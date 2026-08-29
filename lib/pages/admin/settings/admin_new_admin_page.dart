import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/failure_messages.dart';

/// Panduan membuat akun Admin baru (Bab 2.2).
///
/// 🔴 Halaman ini **tidak membuat akun apa pun.** Ia hanya menyusun perintah
/// SQL yang siap disalin, dan itu keputusan yang disengaja.
///
/// Bab 2.2 menuliskannya sebagai aturan: *"Admin dibuat manual di database,
/// tidak ada jalur registrasi menjadi admin dari aplikasi."* Alasannya
/// keamanan berlapis — membuat admin menuntut kredensial **Supabase
/// Dashboard**, yang sama sekali terpisah dari login aplikasi. Bila suatu hari
/// satu akun admin dibobol, penyerangnya tidak dapat mencetak admin baru untuk
/// bertahan di dalam.
///
/// Yang diselesaikan halaman ini adalah dua jebakan nyata yang sudah tercatat
/// di `DEVIASI_LIBRARY.md` **P.3**, dan keduanya gagal tanpa pesan yang
/// menjelaskan sebabnya:
///
///   1. **Alias Gmail ditolak.** `normalize_email` membuang titik dan segala
///      yang setelah `+` untuk domain gmail, dan `email_normalized` unik. Jadi
///      `nama+admin@gmail.com` dianggap **sama persis** dengan
///      `nama@gmail.com` — aturan anti-penyalahgunaan Bab 7.5 mengenai
///      pemiliknya sendiri.
///   2. **Peran dibawa di dalam JWT.** Sesudah `role` diubah, akunnya wajib
///      keluar lalu masuk lagi. Sebelum itu aplikasi masih menganggapnya peran
///      lama, dan gejalanya terlihat seperti perintah SQL-nya gagal.
///
/// 🔴 Perintah **periksa dulu, baru ubah** — dua blok terpisah, bukan satu.
/// `update ... where email = ...` yang salah ketik satu huruf tidak menyentuh
/// baris mana pun dan melaporkan sukses; yang salah ketik dengan cara lain
/// dapat menaikkan orang yang keliru menjadi admin platform. Blok pertama
/// memaksa Admin melihat nama orangnya sebelum menekan apa pun.
class AdminNewAdminPage extends StatefulWidget {
  const AdminNewAdminPage({super.key});

  @override
  State<AdminNewAdminPage> createState() => _AdminNewAdminPageState();
}

class _AdminNewAdminPageState extends State<AdminNewAdminPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _isi => _email.text.trim();

  /// Cukup masuk akal untuk menyusun SQL. Bukan penjagaan — yang menolak
  /// email tidak sah adalah pendaftarannya sendiri, jauh sebelum halaman ini.
  bool get _siap => _isi.contains('@') && _isi.length > 4;

  /// 🔴 Dikutip dengan `''` ganda, bukan sekadar disisipkan.
  ///
  /// Nama email sah boleh memuat tanda kutip tunggal (`o'brien@contoh.com`),
  /// dan satu tanda kutip yang lolos akan memutus perintahnya di tengah. Ini
  /// perintah yang akan ditempel Product Owner ke SQL Editor produksi.
  String get _kutip => _isi.replaceAll("'", "''");

  String get _sqlPeriksa =>
      'select id, email, full_name, role, created_at\n'
      '  from public.users\n'
      " where email_normalized = public.normalize_email('$_kutip');";

  String get _sqlJadikan =>
      'update public.users\n'
      "   set role = 'admin'\n"
      " where email_normalized = public.normalize_email('$_kutip');";

  String get _sqlBatalkan =>
      'update public.users\n'
      "   set role = 'owner'\n"
      " where email_normalized = public.normalize_email('$_kutip');";

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text(t.adminNewAdminTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Kenapa halaman ini tidak punya tombol "Buat" — dikatakan lebih
          // dulu, supaya tidak terbaca sebagai fitur yang belum jadi.
          Card(
            margin: EdgeInsets.zero,
            color: colors.packingContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.adminNewAdminWhyTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.adminNewAdminWhyBody,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _Langkah(
            nomor: 1,
            judul: t.adminNewAdminStep1Title,
            isi: t.adminNewAdminStep1Body,
          ),
          const SizedBox(height: 8),

          // ⚠️ Jebakan alias Gmail. Ditaruh tepat di langkah pendaftaran,
          // bukan di bawah sebagai catatan kaki — di situlah orangnya akan
          // tergoda memakai nama+admin@gmail.com.
          Card(
            margin: EdgeInsets.zero,
            color: colors.warning.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.alternate_email, size: 20, color: colors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.adminNewAdminAliasWarning,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _Langkah(
            nomor: 2,
            judul: t.adminNewAdminStep2Title,
            isi: t.adminNewAdminStep2Body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t.adminNewAdminEmailLabel,
              hintText: 'nama@contoh.com',
              prefixIcon: const Icon(Icons.mail_outline),
              isDense: true,
            ),
          ),

          if (!_siap) ...[
            const SizedBox(height: 20),
            Text(
              t.adminNewAdminFillFirst,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            _Langkah(
              nomor: 3,
              judul: t.adminNewAdminStep3Title,
              isi: t.adminNewAdminStep3Body,
            ),
            const SizedBox(height: 10),
            _BlokSql(sql: _sqlPeriksa, label: t.adminNewAdminSqlCheck),

            const SizedBox(height: 24),
            _Langkah(
              nomor: 4,
              judul: t.adminNewAdminStep4Title,
              isi: t.adminNewAdminStep4Body,
            ),
            const SizedBox(height: 10),
            _BlokSql(sql: _sqlJadikan, label: t.adminNewAdminSqlPromote),

            const SizedBox(height: 24),
            _Langkah(
              nomor: 5,
              judul: t.adminNewAdminStep5Title,
              isi: t.adminNewAdminStep5Body,
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            Text(t.adminNewAdminUndoTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              t.adminNewAdminUndoBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _BlokSql(sql: _sqlBatalkan, label: t.adminNewAdminSqlDemote),
          ],

          const SizedBox(height: 28),
          // 🔴 Peringatan Bab 11: kredensial Dashboard tidak boleh dibagikan.
          // Halaman ini menyuruh Product Owner membukanya, jadi di sinilah
          // tempat peringatan itu paling perlu terbaca.
          Card(
            margin: EdgeInsets.zero,
            color: colors.danger.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 20, color: colors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.adminNewAdminDashboardWarning,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah({required this.nomor, required this.judul, required this.isi});

  final int nomor;
  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$nomor',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // `Expanded`, bukan lebar tetap — kalimat langkahnya panjang dan
        // halaman ini dibuka di lebar mana pun.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(judul, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                isi,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu blok perintah SQL beserta tombol salinnya.
///
/// 🔴 Memakai huruf monospace. Perintah ini ditempel ke SQL Editor produksi,
/// dan pada huruf biasa `0`/`O` serta `1`/`l` nyaris identik — Product Owner
/// membacanya untuk memastikan ia menempel yang benar.
class _BlokSql extends StatelessWidget {
  const _BlokSql({required this.sql, required this.label});

  final String sql;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final pesan = t.commonCopied;
                    await Clipboard.setData(ClipboardData(text: sql));
                    messenger.showSnackBar(SnackBar(content: Text(pesan)));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(t.commonCopy),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            // Digulir mendatar, bukan dipatahkan barisnya. Perintah SQL yang
            // terlipat di tempat acak sulit dibaca, dan yang membacanya sedang
            // memeriksa apakah perintahnya benar.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                sql,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
