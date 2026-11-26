import 'package:flutter/material.dart';

import 'format.dart';
import 'kit/festive_palette.dart';
import 'spin_engine.dart';
import 'wheel_assets.dart';

/// Catatan keadilan di bawah tabel peluang.
const String oddsFairnessNote =
    'Hasil ditentukan sistem secara acak sesuai peluang di atas.';

String _detailOf(SpinPrize prize, int productStock) {
  if (prize.kind == PrizeKind.product) {
    return productStock > 0
        ? 'Sisa kuota: ${groupThousands(productStock)}'
        : 'Kuota habis';
  }
  return 'Setara ${formatRupiah(prize.kelopak * rupiahPerKelopak)}';
}

/// Tabel peluang lengkap, sisa kuota produk, dan aturan pengiriman hadiah;
/// tampil sebelum tombol putar. Pembaca layar mendapat judul sebagai heading
/// tersendiri, tiap baris sebagai satu butir, dan catatan sebagai butir
/// sendiri, jadi tidak ada yang tergabung ke heading halaman di sekitarnya.
class OddsTable extends StatelessWidget {
  /// Membuat tabel dari peluang efektif [odds].
  const OddsTable({
    super.key,
    required this.odds,
    required this.productStock,
    required this.shippingNote,
    this.showTitle = true,
  });

  /// Peluang efektif (urutan kampanye).
  final List<SpinOdds> odds;

  /// Sisa kuota produk gratis.
  final int productStock;

  /// Ketentuan pengiriman hadiah produk.
  final String shippingNote;

  /// Menampilkan judul "Peluang & ketentuan".
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showTitle) ...<Widget>[
          Semantics(
            container: true,
            header: true,
            child: Text(
              'Peluang & ketentuan',
              style: text.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: FestivePalette.lineColor(scheme)),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < odds.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: FestivePalette.lineColor(scheme),
                  ),
                _OddsRow(entry: odds[i], productStock: productStock),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        MergeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.brightness == Brightness.light
                  ? const Color(0xFFFFF4DB)
                  : const Color(0xFF3A2C0A),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ExcludeSemantics(
                    child: Image(image: WheelArt.gift, width: 36, height: 36),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Pengiriman hadiah produk',
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.brightness == Brightness.light
                                ? const Color(0xFF8A5A00)
                                : const Color(0xFFFFD98A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shippingNote,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          child: Text(
            oddsFairnessNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _OddsRow extends StatelessWidget {
  const _OddsRow({required this.entry, required this.productStock});

  final SpinOdds entry;
  final int productStock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SpinPrize prize = entry.prize;
    final bool isProduct = prize.kind == PrizeKind.product;
    final bool soldOut = isProduct && productStock <= 0;
    final bool light = scheme.brightness == Brightness.light;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Opacity(
                opacity: soldOut ? 0.45 : 1,
                child: SizedBox.square(
                  dimension: 40,
                  child: Image(
                    image: WheelArt.forPrize(prize),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    prize.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detailOf(prize, productStock),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: soldOut ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isProduct && !soldOut
                    ? (light
                          ? const Color(0xFFFDE7EC)
                          : const Color(0xFF3B1026))
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  entry.percentText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isProduct && !soldOut
                        ? (light
                              ? const Color(0xFFB3164B)
                              : const Color(0xFFF9A2C1))
                        : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strip peluang di hero (selalu terlihat sebelum memutar): chip kaca per
/// hadiah dibungkus rata tengah tanpa gulir, lalu pil "Ketentuan".
class OddsStrip extends StatelessWidget {
  /// Membuat strip dari peluang efektif [odds].
  const OddsStrip({
    super.key,
    required this.odds,
    required this.productStock,
    this.onOpenDetails,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Peluang efektif (urutan kampanye).
  final List<SpinOdds> odds;

  /// Sisa kuota produk gratis.
  final int productStock;

  /// Membuka lembar tabel lengkap. `null` menyembunyikan tautan.
  final VoidCallback? onOpenDetails;

  /// Jarak tepi strip.
  final EdgeInsets padding;

  /// Label chip [entry], mis. "Produk gratis 5% · sisa 3".
  static String chipLabel(SpinOdds entry, int productStock) {
    final SpinPrize prize = entry.prize;
    if (prize.kind != PrizeKind.product) {
      return '${prize.label} ${entry.percentText}';
    }
    final String quota = productStock > 0
        ? 'sisa ${groupThousands(productStock)}'
        : 'kuota habis';
    return '${prize.label} ${entry.percentText} · $quota';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        );
    final VoidCallback? open = onOpenDetails;
    return Padding(
      padding: padding,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final SpinOdds entry in odds)
            _OddsChip(
              label: chipLabel(entry, productStock),
              prize: entry.prize,
              style: style,
              highlight:
                  entry.prize.kind == PrizeKind.product && productStock > 0,
            ),
          if (open != null) _TermsPill(onTap: open, style: style),
        ],
      ),
    );
  }
}

/// Pil putih "Ketentuan >" yang membuka lembar Peluang & ketentuan. Area
/// sentuh 48 dp walau pilnya ramping.
class _TermsPill extends StatelessWidget {
  const _TermsPill({required this.onTap, required this.style});

  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Peluang & ketentuan',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(999)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Ketentuan',
                        style: style.copyWith(
                          color: FestivePalette.festDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: FestivePalette.festDeep,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OddsChip extends StatelessWidget {
  const _OddsChip({
    required this.label,
    required this.prize,
    required this.style,
    required this.highlight,
  });

  final String label;
  final SpinPrize prize;
  final TextStyle style;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: highlight ? FestivePalette.goldSheen : null,
          color: highlight ? null : Colors.white.withValues(alpha: 0.16),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: highlight
                ? FestivePalette.goldDeep
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image(image: WheelArt.forPrize(prize), width: 24, height: 24),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: highlight
                      ? style.copyWith(color: FestivePalette.onGold)
                      : style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
