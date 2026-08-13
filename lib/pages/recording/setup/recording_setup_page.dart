import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/shop.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import 'recording_setup_view_model.dart';

/// Layar setup perekaman (Bab 8.2).
///
/// Tiga pilihan: kamera, mode pemicu, toko. Tombol Mulai aktif hanya bila
/// ketiganya terisi **dan** saldo token > 0.
class RecordingSetupPage extends ConsumerWidget {
  const RecordingSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(recordingSetupViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.recordSetupTitle)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () => ref.invalidate(recordingSetupViewModelProvider),
        ),
        data: (data) => _SetupBody(data: data),
      ),
    );
  }
}

class _SetupBody extends ConsumerWidget {
  const _SetupBody({required this.data});

  final RecordingSetupData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final vm = ref.read(recordingSetupViewModelProvider.notifier);
    final setup = data.setup;

    // Tanpa toko sama sekali, tidak ada yang bisa dipilih. Menampilkan daftar
    // kosong lalu tombol mati akan membuat pengguna menebak-nebak.
    if (data.shops.isEmpty) {
      return AppEmptyState(
        icon: Icons.storefront_outlined,
        title: t.recordNoShopTitle,
        message: t.recordNoShopBody,
        actionLabel: t.recordNoShopAction,
        onAction: () => context.push(Routes.shopForm),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              _Section(
                number: 1,
                title: t.recordPickCamera,
                child: _CameraPicker(
                  cameras: data.cameras,
                  selected: setup.cameraId,
                  onSelect: vm.selectCamera,
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                number: 2,
                title: t.recordPickTrigger,
                child: _TriggerPicker(
                  selected: setup.triggerMode,
                  onSelect: vm.selectTriggerMode,
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                number: 3,
                title: t.recordPickShop,
                child: _ShopPicker(
                  shops: data.shops,
                  selected: setup.shopId,
                  onSelect: vm.selectShop,
                ),
              ),
            ],
          ),
        ),
        _StartBar(setup: setup),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '$number',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CameraPicker extends StatelessWidget {
  const _CameraPicker({
    required this.cameras,
    required this.selected,
    required this.onSelect,
  });

  final List<CameraDescription> cameras;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    if (cameras.isEmpty) {
      return _Notice(icon: Icons.no_photography_outlined, text: t.recordNoCamera);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cam in cameras)
          ChoiceChip(
            label: Text(_label(context, cam)),
            selected: selected == cam.name,
            onSelected: (_) => onSelect(cam.name),
          ),
      ],
    );
  }

  String _label(BuildContext context, CameraDescription cam) {
    final t = context.l10n;
    return switch (cam.lensDirection) {
      CameraLensDirection.back => t.cameraBack,
      CameraLensDirection.front => t.cameraFront,
      CameraLensDirection.external => t.cameraExternal,
    };
  }
}

class _TriggerPicker extends StatelessWidget {
  const _TriggerPicker({required this.selected, required this.onSelect});

  final TriggerMode? selected;
  final ValueChanged<TriggerMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Column(
      children: [
        for (final mode in TriggerMode.values)
          _TriggerTile(
            mode: mode,
            selected: selected == mode,
            onTap: () => onSelect(mode),
          ),
        // Bab 8.2 — scanner Bluetooth ditampilkan nonaktif dengan label
        // "Segera hadir", supaya pengguna tahu itu direncanakan dan tidak
        // mengira aplikasinya tidak mendukung.
        Opacity(
          opacity: 0.5,
          child: ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(t.triggerBluetooth),
            subtitle: Text(t.commonComingSoon),
            enabled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _TriggerTile extends StatelessWidget {
  const _TriggerTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TriggerMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, String title, String subtitle) = switch (mode) {
      TriggerMode.qrCode => (Icons.qr_code_2, t.triggerQr, t.triggerQrHint),
      TriggerMode.barcode1d => (Icons.barcode_reader, t.triggerBarcode, t.triggerBarcodeHint),
      TriggerMode.manual => (Icons.keyboard_alt_outlined, t.triggerManual, t.triggerManualHint),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
      ),
    );
  }
}

class _ShopPicker extends StatelessWidget {
  const _ShopPicker({
    required this.shops,
    required this.selected,
    required this.onSelect,
  });

  final List<Shop> shops;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final shop in shops)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: selected == shop.id
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(shop.shopName),
              subtitle: Text(shop.marketName),
              trailing:
                  selected == shop.id ? const Icon(Icons.check_circle) : null,
              onTap: () => onSelect(shop.id),
            ),
          ),
      ],
    );
  }
}

/// Tombol Mulai beserta alasannya bila masih mati.
///
/// Bab 9.10 melarang tombol abu-abu tanpa penjelasan — pengguna harus tahu apa
/// yang kurang, bukan menebak.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.setup});

  final dynamic setup;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final reason = setup.blockedReasonKey as String?;
    final canStart = setup.canStart as bool;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.messageForKey(reason),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: AppSizes.touchComfort,
              child: FilledButton.icon(
                onPressed: canStart
                    ? () => context.push(Routes.recordCamera)
                    : null,
                icon: const Icon(Icons.videocam),
                label: Text(t.recordStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
