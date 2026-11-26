import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

int wibDayFor(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(1970)).inDays;

void main() {
  group('weekdayName', () {
    test('pekan 23-29 November 2026', () {
      expect(
        <String>[
          for (int day = 23; day <= 29; day++)
            weekdayName(wibDayFor(2026, 11, day)),
        ],
        <String>[
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ],
      );
    });

    test('hari 0 adalah Kamis; hari negatif tetap benar', () {
      expect(weekdayName(0), 'Kamis');
      expect(weekdayName(-1), 'Rabu');
      expect(weekdayName(-7), 'Kamis');
    });

    test('selalu Sabtu saat isSaturdayWib benar', () {
      for (int day = 20700; day < 20800; day++) {
        expect(weekdayName(day) == 'Sabtu', isSaturdayWib(day), reason: '$day');
      }
    });
  });

  group('spinDayLabel', () {
    test('hari, tanggal, bulan singkat, dan tahun', () {
      expect(spinDayLabel(wibDayFor(2026, 11, 28)), 'Sabtu, 28 Nov 2026');
      expect(spinDayLabel(wibDayFor(2027, 1, 2)), 'Sabtu, 2 Jan 2027');
      expect(spinDayLabel(0), 'Kamis, 1 Jan 1970');
    });
  });

  group('shortDateLabel', () {
    test('tanggal dan bulan singkat Indonesia', () {
      expect(shortDateLabel(wibDayFor(2026, 11, 28)), '28 Nov');
      expect(shortDateLabel(wibDayFor(2026, 12, 5)), '5 Des');
      expect(shortDateLabel(wibDayFor(2027, 1, 2)), '2 Jan');
      expect(shortDateLabel(wibDayFor(2026, 5, 9)), '9 Mei');
      expect(shortDateLabel(wibDayFor(2026, 8, 17)), '17 Agu');
      expect(shortDateLabel(wibDayFor(2026, 10, 31)), '31 Okt');
      expect(shortDateLabel(0), '1 Jan');
    });

    test('29 Februari tahun kabisat', () {
      expect(shortDateLabel(wibDayFor(2028, 2, 29)), '29 Feb');
      expect(shortDateLabel(wibDayFor(2028, 2, 29) + 1), '1 Mar');
    });
  });

  group('countdownLabel', () {
    test('hari dan jam', () {
      expect(countdownLabel(const Duration(days: 2, hours: 3)), '2 hari 3 jam');
      expect(countdownLabel(const Duration(days: 2, minutes: 59)), '2 hari');
      expect(countdownLabel(const Duration(days: 1)), '1 hari');
    });

    test('jam dan menit', () {
      expect(
        countdownLabel(const Duration(hours: 5, minutes: 12)),
        '5 jam 12 menit',
      );
      expect(countdownLabel(const Duration(hours: 5)), '5 jam');
      expect(
        countdownLabel(const Duration(hours: 23, minutes: 59, seconds: 59)),
        '23 jam 59 menit',
      );
    });

    test('menit saja, dan di bawah satu menit', () {
      expect(countdownLabel(const Duration(minutes: 45)), '45 menit');
      expect(countdownLabel(const Duration(minutes: 1)), '1 menit');
      expect(
        countdownLabel(const Duration(seconds: 59)),
        'kurang dari 1 menit',
      );
      expect(countdownLabel(Duration.zero), 'kurang dari 1 menit');
      expect(
        countdownLabel(const Duration(minutes: -5)),
        'kurang dari 1 menit',
      );
    });
  });
}
