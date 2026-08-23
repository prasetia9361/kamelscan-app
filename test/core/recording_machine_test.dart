import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/recording_machine.dart';
import 'package:kamelscan/core/models/enums.dart';

void main() {
  const max = Duration(seconds: 30);
  RecordingState ready() => RecordingMachine.ready(maxDuration: max);

  group('Alur normal (Bab 8.1)', () {
    test('READY -> RECORDING -> STOPPING -> PROCESSING -> QUEUED', () {
      var s = ready();
      expect(s.phase, RecordingPhase.ready);

      s = RecordingMachine.start(s, 'SPXID001')!;
      expect(s.phase, RecordingPhase.recording);
      expect(s.resiCode, 'SPXID001');

      s = RecordingMachine.stop(s, StopReason.manual)!;
      expect(s.phase, RecordingPhase.stopping);

      s = RecordingMachine.toProcessing(s)!;
      expect(s.phase, RecordingPhase.processing);

      s = RecordingMachine.toQueued(s)!;
      expect(s.phase, RecordingPhase.queued);
    });

    test('resi berikutnya kembali ke READY dengan durasi maks yang sama', () {
      var s = RecordingMachine.start(ready(), 'SPXID001')!;
      s = RecordingMachine.stop(s, StopReason.manual)!;
      final n = RecordingMachine.next(s);
      expect(n.phase, RecordingPhase.ready);
      expect(n.resiCode, isNull);
      expect(n.maxDuration, max);
    });
  });

  group('Transisi tidak sah ditolak, bukan diterima diam-diam', () {
    test('tidak bisa mulai dua kali — berkas akan saling menimpa', () {
      final s = RecordingMachine.start(ready(), 'SPXID001')!;
      expect(RecordingMachine.start(s, 'SPXID002'), isNull);
    });

    test('tidak bisa mulai dari IDLE tanpa setup lengkap', () {
      expect(RecordingMachine.start(const RecordingState(), 'A123456'), isNull);
    });

    test('tidak bisa berhenti dua kali — berkas ditutup dua kali', () {
      var s = RecordingMachine.start(ready(), 'SPXID001')!;
      s = RecordingMachine.stop(s, StopReason.manual)!;
      expect(RecordingMachine.stop(s, StopReason.manual), isNull);
    });

    test('tidak bisa berhenti saat belum merekam', () {
      expect(RecordingMachine.stop(ready(), StopReason.manual), isNull);
    });

    test('urutan pemrosesan tidak bisa dilompati', () {
      final rec = RecordingMachine.start(ready(), 'SPXID001')!;
      expect(RecordingMachine.toProcessing(rec), isNull);
      expect(RecordingMachine.toQueued(rec), isNull);
    });
  });

  group('Penghitung durasi (Bab 7.4 & 8.4)', () {
    test('tick hanya berlaku saat merekam', () {
      final r = ready();
      expect(RecordingMachine.tick(r, const Duration(seconds: 5)).elapsed,
          Duration.zero);
    });

    test('sisa waktu tidak pernah negatif', () {
      var s = RecordingMachine.start(ready(), 'A123456')!;
      s = RecordingMachine.tick(s, const Duration(seconds: 45));
      expect(s.remaining, Duration.zero);
    });

    test('batas durasi terdeteksi tepat pada detik ke-30', () {
      var s = RecordingMachine.start(ready(), 'A123456')!;
      s = RecordingMachine.tick(s, const Duration(seconds: 29));
      expect(s.hasReachedLimit, isFalse);
      s = RecordingMachine.tick(s, const Duration(seconds: 30));
      expect(s.hasReachedLimit, isTrue);
    });

    test('hitung mundur suara menyala pada 5 detik terakhir', () {
      var s = RecordingMachine.start(ready(), 'A123456')!;
      s = RecordingMachine.tick(s, const Duration(seconds: 24));
      expect(s.isFinalCountdown, isFalse);
      s = RecordingMachine.tick(s, const Duration(seconds: 25));
      expect(s.isFinalCountdown, isTrue);
      // Setelah batas tercapai bukan lagi hitung mundur.
      s = RecordingMachine.tick(s, const Duration(seconds: 30));
      expect(s.isFinalCountdown, isFalse);
    });
  });

  group('Alasan berhenti', () {
    test('tiga cara berhenti semuanya menyimpan hasil', () {
      for (final r in [
        StopReason.secondScan,
        StopReason.durationLimit,
        StopReason.manual,
      ]) {
        final s = RecordingMachine.stop(
          RecordingMachine.start(ready(), 'A123456')!,
          r,
        )!;
        expect(s.stopReason, r);
        expect(r.keepsRecording, isTrue);
      }
    });

    test('hanya kegagalan yang membuang hasil rekaman', () {
      expect(StopReason.error.keepsRecording, isFalse);
    });

    test('gagal dapat terjadi dari fase mana pun', () {
      final s = RecordingMachine.fail(
        RecordingMachine.start(ready(), 'A123456')!,
        'errorStorage',
      );
      expect(s.phase, RecordingPhase.failed);
      expect(s.errorKey, 'errorStorage');
    });
  });

  group('Tombol Berhenti (Bab 8.3.1)', () {
    test('hanya berguna saat merekam', () {
      expect(ready().phase.canStop, isFalse);
      expect(RecordingMachine.start(ready(), 'A123456')!.phase.canStop, isTrue);
    });

    test('fase sibuk mencakup merekam, menghentikan, dan memproses', () {
      expect(RecordingPhase.recording.isBusy, isTrue);
      expect(RecordingPhase.stopping.isBusy, isTrue);
      expect(RecordingPhase.processing.isBusy, isTrue);
      expect(RecordingPhase.ready.isBusy, isFalse);
      expect(RecordingPhase.queued.isBusy, isFalse);
    });
  });

  group('Layar setup (Bab 8.2)', () {
    const full = RecordingSetup(
      cameraId: 'back',
      triggerMode: TriggerMode.qrCode,
      shopId: 'shop-1',
      hasTokens: true,
    );

    test('tombol Mulai aktif hanya bila ketiganya terisi DAN ada token', () {
      expect(full.canStart, isTrue);
      expect(full.copyWith(hasTokens: false).canStart, isFalse);
      expect(const RecordingSetup(hasTokens: true).canStart, isFalse);
    });

    test('token habis diberitahukan lebih dulu daripada pilihan yang kosong', () {
      // Tanpa token, melengkapi pilihan tidak ada gunanya — sebutkan
      // penghalang yang sesungguhnya.
      const kosong = RecordingSetup();
      expect(kosong.blockedReasonKey, 'errorTokenExhausted');
    });

    test('alasan menyebut pilihan yang belum diisi, satu per satu', () {
      const s = RecordingSetup(hasTokens: true);
      expect(s.blockedReasonKey, 'setupPickCamera');
      expect(s.copyWith(cameraId: 'back').blockedReasonKey, 'setupPickTrigger');
      expect(
        s.copyWith(cameraId: 'back', triggerMode: TriggerMode.manual)
            .blockedReasonKey,
        'setupPickShop',
      );
    });

    test('tidak ada alasan tersisa saat sudah siap', () {
      expect(full.blockedReasonKey, isNull);
    });
  });

  /// Bab 9.2 — jenis paket ditambahkan 18 Agustus 2026. Sebelumnya seluruh
  /// alur rekam memaku `packing`, sehingga video return tersimpan dengan tipe
  /// yang salah dan menabrak indeks `uq_resi_per_tenant_type`.
  group('Jenis paket di layar setup (Bab 9.2)', () {
    test('bawaannya packing — pekerjaan sehari-hari, bukan yang jarang', () {
      expect(const RecordingSetup().type, VideoType.packing);
    });

    test('jenis paket TIDAK ikut menentukan kelengkapan pilihan', () {
      // Berbeda dari kamera/pemicu/toko, ia selalu punya nilai. Bila ia ikut
      // dihitung, tombol Mulai akan mati tanpa alasan yang dapat dijelaskan.
      const s = RecordingSetup(
        cameraId: 'back',
        triggerMode: TriggerMode.qrCode,
        shopId: 'shop-1',
        hasTokens: true,
      );
      expect(s.isComplete, isTrue);
      expect(s.copyWith(type: VideoType.returned).isComplete, isTrue);
      expect(s.copyWith(type: VideoType.returned).canStart, isTrue);
      expect(s.copyWith(type: VideoType.returned).blockedReasonKey, isNull);
    });

    test('copyWith mengganti jenis tanpa menyentuh pilihan lain', () {
      const s = RecordingSetup(
        cameraId: 'back',
        triggerMode: TriggerMode.manual,
        shopId: 'shop-9',
        hasTokens: true,
      );
      final r = s.copyWith(type: VideoType.returned);

      expect(r.type, VideoType.returned);
      expect(r.cameraId, 'back');
      expect(r.triggerMode, TriggerMode.manual);
      expect(r.shopId, 'shop-9');
      expect(r.hasTokens, isTrue);
    });

    test('copyWith tanpa jenis mempertahankan yang sedang dipakai', () {
      const r = RecordingSetup(type: VideoType.returned);
      expect(r.copyWith(cameraId: 'front').type, VideoType.returned);
    });

    test('nilai wire cocok dengan enum database', () {
      // Nilai inilah yang dikirim lewat query rute dan disimpan ke kolom
      // `package_videos.type`. `return` adalah kata kunci Dart, jadi nama
      // Dart-nya `returned` sementara nilai databasenya tetap `return`.
      expect(VideoType.packing.wire, 'packing');
      expect(VideoType.returned.wire, 'return');
      expect(VideoType.fromWire('return'), VideoType.returned);
      expect(VideoType.fromWire('packing'), VideoType.packing);
    });

    test('wire yang tidak dikenal jatuh ke packing, bukan mogok', () {
      // Rute yang dipulihkan tanpa parameter tipe harus tetap berjalan seperti
      // sebelum Bab 9.2 — bukan melempar di tengah layar kamera.
      expect(VideoType.fromWire(null), VideoType.packing);
      expect(VideoType.fromWire(''), VideoType.packing);
      expect(VideoType.fromWire('retur'), VideoType.packing);
    });
  });
}
