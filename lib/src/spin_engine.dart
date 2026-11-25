import 'format.dart';

/// What a prize pays out.
enum PrizeKind { product, kelopak }

/// Constants shared by the engine and the wheel.
abstract final class SpinRules {
  /// Odds are basis points; every effective odds table sums to this value.
  static const int totalWeight = 10000;

  /// Bobot satu unit tata letak roda: 500 basis poin = 5% = 18 derajat.
  static const int wheelUnitWeight = 500;

  /// Bobot terbesar satu irisan roda: 1500 basis poin = 54 derajat.
  static const int maxSliceWeight = 3 * wheelUnitWeight;
}

/// One prize of a campaign. [weight] is in basis points of
/// [SpinRules.totalWeight]; [kelopak] is 0 for product prizes.
final class SpinPrize {
  const SpinPrize({
    required this.id,
    required this.kind,
    required this.label,
    required this.kelopak,
    required this.weight,
    this.productCode,
  });

  final String id;
  final PrizeKind kind;
  final String label;
  final int kelopak;
  final int weight;

  /// Kode produk katalog yang dihadiahkan. Null untuk hadiah Kelopak, atau
  /// bila host yang menentukan produknya (misalnya bergilir tiap pekan).
  final String? productCode;

  @override
  bool operator ==(Object other) =>
      other is SpinPrize &&
      other.id == id &&
      other.kind == kind &&
      other.label == label &&
      other.kelopak == kelopak &&
      other.weight == weight &&
      other.productCode == productCode;

  @override
  int get hashCode =>
      Object.hash(id, kind, label, kelopak, weight, productCode);

  @override
  String toString() {
    final String? code = productCode;
    return 'SpinPrize($id, ${kind.name}, "$label", kelopak: $kelopak, '
        'weight: $weight${code == null ? '' : ', productCode: $code'})';
  }
}

/// Satu irisan pada tata letak roda yang ditentukan kampanye: hadiah
/// [prizeId] selebar [units] unit. Satu unit = 18 derajat = 5% peluang
/// ([SpinRules.wheelUnitWeight]).
final class WheelSliceSpec {
  const WheelSliceSpec({required this.prizeId, required this.units});

  final String prizeId;
  final int units;

  @override
  bool operator ==(Object other) =>
      other is WheelSliceSpec &&
      other.prizeId == prizeId &&
      other.units == units;

  @override
  int get hashCode => Object.hash(prizeId, units);

  @override
  String toString() => 'WheelSliceSpec($prizeId, $units)';
}

/// A Roda Sabtu campaign: prizes in wheel order plus the shipping rule that
/// is shown before the spin button.
final class SpinConfig {
  const SpinConfig({
    required this.version,
    required this.prizes,
    required this.shippingNote,
    this.fallbackPrizeId,
    this.wheelLayout,
  });

  final String version;
  final List<SpinPrize> prizes;
  final String shippingNote;

  /// Hadiah Kelopak yang menerima seluruh bobot hadiah produk saat kuota
  /// produk habis. Null = aturan v2: bobot produk dibagi proporsional ke
  /// semua hadiah Kelopak.
  final String? fallbackPrizeId;

  /// Urutan irisan roda searah jarum jam, irisan pertama di bawah penunjuk
  /// saat roda diam. Dipakai hanya bila jumlah unit tiap hadiah sama dengan
  /// peluang efektifnya; selain itu (juga bila null) roda disusun otomatis.
  /// Lihat `buildWheelSlices`.
  final List<WheelSliceSpec>? wheelLayout;

  SpinPrize? prizeById(String id) {
    for (final SpinPrize prize in prizes) {
      if (prize.id == id) return prize;
    }
    return null;
  }

  /// Hadiah cadangan saat kuota produk habis, atau null bila tidak diatur.
  SpinPrize? get fallbackPrize {
    final String? id = fallbackPrizeId;
    return id == null ? null : prizeById(id);
  }
}

/// Kampanye contoh v3 (nilai demo, keputusan bisnis): produk gratis 5%
/// selama kuota ada, 10 Kelopak 5%, 5 Kelopak 15%, 3 Kelopak 30%,
/// 1 Kelopak 45%. Kuota habis: bagian produk pindah ke 1 Kelopak.
const SpinConfig demoSpinConfig = SpinConfig(
  version: 'demo-v3-2026-11',
  prizes: <SpinPrize>[
    SpinPrize(
      id: 'product',
      kind: PrizeKind.product,
      label: 'Produk gratis',
      kelopak: 0,
      weight: 500,
    ),
    SpinPrize(
      id: 'kelopak-10',
      kind: PrizeKind.kelopak,
      label: '10 Kelopak',
      kelopak: 10,
      weight: 500,
    ),
    SpinPrize(
      id: 'kelopak-5',
      kind: PrizeKind.kelopak,
      label: '5 Kelopak',
      kelopak: 5,
      weight: 1500,
    ),
    SpinPrize(
      id: 'kelopak-3',
      kind: PrizeKind.kelopak,
      label: '3 Kelopak',
      kelopak: 3,
      weight: 3000,
    ),
    SpinPrize(
      id: 'kelopak-1',
      kind: PrizeKind.kelopak,
      label: '1 Kelopak',
      kelopak: 1,
      weight: 4500,
    ),
  ],
  shippingNote:
      'Dikirim bersama pesanan belanja berikutnya, tanpa ongkir tambahan',
  fallbackPrizeId: 'kelopak-1',
  wheelLayout: <WheelSliceSpec>[
    WheelSliceSpec(prizeId: 'product', units: 1),
    WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
    WheelSliceSpec(prizeId: 'kelopak-3', units: 3),
    WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
    WheelSliceSpec(prizeId: 'kelopak-10', units: 1),
    WheelSliceSpec(prizeId: 'kelopak-5', units: 3),
    WheelSliceSpec(prizeId: 'kelopak-3', units: 3),
    WheelSliceSpec(prizeId: 'kelopak-1', units: 3),
  ],
);

/// The weight a prize really has right now, after stock is applied.
final class SpinOdds {
  const SpinOdds({required this.prize, required this.weight});

  final SpinPrize prize;
  final int weight;

  /// Chance in percent (0..100): `10.0` for 10%.
  double get percent => weight * 100 / SpinRules.totalWeight;

  /// Indonesian percentage text: `10%`, `12,5%`.
  String get percentText => formatPercent(weight);

  @override
  bool operator ==(Object other) =>
      other is SpinOdds && other.prize == prize && other.weight == weight;

  @override
  int get hashCode => Object.hash(prize, weight);

  @override
  String toString() => 'SpinOdds(${prize.id}, $weight)';
}

/// Odds in [config] order. Without stock every product prize drops to 0 and
/// its share goes to the Kelopak prizes in proportion to their weights, or
/// entirely to [SpinConfig.fallbackPrizeId] when the campaign sets one.
/// The weights always sum to [SpinRules.totalWeight] (largest remainder
/// rounding, ties to the earlier prize).
List<SpinOdds> effectiveOdds(SpinConfig config, {required int productStock}) {
  final List<SpinPrize> prizes = config.prizes;
  _checkConfig(config);
  final bool productAvailable = productStock > 0;
  final List<int> base = <int>[
    for (final SpinPrize prize in prizes)
      prize.kind == PrizeKind.product && !productAvailable ? 0 : prize.weight,
  ];
  final String? fallbackId = config.fallbackPrizeId;
  if (!productAvailable && fallbackId != null) {
    int freed = 0;
    for (final SpinPrize prize in prizes) {
      if (prize.kind == PrizeKind.product) freed += prize.weight;
    }
    final int fallbackIndex = prizes.indexWhere(
      (SpinPrize prize) => prize.id == fallbackId,
    );
    base[fallbackIndex] += freed;
  }
  final List<int> weights = _distribute(base, SpinRules.totalWeight, config);
  return List<SpinOdds>.unmodifiable(<SpinOdds>[
    for (int i = 0; i < prizes.length; i++)
      SpinOdds(prize: prizes[i], weight: weights[i]),
  ]);
}

/// Maps [roll] (0..9999, drawn by the caller with a secure RNG) onto the
/// cumulative effective odds. The result is final; the wheel only shows it.
SpinPrize resolveSpin(
  SpinConfig config, {
  required int productStock,
  required int roll,
}) {
  assert(
    roll >= 0 && roll < SpinRules.totalWeight,
    'roll must be within 0..${SpinRules.totalWeight - 1}, got $roll',
  );
  RangeError.checkValueInInterval(roll, 0, SpinRules.totalWeight - 1, 'roll');
  int upper = 0;
  for (final SpinOdds odds in effectiveOdds(
    config,
    productStock: productStock,
  )) {
    upper += odds.weight;
    if (roll < upper) return odds.prize;
  }
  throw StateError('Odds of ${config.version} do not cover roll $roll.');
}

void _checkConfig(SpinConfig config) {
  if (config.prizes.isEmpty) {
    throw ArgumentError.value(config.version, 'config', 'has no prizes');
  }
  final Set<String> ids = <String>{};
  for (final SpinPrize prize in config.prizes) {
    if (prize.weight < 0) {
      throw ArgumentError.value(
        prize.weight,
        'config',
        'prize ${prize.id} has a negative weight',
      );
    }
    if (!ids.add(prize.id)) {
      throw ArgumentError.value(prize.id, 'config', 'prize ids must be unique');
    }
  }
  final String? fallbackId = config.fallbackPrizeId;
  if (fallbackId != null &&
      config.prizeById(fallbackId)?.kind != PrizeKind.kelopak) {
    throw ArgumentError.value(
      fallbackId,
      'config',
      'fallbackPrizeId must name a Kelopak prize of the campaign',
    );
  }
  for (final WheelSliceSpec spec
      in config.wheelLayout ?? const <WheelSliceSpec>[]) {
    if (!ids.contains(spec.prizeId)) {
      throw ArgumentError.value(
        spec.prizeId,
        'config',
        'wheelLayout names a prize that is not in the campaign',
      );
    }
    if (spec.units < 1) {
      throw ArgumentError.value(
        spec.units,
        'config',
        'wheelLayout slice of ${spec.prizeId} needs at least 1 unit',
      );
    }
  }
}

List<int> _distribute(List<int> base, int total, SpinConfig config) {
  final int sum = base.fold<int>(0, (int acc, int weight) => acc + weight);
  if (sum <= 0) {
    throw ArgumentError.value(
      config.version,
      'config',
      'needs at least one Kelopak prize with a positive weight',
    );
  }
  final List<int> result = <int>[
    for (final int weight in base) total * weight ~/ sum,
  ];
  final List<int> remainders = <int>[
    for (final int weight in base) total * weight % sum,
  ];
  int left = total - result.fold<int>(0, (int acc, int part) => acc + part);
  final List<int> order = List<int>.generate(base.length, (int i) => i)
    ..sort((int a, int b) {
      final int byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final int index in order) {
    if (left == 0) break;
    result[index]++;
    left--;
  }
  return result;
}
