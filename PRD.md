# PRD 02 · Roda Sabtu (Bpedia Preview)

**Versi 2.0 · 24 November 2026 · Owner: Muhammad Yusuf (Bpedia)**
Paket Flutter `roda_sabtu` untuk aplikasi **Bpedia Preview** (clean-room, Mode Demo).

Dokumen induk (berlaku bila ada perbedaan):
- `../bpedia-kelopak-hub/docs/SPEC-CONTRACT.md` — aturan bisnis & API publik (bagian 1 dan 2).
- `../bpedia-kelopak-hub/docs/SPEC-UIUX.md` — layar Roda Sabtu (3.7), umpan balik (4), copy (6).
- `../bpedia-kelopak-hub/docs/research/RISET-2026-11-24.md` — audit app lama & versi SDK.

---

## 1. Tujuan

1. Alasan mingguan untuk membuka app setiap Sabtu, **tanpa biaya** dan tanpa syarat belanja.
2. **Transparan**: peluang tiap hadiah, sisa kuota produk, dan ketentuan ongkir terlihat sebelum tombol putar.
3. **Tidak membingungkan**: satu pintu masuk bernama Roda Sabtu, satu tombol "Putar gratis", hasil tertulis jelas dan tetap tampil setelah animasi.

Masalah app lama yang ditutup (audit 24 Nov 2026): roda gacha 2 dari 6 segmen "Produk gratis" tanpa peluang, pintu masuk ganda (tile + pop-up), tanpa jadwal dan S&K.

## 2. Aturan bisnis (wajib persis)

| Aturan | Ketentuan |
|---|---|
| Biaya | Gratis. Tidak ada pembelian putaran, baik dengan uang maupun Kelopak. |
| Jadwal | Sabtu WIB 00.00–23.59 (UTC+7), hanya saat promo aktif. |
| Frekuensi | 1 putaran per akun per Sabtu. |
| Hadiah | Produk (sesuai stok) atau Kelopak. 1 Kelopak = Rp100. |
| Penentu hasil | Engine `resolveSpin` dengan `roll` acak 0..9999. Animasi hanya menampilkan hasil yang sudah ditentukan. |
| Peluang Demo | Produk gratis 10% (stok 1), 3 Kelopak 90%. Stok 0 → produk 0%, 3 Kelopak 100%. |
| Ongkir Demo | "Gratis ongkir (Demo)". |

Konfigurasi Demo: `demoSpinConfig`, versi `demo-2026-11`, hadiah `product` (bobot 1000) dan `kelopak-3` (bobot 9000). Nilai belum disetujui bisnis, jadi ditandai **Demo**.

### Hari WIB

```
wibDay   = (utcMillis + 7*3600*1000) ~/ 86400000      // hari 0 = Kamis 1 Jan 1970
weekday  = ((wibDay + 3) % 7) + 1                     // 1 = Senin .. 7 = Minggu
Sabtu    = weekday == 6
```

Contoh: 27 Nov 2026 = hari 20784 (Jumat), 28 Nov = 20785 (Sabtu), 29 Nov = 20786 (Minggu). Jumat 23.59 WIB masih hari 20784; Sabtu 00.00 WIB sudah hari 20785.

### Kelayakan (`spinEligibility`)

Urutan pemeriksaan: promo tidak aktif → `promoInactive`; bukan Sabtu → `notSaturday`; sudah ada putaran pada hari ini atau sesudahnya (jam mundur) → `alreadySpun`; selain itu `available`.

## 3. Transparansi peluang

- Peluang disimpan dalam **basis poin** (total 10.000). `effectiveOdds` selalu menghasilkan total tepat 10.000.
- Stok produk 0: bobot produk menjadi 0 dan sisanya dibagi ke hadiah Kelopak **sebanding bobotnya** (pembulatan largest remainder, seri ke hadiah yang lebih awal). Contoh 3 hadiah 10/60/30 → 0/66,67/33,33.
- `OddsTable` tampil **di atas tombol putar** dan berisi:
  - judul "Peluang & ketentuan";
  - satu baris per hadiah: label + persen format Indonesia ("10%", "90%", "12,5%");
  - baris produk juga "Sisa kuota: N" atau "Kuota habis" saat stok 0;
  - baris Kelopak juga nilai rupiah ("Setara Rp300");
  - baris "Pengiriman hadiah produk" + ketentuan ongkir;
  - catatan "Hasil ditentukan sistem secara acak sesuai peluang di atas."

## 4. Roda (tampilan)

- Persegi, ukuran mengikuti lebar tersedia, maksimum 320 dp.
- **Segmen sebanding peluang**; hadiah berbobot 0 tidak digambar. Setiap area hadiah dibagi menjadi potongan sama besar **maksimum 90°**.
- Produk: warna `tertiary` + ikon kado + label "Produk" (label disembunyikan bila tidak muat; ikon tetap).
- Kelopak: selang-seling `primaryContainer` / `secondaryContainer`, label hadiah ("3 Kelopak") ditulis radial, diperkecil agar muat (minimal setara ±9 px, lalu dipotong "…").
- Tidak ada dua potongan Kelopak bersebelahan yang berwarna sama, termasuk di sambungan 0°.
- Bingkai `primary` dengan pasak putih (`onPrimary`) di setiap batas potongan.
- Jarum segitiga di jam 12 (`primary`, garis tepi 2 dp `onPrimary`, bayangan lembut).
- Lingkaran tengah (`surface`, tepi 3 dp `primary`) berisi `centerChild` dari host, dipotong lingkaran.
- Saat diam tanpa hasil, potongan pertama berada tepat di bawah jarum (jarum tidak pernah berhenti di pasak).
- Semua warna dan gaya teks dari `Theme.of(context)`.

## 5. Gerak & umpan balik

| Kejadian | Perilaku |
|---|---|
| `spinToken` berubah + `resultPrizeId` terisi | 5 putaran penuh + jarak ke titik hasil, `Curves.easeOutQuart`, 4,2 detik (parameter `duration`). |
| Titik berhenti | Di dalam salah satu potongan hadiah hasil, 15–85% lebar potongan, dipilih deterministik dari `landingSeed`. |
| Pasak melewati jarum | `onPegPassed`, maksimal satu panggilan per 45 ms (host: suara `tick`, getar ringan dibatasi host). |
| Roda berhenti | `onSettled` tepat sekali per putaran. |
| Kurangi gerakan (sistem) atau `skipAnimation` | Langsung ke posisi akhir, `onSettled` sekali di frame berikutnya. Berlaku juga bila diaktifkan di tengah putaran. |
| Build pertama dengan hasil | Diam di posisi hasil, tanpa animasi dan tanpa `onSettled`. |
| Build ulang dengan token sama | Tidak memutar ulang. |
| `spinToken` berubah tanpa hasil | Putaran dibatalkan tanpa `onSettled`, roda kembali ke posisi diam. |
| Produk terakhir dimenangkan (stok jadi 0) | Tata letak sebelum putaran dipertahankan selama hasil itu tampil, sehingga jarum tetap di segmen produk. |
| Widget dibuang saat berputar | Aman: controller dan cache gambar dibuang, tidak ada callback setelah dispose. |

Performa: wajah roda direkam sekali sebagai `Picture` (dibuat ulang hanya bila ukuran, tata letak, atau tema berubah), lalu tiap frame hanya diputar di dalam `RepaintBoundary`.

## 6. Aksesibilitas

- Roda: node Semantics "Roda Sabtu" dengan nilai "Sedang berputar", "Hasil: 3 Kelopak", atau `idleSemanticsValue` dari host saat belum ada hasil. Roda tidak tahu kelayakan putaran, jadi host yang mengisi nilai diam: "Siap diputar" hanya bila putaran memang tersedia, selain itu mis. "Buka Sabtu, 5 Des" atau "Promo sedang tidak aktif". Tanpa nilai dari host, roda tidak menyebut status apa pun.
- `OddsTable`: judul sebagai header; tiap baris dibaca sebagai satu item ("Produk gratis, Sisa kuota: 1, 10%").
- Teks mengikuti skala sistem; layar 360×740 dengan teks 200% tanpa overflow (teruji).
- Status tidak hanya warna: kuota dan hasil selalu berupa teks.
- Tidak memakai glyph `≥ → ✓` (font brand tidak punya).

## 7. Layar Roda Sabtu di hub (ringkasan SPEC-UIUX 3.7)

Status di atas roda (Siap diputar / "Roda buka Sabtu, {tgl} · 00.00 WIB" dengan sisa hari dari `daysUntilSaturday` / Sudah diputar Sabtu ini) → `SaturdayWheel` → `OddsTable` → tombol "Putar gratis" (aktif hanya bila `available`; selama berputar menjadi "Lewati animasi" yang mengatur `skipAnimation: true`) → kartu hasil yang tetap tampil setelah app dibuka ulang → tautan S&K. Suara `spin_start`, `tick`, lalu `claim` / `win_product`.

Urutan di host: `roll` dan `landingSeed` dari `Random.secure()` → `resolveSpin` → catat hasil ke ledger → naikkan `spinToken`. Simpan `landingSeed` dan stok sebelum putaran agar roda bisa ditampilkan ulang persis setelah restart (`effectiveOdds(config, productStock: stokSebelumPutar)`).

## 8. Kepatuhan toko & hukum

Perlu diverifikasi ulang terhadap teks kebijakan terbaru oleh tim legal sebelum rilis produksi.

**Apple App Store Review Guidelines 5.3 (Gaming, Gambling, and Lotteries)**
- 5.3.1: undian/kontes harus disponsori pengembang app → penyelenggara Bpedia, tercantum di S&K.
- 5.3.2: aturan resmi tampil di dalam app dan menegaskan Apple bukan sponsor → S&K memuat "Apple bukan sponsor dan tidak terlibat dalam promosi ini."
- 5.3.3: tidak memakai in-app purchase untuk membeli kredit atau tiket undian → Roda Sabtu gratis, tidak ada pembelian putaran (uang maupun Kelopak).
- Peluang ditampilkan sebelum ikut, sejalan dengan kewajiban pengungkapan peluang untuk item acak (3.1.1), walau roda ini tidak dibeli.

**Google Play**
- Kebijakan *Real-Money Gambling, Games, and Contests*: partisipasi gratis tanpa pembelian; penyelenggara, kelayakan, periode, dan pemenuhan hadiah tertulis di S&K. S&K juga memuat "Google bukan sponsor dan tidak terlibat dalam promosi ini."
- Pengungkapan peluang untuk mekanisme acak (loot box) dipenuhi: peluang dan kuota tampil sebelum tombol putar.

**Indonesia**
- Program undian berhadiah dapat memerlukan izin (mis. izin undian gratis berhadiah dari Kementerian Sosial). **Belum diverifikasi**; wajib dicek tim legal sebelum promo nyata.

S&K minimal: penyelenggara, gratis tanpa pembelian, periode Sabtu WIB, peluang, stok, ongkir, cara klaim produk, dua penegasan sponsor di atas.

## 9. API publik (`package:roda_sabtu/roda_sabtu.dart`)

```dart
bool isSaturdayWib(int wibDay);
int daysUntilSaturday(int wibDay);                    // 0 jika Sabtu
enum PrizeKind { product, kelopak }
abstract final class SpinRules { static const int totalWeight = 10000; }
final class SpinPrize { const SpinPrize({required String id, required PrizeKind kind, required String label, required int kelopak, required int weight}); }
final class SpinConfig { const SpinConfig({required String version, required List<SpinPrize> prizes, required String shippingNote}); SpinPrize? prizeById(String id); }
const SpinConfig demoSpinConfig;                      // 'demo-2026-11'
final class SpinOdds { const SpinOdds({required SpinPrize prize, required int weight}); double get percent; String get percentText; }
List<SpinOdds> effectiveOdds(SpinConfig config, {required int productStock});
SpinPrize resolveSpin(SpinConfig config, {required int productStock, required int roll}); // roll 0..9999 (assert + RangeError)
enum SpinEligibility { available, alreadySpun, notSaturday, promoInactive }
SpinEligibility spinEligibility({required int today, required int? lastSpinDay, required bool promoActive});
class SaturdayWheel extends StatefulWidget ({required List<SpinOdds> odds, required String? resultPrizeId, required int spinToken, required int landingSeed, VoidCallback? onSettled, VoidCallback? onPegPassed, Widget? centerChild, bool skipAnimation = false, Duration duration = const Duration(milliseconds: 4200)});
class OddsTable extends StatelessWidget ({required List<SpinOdds> odds, required int productStock, required String shippingNote});
```

Konfigurasi tidak valid (tanpa hadiah, bobot negatif, ID ganda, tidak ada hadiah Kelopak berbobot saat stok 0) → `ArgumentError`.

## 10. Server demo (`server/spin.php`)

Fungsi PHP 8.2+ yang setara dengan Dart: `rodaDemoConfig()`, `rodaWibDayOf()`, `rodaWeekday()`, `rodaIsSaturdayWib()`, `rodaDaysUntilSaturday()`, `rodaSpinEligibility()`, `rodaEffectiveWeights()`, `rodaResolveSpin()`, dan `claimSaturdaySpin(array &$state, int $day, int $roll, ?array $config = null): array`.

`claimSaturdaySpin` menolak (DomainException) bila promo tidak aktif, bukan Sabtu, atau sudah memutar; mengurangi stok + menambah hak produk, atau menambah saldo Kelopak; lalu mencatat `spinDay`, `spinPrizeId`, `spinResult`. Roll wajib 0..9999: `random_int(0, RODA_TOTAL_WEIGHT - 1)`. Pemanggil membungkusnya dalam satu transaksi.

## 11. Uji penerimaan

| # | Skenario | Bukti |
|---|---|---|
| 1 | Jumat 27 Nov 2026 tutup, Sabtu 28 Nov buka, Minggu 29 Nov tutup; Jumat 23.59 WIB tutup vs Sabtu 00.00 WIB buka; Sabtu 23.59 buka vs Minggu 00.00 tutup | `test/schedule_test.dart` |
| 2 | `daysUntilSaturday` untuk Senin–Minggu = 5, 4, 3, 2, 1, 0, 6 | `test/schedule_test.dart` |
| 3 | `spinEligibility` empat cabang + jam mundur | `test/schedule_test.dart` |
| 4 | `effectiveOdds` total 10.000 untuk stok 0, 1, 5 dan konfigurasi 3 hadiah; stok 0 → produk 0% | `test/spin_engine_test.dart` |
| 5 | `resolveSpin`: roll 0 & 999 → produk (stok > 0); 1000 & 9999 → Kelopak; stok 0 → selalu Kelopak; tepat 1.000 dari 10.000 roll menang produk; roll di luar rentang → assert | `test/spin_engine_test.dart` |
| 6 | Segmen sebanding peluang, tanpa celah, maksimum 90°, warna Kelopak tidak bersebelahan sama | `test/wheel_geometry_test.dart` |
| 7 | Titik berhenti di hadiah hasil (15–85% potongan), 5 putaran penuh, posisi diam di tengah potongan | `test/wheel_geometry_test.dart` |
| 8 | Roda berputar 4,2 detik, `onSettled` tepat sekali, jarak `onPegPassed` min. 45 ms | `test/saturday_wheel_test.dart` |
| 9 | Kurangi gerakan (awal & tengah putaran), `skipAnimation`, token sama tidak memutar ulang, token tanpa hasil membatalkan, dispose aman, menang produk terakhir | `test/saturday_wheel_test.dart` |
| 10 | `OddsTable`: persen, kuota, kuota habis, ongkir, catatan, satu node Semantics per baris | `test/odds_table_test.dart` |
| 11 | 360×740 dengan teks 200%: roda + tabel tanpa overflow | `test/odds_table_test.dart` |
| 12 | `php -l server/spin.php` bersih; aturan PHP sama dengan Dart | perintah di README |

Definisi selesai: `flutter pub get` sukses, `flutter analyze` → "No issues found!", `flutter test` hijau.

## 12. Di luar cakupan

- Konfigurasi kampanye dari server, stok nyata, dan klaim produk fisik.
- Penentuan hadiah di server produksi (versi Demo memakai engine lokal di perangkat).
- Teks S&K final (disiapkan hub/legal).

## Riwayat

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0 | 24 Nov 2026 | PRD awal: `saturdayOpen`, `demoProduct` (roll 0..99), roda statis 1 detik. |
| 2.0 | 24 Nov 2026 | Ditulis ulang mengikuti SPEC-CONTRACT v2 & SPEC-UIUX v2: API baru (`effectiveOdds`, `resolveSpin`, `spinEligibility`, `SaturdayWheel`, `OddsTable`), peluang basis poin, segmen sebanding peluang, animasi 4,2 detik dengan kurangi gerakan & lewati, Semantics, server PHP setara Dart, 78 tes. |
