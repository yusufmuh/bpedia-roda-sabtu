# PROGRESS-FIX-M2 (Roda Sabtu)

Lingkup: repo ini kecuali `lib/src/kit` dan `test/support/shot.dart`.

- [x] P3-02 Irisan berselang pink/krem menurut indeks, angka tegak (juga setelah berhenti di hasil mana pun)
- [x] P3-03 Chip peluang dibungkus (Wrap rata tengah), pil putih "Ketentuan"
- [x] P3-13 Tombol putar emas + ikon play + caption tanggal, bilah lekat plum
- [x] P3-14 Lembar menang produk: harga coret + Rp0 (label di bawah foto), catatan "Tanpa ongkir tambahan", ikon keranjang
- [x] R1-05 Runner web+android di example/, README: `cd example && flutter run -d chrome`
- [x] R1-14 `repository:` di pubspec, contoh dependensi git ref v3.0.0 di README, README menyebut lisensi belum ditetapkan (LICENSE dilewati: urusan rilis/owner)
- [x] BACKLOG: docs/shots 1,2 MB (< 3 MB), README menyebut reminderSupported=false untuk host web
- [x] Analyze bersih (akar dan example), tes 267 + example 3 lolos, commit lokal

## Catatan

- Tes baru: warna tinta irisan per indeks, angka tegak, strip tanpa gulir di 390 dp, tombol emas + tanggal, harga coret/Rp0/ongkir/keranjang, `spinDayLabel`.
- Putaran lihat-perbaiki: (1) setelah implementasi dibanding `roda`, `roda_hasil` terang/gelap dan `roda` tinggi penuh; label tegak terbukti saat roda berhenti di hasil 5 Kelopak. (2) irisan sempit (Produk, 10) diperbesar.
- Bilah lekat plum dilukis melewati padding bilah bawaan `GameScaffold` (Stack Clip.none) karena kit belum punya parameter warna bilah.
- Chip hijau bertruk dan baris harga di bawah nama produk butuh slot widget di `ResultSheet` kit; sementara memakai `note` (pil netral) dan label harga di bawah foto.
- Perubahan kit di working copy (hasil sync_kit) tidak di-commit agen ini.
