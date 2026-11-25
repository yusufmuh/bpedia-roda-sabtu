import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/wheel_geometry.dart';

import 'support/v2_fixtures.dart';

const double epsilon = 1e-9;

void main() {
  group('landing', () {
    final WheelGeometry geometry = WheelGeometry.fromOdds(
      effectiveOdds(v2SpinConfig, productStock: 1),
    );

    test('rest rotation puts the result under the pointer, 15-85% in', () {
      for (final String prizeId in <String>['product', 'kelopak-3']) {
        for (int seed = -50; seed < 400; seed++) {
          final double rest = geometry.restRotationFor(prizeId, seed)!;
          expect(rest, inInclusiveRange(0, fullTurn));
          final WheelSlice under = geometry.sliceUnderPointer(rest)!;
          expect(under.prizeId, prizeId, reason: 'seed $seed');
          final double point = normalizeAngle(-rest);
          final double fraction =
              (point - under.startRadians) / under.sweepRadians;
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
              .sliceUnderPointer(geometry.restRotationFor('kelopak-3', seed)!)!
              .startDeg,
      };
      expect(starts, hasLength(6));
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
        expect(geometry.sliceUnderPointer(end)!.prizeId, 'product');
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
      final WheelSlice first = geometry.slices.first;
      final double idle = geometry.idleRotation;
      expect(
        normalizeAngle(-idle),
        closeTo(first.startRadians + first.sweepRadians / 2, epsilon),
      );
      expect(geometry.sliceUnderPointer(idle), same(first));
      expect(WheelGeometry.fromOdds(const <SpinOdds>[]).idleRotation, 0);
    });
  });

  group('pegCrossed', () {
    final WheelGeometry geometry = WheelGeometry.fromOdds(
      effectiveOdds(v2SpinConfig, productStock: 1),
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
      effectiveOdds(v2SpinConfig, productStock: 1),
    );
    final WheelGeometry soldOut = WheelGeometry.fromOdds(
      effectiveOdds(v2SpinConfig, productStock: 0),
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

  group('geometri roda v3 (demoSpinConfig)', () {
    final WheelGeometry geometry = WheelGeometry.fromConfig(
      demoSpinConfig,
      productQuotaLeft: 3,
    );

    test('fromConfig memakai irisan buildWheelSlices', () {
      expect(
        geometry.slices,
        buildWheelSlices(demoSpinConfig, productQuotaLeft: 3),
      );
      expect(
        geometry,
        WheelGeometry.fromOdds(
          effectiveOdds(demoSpinConfig, productStock: 3),
          layout: demoSpinConfig.wheelLayout,
        ),
      );
      expect(
        geometry,
        isNot(WheelGeometry.fromConfig(demoSpinConfig, productQuotaLeft: 0)),
      );
    });

    test('tiap hadiah mendarat di irisannya sendiri untuk semua benih', () {
      for (final SpinPrize prize in demoSpinConfig.prizes) {
        for (int seed = -20; seed < 3200; seed += 7) {
          final double rest = geometry.restRotationFor(prize.id, seed)!;
          final WheelSlice under = geometry.sliceUnderPointer(rest)!;
          expect(under.prizeId, prize.id, reason: 'benih $seed');
          final double fraction =
              (normalizeAngle(-rest) - under.startRadians) / under.sweepRadians;
          expect(fraction, inInclusiveRange(0.15 - 1e-6, 0.85 + 1e-6));
        }
      }
    });

    test('benih menyebar ke ketiga irisan 1 Kelopak', () {
      final Set<int> landed = <int>{
        for (int seed = 0; seed < 3; seed++)
          geometry
              .sliceUnderPointer(geometry.restRotationFor('kelopak-1', seed)!)!
              .index,
      };
      expect(landed, <int>{1, 3, 7});
    });

    test('roda diam menaruh irisan produk di bawah penunjuk', () {
      final WheelSlice idle = geometry.sliceUnderPointer(
        geometry.idleRotation,
      )!;
      expect(idle.prizeId, 'product');
      expect(idle.index, 0);
    });

    test('pasak terlewati di tiap batas irisan dalam satu putaran', () {
      int pegs = 0;
      const int steps = 3600;
      for (int i = 0; i < steps; i++) {
        final double from = 0.0005 + fullTurn * i / steps;
        final double to = 0.0005 + fullTurn * (i + 1) / steps;
        if (geometry.pegCrossed(from, to)) pegs++;
      }
      expect(pegs, geometry.slices.length);
    });

    test(
      'kuota habis setelah menang produk: tata letak lama dipertahankan',
      () {
        final WheelGeometry soldOut = WheelGeometry.fromConfig(
          demoSpinConfig,
          productQuotaLeft: 0,
        );
        expect(soldOut.contains('product'), isFalse);
        expect(
          WheelGeometry.retainResult(
            current: geometry,
            next: soldOut,
            resultPrizeId: 'product',
          ),
          same(geometry),
        );
        expect(
          WheelGeometry.retainResult(
            current: geometry,
            next: soldOut,
            resultPrizeId: 'kelopak-1',
          ),
          same(soldOut),
        );
      },
    );
  });
}
