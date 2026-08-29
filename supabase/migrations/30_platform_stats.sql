-- ============================================================
-- 30_platform_stats.sql  (Bab 11.1 — dasbor platform Admin)
-- ============================================================
-- Angka ringkasan seluruh platform dalam satu panggilan: jumlah pelanggan per
-- tier, pendaftar baru bulan ini, MRR, total video, perkiraan storage, dan
-- perkiraan margin.
--
-- 🔴 SATU-SATUNYA fungsi di proyek ini yang MENEMBUS SELURUH BATAS ANTAR
-- PELANGGAN. Setiap fungsi lain memakai `security invoker` sehingga cakupannya
-- otomatis mengikuti RLS; yang ini `security definer` karena memang harus
-- menghitung lintas tenant.
--
-- Konsekuensinya: RLS TIDAK BERLAKU di dalamnya. Pemeriksaan `is_admin()` di
-- baris pertama adalah **satu-satunya** yang berdiri antara seorang packer dan
-- data seluruh pelanggan. Jangan pernah menghapusnya, dan jangan pernah
-- memindahkannya ke bawah query mana pun.
--
-- Bab 11.1 menuliskannya sebagai keharusan:
--   "Kueri lintas tenant harus dijalankan lewat RPC security definer yang di
--    dalamnya memeriksa is_admin(). Jangan mengandalkan RLS bypass dari klien."
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 EMPAT KEPUTUSAN, dan alasan masing-masing
-- ------------------------------------------------------------
--
-- 1. PENOLAKAN MELEMPAR GALAT, BUKAN MENGEMBALIKAN NOL.
--
--    Mengembalikan angka nol kepada yang tidak berhak akan tampil di layar
--    sebagai "platform ini belum punya pelanggan" — kalimat yang salah dan
--    terlihat masuk akal. Galat 42501 membuat layarnya menampilkan pesan
--    "Anda tidak memiliki akses", yang memang benar.
--
-- 2. MRR DIHITUNG DARI HARGA TIER YANG SEDANG AKTIF, bukan dari jumlah
--    pembayaran yang masuk.
--
--    Keduanya berbeda dan keduanya benar untuk pertanyaan berbeda. MRR
--    menjawab "berapa pendapatan berulang yang seharusnya masuk bulan depan
--    bila tidak ada yang berhenti" — itu angka perencanaan. Menjumlahkan
--    `subscriptions.amount` menjawab "berapa yang sudah masuk", yang berayun
--    mengikuti tanggal orang membayar dan tidak dapat dipakai merencanakan
--    apa pun.
--
--    ⚠️ Tenant `trial` TIDAK dihitung: ia belum membayar sepeser pun.
--
-- 3. BIAYA INFRASTRUKTUR DIBACA DARI `platform_settings`, dan bila BELUM
--    DIISI, marginnya dikirim NULL — bukan sama dengan MRR.
--
--    MRR dikurangi nol menghasilkan angka yang persis sama dengan MRR, dan di
--    layar ia akan terbaca sebagai "seluruh pendapatan adalah keuntungan".
--    Itu kalimat yang paling tidak boleh dikarang oleh sebuah dasbor
--    keuangan. Yang belum diketahui ditulis sebagai belum diketahui.
--
--    Admin mengisinya lewat Supabase Dashboard sampai Bab 11.3 dikerjakan:
--      update public.platform_settings
--         set value = '{"monthly_idr": 500000}'::jsonb
--       where key = 'infra_cost';
--
-- 4. "TOTAL VIDEO" MENGHITUNG SELURUH BARIS, termasuk yang berstatus
--    `deleted` dan `expired`.
--
--    Mengikuti Bab 11.1 apa adanya (`count(package_videos)`). Angka ini
--    menjawab "berapa banyak yang pernah direkam di platform ini", bukan
--    "berapa yang masih tersimpan" — yang kedua sudah dijawab baris storage
--    di bawahnya, yang memang hanya menghitung `uploaded`.
--
--    ⚠️ Keduanya karena itu MEMANG tidak akan pernah cocok, dan layarnya
--    wajib mengatakannya. Selisih yang tidak dijelaskan terbaca sebagai
--    kerusakan — pelajaran dari dua grafik dasbor web (O.16).
-- ------------------------------------------------------------

-- Biaya infrastruktur bulanan, diisi Admin dengan tangan.
-- `on conflict do nothing` supaya migrasi ini aman diulang dan tidak menimpa
-- angka yang sudah diisi Admin.
insert into public.platform_settings (key, value)
values ('infra_cost', '{"monthly_idr": null}'::jsonb)
on conflict (key) do nothing;

create or replace function public.get_platform_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mrr        numeric := 0;
  v_biaya      numeric;
  v_awal_bulan timestamptz;
begin
  -- 🔴 BARIS PENJAGA. Lihat catatan di kepala berkas: `security definer`
  -- mematikan RLS, jadi inilah satu-satunya yang tersisa.
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'get_platform_stats() hanya untuk peran admin.';
  end if;

  -- Awal bulan menurut waktu Jakarta, bukan UTC. Pendaftar yang masuk
  -- tanggal 1 pukul 02.00 WIB tercatat masih 31 di UTC, dan angkanya akan
  -- meleset satu hari setiap awal bulan.
  v_awal_bulan := date_trunc(
    'month', (now() at time zone 'Asia/Jakarta')
  ) at time zone 'Asia/Jakarta';

  -- MRR: harga tier dikalikan jumlah tenant aktif pada tier itu.
  select coalesce(sum(
           (p.value -> t.tier_plan::text ->> 'price')::numeric
         ), 0)
    into v_mrr
    from public.tenants t
    cross join (
      select value from public.platform_settings where key = 'pricing'
    ) p
   where t.status = 'active';

  select (value ->> 'monthly_idr')::numeric
    into v_biaya
    from public.platform_settings
   where key = 'infra_cost';

  return json_build_object(
    'standar_active', (
      select count(*) from public.tenants
       where tier_plan = 'standar' and status = 'active'
    ),
    'pro_active', (
      select count(*) from public.tenants
       where tier_plan = 'pro' and status = 'active'
    ),

    -- ⚠️ Di luar daftar Bab 11.1, ditambahkan dengan sengaja. Tanpa angka
    -- ini dasbor menulis "1 pelanggan" sementara ada belasan tenant uji coba
    -- yang sedang memakai server — gambaran yang menyesatkan justru bagi
    -- orang yang memutuskan kapan menambah kapasitas.
    'trial_count', (
      select count(*) from public.tenants where status = 'trial'
    ),
    'suspended_count', (
      select count(*) from public.tenants
       where status in ('suspended', 'expired')
    ),

    'new_this_month', (
      select count(*) from public.tenants where created_at >= v_awal_bulan
    ),

    'mrr', v_mrr,
    'infra_cost', v_biaya,
    -- NULL bila biayanya belum diisi. Lihat keputusan 3.
    'margin', case when v_biaya is null then null else v_mrr - v_biaya end,

    'total_videos', (select count(*) from public.package_videos),
    'storage_bytes', (
      select coalesce(sum(file_size_bytes), 0)
        from public.package_videos
       where status = 'uploaded'
    )
  );
end;
$$;

comment on function public.get_platform_stats() is
  'Bab 11.1 - angka ringkasan seluruh platform dalam satu panggilan. '
  'security definer: RLS TIDAK berlaku di dalamnya, dan pemeriksaan '
  'is_admin() di baris pertama adalah satu-satunya penjagaan. MRR dihitung '
  'dari harga tier aktif, bukan dari pembayaran yang masuk. Margin NULL bila '
  'platform_settings.infra_cost belum diisi.';

grant execute on function public.get_platform_stats() to authenticated;
revoke execute on function public.get_platform_stats() from anon, public;
