import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/tenant.dart';
import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';

class UserRepository {
  const UserRepository(this._client);

  final SupabaseClient _client;

  Future<Result<AppUser>> fetchCurrentUser() async {
    final id = SupabaseService.currentUser?.id;
    if (id == null) return const Result.err(AppFailure.sessionExpired);
    return fetchUser(id);
  }

  Future<Result<AppUser>> fetchUser(String id) async {
    try {
      final row = await _client
          .from(AppConstants.tblUsers)
          .select()
          .eq('id', id)
          .single();
      return Result.ok(AppUser.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<Tenant>> fetchTenant(String tenantId) async {
    try {
      final row = await _client
          .from(AppConstants.tblTenants)
          .select()
          .eq('id', tenantId)
          .single();
      return Result.ok(Tenant.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Daftar packer milik tenant aktif. RLS sudah membatasi ke tenant sendiri.
  Future<Result<List<AppUser>>> fetchPackers() async {
    try {
      final rows = await _client
          .from(AppConstants.tblUsers)
          .select()
          .eq('role', UserRole.packer.wire)
          .order('created_at', ascending: false);
      return Result.ok(
        rows.map((r) => AppUser.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<AppUser>> updateProfile(
    String id, {
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? username,
  }) async {
    try {
      final row = await _client
          .from(AppConstants.tblUsers)
          .update({
            'full_name': ?fullName,
            'phone': ?phone,
            'avatar_url': ?avatarUrl,
            'username': ?username,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Result.ok(AppUser.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Pembuatan akun packer **wajib** lewat Edge Function service-role.
  ///
  /// Bab 5.4 sengaja tidak memberi policy INSERT pada `public.users` untuk
  /// peran `authenticated`, dan batas jumlah packer ditegakkan trigger
  /// `check_packer_limit()` (Bab 7.4). Jangan pernah membuat jalur insert
  /// langsung dari klien.
  Future<Result<AppUser>> createPacker({
    required String email,
    required String password,
    required String fullName,
    List<String> shopIds = const [],
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnCreatePacker,
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'shop_ids': shopIds,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return Result.err(AppFailure.unknown('Balasan Edge Function tidak sah'));
      }
      return Result.ok(AppUser.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<void>> setPackerActive(String userId, bool isActive) async {
    try {
      await _client
          .from(AppConstants.tblUsers)
          .update({'is_active': isActive})
          .eq('id', userId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
