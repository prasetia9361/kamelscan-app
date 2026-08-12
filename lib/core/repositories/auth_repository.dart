import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';
import 'user_repository.dart';

/// Gerbang tunggal urusan sesi untuk ViewModel.
///
/// ViewModel tidak pernah menyentuh `AuthService` atau `SupabaseClient`
/// langsung (Bab 3.1 poin 1).
class AuthRepository {
  const AuthRepository(this._auth, this._users);

  final AuthService _auth;
  final UserRepository _users;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  bool get isSignedIn => SupabaseService.isSignedIn;

  String? get currentUserId => SupabaseService.currentUser?.id;

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    return switch (result) {
      Err(:final failure) => Result.err(failure),
      Ok() => _users.fetchCurrentUser(),
    };
  }

  /// Registrasi mandiri Owner (Bab 2.1).
  ///
  /// Profil, tenant, dan dompet token uji coba dibuat oleh trigger
  /// `handle_new_user` di server — **bukan** oleh klien (Bab 5.4 & Bab 6).
  /// Karena itu metode ini hanya mengembalikan status verifikasi email.
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? username,
    String? businessName,
  }) async {
    final result = await _auth.signUp(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      username: username,
      businessName: businessName,
    );
    return result.map(
      (response) => SignUpOutcome(
        needsEmailVerification: response.session == null,
        email: email,
      ),
    );
  }

  /// Bab 6.6 — login memakai username: ditukar dulu menjadi email lewat Edge
  /// Function, baru dilanjutkan seperti login biasa.
  Future<Result<AppUser>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final emailResult = await _auth.resolveUsernameToEmail(username);
    return switch (emailResult) {
      Err(:final failure) => Result.err(failure),
      Ok(:final value) => signIn(email: value, password: password),
    };
  }

  /// Menerima email **atau** username pada satu kolom isian, seperti yang
  /// diminta Bab 6.1. Dibedakan dari ada tidaknya `@`.
  Future<Result<AppUser>> signInWithIdentifier({
    required String identifier,
    required String password,
  }) {
    final id = identifier.trim();
    return id.contains('@')
        ? signIn(email: id, password: password)
        : signInWithUsername(username: id, password: password);
  }

  Future<Result<void>> signInWithGoogle() => _auth.signInWithGoogle();

  Future<Result<void>> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<Result<void>> updatePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  /// Bab 6.8 — ganti password dengan verifikasi ulang password lama lebih dulu.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final reauth = await _auth.reauthenticate(currentPassword);
    if (reauth case Err(:final failure)) {
      // Bedakan "password lama salah" dari kegagalan lain agar pesannya tepat.
      return Result.err(
        failure.kind == FailureKind.auth
            ? const AppFailure(
                kind: FailureKind.validation,
                messageKey: 'errorCurrentPasswordWrong',
              )
            : failure,
      );
    }

    final updated = await _auth.updatePassword(newPassword);
    if (updated case Err(:final failure)) return Result.err(failure);

    // Bab 6.7 — lepas paksaan ganti password setelah berhasil.
    if (_auth.mustChangePassword) {
      await _auth.clearMustChangePassword();
    }
    return okVoid;
  }

  /// Bab 6.7 — true selama packer belum mengganti password sementaranya.
  bool get mustChangePassword => _auth.mustChangePassword;

  /// Bab 6.7 — pembuatan akun packer oleh Owner.
  Future<Result<PackerCredentials>> createPacker({
    required String email,
    required String fullName,
    String? phone,
    List<String> shopIds = const [],
  }) =>
      _auth.createPacker(
        email: email,
        fullName: fullName,
        phone: phone,
        shopIds: shopIds,
      );

  Future<Result<void>> resendVerificationEmail(String email) =>
      _auth.resendVerificationEmail(email);

  Future<Result<void>> signOut() => _auth.signOut();

  /// Bab 5.3 — setelah tier atau role berubah, JWT lama masih membawa nilai
  /// lama sampai token disegarkan.
  Future<void> refreshSession() => SupabaseService.refreshSession();
}

class SignUpOutcome {
  const SignUpOutcome({
    required this.needsEmailVerification,
    required this.email,
  });

  final bool needsEmailVerification;
  final String email;
}
