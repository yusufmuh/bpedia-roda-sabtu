import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

/// Hari WIB dari tanggal kalender WIB, mis. `wibDayFor(2026, 11, 28)` (Sabtu).
int wibDayFor(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(1970)).inDays;

/// Waktu [hour]:[minute] WIB pada tanggal WIB yang diberikan.
DateTime wibInstant(
  int year,
  int month,
  int day, {
  int hour = 10,
  int minute = 0,
  int second = 0,
}) => DateTime.utc(year, month, day, hour - 7, minute, second);

void main() {
  group('Roda Sabtu opening: one wording everywhere', () {
    // Dibawa dari hub v2 (test/domain/app_state_review_test.dart) dengan
    // asersi yang sama; `state.nextSpinOpening` menjadi `nextWheelOpening`.
    test('whole calendar days until the day before, then clock time', () {
      WheelOpening openingAt(DateTime now) =>
          nextWheelOpening(now: now, lastSpinDay: null);

      WheelOpening opening = openingAt(wibInstant(2026, 11, 25, hour: 2));
      expect(opening.day, wibDayFor(2026, 11, 28));
      expect(opening.daysLeft, 3);
      expect(opening.remainingLabel, '3 hari lagi');
      expect(opening.opensAtLabel, 'Sabtu, 28 Nov · 00.00 WIB');
      expect(opening.dayLabel, 'Sabtu, 28 Nov');

      opening = openingAt(wibInstant(2026, 11, 27, hour: 1, minute: 20));
      expect(opening.daysLeft, 1);
      expect(opening.remainingLabel, '22 jam 40 menit lagi');
      expect(opening.countsClockTime, isTrue);

      expect(
        openingAt(
          wibInstant(2026, 11, 27, hour: 23, minute: 30),
        ).remainingLabel,
        '30 menit lagi',
      );

      expect(
        openingAt(
          wibInstant(2026, 11, 27, hour: 23, minute: 59),
        ).remainingLabel,
        '1 menit lagi',
      );
      expect(
        openingAt(
          wibInstant(2026, 11, 27, hour: 23, minute: 59, second: 30),
        ).remainingLabel,
        'kurang dari 1 menit lagi',
      );

      expect(
        openingAt(wibInstant(2026, 12, 7, hour: 1, minute: 20)).remainingLabel,
        '5 hari lagi',
      );
    });
  });

  group('nextSpinSaturday', () {
    final int saturday = wibDayFor(2026, 11, 28);

    test('hari biasa menuju Sabtu terdekat', () {
      expect(
        nextSpinSaturday(today: wibDayFor(2026, 11, 23), lastSpinDay: null),
        saturday,
      );
      expect(
        nextSpinSaturday(today: wibDayFor(2026, 11, 27), lastSpinDay: null),
        saturday,
      );
      expect(
        nextSpinSaturday(today: wibDayFor(2026, 11, 29), lastSpinDay: null),
        wibDayFor(2026, 12, 5),
      );
    });

    test('hari Sabtu menunjuk Sabtu pekan depan', () {
      expect(
        nextSpinSaturday(today: saturday, lastSpinDay: null),
        wibDayFor(2026, 12, 5),
      );
      expect(
        nextSpinSaturday(today: saturday, lastSpinDay: saturday),
        wibDayFor(2026, 12, 5),
      );
    });

    test('putaran lama tidak menggeser Sabtu berikutnya', () {
      expect(
        nextSpinSaturday(
          today: wibDayFor(2026, 11, 25),
          lastSpinDay: wibDayFor(2026, 11, 21),
        ),
        saturday,
      );
    });

    // Dibawa dari hub v2: 'the next spin Saturday comes after the
    // future-dated spin'.
    test('jam perangkat dimundurkan: Sabtu berikutnya setelah putaran '
        'terakhir', () {
      final int nextWeek = wibDayFor(2026, 12, 5);
      for (final int today in <int>[
        wibDayFor(2026, 11, 21),
        wibDayFor(2026, 11, 25),
        saturday,
      ]) {
        expect(
          nextSpinSaturday(today: today, lastSpinDay: saturday),
          nextWeek,
          reason: 'hari $today',
        );
      }
      expect(
        nextWheelOpening(
          now: wibInstant(2026, 11, 21),
          lastSpinDay: saturday,
        ).remainingLabel,
        '14 hari lagi',
      );
    });

    test('hasilnya selalu Sabtu setelah hari ini', () {
      for (int today = 20700; today < 20760; today++) {
        for (final int? last in <int?>[null, today - 3, today, today + 9]) {
          final int next = nextSpinSaturday(today: today, lastSpinDay: last);
          expect(isSaturdayWib(next), isTrue);
          expect(next, greaterThan(today));
          if (last != null) expect(next, greaterThan(last));
        }
      }
    });
  });

  group('wheelOpening', () {
    final int saturday = wibDayFor(2026, 11, 28);

    test('sisa waktu dihitung sampai 00.00 WIB hari Sabtu', () {
      final WheelOpening opening = wheelOpening(
        saturday: saturday,
        now: wibInstant(2026, 11, 26, hour: 18, minute: 15),
      );
      expect(opening.day, saturday);
      expect(opening.daysLeft, 2);
      expect(opening.timeLeft, const Duration(hours: 29, minutes: 45));
      expect(opening.remainingLabel, '2 hari lagi');
      expect(opening.countsClockTime, isFalse);
    });

    test('tepat tengah malam sehari sebelumnya: 24 jam', () {
      final WheelOpening opening = wheelOpening(
        saturday: saturday,
        now: wibInstant(2026, 11, 27, hour: 0),
      );
      expect(opening.daysLeft, 1);
      expect(opening.timeLeft, const Duration(days: 1));
      expect(opening.remainingLabel, '1 hari lagi');
    });

    test('hari Sabtu itu sendiri atau sesudahnya: sisa waktu nol', () {
      final WheelOpening today = wheelOpening(
        saturday: saturday,
        now: wibInstant(2026, 11, 28, hour: 9),
      );
      expect(today.daysLeft, 0);
      expect(today.timeLeft, Duration.zero);
      expect(today.remainingLabel, 'kurang dari 1 menit lagi');

      final WheelOpening past = wheelOpening(
        saturday: saturday,
        now: wibInstant(2026, 11, 30),
      );
      expect(past.daysLeft, -2);
      expect(past.timeLeft, Duration.zero);
    });

    test('zona waktu DateTime tidak berpengaruh', () {
      final DateTime utc = wibInstant(2026, 11, 27, hour: 20, minute: 5);
      expect(
        wheelOpening(saturday: saturday, now: utc.toLocal()),
        wheelOpening(saturday: saturday, now: utc),
      );
    });

    test('hari berganti pada 00.00 WIB (17.00 UTC)', () {
      expect(
        wheelOpening(
          saturday: saturday,
          now: DateTime.utc(2026, 11, 26, 16, 59, 59),
        ).daysLeft,
        2,
      );
      expect(
        wheelOpening(
          saturday: saturday,
          now: DateTime.utc(2026, 11, 26, 17),
        ).daysLeft,
        1,
      );
    });

    test('geseran hari Mode Demo: waktu aplikasi yang dikirim host', () {
      final DateTime real = wibInstant(2026, 11, 24, hour: 21);
      final WheelOpening shifted = nextWheelOpening(
        now: real.add(const Duration(days: 3)),
        lastSpinDay: null,
      );
      expect(shifted.day, saturday);
      expect(shifted.daysLeft, 1);
      expect(shifted.remainingLabel, '3 jam lagi');
    });

    test('kesetaraan nilai', () {
      const WheelOpening a = WheelOpening(
        day: 20785,
        daysLeft: 3,
        timeLeft: Duration(hours: 60),
      );
      expect(
        a,
        const WheelOpening(
          day: 20785,
          daysLeft: 3,
          timeLeft: Duration(hours: 60),
        ),
      );
      expect(
        a.hashCode,
        const WheelOpening(
          day: 20785,
          daysLeft: 3,
          timeLeft: Duration(hours: 60),
        ).hashCode,
      );
      expect(
        a,
        isNot(
          const WheelOpening(
            day: 20785,
            daysLeft: 2,
            timeLeft: Duration(hours: 60),
          ),
        ),
      );
    });
  });
}
