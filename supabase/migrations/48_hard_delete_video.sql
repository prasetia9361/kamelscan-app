-- ============================================================
-- 48_hard_delete_video.sql  (Bab 7.7 — hapus video, sungguh-sungguh)
-- ============================================================
-- Keputusan Product Owner 4 September 2026, dengan kalimatnya sendiri:
--
--   "saya tidak mau soft delete. kalau video dihapus yaa video benar hilang.
--    karena soft delete itu racun yang membunuh tanpa sadar"
--
-- Ia benar, dan racunnya dapat ditunjukkan angkanya.
--
-- ============================================================
-- 🔴 APA YANG SEBENARNYA TERJADI SEBELUM BERKAS INI
-- ============================================================
--
-- `video_repository.deleteVideo` hanya menyetel `status = 'deleted'`. Berkas
-- di R2 tidak pernah disentuh, dan barisnya TIDAK PERNAH masuk
-- `storage_purge_queue`.
--
-- Yang mengisi antrean itu hanya tiga: retensi 30 hari (migrasi 41),
-- penghapusan akun (37), dan pembersihan packer (38). Ketiganya melewatkan
-- video yang dihapus Owner dari aplikasi.
--
-- ⚠️ Migrasi 41 punya kalimat yang mudah disalahbaca:
--
--       "Sengaja mengambil `expired` DAN `deleted`."
--
--    Itu benar HANYA untuk pengisian sekali saat migrasi itu dijalankan.
--    Fungsi hariannya, `expire_videos_and_queue_storage()`, hanya menyentuh
--    baris ber-status `uploaded` yang lewat masa retensi. Video ber-status
--    `deleted` tidak pernah menjadi `expired`, jadi ia tidak pernah antre.
--
-- Akibatnya setiap video yang dihapus Owner menjadi berkas yatim yang tetap
-- ditagihkan setiap bulan, selamanya, tanpa satu pun cara membersihkannya
-- selain menghapus seluruh akunnya.
--
-- 🔴 Dan ini bukan sekadar biaya. Owner yang menekan Hapus percaya videonya
-- hilang. Berkasnya masih utuh di R2 dan masih dapat dibuka siapa pun yang
-- memegang kredensial bucket. Janji yang tidak ditepati diam-diam.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Menghapus satu video, sungguh-sungguh
-- ------------------------------------------------------------
-- 🔴 URUTANNYA TIDAK BOLEH DIBALIK: kunci R2 diselamatkan ke antrean LEBIH
-- DULU, barisnya dihapus SESUDAHNYA.
--
-- `storage_key` hanya hidup di baris itu. Menghapus barisnya lebih dulu
-- membuang satu-satunya petunjuk ke berkasnya — dan berkas yang tidak
-- diketahui namanya tidak dapat dihapus oleh siapa pun, selamanya. Kegagalan
-- yang tidak dapat diperbaiki, ditukar dengan kegagalan yang paling buruk
-- hanya menyisakan berkas yatim.
--
-- Pola yang sama dipakai migrasi 37 dan 38; ini yang ketiga.
--
-- ⚠️ `security definer` melewati RLS, jadi kepemilikannya WAJIB diperiksa di
-- sini. Tanpa baris itu, siapa pun yang dapat memanggil RPC ini dapat
-- menghapus video tenant mana pun hanya dengan menebak UUID-nya.
create or replace function public.delete_video_hard(p_video_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
begin
  select tenant_id into v_tenant
    from public.package_videos
   where id = p_video_id;

  if v_tenant is null then
    return false;                       -- sudah tidak ada; bukan galat
  end if;

  if v_tenant <> public.current_tenant_id() then
    raise exception 'Video ini bukan milik tenant Anda'
      using errcode = '42501';
  end if;

  insert into public.storage_purge_queue (tenant_id, storage_key, reason)
  select v.tenant_id, k.kunci, 'owner_deleted'
    from public.package_videos v
    cross join lateral (values (v.storage_key), (v.thumbnail_key)) as k(kunci)
   where v.id = p_video_id
     and k.kunci is not null
  on conflict (storage_key) do nothing;

  delete from public.package_videos where id = p_video_id;
  return true;
end;
$$;

comment on function public.delete_video_hard(uuid) is
  'Bab 7.7 - menghapus video beserta berkas R2-nya. Kunci diantrekan lebih '
  'dulu, barisnya dihapus sesudahnya. Menggantikan soft delete.';

revoke all on function public.delete_video_hard(uuid) from public;
grant execute on function public.delete_video_hard(uuid) to authenticated;

-- ------------------------------------------------------------
-- 2. Retensi: berkasnya hilang, barisnya TETAP
-- ------------------------------------------------------------
-- ⚠️ Sengaja BERBEDA dari nomor 1, dan perbedaannya bukan kelalaian.
--
-- Video yang dihapus Owner: ia tahu ia menghapusnya, jadi barisnya lenyap
-- tanpa membingungkan siapa pun.
--
-- Video yang lewat retensi: Owner TIDAK melakukan apa-apa. Kalau barisnya ikut
-- lenyap, Riwayat menyusut sendiri tanpa penjelasan, dan itu terbaca persis
-- seperti data yang hilang. Status `expired` adalah penjelasannya — dan
-- berkasnya tetap benar-benar dihapus lewat antrean, yang memang yang diminta.
--
-- Jadi fungsi harian migrasi 41 dibiarkan apa adanya. Yang ditambahkan hanya
-- jaring pengaman di bawah.

-- ------------------------------------------------------------
-- 3. Membersihkan yang terlanjur
-- ------------------------------------------------------------
-- Baris ber-status `deleted` yang lahir sebelum berkas ini. Berkasnya masih
-- utuh di R2 dan tidak pernah antre.
--
-- ⚠️ Urutannya sama: antrekan dulu, hapus kemudian.
insert into public.storage_purge_queue (tenant_id, storage_key, reason)
select v.tenant_id, k.kunci, 'owner_deleted'
  from public.package_videos v
  cross join lateral (values (v.storage_key), (v.thumbnail_key)) as k(kunci)
 where v.status = 'deleted'
   and k.kunci is not null
on conflict (storage_key) do nothing;

delete from public.package_videos where status = 'deleted';

-- ============================================================
-- CARA MEMBUKTIKANNYA
-- ============================================================
--
-- 1. Tidak ada lagi yang tersisa berstatus `deleted`:
--
--       select count(*) from public.package_videos where status = 'deleted';
--       -- harus 0
--
-- 2. Hapus satu video dari aplikasi, lalu:
--
--       select reason, storage_key, created_at
--         from public.storage_purge_queue
--        order by created_at desc limit 3;
--       -- harus muncul baris ber-reason 'owner_deleted'
--
-- 3. Barisnya benar-benar hilang, bukan sekadar tersaring:
--
--       select count(*) from public.package_videos where id = '<id tadi>';
--       -- harus 0
--
-- 🔴 4. Berkasnya baru benar-benar terhapus setelah `drain_purge_queue`
--    berjalan — MIGRASI 47. Selama migrasi itu belum dijalankan, antreannya
--    hanya menumpuk dan tidak seorang pun mengurasnya.
--
--       select public.drain_purge_queue();
--       select status_code from net._http_response order by created desc limit 1;
--       -- 200 = berkasnya sudah dibuang dari R2
-- ============================================================
