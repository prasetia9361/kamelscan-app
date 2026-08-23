// ============================================================
// create-public-link  (Bab 8.8 — berbagi bukti, rumahnya di Bab 9.4)
// ============================================================
// Menerbitkan tautan yang dapat dibuka **tanpa login** oleh pusat resolusi
// marketplace.
//
// 🔴 Hanya Owner (Bab 2.2). Membagikan bukti keluar dari tenant adalah
//    keputusan pemilik usaha, bukan keputusan packer yang merekamnya.
//
// ⚠️ RLS TIDAK BERLAKU DI SINI (service role). Seluruh pemeriksaannya ditulis
//    ulang dengan tangan di bawah.
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

/// Basis alamat halaman publik. Disimpan sebagai env agar domainnya dapat
/// berganti tanpa merilis ulang aplikasi.
const BASE_URL = (Deno.env.get('PUBLIC_BASE_URL') ?? 'https://kamelscan.com')
  .replace(/\/+$/, '');

/// 32 karakter acak dari alfabet tanpa huruf yang mudah tertukar.
///
/// 🔴 Memakai `crypto.getRandomValues`, bukan `Math.random()`. Token ini adalah
/// satu-satunya penjaga video yang dapat dibuka tanpa login; angka acak yang
/// dapat ditebak berarti bukti pelanggan dapat dijelajahi orang luar.
///
/// 32 karakter dari alfabet 32 huruf = 160 bit. Menebaknya tidak mungkin
/// dilakukan dengan mencoba.
function generateToken(): string {
  const ALFABET = 'abcdefghjkmnpqrstuvwxyz23456789';
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => ALFABET[b % ALFABET.length]).join('');
}

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

  let body: { video_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const videoId = (body.video_id ?? '').trim();
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

  // Admin platform pun tidak boleh — sama seperti `get-video-url`, ia tidak
  // berhak menyebarkan isi video pelanggan (Bab 2.2 catatan 5).
  if (profile.role !== 'owner') return json({ error: 'OWNER_ONLY' }, 403);

  const { data: video } = await admin
    .from('package_videos')
    .select('id, tenant_id, status, expires_at, public_token, public_expires_at')
    .eq('id', videoId)
    .maybeSingle();

  if (!video) return json({ error: 'NOT_FOUND' }, 404);
  if (profile.tenant_id !== video.tenant_id) return json({ error: 'FORBIDDEN' }, 403);
  if (video.status !== 'uploaded') return json({ error: 'NOT_UPLOADED_YET' }, 409);

  // ---- Tautan yang masih berlaku dipakai ulang ----
  //
  // Menerbitkan token baru setiap kali tombolnya ditekan berarti tautan yang
  // sudah terkirim ke pusat resolusi marketplace mendadak mati — persis pada
  // saat sengketa sedang diperiksa. Idempoten di sini bukan kerapian, melainkan
  // syarat agar buktinya tetap dapat dibuka.
  const masihBerlaku = video.public_token &&
    video.public_expires_at &&
    new Date(video.public_expires_at) > new Date();

  if (masihBerlaku) {
    return json({
      public_url: `${BASE_URL}/v/${video.public_token}`,
      token: video.public_token,
      expires_at: video.public_expires_at,
      reused: true,
    });
  }

  // ---- Terbitkan token baru ----
  //
  // 🔴 Masa berlaku tautan mengikuti `expires_at` video, bukan umur tersendiri.
  // Tautan yang hidup lebih lama daripada berkasnya akan membuka halaman
  // kosong; yang lebih pendek memutus bukti sebelum waktunya.
  const token = generateToken();

  const { error: updateErr } = await admin
    .from('package_videos')
    .update({ public_token: token, public_expires_at: video.expires_at })
    .eq('id', videoId);

  if (updateErr) {
    // `23505` di sini berarti token acaknya bertabrakan — mustahil dalam
    // praktik pada 160 bit, tetapi tetap dilaporkan apa adanya alih-alih
    // dikembalikan sebagai sukses palsu.
    return json({ error: 'LINK_FAILED', detail: updateErr.message }, 500);
  }

  return json({
    public_url: `${BASE_URL}/v/${token}`,
    token,
    expires_at: video.expires_at,
    reused: false,
  });
});
