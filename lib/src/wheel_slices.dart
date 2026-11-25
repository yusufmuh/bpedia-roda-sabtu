import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'spin_engine.dart';

/// Satu irisan roda. Sudut dalam derajat, searah jarum jam dari arah jam 12
/// saat roda belum berputar. Irisan [index] 0 mulai di 0 derajat.
@immutable
final class WheelSlice {
  const WheelSlice({
    required this.prizeId,
    required this.startDeg,
    required this.sweepDeg,
    required this.index,
  });

  final String prizeId;
  final double startDeg;
  final double sweepDeg;

  /// Urutan irisan searah jarum jam, mulai 0.
  final int index;

  double get endDeg => startDeg + sweepDeg;

  /// Garis tengah irisan: tempat label dan gambar hadiah.
  double get centerDeg => startDeg + sweepDeg / 2;

  double get startRadians => startDeg * math.pi / 180;
  double get sweepRadians => sweepDeg * math.pi / 180;
  double get endRadians => startRadians + sweepRadians;

  /// Bobot irisan dalam basis poin ([SpinRules.totalWeight] = satu putaran).
  int get weight => (sweepDeg * SpinRules.totalWeight / 360).round();

  @override
  bool operator ==(Object other) =>
      other is WheelSlice &&
      other.prizeId == prizeId &&
      other.startDeg == startDeg &&
      other.sweepDeg == sweepDeg &&
      other.index == index;

  @override
  int get hashCode => Object.hash(prizeId, startDeg, sweepDeg, index);

  @override
  String toString() => 'WheelSlice($index, $prizeId, $startDeg +$sweepDeg)';
}

/// Irisan roda untuk [config] dengan sisa kuota produk [productQuotaLeft].
///
/// Luas tiap hadiah persis sama dengan peluang efektifnya
/// ([effectiveOdds]); hadiah berpeluang 0 tidak digambar. Tata letak
/// [SpinConfig.wheelLayout] dipakai apa adanya bila cocok dengan peluang
/// efektif; selain itu irisan disusun otomatis. Lihat
/// [buildWheelSlicesFromOdds].
List<WheelSlice> buildWheelSlices(
  SpinConfig config, {
  required int productQuotaLeft,
}) => buildWheelSlicesFromOdds(
  effectiveOdds(config, productStock: productQuotaLeft),
  layout: config.wheelLayout,
);

/// Irisan roda untuk tabel peluang [odds] (berjumlah
/// [SpinRules.totalWeight], seperti keluaran [effectiveOdds]).
///
/// [layout] dipakai bila jumlah unit tiap hadiah sama dengan bobotnya di
/// [odds], tiap irisan 1 sampai 3 unit, dan tidak ada dua irisan
/// bersebelahan yang berhadiah sama. Selain itu susunan otomatis:
///
/// 1. tiap hadiah dipecah menjadi irisan hampir sama besar, paling lebar
///    [SpinRules.maxSliceWeight] (54 derajat);
/// 2. hadiah dengan irisan terbanyak lebih dulu (seri: urutan [odds]) mengisi
///    posisi genap lalu ganjil, sehingga irisan berhadiah sama tidak
///    bersebelahan selama itu mungkin;
/// 3. roda diputar supaya irisan pertama adalah hadiah produk pertama, atau
///    hadiah pertama di [odds] bila tidak ada produk.
///
/// Hasilnya hanya bergantung pada masukan. [odds] kosong atau semua 0
/// menghasilkan daftar kosong.
List<WheelSlice> buildWheelSlicesFromOdds(
  List<SpinOdds> odds, {
  List<WheelSliceSpec>? layout,
}) {
  final Set<String> ids = <String>{};
  int total = 0;
  for (final SpinOdds entry in odds) {
    if (entry.weight < 0) {
      throw ArgumentError.value(
        entry.weight,
        'odds',
        'prize ${entry.prize.id} has a negative weight',
      );
    }
    if (!ids.add(entry.prize.id)) {
      throw ArgumentError.value(
        entry.prize.id,
        'odds',
        'prize ids must be unique',
      );
    }
    total += entry.weight;
  }
  if (total == 0) return const <WheelSlice>[];
  if (total != SpinRules.totalWeight) {
    throw ArgumentError.value(
      total,
      'odds',
      'weights must sum to ${SpinRules.totalWeight}',
    );
  }
  final List<_Part> parts = _explicitParts(odds, layout) ?? _autoParts(odds);
  final List<WheelSlice> slices = <WheelSlice>[];
  int cursor = 0;
  for (final _Part part in parts) {
    slices.add(
      WheelSlice(
        prizeId: part.prizeId,
        startDeg: cursor * 360 / SpinRules.totalWeight,
        sweepDeg: part.weight * 360 / SpinRules.totalWeight,
        index: slices.length,
      ),
    );
    cursor += part.weight;
  }
  return List<WheelSlice>.unmodifiable(slices);
}

typedef _Part = ({String prizeId, int weight});

List<_Part>? _explicitParts(List<SpinOdds> odds, List<WheelSliceSpec>? layout) {
  if (layout == null || layout.isEmpty) return null;
  const int maxUnits = SpinRules.maxSliceWeight ~/ SpinRules.wheelUnitWeight;
  final Map<String, int> units = <String, int>{};
  for (int i = 0; i < layout.length; i++) {
    final WheelSliceSpec spec = layout[i];
    if (spec.units < 1 || spec.units > maxUnits) return null;
    if (layout.length > 1 &&
        spec.prizeId == layout[(i + 1) % layout.length].prizeId) {
      return null;
    }
    units[spec.prizeId] = (units[spec.prizeId] ?? 0) + spec.units;
  }
  int matched = 0;
  for (final SpinOdds entry in odds) {
    final int? laidOut = units[entry.prize.id];
    if ((laidOut ?? 0) * SpinRules.wheelUnitWeight != entry.weight) return null;
    if (laidOut != null) matched++;
  }
  if (matched != units.length) return null;
  return <_Part>[
    for (final WheelSliceSpec spec in layout)
      (prizeId: spec.prizeId, weight: spec.units * SpinRules.wheelUnitWeight),
  ];
}

List<_Part> _autoParts(List<SpinOdds> odds) {
  final List<SpinOdds> visible = <SpinOdds>[
    for (final SpinOdds entry in odds)
      if (entry.weight > 0) entry,
  ];
  final List<List<int>> pieces = <List<int>>[
    for (final SpinOdds entry in visible) _split(entry.weight),
  ];
  final List<int> ranked = List<int>.generate(visible.length, (int i) => i)
    ..sort((int a, int b) {
      final int byCount = pieces[b].length.compareTo(pieces[a].length);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  final List<_Part> sequence = <_Part>[
    for (final int index in ranked)
      for (final int weight in pieces[index])
        (prizeId: visible[index].prize.id, weight: weight),
  ];
  final int count = sequence.length;
  final List<_Part> ring = List<_Part>.of(sequence);
  int next = 0;
  for (int position = 0; position < count; position += 2) {
    ring[position] = sequence[next++];
  }
  for (int position = 1; position < count; position += 2) {
    ring[position] = sequence[next++];
  }
  final String anchor = visible
      .firstWhere(
        (SpinOdds entry) => entry.prize.kind == PrizeKind.product,
        orElse: () => visible.first,
      )
      .prize
      .id;
  final int shift = ring.indexWhere((_Part part) => part.prizeId == anchor);
  return <_Part>[...ring.skip(shift), ...ring.take(shift)];
}

/// Memecah [weight] menjadi irisan hampir sama besar (selisih paling banyak
/// 1 basis poin), tiap irisan tidak lebih dari [SpinRules.maxSliceWeight].
List<int> _split(int weight) {
  final int count =
      (weight + SpinRules.maxSliceWeight - 1) ~/ SpinRules.maxSliceWeight;
  final int base = weight ~/ count;
  final int extra = weight % count;
  return <int>[for (int i = 0; i < count; i++) base + (i < extra ? 1 : 0)];
}
