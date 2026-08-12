-- ============================================================
-- 12_auth_hook.sql  (Bab 5.3) — sisipkan tenant_id & role ke JWT
-- ============================================================
-- 🔴 SETELAH menjalankan berkas ini, aktifkan hook-nya di
--    Dashboard > Authentication > Hooks > Customize Access Token.
--    Tanpa langkah itu JWT tidak akan berisi tenant_id dan SELURUH policy RLS
--    akan menolak semua akses.
--
-- ⚠️ Jebakan klasik (Bab 5.3): policy RLS pada tabel `users` yang di dalamnya
--    melakukan select ke `users` menyebabkan REKURSI TAK TERBATAS dan
--    mematikan seluruh API. Karena itu tenant_id & role dibaca dari JWT,
--    bukan dari tabel.
-- ============================================================

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims   jsonb;
  u_role   text;
  u_tenant uuid;
  u_tier   text;
begin
  select r.role::text, r.tenant_id, t.tier_plan::text
    into u_role, u_tenant, u_tier
  from public.users r
  join public.tenants t on t.id = r.tenant_id
  where r.id = (event->>'user_id')::uuid;

  claims := event->'claims';
  if u_role is not null then
    claims := jsonb_set(claims, '{app_role}',   to_jsonb(u_role));
    claims := jsonb_set(claims, '{tenant_id}',  to_jsonb(u_tenant));
    claims := jsonb_set(claims, '{tier_plan}',  to_jsonb(u_tier));
  end if;

  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

-- Hook dijalankan sebagai supabase_auth_admin; ia perlu membaca dua tabel ini.
grant usage on schema public to supabase_auth_admin;
grant select on public.users, public.tenants to supabase_auth_admin;
