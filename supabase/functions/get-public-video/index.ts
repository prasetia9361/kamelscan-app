// ============================================================
// get-public-video  (Bab 8.8 / Bab 10.6 — halaman bukti publik)
// ============================================================
// Melayani halaman `/v/{token}` yang dibuka **tanpa login** oleh pusat resolusi
// marketplace.
//
// 🔴 Ini satu-satunya Edge Function yang sengaja tidak memeriksa sesi. Yang
//    menjaganya adalah tokennya sendiri: 160 bit acak, dan masa berlakunya
//    mengikuti masa simpan video.
//
// ⚠️ Karena terbuka, yang dikembalikan dibatasi seketat mungkin. `tenant_id`,
//    `user_id`, `shop_id`, dan `storage_key` TIDAK PERNAH ikut keluar — dari
//    id itu orang luar dapat menyusun peta pelanggan, sedangkan yang mereka
//    butuhkan untuk memeriksa sengketa hanyalah isi buktinya.
// ============================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { GetObjectCommand, S3Client } from 'npm:@aws-sdk/client-s3@3';
import { getSignedUrl } from 'npm:@aws-sdk/s3-request-presigner@3';

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

const EXPIRES_IN = 900;
const BUCKET = Deno.env.get('R2_BUCKET_VIDEOS') ?? 'kamelscan-videos';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const token = (body.token ?? '').trim();

  // Bentuk token diperiksa lebih dulu supaya percobaan menebak tidak pernah
  // sampai menyentuh database.
  if (!/^[a-z0-9]{32}$/.test(token)) {
    return json({ error: 'INVALID_TOKEN' }, 400);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: video } = await admin
    .from('package_videos')
    .select(
      'resi_code, type, status, scan_date, duration_seconds, file_size_bytes, ' +
        'location_lat, location_lng, time_verified, storage_key, ' +
        'public_expires_at, shops(shop_name, market_name)',
    )
    .eq('public_token', token)
    .maybeSingle();

  // Token yang tidak dikenal dan token yang sudah mati dijawab sama-sama 404,
  // tanpa menyebut mana yang mana. Membedakannya akan memberi tahu penebak
  // bahwa tokennya pernah benar.
  if (!video) return json({ error: 'NOT_FOUND' }, 404);

  const kedaluwarsa = !video.public_expires_at ||
    new Date(video.public_expires_at) <= new Date();
  if (kedaluwarsa) return json({ error: 'LINK_EXPIRED' }, 410);

  if (video.status !== 'uploaded' || !video.storage_key) {
    return json({ error: 'NOT_AVAILABLE' }, 409);
  }

  const r2 = new S3Client({
    region: 'auto',
    endpoint: Deno.env.get('R2_ENDPOINT')!,
    credentials: {
      accessKeyId: Deno.env.get('R2_ACCESS_KEY_ID')!,
      secretAccessKey: Deno.env.get('R2_SECRET_ACCESS_KEY')!,
    },
  });

  try {
    const url = await getSignedUrl(
      r2,
      new GetObjectCommand({
        Bucket: BUCKET,
        Key: video.storage_key,
        ResponseContentDisposition: 'inline',
      }),
      { expiresIn: EXPIRES_IN },
    );

    const shop = video.shops as { shop_name?: string; market_name?: string } | null;

    return json({
      url,
      expires_in: EXPIRES_IN,
      resi_code: video.resi_code,
      type: video.type,
      scan_date: video.scan_date,
      duration_seconds: video.duration_seconds,
      file_size_bytes: video.file_size_bytes,
      location_lat: video.location_lat,
      location_lng: video.location_lng,
      // Bab 8.5 / L.2 — penanda ini sudah terbakar ke gambar videonya. Ia ikut
      // dikirim agar halaman publik menyatakan hal yang sama dengan yang
      // terlihat di video; menyembunyikannya di sini akan membuat pembaca
      // mengira aplikasinya menutupi sesuatu.
      time_verified: video.time_verified,
      shop_name: shop?.shop_name ?? null,
      market_name: shop?.market_name ?? null,
      // Sisa masa berlaku tautan — Bab 9.4 mewajibkannya tampil, karena pusat
      // resolusi marketplace kadang membuka tautannya beberapa hari kemudian.
      link_expires_at: video.public_expires_at,
    });
  } catch (e) {
    return json(
      { error: 'SIGN_FAILED', detail: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
