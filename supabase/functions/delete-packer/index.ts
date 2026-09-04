// ============================================================
// delete-packer  (Bab 6.7 / Bab 9.6)
// ============================================================
// Menghapus akun packer atas nama Owner — termasuk akun masuknya.
//
// 🔴 DIBUAT 20 AGUSTUS 2026 SETELAH CACAT SERIUS DITEMUKAN DI PERANGKAT.
//
//    Sebelumnya aplikasi menghapus packer langsung lewat PostgREST:
//        delete from public.users where id = ...
//
//    Itu hanya menghapus **profilnya**, bukan akun masuknya. `public.users.id`
//    menunjuk `auth.users(id) on delete cascade` — arahnya auth → public,
//    tidak pernah sebaliknya. Jadi barisnya hilang dari layar Owner sementara
//    akun masuknya tetap hidup di `auth.users`, dan akibatnya:
//
//      1. Orang yang "sudah dihapus" MASIH BISA MASUK dengan password lama.
//      2. Emailnya terkunci selamanya — membuat ulang packer dengan email yang
//         sama ditolak EMAIL_ALREADY_USED, padahal di layar ia tidak ada.
//      3. Begitu masuk, ia punya sesi tanpa profil. Setiap layar mencari baris
//         `users` yang tidak ada lagi dan berhenti di "Data tidak ditemukan"
//         tanpa jalan keluar — bahkan tombol keluar pun tidak terjangkau.
//
//    Poin 1 yang paling berat: Owner mengira ia sudah mencabut akses seorang
//    bekas pegawai, padahal belum sama sekali.
//
//    Menghapus `auth.users` menuntut service-role, dan service-role tidak
//    boleh ada di aplikasi (Bab 4.4) — karena itulah pekerjaannya pindah ke
//    sini.
//
// Alur:
//   1. Pastikan pemanggil Owner yang aktif
//   2. Pastikan sasarannya packer milik tenant yang sama
//   3. Tolak bila ia sudah pernah merekam
//   4. Hapus akunnya (profilnya ikut terhapus lewat cascade)
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

  const { data: profile } = await admin
    .from('users')
    .select('tenant_id, role, is_active')
    .eq('id', user.id)
    .single();

  if (!profile || profile.role !== 'owner' || profile.is_active !== true) {
    return json({ error: 'FORBIDDEN' }, 403);
  }

  let body: { user_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'INVALID_BODY' }, 400);
  }

  const targetId = (body.user_id ?? '').trim();
  if (!targetId) return json({ error: 'INVALID_BODY' }, 400);

  // Owner tidak dapat menghapus dirinya sendiri lewat jalur ini. Tanpa
  // penjagaan ini, satu ketukan keliru dapat menghapus satu-satunya akun yang
  // memegang tenant beserta seluruh isinya.
  if (targetId === user.id) return json({ error: 'CANNOT_DELETE_SELF' }, 400);

  // ---- 2. Sasaran harus packer milik tenant yang sama ----
  //
  // Dicocokkan dengan tenant_id pemanggil, bukan sekadar "ada". Tanpa itu
  // seorang Owner dapat menghapus packer milik tenant lain hanya dengan
  // menebak id-nya — service-role di sini mengabaikan seluruh RLS, jadi
  // pemeriksaannya harus ditulis tangan.
  const { data: target } = await admin
    .from('users')
    .select('id, tenant_id, role')
    .eq('id', targetId)
    .maybeSingle();

  if (!target || target.tenant_id !== profile.tenant_id) {
    return json({ error: 'NOT_FOUND' }, 404);
  }
  if (target.role !== 'packer') return json({ error: 'FORBIDDEN' }, 403);

  // ---- 3. Packer yang sudah merekam tidak boleh dihapus ----
  //
  // `package_videos.user_id` memakai `on delete restrict` (Bab 5.2), jadi
  // database akan menolaknya sendiri. Dihitung lebih dulu agar Owner menerima
  // penjelasan yang dapat ia pahami beserta jumlahnya, bukan kegagalan
  // beruntun dari lapisan auth.
  // 🔴 `status <> 'deleted'` — dihitung seperti yang DILIHAT Owner.
  //
  // Menghapus video di aplikasi adalah penghapusan lunak: barisnya tetap ada,
  // hanya statusnya berubah, dan setiap layar menyaringnya. Hitungan lama
  // memasukkan baris-baris itu, sehingga Owner yang sudah membersihkan video
  // seorang packer tetap ditolak dengan jumlah yang tidak dapat ia temukan di
  // layar mana pun — dan tidak dapat ia hapus lagi, karena menurut aplikasinya
  // memang sudah tidak ada.
  const { count } = await admin
    .from('package_videos')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', targetId)
    .neq('status', 'deleted');

  if ((count ?? 0) > 0) {
    return json({ error: 'PACKER_HAS_VIDEOS', video_count: count }, 409);
  }

  // ---- 3b. Musnahkan video yang sudah dihapus Owner ----
  //
  // ⚠️ Mengubah hitungan di atas saja JUSTRU MEMPERBURUK keadaan. Baris yang
  // berstatus `deleted` masih berdiri, dan `package_videos.user_id` adalah
  // `on delete restrict` — `deleteUser()` di bawah akan gagal dengan 23503,
  // dan penolakan yang jelas beserta jumlahnya berubah menjadi
  // `DELETE_FAILED` tanpa penjelasan.
  //
  // Kunci R2-nya diselamatkan ke `storage_purge_queue` di dalam RPC-nya,
  // sebelum barisnya hilang (migrasi 38). Tanpa itu berkasnya menjadi sampah
  // yang tidak dapat ditemukan siapa pun lagi, dan tetap ditagihkan.
  const { data: dimusnahkan, error: purgeErr } = await admin.rpc(
    'purge_packer_soft_deleted_videos',
    { p_user_id: targetId },
  );

  if (purgeErr) {
    console.error(
      `KAMELSCAN_PACKER gagal memusnahkan video · ${targetId} · ${purgeErr.message}`,
    );
    return json({ error: 'DELETE_FAILED', detail: purgeErr.message }, 400);
  }

  // ---- 4. Hapus akunnya ----
  //
  // Cukup `auth.users`; `public.users` ikut terhapus lewat cascade, begitu
  // pula penugasan tokonya. Urutan ini penting — menghapus profilnya lebih
  // dulu justru melahirkan kembali cacat yang sedang diperbaiki di sini.
  const { error: delErr } = await admin.auth.admin.deleteUser(targetId);
  if (delErr) {
    return json({ error: 'DELETE_FAILED', detail: delErr.message }, 400);
  }

  await admin.from('audit_logs').insert({
    tenant_id: profile.tenant_id,
    actor_id: user.id,
    action: 'packer.delete',
    entity: 'users',
    entity_id: targetId,
    metadata: { videos_purged: dimusnahkan ?? 0 },
  });

  return json({ deleted: true });
});
