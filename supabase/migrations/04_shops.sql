-- ============================================================
-- 04_shops.sql  (Bab 5.2)
-- ============================================================

create table public.shops (
  id                    uuid primary key default uuid_generate_v4(),
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  market_name           text not null,                 -- Shopee, Tokopedia, TikTok Shop, Lazada, Lainnya
  shop_name             text not null,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint uq_shop_per_tenant unique (tenant_id, market_name, shop_name)
);
create index idx_shops_tenant on public.shops(tenant_id);

-- Penugasan packer ke toko (many-to-many).
-- Bab 0.3: packer boleh dipindah antar toko; video yang sudah terekam tetap
-- terikat pada toko saat perekaman terjadi.
create table public.shop_packers (
  shop_id               uuid not null references public.shops(id) on delete cascade,
  user_id               uuid not null references public.users(id) on delete cascade,
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  assigned_at           timestamptz not null default now(),
  primary key (shop_id, user_id)
);
create index idx_shop_packers_user on public.shop_packers(user_id);
