import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/tier_config.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/promo.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'admin_settings_view_model.dart';

/// Nama paket yang dapat dibaca manusia.
///
/// 🔴 Ditulis SEKALI di sini dan memakai `switch` atas [TierPlan], bukan
/// rangkaian `== TierPlan.pro ? ... : ...` yang tersebar. Bentuk terakhir itu
/// selalu berakhir sama: paket ketiga jatuh ke cabang `else` dan tampil dengan
/// nama paket lain. Di halaman ini ia sempat membuat promo Bisnis tertulis
/// "Standar" — dan `switch` atas enum membuat kompilator menolak diam saat
/// paket keempat suatu hari ditambahkan.
String namaPaket(AppL10n t, TierPlan plan) => switch (plan) {
  TierPlan.standar => t.tierStandar,
  TierPlan.pro => t.tierPro,
  TierPlan.bisnis => t.tierBisnis,
};

/// Pengaturan promo (Bab 11.4).
///
/// 🔴 Kode di halaman ini memotong uang yang masuk. Sebuah promo `fixed`
/// senilai Rp 100.000 pada paket Standar seharga Rp 99.000 menghasilkan
/// tagihan nol — dijepit `Promo.discountFor` supaya tidak menjadi negatif,
/// tetapi tetap berarti paket yang dibagikan gratis. Layar ini karena itu
/// menampilkan **contoh perhitungannya** pada kedua paket sebelum disimpan.
///
/// ⚠️ Yang benar-benar menagih adalah Admin saat memverifikasi pembayaran
/// (Bab 12.2). Promo di sini hanya menentukan angka yang dilihat pelanggan
/// sebelum ia menekan Bayar.
class AdminPromosPage extends ConsumerStatefulWidget {
  const AdminPromosPage({super.key});

  @override
  ConsumerState<AdminPromosPage> createState() => _AdminPromosPageState();
}

class _AdminPromosPageState extends ConsumerState<AdminPromosPage> {
  /// Membuka formulir promo lalu menyimpannya.
  ///
  /// 🔴 Metode State, bukan closure di dalam `build`. `context` milik `build`
  /// dianggap analyzer tidak berhubungan dengan `mounted` milik State — dan ia
  /// benar: keduanya memang dapat berbeda umur, sehingga penjagaan `mounted`
  /// di sana tidak menjamin apa pun.
  Future<void> _sunting({Promo? awal}) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showDialog<Promo>(
      context: context,
      builder: (d) => _DialogPromo(awal: awal),
    );
    if (hasil == null || !mounted) return;

    final gagal = await ref
        .read(adminPromosViewModelProvider.notifier)
        .upsert(hasil);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminSettingsSaved : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(adminPromosViewModelProvider);
    final vm = ref.read(adminPromosViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminPromosTitle),
        actions: [
          IconButton(
            onPressed: vm.refresh,
            tooltip: t.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sunting,
        icon: const Icon(Icons.add),
        label: Text(t.adminPromosAdd),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 4, itemHeight: 110),
        error: (error, _) => AppErrorView(failure: error, onRetry: vm.refresh),
        data: (daftar) => daftar.isEmpty
            ? AppEmptyState(
                title: t.adminPromosEmptyTitle,
                message: t.adminPromosEmptyBody,
                icon: Icons.local_offer_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: daftar.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _KartuPromo(
                  promo: daftar[i],
                  onEdit: () => _sunting(awal: daftar[i]),
                ),
              ),
      ),
    );
  }
}

class _KartuPromo extends ConsumerStatefulWidget {
  const _KartuPromo({required this.promo, required this.onEdit});

  final Promo promo;
  final VoidCallback onEdit;

  @override
  ConsumerState<_KartuPromo> createState() => _KartuPromoState();
}

class _KartuPromoState extends ConsumerState<_KartuPromo> {
  Promo get promo => widget.promo;

  /// Menonaktifkan lebih dulu, menghapus hanya bila memang belum pernah
  /// dipakai.
  ///
  /// 🔴 Baris `subscriptions` yang lama menyimpan `promo_code` sebagai teks
  /// biasa, jadi menghapus kodenya tidak merusak apa pun secara teknis —
  /// tetapi menghilangkan satu-satunya keterangan tentang potongan yang pernah
  /// diberikan. Kode yang sudah terpakai karena itu diperingatkan lebih tegas.
  Future<void> _hapus() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final terpakai = promo.usedCount > 0;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.adminPromosDeleteTitle(promo.code)),
        content: Text(
          terpakai
              ? t.adminPromosDeleteUsed(Formatters.number(promo.usedCount))
              : t.adminPromosDeleteBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(d).colorScheme.error,
            ),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final gagal = await ref
        .read(adminPromosViewModelProvider.notifier)
        .delete(promo.code);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          gagal == null ? t.adminPromosDeleted : context.failureMessage(gagal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final vm = ref.read(adminPromosViewModelProvider.notifier);

    final kedaluwarsa = promo.validUntil.isBefore(DateTime.now());
    final pudar = !promo.isActive || kedaluwarsa || promo.isUsedUp;

    return Card(
      margin: EdgeInsets.zero,
      child: Opacity(
        opacity: pudar ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      promo.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Monospace: kode promo dibacakan lewat telepon dan
                      // diketik ulang pelanggan. Pada huruf biasa `0`/`O`
                      // nyaris identik.
                      style: AppTextStyles.resiInline.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: promo.isActive,
                    onChanged: (v) => vm.setActive(promo, v),
                  ),
                  IconButton(
                    onPressed: widget.onEdit,
                    tooltip: t.commonEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    onPressed: _hapus,
                    tooltip: t.commonDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colors.danger,
                    ),
                  ),
                ],
              ),

              Text(
                promo.isPercent
                    ? t.adminPromosValuePercent(
                        Formatters.number(promo.discountValue),
                      )
                    : t.adminPromosValueFixed(
                        Formatters.currency(promo.discountValue),
                      ),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                t.adminPromosValidUntil(Formatters.date(promo.validUntil)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kedaluwarsa ? colors.danger : scheme.onSurfaceVariant,
                ),
              ),
              Text(
                promo.maxUses == null
                    ? t.adminPromosUsedUnlimited(
                        Formatters.number(promo.usedCount),
                      )
                    : t.adminPromosUsedOf(
                        Formatters.number(promo.usedCount),
                        Formatters.number(promo.maxUses!),
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: promo.isUsedUp
                      ? colors.warning
                      : scheme.onSurfaceVariant,
                ),
              ),
              Text(
                promo.appliesTo == null
                    ? t.adminPromosAllPlans
                    : t.adminPromosOnePlan(namaPaket(t, promo.appliesTo!)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulir satu kode promo.
class _DialogPromo extends ConsumerStatefulWidget {
  const _DialogPromo({this.awal});

  final Promo? awal;

  @override
  ConsumerState<_DialogPromo> createState() => _DialogPromoState();
}

class _DialogPromoState extends ConsumerState<_DialogPromo> {
  /// Harga yang sedang berlaku, untuk contoh perhitungan.
  ///
  /// ⚠️ Jatuh ke `TierCatalog.fallback` bila sesi belum termuat. Nilai
  /// cadangan itu sama dengan seed `platform_settings`, jadi contohnya tetap
  /// masuk akal — tetapi Admin yang sudah mengubah harga akan melihat harga
  /// lama sekejap sampai sesinya siap.
  TierCatalog get _katalog =>
      ref.watch(sessionProvider).value?.tierCatalog ?? TierCatalog.fallback;

  late final TextEditingController _kode = TextEditingController(
    text: widget.awal?.code ?? '',
  );
  late final TextEditingController _nilai = TextEditingController(
    text: widget.awal == null ? '' : '${widget.awal!.discountValue.toInt()}',
  );
  late final TextEditingController _maks = TextEditingController(
    text: widget.awal?.maxUses == null ? '' : '${widget.awal!.maxUses}',
  );
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.awal?.description ?? '',
  );

  late bool _persen = widget.awal?.isPercent ?? true;
  late TierPlan? _paket = widget.awal?.appliesTo;
  late DateTime _sampai =
      widget.awal?.validUntil ?? DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _kode.dispose();
    _nilai.dispose();
    _maks.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  num get _angka => num.tryParse(_nilai.text.trim()) ?? 0;

  bool get _lengkap => _kode.text.trim().isNotEmpty && _angka > 0;

  Future<void> _pilihTanggal() async {
    final kini = DateTime.now();
    final hasil = await showDatePicker(
      context: context,
      initialDate: _sampai.isAfter(kini) ? _sampai : kini,
      firstDate: kini,
      lastDate: DateTime(kini.year + 5),
    );
    if (hasil == null || !mounted) return;
    setState(() => _sampai = hasil);
  }

  /// Contoh potongan pada kedua paket dengan aturan yang sedang diisi.
  ///
  /// 🔴 Memakai `Promo.discountFor` yang sama persis dengan yang dipakai
  /// halaman pelanggan — bukan hitungan kedua yang ditulis di sini. Dua tempat
  /// menghitung potongan yang sama pasti berselisih pada perubahan pertama
  /// yang hanya menyentuh salah satunya.
  String _contoh(BuildContext context, TierPlan plan, num harga) {
    final t = context.l10n;
    final calon = Promo(
      code: 'contoh',
      discountType: _persen ? 'percent' : 'fixed',
      discountValue: _angka,
      validUntil: _sampai,
      appliesTo: _paket,
    );
    final potong = calon.discountFor(harga);
    return t.adminPromosPreviewLine(
      namaPaket(t, plan),
      Formatters.currency(potong),
      Formatters.currency(harga - potong),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.awal == null ? t.adminPromosAdd : t.adminPromosEdit),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _kode,
                autofocus: widget.awal == null,
                // Kode diubah menjadi huruf besar saat disimpan; pelanggan
                // mengetiknya bagaimanapun juga, dan pencocokan di server
                // membandingkan teks apa adanya.
                textCapitalization: TextCapitalization.characters,
                enabled: widget.awal == null,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t.adminPromosCode,
                  // 🔴 Kode adalah kunci utama tabelnya. Mengubahnya pada
                  // promo yang sudah ada akan membuat baris BARU, bukan
                  // mengganti nama — dan yang lama tetap hidup.
                  helperText: widget.awal == null
                      ? t.adminPromosCodeHelp
                      : t.adminPromosCodeLocked,
                  helperMaxLines: 2,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  ChoiceChip(
                    label: Text(t.adminPromosPercent),
                    selected: _persen,
                    onSelected: (_) => setState(() => _persen = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(t.adminPromosFixed),
                    selected: !_persen,
                    onSelected: (_) => setState(() => _persen = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nilai,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'\d*')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _persen
                      ? t.adminPromosValueLabelPercent
                      : t.adminPromosValueLabelFixed,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<TierPlan?>(
                initialValue: _paket,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t.adminPromosAppliesTo,
                  isDense: true,
                ),
                // 🔴 Dibangun dari `TierPlan.values`, BUKAN disebut satu
                // per satu. Bentuk lamanya hanya memuat Standar dan Pro,
                // sehingga promo untuk paket Bisnis TIDAK DAPAT DIBUAT sama
                // sekali — dan tidak ada galat apa pun yang menandainya.
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(t.adminPromosAllPlans),
                  ),
                  for (final plan in TierPlan.values)
                    DropdownMenuItem(
                      value: plan,
                      child: Text(namaPaket(t, plan)),
                    ),
                ],
                onChanged: (v) => setState(() => _paket = v),
              ),
              const SizedBox(height: 14),

              InputDecorator(
                decoration: InputDecoration(
                  labelText: t.adminPromosValidUntilLabel,
                  isDense: true,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(Formatters.date(_sampai))),
                    TextButton.icon(
                      onPressed: _pilihTanggal,
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(t.commonEdit),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _maks,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'\d*')),
                ],
                decoration: InputDecoration(
                  labelText: t.adminPromosMaxUses,
                  helperText: t.adminPromosMaxUsesHelp,
                  helperMaxLines: 2,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keterangan,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: t.adminPromosDescription,
                  isDense: true,
                ),
              ),

              // 🔴 Contoh perhitungan. Promo `fixed` yang lebih besar daripada
              // harga paket menghasilkan tagihan nol — dijepit supaya tidak
              // negatif, tetapi tetap berarti paket dibagikan gratis. Angka
              // ini membuat hal itu terlihat SEBELUM disimpan.
              if (_angka > 0) ...[
                const SizedBox(height: 6),
                Text(
                  t.adminPromosPreviewTitle,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                // 🔴 Harga dibaca dari katalog, BUKAN ditulis di sini.
                //
                // Bentuk lamanya menanam 99.000 dan 249.000 — angka yang sudah
                // TIDAK BERLAKU sejak migrasi 39 menetapkan 149.000, 299.000,
                // dan 1.490.000. Contoh perhitungan yang memakai harga salah
                // lebih buruk daripada tidak ada contoh sama sekali: ia
                // meyakinkan Admin bahwa potongannya aman padahal belum tentu.
                for (final tier in _katalog.semua)
                  if (_paket == null || _paket == tier.plan)
                    Text(
                      _contoh(context, tier.plan, tier.price),
                      style: theme.textTheme.bodySmall,
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _lengkap
              ? () => Navigator.pop(
                  context,
                  Promo(
                    code: _kode.text.trim().toUpperCase(),
                    discountType: _persen ? 'percent' : 'fixed',
                    discountValue: _angka,
                    validUntil: _sampai,
                    validFrom: widget.awal?.validFrom,
                    appliesTo: _paket,
                    maxUses: int.tryParse(_maks.text.trim()),
                    description: _keterangan.text.trim().isEmpty
                        ? null
                        : _keterangan.text.trim(),
                    isActive: widget.awal?.isActive ?? true,
                  ),
                )
              : null,
          child: Text(t.commonSave),
        ),
      ],
    );
  }
}
