import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../kit/motion.dart';

/// Pose diam Bipy yang dihidupkan dengan kode: masuk dengan pegas, lalu
/// bergoyang tak-berulang dari tiga gelombang sinus (naik-turun, ayun,
/// miring, napas). Ganti [image] untuk berganti pose; pose baru masuk
/// dengan pegas lagi.
///
/// Diam saat kurangi gerak atau saat `TickerMode` mati.
class LivelyPose extends StatefulWidget {
  /// Membuat pose setinggi [height] dp.
  const LivelyPose({
    super.key,
    required this.image,
    required this.height,
    this.energy = 1,
    this.semanticLabel = 'Bipy',
  });

  /// Gambar pose (satu gambar, bukan lembar sprite).
  final ImageProvider image;

  /// Tinggi gambar (dp).
  final double height;

  /// Pengali amplitudo: 1 = tenang, 2 = merayakan.
  final double energy;

  /// Label pembaca layar.
  final String semanticLabel;

  /// Simpangan pegas pada waktu [seconds] setelah dorongan awal. Dimulai di
  /// -1 (tertekan), melewati 0, lalu mereda.
  static double springAt(double seconds) {
    const double stiffness = 126;
    const double damping = 7;
    final double omega = math.sqrt(stiffness - damping * damping / 4);
    return -math.exp(-damping / 2 * seconds) * math.cos(omega * seconds);
  }

  /// Transformasi goyang pada waktu [t] detik dengan [energy]. Murni,
  /// dipakai widget dan tes.
  static Matrix4 swayAt(double t, {double energy = 1}) {
    final double w1 = math.sin(2 * math.pi * t / 2.7);
    final double w2 = math.sin(2 * math.pi * t / 4.1);
    final double w3 = math.sin(2 * math.pi * t / 6.3);
    final double pop = springAt(t);
    final double bob = (w1 * 0.7 + w3 * 0.3) * 4 * energy + pop * 22;
    final double sway = (w2 * 0.75 + w1 * 0.25) * 2.5 * energy;
    final double tilt = (w2 * 0.6 + w3 * 0.4) * 0.03 * energy;
    final double breath = w1 * 0.012 * energy;
    final double enter = Curves.easeOutBack.transform(
      (t / 0.42).clamp(0.0, 1.0),
    );
    return Matrix4.identity()
      ..translateByDouble(sway, bob, 0, 1)
      ..rotateZ(tilt)
      ..scaleByDouble(
        (1 + breath - pop * 0.1) * enter,
        (1 - breath + pop * 0.1) * enter,
        1,
        1,
      );
  }

  @override
  State<LivelyPose> createState() => _LivelyPoseState();
}

class _LivelyPoseState extends State<LivelyPose>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(LivelyPose oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image && !_reduce) {
      _ticker.stop();
      _seconds.value = 0;
      _ticker.start();
    }
  }

  void _sync() {
    if (_reduce) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) =>
      _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = Semantics(
      image: true,
      label: widget.semanticLabel,
      child: Image(
        image: widget.image,
        height: widget.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
    if (_reduce) return image;
    return ValueListenableBuilder<double>(
      valueListenable: _seconds,
      child: image,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: (t / 0.16).clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: LivelyPose.swayAt(t, energy: widget.energy),
          child: child,
        ),
      ),
    );
  }
}
