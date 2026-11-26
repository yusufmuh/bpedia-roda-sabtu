import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/kit/kit.dart';

import 'support/wheel_harness.dart';

/// Pengendali yang selalu gagal mengirim putaran.
class FailingWheelController extends LocalWheelController {
  FailingWheelController() : super(clock: () => saturday);

  @override
  Future<WheelSpinResult?> spin() async => throw StateError('offline');
}

Future<void> pumpPage(
  WidgetTester tester,
  WheelController controller, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wheelPageApp(
      controller,
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pump();
}

SemanticsNode wheelNode(WidgetTester tester) => tester.getSemantics(
  find
      .descendant(of: find.byType(PrizeWheel), matching: find.byType(Semantics))
      .first,
);

Future<void> untilSheet(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(ResultSheet).evaluate().isNotEmpty) break;
  }
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> tapSpin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Putar gratis'));
  await tester.tap(find.text('Putar gratis'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Saturday shows the wheel, odds, prize and the spin button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPage(tester, localWheel());
    expect(find.text('Roda Sabtu'), findsWidgets);
    expect(find.text('Menangkan produk gratis atau Kelopak'), findsOneWidget);
    expect(find.text('Gratis 1 putaran tiap Sabtu'), findsOneWidget);
    expect(find.byType(PrizeWheel), findsOneWidget);
    expect(find.bySemanticsLabel('Produk gratis 5% · sisa 3'), findsOneWidget);
    expect(find.text('Putar gratis'), findsOneWidget);
    expect(wheelNode(tester), isSemantics(value: 'Siap diputar'));
    handle.dispose();
  });

  testWidgets('the spin bar is gold with a play icon and the valid date', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel());
    final CandyButton button = tester.widget<CandyButton>(
      find.widgetWithText(CandyButton, 'Putar gratis'),
    );
    expect(button.variant, CandyVariant.gold);
    expect(
      find.descendant(
        of: find.byType(CandyButton),
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Sabtu, 28 Nov 2026 · berlaku sampai 23.59 WIB'),
      findsOneWidget,
    );
  });

  testWidgets('the panel lists prize, odds, how it works and history', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel(), size: const Size(390, 2600));
    expect(find.text('Hadiah minggu ini'), findsOneWidget);
    expect(find.text(demoPrizeProduct.name), findsOneWidget);
    expect(find.text('Sisa 3 minggu ini'), findsOneWidget);
    expect(find.text('Peluang & ketentuan'), findsWidgets);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Cara kerja'), findsOneWidget);
    expect(find.text('1. Putar tiap Sabtu'), findsOneWidget);
    expect(find.text('Riwayat putaranmu'), findsOneWidget);
    expect(find.text('Sabtu, 21 Nov'), findsOneWidget);
    expect(find.text('+5 Kelopak'), findsOneWidget);
  });

  testWidgets('spinning to a product ends in the product result sheet', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('product');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    expect(find.text('Sedang berputar'), findsOneWidget);
    await untilSheet(tester);
    expect(find.text('Selamat, kamu menang!'), findsOneWidget);
    expect(find.text('1 produk gratis'), findsOneWidget);
    final Text strike = tester.widget<Text>(find.text('Rp23.230'));
    expect(strike.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Rp0'), findsOneWidget);
    expect(find.text('Tanpa ongkir tambahan'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultSheet),
        matching: find.byIcon(Icons.shopping_cart_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Hadiah masuk ke keranjang dan dikirim bersama pesanan berikutnya.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Lihat keranjang'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.opened, contains('cart'));
    expect(find.text('Lihat hadiah di keranjang'), findsOneWidget);
    expect(find.text('Hasil Sabtu ini'), findsOneWidget);
  });

  testWidgets('"Belanja sekarang" on the product sheet opens the shop', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('product');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await untilSheet(tester);
    await tester.tap(find.text('Belanja sekarang'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.opened, contains('shop'));
  });

  testWidgets('a Kelopak win shows the amount, value and "Mantap"', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-5');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await untilSheet(tester);
    expect(find.text('Hoki besar, Babes!'), findsOneWidget);
    expect(find.text('Senilai Rp500'), findsOneWidget);
    expect(
      find.text('Masuk ke saldo. Otomatis memotong belanja saat checkout.'),
      findsOneWidget,
    );
    expect(find.text('1 Kelopak = Rp100'), findsOneWidget);
    await tester.tap(find.text('Mantap'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Kamu dapat 5 Kelopak'), findsOneWidget);
    expect(find.text('Belanja pakai Kelopak'), findsOneWidget);
  });

  testWidgets('a small Kelopak win uses the gentle title', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-1');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await untilSheet(tester);
    expect(find.text('Kelopak masuk, Babes!'), findsOneWidget);
  });

  testWidgets('cues: spin start, peg ticks, then the win', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-3');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await untilSheet(tester);
    expect(controller.cues.first, GameCue.spinStart);
    expect(
      controller.cues.where((GameCue c) => c == GameCue.tick).length,
      greaterThan(5),
    );
    expect(controller.cues.last, GameCue.winKelopak);
  });

  testWidgets('the balance and history do not reveal the result mid-spin', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-10');
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.balance, 34);
    expect(find.text('24 Kelopak'), findsOneWidget);
    expect(find.text('Hasil Sabtu ini'), findsNothing);
    expect(find.text('+10 Kelopak'), findsNothing);
    await untilSheet(tester);
  });

  testWidgets('the spin button ignores taps while spinning', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel();
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await tester.tap(find.text('Sedang berputar'));
    await tester.pump();
    expect(controller.state.history.length, demoHistory.length + 1);
    await untilSheet(tester);
  });

  testWidgets('reduced motion shows the result almost at once', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-3');
    await pumpPage(tester, controller, disableAnimations: true);
    await tapSpin(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResultSheet), findsOneWidget);
  });

  testWidgets('guests see everything and are asked to sign in', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final LocalWheelController controller = localWheel(signedIn: false);
    await pumpPage(tester, controller, size: const Size(390, 2600));
    expect(find.byType(PrizeWheel), findsOneWidget);
    expect(find.text('Peluang & ketentuan'), findsWidgets);
    expect(find.text('Masuk untuk melihat riwayat putaranmu.'), findsOneWidget);
    expect(find.byType(BalanceChip), findsNothing);
    expect(wheelNode(tester), isSemantics(value: 'Masuk untuk memutar'));
    await tester.tap(find.text('Masuk untuk memutar'));
    await tester.pump();
    expect(controller.opened, <String>['login']);
    handle.dispose();
  });

  testWidgets('Thursday counts down to Saturday 00.00 WIB', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel(now: thursday);
    await pumpPage(tester, controller);
    expect(find.text('Dibuka Sabtu, 28 Nov · 00.00 WIB'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Hari'), findsOneWidget);
    expect(find.text('Detik'), findsOneWidget);
    expect(find.text('Putar gratis'), findsNothing);
    await tester.tap(find.text('Belanja sambil menunggu'));
    await tester.pump();
    expect(controller.opened, <String>['shop']);
  });

  testWidgets('"Ingatkan saya" toggles the reminder', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel(now: thursday);
    await pumpPage(tester, controller, size: const Size(390, 1200));
    expect(find.text('Ingatkan saya'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(controller.state.reminderOn, isTrue);
  });

  testWidgets('no reminder switch on the web or for guests', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      localWheel(now: thursday, reminderSupported: false),
      size: const Size(390, 1200),
    );
    expect(find.text('Ingatkan saya'), findsNothing);
    await pumpPage(
      tester,
      localWheel(now: thursday, signedIn: false),
      size: const Size(390, 1200),
    );
    expect(find.text('Ingatkan saya'), findsNothing);
  });

  testWidgets('already spun: this week result and the next opening', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel(
      lastSpinDay: saturdayDay,
      history: <WheelSpinRecord>[
        WheelSpinRecord.fromPrize(
          demoSpinConfig.prizeById('kelopak-3')!,
          day: saturdayDay,
        ),
        ...demoHistory,
      ],
    );
    await pumpPage(tester, controller, size: const Size(390, 1000));
    expect(find.text('Hasil Sabtu ini'), findsOneWidget);
    expect(find.text('Kamu dapat 3 Kelopak'), findsOneWidget);
    expect(find.text('Roda dibuka lagi Sabtu, 5 Des'), findsOneWidget);
    await tester.tap(find.text('Belanja pakai Kelopak'));
    await tester.pump();
    expect(controller.opened, <String>['shop']);
  });

  testWidgets('a product won this week points to the cart', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel(
      lastSpinDay: saturdayDay,
      quota: 2,
      history: <WheelSpinRecord>[
        WheelSpinRecord.fromPrize(
          demoSpinConfig.prizeById('product')!,
          day: saturdayDay,
          productName: demoPrizeProduct.name,
        ),
      ],
    );
    await pumpPage(tester, controller, size: const Size(390, 1000));
    expect(find.text('Kamu menang ${demoPrizeProduct.name}'), findsOneWidget);
    await tester.tap(find.text('Lihat hadiah di keranjang'));
    await tester.pump();
    expect(controller.opened, <String>['cart']);
  });

  testWidgets('promo off explains itself and offers shopping', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final LocalWheelController controller = localWheel(promoActive: false);
    await pumpPage(tester, controller, size: const Size(390, 1000));
    expect(
      find.textContaining('Promo Roda Sabtu sedang tidak aktif'),
      findsOneWidget,
    );
    expect(wheelNode(tester), isSemantics(value: 'Promo sedang tidak aktif'));
    await tester.tap(find.text('Belanja sekarang'));
    await tester.pump();
    expect(controller.opened, <String>['shop']);
    handle.dispose();
  });

  testWidgets('sold-out quota is shown in the strip and the card', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel(quota: 0), size: const Size(390, 1600));
    expect(
      find.bySemanticsLabel('Produk gratis 0% · kuota habis'),
      findsOneWidget,
    );
    expect(find.text('Kuota habis minggu ini'), findsOneWidget);
  });

  testWidgets('a failed spin shows a message and plays the error cue', (
    WidgetTester tester,
  ) async {
    final FailingWheelController controller = FailingWheelController();
    await pumpPage(tester, controller);
    await tapSpin(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Putaran belum terkirim. Cek koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    expect(controller.cues, contains(GameCue.softError));
    expect(find.text('Putar gratis'), findsOneWidget);
  });

  testWidgets('back during a spin asks before leaving', (
    WidgetTester tester,
  ) async {
    int backs = 0;
    final LocalWheelController controller = localWheel();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wheelApp(WheelPage(controller: controller, onBack: () => backs++)),
    );
    await tester.pump();
    await tapSpin(tester);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Roda masih berputar'), findsOneWidget);
    await tester.tap(find.text('Tetap di sini'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(backs, 0);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keluar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(backs, 1);
    await untilSheet(tester);
  });

  testWidgets('back while idle leaves at once', (WidgetTester tester) async {
    int backs = 0;
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wheelApp(WheelPage(controller: localWheel(), onBack: () => backs++)),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump();
    expect(backs, 1);
    expect(find.text('Roda masih berputar'), findsNothing);
  });

  testWidgets('"Aturan" opens the full odds sheet with the terms link', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel();
    await pumpPage(tester, controller);
    await tester.tap(find.byType(GameBarAction).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(oddsFairnessNote), findsWidgets);
    await tester.ensureVisible(find.text('Syarat & ketentuan lengkap').last);
    await tester.pump();
    await tester.tap(find.text('Syarat & ketentuan lengkap').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.opened, <String>['terms']);
  });

  testWidgets('the strip link opens the same odds sheet', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel());
    final Finder link = find.bySemanticsLabel('Peluang & ketentuan').first;
    await Scrollable.ensureVisible(tester.element(link), alignment: 0.5);
    await tester.pump();
    await tester.tap(link);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('sound button toggles the host sound', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel();
    await pumpPage(tester, controller);
    await tester.tap(find.byTooltip('Matikan suara'));
    await tester.pump();
    expect(controller.state.soundOn, isFalse);
    expect(find.byTooltip('Nyalakan suara'), findsOneWidget);
  });

  testWidgets('no sound button when the host has no sound', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel(soundOn: null));
    expect(find.byTooltip('Matikan suara'), findsNothing);
  });

  testWidgets('tapping the prize card opens the product', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel();
    await pumpPage(tester, controller, size: const Size(390, 1600));
    await tester.tap(find.byType(WheelPrizeCard));
    await tester.pump();
    expect(controller.opened, <String>['product:${demoPrizeProduct.code}']);
  });

  testWidgets('the page follows controller changes', (
    WidgetTester tester,
  ) async {
    final LocalWheelController controller = localWheel(now: thursday);
    await pumpPage(tester, controller);
    expect(find.text('Putar gratis'), findsNothing);
    controller.setTimeOffset(const Duration(days: 2));
    await tester.pump();
    expect(find.text('Putar gratis'), findsOneWidget);
  });

  testWidgets('a new controller replaces the old one', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, localWheel(now: thursday));
    await tester.pumpWidget(wheelPageApp(localWheel()));
    await tester.pump();
    expect(find.text('Putar gratis'), findsOneWidget);
  });

  for (final Brightness brightness in Brightness.values) {
    for (final (String, LocalWheelController Function()) entry
        in <(String, LocalWheelController Function())>[
          ('sabtu', localWheel),
          ('kamis', () => localWheel(now: thursday)),
          ('tamu', () => localWheel(signedIn: false)),
          (
            'sudah putar',
            () => localWheel(
              lastSpinDay: saturdayDay,
              history: <WheelSpinRecord>[
                WheelSpinRecord.fromPrize(
                  demoSpinConfig.prizeById('kelopak-10')!,
                  day: saturdayDay,
                ),
              ],
            ),
          ),
        ]) {
      testWidgets('${entry.$1} fits 360 wide at 200% text '
          '(${brightness.name})', (WidgetTester tester) async {
        await pumpPage(
          tester,
          entry.$2(),
          brightness: brightness,
          textScale: 2,
          size: const Size(360, 740),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
