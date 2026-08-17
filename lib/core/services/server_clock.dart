import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/time_sync.dart';
import '../utils/logger.dart';
import 'monotonic_source.dart';

/// Waktu yang dipakai watermark video (Bab 8.5).
///
/// Aplikasi ini offline-first, sedangkan Bab 8.5 mensyaratkan **waktu server**.
/// Jalan keluarnya diputuskan Product Owner 16 Agustus 2026 dan aturannya
/// ditulis lengkap di [TimeSync] — berkas ini hanya menjalankan: bertanya ke
/// server saat ada sinyal, menyimpan titik acuannya, dan menjawab pertanyaan
/// "sekarang jam berapa" tanpa mempercayai jam HP.
///
/// 🔴 Tidak ada satu pun perhitungan di sini yang mengurangi jam perangkat.
/// Bila suatu saat tergoda menambahkannya "supaya lebih akurat", baca dulu
/// aturan 2 di [TimeSync].
class ServerClock {
  ServerClock(this._client, {MonotonicSource? monotonic})
      : _monotonic = monotonic ?? createMonotonicSource();

  final SupabaseClient _client;
  final MonotonicSource _monotonic;

  static const AppLogger _log = AppLogger('ServerClock');

  /// Nama fungsi Postgres dari migrasi `19_server_time.sql`.
  static const String _rpcServerNow = 'server_now';
  static const String _prefKey = 'time_anchor';

  TimeAnchor? _anchor;
  bool _anchorLoaded = false;

  /// Waktu untuk dibakar ke watermark, beserta kejujuran tentang asalnya.
  ///
  /// **Tidak pernah gagal dan tidak pernah memblokir perekaman.** Bila belum
  /// pernah sinkron, ia menjawab dengan jam HP dan `verified = false`
  /// (aturan 4) — packer di gudang tanpa sinyal harus tetap bisa bekerja.
  Future<TrustedTime> now() async {
    await _loadAnchor();
    final reading = await _monotonic.read();

    final time = TimeSync.resolve(
      anchor: _anchor,
      monotonicNow: reading.elapsed,
      sourceId: reading.sourceId,
      deviceNow: DateTime.now(),
    );

    if (!time.verified) {
      _log.w('Waktu belum pernah disinkronkan — video ditandai '
          'time_verified=false');
    } else if (time.deviceClockSuspect) {
      // Bab 8.5 aturan 3 — dicatat, tetapi perekaman tetap jalan.
      _log.w('Jam HP meleset ${time.deviceClockSkew.inMinutes} menit dari '
          'waktu server; watermark memakai waktu terkoreksi');
    }
    return time;
  }

  /// Tanyakan waktu server bila memang perlu.
  ///
  /// Dipanggil saat aplikasi dibuka dan tiap kali jaringan kembali tersambung.
  /// Aman dipanggil sesering apa pun: bila titik acuannya masih segar, tidak
  /// ada permintaan jaringan sama sekali.
  Future<bool> ensureSynced({bool force = false}) async {
    await _loadAnchor();
    final reading = await _monotonic.read();

    if (!force &&
        !TimeSync.needsRefresh(
          anchor: _anchor,
          monotonicNow: reading.elapsed,
          sourceId: reading.sourceId,
        )) {
      return true;
    }
    return sync();
  }

  /// Satu kali tanya-jawab ke server.
  ///
  /// Titik acuannya diambil di **tengah** perjalanan bolak-balik, bukan
  /// sesudahnya. Jaringan gudang bisa lambat beberapa detik; menempelkan waktu
  /// server pada bacaan penghitung sesudah jawaban tiba akan membuat seluruh
  /// video tertinggal selama itu.
  Future<bool> sync() async {
    try {
      final before = await _monotonic.read();
      final response = await _client.rpc<Object?>(_rpcServerNow);
      final after = await _monotonic.read();

      final serverTime = _parse(response);
      if (serverTime == null) {
        _log.w('Jawaban $_rpcServerNow tidak dapat dibaca: $response');
        _report('jawaban tidak dapat dibaca: $response');
        return false;
      }
      if (after.sourceId != before.sourceId) {
        _log.w('Penghitung berganti di tengah sinkronisasi — diulang nanti');
        _report('penghitung berganti di tengah sinkronisasi');
        return false;
      }

      final roundTrip = after.elapsed - before.elapsed;
      final anchor = TimeAnchor(
        serverTime: serverTime,
        monotonic: before.elapsed + roundTrip ~/ 2,
        sourceId: after.sourceId,
        deviceTimeAtSync: DateTime.now().toUtc(),
      );

      await _saveAnchor(anchor);

      final skew = anchor.deviceTimeAtSync.difference(serverTime);
      _log.i('Waktu server tersinkron (${roundTrip.inMilliseconds} ms '
          'bolak-balik) · selisih jam HP ${skew.inSeconds} detik · '
          'penghitung: ${_monotonic.describe}');
      debugPrint('KAMELSCAN_WAKTU sinkron · selisih jam HP '
          '${skew.inSeconds} detik · ${_monotonic.describe}');
      return true;
    } on Object catch (e) {
      // Offline adalah keadaan normal di gudang, bukan kesalahan.
      _log.i('Sinkronisasi waktu tidak berhasil, dicoba lagi nanti: $e');
      _report(e.toString());
      return false;
    }
  }

  /// Kegagalan sinkronisasi **wajib** tembus ke logcat.
  ///
  /// 🔴 Ditambahkan 17 Agustus 2026 setelah satu sesi uji penuh terbuang.
  /// Enam video keluar bertanda *"waktu belum terverifikasi"* dan tidak ada
  /// satu pun baris di `adb logcat` yang menjelaskan sebabnya: seluruh jalur
  /// gagal di sini hanya memakai [AppLogger], yang memakai `dart:developer` dan
  /// tidak pernah sampai ke logcat (jebakan 11 di `PROMPT_SESI_BARU.md`).
  /// Keberhasilan tercetak, kegagalan senyap — itu justru kebalikan dari yang
  /// dibutuhkan saat mendiagnosis dari perangkat.
  static void _report(String sebab) =>
      debugPrint('KAMELSCAN_WAKTU sinkron GAGAL · $sebab');

  /// Apakah aplikasi ini pernah berhasil menanyakan waktu server.
  Future<bool> get hasAnchor async {
    await _loadAnchor();
    return _anchor != null;
  }

  // ---------------------------------------------------------------------

  static DateTime? _parse(Object? response) {
    // PostgREST mengembalikan timestamptz sebagai string ISO-8601. Bentuk lain
    // (mis. dibungkus daftar) pernah muncul di versi library yang berbeda, jadi
    // ditangani sekalian daripada gagal senyap.
    final raw = switch (response) {
      final String s => s,
      final List<Object?> l when l.isNotEmpty => l.first?.toString(),
      final Object o => o.toString(),
      null => null,
    };
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _loadAnchor() async {
    if (_anchorLoaded) return;
    _anchorLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      _anchor = TimeAnchor.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on Object catch (e) {
      _log.w('Titik acuan waktu tidak terbaca', e);
    }
  }

  Future<void> _saveAnchor(TimeAnchor anchor) async {
    _anchor = anchor;
    _anchorLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(anchor.toJson()));
    } on Object catch (e) {
      // Titik acuan yang gagal disimpan tetap berlaku selama aplikasi hidup.
      _log.w('Titik acuan waktu gagal disimpan', e);
    }
  }
}
