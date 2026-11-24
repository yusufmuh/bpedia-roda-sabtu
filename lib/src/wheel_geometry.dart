import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'spin_engine.dart';

/// One full rotation in radians.
const double fullTurn = 2 * math.pi;

const int _piecesPerTurn = 4;
const double _landingMin = 0.15;
const double _landingMax = 0.85;
const int _landingSteps = 1000;

/// Normalizes [angle] into `[0, fullTurn)`.
double normalizeAngle(double angle) {
  final double turn = angle % fullTurn;
  return turn >= fullTurn ? 0 : turn;
}

/// Fill role of a wheel segment.
enum SegmentTone { product, primary, secondary }

/// A slice of the wheel. Angles are radians measured clockwise from
/// 12 o'clock while the wheel is at rotation 0.
@immutable
final class WheelSegment {
  const WheelSegment({
    required this.prize,
    required this.start,
    required this.sweep,
    required this.tone,
  });

  final SpinPrize prize;
  final double start;
  final double sweep;
  final SegmentTone tone;

  double get end => start + sweep;

  @override
  bool operator ==(Object other) =>
      other is WheelSegment &&
      other.prize == prize &&
      other.start == start &&
      other.sweep == sweep &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(prize, start, sweep, tone);
}

/// Layout of the wheel: every prize area is proportional to its odds and is
/// split into equal pieces of at most 90 degrees. Kelopak pieces alternate
/// between two tones; product pieces use their own tone. A rotation of
/// `theta` (clockwise) puts the wheel angle `-theta` under the pointer.
@immutable
final class WheelGeometry {
  const WheelGeometry._(this.segments);

  factory WheelGeometry.fromOdds(List<SpinOdds> odds) {
    final List<SpinOdds> visible = <SpinOdds>[
      for (final SpinOdds entry in odds)
        if (entry.weight > 0) entry,
    ];
    final int total = visible.fold<int>(
      0,
      (int sum, SpinOdds entry) => sum + entry.weight,
    );
    if (total <= 0) return const WheelGeometry._(<WheelSegment>[]);
    final List<int> pieces = <int>[
      for (final SpinOdds entry in visible)
        (_piecesPerTurn * entry.weight + total - 1) ~/ total,
    ];
    _alternateAcrossSeam(visible, pieces);
    final List<WheelSegment> segments = <WheelSegment>[];
    double cursor = 0;
    int kelopakPieces = 0;
    for (int i = 0; i < visible.length; i++) {
      final SpinOdds entry = visible[i];
      final double area = fullTurn * entry.weight / total;
      final double sweep = area / pieces[i];
      for (int piece = 0; piece < pieces[i]; piece++) {
        final SegmentTone tone;
        if (entry.prize.kind == PrizeKind.product) {
          tone = SegmentTone.product;
        } else {
          tone = kelopakPieces.isEven
              ? SegmentTone.primary
              : SegmentTone.secondary;
          kelopakPieces++;
        }
        segments.add(
          WheelSegment(
            prize: entry.prize,
            start: cursor + sweep * piece,
            sweep: sweep,
            tone: tone,
          ),
        );
      }
      cursor += area;
    }
    return WheelGeometry._(List<WheelSegment>.unmodifiable(segments));
  }

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

  final List<WheelSegment> segments;

  bool contains(String prizeId) =>
      segments.any((WheelSegment segment) => segment.prize.id == prizeId);

  /// Rotation used before any spin: the first segment centered under the
  /// pointer, so the pointer never rests on a peg.
  double get idleRotation {
    if (segments.isEmpty) return 0;
    final WheelSegment first = segments.first;
    return normalizeAngle(-(first.start + first.sweep / 2));
  }

  /// Wheel angle the pointer lands on for [prizeId]: one of its pieces picked
  /// by [landingSeed], at 15%..85% of that piece.
  double? landingAngle(String prizeId, int landingSeed) {
    final List<WheelSegment> targets = <WheelSegment>[
      for (final WheelSegment segment in segments)
        if (segment.prize.id == prizeId) segment,
    ];
    if (targets.isEmpty) return null;
    final int seed = landingSeed % (targets.length * (_landingSteps + 1));
    final WheelSegment target = targets[seed % targets.length];
    final int step = seed ~/ targets.length;
    final double fraction =
        _landingMin + (_landingMax - _landingMin) * step / _landingSteps;
    return target.start + target.sweep * fraction;
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

  /// Segment under the pointer at [rotation].
  WheelSegment? segmentUnderPointer(double rotation) {
    if (segments.isEmpty) return null;
    final double point = normalizeAngle(-rotation);
    for (final WheelSegment segment in segments) {
      if (point < segment.end) return segment;
    }
    return segments.last;
  }

  /// Whether a peg (piece boundary) passes the pointer while rotating
  /// clockwise from [from] to [to].
  bool pegCrossed(double from, double to) {
    if (segments.length < 2 || to <= from) return false;
    for (final WheelSegment segment in segments) {
      final int before = ((from + segment.start) / fullTurn).floor();
      final int after = ((to + segment.start) / fullTurn).floor();
      if (after > before) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is WheelGeometry && listEquals(other.segments, segments);

  @override
  int get hashCode => Object.hashAll(segments);

  static void _alternateAcrossSeam(List<SpinOdds> visible, List<int> pieces) {
    if (visible.first.prize.kind != PrizeKind.kelopak ||
        visible.last.prize.kind != PrizeKind.kelopak) {
      return;
    }
    int kelopakPieces = 0;
    int widest = -1;
    for (int i = 0; i < visible.length; i++) {
      if (visible[i].prize.kind != PrizeKind.kelopak) continue;
      kelopakPieces += pieces[i];
      if (widest < 0 || visible[i].weight > visible[widest].weight) widest = i;
    }
    if (kelopakPieces.isOdd) pieces[widest]++;
  }
}
