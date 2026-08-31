import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/failure_messages.dart';
import '../plan_view_model.dart';

/// Kolom kode promo (Bab 9.8).
///
/// Kode diketik huruf besar semua oleh formatter, bukan diserahkan ke pengguna:
/// kode promo dibagikan lewat gambar dan pesan singkat, dan orang mengetiknya
/// apa adanya. Menolak `hemat50` sementara `HEMAT50` diterima adalah penolakan
/// yang tidak dapat dipahami siapa pun.
class PromoField extends ConsumerStatefulWidget {
  const PromoField({super.key});

  @override
  ConsumerState<PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends ConsumerState<PromoField> {
  final _kode = TextEditingController();
  bool _sedangPeriksa = false;

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final data = ref.watch(planViewModelProvider).value;

    final terpakai = data?.promo;
    final ditolak = data?.promoRejectionKey;

    if (terpakai != null) {
      return Card(
        margin: EdgeInsets.zero,
        color: colors.success.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.local_offer_rounded, size: 18, color: colors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.promoApplied(terpakai.code),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () {
                  _kode.clear();
                  ref.read(planViewModelProvider.notifier).clearPromo();
                },
                child: Text(t.promoRemove),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _kode,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseFormatter()],
                decoration: InputDecoration(
                  labelText: t.promoLabel,
                  hintText: t.promoHint,
                  errorText: ditolak == null
                      ? null
                      : context.messageForKey(ditolak),
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 🔴 LEBARNYA WAJIB DIBATASI — bukan hanya tingginya.
            //
            // Jebakan M.12 terulang di sini pada 22 Agustus 2026, dan sempat
            // sampai ke perangkat: `filledButtonTheme` proyek ini memasang
            // `minimumSize: Size.fromHeight(...)`, yang berarti lebar minimum
            // **tak terhingga**. Di dalam `Row`, tombol semacam itu melahap
            // seluruh ruang dan membuat `Expanded` di sebelahnya tergencet
            // menjadi nol — yang terlihat di layar hanyalah ikon label dan
            // sepotong garis, tanpa kolom teks maupun tombol.
            //
            // Membungkusnya dengan `SizedBox(height: ...)` saja TIDAK cukup:
            // itu hanya mengurus tinggi, sementara yang merusak justru
            // lebarnya. `Expanded` di sini yang memberinya batas.
            //
            // Perbandingan 3:1 dipilih supaya kolom kodenya tetap lapang —
            // kode promo bisa panjang, dan kolom yang sempit membuat awalnya
            // tergulir keluar layar saat diketik.
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 58,
                child: FilledButton.tonal(
                  onPressed: _sedangPeriksa ? null : _terapkan,
                  child: _sedangPeriksa
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.promoApply),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _terapkan() async {
    setState(() => _sedangPeriksa = true);
    await ref.read(planViewModelProvider.notifier).applyPromo(_kode.text);
    if (mounted) setState(() => _sedangPeriksa = false);
  }
}

/// Mengubah ketikan menjadi huruf besar sambil mempertahankan posisi kursor.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => TextEditingValue(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
  );
}
