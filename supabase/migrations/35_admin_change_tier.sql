-- ============================================================
-- 35_admin_change_tier.sql  (Bab 7.2 poin 4 & 5)
-- ============================================================
-- Tombol **Ubah Paket** di Admin > Kelola Pengguna hanya mengubah kolom
-- `tenants.tier_plan`. Dompet tokennya tidak pernah disentuh, dan tidak ada
-- trigger apa pun yang bereaksi terhadap perubahan tier — penyesuaian token
-- selama ini hanya terjadi lewat `activate_subscription()` (migrasi 28), yang
-- dipicu pembayaran.
--
-- Bab 7.2 poin 4 memerintahkannya sejak awal:
--   "Saat upgrade tier, saldo langsung disesuaikan ke kuota tier baru dan
--    dicatat di token_ledger dengan alasan plan_upgrade."
--
-- 🔴 Akibat yang paling mahal bukan saldo hari ini, melainkan `monthly_quota`.
--    Cron `reset-monthly-tokens` (migrasi 16) menjalankan
--    `balance = monthly_quota` setiap awal periode. Selama `monthly_quota`
--    tidak ikut berubah, pelanggan yang dinaikkan ke Pro akan **selamanya**
--    kembali ke 1.000 token setiap bulan, bukan 5.000 — dan tidak ada satu
--    pun galat yang muncul. Ia hanya tampak seperti pelanggan yang boros.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 KENAPA FUNGSI, BUKAN TRIGGER PADA `tenants`
-- ------------------------------------------------------------
-- Migrasi 32 dan 34 keduanya memakai trigger, dan pilihan itu benar di sana.
-- Di sini justru berbahaya.
--
-- `activate_subscription()` mengubah `tenants.tier_plan` LEBIH DULU, baru
-- kemudian mengurus dompet dan buku besarnya sendiri (migrasi 28, baris 116
-- dan 133). Sebuah trigger pada perubahan tier akan menyala **di tengah**
-- proses itu, lalu menulis baris `token_ledger` kedua untuk satu kejadian yang
-- sama — dan deltanya dihitung dari saldo yang sedetik kemudian ditimpa.
--
-- Buku besar token adalah satu-satunya alat menyelesaikan sengketa dengan
-- pelanggan (Bab 7.2 poin 5). Baris ganda dengan angka yang saling
-- bertentangan justru menghancurkan gunanya.
--
-- Fungsi ini karena itu dipanggil **hanya** oleh tombol Ubah Paket. Jalur
-- pembayaran tidak menyentuhnya sama sekali.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 🔴 DUA KEPUTUSAN, dan alasan masing-masing
-- ------------------------------------------------------------
--
-- 1. SALDO DIISI PENUH kuota paket baru, bukan dihitung proporsional.
--
--    Bab 7.2 poin 4 menulis "secara proporsional", tetapi
--    `activate_subscription()` yang sudah berjalan di produksi mengisinya
--    penuh. Dua aturan berbeda untuk hal yang sama sudah terlanjur tertulis.
--
--    Keputusan Product Owner 30 Agustus 2026: **ikuti yang sudah berjalan.**
--    Dengan begitu hanya ada SATU aturan token di seluruh sistem, dan itu yang
--    dapat dijelaskan kepada pelanggan yang bertanya kenapa angkanya sekian.
--
--    ⚠️ Konsekuensinya disadari dan diterima: menurunkan paket dapat memotong
--    sisa token yang belum terpakai, dan menaikkan di tengah bulan memberi
--    kuota sebulan penuh. Keduanya sama persis dengan yang sudah terjadi pada
--    pembayaran sungguhan sejak 26 Agustus 2026.
--
-- 2. STATUS TENANT TIDAK IKUT DIUBAH.
--
--    Kode lama menyetel `status = 'active'` setiap kali tier diubah — artinya
--    mengubah paket pelanggan yang sedang **ditangguhkan** diam-diam mencabut
--    penangguhannya. Tidak ada satu pun kalimat di layar yang mengatakannya.
--
--    Penangguhan datang dari alasan di luar pembayaran, dan mencabutnya adalah
--    keputusan tersendiri yang sudah punya tombolnya sendiri. Aturan yang sama
--    persis sudah disepakati untuk Perpanjang Periode (P.5) — di sana
--    `suspended` juga sengaja tidak ikut diaktifkan.
-- ------------------------------------------------------------

create or replace function public.admin_change_tier(
  p_tenant_id uuid,
  p_plan      tier_plan
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier_lama  tier_plan;
  v_nama       text;
  v_kuota      integer;
  v_saldo_lama integer;
begin
  -- 🔴 BARIS PENJAGA. `security definer` mematikan RLS, dan fungsi ini menulis
  -- ke `token_wallets` serta `token_ledger` — dua tabel yang sengaja tidak
  -- punya policy tulis dari aplikasi sama sekali (migrasi 14).
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'admin_change_tier() hanya untuk peran admin.';
  end if;

  select t.tier_plan, coalesce(t.business_name, u.email::text)
    into v_tier_lama, v_nama
    from public.tenants t
    left join public.users u on u.id = t.owner_id
   where t.id = p_tenant_id;

  if v_tier_lama is null then
    raise exception 'TENANT_NOT_FOUND'
      using errcode = '22023',
            hint = 'Pelanggan ini tidak ditemukan.';
  end if;

  if v_tier_lama = p_plan then
    return format('Tidak ada yang diubah - %s memang sudah paket %s.',
                  v_nama, p_plan);
  end if;

  -- ---- Kuota paket tujuan ----
  select (value -> p_plan::text ->> 'monthly_tokens')::int
    into v_kuota
    from public.platform_settings
   where key = 'pricing';

  -- Menolak lebih baik daripada menebak. Kuota nol akan membuat pelanggan
  -- tidak dapat merekam satu video pun, tanpa satu pun pesan yang menjelaskan
  -- kenapa -- pola yang sama dengan migrasi 28.
  if v_kuota is null or v_kuota <= 0 then
    raise exception 'PRICING_MISSING_FOR_PLAN'
      using errcode = '22023',
            hint = format(
              'platform_settings.pricing tidak memuat monthly_tokens untuk '
              'paket %s. Perbaiki di Admin > Harga & Paket lebih dulu.',
              p_plan);
  end if;

  -- ---- Tenant ----
  --
  -- `status` sengaja TIDAK disentuh. Lihat keputusan 2 di kepala berkas.
  -- Trigger `trg_audit_tenant_admin_change` (migrasi 32) mencatat perubahan
  -- ini ke `audit_logs` dengan sendirinya.
  update public.tenants
     set tier_plan  = p_plan,
         updated_at = now()
   where id = p_tenant_id;

  -- ---- Dompet token ----
  select balance into v_saldo_lama
    from public.token_wallets
   where tenant_id = p_tenant_id
     for update;

  -- `insert ... on conflict` mengikuti migrasi 28: tenant yang dompetnya
  -- hilang karena sebab apa pun tidak boleh menggagalkan perubahan paket.
  --
  -- ⚠️ `period_start`/`period_end` sengaja TIDAK disentuh. Keduanya milik
  -- siklus penagihan, bukan milik paket -- dan menyetelnya di sini akan
  -- memundurkan tanggal reset pelanggan setiap kali Admin mengubah paketnya.
  insert into public.token_wallets (tenant_id, balance, monthly_quota)
  values (p_tenant_id, v_kuota, v_kuota)
  on conflict (tenant_id) do update
     set balance       = v_kuota,
         monthly_quota = v_kuota,
         updated_at    = now();

  -- ---- Buku besar (Bab 7.2 poin 5) ----
  --
  -- `delta` boleh negatif: turun paket memang mengurangi saldo. Buku besar
  -- mencatat kenyataan, bukan kenyataan yang enak dibaca.
  insert into public.token_ledger
        (tenant_id, delta, reason, balance_after, note)
  values (
    p_tenant_id,
    v_kuota - coalesce(v_saldo_lama, 0),
    'plan_upgrade',
    v_kuota,
    format('Ubah paket %s -> %s oleh Admin', v_tier_lama, p_plan)
  );

  return format(
    'BERHASIL - %s kini paket %s, token %s -> %s. Suruh ia keluar lalu masuk '
    'lagi; tier dibawa di dalam token login.',
    v_nama, p_plan, coalesce(v_saldo_lama, 0), v_kuota);
end;
$$;

comment on function public.admin_change_tier(uuid, tier_plan) is
  'Bab 7.2 poin 4 - mengubah paket tenant BESERTA monthly_quota dan saldonya, '
  'dicatat di token_ledger sebagai plan_upgrade. Sengaja fungsi, bukan '
  'trigger: activate_subscription() juga mengubah tier_plan dan akan '
  'menghasilkan baris buku besar ganda. Status tenant tidak ikut diubah.';

grant execute on function public.admin_change_tier(uuid, tier_plan) to authenticated;
revoke execute on function public.admin_change_tier(uuid, tier_plan) from anon, public;

-- ------------------------------------------------------------
-- Menyelaraskan dompet yang sudah terlanjur salah
-- ------------------------------------------------------------
-- Setiap tenant yang tiernya pernah diubah lewat tombol Ubah Paket sejak
-- 29 Agustus 2026 masih membawa `monthly_quota` paket lamanya. Selama tidak
-- diperbaiki, reset bulanan berikutnya akan mengembalikannya ke angka yang
-- salah.
--
-- ⚠️ Hanya `monthly_quota` yang diselaraskan di sini, BUKAN `balance`.
-- Menyentuh saldo berjalan berarti mengubah angka yang mungkin sudah dilihat
-- dan dihitung pelanggan hari ini, tanpa ada yang menekan tombol apa pun.
-- Saldonya akan menyusul dengan sendirinya pada reset berikutnya.
update public.token_wallets w
   set monthly_quota = benar.kuota,
       updated_at    = now()
  from (
    select t.id as tenant_id,
           (p.value -> t.tier_plan::text ->> 'monthly_tokens')::int as kuota
      from public.tenants t
      cross join (
        select value from public.platform_settings where key = 'pricing'
      ) p
  ) benar
 where w.tenant_id = benar.tenant_id
   and benar.kuota is not null
   and benar.kuota > 0
   and w.monthly_quota is distinct from benar.kuota;
