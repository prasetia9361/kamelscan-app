import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Setiap `messageKey` milik `AppFailure` benar-benar punya kalimatnya
/// (Bab 9.11 poin 5).
///
/// 🔴 Cacat yang dijawab berkas ini, 20 Agustus 2026 — dan ia terjadi pada
/// perbaikan yang justru dibuat untuk menghapus kalimat *"Terjadi kesalahan"*.
///
/// Menambah kegagalan baru menuntut tiga tempat disentuh berurutan:
///
///   1. `AppFailure` — kunci pesannya
///   2. `app_id.arb` / `app_en.arb` — kalimatnya
///   3. `failure_messages.dart` — sambungan antara keduanya
///
/// Melewatkan langkah 3 **tidak menimbulkan gejala apa pun**: `analyze` bersih,
/// seluruh tes hijau, aplikasi berjalan. Yang terjadi hanya kuncinya jatuh ke
/// cabang `_` dan pesannya diam-diam berubah menjadi *"Terjadi kesalahan.
/// Coba lagi beberapa saat."* — persis kalimat yang sedang diberantas. Owner
/// yang membacanya akan mencoba lagi berkali-kali hal yang tidak akan pernah
/// berhasil.
///
/// Karena kekeliruannya tidak dapat dilihat, penjagaannya tidak boleh
/// mengandalkan penglihatan. Berkas ini membaca kedua sumbernya apa adanya dan
/// mencocokkannya, sehingga kunci baru yang belum tersambung menggagalkan tes
/// sebelum sempat sampai ke perangkat.
void main() {
  late Set<String> kunciAppFailure;
  late String sumberPenerjemah;

  setUpAll(() {
    final sumberFailure =
        File('lib/core/utils/app_failure.dart').readAsStringSync();
    sumberPenerjemah =
        File('lib/core/widgets/failure_messages.dart').readAsStringSync();

    // Mencocokkan `messageKey: 'xxx'` di mana pun ia ditulis — konstanta
    // maupun factory.
    kunciAppFailure = RegExp(r"messageKey:\s*'([A-Za-z0-9_]+)'")
        .allMatches(sumberFailure)
        .map((m) => m.group(1)!)
        .toSet();
  });

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    // Tanpa pemeriksaan ini, berkas yang berpindah tempat akan membuat seluruh
    // tes di bawah "lulus" atas nol kunci: penjagaan yang hilang tanpa suara,
    // yaitu jenis kegagalan yang sama dengan yang sedang dijaga.
    expect(kunciAppFailure.length, greaterThan(10));
    expect(sumberPenerjemah, contains('messageForKey'));
  });

  test('setiap messageKey AppFailure terdaftar di failure_messages', () {
    // `errorUnknown` sengaja tidak punya cabangnya sendiri — ia justru
    // cabang `_` yang menampung semua yang tidak dikenal. Mendaftarkannya
    // akan mubazir.
    const cadangan = {'errorUnknown'};

    final belumTerdaftar = kunciAppFailure
        .where((k) => !cadangan.contains(k))
        .where((k) => !sumberPenerjemah.contains("'$k' =>"))
        .toList()
      ..sort();

    expect(
      belumTerdaftar,
      isEmpty,
      reason: 'Kunci berikut ada di AppFailure tetapi tidak punya cabang di '
          'failure_messages.dart, sehingga akan tampil sebagai '
          '"Terjadi kesalahan" di layar:\n  ${belumTerdaftar.join('\n  ')}',
    );
  });

  test('kunci yang dipakai Kelola Packer ikut terjaga', () {
    // Disebut namanya agar kegagalan 20 Agustus 2026 punya tes yang menyebut
    // dirinya sendiri, bukan hanya terlindungi oleh aturan umum di atas.
    expect(kunciAppFailure, contains('packersEmailTaken'));
    expect(sumberPenerjemah, contains("'packersEmailTaken' =>"));
  });
}
