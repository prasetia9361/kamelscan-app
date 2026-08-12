import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// Profil pengguna — cerminan tabel `public.users` (Bab 5.2).
///
/// ⚠️ Tidak ada kolom password di sini, dan tidak boleh pernah ada. Password
/// sepenuhnya dikelola Supabase Auth di skema `auth` (Bab 5.1 poin 2).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String tenantId,
    required String email,
    required String fullName,
    @Default(UserRole.packer) UserRole role,
    @Default(true) bool isActive,
    String? username,
    String? phone,
    String? avatarUrl,
    DateTime? lastLoginAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AppUser;

  const AppUser._();

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  bool get isAdmin => role.isAdmin;
  bool get isOwner => role.isOwner;
  bool get isPacker => role.isPacker;

  /// Inisial untuk avatar fallback (Bab 9.x).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Owner boleh mengelola packer; Admin boleh, tetapi lewat panel terpisah.
  bool get canManagePackers => isOwner;

  /// Bab 2.2 — hanya Owner yang boleh membuat tautan publik.
  bool get canCreatePublicLink => isOwner;

  /// Bab 2.2 catatan 2 — tombol rekam disembunyikan dari Admin.
  bool get canRecord => isOwner || isPacker;
}
