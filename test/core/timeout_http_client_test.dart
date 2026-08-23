import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kamelscan/core/services/timeout_http_client.dart';

/// Batas waktu permintaan Supabase.
///
/// 🔴 Cacat yang dijawab berkas ini (19 Agustus 2026): dalam mode pesawat,
/// aplikasi berputar tak berujung di layar splash. Batas waktu yang dipasang di
/// **layar** tidak cukup — layarnya berhenti menunggu, tetapi permintaannya
/// tetap hidup, dan percobaan berikutnya menunggu dari nol lagi.
///
/// ```
/// 09:27:54  mulai · isSignedIn=true
/// 09:28:14  sesi TIMEOUT setelah 20 dtk
/// 09:28:14  mulai · isSignedIn=true      ← mengulang
/// 09:28:34  sesi TIMEOUT setelah 20 dtk
/// ```
void main() {
  /// Klien yang tidak pernah menjawab — tiruan jaringan yang **diam**, bukan
  /// yang menolak sambungan. Justru yang diam inilah yang menggantung, karena
  /// tidak ada yang memberi tahu klien bahwa jawabannya tidak akan datang.
  http.Client klienDiam() => _KlienPalsu(() => Completer<
      http.StreamedResponse>().future); // tidak pernah selesai

  test('permintaan yang tidak dijawab berakhir dengan TimeoutException',
      () async {
    final client = TimeoutHttpClient(
      inner: klienDiam(),
      timeout: const Duration(milliseconds: 80),
    );

    await expectLater(
      client.get(Uri.parse('https://contoh.invalid/apa-saja')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('berakhir mendekati batasnya, bukan menggantung', () async {
    final client = TimeoutHttpClient(
      inner: klienDiam(),
      timeout: const Duration(milliseconds: 100),
    );

    final jam = Stopwatch()..start();
    try {
      await client.get(Uri.parse('https://contoh.invalid/apa-saja'));
    } on TimeoutException {
      // memang ini yang ditunggu
    }
    jam.stop();

    expect(jam.elapsedMilliseconds, lessThan(1000));
  });

  test('permintaan yang dijawab tidak terganggu batas waktu', () async {
    final client = TimeoutHttpClient(
      inner: _KlienPalsu(
        () async => http.StreamedResponse(
          Stream.value('oke'.codeUnits),
          200,
        ),
      ),
      timeout: const Duration(seconds: 5),
    );

    final response = await client.get(Uri.parse('https://contoh.invalid/oke'));
    expect(response.statusCode, 200);
    expect(response.body, 'oke');
  });

  group('Batas bawaan', () {
    test('lebih pendek daripada batas layar splash (20 detik)', () {
      // 🔴 Urutan ini menentukan. Bila permintaannya menyerah **setelah**
      // layarnya, layar berhenti menunggu sementara permintaan masih hidup —
      // dan putaran tak berujung itu kembali lagi.
      expect(
        TimeoutHttpClient.defaultTimeout,
        lessThan(const Duration(seconds: 20)),
      );
    });

    test('cukup longgar untuk Edge Function yang baru bangun', () {
      expect(
        TimeoutHttpClient.defaultTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 10)),
      );
    });
  });
}

class _KlienPalsu extends http.BaseClient {
  _KlienPalsu(this._jawab);

  final Future<http.StreamedResponse> Function() _jawab;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _jawab();
}
