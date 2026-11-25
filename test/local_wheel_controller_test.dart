import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/wheel_harness.dart';

void main() {
  test('starts on the WIB day of its clock', () {
    expect(localWheel().state.today, saturdayDay);
    expect(localWheel(now: thursday).state.today, saturdayDay - 2);
  });

  test('a Saturday spin records the result, quota and balance', () async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('kelopak-5');
    int notified = 0;
    controller.addListener(() => notified++);
    final WheelSpinResult? result = await controller.spin();
    expect(result, isNotNull);
    expect(result!.prize.id, 'kelopak-5');
    expect(result.balance, 29);
    expect(controller.state.balance, 29);
    expect(controller.state.lastSpinDay, saturdayDay);
    expect(controller.state.eligibility, SpinEligibility.alreadySpun);
    expect(controller.state.history.first.prizeId, 'kelopak-5');
    expect(controller.state.productQuotaLeft, 3);
    expect(notified, greaterThanOrEqualTo(2));
  });

  test('winning the product uses one quota and returns the product', () async {
    final LocalWheelController controller = localWheel()
      ..forceNextPrize('product');
    final WheelSpinResult? result = await controller.spin();
    expect(result!.prize.kind, PrizeKind.product);
    expect(result.product, demoPrizeProduct);
    expect(controller.state.productQuotaLeft, 2);
    expect(controller.state.balance, 24);
    expect(controller.state.history.first.productName, demoPrizeProduct.name);
  });

  test('a second spin on the same Saturday returns null', () async {
    final LocalWheelController controller = localWheel();
    expect(await controller.spin(), isNotNull);
    expect(await controller.spin(), isNull);
    expect(controller.state.history.length, demoHistory.length + 1);
  });

  test('no spin on Thursday, for guests or with the promo off', () async {
    expect(await localWheel(now: thursday).spin(), isNull);
    expect(await localWheel(signedIn: false).spin(), isNull);
    expect(await localWheel(promoActive: false).spin(), isNull);
  });

  test('sold-out quota cannot be forced; the fallback prize is used', () async {
    final LocalWheelController controller = localWheel(quota: 0)
      ..forceNextPrize('product');
    final WheelSpinResult? result = await controller.spin();
    expect(result!.prize.kind, PrizeKind.kelopak);
    expect(controller.state.productQuotaLeft, 0);
  });

  test('draws follow the odds over many spins', () async {
    final Map<String, int> counts = <String, int>{};
    final math.Random random = math.Random(7);
    for (int i = 0; i < 2000; i++) {
      final LocalWheelController controller = LocalWheelController(
        clock: () => saturday,
        random: random,
      );
      final WheelSpinResult? result = await controller.spin();
      counts.update(result!.prize.id, (int v) => v + 1, ifAbsent: () => 1);
    }
    expect(counts['kelopak-1']!, inInclusiveRange(780, 1020));
    expect(counts['kelopak-3']!, inInclusiveRange(500, 700));
    expect(counts['product']!, inInclusiveRange(50, 150));
  });

  test('time offset moves the WIB day for the demo panel', () {
    final LocalWheelController controller = localWheel(now: thursday);
    controller.setTimeOffset(const Duration(days: 2));
    expect(controller.state.today, saturdayDay);
    expect(controller.state.canSpin, isTrue);
    expect(controller.now(), thursday.add(const Duration(days: 2)));
  });

  test('sign in and out switch between member and guest', () {
    final LocalWheelController controller = localWheel(signedIn: false);
    expect(controller.state.signedIn, isFalse);
    controller.signIn(balance: 12);
    expect(controller.state.signedIn, isTrue);
    expect(controller.state.balance, 12);
    controller.signOut();
    expect(controller.state.signedIn, isFalse);
    expect(controller.state.history, isEmpty);
  });

  test('reset, quota and promo setters update the state', () async {
    final LocalWheelController controller = localWheel();
    await controller.spin();
    controller.resetSpin();
    expect(controller.state.canSpin, isTrue);
    controller.setProductQuota(-4);
    expect(controller.state.productQuotaLeft, 0);
    controller.setPromoActive(false);
    expect(controller.state.eligibility, SpinEligibility.promoInactive);
  });

  test('reminder only toggles where supported', () async {
    final LocalWheelController supported = localWheel();
    await supported.setReminder(true);
    expect(supported.state.reminderOn, isTrue);
    final LocalWheelController web = localWheel(reminderSupported: false);
    await web.setReminder(true);
    expect(web.state.reminderOn, isFalse);
  });

  test('navigation and cues are recorded', () {
    final List<String> forwarded = <String>[];
    final LocalWheelController controller = LocalWheelController(
      clock: () => saturday,
      onOpen: forwarded.add,
    );
    controller
      ..openLogin()
      ..openShop()
      ..openCart()
      ..openTerms()
      ..openProduct('P1')
      ..playCue(GameCue.tick);
    expect(controller.opened, <String>[
      'login',
      'shop',
      'cart',
      'terms',
      'product:P1',
    ]);
    expect(forwarded, controller.opened);
    expect(controller.cues, <GameCue>[GameCue.tick]);
  });

  test('latency keeps the state busy until the result arrives', () async {
    final LocalWheelController controller = localWheel(
      latency: const Duration(milliseconds: 20),
    );
    final Future<WheelSpinResult?> pending = controller.spin();
    expect(controller.state.busy, isTrue);
    expect(controller.state.canSpin, isFalse);
    await pending;
    expect(controller.state.busy, isFalse);
  });

  test('sound toggle updates the state', () {
    final LocalWheelController controller = localWheel();
    controller.setSoundOn(false);
    expect(controller.state.soundOn, isFalse);
  });
}
