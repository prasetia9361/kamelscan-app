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

## 2.2 Aktifkan pg_net

**Dashboard → Database → Extensions** → cari `pg_net` → aktifkan.

⚠️ Sama seperti `pg_cron`, ia tidak selalu dapat dibuat lewat SQL Editor.

## 2.3 Migrasi 47 — cron pemanggil

Belum ditulis. Bentuknya kira-kira begini, dan **jangan disalin mentah** —
angka dan nama rahasianya perlu Anda cocokkan sendiri:

```sql
-- 47_purge_trigger.sql
-- Memanggil Edge Function purge-storage tiap jam.
do $$
begin
  perform cron.schedule('drain-purge-queue', '0 * * * *', $job$
    select net.http_post(
      url     := 'https://<REF>.supabase.co/functions/v1/purge-storage',
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer ' || current_setting('app.service_role_key')
                 ),
      body    := '{}'::jsonb
    );
  $job$);
end $$;
```

🔴 **Masalah yang harus Anda pecahkan lebih dulu: dari mana service role key
datang.**

`purge-storage` memeriksa `Authorization` lawan service role key secara
*constant-time* di dalam dirinya sendiri. Kunci itu **tidak boleh dituliskan ke
dalam berkas migrasi**, karena migrasi masuk git.

Dua jalan, dan keduanya perlu Anda putuskan:

1. **`ALTER DATABASE ... SET app.service_role_key = '...'`** — dijalankan sekali
   lewat SQL Editor, tidak masuk git. Kuncinya lalu terbaca oleh siapa pun yang
   dapat menjalankan SQL di project itu.
2. **Supabase Vault** — lebih benar, lebih rumit. Kuncinya disimpan terenkripsi
   dan dibaca lewat `vault.decrypted_secrets`.

Saran saya: **Vault**, kalau Anda punya waktu. Kalau tidak, cara pertama masih
jauh lebih baik daripada keadaan sekarang, di mana antreannya tidak pernah
dikuras sama sekali.

## 2.4 Membuktikannya bekerja

Jangan percaya "cron-nya ada" sebagai bukti.

```sql
-- Berapa yang menunggu dikuras
select count(*) from public.storage_purge_queue;

-- Jalankan sekali dengan tangan, lalu hitung lagi
select net.http_post(
  url     := 'https://<REF>.supabase.co/functions/v1/purge-storage',
  headers := jsonb_build_object('Authorization', 'Bearer <service_role_key>'),
  body    := '{}'::jsonb
);
```

Angkanya harus **turun**. Kalau tetap, buka
**Dashboard → Edge Functions → purge-storage → Logs** — sekarang kegagalannya
tertulis di sana.

---

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
$env:SUPABASE_ACCESS_TOKEN = 'sbp_...'
& '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe' secrets set MIDTRANS_SERVER_KEY=Mid-server-XXXX --project-ref <REF>
& '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe' secrets set MIDTRANS_IS_PRODUCTION=true --project-ref <REF>
```

⚠️ Tulis tiap baris **terpisah**. Menyatukannya dengan `;` di satu baris
panjang sudah gagal sekali 3 September 2026 — barisnya terpotong saat ditempel
dan PowerShell menjawab *"Missing expression after '&'"*, galat yang tidak
menyebut sebab sebenarnya.

`MIDTRANS_CLIENT_KEY` di `env.dev.json` juga ikut diganti, lalu APK dan web
dibangun ulang.

## 3.3 Deploy ulang Edge Function

```powershell
& '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe' functions deploy create-payment --project-ref <REF>
& '.\.supabase-cli\node_modules\@supabase\cli-windows-x64\bin\supabase.exe' functions deploy midtrans-webhook --no-verify-jwt --project-ref <REF>
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
U=https://<REF>.supabase.co/functions/v1
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
https://<REF>.supabase.co/functions/v1/midtrans-webhook
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
- [ ] Auth Hook aktif — Beranda menampilkan angka, bukan kosong
- [ ] Redirect URL diisi lengkap
- [ ] Tiga bucket ada, `payment-proofs` **tidak** publik
- [ ] Empat cron ada; `reset-monthly-tokens` dan `mark-expired-videos` **tidak**
- [ ] `pg_net` aktif dan antrean R2 terbukti **turun** setelah dikuras
- [ ] `verify_jwt`: hanya `midtrans-webhook` yang `false`
- [ ] Satu transaksi sungguhan terlacak sampai `token_ledger`
- [ ] APK dan web dibangun ulang dengan kredensial baru
- [ ] Akun Owner, Admin, toko, gambar iklan, dan tutorial dibuat ulang
- [ ] Tiga kartu paket tergambar di Admin > Harga & Paket, bukan dua
- [ ] Project lama **belum** dihapus

⚠️ Yang paling mudah terlewat dari daftar ini adalah baris kedua. Auth Hook
yang mati tidak menimbulkan galat apa pun — hanya layar kosong yang terlihat
seperti "belum ada data".
