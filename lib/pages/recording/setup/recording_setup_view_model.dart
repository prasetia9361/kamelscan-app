import 'package:camera/camera.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/domain/recording_machine.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/shop.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';

part 'recording_setup_view_model.g.dart';

/// Isi layar setup perekaman (Bab 8.2).
class RecordingSetupData {
  const RecordingSetupData({
    required this.cameras,
    required this.shops,
    required this.setup,
    this.loading = false,
  });

  final List<CameraDescription> cameras;
  final List<Shop> shops;
  final RecordingSetup setup;
  final bool loading;

  RecordingSetupData copyWith({
    List<CameraDescription>? cameras,
    List<Shop>? shops,
    RecordingSetup? setup,
    bool? loading,
  }) =>
      RecordingSetupData(
        cameras: cameras ?? this.cameras,
        shops: shops ?? this.shops,
        setup: setup ?? this.setup,
        loading: loading ?? this.loading,
      );
}

/// Bab 8.2 — tiga pilihan: kamera, mode pemicu, toko.
///
/// Pilihan terakhir disimpan di `SharedPreferences`. Alasannya bukan sekadar
/// kenyamanan: satu toko biasanya memakai satu marketplace dengan format resi
/// yang sama setiap hari, sehingga menanyakan ulang tiap kali hanya menambah
/// tiga ketukan pada pekerjaan yang diulang ratusan kali sehari.
@riverpod
class RecordingSetupViewModel extends _$RecordingSetupViewModel {
  @override
  Future<RecordingSetupData> build() async {
    final session = ref.watch(sessionProvider).value;
    final prefs = await SharedPreferences.getInstance();

    final cameras = await _cameras();

    // Packer hanya melihat toko yang ditugaskan kepadanya (Bab 8.2). Filter
    // sesungguhnya ada di RLS; di sini hanya menampilkan apa yang boleh dilihat.
    final shops = (await ref
            .read(shopRepositoryProvider)
            .fetchShops(activeOnly: true))
        .getOrElse((_) => const []);

    final savedShop = prefs.getString(AppConstants.prefLastShopId);
    final savedMode = prefs.getString(AppConstants.prefTriggerMode);

    return RecordingSetupData(
      cameras: cameras,
      shops: shops,
      setup: RecordingSetup(
        // Kamera belakang lebih masuk akal untuk merekam paket di meja.
        cameraId: _defaultCamera(cameras)?.name,
        triggerMode:
            savedMode == null ? TriggerMode.qrCode : TriggerMode.fromWire(savedMode),
        // Toko tersimpan hanya dipakai bila masih ada dan masih aktif —
        // toko yang sudah dinonaktifkan Owner tidak boleh terpilih diam-diam.
        shopId: shops.any((s) => s.id == savedShop)
            ? savedShop
            : (shops.length == 1 ? shops.first.id : null),
        hasTokens: !(session?.quota.isExhausted ?? true),
      ),
    );
  }

  Future<List<CameraDescription>> _cameras() async {
    try {
      return await availableCameras();
    } on CameraException {
      // Perangkat tanpa kamera, atau izin belum diberikan. Layar menampilkan
      // daftar kosong beserta alasannya, bukan mogok.
      return const [];
    }
  }

  CameraDescription? _defaultCamera(List<CameraDescription> cameras) {
    if (cameras.isEmpty) return null;
    return cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  void selectCamera(String cameraId) => _update((s) => s.copyWith(cameraId: cameraId));

  Future<void> selectTriggerMode(TriggerMode mode) async {
    _update((s) => s.copyWith(triggerMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefTriggerMode, mode.wire);
  }

  Future<void> selectShop(String shopId) async {
    _update((s) => s.copyWith(shopId: shopId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLastShopId, shopId);
  }

  void _update(RecordingSetup Function(RecordingSetup) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(setup: change(current.setup)));
  }
}
