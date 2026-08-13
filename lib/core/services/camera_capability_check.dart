import 'camera_capability_check_stub.dart'
    if (dart.library.io) 'camera_capability_check_mobile.dart';

/// Hasil satu butir pemeriksaan kemampuan kamera.
class CameraCheckItem {
  const CameraCheckItem({
    required this.name,
    required this.passed,
    this.detail,
  });

  final String name;
  final bool passed;
  final String? detail;

  @override
  String toString() =>
      '${passed ? 'LULUS' : 'GAGAL'}  $name${detail == null ? '' : ' — $detail'}';
}

class CameraCheckReport {
  const CameraCheckReport(this.items, {this.framesReceived = 0});

  final List<CameraCheckItem> items;

  /// Jumlah frame yang benar-benar diterima selama perekaman berjalan.
  final int framesReceived;

  bool get allPassed => items.every((i) => i.passed);

  String render() {
    final b = StringBuffer()
      ..writeln('===== KAMELSCAN_CAMERA_CHECK MULAI =====');
    for (final i in items) {
      b.writeln(i.toString());
    }
    b
      ..writeln('FRAME DITERIMA SAAT MEREKAM: $framesReceived')
      ..writeln('KESIMPULAN: ${allPassed ? 'SEMUA LULUS' : 'ADA YANG GAGAL'}')
      ..writeln('===== KAMELSCAN_CAMERA_CHECK SELESAI =====');
    return b.toString();
  }
}

/// Membuktikan perangkat sanggup menjalankan **pratinjau + perekaman video +
/// analisis frame** sekaligus.
///
/// 🔴 Ini syarat mutlak aturan berhenti yang diputuskan Product Owner
/// 13 Agustus 2026: pemindaian harus berjalan SELAMA merekam agar resi yang
/// sama dapat menghentikan rekaman.
///
/// Kenapa harus dibuktikan di perangkat, bukan diasumsikan:
///
/// - `CameraController.startImageStream` **melempar** `CameraException` bila
///   perekaman sudah berjalan. Satu-satunya jalan adalah
///   `startVideoRecording(onAvailable:)`, dan belum tentu semua perangkat
///   benar-benar mengalirkan frame lewat jalur itu.
/// - CameraX mengikat Preview + VideoCapture + ImageAnalysis sekaligus. Tiga
///   use case bersamaan hanya dijamin pada perangkat tingkat LIMITED ke atas;
///   perangkat kelas bawah dapat menolak, dan penolakannya muncul sebagai
///   kamera yang gagal menyala — bukan pesan yang menjelaskan.
///
/// Bila pemeriksaan ini gagal, rencana perekaman harus dirombak SEKARANG,
/// bukan setelah seluruh layar kamera ditulis.
Future<CameraCheckReport> runCameraCapabilityCheck() =>
    runPlatformCameraCapabilityCheck();
