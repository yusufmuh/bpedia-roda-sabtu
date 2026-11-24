import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'spin_engine.dart';
import 'wheel_geometry.dart';

const double _maxWheelSide = 320;
const double _radiusFactor = 0.45;
const double _hubFactor = 0.28;
const double _minLabelHeight = 13;
const double _maxGlyphSize = 30;
const double _minGlyphSize = 10;
const String _productSegmentLabel = 'Produk';
const IconData _productGlyph = Icons.redeem;

/// The Roda Sabtu wheel. Segments are proportional to [odds]; the pointer
/// sits at 12 o'clock.
///
/// The result is decided by the engine before the wheel moves: when
/// [spinToken] changes and [resultPrizeId] is set, the wheel turns five full
/// times and eases out onto that prize (a spot inside it picked by
/// [landingSeed]). With reduced motion or [skipAnimation] it jumps straight
/// to the result. On first build with a [resultPrizeId] it rests on the
/// result without animating or calling [onSettled].
///
/// While a result is shown, pass the odds that were in effect when it was
/// drawn (for example computed with the stock before the spin), so the
/// winning segment exists after the app restarts.
///
/// Screen readers hear "Roda Sabtu" with the state as value: "Sedang
/// berputar", "Hasil: …", or [idleSemanticsValue] while no result is shown.
/// The wheel does not know whether a spin is allowed, so the host passes the
/// idle state ("Siap diputar" only when the spin is really available).
class SaturdayWheel extends StatefulWidget {
  const SaturdayWheel({
    super.key,
    required this.odds,
    required this.resultPrizeId,
    required this.spinToken,
    required this.landingSeed,
    this.onSettled,
    this.onPegPassed,
    this.centerChild,
    this.skipAnimation = false,
    this.duration = const Duration(milliseconds: 4200),
    this.idleSemanticsValue,
  });

  final List<SpinOdds> odds;
  final String? resultPrizeId;

  /// Change this value to start a spin towards [resultPrizeId].
  final int spinToken;
  final int landingSeed;

  /// Called exactly once per spin, when the wheel has come to rest.
  final VoidCallback? onSettled;

  /// Called when a peg passes the pointer, at most once every 45 ms.
  final VoidCallback? onPegPassed;

  /// Shown inside the center hub, clipped to a circle.
  final Widget? centerChild;

  /// When true (also mid-spin) the wheel jumps to the result.
  final bool skipAnimation;
  final Duration duration;

  /// Semantics value while no result is shown, e.g. "Siap diputar" or
  /// "Buka Sabtu, 5 Des". Null announces no state.
  final String? idleSemanticsValue;

  @override
  State<SaturdayWheel> createState() => _SaturdayWheelState();
}

class _SaturdayWheelState extends State<SaturdayWheel>
    with SingleTickerProviderStateMixin {
  static const int _fullTurns = 5;
  static const Duration _pegInterval = Duration(milliseconds: 45);

  late final AnimationController _rotation;
  final _WheelArtwork _artwork = _WheelArtwork();
  late WheelGeometry _geometry;
  bool _systemReduceMotion = false;
  bool _spinning = false;
  bool _settleScheduled = false;
  int _spinGeneration = 0;
  double _spinTarget = 0;
  double _lastAngle = 0;
  Duration? _lastPegAt;

  bool get _skipMotion =>
      _systemReduceMotion ||
      widget.skipAnimation ||
      widget.duration <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController.unbounded(vsync: this)
      ..addListener(_handleRotation)
      ..addStatusListener(_handleRotationStatus);
    _geometry = WheelGeometry.fromOdds(widget.odds);
    _rest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_spinning && _skipMotion) _finishSpinNow();
  }

  @override
  void didUpdateWidget(SaturdayWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.spinToken != oldWidget.spinToken) {
      _syncGeometry();
      final String? prizeId = widget.resultPrizeId;
      if (prizeId == null) {
        _cancelSpin();
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
      _rest();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _artwork.dispose();
    super.dispose();
  }

  bool _syncGeometry() {
    final WheelGeometry next = WheelGeometry.retainResult(
      current: _geometry,
      next: WheelGeometry.fromOdds(widget.odds),
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
    _settleScheduled = false;
    _lastPegAt = null;
    _lastAngle = from;
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
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _finishSpinNow() {
    _jumpTo(_spinTarget);
    if (_settleScheduled) return;
    _settleScheduled = true;
    final int generation = _spinGeneration;
    SchedulerBinding.instance
      ..addPostFrameCallback((Duration _) {
        if (mounted && generation == _spinGeneration) _settle();
      }, debugLabel: 'SaturdayWheel.settle')
      ..ensureVisualUpdate();
  }

  void _cancelSpin() {
    _spinGeneration++;
    _spinning = false;
    _settleScheduled = false;
    _rotation.stop();
  }

  void _settle() {
    if (!_spinning) return;
    setState(() {
      _spinning = false;
      _settleScheduled = false;
    });
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
    final VoidCallback? onPegPassed = widget.onPegPassed;
    if (!_spinning || onPegPassed == null) return;
    if (!_geometry.pegCrossed(previous, angle)) return;
    final Duration elapsed = _rotation.lastElapsedDuration ?? widget.duration;
    final Duration? last = _lastPegAt;
    if (last != null && elapsed - last < _pegInterval) return;
    _lastPegAt = elapsed;
    onPegPassed();
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
    for (final WheelSegment segment in _geometry.segments) {
      if (segment.prize.id == prizeId) return segment.prize.label;
    }
    return null;
  }

  static double _sideFor(BoxConstraints constraints) {
    double side = _maxWheelSide;
    if (constraints.hasBoundedWidth) {
      side = math.min(side, constraints.maxWidth);
    }
    if (constraints.hasBoundedHeight) {
      side = math.min(side, constraints.maxHeight);
    }
    return side;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _WheelStyle style = _WheelStyle(
      productFill: scheme.tertiary,
      productInk: scheme.onTertiary,
      primaryFill: scheme.primaryContainer,
      primaryInk: scheme.onPrimaryContainer,
      secondaryFill: scheme.secondaryContainer,
      secondaryInk: scheme.onSecondaryContainer,
      rim: scheme.primary,
      peg: scheme.onPrimary,
      separator: scheme.surface,
      label: theme.textTheme.labelLarge ?? DefaultTextStyle.of(context).style,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
    return Semantics(
      container: true,
      label: 'Roda Sabtu',
      value: _semanticsValue(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double side = _sideFor(constraints);
          if (side <= 0) return const SizedBox.shrink();
          return Center(
            child: SizedBox.square(
              dimension: side,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox.square(
                    dimension: side * _radiusFactor * 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: scheme.secondary.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WheelPainter(
                          rotation: _rotation,
                          geometry: _geometry,
                          style: style,
                          artwork: _artwork,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PointerPainter(
                        fill: scheme.primary,
                        outline: scheme.onPrimary,
                        shadow: scheme.shadow,
                      ),
                    ),
                  ),
                  _WheelHub(
                    diameter: side * _hubFactor,
                    child: widget.centerChild,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelHub extends StatelessWidget {
  const _WheelHub({required this.diameter, required this.child});

  final double diameter;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget? content = child;
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.secondary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(child: SizedBox.expand(child: content)),
              ),
      ),
    );
  }
}

@immutable
final class _WheelMetrics {
  const _WheelMetrics._({
    required this.center,
    required this.radius,
    required this.rimWidth,
    required this.pegRadius,
    required this.gap,
    required this.labelInner,
    required this.labelOuter,
  });

  factory _WheelMetrics.of(Size size) {
    final double side = size.shortestSide;
    final double radius = side * _radiusFactor;
    final double rimWidth = math.max(4.0, radius * 0.075);
    final double gap = math.max(3.0, radius * 0.04);
    return _WheelMetrics._(
      center: size.center(Offset.zero),
      radius: radius,
      rimWidth: rimWidth,
      pegRadius: rimWidth * 0.28,
      gap: gap,
      labelInner: side * _hubFactor / 2 + gap,
      labelOuter: radius - rimWidth - gap,
    );
  }

  final Offset center;
  final double radius;
  final double rimWidth;
  final double pegRadius;
  final double gap;
  final double labelInner;
  final double labelOuter;
}

@immutable
final class _WheelStyle {
  const _WheelStyle({
    required this.productFill,
    required this.productInk,
    required this.primaryFill,
    required this.primaryInk,
    required this.secondaryFill,
    required this.secondaryInk,
    required this.rim,
    required this.peg,
    required this.separator,
    required this.label,
    required this.textScaler,
    required this.textDirection,
  });

  final Color productFill;
  final Color productInk;
  final Color primaryFill;
  final Color primaryInk;
  final Color secondaryFill;
  final Color secondaryInk;
  final Color rim;
  final Color peg;
  final Color separator;
  final TextStyle label;
  final TextScaler textScaler;
  final TextDirection textDirection;

  Color fillFor(SegmentTone tone) => switch (tone) {
    SegmentTone.product => productFill,
    SegmentTone.primary => primaryFill,
    SegmentTone.secondary => secondaryFill,
  };

  Color inkFor(SegmentTone tone) => switch (tone) {
    SegmentTone.product => productInk,
    SegmentTone.primary => primaryInk,
    SegmentTone.secondary => secondaryInk,
  };

  @override
  bool operator ==(Object other) =>
      other is _WheelStyle &&
      other.productFill == productFill &&
      other.productInk == productInk &&
      other.primaryFill == primaryFill &&
      other.primaryInk == primaryInk &&
      other.secondaryFill == secondaryFill &&
      other.secondaryInk == secondaryInk &&
      other.rim == rim &&
      other.peg == peg &&
      other.separator == separator &&
      other.label == label &&
      other.textScaler == textScaler &&
      other.textDirection == textDirection;

  @override
  int get hashCode => Object.hash(
    productFill,
    productInk,
    primaryFill,
    primaryInk,
    secondaryFill,
    secondaryInk,
    rim,
    peg,
    separator,
    label,
    textScaler,
    textDirection,
  );
}

/// Caches the wheel face as a picture so each animation frame is a single
/// rotated draw instead of re-laying out every label.
final class _WheelArtwork {
  ui.Picture? _picture;
  Size _size = Size.zero;
  WheelGeometry? _geometry;
  _WheelStyle? _style;

  ui.Picture resolve(Size size, WheelGeometry geometry, _WheelStyle style) {
    final ui.Picture? cached = _picture;
    if (cached != null &&
        size == _size &&
        geometry == _geometry &&
        style == _style) {
      return cached;
    }
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    _paintWheelFace(Canvas(recorder), _WheelMetrics.of(size), geometry, style);
    final ui.Picture picture = recorder.endRecording();
    cached?.dispose();
    _picture = picture;
    _size = size;
    _geometry = geometry;
    _style = style;
    return picture;
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.rotation,
    required this.geometry,
    required this.style,
    required this.artwork,
  }) : super(repaint: rotation);

  final Animation<double> rotation;
  final WheelGeometry geometry;
  final _WheelStyle style;
  final _WheelArtwork artwork;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ui.Picture picture = artwork.resolve(size, geometry, style);
    final Offset center = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation.value)
      ..translate(-center.dx, -center.dy)
      ..drawPicture(picture)
      ..restore();
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.geometry != geometry ||
      oldDelegate.style != style ||
      oldDelegate.artwork != artwork;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({
    required this.fill,
    required this.outline,
    required this.shadow,
  });

  final Color fill;
  final Color outline;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final _WheelMetrics metrics = _WheelMetrics.of(size);
    final Offset center = metrics.center;
    final double halfWidth = metrics.radius * 0.09;
    final double top = center.dy - metrics.radius - metrics.radius * 0.08;
    final double tip =
        center.dy - metrics.radius + metrics.rimWidth + metrics.radius * 0.015;
    final Path pointer = Path()
      ..moveTo(center.dx - halfWidth, top)
      ..lineTo(center.dx + halfWidth, top)
      ..lineTo(center.dx, tip)
      ..close();
    canvas
      ..drawShadow(pointer, shadow, 3, false)
      ..drawPath(pointer, Paint()..color = fill)
      ..drawPath(
        pointer,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.shadow != shadow;
}

Offset _outward(double wheelAngle) =>
    Offset(math.sin(wheelAngle), -math.cos(wheelAngle));

void _paintWheelFace(
  Canvas canvas,
  _WheelMetrics metrics,
  WheelGeometry geometry,
  _WheelStyle style,
) {
  final Offset center = metrics.center;
  final List<WheelSegment> segments = geometry.segments;
  final Rect disc = Rect.fromCircle(center: center, radius: metrics.radius);
  canvas.drawCircle(center, metrics.radius, Paint()..color = style.primaryFill);
  for (final WheelSegment segment in segments) {
    canvas.drawArc(
      disc,
      segment.start - math.pi / 2,
      segment.sweep,
      true,
      Paint()..color = style.fillFor(segment.tone),
    );
  }
  if (segments.length > 1) {
    final Paint separator = Paint()
      ..color = style.separator.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final double reach = metrics.radius - metrics.rimWidth;
    for (final WheelSegment segment in segments) {
      canvas.drawLine(
        center,
        center + _outward(segment.start) * reach,
        separator,
      );
    }
  }
  for (final WheelSegment segment in segments) {
    _paintSegmentContent(canvas, metrics, segment, style);
  }
  canvas.drawCircle(
    center,
    metrics.radius - metrics.rimWidth / 2,
    Paint()
      ..color = style.rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = metrics.rimWidth,
  );
  if (segments.length > 1) {
    final Paint peg = Paint()..color = style.peg;
    final double pegDistance = metrics.radius - metrics.rimWidth / 2;
    for (final WheelSegment segment in segments) {
      canvas.drawCircle(
        center + _outward(segment.start) * pegDistance,
        metrics.pegRadius,
        peg,
      );
    }
  }
}

void _paintSegmentContent(
  Canvas canvas,
  _WheelMetrics metrics,
  WheelSegment segment,
  _WheelStyle style,
) {
  final double bisector = segment.start + segment.sweep / 2 - math.pi / 2;
  final double spread = math.tan(segment.sweep / 2) * 0.9;
  final Color ink = style.inkFor(segment.tone);
  double outer = metrics.labelOuter;
  String text = segment.prize.label;
  bool hasGlyph = false;
  if (segment.prize.kind == PrizeKind.product) {
    text = _productSegmentLabel;
    final double glyph = math.min(
      math.min(metrics.radius * 0.17, _maxGlyphSize),
      2 * spread * outer / (1 + 2 * spread),
    );
    if (glyph >= _minGlyphSize) {
      _paintGlyph(
        canvas,
        center: metrics.center,
        bisector: bisector,
        distance: outer - glyph / 2,
        size: glyph,
        color: ink,
        textDirection: style.textDirection,
      );
      outer -= glyph + metrics.gap;
      hasGlyph = true;
    }
  }
  _paintRadialLabel(
    canvas,
    metrics: metrics,
    bisector: bisector,
    text: text,
    outer: outer,
    spread: spread,
    textStyle: style.label.copyWith(color: ink),
    style: style,
    truncate: !hasGlyph,
  );
}

double _fitScale({
  required double width,
  required double height,
  required double outer,
  required double length,
  required double spread,
}) {
  if (width <= 0 || height <= 0) return 1;
  final double byLength = length / width;
  final double byHeight = spread * outer / (height / 2 + spread * width);
  return math.min(1.0, math.min(byLength, byHeight));
}

void _paintRadialLabel(
  Canvas canvas, {
  required _WheelMetrics metrics,
  required double bisector,
  required String text,
  required double outer,
  required double spread,
  required TextStyle textStyle,
  required _WheelStyle style,
  required bool truncate,
}) {
  final double length = outer - metrics.labelInner;
  if (length <= 0 || spread <= 0) return;
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: style.textDirection,
    textScaler: style.textScaler,
    maxLines: 1,
    textWidthBasis: TextWidthBasis.longestLine,
  )..layout();
  try {
    double scale = _fitScale(
      width: painter.width,
      height: painter.height,
      outer: outer,
      length: length,
      spread: spread,
    );
    final double floor = math.min(1.0, _minLabelHeight / painter.height);
    if (scale < floor) {
      if (!truncate) return;
      scale = floor;
      final double maxWidth =
          math.min(length, outer - scale * painter.height / (2 * spread)) /
          scale;
      if (maxWidth < painter.height * 1.5) return;
      painter
        ..ellipsis = '…'
        ..layout(maxWidth: maxWidth);
    }
    canvas
      ..save()
      ..translate(metrics.center.dx, metrics.center.dy)
      ..rotate(bisector)
      ..translate(outer - painter.width * scale, -painter.height * scale / 2)
      ..scale(scale);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  } finally {
    painter.dispose();
  }
}

void _paintGlyph(
  Canvas canvas, {
  required Offset center,
  required double bisector,
  required double distance,
  required double size,
  required Color color,
  required TextDirection textDirection,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(_productGlyph.codePoint),
      style: TextStyle(
        inherit: false,
        color: color,
        fontSize: size,
        fontFamily: _productGlyph.fontFamily,
        package: _productGlyph.fontPackage,
        fontFamilyFallback: _productGlyph.fontFamilyFallback,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
    textDirection: textDirection,
    textScaler: TextScaler.noScaling,
  )..layout();
  try {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(bisector + math.pi / 2)
      ..translate(0, -distance);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  } finally {
    painter.dispose();
  }
}
