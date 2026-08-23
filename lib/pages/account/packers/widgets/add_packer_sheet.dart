import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/shop.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/failure_messages.dart';

/// Hasil formulir tambah packer.
class AddPackerResult {
  const AddPackerResult({
    required this.fullName,
    required this.email,
    required this.shopIds,
  });

  final String fullName;
  final String email;
  final List<String> shopIds;
}

/// Formulir **+ Tambah Packer** (Bab 9.6).
///
/// Password tidak diisi Owner: Edge Function `create-packer` yang
/// membangkitkannya, lalu mengembalikannya sekali untuk ditampilkan
/// (Bab 6.7). Owner yang mengarang password sendiri cenderung memakai yang
/// sama untuk semua packer.
class AddPackerSheet extends ConsumerStatefulWidget {
  const AddPackerSheet({super.key});

  @override
  ConsumerState<AddPackerSheet> createState() => _AddPackerSheetState();
}

class _AddPackerSheetState extends ConsumerState<AddPackerSheet> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _terpilih = <String>{};

  String? _salahNama;
  String? _salahEmail;

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final tokoAsync = ref.watch(shopListProvider);

    return Padding(
      // Menyisakan ruang untuk papan ketik — tanpa ini kolom email tertutup
      // saat diketik.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.packersAdd, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t.accountFieldName,
                errorText: _salahNama == null
                    ? null
                    : context.messageForKey(_salahNama!),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              onChanged: (_) => setState(() => _salahNama = null),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: t.authEmail,
                helperText: t.packersEmailHelp,
                helperMaxLines: 2,
                errorText: _salahEmail == null
                    ? null
                    : context.messageForKey(_salahEmail!),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              onChanged: (_) => setState(() => _salahEmail = null),
            ),
            const SizedBox(height: 18),

            Text(t.packersAssignShops, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              t.packersAssignShopsHelp,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),

            switch (tokoAsync) {
              AsyncValue(:final value?) when value.isEmpty => Text(
                  t.recordNoShopBody,
                  style: theme.textTheme.bodySmall,
                ),
              AsyncValue(:final value?) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final Shop toko in value)
                      FilterChip(
                        label: Text(toko.shopName),
                        selected: _terpilih.contains(toko.id),
                        onSelected: (pilih) => setState(() {
                          if (pilih) {
                            _terpilih.add(toko.id);
                          } else {
                            _terpilih.remove(toko.id);
                          }
                        }),
                      ),
                  ],
                ),
              _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
            },

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _kirim,
                child: Text(t.packersCreate),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _kirim() {
    final nama = _nama.text.trim();
    final email = _email.text.trim();

    // Divalidasi dengan aturan yang sama seperti pendaftaran, supaya tidak ada
    // dua definisi "email yang sah" di aplikasi ini.
    final salahNama = Validators.fullName(nama);
    final salahEmail = Validators.email(email);

    if (salahNama != null || salahEmail != null) {
      setState(() {
        _salahNama = salahNama;
        _salahEmail = salahEmail;
      });
      return;
    }

    Navigator.pop(
      context,
      AddPackerResult(
        fullName: nama,
        email: email,
        shopIds: _terpilih.toList(growable: false),
      ),
    );
  }
}

/// Daftar toko aktif untuk penugasan packer.
final shopListProvider = FutureProvider.autoDispose<List<Shop>>((ref) async {
  final result =
      await ref.read(shopRepositoryProvider).fetchShops(activeOnly: true);
  return result.getOrElse((_) => const []);
});
