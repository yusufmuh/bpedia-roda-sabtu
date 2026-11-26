import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'festive_palette.dart';
import 'motion.dart';

/// Varian warna [CandyButton].
enum CandyVariant { pink, gold, tonal }

/// Warna satu varian tombol permen.
@immutable
class CandyColors {
  const CandyColors({
    required this.top,
    required this.bottom,
    required this.lip,
    required this.label,
    required this.textShadow,
    required this.gloss,
  });

  final Color top;
  final Color bottom;
  final Color lip;
  final Color label;
  final Color textShadow;

  /// Kekuatan sorot putih (0..1).
  final double gloss;

  static const CandyColors pink = CandyColors(
    top: FestivePalette.candyTop,
    bottom: FestivePalette.candyBottom,
    lip: FestivePalette.candyLip,
    label: Colors.white,
    textShadow: Color(0x809E1242),
    gloss: 1,
  );

  static const CandyColors gold = CandyColors(
    top: FestivePalette.goldLight,
    bottom: FestivePalette.gold,
    lip: FestivePalette.goldDeep,
    label: FestivePalette.onGold,
    textShadow: Color(0x80FFF3C4),
    gloss: 1,
  );

  /// Varian tonal mengikuti terang/gelap host.
  static CandyColors tonal(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const CandyColors(
        top: Color(0xFFFFEDF2),
        bottom: Color(0xFFFFD6E2),
        lip: Color(0xFFF2A7BF),
        label: FestivePalette.festBottom,
        textShadow: Color(0x00000000),
        gloss: 0.7,
      );
    }
    return const CandyColors(
      top: Color(0xFF5A1F3A),
      bottom: Color(0xFF43152B),
      lip: Color(0xFF260A18),
      label: Color(0xFFFFC2D4),
      textShadow: Color(0x00000000),
      gloss: 0.28,
    );
  }

  /// Tombol nonaktif: netral dari [ColorScheme] host.
  static CandyColors disabled(ColorScheme scheme) {
    final face = Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.10), scheme.surface);
    return CandyColors(
      top: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.07), scheme.surface),
      bottom: face,
      lip: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.20), scheme.surface),
      label: scheme.onSurface.withValues(alpha: 0.48),
      textShadow: const Color(0x00000000),
      gloss: scheme.brightness == Brightness.light ? 0.5 : 0.12,
    );
  }
}

/// Tombol utama zona game bergaya permen 3D.
///
/// Wajah bergradasi dengan sorot kaca di atas, bibir bawah [lipHeight] yang
/// tampak sebagai ketebalan, kilau yang menyapu tiap [shineInterval], dan
/// wajah turun 3 dp saat ditekan. `onPressed == null` menonaktifkan tombol;
/// [busy] menahan ketukan dan menampilkan pemutar.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sublabel,
    this.icon,
    this.variant = CandyVariant.pink,
    this.busy = false,
    this.expand = true,
    this.height = 56,
    this.shine = true,
    this.shineInterval = const Duration(seconds: 3),
    this.pulse = false,
    this.semanticLabel,
    this.haptic = true,
  });

  final String label;
  final String? sublabel;

  /// Seni kecil di kiri label (ikon atau koin).
  final Widget? icon;
  final VoidCallback? onPressed;
  final CandyVariant variant;
  final bool busy;

  /// Melebar memenuhi induk.
  final bool expand;

  /// Tinggi minimum; tombol meninggi bila teks membungkus (skala huruf besar).
  final double height;
  final bool shine;
  final Duration shineInterval;

  /// Berdenyut pelan (skala 1 → 1,03) untuk menarik perhatian ke aksi
  /// berikutnya, mis. "Klaim" yang siap diambil.
  final bool pulse;
  final String? semanticLabel;
  final bool haptic;

  /// Tinggi bibir bawah (dp).
  static const double lipHeight = 4;

  /// Turun wajah saat ditekan (dp).
  static const double pressTravel = 3;

  /// Skala puncak denyut [pulse].
  static const double pulseScale = 1.03;

  @override
  State<CandyButton> createState() => _CandyButtonState();

  /// Sorot kaca muka tombol (KRITIK G3): pita setinggi 40% muka, inset 12 dp
  /// dari kiri dan kanan, 3 dp dari atas.
  @visibleForTesting
  static Rect glossRectFor(Rect face) => Rect.fromLTRB(
        face.left + 12,
        face.top + 3,
        math.max(face.left + 12, face.right - 12),
        face.top + face.height * 0.40,
      );
}

class _CandyButtonState extends State<CandyButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final AnimationController _shine = AnimationController(vsync: this, duration: widget.shineInterval);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CandyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shineInterval != widget.shineInterval) {
      _shine.duration = widget.shineInterval;
      if (_shine.isAnimating) _shine.repeat();
    }
    if (!_enabled && _press.value > 0) _press.reverse();
    _sync();
  }

  void _sync() {
    final reduce = reduceMotionOf(context);
    final shining = widget.shine && _enabled && !reduce;
    if (!shining) _shine.value = 0;
    syncRepeat(_shine, enabled: shining);
    syncRepeat(_spin, enabled: widget.busy && !reduce);
    final pulsing = widget.pulse && _enabled && !reduce;
    if (!pulsing) _pulse.value = 0;
    syncRepeat(_pulse, enabled: pulsing, reverse: true);
  }

  void _activate() {
    final onPressed = widget.onPressed;
    if (onPressed == null || widget.busy) return;
    if (widget.haptic) HapticFeedback.lightImpact();
    onPressed();
  }

  void _down() {
    if (_enabled) _press.forward();
  }

  void _up() => _press.reverse();

  @override
  void dispose() {
    _press.dispose();
    _shine.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  CandyColors _colors(ColorScheme scheme) {
    if (widget.onPressed == null) return CandyColors.disabled(scheme);
    return switch (widget.variant) {
      CandyVariant.pink => CandyColors.pink,
      CandyVariant.gold => CandyColors.gold,
      CandyVariant.tonal => CandyColors.tonal(scheme.brightness),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colors(theme.colorScheme);
    final disabled = widget.onPressed == null;
    final base = theme.textTheme.labelLarge ?? const TextStyle();
    final shadows = colors.textShadow.a == 0
        ? null
        : <Shadow>[Shadow(color: colors.textShadow, offset: const Offset(0, 1), blurRadius: 1)];
    final labelStyle = base.copyWith(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: colors.label,
      shadows: shadows,
    );
    final subStyle = base.copyWith(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      color: colors.label.withValues(alpha: colors.label.a * 0.86),
    );
    final sublabel = widget.sublabel;

    Widget? leading = widget.icon;
    if (widget.busy) {
      leading = SizedBox.square(
        dimension: 20,
        child: CustomPaint(painter: _SpinnerPainter(turn: _spin, color: colors.label)),
      );
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          IconTheme.merge(data: IconThemeData(color: colors.label, size: 22), child: leading),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.label, style: labelStyle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (sublabel != null)
                Text(sublabel, style: subStyle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );

    Widget button = CustomPaint(
      painter: _CandyPainter(
        press: _press,
        shine: _shine,
        colors: colors,
        flat: disabled,
        dimmed: widget.busy,
        focused: _focused,
        focusColor: theme.colorScheme.onSurface,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(widget.height, 48), minWidth: math.max(widget.height, 48)),
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, CandyButton.pressTravel * _press.value),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 7, 22, 7 + CandyButton.lipHeight),
            child: Center(widthFactor: widget.expand ? null : 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );

    button = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _activate();
          return null;
        }),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: _enabled ? _activate : null,
        child: button,
      ),
    );

    if (widget.pulse) {
      button = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: 1 + (CandyButton.pulseScale - 1) * Curves.easeInOut.transform(_pulse.value),
          child: child,
        ),
        child: button,
      );
    }

    final spoken = widget.semanticLabel ?? (sublabel == null ? widget.label : '${widget.label}, $sublabel');
    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      label: spoken,
      value: widget.busy ? 'Memproses' : null,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: widget.expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }
}

class _CandyPainter extends CustomPainter {
  _CandyPainter({
    required this.press,
    required this.shine,
    required this.colors,
    required this.flat,
    required this.dimmed,
    required this.focused,
    required this.focusColor,
  }) : super(repaint: Listenable.merge(<Listenable>[press, shine]));

  final Animation<double> press;
  final Animation<double> shine;
  final CandyColors colors;

  /// Nonaktif: tanpa bayangan berwarna dan tanpa kilau.
  final bool flat;
  final bool dimmed;
  final bool focused;
  final Color focusColor;

  /// Bagian dari satu siklus kilau yang dipakai untuk sapuan.
  static const double sweepFraction = 0.24;

  @override
  void paint(Canvas canvas, Size size) {
    const lip = CandyButton.lipHeight;
    final travel = CandyButton.pressTravel * press.value;
    final faceHeight = size.height - lip;
    final radius = Radius.circular(math.min(faceHeight / 2, 30));
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, travel, size.width, size.height - travel), radius);
    final face = RRect.fromRectAndRadius(Rect.fromLTWH(0, travel, size.width, faceHeight), radius);

    if (!flat) {
      final lift = 1 - press.value;
      canvas.drawRRect(
        body.shift(Offset(0, 3 + 3 * lift)),
        Paint()
          ..color = colors.lip.withValues(alpha: 0.30 + 0.12 * lift)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 5 * lift),
      );
    }

    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, body.top),
          Offset(0, body.bottom),
          <Color>[colors.lip, Color.lerp(colors.lip, Colors.black, 0.22)!],
        ),
    );

    final faceRect = face.outerRect;
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.linear(
          faceRect.topCenter,
          faceRect.bottomCenter,
          <Color>[colors.top, Color.lerp(colors.top, colors.bottom, 0.55)!, colors.bottom],
          const <double>[0, 0.5, 1],
        ),
    );

    canvas
      ..save()
      ..clipRRect(face);

    // Pantulan lembut di tepi bawah wajah.
    canvas.drawRect(
      Rect.fromLTRB(faceRect.left, faceRect.bottom - faceHeight * 0.34, faceRect.right, faceRect.bottom),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, faceRect.bottom - faceHeight * 0.34),
          Offset(0, faceRect.bottom),
          <Color>[Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.16 * colors.gloss)],
        ),
    );

    // Sorot kaca (KRITIK G3): pita gradien 35% -> 0 setinggi 40% muka, inset 12 dp.
    final glossRect = CandyButton.glossRectFor(faceRect);
    if (glossRect.width > 0 && glossRect.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(glossRect, Radius.circular(glossRect.height / 2)),
        Paint()
          ..shader = ui.Gradient.linear(
            glossRect.topCenter,
            glossRect.bottomCenter,
            <Color>[Colors.white.withValues(alpha: 0.35 * colors.gloss), Colors.white.withValues(alpha: 0)],
          ),
      );
    }

    final value = shine.value;
    if (!flat && value > 0 && value < sweepFraction) {
      final t = Curves.easeInOut.transform(value / sweepFraction);
      final band = math.max(faceHeight * 1.1, size.width * 0.16);
      final x = -band + (size.width + band * 2) * t;
      final skew = faceHeight * 0.45;
      final path = Path()
        ..moveTo(x + skew, faceRect.top)
        ..lineTo(x + skew + band, faceRect.top)
        ..lineTo(x - skew + band, faceRect.bottom)
        ..lineTo(x - skew, faceRect.bottom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, 0),
            Offset(x + band, 0),
            <Color>[
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.62),
              Colors.white.withValues(alpha: 0),
            ],
            const <double>[0, 0.5, 1],
          ),
      );
    }

    if (dimmed) {
      canvas.drawRect(faceRect, Paint()..color = colors.lip.withValues(alpha: 0.22));
    }
    canvas.restore();

    // Garis tepi terang di atas, memudar ke bawah.
    canvas.drawRRect(
      face.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          faceRect.topCenter,
          faceRect.bottomCenter,
          <Color>[Colors.white.withValues(alpha: 0.65 * colors.gloss), Colors.white.withValues(alpha: 0)],
          const <double>[0, 0.7],
        ),
    );

    if (focused) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), radius).inflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor,
      );
    }
  }

  @override
  bool shouldRepaint(_CandyPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.flat != flat ||
      oldDelegate.dimmed != dimmed ||
      oldDelegate.focused != focused ||
      oldDelegate.focusColor != focusColor;
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.turn, required this.color}) : super(repaint: turn);

  final Animation<double> turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, paint..color = color.withValues(alpha: color.a * 0.28))
      ..drawArc(rect, turn.value * 2 * math.pi - math.pi / 2, math.pi * 0.7, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => oldDelegate.color != color;
}
