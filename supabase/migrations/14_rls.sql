-- ============================================================
-- 14_rls.sql  (Bab 5.4) — Row Level Security
-- ============================================================
-- 🔴 Bab 2.3: INI penegakan hak akses yang sesungguhnya. Lapisan Flutter hanya
--    menyembunyikan tombol — itu soal kenyamanan, BUKAN keamanan.
--    Setiap policy harus diuji dengan asumsi penyerang memakai JWT valid dan
--    memanggil API langsung tanpa lewat aplikasi.
-- ============================================================

alter table public.tenants           enable row level security;
alter table public.users             enable row level security;
alter table public.shops             enable row level security;
alter table public.shop_packers      enable row level security;
alter table public.package_videos    enable row level security;
alter table public.token_wallets     enable row level security;
alter table public.token_ledger      enable row level security;
alter table public.subscriptions     enable row level security;
alter table public.user_settings     enable row level security;
alter table public.tenant_settings   enable row level security;
alter table public.platform_settings enable row level security;
alter table public.promos            enable row level security;
alter table public.tutorials         enable row level security;
alter table public.audit_logs        enable row level security;

-- ---------- tenants ----------
create policy tenants_select on public.tenants for select
  using (id = public.current_tenant_id() or public.is_admin());
create policy tenants_update_admin on public.tenants for update
  using (public.is_admin()) with check (public.is_admin());

-- ---------- users ----------
create policy users_select_self_or_tenant on public.users for select
  using (
    id = auth.uid()
    or tenant_id = public.current_tenant_id()
    or public.is_admin()
  );

create policy users_update_self on public.users for update
  using (id = auth.uid())
  with check (
    id = auth.uid()
    -- pengguna tidak boleh menaikkan role atau pindah tenant
    and role      = (select role      from public.users where id = auth.uid())
    and tenant_id = (select tenant_id from public.users where id = auth.uid())
  );

create policy users_owner_manage_packers on public.users for update
  using (public.is_owner() and tenant_id = public.current_tenant_id() and role = 'packer')
  with check (public.is_owner() and tenant_id = public.current_tenant_id() and role = 'packer');

create policy users_owner_delete_packers on public.users for delete
  using (public.is_owner() and tenant_id = public.current_tenant_id() and role = 'packer');

create policy users_admin_all on public.users for all
  using (public.is_admin()) with check (public.is_admin());

-- CATATAN: INSERT ke public.users TIDAK diberi policy untuk 'authenticated'.
-- Pembuatan akun hanya lewat trigger handle_new_user (registrasi mandiri)
-- atau Edge Function service-role (pembuatan packer oleh Owner). Lihat Bab 6.

-- ---------- shops ----------
create policy shops_select on public.shops for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
create policy shops_write_owner on public.shops for all
  using ((public.is_owner() and tenant_id = public.current_tenant_id()) or public.is_admin())
  with check ((public.is_owner() and tenant_id = public.current_tenant_id()) or public.is_admin());

-- ---------- shop_packers ----------
create policy shop_packers_select on public.shop_packers for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
create policy shop_packers_write_owner on public.shop_packers for all
  using (public.is_owner() and tenant_id = public.current_tenant_id())
  with check (public.is_owner() and tenant_id = public.current_tenant_id());

-- ---------- package_videos ----------
create policy videos_select on public.package_videos for select
  using (
    public.is_admin()
    or (
      tenant_id = public.current_tenant_id()
      and (
        public.current_app_role() in ('owner')
        or user_id = auth.uid()
        or exists (                                   -- packer boleh lihat se-toko bila diizinkan Owner
          select 1 from public.tenant_settings ts
          join public.shop_packers sp
            on sp.user_id = auth.uid() and sp.shop_id = package_videos.shop_id
          where ts.tenant_id = package_videos.tenant_id
            and ts.shop_history_visible_to_packer
        )
      )
    )
  );

create policy videos_insert on public.package_videos for insert
  with check (
    tenant_id = public.current_tenant_id()
    and user_id = auth.uid()
    and exists (
      select 1 from public.shops s
       where s.id = shop_id
         and s.tenant_id = public.current_tenant_id()
         and s.is_active
    )
  );

-- Perekam boleh memperbarui barisnya sendiri (status upload); Owner boleh
-- semua di tenant-nya.
create policy videos_update on public.package_videos for update
  using (
    public.is_admin()
    or (tenant_id = public.current_tenant_id() and (public.is_owner() or user_id = auth.uid()))
  )
  with check (tenant_id = public.current_tenant_id() or public.is_admin());

create policy videos_delete_owner on public.package_videos for delete
  using (public.is_admin() or (public.is_owner() and tenant_id = public.current_tenant_id()));

-- ---------- token_wallets & ledger : baca saja dari klien ----------
create policy wallet_select on public.token_wallets for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
create policy ledger_select on public.token_ledger for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
-- Tidak ada policy INSERT/UPDATE: hanya trigger & Edge Function (service role)
-- yang boleh menulis. Bab 5.1 poin 4 — penghitungan kuota SELALU di server.

-- ---------- subscriptions ----------
create policy sub_select on public.subscriptions for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
create policy sub_insert_owner on public.subscriptions for insert
  with check (public.is_owner() and tenant_id = public.current_tenant_id() and status = 'pending');
create policy sub_admin_all on public.subscriptions for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- settings ----------
create policy usettings_self on public.user_settings for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy tsettings_select on public.tenant_settings for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
create policy tsettings_write_owner on public.tenant_settings for update
  using ((public.is_owner() and tenant_id = public.current_tenant_id()) or public.is_admin())
  with check ((public.is_owner() and tenant_id = public.current_tenant_id()) or public.is_admin());

create policy psettings_read_all on public.platform_settings for select using (true);
create policy psettings_write_admin on public.platform_settings for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- promos & tutorials ----------
create policy promos_read on public.promos for select using (is_active);
create policy promos_admin on public.promos for all
  using (public.is_admin()) with check (public.is_admin());

create policy tutorials_read on public.tutorials for select using (is_active);
create policy tutorials_admin on public.tutorials for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- audit ----------
create policy audit_select on public.audit_logs for select
  using (tenant_id = public.current_tenant_id() or public.is_admin());
