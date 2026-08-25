# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Tugas worktree ini: Bab 10 — aplikasi WEB.** Aplikasi webnya **sudah terbit**
di `https://kamelscan.com/app` sejak 25 Agustus 2026. Yang tersisa: dasbor web,
halaman berbentuk tabel, titik henti responsif, dan dua cacat login web.

Kerjakan di worktree **`bab 10`**, bukan di master.

## 🔴 Aturan nomor satu: BERTANYA DULU, jangan mengambil keputusan sendiri

**Setiap kali kamu menemui kendala, kebingungan, pilihan bercabang, atau sesuatu
yang tidak sesuai dugaan — BERHENTI dan tanya saya lebih dulu.** Jangan menebak,
jangan memilih sendiri "yang paling masuk akal", jangan melanjutkan dengan
asumsi sambil berharap benar.

Ini berlaku untuk, tetapi tidak terbatas pada:

- Spesifikasi Bab 10 yang tidak jelas atau tampak bertentangan dengan kode yang
  sudah ada
- Perintah gagal, galat yang tidak dikenali, atau hasil yang berbeda dari yang
  kamu perkirakan
- Pilihan pustaka, pola, penamaan, tata letak, atau susunan berkas yang belum
  pernah ditentukan di proyek ini
- Apa pun yang menyangkut **uang, domain, DNS, hosting, dan akun pihak ketiga**
  (Cloudflare, Google Cloud, Supabase) — jangan pernah mendaftar, membeli,
  mengubah pengaturan, atau men-*deploy* tanpa saya menyuruh
- Migrasi SQL baru, penghapusan data, atau perubahan skema
- Menambah lingkup pekerjaan di luar yang tertulis di sini

Cara bertanya yang saya harapkan: sebutkan **apa yang kamu temukan**, **apa
pilihannya**, dan **apa saran kamu beserta alasannya** — lalu tunggu jawaban
saya. Satu pertanyaan jelas jauh lebih murah daripada satu jam pekerjaan yang
harus dibatalkan.

Yang **tidak** perlu ditanyakan: membaca berkas, mencari di kode, menjalankan
`analyze`/`test`, dan hal-hal yang sudah tertulis eksplisit di prompt ini.

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
  `README.md`, `panduan_dokumentasi.md`, prompt serah terima, dan berkas
  dokumentasi lain).

### 🔴 Aturan yang lahir dari sesi Bab 9 — patuhi, ini mahal dipelajari

**1. Berhenti setelah dua percobaan perbaikan yang gagal.**
Satu cacat (Beranda kosong) dikejar **empat ronde berturut-turut**, dan seluruh
hasilnya akhirnya dibatalkan atas permintaan saya.

Bila percobaan kedua gagal **dan gejalanya berubah**, hentikan. Kembalikan
keadaan, tanya saya, lalu ukur bagian yang belum pernah diukur sama sekali.

Aturan ini terbukti berguna lagi di sesi Bab 10: dua dugaan sebab kegagalan
`_redirects` ternyata salah, dan yang memecahkan justru tangkapan layar dashboard
yang saya ambil sendiri.

**2. "Sekali coba berhasil" bukan bukti untuk cacat yang muncul kadang-kadang.**
Untuk cacat semacam itu, ulangi **minimal 4–5 kali** sebelum menyatakan beres.

**3. Kemudikan perangkat/peramban sendiri.**

```powershell
$adb = "C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb devices
& $adb shell input tap <x> <y>
& $adb exec-out screencap -p > layar.png
& $adb logcat -c ; & $adb logcat -v time > log.txt
```

⚠️ Ekstensi Claude in Chrome **tidak terpasang** — saya memilih tidak
memasangnya. Untuk apa pun yang perlu dilihat di peramban, minta saya membuka
dan melaporkannya, atau ukur dengan `curl` dari terminal.

**4. 🔴 Aturan baru dari Bab 10: alat uji yang lebih pemaaf daripada aslinya
lebih berbahaya daripada tidak menguji sama sekali.** Server tiruan Cloudflare
yang dipakai menguji lokal memaafkan kesalahan yang Cloudflare tolak, dan cacat
itu lolos sampai ke situs yang sudah terbit. Uraiannya di `DEVIASI_LIBRARY.md`
**O.3**.

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang sedang
  dikerjakan sebelum menulis kode.** Untuk worktree ini: **Bab 10**, ditambah
  **Bab 9.11** (dwibahasa) dan **Bab 2.2** (matriks hak akses).
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Bagian **O** (Bab 10,
  penerbitan web — seluruh jebakan Cloudflare ada di sini), **M** (Bab 9), dan
  **N** (Bab 6, autentikasi).
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

- `.\run.ps1 -Profile` — jalankan mode profile di HP
- `.\run.ps1 -Build -Profile` — hanya bangun APK (± 13 menit)

🔴 **Mode debug SENGAJA lambat.** Bila saya melaporkan "patah-patah", tanyakan
dulu **mode apa yang dipakai** sebelum menyelidiki apa pun.

**Internet laptop saya berasal dari HP saya lewat kabel.** Bila HP dilepas,
laptop kehilangan internet — dan `flutter analyze` maupun `flutter test`
**menggantung lama** karena keduanya mengecek paket ke `pub.dev` lebih dulu.
Jalan pintasnya:

```powershell
& "E:\flutter_sdk\flutter_3.44.8\bin\cache\dart-sdk\bin\dart.exe" analyze lib test
& "E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat" test --no-pub
```

**Worktree baru wajib dibangkitkan kodenya lebih dulu:**

```powershell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

## 🔴 Menerbitkan aplikasi web — SUDAH JADI, jangan dibangun ulang

```powershell
.\deploy_web.ps1          # bangun + susun folder build\deploy
npx --yes wrangler@latest pages deploy build/deploy --project-name=kamelscan --branch=main --commit-dirty=true
```

Alamat hidup: `https://kamelscan.com/app`, `https://kamelscan.com/v/{token}`.
Akar `/` dilempar ke `/app/` sementara landing page belum ada.

⚠️ **Tiga jebakan yang sudah memakan berjam-jam — baca `DEVIASI_LIBRARY.md` O.2
dan O.6 sebelum menyentuh apa pun yang menyangkut penerbitan:**

1. `deploy_web.ps1` **wajib** dijalankan dari PowerShell, bukan Git Bash, dan
   **tanpa penggabungan stderr** — keduanya menggagalkannya dengan cara yang
   tetap terlihat seperti berhasil.
2. Tujuan aturan `_redirects` **tidak boleh** berakhiran `.html`.
3. Pola `_redirects` **tidak boleh** `/app/*` — ia menelan `main.dart.js` dan
   seluruh aset, lalu aplikasinya jadi halaman putih walaupun `/app/login`
   menjawab 200 dengan benar.

🔴 **Setiap rute baru di `route_names.dart` WAJIB ditambahkan ke daftar rute di
`deploy_web.ps1`.** Yang terlupa bekerja saat diklik dari dalam aplikasi tetapi
menjawab 404 begitu halamannya disegarkan.

Periksa dengan `Content-Type`, bukan hanya kode status:

```bash
curl -sI https://kamelscan.com/app/main.dart.js | grep -i content-type
# WAJIB application/javascript
```

## Supabase

Project `ofggpithmvgnhsshglwx` (wilayah ap-southeast-1). Kredensial di
`dataapp.md`.

Edge Function terpasang: `create-packer`, `delete-packer`, `get-upload-url`,
`get-video-url`, `create-public-link`, `get-public-video`, `resolve-username`.

**Deploy Edge Function** butuh `$env:SUPABASE_ACCESS_TOKEN` dari `dataapp.md`:

```powershell
npx --yes supabase@latest functions deploy <nama> --project-ref ofggpithmvgnhsshglwx
```

⚠️ **Token akses Supabase punya masa berlaku.** Gejalanya
`status 401 {"message":"Unauthorized"}` — bukan pesan yang menyebut kedaluwarsa.
Periksa di <https://supabase.com/dashboard/account/tokens>.

⚠️ Bila deploy lewat CLI mentok, fungsinya bisa ditempel lewat browser:
Dashboard → Edge Functions → Deploy a new function → Via Editor.

**Menjalankan migrasi SQL:** saya menjalankannya sendiri lewat Dashboard → SQL
Editor. Beri saya isi berkasnya beserta langkah yang **detail** — sebutkan menu
yang diklik dan hasil yang seharusnya muncul (`Success. No rows returned`).
Instruksi ringkas pernah membuat saya tersinggung karena terasa seperti diuji.

## Keadaan proyek — sudah selesai dan TERBUKTI

**Bab 0–8 selesai.** Rantai perekaman lengkap terbukti di Redmi Note 9.
Bab 8.8 (putar/unduh/tautan publik) lunas.

**Bab 9 selesai dan sudah di-merge** kecuali **9.9 Tutorial**.

**Bab 6 (autentikasi) sudah diperbaiki dan di-merge** — uraiannya di
`DEVIASI_LIBRARY.md` **N.1–N.5**.

**Bab 10.2 selesai 25 Agustus 2026 — aplikasi web TERBIT.** Uraiannya di
`DEVIASI_LIBRARY.md` bagian **O**. Yang jadi di sesi itu:

| Hasil | Berkas |
|---|---|
| Skrip penerbitan sekali-jalan | `deploy_web.ps1` |
| Halaman bukti publik HTML ringan (15 KB, bawaan Indonesia + tombol EN) | `web_public/v/index.html` |
| Tanda `#` dibuang dari alamat web | `lib/core/utils/url_strategy*.dart`, `lib/main.dart` |
| Judul/warna/deskripsi web memakai palet resmi | `web/index.html`, `web/manifest.json` |
| Domain, DNS, sertifikat HTTPS | Cloudflare Pages, proyek `kamelscan` |

Jalur sukses `create-public-link` **teruji pertama kali** — lihat **O.8**.

## 🔴 Yang WAJIB ditanyakan ke saya di awal sesi

1. **Bagian mana dari Bab 10 yang dikerjakan lebih dulu**, dan seberapa jauh
   lingkupnya untuk sesi ini.
2. **Apakah alamat web sudah saya daftarkan di Supabase** (lihat utang nomor 1
   di bawah). Jangan menganggapnya sudah.
3. **Peramban dan lebar layar** yang saya pakai menguji, supaya titik henti
   responsifnya diuji pada ukuran yang benar-benar saya lihat. Terakhir: Chrome,
   laptop layar penuh.

## 🔴 Utang yang belum lunas

### 1. 🔴 Alamat web belum didaftarkan di Supabase — PALING MURAH, PALING SUNYI

`https://kamelscan.com/app/auth/callback` harus masuk Dashboard →
Authentication → URL Configuration → Redirect URLs.

Selama belum, verifikasi email dan reset password lewat web mendarat di Site URL
**tanpa satu pun pesan galat**. Jebakan yang sama sudah terjadi 13 Agustus 2026.
Perkiraan 5 menit; saya yang mengklik.

### 2. 🔴 Rute `/auth/callback` tidak punya halaman

`lib/core/config/env.dart:107` mengirim `$webAppBaseUrl/auth/callback` sebagai
tujuan tautan verifikasi email dan reset password di web, tetapi **tidak ada
rute dengan alamat itu di seluruh `lib/`**. Yang mengklik tautannya mendarat di
layar "halaman tidak ditemukan". Terverifikasi lewat pembacaan kode, belum diuji
di peramban. Perkiraan ± 1 jam.

⚠️ Ingat butir navigasi di bawah: apa pun yang dibaca `RouteGuards.redirect`
wajib ikut disimak `GoRouterRefreshNotifier`.

### 3. 🔴 Login Google di web memakai alamat khusus HP

`lib/core/services/auth_service.dart:293` memakai `Env.oauthRedirectUrl`, yang
isinya `id.kamelscan.app://login-callback` — skema deep link Android. Peramban
tidak mengerti alamat semacam itu, jadi tombol Google di web besar kemungkinan
tidak pernah menyelesaikan login.

Perbaikannya menyangkut **OAuth Client ID jenis Web** di Google Cloud Console
beserta *Authorized JavaScript origins* dan *redirect URIs* — itu akun saya,
jadi **tanyakan dulu**. Perkiraan ± 1–2 jam. Belum diuji di peramban.

### 4. Sisa Bab 10

| Bagian | Keadaan | Perkiraan |
|---|---|---|
| 10.4 Dasbor web | `web_dashboard_page.dart` masih **placeholder kosong**. Empat kartu + grafik `fl_chart` + pemilih rentang 7/30/90 hari. RPC `get_daily_stats()` **belum ada** — hanya disebut di komentar `20_home_stats.sql`. Migrasi baru, **tanyakan dulu** | ± 4–6 jam |
| 10.5 Halaman versi tabel | Riwayat sebagai tabel terurut, filter, paginasi server-side, pencarian resi di top bar, klik baris → panel samping berisi pemutar. Lalu Toko, Packer, Pembayaran, Setting, Tutorial | ± 6–8 jam |
| 10.3 Responsif + sidebar | Sidebar jadi drawer di bawah 1024 px, tabel jadi kartu di bawah 768 px. `web_shell.dart` baru punya **4 menu dari 7** yang diminta Bab 10.3 | ± 2–3 jam |

⚠️ Zona waktu pada grafik harian: kelompokkan dengan
`(v.scan_date at time zone 'Asia/Jakarta')::date`. Terbukti nyata — lihat **O.8**.

### 5. 🔴 `activate-subscription` — SAYA SUDAH TRANSFER SUNGGUHAN

22 Agustus 2026 saya melakukan **transfer uang sungguhan** lewat alur Bab 9.8,
mengunggah buktinya, dan layarnya berhenti di *"Menunggu verifikasi"*.

**Belum ada apa pun yang dapat mengubahnya menjadi aktif.** Fungsi yang
dibutuhkan harus mengerjakan empat hal dan keempatnya harus benar bersamaan:

1. `subscriptions.status = 'paid'`, `paid_at = now()`
2. `tenants.tier_plan` = paket yang dibeli, `period_start = now()`,
   `period_end = now() + 30 hari`
3. `token_wallets.monthly_quota` & `balance` = kuota tier baru
4. `token_ledger` catat `plan_upgrade`, `audit_logs` catat aksi admin

Perkiraan **± 2 jam**. Saya sudah diberi tahu ini penambahan lingkup dan
**belum memutuskan** kapan dikerjakan.

⚠️ Trigger `guard_subscription_owner_update` (migrasi 25) mengunci seluruh kolom
`subscriptions` bagi Owner kecuali `proof_url`. Ia **dilewati** oleh
`service_role` dan Admin. Jangan menghapus trigger itu untuk "memudahkan".

### 6. Landing page `/` — bagian DESAINER, bukan programmer

Belum diserahkan. Sementara ini akar situs dilempar ke `/app/` dengan status
302. **Hapus baris `/  /app/  302` di `deploy_web.ps1` begitu landing page
dipasang.**

### 7. Bab 9.9 Tutorial — belum dikerjakan

Ditunda atas keputusan saya. Halaman daftar bernomor dari tabel `tutorials`,
membuka YouTube lewat `url_launcher`. Versi web-nya (grid kartu, Bab 10.5) ikut
menunggu ini.

### 8. Halaman `/settings/watermark` masih placeholder

Khusus tier Pro; seluruh tenant saat ini masih trial/Standar.

### 9. Satu video sungguhan lewat jalur unggah latar belakang

Isolatenya terbukti hidup, tetapi antriannya selalu keburu dihabiskan jalur
aplikasi-terbuka. Prosedurnya di `DEVIASI_LIBRARY.md` **L.8**; butuh Wi-Fi.

### 10. Akun packer uji yang perlu dibersihkan

`ujiberanda@ramirez-corp.com` (nama **Uji Beranda**) dibuat untuk mereproduksi
cacat Beranda, dan **belum dihapus**. Kuota packer saya jadi 4 dari 5.

### 11. `server_now` ditolak sebelum login

`permission denied for function server_now (42501)` di HP, dan `401` di web,
muncul tiap kali aplikasi dibuka sebelum sesi ada. Sebabnya sudah diketahui:
`19_server_time.sql` sengaja `revoke ... from anon, public`. Ia pulih sendiri
sesudah login. **Jangan mengubah hak aksesnya tanpa bertanya**; ini keputusan
keamanan, bukan kelalaian.

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
   sebagai sisa lupa dibersihkan.

**Navigasi — temuan terpenting Bab 6:**

10. 🔴 **Apa pun yang dibaca `RouteGuards.redirect` WAJIB ikut disimak
    `GoRouterRefreshNotifier`.** GoRouter tidak mengintip provider; ia hanya
    menghitung ulang tujuan bila ada yang memberitahunya. Nilai yang dibaca
    guard tetapi tidak disimak di sana menghasilkan cacat berbentuk sama:
    **layar yang seharusnya berpindah, diam di tempat** — tanpa error apa pun.
    Ini akan berulang saat menambah rute web baru.

**Tata letak — sudah terjadi DUA KALI:**

11. 🔴 **Tombol bertema di proyek ini menuntut lebar TAK TERHINGGA.**
    `filledButtonTheme` memakai `minimumSize: Size.fromHeight(...)`. Menaruhnya
    di dalam `Row` membuatnya melahap seluruh lebar, dan `Expanded` di
    sebelahnya tergencet jadi nol.

    Pertama kali: judul halaman Toko tergambar satu huruf per baris (M.12).
    Kedua kali: kolom kode promo hilang sama sekali (M.17).

    Membungkusnya dengan `SizedBox(height: ...)` **tidak menolong** — yang
    merusak lebarnya. Batasnya harus datang dari `Expanded`.

    ⚠️ Layar web jauh lebih lebar daripada HP, jadi jebakan ini akan tampak
    berbeda di sana — tetapi sebabnya sama. Bab 10.5 penuh tabel dan tombol
    dalam baris; ia akan muncul lagi.

    ⚠️ **Tes tata letak yang tidak memakai `AppTheme` tidak membuktikan apa
    pun.** Percobaan pertama memakai tema bawaan Flutter dan **lulus**.

**Pesan error:**

12. 🔴 **Menambah kegagalan baru menuntut TIGA tempat disentuh**, dan
    melewatkan yang ketiga tidak menimbulkan gejala apa pun:

    1. `AppFailure` — kunci pesannya
    2. `app_id.arb` / `app_en.arb` — kalimatnya
    3. `failure_messages.dart` — sambungan antara keduanya

    Yang terlewat diam-diam berubah jadi *"Terjadi kesalahan"*. Dijaga
    `test/core/failure_message_keys_test.dart`.

13. Penolakan Edge Function membawa kodenya di **badan balasan**, bukan di
    pesannya. Pemetaannya di `SupabaseService._mapFunctions`. Kelas dasarnya
    `FunctionException` (tanpa `s`).

**Riverpod:**

14. 🔴 **Semua `ref.watch` dan `ref.listen` harus dipanggil SEBELUM `await`
    pertama** di dalam `build()`. Yang didaftarkan sesudahnya tidak tersambung
    dengan benar, dan gejalanya layar yang memuat selamanya tanpa error apa pun.
15. Riverpod yang sedang **mengulang percobaan** membungkus kegagalannya dalam
    `AsyncLoading` yang membawa error — bukan `AsyncError`.

**Pemasangan APK (MIUI) — bila sesi ini sampai menyentuh mobile:**

16. `adb install` ditolak `INSTALL_FAILED_USER_RESTRICTED`. Pesannya
    menyesatkan. **Minta saya menjalankan perintah `adb install`-nya sendiri**.
17. `adb install` pernah mengembalikan exit code 0 walaupun gagal. **Baca
    keluarannya**, jangan percaya kode keluarnya saja. Bentuk yang sama muncul
    lagi di Bab 10 pada `flutter build web` lewat Git Bash — lihat **O.6**.
18. **Memasang ulang APK menghapus cache aplikasi**, termasuk sesi login.

## Di mana kodenya

| Bagian | Berkas |
|---|---|
| Rangka web (sidebar/top bar) | `lib/navigation/shells/web_shell.dart` |
| Dasbor web | `lib/pages/web/dashboard/` |
| Pendaftaran rute & pemisahan web/mobile | `lib/navigation/app_router.dart` |
| Nama rute | `lib/navigation/route_names.dart` |
| Penjagaan rute | `lib/navigation/route_guards.dart` |
| Halaman bukti publik versi Flutter (tidak dipakai di web) | `lib/pages/public/` |
| Halaman bukti publik versi HTML (yang terbit) | `web_public/v/index.html` |
| Strategi alamat web | `lib/core/utils/url_strategy*.dart` |
| Riwayat versi mobile (acuan) | `lib/pages/history/` |
| Statistik beranda (pola RPC) | `lib/core/repositories/home_repository.dart` |
| Konfigurasi env & alamat web | `lib/core/config/env.dart` |
| Kerangka HTML web | `web/index.html` |
| Skrip penerbitan | `deploy_web.ps1` |
| Migrasi database | `supabase/migrations/` |

## Penyangga jadwal

Bab 0.2 mewajibkan tiap penambahan lingkup disertai pengurangan setara atau
geser tanggal. Penyangga **minus ± 9–10 jam** (halaman `/v/` versi HTML menambah
2–3 jam yang saya setujui 25 Agustus 2026). Beri tahu saya setiap kali ada
tambahan baru; jangan diam-diam menyerapnya.

## Mulai dari mana

1. Salin `env.dev.json`, `panduan_dokumentasi.md`, dan `dataapp.md` dari
   `E:\kamelscan\` (ketiganya ter-gitignore)
2. Bangkitkan kode: `pub get` → `build_runner build` → `gen-l10n`
3. Pastikan `analyze` dan `test` hijau **sebelum** menyentuh apa pun
4. Baca **Bab 10** di `panduan_dokumentasi.md`, lalu `DEVIASI_LIBRARY.md`
   bagian **O** seluruhnya, lalu **M.10** dan **N**
5. Lihat sendiri keadaan web sekarang — ia sudah terbit:
   `https://kamelscan.com/app`
6. 🔴 **Tanyakan tiga hal di daftar "Yang WAJIB ditanyakan" di atas**, dan tunggu
   jawaban saya sebelum menulis kode apa pun
