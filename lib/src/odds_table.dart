import 'package:flutter/material.dart';

import 'format.dart';
import 'spin_engine.dart';

/// Odds, remaining product quota and the shipping rule, shown before the
/// spin button. Screen readers get the title as its own heading, each row as
/// one item and the footnote as its own item, so nothing is merged into the
/// heading of the page around it.
class OddsTable extends StatelessWidget {
  const OddsTable({
    super.key,
    required this.odds,
    required this.productStock,
    required this.shippingNote,
  });

  final List<SpinOdds> odds;
  final int productStock;
  final String shippingNote;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              container: true,
              header: true,
              child: Text(
                'Peluang & ketentuan',
                style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: 4),
            for (final SpinOdds entry in odds)
              _OddsRow(entry: entry, productStock: productStock),
            Divider(height: 16, color: scheme.outlineVariant),
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
              title: 'Pengiriman hadiah produk',
              detail: shippingNote,
            ),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              child: Text(
                'Hasil ditentukan sistem secara acak sesuai peluang di atas.',
                style: textTheme.bodySmall?.copyWith(
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
    final String detail;
    if (isProduct) {
      detail = productStock > 0
          ? 'Sisa kuota: ${groupThousands(productStock)}'
          : 'Kuota habis';
    } else {
      detail = 'Setara ${formatRupiah(prize.kelopak * rupiahPerKelopak)}';
    }
    return _DetailRow(
      icon: isProduct ? Icons.redeem : Icons.local_florist_outlined,
      background: isProduct
          ? scheme.tertiaryContainer
          : scheme.primaryContainer,
      foreground: isProduct ? scheme.onTertiaryContainer : scheme.primary,
      title: prize.label,
      detail: detail,
      trailing: Text(
        entry.percentText,
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.detail,
    this.trailing,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget? end = trailing;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: foreground),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (end != null) ...<Widget>[const SizedBox(width: 12), end],
          ],
        ),
      ),
    );
  }
}
