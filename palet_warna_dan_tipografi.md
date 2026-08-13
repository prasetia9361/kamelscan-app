# KamelScan — Palet Warna & Tipografi

**Versi:** 1.0
**Tanggal:** 11 Agustus 2026
**Untuk:** Programmer Flutter, Desainer
**Melengkapi:** `panduan_dokumentasi.md` Bab 3.2 (`core/theme/`) dan Bab 9.10

---

## 0. Prinsip yang mendasari pilihan ini

Palet ini bukan soal selera. Empat kenyataan pemakaian yang menentukannya:

1. **Dipakai di gudang bercahaya terang.** Layar HP sering dilihat di bawah lampu neon terang atau cahaya matahari dari pintu gudang. Warna pastel dan abu-abu muda hilang. Semua warna teks di sini minimal **4,5:1** terhadap latarnya, sebagian besar di atas 6:1.

2. **Produk ini menjual kepercayaan.** ScanProof/KamelScan adalah alat bukti hukum. Biru tua adalah pilihan yang tepat — bukan karena indah, tetapi karena itu kode visual yang dipakai perbankan dan layanan dokumen resmi. Warna cerah kekanakan akan melemahkan posisi produk saat dipakai berdebat dengan pusat resolusi marketplace.

3. **Nama merek KamelScan mengarah ke warna hangat.** Aksen kuning-cokelat (*camel*) dipakai sebagai warna kedua. Ini memberi identitas yang tidak generik, sekaligus menyeimbangkan biru yang dingin.

4. **Dioperasikan cepat, kadang bersarung tangan.** Ukuran font dinaikkan di atas bawaan Material 3, dan angka penting memakai varian tebal berukuran besar.

🔴 **Aturan yang tidak boleh dilanggar: warna tidak pernah menjadi satu-satunya pembeda makna.** Setiap chip status wajib punya ikon dan teks. Sekitar 8% pria mengalami gangguan penglihatan warna, dan di gudang mereka tetap harus bisa membedakan video packing dari video return.

---

## 1. Palet warna — mode terang

### 1.1 Warna inti

| Peran | Hex | Kontras di atas putih | Dipakai untuk |
|---|---|---|---|
| `primary` | `#0D5EA6` | 6,63:1 ✅ | Tombol utama, tautan, AppBar, item nav aktif |
| `onPrimary` | `#FFFFFF` | 6,63:1 ✅ | Teks di atas primary |
| `primaryContainer` | `#D6E6F7` | — | Latar chip terpilih, sorotan lembut |
| `onPrimaryContainer` | `#06304F` | 10,70:1 ✅ | Teks di atas primaryContainer |
| `secondary` | `#9A5B00` | 5,43:1 ✅ | Aksen merek, tombol sekunder, ikon Pro |
| `onSecondary` | `#FFFFFF` | 5,43:1 ✅ | Teks di atas secondary |
| `secondaryContainer` | `#FBEBD2` | — | Latar badge tier Pro |
| `onSecondaryContainer` | `#4A2B00` | — | Teks di atas secondaryContainer |

### 1.2 Permukaan & teks

| Peran | Hex | Kontras | Dipakai untuk |
|---|---|---|---|
| `surface` | `#FFFFFF` | — | Latar kartu, sheet, dialog |
| `surfaceContainer` | `#F2F5F9` | — | Latar halaman, kartu monitoring |
| `surfaceContainerHigh` | `#E7ECF3` | — | Kartu bertumpuk, baris terpilih |
| `onSurface` | `#101828` | 17,75:1 ✅ | Teks utama |
| `onSurfaceVariant` | `#4A5567` | 7,54:1 ✅ | Teks pendukung, label |
| `outline` | `#C7CFDA` | — | Garis pembatas, border input |
| `outlineVariant` | `#E3E8EF` | — | Pemisah baris daftar |

Perhatikan: `onSurfaceVariant` sengaja **tidak** dibuat abu-abu muda. Teks pendukung yang terlalu pucat adalah kesalahan paling umum pada aplikasi lapangan — di bawah cahaya terang teks itu hilang sama sekali.

### 1.3 Warna semantik

| Peran | Hex | Kontras | Dipakai untuk |
|---|---|---|---|
| `packing` | `#0D5EA6` | 6,63:1 ✅ | Video paket kirim |
| `packingContainer` | `#D6E6F7` | — | Latar chip packing |
| `returnColor` | `#5B2C87` | 9,74:1 ✅ | Video paket retur |
| `returnContainer` | `#EDE4F6` | — | Latar chip retur |
| `recording` | `#D32F2F` | 4,98:1 ✅ | Indikator sedang merekam |
| `success` | `#1E7145` | 5,99:1 ✅ | Terunggah, token aman, terverifikasi |
| `warning` | `#8A5300` | 6,33:1 ✅ | Token menipis, menunggu unggah |
| `danger` | `#C62828` | 5,62:1 ✅ | Token habis, gagal unggah, aksi hapus |

⚠️ **`packing` dan `returnColor` sengaja dibedakan luminansnya**, bukan hanya rona. Biru `#0D5EA6` dan ungu `#5B2C87` berbeda 1,47× dalam kecerahan, sehingga masih terbedakan pada layar hitam-putih dan bagi penderita buta warna biru-ungu. Tetap wajib disertai ikon dan teks.

**Gaya chip yang berbeda memperkuat pembedaan:**

- Packing → chip **isi penuh** biru, teks putih, ikon `inventory_2`
- Retur → chip **garis tepi** ungu, latar `returnContainer`, ikon `keyboard_return`

---

## 2. Palet warna — mode gelap

Bukan sekadar pembalikan. Warna disesuaikan agar tidak menyilaukan saat dipakai di gudang minim cahaya, sambil tetap lolos kontras.

| Peran | Hex | Kontras di atas `#0F141A` |
|---|---|---|
| `surface` | `#0F141A` | — |
| `surfaceContainer` | `#1A222C` | — |
| `surfaceContainerHigh` | `#232D39` | — |
| `onSurface` | `#E6EDF5` | 15,68:1 ✅ |
| `onSurfaceVariant` | `#A5B3C4` | 8,67:1 ✅ |
| `outline` | `#3A4757` | — |
| `primary` | `#8FC3F0` | 9,89:1 ✅ |
| `onPrimary` | `#06304F` | 7,28:1 ✅ |
| `primaryContainer` | `#123E63` | — |
| `secondary` | `#F0B454` | 10,01:1 ✅ |
| `packing` | `#8FC3F0` | 9,89:1 ✅ |
| `returnColor` | `#C7A2F0` | 8,9:1 ✅ |
| `recording` | `#FF7A7A` | 7,33:1 ✅ |
| `success` | `#6FD3A0` | 10,13:1 ✅ |
| `warning` | `#F5C06A` | 11,13:1 ✅ |
| `danger` | `#FF8A8A` | 8,15:1 ✅ |

⚠️ Latar gelap sengaja **bukan hitam murni** (`#000000`). Hitam murni pada layar OLED menghasilkan efek *smearing* saat menggulir dan kontras yang terlalu keras untuk dipandang lama.

---

## 3. Tipografi

### 3.1 Pilihan huruf

| Kegunaan | Huruf | Alasan |
|---|---|---|
| Seluruh antarmuka | **Inter** | Keterbacaan tinggi pada ukuran kecil, bentuk huruf terbuka, mendukung angka bertabulasi |
| **Nomor resi** | **JetBrains Mono** | Nol bercoret, `1`/`l`/`I` berbeda jelas, lebar tetap |

🔴 **Keputusan penting: nomor resi wajib memakai huruf monospace.** Pada Inter dan hampir semua huruf sans-serif, angka `0` dan huruf `O` nyaris identik, begitu pula `1`, `l`, dan `I`. Packer yang membacakan nomor resi lewat telepon ke pusat resolusi marketplace akan salah, dan bukti videonya jadi tidak ditemukan. Ini bukan preferensi estetika.

**Cara memasang — bundel sebagai aset, jangan `google_fonts` runtime.**

Paket `google_fonts` mengunduh huruf saat aplikasi pertama dibuka. Di gudang yang sinyalnya buruk, teks akan tampil dengan huruf cadangan atau kosong. Unduh berkasnya, masukkan ke repo:

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Bold.ttf
          weight: 700
```

Hanya empat berat Inter dan satu berat mono. Setiap berat tambahan menambah ± 300 KB ukuran aplikasi tanpa manfaat nyata.

### 3.2 Skala tipografi

Dinaikkan dari bawaan Material 3. Ukuran tubuh teks minimal 14 sp sesuai Bab 9.10.

| Token | Ukuran / Tinggi baris | Berat | Dipakai untuk |
|---|---|---|---|
| `displayMedium` | 40 / 48 | 700 | Angka besar kartu monitoring |
| `displaySmall` | 32 / 40 | 700 | Angka sekunder, sisa token |
| `headlineMedium` | 26 / 34 | 700 | Judul halaman |
| `headlineSmall` | 22 / 30 | 600 | Judul bagian |
| `titleLarge` | 20 / 28 | 600 | Judul kartu, AppBar |
| `titleMedium` | 17 / 24 | 600 | Judul item daftar, label penting |
| `bodyLarge` | 16 / 24 | 400 | **Teks utama, ini bawaannya** |
| `bodyMedium` | 14 / 20 | 400 | Teks pendukung |
| `bodySmall` | 13 / 18 | 400 | Keterangan, stempel waktu |
| `labelLarge` | 15 / 20 | 600 | Label tombol |
| `labelMedium` | 13 / 16 | 600 | Teks chip, badge |
| `labelSmall` | 12 / 16 | 500 | Label paling kecil — batas bawah |

### 3.3 Gaya khusus

| Nama | Spesifikasi | Dipakai untuk |
|---|---|---|
| `resiDisplay` | JetBrainsMono 26 / 34, w700, `letterSpacing: 0.5` | Nomor resi di layar kamera & detail video |
| `resiInline` | JetBrainsMono 15 / 20, w700, `letterSpacing: 0.3` | Nomor resi dalam daftar riwayat |
| `timerDisplay` | JetBrainsMono 22 / 28, w700, angka bertabulasi | Penghitung durasi saat merekam |
| `statNumber` | Inter 40 / 48, w700, `FontFeature.tabularFigures()` | Angka kartu monitoring |

⚠️ `FontFeature.tabularFigures()` wajib pada semua angka yang berubah-ubah — penghitung waktu, sisa token, jumlah video. Tanpa itu, lebar setiap angka berbeda dan tampilan bergoyang setiap detik saat merekam. Detail kecil yang membuat aplikasi terasa murah bila diabaikan.

---

## 4. Kode siap pakai

### 4.1 `core/theme/app_colors.dart`

```dart
import 'package:flutter/material.dart';

/// Warna semantik di luar ColorScheme Material.
/// Diakses lewat Theme.of(context).extension<AppColors>()!
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

  static const light = AppColors(
    packing:            Color(0xFF0D5EA6),
    packingContainer:   Color(0xFFD6E6F7),
    onPackingContainer: Color(0xFF06304F),
    returnColor:        Color(0xFF5B2C87),
    returnContainer:    Color(0xFFEDE4F6),
    onReturnContainer:  Color(0xFF32164A),
    recording:          Color(0xFFD32F2F),
    success:            Color(0xFF1E7145),
    successContainer:   Color(0xFFDDF0E6),
    warning:            Color(0xFF8A5300),
    warningContainer:   Color(0xFFFBEBD2),
    danger:             Color(0xFFC62828),
    dangerContainer:    Color(0xFFFBE3E3),
  );

  static const dark = AppColors(
    packing:            Color(0xFF8FC3F0),
    packingContainer:   Color(0xFF123E63),
    onPackingContainer: Color(0xFFD6E6F7),
    returnColor:        Color(0xFFC7A2F0),
    returnContainer:    Color(0xFF3B2255),
    onReturnContainer:  Color(0xFFEDE4F6),
    recording:          Color(0xFFFF7A7A),
    success:            Color(0xFF6FD3A0),
    successContainer:   Color(0xFF12402A),
    warning:            Color(0xFFF5C06A),
    warningContainer:   Color(0xFF4A3208),
    danger:             Color(0xFFFF8A8A),
    dangerContainer:    Color(0xFF4E1717),
  );

  @override
  AppColors copyWith({
    Color? packing, Color? packingContainer, Color? onPackingContainer,
    Color? returnColor, Color? returnContainer, Color? onReturnContainer,
    Color? recording, Color? success, Color? successContainer,
    Color? warning, Color? warningContainer, Color? danger, Color? dangerContainer,
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
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      packing: Color.lerp(packing, other.packing, t)!,
      packingContainer: Color.lerp(packingContainer, other.packingContainer, t)!,
      onPackingContainer: Color.lerp(onPackingContainer, other.onPackingContainer, t)!,
      returnColor: Color.lerp(returnColor, other.returnColor, t)!,
      returnContainer: Color.lerp(returnContainer, other.returnContainer, t)!,
      onReturnContainer: Color.lerp(onReturnContainer, other.onReturnContainer, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
    );
  }
}
```

### 4.2 `core/theme/app_text_styles.dart`

```dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

class AppFonts {
  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';
}

class AppTextStyles {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color onSurface) => TextTheme(
    displayMedium:  TextStyle(fontFamily: AppFonts.sans, fontSize: 40, height: 48/40, fontWeight: FontWeight.w700, color: onSurface, fontFeatures: _tabular),
    displaySmall:   TextStyle(fontFamily: AppFonts.sans, fontSize: 32, height: 40/32, fontWeight: FontWeight.w700, color: onSurface, fontFeatures: _tabular),
    headlineMedium: TextStyle(fontFamily: AppFonts.sans, fontSize: 26, height: 34/26, fontWeight: FontWeight.w700, color: onSurface),
    headlineSmall:  TextStyle(fontFamily: AppFonts.sans, fontSize: 22, height: 30/22, fontWeight: FontWeight.w600, color: onSurface),
    titleLarge:     TextStyle(fontFamily: AppFonts.sans, fontSize: 20, height: 28/20, fontWeight: FontWeight.w600, color: onSurface),
    titleMedium:    TextStyle(fontFamily: AppFonts.sans, fontSize: 17, height: 24/17, fontWeight: FontWeight.w600, color: onSurface),
    bodyLarge:      TextStyle(fontFamily: AppFonts.sans, fontSize: 16, height: 24/16, fontWeight: FontWeight.w400, color: onSurface),
    bodyMedium:     TextStyle(fontFamily: AppFonts.sans, fontSize: 14, height: 20/14, fontWeight: FontWeight.w400, color: onSurface),
    bodySmall:      TextStyle(fontFamily: AppFonts.sans, fontSize: 13, height: 18/13, fontWeight: FontWeight.w400, color: onSurface),
    labelLarge:     TextStyle(fontFamily: AppFonts.sans, fontSize: 15, height: 20/15, fontWeight: FontWeight.w600, color: onSurface),
    labelMedium:    TextStyle(fontFamily: AppFonts.sans, fontSize: 13, height: 16/13, fontWeight: FontWeight.w600, color: onSurface),
    labelSmall:     TextStyle(fontFamily: AppFonts.sans, fontSize: 12, height: 16/12, fontWeight: FontWeight.w500, color: onSurface),
  );

  // ---- gaya khusus, tidak masuk TextTheme ----
  static const resiDisplay = TextStyle(
    fontFamily: AppFonts.mono, fontSize: 26, height: 34/26,
    fontWeight: FontWeight.w700, letterSpacing: 0.5, fontFeatures: _tabular,
  );

  static const resiInline = TextStyle(
    fontFamily: AppFonts.mono, fontSize: 15, height: 20/15,
    fontWeight: FontWeight.w700, letterSpacing: 0.3, fontFeatures: _tabular,
  );

  static const timerDisplay = TextStyle(
    fontFamily: AppFonts.mono, fontSize: 22, height: 28/22,
    fontWeight: FontWeight.w700, fontFeatures: _tabular,
  );
}
```

### 4.3 `core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static const seed = Color(0xFF0D5EA6);

  static ThemeData light() => _build(
    scheme: const ColorScheme.light(
      primary:              Color(0xFF0D5EA6),
      onPrimary:            Color(0xFFFFFFFF),
      primaryContainer:     Color(0xFFD6E6F7),
      onPrimaryContainer:   Color(0xFF06304F),
      secondary:            Color(0xFF9A5B00),
      onSecondary:          Color(0xFFFFFFFF),
      secondaryContainer:   Color(0xFFFBEBD2),
      onSecondaryContainer: Color(0xFF4A2B00),
      error:                Color(0xFFC62828),
      onError:              Color(0xFFFFFFFF),
      surface:              Color(0xFFFFFFFF),
      onSurface:            Color(0xFF101828),
      surfaceContainer:     Color(0xFFF2F5F9),
      surfaceContainerHigh: Color(0xFFE7ECF3),
      onSurfaceVariant:     Color(0xFF4A5567),
      outline:              Color(0xFFC7CFDA),
      outlineVariant:       Color(0xFFE3E8EF),
    ),
    appColors: AppColors.light,
  );

  static ThemeData dark() => _build(
    scheme: const ColorScheme.dark(
      primary:              Color(0xFF8FC3F0),
      onPrimary:            Color(0xFF06304F),
      primaryContainer:     Color(0xFF123E63),
      onPrimaryContainer:   Color(0xFFD6E6F7),
      secondary:            Color(0xFFF0B454),
      onSecondary:          Color(0xFF3A2200),
      secondaryContainer:   Color(0xFF4A3208),
      onSecondaryContainer: Color(0xFFFBEBD2),
      error:                Color(0xFFFF8A8A),
      onError:              Color(0xFF4E1717),
      surface:              Color(0xFF0F141A),
      onSurface:            Color(0xFFE6EDF5),
      surfaceContainer:     Color(0xFF1A222C),
      surfaceContainerHigh: Color(0xFF232D39),
      onSurfaceVariant:     Color(0xFFA5B3C4),
      outline:              Color(0xFF3A4757),
      outlineVariant:       Color(0xFF2A3542),
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

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      // Tinggi 52 dp, di atas minimum 48 dp. Gudang, sarung tangan.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),

      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
```

### 4.4 Pemakaian di widget

```dart
final c = Theme.of(context).extension<AppColors>()!;
final t = Theme.of(context).textTheme;

// Chip packing — isi penuh
Chip(
  avatar: Icon(Icons.inventory_2, size: 16, color: Colors.white),
  label: Text('Packing', style: t.labelMedium?.copyWith(color: Colors.white)),
  backgroundColor: c.packing,
);

// Chip retur — garis tepi, sengaja beda gaya
Chip(
  avatar: Icon(Icons.keyboard_return, size: 16, color: c.returnColor),
  label: Text('Retur', style: t.labelMedium?.copyWith(color: c.onReturnContainer)),
  backgroundColor: c.returnContainer,
  side: BorderSide(color: c.returnColor),
);

// Nomor resi
Text(video.resiCode, style: AppTextStyles.resiDisplay.copyWith(color: c.packing));
```

---

## 5. Radius, jarak, dan ukuran sentuh

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `radiusSmall` | 8 | Chip, badge, kolom input kecil |
| `radiusMedium` | 12 | Tombol, kolom input, snackbar |
| `radiusLarge` | 16 | Kartu, bottom sheet |
| `radiusFull` | 999 | Avatar, indikator bulat |
| `spaceXs` | 4 | Jarak antar ikon dan teks |
| `spaceSm` | 8 | Jarak dalam komponen |
| `spaceMd` | 16 | **Padding baku halaman** |
| `spaceLg` | 24 | Jarak antar bagian |
| `spaceXl` | 32 | Jarak besar antar blok |
| `touchMin` | 48 | Batas mutlak area sentuh |
| `touchComfort` | 52 | **Tinggi tombol baku** |

---

## 6. Yang tidak boleh dilakukan

| Jangan | Alasan |
|---|---|
| Menulis `Color(0xFF...)` langsung di widget | Mode gelap akan rusak. Selalu lewat `Theme.of(context)` |
| Memakai `Colors.grey` atau `Colors.blue` bawaan Flutter | Tidak lolos kontras dan tidak konsisten |
| Membedakan packing dan retur hanya dengan warna | Gagal bagi pengguna buta warna |
| Font tubuh di bawah 14 sp | Tidak terbaca di gudang |
| Area sentuh di bawah 48 dp | Gagal ditekan dengan sarung tangan |
| Memakai `google_fonts` dengan pengunduhan runtime | Gagal saat sinyal buruk |
| Menambah berat huruf di luar empat yang terdaftar | Menambah ukuran aplikasi tanpa manfaat |
| Angka berubah tanpa `tabularFigures` | Tampilan bergoyang tiap detik |

---

## 7. Untuk desainer

Kalau desainer membuat ulang tampilan di Figma, ketiga hal ini yang wajib dipertahankan, sisanya bebas:

1. **Rasio kontras minimal 4,5:1** untuk semua teks. Periksa dengan alat pemeriksa kontras, bukan dengan mata.
2. **Ukuran sentuh minimal 48 × 48 dp.**
3. **Makna tidak pernah disampaikan hanya lewat warna.**

Palet ini sengaja dibuat konservatif agar cepat dieksekusi. Kalau desainer punya arah merek yang lebih kuat, silakan diganti — tetapi lakukan **sebelum Minggu 2**. Setelah layar-layar dibuat, penggantian warna bukan lagi satu baris kode.
