import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hapus video — sungguh-sungguh, bukan soft delete (Bab 7.7, migrasi 48).
///
/// 🔴 Keputusan Product Owner 4 September 2026: *"soft delete itu racun yang
/// membunuh tanpa sadar"*.
///
/// Racunnya nyata dan dapat disebut angkanya. Bentuk lamanya hanya menyetel
/// `status = 'deleted'`; berkas R2-nya tidak pernah disentuh dan tidak pernah
/// masuk `storage_purge_queue`. Ketiga pengisi antrean — retensi (41),
/// hapus akun (37), packer (38) — semuanya melewatkan jalur itu.
///
/// Akibatnya dua, dan yang kedua lebih buruk daripada yang pertama:
/// berkasnya ditagihkan selamanya, dan Owner yang menekan Hapus percaya
/// videonya hilang padahal masih utuh.
///
/// ⚠️ Tes ini membaca berkas, tidak menjalankan SQL. Batasnya jujur: ia
/// menjaga BENTUK dan URUTAN yang membuat penghapusan itu aman, bukan
/// membuktikan Postgres menerimanya. Yang membuktikan itu hanya menjalankan
/// migrasinya — dan langkahnya ada di kaki berkas migrasi.
void main() {
  late String migrasi;
  late String repo;

  setUpAll(() {
    migrasi =
        File('supabase/migrations/48_hard_delete_video.sql').readAsStringSync();
    repo = File('lib/core/repositories/video_repository.dart').readAsStringSync();
  });

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    expect(migrasi.length, greaterThan(1500));
    expect(repo.length, greaterThan(1000));
  });

  // ==========================================================================
  // 🔴 Urutan yang tidak boleh dibalik
  // ==========================================================================
  //
  // `storage_key` hanya hidup di baris `package_videos`. Menghapus barisnya
  // lebih dulu membuang satu-satunya petunjuk ke berkasnya — dan berkas yang
  // tidak diketahui namanya tidak dapat dihapus siapa pun, selamanya.
  //
  // Ini satu-satunya kegagalan di sini yang TIDAK dapat diperbaiki belakangan.
  group('🔴 antrekan dulu, hapus kemudian', () {
    test('insert ke antrean mendahului delete di dalam fungsinya', () {
      final badan = migrasi.substring(
        migrasi.indexOf('create or replace function public.delete_video_hard'),
      );
      final akhirFungsi = badan.indexOf(r'$$;');
      expect(akhirFungsi, greaterThan(0), reason: 'badan fungsi tidak ketemu');

      final isi = badan.substring(0, akhirFungsi);
      final posInsert = isi.indexOf('insert into public.storage_purge_queue');
      final posDelete = isi.indexOf('delete from public.package_videos');

      expect(posInsert, greaterThan(0), reason: 'tidak mengantrekan kunci R2');
      expect(posDelete, greaterThan(0), reason: 'tidak menghapus barisnya');
      expect(
        posInsert,
        lessThan(posDelete),
        reason: 'DELETE mendahului INSERT — berkas R2 akan yatim selamanya '
            'karena storage_key sudah ikut terhapus',
      );
    });

    test('pembersihan sekali pakai memakai urutan yang sama', () {
      final ekor = migrasi.substring(migrasi.indexOf(r'$$;'));
      final posInsert = ekor.indexOf('insert into public.storage_purge_queue');
      final posDelete =
          ekor.indexOf("delete from public.package_videos where status = 'deleted'");

      expect(posInsert, greaterThan(0));
      expect(posDelete, greaterThan(posInsert),
          reason: 'baris lama akan yatim dengan urutan terbalik');
    });

    test('kedua kunci ikut diantrekan, bukan hanya videonya', () {
      // Thumbnail juga berkas, juga ditagihkan.
      expect(migrasi, contains('thumbnail_key'));
    });
  });

  // ==========================================================================
  // 🔴 Kepemilikan diperiksa — security definer melewati RLS
  // ==========================================================================
  group('🔴 tidak boleh menghapus video tenant lain', () {
    test('fungsinya membandingkan tenant dengan current_tenant_id()', () {
      expect(migrasi, contains('security definer'));
      expect(
        migrasi,
        contains('public.current_tenant_id()'),
        reason: 'security definer melewati RLS — tanpa pemeriksaan ini siapa '
            'pun dapat menghapus video tenant mana pun dengan menebak UUID',
      );
      expect(migrasi, contains('raise exception'));
    });

    test('search_path dipatok', () {
      // Fungsi security definer ber-search_path longgar dapat dibajak lewat
      // fungsi bernama sama di schema lain.
      expect(migrasi, contains('set search_path = public'));
    });

    test('hak panggilnya dibatasi ke pengguna yang masuk', () {
      expect(migrasi, contains('revoke all on function'));
      expect(migrasi, contains('grant execute on function'));
      expect(migrasi, contains('to authenticated'));
    });
  });

  // ==========================================================================
  // Sisi aplikasi
  // ==========================================================================
  group('🔴 aplikasi tidak boleh kembali menyetel status', () {
    test('deleteVideo memanggil RPC, bukan update status', () {
      final i = repo.indexOf('Future<Result<void>> deleteVideo(');
      expect(i, greaterThan(0));
      // ⚠️ Dijepit ke panjang berkas. `deleteVideo` adalah metode
      // TERAKHIR di kelasnya, jadi jendela tetap 700 huruf melewati
      // ujung berkas dan melempar RangeError — kegagalan tes yang tidak
      // ada hubungannya dengan yang sedang diuji.
      final badan = repo.substring(i, (i + 700).clamp(i, repo.length));

      expect(badan, contains('delete_video_hard'),
          reason: 'deleteVideo wajib lewat RPC migrasi 48');
      expect(
        badan,
        isNot(contains('VideoStatus.deleted')),
        reason: 'soft delete sudah kembali — berkas R2 akan yatim lagi',
      );
    });

    test('penyaring status deleted tetap ada untuk baris lama', () {
      // ⚠️ Sengaja TIDAK dibuang. Migrasi 48 membersihkan baris lama, tetapi
      // basis data yang belum menjalankannya masih memuatnya — dan aplikasi
      // yang lebih baru daripada databasenya adalah keadaan yang normal.
      expect(repo, contains("neq('status', VideoStatus.deleted.wire)"));
    });
  });

  // ==========================================================================
  // Retensi sengaja berbeda
  // ==========================================================================
  test('⚠️ migrasi 48 tidak menyentuh fungsi harian retensi', () {
    // Video yang dihapus Owner: ia tahu ia menghapusnya, barisnya boleh lenyap.
    //
    // Video yang lewat retensi: Owner tidak melakukan apa-apa. Barisnya yang
    // ikut lenyap membuat Riwayat menyusut sendiri tanpa penjelasan, dan itu
    // terbaca persis seperti data yang hilang. Status `expired` adalah
    // penjelasannya; berkasnya tetap dibuang lewat antrean.
    // Menyebutnya di komentar justru benar — pembaca harus tahu kenapa
    // retensi diperlakukan berbeda. Yang dilarang adalah MENDEFINISIKAN
    // ULANG fungsinya di berkas ini.
    expect(
      migrasi,
      isNot(contains(
        'create or replace function public.expire_videos_and_queue_storage',
      )),
      reason: 'fungsi retensi harian tidak boleh ikut ditulis ulang di sini',
    );
    expect(
      migrasi,
      contains('expire_videos_and_queue_storage'),
      reason: 'alasan retensi diperlakukan berbeda wajib tertulis',
    );
  });

  test('🔴 migrasi 48 menyebut ketergantungannya pada migrasi 47', () {
    // Antrean tanpa penguras hanya menumpuk. Migrasi 48 yang dijalankan
    // sendirian membuat penghapusannya terlihat selesai padahal berkasnya
    // masih utuh — persis bentuk kegagalan yang ia datang untuk memperbaiki.
    expect(migrasi, contains('drain_purge_queue'));
    expect(migrasi.toUpperCase(), contains('MIGRASI 47'));
  });
}
