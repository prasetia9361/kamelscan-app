-- ============================================================
-- 06_tokens.sql  (Bab 5.2) — dompet kuota
-- ============================================================
-- Bab 7.2: 1 token = 1 video yang BERHASIL diunggah.
-- Pemotongan terjadi saat status berubah menjadi 'uploaded', bukan saat
-- perekaman dimulai — video yang gagal terkirim tidak membebani pelanggan.
-- ============================================================

create table public.token_wallets (
  tenant_id             uuid primary key references public.tenants(id) on delete cascade,
  balance               integer not null default 0,
  monthly_quota         integer not null default 100,
  period_start          timestamptz not null default now(),
  period_end            timestamptz,                       -- NULL selama uji coba (tidak pernah di-reset)
  updated_at            timestamptz not null default now(),

  constraint chk_balance_non_negative check (balance >= 0)
);

-- Bab 7.2 poin 5: setiap perubahan saldo WAJIB menghasilkan satu baris di sini.
-- Tanpa ledger, sengketa dengan pelanggan tidak bisa diselesaikan.
create table public.token_ledger (
  id                    bigserial primary key,
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  video_id              uuid references public.package_videos(id) on delete set null,
  delta                 integer not null,               -- negatif = pemakaian
  reason                ledger_reason not null,
  balance_after         integer not null,
  note                  text,
  created_at            timestamptz not null default now()
);
create index idx_ledger_tenant on public.token_ledger (tenant_id, created_at desc);
