-- ============================================================
-- 08_settings.sql  (Bab 5.2)
-- ============================================================

-- Preferensi per pengguna (tema & voice-over ikut orangnya, bukan tenant)
create table public.user_settings (
  user_id               uuid primary key references public.users(id) on delete cascade,
  theme                 text not null default 'default',  -- default | light | dark
  language              text not null default 'id',       -- id | en
  voice_over_enabled    boolean not null default true,
  updated_at            timestamptz not null default now(),
  constraint chk_theme    check (theme in ('default','light','dark')),
  constraint chk_language check (language in ('id','en'))
);

-- Pengaturan milik tenant, hanya Owner yang boleh mengubah
create table public.tenant_settings (
  tenant_id                      uuid primary key references public.tenants(id) on delete cascade,
  watermark_logo_url             text,                     -- khusus tier pro (Bab 2.2 catatan 4)
  watermark_position             text not null default 'bottom_right',
  watermark_opacity              numeric(3,2) not null default 0.75,
  show_gps_on_watermark          boolean not null default true,
  shop_history_visible_to_packer boolean not null default false,
  updated_at                     timestamptz not null default now(),
  constraint chk_wm_pos check (watermark_position in ('top_left','top_right','bottom_left','bottom_right'))
);

-- Pengaturan platform, hanya Admin.
-- Bab 7.1: SELURUH angka tier dibaca dari sini, tidak ditulis mati di Flutter,
-- agar Admin dapat mengubah harga/kuota tanpa rilis aplikasi baru.
create table public.platform_settings (
  key                   text primary key,
  value                 jsonb not null,
  updated_by            uuid references public.users(id),
  updated_at            timestamptz not null default now()
);

-- Isi awal — angka ini harus cocok dengan TierCatalog.fallback di
-- lib/core/config/tier_config.dart
insert into public.platform_settings (key, value) values
  ('pricing', '{
      "standar": {"price": 99000,  "max_video_seconds": 30, "retention_days": 30, "max_packers": 5,  "monthly_tokens": 1000},
      "pro":     {"price": 249000, "max_video_seconds": 60, "retention_days": 60, "max_packers": -1, "monthly_tokens": 5000}
   }'::jsonb),
  ('trial', '{"tokens": 100, "tier": "standar", "enabled": true}'::jsonb),
  ('banner_landing',  '{"image_url": "", "headline": "", "subheadline": ""}'::jsonb),
  ('banner_payment',  '{"standar_image_url": "", "pro_image_url": ""}'::jsonb),
  ('contact',         '{"whatsapp": "6285113214018", "email": "aiotideaproject@gmail.com", "address": ""}'::jsonb),
  ('payment_methods', '{"midtrans_enabled": false, "manual_transfer_enabled": true, "bank_accounts": []}'::jsonb);
