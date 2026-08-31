-- ============================================================
-- 42_capacity_stats.sql  (Bab 11.1 — kartu Kapasitas)
-- ============================================================
-- Angka mentah untuk kartu *Kapasitas* di Dasbor Platform: seberapa penuh
-- database, seberapa cepat ia tumbuh, dan berapa lama lagi sampai batasnya.
--
-- 🔴 KENAPA KARTU INI ADA.
--    Product Owner bertanya 31 Agustus 2026: *"apa nanti saya perlu cek setiap
--    hari atau bulan untuk tahu penggunanya berapa dan penggunaan datanya udah
--    berapa?"* — dan jawaban yang jujur adalah: tidak boleh bergantung pada
--    ingatan seseorang.
--
--    Batas 8 GB paket Supabase Pro tidak mengirim peringatan apa pun sampai ia
--    tercapai. Yang terjadi saat tercapai bukan aplikasi melambat, melainkan
--    **penulisan ditolak** — packer tidak dapat menyimpan satu video pun, dan
--    tidak ada satu layar pun yang dapat menjelaskan kenapa.
--
-- ⚠️ Yang dijawab kartu ini adalah "berapa lama lagi", bukan "sudah berapa".
--    Angka 4,2 GB tidak memberi tahu siapa pun kapan harus bertindak; "batas
--    tercapai sekitar 5 bulan lagi" memberi tahu.
-- ============================================================

create or replace function public.get_capacity_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_db_bytes     bigint;
  v_video_baris  bigint;
  v_video_bytes  bigint;
  v_baris_30hari bigint;
  v_bytes_30hari bigint;
  v_antrean      bigint;
  v_antrean_gagal bigint;
begin
  -- 🔴 BARIS PENJAGA. `security definer` mematikan RLS; ini satu-satunya yang
  -- tersisa. Ukuran database bukan rahasia besar, tetapi jumlah pelanggan dan
  -- laju pertumbuhannya adalah angka dagang.
  if not public.is_admin() then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'get_capacity_stats() hanya untuk peran admin.';
  end if;

  v_db_bytes := pg_database_size(current_database());

  select count(*), coalesce(sum(file_size_bytes), 0)
    into v_video_baris, v_video_bytes
    from public.package_videos;

  -- ---- Laju pertumbuhan ----
  --
  -- Dihitung dari 30 hari terakhir, bukan dari rata-rata sejak awal. Rata-rata
  -- sejak awal selalu terlalu optimistis: ia memasukkan minggu-minggu pertama
  -- saat belum ada pelanggan, dan pada layanan yang sedang tumbuh ia
  -- meleset semakin jauh justru ketika ramalannya paling dibutuhkan.
  --
  -- ⚠️ `scan_date`, bukan `created_at`: `scan_date` diisi trigger dengan waktu
  -- SERVER (migrasi 15) dan tidak dapat digeser jam HP yang salah.
  select count(*), coalesce(sum(file_size_bytes), 0)
    into v_baris_30hari, v_bytes_30hari
    from public.package_videos
   where scan_date >= now() - interval '30 days';

  -- ---- Antrean penghapusan R2 ----
  --
  -- Ikut ditampilkan karena antrean yang menumpuk berarti `purge-storage`
  -- tidak pernah berjalan — dan itu tepat keadaan yang membuat tagihan R2
  -- tumbuh diam-diam tanpa ada yang menyadarinya.
  select count(*) filter (where purged_at is null),
         count(*) filter (where purged_at is null and attempts > 0)
    into v_antrean, v_antrean_gagal
    from public.storage_purge_queue;

  return json_build_object(
    'db_bytes',        v_db_bytes,
    'video_rows',      v_video_baris,
    'video_bytes',     v_video_bytes,

    -- Angka mentah 30 hari. SENGAJA tidak diubah menjadi "per bulan" atau
    -- diproyeksikan di sini: ramalannya milik aplikasi, dan menaruhnya di dua
    -- tempat berarti dua rumus yang suatu hari akan berbeda.
    'rows_30d',        v_baris_30hari,
    'bytes_30d',       v_bytes_30hari,

    'purge_queue',     v_antrean,
    'purge_failed',    v_antrean_gagal,

    -- Batas paket yang sedang dipakai. Dikirim dari server supaya naik paket
    -- Supabase tidak menuntut rilis aplikasi baru.
    'db_limit_bytes',  8589934592::bigint,   -- 8 GB, Supabase Pro
    'measured_at',     now()
  );
end;
$$;

comment on function public.get_capacity_stats() is
  'Bab 11.1 - ukuran database, jumlah baris video, dan pertumbuhan 30 hari '
  'terakhir untuk kartu Kapasitas. Ramalan "berapa bulan lagi" dihitung di '
  'aplikasi, bukan di sini.';

grant execute on function public.get_capacity_stats() to authenticated;
revoke execute on function public.get_capacity_stats() from anon, public;
