import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/harness.dart';

const Duration spinDuration = Duration(milliseconds: 4200);
const Duration frame = Duration(milliseconds: 16);

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
}) {
  return SaturdayWheel(
    odds: odds ?? effectiveOdds(demoSpinConfig, productStock: 1),
    resultPrizeId: result,
    spinToken: token,
    landingSeed: landingSeed,
    skipAnimation: skipAnimation,
    onSettled: () => log.settled++,
    onPegPassed: () => log.pegs++,
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

void main() {
  testWidgets('spins for the full duration and settles exactly once', (
    WidgetTester tester,
  ) async {
    final SpinLog log = SpinLog();
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
    expect(tester.hasRunningAnimations, isTrue);

    await pumpFrames(tester, const Duration(milliseconds: 4000));
    expect(log.settled, 0);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 300));
    expect(log.settled, 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(log.pegs, greaterThan(5));
    expect(log.pegs, lessThanOrEqualTo(spinDuration.inMilliseconds ~/ 45 + 1));

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
      SaturdayWheel(
        odds: effectiveOdds(demoSpinConfig, productStock: 1),
        resultPrizeId: result,
        spinToken: token,
        landingSeed: 99,
        onPegPassed: () => stamps.add(now),
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
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    expect(
      wheelSemantics(tester),
      isSemantics(label: 'Roda Sabtu', value: 'Siap diputar'),
    );

    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
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
    expect(wheelSemantics(tester), isSemantics(value: 'Hasil: Produk gratis'));
    handle.dispose();
  });

  testWidgets('rebuilding with the same token does not spin again', (
    WidgetTester tester,
  ) async {
    final SpinLog log = SpinLog();
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
    await tester.pump(spinDuration + frame);
    expect(log.settled, 1);
    final int pegsAfterSpin = log.pegs;

    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(
      harness(
        wheel(
          log,
          token: 1,
          result: 'kelopak-3',
          odds: List<SpinOdds>.of(
            effectiveOdds(demoSpinConfig, productStock: 1),
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
      harness(wheel(log, token: 1, result: 'product'), disableAnimations: true),
    );
    expect(log.settled, 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(log.settled, 1);
  });

  testWidgets('skipAnimation mid-spin jumps to the result once', (
    WidgetTester tester,
  ) async {
    final SpinLog log = SpinLog();
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
    await pumpFrames(tester, const Duration(milliseconds: 320));
    expect(log.settled, 0);

    await tester.pumpWidget(
      harness(wheel(log, token: 1, result: 'kelopak-3', skipAnimation: true)),
    );
    expect(log.settled, 1);
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
    await tester.pumpWidget(harness(wheel(log, token: 0, skipAnimation: true)));
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
    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(harness(wheel(log, token: 2)));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(log.settled, 0);
  });

  testWidgets('disposing mid-spin is safe', (WidgetTester tester) async {
    final SpinLog log = SpinLog();
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    await tester.pumpWidget(harness(wheel(log, token: 1, result: 'kelopak-3')));
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
      harness(wheel(log, token: 1, result: 'product'), disableAnimations: true),
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
          odds: effectiveOdds(demoSpinConfig, productStock: 0),
        ),
      ),
    );
    await tester.pump(spinDuration + frame);
    await tester.pump();
    expect(log.settled, 1);
    expect(wheelSemantics(tester), isSemantics(value: 'Hasil: Produk gratis'));
    handle.dispose();
  });

  testWidgets('sizes itself to the available width, max 320', (
    WidgetTester tester,
  ) async {
    final SpinLog log = SpinLog();
    await tester.pumpWidget(harness(wheel(log, token: 0)));
    final Size wide = tester.getSize(
      find.descendant(
        of: find.byType(SaturdayWheel),
        matching: find.byType(Stack),
      ),
    );
    expect(wide, const Size(320, 320));

    await tester.pumpWidget(
      harness(Center(child: SizedBox(width: 200, child: wheel(log, token: 0)))),
    );
    final Size narrow = tester.getSize(
      find.descendant(
        of: find.byType(SaturdayWheel),
        matching: find.byType(Stack),
      ),
    );
    expect(narrow, const Size(200, 200));
  });

  testWidgets('shows the center child inside the hub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        SaturdayWheel(
          odds: effectiveOdds(demoSpinConfig, productStock: 1),
          resultPrizeId: null,
          spinToken: 0,
          landingSeed: 1,
          centerChild: const Text('Bipy'),
        ),
      ),
    );
    expect(find.text('Bipy'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Bipy'), matching: find.byType(ClipOval)),
      findsOneWidget,
    );
  });
}
