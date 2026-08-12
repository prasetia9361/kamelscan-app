-- ============================================================
-- 16_cron.sql  (Bab 5.6)
-- ============================================================
-- Dibungkus DO + PERFORM, bukan SELECT seperti di Bab 5.6.
--
-- Alasannya teknis: `select cron.schedule(...)` mengembalikan baris hasil, dan
-- mengirim tiga perintah semacam itu sekaligus lewat protokol simple query
-- membuat driver PostgreSQL Dart gagal ("Bad state: Future already completed").
-- `perform` membuang hasilnya sehingga tidak ada baris yang dikembalikan.
-- Efek ke database persis sama.
--
-- `cron.schedule` menimpa job bernama sama, jadi berkas ini aman diulang.
-- ============================================================

do $mig$
begin
  -- Bab 7.2 poin 3: saldo direset ke monthly_quota tiap awal periode langganan.
  -- Sisa token TIDAK diakumulasi ke bulan berikutnya.
  -- Tenant uji coba dilewati karena period_end-nya NULL (Bab 7.5) —
  -- perbandingan NULL <= now() menghasilkan NULL, barisnya tidak terpilih.
  perform cron.schedule('reset-monthly-tokens', '0 1 * * *', $job$
    update public.token_wallets w
       set balance      = w.monthly_quota,
           period_start = now(),
           period_end   = now() + interval '30 days',
           updated_at   = now()
     from public.tenants t
    where t.id = w.tenant_id
      and t.status = 'active'
      and w.period_end <= now();
  $job$);

  -- Tandai video kedaluwarsa. Penghapusan objek fisik di R2 dilakukan oleh
  -- Edge Function 'purge-expired-videos' yang dipanggil setelahnya.
  -- Bab 1.3 poin 4: penghapusan otomatis ini BUKAN bug, ini model bisnis.
  perform cron.schedule('mark-expired-videos', '15 1 * * *', $job$
    update public.package_videos
       set status = 'expired'
     where status = 'uploaded' and expires_at <= now();
  $job$);

  -- Bab 7.6: langganan berakhir → terkunci seketika, tanpa masa tenggang.
  perform cron.schedule('expire-tenants', '30 1 * * *', $job$
    update public.tenants set status = 'expired'
     where status = 'active' and period_end <= now();
  $job$);
end
$mig$;
