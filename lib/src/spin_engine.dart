import 'format.dart';

/// What a prize pays out.
enum PrizeKind { product, kelopak }

/// Constants shared by the engine and the wheel.
abstract final class SpinRules {
  /// Odds are basis points; every effective odds table sums to this value.
  static const int totalWeight = 10000;
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
  });

  final String id;
  final PrizeKind kind;
  final String label;
  final int kelopak;
  final int weight;

  @override
  bool operator ==(Object other) =>
      other is SpinPrize &&
      other.id == id &&
      other.kind == kind &&
      other.label == label &&
      other.kelopak == kelopak &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(id, kind, label, kelopak, weight);

  @override
  String toString() =>
      'SpinPrize($id, ${kind.name}, "$label", kelopak: $kelopak, '
      'weight: $weight)';
}

/// A Roda Sabtu campaign: prizes in wheel order plus the shipping rule that
/// is shown before the spin button.
final class SpinConfig {
  const SpinConfig({
    required this.version,
    required this.prizes,
    required this.shippingNote,
  });

  final String version;
  final List<SpinPrize> prizes;
  final String shippingNote;

  SpinPrize? prizeById(String id) {
    for (final SpinPrize prize in prizes) {
      if (prize.id == id) return prize;
    }
    return null;
  }
}

/// Demo campaign: product 10% (while stock lasts), 3 Kelopak 90%.
const SpinConfig demoSpinConfig = SpinConfig(
  version: 'demo-2026-11',
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
      weight: 9000,
    ),
  ],
  shippingNote: 'Gratis ongkir (Demo)',
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
/// its share goes to the Kelopak prizes in proportion to their weights.
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
