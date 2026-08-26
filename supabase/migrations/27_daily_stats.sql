-- ============================================================
-- 27_daily_stats.sql  (Bab 10.4 — grafik harian di dasbor web)
-- ============================================================
-- Menjawab pertanyaan yang SENGAJA tidak dijawab kartu monitoring di Home:
-- "berapa paket dikirim dan di-return per hari, dan naik atau turun
-- dibanding periode sebelumnya?"
--
-- Pemisahan itu keputusan Product Owner 18 Agustus 2026 dan alasannya
-- tertulis panjang di `20_home_stats.sql`: kartu Home menghitung dari
-- `token_wallets.period_start` karena ia menjawab "jatah saya tinggal
-- berapa". Fungsi ini menghitung dari HARI KALENDER karena ia alat analisis.
-- Kedua angka itu memang boleh berbeda, dan tidak boleh digabung.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 EMPAT KEPUTUSAN YANG MUDAH DIBALIK ORANG BERIKUTNYA
-- ------------------------------------------------------------
--
-- 1. TANGGAL DIPINDAH KE WAKTU JAKARTA SEBELUM DIKELOMPOKKAN.
--
--    `scan_date` adalah `timestamptz` — waktu server, disimpan dalam UTC.
--    Mengelompokkan apa adanya (`scan_date::date`) memotong hari pada pukul
--    07:00 WIB, bukan tengah malam. Akibatnya rekaman lembur pukul 23:30
--    tercatat di hari berikutnya, dan grafiknya berbohong tepat pada jam
--    tersibuk gudang.
--
--    Zona ditulis mati sebagai 'Asia/Jakarta', bukan diambil dari peramban.
--    Alasannya: Owner di Jakarta dan packer di Makassar harus melihat grafik
--    yang sama persis saat menelepon satu sama lain. Angka yang berubah
--    mengikuti siapa yang membukanya tidak bisa dijadikan bahan pembicaraan.
--
-- 2. PENYARINGAN DILAKUKAN PADA `scan_date` MENTAH, BUKAN PADA HASIL
--    KONVERSINYA.
--
--    `where (scan_date at time zone 'Asia/Jakarta')::date >= ...` terbaca
--    lebih rapi dan MEMBUANG indeks `idx_videos_tenant_date`: nilainya harus
--    dihitung dulu untuk tiap baris sebelum dapat dibandingkan. Konversi
--    hanya boleh muncul di `group by`, tidak pernah di `where`.
--
-- 3. HARI KOSONG TETAP DIKIRIM SEBAGAI NOL.
--
--    Tanpa `generate_series`, hari tanpa rekaman hilang dari hasil, dan
--    grafik garis akan menyambung 20 Agustus langsung ke 24 Agustus seolah
--    tiga hari di antaranya tidak pernah ada. Libur yang tampak seperti hari
--    kerja biasa adalah kesalahan baca yang paling mahal di dasbor ini.
--
-- 4. `security invoker` (bawaan), BUKAN `security definer`.
--
--    Alasan yang sama dengan `get_home_stats()`: sebagai `security invoker`,
--    policy `videos_select` di `14_rls.sql` berlaku apa adanya, sehingga
--    packer hanya menghitung yang boleh ia lihat. Menutup Riwayat lalu
--    membocorkan hitungannya lewat grafik bukan penjagaan.
-- ------------------------------------------------------------

create or replace function public.get_daily_stats(p_days int default 30)
returns json
language sql
stable
as $$
  with param as (
    select
      -- Dikurung 7..90 mengikuti pemilih rentang Bab 10.4. Nilai di luar itu
      -- tidak ditolak melainkan dijepit: dasbor yang menolak memuat lebih
      -- buruk daripada dasbor yang memuat rentang terdekat yang masuk akal.
      greatest(least(coalesce(p_days, 30), 90), 7)  as jml_hari,
      (now() at time zone 'Asia/Jakarta')::date     as hari_ini
  ),
  batas as (
    select
      jml_hari,
      hari_ini,
      hari_ini - (jml_hari - 1)     as mulai,
      -- Periode pembanding: rentang sepanjang yang sama, persis sebelumnya.
      hari_ini - (jml_hari * 2 - 1) as mulai_lalu,
      hari_ini - jml_hari           as akhir_lalu
    from param
  ),
  v as (
    select
      (pv.scan_date at time zone 'Asia/Jakarta')::date as tanggal,
      pv.type
    from public.package_videos pv
    cross join batas b
    where pv.tenant_id = public.current_tenant_id()
      -- Video terhapus tidak muncul di Riwayat, jadi tidak ikut terhitung —
      -- alasan yang sama seperti `get_home_stats()`.
      and pv.status <> 'deleted'
      -- Batas bawah memakai periode PEMBANDING, karena keduanya dihitung
      -- dari himpunan yang sama ini.
      and pv.scan_date >= (b.mulai_lalu::timestamp at time zone 'Asia/Jakarta')
      and pv.scan_date <  ((b.hari_ini + 1)::timestamp at time zone 'Asia/Jakarta')
  ),
  deret as (
    select
      g::date                                          as tanggal,
      count(*) filter (where v.type = 'packing')       as packing,
      count(*) filter (where v.type = 'return')        as retur
    from batas b
    cross join lateral
      generate_series(b.mulai, b.hari_ini, interval '1 day') g
    left join v on v.tanggal = g::date
    group by g
    order by g
  ),
  kini as (
    select
      count(*) filter (where v.type = 'packing') as packing,
      count(*) filter (where v.type = 'return')  as retur
    from batas b
    left join v on v.tanggal >= b.mulai
  ),
  lalu as (
    select
      count(*) filter (where v.type = 'packing') as packing,
      count(*) filter (where v.type = 'return')  as retur
    from batas b
    left join v on v.tanggal between b.mulai_lalu and b.akhir_lalu
  )
  select json_build_object(
    -- Rentang ikut dikirim agar layar dapat menulis keterangan yang jujur
    -- ("1 - 30 Agustus") alih-alih kata "30 hari terakhir" yang tidak dapat
    -- dicocokkan dengan apa pun. Alasan yang sama seperti `period_start`
    -- pada `get_home_stats()`.
    'days',        b.jml_hari,
    'start_date',  b.mulai,
    'end_date',    b.hari_ini,
    'series', (
      select coalesce(json_agg(json_build_object(
               'date',    d.tanggal,
               'packing', d.packing,
               'return',  d.retur
             ) order by d.tanggal), '[]'::json)
      from deret d
    ),
    'total',      (select json_build_object(
                     'packing', k.packing, 'return', k.retur) from kini k),
    -- Periode pembanding. Dikirim sebagai angka mentah, BUKAN sebagai persen
    -- kenaikan: pembagian dengan nol harus diputuskan oleh layar, yang tahu
    -- cara menuliskannya ("belum ada pembanding"), bukan oleh SQL yang hanya
    -- bisa mengirim NULL.
    'previous',   (select json_build_object(
                     'packing', l.packing, 'return', l.retur) from lalu l)
  )
  from batas b;
$$;

comment on function public.get_daily_stats(int) is
  'Bab 10.4 - grafik harian dasbor web. Hari dikelompokkan menurut waktu '
  'Asia/Jakarta, hari kosong tetap dikirim sebagai nol, dan periode '
  'sebelumnya yang sama panjang ikut dihitung sebagai pembanding. '
  'security invoker: cakupannya mengikuti RLS, sehingga packer hanya '
  'menghitung yang boleh ia lihat.';

grant execute on function public.get_daily_stats(int) to authenticated;
revoke execute on function public.get_daily_stats(int) from anon, public;
