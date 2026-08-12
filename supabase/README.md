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

## Menjalankan dengan alat bawaan repo

`tool/db_migrate` menjalankan seluruh berkas berurutan dan mencatat mana yang
sudah dijalankan di tabel `public.schema_migrations`, sehingga aman diulang.

```powershell
$env:SUPABASE_DB_HOST='aws-0-<region>.pooler.supabase.com'
$env:SUPABASE_DB_PORT='5432'
$env:SUPABASE_DB_USER='postgres.<project-ref>'
$env:SUPABASE_DB_PASSWORD='<password database>'
$env:SUPABASE_DB_NAME='postgres'
cd tool\db_migrate
dart run bin/migrate.dart status   # lihat mana yang sudah/belum
dart run bin/migrate.dart up       # jalankan yang belum
dart run bin/verify.dart           # periksa hasilnya
```

Alamat host dan `<region>` ada di Dashboard → Project Settings → Database →
Connection string. Gunakan **port 5432 (session mode)**, bukan 6543 — mode
transaksi tidak cocok untuk DDL.

---

## 🔴 Satu langkah manual yang tidak bisa lewat SQL

**Aktifkan Auth Hook setelah menjalankan `12_auth_hook.sql`.**
Dashboard → Authentication → Hooks → *Customize Access Token* → pilih
`public.custom_access_token_hook`.

Ini **wajib** dan paling sering terlewat. Tanpanya JWT tidak memuat `tenant_id`,
`current_tenant_id()` mengembalikan NULL, dan setiap perbandingan
`tenant_id = NULL` bernilai NULL — bukan error, melainkan **nol baris**.

Sudah dibuktikan pada 13 Agustus 2026 dengan akun uji yang login sungguhan,
sebelum hook diaktifkan:

| Tabel | Hasil |
|---|---|
| `users` | 1 baris — policy-nya memakai `auth.uid()`, tidak butuh hook |
| `platform_settings` | 6 baris — policy-nya `using (true)` |
| `tenants`, `shops`, `package_videos`, `token_wallets` | **0 baris** |

Gejalanya: aplikasi terbuka, login berhasil, tetapi semua daftar kosong dan
tidak ada satu pun pesan error. Bila Anda melihat gejala itu, **periksa hook ini
lebih dulu** sebelum mencurigai kode Flutter.

> `pg_cron` **tidak** perlu diaktifkan manual di project ini — `create extension`
> pada `00_extensions.sql` berhasil dan ketiga job cron sudah terpasang. Bila di
> project baru ternyata gagal, aktifkan lewat Dashboard → Database → Extensions.

---

## Penyimpangan dari Bab 5 — empat perbaikan wajib

SQL di Bab 5 mengandung empat kesalahan yang membuatnya tidak dapat dijalankan
apa adanya. Tiga ditemukan saat membaca, satu baru muncul saat benar-benar
dijalankan. Semuanya diperbaiki dengan perubahan sekecil mungkin, dan setiap
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

### 4. `uuid_generate_v4()` tak terlihat dari dalam trigger

Semua berkas · **Ini baru ketahuan saat dijalankan, bukan saat dibaca.**

Di Supabase, `uuid-ossp` dan `pgcrypto` dipasang ke schema **`extensions`**,
bukan `public`. Seluruh trigger `SECURITY DEFINER` menyetel
`search_path = public` demi keamanan, sehingga `uuid_generate_v4()` tidak
terlihat dari dalamnya:

```
SQLSTATE 42883: function uuid_generate_v4() does not exist
```

Gejalanya di aplikasi hanyalah *"Database error saving new user"* dari Auth API
— tidak menyebut fungsi mana pun.

**Perbaikan:** seluruh berkas memakai `gen_random_uuid()`, fungsi bawaan
PostgreSQL 13+ yang berada di `pg_catalog` sehingga selalu terlihat berapa pun
`search_path`-nya. Kedua ekstensi tetap dipasang sesuai Bab 5.2.

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

---

## Hasil verifikasi di database sungguhan — 13 Agustus 2026

Seluruh 17 migrasi dijalankan pada project Supabase `ofggpithmvgnhsshglwx`
(wilayah ap-southeast-1) memakai `tool/db_migrate`.

| Yang diperiksa | Hasil |
|---|---|
| 14 tabel terbentuk | ✅ |
| RLS aktif di semua tabel aplikasi | ✅ (hanya `schema_migrations` tanpa RLS, memang bukan tabel data) |
| 30 policy RLS terpasang | ✅ |
| 7 enum sesuai `enums.dart` | ✅ |
| 8 trigger + trigger registrasi di `auth.users` | ✅ |
| 3 job cron terjadwal | ✅ |
| FK `fk_tenants_owner` DEFERRABLE | ✅ |
| `normalize_email` | ✅ `Bu.Di+promo@Gmail.com` → `budi@gmail.com`, non-gmail titiknya dipertahankan |

### Uji alur nyata lewat Auth API

**Registrasi owner baru** — satu panggilan `POST /auth/v1/signup` menghasilkan:

| Baris | Isi |
|---|---|
| `users` | email asli tersimpan, `email_normalized` = `ujiowner@gmail.com`, role `owner` |
| `tenants` | `status=trial`, `tier=standar`, `period_end=NULL` (Bab 7.5 — batasnya jumlah video, bukan waktu) |
| `token_wallets` | saldo 100 / kuota 100, `period_end=NULL` |
| `token_ledger` | `+100`, alasan `monthly_reset`, catatan "Kuota uji coba gratis" |
| `tenant_settings` | watermark `bottom_right`, GPS aktif |
| `user_settings` | tema `default`, bahasa `id`, voice-over aktif |

**Celah alias Gmail tertutup (Bab 7.5).** Pendaftaran kedua dengan
`uji.owner@gmail.com` — email berbeda, normalisasi sama — ditolak:

```
23505: duplicate key value violates unique constraint "users_email_normalized_key"
detail: Key (email_normalized)=(ujiowner@gmail.com) already exists.
```

**Verifikasi email ditegakkan.** Login sebelum email dikonfirmasi ditolak
HTTP 400, sesuai alur Bab 6.

### Yang BELUM diuji

- Isolasi antar tenant (Bab 5.7) — perlu dua tenant berisi data dan Auth Hook
  aktif. **Ini kriteria kelulusan Minggu 2 dan belum terpenuhi.**
- `before_video_insert`, `after_video_uploaded`, `check_packer_limit` — baru
  bisa diuji setelah ada alur perekaman (Bab 8).
- `seed.sql` belum pernah dijalankan.

### Akun uji yang tertinggal di database

`uji.owner+test@gmail.com` / `Password123` — dibuat untuk pengujian di atas dan
sengaja tidak dihapus agar hook bisa diverifikasi ulang. Hapus sebelum database
dipakai sungguhan:

```sql
delete from auth.users where email like 'uji.owner%';
```
