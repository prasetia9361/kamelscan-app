-- ============================================================
-- 37_account_deletion.sql  (Bab 9.6 — Hapus Akun)
-- ============================================================
-- Owner dapat menghapus akunnya sendiri, dari dalam aplikasi, tanpa menghubungi
-- siapa pun.
--
-- 🔴 INI PENGHALANG RILIS APP STORE, bukan fitur kenyamanan. App Store Review
--    Guideline 5.1.1(v): aplikasi yang membuat akun WAJIB menyediakan cara
--    menghapusnya dari dalam aplikasi. "Hubungi kami lewat surel" ditolak.
--    Google Play menuntut hal yang sama sejak 2024. Tanpa berkas ini rilis
--    1 September tidak akan lolos review.
--
-- Bentuk yang disepakati Product Owner 31 Agustus 2026:
--   1. Akun **langsung tidak dapat dipakai** begitu permintaan masuk.
--   2. Datanya baru benar-benar dimusnahkan **7 hari** kemudian.
--   3. Selama 7 hari itu Owner boleh membatalkan.
--   4. Akun yang masih **trial** dihapus seketika, tanpa tenggang.
--
-- ⚠️ Tenggangnya 7 hari MATI, tidak mengikuti sisa masa langganan. Pelanggan
--    yang menghapus akun di hari pertama paket setahun tidak sedang meminta
--    akunnya dijaga 11 bulan lagi — ia sedang meminta pergi. Yang dijaga
--    tenggang ini hanya satu hal: penyesalan, dan penyesalan datang dalam
--    hitungan hari.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Antrean berkas R2
-- ------------------------------------------------------------
-- 🔴 Menghapus baris `package_videos` TIDAK menghapus berkas videonya di
--    Cloudflare R2. Postgres tidak tahu-menahu tentang R2, dan begitu barisnya
--    hilang, `storage_key`-nya hilang bersamanya — berkasnya menjadi sampah
--    yang tidak dapat ditemukan lagi oleh siapa pun, selamanya, dan tetap
--    ditagihkan setiap bulan.
--
--    Karena itu kuncinya DISALIN ke sini lebih dulu, baru barisnya dihapus.
--
-- Tabel ini sengaja dibuat untuk DUA pemakai sekaligus:
--   a. penghapusan akun (berkas ini), dan
--   b. `purge-expired-videos` — retensi 30 hari, yang comment migrasi 16
--      menjanjikannya tetapi belum pernah dibuat, sehingga sampai hari ini
--      TIDAK ADA satu pun berkas R2 yang pernah terhapus.
-- Keduanya butuh mesin yang sama persis; membangunnya dua kali berarti dua
-- tempat yang dapat rusak sendiri-sendiri.
create table if not exists public.storage_purge_queue (
  id            uuid primary key default gen_random_uuid(),

  -- 🔴 SENGAJA TANPA foreign key ke `tenants`.
  --    Dengan FK `on delete cascade`, menghapus tenant akan menghapus antrean
  --    penghapusan berkasnya di detik yang sama — persis pekerjaan yang belum
  --    sempat dikerjakan. Hanya untuk penelusuran, bukan untuk keterkaitan.
  tenant_id     uuid,

  storage_key   text not null,
  reason        text not null,                 -- 'account_deleted' | 'retention'

  queued_at     timestamptz not null default now(),
  purged_at     timestamptz,                   -- terisi = berkasnya sudah hilang
  attempts      integer not null default 0,
  last_error    text,

  unique (storage_key)
);

comment on table public.storage_purge_queue is
  'Kunci objek R2 yang menunggu dihapus. Diisi saat baris videonya dihapus '
  '(penghapusan akun) atau kedaluwarsa (retensi), dikuras Edge Function. '
  'Tanpa FK ke tenants dengan sengaja - lihat komentar di 37_account_deletion.sql.';

create index if not exists idx_purge_queue_belum
  on public.storage_purge_queue (queued_at)
  where purged_at is null;

-- Hanya service role (Edge Function) yang boleh menyentuhnya. Tidak ada satu
-- pun policy di bawah, jadi RLS menolak semua orang — termasuk Admin.
alter table public.storage_purge_queue enable row level security;


-- ------------------------------------------------------------
-- 2. Penanda di tenants
-- ------------------------------------------------------------
alter table public.tenants
  add column if not exists deletion_requested_at timestamptz,
  add column if not exists deletion_purge_after  timestamptz;

comment on column public.tenants.deletion_requested_at is
  'Terisi = Owner meminta akunnya dihapus. Akun langsung tidak dapat dipakai.';
comment on column public.tenants.deletion_purge_after is
  'Kapan datanya benar-benar dimusnahkan. Sebelum tanggal ini masih dapat dibatalkan.';

create index if not exists idx_tenants_purge_due
  on public.tenants (deletion_purge_after)
  where deletion_requested_at is not null;


-- ------------------------------------------------------------
-- 3. Memusnahkan satu tenant
-- ------------------------------------------------------------
-- 🔴 URUTANNYA BUKAN SELERA — tetapi alasannya bukan yang paling mudah
--    ditebak. Diukur langsung di database produksi, 31 Agustus 2026, dengan
--    tenant uji berisi satu toko dan dua video (satu di antaranya milik
--    packer). Dua percobaan, dua hasil yang berlawanan:
--
--      a. `delete from public.tenants where id = ...`   -> BERHASIL.
--         Cascade `package_videos.tenant_id` menghapus videonya lebih dulu,
--         sehingga saat giliran `users` tiba tidak ada lagi yang menunjuk.
--
--      b. `delete from auth.users where id = <packer>`  -> GAGAL, 23503:
--         "violates foreign key constraint package_videos_user_id_fkey".
--         Menghapus seorang pengguna TIDAK menghapus videonya — video terikat
--         pada tenant, bukan pada pembuatnya — jadi RESTRICT menggigit.
--
--    Fungsi ini menempuh jalur (b): ia menghapus di `auth.users` supaya akun
--    loginnya benar-benar hilang. Karena itulah videonya harus dihapus lebih
--    dulu dengan tangan.
--
--    ⚠️ Catatan untuk yang membaca nanti: versi pertama komentar ini menulis
--    bahwa jalur (a) yang gagal. Itu tebakan, dan tebakan itu salah. Yang
--    tertulis di atas adalah hasil pengukuran.
create or replace function public.purge_tenant(p_tenant_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_berkas integer := 0;
begin
  -- ---- a. Selamatkan kunci R2 sebelum barisnya hilang ----
  insert into public.storage_purge_queue (tenant_id, storage_key, reason)
  select p_tenant_id, k.kunci, 'account_deleted'
    from public.package_videos v
    cross join lateral (values (v.storage_key), (v.thumbnail_key)) as k(kunci)
   where v.tenant_id = p_tenant_id
     and k.kunci is not null
  on conflict (storage_key) do nothing;

  get diagnostics v_berkas = row_count;

  -- ---- b. Video, lalu toko ----
  -- Keduanya menghalangi penghapusan `users` lewat RESTRICT.
  delete from public.package_videos where tenant_id = p_tenant_id;
  delete from public.shops          where tenant_id = p_tenant_id;

  -- ---- c. Akun loginnya ----
  --
  -- 🔴 Inilah penghapusan yang sebenarnya. `public.users.id` menunjuk
  --    `auth.users(id) on delete cascade` (migrasi 03), jadi menghapus di
  --    `auth` menyeret baris `public.users`-nya sekalian — dan karena
  --    `tenants.owner_id` juga `on delete cascade`, baris tenantnya ikut
  --    hilang bersama seluruh langganan, dompet token, buku besar, dan
  --    pengaturannya.
  --
  --    Menghapus HANYA `public.users` akan meninggalkan akun `auth` yang masih
  --    dapat login — pengguna yang "sudah dihapus" tetap dapat masuk, ke sesi
  --    yang tidak punya profil sama sekali.
  delete from auth.users
   where id in (select id from public.users where tenant_id = p_tenant_id);

  -- ---- d. Jaring pengaman ----
  -- Bila tenant ini entah bagaimana tidak punya owner, cascade di atas tidak
  -- pernah menyala dan barisnya akan menggantung selamanya.
  delete from public.tenants where id = p_tenant_id;

  return v_berkas;
end;
$$;

comment on function public.purge_tenant(uuid) is
  'Memusnahkan seluruh data satu tenant, kunci R2-nya diantrekan lebih dulu. '
  'Urutan video -> toko -> auth.users wajib: dua FK RESTRICT di package_videos.';

-- Tidak seorang pun boleh memanggilnya dari aplikasi. Hanya dipakai
-- request_account_deletion() dan cron di bawah.
revoke execute on function public.purge_tenant(uuid) from public, anon, authenticated;


-- ------------------------------------------------------------
-- 4. Owner meminta akunnya dihapus
-- ------------------------------------------------------------
create or replace function public.request_account_deletion(p_confirm text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_nama      text;
  v_status    tenant_status;
  v_sudah     timestamptz;
begin
  if not public.is_owner() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'Hanya Owner yang dapat menghapus akun. Packer tidak.';
  end if;

  select t.id, t.business_name, t.status, t.deletion_requested_at
    into v_tenant_id, v_nama, v_status, v_sudah
    from public.tenants t
   where t.id = public.current_tenant_id()
     for update;

  if v_tenant_id is null then
    raise exception 'TENANT_NOT_FOUND' using errcode = '22023';
  end if;

  if v_sudah is not null then
    return 'SUDAH_DIMINTA';
  end if;

  -- 🔴 Nama usahanya diperiksa DI SINI, bukan hanya di layar. Pemeriksaan yang
  --    hanya hidup di widget bukan penjagaan — ia hilang begitu seseorang
  --    memanggil RPC-nya langsung, dan penghapusan akun adalah satu-satunya
  --    tombol di aplikasi ini yang tidak punya tombol urung.
  if lower(btrim(coalesce(p_confirm, ''))) is distinct from lower(btrim(coalesce(v_nama, ''))) then
    raise exception 'CONFIRM_MISMATCH'
      using errcode = '22023',
            hint = 'Nama usaha yang diketik tidak cocok.';
  end if;

  -- ---- Akun trial: seketika ----
  --
  -- Tenggang 7 hari menjaga sesuatu yang berharga. Akun trial belum punya apa
  -- pun yang berharga — tidak ada uang yang dibayarkan, dan menahannya seminggu
  -- hanya menahan data orang yang sudah pamit.
  if v_status = 'trial' then
    perform public.purge_tenant(v_tenant_id);
    return 'DIHAPUS_SEKARANG';
  end if;

  update public.tenants
     set deletion_requested_at = now(),
         deletion_purge_after  = now() + interval '7 days',
         updated_at            = now()
   where id = v_tenant_id;

  return 'DIJADWALKAN';
end;
$$;

comment on function public.request_account_deletion(text) is
  'Bab 9.6 - Owner menghapus akunnya sendiri. Trial dimusnahkan seketika, '
  'selain itu dijadwalkan 7 hari. Nama usaha diverifikasi di server.';

grant execute on function public.request_account_deletion(text) to authenticated;
revoke execute on function public.request_account_deletion(text) from anon, public;


-- ------------------------------------------------------------
-- 5. Membatalkan
-- ------------------------------------------------------------
create or replace function public.cancel_account_deletion()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  if not public.is_owner() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  -- ⚠️ `deletion_purge_after > now()` bukan basa-basi. Sesudah tenggangnya
  -- lewat, tenant ini sedang menunggu cron berikutnya — membatalkannya di
  -- celah itu berarti "menghidupkan kembali" akun yang secara janji sudah
  -- dimusnahkan, dan janji itulah yang dibaca pelanggan sebelum menekan.
  update public.tenants
     set deletion_requested_at = null,
         deletion_purge_after  = null,
         updated_at            = now()
   where id = public.current_tenant_id()
     and deletion_requested_at is not null
     and deletion_purge_after > now();

  if not found then
    raise exception 'CANCEL_TOO_LATE'
      using errcode = '22023',
            hint = 'Tidak ada permintaan hapus yang masih dapat dibatalkan.';
  end if;

  return 'DIBATALKAN';
end;
$$;

grant execute on function public.cancel_account_deletion() to authenticated;
revoke execute on function public.cancel_account_deletion() from anon, public;


-- ------------------------------------------------------------
-- 6. Mencatat percobaan yang gagal
-- ------------------------------------------------------------
-- Dipanggil Edge Function `purge-storage` untuk kunci yang ditolak R2.
--
-- ⚠️ Kenapa RPC, bukan `update` biasa lewat service role: menaikkan penghitung
-- butuh membaca nilai lamanya lebih dulu, dan dua panggilan yang berjalan
-- bersamaan akan saling menimpa. `attempts + 1` di dalam satu perintah tidak
-- punya masalah itu.
--
-- Gunanya bukan hiasan. Baris yang `attempts`-nya terus naik adalah kunci yang
-- tidak akan pernah berhasil dihapus — salah bucket, kredensial dicabut, atau
-- kunci yang cacat sejak ditulis. Tanpa penghitung ini ia hanya dicoba ulang
-- setiap malam tanpa ada seorang pun tahu.
create or replace function public.bump_purge_attempt(
  p_id    uuid,
  p_error text
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.storage_purge_queue
     set attempts   = attempts + 1,
         last_error = p_error
   where id = p_id;
$$;

revoke execute on function public.bump_purge_attempt(uuid, text)
  from public, anon, authenticated;


-- ------------------------------------------------------------
-- 7. Cron harian
-- ------------------------------------------------------------
-- Mengikuti pola migrasi 16: dibungkus DO agar `cron.schedule` yang
-- mengembalikan baris tidak menggagalkan migrasinya, dan aman diulang.
do $mig$
begin
  -- 02:00 — sesudah tiga job migrasi 16 (01:00, 01:15, 01:30) selesai.
  perform cron.schedule('purge-deleted-accounts', '0 2 * * *', $job$
    select public.purge_tenant(id)
      from public.tenants
     where deletion_requested_at is not null
       and deletion_purge_after <= now();
  $job$);
end
$mig$;
