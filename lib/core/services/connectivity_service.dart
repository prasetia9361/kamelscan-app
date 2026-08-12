import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Pantau status jaringan untuk pipeline offline-first (Bab 8).
///
/// ⚠️ `connectivity_plus` hanya melaporkan **ada antarmuka jaringan**, bukan
/// bahwa internet benar-benar dapat dijangkau. Wi-Fi hotel dengan halaman
/// login akan tetap dilaporkan "terhubung". Karena itu antrian upload tidak
/// boleh menganggap sinyal ini sebagai jaminan — kegagalan unggah tetap harus
/// ditangani dengan retry (lihat `UploadTask.retryDelay`).
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onConnectivityChanged => _connectivity
      .onConnectivityChanged
      .map(_hasNetwork)
      .distinct();

  Future<bool> get isConnected async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  /// Koneksi berbayar (seluler). Dipakai bila nanti ditambahkan pengaturan
  /// "unggah hanya lewat Wi-Fi".
  Future<bool> get isMobileData async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );
}
