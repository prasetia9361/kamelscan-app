// ============================================================
// get-upload-url  (Bab 8.7)
// ============================================================
// Menerbitkan presigned URL agar aplikasi dapat mengunggah video langsung ke
// Cloudflare R2 tanpa melewati server.
//
// 🔴 KREDENSIAL R2 TIDAK BOLEH ADA DI APLIKASI FLUTTER (Bab 8.7).
//    Access key R2 dapat membaca dan menghapus SELURUH video seluruh
//    pelanggan. Yang dipegang aplikasi hanyalah URL berumur 15 menit untuk
//    satu berkas.
//
// Bucket: `kamelscan-videos`.
// ⚠️ Bab 8.7 menulis `scanproof-videos` — itu nama dari sebelum produk
//    berganti nama, dan bucket dengan nama itu TIDAK ADA. Bucket yang benar-
//    benar ada di akun Cloudflare hanya `kamelscan-videos` dan
//    `kamelscan-assets`.
// ============================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { S3Client } from 'npm:@aws-sdk/client-s3@3';
import { PutObjectCommand } from 'npm:@aws-sdk/client-s3@3';
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

/// Umur presigned URL. Bab 8.7 menetapkan 15 menit — cukup untuk video 1–3 MB
/// bahkan pada jaringan gudang yang buruk, tetapi tidak cukup lama untuk
/// dipakai ulang bila URL-nya bocor.
const EXPIRES_IN = 900;

const BUCKET = Deno.env.get('R2_BUCKET_VIDEOS') ?? 'kamelscan-videos';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'UNAUTHORIZED' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const caller = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userErr } = await caller.auth.getUser();
  if (userErr || !user) return json({ error: 'UNAUTHORIZED' }, 401);

  let body: { video_id?: string; content_length?: number };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const videoId = (body.video_id ?? '').trim();
  if (!/^[0-9a-f-]{36}$/i.test(videoId)) {
    return json({ error: 'INVALID_VIDEO_ID' }, 400);
  }

  // ---- Video harus benar-benar milik pemanggil ----
  //
  // Tanpa pemeriksaan ini, siapa pun yang punya sesi valid bisa meminta URL
  // tulis untuk video milik tenant lain dan menimpanya. RLS tidak melindungi
  // di sini karena kita memakai service role.
  const { data: video } = await admin
    .from('package_videos')
    .select('id, tenant_id, user_id, status, storage_key')
    .eq('id', videoId)
    .maybeSingle();

  if (!video) return json({ error: 'NOT_FOUND' }, 404);

  const { data: profile } = await admin
    .from('users')
    .select('tenant_id, role')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile || profile.tenant_id !== video.tenant_id) {
    return json({ error: 'FORBIDDEN' }, 403);
  }
  // Perekamnya sendiri, atau Owner tenant tersebut.
  if (video.user_id !== user.id && profile.role !== 'owner') {
    return json({ error: 'FORBIDDEN' }, 403);
  }

  // Video yang sudah terunggah tidak boleh ditimpa — bukti yang sudah
  // tersimpan harus tetap sebagaimana adanya (Bab 1.3).
  if (video.status === 'uploaded') {
    return json({ error: 'ALREADY_UPLOADED' }, 409);
  }

  // ---- Susun kunci objek ----
  // tenant/{tenant_id}/{yyyy}/{mm}/{video_id}.mp4 (Bab 8.7)
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
  const key = video.storage_key ??
    `tenant/${video.tenant_id}/${yyyy}/${mm}/${videoId}.mp4`;

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
      new PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        ContentType: 'video/mp4',
      }),
      { expiresIn: EXPIRES_IN },
    );

    // Simpan kunci sekarang agar tetap sama bila upload diulang setelah gagal.
    if (!video.storage_key) {
      await admin
        .from('package_videos')
        .update({ storage_key: key })
        .eq('id', videoId);
    }

    return json({ url, key, expires_in: EXPIRES_IN, bucket: BUCKET });
  } catch (e) {
    return json(
      { error: 'SIGN_FAILED', detail: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
