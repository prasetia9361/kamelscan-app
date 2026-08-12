# Database KamelScan — Bab 5

Skema, Row Level Security, trigger, dan cron sesuai **Bab 5** dokumen panduan.

---

## Urutan penerapan

Jalankan berurutan. Urutannya **tidak boleh diubah** — tiap berkas bergantung
pada yang sebelumnya.

| # | Berkas | Isi |
|---|---|---|
| 1 | `migrations/00_extensions.sql` | Ekstensi PostgreSQL |
| 2 | `migrations/01_enums.sql` | Tipe enum (cerminan `lib/core/models/enums.dart`) |
| 3 | `migrations/02_tenants.sql` | Tabel tenant |
| 4 | `migrations/03_users.sql` | Profil pengguna + FK melingkar ke tenant |
| 5 | `migrations/04_shops.sql` | Toko & penugasan packer |
| 6 | `migrations/05_package_videos.sql` | Tabel inti + indeks resi |
| 7 | `migrations/06_tokens.sql` | Dompet & buku besar token |
| 8 | `migrations/07_subscriptions.sql` | Langganan |
| 9 | `migrations/08_settings.sql` | Pengaturan pengguna/tenant/platform + isi awal |
| 10 | `migrations/09_promos.sql` | Kode promo |
| 11 | `migrations/10_tutorials.sql` | Tutorial |
| 12 | `migrations/11_audit_logs.sql` | Jejak audit |
| 13 | `migrations/12_auth_hook.sql` | Sisip `tenant_id`/`role` ke JWT |
| 14 | `migrations/13_helpers.sql` | Fungsi bantu RLS + normalisasi email |
| 15 | `migrations/14_rls.sql` | **Seluruh policy RLS** |
| 16 | `migrations/15_triggers.sql` | Trigger registrasi, kuota, batas packer |
| 17 | `migrations/16_cron.sql` | Penjadwalan harian |

Cara termudah: buka **Dashboard → SQL Editor**, tempel isi tiap berkas satu per
satu, jalankan, pastikan sukses sebelum lanjut ke berikutnya.

---

## 🔴 Dua langkah manual yang tidak bisa lewat SQL

Tanpa keduanya aplikasi **tidak akan berfungsi sama sekali**.

**1. Aktifkan `pg_cron` sebelum menjalankan `16_cron.sql`.**
Dashboard → Database → Extensions → cari `pg_cron` → aktifkan.

**2. Aktifkan Auth Hook setelah menjalankan `12_auth_hook.sql`.**
Dashboard → Authentication → Hooks → *Customize Access Token* → pilih
`public.custom_access_token_hook`.

Langkah 2 adalah yang paling sering terlewat. Tanpanya JWT tidak memuat
`tenant_id`, sehingga `current_tenant_id()` mengembalikan NULL dan **setiap
policy RLS menolak semua akses** — aplikasi akan tampak "kosong" tanpa pesan
error yang jelas.

---

## Penyimpangan dari Bab 5 — tiga perbaikan wajib

SQL di Bab 5 mengandung tiga kesalahan yang membuatnya tidak dapat dijalankan
apa adanya. Ketiganya diperbaiki dengan perubahan sekecil mungkin, dan setiap
perbaikan diberi komentar di berkasnya masing-masing.

### 1. Foreign key melingkar — registrasi pertama pasti gagal

`03_users.sql` · Bab 5.2 menulis `fk_tenants_owner` tanpa `DEFERRABLE`.

`tenants.owner_id → users.id` dan `users.tenant_id → tenants.id` saling
melingkar. Trigger `handle_new_user` menyisipkan **tenants lebih dulu** dengan
`owner_id` menunjuk ke baris users yang belum ada, sehingga foreign key
dilanggar seketika.

**Perbaikan:** FK dijadikan `DEFERRABLE INITIALLY DEFERRED` agar diperiksa di
akhir transaksi, bukan per pernyataan.

### 2. `email_normalized` NOT NULL tetapi tidak pernah diisi

`13_helpers.sql` + `15_triggers.sql` · Bab 5.2 mendeklarasikan kolom ini
`not null unique`, tetapi trigger `handle_new_user` di Bab 5.5 tidak pernah
mengisinya → pelanggaran not-null pada setiap registrasi.

**Perbaikan:** fungsi `public.normalize_email()` (kembaran server dari
`Validators.normalizeEmail`) plus trigger `trg_users_email_normalized`.
Dibuat sebagai trigger tersendiri, bukan ditambal di dalam `handle_new_user`,
supaya invariannya tetap terjaga dari mana pun baris `users` disisipkan —
termasuk lewat Edge Function pembuatan packer.

Ini sekaligus menegakkan Bab 7.5: menutup celah alias Gmail agar uji coba
gratis 100 video tidak bisa diulang dengan `nama+1@gmail.com`.

### 3. `coalesce` pada enum tidak bisa dikompilasi

`15_triggers.sql` · Bab 5.5c menulis `coalesce(old.status,'') <> 'uploaded'`.
`old.status` bertipe enum `video_status`; PostgreSQL menolak dengan
*"COALESCE types video_status and text cannot be matched"*.

**Perbaikan:** `old.status is distinct from 'uploaded'` — menangani NULL dengan
benar tanpa memaksa tipe.

---

## Data uji

`seed.sql` berisi 1 admin, 2 owner (`standar` masih trial, `pro` berlangganan
aktif), masing-masing 2 toko dan 3 packer, serta 30 video dengan tanggal
tersebar. Password semua akun uji: `Password123`.

🔴 **Jangan dijalankan di database produksi.** Berkas ini punya pengaman yang
membatalkan eksekusi bila menemukan pengguna dengan email selain
`@example.com`.

---

## Uji kebocoran tenant — kriteria kelulusan Minggu 2

Bab 5.7 menegaskan uji ini **tidak boleh dilewati**. Kegagalan paling umum pada
aplikasi multi-tenant adalah menegakkan aturan hanya di UI.

Setelah seed, login sebagai `owner.pro@example.com` lalu jalankan dari aplikasi
(bukan SQL editor — SQL editor memakai service role yang mengabaikan RLS):

```sql
select count(*) from package_videos;          -- harus 15, bukan 30
select count(*) from shops;                   -- harus 2, bukan 4
select count(*) from users;                   -- harus 4 (1 owner + 3 packer)
```

Lalu coba akses langsung milik tenant lain:

```sql
select * from package_videos where resi_code like 'SPXID%';   -- harus 0 baris
```

Ulangi sebagai packer. Dengan `shop_history_visible_to_packer = false`
(bawaan), packer hanya boleh melihat video yang ia rekam sendiri.

⚠️ Uji ini harus dilakukan dengan **JWT sungguhan lewat API**, dengan asumsi
penyerang memanggil PostgREST langsung tanpa lewat aplikasi. Menguji dari SQL
editor akan selalu lulus dan tidak membuktikan apa pun.
