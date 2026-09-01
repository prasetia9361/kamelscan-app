import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/packer_summary.dart';
import '../models/tenant.dart';
import '../services/supabase_service.dart';
import '../utils/app_failure.dart';
import '../utils/result.dart';

/// Kredensial akun packer yang baru dibuat (Bab 6.7).
///
/// 🔴 [tempPassword] hanya ada di memori, sekali, tepat setelah akunnya dibuat.
/// Server menyimpannya dalam bentuk ter-hash dan tidak dapat mengembalikannya
/// lagi. Owner **wajib** diberi kesempatan menyalinnya sebelum dialognya
/// ditutup.
class NewPackerCredentials {
  const NewPackerCredentials({
    required this.userId,
    required this.email,
    required this.tempPassword,
  });

  final String userId;
  final String email;
  final String tempPassword;
}

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

  /// Daftar packer beserta jumlah video dan toko yang ditugaskan (Bab 9.6).
  ///
  /// Sama dengan [fetchPackers], hanya menambahkan embedding agar tiap baris
  /// dapat menjawab dua pertanyaan yang selalu muncul bersamaan: *"dia sudah
  /// merekam berapa?"* dan *"dia ditugaskan di toko mana?"*.
  Future<Result<List<PackerSummary>>> fetchPackerSummaries() async {
    try {
      final rows = await _client
          .from(AppConstants.tblUsers)
          .select(
            '*, ${AppConstants.tblPackageVideos}(count), '
            '${AppConstants.tblShopPackers}(${AppConstants.tblShops}(shop_name))',
          )
          .eq('role', UserRole.packer.wire)
          // 🔴 Menghapus video di aplikasi adalah penghapusan LUNAK: barisnya
          // tetap ada dengan `status = 'deleted'` (video_repository). Tanpa
          // saringan ini hitungannya memuat video yang di mata Owner sudah
          // hilang dari setiap layar — dan `canDelete` (videoCount == 0) ikut
          // salah, sehingga packer yang videonya sudah dibersihkan tetap
          // menolak dihapus.
          //
          // Dilaporkan Product Owner 1 September 2026 pada packer "Pepus".
          // Diukur langsung ke produksi hari itu: tanpa saringan Pepus = 1,
          // dengan saringan Pepus = 0.
          //
          // ⚠️ Saringan pada tabel tersemat hanya menyaring baris TERSEMAT-nya,
          // bukan membuang packer-nya dari daftar — sudah dibuktikan pada 13
          // packer sungguhan, semuanya tetap kembali.
          .neq('${AppConstants.tblPackageVideos}.status', VideoStatus.deleted.wire)
          .order('created_at', ascending: false);

      return Result.ok(
        rows.map((r) => PackerSummary.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Hapus akun packer beserta akun masuknya.
  ///
  /// 🔴 WAJIB lewat Edge Function `delete-packer`, jangan pernah kembali ke
  /// `delete from users`.
  ///
  /// Sampai 20 Agustus 2026 metode ini menghapus baris `public.users` langsung
  /// dari aplikasi. Itu hanya membuang **profilnya**: `public.users.id`
  /// menunjuk `auth.users(id) on delete cascade`, dan arah cascade-nya
  /// auth → public, tidak pernah sebaliknya. Akun masuknya tetap hidup.
  ///
  /// Akibatnya di perangkat Product Owner: packer yang sudah dihapus dari
  /// layar **masih dapat masuk dengan password lamanya**, emailnya tidak dapat
  /// dipakai lagi untuk membuat packer baru (`EMAIL_ALREADY_USED`), dan begitu
  /// ia masuk ia terjebak di *"Data tidak ditemukan"* karena profilnya sudah
  /// tidak ada. Yang paling berat bukan yang terlihat di layar, melainkan yang
  /// tidak: Owner mengira akses seorang bekas pegawai sudah dicabut, padahal
  /// belum.
  ///
  /// ⚠️ Tetap hanya mungkin bila packer itu belum pernah merekam.
  /// `package_videos.user_id` memakai `on delete restrict` (Bab 5.2) supaya
  /// video tetap menunjuk orang yang merekamnya — menghapus perekamnya akan
  /// memutus rantai bukti tepat di titik yang paling dipertanyakan saat
  /// sengketa. Untuk packer yang sudah tidak bekerja lagi, pakai
  /// [setPackerActive] dengan `false`.
  Future<Result<void>> deletePacker(String userId) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnDeletePacker,
        body: {'user_id': userId},
      );

      final data = response.data;
      if (data is Map && data['deleted'] == true) return okVoid;

      return Result.err(
        AppFailure.unknown('Balasan delete-packer tidak sah: $data'),
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

  /// Unggah foto profil ke bucket `avatars` (Bab 9.6).
  ///
  /// Jalurnya selalu `{userId}/avatar.jpg` — folder teratas adalah pemiliknya,
  /// dan itulah yang diperiksa policy `avatars_insert_own`
  /// (migrasi `23_avatars_bucket.sql`). Tanpa pola itu, siapa pun yang login
  /// dapat menimpa foto profil orang lain.
  ///
  /// Nama berkasnya sengaja **tetap**, bukan bertambah tiap unggahan: foto
  /// lama ditimpa sehingga tidak ada sampah yang menumpuk di penyimpanan.
  /// Konsekuensinya URL-nya tidak berubah, jadi penanda waktu ditempelkan
  /// sebagai query agar gambar lama di cache tidak ikut bertahan.
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      const path = 'avatar.jpg';
      final key = '$userId/$path';

      await _client.storage.from(AppConstants.bucketAvatars).uploadBinary(
            key,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final url = _client.storage.from(AppConstants.bucketAvatars).getPublicUrl(key);
      return Result.ok('$url?v=${DateTime.now().millisecondsSinceEpoch}');
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
  /// 🔴 Password sementaranya dikembalikan **sekali saja** oleh Edge Function
  /// dan tidak pernah dapat dibaca lagi — ia disimpan server dalam bentuk
  /// ter-hash. Pemanggil wajib menampilkannya ke Owner saat itu juga
  /// (Bab 6.7); membuangnya berarti akun packer yang baru dibuat tidak dapat
  /// dipakai siapa pun, dan satu-satunya jalan keluar adalah reset password.
  ///
  /// ⚠️ Sebelum 20 Agustus 2026 balasannya dipaksa menjadi `AppUser`, sehingga
  /// `temp_password` terbuang diam-diam. Kekeliruan itu tidak pernah terlihat
  /// karena layar Kelola Packer belum ada yang memakainya.
  Future<Result<NewPackerCredentials>> createPacker({
    required String email,
    required String fullName,
    String? password,
    List<String> shopIds = const [],
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnCreatePacker,
        body: {
          'email': email,
          'full_name': fullName,
          'password': ?password,
          'shop_ids': shopIds,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return Result.err(AppFailure.unknown('Balasan Edge Function tidak sah'));
      }

      final tempPassword = data['temp_password'] as String?;
      if (tempPassword == null) {
        return Result.err(
          AppFailure.unknown('Password sementara tidak diterima'),
        );
      }

      return Result.ok(
        NewPackerCredentials(
          userId: (data['user_id'] as String?) ?? '',
          email: (data['email'] as String?) ?? email,
          tempPassword: tempPassword,
        ),
      );
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
