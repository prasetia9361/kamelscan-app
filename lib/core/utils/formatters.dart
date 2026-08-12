import 'package:intl/intl.dart';

/// Pemformat tanggal, ukuran berkas, durasi, dan mata uang.
///
/// Semua fungsi menerima `locale` eksplisit agar dwibahasa (Bab 0.3) tetap
/// konsisten — jangan mengandalkan locale global.
class Formatters {
  const Formatters._();

  static const String _idLocale = 'id_ID';

  static String _loc(String? locale) => locale ?? _idLocale;

  /// `12 Agu 2026`
  static String date(DateTime value, {String? locale}) =>
      DateFormat('d MMM yyyy', _loc(locale)).format(value.toLocal());

  /// `12 Agustus 2026, 14.30`
  static String dateTime(DateTime value, {String? locale}) =>
      DateFormat('d MMMM yyyy, HH.mm', _loc(locale)).format(value.toLocal());

  /// `14.30`
  static String time(DateTime value, {String? locale}) =>
      DateFormat('HH.mm', _loc(locale)).format(value.toLocal());

  /// Label ringkas untuk daftar riwayat.
  static String shortDateTime(DateTime value, {String? locale}) =>
      DateFormat('d MMM, HH.mm', _loc(locale)).format(value.toLocal());

  /// `Rp 99.000`
  static String currency(num value, {String? locale}) => NumberFormat.currency(
        locale: _loc(locale),
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(value);

  /// `1.234`
  static String number(num value, {String? locale}) =>
      NumberFormat.decimalPattern(_loc(locale)).format(value);

  /// `12,4 MB`
  static String fileSize(int bytes, {String? locale}) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var size = bytes / 1024;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final fmt = NumberFormat(size >= 10 ? '#,##0' : '#,##0.0', _loc(locale));
    return '${fmt.format(size)} ${units[unit]}';
  }

  /// `00:28` — durasi rekaman selalu di bawah 2 menit.
  static String duration(Duration value) {
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String durationFromSeconds(int? seconds) =>
      seconds == null ? '--:--' : duration(Duration(seconds: seconds));

  /// `-6.20088, 106.81664` atau null bila izin lokasi ditolak (Bab 1.3 poin 6).
  static String? coordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Sisa hari retensi; negatif berarti sudah lewat.
  static int daysUntil(DateTime target, {DateTime? now}) {
    final base = now ?? DateTime.now();
    return target.difference(base).inDays;
  }

  /// Sensor sebagian resi untuk tampilan publik/log.
  static String maskResi(String resi) {
    if (resi.length <= 6) return resi;
    return '${resi.substring(0, 3)}${'*' * (resi.length - 6)}'
        '${resi.substring(resi.length - 3)}';
  }
}
