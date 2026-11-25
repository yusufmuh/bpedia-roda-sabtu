import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/v2_fixtures.dart';

Map<String, int> weightsById(List<SpinOdds> odds) => <String, int>{
  for (final SpinOdds entry in odds) entry.prize.id: entry.weight,
};

int totalOf(List<SpinOdds> odds) =>
    odds.fold<int>(0, (int sum, SpinOdds entry) => sum + entry.weight);

SpinPrize kelopakPrize(String id, int kelopak, int weight) => SpinPrize(
  id: id,
  kind: PrizeKind.kelopak,
  label: '$kelopak Kelopak',
  kelopak: kelopak,
  weight: weight,
);

SpinPrize productPrize(String id, int weight, {String? productCode}) =>
    SpinPrize(
      id: id,
      kind: PrizeKind.product,
      label: 'Produk gratis',
      kelopak: 0,
      weight: weight,
      productCode: productCode,
    );

SpinConfig configOf(
  List<SpinPrize> prizes, {
  String? fallbackPrizeId,
  List<WheelSliceSpec>? wheelLayout,
}) => SpinConfig(
  version: 'tes',
  prizes: prizes,
  shippingNote: '-',
  fallbackPrizeId: fallbackPrizeId,
  wheelLayout: wheelLayout,
);

void main() {
  group('effectiveOdds · kampanye demo v3', () {
    test('kuota ada: peluang sesuai konfigurasi (5/5/15/30/45)', () {
      for (final int stock in <int>[1, 3, 99]) {
        final List<SpinOdds> odds = effectiveOdds(
          demoSpinConfig,
          productStock: stock,
        );
        expect(weightsById(odds), <String, int>{
          'product': 500,
          'kelopak-10': 500,
          'kelopak-5': 1500,
          'kelopak-3': 3000,
          'kelopak-1': 4500,
        });
        expect(odds.map((SpinOdds entry) => entry.percentText), <String>[
          '5%',
          '5%',
          '15%',
          '30%',
          '45%',
        ]);
      }
    });

    test('kuota habis: bagian produk pindah seluruhnya ke 1 Kelopak', () {
      for (final int stock in <int>[0, -1]) {
        final List<SpinOdds> odds = effectiveOdds(
          demoSpinConfig,
          productStock: stock,
        );
        expect(weightsById(odds), <String, int>{
          'product': 0,
          'kelopak-10': 500,
          'kelopak-5': 1500,
          'kelopak-3': 3000,
          'kelopak-1': 5000,
        });
        expect(totalOf(odds), SpinRules.totalWeight);
      }
    });

    test('urutan hadiah tetap urutan konfigurasi', () {
      expect(
        effectiveOdds(
          demoSpinConfig,
          productStock: 0,
        ).map((SpinOdds entry) => entry.prize.id),
        <String>[
          'product',
          'kelopak-10',
          'kelopak-5',
          'kelopak-3',
          'kelopak-1',
        ],
      );
    });
  });

  group('effectiveOdds · hadiah cadangan', () {
    test('tanpa fallbackPrizeId berlaku aturan v2 (proporsional)', () {
      final SpinConfig proportional = configOf(demoSpinConfig.prizes);
      expect(
        weightsById(effectiveOdds(proportional, productStock: 0)),
        <String, int>{
          'product': 0,
          'kelopak-10': 526,
          'kelopak-5': 1579,
          'kelopak-3': 3158,
          'kelopak-1': 4737,
        },
      );
      expect(v2SpinConfig.fallbackPrizeId, isNull);
      expect(v2SpinConfig.fallbackPrize, isNull);
      expect(v2SpinConfig.wheelLayout, isNull);
    });

    test('cadangan tidak berpengaruh selama kuota ada', () {
      final List<SpinPrize> prizes = <SpinPrize>[
        productPrize('product', 1000),
        kelopakPrize('kelopak-3', 3, 6000),
        kelopakPrize('kelopak-10', 10, 3000),
      ];
      expect(
        effectiveOdds(
          configOf(prizes, fallbackPrizeId: 'kelopak-10'),
          productStock: 2,
        ),
        effectiveOdds(configOf(prizes), productStock: 2),
      );
    });

    test('cadangan menerima bobot semua hadiah produk', () {
      final SpinConfig config = configOf(<SpinPrize>[
        productPrize('serum', 300),
        productPrize('lip-tint', 700),
        kelopakPrize('kelopak-5', 5, 4000),
        kelopakPrize('kelopak-1', 1, 5000),
      ], fallbackPrizeId: 'kelopak-5');
      expect(weightsById(effectiveOdds(config, productStock: 0)), <String, int>{
        'serum': 0,
        'lip-tint': 0,
        'kelopak-5': 5000,
        'kelopak-1': 5000,
      });
    });

    test('cadangan berbobot 0 hanya muncul saat kuota habis', () {
      final SpinConfig config = configOf(<SpinPrize>[
        productPrize('product', 2000),
        kelopakPrize('kelopak-5', 5, 8000),
        kelopakPrize('kelopak-1', 1, 0),
      ], fallbackPrizeId: 'kelopak-1');
      expect(weightsById(effectiveOdds(config, productStock: 1)), <String, int>{
        'product': 2000,
        'kelopak-5': 8000,
        'kelopak-1': 0,
      });
      expect(weightsById(effectiveOdds(config, productStock: 0)), <String, int>{
        'product': 0,
        'kelopak-5': 8000,
        'kelopak-1': 2000,
      });
    });

    test('konfigurasi yang tidak berjumlah 10000 tetap dinormalkan', () {
      final SpinConfig config = configOf(<SpinPrize>[
        productPrize('product', 1),
        kelopakPrize('kelopak-3', 3, 1),
        kelopakPrize('kelopak-1', 1, 1),
      ], fallbackPrizeId: 'kelopak-1');
      final List<SpinOdds> odds = effectiveOdds(config, productStock: 0);
      expect(totalOf(odds), SpinRules.totalWeight);
      expect(weightsById(odds), <String, int>{
        'product': 0,
        'kelopak-3': 3333,
        'kelopak-1': 6667,
      });
    });

    test('menolak cadangan yang tidak ada atau bukan hadiah Kelopak', () {
      final List<SpinPrize> prizes = <SpinPrize>[
        productPrize('product', 1000),
        kelopakPrize('kelopak-3', 3, 9000),
      ];
      for (final int stock in <int>[0, 1]) {
        expect(
          () => effectiveOdds(
            configOf(prizes, fallbackPrizeId: 'tidak-ada'),
            productStock: stock,
          ),
          throwsArgumentError,
        );
        expect(
          () => effectiveOdds(
            configOf(prizes, fallbackPrizeId: 'product'),
            productStock: stock,
          ),
          throwsArgumentError,
        );
      }
    });

    test('menolak tata letak yang menyebut hadiah tak dikenal atau 0 unit', () {
      final List<SpinPrize> prizes = <SpinPrize>[
        productPrize('product', 1000),
        kelopakPrize('kelopak-3', 3, 9000),
      ];
      expect(
        () => effectiveOdds(
          configOf(
            prizes,
            wheelLayout: const <WheelSliceSpec>[
              WheelSliceSpec(prizeId: 'kelopak-9', units: 1),
            ],
          ),
          productStock: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildWheelSlices(
          configOf(
            prizes,
            wheelLayout: const <WheelSliceSpec>[
              WheelSliceSpec(prizeId: 'kelopak-3', units: 0),
            ],
          ),
          productQuotaLeft: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('resolveSpin · kampanye demo v3', () {
    String resolve(int stock, int roll) =>
        resolveSpin(demoSpinConfig, productStock: stock, roll: roll).id;

    test('batas roll mengikuti peluang kumulatif saat kuota ada', () {
      expect(resolve(1, 0), 'product');
      expect(resolve(1, 499), 'product');
      expect(resolve(1, 500), 'kelopak-10');
      expect(resolve(1, 999), 'kelopak-10');
      expect(resolve(1, 1000), 'kelopak-5');
      expect(resolve(1, 2499), 'kelopak-5');
      expect(resolve(1, 2500), 'kelopak-3');
      expect(resolve(1, 5499), 'kelopak-3');
      expect(resolve(1, 5500), 'kelopak-1');
      expect(resolve(1, 9999), 'kelopak-1');
    });

    test('kuota habis: produk tidak pernah keluar, roll 5000 ke atas '
        '1 Kelopak', () {
      expect(resolve(0, 0), 'kelopak-10');
      expect(resolve(0, 499), 'kelopak-10');
      expect(resolve(0, 500), 'kelopak-5');
      expect(resolve(0, 1999), 'kelopak-5');
      expect(resolve(0, 2000), 'kelopak-3');
      expect(resolve(0, 4999), 'kelopak-3');
      expect(resolve(0, 5000), 'kelopak-1');
      expect(resolve(0, 9999), 'kelopak-1');
    });

    test('frekuensi atas seluruh 10000 roll sama dengan peluang efektif', () {
      for (final int stock in <int>[1, 0]) {
        final Map<String, int> hits = <String, int>{};
        for (int roll = 0; roll < SpinRules.totalWeight; roll++) {
          final String id = resolve(stock, roll);
          hits[id] = (hits[id] ?? 0) + 1;
        }
        expect(hits, <String, int>{
          for (final SpinOdds entry in effectiveOdds(
            demoSpinConfig,
            productStock: stock,
          ))
            if (entry.weight > 0) entry.prize.id: entry.weight,
        });
      }
    });

    test('luas irisan roda sama dengan frekuensi undian', () {
      for (final int stock in <int>[2, 0]) {
        final Map<String, int> area = <String, int>{};
        for (final WheelSlice slice in buildWheelSlices(
          demoSpinConfig,
          productQuotaLeft: stock,
        )) {
          area[slice.prizeId] = (area[slice.prizeId] ?? 0) + slice.weight;
        }
        expect(area, <String, int>{
          for (final SpinOdds entry in effectiveOdds(
            demoSpinConfig,
            productStock: stock,
          ))
            if (entry.weight > 0) entry.prize.id: entry.weight,
        });
      }
    });
  });

  group('SpinPrize.productCode dan WheelSliceSpec', () {
    test('productCode opsional dan ikut kesetaraan', () {
      final SpinPrize plain = productPrize('product', 500);
      final SpinPrize coded = productPrize(
        'product',
        500,
        productCode: 'P21P03C01000082',
      );
      expect(plain.productCode, isNull);
      expect(coded.productCode, 'P21P03C01000082');
      expect(
        coded,
        productPrize('product', 500, productCode: 'P21P03C01000082'),
      );
      expect(
        coded.hashCode,
        productPrize('product', 500, productCode: 'P21P03C01000082').hashCode,
      );
      expect(coded, isNot(plain));
      expect(coded.toString(), contains('P21P03C01000082'));
      expect(plain.toString(), isNot(contains('productCode')));
    });

    test('hadiah Kelopak tidak butuh kode produk', () {
      for (final SpinPrize prize in demoSpinConfig.prizes) {
        expect(prize.productCode, isNull, reason: prize.id);
      }
    });

    test('WheelSliceSpec: kesetaraan nilai dan satuan unit', () {
      expect(
        const WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
        const WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
      );
      expect(
        const WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
        isNot(const WheelSliceSpec(prizeId: 'kelopak-1', units: 2)),
      );
      expect(SpinRules.wheelUnitWeight, 500);
      expect(SpinRules.maxSliceWeight, 1500);
      expect(SpinRules.totalWeight ~/ SpinRules.wheelUnitWeight, 20);
    });

    test('tata letak demo: 8 irisan, 20 unit, unit per hadiah = peluang', () {
      final List<WheelSliceSpec> layout = demoSpinConfig.wheelLayout!;
      expect(layout, hasLength(8));
      final Map<String, int> units = <String, int>{};
      for (final WheelSliceSpec spec in layout) {
        units[spec.prizeId] = (units[spec.prizeId] ?? 0) + spec.units;
      }
      expect(units, <String, int>{
        for (final SpinPrize prize in demoSpinConfig.prizes)
          prize.id: prize.weight ~/ SpinRules.wheelUnitWeight,
      });
      expect(
        layout.map((WheelSliceSpec spec) => '${spec.prizeId}:${spec.units}'),
        <String>[
          'product:1',
          'kelopak-1:3',
          'kelopak-3:3',
          'kelopak-1:3',
          'kelopak-10:1',
          'kelopak-5:3',
          'kelopak-3:3',
          'kelopak-1:3',
        ],
      );
    });
  });
}
