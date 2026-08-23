-- ============================================================
-- 21_realtime_publication.sql  (Bab 9.2 — kartu monitoring real-time)
-- ============================================================
-- 🔴 TEMUAN 18 Agustus 2026: publikasi `supabase_realtime` ada, tetapi
--    **tidak berisi satu tabel pun**:
--
--      select * from pg_publication_tables where pubname = 'supabase_realtime';
--      → 0 baris
--
--    PostgreSQL hanya mengalirkan perubahan untuk tabel yang terdaftar di
--    publikasi. Tanpa baris di sana, Realtime tidak mengirim apa-apa — dan
--    yang membuatnya mahal: **tidak ada error, tidak ada peringatan**.
--    Langganannya "berhasil", lalu diam selamanya. Ini kerabat dekat jebakan 4
--    di PROMPT_SESI_BARU.md (Auth Hook mati → semua tabel mengembalikan nol
--    baris tanpa pesan apa pun).
--
--    ⚠️ Akibatnya bukan hanya pada Bab 9.2. `TokenRepository.watchWallet`
--    sudah ada di kode sejak Bab 7 dan dipakai `tokenWalletStreamProvider`
--    agar indikator token ikut berubah saat packer lain menyelesaikan
--    unggahan. Fitur itu **tidak pernah hidup**, dan tidak ada yang tahu
--    karena tidak ada gejalanya.
-- ============================================================

-- ------------------------------------------------------------
-- Kenapa hanya dua tabel ini
-- ------------------------------------------------------------
-- Mendaftarkan tabel ke publikasi berarti setiap perubahannya dikirim ke
-- proses Realtime, jadi daftarnya dijaga sesempit mungkin — bukan "semua
-- tabel supaya aman".
--
--   token_wallets  — sumber paling andal. Setiap video yang BERHASIL diunggah
--                    memotong satu token lewat trigger `after_video_uploaded`
--                    (Bab 7.2), jadi satu baris ini bergerak setiap kali ada
--                    video baru masuk. Policy `wallet_select` sederhana
--                    (`tenant_id = current_tenant_id()`), sehingga pemeriksaan
--                    RLS per pelanggan Realtime ringan.
--
--   package_videos — perubahan yang TIDAK menyentuh dompet: video gagal
--                    diunggah, atau dihapus Owner. Tanpa ini kartu diam pada
--                    kejadian yang justru perlu terlihat.
--
-- ⚠️ RLS tetap berlaku: Realtime memeriksa policy tabel untuk tiap pelanggan
-- sebelum mengirimkan barisnya. Kedua tabel ini RLS-nya sudah aktif sejak
-- `14_rls.sql`. Tetapi policy `videos_select` memuat sub-kueri `exists` yang
-- tidak sederhana, dan **belum diuji di perangkat** — bila kelak kartu tidak
-- ikut bergerak untuk packer, di situlah tempat pertama yang harus dilihat.
-- ------------------------------------------------------------

do $$
declare
  t text;
begin
  -- Publikasi ini dibuat Supabase saat project dibentuk. Bila hilang, lebih
  -- baik berhenti dengan pesan yang jelas daripada membuat publikasi baru yang
  -- tidak dikenali layanan Realtime.
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Publikasi supabase_realtime tidak ditemukan. '
                    'Periksa pengaturan Realtime di dashboard Supabase.';
  end if;

  foreach t in array array['token_wallets', 'package_videos'] loop
    -- Idempoten: `alter publication … add table` menolak tabel yang sudah
    -- terdaftar, dan migrasi harus aman dijalankan ulang.
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = t
    ) then
      -- ALTER PUBLICATION adalah perintah utility; di plpgsql ia hanya dapat
      -- dijalankan lewat `execute`.
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
