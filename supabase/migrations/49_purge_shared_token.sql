-- ============================================================
-- 49_purge_shared_token.sql  (Bab 8.7 — penguras antrean, jalur yang tidak
--                            bergantung pada kunci milik Supabase)
-- ============================================================
-- Menggantikan cara `drain_purge_queue` membuktikan diri ke `purge-storage`.
--
-- ============================================================
-- 🔴 KENAPA MIGRASI 47 TIDAK CUKUP
-- ============================================================
--
-- Migrasi 47 mengirim `Authorization: Bearer <service_role_key dari Vault>`,
-- dan `purge-storage` membandingkannya dengan
-- `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`.
--
-- Nilai itu DIKENDALIKAN SUPABASE dan tidak dapat dibaca dari mana pun — tidak
-- dari SQL, tidak dari Dashboard, tidak dari CLI. Yang dapat dilihat hanya
-- sidik SHA-256-nya lewat `supabase secrets list`.
--
-- 4 September 2026, berjam-jam habis di situ. Kunci di Vault sudah:
--
--     ref   = project yang benar        ✅
--     role  = service_role              ✅
--     spasi = tidak ada                 ✅
--     ganda = tidak                     ✅
--
-- dan tetap dijawab 403. Sidiknya membuktikan sebabnya:
--
--     SUPABASE_SERVICE_ROLE_KEY (fungsi) : cae5da3e...
--     kunci yang disimpan di Vault       : 1fb8654...
--
-- 🔴 Dan bukan hanya itu. `SUPABASE_ANON_KEY` yang dilihat fungsi juga BERBEDA
-- dari anon key di `env.dev.json` — padahal aplikasi berjalan normal dengan
-- kunci itu. Supabase memegang kunci yang tidak sama dengan yang tertera di
-- catatan mana pun, dan tidak ada cara mengetahui yang mana.
--
-- Menebaknya gagal tiga kali. Rahasia yang KEDUA SISINYA kita isi sendiri
-- tidak dapat berselisih diam-diam seperti itu.
--
-- ============================================================
-- 🔴 SEBELUM MENJALANKAN — tiga langkah, berurutan
-- ============================================================
--
-- 1. Pilih satu token acak yang panjang. Contoh yang dapat dipakai:
--
--       BiVplRiID01DHFKyoCOXvC4Z2HLL8Uu4YnLMBOhwKTuWCRy7nonBTiCUDY7Nt1vq
--
--    ⚠️ Ia menggantikan seluruh penjagaan fungsi ini, jadi panjang dan acak.
--    Bukan kata yang mudah ditebak.
--
-- 2. Pasang di SISI EDGE FUNCTION:
--
--       & $cli secrets set PURGE_TOKEN='<token>' --project-ref <ref>
--       & $cli functions deploy purge-storage --no-verify-jwt --project-ref <ref>
--
--    🔴 `--no-verify-jwt` DISENGAJA, dan ini perubahan dari sebelumnya.
--    Gerbang JWT hanya memastikan pemanggilnya membawa JWT project yang sah —
--    dan JWT setiap Owner yang sedang login pun sah, jadi ia tidak pernah
--    menjadi penjagaan yang sebenarnya. Yang menjaga tetap rahasia bersama di
--    dalam fungsinya, sama seperti `midtrans-webhook` dijaga tanda tangan.
--
--    ⚠️ Tanpa flag itu, `pg_net` harus mengirim JWT yang sah HANYA untuk
--    melewati gerbang — dan itu mengembalikan tepat masalah yang migrasi ini
--    datang untuk menghapus.
--
-- 3. Pasang token YANG SAMA PERSIS di SISI DATABASE:
--
--       select vault.create_secret('<token>', 'purge_token',
--              'Rahasia bersama drain-purge-queue <-> purge-storage');
--
--    ⚠️ Bila `purge_token` sudah pernah ada, JANGAN create_secret lagi —
--    ia tidak menimpa, ia menambah baris kedua bernama sama. Pakai:
--
--       select vault.update_secret(
--         (select id from vault.secrets where name = 'purge_token'), '<token>');
-- ============================================================

create or replace function public.drain_purge_queue()
returns void
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_token text;
  v_url   text;
  v_req   bigint;
  v_n     integer;
begin
  -- 🔴 Dihitung, bukan diasumsikan tunggal.
  --
  -- Migrasi 47 memakai `select ... into` begitu saja. Bila Vault memuat DUA
  -- baris bernama sama — yang terjadi setiap kali `create_secret` dijalankan
  -- ulang — plpgsql mengambil salah satunya tanpa aturan dan TIDAK MENGELUH.
  -- Percobaan pertama yang salah dapat menang atas perbaikan yang benar, dan
  -- tidak ada satu pun galat yang menandainya.
  select count(*) into v_n from vault.secrets where name = 'purge_token';
  if v_n > 1 then
    raise exception 'Vault memuat % baris bernama purge_token', v_n
      using hint = 'Hapus semuanya lalu simpan sekali: '
                   'delete from vault.secrets where name = ''purge_token'';';
  end if;

  select decrypted_secret into v_token
    from vault.decrypted_secrets where name = 'purge_token';
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'purge_storage_url';

  if v_token is null or v_url is null then
    raise exception 'Vault belum berisi purge_token dan/atau purge_storage_url'
      using hint = 'Lihat kepala 49_purge_shared_token.sql, langkah 1-3.';
  end if;

  -- ⚠️ Tokennya di header SENDIRI, bukan di `Authorization`. Header itu kini
  -- tidak dipakai sama sekali — fungsinya di-deploy `--no-verify-jwt`.
  select net.http_post(
           url     := v_url,
           headers := jsonb_build_object(
                        'Content-Type',  'application/json',
                        'X-Purge-Token', v_token
                      ),
           body    := '{}'::jsonb,
           timeout_milliseconds := 30000
         )
    into v_req;

  raise notice 'purge-storage dipanggil, request_id = %', v_req;
end;
$$;

comment on function public.drain_purge_queue() is
  'Bab 8.7 - memanggil purge-storage lewat rahasia bersama purge_token. '
  'Tidak lagi bergantung pada SUPABASE_SERVICE_ROLE_KEY yang nilainya '
  'dikendalikan Supabase dan tidak dapat dibaca dari mana pun.';

-- Jadwalnya tidak berubah; `cron.schedule` menimpa job bernama sama.
do $$
begin
  perform cron.schedule('drain-purge-queue', '0 * * * *', $job$
    select public.drain_purge_queue();
  $job$);
end $$;

-- ============================================================
-- MEMBUKTIKANNYA
-- ============================================================
--
--   select public.drain_purge_queue();
--   -- tunggu ± 10 detik
--   select status_code, content from net._http_response
--    order by created desc limit 1;
--
-- | status_code | artinya                                                  |
-- |-------------|----------------------------------------------------------|
-- | 200         | berhasil                                                 |
-- | 403         | token di Vault != PURGE_TOKEN di Edge Function            |
-- | 500         | PURGE_TOKEN belum diset di sisi Edge Function             |
-- | 401         | fungsinya belum di-deploy dengan --no-verify-jwt          |
-- | 404         | purge_storage_url salah, atau fungsinya belum ter-deploy  |
-- | NULL        | belum ada jawaban, ulangi kuerinya                        |
--
-- 🔴 Ketiga kode 403/500/401 sekarang menunjuk sebab yang BERBEDA-BEDA, dan
-- ketiganya dapat diperbaiki tanpa menebak. Itulah yang tidak dimiliki
-- migrasi 47.
-- ============================================================
