import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/enums.dart';

void main() {
  group('TierCatalog.fromPricingJson — seed platform_settings (Bab 5.2)', () {
    // Persis isi `insert into public.platform_settings ... ('pricing', ...)`.
    const pricing = <String, dynamic>{
      'standar': {
        'price': 99000,
        'max_video_seconds': 30,
        'retention_days': 30,
        'max_packers': 5,
        'monthly_tokens': 1000,
      },
      'pro': {
        'price': 249000,
        'max_video_seconds': 60,
        'retention_days': 60,
        'max_packers': -1,
        'monthly_tokens': 5000,
      },
    };

    test('membaca angka tier Standar', () {
      final catalog = TierCatalog.fromPricingJson(pricing);
      final standar = catalog.of(TierPlan.standar);

      expect(standar.maxVideoSeconds, 30);
      expect(standar.retentionDays, 30);
      expect(standar.maxPackers, 5);
      expect(standar.monthlyTokens, 1000);
      expect(standar.price, 99000);
    });

    test('Pro punya packer tak terbatas dan watermark kustom', () {
      final pro = TierCatalog.fromPricingJson(pricing).of(TierPlan.pro);

      expect(pro.hasUnlimitedPackers, isTrue);
      expect(pro.allowsCustomWatermark, isTrue);
      expect(pro.maxRecordingDuration, const Duration(seconds: 60));
    });

    test('Standar tidak boleh memakai watermark logo kustom', () {
      final standar = TierCatalog.fromPricingJson(pricing).of(TierPlan.standar);
      expect(standar.allowsCustomWatermark, isFalse);
    });

    test('batas packer Standar ditegakkan pada angka 5', () {
      final standar = TierCatalog.fromPricingJson(pricing).of(TierPlan.standar);

      expect(standar.canAddPacker(4), isTrue);
      expect(standar.canAddPacker(5), isFalse);
    });

    test('kolom yang hilang jatuh ke nilai cadangan, bukan nol', () {
      final catalog = TierCatalog.fromPricingJson({'standar': <String, dynamic>{}});
      final standar = catalog.of(TierPlan.standar);

      expect(standar.monthlyTokens, 1000);
      expect(standar.retentionDays, 30);
    });
  });

  group('TrialConfig — uji coba gratis (Bab 7.5)', () {
    test('default 100 video setara tier Standar', () {
      const trial = TrialConfig.fallback;

      expect(trial.tokens, 100);
      expect(trial.tier, TierPlan.standar);
      expect(trial.enabled, isTrue);
    });

    test('dibaca dari platform_settings.trial', () {
      final trial = TrialConfig.fromJson(const {
        'tokens': 50,
        'tier': 'pro',
        'enabled': false,
      });

      expect(trial.tokens, 50);
      expect(trial.tier, TierPlan.pro);
      expect(trial.enabled, isFalse);
    });
  });
}
