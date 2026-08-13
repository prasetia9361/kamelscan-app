import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/scan_gate.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/services/trigger_strategy.dart';

void main() {
  /// Jam palsu agar debounce dapat diuji tanpa menunggu sungguhan.
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 8, 13, 10));

  ScanGate gate(TriggerMode mode) =>
      ScanGate(strategy: TriggerStrategy.of(mode), clock: clock);

  group('Mode QR (Bab 8.3.2)', () {
    test('pembacaan pertama langsung diterima', () {
      final g = gate(TriggerMode.qrCode);
      final r = g.read('SPXID000123456');
      expect(r.decision, ScanDecision.accepted);
      expect(r.resiCode, 'SPXID000123456');
      expect(g.isRecording, isTrue);
    });

    test('resi dinormalkan: spasi dibuang, huruf dibesarkan', () {
      final g = gate(TriggerMode.qrCode);
      expect(g.read(' spxid000123456 \n').resiCode, 'SPXID000123456');
    });

    test('URL ditolak, bukan dipaksa jadi nomor resi (Bab 8.3.1)', () {
      final g = gate(TriggerMode.qrCode);
      final r = g.read('https://shopee.co.id/track?no=SPXID000123456');
      expect(r.decision, ScanDecision.rejected);
      expect(g.isRecording, isFalse);
    });

    test('kode terlalu pendek ditolak', () {
      expect(gate(TriggerMode.qrCode).read('AB12').decision,
          ScanDecision.rejected);
    });

    test('resi SAMA sebelum 5 detik belum boleh menghentikan', () {
      // Kamera yang masih menghadap label tidak boleh langsung menghentikan
      // rekaman yang baru saja dimulai.
      final g = gate(TriggerMode.qrCode)..read('SPXID000123456');
      now = now.add(const Duration(seconds: 2));
      final r = g.read('SPXID000123456');
      expect(r.decision, ScanDecision.stopTooEarly);
      expect(g.isRecording, isTrue);
      expect(g.secondsUntilScanStop, greaterThan(0));
    });

    test('resi SAMA setelah 5 detik menghentikan (aturan Product Owner)', () {
      final g = gate(TriggerMode.qrCode)..read('SPXID000123456');
      now = now.add(const Duration(seconds: 6));
      final r = g.read('SPXID000123456');
      expect(r.decision, ScanDecision.stopRequested);
      expect(r.resiCode, 'SPXID000123456');
      expect(g.canStopByScan, isTrue);
    });

    test('tepat pada detik ke-5 sudah boleh menghentikan', () {
      final g = gate(TriggerMode.qrCode)..read('SPXID000123456');
      now = now.add(const Duration(seconds: 5));
      expect(g.read('SPXID000123456').decision, ScanDecision.stopRequested);
    });

    test('resi BERBEDA tidak menghentikan, perekaman lanjut', () {
      // Penyimpangan dari Bab 8.3.2: menghentikan dengan resi lain memaksa
      // packer mencari label paket lain untuk paket terakhir.
      final g = gate(TriggerMode.qrCode)..read('SPXID000000001');
      now = now.add(const Duration(seconds: 10));
      final r = g.read('SPXID000000002');
      expect(r.decision, ScanDecision.otherResiIgnored);
      expect(g.isRecording, isTrue);
      expect(g.activeResi, 'SPXID000000001');
    });

    test('resi berbeda melaporkan resi yang SEDANG direkam, bukan yang dipindai', () {
      // Layar harus bisa berkata "Masih merekam SPXID000000001".
      final g = gate(TriggerMode.qrCode)..read('SPXID000000001');
      now = now.add(const Duration(seconds: 10));
      expect(g.read('SPXID000000002').resiCode, 'SPXID000000001');
    });

    test('sisa detik menghitung mundur menuju nol', () {
      final g = gate(TriggerMode.qrCode)..read('SPXID000123456');
      expect(g.secondsUntilScanStop, 5);
      now = now.add(const Duration(seconds: 3));
      expect(g.secondsUntilScanStop, 2);
      now = now.add(const Duration(seconds: 3));
      expect(g.secondsUntilScanStop, 0);
    });

    test('bip dan getar hanya pada pembacaan yang diterima (Bab 8.3.5)', () {
      final g = gate(TriggerMode.qrCode);
      final ok = g.read('SPXID000123456');
      expect(ok.shouldBeep, isTrue);
      expect(ok.shouldVibrate, isTrue);
      now = now.add(const Duration(seconds: 6));
      expect(g.read('SPXID000123456').shouldBeep, isFalse);
    });
  });

  group('Mode Barcode 1D — konfirmasi pembacaan ganda (Bab 8.3.3)', () {
    test('pembacaan pertama BELUM diterima', () {
      final g = gate(TriggerMode.barcode1d);
      final r = g.read('JX1234567890');
      expect(r.decision, ScanDecision.pendingConfirmation);
      expect(r.resiCode, isNull);
      expect(g.isRecording, isFalse);
    });

    test('pembacaan pertama TIDAK berbunyi bip (Bab 8.3.5)', () {
      final g = gate(TriggerMode.barcode1d);
      expect(g.read('JX1234567890').shouldBeep, isFalse);
    });

    test('dua pembacaan identik berturut-turut diterima', () {
      final g = gate(TriggerMode.barcode1d)..read('JX1234567890');
      now = now.add(const Duration(milliseconds: 300));
      final r = g.read('JX1234567890');
      expect(r.decision, ScanDecision.accepted);
      expect(r.resiCode, 'JX1234567890');
      expect(r.shouldBeep, isTrue);
    });

    test('pembacaan kedua yang BERBEDA membatalkan, bukan menerima', () {
      // Inilah yang dijaga: barcode 1D sering salah baca satu-dua digit.
      final g = gate(TriggerMode.barcode1d)..read('JX1234567890');
      now = now.add(const Duration(milliseconds: 200));
      final r = g.read('JX1234567891'); // digit terakhir beda
      expect(r.decision, ScanDecision.pendingConfirmation);
      expect(g.isRecording, isFalse);
    });

    test('salah baca lalu benar dua kali tetap harus dua kali identik', () {
      final g = gate(TriggerMode.barcode1d);
      expect(g.read('JX1234567891').decision, ScanDecision.pendingConfirmation);
      expect(g.read('JX1234567890').decision, ScanDecision.pendingConfirmation);
      expect(g.read('JX1234567890').decision, ScanDecision.accepted);
    });

    test('konfirmasi yang terlalu lama dianggap pembacaan pertama lagi', () {
      final g = gate(TriggerMode.barcode1d)..read('JX1234567890');
      now = now.add(const Duration(seconds: 30));
      expect(g.read('JX1234567890').decision, ScanDecision.pendingConfirmation);
      now = now.add(const Duration(milliseconds: 300));
      expect(g.read('JX1234567890').decision, ScanDecision.accepted);
    });

    test('format 1D sesuai daftar Bab 8.3.3, tanpa tambahan', () {
      final formats = TriggerStrategy.of(TriggerMode.barcode1d).formats;
      expect(formats.length, 6);
    });

    test('senter dan bingkai lebar wajib pada mode ini', () {
      final s = TriggerStrategy.of(TriggerMode.barcode1d);
      expect(s.needsTorchButton, isTrue);
      expect(s.usesWideFrame, isTrue);
      expect(s.requiresDoubleRead, isTrue);
    });
  });

  group('Mode Input Manual (Bab 8.3.4)', () {
    test('resi diketik diterima setelah dinormalkan', () {
      final g = gate(TriggerMode.manual);
      expect(g.acceptManual(' jne-00012345 '), 'JNE-00012345');
      expect(g.isRecording, isTrue);
    });

    test('ketikan tidak sah ditolak', () {
      final g = gate(TriggerMode.manual);
      expect(g.acceptManual('AB'), isNull);
      expect(g.acceptManual('https://contoh.com/resi'), isNull);
      expect(g.isRecording, isFalse);
    });

    test('pemindaian tidak dapat menghentikan mode manual', () {
      // Bab 8.3.4: hanya tombol Berhenti dan batas durasi yang berlaku.
      final g = gate(TriggerMode.manual);
      g.acceptManual('JNE-00012345');
      now = now.add(const Duration(seconds: 5));
      expect(g.read('JNE-00099999').decision, ScanDecision.otherResiIgnored);
      expect(g.isRecording, isTrue);
    });

    test('acceptManual ditolak pada mode selain manual', () {
      expect(gate(TriggerMode.qrCode).acceptManual('JNE-00012345'), isNull);
    });
  });

  group('Daur ulang antar rekaman', () {
    test('reset mengosongkan keadaan untuk resi berikutnya', () {
      final g = gate(TriggerMode.qrCode)..read('SPXID000000001');
      expect(g.isRecording, isTrue);
      g.reset();
      expect(g.isRecording, isFalse);
      expect(g.activeResi, isNull);
      final r = g.read('SPXID000000002');
      expect(r.decision, ScanDecision.accepted);
    });
  });
}
