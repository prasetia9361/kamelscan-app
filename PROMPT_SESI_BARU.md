# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Tugas worktree ini: menyelesaikan Bab 8** (watermark, antrian upload, unggah).

## Cara kerja yang saya harapkan

- **Bahasa Indonesia.** Saya bukan programmer; jelaskan dengan bahasa yang mudah
  dipahami, tanpa istilah teknis yang tidak perlu. Kalau saya bilang "belum
  paham", ulangi dengan perumpamaan, jangan diulang dengan istilah yang sama.
- **Verifikasi, jangan asumsi.** Pola yang paling berharga di proyek ini: tiap
  asumsi berisiko dibuktikan di perangkat/database sungguhan **sebelum** kode
  besar ditulis di atasnya. Berkali-kali cara ini menyelamatkan kami dari
  pekerjaan yang harus dibongkar ulang.
- **Jangan menyimpulkan cacat visual dari satu tangkapan layar.** 15 Agustus
  2026 sebuah perbaikan dinyatakan gagal karena benda di foto tampak miring —
  padahal bendanya memang tergeletak miring. Satu putaran build terbuang.
  Bandingkan dua keadaan pada adegan yang sama, atau tanyakan apa yang saya
  lihat dengan mata sendiri.
- **Laporkan apa adanya.** Kalau gagal, katakan gagal beserta pesannya. Kalau
  belum diuji, katakan belum diuji.
- **Jangan ubah keputusan yang sudah diambil** tanpa memberi tahu saya lebih
  dulu.

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang
  sedang dikerjakan sebelum menulis kode.**
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Seluruh penyimpangan
  beserta alasannya, dan jebakan yang sudah memakan waktu. Bagian J panjang dan
  penting: seluruh riwayat perbaikan kamera ada di sana.
- `supabase/README.md` — skema database, RLS, jebakan Supabase, hasil pengujian.
- `palet_warna_dan_tipografi.md` — palet resmi.
- `dataapp.md` — seluruh kredensial. Ter-gitignore. **Jangan pernah menuliskan
  isinya ke berkas yang masuk git.**

## Lingkungan

| | |
|---|---|
| Flutter | `E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat` (tidak ada di PATH) |
| JDK | `$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'` |
| adb | `C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Perangkat uji | Xiaomi Redmi Note 9, serial `7744ca520408` |

**🔴 Jangan pernah menjalankan `flutter run` polos.** Tanpa
`--dart-define-from-file=env.dev.json` aplikasi berhenti di layar "Konfigurasi
belum lengkap", dan lebih buruk: kernel Dart tanpa kredensial ikut tersimpan di
cache sehingga `flutter build` berikutnya diam-diam memakainya. Pakai
`.\run.ps1`. Bila terlanjur: hapus `.dart_tool/flutter_build` lalu bangun ulang.

**⚠️ Worktree baru tidak punya `env.dev.json`** — berkas itu ter-gitignore.
Salin dari `E:\kamelscan\env.dev.json` sebelum menjalankan apa pun.

**Mode profile** (untuk mengukur kelancaran, `run.ps1` belum punya sakelarnya):

```
$env:JAVA_HOME='E:\Android\Android Studio\jbr'; E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat run --profile --dart-define-from-file=env.dev.json
```

## Supabase

Project `ofggpithmvgnhsshglwx` (wilayah ap-southeast-1):

```powershell
$env:SUPABASE_DB_HOST='aws-0-ap-southeast-1.pooler.supabase.com'
$env:SUPABASE_DB_PORT='5432'
$env:SUPABASE_DB_USER='postgres.ofggpithmvgnhsshglwx'
$env:SUPABASE_DB_PASSWORD='<lihat dataapp.md>'
$env:SUPABASE_DB_NAME='postgres'
cd tool\db_migrate
dart run bin/migrate.dart status
dart run bin/migrate.dart up
dart run bin/sql.dart "select 1"
```

⚠️ Driver Postgres Dart tidak sanggup menerima beberapa perintah berpenghasil
baris sekaligus. Gabungkan dengan `union all`, jangan pisah dengan `;`.

⚠️ `tool/db_migrate` adalah paket Dart terpisah. `flutter analyze` di akar akan
melaporkan ± 30 error dari sana bila dependensinya belum diambil — **itu bukan
masalah pada aplikasi**. Pakai `flutter analyze lib` untuk menilai aplikasinya.

Edge Function: `npx --yes supabase@latest functions deploy <nama> --project-ref
ofggpithmvgnhsshglwx`, dengan `$env:SUPABASE_ACCESS_TOKEN` dari `dataapp.md`.

## Sudah selesai dan TERBUKTI jalan

**Bab 0–4** — arsitektur MVVM, 130 tes lulus, `analyze` bersih.

**Bab 5** — 18 migrasi terpasang. RLS diuji dua tenant lewat JWT asli:
kebocoran nol, kenaikan role ditolak `42501`.

**Bab 6** — registrasi, verifikasi email (Resend), login email + Google,
username unik, packer + batas 5, persetujuan S&K, layar Lengkapi Profil.

**Bab 7** — aturan kuota token & masa langganan teruji. Pemotongan token
terbukti di database: 100 → 99.

**Bab 8.1 & 8.3 — SELESAI dan diuji di perangkat (15–16 Agustus 2026):**

- Layar kamera penuh: pratinjau, bingkai bantu, penghitung durasi, berhenti
  otomatis pada batas tier, tombol Berhenti & senter, mode Input Manual
- Pemindaian berjalan **selama** merekam lewat `startVideoRecording(onAvailable:)`
- Pratinjau **tegak dan proporsional** saat merekam — tiga cacat rotasi/proporsi
  ditemukan dan diperbaiki, seluruh riwayatnya di `DEVIASI_LIBRARY.md` bagian J
- Perekaman beruntun **tanpa tombol**, dengan pengaman resi ganda
- Pratinjau lancar (dulu patah-patah; sebabnya widget dibangun ulang tiap detak)

**Bab 8.9** — izin Android; mikrofon/lokasi ditolak tidak memblokir perekaman.

**Sebagian Bab 8.7** — Edge Function `get-upload-url`, upload R2 terbukti
HTTP 200.

## Keputusan Product Owner yang WAJIB dipatuhi

**1. Aturan berhenti perekaman** (menyimpang dari Bab 8.3.2):
1. Pindai pertama → mulai merekam
2. 5 detik pertama → pemindaian belum bisa menghentikan
3. Setelah 5 detik → pindai resi **yang sama** menghentikan
4. Resi **berbeda** → perekaman lanjut, disertai pesan *"Masih merekam X"*
5. **Tombol Berhenti selalu hidup**; bila ditekan < 5 detik muncul konfirmasi

Alasan: aturan asli dokumen memaksa packer mencari label paket lain untuk
menghentikan rekaman paket terakhir.

**2. Perekaman beruntun tanpa tombol** (menyimpang dari Bab 8.3): panel
"Rekaman selesai" beserta tombolnya dihapus; pemindaian hidup lagi sendiri.
Alasan: 100 paket = 100 ketukan sia-sia.

🔴 **Pengamannya wajib ikut ada.** Label yang dipakai menghentikan rekaman masih
di depan kamera sesudahnya. `_recordedInSession` menolak resi yang sudah selesai
direkam **selama layar rekam terbuka**. Pengecekan ke server tidak menolong —
videonya belum terunggah. Menghapus pengaman ini berarti merekam ulang paket
yang sama berkali-kali dan membakar token pelanggan.

**3. Arsitektur kamera:** `camera` + `google_mlkit_barcode_scanning` satu-satunya
pemilik kamera. `mobile_scanner` tidak dapat berbagi kamera, dan
`startImageStream` melempar error bila perekaman sudah berjalan.

## Tugas worktree ini: Bab 8.5, 8.6, 8.7

### Bab 8.5 — watermark FFmpeg

Mesinnya **sudah ada**: `VideoProcessor.applyWatermark()` di
`lib/core/services/video_processor_mobile.dart`, dan `WatermarkCommand` di
`lib/core/domain/`. Sudah diukur di perangkat sungguhan:

| Kondisi | Rasio proses/durasi |
|---|---|
| Debug, sendirian | 0,64x |
| Debug, beruntun | 1,07x |
| **Profile** | **0,58 – 0,73x** |

Penyusutan berkas **15,9 MB → 1,1 MB (14x)**. Bab 8.6 memperkirakan 50 video
antre = 550 MB mentah vs 100 MB hasil proses; kenyataannya **795 MB vs 55 MB**.

⚠️ Angka itu diambil tanpa antrean, beberapa FFmpeg sempat berjalan bersamaan.
**Bab 8.5 wajib menjalankannya berurutan satu per satu.**

⚠️ Rasio menyesatkan untuk video pendek: 3,8 dtk → 4,6 dtk terbaca "1,20x"
padahal absolutnya 4,6 detik. FFmpeg punya ongkos tetap di awal.

Yang masih harus dikerjakan (pengukuran memakai data bohongan):
- Nama toko sungguhan dari sesi
- **Waktu server**, bukan `DateTime.now()`
- Koordinat GPS bila izinnya ada, "Lokasi tidak tersedia" bila ditolak
- `TenantSettings` sungguhan: posisi watermark, opasitas, logo tier Pro
- Antrean berurutan, penanganan gagal, bisa diulang
- **Hapus berkas mentah** setelah hasil olahannya aman

#### Waktu pada watermark — SUDAH DIPUTUSKAN, jangan dibahas ulang

Bab 8.5 mensyaratkan **waktu server**, sedangkan aplikasi ini offline-first.
Aturan yang diputuskan Product Owner 16 Agustus 2026:

1. **Saat ada sinyal**, aplikasi menanyakan waktu server dan menyimpan dua hal:
   waktu server itu, dan titik acuan dari penghitung yang **tidak dapat diubah
   pengguna** (mis. `Stopwatch` / `elapsedRealtime`).
2. **Waktu yang dipakai watermark** = waktu server terakhir + berapa lama
   berlalu sejak sinkron, dihitung dari penghitung tadi.
   🔴 **Jangan menghitung selisihnya dengan mengurangi jam HP** — orang yang
   mengubah jam HP di tengah sesi bisa menggeser waktu di watermark.
3. **Toleransi ±2 menit.** Bila jam HP dan waktu terkoreksi selisihnya di bawah
   itu, keduanya dianggap sama — hasilnya memang identik. Bila di atas itu, jam
   HP dianggap tidak layak dipercaya, tetapi **perekaman tetap jalan** dengan
   waktu terkoreksi. Packer di gudang tidak boleh berhenti bekerja karena jam
   HP salah.
4. **Belum pernah sinkron sama sekali** (aplikasi baru dipasang lalu langsung
   dibawa ke gudang tanpa sinyal): **tetap boleh merekam**, watermark memakai
   jam HP apa adanya, dan videonya **ditandai "waktu belum terverifikasi"**.
   Alasan: bukti dengan waktu yang mungkin meleset jauh lebih berharga daripada
   tidak ada bukti sama sekali. Server tetap mencatat `created_at` sendiri saat
   video diunggah, jadi kebenarannya masih dapat ditelusuri.

⚠️ **Tanda "waktu belum terverifikasi" butuh tempat tinggal.** Kemungkinan besar
perlu kolom baru di `package_videos` (mis. `time_verified boolean`) — berarti
satu migrasi tambahan — dan ikut ditulis ke metadata berkas lewat
`WatermarkCommand.buildMetadataComment`. **Ini penambahan lingkup kecil;
laporkan ke saya sesuai Bab 0.2 sebelum dikerjakan.**

Sumber waktu server belum ditentukan dan boleh dipilih yang paling sederhana —
`select now()` lewat Supabase sudah cukup. Yang penting **bukan** jam HP.

### Bab 8.6 — antrian upload

⚠️ **Wajib menyimpan berkas HASIL PROSES, bukan mentah** (lihat angka 14x di
atas). Rekaman mentah menumpuk di cache aplikasi dan **saat ini tidak pernah
dihapus** — itu utang yang harus dilunasi di sini.

### Bab 8.7 — unggah ke R2

Sebagian sudah terbukti. Bucket bernama `kamelscan-videos`, **bukan**
`scanproof-videos` seperti tertulis di dokumen.

## Jebakan yang sudah memakan waktu

1. `flutter run` polos meracuni cache kernel — lihat di atas
2. Ekstensi Supabase ada di schema `extensions`, bukan `public`. Pakai
   `gen_random_uuid()`, bukan `uuid_generate_v4()`
3. Redirect URL yang tidak cocok **tidak menghasilkan error** — Supabase
   diam-diam memakai Site URL
4. Auth Hook wajib aktif, kalau tidak semua tabel mengembalikan **nol baris**
   tanpa pesan apa pun
5. Bucket R2 `kamelscan-videos`, bukan `scanproof-videos`
6. `AppColors` adalah `ThemeExtension`, diakses lewat
   `Theme.of(context).extension<AppColors>()!`
7. Periksa API widget/paket sebelum memakainya — beberapa kali ditebak dan salah

**Jebakan pemasangan APK (MIUI):**

8. `adb install` ditolak dengan `INSTALL_FAILED_USER_RESTRICTED: Install
   canceled by user`. Pesannya menyesatkan — sering **tidak ada** yang menekan
   Batal. Dua sebab:
   - **HP tanpa internet.** MIUI memverifikasi ke server Xiaomi dulu. Periksa
     `adb shell ping -c 2 8.8.8.8` sebelum menuduh sakelarnya.
   - **Tidak ada yang menekan "Izinkan"** di layar HP. Claude tidak bisa
     menekannya; minta saya yang memegang HP, atau biarkan saya yang menjalankan
     `.\run.ps1` sendiri — itu lebih cepat.
9. `adb install` mengembalikan **exit code 0 walaupun gagal**. Jangan percaya
   status "selesai", baca keluarannya.
10. **Memasang ulang APK menghapus cache aplikasi**, termasuk seluruh rekaman
    mentah. Jangan mengandalkan berkas di sana bertahan antar-pemasangan.

**Jebakan diagnosis:**

11. **`AppLogger` tidak pernah sampai ke logcat.** Ia memakai `dart:developer`,
    yang hanya muncul di terminal `flutter run`. Untuk jejak yang perlu dibaca
    dari perangkat, pakai `debugPrint` (tembus sebagai `I/flutter`). Buta ini
    pernah membuang satu putaran build penuh.
12. `flutter analyze` di akar melaporkan error dari `tool/db_migrate` yang tidak
    ada hubungannya dengan aplikasi. Pakai `flutter analyze lib`.

**Jebakan yang khusus untuk layar kamera — baca `DEVIASI_LIBRARY.md` bagian J
sebelum menyentuhnya:**

13. **`CameraPreview` sengaja TIDAK dipakai.** Ia mengunci bentuk kotaknya pada
    `previewSize` yang hanya diisi sekali, sehingga gambar melar 2,25x saat
    merekam. Layar memakai `controller.buildPreview()` dengan kotak dihitung
    sendiri, dan **putaran bawaan `CameraPreview` direplikasi manual** di
    `_preAppliedQuarterTurns` — jangan dihapus.
14. **`_preview` dan `_transitionCover` dibuat sekali di `State`, bukan di
    dalam `build`.** Mengembalikannya ke dalam `build` membuat pratinjau
    patah-patah, dan gejalanya akan tampak seperti masalah kamera — bukan
    masalah widget.
15. **Jangan menghapus penutup peralihan** (`previewSettling`) dan jangan
    menggantinya dengan tebakan jeda. Yang disembunyikan adalah
    ketidaksinkronan CameraX yang tidak dapat diamati dari sisi Flutter.

## Beban perangkat — sudah diselidiki, jangan diulang

Pratinjau pernah patah-patah. Tiga dugaan **semuanya salah** dan sudah dibuktikan
salah lewat pengukuran; jangan diselidiki ulang:

1. Build debug — profile pun masih patah-patah
2. ML Kit membaca tiap frame — sudah dijarangkan ke ± 8/detik
   (`AppConstants.scanFrameInterval`), tetap patah-patah
3. FFmpeg berebut CPU — pengukur dicabut seluruhnya, tetap patah-patah

Penyebab sebenarnya: widget dibangun ulang tiap detak pencatat waktu (jebakan
14). Sudah diperbaiki dan terbukti halus.

## Penyangga jadwal

Bab 0.2 mewajibkan tiap penambahan lingkup disertai pengurangan setara atau
geser tanggal. Penyangga **minus ± 5 jam**. Beri tahu saya setiap kali ada
tambahan baru; jangan diam-diam menyerapnya.

Satu utang teknis tercatat dan **sengaja ditunda**: menambal
`camera_android_camerax` (akar kedipan peralihan). Alasannya di
`DEVIASI_LIBRARY.md` bagian J — berkas video tidak terpengaruh, dan memelihara
fork paket resmi Flutter terlalu mahal untuk saat ini.

## Mulai dari mana

1. Salin `env.dev.json` ke worktree ini
2. Baca `DEVIASI_LIBRARY.md` — terutama bagian J dan E
3. Baca Bab 8.5–8.7 di `panduan_dokumentasi.md`
4. **Tanyakan dulu soal waktu server saat offline** sebelum menulis kode Bab 8.5
