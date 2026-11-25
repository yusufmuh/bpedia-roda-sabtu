# PRD · Roda Sabtu v3 (Bpedia Demo)

**Versi 3.0 · 26 November 2026 · Owner: Muhammad Yusuf (Bpedia)**
Paket Flutter `roda_sabtu`. Dokumen induk: `bpedia-asset-build/v3/KEPUTUSAN-V3.md` (aturan bisnis) dan `SPEC-V3.md` §6.2 (tampilan). Bila berbeda, dokumen induk yang berlaku.

## 1. Tujuan

1. Alasan mingguan membuka app tiap Sabtu, gratis dan tanpa syarat belanja.
2. **Transparan**: peluang, sisa kuota produk, dan ketentuan pengiriman tampil sebelum memutar.
3. **Meriah** (keluhan owner K1, K6): roda 3D mengilap, lampu tepi, Bipy bergerak, perayaan menang, bukan roda datar yang membosankan.

## 2. Aturan bisnis

| Aturan | Ketentuan |
|---|---|
| Biaya | Gratis. Tidak bisa membeli putaran. |
| Jadwal | Sabtu WIB 00.00–23.59, hanya saat promo aktif. |
| Frekuensi | 1 putaran per akun per Sabtu. |
| Penentu hasil | Undian 0..9999 (`resolveSpin`) sebelum animasi; animasi hanya menampilkan hasil. |
| Peluang **(demo)** | Produk gratis 5% (selama kuota ada), 10 Kelopak 5%, 5 Kelopak 15%, 3 Kelopak 30%, 1 Kelopak 45%. Kuota habis: 5% produk pindah ke 1 Kelopak (50%). |
| Kuota **(demo)** | 3 produk per minggu, produk hadiah bergilir (diatur host, `demo_campaign.dart` app). |
| Hadiah produk (K17) | Menjadi hadiah menunggu di keranjang (Rp0) dan dikirim bersama pesanan belanja berikutnya, tanpa ongkir tambahan. |
| Kelopak | Langsung masuk saldo. 1 Kelopak = Rp100, otomatis memotong belanja saat checkout (K16). |
| Tamu | Boleh melihat halaman, roda, peluang, dan hadiah; memutar wajib masuk. |
| Pengingat | "Ingatkan saya" Sabtu 09.00 WIB, hanya Android/iOS (host). |

Tata letak roda: satuan 18 derajat (5%), maks. 54 derajat per irisan, berselang: `[Produk 18][1K 54][3K 54][1K 54][10K 18][5K 54][3K 54][1K 54]`. Total sudut per hadiah = peluangnya.

## 3. Pengalaman

1. **Panggung**: gradasi radial pink ke plum, sinar berputar, kilau, stiker melayang, Bipy (pose semangat/fokus/rayakan) di samping roda.
2. **Roda**: bayangan lantai, pelat dan penyangga, cincin emas dengan 24 lampu (kejar 2 Hz diam, mengikuti putaran saat berputar, berkedip saat menang), cakram beririsan dengan angka, kata "Kelopak", dan seni tumpukan koin/kado, pasak emas, kilap diam, poros wajah Bipy (senyum, berkedip saat menang), penunjuk hati emas yang terpental tiap pasak.
3. **Strip peluang** selalu terlihat + tautan "Peluang & ketentuan".
4. **Aksi** sesuai keadaan: "Putar gratis" (Sabtu), hitung mundur + "Ingatkan saya" (hari lain), kartu "Hasil Sabtu ini" (sudah putar), "Masuk untuk memutar" (tamu), catatan promo tidak aktif.
5. **Putaran** 5,85 dtk: percepat 0,4 → laju penuh 1,2 → melambat 4,0 (`easeOutQuart`) → mengendap 0,25 (lewat 2 derajat). Tombol sibuk; kembali meminta konfirmasi.
6. **Menang**: irisan berdenyut 3 kali, lampu berkedip, ledakan sinar, konfeti dua meriam, air mancur koin (min(nilai x 3, 24)) untuk Kelopak, lalu lembar hasil setelah 900 ms.
7. **Lembar hasil**: produk = "Selamat, kamu menang!", pil "1 produk gratis", foto di podium, Bipy menari, "Lihat keranjang" / "Belanja sekarang". Kelopak = angka naik "+5 Kelopak", "Senilai Rp500", "Mantap".
8. **Panel putih**: Hadiah minggu ini, Peluang & ketentuan, Cara kerja (3 langkah), Riwayat putaranmu, tautan S&K.

## 4. Integrasi

Host mengisi `WheelController` (lihat README): keadaan dari mesin Kelopak, `spin()` dari server/mesin lokal, navigasi keluar, pengingat, suara (`GameCue` → `SoundService`). Hub `kelopak_hub` menyediakan pengendali sungguhan dan rute `/hadiah/roda`.

## 5. Aksesibilitas dan kinerja

- Semantics: roda berlabel "Roda Sabtu" dengan nilai keadaan ("Siap diputar", "Sedang berputar", "Hasil: 5 Kelopak", "Dibuka Sabtu, 28 Nov"); hasil diumumkan; tiap baris peluang satu simpul; kartu dan hitung mundur satu kalimat.
- Skala teks 200% pada lebar 360 tanpa luapan; teks di dalam roda tidak diskalakan (alternatifnya tabel peluang).
- Kurangi gerak dihormati. Animasi berulang berhenti saat tak terlihat. Cakram dirender sekali lalu hanya diputar.

## 6. Penerimaan

| Kriteria | Bukti |
|---|---|
| Aturan v2 tetap (37 tes lama) dan aturan v3 | `test/spin_engine_test.dart`, `schedule_test.dart`, `spin_fallback_test.dart`, `wheel_slices_test.dart` |
| Kontrak widget v2 (23 kasus) di widget baru | `test/prize_wheel_test.dart`, `test/odds_table_test.dart` |
| Roda berhenti di irisan hasil | `prize_wheel_test.dart` grup "roda v3" |
| Alur halaman, tamu, hitung mundur, gagal kirim, tahan kembali | `test/wheel_page_test.dart` |
| Tampilan terang/gelap semua keadaan | `test/shots/`, `docs/shots/` |

## 7. Keputusan terbuka (bisnis)

Nilai peluang, kuota mingguan, daftar produk hadiah, masa berlaku hadiah menunggu, dan minimum belanja pengiriman hadiah masih **(demo)**.
