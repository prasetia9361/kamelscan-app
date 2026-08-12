-- ============================================================
-- 03_users.sql  (Bab 5.2) — profil aplikasi, terhubung ke auth.users
-- ============================================================
-- 🔴 Password TIDAK PERNAH disimpan di sini. Supabase Auth mengelolanya di
--    skema `auth` (Bab 0.4 poin 3).
-- ============================================================

create table public.users (
  id                    uuid primary key references auth.users(id) on delete cascade,
  tenant_id             uuid not null references public.tenants(id) on delete cascade,
  email                 citext not null unique,        -- bentuk asli, untuk pengiriman surat
  email_normalized      citext not null unique,        -- tanpa alias '+' & titik gmail (Bab 7.5)
  username              text unique,
  full_name             text not null,
  phone                 text,
  avatar_url            text,
  role                  user_role not null default 'packer',
  is_active             boolean not null default true,
  last_login_at         timestamptz,
  created_by            uuid references public.users(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint chk_username_format check (username is null or username ~ '^[a-z0-9._]{4,20}$')
);

-- ------------------------------------------------------------
-- ⚠️ PENYIMPANGAN DARI BAB 5.2 — WAJIB, BUKAN PILIHAN.
--
-- Bab 5.2 menulis FK ini tanpa DEFERRABLE. Dengan begitu, trigger
-- `handle_new_user` (Bab 5.5a) PASTI GAGAL pada registrasi pertama:
--
--   1. tenants disisipkan lebih dulu dengan owner_id = <id user baru>
--   2. baris users dengan id itu BARU disisipkan sesudahnya
--
-- Pada langkah 1 baris users belum ada → pelanggaran foreign key seketika.
-- tenants.owner_id → users.id dan users.tenant_id → tenants.id saling
-- melingkar, sehingga salah satunya HARUS ditangguhkan sampai akhir
-- transaksi. Menghapus urutan melingkar ini akan mengubah skema Bab 5.2
-- lebih jauh, jadi dipilih perubahan yang paling kecil.
-- ------------------------------------------------------------
alter table public.tenants
  add constraint fk_tenants_owner
  foreign key (owner_id) references public.users(id) on delete cascade
  deferrable initially deferred;

create index idx_users_tenant on public.users(tenant_id);
create index idx_users_role   on public.users(role);
