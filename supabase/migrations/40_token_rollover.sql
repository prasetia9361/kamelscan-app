-- ============================================================
-- 40_token_rollover.sql  (Bab 7.2 poin 3–5, direvisi 31 Agustus 2026)
-- ============================================================
-- Model token berubah dari **kuota bulanan** menjadi **akumulatif (rollover)**.
--
--   Lama : tiap awal periode saldo direset ke `monthly_quota`; sisa hangus.
--   Baru : token pembelian DITAMBAHKAN ke saldo; sisa hari DITAMBAHKAN ke
--          periode; `tier_plan` mengikuti pembelian TERAKHIR, dua arah.
--          Token hidup selama langganannya hidup, dan hangus bersamanya.
--
-- 🔴 Migrasi 39 WAJIB dijalankan lebih dulu. Berkas ini memakai nilai enum
--    'bisnis' dan 'token_expired' yang ditambahkan di sana, dan PostgreSQL
--    menolak memakai nilai enum baru di transaksi yang sama dengan
--    penambahannya.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Cabut pengisian ulang bulanan
-- ------------------------------------------------------------
-- 🔴 INI LANGKAH YANG PALING MUDAH TERLUPA, DAN YANG PALING MAHAL BILA LUPA.
--
--    `reset-monthly-tokens` menjalankan `balance = monthly_quota` setiap awal
--    periode. Selama ia masih hidup, seluruh akumulasi yang dibangun berkas
--    ini akan **ditimpa setiap 30 hari** — tanpa satu pun galat, tanpa satu
--    pun baris buku besar, dan tanpa seorang pun tahu sampai ada pelanggan
--    yang menghitung tokennya sendiri.
--
-- ⚠️ Job ini praktis tidak pernah bekerja sejak awal: ia mensyaratkan tenant
--    berstatus `active`, sedangkan KamelScan menjual periode 30 hari sekali
--    beli tanpa penagihan berulang — tenant yang tidak membeli lagi sudah
--    berstatus `expired` sebelum jobnya sempat menyala. Itu sebabnya tidak ada
--    yang menyadari keberadaannya selama ini.
do $mig$
begin
  perform cron.unschedule('reset-monthly-tokens');
exception
  when others then
    -- Belum pernah terpasang, atau sudah dicabut. Keduanya keadaan yang benar.
    raise notice 'reset-monthly-tokens tidak ada / sudah dicabut';
end
$mig$;


-- ------------------------------------------------------------
-- 2. Aktivasi pembayaran — rollover
-- ------------------------------------------------------------
create or replace function public.activate_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tokens     int;
  v_saldo_lama int;
  v_saldo_baru int;
  v_mulai      timestamptz;
  v_akhir      timestamptz;
  v_akhir_lama timestamptz;
  v_mulai_lama timestamptz;
begin
  -- Hanya pada PERPINDAHAN menjadi 'paid'. Menyimpan ulang baris yang sudah
  -- lunas tidak boleh mengisi ulang dompet — itu jalan pintas menuju token
  -- gratis tanpa batas bagi siapa pun yang dapat menyentuh barisnya.
  if new.status <> 'paid' or old.status is not distinct from 'paid' then
    return new;
  end if;

  -- ---- Kuota paket yang dibeli ----
  select (value -> new.plan::text ->> 'monthly_tokens')::int
    into v_tokens
    from public.platform_settings
   where key = 'pricing';

  if v_tokens is null or v_tokens <= 0 then
    raise exception 'PRICING_MISSING_FOR_PLAN'
      using errcode = '22023',
            hint = format(
              'platform_settings.pricing tidak memuat monthly_tokens untuk paket %s. '
              'Perbaiki pengaturannya lebih dulu, lalu setujui ulang pembayarannya.',
              new.plan
            );
  end if;

  -- ---- Periode: SISA HARI DITAMBAHKAN ----
  --
  -- 🔴 Berubah dari perilaku lama, yang me-reset periode ke 30 hari dari
  --    sekarang dan menghanguskan sisa hari yang sudah dibayar. Bab 7.2 poin 4.
  --
  -- `greatest(..., now())` menangani langganan yang SUDAH lewat: sisa harinya
  -- negatif, dan menambahkan angka negatif akan memberi periode lebih pendek
  -- dari 30 hari kepada orang yang baru saja membayar penuh.
  select t.period_start, t.period_end
    into v_mulai_lama, v_akhir_lama
    from public.tenants t
   where t.id = new.tenant_id
     for update;

  v_akhir := greatest(coalesce(v_akhir_lama, now()), now()) + interval '30 days';

  -- Perpanjangan melanjutkan periode yang sedang berjalan, jadi tanggal
  -- mulainya tidak digeser. Pembelian sesudah langganan mati memulai periode
  -- baru dari hari ini.
  v_mulai := case
               when v_akhir_lama > now() then coalesce(v_mulai_lama, now())
               else now()
             end;

  new.paid_at      := coalesce(new.paid_at, now());
  new.period_start := v_mulai;
  new.period_end   := v_akhir;

  -- ---- Tenant ----
  -- `tier_plan` mengikuti pembelian TERAKHIR, dua arah. Membeli paket yang
  -- lebih rendah memang menurunkan tier — termasuk durasi maksimal rekamnya.
  -- Peringatannya adalah tanggung jawab layar checkout (Bab 12.4).
  update public.tenants
     set tier_plan    = new.plan,
         status       = 'active',
         period_start = v_mulai,
         period_end   = v_akhir,
         updated_at   = now()
   where id = new.tenant_id;

  -- ---- Dompet token: DITAMBAHKAN, bukan diganti ----
  select balance into v_saldo_lama
    from public.token_wallets
   where tenant_id = new.tenant_id
     for update;

  v_saldo_baru := coalesce(v_saldo_lama, 0) + v_tokens;

  -- ⚠️ `monthly_quota` tidak lagi dipakai untuk mengisi ulang apa pun — cron-
  -- nya sudah dicabut di bagian 1. Ia tetap diperbarui sebagai catatan kuota
  -- nominal paket yang sedang berlaku, dan dibaca layar untuk menampilkan
  -- "x dari y". Jangan menghidupkan kembali pemakaiannya sebagai sumber
  -- pengisian ulang.
  insert into public.token_wallets
        (tenant_id, balance, monthly_quota, period_start, period_end)
  values (new.tenant_id, v_saldo_baru, v_tokens, v_mulai, v_akhir)
  on conflict (tenant_id) do update
     set balance       = excluded.balance,
         monthly_quota = excluded.monthly_quota,
         period_start  = excluded.period_start,
         period_end    = excluded.period_end,
         updated_at    = now();

  -- ---- Buku besar ----
  -- Deltanya kini SELALU positif dan selalu sama dengan kuota paket yang
  -- dibeli. Itu bukan kebetulan — itulah yang membuat rollover dapat
  -- dijelaskan kepada pelanggan baris demi baris.
  insert into public.token_ledger
        (tenant_id, delta, reason, balance_after, note)
  values (
    new.tenant_id,
    v_tokens,
    'plan_upgrade',
    v_saldo_baru,
    format('Beli paket %s · +%s token · langganan %s',
           new.plan, v_tokens, new.id)
  );

  -- ---- Jejak audit ----
  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  values (
    new.tenant_id,
    new.verified_by,
    'subscription.activate',
    'subscriptions',
    new.id,
    jsonb_build_object(
      'plan',           new.plan,
      'amount',         new.amount,
      'payment_method', new.payment_method,
      'saldo_sebelum',  coalesce(v_saldo_lama, 0),
      'saldo_sesudah',  v_saldo_baru,
      'token_ditambah', v_tokens,
      'period_start',   v_mulai,
      'period_end',     v_akhir
    )
  );

  return new;
end;
$$;

comment on function public.activate_subscription() is
  'Bab 7.2 poin 3-5 - saat subscriptions.status menjadi paid: token DITAMBAHKAN '
  '(rollover), sisa hari DITAMBAHKAN, tier mengikuti pembelian terakhir. '
  'Direvisi 31 Agustus 2026; sebelumnya saldo diganti dan periode di-reset.';


-- ------------------------------------------------------------
-- 3. Token hangus saat langganan berakhir
-- ------------------------------------------------------------
-- Keputusan Product Owner 31 Agustus 2026 (pilihan B): token hidup selama
-- langganannya hidup. Kalimat yang harus dapat diucapkan ke pelanggan hanya
-- satu, tanpa pengecualian: *"token Anda hangus kalau langganan berhenti"*.
--
-- 🔴 Tanpa fungsi ini rollover menjadi selamanya. Pelanggan yang berhenti
--    setahun lalu dapat kembali, membeli paket termurah, dan menemukan
--    tokennya masih utuh — dan tidak ada dasar untuk menolaknya, karena tidak
--    pernah ada satu baris pun yang menghanguskannya.
create or replace function public.expire_tenant_tokens()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jumlah integer := 0;
begin
  -- Buku besar ditulis LEBIH DULU, selagi saldonya masih terbaca. Sesudah
  -- saldonya nol, jumlah yang hangus tidak dapat direkonstruksi dari mana pun
  -- — dan itulah satu-satunya angka yang akan ditanyakan pelanggan.
  insert into public.token_ledger
        (tenant_id, delta, reason, balance_after, note)
  select w.tenant_id, -w.balance, 'token_expired', 0,
         format('Langganan berakhir %s - %s token hangus',
                to_char(t.period_end, 'YYYY-MM-DD'), w.balance)
    from public.token_wallets w
    join public.tenants t on t.id = w.tenant_id
   where t.status = 'expired'
     and w.balance > 0;

  get diagnostics v_jumlah = row_count;

  update public.token_wallets w
     set balance    = 0,
         updated_at = now()
    from public.tenants t
   where t.id = w.tenant_id
     and t.status = 'expired'
     and w.balance > 0;

  return v_jumlah;
end;
$$;

revoke execute on function public.expire_tenant_tokens()
  from public, anon, authenticated;


-- ------------------------------------------------------------
-- 4. Cron
-- ------------------------------------------------------------
do $mig$
begin
  -- ⚠️ URUTANNYA MENGIKAT. `expire-tenants` (01:30, migrasi 16) yang menyetel
  -- status menjadi `expired`; fungsi di bawah membaca status itu. Menjalankan
  -- penghangusan token lebih dulu berarti ia tidak menemukan satu pun tenant
  -- yang baru berakhir malam itu, dan tokennya baru hangus sehari kemudian.
  perform cron.schedule('expire-tenant-tokens', '45 1 * * *', $job$
    select public.expire_tenant_tokens();
  $job$);
end
$mig$;


-- ------------------------------------------------------------
-- 5. Ubah Paket milik Admin tidak lagi menyentuh saldo
-- ------------------------------------------------------------
-- Keputusan Product Owner 31 Agustus 2026 (Bab 7.2 poin 7).
--
-- Versi lama (migrasi 35) mengisi saldo penuh ke kuota tier baru. Itu benar
-- untuk model kuota bulanan, dan salah untuk rollover: menaikkan paket
-- pelanggan akan **memotong** token yang sudah ia kumpulkan bila kuota tier
-- barunya lebih kecil dari saldonya — Admin menekan tombol yang berbunyi
-- "Ubah Paket" dan yang terjadi adalah token pelanggan berkurang.
--
-- Token datang dari pembelian. Admin sudah punya `admin_adjust_tokens()`
-- untuk menambah atau mengurangi token, dan memisahkan keduanya berarti satu
-- tombol menghasilkan tepat satu akibat.
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
  v_tier_lama tier_plan;
  v_nama      text;
  v_kuota     integer;
begin
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
      using errcode = '22023', hint = 'Pelanggan ini tidak ditemukan.';
  end if;

  if v_tier_lama = p_plan then
    return format('Tidak ada yang diubah - %s memang sudah paket %s.',
                  v_nama, p_plan);
  end if;

  select (value -> p_plan::text ->> 'monthly_tokens')::int
    into v_kuota
    from public.platform_settings
   where key = 'pricing';

  if v_kuota is null or v_kuota <= 0 then
    raise exception 'PRICING_MISSING_FOR_PLAN'
      using errcode = '22023',
            hint = format(
              'platform_settings.pricing tidak memuat monthly_tokens untuk '
              'paket %s. Perbaiki di Admin > Harga & Paket lebih dulu.', p_plan);
  end if;

  -- `status` sengaja tidak disentuh (keputusan lama, tetap berlaku):
  -- mengubah paket pelanggan yang ditangguhkan tidak boleh diam-diam
  -- mencabut penangguhannya.
  update public.tenants
     set tier_plan = p_plan, updated_at = now()
   where id = p_tenant_id;

  -- ⚠️ `monthly_quota` diperbarui, `balance` TIDAK. Lihat kepala bagian ini.
  update public.token_wallets
     set monthly_quota = v_kuota, updated_at = now()
   where tenant_id = p_tenant_id;

  return format(
    'BERHASIL - %s kini paket %s. Saldo tokennya TIDAK diubah; pakai tombol '
    'Sesuaikan Token bila memang perlu. Suruh ia keluar lalu masuk lagi; tier '
    'dibawa di dalam token login.', v_nama, p_plan);
end;
$$;

comment on function public.admin_change_tier(uuid, tier_plan) is
  'Bab 7.2 poin 7 - mengubah tier dan monthly_quota saja. Saldo token TIDAK '
  'disentuh sejak 31 Agustus 2026: token datang dari pembelian, dan Admin '
  'punya admin_adjust_tokens() tersendiri.';

grant execute on function public.admin_change_tier(uuid, tier_plan) to authenticated;
revoke execute on function public.admin_change_tier(uuid, tier_plan) from anon, public;
