import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/v2_fixtures.dart';

const double epsilon = 1e-9;

SpinPrize kelopakPrize(String id, int weight) => SpinPrize(
  id: id,
  kind: PrizeKind.kelopak,
  label: id,
  kelopak: 1,
  weight: weight,
);

SpinPrize productPrize(String id, int weight) => SpinPrize(
  id: id,
  kind: PrizeKind.product,
  label: id,
  kelopak: 0,
  weight: weight,
);

SpinOdds oddsOf(SpinPrize prize) =>
    SpinOdds(prize: prize, weight: prize.weight);

List<String> idsOf(List<WheelSlice> slices) => <String>[
  for (final WheelSlice slice in slices) slice.prizeId,
];

List<int> weightsOf(List<WheelSlice> slices) => <int>[
  for (final WheelSlice slice in slices) slice.weight,
];

int adjacentSamePrize(List<WheelSlice> slices) {
  if (slices.length < 2) return 0;
  int count = 0;
  for (int i = 0; i < slices.length; i++) {
    if (slices[i].prizeId == slices[(i + 1) % slices.length].prizeId) count++;
  }
  return count;
}

/// Sifat yang wajib dipenuhi setiap roda: menutup 360 derajat tanpa celah,
/// luas tiap hadiah = peluang efektifnya, tidak ada irisan di atas 54
/// derajat, dan irisan berhadiah sama tidak bersebelahan selama jumlah
/// irisan terbanyak tidak melebihi separuh roda.
void expectWheelProperties(
  List<SpinOdds> odds,
  List<WheelSlice> slices, {
  String? reason,
}) {
  expect(slices, isNotEmpty, reason: reason);
  expect(slices.first.startDeg, 0, reason: reason);
  expect(slices.last.endDeg, closeTo(360, epsilon), reason: reason);
  final Map<String, int> perPrize = <String, int>{};
  final Map<String, int> counts = <String, int>{};
  for (int i = 0; i < slices.length; i++) {
    final WheelSlice slice = slices[i];
    expect(slice.index, i, reason: reason);
    if (i > 0) {
      expect(
        slice.startDeg,
        closeTo(slices[i - 1].endDeg, epsilon),
        reason: reason,
      );
    }
    expect(slice.sweepDeg, greaterThan(0), reason: reason);
    expect(slice.sweepDeg, lessThanOrEqualTo(54 + epsilon), reason: reason);
    expect(
      slice.sweepDeg,
      closeTo(slice.weight * 360 / SpinRules.totalWeight, epsilon),
      reason: reason,
    );
    perPrize[slice.prizeId] = (perPrize[slice.prizeId] ?? 0) + slice.weight;
    counts[slice.prizeId] = (counts[slice.prizeId] ?? 0) + 1;
  }
  expect(perPrize, <String, int>{
    for (final SpinOdds entry in odds)
      if (entry.weight > 0) entry.prize.id: entry.weight,
  }, reason: reason);
  final int most = counts.values.reduce(math.max);
  if (slices.length >= 2 && most <= slices.length ~/ 2) {
    expect(adjacentSamePrize(slices), 0, reason: reason);
  }
}

/// Bobot acak berjumlah 10000 untuk [count] hadiah (tiap bobot minimal 1).
List<int> randomWeights(math.Random random, int count) {
  final Set<int> cuts = <int>{};
  while (cuts.length < count - 1) {
    cuts.add(1 + random.nextInt(SpinRules.totalWeight - 1));
  }
  final List<int> bounds = <int>[0, ...cuts.toList()..sort(), 10000];
  return <int>[for (int i = 0; i < count; i++) bounds[i + 1] - bounds[i]];
}

/// [parts] bilangan positif berjumlah [total].
List<int> randomComposition(math.Random random, int total, int parts) {
  final Set<int> cuts = <int>{};
  while (cuts.length < parts - 1) {
    cuts.add(1 + random.nextInt(total - 1));
  }
  final List<int> bounds = <int>[0, ...cuts.toList()..sort(), total];
  return <int>[for (int i = 0; i < parts; i++) bounds[i + 1] - bounds[i]];
}

void main() {
  group('WheelSlice', () {
    const WheelSlice slice = WheelSlice(
      prizeId: 'kelopak-1',
      startDeg: 18,
      sweepDeg: 54,
      index: 1,
    );

    test('turunan sudut: akhir, tengah, radian, bobot', () {
      expect(slice.endDeg, 72);
      expect(slice.centerDeg, 45);
      expect(slice.startRadians, closeTo(math.pi / 10, epsilon));
      expect(slice.sweepRadians, closeTo(3 * math.pi / 10, epsilon));
      expect(slice.endRadians, closeTo(2 * math.pi / 5, epsilon));
      expect(slice.weight, 1500);
    });

    test('kesetaraan nilai', () {
      expect(
        slice,
        const WheelSlice(
          prizeId: 'kelopak-1',
          startDeg: 18,
          sweepDeg: 54,
          index: 1,
        ),
      );
      expect(
        slice.hashCode,
        const WheelSlice(
          prizeId: 'kelopak-1',
          startDeg: 18,
          sweepDeg: 54,
          index: 1,
        ).hashCode,
      );
      expect(
        slice,
        isNot(
          const WheelSlice(
            prizeId: 'kelopak-3',
            startDeg: 18,
            sweepDeg: 54,
            index: 1,
          ),
        ),
      );
      expect(slice.toString(), contains('kelopak-1'));
    });
  });

  group('buildWheelSlices · kampanye demo v3', () {
    test('kuota ada: tata letak KEPUTUSAN-V3 dipakai persis', () {
      final List<WheelSlice> slices = buildWheelSlices(
        demoSpinConfig,
        productQuotaLeft: 3,
      );
      expect(idsOf(slices), <String>[
        'product',
        'kelopak-1',
        'kelopak-3',
        'kelopak-1',
        'kelopak-10',
        'kelopak-5',
        'kelopak-3',
        'kelopak-1',
      ]);
      expect(
        <double>[for (final WheelSlice slice in slices) slice.sweepDeg],
        <double>[18, 54, 54, 54, 18, 54, 54, 54],
      );
      expect(
        <double>[for (final WheelSlice slice in slices) slice.startDeg],
        <double>[0, 18, 72, 126, 180, 198, 252, 306],
      );
      expect(adjacentSamePrize(slices), 0);
      expectWheelProperties(
        effectiveOdds(demoSpinConfig, productStock: 3),
        slices,
      );
    });

    test('sisa kuota berapa pun (selama ada) memberi roda yang sama', () {
      expect(
        buildWheelSlices(demoSpinConfig, productQuotaLeft: 1),
        buildWheelSlices(demoSpinConfig, productQuotaLeft: 250),
      );
    });

    test('kuota habis: produk hilang, 1 Kelopak jadi 50% dalam 4 irisan '
        'berselang', () {
      final List<WheelSlice> slices = buildWheelSlices(
        demoSpinConfig,
        productQuotaLeft: 0,
      );
      expect(idsOf(slices), <String>[
        'kelopak-10',
        'kelopak-1',
        'kelopak-5',
        'kelopak-1',
        'kelopak-3',
        'kelopak-1',
        'kelopak-3',
        'kelopak-1',
      ]);
      expect(weightsOf(slices), <int>[
        500,
        1250,
        1500,
        1250,
        1500,
        1250,
        1500,
        1250,
      ]);
      expect(adjacentSamePrize(slices), 0);
      expectWheelProperties(
        effectiveOdds(demoSpinConfig, productStock: 0),
        slices,
      );
    });

    test('kuota negatif diperlakukan sebagai habis', () {
      expect(
        buildWheelSlices(demoSpinConfig, productQuotaLeft: -4),
        buildWheelSlices(demoSpinConfig, productQuotaLeft: 0),
      );
    });

    test('daftar irisan tidak bisa diubah', () {
      final List<WheelSlice> slices = buildWheelSlices(
        demoSpinConfig,
        productQuotaLeft: 1,
      );
      expect(slices.removeLast, throwsUnsupportedError);
    });
  });

  group('buildWheelSlices · susunan otomatis', () {
    test('kampanye v2 (10% / 90%): produk dulu, lalu enam irisan 54 '
        'derajat', () {
      final List<WheelSlice> slices = buildWheelSlices(
        v2SpinConfig,
        productQuotaLeft: 1,
      );
      expect(idsOf(slices), <String>[
        'product',
        for (int i = 0; i < 6; i++) 'kelopak-3',
      ]);
      expect(weightsOf(slices), <int>[
        1000,
        1500,
        1500,
        1500,
        1500,
        1500,
        1500,
      ]);
      expectWheelProperties(
        effectiveOdds(v2SpinConfig, productStock: 1),
        slices,
      );
    });

    test('satu hadiah menguasai roda: tujuh irisan hampir sama besar', () {
      final List<WheelSlice> slices = buildWheelSlices(
        v2SpinConfig,
        productQuotaLeft: 0,
      );
      expect(idsOf(slices).toSet(), <String>{'kelopak-3'});
      expect(weightsOf(slices), <int>[
        1429,
        1428,
        1429,
        1428,
        1429,
        1428,
        1429,
      ]);
      expectWheelProperties(
        effectiveOdds(v2SpinConfig, productStock: 0),
        slices,
      );
    });

    test('bobot ganjil 2% / 33,33% / 64,67% tetap persis', () {
      final List<SpinOdds> odds = <SpinOdds>[
        oddsOf(productPrize('p', 200)),
        oddsOf(kelopakPrize('a', 3333)),
        oddsOf(kelopakPrize('b', 6467)),
      ];
      final List<WheelSlice> slices = buildWheelSlicesFromOdds(odds);
      expect(slices.first.prizeId, 'p');
      expect(weightsOf(slices).reduce((int a, int b) => a + b), 10000);
      expectWheelProperties(odds, slices);
    });

    test('tanpa hadiah produk: irisan pertama milik hadiah pertama', () {
      final List<SpinOdds> odds = <SpinOdds>[
        oddsOf(kelopakPrize('a', 2000)),
        oddsOf(kelopakPrize('b', 3000)),
        oddsOf(kelopakPrize('c', 5000)),
      ];
      final List<WheelSlice> slices = buildWheelSlicesFromOdds(odds);
      expect(slices.first.prizeId, 'a');
      expect(adjacentSamePrize(slices), 0);
      expectWheelProperties(odds, slices);
    });

    test('hadiah berpeluang 0 tidak digambar', () {
      final List<SpinOdds> odds = <SpinOdds>[
        SpinOdds(prize: productPrize('p', 1000), weight: 0),
        oddsOf(kelopakPrize('a', 4000)),
        oddsOf(kelopakPrize('b', 6000)),
      ];
      final List<WheelSlice> slices = buildWheelSlicesFromOdds(odds);
      expect(idsOf(slices), isNot(contains('p')));
      expect(slices.first.prizeId, 'a');
      expectWheelProperties(odds, slices);
    });

    test('masukan sama memberi keluaran sama', () {
      final List<SpinOdds> odds = effectiveOdds(
        demoSpinConfig,
        productStock: 0,
      );
      expect(buildWheelSlicesFromOdds(odds), buildWheelSlicesFromOdds(odds));
    });

    test('peluang kosong atau semua 0 tidak menghasilkan irisan', () {
      expect(buildWheelSlicesFromOdds(const <SpinOdds>[]), isEmpty);
      expect(
        buildWheelSlicesFromOdds(<SpinOdds>[
          SpinOdds(prize: kelopakPrize('a', 0), weight: 0),
        ]),
        isEmpty,
      );
    });

    test('menolak peluang yang tidak berjumlah 10000, negatif, atau '
        'ber-ID ganda', () {
      expect(
        () => buildWheelSlicesFromOdds(<SpinOdds>[
          oddsOf(kelopakPrize('a', 4000)),
          oddsOf(kelopakPrize('b', 5000)),
        ]),
        throwsArgumentError,
      );
      expect(
        () => buildWheelSlicesFromOdds(<SpinOdds>[
          SpinOdds(prize: kelopakPrize('a', 0), weight: -1),
          oddsOf(kelopakPrize('b', 10001)),
        ]),
        throwsArgumentError,
      );
      expect(
        () => buildWheelSlicesFromOdds(<SpinOdds>[
          oddsOf(kelopakPrize('a', 5000)),
          oddsOf(kelopakPrize('a', 5000)),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('buildWheelSlices · tata letak eksplisit', () {
    final List<SpinOdds> odds = <SpinOdds>[
      oddsOf(productPrize('p', 1000)),
      oddsOf(kelopakPrize('a', 4000)),
      oddsOf(kelopakPrize('b', 5000)),
    ];
    const List<WheelSliceSpec> matching = <WheelSliceSpec>[
      WheelSliceSpec(prizeId: 'b', units: 3),
      WheelSliceSpec(prizeId: 'a', units: 3),
      WheelSliceSpec(prizeId: 'b', units: 3),
      WheelSliceSpec(prizeId: 'a', units: 3),
      WheelSliceSpec(prizeId: 'b', units: 2),
      WheelSliceSpec(prizeId: 'p', units: 2),
      WheelSliceSpec(prizeId: 'b', units: 2),
      WheelSliceSpec(prizeId: 'a', units: 2),
    ];
    final List<WheelSlice> automatic = buildWheelSlicesFromOdds(odds);

    test('cocok dengan peluang: urutan dan lebar dipakai apa adanya', () {
      final List<WheelSlice> slices = buildWheelSlicesFromOdds(
        odds,
        layout: matching,
      );
      expect(idsOf(slices), <String>['b', 'a', 'b', 'a', 'b', 'p', 'b', 'a']);
      expect(
        <double>[for (final WheelSlice slice in slices) slice.sweepDeg],
        <double>[54, 54, 54, 54, 36, 36, 36, 36],
      );
      expect(slices, isNot(automatic));
      expectWheelProperties(odds, slices);
    });

    test('jumlah unit tidak cocok dengan peluang: susunan otomatis', () {
      expect(
        buildWheelSlicesFromOdds(
          odds,
          layout: const <WheelSliceSpec>[
            WheelSliceSpec(prizeId: 'p', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 2),
            WheelSliceSpec(prizeId: 'b', units: 3),
          ],
        ),
        automatic,
      );
    });

    test('irisan lebih dari 3 unit (54 derajat): susunan otomatis', () {
      expect(
        buildWheelSlicesFromOdds(
          odds,
          layout: const <WheelSliceSpec>[
            WheelSliceSpec(prizeId: 'p', units: 2),
            WheelSliceSpec(prizeId: 'a', units: 4),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 1),
            WheelSliceSpec(prizeId: 'b', units: 4),
          ],
        ),
        automatic,
      );
    });

    test('dua irisan bersebelahan berhadiah sama: susunan otomatis', () {
      expect(
        buildWheelSlicesFromOdds(
          odds,
          layout: const <WheelSliceSpec>[
            WheelSliceSpec(prizeId: 'p', units: 2),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 2),
            WheelSliceSpec(prizeId: 'b', units: 1),
          ],
        ),
        automatic,
      );
      // Sambungan 360 -> 0 derajat ikut dihitung.
      expect(
        buildWheelSlicesFromOdds(
          odds,
          layout: const <WheelSliceSpec>[
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 3),
            WheelSliceSpec(prizeId: 'a', units: 3),
            WheelSliceSpec(prizeId: 'b', units: 1),
            WheelSliceSpec(prizeId: 'p', units: 2),
            WheelSliceSpec(prizeId: 'a', units: 2),
            WheelSliceSpec(prizeId: 'b', units: 3),
          ],
        ),
        automatic,
      );
    });

    test('hadiah tak dikenal atau tata letak kosong: susunan otomatis', () {
      expect(
        buildWheelSlicesFromOdds(
          odds,
          layout: const <WheelSliceSpec>[
            ...matching,
            WheelSliceSpec(prizeId: 'x', units: 1),
          ],
        ),
        automatic,
      );
      expect(
        buildWheelSlicesFromOdds(odds, layout: const <WheelSliceSpec>[]),
        automatic,
      );
    });

    test('kuota habis tanpa hadiah cadangan (aturan v2): tata letak demo '
        'tidak cocok lagi, roda disusun otomatis', () {
      final SpinConfig proportional = SpinConfig(
        version: 'tanpa-cadangan',
        prizes: demoSpinConfig.prizes,
        shippingNote: demoSpinConfig.shippingNote,
        wheelLayout: demoSpinConfig.wheelLayout,
      );
      expect(
        buildWheelSlices(proportional, productQuotaLeft: 1),
        buildWheelSlices(demoSpinConfig, productQuotaLeft: 1),
      );
      final List<SpinOdds> soldOut = effectiveOdds(
        proportional,
        productStock: 0,
      );
      final List<WheelSlice> slices = buildWheelSlices(
        proportional,
        productQuotaLeft: 0,
      );
      expect(idsOf(slices), isNot(contains('product')));
      expectWheelProperties(soldOut, slices);
    });
  });

  group('uji sifat acak (benih tetap)', () {
    test('4000 kampanye acak: 360 derajat, luas = peluang efektif, maks. 54 '
        'derajat, tidak bersebelahan bila bisa, deterministik', () {
      final math.Random random = math.Random(20261125);
      int soldOutCases = 0;
      int fallbackCases = 0;
      int unavoidable = 0;
      for (int round = 0; round < 4000; round++) {
        final int count = 1 + random.nextInt(7);
        final List<int> weights = randomWeights(random, count);
        final int productCount = count == 1 ? 0 : random.nextInt(3);
        final List<SpinPrize> prizes = <SpinPrize>[
          for (int i = 0; i < count; i++)
            i < productCount && i < count - 1
                ? productPrize('p$i', weights[i])
                : kelopakPrize('k$i', weights[i]),
        ];
        final List<SpinPrize> kelopak = <SpinPrize>[
          for (final SpinPrize prize in prizes)
            if (prize.kind == PrizeKind.kelopak) prize,
        ];
        final bool withFallback = random.nextBool();
        final SpinConfig config = SpinConfig(
          version: 'acak-$round',
          prizes: prizes,
          shippingNote: '-',
          fallbackPrizeId: withFallback
              ? kelopak[random.nextInt(kelopak.length)].id
              : null,
        );
        final int quota = random.nextInt(3);
        if (quota == 0) soldOutCases++;
        if (quota == 0 && withFallback) fallbackCases++;
        final List<SpinOdds> odds = effectiveOdds(config, productStock: quota);
        final List<WheelSlice> slices = buildWheelSlices(
          config,
          productQuotaLeft: quota,
        );
        expectWheelProperties(odds, slices, reason: 'putaran $round');
        expect(
          buildWheelSlices(config, productQuotaLeft: quota),
          slices,
          reason: 'putaran $round',
        );
        final String anchor = odds
            .firstWhere(
              (SpinOdds entry) =>
                  entry.weight > 0 && entry.prize.kind == PrizeKind.product,
              orElse: () =>
                  odds.firstWhere((SpinOdds entry) => entry.weight > 0),
            )
            .prize
            .id;
        expect(slices.first.prizeId, anchor, reason: 'putaran $round');
        if (adjacentSamePrize(slices) > 0) unavoidable++;
      }
      expect(soldOutCases, greaterThan(1000));
      expect(fallbackCases, greaterThan(400));
      expect(unavoidable, greaterThan(0));
    });

    test('3000 tata letak acak kelipatan 18 derajat: dipakai persis bila '
        'sah, selain itu tetap memenuhi semua sifat', () {
      final math.Random random = math.Random(4112026);
      int verbatim = 0;
      int rearranged = 0;
      for (int round = 0; round < 3000; round++) {
        final int count = 2 + random.nextInt(4);
        final List<int> prizeUnits = randomComposition(random, 20, count);
        final List<SpinPrize> prizes = <SpinPrize>[
          for (int i = 0; i < count; i++)
            i == 0 && random.nextBool()
                ? productPrize('p$i', prizeUnits[i] * 500)
                : kelopakPrize('k$i', prizeUnits[i] * 500),
        ];
        // Tiga dari empat tata letak dibuat rapi (maks. 3 unit, menghindari
        // hadiah yang baru dipasang) supaya banyak yang sah.
        final bool tidy = random.nextInt(4) != 0;
        final List<WheelSliceSpec> layout = <WheelSliceSpec>[];
        final List<int> left = List<int>.of(prizeUnits);
        while (left.any((int units) => units > 0)) {
          final List<int> remaining = <int>[
            for (int i = 0; i < count; i++)
              if (left[i] > 0) i,
          ];
          final List<int> fresh = <int>[
            for (final int i in remaining)
              if (layout.isEmpty || prizes[i].id != layout.last.prizeId) i,
          ];
          final List<int> open = tidy && fresh.isNotEmpty ? fresh : remaining;
          final int pick = open[random.nextInt(open.length)];
          final int units =
              1 + random.nextInt(math.min(left[pick], tidy ? 3 : 4));
          left[pick] -= units;
          layout.add(WheelSliceSpec(prizeId: prizes[pick].id, units: units));
        }
        final SpinConfig config = SpinConfig(
          version: 'tata-letak-$round',
          prizes: prizes,
          shippingNote: '-',
          wheelLayout: layout,
        );
        final List<SpinOdds> odds = effectiveOdds(config, productStock: 1);
        final List<WheelSlice> slices = buildWheelSlices(
          config,
          productQuotaLeft: 1,
        );
        expectWheelProperties(odds, slices, reason: 'putaran $round');
        bool valid = layout.every((WheelSliceSpec spec) => spec.units <= 3);
        for (int i = 0; valid && i < layout.length; i++) {
          valid = layout[i].prizeId != layout[(i + 1) % layout.length].prizeId;
        }
        if (valid) {
          verbatim++;
          expect(idsOf(slices), <String>[
            for (final WheelSliceSpec spec in layout) spec.prizeId,
          ], reason: 'putaran $round');
          expect(weightsOf(slices), <int>[
            for (final WheelSliceSpec spec in layout) spec.units * 500,
          ], reason: 'putaran $round');
        } else {
          rearranged++;
          expect(
            slices,
            buildWheelSlicesFromOdds(odds),
            reason: 'putaran $round',
          );
        }
      }
      expect(verbatim, greaterThan(100));
      expect(rearranged, greaterThan(100));
    });
  });
}
