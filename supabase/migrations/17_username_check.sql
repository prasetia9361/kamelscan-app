-- ============================================================
-- 17_username_check.sql  (Bab 6.2)
-- ============================================================
-- Ketersediaan username harus bisa dicek SEBELUM pendaftaran dikirim.
--
-- Tanpa ini, username ganda baru ketahuan saat trigger handle_new_user
-- melanggar `users_username_key`. Kegagalan di dalam trigger dibungkus GoTrue
-- menjadi pesan yang sama sekali tidak menjelaskan apa pun:
--
--   {"code":500,"error_code":"unexpected_failure",
--    "msg":"Database error saving new user"}
--
-- Aplikasi tidak punya cara membedakannya dari kegagalan lain, sehingga
-- pengguna hanya melihat pesan umum. Terjadi sungguhan 13 Agustus 2026:
-- pendaftaran ditolak berulang kali tanpa petunjuk bahwa penyebabnya adalah
-- username yang sudah dipakai akun lain milik orang yang sama.
--
-- ⚠️ Fungsi ini SENGAJA hanya mengembalikan boolean. Bab 6.6 melarang
-- membocorkan daftar email pelanggan; mengembalikan baris `users` di sini akan
-- melanggar itu. Bahwa sebuah username sudah terpakai memang perlu diketahui
-- calon pendaftar — itu tujuan formulirnya.
-- ============================================================

create or replace function public.is_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    -- Format tidak valid diperlakukan sebagai "tidak tersedia" agar aturannya
    -- sama persis dengan chk_username_format di 03_users.sql.
    when p_username is null then false
    when lower(trim(p_username)) !~ '^[a-z0-9._]{4,20}$' then false
    else not exists (
      select 1 from public.users u
       where u.username = lower(trim(p_username))
    )
  end;
$$;

-- Boleh dipanggil sebelum login (formulir pendaftaran belum punya sesi).
grant execute on function public.is_username_available(text) to anon, authenticated;
