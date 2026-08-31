// ============================================================
// purge-storage  (Bab 9.6 + Bab 1.3 poin 4)
// ============================================================
// Menguras `storage_purge_queue`: menghapus objek dari Cloudflare R2, lalu
// menandai barisnya selesai.
//
// 🔴 SAMPAI FUNGSI INI ADA, TIDAK SATU PUN BERKAS DI R2 PERNAH TERHAPUS.
//    Comment migrasi 16 menjanjikan `purge-expired-videos` "yang dipanggil
//    setelahnya" — fungsi itu tidak pernah dibuat. Akibatnya berjalan diam-
//    diam sejak hari pertama: `mark-expired-videos` rajin menandai baris
//    `expired` setiap malam, dan videonya tetap utuh di R2, tetap ditagihkan
//    setiap bulan, selamanya.
//
//    Tidak ada satu pun galat yang muncul dari keadaan itu. Yang muncul hanya
//    tagihan yang naik pelan-pelan.
//
// 🔴 KENAPA ANTREAN, BUKAN "BACA TABEL VIDEO LALU HAPUS".
//    Menghapus akun menghapus baris `package_videos`-nya, dan `storage_key`
//    hilang bersama barisnya. Sesudah itu tidak ada seorang pun — tidak juga
//    Admin — yang dapat mengetahui berkas mana di R2 yang milik siapa. Kuncinya
//    karena itu disalin ke antrean SEBELUM barisnya dihapus (migrasi 37).
//
// ⚠️ Fungsi ini SENGAJA tidak menyentuh baris `package_videos` sama sekali. Ia
//    hanya tahu tentang kunci objek. Keputusan tentang nasib barisnya —
//    dibiarkan `expired` atau ditandai `deleted` — milik yang mengisi antrean,
//    bukan milik yang mengurasnya.
// ============================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { DeleteObjectsCommand, S3Client } from 'npm:@aws-sdk/client-s3@3';

const BUCKET = Deno.env.get('R2_BUCKET_VIDEOS') ?? 'kamelscan-videos';

/// R2 menerima paling banyak 1000 kunci per permintaan DeleteObjects.
const SEKALI_HAPUS = 1000;

/// Batas satu panggilan, supaya fungsinya tidak pernah menabrak batas waktu
/// Edge Function pada antrean yang menumpuk. Sisanya terangkut panggilan
/// berikutnya — antreannya memang dibuat untuk itu.
const MAKS_PER_PANGGILAN = 5000;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

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

  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // 🔴 `verify_jwt` saja TIDAK CUKUP di sini. Ia hanya memastikan pemanggilnya
  //    membawa JWT yang sah — dan JWT setiap Owner yang sedang login pun sah.
  //    Tanpa baris ini, siapa pun yang punya akun dapat memicu penghapusan
  //    berkas milik seluruh pelanggan.
  const auth = req.headers.get('Authorization') ?? '';
  if (!samaAman(auth, `Bearer ${serviceKey}`)) {
    return json({ error: 'FORBIDDEN' }, 403);
  }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, serviceKey);

  const { data: antrean, error: bacaErr } = await admin
    .from('storage_purge_queue')
    .select('id, storage_key')
    .is('purged_at', null)
    .order('queued_at', { ascending: true })
    .limit(MAKS_PER_PANGGILAN);

  if (bacaErr) {
    console.error(`KAMELSCAN_PURGE gagal membaca antrean · ${bacaErr.message}`);
    return json({ error: 'QUEUE_READ_FAILED' }, 500);
  }

  if (!antrean || antrean.length === 0) {
    return json({ ok: true, dihapus: 0, gagal: 0, note: 'antrean kosong' });
  }

  const r2 = new S3Client({
    region: 'auto',
    endpoint: Deno.env.get('R2_ENDPOINT')!,
    credentials: {
      accessKeyId: Deno.env.get('R2_ACCESS_KEY_ID')!,
      secretAccessKey: Deno.env.get('R2_SECRET_ACCESS_KEY')!,
    },
  });

  const idOleh = new Map<string, string>();
  for (const baris of antrean) idOleh.set(baris.storage_key, baris.id);

  let dihapus = 0;
  let gagal = 0;

  for (let i = 0; i < antrean.length; i += SEKALI_HAPUS) {
    const bagian = antrean.slice(i, i + SEKALI_HAPUS);

    let berhasil: string[] = [];
    const salah = new Map<string, string>();

    try {
      const jawab = await r2.send(
        new DeleteObjectsCommand({
          Bucket: BUCKET,
          Delete: {
            Objects: bagian.map((b) => ({ Key: b.storage_key })),
            // Hanya galat yang dikembalikan; daftar berhasilnya disusun sendiri
            // di bawah dari selisihnya.
            Quiet: true,
          },
        }),
      );

      for (const e of jawab.Errors ?? []) {
        if (e.Key) salah.set(e.Key, `${e.Code}: ${e.Message}`);
      }

      // ⚠️ Kunci yang TIDAK ADA di R2 dihitung berhasil, dan itu disengaja.
      // DeleteObjects memang menjawab sukses untuk kunci yang tidak ada, dan
      // itulah jawaban yang benar: yang diminta adalah "pastikan berkas ini
      // tidak ada lagi". Berkas yang sudah hilang sudah memenuhi permintaan
      // itu. Memperlakukannya sebagai kegagalan hanya membuat barisnya
      // dicoba ulang setiap malam, selamanya.
      berhasil = bagian
        .map((b) => b.storage_key)
        .filter((k) => !salah.has(k));
    } catch (e) {
      // Seluruh bagian gagal — biasanya jaringan atau kredensial R2. Barisnya
      // dibiarkan di antrean; panggilan berikutnya akan mencobanya lagi.
      const pesan = e instanceof Error ? e.message : String(e);
      console.error(`KAMELSCAN_PURGE bagian gagal seluruhnya · ${pesan}`);
      for (const b of bagian) salah.set(b.storage_key, pesan);
    }

    if (berhasil.length > 0) {
      const ids = berhasil.map((k) => idOleh.get(k)!).filter(Boolean);
      const { error: tandaErr } = await admin
        .from('storage_purge_queue')
        .update({ purged_at: new Date().toISOString() })
        .in('id', ids);

      if (tandaErr) {
        // 🔴 Berkasnya sudah hilang tetapi barisnya tidak tertandai. Panggilan
        //    berikutnya akan mencoba menghapus kunci yang sudah tidak ada —
        //    dan berhasil, karena itulah jawaban R2 untuk kunci yang hilang.
        //    Jadi keadaan ini pulih sendiri, dan tidak boleh menggagalkan
        //    sisanya.
        console.error(`KAMELSCAN_PURGE gagal menandai · ${tandaErr.message}`);
      } else {
        dihapus += berhasil.length;
      }
    }

    for (const [kunci, pesan] of salah) {
      gagal++;
      const id = idOleh.get(kunci);
      if (!id) continue;
      await admin.rpc('bump_purge_attempt', {
        p_id: id,
        p_error: pesan.slice(0, 500),
      });
    }
  }

  console.log(`KAMELSCAN_PURGE selesai · dihapus=${dihapus} gagal=${gagal}`);
  return json({ ok: true, dihapus, gagal, diperiksa: antrean.length });
});
