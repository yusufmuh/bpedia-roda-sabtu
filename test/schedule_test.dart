import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

/// SPEC-CONTRACT: `wibDay = (utcMillis + 7*3600*1000) ~/ 86400000`.
int wibDayOf(DateTime instant) =>
    (instant.toUtc().millisecondsSinceEpoch + 7 * 3600 * 1000) ~/ 86400000;

/// Noon WIB (05.00 UTC) on the given calendar date.
int wibDayAtNoon(int year, int month, int day) =>
    wibDayOf(DateTime.utc(year, month, day, 5));

void main() {
  group('isSaturdayWib', () {
    test('uses the SPEC day numbers for 27-29 November 2026', () {
      expect(wibDayAtNoon(2026, 11, 27), 20784);
      expect(wibDayAtNoon(2026, 11, 28), 20785);
      expect(wibDayAtNoon(2026, 11, 29), 20786);
    });

    test('Friday 27 Nov 2026 is not Saturday', () {
      expect(isSaturdayWib(wibDayAtNoon(2026, 11, 27)), isFalse);
    });

    test('Saturday 28 Nov 2026 is Saturday', () {
      expect(isSaturdayWib(wibDayAtNoon(2026, 11, 28)), isTrue);
    });

    test('Sunday 29 Nov 2026 is not Saturday', () {
      expect(isSaturdayWib(wibDayAtNoon(2026, 11, 29)), isFalse);
    });

    test('Friday 23.59 WIB is closed, Saturday 00.00 WIB is open', () {
      final int fridayLate = wibDayOf(DateTime.utc(2026, 11, 27, 16, 59));
      final int saturdayStart = wibDayOf(DateTime.utc(2026, 11, 27, 17));
      expect(fridayLate, 20784);
      expect(saturdayStart, 20785);
      expect(isSaturdayWib(fridayLate), isFalse);
      expect(isSaturdayWib(saturdayStart), isTrue);
    });

    test('Saturday 23.59 WIB is open, Sunday 00.00 WIB is closed', () {
      final int saturdayLate = wibDayOf(DateTime.utc(2026, 11, 28, 16, 59));
      final int sundayStart = wibDayOf(DateTime.utc(2026, 11, 28, 17));
      expect(isSaturdayWib(saturdayLate), isTrue);
      expect(isSaturdayWib(sundayStart), isFalse);
    });

    test('repeats every 7 days, also before 1970', () {
      expect(isSaturdayWib(20785 + 7 * 52), isTrue);
      expect(isSaturdayWib(2), isTrue);
      expect(isSaturdayWib(-5), isTrue);
      expect(isSaturdayWib(-4), isFalse);
    });
  });

  group('daysUntilSaturday', () {
    final Map<String, (int, int)> week = <String, (int, int)>{
      'Senin 23 Nov': (wibDayAtNoon(2026, 11, 23), 5),
      'Selasa 24 Nov': (wibDayAtNoon(2026, 11, 24), 4),
      'Rabu 25 Nov': (wibDayAtNoon(2026, 11, 25), 3),
      'Kamis 26 Nov': (wibDayAtNoon(2026, 11, 26), 2),
      'Jumat 27 Nov': (wibDayAtNoon(2026, 11, 27), 1),
      'Sabtu 28 Nov': (wibDayAtNoon(2026, 11, 28), 0),
      'Minggu 29 Nov': (wibDayAtNoon(2026, 11, 29), 6),
    };
    for (final MapEntry<String, (int, int)> day in week.entries) {
      test('${day.key} -> ${day.value.$2} hari', () {
        expect(daysUntilSaturday(day.value.$1), day.value.$2);
      });
    }

    test('lands on a Saturday for every day of a week', () {
      for (int day = 20780; day < 20787; day++) {
        expect(isSaturdayWib(day + daysUntilSaturday(day)), isTrue);
      }
    });
  });

  group('spinEligibility', () {
    const int friday = 20784;
    const int saturday = 20785;
    const int previousSaturday = saturday - 7;

    test('promoInactive wins over every other reason', () {
      expect(
        spinEligibility(
          today: friday,
          lastSpinDay: saturday,
          promoActive: false,
        ),
        SpinEligibility.promoInactive,
      );
      expect(
        spinEligibility(today: saturday, lastSpinDay: null, promoActive: false),
        SpinEligibility.promoInactive,
      );
    });

    test('notSaturday outside Saturday', () {
      expect(
        spinEligibility(today: friday, lastSpinDay: null, promoActive: true),
        SpinEligibility.notSaturday,
      );
    });

    test('alreadySpun after a spin on the same Saturday', () {
      expect(
        spinEligibility(
          today: saturday,
          lastSpinDay: saturday,
          promoActive: true,
        ),
        SpinEligibility.alreadySpun,
      );
    });

    test('alreadySpun when the recorded spin is later than today', () {
      expect(
        spinEligibility(
          today: saturday,
          lastSpinDay: saturday + 7,
          promoActive: true,
        ),
        SpinEligibility.alreadySpun,
      );
    });

    test('available on Saturday without a spin this week', () {
      expect(
        spinEligibility(today: saturday, lastSpinDay: null, promoActive: true),
        SpinEligibility.available,
      );
      expect(
        spinEligibility(
          today: saturday,
          lastSpinDay: previousSaturday,
          promoActive: true,
        ),
        SpinEligibility.available,
      );
    });
  });
}
