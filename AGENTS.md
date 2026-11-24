# AGENTS.md · bpedia-roda-sabtu

Berlaku untuk Codex, Antigravity, Claude, dan agen lain. Bahasa kerja: Indonesia (UI), identifier kode bahasa Inggris.

## Baca dulu
1. `../bpedia-kelopak-hub/docs/SPEC-CONTRACT.md` — aturan bisnis & API publik modul (sumber kebenaran).
2. `../bpedia-kelopak-hub/docs/SPEC-UIUX.md` — layar Roda Sabtu (3.7), umpan balik, copy.
3. `PRD.md` di repo ini — detail fitur, kepatuhan toko, uji penerimaan.
4. Aturan kerja lintas repo: `../bpedia-kelopak-hub/AGENTS.md`.

## Aturan repo ini
- API publik (`lib/roda_sabtu.dart`) mengikuti SPEC-CONTRACT bagian 2 persis; tambahan hanya parameter opsional dengan default.
- Warna & gaya teks hanya dari `Theme.of(context)`. Teks UI tanpa glyph `≥ → ✓`.
- Hormati `MediaQuery.disableAnimationsOf(context)`; dispose setiap controller.
- Tanpa TODO/placeholder, tanpa `print`.
- Sebelum selesai: `flutter analyze` → "No issues found!", `flutter test` hijau, `php -l server/spin.php` bersih.
- Ubah aturan lintas fitur di hub, bukan di sini. Perbarui bagian **Riwayat** di `PRD.md` setiap perubahan.
