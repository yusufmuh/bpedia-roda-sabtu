import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'spin_engine.dart';
import 'wheel_slices.dart';

/// One full rotation in radians.
const double fullTurn = 2 * math.pi;

const double _landingMin = 0.15;
const double _landingMax = 0.85;
const int _landingSteps = 1000;

/// Normalizes [angle] into `[0, fullTurn)`.
double normalizeAngle(double angle) {
  final double turn = angle % fullTurn;
  return turn >= fullTurn ? 0 : turn;
}

/// Matematika putaran di atas irisan roda ([WheelSlice]). Sudut putaran
/// dalam radian; putaran `theta` (searah jarum jam) menaruh sudut roda
/// `-theta` di bawah penunjuk jam 12.
@immutable
final class WheelGeometry {
  const WheelGeometry(this.slices);

  /// Geometri untuk [config] dengan sisa kuota produk [productQuotaLeft].
  factory WheelGeometry.fromConfig(
    SpinConfig config, {
    required int productQuotaLeft,
  }) => WheelGeometry(
    buildWheelSlices(config, productQuotaLeft: productQuotaLeft),
  );

  /// Geometri untuk tabel peluang [odds]; [layout] seperti di
  /// [buildWheelSlicesFromOdds].
  factory WheelGeometry.fromOdds(
    List<SpinOdds> odds, {
    List<WheelSliceSpec>? layout,
  }) => WheelGeometry(buildWheelSlicesFromOdds(odds, layout: layout));

  /// Keeps [current] when [next] no longer shows [resultPrizeId] but
  /// [current] does, so a just-won prize stays under the pointer after its
  /// stock reaches zero.
  static WheelGeometry retainResult({
    required WheelGeometry current,
    required WheelGeometry next,
    required String? resultPrizeId,
  }) {
    if (resultPrizeId != null &&
        !next.contains(resultPrizeId) &&
        current.contains(resultPrizeId)) {
      return current;
    }
    return next;
  }

  final List<WheelSlice> slices;

  bool contains(String prizeId) =>
      slices.any((WheelSlice slice) => slice.prizeId == prizeId);

  /// Rotation used before any spin: the first slice centered under the
  /// pointer, so the pointer never rests on a peg.
  double get idleRotation {
    if (slices.isEmpty) return 0;
    final WheelSlice first = slices.first;
    return normalizeAngle(-(first.startRadians + first.sweepRadians / 2));
  }

  /// Wheel angle the pointer lands on for [prizeId]: one of its slices picked
  /// by [landingSeed], at 15%..85% of that slice.
  double? landingAngle(String prizeId, int landingSeed) {
    final List<WheelSlice> targets = <WheelSlice>[
      for (final WheelSlice slice in slices)
        if (slice.prizeId == prizeId) slice,
    ];
    if (targets.isEmpty) return null;
    final int seed = landingSeed % (targets.length * (_landingSteps + 1));
    final WheelSlice target = targets[seed % targets.length];
    final int step = seed ~/ targets.length;
    final double fraction =
        _landingMin + (_landingMax - _landingMin) * step / _landingSteps;
    return target.startRadians + target.sweepRadians * fraction;
  }

  /// Rotation in `[0, fullTurn)` that rests [prizeId] under the pointer.
  double? restRotationFor(String prizeId, int landingSeed) {
    final double? angle = landingAngle(prizeId, landingSeed);
    return angle == null ? null : normalizeAngle(-angle);
  }

  /// End rotation of a spin starting at [from]: [fullTurns] whole turns plus
  /// the clockwise distance to the rest rotation of [prizeId]. An unknown
  /// prize spins whole turns only.
  double spinEndRotation({
    required double from,
    required String prizeId,
    required int landingSeed,
    required int fullTurns,
  }) {
    final double? rest = restRotationFor(prizeId, landingSeed);
    final double delta = rest == null ? 0 : normalizeAngle(rest - from);
    return from + fullTurns * fullTurn + delta;
  }

  /// Slice under the pointer at [rotation].
  WheelSlice? sliceUnderPointer(double rotation) {
    if (slices.isEmpty) return null;
    final double point = normalizeAngle(-rotation);
    for (final WheelSlice slice in slices) {
      if (point < slice.endRadians) return slice;
    }
    return slices.last;
  }

  /// Whether a peg (slice boundary) passes the pointer while rotating
  /// clockwise from [from] to [to].
  bool pegCrossed(double from, double to) {
    if (slices.length < 2 || to <= from) return false;
    for (final WheelSlice slice in slices) {
      final double start = slice.startRadians;
      final int before = ((from + start) / fullTurn).floor();
      final int after = ((to + start) / fullTurn).floor();
      if (after > before) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is WheelGeometry && listEquals(other.slices, slices);

  @override
  int get hashCode => Object.hashAll(slices);
}
