import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/tutorial.dart';
import '../../core/providers/repository_providers.dart';

part 'tutorial_view_model.g.dart';

/// Daftar tutorial yang berlaku pada rangka yang sedang berjalan (Bab 9.9).
///
/// 🔴 Rangkanya diterima sebagai **parameter `isWeb`**, bukan dibaca dari
/// `kIsWeb` di dalam sini. `kIsWeb` konstanta waktu kompilasi dan selalu
/// `false` pada `flutter test`, sehingga cabang webnya tidak akan pernah
/// dijalankan satu kali pun oleh tes mana pun (O.14, aturan 6 prompt serah
/// terima). Penyaringan `platform` adalah aturan yang justru paling perlu
/// diuji pada kedua nilainya.
@riverpod
Future<List<Tutorial>> tutorialList(Ref ref, {required bool isWeb}) async {
  debugPrint('KAMELSCAN_TUTORIAL minta daftar (isWeb=$isWeb)');

  final hasil = await ref.read(tutorialRepositoryProvider).fetchActive();

  debugPrint(
    'KAMELSCAN_TUTORIAL daftar '
    '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} langkah' : 'GAGAL · ${hasil.failureOrNull}'}',
  );

  final semua = hasil.unwrap();
  return List.unmodifiable(
    semua.where((t) => t.berlakuDi(isWeb: isWeb)),
  );
}
