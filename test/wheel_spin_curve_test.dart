import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

void main() {
  const WheelSpinCurve curve = WheelSpinCurve(overshoot: 0.01);

  test('starts at 0 and ends exactly at 1', () {
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
  });

  test('phases add up to 5.85 s: 0.4 + 1.2 + 4.0 + 0.25', () {
    expect(WheelSpinCurve.duration, const Duration(milliseconds: 5850));
    expect(
      WheelSpinCurve.accelerate +
          WheelSpinCurve.cruise +
          WheelSpinCurve.decelerate +
          WheelSpinCurve.settle,
      closeTo(1, 1e-9),
    );
  });

  test('moves forward without stopping until the settle phase', () {
    double previous = 0;
    for (int i = 1; i <= 1000; i++) {
      final double t = WheelSpinCurve.settleStart * i / 1000;
      final double value = curve.transform(t);
      expect(value, greaterThan(previous), reason: 't=$t');
      previous = value;
    }
  });

  test('peaks at 1 + overshoot, then eases back to 1', () {
    expect(curve.transform(WheelSpinCurve.settleStart), closeTo(1.01, 1e-9));
    final double mid = curve.transform(
      WheelSpinCurve.settleStart + WheelSpinCurve.settle / 2,
    );
    expect(mid, inExclusiveRange(1, 1.01));
  });

  test('speed is continuous at every phase boundary', () {
    double speedAt(double t) =>
        (curve.transform(t + 1e-6) - curve.transform(t - 1e-6)) / 2e-6;
    for (final double boundary in <double>[
      WheelSpinCurve.accelerate,
      WheelSpinCurve.accelerate + WheelSpinCurve.cruise,
    ]) {
      final double before = speedAt(boundary - 1e-4);
      final double after = speedAt(boundary + 1e-4);
      expect((before - after).abs() / after, lessThan(0.01));
    }
  });

  test('cruise is the fastest phase; deceleration ends near zero speed', () {
    double speedAt(double t) =>
        (curve.transform(t + 1e-5) - curve.transform(t - 1e-5)) / 2e-5;
    final double cruise = speedAt(
      WheelSpinCurve.accelerate + WheelSpinCurve.cruise / 2,
    );
    expect(speedAt(WheelSpinCurve.accelerate / 2), lessThan(cruise));
    expect(speedAt(WheelSpinCurve.settleStart - 1e-4), lessThan(cruise * 0.01));
  });

  test('forDistance turns 2 degrees into a fraction of the spin', () {
    const double distance = 6 * 2 * math.pi;
    final WheelSpinCurve spin = WheelSpinCurve.forDistance(distance);
    expect(spin.overshoot * distance, closeTo(2 * math.pi / 180, 1e-12));
    expect(WheelSpinCurve.forDistance(0).overshoot, 0);
  });

  test('overshoot of 2 degrees never leaves the landing slice', () {
    final WheelGeometry geometry = WheelGeometry.fromConfig(
      demoSpinConfig,
      productQuotaLeft: 3,
    );
    for (final WheelSlice slice in geometry.slices) {
      for (int seed = 0; seed < 200; seed += 7) {
        final double? rest = geometry.restRotationFor(slice.prizeId, seed);
        expect(rest, isNotNull);
        final double past = rest! + WheelSpinCurve.settleOvershoot;
        expect(
          geometry.sliceUnderPointer(past)?.prizeId,
          geometry.sliceUnderPointer(rest)?.prizeId,
        );
      }
    }
  });
}
