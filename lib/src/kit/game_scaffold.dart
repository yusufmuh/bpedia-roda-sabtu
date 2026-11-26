import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coin_fly.dart';
import 'count_up.dart';
import 'festive_palette.dart';
import 'motion.dart';
import 'sunburst.dart';

/// Latar pesta: gradasi, bokeh lembut, sinar berputar pelan, dan kilau
/// berkelip, dengan [child] di atasnya.
///
/// Tanpa [height], tinggi mengikuti [child]; tanpa [child], mengisi induk.
class FestiveHero extends StatelessWidget {
  const FestiveHero({
    super.key,
    this.child,
    this.height,
    this.gradient = FestivePalette.hero,
    this.rays = true,
    this.rayOpacity = 0.06,
    this.rayCenter = const Alignment(0.55, -0.1),
    this.sparkles = true,
    this.padding = EdgeInsets.zero,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget? child;
  final double? height;
  final Gradient gradient;
  final bool rays;
  final double rayOpacity;
  final Alignment rayCenter;
  final bool sparkles;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    final backdrop = <Widget>[
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: gradient))),
      const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _BokehPainter()))),
      if (rays)
        Positioned.fill(
          child: SunburstRays(opacity: rayOpacity, center: rayCenter, period: const Duration(seconds: 48)),
        ),
      if (sparkles) const Positioned.fill(child: Sparkles(count: 9, maxSize: 14)),
    ];
    Widget hero = Stack(
      clipBehavior: Clip.hardEdge,
      fit: child == null ? StackFit.expand : StackFit.passthrough,
      children: <Widget>[
        ...backdrop,
        if (child != null) Padding(padding: padding, child: child),
      ],
    );
    if (borderRadius != BorderRadius.zero) {
      hero = ClipRRect(borderRadius: borderRadius, child: hero);
    }
    return SizedBox(width: double.infinity, height: height, child: hero);
  }
}

class _BokehPainter extends CustomPainter {
  const _BokehPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    void blob(double x, double y, double radius, double alpha) {
      final center = Offset(size.width * x, size.height * y);
      paint.shader = RadialGradient(
        colors: <Color>[Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    canvas.clipRect(Offset.zero & size);
    blob(0.1, 0.12, size.width * 0.42, 0.20);
    blob(0.92, 0.3, size.width * 0.34, 0.14);
    blob(0.45, 1.05, size.width * 0.5, 0.10);
  }

  @override
  bool shouldRepaint(_BokehPainter oldDelegate) => false;
}

/// Chip kaca tembus pandang untuk hero pesta (saldo, "Riwayat", "Cara pakai").
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    this.label,
    this.child,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.strong = false,
  }) : assert(label != null || child != null, 'Beri label atau child.');

  final String? label;

  /// Isi pengganti [label] (mis. angka yang naik). Mewarisi gaya teks chip.
  final Widget? child;
  final Widget? leading;
  final Widget? trailing;

  /// Bila diisi, chip menjadi tombol dengan area sentuh 48.
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Kaca lebih pekat untuk chip utama (mis. saldo).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final textStyle = base.copyWith(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: strong ? 0.30 : 0.20),
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: strong ? 0.65 : 0.45))),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading == null ? 12 : 8, 5, trailing == null ? 12 : 8, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                IconTheme.merge(data: const IconThemeData(color: Colors.white, size: 16), child: leading!),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: DefaultTextStyle.merge(
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: child ?? Text(label!),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 4),
                IconTheme.merge(data: const IconThemeData(color: Colors.white, size: 16), child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(label: semanticLabel, excludeSemantics: semanticLabel != null, child: chip);
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      focusRadius: const BorderRadius.all(Radius.circular(24)),
      child: chip,
    );
  }
}

/// Chip saldo Kelopak di hero: koin dan angka yang naik serta membal tiap
/// kali [value] berubah.
///
/// Beri `GlobalKey` sebagai `key` supaya chip bisa menjadi tujuan
/// [CoinFlight]. Dengan [onTap], chip menjadi tombol berpanah (mis. ke riwayat).
class BalanceChip extends StatelessWidget {
  const BalanceChip({
    super.key,
    required this.value,
    this.coin,
    this.suffix = '',
    this.onTap,
    this.semanticLabel,
  });

  final int value;

  /// Gambar koin (mis. `assets/art/coin.webp`); bawaan [KelopakCoin].
  final ImageProvider? coin;
  final String suffix;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final coin = this.coin;
    return GlassChip(
      strong: true,
      onTap: onTap,
      semanticLabel: semanticLabel ?? 'Saldo ${formatThousands(value)} Kelopak',
      leading: coin == null
          ? const KelopakCoin(size: 24)
          : Image(image: coin, width: 24, height: 24, filterQuality: FilterQuality.medium),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, size: 18),
      child: CountUpText(
        value: value,
        suffix: suffix,
        bump: true,
        style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Warna [FestiveRibbon].
enum FestiveRibbonTone { gold, pink }

/// Pita bergaya stiker untuk label hadiah ("Bonus", "Misi", "Gratis"):
/// badan bergradasi dengan dua ekor terlipat di belakangnya.
///
/// [large] membuat pita tajuk (huruf 18) untuk kepala lembar hasil atau
/// pembatas seksi, mis. "Selamat!".
class FestiveRibbon extends StatelessWidget {
  const FestiveRibbon({
    super.key,
    required this.label,
    this.tone = FestiveRibbonTone.gold,
    this.large = false,
  });

  final String label;
  final FestiveRibbonTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    final gold = tone == FestiveRibbonTone.gold;
    return CustomPaint(
      painter: _RibbonPainter(gold: gold, tail: large ? 20 : 9, drop: large ? 9 : 4),
      child: Padding(
        padding: large ? const EdgeInsets.fromLTRB(36, 7, 36, 16) : const EdgeInsets.fromLTRB(14, 3, 14, 7),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontSize: large ? 18 : 11,
            height: large ? 24 / 18 : 14 / 11,
            fontWeight: FontWeight.w800,
            letterSpacing: large ? 0.4 : 0.2,
            color: gold ? FestivePalette.onGold : Colors.white,
            shadows: large
                ? <Shadow>[
                    Shadow(
                      color: gold ? const Color(0x99FFF3C4) : const Color(0x809E1242),
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.gold, required this.tail, required this.drop});

  final bool gold;

  /// Lebar ekor yang terlihat di kiri dan kanan badan.
  final double tail;

  /// Turun ekor terhadap badan.
  final double drop;

  @override
  void paint(Canvas canvas, Size size) {
    final top = gold ? FestivePalette.goldLight : FestivePalette.candyTop;
    final bottom = gold ? FestivePalette.gold : FestivePalette.candyBottom;
    final deep = gold ? FestivePalette.goldDeep : FestivePalette.candyLip;
    final bandHeight = size.height - drop;
    final band = Rect.fromLTWH(tail * 0.55, 0, size.width - tail * 1.1, bandHeight);

    Path tailPath(double sign, double edge) {
      final inner = edge + sign * (tail + 3);
      return Path()
        ..moveTo(edge, drop)
        ..lineTo(inner, drop)
        ..lineTo(inner, size.height)
        ..lineTo(edge, size.height)
        ..lineTo(edge + sign * tail * 0.5, (size.height + drop) / 2)
        ..close();
    }

    final tailPaint = Paint()..color = Color.lerp(bottom, deep, 0.55)!;
    canvas
      ..drawPath(tailPath(1, 0), tailPaint)
      ..drawPath(tailPath(-1, size.width), tailPaint);

    // Lipatan gelap antara badan dan ekor.
    final foldPaint = Paint()..color = Color.lerp(deep, Colors.black, 0.25)!;
    canvas
      ..drawPath(
        Path()
          ..moveTo(band.left, bandHeight)
          ..lineTo(band.left + tail * 0.6, bandHeight)
          ..lineTo(band.left + tail * 0.6, size.height)
          ..close(),
        foldPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(band.right, bandHeight)
          ..lineTo(band.right - tail * 0.6, bandHeight)
          ..lineTo(band.right - tail * 0.6, size.height)
          ..close(),
        foldPaint,
      );

    final corner = Radius.circular(drop * 0.75);
    final body = RRect.fromRectAndRadius(band, corner);
    canvas
      // Bibir bawah tipis supaya badan pita tampak tebal.
      ..drawRRect(body.shift(Offset(0, drop * 0.3)), Paint()..color = deep)
      ..drawRRect(
        body,
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, bottom],
        ).createShader(band),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(band.left + 2, 1.5, band.width - 4, bandHeight * 0.36),
          corner,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.32),
      );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) =>
      oldDelegate.gold != gold || oldDelegate.tail != tail || oldDelegate.drop != drop;
}

/// Nuansa [FestivePanel].
enum FestivePanelTone {
  /// Mengikuti `ColorScheme.surface` host.
  surface,

  /// Krem pesta (terang) atau plum tua (gelap), untuk panel di atas hero.
  cream,
}

/// Panel pesta: radius 20, warna dan teks mengikuti `ColorScheme` host,
/// bayangan pink lembut (terang) atau garis tipis (gelap).
class FestivePanel extends StatelessWidget {
  const FestivePanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.tone = FestivePanelTone.surface,
  });

  final Widget child;
  final String? title;

  /// Aksi kecil di kanan judul (mis. tautan "Lihat semua").
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final FestivePanelTone tone;

  /// Radius panel pesta.
  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final Color background;
    final Color foreground;
    switch (tone) {
      case FestivePanelTone.surface:
        background = FestivePalette.panelColor(scheme);
        foreground = scheme.onSurface;
      case FestivePanelTone.cream:
        background = dark ? const Color(0xFF2B1622) : FestivePalette.festCream;
        foreground = dark ? const Color(0xFFFBE9EF) : const Color(0xFF3A1A26);
    }
    final title = this.title;
    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w700,
      color: foreground,
    );
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: dark ? Border.all(color: FestivePalette.lineColor(scheme)) : null,
          boxShadow: dark ? null : FestivePalette.panelShadow,
        ),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: title == null
                  ? child
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Wrap: aksi turun ke baris sendiri bila judul panjang
                        // atau huruf diperbesar.
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: <Widget>[
                            Semantics(header: true, child: Text(title, style: titleStyle)),
                            ?trailing,
                          ],
                        ),
                        const SizedBox(height: 12),
                        child,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol di bilah atas [GameScaffold] (suara, "Aturan"). Warnanya mengikuti
/// bilah: putih di atas hero, `onSurface` setelah bilah memadat.
class GameBarAction extends StatelessWidget {
  const GameBarAction({super.key, required this.icon, required this.tooltip, required this.onPressed}) : label = null;

  /// Tombol berteks pendek, mis. "Aturan".
  const GameBarAction.text({super.key, required String this.label, required this.onPressed, String? tooltip})
      : icon = null,
        tooltip = tooltip ?? label;

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.white;
    final label = this.label;
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return Pressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      tooltip: label == null ? tooltip : null,
      focusRadius: const BorderRadius.all(Radius.circular(24)),
      child: label == null
          ? SizedBox.square(dimension: 40, child: Icon(icon, size: 24, color: color))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                label,
                maxLines: 1,
                style: base.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: color),
              ),
            ),
    );
  }
}

/// Kerangka halaman game.
///
/// - Hero pesta ([backdrop], bawaan [FestiveHero]) terbentang di belakang
///   status bar; [hero] adalah isi di atasnya (judul, chip, Bipy).
/// - Bilah atas transparan (kembali, [title], [actions]) yang memadat menjadi
///   `surface` setelah hero tergulir lewat. Isi hero tidak pernah lewat di
///   bawah bilah: saat digulir, isi itu memudar dalam
///   [GameScaffold.heroFadeExtent] dp di bawah garis bilah lalu terpotong di
///   garis itu. Judul bilah baru muncul setelah [heroTitleExtent] dp teratas
///   isi hero (judul hero) tergulir lewat.
/// - Isi berupa [slivers] di atas panel `surface` beradius atas 24 yang
///   menumpuk [panelOverlap] di atas hero.
/// - [bottomBar] opsional menempel di bawah dengan garis dan area aman.
class GameScaffold extends StatefulWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.hero,
    required this.slivers,
    this.actions = const <Widget>[],
    this.onBack,
    this.showBack = true,
    this.backdrop,
    this.bottomBar,
    this.scrollController,
    this.panelOverlap = 24,
    this.heroPadding = const EdgeInsets.fromLTRB(16, 4, 16, 20),
    this.heroTitleExtent = 96,
  });

  final String title;
  final Widget hero;
  final List<Widget> slivers;
  final List<Widget> actions;

  /// Bawaan: `Navigator.maybePop`.
  final VoidCallback? onBack;
  final bool showBack;

  /// Latar hero pengganti (mis. gradasi radial roda). Harus mengisi induk.
  final Widget? backdrop;
  final Widget? bottomBar;

  /// Untuk paralaks: dengarkan `offset`-nya dari modul.
  final ScrollController? scrollController;
  final double panelOverlap;
  final EdgeInsets heroPadding;

  /// Jarak dari atas isi [hero] sampai bawah judul hero (dp). Judul bilah
  /// mulai muncul setelah bagian ini habis tergulir di bawah bilah.
  final double heroTitleExtent;

  /// Tinggi bilah atas (tanpa status bar).
  static const double barHeight = 56;

  /// Lebar pudar isi hero tepat di bawah garis bilah (dp).
  static const double heroFadeExtent = 24;

  /// Batas skala teks judul dan aksi teks bilah, sama dengan `AppBar`.
  static const double barMaxTextScale = 1.34;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  final ValueNotifier<double> _solid = ValueNotifier<double>(0);
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  final ValueNotifier<double> _titleReveal = ValueNotifier<double>(0);
  final GlobalKey _heroKey = GlobalKey();
  ScrollController? _ownController;

  ScrollController get _controller => widget.scrollController ?? (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GameScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      (oldWidget.scrollController ?? _ownController)?.removeListener(_onScroll);
      _controller.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final controller = _controller;
    if (!controller.hasClients) return;
    final heroBox = _heroKey.currentContext?.findRenderObject();
    final heroHeight = heroBox is RenderBox && heroBox.hasSize ? heroBox.size.height : 240.0;
    final top = MediaQuery.paddingOf(context).top + GameScaffold.barHeight;
    final end = math.max(1.0, heroHeight - widget.panelOverlap - top);
    final start = math.max(0.0, end - 48);
    final offset = controller.offset;
    _offset.value = offset;
    _solid.value = ((offset - start) / (end - start)).clamp(0.0, 1.0);
    final titleGone = widget.heroPadding.top + widget.heroTitleExtent;
    final reveal = ((offset - titleGone) / GameScaffold.heroFadeExtent).clamp(0.0, 1.0);
    _titleReveal.value = math.max(reveal, _solid.value);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _ownController?.dispose();
    _solid.dispose();
    _offset.dispose();
    _titleReveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomBar = widget.bottomBar;

    final heroSliver = SliverToBoxAdapter(
      child: Stack(
        key: _heroKey,
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: widget.backdrop ?? const FestiveHero()),
          ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, offset, child) => _HeroUnderBar(
              line: topInset + GameScaffold.barHeight + offset,
              child: child!,
            ),
            child: Padding(
              padding: widget.heroPadding.add(
                EdgeInsets.only(top: topInset + GameScaffold.barHeight, bottom: widget.panelOverlap),
              ),
              child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: widget.hero),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: widget.panelOverlap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x246B1439), blurRadius: 16, offset: Offset(0, -6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scheme.surface,
        bottomNavigationBar: bottomBar == null
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: FestivePalette.lineColor(scheme))),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: bottomBar),
                ),
              ),
        body: Stack(
          children: <Widget>[
            // Menutup celah saat gulir memantul di atas hero.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 220,
              child: ColoredBox(color: FestivePalette.festTop),
            ),
            CustomScrollView(
              controller: _controller,
              slivers: <Widget>[
                heroSliver,
                ...widget.slivers,
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomBar == null ? MediaQuery.paddingOf(context).bottom + 24 : 24),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_solid, _titleReveal]),
                builder: (context, _) => _GameBar(
                  title: widget.title,
                  solid: _solid.value,
                  titleOpacity: _titleReveal.value,
                  topInset: topInset,
                  showBack: widget.showBack,
                  onBack: widget.onBack ?? () => Navigator.maybePop(context),
                  actions: widget.actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBar extends StatelessWidget {
  const _GameBar({
    required this.title,
    required this.solid,
    required this.titleOpacity,
    required this.topInset,
    required this.showBack,
    required this.onBack,
    required this.actions,
  });

  final String title;
  final double solid;
  final double titleOpacity;
  final double topInset;
  final bool showBack;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = Color.lerp(Colors.white, scheme.onSurface, solid)!;
    final base = theme.textTheme.titleMedium ?? const TextStyle();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: solid),
        border: Border(
          bottom: BorderSide(color: FestivePalette.lineColor(scheme).withValues(alpha: solid)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: GameScaffold.barHeight,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: GameScaffold.barMaxTextScale,
            child: IconTheme(
            data: IconThemeData(color: foreground, size: 24),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 4),
                if (showBack)
                  Pressable(
                    onTap: onBack,
                    semanticLabel: 'Kembali',
                    tooltip: 'Kembali',
                    focusRadius: const BorderRadius.all(Radius.circular(24)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22 * (1 - solid)),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(Icons.arrow_back_rounded, color: foreground),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Opacity(
                      opacity: titleOpacity,
                      alwaysIncludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: base.copyWith(
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...actions,
                const SizedBox(width: 4),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// Isi hero yang memudar tepat di bawah garis bilah dan terpotong di atasnya
/// (termasuk ketukan), supaya tidak bertabrakan dengan bilah transparan.
class _HeroUnderBar extends StatelessWidget {
  const _HeroUnderBar({required this.line, required this.child});

  /// Garis bawah bilah dalam koordinat hero.
  final double line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _BelowLineClipper(line),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => ui.Gradient.linear(
          Offset(0, line),
          Offset(0, line + GameScaffold.heroFadeExtent),
          const <Color>[Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        ),
        child: child,
      ),
    );
  }
}

class _BelowLineClipper extends CustomClipper<Rect> {
  const _BelowLineClipper(this.line);

  final double line;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, line.clamp(0.0, size.height), size.width, size.height);

  @override
  bool shouldReclip(_BelowLineClipper oldClipper) => oldClipper.line != line;
}
