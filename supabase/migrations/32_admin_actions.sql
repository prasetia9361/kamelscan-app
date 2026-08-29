-- ============================================================
-- 32_admin_actions.sql  (Bab 11.2 & 11.7 — aksi Admin yang berjejak)
-- ============================================================
-- Lahir dari pengujian Product Owner 29 Agustus 2026 pada halaman Kelola
-- Pengguna yang baru terbit. Empat hal yang ditemukannya, dan seluruhnya
-- nyata:
--
--   1. Barisnya sendiri ikut terdaftar sebagai pelanggan. Benar menurut
--      skema — setiap akun yang mendaftar memperoleh satu tenant, dan akun
--      itu baru dinaikkan menjadi admin belakangan — tetapi membuat tulisan
--      "7 pelanggan" menjadi angka yang salah, dan tombol Tangguhkan di baris
--      itu mengenai tenantnya sendiri.
--
--   2. Tidak ada cara menambah token seorang pelanggan. Bab 11.2 memintanya
--      sejak awal; yang dibangun 29 Agustus hanya tiga aksi dari lima.
--
--   3. Ketiga aksi yang sudah ada TIDAK tercatat di `audit_logs`, padahal
--      Bab 11.2 menulis "Setiap aksi tercatat di audit_logs". Kelalaian.
--
--   4. Pembayaran yang ditolak tidak terlihat sama sekali oleh pelanggannya —
--      spanduk "menunggu" hilang dan tidak ada apa pun yang menggantikan.
--      Bab 11.7 meminta penolakan disertai **alasan**; kolomnya tidak pernah
--      ada.
--
-- 🔴 Seluruh fungsi di berkas ini `security definer` dan diawali `is_admin()`.
-- RLS tidak berlaku di dalamnya. Jangan pernah menghapus baris penjaga itu,
-- dan jangan pernah memindahkannya ke bawah query mana pun.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Alasan penolakan pembayaran (Bab 11.7)
-- ------------------------------------------------------------
-- Nullable dengan sengaja: baris yang ditolak sebelum hari ini memang tidak
-- punya alasan tercatat, dan mengarang isinya lebih buruk daripada kosong.
alter table public.subscriptions
  add column if not exists rejection_reason text;

comment on column public.subscriptions.rejection_reason is
  'Bab 11.7 - alasan Admin menolak pembayaran manual. Ditampilkan apa adanya '
  'kepada pelanggan di halaman Pembayaran, jadi isinya dibaca orang luar.';

-- ------------------------------------------------------------
-- 2. Jejak audit untuk SETIAP perubahan admin pada tenant (Bab 11.2)
-- ------------------------------------------------------------
-- 🔴 Dipasang sebagai TRIGGER, bukan ditambahkan ke masing-masing tombol.
--
-- Alasannya: `tenants_update_admin` (migrasi 14) membuat tabel ini hanya
-- dapat diubah oleh admin — lewat aplikasi, lewat SQL Editor, atau lewat cara
-- apa pun yang belum terpikirkan. Menempelkan pencatatan pada tiga tombol
-- hanya menjamin ketiga tombol itu; trigger menjamin **seluruh jalan masuk**.
-- Product Owner mengubah tier lewat SQL Editor lebih dari sekali pada Agustus
-- 2026, dan tidak satu pun tercatat.
--
-- ⚠️ Akibat yang harus disadari: menyetujui pembayaran menghasilkan DUA baris
-- audit — `subscription.activate` dari `activate_subscription()` (migrasi 28)
-- dan `tenant.admin_update` dari sini. Keduanya benar dan memandang kejadian
-- yang sama dari dua sisi. Buku audit boleh berulang; yang tidak boleh adalah
-- bolong.
create or replace function public.audit_tenant_admin_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ubah jsonb := '{}'::jsonb;
begin
  -- Hanya perubahan yang berarti. `updated_at` bergerak pada setiap
  -- penyimpanan (trigger `trg_touch_tenants`), dan mencatatnya berarti buku
  -- audit penuh oleh baris yang tidak menyebutkan apa-apa.
  if new.tier_plan is distinct from old.tier_plan then
    v_ubah := v_ubah || jsonb_build_object(
      'tier_plan', jsonb_build_object('dari', old.tier_plan, 'jadi', new.tier_plan));
  end if;

  if new.status is distinct from old.status then
    v_ubah := v_ubah || jsonb_build_object(
      'status', jsonb_build_object('dari', old.status, 'jadi', new.status));
  end if;

  if new.period_end is distinct from old.period_end then
    v_ubah := v_ubah || jsonb_build_object(
      'period_end', jsonb_build_object('dari', old.period_end, 'jadi', new.period_end));
  end if;

  if v_ubah = '{}'::jsonb then
    return new;
  end if;

  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  values (new.id, auth.uid(), 'tenant.admin_update', 'tenants', new.id, v_ubah);

  return new;
end;
$$;

drop trigger if exists trg_audit_tenant_admin_change on public.tenants;
create trigger trg_audit_tenant_admin_change
  after update on public.tenants
  for each row execute function public.audit_tenant_admin_change();

-- ------------------------------------------------------------
-- 3. Tabel Kelola Pengguna — kini menandai barisnya sendiri
-- ------------------------------------------------------------
-- Perubahan tunggal dari migrasi 31: kolom `owner_is_admin`. Barisnya TETAP
-- ditampilkan (keputusan Product Owner 29 Agustus 2026) — yang berubah hanya
-- bahwa layar sekarang dapat menandainya dan mematikan tombol aksinya.
--
-- Menyembunyikannya sempat disarankan dan ditolak, dengan alasan yang masuk
-- akal: baris yang hilang tanpa penjelasan membuat orang mencari-cari, dan
-- akun admin ini juga tetap punya toko dan video sungguhan yang perlu
-- terlihat.
create or replace function public.admin_list_tenants(p_limit integer default 200)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hasil json;
begin
  -- 🔴 BARIS PENJAGA.
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

          -- 🔴 Akhir periode DOMPET, bukan akhir periode langganan. Keduanya
          -- berbeda dan yang menyamakannya akan menampilkan tanggal yang
          -- salah: cron `reset-monthly-tokens` (migrasi 16) menyetel
          -- `token_wallets.period_end = now() + 30 hari` pada setiap reset,
          -- sementara `tenants.period_end` hanya bergerak saat membayar atau
          -- saat Admin memperpanjang. Sesudah bulan pertama keduanya sudah
          -- tidak lagi sama.
          --
          -- Dipakai layar untuk mengatakan kapan token bonus akan hangus.
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
  'dan saldo token. owner_is_admin menandai tenant milik akun admin sendiri. '
  'security definer: RLS TIDAK berlaku, is_admin() adalah satu-satunya '
  'penjagaan.';

grant execute on function public.admin_list_tenants(integer) to authenticated;
revoke execute on function public.admin_list_tenants(integer) from anon, public;

-- ------------------------------------------------------------
-- 4. Tambah / kurangi token satu pelanggan (Bab 11.2)
-- ------------------------------------------------------------
-- ⚠️ BONUS INI HANGUS PADA RESET PERIODE BERIKUTNYA, dan itu bukan cacat.
--
-- Cron `reset-monthly-tokens` (migrasi 16) menjalankan `balance =
-- monthly_quota` tiap awal periode; token tambahan apa pun ikut terhapus di
-- situ. Itu Bab 7.2 poin 3 apa adanya: sisa token TIDAK diakumulasi.
--
-- Keputusan Product Owner 29 Agustus 2026: bonus memang hanya berlaku sampai
-- akhir periode berjalan. Yang menaikkan `monthly_quota` supaya bonusnya
-- berulang tiap bulan adalah keputusan lain yang belum pernah diambil —
-- jangan menambahkannya diam-diam.
--
-- ⚠️ Untuk tenant uji coba akibatnya terbalik: `period_end`-nya NULL sehingga
-- cron tidak pernah menyentuhnya, dan bonusnya bertahan selamanya.
create or replace function public.admin_adjust_tokens(
  p_tenant_id uuid,
  p_delta     integer,
  p_reason    text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lama    integer;
  v_baru    integer;
  v_alasan  text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'admin_adjust_tokens() hanya untuk peran admin.';
  end if;

  -- Bab 11.2: "dengan alasan wajib". Ditegakkan di server, bukan hanya di
  -- formulir — buku besar token adalah satu-satunya alat menyelesaikan
  -- sengketa, dan baris tanpa alasan tidak menyelesaikan apa pun.
  if v_alasan is null then
    raise exception 'REASON_REQUIRED'
      using errcode = '22023',
            hint = 'Alasan penyesuaian token wajib diisi (Bab 11.2).';
  end if;

  if p_delta = 0 then
    raise exception 'DELTA_ZERO'
      using errcode = '22023',
            hint = 'Jumlah token yang ditambah atau dikurangi tidak boleh nol.';
  end if;

  -- `for update` mengunci dompet selama perubahan. Tanpa itu, penyesuaian
  -- admin dan pemotongan token oleh unggahan yang sedang berjalan dapat
  -- saling menimpa (Bab 7.3, kondisi balapan).
  select balance into v_lama
    from public.token_wallets
   where tenant_id = p_tenant_id
     for update;

  if v_lama is null then
    raise exception 'WALLET_MISSING'
      using errcode = '22023',
            hint = 'Pelanggan ini belum punya dompet token. Periksa datanya '
                   'lebih dulu, jangan dibuatkan dari sini.';
  end if;

  -- Saldo tidak boleh negatif (`chk_balance_non_negative`). Bila pengurangan
  -- melebihi saldo, yang tercatat di buku besar adalah selisih yang BENAR-
  -- BENAR terjadi, bukan angka yang diminta — mengikuti pola `greatest(...)`
  -- pada pemakaian token (Bab 7.3 baris terakhir).
  v_baru := greatest(v_lama + p_delta, 0);

  update public.token_wallets
     set balance = v_baru, updated_at = now()
   where tenant_id = p_tenant_id;

  insert into public.token_ledger
        (tenant_id, delta, reason, balance_after, note)
  values (p_tenant_id, v_baru - v_lama, 'admin_adjust', v_baru, v_alasan);

  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  values (
    p_tenant_id, auth.uid(), 'tenant.token_adjust', 'token_wallets', p_tenant_id,
    jsonb_build_object(
      'delta_diminta',  p_delta,
      'delta_terjadi',  v_baru - v_lama,
      'saldo_sebelum',  v_lama,
      'saldo_sesudah',  v_baru,
      'alasan',         v_alasan
    )
  );

  return v_baru;
end;
$$;

comment on function public.admin_adjust_tokens(uuid, integer, text) is
  'Bab 11.2 - tambah/kurangi token satu pelanggan, alasan wajib, tercatat di '
  'token_ledger (admin_adjust) dan audit_logs. Bonus hangus pada reset '
  'periode berikutnya (Bab 7.2 poin 3).';

grant execute on function public.admin_adjust_tokens(uuid, integer, text) to authenticated;
revoke execute on function public.admin_adjust_tokens(uuid, integer, text) from anon, public;

-- ------------------------------------------------------------
-- 5. Pemberian token serentak ke seluruh pelanggan aktif
-- ------------------------------------------------------------
-- Untuk pemberian bertema — "81 token untuk HUT RI ke-81". Diminta Product
-- Owner 29 Agustus 2026.
--
-- 🔴 HANYA MENAMBAH. `p_delta` wajib positif, dan itu bukan kehati-hatian
-- berlebihan: satu tombol yang mengurangi token seluruh pelanggan sekaligus
-- tidak punya kegunaan yang sepadan dengan akibat salah tekannya. Pengurangan
-- tetap bisa dilakukan satu per satu lewat `admin_adjust_tokens`, tempat nama
-- pelanggannya terbaca sebelum ditekan.
--
-- 🔴 HANYA yang berstatus `active`. Keputusan Product Owner 29 Agustus 2026.
-- Uji coba sengaja tidak ikut: kuotanya 100 sekali seumur akun (Bab 7.5), dan
-- menambahinya sama dengan memperpanjang masa gratis. Yang ditangguhkan juga
-- tidak — tokennya bertambah tetapi mereka tetap tidak dapat merekam
-- (Bab 7.6), jadi yang terjadi hanya angka yang berubah tanpa akibat.
--
-- Mengembalikan DUA angka: berapa yang menjadi sasaran, dan berapa yang
-- benar-benar berubah. Keduanya biasanya sama; bedanya muncul bila ada tenant
-- aktif yang dompetnya hilang. Layar wajib menampilkan selisihnya — angka
-- tunggal akan menyembunyikan kejanggalan yang justru perlu diselidiki.
create or replace function public.admin_grant_tokens_all(
  p_delta  integer,
  p_reason text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alasan  text := nullif(btrim(coalesce(p_reason, '')), '');
  v_sasaran integer;
  v_berhasil integer := 0;
  v_baris   record;
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'admin_grant_tokens_all() hanya untuk peran admin.';
  end if;

  if v_alasan is null then
    raise exception 'REASON_REQUIRED'
      using errcode = '22023',
            hint = 'Alasan pemberian token wajib diisi (Bab 11.2).';
  end if;

  if p_delta is null or p_delta <= 0 then
    raise exception 'DELTA_NOT_POSITIVE'
      using errcode = '22023',
            hint = 'Pemberian serentak hanya boleh menambah token.';
  end if;

  select count(*) into v_sasaran
    from public.tenants where status = 'active';

  for v_baris in
    select w.tenant_id, w.balance
      from public.token_wallets w
      join public.tenants t on t.id = w.tenant_id
     where t.status = 'active'
     order by w.tenant_id
       for update of w
  loop
    update public.token_wallets
       set balance = v_baris.balance + p_delta, updated_at = now()
     where tenant_id = v_baris.tenant_id;

    insert into public.token_ledger
          (tenant_id, delta, reason, balance_after, note)
    values (v_baris.tenant_id, p_delta, 'admin_adjust',
            v_baris.balance + p_delta, v_alasan);

    insert into public.audit_logs
          (tenant_id, actor_id, action, entity, entity_id, metadata)
    values (
      v_baris.tenant_id, auth.uid(), 'tenant.token_grant_all',
      'token_wallets', v_baris.tenant_id,
      jsonb_build_object(
        'delta',         p_delta,
        'saldo_sebelum', v_baris.balance,
        'saldo_sesudah', v_baris.balance + p_delta,
        'alasan',        v_alasan
      )
    );

    v_berhasil := v_berhasil + 1;
  end loop;

  return json_build_object('target', v_sasaran, 'granted', v_berhasil);
end;
$$;

comment on function public.admin_grant_tokens_all(integer, text) is
  'Bab 11.2 - pemberian token serentak ke seluruh pelanggan berstatus active. '
  'Hanya menambah, alasan wajib, tercatat di token_ledger dan audit_logs. '
  'Mengembalikan {target, granted}.';

grant execute on function public.admin_grant_tokens_all(integer, text) to authenticated;
revoke execute on function public.admin_grant_tokens_all(integer, text) from anon, public;

-- ------------------------------------------------------------
-- 6. Menolak pembayaran, dengan alasan (Bab 11.7)
-- ------------------------------------------------------------
-- Sampai hari ini penolakan hanya mengubah status menjadi `failed` dari
-- aplikasi. Akibatnya di layar PELANGGAN: spanduk "menunggu verifikasi"
-- lenyap dan tidak ada apa pun yang menggantikannya — tagihannya seolah
-- menguap. Ditemukan Product Owner 29 Agustus 2026 saat menguji tombol Tolak
-- pada baris sungguhan.
--
-- 🔴 Alasannya WAJIB, dan alasannya dibaca PELANGGAN apa adanya di halaman
-- Pembayaran. Ia bukan catatan internal — jangan menulis singkatan yang hanya
-- dimengerti Admin. Layar yang memanggil fungsi ini wajib mengatakan hal itu
-- kepada Admin sebelum ia mengetik.
--
-- ⚠️ Yang TIDAK dilakukan fungsi ini, dan tetap urusan manusia: uang yang
-- terlanjur masuk tidak dikembalikan, dan tidak ada pemberitahuan yang dikirim
-- ke mana pun. Yang berubah hanyalah bahwa penolakannya kini **terlihat** oleh
-- pelanggan saat ia membuka halaman Pembayaran.
create or replace function public.admin_reject_payment(
  p_subscription_id uuid,
  p_reason          text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alasan text := nullif(btrim(coalesce(p_reason, '')), '');
  v_tenant uuid;
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'admin_reject_payment() hanya untuk peran admin.';
  end if;

  if v_alasan is null then
    raise exception 'REASON_REQUIRED'
      using errcode = '22023',
            hint = 'Alasan penolakan wajib diisi dan akan dibaca pelanggan '
                   '(Bab 11.7).';
  end if;

  -- 🔴 Hanya baris yang masih `pending`. Menolak baris yang sudah `paid`
  -- akan menurunkan statusnya tanpa mengembalikan tier, token, maupun periode
  -- yang sudah terlanjur diberikan trigger aktivasi — pelanggan tetap Pro
  -- sementara tagihannya tertulis gagal, dan tidak ada yang menyadarinya.
  update public.subscriptions
     set status = 'failed', rejection_reason = v_alasan
   where id = p_subscription_id
     and status = 'pending'
  returning tenant_id into v_tenant;

  if v_tenant is null then
    raise exception 'NOT_PENDING'
      using errcode = '22023',
            hint = 'Pembayaran ini sudah tidak berstatus menunggu. Muat ulang '
                   'daftarnya sebelum menolak.';
  end if;

  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  values (
    v_tenant, auth.uid(), 'subscription.reject', 'subscriptions',
    p_subscription_id, jsonb_build_object('alasan', v_alasan)
  );
end;
$$;

comment on function public.admin_reject_payment(uuid, text) is
  'Bab 11.7 - menolak pembayaran manual dengan alasan yang dibaca pelanggan. '
  'Hanya berlaku pada baris berstatus pending. Tercatat di audit_logs. Tidak '
  'mengembalikan uang dan tidak mengirim pemberitahuan apa pun.';

grant execute on function public.admin_reject_payment(uuid, text) to authenticated;
revoke execute on function public.admin_reject_payment(uuid, text) from anon, public;
