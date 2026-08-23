-- ============================================================
-- 24_videos_insert_assignment.sql  (panduan §8.2)
-- ============================================================
-- Packer hanya boleh merekam atas nama toko yang DITUGASKAN kepadanya.
--
-- 🔴 CACAT YANG DIPERBAIKI, terbukti di perangkat Product Owner
--    20 Agustus 2026.
--
--    Owner menugaskan seorang packer ke 2 dari 3 toko. Packer itu tetap
--    melihat ketiga toko di layar Pilih Toko, memilih toko yang bukan
--    tugasnya, merekam — dan servernya menerima. Videonya lalu muncul di
--    riwayat atas nama toko yang tidak pernah ia pegang.
--
--    Sebabnya policy `videos_insert` di `14_rls.sql` hanya memastikan tokonya
--    milik tenant yang sama dan berstatus aktif. Ia tidak pernah melihat
--    `shop_packers` sama sekali, sehingga penugasan itu selama ini hanya
--    mengatur APA YANG TERLIHAT di Riwayat (`videos_select`), bukan APA YANG
--    BOLEH DIREKAM.
--
--    Layar perekaman kini menyaring daftarnya, tetapi penyaringan di layar
--    bukan penjagaan (Bab 2.3): siapa pun yang memanggil API langsung
--    melewatinya. Karena itu aturannya ditegakkan di sini.
--
-- ⚠️ SENGAJA TIDAK MENYENTUH `shops_select`.
--
--    Menyempitkan hak baca toko untuk packer akan terasa lebih rapi, tetapi
--    merusak hal lain: packer berhak melihat rekamannya sendiri selamanya
--    (Bab 2.2 catatan 3), termasuk video dari toko yang penugasannya kemudian
--    dicabut Owner. Bila tokonya tak lagi terbaca, baris riwayat itu
--    kehilangan namanya dan berubah menjadi bukti tanpa identitas toko —
--    justru pada berkas yang gunanya menjadi bukti.
--
--    Yang perlu dijaga adalah PERBUATANNYA (merekam), bukan pengetahuannya
--    (nama toko milik tenant sendiri).
-- ============================================================

drop policy if exists videos_insert on public.package_videos;

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
    -- Owner merekam atas nama toko mana pun miliknya; ia memang pemiliknya
    -- dan tidak pernah punya baris di `shop_packers`. Syarat ini khusus
    -- packer.
    and (
      public.current_app_role() <> 'packer'
      or exists (
        select 1 from public.shop_packers sp
         where sp.user_id = auth.uid()
           and sp.shop_id = package_videos.shop_id
      )
    )
  );

comment on policy videos_insert on public.package_videos is
  'Panduan §8.2 — packer hanya boleh merekam untuk toko yang ditugaskan '
  'kepadanya lewat shop_packers. Ditambahkan 20 Agustus 2026 setelah packer '
  'terbukti dapat merekam atas nama toko yang bukan tugasnya.';
