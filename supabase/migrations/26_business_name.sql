-- ============================================================
-- 26_business_name.sql  (Bab 6.2)
-- ============================================================
-- Owner harus dapat mengisi nama usahanya sendiri.
--
-- 🔴 Sebelum ini ia TIDAK BISA, dan tidak ada satu layar pun yang menutupinya.
--
--    `business_name` hanya terisi lewat `raw_user_meta_data` saat pendaftaran
--    lewat formulir. Pendaftaran lewat "Lanjutkan dengan Google" tidak pernah
--    mengirim metadata apa pun, sehingga kolomnya NULL — dan satu-satunya
--    policy tulis pada `public.tenants` adalah `tenants_update_admin`
--    (14_rls.sql), yang hanya mengizinkan Admin.
--
--    Akibatnya nyata dan terlihat: bilah atas aplikasi menampilkan nama usaha
--    (`mobile_app_bar.dart`), dan bagi pendaftar lewat Google ia kosong
--    selamanya. Layar Edit Profil pun tidak dapat menolong — ia menulis ke
--    `users`, bukan `tenants`.
--
--    Dilaporkan Product Owner 24 Agustus 2026 sebagai "formulir pendaftaran
--    lewat Google tidak sama dengan pendaftaran manual".
--
-- Dibuat sebagai RPC `security definer`, BUKAN dengan melonggarkan
-- `tenants_update_admin`, karena tabel `tenants` memuat kolom yang tidak boleh
-- disentuh Owner sama sekali: `tier_plan`, `status`, `period_end`,
-- `trial_used`. Membuka UPDATE untuk Owner demi satu kolom berarti membuka
-- jalan menaikkan paketnya sendiri dan memperpanjang masa uji cobanya sendiri.
-- Alasan yang sama melahirkan `guard_subscription_owner_update` di migrasi 25.
--
-- Fungsi ini hanya menyentuh `business_name`, hanya pada tenant milik
-- pemanggilnya, dan hanya bila pemanggilnya benar-benar Owner.
-- ============================================================

create or replace function public.set_business_name(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHORIZED';
  end if;

  -- Perannya dibaca dari tabel, bukan dari klaim JWT. JWT membawa nilai lama
  -- sampai disegarkan (Bab 5.3), dan operasi tulis tidak boleh bergantung
  -- pada itu.
  select tenant_id into v_tenant
    from public.users
   where id = auth.uid() and role = 'owner';

  if v_tenant is null then
    raise exception 'FORBIDDEN';
  end if;

  -- Kosong disimpan sebagai NULL, bukan string kosong: bilah atas aplikasi
  -- memeriksa `(businessName ?? '').trim()`, dan dua bentuk "tidak diisi"
  -- hanya akan membingungkan pembaca kueri berikutnya.
  --
  -- `updated_at` sengaja tidak disetel di sini — trigger `trg_touch_tenants`
  -- (15_triggers.sql) sudah mengerjakannya.
  update public.tenants
     set business_name = nullif(trim(p_name), '')
   where id = v_tenant;
end;
$$;

grant execute on function public.set_business_name(text) to authenticated;
revoke execute on function public.set_business_name(text) from anon, public;

comment on function public.set_business_name(text) is
  'Bab 6.2 — Owner mengisi nama usahanya sendiri. Satu-satunya jalan tulis '
  'Owner ke public.tenants; sengaja dibatasi pada satu kolom.';
