import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/services/ffmpeg_check_overlay.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'navigation/app_router.dart';

/// `MaterialApp.router` + tema + lokalisasi (Bab 3.2).
class KamelScanApp extends ConsumerWidget {
  const KamelScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageCodeProvider);

    return MaterialApp.router(
      title: 'KamelScan',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      // Hamparan diagnostik FFmpeg — hanya aktif di debug, dihapus setelah
      // butir D.4 DEVIASI_LIBRARY.md tuntas.
      builder: (context, child) =>
          FfmpegCheckOverlay(child: child ?? const SizedBox.shrink()),

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Bab 9.11 — Indonesia default, Inggris dapat dipilih di Pengaturan.
      locale: Locale(language),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supported) {
        // Bab 9.11 poin 4: ikuti bahasa perangkat bila didukung, selain itu
        // jatuh ke Bahasa Indonesia.
        final code = deviceLocale?.languageCode;
        if (code != null && supported.any((l) => l.languageCode == code)) {
          return Locale(code);
        }
        return const Locale('id');
      },
    );
  }
}
