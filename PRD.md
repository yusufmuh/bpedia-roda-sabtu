# PRD 02 · Roda Sabtu / Gacha Roulette (Bpedia Kelopak)

**Versi 1.0 (Final & Resmi) · 24 November 2026 · Owner: Muhammad Yusuf (Bpedia)**  
Dokumen spesifikasi teknis dan aturan bisnis modul Roda Sabtu Bpedia Kelopak.  
Induk acuan: `bpedia-kelopak-hub/PRD.md`.

---

## 1. Tujuan & Nilai bagi Pengguna
Menciptakan momentum kegembiraan mingguan bagi pembeli Bpedia setiap akhir pekan. Pengguna yang membuka aplikasi Bpedia pada hari Sabtu berhak mendapatkan **1 putaran gratis** untuk memenangkan produk gratis atau Kelopak.

---

## 2. Aturan Permainan & Jadwal Promosi

| Parameter | Ketentuan Resmi |
|---|---|
| **Jadwal Buka** | Hari **Sabtu pukul 00.00 – 23.59.59 WIB** (Asia/Jakarta). |
| **Frekuensi** | **1 kali putaran gratis per akun** per Sabtu aktif selama periode promo. |
| **Biaya Putaran** | **100% Gratis**. Tidak ada sistem beli putaran (sesuai kepatuhan Apple & Google). |
| **Hadiah 1: Produk Gratis** | Diberikan jika RNG memicu kemenangan dan stok kuota promo > 0. |
| **Hadiah 2: Kelopak** | Hadiah alternatif (misal: 3 Kelopak = Rp300). |
| **Transparansi Sebelum Putar** | Persentase peluang menang (%) dan sisa kuota produk wajib tampil di layar sebelum tombol putar dapat disentuh. |
| **Ketentuan Ongkir** | Subsidi Ongkir Rp0 selama periode promo (atau syarat ongkir tertera jelas). |

---

## 3. Komponen Visual & Aksesibilitas
1. **Roda Putar (Wheel Dial)**:
   - Dibuat menggunakan `CustomPainter` dengan pembagian sektor proporsional terhadap peluang hadiah.
   - Jarum penunjuk di bagian atas dengan warna Plum `#4B1C2E`.
2. **Animasi & Reduce Motion**:
   - Animasi rotasi halus dengan kurva `Curves.easeOutCubic` selama ~1 detik.
   - Jika pengguna mengaktifkan mode *Reduce Motion* di pengaturan perangkat, durasi animasi otomatis menjadi `Duration.zero` dan langsung menampilkan hasil.
3. **Tombol CTA**:
   - Jika hari Sabtu & belum putar: *"Putar gratis"* (Aktif, Berry `#982149`).
   - Jika sudah memutar hari ini: *"Putaran sudah digunakan"* (Disabled).
   - Jika bukan hari Sabtu: *"Kembali pada Sabtu"* (Disabled).
4. **Hasil Putaran Terakhir**:
   - Menampilkan teks hasil klaim yang tetap tersimpan meskipun dialog/animasi ditutup.
   - Didukung `Semantics(liveRegion: true)` untuk pembaca layar.

---

## 4. Kepatuhan Toko Aplikasi (App Store & Play Store)
- **Apple App Store Review Guidelines §5.3**:
  - Putaran roulette **100% gratis** dan tidak memerlukan pembelian apa pun.
  - S&K mencantumkan penegasan resmi: *"Apple Inc. bukan sponsor dan tidak terlibat dalam kegiatan promosi ini."*
- **Google Play Developer Policy**:
  - Peluang probabilitas dan jumlah kuota stok ditampilkan secara transparan sebelum pengguna berpartisipasi.

---

## 5. Kontrak API Backend
- Endpoint: `POST /v1/spin/commit`
- Header: `Authorization: Bearer <token>`, `Idempotency-Key: <uuid>`
- Respons Sukses (200 OK):
  ```json
  {
    "receiptId": "spn-9821a",
    "prizeType": "kelopak",
    "prizeLabel": "3 Kelopak",
    "awardedKelopak": 3,
    "newBalance": 13,
    "remainingStock": 1
  }
  ```
- Error Bukan Hari Sabtu / Promo Tutup (422 Unprocessable):
  ```json
  {
    "error": "not_eligible",
    "message": "Roda hanya tersedia pada hari Sabtu WIB selama periode promo."
  }
  ```

---

## 6. Pengujian Mutu (Test Scenarios)
1. Hari Sabtu WIB mengaktifkan ketersediaan roda; hari lain menonaktifkannya.
2. Putaran roda menghasilkan penambahan 3 Kelopak atau hak produk sesuai RNG server.
3. Stok produk 0 otomatis mengalihkan peluang 100% ke Kelopak.
4. Akun yang sudah memutar pada Sabtu yang sama ditolak jika mencoba memutar kedua kalinya.
