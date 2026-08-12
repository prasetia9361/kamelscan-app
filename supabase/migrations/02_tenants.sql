-- ============================================================
-- 02_tenants.sql  (Bab 5.2) — satu baris = satu pelanggan (Owner)
-- ============================================================

create table public.tenants (
  id                    uuid primary key default uuid_generate_v4(),
  owner_id              uuid not null unique,          -- FK ditambahkan di 03_users.sql
  business_name         text,
  legal_name            text,                                     -- nama wajib pajak, untuk faktur
  tax_id                text,                                     -- NPWP, opsional
  tier_plan             tier_plan     not null default 'standar',
  status                tenant_status not null default 'trial',   -- pendaftar baru masuk uji coba
  trial_used            boolean       not null default true,      -- uji coba hanya sekali seumur akun
  period_start          timestamptz   not null default now(),
  period_end            timestamptz,                              -- NULL selama trial (Bab 7.5)
  created_at            timestamptz   not null default now(),
  updated_at            timestamptz   not null default now()
);
