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
