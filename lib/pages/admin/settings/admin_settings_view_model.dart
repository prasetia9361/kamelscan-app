import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/tier_config.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/payment_methods.dart';
import '../../../core/models/platform_contact.dart';
import '../../../core/models/promo.dart';
import '../../../core/models/tutorial.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';

part 'admin_settings_view_model.g.dart';

/// Isi halaman Harga & Paket (Bab 11.3).
///
/// Menggabungkan dua baris `platform_settings` yang berbeda — `pricing` dan
/// `infra_cost` — karena keduanya dijawab pertanyaan yang sama: *"berapa
/// angka usaha ini"*. Memisahkannya menjadi dua halaman berarti Admin harus
/// mengingat bahwa biaya infrastruktur ada di tempat lain, dan tidak akan.
class AdminPricingData {
  const AdminPricingData({required this.catalog, this.infraCost});

  final TierCatalog catalog;

  /// null = belum pernah diisi. Dasbor Platform menuliskannya sebagai belum
  /// diisi alih-alih menganggapnya nol.
  final num? infraCost;
}

/// Harga, batas paket, dan biaya infrastruktur (Bab 11.3).
///
/// 🔴 Layar ini mengubah aturan yang berlaku bagi **seluruh pelanggan
/// sekaligus**. Salah satu angka yang keliru tidak menghasilkan galat apa pun:
/// ia hanya membuat setiap perangkat membaca batas yang berbeda dari yang
/// dimaksud, dan baru ketahuan saat seorang packer tidak bisa merekam.
@riverpod
class AdminPricingViewModel extends _$AdminPricingViewModel {
  @override
  Future<AdminPricingData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final repo = ref.read(adminSettingsRepositoryProvider);

    debugPrint('KAMELSCAN_ADMIN minta pengaturan harga');
    final harga = await repo.fetchPricing();
    final biaya = await repo.fetchInfraCost();

    debugPrint(
      'KAMELSCAN_ADMIN pengaturan harga '
      '${harga.isOk ? 'OK' : 'GAGAL · ${harga.failureOrNull}'}',
    );

    return AdminPricingData(
      catalog: harga.unwrap(),
      // Biaya infrastruktur boleh gagal dibaca tanpa menjatuhkan halamannya:
      // ia hanya mengisi satu kolom, sementara harga adalah isi utamanya.
      infraCost: biaya.valueOrNull,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<AppFailure?> save({
    required List<TierConfig> tiers,
    required num? infraCost,
  }) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    debugPrint(
      'KAMELSCAN_ADMIN simpan harga '
      '${tiers.map((e) => '${e.plan.wire}=${e.price}').join(' ')} '
      'biaya=$infraCost',
    );

    final harga = await repo.savePricing(tiers: tiers);
    if (harga.isErr) {
      debugPrint('KAMELSCAN_ADMIN simpan harga GAGAL · ${harga.failureOrNull}');
      return harga.failureOrNull;
    }

    // 🔴 Biaya infrastruktur disimpan SESUDAH harga, dan kegagalannya
    // dilaporkan apa adanya. Menyimpan keduanya dalam satu panggilan tidak
    // mungkin — keduanya baris berbeda — jadi yang dapat dilakukan hanyalah
    // tidak berpura-pura keduanya selalu berhasil bersamaan.
    final biaya = await repo.saveInfraCost(infraCost);
    if (biaya.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN simpan harga '
      '${biaya.isOk ? 'BERHASIL' : 'GAGAL di biaya · ${biaya.failureOrNull}'}',
    );
    return biaya.failureOrNull;
  }
}

/// Metode pembayaran yang aktif (Bab 11.6).
///
/// 🔴 Seluruh gunanya adalah agar Midtrans dapat dinyalakan begitu verifikasi
/// merchant selesai **tanpa merilis aplikasi baru** — verifikasi itu memakan
/// 5–14 hari kerja dan sepenuhnya di luar kendali tim (Bab 12.1).
@riverpod
class AdminPaymentMethodsViewModel extends _$AdminPaymentMethodsViewModel {
  @override
  Future<PaymentMethods> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta metode pembayaran');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .fetchPaymentMethods();

    debugPrint(
      'KAMELSCAN_ADMIN metode pembayaran '
      '${hasil.isOk ? 'OK' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<AppFailure?> save(PaymentMethods methods) async {
    debugPrint(
      'KAMELSCAN_ADMIN simpan metode midtrans=${methods.midtransEnabled} '
      'manual=${methods.manualTransferEnabled} '
      'rekening=${methods.bankAccounts.length}',
    );

    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .savePaymentMethods(methods);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN simpan metode '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }
}

/// Kontak dukungan (Bab 11.5).
@riverpod
class AdminContactViewModel extends _$AdminContactViewModel {
  @override
  Future<PlatformContact> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta kontak');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .fetchContact();

    debugPrint(
      'KAMELSCAN_ADMIN kontak '
      '${hasil.isOk ? 'OK' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<AppFailure?> save(PlatformContact contact) async {
    debugPrint('KAMELSCAN_ADMIN simpan kontak');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .saveContact(contact);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN simpan kontak '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }
}

/// Daftar kode promo (Bab 11.4).
@riverpod
class AdminPromosViewModel extends _$AdminPromosViewModel {
  @override
  Future<List<Promo>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta daftar promo');
    final hasil = await ref.read(adminSettingsRepositoryProvider).fetchPromos();

    debugPrint(
      'KAMELSCAN_ADMIN daftar promo '
      '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} kode' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<AppFailure?> upsert(Promo promo) async {
    debugPrint('KAMELSCAN_ADMIN simpan promo ${promo.code}');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .upsertPromo(promo);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN simpan promo '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }

  /// Menghidupkan atau mematikan satu kode tanpa membuka formulirnya.
  ///
  /// Inilah aksi yang paling sering dibutuhkan: promo berakhir lebih cepat
  /// daripada rencananya, dan yang diperlukan hanya mematikannya — bukan
  /// menyunting seluruh isinya.
  Future<AppFailure?> setActive(Promo promo, bool active) =>
      upsert(promo.copyWith(isActive: active));

  Future<AppFailure?> delete(String code) async {
    debugPrint('KAMELSCAN_ADMIN hapus promo $code');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .deletePromo(code);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN hapus promo '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }
}

/// Daftar langkah tutorial (Bab 9.9).
///
/// 🔴 Memakai `fetchTutorials()`, bukan `TutorialRepository.fetchActive()`.
/// Yang kedua disaring policy `tutorials_read` (`using (is_active)`), sehingga
/// langkah yang baru saja dinonaktifkan Admin akan **lenyap dari layarnya
/// sendiri** dan tidak ada lagi cara mengaktifkannya kembali dari aplikasi.
@riverpod
class AdminTutorialsViewModel extends _$AdminTutorialsViewModel {
  @override
  Future<List<Tutorial>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta daftar tutorial');
    final hasil =
        await ref.read(adminSettingsRepositoryProvider).fetchTutorials();

    debugPrint(
      'KAMELSCAN_ADMIN daftar tutorial '
      '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} langkah' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<AppFailure?> upsert(Tutorial tutorial) async {
    debugPrint('KAMELSCAN_ADMIN simpan tutorial "${tutorial.title}"');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .upsertTutorial(tutorial);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN simpan tutorial '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }

  /// Menghidupkan atau mematikan satu langkah tanpa membuka formulirnya.
  ///
  /// Aksi yang paling sering dibutuhkan: video sedang direkam ulang, dan yang
  /// diperlukan hanya menyembunyikannya sementara — bukan menghapusnya lalu
  /// mengetik ulang seluruh isinya nanti.
  Future<AppFailure?> setActive(Tutorial tutorial, bool active) =>
      upsert(tutorial.copyWith(isActive: active));

  Future<AppFailure?> delete(String id) async {
    debugPrint('KAMELSCAN_ADMIN hapus tutorial $id');
    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .deleteTutorial(id);
    if (hasil.isOk) await refresh();

    debugPrint(
      'KAMELSCAN_ADMIN hapus tutorial '
      '${hasil.isOk ? 'BERHASIL' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.failureOrNull;
  }
}

/// Gambar iklan landing page dan kartu paket (Bab 11.5).
///
/// 🔴 Utang nomor 3 daftar kesiapan produksi. Bab 11.5 menyebut gambar iklan
/// diunggah ke bucket `public-assets`, tetapi buckets itu **tidak pernah
/// dibuat** — diukur 3 September 2026, yang ada hanya `avatars` (migrasi 23)
/// dan `payment-proofs` (migrasi 25). Bucket-nya lahir di migrasi 46.
///
/// Alamat gambarnya sendiri sudah punya tempat sejak migrasi 08; yang kurang
/// hanya tempat menaruh berkasnya.
class AdminBannerData {
  const AdminBannerData({required this.landing, required this.payment});

  /// `{image_url, headline, subheadline}`.
  final Map<String, dynamic> landing;

  /// `{standar_image_url, pro_image_url, bisnis_image_url}`.
  final Map<String, dynamic> payment;

  String get landingImage => (landing['image_url'] as String?) ?? '';
  String get landingHeadline => (landing['headline'] as String?) ?? '';
  String get landingSub => (landing['subheadline'] as String?) ?? '';

  /// ⚠️ Kunci per paket dibangun dari `TierPlan.wire`, bukan ditulis satu per
  /// satu. Menyebut nama paket satu per satu adalah Pola A yang sudah muncul
  /// tiga kali di proyek ini — dan setiap kali akibatnya sama: paket Bisnis
  /// tidak pernah tergambar.
  String imageFor(TierPlan plan) =>
      (payment['${plan.wire}_image_url'] as String?) ?? '';
}

@riverpod
class AdminBannersViewModel extends _$AdminBannersViewModel {
  @override
  Future<AdminBannerData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final repo = ref.read(adminSettingsRepositoryProvider);
    debugPrint('KAMELSCAN_ADMIN minta gambar iklan');

    final landing = await repo.fetchLandingBanner();
    if (landing.isErr) throw landing.failureOrNull!;
    final payment = await repo.fetchPaymentBanners();
    if (payment.isErr) throw payment.failureOrNull!;

    return AdminBannerData(
      landing: Map<String, dynamic>.from(landing.valueOrNull!),
      payment: Map<String, dynamic>.from(payment.valueOrNull!),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Mengunggah satu gambar lalu menyimpan alamatnya.
  ///
  /// 🔴 Dua langkah yang WAJIB berurutan dan tidak boleh terbalik: berkasnya
  /// diunggah lebih dulu, baru alamatnya disimpan. Menyimpan alamat untuk
  /// berkas yang belum tentu sampai berarti halaman depan menunjuk gambar yang
  /// tidak ada — dan yang melihatnya calon pelanggan, bukan kita.
  Future<AppFailure?> unggahLanding(Uint8List bytes) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    final unggah = await repo.uploadPublicAsset(
      nama: 'landing.jpg',
      bytes: bytes,
    );
    if (unggah.isErr) {
      debugPrint('KAMELSCAN_ADMIN unggah landing GAGAL · '
          '${unggah.failureOrNull}');
      return unggah.failureOrNull;
    }

    final kini = Map<String, dynamic>.from(state.value?.landing ?? {});
    kini['image_url'] = unggah.valueOrNull;
    final simpan = await repo.saveLandingBanner(kini);
    if (simpan.isOk) await refresh();
    return simpan.failureOrNull;
  }

  Future<AppFailure?> unggahPaket(TierPlan plan, Uint8List bytes) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    final unggah = await repo.uploadPublicAsset(
      nama: 'plan-${plan.wire}.jpg',
      bytes: bytes,
    );
    if (unggah.isErr) {
      debugPrint('KAMELSCAN_ADMIN unggah paket ${plan.wire} GAGAL · '
          '${unggah.failureOrNull}');
      return unggah.failureOrNull;
    }

    final kini = Map<String, dynamic>.from(state.value?.payment ?? {});
    kini['${plan.wire}_image_url'] = unggah.valueOrNull;
    final simpan = await repo.savePaymentBanners(kini);
    if (simpan.isOk) await refresh();
    return simpan.failureOrNull;
  }

  // ---------------------------------------------------------------
  // Menghapus gambar
  // ---------------------------------------------------------------
  //
  // 🔴 Urutannya KEBALIKAN dari mengunggah, dan itu disengaja.
  //
  // Mengunggah: berkas dulu, baru alamatnya — supaya halaman depan tidak
  // pernah menunjuk berkas yang belum tentu sampai.
  //
  // Menghapus: alamatnya dulu, baru berkasnya — dengan alasan yang sama dari
  // arah sebaliknya. Bila berkasnya dibuang lebih dulu lalu penyimpanan
  // alamatnya gagal, landing page menunjuk gambar yang sudah tidak ada, dan
  // yang melihat gambar rusak itu calon pelanggan.
  //
  // Kebalikannya hanya menyisakan berkas yatim di bucket: memakan beberapa
  // ratus kilobyte, tidak terlihat siapa pun, dan tertimpa sendiri saat Admin
  // mengunggah gambar baru — karena namanya tetap `landing.jpg`.

  /// Membuang spanduk landing page.
  Future<AppFailure?> hapusLanding() async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    final kini = Map<String, dynamic>.from(state.value?.landing ?? {});
    kini['image_url'] = '';
    final simpan = await repo.saveLandingBanner(kini);
    if (simpan.isErr) {
      debugPrint('KAMELSCAN_ADMIN hapus landing GAGAL · '
          '${simpan.failureOrNull}');
      return simpan.failureOrNull;
    }

    // Berkasnya menyusul. Gagalnya TIDAK dilaporkan sebagai kegagalan —
    // bagi Admin gambarnya memang sudah hilang dari halaman depan, dan itu
    // yang ia minta.
    final buang = await repo.deletePublicAsset('landing.jpg');
    if (buang.isErr) {
      debugPrint('KAMELSCAN_ADMIN berkas landing.jpg tertinggal di bucket · '
          '${buang.failureOrNull}');
    }

    await refresh();
    return null;
  }

  /// Membuang gambar satu kartu paket.
  Future<AppFailure?> hapusPaket(TierPlan plan) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    final kini = Map<String, dynamic>.from(state.value?.payment ?? {});
    kini['${plan.wire}_image_url'] = '';
    final simpan = await repo.savePaymentBanners(kini);
    if (simpan.isErr) {
      debugPrint('KAMELSCAN_ADMIN hapus paket ${plan.wire} GAGAL · '
          '${simpan.failureOrNull}');
      return simpan.failureOrNull;
    }

    final buang = await repo.deletePublicAsset('plan-${plan.wire}.jpg');
    if (buang.isErr) {
      debugPrint('KAMELSCAN_ADMIN berkas plan-${plan.wire}.jpg tertinggal '
          'di bucket · ${buang.failureOrNull}');
    }

    await refresh();
    return null;
  }

  /// Menyimpan judul dan subjudul landing page tanpa menyentuh gambarnya.
  Future<AppFailure?> simpanTeksLanding({
    required String headline,
    required String subheadline,
  }) async {
    final kini = Map<String, dynamic>.from(state.value?.landing ?? {});
    kini['headline'] = headline;
    kini['subheadline'] = subheadline;

    final hasil = await ref
        .read(adminSettingsRepositoryProvider)
        .saveLandingBanner(kini);
    if (hasil.isOk) await refresh();
    return hasil.failureOrNull;
  }
}

/// Iklan & pengumuman saat login (migrasi 50).
///
/// Diminta Product Owner 5 September 2026. Halaman ini satu-satunya cara
/// mengumumkan sesuatu kepada seluruh pengguna — termasuk mewajibkan mereka
/// memperbarui aplikasi — tanpa merilis aplikasi baru.
///
/// 🔴 Sama seperti Harga dan Metode Pembayaran, isi halaman ini berlaku bagi
/// **seluruh pelanggan sekaligus**. Bedanya satu pengumuman yang salah di sini
/// dapat MENGUNCI mereka semua: jenis `important` tanpa tautan aksi yang sah
/// adalah jalan buntu. Formulirnya menolak keadaan itu sebelum disimpan.
@riverpod
class AdminAnnouncementsViewModel extends _$AdminAnnouncementsViewModel {
  @override
  Future<List<Announcement>> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    debugPrint('KAMELSCAN_ADMIN minta daftar pengumuman');
    final hasil =
        await ref.read(adminSettingsRepositoryProvider).fetchAnnouncements();

    debugPrint(
      'KAMELSCAN_ADMIN daftar pengumuman '
      '${hasil.isOk ? 'OK · ${hasil.valueOrNull?.length} baris' : 'GAGAL · ${hasil.failureOrNull}'}',
    );
    return hasil.unwrap();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Menyimpan satu pengumuman, beserta gambarnya bila ada yang baru dipilih.
  ///
  /// 🔴 Urutannya WAJIB baris dulu, gambar belakangan, dan itu kebalikan dari
  /// gambar iklan landing page (`unggahLanding`). Alasannya bukan gaya:
  /// berkasnya dinamai `announcement-<id>.jpg`, sehingga **id-nya harus sudah
  /// ada** sebelum berkasnya punya nama. Pengumuman baru belum punya id sampai
  /// server membuatnya.
  ///
  /// ⚠️ Karena itu ada dua penulisan untuk satu penyimpanan, dan yang kedua
  /// dapat gagal sendirian: barisnya sudah tersimpan, gambarnya tidak.
  /// Kegagalannya dilaporkan apa adanya — Admin melihat pengumumannya ada di
  /// daftar tanpa gambar, dan dapat mengulang unggahannya. Kebalikannya
  /// (gambar tanpa baris) tidak mungkin terjadi sama sekali.
  Future<AppFailure?> simpan(Announcement a, {Uint8List? gambar}) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    debugPrint('KAMELSCAN_ADMIN simpan pengumuman "${a.title}" '
        '(${a.kind.wire}/${a.audience.wire})');

    final baris = await repo.upsertAnnouncement(a);
    if (baris.isErr) {
      debugPrint('KAMELSCAN_ADMIN simpan pengumuman GAGAL · '
          '${baris.failureOrNull}');
      return baris.failureOrNull;
    }

    final id = baris.valueOrNull!;

    if (gambar != null) {
      final unggah = await repo.uploadPublicAsset(
        nama: berkasGambar(id),
        bytes: gambar,
      );
      if (unggah.isErr) {
        await refresh();
        debugPrint('KAMELSCAN_ADMIN unggah gambar pengumuman GAGAL · '
            '${unggah.failureOrNull}');
        return unggah.failureOrNull;
      }

      final alamat = await repo.upsertAnnouncement(
        a.copyWith(id: id, imageUrl: unggah.valueOrNull),
      );
      if (alamat.isErr) {
        await refresh();
        return alamat.failureOrNull;
      }
    }

    await refresh();
    return null;
  }

  /// Menghidupkan atau mematikan satu pengumuman tanpa membuka formulirnya.
  ///
  /// Aksi yang paling sering dibutuhkan: event sudah lewat, dan yang diperlukan
  /// hanya menyembunyikannya — bukan menghapusnya lalu mengetik ulang seluruh
  /// isinya tahun depan.
  ///
  /// 🔴 Ini juga tombol darurat untuk pengumuman `important`. Kalau tautan
  /// aksinya ternyata salah, mematikannya di sini adalah satu-satunya cara
  /// melepaskan seluruh pengguna yang sedang terkunci.
  Future<AppFailure?> setActive(Announcement a, bool active) =>
      simpan(a.copyWith(isActive: active));

  /// Menghapus satu pengumuman beserta berkas gambarnya.
  ///
  /// ⚠️ Catatan siapa saja yang sudah menutupnya ikut terbuang lewat
  /// `on delete cascade` (migrasi 50). Berkas gambarnya TIDAK — Storage bukan
  /// bagian dari cascade — jadi ia dibuang di sini, sesudah barisnya hilang.
  ///
  /// Kegagalan membuang berkasnya tidak dilaporkan sebagai kegagalan: bagi
  /// Admin pengumumannya memang sudah hilang, dan itu yang ia minta. Yang
  /// tertinggal hanya berkas yatim beberapa ratus kilobyte yang tidak dapat
  /// ditemukan siapa pun lagi.
  Future<AppFailure?> hapus(Announcement a) async {
    final repo = ref.read(adminSettingsRepositoryProvider);

    debugPrint('KAMELSCAN_ADMIN hapus pengumuman ${a.id}');
    final hasil = await repo.deleteAnnouncement(a.id);
    if (hasil.isErr) {
      debugPrint('KAMELSCAN_ADMIN hapus pengumuman GAGAL · '
          '${hasil.failureOrNull}');
      return hasil.failureOrNull;
    }

    final buang = await repo.deletePublicAsset(berkasGambar(a.id));
    if (buang.isErr) {
      debugPrint('KAMELSCAN_ADMIN berkas ${berkasGambar(a.id)} tertinggal '
          'di bucket · ${buang.failureOrNull}');
    }

    await refresh();
    return null;
  }

  /// Nama berkas gambar sebuah pengumuman di bucket `public-assets`.
  ///
  /// 🔴 Memakai id, BUKAN nama tetap seperti `landing.jpg`. Di sana hanya ada
  /// satu gambar yang selalu ditimpa; di sini pengumumannya banyak dan hidup
  /// bersamaan, sehingga nama tetap berarti pengumuman kedua menimpa gambar
  /// pengumuman pertama — dan yang pertama berubah gambarnya sendiri tanpa ada
  /// yang menyentuhnya.
  static String berkasGambar(String id) => 'announcement-$id.jpg';
}
