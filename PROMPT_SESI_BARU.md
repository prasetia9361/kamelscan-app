# Prompt untuk sesi baru

Salin seluruh isi di bawah garis ini ke sesi Claude Code yang baru.

---

Kamu adalah programmer Flutter profesional yang melanjutkan proyek **KamelScan**
— aplikasi SaaS perekaman video bukti packing berbasis pemicu barcode/QR.

**Bab 10 (web) dan Bab 11 (panel Admin) SUDAH SELESAI SELURUHNYA dan
terbukti di peramban.** Aplikasinya hidup di `https://kamelscan.com/app`,
landing page di `https://kamelscan.com`.

**Rencana Product Owner, ditetapkan 29 Agustus 2026:**

| Tanggal | Pekerjaan |
|---|---|
| ~~30 Agustus~~ | ✅ **SELESAI — Bab 12 Midtrans jalan di Sandbox**, kelima skenario aturan 6 lulus (P.7) |
| 31 Agustus | Optimasi menyeluruh, berburu bug, lalu **mengganti database yang dipakai produksi**. |
| 1 September | Rilis iOS, persiapan produksi, dan memeriksa apa lagi yang dibutuhkan untuk unggah ke Google Play & App Store. |

Product Owner membuat **worktree baru per tanggal**. Tutorial (Bab 9.9) tetap
ditunda menunggu channel YouTube-nya siap — lihat daftar utang di bawah.

🔴 **Midtrans masih di SANDBOX, dan itu disengaja.** Untuk pindah ke produksi,
`MIDTRANS_SERVER_KEY` dan `MIDTRANS_IS_PRODUCTION` harus diganti **bersamaan** —
mengganti salah satu saja membuat setiap pembayaran gagal tanpa penjelasan yang
berguna. Uraiannya di `DEVIASI_LIBRARY.md` **P.7**.

⚠️ Saya memutuskan menundanya sampai database produksi final: menyalakan uang
sungguhan lebih dulu berarti transaksi pertama lahir di database yang akan
diganti.

⚠️ **Awalan kunci Midtrans di akun saya SAMA untuk sandbox dan produksi**
(`Mid-server-`), tidak ada `SB-`. Jangan menebak dari awalannya — cara
membedakannya yang benar ada di P.7. `dataapp.md` baris 106–109 Sandbox, baris
111–114 Produksi.

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
5. 🔴 **Ctrl + Shift + R TIDAK selalu cukup.** Flutter web memasang *service
   worker*, dan ia menyajikan salinannya sendiri melewati muat ulang paksa.
   Memakan 40 menit pada 29 Agustus 2026. Pembersihannya:
   **F12 → Application → Service Workers → Unregister → Ctrl + Shift + R**
   (login saya tidak hilang; `localStorage` tidak ikut terhapus). Uji tercepat
   untuk memastikan siapa yang salah: **jendela Samaran**. Uraiannya di
   `DEVIASI_LIBRARY.md` **O.17**.

🔴 **`wrangler pages deploy` HARUS saya yang jalankan, bukan kamu.** Sesi
non-interaktif menuntut `CLOUDFLARE_API_TOKEN`, dan token itu tidak ada di
`dataapp.md`. Kamu boleh menjalankan `deploy_web.ps1` (hanya membangun ke
`build/deploy`, tidak menyentuh Cloudflare), lalu minta saya menjalankan
perintah unggahnya dengan awalan `!`.

🔴 **Setiap rute baru di `route_names.dart` WAJIB ditambahkan ke daftar rute di
`deploy_web.ps1`.** Yang terlupa bekerja saat diklik dari dalam aplikasi tetapi
rusak begitu halamannya disegarkan atau alamatnya dikirim ke orang lain.

⚠️ **Gejalanya BUKAN 404** — kalimat itu salah, dan sempat tertulis di catatan
ini maupun di komentar `deploy_web.ps1` selama berbulan-bulan. Diukur di
produksi 1 September 2026 pada rute `/deletion-pending` yang memang terlupa:

```
/app/complete-profile  -> 200, 13327 byte, flutter_bootstrap.js x1   (aplikasi)
/app/deletion-pending  -> 200, 35969 byte, flutter_bootstrap.js x0   (LANDING)
```

Alamatnya menjawab **200 sambil menyajikan halaman landing**, tampil tanpa gaya
sama sekali karena CSS-nya dicari relatif terhadap folder yang tidak ada. Itu
lebih jahat daripada 404: 404 kelihatan jelas rusak, sedangkan ini terbaca
seperti **aplikasinya** yang rusak — dan penyelidikan berangkat ke arah yang
salah sejak menit pertama.

🔴 **Cara memeriksanya yang benar bukan kode status, melainkan isinya:**

```bash
curl -s https://kamelscan.com/app/<rute> | grep -c "flutter_bootstrap.js"
```

Harus **1**. Nol berarti yang tersaji halaman landing, berapa pun kode
statusnya. Pola bertanda bintang menutupi anaknya (`account/*` menutupi
`/account/delete`), tetapi **tidak** menutupi rute tingkat atas yang kebetulan
mirip namanya.

Periksa dengan **tiga langkah**, bukan hanya kode status. Langkah ketiga yang
menentukan, dan paling sering dilupakan:

```bash
# 1. Content-Type WAJIB application/javascript, bukan text/html
curl -sI https://kamelscan.com/app/main.dart.js | grep -iE "content-type|content-length"

# 2. Content-Length harus SAMA dengan berkas lokal
wc -c build/deploy/app/main.dart.js

# 3. Isinya benar-benar baru — cari teks yang HANYA ada di versi baru.
#    Teks l10n terbawa apa adanya ke dalam main.dart.js.
curl -s https://kamelscan.com/app/main.dart.js | grep -c "<kalimat baru dari ARB>"
```

Bila ketiganya benar tetapi saya masih melihat versi lama, penyebabnya service
worker — bukan unggahannya. Lihat jebakan nomor 5 di atas.

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

**Migrasi terakhir yang sudah dijalankan: 44** (2 September 2026). Seluruhnya
sudah berjalan di produksi:

⚠️ **43 ada di worktree lain, dan sudah dijalankan juga.** Berkasnya
`43_user_settings_show_record_fab.sql` di `revisi-desain-aplikasimobile`,
dijalankan Product Owner 3 September 2026. Diukur ke produksi hari itu: kolom
`user_settings.show_record_fab` **ada** dan terisi. Jadi 37–44 lengkap tanpa
lubang, hanya berkas nomor 43-nya yang tidak berada di worktree ini.

- **30** `get_platform_stats()` — angka Dasbor Platform
- **31** `admin_list_tenants()` — tabel Kelola Pengguna
- **32** alasan penolakan, jejak audit tenant, penyesuaian token, pemberian
  token serentak
- **33** `promote_to_admin()`, `demote_to_owner()`, `list_admins()`
- **34** `promos.used_count` akhirnya dihitung — batas pemakaian promo berlaku
- **35** `admin_change_tier()` — ubah paket kini menyesuaikan kuota & saldo token
- **36** `cancel_pending_subscription()` — pelanggan dapat membatalkan tagihannya
- **37** hapus akun Owner + antrean `storage_purge_queue`
- **38** tiga bug akun packer
- **39** enum `bisnis` + `token_expired`, harga 3 paket, trial 5 packer
- **40** rollover token, cabut cron isi ulang, token hangus, `admin_change_tier`
- **41** antrean retensi 30 hari, cabut `mark-expired-videos`
- **42** `get_capacity_stats()` — RPC kartu Kapasitas
- **44** `check_packer_limit()` membaca kunci `trial`, menutup celah batas
  packer masa uji coba yang sebelumnya tidak ditegakkan di mana pun

**Edge Function terpasang: 10.** Dua yang terbaru `delete-packer` (versi 6,
di-deploy ulang 1 Sep 2026 karena memanggil RPC migrasi 38) dan `purge-storage`
(versi 1, baru).

🔴 **`npx supabase@latest` TIDAK LAGI JALAN DI WINDOWS.** Galatnya
`No matching Supabase CLI binary package found for win32-x64`, dan itu
menyesatkan — Windows *didukung*, tetapi paket binari
`@supabase/cli-windows-x64` gagal terpasang sebagai *optional dependency*
sehingga folder `node_modules/@supabase` tinggal kosong. Jalan pintasnya:

```powershell
npm install --prefix <folder> --include=optional supabase@2.116.0
& '<folder>\node_modules\@supabase\cli-windows-x64\bin\supabase.exe' functions deploy <nama> --project-ref ofggpithmvgnhsshglwx
```

⚠️ `dart run build_runner build` sekarang menolak `--delete-conflicting-outputs`
(*"These options have been removed and were ignored"*). Bukan galat, hanya
peringatan — tetapi perintah di bagian Lingkungan di atas perlu dibaca dengan
itu di kepala.

🔴 `midtrans-webhook` WAJIB di-deploy dengan `--no-verify-jwt`. Periksa dengan
`supabase functions list` — kolom `verify_jwt` harus `False` untuk webhook itu
saja, `True` untuk semua yang lain.

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

**Bab 11 (PANEL ADMIN) SELESAI SELURUHNYA — 29 Agustus 2026.** Delapan
halaman, uraiannya di `DEVIASI_LIBRARY.md` **P.5**:

| Bagian | Keadaan |
|---|---|
| 11.1 Dasbor platform | ✅ |
| 11.2 Manajemen pengguna | ✅ tabel 10 kolom + 5 aksi |
| 11.3 Harga & paket | ✅ termasuk biaya infrastruktur |
| 11.4 Promo | ✅ CRUD penuh |
| 11.5 Kontak | ✅ (gambar iklan ditunda) |
| 11.6 Metode pembayaran | ✅ sakelar Midtrans + rekening |
| 11.7 Verifikasi pembayaran | ✅ + alasan penolakan |
| *(di luar Bab 11)* Buat Akun Admin | ✅ halaman **panduan**, bukan pembuat akun — lihat P.3 |

🔴 **Tiga keputusan dagang di panel Admin yang TIDAK BOLEH diubah diam-diam**
— seluruhnya diuraikan di **P.5**:

1. Perpanjangan manual **disambung** dari sisa hari, berbeda dari pembayaran
   otomatis yang menghitung ulang 30 hari.
2. Token bonus **hangus** pada reset periode berikutnya, dan tanggalnya dibaca
   dari `token_wallets.period_end` — bukan `tenants.period_end`.
3. Pemberian token serentak hanya ke yang berstatus `active`, dan **hanya
   menambah**.

**Yang juga sudah beres di luar Bab 10:**

- **Login Google di web** — terbukti dua akun (O.14)
- **Tautan verifikasi email & reset password di web** (O.10)
- **Aktivasi langganan** — migrasi 28, langganan sungguhan sudah aktif (P.1)
- **Setujui & Tolak pembayaran** — terbukti pada baris sungguhan 29 Agustus
  2026 (P.4). Penolakan kini terlihat pelanggan beserta alasannya (P.6).
- **Bab 12.3 Midtrans Snap** — dua Edge Function terbit, kelima skenario aturan
  6 lulus di Sandbox 31 Agustus 2026 (P.7). Nominal dihitung di server, bukan
  dikirim aplikasi.
- **Bab 12.5** — jalur bayar ditutup di aplikasi HP supaya tidak ditolak App
  Store. Di HP paket tetap terlihat, pembayarannya diarahkan ke dasbor web.
- **Pelanggan dapat membatalkan tagihannya sendiri** (migrasi 36, P.8) —
  sebelumnya satu tagihan yang ditinggalkan mengurungnya tanpa batas waktu.

⚠️ Naskah **Syarat & Ketentuan** dan **Kebijakan Privasi** disusun desainer dan
**tidak pernah diperiksa penasihat hukum**. Saya memutuskan menerbitkannya apa
adanya setelah diberi tahu risikonya. Jangan membuka ulang keputusan itu.

## 🔴 Yang WAJIB ditanyakan ke saya di awal sesi

1. **Bagian mana yang dikerjakan lebih dulu**, dan seberapa jauh lingkupnya
   untuk sesi ini.
2. **Peramban dan lebar layar** yang saya pakai menguji. Terakhir: Chrome,
   laptop layar penuh, tema gelap.
3. Apakah ada yang berubah di server sejak prompt ini ditulis.

## 🔴 SESI 31 AGUSTUS – 3 SEPTEMBER 2026 — BACA INI LEBIH DULU

Seluruh pekerjaan di bawah ada di worktree **`31-agustus`** (cabang
`worktree-31-agustus`, lahir dari master `4cb9cbc`).

**Keadaannya:** `dart analyze lib test` bersih, **625 uji lolos**, dan pohon
kerjanya **bersih — tidak ada yang belum di-commit**. Belum di-push, dan
**belum digabung ke `master` atas keputusan Product Owner** — penggabungannya
menyusul. Jumlah commit sengaja tidak ditulis di sini; `git log 4cb9cbc..HEAD`
selalu lebih benar daripada angka yang disalin tangan.

Migrasi **37–44 sudah dijalankan di produksi**, Edge Function berjumlah **10**,
dan aplikasi webnya sudah diterbitkan ulang. Seluruh pekerjaan sesi ini
**diuji Product Owner langsung di produksi**, bukan hanya lewat tes.

### ✅ TABRAKAN NOMOR MIGRASI — SUDAH BERES 1 September 2026

Sempat ada **dua berkas migrasi bernomor 37** di dua worktree berbeda. Product
Owner menomori ulang yang di `revisi-desain-aplikasimobile` menjadi
`43_user_settings_show_record_fab.sql`, dan itu arah yang benar — menomori ulang
migrasi yang sudah terlanjur berjalan di produksi hanya merusak catatannya.

✅ **43 sudah dijalankan juga**, pada 3 September 2026, dan Product Owner sudah
menjalankan aplikasinya. Penomoran ulang itu terbukti benar: tidak ada nomor
kembar, tidak ada yang terlewat, dan 37–44 kini lengkap di produksi.

### Migrasi yang dibuat sesi ini

Seluruhnya **sudah dijalankan Product Owner di produksi, 1 September 2026.**

| No | Berkas | Isi | Status |
|---|---|---|---|
| 37 | `account_deletion` | Hapus akun Owner + antrean `storage_purge_queue` | ✅ terverifikasi |
| 38 | `packer_fixes` | 3 bug akun packer | ✅ |
| 39 | `tier_bisnis` | Enum `bisnis` + `token_expired`, harga 3 paket, trial 5 packer | ✅ |
| 40 | `token_rollover` | Rollover, cabut cron isi ulang, token hangus, `admin_change_tier` | ✅ |
| 41 | `retention_purge` | Antrean retensi 30 hari, cabut `mark-expired-videos` | ✅ |
| 42 | `capacity_stats` | RPC kartu Kapasitas | ✅ |

🔴 **39 WAJIB dijalankan terpisah dari 40.** PostgreSQL menolak memakai nilai
enum baru di transaksi yang sama dengan penambahannya; digabung, galatnya
berbunyi *"unsafe use of new value of enum type"* — menyesatkan, karena
masalahnya bukan nilai itu.

### Edge Function

- ✅ **`delete-packer` sudah di-deploy ulang** (versi 6, 1 Sep 2026) — ia
  memanggil RPC `purge_packer_soft_deleted_videos()` dari migrasi 38.
- ✅ **`purge-storage` sudah terbit** (versi 1) — penguras antrean R2.
  `verify_jwt` sengaja **`true`**: fungsinya sudah memeriksa
  `Authorization` lawan service role key secara *constant-time* di dalam
  dirinya sendiri, dan service role key sendiri adalah JWT yang sah sehingga
  lolos gerbangnya. `midtrans-webhook` tetap satu-satunya yang `false`.
- 🔴 **Pemicu antrean R2 MASIH belum ada.** `pg_net` belum aktif di proyek ini.
  Product Owner **sengaja menundanya** sampai database produksi final, supaya
  tidak dipasang dua kali.

  ⚠️ Akibatnya sekarang: `purge-storage` sudah terpasang tetapi **tidak ada
  satu pun yang memanggilnya**. Antreannya terisi, berkas R2-nya tetap utuh
  dan tetap ditagihkan. Ini keadaan yang diterima, bukan cacat yang terlewat —
  tetapi ia berhenti diterima begitu database produksi final.

### Keputusan produk yang FINAL (jangan diperdebatkan ulang)

**Tiga paket, hanya berbeda pada harga, jumlah token, dan durasi:**

| | Standar | Pro | Bisnis |
|---|---|---|---|
| Harga | Rp 149.000 | Rp 299.000 | Rp 1.490.000 |
| Token | 2.000 | 5.000 | 30.000 |
| Durasi | 30 detik | 60 detik | **3 menit** |

Retensi **30 hari ketiganya**. Packer **tak terbatas ketiganya**; masa uji coba
**5 packer** dengan pengaturannya sendiri.

**Model token — akumulatif (rollover):**
- Beli lagi → token **ditambahkan**, sisa hari **ditambahkan**, tier mengikuti
  **pembelian terakhir** (dua arah, naik maupun turun).
- Token **hidup selama langganannya hidup**, hangus saat langganan berakhir
  (pilihan B, dipilih Product Owner). Bukan 30 hari sejak pembelian.
- **Tidak ada lagi isi ulang bulanan otomatis.** Token hanya datang dari
  pembelian. Cron `reset-monthly-tokens` dicabut migrasi 40.
- Tombol **Ubah Paket** milik Admin hanya mengubah tier, **tidak menyentuh
  saldo**.

**Dibatalkan, tidak jadi ada:**
- **Watermark logo kustom** (1 Sep 2026) — seluruh paket memakai watermark
  teks. Pembedanya sudah dibuang dari aplikasi 29 Agustus; dokumen menyusul.
- **`package_videos.thumbnail_key`** — tidak dipakai, tidak akan dibuat.
  Diukur 1 Sep 2026: 0 dari 50 baris terisi. Kolomnya **sengaja tidak
  dihapus**.

⚠️ **Harga Bisnis tetap Rp 1.490.000.** Claude menyarankan menurunkannya ke
kisaran Rp 800.000 (lompatannya 5x harga untuk 3x durasi, sementara pembeda
sesungguhnya bagi pelanggan bervolume rendah hanya durasi). Product Owner
menimbangnya dan memutuskan tetap. Tercatat di Bab 7.1 — jangan diangkat lagi
kecuali Product Owner yang memulai.

### Yang dibangun di aplikasi

1. **Hapus akun Owner** — penghalang App Store 5.1.1(v). Konfirmasi ketik nama
   usaha (diverifikasi di server), akun langsung terkunci, data musnah 7 hari,
   trial musnah seketika. Penjaga rute mengunci **setiap** rute.
2. **Tiga bug akun packer** — hitungan video mengecualikan `status='deleted'`,
   `is_active` ditegakkan di jalur masuk **dan** di `before_video_insert()`,
   batas packer menghitung yang aktif saja.
3. **Ekspor CSV** di Riwayat web, Owner saja. Mengekspor **hasil saringan**
   (maks 20.000 baris), bukan halaman yang terlihat.
4. **Kartu Kapasitas** di Statistik Platform — menonjolkan *"batas tercapai
   sekitar N bulan lagi"*, bukan angka mentah.
5. **Tombol ke dasbor web** di kartu peringatan bayar versi HP.

### Angka biaya yang sudah diukur (bukan tebakan)

Dari 50 video sungguhan di produksi: **3,49 MB per menit**
(rata-rata 1,07 MB pada 18,4 detik). Dipakai menghitung simpanan R2 per paket.
Kalau perlu menghitung ulang margin, mulai dari angka ini.

### 🔴 Dua klaim Claude yang TERBUKTI SALAH di sesi ini

Ditulis di sini supaya tidak diulang:

1. **"`delete from tenants` gagal karena FK RESTRICT"** — **salah**. Diukur di
   produksi: justru **berhasil**, karena cascade menghapus `package_videos`
   sebelum `users`. Yang gagal adalah menghapus lewat `auth.users`
   (`23503 package_videos_user_id_fkey`) — dan itu kebetulan memang jalur yang
   ditempuh `purge_tenant()`. Urutannya tetap perlu; alasan yang semula
   ditulis karangan. Sudah diperbaiki di kepala migrasi 37.
2. **"Bug batas packer tidak tereproduksi"** — **salah**. Hanya sisi server
   yang diperiksa. Bugnya nyata dan ada di aplikasi: `packers_page.dart`
   memakai `items.length` yang memuat packer nonaktif.

**Pelajarannya sama untuk keduanya: ukur, jangan menyimpulkan dari ingatan.**

### 🔴 Dua cacat yang ditemukan 1 September 2026, SESUDAH migrasi dijalankan

Keduanya lahir dari migrasi 39/40, dan **tidak satu pun tertangkap oleh 620 tes
yang lolos** — karena tidak ada yang rusak. Keduanya sudah diperbaiki.

**1. `LedgerReason` melempar untuk `token_expired`.**
Migrasi 39 menambahkan nilai enum `token_expired`; migrasi 40 memasang cron
`expire-tenant-tokens` (tiap 01:45) yang menulisnya ke `token_ledger`. Di Dart,
`LedgerReason` adalah **satu-satunya** enum di `enums.dart` yang tidak punya
nilai jatuhan — `TierPlan`, `SubStatus`, dan `VideoType` semuanya punya
`fromWire`. Jadi ia di-decode `$enumDecode` yang **melempar**.

Terpendam saat ditemukan karena `fetchLedger()` belum punya satu pun pemanggil.
Ia akan menggigit pada hari layar riwayat token dibuat.

Perbaikannya: nilai `tokenExpired`, nilai jatuhan `unknown`, `fromWire`, dan
`@JsonKey(fromJson: LedgerReason.fromWire)` di `token_wallet.dart` supaya
jatuhannya benar-benar dijalankan. Jatuhannya sengaja **bukan** alasan yang
sudah ada: buku besar token dipakai menyelesaikan sengketa dengan pelanggan
(Bab 7.2 poin 5), dan melabeli baris sistem sebagai `admin_adjust` berarti
memalsukan bukti di dokumen yang gunanya justru membuktikan. Aman karena
aplikasi tidak punya izin tulis ke `token_ledger` sama sekali (migrasi 14).

**2. Lima kalimat Admin menjanjikan "reset" yang sudah dicabut.**
Migrasi 40 baris 36 menjalankan `cron.unschedule('reset-monthly-tokens')` —
tidak ada lagi reset bulanan. Tetapi lima kalimat masih menjanjikannya, dan
dialog atur token bahkan menampilkan **tanggal dari `token_wallets.period_end`**
untuk peristiwa yang tidak akan pernah terjadi lagi.

Aturan yang berlaku sekarang: token hangus saat **langganan berakhir** —
`expire-tenants` (01:30) membalik tenant `active` menjadi `expired`, lalu
`expire-tenant-tokens` (01:45) menghanguskan saldonya. `expire-tenants` **tidak
menyentuh `trial` maupun `suspended`**, jadi keduanya memang tidak hangus
dengan sendirinya.

Sumber tanggalnya dipindah ke `tenants.period_end`
(`AdminTenantRow.tokenResetsAt` → `tokenExpiresAt`).

🔴 **Yang paling perlu diingat dari cacat kedua:** ada satu tes yang justru
**mengunci perilaku lama** — `admin_users_table_test.dart`, *"pelanggan aktif —
memakai tanggal reset DOMPET"*. Tes itu benar saat ditulis dan menjadi salah
tanpa pernah gagal. Sesudah mengubah aturan dagang di SQL, **tes yang lulus
adalah tempat pertama yang harus dicurigai**, bukan yang terakhir.

### 🔴 PUTARAN PENGUJIAN PRODUKSI 1–3 September 2026 — sembilan cacat lagi

Product Owner menguji seluruh pekerjaan sesi ini **langsung di produksi**, satu
butir demi satu butir. Sembilan cacat yang ditemukan tidak satu pun tertangkap
oleh 620 tes yang lolos. Seluruhnya sudah diperbaiki dan **diverifikasi ulang
oleh Product Owner**.

⚠️ **Pelajaran nomor satu, dan ia mahal:** putaran pengujian pertama nyaris
seluruhnya sia-sia karena **webnya tidak pernah di-deploy**. Lima dari enam
"cacat" hari itu hanyalah kode lama yang masih tayang. Sebelum menguji apa pun,
**buktikan dulu build yang tayang memang memuat pekerjaannya**:

```bash
curl -s https://kamelscan.com/app/main.dart.js | grep -c "<kalimat baru dari ARB>"
```

**Tiga pola yang berulang, dan ketiganya layak dicurigai lebih dulu di sesi
berikutnya:**

**Pola A — kode yang menyebut nama paket satu per satu.** Muncul **tiga kali**,
seluruhnya berdiri tepat di sebelah komentar yang menjanjikan katalognya
dibangun dinamis:

- `admin_pricing_page.dart` menyusun `kartu[0]` dan `kartu[1]` di kedua cabang
  tata letak, sehingga paket Bisnis **tidak pernah digambar**
- `create-payment/index.ts` menolak `plan !== 'standar' && plan !== 'pro'`,
  sehingga membeli Bisnis gagal dengan pesan *"terjadi kesalahan"* yang tidak
  menyebut apa pun
- tesnya sendiri mengunci `findsNWidgets(2)`

**Pola B — tes yang lulus sambil mengunci cacatnya.** Dua kali dalam satu sesi:
tanggal reset dompet, dan jumlah kartu paket. Keduanya benar saat ditulis.

**Pola C — nilai yang dibaca penjaga rute tetapi tidak disimak notifier.**
Jebakan nomor 11, dan ia **berulang dua kali dalam satu sesi**: pertama karena
keadaan penghapusan tidak disimak sama sekali, lalu karena yang disimak hanya
turunan sempitnya sementara penjaganya membaca `sessionProvider` utuh. Aturannya
harfiah — **yang DIBACA `redirect`, itu yang wajib disimak.**

**Daftar sembilan cacatnya:**

| # | Cacat | Tempat |
|---|---|---|
| 1 | `LedgerReason` melempar untuk `token_expired` | `enums.dart` |
| 2 | Lima kalimat Admin menjanjikan "reset" yang sudah dicabut | ARB + `admin_tenant_row.dart` |
| 3 | Rute `/deletion-pending` tidak terdaftar di `_redirects` | `deploy_web.ps1` |
| 4 | Landing page rusak di alamat dalam (jalur aset relatif) | `landing/*.html` |
| 5 | Batas 5 packer masa uji coba tidak ditegakkan di mana pun | `create-packer` + migrasi 44 |
| 6 | Admin Harga & Paket hanya menggambar dua kartu | `admin_pricing_page.dart` |
| 7 | `create-payment` menolak paket Bisnis | `create-payment/index.ts` |
| 8 | Paket yang sedang aktif tidak dapat dibeli lagi | `plan_page.dart` |
| 9 | Hitungan video packer memuat video yang sudah dihapus | `user_repository.dart` |

Ditambah dua cacat navigasi hapus akun (permintaan dan pembatalan), dan dua
perbaikan kartu token pelanggan.

🔴 **Cacat nomor 5 yang paling perlu diingat sebagai pelajaran menulis migrasi.**
Migrasi 39 **meramalkannya sendiri di komentarnya** — *"pendaftar baru dapat
membuat seratus akun packer tanpa membayar sepeser pun"* — lalu menambal
`platform_settings` kunci `trial` dan menulis bahwa Dart harus membacanya.
Tambalannya benar. Yang tidak pernah terjadi: **tidak ada satu pun penegak yang
membaca kunci itu.** Menulis peringatan di komentar bukan menutup celah.

**Bukti model token akumulatif, dari `token_ledger` produksi.** Tujuh pembelian
beruntun pada akun *Sarang sarung*, seluruhnya **menambah**, tidak satu pun
menimpa:

```
+5000 → 5992    +2000 → 7992    +5000 → 12992   +30000 → 42992
+30000 → 72992  +2000 → 74992   +30000 → 104992
```

Sisa hari ikut bertumpuk (`period_end` 28 Apr 2027), dan tier mengikuti
pembelian terakhir: Standar pukul 15:25, lalu Bisnis 15:26, dan tier akhirnya
`bisnis`. **Ketiga aturan Bab 7.2 terbukti sekaligus pada data sungguhan** —
jangan diuji ulang dari nol tanpa alasan.

⚠️ **Jebakan Windows yang baru:** `npx supabase@latest` tidak lagi jalan di
Windows; uraiannya di bagian Supabase di atas.

### Catatan berkas

- **`panduan_dokumentasi.md` ada di `.gitignore`.** Revisi besar sesi ini
  (Bab 0, 2.2, 5.2, 5.6, 7.1, 7.2, 7.5, 9.6, 9.8, 12.4) **hanya hidup di
  worktree `31-agustus`**. Salin ke checkout utama bila ingin disimpan.
- **Dependensi baru:** `web: ^1.1.1` di `pubspec.yaml`. Sudah ada di
  `pubspec.lock` sebagai transitif dengan versi sama, jadi tidak menarik paket
  baru — hanya dinyatakan karena `file_download_web.dart` mengimpornya
  langsung.

## 🔴 TUGAS SESI BERIKUTNYA — ditetapkan Product Owner 3 September 2026

Dikerjakan **berurutan**. Yang (a) lebih dulu, karena (b) menambah layar di
atas rancangan yang sedang diganti — mengerjakannya terbalik berarti menulis
layar dua kali.

### a. Implementasi rancangan ulang aplikasi HP

Desainer sudah membuat rancangan UI/UX aplikasi HP di worktree
**`revisi-desain-aplikasimobile`**.

🔴 **Masalah pokoknya: worktree itu lahir dari `master`, jadi programnya
TERTINGGAL JAUH dari `31-agustus`.** Ia tidak punya satu pun pekerjaan sesi ini
— hapus akun, tier Bisnis, rollover token, ekspor CSV, kartu Kapasitas,
perbaikan packer, dan sembilan cacat produksi di atas.

**Karena itu urutannya WAJIB begini, dan jangan dibalik:**

1. **Baca dulu** program di `revisi-desain-aplikasimobile`. Jangan menyalin apa
   pun sebelum tahu apa saja yang berubah di sana.
2. **Buat rencana kerja** dan tunjukkan ke Product Owner sebelum menulis kode.
3. **Bawa rancangannya ke worktree ini**, bukan sebaliknya. Menggabungkan arah
   sebaliknya akan membuang pekerjaan sesi 31 Agustus – 3 September.

⚠️ **Jangan sampai pekerjaan di worktree ini terbuang.** Itu kalimat Product
Owner sendiri, dan ia menyebutnya sebagai syarat, bukan harapan.

✅ **Migrasi 43 sudah dijalankan** (3 September 2026), dan Product Owner sudah
menjalankan aplikasi dari worktree itu. Kolom `user_settings.show_record_fab`
terverifikasi ada di produksi. Jadi databasenya **sudah siap** menerima
rancangan itu — yang tertinggal hanya kode Dart-nya.

⚠️ Berkas migrasi 43 **tidak ada di worktree ini**. Bila kodenya dibawa ke
sini, berkas SQL-nya perlu ikut dibawa supaya riwayat migrasinya tidak
berlubang — meskipun isinya sudah terlanjur berjalan di database.

### b. Setelah rancangan selesai — tiga pekerjaan

**1. Menu Tutorial (Bab 9.9).** Utang paling lama di proyek ini, dan sekarang
dijadwalkan.

- Admin: halaman untuk memasukkan **tautan YouTube** beserta daftarnya
- Owner dan packer: daftar tutorial yang sudah didaftarkan Admin, diketuk →
  membuka videonya di YouTube (`url_launcher`)
- Tabel `tutorials` sudah ada sejak migrasi 10; CRUD Admin-nya yang belum

**2. Riwayat pembayaran.** Diminta Product Owner setelah melihat saldonya
sendiri menjadi 105.092 token dari tujuh pembelian, dan menyadari **tidak ada
satu layar pun yang dapat menjelaskan angka itu**. Sejak model akumulatif
(migrasi 40) riwayat berhenti menjadi kemewahan.

Yang wajib ditampilkan tiap baris:

- Waktu pembayaran
- Tier yang dibeli
- Jumlah token yang dibeli
- Tanggal dan waktu masa aktifnya berakhir
- Jenis pembayaran yang dipakai

Datanya sudah lengkap di `subscriptions` dan `token_ledger`; belum ada yang
menampilkannya.

**3. Nomor HP di halaman Kelola Pengguna milik Admin.** Kolomnya ditambahkan
ke tabel yang sudah ada.

### c. Analisis sistem perekaman — penjelasan dulu, baru optimasi

Product Owner meminta **penjelasan menyeluruh** cara kerja perekaman packing
dan retur, dari persiapan sampai selesai, lalu menilai apakah prosesnya sudah
efektif dan efisien.

**Sasaran ukurannya:** dari **3,48 MB/menit** (angka terukur dari 50 video
produksi) turun ke **2–3 MB/menit**.

🔴 **Syarat yang tidak boleh dilanggar: FPS harus lancar, jangan sampai patah-
patah.** Product Owner menyatakan hal lain masih dapat ditoleransi, tetapi yang
ini tidak. Artinya: **jangan menukar kelancaran demi ukuran berkas.**

⚠️ Sebelum menyelidiki laporan "patah-patah", **tanyakan dulu mode apa yang
dipakai** — mode debug memang sengaja lambat, dan itu sudah pernah memakan
waktu.

## 🔴 Yang belum siap produksi — daftar lengkap per 3 September 2026

Diurutkan menurut yang menghalangi rilis, bukan menurut kemudahannya.

**Penghalang uang:**

1. 🔴 **Midtrans masih SANDBOX.** Belum satu rupiah sungguhan pernah berpindah.
   `MIDTRANS_SERVER_KEY` dan `MIDTRANS_IS_PRODUCTION` wajib diganti
   **bersamaan** (P.7). Ditunda Product Owner sampai database produksi final.
2. 🔴 **Database produksi belum diganti.** Rencana 31 Agustus yang belum
   dijalankan, dan ia menghalangi butir 1 sekaligus butir 3.
3. **Dua kegagalan Midtrans berbagi satu pesan** — `MIDTRANS_UNREACHABLE` dan
   `MIDTRANS_REJECTED` tidak dapat dibedakan dari layar maupun dari catatan
   fungsi. Sudah terbukti memakan waktu; ± 30 menit memperbaikinya.

**Penghalang biaya yang berjalan diam-diam:**

4. 🔴 **Pemicu antrean R2 belum ada.** `purge-storage` sudah terbit tetapi
   **tidak ada yang memanggilnya** karena `pg_net` belum aktif. Antreannya
   terisi, berkasnya tetap di R2, dan tetap ditagihkan tiap bulan. Sengaja
   ditunda sampai database produksi final — tetapi ia berhenti dapat diterima
   begitu database itu final.

**Penghalang toko aplikasi:**

5. **Rilis iOS dan persiapan Google Play / App Store** belum dimulai.
6. **Layar putih 30 detik** saat aplikasi pertama dibuka (O.15), diserahkan ke
   desainer 26 Agustus.

**Belum pernah diuji:**

7. ✅ **Aplikasi HP sudah diuji 3 September 2026** — hapus akun benar, hitungan
   token sama dengan web (135.092/30.000), dan tiga paket muncul. Dua temuan
   dari putaran itu:

   - **Pilihan paket hilang saat HP → web.** Nyata, sudah diperbaiki:
     `?plan=` kini ikut dibawa. Sekalian pilihan bawaan halaman pembayaran
     diubah menjadi **paket yang sedang aktif** (keputusan Product Owner),
     karena rumus lama menjatuhkan Owner Bisnis ke Standar — paket terendah
     untuk pelanggan termahal.
   - **Hitungan video packing/return berbeda antara HP dan web.** BUKAN cacat.
     HP menghitung sejak `token_wallets.period_start` dan layarnya menulis
     *"sejak 31 Agu"*; web menghitung rentang hari yang dipilih. Keduanya
     mengecualikan `status='deleted'`. Jangan "memperbaikinya" menjadi sama —
     keduanya menjawab pertanyaan yang berbeda, dan keduanya menyebutkan
     periodenya sendiri.

   ⚠️ Yang masih belum diuji di HP: perekaman ujung ke ujung sesudah perubahan
   sesi ini, dan ekspor CSV (web saja).
8. **Satu video sungguhan lewat jalur unggah latar belakang** (L.8).
9. **Perbaikan `LedgerReason`** hanya terbukti lewat 3 tes unit —
   `fetchLedger()` belum punya pemanggil, jadi tidak ada yang dapat dilihat.

**Belum ada:**

10. **Bucket `public-assets`** tidak pernah dibuat, jadi unggah gambar iklan
    (Bab 11.5) masih lewat Dashboard Supabase.
11. **Menu Tutorial** — tugas (b) di atas.
12. **Riwayat pembayaran** — tugas (b) di atas.

**Kebersihan git:**

13. Cabang `worktree-31-agustus` **belum di-push dan belum digabung ke
    `master`**. Sembilan commit. Product Owner memutuskan penggabungannya
    menyusul.

## 🔴 Utang yang belum lunas

### 1. 🔴 Midtrans belum pernah diuji di PRODUKSI

Kelima skenario Bab 12.3 aturan 6 sudah lulus, tetapi **seluruhnya di
Sandbox**. Yang belum pernah terjadi sekali pun: satu rupiah sungguhan berpindah
lewat jalur ini.

Untuk menyalakannya, `MIDTRANS_SERVER_KEY` dan `MIDTRANS_IS_PRODUCTION` harus
diganti **bersamaan** (P.7). Saya menundanya sampai database produksi final.

⚠️ Sesudah dinyalakan, transaksi pertama sebaiknya nominal kecil dan diperiksa
sampai ke `token_ledger` — bukan hanya sampai layar bilang berhasil.

### 2. Dua kegagalan Midtrans yang pesannya sama

`MIDTRANS_UNREACHABLE` (jaringan) dan `MIDTRANS_REJECTED` (Midtrans menolak,
biasanya kunci salah) dipetakan ke **satu kalimat yang sama** di
`subscription_repository.dart`, dan `create-payment` tidak menuliskan penolakan
Midtrans ke `console.error`.

Akibatnya, saat tiga pembayaran gagal berturut-turut pada 31 Agustus 2026,
tidak ada satu pun petunjuk di layar maupun di catatan fungsi. Sebabnya baru
ketahuan setelah kuncinya diuji langsung ke Midtrans. ± 30 menit untuk
memperbaiki keduanya.

### 3. Unggah gambar iklan (Bab 11.5) — butuh migrasi baru

Bucket `public-assets` **tidak pernah dibuat**; yang ada hanya `avatars`
(migrasi 23) dan `payment-proofs` (migrasi 25). Sisa Bab 11.5 (kontak) sudah
selesai. Gambar landing page dan gambar halaman pembayaran karena itu masih
diatur lewat Supabase Dashboard.

### 4. Bab 9.9 Tutorial — ✅ TIDAK DITUNDA LAGI, kini tugas sesi berikutnya

🔴 **Bagian di bawah ini sudah kedaluwarsa.** Product Owner menjadwalkannya
pada 3 September 2026 sebagai tugas (b) — lihat bagian **TUGAS SESI
BERIKUTNYA** di atas. Bentuknya juga ditetapkan lebih sederhana daripada yang
tertulis di bawah: Admin memasukkan tautan YouTube, pengguna mengetuk dan
videonya terbuka.

Teks aslinya disimpan supaya alasan penundaannya dulu tetap terbaca:

Halaman daftar bernomor dari tabel `tutorials`, membuka YouTube lewat
`url_launcher`. Versi webnya grid kartu (Bab 10.5). CRUD-nya di panel Admin
juga belum dibuat, dan sengaja.

⚠️ **Bukan prioritas, dan bukan karena terlupa.** Isinya bergantung pada video
tutorial yang belum dibuat; halaman yang jadi lebih dulu hanya akan menampilkan
daftar kosong. Product Owner memutuskan 29 Agustus 2026 untuk menunggu
channel-nya siap.

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

### 7. Layar putih 30 detik saat aplikasi pertama dibuka

Diserahkan ke desainer 26 Agustus 2026, briefnya sudah diberikan. Uraiannya di
**O.15**. Jangan memperkecil `main.dart.js` diam-diam sambil menunggu — itu
pekerjaan lain yang belum diputuskan.

### 8. Versi tabel untuk Toko, Packer, dan Pembayaran — DIBATALKAN

Bab 10.5 memintanya, tetapi saya memutuskan 29 Agustus 2026 bahwa bentuk
sekarang (tampilan HP di dalam rangka web) sudah cukup. **Jangan
mengerjakannya** tanpa saya minta ulang.

## ✅ Yang sudah lunas 29 Agustus 2026 — jangan dikerjakan ulang

- **Dua halaman Admin yang kosong** → Bab 11 selesai seluruhnya, tujuh halaman
  (P.5). Jangan membangun "Daftar Pelanggan"; menu itu karangan sesi lama, dan
  Bab 11.2 hanya menyebut satu halaman.
- **Tombol Setujui/Tolak belum pernah diuji** → sudah terbukti pada baris
  sungguhan (P.4).
- **Alur perpanjangan langganan belum pernah diuji** → sudah terbukti, dan
  Admin kini punya tombol **Perpanjang periode** dengan pilihan 1/3/6/12 bulan
  atau tanggal sendiri.
- **Ubah Paket tidak menyesuaikan token** → lunas 30 Agustus 2026, migrasi 35.
  Kuota bulanan ikut berubah, saldonya diisi penuh, dan tercatat di buku besar.
- **Pemakaian promo tidak pernah dihitung** → lunas, migrasi 34.

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
