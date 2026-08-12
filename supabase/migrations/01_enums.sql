-- ============================================================
-- 01_enums.sql  (Bab 5.2)
-- ============================================================
-- Nilai di sini harus SAMA PERSIS dengan lib/core/models/enums.dart.
-- Mengubah salah satu tanpa yang lain akan memutus serialisasi.
-- ============================================================

create type user_role       as enum ('admin', 'owner', 'packer');
create type tier_plan       as enum ('standar', 'pro');
create type video_type      as enum ('packing', 'return');
create type video_status    as enum ('pending_upload', 'uploading', 'uploaded', 'failed', 'expired', 'deleted');
create type tenant_status   as enum ('trial', 'active', 'suspended', 'expired');
create type sub_status      as enum ('pending', 'paid', 'failed', 'expired', 'cancelled');
create type ledger_reason   as enum ('video_upload', 'monthly_reset', 'plan_upgrade', 'admin_adjust', 'refund');
