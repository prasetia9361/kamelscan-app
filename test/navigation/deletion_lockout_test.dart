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

  // ---------------------------------------------------------------------------
  // 🔴 Router harus DIBERI TAHU, bukan hanya memutuskan dengan benar
  // ---------------------------------------------------------------------------
  //
  // Seluruh tes di atas memanggil `RouteGuards.redirect` LANGSUNG. Semuanya
  // lulus, dan cacatnya tetap lolos ke produksi: Owner menekan Hapus Akun,
  // permintaannya berhasil, `deletion_requested_at` benar-benar terisi — dan
  // layarnya diam di tempat. Harus keluar lalu masuk lagi baru layar kuncinya
  // muncul.
  //
  // Sebabnya `GoRouterRefreshNotifier` tidak menyimak keadaan itu, sehingga
  // penjaganya tidak pernah diminta menilai ulang. Penjaga yang benar tetapi
  // tidak pernah dipanggil sama saja dengan penjaga yang salah.
  //
  // Ini jebakan nomor 11 di catatan proyek, dan ia sudah berulang. Tes di bawah
  // menguji SAMBUNGANNYA, bukan keputusannya.
  group('GoRouterRefreshNotifier menyimak permintaan hapus akun', () {
    test('🔴 memberi tahu router saat penghapusan mulai tertunda', () async {
      final palsu = _SesiPalsuBerubah(sesiDengan());
      final c = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          currentRoleProvider.overrideWithValue(UserRole.owner),
          mustChangePasswordProvider.overrideWithValue(false),
          needsProfileCompletionProvider.overrideWithValue(false),
          passwordResetPendingProvider.overrideWith(() => _PemulihanPalsu(false)),
          sessionProvider.overrideWith(() => palsu),
        ],
      );
      addTearDown(c.dispose);
      await siap(c);

      final notifier = GoRouterRefreshNotifier(c.read(_refProvider));
      addTearDown(notifier.dispose);

      var diberitahu = 0;
      notifier.addListener(() => diberitahu++);

      palsu.ganti(
        sesiDengan(
          diminta: DateTime(2026, 9, 1),
          musnahkanSetelah: DateTime(2026, 9, 8),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        diberitahu,
        greaterThan(0),
        reason: 'Router tidak pernah diberi tahu, jadi penjaganya tidak pernah '
            'menilai ulang dan layarnya diam di tempat.',
      );
      expect(tujuan(c, Routes.home), Routes.deletionPending);
    });

    test('memberi tahu juga saat penghapusan dibatalkan', () async {
      final palsu = _SesiPalsuBerubah(
        sesiDengan(
          diminta: DateTime(2026, 9, 1),
          musnahkanSetelah: DateTime(2026, 9, 8),
        ),
      );
      final c = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          currentRoleProvider.overrideWithValue(UserRole.owner),
          mustChangePasswordProvider.overrideWithValue(false),
          needsProfileCompletionProvider.overrideWithValue(false),
          passwordResetPendingProvider.overrideWith(() => _PemulihanPalsu(false)),
          sessionProvider.overrideWith(() => palsu),
        ],
      );
      addTearDown(c.dispose);
      await siap(c);

      final notifier = GoRouterRefreshNotifier(c.read(_refProvider));
      addTearDown(notifier.dispose);

      var diberitahu = 0;
      notifier.addListener(() => diberitahu++);

      palsu.ganti(sesiDengan());
      await Future<void>.delayed(Duration.zero);

      expect(diberitahu, greaterThan(0));
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

/// Sesi palsu yang nilainya dapat DIGANTI di tengah tes, supaya sambungan
/// antara perubahan sesi dan `GoRouterRefreshNotifier` benar-benar terlihat.
/// [_SesiPalsu] nilainya tetap, jadi ia tidak dapat menguji hal itu.
class _SesiPalsuBerubah extends Session {
  _SesiPalsuBerubah(this._nilai);
  SessionContext? _nilai;

  @override
  Future<SessionContext?> build() async => _nilai;

  void ganti(SessionContext? baru) {
    _nilai = baru;
    state = AsyncData(baru);
  }
}

class _PemulihanPalsu extends PasswordResetPending {
  _PemulihanPalsu(this._nilai);
  final bool _nilai;

  @override
  bool build() => _nilai;
}
