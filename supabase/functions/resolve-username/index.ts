// ============================================================
// resolve-username  (Bab 6.6)
// ============================================================
// Supabase Auth hanya mengenal email. Fungsi ini menukar username menjadi
// email agar aplikasi dapat melanjutkan `signInWithPassword`.
//
// ⚠️ Bab 6.6: JANGAN mengekspos tabel `users` ke peran `anon` untuk keperluan
//    ini — itu membocorkan seluruh daftar email pelanggan. Fungsi ini memakai
//    service role di server dan hanya mengembalikan SATU email untuk satu
//    username yang cocok persis.
//
// Pembatasan penyalahgunaan:
//   - hanya menerima username yang lolos pola `^[a-z0-9._]{4,20}$`
//   - rate limit sederhana per alamat IP, disimpan di memori instans
//   - balasan seragam agar tidak bisa dipakai menebak username mana yang ada
//     (lihat catatan di bawah)
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

const USERNAME_RE = /^[a-z0-9._]{4,20}$/;

// Rate limit sederhana: 10 permintaan per menit per IP.
//
// ⚠️ Batas ini hanya berlaku di dalam satu instans Edge Function. Deno Deploy
// dapat menjalankan beberapa instans sekaligus, jadi ini memperlambat
// penyalahgunaan, bukan menghentikannya. Bila serangan penebakan username
// menjadi nyata, pindahkan penghitungnya ke tabel Postgres atau Redis.
const WINDOW_MS = 60_000;
const MAX_HITS = 10;
const hits = new Map<string, { count: number; resetAt: number }>();

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || now > entry.resetAt) {
    hits.set(ip, { count: 1, resetAt: now + WINDOW_MS });
    return false;
  }
  entry.count++;
  return entry.count > MAX_HITS;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  const ip = req.headers.get('x-forwarded-for')?.split(',')[0].trim() ?? 'unknown';
  if (rateLimited(ip)) return json({ error: 'RATE_LIMITED' }, 429);

  let body: { username?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const username = (body.username ?? '').trim().toLowerCase();
  if (!USERNAME_RE.test(username)) {
    // Sengaja memakai kode yang sama dengan "tidak ditemukan": bila format
    // salah dan tidak ditemukan bisa dibedakan, penyerang mendapat petunjuk
    // gratis tentang pola username yang dipakai.
    return json({ error: 'NOT_FOUND' }, 404);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data, error } = await admin
    .from('users')
    .select('email, is_active')
    .eq('username', username)
    .maybeSingle();

  if (error || !data) return json({ error: 'NOT_FOUND' }, 404);

  // Akun nonaktif diperlakukan seperti tidak ada, agar statusnya tidak bocor
  // ke pihak yang belum terautentikasi (Bab 6.9).
  if (data.is_active !== true) return json({ error: 'NOT_FOUND' }, 404);

  return json({ email: data.email });
});
