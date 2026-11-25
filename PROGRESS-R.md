# PROGRESS-R · bpedia-roda-sabtu (agen R, aturan murni v3)

Lingkup: `lib/src/*.dart` non-widget, `lib/roda_sabtu.dart`, `server/spin.php`, tes aturan.
Widget lama (`saturday_wheel.dart`, `odds_table.dart`) hanya dibuat tetap terkompilasi; ditulis ulang agen M2.

## Tonggak

- [x] 1. `spin_engine.dart`: `SpinPrize.productCode`, `WheelSliceSpec`, `SpinConfig.fallbackPrizeId`, `SpinConfig.wheelLayout`, `demoSpinConfig` v3
- [x] 2. `wheel_slices.dart`: `WheelSlice`, `buildWheelSlices`, `buildWheelSlicesFromOdds`
- [x] 3. `wheel_geometry.dart` di atas `WheelSlice`
- [x] 4. `format.dart` (+ `weekdayName`, `shortDateLabel`, `countdownLabel`) dan `wheel_opening.dart`
- [x] 5. Tes: fixture `v2SpinConfig`, 37 tes lama, tes baru (irisan, geometri, cadangan, pembukaan, format)
- [x] 6. `server/spin.php` v3 + swa-uji (86 cek, 0 gagal)
- [x] 7. `flutter analyze`, `flutter test` penuh (138 lolos), CHANGELOG 3.0.0, commit lokal

## Keputusan

- Kuota habis + `fallbackPrizeId`: seluruh bobot hadiah produk pindah ke hadiah cadangan sebelum pembulatan; tanpa `fallbackPrizeId` aturan v2 (proporsional, largest remainder) tetap berlaku.
- `fallbackPrizeId` wajib menunjuk hadiah Kelopak di kampanye; `wheelLayout` wajib menyebut hadiah yang ada dengan minimal 1 unit. Pelanggaran = `ArgumentError` dari `effectiveOdds` (kesalahan konfigurasi, bukan keadaan runtime).
- Tata letak eksplisit dipakai hanya bila: jumlah unit tiap hadiah x 500 = bobot efektifnya, tiap irisan 1..3 unit, dan tidak ada dua irisan bersebelahan (melingkar) berhadiah sama. Selain itu susunan otomatis. Akibatnya roda demo v3 dengan kuota habis disusun otomatis (1 Kelopak 50% dalam 4 irisan 45 derajat berselang).
- Susunan otomatis: pecah tiap hadiah menjadi irisan hampir sama besar (maks. 1500 bp), urutkan hadiah menurut jumlah irisan (seri: urutan konfigurasi), isi posisi genap lalu ganjil, putar supaya irisan pertama = hadiah produk pertama (atau hadiah pertama). Irisan sama tidak bersebelahan selama jumlah irisan terbanyak tidak melebihi separuh roda.
- `WheelSlice.weight` (basis poin) adalah nilai bulat acuan; `startDeg`/`sweepDeg` turunannya.
- `WheelGeometry` kini memegang `slices` (bukan `segments`); `WheelSegment` dihapus. `SaturdayWheel` lama disesuaikan seminimal mungkin supaya tetap terkompilasi dan 16 tes widget lamanya lolos.
- `pubspec.yaml` (versi paket) tidak disentuh: milik agen M2.
- `test/support/shot.dart` (milik orkestrator, tidak boleh diubah) memberi 2 info `unnecessary_lambdas` di `flutter analyze`; berkas milik agen R bersih.

## Cara melanjutkan

Semua tonggak selesai. Perintah verifikasi:

```bash
flutter analyze
flutter test --concurrency=3
php -d extension=pdo_sqlite server/spin.php
```
