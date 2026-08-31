import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/enums.dart';

void main() {
  group('TierCatalog.fromPricingJson — seed platform_settings (Bab 5.2)', () {
    // Persis isi `platform_settings.pricing` sesudah migrasi 39
    // (31 Agustus 2026). Angka lama: Standar 99.000/1.000 token dengan batas
    // 5 packer, Pro 249.000 dengan retensi 60 hari.
    const pricing = <String, dynamic>{
      'standar': {
        'price': 149000,
        'max_video_seconds': 30,
        'retention_days': 30,
        'max_packers': -1,
        'monthly_tokens': 2000,
      },
      'pro': {
        'price': 299000,
        'max_video_seconds': 60,
        'retention_days': 30,
        'max_packers': -1,
        'monthly_tokens': 5000,
      },
      'bisnis': {
        'price': 1490000,
        'max_video_seconds': 180,
        'retention_days': 30,
        'max_packers': -1,
        'monthly_tokens': 30000,
      },
    };

    test('membaca angka tier Standar', () {
      final catalog = TierCatalog.fromPricingJson(pricing);
      final standar = catalog.of(TierPlan.standar);

      expect(standar.maxVideoSeconds, 30);
      expect(standar.retentionDays, 30);
      expect(standar.hasUnlimitedPackers, isTrue);
      expect(standar.monthlyTokens, 2000);
      expect(standar.price, 149000);
    });

    test('Pro punya packer tak terbatas dan durasi rekam lebih panjang', () {
      final pro = TierCatalog.fromPricingJson(pricing).of(TierPlan.pro);

      expect(pro.hasUnlimitedPackers, isTrue);
      expect(pro.maxRecordingDuration, const Duration(seconds: 60));
    });

    // Sejak 31 Agustus 2026 tidak ada satu pun paket berbayar yang membatasi
    // packer, tetapi kemampuan membacanya tetap harus benar — masa uji coba
    // memakainya, dan Admin dapat memasang batas lagi kapan saja lewat
    // pengaturan tanpa merilis aplikasi baru.
    test('batas packer bernilai positif tetap ditegakkan', () {
      final terbatas = TierCatalog.fromPricingJson(const {
        'standar': {'max_packers': 5},
      }).of(TierPlan.standar);

      expect(terbatas.canAddPacker(4), isTrue);
      expect(terbatas.canAddPacker(5), isFalse);
    });

    test('kolom yang hilang jatuh ke nilai cadangan, bukan nol', () {
      final catalog = TierCatalog.fromPricingJson({'standar': <String, dynamic>{}});
      final standar = catalog.of(TierPlan.standar);

      expect(standar.monthlyTokens, 2000);
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
