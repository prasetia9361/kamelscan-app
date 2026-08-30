-- ============================================================
-- 34_promo_usage.sql  (Bab 12.4 — hitungan pemakaian kode promo)
-- ============================================================
-- `promos.used_count` **tidak pernah dinaikkan siapa pun** sejak tabelnya
-- lahir di migrasi 09. Kolomnya ada, nilai awalnya 0, dan tidak satu baris
-- kode pun di seluruh proyek yang menyentuhnya.
--
-- Akibatnya dua, dan keduanya diam:
--
--   1. **`max_uses` tidak pernah berlaku.** `Promo.isUsedUp` membandingkan
--      `used_count >= max_uses`, dan ruas kirinya selamanya 0. Kode promo
--      dengan batas 10 kali dapat dipakai tanpa henti, dan tidak ada galat
--      apa pun yang muncul.
--   2. Halaman Admin → Kode Promo (Bab 11.4, dibangun 29 Agustus 2026)
--      selamanya menulis "Terpakai 0 kali" — angka yang salah dan terlihat
--      masuk akal.
--
-- Bab 12.4 sudah memerintahkannya sejak awal, di dalam fungsi aktivasi:
--
--     if v_sub.promo_code is not null then
--       update public.promos set used_count = used_count + 1
--        where code = v_sub.promo_code;
--     end if;
--
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 Dipasang sebagai TRIGGER TERSENDIRI, bukan ditambal ke dalam
--    `activate_subscription()`
-- ------------------------------------------------------------
--
-- Dua alasan, dan yang kedua lebih menentukan:
--
-- 1. `activate_subscription()` (migrasi 28) panjangnya ± 180 baris dan
--    menyentuh uang, token, serta periode langganan. Menyalin ulang seluruh
--    isinya hanya untuk menyisipkan tiga baris berarti mempertaruhkan
--    seluruhnya pada satu kesalahan salin.
--
-- 2. Menghitung pemakaian promo adalah urusan yang **berbeda** dari
--    mengaktifkan langganan. Bila suatu hari salah satunya perlu diubah,
--    yang lain tidak ikut tersentuh — dan `audit_logs` (migrasi 32) sudah
--    memakai pola yang sama persis untuk alasan yang sama.
--
-- ⚠️ Berlaku untuk KEDUA jalur pembayaran sekaligus. Transfer manual dan
-- Midtrans sama-sama berakhir pada `subscriptions.status = 'paid'`, jadi
-- trigger ini tidak perlu tahu uangnya datang dari mana.
create or replace function public.count_promo_usage()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 🔴 Penjagaan yang sama persis dengan `activate_subscription()`: hanya
  -- pada PERPINDAHAN menjadi 'paid'.
  --
  -- Tanpa ini, menyimpan ulang baris yang sudah lunas — apa pun sebabnya —
  -- menaikkan hitungannya lagi. Webhook Midtrans khususnya WAJIB dianggap
  -- akan datang berkali-kali untuk pembayaran yang sama (Bab 12.3 aturan 3),
  -- dan hitungan yang menggelembung membuat batas pemakaian promo habis
  -- sebelum waktunya bagi pelanggan yang tidak melakukan apa-apa.
  if new.status <> 'paid' or old.status is not distinct from 'paid' then
    return new;
  end if;

  if new.promo_code is null or btrim(new.promo_code) = '' then
    return new;
  end if;

  -- ⚠️ Tidak melempar galat bila kodenya sudah tidak ada di tabel `promos`.
  --
  -- `subscriptions.promo_code` menyimpan teks biasa, bukan foreign key, jadi
  -- kode yang sudah dihapus Admin tetap tertinggal di baris lama. Menggagalkan
  -- aktivasi karena hitungan promo tidak dapat dinaikkan berarti pelanggan
  -- yang sudah membayar tidak jadi aktif — akibat yang jauh lebih berat
  -- daripada satu angka statistik yang meleset.
  update public.promos
     set used_count = used_count + 1
   where code = new.promo_code;

  return new;
end;
$$;

comment on function public.count_promo_usage() is
  'Bab 12.4 - menaikkan promos.used_count saat langganan menjadi paid. '
  'Hanya pada perpindahan status, supaya webhook Midtrans yang datang '
  'berkali-kali tidak menggelembungkan hitungannya.';

-- 🔴 `after update`, bukan `before`.
--
-- `activate_subscription()` berjalan `before update` dan masih dapat
-- menggagalkan seluruh transaksi (misalnya saat `platform_settings.pricing`
-- tidak memuat paketnya). Menaikkan hitungan promo sebelum itu berarti
-- angkanya naik untuk aktivasi yang akhirnya dibatalkan.
drop trigger if exists trg_count_promo_usage on public.subscriptions;
create trigger trg_count_promo_usage
  after update on public.subscriptions
  for each row execute function public.count_promo_usage();

-- ------------------------------------------------------------
-- Menyelaraskan hitungan yang sudah terlanjur tertinggal
-- ------------------------------------------------------------
-- Baris `subscriptions` yang sudah lunas sebelum hari ini tidak pernah
-- terhitung. Sekali jalan, hitungannya disusun ulang dari kenyataan.
--
-- ⚠️ Ini `update` biasa, bukan penambahan — aman diulang. Menjalankan berkas
-- migrasi ini dua kali tidak menggandakan apa pun.
update public.promos p
   set used_count = coalesce(t.jumlah, 0)
  from (
    select code, count(*) as jumlah
      from (
        select promo_code as code
          from public.subscriptions
         where status = 'paid'
           and promo_code is not null
           and btrim(promo_code) <> ''
      ) x
     group by code
  ) t
 where p.code = t.code
   and p.used_count is distinct from coalesce(t.jumlah, 0);

-- Kode yang tidak pernah dipakai sama sekali dikembalikan ke nol, supaya
-- hitungan yang pernah diisi tangan lewat Dashboard tidak tertinggal.
update public.promos
   set used_count = 0
 where used_count <> 0
   and code not in (
     select promo_code from public.subscriptions
      where status = 'paid' and promo_code is not null
   );