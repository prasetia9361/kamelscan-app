-- ============================================================
-- 50_announcements.sql  (Iklan & pengumuman saat login)
-- ============================================================
-- Diminta Product Owner 5 September 2026, untuk HP maupun web sekaligus.
--
-- Dua kebutuhan yang selama ini tidak punya tempat sama sekali:
--
--   1. **Memaksa update.** Saat versi baru rilis, pengguna versi lama harus
--      memperbaruinya sebelum dapat memakai aplikasi. Tanpa ini satu-satunya
--      cara adalah menunggu Play Store memperbarui sendiri — yang tidak
--      pernah serentak — atau mematikan servernya, yang menghukum semua orang.
--
--   2. **Mengumumkan sesuatu.** Event, perawatan terjadwal, promo. Ini boleh
--      diabaikan: pengguna menutupnya dengan tanda silang.
--
-- ============================================================
-- 🔴 KENAPA TABEL SENDIRI, BUKAN `platform_settings`
-- ============================================================
--
-- Godaannya besar: `platform_settings` sudah ada sejak migrasi 08, sudah
-- punya izin admin, dan menampung jsonb apa pun. Satu baris `announcement`
-- dan selesai.
--
-- Itu tidak cukup, karena dua alasan yang keduanya diminta Product Owner:
--
--   - **Boleh ada banyak sekaligus.** Mengumumkan event sambil mewajibkan
--      update adalah keadaan yang wajar, bukan pengecualian. Satu baris jsonb
--      memaksa yang satu menimpa yang lain.
--
--   - **Yang sudah ditutup tidak muncul lagi, per orang.** Itu keadaan milik
--      PENGGUNA, bukan milik platform, dan `platform_settings` tidak punya
--      tempat untuknya. Menyimpannya di perangkat (SharedPreferences) juga
--      salah: orang yang sama membuka aplikasi di HP dan di web, dan
--      pengumuman yang sudah ditutup akan muncul lagi di layar kedua.
--
-- ⚠️ Migrasi ini tidak menyentuh satu tabel pun yang sudah ada. Aman
-- dijalankan ulang: keduanya `create table if not exists`.
-- ============================================================

-- ------------------------------------------------------------
-- Isi pengumuman
-- ------------------------------------------------------------
create table if not exists public.announcements (
  id            uuid primary key default gen_random_uuid(),

  title         text not null,
  body          text not null default '',

  -- Alamat gambar di bucket `public-assets` (migrasi 46). Boleh kosong:
  -- pengumuman perawatan biasanya tidak punya gambar, dan memaksakan satu
  -- gambar hanya membuat Admin menempelkan gambar asal.
  image_url     text,

  -- `important` | `normal`
  --
  -- 🔴 Perbedaannya bukan warna, melainkan apakah aplikasinya masih dapat
  -- dipakai. `important` mengunci: tidak ada tanda silang, dan tidak ada cara
  -- melewatinya selain menekan tombol aksinya. `normal` dapat ditutup.
  kind          text not null default 'normal',

  -- `all` | `owner` | `packer`
  --
  -- ⚠️ Admin TIDAK termasuk sasaran mana pun, dan itu disengaja: yang menulis
  -- pengumuman tidak perlu diberi tahu isinya sendiri, dan panel admin berdiri
  -- di luar rangka yang menampilkannya.
  audience      text not null default 'all',

  -- Tombol aksi. Untuk `important` inilah satu-satunya jalan keluar, jadi
  -- alamatnya wajib diisi Admin — biasanya halaman Play Store.
  action_url    text,
  action_label  text,

  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint chk_ann_kind     check (kind in ('important', 'normal')),
  constraint chk_ann_audience check (audience in ('all', 'owner', 'packer'))
);

-- Yang dibaca aplikasi selalu "yang aktif, terbaru dulu".
create index if not exists idx_announcements_active
  on public.announcements (is_active, created_at desc);

-- `updated_at` otomatis, memakai fungsi yang sudah ada sejak migrasi 15.
drop trigger if exists trg_touch_announcements on public.announcements;
create trigger trg_touch_announcements
  before update on public.announcements
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- Siapa sudah menutup apa
-- ------------------------------------------------------------
-- 🔴 Hanya berlaku bagi pengumuman `normal`. Yang `important` sengaja TIDAK
-- pernah dicatat di sini: ia harus muncul lagi pada login berikutnya selama
-- masih aktif, dan mencatat penutupannya berarti sekali lolos, selamanya
-- lolos.
create table if not exists public.announcement_dismissals (
  announcement_id uuid not null
    references public.announcements(id) on delete cascade,
  user_id         uuid not null
    references public.users(id) on delete cascade,
  dismissed_at    timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

-- Kueri yang dipakai aplikasi selalu bertanya "apa yang sudah ditutup ORANG
-- INI", jadi indeksnya menurut pengguna. Primary key di atas mengurutkan
-- menurut pengumuman, dan itu urutan yang salah untuk pertanyaan itu.
create index if not exists idx_dismissals_user
  on public.announcement_dismissals (user_id);

-- ------------------------------------------------------------
-- Izin
-- ------------------------------------------------------------
alter table public.announcements           enable row level security;
alter table public.announcement_dismissals enable row level security;

-- Dua policy untuk membaca, mengikuti pola `tutorials` (migrasi 14).
--
-- 🔴 Yang kedua bukan hiasan. `announcements_read` memakai `using (is_active)`,
-- sehingga pengumuman yang dinonaktifkan **tidak terlihat sama sekali** lewat
-- jalur itu — Admin yang menonaktifkan sebuah pengumuman akan melihatnya
-- lenyap dan tidak punya cara menghidupkannya kembali. Policy PostgreSQL
-- digabung dengan OR, jadi admin lolos lewat policy kedua tanpa peduli
-- `is_active`.
drop policy if exists announcements_read on public.announcements;
create policy announcements_read on public.announcements for select
  using (is_active);

drop policy if exists announcements_admin on public.announcements;
create policy announcements_admin on public.announcements for all
  using (public.is_admin()) with check (public.is_admin());

-- Catatan penutupan milik orangnya sendiri, dan hanya itu.
--
-- ⚠️ `with check` wajib ada di samping `using`. Tanpanya seseorang dapat
-- menuliskan baris atas nama `user_id` orang lain — tidak berbahaya isinya,
-- tetapi cukup untuk membungkam pengumuman bagi seluruh pengguna satu per
-- satu.
drop policy if exists dismissals_own on public.announcement_dismissals;
create policy dismissals_own on public.announcement_dismissals for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ------------------------------------------------------------
-- Catatan pemakaian
-- ------------------------------------------------------------
-- Gambar pengumuman menumpang bucket `public-assets` (migrasi 46) dengan nama
-- `announcement-<id>.jpg`.
--
-- 🔴 Namanya memakai id, BUKAN nama tetap seperti `landing.jpg`. Alasannya
-- berbeda dari gambar iklan landing page: di sana hanya ada satu gambar yang
-- selalu ditimpa, sedangkan di sini pengumumannya banyak dan hidup
-- bersamaan. Nama tetap berarti pengumuman kedua menimpa gambar pengumuman
-- pertama, dan yang pertama berubah gambarnya sendiri tanpa ada yang
-- menyentuhnya.
--
-- ⚠️ Konsekuensinya berkasnya harus ikut dibuang saat pengumumannya dihapus —
-- `on delete cascade` di atas hanya mengurus baris database, bukan berkas di
-- Storage. Itu dikerjakan `AdminAnnouncementsViewModel.hapus`.
