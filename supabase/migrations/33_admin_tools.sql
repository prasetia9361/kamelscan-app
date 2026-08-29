-- ============================================================
-- 33_admin_tools.sql  (Bab 2.2 — menaikkan seseorang menjadi Admin)
-- ============================================================
-- Tiga fungsi yang dijalankan Product Owner sendiri dari **Supabase Dashboard
-- → SQL Editor**, masing-masing cukup satu baris:
--
--   select public.promote_to_admin('budi@contoh.com');
--   select public.demote_to_owner('budi@contoh.com');
--   select * from public.list_admins();
--
-- Bab 2.2 menuliskannya sebagai aturan: *"Admin dibuat manual di database,
-- tidak ada jalur registrasi menjadi admin dari aplikasi."* Berkas ini TIDAK
-- melanggarnya — ia hanya membuat cara manualnya lebih sulit dilakukan dengan
-- salah. Membuat admin tetap menuntut kredensial Dashboard, yang terpisah dari
-- login aplikasi.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 KENAPA `security invoker`, DAN KENAPA HAK PANGGILNYA DICABUT
-- ------------------------------------------------------------
--
-- Seluruh fungsi lintas-pelanggan di proyek ini `security definer`
-- (`get_platform_stats`, `admin_list_tenants`, dan seterusnya). Yang di berkas
-- ini justru **kebalikannya**, dan itu bukan kelalaian.
--
-- Sebuah fungsi `security definer` bernama `promote_to_admin` adalah lubang
-- peningkatan hak akses yang paling telanjang yang dapat dibuat: siapa pun
-- yang berhasil login — termasuk packer mana pun — dapat memanggilnya lewat
-- PostgREST dan mengangkat dirinya sendiri menjadi admin platform. Penjagaan
-- `is_admin()` di dalamnya pun tidak cukup menenangkan, karena satu suntingan
-- ceroboh di kemudian hari sudah cukup untuk membukanya.
--
-- Karena itu DUA lapis sekaligus:
--
--   1. `security invoker` (bawaan) — RLS tetap berlaku bagi pemanggilnya.
--      Yang bukan admin tidak menyentuh satu baris pun.
--   2. `revoke execute ... from public, anon, authenticated` — ia tidak dapat
--      dipanggil dari aplikasi SAMA SEKALI, bahkan oleh admin sungguhan.
--
-- PostgreSQL memberikan EXECUTE kepada PUBLIC secara otomatis pada setiap
-- fungsi baru. Baris `revoke` di bawah karena itu WAJIB ada, dan wajib ikut
-- disalin bila suatu hari fungsi ini diubah.
--
-- ⚠️ Bagi yang menjalankannya di SQL Editor, `auth.uid()` bernilai NULL —
-- tidak ada JWT di sana. `audit_logs.actor_id` karena itu kosong, dan itu
-- **keadaan yang benar**: barisnya justru menandakan perubahan dilakukan dari
-- Dashboard, bukan dari dalam aplikasi.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 1. Naikkan menjadi Admin
-- ------------------------------------------------------------
-- Mengembalikan satu kalimat berisi NAMA orangnya, bukan sekadar "berhasil".
-- Product Owner mengetik email; yang harus ia periksa adalah namanya.
create or replace function public.promote_to_admin(p_email text)
returns text
language plpgsql
as $$
declare
  v_id     uuid;
  v_nama   text;
  v_email  text;
  v_role   user_role;
begin
  select id, full_name, email::text, role
    into v_id, v_nama, v_email, v_role
    from public.users
   where email_normalized = public.normalize_email(p_email);

  -- 🔴 Menolak dengan galat, bukan mengembalikan pesan biasa. Perintah yang
  -- "berhasil" tetapi tidak mengubah apa pun adalah bentuk kegagalan paling
  -- sulit disadari — `update ... where email = ...` yang salah ketik satu
  -- huruf melakukan persis itu, dan SQL Editor menuliskannya sebagai sukses.
  if v_id is null then
    raise exception 'TIDAK DITEMUKAN'
      using errcode = '22023',
            hint = format(
              '%s belum terdaftar. Suruh ia mendaftar lebih dulu di '
              'kamelscan.com/app/register, atau buat akunnya lewat Dashboard '
              '> Authentication > Add user. JANGAN memakai alias Gmail '
              '(nama+admin@gmail.com) - alias itu dianggap sama dengan alamat '
              'aslinya dan pendaftarannya ditolak.',
              p_email);
  end if;

  if v_role = 'admin' then
    return format(
      'TIDAK ADA YANG DIUBAH - %s (%s) memang sudah admin.', v_nama, v_email);
  end if;

  update public.users
     set role = 'admin'
   where id = v_id;

  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  select u.tenant_id, auth.uid(), 'user.promote_admin', 'users', u.id,
         jsonb_build_object('email', v_email, 'dari', v_role, 'jadi', 'admin')
    from public.users u
   where u.id = v_id;

  return format(
    'BERHASIL - %s (%s) kini admin. SURUH IA KELUAR LALU MASUK LAGI; '
    'perannya dibawa di dalam token login, dan sebelum itu aplikasi masih '
    'menganggapnya %s.', v_nama, v_email, v_role);
end;
$$;

comment on function public.promote_to_admin(text) is
  'Bab 2.2 - menaikkan pengguna terdaftar menjadi admin. HANYA dari SQL '
  'Editor: security invoker dan hak execute dicabut dari anon/authenticated, '
  'karena fungsi semacam ini yang dapat dipanggil aplikasi adalah lubang '
  'peningkatan hak akses.';

-- ------------------------------------------------------------
-- 2. Kembalikan menjadi Owner
-- ------------------------------------------------------------
create or replace function public.demote_to_owner(p_email text)
returns text
language plpgsql
as $$
declare
  v_id      uuid;
  v_nama    text;
  v_email   text;
  v_role    user_role;
  v_sisa    integer;
begin
  select id, full_name, email::text, role
    into v_id, v_nama, v_email, v_role
    from public.users
   where email_normalized = public.normalize_email(p_email);

  if v_id is null then
    raise exception 'TIDAK DITEMUKAN'
      using errcode = '22023',
            hint = format('%s tidak ada di tabel users.', p_email);
  end if;

  if v_role <> 'admin' then
    return format(
      'TIDAK ADA YANG DIUBAH - %s (%s) bukan admin, melainkan %s.',
      v_nama, v_email, v_role);
  end if;

  -- 🔴 Menolak menurunkan admin TERAKHIR.
  --
  -- Tanpa penjagaan ini, satu perintah salah ketik dapat membuat platform
  -- tidak punya admin sama sekali: panel admin tidak dapat dibuka siapa pun,
  -- pembayaran tidak dapat diverifikasi, dan satu-satunya jalan keluar adalah
  -- kembali ke SQL Editor. Belum tentu orang yang menyadarinya punya
  -- kredensialnya.
  select count(*) into v_sisa
    from public.users where role = 'admin' and id <> v_id;

  if v_sisa = 0 then
    raise exception 'ADMIN TERAKHIR'
      using errcode = '22023',
            hint = format(
              '%s adalah satu-satunya admin yang tersisa. Menurunkannya '
              'membuat platform tidak punya admin sama sekali. Naikkan orang '
              'lain lebih dulu dengan promote_to_admin(), baru jalankan ini.',
              v_email);
  end if;

  update public.users
     set role = 'owner'
   where id = v_id;

  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  select u.tenant_id, auth.uid(), 'user.demote_owner', 'users', u.id,
         jsonb_build_object('email', v_email, 'dari', 'admin', 'jadi', 'owner')
    from public.users u
   where u.id = v_id;

  return format(
    'BERHASIL - %s (%s) kembali menjadi owner. Suruh ia keluar lalu masuk '
    'lagi. Tenant miliknya tidak tersentuh sama sekali.', v_nama, v_email);
end;
$$;

comment on function public.demote_to_owner(text) is
  'Bab 2.2 - mengembalikan admin menjadi owner. Menolak menurunkan admin '
  'terakhir, karena itu membuat platform tidak punya admin sama sekali.';

-- ------------------------------------------------------------
-- 3. Siapa saja yang sekarang admin
-- ------------------------------------------------------------
-- Dijalankan SEBELUM dan SESUDAH kedua fungsi di atas. Daftar yang lebih
-- panjang daripada dugaan adalah hal pertama yang perlu diketahui pemilik
-- platform, dan tidak ada satu pun layar di aplikasi yang menampilkannya.
create or replace function public.list_admins()
returns table (email text, nama text, terdaftar timestamptz)
language sql
stable
as $$
  select u.email::text, u.full_name, u.created_at
    from public.users u
   where u.role = 'admin'
   order by u.created_at;
$$;

comment on function public.list_admins() is
  'Bab 2.2 - daftar seluruh akun berperan admin. Tidak ada layar di aplikasi '
  'yang menampilkannya; jalankan dari SQL Editor sebelum dan sesudah mengubah '
  'peran siapa pun.';

-- ------------------------------------------------------------
-- 🔴 WAJIB — dan wajib ikut disalin bila fungsi di atas diubah
-- ------------------------------------------------------------
-- PostgreSQL memberikan EXECUTE kepada PUBLIC secara otomatis pada setiap
-- fungsi baru. Tanpa baris-baris ini, ketiganya dapat dipanggil lewat
-- PostgREST oleh siapa pun yang berhasil login.
revoke execute on function public.promote_to_admin(text) from public, anon, authenticated;
revoke execute on function public.demote_to_owner(text)  from public, anon, authenticated;
revoke execute on function public.list_admins()          from public, anon, authenticated;
