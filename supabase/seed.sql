-- ============================================================
-- seed.sql  (Bab 5.7) — data uji minimum
-- ============================================================
-- Isi: 1 admin, 2 owner (satu `standar`, satu `pro`), masing-masing 2 toko dan
-- 3 packer, serta 30 video dengan tanggal tersebar.
--
-- 🔴 JANGAN DIJALANKAN DI DATABASE PRODUKSI.
--    Berkas ini membuat akun dengan password yang tertulis terang-terangan dan
--    email @example.com. Bab 5.7 memintanya untuk PENGUJIAN — tanpa data ini,
--    pengujian RLS tidak bisa dilakukan dengan benar.
--
--    Pengaman di bawah akan membatalkan eksekusi bila database sudah berisi
--    pengguna sungguhan. Hapus pengaman itu hanya bila Anda yakin.
--
-- Password semua akun uji: Password123
-- ============================================================

do $$
begin
  if exists (
    select 1 from public.users
     where email not like '%@example.com'
  ) then
    raise exception 'DIBATALKAN: database sudah berisi pengguna non-uji. '
                    'seed.sql hanya untuk database pengembangan.';
  end if;
end $$;

-- ------------------------------------------------------------
-- Trigger dimatikan sementara.
--
-- `before_video_insert` membaca auth.uid() untuk menentukan tenant; saat seed
-- dijalankan dari SQL editor tidak ada sesi login sehingga auth.uid() NULL dan
-- trigger akan menolak dengan USER_NOT_FOUND. `after_video_uploaded` juga
-- dimatikan agar saldo token tidak ikut terpotong 30 kali oleh data palsu.
-- ------------------------------------------------------------
alter table public.package_videos disable trigger trg_before_video_insert;
alter table public.package_videos disable trigger trg_after_video_uploaded;

-- ------------------------------------------------------------
-- Pembuat akun uji.
--
-- Menyisipkan langsung ke auth.users akan memicu trigger on_auth_user_created,
-- sehingga tenant, profil, dompet, dan pengaturan ikut terbentuk persis seperti
-- registrasi sungguhan — itulah yang ingin diuji.
--
-- ⚠️ Kolom auth.identities.provider_id hanya ada pada GoTrue versi baru. Bila
--    database Anda menolak kolom itu, hapus blok insert auth.identities di
--    bawah; akun tetap terbentuk, hanya login berbasis password yang perlu
--    diatur ulang.
-- ------------------------------------------------------------
create or replace function public.seed_auth_user(
  p_id uuid, p_email text, p_meta jsonb
) returns void language plpgsql security definer as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    -- `extensions.` wajib: pgcrypto dipasang di schema extensions, bukan
    -- public (lihat penyimpangan #4 di README).
    p_email, extensions.crypt('Password123', extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    p_meta, '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_id, p_id::text,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email', now(), now(), now()
  );
end $$;

do $$
declare
  v_admin    uuid := '00000000-0000-4000-a000-000000000001';
  v_owner_s  uuid := '00000000-0000-4000-a000-000000000002';
  v_owner_p  uuid := '00000000-0000-4000-a000-000000000003';
  v_tenant_s uuid;
  v_tenant_p uuid;
  v_packer   uuid;
  v_shops_s  uuid[];
  v_shops_p  uuid[];
  v_packers_s uuid[] := '{}';
  v_packers_p uuid[] := '{}';
  i          int;
  j          int;
begin
  -- ---------- akun auth ----------
  -- Admin dibuat lebih dulu tanpa lewat handle_new_user sebagai owner:
  -- role admin diberikan setelahnya (Bab 2.1 — tidak ada jalur registrasi admin).
  perform public.seed_auth_user(v_admin,   'admin@example.com',
    '{"role":"owner","full_name":"Admin Platform","business_name":"KamelScan"}'::jsonb);
  perform public.seed_auth_user(v_owner_s, 'owner.standar@example.com',
    '{"role":"owner","full_name":"Budi Standar","business_name":"Toko Budi","username":"budi.std"}'::jsonb);
  perform public.seed_auth_user(v_owner_p, 'owner.pro@example.com',
    '{"role":"owner","full_name":"Sari Pro","business_name":"Toko Sari","username":"sari.pro"}'::jsonb);

  select tenant_id into v_tenant_s from public.users where id = v_owner_s;
  select tenant_id into v_tenant_p from public.users where id = v_owner_p;

  -- Admin: naikkan role, dan aktifkan tenant-nya agar tidak tampak sebagai trial
  update public.users   set role = 'admin' where id = v_admin;
  update public.tenants set status = 'active', period_end = now() + interval '365 days'
   where owner_id = v_admin;

  -- Owner standar tetap 'trial' (menguji jalur uji coba gratis Bab 7.5).
  -- Owner pro dijadikan berlangganan aktif.
  update public.tenants
     set tier_plan = 'pro', status = 'active',
         period_end = now() + interval '30 days'
   where id = v_tenant_p;
  update public.token_wallets
     set balance = 5000, monthly_quota = 5000, period_end = now() + interval '30 days'
   where tenant_id = v_tenant_p;

  -- ---------- toko ----------
  insert into public.shops (tenant_id, market_name, shop_name) values
    (v_tenant_s, 'Shopee',     'Budi Store Shopee'),
    (v_tenant_s, 'Tokopedia',  'Budi Store Tokopedia');
  select array_agg(id order by created_at) into v_shops_s
    from public.shops where tenant_id = v_tenant_s;

  insert into public.shops (tenant_id, market_name, shop_name) values
    (v_tenant_p, 'TikTok Shop', 'Sari Official'),
    (v_tenant_p, 'Lazada',      'Sari Lazada');
  select array_agg(id order by created_at) into v_shops_p
    from public.shops where tenant_id = v_tenant_p;

  -- ---------- packer ----------
  for i in 1..3 loop
    v_packer := gen_random_uuid();
    perform public.seed_auth_user(
      v_packer,
      format('packer.std%s@example.com', i),
      jsonb_build_object('role','packer','tenant_id',v_tenant_s,
                         'full_name', format('Packer Budi %s', i),
                         'created_by', v_owner_s)
    );
    v_packers_s := v_packers_s || v_packer;
    insert into public.shop_packers (shop_id, user_id, tenant_id)
    values (v_shops_s[1 + (i % 2)], v_packer, v_tenant_s);
  end loop;

  for i in 1..3 loop
    v_packer := gen_random_uuid();
    perform public.seed_auth_user(
      v_packer,
      format('packer.pro%s@example.com', i),
      jsonb_build_object('role','packer','tenant_id',v_tenant_p,
                         'full_name', format('Packer Sari %s', i),
                         'created_by', v_owner_p)
    );
    v_packers_p := v_packers_p || v_packer;
    insert into public.shop_packers (shop_id, user_id, tenant_id)
    values (v_shops_p[1 + (i % 2)], v_packer, v_tenant_p);
  end loop;

  -- ---------- 30 video, tanggal tersebar ----------
  -- 15 milik tenant standar, 15 milik tenant pro. Sengaja dibuat dua tenant
  -- agar uji kebocoran RLS (Bab 5.7) punya lawan bandingnya.
  for i in 1..15 loop
    insert into public.package_videos (
      tenant_id, shop_id, user_id, resi_code, type, status,
      scan_date, duration_seconds, file_size_bytes,
      location_lat, location_lng, storage_key, expires_at, uploaded_at
    ) values (
      v_tenant_s,
      v_shops_s[1 + (i % 2)],
      v_packers_s[1 + (i % 3)],
      format('SPXID%s', lpad(i::text, 9, '0')),
      case when i % 5 = 0 then 'return'::video_type else 'packing'::video_type end,
      'uploaded',
      now() - make_interval(days => i),
      20 + (i % 10),
      3000000 + i * 120000,
      -6.2 + (i * 0.001), 106.8 + (i * 0.001),
      format('tenant/%s/2026/08/seed-%s.mp4', v_tenant_s, i),
      now() + make_interval(days => 30 - i),
      now() - make_interval(days => i)
    );
  end loop;

  for j in 1..15 loop
    insert into public.package_videos (
      tenant_id, shop_id, user_id, resi_code, type, status,
      scan_date, duration_seconds, file_size_bytes,
      location_lat, location_lng, storage_key, expires_at, uploaded_at
    ) values (
      v_tenant_p,
      v_shops_p[1 + (j % 2)],
      v_packers_p[1 + (j % 3)],
      format('TKSID%s', lpad(j::text, 9, '0')),
      case when j % 4 = 0 then 'return'::video_type else 'packing'::video_type end,
      case when j = 15 then 'pending_upload'::video_status else 'uploaded'::video_status end,
      now() - make_interval(days => j),
      30 + (j % 25),
      5000000 + j * 150000,
      -7.25 + (j * 0.001), 112.75 + (j * 0.001),
      format('tenant/%s/2026/08/seed-%s.mp4', v_tenant_p, j),
      now() + make_interval(days => 60 - j),
      case when j = 15 then null else now() - make_interval(days => j) end
    );
  end loop;
end $$;

alter table public.package_videos enable trigger trg_before_video_insert;
alter table public.package_videos enable trigger trg_after_video_uploaded;

-- Fungsi bantu seed tidak boleh tertinggal di database: ia menyisipkan ke
-- auth.users dengan hak security definer.
drop function if exists public.seed_auth_user(uuid, text, jsonb);

-- ------------------------------------------------------------
-- Tutorial contoh (Bab 0.2 poin 14)
-- ------------------------------------------------------------
insert into public.tutorials (step_order, title, description, youtube_url) values
  (1, 'Membuat toko pertama',   'Menambahkan akun marketplace ke KamelScan', 'https://youtube.com/watch?v=placeholder1'),
  (2, 'Menambah akun packer',   'Membuatkan akun untuk karyawan',            'https://youtube.com/watch?v=placeholder2'),
  (3, 'Merekam video packing',  'Scan resi, rekam, dan unggah',              'https://youtube.com/watch?v=placeholder3'),
  (4, 'Membagikan bukti',       'Membuat tautan publik untuk marketplace',   'https://youtube.com/watch?v=placeholder4');
