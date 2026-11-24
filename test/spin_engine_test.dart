import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

const SpinConfig threePrizeConfig = SpinConfig(
  version: 'test-3',
  prizes: <SpinPrize>[
    SpinPrize(
      id: 'product',
      kind: PrizeKind.product,
      label: 'Produk gratis',
      kelopak: 0,
      weight: 1000,
    ),
    SpinPrize(
      id: 'kelopak-3',
      kind: PrizeKind.kelopak,
      label: '3 Kelopak',
      kelopak: 3,
      weight: 6000,
    ),
    SpinPrize(
      id: 'kelopak-10',
      kind: PrizeKind.kelopak,
      label: '10 Kelopak',
      kelopak: 10,
      weight: 3000,
    ),
  ],
  shippingNote: 'Gratis ongkir (Demo)',
);

int totalOf(List<SpinOdds> odds) =>
    odds.fold<int>(0, (int sum, SpinOdds entry) => sum + entry.weight);

Map<String, int> weightsById(List<SpinOdds> odds) => <String, int>{
  for (final SpinOdds entry in odds) entry.prize.id: entry.weight,
};

void main() {
  group('demoSpinConfig', () {
    test('matches the demo campaign of SPEC-CONTRACT', () {
      expect(demoSpinConfig.version, 'demo-2026-11');
      expect(demoSpinConfig.shippingNote, 'Gratis ongkir (Demo)');
      final SpinPrize? product = demoSpinConfig.prizeById('product');
      final SpinPrize? kelopak = demoSpinConfig.prizeById('kelopak-3');
      expect(product?.kind, PrizeKind.product);
      expect(product?.weight, 1000);
      expect(kelopak?.kind, PrizeKind.kelopak);
      expect(kelopak?.label, '3 Kelopak');
      expect(kelopak?.kelopak, 3);
      expect(kelopak?.weight, 9000);
      expect(demoSpinConfig.prizeById('unknown'), isNull);
    });
  });

  group('effectiveOdds', () {
    for (final int stock in <int>[0, 1, 5]) {
      test('always sums to 10000 with stock $stock', () {
        expect(
          totalOf(effectiveOdds(demoSpinConfig, productStock: stock)),
          SpinRules.totalWeight,
        );
        expect(
          totalOf(effectiveOdds(threePrizeConfig, productStock: stock)),
          SpinRules.totalWeight,
        );
      });
    }

    test('keeps configured odds while stock lasts', () {
      expect(
        weightsById(effectiveOdds(demoSpinConfig, productStock: 1)),
        <String, int>{'product': 1000, 'kelopak-3': 9000},
      );
      expect(
        weightsById(effectiveOdds(demoSpinConfig, productStock: 5)),
        <String, int>{'product': 1000, 'kelopak-3': 9000},
      );
    });

    test('stock 0 gives the product 0% and Kelopak 100%', () {
      final List<SpinOdds> odds = effectiveOdds(
        demoSpinConfig,
        productStock: 0,
      );
      expect(weightsById(odds), <String, int>{
        'product': 0,
        'kelopak-3': 10000,
      });
      expect(odds.map((SpinOdds e) => e.percentText), <String>['0%', '100%']);
    });

    test('negative stock counts as sold out', () {
      expect(
        weightsById(effectiveOdds(demoSpinConfig, productStock: -2)),
        <String, int>{'product': 0, 'kelopak-3': 10000},
      );
    });

    test('three prizes: freed share goes to Kelopak proportionally', () {
      expect(
        weightsById(effectiveOdds(threePrizeConfig, productStock: 1)),
        <String, int>{'product': 1000, 'kelopak-3': 6000, 'kelopak-10': 3000},
      );
      expect(
        weightsById(effectiveOdds(threePrizeConfig, productStock: 0)),
        <String, int>{'product': 0, 'kelopak-3': 6667, 'kelopak-10': 3333},
      );
    });

    test('normalizes a config that does not sum to 10000', () {
      const SpinConfig uneven = SpinConfig(
        version: 'uneven',
        prizes: <SpinPrize>[
          SpinPrize(
            id: 'a',
            kind: PrizeKind.kelopak,
            label: '1 Kelopak',
            kelopak: 1,
            weight: 1,
          ),
          SpinPrize(
            id: 'b',
            kind: PrizeKind.kelopak,
            label: '2 Kelopak',
            kelopak: 2,
            weight: 1,
          ),
          SpinPrize(
            id: 'c',
            kind: PrizeKind.kelopak,
            label: '5 Kelopak',
            kelopak: 5,
            weight: 1,
          ),
        ],
        shippingNote: '-',
      );
      final List<SpinOdds> odds = effectiveOdds(uneven, productStock: 0);
      expect(totalOf(odds), SpinRules.totalWeight);
      expect(odds.map((SpinOdds e) => e.weight), <int>[3334, 3333, 3333]);
    });

    test('keeps prize order and exposes percent', () {
      final List<SpinOdds> odds = effectiveOdds(
        demoSpinConfig,
        productStock: 1,
      );
      expect(odds.map((SpinOdds e) => e.prize.id), <String>[
        'product',
        'kelopak-3',
      ]);
      expect(odds.first.percent, 10);
      expect(odds.last.percent, 90);
    });

    test('rejects configs that cannot reach 10000 or are malformed', () {
      const SpinConfig productOnly = SpinConfig(
        version: 'product-only',
        prizes: <SpinPrize>[
          SpinPrize(
            id: 'product',
            kind: PrizeKind.product,
            label: 'Produk gratis',
            kelopak: 0,
            weight: 10000,
          ),
        ],
        shippingNote: '-',
      );
      expect(
        () => effectiveOdds(productOnly, productStock: 0),
        throwsArgumentError,
      );
      expect(
        () => effectiveOdds(
          const SpinConfig(
            version: 'empty',
            prizes: <SpinPrize>[],
            shippingNote: '-',
          ),
          productStock: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => effectiveOdds(
          const SpinConfig(
            version: 'duplicate',
            prizes: <SpinPrize>[
              SpinPrize(
                id: 'x',
                kind: PrizeKind.kelopak,
                label: '1 Kelopak',
                kelopak: 1,
                weight: 5000,
              ),
              SpinPrize(
                id: 'x',
                kind: PrizeKind.kelopak,
                label: '2 Kelopak',
                kelopak: 2,
                weight: 5000,
              ),
            ],
            shippingNote: '-',
          ),
          productStock: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => effectiveOdds(
          const SpinConfig(
            version: 'negative',
            prizes: <SpinPrize>[
              SpinPrize(
                id: 'x',
                kind: PrizeKind.kelopak,
                label: '1 Kelopak',
                kelopak: 1,
                weight: -1,
              ),
            ],
            shippingNote: '-',
          ),
          productStock: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('resolveSpin', () {
    String resolve(int stock, int roll) =>
        resolveSpin(demoSpinConfig, productStock: stock, roll: roll).id;

    test('roll 0 and 999 win the product while stock lasts', () {
      expect(resolve(1, 0), 'product');
      expect(resolve(1, 999), 'product');
    });

    test('roll 1000 and 9999 win Kelopak', () {
      expect(resolve(1, 1000), 'kelopak-3');
      expect(resolve(1, 9999), 'kelopak-3');
    });

    test('stock 0 always wins Kelopak', () {
      for (final int roll in <int>[0, 1, 999, 1000, 5000, 9999]) {
        expect(resolve(0, roll), 'kelopak-3');
      }
    });

    test('exactly 1000 of 10000 rolls win the product', () {
      int products = 0;
      for (int roll = 0; roll < SpinRules.totalWeight; roll++) {
        if (resolve(1, roll) == 'product') products++;
      }
      expect(products, 1000);
    });

    test('three prizes follow cumulative odds', () {
      String id(int roll) =>
          resolveSpin(threePrizeConfig, productStock: 1, roll: roll).id;
      expect(id(999), 'product');
      expect(id(1000), 'kelopak-3');
      expect(id(6999), 'kelopak-3');
      expect(id(7000), 'kelopak-10');
      expect(id(9999), 'kelopak-10');
    });

    test('asserts the roll range', () {
      expect(() => resolve(1, -1), throwsA(isA<AssertionError>()));
      expect(() => resolve(1, 10000), throwsA(isA<AssertionError>()));
    });
  });

  group('SpinOdds.percentText', () {
    SpinOdds odds(int weight) =>
        SpinOdds(prize: demoSpinConfig.prizes.last, weight: weight);

    test('formats Indonesian percentages', () {
      expect(odds(1000).percentText, '10%');
      expect(odds(9000).percentText, '90%');
      expect(odds(1250).percentText, '12,5%');
      expect(odds(10000).percentText, '100%');
      expect(odds(0).percentText, '0%');
      expect(odds(1).percentText, '0,01%');
      expect(odds(3333).percentText, '33,33%');
      expect(odds(505).percentText, '5,05%');
    });
  });
}
