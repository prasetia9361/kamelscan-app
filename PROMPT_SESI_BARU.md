# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Tugas worktree ini: mengerjakan Bab 9** (UI/UX aplikasi mobile), berikut satu
utang yang dibawa dari Bab 8 — **Bab 8.8**, yang rumah sebenarnya ada di
Bab 9.4.

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
  belum diuji, katakan belum diuji. Kalau tidak tahu sebabnya, katakan tidak
  tahu — jangan menebak lalu menyuruh saya build berkali-kali.
- **Jangan ubah keputusan yang sudah diambil** tanpa memberi tahu saya lebih
  dulu.

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang
  sedang dikerjakan sebelum menulis kode.**
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Seluruh penyimpangan
  beserta alasannya, dan jebakan yang sudah memakan waktu. Bagian **J** (kamera)
  dan **L** (pipeline Bab 8.5–8.7) panjang dan penting.
- `supabase/README.md` — skema database, RLS, jebakan Supabase, hasil pengujian.
- `palet_warna_dan_tipografi.md` — palet resmi.
- `dataapp.md` — seluruh kredensial. Ter-gitignore. **Jangan pernah menuliskan
  isinya ke berkas yang masuk git.**

⚠️ **`panduan_dokumentasi.md` dan `dataapp.md` juga ter-gitignore**, jadi
worktree baru tidak memilikinya. Salin dari `E:\kamelscan\` bersama
`env.dev.json`.

## Lingkungan

| | |
|---|---|
| Flutter | `E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat` (tidak ada di PATH) |
| Dart | `E:\flutter_sdk\flutter_3.44.8\bin\dart.bat` |
| JDK | `$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'` |
| adb | `C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe` (tidak ada di PATH) |
| Perangkat uji | Xiaomi Redmi Note 9, serial `7744ca520408` |

**🔴 Jangan pernah menjalankan `flutter run` polos.** Tanpa
`--dart-define-from-file=env.dev.json` aplikasi berhenti di layar "Konfigurasi
belum lengkap", dan lebih buruk: kernel Dart tanpa kredensial ikut tersimpan di
cache sehingga `flutter build` berikutnya diam-diam memakainya. Pakai
`.\run.ps1`. Bila terlanjur: hapus `.dart_tool/flutter_build` lalu bangun ulang.

**Mode profile** — `.\run.ps1 -Profile`

🔴 **Mode debug SENGAJA lambat** dan pratinjau kamera akan terasa patah-patah di
sana. Itu **bukan cacat produk**. Terukur di Redmi Note 9: watermark video 30
detik butuh 32 detik di debug, hanya 17 detik di profile.

Bila saya melaporkan "patah-patah", tanyakan dulu **mode apa yang dipakai**
sebelum menyelidiki apa pun.

**Worktree baru wajib dibangkitkan kodenya lebih dulu**, kalau tidak
`flutter analyze` melaporkan ratusan error yang tidak ada hubungannya dengan
kode:

```powershell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n
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

Yang sudah terpasang: `create-packer`, `get-upload-url`, `resolve-username`.

## Sudah selesai dan TERBUKTI jalan

**Bab 0–4** — arsitektur MVVM, `analyze` bersih.

**Bab 5** — 20 migrasi terpasang. RLS diuji dua tenant lewat JWT asli:
kebocoran nol, kenaikan role ditolak `42501`.

**Bab 6** — registrasi, verifikasi email (Resend), login email + Google,
username unik, packer + batas 5, persetujuan S&K, layar Lengkapi Profil.

**Bab 7** — aturan kuota token & masa langganan teruji.

**Bab 8.1–8.7 dan 8.9 — SELESAI dan terbukti di perangkat.** Rantai lengkapnya
dijalankan di Redmi Note 9 pada 17 Agustus 2026:

- Layar kamera penuh, pemindaian **selama** merekam, perekaman beruntun tanpa
  tombol, pratinjau tegak dan lancar
- Watermark: **isinya dilihat langsung** pada berkas di R2 — GPS, nama toko,
  waktu, nomor resi keempatnya terbaca. Waktu 19.59 WIB cocok tepat dengan log
  unggah 12:59 UTC, tanpa keterangan *"waktu belum terverifikasi"*
- Rasio watermark di profile: **0,42x sendirian, 0,61–0,81x beruntun**. Pakai
  angka yang beruntun untuk merencanakan
- Video sampai di R2 lewat aplikasi; `token_ledger` memotong **tepat satu token
  per video** (100 → 99 → 98)
- Isolate unggah latar belakang hidup, sesi Supabase pulih di dalamnya, drift
  terbuka berdampingan tanpa saling mengunci

Seluruh riwayat, angka, dan dua cacat yang ditemukan di dalamnya ada di
`DEVIASI_LIBRARY.md` **bagian L**. Bagian **L.9** wajib dibaca sebelum menyentuh
`ServerClock` atau `uploadPipeline`.

## Utang yang dibawa masuk ke worktree ini

### 1. Bab 8.8 — pemutaran, unduh, dan berbagi (BELUM ADA)

Rumahnya di **Bab 9.4 (Riwayat)**, karena di situlah tombol putar, unduh, dan
bagikan sebenarnya tinggal. Di sisi aplikasi metodenya **sudah ada**
(`VideoRepository.getPlaybackUrl`, `.createPublicLink`), tetapi Edge Function
yang dipanggilnya **belum dibuat sama sekali** — menekan tombol putar hari ini
akan gagal.

Yang harus dibuat:

- Edge Function `get-video-url` — presigned GET berumur 15 menit.
  ⚠️ Bab 2.2 catatan 5: **tolak pemanggil dengan `app_role = 'admin'`.** Admin
  platform hanya boleh melihat metadata, bukan isi video pelanggan.
- Edge Function `create-public-link` — `public_token` acak 32 karakter,
  `public_expires_at` = `expires_at` video. Hanya Owner.
- Halaman publik `/v/{token}` — pemutar + metadata, **tanpa login**, menampilkan
  sisa masa berlaku tautan (pusat resolusi marketplace kadang membuka tautannya
  beberapa hari kemudian).
- Unduh (`dio.download`) dan berbagi (`share_plus`).

✅ **Tidak perlu migrasi baru.** Kolom `public_token` (unik),
`public_expires_at`, dan indeks parsial `idx_videos_public` sudah ada sejak
migrasi `05_package_videos.sql`. Yang kurang murni Edge Function, halaman
publik, dan tombolnya di Riwayat.

### 2. Sakelar "unggah lewat data seluler" menumpang di halaman Akun

Rumah sebenarnya **Bab 9.7 (Setting)**. Ia dipasang lebih awal di halaman Akun
pada 17 Agustus 2026 karena tanpa layar untuk menyalakannya, antrian unggah
tidak dapat diuji sama sekali di perangkat yang hanya punya sinyal seluler.
Pindahkan ke Setting saat Bab 9.7 dikerjakan — nilainya ada di
`SharedPreferences`, jadi kepindahan itu tidak menghilangkan pilihan pengguna.
Lihat `DEVIASI_LIBRARY.md` **L.7**.

### 3. Dua hal yang belum terbukti dari Bab 8

- **Satu video sungguhan lewat jalur unggah latar belakang.** Isolatenya sudah
  terbukti hidup dan berwenang, tetapi antriannya selalu keburu dihabiskan jalur
  aplikasi-terbuka. Prosedur pengujiannya di `DEVIASI_LIBRARY.md` **L.8**;
  butuh Wi-Fi.
- **Dugaan Product Owner soal pratinjau patah-patah.** Beliau mengamati
  patah-patah muncul saat antrian menumpuk (sakelar seluler mati, tidak ada
  Wi-Fi). Jejak yang menjawabnya sudah ditanam dan tinggal dibaca:

  ```
  adb logcat -v time | findstr "ditunda"
  ```

  Sering muncul = FFmpeg masih berjalan tiap kali perekaman dimulai, artinya
  dugaan itu benar. Tidak muncul sama sekali = penyebabnya lain.

## Tugas worktree ini: Bab 9

Seluruh halamannya **sudah ada sebagai placeholder** dan sudah terhubung ke
router; yang belum ada adalah isinya. Kerangka layar (bottom nav, app bar,
tombol Rekam mengambang) sudah berdiri.

| Bagian | Keadaan |
|---|---|
| 9.1 Kerangka layar | Sudah berdiri |
| 9.2 Home | 🔴 Placeholder — kartu monitoring & menu utama belum ada |
| 9.3 Alur perekaman | Sudah selesai di Bab 8 |
| 9.4 Riwayat | 🔴 Placeholder — **plus seluruh Bab 8.8** |
| 9.5 Toko | 🔴 Placeholder |
| 9.6 Akun | Baru tombol Keluar + sakelar seluler yang menumpang |
| 9.7 Setting | 🔴 Placeholder — **rumah sakelar seluler** |
| 9.8 Pembayaran | 🔴 Placeholder |
| 9.9 Tutorial | 🔴 Placeholder |
| 9.10 Aturan desain umum | Berlaku terus |
| 9.11 Dwibahasa | Kerangkanya jalan; tiap teks baru wajib lewat ARB |

**Mulai dari 9.2 (Home).** Alasannya bukan urutan nomor: Home adalah satu-satunya
tempat Product Owner dapat melihat saldo token dan jumlah video tanpa membuka
database. Selama ia kosong, tiap pengujian menuntut saya membuka `psql`.

⚠️ Bab 9.1 menyembunyikan menu **Toko** untuk role Packer — **disembunyikan,
bukan dinonaktifkan**. Pakai `IndexedStack` dengan daftar tab yang dibangun dari
role agar indeks tidak bergeser dan salah arah.

## Keputusan Product Owner yang WAJIB dipatuhi

**1. Aturan berhenti perekaman** (menyimpang dari Bab 8.3.2):
1. Pindai pertama → mulai merekam
2. 5 detik pertama → pemindaian belum bisa menghentikan
3. Setelah 5 detik → pindai resi **yang sama** menghentikan
4. Resi **berbeda** → perekaman lanjut, disertai pesan *"Masih merekam X"*
5. **Tombol Berhenti selalu hidup**; bila ditekan < 5 detik muncul konfirmasi

**2. Perekaman beruntun tanpa tombol** (menyimpang dari Bab 8.3): panel
"Rekaman selesai" beserta tombolnya dihapus; pemindaian hidup lagi sendiri.

🔴 **Pengamannya wajib ikut ada.** `_recordedInSession` menolak resi yang sudah
selesai direkam selama layar rekam terbuka. Menghapusnya berarti merekam ulang
paket yang sama berkali-kali dan membakar token pelanggan.

**3. Arsitektur kamera:** `camera` + `google_mlkit_barcode_scanning` satu-satunya
pemilik kamera.

**4.** Tanda *waktu belum terverifikasi* hidup di kolom
`package_videos.time_verified` **dan** metadata berkas, **dan** ikut terbakar ke
gambar.

**5.** Sakelar "unggah lewat data seluler" disimpan di HP (`SharedPreferences`),
bukan di server — preferensi milik satu perangkat.

**6.** FFmpeg berjalan **di sela antar-paket**, satu per satu, dijeda saat
merekam.

**7. Layar rekam, diputuskan 17 Agustus 2026:**

- **Blok gelap di luar bingkai pindai dicabut.** Packer memindai *sambil
  mengemas*; yang digelapkan justru barang yang sedang ia kerjakan.
  🔴 Jangan mengembalikannya tanpa bertanya lebih dulu.
- **Isi watermark ditampilkan selama merekam**, di posisi yang sama seperti yang
  akan terbakar. Isinya disusun `WatermarkCommand.buildLines` — penyusun yang
  **sama** dengan yang dipakai FFmpeg. Jangan menyusunnya ulang di lapisan
  tampilan.
- **Tombol Berhenti bulat seperti tombol rana kamera**, berdiri sendiri sebagai
  lapisan di `Stack`. Lihat jebakan 16 di bawah.

## Jebakan yang sudah memakan waktu

1. `flutter run` polos meracuni cache kernel — lihat di atas
2. Ekstensi Supabase ada di schema `extensions`, bukan `public`. Pakai
   `gen_random_uuid()`, bukan `uuid_generate_v4()`
3. Redirect URL yang tidak cocok **tidak menghasilkan error** — Supabase
   diam-diam memakai Site URL
4. Auth Hook wajib aktif, kalau tidak semua tabel mengembalikan **nol baris**
   tanpa pesan apa pun
5. Bucket R2 `kamelscan-videos`, bukan `scanproof-videos` seperti di dokumen
6. `AppColors` adalah `ThemeExtension`, diakses lewat
   `Theme.of(context).extension<AppColors>()!`
7. Periksa API widget/paket sebelum memakainya — beberapa kali ditebak dan salah

**Jebakan pemasangan APK (MIUI):**

8. `adb install` ditolak `INSTALL_FAILED_USER_RESTRICTED`. Pesannya menyesatkan.
   Dua sebab: HP tanpa internet (MIUI memverifikasi ke server Xiaomi dulu), atau
   tidak ada yang menekan *Izinkan* di layar HP. Claude tidak bisa menekannya;
   minta saya menjalankan `.\run.ps1` sendiri — itu lebih cepat.
9. `adb install` mengembalikan **exit code 0 walaupun gagal**. Baca keluarannya.
10. **Memasang ulang APK menghapus cache aplikasi**, termasuk rekaman mentah.

**Jebakan diagnosis — dua di antaranya masing-masing membuang satu sesi penuh:**

11. 🔴 **`AppLogger` tidak pernah sampai ke logcat.** Ia memakai
    `dart:developer`, yang hanya muncul di terminal `flutter run`. Untuk jejak
    yang perlu dibaca dari perangkat, pakai `debugPrint` (tembus sebagai
    `I/flutter`).

    **Aturan yang lahir dari sini, dan berlaku untuk seluruh jejak baru: bila
    jalur berhasilnya dicetak dengan `debugPrint`, jalur gagalnya WAJIB ikut.**
    17 Agustus 2026 enam video keluar bertanda "waktu belum terverifikasi" dan
    tidak ada satu pun baris yang menjelaskan sebabnya — karena hanya
    keberhasilan yang tercetak. Rinciannya di `DEVIASI_LIBRARY.md` L.9.

12. `flutter analyze` di akar melaporkan error dari `tool/db_migrate`. Pakai
    `flutter analyze lib`.

13. **Periksa worktree sebelum mempercayai hasil `analyze`/`test`.** Sesi pernah
    terlempar ke worktree lain diam-diam, dan hasil dari checkout yang salah
    sempat dilaporkan sebagai hasil pekerjaan. Jalur berkas pada keluaran tes
    menyebutkan worktree-nya — baca itu. Jumlah tes juga penanda cepat.

**Jebakan khusus layar kamera — baca `DEVIASI_LIBRARY.md` bagian J sebelum
menyentuhnya:**

14. **`CameraPreview` sengaja TIDAK dipakai.** Ia mengunci bentuk kotaknya pada
    `previewSize` yang hanya diisi sekali, sehingga gambar melar 2,25x saat
    merekam. Putaran bawaannya direplikasi manual di `_preAppliedQuarterTurns` —
    jangan dihapus.
15. 🔴 **Widget berat di layar rekam dibuat sekali di `State`, bukan di dalam
    `build`.** Selama merekam, pencatat waktu berdetak 5x per detik. Widget yang
    dibuat ulang tiap kali membuat pratinjau patah-patah, dan **gejalanya akan
    tampak seperti masalah kamera** — bukan masalah widget. Ini sudah pernah
    menyesatkan penyelidikan sampai tiga dugaan salah.

    Pola yang benar: `late final Widget _x = ...` di `State`, lalu widget itu
    berlangganan sendiri lewat `ref.watch(provider.select(...))`.
16. **Tombol Berhenti berdiri sendiri sebagai lapisan di `Stack`, bukan di dalam
    `_BottomBar`.** Saat masih berada di `Row` berisi dua `Spacer` di baris
    bawah, tombol itu **tidak pernah tergambar sama sekali** — padahal tombol
    senter di baris yang sama tampil, dan tiga elemen lain yang dihidupkan
    syarat yang sama persis (`isRecording`) juga tampil. Sebabnya tidak pernah
    ditemukan. Jangan mengembalikannya ke dalam `_BottomBar`.

    Jejak `KAMELSCAN_UI tombol Berhenti tampil=…` sengaja permanen. Jangan
    dihapus sebagai sisa lupa dibersihkan.
17. **Jangan menambahkan `clipBehavior` pada widget yang menumpang di atas
    tekstur kamera** tanpa alasan kuat. Lapisan pemotong di atas tekstur adalah
    tersangka pertama saat kelancaran turun.

## Beban perangkat — sudah diselidiki, jangan diulang

Pratinjau pernah patah-patah. Tiga dugaan **semuanya salah** dan sudah
dibuktikan salah lewat pengukuran; jangan diselidiki ulang:

1. Build debug — profile pun masih patah-patah
2. ML Kit membaca tiap frame — sudah dijarangkan ke ± 8/detik, tetap patah-patah
3. FFmpeg berebut CPU — pengukur dicabut seluruhnya, tetap patah-patah

Penyebab sebenarnya: widget dibangun ulang tiap detak pencatat waktu
(jebakan 15). Sudah diperbaiki dan terbukti halus.

⚠️ Ini **tidak** membatalkan dugaan Product Owner di utang nomor 3 — yang di
sana adalah keadaan berbeda: antrean yang tidak pernah kosong sehingga FFmpeg
selalu sedang berjalan tepat saat perekaman dimulai. Baris `ditunda` di logcat
yang menjawabnya.

## Penyangga jadwal

Bab 0.2 mewajibkan tiap penambahan lingkup disertai pengurangan setara atau
geser tanggal. Penyangga **minus ± 7 jam** — bertambah 1 jam pada 17 Agustus
2026 dari kolom `time_verified` beserta migrasinya, dan 1 jam lagi dari sakelar
data seluler yang dipasang lebih awal. Beri tahu saya setiap kali ada tambahan
baru; jangan diam-diam menyerapnya.

Satu utang teknis tercatat dan **sengaja ditunda**: menambal
`camera_android_camerax` (akar kedipan peralihan). Alasannya di
`DEVIASI_LIBRARY.md` bagian J — berkas video tidak terpengaruh, dan memelihara
fork paket resmi Flutter terlalu mahal untuk saat ini.

## Mulai dari mana

1. Salin `env.dev.json`, `panduan_dokumentasi.md`, dan `dataapp.md` dari
   `E:\kamelscan\` (ketiganya ter-gitignore)
2. Bangkitkan kode: `pub get` → `build_runner build` → `gen-l10n`
3. Baca `DEVIASI_LIBRARY.md` — terutama bagian J dan L
4. Baca Bab 9 di `panduan_dokumentasi.md`
5. Mulai dari **9.2 Home**
