import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/validators.dart';

part 'edit_profile_view_model.g.dart';

/// Isi formulir Edit Profil (Bab 9.6 butir 1).
class EditProfileData {
  const EditProfileData({
    required this.fullName,
    required this.phone,
    required this.username,
    this.avatarUrl,
    this.saving = false,
    this.uploadingPhoto = false,
  });

  final String fullName;
  final String phone;
  final String username;
  final String? avatarUrl;
  final bool saving;
  final bool uploadingPhoto;

  bool get isBusy => saving || uploadingPhoto;

  EditProfileData copyWith({
    String? fullName,
    String? phone,
    String? username,
    String? avatarUrl,
    bool? saving,
    bool? uploadingPhoto,
  }) =>
      EditProfileData(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        saving: saving ?? this.saving,
        uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
      );
}

@riverpod
class EditProfileViewModel extends _$EditProfileViewModel {
  @override
  Future<EditProfileData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final user = session.user;
    return EditProfileData(
      fullName: user.fullName,
      phone: user.phone ?? '',
      username: user.username ?? '',
      avatarUrl: user.avatarUrl,
    );
  }

  void setFullName(String v) => _update((s) => s.copyWith(fullName: v));
  void setPhone(String v) => _update((s) => s.copyWith(phone: v));
  void setUsername(String v) =>
      _update((s) => s.copyWith(username: v.trim().toLowerCase()));

  /// Unggah foto profil yang sudah dipilih **dan dipotong** di layar.
  ///
  /// Diunggah lebih dulu, terpisah dari tombol Simpan: berkasnya bisa ratusan
  /// kilobyte, dan menahannya sampai Simpan ditekan membuat tombol itu terasa
  /// menggantung tanpa penjelasan.
  Future<AppFailure?> uploadPhoto(Uint8List bytes) async {
    final current = state.value;
    final session = ref.read(sessionProvider).value;
    if (current == null || session == null) return null;

    state = AsyncData(current.copyWith(uploadingPhoto: true));

    final result = await ref.read(userRepositoryProvider).uploadAvatar(
          userId: session.user.id,
          bytes: bytes,
        );

    return result.fold(
      onOk: (url) {
        state = AsyncData(
          current.copyWith(avatarUrl: url, uploadingPhoto: false),
        );
        return null;
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_PROFIL unggah foto GAGAL · $failure');
        state = AsyncData(current.copyWith(uploadingPhoto: false));
        return failure;
      },
    );
  }

  /// Simpan. Mengembalikan `null` bila berhasil.
  ///
  /// Username diperiksa ketersediaannya lebih dulu lewat RPC — sama seperti
  /// saat mendaftar (Bab 6.2). Membiarkan server menolaknya dengan `23505`
  /// tetap aman, tetapi pesan yang muncul jauh lebih membingungkan daripada
  /// "username sudah dipakai".
  Future<AppFailure?> save() async {
    final current = state.value;
    final session = ref.read(sessionProvider).value;
    if (current == null || session == null || current.isBusy) return null;

    final nama = current.fullName.trim();
    final hp = current.phone.trim();
    final username = current.username.trim().toLowerCase();
    final user = session.user;

    // Validasi yang sama dengan pendaftaran, supaya aturan tidak bercabang.
    final salahNama = Validators.fullName(nama);
    if (salahNama != null) {
      return AppFailure(kind: FailureKind.validation, messageKey: salahNama);
    }
    final salahHp = Validators.phone(hp);
    if (salahHp != null) {
      return AppFailure(kind: FailureKind.validation, messageKey: salahHp);
    }
    if (username.isNotEmpty) {
      final salahUsername = Validators.username(username);
      if (salahUsername != null) {
        return AppFailure(
          kind: FailureKind.validation,
          messageKey: salahUsername,
        );
      }
    }

    state = AsyncData(current.copyWith(saving: true));

    // Hanya diperiksa bila memang berubah — memeriksa username sendiri akan
    // selalu menjawab "sudah dipakai".
    if (username.isNotEmpty && username != (user.username ?? '')) {
      final tersedia =
          await ref.read(authRepositoryProvider).isUsernameAvailable(username);
      final bebas = tersedia.valueOrNull ?? false;
      if (!bebas) {
        state = AsyncData(current.copyWith(saving: false));
        return const AppFailure(
          kind: FailureKind.validation,
          messageKey: 'validationUsernameTaken',
        );
      }
    }

    final result = await ref.read(userRepositoryProvider).updateProfile(
          user.id,
          fullName: nama,
          phone: hp,
          username: username.isEmpty ? null : username,
          avatarUrl: current.avatarUrl,
        );

    state = AsyncData(current.copyWith(saving: false));

    final failure = result.failureOrNull;
    if (failure != null) {
      debugPrint('KAMELSCAN_PROFIL simpan GAGAL · $failure');
      return failure;
    }

    // Seluruh aplikasi membaca profil dari `sessionProvider` — bilah atas,
    // halaman Akun, nama perekam di Riwayat. Tanpa muat ulang ini, nama lama
    // masih terpampang sampai aplikasi dibuka kembali.
    await ref.read(sessionProvider.notifier).reload();
    return null;
  }

  void _update(EditProfileData Function(EditProfileData) ubah) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(ubah(current));
  }
}
