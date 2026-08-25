import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../navigation/route_names.dart';
import '../widgets/auth_scaffold.dart';

/// Tempat peramban mendarat sesudah tautan email ditekan di **web** (Bab 10).
///
/// 🔴 Halaman ini nyaris tidak pernah terlihat, dan itu memang tujuannya.
/// `Supabase.initialize()` **menunggu** penukaran tautan selesai sebelum
/// `runApp()` berjalan (`supabase_flutter` 2.17, `SupabaseAuth.initialize` →
/// `_startDeeplinkObserver` → `_handleInitialUri`), jadi begitu layar pertama
/// digambar sesinya biasanya sudah ada dan penjagaan rute langsung memindahkan
/// pengguna:
///
/// - tautan **Lupa password** → `passwordResetPending` menyala → layar password
///   baru;
/// - tautan **verifikasi email** → sesi terbentuk → layar pembuka, lalu Beranda.
///
/// Yang dikerjakan halaman ini hanyalah dua keadaan yang tidak ditangani
/// siapa pun:
///
/// 1. **Tautannya gagal ditukar** — kedaluwarsa, sudah terpakai, atau dibuka di
///    peramban yang berbeda dari yang memintanya. Pengguna dibawa ke layar
///    Masuk, yang sudah punya kotak merah untuk kegagalan semacam ini
///    (`authLinkFailureProvider`). Sengaja tidak diulang di sini: satu kalimat
///    di satu tempat, supaya tidak ada dua versi yang bisa berbeda.
/// 2. **Alamatnya dibuka tanpa membawa apa pun** — misalnya di-*bookmark*, atau
///    tautannya dipotong saat disalin. Tanpa batas waktu di bawah, layar ini
///    berputar selamanya tanpa pernah mengatakan apa pun.
class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  /// Batas menunggu sebelum menyerah dan pindah ke layar Masuk.
  ///
  /// Dibuat selonggar ini bukan karena penukarannya lama — ia sudah selesai
  /// sebelum halaman ini lahir — melainkan karena sesudah sesi terbentuk masih
  /// ada satu langkah lagi: `sessionProvider` memuat profil, tenant, katalog
  /// tier, dan dompet sebelum peran diketahui. Menyerah terlalu cepat akan
  /// membuang pengguna yang sebenarnya sudah berhasil masuk.
  static const Duration batasTunggu = Duration(seconds: 15);

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  Timer? _batas;
  bool _sudahPindah = false;

  @override
  void initState() {
    super.initState();
    debugPrint('KAMELSCAN_CALLBACK halaman terbuka · menunggu hasil tautan');
    _batas = Timer(AuthCallbackPage.batasTunggu, () {
      debugPrint('KAMELSCAN_CALLBACK menyerah · tautan tidak menghasilkan sesi');
      _keLogin();
    });

    // Kegagalan biasanya **sudah ada** sejak build pertama, karena tautannya
    // ditukar sebelum aplikasi digambar. `ref.listen` di `build` hanya menyimak
    // perubahan berikutnya, jadi keadaan awalnya harus diperiksa terpisah.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authLinkFailureProvider) != null) {
        debugPrint('KAMELSCAN_CALLBACK tautan GAGAL sejak awal → layar Masuk');
        _keLogin();
      }
    });
  }

  @override
  void dispose() {
    _batas?.cancel();
    super.dispose();
  }

  void _keLogin() {
    if (!mounted || _sudahPindah) return;
    _sudahPindah = true;
    _batas?.cancel();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Kegagalan yang tiba sesudah halaman ini terbangun.
    ref.listen(authLinkFailureProvider, (_, next) {
      if (next != null) {
        debugPrint('KAMELSCAN_CALLBACK tautan GAGAL ditukar → layar Masuk');
        _keLogin();
      }
    });

    final t = context.l10n;

    return AuthScaffold(
      showBack: false,
      title: t.authCallbackTitle,
      subtitle: t.authCallbackBody,
      children: const [
        Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ],
    );
  }
}
