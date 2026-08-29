import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/admin_tenant_row.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';

part 'admin_users_view_model.g.dart';

/// Aturan perpanjangan periode langganan (Bab 11.2).
///
/// 🔴 Berdiri sebagai kelas tersendiri, bukan sebagai fungsi di dalam State
/// dialognya, dan itu bukan soal kerapian: ketiga aturan di bawah adalah
/// **keputusan dagang** yang salahnya berupa hari — pelanggan mendapat tiga
/// hari lebih, atau kehilangan dua puluh hari yang sudah dibayarnya. Cacat
/// semacam itu tidak melempar galat apa pun dan tidak terlihat di layar
/// sampai seseorang menghitung sendiri dengan kalender.
///
/// Aturan O.14 di catatan proyek lahir dari cacat yang bentuknya persis
/// seperti ini: logika yang terkubur di dalam widget tidak pernah diuji satu
/// kali pun. Di sini ketiganya dapat diuji tanpa menggambar apa pun.
class Perpanjangan {
  const Perpanjangan._();

  /// Lama perpanjangan siap pakai, dalam bulan (keputusan PO 29 Agustus 2026).
  static const List<int> pilihanBulan = [1, 3, 6, 12];

  /// Menambah [bulan] bulan sambil menjaga tanggalnya tetap masuk akal.
  ///
  /// 🔴 Bukan `Duration(days: 30 * bulan)`, dan bukan pula `DateTime(y, m + n,
  /// hari)` telanjang. Yang kedua meluap diam-diam: 31 Januari + 1 bulan
  /// menjadi `DateTime(2026, 2, 31)`, yang oleh Dart diterjemahkan menjadi
  /// **3 Maret** — pelanggan mendapat tiga hari lebih, dan tidak ada satu pun
  /// galat yang muncul. Di sini tanggalnya dijepit ke hari terakhir bulan
  /// tujuan.
  static DateTime tambahBulan(DateTime dari, int bulan) {
    final total = dari.month - 1 + bulan;
    final tahun = dari.year + (total ~/ 12);
    final bulanBaru = (total % 12) + 1;
    final hariTerakhir = DateTime(tahun, bulanBaru + 1, 0).day;
    final hari = dari.day > hariTerakhir ? hariTerakhir : dari.day;
    return DateTime(
      tahun,
      bulanBaru,
      hari,
      dari.hour,
      dari.minute,
      dari.second,
    );
  }

  /// Tanggal awal perhitungan perpanjangan.
  ///
  /// 🔴 Disambung dari akhir periode yang masih berjalan — keputusan dagang
  /// Product Owner, 29 Agustus 2026. Ini **berbeda** dari pembayaran otomatis
  /// (`activate_subscription()`, migrasi 28), yang selalu menghitung ulang 30
  /// hari dari hari pembayaran. Perbedaannya disengaja: tombol perpanjang
  /// dipakai untuk memberi kompensasi, dan memperpanjang pelanggan yang masih
  /// punya 20 hari lalu justru memotong 20 hari itu adalah kejutan yang tidak
  /// dapat dibatalkan.
  ///
  /// ⚠️ Migrasi 28 baris 110 menuliskan larangan tegas: *"aturan perpanjangan
  /// adalah keputusan dagang, bukan teknis — jangan mengubahnya diam-diam"*.
  /// Yang hendak menyamakannya dengan pembayaran otomatis wajib bertanya
  /// lebih dulu. Dialognya mengatakan perbedaan ini apa adanya kepada Admin,
  /// bukan menyembunyikannya.
  static DateTime dasar(AdminTenantRow baris, DateTime kini) {
    final akhir = baris.periodEnd;
    return (akhir != null && akhir.isAfter(kini)) ? akhir : kini;
  }

  /// Apakah perpanjangan sekaligus mengembalikan statusnya menjadi aktif.
  ///
  /// 🔴 `suspended` **tidak** ikut diaktifkan. Penangguhan datang dari alasan
  /// di luar pembayaran, dan memperpanjang periode tidak boleh diam-diam
  /// mencabutnya. Sebaliknya `expired` dan `trial` wajib ikut aktif —
  /// memperpanjang tanpa itu menghasilkan pelanggan yang tanggal langganannya
  /// panjang tetapi tetap tidak dapat merekam (Bab 7.6): keadaan yang benar
  /// menurut database dan mustahil dipahami dari layar.
  static bool aktifkan(TenantStatus status) =>
      status == TenantStatus.expired || status == TenantStatus.trial;
}

/// Kolom yang dapat diurutkan pada tabel Kelola Pengguna.
enum AdminTenantSort {
  business,
  tier,
  status,
  created,
  period,
  shops,
  packers,
  videos,
  tokens,
}

/// Isi tabel Kelola Pengguna (Bab 11.2).
///
/// 🔴 Menyimpan **seluruh** baris sekaligus, tanpa halaman bernomor — berbeda
/// dari tabel Riwayat. Alasannya bukan kemalasan: yang dihitung di sini adalah
/// pelanggan, dan platform ini punya belasan. Menyaring dan mengurutkan di
/// dalam aplikasi juga membuat keduanya seketika, tanpa satu pun perjalanan ke
/// server.
///
/// ⚠️ Batasnya nyata dan tertulis di `AdminRepository.fetchAdminTenants`: 200
/// baris. Melewati angka itu, halaman ini butuh halaman bernomor seperti
/// Riwayat — dan yang menambahkannya nanti wajib memindahkan penyaringan dan
/// pengurutan ke server, karena keduanya tidak dapat bekerja benar pada satu
/// halaman saja.
class AdminUsersData {
  const AdminUsersData({
    required this.all,
    this.query = '',
    this.status,
    this.tier,
    this.sort = AdminTenantSort.created,
    this.ascending = false,
    this.selectedId,
  });

  /// Seluruh baris apa adanya dari server, sebelum disaring.
  final List<AdminTenantRow> all;

  final String query;
  final TenantStatus? status;
  final TierPlan? tier;
  final AdminTenantSort sort;
  final bool ascending;

  /// Baris yang panel sampingnya sedang terbuka. null = panel tertutup.
  final String? selectedId;

  bool get hasFilter =>
      query.trim().isNotEmpty || status != null || tier != null;

  /// Baris yang lolos saringan, sudah terurut.
  ///
  /// Dihitung ulang setiap kali dibaca, bukan disimpan. Daftar terurut yang
  /// disimpan berdampingan dengan daftar aslinya adalah dua sumber kebenaran
  /// yang akan berselisih pada perubahan pertama yang lupa memperbarui
  /// keduanya.
  List<AdminTenantRow> get items {
    final cari = query.trim().toLowerCase();

    final hasil = all.where((r) {
      if (status != null && r.status != status) return false;
      if (tier != null && r.tierPlan != tier) return false;
      if (cari.isEmpty) return true;
      // Nama usaha ATAU email — keduanya menunjuk orang yang sama, dan yang
      // mencari belum tentu ingat versi mana yang tercatat.
      return (r.businessName ?? '').toLowerCase().contains(cari) ||
          (r.ownerEmail ?? '').toLowerCase().contains(cari);
    }).toList();

    hasil.sort((a, b) {
      final n = switch (sort) {
        AdminTenantSort.business => a.label.toLowerCase().compareTo(
          b.label.toLowerCase(),
        ),
        AdminTenantSort.tier => a.tierPlan.index.compareTo(b.tierPlan.index),
        AdminTenantSort.status => a.status.index.compareTo(b.status.index),
        AdminTenantSort.created => _tanggal(
          a.createdAt,
        ).compareTo(_tanggal(b.createdAt)),
        AdminTenantSort.period => _tanggal(
          a.periodEnd,
        ).compareTo(_tanggal(b.periodEnd)),
        AdminTenantSort.shops => a.shopCount.compareTo(b.shopCount),
        AdminTenantSort.packers => a.packerCount.compareTo(b.packerCount),
        AdminTenantSort.videos => a.videoCount.compareTo(b.videoCount),
        AdminTenantSort.tokens => a.tokenBalance.compareTo(b.tokenBalance),
      };
      return ascending ? n : -n;
    });
    return hasil;
  }

  /// Tanggal kosong diperlakukan sebagai yang paling awal.
  ///
  /// 🔴 `period_end` NULL bukan data yang lupa diisi — ia berarti *masa uji
  /// coba*, yang memang tidak punya batas waktu (Bab 7.5). Mengumpulkannya di
  /// satu ujung membuat seluruh tenant uji coba berkumpul, alih-alih tersebar
  /// acak di tengah daftar.
  static DateTime _tanggal(DateTime? v) =>
      v ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Baris yang sedang terpilih, atau null bila baris itu sudah tidak ada lagi
  /// setelah daftar disegarkan.
  AdminTenantRow? get selected {
    final id = selectedId;
    if (id == null) return null;
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  AdminUsersData copyWith({
    List<AdminTenantRow>? all,
    String? query,
    TenantStatus? status,
    TierPlan? tier,
    AdminTenantSort? sort,
    bool? ascending,
    String? selectedId,
    bool clearStatus = false,
    bool clearTier = false,
    bool clearSelection = false,
  }) => AdminUsersData(
    all: all ?? this.all,
    query: query ?? this.query,
    status: clearStatus ? null : (status ?? this.status),
    tier: clearTier ? null : (tier ?? this.tier),
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
  );
}

/// Tabel Kelola Pengguna beserta ketiga aksinya (Bab 11.2).
///
/// 🔴 Ketiga aksi di sini menyentuh **pelanggan yang sedang bekerja**.
/// Menangguhkan mengunci perekaman seketika (Bab 7.6); menurunkan tier
/// memangkas jumlah packer dan durasi video yang boleh direkam. Karena itu
/// ViewModel ini tidak pernah mengubah apa pun atas inisiatifnya sendiri:
/// tidak ada percobaan ulang otomatis, dan setiap perubahan datang dari satu
/// ketukan manusia yang sudah membaca nama usahanya di dialog konfirmasi.
@riverpod
class AdminUsersViewModel extends _$AdminUsersViewModel {
  Timer? _cariDebounce;

  @override
  Future<AdminUsersData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    ref.onDispose(() => _cariDebounce?.cancel());

    debugPrint('KAMELSCAN_ADMIN minta daftar pelanggan');
    final hasil = await ref.read(adminRepositoryProvider).fetchAdminTenants();

    // Jalur gagal ikut dicetak — aturan L.9. Yang bukan admin sampai di sini
    // dengan galat izin, dan itu perilaku yang benar: fungsi servernya
    // menolak, bukan mengembalikan daftar kosong.
    debugPrint(
      'KAMELSCAN_ADMIN daftar pelanggan '
      '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} baris' : 'GAGAL · ${hasil.failureOrNull}'}',
    );

    return AdminUsersData(all: hasil.unwrap());
  }

  /// Ambil ulang dari server sambil **mempertahankan** saringan, urutan, dan
  /// baris yang sedang terbuka.
  ///
  /// 🔴 Mengembalikan saringan ke kosong sesudah setiap aksi adalah cacat yang
  /// mahal di halaman seperti ini: admin yang sedang menelusuri satu pelanggan
  /// dari daftar tersaring kehilangan tempatnya tepat setelah menekan tombol,
  /// dan akan mengira aksinya membuat barisnya hilang.
  Future<void> refresh() async {
    final lama = state.value;
    state = await AsyncValue.guard(() async {
      final baris =
          (await ref.read(adminRepositoryProvider).fetchAdminTenants())
              .unwrap();
      return lama == null
          ? AdminUsersData(all: baris)
          : lama.copyWith(all: baris);
    });
  }

  void _ubah(AdminUsersData Function(AdminUsersData) f) {
    final kini = state.value;
    if (kini == null) return;
    state = AsyncData(f(kini));
  }

  /// Pencarian ditunda 300 ms.
  ///
  /// Penyaringannya berjalan di dalam aplikasi, jadi penundaan ini bukan demi
  /// menghemat permintaan ke server — melainkan agar tabelnya tidak digambar
  /// ulang pada setiap huruf yang diketik.
  void search(String q) {
    _cariDebounce?.cancel();
    _cariDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _ubah((d) => d.copyWith(query: q)),
    );
  }

  void selectStatus(TenantStatus? v) => _ubah(
    (d) => v == null ? d.copyWith(clearStatus: true) : d.copyWith(status: v),
  );

  void selectTier(TierPlan? v) => _ubah(
    (d) => v == null ? d.copyWith(clearTier: true) : d.copyWith(tier: v),
  );

  void clearFilters() =>
      _ubah((d) => d.copyWith(query: '', clearStatus: true, clearTier: true));

  /// Menekan kolom yang sama membalik arahnya; kolom lain mulai dari menurun.
  ///
  /// Menurun lebih dulu karena pada hampir setiap kolom di tabel ini yang
  /// dicari adalah ujung atasnya: yang paling baru mendaftar, yang paling
  /// banyak videonya, yang tokennya paling banyak tersisa.
  void sortBy(AdminTenantSort kolom) => _ubah(
    (d) => d.sort == kolom
        ? d.copyWith(ascending: !d.ascending)
        : d.copyWith(sort: kolom, ascending: false),
  );

  void select(String? id) => _ubah(
    (d) => id == null
        ? d.copyWith(clearSelection: true)
        : d.copyWith(selectedId: id),
  );

  /// Ubah tier tenant (Bab 11.2).
  ///
  /// ⚠️ Bab 5.3 — `tier_plan` dibawa di dalam JWT. Pelanggannya wajib keluar
  /// lalu masuk lagi sebelum batas tier baru terasa; sampai saat itu layarnya
  /// masih menulis keadaan lama padahal database sudah benar. Layar yang
  /// memanggil ini wajib mengatakannya.
  Future<AppFailure?> changeTier(AdminTenantRow baris, TierPlan plan) async {
    debugPrint('KAMELSCAN_ADMIN ubah tier ${baris.id} → ${plan.wire}');
    final hasil = await ref
        .read(adminRepositoryProvider)
        .changeTier(tenantId: baris.id, plan: plan);

    // 🔴 Daftar disegarkan HANYA setelah berhasil. Menyegarkannya lebih dulu
    // membuat barisnya tampak berubah walaupun servernya menolak — dan yang
    // melihatnya akan mengira pekerjaannya sudah selesai.
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN ubah tier '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }

  /// Tangguhkan atau aktifkan kembali (Bab 11.2).
  ///
  /// 🔴 Menangguhkan mengunci perekaman **seketika** (Bab 7.6) — tidak ada
  /// masa tenggang, dan packer yang sedang berdiri di depan kamera akan
  /// berhenti di tengah jalan.
  Future<AppFailure?> setStatus(
    AdminTenantRow baris,
    TenantStatus status,
  ) async {
    debugPrint('KAMELSCAN_ADMIN status ${baris.id} → ${status.wire}');
    final hasil = await ref
        .read(adminRepositoryProvider)
        .setTenantStatus(tenantId: baris.id, status: status);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN status '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }

  /// Tambah atau kurangi token satu pelanggan (Bab 11.2).
  ///
  /// [delta] negatif berarti mengurangi. [reason] wajib dan ditegakkan di
  /// server — buku besar token adalah satu-satunya alat menyelesaikan sengketa
  /// (Bab 7.2 poin 5).
  ///
  /// ⚠️ Bonusnya hangus pada reset periode berikutnya. Itu keputusan, bukan
  /// cacat — lihat [Perpanjangan] dan dialog yang memanggil metode ini.
  Future<AppFailure?> adjustTokens(
    AdminTenantRow baris, {
    required int delta,
    required String reason,
  }) async {
    debugPrint('KAMELSCAN_ADMIN token ${baris.id} delta=$delta');
    final hasil = await ref
        .read(adminRepositoryProvider)
        .adjustTokens(tenantId: baris.id, delta: delta, reason: reason);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN token '
      '${hasil.isOk ? 'BERHASIL · saldo ${hasil.valueOrNull}' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }

  /// Beri token serentak ke seluruh pelanggan berstatus aktif.
  ///
  /// Mengembalikan `(sasaran, berhasil, kegagalan)`. Dua angka pertama
  /// biasanya sama; selisihnya berarti ada tenant aktif yang dompetnya hilang,
  /// dan layar wajib menampilkannya alih-alih satu angka yang menutupinya.
  Future<({int target, int granted, AppFailure? failure})> grantTokensToAll({
    required int delta,
    required String reason,
  }) async {
    debugPrint('KAMELSCAN_ADMIN token serentak delta=$delta');
    final hasil = await ref
        .read(adminRepositoryProvider)
        .grantTokensToAllActive(delta: delta, reason: reason);
    if (hasil.isOk) await refresh();

    final nilai = hasil.valueOrNull;
    debugPrint(
      'KAMELSCAN_ADMIN token serentak '
      '${hasil.isOk ? 'BERHASIL · ${nilai?.granted}/${nilai?.target}' : 'GAGAL · ${hasil.failureOrNull}'}',
    );

    return (
      target: nilai?.target ?? 0,
      granted: nilai?.granted ?? 0,
      failure: hasil.failureOrNull,
    );
  }

  /// Perpanjang periode langganan (Bab 11.2).
  ///
  /// [reactivate] ditentukan layar, bukan di sini — alasannya tertulis di
  /// `AdminRepository.extendPeriod`.
  Future<AppFailure?> extendPeriod(
    AdminTenantRow baris, {
    required DateTime periodEnd,
    required bool reactivate,
  }) async {
    debugPrint(
      'KAMELSCAN_ADMIN perpanjang ${baris.id} → '
      '${periodEnd.toIso8601String()} aktifkan=$reactivate',
    );
    final hasil = await ref
        .read(adminRepositoryProvider)
        .extendPeriod(
          tenantId: baris.id,
          periodEnd: periodEnd,
          reactivate: reactivate,
        );
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN perpanjang '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }
}
