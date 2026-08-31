-- ============================================================
-- 39_tier_bisnis.sql  (Bab 7.1 — tiga paket)
-- ============================================================
-- Keputusan Product Owner 31 Agustus 2026. Ketiga paket HANYA berbeda pada
-- tiga hal: harga, jumlah token, dan durasi maksimal per video.
--
--   Standar  Rp   149.000   2.000 token    30 detik
--   Pro      Rp   299.000   5.000 token    60 detik
--   Bisnis   Rp 1.490.000  30.000 token     3 menit
--
-- Retensi 30 hari untuk ketiganya. Jumlah packer TAK TERBATAS untuk ketiganya.
--
-- ⚠️ Harga Bisnis sengaja tetap Rp 1.490.000. Claude menyarankan menurunkannya
--    ke kisaran Rp 800.000 dengan alasan lompatannya 5x harga untuk 3x durasi,
--    sementara pembeda sesungguhnya bagi pelanggan bervolume rendah hanyalah
--    durasi. Product Owner menimbangnya dan memutuskan tetap. Dicatat di sini
--    supaya keputusan itu tidak perlu diperdebatkan ulang setiap kali angkanya
--    dibaca orang baru.
--
-- 🔴 BERKAS INI SENGAJA TIDAK MENYENTUH tier_plan SEBAGAI NILAI ENUM.
--    `alter type ... add value` tidak boleh dipakai di transaksi yang sama
--    dengan pemakaian nilai barunya. Seluruh yang MEMAKAI 'bisnis'::tier_plan
--    ada di migrasi 40, dan itu bukan kerapian — menggabungkannya membuat
--    migrasinya gagal dengan galat yang menyesatkan
--    ("unsafe use of new value of enum type").
-- ============================================================

-- ------------------------------------------------------------
-- 1. Nilai enum baru
-- ------------------------------------------------------------
-- `if not exists` supaya berkas ini aman diulang.
alter type tier_plan add value if not exists 'bisnis';

-- Alasan buku besar untuk token yang hangus (migrasi 40). Ditaruh di sini
-- karena alasannya sama persis: nilai enum baru tidak boleh dipakai di
-- transaksi yang sama dengan penambahannya.
alter type ledger_reason add value if not exists 'token_expired';


-- ------------------------------------------------------------
-- 2. Harga & isi paket
-- ------------------------------------------------------------
-- Kuncinya jsonb biasa, bukan nilai enum, jadi aman ditulis di sini.
--
-- 🔴 `max_packers: -1` (tak terbatas) untuk KETIGANYA.
--    Alasannya bukan kemurahan hati: packer tidak memakan biaya sama sekali —
--    yang memakan biaya adalah VIDEO, dan video sudah diukur token. Membatasi
--    packer berarti menagih hal yang sama dua kali, dengan dua angka yang
--    dapat saling bertentangan. Batas itu juga sumber satu kelas cacat
--    tersendiri (lihat migrasi 38 bagian 2).
update public.platform_settings
   set value = '{
      "standar": {"price": 149000,  "max_video_seconds": 30,  "retention_days": 30, "max_packers": -1, "monthly_tokens": 2000},
      "pro":     {"price": 299000,  "max_video_seconds": 60,  "retention_days": 30, "max_packers": -1, "monthly_tokens": 5000},
      "bisnis":  {"price": 1490000, "max_video_seconds": 180, "retention_days": 30, "max_packers": -1, "monthly_tokens": 30000}
   }'::jsonb,
       updated_at = now()
 where key = 'pricing';


-- ------------------------------------------------------------
-- 3. Batas packer masa uji coba
-- ------------------------------------------------------------
-- 🔴 CACAT YANG NYARIS LOLOS DIAM-DIAM.
--
--    `TrialConfig` hanya menyimpan `tokens`, `tier`, dan `enabled`. Ia TIDAK
--    punya batas packer sendiri — selama ini trial meminjam SELURUH
--    konfigurasi paket Standar (`tierCatalog.of(trial.tier)`).
--
--    Begitu Standar disetel `max_packers: -1` di bagian 2 di atas, masa uji
--    coba ikut menjadi tak terbatas — persis kebalikan dari yang diminta, dan
--    tanpa satu pun galat. Seorang pendaftar baru dapat membuat seratus akun
--    packer tanpa membayar sepeser pun.
--
--    Karena itu trial diberi `max_packers` sendiri di sini, dan
--    `TrialConfig` di Dart harus membacanya.
update public.platform_settings
   set value = value || '{"max_packers": 5}'::jsonb,
       updated_at = now()
 where key = 'trial';


-- ------------------------------------------------------------
-- 4. Spanduk halaman pembayaran
-- ------------------------------------------------------------
-- Bentuknya masih dua kolom bernama (`standar_image_url`, `pro_image_url`) dan
-- tidak punya tempat untuk paket ketiga. Ditambahkan supaya Admin > Spanduk
-- tidak menyimpan gambar Bisnis ke tempat yang tidak pernah dibaca siapa pun.
update public.platform_settings
   set value = value || '{"bisnis_image_url": ""}'::jsonb,
       updated_at = now()
 where key = 'banner_payment'
   and not (value ? 'bisnis_image_url');
