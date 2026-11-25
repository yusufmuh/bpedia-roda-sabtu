import 'package:flutter/material.dart';

import 'motion.dart';

/// `12800` → `12.800` (pemisah ribuan Indonesia).
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Angka yang naik (atau turun) ke [value] tiap kali nilainya berubah.
///
/// Memakai angka tabular supaya lebar tidak bergoyang. Saat kurangi gerak,
/// angka langsung berganti. Pembaca layar hanya menerima nilai akhir.
class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.from,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.formatter = formatThousands,
    this.bump = false,
    this.textAlign,
    this.semanticsLabel,
  });

  final int value;

  /// Nilai awal animasi pertama. `null` = tampil langsung di [value].
  final int? from;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final String Function(int value) formatter;

  /// Membal sedikit (1 → 1,14 → 1) selama angka berubah.
  final bool bump;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late int _begin = widget.from ?? widget.value;
  late int _end = widget.value;
  bool _started = false;

  int get _shown {
    if (!_controller.isAnimating && _controller.value == 0) return _begin;
    final t = widget.curve.transform(_controller.value);
    return (_begin + (_end - _begin) * t).round();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_begin == _end) return;
    if (reduceMotionOf(context)) {
      _begin = _end;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.value == _end) return;
    final current = _shown;
    _end = widget.value;
    if (reduceMotionOf(context)) {
      _controller.stop();
      _controller.value = 0;
      _begin = _end;
    } else {
      _begin = current;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _text(int value) => '${widget.prefix}${widget.formatter(value)}${widget.suffix}';

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final style = base.copyWith(
      fontFeatures: <FontFeature>[...?base.fontFeatures, const FontFeature.tabularFigures()],
    );
    return Semantics(
      label: widget.semanticsLabel ?? _text(_end),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final text = Text(_text(_shown), style: style, textAlign: widget.textAlign, maxLines: 1);
            if (!widget.bump || !_controller.isAnimating) return text;
            final t = _controller.value;
            final scale = 1 + 0.14 * (t < 0.3 ? t / 0.3 : 1 - Curves.easeOut.transform((t - 0.3) / 0.7));
            return Transform.scale(scale: scale, child: text);
          },
        ),
      ),
    );
  }
}
