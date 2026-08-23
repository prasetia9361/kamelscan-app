import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pipeline_providers.dart';
import '../../../core/providers/upload_queue_provider.dart';
import '../../../core/widgets/failure_messages.dart';

/// Sakelar **"Unggah lewat data seluler"** (Bab 8.7 langkah 1 / Bab 9.7).
///
/// Sempat menumpang di halaman Akun sejak 17 Agustus 2026, karena tanpa layar
/// untuk menyalakannya nilainya terkunci mati dan antrian unggah tidak pernah
/// dapat diuji di perangkat yang hanya punya sinyal seluler — enam video
/// menumpuk tanpa ada cara mengeluarkannya (L.7).
///
/// **Dipindahkan ke Pengaturan 19 Agustus 2026**, rumahnya menurut Bab 9.7.
/// Nilainya ada di `SharedPreferences`, jadi kepindahan ini tidak
/// menghilangkan pilihan yang sudah dibuat pengguna.
///
/// 🔴 Disimpan di perangkat, **bukan** di `user_settings`. Keputusan Product
/// Owner 17 Agustus 2026: ini preferensi milik satu HP, dan packer berkuota
/// terbatas tidak seharusnya terikat pilihan packer yang memakai HP kantor.
class CellularUploadSwitch extends ConsumerWidget {
  const CellularUploadSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final enabled = ref.watch(uploadOnCellularProvider);
    final pending = ref.watch(pendingUploadCountProvider).value ?? 0;

    // Selagi nilainya dibaca dari penyimpanan, sakelar ditampilkan mati dan
    // tidak dapat ditekan. Menebak "hidup" di sini akan membuat sakelar melompat
    // sendiri sepersekian detik kemudian.
    final value = enabled.value ?? false;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            value: value,
            onChanged: enabled.isLoading
                ? null
                : (next) =>
                    ref.read(uploadOnCellularProvider.notifier).set(next),
            secondary: const Icon(Icons.signal_cellular_alt_rounded),
            title: Text(t.accountUploadCellularTitle),
            subtitle: Text(t.accountUploadCellularBody),
            isThreeLine: true,
            // Bab 9.10 — target sentuh besar; dipakai dengan sarung tangan.
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          ),
          // Angka inilah yang menjawab pertanyaan sebenarnya: *"kalau saya
          // nyalakan, apa yang akan terkirim?"* Tanpa ini sakelar terasa seperti
          // tidak melakukan apa-apa, karena unggahannya berjalan di latar.
          if (!value && pending > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_queue_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.accountUploadCellularWaiting(pending),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
