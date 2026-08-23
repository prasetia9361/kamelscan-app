# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Tugas worktree ini: memperbaiki cacat pada alur masuk & pendaftaran** —
khususnya **Lupa Password** dan **pendaftaran lewat "Lanjutkan dengan Google"**.

Kerjakan di worktree `login-logout`, bukan di master.

## Cara kerja yang saya harapkan

- **Bahasa Indonesia.** Saya bukan programmer; jelaskan dengan bahasa yang mudah
  dipahami, tanpa istilah teknis yang tidak perlu. Kalau saya bilang "belum
  paham", ulangi dengan perumpamaan, jangan diulang dengan istilah yang sama.
- **Verifikasi, jangan asumsi.** Pola paling berharga di proyek ini: tiap asumsi
  berisiko dibuktikan di perangkat/database sungguhan **sebelum** kode besar
  ditulis di atasnya.
- **Jangan menyimpulkan cacat visual dari satu tangkapan layar.** Bandingkan dua
  keadaan pada adegan yang sama, atau tanyakan apa yang saya lihat dengan mata
  sendiri.
- **Laporkan apa adanya.** Kalau gagal, katakan gagal beserta pesannya. Kalau
  belum diuji, katakan belum diuji. Kalau tidak tahu sebabnya, katakan tidak
  tahu — jangan menebak lalu menyuruh saya build berkali-kali.
- **Jangan ubah keputusan yang sudah diambil** tanpa memberi tahu saya lebih
  dulu.
- 🔴 **Tanya saya dulu sebelum menyunting berkas catatan** (`DEVIASI_LIBRARY.md`,
  README, prompt serah terima).

### 🔴 Aturan yang lahir dari sesi Bab 9 — patuhi, ini mahal dipelajari

**1. Berhenti setelah dua percobaan perbaikan yang gagal.**
Satu cacat (Beranda kosong) dikejar **empat ronde berturut-turut**. Percobaan
kedua memperbaiki cacat aslinya tetapi melahirkan yang lebih buruk, dan
percobaan ketiga serta keempat menumpuk di atasnya sampai layar splash yang
sudah beres ikut rusak. Seluruhnya akhirnya **dibatalkan atas permintaan saya**.

Bila percobaan kedua gagal **dan gejalanya berubah**, hentikan. Kembalikan
keadaan, lalu ukur bagian yang belum pernah diukur sama sekali. Tiap ronde
memakan satu build 13 menit dan satu pengujian di perangkat saya.

**2. "Sekali coba berhasil" bukan bukti untuk cacat yang muncul kadang-kadang.**
Beranda pernah dinyatakan aman, lalu kambuh. Setelah diukur: 3 dari 4 siklus
gagal, dan yang satu lolos hanya karena datanya kebetulan tiba tepat waktu.
Untuk cacat semacam ini, ulangi **minimal 4–5 kali** sebelum menyatakan beres.

**3. Kemudikan perangkatnya sendiri lewat adb — ini yang akhirnya memecahkan.**
Tiga ronde pertama menebak dari potongan logcat yang saya salin, dan dua
tebakannya salah. Ronde keempat berhasil karena aplikasinya dikendalikan
langsung: mengetuk, mengetik, memasang, mengambil tangkapan layar, dan membaca
logcat sendiri. Kemampuan itu ada — pakai sejak awal.

```powershell
$adb = "C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb devices
& $adb shell input tap <x> <y>
& $adb shell input text "teks%stanpa%sspasi"
& $adb exec-out screencap -p > layar.png      # lalu baca gambarnya
& $adb logcat -c ; & $adb logcat -v time > log.txt
```

⚠️ Layar bergulir saat papan ketik muncul — **ambil tangkapan layar ulang
setelah mengetik** sebelum menghitung koordinat berikutnya. Beberapa ketukan
mendarat di kolom yang salah karena ini.

⚠️ `input keyevent 111` (Escape) menutup bottom sheet, bukan papan ketik.

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang sedang
  dikerjakan sebelum menulis kode.** Untuk worktree ini: **Bab 6** (autentikasi).
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Bagian **B** (google_sign_in
  v7), **J** (kamera), **L** (pipeline), **M** (Bab 9).
- `supabase/README.md` — skema database, RLS, jebakan Supabase.
- `palet_warna_dan_tipografi.md` — palet resmi.
- `dataapp.md` — seluruh kredensial. Ter-gitignore. **Jangan pernah menuliskan
  isinya ke berkas yang masuk git**, dan jangan menampilkannya di percakapan.

⚠️ `panduan_dokumentasi.md` dan `dataapp.md` juga ter-gitignore, jadi worktree
baru tidak memilikinya. Salin dari `E:\kamelscan\` bersama `env.dev.json`.

## Lingkungan

| | |
|---|---|
| Flutter | `E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat` (tidak ada di PATH) |
| Dart | `E:\flutter_sdk\flutter_3.44.8\bin\cache\dart-sdk\bin\dart.exe` |
| JDK | `$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'` |
| adb | `C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Perangkat uji | Xiaomi Redmi Note 9, serial `7744ca520408` |

**🔴 Jangan pernah menjalankan `flutter run` polos.** Tanpa
`--dart-define-from-file=env.dev.json` aplikasi berhenti di layar "Konfigurasi
belum lengkap", dan kernel Dart tanpa kredensial ikut tersimpan di cache
sehingga `flutter build` berikutnya diam-diam memakainya. Pakai `.\run.ps1`.
Bila terlanjur: hapus `.dart_tool/flutter_build` lalu bangun ulang.

- `.\run.ps1 -Profile` — jalankan mode profile
- `.\run.ps1 -Build -Profile` — hanya bangun APK (± 13 menit)

🔴 **Mode debug SENGAJA lambat.** Bila saya melaporkan "patah-patah", tanyakan
dulu **mode apa yang dipakai** sebelum menyelidiki apa pun.

**Internet laptop saya berasal dari HP saya lewat kabel.** Bila HP dilepas,
laptop kehilangan internet — dan `flutter analyze` maupun `flutter test`
**menggantung lama** karena keduanya mengecek paket ke `pub.dev` lebih dulu.
Gejalanya tampak seperti proyek yang rusak, padahal bukan. Jalan pintasnya:

```powershell
& "E:\flutter_sdk\flutter_3.44.8\bin\cache\dart-sdk\bin\dart.exe" analyze lib test
& "E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat" test --no-pub
```

**Worktree baru wajib dibangkitkan kodenya lebih dulu**, kalau tidak
`flutter analyze` melaporkan ratusan error yang tidak ada hubungannya dengan
kode:

```powershell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

## Supabase

Project `ofggpithmvgnhsshglwx` (wilayah ap-southeast-1). Kredensial di
`dataapp.md`.

Edge Function yang sudah terpasang: `create-packer`, `delete-packer`,
`get-upload-url`, `get-video-url`, `create-public-link`, `get-public-video`,
`resolve-username`.

**Deploy Edge Function** butuh `$env:SUPABASE_ACCESS_TOKEN` dari `dataapp.md`:

```powershell
npx --yes supabase@latest functions deploy <nama> --project-ref ofggpithmvgnhsshglwx
```

⚠️ **Token akses Supabase punya masa berlaku** dan yang lama sempat kedaluwarsa
di tengah pekerjaan. Gejalanya `status 401 {"message":"Unauthorized"}` —
bukan pesan yang menyebut kedaluwarsa. Periksa di
<https://supabase.com/dashboard/account/tokens>.

⚠️ Bila deploy lewat CLI mentok, **fungsinya bisa ditempel lewat browser**:
Dashboard → Edge Functions → Deploy a new function → Via Editor. Cara ini
sudah terbukti berhasil.

**Menjalankan migrasi SQL:** saya menjalankannya sendiri lewat Dashboard → SQL
Editor. Beri saya isi berkasnya beserta langkah yang **detail** — sebutkan menu
yang diklik dan hasil yang seharusnya muncul (`Success. No rows returned`).
Instruksi ringkas pernah membuat saya tersinggung karena terasa seperti diuji.

## Keadaan proyek — sudah selesai dan TERBUKTI

**Bab 0–8 selesai.** Rantai perekaman lengkap terbukti di Redmi Note 9:
watermark terbakar benar, video sampai di R2, token terpotong tepat satu per
video, isolate unggah latar belakang hidup.

**Bab 9 selesai dan sudah di-merge ke master** (commit `4c0c42c`), kecuali
**9.9 Tutorial** yang belum dikerjakan. 295 tes hijau, `analyze` bersih.

Layar yang jadi: Beranda, Riwayat, Toko, Akun, Kelola Akun Packer, Pengaturan,
Pembayaran. Bab 8.8 (putar/unduh/tautan publik) juga lunas.

Enam cacat ditemukan lewat pengujian di perangkat — **tidak satu pun terdeteksi
`analyze` atau tes**. Uraiannya di `DEVIASI_LIBRARY.md` bagian **M.15–M.17**.

## 🔴 Tugas worktree ini

Saya melaporkan ada cacat pada dua alur berikut. **Gejala persisnya belum
dijelaskan — tanyakan saya lebih dulu di awal sesi**, jangan menebak dan jangan
langsung membongkar kode:

1. **Lupa Password**
2. **Pendaftaran akun lewat "Lanjutkan dengan Google"**

Yang perlu ditanyakan: apa yang saya lakukan, apa yang muncul di layar, dan
apakah ada email yang masuk atau tidak.

### Di mana kodenya

| Bagian | Berkas |
|---|---|
| Layar Lupa Password | `lib/pages/auth/forgot_password/` |
| Layar Masuk (tombol Google) | `lib/pages/auth/login/` |
| Layar Daftar | `lib/pages/auth/register/` |
| Lengkapi Profil | `lib/pages/auth/complete_profile/` |
| Ganti Password | `lib/pages/auth/change_password/` |
| Logika Google & reset | `lib/core/services/auth_service.dart` |
| Pembungkusnya | `lib/core/repositories/auth_repository.dart` |
| Penjagaan rute | `lib/navigation/route_guards.dart` |
| Pembuatan tenant otomatis | `supabase/migrations/15_triggers.sql` → `handle_new_user()` |

### Tersangka yang sudah diketahui — periksa ini lebih dulu

**a. Redirect URL yang tidak terdaftar TIDAK menghasilkan error.**
Supabase diam-diam memakai Site URL sebagai gantinya, sehingga pengguna mendarat
di halaman web alih-alih kembali ke aplikasi. Ini tersangka nomor satu untuk
**Lupa Password**, karena tautannya harus membuka aplikasi lewat deep link
`id.kamelscan.app://`.

Periksa: Dashboard → Authentication → URL Configuration → Redirect URLs, dan
cocokkan dengan `AUTH_REDIRECT_SCHEME` di `env.dev.json` serta `intent-filter`
di `android/app/src/main/AndroidManifest.xml`.

**b. Google Sign-In di Android hanya berfungsi bila SHA-1 dan SHA-256 keystore
— debug DAN release — sudah didaftarkan di Google Cloud Console.** Bila belum,
`authenticate()` gagal dengan galat konfigurasi yang tidak menyebut SHA sama
sekali.

**c. `google_sign_in` v7 berbeda total dari v6** yang ditulis di Bab 4.2:
memakai singleton `GoogleSignIn.instance` dan wajib `initialize()` lebih dulu.
Lihat `DEVIASI_LIBRARY.md` bagian **B**.

**d. Pendaftaran lewat Google melewati formulir**, sehingga nomor HP dan
persetujuan S&K tidak pernah ditanyakan (Bab 6.2). Penjagaannya ada di
`needsProfileCompletionProvider` yang melempar ke layar Lengkapi Profil. Periksa
apakah penjagaan itu benar-benar menyala pada akun Google baru — kalau tidak,
seseorang memperoleh tenant beserta 100 video gratis tanpa nomor kontak dan
tanpa pernah menyetujui apa pun.

**e. `handle_new_user()` memakai `raw_user_meta_data`.** Pendaftaran biasa
mengisi `full_name`, `username`, `phone`, `business_name` di sana; pendaftaran
Google **tidak mengisi satu pun**. Periksa apa yang sebenarnya terbentuk di
`public.users` dan `public.tenants` untuk akun Google — `username` bisa jadi
null, dan `full_name` jatuh ke potongan email.

**f. Batas kirim email Supabase.** Sudah dipetakan sebagai
`errorEmailRateLimited`. Percobaan berulang saat menguji Lupa Password mudah
menabraknya, dan pesannya bisa disalahartikan sebagai cacat.

## Jebakan yang sudah memakan waktu

**Umum:**

1. `flutter run` polos meracuni cache kernel — lihat di atas
2. Ekstensi Supabase ada di schema `extensions`, bukan `public`. Pakai
   `gen_random_uuid()`
3. Redirect URL tidak cocok → tidak ada error, diam-diam pakai Site URL
4. Auth Hook wajib aktif, kalau tidak semua tabel mengembalikan **nol baris**
   tanpa pesan apa pun
5. `AppColors` adalah `ThemeExtension`, diakses lewat
   `Theme.of(context).extension<AppColors>()!`
6. `flutter analyze` di akar melaporkan error dari `tool/db_migrate`. Pakai
   `flutter analyze lib`
7. **Periksa worktree sebelum mempercayai hasil `analyze`/`test`.** Sesi pernah
   terlempar ke worktree lain diam-diam. Jalur berkas pada keluaran tes
   menyebutkan worktree-nya — baca itu

**Diagnosis:**

8. 🔴 **`AppLogger` tidak pernah sampai ke logcat.** Ia memakai
   `dart:developer`. Untuk jejak yang perlu dibaca dari perangkat, pakai
   `debugPrint` (tembus sebagai `I/flutter`).

   **Aturan yang lahir dari sini: bila jalur berhasilnya dicetak dengan
   `debugPrint`, jalur gagalnya WAJIB ikut.**

9. Jejak `KAMELSCAN_*` yang sudah ada **sengaja permanen** — jangan dihapus
   sebagai sisa lupa dibersihkan. Yang relevan untuk worktree ini:
   `KAMELSCAN_SPLASH`, `KAMELSCAN_GUARD`, `KAMELSCAN_SESI`.

**Pemasangan APK (MIUI):**

10. `adb install` ditolak `INSTALL_FAILED_USER_RESTRICTED`. Pesannya
    menyesatkan. Sebabnya: tidak ada yang menekan *Izinkan* di layar HP, atau
    HP tanpa internet (MIUI memverifikasi ke server Xiaomi). **Minta saya
    menjalankan perintah `adb install`-nya sendiri** — saya yang menekan
    izinnya. Kadang berhasil langsung, kadang tidak; jangan menyerah di
    percobaan pertama.
11. `adb install` pernah mengembalikan exit code 0 walaupun gagal. **Baca
    keluarannya**, jangan percaya kode keluarnya saja.
12. **Memasang ulang APK menghapus cache aplikasi**, termasuk sesi login. Jangan
    menguji "sesi bertahan setelah aplikasi ditutup" tepat setelah memasang
    ulang — pengujiannya tidak akan pernah sampai ke jalur yang dimaksud.

**Tata letak — sudah terjadi DUA KALI:**

13. 🔴 **Tombol bertema di proyek ini menuntut lebar TAK TERHINGGA.**
    `filledButtonTheme` memakai `minimumSize: Size.fromHeight(...)`. Menaruhnya
    di dalam `Row` membuatnya melahap seluruh lebar, dan `Expanded` di
    sebelahnya tergencet jadi nol.

    Pertama kali: judul halaman Toko tergambar satu huruf per baris (M.12).
    Kedua kali: kolom kode promo hilang sama sekali, hanya tersisa ikon (M.17).

    Membungkusnya dengan `SizedBox(height: ...)` **tidak menolong** — yang
    merusak lebarnya. Batasnya harus datang dari `Expanded`.

    ⚠️ **Tes tata letak yang tidak memakai `AppTheme` tidak membuktikan apa
    pun.** Percobaan pertama memakai tema bawaan Flutter dan **lulus**, sehingga
    sempat menyimpulkan susunannya baik-baik saja.

**Pesan error:**

14. 🔴 **Menambah kegagalan baru menuntut TIGA tempat disentuh**, dan
    melewatkan yang ketiga tidak menimbulkan gejala apa pun:

    1. `AppFailure` — kunci pesannya
    2. `app_id.arb` / `app_en.arb` — kalimatnya
    3. `failure_messages.dart` — sambungan antara keduanya

    Yang terlewat diam-diam berubah jadi *"Terjadi kesalahan"*. Dijaga
    `test/core/failure_message_keys_test.dart` — jalankan bila menambah
    kegagalan baru.

15. Penolakan Edge Function membawa kodenya di **badan balasan**, bukan di
    pesannya. Pemetaannya di `SupabaseService._mapFunctions`. Kelas dasarnya
    `FunctionException` (tanpa `s`).

**Riverpod:**

16. 🔴 **Semua `ref.watch` dan `ref.listen` harus dipanggil SEBELUM `await`
    pertama** di dalam `build()`. Yang didaftarkan sesudahnya tidak tersambung
    dengan benar, dan gejalanya layar yang memuat selamanya tanpa error apa pun.
17. Riverpod yang sedang **mengulang percobaan** membungkus kegagalannya dalam
    `AsyncLoading` yang membawa error — bukan `AsyncError`. Pencocokan menurut
    tipe akan meleset dan jatuh ke cabang "sedang memuat".

## Utang yang belum lunas

### 1. 🔴 `activate-subscription` — SAYA SUDAH TRANSFER SUNGGUHAN

22 Agustus 2026 saya melakukan **transfer uang sungguhan** lewat alur Bab 9.8,
mengunggah buktinya, dan layarnya berhenti di *"Menunggu verifikasi"*.

**Belum ada apa pun yang dapat mengubahnya menjadi aktif.** Langkah terakhir
Bab 12.2 — Admin memeriksa bukti lalu paket dinyalakan — ada di panel Admin
(Bab 11) dan belum dibuat.

Fungsi yang dibutuhkan harus mengerjakan empat hal dan keempatnya harus benar
bersamaan:

1. `subscriptions.status = 'paid'`, `paid_at = now()`
2. `tenants.tier_plan` = paket yang dibeli, `period_start = now()`,
   `period_end = now() + 30 hari`
3. `token_wallets.monthly_quota` & `balance` = kuota tier baru
4. `token_ledger` catat `plan_upgrade`, `audit_logs` catat aksi admin

Perkiraan **± 2 jam**. Saya sudah diberi tahu ini penambahan lingkup dan
**belum memutuskan** kapan dikerjakan.

⚠️ Trigger `guard_subscription_owner_update` (migrasi 25) mengunci seluruh kolom
`subscriptions` bagi Owner kecuali `proof_url`. Ia **dilewati** oleh
`service_role` dan Admin — jadi Edge Function aktivasi tidak akan tertahan
olehnya. Jangan menghapus trigger itu untuk "memudahkan".

### 2. Bab 9.9 Tutorial — belum dikerjakan

Ditunda atas keputusan saya. Halaman daftar bernomor dari tabel `tutorials`,
membuka YouTube lewat `url_launcher`. Bagian paling ringan di Bab 9.

### 3. Halaman `/settings/watermark` masih placeholder

Khusus tier Pro; seluruh tenant saat ini masih trial/Standar, jadi belum ada
yang dapat menemukannya.

### 4. Tautan bukti publik belum bisa dibuka

`https://kamelscan.com/v/{token}` menunggu aplikasi web Bab 10 di-deploy.
Edge Function-nya sudah jadi dan sudah diuji tanpa login.

### 5. Satu video sungguhan lewat jalur unggah latar belakang

Isolatenya terbukti hidup, tetapi antriannya selalu keburu dihabiskan jalur
aplikasi-terbuka. Prosedurnya di `DEVIASI_LIBRARY.md` **L.8**; butuh Wi-Fi.

### 6. Akun packer uji yang perlu dibersihkan

`ujiberanda@ramirez-corp.com` (nama **Uji Beranda**) dibuat untuk mereproduksi
cacat Beranda, dan **belum dihapus**. Kuota packer saya jadi 4 dari 5. Ia belum
pernah merekam, jadi tombol Hapus seharusnya bekerja.

### 7. `server_now` ditolak sebelum login

`KAMELSCAN_WAKTU sinkron GAGAL · permission denied for function server_now
(42501)` muncul tiap kali aplikasi dibuka, sebelum sesi ada. Ia pulih sendiri
sesudah login, jadi tidak merusak apa pun — tetapi berisik di logcat dan
sebaiknya dibereskan bersama pekerjaan autentikasi. Kemungkinan `server_now`
belum di-`grant` ke peran `anon`.

## Penyangga jadwal

Bab 0.2 mewajibkan tiap penambahan lingkup disertai pengurangan setara atau
geser tanggal. Penyangga **minus ± 7 jam**. Beri tahu saya setiap kali ada
tambahan baru; jangan diam-diam menyerapnya.

## Mulai dari mana

1. Salin `env.dev.json`, `panduan_dokumentasi.md`, dan `dataapp.md` dari
   `E:\kamelscan\` (ketiganya ter-gitignore)
2. Bangkitkan kode: `pub get` → `build_runner build` → `gen-l10n`
3. Baca `DEVIASI_LIBRARY.md` bagian **B** dan **M**
4. Baca **Bab 6** di `panduan_dokumentasi.md`
5. **Tanyakan saya dulu**: gejala persis pada Lupa Password dan pendaftaran
   Google — apa yang saya lakukan, apa yang muncul, ada email masuk atau tidak
6. Baru sesudah itu periksa kode dan konfigurasi Supabase
