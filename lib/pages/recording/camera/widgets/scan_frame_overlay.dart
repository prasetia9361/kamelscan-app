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
  static const double _radius = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    // Gelapkan area di luar bingkai supaya mata langsung tertuju ke dalamnya.
    // Ini penting di gudang: layar terang penuh membuat packer menebak-nebak
    // bagian mana yang sebenarnya dibaca.
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    // Hanya sudut-sudutnya yang digambar, bukan kotak penuh: garis penuh
    // menutupi tepi label dan justru menyulitkan membidik.
    final len = _cornerLength.clamp(0.0, rect.shortestSide / 2.5);

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

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.rect != rect || old.color != color;
}
