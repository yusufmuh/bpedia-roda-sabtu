import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:roda_sabtu/src/kit/sprite_sheet.dart';

import 'support/wheel_harness.dart';

WheelViewState stateOn(
  DateTime now, {
  int? lastSpinDay,
  bool promoActive = true,
  int quota = 3,
  List<WheelSpinRecord> history = const <WheelSpinRecord>[],
}) => WheelViewState(
  signedIn: true,
  today: wheelWibDayOf(now),
  config: demoSpinConfig,
  productQuotaLeft: quota,
  lastSpinDay: lastSpinDay,
  promoActive: promoActive,
  history: history,
);

void main() {
  group('wheelWibDayOf', () {
    test('Saturday 28 Nov 2026 10.00 WIB is a Saturday', () {
      expect(isSaturdayWib(wheelWibDayOf(saturday)), isTrue);
    });

    test('a new WIB day starts at 17.00 UTC', () {
      final DateTime before = DateTime.utc(2026, 11, 27, 16, 59);
      final DateTime after = DateTime.utc(2026, 11, 27, 17);
      expect(wheelWibDayOf(after) - wheelWibDayOf(before), 1);
      expect(isSaturdayWib(wheelWibDayOf(after)), isTrue);
    });
  });

  group('WheelViewState', () {
    test('Saturday without a spin is available', () {
      final WheelViewState state = stateOn(saturday);
      expect(state.eligibility, SpinEligibility.available);
      expect(state.canSpin, isTrue);
    });

    test('Thursday waits for Saturday 28 Nov', () {
      final WheelViewState state = stateOn(thursday);
      expect(state.eligibility, SpinEligibility.notSaturday);
      expect(state.canSpin, isFalse);
      expect(state.nextSaturday, saturdayDay);
      expect(state.openingAt(thursday).dayLabel, 'Sabtu, 28 Nov');
    });

    test('after spinning, the next opening is a week later', () {
      final WheelViewState state = stateOn(saturday, lastSpinDay: saturdayDay);
      expect(state.eligibility, SpinEligibility.alreadySpun);
      expect(state.nextSaturday, saturdayDay + 7);
      expect(state.openingAt(saturday).dayLabel, 'Sabtu, 5 Des');
    });

    test('guests see the page but cannot spin', () {
      final WheelViewState guest = WheelViewState.guest(
        today: saturdayDay,
        config: demoSpinConfig,
        productQuotaLeft: 3,
      );
      expect(guest.signedIn, isFalse);
      expect(guest.eligibility, SpinEligibility.available);
      expect(guest.canSpin, isFalse);
      expect(guest.balance, 0);
      expect(guest.history, isEmpty);
    });

    test('busy blocks a second spin', () {
      expect(stateOn(saturday).copyWith(busy: true).canSpin, isFalse);
    });

    test('promo off wins over every other state', () {
      expect(
        stateOn(saturday, promoActive: false).eligibility,
        SpinEligibility.promoInactive,
      );
    });

    test('odds and slices follow the remaining quota', () {
      final WheelViewState full = stateOn(saturday);
      expect(full.odds.first.prize.id, 'product');
      expect(full.odds.first.weight, 500);
      expect(full.slices.first.prizeId, 'product');
      final WheelViewState empty = stateOn(saturday, quota: 0);
      expect(empty.odds.first.weight, 0);
      expect(
        empty.slices.any((WheelSlice s) => s.prizeId == 'product'),
        isFalse,
      );
      expect(
        empty.odds.firstWhere((SpinOdds o) => o.prize.id == 'kelopak-1').weight,
        5000,
      );
    });

    test('thisWeekSpin finds the record of the current Saturday only', () {
      final WheelSpinRecord now = WheelSpinRecord.fromPrize(
        demoSpinConfig.prizeById('kelopak-3')!,
        day: saturdayDay,
      );
      expect(
        stateOn(
          saturday,
          lastSpinDay: saturdayDay,
          history: <WheelSpinRecord>[now, ...demoHistory],
        ).thisWeekSpin,
        now,
      );
      expect(
        stateOn(
          saturday,
          lastSpinDay: saturdayDay - 7,
          history: demoHistory,
        ).thisWeekSpin,
        isNull,
      );
    });

    test('copyWith can clear the last spin and the product', () {
      final WheelViewState state = stateOn(
        saturday,
        lastSpinDay: saturdayDay,
      ).copyWith(product: demoPrizeProduct);
      final WheelViewState cleared = state.copyWith(
        clearLastSpin: true,
        clearProduct: true,
      );
      expect(cleared.lastSpinDay, isNull);
      expect(cleared.product, isNull);
      expect(cleared.canSpin, isTrue);
    });

    test('equality compares values, history included', () {
      expect(stateOn(saturday), stateOn(saturday));
      expect(stateOn(saturday).hashCode, stateOn(saturday).hashCode);
      expect(stateOn(saturday, history: demoHistory), isNot(stateOn(saturday)));
    });
  });

  group('WheelSpinRecord', () {
    test('labels the day and prefers the product name as title', () {
      final WheelSpinRecord record = WheelSpinRecord.fromPrize(
        demoSpinConfig.prizeById('product')!,
        day: saturdayDay,
        productName: 'Pinkflash Duo Lipgloss',
      );
      expect(record.dayLabel, 'Sabtu, 28 Nov');
      expect(record.title, 'Pinkflash Duo Lipgloss');
      expect(record.kind, PrizeKind.product);
    });

    test('Kelopak records keep their value', () {
      final WheelSpinRecord record = WheelSpinRecord.fromPrize(
        demoSpinConfig.prizeById('kelopak-10')!,
        day: saturdayDay,
      );
      expect(record.kelopak, 10);
      expect(record.title, '10 Kelopak');
    });
  });

  group('WheelArt', () {
    test('art grows with the prize', () {
      SpinPrize prize(String id) => demoSpinConfig.prizeById(id)!;
      expect(WheelArt.forPrize(prize('product')), WheelArt.gift);
      expect(WheelArt.forPrize(prize('kelopak-10')), WheelArt.coinStack10);
      expect(WheelArt.forPrize(prize('kelopak-5')), WheelArt.coinStack5);
      expect(WheelArt.forPrize(prize('kelopak-3')), WheelArt.coinStack3);
      expect(WheelArt.forPrize(prize('kelopak-1')), WheelArt.coinStack1);
    });

    test('sprite sheets match the asset grids', () {
      expect(WheelSprites.dance.frameCount, 42);
      expect(WheelSprites.dance.columns * WheelSprites.dance.rows, 42);
      expect(WheelSprites.peek.frameCount, 18);
      expect(WheelSprites.peek.loopMode, SpriteLoopMode.pingPong);
    });
  });
}
