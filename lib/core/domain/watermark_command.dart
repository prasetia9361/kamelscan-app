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
  /// `box=1:boxcolor=black@0.5` mengikuti Bab 8.5 — bidang gelap di belakang
  /// teks jauh lebih terbaca di atas kardus terang daripada sekadar garis tepi.
  ///
  /// [boxOpacity] `0` mematikan kotaknya sama sekali, bukan menggambar kotak
  /// tembus pandang. Dipakai plakat bukti, yang sudah punya satu bidang gelap
  /// untuk seluruh blok — kotak per baris di atasnya hanya menumpuk gelap di
  /// tempat yang sudah gelap.
  static String drawText({
    required String text,
    required String fontFile,
    required String x,
    required String y,
    required int fontSize,
    double boxOpacity = 0.5,
    String fontColor = 'white',
  }) =>
      "drawtext=text='${escapeDrawText(text)}'"
      ':fontfile=${escapeDrawText(fontFile)}'
      ':x=$x:y=$y'
      ':fontsize=$fontSize'
      ':fontcolor=$fontColor'
      '${boxOpacity <= 0 ? '' : ':box=1:boxcolor=black@$boxOpacity'}';

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
  /// Kepala plakat bukti. Ia yang menyatakan blok di bawahnya adalah nomor
  /// resi, sehingga baris resinya sendiri tidak lagi memerlukan awalan
  /// `RESI:` yang memakan lebar di depan angka terpenting.
  static const String plaqueKicker = 'KAMELSCAN · BUKTI VIDEO';

  /// Ukuran huruf tiap bagian plakat, dalam piksel video 480p.
  static const int kickerFontSize = 11;
  static const int resiFontSize = 26;
  static const int metaFontSize = 13;

  /// Tinggi baris tiap bagian. Dipisah dari ukuran hurufnya karena keduanya
  /// tidak sama: huruf 26 px butuh baris 34 px agar tidak berimpit.
  static const int _kickerLine = 15;
  static const int _resiLine = 34;
  static const int _metaLine = 18;

  /// Lebar garis aksen camel di tepi kiri plakat.
  static const int accentWidth = 3;

  /// Jarak dari garis aksen ke teks.
  static const int accentGap = 9;

  /// Jarak dari tepi bidang gelap ke teks, atas dan bawah.
  ///
  /// 🔴 Ditambahkan 3 September 2026. Sebelumnya tidak ada sama sekali di sisi
  /// video: baris kepala digambar tepat pada tepi atas bidang gelapnya,
  /// sehingga hurufnya duduk menempel di garis batas — sementara pratinjau di
  /// layar rekam memberinya 8 dp. Product Owner melihat kedua bentuk itu
  /// berdampingan dan melaporkan bahwa keduanya tidak sama.
  static const int padTop = 8;
  static const int padBottom = 6;

  /// Warna kepala plakat, sebagai ARGB.
  ///
  /// 🔴 SATU sumber untuk video dan pratinjau, dan itu bukan kerapian.
  /// Sampai 3 September 2026 keduanya menulis warnanya sendiri-sendiri:
  /// pratinjau memakai emas terang `#D9A441`, sedangkan video memakai
  /// `#9A5B00` — warna aksen yang sama dengan garis tepinya. Di atas bidang
  /// gelap yang tembus pandang, coklat gelap itu praktis tidak terbaca, dan
  /// packer yang membaca kepalanya di layar tidak menemukannya lagi di video.
  ///
  /// ⚠️ Sengaja BUKAN [accentArgb]. Garis aksen adalah bidang penuh selebar
  /// 3 px yang tetap terlihat walau gelap; huruf setinggi 11 px tidak.
  static const int kickerArgb = 0xFFD9A441;

  /// Warna garis aksen camel di tepi plakat.
  static const int accentArgb = 0xFF9A5B00;

  /// Kepekatan bidang gelap di belakang plakat.
  ///
  /// 🔴 Diminta Product Owner 3 September 2026: *"warna dasar watermark lebih
  /// transparan sedikit"*, sesudah melihat video sungguhan pertamanya.
  /// Sebelumnya 0,75 — dibaca dari `tenant_settings.watermark_opacity`.
  ///
  /// ⚠️ Konstanta, BUKAN lagi pengaturan tenant, dan itu perubahan perilaku
  /// yang disengaja. Dua alasan:
  ///
  /// 1. Nilai itu **sudah tidak dapat diubah dari mana pun** sejak grup
  ///    pengaturan Merek dihapus 29 Agustus 2026, sehingga ia beku di 0,75
  ///    bagi setiap tenant. Membacanya dari database hanya memberi kesan ada
  ///    yang mengaturnya, padahal tidak ada.
  /// 2. 0,75 disetel untuk bentuk yang **lama**: kotak gelap kecil di belakang
  ///    tiap baris. Plakat sekarang satu bidang selebar video, jadi kepekatan
  ///    yang sama menutupi jauh lebih banyak gambar buktinya.
  ///
  /// 🔴 Batas bawahnya bukan selera. Bab 8.5 menyebut bidang gelap ini ada
  /// karena teks putih di atas kardus terang tidak terbaca. Menurunkannya
  /// terlalu jauh mengembalikan persis masalah yang dijawabnya — dan yang
  /// dikorbankan adalah keterbacaan nomor resi pada dokumen yang gunanya
  /// menyelesaikan sengketa.
  static const double plaqueBoxOpacity = 0.55;

  /// Bentuk `0xRRGGBB` yang dimengerti FFmpeg.
  static String hexOf(int argb) =>
      '0x${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static List<String> buildLines({
    required String resiCode,
    required DateTime serverTime,
    required String shopName,
    String? coordinates,
    bool timeVerified = true,
    bool showGps = true,
  }) =>
      <String>[
        // 🔴 Indeks 0 tetap nomor resi — ia digambar paling besar, dan itu
        // satu-satunya baris yang dicari petugas resolusi marketplace.
        //
        // Awalan `RESI:` dibuang 1 September 2026: kepala plakat
        // [plaqueKicker] sudah menyatakan blok ini bukti video KamelScan, dan
        // awalan itu mendorong angka terpenting ke kanan tanpa menambah arti.
        resiCode,
        formatStamp(serverTime, timeVerified: timeVerified),
        // Baris yang hilang membuat pembacanya tidak dapat membedakan "lokasi
        // tidak ada" dari "versi aplikasi ini belum menulis lokasi".
        if (showGps) coordinates ?? 'Lokasi tidak tersedia',
        shopName,
      ];

  /// Tinggi seluruh blok plakat untuk [lineCount] baris (termasuk resi).
  ///
  /// Dipakai bersama oleh penyusun FFmpeg dan pratinjau di layar, supaya
  /// keduanya menaruh plakat pada tempat yang sama.
  static int plaqueHeight(int lineCount) =>
      padTop +
      _kickerLine +
      _resiLine +
      (_metaLine * (lineCount <= 1 ? 0 : lineCount - 1)) +
      padBottom;

  /// Jarak dari puncak blok ke puncak baris ke-[index].
  ///
  /// Indeks −1 berarti kepala plakat.
  ///
  /// ⚠️ Seluruhnya bergeser [padTop] ke bawah. Tanpa itu baris kepala digambar
  /// tepat pada tepi bidang gelapnya dan hurufnya menempel di garis batas.
  static int plaqueOffset(int index) {
    if (index < 0) return padTop;
    if (index == 0) return padTop + _kickerLine;
    return padTop + _kickerLine + _resiLine + (_metaLine * (index - 1));
  }

  /// Susun seluruh rantai filter: skala 480p + baris-baris watermark.
  /// Susun seluruh rantai filter: skala 480p + **plakat bukti**.
  ///
  /// 🔴 Bentuknya berubah 1 September 2026 atas keputusan Product Owner. Dulu
  /// tiap baris berdiri sendiri dengan kotak gelapnya masing-masing, rata
  /// kanan. Sekarang keempat baris berkumpul menjadi satu blok rata kiri
  /// dengan satu bidang gelap, kepala `KAMELSCAN · BUKTI VIDEO`, nomor resi
  /// besar, dan garis aksen camel di tepinya.
  ///
  /// ⚠️ **Ini mengubah isi berkas video bukti**, bukan hanya tampilan layar.
  /// Pratinjau di layar rekam (`watermark_preview_overlay.dart`) meniru bentuk
  /// yang sama dan membaca daftar baris yang sama; bila keduanya menyimpang,
  /// yang salah pratinjaunya.
  ///
  /// Blok selalu **rata kiri di dalam dirinya sendiri**. [WatermarkPosition]
  /// menentukan sudut tempat blok itu ditambatkan, bukan perataan teksnya —
  /// teks rata kanan membuat angka resi berpindah-pindah posisi awal setiap
  /// kali panjangnya berbeda, dan itu justru angka yang dibaca orang.
  static String buildFilterChain({
    required List<String> lines,
    required String fontFile,
    required WatermarkPosition position,
    required int heightPx,
    int margin = 16,
    double boxOpacity = 0.5,
    String? accentColor,
  }) {
    final isTop = position == WatermarkPosition.topLeft ||
        position == WatermarkPosition.topRight;

    final blockH = plaqueHeight(lines.length);

    // 🔴 Plakat **selebar bidang video**, ditambatkan hanya ke atas atau bawah.
    //
    // [WatermarkPosition] karenanya hanya menentukan sisi tegaknya; kiri/kanan
    // tidak lagi berpengaruh. Itu disengaja, dan konsekuensinya harus
    // diketahui: pengaturan posisi watermark memang sudah tidak dapat diubah
    // dari mana pun sejak grup Merek dihapus 29 Agustus 2026, sehingga
    // nilainya beku di `bottom_right` bagi hampir semua tenant.
    //
    // Blok setengah lebar sempat dicoba agar sudut kanan tetap berarti, tetapi
    // pratinjau di layar rekam menggambarnya selebar layar — dan pratinjau
    // yang berbeda dari videonya persis kesalahan yang dilarang dartdoc
    // `watermark_preview_overlay.dart`. Satu bentuk untuk keduanya.
    // 🔴 `ih`, BUKAN `h` — dan perbedaannya menghentikan seluruh perekaman.
    //
    // Di `drawbox`, `w` dan `h` di dalam ekspresi berarti **ukuran kotak yang
    // sedang digambar**, bukan ukuran videonya; ukuran video adalah `iw`/`ih`.
    // Di `drawtext` justru sebaliknya: di sana `w`/`h` memang berarti ukuran
    // video. Dua filter yang berdiri bersebelahan memakai arti yang berlawanan
    // untuk huruf yang sama.
    //
    // ⚠️ Yang ditulis semula `h-$margin-$blockH`. Karena `h` di drawbox adalah
    // tinggi kotak — yang nilainya `$blockH` itu sendiri — hasilnya menjadi
    // `blockH - margin - blockH`, yaitu **−16**. Lebarnya `w-32` bahkan
    // menunjuk dirinya sendiri. FFmpeg menolak kotak seperti itu dan keluar
    // dengan kode 1, sehingga video TIDAK PERNAH selesai diberi watermark dan
    // berhenti selamanya di antrean lokal.
    //
    // Ditemukan Product Owner 3 September 2026. Ia sudah gagal sejak plakat ini
    // dibuat — terbukti sama di worktree `revisi-desain-aplikasimobile` maupun
    // di sini — dan tidak satu pun dari 687 tes menangkapnya, karena seluruh
    // tes memeriksa STRING yang disusun, bukan apakah FFmpeg menerimanya.
    final blockY = isTop ? '$margin' : 'ih-$margin-$blockH';
    final blockW = 'iw-${margin * 2}';

    // Warna aksen boleh ditimpa pemanggil (dipakai tes), tetapi bawaannya
    // datang dari [accentArgb] — satu sumber yang sama dengan pratinjau.
    final aksen = accentColor ?? hexOf(accentArgb);
    final textX = '${margin + accentWidth + accentGap}';

    // ⚠️ `h` di sini BENAR dan sengaja berbeda dari [blockY] di atas: nilainya
    // dipakai `drawtext`, tempat `h` memang berarti tinggi video.
    String yAt(int index) {
      final off = plaqueOffset(index);
      return isTop ? '${margin + off}' : 'h-$margin-${blockH - off}';
    }

    final filters = <String>[
      'scale=-2:$heightPx',
      // Satu bidang gelap untuk seluruh plakat, menggantikan kotak per baris.
      // Di atas kardus terang, teks putih tanpa bidang gelap tidak terbaca
      // (Bab 8.5).
      'drawbox=x=$margin:y=$blockY:w=$blockW:h=$blockH'
          ':color=black@$boxOpacity:t=fill',
      // Garis aksen camel di tepi blok — satu-satunya warna merek pada bukti.
      'drawbox=x=$margin:y=$blockY:w=$accentWidth:h=$blockH'
          ':color=$aksen@0.95:t=fill',
      drawText(
        text: plaqueKicker,
        fontFile: fontFile,
        x: textX,
        y: yAt(-1),
        fontSize: kickerFontSize,
        boxOpacity: 0,
        // 🔴 Kepala plakat memakai [kickerArgb], BUKAN warna aksennya.
        //
        // Ia keterangan dan tidak boleh bersaing dengan nomor resi — tetapi
        // sampai 3 September 2026 ia memakai coklat gelap `#9A5B00` yang di
        // atas bidang tembus pandang praktis tidak terbaca sama sekali,
        // sementara pratinjau di layar rekam memakai emas terang. Tidak
        // bersaing bukan berarti tidak terbaca.
        fontColor: '${hexOf(kickerArgb)}@0.95',
      ),
    ];

    for (var i = 0; i < lines.length; i++) {
      filters.add(
        drawText(
          text: lines[i],
          fontFile: fontFile,
          x: textX,
          y: yAt(i),
          // Indeks 0 adalah nomor resi — satu-satunya yang dibaca dari jauh.
          fontSize: i == 0 ? resiFontSize : metaFontSize,
          boxOpacity: 0,
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
