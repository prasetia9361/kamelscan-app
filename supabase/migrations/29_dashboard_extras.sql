-- ============================================================
-- 29_dashboard_extras.sql  (Bab 10.4 — dasbor mengikuti rancangan desainer)
-- ============================================================
-- `get_daily_stats()` diperluas, BUKAN diganti fungsi baru. Dasbor tetap
-- terisi oleh **satu** panggilan.
--
-- Alasannya sama dengan `get_home_stats()`: memecahnya menjadi empat panggilan
-- berarti empat perjalanan bolak-balik untuk satu layar, dan keempatnya
-- memotret keadaan pada detik yang sedikit berbeda. Kartu "sisa token 371"
-- yang berdiri di sebelah grafik pemakaian yang dihitung dua detik kemudian
-- akan sesekali saling membantah, dan tidak ada yang bisa menjelaskannya.
--
-- Yang ditambahkan:
--   token_series   pemakaian token per hari, untuk grafik kedua
--   pending        antrean unggah di server: jumlah dan yang tertua
--   wallet         saldo dan kuota, untuk kartu Token Tersedia
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 TIGA HAL YANG MUDAH SALAH DI SINI
-- ------------------------------------------------------------
--
-- 1. PEMAKAIAN TOKEN HANYA `video_upload`.
--
--    `token_ledger` juga memuat `plan_upgrade`, `monthly_reset`,
--    `admin_adjust`, dan `refund`. Ketiga yang pertama bernilai BESAR dan
--    positif — aktivasi langganan Product Owner 26 Agustus 2026 mencatat
--    +942 dalam satu baris. Menjumlahkan seluruh alasan menghasilkan grafik
--    "pemakaian" yang melonjak ke atas tepat pada hari pelanggan membayar,
--    yang artinya kebalikan dari yang dibaca orang.
--
--    Keterangan di bawah judul grafiknya berbunyi "1 token = 1 video yang
--    berhasil diunggah". Hanya `video_upload` yang memenuhi kalimat itu.
--
-- 2. `delta` DIBALIK TANDANYA.
--
--    Pemakaian tercatat negatif (-1 per video). Grafik menggambar batang ke
--    atas, jadi yang dikirim `-sum(delta)`. Lupa membaliknya menghasilkan
--    grafik yang seluruhnya di bawah nol — dan pada sumbu yang dimulai dari
--    nol, itu tampak sebagai grafik kosong. Bukan galat, hanya salah.
--
-- 3. ANTREAN DI SINI ADALAH ANTREAN SERVER, BUKAN ANTREAN PERANGKAT.
--
--    ⚠️ `DEVIASI_LIBRARY.md` L.5: baris `package_videos` baru dibuat SAAT
--    MENGUNGGAH. Video yang direkam di gudang tanpa sinyal belum punya baris
--    di sini sama sekali — justru video yang paling perlu diberitahukan.
--
--    Di HP, spanduk "menunggu Wi-Fi" karena itu membaca antrean lokal
--    (`pendingUploadCountProvider`), bukan angka ini. Di web antrean lokal
--    itu **tidak dapat dilihat sama sekali** — perangkatnya bukan yang
--    sedang dipakai. Kartu di dasbor karena itu menghitung hal yang berbeda
--    dari spanduk di HP, dan keduanya sama-sama benar untuk pertanyaannya
--    masing-masing. Jangan "menyeragamkan" salah satunya.
-- ------------------------------------------------------------

-- 🔴 Dibuang lebih dulu karena TANDA TANGANNYA berubah (dua parameter tanggal
-- ditambahkan). `create or replace` dengan parameter baru tidak mengganti
-- fungsi lama melainkan membuat fungsi KEDUA di sebelahnya, dan panggilan
-- berikutnya menjadi rancu — PostgREST akan memilih salah satunya tanpa
-- memberi tahu yang mana.
drop function if exists public.get_daily_stats(int);

create or replace function public.get_daily_stats(
  p_days int  default 30,
  p_from date default null,
  p_to   date default null
)
returns json
language sql
stable
as $$
  with param as (
    select
      -- Dua cara memilih rentang, dan keduanya berakhir sebagai "berapa hari,
      -- berhenti di tanggal berapa":
      --
      --   * pemilih 7/30/90  -> p_days, selalu berakhir hari ini
      --   * rentang Kustom   -> p_from..p_to, boleh berakhir di masa lalu
      --
      -- Kustom dibatasi 366 hari. Bukan untuk melindungi grafik — ia sudah
      -- mengelompokkan sendiri — melainkan server: rentang sepuluh tahun
      -- menghasilkan `generate_series` sepanjang 3.650 baris untuk setiap
      -- pembukaan halaman.
      case
        when p_from is not null and p_to is not null
          then greatest(least((p_to - p_from) + 1, 366), 1)
        else greatest(least(coalesce(p_days, 30), 90), 7)
      end                                                       as jml_hari,
      coalesce(p_to, (now() at time zone 'Asia/Jakarta')::date)  as hari_ini
  ),
  batas as (
    select
      jml_hari,
      hari_ini,
      hari_ini - (jml_hari - 1)     as mulai,
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
      and pv.status <> 'deleted'
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
  ),

  -- ---- Pemakaian token per hari ----
  tok as (
    select
      (l.created_at at time zone 'Asia/Jakarta')::date as tanggal,
      -l.delta                                         as dipakai
    from public.token_ledger l
    cross join batas b
    where l.tenant_id = public.current_tenant_id()
      -- Butir 1: HANYA video_upload. Lihat catatan di atas.
      and l.reason = 'video_upload'
      and l.created_at >= (b.mulai::timestamp at time zone 'Asia/Jakarta')
      and l.created_at <  ((b.hari_ini + 1)::timestamp at time zone 'Asia/Jakarta')
  ),
  deret_token as (
    select
      g::date                              as tanggal,
      -- Butir 2: tandanya sudah dibalik di `tok`.
      coalesce(sum(tok.dipakai), 0)::int   as dipakai
    from batas b
    cross join lateral
      generate_series(b.mulai, b.hari_ini, interval '1 day') g
    left join tok on tok.tanggal = g::date
    group by g
    order by g
  )

  select json_build_object(
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
    'previous',   (select json_build_object(
                     'packing', l.packing, 'return', l.retur) from lalu l),

    'token_series', (
      select coalesce(json_agg(json_build_object(
               'date', dt.tanggal,
               'used', dt.dipakai
             ) order by dt.tanggal), '[]'::json)
      from deret_token dt
    ),

    -- Antrean unggah di SERVER. Butir 3 — bukan antrean perangkat.
    'pending', (
      select json_build_object(
        'count',     count(*),
        -- Yang tertua, bukan yang terbaru: itu yang menentukan apakah ada
        -- yang benar-benar tersangkut. Sepuluh video berumur satu menit
        -- adalah keadaan sehat; satu video berumur enam jam tidak.
        'oldest_at', min(p.scan_date)
      )
      from public.package_videos p
      where p.tenant_id = public.current_tenant_id()
        and p.status in ('pending_upload', 'uploading')
    ),

    -- Dibiarkan NULL bila dompetnya belum ada, bukan dipaksa 0 — alasan yang
    -- sama seperti `get_home_stats()`: "belum punya dompet" dan "saldo habis"
    -- adalah dua keadaan berbeda, dan yang pertama tidak boleh menyuruh Owner
    -- membeli token yang sebenarnya sudah ia punya.
    'wallet', (
      select json_build_object(
        'balance', w.balance,
        'quota',   w.monthly_quota
      )
      from public.token_wallets w
      where w.tenant_id = public.current_tenant_id()
    )
  )
  from batas b;
$$;

comment on function public.get_daily_stats(int, date, date) is
  'Bab 10.4 - seluruh isi dasbor web dalam satu panggilan: grafik video '
  'harian, grafik pemakaian token harian, antrean unggah server, dan saldo '
  'dompet. Hari dikelompokkan menurut waktu Asia/Jakarta; hari kosong tetap '
  'dikirim sebagai nol. Pemakaian token hanya menghitung reason video_upload. '
  'security invoker: cakupannya mengikuti RLS.';

grant execute on function public.get_daily_stats(int, date, date) to authenticated;
revoke execute on function public.get_daily_stats(int, date, date) from anon, public;
