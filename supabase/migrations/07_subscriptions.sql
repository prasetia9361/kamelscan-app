-- ============================================================
-- 07_subscriptions.sql  (Bab 5.2)
-- ============================================================
-- Bab 12: Fase 1 memakai alur semi-manual (transfer + verifikasi Admin),
-- kolom midtrans_* sudah disiapkan untuk Fase 2.
-- ============================================================

create table public.subscriptions (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  plan                  tier_plan not null,
  status                sub_status not null default 'pending',
  amount                numeric(12,2) not null,
  discount_amount       numeric(12,2) not null default 0,
  promo_code            text,
  payment_method        text,                            -- 'midtrans' | 'manual_transfer'
  midtrans_order_id     text unique,
  midtrans_txn_id       text,
  proof_url             text,                            -- bukti transfer manual
  verified_by           uuid references public.users(id),
  period_start          timestamptz,
  period_end            timestamptz,
  paid_at               timestamptz,
  created_at            timestamptz not null default now()
);
create index idx_sub_tenant on public.subscriptions (tenant_id, created_at desc);
