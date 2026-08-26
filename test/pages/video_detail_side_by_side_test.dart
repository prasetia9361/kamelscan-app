import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/history_item.dart';
import 'package:kamelscan/core/models/package_video.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/history/detail/video_detail_page.dart';
import 'package:kamelscan/pages/history/detail/video_detail_view_model.dart';
import 'package:kamelscan/pages/web/history/web_history_page.dart';

/// Panel samping berdampingan (Bab 10.5) — pemutar tegak di kiri, keterangan
/// di kanannya.
///
/// 🔴 Bentuknya persis jenis yang sudah DUA KALI meluber di proyek ini: sebuah
/// `Row` berisi anak berlebar tetap dan sebuah `Expanded`, di dalam tema yang
/// tombolnya menuntut lebar tak terhingga (M.12 dan M.17). Karena itu ia
/// dirender sungguhan pada lebar panel yang sebenarnya, memakai `AppTheme`.
void main() {
  HistoryItem contoh({
    String resi = 'JX1234567890ID',
    String? toko = 'Toko Berkah Jaya',
    VideoStatus status = VideoStatus.uploaded,
  }) =>
      HistoryItem(
        video: PackageVideo(
          id: 'v1',
          tenantId: 't1',
          shopId: 's1',
          userId: 'u1',
          resiCode: resi,
          type: VideoType.packing,
          scanDate: DateTime(2026, 8, 26, 14, 32),
          expiresAt: DateTime(2026, 11, 26),
          status: status,
          durationSeconds: 24,
        ),
        shopName: toko,
        marketName: 'Shopee',
        recorderName: 'Budi Santoso',
      );

  Future<void> pasang(
    WidgetTester tester, {
    required HistoryItem item,
    double lebar = WebHistoryPage.panelWidth,
  }) async {
    tester.view.physicalSize = Size(lebar, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDetailViewModelProvider('v1')
              .overrideWith(() => _VmPalsu(VideoDetailData(item: item))),
        ],
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
          home: const SizedBox(
            width: WebHistoryPage.panelWidth,
            child: VideoDetailPage(
              videoId: 'v1',
              embedded: true,
              sideBySide: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Susunan berdampingan', () {
    testWidgets('nomor resi dan keterangan berdiri di sebelah pemutar',
        (tester) async {
      await pasang(tester, item: contoh());

      expect(find.text('JX1234567890ID'), findsWidgets);
      expect(find.text('Toko Berkah Jaya · Shopee'), findsNothing);
      // shopLabel menggabungkan marketplace lebih dulu: "Shopee · Toko ...".
      expect(find.textContaining('Toko Berkah Jaya'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tidak meluber pada lebar panel yang sebenarnya',
        (tester) async {
      await pasang(tester, item: contoh());
      expect(tester.takeException(), isNull);
    });

    testWidgets('resi yang panjang pun tidak merusak susunannya',
        (tester) async {
      // Resi marketplace bisa jauh lebih panjang daripada contoh yang enak
      // dipandang. Yang panjang inilah yang menekan tata letak.
      await pasang(tester, item: contoh(resi: 'SPX09876543210987654321ID'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nama toko yang panjang dipotong, bukan meluber',
        (tester) async {
      await pasang(
        tester,
        item: contoh(toko: 'Toko Serba Ada Berkah Jaya Abadi Sentosa Makmur'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Jalur HP tidak ikut berubah', () {
    testWidgets('tanpa sideBySide, pemutar berdiri sendiri di atas',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoDetailViewModelProvider('v1')
                .overrideWith(() => _VmPalsu(VideoDetailData(item: contoh()))),
          ],
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
            home: const VideoDetailPage(videoId: 'v1'),
          ),
        ),
      );
      await tester.pump();

      // Ringkasan berdampingan TIDAK boleh muncul di HP — bilah judulnya pun
      // harus kembali, karena `embedded` juga false.
      expect(find.text('Detail Rekaman'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _VmPalsu extends VideoDetailViewModel {
  _VmPalsu(this._nilai);

  final VideoDetailData _nilai;

  @override
  Future<VideoDetailData> build(String videoId) async => _nilai;
}
