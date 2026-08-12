-- ============================================================
-- 15_triggers.sql  (Bab 5.5)
-- ============================================================

-- ------------------------------------------------------------
-- ⚠️ TAMBAHAN DI LUAR BAB 5.5 — WAJIB.
--
-- `users.email_normalized` bersifat NOT NULL (Bab 5.2), tetapi trigger
-- handle_new_user di Bab 5.5 tidak pernah mengisinya, sehingga registrasi
-- PASTI gagal dengan pelanggaran not-null.
--
-- Dijadikan trigger tersendiri, bukan ditambal di dalam handle_new_user,
-- supaya invariannya tetap terjaga dari mana pun baris users disisipkan atau
-- emailnya diubah — termasuk lewat Edge Function pembuatan packer.
-- ------------------------------------------------------------
create or replace function public.set_email_normalized()
returns trigger language plpgsql as $$
begin
  new.email_normalized := public.normalize_email(new.email);
  return new;
end;
$$;

drop trigger if exists trg_users_email_normalized on public.users;
create trigger trg_users_email_normalized
  before insert or update of email on public.users
  for each row execute function public.set_email_normalized();

-- ------------------------------------------------------------
-- (a) Registrasi mandiri: buat tenant + profil owner + dompet + pengaturan
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tenant uuid;
  v_role   text := coalesce(new.raw_user_meta_data->>'role', 'owner');
  v_quota  int;
begin
  -- Packer dibuat lewat Edge Function yang sudah mengisi tenant_id di metadata
  if v_role = 'packer' then
    insert into public.users (id, tenant_id, email, full_name, phone, role, created_by)
    values (new.id,
            (new.raw_user_meta_data->>'tenant_id')::uuid,
            new.email,
            coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
            new.raw_user_meta_data->>'phone',
            'packer',
            (new.raw_user_meta_data->>'created_by')::uuid);
    insert into public.user_settings (user_id) values (new.id);
    return new;
  end if;

  -- Owner baru: langsung masuk masa UJI COBA (Bab 7.5)
  -- Urutan tenants→users hanya mungkin karena fk_tenants_owner dibuat
  -- DEFERRABLE INITIALLY DEFERRED di 03_users.sql.
  insert into public.tenants (id, owner_id, business_name, tier_plan, status, period_end)
  values (gen_random_uuid(), new.id, new.raw_user_meta_data->>'business_name', 'standar', 'trial', null)
  returning id into v_tenant;

  insert into public.users (id, tenant_id, email, username, full_name, phone, role)
  values (new.id, v_tenant, new.email,
          new.raw_user_meta_data->>'username',
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
          new.raw_user_meta_data->>'phone',
          'owner');

  -- Dompet diisi kuota UJI COBA (100 video), bukan kuota bulanan tier
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- (b) Isi otomatis tenant_id, scan_date, dan expires_at pada video
-- ------------------------------------------------------------
create or replace function public.before_video_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tenant uuid;
  v_tier   tier_plan;
  v_status tenant_status;
  v_days   int;
  v_bal    int;
begin
  select tenant_id into v_tenant from public.users where id = auth.uid();
  if v_tenant is null then raise exception 'USER_NOT_FOUND'; end if;

  select tier_plan, status into v_tier, v_status
    from public.tenants where id = v_tenant;

  -- Bab 7.6: langganan berakhir / ditangguhkan = TERKUNCI SEKETIKA,
  -- tanpa masa tenggang.
  if v_status not in ('trial','active') then
    raise exception 'SUBSCRIPTION_INACTIVE' using errcode = 'P0003';
  end if;

  select (value->(v_tier::text)->>'retention_days')::int into v_days
  from public.platform_settings where key = 'pricing';

  -- Bab 7.3: tolak bila kuota habis. INI penegakan sesungguhnya — bukan
  -- pengecekan di Flutter. `for update` menutup kondisi balapan saat beberapa
  -- packer merekam bersamaan.
  select balance into v_bal from public.token_wallets where tenant_id = v_tenant for update;
  if coalesce(v_bal,0) <= 0 then
    if v_status = 'trial' then
      raise exception 'TRIAL_EXHAUSTED' using errcode = 'P0004';
    else
      raise exception 'TOKEN_EXHAUSTED' using errcode = 'P0001';
    end if;
  end if;

  new.tenant_id  := v_tenant;
  new.scan_date  := now();                    -- waktu server, anti manipulasi jam HP
  new.expires_at := now() + make_interval(days => coalesce(v_days,30));
  return new;
end;
$$;

drop trigger if exists trg_before_video_insert on public.package_videos;
create trigger trg_before_video_insert
  before insert on public.package_videos
  for each row execute function public.before_video_insert();

-- ------------------------------------------------------------
-- (c) Potong 1 token saat video BERHASIL diunggah (bukan saat direkam)
-- ------------------------------------------------------------
create or replace function public.after_video_uploaded()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_new int;
begin
  -- ⚠️ PENYIMPANGAN DARI BAB 5.5c: dokumen menulis
  --   `coalesce(old.status,'') <> 'uploaded'`
  -- yang TIDAK BISA dikompilasi — old.status bertipe enum video_status dan
  -- PostgreSQL menolak coalesce(video_status, text) dengan
  -- "COALESCE types video_status and text cannot be matched".
  -- `is distinct from` menangani NULL dengan benar tanpa memaksa tipe.
  if new.status = 'uploaded' and old.status is distinct from 'uploaded' then
    update public.token_wallets
       set balance = greatest(balance - 1, 0), updated_at = now()
     where tenant_id = new.tenant_id
    returning balance into v_new;

    insert into public.token_ledger (tenant_id, video_id, delta, reason, balance_after)
    values (new.tenant_id, new.id, -1, 'video_upload', v_new);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_after_video_uploaded on public.package_videos;
create trigger trg_after_video_uploaded
  after update on public.package_videos
  for each row execute function public.after_video_uploaded();

-- ------------------------------------------------------------
-- (d) Batasi jumlah packer sesuai tier (Bab 2.2 catatan 1)
-- ------------------------------------------------------------
create or replace function public.check_packer_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_tier tier_plan; v_max int; v_count int;
begin
  if new.role <> 'packer' then return new; end if;

  select tier_plan into v_tier from public.tenants where id = new.tenant_id;
  select (value->(v_tier::text)->>'max_packers')::int into v_max
    from public.platform_settings where key='pricing';

  if v_max = -1 then return new; end if;   -- unlimited (tier pro)

  select count(*) into v_count from public.users
   where tenant_id = new.tenant_id and role = 'packer' and is_active;

  if v_count >= v_max then
    raise exception 'PACKER_LIMIT_REACHED' using errcode = 'P0002';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_packer_limit on public.users;
create trigger trg_check_packer_limit
  before insert on public.users
  for each row execute function public.check_packer_limit();

-- ------------------------------------------------------------
-- (e) updated_at otomatis
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists trg_touch_users on public.users;
create trigger trg_touch_users   before update on public.users   for each row execute function public.touch_updated_at();
drop trigger if exists trg_touch_shops on public.shops;
create trigger trg_touch_shops   before update on public.shops   for each row execute function public.touch_updated_at();
drop trigger if exists trg_touch_tenants on public.tenants;
create trigger trg_touch_tenants before update on public.tenants for each row execute function public.touch_updated_at();
