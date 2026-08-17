import 'package:flutter/material.dart';

/// Bingkai bantu di atas pratinjau kamera (Bab 8.3.3).
///
/// 🔴 Bentuknya **berbeda per mode**, dan itu bukan hiasan:
///
/// - **QR** — kotak. QR dibaca dari segala arah dan hanya perlu masuk utuh.
/// - **Barcode 1D** — persegi panjang **mendatar**. Bab 8.3.3: *"Barcode 1D
///   perlu mengisi lebar bingkai agar terbaca."* Bingkai kotak justru menuntun
///   packer memegang HP terlalu dekat, dan garis-garis barcode terpotong di
///   kedua tepinya.
class ScanFrameOverlay extends StatelessWidget {
  const ScanFrameOverlay({
    super.key,
    required this.wide,
    required this.color,
  });

  /// `true` untuk barcode 1D (mendatar), `false` untuk QR (kotak).
  final bool wide;

  /// Warna sudut bingkai. Berubah mengikuti keadaan: menunggu, menimbang
  /// pembacaan kedua, atau merekam.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = _frameRect(constraints.biggest);
        return IgnorePointer(
          child: CustomPaint(
            size: constraints.biggest,
            painter: _FramePainter(rect: rect, color: color),
          ),
        );
      },
    );
  }

  Rect _frameRect(Size size) {
    final width = size.width * (wide ? 0.88 : 0.68);
    // Barcode 1D: rasio 3:1 mendatar. QR: bujur sangkar.
    final height = wide ? width / 3 : width;
    return Rect.fromCenter(
      // Sedikit di atas tengah: bagian bawah layar tertutup tombol Berhenti
      // dan panel resi.
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: height,
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.rect, required this.color});

  final Rect rect;
  final Color color;

  static const double _cornerLength = 28;
  static const double _stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // 🔴 Area di luar bingkai TIDAK digelapkan — dicabut atas permintaan
    // Product Owner 17 Agustus 2026.
    //
    // Semula seluruh layar di luar kotak ditutup hitam 60% agar mata packer
    // langsung tertuju ke dalamnya. Alasan itu masuk akal untuk layar yang
    // *hanya* dipakai memindai, dan salah untuk layar ini: packer memindai
    // **sambil mengemas**, jadi yang digelapkan justru barang dan meja yang
    // sedang ia kerjakan. Kotaknya sendiri sudah cukup menunjukkan tempat
    // membidik.
    //
    // Bila suatu saat tergoda mengembalikannya, tanyakan dulu — ini keputusan
    // Product Owner, bukan kelalaian.
    // Hanya sudut-sudutnya yang digambar, bukan kotak penuh: garis penuh
    // menutupi tepi label dan justru menyulitkan membidik.
    final len = _cornerLength.clamp(0.0, rect.shortestSide / 2.5);

    // Tanpa latar gelap, sudut putih dapat lenyap di atas kardus terang atau
    // lantai gudang yang pucat. Digambar dua kali: garis hitam tipis lebih
    // dulu sebagai tepian, lalu warnanya di atasnya. §0 palet — warna tidak
    // boleh menjadi satu-satunya pembeda, dan di sini ia bahkan tidak boleh
    // menjadi satu-satunya yang terlihat.
    void corners(Paint paint) {
      void corner(Offset at, double dx, double dy) {
        canvas
          ..drawLine(at, at.translate(dx * len, 0), paint)
          ..drawLine(at, at.translate(0, dy * len), paint);
      }

      corner(rect.topLeft, 1, 1);
      corner(rect.topRight, -1, 1);
      corner(rect.bottomLeft, 1, -1);
      corner(rect.bottomRight, -1, -1);
    }

    corners(
      Paint()
        ..color = const Color(0x8C000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke + 3
        ..strokeCap = StrokeCap.round,
    );
    corners(
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.rect != rect || old.color != color;
}
