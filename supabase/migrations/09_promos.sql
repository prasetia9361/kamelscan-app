-- ============================================================
-- 09_promos.sql  (Bab 5.2)
-- ============================================================
-- Bab 0.2: UI khusus promo dibangun di Fase 2. Pada MVP, Admin mengubah
-- baris tabel ini langsung lewat Supabase Dashboard.
-- ============================================================

create table public.promos (
  code                  text primary key,
  description           text,
  discount_type         text not null,                    -- 'percent' | 'fixed'
  discount_value        numeric(12,2) not null,
  applies_to            tier_plan,                        -- null = semua paket
  valid_from            timestamptz not null default now(),
  valid_until           timestamptz not null,
  max_uses              integer,
  used_count            integer not null default 0,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  constraint chk_discount_type check (discount_type in ('percent','fixed'))
);
