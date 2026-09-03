import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema terang & gelap. Sumber: `palet_warna_dan_tipografi.md` §4.3, direvisi
/// mengikuti `PANDUAN_TAMPILAN.md` Langkah 1 (revisi tampilan, Agustus 2026).
///
/// Warna tidak diturunkan dari `ColorScheme.fromSeed` — setiap nilai ditetapkan
/// eksplisit karena rasio kontrasnya sudah dihitung satu per satu (§1, §2).
/// Membiarkan Material menghasilkan turunannya sendiri akan merusak jaminan itu.
///
/// Yang berubah pada revisi tampilan, dan hanya ini:
///
/// 1. **Latar halaman jadi netral hangat** (`#F6F4F1`) alih-alih abu-biru
///    `#F2F5F9`. Abu-biru itu warna bawaan Material dan itulah sumber utama
///    kesan "template". Netral hangat juga memasangkan biru dengan camel
///    (`secondary`) dengan lebih baik. Kontras teks TIDAK turun: `onSurface`
///    #101828 di atas #F6F4F1 = 16,9:1 (sebelumnya 17,0:1).
/// 2. **Kartu tidak lagi punya garis tepi.** Halaman disusun oleh garis rambut
///    + ruang kosong, bukan kotak. Garis tepi + latar berbeda + radius besar
///    adalah tiga penanda sekaligus untuk isi yang tidak diskret.
/// 3. **Chip jadi kapsul penuh** (`StadiumBorder`) — bentuk yang paling jauh
///    dari kotak, dan tetap terbaca pada label dua kata.
/// 4. **Bilah atas menyatu dengan halaman**: tidak ada dua permukaan berbeda
///    yang bertemu di garis yang tidak berarti apa pun.
/// 5. **Indikator pil di menu bawah dimatikan** — diganti garis 2 dp di atas
///    tab aktif oleh `KamelNavBar`.
///
/// `AppSizes` tidak disentuh — radius 12/16 tetap. Warna semantik, tipografi,
/// dan ukuran sentuh (§1–§3, §5) juga tidak disentuh.
///
/// ⚠️ **Nilai container mengikuti prototipe, bukan berkas kiriman desainer.**
/// Keputusan Product Owner 31 Agustus 2026. Berkas `app_theme.dart` yang
/// dikirim desainer memakai `primaryContainer` #E2ECF7 / #12354F, sedangkan
/// prototipe HTML-nya memakai #D6E6F7 / #123E63. Yang dipakai di sini adalah
/// nilai prototipe, karena itu yang sama persis dengan
/// [AppColors.packingContainer] — dua biru sorotan yang berbeda tipis akan
/// terlihat salah begitu keduanya bersebelahan, dan #D6E6F7 yang rasio
/// kontrasnya sudah tercatat di palet.
class AppTheme {
  const AppTheme._();

  /// Latar halaman terang — netral hangat, bukan abu-biru Material.
  static const Color _groundLight = Color(0xFFF6F4F1);
  static const Color _groundLightHigh = Color(0xFFEFEDE8);

  /// Garis rambut pemisah baris. Padanan hangat dari `#E3E8EF` lama.
  static const Color _hairLight = Color(0xFFDCD7CE);

  /// Garis tepi input & tombol. Padanan hangat dari `#C7CFDA` lama — sengaja
  /// lebih gelap dari garis rambut, karena kolom isian harus tetap terlihat
  /// batasnya di bawah lampu gudang.
  static const Color _outlineLight = Color(0xFFC9C3B8);

  /// ⚠️ Sengaja bukan hitam murni: pada layar OLED, #000000 menimbulkan
  /// smearing saat menggulir dan terlalu keras dipandang lama (§2).
  static const Color _groundDark = Color(0xFF0F141A);
  static const Color _surfaceDark = Color(0xFF161E26);
  static const Color _groundDarkHigh = Color(0xFF1F2932);
  static const Color _hairDark = Color(0xFF222C36);
  static const Color _outlineDark = Color(0xFF2E3A47);

  static ThemeData get light => _build(
        scheme: const ColorScheme.light(
          primary: Color(0xFF0D5EA6),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFD6E6F7),
          onPrimaryContainer: Color(0xFF06304F),
          secondary: Color(0xFF9A5B00),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFF7ECD9),
          onSecondaryContainer: Color(0xFF4A2B00),
          error: Color(0xFFC62828),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF101828),
          surfaceContainer: _groundLight,
          surfaceContainerHigh: _groundLightHigh,
          onSurfaceVariant: Color(0xFF4A5567),
          outline: _outlineLight,
          outlineVariant: _hairLight,
        ),
        appColors: AppColors.light,
      );

  static ThemeData get dark => _build(
        scheme: const ColorScheme.dark(
          primary: Color(0xFF8FC3F0),
          onPrimary: Color(0xFF06304F),
          primaryContainer: Color(0xFF123E63),
          onPrimaryContainer: Color(0xFFD6E6F7),
          secondary: Color(0xFFF0B454),
          onSecondary: Color(0xFF3A2200),
          secondaryContainer: Color(0xFF4A3208),
          onSecondaryContainer: Color(0xFFFBEBD2),
          error: Color(0xFFFF8A8A),
          onError: Color(0xFF4E1717),
          surface: _surfaceDark,
          onSurface: Color(0xFFE6EDF5),
          surfaceContainer: _groundDark,
          surfaceContainerHigh: _groundDarkHigh,
          onSurfaceVariant: Color(0xFFA5B3C4),
          outline: _outlineDark,
          outlineVariant: _hairDark,
        ),
        appColors: AppColors.dark,
      );

  static ThemeData _build({
    required ColorScheme scheme,
    required AppColors appColors,
  }) {
    final text = AppTextStyles.textTheme(scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainer,
      fontFamily: AppFonts.sans,
      textTheme: text,
      extensions: [appColors],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        // Bilah atas menyatu dengan halaman: tidak ada dua permukaan berbeda
        // yang bertemu di garis yang tidak berarti apa pun.
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),

      // Tinggi 52 dp, di atas minimum 48 dp. Gudang, sarung tangan (§5).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.touchComfort),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.touchComfort),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
        ),
      ),

      // 🔴 Kartu tanpa garis tepi. Garis tepi + latar berbeda + radius besar
      // adalah tiga penanda sekaligus, dan tiga-tiganya menuntut perhatian
      // yang seharusnya jatuh ke angkanya.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: scheme.surface,
        // Pil dimatikan; penanda tab aktif dipegang KamelNavBar.
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        labelType: NavigationRailLabelType.all,
      ),

      // Chip & badge jadi kapsul penuh — bentuk yang paling jauh dari kotak,
      // dan tetap terbaca pada label dua kata.
      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusLarge),
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.spaceMd),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
