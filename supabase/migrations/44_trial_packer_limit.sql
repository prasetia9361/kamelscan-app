-- ============================================================
-- 44_trial_packer_limit.sql  (Bab 7.4 / Bab 7.5)
-- ============================================================
-- Menutup celah yang ditemukan Product Owner 1 September 2026 saat menguji
-- produksi: batas 5 packer masa uji coba tidak ditegakkan di mana pun.
--
-- 🔴 CACATNYA DITULIS SENDIRI OLEH MIGRASI 39, LALU TETAP TERJADI.
--
--    Migrasi 39 bagian 3 memperingatkan dengan tepat: begitu ketiga paket
--    berbayar disetel `max_packers: -1` (tak terbatas — keputusan Product
--    Owner), masa uji coba yang meminjam konfigurasi paket Standar ikut
--    menjadi tak terbatas. Ia lalu menambalnya dengan menulis
--    `{"max_packers": 5}` ke `platform_settings` kunci `trial`.
--
--    Tambalannya benar. Yang tidak pernah terjadi: TIDAK ADA SATU PUN
--    penegak yang membaca kunci itu. Keduanya tetap membaca kunci `pricing`
--    dan mendapat -1.
--
--      create-packer/index.ts   -> pricing[tier_plan].max_packers = -1
--      check_packer_limit()     -> pricing[tier_plan].max_packers = -1
--
--    Berkas ini memperbaiki yang kedua; yang pertama diperbaiki di berkas
--    fungsinya dan WAJIB di-deploy ulang bersama migrasi ini.
--
-- ⚠️ Sisi Dart sudah benar sejak awal — `TrialConfig.maxPackers` ada, dan
--    `session_provider.dart` menimpa batas tier dengan milik trial. Justru
--    itu yang membuat cacatnya sulit terlihat: layarnya menampilkan batas
--    yang benar, dan hanya servernya yang mengizinkan lebih. Siapa pun yang
--    memeriksa dari aplikasi akan menyimpulkan tidak ada masalah.
--
-- 🔴 Kenapa dua tempat, bukan satu. `create-packer` adalah jalur aplikasi,
--    dan trigger ini adalah jaring terakhirnya. Pemegang JWT dapat memanggil
--    PostgREST langsung tanpa pernah menyentuh Edge Function mana pun —
--    alasan yang sama persis yang ditulis di kepala migrasi 38.
-- ============================================================

create or replace function public.check_packer_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tier   tier_plan;
  v_status tenant_status;
  v_max    int;
  v_count  int;
begin
  if new.role <> 'packer' then return new; end if;

  select tier_plan, status into v_tier, v_status
    from public.tenants where id = new.tenant_id;

  -- Bab 7.5 — masa uji coba dibatasi terpisah, dan sengaja TIDAK meminjam
  -- konfigurasi paket mana pun. Nilainya di kunci `trial`, bukan `pricing`.
  if v_status = 'trial' then
    select (value->>'max_packers')::int into v_max
      from public.platform_settings where key = 'trial';
    v_max := coalesce(v_max, 5);
  else
    select (value->(v_tier::text)->>'max_packers')::int into v_max
      from public.platform_settings where key = 'pricing';
  end if;

  -- ⚠️ `v_max is null` ditulis eksplisit. Versi lama hanya menguji `= -1`,
  -- dan bila pengaturannya hilang v_max menjadi NULL: `v_count >= NULL`
  -- menghasilkan NULL, yang bukan true, sehingga batasnya diam-diam lenyap.
  -- Keadaan itu tetap dipilih sebagai "tak terbatas", tetapi sekarang karena
  -- diputuskan begitu, bukan karena kecelakaan tiga nilai logika.
  if v_max is null or v_max = -1 then return new; end if;

  -- Bab 6.7 — hanya yang AKTIF dihitung. Packer nonaktif tidak memakai kursi:
  -- ia tidak dapat masuk dan tidak dapat merekam (migrasi 38).
  select count(*) into v_count from public.users
   where tenant_id = new.tenant_id and role = 'packer' and is_active;

  if v_count >= v_max then
    raise exception 'PACKER_LIMIT_REACHED' using errcode = 'P0002';
  end if;

  return new;
end;
$$;

comment on function public.check_packer_limit() is
  'Bab 7.4/7.5 - batas jumlah packer. Masa uji coba memakai '
  'platform_settings.trial.max_packers; paket berbayar memakai '
  'platform_settings.pricing.<tier>.max_packers. Jaring terakhir di belakang '
  'create-packer, karena pemegang JWT dapat memanggil PostgREST langsung.';
