# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Bab 10 (aplikasi web) SUDAH SELESAI dan terbukti di peramban.** Aplikasinya
hidup di `https://kamelscan.com/app`, landing page di `https://kamelscan.com`.
**Prioritas sekarang: dua halaman Admin yang masih kosong** (Bab 11). Tutorial
(Bab 9.9) sengaja ditunda menunggu channel YouTube-nya siap — lihat daftar
utang di bawah.

## 🔴 Aturan nomor satu: BERTANYA DULU, jangan mengambil keputusan sendiri

**Setiap kali kamu menemui kendala, kebingungan, pilihan bercabang, atau sesuatu
yang tidak sesuai dugaan — BERHENTI dan tanya saya lebih dulu.** Jangan menebak,
jangan memilih sendiri "yang paling masuk akal", jangan melanjutkan dengan
asumsi sambil berharap benar.

Ini berlaku untuk, tetapi tidak terbatas pada:

- Spesifikasi yang tidak jelas atau tampak bertentangan dengan kode yang ada
- Perintah gagal, galat yang tidak dikenali, atau hasil yang berbeda dari
  perkiraanmu
- Pilihan pustaka, pola, penamaan, tata letak, atau susunan berkas yang belum
  pernah ditentukan di proyek ini
- Apa pun yang menyangkut **uang, domain, DNS, hosting, dan akun pihak ketiga**
  (Cloudflare, Google Cloud, Supabase) — jangan pernah mendaftar, membeli,
  mengubah pengaturan, atau men-*deploy* tanpa saya menyuruh
- **Migrasi SQL baru, penghapusan data, atau perubahan skema**
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
  `README.md`, `panduan_dokumentasi.md`, prompt serah terima).

### 🔴 Aturan yang lahir dari sesi-sesi sebelumnya — patuhi, ini mahal dipelajari

**1. Berhenti setelah dua percobaan perbaikan yang gagal.**
Satu cacat (Beranda kosong) dikejar **empat ronde berturut-turut**, dan seluruh
hasilnya akhirnya dibatalkan atas permintaan saya. Bila percobaan kedua gagal
**dan gejalanya berubah**, hentikan. Kembalikan keadaan, tanya saya, lalu ukur
bagian yang belum pernah diukur sama sekali.

**2. "Sekali coba berhasil" bukan bukti untuk cacat yang muncul kadang-kadang.**
Untuk cacat semacam itu, ulangi **minimal 4–5 kali** sebelum menyatakan beres.

**3. Kemudikan perangkat/peramban sendiri bila bisa; kalau tidak, UKUR.**

```powershell
$adb = "C:\Users\ACER\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb devices
& $adb shell input tap <x> <y>
& $adb exec-out screencap -p > layar.png
& $adb logcat -c ; & $adb logcat -v time > log.txt
```

⚠️ Ekstensi Claude in Chrome **tidak terpasang** — saya memilih tidak
memasangnya. Untuk apa pun di peramban, minta saya membuka dan melaporkannya,
**atau ukur sendiri dengan `curl`**. Mengukur server jauh lebih baik daripada
menebak: dua kali sesi lalu `curl -sI` langsung membedakan "salah unggah" dari
"simpanan Chrome".

**4. Alat uji yang lebih pemaaf daripada aslinya lebih berbahaya daripada tidak
menguji sama sekali.** Server tiruan Cloudflare memaafkan kesalahan yang
Cloudflare tolak. Uraiannya di `DEVIASI_LIBRARY.md` **O.3**.

**5. 🔴 Tes hanya menjawab "apakah ini bekerja seperti yang diperintahkan".**
Yang tidak dapat dijawabnya: "apakah perintahnya masuk akal dilihat manusia".
Beberapa cacat lolos ratusan tes karena **tidak ada yang rusak** — kolom cari
yang dobel, dasbor yang berhenti di separuh layar, panel admin yang tidak dapat
dicapai. **Terbitkan dan minta saya melihatnya sendiri sebelum menumpuk bab
berikutnya.** Uraiannya di **O.13** dan **P.2**.

**6. 🔴 Percabangan `kIsWeb` yang ditulis langsung di dalam kode TIDAK DAPAT
DIUJI.** `kIsWeb` konstanta waktu kompilasi; pada `flutter test` nilainya selalu
`false`, jadi cabang webnya tidak pernah dijalankan sekali pun. Pisahkan sebagai
fungsi yang menerima `isWeb`, lalu getter/widget-nya sekadar memanggil. Contoh:
`Env.oauthRedirectFor(isWeb:)` dan `SettingsPage.tampil(...)`. Uraiannya di
**O.14**.

## 🔴 Kebersihan cabang dan merge — BACA SEBELUM MENYENTUH GIT

Riwayat git ditulis ulang 29 Agustus 2026 untuk membuang penanda
`Co-Authored-By` dari seluruh commit. Uraiannya di `DEVIASI_LIBRARY.md`
bagian **R**. Tiga aturan yang lahir dari sana:

**1. JANGAN PERNAH menggabungkan cabang yang dibuat sebelum 29 Agustus 2026.**

Penulisan ulang hanya menyentuh `master`. Cabang lama (`worktree-desain-web`,
`worktree-bab-10`, `worktree-bab-9`, seluruh `claude/*`) masih menunjuk commit
lama lengkap dengan penandanya — sebagian membawa 40 commit sekaligus.
Menggabungkannya **mengembalikan seluruh jejak itu ke GitHub tanpa satu pun
peringatan**. Isinya sudah diperiksa dan tidak ada yang berharga; buang saja.

**2. Worktree yang dibuat sebelum tanggal itu wajib disamakan dulu.**

```
git diff <cabang> origin/master --stat   # harus KOSONG
git reset --hard origin/master
```

Nyaris terjadi: cabang `selesaikan-bab-10` masih menunjuk commit
pra-penulisan-ulang, dan satu commit berikutnya di sana akan menyeret seluruh
riwayat lama kembali.

**3. Periksa sebelum setiap push.**

```
git log master --grep="Co-Authored-By: Claude" --oneline
```

Harus kosong. Bila menghasilkan sesuatu, **jangan di-push** — lapor ke saya.

⚠️ Pencarian tanpa peduli huruf besar-kecil akan menemukan satu commit; itu
alarm palsu, kalimat biasa di badan pesan. Lihat R.4.

**Worktree baru selalu dibuat dari master:**

```
git worktree add .claude\worktrees\<nama> -b worktree-<nama> master
```

## Dokumen acuan

- `panduan_dokumentasi.md` — kitab suci proyek, Bab 0–17. **Baca bab yang sedang
  dikerjakan sebelum menulis kode.**
- `DEVIASI_LIBRARY.md` — **wajib dibaca lebih dulu.** Bagian **O** (Bab 10, web),
  **P** (Bab 12, pembayaran & Admin), **Q** (pembersihan), **M** (Bab 9), dan
  **N** (Bab 6).
- `supabase/README.md` — skema database, RLS, jebakan Supabase.
- `palet_warna_dan_tipografi.md` — palet resmi. §6 dan §7 mengikat.
- `desain/` — rancangan layar dari desainer, berupa SVG. **Gambar, bukan kode.**
  Angkanya yang mengikat: warna, ukuran huruf, lebar kolom, tinggi baris.
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

**Internet laptop saya berasal dari HP lewat kabel.** Bila HP dilepas, laptop
kehilangan internet — dan `flutter analyze` maupun `flutter test` **menggantung
lama** karena mengecek paket ke `pub.dev` lebih dulu. Jalan pintasnya:

```powershell
& "E:\flutter_sdk\flutter_3.44.8\bin\cache\dart-sdk\bin\dart.exe" analyze lib test
& "E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat" test --no-pub
```

**Worktree baru wajib dibangkitkan kodenya lebih dulu** (`.g.dart`,
`.freezed.dart`, dan `lib/l10n/generated/` semuanya ter-gitignore):

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

## Menerbitkan aplikasi web

```powershell
.\deploy_web.ps1
npx --yes wrangler@latest pages deploy build/deploy --project-name=kamelscan --branch=main --commit-dirty=true
```

Landing page di folder `.\landing` **ikut otomatis** — tidak perlu menyebut
`-Landing`. Perhatikan dua baris hijau sebelum mengunggah: *"Landing page
disalin"* dan *"Landing page menempati akar situs"*. Bila yang muncul kuning
*"Akar situs kosong"*, berhenti — tidak ada gunanya diunggah.

⚠️ **Empat jebakan yang sudah memakan berjam-jam — baca `DEVIASI_LIBRARY.md`
O.2 dan O.6 sebelum menyentuh apa pun yang menyangkut penerbitan:**

1. `deploy_web.ps1` **wajib** dijalankan dari PowerShell, bukan Git Bash, dan
   **tanpa penggabungan stderr** — keduanya menggagalkannya dengan cara yang
   tetap terlihat seperti berhasil.
2. Tujuan aturan `_redirects` **tidak boleh** berakhiran `.html`.
3. Pola `_redirects` **tidak boleh** `/app/*` — ia menelan `main.dart.js` dan
   seluruh aset, lalu aplikasinya jadi halaman putih walaupun `/app/login`
   menjawab 200.
4. Sesudah menerbitkan, Chrome menyajikan versi lama dari simpanannya. **Ctrl +
   Shift + R.** Ini sudah memakan satu ronde penuh.

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

⚠️ **Token akses Supabase punya masa berlaku.** Gejalanya `401 Unauthorized` —
bukan pesan yang menyebut kedaluwarsa. Periksa di
<https://supabase.com/dashboard/account/tokens>.

**Menjalankan migrasi SQL:** saya menjalankannya sendiri lewat Dashboard → SQL
Editor. Beri saya isi berkasnya beserta langkah yang **detail** — sebutkan menu
yang diklik dan hasil yang seharusnya muncul (`Success. No rows returned`).
Instruksi ringkas pernah membuat saya tersinggung karena terasa seperti diuji.

**Migrasi terakhir yang sudah dijalankan: 29.** Ketiga migrasi terbaru (27, 28,
29) sudah berjalan di produksi.

## Keadaan proyek — sudah selesai dan TERBUKTI di peramban/perangkat

**Bab 0–9 selesai** kecuali **9.9 Tutorial**. Rantai perekaman lengkap terbukti
di Redmi Note 9.

**Bab 10 SELESAI SELURUHNYA:**

| Bagian | Keadaan |
|---|---|
| 10.2 Aplikasi web terbit | ✅ `kamelscan.com/app` |
| 10.3 Rangka, sidebar 7 menu, laci di bawah 1024 px | ✅ |
| 10.4 Dasbor: 4 kartu + 2 grafik batang + rentang Kustom | ✅ |
| 10.5 Riwayat versi tabel + panel samping berpemutar tegak | ✅ |
| 10.6 Halaman bukti publik | ✅ |
| Landing page + Syarat & Ketentuan + Kebijakan Privasi | ✅ |
| Layar peluncur web, Android, iOS | ✅ |

**Yang juga sudah beres di luar Bab 10:**

- **Login Google di web** — terbukti dua akun (O.14)
- **Tautan verifikasi email & reset password di web** (O.10)
- **Aktivasi langganan** — migrasi 28, langganan sungguhan sudah aktif (P.1)
- **Panel Admin** — verifikasi pembayaran beserta menu dan tombol Keluar (P.2)

⚠️ Naskah **Syarat & Ketentuan** dan **Kebijakan Privasi** disusun desainer dan
**tidak pernah diperiksa penasihat hukum**. Saya memutuskan menerbitkannya apa
adanya setelah diberi tahu risikonya. Jangan membuka ulang keputusan itu.

## 🔴 Yang WAJIB ditanyakan ke saya di awal sesi

1. **Bagian mana yang dikerjakan lebih dulu**, dan seberapa jauh lingkupnya
   untuk sesi ini.
2. **Peramban dan lebar layar** yang saya pakai menguji. Terakhir: Chrome,
   laptop layar penuh, tema gelap.
3. Apakah ada yang berubah di server sejak prompt ini ditulis.

## 🔴 Utang yang belum lunas

### 1. 🔴 Langganan saya habis 25 September 2026

Bab 7.6: tanpa masa tenggang, terkunci seketika. Alur perpanjangannya
**belum pernah diuji sekali pun** — lihat utang nomor 2.

### 2. 🔴 Tombol Setujui/Tolak belum pernah dijalankan pada baris sungguhan

Halaman Admin → Verifikasi Pembayaran sudah jadi dan dapat dibuka, tetapi
daftarnya kosong saat diuji. Yang terbukti baru *"halamannya jalan"*, bukan
*"tombolnya bekerja"*. Prosedur pengujian yang aman ada di **P.4**.

### 3. 🔴 PRIORITAS: dua halaman Admin masih kosong

`Admin → Kelola Pengguna` dan `Admin → Daftar Pelanggan`. Keduanya sudah
tampil di menu dengan keterangan "Belum dikerjakan", jadi tidak menyesatkan —
tetapi panel admin baru berguna separuh tanpa keduanya. **Inilah yang saya
minta dikerjakan lebih dulu** (keputusan saya 29 Agustus 2026).
± 2 jam masing-masing.

Spesifikasinya Bab 11. `AdminRepository` sudah punya `fetchTenants`,
`changeTier`, dan `setTenantStatus` — ketiganya belum dipakai layar mana pun.

### 4. Bab 9.9 Tutorial — DITUNDA, menunggu channel YouTube

Halaman daftar bernomor dari tabel `tutorials`, membuka YouTube lewat
`url_launcher`. Versi webnya grid kartu (Bab 10.5).

⚠️ **Bukan prioritas, dan bukan karena terlupa.** Isinya bergantung pada video
tutorial yang belum dibuat; halaman yang jadi lebih dulu hanya akan menampilkan
daftar kosong. Saya memutuskan 29 Agustus 2026 untuk menunggu channel-nya siap.

Sampai saat itu, menu Tutorial di sidebar web dan di Beranda HP tetap mendarat
di halaman kosong. **Itu keadaan yang saya terima, bukan cacat yang terlewat.**
Perkiraan ± 2 jam begitu videonya ada.

### 5. Satu video sungguhan lewat jalur unggah latar belakang

Isolatenya terbukti hidup, tetapi antriannya selalu keburu dihabiskan jalur
aplikasi-terbuka. Prosedurnya di `DEVIASI_LIBRARY.md` **L.8**; butuh Wi-Fi.

### 6. Zoom peramban pada aplikasi web

Belum jelas apakah perlu diperbaiki. Tidak ada apa pun di kode yang menguncinya
(tidak ada `user-scalable=no`), tetapi Flutter web menata ulang isinya alih-alih
memperbesar, sehingga tidak terasa seperti zoom biasa. Bila saya
membutuhkannya, jalan yang lebih pasti adalah menambah pengaturan **ukuran
huruf** di Pengaturan → Tampilan (± 1 jam), bukan mengandalkan perilaku
peramban.

### 7. Versi tabel untuk Toko, Packer, dan Pembayaran — DIBATALKAN

Bab 10.5 memintanya, tetapi saya memutuskan 29 Agustus 2026 bahwa bentuk
sekarang (tampilan HP di dalam rangka web) sudah cukup. **Jangan
mengerjakannya** tanpa saya minta ulang.

## Jebakan yang sudah memakan waktu

**Umum:**

1. `flutter run` polos meracuni cache kernel — lihat di atas
2. Ekstensi Supabase ada di schema `extensions`, bukan `public`. Pakai
   `gen_random_uuid()`
3. Redirect URL tidak cocok → **tidak ada error**, diam-diam pakai Site URL.
   Sudah memakan waktu **tiga kali** (13 Agu, 25 Agu, 26 Agu)
4. Auth Hook wajib aktif, kalau tidak semua tabel mengembalikan **nol baris**
   tanpa pesan apa pun
5. `AppColors` adalah `ThemeExtension`, diakses lewat
   `Theme.of(context).extension<AppColors>()!`
6. `flutter analyze` di akar melaporkan error dari `tool/db_migrate`. Pakai
   `dart analyze lib test`
7. **Periksa worktree sebelum mempercayai hasil `analyze`/`test`.** Sesi pernah
   terlempar ke worktree lain diam-diam
8. **Peran dibawa di dalam JWT.** Sesudah mengubah `role` atau `tier_plan`,
   akunnya wajib keluar lalu masuk lagi. Gejalanya: layar masih menulis keadaan
   lama padahal database sudah benar

**Diagnosis:**

9. 🔴 **`AppLogger` tidak pernah sampai ke logcat.** Ia memakai
   `dart:developer`. Untuk jejak yang perlu dibaca dari perangkat, pakai
   `debugPrint` (tembus sebagai `I/flutter`). **Bila jalur berhasilnya dicetak,
   jalur gagalnya WAJIB ikut.**
10. Jejak `KAMELSCAN_*` yang sudah ada **sengaja permanen** — jangan dihapus
    sebagai sisa lupa dibersihkan

**Navigasi:**

11. 🔴 **Apa pun yang dibaca `RouteGuards.redirect` WAJIB ikut disimak
    `GoRouterRefreshNotifier`.** Nilai yang dibaca guard tetapi tidak disimak di
    sana menghasilkan **layar yang seharusnya berpindah, diam di tempat** —
    tanpa error apa pun.
12. **Alamat rute anak selalu disambung ke induknya.** `'/tutorial'` yang
    didaftarkan di bawah `/home` menjadi `/home/tutorial`; menuliskannya salah
    mendarat di "halaman tidak ditemukan" tanpa satu pun galat.
13. 🔴 **Layar yang berdiri di luar rangka aplikasi wajib punya dua jalan:
    masuk dan keluar.** Panel admin sempat tidak punya keduanya (P.2).

**Tata letak — sudah terjadi berkali-kali:**

14. 🔴 **Tombol bertema proyek ini menuntut lebar TAK TERHINGGA.**
    `filledButtonTheme` memakai `minimumSize: Size.fromHeight(...)`.
    Menaruhnya di dalam `Row` membuatnya melahap seluruh lebar. Batasnya harus
    datang dari `Expanded`. (M.12, M.17)
15. 🔴 **Chip ber-`mainAxisSize.min` menolak menyusut** dan meluber di kolom
    sempit. Teksnya wajib dibungkus `Flexible` + ellipsis. Tertangkap tes pada
    selisih **0,29 piksel**.
16. **`DropdownButtonFormField` wajib `isExpanded: true`**, dan nilai
    terpilihnya wajib ada di daftar pilihan — bila tidak, ia **melempar** dan
    meruntuhkan seluruh halaman.
17. **`LayoutBuilder` yang mengukur tinggi harus berdiri DI LUAR gulir.** Di
    dalam `SingleChildScrollView` tinggi yang tersedia tak terhingga.

**Uji tata letak:**

18. 🔴 **Tes tata letak WAJIB memakai `AppTheme` sungguhan.** Percobaan pertama
    pada M.12 memakai tema bawaan Flutter dan **lulus**, sehingga susunan yang
    rusak sempat dinyatakan baik-baik saja.
19. **`expect(tester.takeException(), isNull)`** adalah yang menangkap luberan
    `RenderFlex`. Tanpa baris itu, tesnya lulus sambil layarnya bergaris
    kuning-hitam.
