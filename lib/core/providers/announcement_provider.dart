import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/announcement.dart';
import 'repository_providers.dart';
import 'session_provider.dart';

part 'announcement_provider.g.dart';

/// Pengumuman yang harus dilihat pengguna yang sedang masuk (migrasi 50).
///
/// 🔴 **Kegagalan menjawab daftar kosong, bukan melempar.** Ini keputusan yang
/// paling menentukan di berkas ini.
///
/// Pengumuman adalah lapisan tambahan di atas aplikasi, bukan bagian dari
/// pekerjaan yang sedang dilakukan orang. Aplikasi ini dipakai packer di gudang
/// bersinyal buruk (Bab 8.7); kalau kueri ini gagal dan kegagalannya
/// dinaikkan, Beranda akan menampilkan layar galat untuk sesuatu yang tidak
/// dicari siapa pun — dan seorang packer yang tidak dapat merekam karena iklan
/// gagal dimuat adalah kerusakan yang jauh lebih besar daripada iklan yang
/// tidak tampil.
///
/// ⚠️ Konsekuensinya nyata dan harus disadari: perangkat yang tidak dapat
/// menghubungi server **tidak akan pernah** melihat layar "wajib update". Itu
/// memang tidak dapat dihindari — perangkat yang sama juga tidak dapat memakai
/// aplikasinya sama sekali tanpa server, jadi tidak ada yang lolos memakai
/// versi lama diam-diam.
@riverpod
Future<List<Announcement>> activeAnnouncements(Ref ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const <Announcement>[];

  final hasil = await ref.read(announcementRepositoryProvider).fetchFor(
        role: session.role,
        userId: session.user.id,
      );

  if (hasil.isErr) {
    debugPrint('KAMELSCAN_IKLAN gagal dibaca · ${hasil.failureOrNull} '
        '— diabaikan, aplikasi jalan terus');
    return const <Announcement>[];
  }

  final daftar = hasil.valueOrNull ?? const <Announcement>[];
  debugPrint('KAMELSCAN_IKLAN ${daftar.length} pengumuman untuk '
      '${session.role.wire}');
  return daftar;
}
