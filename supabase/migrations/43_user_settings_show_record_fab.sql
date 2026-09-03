-- ============================================================
-- 43_user_settings_show_record_fab.sql
--   (Bab 9.7 — sakelar "Tombol Rekam mengambang", revisi tampilan)
-- ============================================================
-- Diminta Product Owner 31 Agustus 2026 bersama revisi tampilan. Sebagian
-- packer memulai perekaman dari kartu di Beranda dan tidak pernah memakai
-- tombol mengambang; bagi mereka tombol itu hanya menutupi baris terakhir
-- daftar, dan ruang 88 dp yang disisakan untuknya jadi ruang kosong.
--
-- 🔴 `default true` bukan sekadar kenyamanan. Kolom ini baru, jadi seluruh
-- baris `user_settings` yang sudah ada tidak memilikinya. Kalau defaultnya
-- `false`, setiap pengguna lama akan kehilangan tombol Rekamnya begitu
-- aplikasi diperbarui — tanpa pernah meminta, dan tanpa tanda apa pun bahwa
-- tombolnya bisa dikembalikan.
--
-- `not null` menyusul `default` dengan sengaja: Postgres mengisi baris lama
-- dengan nilai default lebih dulu, jadi tidak ada baris yang melanggar.
--
-- ⚠️ Ini preferensi milik ORANG, bukan tenant — sama seperti tema, bahasa, dan
-- voice-over. Ia ikut ke semua perangkat pengguna (Bab 9.11 poin 4), dan
-- policy RLS `user_settings` yang sudah ada sudah membatasinya ke barisnya
-- sendiri. Tidak ada policy baru yang perlu ditambahkan.

alter table public.user_settings
  add column if not exists show_record_fab boolean not null default true;

comment on column public.user_settings.show_record_fab is
  'Tampilkan tombol Rekam mengambang di kerangka mobile (Bab 9.7). '
  'Saat false, perekaman dimulai dari kartu di Beranda.';
