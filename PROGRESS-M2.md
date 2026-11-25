# PROGRESS-M2 · Roda Sabtu v3

Agen: M2. Repo: `bpedia-roda-sabtu` (paket `roda_sabtu`). Mulai 26 Nov 2026 (sesi sebelumnya terhenti sebelum menulis berkas apa pun).

## Tonggak

- [x] T0 Baca RENCANA, BRIEF §2 §5, SPEC §2.4 §6 §6.2 §7 §8 §10 §11, ARSITEKTUR §0 §1.2 §1.5, KEPUTUSAN, README kit, PROGRESS-R, rujukan owner (Figma P, flyer roulette H, REF-ECOM-A/B roda dan pop-up menang)
- [x] T1 Dasar: `pubspec.yaml` 3.0.0 + aset, `wheel_assets.dart`, `wheel_view.dart` (ViewState, Controller), `local_wheel_controller.dart`, `wheel_spin_curve.dart` + tes unit
- [x] T2 `PrizeWheel` (7 lapisan, lampu, penunjuk berengsel, kurva 5,6 dtk, mengendap) menggantikan `SaturdayWheel`; `OddsTable` + `OddsStrip`; 23 kasus widget v2 dibawa
- [x] T3 Widget pendukung (hitung mundur, kartu hadiah, cara kerja, riwayat, pose hidup) + `WheelPage` (hero panggung, aksi per keadaan, perayaan, lembar hasil, tamu, kurangi gerak, tahan kembali) + tes halaman
- [x] T4 Tangkap layar terang + gelap semua keadaan + strip putaran/perayaan; putaran lihat-perbaiki 1
- [x] T5 Putaran lihat-perbaiki 2 (banding Figma owner + flyer roulette), pilih PNG ke `docs/shots/`
- [x] T6 `example/` (app + panel uji: hari, status, tema, kuota, paksa hasil)
- [x] T7 Dokumen: README, PRD v3, CHANGELOG 3.0.0
- [x] T8 `flutter analyze` 0 isu, `flutter test --concurrency=3` penuh, commit lokal

## Status sesi 26 Nov

- T1, T2 selesai (34 tes roda + tabel lolos). T3 kode halaman selesai, tangkap layar putaran 1 dilihat (perbaikan: teks hero tanpa Material, bayangan cakram menutupi irisan, seni irisan terlalu besar, lembar hasil AspectRatio, seni Kelopak terlalu lebar, pose dipra-muat). T3 selesai: tes halaman (36) dan widget pendukung (20) lolos; tes penuh 262 lolos, analyze 0 isu.

- T4/T5: 19 tangkapan layar + 2 strip dilihat; putaran 2: saldo naik setelah roda berhenti (bukan setelah lembar ditutup), penyangga diganti pelat 3D, judul hero dibatasi 1,6x. Dibanding Figma owner (roda, wajah Bipy di pusat, penunjuk hati, tombol besar) dan flyer roulette (lampu tepi, podium, Bipy di lembar hasil). 10 JPG di `docs/shots/`.
- T6: `example/` (panel uji hari/masuk/promo/kuota/paksa hasil/tema/kurangi gerak), 3 tes lolos, analyze bersih.

- T7/T8: README, PRD v3, CHANGELOG 3.0.0 ditulis. `flutter analyze` 0 isu (akar dan example), `flutter test --concurrency=3` 262 lolos, example 3 lolos. Commit lokal dibuat (tanpa push).

## Catatan untuk agen lain

- Kit tidak diubah dan tidak perlu perbaikan untuk modul ini. Catatan kecil: `GameBarAction` dan `showModalBottomSheet` di tes butuh dua `pump` sebelum lembar terlihat (bukan galat kit).
- Hub (H2) mengisi `WheelController`: `state` dari `KelopakEngine` (kuota, putaran terakhir, riwayat, produk hadiah dari `KelopakHost.productOf`), `spin()` dari backend, `now()` dari `WibClock` supaya geseran hari Mode Demo terpakai.

## Keputusan

- Nama publik: `WheelPage`, `WheelController` (abstrak), `WheelViewState`, `LocalWheelController`, `WheelPrizeProduct`, `WheelSpinResult`, `WheelSpinRecord`, `PrizeWheel`, `OddsTable`, `OddsStrip`.
- `SaturdayWheel` v2 dihapus; kontrak `spinToken`/`resultPrizeId`/`landingSeed`/`onSettled`/`onPegPassed`/`skipAnimation`/`idleSemanticsValue`/`centerChild` dibawa ke `PrizeWheel`.
- Kit tidak diubah. JANGAN `dart format lib` (memformat ulang kit); format hanya berkas milik M2.

## Cara melanjutkan

1. `git status`, `git log --oneline`, daftar tonggak di atas.
2. Iterasi: `flutter test --concurrency=3 test/<berkas>`; tangkap layar: `flutter test --concurrency=3 test/shots`; lihat PNG di `build/shots/`.
3. Tes penuh hanya di tonggak.
