import 'package:flutter/material.dart';

import '../kit/festive_palette.dart';
import '../spin_engine.dart';
import '../wheel_assets.dart';
import '../wheel_view.dart';
import 'lively_pose.dart';

/// "Riwayat putaranmu": tiap putaran dengan seni hadiah, tanggal, dan
/// hasil. Kosong: Bipy menyemangati.
class WheelHistoryList extends StatelessWidget {
  /// Membuat daftar dari [records] (terbaru dulu).
  const WheelHistoryList({super.key, required this.records, this.limit = 5});

  /// Riwayat putaran.
  final List<WheelSpinRecord> records;

  /// Jumlah baris terbanyak.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    if (records.isEmpty) {
      return MergeSemantics(
        child: Row(
          children: <Widget>[
            const LivelyPose(image: WheelArt.poseCheer, height: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada putaran. Sampai jumpa Sabtu ini, Babes!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final List<WheelSpinRecord> shown = records.take(limit).toList();
    return Column(
      children: <Widget>[
        for (int i = 0; i < shown.length; i++) ...<Widget>[
          if (i > 0)
            Divider(height: 1, color: FestivePalette.lineColor(scheme)),
          _HistoryRow(record: shown[i]),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final WheelSpinRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool light = scheme.brightness == Brightness.light;
    final bool product = record.kind == PrizeKind.product;
    final String result = product ? 'Produk gratis' : '+${record.kelopak}';
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: 40,
                child: Image(
                  image: WheelArt.forReward(record.kind, record.kelopak),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    record.dayLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: product
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: light
                            ? const Color(0xFFFDE7EC)
                            : const Color(0xFF3B1026),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          result,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: light
                                ? const Color(0xFFB3164B)
                                : const Color(0xFFF9A2C1),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      '$result Kelopak',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: light
                            ? const Color(0xFF1E7A55)
                            : const Color(0xFF5FD3A0),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
