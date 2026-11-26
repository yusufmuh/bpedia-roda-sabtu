import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/kit/kit.dart';

import 'support/harness.dart';
import 'support/v2_fixtures.dart';

const Duration spinDuration = WheelSpinCurve.duration;
const Duration frame = Duration(milliseconds: 16);

/// Pegas penunjuk masih bergetar sebentar setelah pasak terakhir, dan
/// wajah poros berganti dengan silang-pudar setelah roda berhenti.
const Duration pointerRest = Duration(milliseconds: 700);

Future<void> rest(WidgetTester tester) async {
  await tester.pump(pointerRest);
  await tester.pump(const Duration(milliseconds: 300));
}

final class SpinLog {
  int settled = 0;
  int pegs = 0;
}

Widget wheel(
  SpinLog log, {
  required int token,
  String? result,
  List<SpinOdds>? odds,
  bool skipAnimation = false,
  int landingSeed = 7331,
  String? idle,
}) {
  return PrizeWheel(
    odds: odds ?? effectiveOdds(v2SpinConfig, productStock: 1),
    resultPrizeId: result,
    spinToken: token,
    landingSeed: landingSeed,
    skipAnimation: skipAnimation,
    onSettled: () => log.settled++,
    onPegPassed: () => log.pegs++,
    idleSemanticsValue: idle,
    ambientMotion: false,
  );
}

Future<void> pumpFrames(WidgetTester tester, Duration total) async {
  final int frames = total.inMicroseconds ~/ frame.inMicroseconds;
  for (int i = 0; i < frames; i++) {
    await tester.pump(frame);
  }
}

SemanticsNode wheelSemantics(WidgetTester tester) =>
    tester.getSemantics(find.bySemanticsLabel('Roda Sabtu'));

/// Sudut putaran cakram yang sedang tampil.
double discRotation(WidgetTester tester) {
  final Transform transform = tester.widget<Transform>(
    find.byKey(PrizeWheel.discKey),
  );
  final Matrix4 m = transform.transform;
  return math.atan2(m.entry(1, 0), m.entry(0, 0));
}

Size wheelSize(WidgetTester tester) => tester.getSize(
  find
      .descendant(of: find.byType(PrizeWheel), matching: find.byType(Stack))
      .first,
);

void main() {
  group('kontrak v2', () {
    testWidgets('spins for the full duration and settles exactly once', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      expect(tester.hasRunningAnimations, isTrue);

      await pumpFrames(
        tester,
        spinDuration - const Duration(milliseconds: 200),
      );
      expect(log.settled, 0);
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 300));
      expect(log.settled, 1);
      expect(log.pegs, greaterThan(5));
      expect(
        log.pegs,
        lessThanOrEqualTo(spinDuration.inMilliseconds ~/ 45 + 1),
      );
      await rest(tester);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('peg callbacks are at least 45 ms apart', (
      WidgetTester tester,
    ) async {
      final List<Duration> stamps = <Duration>[];
      Duration now = Duration.zero;
      Widget build(int token, String? result) => harness(
        PrizeWheel(
          odds: effectiveOdds(v2SpinConfig, productStock: 1),
          resultPrizeId: result,
          spinToken: token,
          landingSeed: 99,
          onPegPassed: () => stamps.add(now),
          ambientMotion: false,
        ),
      );
      await tester.pumpWidget(build(0, null));
      await tester.pumpWidget(build(1, 'product'));
      const Duration step = Duration(milliseconds: 5);
      while (now < spinDuration + const Duration(milliseconds: 100)) {
        now += step;
        await tester.pump(step);
      }
      expect(stamps.length, greaterThan(5));
      for (int i = 1; i < stamps.length; i++) {
        expect(
          stamps[i] - stamps[i - 1],
          greaterThanOrEqualTo(const Duration(milliseconds: 45)),
        );
      }
    });

    testWidgets('semantics describe ready, spinning and result', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SpinLog log = SpinLog();
      await tester.pumpWidget(
        harness(wheel(log, token: 0, idle: 'Siap diputar')),
      );
      expect(
        wheelSemantics(tester),
        isSemantics(label: 'Roda Sabtu', value: 'Siap diputar'),
      );

      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      expect(
        wheelSemantics(tester),
        isSemantics(label: 'Roda Sabtu', value: 'Sedang berputar'),
      );

      await tester.pump(spinDuration + frame);
      await tester.pump();
      expect(log.settled, 1);
      expect(
        wheelSemantics(tester),
        isSemantics(label: 'Roda Sabtu', value: 'Hasil: 3 Kelopak'),
      );
      handle.dispose();
    });

    testWidgets('idle semantics come from the host, never a default '
        '"Siap diputar"', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      final SemanticsNode unknown = wheelSemantics(tester);
      expect(unknown.label, 'Roda Sabtu');
      expect(unknown.value, isNot('Siap diputar'));
      expect(unknown.value, isEmpty);

      for (final String closed in <String>[
        'Buka Sabtu, 5 Des',
        'Promo sedang tidak aktif',
        'Sudah diputar Sabtu ini',
      ]) {
        await tester.pumpWidget(harness(wheel(log, token: 0, idle: closed)));
        expect(
          wheelSemantics(tester),
          isSemantics(label: 'Roda Sabtu', value: closed),
        );
      }

      await tester.pumpWidget(
        harness(
          wheel(log, token: 1, result: 'kelopak-3', idle: 'Siap diputar'),
        ),
      );
      await tester.pump(spinDuration + frame);
      await tester.pump();
      expect(
        wheelSemantics(tester),
        isSemantics(label: 'Roda Sabtu', value: 'Hasil: 3 Kelopak'),
      );
      handle.dispose();
    });

    testWidgets('first build with a result rests without animating', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 4, result: 'product')));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 0);
      expect(log.pegs, 0);
      expect(
        wheelSemantics(tester),
        isSemantics(value: 'Hasil: Produk gratis'),
      );
      handle.dispose();
    });

    testWidgets('rebuilding with the same token does not spin again', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      await tester.pump(spinDuration + frame);
      expect(log.settled, 1);
      await rest(tester);
      final int pegsAfterSpin = log.pegs;

      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        harness(
          wheel(
            log,
            token: 1,
            result: 'kelopak-3',
            odds: List<SpinOdds>.of(
              effectiveOdds(v2SpinConfig, productStock: 1),
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 1);
      expect(log.pegs, pegsAfterSpin);
    });

    testWidgets('reduced motion settles within one frame', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(
        harness(wheel(log, token: 0), disableAnimations: true),
      );
      await tester.pumpWidget(
        harness(
          wheel(log, token: 1, result: 'kelopak-3'),
          disableAnimations: true,
        ),
      );
      expect(log.settled, 1);
      expect(log.pegs, 0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump();
      expect(log.settled, 1);
    });

    testWidgets('reduced motion switched on mid-spin jumps to the result', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(harness(wheel(log, token: 1, result: 'product')));
      await pumpFrames(tester, const Duration(milliseconds: 480));
      expect(log.settled, 0);

      await tester.pumpWidget(
        harness(
          wheel(log, token: 1, result: 'product'),
          disableAnimations: true,
        ),
      );
      expect(log.settled, 1);
      await rest(tester);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 1);
    });

    testWidgets('skipAnimation mid-spin jumps to the result once', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      await pumpFrames(tester, const Duration(milliseconds: 320));
      expect(log.settled, 0);

      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3', skipAnimation: true)),
      );
      expect(log.settled, 1);
      await rest(tester);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3', skipAnimation: true)),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 1);
    });

    testWidgets('skipAnimation at spin start settles without animating', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(
        harness(wheel(log, token: 0, skipAnimation: true)),
      );
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'product', skipAnimation: true)),
      );
      expect(log.settled, 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(log.pegs, 0);
    });

    testWidgets('a new token without a result cancels the spin silently', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(harness(wheel(log, token: 2)));
      await rest(tester);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 0);
    });

    testWidgets('disposing mid-spin is safe', (WidgetTester tester) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(wheel(log, token: 1, result: 'kelopak-3')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(log.settled, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing after a reduced-motion settle is safe', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(
        harness(wheel(log, token: 0), disableAnimations: true),
      );
      await tester.pumpWidget(
        harness(
          wheel(log, token: 1, result: 'product'),
          disableAnimations: true,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(log.settled, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('winning the last product still settles with its label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      await tester.pumpWidget(
        harness(
          wheel(
            log,
            token: 1,
            result: 'product',
            odds: effectiveOdds(v2SpinConfig, productStock: 0),
          ),
        ),
      );
      await tester.pump(spinDuration + frame);
      await tester.pump();
      expect(log.settled, 1);
      expect(
        wheelSemantics(tester),
        isSemantics(value: 'Hasil: Produk gratis'),
      );
      handle.dispose();
    });

    testWidgets('sizes itself to the available width, max 360', (
      WidgetTester tester,
    ) async {
      final SpinLog log = SpinLog();
      await tester.pumpWidget(harness(wheel(log, token: 0)));
      expect(wheelSize(tester).width, 360);
      expect(
        wheelSize(tester).height,
        closeTo(PrizeWheel.heightFor(360), 0.01),
      );

      await tester.pumpWidget(
        harness(
          Center(child: SizedBox(width: 200, child: wheel(log, token: 0))),
        ),
      );
      expect(wheelSize(tester).width, 200);
      expect(
        wheelSize(tester).height,
        closeTo(PrizeWheel.heightFor(200), 0.01),
      );
    });

    testWidgets('shows the center child inside the hub', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          PrizeWheel(
            odds: effectiveOdds(v2SpinConfig, productStock: 1),
            resultPrizeId: null,
            spinToken: 0,
            landingSeed: 1,
            centerChild: const Text('Bipy'),
            ambientMotion: false,
          ),
        ),
      );
      expect(find.text('Bipy'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('Bipy'), matching: find.byType(ClipOval)),
        findsOneWidget,
      );
    });
  });

  group('roda v3', () {
    final List<SpinOdds> v3Odds = effectiveOdds(
      demoSpinConfig,
      productStock: 3,
    );

    Widget v3Wheel({
      required int token,
      String? result,
      int seed = 11,
      VoidCallback? onSettled,
      bool ambient = false,
    }) => PrizeWheel(
      odds: v3Odds,
      layout: demoSpinConfig.wheelLayout,
      resultPrizeId: result,
      spinToken: token,
      landingSeed: seed,
      onSettled: onSettled,
      ambientMotion: ambient,
    );

    testWidgets('idle wheel rests with the first slice under the pointer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0)));
      final WheelGeometry geometry = WheelGeometry.fromOdds(
        v3Odds,
        layout: demoSpinConfig.wheelLayout,
      );
      final WheelSlice? under = geometry.sliceUnderPointer(
        discRotation(tester),
      );
      expect(under?.index, 0);
      expect(under?.prizeId, 'product');
    });

    testWidgets('Kelopak slices alternate pink/white and cream/deep by index', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0)));
      final WheelGeometry geometry = WheelGeometry.fromOdds(
        v3Odds,
        layout: demoSpinConfig.wheelLayout,
      );
      final List<WheelSlice> plain = <WheelSlice>[
        for (final WheelSlice slice in geometry.slices)
          if (slice.prizeId != 'product' && slice.prizeId != 'kelopak-10')
            slice,
      ];
      final int even = plain.where((WheelSlice s) => s.index.isEven).length;
      expect(even, greaterThan(0));
      expect(plain.length - even, greaterThan(0));
      final List<Color?> inks = <Color?>[
        for (final String number in <String>['1', '3', '5'])
          for (final Element element
              in find
                  .descendant(
                    of: find.byKey(PrizeWheel.discKey),
                    matching: find.text(number),
                  )
                  .evaluate())
            (element.widget as Text).style?.color,
      ];
      expect(inks.where((Color? c) => c == Colors.white).length, even);
      expect(
        inks.where((Color? c) => c == FestivePalette.festDeep).length,
        plain.length - even,
      );
    });

    testWidgets('slice numbers stand upright while the wheel rests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0)));
      for (final String number in <String>['1', '3', '5', '10']) {
        for (final Element element
            in find
                .descendant(
                  of: find.byKey(PrizeWheel.discKey),
                  matching: find.text(number),
                )
                .evaluate()) {
          final RenderBox box = element.renderObject! as RenderBox;
          final Matrix4 m = box.getTransformTo(null);
          final double angle = math.atan2(m.entry(1, 0), m.entry(0, 0));
          expect(angle.abs(), lessThan(0.01), reason: 'angka $number miring');
        }
      }
    });

    for (final String prizeId in <String>[
      'product',
      'kelopak-10',
      'kelopak-5',
      'kelopak-3',
      'kelopak-1',
    ]) {
      testWidgets('stops inside a $prizeId slice for several seeds', (
        WidgetTester tester,
      ) async {
        final WheelGeometry geometry = WheelGeometry.fromOdds(
          v3Odds,
          layout: demoSpinConfig.wheelLayout,
        );
        int token = 0;
        await tester.pumpWidget(harness(v3Wheel(token: token)));
        for (final int seed in <int>[1, 77, 4242]) {
          token++;
          await tester.pumpWidget(
            harness(v3Wheel(token: token, result: prizeId, seed: seed)),
          );
          await tester.pump(spinDuration + frame);
          await rest(tester);
          expect(
            geometry.sliceUnderPointer(discRotation(tester))?.prizeId,
            prizeId,
          );
        }
      });
    }

    testWidgets('shows a number, "Kelopak" and art on the wide slices', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0)));
      expect(find.text('Produk'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('1'), findsNWidgets(3));
      expect(find.text('Kelopak'), findsNWidgets(6));
      expect(
        find.descendant(
          of: find.byKey(PrizeWheel.discKey),
          matching: find.byType(Image),
        ),
        findsNWidgets(8),
      );
    });

    testWidgets('ambient lights run while idle and stop when disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0, ambient: true)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        harness(v3Wheel(token: 0, ambient: true), disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('celebrates for 1.8 s after a win, then rests', (
      WidgetTester tester,
    ) async {
      int settled = 0;
      await tester.pumpWidget(harness(v3Wheel(token: 0, ambient: true)));
      await tester.pumpWidget(
        harness(
          v3Wheel(
            token: 1,
            result: 'kelopak-5',
            ambient: true,
            onSettled: () => settled++,
          ),
        ),
      );
      await tester.pump(spinDuration + frame);
      expect(settled, 1);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 1900));
      await rest(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('hub shows the wink face after a win', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0)));
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Image && w.image == WheelArt.faceSmile,
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(harness(v3Wheel(token: 1, result: 'kelopak-1')));
      await tester.pump(spinDuration + frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Image && w.image == WheelArt.faceWink,
        ),
        findsOneWidget,
      );
    });

    testWidgets('wheel text ignores the system text scale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(v3Wheel(token: 0), textScale: 2));
      final RichText ten = tester.widget<RichText>(
        find.descendant(of: find.text('10'), matching: find.byType(RichText)),
      );
      expect(ten.textScaler, TextScaler.noScaling);
      expect(tester.takeException(), isNull);
    });
  });
}
