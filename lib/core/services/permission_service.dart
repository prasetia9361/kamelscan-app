import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

/// Izin perangkat (Bab 8.9).
///
/// 🔴 Aturan paling penting dari Bab 8.9: **tiap izin punya akibat berbeda bila
/// ditolak.** Memperlakukan semuanya sama — misalnya memblokir perekaman
/// karena lokasi ditolak — akan membuat produk tidak dapat dipakai di gudang
/// tanpa sinyal GPS, padahal Bab 1.3 poin 6 justru menyatakan video tanpa
/// koordinat tetap sah sebagai bukti.
///
/// | Izin | Bila ditolak |
/// |---|---|
/// | Kamera | perekaman diblokir |
/// | Mikrofon | tetap merekam, tanpa audio |
/// | Lokasi | tetap merekam, watermark "Lokasi tidak tersedia" |
/// | Notifikasi | upload tetap jalan, tanpa notifikasi |
/// | Penyimpanan | hanya unduhan yang diblokir |
///
/// Bab 8.9 juga menegaskan: minta izin **saat pertama kali dibutuhkan**, bukan
/// seluruhnya saat aplikasi dibuka.
enum AppPermission {
  camera,
  microphone,
  location,
  notification,
  storage;

  /// Apakah penolakan izin ini menghentikan perekaman sama sekali.
  bool get blocksRecording => this == AppPermission.camera;

  /// Kunci l10n untuk penjelasan yang ditampilkan SEBELUM dialog sistem.
  String get rationaleKey => switch (this) {
        AppPermission.camera => 'permissionCameraRationale',
        AppPermission.microphone => 'permissionMicrophoneRationale',
        AppPermission.location => 'permissionLocationRationale',
        AppPermission.notification => 'permissionNotificationRationale',
        AppPermission.storage => 'permissionStorageRationale',
      };

  /// Kunci l10n untuk pesan setelah ditolak.
  String get deniedKey => switch (this) {
        AppPermission.camera => 'permissionCameraDenied',
        AppPermission.microphone => 'permissionMicrophoneDenied',
        AppPermission.location => 'permissionLocationDenied',
        AppPermission.notification => 'permissionNotificationDenied',
        AppPermission.storage => 'permissionStorageDenied',
      };
}

/// Hasil permintaan izin.
enum PermissionOutcome {
  granted,

  /// Ditolak, tetapi masih boleh diminta lagi nanti.
  denied,

  /// Ditolak permanen — dialog sistem tidak akan muncul lagi. Satu-satunya
  /// jalan adalah membuka Pengaturan aplikasi.
  permanentlyDenied;

  bool get isGranted => this == PermissionOutcome.granted;

  /// Hanya kondisi ini yang layak menampilkan tombol *Buka Pengaturan*.
  /// Menampilkannya pada penolakan biasa membingungkan — pengguna dikirim ke
  /// Pengaturan padahal cukup menekan "Izinkan" pada percobaan berikutnya.
  bool get needsSettings => this == PermissionOutcome.permanentlyDenied;
}

class PermissionService {
  const PermissionService();

  static const AppLogger _log = AppLogger('Permission');

  Permission _map(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
        // `locationWhenInUse`, bukan `location`: KamelScan tidak pernah
        // membutuhkan lokasi saat aplikasi tertutup, dan meminta izin latar
        // belakang akan memicu peninjauan tambahan di Play Store.
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.notification => Permission.notification,
        AppPermission.storage => Permission.photos,
      };

  Future<PermissionOutcome> status(AppPermission p) async =>
      _outcome(await _map(p).status);

  Future<bool> isGranted(AppPermission p) async =>
      (await status(p)).isGranted;

  /// Minta satu izin. Panggil tepat sebelum fiturnya dipakai (Bab 8.9).
  Future<PermissionOutcome> request(AppPermission p) async {
    try {
      final current = await _map(p).status;
      if (current.isGranted) return PermissionOutcome.granted;

      // Sudah ditolak permanen — meminta lagi tidak memunculkan dialog apa pun
      // dan hanya membuat pengguna mengira aplikasinya rusak.
      if (current.isPermanentlyDenied) {
        return PermissionOutcome.permanentlyDenied;
      }

      return _outcome(await _map(p).request());
    } on Object catch (e) {
      _log.w('Permintaan izin ${p.name} gagal', e);
      return PermissionOutcome.denied;
    }
  }

  /// Izin untuk mulai merekam.
  ///
  /// Kamera wajib; mikrofon **tidak**. Bab 8.9: bila mikrofon ditolak,
  /// perekaman tetap berjalan tanpa audio disertai peringatan — video bisu
  /// jauh lebih baik daripada tidak ada bukti sama sekali.
  Future<RecordingPermissions> requestForRecording() async {
    final camera = await request(AppPermission.camera);
    if (!camera.isGranted) {
      return RecordingPermissions(camera: camera, microphone: null, location: null);
    }

    final mic = await request(AppPermission.microphone);

    // Lokasi diminta terakhir dan kegagalannya tidak pernah menghalangi.
    final loc = await request(AppPermission.location);

    return RecordingPermissions(camera: camera, microphone: mic, location: loc);
  }

  /// Buka halaman Pengaturan aplikasi. Hanya dipanggil saat
  /// [PermissionOutcome.permanentlyDenied].
  Future<bool> openSettings() => openAppSettings();

  PermissionOutcome _outcome(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return PermissionOutcome.granted;
    }
    if (s.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }
}

/// Ringkasan izin yang relevan untuk satu sesi perekaman.
class RecordingPermissions {
  const RecordingPermissions({
    required this.camera,
    required this.microphone,
    required this.location,
  });

  final PermissionOutcome camera;
  final PermissionOutcome? microphone;
  final PermissionOutcome? location;

  /// Satu-satunya syarat mutlak.
  bool get canRecord => camera.isGranted;

  /// Bab 8.9 — rekam tanpa audio bila mikrofon ditolak.
  bool get withAudio => microphone?.isGranted ?? false;

  /// Bab 1.3 poin 6 — video tanpa koordinat tetap sah sebagai bukti.
  bool get withLocation => location?.isGranted ?? false;

  /// Peringatan yang perlu ditampilkan meski perekaman tetap berjalan.
  List<String> get warningKeys => [
        if (!withAudio) AppPermission.microphone.deniedKey,
        if (!withLocation) AppPermission.location.deniedKey,
      ];
}
