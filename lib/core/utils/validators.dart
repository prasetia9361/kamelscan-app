/// Validasi input. Mengembalikan **kunci l10n** bila tidak valid, dan `null`
/// bila valid — cocok langsung dipakai sebagai `validator` TextFormField
/// setelah dipetakan ke teks terjemahan.
library;

class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  /// `chk_username_format` di Bab 5.2: `^[a-z0-9._]{4,20}$`.
  static final RegExp _username = RegExp(r'^[a-z0-9._]{4,20}$');

  /// Nomor HP Indonesia: 08xx, +628xx, atau 628xx. 9–15 digit total.
  static final RegExp _phoneId = RegExp(r'^(?:\+?62|0)8[1-9][0-9]{6,11}$');

  /// Resi marketplace (Bab 8.3.1): 6–50 karakter, hanya alfanumerik serta
  /// tanda `-` dan `/`.
  static final RegExp _resi = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/]{5,49}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'validationEmailRequired';
    if (!_email.hasMatch(v)) return 'validationEmailInvalid';
    return null;
  }

  /// Supabase Auth menolak password di bawah 6 karakter. Kita naikkan ke 8
  /// dan wajibkan huruf + angka.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'validationPasswordRequired';
    if (v.length < 8) return 'validationPasswordTooShort';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    if (!hasLetter || !hasDigit) return 'validationPasswordWeak';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'validationPasswordRequired';
    if (value != original) return 'validationPasswordMismatch';
    return null;
  }

  static String? username(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'validationUsernameRequired' : null;
    if (!_username.hasMatch(v)) return 'validationUsernameInvalid';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'validationNameRequired';
    if (v.length < 3) return 'validationNameTooShort';
    if (v.length > 80) return 'validationNameTooLong';
    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final v = normalizePhone(value ?? '');
    if (v.isEmpty) return required ? 'validationPhoneRequired' : null;
    if (!_phoneId.hasMatch(v)) return 'validationPhoneInvalid';
    return null;
  }

  static String? resiCode(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) return 'validationResiRequired';
    // Bab 8.3.1 — isi berupa URL ditolak dengan pesan khusus, bukan dipaksa
    // menjadi nomor resi.
    if (isLikelyUrl(raw)) return 'validationResiNotACode';
    final v = normalizeResi(raw);
    if (!_resi.hasMatch(v)) return 'validationResiInvalid';
    return null;
  }

  /// QR sebagian marketplace berisi URL pelacakan, bukan nomor resi.
  static bool isLikelyUrl(String raw) {
    final v = raw.trim().toLowerCase();
    return v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('www.') ||
        v.contains('://');
  }

  static String? required(String? value, [String key = 'validationRequired']) {
    if (value == null || value.trim().isEmpty) return key;
    return null;
  }

  static String? shopName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'validationShopNameRequired';
    if (v.length > 60) return 'validationShopNameTooLong';
    return null;
  }

  // ---------- Normalisasi ----------

  /// Bab 7.5 — tutup celah alias Gmail agar uji coba gratis tidak diulang:
  /// buang bagian setelah `+`, dan hapus titik khusus domain gmail.
  ///
  /// Klien menormalkan untuk umpan balik dini; **sumber kebenarannya tetap
  /// server** (kolom `users.email_normalized`).
  static String normalizeEmail(String raw) {
    final v = raw.trim().toLowerCase();
    final at = v.lastIndexOf('@');
    if (at <= 0) return v;

    var local = v.substring(0, at);
    final domain = v.substring(at + 1);

    final plus = local.indexOf('+');
    if (plus >= 0) local = local.substring(0, plus);

    if (domain == 'gmail.com' || domain == 'googlemail.com') {
      local = local.replaceAll('.', '');
      return '$local@gmail.com';
    }
    return '$local@$domain';
  }

  /// Seragamkan ke format `62xxxxxxxxxx` tanpa spasi/tanda baca.
  static String normalizePhone(String raw) {
    var v = raw.replaceAll(RegExp(r'[\s\-().]'), '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('+')) v = v.substring(1);
    if (v.startsWith('0')) v = '62${v.substring(1)}';
    return v;
  }

  /// Bab 8.3.1 — buang seluruh spasi (scanner sering menyertakan baris baru)
  /// lalu ubah ke huruf besar. Tidak ada penebakan isi: kode yang bukan resi
  /// ditolak oleh [resiCode], bukan diperbaiki diam-diam.
  static String normalizeResi(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
}
