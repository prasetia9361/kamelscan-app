// ============================================================
// get-video-url  (Bab 8.8 — pemutaran & unduh, rumahnya di Bab 9.4)
// ============================================================
// Menerbitkan presigned GET berumur 15 menit agar aplikasi dapat memutar dan
// mengunduh video langsung dari Cloudflare R2.
//
// 🔴 KREDENSIAL R2 TIDAK BOLEH ADA DI APLIKASI FLUTTER (Bab 8.7). Access key R2
//    dapat membaca dan menghapus SELURUH video seluruh pelanggan. Yang dipegang
//    aplikasi hanyalah URL berumur pendek untuk satu berkas.
//
// ⚠️ RLS TIDAK BERLAKU DI SINI. Fungsi ini memakai service role, jadi seluruh
//    aturan siapa-boleh-melihat-apa ditulis ulang di bawah dengan tangan, dan
//    harus tetap sejalan dengan policy `videos_select` di `14_rls.sql`.
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

/// Bab 8.8 menetapkan 15 menit. Cukup untuk menonton video 30–60 detik beserta
/// mengulangnya beberapa kali, tetapi tidak cukup lama untuk dipakai ulang bila
/// URL-nya tersebar.
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

  let body: { video_id?: string; download?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const videoId = (body.video_id ?? '').trim();

  // Satu URL, dua keperluan yang berbeda perlakuannya. Untuk **menonton**,
  // berkasnya harus disajikan apa adanya agar pemutar dapat melompat ke tengah
  // video (byte-range). Untuk **mengunduh**, ia perlu nama berkas yang dikenali
  // manusia. Menyatukan keduanya dengan `attachment` membuat halaman publik
  // Bab 10.6 mengunduh berkas alih-alih memutarnya.
  const forDownload = body.download === true;
  if (!/^[0-9a-f-]{36}$/i.test(videoId)) {
    return json({ error: 'INVALID_VIDEO_ID' }, 400);
  }

  const { data: profile } = await admin
    .from('users')
    .select('tenant_id, role, is_active')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile) return json({ error: 'UNAUTHORIZED' }, 401);
  if (!profile.is_active) return json({ error: 'ACCOUNT_DISABLED' }, 403);

  // ---- 🔴 Bab 2.2 catatan 5 — Admin platform DITOLAK ----
  //
  // Admin boleh melihat metadata pelanggan (untuk dukungan dan penagihan),
  // tetapi TIDAK BOLEH melihat isi videonya. Video packing adalah rekaman
  // dalam gudang pelanggan: wajah pegawai, tata letak, dan barang yang
  // dikirim. Kepercayaan produk ini bersandar pada batas itu.
  //
  // Penolakan ini berdiri di sini, bukan di aplikasi, karena aplikasi dapat
  // diganti sedangkan Edge Function tidak.
  if (profile.role === 'admin') return json({ error: 'ADMIN_FORBIDDEN' }, 403);

  const { data: video } = await admin
    .from('package_videos')
    .select('id, tenant_id, user_id, shop_id, status, storage_key, resi_code, expires_at')
    .eq('id', videoId)
    .maybeSingle();

  if (!video) return json({ error: 'NOT_FOUND' }, 404);
  if (profile.tenant_id !== video.tenant_id) return json({ error: 'FORBIDDEN' }, 403);

  // ---- Cakupan per peran — cerminan policy `videos_select` ----
  let allowed = profile.role === 'owner' || video.user_id === user.id;

  if (!allowed) {
    // Packer boleh melihat video se-toko hanya bila Owner mengizinkannya
    // DAN packer itu memang ditugaskan ke toko tersebut (Bab 2.2 catatan 3).
    const { data: setting } = await admin
      .from('tenant_settings')
      .select('shop_history_visible_to_packer')
      .eq('tenant_id', video.tenant_id)
      .maybeSingle();

    if (setting?.shop_history_visible_to_packer) {
      const { data: assignment } = await admin
        .from('shop_packers')
        .select('user_id')
        .eq('user_id', user.id)
        .eq('shop_id', video.shop_id)
        .maybeSingle();
      allowed = assignment != null;
    }
  }

  if (!allowed) return json({ error: 'FORBIDDEN' }, 403);

  // ---- Bab 7.6 — langganan berakhir mengunci pemutaran ----
  //
  // Riwayatnya tetap terlihat (metadata masih boleh dibaca), tetapi isi
  // videonya tidak dapat diambil sampai langganan diperpanjang.
  const { data: tenant } = await admin
    .from('tenants')
    .select('status')
    .eq('id', video.tenant_id)
    .maybeSingle();

  if (!tenant || !['trial', 'active'].includes(tenant.status)) {
    return json({ error: 'SUBSCRIPTION_INACTIVE' }, 402);
  }

  // ---- Berkasnya harus benar-benar ada ----
  //
  // Dibedakan dari NOT_FOUND: barisnya ada, isinya yang tidak. Aplikasi
  // menerjemahkan keduanya menjadi kalimat yang berbeda — "video belum
  // terkirim" bukan hal yang sama dengan "video sudah dihapus".
  if (video.status === 'expired') return json({ error: 'VIDEO_EXPIRED' }, 410);
  if (video.status === 'deleted') return json({ error: 'NOT_FOUND' }, 404);
  if (video.status !== 'uploaded' || !video.storage_key) {
    return json({ error: 'NOT_UPLOADED_YET' }, 409);
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
        // Nama berkas saat diunduh memakai nomor resi, bukan UUID. Packer yang
        // mengirim bukti ke pusat resolusi marketplace harus dapat mengenali
        // berkasnya tanpa membukanya satu per satu.
        ResponseContentDisposition: forDownload
          ? `attachment; filename="${video.resi_code.replace(/[^\w.-]/g, '_')}.mp4"`
          : 'inline',
      }),
      { expiresIn: EXPIRES_IN },
    );

    return json({ url, expires_in: EXPIRES_IN, resi_code: video.resi_code });
  } catch (e) {
    return json(
      { error: 'SIGN_FAILED', detail: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
