import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/billing.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/promo.dart';
import 'package:kamelscan/core/models/subscription.dart';

/// Aritmetika tagihan (Bab 9.8 & 12.2).
///
/// Seluruhnya murni Dart, jadi dapat diuji tanpa perangkat maupun jaringan —
/// dan memang harus: uang adalah tempat terakhir yang pantas menebak-nebak.
/// Kekeliruan di sini tidak menampilkan pesan error apa pun, ia hanya menagih
/// angka yang salah.
void main() {
  Promo promo({
    String type = 'percent',
    num value = 10,
    TierPlan? appliesTo,
    DateTime? validUntil,
    DateTime? validFrom,
    int? maxUses,
    int usedCount = 0,
    bool isActive = true,
  }) =>
      Promo(
        code: 'HEMAT',
        discountType: type,
        discountValue: value,
        appliesTo: appliesTo,
        validFrom: validFrom,
        validUntil: validUntil ?? DateTime(2026, 12, 31),
        maxUses: maxUses,
        usedCount: usedCount,
        isActive: isActive,
      );

  final kini = DateTime(2026, 8, 22, 10);

  group('Potongan promo', () {
    test('persen dihitung dari harga paket', () {
      expect(promo(value: 20).discountFor(99000), 19800);
    });

    test('nominal tetap dipakai apa adanya', () {
      expect(promo(type: 'fixed', value: 25000).discountFor(99000), 25000);
    });

    test('🔴 potongan tetap tidak pernah melebihi harganya', () {
      // Admin salah ketik satu angka nol dan promo Rp 500.000 dipasang pada
      // paket Rp 99.000. Tanpa penjepit, tagihannya menjadi minus 401.000 —
      // dan angka minus itu akan diteruskan apa adanya ke instruksi transfer.
      expect(promo(type: 'fixed', value: 500000).discountFor(99000), 99000);
    });

    test('persen di atas 100 pun berhenti di harga', () {
      expect(promo(value: 150).discountFor(99000), 99000);
    });

    test('hasilnya bilangan bulat — rupiah tidak mengenal sen', () {
      // 33% dari 99.000 = 32.670 tepat; 7% dari 99.000 = 6.930.
      // Yang berpotensi pecahan diuji di sini: 3% dari 99.999.
      final potongan = promo(value: 3).discountFor(99999);
      expect(potongan, isA<int>());
      expect(potongan, 2999); // 2999,97 dibulatkan ke bawah
    });
  });

  group('Kode promo yang tidak boleh dipakai', () {
    test('kode dimatikan Admin', () {
      expect(promo(isActive: false).rejectionKey(TierPlan.standar, kini),
          'promoInactive');
    });

    test('belum mulai berlaku', () {
      expect(
        promo(validFrom: DateTime(2026, 9, 1))
            .rejectionKey(TierPlan.standar, kini),
        'promoNotStarted',
      );
    });

    test('sudah lewat masa berlakunya', () {
      expect(
        promo(validUntil: DateTime(2026, 8, 1))
            .rejectionKey(TierPlan.standar, kini),
        'promoExpired',
      );
    });

    test('kuota pemakaiannya habis', () {
      expect(promo(maxUses: 100, usedCount: 100)
          .rejectionKey(TierPlan.standar, kini), 'promoUsedUp');
    });

    test('kuota tanpa batas tidak pernah habis', () {
      expect(promo(usedCount: 99999).rejectionKey(TierPlan.standar, kini),
          isNull);
    });

    test('dipasang untuk paket lain', () {
      expect(
        promo(appliesTo: TierPlan.pro).rejectionKey(TierPlan.standar, kini),
        'promoWrongPlan',
      );
      expect(promo(appliesTo: TierPlan.pro).rejectionKey(TierPlan.pro, kini),
          isNull);
    });

    test('kode yang sah tidak ditolak', () {
      expect(promo().rejectionKey(TierPlan.standar, kini), isNull);
    });
  });

  group('Rincian tagihan', () {
    test('tanpa promo, totalnya harga paket', () {
      final t = BillingSummary.of(price: 99000, random: Random(1));

      expect(t.subtotal, 99000);
      expect(t.discount, 0);
      expect(t.total, 99000);
      expect(t.hasDiscount, isFalse);
    });

    test('dengan promo, potongannya dikurangkan', () {
      final t = BillingSummary.of(
        price: 249000,
        promo: promo(value: 20),
        random: Random(1),
      );

      expect(t.discount, 49800);
      expect(t.total, 199200);
      expect(t.hasDiscount, isTrue);
    });

    test('total tidak pernah minus', () {
      final t = BillingSummary.of(
        price: 99000,
        promo: promo(type: 'fixed', value: 500000),
        random: Random(1),
      );

      expect(t.total, 0);
    });
  });

  group('🔴 Tiga digit pembeda', () {
    test('selalu 1–999, tidak pernah nol', () {
      // Nol berarti nominalnya persis harga daftar — justru keadaan yang
      // membuat Admin tidak dapat mencocokkan mutasi rekening.
      for (var benih = 0; benih < 300; benih++) {
        final t = BillingSummary.of(price: 99000, random: Random(benih));
        expect(t.uniqueCode, inInclusiveRange(1, 999));
      }
    });

    test('DITAMBAHKAN, bukan menggantikan digit terakhir', () {
      // Menggantikan digit terakhir dapat menghasilkan nominal yang lebih
      // KECIL daripada yang seharusnya dibayar, dan selisihnya baru ketahuan
      // saat rekonsiliasi — ketika uangnya sudah masuk.
      for (var benih = 0; benih < 300; benih++) {
        final t = BillingSummary.of(price: 99000, random: Random(benih));
        expect(t.amountToTransfer, greaterThan(t.total));
        expect(t.amountToTransfer - t.total, t.uniqueCode);
      }
    });

    test('dua tagihan berturut-turut hampir selalu berbeda', () {
      // Inilah gunanya. Sepuluh pelanggan paket Standar pada hari yang sama
      // semuanya mengirim Rp 99.000; mutasi rekening tidak memuat nama tenant.
      final nominal = {
        for (var i = 0; i < 200; i++)
          BillingSummary.of(price: 99000, random: Random(i)).amountToTransfer,
      };

      expect(nominal.length, greaterThan(150));
    });
  });

  group('Batas waktu transfer 24 jam', () {
    Subscription tagihan({DateTime? dibuat, String? bukti}) => Subscription(
          id: 's-1',
          tenantId: 't-1',
          plan: TierPlan.standar,
          amount: 99317,
          proofUrl: bukti,
          createdAt: dibuat ?? DateTime(2026, 8, 22, 8),
        );

    test('sisa waktunya dihitung dari saat tagihan dibuat', () {
      expect(
        tagihan().remainingToTransfer(DateTime(2026, 8, 22, 20)),
        const Duration(hours: 12),
      );
    });

    test('tidak pernah negatif', () {
      expect(
        tagihan().remainingToTransfer(DateTime(2026, 8, 25)),
        Duration.zero,
      );
    });

    test('tagihan lewat waktu tanpa bukti dianggap basi', () {
      expect(tagihan().isStale(DateTime(2026, 8, 25)), isTrue);
    });

    test('🔴 tagihan yang SUDAH ada buktinya tidak pernah basi', () {
      // Owner sudah mengirim uangnya; yang terlambat justru verifikasinya.
      // Menandainya basi akan menyuruh orang mentransfer ulang uang yang sudah
      // berpindah — kesalahan yang tidak dapat dibatalkan aplikasi.
      final sudahBayar = tagihan(bukti: 't-1/s-1.jpg');

      expect(sudahBayar.isWaitingVerification, isTrue);
      expect(sudahBayar.isStale(DateTime(2026, 8, 25)), isFalse);
    });

    test('menunggu verifikasi dibedakan dari menunggu pembayaran', () {
      expect(tagihan().isWaitingVerification, isFalse);
      expect(tagihan(bukti: 't-1/s-1.jpg').isWaitingVerification, isTrue);
    });
  });
}
