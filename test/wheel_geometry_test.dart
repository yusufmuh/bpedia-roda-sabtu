import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/wheel_geometry.dart';

const double epsilon = 1e-9;

SpinOdds kelopakOdds(String id, int weight) => SpinOdds(
  prize: SpinPrize(
    id: id,
    kind: PrizeKind.kelopak,
    label: id,
    kelopak: 1,
    weight: weight,
  ),
  weight: weight,
);

SpinOdds productOdds(String id, int weight) => SpinOdds(
  prize: SpinPrize(
    id: id,
    kind: PrizeKind.product,
    label: id,
    kelopak: 0,
    weight: weight,
  ),
  weight: weight,
);

void expectNoAdjacentKelopakTone(WheelGeometry geometry) {
  final List<WheelSegment> segments = geometry.segments;
  for (int i = 0; i < segments.length; i++) {
    final WheelSegment current = segments[i];
    final WheelSegment next = segments[(i + 1) % segments.length];
    if (current.tone == SegmentTone.product) continue;
    expect(
      next.tone,
      isNot(current.tone),
      reason: 'segments $i and ${(i + 1) % segments.length} share a tone',
    );
  }
}

void main() {
  final List<List<SpinOdds>> layouts = <List<SpinOdds>>[
    effectiveOdds(demoSpinConfig, productStock: 1),
    effectiveOdds(demoSpinConfig, productStock: 0),
    <SpinOdds>[kelopakOdds('a', 7000), kelopakOdds('b', 3000)],
    <SpinOdds>[
      kelopakOdds('a', 4000),
      productOdds('p', 1000),
      kelopakOdds('b', 5000),
    ],
    <SpinOdds>[
      productOdds('p', 3000),
      kelopakOdds('a', 2000),
      kelopakOdds('b', 5000),
    ],
  ];

  group('WheelGeometry.fromOdds', () {
    test('demo odds: one product slice and four 81 degree Kelopak slices', () {
      final WheelGeometry geometry = WheelGeometry.fromOdds(
        effectiveOdds(demoSpinConfig, productStock: 1),
      );
      final List<WheelSegment> segments = geometry.segments;
      expect(segments, hasLength(5));
      expect(segments.first.prize.id, 'product');
      expect(segments.first.tone, SegmentTone.product);
      expect(segments.first.sweep, closeTo(fullTurn * 0.1, epsilon));
      for (final WheelSegment segment in segments.skip(1)) {
        expect(segment.prize.id, 'kelopak-3');
        expect(segment.sweep, closeTo(81 * math.pi / 180, epsilon));
      }
    });

    test('stock 0 skips the zero-weight product', () {
      final WheelGeometry geometry = WheelGeometry.fromOdds(
        effectiveOdds(demoSpinConfig, productStock: 0),
      );
      expect(geometry.contains('product'), isFalse);
      expect(geometry.segments, hasLength(4));
      for (final WheelSegment segment in geometry.segments) {
        expect(segment.sweep, closeTo(math.pi / 2, epsilon));
      }
    });

    for (int i = 0; i < layouts.length; i++) {
      test('layout $i: proportional, gap-free, at most 90 degrees', () {
        final List<SpinOdds> odds = layouts[i];
        final WheelGeometry geometry = WheelGeometry.fromOdds(odds);
        final List<WheelSegment> segments = geometry.segments;
        final int total = odds.fold<int>(
          0,
          (int sum, SpinOdds e) => sum + e.weight,
        );
        expect(segments.first.start, 0);
        expect(segments.last.end, closeTo(fullTurn, epsilon));
        for (int s = 1; s < segments.length; s++) {
          expect(segments[s].start, closeTo(segments[s - 1].end, epsilon));
        }
        for (final WheelSegment segment in segments) {
          expect(segment.sweep, lessThanOrEqualTo(math.pi / 2 + epsilon));
        }
        for (final SpinOdds entry in odds) {
          final double area = segments
              .where((WheelSegment s) => s.prize.id == entry.prize.id)
              .fold<double>(0, (double sum, WheelSegment s) => sum + s.sweep);
          expect(area, closeTo(fullTurn * entry.weight / total, epsilon));
        }
        expectNoAdjacentKelopakTone(geometry);
      });
    }

    test('balances an odd Kelopak count across the seam', () {
      final WheelGeometry geometry = WheelGeometry.fromOdds(<SpinOdds>[
        kelopakOdds('a', 7000),
        kelopakOdds('b', 3000),
      ]);
      expect(geometry.segments.length.isEven, isTrue);
      expectNoAdjacentKelopakTone(geometry);
    });

    test('empty or all-zero odds produce no segments', () {
      expect(WheelGeometry.fromOdds(const <SpinOdds>[]).segments, isEmpty);
      expect(
        WheelGeometry.fromOdds(<SpinOdds>[kelopakOdds('a', 0)]).segments,
        isEmpty,
      );
    });

    test('equal odds give equal geometry', () {
      expect(
        WheelGeometry.fromOdds(effectiveOdds(demoSpinConfig, productStock: 1)),
        WheelGeometry.fromOdds(effectiveOdds(demoSpinConfig, productStock: 3)),
      );
    });
  });

  group('landing', () {
    final WheelGeometry geometry = WheelGeometry.fromOdds(
      effectiveOdds(demoSpinConfig, productStock: 1),
    );

    test('rest rotation puts the result under the pointer, 15-85% in', () {
      for (final String prizeId in <String>['product', 'kelopak-3']) {
        for (int seed = -50; seed < 400; seed++) {
          final double rest = geometry.restRotationFor(prizeId, seed)!;
          expect(rest, inInclusiveRange(0, fullTurn));
          final WheelSegment under = geometry.segmentUnderPointer(rest)!;
          expect(under.prize.id, prizeId, reason: 'seed $seed');
          final double point = normalizeAngle(-rest);
          final double fraction = (point - under.start) / under.sweep;
          expect(fraction, inInclusiveRange(0.15 - 1e-6, 0.85 + 1e-6));
        }
      }
    });

    test('landing is deterministic per seed and spreads over pieces', () {
      expect(
        geometry.landingAngle('kelopak-3', 77),
        geometry.landingAngle('kelopak-3', 77),
      );
      final Set<double> starts = <double>{
        for (int seed = 0; seed < 8; seed++)
          geometry
              .segmentUnderPointer(
                geometry.restRotationFor('kelopak-3', seed)!,
              )!
              .start,
      };
      expect(starts, hasLength(4));
    });

    test('spin end adds five turns and stops on the rest rotation', () {
      for (final double from in <double>[0, 1.3, 37.9, -2.4]) {
        final double end = geometry.spinEndRotation(
          from: from,
          prizeId: 'product',
          landingSeed: 1234,
          fullTurns: 5,
        );
        expect(end - from, greaterThanOrEqualTo(5 * fullTurn - epsilon));
        expect(end - from, lessThan(6 * fullTurn + epsilon));
        expect(geometry.segmentUnderPointer(end)!.prize.id, 'product');
        final double rest = geometry.restRotationFor('product', 1234)!;
        expect(
          normalizeAngle(end - rest),
          anyOf(lessThan(1e-6), greaterThan(fullTurn - 1e-6)),
        );
      }
    });

    test('unknown prize spins whole turns only', () {
      expect(geometry.restRotationFor('missing', 1), isNull);
      expect(
        geometry.spinEndRotation(
          from: 1,
          prizeId: 'missing',
          landingSeed: 1,
          fullTurns: 5,
        ),
        closeTo(1 + 5 * fullTurn, epsilon),
      );
    });

    test('idle rotation centers the first segment under the pointer', () {
      final WheelSegment first = geometry.segments.first;
      final double idle = geometry.idleRotation;
      expect(
        normalizeAngle(-idle),
        closeTo(first.start + first.sweep / 2, epsilon),
      );
      expect(geometry.segmentUnderPointer(idle), same(first));
      expect(WheelGeometry.fromOdds(const <SpinOdds>[]).idleRotation, 0);
    });
  });

  group('pegCrossed', () {
    final WheelGeometry geometry = WheelGeometry.fromOdds(
      effectiveOdds(demoSpinConfig, productStock: 1),
    );

    test('detects a boundary passing the pointer', () {
      expect(geometry.pegCrossed(0.01, 0.02), isFalse);
      expect(geometry.pegCrossed(0.01, fullTurn), isTrue);
      expect(geometry.pegCrossed(-0.01, 0.01), isTrue);
    });

    test('counts nothing for no movement or a single segment', () {
      expect(geometry.pegCrossed(1, 1), isFalse);
      expect(geometry.pegCrossed(2, 1), isFalse);
      expect(
        WheelGeometry.fromOdds(const <SpinOdds>[]).pegCrossed(0, 10),
        isFalse,
      );
    });
  });

  group('retainResult', () {
    final WheelGeometry withProduct = WheelGeometry.fromOdds(
      effectiveOdds(demoSpinConfig, productStock: 1),
    );
    final WheelGeometry soldOut = WheelGeometry.fromOdds(
      effectiveOdds(demoSpinConfig, productStock: 0),
    );

    test('keeps the layout that still shows a just-won product', () {
      expect(
        WheelGeometry.retainResult(
          current: withProduct,
          next: soldOut,
          resultPrizeId: 'product',
        ),
        same(withProduct),
      );
    });

    test('switches to the new layout otherwise', () {
      expect(
        WheelGeometry.retainResult(
          current: withProduct,
          next: soldOut,
          resultPrizeId: 'kelopak-3',
        ),
        same(soldOut),
      );
      expect(
        WheelGeometry.retainResult(
          current: withProduct,
          next: soldOut,
          resultPrizeId: null,
        ),
        same(soldOut),
      );
    });
  });
}
