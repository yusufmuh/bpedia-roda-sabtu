import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Profil putaran roda (SPEC §6.2): percepat, laju penuh, melambat
/// `easeOutQuart`, lalu mengendap (lewat sedikit dan kembali).
///
/// Kecepatan menyambung di setiap batas fase, jadi tidak ada sentakan.
/// [overshoot] adalah pecahan jarak total yang dilewati sebelum kembali;
/// pakai [WheelSpinCurve.forDistance] untuk mengubah sudut menjadi pecahan.
class WheelSpinCurve extends Curve {
  /// Membuat kurva dengan [overshoot] (pecahan jarak total, ≥ 0).
  const WheelSpinCurve({this.overshoot = 0})
    : assert(overshoot >= 0, 'overshoot tidak boleh negatif');

  /// Kurva untuk putaran sejauh [distance] radian yang lewat
  /// [overshootRadians] sebelum mengendap.
  factory WheelSpinCurve.forDistance(
    double distance, {
    double overshootRadians = settleOvershoot,
  }) => WheelSpinCurve(
    overshoot: distance <= 0 ? 0 : overshootRadians / distance,
  );

  /// Durasi bawaan: 0,4 + 1,2 + 4,0 detik berputar + 0,25 detik mengendap.
  static const Duration duration = Duration(milliseconds: 5850);

  /// Lewat 2 derajat sebelum kembali.
  static const double settleOvershoot = 2 * math.pi / 180;

  /// Bagian waktu fase percepat.
  static const double accelerate = 400 / 5850;

  /// Bagian waktu fase laju penuh.
  static const double cruise = 1200 / 5850;

  /// Bagian waktu fase melambat.
  static const double decelerate = 4000 / 5850;

  /// Bagian waktu fase mengendap.
  static const double settle = 250 / 5850;

  /// Pecahan jarak yang dilewati sebelum kembali.
  final double overshoot;

  /// Waktu (0..1) saat roda mulai mengendap.
  static const double settleStart = accelerate + cruise + decelerate;

  static const double _distanceUnits = accelerate / 2 + cruise + decelerate / 4;

  @override
  double transformInternal(double t) {
    const double a = accelerate;
    const double b = cruise;
    const double c = decelerate;
    const double units = _distanceUnits;
    final double peak = 1 + overshoot;
    if (t < a) return peak * (t * t / (2 * a)) / units;
    if (t < a + b) return peak * (a / 2 + (t - a)) / units;
    if (t < a + b + c) {
      final double u = (t - a - b) / c;
      final double eased = 1 - math.pow(1 - u, 4).toDouble();
      return peak * (a / 2 + b + c / 4 * eased) / units;
    }
    final double u = ((t - settleStart) / settle).clamp(0.0, 1.0);
    return 1 + overshoot * (1 - Curves.easeInOut.transform(u));
  }
}
