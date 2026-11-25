import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu_example/main.dart';

/// Kamis, 26 November 2026 pukul 10.00 WIB.
final DateTime thursday = DateTime.utc(2026, 11, 26, 3);

void main() {
  testWidgets('the panel moves the demo to Saturday and the wheel opens', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final LocalWheelController controller = LocalWheelController(
      clock: () => thursday,
      balance: 24,
      product: demoPrizeProducts.first,
      random: math.Random(1),
    );
    await tester.pumpWidget(WheelExampleApp(controller: controller));
    await tester.pump();
    expect(find.text('Belanja sambil menunggu'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Panel uji'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sabtu'));
    await tester.pump();
    expect(controller.state.canSpin, isTrue);
    expect(isSaturdayWib(controller.state.today), isTrue);
  });

  test('day offsets land on the chosen weekday', () {
    for (final DemoDay day in DemoDay.values) {
      final int target = wheelWibDayOf(
        thursday.add(offsetFor(day, thursday)),
      );
      expect(weekdayName(target), day.label);
    }
  });

  test('the prize product rotates weekly', () {
    expect(prizeOfWeek(0), isNot(prizeOfWeek(7)));
    expect(prizeOfWeek(0), prizeOfWeek(6));
  });
}
