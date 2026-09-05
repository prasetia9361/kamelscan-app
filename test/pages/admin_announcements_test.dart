import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/announcement.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/settings/admin_announcements_page.dart';
import 'package:kamelscan/pages/admin/settings/admin_settings_view_model.dart';

/// Kelola Iklan & Pengumuman (migrasi 50), diminta Product Owner 5 September
/// 2026.
///
/// 🔴 Yang dijaga tes ini satu hal di atas segalanya: **formulir tidak boleh
/// menyimpan pengumuman penting tanpa tautan tombol yang sah.**
///
/// Pengumuman penting mengunci aplikasi sampai tombol aksinya ditekan. Tanpa
/// tautan yang dapat dibuka, tombol itu tidak melakukan apa-apa dan tidak ada
/// tanda silang — seluruh pelanggan terkurung sekaligus, tanpa satu pun galat
/// di mana pun, dan kita baru tahu dari telepon.
///
/// Dirender dengan `AppTheme` sungguhan (aturan 18).
void main() {
  Future<void> pasang(
    WidgetTester tester,
    _VmPengumuman vm, {
    double lebar = 1000,
    double tinggi = 1600,
  }) async {
    tester.view.physicalSize = Size(lebar, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminAnnouncementsViewModelProvider.overrideWith(() => vm)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AdminAnnouncementsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Announcement buat({
    String id = 'a1',
    String title = 'Event akhir bulan',
    AnnouncementKind kind = AnnouncementKind.normal,
    AnnouncementAudience audience = AnnouncementAudience.all,
    String? actionUrl,
    bool isActive = true,
  }) =>
      Announcement(
        id: id,
        title: title,
        body: 'Isi pengumuman.',
        kind: kind,
        audience: audience,
        actionUrl: actionUrl,
        isActive: isActive,
        createdAt: DateTime(2026, 9, 5),
      );

  group('Daftar', () {
    testWidgets('kosong menjelaskan kegunaannya, bukan menyatakan galat',
        (tester) async {
      await pasang(tester, _VmPengumuman(const []));

      expect(find.text('Belum ada pengumuman'), findsOneWidget);
      // Sampai Admin membuat yang pertama, INI keadaan yang normal.
      expect(find.textContaining('perawatan terjadwal'), findsOneWidget);
    });

    testWidgets('🔴 jenis dan sasaran tiap baris terbaca', (tester) async {
      await pasang(
        tester,
        _VmPengumuman([
          buat(
            id: 'update',
            title: 'Versi baru',
            kind: AnnouncementKind.important,
            actionUrl: 'https://play.google.com/store/apps/details?id=x',
          ),
          buat(id: 'event', audience: AnnouncementAudience.owner),
        ]),
      );

      // Inilah satu-satunya keterangan di daftar yang membedakan "pengumuman"
      // dari "seluruh pelanggan tidak bisa memakai aplikasinya".
      expect(find.text('Penting'), findsOneWidget);
      expect(find.text('Biasa'), findsOneWidget);
      expect(find.text('Hanya Owner'), findsOneWidget);
    });

    testWidgets('🔴 baris yang mengunci tanpa tautan sah diberi peringatan',
        (tester) async {
      // Formulir menolaknya, tetapi baris lama — atau yang disunting langsung
      // lewat Supabase Dashboard — bisa saja begitu, dan Admin harus dapat
      // melihatnya tanpa membuka formulirnya satu per satu.
      await pasang(
        tester,
        _VmPengumuman([
          buat(id: 'buntu', kind: AnnouncementKind.important),
        ]),
      );

      expect(
        find.textContaining('terkunci tanpa satu pun jalan keluar'),
        findsOneWidget,
      );
    });

    testWidgets('sakelar tiap baris mematikan pengumuman tanpa formulir',
        (tester) async {
      // Tombol darurat: kalau tautan aksinya ternyata salah, inilah
      // satu-satunya cara melepaskan pengguna yang sedang terkunci.
      final vm = _VmPengumuman([buat(id: 'update')]);
      await pasang(tester, vm);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(vm.diubahAktif, [false]);
    });
  });

  group('Formulir', () {
    Future<void> bukaForm(WidgetTester tester, _VmPengumuman vm) async {
      await pasang(tester, vm);
      await tester.tap(find.text('Tambah pengumuman').last);
      await tester.pumpAndSettle();
    }

    testWidgets('judul kosong ditolak', (tester) async {
      final vm = _VmPengumuman(const []);
      await bukaForm(tester, vm);

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Judul wajib diisi.'), findsOneWidget);
      expect(vm.disimpan, isEmpty);
    });

    testWidgets('🔴 penting tanpa tautan DITOLAK', (tester) async {
      final vm = _VmPengumuman(const []);
      await bukaForm(tester, vm);

      await tester.enterText(find.byType(TextField).first, 'Versi baru');
      await tester.tap(find.text('Penting'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('terkunci tanpa satu pun jalan keluar'),
        findsOneWidget,
      );
      // Yang paling penting: tidak ada apa pun yang sampai ke server.
      expect(vm.disimpan, isEmpty);
    });

    testWidgets('penting dengan tautan sah diterima', (tester) async {
      final vm = _VmPengumuman(const []);
      await bukaForm(tester, vm);

      final kolom = find.byType(TextField);
      await tester.enterText(kolom.at(0), 'Versi baru');
      await tester.tap(find.text('Penting'));
      await tester.pumpAndSettle();
      await tester.enterText(
        kolom.at(2),
        'https://play.google.com/store/apps/details?id=x',
      );

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(vm.disimpan, hasLength(1));
      expect(vm.disimpan.single.kind, AnnouncementKind.important);
      expect(vm.disimpan.single.title, 'Versi baru');
    });

    testWidgets('pengumuman biasa tanpa tautan tetap boleh disimpan',
        (tester) async {
      // Pengumuman event tidak wajib punya tombol — ia dapat ditutup dengan
      // tanda silang, jadi tidak ada yang terkurung.
      final vm = _VmPengumuman(const []);
      await bukaForm(tester, vm);

      await tester.enterText(find.byType(TextField).first, 'Event akhir bulan');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(vm.disimpan, hasLength(1));
      expect(vm.disimpan.single.kind, AnnouncementKind.normal);
    });

    testWidgets('sasaran dapat dipilih per peran', (tester) async {
      final vm = _VmPengumuman(const []);
      await bukaForm(tester, vm);

      await tester.enterText(find.byType(TextField).first, 'Untuk packer');
      await tester.tap(find.text('Semua pengguna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hanya Packer').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(vm.disimpan.single.audience, AnnouncementAudience.packer);
    });
  });
}

class _VmPengumuman extends AdminAnnouncementsViewModel {
  _VmPengumuman(this._isi);

  final List<Announcement> _isi;
  final List<Announcement> disimpan = [];
  final List<bool> diubahAktif = [];

  @override
  Future<List<Announcement>> build() async => _isi;

  @override
  Future<AppFailure?> simpan(Announcement a, {Uint8List? gambar}) async {
    disimpan.add(a);
    return null;
  }

  @override
  Future<AppFailure?> setActive(Announcement a, bool active) async {
    diubahAktif.add(active);
    return null;
  }

  @override
  Future<void> refresh() async {}
}
