-- ============================================================
-- 16_cron.sql  (Bab 5.6)
-- ============================================================
-- 🔴 Jalankan HANYA setelah pg_cron diaktifkan di
--    Dashboard > Database > Extensions.
-- ============================================================

-- Bab 7.2 poin 3: saldo direset ke monthly_quota tiap awal periode langganan.
-- Sisa token TIDAK diakumulasi ke bulan berikutnya.
-- Tenant uji coba dilewati karena period_end-nya NULL (Bab 7.5) — perbandingan
-- NULL <= now() menghasilkan NULL, sehingga barisnya tidak ikut terpilih.
select cron.schedule('reset-monthly-tokens', '0 1 * * *', $$
  update public.token_wallets w
     set balance      = w.monthly_quota,
         period_start = now(),
         period_end   = now() + interval '30 days',
         updated_at   = now()
   from public.tenants t
  where t.id = w.tenant_id
    and t.status = 'active'
    and w.period_end <= now();
$$);

-- Tandai video kedaluwarsa. Penghapusan objek fisik di R2 dilakukan oleh
-- Edge Function 'purge-expired-videos' yang dipanggil setelahnya.
-- Bab 1.3 poin 4: penghapusan otomatis ini BUKAN bug, ini model bisnis.
select cron.schedule('mark-expired-videos', '15 1 * * *', $$
  update public.package_videos
     set status = 'expired'
   where status = 'uploaded' and expires_at <= now();
$$);

-- Bab 7.6: langganan berakhir → terkunci seketika.
select cron.schedule('expire-tenants', '30 1 * * *', $$
  update public.tenants set status = 'expired'
   where status = 'active' and period_end <= now();
$$);
