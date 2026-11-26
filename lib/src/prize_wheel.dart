import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'kit/festive_palette.dart';
import 'kit/motion.dart';
import 'spin_engine.dart';
import 'wheel_assets.dart';
import 'wheel_geometry.dart';
import 'wheel_slices.dart';
import 'wheel_spin_curve.dart';

/// Tinggi roda dibagi lebarnya: cakram, penyangga, dan bayangan lantai.
const double _heightFactor = 1.13;

/// Pusat cakram dari atas, dibagi lebar.
const double _centerFactor = 0.52;

/// Jari-jari cincin luar, dibagi lebar.
const double _radiusFactor = 0.46;

/// Diameter poros, dibagi lebar (84 dp pada lebar 360).
const double _hubFactor = 0.233;

const int _bulbCount = 24;
const double _pointerKick = 18 * math.pi / 180;

/// Roda hadiah 3D mengilap (SPEC-V3 §6.2), tujuh lapisan dari bawah ke
/// atas: bayangan lantai, penyangga, cincin emas berlampu, cakram beririsan
/// dengan seni koin/kado dan pasak emas, kilap diam, poros berwajah Bipy,
/// dan penunjuk hati berengsel yang terpental tiap pasak lewat.
///
/// Hasil ditentukan di luar widget. Ubah [spinToken] untuk memutar menuju
/// [resultPrizeId]; roda berhenti di dalam irisan hasil (titik dipilih
/// [landingSeed]) lalu memanggil [onSettled] tepat sekali. Kurangi gerak
/// atau [skipAnimation] langsung menaruh roda di hasil.
class PrizeWheel extends StatefulWidget {
  /// Membuat roda dari tabel peluang efektif [odds].
  const PrizeWheel({
    super.key,
    required this.odds,
    required this.resultPrizeId,
    required this.spinToken,
    required this.landingSeed,
    this.layout,
    this.onSettled,
    this.onPegPassed,
    this.centerChild,
    this.skipAnimation = false,
    this.duration = WheelSpinCurve.duration,
    this.idleSemanticsValue,
    this.ambientMotion = true,
    this.maxSide = 360,
  });

  /// Peluang efektif; menentukan irisan (lihat `buildWheelSlicesFromOdds`).
  final List<SpinOdds> odds;

  /// Tata letak irisan kampanye (`SpinConfig.wheelLayout`), bila ada.
  final List<WheelSliceSpec>? layout;

  /// Hadiah yang ditampilkan di bawah penunjuk; `null` = posisi diam.
  final String? resultPrizeId;

  /// Ubah nilai ini untuk mulai berputar menuju [resultPrizeId].
  final int spinToken;

  /// Benih titik berhenti di dalam irisan hasil.
  final int landingSeed;

  /// Dipanggil tepat sekali per putaran, saat roda sudah diam.
  final VoidCallback? onSettled;

  /// Dipanggil saat pasak lewat penunjuk, paling sering tiap 45 ms.
  final VoidCallback? onPegPassed;

  /// Isi poros (dipotong lingkaran). Bawaan: wajah Bipy tersenyum, berkedip
  /// setelah menang.
  final Widget? centerChild;

  /// Bila `true` (juga di tengah putaran) roda langsung ke hasil.
  final bool skipAnimation;

  /// Lama putaran termasuk mengendap.
  final Duration duration;

  /// Nilai Semantics saat tidak ada hasil, mis. "Siap diputar" atau
  /// "Dibuka Sabtu, 28 Nov". `null` = tanpa keterangan.
  final String? idleSemanticsValue;

  /// Lampu berkejaran saat diam dan perayaan setelah menang (irisan
  /// berdenyut, lampu berkedip). Lampu selama berputar selalu mengikuti
  /// putaran roda.
  final bool ambientMotion;

  /// Lebar terbesar roda.
  final double maxSide;

  /// Kunci `Transform` cakram yang berputar (untuk tes dan tangkap layar).
  static const Key discKey = ValueKey<String>('prize-wheel-disc');

  /// Lebar roda untuk batasan [constraints] dan lebar terbesar [maxSide].
  static double sideFor(BoxConstraints constraints, {double maxSide = 360}) {
    double side = maxSide;
    if (constraints.hasBoundedWidth) {
      side = math.min(side, constraints.maxWidth);
    }
    if (constraints.hasBoundedHeight) {
      side = math.min(side, constraints.maxHeight / _heightFactor);
    }
    return math.max(0, side);
  }

  /// Tinggi roda selebar [side].
  static double heightFor(double side) => side * _heightFactor;

  @override
  State<PrizeWheel> createState() => _PrizeWheelState();
}

enum _LightMode { idle, spinning, celebrating, still }

class _PrizeWheelState extends State<PrizeWheel> with TickerProviderStateMixin {
  static const int _fullTurns = 6;
  static const Duration _pegInterval = Duration(milliseconds: 45);
  static const Duration _celebration = Duration(milliseconds: 1800);
  static const SpringDescription _pointerSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 26,
  );

  late final AnimationController _rotation;
  late final AnimationController _kick;
  late final AnimationController _ambient;
  late final AnimationController _celebrate;
  late WheelGeometry _geometry;
  final Map<String, SpinPrize> _prizes = <String, SpinPrize>{};
  bool _reduceMotion = false;
  bool _spinning = false;
  bool _settleScheduled = false;
  bool _won = false;
  int _spinGeneration = 0;
  double _spinTarget = 0;
  double _lastAngle = 0;
  Duration? _lastPegAt;

  bool get _skipMotion =>
      _reduceMotion || widget.skipAnimation || widget.duration <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController.unbounded(vsync: this)
      ..addListener(_handleRotation)
      ..addStatusListener(_handleRotationStatus);
    _kick = AnimationController.unbounded(vsync: this);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _celebrate = AnimationController(vsync: this, duration: _celebration);
    _rememberPrizes();
    _geometry = _geometryFor(widget);
    _won = widget.resultPrizeId != null;
    _rest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
    _syncAmbient();
    if (_spinning && _skipMotion) _finishSpinNow();
  }

  @override
  void didUpdateWidget(PrizeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduceMotion = reduceMotionOf(context);
    _syncAmbient();
    if (widget.spinToken != oldWidget.spinToken) {
      _syncGeometry();
      final String? prizeId = widget.resultPrizeId;
      if (prizeId == null) {
        _cancelSpin();
        _won = false;
        _rest();
      } else {
        _startSpin(prizeId);
      }
      return;
    }
    if (_spinning) {
      if (_skipMotion) _finishSpinNow();
      return;
    }
    final bool layoutChanged = _syncGeometry();
    if (layoutChanged ||
        widget.resultPrizeId != oldWidget.resultPrizeId ||
        widget.landingSeed != oldWidget.landingSeed) {
      _won = widget.resultPrizeId != null;
      _rest();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _kick.dispose();
    _ambient.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  WheelGeometry _geometryFor(PrizeWheel wheel) =>
      WheelGeometry.fromOdds(wheel.odds, layout: wheel.layout);

  void _syncAmbient() {
    final bool run =
        widget.ambientMotion && !_reduceMotion && !_spinning && !_won;
    syncRepeat(_ambient, enabled: run);
  }

  void _rememberPrizes() {
    for (final SpinOdds entry in widget.odds) {
      _prizes[entry.prize.id] = entry.prize;
    }
  }

  bool _syncGeometry() {
    _rememberPrizes();
    final WheelGeometry next = WheelGeometry.retainResult(
      current: _geometry,
      next: _geometryFor(widget),
      resultPrizeId: widget.resultPrizeId,
    );
    if (next == _geometry) return false;
    _geometry = next;
    return true;
  }

  void _rest() {
    final String? prizeId = widget.resultPrizeId;
    if (prizeId == null) {
      _jumpTo(_geometry.idleRotation);
      return;
    }
    final double? rest = _geometry.restRotationFor(prizeId, widget.landingSeed);
    if (rest != null) _jumpTo(rest);
  }

  void _jumpTo(double angle) {
    _lastAngle = angle;
    _rotation.value = angle;
  }

  void _startSpin(String prizeId) {
    final double from = _rotation.value;
    _spinGeneration++;
    _spinning = true;
    _won = false;
    _settleScheduled = false;
    _lastPegAt = null;
    _lastAngle = from;
    _celebrate.reset();
    _syncAmbient();
    _spinTarget = _geometry.spinEndRotation(
      from: from,
      prizeId: prizeId,
      landingSeed: widget.landingSeed,
      fullTurns: _fullTurns,
    );
    if (_skipMotion) {
      _finishSpinNow();
    } else {
      _rotation.animateTo(
        _spinTarget,
        duration: widget.duration,
        curve: WheelSpinCurve.forDistance(_spinTarget - from),
      );
    }
  }

  void _finishSpinNow() {
    _rotation.stop();
    _jumpTo(_spinTarget);
    if (_settleScheduled) return;
    _settleScheduled = true;
    final int generation = _spinGeneration;
    SchedulerBinding.instance
      ..addPostFrameCallback((Duration _) {
        if (mounted && generation == _spinGeneration) _settle();
      }, debugLabel: 'PrizeWheel.settle')
      ..ensureVisualUpdate();
  }

  void _cancelSpin() {
    _spinGeneration++;
    _spinning = false;
    _settleScheduled = false;
    _rotation.stop();
    _celebrate.reset();
  }

  void _settle() {
    if (!_spinning) return;
    setState(() {
      _spinning = false;
      _settleScheduled = false;
      _won = true;
    });
    _syncAmbient();
    if (widget.ambientMotion && !_reduceMotion) {
      _celebrate.forward(from: 0);
    }
    widget.onSettled?.call();
  }

  void _handleRotationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _spinning && !_settleScheduled) {
      _settle();
    }
  }

  void _handleRotation() {
    final double angle = _rotation.value;
    final double previous = _lastAngle;
    _lastAngle = angle;
    if (!_spinning) return;
    if (!_geometry.pegCrossed(previous, angle)) return;
    final Duration elapsed = _rotation.lastElapsedDuration ?? widget.duration;
    final Duration? last = _lastPegAt;
    if (last != null && elapsed - last < _pegInterval) return;
    _lastPegAt = elapsed;
    if (!_reduceMotion) {
      _kick
        ..value = 1
        ..animateWith(SpringSimulation(_pointerSpring, 1, 0, 0));
    }
    widget.onPegPassed?.call();
  }

  String _semanticsValue() {
    if (_spinning) return 'Sedang berputar';
    final String? prizeId = widget.resultPrizeId;
    if (prizeId == null) return widget.idleSemanticsValue ?? '';
    final String? label = _labelFor(prizeId);
    return label == null ? 'Sudah diputar' : 'Hasil: $label';
  }

  String? _labelFor(String prizeId) {
    for (final SpinOdds entry in widget.odds) {
      if (entry.prize.id == prizeId) return entry.prize.label;
    }
    return _prizes[prizeId]?.label;
  }

  _LightMode get _lightMode {
    if (_spinning) return _LightMode.spinning;
    if (_won && _celebrate.isAnimating) return _LightMode.celebrating;
    if (!widget.ambientMotion || _reduceMotion || _won) return _LightMode.still;
    return _LightMode.idle;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle());
    final List<_FaceSlice> faces = <_FaceSlice>[
      for (final WheelSlice slice in _geometry.slices)
        if (_prizes[slice.prizeId] case final SpinPrize prize)
          _FaceSlice(slice: slice, prize: prize),
    ];
    return Semantics(
      container: true,
      label: 'Roda Sabtu',
      value: _semanticsValue(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double side = PrizeWheel.sideFor(
            constraints,
            maxSide: widget.maxSide,
          );
          if (side <= 0) return const SizedBox.shrink();
          final _Metrics m = _Metrics(side);
          return Center(
            child: ExcludeSemantics(
              child: MediaQuery.withNoTextScaling(
                child: SizedBox(
                  width: side,
                  height: PrizeWheel.heightFor(side),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(painter: _StandPainter(m)),
                      ),
                      Positioned(
                        left: m.center.dx - m.discRadius,
                        top: m.center.dy - m.discRadius,
                        width: m.discRadius * 2,
                        height: m.discRadius * 2,
                        child: _RotatingDisc(
                          rotation: _rotation,
                          celebrate: _celebrate,
                          faces: faces,
                          metrics: m,
                          resultPrizeId: _won ? widget.resultPrizeId : null,
                          baseStyle: base,
                        ),
                      ),
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[
                              _ambient,
                              _celebrate,
                              _rotation,
                            ]),
                            builder: (BuildContext context, Widget? _) =>
                                CustomPaint(
                                  painter: _RingPainter(
                                    metrics: m,
                                    mode: _lightMode,
                                    ambient: _ambient.value,
                                    celebrate: _celebrate.value,
                                    rotation: _rotation.value,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: m.center.dx - m.hubRadius,
                        top: m.center.dy - m.hubRadius,
                        width: m.hubRadius * 2,
                        height: m.hubRadius * 2,
                        child: _Hub(won: _won, child: widget.centerChild),
                      ),
                      Positioned(
                        left: m.center.dx - m.pointerWidth / 2,
                        top: 0,
                        width: m.pointerWidth,
                        height: m.pointerHeight,
                        child: AnimatedBuilder(
                          animation: _kick,
                          builder: (BuildContext context, Widget? child) =>
                              Transform.rotate(
                                angle: -_pointerKick * _kick.value,
                                alignment: const Alignment(0, -0.62),
                                child: child,
                              ),
                          child: const CustomPaint(painter: _PointerPainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ukuran turunan dari lebar roda.
class _Metrics {
  _Metrics(this.side)
    : center = Offset(side / 2, side * _centerFactor),
      outerRadius = side * _radiusFactor;

  final double side;
  final Offset center;
  final double outerRadius;

  double get ringWidth => outerRadius * 0.122;
  double get innerRingWidth => outerRadius * 0.03;
  double get discRadius => outerRadius - ringWidth - innerRingWidth;
  double get hubRadius => side * _hubFactor / 2;
  double get bulbRadius => ringWidth * 0.27;
  double get pointerWidth => side * 0.15;
  double get pointerHeight => side * 0.16;
}

class _FaceSlice {
  const _FaceSlice({required this.slice, required this.prize});

  final WheelSlice slice;
  final SpinPrize prize;
}

enum _Tone { cream, pink, gold, product }

/// Irisan Kelopak berselang menurut indeks (genap pink jenuh, ganjil krem)
/// supaya roda terbaca berputar; produk dan 10 Kelopak tetap menonjol.
_Tone _toneOf(_FaceSlice face) {
  final SpinPrize prize = face.prize;
  if (prize.kind == PrizeKind.product) return _Tone.product;
  if (prize.kelopak >= 10) return _Tone.gold;
  return face.slice.index.isEven ? _Tone.pink : _Tone.cream;
}

List<Color> _fillOf(_Tone tone) => switch (tone) {
  _Tone.cream => const <Color>[Color(0xFFFFFDF8), FestivePalette.festCream],
  _Tone.pink => const <Color>[
    FestivePalette.festMid,
    FestivePalette.candyBottom,
  ],
  _Tone.gold => const <Color>[FestivePalette.goldLight, FestivePalette.gold],
  _Tone.product => const <Color>[
    FestivePalette.candyBottom,
    FestivePalette.festDeep,
  ],
};

Color _inkOf(_Tone tone) => switch (tone) {
  _Tone.product || _Tone.pink => Colors.white,
  _Tone.gold => const Color(0xFF5A3300),
  _ => FestivePalette.festDeep,
};

/// Cakram berputar: irisan dan pasak dirender sekali lalu hanya diputar;
/// isi irisan ikut berputar mengitari pusat tetapi diputar balik supaya
/// angka selalu tegak, juga saat roda berhenti di hasil mana pun.
class _RotatingDisc extends StatelessWidget {
  const _RotatingDisc({
    required this.rotation,
    required this.celebrate,
    required this.faces,
    required this.metrics,
    required this.resultPrizeId,
    required this.baseStyle,
  });

  final Animation<double> rotation;
  final Animation<double> celebrate;
  final List<_FaceSlice> faces;
  final _Metrics metrics;
  final String? resultPrizeId;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final double r = metrics.discRadius;
    final Widget face = RepaintBoundary(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DiscPainter(faces, metrics)),
            ),
          ),
          for (final _FaceSlice face in faces)
            Positioned.fill(
              child: Transform.rotate(
                angle: face.slice.startRadians + face.slice.sweepRadians / 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: r * 0.1),
                    child: AnimatedBuilder(
                      animation: rotation,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.rotate(
                            angle:
                                -(face.slice.startRadians +
                                    face.slice.sweepRadians / 2 +
                                    rotation.value),
                            child: child,
                          ),
                      child: RepaintBoundary(
                        child: _SliceLabel(
                          face: face,
                          radius: r,
                          baseStyle: baseStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WinPainter(
                  faces: faces,
                  resultPrizeId: resultPrizeId,
                  rotation: rotation,
                  celebrate: celebrate,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AnimatedBuilder(
            animation: rotation,
            child: face,
            builder: (BuildContext context, Widget? child) => Transform.rotate(
              key: PrizeWheel.discKey,
              angle: rotation.value,
              child: child,
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GlossPainter())),
        ),
      ],
    );
  }
}

/// Isi satu irisan, tegak saat roda diam: seni koin, angka besar, lalu kata
/// "Kelopak" (irisan produk: "Produk gratis" lalu kado).
class _SliceLabel extends StatelessWidget {
  const _SliceLabel({
    required this.face,
    required this.radius,
    required this.baseStyle,
  });

  final _FaceSlice face;
  final double radius;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final SpinPrize prize = face.prize;
    final _Tone tone = _toneOf(face);
    final Color ink = _inkOf(tone);
    final bool narrow = face.slice.sweepDeg < 30;
    final bool product = prize.kind == PrizeKind.product;
    final double width = math.min(
      radius * 0.56,
      2 *
          radius *
          (narrow ? 0.84 : 0.7) *
          math.sin(face.slice.sweepRadians / 2) *
          0.92,
    );
    final List<Shadow> glow = <Shadow>[
      Shadow(
        color: ink == Colors.white
            ? FestivePalette.festDeep.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.7),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
    final TextStyle big = baseStyle.copyWith(
      color: product ? FestivePalette.goldLight : ink,
      fontSize: product ? radius * 0.11 : radius * (narrow ? 0.18 : 0.22),
      fontWeight: FontWeight.w800,
      height: 1,
      shadows: glow,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final TextStyle small = baseStyle.copyWith(
      color: ink,
      fontSize: radius * 0.078,
      fontWeight: FontWeight.w700,
      height: 1.1,
      shadows: glow,
    );
    final Widget art = Image(
      image: WheelArt.forPrize(prize),
      width: math.min(narrow ? width * 1.1 : width * 0.7, radius * 0.3),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );
    if (product) {
      return SizedBox(
        width: width,
        height: radius * 0.52,
        child: Column(
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Produk', style: big, maxLines: 1),
            ),
            if (!narrow)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('gratis', style: small, maxLines: 1),
              ),
            SizedBox(height: radius * 0.03),
            Expanded(child: art),
          ],
        ),
      );
    }
    return SizedBox(
      width: width,
      height: radius * 0.52,
      child: Column(
        children: <Widget>[
          Expanded(child: art),
          SizedBox(height: radius * 0.02),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${prize.kelopak}', style: big, maxLines: 1),
          ),
          if (!narrow) ...<Widget>[
            SizedBox(height: radius * 0.01),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Kelopak', style: small, maxLines: 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter(this.faces, this.metrics);

  final List<_FaceSlice> faces;
  final _Metrics metrics;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Rect disc = Rect.fromCircle(center: c, radius: r);
    // Sudut 0 = jam 12, searah jarum jam.
    const double up = -math.pi / 2;
    for (final _FaceSlice face in faces) {
      final _Tone tone = _toneOf(face);
      final List<Color> fill = _fillOf(tone);
      final Path path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(
          disc,
          up + face.slice.startRadians,
          face.slice.sweepRadians,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: fill,
            stops: const <double>[0.25, 1],
          ).createShader(disc),
      );
      if (tone == _Tone.product) _paintStars(canvas, c, r, face.slice);
    }
    final Paint separator = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = math.max(1.5, r * 0.014);
    for (final _FaceSlice face in faces) {
      final double a = up + face.slice.startRadians;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, separator);
    }
    // Bayangan dalam di tepi supaya cakram terasa cekung.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.transparent,
            FestivePalette.festDeep.withValues(alpha: 0.22),
          ],
          stops: const <double>[0.82, 1],
        ).createShader(disc),
    );
    final double pegR = math.max(2.5, r * 0.032);
    for (final _FaceSlice face in faces) {
      final double a = up + face.slice.startRadians;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * (r - pegR * 1.9);
      _paintPeg(canvas, p, pegR);
    }
  }

  void _paintStars(Canvas canvas, Offset c, double r, WheelSlice slice) {
    final math.Random random = math.Random(slice.index * 31 + 7);
    final Paint star = Paint();
    for (int i = 0; i < 9; i++) {
      final double a =
          -math.pi / 2 +
          slice.startRadians +
          slice.sweepRadians * (0.12 + random.nextDouble() * 0.76);
      final double d = r * (0.32 + random.nextDouble() * 0.6);
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * d;
      star.color = Colors.white.withValues(
        alpha: 0.35 + random.nextDouble() * 0.45,
      );
      canvas.drawPath(
        _sparkPath(p, r * (0.012 + random.nextDouble() * 0.02)),
        star,
      );
    }
  }

  @override
  bool shouldRepaint(_DiscPainter oldDelegate) =>
      oldDelegate.faces.length != faces.length ||
      !_sameFaces(oldDelegate.faces, faces) ||
      oldDelegate.metrics.side != metrics.side;
}

bool _sameFaces(List<_FaceSlice> a, List<_FaceSlice> b) {
  for (int i = 0; i < a.length; i++) {
    if (a[i].slice != b[i].slice || a[i].prize != b[i].prize) return false;
  }
  return true;
}

Path _sparkPath(Offset c, double s) {
  return Path()
    ..moveTo(c.dx, c.dy - s * 2)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 2, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s * 2)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 2, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s * 2)
    ..close();
}

void _paintPeg(Canvas canvas, Offset p, double radius) {
  canvas.drawCircle(
    p + Offset(0, radius * 0.35),
    radius,
    Paint()..color = FestivePalette.festDeep.withValues(alpha: 0.35),
  );
  canvas.drawCircle(
    p,
    radius,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.5),
        colors: <Color>[
          Color(0xFFFFF6D0),
          FestivePalette.gold,
          FestivePalette.goldDeep,
        ],
        stops: <double>[0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: p, radius: radius)),
  );
}

/// Sorot irisan menang: berdenyut tiga kali lalu tetap bercahaya lembut.
class _WinPainter extends CustomPainter {
  _WinPainter({
    required this.faces,
    required this.resultPrizeId,
    required this.rotation,
    required this.celebrate,
  }) : super(repaint: celebrate);

  final List<_FaceSlice> faces;
  final String? resultPrizeId;
  final Animation<double> rotation;
  final Animation<double> celebrate;

  @override
  void paint(Canvas canvas, Size size) {
    final String? prizeId = resultPrizeId;
    if (prizeId == null) return;
    final WheelSlice? slice = WheelGeometry(<WheelSlice>[
      for (final _FaceSlice face in faces) face.slice,
    ]).sliceUnderPointer(rotation.value);
    if (slice == null || slice.prizeId != prizeId) return;
    final double t = celebrate.value;
    final double pulse = t <= 0 || t >= 1
        ? 0
        : 0.5 - 0.5 * math.cos(t * 3 * 2 * math.pi);
    final double alpha = 0.16 + 0.34 * pulse;
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Rect disc = Rect.fromCircle(center: c, radius: r);
    const double up = -math.pi / 2;
    final Path path = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(disc, up + slice.startRadians, slice.sweepRadians, false)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.025)
        ..color = FestivePalette.goldLight.withValues(alpha: 0.6 + 0.4 * pulse),
    );
  }

  @override
  bool shouldRepaint(_WinPainter oldDelegate) =>
      oldDelegate.resultPrizeId != resultPrizeId || oldDelegate.faces != faces;
}

/// Kilap diam di atas cakram: sorot putih kiri atas dan vinyet kanan bawah.
class _GlossPainter extends CustomPainter {
  const _GlossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Rect disc = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    canvas.drawRect(
      disc,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.6),
          radius: 0.75,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(disc),
    );
    canvas.drawRect(
      disc,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.7, 0.75),
          radius: 0.9,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(disc),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlossPainter oldDelegate) => false;
}

/// Bayangan lantai dan penyangga trapesium emas-pink.
class _StandPainter extends CustomPainter {
  _StandPainter(this.m);

  final _Metrics m;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = m.side;
    final double floorY = s * 1.085;
    final Rect floor = Rect.fromCenter(
      center: Offset(s / 2, floorY),
      width: s * 0.78,
      height: s * 0.075,
    );
    canvas.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(floor),
    );
    final double topY = m.center.dy + m.outerRadius * 0.62;
    canvas.drawCircle(
      m.center + Offset(0, m.outerRadius * 0.06),
      m.outerRadius,
      Paint()
        ..color = FestivePalette.festDeep.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.outerRadius * 0.07),
    );
    final double baseY = s * 1.075;
    final double topHalf = s * 0.13;
    final double baseHalf = s * 0.25;
    final Rect plate = Rect.fromCenter(
      center: Offset(s / 2, baseY - s * 0.004),
      width: (baseHalf + s * 0.03) * 2,
      height: s * 0.07,
    );
    canvas.drawOval(
      plate.shift(Offset(0, s * 0.012)),
      Paint()..color = FestivePalette.festDeep,
    );
    canvas.drawOval(
      plate,
      Paint()..shader = FestivePalette.goldSheen.createShader(plate),
    );
    final Rect top = plate.deflate(s * 0.012);
    canvas.drawOval(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[FestivePalette.candyTop, FestivePalette.candyBottom],
        ).createShader(top),
    );
    final Path stand = Path()
      ..moveTo(s / 2 - topHalf, topY)
      ..lineTo(s / 2 + topHalf, topY)
      ..lineTo(s / 2 + baseHalf, baseY - s * 0.03)
      ..quadraticBezierTo(
        s / 2 + baseHalf,
        baseY,
        s / 2 + baseHalf - s * 0.03,
        baseY,
      )
      ..lineTo(s / 2 - baseHalf + s * 0.03, baseY)
      ..quadraticBezierTo(
        s / 2 - baseHalf,
        baseY,
        s / 2 - baseHalf,
        baseY - s * 0.03,
      )
      ..close();
    final Rect bounds = stand.getBounds();
    canvas.drawPath(
      stand,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            FestivePalette.festDeep,
            FestivePalette.candyBottom,
            FestivePalette.candyTop,
            FestivePalette.candyBottom,
            FestivePalette.festDeep,
          ],
          stops: <double>[0, 0.25, 0.45, 0.7, 1],
        ).createShader(bounds),
    );
    canvas.drawLine(
      Offset(s / 2 - topHalf * 0.4, topY + s * 0.02),
      Offset(s / 2 - baseHalf * 0.45, baseY - s * 0.04),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = s * 0.012
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StandPainter oldDelegate) => oldDelegate.m.side != m.side;
}

/// Cincin luar emas, cincin dalam plum, dan 24 lampu.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.metrics,
    required this.mode,
    required this.ambient,
    required this.celebrate,
    required this.rotation,
  });

  final _Metrics metrics;
  final _LightMode mode;
  final double ambient;
  final double celebrate;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final _Metrics m = metrics;
    final Offset c = m.center;
    final double outer = m.outerRadius;
    final double ring = m.ringWidth;
    final Rect outerRect = Rect.fromCircle(center: c, radius: outer);
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring
      ..shader = const SweepGradient(
        colors: <Color>[
          FestivePalette.goldLight,
          FestivePalette.gold,
          FestivePalette.goldDeep,
          FestivePalette.gold,
          FestivePalette.goldLight,
          FestivePalette.gold,
          FestivePalette.goldDeep,
          FestivePalette.gold,
          FestivePalette.goldLight,
        ],
        transform: GradientRotation(-math.pi / 3),
      ).createShader(outerRect);
    canvas.drawCircle(c, outer - ring / 2, ringPaint);
    canvas.drawCircle(
      c,
      outer - ring * 0.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring * 0.14
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, ring * 0.08)
        ..color = FestivePalette.goldDeep,
    );
    canvas.drawCircle(
      c,
      outer - ring - m.innerRingWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m.innerRingWidth
        ..color = FestivePalette.festDeep,
    );
    final double bulbOrbit = outer - ring / 2;
    for (int i = 0; i < _bulbCount; i++) {
      final double a = -math.pi / 2 + i * 2 * math.pi / _bulbCount;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * bulbOrbit;
      _paintBulb(canvas, p, m.bulbRadius, _brightness(i));
    }
  }

  double _brightness(int i) {
    switch (mode) {
      case _LightMode.still:
        return i.isEven ? 1 : 0.35;
      case _LightMode.idle:
        final int step = (ambient * 4).floor();
        return (i + step).isEven ? 1 : 0.3;
      case _LightMode.spinning:
        final int step = (rotation / (2 * math.pi / _bulbCount)).floor() % 3;
        return (i + step) % 3 == 0 ? 1 : 0.3;
      case _LightMode.celebrating:
        final bool on = (celebrate * 8).floor().isEven;
        return on ? 1 : 0.25;
    }
  }

  void _paintBulb(Canvas canvas, Offset p, double radius, double level) {
    if (level > 0.6) {
      canvas.drawCircle(
        p,
        radius * 2.2,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFFFF4C2).withValues(alpha: 0.75 * level),
              const Color(0xFFFFF4C2).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: radius * 2.2)),
      );
    }
    final Color core = Color.lerp(
      const Color(0xFFE7B867),
      const Color(0xFFFFFDF0),
      level,
    )!;
    canvas.drawCircle(
      p,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: <Color>[
            Colors.white,
            core,
            Color.lerp(core, FestivePalette.goldDeep, 0.45)!,
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: p, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.metrics.side != metrics.side ||
      _brightnessChanged(oldDelegate);

  bool _brightnessChanged(_RingPainter old) {
    for (int i = 0; i < 3; i++) {
      if (old._brightness(i) != _brightness(i)) return true;
    }
    return false;
  }
}

/// Poros: cincin putih dan emas dengan wajah Bipy (atau [child]).
class _Hub extends StatelessWidget {
  const _Hub({required this.won, this.child});

  final bool won;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double d = constraints.biggest.shortestSide;
        final Widget face =
            child ??
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Image(
                key: ValueKey<bool>(won),
                image: won ? WheelArt.faceWink : WheelArt.faceSmile,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                filterQuality: FilterQuality.medium,
              ),
            );
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FestivePalette.goldSheen,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: FestivePalette.festDeep.withValues(alpha: 0.45),
                blurRadius: d * 0.12,
                offset: Offset(0, d * 0.05),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(d * 0.055),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.all(d * 0.035),
                child: ClipOval(
                  child: ColoredBox(
                    color: FestivePalette.festBlush,
                    child: SizedBox.expand(child: face),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Penunjuk emas berbentuk hati terbalik dengan engsel di atas.
class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect heart = Rect.fromLTWH(0, h * 0.16, w, h * 0.84);
    final Path path = _heartPath(heart);
    canvas.drawPath(
      path.shift(Offset(0, h * 0.04)),
      Paint()
        ..color = FestivePalette.festDeep.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF3C4),
            FestivePalette.goldLight,
            FestivePalette.gold,
            FestivePalette.goldDeep,
          ],
          stops: <double>[0, 0.3, 0.62, 1],
        ).createShader(heart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = FestivePalette.goldDeep,
    );
    final Rect gem = Rect.fromCenter(
      center: Offset(w / 2, heart.top + heart.height * 0.42),
      width: w * 0.44,
      height: heart.height * 0.36,
    );
    canvas.drawPath(
      _heartPath(gem),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: <Color>[
            FestivePalette.candyTop,
            FestivePalette.candyBottom,
            FestivePalette.candyLip,
          ],
        ).createShader(gem),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        w * 0.16,
        heart.top + heart.height * 0.1,
        w * 0.2,
        heart.height * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    final Offset hinge = Offset(w / 2, h * 0.19);
    canvas.drawCircle(
      hinge,
      w * 0.12,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: <Color>[
            Colors.white,
            FestivePalette.gold,
            FestivePalette.goldDeep,
          ],
          stops: <double>[0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: hinge, radius: w * 0.12)),
    );
  }

  Path _heartPath(Rect r) {
    final double w = r.width;
    final double h = r.height;
    final double x = r.left;
    final double y = r.top;
    return Path()
      ..moveTo(x + w * 0.5, y + h)
      ..cubicTo(
        x + w * 0.22,
        y + h * 0.78,
        x - w * 0.02,
        y + h * 0.5,
        x + w * 0.04,
        y + h * 0.26,
      )
      ..cubicTo(
        x + w * 0.1,
        y + h * 0.02,
        x + w * 0.4,
        y - h * 0.04,
        x + w * 0.5,
        y + h * 0.2,
      )
      ..cubicTo(
        x + w * 0.6,
        y - h * 0.04,
        x + w * 0.9,
        y + h * 0.02,
        x + w * 0.96,
        y + h * 0.26,
      )
      ..cubicTo(
        x + w * 1.02,
        y + h * 0.5,
        x + w * 0.78,
        y + h * 0.78,
        x + w * 0.5,
        y + h,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
