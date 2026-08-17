/// Aturan waktu pada watermark (Bab 8.5) — **tanpa satu pun panggilan I/O**.
///
/// Dipisahkan agar seluruh aturannya dapat diuji di komputer, sama seperti
/// [ScanGate] dan [RecordingMachine]. Yang membaca jam, berkas, dan jaringan
/// adalah `ServerClock`; berkas ini hanya memutuskan.
///
/// 🔴 Aturan Product Owner 16 Agustus 2026, dan **jangan diubah tanpa
/// memberitahu beliau lebih dulu**:
///
/// 1. Saat ada sinyal, aplikasi menanyakan waktu server dan menyimpannya
///    bersama titik acuan dari penghitung yang **tidak dapat diubah pengguna**.
/// 2. Waktu watermark = waktu server terakhir + berapa lama berlalu sejak
///    sinkron, dihitung dari penghitung tadi.
///    🔴 **Tidak pernah dengan mengurangi jam HP.** Orang yang memundurkan jam
///    HP di tengah sesi akan menggeser waktu di seluruh video sesudahnya —
///    dan video bukti yang jamnya dapat digeser tidak ada nilainya saat
///    disengketakan.
/// 3. Toleransi ±2 menit terhadap jam HP. Di bawah itu keduanya dianggap sama.
///    Di atas itu jam HP dianggap tidak layak dipercaya, tetapi **perekaman
///    tetap jalan** dengan waktu terkoreksi. Packer di gudang tidak boleh
///    berhenti bekerja karena jam HP-nya salah.
/// 4. Belum pernah sinkron sama sekali → **tetap boleh merekam** dengan jam HP
///    apa adanya, dan videonya ditandai `timeVerified = false`.
library;

/// Titik acuan hasil satu kali sinkronisasi ke server.
class TimeAnchor {
  const TimeAnchor({
    required this.serverTime,
    required this.monotonic,
    required this.sourceId,
    required this.deviceTimeAtSync,
  });

  /// Waktu server saat sinkron (UTC).
  final DateTime serverTime;

  /// Bacaan penghitung monotonic pada saat yang sama.
  final Duration monotonic;

  /// Identitas penghitung yang dipakai — mis. id boot perangkat.
  ///
  /// 🔴 Inilah yang membuat titik acuan gugur setelah HP dinyalakan ulang.
  /// Penghitung sejak-boot kembali ke nol tiap kali HP restart; tanpa penanda
  /// ini, titik acuan lama akan dipakai terhadap penghitung yang sudah
  /// direset dan menghasilkan waktu yang meleset berjam-jam **tanpa gejala**.
  final String sourceId;

  /// Jam HP pada saat sinkron. **Hanya untuk diagnosis**, tidak pernah dipakai
  /// menghitung apa pun — lihat aturan 2 di atas.
  final DateTime deviceTimeAtSync;

  Map<String, Object?> toJson() => {
        'server_time': serverTime.toUtc().toIso8601String(),
        'monotonic_us': monotonic.inMicroseconds,
        'source_id': sourceId,
        'device_time': deviceTimeAtSync.toUtc().toIso8601String(),
      };

  static TimeAnchor? fromJson(Map<String, Object?> json) {
    final server = DateTime.tryParse(json['server_time'] as String? ?? '');
    final micros = json['monotonic_us'];
    final source = json['source_id'] as String?;
    if (server == null || micros is! int || source == null || source.isEmpty) {
      return null;
    }
    return TimeAnchor(
      serverTime: server.toUtc(),
      monotonic: Duration(microseconds: micros),
      sourceId: source,
      deviceTimeAtSync:
          DateTime.tryParse(json['device_time'] as String? ?? '')?.toUtc() ??
              server.toUtc(),
    );
  }
}

/// Waktu yang dipakai watermark, beserta kejujuran tentang asalnya.
class TrustedTime {
  const TrustedTime({
    required this.utc,
    required this.verified,
    this.deviceClockSkew = Duration.zero,
  });

  final DateTime utc;

  /// `false` = angka ini berasal dari jam HP yang belum pernah diadu dengan
  /// waktu server. Videonya tetap direkam; tandanya ikut ke
  /// `package_videos.time_verified` dan ke metadata berkas.
  final bool verified;

  /// Selisih jam HP terhadap waktu terkoreksi. Positif = jam HP kedepanan.
  final Duration deviceClockSkew;

  /// Jam HP meleset lebih dari toleransi. Tidak menghentikan apa pun —
  /// hanya layak dicatat dan (bila perlu) diberitahukan ke pengguna.
  bool get deviceClockSuspect =>
      verified && deviceClockSkew.abs() > TimeSync.tolerance;

  DateTime get local => utc.toLocal();
}

class TimeSync {
  const TimeSync._();

  /// Aturan 3 — di bawah ini jam HP dan waktu terkoreksi dianggap sama.
  static const Duration tolerance = Duration(minutes: 2);

  /// Seberapa lama satu titik acuan dianggap masih segar sebelum aplikasi
  /// sebaiknya menanyakan ulang ke server saat ada sinyal.
  ///
  /// Bukan batas kedaluwarsa: titik acuan yang lebih tua **tetap dipakai** —
  /// penghitung monotonic tidak melar. Ini hanya penentu kapan sinkronisasi
  /// berikutnya layak dicoba.
  static const Duration refreshAfter = Duration(hours: 1);

  /// Waktu yang dipakai watermark.
  ///
  /// [monotonicNow] dan [sourceId] datang dari penghitung yang tidak dapat
  /// diubah pengguna. [deviceNow] hanya dipakai sebagai cadangan (aturan 4)
  /// dan untuk menghitung selisih diagnosis.
  static TrustedTime resolve({
    required TimeAnchor? anchor,
    required Duration monotonicNow,
    required String sourceId,
    required DateTime deviceNow,
  }) {
    final device = deviceNow.toUtc();

    // Aturan 4 — belum pernah sinkron. Juga berlaku bila titik acuannya berasal
    // dari penghitung yang sudah tidak ada lagi (HP dinyalakan ulang, atau
    // aplikasi ditutup sementara penghitungnya hanya seumur proses).
    if (anchor == null || anchor.sourceId != sourceId) {
      return TrustedTime(utc: device, verified: false);
    }

    // Penghitung monotonic tidak pernah mundur. Bila ternyata mundur, yang kita
    // pegang bukan penghitung yang sama — perlakukan seperti belum pernah
    // sinkron daripada menghasilkan waktu yang salah diam-diam.
    if (monotonicNow < anchor.monotonic) {
      return TrustedTime(utc: device, verified: false);
    }

    final corrected = anchor.serverTime.add(monotonicNow - anchor.monotonic);
    return TrustedTime(
      utc: corrected,
      verified: true,
      deviceClockSkew: device.difference(corrected),
    );
  }

  /// Apakah layak menanyakan ulang waktu server sekarang.
  static bool needsRefresh({
    required TimeAnchor? anchor,
    required Duration monotonicNow,
    required String sourceId,
  }) {
    if (anchor == null || anchor.sourceId != sourceId) return true;
    if (monotonicNow < anchor.monotonic) return true;
    return monotonicNow - anchor.monotonic >= refreshAfter;
  }
}
