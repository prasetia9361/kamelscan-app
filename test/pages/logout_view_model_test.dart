import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/app_constants.dart';
import 'package:kamelscan/core/providers/repository_providers.dart';
import 'package:kamelscan/core/repositories/auth_repository.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/core/utils/result.dart';
import 'package:kamelscan/pages/account/logout_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository auth;

  /// Isi awal yang mewakili dua golongan berbeda: milik akun (harus hilang saat
  /// keluar) dan milik perangkat (harus bertahan).
  Map<String, Object> initialPrefs() => {
        AppConstants.prefLastShopId: 'shop-lama',
        AppConstants.prefRecentResi: <String>['SPX123', 'JNE456'],
        AppConstants.prefThemeMode: 'dark',
        AppConstants.prefLanguage: 'id',
        AppConstants.prefTriggerMode: 'qr',
        AppConstants.prefOnboardingSeen: true,
      };

  setUp(() {
    auth = _MockAuthRepository();
    SharedPreferences.setMockInitialValues(initialPrefs());
  });

  ProviderContainer containerWith(_MockAuthRepository auth) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('LogoutViewModel — Bab 6.8', () {
    test('keluar yang berhasil mengembalikan keadaan ke idle', () async {
      when(() => auth.signOut()).thenAnswer((_) async => okVoid);
      final container = containerWith(auth);
      final vm = container.read(logoutViewModelProvider.notifier);

      await vm.signOut();

      verify(() => auth.signOut()).called(1);
      expect(container.read(logoutViewModelProvider), isA<LogoutIdle>());
    });

    test('cache milik akun dihapus, preferensi perangkat dipertahankan',
        () async {
      when(() => auth.signOut()).thenAnswer((_) async => okVoid);
      final container = containerWith(auth);

      await container.read(logoutViewModelProvider.notifier).signOut();

      final prefs = await SharedPreferences.getInstance();
      // Data pengguna sebelumnya: toko terakhir dan nomor resi paket pelanggan.
      expect(prefs.getString(AppConstants.prefLastShopId), isNull);
      expect(prefs.getStringList(AppConstants.prefRecentResi), isNull);
      // Preferensi perangkat tidak ada urusannya dengan siapa yang masuk.
      expect(prefs.getString(AppConstants.prefThemeMode), 'dark');
      expect(prefs.getString(AppConstants.prefLanguage), 'id');
      expect(prefs.getString(AppConstants.prefTriggerMode), 'qr');
      expect(prefs.getBool(AppConstants.prefOnboardingSeen), isTrue);
    });

    test('kegagalan keluar dilaporkan dan tidak menghapus apa pun', () async {
      when(() => auth.signOut())
          .thenAnswer((_) async => const Result<void>.err(AppFailure.network));
      final container = containerWith(auth);

      await container.read(logoutViewModelProvider.notifier).signOut();

      final state = container.read(logoutViewModelProvider);
      expect(state, isA<LogoutFailed>());
      expect((state as LogoutFailed).failure.kind, FailureKind.network);

      // Sesi masih hidup, jadi cache-nya masih milik pengguna yang sama.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefLastShopId), 'shop-lama');
      expect(prefs.getStringList(AppConstants.prefRecentResi), isNotNull);
    });

    test('clearError mengembalikan keadaan ke idle', () async {
      when(() => auth.signOut())
          .thenAnswer((_) async => const Result<void>.err(AppFailure.network));
      final container = containerWith(auth);
      final vm = container.read(logoutViewModelProvider.notifier);

      await vm.signOut();
      vm.clearError();

      expect(container.read(logoutViewModelProvider), isA<LogoutIdle>());
    });

    test('penekanan kedua saat masih sibuk diabaikan', () async {
      // Tombol memang sudah dimatikan selagi sibuk, tetapi penjagaan di
      // ViewModel yang menentukan: dua panggilan signOut berbarengan berarti
      // dua permintaan ke server untuk satu niat yang sama.
      final gate = Completer<void>();
      when(() => auth.signOut()).thenAnswer((_) async {
        await gate.future;
        return okVoid;
      });
      final container = containerWith(auth);
      final vm = container.read(logoutViewModelProvider.notifier);

      final first = vm.signOut();
      await vm.signOut(); // ditolak karena keadaan masih LogoutBusy
      gate.complete();
      await first;

      verify(() => auth.signOut()).called(1);
    });
  });
}
