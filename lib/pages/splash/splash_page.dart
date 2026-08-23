import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/failure_messages.dart';
import 'splash_view_model.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(splashViewModelProvider, (previous, next) {
      final destination = next.value;
      if (destination != null && context.mounted) {
        context.go(destination);
      }
    });

    final state = ref.watch(splashViewModelProvider);

    return Scaffold(
      body: state.when(
        loading: () => const _SplashBranding(),
        error: (e, _) => AppErrorView(
          failure: e,
          // Bukan sekadar `ref.invalidate` layar ini — `retry()` juga membuang
          // sesi yang tersimpan gagal. Tanpa itu tombolnya tidak melakukan
          // apa pun; alasannya di `SplashViewModel.retry`.
          onRetry: ref.read(splashViewModelProvider.notifier).retry,
        ),
        // Navigasi ditangani listener di atas; branding tetap tampil sampai
        // rute berganti agar tidak ada kedipan layar kosong.
        data: (_) => const _SplashBranding(),
      ),
    );
  }
}

class _SplashBranding extends StatelessWidget {
  const _SplashBranding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(context.l10n.appName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            context.l10n.appTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }
}
