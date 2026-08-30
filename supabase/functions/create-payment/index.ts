// ============================================================
// create-payment  (Bab 12.3)
// ============================================================
// Membuat tagihan Midtrans Snap atas nama Owner, lalu mengembalikan
// `redirect_url` halaman pembayaran Snap.
//
// 🔴 MIDTRANS_SERVER_KEY hanya boleh hidup di sini, sebagai Edge Function
//    secret (Bab 11.6). Kunci itu cukup untuk menagih atas nama Product Owner;
//    ia tidak pernah masuk aplikasi Flutter dan tidak pernah masuk tabel mana
//    pun. Halaman Admin > Metode Pembayaran sengaja tidak punya kolomnya, dan
//    ada tes yang gagal bila seseorang menambahkannya.
//
// 🔴 NOMINAL DIHITUNG DI SINI, BUKAN DITERIMA DARI APLIKASI.
//    Bab 12.3 aturan 4: "Nominal dihitung di server dari platform_settings dan
//    tabel promos. Jangan pernah mempercayai nominal yang dikirim aplikasi."
//
//    Ini perbedaan menentukan dari jalur transfer manual, dan alasannya bukan
//    kerapian: pada transfer manual, Admin melihat bukti transfernya dan
//    mencocokkan angkanya dengan tangan — manusia menjadi penjaga terakhir.
//    Pada Midtrans tidak ada yang memeriksa. Nominal yang dikirim aplikasi
//    berarti siapa pun yang dapat menyunting permintaan HTTP dapat membeli
//    paket Pro seharga seribu rupiah, dan pembayarannya akan lunas dengan
//    benar sampai ke buku besar.
//
// Alur:
//   1. Pastikan pemanggil punya sesi valid dan perannya `owner`
//   2. Pastikan Midtrans memang sedang dinyalakan Admin
//   3. Bersihkan tagihan Midtrans yang sudah lewat 24 jam (Bab 12.2 langkah 3)
//   4. Tolak bila masih ada tagihan yang berjalan
//   5. Hitung harga dari `platform_settings.pricing`
//   6. Periksa dan hitung promo dari tabel `promos` -- juga di server
//   7. Buat baris `subscriptions` berstatus pending
//   8. Minta Snap token ke Midtrans
//   9. Kembalikan redirect_url
// ============================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/// Alamat Snap. Sandbox dan produksi berbeda host, dan memakai kunci sandbox
/// pada host produksi ditolak dengan 401 yang tidak menyebutkan sebabnya.
///
/// Sakelarnya `MIDTRANS_IS_PRODUCTION`. Sengaja **tidak** menebak dari awalan
/// kunci (`SB-Mid-server-`): menebak berarti satu kunci yang salah tempel
/// diam-diam mengarahkan uang sungguhan ke sandbox, atau sebaliknya.
function snapEndpoint(isProduction: boolean): string {
  return isProduction
    ? 'https://app.midtrans.com/snap/v1/transactions'
    : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
}

/// Potongan promo, dihitung dengan aturan yang sama persis dengan
/// `Promo.discountFor` di Flutter — dan **inilah yang menentukan**.
///
/// Yang di aplikasi hanya agar Owner melihat angkanya sebelum menekan Bayar.
function discountFor(
  price: number,
  type: string,
  value: number,
): number {
  const mentah = type === 'percent' ? (price * value) / 100 : value;
  return Math.floor(Math.min(Math.max(mentah, 0), price));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY');
  if (!serverKey) {
    // Dikatakan apa adanya. Kegagalan karena secret belum dipasang terlihat
    // persis seperti kegagalan jaringan bila pesannya disamarkan.
    return json({ error: 'MIDTRANS_NOT_CONFIGURED' }, 503);
  }
  const isProduction = Deno.env.get('MIDTRANS_IS_PRODUCTION') === 'true';

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'UNAUTHORIZED' }, 401);

  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });

  // ---- 1. Sesi pemanggil ----
  const { data: { user }, error: userErr } = await caller.auth.getUser();
  if (userErr || !user) return json({ error: 'UNAUTHORIZED' }, 401);

  const { data: profile } = await admin
    .from('users')
    .select('tenant_id, role, is_active, email, full_name, phone')
    .eq('id', user.id)
    .single();

  if (!profile || profile.role !== 'owner' || profile.is_active !== true) {
    return json({ error: 'FORBIDDEN' }, 403);
  }

  let body: { plan?: string; promo_code?: string; finish_url?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const plan = (body.plan ?? '').trim();
  if (plan !== 'standar' && plan !== 'pro') {
    return json({ error: 'INVALID_PLAN' }, 400);
  }

  // ---- 2. Midtrans harus sedang dinyalakan Admin ----
  //
  // Sakelarnya di `platform_settings.payment_methods` (Bab 11.6), dan seluruh
  // gunanya adalah agar Midtrans dapat dinyalakan tanpa merilis aplikasi baru.
  // Diperiksa di server juga, bukan hanya di layar: sakelar yang hanya
  // menyembunyikan tombol tidak menghentikan siapa pun yang memanggil
  // fungsinya langsung.
  const { data: methodsRow } = await admin
    .from('platform_settings')
    .select('value')
    .eq('key', 'payment_methods')
    .maybeSingle();

  if (methodsRow?.value?.midtrans_enabled !== true) {
    return json({ error: 'MIDTRANS_DISABLED' }, 403);
  }

  // ---- 3. Bersihkan tagihan Midtrans yang sudah kedaluwarsa ----
  //
  // Bab 12.2 langkah 3 memberi batas 24 jam. Tanpa pembersihan ini, satu
  // percobaan bayar yang ditinggalkan mengunci pelanggan selamanya: tagihannya
  // tetap `pending`, dan langkah 4 di bawah menolak setiap percobaan
  // berikutnya. Webhook juga menutup baris seperti ini saat Midtrans
  // mengirim `expire`, tetapi pelanggan yang menutup jendelanya sebelum
  // Midtrans sempat memberi tahu tidak pernah mendapat notifikasi itu.
  const batas = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  await admin
    .from('subscriptions')
    .update({ status: 'expired' })
    .eq('tenant_id', profile.tenant_id)
    .eq('status', 'pending')
    .eq('payment_method', 'midtrans')
    .lt('created_at', batas);

  // ---- 4. Satu tagihan berjalan pada satu waktu ----
  //
  // Bab 12.2: Owner yang lupa pernah menekan Bayar akan membuat tagihan kedua,
  // mentransfer nominal yang berbeda dari tagihan pertama, dan pembayarannya
  // tidak cocok dengan satu pun di antaranya.
  const { data: berjalan } = await admin
    .from('subscriptions')
    .select('id, payment_method')
    .eq('tenant_id', profile.tenant_id)
    .eq('status', 'pending')
    .limit(1)
    .maybeSingle();

  if (berjalan) {
    return json(
      { error: 'PENDING_EXISTS', payment_method: berjalan.payment_method },
      409,
    );
  }

  // ---- 5. Harga, dari platform_settings ----
  const { data: pricingRow } = await admin
    .from('platform_settings')
    .select('value')
    .eq('key', 'pricing')
    .maybeSingle();

  const harga = Number(pricingRow?.value?.[plan]?.price);
  if (!Number.isFinite(harga) || harga <= 0) {
    // Sama seperti `activate_subscription()`: lebih baik menolak dengan galat
    // yang jelas daripada menagih angka yang dikarang.
    return json({ error: 'PRICING_MISSING_FOR_PLAN', plan }, 503);
  }

  // ---- 6. Promo, juga diperiksa di server ----
  //
  // 🔴 Seluruh syaratnya diperiksa ulang di sini: aktif, sudah mulai, belum
  // lewat, belum habis kuotanya, dan berlaku untuk paket ini. Pemeriksaan di
  // aplikasi (`Promo.rejectionKey`) hanya agar Owner tahu lebih dulu; ia
  // berjalan di perangkat yang dapat disunting siapa pun.
  const kode = (body.promo_code ?? '').trim();
  let potongan = 0;
  let kodeDipakai: string | null = null;

  if (kode) {
    const { data: promo } = await admin
      .from('promos')
      .select('code, discount_type, discount_value, applies_to, valid_from, valid_until, max_uses, used_count, is_active')
      .eq('code', kode)
      .maybeSingle();

    const kini = Date.now();
    const sah = promo
      && promo.is_active === true
      && (!promo.valid_from || new Date(promo.valid_from).getTime() <= kini)
      && new Date(promo.valid_until).getTime() >= kini
      && (promo.max_uses === null || promo.used_count < promo.max_uses)
      && (promo.applies_to === null || promo.applies_to === plan);

    if (!sah) return json({ error: 'PROMO_INVALID', code: kode }, 400);

    potongan = discountFor(
      harga,
      promo!.discount_type,
      Number(promo!.discount_value),
    );
    kodeDipakai = promo!.code;
  }

  const nominal = Math.round(harga - potongan);

  // Midtrans menolak gross_amount 0. Promo yang menutupi seluruh harga berarti
  // paketnya gratis — itu urusan Admin, bukan urusan pintu pembayaran, dan
  // menagih Rp 0 lewat Midtrans hanya menghasilkan galat yang membingungkan.
  if (nominal <= 0) return json({ error: 'AMOUNT_ZERO' }, 400);

  // ---- 7. Baris subscriptions ----
  //
  // Dibuat SEBELUM menghubungi Midtrans, supaya `order_id` dapat memakai id
  // barisnya sendiri. Dengan begitu webhook selalu menemukan barisnya, dan
  // tidak ada pemetaan kedua yang harus dijaga tetap sinkron.
  const { data: sub, error: subErr } = await admin
    .from('subscriptions')
    .insert({
      tenant_id: profile.tenant_id,
      plan,
      status: 'pending',
      amount: nominal,
      discount_amount: potongan,
      promo_code: kodeDipakai,
      payment_method: 'midtrans',
    })
    .select('id')
    .single();

  if (subErr || !sub) return json({ error: 'BILL_CREATE_FAILED' }, 500);

  // `order_id` Midtrans dibatasi 50 karakter; "KS-" + uuid = 39.
  const orderId = `KS-${sub.id}`;

  const { error: orderErr } = await admin
    .from('subscriptions')
    .update({ midtrans_order_id: orderId })
    .eq('id', sub.id);

  if (orderErr) return json({ error: 'BILL_CREATE_FAILED' }, 500);

  // ---- 8. Minta Snap token ----
  const finishUrl = (body.finish_url ?? '').trim();

  const snapBody = {
    transaction_details: { order_id: orderId, gross_amount: nominal },
    item_details: [
      {
        id: plan,
        price: nominal,
        quantity: 1,
        name: `KamelScan ${plan === 'pro' ? 'Pro' : 'Standar'} 30 hari`,
      },
    ],
    customer_details: {
      first_name: profile.full_name ?? '',
      email: profile.email ?? '',
      phone: profile.phone ?? '',
    },
    // Snap mengembalikan pelanggan ke sini setelah selesai. Halamannya hanya
    // menampilkan keadaan; yang benar-benar mengaktifkan langganan adalah
    // webhook (Bab 12.3 aturan 1).
    ...(finishUrl ? { callbacks: { finish: finishUrl } } : {}),
  };

  let snap: Response;
  try {
    snap = await fetch(snapEndpoint(isProduction), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        // Basic auth: server key sebagai username, sandi kosong.
        Authorization: `Basic ${btoa(`${serverKey}:`)}`,
      },
      body: JSON.stringify(snapBody),
    });
  } catch (_e) {
    await admin.from('subscriptions').update({ status: 'failed' }).eq('id', sub.id);
    return json({ error: 'MIDTRANS_UNREACHABLE' }, 502);
  }

  const snapJson = await snap.json().catch(() => null);

  if (!snap.ok || !snapJson?.token) {
    // 🔴 Barisnya ditutup, bukan dibiarkan `pending`. Tagihan yang menggantung
    // tanpa transaksi Midtrans di baliknya akan menghalangi percobaan
    // berikutnya selama 24 jam penuh (langkah 4 di atas), untuk kesalahan yang
    // sama sekali bukan kesalahan pelanggan.
    await admin.from('subscriptions').update({ status: 'failed' }).eq('id', sub.id);
    return json(
      {
        error: 'MIDTRANS_REJECTED',
        status: snap.status,
        detail: snapJson?.error_messages ?? null,
      },
      502,
    );
  }

  return json({
    order_id: orderId,
    subscription_id: sub.id,
    amount: nominal,
    discount: potongan,
    token: snapJson.token,
    redirect_url: snapJson.redirect_url,
    is_production: isProduction,
  });
});
