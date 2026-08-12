/// Pemeriksa keadaan database setelah migrasi (Bab 5).
///
/// Memakai variabel lingkungan yang sama dengan migrate.dart.
library;

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main() async {
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

  Future<void> show(String label, String sql) async {
    final rows = await conn.execute(sql, queryMode: QueryMode.simple);
    stdout.writeln('\n=== $label ===');
    for (final r in rows) {
      stdout.writeln('  ${r.map((c) => c ?? 'NULL').join('  |  ')}');
    }
    if (rows.isEmpty) stdout.writeln('  (kosong)');
  }

  await show('Tabel', '''
    select table_name from information_schema.tables
     where table_schema='public' and table_type='BASE TABLE'
     order by table_name;
  ''');

  await show('Tabel TANPA RLS (harus kosong selain schema_migrations)', '''
    select c.relname from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
     order by 1;
  ''');

  await show('Jumlah policy RLS per tabel', '''
    select tablename, count(*) from pg_policies
     where schemaname='public' group by 1 order by 1;
  ''');

  await show('Enum', '''
    select t.typname, count(e.enumlabel)
      from pg_type t join pg_enum e on e.enumtypid=t.oid
      join pg_namespace n on n.oid=t.typnamespace
     where n.nspname='public' group by 1 order by 1;
  ''');

  await show('Trigger', '''
    select event_object_table, trigger_name
      from information_schema.triggers
     where trigger_schema='public' order by 1,2;
  ''');

  await show('Trigger di auth.users (registrasi)', '''
    select tgname from pg_trigger
     where tgrelid='auth.users'::regclass and not tgisinternal;
  ''');

  await show('Fungsi bantu', '''
    select routine_name from information_schema.routines
     where routine_schema='public'
       and routine_name in ('current_tenant_id','current_app_role','is_admin',
                            'is_owner','normalize_email','resi_exists',
                            'custom_access_token_hook','handle_new_user')
     order by 1;
  ''');

  await show('Job cron', 'select jobname, schedule from cron.job order by 1;');

  await show('platform_settings', 'select key from public.platform_settings order by 1;');

  // ::text wajib — tipe citext tidak dikenali driver dan tampil sebagai
  // UndecodedBytes bila tidak di-cast.
  await show('Uji normalize_email (Bab 7.5)', '''
    select public.normalize_email('Bu.Di+promo@Gmail.com')::text
             || '   <= alias gmail (titik & +promo dibuang)'
    union all
    select public.normalize_email('a.b+x@company.co.id')::text
             || '   <= non-gmail (titik DIPERTAHANKAN)'
    union all
    select public.normalize_email('BUDI@Example.COM')::text
             || '   <= huruf besar jadi kecil';
  ''');

  await show('FK tenants->users harus DEFERRABLE', '''
    select conname, condeferrable, condeferred
      from pg_constraint where conname='fk_tenants_owner';
  ''');

  await conn.close();
}
