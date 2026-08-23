import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/quota_status.dart';
import 'package:kamelscan/core/models/home_stats.dart';

/// Bab 9.2 — kartu monitoring Beranda.
///
/// Yang diuji di sini adalah **jembatan** antara RPC `get_home_stats()` dan
/// layar: pemetaan nama kolom, dan keadaan-keadaan yang mudah salah dibaca
/// (dompet belum ada vs saldo habis). Angka agregatnya sendiri dihitung
/// PostgreSQL dan sudah dibuktikan dengan JWT sungguhan — hasilnya tercatat di
/// `supabase/README.md`.
void main() {
  /// Bentuk yang benar-benar dikembalikan RPC, disalin dari hasil pengujian
  /// 18 Agustus 2026 pada tenant "Sarang sarung" (27 video, saldo 73).
  Map<String, dynamic> rpcJson({
    int packing = 27,
    int returned = 0,
    int pending = 0,
    int failed = 0,
    Object? balance = 73,
    Object? quota = 100,
  }) =>
      <String, dynamic>{
        'period_start': '2026-08-13T02:14:11.523+00:00',
        'packing_count': packing,
        'return_count': returned,
        'pending_upload': pending,
        'failed_upload': failed,
        'token_balance': balance,
        'token_quota': quota,
      };

  group('HomeStats.fromJson — pemetaan kolom RPC', () {
    test('seluruh kolom snake_case terbaca', () {
      final stats = HomeStats.fromJson(rpcJson(returned: 4, pending: 2, failed: 1));

      expect(stats.packingCount, 27);
      expect(stats.returnCount, 4);
      expect(stats.pendingUpload, 2);
      expect(stats.failedUpload, 1);
      expect(stats.tokenBalance, 73);
      expect(stats.tokenQuota, 100);
    });

    test('period_start terbaca sebagai waktu, bukan teks', () {
      final stats = HomeStats.fromJson(rpcJson());

      expect(stats.periodStart.toUtc().year, 2026);
      expect(stats.periodStart.toUtc().month, 8);
      expect(stats.periodStart.toUtc().day, 13);
    });

    test('total video adalah jumlah kedua tipe', () {
      expect(HomeStats.fromJson(rpcJson(returned: 4)).totalVideos, 31);
    });
  });

  group('Dompet yang belum terbentuk ≠ saldo habis', () {
    test('token null tetap null, tidak diam-diam menjadi 0', () {
      final stats = HomeStats.fromJson(rpcJson(balance: null, quota: null));

      expect(stats.tokenBalance, isNull);
      expect(stats.tokenQuota, isNull);
    });

    test('kuota 0 tidak membagi nol saat dijadikan QuotaStatus', () {
      final quota =
          HomeStats.fromJson(rpcJson(balance: null, quota: null))
              .quota(isTrial: true);

      expect(quota.ratio, 0);
      expect(quota.level, QuotaLevel.exhausted);
    });
  });

  group('quota() memakai ambang Bab 7.3 yang sudah teruji', () {
    test('saldo 73 dari 100 masih normal', () {
      final quota = HomeStats.fromJson(rpcJson()).quota(isTrial: true);

      expect(quota.level, QuotaLevel.normal);
      expect(quota.isTrial, isTrue);
      expect(quota.used, 27);
    });

    test('sisa 5 dari 100 sudah kritis dan memunculkan spanduk Beranda', () {
      final quota =
          HomeStats.fromJson(rpcJson(balance: 5)).quota(isTrial: false);

      expect(quota.level, QuotaLevel.critical);
      expect(quota.level.needsHomeBanner, isTrue);
      expect(quota.bannerKey, 'quotaLowBanner');
    });

    test('uji coba habis memakai kalimat yang berbeda dari pelanggan berbayar',
        () {
      expect(
        HomeStats.fromJson(rpcJson(balance: 0)).quota(isTrial: true).bannerKey,
        'trialExhaustedBanner',
      );
      expect(
        HomeStats.fromJson(rpcJson(balance: 0)).quota(isTrial: false).bannerKey,
        'quotaExhaustedBanner',
      );
    });
  });

  group('Kondisi kosong — Bab 3.4', () {
    test('nol video pada periode berjalan dianggap kosong', () {
      expect(HomeStats.fromJson(rpcJson(packing: 0)).isEmpty, isTrue);
    });

    test('satu video saja sudah tidak kosong', () {
      expect(HomeStats.fromJson(rpcJson(packing: 0, returned: 1)).isEmpty,
          isFalse);
    });

    test('video gagal unggah ditandai agar Beranda dapat memberitahukannya', () {
      expect(HomeStats.fromJson(rpcJson()).hasFailedUploads, isFalse);
      expect(HomeStats.fromJson(rpcJson(failed: 3)).hasFailedUploads, isTrue);
    });
  });
}
