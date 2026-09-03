-- ============================================================
-- 46_public_assets_bucket.sql  (Bab 11.5 — gambar iklan)
-- ============================================================
-- Utang nomor 3 daftar kesiapan produksi, dan yang paling lama tertunda
-- setelah Tutorial.
--
-- Bab 11.5 menyebut gambar iklan diunggah ke bucket `public-assets`, tetapi
-- diukur 3 September 2026: **tidak ada satu pun migrasi yang membuatnya**.
-- Yang pernah dibuat hanya `avatars` (migrasi 23) dan `payment-proofs`
-- (migrasi 25).
--
-- Akibatnya sampai sekarang gambar landing page dan gambar kartu paket hanya
-- dapat diganti lewat Supabase Dashboard — antarmuka teknis berbahasa Inggris
-- yang tidak seharusnya dituntut dari orang yang mengelola isi iklan.
--
-- Alamat gambarnya sendiri sudah punya tempat sejak migrasi 08:
--
--     platform_settings.banner_landing  = {image_url, headline, subheadline}
--     platform_settings.banner_payment  = {standar_image_url, pro_image_url,
--                                          bisnis_image_url}   (migrasi 39)
--
-- Jadi yang kurang **hanya tempat menaruh berkasnya**, bukan tempat menaruh
-- alamatnya.
--
-- ⚠️ Migrasi ini tidak menyentuh satu tabel pun dan tidak mengubah satu baris
-- data pun. Aman dijalankan ulang.
-- ============================================================

-- ------------------------------------------------------------
-- Bucket
-- ------------------------------------------------------------
-- `public = true`: gambar iklan memang untuk dilihat siapa saja — landing page
-- dibuka orang yang belum punya akun sama sekali. Memakai presigned URL di
-- sana justru mustahil: tidak ada sesi yang dapat menandatanganinya.
--
-- 🔴 Jangan menaruh apa pun selain gambar iklan di sini. Bucket ini terbuka
-- tanpa login, dan video bukti pelanggan tidak boleh berada di tempat seperti
-- itu dengan alasan apa pun (Bab 1.3). Video memang tidak pernah menyentuh
-- Supabase Storage — ia langsung ke Cloudflare R2 (Bab 8.7).
--
-- Batas 5 MB, lebih besar daripada `avatars` (2 MB): gambar iklan tampil
-- selebar layar landing page, sedangkan foto profil hanya sebesar lingkaran
-- kecil di bilah atas. Tetapi tetap dibatasi — gambar 20 MB di halaman depan
-- akan membuat calon pelanggan pergi sebelum halamannya selesai dimuat.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'public-assets',
  'public-assets',
  true,
  5242880,                                    -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ------------------------------------------------------------
-- Siapa boleh membaca
-- ------------------------------------------------------------
-- Semua orang, termasuk yang belum login. Itu memang gunanya.
drop policy if exists public_assets_read_all on storage.objects;
create policy public_assets_read_all on storage.objects for select
  using (bucket_id = 'public-assets');

-- ------------------------------------------------------------
-- Siapa boleh menulis
-- ------------------------------------------------------------
-- 🔴 HANYA admin. Berbeda mendasar dari `avatars`, yang membiarkan setiap
-- pengguna menulis ke foldernya sendiri.
--
-- Alasannya: isi bucket ini tampil di **halaman depan** kepada calon pelanggan
-- yang belum punya akun. Satu gambar yang salah di sana merusak kepercayaan
-- sebelum ada satu kalimat pun yang sempat dibaca — dan tidak ada pemilik
-- folder yang dapat disalahkan, karena tidak ada yang memilikinya.
--
-- `public.is_admin()` sudah ada sejak migrasi 13 dan membaca peran dari JWT.
--
-- ⚠️ Peran dibawa di dalam JWT (jebakan nomor 8): akun yang baru dinaikkan
-- menjadi admin harus keluar lalu masuk lagi sebelum policy ini mengenalinya.
drop policy if exists public_assets_write_admin on storage.objects;
create policy public_assets_write_admin on storage.objects for insert
  with check (bucket_id = 'public-assets' and public.is_admin());

drop policy if exists public_assets_update_admin on storage.objects;
create policy public_assets_update_admin on storage.objects for update
  using (bucket_id = 'public-assets' and public.is_admin())
  with check (bucket_id = 'public-assets' and public.is_admin());

-- Menghapus juga hanya admin.
--
-- ⚠️ Nama berkasnya sengaja TETAP (`landing.jpg`, `plan-standar.jpg`, dan
-- seterusnya) dan ditimpa saat diganti, sama seperti foto profil. Jadi
-- penghapusan hampir tidak pernah dibutuhkan — ia ada supaya gambar yang
-- terlanjur salah dapat dicabut, bukan supaya sampah dapat dibersihkan.
drop policy if exists public_assets_delete_admin on storage.objects;
create policy public_assets_delete_admin on storage.objects for delete
  using (bucket_id = 'public-assets' and public.is_admin());

comment on table storage.objects is
  'Berkas Supabase Storage. Bucket: avatars (foto profil, migrasi 23), '
  'payment-proofs (bukti transfer, migrasi 25), public-assets (gambar iklan, '
  'migrasi 46). Video bukti TIDAK di sini - ia di Cloudflare R2 (Bab 8.7).';
