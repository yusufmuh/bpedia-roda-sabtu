# Changelog · roda_sabtu

## 3.0.0 · aturan (25 Nov 2026)

Perluasan aturan murni untuk Bpedia Demo v3. Semua parameter baru opsional:
kampanye tanpa `fallbackPrizeId` dan `wheelLayout` berperilaku persis seperti
2.0.0. Tanda tangan `effectiveOdds` dan `resolveSpin` tidak berubah.

### Ditambahkan

- `SpinPrize.productCode` (`String?`): kode produk katalog yang dihadiahkan.
- `SpinConfig.fallbackPrizeId` (`String?`) dan `SpinConfig.fallbackPrize`:
  hadiah Kelopak yang menerima seluruh bobot produk saat kuota produk habis.
  Null = aturan 2.0.0 (dibagi proporsional ke hadiah Kelopak).
- `SpinConfig.wheelLayout` (`List<WheelSliceSpec>?`) dan `WheelSliceSpec`
  (`prizeId`, `units`; 1 unit = 18 derajat = 500 basis poin).
- `SpinRules.wheelUnitWeight` (500) dan `SpinRules.maxSliceWeight` (1500).
- `lib/src/wheel_slices.dart`: `WheelSlice`, `buildWheelSlices(config,
  productQuotaLeft:)`, `buildWheelSlicesFromOdds(odds, layout:)`. Tata letak
  kampanye dipakai apa adanya bila cocok dengan peluang efektif; selain itu
  irisan disusun otomatis dan deterministik (maks. 54 derajat per irisan,
  hadiah yang sama tidak bersebelahan selama bisa dihindari).
- `lib/src/wheel_opening.dart`: `WheelOpening`, `nextSpinSaturday`,
  `wheelOpening`, `nextWheelOpening` (pindahan `SpinOpening` dari hub v2).
- `format.dart`: `weekdayName`, `shortDateLabel`, `countdownLabel`.
- `WheelGeometry.fromConfig` dan `WheelGeometry.sliceUnderPointer`.
- `server/spin.php`: hadiah cadangan, konfigurasi v3, `rodaBuildWheelSlices`,
  `rodaNextSpinSaturday`, `rodaCheckConfig`, dan swa-uji
  (`php server/spin.php`).

### Diubah

- `demoSpinConfig` berisi kampanye contoh v3: produk gratis 5% (selama kuota
  ada), 10 Kelopak 5%, 5 Kelopak 15%, 3 Kelopak 30%, 1 Kelopak 45%; cadangan
  1 Kelopak; tata letak `[produk 1][1K 3][3K 3][1K 3][10K 1][5K 3][3K 3][1K 3]`.
  Versi kampanye `demo-v3-2026-11`; teks pengiriman "Dikirim bersama pesanan
  belanja berikutnya, tanpa ongkir tambahan".
- `WheelGeometry` bekerja di atas `List<WheelSlice>` (`slices`), menggantikan
  `segments`. `landingAngle`, `restRotationFor`, `spinEndRotation`,
  `pegCrossed`, `retainResult`, dan `idleRotation` dipertahankan.
- `effectiveOdds` menolak `fallbackPrizeId` yang bukan hadiah Kelopak
  kampanye dan `wheelLayout` yang menyebut hadiah tak dikenal atau irisan di
  bawah 1 unit (`ArgumentError`).

### Dihapus

- `WheelSegment` dan pembagian potongan lama (maks. 90 derajat, berurutan);
  penggantinya `WheelSlice` dan `buildWheelSlices`.

### Tes

- Nilai kampanye 2.0.0 menjadi fixture `v2SpinConfig`
  (`test/support/v2_fixtures.dart`); 37 tes aturan lama lolos dengan asersi
  yang sama.
- Tes baru: hadiah cadangan, pemecah irisan (termasuk uji sifat acak berbenih
  tetap: 4000 kampanye dan 3000 tata letak), geometri di atas irisan,
  pembukaan roda, format tanggal dan hitung mundur.

## 2.0.0 · 24 Nov 2026

Aturan murni (jadwal, peluang, undian), widget roda bertema, tabel peluang,
PRD v2.
