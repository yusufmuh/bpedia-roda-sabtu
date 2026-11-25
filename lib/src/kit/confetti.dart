import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'festive_palette.dart';
import 'motion.dart';

/// Bentuk partikel konfeti.
enum ConfettiShape { rect, circle, petal }

/// Pola semburan.
enum ConfettiStyle {
  /// Menyembur ke atas dari satu titik lalu jatuh.
  burst,

  /// Dua meriam dari kiri dan kanan bawah yang saling menyilang.
  cannons,

  /// Hujan dari tepi atas.
  rain,
}

/// Fisika konfeti murni (tanpa widget): posisi, kecepatan, rotasi, umur.
///
/// Data disimpan di larik bertipe tetap sehingga tidak ada alokasi per frame.
class ConfettiSimulation {
  ConfettiSimulation({required this.capacity, int seed = 7})
      : _random = math.Random(seed),
        _data = Float32List(capacity * stride),
        _shape = Uint8List(capacity),
        _color = Uint8List(capacity);

  /// Jumlah nilai per partikel: x, y, vx, vy, rotasi, laju rotasi, ukuran,
  /// fase guling, laju guling, umur, usia maksimum, fase ayun.
  static const int stride = 12;

  static const double gravity = 1150;
  static const double dragX = 1.7;
  static const double dragY = 1.1;

  final int capacity;
  final math.Random _random;
  final Float32List _data;
  final Uint8List _shape;
  final Uint8List _color;
  int _cursor = 0;
  int _alive = 0;

  Float32List get data => _data;
  int get aliveCount => _alive;
  bool get isActive => _alive > 0;

  ConfettiShape shapeOf(int index) => ConfettiShape.values[_shape[index]];
  int colorOf(int index) => _color[index];

  bool isAlive(int index) {
    final o = index * stride;
    return _data[o + 10] > 0 && _data[o + 9] < _data[o + 10];
  }

  double xOf(int index) => _data[index * stride];
  double yOf(int index) => _data[index * stride + 1];
  double vxOf(int index) => _data[index * stride + 2];
  double vyOf(int index) => _data[index * stride + 3];

  /// Menambah [count] partikel. Partikel tertua ditimpa bila penuh.
  void spawn({
    required ConfettiStyle style,
    required Size area,
    required Offset origin,
    required int count,
    required int colorCount,
    double lifetime = 1.8,
    double power = 1,
  }) {
    for (var i = 0; i < count; i++) {
      final index = _cursor;
      _cursor = (_cursor + 1) % capacity;
      final o = index * stride;
      double x = origin.dx;
      double y = origin.dy;
      double angle;
      double speed;
      double delay = 0;
      switch (style) {
        case ConfettiStyle.burst:
          angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * 2.5;
          speed = (320 + _random.nextDouble() * 560) * power;
        case ConfettiStyle.cannons:
          final left = i.isEven;
          x = left ? -8 : area.width + 8;
          y = area.height * 0.72;
          final aim = left ? -math.pi / 2 + 0.55 : -math.pi / 2 - 0.55;
          angle = aim + (_random.nextDouble() - 0.5) * 0.7;
          speed = (620 + _random.nextDouble() * 620) * power * math.max(0.75, area.width / 390);
        case ConfettiStyle.rain:
          x = _random.nextDouble() * area.width;
          y = -12 - _random.nextDouble() * 40;
          angle = math.pi / 2 + (_random.nextDouble() - 0.5) * 0.6;
          speed = (40 + _random.nextDouble() * 160) * power;
          delay = _random.nextDouble() * 0.5;
      }
      _data[o] = x;
      _data[o + 1] = y;
      _data[o + 2] = math.cos(angle) * speed;
      _data[o + 3] = math.sin(angle) * speed;
      _data[o + 4] = _random.nextDouble() * math.pi * 2;
      _data[o + 5] = (_random.nextDouble() - 0.5) * 9;
      _data[o + 6] = 8 + _random.nextDouble() * 8;
      _data[o + 7] = _random.nextDouble() * math.pi * 2;
      _data[o + 8] = 5 + _random.nextDouble() * 9;
      _data[o + 9] = -delay;
      _data[o + 10] = lifetime * (0.72 + _random.nextDouble() * 0.28);
      _data[o + 11] = _random.nextDouble() * math.pi * 2;
      final roll = _random.nextDouble();
      _shape[index] = (roll < 0.46
              ? ConfettiShape.rect
              : roll < 0.72
                  ? ConfettiShape.circle
                  : ConfettiShape.petal)
          .index;
      _color[index] = _random.nextInt(math.max(1, colorCount));
    }
    _recount();
  }

  /// Memajukan simulasi [dt] detik.
  void step(double dt) {
    final keepX = math.exp(-dragX * dt);
    final keepY = math.exp(-dragY * dt);
    var alive = 0;
    for (var i = 0; i < capacity; i++) {
      final o = i * stride;
      final life = _data[o + 10];
      if (life <= 0) continue;
      final age = _data[o + 9] + dt;
      _data[o + 9] = age;
      if (age >= life) {
        _data[o + 10] = 0;
        continue;
      }
      alive++;
      if (age < 0) continue;
      final vx = _data[o + 2] * keepX;
      final vy = _data[o + 3] * keepY + gravity * dt;
      _data[o + 2] = vx;
      _data[o + 3] = vy;
      final sway = vy > 0 ? math.sin(_data[o + 11] + age * 5.5) * 34 : 0.0;
      _data[o] += (vx + sway) * dt;
      _data[o + 1] += vy * dt;
      _data[o + 4] += _data[o + 5] * dt;
      _data[o + 7] += _data[o + 8] * dt;
    }
    _alive = alive;
  }

  /// Memajukan simulasi [seconds] dalam langkah tetap 1/60 detik, sehingga
  /// lintasan tidak bergantung pada laju bingkai.
  void advance(double seconds) {
    var remaining = seconds;
    while (remaining > 1e-6 && _alive > 0) {
      final dt = math.min(remaining, 1 / 60);
      step(dt);
      remaining -= dt;
    }
  }

  void clear() {
    _data.fillRange(0, _data.length, 0);
    _alive = 0;
    _cursor = 0;
  }

  void _recount() {
    var alive = 0;
    for (var i = 0; i < capacity; i++) {
      if (isAlive(i)) alive++;
    }
    _alive = alive;
  }
}

/// Memicu semburan pada [ConfettiBurst] yang memegang pengendali ini.
class ConfettiController extends ChangeNotifier {
  _ConfettiRequest? _request;
  bool _active = false;

  /// `true` selama masih ada partikel hidup.
  bool get isActive => _active;

  void fire({
    ConfettiStyle style = ConfettiStyle.burst,
    Alignment origin = const Alignment(0, -0.1),
    int? count,
    double power = 1,
  }) {
    _request = _ConfettiRequest(style, origin, count, power);
    notifyListeners();
  }

  _ConfettiRequest? _take() {
    final request = _request;
    _request = null;
    return request;
  }
}

class _ConfettiRequest {
  const _ConfettiRequest(this.style, this.origin, this.count, this.power);

  final ConfettiStyle style;
  final Alignment origin;
  final int? count;
  final double power;
}

/// Lapisan konfeti di atas [child]: partikel persegi, bulat, dan kelopak
/// dengan gravitasi, hambatan udara, rotasi, dan guling, dilukis oleh satu
/// `CustomPainter`.
///
/// Kurangi gerak: taburan diam yang muncul dan memudar (silang-pudar),
/// tanpa lintasan.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.controller,
    this.child,
    this.colors = FestivePalette.confetti,
    this.particleCount = 110,
    this.lifetime = const Duration(milliseconds: 1800),
    this.seed = 7,
    this.onCompleted,
  })  : assert(particleCount >= 1 && particleCount <= 140),
        assert(colors.length > 0 && colors.length <= 255);

  final ConfettiController controller;
  final Widget? child;
  final List<Color> colors;

  /// Partikel per semburan (80–140 untuk perayaan penuh, lebih kecil untuk
  /// konfeti ringan).
  final int particleCount;
  final Duration lifetime;
  final int seed;

  /// Dipanggil saat partikel terakhir padam.
  final VoidCallback? onCompleted;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  static const int _capacity = 280;

  late final Ticker _ticker;
  late ConfettiSimulation _simulation = ConfettiSimulation(capacity: _capacity, seed: widget.seed);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;

  /// Kurangi gerak: 0..1 kemajuan silang-pudar taburan diam, -1 = tidak aktif.
  double _stillProgress = -1;

  double get _lifeSeconds => widget.lifetime.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onFire);
  }

  @override
  void didUpdateWidget(ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onFire);
      oldWidget.controller._active = false;
      widget.controller.addListener(_onFire);
    }
    if (oldWidget.seed != widget.seed) {
      _simulation = ConfettiSimulation(capacity: _capacity, seed: widget.seed);
    }
  }

  void _onFire() {
    final request = widget.controller._take();
    if (request == null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final size = box.size;
    final reduce = reduceMotionOf(context);
    if (reduce) _simulation.clear();
    _simulation.spawn(
      style: request.style,
      area: size,
      origin: request.origin.alongSize(size),
      count: math.min(request.count ?? widget.particleCount, _capacity),
      colorCount: widget.colors.length,
      lifetime: _lifeSeconds,
      power: request.power,
    );
    if (reduce) {
      // Bekukan taburan pada posisi sebar, lalu tampilkan dengan pudar.
      for (var i = 0; i < 28; i++) {
        _simulation.step(1 / 60);
      }
      _stillProgress = 0;
    } else {
      _stillProgress = -1;
    }
    widget.controller._active = true;
    _last = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
    _repaint.value++;
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond, 0.25);
    _last = elapsed;
    if (_stillProgress >= 0) {
      _stillProgress += dt / 1.0;
      if (_stillProgress >= 1) {
        _stillProgress = -1;
        _simulation.clear();
        _finish();
      }
    } else {
      _simulation.advance(dt);
      if (!_simulation.isActive) _finish();
    }
    _repaint.value++;
  }

  void _finish() {
    _ticker.stop();
    widget.controller._active = false;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFire);
    widget.controller._active = false;
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layer = IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(state: this, repaint: _repaint),
          size: Size.infinite,
        ),
      ),
    );
    final child = widget.child;
    if (child == null) return layer;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[child, Positioned.fill(child: layer)],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.state, required Listenable repaint}) : super(repaint: repaint);

  final _ConfettiBurstState state;
  final Paint _paint = Paint()..isAntiAlias = true;

  static final Path _petal = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.85, -0.45, 0.62, 0.72, 0, 1)
    ..cubicTo(-0.62, 0.72, -0.85, -0.45, 0, -1)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final simulation = state._simulation;
    if (!simulation.isActive) return;
    final still = state._stillProgress;
    final stillAlpha = still < 0 ? 1.0 : math.sin(still.clamp(0.0, 1.0) * math.pi).clamp(0.0, 1.0);
    final colors = state.widget.colors;
    final data = simulation.data;
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < simulation.capacity; i++) {
      final o = i * ConfettiSimulation.stride;
      final life = data[o + 10];
      final age = data[o + 9];
      if (life <= 0 || age < 0 || age >= life) continue;
      final remaining = 1 - age / life;
      final fade = still >= 0 ? stillAlpha : (remaining < 0.28 ? remaining / 0.28 : 1.0);
      final flip = math.cos(data[o + 7]);
      final base = colors[simulation.colorOf(i) % colors.length];
      final shaded = flip < 0 ? Color.lerp(base, Colors.black, 0.18)! : base;
      _paint.color = shaded.withValues(alpha: shaded.a * fade);
      final extent = data[o + 6];
      canvas
        ..save()
        ..translate(data[o], data[o + 1])
        ..rotate(data[o + 4]);
      switch (simulation.shapeOf(i)) {
        case ConfettiShape.rect:
          canvas
            ..scale(1, math.max(0.12, flip.abs()))
            ..drawRect(Rect.fromCenter(center: Offset.zero, width: extent, height: extent * 0.62), _paint);
        case ConfettiShape.circle:
          canvas
            ..scale(math.max(0.3, flip.abs()), 1)
            ..drawCircle(Offset.zero, extent * 0.36, _paint);
        case ConfettiShape.petal:
          canvas
            ..scale(extent * 0.5 * math.max(0.25, flip.abs()), extent * 0.72)
            ..drawPath(_petal, _paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
