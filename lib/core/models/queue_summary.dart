/// Ringkasan antrian unggah, dipecah menurut **apa yang sebenarnya menahan**
/// tiap baris (Bab 8.7).
///
/// 🔴 Kenapa ini ada. Sampai 3 September 2026 Beranda hanya tahu satu angka —
/// jumlah baris yang belum selesai — dan kalimat di sebelahnya ditulis mati:
/// *"{n} video dalam antrean — menunggu Wi-Fi"*. Kalimat itu diucapkan tanpa
/// peduli sebab sebenarnya.
///
/// Akibatnya diukur Product Owner 3 September 2026: sebuah video gagal diberi
/// watermark (FFmpeg keluar kode 1), tetapi layarnya tetap menyalahkan
/// jaringan. Ia lalu menyalakan "Unggah lewat data seluler" — pengaturan yang
/// sama sekali tidak berhubungan — dan tentu saja tidak terjadi apa-apa.
///
/// ⚠️ Pemisahan ini juga menutup ketidaksesuaian yang lebih dalam: hitungan
/// lama memasukkan baris yang penjalan antrian **tidak akan pernah sentuh**
/// (`failed` yang jatah percobaannya habis, dan rekaman yang masih menunggu
/// watermark). Angka dan aksinya karena itu bicara tentang hal yang berbeda —
/// menekan "Unggah sekarang" pada baris seperti itu tidak mungkin berhasil,
/// berapa kali pun ditekan.
class QueueSummary {
  const QueueSummary({
    this.siap = 0,
    this.sedangDiproses = 0,
    this.gagal = 0,
    this.tertunda = 0,
  });

  /// Siap diunggah sekarang juga — tinggal menunggu jaringan yang diizinkan.
  final int siap;

  /// Rekaman mentah yang masih menunggu watermark (`pendingProcess`).
  ///
  /// Tidak pernah boleh diunggah apa adanya (Bab 8.5), jadi menekan
  /// "Unggah sekarang" tidak akan menyentuhnya.
  final int sedangDiproses;

  /// Sudah menghabiskan jatah percobaan. Hanya tombol *Coba lagi* di Riwayat
  /// yang dapat menolongnya (Bab 8.7 langkah 6).
  final int gagal;

  /// Menunggu giliran percobaan berikutnya (`nextAttemptAt` belum tiba) atau
  /// sengaja dijeda.
  final int tertunda;

  /// Seluruh baris yang belum sampai ke server.
  ///
  /// Ini angka yang dipakai lencana dan peringatan saat keluar: di sana yang
  /// ditanyakan memang *"ada berapa yang belum terkirim"*, bukan *"apa yang
  /// menahannya"*.
  int get total => siap + sedangDiproses + gagal + tertunda;

  bool get kosong => total == 0;

  /// Menekan "Unggah sekarang" masuk akal hanya bila ada yang benar-benar
  /// siap. Selain itu tombolnya menjanjikan sesuatu yang tidak dapat ia
  /// tepati.
  bool get adaYangDapatDiunggah => siap > 0;

  @override
  String toString() => 'QueueSummary(siap: $siap, diproses: $sedangDiproses, '
      'gagal: $gagal, tertunda: $tertunda)';

  @override
  bool operator ==(Object other) =>
      other is QueueSummary &&
      other.siap == siap &&
      other.sedangDiproses == sedangDiproses &&
      other.gagal == gagal &&
      other.tertunda == tertunda;

  @override
  int get hashCode => Object.hash(siap, sedangDiproses, gagal, tertunda);
}
