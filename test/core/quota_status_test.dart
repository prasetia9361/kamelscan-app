import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/quota_status.dart';
import 'package:kamelscan/core/models/enums.dart';

void main() {
  group('QuotaStatus — ambang Bab 7.3', () {
    QuotaStatus q(int balance, {int quota = 1000, bool trial = false}) =>
        QuotaStatus(balance: balance, quota: quota, isTrial: trial);

    test('sisa > 20% berwarna normal', () {
      expect(q(1000).level, QuotaLevel.normal);
      expect(q(201).level, QuotaLevel.normal);
    });

    test('sisa tepat 20% sudah masuk peringatan', () {
      // Dokumen menulis "Sisa ≤ 20%", jadi 200/1000 IKUT, bukan dikecualikan.
      expect(q(200).level, QuotaLevel.warning);
    });

    test('sisa antara 5% dan 20% adalah peringatan', () {
      expect(q(199).level, QuotaLevel.warning);
      expect(q(51).level, QuotaLevel.warning);
    });

    test('sisa tepat 5% sudah masuk kritis', () {
      expect(q(50).level, QuotaLevel.critical);
    });

    test('sisa di bawah 5% tetap kritis selama belum nol', () {
      expect(q(49).level, QuotaLevel.critical);
      expect(q(1).level, QuotaLevel.critical);
    });

    test('sisa nol berarti habis, bukan kritis', () {
      expect(q(0).level, QuotaLevel.exhausted);
      expect(q(0).isExhausted, isTrue);
    });

    test('hanya nol yang memblokir perekaman', () {
      expect(q(1).level.blocksRecording, isFalse);
      expect(q(0).level.blocksRecording, isTrue);
    });

    test('spanduk Beranda muncul mulai peringatan, tidak pada normal', () {
      expect(q(1000).level.needsHomeBanner, isFalse);
      expect(q(200).level.needsHomeBanner, isTrue);
      expect(q(50).level.needsHomeBanner, isTrue);
    });

    test('dialog sebelum merekam hanya pada kondisi kritis', () {
      expect(q(200).level.needsRecordingDialog, isFalse);
      expect(q(50).level.needsRecordingDialog, isTrue);
      // Saat habis, menunya sudah dinonaktifkan — dialognya tidak relevan.
      expect(q(0).level.needsRecordingDialog, isFalse);
    });

    test('kuota nol tidak menyebabkan pembagian nol', () {
      const zero = QuotaStatus(balance: 0, quota: 0, isTrial: false);
      expect(zero.ratio, 0);
      expect(zero.level, QuotaLevel.exhausted);
    });

    test('saldo minus tidak pernah menghasilkan rasio negatif', () {
      expect(q(-5).ratio, 0);
      expect(q(-5).level, QuotaLevel.exhausted);
    });

    test('terpakai dihitung dari kuota dikurangi sisa', () {
      expect(q(380, quota: 1000).used, 620);
      expect(q(0, quota: 100).used, 100);
    });

    test('pesan uji coba berbeda dari pesan pelanggan berbayar (Bab 7.5)', () {
      expect(q(10, quota: 100, trial: true).bannerKey, 'trialLowBanner');
      expect(q(10, quota: 100).bannerKey, 'quotaLowBanner');
      expect(q(0, quota: 100, trial: true).bannerKey, 'trialExhaustedBanner');
      expect(q(0, quota: 100).bannerKey, 'quotaExhaustedBanner');
      expect(q(1000).bannerKey, isNull);
    });

    test('skenario uji coba 100 video (Bab 7.5)', () {
      // Bab 7.5: spanduk ajakan berlangganan pada sisa <= 20.
      expect(q(62, quota: 100, trial: true).level, QuotaLevel.normal);
      expect(q(20, quota: 100, trial: true).level, QuotaLevel.warning);
      expect(q(5, quota: 100, trial: true).level, QuotaLevel.critical);
      expect(q(0, quota: 100, trial: true).level, QuotaLevel.exhausted);
    });
  });

  group('SubscriptionStatus — peringatan Bab 7.6', () {
    final now = DateTime(2026, 8, 13, 10);

    SubscriptionStatus sub(int daysFromNow, {
      TenantStatus status = TenantStatus.active,
      bool trial = false,
    }) =>
        SubscriptionStatus(
          tenantStatus: status,
          periodEnd: DateTime(2026, 8, 13).add(Duration(days: daysFromNow)),
          isTrial: trial,
          now: now,
        );

    test('sisa hari dihitung per hari, bukan per jam', () {
      expect(sub(7).daysRemaining, 7);
      expect(sub(0).daysRemaining, 0);
    });

    test('uji coba tidak punya batas waktu sama sekali (Bab 7.5)', () {
      final trial = SubscriptionStatus(
        tenantStatus: TenantStatus.trial,
        periodEnd: null,
        isTrial: true,
        now: now,
      );
      expect(trial.daysRemaining, isNull);
      expect(trial.shouldWarnExpiry, isFalse);
      expect(trial.warningDay, isNull);
    });

    test('belum diperingatkan bila masih lebih dari 7 hari', () {
      expect(sub(8).shouldWarnExpiry, isFalse);
      expect(sub(8).warningDay, isNull);
    });

    test('peringatan menyala mulai H-7', () {
      expect(sub(7).shouldWarnExpiry, isTrue);
      expect(sub(7).warningDay, 7);
    });

    test('ambang mengetat mengikuti sisa hari', () {
      // Bab 7.6 menyebut H-7, H-3, H-1. Pengguna yang tidak membuka aplikasi
      // tepat pada hari itu tetap harus diperingatkan.
      expect(sub(6).warningDay, 7);
      expect(sub(4).warningDay, 7);
      expect(sub(3).warningDay, 3);
      expect(sub(2).warningDay, 3);
      expect(sub(1).warningDay, 1);
      expect(sub(0).warningDay, 1);
    });

    test('tenant kedaluwarsa tidak diperingatkan lagi — sudah terkunci', () {
      final expired = sub(0, status: TenantStatus.expired);
      expect(expired.isExpired, isTrue);
      expect(expired.isActive, isFalse);
      expect(expired.shouldWarnExpiry, isFalse);
    });

    test('tenant ditangguhkan juga tidak boleh merekam', () {
      expect(sub(30, status: TenantStatus.suspended).isActive, isFalse);
      expect(sub(30, status: TenantStatus.suspended).isSuspended, isTrue);
    });

    test('trial dan active sama-sama boleh merekam', () {
      expect(sub(30).isActive, isTrue);
      expect(sub(30, status: TenantStatus.trial).isActive, isTrue);
    });
  });
}
