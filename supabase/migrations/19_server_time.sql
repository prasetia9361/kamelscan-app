-- ============================================================
-- 19_server_time.sql  (Bab 8.5 — waktu pada watermark)
-- ============================================================
-- Dua hal, satu perkara yang sama: **waktu di watermark tidak boleh berasal
-- dari jam HP.** Jam perangkat dapat dimundurkan, dan video bukti yang jamnya
-- dapat dipalsukan tidak ada gunanya saat disengketakan (Bab 1.3 poin 6).
--
-- 1. `server_now()` — sumber waktu server yang dapat ditanyakan aplikasi saat
--    ada sinyal. Aplikasi menyimpannya bersama titik acuan penghitung yang
--    tidak dapat diubah pengguna, lalu memakai hasil koreksinya di watermark
--    walaupun kemudian offline berjam-jam.
--
-- 2. `time_verified` — penanda bahwa waktu pada video itu **belum pernah**
--    diadu dengan waktu server sama sekali.
--
-- 🔴 Keputusan Product Owner 16 Agustus 2026: aplikasi yang baru dipasang lalu
--    langsung dibawa ke gudang tanpa sinyal **tetap boleh merekam**. Watermark
--    memakai jam HP apa adanya, dan videonya ditandai di sini. Alasannya:
--    bukti dengan waktu yang mungkin meleset jauh lebih berharga daripada
--    tidak ada bukti sama sekali, dan `created_at` di baris ini tetap diisi
--    server sehingga kebenarannya masih dapat ditelusuri.
-- ============================================================

alter table public.package_videos
  add column if not exists time_verified boolean not null default true;

comment on column public.package_videos.time_verified is
  'false = waktu pada watermark berasal dari jam HP yang belum pernah '
  'disinkronkan ke waktu server. Videonya tetap sah sebagai bukti, tetapi '
  'jamnya tidak dapat dijamin. Bandingkan dengan scan_date/created_at yang '
  'selalu diisi server.';

-- Video yang jamnya meragukan adalah kejadian langka; partial index membuatnya
-- dapat disaring dari dasbor tanpa membebani tabel yang isinya hampir seluruhnya
-- `true`.
create index if not exists idx_videos_time_unverified
  on public.package_videos (tenant_id, scan_date desc)
  where not time_verified;

-- ------------------------------------------------------------
-- Sumber waktu server
-- ------------------------------------------------------------
-- Sengaja sesederhana mungkin. Yang penting bukan ketelitiannya sampai
-- milidetik, melainkan bahwa angkanya **bukan berasal dari perangkat**.
--
-- ⚠️ `stable`, bukan `immutable` — hasilnya memang berubah tiap panggilan.
-- Menandainya `immutable` akan membuat PostgreSQL berhak menyimpan hasil
-- lamanya, dan sumber waktu yang di-cache adalah sumber waktu yang salah.
create or replace function public.server_now()
returns timestamptz
language sql
stable
as $$
  select now();
$$;

grant execute on function public.server_now() to authenticated;
revoke execute on function public.server_now() from anon, public;
