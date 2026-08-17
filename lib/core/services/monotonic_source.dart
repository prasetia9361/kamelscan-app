// ⚠️ Bab 4.3 — pembacaan `/proc` memakai `dart:io` yang tidak ada di Web.
// Web tidak merekam, jadi di sana penghitungnya cukup seumur proses.
import 'monotonic_source_stub.dart'
    if (dart.library.io) 'monotonic_source_mobile.dart';

/// Satu bacaan penghitung waktu yang **tidak dapat diubah pengguna**.
class MonotonicReading {
  const MonotonicReading({required this.elapsed, required this.sourceId});

  /// Berapa lama berjalan sejak titik nol penghitung (boot, atau mulai proses).
  final Duration elapsed;

  /// Identitas penghitungnya. Berubah = penghitung lama sudah tidak ada, dan
  /// titik acuan yang mengacu padanya wajib dianggap gugur.
  final String sourceId;
}

/// Penghitung waktu berjalan yang tidak bergantung pada jam HP.
///
/// 🔴 Alasan keberadaannya ada di [TimeSync]: waktu di watermark tidak boleh
/// bergeser hanya karena seseorang mengubah jam perangkat.
abstract interface class MonotonicSource {
  Future<MonotonicReading> read();

  /// Untuk dilaporkan ke log saat menguji di perangkat baru — penghitung mana
  /// yang benar-benar dipakai di sana.
  String get describe;
}

MonotonicSource createMonotonicSource() => createPlatformMonotonicSource();
