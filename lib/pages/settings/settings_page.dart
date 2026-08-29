import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_constants.dart';
import '../../core/providers/pipeline_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/failure_messages.dart';
import 'settings_view_model.dart';
import 'widgets/cellular_upload_switch.dart';

/// Halaman Pengaturan (Bab 9.7).
///
/// Kelompoknya lima: Tampilan, Perekaman, Privasi, Data, lalu Info.
///
/// ⚠️ Bab 9.7 menyebut enam — kelompok **Merek** dihapus 29 Agustus 2026
/// bersama pengaturan watermark, atas keputusan Product Owner. Satu-satunya
/// isinya yang tersisa, sakelar GPS, pindah ke Perekaman: yang diaturnya
/// memang apa yang ikut terbakar ke video berikutnya.
///
/// 🔴 Di **web**, tiga kelompok tidak ditampilkan sama sekali: Perekaman,
/// Privasi, dan Data. Alasannya sama seperti Bab 10.1 menghapus rute
/// perekaman dari web — merekam dan menyimpan berkas sementara hanya terjadi
/// di HP, dan pengaturan yang tidak dapat berpengaruh apa pun di tempat ia
/// ditampilkan lebih buruk daripada pengaturan yang tidak ada: ia mengundang
/// orang mengubahnya lalu bertanya-tanya kenapa tidak terjadi apa-apa.
///
/// ⚠️ Yang ikut hilang di web bersama kelompok Privasi adalah *"Packer boleh
/// melihat riwayat se-toko"* — satu-satunya isinya, dan satu-satunya yang
/// sebenarnya **bukan** soal perekaman. Sesudah ini ia hanya dapat diubah
/// dari HP. Product Owner sudah diberi tahu.

/// Kelompok pengaturan menurut Bab 9.7.
enum SettingsGroup { display, recording, privacy, data, info }

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Apakah satu kelompok tampil pada keadaan tertentu.
  ///
  /// 🔴 Dipisah sebagai fungsi murni, mengikuti aturan yang lahir dari cacat
  /// login Google (`DEVIASI_LIBRARY.md` O.14): **percabangan `kIsWeb` yang
  /// ditulis langsung di dalam kode tidak dapat diuji.** `kIsWeb` adalah
  /// konstanta waktu kompilasi; pada `flutter test` nilainya selalu `false`,
  /// sehingga cabang webnya tidak pernah dijalankan satu kali pun dan tidak
  /// ada yang bisa membantahnya. Di berkas itu, komentarnya menjanjikan
  /// pemisahan mobile/web selama berminggu-minggu sementara kodenya tidak
  /// pernah melakukannya.
  static bool tampil(
    SettingsGroup group, {
    required bool isWeb,
    required bool isOwner,
  }) =>
      switch (group) {
        SettingsGroup.display || SettingsGroup.info => true,

        // 🔴 "Bersihkan cache" di web selalu menjawab "tidak ada berkas
        // sementara untuk dihapus" — bukan karena bersih, melainkan karena
        // peramban memang tidak menyimpan berkas video sementara. Tombolnya
        // tidak melakukan apa pun dan MENGAKU BERHASIL, dan kegagalannya
        // ditelan `on Object catch` sehingga tidak ada satu pun tanda.
        //
        // Pengaturan yang berbohong lebih buruk daripada pengaturan yang tidak
        // ada. Alasan yang sama seperti tiga kelompok di bawah.
        SettingsGroup.data => !isWeb,

        SettingsGroup.recording => !isWeb,
        SettingsGroup.privacy => !isWeb && isOwner,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider).value;
    final isOwner = session?.isOwner ?? false;

    return SafeArea(
      child: ListView(
        // Jarak bawah 88 dp — tombol Rekam mengambang menumpang di atas isi
        // halaman dan akan menutupi baris terakhir.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(t.navSettings, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),

          _Kelompok(judul: t.settingsGroupDisplay, children: const [
            _ThemePicker(),
            _LanguagePicker(),
          ]),

          // Ketiganya mengatur apa yang terjadi saat merekam — dan merekam
          // hanya ada di HP (Bab 10.1).
          if (tampil(SettingsGroup.recording, isWeb: kIsWeb, isOwner: isOwner))
            _Kelompok(judul: t.settingsGroupRecording, children: [
              const _MicSwitch(),
              const SizedBox(height: 10),
              const _VoiceOverSwitch(),
              const SizedBox(height: 10),
              const CellularUploadSwitch(),
              // 🔴 GPS pindah ke sini dari kelompok **Merek**, yang dihapus
              // bersama pengaturan watermark (keputusan Product Owner
              // 29 Agustus 2026). Ia memang pengaturan perekaman: yang
              // diaturnya adalah apa yang ikut terbakar ke video BERIKUTNYA.
              //
              // Kelompok bernama "Merek" yang isinya tinggal satu sakelar GPS
              // akan terbaca seperti judul yang lupa dihapus.
              if (isOwner) ...[
                const SizedBox(height: 10),
                const _GpsSwitch(),
              ],
            ]),

          if (tampil(SettingsGroup.privacy, isWeb: kIsWeb, isOwner: isOwner))
            _Kelompok(
              judul: t.settingsGroupPrivacy,
              children: const [_PackerHistorySwitch()],
            ),

          if (tampil(SettingsGroup.data, isWeb: kIsWeb, isOwner: isOwner))
            _Kelompok(
              judul: t.settingsGroupData,
              children: const [_ClearCache()],
            ),
          _Kelompok(judul: t.settingsGroupInfo, children: const [_InfoTile()]),
        ],
      ),
    );
  }
}

class _Kelompok extends StatelessWidget {
  const _Kelompok({required this.judul, required this.children});

  final String judul;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            judul,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tampilan
// ---------------------------------------------------------------------------

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final mode = ref.watch(themeModeProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_6_outlined, size: 20),
                const SizedBox(width: 12),
                Text(t.settingsTheme,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final (m, label) in <(ThemeMode, String)>[
                  (ThemeMode.system, t.settingsThemeDefault),
                  (ThemeMode.light, t.settingsThemeLight),
                  (ThemeMode.dark, t.settingsThemeDark),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: mode == m,
                    onSelected: (_) =>
                        ref.read(appPreferencesProvider.notifier).setThemeMode(m),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final code = ref.watch(languageCodeProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate_rounded, size: 20),
                const SizedBox(width: 12),
                Text(t.settingsLanguage,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final (c, label) in <(String, String)>[
                  ('id', t.settingsLanguageId),
                  ('en', t.settingsLanguageEn),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: code == c,
                    onSelected: (_) =>
                        ref.read(appPreferencesProvider.notifier).setLanguage(c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Perekaman
// ---------------------------------------------------------------------------

/// Sakelar **"Rekam dengan suara"** (Bab 9.7, diminta Product Owner
/// 19 Agustus 2026).
///
/// Berlaku pada perekaman **berikutnya**: nilainya dibaca saat kamera
/// disiapkan, bukan saat tombol rekam ditekan.
///
/// ⚠️ Ia hanya dapat menurunkan kemampuan. Bila izin mikrofon ditolak sistem,
/// video tetap bisu walaupun sakelar ini menyala — dan itu memang benar
/// (Bab 8.9).
class _MicSwitch extends ConsumerWidget {
  const _MicSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(micEnabledProvider);
    final value = async.value ?? true;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: async.isLoading
            ? null
            : (next) => ref.read(micEnabledProvider.notifier).set(next),
        secondary: Icon(
          value ? Icons.mic_outlined : Icons.mic_off_outlined,
        ),
        title: Text(t.settingsMic),
        subtitle: Text(value ? t.settingsMicBody : t.settingsMicOffBody),
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }
}

class _VoiceOverSwitch extends ConsumerWidget {
  const _VoiceOverSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final prefs = ref.watch(appPreferencesProvider);
    final value = prefs.value?.voiceOverEnabled ?? true;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: prefs.isLoading
            ? null
            : (next) => ref
                .read(appPreferencesProvider.notifier)
                .setVoiceOverEnabled(next),
        secondary: const Icon(Icons.record_voice_over_outlined),
        title: Text(t.settingsVoiceOver),
        subtitle: Text(t.settingsVoiceOverBody),
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Merek — Owner
// ---------------------------------------------------------------------------

/// Bab 9.7 — bagi tier Standar baris ini **tetap terlihat** namun terkunci
/// dengan gembok dan label *Fitur Pro*.
///
/// Menyembunyikan fitur berbayar sepenuhnya membuat pelanggan tidak tahu apa
/// yang mereka lewatkan; menekannya membuka halaman Pembayaran.
class _GpsSwitch extends ConsumerWidget {
  const _GpsSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(tenantSettingsViewModelProvider);
    final value = async.value?.showGpsOnWatermark ?? true;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: async.isLoading
            ? null
            : (next) async {
                final messenger = ScaffoldMessenger.of(context);
                final failure = await ref
                    .read(tenantSettingsViewModelProvider.notifier)
                    .setShowGps(next);
                if (failure == null || !context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(context.failureMessage(failure))),
                );
              },
        secondary: const Icon(Icons.location_on_outlined),
        title: Text(t.settingsShowGps),
        subtitle: Text(t.settingsShowGpsBody),
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privasi — Owner
// ---------------------------------------------------------------------------

class _PackerHistorySwitch extends ConsumerWidget {
  const _PackerHistorySwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(tenantSettingsViewModelProvider);
    final value = async.value?.shopHistoryVisibleToPacker ?? false;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: async.isLoading
            ? null
            : (next) async {
                final messenger = ScaffoldMessenger.of(context);
                final failure = await ref
                    .read(tenantSettingsViewModelProvider.notifier)
                    .setShopHistoryVisible(next);
                if (failure == null || !context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(context.failureMessage(failure))),
                );
              },
        secondary: const Icon(Icons.groups_outlined),
        title: Text(t.settingsPackerHistory),
        subtitle: Text(t.settingsPackerHistoryBody),
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

/// Bersihkan cache (Bab 9.7).
///
/// 🔴 Yang dihapus **hanya** direktori cache sementara. Rekaman yang belum
/// terkirim tidak ada di sana — sejak L.4 hasil olahan video disimpan di
/// `getApplicationSupportDirectory()`, justru karena cache boleh dibuang sistem
/// operasi kapan saja dan isinya di sini adalah bukti pelanggan.
class _ClearCache extends ConsumerStatefulWidget {
  const _ClearCache();

  @override
  ConsumerState<_ClearCache> createState() => _ClearCacheState();
}

class _ClearCacheState extends ConsumerState<_ClearCache> {
  bool _sedang = false;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(t.settingsClearCache),
        subtitle: Text(t.settingsClearCacheBody),
        isThreeLine: true,
        trailing: _sedang
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : null,
        onTap: _sedang ? null : _bersihkan,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      ),
    );
  }

  Future<void> _bersihkan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sedang = true);

    var terhapus = 0;
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        for (final entry in dir.listSync()) {
          try {
            entry.deleteSync(recursive: true);
            terhapus++;
          } on FileSystemException {
            // Berkas yang sedang dipakai proses lain dilewati saja — membatalkan
            // seluruh pembersihan karena satu berkas terkunci tidak ada
            // gunanya bagi pengguna.
          }
        }
      }
    } on Object {
      // Kegagalan membaca direktori cache bukan hal yang perlu dijelaskan
      // panjang; pesannya sama saja bagi pengguna.
    }

    if (!mounted) return;
    setState(() => _sedang = false);
    messenger.showSnackBar(
      SnackBar(content: Text(t.settingsCacheCleared(terhapus))),
    );
  }
}

// ---------------------------------------------------------------------------
// Info
// ---------------------------------------------------------------------------

class _InfoTile extends StatelessWidget {
  const _InfoTile();

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(t.settingsVersion),
                subtitle: Text(
                  info == null
                      ? AppConstants.appName
                      : '${AppConstants.appName} ${info.version} (${info.buildNumber})',
                ),
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(t.settingsTerms),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _buka(AppConstants.termsUrl),
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.settingsPrivacy),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _buka(AppConstants.privacyUrl),
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          ),
        ],
      ),
    );
  }

  Future<void> _buka(String url) async {
    final uri = Uri.parse(url);
    // Dibuka di peramban luar, bukan di dalam aplikasi: dokumen S&K dan
    // kebijakan privasi berubah tanpa rilis baru, dan pengguna berhak
    // membacanya di tempat yang dapat ia simpan atau bagikan.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
