-- ============================================================
-- 36_cancel_bill.sql  (Bab 12.2 — pelanggan membatalkan tagihannya sendiri)
-- ============================================================
-- Tidak ada satu pun jalan bagi Owner untuk melepaskan diri dari tagihan yang
-- terlanjur dibuat. `subscriptions` sengaja hanya punya policy `select` dan
-- `insert` bagi Owner (migrasi 14) — ia dapat membuat tagihan, tetapi tidak
-- pernah dapat menutupnya.
--
-- 🔴 Akibatnya nyata dan sudah terjadi pada Product Owner sendiri: satu
-- tagihan dari hari Kamis menggantung sampai Minggu, dan selama itu tombol
-- Bayar mati dengan pesan "Selesaikan dulu pembayaran yang sedang berjalan".
--
-- Yang membuatnya lebih buruk: halaman Checkout menampilkan tombol **"Buat
-- tagihan baru"** yang tidak membatalkan apa pun — ia hanya berpindah ke
-- halaman Pembayaran, tempat tagihan lamanya masih berdiri dan tombol
-- Bayarnya masih mati. Tombol yang menjanjikan jalan keluar lalu memutar
-- kembali ke tempat yang sama.
--
-- ⚠️ Sejak Midtrans hidup, kebuntuan ini jadi lebih mahal: `create-payment`
-- menolak membuat tagihan Snap selama masih ada tagihan `pending` apa pun —
-- termasuk tagihan transfer manual yang sudah basi.
-- ============================================================

-- ------------------------------------------------------------
-- 🔴 HANYA TAGIHAN YANG BELUM ADA BUKTINYA
-- ------------------------------------------------------------
-- Keputusan Product Owner 31 Agustus 2026.
--
-- Begitu bukti transfer diunggah, satu-satunya jalan adalah Admin menolaknya
-- dari panel — lengkap dengan alasan yang dibaca pelanggan (migrasi 32).
--
-- Alasannya bukan kerapian: pelanggan yang sudah benar-benar mentransfer lalu
-- menekan Batalkan akan kehilangan jejak uangnya, dan satu-satunya orang yang
-- dapat memeriksa mutasi rekening adalah Admin. Membiarkan tombol itu hidup
-- berarti memindahkan keputusan tentang uang sungguhan kepada orang yang tidak
-- punya cara memeriksanya.
-- ------------------------------------------------------------

create or replace function public.cancel_pending_subscription(
  p_subscription_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant  uuid;
  v_status  sub_status;
  v_bukti   text;
  v_saya    uuid;
begin
  -- 🔴 `security definer` mematikan RLS, jadi kepemilikannya diperiksa di
  -- sini dengan tangan. Tanpa baris-baris ini, siapa pun yang berhasil login
  -- dapat membatalkan tagihan pelanggan mana pun hanya dengan menebak id-nya.
  v_saya := public.current_tenant_id();
  if v_saya is null then
    raise exception 'UNAUTHORIZED'
      using errcode = '42501', hint = 'Sesi tidak dikenali.';
  end if;

  select tenant_id, status, proof_url
    into v_tenant, v_status, v_bukti
    from public.subscriptions
   where id = p_subscription_id
     for update;

  if v_tenant is null then
    raise exception 'NOT_FOUND'
      using errcode = '22023', hint = 'Tagihan ini tidak ditemukan.';
  end if;

  -- Bukan milik penelepon. Admin punya jalannya sendiri lewat panel.
  if v_tenant <> v_saya then
    raise exception 'FORBIDDEN'
      using errcode = '42501',
            hint = 'Tagihan ini bukan milik akun Anda.';
  end if;

  if v_status <> 'pending' then
    -- Bukan galat: dua ketukan beruntun pada tombol yang sama akan sampai di
    -- sini, dan menakut-nakuti orang untuk sesuatu yang sudah selesai tidak
    -- ada gunanya.
    return format('Tagihan ini memang sudah tidak berjalan (%s).', v_status);
  end if;

  -- 🔴 Bukti sudah diunggah — berhenti.
  if v_bukti is not null and btrim(v_bukti) <> '' then
    raise exception 'PROOF_UPLOADED'
      using errcode = '22023',
            hint = 'Bukti transfer sudah diunggah, jadi tagihan ini hanya '
                   'dapat ditutup Admin. Hubungi kami bila Anda tidak jadi '
                   'membayar.';
  end if;

  update public.subscriptions
     set status = 'cancelled'
   where id = p_subscription_id;

  -- Jejak audit. Pembatalan oleh pelanggan tetap peristiwa yang menyangkut
  -- uang, dan saat ia bertanya "kenapa tagihan saya hilang", inilah yang
  -- menjawabnya.
  insert into public.audit_logs
        (tenant_id, actor_id, action, entity, entity_id, metadata)
  values (
    v_tenant, auth.uid(), 'subscription.cancel_by_owner', 'subscriptions',
    p_subscription_id, jsonb_build_object('oleh', 'owner')
  );

  return 'Tagihan dibatalkan.';
end;
$$;

comment on function public.cancel_pending_subscription(uuid) is
  'Bab 12.2 - Owner membatalkan tagihannya sendiri yang belum ada buktinya. '
  'Menolak bila proof_url sudah terisi: tagihan berbukti hanya boleh ditutup '
  'Admin, karena hanya Admin yang dapat memeriksa mutasi rekening.';

grant execute on function public.cancel_pending_subscription(uuid) to authenticated;
revoke execute on function public.cancel_pending_subscription(uuid) from anon, public;
