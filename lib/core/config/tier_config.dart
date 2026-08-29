import '../models/enums.dart';

/// SATU-SATUNYA tempat aturan tier hidup di sisi klien (Bab 7.1).
///
/// ⚠️ Nilai sebenarnya **dibaca dari `platform_settings.pricing`** agar Admin
/// bisa mengubah harga/kuota tanpa rilis aplikasi baru. Konstanta di kelas
/// [TierCatalog] hanya dipakai sebagai cadangan saat perangkat offline dan
/// belum pernah menyinkronkan pricing.
///
/// Aturan ini **tidak** menggantikan penegakan di database. Semua batas juga
/// ditegakkan trigger/constraint di server (Bab 7.4).
class TierConfig {
  const TierConfig({
    required this.plan,
    required this.maxVideoSeconds,
    required this.retentionDays,
    required this.maxPackers,
    required this.monthlyTokens,
    required this.price,
  });

  final TierPlan plan;
  final int maxVideoSeconds;
  final int retentionDays;

  /// -1 = tidak terbatas.
  final int maxPackers;
  final int monthlyTokens;
  final num price;


  bool get hasUnlimitedPackers => maxPackers < 0;

  Duration get maxRecordingDuration => Duration(seconds: maxVideoSeconds);

  Duration get retention => Duration(days: retentionDays);

  bool canAddPacker(int currentPackerCount) =>
      hasUnlimitedPackers || currentPackerCount < maxPackers;

  factory TierConfig.fromJson(TierPlan plan, Map<String, dynamic> json) {
    int asInt(String key, int fallback) {
      final v = json[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final fallback = TierCatalog.fallbackFor(plan);
    return TierConfig(
      plan: plan,
      maxVideoSeconds: asInt('max_video_seconds', fallback.maxVideoSeconds),
      retentionDays: asInt('retention_days', fallback.retentionDays),
      maxPackers: asInt('max_packers', fallback.maxPackers),
      monthlyTokens: asInt('monthly_tokens', fallback.monthlyTokens),
      price: (json['price'] as num?) ?? fallback.price,
    );
  }

  Map<String, dynamic> toJson() => {
        'max_video_seconds': maxVideoSeconds,
        'retention_days': retentionDays,
        'max_packers': maxPackers,
        'monthly_tokens': monthlyTokens,
        'price': price,
      };
}

/// Kumpulan tier yang sedang berlaku, hasil parse `platform_settings.pricing`.
class TierCatalog {
  const TierCatalog({required this.standar, required this.pro, required this.trial});

  final TierConfig standar;
  final TierConfig pro;
  final TrialConfig trial;

  TierConfig of(TierPlan plan) => plan == TierPlan.pro ? pro : standar;

  /// Nilai cadangan — sama dengan seed `platform_settings` di Bab 5.2.
  static const TierConfig _standarFallback = TierConfig(
    plan: TierPlan.standar,
    maxVideoSeconds: 30,
    retentionDays: 30,
    maxPackers: 5,
    monthlyTokens: 1000,
    price: 99000,
  );

  static const TierConfig _proFallback = TierConfig(
    plan: TierPlan.pro,
    maxVideoSeconds: 60,
    retentionDays: 60,
    maxPackers: -1,
    monthlyTokens: 5000,
    price: 249000,
  );

  static TierConfig fallbackFor(TierPlan plan) =>
      plan == TierPlan.pro ? _proFallback : _standarFallback;

  static const TierCatalog fallback = TierCatalog(
    standar: _standarFallback,
    pro: _proFallback,
    trial: TrialConfig.fallback,
  );

  factory TierCatalog.fromPricingJson(
    Map<String, dynamic> pricing, {
    Map<String, dynamic>? trial,
  }) {
    return TierCatalog(
      standar: TierConfig.fromJson(
        TierPlan.standar,
        (pricing['standar'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      pro: TierConfig.fromJson(
        TierPlan.pro,
        (pricing['pro'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      trial: trial == null ? TrialConfig.fallback : TrialConfig.fromJson(trial),
    );
  }
}

/// Masa uji coba gratis (Bab 7.5): 100 video, sekali per akun, tanpa batas waktu.
class TrialConfig {
  const TrialConfig({
    required this.tokens,
    required this.tier,
    required this.enabled,
  });

  final int tokens;
  final TierPlan tier;
  final bool enabled;

  static const TrialConfig fallback =
      TrialConfig(tokens: 100, tier: TierPlan.standar, enabled: true);

  factory TrialConfig.fromJson(Map<String, dynamic> json) => TrialConfig(
        tokens: (json['tokens'] as num?)?.toInt() ?? fallback.tokens,
        tier: TierPlan.fromWire(json['tier'] as String?),
        enabled: json['enabled'] as bool? ?? fallback.enabled,
      );
}
