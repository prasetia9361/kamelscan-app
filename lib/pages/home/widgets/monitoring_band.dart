import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_text_styles_display.dart';

/// Pantauan — pengganti `_MonitoringRow` + `_StatCard`
/// (`PANDUAN_TAMPILAN.md` Langkah 4).
///
/// 🔴 Kenapa tiga kartu lama dibongkar:
///
/// Tiga kartu bergaris tepi pada lebar sepertiga layar memaksa angkanya turun
/// ke 30 sp dan labelnya ke 12 sp, lalu masih menyisakan tiga garis tepi abu
/// yang harus dilihat lebih dulu sebelum sampai ke angkanya.
///
/// Susunan sekarang: **dua petak berdampingan** (packing biru, return ungu),
/// lalu saldo token satu petak penuh lebar di bawahnya. Isinya **rata kiri** —
/// mata membaca angka dari tepi yang sama, dan label di kiri atas menerangkan
/// angka di bawahnya tanpa perlu dicari.
///
/// Ketiga angka tetap terlihat sekaligus dalam satu layar tanpa gulir — syarat
/// Bab 9.2 dan keputusan Product Owner 18 Agustus 2026.
///
/// 🔴 **Latarnya warna container penuh, bukan warna penuh yang diberi alpha.**
/// Versi pertama memakai `color.withValues(alpha: 0.12)`. Di mode gelap, 12%
/// dari `#8FC3F0` di atas latar `#0F141A` praktis tidak terlihat — Product
/// Owner melaporkan petaknya hilang dan hanya angkanya mengambang di ruang
/// hitam. Pasangan container/on-container sudah dihitung kontrasnya untuk
/// kedua tema (§1.3 & §2 palet); warna ber-alpha tidak menjamin apa pun.
///
/// ⚠️ Seluruh teks datang dari pemanggil, bukan ditulis di sini. Aplikasi ini
/// dwibahasa (Bab 9.11) dan widget ini sengaja tidak mengenal `context.l10n`
/// supaya tetap dapat diuji tanpa `MaterialApp` berlokalisasi.
class MonitoringBand extends StatelessWidget {
  const MonitoringBand({
    super.key,
    required this.packingLabel,
    required this.packingCount,
    required this.packingColor,
    required this.packingBackground,
    required this.returnLabel,
    required this.returnCount,
    required this.returnColor,
    required this.returnBackground,
    required this.tokenLabel,
    required this.tokenValue,
    required this.tokenColor,
    required this.tokenBackground,
    required this.numberFormatter,
    this.tokenTotal,
    this.tokenRatio,
    this.tokenMeta,
    this.onTapPacking,
    this.onTapReturn,
    this.onTapToken,
  });

  final String packingLabel;
  final int packingCount;

  /// Warna label & angka. Pasangannya [packingBackground].
  final Color packingColor;
  final Color packingBackground;

  final String returnLabel;
  final int returnCount;
  final Color returnColor;
  final Color returnBackground;

  final String tokenLabel;
  final int tokenValue;
  final Color tokenColor;
  final Color tokenBackground;
  final int? tokenTotal;

  /// 0..1 sisa kuota. Sumbernya tetap aturan Bab 7.3, tidak dihitung di sini.
  final double? tokenRatio;

  /// Baris meta kanan, mis. "SISA 73% · 12 SEP". Kosong saat uji coba, karena
  /// uji coba dibatasi jumlah video dan bukan waktu (Bab 7.5).
  final String? tokenMeta;

  final VoidCallback? onTapPacking;
  final VoidCallback? onTapReturn;
  final VoidCallback? onTapToken;

  /// Diteruskan dari `Formatters.number` supaya pemisah ribuan tetap satu
  /// sumber.
  final String Function(int) numberFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔴 `IntrinsicHeight`, bukan `CrossAxisAlignment.stretch` telanjang.
        //
        // Widget ini hidup sebagai anak `ListView`, jadi tingginya tidak
        // terbatas. `stretch` pada Row yang tingginya tidak terbatas meminta
        // anaknya setinggi tak hingga — "BoxConstraints forces an infinite
        // height" — dan seluruh sisa halaman berhenti tergambar, bukan hanya
        // baris ini. Versi lama aman karena dibungkus `SizedBox(height: 138)`;
        // begitu tinggi tetap itu dibuang, pembatasnya harus diganti, bukan
        // dihapus.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Cell(
                  icon: Icons.inventory_2_outlined,
                  label: packingLabel,
                  value: numberFormatter(packingCount),
                  color: packingColor,
                  background: packingBackground,
                  onTap: onTapPacking,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Cell(
                  icon: Icons.move_to_inbox_outlined,
                  label: returnLabel,
                  value: numberFormatter(returnCount),
                  color: returnColor,
                  background: returnBackground,
                  onTap: onTapReturn,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _TokenTile(
          label: tokenLabel,
          value: numberFormatter(tokenValue),
          total: tokenTotal == null ? null : numberFormatter(tokenTotal!),
          ratio: tokenRatio,
          meta: tokenMeta,
          color: tokenColor,
          background: tokenBackground,
          onTap: onTapToken,
        ),
      ],
    );
  }
}

/// Baris label: ikon + teks kicker. Dipakai kedua bentuk petak supaya
/// keduanya benar-benar sama, bukan mirip.
class _Kicker extends StatelessWidget {
  const _Kicker({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDisplayStyles.kicker.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.6,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Petak token: satu bidang penuh lebar. Ia memuat empat hal (label, angka,
/// total, palang), bukan satu angka.
class _TokenTile extends StatelessWidget {
  const _TokenTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.total,
    this.ratio,
    this.meta,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
  final String? total;
  final double? ratio;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Kicker(
                      icon: Icons.confirmation_number_outlined,
                      label: label,
                      color: color,
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      meta!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDisplayStyles.metaMono.copyWith(color: color),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: AppDisplayStyles.statHero
                            .copyWith(fontSize: 34, color: color)),
                    if (total != null) ...[
                      const SizedBox(width: 7),
                      Text('/ $total',
                          style: AppTextStyles.resiInline.copyWith(
                            fontSize: 15,
                            color: color.withValues(alpha: 0.7),
                          )),
                    ],
                  ],
                ),
              ),
              if (ratio != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  backgroundColor: color.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Petak angka. Isi **rata kiri**, sejajar dengan petak token di bawahnya.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Kicker(icon: icon, label: label, color: color),
              const SizedBox(height: 7),
              // Sepertiga layar itu sempit, dan tenant sibuk bisa menembus
              // empat digit. Angkanya dikecilkan, bukan dipotong — angka bukti
              // yang terpotong lebih buruk daripada angka yang kecil.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: AppDisplayStyles.statHero
                      .copyWith(fontSize: 34, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
