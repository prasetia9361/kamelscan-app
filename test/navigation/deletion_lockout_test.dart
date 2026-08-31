import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/app_user.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/tenant.dart';
import 'package:kamelscan/core/providers/auth_provider.dart';
import 'package:kamelscan/core/providers/session_provider.dart';
import 'package:kamelscan/navigation/route_guards.dart';
import 'package:kamelscan/navigation/route_names.dart';

/// Kunci akun yang sedang menunggu dimusnahkan (Bab 9.6, migrasi 37).
///
/// 🔴 Layar konfirmasi hapus akun menjanjikan satu kalimat yang sangat spesifik
/// — *"akun langsung tidak dapat digunakan"* — dan janji itu ditegakkan
/// **hanya** oleh penjaga rute. Tidak ada tombol yang disembunyikan, tidak ada
/// policy RLS yang berubah; satu-satunya yang berdiri di antara akun itu dan
/// seluruh aplikasi adalah `RouteGuards.redirect`.
///
/// Karena itu berkas ini menguji setiap jalan masuk yang terpikirkan, bukan
/// satu contoh yang mewakili. Sebuah rute yang lolos berarti janji di layar
/// konfirmasi itu bohong pada rute tersebut, dan pemiliknya tidak akan pernah
/// tahu rute mana.
void main() {
  const user = AppUser(
    id: 'u1',
    tenantId: 't1',
    email: 'owner@contoh.com',
    fullName: 'Budi Santoso',
    role: UserRole.owner,
  );

  SessionContext sesiDengan({DateTime? diminta, DateTime? musnahkanSetelah}) =>
      SessionContext(
        user: user,
        tenant: Tenant(
          id: 't1',
          ownerId: 'u1',
          status: TenantStatus.active,
          deletionRequestedAt: diminta,
          deletionPurgeAfter: musnahkanSetelah,
        ),
        tierCatalog: TierCatalog.fallback,
      );

  /// 🔴 `Session.build()` async, jadi pembacaan pertama masih `AsyncLoading`
  /// dan `.value`-nya null — penjaga rute akan mengira tidak ada tenant sama
  /// sekali. Menunggu `future`-nya di sini membuat tesnya menguji keadaan yang
  /// benar-benar dihadapi aplikasi, bukan keadaan setengah termuat.
  Future<ProviderContainer> siap(ProviderContainer c) async {
    await c.read(sessionProvider.future);
    return c;
  }

  ProviderContainer wadah(SessionContext sesi) => ProviderContainer(
    overrides: [
      isSignedInProvider.overrideWithValue(true),
      currentRoleProvider.overrideWithValue(UserRole.owner),
      mustChangePasswordProvider.overrideWithValue(false),
      needsProfileCompletionProvider.overrideWithValue(false),
      passwordResetPendingProvider.overrideWith(() => _PemulihanPalsu(false)),
      sessionProvider.overrideWith(() => _SesiPalsu(sesi)),
    ],
  );

  String? tujuan(ProviderContainer c, String dari) =>
      RouteGuards(c.read(_refProvider)).redirect(dari);

  group('Akun yang sudah meminta dihapus', () {
    late ProviderContainer c;

    setUp(() async {
      c = await siap(
        wadah(
          sesiDengan(
            diminta: DateTime(2026, 8, 31),
            musnahkanSetelah: DateTime(2026, 9, 7),
          ),
        ),
      );
      addTearDown(c.dispose);
    });

    test('setiap rute dialihkan ke layar kunci', () {
      for (final rute in [
        Routes.home,
        Routes.history,
        Routes.shops,
        Routes.account,
        Routes.settings,
        Routes.payment,
        Routes.packers,
        Routes.editProfile,
        Routes.deleteAccount,
      ]) {
        expect(
          tujuan(c, rute),
          Routes.deletionPending,
          reason: '$rute masih dapat dibuka akun yang sedang dihapus',
        );
      }
    });

    test('layar kuncinya sendiri tidak dialihkan ke mana-mana', () {
      expect(tujuan(c, Routes.deletionPending), isNull);
    });

    // 🔴 Kedua layar ini menulis ke database — mengganti password dan mengisi
    // profil. Penjagaan yang diletakkan SESUDAH keduanya akan membiarkan akun
    // yang sudah pamit singgah dulu untuk menulis, dan itulah alasan blok
    // penjagaannya diletakkan di atas keduanya, bukan di bawah.
    test('tidak disinggahkan dulu ke Ganti Password atau Lengkapi Profil', () async {
      final ketat = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          currentRoleProvider.overrideWithValue(UserRole.owner),
          mustChangePasswordProvider.overrideWithValue(true),
          needsProfileCompletionProvider.overrideWithValue(true),
          passwordResetPendingProvider.overrideWith(
            () => _PemulihanPalsu(false),
          ),
          sessionProvider.overrideWith(
            () => _SesiPalsu(
              sesiDengan(
                diminta: DateTime(2026, 8, 31),
                musnahkanSetelah: DateTime(2026, 9, 7),
              ),
            ),
          ),
        ],
      );
      addTearDown(ketat.dispose);
      await siap(ketat);

      expect(tujuan(ketat, Routes.home), Routes.deletionPending);
    });

    // Tenggangnya sudah lewat tetapi cron belum berjalan. Inilah keadaan yang
    // paling tidak boleh dibiarkan masuk, dan satu-satunya yang akan lolos bila
    // `isDeletionPending` ikut membandingkan tanggal dengan waktu sekarang.
    test('tetap terkunci walau tenggangnya sudah lewat', () async {
      final lewat = await siap(
        wadah(
          sesiDengan(
            diminta: DateTime(2026, 1, 1),
            musnahkanSetelah: DateTime(2026, 1, 8),
          ),
        ),
      );
      addTearDown(lewat.dispose);

      expect(tujuan(lewat, Routes.home), Routes.deletionPending);
    });
  });

  group('Akun biasa', () {
    test('tidak terkunci', () async {
      final c = await siap(wadah(sesiDengan()));
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.home), isNull);
      expect(tujuan(c, Routes.deleteAccount), isNull);
    });

    test('layar kunci yang terbuka sesudah dibatalkan memulangkan ke Beranda',
        () async {
      final c = await siap(wadah(sesiDengan()));
      addTearDown(c.dispose);

      expect(tujuan(c, Routes.deletionPending), Routes.home);
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);

class _SesiPalsu extends Session {
  _SesiPalsu(this._nilai);
  final SessionContext? _nilai;

  @override
  Future<SessionContext?> build() async => _nilai;
}

class _PemulihanPalsu extends PasswordResetPending {
  _PemulihanPalsu(this._nilai);
  final bool _nilai;

  @override
  bool build() => _nilai;
}
