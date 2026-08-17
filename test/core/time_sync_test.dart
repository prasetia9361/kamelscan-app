import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/time_sync.dart';

/// Aturan waktu watermark (Bab 8.5, keputusan Product Owner 16 Agustus 2026).
///
/// Yang diuji di sini bukan kerapian kode, melainkan janji produknya: waktu di
/// video bukti **tidak boleh dapat digeser dengan mengubah jam HP**.
void main() {
  final serverTime = DateTime.utc(2026, 8, 17, 10);
  const anchorPoint = Duration(hours: 5);

  TimeAnchor anchorAt(String sourceId) => TimeAnchor(
        serverTime: serverTime,
        monotonic: anchorPoint,
        sourceId: sourceId,
        deviceTimeAtSync: serverTime,
      );

  group('waktu terkoreksi dihitung dari penghitung, bukan jam HP', () {
    test('20 menit berlalu menurut penghitung → waktu maju 20 menit', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint + const Duration(minutes: 20),
        sourceId: 'boot:abc',
        deviceNow: DateTime.utc(2026, 8, 17, 10, 20),
      );

      expect(time.verified, isTrue);
      expect(time.utc, DateTime.utc(2026, 8, 17, 10, 20));
    });

    test('🔴 jam HP dimundurkan 3 jam — waktu watermark TIDAK ikut mundur', () {
      // Inti seluruh berkas ini. Packer memundurkan jam HP di tengah sesi agar
      // videonya seolah direkam sebelum batas kirim marketplace.
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint + const Duration(minutes: 20),
        sourceId: 'boot:abc',
        deviceNow: DateTime.utc(2026, 8, 17, 7, 20), // dimundurkan 3 jam
      );

      expect(time.utc, DateTime.utc(2026, 8, 17, 10, 20));
      expect(time.verified, isTrue);
      expect(time.deviceClockSuspect, isTrue);
      expect(time.deviceClockSkew, const Duration(hours: -3));
    });

    test('jam HP dimajukan setahun pun tidak mengubah hasilnya', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint,
        sourceId: 'boot:abc',
        deviceNow: DateTime.utc(2027, 8, 17, 10),
      );

      expect(time.utc, serverTime);
      expect(time.deviceClockSuspect, isTrue);
    });
  });

  group('toleransi ±2 menit (aturan 3)', () {
    test('selisih 1 menit dianggap wajar', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint,
        sourceId: 'boot:abc',
        deviceNow: serverTime.add(const Duration(minutes: 1)),
      );

      expect(time.deviceClockSuspect, isFalse);
    });

    test('selisih 3 menit ditandai, tetapi waktunya tetap terpakai', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint,
        sourceId: 'boot:abc',
        deviceNow: serverTime.add(const Duration(minutes: 3)),
      );

      expect(time.deviceClockSuspect, isTrue);
      // 🔴 Perekaman tidak boleh berhenti karena jam HP salah.
      expect(time.utc, serverTime);
      expect(time.verified, isTrue);
    });
  });

  group('belum pernah sinkron (aturan 4)', () {
    test('tanpa titik acuan → pakai jam HP, ditandai belum terverifikasi', () {
      final device = DateTime.utc(2026, 8, 17, 9, 30);
      final time = TimeSync.resolve(
        anchor: null,
        monotonicNow: const Duration(minutes: 3),
        sourceId: 'boot:abc',
        deviceNow: device,
      );

      expect(time.verified, isFalse);
      expect(time.utc, device);
    });
  });

  group('titik acuan gugur saat penghitungnya sudah tidak ada', () {
    test('🔴 HP dinyalakan ulang (boot_id berganti) → tidak dipakai', () {
      // Tanpa penjagaan ini, penghitung yang sudah kembali ke nol akan dibaca
      // seolah masih berlanjut, dan waktunya meleset berjam-jam tanpa gejala.
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:lama'),
        monotonicNow: anchorPoint + const Duration(minutes: 20),
        sourceId: 'boot:baru',
        deviceNow: DateTime.utc(2026, 8, 17, 10, 20),
      );

      expect(time.verified, isFalse);
      expect(time.utc, DateTime.utc(2026, 8, 17, 10, 20));
    });

    test('penghitung mundur → dianggap belum pernah sinkron', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint - const Duration(minutes: 1),
        sourceId: 'boot:abc',
        deviceNow: serverTime,
      );

      expect(time.verified, isFalse);
    });

    test('aplikasi ditutup lalu dibuka lagi tanpa sinyal (penghitung seumur '
        'proses) → belum terverifikasi, bukan diam-diam salah', () {
      final time = TimeSync.resolve(
        anchor: anchorAt('process:111'),
        monotonicNow: const Duration(minutes: 2),
        sourceId: 'process:222',
        deviceNow: DateTime.utc(2026, 8, 17, 12),
      );

      expect(time.verified, isFalse);
    });
  });

  group('kapan perlu tanya ulang ke server', () {
    test('belum punya titik acuan → perlu', () {
      expect(
        TimeSync.needsRefresh(
          anchor: null,
          monotonicNow: Duration.zero,
          sourceId: 'boot:abc',
        ),
        isTrue,
      );
    });

    test('baru 10 menit → belum perlu', () {
      expect(
        TimeSync.needsRefresh(
          anchor: anchorAt('boot:abc'),
          monotonicNow: anchorPoint + const Duration(minutes: 10),
          sourceId: 'boot:abc',
        ),
        isFalse,
      );
    });

    test('sudah lewat sejam → perlu', () {
      expect(
        TimeSync.needsRefresh(
          anchor: anchorAt('boot:abc'),
          monotonicNow: anchorPoint + const Duration(hours: 1, minutes: 1),
          sourceId: 'boot:abc',
        ),
        isTrue,
      );
    });

    test('titik acuan tua tetap DIPAKAI meski perlu disegarkan', () {
      // Penghitung monotonic tidak melar; acuan berumur 8 jam tetap sah.
      // "Perlu disegarkan" hanya berarti layak ditanyakan ulang bila ada sinyal.
      final time = TimeSync.resolve(
        anchor: anchorAt('boot:abc'),
        monotonicNow: anchorPoint + const Duration(hours: 8),
        sourceId: 'boot:abc',
        deviceNow: serverTime.add(const Duration(hours: 8)),
      );

      expect(time.verified, isTrue);
      expect(time.utc, DateTime.utc(2026, 8, 17, 18));
    });
  });

  group('titik acuan bertahan di penyimpanan', () {
    test('disimpan lalu dibaca kembali menghasilkan nilai yang sama', () {
      final original = anchorAt('boot:abc');
      final restored = TimeAnchor.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.serverTime, original.serverTime);
      expect(restored.monotonic, original.monotonic);
      expect(restored.sourceId, original.sourceId);
    });

    test('isi rusak menghasilkan null, bukan waktu yang salah', () {
      expect(TimeAnchor.fromJson(const {}), isNull);
      expect(
        TimeAnchor.fromJson(const {'server_time': 'bukan waktu'}),
        isNull,
      );
    });
  });
}
