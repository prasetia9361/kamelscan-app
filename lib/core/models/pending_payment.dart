import 'subscription.dart';

/// Satu pembayaran yang menunggu diverifikasi Admin (Bab 12.2).
///
/// Dipisahkan dari [Subscription] dengan alasan yang sama seperti `HistoryItem`
/// dipisahkan dari `PackageVideo`: [Subscription] adalah cerminan satu tabel
/// dan dipakai juga di layar Pembayaran milik Owner. Menempelkan nama usaha ke
/// sana berarti kolom yang tidak pernah ada di tabelnya ikut terbawa ke
/// tempat-tempat yang tidak membutuhkannya.
class PendingPayment {
  const PendingPayment({required this.subscription, this.businessName});

  final Subscription subscription;

  /// 🔴 Inilah satu-satunya alasan embedding ini ada. Tanpa nama usaha, yang
  /// tampil di layar Admin hanyalah UUID tenant — dan mencocokkan
  /// `0b5ae403-…` dengan mutasi rekening adalah pekerjaan yang mustahil
  /// dilakukan tanpa salah.
  ///
  /// null bila tenant-nya belum mengisi nama usaha (Bab 6.2 membuatnya wajib
  /// saat mendaftar, jadi ini seharusnya hanya terjadi pada data lama).
  final String? businessName;

  factory PendingPayment.fromJson(Map<String, dynamic> json) {
    // PostgREST menaruh hasil embedding sebagai objek bersarang di bawah nama
    // tabelnya. Bila relasinya kosong, nilainya null — bukan map kosong.
    final tenant = json['tenants'] as Map<String, dynamic>?;

    return PendingPayment(
      subscription: Subscription.fromJson(json),
      businessName: tenant?['business_name'] as String?,
    );
  }

  /// Nama yang ditampilkan Admin. Jatuh ke potongan id tenant bila nama
  /// usahanya kosong — lebih baik sepotong id daripada baris tanpa identitas
  /// sama sekali.
  String get label {
    final nama = (businessName ?? '').trim();
    if (nama.isNotEmpty) return nama;
    final id = subscription.tenantId;
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}
