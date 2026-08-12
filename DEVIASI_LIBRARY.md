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
