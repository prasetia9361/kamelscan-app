-- ============================================================
-- 28_activate_subscription.sql  (Bab 7.2 poin 4 / Bab 12.2)
-- ============================================================
-- Langganan yang dibayar akhirnya BERLAKU.
--
-- 🔴 Sampai 26 Agustus 2026 tidak ada apa pun di server yang bereaksi ketika
-- `subscriptions.status` menjadi `'paid'`. Akibatnya:
--
--   * `AdminRepository.approvePayment()` sudah ada di Flutter, dan komentarnya
--     berbunyi *"penyesuaian tier, periode langganan, dan reset saldo token
--     dilakukan trigger di server"* — trigger yang tidak pernah dibuat.
--   * Product Owner melakukan **transfer uang sungguhan** 22 Agustus 2026,
--     mengunggah buktinya, dan layarnya berhenti di "Menunggu verifikasi".
--     Empat hari tanpa satu pun jalan untuk mengubahnya menjadi aktif.
--
-- Kegagalannya diam dan mahal sekaligus: menyetujui pembayaran akan mengubah
-- status menjadi `paid` tanpa keluhan apa pun, lalu **tidak terjadi apa-apa**.
-- Pelanggan sudah membayar dan tetap memakai jatah uji coba.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 EMPAT KEPUTUSAN, dan alasan masing-masing
-- ------------------------------------------------------------
--
-- 1. TRIGGER, BUKAN EDGE FUNCTION.
--
--    Rancangannya memang begitu sejak awal: `approvePayment()` hanyalah satu
--    `update` biasa ke tabel, dan komentarnya sudah menunjuk ke trigger.
--
--    Ada alasan yang lebih kuat daripada sekadar mengikuti rancangan lama:
--    trigger **tidak dapat dilewati**. Siapa pun yang mengubah status menjadi
--    `paid` — lewat aplikasi Admin, lewat SQL Editor, atau lewat perbaikan
--    darurat suatu malam — tetap menghasilkan tenant yang benar-benar aktif.
--    Edge Function hanya berlaku bagi yang memanggilnya, dan baris yang
--    diperbaiki dengan tangan akan melewatinya tanpa ada yang tahu.
--
-- 2. `before update`, BUKAN `after update`.
--
--    Barisnya sendiri ikut diisi (`period_start`, `period_end`, `paid_at`).
--    Pada `after`, mengisinya menuntut `update` kedua ke tabel yang sama —
--    yang memanggil trigger ini lagi. Pada `before`, cukup menyetel `new.*`
--    tanpa satu pun putaran tambahan.
--
--    ⚠️ Urutan terhadap `trg_guard_subscription_owner_update` (migrasi 25)
--    aman: PostgreSQL menjalankan trigger `before` menurut abjad, dan
--    `trg_activate_...` mendahului `trg_guard_...`. Penjaga itu kemudian
--    meloloskan Admin dan `service_role` lebih dulu daripada memeriksa kolom,
--    jadi perubahan yang dibuat di sini tidak akan dianggap pelanggaran.
--
-- 3. JUMLAH TOKEN DIBACA DARI `platform_settings`, TIDAK DITULIS MATI.
--
--    Bab 7.1: seluruh angka tier dibaca dari sana agar Admin dapat mengubah
--    harga dan kuota tanpa rilis aplikasi baru. Menyalin angkanya ke sini
--    berarti dua sumber kebenaran, dan yang satu akan menyimpang diam-diam.
--
-- 4. 🔴 PRICING YANG HILANG MEMBATALKAN SELURUHNYA, bukan diberi nol.
--
--    Ini yang paling penting di berkas ini. Bila `platform_settings.pricing`
--    tidak memuat paket yang dibeli, `coalesce(..., 0)` akan menghasilkan
--    dompet bersaldo **nol** — pelanggan yang baru saja membayar tidak dapat
--    merekam satu video pun, dan tidak ada satu pun pesan yang menjelaskan
--    kenapa. Lebih baik pembayarannya menolak disetujui dengan galat yang
--    jelas: uangnya sudah masuk, dan Admin masih dapat mencoba lagi setelah
--    memperbaiki pengaturannya.
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
  v_mulai      timestamptz := now();
  v_akhir      timestamptz := now() + interval '30 days';
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

  -- ---- Barisnya sendiri ----
  -- `paid_at` ikut diisi bila belum ada, supaya baris yang diaktifkan lewat
  -- SQL Editor tetap lengkap seperti yang lewat aplikasi Admin.
  new.paid_at      := coalesce(new.paid_at, v_mulai);
  new.period_start := v_mulai;
  new.period_end   := v_akhir;

  -- ---- Tenant ----
  -- ⚠️ Periode dihitung dari SEKARANG, bukan disambung dari sisa periode
  -- lama. Untuk uji coba (period_end NULL) ini satu-satunya yang masuk akal.
  -- Untuk perpanjangan yang dibayar lebih awal, pelanggan kehilangan sisa
  -- harinya — belum pernah terjadi karena belum ada pelanggan berbayar, dan
  -- Product Owner sudah diberi tahu 26 Agustus 2026. Jangan mengubahnya
  -- diam-diam: aturan perpanjangan adalah keputusan dagang, bukan teknis.
  update public.tenants
     set tier_plan    = new.plan,
         status       = 'active',
         period_start = v_mulai,
         period_end   = v_akhir,
         updated_at   = now()
   where id = new.tenant_id;

  -- ---- Dompet token ----
  select balance into v_saldo_lama
    from public.token_wallets
   where tenant_id = new.tenant_id
     for update;

  -- `insert ... on conflict` bukan kelebihan kehati-hatian: dompet dibuat
  -- trigger pendaftaran, dan tenant yang dompetnya hilang karena sebab apa pun
  -- tidak boleh gagal diaktifkan sesudah membayar.
  insert into public.token_wallets
        (tenant_id, balance, monthly_quota, period_start, period_end)
  values (new.tenant_id, v_tokens, v_tokens, v_mulai, v_akhir)
  on conflict (tenant_id) do update
     set balance       = excluded.balance,
         monthly_quota = excluded.monthly_quota,
         period_start  = excluded.period_start,
         period_end    = excluded.period_end,
         updated_at    = now();

  -- ---- Buku besar token (Bab 7.2 poin 5) ----
  -- `delta` boleh negatif — turun paket dari pro ke standar memang mengurangi
  -- saldo. Buku besar mencatat kenyataan, bukan kenyataan yang enak dibaca.
  insert into public.token_ledger
        (tenant_id, delta, reason, balance_after, note)
  values (
    new.tenant_id,
    v_tokens - coalesce(v_saldo_lama, 0),
    'plan_upgrade',
    v_tokens,
    format('Aktivasi paket %s · langganan %s', new.plan, new.id)
  );

  -- ---- Jejak audit ----
  -- Saldo sebelum dan sesudah ikut dicatat. Bila suatu hari ada sengketa
  -- soal token, buku besar menyebut selisihnya dan baris ini menyebut
  -- keadaannya — dua-duanya diperlukan untuk menyusun ulang kejadiannya.
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
      'saldo_sesudah',  v_tokens,
      'period_start',   v_mulai,
      'period_end',     v_akhir
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_activate_subscription on public.subscriptions;
create trigger trg_activate_subscription
  before update on public.subscriptions
  for each row
  execute function public.activate_subscription();

comment on function public.activate_subscription() is
  'Bab 7.2 poin 4 - saat subscriptions.status menjadi paid: tenant naik tier '
  'dan berstatus active, dompet token di-reset ke kuota paket, buku besar dan '
  'audit dicatat. Kuota dibaca dari platform_settings.pricing; paket yang '
  'tidak ada di sana MEMBATALKAN aktivasi, bukan diberi saldo nol.';
