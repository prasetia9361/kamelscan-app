import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/payment_methods.dart';
import 'package:kamelscan/core/models/subscription.dart';
import 'package:kamelscan/pages/payment/plan_view_model.dart';

/// Spanduk "Pembayaran Anda ditolak" di halaman Pembayaran Owner (Bab 11.7).
///
/// 🔴 Lahir dari cacat, bukan dari permintaan fitur. Sampai 29 Agustus 2026
/// menolak pembayaran hanya mengubah status menjadi `failed`, dan di layar
/// Owner akibatnya: spanduk "menunggu verifikasi" lenyap tanpa satu kalimat
/// pun yang menggantikannya. Owner yang uangnya sudah keluar melihat halaman
/// pilih paket biasa, seolah tagihannya tidak pernah ada. Ditemukan Product
/// Owner saat menguji tombol Tolak pada baris sungguhan.
///
/// ⚠️ Yang diuji di sini adalah **aturan datanya**, bukan gambarnya. Apakah
/// spanduk merahnya terbaca jelas oleh mata manusia tetap harus dilihat
/// sendiri di peramban — tes tidak pernah dapat menjawab pertanyaan itu.
void main() {
  Subscription sub(SubStatus status, {String? alasan}) => Subscription(
    id: 'sub-1',
    tenantId: 't1',
    plan: TierPlan.standar,
    amount: 99317,
    status: status,
    rejectionReason: alasan,
  );

  PlanData data({Subscription? pending, Subscription? rejected}) => PlanData(
    catalog: TierCatalog.fallback,
    currentPlan: TierPlan.standar,
    isTrial: false,
    methods: PaymentMethods.fallback,
    banners: const {},
    selected: TierPlan.pro,
    pending: pending,
    rejected: rejected,
  );

  test('status failed dikenali sebagai penolakan', () {
    expect(sub(SubStatus.failed).isRejected, isTrue);
    expect(sub(SubStatus.pending).isRejected, isFalse);
    expect(sub(SubStatus.paid).isRejected, isFalse);
  });

  test('alasan penolakan terbawa apa adanya', () {
    // Ditulis Admin dan dibaca Owner tanpa diubah. Ia bukan catatan internal.
    final s = sub(SubStatus.failed, alasan: 'Nominal transfer tidak cocok');
    expect(s.rejectionReason, 'Nominal transfer tidak cocok');
  });

  test('baris lama tanpa kolom alasan tetap dikenali ditolak', () {
    // Penolakan yang terjadi sebelum kolomnya ada memang tidak punya isi.
    // Layar menggantinya dengan kalimat "tidak ada alasan yang tercatat",
    // bukan ruang kosong — dan itu hanya mungkin bila statusnya tetap terbaca.
    final s = sub(SubStatus.failed);
    expect(s.isRejected, isTrue);
    expect(s.rejectionReason, isNull);
  });

  test('🔴 tagihan baru menghapus spanduk penolakan yang lama', () {
    // Membiarkan spanduk merah berdiri di samping tagihan yang sedang berjalan
    // membuat Owner mengira tagihan barunya ikut ditolak, lalu ia berhenti
    // mentransfer dan menghubungi Admin — untuk masalah yang sudah selesai.
    final awal = data(rejected: sub(SubStatus.failed, alasan: 'Tidak cocok'));
    expect(awal.rejected, isNotNull);

    final sesudah = awal.copyWith(pending: sub(SubStatus.pending));
    expect(sesudah.pending, isNotNull);
    expect(sesudah.rejected, isNull);
  });

  test('tanpa tagihan baru, penolakannya bertahan di layar', () {
    final awal = data(rejected: sub(SubStatus.failed, alasan: 'Tidak cocok'));
    final sesudah = awal.copyWith(selected: TierPlan.standar);
    expect(sesudah.rejected, isNotNull);
  });
}
