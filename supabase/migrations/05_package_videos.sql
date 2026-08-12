-- ============================================================
-- 05_package_videos.sql  (Bab 5.2) — tabel inti
-- ============================================================

create table public.package_videos (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  shop_id               uuid not null references public.shops(id) on delete restrict,
  user_id               uuid not null references public.users(id) on delete restrict,

  resi_code             text not null,
  type                  video_type not null,
  status                video_status not null default 'pending_upload',

  scan_date             timestamptz not null,          -- waktu SERVER, bukan waktu HP
  device_started_at     timestamptz,                   -- waktu HP, hanya untuk audit selisih
  duration_seconds      integer,
  file_size_bytes       bigint,

  location_lat          double precision,
  location_lng          double precision,
  location_accuracy_m   double precision,

  storage_key           text,                          -- kunci objek R2: tenant/{tenant_id}/2026/08/{id}.mp4
  thumbnail_key         text,

  public_token          text unique,                   -- diisi saat Owner menekan 'Bagikan'
  public_expires_at     timestamptz,

  expires_at            timestamptz not null,          -- waktu hapus otomatis (retensi)
  uploaded_at           timestamptz,
  upload_attempts       smallint not null default 0,
  last_error            text,

  device_model          text,
  app_version           text,
  created_at            timestamptz not null default now(),

  constraint chk_duration check (duration_seconds is null or duration_seconds between 1 and 120)
);

-- Bab 7.7 — nomor resi TIDAK BOLEH ganda dalam satu tenant untuk tipe yang sama.
-- Dipisah per tipe: satu resi wajar direkam sekali saat packing dan sekali lagi
-- bila paket itu kembali (return).
-- Partial index dipakai agar video yang sudah dihapus tidak menghalangi
-- perekaman ulang.
create unique index uq_resi_per_tenant_type
  on public.package_videos (tenant_id, resi_code, type)
  where status <> 'deleted';

create index idx_videos_resi        on public.package_videos (tenant_id, resi_code);
create index idx_videos_tenant_date on public.package_videos (tenant_id, scan_date desc);
create index idx_videos_shop        on public.package_videos (shop_id, scan_date desc);
create index idx_videos_user        on public.package_videos (user_id, scan_date desc);
create index idx_videos_status      on public.package_videos (status) where status <> 'uploaded';
create index idx_videos_expiry      on public.package_videos (expires_at) where status = 'uploaded';
create index idx_videos_public      on public.package_videos (public_token) where public_token is not null;

-- Pencarian resi cepat & toleran salah ketik
create index idx_videos_resi_trgm on public.package_videos using gin (resi_code gin_trgm_ops);
