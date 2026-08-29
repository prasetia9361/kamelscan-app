import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_contact.freezed.dart';
part 'platform_contact.g.dart';

/// Kontak dukungan platform (Bab 11.5) — baris `platform_settings.contact`.
///
/// 🔴 Nomor WhatsApp di sini adalah **satu-satunya jalan pelanggan menghubungi
/// Anda** saat pembayarannya ditolak, tokennya habis, atau langganannya
/// terkunci. Ia dipakai halaman Pembayaran dan halaman Bantuan; salah satu
/// angka yang keliru membuat seluruh jalur itu mati tanpa satu pun galat yang
/// muncul di mana pun.
///
/// ⚠️ Formatnya nomor internasional tanpa tanda plus dan tanpa nol di depan
/// (`6285…`), karena itu yang diterima `wa.me`. Nomor lokal `08…` menghasilkan
/// tautan yang terbuka tetapi tidak menemukan siapa-siapa — gagal dengan cara
/// yang paling sulit disadari.
@freezed
abstract class PlatformContact with _$PlatformContact {
  const factory PlatformContact({
    @Default('') String whatsapp,
    @Default('') String email,
    @Default('') String address,
  }) = _PlatformContact;

  const PlatformContact._();

  factory PlatformContact.fromJson(Map<String, dynamic> json) =>
      _$PlatformContactFromJson(json);

  /// Nomor sudah berbentuk internasional seperti yang dituntut `wa.me`.
  ///
  /// Dipakai layar untuk memperingatkan **sebelum** disimpan, bukan sesudah
  /// pelanggan pertama gagal menghubungi.
  bool get waLooksInternational =>
      whatsapp.startsWith('62') && whatsapp.length >= 10;
}
