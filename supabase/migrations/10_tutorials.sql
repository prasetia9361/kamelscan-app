-- ============================================================
-- 10_tutorials.sql  (Bab 5.2)
-- ============================================================
-- Bab 0.2 poin 14: halaman tutorial hanya menampilkan daftar langkah dengan
-- tautan YouTube. Isinya dikelola Admin lewat Dashboard, bukan ditulis mati.
-- ============================================================

create table public.tutorials (
  id                    uuid primary key default gen_random_uuid(),
  step_order            integer not null,
  title                 text not null,
  description           text,
  youtube_url           text not null,
  platform              text not null default 'all',      -- all | mobile | web
  is_active             boolean not null default true,
  created_at            timestamptz not null default now()
);
