import '../../l10n/generated/app_localizations.dart';
import '../models/enums.dart';

/// Nama paket untuk ditampilkan.
///
/// Ditaruh di sebelah katalognya supaya paket baru hanya menuntut satu tempat
/// disunting. `switch` tanpa `default` disengaja: menambah nilai [TierPlan]
/// tanpa menyediakan namanya akan gagal saat kompilasi, bukan muncul sebagai
/// kartu tanpa judul di halaman harga Admin.
/// Durasi maksimal rekam, dalam satuan yang wajar dibaca.
///
/// "180 detik per video" benar tetapi tidak ada yang menulis begitu; paket
/// Bisnis dijual sebagai "3 menit". Detik dipakai selama masih di bawah satu
/// menit atau tidak bulat.
String labelDurasi(AppL10n t, int detik) => detik >= 60 && detik % 60 == 0
    ? t.durationMinutes(detik ~/ 60)
    : t.durationSeconds(detik);

String labelTier(AppL10n t, TierPlan plan) => switch (plan) {
  TierPlan.standar => t.tierStandar,
  TierPlan.pro => t.tierPro,
  TierPlan.bisnis => t.tierBisnis,
};

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

  /// Salinan dengan sebagian nilai diganti — dipakai formulir Bab 11.3.
  ///
  /// `plan` sengaja TIDAK dapat diganti: ia menentukan baris mana yang ditulis
  /// di `platform_settings.pricing`, dan menukarnya berarti menyimpan harga
  /// Pro ke tempat Standar tanpa satu pun galat.
  TierConfig copyWith({
    int? maxVideoSeconds,
    int? retentionDays,
    int? maxPackers,
    int? monthlyTokens,
    num? price,
  }) => TierConfig(
    plan: plan,
    maxVideoSeconds: maxVideoSeconds ?? this.maxVideoSeconds,
    retentionDays: retentionDays ?? this.retentionDays,
    maxPackers: maxPackers ?? this.maxPackers,
    monthlyTokens: monthlyTokens ?? this.monthlyTokens,
    price: price ?? this.price,
  );

  Map<String, dynamic> toJson() => {
    'max_video_seconds': maxVideoSeconds,
    'retention_days': retentionDays,
    'max_packers': maxPackers,
    'monthly_tokens': monthlyTokens,
    'price': price,
  };
}

/// Kumpulan tier yang sedang berlaku, hasil parse `platform_settings.pricing`.
///
/// 🔴 Berbentuk **peta**, bukan dua field bernama `standar` dan `pro`.
/// Sampai 30 Agustus 2026 ia menyimpan keduanya sebagai field terpisah, dan
/// menambah paket ketiga berarti menyentuh setiap tempat yang menyebut nama
/// paket satu per satu — halaman harga Admin, halaman pembayaran, katalog
/// cadangan. Bentuk peta membuat paket keempat suatu hari nanti hanya menuntut
/// satu nilai enum baru.
class TierCatalog {
  const TierCatalog({required this.tiers, required this.trial});

  final Map<TierPlan, TierConfig> tiers;
  final TrialConfig trial;

  /// Aturan paket [plan]. Jatuh ke nilai cadangan bila `pricing` di server
  /// belum memuat paket itu — pelanggan tidak boleh melihat layar kosong hanya
  /// karena Admin belum mengisi satu baris pengaturan.
  TierConfig of(TierPlan plan) => tiers[plan] ?? fallbackFor(plan);

  /// Seluruh paket berbayar, urut dari termurah. Dipakai halaman pembayaran
  /// dan halaman harga Admin supaya keduanya tidak perlu menyebut nama paket.
  List<TierConfig> get semua =>
      TierPlan.values.map(of).toList(growable: false);

  /// Nilai cadangan — sama dengan seed `platform_settings` di Bab 5.2.
  static const TierConfig _standarFallback = TierConfig(
    plan: TierPlan.standar,
    maxVideoSeconds: 30,
    retentionDays: 30,
    maxPackers: -1,
    monthlyTokens: 2000,
    price: 149000,
  );

  static const TierConfig _proFallback = TierConfig(
    plan: TierPlan.pro,
    maxVideoSeconds: 60,
    retentionDays: 30,
    maxPackers: -1,
    monthlyTokens: 5000,
    price: 299000,
  );

  static const TierConfig _bisnisFallback = TierConfig(
    plan: TierPlan.bisnis,
    maxVideoSeconds: 180,
    retentionDays: 30,
    maxPackers: -1,
    monthlyTokens: 30000,
    price: 1490000,
  );

  static TierConfig fallbackFor(TierPlan plan) => switch (plan) {
    TierPlan.standar => _standarFallback,
    TierPlan.pro => _proFallback,
    TierPlan.bisnis => _bisnisFallback,
  };

  static const TierCatalog fallback = TierCatalog(
    tiers: {
      TierPlan.standar: _standarFallback,
      TierPlan.pro: _proFallback,
      TierPlan.bisnis: _bisnisFallback,
    },
    trial: TrialConfig.fallback,
  );

  factory TierCatalog.fromPricingJson(
    Map<String, dynamic> pricing, {
    Map<String, dynamic>? trial,
  }) {
    return TierCatalog(
      tiers: {
        for (final plan in TierPlan.values)
          plan: TierConfig.fromJson(
            plan,
            (pricing[plan.wire] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
      },
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
    required this.maxPackers,
  });

  final int tokens;
  final TierPlan tier;
  final bool enabled;

  /// 🔴 Batas packer MILIK masa uji coba sendiri, bukan pinjaman dari tier
  /// [tier].
  ///
  /// Sampai 31 Agustus 2026 field ini tidak ada, dan masa uji coba memakai
  /// seluruh konfigurasi paket Standar. Begitu Standar disetel tak terbatas
  /// (keputusan hari itu), masa uji coba ikut menjadi tak terbatas — tanpa
  /// satu pun galat, dan seorang pendaftar baru dapat membuat seratus akun
  /// packer tanpa membayar sepeser pun.
  final int maxPackers;

  static const TrialConfig fallback = TrialConfig(
    tokens: 100,
    tier: TierPlan.standar,
    enabled: true,
    maxPackers: 5,
  );

  factory TrialConfig.fromJson(Map<String, dynamic> json) => TrialConfig(
    tokens: (json['tokens'] as num?)?.toInt() ?? fallback.tokens,
    tier: TierPlan.fromWire(json['tier'] as String?),
    enabled: json['enabled'] as bool? ?? fallback.enabled,
    maxPackers: (json['max_packers'] as num?)?.toInt() ?? fallback.maxPackers,
  );
}
