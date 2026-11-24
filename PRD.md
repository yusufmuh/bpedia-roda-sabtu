# PRD 02 · Roda Sabtu

**Versi 0.1 · 24 November 2026 · Pemilik keputusan bisnis: tim kampanye Bpedia**

## Penawaran dan jadwal
Saat promo aktif, pengguna terautentikasi mendapat tepat satu putaran gratis per Sabtu WIB. Satu periode mingguan adalah Sabtu 00.00 hingga Minggu 00.00 WIB, dengan batas akhir eksklusif. Jatah yang tidak terpakai berakhir saat periode tutup. Pengguna dapat ikut Sabtu berikutnya jika kampanye masih aktif. Beberapa banner untuk periode yang sama memakai jatah akun yang sama. Putaran gratis tidak mensyaratkan pembelian, saldo atau pembayaran tambahan.

## Sebelum, selama, dan setelah putaran
1. Pengguna melihat waktu buka/tutup, daftar hadiah, probabilitas numerik setiap hasil, kuota produk tersedia, serta ketentuan dan biaya ongkir yang berlaku bagi wilayahnya. Bila ongkir tergantung tujuan, pilih tujuan dan lihat estimasi atau batas yang disetujui dahulu.
2. Tombol “Putar gratis” aktif setelah konfigurasi valid dan syarat ditampilkan. Jika versi syarat berubah, tampilkan versi baru dan beri kesempatan membatalkan tanpa memakai jatah.
3. Server memilih hasil, menyimpan receipt dan mencadangkan stok atau mengkreditkan Kelopak secara atomik. Animasi hanya mengungkap hasil yang tercatat. Pengguna dapat mengurangi gerakan dan tetap memperoleh hasil tertulis.
4. Produk menampilkan nomor klaim, tenggat, ongkir, alamat melalui alur aplikasi utama dan status kirim. Kelopak menampilkan jumlah dan saldo. Masuk dari perangkat lain membuka hasil yang sama.

## Contoh untuk pengujian
| Hadiah | Saat produk tersedia | Sesudah kuota contoh habis |
|---|---:|---:|
| Satu produk demo | 10% | 0% |
| 3 Kelopak | 90% | 100% |

Kuota demo satu unit, ongkir demo Rp0. Nilai ini hanya berlaku dalam simulasi. Pada produksi peluang harus berjumlah 100%, memakai versi konfigurasi, anggaran dan periode efektif. Jika unit terakhir diambil pengguna lain antara tampilan dan putaran, kembalikan odds_changed serta konfigurasi baru sebelum menghabiskan jatah. SKU, nilai Kelopak, metode alokasi, dukungan wilayah, subsidi ongkir dan tanggal kampanye merupakan keputusan pemilik promo.

## Batas sistem dan operasional
Gunakan RNG server, satu unique key (akun, Sabtu WIB) dan transaksi stok yang menolak nilai negatif. Outbox mengirim permintaan fulfillment. Kegagalan fulfillment tetap menyimpan hak pengguna. Jika saldo, RNG, atau kuota tak tersedia sebelum commit, kembalikan kegagalan yang dapat dicoba lagi. Operator bisa menjeda putaran baru dan melanjutkan pemenuhan yang sudah terbit. Simpan versi peluang bersama receipt untuk rekonsiliasi.

## Uji penerimaan
- Jumat 23.59, Sabtu 00.00, Sabtu 23.59, dan Minggu 00.00 mengikuti WIB meski perangkat berada di luar Indonesia.
- Sabtu di luar periode promo menampilkan status tutup. Dua putaran serentak dari Android/web untuk akun yang sama menghasilkan satu hadiah.
- Dua akun bersaing atas produk terakhir. Satu reservasi saja dapat berhasil; pengguna dengan syarat usang melihat peluang baru sebelum konfirmasi.
- Timeout setelah hasil ditetapkan, refresh, keluar lalu masuk, serta skip animasi menampilkan satu receipt. Stok nol masih memungkinkan Kelopak dengan peluang terbaru.
- Syarat bisa dibaca dengan pembaca layar sebelum tombol. Teks status tidak bergantung pada warna roda.

## Tinjauan rilis dan pengukuran
Catat eligible_open, terms_shown, spin_committed, prize_claimed dan fulfillment_failed dengan ID transaksi pseudonim. Ukur konversi putar, jumlah produk terkirim, distribusi aktual per versi peluang dan biaya tiap Sabtu. Untuk aktivasi hadiah nyata di aplikasi belanja, Product/Legal meninjau aturan promosi Indonesia dan kebijakan toko sesuai mekanisme final. Di iOS siapkan ketentuan resmi di dalam aplikasi, penyelenggara dan pernyataan bahwa Apple tidak mensponsori promosi. [Apple §5.3](https://developer.apple.com/app-store/review/guidelines/#gaming-gambling-and-lotteries) · [Kebijakan Google Play](https://support.google.com/googleplay/android-developer/answer/9877032)
