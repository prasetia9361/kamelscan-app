// ============================================================
// create-packer  (Bab 6.7)
// ============================================================
// Membuat akun packer atas nama Owner.
//
// 🔴 SUPABASE_SERVICE_ROLE_KEY hanya boleh hidup di sini (Bab 4.4). Kunci ini
//    mengabaikan seluruh RLS — jangan pernah masuk ke aplikasi Flutter.
//
// Alur:
//   1. Pastikan pemanggil punya sesi valid
//   2. Pastikan perannya `owner` dan tenant-nya masih boleh beroperasi
//   3. Cek batas packer sesuai tier (trigger juga mengecek; ini agar pesannya ramah)
//   4. Buat akun dengan email_confirm=true + password sementara
//   5. Tugaskan ke toko yang dipilih
//   6. Kembalikan password sementara SEKALI SAJA
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

/// Password sementara: 12 karakter, tanpa karakter yang mudah tertukar
/// (0/O, 1/l/I). Packer akan mengetiknya manual dari layar Owner.
function generateTempPassword(): string {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  let out = '';
  for (const b of bytes) out += alphabet[b % alphabet.length];
  // Jamin ada huruf dan angka agar lolos aturan password aplikasi.
  return out.slice(0, 10) + '7a';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

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

  // ---- 2. Harus Owner, dan tenant-nya masih hidup ----
  const { data: profile } = await admin
    .from('users')
    .select('tenant_id, role, is_active')
    .eq('id', user.id)
    .single();

  if (!profile || profile.role !== 'owner' || profile.is_active !== true) {
    return json({ error: 'FORBIDDEN' }, 403);
  }

  const { data: tenant } = await admin
    .from('tenants')
    .select('status, tier_plan')
    .eq('id', profile.tenant_id)
    .single();

  // Bab 7.6 — tenant kedaluwarsa/ditangguhkan tidak boleh menambah packer.
  if (!tenant || !['trial', 'active'].includes(tenant.status)) {
    return json({ error: 'SUBSCRIPTION_INACTIVE' }, 403);
  }

  let body: {
    email?: string;
    full_name?: string;
    phone?: string;
    shop_ids?: string[];
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const email = (body.email ?? '').trim().toLowerCase();
  const fullName = (body.full_name ?? '').trim();
  if (!email || !email.includes('@')) return json({ error: 'INVALID_EMAIL' }, 400);
  if (fullName.length < 3) return json({ error: 'INVALID_NAME' }, 400);

  // ---- 3. Batas packer sesuai tier (Bab 7.4) ----
  const { data: pricing } = await admin
    .from('platform_settings')
    .select('value')
    .eq('key', 'pricing')
    .single();

  const maxPackers: number = pricing?.value?.[tenant.tier_plan]?.max_packers ?? 5;
  if (maxPackers !== -1) {
    const { count } = await admin
      .from('users')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', profile.tenant_id)
      .eq('role', 'packer')
      .eq('is_active', true);

    if ((count ?? 0) >= maxPackers) {
      return json(
        { error: 'PACKER_LIMIT_REACHED', max: maxPackers, current: count },
        409,
      );
    }
  }

  // ---- 4. Buat akun ----
  const tempPassword = generateTempPassword();
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password: tempPassword,
    email_confirm: true, // packer tidak melalui verifikasi email
    user_metadata: {
      role: 'packer',
      tenant_id: profile.tenant_id,
      full_name: fullName,
      phone: body.phone ?? null,
      created_by: user.id,
      must_change_password: true, // Bab 6.7
    },
  });

  if (createErr || !created?.user) {
    const msg = createErr?.message ?? 'CREATE_FAILED';
    // Pesan Supabase dipetakan ke kode yang dikenali aplikasi, bukan diteruskan
    // mentah-mentah ke pengguna (Bab 9.10).
    const code = /already been registered|already exists/i.test(msg)
      ? 'EMAIL_ALREADY_USED'
      : /packer_limit/i.test(msg)
      ? 'PACKER_LIMIT_REACHED'
      : 'CREATE_FAILED';
    return json({ error: code, detail: msg }, 400);
  }

  // ---- 5. Penugasan toko ----
  const shopIds = Array.isArray(body.shop_ids) ? body.shop_ids : [];
  if (shopIds.length > 0) {
    // Hanya toko milik tenant ini yang boleh ditugaskan.
    const { data: ownShops } = await admin
      .from('shops')
      .select('id')
      .eq('tenant_id', profile.tenant_id)
      .in('id', shopIds);

    const valid = (ownShops ?? []).map((s: { id: string }) => s.id);
    if (valid.length > 0) {
      await admin.from('shop_packers').insert(
        valid.map((shopId: string) => ({
          shop_id: shopId,
          user_id: created.user!.id,
          tenant_id: profile.tenant_id,
        })),
      );
    }
  }

  await admin.from('audit_logs').insert({
    tenant_id: profile.tenant_id,
    actor_id: user.id,
    action: 'packer.create',
    entity: 'users',
    entity_id: created.user.id,
    metadata: { shop_ids: shopIds },
  });

  // ---- 6. Password sementara dikembalikan SEKALI ----
  return json({
    user_id: created.user.id,
    email,
    temp_password: tempPassword,
  });
});
