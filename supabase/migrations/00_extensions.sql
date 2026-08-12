-- ============================================================
-- 00_extensions.sql  (Bab 5.2)
-- ============================================================
-- Dijalankan sekali, berurutan, pada database kosong.
-- Urutan berkas 00 → 16 WAJIB dipatuhi.
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "citext";     -- email case-insensitive
create extension if not exists "pg_trgm";    -- pencarian resi

-- ⚠️ pg_cron TIDAK dapat dibuat lewat SQL editor pada sebagian proyek Supabase.
-- Aktifkan dulu lewat Dashboard > Database > Extensions, baru jalankan 16_cron.sql.
-- Baris ini sengaja dibiarkan agar gagal cepat bila belum diaktifkan.
create extension if not exists "pg_cron";
