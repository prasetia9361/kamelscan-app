/// Penyusun perintah watermark FFmpeg (Bab 8.5).
///
/// Dipisahkan dari `MobileVideoProcessor` agar **tidak mengimpor FFmpeg sama
/// sekali**, sehingga dapat diuji di komputer tanpa perangkat.
///
/// Alasannya spesifik. Bab 8.5 menulis:
///
/// > *"Karakter `:` di dalam `drawtext` harus di-escape menjadi `\:`.
/// > Ini penyebab kegagalan ffmpeg paling sering."*
///
/// Nomor resi dan nama toko datang dari pengguna dan marketplace — keduanya
/// bisa berisi karakter apa pun. Bila escape-nya salah, FFmpeg gagal pada
/// video tertentu saja, dan kegagalan seperti itu baru ketahuan di gudang
/// pelanggan.
library;

import '../models/enums.dart';

class WatermarkCommand {
  const WatermarkCommand._();

  /// Karakter yang bermakna khusus di dalam nilai `drawtext`.
  ///
  /// Urutan penggantian **penting**: garis miring terbalik harus lebih dulu,
  /// kalau tidak escape yang baru ditambahkan ikut ter-escape lagi.
  static String escapeDrawText(String raw) => raw
      .replaceAll('\\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll('%', r'\%')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');

  /// Bungkus argumen berisi spasi agar aman dilewatkan ke FFmpeg.
  static String quote(String path) => '"${path.replaceAll('"', r'\"')}"';

  /// Satu filter `drawtext` untuk satu baris teks.
  ///
  /// `box=1:boxcolor=black@0.5` mengikuti Bab 8.5 — kotak gelap di belakang
  /// teks jauh lebih terbaca di atas kardus terang daripada sekadar garis tepi.
  static String drawText({
    required String text,
    required String fontFile,
    required String x,
    required String y,
    required int fontSize,
    double boxOpacity = 0.5,
  }) =>
      "drawtext=text='${escapeDrawText(text)}'"
      ':fontfile=${escapeDrawText(fontFile)}'
      ':x=$x:y=$y'
      ':fontsize=$fontSize'
      ':fontcolor=white'
      ':box=1:boxcolor=black@$boxOpacity';

  /// Baris-baris yang tertulis di watermark, **berurutan dari tepi ke dalam**.
  ///
  /// 🔴 Satu-satunya tempat isi watermark ditentukan. Sebelumnya daftar ini
  /// disusun di dalam `video_processor_mobile.dart`, yang hanya dapat berjalan
  /// di perangkat — sementara layar rekam perlu menampilkan **isi yang sama
  /// persis** kepada packer sebelum videonya jadi (permintaan Product Owner
  /// 17 Agustus 2026). Dua penyusun terpisah berarti pratinjau di layar
  /// perlahan berbeda dari yang terbakar di video, dan packer akan mempercayai
  /// yang salah.
  ///
  /// Urutannya bukan selera: indeks 0 digambar paling dekat tepi layar dan
  /// dengan huruf terbesar, jadi **nomor resi harus pertama**. Itu satu-satunya
  /// baris yang dicari petugas resolusi marketplace.
  static List<String> buildLines({
    required String resiCode,
    required DateTime serverTime,
    required String shopName,
    String? coordinates,
    bool timeVerified = true,
    bool showGps = true,
  }) =>
      <String>[
        'RESI: $resiCode',
        formatStamp(serverTime, timeVerified: timeVerified),
        shopName,
        if (showGps)
          coordinates == null
              ? 'Lokasi tidak tersedia'
              : 'GPS: $coordinates',
      ];

  /// Susun seluruh rantai filter: skala 480p + baris-baris watermark.
  static String buildFilterChain({
    required List<String> lines,
    required String fontFile,
    required WatermarkPosition position,
    required int heightPx,
    int fontSize = 18,
    int lineHeight = 24,
    int margin = 16,
    double boxOpacity = 0.5,
  }) {
    final isTop = position == WatermarkPosition.topLeft ||
        position == WatermarkPosition.topRight;
    final isLeft = position == WatermarkPosition.topLeft ||
        position == WatermarkPosition.bottomLeft;

    final x = isLeft ? '$margin' : 'w-tw-$margin';

    final filters = <String>['scale=-2:$heightPx'];
    for (var i = 0; i < lines.length; i++) {
      // Dari atas: baris pertama paling atas. Dari bawah: baris pertama paling
      // bawah, sehingga nomor resi selalu paling dekat tepi layar.
      final offset = margin + (i * lineHeight);
      final y = isTop ? '$offset' : 'h-th-$offset';
      filters.add(
        drawText(
          text: lines[i],
          fontFile: fontFile,
          x: x,
          y: y,
          fontSize: i == 0 ? fontSize : fontSize - 2,
          boxOpacity: boxOpacity,
        ),
      );
    }
    return filters.join(',');
  }

  /// Metadata yang ditanam di berkas video (Bab 8.5).
  ///
  /// Berguna saat berkas beredar lepas dari aplikasi — petugas resolusi
  /// marketplace dapat memeriksa asalnya tanpa membuka KamelScan.
  ///
  /// Tanda `|` dan `=` dipakai sebagai pemisah, jadi keduanya dibuang dari
  /// nilai agar metadata tidak bisa dipalsukan lewat nomor resi yang disusun
  /// khusus.
  static String buildMetadataComment({
    required String resiCode,
    required DateTime serverTime,
    required String shopId,
    double? lat,
    double? lng,
    bool timeVerified = true,
  }) {
    String clean(String v) => v.replaceAll(RegExp(r'[|=]'), '');
    final parts = <String>[
      'KamelScan',
      'resi=${clean(resiCode)}',
      'ts=${serverTime.toUtc().toIso8601String()}',
      // Selalu ditulis, tidak hanya saat bernilai 0. Metadata yang menghilang
      // saat keadaannya baik membuat pembacanya tidak dapat membedakan
      // "waktunya sahih" dari "versi aplikasi ini belum menulis tandanya".
      'time_verified=${timeVerified ? 1 : 0}',
      'shop_id=${clean(shopId)}',
      if (lat != null) 'lat=${lat.toStringAsFixed(6)}',
      if (lng != null) 'lng=${lng.toStringAsFixed(6)}',
    ];
    return parts.join('|');
  }

  /// Waktu server dalam format yang mudah dibaca petugas resolusi marketplace.
  ///
  /// ⚠️ Selalu waktu **server**, tidak pernah jam perangkat — jam HP dapat
  /// dimundurkan untuk memalsukan bukti (Bab 1.3 poin 6).
  ///
  /// [timeVerified] `false` menempelkan keterangan apa adanya ke dalam gambar.
  /// Keputusan Product Owner 16 Agustus 2026: aplikasi yang belum pernah
  /// menyentuh sinyal tetap boleh merekam, dan videonya ditandai — bukan
  /// ditolak, dan bukan pula ditampilkan seolah waktunya terjamin.
  static String formatStamp(DateTime serverTime, {bool timeVerified = true}) {
    final t = serverTime.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${two(t.day)}/${two(t.month)}/${t.year} '
        '${two(t.hour)}.${two(t.minute)}.${two(t.second)}';
    return timeVerified ? stamp : '$stamp (waktu belum terverifikasi)';
  }

  /// Perintah lengkap.
  ///
  /// `-preset ultrafast -crf 28` mengikuti Bab 8.5: pemrosesan di HP kelas
  /// menengah tidak boleh lebih dari ± 3 detik untuk video 30 detik. Jangan
  /// menggantinya dengan preset lambat demi kualitas.
  ///
  /// `-movflags +faststart` **wajib** agar video dapat diputar streaming tanpa
  /// diunduh penuh.
  static String build({
    required String inputPath,
    required String outputPath,
    required String filterChain,
    required String metadataComment,
  }) =>
      '-y -i ${quote(inputPath)} '
      '-vf "$filterChain" '
      '-c:v libx264 -preset ultrafast -crf 28 '
      '-c:a aac -b:a 96k '
      '-movflags +faststart '
      '-metadata comment=${quote(metadataComment)} '
      '${quote(outputPath)}';
}
