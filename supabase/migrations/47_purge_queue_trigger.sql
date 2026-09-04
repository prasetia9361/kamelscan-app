-- ============================================================
-- 47_purge_queue_trigger.sql  (Bab 8.7 — penguras antrean R2)
-- ============================================================
-- Utang nomor 4 daftar kesiapan produksi, dan satu-satunya yang BERBIAYA
-- selama dibiarkan.
--
-- `purge-storage` sudah terbit sejak 31 Agustus 2026 dan berfungsi. Yang tidak
-- pernah ada: siapa pun yang memanggilnya. Akibatnya berjalan diam-diam —
-- akun yang dihapus mengisi `storage_purge_queue`, berkas videonya tetap utuh
-- di Cloudflare R2, dan tetap ditagihkan setiap bulan.
--
-- ============================================================
-- 🔴 SEBELUM MENJALANKAN BERKAS INI — tiga hal wajib sudah siap
-- ============================================================
--
-- 1. Ekstensi `pg_net` aktif.
--    Dashboard > Database > Extensions > cari `pg_net` > Enable.
--    Sama seperti `pg_cron`, ia tidak selalu dapat dibuat lewat SQL Editor.
--
-- 2. Ekstensi `supabase_vault` aktif.
--    Dashboard > Database > Extensions > cari `supabase_vault` > Enable.
--
-- 3. DUA rahasia sudah tersimpan di Vault. Jalankan di SQL Editor, sekali:
--
--       select vault.create_secret(
--         'eyJhbGciOi...',                    -- service_role key project INI
--         'service_role_key',
--         'Dipakai cron drain-purge-queue memanggil Edge Function purge-storage'
--       );
--
--       select vault.create_secret(
--         'https://<REF>.supabase.co/functions/v1/purge-storage',
--         'purge_storage_url',
--         'Alamat Edge Function penguras antrean R2'
--       );
--
--    Periksa keduanya tersimpan (nilainya sengaja TIDAK ikut ditampilkan):
--
--       select name, created_at from vault.secrets order by created_at desc;
--
-- 🔴 Kenapa lewat Vault, bukan ditulis di berkas ini.
--
-- Berkas migrasi masuk git. Service role key adalah kunci yang MELEWATI
-- SELURUH RLS — siapa pun yang memegangnya dapat membaca dan menghapus data
-- setiap pelanggan. Ia tidak boleh berada di repositori dengan alasan apa pun.
--
-- ⚠️ Alamat fungsinya ikut disimpan di Vault, bukan ditulis mati di sini.
-- Alasannya bukan kerahasiaan — alamat itu tidak rahasia — melainkan supaya
-- berkas migrasi ini SAMA PERSIS di project lama maupun baru. Migrasi yang
-- perlu disunting sebelum dijalankan adalah migrasi yang cepat atau lambat
-- dijalankan dalam bentuk yang salah.
-- ============================================================

-- ------------------------------------------------------------
-- Pemanggil
-- ------------------------------------------------------------
-- `security definer` supaya ia boleh membaca `vault.decrypted_secrets`.
-- Cron berjalan sebagai pemilik job, dan pemilik job tidak selalu punya izin
-- itu.
--
-- ⚠️ `search_path` dipatok, dan `net.http_post` tetap disebut lengkap dengan
-- schema-nya. Fungsi `security definer` yang search_path-nya longgar dapat
-- dibajak lewat fungsi bernama sama di schema lain — dan fungsi ini memegang
-- kunci yang melewati seluruh RLS.
create or replace function public.drain_purge_queue()
returns void
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_key text;
  v_url text;
  v_req bigint;
begin
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'service_role_key';

  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'purge_storage_url';

  -- 🔴 Berhenti dengan KERAS bila rahasianya belum ada.
  --
  -- Tanpa baris ini, `net.http_post` tetap terkirim dengan header
  -- `Bearer ` kosong, `purge-storage` menjawab 403, dan antreannya tidak
  -- pernah berkurang — persis keadaan yang migrasi ini datang untuk
  -- memperbaiki, tetapi kini terlihat seperti sudah dikerjakan.
  if v_key is null or v_url is null then
    raise exception
      'Vault belum berisi service_role_key dan/atau purge_storage_url'
      using hint = 'Lihat kepala 47_purge_queue_trigger.sql, syarat nomor 3.';
  end if;

  -- ⚠️ `pg_net` bekerja ASINKRON. Fungsi ini hanya menitipkan permintaan dan
  -- langsung selesai; jawabannya datang belakangan ke `net._http_response`.
  -- Jadi "fungsi ini berhasil" TIDAK berarti antreannya terkuras — lihat
  -- cara memeriksanya di kaki berkas ini.
  select net.http_post(
           url     := v_url,
           headers := jsonb_build_object(
                        'Content-Type',  'application/json',
                        'Authorization', 'Bearer ' || v_key
                      ),
           body    := '{}'::jsonb,
           timeout_milliseconds := 30000
         )
    into v_req;

  raise notice 'purge-storage dipanggil, request_id = %', v_req;
end;
$$;

comment on function public.drain_purge_queue() is
  'Bab 8.7 - memanggil Edge Function purge-storage untuk menguras '
  'storage_purge_queue. Kredensialnya dibaca dari Vault, tidak pernah '
  'dituliskan ke berkas migrasi.';

-- ------------------------------------------------------------
-- Jadwal
-- ------------------------------------------------------------
-- Dibungkus DO mengikuti pola migrasi 16: `cron.schedule` mengembalikan baris
-- hasil, dan `perform` membuangnya sehingga berkas ini aman diulang.
-- `cron.schedule` menimpa job bernama sama.
--
-- Tiap jam, bukan tiap menit: antrean ini terisi hanya saat ada akun dihapus
-- atau video kedaluwarsa, dan `purge-storage` sendiri sudah membatasi diri
-- 5.000 kunci per panggilan.
do $$
begin
  perform cron.schedule('drain-purge-queue', '0 * * * *', $job$
    select public.drain_purge_queue();
  $job$);
end $$;

-- ============================================================
-- CARA MEMBUKTIKANNYA BEKERJA — jangan percaya "cron-nya ada"
-- ============================================================
--
-- 1. Berapa yang menunggu sekarang:
--
--       select count(*) from public.storage_purge_queue;
--
-- 2. Jalankan sekali dengan tangan, tanpa menunggu jam berikutnya:
--
--       select public.drain_purge_queue();
--
-- 3. Tunggu beberapa detik, lalu lihat JAWABAN dari Edge Function.
--    🔴 Ini langkah yang paling sering dilewati. `pg_net` asinkron, jadi
--    langkah 2 selalu "berhasil" bahkan ketika panggilannya ditolak.
--
--       select id, status_code, content, created
--         from net._http_response
--        order by created desc limit 3;
--
--    | status_code | artinya                                             |
--    |-------------|-----------------------------------------------------|
--    | 200         | berhasil                                            |
--    | 403         | FORBIDDEN - service_role_key di Vault salah         |
--    | 401         | gerbang menolak - kunci bukan JWT yang sah          |
--    | 404         | purge_storage_url salah, atau fungsi belum di-deploy|
--    | NULL        | belum ada jawaban, tunggu sebentar lagi             |
--
-- 4. Hitung ulang. Angkanya harus TURUN:
--
--       select count(*) from public.storage_purge_queue;
--
-- 5. Periksa jadwalnya benar-benar terpasang:
--
--       select jobname, schedule, active from cron.job
--        where jobname = 'drain-purge-queue';
--
-- ⚠️ Bila antreannya memang sudah kosong sejak awal, langkah 4 tidak
-- membuktikan apa pun. Yang membuktikan tetap `status_code = 200` di
-- langkah 3.
