-- ============================================================
-- 23_avatars_bucket.sql  (Bab 9.6 — foto profil)
-- ============================================================
-- Bab 9.6 menyebut foto profil diunggah ke bucket `avatars`, tetapi diperiksa
-- 20 Agustus 2026: **tidak ada satu bucket pun** di project ini.
--
--     select * from storage.buckets;  → 0 baris
--
-- Video tidak memakai Supabase Storage sama sekali (ia langsung ke Cloudflare
-- R2, Bab 8.7), jadi bucket memang belum pernah dibutuhkan sampai sekarang.
-- ============================================================

-- ------------------------------------------------------------
-- Bucket
-- ------------------------------------------------------------
-- `public = true`: foto profil dibaca lewat URL biasa tanpa tanda tangan.
--
-- Alasannya bukan kemudahan semata. Foto profil muncul di bilah atas setiap
-- layar dan di daftar packer; memakai presigned URL berarti menerbitkan tanda
-- tangan baru tiap kali gambarnya digambar ulang, dan gambar yang URL-nya
-- berubah terus tidak pernah dapat di-cache — pemborosan yang justru terasa di
-- jaringan gudang.
--
-- ⚠️ Konsekuensinya: siapa pun yang **memegang URL-nya** dapat membukanya.
-- Karena itu nama berkasnya memuat `user_id` (UUID), bukan nama atau email —
-- alamatnya tidak dapat ditebak dari identitas orangnya.
--
-- 🔴 Jangan menaruh apa pun selain foto profil di sini. Video bukti pelanggan
-- tidak boleh berada di bucket publik dengan alasan apa pun (Bab 1.3).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,                                    -- 2 MB; foto profil sudah dipotong di aplikasi
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ------------------------------------------------------------
-- Siapa boleh menulis
-- ------------------------------------------------------------
-- Berkas disimpan sebagai `{user_id}/avatar.jpg`, sehingga folder teratas
-- adalah pemiliknya. `storage.foldername(name)[1]` membaca folder itu.
--
-- 🔴 Tanpa pemeriksaan ini, siapa pun yang sudah login dapat **menimpa foto
-- profil orang lain** — termasuk mengganti foto Owner dengan gambar apa pun.
-- Bucket publik membuat akibatnya langsung terlihat semua orang.

drop policy if exists avatars_read_all on storage.objects;
create policy avatars_read_all on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
