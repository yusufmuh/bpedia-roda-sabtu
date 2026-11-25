import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import '../support/shot.dart';
import '../support/wheel_harness.dart';

/// Tangkap layar halaman Roda Sabtu di semua keadaan penting, terang dan
/// gelap, ke `build/shots/roda_*.png`.
void main() {
  for (final Brightness brightness in Brightness.values) {
    final String tone = brightness == Brightness.light ? 'terang' : 'gelap';

    testWidgets('sabtu siap putar ($tone)', (WidgetTester tester) async {
      await shot(
        tester,
        wheelPageApp(localWheel(), brightness: brightness),
        name: 'roda_sabtu_siap_$tone',
      );
    });

    testWidgets('halaman panjang ($tone)', (WidgetTester tester) async {
      await shot(
        tester,
        wheelPageApp(localWheel(), brightness: brightness),
        name: 'roda_panjang_$tone',
        size: const Size(390, 2300),
      );
    });

    testWidgets('kamis hitung mundur ($tone)', (WidgetTester tester) async {
      await shot(
        tester,
        wheelPageApp(localWheel(now: thursday), brightness: brightness),
        name: 'roda_hitung_mundur_$tone',
      );
    });

    testWidgets('sudah putar ($tone)', (WidgetTester tester) async {
      await shot(
        tester,
        wheelPageApp(
          localWheel(
            lastSpinDay: saturdayDay,
            history: <WheelSpinRecord>[
              WheelSpinRecord.fromPrize(
                demoSpinConfig.prizeById('kelopak-5')!,
                day: saturdayDay,
              ),
              ...demoHistory,
            ],
          ),
          brightness: brightness,
        ),
        name: 'roda_sudah_putar_$tone',
      );
    });

    testWidgets('tamu ($tone)', (WidgetTester tester) async {
      await shot(
        tester,
        wheelPageApp(localWheel(signedIn: false), brightness: brightness),
        name: 'roda_tamu_$tone',
      );
    });
  }

  testWidgets('kuota habis (terang)', (WidgetTester tester) async {
    await shot(
      tester,
      wheelPageApp(localWheel(quota: 0)),
      name: 'roda_kuota_habis_terang',
    );
  });

  testWidgets('promo mati (gelap)', (WidgetTester tester) async {
    await shot(
      tester,
      wheelPageApp(localWheel(promoActive: false), brightness: Brightness.dark),
      name: 'roda_promo_mati_gelap',
    );
  });

  testWidgets('teks 200% lebar 360', (WidgetTester tester) async {
    await shot(
      tester,
      wheelPageApp(localWheel(now: thursday), textScale: 2),
      name: 'roda_teks_200',
      size: const Size(360, 1600),
    );
  });
}
