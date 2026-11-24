# roda_sabtu

Modul Flutter **Roda Sabtu** untuk Bpedia Preview: satu putaran gratis setiap Sabtu WIB, hadiah produk (sesuai stok) atau Kelopak (1 Kelopak = Rp100). Peluang, sisa kuota, dan ongkir tampil sebelum tombol putar; hasil ditentukan engine, animasi hanya menampilkannya.

Spesifikasi lengkap: [`PRD.md`](PRD.md). Kontrak induk: `../bpedia-kelopak-hub/docs/SPEC-CONTRACT.md`.

## Pasang

```yaml
# pubspec.yaml aplikasi host
dependencies:
  roda_sabtu:
    path: ../bpedia-roda-sabtu
```

Butuh Flutter 3.41+ / Dart 3.11+. Tanpa dependensi pihak ketiga.

## Pakai

```dart
import 'dart:math';

import 'package:roda_sabtu/roda_sabtu.dart';

final Random random = Random.secure();

// 1. Kelayakan & status.
final SpinEligibility eligibility = spinEligibility(
  today: today,               // hari WIB: (utcMillis + 7 jam) ~/ 1 hari
  lastSpinDay: lastSpinDay,
  promoActive: promoActive,
);
final int daysLeft = daysUntilSaturday(today);

// 2. Peluang yang ditampilkan sebelum tombol putar.
final List<SpinOdds> odds = effectiveOdds(demoSpinConfig, productStock: stock);

// 3. Saat "Putar gratis": hasil ditentukan dulu, lalu roda diputar.
final SpinPrize prize = resolveSpin(
  demoSpinConfig,
  productStock: stock,
  roll: random.nextInt(SpinRules.totalWeight),
);
final int landingSeed = random.nextInt(1 << 31);
// simpan prize.id, landingSeed, dan stok sebelum putaran; naikkan spinToken.

// 4. Widget.
SaturdayWheel(
  odds: effectiveOdds(demoSpinConfig, productStock: stockBeforeSpin),
  resultPrizeId: prizeIdThisSaturday,      // null bila belum memutar
  spinToken: spinToken,                    // ubah untuk memulai putaran
  landingSeed: landingSeed,
  skipAnimation: userTappedSkip,           // tombol "Lewati animasi"
  onPegPassed: playTick,                   // maks. 1x per 45 ms
  onSettled: showResultCard,               // tepat sekali per putaran
  idleSemanticsValue: canSpin ? 'Siap diputar' : 'Buka Sabtu, 5 Des',
  centerChild: Image.asset('assets/images/bipy_senyum.webp', fit: BoxFit.cover),
);
OddsTable(
  odds: odds,
  productStock: stock,
  shippingNote: demoSpinConfig.shippingNote,
);
```

## Perilaku penting

- Segmen roda sebanding peluang; hadiah 0% tidak digambar; potongan maksimal 90°.
- `spinToken` berubah + `resultPrizeId` terisi → 5 putaran, `easeOutQuart`, 4,2 detik.
- Kurangi gerakan sistem atau `skipAnimation: true` (juga di tengah putaran) → langsung ke hasil, `onSettled` sekali di frame berikutnya.
- Build pertama dengan hasil → diam di hasil, tanpa animasi dan tanpa `onSettled`.
- Menang produk terakhir (stok jadi 0) → roda tetap menampilkan tata letak sebelum putaran selama hasil itu tampil. Setelah app dibuka ulang, kirim `odds` dengan stok sebelum putaran agar segmen produk tetap ada.
- Pembaca layar mendengar "Roda Sabtu" dengan nilai "Sedang berputar", "Hasil: …", atau `idleSemanticsValue` saat belum ada hasil. Roda tidak tahu kelayakan putaran, jadi host mengisi "Siap diputar" hanya bila putaran tersedia.
- Semua warna dan teks dari `Theme.of(context)`.

## Pengembangan

```bash
flutter pub get
flutter analyze        # No issues found!
flutter test
php -l server/spin.php
```

`server/spin.php` berisi logika demo yang setara dengan engine Dart (`claimSaturdaySpin`, `rodaResolveSpin`, `rodaEffectiveWeights`, `rodaSpinEligibility`). Roll wajib 0..9999: `random_int(0, RODA_TOTAL_WEIGHT - 1)`.

## Struktur

```
lib/roda_sabtu.dart          ekspor publik
lib/src/schedule.dart        hari WIB, Sabtu, kelayakan
lib/src/spin_engine.dart     hadiah, konfigurasi, peluang efektif, undian
lib/src/wheel_geometry.dart  tata letak segmen, titik berhenti, pasak (internal)
lib/src/saturday_wheel.dart  widget roda + painter
lib/src/odds_table.dart      tabel peluang & ketentuan
lib/src/format.dart          format persen, ribuan, rupiah (internal)
server/spin.php              logika server demo
```
