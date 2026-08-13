import 'package:flutter/material.dart';

/// Warna semantik di luar `ColorScheme` Material.
/// Diakses lewat `Theme.of(context).extension<AppColors>()!`.
///
/// Sumber: `palet_warna_dan_tipografi.md` §4.1.
///
/// 🔴 §6 — jangan pernah menulis `Color(0xFF...)` langsung di widget dan jangan
/// memakai `Colors.grey`/`Colors.blue` bawaan Flutter. Mode gelap akan rusak
/// dan kontrasnya tidak terjamin.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.packing,
    required this.packingContainer,
    required this.onPackingContainer,
    required this.returnColor,
    required this.returnContainer,
    required this.onReturnContainer,
    required this.recording,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Color packing;
  final Color packingContainer;
  final Color onPackingContainer;
  final Color returnColor;
  final Color returnContainer;
  final Color onReturnContainer;
  final Color recording;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;

  /// Dasar & sorotan shimmer skeleton (Bab 9.10 — skeleton, bukan spinner).
  final Color shimmerBase;
  final Color shimmerHighlight;

  static const light = AppColors(
    packing: Color(0xFF0D5EA6),
    packingContainer: Color(0xFFD6E6F7),
    onPackingContainer: Color(0xFF06304F),
    returnColor: Color(0xFF5B2C87),
    returnContainer: Color(0xFFEDE4F6),
    onReturnContainer: Color(0xFF32164A),
    recording: Color(0xFFD32F2F),
    success: Color(0xFF1E7145),
    successContainer: Color(0xFFDDF0E6),
    warning: Color(0xFF8A5300),
    warningContainer: Color(0xFFFBEBD2),
    danger: Color(0xFFC62828),
    dangerContainer: Color(0xFFFBE3E3),
    shimmerBase: Color(0xFFE7ECF3),
    shimmerHighlight: Color(0xFFF2F5F9),
  );

  static const dark = AppColors(
    packing: Color(0xFF8FC3F0),
    packingContainer: Color(0xFF123E63),
    onPackingContainer: Color(0xFFD6E6F7),
    returnColor: Color(0xFFC7A2F0),
    returnContainer: Color(0xFF3B2255),
    onReturnContainer: Color(0xFFEDE4F6),
    recording: Color(0xFFFF7A7A),
    success: Color(0xFF6FD3A0),
    successContainer: Color(0xFF12402A),
    warning: Color(0xFFF5C06A),
    warningContainer: Color(0xFF4A3208),
    danger: Color(0xFFFF8A8A),
    dangerContainer: Color(0xFF4E1717),
    shimmerBase: Color(0xFF232D39),
    shimmerHighlight: Color(0xFF2E3A48),
  );

  @override
  AppColors copyWith({
    Color? packing,
    Color? packingContainer,
    Color? onPackingContainer,
    Color? returnColor,
    Color? returnContainer,
    Color? onReturnContainer,
    Color? recording,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      packing: packing ?? this.packing,
      packingContainer: packingContainer ?? this.packingContainer,
      onPackingContainer: onPackingContainer ?? this.onPackingContainer,
      returnColor: returnColor ?? this.returnColor,
      returnContainer: returnContainer ?? this.returnContainer,
      onReturnContainer: onReturnContainer ?? this.onReturnContainer,
      recording: recording ?? this.recording,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      packing: Color.lerp(packing, other.packing, t)!,
      packingContainer: Color.lerp(packingContainer, other.packingContainer, t)!,
      onPackingContainer:
          Color.lerp(onPackingContainer, other.onPackingContainer, t)!,
      returnColor: Color.lerp(returnColor, other.returnColor, t)!,
      returnContainer: Color.lerp(returnContainer, other.returnContainer, t)!,
      onReturnContainer:
          Color.lerp(onReturnContainer, other.onReturnContainer, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }

  /// Warna indikator token menurut sisa saldo (Bab 7.3).
  ///
  /// ⚠️ Warna saja tidak cukup — §0 melarang warna menjadi satu-satunya pembeda
  /// makna. Indikator token wajib disertai angka sisa token.
  Color tokenIndicator(double ratio) {
    if (ratio <= 0.05) return danger;
    if (ratio <= 0.20) return warning;
    return success;
  }
}

/// Warna yang tidak ikut berubah menurut tema.
class AppStaticColors {
  const AppStaticColors._();

  /// Layar kamera selalu gelap, apa pun tema yang dipilih pengguna.
  static const Color cameraBackdrop = Color(0xFF0F141A);
  static const Color scannerFrame = Color(0xFF6FD3A0);

  /// Avatar cadangan bila `avatar_url` kosong (Bab 9.x): inisial nama di atas
  /// warna yang dihasilkan dari hash `user_id`.
  static const List<Color> avatarPalette = [
    Color(0xFF0D5EA6),
    Color(0xFF5B2C87),
    Color(0xFF1E7145),
    Color(0xFF9A5B00),
    Color(0xFF00696E),
    Color(0xFFA02352),
    Color(0xFF4A5567),
    Color(0xFF6D4C41),
  ];

  static Color avatarFor(String seedText) {
    if (seedText.isEmpty) return avatarPalette.first;
    final hash =
        seedText.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
    return avatarPalette[hash % avatarPalette.length];
  }
}
