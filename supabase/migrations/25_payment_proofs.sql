-- ============================================================
-- 25_payment_proofs.sql  (Bab 9.8 / Bab 12.2 — transfer manual)
-- ============================================================
-- Bab 12 menetapkan Fase 1 memakai transfer manual: Owner mentransfer, lalu
-- mengunggah bukti, lalu Admin memverifikasi. Dua hal yang dibutuhkan alur itu
-- belum pernah ada:
--
--   1. tempat menyimpan bukti transfernya
--   2. izin bagi Owner untuk menempelkan bukti itu ke barisnya sendiri
--
-- Keduanya dibuat di sini.
-- ============================================================

-- ------------------------------------------------------------
-- Bucket bukti transfer
-- ------------------------------------------------------------
-- 🔴 `public = false`, KEBALIKAN dari bucket `avatars` (migrasi 23).
--
-- Bukti transfer adalah tangkapan layar mutasi rekening. Di dalamnya biasanya
-- ada nama pemilik rekening, nomor rekening, sisa saldo, dan riwayat transaksi
-- lain yang tidak ada hubungannya dengan KamelScan. Menaruhnya di bucket publik
-- berarti siapa pun yang memegang URL-nya dapat membacanya — dan URL itu akan
-- melewati log server, riwayat browser, dan tangkapan layar dukungan pelanggan.
--
-- Bedanya dengan foto profil bukan soal tingkat kerahasiaan yang sedikit lebih
-- tinggi. Foto profil memang dimaksudkan untuk dilihat orang lain; mutasi
-- rekening tidak pernah.
--
-- Konsekuensinya bacaannya wajib lewat URL bertanda tangan berumur pendek.
-- Itu memang lebih repot, dan di sini kerepotan itu sepadan: bukti transfer
-- dibuka paling banyak dua kali seumur hidupnya — sekali oleh Owner untuk
-- memastikan yang benar terunggah, sekali oleh Admin saat memverifikasi.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,                                    -- 5 MB; tangkapan layar m-banking
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ------------------------------------------------------------
-- Siapa boleh menulis dan membaca
-- ------------------------------------------------------------
-- Berkas disimpan sebagai `{tenant_id}/{subscription_id}.jpg`, sehingga folder
-- teratas adalah tenant pemiliknya.
--
-- Dikunci ke `tenant_id`, bukan `user_id`, karena yang membayar adalah tenant —
-- dan Bab 5.4 sudah menetapkan seluruh isolasi data di proyek ini memakai
-- `tenant_id`, bukan identitas perorangan.

drop policy if exists proofs_insert_own_tenant on storage.objects;
create policy proofs_insert_own_tenant on storage.objects for insert
  with check (
    bucket_id = 'payment-proofs'
    and public.is_owner()
    and (storage.foldername(name))[1] = public.current_tenant_id()::text
  );

-- Menimpa berkas yang sudah ada: Owner yang salah unggah harus dapat
-- memperbaikinya sendiri selama Admin belum memverifikasi.
drop policy if exists proofs_update_own_tenant on storage.objects;
create policy proofs_update_own_tenant on storage.objects for update
  using (
    bucket_id = 'payment-proofs'
    and public.is_owner()
    and (storage.foldername(name))[1] = public.current_tenant_id()::text
  );

drop policy if exists proofs_read_own_tenant on storage.objects;
create policy proofs_read_own_tenant on storage.objects for select
  using (
    bucket_id = 'payment-proofs'
    and (
      public.is_admin()
      or (storage.foldername(name))[1] = public.current_tenant_id()::text
    )
  );

-- Sengaja tidak ada policy DELETE. Bukti pembayaran adalah catatan keuangan;
-- yang salah unggah ditimpa, bukan dihapus, sehingga tidak ada tenant yang
-- dapat menghilangkan jejak pembayarannya sendiri.

-- ------------------------------------------------------------
-- Owner boleh menempelkan bukti ke barisnya sendiri
-- ------------------------------------------------------------
-- `14_rls.sql` memberi Owner izin INSERT (status `pending`) dan SELECT, tetapi
-- tidak pernah UPDATE. Tanpa itu, langkah 4 Bab 12.2 — "unggah bukti" —
-- mustahil: berkasnya masuk ke bucket, tetapi `subscriptions.proof_url` tidak
-- dapat diisi siapa pun kecuali Admin.
--
-- Kekeliruan yang sama pernah terjadi pada `tenant_settings` (M.14), dan
-- gejalanya sama-sama muncul sebagai "Anda tidak memiliki akses ke data ini"
-- pada perbuatan yang jelas-jelas hak pemiliknya.
drop policy if exists sub_update_proof_owner on public.subscriptions;
create policy sub_update_proof_owner on public.subscriptions for update
  using (
    public.is_owner()
    and tenant_id = public.current_tenant_id()
    and status = 'pending'
  )
  with check (
    public.is_owner()
    and tenant_id = public.current_tenant_id()
    and status = 'pending'
  );

-- ------------------------------------------------------------
-- 🔴 …tetapi HANYA kolom buktinya
-- ------------------------------------------------------------
-- Policy di atas mengizinkan UPDATE pada barisnya, dan RLS tidak mengenal
-- batasan per kolom. Apa adanya, ia membuka lubang yang jauh lebih besar
-- daripada masalah yang dipecahkannya: Owner dapat memilih paket Standar,
-- mentransfer Rp 99.000, lalu mengubah `plan` barisnya sendiri menjadi `pro`
-- sebelum Admin melihatnya. Ia juga dapat menulis `paid_at` dan `period_end`.
--
-- Admin memang memeriksa buktinya dengan mata, dan itu penjagaan yang nyata.
-- Tetapi penjagaan yang bersandar pada ketelitian manusia saat sedang sibuk
-- bukan penjagaan yang boleh diandalkan sendirian untuk urusan uang.
--
-- Trigger dipilih daripada `revoke update … grant update (proof_url)` karena
-- Admin juga berperan `authenticated`: mencabut hak UPDATE di tingkat kolom
-- akan ikut melumpuhkan panel Admin nanti (Bab 11).
create or replace function public.guard_subscription_owner_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Edge Function `activate-subscription` berjalan sebagai service_role, dan
  -- service_role menembus RLS tetapi **tidak** menembus trigger. Tanpa baris
  -- ini, aktivasi langganan justru ditolak oleh penjagaan yang dimaksudkan
  -- untuk membatasi Owner.
  if current_user in ('service_role', 'postgres', 'supabase_admin')
     or public.is_admin() then
    return new;
  end if;

  if new.tenant_id         is distinct from old.tenant_id
     or new.plan              is distinct from old.plan
     or new.status            is distinct from old.status
     or new.amount            is distinct from old.amount
     or new.discount_amount   is distinct from old.discount_amount
     or new.promo_code        is distinct from old.promo_code
     or new.payment_method    is distinct from old.payment_method
     or new.midtrans_order_id is distinct from old.midtrans_order_id
     or new.midtrans_txn_id   is distinct from old.midtrans_txn_id
     or new.verified_by       is distinct from old.verified_by
     or new.period_start      is distinct from old.period_start
     or new.period_end        is distinct from old.period_end
     or new.paid_at           is distinct from old.paid_at
     or new.created_at        is distinct from old.created_at
  then
    raise exception 'SUBSCRIPTION_FIELD_LOCKED'
      using errcode = '42501',
            hint = 'Owner hanya boleh mengisi proof_url pada barisnya sendiri.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_subscription_owner_update on public.subscriptions;
create trigger trg_guard_subscription_owner_update
  before update on public.subscriptions
  for each row
  execute function public.guard_subscription_owner_update();

comment on function public.guard_subscription_owner_update() is
  'Bab 12.2 — Owner hanya boleh mengisi subscriptions.proof_url. Seluruh kolom '
  'lain terkunci baginya, termasuk plan, amount, dan status. Dilewati oleh '
  'service_role (Edge Function aktivasi) dan oleh Admin.';
