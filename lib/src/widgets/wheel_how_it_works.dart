import 'package:flutter/material.dart';

import '../kit/festive_palette.dart';
import '../wheel_assets.dart';

/// Satu langkah "Cara kerja".
@immutable
class WheelStep {
  /// Membuat langkah.
  const WheelStep({required this.title, required this.body, required this.art});

  /// Judul pendek.
  final String title;

  /// Penjelasan satu kalimat.
  final String body;

  /// Seni 3D langkah.
  final ImageProvider art;
}

/// Tiga langkah bawaan: Putar, Menang, Produk ikut pesanan berikutnya.
const List<WheelStep> wheelSteps = <WheelStep>[
  WheelStep(
    title: 'Putar tiap Sabtu',
    body: 'Satu putaran gratis tiap Sabtu, mulai 00.00 WIB.',
    art: WheelArt.coin,
  ),
  WheelStep(
    title: 'Menangkan hadiah',
    body: 'Kelopak langsung masuk saldo. 1 Kelopak = Rp100.',
    art: WheelArt.coinStack5,
  ),
  WheelStep(
    title: 'Produk ikut pesanan',
    body:
        'Produk gratis masuk keranjang dan dikirim bersama pesanan '
        'belanja berikutnya.',
    art: WheelArt.gift,
  ),
];

/// Daftar langkah bernomor dengan seni 3D, garis penghubung di kiri.
class WheelHowItWorks extends StatelessWidget {
  /// Membuat daftar langkah [steps].
  const WheelHowItWorks({super.key, this.steps = wheelSteps});

  /// Langkah yang ditampilkan.
  final List<WheelStep> steps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool light = scheme.brightness == Brightness.light;
    return Column(
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          MergeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    child: Column(
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: light
                                ? const Color(0xFFFDE7EC)
                                : const Color(0xFF3B1026),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: ExcludeSemantics(
                              child: Image(
                                image: steps[i].art,
                                width: 32,
                                height: 32,
                              ),
                            ),
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: FestivePalette.lineColor(scheme),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: i < steps.length - 1 ? 16 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${i + 1}. ${steps[i].title}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
