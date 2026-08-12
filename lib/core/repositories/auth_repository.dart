import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
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
  }) async {
    final result = await _auth.signUp(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    return result.map(
      (response) => SignUpOutcome(
        needsEmailVerification: response.session == null,
        email: email,
      ),
    );
  }

  Future<Result<bool>> signInWithGoogle() => _auth.signInWithGoogle();

  Future<Result<void>> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<Result<void>> updatePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

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
