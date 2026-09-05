import 'enums.dart';

/// Jenis pengumuman — menentukan apakah aplikasinya masih dapat dipakai.
///
/// 🔴 Perbedaannya bukan warna dan bukan ikon. [important] **mengunci**:
/// tidak ada tanda silang, dan satu-satunya jalan keluar adalah tombol
/// aksinya. Itu yang dipakai saat versi baru wajib dipasang.
enum AnnouncementKind {
  important,
  normal;

  String get wire => name;

  /// ⚠️ Nilai yang tidak dikenal jatuh ke [normal], BUKAN ke [important].
  ///
  /// Arah jatuhannya sengaja begitu. Aplikasi lama yang membaca jenis
  /// pengumuman yang belum dikenalnya akan **membiarkan orang masuk**;
  /// jatuhan sebaliknya akan mengunci seluruh pengguna versi lama dari
  /// sesuatu yang bahkan tidak dimaksudkan mengunci mereka — dan mereka tidak
  /// punya cara memberi tahu kita, karena aplikasinya tidak bisa dibuka.
  static AnnouncementKind fromWire(String? v) =>
      v == 'important' ? AnnouncementKind.important : AnnouncementKind.normal;

  bool get mengunci => this == AnnouncementKind.important;
}

/// Siapa yang melihat sebuah pengumuman.
///
/// ⚠️ Admin tidak termasuk sasaran mana pun, termasuk [all]. Yang menulis
/// pengumuman tidak perlu diberi tahu isinya sendiri, dan panel admin berdiri
/// di luar rangka yang menampilkannya — memasukkan admin berarti membangun
/// jalur tampilan ketiga untuk satu-satunya orang yang sudah tahu.
enum AnnouncementAudience {
  all,
  owner,
  packer;

  String get wire => name;

  /// Nilai yang tidak dikenal jatuh ke [all] — sasaran terluas.
  ///
  /// Kebalikan dari [AnnouncementKind.fromWire], dan alasannya juga
  /// kebalikannya: pengumuman yang salah sasaran hanya mengganggu, sedangkan
  /// pengumuman yang tidak sampai kepada siapa pun sama saja dengan tidak
  /// pernah ditulis — dan Admin tidak akan pernah tahu bedanya.
  static AnnouncementAudience fromWire(String? v) => switch (v) {
        'owner' => AnnouncementAudience.owner,
        'packer' => AnnouncementAudience.packer,
        _ => AnnouncementAudience.all,
      };
}

/// Satu iklan atau pengumuman yang muncul sesudah pengguna masuk.
///
/// Cerminan tabel `public.announcements` (migrasi 50). Diminta Product Owner
/// 5 September 2026 untuk HP dan web sekaligus.
///
/// 🔴 Isinya dikelola Admin lewat halaman Kelola Pengumuman, bukan ditulis
/// mati di kode. Mengumumkan perawatan terjadwal karena itu tidak menuntut
/// rilis aplikasi baru — dan itu justru inti permintaannya: yang paling sering
/// perlu diumumkan adalah rilis itu sendiri.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.body = '',
    this.imageUrl,
    this.kind = AnnouncementKind.normal,
    this.audience = AnnouncementAudience.all,
    this.actionUrl,
    this.actionLabel,
    this.isActive = true,
    this.createdAt,
  });

  /// Kosong berarti **pengumuman baru** yang belum pernah disimpan. Kuncinya
  /// dibuat server lewat `default gen_random_uuid()`; mengirim string kosong
  /// sebagai `id` ditolak PostgreSQL sebagai uuid tidak sah.
  final String id;

  final String title;
  final String body;

  /// Alamat gambar di bucket `public-assets`. Kosong berarti tanpa gambar —
  /// keadaan yang wajar, bukan kekurangan.
  final String? imageUrl;

  final AnnouncementKind kind;
  final AnnouncementAudience audience;

  final String? actionUrl;
  final String? actionLabel;

  final bool isActive;
  final DateTime? createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        imageUrl: json['image_url'] as String?,
        kind: AnnouncementKind.fromWire(json['kind'] as String?),
        audience: AnnouncementAudience.fromWire(json['audience'] as String?),
        actionUrl: json['action_url'] as String?,
        actionLabel: json['action_label'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    AnnouncementKind? kind,
    AnnouncementAudience? audience,
    String? actionUrl,
    String? actionLabel,
    bool? isActive,
  }) =>
      Announcement(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        imageUrl: imageUrl ?? this.imageUrl,
        kind: kind ?? this.kind,
        audience: audience ?? this.audience,
        actionUrl: actionUrl ?? this.actionUrl,
        actionLabel: actionLabel ?? this.actionLabel,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  /// Aplikasi tidak dapat dipakai sampai pengumuman ini dijawab.
  bool get mengunci => kind.mengunci;

  bool get punyaGambar => (imageUrl ?? '').trim().isNotEmpty;

  /// Tombol aksinya dapat ditekan.
  ///
  /// 🔴 Wajib diperiksa sebelum menggambar tombolnya. Pengumuman [mengunci]
  /// tanpa alamat aksi yang sah adalah **jalan buntu**: tidak ada silang,
  /// tidak ada tombol, dan pengguna terkurung di layar itu sampai memasang
  /// ulang aplikasinya. Formulir Admin menolak keadaan itu sebelum disimpan,
  /// dan pemeriksaan di sini adalah jaring keduanya — untuk baris yang
  /// terlanjur ada, atau yang disunting langsung lewat Supabase Dashboard.
  bool get punyaAksi {
    final u = actionUrl?.trim() ?? '';
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// Pengumuman ini ditujukan kepada [role].
  ///
  /// ⚠️ Admin selalu `false`, termasuk untuk [AnnouncementAudience.all].
  /// Uraiannya di [AnnouncementAudience].
  bool untuk(UserRole? role) {
    if (role == null || role.isAdmin) return false;
    return switch (audience) {
      AnnouncementAudience.all => true,
      AnnouncementAudience.owner => role.isOwner,
      AnnouncementAudience.packer => role.isPacker,
    };
  }

  /// Urutan tampil resmi: yang mengunci lebih dulu, lalu yang terbaru.
  ///
  /// 🔴 Yang mengunci HARUS di depan. Kalau pengumuman event tampil lebih
  /// dulu, pengguna menutupnya, lalu baru bertemu layar "wajib update", ia
  /// sudah menutup sesuatu yang tidak pernah sempat dibacanya — dan
  /// penutupannya terlanjur dicatat.
  static int urutkan(Announcement a, Announcement b) {
    if (a.mengunci != b.mengunci) return a.mengunci ? -1 : 1;
    final wa = a.createdAt;
    final wb = b.createdAt;
    if (wa == null || wb == null) return 0;
    return wb.compareTo(wa);
  }
}
