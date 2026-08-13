import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';

/// Pembungkus tipis di atas SDK Supabase (Bab 3.2).
///
/// Tugasnya hanya inisialisasi dan menyediakan akses `client`. Semua query
/// bisnis tinggal di Repository, bukan di sini.
class SupabaseService {
  const SupabaseService._();

  static const AppLogger _log = AppLogger('SupabaseService');

  static Future<void> init() async {
    Env.assertConfigured();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // `anonKey` sudah deprecated di supabase_flutter 2.17. Parameter baru
      // menerima kunci yang sama, baik JWT anon lama maupun format
      // `sb_publishable_...`. Nama variabel lingkungan tetap SUPABASE_ANON_KEY
      // agar sesuai Bab 4.4.
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // PKCE diperlukan untuk OAuth Google lewat deep link (Bab 6).
        authFlowType: AuthFlowType.pkce,
      ),
      debug: Env.isDev,
    );
    _log.i('Supabase siap (${Env.appEnv.name})');
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static Session? get session => auth.currentSession;

  static User? get currentUser => auth.currentUser;

  static bool get isSignedIn => session != null;

  /// Klaim khusus yang disisipkan Custom Access Token Hook (Bab 5.3).
  ///
  /// ⚠️ JWT lama masih membawa nilai lama sampai token disegarkan. Setelah
  /// tier atau role berubah, panggil [refreshSession] — dan tetap validasi
  /// ulang operasi sensitif terhadap tabel, jangan hanya percaya JWT.
  static Map<String, dynamic> get jwtClaims => _claimsFromToken();

  static String? get tenantId => jwtClaims['tenant_id'] as String?;
  static String? get appRole => jwtClaims['app_role'] as String?;
  static String? get tierPlan => jwtClaims['tier_plan'] as String?;

  static Future<void> refreshSession() async {
    try {
      await auth.refreshSession();
    } on AuthException catch (e) {
      _log.w('Gagal menyegarkan sesi', e.message);
    }
  }

  static Map<String, dynamic> _claimsFromToken() {
    final token = session?.accessToken;
    if (token == null) return const {};
    try {
      return Map<String, dynamic>.from(JwtDecoder.decode(token));
    } on Object catch (e) {
      _log.w('JWT tidak dapat dibaca', e);
      return const {};
    }
  }

  /// Terjemahkan error Supabase menjadi [AppFailure].
  ///
  /// Bab 9.10: pesan mentah server **tidak boleh** sampai ke layar pengguna.
  static AppFailure mapError(Object error, [StackTrace? stack]) {
    if (error is AppFailure) return error;

    if (error is PostgrestException) {
      return switch (error.code) {
        // Pelanggaran unique constraint — resi ganda (Bab 7.7).
        '23505' => AppFailure.resiDuplicate.copyWith(debugMessage: error.message),
        // RLS menolak.
        '42501' || 'PGRST301' =>
          AppFailure.permissionDenied.copyWith(debugMessage: error.message),
        'PGRST116' => AppFailure.notFound.copyWith(debugMessage: error.message),
        _ => _mapByMessage(error.message, error.code),
      };
    }

    if (error is AuthException) return _mapAuth(error);

    if (error is StorageException) {
      return AppFailure.storage(error.message, stack);
    }

    return AppFailure.unknown(error, stack);
  }

  /// Petakan [AuthException] ke pesan yang benar-benar menjelaskan sebabnya.
  ///
  /// ⚠️ Sebelumnya SELURUH AuthException dipetakan ke `errorSessionExpired`.
  /// Akibatnya pendaftaran dengan email yang sudah terpakai menampilkan
  /// *"Sesi Anda telah berakhir. Silakan masuk kembali."* — pesan yang tidak
  /// masuk akal dan menyesatkan; pengguna diminta masuk padahal ia sedang
  /// mencoba mendaftar. Ditemukan saat uji perangkat 13 Agustus 2026.
  ///
  /// Bab 6.2 menuntut pesan spesifik untuk email ganda, dan Bab 9.10 melarang
  /// pesan mentah server sampai ke layar.
  static AppFailure _mapAuth(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final msg = e.message.toLowerCase();

    bool has(String needle) => code.contains(needle) || msg.contains(needle);

    final (FailureKind kind, String key) = switch (true) {
      // Bab 6.2 — email sudah terdaftar.
      _ when has('user_already_exists') ||
              has('already registered') ||
              has('already been registered') =>
        (FailureKind.validation, 'errorEmailAlreadyUsed'),

      _ when has('invalid_credentials') || has('invalid login credentials') =>
        (FailureKind.auth, 'errorInvalidCredentials'),

      _ when has('email_not_confirmed') || has('not confirmed') =>
        (FailureKind.auth, 'errorEmailNotConfirmed'),

      // Batas kirim email tercapai (Bab 6.4). Bukan salah pengguna — minta
      // menunggu, jangan suruh mendaftar ulang.
      _ when has('rate_limit') || has('rate limit') || has('too many') =>
        (FailureKind.validation, 'errorEmailRateLimited'),

      _ when has('weak_password') =>
        (FailureKind.validation, 'validationPasswordWeak'),

      _ when has('same_password') =>
        (FailureKind.validation, 'errorSamePassword'),

      _ when has('email_address_invalid') || has('invalid email') =>
        (FailureKind.validation, 'validationEmailInvalid'),

      // Barulah ini yang benar-benar soal sesi.
      _ when has('session') || has('jwt') || has('token is expired') ||
              e.statusCode == '401' =>
        (FailureKind.auth, 'errorSessionExpired'),

      _ => (FailureKind.auth, 'errorAuthGeneric'),
    };

    return AppFailure(
      kind: kind,
      messageKey: key,
      debugMessage: '${e.code ?? '-'}: ${e.message}',
      code: e.statusCode,
    );
  }

  /// Trigger di server melempar pesan bertanda (Bab 7.4). Petakan ke failure
  /// yang punya arti di UI.
  static AppFailure _mapByMessage(String message, String? code) {
    final m = message.toUpperCase();
    if (m.contains('TOKEN_EXHAUSTED') || m.contains('INSUFFICIENT_TOKEN')) {
      return AppFailure.tokenExhausted.copyWith(debugMessage: message);
    }
    if (m.contains('SUBSCRIPTION_INACTIVE')) {
      return AppFailure.subscriptionInactive.copyWith(debugMessage: message);
    }
    if (m.contains('PACKER_LIMIT')) {
      return AppFailure.packerLimitReached.copyWith(debugMessage: message);
    }
    return AppFailure(
      kind: FailureKind.unknown,
      messageKey: 'errorUnknown',
      debugMessage: message,
      code: code,
    );
  }
}

/// Pembaca payload JWT tanpa verifikasi tanda tangan.
///
/// 🔴 Hanya untuk membaca klaim tampilan (tenant_id, role, tier) di sisi klien.
/// **Jangan pernah** memakainya sebagai dasar keputusan keamanan — penegakan
/// sesungguhnya ada di RLS (Bab 2.3).
class JwtDecoder {
  const JwtDecoder._();

  static Map<String, dynamic> decode(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : const {};
  }
}
