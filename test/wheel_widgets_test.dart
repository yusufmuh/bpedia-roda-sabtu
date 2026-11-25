import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/wheel_harness.dart';

Widget host(Widget child, {double textScale = 1, bool dark = false}) =>
    wheelApp(
      Scaffold(
        backgroundColor: const Color(0xFFB3164B),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
      textScale: textScale,
      brightness: dark ? Brightness.dark : Brightness.light,
    );

void setSmallView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('WheelCountdown', () {
    testWidgets('shows days, hours, minutes and seconds to Saturday', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.utc(2026, 11, 26, 3, 15, 30);
      await tester.pumpWidget(
        host(WheelCountdown(saturday: saturdayDay, now: () => now)),
      );
      expect(find.text('Dibuka Sabtu, 28 Nov · 00.00 WIB'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('44'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('ticks every second from the host clock', (
      WidgetTester tester,
    ) async {
      DateTime now = DateTime.utc(2026, 11, 27, 16, 59, 50);
      await tester.pumpWidget(
        host(WheelCountdown(saturday: saturdayDay, now: () => now)),
      );
      expect(find.text('10'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('09'), findsOneWidget);
    });

    testWidgets('reads as one sentence for screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(WheelCountdown(saturday: saturdayDay, now: () => thursday)),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Dibuka Sabtu, 28 Nov · 00\.00 WIB, 2 hari lagi$'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('reminder switch reports changes', (WidgetTester tester) async {
      bool? value;
      await tester.pumpWidget(
        host(
          WheelCountdown(
            saturday: saturdayDay,
            now: () => thursday,
            showReminder: true,
            onReminderChanged: (bool on) => value = on,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(value, isTrue);
    });

    testWidgets('fits 360 wide at 200% text', (WidgetTester tester) async {
      setSmallView(tester);
      await tester.pumpWidget(
        host(
          WheelCountdown(
            saturday: saturdayDay,
            now: () => thursday,
            showReminder: true,
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WheelPrizeCard', () {
    testWidgets('shows the product as free with its normal price', (
      WidgetTester tester,
    ) async {
      String? opened;
      await tester.pumpWidget(
        host(
          WheelPrizeCard(
            product: demoPrizeProduct,
            quotaLeft: 3,
            shippingNote: demoSpinConfig.shippingNote,
            onOpenProduct: () => opened = 'yes',
          ),
        ),
      );
      expect(find.text('Hadiah utama'), findsOneWidget);
      expect(find.text(demoPrizeProduct.name), findsOneWidget);
      expect(find.text('Gratis'), findsOneWidget);
      expect(find.text('Rp23.230'), findsOneWidget);
      expect(find.text('Sisa 3 minggu ini'), findsOneWidget);
      expect(find.text(demoSpinConfig.shippingNote), findsOneWidget);
      await tester.tap(find.byType(WheelPrizeCard));
      expect(opened, 'yes');
    });

    testWidgets('sold out and without a product', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          WheelPrizeCard(
            product: null,
            quotaLeft: 0,
            shippingNote: demoSpinConfig.shippingNote,
          ),
        ),
      );
      expect(find.text('Produk kecantikan pilihan Bpedia'), findsOneWidget);
      expect(find.text('Kuota habis minggu ini'), findsOneWidget);
    });

    testWidgets('is one button node with the whole story', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          WheelPrizeCard(
            product: demoPrizeProduct,
            quotaLeft: 2,
            shippingNote: 'Ikut pesanan berikutnya',
            onOpenProduct: () {},
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(WheelPrizeCard),
      );
      expect(node.label, contains(demoPrizeProduct.name));
      expect(node.label, contains('Rp23.230'));
      expect(node.label, contains('Sisa 2 minggu ini'));
      expect(node.label, contains('Ikut pesanan berikutnya'));
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('fits 360 wide at 200% text, light and dark', (
      WidgetTester tester,
    ) async {
      setSmallView(tester);
      for (final bool dark in <bool>[false, true]) {
        await tester.pumpWidget(
          host(
            WheelPrizeCard(
              product: demoPrizeProduct,
              quotaLeft: 3,
              shippingNote: demoSpinConfig.shippingNote,
              onOpenProduct: () {},
            ),
            textScale: 2,
            dark: dark,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('WheelHistoryList', () {
    testWidgets('lists spins newest first with their result', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(WheelHistoryList(records: demoHistory)));
      expect(find.text('5 Kelopak'), findsOneWidget);
      expect(find.text('+5 Kelopak'), findsOneWidget);
      expect(find.text('Sabtu, 21 Nov'), findsOneWidget);
      expect(find.text('+1 Kelopak'), findsOneWidget);
    });

    testWidgets('product wins show the product name and a badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          WheelHistoryList(
            records: <WheelSpinRecord>[
              WheelSpinRecord.fromPrize(
                demoSpinConfig.prizeById('product')!,
                day: saturdayDay,
                productName: 'Lipgloss',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Lipgloss'), findsOneWidget);
      expect(find.text('Produk gratis'), findsOneWidget);
    });

    testWidgets('limits the rows', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(WheelHistoryList(records: demoHistory, limit: 1)),
      );
      expect(find.text('Sabtu, 14 Nov'), findsNothing);
    });

    testWidgets('empty history cheers the user on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const WheelHistoryList(records: <WheelSpinRecord>[])),
      );
      expect(
        find.text('Belum ada putaran. Sampai jumpa Sabtu ini, Babes!'),
        findsOneWidget,
      );
      expect(find.byType(LivelyPose), findsOneWidget);
    });
  });

  group('WheelHowItWorks', () {
    testWidgets('three numbered steps, product shipping explained', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(const WheelHowItWorks()));
      expect(find.text('1. Putar tiap Sabtu'), findsOneWidget);
      expect(find.text('2. Menangkan hadiah'), findsOneWidget);
      expect(find.text('3. Produk ikut pesanan'), findsOneWidget);
      expect(find.textContaining('pesanan belanja berikutnya'), findsOneWidget);
    });

    testWidgets('fits 360 wide at 200% text', (WidgetTester tester) async {
      setSmallView(tester);
      await tester.pumpWidget(host(const WheelHowItWorks(), textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('OddsStrip', () {
    testWidgets('one chip per prize with odds and quota', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      bool opened = false;
      await tester.pumpWidget(
        host(
          OddsStrip(
            odds: effectiveOdds(demoSpinConfig, productStock: 3),
            productStock: 3,
            onOpenDetails: () => opened = true,
          ),
        ),
      );
      for (final String label in <String>[
        'Produk gratis 5% · sisa 3',
        '10 Kelopak 5%',
        '5 Kelopak 15%',
        '3 Kelopak 30%',
        '1 Kelopak 45%',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await tester.ensureVisible(find.bySemanticsLabel('Peluang & ketentuan'));
      await tester.tap(find.bySemanticsLabel('Peluang & ketentuan'));
      expect(opened, isTrue);
      handle.dispose();
    });

    test('chip label for sold-out product', () {
      final List<SpinOdds> odds = effectiveOdds(
        demoSpinConfig,
        productStock: 0,
      );
      expect(
        OddsStrip.chipLabel(odds.first, 0),
        'Produk gratis 0% · kuota habis',
      );
      expect(OddsStrip.chipLabel(odds.last, 0), '1 Kelopak 50%');
    });

    testWidgets('hides the link without a callback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          OddsStrip(
            odds: effectiveOdds(demoSpinConfig, productStock: 3),
            productStock: 3,
          ),
        ),
      );
      expect(find.text('Peluang & ketentuan'), findsNothing);
    });
  });

  group('LivelyPose', () {
    testWidgets('moves, and stands still with reduced motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const LivelyPose(image: WheelArt.poseCheer, height: 80)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        wheelApp(
          const LivelyPose(image: WheelArt.poseCheer, height: 80),
          disableAnimations: true,
        ),
      );
      expect(find.byType(Transform), findsNothing);
    });

    test('spring starts compressed and settles', () {
      expect(LivelyPose.springAt(0), -1);
      expect(LivelyPose.springAt(2).abs(), lessThan(0.01));
    });
  });
}
