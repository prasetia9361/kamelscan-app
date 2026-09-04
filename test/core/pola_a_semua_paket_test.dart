import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/l10n/generated/app_localizations.dart';
import 'package:kamelscan/pages/admin/settings/admin_promos_page.dart';

/// **Pola A** — paket disebut satu per satu, dan Bisnis selalu jadi korbannya.
///
/// 🔴 Kemunculan kelima di proyek ini, ditemukan Product Owner 4 September 2026
/// saat membuka dialog promo dan melihat dropdown hanya berisi *Semua paket*,
/// *Standar*, dan *Pro*. Empat kemunculan sebelumnya: `admin_pricing_page`,
/// `create-payment`, `admin_banners_page`, dan tes salah satunya sendiri.
///
/// Bentuknya selalu sama, dan selalu lolos analyze:
///
/// ```dart
/// plan == TierPlan.pro ? t.tierPro : t.tierStandar   // Bisnis -> "Standar"
/// items: [ ...standar, ...pro ]                       // Bisnis tak terpilih
/// ```
///
/// Keduanya sah menurut kompilator. Tidak ada satu pun galat yang menandai
/// paket yang hilang — yang ada hanya Admin yang tidak dapat membuat promo
/// Bisnis, dan promo Bisnis yang tertulis "Standar".
void main() {
  // ==========================================================================
  // Nama paket — perilaku sungguhan, bukan pembacaan berkas
  // ==========================================================================
  group('🔴 namaPaket menjawab ketiga paket', () {
    late AppL10n t;

    setUpAll(() async {
      t = await AppL10n.delegate.load(const Locale('id'));
    });

    test('tiap paket punya namanya sendiri', () {
      final nama = {for (final p in TierPlan.values) p: namaPaket(t, p)};

      // Inti tesnya: TIGA nama yang berbeda. Bentuk lamanya menghasilkan dua —
      // Bisnis memakai nama Standar — dan itu lolos tanpa galat apa pun.
      expect(
        nama.values.toSet().length,
        TierPlan.values.length,
        reason: 'ada paket yang memakai nama paket lain: $nama',
      );
    });

    test('tidak ada yang kosong', () {
      for (final p in TierPlan.values) {
        expect(namaPaket(t, p).trim(), isNotEmpty, reason: 'nama $p kosong');
      }
    });

    test('Bisnis tidak tertulis sebagai Standar maupun Pro', () {
      final bisnis = namaPaket(t, TierPlan.bisnis);
      expect(bisnis, isNot(namaPaket(t, TierPlan.standar)));
      expect(bisnis, isNot(namaPaket(t, TierPlan.pro)));
    });
  });

  // ==========================================================================
  // Bentuk sumbernya
  // ==========================================================================
  //
  // ⚠️ Membaca berkas, bukan menggambar layar. Batas itu ditulis terbuka:
  // tes ini menjaga BENTUK yang terbukti berulang kali melahirkan cacatnya,
  // bukan membuktikan dropdown-nya tergambar benar. Untuk yang terakhir tidak
  // ada penggantinya selain membukanya.
  //
  // Ia tetap berharga justru karena cacat ini lima kali lolos dari analyze,
  // dari 784 tes, dan dari mata — lalu ditemukan Product Owner.
  group('🔴 bentuk yang melahirkan Pola A tidak boleh kembali', () {
    String baca(String jalur) {
      final f = File(jalur);
      expect(f.existsSync(), isTrue, reason: '$jalur tidak ada');
      final isi = f.readAsStringSync();
      expect(isi.length, greaterThan(500), reason: '$jalur terbaca kosong');
      return isi;
    }

    test('dialog promo membangun pilihannya dari TierPlan.values', () {
      final src = baca('lib/pages/admin/settings/admin_promos_page.dart');

      expect(
        src,
        contains('for (final plan in TierPlan.values)'),
        reason: 'daftar paket wajib dibangun dari TierPlan.values',
      );

      // Bentuk lama yang menjatuhkan Bisnis ke cabang else.
      expect(
        src,
        isNot(contains('== TierPlan.pro\n')),
        reason: 'pemeriksaan biner terhadap TierPlan.pro sudah kembali',
      );
      expect(
        src.contains('? t.tierPro') && src.contains(': t.tierStandar'),
        isFalse,
        reason: 'ternary Pro/Standar sudah kembali — Bisnis akan tertulis '
            '"Standar" lagi',
      );
    });

    test('contoh harga promo tidak menanam angka', () {
      final src = baca('lib/pages/admin/settings/admin_promos_page.dart');

      // Harga lama yang sempat tertanam, dan sudah tidak berlaku sejak
      // migrasi 39 menetapkan 149.000 / 299.000 / 1.490.000.
      for (final basi in ['99000', '249000']) {
        expect(
          src,
          isNot(contains(basi)),
          reason: 'harga $basi ditanam di kode — contoh perhitungan yang '
              'memakai harga salah lebih buruk daripada tanpa contoh',
        );
      }

      expect(src, contains('_katalog.semua'),
          reason: 'harga wajib dibaca dari katalog');
    });

    test('🔴 nama produk di tagihan Midtrans mencakup Bisnis', () {
      final src = baca('supabase/functions/create-payment/index.ts');

      // Cacat yang paling mahal dari kelimanya: ia tercetak di STRUK
      // Midtrans sungguhan yang dilihat pelanggan dan masuk ke pembukuan.
      expect(
        src,
        isNot(contains("plan === 'pro' ? 'Pro' : 'Standar'")),
        reason: 'pembelian Bisnis akan kembali tertulis "KamelScan Standar"',
      );
      expect(src, contains('NAMA_PAKET'));
      expect(src, contains('bisnis:'),
          reason: 'peta nama paket wajib memuat bisnis');
    });
  });
}
