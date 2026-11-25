import 'package:flutter/material.dart';

import '../format.dart';
import '../kit/festive_palette.dart';
import '../kit/game_scaffold.dart';
import '../wheel_assets.dart';
import '../wheel_view.dart';

/// Kartu "Hadiah minggu ini": foto produk hadiah, nama, harga coret
/// dengan label Gratis, sisa kuota, dan ketentuan pengiriman.
///
/// Tanpa [product] kartu menampilkan kado umum.
class WheelPrizeCard extends StatelessWidget {
  /// Membuat kartu hadiah.
  const WheelPrizeCard({
    super.key,
    required this.product,
    required this.quotaLeft,
    required this.shippingNote,
    this.onOpenProduct,
  });

  /// Produk hadiah minggu ini.
  final WheelPrizeProduct? product;

  /// Sisa kuota produk.
  final int quotaLeft;

  /// Ketentuan pengiriman hadiah produk.
  final String shippingNote;

  /// Membuka detail produk.
  final VoidCallback? onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool light = scheme.brightness == Brightness.light;
    final WheelPrizeProduct? item = product;
    final bool soldOut = quotaLeft <= 0;
    final Color strong = light
        ? const Color(0xFFB3164B)
        : const Color(0xFFF9A2C1);
    final String quotaText = soldOut
        ? 'Kuota habis minggu ini'
        : 'Sisa ${groupThousands(quotaLeft)} minggu ini';
    final Widget photo = ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: ColoredBox(
        color: light ? const Color(0xFFF3F3F5) : const Color(0xFF242126),
        child: SizedBox.square(
          dimension: 92,
          child: item == null
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Image(image: WheelArt.gift),
                )
              : Opacity(
                  opacity: soldOut ? 0.55 : 1,
                  child: Image(
                    image: item.image,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? s) =>
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Image(image: WheelArt.gift),
                            ),
                  ),
                ),
        ),
      ),
    );
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FestiveRibbon(label: 'Hadiah utama'),
        const SizedBox(height: 6),
        Text(
          item?.name ?? 'Produk kecantikan pilihan Bpedia',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Gratis',
              style: theme.textTheme.titleMedium?.copyWith(
                color: strong,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item != null)
              Text(
                formatRupiah(item.price),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: scheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: soldOut
                ? scheme.surfaceContainerHighest
                : (light ? const Color(0xFFFFF4DB) : const Color(0xFF3A2C0A)),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              quotaText,
              style: theme.textTheme.labelMedium?.copyWith(
                color: soldOut
                    ? scheme.onSurfaceVariant
                    : (light
                          ? const Color(0xFF8A5A00)
                          : const Color(0xFFFFD98A)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: FestivePalette.lineColor(scheme)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                photo,
                const SizedBox(width: 12),
                Expanded(child: body),
                if (item != null && onOpenProduct != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shippingNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final VoidCallback? open = item == null ? null : onOpenProduct;
    final String label = item == null
        ? 'Hadiah utama: produk kecantikan pilihan Bpedia. $quotaText. '
              '$shippingNote.'
        : 'Hadiah utama: ${item.name}, gratis, harga normal '
              '${formatRupiah(item.price)}. $quotaText. $shippingNote.';
    return Semantics(
      container: true,
      button: open != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: open,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: card,
        ),
      ),
    );
  }
}
