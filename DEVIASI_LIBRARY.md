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

> **Utang ini lunas 19 Agustus 2026.** Sakelarnya sudah pindah ke halaman
> Pengaturan (Bab 9.7) — lihat M.14.

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

### L.8 Unggah di latar belakang — isolate terbukti hidup 17 Agustus 2026

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

**Hasil uji 17 Agustus 2026 (Redmi Note 9, profile):**

```
KAMELSCAN_LATAR Tugas latar dijalankan: kamelscan.uploadQueue
supabase.supabase_flutter: INFO: ***** Supabase init completed *****
KAMELSCAN_LATAR sesi pulih · uid=f999c837-…
KAMELSCAN_LATAR selesai
```

Kedua risiko di atas terjawab: sesi Supabase **pulih** di isolate, dan drift
terbuka berdampingan dengan aplikasi tanpa "database is locked".

🔴 **Yang belum terbukti: satu video sungguhan terkirim dari isolate ini.**
`selesai` hanya berarti putarannya bersih — antriannya memang kosong, karena
jalur aplikasi-terbuka sudah mengambil semuanya lebih dulu. Itu memang
rancangannya, dan justru membuat jalur latar sulit diuji tersendiri.

Cara mengujinya tanpa mengakali kode, bila suatu saat diperlukan: rekam video
dengan sakelar data seluler **mati** sehingga ia mengantre, tutup aplikasi
(jangan *force-stop* — Android tidak menjalankan WorkManager untuk aplikasi
yang dihentikan paksa), lalu sambungkan HP ke **Wi-Fi**. Tugas periodik 15
menit akan menemukan antrian yang sudah boleh jalan. Ini juga persis keadaan
sungguhannya: packer berjalan kembali ke jangkauan Wi-Fi dengan aplikasi
tertutup.

### L.11 Layar rekam: blok gelap dicabut, watermark ditampilkan

**Dua keputusan Product Owner 17 Agustus 2026, sesudah melihat hasil uji.**

**1. Blok gelap di luar bingkai pindai — DICABUT.**

`ScanFrameOverlay` semula menutup seluruh layar di luar kotak dengan hitam 60%,
"supaya mata packer langsung tertuju ke dalamnya". Alasan itu benar untuk layar
yang **hanya** dipakai memindai, dan salah untuk layar ini: packer memindai
**sambil mengemas**, jadi yang digelapkan justru barang dan meja yang sedang ia
kerjakan.

Sudut bingkainya kini digambar dua kali — garis hitam tipis lebih dulu sebagai
tepian, lalu warnanya di atas. Tanpa latar gelap, sudut putih dapat lenyap di
atas kardus terang.

🔴 Jangan mengembalikan blok gelapnya tanpa bertanya lebih dulu. Ini keputusan
Product Owner, bukan kelalaian.

**2. Isi watermark ditampilkan selama merekam.**

Sebelumnya packer baru dapat melihat isi watermark setelah videonya jadi **dan
terunggah** — terlambat untuk menyadari nama toko yang salah, GPS yang tidak
terbaca, atau waktu yang belum terverifikasi. Sekarang ia melihatnya saat masih
bisa berbuat sesuatu.

Tiga hal yang membuatnya tidak berubah jadi utang:

- **Satu penyusun isi.** Daftar barisnya dipindahkan dari
  `video_processor_mobile.dart` (hanya jalan di perangkat) ke
  `WatermarkCommand.buildLines` — yang sama dipakai FFmpeg **dan** layar. Dua
  penyusun terpisah berarti layar perlahan menjanjikan sesuatu yang tidak ada
  di videonya, dan packer akan mempercayai yang salah.
- **Waktunya tidak berdetak.** Yang terbakar adalah satu tanda waktu, yaitu
  saat rekaman dimulai. Jam berjalan di layar justru akan berbohong.
- **Berlangganan hanya pada `watermarkPreview`**, seperti `_TransitionCover`.
  Membangunnya dari seluruh keadaan layar berarti ia ikut dibangun ulang tiap
  detak pencatat waktu — jebakan 14, yang dulu membuat pratinjau patah-patah
  dan gejalanya tampak seperti masalah kamera.

Koordinat GPS tiba beberapa detik setelah rekaman mulai, jadi pratinjaunya
diperbarui sekali saat `_captureLocation` selesai. Tanpa itu layar akan tetap
bertuliskan *"Lokasi tidak tersedia"* padahal videonya nanti membawa koordinat.

⚠️ Ini **pratinjau**, bukan yang direkam. Yang tergambar di berkas tetap
dibakar FFmpeg sesudah rekaman ditutup. Bila keduanya berbeda, yang salah
adalah tata letak widget-nya — isinya sama-sama dari `buildLines`.

### L.12 Tombol Berhenti tidak pernah tergambar

**Dilaporkan Product Owner 17 Agustus 2026, terlihat di perangkat.**

Selama merekam, tombol Berhenti **tidak muncul sama sekali** — di mode barcode
maupun manual. Perekaman selama ini berhenti dengan cara lain: batas 30 detik
di mode manual, pemindaian ulang di mode pindai. Karena keduanya bekerja,
hilangnya tombol ini tidak pernah tertangkap.

Yang membuatnya membingungkan: syaratnya `showStopButton => isRecording`, dan
**tiga hal lain yang dihidupkan syarat yang sama persis tetap tampil** — titik
merah, penghitung durasi, dan hitung mundur. Di mode barcode, tombol senter
yang berada di `Row` yang **sama** juga tampil. Jadi baris bawahnya jelas
tergambar; hanya tombolnya yang tidak.

Bukti paling terang datang dari mode manual: di sana senternya memang tidak
ada, sehingga seluruh baris bawah kosong melompong.

🔴 **Sebabnya tidak pernah ditemukan dari membaca kode**, dan tidak layak
menghabiskan putaran build untuk menebaknya. Tombolnya dikeluarkan dari `Row`
berisi dua `Spacer` di `_BottomBar` dan dijadikan lapisan sendiri
(`_StopButtonOverlay`) langsung di `Stack`, paling akhir supaya berada di atas
segalanya dan tetap dapat ditekan.

Ikut ditanam satu jejak diagnosis yang **jangan dihapus**:

```
KAMELSCAN_UI tombol Berhenti tampil=<true|false>
```

Dicetak hanya saat nilainya berubah, bukan lima kali per detik. Bila tombolnya
kelak hilang lagi, baris itulah yang membedakan *"layar tidak menganggap
dirinya sedang merekam"* dari *"sedang merekam tetapi tombolnya tidak
tergambar"* — dua sebab yang sangat berbeda dan tidak dapat dibedakan dengan
mata.

⚠️ Jangan mengembalikan tombolnya ke dalam `_BottomBar`.

**Terbukti muncul** setelah dipindahkan (Redmi Note 9, 17 Agustus 2026). Bentuk
pertamanya melebar dengan tulisan *"Berhenti"* dan memakan hampir seluruh lebar
layar — menutupi pandangan ke meja packing. Atas permintaan Product Owner
diganti **bulat seperti tombol rana kamera**, diameter 76 dp, ikon kotak
berhenti di tengah dan cincin putih di tepinya.

Cincin dan ikonnya bukan hiasan: tulisannya sudah dilepas, jadi §0 palet
menuntut ada pembeda selain warna merah.

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

---

## M. Bab 9: UI/UX aplikasi mobile

**Dikerjakan mulai 18 Agustus 2026.**

### M.1 Kartu Beranda dihitung per periode dompet, bukan per bulan kalender

**Keputusan Product Owner 18 Agustus 2026,** diambil setelah melihat angkanya
pada data sungguhan.

Contoh SQL di Bab 9.2 menghitung video sejak `date_trunc('month', now())`. Itu
benar untuk pelanggan berbayar yang kuotanya di-reset tiap bulan, dan salah
selama masa uji coba: jatah 100 video **tidak pernah** di-reset (`period_end`
NULL, Bab 7.5). Dibuktikan pada tenant `0b5ae403…` — 27 video, seluruhnya
17 Agustus 2026 — dengan mengandaikan hari ini 1 September:

| Cara hitung | Kartu Video | Kartu Token |
|---|---|---|
| bulan kalender (contoh panduan) | **0** | 73 / 100 |
| sejak `token_wallets.period_start` | **27** | 73 / 100 |

Baris pertama menaruh *"belum merekam apa pun"* tepat di sebelah *"27 kupon
sudah habis"*. Dua kartu bersebelahan yang saling membantah, tanpa satu pun
keterangan di layar yang menjelaskannya.

Pemilihannya bukan soal ketelitian melainkan soal **pertanyaan apa yang dijawab
kartu itu**. Product Owner memilih *"jatah saya tinggal berapa"*, karena itulah
yang dilihat sambil bekerja. Pertanyaan *"bulan ini berapa paket dikirim dan
di-return"* tetap dijawab — di **grafik dashboard web** (Bab 10.4,
`get_daily_stats`), yang memang punya pemilih rentang 7/30/90 hari.

🔴 Jangan menggabungkan keduanya ke satu kartu. Itu persis yang membuat
angkanya saling membantah.

Kartu juga membawa keterangan *"sejak 13 Agu"*. Tanpa itu angkanya benar tetapi
pembacanya menduga "bulan ini", dan dugaan itu salah.

### M.2 `get_home_stats()` tunduk RLS — bukan `security definer`

Contoh di Bab 9.2 memakai `security definer`, yang menembus RLS. Dengan itu,
packer melihat jumlah video **seluruh tenant** di Beranda — padahal Bab 2.2
catatan 3 sudah menutup Riwayatnya (`shop_history_visible_to_packer` bawaannya
`false`, dan memang `false` di seluruh tenant saat ini). Menutup satu layar lalu
membocorkan hitungannya di layar sebelah bukan penjagaan.

Diuji dengan klaim JWT sungguhan (`set role authenticated` +
`set_config('request.jwt.claims', …)`), 18 Agustus 2026:

| Sebagai | Hasil | |
|---|---|---|
| Owner "Sarang sarung" | 27 packing · saldo 73/100 | ✅ 27 + 73 = 100 |
| Owner "Toko Uji" | 1 packing · saldo 99/100 | ✅ tidak melihat tenant sebelah |
| Packer, **bukan** perekamnya | **0** packing | ✅ tidak menembus RLS |
| Packer, perekamnya sendiri | 27 packing | ✅ tidak asal memblokir |
| Tamu (`anon`) | ditolak `42501` | ✅ bukan diam-diam 0 |

Baris ketiga akan keluar **27** bila `security definer` dipakai.

⚠️ Menguji lewat koneksi `postgres` biasa tidak membuktikan apa pun — peran itu
mengabaikan RLS dan akan selalu lulus.

### M.3 🔴 Publikasi `supabase_realtime` KOSONG — Realtime tidak pernah hidup

> **Terselesaikan 18 Agustus 2026.** Sesudah kedua tabel didaftarkan, Realtime
> terbukti mengirim perubahannya ke perangkat — buktinya di M.7.

**Temuan 18 Agustus 2026, dan akibatnya mundur sampai Bab 7.**

```
select * from pg_publication_tables where pubname = 'supabase_realtime';
→ 0 baris
```

PostgreSQL hanya mengalirkan perubahan untuk tabel yang terdaftar di publikasi.
Tanpa baris di sana, Realtime **tidak mengirim apa pun** — dan yang membuatnya
mahal: langganannya "berhasil", tidak ada error, tidak ada peringatan, lalu
diam selamanya. Kerabat dekat jebakan 4 (Auth Hook mati → semua tabel
mengembalikan nol baris tanpa pesan).

⚠️ **Ini bukan hanya soal Bab 9.2.** `TokenRepository.watchWallet` sudah ada
sejak Bab 7 dan dipakai `tokenWalletStreamProvider` supaya indikator token ikut
berubah saat packer lain menyelesaikan unggahan. Fitur itu tidak pernah bekerja,
dan tidak ada yang menyadarinya karena tidak ada gejalanya.

Diperbaiki di migrasi `21_realtime_publication.sql`, yang mendaftarkan dua tabel
saja — daftarnya dijaga sempit, bukan "semua tabel supaya aman":

- `token_wallets` — bergerak setiap kali video **berhasil** diunggah, karena
  trigger `after_video_uploaded` memotong satu token. Jalur paling andal, dan
  policy-nya sederhana sehingga pemeriksaan RLS per pelanggan Realtime ringan.
- `package_videos` — untuk perubahan yang tidak menyentuh dompet: unggahan
  gagal, dan video yang dihapus Owner.

🔴 **Belum diuji di perangkat.** Policy `videos_select` memuat sub-kueri
`exists` yang tidak sederhana, dan Realtime memeriksa policy per pelanggan.
Bila kelak kartu tidak ikut bergerak untuk packer, di situlah tempat pertama
yang harus dilihat. Jejak yang menjawabnya sudah ditanam:

```
adb logcat -v time | findstr KAMELSCAN_HOME
```

Sesuai aturan L.9, **jalur gagalnya ikut dicetak**, bukan hanya yang berhasil —
sehingga *"isyaratnya tidak pernah datang"* dapat dibedakan dari *"isyaratnya
datang tetapi angkanya gagal diambil"*.

### M.4 Tipe `return` tidak pernah dapat direkam — diperbaiki

**Temuan 18 Agustus 2026, diperbaiki hari yang sama atas keputusan Product
Owner.**

Bab 9.2 meminta dua menu perekaman, tetapi seluruh alur rekam memaku
`VideoType.packing` — tiga tempat di `recording_camera_view_model.dart`, dan
tidak ada satu pun jalan yang menghasilkan video bertipe `return`. Layar setup
pun tidak punya pilihannya.

**Kenapa ini bukan sekadar label yang keliru.** Indeks unik
`uq_resi_per_tenant_type` memisahkan kedua tipe justru supaya satu resi boleh
direkam sekali saat packing dan sekali lagi saat paketnya kembali (Bab 7.7).
Video return yang tersimpan sebagai packing menabrak baris packing-nya sendiri,
dan packer ditolak *"resi sudah pernah direkam"* pada paket yang belum pernah ia
rekam sebagai return. Dibuktikan langsung di database, di dalam transaksi yang
di-rollback:

```
resi sama + tipe berbeda  → DITERIMA (packing + return)
resi sama + tipe sama     → 23505 duplicate key … uq_resi_per_tenant_type
```

**Yang diubah** — tipe mengalir dari menu sampai ke baris `package_videos`:

```
Beranda → Routes.recordSetupOf(type)
        → RecordingSetupPage(typeWire)      ← pilihan dapat diganti di layar
        → Routes.recordCameraOf(type)
        → RecordingCameraViewModel(_type)   ← 3 pemakaian, termasuk resiExists
        → UploadTask.type → package_videos.type
```

Tipe dibawa di **query rute**, bukan `extra`, dengan alasan yang sama seperti
tiga pilihan lainnya: rute yang dipulihkan setelah aplikasi di-restart tidak
boleh diam-diam kembali ke packing.

⚠️ Yang mudah terlewat saat menambah parameter ini: `_RecordingScope` di
`recording_camera_page.dart` **ikut** membawa seluruh argumen keluarga. Satu
saja tertinggal, widget anak membaca instance ViewModel yang berbeda — tombolnya
tampak normal tetapi tidak melakukan apa pun. Peringatan itu memang sudah
tertulis di kepala kelasnya.

**Pilihan tipe TIDAK disimpan ke `SharedPreferences`,** berbeda dari mode pemicu
dan toko. Keduanya sama sepanjang hari; tipe berganti per paket. Mengingat
pilihan terakhir justru berbahaya: packer yang merekam satu paket return kemarin
akan menemukan layarnya masih di posisi Return hari ini, dan seluruh rekaman
packing-nya masuk dengan tipe yang salah.

Pemilihnya berdiri sebagai **bagian nomor 1** di layar setup, di atas kamera —
ia keputusan yang paling mahal bila keliru. Penomoran tiga bagian lama bergeser
menjadi 2, 3, 4.

🔴 **Belum diuji di perangkat.** Yang terbukti baru sisi database dan
`flutter test`.

### M.6 Bilah atas kerangka mobile (Bab 9.1)

Bab 9.1 mensyaratkan bilah atas 72 dp, tetapi kerangka yang ada sama sekali
tidak memilikinya — `MobileShell` hanya `body` + `bottomNavigationBar`. Diisi
18 Agustus 2026: foto profil 44 dp (inisial di atas warna hasil hash `user_id`
bila `avatar_url` kosong), ucapan menurut jam, nama, dan lencana peran beserta
nama usaha.

Ambang ucapannya ditaruh di `core/domain/greeting.dart` — murni Dart, teruji
tanpa perangkat. Alasannya: angka batas seperti 00–10 / 11–14 / 15–18 / 19–23
mudah tergeser satu jam, dan salahnya **hanya muncul pada jam tertentu** — jenis
cacat yang tidak akan pernah tertangkap saat mencoba aplikasi di siang hari.

Ini satu-satunya tempat jam HP boleh dipakai apa adanya: sapaan memang harus
mengikuti pagi-sore yang sedang dialami penggunanya. Bandingkan dengan watermark,
yang justru tidak boleh menyentuh jam perangkat sama sekali (L.1).

**Lonceng notifikasi diganti indikator antrian unggah**, persis seperti yang
diinstruksikan Bab 9.1 bila loncengnya belum punya isi. Lonceng kosong yang
tidak pernah berbunyi hanya melatih pengguna untuk mengabaikannya.

Warna lencana peran (Admin ungu, Owner biru, Packer hijau) meminjam warna
semantik palet yang sudah ada — tidak ada `Color(0xFF…)` baru yang ditulis di
widget (§6 palet), sehingga mode gelapnya ikut benar dengan sendirinya. Titik
berwarnanya selalu ditemani tulisan perannya (§0 palet).

### M.5 Antrian di Beranda dibaca dari perangkat, bukan dari server

Spanduk *"4 video menunggu diunggah"* memakai `pendingUploadCountProvider`
(antrian lokal), **bukan** `pending_upload` dari `get_home_stats()`.

Alasannya L.5: baris `package_videos` baru dibuat **saat mengunggah**, jadi
video yang direkam di gudang tanpa sinyal belum punya baris di server sama
sekali — padahal justru itu yang paling perlu diberitahukan. Kolomnya tetap
dikembalikan RPC dan tercatat di model beserta peringatan ini, supaya tidak ada
yang memakainya untuk spanduk itu di kemudian hari.

### M.7 Hasil uji perangkat 18 Agustus 2026 — Redmi Note 9

Uji pertama Bab 9 di perangkat sungguhan. Tiga temuan Product Owner.

**1. Kartu ketiga di luar layar.** Ketiga kartu pantauan digulir mendatar dengan
lebar tetap 200 dp, persis seperti bunyi Bab 9.2 — dan akibatnya saldo token
berada di luar layar. Angka yang paling sering dicari justru satu-satunya yang
harus dicari.

Bab 9.2 menyebut "dapat digulir horizontal" sebagai **bentuk**, bukan tujuan.
Tujuannya ketiga angka terlihat; menggulir hanya jalan keluar bila tidak muat.
Sekarang ketiganya berbagi lebar layar dan tidak digulir sama sekali.

Ikut berubah: keterangan periode (*"sejak 13 Agu 2026"*) dipindahkan dari tiap
kartu ke satu baris di samping judul **Pantauan**. Ia menerangkan ketiga angka
sekaligus, dan pada lebar sepertiga layar pengulangannya memakan ruang yang
dibutuhkan angkanya sendiri. Keterangan itu sendiri tetap wajib ada (M.1).

Angka memakai `FittedBox`: tenant sibuk bisa menembus empat digit, dan angka
bukti yang terpotong lebih buruk daripada angka yang mengecil.

**2. 🔴 Realtime TIDAK memicu penyegaran.** Video return terekam, angkanya
benar, tetapi baru muncul setelah halaman dimuat ulang dengan tangan. Ini
membuktikan yang sudah ditandai sebagai belum teruji di M.3: mendaftarkan tabel
ke publikasi ternyata **belum cukup**.

Sebabnya belum diketahui, dan tidak layak ditebak. Dua langkah diambil:

- **Jejak diagnosis dilengkapi.** `subscribe()` kini mencetak statusnya, karena
  tanpa itu langganan yang ditolak Realtime tampak persis sama dengan langganan
  sehat yang kebetulan belum ada perubahannya — dua-duanya diam.

  ```
  adb logcat -v time | findstr KAMELSCAN_HOME
  ```

  `status=subscribed` tanpa baris `isyarat` → channel sehat, servernya yang
  tidak mengirim (periksa publikasi & RLS Realtime). `status=channelError` →
  langganannya sendiri yang ditolak, dan pesannya ikut tercetak.

- **Jaring pengaman yang tidak bergantung Realtime.** `HomeViewModel` kini juga
  mendengarkan **antrian lokal**: saat jumlahnya berkurang, sebuah video baru
  saja selesai terkirim, dan itulah saat angka di server berubah. Sumbernya
  SQLite di perangkat — tidak melibatkan jaringan sama sekali, jadi ia bekerja
  walaupun Realtime tetap bermasalah.

  Kenaikan sengaja diabaikan: video yang baru direkam belum menambah apa pun di
  server (L.5).

**3. Jenis paket ditentukan menu, bukan dipilih ulang** — lihat M.8.

#### Uji lanjutan 18 Agustus 2026 — sesudah ketiga perbaikan

Product Owner melaporkan: **ketiga kartu muat tanpa digeser**, dan **angkanya
berubah sendiri tanpa dimuat ulang.**

**Realtime TERBUKTI HIDUP.** Angka yang bergerak dapat datang dari dua jalur
yang dari luar tampak sama — Realtime dari server, atau jaring pengaman antrian
lokal — jadi keduanya dipisahkan lewat logcat, bukan disimpulkan dari layar.

Dugaan awal keliru dan dicatat di sini supaya tidak diulang: karena publikasi
`supabase_realtime` sudah terdaftar sejak build pertama (yang saat itu tidak
bergerak), sempat disimpulkan bahwa Realtime masih diam dan hanya jaring
pengaman yang bekerja. Logcat membantahnya.

**Bukti 1 — dipicu dari luar aplikasi.** Satu `update` pada `token_wallets`
dijalankan langsung dari `bin/sql.dart` (hanya stempel waktu; saldo tidak
disentuh). Aplikasi bereaksi pada detik yang sama, tanpa ada yang menyentuh HP:

```
15:34:06 UTC  update token_wallets … (dari laptop)
22:34:06 WIB  KAMELSCAN_HOME isyarat · token_wallets/update
```

Ini sekaligus membuktikan keadaan yang tidak dapat ditiru jaring pengaman:
perubahan berasal dari luar perangkat, dan antrian lokal sama sekali tidak
bergerak.

**Bukti 2 — satu perekaman utuh, kedua jalur terlihat berdampingan:**

```
15:21:41  KAMELSCAN_HOME langganan status=subscribed
15:23:52  KAMELSCAN_HOME isyarat · package_videos/insert      ← Realtime
15:23:57  KAMELSCAN_PIPA Terunggah · resi=6896RTI
15:23:57  KAMELSCAN_HOME antrian 1 → 0 · menyegarkan          ← jaring pengaman
15:23:57  KAMELSCAN_HOME isyarat · package_videos/update      ← Realtime
15:23:57  KAMELSCAN_HOME isyarat · token_wallets/update       ← Realtime
15:23:58  KAMELSCAN_HOME segar · packing=28 retur=3 token=69
```

Empat isyarat dalam 400 ms menghasilkan **satu** pemuatan ulang — jeda 600 ms
di `_scheduleRefresh` bekerja seperti yang dimaksudkan. Tanpa itu, perekaman
beruntun akan memanggil RPC belasan kali beruntun.

Jaring pengaman tetap dipertahankan meski Realtime terbukti hidup. Ia menutup
keadaan yang berbeda: perangkat yang kehilangan sambungan WebSocket sementara
tetap mengetahui videonya sendiri sudah terkirim. Keduanya murah dan tidak
saling mengganggu — bukti di atas memperlihatkan keduanya berbunyi berdampingan
tanpa menghasilkan pemuatan ganda.

**Ikut terbukti pada jejak yang sama** — jenis paket mengalir utuh lewat rute:

```
GoRouter: pushing /record?type=packing
GoRouter: pushing /record/camera?camera=0&mode=manual&shop=…&type=packing&shop_name=…
```

Sisi database diperiksa dan seluruhnya benar:

| Tabel | Terdaftar di publikasi | RLS | Replica identity |
|---|---|---|---|
| `package_videos` | ✅ | aktif | default (primary key) |
| `token_wallets` | ✅ | aktif | default (primary key) |

⚠️ **Jejak `KAMELSCAN_*` sampai ke logcat lewat breadcrumb Sentry**, bukan
sebagai baris `I/flutter`. Mencarinya dengan `findstr flutter` akan
mengembalikan kosong dan tampak seperti jejaknya tidak ada. Cari kata kuncinya
langsung:

```
adb logcat -v time | findstr KAMELSCAN_HOME
```

### M.8 Jenis paket punya satu sumber: menu yang ditekan

**Keputusan Product Owner 18 Agustus 2026, `arahan.json`.**

```
menu rekam_paket_packing → masuk: packing, keluar: none
menu rekam_paket_return  → masuk: return,  keluar: none
selain itu               → none (tidak ada perekaman)
```

Pemilih *"Pilih jenis paket"* yang sempat berdiri sebagai bagian 1 di layar
setup **dicabut**. Alasannya sama dengan alasan `buildLines` hanya boleh punya
satu penyusun (L.11): dua sumber kebenaran untuk satu hal akan menyimpang.
Packer yang menekan "Rekam Paket Return" lalu menemukan chip Packing masih
dapat dipilih akan wajar mengira menu tadi belum berlaku.

Sebagai gantinya, **judul layar menyatakan jenisnya** — *"Perekaman packing"*
atau *"Perekaman return"*. Penomoran tiga pilihan yang tersisa kembali ke
1, 2, 3.

*"Keluar → none"* tidak memerlukan kode khusus: providernya dibuang begitu
layarnya ditutup, jadi jenisnya memang tidak bertahan ke mana pun. Ia juga
tidak pernah disimpan ke `SharedPreferences`.

🔴 **Tombol Rekam mengambang ikut berubah.** Ia tidak berangkat dari salah satu
menu, jadi jenisnya belum ditentukan — dan aturan `else → none` melarangnya
merekam begitu saja. Ia kini menanyakan jenis lebih dulu lewat lembar pilihan.

Tanpa perubahan itu, mencabut pemilih di layar setup justru membuka lubang yang
lebih buruk daripada sebelumnya: tombol itu akan diam-diam merekam **segalanya**
sebagai packing, termasuk paket return, tanpa satu pun tempat untuk
membetulkannya.

### M.9 Riwayat (Bab 9.4) dan utang Bab 8.8

**Dikerjakan 18 Agustus 2026.** Tata letaknya mengikuti acuan tangkapan layar
yang diberikan Product Owner: judul, chip jenis, kolom pencarian, kartu daftar,
lalu halaman detail berisi pemutar, tombol unduh, kartu metadata berpasangan
label–nilai, dan tombol hapus.

#### Edge Function `get-video-url` — dibuat dari nol

`VideoRepository.getPlaybackUrl` sudah ada di kode sejak Bab 8, tetapi fungsi
yang dipanggilnya **belum pernah dibuat**; menekan tombol putar sebelum ini
pasti gagal.

🔴 **RLS tidak berlaku di dalamnya.** Fungsi ini memakai service role, jadi
seluruh aturan siapa-boleh-melihat-apa ditulis ulang dengan tangan dan harus
tetap sejalan dengan policy `videos_select` di `14_rls.sql`. Bila policy itu
kelak diubah, berkas ini wajib ikut diubah — tidak ada yang mengingatkan.

Yang ditegakkan di sana:

| Aturan | Alasan |
|---|---|
| `app_role = 'admin'` **ditolak** | Bab 2.2 catatan 5. Admin boleh melihat metadata pelanggan, bukan isi videonya: rekaman gudang memuat wajah pegawai, tata letak, dan barang yang dikirim. Penolakannya berdiri di server, bukan di aplikasi, karena aplikasi dapat diganti sedangkan Edge Function tidak. |
| Langganan tidak aktif → `402` | Bab 7.6 — riwayat tetap terbaca, isi videonya terkunci sampai diperpanjang. |
| Packer di luar cakupannya → `403` | Cerminan `videos_select`: rekamannya sendiri, atau se-toko bila `shop_history_visible_to_packer` menyala **dan** ia memang ditugaskan ke toko itu. |
| Status bukan `uploaded` → `409` / `410` | Dibedakan dari `404`: barisnya ada, isinya yang tidak. "Belum terkirim" dan "sudah dihapus sesuai retensi" adalah dua kalimat yang berbeda bagi penggunanya. |

**Hasil uji penolakan 18 Agustus 2026** (jalur sukses belum diuji — perlu JWT
pengguna sungguhan dari aplikasi):

```
tanpa header Authorization   → 401
sebagai tamu (anon key)      → 401 UNAUTHORIZED
metode GET                   → 405 METHOD_NOT_ALLOWED
```

⚠️ Satu URL melayani dua keperluan yang perlakuannya berbeda, jadi permintaan
membawa penanda `download`. Untuk **menonton**, berkas disajikan `inline` agar
pemutar dapat melompat ke tengah video; untuk **mengunduh**, ia diberi
`attachment` bernama nomor resi. Menyatukan keduanya sebagai `attachment` akan
membuat halaman publik Bab 10.6 mengunduh berkas alih-alih memutarnya.

#### Nama toko dan perekam diambil lewat embedding, bukan per baris

`fetchHistory` memakai embedding PostgREST (`shops`, `users`) dalam satu
permintaan. Alternatifnya 20 permintaan tambahan per halaman, dan pada jaringan
gudang itu terasa seperti aplikasi yang menggantung.

Embedding tetap tunduk RLS. `shops_select` dan `users_select_self_or_tenant`
sama-sama mengizinkan seluruh anggota tenant membacanya, jadi namanya terisi
untuk packer maupun Owner. ⚠️ Bila policy itu kelak diperketat, yang muncul
**bukan error melainkan nama yang kosong** — periksa ke sana lebih dulu sebelum
menduga masalahnya di Dart. `HistoryItem` sengaja dipisah dari `PackageVideo`
supaya kolom hasil join tidak ikut terbawa ke jalur unggah.

#### Tiga keputusan yang menyimpang dari acuan Product Owner

1. **Logo marketplace diganti huruf awal berwarna.** Berkas logonya belum ada
   di repo, dan logo Shopee/Tokopedia adalah merek dagang pihak lain yang
   pemakaiannya perlu diputuskan lebih dulu. Warnanya diambil dari palet, bukan
   warna merek aslinya, agar mode gelap tetap terbaca (§6 palet).

2. **Tombol unduh membuka lembar Bagikan** sesudah berkasnya turun, dan
   berkasnya disimpan di direktori dokumen aplikasi. Menulis ke folder Unduhan
   bersama pada Android modern menuntut izin penyimpanan tambahan, sedangkan
   pemakaian nyatanya hampir selalu meneruskan berkas itu ke pusat resolusi
   marketplace lewat aplikasi pesan.

3. **Pemutar tidak memuat video sampai ditekan** — disetujui Product Owner
   18 Agustus 2026. Acuan menampilkan pemutar yang langsung siap; di sini yang
   tampil bidang gelap dengan tombol putar. Packer membuka halaman detail
   terutama untuk membaca nomor resi dan waktunya saat menjawab komplain, dan
   di gudang yang hanya punya sinyal seluler, menarik berkas 1 MB setiap kali
   halaman dibuka akan membakar kuota data mereka tanpa videonya pernah
   ditonton.

#### Ditambahkan di luar acuan karena Bab 9.4 mewajibkannya

**Sisa retensi** — *"Video akan dihapus otomatis dalam 18 hari"*. Acuan tidak
memilikinya. Pelanggan yang tidak tahu videonya akan terhapus tidak akan pernah
menyimpan salinannya, dan baru menyadarinya saat sengketa terjadi.

Kondisi kosong dibedakan menjadi dua: belum pernah merekam apa pun, atau
pencariannya yang tidak menemukan. Menyamakan keduanya membuat orang mengira
datanya hilang.

#### Belum dikerjakan

- Edge Function `create-public-link` dan halaman publik `/v/{token}`
  (Bab 10.6). Karena keduanya belum ada, tombol **Salin Tautan** dan
  **Bagikan tautan** sengaja **tidak dipasang** — pelajaran dari menu Rekam
  Return (M.4): tombol yang gagal saat ditekan lebih buruk daripada tombol yang
  belum ada.
- Tombol saringan lanjutan dan pindai QR pada baris pencarian, keduanya ada di
  acuan.
- Tombol *Coba unggah lagi* pada video berstatus `failed`.

#### Hasil uji perangkat 19 Agustus 2026 — Redmi Note 9

Dilaporkan Product Owner: **daftar riwayat muncul, penyaringan bekerja, video
dapat diputar dan diunduh.** Dengan itu rantai Bab 8.8 terbukti utuh dari
tombol di layar sampai berkas di R2 — termasuk `get-video-url`, yang jalur
suksesnya sebelumnya belum pernah teruji.

Permintaan yang menyusul dari uji itu: tombol **Unduh dipendekkan** dan
**Tautan Publik** ditaruh di sebelah kanannya (lihat M.10).

### M.10 Tautan bukti publik — Bab 8.8 tuntas, kecuali tempat menaruhnya

**Dikerjakan 19 Agustus 2026**, atas permintaan Product Owner sesudah uji
Riwayat: *"untuk ke tautan publik taruh di sebelah kanan download, button
download dipendekan lagi."*

Yang ternyata ikut harus dibuat: halaman `/v/{token}` **belum terdaftar di
router sama sekali** — yang ada baru konstanta alamatnya di `route_names.dart`.
Tautan tanpa halaman adalah tautan mati, jadi tombolnya tidak dapat berdiri
sendiri.

#### Dua Edge Function baru

**`create-public-link`** — hanya Owner (Bab 2.2). Admin platform pun ditolak:
ia tidak berhak menyebarkan isi video pelanggan, sama seperti pada
`get-video-url`.

🔴 **Idempoten, dan itu bukan kerapian.** Tautan yang masih berlaku dipakai
ulang alih-alih diterbitkan baru. Menerbitkan token baru tiap kali tombolnya
ditekan akan mematikan tautan yang sudah terkirim ke pusat resolusi
marketplace — persis pada saat sengketanya sedang diperiksa.

Masa berlaku tautan mengikuti `expires_at` videonya, bukan umur tersendiri:
tautan yang hidup lebih lama daripada berkasnya membuka halaman kosong, yang
lebih pendek memutus bukti sebelum waktunya.

Tokennya 32 karakter dari alfabet 31 huruf (tanpa huruf yang mudah tertukar) =
± 160 bit, dibangkitkan `crypto.getRandomValues` — **bukan** `Math.random()`.
Token ini satu-satunya penjaga video yang dapat dibuka tanpa login; angka acak
yang dapat ditebak berarti bukti pelanggan dapat dijelajahi orang luar.

**`get-public-video`** — satu-satunya Edge Function di proyek ini yang sengaja
**tidak** memeriksa sesi. Yang dikembalikan dibatasi seketat mungkin:
`tenant_id`, `user_id`, `shop_id`, dan `storage_key` tidak pernah ikut keluar.
Dari id itu orang luar dapat menyusun peta pelanggan, sedangkan untuk memeriksa
sengketa mereka hanya butuh isi buktinya.

Token yang tidak dikenal dan token yang sudah mati sama-sama dijawab tanpa
menyebut mana yang mana — membedakannya akan memberi tahu penebak bahwa
tokennya pernah benar.

#### Hasil uji 19 Agustus 2026

Halaman publik dapat diuji penuh tanpa perangkat maupun akun, justru karena ia
memang tidak memerlukan login:

| Yang diuji | Hasil |
|---|---|
| Buka tautan berlaku, tanpa login | ✅ metadata lengkap + URL video |
| Kolom sensitif ikut keluar? | ✅ **tidak ada** — diperiksa satu per satu |
| Berkas video di R2 | ✅ `206 Partial Content`, `video/mp4`, `inline` |
| Tautan kedaluwarsa | ✅ `410 LINK_EXPIRED` |
| Token asal-asalan | ✅ `400` — ditolak sebelum menyentuh database |
| Token 32 huruf tapi tidak dikenal | ✅ `404` |
| `create-public-link` sebagai tamu | ✅ `401` |

`206 Partial Content` membuktikan pemutar dapat melompat ke tengah video, dan
`inline` membuktikan pemisahan tonton/unduh pada `get-video-url` bekerja
sebagaimana dirancang.

⚠️ Data uji dibuat langsung di database lalu **dibersihkan**: 0 tautan publik
tersisa, saldo token tidak tersentuh.

🔴 Belum teruji: **jalur sukses `create-public-link`** — perlu JWT Owner, jadi
hanya dapat diuji dari aplikasi.

#### 🔴 Tautannya belum dapat dibuka siapa pun — dan sebabnya bukan kode

Tautan berbentuk `https://kamelscan.com/v/{token}`. Diperiksa 19 Agustus 2026:

```
kamelscan.com        → tidak ada A record
www.kamelscan.com    → tidak ditemukan
membuka halamannya   → tidak ada jawaban
```

Domainnya **sudah dibeli** Product Owner; yang belum ada adalah aplikasi web di
belakangnya dan pengarahan DNS ke sana. Tidak diperlukan domain kedua — yang
kurang isinya, bukan namanya.

**Keputusan Product Owner 19 Agustus 2026: ditunda sampai Bab 10.** Alasannya
membangun dan mengunggah aplikasi web memang lingkup Bab 10, dan menariknya ke
Bab 9 akan menambah ± 2–3 jam pada penyangga yang sudah minus ± 10 jam.

Tidak ada pekerjaan yang terbuang oleh penundaan itu: tombolnya berfungsi,
tokennya tersimpan benar, dan halaman `/v/{token}` sudah jadi — ia hanya belum
punya alamat yang dapat dijangkau orang luar. Basis alamatnya sendiri dibaca
dari env `PUBLIC_BASE_URL` di Edge Function, jadi domainnya dapat diganti
**tanpa merilis ulang aplikasi**.

⚠️ Sampai Bab 10 selesai, jangan menyarankan Product Owner mengirim tautan ini
ke pusat resolusi marketplace — yang terbuka di sana halaman kosong, bukan
buktinya.

#### Tata letak tombol

Unduh dan Tautan Publik berbagi satu baris, masing-masing setengah lebar.
Tautan Publik hanya tampil untuk Owner; bagi packer, Unduh kembali memakai
lebar penuh supaya tidak ada ruang kosong yang tidak dapat dijelaskan.

Menekan Tautan Publik menyalin alamatnya ke papan klip dan menyebut **sampai
kapan tautan itu berlaku** (Bab 9.4). Masa berlaku disebut di muka, bukan
disembunyikan: pusat resolusi marketplace kadang baru membukanya beberapa hari
kemudian, dan Owner perlu tahu itu **sebelum** mengirimkannya.

### M.11 Halaman Toko (Bab 9.5)

**Dikerjakan 19 Agustus 2026.** Halaman ini menghalangi pekerjaan lain bila
kosong: perekaman tidak dapat dimulai tanpa toko, sehingga pelanggan baru
langsung buntu di layar setup.

#### Jumlah video diambil sekali jalan — tanpa migrasi baru

Daftar toko menampilkan jumlah video tiap toko lewat **agregat bersarang
PostgREST** dalam permintaan yang sama:

```
select=*,package_videos(count)
```

Sintaksnya diuji lebih dulu langsung ke server sebelum kode ditulis di atasnya,
dan terbukti didukung. Alternatifnya satu permintaan `count` per toko — pada
Owner dengan belasan toko itu belasan perjalanan bolak-balik hanya untuk mengisi
satu baris angka.

⚠️ Bentuk yang dikembalikan tidak biasa: **daftar berisi satu objek**, bukan
angka.

```json
"package_videos": [ { "count": 12 } ]
```

Salah membacanya membuat setiap toko tampak belum pernah dipakai — dan itu
berbahaya, karena angka inilah yang menentukan tombol Hapus dijalankan atau
ditolak. Karena itu pembacaannya dikunci tes (`shop_summary_test.dart`).

#### Jumlah yang dihitung adalah SELURUH video, termasuk yang dihapus

Menyimpang dari Bab 9.5 yang menulis "jumlah video bulan ini", dan berbeda pula
dari kartu Beranda yang memakai periode dompet (M.1). Alasannya angka ini
menjawab pertanyaan yang berbeda: **apakah toko ini dapat dihapus.**

`package_videos.shop_id` memakai `on delete restrict`, dan yang menghalangi
penghapusan adalah **adanya baris** — bukan status maupun tanggalnya. Angka yang
menghitung lebih sedikit akan menjanjikan toko dapat dihapus padahal server
menolaknya.

#### Penolakan hapus yang menawarkan jalan keluar

Toko yang punya video tidak dapat dihapus, dan itu disengaja sejak Bab 5.2:
video terikat pada toko tempat perekaman terjadi, jadi menghapus tokonya memutus
rantai bukti. Yang ditampilkan bukan pesan error melainkan tawaran:

> *"Toko ini memiliki 27 video. Nonaktifkan toko alih-alih menghapusnya — video
> lamanya tetap tersimpan dan tetap dapat dibuka."*

beserta tombol **Nonaktifkan** yang langsung melakukannya.

🔴 Toko yang tidak dapat dihapus **tidak** ditanyai "yakin ingin menghapus?"
lebih dulu. Menanyakan lalu menolak sesudah ditekan adalah cara tercepat membuat
orang mengira aplikasinya rusak.

`23503` dari server tetap ditangani sebagai penolakan yang sama, bukan error tak
dikenal: daftar di layar bisa tertinggal beberapa detik bila packer lain baru
saja merekam.

`23505` (`uq_shop_per_tenant`) juga diberi kalimatnya sendiri — Owner yang
mengetik nama yang sudah ada berhak tahu sebabnya, bukan menerima "terjadi
kesalahan".

#### Dua penyimpangan dari Bab 9.5

1. **Tombol Tambah Toko bukan tombol mengambang.** Sudut kanan bawah sudah
   ditempati tombol Rekam milik kerangka layar (Bab 9.1); menumpuk dua tombol
   mengambang di titik yang sama membuat keduanya sulit ditekan tepat.

2. **Menu tiga titik menggantikan geser-ke-kiri** untuk Edit / Nonaktifkan /
   Hapus. Gestur geser tidak meninggalkan petunjuk apa pun di layar, dan di
   gudang yang sering dioperasikan dengan sarung tangan, sasaran sentuh 48 dp
   yang terlihat jauh lebih dapat diandalkan daripada gerakan yang harus ditebak
   (Bab 9.10).

#### Hasil uji perangkat 19 Agustus 2026 — Redmi Note 9

Tampilan halaman Toko **baik** setelah perbaikan M.12. Satu cacat ditemukan
Product Owner: sesudah menambah atau mengubah toko, daftarnya **tidak ikut
berubah** sampai ditarik ke bawah.

🔴 Sebabnya salah sasaran `invalidate`:

```dart
ref.invalidate(shopRepositoryProvider);   // tidak melakukan apa-apa yang terlihat
```

Repository **tidak menyimpan state** (Bab 3.1 poin 3) — ia hanya pengambil
data — dan `ShopsViewModel` membacanya dengan `ref.read`, jadi ia tidak pernah
tahu ada yang berubah. Yang harus di-invalidate adalah **ViewModel yang
menyimpan daftarnya**:

```dart
ref.invalidate(shopsViewModelProvider);
ref.invalidate(recordingSetupViewModelProvider);
```

Baris kedua sama pentingnya: layar setup perekaman membaca daftar toko yang
sama. Tanpa itu, toko yang baru dibuat belum muncul bila packer langsung
menekan Rekam — dan pada pelanggan baru, itu persis urutan yang paling mungkin
terjadi.

⚠️ Pola ini berlaku umum di proyek ini: **meng-invalidate repository tidak
menyegarkan layar apa pun.** Sasarannya selalu ViewModel yang memegang
datanya. Terbukti diperbaiki di perangkat pada hari yang sama.

#### Belum dikerjakan

Penugasan packer ke toko (multi-select pada formulir). Ditandai 🟡 TARGET di
Bab 9.5, bukan wajib MVP; tabel `shop_packers` sudah ada sejak `04_shops.sql`.

### M.12 🔴 Jebakan: tombol bertema menuntut lebar TAK TERHINGGA

**Ditemukan 19 Agustus 2026 di Redmi Note 9, dilaporkan Product Owner.**

Gejalanya: judul "Toko Saya" tergambar **menurun satu huruf per baris**, dan
seluruh daftar tokonya tidak terlihat sama sekali.

Sebabnya **bukan** di halaman Toko, melainkan di `app_theme.dart`:

```dart
filledButtonTheme:  minimumSize: const Size.fromHeight(AppSizes.touchComfort)
outlinedButtonTheme: minimumSize: const Size.fromHeight(AppSizes.touchComfort)
```

`Size.fromHeight(52)` sama dengan `Size(double.infinity, 52)` — lebar
minimumnya **tak terhingga**. Itu disengaja dan benar: tombol utama seperti
*Simpan*, *Mulai*, dan *Unduh* memang harus selebar layar.

Yang tidak disengaja adalah akibatnya di dalam `Row`. Tombol itu menuntut
seluruh lebar, dan `Expanded` di sebelahnya tidak kebagian apa pun:

```
BoxConstraints forces an infinite width.
BoxConstraints(w=Infinity, 52.0<=h<=Infinity)
```

⚠️ **Di perangkat tidak muncul pita overflow kuning-hitam sama sekali**, dan
`flutter analyze` tetap bersih. Jadi jangan menunggu peringatan — kenali
gejalanya dari bentuk teksnya.

#### Bentuk mana yang aman

| Bentuk | Aman? |
|---|---|
| `Row( Expanded(teks), FilledButton(...) )` | ❌ runtuh |
| `Row( Expanded(SizedBox(FilledButton)), Expanded(...) )` | ✅ lebar ditentukan induk |
| `Column( teks, FilledButton(...) )` | ✅ tombol memang selebar layar |
| `FilledButton(style: styleFrom(minimumSize: Size(0, 48)))` | ⚠️ tidak runtuh, tetapi hanya menyisakan ± 119 dp untuk teks di sebelahnya pada layar 393 dp |

Halaman Toko memakai bentuk ketiga: judul dan keterangan di atas, tombol selebar
layar di bawahnya. Tombol Unduh + Tautan Publik pada detail video memakai bentuk
kedua, dan karena itu tidak pernah ikut runtuh.

Seluruh `FilledButton`/`OutlinedButton` di `lib/` sudah disisir; tidak ada
pemakaian berisiko lain yang tersisa.

#### 🔴 Pelajaran tentang tes tata letak

Tes pertama yang ditulis untuk mengejar cacat ini memakai **tema bawaan
Flutter** dan **lulus** — sehingga sempat menyimpulkan susunan widget-nya
baik-baik saja dan penyebabnya di tempat lain. Baru setelah `theme: AppTheme.light`
dipasang, cacatnya muncul.

**Tes tata letak yang tidak memakai `AppTheme` tidak membuktikan apa pun tentang
aplikasi ini.** Tes regresinya ada di `test/pages/shops_header_layout_test.dart`,
lengkap dengan kasus bentuk-yang-aman agar keduanya tidak tertukar lagi.

⚠️ Yang diukur di tes itu **tinggi** teks, bukan lebarnya. `Text` di dalam
`Column` menyusut ke lebar tulisannya sendiri, jadi lebarnya tidak memberi tahu
apa pun tentang ruang yang tersedia — sedangkan judul yang menurun satu huruf
per baris tingginya melonjak dari ± 30 dp menjadi ratusan.

### M.13 🔴 Aplikasi menggantung selamanya di layar splash saat jaringan mati

**Ditemukan 19 Agustus 2026 di Redmi Note 9.** Bukan cacat Bab 9 — ia sudah ada
sejak layar splash dibuat, dan baru terlihat ketika jaringan kebetulan mati
tepat pada saat aplikasi dibuka.

Gejalanya: logo KamelScan berputar terus sebelum halaman login. Tidak ada pesan,
tidak ada tombol, dan satu-satunya jalan keluar adalah menutup paksa aplikasi.

#### Log yang menjawabnya

Product Owner menyimpan logcat-nya. Jejak aplikasi berhenti persis di tiga baris
ini dan tidak pernah berlanjut:

```
supabase.supabase_flutter: INFO: ***** Supabase init completed *****
GoRouter: INFO: Using MaterialApp configuration
KAMELSCAN_WAKTU penghitung: sejak HP menyala (elapsedRealtime, boot_id=…)
```

Tidak ada perpindahan rute, dan tidak ada `KAMELSCAN_WAKTU sinkron` — yang
berarti alurnya berhenti **sebelum** sesi selesai dipulihkan.

#### Sebab

`SplashViewModel.build()` menunggu `sessionProvider.future`, dan pemulihan sesi
menembakkan **empat permintaan berturut-turut** ke Supabase: profil pengguna,
tenant, katalog tier, lalu dompet token.

🔴 Klien HTTP-nya tidak punya batas waktu bawaan. Pada jaringan yang **mati di
tengah** — bukan menolak sambungan, melainkan diam — permintaan itu tidak pernah
kembali, dan `await`-nya tidak pernah selesai.

`uploadWorker.requestImmediateRun()` yang ikut di-`await` menambah satu lagi
tempat yang dapat menggantung dengan cara yang sama.

#### Perbaikan

1. **Batas waktu 20 detik** pada pemulihan sesi. Lewat dari itu ia melempar
   `AppFailure.network`. `SplashPage` sudah lama menangani keadaan error dengan
   `AppErrorView` beserta tombol *Coba lagi* — yang selama ini kurang hanyalah
   sesuatu yang mengakhiri penantiannya.

2. 🔴 **Tidak jatuh ke halaman login saat waktu habis.** Sesinya kemungkinan
   besar masih sah; yang gagal jaringannya. Melempar pengguna ke layar masuk
   berarti menyuruhnya mengetik ulang kata sandi untuk masalah yang bukan
   salahnya — dan di gudang tanpa sinyal ia justru tidak akan bisa masuk
   kembali.

3. **Membangunkan antrian unggah tidak lagi ditunggu** (`unawaited`). Itu bukan
   syarat untuk memakai aplikasi.

#### Kenapa ini penting melebihi kejadiannya sendiri

Produk ini dipakai di gudang, dan gudang adalah tempat sinyal paling sering
hilang di tengah. Keadaan yang menimpa Product Owner satu malam adalah keadaan
sehari-hari packer.

#### 🔴 Batas waktu di layar saja TIDAK cukup — tiga lapis yang bekerja bersamaan

Perbaikan di atas ternyata baru separuh jalan, dan itu baru ketahuan setelah
diuji di perangkat. Log 19 Agustus 2026 memperlihatkan layar splash mengulang
dirinya **11 kali** dengan jeda yang berlipat rapi:

```
0,2 dtk → 0,4 → 0,8 → 1,6 → 3,2 → 6,4 → 6,4 → 6,4 …
```

Ada **tiga lapis** yang bekerja bersamaan, dan dua di antaranya bukan milik
kode ini:

| Lapis | Perilaku | Milik |
|---|---|---|
| Batas waktu permintaan | 15 detik | `TimeoutHttpClient` (ditambahkan) |
| Coba-lagi Postgrest | mengulang permintaan gagal sebelum menyerah | bawaan Supabase |
| Coba-lagi Riverpod | 10× dengan jeda 200 ms → 6,4 dtk | bawaan Riverpod 3 |

Pola jeda di atas persis `ProviderContainer.defaultRetry`:

```dart
static Duration? defaultRetry(int retryCount, Object error, {
  int maxRetries = 10,
  Duration maxDelay = const Duration(milliseconds: 6400),
  Duration minDelay = const Duration(milliseconds: 200),
})
```

⚠️ Batas waktu yang dipasang di **layar** tidak menghentikan permintaannya:
layar berhenti menunggu, tetapi permintaannya tetap hidup, dan percobaan
berikutnya menunggu dari nol lagi. Batasnya harus berdiri di permintaannya
sendiri — lihat `TimeoutHttpClient`, yang dipasang lewat
`Supabase.initialize(httpClient: …)` dan terbukti diteruskan ke auth,
postgrest, maupun Edge Function.

#### 🔴 `keepAlive` menyimpan kegagalan — tombol *Coba lagi* jadi mati

Diuji di perangkat: dengan internet sudah kembali, menekan *Coba lagi* **tidak
melakukan apa pun**. Layarnya tetap sama.

Sebabnya `sessionProvider` adalah `@Riverpod(keepAlive: true)`. Sekali gagal, ia
menyimpan kegagalan itu; menyegarkan layar splash saja akan membaca kegagalan
lama dan menyerah seketika **tanpa pernah menyentuh jaringan**.

```dart
void retry() {
  ref.invalidate(sessionProvider);   // ← wajib, tidak boleh dilewat
  ref.invalidateSelf();
}
```

⚠️ **Pola ini akan terulang.** Setiap tombol *Coba lagi* yang sumber datanya
`keepAlive` harus membuang sumbernya juga, bukan hanya layarnya. Kerabat dekat
temuan M.11: meng-invalidate benda yang salah tidak menghasilkan gejala apa pun
selain "tombolnya tidak bekerja".

#### 🔴 Kegagalan jaringan tidak dikenali sama sekali

Layar menampilkan *"Terjadi kesalahan. Coba lagi beberapa saat."* padahal yang
terjadi sinyalnya hilang. `SupabaseService.mapError` tidak mengenal
`ClientException` maupun `TimeoutException`, sehingga keduanya jatuh ke
`AppFailure.unknown`.

Kalimat itu menyembunyikan satu-satunya hal yang perlu diketahui penggunanya. Di
gudang, keliru itu berarti packer mencari-cari masalah pada aplikasi padahal
cukup berjalan ke tempat yang ada sinyalnya.

Dikunci tes di `test/core/network_failure_mapping_test.dart`.

#### Coba-lagi otomatis dimatikan KHUSUS di layar splash

```dart
@Riverpod(retry: _tanpaCobaLagiOtomatis)
```

Di layar lain coba-lagi otomatis berguna dan berjalan di latar tanpa
menghalangi apa pun. Di layar pembuka ia berarti pengguna menatap logo berputar
± 2,5 menit sebelum diberi tahu bahwa jaringannya mati. Layar pembuka harus
cepat berterus terang.

#### Hasil uji perangkat — 19 Agustus 2026, Redmi Note 9

⚠️ **Tidak dapat diuji lewat `flutter test`**; cacatnya hanya muncul saat
jaringan benar-benar diam.

```
17:54:39  mulai · isSignedIn=true
17:54:59  sesi TIMEOUT setelah 20 dtk                 ← sekali saja
17:54:59  pulihkan sesi GAGAL · AppFailure(network)   ← bukan lagi unknown
          ……… hening 65 detik ………                    ← tidak mengulang
17:56:04  mulai · isSignedIn=true                     ← tombol Coba lagi ditekan
17:56:05  sesi siap · role=owner                      ← masuk, 0,9 detik
```

Dari 11 percobaan menjadi **2**. Waktu tunggunya 20 detik, bukan 15 seperti
yang dirancang — coba-lagi Postgrest menambah satu putaran sebelum menyerah.
Dibiarkan: yang penting ia berujung dan tidak berulang.

#### ⚠️ Prosedur uji yang benar — build ulang menghapus sesi

Pengujian pertama gagal mencapai jalur yang dimaksud dan sempat disimpulkan
keliru sebagai cacat baru. Sebabnya: **memasang ulang APK menghapus seluruh
data aplikasi, termasuk sesi login.** Dibuktikan di perangkat — seluruh berkas
preferensi hilang dan yang tersisa hanya dua berkas plugin bertanggal sama
dengan waktu pemasangan.

Jebakan 10 di `PROMPT_SESI_BARU.md` selama ini hanya menyebut rekaman mentah;
sesi login ikut terhapus juga.

Urutan uji yang benar:

1. `.\run.ps1`
2. **login** — wajib, sesi lama sudah terhapus oleh pemasangan
3. aktifkan **mode pesawat**
4. tutup aplikasi dari daftar aplikasi terbuka — **jangan** pasang ulang
5. buka lagi, tunggu pesannya
6. matikan mode pesawat, tekan **Coba lagi**

⚠️ Laptop pengembangan memperoleh internet dari HP yang sama (tethering), jadi
mode pesawat memutus internet laptop juga. `adb` tetap bekerja lewat USB, jadi
logcat dapat direkam ke berkas selama pengujian dan dibaca setelah internet
kembali.

⚠️ `adb logcat | findstr …` di PowerShell tampak kosong karena penyangga pipa.
Rekam ke berkas (`> berkas.log`) atau pakai `-d` sesudah pengujian.

⚠️ Batas waktu serupa **belum** dipasang di jalur lain yang menunggu jaringan
di luar Supabase. Bila kelak ada layar yang menggantung tanpa pesan, periksa
apakah ia menunggu `Future` tanpa `timeout`.

### M.14 Halaman Pengaturan (Bab 9.7) — utang L.7 lunas

**Dikerjakan 19–20 Agustus 2026, terbukti di perangkat.**

Sakelar **"unggah lewat data seluler"** akhirnya pindah dari halaman Akun ke
Pengaturan, rumahnya menurut Bab 9.7. Ia menumpang di Akun sejak 17 Agustus
2026 karena tanpa layar untuk menyalakannya antrian unggah tidak dapat diuji
sama sekali (L.7). Nilainya ada di `SharedPreferences`, jadi kepindahan itu
tidak menghilangkan pilihan yang sudah dibuat pengguna — dikonfirmasi Product
Owner: seluruh sakelar masih ingat posisinya setelah aplikasi ditutup.

Fondasinya sebagian besar sudah ada sejak bab sebelumnya (`AppPreferences`,
`UserSettings`, `TenantSettings`, `UploadOnCellular`); halaman ini terutama
merangkainya.

#### 🔴 `upsert` menuntut izin INSERT — walaupun barisnya sudah ada

**Cacat yang dilaporkan Product Owner 19 Agustus 2026:** menyalakan sakelar
*"Packer boleh melihat riwayat se-toko"* menghasilkan

> "Anda tidak memiliki akses ke data ini"

padahal ia Owner tenant itu sendiri, dan barisnya sudah ada di database.

Sebabnya: `SettingsRepository.saveTenantSettings` memakai **upsert**, dan
PostgREST menerjemahkannya menjadi

```sql
insert into tenant_settings … on conflict (tenant_id) do update …
```

Bagi PostgreSQL perintah itu tetap **INSERT**, meskipun hasil akhirnya
memperbarui baris yang sudah ada. RLS karenanya menuntut policy INSERT —
sedangkan `14_rls.sql` hanya memberi `for update`. Ditolak `42501`.

Dibuktikan langsung sebelum perbaikan ditulis, memakai klaim JWT Owner
sungguhan di dalam transaksi yang di-rollback:

| Percobaan | Sebelum migrasi 22 | Sesudah |
|---|---|---|
| Owner melakukan upsert | ❌ `42501` | ✅ diterima |
| **Packer** melakukan upsert | — | ✅ **tetap ditolak** |

Baris kedua sama pentingnya: perbaikan ini tidak membuka celah baru.

⚠️ **`user_settings` tidak terkena** karena policy-nya `for all` — satu kata
yang mencakup INSERT sekaligus. Perbedaan itulah yang membuat tema dan bahasa
tersimpan ke server sementara pengaturan tenant diam-diam gagal.

🔴 **Pola ini akan terulang.** Setiap tabel yang ditulis lewat `upsert` wajib
punya policy INSERT, bukan hanya UPDATE. Saat ini hanya `user_settings` dan
`tenant_settings` yang ditulis dengan upsert; periksa lagi bila ada yang
ditambahkan.

Migrasi `22_tenant_settings_insert.sql` sengaja **tidak** memakai `for all`:
itu akan sekalian memberi hak DELETE, dan menghapus baris pengaturan tenant
bukan sesuatu yang perlu dapat dilakukan dari aplikasi.

#### Menu bawah menjadi lima tab

Keputusan Product Owner 19 Agustus 2026, mengikuti Bab 9.1:
**Beranda · Toko · Riwayat · Pengaturan · Akun.** Dikonfirmasi di perangkat:
lima tombol masih nyaman ditekan.

🔴 Pengaturan semula **berbagi cabang dengan Akun** di router. Dua tab yang
berbagi satu cabang saling menimpa — menekan Pengaturan lalu Akun akan
menampilkan halaman yang sama dan riwayat navigasi keduanya bercampur. Kini ia
cabang sendiri (cabang 4).

⚠️ Nomor cabang **tidak** sama dengan urutan tombol, dan menu Toko
disembunyikan untuk packer sehingga tombol sesudahnya bergeser di layar tetapi
tidak di router. Pemetaannya dipisah menjadi `MobileShell.branchesFor` dan
dikunci 10 tes — kesalahan satu angka di sana tidak menimbulkan error apa pun,
hanya membuat packer yang menekan *Riwayat* mendarat di *Pengaturan*.

#### Sakelar "Rekam dengan suara" — tambahan di luar Bab 9.7

**Diminta Product Owner 20 Agustus 2026.** Dua alasannya, dan keduanya perlu
dicatat karena berbeda sifat:

1. **Tidak semua Owner olshop membutuhkan suara** pada video buktinya.
2. **Mengurangi ukuran video** — dan ini alasan berbiaya: tiap megabyte
   menjadi ongkos penyimpanan R2 sekaligus kuota data packer yang
   mengunggahnya.

⚠️ Penghematannya **belum diukur**. Bila kelak ingin dipakai untuk
merencanakan biaya, bandingkan `file_size_bytes` video dengan dan tanpa suara
pada durasi yang sama.

Disimpan di perangkat (`SharedPreferences`), bukan di server — keputusan
Product Owner, sejalan dengan sakelar data seluler.

⚠️ Konsekuensi yang ikut disetujui: **packer dapat mematikannya tanpa
sepengetahuan Owner.** Bila kelak Owner perlu menjamin seluruh buktinya
bersuara, sakelar ini harus pindah ke `tenant_settings` beserta migrasinya.

Dua hal yang menjaga agar sakelar ini tidak merusak bukti yang sudah ada:

- 🔴 **Bawaannya menyala.** Sebelum sakelar ini ada, seluruh video direkam
  bersuara selama izin mikrofon diberikan. Bawaan mati akan diam-diam mengubah
  isi bukti pada perangkat yang sudah dipakai, dan pelanggan baru
  menyadarinya saat membuka video lama untuk sengketa.
- **Ia hanya dapat menurunkan kemampuan.** Izin sistem tetap batas atasnya:
  mikrofon yang ditolak membuat video bisu walaupun sakelarnya menyala —
  dan itu memang benar (Bab 8.9: video bisu jauh lebih baik daripada tidak ada
  video).

Nilainya dibaca **saat kamera disiapkan**, bukan saat tombol rekam ditekan,
jadi perubahannya berlaku pada perekaman berikutnya.

Penyangga jadwal: ± 0,5 jam, dilaporkan sesuai Bab 0.2.

#### Belum dikerjakan

Halaman `/settings/watermark` (logo, posisi, transparansi) masih placeholder.
Barisnya di Pengaturan hanya terbuka untuk tier Pro; seluruh tenant saat ini
masih trial/Standar, jadi belum ada yang dapat menemukan halaman kosong itu.

---

### M.15 Kelola Akun Packer (Bab 9.6) — dan tiga cacat yang hanya perangkat dapat menemukannya

**Dikerjakan 19–20 Agustus 2026.** Halaman Akun, Ubah Profil, dan sub-halaman
Kelola Akun Packer. Bucket `avatars` dibuat lewat migrasi
`23_avatars_bucket.sql` (publik, batas 2 MB, jpeg/png/webp) dengan empat policy
yang seluruhnya bersandar pada satu pola jalur: `{userId}/avatar.jpg`. Folder
teratas adalah pemiliknya, dan itulah yang diperiksa
`(storage.foldername(name))[1] = auth.uid()::text`. Tanpa pola itu, siapa pun
yang login dapat menimpa foto profil orang lain.

Nama berkasnya sengaja **tetap**, bukan bertambah tiap unggahan: foto lama
ditimpa sehingga tidak ada sampah menumpuk. Konsekuensinya URL-nya tidak
berubah, jadi penanda waktu ditempelkan sebagai query agar gambar lama di cache
tidak ikut bertahan.

Tiga cacat di bawah ini punya satu kesamaan yang layak dicatat sendiri:
**tidak satu pun dapat ditemukan oleh `flutter analyze` maupun `flutter test`.**
Ketiganya lolos seluruh pemeriksaan otomatis dan hanya muncul ketika aplikasi
dijalankan di perangkat sungguhan oleh orang yang memakainya sebagaimana
mestinya.

#### 🔴 `temp_password` terbuang diam-diam sejak Bab 6.7

`UserRepository.createPacker` memaksa balasan Edge Function `create-packer`
menjadi `AppUser`. Balasan itu berisi `temp_password`, dan `AppUser` tidak
punya kolom untuk menampungnya — jadi ia dibuang tanpa suara.

Password sementara itu dikembalikan server **sekali saja**; sesudahnya ia hanya
ada dalam bentuk ter-hash dan tidak dapat diminta lagi. Membuangnya berarti
akun packer yang baru dibuat tidak dapat dipakai siapa pun, dan satu-satunya
jalan keluar adalah mengirim tautan atur ulang password.

Tidak pernah terlihat karena belum ada layar yang memakainya. Diperbaiki
dengan kelas `NewPackerCredentials`, dan dialognya sengaja tidak dapat ditutup
dengan mengetuk di luar.

#### 🔴 Menghapus packer TIDAK mencabut aksesnya

**Dilaporkan Product Owner 20 Agustus 2026.** Akun packer dihapus dari layar,
lalu:

1. emailnya tidak dapat dipakai lagi (`EMAIL_ALREADY_USED`),
2. orang yang "sudah dihapus" **masih dapat masuk dengan password lamanya**,
3. begitu masuk ia terjebak di *"Data tidak ditemukan"* tanpa jalan keluar.

Sebabnya satu. Akun tersimpan di dua tempat: akun masuk (`auth.users`) dan
profil aplikasi (`public.users`). `deletePacker` menghapus langsung lewat
PostgREST:

```sql
delete from public.users where id = …
```

Itu hanya membuang profilnya. `03_users.sql` baris 9 menyatakan

```sql
id uuid primary key references auth.users(id) on delete cascade
```

— cascade-nya berjalan **auth → public**, tidak pernah sebaliknya. Kartu
aksesnya tidak pernah ditarik.

Poin 2 yang paling berat, dan ia tidak terlihat di layar mana pun: Owner
mengira akses seorang bekas pegawai sudah dicabut, padahal belum sama sekali.

Menghapus `auth.users` menuntut service-role, dan service-role tidak boleh ada
di aplikasi (Bab 4.4). Karena itu pekerjaannya pindah ke Edge Function
**`delete-packer`** — pemanggil harus Owner aktif, sasarannya harus packer
milik tenant yang sama (diperiksa dengan tangan: service-role mengabaikan
seluruh RLS), Owner tidak dapat menghapus dirinya sendiri, dan packer yang
sudah pernah merekam tetap ditolak.

**Katup pengaman menyertainya di `Session.build()`:** sesi sah yang profilnya
tidak ada (`notFound`) memicu keluar paksa ke halaman login. Sebab utamanya
sudah diperbaiki, tetapi akun dapat lenyap karena hal lain — dihapus dari
dasbor, tenant dibersihkan — dan **aplikasi tidak boleh punya keadaan yang
tidak dapat ditinggalkan penggunanya.** Kemarin bahkan tombol keluar pun tidak
terjangkau, karena ia berada di layar yang tidak pernah sempat tampil, dan
menutup paksa aplikasi tidak menolong: sesinya tersimpan.

Hanya `notFound` yang memicunya. PostgREST menjawab sukses dan berkata nol
baris — bukan jaringan gagal, bukan RLS menolak. Memperlakukan kegagalan
jaringan dengan cara yang sama akan mengeluarkan orang dari aplikasi setiap
kali sinyalnya hilang.

#### 🔴 Layar pemotong foto tidak terdaftar — aplikasi mati total

**Dilaporkan Product Owner 20 Agustus 2026.** Memilih foto profil membunuh
aplikasi. Logcat:

```
ActivityNotFoundException: Unable to find explicit activity class
  {id.kamelscan.app/com.yalantis.ucrop.UCropActivity}
IllegalStateException: Reply already submitted
```

`image_cropper` menuntut `com.yalantis.ucrop.UCropActivity` dideklarasikan di
`AndroidManifest.xml`; ia tidak pernah ada di sana. Android menolak membuka
layar yang tidak terdaftar, lalu pluginnya membalas Flutter dua kali dan proses
dimatikan.

Temanya wajib AppCompat (`Theme.AppCompat.Light.NoActionBar`) karena UCrop
mewarisi `AppCompatActivity`.

**Pelajaran yang lebih penting daripada perbaikannya:** cacat ini ada di berkas
konfigurasi Android, bukan di kode Dart. Tidak ada jumlah tes Dart yang dapat
menemukannya.

---

### M.16 🔴 Jebakan: `messageKey` baru yang lupa disambungkan berubah jadi "Terjadi kesalahan"

**Terjadi 20 Agustus 2026 — pada perbaikan yang justru dibuat untuk menghapus
kalimat itu.**

Product Owner melaporkan bahwa menambah packer dengan email yang sudah terpakai
menampilkan *"Terjadi kesalahan. Coba lagi beberapa saat."* Logcat menunjukkan
server sudah menjelaskannya dengan sangat jelas:

```
FunctionsHttpException(status: 400, details: {error: EMAIL_ALREADY_USED, …})
```

Dua cacat terpisah bersembunyi di balik satu kalimat yang sama.

**Cacat pertama — `mapError` tidak mengenal Edge Function sama sekali.**
Seluruh fungsi di `supabase/functions/` sepakat membalas
`{ "error": "KODE_HURUF_BESAR" }`, tetapi kodenya ada di **badan balasan**,
bukan di pesannya — sehingga `_mapByMessage` tidak pernah melihatnya dan setiap
penolakan Edge Function jatuh ke `unknown`. Diperbaiki dengan `_mapFunctions`.

Kelas dasarnya `FunctionException` (tanpa `s`), bukan `FunctionsException`.
`FunctionsFetchException` ditangani terpisah sebagai kegagalan **jaringan**:
statusnya 0 karena tidak ada balasan sama sekali.

**Cacat kedua — sambungannya lupa dipasang.** Menambah kegagalan baru menuntut
tiga tempat disentuh berurutan:

1. `AppFailure` — kunci pesannya
2. `app_id.arb` / `app_en.arb` — kalimatnya
3. `failure_messages.dart` — sambungan antara keduanya

Langkah 3 terlewat. Akibatnya `packersEmailTaken` sudah ada di ARB, sudah
dipetakan dari kode server, dan tetap tidak pernah sampai ke layar — ia jatuh
ke cabang `_` dan berubah kembali menjadi *"Terjadi kesalahan"*.

**Melewatkan langkah 3 tidak menimbulkan gejala apa pun:** `analyze` bersih,
seluruh tes hijau, aplikasi berjalan normal. Satu-satunya gejalanya adalah
kalimat yang salah di layar — dan kalimat itu justru menyuruh penggunanya
mencoba lagi hal yang tidak akan pernah berhasil.

Karena kekeliruannya tidak dapat dilihat, penjagaannya tidak boleh mengandalkan
penglihatan. `test/core/failure_message_keys_test.dart` membaca `AppFailure`
langsung dari berkas sumbernya, mengumpulkan seluruh `messageKey`, dan menolak
yang belum punya cabang di `failure_messages.dart`. `errorUnknown` dikecualikan
— ia justru cabang cadangan itu sendiri.

Tesnya juga memeriksa bahwa ia benar-benar membaca sesuatu (`length > 10`);
tanpa itu, berkas yang berpindah tempat akan membuatnya "lulus" atas nol kunci
— penjagaan yang hilang tanpa suara, jenis kegagalan yang sama persis dengan
yang sedang dijaga.

---

### M.17 🔴 Penugasan toko tidak pernah membatasi perekaman

**Dilaporkan Product Owner 20 Agustus 2026.** Seorang packer ditugaskan ke 2
dari 3 toko. Ia tetap melihat ketiga toko di layar Pilih Toko, memilih toko
yang bukan tugasnya, merekam — dan server menerimanya. Videonya lalu muncul di
Riwayat atas nama toko yang tidak pernah ia pegang.

Panduan §8.2 baris 1697 sudah tegas: *"Pilih toko — bagi packer, hanya toko
yang ditugaskan kepadanya (`shop_packers`)."*

Yang membuat ini layak dicatat bukan cacatnya, melainkan **komentar yang
menutupinya**. `recording_setup_view_model.dart` memanggil `fetchShops` tanpa
penyaringan apa pun sambil menuliskan:

> *"Packer hanya melihat toko yang ditugaskan kepadanya (Bab 8.2). Filter
> sesungguhnya ada di RLS; di sini hanya menampilkan apa yang boleh dilihat."*

Filter itu tidak pernah ada. `shops_select` di `14_rls.sql` memberi seluruh
anggota tenant hak baca atas semua toko, dan `videos_insert` hanya memastikan
tokonya milik tenant yang sama dan berstatus aktif — ia tidak pernah menyentuh
`shop_packers`. Penugasan selama ini hanya mengatur **apa yang terlihat di
Riwayat** (`videos_select`), bukan **apa yang boleh direkam**.

Komentar yang menyatakan penjagaan ada di tempat lain lebih berbahaya daripada
tidak ada komentar sama sekali: ia menghentikan pembaca berikutnya dari
memeriksa.

**Diperbaiki dua lapis, dan keduanya perlu:**

| Lapis | Gunanya |
|---|---|
| `fetchShops(assignedOnly:)` — PostgREST `shop_packers!inner` | Pilihan yang pasti ditolak tidak pernah muncul di layar |
| Policy `videos_insert` (migrasi `24_videos_insert_assignment.sql`) | Penjagaan sesungguhnya — berlaku juga bagi yang memanggil API langsung |

Menyaring di layar saja bukan penjagaan (Bab 2.3). Menjaga di server saja
membuat packer memilih toko lalu ditolak tanpa mengerti sebabnya.

Tanda `!inner` wajib: tanpanya PostgREST tetap mengembalikan tokonya dengan
daftar penugasan kosong, dan penyaringannya tidak terjadi sama sekali.

**`shops_select` sengaja TIDAK diperketat.** Menyempitkan hak baca toko untuk
packer terasa lebih rapi, tetapi merusak hal lain: packer berhak melihat
rekamannya sendiri selamanya (Bab 2.2 catatan 3), termasuk video dari toko yang
penugasannya kemudian dicabut Owner. Bila tokonya tak lagi terbaca, baris
riwayat itu kehilangan namanya dan berubah menjadi bukti tanpa identitas toko —
justru pada berkas yang gunanya menjadi bukti. Yang perlu dijaga adalah
**perbuatannya** (merekam), bukan **pengetahuannya** (nama toko milik tenant
sendiri).

⚠️ Perbaikan ini menyentuh
`lib/pages/recording/setup/recording_setup_view_model.dart`, folder yang
dikerjakan worktree kamera. Perubahannya satu pemanggilan, tetapi berpotensi
bentrok saat digabung.

#### Belum terpecahkan: Beranda kosong pada packer

Product Owner melaporkan 20 Agustus 2026: sesudah packer masuk, badan Beranda
kosong sama sekali; menekan menu lain lalu kembali membuat isinya muncul.
Owner tidak terpengaruh.

**Sebabnya belum diketahui.** Yang sudah terbukti dari jejak perangkat:

- `KAMELSCAN_SHELL cabang=0 tab=0` — lapisan navigasi **tidak bersalah**;
  dugaan awal tentang cabang yang belum dikunjungi terbukti salah.
- `KAMELSCAN_HOME bangun` tercetak, jadi halamannya memang dibangun.
- Datanya pun sampai: percobaan pada 20 Agustus mencatat `statistik OK`,
  tetapi layarnya tidak digambar ulang sesudahnya.
- Halamannya kadang terisi dan kadang tidak pada langkah yang sama persis —
  jadi ini **balapan waktu**, bukan kegagalan yang tetap.

⚠️ **Empat percobaan perbaikan dibatalkan seluruhnya atas keputusan Product
Owner, 21 Agustus 2026**, sesudah percobaan keempat masih gagal *dan* merusak
layar splash yang sudah beres di M.13 (tombol *Coba lagi* tidak berfungsi, lalu
terlempar ke halaman login). Yang dibatalkan:

1. `sessionProvider.future` menggantikan `.value` di kedelapan ViewModel
2. Pencocokan `hasError` menggantikan tipe `AsyncError` di tujuh halaman
3. Pembantu `sessionForBuild`
4. Provider turunan `currentSession` untuk meredam pembangunan ganda

Pelajaran yang layak dibawa: **percobaan ketiga dan keempat seharusnya tidak
pernah ada.** Sesudah percobaan kedua gagal dan gejalanya berubah menjadi lebih
buruk, yang benar adalah berhenti, mengembalikan keadaan, lalu memeriksa dari
sisi yang belum pernah diukur sama sekali — bukan menumpuk perbaikan di atas
perbaikan yang belum terbukti. Setiap ronde memakan satu siklus build dan satu
pengujian di perangkat milik Product Owner, dan biaya itu ditanggung orang lain.

Jejak `KAMELSCAN_SHELL` dan `KAMELSCAN_HOME bangun` sengaja **dibiarkan
terpasang** untuk penyelidikan berikutnya. Yang belum pernah diukur sama
sekali: bagian dalam `Session.build()`, dan apakah `Shimmer` (yang dipakai
`_HomeSkeleton`) benar-benar tergambar di bawah Impeller/Vulkan — kerangka yang
tidak terlihat akan tampak persis seperti halaman kosong.

#### Belum dikerjakan / diputuskan

- **Email ke packer baru.** Aplikasi tidak pernah mengirim email saat akun
  packer dibuat; `email_confirm: true` menandainya terkonfirmasi, bukan
  mengirim apa pun. Itu sesuai Bab 6.7 — password diserahkan Owner langsung.
  Product Owner menanyakannya 20 Agustus 2026; belum ada keputusan, dan
  penambahannya akan dilaporkan sebagai penambahan lingkup (Bab 0.2).

---

## N. Bab 6: alur masuk & pendaftaran

Empat temuan dari pengujian Product Owner **24 Agustus 2026**. Tidak satu pun
terdeteksi `flutter analyze` maupun 295 tes yang ada — semuanya baru terlihat
ketika aplikasinya dijalankan di Redmi Note 9 dan logcat-nya dibaca langsung.

### N.1 🔴 GoRouter tidak pernah diberi tahu — Lengkapi Profil jadi jebakan

**Ini temuan terpenting berkas ini untuk navigasi.** Aturannya satu kalimat:

> **Apa pun yang dibaca `RouteGuards.redirect` WAJIB ikut disimak
> `GoRouterRefreshNotifier`.**

GoRouter tidak mengintip provider. Ia hanya menghitung ulang tujuan ketika ada
yang memberitahunya, dan satu-satunya pemberi tahu adalah `refreshListenable`.
Setiap nilai yang dibaca guard tetapi tidak disimak di sana menghasilkan cacat
berbentuk sama: **layar yang seharusnya berpindah, diam di tempat.**

**Gejalanya.** Mendaftar lewat "Lanjutkan dengan Google" membawa pengguna ke
layar *Lengkapi Profil*. Ia mengisi nomor HP, mencentang S&K, menekan *Simpan &
lanjutkan* — dan tidak terjadi apa-apa. Tombol kembali di layar itu sengaja
dimatikan, jadi satu-satunya jalan keluar adalah menutup paksa aplikasi.

**Yang menyesatkan.** Tangkapan layar yang dikirim memperlihatkan layar itu
**tanpa satu pun kolom** — hanya judul dan tombol. Membaca kode, keadaan itu
mustahil: bila kedua kolom padam berarti profilnya sudah lengkap, dan bila sudah
lengkap guard seharusnya sudah memindahkannya. Salah satu dari dua anggapan itu
keliru, dan tidak ada cara memilihnya dari gambar.

**Yang memecahkan: basis data, bukan kode.** Kueri ke `public.users` menunjukkan
`phone` dan `terms_accepted_at` **terisi**. Penekanan tombolnya berhasil
sepenuhnya. Lebih jauh, `terms_accepted_at` tercatat **sembilan menit sesudah**
akunnya dibuat — jejak Product Owner menekan tombol itu berulang kali;
`accept_terms()` menulis ulang `now()` setiap panggilan, jadi yang tersimpan
adalah tekanan terakhirnya sebelum menyerah.

Jadi kolomnya bukan tidak pernah muncul: ia **hilang sesudah tersimpan**, karena
`needsPhoneInput` dan `needsTermsAcceptance` ikut padam. Tangkapan layar itu
keadaan sesudah berhasil, bukan sebelum.

**Sebabnya.** `GoRouterRefreshNotifier` hanya menyimak `isSignedIn` dan
`currentRole`. Melengkapi profil tidak mengubah keduanya — penggunanya tetap
masuk, tetap `owner`. Tidak ada pemicu, tidak ada perhitungan ulang.

`CompleteProfilePage` sendiri sengaja tidak menavigasi, dengan alasan yang masuk
akal ("agar tidak ada dua pihak yang mengatur tujuan"). Keputusan itu benar;
yang kurang adalah pihak yang **satu-satunya** itu tidak pernah dibangunkan.

**Diperbaiki** dengan menambahkan `mustChangePassword`, `needsProfileCompletion`,
dan `passwordResetPending` ke daftar simakan.

**Dijaga** `test/navigation/route_guards_test.dart` — dan penjagaannya sudah
dibuktikan: dengan simakan itu dilepas, jumlah pemberitahuan ke GoRouter = **0**
dan tesnya gagal. Tes yang tidak pernah dilihat gagal tidak membuktikan apa pun.

**Terbukti di perangkat 24 Agustus 2026:**

```
KAMELSCAN_PROFIL bangun · butuhHp=true  butuhSetuju=true  butuhLengkap=true
KAMELSCAN_PROFIL simpan · kirimHp=true kirimSetuju=true
KAMELSCAN_PROFIL simpan BERHASIL · hp=628… setuju=…14:00:42 butuhLengkap=false
KAMELSCAN_PROFIL bangun · butuhHp=false butuhSetuju=false butuhLengkap=false  <- *
(pindah ke Beranda)
```

Baris bertanda `*` itulah keadaan tangkapan layar yang membingungkan. Dulu di
situ berhenti selamanya; sekarang ia satu kedipan yang terlewati.

**Dua penambalan yang lahir dari penyelidikan yang sama:**

1. `AuthService.updatePhone` memakai `.update()` tanpa `.select()`. PostgREST
   menjawab **sukses** walaupun nol baris berubah — baris yang tersaring RLS
   tidak menghasilkan error, ia hanya menghasilkan nol baris. Kegagalan
   penyimpanan akan tampak persis seperti keberhasilan. Sekarang nol baris =
   gagal.
2. Layar Lengkapi Profil diberi tombol **Keluar**. Ia tetap tidak boleh
   dilewati — menekannya MENGELUARKAN pengguna, bukan meloloskannya. Yang
   diperbaiki adalah keadaan tanpa jalan keluar sama sekali. **Aplikasi tidak
   boleh punya keadaan yang tidak dapat ditinggalkan penggunanya** — aturan yang
   sama sudah lahir sekali di `Session.build()` (packer terhapus yang terjebak,
   20 Agustus 2026).

### N.2 🔴 Lupa Password tidak punya layar tujuan sama sekali

**Dilaporkan Product Owner 24 Agustus 2026:** email reset masuk, tautannya
diketuk, aplikasi terbuka — di **halaman Masuk**, tanpa pesan apa pun.

Penelusuran seluruh `lib/` tidak menemukan satu baris pun yang menangani
`AuthChangeEvent.passwordRecovery`, dan tidak ada layar yang meminta password
baru. `/change-password` yang ada justru **menanyakan password lama** — padahal
orang sampai ke sana karena tidak mengingatnya.

Alur itu punya dua kemungkinan akhir, dan **keduanya buntu**:

| Bila penukaran tautan | Akibatnya |
|---|---|
| berhasil | pengguna langsung "masuk" ke Beranda, tidak pernah diminta password baru — dan password lamanya masih berlaku |
| gagal | `gotrue` melempar galatnya ke aliran `onAuthStateChange` lewat `notifyException`, dan satu-satunya pembacanya adalah `isSignedInProvider` yang diam-diam jatuh ke sesi lama. **Dari layar, tautan kedaluwarsa tampak persis seperti tautan yang tidak melakukan apa-apa.** |

**Diperbaiki** dengan layar `/reset-password`, penanda pemulihan, dan pemetaan
galat tautan ke `errorResetLinkInvalid`.

⚠️ Penandanya disimpan sebagai `ValueNotifier` di `SupabaseService`, **bukan** di
provider. Alasannya bukan gaya: `supabase_flutter` mulai menyimak deep link di
dalam `Supabase.initialize()`, yang berjalan **sebelum `runApp()`**. Provider
yang baru lahir saat layar pertama dibangun akan melewatkan peristiwanya, dan
gejalanya persis seperti tautan yang tidak berfungsi.

**Akibat sampingan yang penting bagi produk:** akun yang lahir dari tombol
Google **tidak punya password sama sekali** — Google tidak pernah memberikan
password pemiliknya kepada aplikasi mana pun. Satu-satunya cara akun semacam itu
memperoleh password adalah lewat alur ini. Selama alurnya buntu, pertanyaan
Product Owner *"kok tidak bisa masuk pakai email dan password?"* tidak punya
jawaban yang dapat dikerjakan. Terbukti tuntas di perangkat 24 Agustus 2026.

### N.3 Tombol Google terasa lambat — 2,8 dari 3,17 detik bukan milik kita

**Terukur di Redmi Note 9, 24 Agustus 2026**, dengan penanda disisipkan ke
logcat (`adb shell log -t KAMELSCAN_UJI`) tepat sebelum ketukan:

| Waktu | Kejadian | Selisih |
|---|---|---|
| 20:56:50.704 | ketukan | — |
| 20:56:51.065 | aplikasi melempar ke Google | **+0,36 dtk** |
| 20:56:52.687 | `SignInCredentialChooserActivity` tampil | +1,62 dtk |
| 20:56:53.875 | `GoogleSignInActivity` siap ditekan | +0,87 dtk |

**Dugaan awal keliru dan perlu dicatat sebagai peringatan.** Diduga
`GoogleSignIn.initialize()` yang mahal, lalu dipindahkan ke awal aplikasi.
Pengukuran menunjukkan ia hanya butuh **±40 ms** (`KAMELSCAN_GOOGLE siap
dipakai` muncul 43 ms sesudah Supabase siap). Pemanasannya tetap dipertahankan —
ia benar dan menghilangkan biaya itu dari jalur ketukan — tetapi **bukan itu
sebab lambatnya.**

2,8 detik sisanya milik Google Play Services, di luar proses aplikasi. Dari
Flutter tidak ada yang dapat mempercepatnya.

**Yang justru dapat diperbaiki adalah keheningannya.** Selama tiga detik itu
tombolnya hanya berubah abu-abu tanpa tanda apa pun — dan itulah yang dilaporkan
sebagai "lama banget". Tiga detik yang diakui terasa berbeda dari tiga detik
yang didiamkan.

`LoginBusy` kini membawa `viaGoogle`, supaya menekan *Masuk* tidak membuat
tombol Google ikut berputar — memberi tahu hal yang tidak benar sama buruknya
dengan tidak memberi tahu apa pun.

### N.4 Email yang sudah terdaftar: penolakannya BENAR, kalimatnya yang salah

**Diuji Product Owner 24 Agustus 2026** atas pertanyaannya sendiri: apakah email
yang sudah dipakai packer bisa dipakai mendaftar sebagai owner?

**Tidak bisa, dan terkunci rangkap tiga:** `auth.users.email` unik (bawaan
Supabase), `users.email` unik (`citext`, jadi huruf besar/kecil sama), dan
`users.email_normalized` unik — yang terakhir membuang alias `+` dan titik Gmail
lewat `normalize_email()`, sehingga `budi+owner@gmail.com` dan
`b.u.d.i@gmail.com` ikut tertolak. Penjagaannya di basis data, jadi tetap
berlaku bagi penyerang yang memanggil API langsung (Bab 2.3).

**Tetapi layarnya berbohong.** Supabase sengaja menyamarkan penolakan ini agar
tidak ada yang dapat memetakan daftar email pelanggan dengan mencoba mendaftar
satu per satu. Ia menjawab seolah normal: tidak membuat akun, tidak mengirim
email. Aplikasi menerjemahkannya menjadi janji pasti — *"Kami mengirim tautan
verifikasi ke …"* — lalu *"Menunggu verifikasi…"* berputar untuk sesuatu yang
tidak akan pernah datang.

🔴 **Perbaikannya sengaja di kalimatnya, BUKAN di mekanismenya.** Menambahkan
pengecekan email di depan akan membongkar perlindungan itu dan mengubah formulir
Daftar menjadi alat pemeriksa siapa pelanggan KamelScan. Garis itu sudah ditarik
dua kali di proyek ini: `17_username_check.sql` sengaja hanya membuka
**username**, dan `ForgotPasswordViewModel` sudah memakai pola *"Jika email
tersebut terdaftar…"*. Layar verifikasi kini memakai pola yang sama, ditambah
tombol **Masuk** sebagai jalan keluar.

Kalau suatu saat kejelasan dinilai lebih berharga daripada kerahasiaan daftar
pelanggan, RPC `is_email_available` dapat dibuat — tetapi itu **keputusan
produk, bukan keputusan teknis**, dan harus diambil sadar-sadar.

### N.5 🔴 `tenants` tertutup rapat bagi Owner — nama usaha tidak pernah dapat diisi

**Dilaporkan Product Owner 24 Agustus 2026:** *"pendaftaran lewat Google
formulirnya tidak sama dengan pendaftaran manual"*. Benar, dan yang paling
parah bukan yang terlihat.

Pendaftaran lewat formulir mengirim `username` dan `business_name` lewat
`raw_user_meta_data`, dan `handle_new_user()` menyalinnya. Pendaftaran lewat
Google tidak pernah mengirim metadata apa pun, sehingga keduanya NULL.

| Kolom | Bisa diisi belakangan? |
|---|---|
| nama lengkap | ya — Google memberikannya, dan Edit Profil dapat mengubahnya |
| nomor HP | ya — Edit Profil |
| username | ya — Edit Profil |
| **nama usaha** | 🔴 **TIDAK, di mana pun** |
| **password** | 🔴 **TIDAK** — "Ganti Password" menuntut password lama |

**Sebab nama usaha:** ia tinggal di `public.tenants`, dan satu-satunya policy
tulis pada tabel itu adalah `tenants_update_admin` (14_rls.sql) — **hanya
Admin**. Owner tidak punya izin menyentuh barisnya sendiri. Jadi ini bukan
"layarnya lupa dibuat"; memang tidak mungkin dibuat. Layar Edit Profil pun
tidak dapat menolong karena ia menulis ke `users`.

Akibatnya terlihat setiap hari: `mobile_app_bar.dart` menampilkan nama usaha di
bilah atas, dan bagi pendaftar lewat Google ia kosong selamanya.

🔴 **RLS-nya sengaja TIDAK dilonggarkan.** `tenants` memuat `tier_plan`,
`status`, `period_end`, dan `trial_used`. Membuka UPDATE bagi Owner demi satu
kolom berarti membuka jalan menaikkan paketnya sendiri dan memperpanjang masa
uji cobanya sendiri. Kekhawatiran yang sama sudah melahirkan
`guard_subscription_owner_update` di migrasi 25.

Gantinya RPC `security definer` yang hanya menyentuh satu kolom, hanya pada
tenant milik pemanggilnya, dan hanya bila ia benar-benar Owner —
`26_business_name.sql`. Perannya dibaca dari tabel, **bukan** dari klaim JWT:
JWT membawa nilai lama sampai disegarkan (Bab 5.3), dan operasi tulis tidak
boleh bergantung pada itu.

**Aturan yang lahir dari sini:** sebelum menaruh kolom `tenants` mana pun di
layar mana pun, periksa dulu apakah Owner memang punya izin menulisnya. Jawaban
bawaannya **tidak**.

**Layar Lengkapi Profil kini menanyakan keempatnya** — nomor HP (wajib),
username, nama usaha, dan password (ketiganya opsional). Password sengaja tidak
diwajibkan: mewajibkannya menghapus satu-satunya keuntungan tombol Google.
Keputusan Product Owner, 24 Agustus 2026.

⚠️ **Urutan penyimpanannya bukan selera.** Persetujuan S&K dicatat **paling
akhir**, karena `terms_accepted_at` adalah separuh syarat yang dibaca
`needsProfileCompletion`. Mencatatnya lebih dulu berarti sebuah kegagalan di
tengah jalan tetap meloloskan pengguna keluar dari layar ini dengan data yang
masih kurang — dan tidak ada layar lain yang akan menanyakan sisanya. Dijaga
`test/core/complete_profile_order_test.dart`.

**Masih terbuka:** yang **melewati** kolom nama usaha saat mendaftar tetap tidak
punya jalan mengisinya belakangan. Fungsi servernya sudah ada; yang kurang
tinggal satu kolom di layar Edit Profil. Belum dikerjakan atas keputusan
Product Owner.

## O. Bab 10: menerbitkan aplikasi web

**Dikerjakan 25 Agustus 2026.** Bab 10.2 — utang tertua proyek ini. Sejak M.10
(19 Agustus) tautan bukti `https://kamelscan.com/v/{token}` tidak dapat dibuka
siapa pun; halaman dan Edge Function-nya sudah jadi, yang kurang hanya alamat
yang dapat dijangkau orang luar. Sekarang lunas.

Hasil akhir yang terbukti:

```
https://kamelscan.com           -> 302 ke /app/
https://kamelscan.com/app/*     -> aplikasi Flutter Web
https://kamelscan.com/v/{token} -> halaman bukti, tanpa login
```

### O.1 Tanda `#` dibuang dari alamat web

Flutter Web bawaannya menaruh `#` di alamat (`/app/#/login`), sedangkan Bab 10.2
menetapkan tautan *Masuk* pada landing page mengarah ke `/app/login`. Perbaikan:
`applyUrlStrategy()` di `main.dart`, dengan pola impor bersyarat yang sudah
dipakai sembilan kali di proyek ini (`lib/core/utils/url_strategy*.dart`).

🔴 **Konsekuensinya bukan kosmetik.** Tanpa `#`, **server** yang menerima
`/app/history` — bukan aplikasi. Server yang tidak diberi tahu akan mencari
berkas bernama `history` dan menjawab 404 begitu halaman disegarkan. Itulah
sebab seluruh isi O.2 diperlukan.

### O.2 🔴 Dua jebakan `_redirects` yang gagal TANPA pesan apa pun

Keduanya memakan waktu berjam-jam pada 25 Agustus 2026, dan **tidak satu pun
terdeteksi `analyze`, tes, maupun keluaran `wrangler`** — deployment dilaporkan
sukses, dan dashboard Cloudflare menampilkan aturannya terdaftar rapi.

**1. Tujuan tidak boleh berakhiran `.html`.**

Cloudflare punya kebiasaan sendiri membuang akhiran `.html` dan mengalihkan
alamatnya (308). Aturan `/app/*` menuju `/app/index.html` dengan status 200
karena itu tidak pernah menyajikan apa pun; hasilnya 404 di situs yang sudah
terbit. Tulis tujuannya sebagai direktori: `/app/`.

**2. Pola `/app/*` menelan berkas aplikasinya sendiri.**

`_redirects` diproses **sebelum** berkas dicari, jadi `/app/*` ikut menangkap
`main.dart.js`, `flutter.js`, `manifest.json`, dan seluruh `assets/`. Semuanya
berubah menjadi `text/html` dan aplikasinya jadi halaman putih. Gejalanya halus:
`/app/login` menjawab 200 dengan benar, sehingga cacat ini mudah dikira beres.

Karena itu rutenya **didaftarkan satu per satu** di `deploy_web.ps1`.

⚠️ **Utang yang lahir dari sini:** setiap rute baru di `route_names.dart` WAJIB
ditambahkan ke daftar itu. Yang terlupa akan bekerja saat diklik dari dalam
aplikasi, tetapi menjawab 404 begitu halamannya disegarkan atau alamatnya
dikirim ke orang lain.

**Cara memeriksa yang benar** — periksa `Content-Type`, bukan hanya kode status:

```bash
curl -sI https://kamelscan.com/app/main.dart.js | grep -i content-type
# WAJIB application/javascript. Bila text/html, aturannya terlalu rakus.
```

### O.3 Yang BUKAN penyebabnya — jangan diulang

Dua dugaan menghabiskan waktu dan keduanya terbantah oleh pengukuran:

- **Akhir baris CRLF pada `_redirects`.** Diuji: Cloudflare memaafkannya. LF
  tetap dipakai karena itu bentuk yang didokumentasikan, tetapi ia **bukan**
  sebab kegagalan hari itu.
- **Cloudflare menolak berkasnya.** Terbantah oleh tangkapan layar dashboard
  Product Owner: tab *Redirects* menampilkan seluruh aturan tanpa satu pun
  galat. Itu yang membalik arah penyelidikan.

🔴 **Aturan yang lahir dari sini: alat uji yang lebih pemaaf daripada aslinya
lebih berbahaya daripada tidak menguji sama sekali.** Server tiruan Cloudflare
yang dipakai menguji secara lokal memakai `.strip()` Python, yang diam-diam
membuang `\r` — sehingga berkas CRLF lolos di tiruan padahal ditolak aslinya.
Tiruannya sudah diperbaiki agar menolak apa yang aslinya tolak.

### O.4 Halaman bukti publik dibuat ulang sebagai HTML ringan

Bab 10.2 mengeluarkan `/v/{token}` dari bundel Flutter agar petugas resolusi
marketplace tidak mengunduh seluruh aplikasi hanya untuk menonton satu video.
Diukur: bundel Flutter **4,3 MB**, halaman HTML **15 KB**.

Keputusan Product Owner 25 Agustus 2026, disertai catatan bahwa versi
Flutter-nya (`lib/pages/public/public_video_page.dart`) sudah jadi dan teruji —
penambahan lingkup ± 2–3 jam yang disetujui.

⚠️ Versi Flutter **sengaja dibiarkan terdaftar** di `app_router.dart`. Ia tidak
akan pernah tercapai (Flutter hanya melayani `/app/`), dan mencabutnya berarti
membuang jaring pengaman tanpa keuntungan apa pun.

**Kredensial diisi saat deploy**, bukan di berkas sumbernya: `web_public/`
masuk git, `env.dev.json` tidak. `deploy_web.ps1` menolak berjalan bila penanda
kredensialnya masih tersisa.

### O.5 🔴 Bahasa: `navigator.language` adalah asumsi yang salah

Versi pertama halaman bukti mengikuti bahasa peramban. Diuji di komputer Product
Owner: **hasilnya bahasa Inggris** — Chrome-nya berbahasa Inggris, seperti
kebanyakan komputer di Indonesia.

Pembaca halaman ini mayoritas petugas resolusi marketplace Indonesia. Setelan
peramban mereka tidak memberi tahu apa pun tentang bahasa yang mereka baca.

**Keputusan: bawaan Indonesia, dengan tombol pengalih `EN`** di bilah atas,
pilihannya diingat lewat `localStorage`.

Ditemukan dari satu tangkapan layar, bukan dari kode maupun tes.

### O.6 Jebakan perkakas yang memakan waktu

**1. `flutter build web` dengan `--base-href` TIDAK BOLEH dijalankan dari Git
Bash.** Git Bash menerjemahkan `/app/` menjadi `C:/Program Files/Git/app/`
sebelum Flutter melihatnya — dan perintahnya **tetap melaporkan berhasil**.
Saudara kandung jebakan `adb install` (butir 17 di prompt serah terima).
Jalankan dari PowerShell. `deploy_web.ps1` kini menolak berjalan bila
`base href` hasil build bukan `/app/`.

**2. Jangan menjalankan `deploy_web.ps1` dengan penggabungan stderr.** Flutter
menulis "Wasm dry run findings" ke stderr; Windows PowerShell 5.1 mengubahnya
menjadi `NativeCommandError`, dan `ErrorActionPreference = Stop` menghentikan
skrip di tengah walaupun buildnya baik-baik saja. Panggil apa adanya.

**3. Unggahan lewat dashboard gagal, Wrangler berhasil.** 47 MB lewat tethering:
50 dari 51 berkas ditolak dengan pesan `unknown`. Wrangler mengulang sendiri
berkas yang gagal, dan deploy berikutnya hanya mengirim yang berubah — 0,37
detik untuk perubahan satu berkas.

```powershell
npx --yes wrangler@latest login
# klik Authorize di peramban dalam < 1 menit, kalau tidak ia kehabisan waktu
npx --yes wrangler@latest pages deploy build/deploy --project-name=kamelscan --branch=main --commit-dirty=true
```

### O.7 Domain dan DNS

`kamelscan.com` sudah dikelola Cloudflare sejak sebelumnya (nameserver
`paris`/`aaden.ns.cloudflare.com`), tetapi tanpa satu pun A record. Disambungkan
lewat Pages → Custom domains, yang membuat sendiri CNAME `kamelscan.com` menuju
`kamelscan.pages.dev` dengan status Proxied.

⚠️ **Propagasi tidak seragam.** Beberapa saat setelah aktif, `1.1.1.1` sudah
memberi A record sedangkan `8.8.8.8` belum — dan jaringan Product Owner
(tethering HP) kebetulan bertanya ke Google, sehingga Chrome-nya menjawab
`DNS_PROBE_FINISHED_NXDOMAIN` padahal situsnya hidup. Cara membuktikan situs
hidup tanpa bergantung penerjemah nama:

```bash
curl -sI --resolve "kamelscan.com:443:104.21.2.17" https://kamelscan.com/app/login
```

**Akar situs dilempar ke `/app/` dengan status 302** selama landing page belum
diserahkan desainer. Sengaja 302, bukan 301: peramban menyimpan 301 di komputer
pengunjung dan tetap mematuhinya walaupun aturannya sudah dihapus dari server —
landing page baru tidak akan pernah terlihat oleh yang sempat membukanya lebih
dulu. **Hapus baris itu begitu landing page dipasang.**

⚠️ `kamelscan.pages.dev` tetap dapat dibuka dan **tidak dapat dimatikan** —
Cloudflare selalu memberi setiap proyek satu alamat bawaan. Keduanya pintu
menuju berkas yang sama, bukan dua situs.

### O.8 Jalur sukses `create-public-link` — teruji pertama kali

M.10 mencatat jalur ini belum pernah diuji karena memerlukan JWT Owner. Pada 25
Agustus 2026 Product Owner menerbitkan tautan sungguhan dari aplikasi, dan
`get-public-video` mengembalikan metadata lengkap dengan `tenant_id`, `user_id`,
`shop_id`, dan `storage_key` **tidak ikut keluar** — sesuai rancangan.

Videonya juga membuktikan jebakan zona waktu itu nyata: `scan_date` tersimpan
`19 Agustus 17:39 UTC`, yang di Indonesia adalah **20 Agustus 00:39 WIB**. Tanpa
zona `Asia/Jakarta` yang dipaksa, halaman akan menuliskan tanggal 19 sementara
watermark videonya menuliskan 20 — dan pembacanya menyimpulkan buktinya tidak
cocok.

### O.9 Yang masih terbuka sesudah sesi ini

✅ ~~Alamat web belum didaftarkan di Supabase.~~ Beres 25 Agustus 2026 —
`https://kamelscan.com/app/**` kini terdaftar di Dashboard → Authentication →
URL Configuration → Redirect URLs, berdampingan dengan `id.kamelscan.app://**`.
Pola `**` sengaja dipakai supaya rute web baru tidak perlu didaftarkan satu per
satu; yang terlupa **tidak menghasilkan pesan galat apa pun**, Supabase hanya
diam-diam memakai Site URL.

✅ ~~Rute `/auth/callback` tidak punya halaman.~~ Beres — lihat **O.10**.

🔴 **Login Google di web memakai alamat khusus HP.** `auth_service.dart:293`
memakai `Env.oauthRedirectUrl`, yang isinya `id.kamelscan.app://login-callback`
— skema deep link Android. Peramban tidak mengerti alamat semacam itu. Belum
diuji di peramban; ini pembacaan kode.

⚠️ Perbaikan O.10 **tidak menyentuh** baris 293 itu. Ia mengubah
`sendPasswordReset` (baris 426), yang cacatnya sebentuk tetapi bukan cacat yang
sama. Memperbaiki yang 293 menuntut OAuth Client ID jenis Web di Google Cloud
Console — akun Product Owner.

### O.10 Tautan email di web: tiga cacat yang saling menutupi

**Dikerjakan 25 Agustus 2026, sesudah O.** Ketiganya gagal **tanpa satu pun
pesan galat**, dan tidak satu pun terdeteksi `analyze` maupun 307 tes yang ada.
Ketiganya harus benar bersamaan; membetulkan satu saja tidak mengubah apa pun
yang terlihat di layar.

**1. Rute `/auth/callback` tidak ada.**

`env.dart` sudah mengirim alamat itu sejak Bab 10.2. Akibatnya bukan sekadar
salah layar. Alamat itu bukan halaman publik, jadi `RouteGuards.redirect`
menjatuhkannya ke cabang terakhir dan mengembalikan `null` — pengguna yang sudah
masuk **dibiarkan tetap di sana**, dan GoRouter menyerahkannya ke `errorBuilder`.
Hasilnya tersangkut permanen di "halaman tidak ditemukan": tidak ada satu pun
aturan yang memindahkannya, sekarang maupun sesudah sesinya siap.

Perbaikannya karena itu **dua** baris yang harus jalan bersama: mendaftarkan
rutenya di `app_router.dart`, **dan** memasukkan `authCallback` ke
`Routes.public`. Yang kedua yang sebenarnya menutup jalan buntunya.

**2. `sendPasswordReset` memakai alamat deep link Android.**

`Env.oauthRedirectUrl` alih-alih `Env.emailVerifyRedirectUrl`. Keduanya bernilai
sama di HP, sehingga perbedaannya **tidak terlihat sama sekali di sana**. Di web
ia menentukan segalanya: peramban tidak mengerti `id.kamelscan.app://`, dan yang
mengklik tautannya berhenti di halaman kosong abu-abu tanpa penjelasan apa pun.

**3. `WEB_APP_BASE_URL` masih `http://localhost:8080`.**

Situs yang **sudah terbit** dibangun dengan nilai itu, sehingga tautan yang
dikirim ke pengguna sungguhan menunjuk ke komputer pengguna itu sendiri.
`deploy_web.ps1` sudah memperingatkannya — tetapi sebagai peringatan kuning yang
tidak menghentikan build, dan peringatan yang tidak menghentikan apa pun mudah
terlewat di antara ratusan baris keluaran Flutter.

Berkasnya ter-gitignore, jadi perbaikannya tidak ikut commit mana pun.
**Salinan di `E:\kamelscan\env.dev.json` ikut diperbarui** supaya worktree lain
tidak memakai nilai lama.

#### Cara membuktikannya — yang akhirnya memecahkan

Tiga ronde pertama berputar di dugaan. Yang memecahkan: **panel Network peramban
Product Owner**, dibaca baris demi baris.

```
Navigated to  https://kamelscan.com/app/auth/callback?code=27e3c78e-…   ← kode SAMPAI
POST  …/auth/v1/token?grant_type=pkce   422 (Unprocessable Content)     ← server MENOLAK
```

Dua baris itu memisahkan tiga kemungkinan yang sebelumnya menyatu. Kode yang
sampai membuktikan alamat dan `_redirects` sudah benar. POST yang benar-benar
terkirim membuktikan kunci PKCE-nya **ada** — `exchangeCodeForSession` melempar
di laptop dan tidak mengirim apa pun bila kuncinya hilang (gotrue 2.27,
`gotrue_client.dart:430`). Yang tersisa hanya penolakan server.

🔴 **Aturan yang lahir dari sini: pada cacat web, panel Network lebih menentukan
daripada Console.** Console hanya memuat apa yang sempat dicetak aplikasi;
Network memuat apa yang benar-benar terjadi di kabel, termasuk yang gagal
sebelum kode mana pun sempat bereaksi. Centang **Preserve log** lebih dulu —
tanpa itu catatannya terhapus begitu halaman berpindah, dan perpindahan halaman
justru bagian yang sedang diselidiki.

⚠️ Product Owner bukan programmer. Instruksi DevTools yang berbelit gagal
diikuti sampai selesai, dan langkah-langkah menyalin tautan itu sendiri
**menciptakan** kegagalan berikutnya (lihat di bawah). Uji yang berhasil justru
yang paling sederhana: *"klik secepat mungkin, lalu beri tahu saya layar mana
yang muncul."* Satu kalimat, satu pengamatan, satu jawaban yang menentukan.

#### Utang yang lahir: tautan reset di web cepat basi

Diklik dalam ± 1 menit → layar password baru muncul. Diklik sesudah didiamkan
beberapa menit → Supabase menolak dengan `422`.

Sebabnya `authFlowType: AuthFlowType.pkce` di `SupabaseService.init()`. PKCE
menuntut dua hal sekaligus di web: tautannya diklik **cepat**, dan **di peramban
yang sama** dengan yang memintanya. Di HP keduanya gratis — tautannya langsung
membuka aplikasi.

⚠️ **Angka batas waktunya belum pernah diukur.** Jangan menuliskannya sebagai
fakta di dokumen mana pun.

**Keputusan Product Owner 25 Agustus 2026: DIBIARKAN.** Pesan kegagalannya sudah
benar dan sudah menyuruh meminta tautan baru (`errorResetLinkInvalid`), jadi
bukan jalan buntu — hanya merepotkan. Penyangga jadwal sudah minus, dan
± 1 jam itu lebih berharga di Bab 10 yang belum jadi.

Usul yang **sudah ditolak**, jangan diajukan ulang tanpa diminta: memisahkan web
ke alur implicit sambil HP tetap PKCE. Sudah diperiksa dan layak secara teknis —
`getSessionFromUrl` menyalakan `passwordRecovery` dari `type=recovery` di
fragmen alamat (gotrue 2.27, `gotrue_client.dart:1058`), jadi layar password
baru tetap bekerja. Pemicunya bila suatu saat ada pelanggan yang mengeluh.

### O.11 Bab 10.4 — dasbor web: empat keputusan yang tampak sepele

**Dikerjakan 26 Agustus 2026.** Migrasi `27_daily_stats.sql`, dijalankan
Product Owner lewat Dashboard → SQL Editor (`Success. No rows returned`).

Keempatnya punya sifat yang sama: bila dibalik, hasilnya **grafik yang salah
tanpa satu pun galat**. Tidak ada yang merah, tidak ada yang berhenti — hanya
angka yang keliru dan dipercaya.

**1. Hari dikelompokkan menurut waktu Jakarta, di SERVER.**

`scan_date` bertipe `timestamptz`, disimpan UTC. `scan_date::date` memotong hari
pada pukul 07:00 WIB, sehingga rekaman lembur pukul 23:30 tercatat di hari
berikutnya — grafiknya berbohong tepat pada jam tersibuk gudang.

Zona ditulis mati `'Asia/Jakarta'`, **bukan** diambil dari peramban. Owner di
Jakarta dan packer di Makassar harus melihat grafik yang sama persis saat
saling menelepon; angka yang berubah mengikuti siapa yang membukanya tidak bisa
dijadikan bahan pembicaraan.

**2. Penyaringan pada `scan_date` mentah, bukan pada hasil konversinya.**

`where (scan_date at time zone 'Asia/Jakarta')::date >= ...` terbaca lebih rapi
dan **membuang indeks `idx_videos_tenant_date`**: nilainya harus dihitung dulu
untuk tiap baris sebelum dapat dibandingkan. Konversi hanya boleh muncul di
`group by`.

**3. Hari kosong dikirim sebagai nol (`generate_series`).**

Tanpa itu, hari tanpa rekaman hilang dari hasil dan grafik menyambung
20 Agustus langsung ke 24 Agustus — libur tampak seperti hari kerja biasa.

**4. Perubahan dikirim sebagai angka mentah, bukan persen.**

Naik dari 0 ke 40 bukan "naik 100%" dan bukan "tidak berubah": kenaikannya
tidak terdefinisi. SQL hanya bisa mengirim NULL; yang tahu cara menuliskannya
("belum ada pembanding") adalah layar. `DailyStats._change` mengembalikan
`null` saat pembaginya nol, dan ada tes yang gagal bila suatu hari ada yang
"memperbaikinya" menjadi 0 atau 1.

#### Dua jebakan di sisi Dart

🔴 **`DailyStats.peak` adalah garis tertinggi, BUKAN `packing + return`.**
Grafiknya dua garis terpisah, bukan tumpukan. Memakai jumlah keduanya membuat
batas atas sumbu hampir dua kali lebih tinggi daripada garis tertingginya, dan
seluruh grafik memipih ke dasar — terlihat seperti "bisnis sedang sepi".

🔴 **`@JsonKey(name: 'return')` wajib, dan melanggar dua aturan sekaligus.**
`return` kata kunci Dart sehingga field tidak boleh bernama itu, dan
`field_rename: snake` di `build.yaml` akan mencari `return_count` — kunci yang
tidak pernah dikirim server. Bila anotasinya hilang, **angka return diam-diam
menjadi nol**. Ada tes khusus (`daily_stats_test.dart`) yang gagal bila itu
terjadi.

#### Yang sengaja berbeda dari Beranda, jangan "diseragamkan"

Angka dasbor **tidak akan sama** dengan kartu monitoring Beranda. Beranda
menghitung sejak `token_wallets.period_start` karena menjawab *"jatah saya
tinggal berapa"* (keputusan Product Owner 18 Agustus 2026, uraiannya di
`20_home_stats.sql`); dasbor menghitung per hari kalender karena ia alat
analisis. Keduanya benar untuk pertanyaannya masing-masing.

#### Kondisi kosong sengaja tidak menyembunyikan pemilih rentang

Sebab tersering dasbor kosong bukan "belum pernah merekam", melainkan rentang
7 hari yang kebetulan sepi. Layar kosong yang menyembunyikan tombol 30/90 hari
menghilangkan satu-satunya jalan keluar yang dibutuhkan orang itu. Kartu dan
pemilih tetap berdiri; hanya grafiknya yang diganti ajakan.

#### fl_chart 1.2.0 — API-nya berbeda dari hampir semua contoh di internet

Proyek ini memakai `fl_chart: ^1.2.0`, sementara Bab 4.2 menulis `^0.68.0`
(deviasi lama). Yang berubah dan sempat memakan waktu:

| Contoh lama (0.6x) | 1.2.0 |
|---|---|
| `LineTouchTooltipData(tooltipBgColor: ...)` | `getTooltipColor: (spot) => ...` |
| `SideTitleWidget(axisSide: meta.axisSide)` | `SideTitleWidget(meta: meta)` |

Keduanya diperiksa langsung di `~/AppData/Local/Pub/Cache/hosted/pub.dev/fl_chart-1.2.0/`,
bukan ditebak dari ingatan.

#### Aksesibilitas

Garis return digambar putus-putus (`dashArray: [5, 4]`) dan perubahan memakai
panah naik/turun, bukan warna saja — `palet_warna_dan_tipografi.md` §7 butir 3
dan Bab 9.10. Keterangan grafiknya ikut menggambar pola garisnya, supaya
keterangan dan garis benar-benar terlihat sama.

**358 tes hijau, analyze bersih. Belum diuji di peramban.**

### O.12 Bab 10.5 — tabel Riwayat web

**Dikerjakan 26 Agustus 2026.**

#### Satu alamat, dua halaman — dan itu disengaja

`/history` membangun `WebHistoryPage` di web dan `HistoryPage` di HP.
Alasannya bukan malas menggabungkan: HP memakai gulir tak berujung dan tidak
pernah menampilkan jumlah total, sedangkan tabel bernomor **wajib** tahu
totalnya untuk menggambar halaman terakhir. Satu halaman yang melayani
keduanya berarti HP ikut menanggung perhitungan `count` pada setiap gulir, di
jaringan gudang, untuk angka yang tidak pernah ditampilkan di sana.

Penyaringannya tetap satu (`VideoRepository._applyFilter`) supaya keduanya
tidak dapat menyimpang. Aturan yang disalin akan membuat kedua layar
menampilkan jumlah baris berbeda untuk pencarian yang sama — dan yang
melihatnya akan menduga datanya yang hilang.

#### 🔴 Paginasi WAJIB punya pemecah seri

`.order(kolom).order('id')`. Mengurutkan menurut `type` atau `status`
menghasilkan ribuan baris bernilai sama persis; urutan di antaranya **tidak
dijamin PostgreSQL** dan boleh berbeda pada setiap permintaan. Akibatnya satu
video muncul di halaman 2 **dan** halaman 3, sementara video lain tidak muncul
di mana pun.

Bukti packing yang "hilang" saat dicari adalah kegagalan terburuk aplikasi
ini, dan ia tidak dapat direproduksi dengan sengaja — hanya muncul sebagai
keluhan pelanggan yang tidak masuk akal.

#### Kolom tabel tetangga sengaja tidak dapat diurutkan

Toko dan Packer datang dari embedding PostgREST. Sintaks pengurutan pada
relasi bersarang belum pernah dibuktikan di proyek ini, dan **bila salah
server mengabaikannya lalu mengembalikan urutan bawaan tanpa satu pun pesan**.
Judul yang dapat ditekan tetapi diam saja lebih membingungkan daripada judul
biasa, jadi keduanya tidak dibuat dapat ditekan sama sekali.

#### Kolom dibuang, bukan dipersempit

Tujuh kolom yang dipaksa muat pada 950 px menyisakan ± 100 px per kolom, dan
nomor resi — satu-satunya isi yang tidak boleh terpotong — berakhir sebagai
`JX12…`. Packer dan Durasi hilang lebih dulu di bawah 1180 px.

#### Panel samping memakai halaman detail yang sama dengan HP

`VideoDetailPage(embedded: true)` melepas bilah judulnya. Halaman itu sudah
menangani pemutar, unduh, tautan publik, dan penghapusan beserta seluruh
keadaan gagalnya. `key: ValueKey(videoId)` **wajib**: tanpa itu memilih baris
lain memakai ulang `State` yang sama dan panelnya tetap menampilkan video
sebelumnya.

⚠️ `onClose` juga wajib. Sebagai halaman, penghapusan diakhiri
`Navigator.pop()`; di dalam panel tidak ada apa pun untuk di-*pop*, dan
memanggilnya melempar pengguna keluar dari seluruh cabang Riwayat.

---

### O.13 Dua cacat yang lolos 386 tes karena tidak ada yang rusak

**26 Agustus 2026, terlihat pertama kali di peramban Product Owner.**

1. **Dua kolom pencarian berdiri bersamaan.** Bab 10.3 menaruh *Cari nomor
   resi* di bilah atas; Bab 10.5 memberi tabel saringannya sendiri. Keduanya
   bekerja, keduanya berisi kata yang sama. Keputusan Product Owner: yang di
   bilah atas dibuang, diganti judul halaman — yang juga menjadi satu-satunya
   penanda halaman aktif di bawah 1024 px saat sidebar menjadi laci.

2. **Dasbor berhenti di separuh layar.** Tinggi grafik dulu angka mati 280 px.
   Kini dihitung dari tinggi jendela, dijepit 260..640 px.
   ⚠️ `LayoutBuilder`-nya harus berdiri **di luar** `SingleChildScrollView`:
   di dalamnya tinggi yang tersedia tak terhingga, dan perhitungan apa pun
   akan selalu jatuh ke batas atas.

🔴 **Pelajaran yang layak diulang:** tes hanya menjawab *"apakah ini bekerja
seperti yang diperintahkan"*. Yang tidak dapat dijawabnya: *"apakah
perintahnya masuk akal dilihat manusia"*. Dua cacat di atas lolos 386 tes
karena tidak ada satu pun yang rusak. Terbitkan dan minta Product Owner
melihatnya sendiri sebelum menumpuk bab berikutnya.

---

### O.14 Login Google di web — komentar yang berbohong tentang kodenya

**Beres 26 Agustus 2026, terbukti di peramban Product Owner, dua akun.**

`Env.oauthRedirectUrl` selalu mengembalikan `id.kamelscan.app://login-callback`,
termasuk di web — sementara komentar tepat di atasnya sudah menulis *"mobile
memakai deep link, web memakai URL halaman"* sejak awal.

Gagalnya diam, seperti dua pendahulunya: alamat yang tidak cocok dengan daftar
*Redirect URLs* **tidak menghasilkan pesan galat apa pun**, Supabase memakai
Site URL. Ini kali ketiga jebakan yang sama memakan waktu (13 Agustus,
25 Agustus, dan di sini).

⚠️ Perkiraan awal ± 1–2 jam **terlalu besar**, dan alasannya layak dicatat:
utangnya tertulis sebagai *"butuh OAuth Client ID jenis Web di Google Cloud
Console"*, padahal Client ID itu **sudah ada sejak awal** —
`GOOGLE_WEB_CLIENT_ID` dipakai Android sebagai `serverClientId` (lihat catatan
pada `Env.googleWebClientId`). Utang yang ditulis tanpa diperiksa ulang
menaksir dirinya sendiri terlalu mahal.

#### 🔴 Kenapa tidak ada tes yang menangkapnya selama berminggu-minggu

`Env.kIsWebPlatform` adalah `bool.fromEnvironment('dart.library.js_util')` —
**konstanta waktu kompilasi**. Pada `flutter test` nilainya selalu `false`,
jadi cabang web tidak pernah dijalankan satu kali pun dan tidak ada yang bisa
membantah komentarnya.

Kedua cabang kini berupa `Env.oauthRedirectFor(isWeb:)` yang menerima
parameter, sehingga keduanya dapat diperiksa dari mesin mana pun.

**Aturan umumnya: percabangan `kIsWeb` di dalam getter tidak dapat diuji.
Pisahkan sebagai fungsi yang menerima `isWeb`, lalu getter-nya sekadar
memanggil.** Berlaku untuk setiap `kIsWeb` yang menentukan nilai, bukan hanya
yang ini.

---

### O.15 Layar putih 30 detik saat aplikasi pertama dibuka

**Terukur 26 Agustus 2026, belum dikerjakan.**

| | |
|---|---|
| `main.dart.js` | 4,6 MB mentah · **1,3 MB** setelah dipadatkan |
| Waktu unduh dari jaringan Product Owner | **± 33 detik** |
| Isi `web/index.html` sebelum aplikasi hidup | **kosong sama sekali** |

Badan `web/index.html` hanya berisi `<script src="flutter_bootstrap.js">`.
Selama unduhan berlangsung peramban tidak punya apa pun untuk digambar.

Yang kena hanya pengunjung **pertama kali** — kunjungan berikutnya memakai
simpanan peramban. Tetapi pengunjung pertama kali itu setiap calon pelanggan,
dan layar putih 30 detik sulit dibedakan dari situs rusak.

**Keputusan Product Owner 26 Agustus 2026: diserahkan ke desainer**, karena ia
memang hal pertama yang dilihat pelanggan. Briefnya sudah diberikan, lengkap
dengan lima batasan yang bila dilanggar justru memperparah keadaan — yang
terpenting: **layar tunggu tidak boleh memanggil berkas lain** (gambar, CSS,
huruf), karena pada detik itu tidak ada satu pun dari semuanya yang sudah
terunduh.

⚠️ Memperkecil 4,6 MB itu sendiri adalah pekerjaan lain (± 3–4 jam, hasil
belum pasti) dan **belum diputuskan**. Jangan mengerjakannya diam-diam sambil
memasang layar tunggu.

### O.16 Bab 10.5-B & 10.4-C — layar mengikuti rancangan desainer

**Dikerjakan 26–28 Agustus 2026.** Rancangannya berupa SVG di `desain/`,
dibuat desainer **sebelum** kedua layar itu dibangun. Angkanya diambil apa
adanya; yang berbeda ditulis di sini beserta alasannya.

#### Tabel Riwayat

🔴 **Urutan kolom yang dibuang saat ruang menyempit ditetapkan desainer dan
bukan selera:** Aksi → Durasi → Packer → Toko. Resi, Tipe, Tanggal, dan Status
**tidak pernah** dibuang. Keempatnya yang dibutuhkan saat menangani komplain,
dan komplain adalah satu-satunya alasan halaman itu dibuka dalam keadaan
terburu-buru.

Lebar kolomnya dipakai sebagai **perbandingan**, bukan ukuran mati, supaya
tabelnya tumbuh mengisi layar lebar tanpa menyisakan jalur kosong di kanan.

**Kolom yang bisa diurutkan tapi belum dipakai diberi panah dua arah abu-abu.**
Tanpa itu ia terlihat persis sama dengan kolom yang memang tidak dapat
diurutkan — dan pengurutan yang tidak pernah ditemukan sama saja dengan
pengurutan yang tidak ada.

**Tipe dibedakan TIGA cara:** Packing chip berisi penuh, Retur chip bergaris
tepi, masing-masing berikon dan berteks. Biru dan ungu adalah pasangan yang
paling sering tertukar bagi pengguna buta warna.

⚠️ Status `uploaded` dulu satu-satunya yang ikonnya `null`, sehingga justru
menjadi satu-satunya yang hanya dapat dibedakan lewat warna. Kini keenam
status berikon, tanpa syarat.

#### Dasbor

Grafik berubah dari **garis** menjadi **batang bertumpuk**. Konsekuensi yang
mudah terlewat: puncak sumbunya menjadi **jumlah** packing + retur, bukan yang
tertinggi di antaranya. Pada grafik garis justru sebaliknya, dan salah memilih
membuat batang tertinggi terpotong di ujung atas.

**90 hari dikelompokkan per minggu menjadi 13 batang.** Keputusan **tampilan** —
RPC tetap mengembalikan harian, dan pengelompokannya terjadi di Flutter supaya
server tidak perlu tahu apa pun tentang lebar layar.

🔴 **Dua kartu menyimpang dari Bab 10.4, dan desainer sendiri yang menandainya.**
Dokumen meminta keempat kartu membandingkan dengan periode sebelumnya. Untuk
*Token Tersedia* dan *Menunggu Unggah* itu tidak bermakna: keduanya keadaan
**saat ini**, bukan jumlah satu periode. Diganti perkiraan sisa hari dan umur
antrean tertua.

⚠️ **Arsir tidak dapat dikerjakan.** Desainer meminta segmen Retur diarsir agar
batas antar segmen tetap terlihat pada layar hitam-putih; fl_chart tidak
menyediakan pola arsir. Diganti **garis tepi** pada segmen itu — tujuan yang
sama dengan cara yang tersedia.

#### Yang TIDAK diikuti, atas keputusan Product Owner

Kedua rancangan menaruh kolom **Cari nomor resi** kembali di bilah atas.
Gambarnya dibuat sebelum keputusan 26 Agustus 2026 yang membuangnya dari sana
(lihat O.13). **Keputusan Product Owner berlaku di atas gambar.**

Bentuk grafik dibiarkan apa adanya atas keputusan Product Owner 28 Agustus
2026, sesudah ia melihatnya di peramban dan mengatakan sulit dibaca. Sebabnya
bukan bentuknya melainkan datanya: 4 video dalam 7 hari pada grafik selebar
1600 px. Jangan mengubah bentuknya sampai gudangnya benar-benar dipakai
sehari-hari.

⚠️ **Kedua grafik dasbor menghitung TANGGAL YANG BERBEDA** — video menurut
`scan_date` (kapan direkam), token menurut `token_ledger.created_at` (kapan
unggahannya berhasil). Video yang direkam malam lalu terunggah besok paginya
muncul pada dua tanggal berbeda. Selisihnya benar; yang salah adalah tidak
menjelaskannya, dan Product Owner mengiranya kerusakan. Kini keduanya
berketerangan.

---

## P. Bab 12: pembayaran, aktivasi, dan panel Admin

### P.1 🔴 Langganan yang dibayar tidak pernah berlaku

**Beres 26 Agustus 2026.** Uraiannya di `28_activate_subscription.sql`.

Tidak ada apa pun di server yang bereaksi ketika `subscriptions.status`
menjadi `paid`. `AdminRepository.approvePayment()` sudah ada di Flutter sejak
lama, dan komentarnya berbunyi *"penyesuaian tier, periode langganan, dan reset
saldo token dilakukan trigger di server"* — trigger yang **tidak pernah
dibuat**.

Gagalnya diam dan mahal sekaligus: menyetujui pembayaran mengubah status
menjadi `paid` tanpa keluhan apa pun, lalu **tidak terjadi apa-apa**. Product
Owner mentransfer uang sungguhan 22 Agustus 2026 dan layarnya berhenti di
*"Menunggu verifikasi"* selama empat hari.

**Pelajarannya bukan soal trigger.** Komentar yang menjanjikan pekerjaan yang
belum ada lebih berbahaya daripada tidak ada komentar: ia membuat orang
berikutnya yakin bagian itu sudah selesai, sehingga tidak ada yang
memeriksanya. Bentuk yang sama muncul lagi pada `Env.oauthRedirectUrl` (O.14).

#### Empat keputusan di dalam triggernya

1. **Trigger, bukan Edge Function.** Trigger **tidak dapat dilewati**: siapa
   pun yang mengubah status menjadi `paid` — aplikasi Admin, SQL Editor, atau
   perbaikan darurat suatu malam — tetap menghasilkan tenant yang benar-benar
   aktif.
2. **`before update`, bukan `after`.** Barisnya sendiri ikut diisi
   (`period_start`, `period_end`, `paid_at`); pada `after` itu menuntut
   `update` kedua ke tabel yang sama, yang memanggil trigger ini lagi.
3. **Kuota dibaca dari `platform_settings.pricing`** (Bab 7.1), tidak ditulis
   mati.
4. 🔴 **Pricing yang hilang MEMBATALKAN aktivasi, bukan diberi nol.**
   `coalesce(..., 0)` menghasilkan dompet bersaldo nol — pelanggan yang baru
   membayar tidak dapat merekam satu video pun, tanpa satu pun pesan. Lebih
   baik menolak dengan galat yang jelas: uangnya sudah masuk, dan Admin masih
   bisa memperbaiki pengaturannya lalu menyetujui ulang.

⚠️ Hanya bereaksi pada **perpindahan** ke `paid`. Menyimpan ulang baris yang
sudah lunas tidak mengisi ulang dompet — itu jalan pintas menuju token gratis
tanpa batas.

⚠️ Periode dihitung dari **sekarang**, bukan disambung dari sisa periode lama.
Benar untuk uji coba; perpanjangan yang dibayar lebih awal akan kehilangan sisa
harinya. Belum pernah terjadi. **Aturan perpanjangan adalah keputusan dagang,
bukan teknis** — jangan mengubahnya sendiri.

### P.2 🔴 Dua cacat panel Admin yang hanya ketahuan dengan benar-benar masuk

**28 Agustus 2026.** Keduanya lolos 438 tes, dengan alasan yang sama seperti
O.13: tidak ada yang rusak.

**1. Panel admin tidak dapat dicapai.** Halaman Verifikasi Pembayaran selesai
dibangun, tetapi `_homeFor(admin)` mendaratkan admin di `/admin` yang masih
placeholder — dan tidak ada satu pun tautan menuju halaman itu. Satu-satunya
cara membukanya adalah mengetik alamatnya.

*Halaman yang tidak dapat dicapai bukan halaman yang selesai.*

**2. Admin terkurung, tidak bisa keluar.** Rute admin berdiri **di luar**
`StatefulShellRoute`, jadi tidak ada menu bawah maupun sidebar. Sementara
`RouteGuards` melempar siapa pun yang sudah masuk kembali ke beranda perannya
— termasuk dari `/login`. Tanpa tombol Keluar, tidak ada jalan kembali ke akun
sendiri selain membersihkan simpanan peramban.

🔴 Yang kedua lebih berbahaya dan lebih mudah terlewat: **seorang programmer
yang menguji dengan akun admin miliknya sendiri tidak akan pernah
merasakannya.** Ia baru terasa oleh orang yang punya akun lain dan ingin
kembali ke sana.

**Aturan yang lahir dari sini: setiap kali menambah layar yang berdiri di luar
rangka aplikasi, periksa dua hal — bagaimana orang sampai ke sana, dan
bagaimana ia keluar.**

### P.3 Membuat akun Admin — dua jebakan

`users.tenant_id` **NOT NULL**, jadi admin pun harus punya tenant. Akun baru
selalu lahir sebagai `owner` beserta tenant uji cobanya sendiri; promosi ke
admin dilakukan sesudahnya dengan `update public.users set role = 'admin'`.
Tenant sisanya tidak terpakai dan tidak mengganggu.

🔴 **Alias Gmail TIDAK BISA dipakai.** `normalize_email` (Bab 7.5) membuang
titik dan segala yang setelah `+` untuk domain gmail, dan `email_normalized`
unik. Jadi `nama+admin@gmail.com` dianggap **sama persis** dengan
`nama@gmail.com` dan ditolak sebagai duplikat. Aturan anti-penyalahgunaan itu
mengenai pemiliknya sendiri saat hendak membuat akun admin.

⚠️ Peran dibawa di dalam **JWT** lewat Auth Hook. Sesudah `role` diubah,
akunnya **wajib keluar lalu masuk lagi** — sebelum itu aplikasi masih
menganggapnya peran lama. Gejalanya sama persis dengan tier yang baru naik
tetapi masih tertulis "Uji Coba".

✅ Admin **dikecualikan** dari *Lengkapi Profil* (`needsProfileCompletion`
memeriksa `isOwner`), jadi akun admin yang dibuat lewat Dashboard tidak
tersangkut di formulir nomor HP.

### P.4 Yang belum pernah diuji pada halaman ini

Tombol **Setujui** dan **Tolak** belum pernah dijalankan pada baris sungguhan
— daftarnya kosong saat diuji. Yang terbukti baru *"halamannya jalan"*, bukan
*"tombolnya bekerja"*.

Cara mengujinya tanpa uang berpindah: dari akun Owner, buka Pembayaran → pilih
paket → unggah bukti apa pun; lalu dari akun admin tekan **Tolak**. Menolak
hanya menutup barisnya dan tidak menyentuh langganan yang sudah aktif.

---

## Q. Pembersihan 29 Agustus 2026

Tiga hal yang dihapus, seluruhnya atas keputusan Product Owner.

**1. "Bersihkan cache" dibuang dari web.** Ia selalu menjawab *"Tidak ada
berkas sementara untuk dihapus"* — bukan karena bersih, melainkan karena
peramban memang tidak menyimpan berkas video sementara.
`getTemporaryDirectory()` melempar di web dan `on Object catch` menelannya,
sehingga tombolnya **tidak melakukan apa pun dan mengaku berhasil**.

**2. Rute mati `/record/result` dibuang.** Terdaftar di router lengkap dengan
halaman placeholder, tetapi tidak ada satu pun kode yang menuju ke sana — layar
kamera menangani hasilnya sendiri.

**3. 🔴 Logo watermark dihapus — dan ternyata tidak pernah ada.**

Yang dihapus **hanya logonya**. Watermark yang terbakar ke video — GPS,
tanggal, nama toko, nomor resi — utuh seluruhnya, begitu pula posisi dan
transparansinya (keduanya dipakai teksnya).

Temuan saat mengerjakannya: `watermark_command.dart` **sama sekali tidak punya
lapisan gambar**; isinya murni teks. Kolom `watermark_logo_url` hanya disimpan
dan dibaca, dan `hasCustomLogo` tidak pernah dipanggil dari mana pun. Yang
dihapus karena itu adalah **janji yang tidak pernah ditepati** — termasuk
barisnya di kartu harga, yang mengiklankannya sebagai keunggulan paket Pro.

⚠️ Kolom `tenant_settings.watermark_logo_url` di database **sengaja
dibiarkan**. Menghapus kolom tidak dapat dibatalkan, dan tidak diminta. Ia
hanya berhenti diisi.

Kelompok **Merek** ikut hilang karena tinggal berisi satu sakelar GPS, dan
sakelar itu pindah ke Perekaman. Judul kelompok yang isinya tidak lagi sesuai
namanya terbaca seperti judul yang lupa dihapus.

🔴 **Pelajaran yang berulang di ketiganya:** fitur yang tampak ada tetapi tidak
mengerjakan apa pun lebih merugikan daripada fitur yang memang tidak ada. Ia
mengundang orang memakainya, lalu diam. Ketiganya juga punya bentuk yang sama
dengan P.1 dan O.14 — sesuatu yang **tertulis** ada tetapi tidak pernah
dikerjakan kodenya.
