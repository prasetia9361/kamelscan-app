import 'url_strategy_web.dart'
    if (dart.library.io) 'url_strategy_mobile.dart';

/// Menghapus tanda `#` dari alamat aplikasi web.
///
/// Bab 10.2 menetapkan tautan *Masuk* dan *Daftar* pada landing page mengarah
/// ke `/app/login` dan `/app/register`. Tanpa pemanggilan ini Flutter Web
/// memakai strategi bawaannya dan alamatnya menjadi `/app/#/login` — tautan
/// yang dituliskan desainer tidak akan pernah cocok.
///
/// 🔴 Konsekuensi yang tidak boleh dilupakan saat menerbitkan: dengan strategi
/// ini, **server** yang menerima permintaan `/app/history` — bukan aplikasi.
/// Bila tidak diberi tahu untuk mengembalikan `index.html`, ia akan mencari
/// berkas bernama `history` dan menjawab 404 begitu halaman disegarkan.
/// Aturannya ada di `_redirects` yang dibuat `deploy_web.ps1`.
///
/// Di Android dan iOS pemanggilan ini tidak melakukan apa pun — tidak ada
/// alamat peramban untuk diatur.
void applyUrlStrategy() => applyPlatformUrlStrategy();
