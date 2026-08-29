import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/tier_config.dart';
import '../../core/domain/billing.dart';
import '../../core/models/enums.dart';
import '../../core/models/payment_methods.dart';
import '../../core/models/promo.dart';
import '../../core/models/subscription.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/utils/app_failure.dart';

part 'plan_view_model.g.dart';

/// Isi halaman Pilih Paket (Bab 9.8).
class PlanData {
  const PlanData({
    required this.catalog,
    required this.currentPlan,
    required this.isTrial,
    required this.methods,
    required this.banners,
    required this.selected,
    this.pending,
    this.rejected,
    this.promo,
    this.promoRejectionKey,
  });

  final TierCatalog catalog;

  /// Paket yang sedang berjalan — kartunya diberi label *Paket Aktif* dan
  /// tombolnya dimatikan.
  final TierPlan currentPlan;

  /// Selama uji coba, belum ada paket yang benar-benar dibeli, sehingga tidak
  /// ada kartu yang boleh mengaku aktif.
  final bool isTrial;

  final PaymentMethods methods;
  final Map<String, String> banners;

  /// Paket yang sedang dipilih Owner di layar.
  final TierPlan selected;

  /// Tagihan yang belum tuntas. Selama ini ada, Owner diarahkan
  /// menyelesaikannya alih-alih membuat tagihan baru.
  final Subscription? pending;

  /// Tagihan terakhir yang **ditolak Admin**, selama belum ada tagihan baru.
  ///
  /// 🔴 Ada di sini karena ketiadaannya adalah cacat sungguhan: sampai
  /// 29 Agustus 2026, menolak pembayaran hanya membuat spanduk "menunggu
  /// verifikasi" lenyap tanpa satu kalimat pun yang menggantikannya. Dari sisi
  /// Owner, tagihan yang uangnya sudah ia kirim seolah menguap.
  final Subscription? rejected;

  final Promo? promo;

  /// Kunci l10n alasan kode promo ditolak; null bila tidak ada masalah.
  final String? promoRejectionKey;

  TierConfig get selectedTier => catalog.of(selected);

  num get subtotal => selectedTier.price;
  num get discount => promo?.discountFor(subtotal) ?? 0;
  num get total => subtotal - discount;

  /// Kartu paket ini sedang berjalan.
  ///
  /// Selama uji coba jawabannya selalu `false`: Bab 7.5 memberi tenant uji coba
  /// kemampuan setara Standar, tetapi ia belum membeli apa pun. Kartu Standar
  /// yang berlabel *Paket Aktif* akan membuat Owner mengira ia sudah berlangganan
  /// dan tidak perlu membayar.
  bool isActivePlan(TierPlan plan) => !isTrial && plan == currentPlan;

  PlanData copyWith({
    TierPlan? selected,
    Subscription? pending,
    Promo? promo,
    String? promoRejectionKey,
    bool hapusPromo = false,
  }) =>
      PlanData(
        catalog: catalog,
        currentPlan: currentPlan,
        isTrial: isTrial,
        methods: methods,
        banners: banners,
        selected: selected ?? this.selected,
        pending: pending ?? this.pending,

        // Tagihan baru menjawab penolakan yang lama. Membiarkan spanduk merah
        // tetap berdiri di samping tagihan yang sedang berjalan membuat Owner
        // mengira yang baru ikut ditolak.
        rejected: pending != null ? null : rejected,
        promo: hapusPromo ? null : (promo ?? this.promo),
        promoRejectionKey: hapusPromo ? null : promoRejectionKey,
      );
}

/// Halaman Pilih Paket (Bab 9.8 — Owner saja).
@riverpod
class PlanViewModel extends _$PlanViewModel {
  @override
  Future<PlanData> build() async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    final repo = ref.read(subscriptionRepositoryProvider);

    final methods =
        (await repo.fetchPaymentMethods()).getOrElse((_) => PaymentMethods.fallback);
    final banners = (await repo.fetchPlanBanners()).getOrElse((_) => const {});
    final pending = (await repo.fetchLatest()).valueOrNull;

    // Paket yang ditawarkan lebih dulu adalah yang belum dimiliki. Owner yang
    // sudah Standar datang ke sini untuk naik ke Pro, bukan untuk membeli
    // Standar lagi.
    final sekarang = session.plan;
    final pilihanAwal = (!session.isTrial && sekarang == TierPlan.standar)
        ? TierPlan.pro
        : TierPlan.standar;

    return PlanData(
      catalog: session.tierCatalog,
      currentPlan: sekarang,
      isTrial: session.isTrial,
      methods: methods,
      banners: banners,
      selected: pilihanAwal,
      pending: pending != null && pending.isPending ? pending : null,

      // Hanya tagihan TERAKHIR. Penolakan yang lebih lama sudah terjawab oleh
      // tagihan sesudahnya, dan menampilkannya kembali berarti mengungkit
      // masalah yang sudah selesai setiap kali halaman ini dibuka.
      rejected: pending != null && pending.isRejected ? pending : null,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void select(TierPlan plan) {
    final data = state.value;
    if (data == null) return;

    // Kode promo dilepas saat paketnya berganti: promo dapat dibatasi ke satu
    // paket saja (`promos.applies_to`), dan potongan yang tetap menempel akan
    // menampilkan angka yang tidak akan disetujui server.
    state = AsyncData(data.copyWith(selected: plan, hapusPromo: true));
  }

  /// Memeriksa kode promo ke tabel `promos`.
  ///
  /// Pemeriksaan lengkapnya tetap milik server saat Admin memverifikasi; yang
  /// di sini agar Owner tahu angkanya sebelum menekan Bayar, dan agar kode yang
  /// jelas-jelas salah tidak berakhir menjadi tagihan yang gagal diverifikasi.
  Future<void> applyPromo(String code) async {
    final data = state.value;
    if (data == null) return;

    final bersih = code.trim();
    if (bersih.isEmpty) {
      state = AsyncData(data.copyWith(hapusPromo: true));
      return;
    }

    final hasil = await ref.read(subscriptionRepositoryProvider).findPromo(bersih);

    hasil.fold(
      onOk: (promo) {
        if (promo == null) {
          debugPrint('KAMELSCAN_BAYAR promo tidak ditemukan · $bersih');
          state = AsyncData(
            data.copyWith(hapusPromo: true, promoRejectionKey: 'promoNotFound'),
          );
          return;
        }

        final tolak = promo.rejectionKey(data.selected, DateTime.now());
        if (tolak != null) {
          debugPrint('KAMELSCAN_BAYAR promo ditolak · $bersih · $tolak');
          state = AsyncData(
            data.copyWith(hapusPromo: true, promoRejectionKey: tolak),
          );
          return;
        }

        state = AsyncData(data.copyWith(promo: promo));
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_BAYAR promo GAGAL dibaca · $failure');
        state = AsyncData(
          data.copyWith(hapusPromo: true, promoRejectionKey: 'promoNotFound'),
        );
      },
    );
  }

  void clearPromo() {
    final data = state.value;
    if (data == null) return;
    state = AsyncData(data.copyWith(hapusPromo: true));
  }

  /// Membuat tagihan `pending` dan mengembalikannya (Bab 12.2 langkah 2).
  ///
  /// 🔴 Digit pembeda dibangkitkan **di sini, sekali**, bukan setiap kali layar
  /// digambar ulang. Nominal yang berubah-ubah di depan mata Owner adalah cara
  /// tercepat membuat orang mentransfer angka yang sudah tidak berlaku.
  Future<(Subscription?, AppFailure?)> createBill() async {
    final data = state.value;
    if (data == null) return (null, AppFailure.sessionExpired);

    final session = ref.read(sessionProvider).value;
    if (session == null) return (null, AppFailure.sessionExpired);

    final rincian = BillingSummary.of(
      price: data.subtotal,
      promo: data.promo,
    );

    final hasil = await ref.read(subscriptionRepositoryProvider).createPending(
          tenantId: session.tenantId,
          plan: data.selected,
          amount: rincian.amountToTransfer,
          discountAmount: rincian.discount,
          promoCode: data.promo?.code,
        );

    return hasil.fold(
      onOk: (sub) {
        debugPrint('KAMELSCAN_BAYAR tagihan dibuat · ${sub.id} · ${sub.amount}');
        state = AsyncData(data.copyWith(pending: sub));
        return (sub, null);
      },
      onErr: (failure) {
        debugPrint('KAMELSCAN_BAYAR tagihan GAGAL · $failure');
        return (null, failure);
      },
    );
  }
}
