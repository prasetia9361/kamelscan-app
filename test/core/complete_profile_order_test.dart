import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/repositories/auth_repository.dart';
import 'package:kamelscan/core/repositories/user_repository.dart';
import 'package:kamelscan/core/services/auth_service.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Urutan penyimpanan di layar *Lengkapi Profil* (Bab 6.2).
///
/// 🔴 Persetujuan S&K **wajib dicatat paling akhir**, dan itu bukan selera.
/// `terms_accepted_at` adalah separuh syarat yang dibaca
/// `needsProfileCompletion`. Begitu ia terisi — sementara nomor HP, username,
/// nama usaha, atau password gagal disimpan — route guard menganggap profilnya
/// sudah lengkap dan melepas pengguna keluar dari layar ini. Tidak ada layar
/// lain yang akan menanyakan sisanya, dan nama usahanya akan kosong selamanya
/// di bilah atas aplikasi.
///
/// Kebalikannya sudah terjadi sungguhan pada 24 Agustus 2026 dalam bentuk lain:
/// `updatePhone` melapor berhasil padahal nol baris berubah, sehingga
/// persetujuan tercatat di atas profil yang sebenarnya belum lengkap. Berkas
/// ini menjaga urutannya agar kekeliruan serupa tidak dapat kembali diam-diam.
void main() {
  AuthRepository buat(_AuthPalsu auth) => AuthRepository(
        auth,
        UserRepository(SupabaseClient('https://x.supabase.co', 'kunci-uji')),
      );

  test('kolom kosong dilewati — server tidak disentuh untuk yang tidak diisi',
      () async {
    final auth = _AuthPalsu();
    final hasil = await buat(auth).completeProfile(
      phone: '081234567890',
      username: '   ',
      businessName: '',
      password: null,
    );

    expect(hasil.isOk, isTrue);
    expect(auth.jejak, ['phone', 'terms']);
  });

  test('semuanya terisi — persetujuan dicatat paling akhir', () async {
    final auth = _AuthPalsu();
    final hasil = await buat(auth).completeProfile(
      phone: '081234567890',
      username: 'gudangbaru',
      businessName: 'Gudang Baru',
      password: 'rahasia123',
    );

    expect(hasil.isOk, isTrue);
    expect(auth.jejak, ['phone', 'username', 'business', 'password', 'terms']);
  });

  test('username ditolak — persetujuan TIDAK ikut tercatat', () async {
    final auth = _AuthPalsu(gagalPada: 'username');
    final hasil = await buat(auth).completeProfile(
      phone: '081234567890',
      username: 'sudahdipakai',
      businessName: 'Gudang Baru',
      password: 'rahasia123',
    );

    expect(hasil.isErr, isTrue);
    // Yang sesudahnya tidak boleh dijalankan sama sekali.
    expect(auth.jejak, ['phone', 'username']);
  });

  test('password ditolak server — persetujuan TIDAK ikut tercatat', () async {
    final auth = _AuthPalsu(gagalPada: 'password');
    final hasil = await buat(auth).completeProfile(
      phone: '081234567890',
      username: 'gudangbaru',
      businessName: 'Gudang Baru',
      password: 'lemah',
    );

    expect(hasil.isErr, isTrue);
    expect(auth.jejak, ['phone', 'username', 'business', 'password']);
    expect(auth.jejak, isNot(contains('terms')));
  });

  test('nomor HP gagal disimpan — tidak ada apa pun sesudahnya', () async {
    final auth = _AuthPalsu(gagalPada: 'phone');
    final hasil = await buat(auth).completeProfile(
      phone: '081234567890',
      username: 'gudangbaru',
    );

    expect(hasil.isErr, isTrue);
    expect(auth.jejak, ['phone']);
  });
}

/// Mencatat urutan panggilan tanpa menyentuh jaringan.
///
/// Seluruh metode yang dipakai `completeProfile` ditimpa, sehingga `_auth`
/// milik [AuthService] — yang menuntut Supabase sudah diinisialisasi — tidak
/// pernah tersentuh.
class _AuthPalsu extends AuthService {
  _AuthPalsu({this.gagalPada});

  final String? gagalPada;
  final List<String> jejak = [];

  Future<Result<void>> _catat(String nama) async {
    jejak.add(nama);
    if (nama == gagalPada) {
      return const Result.err(AppFailure.permissionDenied);
    }
    return okVoid;
  }

  @override
  Future<Result<void>> updatePhone(String phone) => _catat('phone');

  @override
  Future<Result<void>> updateUsername(String username) => _catat('username');

  @override
  Future<Result<void>> updateBusinessName(String name) => _catat('business');

  @override
  Future<Result<void>> updatePassword(String newPassword) => _catat('password');

  @override
  Future<Result<void>> acceptTerms() => _catat('terms');
}
