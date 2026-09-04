-- ============================================================
-- 45_admin_tenant_phone.sql  (Bab 11.2)
-- ============================================================
-- Nomor HP pemilik di halaman Kelola Pengguna, diminta Product Owner
-- 3 September 2026.
--
-- Kolom `users.phone` sudah ada sejak migrasi 03; yang tidak ada hanyalah
-- jalannya ke layar. Halaman Kelola Pengguna diisi sepenuhnya oleh RPC
-- `admin_list_tenants()`, jadi kolom yang tidak dikembalikan fungsi ini tidak
-- akan pernah sampai ke Admin betapapun lengkap datanya di tabel.
--
-- 🔴 Kenapa lewat RPC ini dan bukan kueri terpisah ke `public.users`.
--
-- Admin memang boleh membaca `public.users` (policy `users_admin_all`, migrasi
-- 14), jadi nomor HP-nya bisa saja diambil aplikasi dengan kueri kedua. Itu
-- ditolak, dan alasannya bukan kerapian.
--
-- Fungsi ini mengambil email pemilik lewat `t.owner_id` — satu kolom yang
-- menunjuk satu baris. Kueri terpisah dari aplikasi tidak punya `owner_id`
-- (fungsi ini tidak mengembalikannya), jadi ia hanya bisa mencari lewat
-- `tenant_id` + `role = 'owner'`. Kedua definisi itu biasanya menjawab orang
-- yang sama, tetapi tidak dijamin sama: `owner_id` tidak ikut berubah bila
-- baris `users`-nya berpindah tenant, dan tidak ada apa pun yang melarang dua
-- baris berperan `owner` pada satu tenant.
--
-- Bila keduanya pernah berbeda pada satu baris, layarnya akan menampilkan
-- **email satu orang bersebelahan dengan nomor HP orang lain** — tanpa satu
-- pun galat yang menandainya, dan pada halaman yang justru dipakai Admin untuk
-- menghubungi pelanggan. Satu sumber untuk keduanya menutup kemungkinan itu
-- sepenuhnya.
--
-- ⚠️ Migrasi ini hanya mengganti isi satu fungsi. Tidak ada tabel yang
-- disentuh, tidak ada data yang berubah, dan tidak ada yang dihapus. Aman
-- dijalankan ulang.
-- ============================================================

-- Disalin utuh dari migrasi 32 dengan SATU tambahan: 'owner_phone'.
-- Ditulis ulang seluruhnya, bukan ditambal, karena `create or replace
-- function` memang mengganti seluruh badannya — menyalin sebagian akan
-- menghapus diam-diam bagian yang tidak ikut disalin.
create or replace function public.admin_list_tenants(p_limit integer default 200)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hasil json;
begin
  -- 🔴 BARIS PENJAGA. `security definer` mematikan RLS, jadi baris ini adalah
  -- satu-satunya yang memisahkan Admin dari siapa pun yang sudah masuk.
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'admin_list_tenants() hanya untuk peran admin.';
  end if;

  select coalesce(json_agg(baris order by baris_created_at desc), '[]'::json)
    into v_hasil
    from (
      select
        t.created_at as baris_created_at,
        json_build_object(
          'id',            t.id,
          'business_name', t.business_name,
          'owner_email',   (select u.email::text
                              from public.users u
                             where u.id = t.owner_id),

          -- Nomor HP pemilik (Bab 11.2, ditambahkan 3 September 2026).
          --
          -- ⚠️ Sengaja dibaca lewat `t.owner_id` yang SAMA dengan emailnya di
          -- atas. Bila suatu saat sumbernya diubah, keduanya harus diubah
          -- bersamaan — dua sumber berbeda pada satu baris kontak adalah cara
          -- tercepat menelepon orang yang salah.
          --
          -- Boleh null: `users.phone` tidak wajib diisi (migrasi 03), dan
          -- pendaftar lewat Google tidak pernah ditanya nomornya.
          'owner_phone',   (select u.phone
                              from public.users u
                             where u.id = t.owner_id),

          -- Tenant milik akun admin. Setiap akun memperoleh tenant saat
          -- mendaftar, termasuk yang belakangan dinaikkan menjadi admin.
          'owner_is_admin', coalesce(
                              (select u.role = 'admin'
                                 from public.users u
                                where u.id = t.owner_id), false),

          'tier_plan',     t.tier_plan,
          'status',        t.status,
          'created_at',    t.created_at,
          'period_end',    t.period_end,

          'shop_count',    (select count(*) from public.shops s
                             where s.tenant_id = t.id),
          'packer_count',  (select count(*) from public.users u
                             where u.tenant_id = t.id and u.role = 'packer'),
          'video_count',   (select count(*) from public.package_videos v
                             where v.tenant_id = t.id),
          'token_balance', coalesce(
                             (select w.balance from public.token_wallets w
                               where w.tenant_id = t.id), 0),

          -- 🔴 Akhir periode DOMPET, bukan akhir periode langganan.
          --
          -- ⚠️ Sejak migrasi 40 nilai ini TIDAK LAGI dipakai layar untuk
          -- mengatakan kapan token hangus. Cron `reset-monthly-tokens` sudah
          -- dicabut, jadi tidak ada lagi reset bulanan yang menggerakkannya;
          -- token sekarang hangus saat LANGGANAN berakhir, dan tanggal itu
          -- dibaca dari `period_end` di atas. Kolom ini dipertahankan supaya
          -- versi aplikasi lama tidak kehilangan bidang yang dibacanya.
          'token_period_end', (select w.period_end from public.token_wallets w
                                where w.tenant_id = t.id)
        ) as baris
        from public.tenants t
       order by t.created_at desc
       limit p_limit
    ) urut;

  return v_hasil;
end;
$$;

comment on function public.admin_list_tenants(integer) is
  'Bab 11.2 - satu baris per pelanggan beserta jumlah toko, packer, video, '
  'saldo token, dan kontak pemilik (email + nomor HP). owner_is_admin '
  'menandai tenant milik akun admin sendiri. security definer: RLS TIDAK '
  'berlaku, is_admin() adalah satu-satunya penjagaan.';

grant execute on function public.admin_list_tenants(integer) to authenticated;
revoke execute on function public.admin_list_tenants(integer) from anon, public;
