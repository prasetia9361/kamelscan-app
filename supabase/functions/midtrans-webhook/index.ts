// ============================================================
// midtrans-webhook  (Bab 12.3)
// ============================================================
// Menerima notifikasi server-to-server dari Midtrans dan menutup tagihan.
//
// 🔴 INILAH SATU-SATUNYA YANG BOLEH MENGAKTIFKAN LANGGANAN.
//    Bab 12.3 aturan 1: "Aktivasi langganan hanya boleh dipicu oleh webhook
//    server-to-server, tidak pernah oleh callback sukses di sisi aplikasi.
//    Callback klien mudah dipalsukan."
//
//    Halaman `finish` Snap hanya memberi tahu pelanggan bahwa ia sudah
//    selesai; ia tidak menyentuh status apa pun. Siapa pun dapat membuka
//    alamat itu tanpa membayar sepeser pun.
//
// 🔴 TIDAK ADA PEMERIKSAAN JWT DI SINI, dan itu memang seharusnya — yang
//    memanggil adalah server Midtrans, bukan pengguna. Penjagaannya adalah
//    **tanda tangan**: sha512(order_id + status_code + gross_amount +
//    MIDTRANS_SERVER_KEY). Tanpa kunci server, tanda tangan yang sah tidak
//    dapat dibuat siapa pun.
//
//    ⚠️ Fungsi ini WAJIB di-deploy dengan `--no-verify-jwt`. Tanpa itu
//    Supabase menolak setiap notifikasi Midtrans dengan 401, dan tidak ada
//    satu pun pembayaran yang pernah aktif — persis cacat P.1, dengan gejala
//    yang sama persis: uang masuk, layar berhenti di "menunggu verifikasi".
//
// 🔴 IDEMPOTEN. Bab 12.3 aturan 3: Midtrans dapat mengirim notifikasi yang
//    sama berkali-kali. Setiap jalan keluar di bawah menjawab 200, dan
//    perubahan status hanya terjadi sekali karena disaring `status = pending`.
// ============================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

/// Balas 200 apa pun yang terjadi, kecuali tanda tangan yang salah.
///
/// Midtrans mengulang notifikasi yang tidak dibalas 200 berkali-kali selama
/// berjam-jam. Membalas 500 untuk keadaan yang tidak akan pernah membaik —
/// misalnya `order_id` yang tidak dikenali — hanya menghasilkan banjir
/// percobaan ulang untuk sesuatu yang tidak dapat diperbaiki dengan mengulang.
function ok(catatan: string) {
  return new Response(JSON.stringify({ ok: true, note: catatan }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function sha512Hex(teks: string): Promise<string> {
  const data = new TextEncoder().encode(teks);
  const buf = await crypto.subtle.digest('SHA-512', data);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/// Perbandingan yang tidak bocor lewat lamanya waktu.
///
/// Perbandingan string biasa berhenti pada huruf pertama yang berbeda, dan
/// selisih waktunya — walau kecil — dapat dipakai menebak tanda tangan huruf
/// demi huruf. Biayanya di sini nol, jadi tidak ada alasan memakai `===`.
function samaAman(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let beda = 0;
  for (let i = 0; i < a.length; i++) beda |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return beda === 0;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('METHOD_NOT_ALLOWED', { status: 405 });
  }

  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY');
  if (!serverKey) {
    // 🔴 500, bukan 200. Ini satu-satunya kegagalan di berkas ini yang MEMBAIK
    // bila diulang: begitu secret-nya dipasang, percobaan ulang Midtrans akan
    // berhasil dengan sendirinya. Membalas 200 di sini berarti pembayaran
    // sungguhan hilang tanpa jejak.
    console.error('KAMELSCAN_MIDTRANS secret MIDTRANS_SERVER_KEY belum dipasang');
    return new Response('NOT_CONFIGURED', { status: 500 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response('INVALID_BODY', { status: 400 });
  }

  const orderId = String(body.order_id ?? '');
  const statusCode = String(body.status_code ?? '');
  const grossAmount = String(body.gross_amount ?? '');
  const signature = String(body.signature_key ?? '');
  const trxStatus = String(body.transaction_status ?? '');
  const fraud = String(body.fraud_status ?? '');
  const trxId = String(body.transaction_id ?? '');

  // ---- 1. Tanda tangan ----
  //
  // 🔴 Diperiksa PALING DULU, sebelum satu pun baris dibaca dari database.
  // Segala yang ada di badan permintaan berasal dari luar sampai baris ini
  // lolos.
  const harusnya = await sha512Hex(orderId + statusCode + grossAmount + serverKey);
  if (!samaAman(harusnya, signature.toLowerCase())) {
    console.error(`KAMELSCAN_MIDTRANS tanda tangan salah · order=${orderId}`);
    return new Response('invalid signature', { status: 403 });
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ---- 2. Barisnya ----
  const { data: sub } = await admin
    .from('subscriptions')
    .select('id, status, amount, tenant_id')
    .eq('midtrans_order_id', orderId)
    .maybeSingle();

  if (!sub) {
    console.error(`KAMELSCAN_MIDTRANS order tidak dikenali · ${orderId}`);
    return ok('order tidak dikenali');
  }

  // ---- 3. Sudah selesai? ----
  //
  // Idempoten (Bab 12.3 aturan 3). Baris yang sudah `paid` tidak boleh
  // disentuh lagi: `activate_subscription()` akan mengisi ulang dompet token
  // sekali lagi, dan notifikasi ganda dari Midtrans adalah keadaan yang
  // NORMAL, bukan gangguan.
  if (sub.status === 'paid') return ok('sudah lunas');

  const lunas = trxStatus === 'settlement'
    || (trxStatus === 'capture' && fraud === 'accept');

  // ---- 4. Yang belum selesai ----
  if (!lunas) {
    // Status yang belum final (`pending`, `capture` dengan fraud `challenge`)
    // dibiarkan apa adanya — Midtrans akan mengabari lagi.
    const berakhir: Record<string, string> = {
      expire: 'expired',
      cancel: 'cancelled',
      deny: 'failed',
      failure: 'failed',
    };
    const statusBaru = berakhir[trxStatus];

    if (statusBaru) {
      // 🔴 Menutup barisnya PENTING, bukan sekadar kerapian: `create-payment`
      // menolak membuat tagihan baru selama masih ada yang `pending`. Tanpa
      // ini, satu pembayaran yang dibatalkan mengunci pelanggan selama 24 jam
      // penuh dari mencoba lagi.
      await admin
        .from('subscriptions')
        .update({ status: statusBaru, midtrans_txn_id: trxId || null })
        .eq('id', sub.id)
        .eq('status', 'pending');

      console.log(
        `KAMELSCAN_MIDTRANS ${orderId} · ${trxStatus} → ${statusBaru}`,
      );
      return ok(`ditutup sebagai ${statusBaru}`);
    }

    console.log(`KAMELSCAN_MIDTRANS ${orderId} · ${trxStatus} belum final`);
    return ok('belum final');
  }

  // ---- 5. Nominalnya harus cocok ----
  //
  // ⚠️ Tanda tangannya memang sudah memuat `gross_amount`, jadi angka ini
  // tidak dapat dipalsukan tanpa kunci server. Yang dijaga di sini keadaan
  // lain: tagihan yang nominalnya sempat berubah di sisi kita sesudah Snap
  // dibuat. Bila itu terjadi, yang benar adalah BERHENTI dan menyerahkannya
  // ke manusia — bukan mengaktifkan langganan dengan angka yang tidak kita
  // kenali.
  const dibayar = Number(grossAmount);
  if (Number.isFinite(dibayar) && Math.round(Number(sub.amount)) !== Math.round(dibayar)) {
    console.error(
      `KAMELSCAN_MIDTRANS nominal tidak cocok · ${orderId} · ` +
      `tagihan=${sub.amount} dibayar=${dibayar}`,
    );
    return ok('nominal tidak cocok, diserahkan ke Admin');
  }

  // ---- 6. Lunas ----
  //
  // 🔴 Yang dilakukan hanyalah mengubah status menjadi `paid`. Kenaikan tier,
  // periode 30 hari, pengisian ulang token, buku besar, dan jejak audit
  // seluruhnya dikerjakan trigger `activate_subscription()` (migrasi 28) —
  // jalur yang sama persis dengan transfer manual, dan sudah terbukti pada
  // uang sungguhan.
  //
  // ⚠️ Bab 12.4 di dokumen menuliskannya sebagai RPC
  // `activate_subscription(p_subscription_id)`. Di proyek ini ia berbentuk
  // TRIGGER, bukan RPC — penyimpangan yang disengaja dan tercatat di P.1.
  // Jangan mencari fungsi RPC itu; ia memang tidak ada.
  //
  // `.eq('status', 'pending')` adalah penjagaan terakhir terhadap dua
  // notifikasi yang tiba bersamaan: yang kedua tidak menemukan baris untuk
  // diubah, sehingga triggernya tidak berjalan dua kali.
  const { data: diubah, error: updErr } = await admin
    .from('subscriptions')
    .update({ status: 'paid', midtrans_txn_id: trxId || null })
    .eq('id', sub.id)
    .eq('status', 'pending')
    .select('id');

  if (updErr) {
    // 🔴 500 supaya Midtrans mengulang. Uangnya sudah berpindah; kegagalan di
    // sini adalah satu-satunya keadaan yang benar-benar layak diulang.
    console.error(`KAMELSCAN_MIDTRANS gagal melunasi ${orderId} · ${updErr.message}`);
    return new Response('UPDATE_FAILED', { status: 500 });
  }

  console.log(
    `KAMELSCAN_MIDTRANS LUNAS ${orderId} · ${diubah?.length ?? 0} baris`,
  );
  return ok('lunas');
});
