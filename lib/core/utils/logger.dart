import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'app_failure.dart';

enum LogLevel { debug, info, warn, error }

/// Logger tipis di atas `dart:developer`.
///
/// ⚠️ Sentry dikonfigurasi `sendDefaultPii: false`. Jaga agar tetap begitu:
/// **jangan pernah** menuliskan email, nomor HP, atau nomor resi utuh ke log
/// yang ikut terkirim. Pakai `Formatters.maskResi` bila perlu.
class AppLogger {
  const AppLogger(this._tag);

  final String _tag;

  factory AppLogger.of(Object owner) => AppLogger(owner.runtimeType.toString());

  void d(String message) => _log(LogLevel.debug, message);
  void i(String message) => _log(LogLevel.info, message);
  void w(String message, [Object? error]) => _log(LogLevel.warn, message, error);

  void e(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, message, error, stack);

  void failure(AppFailure f) => _log(
        f.shouldReport ? LogLevel.error : LogLevel.warn,
        '${f.kind.name}: ${f.messageKey}',
        f.debugMessage,
        f.stackTrace,
      );

  void _log(LogLevel level, String message, [Object? error, StackTrace? stack]) {
    // Di produksi hanya warn ke atas yang dicetak; sisanya membebani tanpa guna.
    if (Env.isProd && level.index < LogLevel.warn.index) return;
    if (kReleaseMode && level.index < LogLevel.warn.index) return;

    developer.log(
      message,
      name: '${_levelLabel(level)} $_tag',
      error: error,
      stackTrace: stack,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
    );
  }

  static String _levelLabel(LogLevel level) => switch (level) {
        LogLevel.debug => '·',
        LogLevel.info => 'i',
        LogLevel.warn => '!',
        LogLevel.error => 'x',
      };
}
