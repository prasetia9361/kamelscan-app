-- ============================================================
-- 18_terms_consent.sql  (Bab 6.2)
-- ============================================================
-- Mencatat persetujuan Syarat & Ketentuan.
--
-- 🔴 Sebelum ini, centang "Saya setuju dengan Syarat & Ketentuan" di formulir
--    pendaftaran **tidak disimpan ke mana pun**. Tidak ada catatan siapa
--    menyetujui apa, kapan.
--
--    Untuk produk yang seluruh nilainya adalah BUKTI HUKUM, tidak punya
--    catatan persetujuan pelanggan adalah kelalaian yang berbalik menyerang
--    justru saat dibutuhkan — yaitu ketika ada sengketa.
--
--    Ditemukan 13 Agustus 2026 saat menelusuri mengapa pendaftaran lewat
--    Google bisa melewati kolom yang ditandai wajib di Bab 6.2.
--
-- Versi ikut disimpan, bukan sekadar `true`. Bila syarat & ketentuan berubah,
-- kita harus dapat menjawab "pelanggan ini menyetujui versi yang mana" —
-- boolean tidak dapat menjawab itu.
-- ============================================================

alter table public.users
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version     text;

comment on column public.users.terms_accepted_at is
  'Waktu pengguna menyetujui S&K. NULL = belum pernah menyetujui, wajib '
  'diarahkan ke layar Lengkapi Profil sebelum boleh memakai aplikasi.';
comment on column public.users.terms_version is
  'Versi dokumen S&K yang disetujui, mis. 2026-08-01. Diperlukan agar '
  'persetujuan tetap bermakna setelah dokumennya direvisi.';

-- Owner tanpa nomor HP juga belum lengkap: Bab 6.2 menandai nomor HP WAJIB,
-- tetapi Google tidak pernah memberikannya.
create index if not exists idx_users_incomplete_profile
  on public.users (id)
  where terms_accepted_at is null;

-- ------------------------------------------------------------
-- Trigger registrasi ikut mencatat persetujuan bila formulir mengirimnya.
--
-- Pendaftaran lewat formulir: metadata memuat `terms_version` → tercatat
-- seketika, pengguna tidak akan diminta menyetujui dua kali.
--
-- Pendaftaran lewat Google: metadata tidak memuat apa pun → NULL → aplikasi
-- mengarahkan ke layar Lengkapi Profil.
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tenant  uuid;
  v_role    text := coalesce(new.raw_user_meta_data->>'role', 'owner');
  v_quota   int;
  v_terms   text := nullif(new.raw_user_meta_data->>'terms_version', '');
begin
  if v_role = 'packer' then
    insert into public.users (
      id, tenant_id, email, full_name, phone, role, created_by,
      terms_accepted_at, terms_version
    )
    values (new.id,
            (new.raw_user_meta_data->>'tenant_id')::uuid,
            new.email,
            coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
            new.raw_user_meta_data->>'phone',
            'packer',
            (new.raw_user_meta_data->>'created_by')::uuid,
            -- Packer memakai akun yang dibuatkan Owner; persetujuan diberikan
            -- Owner atas nama tenant, jadi packer tidak diminta menyetujui.
            now(), 'inherited-from-owner');
    insert into public.user_settings (user_id) values (new.id);
    return new;
  end if;

  insert into public.tenants (id, owner_id, business_name, tier_plan, status, period_end)
  values (gen_random_uuid(), new.id, new.raw_user_meta_data->>'business_name', 'standar', 'trial', null)
  returning id into v_tenant;

  insert into public.users (
    id, tenant_id, email, username, full_name, phone, role,
    terms_accepted_at, terms_version
  )
  values (new.id, v_tenant, new.email,
          new.raw_user_meta_data->>'username',
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
          new.raw_user_meta_data->>'phone',
          'owner',
          case when v_terms is null then null else now() end,
          v_terms);

  select (value->>'tokens')::int into v_quota
  from public.platform_settings where key = 'trial';

  insert into public.token_wallets (tenant_id, balance, monthly_quota, period_end)
  values (v_tenant, coalesce(v_quota,100), coalesce(v_quota,100), null);

  insert into public.token_ledger (tenant_id, delta, reason, balance_after, note)
  values (v_tenant, coalesce(v_quota,100), 'monthly_reset', coalesce(v_quota,100), 'Kuota uji coba gratis');

  insert into public.tenant_settings (tenant_id) values (v_tenant);
  insert into public.user_settings   (user_id)   values (new.id);
  return new;
end;
$$;

-- ------------------------------------------------------------
-- Pencatat persetujuan dari layar Lengkapi Profil.
--
-- Dibuat sebagai RPC, bukan UPDATE langsung dari klien, agar waktunya
-- ditentukan SERVER. Jam perangkat dapat dimundurkan, dan catatan persetujuan
-- yang waktunya berasal dari HP pelanggan tidak ada gunanya saat disengketakan
-- (alasan yang sama dengan `scan_date` di Bab 5.5b).
-- ------------------------------------------------------------
create or replace function public.accept_terms(p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'UNAUTHORIZED';
  end if;
  if coalesce(trim(p_version), '') = '' then
    raise exception 'TERMS_VERSION_REQUIRED';
  end if;

  update public.users
     set terms_accepted_at = now(),
         terms_version     = trim(p_version),
         updated_at        = now()
   where id = auth.uid();
end;
$$;

grant execute on function public.accept_terms(text) to authenticated;
revoke execute on function public.accept_terms(text) from anon, public;
