import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/app_user.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/package_video.dart';
import 'package:kamelscan/core/models/tenant.dart';
import 'package:kamelscan/core/models/token_wallet.dart';

void main() {
  group('Pemetaan JSON snake_case ⇄ camelCase', () {
    test('AppUser membaca baris public.users apa adanya', () {
      final user = AppUser.fromJson(const {
        'id': 'u-1',
        'tenant_id': 't-1',
        'email': 'Budi@Contoh.com',
        'full_name': 'Budi Santoso',
        'role': 'owner',
        'is_active': true,
        'avatar_url': null,
        'created_at': '2026-08-01T03:00:00.000Z',
      });

      expect(user.tenantId, 't-1');
      expect(user.role, UserRole.owner);
      expect(user.isOwner, isTrue);
      expect(user.initials, 'BS');
      expect(user.createdAt, isNotNull);
    });

    test("VideoType 'return' dipetakan ke nama Dart `returned`", () {
      final video = _sampleVideoJson(type: 'return');
      expect(PackageVideo.fromJson(video).type, VideoType.returned);
      expect(VideoType.returned.wire, 'return');
    });

    test('VideoStatus pending_upload dipetakan benar', () {
      final video = PackageVideo.fromJson(_sampleVideoJson());
      expect(video.status, VideoStatus.pendingUpload);
      expect(VideoStatus.pendingUpload.wire, 'pending_upload');
    });
  });

  group('PackageVideo — retensi & lokasi', () {
    test('izin lokasi ditolak tetap menghasilkan video sah (Bab 1.3)', () {
      final video = PackageVideo.fromJson(_sampleVideoJson());
      expect(video.hasLocation, isFalse);
    });

    test('video melewati expires_at ditandai kedaluwarsa', () {
      final video = PackageVideo.fromJson(
        _sampleVideoJson(expiresAt: '2026-08-01T00:00:00.000Z'),
      );
      expect(video.isExpired(now: DateTime.utc(2026, 8, 12)), isTrue);
    });

    test('tautan publik tanpa token tidak pernah aktif', () {
      final video = PackageVideo.fromJson(_sampleVideoJson());
      expect(video.isPublicLinkActive(now: DateTime.utc(2026, 8, 12)), isFalse);
    });
  });

  group('Tenant — penguncian langganan (Bab 7.6)', () {
    test('status trial masih boleh merekam', () {
      final tenant = _tenant(status: 'trial');
      expect(tenant.canRecord, isTrue);
      expect(tenant.isTrial, isTrue);
    });

    test('status expired mengunci perekaman dan pemutaran', () {
      final tenant = _tenant(status: 'expired');
      expect(tenant.canRecord, isFalse);
      expect(tenant.canPlayVideo, isFalse);
    });

    test('trial tanpa period_end tidak punya hitung mundur', () {
      expect(_tenant(status: 'trial').daysUntilExpiry(), isNull);
    });

    test('peringatan muncul pada H-7, H-3, dan H-1', () {
      final now = DateTime.utc(2026, 8, 12);
      Tenant at(int days) => _tenant(
            status: 'active',
            periodEnd: now.add(Duration(days: days)).toIso8601String(),
          );

      expect(at(7).shouldWarnExpiry(now: now), isTrue);
      expect(at(3).shouldWarnExpiry(now: now), isTrue);
      expect(at(1).shouldWarnExpiry(now: now), isTrue);
      expect(at(5).shouldWarnExpiry(now: now), isFalse);
    });
  });

  group('TokenWallet — indikator kuota (Bab 7.3)', () {
    TokenWallet wallet(int balance) => TokenWallet(
          tenantId: 't-1',
          balance: balance,
          monthlyQuota: 1000,
          periodEnd: DateTime.utc(2026, 9, 1),
        );

    test('sisa di atas 20% dianggap normal', () {
      expect(wallet(500).isLow, isFalse);
      expect(wallet(500).isCritical, isFalse);
    });

    test('sisa 20% atau kurang berstatus rendah', () {
      expect(wallet(200).isLow, isTrue);
      expect(wallet(200).isCritical, isFalse);
    });

    test('sisa 5% atau kurang berstatus kritis', () {
      expect(wallet(50).isCritical, isTrue);
    });

    test('saldo 0 bukan low maupun critical, melainkan habis', () {
      expect(wallet(0).isExhausted, isTrue);
      expect(wallet(0).isLow, isFalse);
    });

    test('dompet trial dikenali dari period_end kosong (Bab 7.5)', () {
      const trialWallet =
          TokenWallet(tenantId: 't-1', balance: 62, monthlyQuota: 100);
      expect(trialWallet.isTrialWallet, isTrue);
      expect(trialWallet.used, 38);
    });
  });
}

Map<String, dynamic> _sampleVideoJson({
  String type = 'packing',
  String expiresAt = '2026-09-11T00:00:00.000Z',
}) =>
    {
      'id': 'v-1',
      'tenant_id': 't-1',
      'shop_id': 's-1',
      'user_id': 'u-1',
      'resi_code': 'SPX1234567890',
      'type': type,
      'status': 'pending_upload',
      'scan_date': '2026-08-12T02:00:00.000Z',
      'expires_at': expiresAt,
      'location_lat': null,
      'location_lng': null,
    };

Tenant _tenant({required String status, String? periodEnd}) => Tenant.fromJson({
      'id': 't-1',
      'owner_id': 'u-1',
      'tier_plan': 'standar',
      'status': status,
      'trial_used': true,
      'period_end': periodEnd,
    });
