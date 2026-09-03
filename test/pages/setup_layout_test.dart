import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/shop.dart';
import 'package:kamelscan/core/theme/app_theme.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/history/widgets/marketplace_badge.dart';

/// Petak toko di layar Setup — **satu baris yang digulir mendatar**.
///
/// Keputusan Product Owner 3 September 2026, menggantikan grid 3 kolom yang
/// dipakai sejak revisi tampilan 1 September.
///
/// 🔴 Yang dijaga tes ini tetap sama, dan ia bukan "petaknya rapi": layar
/// Setup punya tiga bagian bernomor di atas tombol **Mulai Rekam** yang
/// dipatok di dasar. Susunan yang tumbuh ke bawah mendorong tombol itu keluar
/// layar begitu tokonya bertambah — dan tombol yang tidak terlihat adalah alur
/// perekaman yang buntu. Baris mendatar tingginya tetap 92 dp berapa pun
/// jumlah tokonya, jadi tombolnya tidak dapat terdorong sama sekali.
///
/// ⚠️ Tes di bawah menguji **enam** toko, bukan satu: satu toko selalu muat,
/// dan cacatnya justru muncul saat tokonya banyak.
void main() {
  Shop toko(String id, String market, String nama) => Shop(
        id: id,
        tenantId: 't1',
        marketName: market,
        shopName: nama,
        isActive: true,
      );

  Future<void> pasang(
    WidgetTester tester,
    List<Shop> shops, {
    String? terpilih,
  }) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Bentuk yang sama seperti di `RecordingSetupPage`: gulir
                    // mendatar bersarang di dalam gulir tegak — susunan yang
                    // paling mudah membuat galat tata letak, dan karena itu
                    // justru yang harus diuji.
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shops.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => SizedBox(
                          width: 128,
                          child: _Petak(
                            shop: shops[i],
                            selected: shops[i].id == terpilih,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('SESUDAHNYA'),
                  ],
                ),
              ),
              FilledButton(onPressed: () {}, child: const Text('Mulai Rekam')),
            ],
          ),
        ),
      ),
    );
  }

  final enam = [
    toko('1', 'Shopee', 'Sugeh kabeh'),
    toko('2', 'Tokopedia', 'Sarung Kajine'),
    toko('3', 'TikTok Shop', 'kangsarung'),
    toko('4', 'Lazada', 'Kamel Store'),
    toko('5', 'Blibli', 'Kamel Official'),
    toko('6', 'Lainnya', 'Toko Offline'),
  ];

  testWidgets('enam toko — tergambar tanpa galat tata letak', (tester) async {
    await pasang(tester, enam);
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 tombol Mulai Rekam tetap terlihat pada enam toko',
      (tester) async {
    await pasang(tester, enam);

    // Inti tesnya: bukan "gridnya rapi", melainkan alur perekaman tidak buntu.
    expect(find.text('Mulai Rekam'), findsOneWidget);
    expect(find.text('SESUDAHNYA'), findsOneWidget);
  });

  testWidgets(
      '🔴 satu baris mendatar — enam toko TIDAK turun ke baris kedua',
      (tester) async {
    await pasang(tester, enam);

    // Yang diperiksa hanya petak yang sudah tergambar: `ListView` mendatar
    // sengaja tidak membangun yang jauh di luar layar, dan itu justru
    // perilaku yang diinginkan — tiga toko atau tiga puluh, tingginya sama.
    final petak = find.byType(MarketplaceBadge);
    expect(tester.widgetList(petak).length, greaterThanOrEqualTo(3));

    final p1 = tester.getTopLeft(petak.at(0));
    final p2 = tester.getTopLeft(petak.at(1));
    final p3 = tester.getTopLeft(petak.at(2));

    expect(p2.dy, p1.dy, reason: 'petak kedua wajib sebaris dengan pertama');
    expect(p3.dy, p1.dy, reason: 'petak ketiga wajib sebaris dengan pertama');
    expect(p2.dx, greaterThan(p1.dx),
        reason: 'susunannya ke kanan, bukan turun');
    expect(p3.dx, greaterThan(p2.dx));
  });

  testWidgets('🔴 barisnya dapat digulir — toko keempat dapat dicapai',
      (tester) async {
    await pasang(tester, enam);

    // Baris yang tidak dapat digulir menyembunyikan toko keempat selamanya,
    // dan tidak ada satu pun galat yang menandainya.
    final sebelum = tester.getTopLeft(find.byType(MarketplaceBadge).at(0)).dx;
    await tester.drag(
        find.byType(MarketplaceBadge).at(0), const Offset(-160, 0));
    await tester.pumpAndSettle();
    final sesudah = tester.getTopLeft(find.byType(MarketplaceBadge).at(0)).dx;

    expect(sesudah, lessThan(sebelum), reason: 'barisnya wajib dapat digulir');
    expect(tester.takeException(), isNull);
  });

  testWidgets('satu toko pun tidak merusak susunannya', (tester) async {
    await pasang(tester, [enam.first]);

    expect(tester.takeException(), isNull);
    expect(find.text('Mulai Rekam'), findsOneWidget);
  });
}

/// Salinan bentuk petak untuk pengujian tata letak — bukan widget produksi.
class _Petak extends StatelessWidget {
  const _Petak({required this.shop, required this.selected});

  final Shop shop;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketplaceBadge(marketName: shop.marketName, size: 26),
          const SizedBox(height: 6),
          Text(
            shop.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
