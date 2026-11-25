import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `true` bila pengguna meminta gerak dikurangi (`MediaQuery.disableAnimations`).
bool reduceMotionOf(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Memaksa kurangi gerak untuk subpohon, mis. dari sakelar pengaturan host.
class ReduceMotion extends StatelessWidget {
  const ReduceMotion({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final data = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(data: data.copyWith(disableAnimations: true), child: child);
  }
}

/// Menyelaraskan pengendali berulang: jalan saat [enabled], diam selain itu.
void syncRepeat(AnimationController controller, {required bool enabled, bool reverse = false}) {
  if (enabled) {
    if (!controller.isAnimating) controller.repeat(reverse: reverse);
  } else if (controller.isAnimating) {
    controller.stop();
  }
}

/// Pembungkus sentuh: mengecil ke [pressedScale] saat ditekan (140 ms), area
/// sentuh minimal [minSize], Semantics tombol, dan aktivasi papan ketik.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.minSize = 48,
    this.semanticLabel,
    this.tooltip,
    this.haptic = true,
    this.focusRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;

  /// `null` menonaktifkan tombol.
  final VoidCallback? onTap;
  final double pressedScale;
  final double minSize;

  /// Label pembaca layar. Bila `null`, Semantics anak dipakai apa adanya.
  final String? semanticLabel;
  final String? tooltip;
  final bool haptic;
  final BorderRadius focusRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 180),
  );
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    onTap();
  }

  void _down() {
    if (_enabled) _press.forward();
  }

  void _up() => _press.reverse();

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final scheme = Theme.of(context).colorScheme;
    Widget child = AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_press.value);
        if (reduce) return Opacity(opacity: 1 - 0.2 * t, child: child);
        return Transform.scale(scale: 1 - (1 - widget.pressedScale) * t, child: child);
      },
      child: widget.child,
    );
    child = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: widget.focusRadius,
        border: _focused ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: child,
    );
    child = ConstrainedBox(
      constraints: BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
    final label = widget.semanticLabel;
    child = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _activate();
          return null;
        }),
      },
      // Semantics berada di dalam detektor supaya simpul tombol ikut membawa
      // status fokus papan ketik.
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: label,
        excludeSemantics: label != null,
        onTap: _enabled ? _activate : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          onTap: _enabled ? _activate : null,
          child: child,
        ),
      ),
    );
    final tooltip = widget.tooltip;
    return tooltip == null ? child : Tooltip(message: tooltip, child: child);
  }
}

/// Mengayun [child] naik-turun pelan (seni 3D melayang). Diam saat kurangi
/// gerak atau saat tidak terlihat.
class Bobbing extends StatefulWidget {
  const Bobbing({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 2600),
    this.phase = 0,
    this.tilt = 0,
  });

  final Widget child;

  /// Simpangan vertikal (dp).
  final double amplitude;
  final Duration period;

  /// Geser fase 0..1 supaya beberapa objek tidak bergerak serempak.
  final double phase;

  /// Goyang putar maksimum (radian).
  final double tilt;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncRepeat(_controller, enabled: !reduceMotionOf(context));
  }

  @override
  void didUpdateWidget(Bobbing oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (_controller.value + widget.phase) * 2 * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(0, math.sin(angle) * widget.amplitude, 0)
            ..rotateZ(math.cos(angle) * widget.tilt),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
