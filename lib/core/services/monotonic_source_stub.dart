import 'monotonic_source.dart';

/// Implementasi web.
///
/// Web tidak merekam (Bab 10.1), jadi penghitung seumur halaman sudah cukup.
/// [Stopwatch] tetap memakai jam monotonic peramban — bukan jam sistem —
/// sehingga aturan "jangan mengurangi jam perangkat" tetap dipatuhi di sini.
class ProcessMonotonicSource implements MonotonicSource {
  ProcessMonotonicSource();

  static final Stopwatch _sinceStart = Stopwatch()..start();
  static final String _processId =
      'process:${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<MonotonicReading> read() async => MonotonicReading(
        elapsed: _sinceStart.elapsed,
        sourceId: _processId,
      );

  @override
  String get describe => 'sejak halaman dibuka (Stopwatch)';
}

MonotonicSource createPlatformMonotonicSource() => ProcessMonotonicSource();
