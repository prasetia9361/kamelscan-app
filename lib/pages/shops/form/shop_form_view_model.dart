import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/shop.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/app_failure.dart';
import '../../recording/setup/recording_setup_view_model.dart';
import '../shops_view_model.dart';

part 'shop_form_view_model.g.dart';

/// Isi formulir toko (Bab 9.5).
class ShopFormData {
  const ShopFormData({
    required this.marketName,
    required this.shopName,
    required this.isActive,
    this.saving = false,
  });

  final String marketName;
  final String shopName;
  final bool isActive;
  final bool saving;

  bool get canSave => shopName.trim().isNotEmpty && !saving;

  ShopFormData copyWith({
    String? marketName,
    String? shopName,
    bool? isActive,
    bool? saving,
  }) =>
      ShopFormData(
        marketName: marketName ?? this.marketName,
        shopName: shopName ?? this.shopName,
        isActive: isActive ?? this.isActive,
        saving: saving ?? this.saving,
      );
}

/// Tambah atau ubah toko (Bab 9.5 — Owner saja).
///
/// [shopId] kosong berarti menambah baru.
@riverpod
class ShopFormViewModel extends _$ShopFormViewModel {
  @override
  Future<ShopFormData> build(String shopId) async {
    final session = ref.watch(sessionProvider).value;
    if (session == null) throw AppFailure.sessionExpired;

    if (shopId.isEmpty) {
      return const ShopFormData(
        marketName: MarketNames.shopee,
        shopName: '',
        isActive: true,
      );
    }

    final shop =
        (await ref.read(shopRepositoryProvider).fetchShop(shopId)).unwrap();

    return ShopFormData(
      marketName: shop.marketName,
      shopName: shop.shopName,
      isActive: shop.isActive,
    );
  }

  void setMarket(String value) => _update((s) => s.copyWith(marketName: value));
  void setName(String value) => _update((s) => s.copyWith(shopName: value));
  void setActive(bool value) => _update((s) => s.copyWith(isActive: value));

  /// Simpan. Mengembalikan `null` bila berhasil.
  ///
  /// ⚠️ `23505` di sini bukan kesalahan tak dikenal: `uq_shop_per_tenant`
  /// melarang kombinasi marketplace + nama toko yang sama dalam satu tenant.
  /// Owner yang mengetik nama yang sudah ada berhak mendapat kalimat yang
  /// menjelaskan itu, bukan "terjadi kesalahan".
  Future<AppFailure?> save() async {
    final current = state.value;
    final session = ref.read(sessionProvider).value;
    if (current == null || session == null || !current.canSave) return null;

    state = AsyncData(current.copyWith(saving: true));

    final repo = ref.read(shopRepositoryProvider);
    final nama = current.shopName.trim();

    final result = shopId.isEmpty
        ? await repo.createShop(
            tenantId: session.tenantId,
            marketName: current.marketName,
            shopName: nama,
          )
        : await repo.updateShop(
            shopId,
            marketName: current.marketName,
            shopName: nama,
            isActive: current.isActive,
          );

    state = AsyncData(current.copyWith(saving: false));

    final failure = result.failureOrNull;
    if (failure != null) {
      debugPrint('KAMELSCAN_TOKO simpan GAGAL · $failure');
      return failure;
    }

    // 🔴 Yang di-invalidate adalah **ViewModel yang menyimpan daftarnya**,
    // bukan repository-nya.
    //
    // Sebelumnya di sini tertulis `ref.invalidate(shopRepositoryProvider)`, dan
    // itu tidak melakukan apa-apa yang terlihat: repository tidak menyimpan
    // state (Bab 3.1 poin 3), dan `ShopsViewModel` membacanya dengan
    // `ref.read` — jadi ia tidak pernah tahu ada yang berubah. Akibatnya Owner
    // harus menarik daftarnya ke bawah setiap kali menambah atau mengubah toko.
    // Dilaporkan Product Owner 19 Agustus 2026.
    ref.invalidate(shopsViewModelProvider);

    // Layar setup perekaman membaca daftar toko yang sama. Tanpa ini, toko yang
    // baru ditambahkan belum muncul bila packer langsung menekan Rekam —
    // dan pada pelanggan baru, itu persis urutan yang paling mungkin terjadi.
    ref.invalidate(recordingSetupViewModelProvider);
    return null;
  }

  void _update(ShopFormData Function(ShopFormData) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(change(current));
  }
}
