import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/models/payment_history_entry.dart';
import 'package:kamelscan/core/models/subscription.dart';
import 'package:kamelscan/core/models/token_wallet.dart';

/// Aturan Riwayat pembayaran (Bab 7.2).
///
/// 🔴 Layar ini dipakai menyelesaikan sengketa dengan pelanggan (Bab 7.2 poin
/// 5), jadi kekeliruan di sini bukan kekeliruan tampilan — ia bukti yang
/// salah. Dua hal yang dijaga paling keras: tagihan yang belum dibayar tidak
/// boleh terhitung, dan jumlah token tidak boleh ditebak.
void main() {
  final t0 = DateTime.utc(2026, 9, 1, 10);

  Subscription sub({
    required String id,
    SubStatus status = SubStatus.paid,
    TierPlan plan = TierPlan.standar,
    DateTime? paidAt,
    DateTime? periodEnd,
    String? method = 'midtrans',
  }) =>
      Subscription(
        id: id,
        tenantId: 'tn1',
        plan: plan,
        amount: 149000,
        status: status,
        paymentMethod: method,
        paidAt: paidAt,
        periodEnd: periodEnd,
        createdAt: paidAt ?? t0,
      );

  TokenLedgerEntry ledger({
    required int id,
    required int delta,
    LedgerReason reason = LedgerReason.planUpgrade,
    String? note,
  }) =>
      TokenLedgerEntry(
        id: id,
        tenantId: 'tn1',
        delta: delta,
        reason: reason,
        balanceAfter: 0,
        note: note,
        createdAt: t0,
      );

  group('Mana yang layak disebut pembayaran', () {
    test('🔴 hanya status paid yang masuk', () {
      // Diperiksa ke SQL, bukan diingat: trigger `activate_subscription`
      // (migrasi 28) menolak bekerja kecuali statusnya menjadi `paid`,
      // sehingga `paid` satu-satunya keadaan yang pernah menambah token.
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [
          sub(id: 'a', status: SubStatus.paid, paidAt: t0),
          sub(id: 'b', status: SubStatus.pending, paidAt: t0),
          sub(id: 'c', status: SubStatus.failed, paidAt: t0),
          sub(id: 'd', status: SubStatus.cancelled, paidAt: t0),
          sub(id: 'e', status: SubStatus.expired, paidAt: t0),
        ],
        ledger: const [],
      );

      expect(hasil.map((e) => e.subscription.id).toList(), ['a']);
    });

    test('🔴 tagihan pending TIDAK boleh terhitung sebagai token yang dimiliki',
        () {
      // Kekeliruan yang paling mungkin dan paling mahal: pelanggan membaca
      // tagihan yang belum ia bayar sebagai token yang sudah ia punya, lalu
      // menuntut selisihnya.
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 'x', status: SubStatus.pending, paidAt: t0)],
        ledger: [ledger(id: 1, delta: 2000, note: 'langganan x')],
      );
      expect(hasil, isEmpty);
    });
  });

  group('Jumlah token yang diberikan', () {
    test('dibaca dari buku besar lewat id langganan di dalam note', () {
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 'sub-abc', paidAt: t0)],
        ledger: [
          ledger(
            id: 1,
            delta: 30000,
            note: 'Beli paket bisnis · +30000 token · langganan sub-abc',
          ),
        ],
      );

      expect(hasil.single.tokensGranted, 30000);
    });

    test('🔴 tanpa pasangan di buku besar hasilnya NULL, bukan nol', () {
      // Null berarti "tidak diketahui" dan tampil sebagai tanda hubung. Nol
      // berarti "tidak ada token yang diberikan" — pernyataan yang berbeda,
      // dan pada dokumen bukti, menebak lebih berbahaya daripada mengaku
      // tidak tahu.
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 'sub-yatim', paidAt: t0)],
        ledger: [ledger(id: 1, delta: 2000, note: 'langganan sub-lain')],
      );

      expect(hasil.single.tokensGranted, isNull);
      expect(hasil.single.tokensGranted, isNot(0));
    });

    test('🔴 baris buku besar yang BUKAN pembelian tidak pernah dipakai', () {
      // Pemakaian video (`video_upload`, delta negatif) dan penghangusan
      // (`token_expired`) juga menyebut tenant yang sama. Mengambilnya akan
      // menampilkan angka negatif sebagai "token yang dibeli".
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 's1', paidAt: t0)],
        ledger: [
          ledger(
            id: 1,
            delta: -5,
            reason: LedgerReason.videoUpload,
            note: 'langganan s1',
          ),
          ledger(
            id: 2,
            delta: -100,
            reason: LedgerReason.tokenExpired,
            note: 'langganan s1',
          ),
          ledger(
            id: 3,
            delta: -50,
            reason: LedgerReason.adminAdjust,
            note: 'langganan s1',
          ),
        ],
      );

      expect(hasil.single.tokensGranted, isNull);
    });

    test('penambahan bernilai nol pun tidak dianggap pembelian', () {
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 's1', paidAt: t0)],
        ledger: [ledger(id: 1, delta: 0, note: 'langganan s1')],
      );
      expect(hasil.single.tokensGranted, isNull);
    });
  });

  group('Urutan baris', () {
    test('terbaru di atas', () {
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [
          sub(id: 'lama', paidAt: DateTime.utc(2026, 1, 1)),
          sub(id: 'baru', paidAt: DateTime.utc(2026, 9, 1)),
          sub(id: 'tengah', paidAt: DateTime.utc(2026, 5, 1)),
        ],
        ledger: const [],
      );

      expect(hasil.map((e) => e.subscription.id).toList(),
          ['baru', 'tengah', 'lama']);
    });

    test('🔴 baris tanpa tanggal DIBUANG ke bawah, bukan dibuang dari daftar',
        () {
      // Ia tetap pembayaran yang pernah terjadi. Menghilangkannya membuat
      // jumlah token pada layar tidak lagi menjelaskan saldo — yaitu
      // satu-satunya gunanya.
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [
          sub(id: 'kosong', paidAt: null).copyWith(createdAt: null),
          sub(id: 'ada', paidAt: DateTime.utc(2026, 5, 1)),
        ],
        ledger: const [],
      );

      expect(hasil.length, 2);
      expect(hasil.last.subscription.id, 'kosong');
    });

    test('paidAt kosong jatuh ke createdAt, bukan ke tanda hubung', () {
      final dibuat = DateTime.utc(2026, 3, 3, 9);
      final hasil = PaymentHistoryEntry.susun(
        subscriptions: [sub(id: 's1', paidAt: null).copyWith(createdAt: dibuat)],
        ledger: const [],
      );
      expect(hasil.single.paidAt, dibuat);
    });
  });

  test('daftarnya tidak dapat diubah pemanggil', () {
    final hasil = PaymentHistoryEntry.susun(
      subscriptions: [sub(id: 'a', paidAt: t0)],
      ledger: const [],
    );
    expect(() => hasil.add(hasil.first), throwsUnsupportedError);
  });
}
