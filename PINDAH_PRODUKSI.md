# Pindah ke produksi — Midtrans, database, dan pemicu R2

Ditulis 4 September 2026 untuk dikerjakan Product Owner sendiri.

Isinya **tiga pekerjaan yang saling terikat**, dan urutannya bukan selera.
Membalik urutannya menimbulkan kerusakan yang tidak selalu terlihat saat itu
juga.

---

## Kenapa urutannya begini

```
  1. DATABASE PRODUKSI  ──┐
                          ├──> 2. PEMICU R2 (pg_net)
                          └──> 3. MIDTRANS PRODUKSI
```

**Database dulu.** Menyalakan uang sungguhan lebih dahulu berarti transaksi
pertama Anda lahir di database yang akan diganti — dan memindahkannya nanti
berarti memindahkan bukti pembayaran orang.

**Pemicu R2 dan Midtrans boleh menyusul dalam urutan apa pun**, tetapi keduanya
menunggu database final. Pemicu R2 karena ia menulis cron ke database; Midtrans
karena ia melahirkan baris `subscriptions` sungguhan.

⚠️ **Jangan kerjakan ketiganya dalam satu hari yang sama dengan pelanggan
aktif.** Setiap langkah punya jendela di mana layanan tidak utuh.

---

# 1. Database produksi

## 1.1 Yang perlu Anda siapkan lebih dulu

- Project Supabase baru (sudah Anda buat)
- `dataapp.md` terbuka — kredensial project lama **dan** baru
- Waktu tenang ± 2 jam, di luar jam sibuk packer

## 1.2 Urutan menjalankan migrasi

🔴 **Urutannya WAJIB 00 → 46, satu per satu, tidak boleh dilompati.**

⚠️ **Migrasi 47 sengaja TIDAK ikut di sini.** Ia menuntut dua ekstensi dan
dua rahasia Vault yang belum ada pada tahap ini; menjalankannya sekarang
hanya menghasilkan galat. Tempatnya di bagian 2.4.
Migrasi bernomor besar mengubah apa yang dibuat migrasi bernomor kecil;
menjalankannya terbalik menghasilkan galat yang menyesatkan.

**Sebelum migrasi 16**, aktifkan `pg_cron` lewat
**Dashboard → Database → Extensions**. Ia tidak selalu dapat dibuat lewat SQL
Editor, dan `00_extensions.sql` sengaja dibiarkan gagal cepat kalau belum
aktif.

### Dua migrasi yang punya jebakan sendiri

**Migrasi 39 dan 40 WAJIB dijalankan terpisah.** Jangan menempelkan keduanya
dalam satu kotak SQL Editor.

PostgreSQL menolak memakai nilai enum baru di transaksi yang sama dengan
penambahannya. Digabung, galatnya berbunyi:

```
unsafe use of new value of enum type
```

Kalimat itu menyesatkan — masalahnya bukan nilai itu, melainkan bahwa keduanya
berada dalam satu transaksi.

**Migrasi 46 tidak boleh memuat `comment on table storage.objects`.** Tabel itu
milik peran internal Supabase. Kalau Anda melihat:

```
ERROR: 42501: must be owner of table objects
```

berarti berkasnya versi lama. Berkas di repositori ini sudah benar.

⚠️ **SQL Editor menjalankan seluruh isi kotak sebagai SATU transaksi.** Satu
baris yang ditolak membatalkan semuanya — bukan setengah jadi. Itu sebabnya
migrasi yang gagal cukup dijalankan ulang apa adanya setelah diperbaiki.

## 1.3 Sesudah seluruh migrasi jalan

Periksa keempat hal ini sebelum melanjutkan. **Jangan percaya "tidak ada galat"
sebagai bukti** — beberapa kegagalan di proyek ini tidak pernah memunculkan
galat sama sekali.

### a. Auth Hook

🔴 **Ini yang paling sering terlupa, dan akibatnya paling membingungkan.**

Tanpa Auth Hook aktif, **setiap tabel mengembalikan nol baris** tanpa satu pun
pesan. Aplikasi terlihat berjalan, login berhasil, dan semua layar kosong.

**Dashboard → Authentication → Hooks → Custom Access Token** → arahkan ke
fungsi dari `12_auth_hook.sql`.

Buktinya: masuk sebagai Owner, dan Beranda menampilkan angka. Kalau kosong,
hook-nya belum aktif — bukan datanya yang hilang.

### b. Redirect URL

**Dashboard → Authentication → URL Configuration.**

⚠️ Redirect yang tidak cocok **tidak menimbulkan error**. Supabase diam-diam
memakai Site URL, dan tautan verifikasi email mendarat di tempat yang salah.
Sudah memakan waktu **tiga kali** (13, 25, dan 26 Agustus 2026).

Isi Site URL dan seluruh Redirect URL persis seperti project lama.

### c. Bucket Storage

Ketiganya harus ada:

| Bucket | Publik | Dibuat migrasi |
|---|---|---|
| `avatars` | ya | 23 |
| `payment-proofs` | **tidak** | 25 |
| `public-assets` | ya | 46 |

Periksa **Dashboard → Storage**. `payment-proofs` yang tidak sengaja publik
berarti bukti transfer pelanggan dapat dibuka siapa pun yang menebak
alamatnya.

### d. Cron

**Dashboard → Database → Cron Jobs.** Yang harus ada:

| Job | Jadwal | Dari migrasi |
|---|---|---|
| `expire-tenants` | 01:30 | 16 |
| `expire-tenant-tokens` | 01:45 | 40 |
| `expire-videos` | 01:15 | 41 |
| `purge-deleted-accounts` | 02:00 | 37 |

Yang **TIDAK boleh ada**: `reset-monthly-tokens` (dicabut migrasi 40) dan
`mark-expired-videos` (dicabut migrasi 41). Kalau keduanya muncul, ada migrasi
yang terlewat.

## 1.4 Data lama: TIDAK dipindahkan

✅ **Keputusan Product Owner 4 September 2026: mulai bersih.**

Ditanya dan dijawab langsung — seluruh isi database lama adalah akun, toko, dan
video **pengujian Product Owner sendiri**. Tidak ada satu pun pelanggan yang
datanya hilang kalau ditinggalkan.

Itu cocok dengan keadaan yang tercatat: Midtrans masih Sandbox, dan **belum
satu rupiah sungguhan pun pernah berpindah**. Saldo 135.092 token itu hasil
tujuh pembelian sandbox di akun Product Owner sendiri.

🔴 **Karena itu jangan dipindahkan.** Memindahkan data antar-project Supabase
menuntut `pg_dump` dan `psql` — keduanya tidak ada di komputer ini, jadi
PostgreSQL harus dipasang lebih dulu — dan bagian tersulitnya bukan tabel
`public`, melainkan skema `auth`: kata sandi, sesi, dan identitas Google hidup
di sana. Salah sedikit, akunnya ada tetapi tidak seorang pun dapat masuk.

Menanggung risiko itu demi data pengujian sendiri adalah pertukaran yang salah.

### Yang perlu dibuat ulang, berurutan

**1. Akun Owner.** Daftar biasa lewat `kamelscan.com/app/register` memakai
project baru. Akun ini otomatis mendapat tenant, masa uji coba, dan 100 token
(Bab 7.5).

**2. Akun Admin.** Daftar dulu seperti biasa, lalu naikkan perannya lewat
**SQL Editor**:

```sql
select public.promote_to_admin('email-admin@contoh.com');
```

⚠️ **Sesudah dinaikkan, akun itu WAJIB keluar lalu masuk lagi.** Peran dibawa
di dalam JWT (jebakan nomor 8); tanpa keluar-masuk, panel Admin tetap menolak
dan tidak ada satu pun galat yang menjelaskan kenapa.

**3. Toko.** Buat ulang lewat aplikasi, **Toko → Tambah Toko**.

⚠️ Nama toko yang dipakai watermark diambil dari baris ini. Kalau Anda ingin
video baru terbaca sama dengan video lama, tulis nama dan marketplace-nya
persis sama.

**4. Gambar iklan.** **Admin → Gambar iklan** — spanduk landing page dan
gambar tiap paket. Bucket-nya dibuat migrasi 46, jadi sudah siap.

**5. Tutorial.** **Admin → Tutorial** — tautan YouTube tiap langkah.

**6. Harga TIDAK perlu diisi.** Migrasi 39 sudah menanam ketiga paket beserta
angkanya:

```
standar  Rp   149.000   30 detik    2.000 token
pro      Rp   299.000   60 detik    5.000 token
bisnis   Rp 1.490.000    3 menit   30.000 token
```

Buka **Admin → Harga & Paket** hanya untuk memastikan ketiganya tergambar. Tiga
kartu, bukan dua — kalau hanya dua yang muncul, migrasi 39 belum jalan.

**7. Kontak dan metode pembayaran.** **Admin → Kontak** dan
**Admin → Metode pembayaran**. Nomor rekening tidak ikut migrasi mana pun.

### 🔴 Video lama di R2 menjadi yatim

Ini konsekuensi yang paling mudah terlupa, dan ia **berbiaya**.

Berkas video hidup di Cloudflare R2, bukan di Supabase. Meninggalkan database
lama **tidak menghapus satu berkas pun** — yang hilang hanya baris yang menunjuk
ke sana. Berkasnya tetap ada, tidak dapat dibuka siapa pun lagi, dan **tetap
ditagihkan setiap bulan**.

Dua jalan:

1. **Biarkan.** Dari 50 video terukur, rata-rata 1,07 MB — beberapa puluh video
   pengujian berarti puluhan megabyte. Biayanya kecil, tetapi ia tidak akan
   pernah berkurang sendiri.
2. **Hapus dari Cloudflare Dashboard.** R2 → bucket video → hapus isinya.

⚠️ **Jangan menghapus sebelum project lama benar-benar ditinggalkan.** Selama
Anda masih mungkin kembali ke sana untuk memeriksa sesuatu, videonya masih
dibutuhkan agar Riwayat di project lama tetap dapat dibuka.

### Kalau nanti sudah ada pelanggan sungguhan

Bagian ini ditulis untuk keadaan **sekarang**. Begitu ada Owner selain Anda yang
membayar dengan uang sungguhan, "mulai bersih" berhenti menjadi pilihan — dan
pemindahan data harus dikerjakan dengan `pg_dump`, termasuk skema `auth`.

Jangan menyalin bagian ini untuk keadaan itu.

## 1.5 Mengganti kredensial di aplikasi

`env.dev.json` — ganti `SUPABASE_URL` dan `SUPABASE_ANON_KEY`.

Lalu **ketiganya wajib dibangun ulang**, karena kredensial ditanam saat build:

```powershell
.\run.ps1 -Build -Profile          # APK
.\deploy_web.ps1                   # web + landing
```

⚠️ Landing page juga ikut: sejak 4 September 2026 ia membaca spanduk dari
Supabase, dan kredensialnya disuntikkan `deploy_web.ps1` saat menerbitkan.

**Edge Function tidak membaca `env.dev.json`.** Rahasianya disimpan terpisah —
lihat bagian 3.2.

---

## 1.6 Layanan luar yang menyimpan alamat project

🔴 **Bagian ini sebelumnya tidak ada, dan itu kelalaian yang serius.**

Ref project berubah, dan setiap layanan luar yang menyimpan alamat lama akan
menunjuk ke tempat yang salah. Yang paling berbahaya: **hampir semuanya gagal
tanpa pesan** — tombolnya ada, dipencet, lalu tidak terjadi apa-apa.

### Yang berubah, dan yang TIDAK

| Layanan | Menyimpan alamat Supabase? | Yang harus dikerjakan |
|---|---|---|
| **Supabase -> Providers -> Google** | — | 🔴 **aktifkan** (mati di project baru) |
| **Google Cloud Console** | ya, **hanya** untuk login web | tambah redirect URI baru |
| **Midtrans Dashboard** | ya | ganti Payment Notification URL |
| **SMTP (Resend/Brevo)** | tidak | wajib dipasang ulang di project baru |
| **Sentry** | 🟢 **TIDAK** | **tidak ada yang perlu diubah** |
| **Cloudflare R2** | tidak | kuncinya lewat Edge Function Secrets (1.7) |
| **Cloudflare Pages** | tidak | cukup deploy ulang (1.5) |

⚠️ Baris **Sentry** sengaja ditulis. Sentry hanya menerima laporan **dari**
aplikasi; ia tidak pernah memanggil Supabase. `SENTRY_DSN` milik Sentry, bukan
milik project Supabase. Tidak perlu diapa-apakan — dan mengetahui apa yang
**tidak** perlu dikerjakan menghemat waktu sama banyaknya.

---

### a. 🔴 Login Google — kenapa gagal, dan cara memperbaikinya

**Penyebab paling mungkin: provider Google MATI di project baru.**

Setiap project Supabase baru lahir dengan seluruh provider dalam keadaan
nonaktif. Ini berlaku untuk **kedua** jalur login, HP maupun web.

**Dashboard -> Authentication -> Sign In / Providers -> Google -> Enable.**

Isi dari Google Cloud Console -> **APIs & Services -> Credentials -> OAuth 2.0
Client IDs -> klien bertipe *Web application***:

| Kolom di Supabase | Diisi dengan |
|---|---|
| Client IDs | Client ID **Web** — sama dengan `GOOGLE_WEB_CLIENT_ID` di `env.dev.json` |
| Client Secret | Client secret dari klien Web yang sama |

⚠️ **Client ID-nya sama persis dengan yang lama.** Anda tidak membuat klien
Google baru — yang baru hanyalah project Supabase-nya.

#### Kalau yang Anda coba di HP (Android)

Jalur HP tidak memakai redirect sama sekali. Aplikasi meminta *ID token* ke
Google, lalu menyerahkannya ke Supabase:

```
GoogleSignIn.authenticate()  ->  idToken  ->  signInWithIdToken()
```

🟢 **Karena itu Google Cloud Console TIDAK perlu diubah untuk jalur HP.**
SHA-1, SHA-256, dan nama paketnya tidak tersentuh oleh pindah project. Dugaan
bahwa Google Cloud perlu disinkronkan hanya benar untuk jalur **web**.

Yang menolaknya adalah Supabase, karena provider-nya mati. Sesudah di-Enable,
pastikan Client ID Web tercantum di kolom **Client IDs** — Supabase memeriksa
`aud` di dalam ID token terhadap daftar itu, dan token yang `aud`-nya tidak
terdaftar ditolak meski provider sudah aktif.

#### Kalau yang Anda coba di web

Tambahan satu langkah, di **Google Cloud Console -> Credentials -> klien Web ->
Authorized redirect URIs**:

```
https://cgzvrhwlyzettnfbiiuk.supabase.co/auth/v1/callback
```

🔴 **TAMBAHKAN, jangan mengganti.** Alamat project lama harus tetap di
daftar itu selama Anda masih mungkin kembali ke project lama. Menghapusnya
mematikan login Google di sana seketika.

Lalu di Supabase, **Authentication -> URL Configuration**:

| Kolom | Isi |
|---|---|
| Site URL | `https://kamelscan.com/app` |
| Redirect URLs | `https://kamelscan.com/app/auth/callback` |

⚠️ Redirect URL yang tidak cocok **tidak menghasilkan galat**. Supabase
diam-diam memakai Site URL. Jebakan ini sudah memakan waktu tiga kali di proyek
ini.

#### Kalau masih gagal, baca galatnya

Aplikasi menyimpan sebabnya di `debugMessage`. Di HP:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" logcat -d |
  Select-String -Pattern 'provider|oauth|idToken|400'
```

| Yang terbaca | Artinya |
|---|---|
| `Unsupported provider` / `provider is not enabled` | provider Google masih mati |
| `Invalid audience` / `bad_jwt` | Client ID Web belum tercantum di kolom Client IDs |
| `redirect_uri_mismatch` | jalur web, redirect URI belum ditambahkan di Google Cloud |
| `errorGoogleNotConfigured` | `GOOGLE_WEB_CLIENT_ID` kosong saat aplikasi dibangun |

---

### b. Email — pengirim, dan alamat kontak

#### Pengirim SMTP

Project baru kembali memakai pengirim bawaan Supabase, yang **dibatasi sekitar
3-4 email per jam** dan memang tidak diperuntukkan bagi produksi.

Akibatnya khas dan menyesatkan: pendaftaran pertama dan kedua lancar, lalu email
verifikasi berhenti datang — tanpa galat apa pun di aplikasi.

**Dashboard -> Project Settings -> Authentication -> SMTP Settings**, isi dengan
akun Resend/Brevo yang sama seperti project lama.

⚠️ Periksa juga **Authentication -> Emails -> Templates**. Kalau di project
lama templatnya pernah disunting, di project baru ia kembali ke bentuk bawaan
berbahasa Inggris.

#### 🔴 Mengirim dan menerima adalah dua hal yang berbeda

Ini membingungkan karena keduanya memakai alamat yang bentuknya sama, padahal
syaratnya sama sekali lain:

| | Yang dibutuhkan | Perlu kotak surat? |
|---|---|---|
| **Alamat pengirim** (`from:` di email verifikasi) | domain diverifikasi di Resend lewat catatan DNS | 🟢 **tidak** |
| **Alamat kontak** (dipajang ke pelanggan) | tempat yang benar-benar dapat menerima | 🔴 **wajib** |

Artinya `team@kamelscan.com` **sudah dapat dipakai mengirim hari ini juga**,
begitu domainnya terverifikasi di Resend — tanpa membuat kotak surat apa pun.

🔴 **Tetapi memasangnya sebagai kontak tanpa kotak surat berbahaya.**
Setiap balasan pelanggan akan terpantul, atau hilang diam-diam. Alamat dukungan
yang tidak menerima apa-apa lebih buruk daripada tidak mencantumkan alamat sama
sekali — pelanggan mengira sudah mengadu, padahal tidak ada yang membaca.

#### Cara termurahnya: Cloudflare Email Routing (gratis)

Domainnya sudah di Cloudflare, jadi tidak perlu layanan baru.

**Cloudflare Dashboard -> pilih `kamelscan.com` -> Email -> Email Routing.**

1. Aktifkan Email Routing. Cloudflare menawarkan menambahkan catatan MX
   otomatis — setujui.
2. **Destination addresses** -> tambah `aiotideaproject@gmail.com`, lalu buka
   Gmail itu dan **klik tautan konfirmasinya**. Tanpa langkah ini penerusannya
   diam saja.
3. **Routing rules** -> Create address: `team@kamelscan.com` -> Send to ->
   alamat Gmail tadi.

⚠️ **MX menunjuk satu tujuan.** Kalau `kamelscan.com` sudah memakai layanan
email lain, Email Routing akan menggantikannya. Kalau selama ini belum pernah
ada email di domain itu, tidak ada yang hilang.

#### Membuktikannya sebelum dipajang

🔴 **Kirim satu email dari luar ke `team@kamelscan.com` dan pastikan ia
sampai di Gmail Anda.** Jangan melewatkan langkah ini. Alamat kontak yang salah
tidak menghasilkan galat di mana pun — ia hanya menelan keluhan pelanggan.

Sesudah terbukti sampai, ganti kontaknya lewat **Admin -> Kontak**. Nilainya
tersimpan di `platform_settings` kunci `contact`, dan **tidak ada kode yang
perlu diubah**.

Isi bawaannya ditanam migrasi `08_settings.sql`:

```json
{"whatsapp": "6285113214018", "email": "aiotideaproject@gmail.com", "address": ""}
```

---

### c. Midtrans — Payment Notification URL

Selama masih Sandbox pun alamatnya sudah harus dipindah; kalau tidak, pembayaran
uji coba tidak akan pernah mengaktifkan langganan.

**Midtrans Dashboard -> Settings -> Configuration -> Payment Notification URL:**

```
https://cgzvrhwlyzettnfbiiuk.supabase.co/functions/v1/midtrans-webhook
```

🔴 Ganti di lingkungan **Sandbox** sekarang. Bagian 3.5 mengurus
lingkungan **Production**, dan keduanya punya kolom sendiri-sendiri yang tidak
saling mempengaruhi.

---

## 1.7 Deploy ulang SELURUH Edge Function

🔴 **Edge Function tidak ikut pindah.** Project baru tidak memiliki satu
pun dari kesepuluhnya — dan aplikasi memanggil sebagian besarnya sejak layar
pertama.

Bagian ini dikerjakan dari **PowerShell**, bukan dari Dashboard. Kerjakan
berurutan; tiap langkah punya cara memeriksanya sendiri.

---

### Langkah a — buka PowerShell di folder yang benar

Perintah di bawah memakai jalur **relatif**, jadi folder kerjanya menentukan.

```powershell
cd E:\kamelscan\.claude\worktrees\31-agustus
```

Pastikan CLI-nya memang ada di sana:

```powershell
Test-Path .\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe
```

Harus menjawab `True`. Kalau `False`, CLI-nya belum terpasang:

```powershell
npm install supabase --save-dev --prefix .supabase-cli
```

---

### Langkah b — 🔴 buat Access Token yang baru

**Ini yang paling sering menghentikan orang di sini, dan panduan sebelumnya
hanya menulis `sbp_...` tanpa memberi tahu dari mana asalnya.**

⚠️ Token lama Anda **sudah dicabut** (ia sempat terlihat di tangkapan layar
4 September 2026). Token yang dicabut tidak dapat dipakai lagi — jadi memang
harus membuat yang baru, bukan mencari yang lama.

1. Buka **https://supabase.com/dashboard/account/tokens**
2. **Generate new token**, beri nama bebas — misalnya `cli-laptop`
3. Salin nilainya **sekarang juga**. Ia diawali `sbp_` dan **hanya
   ditampilkan satu kali**; menutup halaman berarti membuat token lagi.

```powershell
$env:SUPABASE_ACCESS_TOKEN = 'sbp_GANTI_DENGAN_TOKEN_ANDA'
```

⚠️ Baris ini hanya berlaku **selama jendela PowerShell itu terbuka**. Menutup
jendelanya berarti mengulanginya. Itu memang disengaja — token ini tidak
seharusnya menetap di komputer.

Sekalian siapkan dua pemboleh-ubah lain:

```powershell
$cli = '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
$ref = 'cgzvrhwlyzettnfbiiuk'
```

Buktikan tokennya diterima **sebelum** melangkah:

```powershell
& $cli projects list
```

Project baru Anda harus muncul di daftarnya. Kalau jawabannya galat
`Unauthorized` atau `invalid access token`, tokennya salah salin — ulangi
langkah b.

---

### Langkah c — deploy sembilan fungsi

```powershell
foreach ($f in 'create-packer','create-payment','create-public-link',
               'delete-packer','get-public-video','get-upload-url',
               'get-video-url','purge-storage','resolve-username') {
  & $cli functions deploy $f --project-ref $ref
}
```

Tiap fungsi memakan belasan detik. Yang benar berakhir dengan
`Deployed Function <nama>`.

---

### Langkah d — deploy `midtrans-webhook` TERPISAH

```powershell
& $cli functions deploy midtrans-webhook --no-verify-jwt --project-ref $ref
```

🔴 **`--no-verify-jwt` TIDAK BOLEH TERLUPA, dan karena itu ia ditulis di
baris sendiri — bukan ikut ke dalam daftar di langkah c.**

Midtrans memanggilnya tanpa JWT; penjagaannya tanda tangan, bukan gerbang.
Men-deploy tanpa flag itu mematikannya **secara diam-diam**: uang berpindah di
Midtrans, dan langganan pelanggan tidak pernah aktif. Tidak ada galat di mana
pun.

Periksa kesepuluhnya berdiri:

```powershell
& $cli functions list --project-ref $ref
```

---

### Langkah e — 🔴 tujuh rahasia, bukan lima

⚠️ **Panduan versi pertama hanya menyebut lima.** Dua yang hilang tidak
menghasilkan galat apa pun saat di-deploy — akibatnya baru terasa jauh
kemudian, di tempat yang tidak terhubung dengan langkah ini.

| Rahasia | Dibaca fungsi | Nilainya dari | Kalau kosong |
|---|---|---|---|
| `R2_ENDPOINT` | 4 fungsi video | `dataapp.md`, bagian **S3 API** | unggah & pemutaran video mati |
| `R2_ACCESS_KEY_ID` | 4 fungsi video | `dataapp.md` | sama |
| `R2_SECRET_ACCESS_KEY` | 4 fungsi video | `dataapp.md`, **secret access key** | sama |
| `R2_BUCKET_VIDEOS` | 4 fungsi video | nama bucket R2 Anda | memakai `kamelscan-videos` |
| `MIDTRANS_SERVER_KEY` | `create-payment`, `midtrans-webhook` | `dataapp.md`, **Server Key** | pembayaran mati |
| 🔴 `MIDTRANS_IS_PRODUCTION` | `create-payment` | `false` selama masih Sandbox | dianggap `false` |
| 🔴 `PUBLIC_BASE_URL` | `create-public-link` | `https://kamelscan.com` | memakai `https://kamelscan.com` |

Dua baris terakhir itulah yang hilang.

🔴 **`MIDTRANS_IS_PRODUCTION` sengaja tidak ditebak dari awalan kunci.**
Menebak berarti satu kunci yang salah tempel diam-diam mengarahkan **uang
sungguhan** ke sandbox, atau sebaliknya. Selama masih Sandbox, isinya `false`.

```powershell
& $cli secrets set `
    R2_ENDPOINT='https://GANTI.r2.cloudflarestorage.com' `
    R2_ACCESS_KEY_ID='GANTI' `
    R2_SECRET_ACCESS_KEY='GANTI' `
    R2_BUCKET_VIDEOS='kamelscan-videos' `
    MIDTRANS_SERVER_KEY='SB-Mid-server-GANTI' `
    MIDTRANS_IS_PRODUCTION='false' `
    PUBLIC_BASE_URL='https://kamelscan.com' `
    --project-ref $ref
```

⚠️ Tanda **`` ` ``** di ujung baris adalah penyambung baris PowerShell. Ia
harus benar-benar di ujung, tanpa spasi sesudahnya — kalau tidak, perintahnya
terpotong dan sebagian rahasia tidak pernah terkirim.

Periksa:

```powershell
& $cli secrets list --project-ref $ref
```

Harus terlihat **tujuh** nama itu. CLI hanya menampilkan nama dan sidik
nilainya, tidak isinya.

⚠️ `SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY` ikut
muncul di daftar itu. Ketiganya **terisi sendiri** — jangan diset manual.

---

### Langkah f — membuktikannya lewat aplikasi

🔴 `functions list` hanya membuktikan fungsinya **ada**, bukan bahwa ia
**bekerja**. Rahasia yang salah tidak terlihat sama sekali dari daftar itu.

| Yang diuji | Caranya | Kalau gagal |
|---|---|---|
| `resolve-username` | login memakai username, bukan email | fungsinya belum ter-deploy |
| `create-payment` | buka halaman Pembayaran, pilih satu paket | `MIDTRANS_SERVER_KEY` salah/kosong |
| `get-upload-url` | rekam satu video, tunggu terunggah | rahasia R2 salah/kosong |
| `get-video-url` | buka video itu dari Riwayat | rahasia R2 salah/kosong |
| `create-public-link` | Bagikan dari Riwayat, buka tautannya | `PUBLIC_BASE_URL` salah |

Kalau ada yang gagal, galat sesungguhnya ada di log fungsinya:

```powershell
& $cli functions logs get-upload-url --project-ref $ref
```

# 2. Pemicu antrean R2 (`pg_net`)

## 2.1 Keadaan sekarang, dan kenapa ini mendesak

`purge-storage` **sudah terbit** (versi 1) dan berfungsi. Yang tidak ada:
**siapa pun yang memanggilnya.**

Akibatnya berjalan diam-diam sekarang juga:

- Akun yang dihapus mengisi `storage_purge_queue`
- Berkas videonya **tetap utuh di Cloudflare R2**
- Dan **tetap ditagihkan setiap bulan**

Product Owner sengaja menundanya sampai database final supaya tidak dipasang
dua kali. Itu keputusan yang benar — tetapi ia berhenti dapat diterima begitu
database itu final.

## 2.2 Tiga ekstensi — periksa dulu, jangan langsung mencari

🔴 **Jangan mulai dari daftar Extensions.** Panduan versi pertama
menyuruh begitu, dan itu keliru: **`supabase_vault` sudah terpasang sendiri di
setiap project Supabase baru**, sehingga ia sering tidak muncul di daftar yang
dapat dinyalakan. Mencarinya di sana berakhir dengan mengira ada yang salah,
padahal justru sudah beres.

Mulailah dengan bertanya kepada databasenya. **SQL Editor:**

```sql
select extname, extversion
  from pg_extension
 where extname in ('pg_net', 'supabase_vault', 'pg_cron')
 order by extname;
```

| Yang kembali | Artinya |
|---|---|
| **tiga baris** | ✅ selesai, lanjut ke 2.3 |
| dua baris | satu kurang — lihat tabel di bawah |
| kurang dari itu | nyalakan yang belum ada |

---

### Kalau `supabase_vault` yang tidak muncul

Sebelum menyalakan apa pun, periksa apakah ia sebenarnya sudah bekerja.
Ekstensi ini hidup di schema `vault`, bukan `public`:

```sql
select count(*) from vault.secrets;
```

🟢 Menjawab angka — termasuk `0` — berarti **Vault sudah siap**.
Abaikan daftar Extensions, dan lanjut ke 2.3.

🔴 Menjawab `relation "vault.secrets" does not exist` berarti ia memang
belum ada. Baru di situ:

```sql
create extension if not exists supabase_vault with schema vault;
```

---

### Kalau `pg_net` atau `pg_cron` yang tidak muncul

Keduanya **tidak** terpasang sendiri, dan keduanya memang ada di daftar
Extensions.

**Dashboard → Database → Extensions**, ketik namanya di kotak pencarian, lalu
nyalakan.

⚠️ Daftar itu memuat ratusan ekstensi dan **halaman pertamanya bukan yang
tersedia semua** — gunakan kotak pencarian, jangan menggulir.

⚠️ Keduanya tidak selalu dapat dibuat lewat SQL Editor. Kalau
`create extension` menjawab galat izin, nyalakan lewat Dashboard — itu jalur
yang benar, bukan jalan pintas.

---

### Bukti yang sesungguhnya

🔴 Ekstensi yang terdaftar belum tentu **dapat dipakai**. Yang
membuktikannya adalah memanggil fungsi yang nanti benar-benar Anda butuhkan:

```sql
select vault.create_secret('uji-boleh-dihapus', 'uji_pindah_produksi');
select name from vault.secrets where name = 'uji_pindah_produksi';
```

Baris kedua harus mengembalikan `uji_pindah_produksi`. Bersihkan setelahnya:

```sql
delete from vault.secrets where name = 'uji_pindah_produksi';
```

Dan untuk `pg_net`:

```sql
select net.http_get('https://example.com') is not null;
```

Menjawab `true` berarti `pg_net` benar-benar dapat dipanggil, bukan sekadar
tercatat.

## 2.3 Menyimpan dua rahasia ke Vault

🔴 **Ini bagian yang Anda tanyakan, dan ini langkah lengkapnya.**

### Kenapa Vault, bukan ditulis di berkas migrasi

Berkas migrasi masuk git. **Service role key adalah kunci yang melewati seluruh
RLS** — siapa pun yang memegangnya dapat membaca dan menghapus data setiap
pelanggan. Ia tidak boleh berada di repositori dengan alasan apa pun.

Vault menyimpannya terenkripsi di dalam database, dan hanya fungsi
`security definer` yang boleh membacanya kembali.

### Langkah a — ambil service role key

**Dashboard → Project Settings → API Keys**.

Ada dua kunci di sana. Yang Anda butuhkan yang **bawah**:

| Kunci | Dipakai untuk | Boleh dilihat publik? |
|---|---|---|
| `anon` / `publishable` | aplikasi & landing page | ya |
| **`service_role` / `secret`** | **yang ini** | 🔴 **TIDAK PERNAH** |

Klik **Reveal**, lalu salin. Ia panjang dan diawali `eyJ`.

⚠️ **Jangan menempelkannya ke mana pun selain SQL Editor.** Bukan ke chat,
bukan ke catatan, bukan ke tangkapan layar. Kalau terlanjur, cabut dan buat
ulang di halaman yang sama.

### Langkah b — ambil alamat Edge Function

Bentuknya:

```
https://cgzvrhwlyzettnfbiiuk.supabase.co/functions/v1/purge-storage
```

⚠️ `cgzvrhwlyzettnfbiiuk` adalah Project Reference ID project **baru** Anda —
bukan `ofggpithmvgnhsshglwx` yang lama. Cocokkan dengan yang tertera di
**Project Settings → General**; kalau berbeda, pakai yang di sana.

### Langkah c — simpan keduanya

**SQL Editor → New query.** Jalankan **satu per satu**, ganti bagian bertanda:

```sql
select vault.create_secret(
  'eyJhbGciOi...GANTI_DENGAN_SERVICE_ROLE_KEY...',
  'service_role_key',
  'Dipakai cron drain-purge-queue memanggil Edge Function purge-storage'
);
```

```sql
select vault.create_secret(
  'https://GANTI_DENGAN_REF.supabase.co/functions/v1/purge-storage',
  'purge_storage_url',
  'Alamat Edge Function penguras antrean R2'
);
```

Masing-masing mengembalikan satu **UUID**. Itu tandanya berhasil.

### Langkah d — pastikan keduanya tersimpan

```sql
select name, created_at from vault.secrets order by created_at desc;
```

Harus muncul **dua baris**: `service_role_key` dan `purge_storage_url`.

⚠️ Perhatikan bahwa kueri ini **tidak menampilkan isinya** — itu memang
disengaja. Kalau Anda benar-benar perlu memastikan isinya benar, ada cara
memeriksa **tanpa menampilkannya**:

```sql
select name, length(decrypted_secret) as panjang,
       left(decrypted_secret, 6) as awalan
  from vault.decrypted_secrets
 where name in ('service_role_key', 'purge_storage_url');
```

`service_role_key` harus berawalan `eyJhbG` dan panjangnya beberapa ratus
huruf. `purge_storage_url` harus berawalan `https:`.

### Kalau salah menyimpan

Rahasia di Vault **tidak ditimpa** oleh `create_secret` yang kedua — ia
membuat baris baru bernama sama, dan fungsi pembacanya akan bingung. Perbaiki
dengan mengubah, bukan menambah:

```sql
select vault.update_secret(
  (select id from vault.secrets where name = 'service_role_key'),
  'eyJhbGciOi...NILAI_YANG_BENAR...'
);
```

Atau hapus lalu buat lagi:

```sql
delete from vault.secrets where name = 'service_role_key';
```

---

## 2.4 Jalankan migrasi 47

Berkasnya sudah ada: `supabase/migrations/47_purge_queue_trigger.sql`.

Salin seluruh isinya ke SQL Editor dan jalankan. **Tidak ada yang perlu Anda
sunting** — alamat dan kuncinya dibaca dari Vault, jadi berkasnya sama persis
di project lama maupun baru.

**Yang seharusnya muncul:** `Success. No rows returned`.

Kalau muncul galat menyebut `vault` atau `net`, berarti ekstensinya belum aktif
— kembali ke 2.2.

---

## 2.5 Membuktikannya bekerja

🔴 **Jangan berhenti di "cron-nya sudah ada".** `pg_net` bekerja asinkron:
fungsinya hanya menitipkan permintaan lalu selesai, jadi ia **selalu terlihat
berhasil** bahkan ketika panggilannya ditolak 403.

**1. Hitung antreannya sekarang:**

```sql
select count(*) from public.storage_purge_queue;
```

**2. Jalankan sekali dengan tangan**, tanpa menunggu jam berikutnya:

```sql
select public.drain_purge_queue();
```

**3. Tunggu ± 10 detik, lalu lihat JAWABAN Edge Function.** Ini langkah yang
paling sering dilewati, dan satu-satunya yang benar-benar membuktikan:

```sql
select id, status_code, content, created
  from net._http_response
 order by created desc limit 3;
```

| `status_code` | Artinya | Yang harus diperbaiki |
|---|---|---|
| **200** | ✅ berhasil | — |
| 403 | `FORBIDDEN` | `service_role_key` di Vault salah |
| 401 | ditolak gerbang | kunci bukan JWT yang sah — salah salin |
| 404 | fungsinya tidak ditemukan | `purge_storage_url` salah, atau `purge-storage` belum di-deploy ke project ini |
| `NULL` | belum ada jawaban | tunggu sebentar lagi, lalu ulangi kueri |

**4. Hitung ulang. Angkanya harus TURUN:**

```sql
select count(*) from public.storage_purge_queue;
```

⚠️ Kalau antreannya memang **sudah kosong sejak awal**, langkah 4 tidak
membuktikan apa pun. Yang membuktikan tetap `status_code = 200` di langkah 3.

**5. Pastikan jadwalnya terpasang:**

```sql
select jobname, schedule, active from cron.job
 where jobname = 'drain-purge-queue';
```

Harus satu baris, `schedule` `0 * * * *`, `active` `t`.

---

## 2.6 Dua tempat rahasia yang berbeda

`purge-storage` sendiri sudah di-deploy di **1.7** bersama sembilan fungsi
lainnya, beserta rahasia R2-nya. Kalau bagian itu dilewati, kembali ke sana
lebih dulu — `drain_purge_queue()` akan menjawab **404** tanpa fungsinya.

⚠️ **Yang sering tertukar, dan tidak menghasilkan galat apa pun:**

| Tempat | Isinya | Dibaca oleh |
|---|---|---|
| **Vault** (di dalam database) | `service_role_key`, `purge_storage_url` | fungsi SQL `drain_purge_queue()` |
| **Edge Function Secrets** | kunci R2, `MIDTRANS_SERVER_KEY` | kode Deno di dalam fungsinya |

Menaruh kunci R2 di Vault tidak akan ditolak siapa pun — fungsinya hanya tidak
pernah menemukannya, lalu gagal dengan sebab yang terlihat seperti hal lain.

# 3. Midtrans produksi

## 3.1 Aturan yang tidak boleh dilanggar

🔴 **`MIDTRANS_SERVER_KEY` dan `MIDTRANS_IS_PRODUCTION` wajib diganti
BERSAMAAN.** Mengganti salah satu saja membuat **setiap** pembayaran gagal.

⚠️ **Awalan kunci di akun Anda SAMA untuk sandbox dan produksi**
(`Mid-server-`) — tidak ada `SB-`. Jangan menebak dari awalannya.

Cara membedakannya yang benar: buka Midtrans Dashboard, dan lihat **sakelar
Sandbox/Production di pojok kiri atas**. Kunci yang ditampilkan mengikuti
sakelar itu. `dataapp.md` baris 106–109 Sandbox, baris 111–114 Produksi.

## 3.2 Mengganti rahasianya

Rahasia Edge Function **tidak** ada di `env.dev.json`.

**Dashboard → Edge Functions → Secrets**, atau lewat CLI:

```powershell
$env:SUPABASE_ACCESS_TOKEN = 'sbp_GANTI_DENGAN_TOKEN_ANDA'
$cli = '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
$ref = 'cgzvrhwlyzettnfbiiuk'

& $cli secrets set MIDTRANS_SERVER_KEY='Mid-server-GANTI' --project-ref $ref
& $cli secrets set MIDTRANS_IS_PRODUCTION='true' --project-ref $ref
```

⚠️ Tulis tiap baris **terpisah**. Menyatukannya dengan `;` di satu baris
panjang sudah gagal sekali 3 September 2026 — barisnya terpotong saat ditempel
dan PowerShell menjawab *"Missing expression after '&'"*, galat yang tidak
menyebut sebab sebenarnya.

`MIDTRANS_CLIENT_KEY` di `env.dev.json` juga ikut diganti, lalu APK dan web
dibangun ulang.

## 3.3 Deploy ulang Edge Function

⚠️ **Lanjutkan dari jendela PowerShell yang sama seperti 3.2** — `$cli`
dan `$ref` masih terisi di sana. Kalau jendelanya sudah ditutup,
ulangi tiga baris pertama blok 3.2.

```powershell
& $cli functions deploy create-payment --project-ref $ref
& $cli functions deploy midtrans-webhook --no-verify-jwt --project-ref $ref
```

🔴 **`--no-verify-jwt` pada `midtrans-webhook` TIDAK BOLEH TERLUPA.**

Midtrans memanggilnya tanpa JWT; penjagaannya tanda tangan, bukan gerbang.
Men-deploy tanpa flag itu **mematikan webhook secara diam-diam** — pembayaran
berhasil di Midtrans, uang berpindah, dan langganan pelanggan tidak pernah
aktif. Tidak ada galat di mana pun.

## 3.4 Memeriksa `verify_jwt`

⚠️ **Cara lama sudah tidak berlaku.** `supabase functions list` pada CLI
2.116.0 tidak lagi punya kolom `verify_jwt`.

Cara yang benar — panggil fungsinya **tanpa** header Authorization:

```bash
U=https://cgzvrhwlyzettnfbiiuk.supabase.co/functions/v1
curl -s -o /dev/null -w "%{http_code}\n" -X POST $U/create-payment \
     -H "Content-Type: application/json" -d '{}'
```

| Jawaban | Artinya |
|---|---|
| `401 UNAUTHORIZED_NO_AUTH_HEADER` | ditolak **gerbang** → `verify_jwt` **true** |
| apa pun yang lain | **kodenya sendiri** yang menjawab → `verify_jwt` **false** |

Yang benar: `midtrans-webhook` **false**, semua yang lain **true**.

✅ Cara ini lebih kuat daripada membaca kolom: ia membuktikan **perilaku
sungguhan**, bukan label pengaturan.

## 3.5 Webhook di Midtrans Dashboard

**Settings → Configuration → Payment Notification URL:**

```
https://cgzvrhwlyzettnfbiiuk.supabase.co/functions/v1/midtrans-webhook
```

Alamat ini berbeda antara sandbox dan produksi — pastikan Anda mengisinya pada
sakelar **Production**.

## 3.6 Transaksi pertama

🔴 **Nominal kecil, dan diperiksa sampai ke buku besar** — bukan hanya sampai
layar bilang berhasil.

1. Beli paket **Standar** dengan akun sungguhan
2. Bayar sungguhan
3. Periksa berurutan:

```sql
-- a. Baris pembayaran jadi 'paid'?
select id, plan, status, amount, paid_at
  from public.subscriptions order by created_at desc limit 1;

-- b. Tenant naik tier dan aktif?
select tier_plan, status, period_end from public.tenants where id = '<TENANT>';

-- c. Tokennya benar-benar masuk?
select delta, reason, balance_after, note
  from public.token_ledger where tenant_id = '<TENANT>'
 order by created_at desc limit 3;
```

Kalau (a) `paid` tetapi (b) masih lama, **webhook-nya tidak sampai** — hampir
selalu `--no-verify-jwt` yang terlupa, atau alamat notifikasi salah.

Kalau ketiganya benar, buka **Riwayat pembayaran** di aplikasi. Barisnya harus
muncul dengan jumlah token yang sama dengan (c).

## 3.7 Kalau gagal

Sejak 3 September 2026 kedua kegagalan Midtrans punya kalimat sendiri:

| Yang Anda lihat | Artinya | Tindakan |
|---|---|---|
| *"Layanan pembayaran sedang tidak dapat dihubungi"* | jaringan | coba lagi |
| *"Pembayaran otomatis sedang bermasalah di sisi kami"* | **Midtrans menolak** | kunci salah atau akun belum aktif — mengulang tidak akan menolong |

Dan sebabnya kini tertulis di **Edge Functions → create-payment → Logs**,
lengkap dengan `http_status`, `error_messages`, dan awalan kunci yang dipakai.
Kunci penuhnya sengaja tidak ikut tercetak.

---

# Daftar periksa terakhir

Sebelum menyatakan produksi siap:

- [ ] Migrasi 00–46 jalan berurutan, tanpa lubang
- [ ] Provider **Google aktif**, Client ID Web tercantum — daftar akun lewat Google berhasil
- [ ] SMTP kustom terpasang — bukan pengirim bawaan yang dibatasi 3–4 email/jam
- [ ] Alamat kontak **terbukti menerima** — satu email uji sampai ke kotak masuk
- [ ] Kesepuluh Edge Function ter-deploy; `midtrans-webhook` dengan `--no-verify-jwt`
- [ ] **Tujuh** rahasia Edge Function terisi — termasuk `MIDTRANS_IS_PRODUCTION` dan `PUBLIC_BASE_URL`
- [ ] Payment Notification URL Midtrans **Sandbox** menunjuk ref baru
- [ ] Auth Hook aktif — Beranda menampilkan angka, bukan kosong
- [ ] Redirect URL diisi lengkap
- [ ] Tiga bucket ada, `payment-proofs` **tidak** publik
- [ ] Empat cron ada; `reset-monthly-tokens` dan `mark-expired-videos` **tidak**
- [ ] `pg_net`, `pg_cron`, dan `supabase_vault` terbukti DAPAT DIPANGGIL — bukan sekadar terdaftar
- [ ] Dua rahasia ada di Vault: `service_role_key`, `purge_storage_url`
- [ ] Migrasi 47 jalan, dan `net._http_response` menjawab **200**
- [ ] Antrean R2 terbukti **turun** setelah dikuras
- [ ] `verify_jwt`: hanya `midtrans-webhook` yang `false`
- [ ] Satu transaksi sungguhan terlacak sampai `token_ledger`
- [ ] APK dan web dibangun ulang dengan kredensial baru
- [ ] Akun Owner, Admin, toko, gambar iklan, dan tutorial dibuat ulang
- [ ] Tiga kartu paket tergambar di Admin > Harga & Paket, bukan dua
- [ ] Project lama **belum** dihapus

⚠️ **Dua kegagalan paling senyap ada di daftar ini, dan keduanya tidak
menghasilkan satu pun pesan galat:**

- **Provider Google mati** — tombol "Lanjut dengan Google" ada, dipencet, lalu
  tidak terjadi apa-apa.
- **Auth Hook mati** — login berhasil, lalu setiap layar kosong. Terlihat persis
  seperti "belum ada data", padahal datanya ada.

Keduanya tidak dapat dibuktikan dengan membaca layar Dashboard. Yang
membuktikan hanya mencobanya: daftar satu akun lewat Google, lalu buka Beranda
dan pastikan angkanya muncul.
