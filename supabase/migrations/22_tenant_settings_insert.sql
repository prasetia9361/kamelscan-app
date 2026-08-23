-- ============================================================
-- 22_tenant_settings_insert.sql  (Bab 9.7 — halaman Pengaturan)
-- ============================================================
-- 🔴 TEMUAN 19 Agustus 2026, terlihat di perangkat: Owner menyalakan sakelar
--    "Packer boleh melihat riwayat se-toko" dan menerima
--
--      "Anda tidak memiliki akses ke data ini"
--
--    padahal ia Owner tenant itu sendiri, dan barisnya sudah ada.
--
-- Sebabnya halus. Aplikasi menyimpan lewat **upsert**, dan PostgREST
-- menerjemahkannya menjadi:
--
--      insert into tenant_settings … on conflict (tenant_id) do update …
--
-- Bagi PostgreSQL perintah itu tetap **INSERT**, walaupun hasil akhirnya
-- memperbarui baris yang sudah ada. RLS karenanya menuntut policy INSERT —
-- sedangkan `14_rls.sql` hanya memberi `tsettings_write_owner … for update`.
-- Hasilnya ditolak `42501: new row violates row-level security policy`.
--
-- Dibuktikan langsung di database sebelum migrasi ini ditulis: upsert yang
-- sama, dijalankan dengan klaim JWT Owner sungguhan, ditolak dengan kode itu.
--
-- ⚠️ `user_settings` TIDAK terkena karena policy-nya `for all` — mencakup
-- INSERT sekaligus. Perbedaan satu kata itulah yang membuat tema dan bahasa
-- tersimpan sementara pengaturan tenant tidak.
-- ============================================================

-- Baris `tenant_settings` sebenarnya sudah dibuat trigger registrasi untuk
-- setiap tenant, jadi jalur INSERT ini jarang benar-benar menyisipkan apa pun.
-- Ia tetap diperlukan agar upsert diizinkan, dan sekaligus menutup keadaan
-- tenant lama yang barisnya belum sempat terbentuk.
--
-- 🔴 Sengaja TIDAK memakai `for all`. Itu akan sekalian memberi hak DELETE,
-- dan menghapus baris pengaturan tenant bukan sesuatu yang perlu dapat
-- dilakukan dari aplikasi — yang hilang bukan hanya sakelarnya, melainkan
-- juga jejak pengaturan watermark yang dipakai video-video lama.
create policy tsettings_insert_owner on public.tenant_settings for insert
  with check (
    (public.is_owner() and tenant_id = public.current_tenant_id())
    or public.is_admin()
  );
