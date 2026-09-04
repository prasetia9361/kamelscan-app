-- ============================================================
-- 41_retention_purge.sql  (Bab 1.3 poin 4 — retensi 30 hari)
-- ============================================================
-- Mengisi `storage_purge_queue` dengan kunci objek video yang retensinya
-- habis, supaya Edge Function `purge-storage` benar-benar menghapus berkasnya
-- dari Cloudflare R2.
--
-- 🔴 SEJAK HARI PERTAMA, TIDAK SATU PUN BERKAS R2 PERNAH TERHAPUS.
--
--    Comment migrasi 16 menjanjikan: *"Penghapusan objek fisik di R2 dilakukan
--    oleh Edge Function 'purge-expired-videos' yang dipanggil setelahnya."*
--    Fungsi itu tidak pernah dibuat. `mark-expired-videos` rajin menandai
--    baris `expired` setiap malam, dan videonya tetap utuh di R2 — tetap
--    ditagihkan setiap bulan, selamanya, tanpa satu pun galat.
--
--    Retensi 30 hari bukan sekadar janji ke pelanggan; ia **model bisnisnya**
--    (Bab 1.3 poin 4). Selama berkasnya tidak pernah hilang, biaya
--    penyimpanan tumbuh tanpa batas sementara pendapatannya tidak.
-- ============================================================


-- ------------------------------------------------------------
-- 🔴 KENAPA DIANTREKAN SAAT DITANDAI, BUKAN DIPINDAI ULANG TIAP MALAM
-- ------------------------------------------------------------
-- Cara yang paling terpikirkan adalah memindai seluruh video berstatus
-- `expired` setiap malam lalu mengantrekan yang belum pernah diantrekan.
-- Itu bekerja, dan biayanya naik terus: jumlah video kedaluwarsa hanya
-- bertambah — barisnya sengaja TIDAK dihapus (keputusan Product Owner, riwayat
-- harus tetap dapat ditelusuri) — sehingga pemindaian malam ke-1000 memeriksa
-- ratusan ribu baris untuk menemukan beberapa lusin yang baru.
--
-- Menyatukan penandaan dan pengantrean dalam satu perintah membuat yang
-- diperiksa **hanya video yang baru kedaluwarsa malam itu**. Tidak ada
-- pemindaian yang tumbuh, dan tidak ada dua langkah yang dapat berjalan
-- terpisah lalu tidak sinkron.
--
-- ⚠️ Baris videonya TETAP ADA dan tetap berstatus `expired`. Yang hilang hanya
--    berkasnya di R2. Riwayat pelanggan tetap menunjukkan bahwa video itu
--    pernah ada, kapan direkam, dan oleh siapa — yang tidak dapat diputar
--    lagi. Itu disengaja: bukti packing yang lenyap tanpa jejak lebih buruk
--    daripada bukti yang tercatat pernah ada.
-- ------------------------------------------------------------

create or replace function public.expire_videos_and_queue_storage()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_video integer := 0;
begin
  with kedaluwarsa as (
    update public.package_videos
       set status = 'expired'
     where status = 'uploaded'
       and expires_at <= now()
    returning tenant_id, storage_key, thumbnail_key
  ), diantre as (
    insert into public.storage_purge_queue (tenant_id, storage_key, reason)
    select k.tenant_id, kunci.v, 'retention'
      from kedaluwarsa k
      cross join lateral (values (k.storage_key), (k.thumbnail_key)) as kunci(v)
     where kunci.v is not null
    on conflict (storage_key) do nothing
    returning 1
  )
  select count(*) into v_video from kedaluwarsa;

  return v_video;
end;
$$;

comment on function public.expire_videos_and_queue_storage() is
  'Bab 1.3 poin 4 - menandai video kedaluwarsa DAN mengantrekan kunci R2-nya '
  'dalam satu perintah. Barisnya tetap ada; hanya berkasnya yang dihapus '
  'purge-storage. Menggantikan cron mark-expired-videos (migrasi 16).';

revoke execute on function public.expire_videos_and_queue_storage()
  from public, anon, authenticated;


-- ------------------------------------------------------------
-- Menyusul yang sudah terlanjur kedaluwarsa
-- ------------------------------------------------------------
-- Setiap video yang ditandai `expired` sebelum hari ini tidak pernah masuk
-- antrean, dan berkasnya masih berdiri di R2. Ini satu-satunya kesempatan
-- mengangkatnya: sekali dijalankan, `on conflict do nothing` membuat
-- pengulangan berkas ini tidak menduplikasi apa pun.
--
-- ⚠️ Sengaja mengambil `expired` DAN `deleted`. Video yang dihapus Owner
--    dari aplikasi hanya berubah status — berkasnya tidak pernah disentuh,
--    dan Owner sudah menyatakan tidak menginginkannya lagi.
insert into public.storage_purge_queue (tenant_id, storage_key, reason)
select v.tenant_id, k.kunci, 'retention'
  from public.package_videos v
  cross join lateral (values (v.storage_key), (v.thumbnail_key)) as k(kunci)
 where v.status in ('expired', 'deleted')
   and k.kunci is not null
on conflict (storage_key) do nothing;


-- ------------------------------------------------------------
-- Cron
-- ------------------------------------------------------------
do $mig$
begin
  -- 🔴 `mark-expired-videos` DICABUT, bukan dibiarkan berdampingan.
  --    Ia melakukan setengah pekerjaan yang sama (menandai `expired`) tanpa
  --    mengantrekan kuncinya. Bila keduanya hidup, yang menang adalah yang
  --    berjalan lebih dulu — dan video yang sudah ditandai olehnya tidak akan
  --    pernah terlihat oleh fungsi baru, karena syaratnya `status = 'uploaded'`.
  --    Berkasnya kembali menjadi sampah yang tidak dapat ditemukan siapa pun.
  begin
    perform cron.unschedule('mark-expired-videos');
  exception
    when others then
      raise notice 'mark-expired-videos tidak ada / sudah dicabut';
  end;

  -- Jam yang sama dengan job lama (01:15), sesudah reset token dan sebelum
  -- `expire-tenants`. Urutannya tidak mengikat di sini, tetapi menggesernya
  -- tanpa alasan hanya membuat jejak log lebih sulit dibaca.
  perform cron.schedule('expire-videos', '15 1 * * *', $job$
    select public.expire_videos_and_queue_storage();
  $job$);
end
$mig$;
