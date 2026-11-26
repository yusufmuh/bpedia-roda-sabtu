import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'candy_button.dart';
import 'confetti.dart';
import 'count_up.dart';
import 'festive_palette.dart';
import 'game_scaffold.dart';
import 'motion.dart';
import 'sunburst.dart';

/// Menampilkan lembar hasil dari bawah layar.
///
/// [builder] mengembalikan [ResultSheet]; aksi di dalamnya menutup lembar
/// dengan `Navigator.pop(context)`.
Future<T?> showResultSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB32A0A18),
    elevation: 0,
    builder: builder,
  );
}

/// Lembar hasil megah: panggung pesta dengan cincin cahaya berputar, podium,
/// slot seni, dan konfeti; di bawahnya panel `surface` berisi angka, nama
/// hadiah, penjelasan, tombol permen, dan aksi sekunder.
class ResultSheet extends StatefulWidget {
  const ResultSheet({
    super.key,
    required this.title,
    required this.message,
    required this.art,
    required this.primaryLabel,
    required this.onPrimary,
    this.ribbon,
    this.pill,
    this.amount,
    this.amountPrefix = '+',
    this.amountSuffix = '',
    this.caption,
    this.note,
    this.companion,
    this.podium,
    this.showPodium = true,
    this.primaryVariant = CandyVariant.pink,
    this.primaryIcon,
    this.pulsePrimary = true,
    this.secondaryLabel,
    this.onSecondary,
    this.showClose = true,
    this.onClose,
    this.confetti = true,
    this.artHeight = 132,
    this.artWidth = 200,
  });

  /// Judul di panggung, mis. "Selamat, kamu menang!".
  final String title;

  /// Penjelasan di panel, mis. cara hadiah dikirim.
  final String message;

  /// Seni hadiah di atas podium (foto produk, tumpukan koin). Diletakkan di
  /// dasar-tengah kotak tetap [artWidth] x [artHeight] dengan batas longgar,
  /// jadi gambar besar mengecil mengikuti kotak dan anak tanpa ukuran
  /// (`AspectRatio`, `SizedBox.expand`) mengisi kotak.
  final Widget art;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Pita emas yang menonjol di atas tepi lembar, mis. "Selamat!". Dengan
  /// pita, [title] menjadi kalimat pendamping di bawahnya.
  final String? ribbon;

  /// Pil emas di bawah judul, mis. "1 produk gratis".
  final String? pill;

  /// Angka besar yang naik dari 0, mis. `5` → "+5 Kelopak" dengan
  /// [amountSuffix] `' Kelopak'`.
  final int? amount;
  final String amountPrefix;
  final String amountSuffix;

  /// Nama hadiah di panel (tebal).
  final String? caption;

  /// Catatan kecil dalam pil di bawah pesan, mis. "1 Kelopak = Rp100".
  final String? note;

  /// Pendamping di kanan podium, mis. Bipy menari.
  final Widget? companion;

  /// Gambar podium pengganti podium vektor.
  final ImageProvider? podium;
  final bool showPodium;
  final CandyVariant primaryVariant;
  final Widget? primaryIcon;

  /// Tombol utama berdenyut pelan supaya langkah berikutnya jelas.
  final bool pulsePrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool showClose;

  /// Bawaan: `Navigator.maybePop`.
  final VoidCallback? onClose;
  final bool confetti;
  final double artHeight;
  final double artWidth;

  @override
  State<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  final ConfettiController _confetti = ConfettiController();
  bool _started = false;
  bool _fired = false;

  static const double _overlap = 24;

  /// Bagian pita yang menonjol di atas tepi lembar.
  static const double _ribbonRise = 20;

  @override
  void initState() {
    super.initState();
    _intro.addListener(_maybeFire);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) _intro.duration = const Duration(milliseconds: 200);
    _intro.forward();
  }

  void _maybeFire() {
    if (_fired || !widget.confetti || _intro.value < 0.18) return;
    _fired = true;
    _confetti.fire(style: ConfettiStyle.cannons);
  }

  @override
  void dispose() {
    _intro.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final reduce = reduceMotionOf(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final panel = FestivePalette.panelColor(scheme);
    final amount = widget.amount;
    final caption = widget.caption;
    final pill = widget.pill;
    final note = widget.note;
    final ribbon = widget.ribbon;
    final secondaryLabel = widget.secondaryLabel;
    // Aksi sekunder sudah membawa bantalan sentuh 48 dp di bawah teksnya.
    final bottomGap = secondaryLabel == null ? 32.0 : 20.0;

    // Urutan lapis: latar, sinar, kilau, konfeti, lalu judul/pil/seni di atas
    // supaya partikel tidak pernah menutupi teks (W1-04).
    final stage = DecoratedBox(
      decoration: const BoxDecoration(gradient: FestivePalette.stage),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: SunburstRays(opacity: 0.09, center: Alignment(0, 0.25), rayCount: 14)),
          const Positioned.fill(child: Sparkles(count: 14, seed: 9)),
          Positioned.fill(child: ConfettiBurst(controller: _confetti, particleCount: 90)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (ribbon == null) ...<Widget>[
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 22),
                ] else
                  const SizedBox(height: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: base.copyWith(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const <Shadow>[
                        Shadow(color: Color(0xD99E1242), offset: Offset(0, 1.5)),
                        Shadow(color: Color(0x666B1439), offset: Offset(0, 4), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
                if (pill != null) ...<Widget>[
                  const SizedBox(height: 10),
                  _GoldPill(label: pill),
                ],
                const SizedBox(height: 4),
                _Stage(
                  intro: _intro,
                  reduce: reduce,
                  art: widget.art,
                  artHeight: widget.artHeight,
                  artWidth: widget.artWidth,
                  companion: widget.companion,
                  podium: widget.podium,
                  showPodium: widget.showPodium,
                ),
                const SizedBox(height: 22 + _overlap),
              ],
            ),
          ),
          if (widget.showClose)
            Positioned(
              top: 6,
              right: 8,
              child: Pressable(
                onTap: widget.onClose ?? () => Navigator.maybePop(context),
                semanticLabel: 'Tutup',
                tooltip: 'Tutup',
                focusRadius: const BorderRadius.all(Radius.circular(24)),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.24)),
                  child: const SizedBox.square(
                    dimension: 36,
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Panel naik 24 dp menutupi kaki panggung. Celah 24 dp yang tertinggal di
    // bawah berwarna sama dengan panel, jadi dihitung sebagai jarak bawah.
    final body = Transform.translate(
      offset: const Offset(0, -_overlap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, math.max(0, media.viewPadding.bottom + bottomGap - _overlap)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (amount != null) ...<Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CountUpText(
                          value: amount,
                          from: 0,
                          prefix: widget.amountPrefix,
                          suffix: widget.amountSuffix,
                          duration: const Duration(milliseconds: 900),
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                            fontSize: 34,
                            height: 40 / 34,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (caption != null) ...<Widget>[
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: base.copyWith(
                          fontSize: 16,
                          height: 22 / 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: base.copyWith(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant),
                    ),
                    if (note != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Center(child: _NotePill(label: note)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CandyButton(
                label: widget.primaryLabel,
                onPressed: widget.onPrimary,
                variant: widget.primaryVariant,
                icon: widget.primaryIcon,
                pulse: widget.pulsePrimary,
              ),
              if (secondaryLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Pressable(
                      onTap: widget.onSecondary,
                      semanticLabel: secondaryLabel,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          secondaryLabel,
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final sheet = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: panel,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              stage,
              body,
            ],
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
      child: ribbon == null
          ? sheet
          : Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                Padding(padding: const EdgeInsets.only(top: _ribbonRise), child: sheet),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: ScaleTransition(
                    scale: reduce
                        ? const AlwaysStoppedAnimation<double>(1)
                        : CurvedAnimation(parent: _intro, curve: const Interval(0.1, 0.75, curve: Curves.elasticOut)),
                    child: FestiveRibbon(label: ribbon, large: true),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoldPill extends StatelessWidget {
  const _GoldPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return DecoratedBox(
      decoration: const ShapeDecoration(
        gradient: FestivePalette.goldSheen,
        shape: StadiumBorder(side: BorderSide(color: Color(0xFFFFF3C4), width: 1.5)),
        shadows: <BoxShadow>[BoxShadow(color: Color(0x596B1439), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w700,
            color: FestivePalette.onGold,
          ),
        ),
      ),
    );
  }
}

class _NotePill extends StatelessWidget {
  const _NotePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.labelMedium ?? const TextStyle();
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: base.copyWith(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.intro,
    required this.reduce,
    required this.art,
    required this.artHeight,
    required this.artWidth,
    required this.companion,
    required this.podium,
    required this.showPodium,
  });

  final Animation<double> intro;
  final bool reduce;
  final Widget art;
  final double artHeight;
  final double artWidth;
  final Widget? companion;
  final ImageProvider? podium;
  final bool showPodium;

  static const double _podiumWidth = 196;
  static const double _podiumHeight = 62;

  @override
  Widget build(BuildContext context) {
    final podium = this.podium;
    final ringSize = artHeight + 150;
    final height = artHeight + (showPodium ? _podiumHeight * 0.66 : 0) + 44;
    final podiumRest = showPodium ? _podiumHeight * 0.62 : 0.0;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            bottom: podiumRest + artHeight / 2 - ringSize / 2,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: intro, curve: const Interval(0, 0.5)),
              child: GlowRing(diameter: ringSize),
            ),
          ),
          if (showPodium)
            Positioned(
              bottom: 0,
              child: podium == null
                  ? const SizedBox(
                      width: _podiumWidth,
                      height: _podiumHeight,
                      child: CustomPaint(painter: _PodiumPainter()),
                    )
                  : Image(image: podium, width: _podiumWidth, height: _podiumHeight * 1.4, fit: BoxFit.contain),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: podiumRest,
            child: AnimatedBuilder(
              animation: intro,
              builder: (context, child) {
                if (reduce) return Opacity(opacity: intro.value, child: child);
                final t = intro.value;
                final scale = 0.4 + 0.6 * Curves.elasticOut.transform(t);
                return Opacity(
                  opacity: (t / 0.2).clamp(0.0, 1.0),
                  child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
                );
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: SizedBox(
                  width: artWidth,
                  height: artHeight,
                  child: Align(alignment: Alignment.bottomCenter, child: art),
                ),
              ),
            ),
          ),
          if (companion != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: intro, curve: const Interval(0.2, 0.7)),
                child: companion,
              ),
            ),
        ],
      ),
    );
  }
}

/// Podium silinder pendek: sisi pink mengilap, tutup krem, bibir emas.
class _PodiumPainter extends CustomPainter {
  const _PodiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final topHeight = h * 0.52;
    final sideHeight = h - topHeight / 2 - 6;
    final top = Rect.fromLTWH(0, 0, w, topHeight);
    final bottom = top.shift(Offset(0, sideHeight));

    canvas.drawOval(
      Rect.fromLTWH(-w * 0.06, h - topHeight * 0.55, w * 1.12, topHeight * 0.9),
      Paint()
        ..color = const Color(0x664A0C26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final side = Path()
      ..moveTo(0, top.center.dy)
      ..lineTo(0, bottom.center.dy)
      ..arcTo(bottom, math.pi, -math.pi, false)
      ..lineTo(w, top.center.dy)
      ..close();
    canvas.drawPath(
      side,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, 0),
          const <Color>[
            Color(0xFFD81F57),
            Color(0xFFFF8FB1),
            Color(0xFFF0447A),
            Color(0xFF9E1242),
          ],
          const <double>[0, 0.2, 0.55, 1],
        ),
    );
    canvas.drawPath(
      side,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top.center.dy),
          Offset(0, bottom.bottom),
          <Color>[Colors.white.withValues(alpha: 0), const Color(0x556B1439)],
        ),
    );

    canvas
      ..drawOval(top, Paint()..shader = FestivePalette.goldSheen.createShader(top))
      ..drawOval(
        top.deflate(4),
        Paint()
          ..shader = ui.Gradient.radial(
            top.center - Offset(w * 0.15, topHeight * 0.1),
            w * 0.6,
            const <Color>[Colors.white, FestivePalette.festCream, FestivePalette.festBlush],
            const <double>[0, 0.45, 1],
          ),
      );
  }

  @override
  bool shouldRepaint(_PodiumPainter oldDelegate) => false;
}
