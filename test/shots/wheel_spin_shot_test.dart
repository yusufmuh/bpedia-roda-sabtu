import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/kit/kit.dart';

import '../support/shot.dart';
import '../support/wheel_harness.dart';

/// Strip animasi putaran dan lembar hasil (produk dan Kelopak).
Future<void> untilSheet(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(ResultSheet).evaluate().isNotEmpty) break;
  }
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  Future<LocalWheelController> spinTo(
    WidgetTester tester,
    String prizeId, {
    Brightness brightness = Brightness.light,
  }) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize(prizeId);
    await pumpShot(tester, wheelPageApp(controller, brightness: brightness));
    await tester.tap(find.text('Putar gratis'));
    await tester.pump();
    return controller;
  }

  testWidgets('strip putaran', (WidgetTester tester) async {
    await spinTo(tester, 'kelopak-10');
    await shotStrip(
      tester,
      'roda_strip_putar',
      frames: 12,
      step: const Duration(milliseconds: 520),
    );
  });

  testWidgets('strip perayaan menang', (WidgetTester tester) async {
    await spinTo(tester, 'kelopak-5');
    await tester.pump(WheelSpinCurve.duration);
    await shotStrip(
      tester,
      'roda_strip_menang',
      frames: 8,
      step: const Duration(milliseconds: 160),
    );
  });

  for (final Brightness brightness in Brightness.values) {
    final String tone = brightness == Brightness.light ? 'terang' : 'gelap';

    testWidgets('hasil produk ($tone)', (WidgetTester tester) async {
      await spinTo(tester, 'product', brightness: brightness);
      await untilSheet(tester);
      await settleImages(tester);
      await saveShot(tester, 'roda_hasil_produk_$tone');
    });

    testWidgets('hasil kelopak ($tone)', (WidgetTester tester) async {
      await spinTo(tester, 'kelopak-5', brightness: brightness);
      await untilSheet(tester);
      await settleImages(tester);
      await saveShot(tester, 'roda_hasil_kelopak_$tone');
    });
  }
}
