import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'festive_palette.dart';
import 'motion.dart';

/// Melukis koin Kelopak vektor (emas dengan emblem tiga kelopak pink).
///
/// [turn] (radian) memutar koin pada sumbu tegak: lebar menyusut mengikuti
/// `cos(turn)` dan tepi koin terlihat sebagai ketebalan.
void paintKelopakCoin(Canvas canvas, Offset center, double radius, {double turn = 0, double opacity = 1}) {
  if (radius <= 0 || opacity <= 0) return;
  final cosine = math.cos(turn);
  final squash = math.max(0.14, cosine.abs());
  final edge = radius * 0.2 * (1 - squash);
  final alpha = opacity.clamp(0.0, 1.0);
  canvas
    ..save()
    ..translate(center.dx, center.dy);

  if (edge > 0.2) {
    final side = math.sin(turn) >= 0 ? 1.0 : -1.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(side * edge, 0), width: radius * 2 * squash, height: radius * 2),
      Paint()..color = FestivePalette.goldDeep.withValues(alpha: alpha),
    );
  }

  canvas.scale(radius * squash, radius);
  final modulate = Color.fromRGBO(255, 255, 255, alpha);
  canvas
    ..drawCircle(Offset.zero, 1, Paint()
      ..shader = _CoinShaders.rim
      ..color = modulate)
    ..drawCircle(Offset.zero, 0.8, Paint()
      ..shader = _CoinShaders.face
      ..color = modulate)
    ..drawCircle(
      Offset.zero,
      0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..color = FestivePalette.goldDeep.withValues(alpha: 0.55 * alpha),
    );

  // Emblem: tiga kelopak tulip.
  for (final (angle, color) in const <(double, Color)>[
    (-0.62, Color(0xFFD81F57)),
    (0.62, Color(0xFFD81F57)),
    (0.0, Color(0xFFFF5C8D)),
  ]) {
    canvas
      ..save()
      ..translate(0, 0.46)
      ..rotate(angle)
      ..drawPath(_CoinShaders.petal, Paint()..color = color.withValues(alpha: alpha))
      ..restore();
  }
  canvas
    ..save()
    ..translate(-0.06, 0.02)
    ..rotate(-0.1)
    ..scale(0.34, 0.6)
    ..translate(0, 0.72)
    ..drawPath(_CoinShaders.petal, Paint()..color = Colors.white.withValues(alpha: 0.28 * alpha))
    ..restore();

  // Sorot kiri atas.
  canvas
    ..save()
    ..translate(-0.36, -0.5)
    ..rotate(-0.62)
    ..drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.62, height: 0.2),
      Paint()..color = Colors.white.withValues(alpha: 0.6 * alpha),
    )
    ..restore()
    ..restore();
}

abstract final class _CoinShaders {
  static final ui.Shader rim = ui.Gradient.linear(
    const Offset(-0.7, -0.8),
    const Offset(0.7, 0.9),
    const <Color>[FestivePalette.goldLight, FestivePalette.gold, FestivePalette.goldDeep],
    const <double>[0, 0.5, 1],
  );

  static final ui.Shader face = ui.Gradient.radial(
    const Offset(-0.28, -0.34),
    1.25,
    const <Color>[Color(0xFFFFEFB8), FestivePalette.gold, Color(0xFFE39C1A)],
    const <double>[0, 0.62, 1],
  );

  /// Kelopak tegak dengan pangkal di titik asal dan ujung di (0, -0.9).
  static final Path petal = Path()
    ..moveTo(0, 0)
    ..cubicTo(0.34, -0.2, 0.3, -0.66, 0, -0.9)
    ..cubicTo(-0.3, -0.66, -0.34, -0.2, 0, 0)
    ..close();
}

/// Koin Kelopak vektor untuk partikel kecil dan lencana saldo.
class KelopakCoin extends StatelessWidget {
  const KelopakCoin({super.key, this.size = 24, this.turn = 0, this.semanticLabel});

  final double size;

  /// Putaran pada sumbu tegak (radian).
  final double turn;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final coin = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _KelopakCoinPainter(turn)),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: coin);
    return Semantics(image: true, label: label, child: coin);
  }
}

class _KelopakCoinPainter extends CustomPainter {
  const _KelopakCoinPainter(this.turn);

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset(0, radius * 0.1)),
        width: radius * 1.9 * math.max(0.14, math.cos(turn).abs()),
        height: radius * 1.9,
      ),
      Paint()
        ..color = const Color(0x33703A00)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12),
    );
    paintKelopakCoin(canvas, size.center(Offset.zero), radius * 0.94, turn: turn);
  }

  @override
  bool shouldRepaint(_KelopakCoinPainter oldDelegate) => oldDelegate.turn != turn;
}

/// Titik pada kurva Bezier kubik untuk `t` 0..1.
Offset cubicBezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final u = 1 - t;
  return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
}

Rect? _globalRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ImageHolder {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? info;

  void resolve(ImageProvider? provider, BuildContext context, VoidCallback onChanged) {
    if (provider == null) {
      dispose();
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    dispose();
    final listener = ImageStreamListener(
      (image, _) {
        info?.dispose();
        info = image;
        onChanged();
      },
      onError: (error, stackTrace) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'kit pesta',
          context: ErrorDescription('saat memuat gambar koin'),
        ));
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
    info?.dispose();
    info = null;
  }
}

void _paintCoin(Canvas canvas, ui.Image? image, Offset center, double radius, double turn, double opacity) {
  if (image == null) {
    paintKelopakCoin(canvas, center, radius, turn: turn, opacity: opacity);
    return;
  }
  final squash = math.max(0.14, math.cos(turn).abs());
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(center: center, width: radius * 2.2 * squash, height: radius * 2.2),
    Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)),
  );
}

/// Memicu koin terbang pada [CoinFlight].
class CoinFlightController {
  _CoinFlightState? _state;

  /// `true` selama masih ada koin di udara.
  bool get isFlying => _state?._coins.isNotEmpty ?? false;

  /// Menerbangkan [count] koin dari [fromKey] (atau titik global
  /// [fromGlobal]) ke pusat widget [toKey].
  ///
  /// Koin menyembur dulu dari asal, lalu melengkung (Bezier kubik) dan
  /// berputar menuju tujuan; koin ke-n berangkat `n × stagger` kemudian.
  /// [onFirstArrive] dipanggil saat koin pertama tiba (saat yang tepat untuk
  /// membalkan chip saldo), [onArrive] untuk tiap koin. Future selesai
  /// setelah koin terakhir tiba. Bila asal/tujuan belum terpasang atau saat
  /// kurangi gerak, lintasan dilewati dan panggilan balik tetap dijalankan.
  Future<void> fly({
    GlobalKey? fromKey,
    Offset? fromGlobal,
    required GlobalKey toKey,
    int count = 8,
    Duration duration = const Duration(milliseconds: 700),
    Duration stagger = const Duration(milliseconds: 40),
    VoidCallback? onFirstArrive,
    ValueChanged<int>? onArrive,
  }) {
    assert(fromKey != null || fromGlobal != null, 'Beri fromKey atau fromGlobal.');
    assert(count > 0);
    final state = _state;
    if (state == null) {
      onFirstArrive?.call();
      for (var i = 0; i < count; i++) {
        onArrive?.call(i);
      }
      return Future<void>.value();
    }
    return state._fly(
      fromKey: fromKey,
      fromGlobal: fromGlobal,
      toKey: toKey,
      count: count,
      duration: duration,
      stagger: stagger,
      onFirstArrive: onFirstArrive,
      onArrive: onArrive,
    );
  }
}

class _FlyingCoin {
  _FlyingCoin({
    required this.batch,
    required this.index,
    required this.delay,
    required this.duration,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.spin,
    required this.phase,
    required this.scale,
  });

  final _FlightBatch batch;
  final int index;
  final double delay;
  final double duration;
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset p3;
  final double spin;
  final double phase;
  final double scale;
  bool arrived = false;
}

class _FlightBatch {
  _FlightBatch(this.remaining, this.onFirstArrive, this.onArrive);

  int remaining;
  final VoidCallback? onFirstArrive;
  final ValueChanged<int>? onArrive;
  final Completer<void> completer = Completer<void>();
  bool firstArrived = false;
  double age = 0;

  /// Kurangi gerak: koin diam yang muncul dan memudar di tujuan.
  bool still = false;
}

/// Lapisan koin terbang di atas [child].
///
/// Pasang di sekitar halaman game; asal dan tujuan ditunjuk dengan
/// `GlobalKey` sehingga tata letak bebas. Semua koin dilukis oleh satu
/// `CustomPainter`. Memakai [image] (mis. `assets/art/coin.webp`) bila diberi,
/// selain itu koin vektor [KelopakCoin].
class CoinFlight extends StatefulWidget {
  const CoinFlight({
    super.key,
    required this.controller,
    required this.child,
    this.image,
    this.coinSize = 30,
    this.seed = 11,
  });

  final CoinFlightController controller;
  final Widget child;
  final ImageProvider? image;
  final double coinSize;
  final int seed;

  @override
  State<CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<CoinFlight> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final List<_FlyingCoin> _coins = <_FlyingCoin>[];
  final List<_FlightBatch> _batches = <_FlightBatch>[];
  final _ImageHolder _image = _ImageHolder();
  late math.Random _random = math.Random(widget.seed);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _image.resolve(widget.image, context, () => _repaint.value++);
  }

  @override
  void didUpdateWidget(CoinFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    if (oldWidget.image != widget.image) {
      _image.resolve(widget.image, context, () => _repaint.value++);
    }
    if (oldWidget.seed != widget.seed) _random = math.Random(widget.seed);
  }

  Future<void> _fly({
    required GlobalKey? fromKey,
    required Offset? fromGlobal,
    required GlobalKey toKey,
    required int count,
    required Duration duration,
    required Duration stagger,
    required VoidCallback? onFirstArrive,
    required ValueChanged<int>? onArrive,
  }) {
    final layer = context.findRenderObject();
    final target = _globalRectOf(toKey);
    final source = fromGlobal ?? (fromKey == null ? null : _globalRectOf(fromKey)?.center);
    final batch = _FlightBatch(count, onFirstArrive, onArrive);
    if (layer is! RenderBox || !layer.hasSize || target == null || source == null) {
      _completeBatch(batch, skipped: true);
      return batch.completer.future;
    }
    final start = layer.globalToLocal(source);
    final end = layer.globalToLocal(target.center);
    if (reduceMotionOf(context)) {
      batch.still = true;
      _coins.add(_FlyingCoin(
        batch: batch,
        index: 0,
        delay: 0,
        duration: 0.2,
        p0: end,
        p1: end,
        p2: end,
        p3: end,
        spin: 0,
        phase: 0,
        scale: 1,
      ));
    } else {
      final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
      final gap = stagger.inMicroseconds / Duration.microsecondsPerSecond;
      final travel = end - start;
      final distance = math.max(travel.distance, 1.0);
      final normal = Offset(-travel.dy, travel.dx) / distance;
      for (var i = 0; i < count; i++) {
        final angle = _random.nextDouble() * math.pi * 2;
        final reach = 46 + _random.nextDouble() * 54;
        final pop = Offset(math.cos(angle), math.sin(angle) * 0.8 - 0.55) * reach;
        final bend = (_random.nextDouble() - 0.5) * math.min(distance * 0.5, 150);
        _coins.add(_FlyingCoin(
          batch: batch,
          index: i,
          delay: i * gap,
          duration: seconds,
          p0: start,
          p1: start + pop * 2.1,
          p2: start + travel * 0.62 + normal * bend + const Offset(0, -34),
          p3: end,
          spin: (5 + _random.nextDouble() * 5) * (_random.nextBool() ? 1 : -1),
          phase: _random.nextDouble() * math.pi * 2,
          scale: 0.86 + _random.nextDouble() * 0.3,
        ));
      }
    }
    _batches.add(batch);
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    _repaint.value++;
    return batch.completer.future;
  }

  /// Panggilan balik batch yang lintasannya dilewati (asal/tujuan belum
  /// terpasang) atau diganti koin diam (kurangi gerak).
  void _completeBatch(_FlightBatch batch, {bool skipped = false}) {
    if (skipped || batch.still) {
      batch.onFirstArrive?.call();
      final count = batch.remaining;
      for (var i = 0; i < count; i++) {
        batch.onArrive?.call(i);
      }
    }
    if (!batch.completer.isCompleted) batch.completer.complete();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond, 0.25);
    _last = elapsed;
    for (final batch in _batches) {
      batch.age += dt;
    }
    // Panggilan balik dijalankan setelah daftar selesai diubah, supaya pemanggil
    // boleh memicu penerbangan baru dari dalamnya.
    final callbacks = <VoidCallback>[];
    for (final coin in _coins) {
      final batch = coin.batch;
      if (coin.arrived || batch.age < coin.delay + coin.duration) continue;
      coin.arrived = true;
      if (batch.still) continue;
      if (!batch.firstArrived) {
        batch.firstArrived = true;
        final onFirstArrive = batch.onFirstArrive;
        if (onFirstArrive != null) callbacks.add(onFirstArrive);
      }
      final onArrive = batch.onArrive;
      final index = coin.index;
      if (onArrive != null) callbacks.add(() => onArrive(index));
      batch.remaining--;
    }
    _coins.removeWhere((coin) => coin.arrived);
    final finished = <_FlightBatch>[
      for (final batch in _batches)
        if (!_coins.any((coin) => coin.batch == batch)) batch,
    ];
    _batches.removeWhere(finished.contains);
    if (_coins.isEmpty) _ticker.stop();
    _repaint.value++;
    for (final callback in callbacks) {
      callback();
    }
    for (final batch in finished) {
      _completeBatch(batch);
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _ticker.dispose();
    for (final batch in _batches) {
      if (!batch.completer.isCompleted) batch.completer.complete();
    }
    _batches.clear();
    _coins.clear();
    _image.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _CoinFlightPainter(state: this, repaint: _repaint)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinFlightPainter extends CustomPainter {
  _CoinFlightPainter({required this.state, required Listenable repaint}) : super(repaint: repaint);

  final _CoinFlightState state;

  @override
  void paint(Canvas canvas, Size size) {
    final image = state._image.info?.image;
    final radius = state.widget.coinSize / 2;
    for (final coin in state._coins) {
      final raw = (coin.batch.age - coin.delay) / coin.duration;
      if (raw <= 0 || raw >= 1) continue;
      if (coin.batch.still) {
        _paintCoin(canvas, image, coin.p3, radius, 0, math.sin(raw * math.pi));
        continue;
      }
      // Sembur cepat di awal, lalu tersedot makin kencang ke tujuan.
      final t = raw < 0.3
          ? 0.34 * Curves.easeOutCubic.transform(raw / 0.3)
          : 0.34 + 0.66 * Curves.easeInQuad.transform((raw - 0.3) / 0.7);
      final position = cubicBezierPoint(coin.p0, coin.p1, coin.p2, coin.p3, t);
      final grow = raw < 0.18 ? 0.5 + 0.5 * (raw / 0.18) : 1.0;
      final shrink = raw > 0.8 ? 1 - 0.38 * ((raw - 0.8) / 0.2) : 1.0;
      final scale = coin.scale * grow * shrink;
      final opacity = raw < 0.08 ? raw / 0.08 : (raw > 0.94 ? (1 - raw) / 0.06 : 1.0);
      final turn = coin.phase + coin.spin * raw;
      if (raw > 0.34) {
        // Jejak kilau di belakang koin.
        for (var k = 1; k <= 3; k++) {
          final trail = cubicBezierPoint(coin.p0, coin.p1, coin.p2, coin.p3, math.max(0, t - 0.035 * k));
          canvas.drawCircle(
            trail,
            radius * scale * (0.62 - 0.14 * k),
            Paint()..color = FestivePalette.goldLight.withValues(alpha: opacity * (0.34 - 0.09 * k)),
          );
        }
      }
      _paintCoin(canvas, image, position, radius * scale, turn, opacity);
    }
  }

  @override
  bool shouldRepaint(_CoinFlightPainter oldDelegate) => true;
}

/// Memicu air mancur koin pada [CoinFountain].
class CoinFountainController {
  _CoinFountainState? _state;

  bool get isSpraying => _state?._ticker.isActive ?? false;

  /// Menyemburkan [count] koin ke atas dari pusat [originKey] (atau dari
  /// [origin] relatif terhadap lapisan), lalu jatuh dan memudar. Future
  /// selesai saat koin terakhir padam.
  Future<void> spray({
    GlobalKey? originKey,
    Alignment origin = const Alignment(0, 0.2),
    int count = 12,
    double power = 1,
  }) {
    assert(count > 0);
    final state = _state;
    if (state == null) return Future<void>.value();
    return state._spray(originKey: originKey, origin: origin, count: count, power: power);
  }
}

/// Lapisan air mancur koin di atas [child] (menang Kelopak di roda).
///
/// Koin menyembur berkipas, berputar, jatuh oleh gravitasi, lalu memudar;
/// dilukis oleh satu `CustomPainter`. Kurangi gerak: tidak ada semburan.
class CoinFountain extends StatefulWidget {
  const CoinFountain({
    super.key,
    required this.controller,
    this.child,
    this.image,
    this.coinSize = 30,
    this.lifetime = const Duration(milliseconds: 1500),
    this.seed = 5,
  });

  final CoinFountainController controller;
  final Widget? child;
  final ImageProvider? image;
  final double coinSize;
  final Duration lifetime;
  final int seed;

  /// Koin maksimum dalam satu waktu.
  static const int capacity = 48;

  @override
  State<CoinFountain> createState() => _CoinFountainState();
}

class _CoinFountainState extends State<CoinFountain> with SingleTickerProviderStateMixin {
  /// x, y, vx, vy, putaran, laju putar, umur, usia maksimum, skala.
  static const int _stride = 9;
  static const double _gravity = 1500;

  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final Float32List _data = Float32List(CoinFountain.capacity * _stride);
  final _ImageHolder _image = _ImageHolder();
  late math.Random _random = math.Random(widget.seed);
  final List<Completer<void>> _waiting = <Completer<void>>[];
  int _cursor = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _image.resolve(widget.image, context, () => _repaint.value++);
  }

  @override
  void didUpdateWidget(CoinFountain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    if (oldWidget.image != widget.image) {
      _image.resolve(widget.image, context, () => _repaint.value++);
    }
    if (oldWidget.seed != widget.seed) _random = math.Random(widget.seed);
  }

  Future<void> _spray({
    required GlobalKey? originKey,
    required Alignment origin,
    required int count,
    required double power,
  }) {
    final layer = context.findRenderObject();
    if (layer is! RenderBox || !layer.hasSize || reduceMotionOf(context)) return Future<void>.value();
    final keyRect = originKey == null ? null : _globalRectOf(originKey);
    final start = keyRect == null ? origin.alongSize(layer.size) : layer.globalToLocal(keyRect.center);
    final life = widget.lifetime.inMicroseconds / Duration.microsecondsPerSecond;
    final total = math.min(count, CoinFountain.capacity);
    // Jeda antar-koin menyusut untuk semburan besar supaya seluruh semburan
    // selesai dalam batas waktu perayaan.
    final stagger = math.min(0.022, 0.3 / total);
    for (var i = 0; i < total; i++) {
      final o = _cursor * _stride;
      _cursor = (_cursor + 1) % CoinFountain.capacity;
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.5;
      final speed = (560 + _random.nextDouble() * 420) * power;
      _data[o] = start.dx + (_random.nextDouble() - 0.5) * 16;
      _data[o + 1] = start.dy;
      _data[o + 2] = math.cos(angle) * speed;
      _data[o + 3] = math.sin(angle) * speed;
      _data[o + 4] = _random.nextDouble() * math.pi * 2;
      _data[o + 5] = (6 + _random.nextDouble() * 8) * (_random.nextBool() ? 1 : -1);
      _data[o + 6] = -i * stagger;
      _data[o + 7] = life * (0.8 + _random.nextDouble() * 0.2);
      _data[o + 8] = 0.8 + _random.nextDouble() * 0.45;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    _repaint.value++;
    return completer.future;
  }

  void _onTick(Duration elapsed) {
    var remaining = math.min((elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond, 0.25);
    _last = elapsed;
    var alive = _step(0);
    // Langkah tetap 1/60 detik supaya busur tidak bergantung pada laju bingkai.
    while (remaining > 1e-6 && alive > 0) {
      final dt = math.min(remaining, 1 / 60);
      alive = _step(dt);
      remaining -= dt;
    }
    if (alive == 0) {
      _ticker.stop();
      _finishWaiting();
    }
    _repaint.value++;
  }

  /// Memajukan semua koin [dt] detik; mengembalikan jumlah yang masih hidup.
  int _step(double dt) {
    var alive = 0;
    final keepX = math.exp(-0.6 * dt);
    for (var i = 0; i < CoinFountain.capacity; i++) {
      final o = i * _stride;
      final life = _data[o + 7];
      if (life <= 0) continue;
      final age = _data[o + 6] + dt;
      _data[o + 6] = age;
      if (age >= life) {
        _data[o + 7] = 0;
        continue;
      }
      alive++;
      if (age < 0) continue;
      _data[o + 2] *= keepX;
      _data[o + 3] += _gravity * dt;
      _data[o] += _data[o + 2] * dt;
      _data[o + 1] += _data[o + 3] * dt;
      _data[o + 4] += _data[o + 5] * dt;
    }
    return alive;
  }

  void _finishWaiting() {
    for (final completer in _waiting) {
      if (!completer.isCompleted) completer.complete();
    }
    _waiting.clear();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _ticker.dispose();
    _finishWaiting();
    _image.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layer = IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CoinFountainPainter(state: this, repaint: _repaint),
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

class _CoinFountainPainter extends CustomPainter {
  _CoinFountainPainter({required this.state, required Listenable repaint}) : super(repaint: repaint);

  final _CoinFountainState state;

  @override
  void paint(Canvas canvas, Size size) {
    final image = state._image.info?.image;
    final radius = state.widget.coinSize / 2;
    final data = state._data;
    for (var i = 0; i < CoinFountain.capacity; i++) {
      final o = i * _CoinFountainState._stride;
      final life = data[o + 7];
      final age = data[o + 6];
      if (life <= 0 || age < 0 || age >= life) continue;
      final remaining = 1 - age / life;
      final opacity = remaining < 0.25 ? remaining / 0.25 : 1.0;
      final grow = age < 0.12 ? 0.4 + 0.6 * (age / 0.12) : 1.0;
      _paintCoin(canvas, image, Offset(data[o], data[o + 1]), radius * data[o + 8] * grow, data[o + 4], opacity);
    }
  }

  @override
  bool shouldRepaint(_CoinFountainPainter oldDelegate) => true;
}
