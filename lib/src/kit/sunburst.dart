import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'festive_palette.dart';
import 'motion.dart';

/// Berkas sinar yang berputar pelan di belakang [child].
///
/// Dilukis oleh satu `CustomPainter`; diam saat kurangi gerak atau saat
/// `TickerMode` mati.
class SunburstRays extends StatefulWidget {
  const SunburstRays({
    super.key,
    this.child,
    this.rayCount = 12,
    this.color = Colors.white,
    this.opacity = 0.10,
    this.period = const Duration(seconds: 40),
    this.center = Alignment.center,
    this.fadeOut = true,
    this.spinning = true,
  }) : assert(rayCount >= 2);

  final Widget? child;
  final int rayCount;
  final Color color;
  final double opacity;

  /// Lama satu putaran penuh.
  final Duration period;
  final Alignment center;

  /// Sinar memudar ke tepi.
  final bool fadeOut;
  final bool spinning;

  @override
  State<SunburstRays> createState() => _SunburstRaysState();
}

class _SunburstRaysState extends State<SunburstRays> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SunburstRays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
    _sync();
  }

  void _sync() => syncRepeat(_controller, enabled: widget.spinning && !reduceMotionOf(context));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RaysPainter(
          turn: _controller,
          rayCount: widget.rayCount,
          color: widget.color.withValues(alpha: widget.opacity),
          center: widget.center,
          fadeOut: widget.fadeOut,
        ),
        child: widget.child,
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.turn,
    required this.rayCount,
    required this.color,
    required this.center,
    required this.fadeOut,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final int rayCount;
  final Color color;
  final Alignment center;
  final bool fadeOut;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final origin = center.alongSize(size);
    final radius = math.max(
      math.max(origin.distance, (origin - Offset(size.width, 0)).distance),
      math.max((origin - Offset(0, size.height)).distance, (origin - size.bottomRight(Offset.zero)).distance),
    );
    final sweep = math.pi / rayCount;
    final path = Path();
    for (var i = 0; i < rayCount; i++) {
      final start = i * 2 * sweep;
      path
        ..moveTo(0, 0)
        ..lineTo(math.cos(start) * radius, math.sin(start) * radius)
        ..lineTo(math.cos(start + sweep) * radius, math.sin(start + sweep) * radius)
        ..close();
    }
    final paint = Paint()..isAntiAlias = true;
    if (fadeOut) {
      paint.shader = ui.Gradient.radial(
        Offset.zero,
        radius,
        <Color>[color, color.withValues(alpha: color.a * 0.55), color.withValues(alpha: 0)],
        const <double>[0, 0.55, 1],
      );
    } else {
      paint.color = color;
    }
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(origin.dx, origin.dy)
      ..rotate(turn.value * 2 * math.pi)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) =>
      oldDelegate.rayCount != rayCount ||
      oldDelegate.color != color ||
      oldDelegate.center != center ||
      oldDelegate.fadeOut != fadeOut;
}

/// Bintang empat sudut yang berkelip di area [child].
class Sparkles extends StatefulWidget {
  const Sparkles({
    super.key,
    this.child,
    this.count = 12,
    this.color = Colors.white,
    this.seed = 3,
    this.minSize = 6,
    this.maxSize = 16,
    this.period = const Duration(milliseconds: 2400),
  }) : assert(count > 0);

  final Widget? child;
  final int count;
  final Color color;
  final int seed;
  final double minSize;
  final double maxSize;

  /// Lama satu siklus kelip.
  final Duration period;

  @override
  State<Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<Sparkles> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);
  late List<_Star> _stars = _build();

  List<_Star> _build() {
    final random = math.Random(widget.seed);
    return List<_Star>.generate(widget.count, (_) {
      return _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: widget.minSize + random.nextDouble() * (widget.maxSize - widget.minSize),
        phase: random.nextDouble(),
        speed: 1 + random.nextInt(2),
      );
    }, growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncRepeat(_controller, enabled: !reduceMotionOf(context));
  }

  @override
  void didUpdateWidget(Sparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count ||
        oldWidget.seed != widget.seed ||
        oldWidget.minSize != widget.minSize ||
        oldWidget.maxSize != widget.maxSize) {
      _stars = _build();
    }
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SparklePainter(phase: _controller, stars: _stars, color: widget.color),
        child: widget.child,
      ),
    );
  }
}

class _Star {
  const _Star({required this.x, required this.y, required this.size, required this.phase, required this.speed});

  final double x;
  final double y;
  final double size;
  final double phase;
  final int speed;
}

/// Jalur bintang empat sudut berjari-jari 1 di titik asal.
Path fourPointStarPath() {
  const waist = 0.16;
  return Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(waist, -waist, 1, 0)
    ..quadraticBezierTo(waist, waist, 0, 1)
    ..quadraticBezierTo(-waist, waist, -1, 0)
    ..quadraticBezierTo(-waist, -waist, 0, -1)
    ..close();
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.phase, required this.stars, required this.color}) : super(repaint: phase);

  final Animation<double> phase;
  final List<_Star> stars;
  final Color color;

  static final Path _unit = fourPointStarPath();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    // Bintang dijaga di dalam kotak supaya tidak terpotong atau meluber.
    var inset = 0.0;
    for (final star in stars) {
      inset = math.max(inset, star.size / 2);
    }
    for (final star in stars) {
      final wave = math.sin((phase.value * star.speed + star.phase) * 2 * math.pi);
      final glow = 0.5 + 0.5 * wave;
      final radius = star.size * (0.45 + 0.55 * glow) / 2;
      paint.color = color.withValues(alpha: color.a * (0.25 + 0.75 * glow));
      canvas
        ..save()
        ..translate(
          inset + star.x * math.max(0, size.width - 2 * inset),
          inset + star.y * math.max(0, size.height - 2 * inset),
        )
        ..scale(radius)
        ..drawPath(_unit, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.stars != stars || oldDelegate.color != color;
}

/// Cincin cahaya berputar di belakang hadiah: pendar lembut, berkas pendek,
/// dan cincin emas bergradasi sapuan.
class GlowRing extends StatefulWidget {
  const GlowRing({
    super.key,
    this.child,
    this.diameter = 220,
    this.color = FestivePalette.goldLight,
    this.period = const Duration(seconds: 9),
    this.rayCount = 16,
  });

  final Widget? child;
  final double diameter;
  final Color color;
  final Duration period;
  final int rayCount;

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncRepeat(_controller, enabled: !reduceMotionOf(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.diameter,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GlowRingPainter(turn: _controller, color: widget.color, rayCount: widget.rayCount),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter({required this.turn, required this.color, required this.rayCount}) : super(repaint: turn);

  final Animation<double> turn;
  final Color color;
  final int rayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final angle = turn.value * 2 * math.pi;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          <Color>[
            Colors.white.withValues(alpha: 0.85),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0),
          ],
          const <double>[0, 0.32, 0.7, 1],
        ),
    );

    // Sinar panjang dan pendek berselang; tiap kelompok memudar habis tepat
    // di ujungnya supaya tidak ada potongan tegas.
    final longRays = Path();
    final shortRays = Path();
    final sweep = math.pi / rayCount;
    const shortReach = 0.8;
    for (var i = 0; i < rayCount; i++) {
      final start = i * 2 * sweep;
      final reach = radius * (i.isEven ? 0.98 : shortReach);
      (i.isEven ? longRays : shortRays)
        ..moveTo(0, 0)
        ..lineTo(math.cos(start) * reach, math.sin(start) * reach)
        ..lineTo(math.cos(start + sweep * 0.7) * reach, math.sin(start + sweep * 0.7) * reach)
        ..close();
    }
    Paint rayPaint(double reach) => Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        radius * reach,
        <Color>[Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
        const <double>[0.2, 1],
      );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..drawPath(longRays, rayPaint(0.98))
      ..drawPath(shortRays, rayPaint(shortReach))
      ..restore();

    final ringRadius = radius * 0.7;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-angle * 1.5)
      ..translate(-center.dx, -center.dy)
      ..drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.045
          ..shader = SweepGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.95),
              color.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.8),
              color.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.95),
            ],
          ).createShader(ringRect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlowRingPainter oldDelegate) => oldDelegate.color != color || oldDelegate.rayCount != rayCount;
}
