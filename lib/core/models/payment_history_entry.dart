import 'enums.dart';
import 'subscription.dart';
import 'token_wallet.dart';

/// Satu baris Riwayat pembayaran (Bab 7.2).
///
/// 🔴 Kenapa layar ini ada. Diminta Product Owner 3 September 2026 setelah
/// melihat saldonya sendiri menjadi 135.092 token dari tujuh pembelian dan
/// menyadari **tidak ada satu layar pun yang dapat menjelaskan angka itu**.
/// Sejak model token menjadi akumulatif (migrasi 40) pembelian saling
/// menumpuk, sehingga saldo akhir tidak lagi dapat diterka dari paket yang
/// sedang aktif.
///
/// ⚠️ Ini **bukan** cerminan satu tabel. Ia menggabungkan dua sumber yang
/// keduanya sudah boleh dibaca aplikasi sejak migrasi 14 (`sub_select` dan
/// `ledger_select`), jadi layar ini tidak menuntut satu migrasi pun:
///
///   - `subscriptions` — waktu bayar, tier, masa berlaku, cara membayar
///   - `token_ledger`  — **jumlah token yang benar-benar diberikan**
class PaymentHistoryEntry {
  const PaymentHistoryEntry({
    required this.subscription,
    this.tokensGranted,
  });

  final Subscription subscription;

  /// Token yang benar-benar masuk ke dompet karena pembelian ini, atau null
  /// bila baris buku besarnya tidak ditemukan.
  ///
  /// 🔴 Dibaca dari `token_ledger`, **bukan dihitung dari tier**. Menghitungnya
  /// dari `TierConfig` akan menampilkan jumlah token yang berlaku *hari ini*
  /// pada pembelian yang terjadi *dahulu* — dan angka itu memang sudah pernah
  /// berubah: migrasi 39 mengubah jatah ketiga paket sekaligus. Layar yang
  /// gunanya menjelaskan saldo justru menjadi layar yang membantah saldo.
  ///
  /// Null ditampilkan sebagai tanda hubung, bukan sebagai nol. Nol berarti
  /// "tidak ada token yang diberikan", sedangkan yang sebenarnya terjadi
  /// adalah "tidak diketahui" — dan pada dokumen yang dipakai menyelesaikan
  /// sengketa dengan pelanggan (Bab 7.2 poin 5), menebak angka jauh lebih
  /// berbahaya daripada mengaku tidak tahu.
  final int? tokensGranted;

  TierPlan get plan => subscription.plan;

  /// Waktu pembayaran diterima. `paidAt` bila ada, kalau tidak waktu tagihan
  /// dibuat — baris lunas selalu punya `paidAt`, tetapi baris lama dari masa
  /// sebelum kolom itu selalu diisi belum tentu.
  DateTime? get paidAt => subscription.paidAt ?? subscription.createdAt;

  DateTime? get periodEnd => subscription.periodEnd;

  /// `midtrans` | `manual_transfer` | null.
  String? get paymentMethod => subscription.paymentMethod;

  /// Menyusun riwayat dari kedua sumbernya.
  ///
  /// 🔴 Hanya status `paid` yang masuk, dan hanya itu satu-satunya yang
  /// benar. Diperiksa ke SQL, bukan diingat: trigger `activate_subscription`
  /// (migrasi 28 baris 82) menolak bekerja kecuali statusnya menjadi `paid`,
  /// sehingga `paid` adalah satu-satunya keadaan yang pernah menambah token.
  ///
  /// Keempat status lain memang bukan pembayaran:
  ///
  ///   - `pending`   — tagihan yang belum terjadi. Menampilkannya di sini
  ///                   membuat pelanggan menghitungnya sebagai token yang
  ///                   sudah ia miliki.
  ///   - `failed`    — ditulis `create-payment` saat Midtrans menolak.
  ///   - `cancelled` — dibatalkan pelanggan sendiri (migrasi 36, P.8).
  ///   - `expired`   — tidak pernah ditulis siapa pun ke tabel ini; yang
  ///                   berakhir adalah `tenants.status`, bukan barisnya.
  ///
  /// 🔴 Cara mencocokkan baris buku besar dengan langganannya: `note` yang
  /// ditulis `activate_subscription` (migrasi 40) berbunyi
  /// *"Beli paket X · +N token · langganan &lt;uuid&gt;"*, dan uuid itu satu-satunya
  /// tali antara kedua tabel — `token_ledger` tidak punya kolom yang menunjuk
  /// `subscriptions`.
  ///
  /// ⚠️ Talinya memang tipis, dan itu disengaja tidak diperbaiki dengan
  /// migrasi: menambah kolom berarti seluruh baris buku besar yang sudah ada
  /// tetap kosong, sehingga layar ini justru buta pada tujuh pembelian yang
  /// menjadi alasan ia dibuat. Bila talinya putus, [tokensGranted] menjadi
  /// null dan barisnya tetap tampil — hanya kolom tokennya yang bertanda
  /// hubung.
  static List<PaymentHistoryEntry> susun({
    required List<Subscription> subscriptions,
    required List<TokenLedgerEntry> ledger,
  }) {
    final pembelian = ledger
        .where((e) => e.reason == LedgerReason.planUpgrade && e.delta > 0)
        .toList(growable: false);

    final hasil = <PaymentHistoryEntry>[];

    for (final s in subscriptions) {
      if (s.status != SubStatus.paid) continue;

      final cocok = pembelian
          .where((e) => (e.note ?? '').contains(s.id))
          .firstOrNull;

      hasil.add(
        PaymentHistoryEntry(
          subscription: s,
          tokensGranted: cocok?.delta,
        ),
      );
    }

    // Terbaru di atas. Baris tanpa tanggal sama sekali diletakkan paling
    // bawah alih-alih dibuang — ia tetap pembayaran yang pernah terjadi.
    hasil.sort((a, b) {
      final x = a.paidAt;
      final y = b.paidAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    return List.unmodifiable(hasil);
  }
}
