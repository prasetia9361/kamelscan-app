/// Unduhan berkas di luar peramban — tidak ada, dan memang tidak seharusnya
/// ada.
///
/// 🔴 Ekspor CSV sengaja **web saja** (keputusan Product Owner 31 Agustus
/// 2026). Di HP tidak ada tempat yang jelas untuk menaruh berkasnya, tidak ada
/// pengelola berkas yang dapat diandalkan di seluruh merek, dan Riwayat versi
/// HP tidak punya tabel yang layak diekspor.
///
/// Berkas ini melempar alih-alih diam. Tombol Ekspor tidak pernah dirender di
/// HP; kalau ia sampai terpanggil, yang terjadi adalah cacat rute atau widget
/// yang salah tempat — dan diam hanya membuatnya tampak berhasil.
void unduhTeks({
  required String namaBerkas,
  required String isi,
  String mime = 'text/csv',
}) {
  throw UnsupportedError(
    'unduhTeks() hanya tersedia di web. Tombol Ekspor seharusnya tidak '
    'dirender di platform ini.',
  );
}
