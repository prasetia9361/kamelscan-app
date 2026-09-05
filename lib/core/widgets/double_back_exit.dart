import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'failure_messages.dart';

/// Menahan tombol Kembali perangkat: keluar aplikasi butuh **dua** ketukan.
///
/// 🔴 Dilaporkan Product Owner 5 September 2026: *"saat saya tidak sengaja
/// klik kembali aplikasinya langsung keluar"*. Itu memang perilaku bawaan
/// Android pada rute paling bawah — tidak ada yang dapat di-`pop`, jadi sistem
/// menutup aplikasinya. Tidak ada galat, tidak ada peringatan, dan yang hilang
/// bukan cuma layarnya: antrean unggah yang sedang berjalan ikut berhenti
/// bersama prosesnya (Bab 8.7).
///
/// Ketukan pertama **wajib** memberi tahu. Menahan diam-diam justru lebih
/// buruk daripada langsung keluar: orang yang menekan Kembali dan tidak
/// terjadi apa-apa akan menekannya berkali-kali sampai keluar juga, tanpa
/// pernah tahu kenapa yang pertama diabaikan.
///
/// ⚠️ Di web widget ini tidak melakukan apa pun. `SystemNavigator.pop()` di
/// peramban tidak menutup tab, dan menahan tombol Kembali peramban berarti
/// merampas satu-satunya cara orang berpindah halaman di sana.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    this.jeda = const Duration(seconds: 2),
  });

  final Widget child;

  /// Selang waktu ketukan kedua masih dihitung sebagai "sengaja keluar".
  ///
  /// Dua detik, sama dengan lama SnackBar-nya tampil — supaya batas waktunya
  /// **terlihat**: selama pesannya masih di layar, ketukan berikutnya keluar.
  /// Angka yang lebih panjang membuat ketukan tak sengaja beberapa detik
  /// kemudian ikut menutup aplikasi, dan itu persis keluhan yang diperbaiki.
  final Duration jeda;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  /// Ketukan pertama sudah terjadi dan jedanya belum habis.
  bool _menunggu = false;

  /// Yang memadamkan [_menunggu] saat jedanya habis.
  ///
  /// 🔴 `Timer`, bukan selisih `DateTime.now()`. Dicoba begitu lebih dulu dan
  /// dibatalkan tes: `DateTime.now()` membaca jam dinding, sedangkan waktu di
  /// dalam tes widget adalah waktu palsu yang dimajukan `tester.pump`. Jedanya
  /// karena itu **tidak pernah habis** di tes, dan tidak ada satu pun cara
  /// membuktikan bahwa ketukan kedua yang terlambat memang tidak menutup
  /// aplikasi — padahal justru itu inti perbaikannya.
  Timer? _pemadam;

  @override
  void dispose() {
    // Tanpa ini timernya menyala melewati umur widget dan menyentuh state
    // yang sudah dibuang.
    _pemadam?.cancel();
    super.dispose();
  }

  void _tanganiKembali() {
    if (_menunggu) {
      // Ketukan kedua. `SystemNavigator.pop()` menutup aplikasi seperti tombol
      // Kembali biasa — bukan `exit(0)`, yang mematikan proses tanpa memberi
      // kesempatan apa pun untuk beres-beres.
      SystemNavigator.pop();
      return;
    }

    _menunggu = true;
    _pemadam?.cancel();
    _pemadam = Timer(widget.jeda, () => _menunggu = false);

    // `hideCurrentSnackBar` lebih dulu: tanpa itu pesan ini mengantre di
    // belakang SnackBar lain yang sedang tampil (mis. laporan antrean unggah),
    // dan baru muncul sesudah jedanya habis — memberi tahu terlambat sama saja
    // dengan tidak memberi tahu.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.navExitConfirm),
          duration: widget.jeda,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;

    // `canPop: false` — rute ini tidak boleh di-`pop` oleh sistem; keputusan
    // keluar atau tidak diambil di `onPopInvokedWithResult`.
    //
    // ⚠️ `PopScope` hanya berlaku saat rutenya sedang paling atas. Halaman yang
    // di-`push` di atas rangka (Tutorial, Pembayaran, Riwayat pembayaran,
    // Detail video) tetap ditutup satu ketukan seperti biasa — memang begitu
    // yang diminta: yang dijaga hanya jalan keluar dari aplikasi.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _tanganiKembali();
      },
      child: widget.child,
    );
  }
}
