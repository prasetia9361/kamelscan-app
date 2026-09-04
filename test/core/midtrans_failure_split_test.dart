import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dua kegagalan Midtrans wajib punya kalimat yang berbeda (Bab 12.3).
///
/// 🔴 Utang nomor 2 daftar kesiapan produksi, lunas 3 September 2026.
///
/// `MIDTRANS_UNREACHABLE` dan `MIDTRANS_REJECTED` dipetakan ke **satu kalimat
/// yang sama**, dan `create-payment` tidak menuliskan penolakan Midtrans ke
/// catatan fungsi sama sekali.
///
/// Akibatnya terukur: 31 Agustus 2026 tiga pembayaran gagal beruntun karena
/// kunci sandbox dan produksi tertukar. Tidak ada satu pun petunjuk di layar
/// maupun di catatan fungsi, dan sebabnya baru ketahuan setelah kuncinya diuji
/// langsung ke Midtrans dengan tangan.
///
/// ⚠️ Diuji dengan **membaca sumbernya**, mengikuti pola
/// `failure_message_keys_test.dart`. `_midtransFailure` privat dan Edge
/// Function berjalan di Deno — keduanya tidak dapat dipanggil dari sini.
/// Membaca sumber tetap jauh lebih baik daripada tidak menjaga sama sekali:
/// yang dijaga adalah *keputusan*, dan keputusan itu terlihat di teksnya.
void main() {
  late String repo;
  late String pesan;
  late String edge;

  setUpAll(() {
    repo = File('lib/core/repositories/subscription_repository.dart')
        .readAsStringSync();
    pesan = File('lib/core/widgets/failure_messages.dart').readAsStringSync();
    edge =
        File('supabase/functions/create-payment/index.ts').readAsStringSync();
  });

  test('sumbernya terbaca — penjagaan ini tidak boleh lolos karena kosong', () {
    expect(repo, contains('_midtransFailure'));
    expect(edge, contains('MIDTRANS_REJECTED'));
  });

  group('🔴 pemetaan di aplikasi', () {
    test('keduanya TIDAK lagi berbagi satu cabang', () {
      // Bentuk lamanya persis: `'MIDTRANS_UNREACHABLE' || 'MIDTRANS_REJECTED'`.
      expect(
        repo.replaceAll(RegExp(r'\s+'), ' '),
        isNot(contains("'MIDTRANS_UNREACHABLE' || 'MIDTRANS_REJECTED'")),
        reason: 'kedua kegagalan kembali berbagi satu kalimat',
      );
    });

    test('masing-masing punya kunci pesannya sendiri', () {
      expect(repo, contains("'MIDTRANS_UNREACHABLE' => "));
      expect(repo, contains("'MIDTRANS_REJECTED' => "));
      expect(repo, contains('errorMidtransUnreachable'));
      expect(repo, contains('errorMidtransRejected'));
    });

    test('kedua kunci terdaftar di failure_messages', () {
      // Kunci yang lupa disambungkan tidak menimbulkan galat apa pun — ia
      // hanya jatuh ke "Terjadi kesalahan" (cacat 20 Agustus 2026).
      expect(pesan, contains("'errorMidtransUnreachable' =>"));
      expect(pesan, contains("'errorMidtransRejected' =>"));
    });
  });

  group('🔴 catatan Edge Function', () {
    test('kedua jalur kegagalan menulis console.error', () {
      expect(edge, contains("console.error('MIDTRANS_UNREACHABLE'"));
      expect(edge, contains("console.error('MIDTRANS_REJECTED'"));
    });

    test('penolakan Midtrans membawa keterangan yang benar-benar menolong', () {
      // Ketiganya yang membedakan "kunci salah" dari "akun belum aktif" tanpa
      // harus menguji kuncinya dengan tangan.
      final blok = edge.substring(edge.indexOf("console.error('MIDTRANS_REJECTED'"));
      expect(blok, contains('http_status'));
      expect(blok, contains('error_messages'));
      expect(blok, contains('production'));
    });

    test('🔴 kunci server TIDAK PERNAH ikut tercetak utuh', () {
      // Catatan fungsi dapat dibaca siapa pun yang punya akses dashboard, dan
      // kunci server Midtrans adalah kunci untuk MENAGIH atas nama kami.
      // Yang boleh keluar hanya awalannya.
      expect(
        edge,
        isNot(contains('serverKey,')),
        reason: 'kunci server tercetak utuh ke catatan fungsi',
      );
      expect(
        edge,
        isNot(contains('server_key: serverKey')),
        reason: 'kunci server tercetak utuh ke catatan fungsi',
      );
      expect(edge, contains('key_prefix'));
    });
  });
}
