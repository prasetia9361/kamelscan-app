-- ============================================================
-- 00_extensions.sql  (Bab 5.2)
-- ============================================================
-- Dijalankan sekali, berurutan, pada database kosong.
-- Urutan berkas 00 → 16 WAJIB dipatuhi.
-- ============================================================

-- ⚠️ Di Supabase, uuid-ossp dan pgcrypto dipasang ke schema `extensions`,
--    BUKAN `public`. Akibatnya `uuid_generate_v4()` TIDAK terlihat dari fungsi
--    apa pun yang menyetel `search_path = public` — termasuk seluruh trigger
--    SECURITY DEFINER di 15_triggers.sql. Registrasi pertama akan gagal dengan
--    "function uuid_generate_v4() does not exist" (SQLSTATE 42883).
--
--    Karena itu seluruh berkas migrasi memakai `gen_random_uuid()` yang sudah
--    menjadi fungsi bawaan PostgreSQL 13+ di pg_catalog, sehingga selalu
--    terlihat berapa pun search_path-nya. Kedua ekstensi tetap dipasang sesuai
--    Bab 5.2 untuk keperluan lain.
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "citext";     -- email case-insensitive
create extension if not exists "pg_trgm";    -- pencarian resi

-- ⚠️ pg_cron TIDAK dapat dibuat lewat SQL editor pada sebagian proyek Supabase.
-- Aktifkan dulu lewat Dashboard > Database > Extensions, baru jalankan 16_cron.sql.
-- Baris ini sengaja dibiarkan agar gagal cepat bila belum diaktifkan.
create extension if not exists "pg_cron";
