-- ============================================================
-- 13_helpers.sql  (Bab 5.3)
-- ============================================================

create or replace function public.current_tenant_id()
returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id','')::uuid
$$;

create or replace function public.current_app_role()
returns text language sql stable as $$
  select coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'app_role', 'anon')
$$;

create or replace function public.is_admin()
returns boolean language sql stable as $$ select public.current_app_role() = 'admin' $$;

create or replace function public.is_owner()
returns boolean language sql stable as $$ select public.current_app_role() = 'owner' $$;

-- ------------------------------------------------------------
-- ⚠️ TAMBAHAN DI LUAR BAB 5.3 — dibutuhkan agar kolom NOT NULL
--    `users.email_normalized` (Bab 5.2) bisa terisi.
--
-- Bab 7.5 mewajibkan penutupan celah alias Gmail: satu orang bisa mendaftar
-- berkali-kali dengan nama+1@gmail.com, nama+2@gmail.com dan memperoleh 100
-- video gratis tiap kali. Aturannya: buang bagian setelah '+', dan hapus titik
-- khusus domain gmail.
--
-- Ini kembaran server dari Validators.normalizeEmail di Flutter. Yang di sini
-- adalah SUMBER KEBENARANNYA — sisi klien hanya untuk umpan balik dini.
-- ------------------------------------------------------------
create or replace function public.normalize_email(p_email text)
returns citext language sql immutable as $$
  select case
    when p_email is null or position('@' in p_email) = 0 then lower(p_email)::citext
    else (
      select case
        when d in ('gmail.com', 'googlemail.com')
          then (replace(l, '.', '') || '@gmail.com')::citext
        else (l || '@' || d)::citext
      end
      from (
        select split_part(lower(split_part(p_email, '@', 1)), '+', 1) as l,
               lower(split_part(p_email, '@', 2))                     as d
      ) parts
    )
  end
$$;

-- Bab 7.7 — dipanggil Flutter tepat setelah kode terbaca dan SEBELUM kamera
-- mulai merekam, agar packer tidak merekam 30 detik lalu baru ditolak.
create or replace function public.resi_exists(p_resi text, p_type video_type)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.package_videos
     where tenant_id = public.current_tenant_id()
       and resi_code = p_resi
       and type      = p_type
       and status   <> 'deleted'
  );
$$;
