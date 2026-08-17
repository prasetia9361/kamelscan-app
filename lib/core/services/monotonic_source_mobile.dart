import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';
import 'monotonic_source.dart';

/// Penghitung waktu berjalan di Android/iOS.
///
/// Dua tingkat, dicoba berurutan:
///
/// **1. Sejak HP menyala** (Android). `SystemClock.elapsedRealtime()` lewat
/// [MethodChannel] ke `MainActivity`, dipasangkan dengan
/// `/proc/sys/kernel/random/boot_id` sebagai penanda identitas.
///
/// 🔴 Keduanya dipakai bersama, dan itu disengaja. Penghitung sejak-boot
/// sendirian kembali ke nol setiap HP dinyalakan ulang. Bila kebetulan HP sudah
/// menyala lebih lama daripada bacaan yang tersimpan, titik acuan lama akan
/// tampak masih sah padahal melesetnya berjam-jam **tanpa gejala apa pun**.
/// `boot_id` berganti tiap boot, sehingga kekeliruan itu mustahil.
///
/// **2. Sejak aplikasi dibuka** (cadangan; iOS, dan Android yang saluran
/// nativenya tidak menjawab). [Stopwatch] Dart memakai jam monotonic sistem,
/// jadi sama-sama kebal terhadap perubahan jam HP — hanya saja titik nolnya
/// hilang begitu aplikasi ditutup. Konsekuensinya jujur dan disengaja:
/// aplikasi yang dibuka ulang tanpa sinyal akan menandai videonya *"waktu
/// belum terverifikasi"* alih-alih diam-diam mengurangi jam HP.
///
/// ### Kenapa tidak membaca `/proc/uptime` saja
///
/// Sudah dicoba, dan **gagal di perangkat uji**. Redmi Note 9 (MIUI,
/// 17 Agustus 2026) memasang `/proc` dengan `hidepid=2`:
///
/// ```
/// $ run-as id.kamelscan.app cat /proc/uptime
/// cat: /proc/uptime: Permission denied
/// $ run-as id.kamelscan.app cat /proc/sys/kernel/random/boot_id
/// e1dfb6e7-a33b-412c-861a-6c88dfeea1c1
/// ```
///
/// Hanya `boot_id` yang lolos, dan itulah sebabnya ia tetap dipakai sementara
/// angka waktunya datang dari saluran native.
///
/// ⚠️ **Yang mana yang berlaku di perangkat wajib dibaca, bukan diasumsikan.**
/// [describe] dicetak lewat `debugPrint` supaya terbaca dari logcat —
/// `AppLogger` tidak pernah sampai ke sana (jebakan 11 di
/// `PROMPT_SESI_BARU.md`):
///
/// ```
/// adb logcat -v time | findstr KAMELSCAN_WAKTU
/// ```
class DeviceMonotonicSource implements MonotonicSource {
  DeviceMonotonicSource();

  static const AppLogger _log = AppLogger('MonotonicSource');

  static const MethodChannel _channel =
      MethodChannel('id.kamelscan.app/monotonic');

  static final Stopwatch _sinceAppStart = Stopwatch()..start();

  /// Id proses yang berlaku selama aplikasi hidup. Diberi cap waktu agar dua
  /// kali menjalankan aplikasi tidak pernah menghasilkan id yang sama.
  static final String _processId =
      'process:${DateTime.now().microsecondsSinceEpoch}';

  static const String _bootIdPath = '/proc/sys/kernel/random/boot_id';

  /// `null` = belum diperiksa, `''` = sudah diperiksa dan tidak tersedia.
  static String? _bootId;
  static bool? _nativeAvailable;

  @override
  Future<MonotonicReading> read() async {
    final bootId = await _readBootId();
    if (bootId.isNotEmpty) {
      final elapsed = await _elapsedRealtime();
      if (elapsed != null) {
        return MonotonicReading(elapsed: elapsed, sourceId: 'boot:$bootId');
      }
    }
    return MonotonicReading(
      elapsed: _sinceAppStart.elapsed,
      sourceId: _processId,
    );
  }

  @override
  String get describe => switch ((_bootId, _nativeAvailable)) {
        (null, _) => 'belum diperiksa',
        (_, false) =>
          'sejak aplikasi dibuka (Stopwatch) — saluran native tidak menjawab',
        ('', _) => 'sejak aplikasi dibuka (Stopwatch) — boot_id tidak terbaca',
        (final id, _) => 'sejak HP menyala (elapsedRealtime, boot_id=$id)',
      };

  Future<String> _readBootId() async {
    final cached = _bootId;
    if (cached != null) return cached;

    var value = '';
    try {
      value = (await File(_bootIdPath).readAsString()).trim();
    } on Object catch (e) {
      // Diharapkan di iOS. Bukan kegagalan — hanya turun ke tingkat berikutnya.
      _log.i('boot_id tidak terbaca, memakai penghitung seumur aplikasi: $e');
    }
    _bootId = value;
    return value;
  }

  Future<Duration?> _elapsedRealtime() async {
    if (_nativeAvailable == false) return null;
    try {
      final millis = await _channel.invokeMethod<int>('elapsedRealtime');
      if (millis == null) return null;
      if (_nativeAvailable == null) {
        _nativeAvailable = true;
        debugPrint('KAMELSCAN_WAKTU penghitung: $describe');
      }
      return Duration(milliseconds: millis);
    } on Object catch (e) {
      // Diharapkan di iOS (saluran ini hanya dipasang di MainActivity Android).
      _nativeAvailable = false;
      _log.i('Saluran elapsedRealtime tidak tersedia: $e');
      debugPrint('KAMELSCAN_WAKTU penghitung: $describe');
      return null;
    }
  }
}

MonotonicSource createPlatformMonotonicSource() => DeviceMonotonicSource();
