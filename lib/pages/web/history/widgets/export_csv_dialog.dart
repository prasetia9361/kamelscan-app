import 'package:flutter/material.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/history_item.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Nama kolom di judul berkas.
String labelKolomCsv(AppL10n t, CsvColumn kolom) => switch (kolom) {
  CsvColumn.tanggal => t.csvColTanggal,
  CsvColumn.resi => t.csvColResi,
  CsvColumn.jenis => t.csvColJenis,
  CsvColumn.status => t.csvColStatus,
  CsvColumn.toko => t.csvColToko,
  CsvColumn.marketplace => t.csvColMarketplace,
  CsvColumn.perekam => t.csvColPerekam,
  CsvColumn.durasi => t.csvColDurasi,
  CsvColumn.ukuran => t.csvColUkuran,
  CsvColumn.kedaluwarsa => t.csvColKedaluwarsa,
};

/// Isi satu sel.
///
/// ⚠️ Durasi ditulis sebagai **angka detik telanjang**, bukan `00:28`. Yang
/// membuka berkas ini akan menjumlah dan merata-ratakannya; `00:28` dibaca
/// Excel sebagai teks dan tidak dapat dihitung sama sekali. Ukuran berkas
/// sebaliknya ditulis manusiawi — tidak ada yang menjumlahkan byte.
String nilaiKolomCsv(AppL10n t, CsvColumn kolom, HistoryItem item) {
  final v = item.video;
  return switch (kolom) {
    CsvColumn.tanggal => CsvExport.tanggal(v.scanDate),
    CsvColumn.resi => v.resiCode,
    CsvColumn.jenis => v.type == VideoType.packing
        ? t.videoTypePacking
        : t.videoTypeReturn,
    CsvColumn.status => switch (v.status) {
      VideoStatus.uploaded => t.videoStatusUploaded,
      VideoStatus.uploading => t.videoStatusUploading,
      VideoStatus.pendingUpload => t.videoStatusPendingUpload,
      VideoStatus.failed => t.videoStatusFailed,
      VideoStatus.expired => t.videoStatusExpired,
      VideoStatus.deleted => t.videoStatusDeleted,
    },
    CsvColumn.toko => item.shopName ?? '',
    CsvColumn.marketplace => item.marketName ?? '',
    CsvColumn.perekam => item.recorderName ?? '',
    CsvColumn.durasi => v.durationSeconds?.toString() ?? '',
    CsvColumn.ukuran => v.fileSizeBytes == null
        ? ''
        : Formatters.fileSize(v.fileSizeBytes!),
    CsvColumn.kedaluwarsa => CsvExport.tanggal(v.expiresAt),
  };
}

/// Hasil dialog: kolom yang dipilih Owner.
typedef PilihanEkspor = List<CsvColumn>;

/// Dialog pemilih kolom sebelum berkas diunduh (Bab 10).
///
/// 🔴 Jumlah barisnya dihitung dan ditampilkan **sebelum** tombol Unduh
/// ditekan. Ekspor adalah satu-satunya tempat di aplikasi ini yang hasilnya
/// dibawa keluar dan dibaca tanpa aplikasinya — kalau isinya kurang, tidak ada
/// yang akan tahu. Menyebut angkanya di muka membuat "kok cuma segini?"
/// terjadi di sini, bukan seminggu kemudian di depan orang lain.
class ExportCsvDialog extends StatefulWidget {
  const ExportCsvDialog({
    required this.total,
    required this.maks,
    super.key,
  });

  /// Jumlah baris yang cocok dengan saringan, seluruhnya.
  final int total;

  /// Batas baris yang benar-benar masuk berkas.
  final int maks;

  @override
  State<ExportCsvDialog> createState() => _ExportCsvDialogState();
}

class _ExportCsvDialogState extends State<ExportCsvDialog> {
  /// Kolom yang tercentang saat dialog dibuka.
  ///
  /// Sengaja tidak semuanya: yang dicari orang dari arsip bukti packing adalah
  /// tanggal, resi, dan siapa yang merekam. Kolom lain tersedia bagi yang
  /// membutuhkannya, tanpa memaksa semua orang membersihkannya lebih dulu.
  late final Set<CsvColumn> _dipilih = {
    CsvColumn.tanggal,
    CsvColumn.resi,
    CsvColumn.jenis,
    CsvColumn.status,
    CsvColumn.toko,
    CsvColumn.perekam,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final kosong = widget.total == 0;
    final terpotong = widget.total > widget.maks;

    return AlertDialog(
      title: Text(t.exportTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kosong)
                Text(t.exportEmpty, style: theme.textTheme.bodyMedium)
              else ...[
                Text(t.exportRows(widget.total)),
                if (terpotong) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.exportTruncated(widget.total, widget.maks),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.exportChooseColumns,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _dipilih.addAll(CsvColumn.values),
                      ),
                      child: Text(t.exportSelectAll),
                    ),
                    TextButton(
                      onPressed: () => setState(_dipilih.clear),
                      child: Text(t.exportSelectNone),
                    ),
                  ],
                ),
                for (final kolom in CsvColumn.values)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _dipilih.contains(kolom),
                    title: Text(labelKolomCsv(t, kolom)),
                    onChanged: (pilih) => setState(() {
                      if (pilih ?? false) {
                        _dipilih.add(kolom);
                      } else {
                        _dipilih.remove(kolom);
                      }
                    }),
                  ),
                if (_dipilih.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.exportNeedColumn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
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
        FilledButton.icon(
          // Kosong atau tanpa kolom = tidak ada berkas yang masuk akal untuk
          // dibuat. Tombol yang menghasilkan berkas berisi judul saja lebih
          // membingungkan daripada tombol yang mati.
          onPressed: kosong || _dipilih.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  // Urut mengikuti enum, bukan urutan pencentangan — supaya
                  // dua ekspor dengan pilihan sama selalu menghasilkan susunan
                  // kolom yang sama.
                  CsvColumn.values.where(_dipilih.contains).toList(),
                ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(t.exportDownload),
        ),
      ],
    );
  }
}
