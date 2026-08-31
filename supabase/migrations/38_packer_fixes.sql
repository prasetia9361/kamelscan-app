-- ============================================================
-- 38_packer_fixes.sql  (Bab 6.7)
-- ============================================================
-- Dua cacat akun packer yang dilaporkan 31 Agustus 2026. Keduanya punya bentuk
-- yang sama persis, dan bentuk itu yang paling mahal di aplikasi ini:
--
--   🔴 Owner menekan tombol, layarnya berubah seolah berhasil, dan yang
--      dijanjikan tombol itu tidak pernah terjadi.
--
-- Persis cacat `delete-packer` 20 Agustus (P.2). Ketiganya tidak pernah
-- memunculkan satu pun galat.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Packer nonaktif tetap boleh merekam
-- ------------------------------------------------------------
-- `users.is_active` disetel tombol Nonaktifkan di Kelola Packer, dan sampai
-- hari ini TIDAK ADA satu baris pun yang membacanya di jalur kerja. Bekas
-- pegawai yang aksesnya "sudah dicabut" tetap masuk dan tetap merekam.
--
-- ⚠️ Penjagaan di aplikasi (session_provider.dart) memang sudah ditambahkan,
--    tetapi itu saja TIDAK CUKUP dan tidak boleh dianggap cukup: JWT-nya masih
--    sah sampai kedaluwarsa, dan siapa pun yang memegangnya dapat memanggil
--    PostgREST langsung tanpa pernah membuka aplikasinya. Yang menegakkan
--    aturan adalah baris di bawah ini; yang di aplikasi hanya menjelaskannya.
--
-- Ditaruh di sini, bukan di policy RLS, karena inilah tempat setiap aturan
-- perekaman lain sudah berdiri (kuota, status langganan, retensi) — dan aturan
-- yang tersebar di dua tempat adalah aturan yang suatu hari akan berbeda.
create or replace function public.before_video_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tenant uuid;
  v_aktif  boolean;
  v_tier   tier_plan;
  v_status tenant_status;
  v_days   int;
  v_bal    int;
begin
  select tenant_id, is_active into v_tenant, v_aktif
    from public.users where id = auth.uid();
  if v_tenant is null then raise exception 'USER_NOT_FOUND'; end if;

  -- Bab 6.7 — dinonaktifkan berarti berhenti bekerja, seketika.
  if not coalesce(v_aktif, true) then
    raise exception 'ACCOUNT_DISABLED' using errcode = 'P0005';
  end if;

  select tier_plan, status into v_tier, v_status
    from public.tenants where id = v_tenant;

  -- Bab 7.6: langganan berakhir / ditangguhkan = TERKUNCI SEKETIKA,
  -- tanpa masa tenggang.
  if v_status not in ('trial','active') then
    raise exception 'SUBSCRIPTION_INACTIVE' using errcode = 'P0003';
  end if;

  select (value->(v_tier::text)->>'retention_days')::int into v_days
  from public.platform_settings where key = 'pricing';

  -- Bab 7.3: tolak bila kuota habis. INI penegakan sesungguhnya — bukan
  -- pengecekan di Flutter. `for update` menutup kondisi balapan saat beberapa
  -- packer merekam bersamaan.
  select balance into v_bal from public.token_wallets where tenant_id = v_tenant for update;
  if coalesce(v_bal,0) <= 0 then
    if v_status = 'trial' then
      raise exception 'TRIAL_EXHAUSTED' using errcode = 'P0004';
    else
      raise exception 'TOKEN_EXHAUSTED' using errcode = 'P0001';
    end if;
  end if;

  new.tenant_id  := v_tenant;
  new.scan_date  := now();                    -- waktu server, anti manipulasi jam HP
  new.expires_at := now() + make_interval(days => coalesce(v_days,30));
  return new;
end;
$$;


-- ------------------------------------------------------------
-- 2. Packer tidak dapat dihapus karena video yang sudah dihapus
-- ------------------------------------------------------------
-- 🔴 Menghapus video di aplikasi adalah penghapusan LUNAK: `video_repository`
--    baris 503 hanya menyetel `status = 'deleted'`, dan barisnya tetap ada.
--    Setiap layar menyaringnya (`status <> 'deleted'`), sehingga di mata Owner
--    video itu benar-benar hilang.
--
--    `delete-packer` adalah satu-satunya tempat yang menghitung SEMUA baris.
--    Akibatnya Owner yang sudah membersihkan video seorang packer tetap
--    ditolak dengan *"packer masih punya 12 video"* — dua belas video yang
--    tidak dapat ia temukan di layar mana pun, dan tidak dapat ia hapus lagi
--    karena menurut aplikasinya memang sudah tidak ada.
--
-- ⚠️ Sekadar mengubah hitungannya menjadi `status <> 'deleted'` JUSTRU
--    MEMPERBURUK. Baris-baris itu masih berdiri, dan
--    `package_videos.user_id` adalah `on delete restrict` — diukur langsung
--    31 Agustus 2026: menghapus `auth.users` yang masih ditunjuk baris
--    `package_videos` gagal dengan `23503`. Penolakan yang jelas beserta
--    jumlahnya akan berubah menjadi `DELETE_FAILED` tanpa penjelasan.
--
--    Jadi barisnya harus benar-benar dihapus lebih dulu — dan kunci R2-nya
--    diselamatkan ke antrean, persis seperti penghapusan akun (migrasi 37).
create or replace function public.purge_packer_soft_deleted_videos(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_baris integer := 0;
begin
  insert into public.storage_purge_queue (tenant_id, storage_key, reason)
  select v.tenant_id, k.kunci, 'packer_deleted'
    from public.package_videos v
    cross join lateral (values (v.storage_key), (v.thumbnail_key)) as k(kunci)
   where v.user_id = p_user_id
     and v.status  = 'deleted'
     and k.kunci is not null
  on conflict (storage_key) do nothing;

  delete from public.package_videos
   where user_id = p_user_id
     and status  = 'deleted';

  get diagnostics v_baris = row_count;
  return v_baris;
end;
$$;

comment on function public.purge_packer_soft_deleted_videos(uuid) is
  'Bab 6.7 - menghapus permanen video yang sudah dihapus lunak milik satu '
  'packer, kunci R2-nya diantrekan lebih dulu. Dipanggil delete-packer supaya '
  'FK RESTRICT package_videos.user_id tidak lagi memblokir penghapusan akun.';

-- Hanya service role (Edge Function `delete-packer`). Owner tidak boleh dapat
-- memusnahkan baris video siapa pun langsung dari aplikasi.
revoke execute on function public.purge_packer_soft_deleted_videos(uuid)
  from public, anon, authenticated;
