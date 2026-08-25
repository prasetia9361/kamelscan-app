import 'package:flutter_web_plugins/url_strategy.dart' as plugins;

/// Implementasi web: alamat memakai jalur biasa, tanpa `#`.
void applyPlatformUrlStrategy() => plugins.usePathUrlStrategy();
