-- ============================================================
-- 31_admin_tenants.sql  (Bab 11.2 — manajemen pengguna Admin)
-- ============================================================
-- Satu baris per pelanggan beserta angka pemakaiannya: jumlah toko, packer,
-- video, dan saldo token. Sepuluh kolom yang diminta Bab 11.2, dalam SATU
-- panggilan.
--
-- 🔴 `security definer`, sama seperti `get_platform_stats()` (migrasi 30) dan
-- untuk alasan yang sama: RLS TIDAK berlaku di dalamnya, dan pemeriksaan
-- `is_admin()` di baris pertama adalah satu-satunya yang berdiri antara
-- seorang packer dan data seluruh pelanggan. Jangan pernah menghapusnya, dan
-- jangan pernah memindahkannya ke bawah query mana pun.
--
-- Bab 11.1 menuliskannya sebagai keharusan:
--   "Kueri lintas tenant harus dijalankan lewat RPC security definer yang di
--    dalamnya memeriksa is_admin(). Jangan mengandalkan RLS bypass dari klien."
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 EMPAT KEPUTUSAN, dan alasan masing-masing
-- ------------------------------------------------------------
--
-- 1. PENOLAKAN MELEMPAR GALAT, BUKAN MENGEMBALIKAN DAFTAR KOSONG.
--
--    Alasannya persis seperti migrasi 30. Daftar kosong akan tampil di layar
--    sebagai "platform ini belum punya pelanggan" — kalimat yang salah dan
--    terlihat masuk akal. Galat 42501 membuat layarnya menulis "Anda tidak
--    memiliki akses", yang memang benar.
--
-- 2. EMPAT ANGKA PEMAKAIAN DIHITUNG LEWAT SUBQUERY, bukan lewat join
--    bertumpuk.
--
--    Empat `left join` ke tabel yang masing-masing punya banyak baris akan
--    saling menggandakan: satu tenant dengan 2 toko dan 3 packer menghasilkan
--    6 baris, dan `count(*)` di atasnya mengembalikan angka yang salah untuk
--    keduanya. Kesalahan itu tidak melempar apa pun — ia hanya menampilkan
--    angka yang terlalu besar, dan tidak ada yang menyadarinya sampai
--    seseorang menghitung sendiri.
--
-- 3. "JUMLAH VIDEO" MENGHITUNG SELURUH BARIS, termasuk `deleted` dan
--    `expired` — sama dengan "Total Video" di dasbor platform (migrasi 30
--    keputusan 4).
--
--    Dua angka bernama sama yang menghitung hal berbeda di dua halaman
--    bersebelahan adalah cara tercepat membuat kedua halaman itu tidak
--    dipercaya lagi.
--
-- 4. EMAIL PEMILIK DIAMBIL LEWAT SUBQUERY KE `users`, bukan lewat embedding
--    PostgREST.
--
--    `users` punya DUA hubungan ke `tenants` sekaligus (`users.tenant_id` dan
--    `tenants.owner_id`), dan PostgREST menolak embedding yang rancu seperti
--    itu tanpa menyebut nama constraint-nya — sudah tercatat di
--    `AdminRepository.fetchPendingPayments`. Di dalam SQL kerancuan itu tidak
--    ada: `t.owner_id` menunjuk tepat satu baris.
-- ------------------------------------------------------------

create or replace function public.admin_list_tenants(p_limit integer default 200)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hasil json;
begin
  -- 🔴 BARIS PENJAGA. Lihat catatan di kepala berkas.
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
          'tier_plan',     t.tier_plan,
          'status',        t.status,
          'created_at',    t.created_at,
          'period_end',    t.period_end,

          -- Lihat keputusan 2: subquery, bukan join bertumpuk.
          'shop_count',    (select count(*) from public.shops s
                             where s.tenant_id = t.id),
          'packer_count',  (select count(*) from public.users u
                             where u.tenant_id = t.id and u.role = 'packer'),
          'video_count',   (select count(*) from public.package_videos v
                             where v.tenant_id = t.id),

          -- Dompet token dibuat trigger saat pendaftaran, tetapi tenant yang
          -- lahir sebelum trigger itu ada tidak memilikinya. `coalesce`
          -- membuat kolomnya menulis 0, bukan kosong — sel kosong di kolom
          -- angka terbaca sebagai kerusakan halaman.
          'token_balance', coalesce(
                             (select w.balance from public.token_wallets w
                               where w.tenant_id = t.id), 0)
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
  'dan saldo token. security definer: RLS TIDAK berlaku di dalamnya, dan '
  'pemeriksaan is_admin() di baris pertama adalah satu-satunya penjagaan. '
  'Jumlah video menghitung seluruh baris termasuk deleted dan expired, sama '
  'dengan Total Video di dasbor platform.';

grant execute on function public.admin_list_tenants(integer) to authenticated;
revoke execute on function public.admin_list_tenants(integer) from anon, public;
