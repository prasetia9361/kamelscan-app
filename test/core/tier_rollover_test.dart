import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/enums.dart';

/// Tiga paket dan model token akumulatif (Bab 7.1 & 7.2, direvisi
/// 31 Agustus 2026).
///
/// 🔴 Angka-angka di berkas ini adalah **harga jual**. Kalau salah satunya
/// bergeser tanpa sengaja, yang terjadi bukan tampilan yang jelek melainkan
/// pelanggan ditagih angka yang salah — dan tidak ada satu pun galat yang
/// muncul untuk memberitahunya. Nilai cadangan inilah yang dipakai saat
/// perangkat belum pernah menyinkronkan `platform_settings.pricing`, jadi ia
/// benar-benar tampil di layar orang.
void main() {
  const katalog = TierCatalog.fallback;

  group('Tiga paket, dan hanya tiga hal yang membedakannya', () {
    test('harga, token, dan durasi sesuai keputusan 31 Agustus 2026', () {
      final standar = katalog.of(TierPlan.standar);
      final pro = katalog.of(TierPlan.pro);
      final bisnis = katalog.of(TierPlan.bisnis);

      expect(standar.price, 149000);
      expect(standar.monthlyTokens, 2000);
      expect(standar.maxVideoSeconds, 30);

      expect(pro.price, 299000);
      expect(pro.monthlyTokens, 5000);
      expect(pro.maxVideoSeconds, 60);

      expect(bisnis.price, 1490000);
      expect(bisnis.monthlyTokens, 30000);
      expect(bisnis.maxVideoSeconds, 180, reason: '3 menit, bukan 5');
    });

    test('retensi 30 hari untuk ketiganya', () {
      for (final plan in TierPlan.values) {
        expect(
          katalog.of(plan).retentionDays,
          30,
          reason: 'retensi $plan harus seragam',
        );
      }
    });

    test('packer tak terbatas untuk ketiganya', () {
      for (final plan in TierPlan.values) {
        expect(katalog.of(plan).hasUnlimitedPackers, isTrue);
      }
    });
  });

  group('Masa uji coba punya batas packer sendiri', () {
    // 🔴 Cacat yang nyaris lolos diam-diam. Sampai 31 Agustus 2026
    // `TrialConfig` tidak punya `maxPackers`, sehingga masa uji coba meminjam
    // SELURUH konfigurasi paket Standar. Begitu Standar disetel tak terbatas,
    // masa uji coba ikut tak terbatas — tanpa satu pun galat, dan pendaftar
    // baru dapat membuat seratus akun packer tanpa membayar sepeser pun.
    test('lima, walaupun paket yang dipinjamnya tak terbatas', () {
      expect(katalog.trial.maxPackers, 5);
      expect(katalog.of(katalog.trial.tier).hasUnlimitedPackers, isTrue);
    });

    test('konfigurasi efektifnya benar-benar membatasi', () {
      final efektif = katalog
          .of(katalog.trial.tier)
          .copyWith(maxPackers: katalog.trial.maxPackers);

      expect(efektif.canAddPacker(4), isTrue);
      expect(efektif.canAddPacker(5), isFalse);
    });

    test('dibaca dari platform_settings, bukan ditulis mati', () {
      final dari = TierCatalog.fromPricingJson(
        const {},
        trial: const {'tokens': 100, 'tier': 'standar', 'max_packers': 3},
      );

      expect(dari.trial.maxPackers, 3);
    });

    test('pengaturan lama tanpa max_packers jatuh ke 5, bukan tak terbatas', () {
      // Baris `trial` yang belum disentuh migrasi 39 tidak punya kunci itu.
      // Yang aman adalah membatasi, bukan membebaskan.
      final dari = TierCatalog.fromPricingJson(
        const {},
        trial: const {'tokens': 100, 'tier': 'standar'},
      );

      expect(dari.trial.maxPackers, 5);
    });
  });

  group('Urutan paket menentukan mana yang turun', () {
    // Dipakai layar checkout untuk memutuskan apakah sebuah pembelian
    // MENURUNKAN paket dan karena itu wajib memunculkan peringatan durasi
    // (Bab 12.4).
    test('standar < pro < bisnis', () {
      expect(TierPlan.standar.lebihRendahDari(TierPlan.pro), isTrue);
      expect(TierPlan.pro.lebihRendahDari(TierPlan.bisnis), isTrue);
      expect(TierPlan.standar.lebihRendahDari(TierPlan.bisnis), isTrue);
    });

    test('paket yang sama bukan penurunan', () {
      for (final plan in TierPlan.values) {
        expect(plan.lebihRendahDari(plan), isFalse);
      }
    });

    test('naik paket bukan penurunan', () {
      expect(TierPlan.bisnis.lebihRendahDari(TierPlan.standar), isFalse);
      expect(TierPlan.pro.lebihRendahDari(TierPlan.standar), isFalse);
    });
  });

  group('Pembacaan wire', () {
    test('bisnis dikenali', () {
      expect(TierPlan.fromWire('bisnis'), TierPlan.bisnis);
    });

    // 🔴 Nilai tak dikenal jatuh ke paket TERENDAH, bukan tertinggi. Aplikasi
    // lama yang membaca tenant berpaket baru akan membatasi, bukan memberi
    // durasi rekam yang tidak dibayar.
    test('nilai asing jatuh ke standar, bukan ke paket tertinggi', () {
      expect(TierPlan.fromWire('enterprise'), TierPlan.standar);
      expect(TierPlan.fromWire(null), TierPlan.standar);
      expect(TierPlan.fromWire(''), TierPlan.standar);
    });
  });

  group('Paket baru tidak boleh menghilang saat Admin menyimpan', () {
    // `savePricing` menulis ulang seluruh baris `platform_settings.pricing`.
    // Paket yang tidak ikut terkirim akan LENYAP dari pengaturan tanpa satu pun
    // galat — dan pelanggan yang sedang memakainya jatuh ke nilai cadangan.
    test('katalog memuat seluruh nilai enum', () {
      expect(katalog.semua, hasLength(TierPlan.values.length));
      expect(
        katalog.semua.map((e) => e.plan).toList(),
        TierPlan.values,
        reason: 'urutannya juga mengikat — kartu harga tampil berurutan',
      );
    });

    test('paket yang belum ada di pricing tetap punya nilai cadangan', () {
      final sebagian = TierCatalog.fromPricingJson(const {
        'standar': {'price': 111, 'monthly_tokens': 1},
      });

      expect(sebagian.of(TierPlan.standar).price, 111);
      expect(sebagian.of(TierPlan.bisnis).price, 1490000);
      expect(sebagian.of(TierPlan.bisnis).maxVideoSeconds, 180);
    });
  });
}
