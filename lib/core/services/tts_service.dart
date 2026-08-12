import 'package:flutter_tts/flutter_tts.dart';

import '../utils/logger.dart';

/// Voice-over penanda mulai/selesai rekam (Bab 8.4).
///
/// ⚠️ TTS dan perekaman audio berebut sesi audio perangkat, dan perilakunya
/// berbeda antara Android dan iOS. Kalimat yang diucapkan ditetapkan di
/// Bab 8.4; teksnya wajib mengikuti bahasa aktif (Bab 9.11 poin 6), karena itu
/// kelas ini menerima teks jadi dan tidak menyusun kalimat sendiri.
class TtsService {
  TtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  static const AppLogger _log = AppLogger('TtsService');

  bool _enabled = true;
  bool _initialized = false;

  bool get isEnabled => _enabled;

  set enabled(bool value) => _enabled = value;

  /// [locale] mengikuti `UserSettings.ttsLocale` — `id-ID` atau `en-US`.
  Future<void> init({required String locale}) async {
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(0.9);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
    } on Object catch (e) {
      _log.w('Inisialisasi TTS gagal', e);
    }
  }

  Future<void> speak(String text) async {
    if (!_enabled || !_initialized || text.isEmpty) return;
    try {
      await _tts.speak(text);
    } on Object catch (e) {
      // Voice-over adalah kenyamanan, bukan syarat. Kegagalannya tidak boleh
      // menghentikan perekaman.
      _log.w('TTS gagal berbicara', e);
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (_) {}
  }
}
