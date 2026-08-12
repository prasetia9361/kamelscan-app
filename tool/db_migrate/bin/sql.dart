/// Jalankan SQL sekali jalan terhadap database, cetak hasil atau error lengkap.
///
///   dart run bin/sql.dart "select 1"
///   dart run bin/sql.dart --file=periksa.sql
///
/// Memakai variabel lingkungan yang sama dengan migrate.dart.
library;

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Pemakaian: dart run bin/sql.dart "<sql>" | --file=<path>');
    exit(2);
  }

  final sql = args.first.startsWith('--file=')
      ? File(args.first.substring(7)).readAsStringSync()
      : args.join(' ');

  final env = Platform.environment;
  final conn = await Connection.open(
    Endpoint(
      host: env['SUPABASE_DB_HOST']!,
      port: int.tryParse(env['SUPABASE_DB_PORT'] ?? '') ?? 5432,
      database: env['SUPABASE_DB_NAME'] ?? 'postgres',
      username: env['SUPABASE_DB_USER'],
      password: env['SUPABASE_DB_PASSWORD'],
    ),
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );

  try {
    final rows = await conn.execute(sql, queryMode: QueryMode.simple);
    for (final r in rows) {
      stdout.writeln(r.map((c) => c ?? 'NULL').join('  |  '));
    }
    stdout.writeln('(${rows.length} baris)');
  } on ServerException catch (e) {
    // toString() sudah memuat pesan, kode, detail, hint, dan lokasi sekaligus.
    stderr.writeln('SQL ERROR\n$e');
    exitCode = 1;
  } on Object catch (e) {
    stderr.writeln('ERROR: $e');
    exitCode = 1;
  } finally {
    await conn.close();
  }
}
