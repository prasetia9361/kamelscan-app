# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

## Cara kerja yang saya harapkan

- **Bahasa Indonesia.** Saya bukan programmer; jelaskan dengan bahasa yang mudah
  dipahami, tanpa istilah teknis yang tidak perlu.
- **Verifikasi, jangan asumsi.** Pola yang sudah terbukti berharga di proyek ini:
  setiap asumsi berisiko dibuktikan di perangkat/database sungguhan **sebelum**
  kode besar ditulis di atasnya. Tiga kali cara ini menyelamatkan kami dari
  pekerjaan yang harus dibongkar ulang.
- **Laporkan apa adanya.** Kalau gagal, katakan gagal beserta pesannya. Kalau
  belum diuji, katakan belum diuji.
- **Jangan ubah keputusan yang sudah diambil** tanpa memberi tahu saya lebih dulu.

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang
  sedang dikerjakan sebelum menulis kode.**
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Berisi seluruh
  penyimpangan dari dokumen beserta alasannya, dan jebakan yang sudah pernah
  memakan waktu.
- `supabase/README.md` — skema database, RLS, jebakan Supabase, hasil pengujian.
- `palet_warna_dan_tipografi.md` — palet resmi.
- `dataapp.md` — seluruh kredensial (Supabase, R2, Resend, Google, Midtrans).
  Ter-gitignore. **Jangan pernah menuliskan isinya ke berkas yang masuk git.**

## Lingkungan

| | |
|---|---|
| Direktori proyek | `E:\kamelscan` — **bukan** folder di `.claude/worktrees/` |
| Flutter | `E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat` (tidak ada di PATH) |
| JDK | `$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'` |
| adb | `C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Perangkat uji | Xiaomi Redmi Note 9, serial `7744ca520408` |

**🔴 Jangan pernah menjalankan `flutter run` polos.** Tanpa
`--dart-define-from-file=env.dev.json` aplikasi berhenti di layar "Konfigurasi
belum lengkap", dan lebih buruk lagi: kernel Dart tanpa kredensial ikut
tersimpan di cache sehingga `flutter build` berikutnya diam-diam memakainya.
Pakai `.\run.ps1` atau konfigurasi **KamelScan (dev)** di editor.

Bila terlanjur: hapus `.dart_tool/flutter_build` lalu bangun ulang.

## Supabase

Project `ofggpithmvgnhsshglwx` (wilayah ap-southeast-1). Migrasi dijalankan
lewat alat bawaan repo:

```powershell
$env:SUPABASE_DB_HOST='aws-0-ap-southeast-1.pooler.supabase.com'
$env:SUPABASE_DB_PORT='5432'
$env:SUPABASE_DB_USER='postgres.ofggpithmvgnhsshglwx'
$env:SUPABASE_DB_PASSWORD='<lihat dataapp.md>'
$env:SUPABASE_DB_NAME='postgres'
cd tool\db_migrate
dart run bin/migrate.dart status   # lihat status
dart run bin/migrate.dart up       # jalankan yang belum
dart run bin/sql.dart "select 1"   # SQL sekali jalan
```

⚠️ Driver Postgres Dart tidak sanggup menerima beberapa perintah berpenghasil
baris sekaligus. Gabungkan dengan `union all`, jangan pisah dengan `;`.

Edge Function di-deploy dengan `npx --yes supabase@latest functions deploy <nama>
--project-ref ofggpithmvgnhsshglwx`, dengan `$env:SUPABASE_ACCESS_TOKEN` diisi
dari `dataapp.md`.

## Sudah selesai dan TERBUKTI jalan

**Bab 0–4** — arsitektur MVVM, 130 tes lulus, `analyze` bersih, APK terpasang
di perangkat.

**Bab 5** — 18 migrasi terpasang di database sungguhan. RLS diuji dengan dua
tenant lewat JWT asli: kebocoran antar tenant nol, kenaikan role ditolak
`42501`. **Empat kesalahan di SQL Bab 5 sudah diperbaiki** — rinciannya di
`supabase/README.md`.

**Bab 6** — registrasi, verifikasi email (SMTP Resend, domain kamelscan.com),
login email + Google (satu akun dua identitas), username unik, pembuatan
packer + batas 5, persetujuan S&K tercatat berikut versinya, layar Lengkapi
Profil untuk yang masuk lewat Google.

**Bab 7** — aturan kuota token & masa langganan sebagai logika murni teruji.
Pemotongan token terbukti di database: 100 → 99 saat video ditandai terunggah.

**Bab 8 sebagian** — izin Android, `ScanGate` (aturan 3 mode pemicu),
`RecordingMachine` (mesin status), `WatermarkCommand` (perintah FFmpeg),
Edge Function `get-upload-url`, **upload ke R2 terbukti HTTP 200**, layar setup
perekaman.

## Keputusan Product Owner yang WAJIB dipatuhi

**Aturan berhenti perekaman** (menyimpang dari Bab 8.3.2):
1. Pindai pertama → mulai merekam
2. 5 detik pertama → pemindaian belum bisa menghentikan
3. Setelah 5 detik → pindai resi **yang sama** menghentikan
4. Resi **berbeda** → perekaman lanjut, disertai pesan *"Masih merekam X"*
5. **Tombol Berhenti selalu hidup**; bila ditekan < 5 detik muncul konfirmasi

Alasan: aturan asli dokumen memaksa packer mencari label paket lain untuk
menghentikan rekaman paket terakhir.

**Arsitektur kamera:** `camera` + `google_mlkit_barcode_scanning` menjadi
satu-satunya pemilik kamera pada alur perekaman. `mobile_scanner` tidak dapat
berbagi kamera, dan `startImageStream` melempar error bila perekaman sudah
berjalan. Frame diambil lewat `startVideoRecording(onAvailable:)`.

**Sudah diverifikasi di Redmi Note 9:** 107 frame dalam 6 detik saat merekam,
ML Kit memproses frame, berkas video tersimpan. Semua lulus.

## Tugas berikutnya: layar kamera (Bab 8.1 & 8.3)

Seluruh logikanya **sudah ada dan teruji** di `lib/core/domain/`. Layar tinggal
menyambungkan, jangan menulis ulang aturannya:

- `scan_gate.dart` — keputusan tiap pembacaan (`accepted`, `stopRequested`,
  `stopTooEarly`, `otherResiIgnored`, `pendingConfirmation`, `rejected`)
- `recording_machine.dart` — transisi status; transisi tidak sah **ditolak**
- `watermark_command.dart` — perintah FFmpeg
- `ScannerService` sudah mendelegasikan ke `ScanGate`

Yang perlu dibangun:
1. Pratinjau kamera + hamparan bingkai (kotak untuk QR, **mendatar** untuk
   barcode 1D)
2. Frame dari `startVideoRecording(onAvailable:)` → ML Kit → `ScanGate`
3. Penghitung durasi + berhenti otomatis pada batas tier
4. Tombol Berhenti (selalu hidup) + tombol senter (mode barcode)
5. Mode Input Manual: kolom teks, tombol Tempel, cek resi ganda saat berhenti
   mengetik
6. Umpan balik: getar, bip, nomor resi tampil besar. **Pada mode barcode, bip
   hanya setelah konfirmasi pembacaan kedua**
7. Voice-over (Bab 8.4) bila `user_settings.voice_over_enabled`
8. Sesudahnya: FFmpeg watermark → simpan ke antrian lokal

⚠️ **Antrian upload (Bab 8.6) harus menyimpan berkas HASIL PROSES, bukan
mentah.** Rekaman mentah ± 370 KB/detik; 50 video antre saat sinyal mati
berarti 550 MB versus 100 MB.

## Jebakan yang sudah pernah memakan waktu

1. `flutter run` polos meracuni cache kernel — lihat di atas
2. Ekstensi Supabase ada di schema `extensions`, bukan `public`. Pakai
   `gen_random_uuid()`, bukan `uuid_generate_v4()`
3. Redirect URL yang tidak cocok **tidak menghasilkan error** — Supabase
   diam-diam memakai Site URL
4. Auth Hook wajib aktif, kalau tidak semua tabel mengembalikan **nol baris**
   tanpa pesan apa pun
5. Bucket R2 bernama `kamelscan-videos`, **bukan** `scanproof-videos` seperti
   tertulis di Bab 8.7
6. MIUI sering menolak `adb install`; minta saya menyalakan "Instal via USB"
7. `AppColors` adalah `ThemeExtension`, diakses lewat
   `Theme.of(context).extension<AppColors>()!`, bukan konstanta statis
8. Periksa API widget/paket sebelum memakainya — beberapa kali saya menebak
   nama parameter dan salah

## Penyangga jadwal

Bab 0.2 mewajibkan tiap penambahan lingkup disertai pengurangan setara atau
geser tanggal. Penyangga sudah **minus ± 5 jam**. Beri tahu saya setiap kali
ada tambahan baru; jangan diam-diam menyerapnya.

## Mulai dari mana

Baca `DEVIASI_LIBRARY.md` dan `supabase/README.md` dulu, lalu Bab 8 di
`panduan_dokumentasi.md`, baru mulai layar kamera.
