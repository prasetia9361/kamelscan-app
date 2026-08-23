import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/shop.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../history/widgets/marketplace_badge.dart';
import 'shop_form_view_model.dart';

/// Tambah / ubah toko (Bab 9.5 — Owner saja).
class ShopFormPage extends ConsumerStatefulWidget {
  const ShopFormPage({super.key, this.shopId = ''});

  /// Kosong berarti menambah toko baru.
  final String shopId;

  @override
  ConsumerState<ShopFormPage> createState() => _ShopFormPageState();
}

class _ShopFormPageState extends ConsumerState<ShopFormPage> {
  final TextEditingController _nama = TextEditingController();
  bool _namaTerisi = false;

  ShopFormViewModel get _vm =>
      ref.read(shopFormViewModelProvider(widget.shopId).notifier);

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(shopFormViewModelProvider(widget.shopId));
    final baru = widget.shopId.isEmpty;

    // Isi awal hanya disalin sekali. Menyalinnya tiap build akan memindahkan
    // kursor ke awal setiap kali Owner mengetik satu huruf.
    final data = async.value;
    if (data != null && !_namaTerisi) {
      _nama.text = data.shopName;
      _namaTerisi = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(baru ? t.shopFormAddTitle : t.shopFormEditTitle)),
      body: switch (async) {
        AsyncValue(:final value?) => _Form(
            data: value,
            controller: _nama,
            showActive: !baru,
            onMarket: _vm.setMarket,
            onName: _vm.setName,
            onActive: _vm.setActive,
            onSave: _simpan,
          ),
        AsyncError(:final error) => AppErrorView(
            failure: error,
            onRetry: () =>
                ref.invalidate(shopFormViewModelProvider(widget.shopId)),
          ),
        _ => const AppListSkeleton(itemCount: 3),
      },
    );
  }

  Future<void> _simpan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final failure = await _vm.save();
    if (!mounted) return;

    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            // `uq_shop_per_tenant` — marketplace + nama toko yang sama sudah
            // ada. Kalimatnya menyebut sebabnya, bukan kode errornya.
            failure.code == '23505'
                ? t.shopFormDuplicate
                : context.failureMessage(failure),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(t.shopFormSaved)));
    navigator.pop();
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.data,
    required this.controller,
    required this.showActive,
    required this.onMarket,
    required this.onName,
    required this.onActive,
    required this.onSave,
  });

  final ShopFormData data;
  final TextEditingController controller;

  /// Sakelar aktif hanya masuk akal pada toko yang sudah ada — toko baru selalu
  /// dibuat aktif.
  final bool showActive;

  final ValueChanged<String> onMarket;
  final ValueChanged<String> onName;
  final ValueChanged<bool> onActive;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.shopFormMarket, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              // Marketplace disimpan sebagai teks bebas di database (Bab 5.2)
              // supaya marketplace baru tidak menuntut migrasi. Daftar ini
              // hanya bantuan pengisian.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final nama in MarketNames.all)
                    ChoiceChip(
                      avatar: MarketplaceBadge(marketName: nama, size: 22),
                      label: Text(nama),
                      selected: data.marketName == nama,
                      onSelected: (_) => onMarket(nama),
                    ),
                ],
              ),

              const SizedBox(height: 24),
              Text(t.shopFormName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                onChanged: onName,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: InputDecoration(
                  hintText: t.shopFormNameHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
              ),

              if (showActive) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: data.isActive,
                  onChanged: onActive,
                  title: Text(t.shopFormActive),
                  subtitle: Text(t.shopFormActiveBody),
                ),
              ],

              const SizedBox(height: 16),
              // Pratinjau bentuk akhirnya — nama inilah yang nanti terbakar ke
              // watermark video (Bab 8.5), jadi Owner sebaiknya melihat
              // hasilnya sebelum menyimpan.
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      MarketplaceBadge(marketName: data.marketName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.shopFormPreview,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.shopName.trim().isEmpty
                                  ? data.marketName
                                  : '${data.marketName} · ${data.shopName.trim()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.resiInline.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: data.canSave ? onSave : null,
                child: data.saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(t.commonSave),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
