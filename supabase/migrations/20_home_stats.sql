-- ============================================================
-- 20_home_stats.sql  (Bab 9.2 — kartu monitoring di Home)
-- ============================================================
-- Satu panggilan yang mengisi seluruh kartu monitoring sekaligus. Alternatifnya
-- empat permintaan terpisah dari Flutter tiap kali Home dibuka; halaman ini
-- yang paling sering dibuka di aplikasi, jadi biayanya terasa.
--
-- Menghitung baris mentah dari klien juga ditolak karena alasan yang sama
-- dengan Bab 7.3: angka yang dihitung di perangkat akan salah begitu dua packer
-- bekerja bersamaan.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 DUA PENYIMPANGAN DARI CONTOH SQL DI BAB 9.2 — keduanya disengaja
-- ------------------------------------------------------------
--
-- 1. PERIODE DIHITUNG DARI `token_wallets.period_start`, BUKAN DARI
--    `date_trunc('month', now())`.
--
--    Diputuskan Product Owner 18 Agustus 2026, setelah melihat angkanya pada
--    data sungguhan. Kartu video dan kartu token berdiri bersebelahan di layar
--    yang sama, jadi keduanya harus bercerita tentang rentang waktu yang sama.
--
--    Contoh di Bab 9.2 memakai bulan kalender. Itu benar untuk pelanggan
--    berbayar yang kuotanya di-reset tiap bulan, dan salah selama masa uji
--    coba — jatah 100 video uji coba TIDAK PERNAH di-reset (`period_end` NULL,
--    Bab 7.5). Dibuktikan pada tenant `0b5ae403…` (27 video, 17 Agustus 2026):
--
--      cara bulan kalender, andai hari ini 1 September →  0 video · 73 token
--      cara periode dompet, andai hari ini 1 September → 27 video · 73 token
--
--    Baris pertama menampilkan "belum merekam apa pun" di sebelah "27 kupon
--    sudah habis" — dua kartu yang saling membantah, tanpa satu pun keterangan
--    di layar yang menjelaskannya.
--
--    Memakai `period_start` juga otomatis benar untuk pelanggan berbayar:
--    di sana ia memang bergerak tiap bulan mengikuti tanggal langganan, yang
--    lebih tepat daripada tanggal 1 kalender.
--
--    ⚠️ Ini BUKAN berarti pertanyaan "bulan ini / hari ini berapa paket
--    dikirim dan di-return" ditinggalkan. Product Owner menegaskan 18 Agustus
--    2026 bahwa pertanyaan itu rumahnya di **grafik dashboard web (Bab 10.4,
--    `get_daily_stats`)** — di sana ada pemilih rentang 7/30/90 hari dan
--    perbandingan dengan periode sebelumnya, yang memang alat analisis.
--    Kartu di Home mobile menjawab pertanyaan lain: "jatah saya tinggal
--    berapa". Jangan menggabungkan keduanya ke satu kartu; itu persis yang
--    membuat angkanya saling membantah.
--
-- 2. `security invoker` (bawaan), BUKAN `security definer`.
--
--    Contoh di Bab 9.2 memakai `security definer`, yang menembus RLS. Dengan
--    itu, packer akan melihat jumlah video SELURUH tenant di Home — padahal
--    Bab 2.2 catatan 3 sudah memutuskan packer hanya melihat rekamannya
--    sendiri kecuali Owner menyalakan `shop_history_visible_to_packer`
--    (bawaannya `false`, dan memang `false` di seluruh tenant saat ini).
--
--    Menutup riwayat di satu layar lalu membocorkan hitungannya di layar
--    sebelah bukan penjagaan. Sebagai `security invoker`, policy `videos_select`
--    di `14_rls.sql` berlaku apa adanya dan angkanya otomatis sesuai cakupan
--    tiap peran — tanpa satu baris pun aturan peran ditulis ulang di sini.
--
--    ⚠️ `resi_exists` di `13_helpers.sql` memang `security definer`, dan itu
--    bukan ketidakkonsistenan: ia HARUS menembus RLS supaya packer tahu resi
--    sudah dipakai rekan sekerjanya. Fungsi ini kebalikannya.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Awal periode berjalan.
-- ------------------------------------------------------------
-- Dipisah agar dipakai bersama oleh hitungan dan oleh keterangan yang dikirim
-- ke layar — dua tempat yang WAJIB memakai tanggal yang sama persis. Bila
-- keduanya dihitung sendiri-sendiri, layar akan menuliskan satu tanggal sambil
-- menghitung dari tanggal lain, dan tidak ada yang tahu.
--
-- ⚠️ Harus berdiri LEBIH DULU daripada `get_home_stats()`. Fungsi `language sql`
-- diperiksa isinya saat dibuat, jadi urutan terbalik ditolak `42883` — sudah
-- terjadi sekali pada 18 Agustus 2026.
create or replace function public.home_stats_period_start()
returns timestamptz
language sql
stable
as $$
  select coalesce(
    (select w.period_start from public.token_wallets w
      where w.tenant_id = public.current_tenant_id()),
    -- Cadangan bila dompet belum terbentuk: bulan kalender berjalan. Keadaan
    -- ini seharusnya tidak pernah terjadi (trigger registrasi membuat dompet
    -- bersama tenant), tetapi kartu yang kosong lebih baik daripada kartu yang
    -- menghitung seluruh riwayat sejak awal.
    date_trunc('month', now())
  );
$$;

create or replace function public.get_home_stats()
returns json
language sql
stable
as $$
  select json_build_object(
    -- Awal periode ikut dikirim agar kartu dapat menulis keterangan yang jujur
    -- ("sejak 13 Agustus") alih-alih memakai kata "bulan ini" yang belum tentu
    -- benar. Tanpa ini, angkanya betul tetapi kalimatnya berbohong.
    'period_start',   public.home_stats_period_start(),

    'packing_count',  count(*) filter (where v.type = 'packing'),
    'return_count',   count(*) filter (where v.type = 'return'),

    -- Bab 9.2 (🟡 TARGET) — banner "4 video menunggu koneksi Wi-Fi". Sengaja
    -- TIDAK dibatasi periode: video yang tersangkut sejak periode lalu justru
    -- yang paling perlu diberitahukan.
    'pending_upload', (
      select count(*)
        from public.package_videos p
       where p.tenant_id = public.current_tenant_id()
         and p.status in ('pending_upload', 'uploading')
    ),
    'failed_upload',  (
      select count(*)
        from public.package_videos p
       where p.tenant_id = public.current_tenant_id()
         and p.status = 'failed'
    ),

    -- Dibiarkan NULL bila dompetnya belum ada, bukan dipaksa 0. "Belum punya
    -- dompet" dan "saldo habis" adalah dua keadaan berbeda, dan kartu yang
    -- menampilkan 0 pada keadaan pertama akan menyuruh Owner membeli token
    -- yang sebenarnya sudah ia punya.
    'token_balance',  (
      select w.balance from public.token_wallets w
       where w.tenant_id = public.current_tenant_id()
    ),
    'token_quota',    (
      select w.monthly_quota from public.token_wallets w
       where w.tenant_id = public.current_tenant_id()
    )
  )
  from public.package_videos v
  where v.tenant_id = public.current_tenant_id()
    -- Video terhapus tidak muncul di Riwayat (`VideoRepository.fetchVideos`),
    -- jadi tidak boleh ikut terhitung di sini — kartu ini dapat ditekan dan
    -- membuka Riwayat, dan angka yang berbeda dari jumlah baris yang muncul
    -- sesudahnya akan tampak seperti kesalahan.
    and v.status <> 'deleted'
    and v.scan_date >= public.home_stats_period_start();
$$;

comment on function public.get_home_stats() is
  'Bab 9.2 — isi seluruh kartu monitoring Home dalam satu panggilan. Periode '
  'dihitung sejak token_wallets.period_start (keputusan Product Owner '
  '18 Agustus 2026) agar angka video selalu sejalan dengan sisa token. '
  'security invoker: cakupannya mengikuti RLS, sehingga packer hanya '
  'menghitung yang boleh ia lihat.';

grant execute on function public.home_stats_period_start() to authenticated;
grant execute on function public.get_home_stats() to authenticated;
revoke execute on function public.home_stats_period_start() from anon, public;
revoke execute on function public.get_home_stats() from anon, public;
