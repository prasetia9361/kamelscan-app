import 'package:geolocator/geolocator.dart';

import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Koordinat hasil pembacaan GPS.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

/// Pembacaan lokasi untuk watermark video (Bab 0.2 poin 6).
///
/// 🔴 Aturan Bab 1.3 poin 6: **penolakan izin lokasi tidak boleh membatalkan
/// perekaman.** Video tetap direkam, `location_coords` bernilai NULL, dan
/// watermark menampilkan "Lokasi tidak tersedia". Karena itu seluruh metode di
/// sini mengembalikan `null` yang sah, bukan melempar error.
class LocationService {
  const LocationService();

  static const AppLogger _log = AppLogger('LocationService');

  /// Akurasi menengah sudah cukup: bukti sengketa perlu tahu "di gudang mana",
  /// bukan presisi sentimeter. Akurasi tinggi menguras baterai dan memperlambat
  /// mulai rekam.
  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    timeLimit: Duration(seconds: 8),
  );

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Ambil posisi sekarang. Mengembalikan `null` bila izin ditolak, layanan
  /// mati, atau pembacaan melewati batas waktu — semuanya kondisi normal.
  Future<GeoPoint?> currentPosition() async {
    try {
      if (!await isServiceEnabled()) {
        _log.i('Layanan lokasi mati — video direkam tanpa koordinat');
        return null;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.i('Izin lokasi ditolak — video direkam tanpa koordinat');
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(locationSettings: _settings);
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on Object catch (e) {
      _log.w('Pembacaan lokasi gagal', e);
      return null;
    }
  }

  /// Varian yang melaporkan sebab kegagalan — dipakai layar Pengaturan agar
  /// pengguna tahu mengapa koordinat tidak muncul di video mereka.
  Future<Result<GeoPoint>> currentPositionOrFailure() async {
    final point = await currentPosition();
    if (point != null) return Result.ok(point);
    return Result.err(
      AppFailure.devicePermission('permissionLocationDenied'),
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
