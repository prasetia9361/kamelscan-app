import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema terang & gelap. Sumber: `palet_warna_dan_tipografi.md` §4.3.
///
/// Warna tidak diturunkan dari `ColorScheme.fromSeed` — setiap nilai ditetapkan
/// eksplisit karena rasio kontrasnya sudah dihitung satu per satu (§1, §2).
/// Membiarkan Material menghasilkan turunannya sendiri akan merusak jaminan itu.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        scheme: const ColorScheme.light(
          primary: Color(0xFF0D5EA6),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFD6E6F7),
          onPrimaryContainer: Color(0xFF06304F),
          secondary: Color(0xFF9A5B00),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFFBEBD2),
          onSecondaryContainer: Color(0xFF4A2B00),
          error: Color(0xFFC62828),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF101828),
          surfaceContainer: Color(0xFFF2F5F9),
          surfaceContainerHigh: Color(0xFFE7ECF3),
          onSurfaceVariant: Color(0xFF4A5567),
          outline: Color(0xFFC7CFDA),
          outlineVariant: Color(0xFFE3E8EF),
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
          // ⚠️ Sengaja bukan hitam murni: pada layar OLED, #000000
          // menimbulkan smearing saat menggulir dan terlalu keras dipandang
          // lama (§2).
          surface: Color(0xFF0F141A),
          onSurface: Color(0xFFE6EDF5),
          surfaceContainer: Color(0xFF1A222C),
          surfaceContainerHigh: Color(0xFF232D39),
          onSurfaceVariant: Color(0xFFA5B3C4),
          outline: Color(0xFF3A4757),
          outlineVariant: Color(0xFF2A3542),
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

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
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

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        height: 64,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
      ),

      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
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
