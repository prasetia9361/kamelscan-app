import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/recording_machine.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/shop.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_text_styles_display.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../main.dart' show reportCameraCapabilities;
import '../../../navigation/route_names.dart';
import '../../history/widgets/marketplace_badge.dart';
import 'recording_setup_view_model.dart';

/// Layar setup perekaman (Bab 8.2).
///
/// Tiga pilihan: kamera, mode pemicu, toko. Tombol Mulai aktif hanya bila
/// ketiganya terisi **dan** saldo token > 0.
class RecordingSetupPage extends ConsumerWidget {
  const RecordingSetupPage({super.key, required this.typeWire});

  /// Pilihan awal Packing/Return, dibawa dari menu Beranda (Bab 9.2).
  final String typeWire;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(recordingSetupViewModelProvider(typeWire));

    return Scaffold(
      appBar: AppBar(
        // Judulnya menyatakan jenis yang sedang berlaku — "Perekaman packing"
        // atau "Perekaman return" (`arahan.json`, 18 Agustus 2026). Karena
        // pilihannya sudah tidak ada di layar ini, judul inilah satu-satunya
        // yang memberi tahu packer bahwa menu tadi memang berlaku.
        title: Text(
          VideoType.fromWire(typeWire) == VideoType.returned
              ? t.recordSetupTitleReturn
              : t.recordSetupTitlePacking,
        ),
        actions: [
          // ⚠️ Alat verifikasi sementara (Bab 8.1). Membuktikan perangkat
          // sanggup menjalankan pratinjau + rekam + analisis frame sekaligus —
          // syarat mutlak aturan pindai-untuk-berhenti. Hapus setelah
          // terverifikasi di beberapa perangkat.
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.biotech_outlined),
              tooltip: 'Uji kemampuan kamera',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(
                  duration: Duration(seconds: 30),
                  content: Text(
                    'ARAHKAN KAMERA KE QR/BARCODE dan tahan ± 30 detik. '
                    'Layar tidak berubah — hasilnya masuk ke log.',
                  ),
                ));
                await reportCameraCapabilities();
                messenger.showSnackBar(const SnackBar(
                  content: Text('Selesai. Hasil ada di log (KAMELSCAN_CAMERA_CHECK).'),
                ));
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorView(
          failure: e,
          onRetry: () =>
              ref.invalidate(recordingSetupViewModelProvider(typeWire)),
        ),
        data: (data) => _SetupBody(data: data, typeWire: typeWire),
      ),
    );
  }
}

class _SetupBody extends ConsumerWidget {
  const _SetupBody({required this.data, required this.typeWire});

  final RecordingSetupData data;
  final String typeWire;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final vm = ref.read(recordingSetupViewModelProvider(typeWire).notifier);
    final setup = data.setup;

    // Tanpa toko sama sekali, tidak ada yang bisa dipilih. Menampilkan daftar
    // kosong lalu tombol mati akan membuat pengguna menebak-nebak.
    if (data.shops.isEmpty) {
      return AppEmptyState(
        icon: Icons.storefront_outlined,
        title: t.recordNoShopTitle,
        message: t.recordNoShopBody,
        actionLabel: t.recordNoShopAction,
        onAction: () => context.push(Routes.shopForm),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              // 🔴 TIDAK ADA pemilih jenis paket di sini — keputusan Product
              // Owner 18 Agustus 2026 (`arahan.json`).
              //
              // Jenis ditentukan sepenuhnya oleh menu yang ditekan di Beranda,
              // dan layar ini hanya menyatakannya kembali lewat judulnya.
              // Menyediakan pilihan kedua di sini berarti dua sumber kebenaran
              // untuk satu hal: packer yang menekan "Rekam Paket Return" lalu
              // menemukan chip Packing masih dapat dipilih akan wajar mengira
              // menu tadi belum berlaku.
              // Chip penanda jenis — **tidak dapat ditekan**, dan itu
              // disengaja. Ia mengulang apa yang sudah dikatakan judul AppBar
              // supaya jenisnya terlihat tanpa menengadah ke bilah atas, tetapi
              // tetap bukan pilihan kedua (lihat catatan di bawah).
              _TypeMarker(type: VideoType.fromWire(typeWire)),
              const SizedBox(height: 18),
              _Section(
                number: 1,
                title: t.recordPickCamera,
                child: _CameraPicker(
                  cameras: data.cameras,
                  selected: setup.cameraId,
                  onSelect: vm.selectCamera,
                ),
              ),
              const SizedBox(height: 18),
              _Section(
                number: 2,
                title: t.recordPickTrigger,
                child: _TriggerPicker(
                  selected: setup.triggerMode,
                  onSelect: vm.selectTriggerMode,
                ),
              ),
              const SizedBox(height: 18),
              _Section(
                number: 3,
                title: t.recordPickShop,
                child: _ShopPicker(
                  shops: data.shops,
                  selected: setup.shopId,
                  onSelect: vm.selectShop,
                ),
              ),
            ],
          ),
        ),
        _StartBar(setup: setup, shops: data.shops),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '$number',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CameraPicker extends StatelessWidget {
  const _CameraPicker({
    required this.cameras,
    required this.selected,
    required this.onSelect,
  });

  final List<CameraDescription> cameras;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    if (cameras.isEmpty) {
      return _Notice(icon: Icons.no_photography_outlined, text: t.recordNoCamera);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cam in cameras)
          ChoiceChip(
            label: Text(_label(context, cam)),
            selected: selected == cam.name,
            onSelected: (_) => onSelect(cam.name),
          ),
      ],
    );
  }

  String _label(BuildContext context, CameraDescription cam) {
    final t = context.l10n;
    return switch (cam.lensDirection) {
      CameraLensDirection.back => t.cameraBack,
      CameraLensDirection.front => t.cameraFront,
      CameraLensDirection.external => t.cameraExternal,
    };
  }
}

class _TriggerPicker extends StatelessWidget {
  const _TriggerPicker({required this.selected, required this.onSelect});

  final TriggerMode? selected;
  final ValueChanged<TriggerMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Column(
      children: [
        for (final mode in TriggerMode.values)
          _TriggerTile(
            mode: mode,
            selected: selected == mode,
            onTap: () => onSelect(mode),
          ),
        // Bab 8.2 — scanner Bluetooth ditampilkan nonaktif dengan label
        // "Segera hadir", supaya pengguna tahu itu direncanakan dan tidak
        // mengira aplikasinya tidak mendukung.
        Opacity(
          opacity: 0.5,
          child: ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(t.triggerBluetooth),
            subtitle: Text(t.commonComingSoon),
            enabled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _TriggerTile extends StatelessWidget {
  const _TriggerTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TriggerMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, String title, String subtitle) = switch (mode) {
      TriggerMode.qrCode => (Icons.qr_code_2, t.triggerQr, t.triggerQrHint),
      TriggerMode.barcode1d => (Icons.barcode_reader, t.triggerBarcode, t.triggerBarcodeHint),
      TriggerMode.manual => (Icons.keyboard_alt_outlined, t.triggerManual, t.triggerManualHint),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        // Terpilih dibedakan bentuk **dan** warna (§0 palet): garis tepi primer
        // ditambah tanda centang, bukan hanya latar yang berubah.
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        leading: Icon(icon,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Penanda jenis paket — **bukan pemilih**.
///
/// 🔴 TIDAK ADA pemilih jenis di layar ini (keputusan Product Owner
/// 18 Agustus 2026). Chip ini sengaja tanpa `onTap`: ia menyatakan jenis yang
/// sudah ditentukan menu Beranda, bukan menawarkan mengubahnya. Packer yang
/// menekan "Rekam Return" lalu menemukan chip yang dapat ditekan akan wajar
/// mengira pilihannya belum berlaku.
class _TypeMarker extends StatelessWidget {
  const _TypeMarker({required this.type});

  final VideoType type;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final packing = type == VideoType.packing;

    final (bg, fg, icon, label) = packing
        ? (
            colors.packingContainer,
            colors.onPackingContainer,
            Icons.inventory_2_outlined,
            t.videoTypePacking,
          )
        : (
            colors.returnContainer,
            colors.onReturnContainer,
            Icons.move_to_inbox_outlined,
            t.videoTypeReturn,
          );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // §0 palet — warna tidak pernah jadi satu-satunya pembeda makna;
            // chip ini selalu memuat ikon dan tulisannya.
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: AppDisplayStyles.kicker
                  .copyWith(fontSize: 9.5, letterSpacing: 1.4, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih toko — **satu baris yang digulir mendatar**.
///
/// 🔴 Keputusan Product Owner 3 September 2026, menggantikan grid 3 kolom.
///
/// Alasannya bukan gaya: layar ini punya tiga bagian di atas tombol Mulai.
/// Grid 3 kolom memang lebih hemat daripada daftar vertikal, tetapi ia tetap
/// **tumbuh ke bawah** — enam toko menjadi dua baris, sembilan menjadi tiga,
/// dan setiap baris tambahan mendorong tombol Mulai makin jauh dari jempol.
/// Baris mendatar tingginya tetap 92 dp berapa pun jumlah tokonya.
///
/// ⚠️ Lebar petak 128 dp dipilih supaya pada layar 402 dp petak ketiga
/// **terpotong sedikit**, bukan pas di tepi. Baris yang berhenti rapi di tepi
/// layar terbaca seperti daftar yang sudah habis, dan toko keempat tidak akan
/// pernah dicari orang. Potongan itu satu-satunya tanda bahwa barisnya masih
/// berlanjut.
///
/// Logo marketplace memakai [MarketplaceBadge] yang sama dengan Riwayat dan
/// daftar Toko — menyalinnya ke sini berarti warna dan bentuknya perlahan
/// menyimpang di antara layar.
class _ShopPicker extends StatefulWidget {
  const _ShopPicker({
    required this.shops,
    required this.selected,
    required this.onSelect,
  });

  final List<Shop> shops;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<_ShopPicker> createState() => _ShopPickerState();
}

class _ShopPickerState extends State<_ShopPicker> {
  /// Lebar satu petak beserta jaraknya ke petak berikutnya.
  static const double _lebarPetak = 128;
  static const double _jarak = 8;

  /// Sisa ruang yang sengaja disisakan di kiri petak terpilih.
  ///
  /// Tanpa ini petak terpilih menempel persis di tepi kiri, dan barisnya
  /// terbaca seolah tidak ada apa-apa lagi sebelumnya. Potongan petak
  /// sebelumnya adalah satu-satunya tanda bahwa daftarnya masih berlanjut ke
  /// kiri — alasan yang sama dengan potongan di tepi kanan.
  static const double _intip = 44;

  late final ScrollController _gulir =
      ScrollController(initialScrollOffset: _offsetAwal());

  /// Posisi gulir awal supaya toko yang SUDAH TERPILIH terlihat.
  ///
  /// 🔴 Ini menutup cacat yang lahir 3 September 2026 bersama perubahan grid
  /// menjadi baris mendatar, dan tidak tertangkap satu pun tes.
  ///
  /// `RecordingSetupViewModel` memilih toko terakhir dari `prefLastShopId`.
  /// Saat pemilihnya masih grid, seluruh toko selalu terlihat sehingga
  /// pilihan itu mustahil tersembunyi. Pada baris mendatar hanya sekitar tiga
  /// petak yang muat di layar 402 dp — tenant dengan empat toko atau lebih
  /// membuka layar ini dengan **pilihannya berada di luar pandangan**.
  ///
  /// Yang dilihat packer: tiga petak tanpa satu pun tertandai, sementara
  /// tombol Mulai sudah menyala. Di layar yang gunanya menetapkan nama toko
  /// yang **terbakar ke dalam video bukti**, pilihan yang tidak terlihat
  /// bukan sekadar kurang rapi.
  ///
  /// ⚠️ Dihitung sekali saat controller lahir, BUKAN digulirkan ulang tiap
  /// kali pilihannya berubah. Menggulir sendiri saat packer baru saja
  /// mengetuk sebuah petak akan memindahkan barisnya di bawah jarinya.
  double _offsetAwal() {
    final i = widget.shops.indexWhere((s) => s.id == widget.selected);
    if (i <= 0) return 0;

    final offset = (i * (_lebarPetak + _jarak)) - _intip;
    // Negatif mustahil di sini (i >= 1), tetapi dijaga supaya perubahan angka
    // di atas tidak diam-diam menghasilkan offset tak sah.
    return offset < 0 ? 0 : offset;
  }

  @override
  void dispose() {
    _gulir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tinggi ditetapkan dari luar, bukan diukur dari isinya: bagian ini
    // berdiri di dalam `ListView`, dan di dalam gulir tinggi yang tersedia
    // tak terhingga — mengukurnya di sana melempar galat tata letak.
    return SizedBox(
      height: 92,
      child: ListView.separated(
        controller: _gulir,
        scrollDirection: Axis.horizontal,
        itemCount: widget.shops.length,
        separatorBuilder: (_, _) => const SizedBox(width: _jarak),
        itemBuilder: (context, i) {
          final shop = widget.shops[i];
          return SizedBox(
            width: _lebarPetak,
            child: _ShopTile(
              shop: shop,
              selected: widget.selected == shop.id,
              onTap: () => widget.onSelect(shop.id),
            ),
          );
        },
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.shop,
    required this.selected,
    required this.onTap,
  });

  final Shop shop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            // Terpilih dibedakan bentuk **dan** warna: garis tepi primer di
            // atas latar container, bukan warna latar saja.
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketplaceBadge(marketName: shop.marketName, size: 26),
              const SizedBox(height: 6),
              Text(
                shop.marketName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDisplayStyles.metaMono.copyWith(
                  fontSize: 8.5,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                shop.shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol Mulai beserta alasannya bila masih mati.
///
/// Bab 9.10 melarang tombol abu-abu tanpa penjelasan — pengguna harus tahu apa
/// yang kurang, bukan menebak.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.setup, required this.shops});

  final RecordingSetup setup;

  /// Dibawa hanya untuk mengambil **nama** toko yang dipilih: watermark
  /// memerlukannya, dan di gudang tanpa sinyal nama itu tidak dapat ditanyakan
  /// lagi ke server saat videonya diproses (Bab 8.5).
  final List<Shop> shops;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final reason = setup.blockedReasonKey;
    final canStart = setup.canStart;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.messageForKey(reason),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: AppSizes.touchComfort,
              child: FilledButton.icon(
                onPressed: canStart
                    ? () => context.push(
                          Routes.recordCameraOf(
                            // Ketiganya sudah dipastikan terisi oleh
                            // `RecordingSetup.canStart`.
                            cameraName: setup.cameraId!,
                            triggerWire: setup.triggerMode!.wire,
                            shopId: setup.shopId!,
                            typeWire: setup.type.wire,
                            // "Shopee · Toko Kamel" — Bab 8.5 menampilkan
                            // marketplace beserta nama tokonya di watermark.
                            shopName: shops
                                    .where((s) => s.id == setup.shopId)
                                    .map((s) => s.displayName)
                                    .firstOrNull ??
                                '',
                          ),
                        )
                    : null,
                icon: const Icon(Icons.videocam),
                label: Text(t.recordStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
