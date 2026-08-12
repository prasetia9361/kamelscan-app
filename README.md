# KamelScan

Aplikasi SaaS B2B yang merekam proses pengemasan (*packing*) dan pengembalian
(*return*) barang e-commerce secara otomatis, dipicu pemindaian nomor resi.

Dokumen acuan utama: **`panduan_dokumentasi.md`** (tidak di-commit — minta ke
Product Owner). Nomor bab yang disebut di komentar kode merujuk ke sana.

> **Status repo saat ini: Bab 0–4 selesai.** Yang ada di sini adalah kerangka
> arsitektur MVVM, tech stack, dan pemisahan platform. Layar-layar aplikasi
> (Bab 6–11) belum dikerjakan — lihat [Yang belum dikerjakan](#yang-belum-dikerjakan).

---

## Menjalankan proyek

### 1. Prasyarat

| Kebutuhan | Versi yang dipakai |
|---|---|
| Flutter | 3.44.8 (stable) |
| Dart | 3.12.2 |
| Android compileSdk | 35+ (syarat `permission_handler` 13) |

### 2. Siapkan variabel lingkungan

🔴 **Tidak ada key yang boleh ditulis di dalam kode** (Bab 4.4).

```bash
cp env.example.json env.dev.json
```

Isi nilainya, lalu jalankan:

```bash
flutter run --dart-define-from-file=env.dev.json
```

`env.dev.json`, `env.staging.json`, dan `env.prod.json` sudah masuk `.gitignore`.
Hanya `env.example.json` yang boleh masuk repo.

> 🔴 `SUPABASE_SERVICE_ROLE_KEY` dan `MIDTRANS_SERVER_KEY` **tidak boleh** ada di
> aplikasi Flutter dalam bentuk apa pun. Keduanya dapat mengabaikan seluruh RLS
> dan hanya boleh berada di Supabase Edge Function secrets.

### 3. Code generation

Model `freezed`, provider Riverpod, dan tabel drift memakai `build_runner`:

```bash
dart run build_runner build
```

Selama pengembangan:

```bash
dart run build_runner watch
```

### 4. Build

```bash
flutter build apk --dart-define-from-file=env.prod.json
```

Web — aplikasi Flutter berada di `/app`, landing page statis desainer di `/`
(Bab 10.2):

```bash
flutter build web --base-href /app/ --dart-define-from-file=env.prod.json
```

### 5. Pemeriksaan sebelum commit

```bash
flutter analyze && flutter test
```

---

## Struktur folder

Mengikuti Bab 3.2 — tiga folder utama: `core`, `pages`, `navigation`.

```
lib/
├── main.dart                  # bootstrap: Sentry → Supabase → worker → runApp
├── app.dart                   # MaterialApp.router, tema, lokalisasi
│
├── core/
│   ├── config/                # env, konstanta, aturan tier
│   ├── models/                # freezed + json_serializable, immutable
│   ├── services/              # pembungkus tipis SDK pihak ketiga
│   ├── workers/               # WorkManager & pengecek retensi
│   ├── repositories/          # sumber kebenaran data untuk ViewModel
│   ├── providers/             # provider Riverpod global (DI)
│   ├── utils/                 # Result, AppFailure, validator, formatter
│   ├── theme/                 # tema terang & gelap
│   └── widgets/               # komponen bersama (error, kosong, skeleton)
│
├── pages/                     # 1 folder = 1 layar
├── navigation/                # GoRouter, guard, shell mobile & web
└── l10n/                      # app_id.arb (sumber) + app_en.arb
```

## Aturan yang tidak boleh dilanggar (Bab 3.1)

1. **View tidak pernah memanggil Repository atau Supabase langsung.** Selalu
   lewat ViewModel.
2. **ViewModel tidak pernah mengimpor `material.dart`.** Harus dapat diuji tanpa
   widget test.
3. **Repository tidak menyimpan state.** Ia hanya menerjemahkan data mentah
   menjadi Model.
4. **Model bersifat immutable** (`freezed`). Tidak ada setter.
5. **Navigasi hanya lewat GoRouter.** Tidak ada `Navigator.push` di widget
   bisnis.
6. **Setiap layar berdata wajib punya empat kondisi:** loading, error, kosong,
   berisi. Layar yang hanya menangani "berisi" ditolak saat review (Bab 3.4).
7. **Tidak ada string yang dilihat pengguna ditulis langsung di widget.** Semua
   lewat `context.l10n.<kunci>` (Bab 9.11).

## Dua lapisan hak akses (Bab 2.3)

- **UI (Flutter)** — menyembunyikan menu/tombol. Ini kenyamanan, **bukan
  keamanan**.
- **Database (RLS Supabase)** — penegakan sesungguhnya. Setiap policy diuji
  dengan asumsi penyerang memakai JWT valid dan memanggil API langsung.

Kegagalan paling umum pada aplikasi multi-tenant adalah menegakkan aturan hanya
di UI. Jangan lakukan itu.

## Pemisahan platform (Bab 4.3)

Paket berikut tidak berjalan di Flutter Web dan sudah dipisah dengan
*conditional import* sejak Minggu 1: `ffmpeg_kit_flutter_new`, `workmanager`,
`drift`, `flutter_local_notifications`.

Polanya:

```
core/services/video_processor.dart          # antarmuka abstrak + pabrik
core/services/video_processor_mobile.dart   # implementasi asli
core/services/video_processor_stub.dart     # penolakan sopan di web
```

```dart
import 'video_processor_stub.dart'
    if (dart.library.io) 'video_processor_mobile.dart';
```

Berlaku sama untuk `local_db_service`, `notification_service`, dan
`workers/upload_worker`. `flutter build web` sudah diverifikasi berhasil.

## Deviasi library

Beberapa versi di Bab 4.2 tidak dapat di-resolve pada Dart 3.12, dan dua paket
sudah ditarik dari pub.dev. Seluruh penyimpangan beserta alasan dan dampak
kodenya dicatat di **[`DEVIASI_LIBRARY.md`](DEVIASI_LIBRARY.md)** — baca sebelum
menaikkan atau menurunkan versi apa pun.

Perubahan terbesar yang mempengaruhi cara menulis kode:

```dart
// freezed 3 mewajibkan `abstract`:
@freezed
abstract class Shop with _$Shop { ... }

// riverpod 3 memakai `Ref` polos, tanpa parameter tipe:
@riverpod
ShopRepository shopRepository(Ref ref) => ...;
```

---

## Yang belum dikerjakan

| Bagian | Bab | Status |
|---|---|---|
| Skema database & RLS | 5 | Belum — `supabase/migrations/` masih kosong |
| Autentikasi & registrasi | 6 | Kerangka service ada, alur belum |
| Trigger token & kuota | 7 | Aturan sudah di `TierConfig`, trigger server belum |
| Pipeline perekaman & upload | 8 | Antarmuka & antrian ada, pipeline belum |
| Layar mobile | 9 | Penanda `PageScaffoldPlaceholder` |
| Layar web | 10 | Penanda `PageScaffoldPlaceholder` |
| Panel admin | 11 | Repository ada, layar belum |
| Midtrans | 12 | Antarmuka `PaymentService` saja |

Setiap layar yang masih berupa penanda menampilkan nomor bab yang menetapkannya,
sehingga tidak ada yang tertukar antara "belum dikerjakan" dan "sudah jadi".

## Catatan untuk pengerjaan berikutnya

1. **Palet warna desainer dibutuhkan Minggu 1**, bukan belakangan. Sementara ini
   `AppColors.seed` memakai `Colors.indigo` (Bab 9.10). Mengganti warna di 30
   layar pada Minggu 5 adalah pemborosan yang bisa dihindari.
2. **Verifikasi filter `drawtext` pada `ffmpeg_kit_flutter_new`** sebelum
   pipeline watermark Bab 8 dibangun di atasnya. Bila tidak tersedia, rencana
   cadangannya jauh lebih mahal — jangan ditunda.
3. **`google_sign_in` v7 memakai API yang berbeda total dari v6** yang ditulis di
   Bab 4.2. Perhitungkan saat mengerjakan Bab 6.
