-- ============================================================
-- 11_audit_logs.sql  (Bab 5.2)
-- ============================================================
-- Hanya ditulis oleh Edge Function (service role). Tidak ada policy INSERT
-- untuk peran 'authenticated' — lihat 14_rls.sql.
-- ============================================================

create table public.audit_logs (
  id                    bigserial primary key,
  tenant_id             uuid,
  actor_id              uuid,
  action                text not null,                    -- 'video.delete', 'packer.create', dst
  entity                text,
  entity_id             uuid,
  metadata              jsonb,
  created_at            timestamptz not null default now()
);
create index idx_audit_tenant on public.audit_logs (tenant_id, created_at desc);
