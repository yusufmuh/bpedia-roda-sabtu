import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

void main() {
  group('PRD 2 - Roda Sabtu Logic Tests', () {
    test('saturdayOpen hanya bernilai true pada hari Sabtu dalam masa promo', () {
      // 20785 adalah Sabtu (UTC)
      const saturdayDay = 20785;
      const fridayDay = 20784;
      const sundayDay = 20786;

      expect(saturdayOpen(saturdayDay, first: 20000, endExclusive: 21000), isTrue);
      expect(saturdayOpen(fridayDay, first: 20000, endExclusive: 21000), isFalse);
      expect(saturdayOpen(sundayDay, first: 20000, endExclusive: 21000), isFalse);
    });

    test('saturdayOpen di luar rentang promo bernilai false', () {
      const saturdayDay = 20785;
      expect(saturdayOpen(saturdayDay, first: 20800, endExclusive: 21000), isFalse);
    });

    test('demoProduct menang produk jika roll < 10 dan stok > 0', () {
      expect(demoProduct(remaining: 1, roll: 0), isTrue);
      expect(demoProduct(remaining: 1, roll: 9), isTrue);
      expect(demoProduct(remaining: 1, roll: 10), isFalse);
      expect(demoProduct(remaining: 1, roll: 99), isFalse);
    });

    test('demoProduct gagal produk jika stok kosong meski roll < 10', () {
      expect(demoProduct(remaining: 0, roll: 5), isFalse);
    });

    test('demoProduct melempar RangeError jika roll di luar 0-99', () {
      expect(() => demoProduct(remaining: 1, roll: -1), throwsRangeError);
      expect(() => demoProduct(remaining: 1, roll: 100), throwsRangeError);
    });
  });
}
