# Deviasi Daftar Library terhadap Bab 4.2

**Tanggal:** 12 Agustus 2026
**Toolchain terpasang:** Flutter 3.44.8 · Dart 3.12.2 · DevTools 2.57.0

Bab 4.2 menulis *"Versi berikut adalah batas minimum yang sudah terverifikasi
kompatibel. Jangan menaikkan versi mayor di tengah proyek tanpa persetujuan."*

Dokumen ini mencatat setiap penyimpangan berikut alasannya. Semua penyimpangan
terjadi **di awal proyek, bukan di tengah**, dan sebagian besar bersifat
**terpaksa** — versi yang tertulis di Bab 4.2 tidak dapat di-resolve sama sekali
pada Dart 3.12. Mohon ditinjau dan disetujui Product Owner.

---

## A. Penyimpangan terpaksa — versi di Bab 4.2 tidak dapat dipasang

| Library | Bab 4.2 | Dipakai | Sebab |
|---|---|---|---|
| `ffmpeg_kit_flutter_min_gpl` | `^6.0.3` | **`ffmpeg_kit_flutter_new: ^4.6.2`** | Paket aslinya **sudah ditarik dari pub.dev** (proyek FFmpegKit dihentikan pengembang aslinya). `ffmpeg_kit_flutter_new` adalah fork yang masih dipelihara dan tetap menyertakan filter `drawtext` serta `libx264` — syarat watermark teks di Bab 8. |
| `sqlite3_flutter_libs` | `^0.5.23` | **`drift_flutter: ^0.3.1`** | Paket lama kini berstatus EOL, deskripsinya sendiri berbunyi *"Not used anymore"*. `drift_flutter` adalah cara resmi drift menyediakan pustaka native SQLite + lokasi berkas lintas platform. |
| `golden_toolkit` | `^0.15.0` | **dihapus** | Paket *discontinued* dan tidak kompatibel dengan Flutter 3.44. Golden test memakai `matchesGoldenFile` bawaan `flutter_test`. |
| `video_thumbnail` | `^0.5.3` | **dihapus** | Berkas Gradle paket ini menerapkan `kotlin-android` **tanpa** Android Gradle plugin — bentuk yang ditolak AGP versi sekarang, sehingga `flutter build apk` **gagal total** (`Failed to notify project evaluation listener`). Paket sudah lama tidak dipelihara. Thumbnail dibuat FFmpeg lewat `MobileVideoProcessor.generateThumbnail()`; FFmpeg memang sudah wajib ada demi watermark, jadi paket ini mubazir sejak awal. |
| `freezed` | `^2.5.7` | **`^3.2.6-dev.1`** | freezed 2.x mensyaratkan `analyzer` 6.x, sedangkan `build_runner` 2.15 pada Dart 3.12 mewajibkan `analyzer` 12.x. Stabil terakhir (3.2.5) pun belum mendukung analyzer 12, sehingga pra-rilis 3.2.6-dev.1 adalah satu-satunya yang dapat di-resolve. ⚠️ **Naikkan ke 3.2.6 stabil begitu rilis.** |
| `riverpod_generator` | `^2.4.3` | **`^4.0.4`** | Alasan sama dengan freezed: generator 2.x terkunci pada analyzer lama. Menaikkan generator memaksa `flutter_riverpod` dan `riverpod_annotation` ikut naik. |
| `flutter_riverpod` | `^2.5.1` | **`^3.3.2`** | Konsekuensi dari `riverpod_generator` 4.x. |
| `riverpod_annotation` | `^2.3.5` | **`^4.0.3`** | Konsekuensi dari `riverpod_generator` 4.x. |
| `freezed_annotation` | `^2.4.4` | **`^3.1.0`** | Konsekuensi dari `freezed` 3.x. |
| `intl` | `^0.19.0` | **`^0.20.2`** | Versi dipaksa oleh `flutter_localizations` bawaan SDK 3.44. Tidak ada pilihan. |

### Dampak kode dari kenaikan freezed & Riverpod

Ini bukan sekadar angka versi — dua-duanya mengubah bentuk kode yang ditulis
di Bab 3.4. Pola yang dipakai di repo ini:

```dart
// Bab 3.4 (freezed 2):     @freezed class Shop with _$Shop { ... }
// Dipakai (freezed 3):     @freezed abstract class Shop with _$Shop { ... }

// Bab 3.4 (riverpod 2):    Ref bertipe generik (ShopsViewModelRef)
// Dipakai (riverpod 3):    Ref polos, tanpa parameter tipe
```

Semantik MVVM di Bab 3.1 **tidak berubah sama sekali**. Yang berubah hanya
sintaks deklarasi. Seluruh aturan (View tidak memanggil Repository, ViewModel
tanpa `material.dart`, Model immutable, navigasi hanya lewat GoRouter) tetap
berlaku apa adanya.

---

## B. Penyimpangan versi mayor — paket lama tidak mendukung Dart 3.12

Semua ini naik karena versi di Bab 4.2 tidak lagi menerima SDK 3.12, bukan
karena preferensi.

| Library | Bab 4.2 | Dipakai | Catatan perubahan API yang perlu diwaspadai |
|---|---|---|---|
| `go_router` | `^14.2.0` | `^17.5.0` | `GoRouterState.location` → `state.uri`. Sudah diterapkan di `app_router.dart`. |
| `google_sign_in` | `^6.2.1` | `^7.2.0` | **Perubahan terbesar.** v7 memakai singleton `GoogleSignIn.instance` + `initialize()`, bukan konstruktor. Akan berdampak saat Bab 6 dikerjakan. |
| `mobile_scanner` | `^5.1.1` | `^7.4.0` | `MobileScannerController` kini wajib di-`start()`/`dispose()` manual. Berdampak di Bab 8.3. |
| `permission_handler` | `^11.3.1` | `^13.0.1` | Perlu `compileSdk 35+` di Android. |
| `camera` | `^0.11.0` | `^0.12.0` | Perubahan kecil pada `ResolutionPreset`. |
| `geolocator` | `^12.0.0` | `^14.0.3` | `LocationSettings` menggantikan parameter `desiredAccuracy` lepas. |
| `geocoding` | `^3.0.0` | `^5.0.0` | — |
| `flutter_secure_storage` | `^9.2.2` | `^11.0.0` | — |
| `workmanager` | `^0.5.2` | `^0.10.7` | Kini terpecah per platform (`workmanager_android`, `workmanager_apple`). Catatan Bab 4.3 soal keterbatasan iOS **tetap berlaku**. |
| `connectivity_plus` | `^6.0.3` | `^7.3.1` | — |
| `flutter_local_notifications` | `^17.2.1` | `^22.3.0` | Inisialisasi Android berubah. |
| `fl_chart` | `^0.68.0` | `^1.2.0` | API `LineChartData` banyak berubah. Berdampak di Bab 10 (dasbor web). |
| `image_cropper` | `^8.0.2` | `^12.2.1` | — |
| `share_plus` | `^9.0.0` | `^13.3.0` | `Share.share()` → `SharePlus.instance.share(ShareParams(...))`. |
| `package_info_plus` | `^8.0.0` | `^10.2.1` | — |
| `device_info_plus` | `^10.1.0` | `^13.2.0` | — |
| `flutter_lints` | `^4.0.0` | `^6.0.0` | Lint baru aktif; `analysis_options.yaml` sudah disesuaikan. |

---

## C. Sesuai Bab 4.2, tanpa perubahan

`supabase_flutter`, `json_annotation`, `json_serializable`, `equatable`,
`video_player`, `chewie`, `drift`, `drift_dev`,
`path_provider`, `shared_preferences`, `dio`, `http`, `flutter_tts`,
`cached_network_image`, `shimmer`, `image_picker`, `flutter_svg`,
`url_launcher`, `webview_flutter`, `uuid`, `sentry_flutter`, `build_runner`,
`mocktail`.

---

## D. Yang perlu diputuskan Product Owner

1. **`freezed` pra-rilis.** Dipakai karena terpaksa. Risikonya rendah (hanya
   generator, tidak ikut ke APK) tetapi perlu dijadwalkan naik ke stabil.
2. **`google_sign_in` v7.** Bab 6 (autentikasi) harus ditulis mengikuti API
   baru. Tambahan waktu diperkirakan ± 1 jam dibanding v6.
3. **`fl_chart` v1.** Bab 10 dasbor web perlu mengikuti API baru. Tambahan
   waktu ± 1 jam.
4. ~~**`ffmpeg_kit_flutter_new`.** Perlu diverifikasi sekali di Minggu 2 bahwa
   filter `drawtext` benar-benar tersedia di build fork ini.~~
   ✅ **SELESAI — lihat bagian G.**

Sesuai ⚠️ aturan main Bab 0.2, poin 2 dan 3 menambah ± 2 jam pada anggaran yang
penyangganya tinggal ± 2 jam. Perlu keputusan Product Owner: tambah waktu, atau
kurangi lingkup lain dengan bobot setara.

---

## E. Keputusan Product Owner — 12 Agustus 2026

| No | Perkara | Keputusan |
|---|---|---|
| 1 | Tambahan ± 2 jam dari `google_sign_in` v7 dan `fl_chart` v1 | **Tambah waktu.** Tidak ada lingkup yang dikurangi. Penyangga Bab 0.2 kini **−2 jam** (defisit), bukan +2 jam. |
| 2 | Verifikasi `drawtext` pada `ffmpeg_kit_flutter_new` | **Dikerjakan lebih dulu**, sebelum bab mana pun dilanjutkan. |
| 3 | Berkas hasil generator (`*.freezed.dart`, `*.g.dart`) | Tetap di-gitignore. |

### Tambahan 16 Agustus 2026 — waktu pada watermark saat offline

Bab 8.5 mensyaratkan **waktu server**, sedangkan aplikasi ini offline-first.
Keputusan Product Owner:

| Keadaan | Waktu yang dipakai watermark |
|---|---|
| Pernah sinkron, jam HP wajar (selisih < 2 menit) | Waktu terkoreksi (praktis = jam HP) |
| Pernah sinkron, jam HP meleset jauh | **Waktu terkoreksi**, perekaman tetap jalan |
| Belum pernah sinkron | Jam HP apa adanya, video **ditandai "waktu belum terverifikasi"** |

Waktu terkoreksi = waktu server terakhir + lama berlalu sejak sinkron.

🔴 **Lama berlalu wajib dihitung dari penghitung yang tidak dapat diubah
pengguna** (`Stopwatch` / `elapsedRealtime`), **bukan** dari selisih jam HP.
Bila dihitung dari jam HP, orang yang mengubah jamnya di tengah sesi dapat
menggeser waktu di watermark — dan itu merusak seluruh nilai bukti produk ini.

Perekaman **tidak pernah diblokir** oleh jam yang salah: packer di gudang tidak
boleh berhenti bekerja karena itu. Bukti dengan waktu yang mungkin meleset jauh
lebih berharga daripada tidak ada bukti; server tetap mencatat `created_at`
sendiri saat video diunggah, sehingga kebenarannya masih dapat ditelusuri.

⚠️ Tanda "waktu belum terverifikasi" belum punya tempat tinggal — kemungkinan
perlu kolom di `package_videos` dan ikut ke metadata berkas lewat
`WatermarkCommand.buildMetadataComment`. Penambahan lingkup kecil, laporkan
sesuai Bab 0.2.

### Tambahan 15 Agustus 2026 — perekaman beruntun tanpa tombol

**Menyimpang dari Bab 8.3:** panel "Rekaman selesai" beserta tombol
**"Rekam paket berikutnya"** dihapus. Setelah berkas tersimpan, pemindaian
hidup lagi **dengan sendirinya**; ringkasannya hanya lewat sebentar (4 detik)
dan tidak menghalangi apa pun.

Alasan Product Owner: packer merekam ratusan paket berturut-turut. Satu ketukan
per paket berarti ratusan ketukan yang tidak menghasilkan apa pun.

🔴 **Pengaman yang WAJIB ikut ada.** Aturan berhenti membuat packer memindai
label yang sama untuk mengakhiri rekaman — dan label itu masih persis di depan
kamera sesudahnya. Tanpa pengaman, pemindaian yang langsung hidup lagi akan
menerima resi yang sama dan merekamnya ulang seketika, berulang, memakan token
dan kuota pelanggan.

Karena itu `RecordingCameraViewModel._recordedInSession` menolak resi yang sudah
selesai direkam **selama layar rekam terbuka**. Pengecekan resi ganda ke server
tidak menolong di sini: videonya belum terunggah, jadi server menjawab
"belum ada".

Cakupan "seumur layar" dipilih sadar: merekam ulang resi yang sama adalah
kejadian langka dan sudah punya jalannya lewat Riwayat, sedangkan rekaman ganda
tak disengaja akan terjadi setiap hari.

Diuji Product Owner 15 Agustus 2026 — dua-duanya lulus: (1) rekam paket A,
hentikan, langsung pindai paket B tanpa menyentuh layar → B terekam;
(2) tahan kamera menghadap label A sesudah rekaman berhenti → muncul pesan
"sudah direkam", tidak merekam ulang.

---

## F. Penyesuaian konfigurasi build Android

Lima hal berikut **bukan** perubahan library, melainkan penyesuaian Gradle yang
tanpanya build Android gagal total. Urutannya mencerminkan urutan kegagalan
yang benar-benar terjadi — tiap satu yang diperbaiki membuka penghalang
berikutnya. Semuanya berakhir pada `flutter build apk --debug` yang **sukses**
dan APK yang terpasang serta berjalan di perangkat.

| Berkas | Penyesuaian | Sebab |
|---|---|---|
| `android/app/build.gradle.kts` | `compileSdk = 37` + `compileSdkMinor = 0` | `flutter_secure_storage` 11 dan `permission_handler_android` 13 mewajibkan SDK 37. SDK Platform 37 memakai skema versi minor (direktori `platforms/android-37.0`), sehingga `compileSdk = 37` sendirian dicari sebagai `android-37` dan tidak ketemu. |
| `android/gradle.properties` | `kotlin.incremental=false` (+ dua turunannya) | Cache paket Dart di **C:**, proyek di **E:**. Kotlin menghitung path *relatif* dari sumber plugin ke folder proyek untuk cache inkremental; di Windows path relatif antar drive tidak ada → `IllegalArgumentException: this and base files have different roots`. Dapat dicabut bila `PUB_CACHE` dipindah ke drive yang sama. |
| `android/build.gradle.kts` | `languageVersion`/`apiVersion` = **2.0** untuk semua subproyek plugin | `sentry_flutter` menyetel versi bahasa 1.6; Kotlin 2.3.20 menolak di bawah 2.0. ⚠️ **Jangan naikkan ke 2.1** — sudah dicoba dan gagal: pada 2.1, `String.toUpperCase(Locale)` yang dipakai `sentry_flutter` berubah dari peringatan menjadi error. |
| `android/build.gradle.kts` | `compileSdk` subproyek plugin dinaikkan ke **36** bila di bawah itu | `sentry_flutter` memakukan compileSdk-nya di 34, sedangkan `package_info_plus` menuntut konsumennya ≥ 36 → `:sentry_flutter:checkDebugAarMetadata` gagal. |
| `android/app/build.gradle.kts` | `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` | `flutter_local_notifications` memakai API `java.time` yang baru ada di Android 8+, sedangkan minSdk kita di bawah itu. Tanpa desugaring, `:app:checkDebugAarMetadata` menolak build. |

⚠️ Ketiganya adalah penghindaran masalah, bukan penyelesaian. Semuanya bisa
dicabut satu per satu begitu penyebab aslinya hilang (plugin diperbarui, atau
`PUB_CACHE` dipindahkan). Jangan dilupakan.

---

⚠️ **Konsekuensi keputusan 1 yang harus diketahui:** penyangga jadwal 6 minggu
sekarang sudah habis dan minus. Setiap permintaan fitur baru berikutnya **tidak
lagi punya bantalan** — langsung menggeser tanggal rilis. Aturan main Bab 0.2
tetap berlaku dan perlu ditegakkan lebih ketat mulai titik ini.

---

## G. Hasil verifikasi FFmpeg `drawtext` (butir D.4) — SELESAI

**Dijalankan:** 12 Agustus 2026 · **Perangkat:** Xiaomi Redmi Note 9 (M2003J15SC)
**Cara:** `runFfmpegCapabilityCheck()`, otomatis saat aplikasi debug dijalankan.

```
===== KAMELSCAN_FFMPEG_CHECK MULAI =====
LULUS  Filter drawtext terdaftar
LULUS  Encoder libx264 tersedia
GAGAL  Render drawtext tanpa fontfile — kode 1 — Conversion failed!
LULUS  Render drawtext dengan fontfile
FONT DIPAKAI: /system/fonts/Roboto-Regular.ttf
KESIMPULAN: ADA YANG GAGAL
===== KAMELSCAN_FFMPEG_CHECK SELESAI =====
```

### Kesimpulan

✅ **Pipeline watermark Bab 8 dapat dilanjutkan.** `ffmpeg_kit_flutter_new`
menyediakan `drawtext` **dan** `libx264`, jadi rencana cadangan yang mahal
(menggambar watermark di lapisan Flutter lalu merekam ulang) **tidak diperlukan**.

🔴 **Dengan satu syarat mutlak: `fontfile` wajib selalu disebutkan.** Build
FFmpeg ini tidak menyertakan fontconfig, sehingga `drawtext` tidak punya font
bawaan dan langsung gagal bila `fontfile` dikosongkan.

### Yang sudah diperbaiki akibat temuan ini

`MobileVideoProcessor._buildCommand` semula menyusun `drawtext` **tanpa**
`fontfile` — bentuk yang terbukti gagal. Sudah diperbaiki: font dicari lebih
dulu lewat `_resolveFontFile()`, dan bila tidak ada satu pun kandidat yang
cocok, perekaman ditolak dengan `errorWatermarkFontMissing` alih-alih
menghasilkan video rusak.

### Sisa pekerjaan untuk Bab 8

⚠️ **Bundel satu berkas TTF di `assets/fonts/` dan jadikan pilihan pertama.**
Bergantung pada font sistem berisiko dua hal:

1. ROM pabrikan (khususnya ROM Cina) kadang mengganti atau menghapus Roboto —
   pada perangkat itu perekaman akan tertolak.
2. Bentuk huruf berbeda antar perangkat membuat watermark tidak seragam.
   Untuk produk yang videonya dipakai sebagai **bukti sengketa marketplace**,
   keseragaman tampilan bukan soal estetika.

Daftar font sistem di `_systemFontCandidates` adalah jaring pengaman, bukan
solusi akhir.

---

## H. Jebakan: `flutter build` memakai ulang kernel Dart dengan `--dart-define` lama

**Terjadi 13 Agustus 2026.** Aplikasi berhenti di layar *"Konfigurasi belum
lengkap"* meski dibangun dengan `--dart-define-from-file=env.dev.json`.

Urutan yang menyebabkannya:

1. `flutter run` dijalankan **tanpa** flag → kernel Dart tanpa kredensial
   tersimpan di `.dart_tool/flutter_build/`
2. `flutter build apk --dart-define-from-file=env.dev.json` berikutnya
   **memakai ulang kernel itu** — nilai `--dart-define` yang berubah tidak
   selalu membatalkan cache
3. APK jadi tanpa kredensial, tanpa satu pun peringatan saat membangun

**Cara memastikan APK benar-benar membawa kredensial** (tanpa perlu memasang ke
perangkat): `--dart-define` yang dipakai `String.fromEnvironment` ikut tertanam
di `assets/flutter_assets/kernel_blob.bin` pada build debug. Ekstrak APK sebagai
zip lalu cari teksnya:

```powershell
$tmp="$env:TEMP\apkchk"; Remove-Item -Recurse -Force $tmp -EA SilentlyContinue
New-Item -ItemType Directory -Force $tmp | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-debug.apk "$tmp\a.zip"
Expand-Archive "$tmp\a.zip" "$tmp\x" -Force
$kb = Get-ChildItem "$tmp\x" -Recurse -Filter kernel_blob.bin | Select -First 1
$t = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($kb.FullName))
$t.Contains('<project-ref-supabase>')   # harus True
```

**Pencegahan:** jangan pernah menjalankan `flutter run` polos di proyek ini.
Pakai `.\run.ps1`, atau tombol Run editor yang konfigurasinya sudah membawa
flag (`.vscode/launch.json` dan `.idea/runConfigurations/`). Bila terlanjur,
hapus `.dart_tool/flutter_build` lalu bangun ulang.

---

## I. Verifikasi kamera — pratinjau + rekam + analisis frame sekaligus

**Terverifikasi 14 Agustus 2026 · Xiaomi Redmi Note 9 (M2003J15SC)**

Syarat mutlak aturan berhenti Product Owner: pemindaian harus berjalan
**selama** merekam.

```
LULUS  Kamera terdeteksi — 2 lensa
LULUS  Pratinjau kamera menyala
LULUS  Frame mengalir SELAGI merekam — 107 frame dalam 6 detik
LULUS  ML Kit memproses frame — 3 frame diproses
LULUS  Berkas video tersimpan — 2229121 byte
KESIMPULAN: SEMUA LULUS
```

**≈ 18 frame per detik** tersedia untuk dianalisis sambil merekam — jauh lebih
dari cukup. Pemindaian barcode hanya butuh beberapa frame per detik; sisanya
justru sengaja dilewati agar antrean tidak menumpuk lebih cepat daripada ML Kit
menyelesaikannya.

### Keputusan yang kini aman diambil

`camera` + `google_mlkit_barcode_scanning` menjadi satu-satunya pemilik kamera
pada alur perekaman. `mobile_scanner` tetap dipakai di layar lain yang tidak
merekam.

### ⚠️ Temuan sampingan: ukuran berkas mentah

6 detik menghasilkan **2,2 MB** pada `ResolutionPreset.low` — sekitar
370 KB/detik. Sebuah rekaman 30 detik berarti ± 11 MB **sebelum** FFmpeg
memampatkannya.

Ini tidak melanggar target Bab 8.5 (1–3 MB per 30 detik), karena target itu
berlaku untuk hasil akhir setelah `crf 28`. Tetapi berkas mentah itu tetap
menempati penyimpanan HP sampai watermark selesai ditempelkan.

Konsekuensi untuk Bab 8.6: **antrian upload harus menyimpan berkas yang sudah
diproses, bukan yang mentah**, dan berkas mentah dihapus segera setelah FFmpeg
selesai. Packer yang merekam 50 paket saat sinyal mati akan menahan ± 550 MB
bila yang disimpan berkas mentah, dibanding ± 100 MB bila yang sudah diproses.

---

## J. Jebakan: pratinjau berputar 90° saat perekaman dimulai (StreamSharing)

**Ditemukan & diperbaiki 14 Agustus 2026 · Xiaomi Redmi Note 9 (M2003J15SC)**

### Gejala

Begitu pindaian pertama diterima dan perekaman mulai, pratinjau kamera berputar
seperempat putaran searah jarum jam. Barcode yang tadinya pas mendatar di dalam
bingkai bantu jadi melintang tegak. Saat perekaman berhenti, gambarnya kembali
normal dengan sendirinya.

Auto-rotate layar dalam keadaan **mati**, jadi ini sama sekali bukan soal
orientasi perangkat.

### Sebab

Selama merekam, kamera dipakai tiga hal sekaligus: **Preview** (pratinjau),
**ImageAnalysis** (pemindai frame ML Kit), dan **VideoCapture** (perekam).
Tiga aliran gambar terpisah hanya dijamin pada perangkat `LEVEL_3`. Redmi
Note 9 hanya `INFO_SUPPORTED_HARDWARE_LEVEL_FULL`, jadi CameraX menyalakan
**StreamSharing**: Preview dan VideoCapture digabung menjadi satu aliran, lalu
dipisah lagi lewat `SurfaceProcessorNode` (OpenGL).

Pemroses itu **memutar sendiri gambarnya 90° ke dalam piksel**, lalu melapor
`rotationDegrees=0` — "tidak perlu diputar lagi". Tetapi
`camera_android_camerax` menetapkan **sekali di awal** siapa yang bertugas
memutar (`surfaceProducerHandlesCropAndRotation`) dan tidak pernah menengok
lagi. Flutter tetap memutar 90° seperti semula, dua putaran menumpuk.

Bukti dari logcat (`adb shell setprop log.tag.StreamSharing VERBOSE`):

```
sebelum : D/Preview  onSuggestedStreamSpecUpdated: resolution=720x480
merekam : D/StreamSharing  onSuggestedStreamSpecUpdated: resolution=1440x1080
          D/SurfaceProcessorNode  [StreamSharing]
            inputEdge  rotationDegrees=90, rotationInTransform=0
            outputEdge rotationDegrees=0,  rotationInTransform=90
          D/Preview  resolution=480x720 (originalConfiguredResolution=720x480)
berhenti: D/Preview  onSuggestedStreamSpecUpdated: resolution=720x480
```

Perhatikan bingkainya berbalik bentuk: `720x480` (mendatar) → `480x720`
(tegak) → `720x480` lagi.

### Kenapa tidak bisa dihindari

Menghapus ImageAnalysis saat merekam memang mematikan StreamSharing, tetapi
melanggar aturan berhenti Product Owner (pindai resi **yang sama** setelah
5 detik harus menghentikan rekaman). Pemindaian wajib berjalan selama merekam,
jadi tiga use case memang harus diterima.

### Perbaikan

`CameraService.readPreviewRotationCorrection()` menanyakan langsung ke CameraX
ukuran bingkai pratinjau **yang sedang berjalan**, lalu membandingkan bentuknya
dengan bentuk saat kamera dibuka. Bila berbalik dari mendatar jadi tegak,
berarti CameraX sudah memutar sendiri, dan layar membatalkan satu seperempat
putaran (`RotatedBox(quarterTurns: -1)`) sekaligus membalik bentuk kotak
pratinjaunya. Dibaca ulang saat perekaman mulai dan saat berhenti.

⚠️ **Jangan menggantinya dengan "kalau sedang merekam, putar balik 90°".**
StreamSharing tidak selalu menyala — perangkat `LEVEL_3` sanggup tiga aliran
sekaligus dan tidak memutar apa pun. Koreksi buta akan membuat pratinjau di
perangkat itu justru miring. Yang diperiksa harus **bentuk bingkainya**, bukan
status perekaman.

### Konsekuensi: dua paket disebut terang-terangan di `pubspec.yaml`

`camera_android_camerax` dan `camera_platform_interface` sebenarnya bawaan
`camera`, tetapi kita mengimpornya langsung sehingga harus dicantumkan
(`depend_on_referenced_packages`). Ukuran pratinjau dibaca lewat
`AndroidCameraCameraX.preview.getResolutionInfo()`; medan `preview` ditandai
`@visibleForTesting` oleh paketnya, jadi perlu satu baris `// ignore:`.
Tidak ada jalan lain — paket itu tidak menyediakan cara menanyakan ukuran
pratinjau yang sedang berjalan, dan justru di situlah letak cacatnya.

⚠️ `camerax_library.g.dart` menarik `dart:io`, jadi impornya **wajib** lewat
conditional import (`preview_rotation_probe.dart`) seperti
`barcode_frame_reader.dart` — kalau tidak, `flutter build web` gagal (Bab 4.3).

### Hasil pengujian di perangkat — 15 Agustus 2026, Redmi Note 9

**Pratinjau: TERBUKTI BENAR.** Diuji lewat mode Input Manual (memicu
StreamSharing yang sama tanpa perlu memindai barcode). Koreksi berbalik tepat
mengikuti laporan CameraX, tiga siklus penuh, dua arah:

| Keadaan | Bingkai CameraX | Koreksi |
|---|---|---|
| siaga | 720x480 | 0 |
| merekam | 480x720 | −1 |
| berhenti | 720x480 | 0 |

Dibandingkan pada adegan yang sama sebelum dan saat merekam: benda uji tegak,
tulisannya mendatar, tidak gepeng.

**Berkas video: terbukti sebagian.** Header MP4 dibaca langsung — `tkhd`
menunjukkan `480x640` dengan matriks putaran **0**, artinya tersimpan tegak dan
pemutar tidak perlu memutarnya lagi. Isinya belum diperiksa dengan mata;
percobaan membuka video lewat `adb` gagal karena MIUI selalu mengembalikan
fokus ke aplikasi.

### Dua cacat lanjutan — dilaporkan Product Owner & DIPERBAIKI 15 Agustus 2026

**1. Pratinjau gepeng selama merekam — SELESAI.** Putarannya sudah benar,
bentuknya belum. Penyebabnya:

`CameraPreview` menetapkan bentuk kotaknya dari `AspectRatio(1/previewSize)`,
dan `previewSize` hanya diisi **sekali** saat kamera dibuka (720x480). Plugin
lalu membalik kotak itu lewat `RotatedBox(1)`, sehingga `Texture` selalu
menerima kotak 720x480 — padahal selama merekam isinya 480x720. Gambar tegak
diperas ke kotak mendatar: melar **2,25 kali**.

Koreksi putaran tidak bisa menyembuhkannya, karena bentuk kotaknya ditentukan
di dalam `CameraPreview` dan tidak dapat ditimpa dari luar.

🔴 **`CameraPreview` karena itu TIDAK dipakai lagi.** Layar memakai
`controller.buildPreview()` langsung, dengan kotaknya dihitung sendiri dari
ukuran bingkai yang sedang berjalan (`PreviewGeometry.liveSize`).

Konsekuensinya — **jangan dihapus**: putaran yang dulu disumbang `CameraPreview`
(`portraitUp`→0, `landscapeRight`→1, `portraitDown`→2, `landscapeLeft`→3) harus
direplikasi sendiri di `_Preview._preAppliedQuarterTurns`, karena delegasi
plugin menguranginya lagi lewat
`getPreAppliedQuarterTurnsRotationFromDeviceOrientation`. Tanpa salinan itu,
pratinjau ikut miring begitu perangkat dimiringkan.

Terbukti dengan gunting berpegangan lingkaran: kedua lingkarannya tetap bulat
selama merekam. Lingkaran adalah penguji proporsi paling jujur — melar 2,25×
akan membuatnya lonjong.

**2. Kedipan putaran saat mulai merekam — SELESAI.** CameraX membalik bingkai
**di tengah** `startVideoRecording`, ± 620 ms sebelum panggilan itu kembali;
koreksi yang dibaca sesudahnya selalu terlambat sejauh itu. Diukur di Redmi
Note 9:

```
01:58:48.563  CameraX membalik bingkai → 480x720
01:58:49.183  koreksi baru masuk            (jeda 620 ms)
```

Perbaikannya: `_followPreviewGeometry()` memantau bingkai **berbarengan** dengan
`startVideoRecording`, tiap 60 ms, berhenti pada perubahan pertama. Sesudahnya:

```
13:54:59.462  koreksi=-1 merekam=false   ← tertangkap di tengah startRecording
13:55:00.080  koreksi=-1 merekam=true    ← saat panggilan akhirnya kembali
```

Koreksi masuk **618 ms lebih awal**; sisa kedipnya paling lama satu putaran
pemantauan (60 ms). `merekam=false` pada baris pertama adalah buktinya.

**3. Kedipan sisa pada kedua peralihan — ditutup, bukan dikejar.**

Memangkas jeda saja ternyata tidak cukup. Product Owner menguji ulang dengan HP
diam dan gunting sebagai objek acuan, lalu menemukan kuncinya: saat **mulai**
merekam gunting berputar dari selatan ke **timur**, saat **berhenti** dari
selatan ke **barat** — dua arah **berlawanan**.

Arah berlawanan itulah buktinya: CameraX mengumumkan bingkai barunya lewat
**metadata lebih dulu**, dan baru beberapa frame kemudian benar-benar mengirim
piksel yang sudah diputar. Koreksi yang masuk terlalu cepat memiringkan ke satu
arah; yang terlalu lambat ke arah sebaliknya.

🔴 **Balapan ini tidak bisa dimenangkan dengan mengatur waktu.** Flutter tidak
punya cara mengetahui frame mana yang pertama sudah berputar. Karena itu
pratinjau **ditutup** selama peralihan — `RecordingScreenState.previewSettling`,
hitam seketika lalu memudar 220 ms. Berlaku untuk mulai **dan** berhenti.

**Jedanya (`_previewSettleGrace`) aman kelebihan, tidak aman kekurangan.**
Kelebihan hanya membuat layar hitam sedikit lebih lama; kekurangan membuat
kedipan putarannya terlihat lagi. Diuji Product Owner di Redmi Note 9:

| Jeda | Hasil |
|---|---|
| 400 ms | **kebobolan** — hitam, lalu putaran masih sempat terlihat |
| **1 detik** | **bersih** — hitam lalu langsung normal, kedua peralihan |

⚠️ Jangan memangkasnya berdasarkan dugaan; turunkan sedikit demi sedikit sambil
diuji ulang di perangkat. Dan jangan menaikkannya tanpa batas bila suatu saat
kebobolan lagi — menambah terus sampai "kebetulan pas" hanya menutupi masalah,
dan akan meleset di perangkat lain. Bila 1 detik tidak lagi cukup, itu tanda
menutupi bukan jalannya.

### Perbaikan sejati ada di paket, bukan di aplikasi ini

Akar kedipan ini adalah cacat `camera_android_camerax`: paket itu menetapkan
**sekali di awal** siapa yang bertugas memutar
(`surfaceProducerHandlesCropAndRotation`) dan tidak pernah menengok lagi, serta
tidak menyediakan cara apa pun mengetahui kapan piksel yang sudah diputar mulai
berdatangan.

Menambalnya berarti memelihara fork paket resmi Flutter pada bagian paling
rawan di aplikasi ini. **Ditunda 15 Agustus 2026** dengan alasan: berkas
videonya tidak terpengaruh sama sekali, penyangga jadwal sudah minus ± 5 jam,
dan Bab 8.5–8.6 belum dikerjakan. Yang layak dilakukan lebih dulu adalah
melaporkannya sebagai isu ke Flutter — buktinya sudah lengkap di bagian ini.

Kedipan ini **tidak pernah masuk ke berkas video** — murni soal tampilan.

### Pengukuran untuk Bab 8.5 — FFmpeg TIDAK boleh jalan saat merekam

Diukur di Redmi Note 9, 15–16 Agustus 2026, dengan pengukur sementara yang
menjalankan `VideoProcessor.applyWatermark()` sungguhan pada rekaman yang baru
selesai. Pengukurnya sudah dicabut; angkanya disimpan di sini.

**Penyusutan berkas — jauh lebih baik dari perkiraan Bab 8.6:**

| 50 video antre saat sinyal mati | Perkiraan Bab 8.6 | Terukur |
|---|---|---|
| Mentah | 550 MB | **795 MB** |
| Hasil proses | 100 MB | **55 MB** |

Video 30 detik: ± 16 MB mentah → ± 1–2,5 MB hasil. Menyusut **± 14 kali**,
bukan 5,5 kali seperti tertulis di dokumen. Menyimpan yang mentah lebih buruk
dari dugaan, menyimpan hasil olahannya jauh lebih murah.

**Kecepatan proses (mode profile):** rasio 0,58–0,87x terhadap durasi video —
FFmpeg lebih cepat daripada perekamannya sendiri. Di mode **debug** rasionya
melonjak sampai 1,15x; jangan pernah mengambil keputusan kinerja dari build
debug.

🔴 **Temuan yang menentukan rancangan:** menjalankan FFmpeg segera setelah tiap
rekaman — selagi packer merekam paket berikutnya — membuat **pratinjau
patah-patah dan HP panas**. Dibuktikan dengan memisahkan bebannya: begitu
pengukur FFmpeg dicabut dan hanya kamera yang berjalan, pratinjaunya kembali
mulus. Jadi penyebabnya FFmpeg, bukan jalur kameranya.

Konsekuensi untuk Bab 8.5: **jangan "tembak lalu lupa" sesudah tiap rekaman.**
Watermark harus mengantre dan dikerjakan saat tidak sedang merekam. Rasio di
bawah 1,0x membuat antrean tetap terkuras selama ada jeda antar-paket.

⚠️ Pengukur itu juga punya cacat yang jangan ditiru: dipanggil `unawaited`
tanpa antrean, sehingga beberapa FFmpeg berjalan bersamaan saat perekaman
beruntun dan saling berebut CPU. Dan rasio menyesatkan untuk video pendek —
FFmpeg punya ongkos tetap di awal, sehingga video 3,8 detik terlihat "1,20x"
padahal absolutnya hanya 4,6 detik.

### Jebakan: `adb install` ditolak MIUI saat HP tanpa internet

Pesannya menyesatkan:

```
Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
```

Terdengar seolah ada yang menekan Batal, padahal dialog izinnya **tidak pernah
sempat muncul**. MIUI memverifikasi pemasangan via USB ke server Xiaomi lebih
dulu; tanpa koneksi, permintaannya ditolak otomatis. Ini melengkapi jebakan
nomor 6 di `PROMPT_SESI_BARU.md`, yang baru menyebut sakelar "Instal via USB".

Periksa koneksinya dulu sebelum menuduh sakelarnya:

```
adb shell ping -c 2 8.8.8.8
```

⚠️ `adb install` juga mengembalikan **exit code 0 walaupun gagal** — jangan
percaya status "selesai", baca keluarannya.

### Jejak `KAMELSCAN_ROTASI` — jangan dihapus tanpa penggantinya

🔴 `AppLogger` memakai `dart:developer`, yang **tidak pernah sampai ke logcat** —
hanya ke terminal `flutter run`. Begitu terminal itu ditutup, seluruh
kemampuan mendiagnosis rotasi dari perangkat ikut hilang. Buta itu sempat
membuang satu putaran build penuh pada 15 Agustus 2026.

Karena itu `preview_rotation_probe_mobile.dart` dan
`CameraService.readPreviewRotationCorrection()` mencetak lewat `debugPrint`
(yang tembus logcat sebagai `I/flutter`), bukan hanya `AppLogger`. Membacanya:

```
adb logcat -v time | findstr KAMELSCAN_ROTASI
```

Ini akan dibutuhkan lagi saat menguji di perangkat lain: pada perangkat
`LEVEL_3`, StreamSharing tidak menyala dan koreksinya harus tetap `0`.

---

## K. Jebakan kinerja: pratinjau dibangun ulang tiap detak pencatat waktu

**Ditemukan & diperbaiki 16 Agustus 2026 · Xiaomi Redmi Note 9**

### Gejala

Pratinjau kamera patah-patah selama merekam, dan HP menjadi sangat panas.
Terasa sejak layar rekam dipakai sungguhan, bukan hanya di build debug.

### Yang BUKAN penyebabnya

Diselidiki satu per satu, dan ketiganya terbukti bukan biang utamanya —
dicatat agar tidak diselidiki ulang:

1. **Build debug.** Memang memberatkan, tetapi build `--profile` pun masih
   patah-patah.
2. **FFmpeg.** Pengukur watermark sempat dituduh. Dicabut, dan pratinjaunya
   **tetap** patah-patah.
3. **Konversi frame ke ML Kit.** Sempat diduga menyalin ± 700 KB per frame di
   Dart. Ternyata `barcode_frame_reader_mobile.dart` meneruskan
   `image.planes.first.bytes` **langsung**, tanpa salinan.

### Sebab sesungguhnya

`RecordingCameraViewModel` menjalankan pencatat waktu tiap 200 ms untuk
memperbarui angka durasi. Tiap detak mengubah state, dan `build` seluruh
halaman ikut berjalan — **5 kali per detik**. Yang ikut dibangun ulang termasuk
subtree terberat di layar: `Texture` kamera beserta `RotatedBox` dan
`controller.buildPreview()`-nya, padahal isinya tidak berubah sama sekali.

### Perbaikan

🔴 `_preview` dan `_transitionCover` dibuat **sekali** sebagai field
`late final` di `_RecordingCameraPageState`, lalu dipakai ulang. Karena Flutter
melihat instance widget yang identik, subtree itu dilewati saat halaman
dibangun ulang.

Keduanya berlangganan sendiri ke kepingan state yang benar-benar dibutuhkan
(`cameraReady`, `previewGeometry`, `previewSettling`) lewat `ref.watch(...select(...))`,
sehingga tetap ikut berubah saat memang perlu.

⚠️ **Jangan mengubahnya kembali menjadi konstruksi di dalam `build`** — mis.
`_Preview(ready: state.cameraReady, geometry: state.previewGeometry)`. Itu
terlihat lebih rapi dan lebih "Flutter", tetapi mengembalikan patah-patahnya.

### Akibat lanjutan yang belum ditindaklanjuti

Pengukuran FFmpeg pada 15 Agustus 2026 (rasio 0,58x–1,20x) diambil **sebelum**
perbaikan ini, jadi angkanya tercemar beban gambar ulang. Bila keputusan
"watermark segera vs ditunda" (Bab 8.5) hendak diambil berdasarkan angka,
**ukur ulang** — kemungkinan besar hasilnya lebih baik dari yang tercatat.

⚠️ Pengukur itu juga memanggil FFmpeg dengan `unawaited` tanpa antrean,
sehingga beberapa proses berjalan bersamaan saat merekam beruntun. Bab 8.5
yang sungguhan wajib berurutan satu per satu.

---

## L. Pipeline Bab 8.5–8.7: watermark, antrian, unggah

**Dikerjakan 17 Agustus 2026.** Bagian ini mencatat keputusan yang tidak
terbaca dari kodenya sendiri.

### L.1 Waktu watermark saat perangkat offline

Bab 8.5 mensyaratkan **waktu server**, sedangkan produk ini offline-first.
Aturan yang diputuskan Product Owner 16 Agustus 2026 diterapkan di
`core/domain/time_sync.dart` (murni, teruji tanpa perangkat) dan dijalankan
`core/services/server_clock.dart`.

Intinya satu kalimat: **waktu watermark = waktu server terakhir + berapa lama
berlalu menurut penghitung yang tidak dapat diubah pengguna.** Tidak ada satu
baris pun yang mengurangi jam HP; kalau ada, memundurkan jam perangkat akan
menggeser waktu di seluruh video sesudahnya.

Penghitungnya dicari berjenjang di `monotonic_source_mobile.dart`:

| Tingkat | Sumber | Bertahan setelah |
|---|---|---|
| 1 | `SystemClock.elapsedRealtime()` (native) + `boot_id` | aplikasi ditutup |
| 2 | `Stopwatch` (jam monotonic Dart) | — hanya seumur aplikasi |

🔴 **Keduanya dipakai bersama, dan itu bukan kelebihan.** Penghitung sejak-boot
sendirian kembali ke nol setiap HP dinyalakan ulang. Bila kebetulan HP sudah
menyala lebih lama daripada bacaan yang tersimpan, titik acuan lama akan tampak
masih sah dan waktunya meleset berjam-jam **tanpa satu pun gejala**. `boot_id`
berganti tiap boot, sehingga kekeliruan itu mustahil.

Bila keduanya tidak terbaca, aplikasi turun ke `Stopwatch` dan — setelah
ditutup lalu dibuka lagi tanpa sinyal — **menandai videonya
`time_verified = false`** alih-alih diam-diam memakai jam HP. Videonya tetap
direkam (aturan 4 Product Owner).

#### Kenapa ada kode Kotlin di `MainActivity` — rencana pertama gagal di perangkat

Rancangan semula sengaja menghindari kode native dengan membaca `/proc/uptime`,
berkas biasa yang di Linux dapat dibaca siapa pun. **Diuji lebih dulu sebelum
kode besar ditulis di atasnya, dan ternyata tidak bisa** (Redmi Note 9, MIUI,
17 Agustus 2026):

```
$ adb shell cat /proc/mounts | grep -w proc
proc /proc proc rw,relatime,gid=3009,hidepid=2 0 0

$ adb shell run-as id.kamelscan.app cat /proc/uptime
cat: /proc/uptime: Permission denied
$ adb shell run-as id.kamelscan.app cat /proc/stat
cat: /proc/stat: Permission denied
$ adb shell run-as id.kamelscan.app cat /proc/sys/kernel/random/boot_id
e1dfb6e7-a33b-412c-861a-6c88dfeea1c1
```

MIUI memasang `/proc` dengan `hidepid=2`; dari seluruh berkas yang dicoba,
hanya `boot_id` yang lolos. Karena itu angka waktunya kini datang dari
`SystemClock.elapsedRealtime()` lewat `MethodChannel`
(`id.kamelscan.app/monotonic`) — API Android yang memang dirancang untuk ini:
menghitung sejak HP menyala termasuk saat tidur, tanpa izin apa pun, dan tidak
terpengaruh perubahan jam.

⚠️ **iOS belum punya sisi nativenya** dan akan turun ke `Stopwatch`. Untuk MVP
Android hal itu tidak menghalangi; saat iOS digarap, tambahkan
`ProcessInfo.processInfo.systemUptime` pada saluran yang sama.

⚠️ **Yang mana yang berlaku di perangkat wajib dibaca, bukan diasumsikan:**

```
adb logcat -v time | findstr KAMELSCAN_WAKTU
```

### L.2 Tanda `time_verified` — penambahan lingkup yang disetujui

Disetujui Product Owner 17 Agustus 2026, ± 1 jam. Tiga tempat:

1. kolom `package_videos.time_verified` (migrasi `19_server_time.sql`),
2. metadata berkas video (`time_verified=0|1`, selalu ditulis),
3. **terbakar ke gambar** sebagai *"(waktu belum terverifikasi)"* di baris jam.

Nomor 3 sengaja: berkas video beredar lepas dari aplikasi, dan orang yang
membacanya saat sengketa harus tahu seberapa jauh jam itu boleh dipercaya
tanpa perlu membuka database siapa pun.

### L.3 FFmpeg dijadwalkan di sela antar-paket

Diputuskan Product Owner 17 Agustus 2026. `VideoProcessingQueue` mengerjakan
**satu** video pada satu waktu dan dijeda seluruhnya selama merekam; pekerjaan
yang sedang berjalan **dibatalkan** saat perekaman dimulai, lalu diulang dari
berkas mentahnya yang masih utuh.

Pembatalan itu sengaja **tidak** menghabiskan jatah percobaan. Tanpa aturan
tersebut, packer yang memindai paket berikutnya dengan cepat akan membuat video
sebelumnya dianggap gagal lima kali dan berhenti diproses.

Alternatif "kerjakan semua setelah keluar layar rekam" ditolak: 50 paket berarti
± 795 MB rekaman mentah menumpuk selama sesi.

⚠️ Angka rasio lama (0,58x–1,20x) diambil sebelum perbaikan bagian K dan
**tercemar**. Pengukuran ulang di perangkat masih menjadi pekerjaan terbuka.

### L.4 Satu kolom `localPath`, bukan dua

Selama status `pending_process` isinya rekaman mentah; setelah watermark
ditempelkan ia berganti menjadi hasil prosesnya, dan yang mentah dihapus. Satu
kolom dipilih agar tidak pernah ada keraguan berkas mana yang akan diunggah.

🔴 Urutannya tidak boleh dibalik: berkas mentah **baru** dihapus setelah hasil
olahannya ada di disk **dan** sudah tercatat di antrian. Bila pencatatannya
gagal, yang dihapus justru hasil prosesnya — yang mentah masih dapat diolah
ulang, sedangkan rekaman yang hilang tidak dapat dibuat ulang.

Hasil proses disimpan di `getApplicationSupportDirectory()/videos`, **bukan**
cache: cache boleh dibuang sistem operasi kapan saja, dan isinya di sini adalah
bukti pelanggan yang belum terkirim.

### L.5 Baris `package_videos` dibuat saat mengunggah, bukan saat merekam

Edge Function `get-upload-url` menolak video yang barisnya belum ada, sedangkan
perekaman terjadi di gudang tanpa sinyal. Karena itu barisnya disisipkan pada
langkah pertama proses unggah (`VideoRepository.ensureVideoRow`).

⚠️ `23505` di titik itu berarti **dua hal yang berbeda**: barisnya sudah kita
buat pada percobaan sebelumnya yang putus, atau resinya memang sudah pernah
direkam (Bab 7.7). Yang pertama dilanjutkan, yang kedua ditandai `duplicate`.
Menyamakan keduanya berarti membuang video pelanggan.

### L.6 Kuota habis bukan kegagalan unggah

Kuota token habis dan langganan berakhir adalah keadaan **milik tenant**.
Menghabiskan jatah 5 percobaan karenanya akan membuang video yang sebenarnya
baik-baik saja begitu Owner mengisi token. Keduanya menjadwalkan ulang
1 jam kemudian tanpa menambah hitungan percobaan.

### L.7 Sakelar "unggah lewat data seluler" disimpan di perangkat

Diputuskan Product Owner 17 Agustus 2026: `SharedPreferences`, bukan kolom di
`user_settings`. Alasannya bukan penghematan migrasi — ini preferensi milik
**satu HP**, dan packer berkuota terbatas tidak seharusnya terikat pilihan
packer yang memakai HP kantor.

**Sakelarnya dipasang lebih awal di halaman Akun** — diputuskan Product Owner
17 Agustus 2026, setelah keadaan tanpa-layar terbukti memblokir pengujian:
perangkat uji hanya punya sinyal seluler (HP-nya dipakai sebagai hotspot untuk
laptop), enam video menumpuk di antrian, dan tidak ada satu pun cara
mengeluarkannya. `CellularUploadSwitch` berada tepat di atas tombol Keluar.

Pindahkan ke Pengaturan begitu Bab 9.7 dikerjakan. Nilainya sendiri ada di
`SharedPreferences`, jadi kepindahan itu tidak menghilangkan pilihan pengguna.
Tambahan lingkup ± 1 jam, dilaporkan sesuai Bab 0.2.

### L.8 Unggah di latar belakang belum diuji di perangkat

`uploadCallbackDispatcher` kini benar-benar berisi alur unggah, bukan lagi
`return true` kosong. Dua hal yang wajib diperiksa saat mengujinya:

1. sesi Supabase harus pulih di isolate itu — bila tidak, seluruh permintaan
   ditolak 401 dan antrian menghabiskan jatah percobaannya tanpa sebab yang
   terlihat pengguna;
2. dua koneksi drift ke berkas SQLite yang sama (aplikasi + isolate) dapat
   saling mengunci.

Token tidak akan terpotong dua kali walau keduanya berjalan bersamaan: trigger
`after_video_uploaded` hanya bereaksi pada **perubahan** status ke `uploaded`.

Jalur utama tetap aplikasi yang sedang terbuka — dipicu saat dibuka, saat sesi
pengguna siap, dan tiap kali jaringan kembali (`uploadPipelineProvider`).

### L.9 Sinkronisasi waktu berjalan sebelum sesi login pulih

**Ditemukan di perangkat 17 Agustus 2026. Satu sesi uji penuh terbuang.**

Gejalanya: enam video keluar dari pipeline dengan `time_verified = false`, dan
`adb logcat` tidak memuat satu pun baris yang menjelaskan sebabnya.

Dua cacat yang bertumpuk, dan yang kedua menyembunyikan yang pertama:

**1. `sync()` dipanggil terlalu dini.** `uploadPipelineProvider` dihidupkan di
build pertama `KamelScanApp` ([`app.dart`](lib/app.dart)), saat sesi Supabase
belum pulih dari penyimpanan. `server_now()` pun terpanggil sebagai anon dan
ditolak — persis perilaku yang sudah tercatat benar di L.1:

```
PostgrestException(message: permission denied for function server_now,
                   code: 42501, details: Unauthorized)
```

Sesudah itu satu-satunya pemicu coba-lagi adalah **pergantian jaringan**. HP
yang menyala di satu jaringan yang sama sepanjang sesi tidak pernah memicunya,
sehingga titik acuan waktu tidak pernah terisi dan **seluruh** video sesi itu
ditandai belum terverifikasi.

Perbaikannya: `ref.listen(sessionProvider, …)` di `uploadPipeline` —
sinkronisasi diulang begitu sesi pengguna siap.

**2. Kegagalannya senyap.** Seluruh jalur gagal di `ServerClock.sync()` hanya
memakai `AppLogger`, yang memakai `dart:developer` dan **tidak pernah sampai ke
logcat** (jebakan 11 di `PROMPT_SESI_BARU.md`). Yang tercetak lewat `debugPrint`
hanya jalur **berhasil**.

🔴 Ini kebalikan dari yang dibutuhkan. Keberhasilan tidak perlu didiagnosis;
kegagalanlah yang perlu. Aturan untuk seluruh jejak `KAMELSCAN_*` yang
ditambahkan sesudah ini: **bila jalur berhasilnya dicetak dengan `debugPrint`,
jalur gagalnya wajib ikut.**

Sesudah keduanya diperbaiki, terbaca di Redmi Note 9 (profile):

```
KAMELSCAN_WAKTU sinkron GAGAL · PostgrestException(… 42501 …)   12:53:32
KAMELSCAN_WAKTU sinkron · selisih jam HP 0 detik · sejak HP menyala   12:54:36
```

Baris pertama adalah percobaan pra-login yang memang gagal, baris kedua
percobaan ulang sesudah sesi siap. Selisih jam HP **0 detik** — jam perangkat
uji ini memang tepat, jadi toleransi ±2 menit (aturan 3) belum pernah teruji
pada jam yang benar-benar meleset.

### L.10 Hasil uji perangkat 17 Agustus 2026 — Redmi Note 9, mode profile

Pipeline berjalan utuh dari rekam sampai R2 untuk pertama kalinya.

**Watermark.** Rasio proses/durasi terbaca **0,42x** (12 detik untuk video 30
detik), lebih cepat daripada rentang 0,58–0,73x yang tercatat sebelumnya di
bagian J. Penyusutan berkas 16,5 MB → 1,0 MB.

Pada sesi yang sama, saat enam video antre beruntun, rasionya **0,61x dan
0,81x**. Ketiganya di bawah 1,0x, jadi antrean tetap terkuras — tetapi selisih
0,42 ke 0,81 menunjukkan angka satu-video-sendirian **bukan** angka yang layak
dipakai merencanakan. Pakai yang beruntun.

**Unggah.** Terbukti dari ujung ke ujung:

```
KAMELSCAN_PIPA Watermark selesai · 12 dtk untuk video 30 dtk (rasio 0.42)
KAMELSCAN_PIPA Mengunggah 1 video
KAMELSCAN_PIPA Terunggah · resi=10952ERTY · tenant/…/2026/08/….mp4
```

Barisnya diperiksa langsung di database: `status = uploaded`,
`time_verified = true`, `file_size_bytes = 1034380`, `duration_seconds = 30`.

**Isi watermark — dilihat langsung oleh Product Owner pada berkas di R2.**
Keempat unsur Bab 8.5 tergambar, urutannya sesuai `buildFilterChain`: nomor
resi paling dekat tepi dan hurufnya paling besar, sisanya naik ke atas.

```
GPS: -6.972683, 109.711146
Shopee · Toko Uji Bab 8
17/08/2026 19.59.00
RESI: 10952ERTY
```

🔴 **Inilah bukti terkuat bahwa L.9 benar-benar tuntas.** Log unggah bertanda
`12:59` UTC; WIB = UTC+7 = **19:59**, persis seperti yang tergambar. Dan tidak
ada keterangan *"(waktu belum terverifikasi)"* — angka itu datang dari titik
acuan waktu server, bukan dari jam HP. Rantai lengkapnya terbukti dari
`server_now()` sampai ke piksel.

Pengamatan Product Owner: pada pemutar video biasa, palang kontrol di dasar
layar menutupi sebagian baris tanggal. Bukan cacat — posisi watermark adalah
pengaturan tenant (`WatermarkPosition`), jadi pelanggan yang terganggu dapat
memindahkannya.

**Pemotongan token — diperiksa langsung di `token_ledger`.** Dua video diunggah
pada sesi itu, dan keduanya memotong tepat satu token:

```
100  monthly_reset                              → 100
 -1  video_upload  c45d8a35… (resi 10952ERTY)   →  99
 -1  video_upload  0c1abce5… (resi 8990085023648) → 98
```

`balance_after` ikut tercatat di tiap baris, jadi urutannya dapat ditelusuri
tanpa menghitung ulang dari saldo. Trigger `after_video_uploaded` terbukti
bereaksi sekali per video, bukan per percobaan unggah.

⚠️ Jebakan saat memeriksa ini: saldo dibaca 98 padahal baru satu video yang
diketahui terunggah, dan sempat terlihat seperti pemotongan ganda. Yang
sebenarnya terjadi: Product Owner merekam video kedua di sela pemeriksaan.
**Cocokkan `token_ledger.video_id` dengan `package_videos`, jangan menyimpulkan
dari selisih saldo saja.**
