/// Penjalan migrasi SQL KamelScan.
///
/// Menjalankan berkas `supabase/migrations/*.sql` berurutan, satu transaksi per
/// berkas, dan mencatat yang sudah dijalankan di tabel `public.schema_migrations`
/// sehingga aman dijalankan ulang.
///
/// Kredensial dibaca dari environment — JANGAN pernah ditulis di berkas ini:
///   SUPABASE_DB_HOST, SUPABASE_DB_PORT, SUPABASE_DB_USER,
///   SUPABASE_DB_PASSWORD, SUPABASE_DB_NAME
///
/// Pemakaian:
///   dart run bin/migrate.dart status      # lihat mana yang sudah/belum
///   dart run bin/migrate.dart up          # jalankan yang belum
///   dart run bin/migrate.dart up --only=00_extensions.sql
///   dart run bin/migrate.dart seed        # jalankan supabase/seed.sql
library;

import 'dart:io';

import 'package:postgres/postgres.dart';

const _migrationsSubdir = 'supabase/migrations';
const _seedSubpath = 'supabase/seed.sql';

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'status' : args.first;
  final only = args
      .firstWhere((a) => a.startsWith('--only='), orElse: () => '')
      .replaceFirst('--only=', '');

  final endpoint = _endpointFromEnv();
  if (endpoint == null) exit(2);

  stdout.writeln('Menghubungi ${endpoint.host}:${endpoint.port}/${endpoint.database} '
      'sebagai ${endpoint.username} ...');

  final Connection conn;
  try {
    conn = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(
        sslMode: SslMode.require,
        connectTimeout: Duration(seconds: 30),
      ),
    );
  } on Object catch (e) {
    stderr.writeln('GAGAL terhubung: $e');
    exit(1);
  }
  stdout.writeln('Terhubung.\n');

  try {
    await _ensureLedger(conn);

    switch (command) {
      case 'status':
        await _status(conn);
      case 'up':
        await _up(conn, only: only);
      case 'seed':
        await _seed(conn);
      default:
        stderr.writeln('Perintah tidak dikenal: $command');
        exit(2);
    }
  } finally {
    await conn.close();
  }
}

Endpoint? _endpointFromEnv() {
  final env = Platform.environment;
  final missing = <String>[
    for (final k in const [
      'SUPABASE_DB_HOST',
      'SUPABASE_DB_USER',
      'SUPABASE_DB_PASSWORD',
    ])
      if ((env[k] ?? '').isEmpty) k,
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Variabel lingkungan belum diisi: ${missing.join(', ')}');
    return null;
  }
  return Endpoint(
    host: env['SUPABASE_DB_HOST']!,
    port: int.tryParse(env['SUPABASE_DB_PORT'] ?? '') ?? 5432,
    database: env['SUPABASE_DB_NAME'] ?? 'postgres',
    username: env['SUPABASE_DB_USER'],
    password: env['SUPABASE_DB_PASSWORD'],
  );
}

Future<void> _ensureLedger(Connection conn) async {
  await conn.execute(
    '''
    create table if not exists public.schema_migrations (
      filename    text primary key,
      applied_at  timestamptz not null default now()
    );
    ''',
    queryMode: QueryMode.simple,
  );
}

List<File> _migrationFiles() {
  final dir = Directory(_resolve(_migrationsSubdir));
  if (!dir.existsSync()) {
    stderr.writeln('Folder migrasi tidak ditemukan: ${dir.path}');
    exit(1);
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.sql'))
      .toList()
    ..sort((a, b) => _name(a).compareTo(_name(b)));
  return files;
}

String _name(File f) => f.uri.pathSegments.last;

/// Cari akar repo dengan menaiki folder dari lokasi skrip sampai menemukan
/// `supabase/migrations`. Dibuat begini agar alat ini tetap jalan walau
/// dipindahkan, dan tidak bergantung pada direktori kerja saat dipanggil.
String _resolve(String subpath) {
  var dir = File.fromUri(Platform.script).parent.absolute;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/$_migrationsSubdir').existsSync()) {
      return '${dir.path}/$subpath';
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  stderr.writeln(
    'Tidak menemukan folder "$_migrationsSubdir" di atas ${Platform.script.toFilePath()}',
  );
  exit(1);
}

Future<Set<String>> _applied(Connection conn) async {
  final rows = await conn.execute(
    'select filename from public.schema_migrations',
    queryMode: QueryMode.simple,
  );
  return rows.map((r) => r[0]! as String).toSet();
}

Future<void> _status(Connection conn) async {
  final applied = await _applied(conn);
  for (final f in _migrationFiles()) {
    final n = _name(f);
    stdout.writeln('${applied.contains(n) ? "  sudah" : "  BELUM"}  $n');
  }
  final pending = _migrationFiles().where((f) => !applied.contains(_name(f)));
  stdout.writeln('\n${pending.length} berkas belum dijalankan.');
}

Future<void> _up(Connection conn, {String only = ''}) async {
  final applied = await _applied(conn);
  var ran = 0;

  for (final file in _migrationFiles()) {
    final name = _name(file);
    if (only.isNotEmpty && name != only) continue;
    if (applied.contains(name)) {
      stdout.writeln('  lewati  $name (sudah dijalankan)');
      continue;
    }

    stdout.write('  jalan   $name ... ');
    final sql = file.readAsStringSync();
    try {
      // Satu transaksi per berkas: bila gagal di tengah, tidak ada yang
      // separuh jadi.
      await conn.runTx((tx) async {
        await tx.execute(sql, queryMode: QueryMode.simple);
        await tx.execute(
          "insert into public.schema_migrations (filename) values ('$name')",
          queryMode: QueryMode.simple,
        );
      });
      stdout.writeln('OK');
      ran++;
    } on Object catch (e) {
      stdout.writeln('GAGAL');
      stderr.writeln('\n--- $name ---\n$e\n');
      stderr.writeln('Dihentikan. Berkas berikutnya tidak dijalankan.');
      exit(1);
    }
  }
  stdout.writeln('\nSelesai. $ran berkas dijalankan.');
}

Future<void> _seed(Connection conn) async {
  final file = File(_resolve(_seedSubpath));
  if (!file.existsSync()) {
    stderr.writeln('seed.sql tidak ditemukan: ${file.path}');
    exit(1);
  }
  stdout.write('  jalan   seed.sql ... ');
  try {
    // Sengaja TANPA runTx: seed.sql memakai ALTER TABLE ... DISABLE TRIGGER
    // dan blok DO yang mengelola transaksinya sendiri.
    await conn.execute(file.readAsStringSync(), queryMode: QueryMode.simple);
    stdout.writeln('OK');
  } on Object catch (e) {
    stdout.writeln('GAGAL');
    stderr.writeln('\n$e');
    exit(1);
  }
}
