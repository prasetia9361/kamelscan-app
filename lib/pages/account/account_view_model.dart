import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_constants.dart';
import '../../core/providers/repository_providers.dart';

part 'account_view_model.g.dart';

/// Kontak dukungan yang ditampilkan di halaman Akun (Bab 9.6 butir 5).
class SupportContact {
  const SupportContact({required this.whatsapp, required this.email});

  final String whatsapp;
  final String email;

  /// Nilai cadangan dari [AppConstants], dipakai bila `platform_settings`
  /// belum pernah terbaca — misalnya perangkat sedang tanpa sinyal.
  static const SupportContact fallback = SupportContact(
    whatsapp: AppConstants.supportWhatsApp,
    email: AppConstants.supportEmail,
  );

  /// Tautan WhatsApp beserta pesan pembuka.
  ///
  /// Nomor resi atau nama pengguna sengaja **tidak** ikut ditempelkan: pesan
  /// pembuka yang sudah terisi data pribadi akan ikut tersalin ke mana pun
  /// pengguna meneruskannya.
  Uri waLink(String pesan) => Uri.parse(
        'https://wa.me/$whatsapp?text=${Uri.encodeComponent(pesan)}',
      );
}

/// Bab 9.6 butir 5 — nomor WhatsApp admin dibaca dari `platform_settings`,
/// **bukan** ditulis mati di aplikasi, supaya Admin dapat menggantinya tanpa
/// merilis versi baru (Bab 5.2).
@riverpod
Future<SupportContact> supportContact(Ref ref) async {
  final result = await ref
      .read(settingsRepositoryProvider)
      .fetchPlatformSetting('contact');

  return result.fold(
    onOk: (data) => SupportContact(
      whatsapp: (data['whatsapp'] as String?)?.trim().isNotEmpty == true
          ? (data['whatsapp'] as String).trim()
          : AppConstants.supportWhatsApp,
      email: (data['email'] as String?)?.trim().isNotEmpty == true
          ? (data['email'] as String).trim()
          : AppConstants.supportEmail,
    ),
    // Gagal membaca pengaturan platform tidak boleh membuat halaman Akun
    // gagal dimuat — kontak cadangan lebih berguna daripada layar error.
    onErr: (_) => SupportContact.fallback,
  );
}
