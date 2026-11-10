/// Executable example for the migration lock, the repair of a failed
/// migration and the rollback of applied ones, in the database-migration
/// module of `tom_core_server`.
///
/// Demonstrates the half of them that runs without a database:
///
///  1. the name of a database's migration lock
///     ([TomSqlMigrationAdaptor.migrationLockName]), and how a database name
///     too long for MariaDB's 64-character lock names is folded into it;
///  2. how long a run waits for another process's run
///     ([TomSqlMigrationAdaptor.lockWait]);
///  3. the two repair actions and the command-line options that choose them
///     ([TomMigrationRepair], [TomDbMigrations.repairMigrationOption],
///     [TomDbMigrations.repairActionOption]);
///  4. a start without a repair request: [TomDbMigrations.repairFromArgs]
///     answers `false` and the server goes on to migrate;
///  5. malformed repair requests, refused with
///     `db_migration.repair.invalid_arguments` before any data source is
///     looked up;
///  6. down scripts: `[3]-add_column.down.sql` undoes `[3]-add_column.sql`
///     ([TomDbMigrations.isDownMigration],
///     [TomDbMigrations.collectDownMigrationFiles]), and the forward run's
///     [TomDbMigrations.collectMigrationFiles] does not see them;
///  7. a start without a rollback request: [TomDbMigrations.rollbackFromArgs]
///     answers `false`;
///  8. malformed rollback requests, refused with
///     `db_migration.rollback.invalid_arguments` before any data source is
///     looked up.
///
/// Taking the lock, repairing a record and rolling migrations back need a
/// registered data source and a live server; `doc/db_migration.md` describes
/// them, and `test/db_migration_lock_db_test.dart` and
/// `test/db_migration_rollback_db_test.dart` run them against one.
///
/// Run with `dart run example/db_migration/db_migration_repair_example.dart`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The key [TomDbMigrations.repairFromArgs] refuses [args] with, or `null`
/// when it accepted them.
Future<String?> _refusalOf(List<String> args) async {
  try {
    await TomDbMigrations.repairFromArgs(args);
    return null;
  } on TomDbMigrationException catch (e) {
    return e.key;
  }
}

/// The key [TomDbMigrations.rollbackFromArgs] refuses [args] with, or `null`
/// when it accepted them.
Future<String?> _rollbackRefusalOf(List<String> args) async {
  try {
    await TomDbMigrations.rollbackFromArgs(args, 'migrations');
    return null;
  } on TomDbMigrationException catch (e) {
    return e.key;
  }
}

Future<void> run() async {
  // 1. The lock is named by database: two databases on one MariaDB server
  //    migrate side by side, two processes migrating one database take turns.
  final short = TomSqlMigrationAdaptor.migrationLockName('app_db');
  final long = TomSqlMigrationAdaptor.migrationLockName('tenant_' * 12);
  print('1. migration lock names');
  print('   app_db -> $short');
  print('   an 84-character database name -> $long (${long.length} chars)');
  check(
    short == 'tom_db_migration:app_db',
    'a short database name is carried in the lock name as it is',
  );
  check(
    long.length == 64 && long.startsWith('tom_db_migration:'),
    'a long database name is hashed to fit MariaDB\'s 64-character limit',
  );
  check(
    long == TomSqlMigrationAdaptor.migrationLockName('tenant_' * 12),
    'every process derives the same name for the same database',
  );

  // 2. A process finding the lock held waits for the holder's run to finish.
  //    The bound is generous: the holder is migrating, and a dead holder
  //    releases at once because the database ends its session.
  print(
    '2. a run waits up to ${TomSqlMigrationAdaptor.lockWait.inMinutes} '
    'minutes for another process\'s run',
  );
  check(
    TomSqlMigrationAdaptor.lockWait == const Duration(minutes: 10),
    'the default wait is ten minutes',
  );

  // 3. Repair never runs a script. `remove` deletes the failed record, so the
  //    next run applies the migration again; `markResolved` (`resolve` on the
  //    command line) marks it applied, so the next run skips it.
  print(
    '3. repair actions: '
    '${TomMigrationRepair.values.map((a) => a.name).join(', ')}',
  );
  print(
    '   --${TomDbMigrations.repairMigrationOption}='
    '<datasource>/<schema>/<version> '
    '--${TomDbMigrations.repairActionOption}=remove|resolve',
  );
  check(
    TomMigrationRepair.values.length == 2,
    'there are exactly two ways to resolve a failed record',
  );

  // 4. A start script calls repairFromArgs once its data sources are
  //    registered. Without the repair option it does nothing.
  final repaired = await TomDbMigrations.repairFromArgs(['port=8080']);
  print('4. a start without a repair request: repairFromArgs -> $repaired');
  check(!repaired, 'without --repair-migration nothing is repaired');

  // 5. A request it cannot read is refused before anything is looked up —
  //    which is why these run with no data source registered at all. Each
  //    refusal is also logged, as every orchestration failure of the module
  //    is: the ERROR lines printed above each answer are that log.
  print('5. malformed repair requests');
  for (final args in [
    // The flat form of a system target: it needs its `system/` prefix.
    ['--repair-migration=app_db/app_schema/7', '--repair-action=remove'],
    [
      '--repair-migration=system/app_db/app_schema/seven',
      '--repair-action=remove',
    ],
    ['--repair-migration=tenant:/app_db/7', '--repair-action=remove'],
    ['--repair-migration=system/app_db/app_schema/7', '--repair-action=rerun'],
    ['--repair-migration=system/app_db/app_schema/7'],
  ]) {
    final key = await _refusalOf(args);
    print('   ${args.join(' ')} -> $key');
    check(
      key == 'db_migration.repair.invalid_arguments',
      'a malformed request is refused with its own key',
    );
  }

  // 6. A down script sits beside the migration it undoes and carries its
  //    basename plus `.down`, environment tag included. The forward run never
  //    sees it; a rollback finds it by the migration's basename.
  print('6. down scripts');
  final dir = await Directory.systemTemp.createTemp('tom_db_migration_down_');
  try {
    for (final name in [
      '[1]-create_customer.sql',
      '[2]-add_email.sql',
      '[2]-add_email.down.sql',
      '[3]-seed@dev.sql',
      '[3]-seed@dev.down.sql',
    ]) {
      File(p.join(dir.path, name)).writeAsStringSync('-- $name\n');
    }
    final entries = dir.listSync();
    final ups = TomDbMigrations.collectMigrationFiles(entries);
    final downs = TomDbMigrations.collectDownMigrationFiles(entries);
    print('   migrations: ${(ups.keys.toList()..sort()).join(', ')}');
    print(
      '   down scripts: ${(downs.keys.toList()..sort()).map((k) => '$k <- '
          '${p.basename(downs[k]!.path)}').join(', ')}',
    );
    check(
      TomDbMigrations.isDownMigration('[2]-add_email.down') &&
          !TomDbMigrations.isDownMigration('[2]-add_email'),
      'a down script is recognised by its `.down` suffix',
    );
    check(
      ups.length == 3 && ups.keys.every((k) => !k.endsWith('.down')),
      'the forward run collects the three migrations and no down script',
    );
    check(
      downs.keys.toSet().containsAll(['[2]-add_email', '[3]-seed@dev']) &&
          downs.length == 2,
      'each down script is keyed by the migration it undoes, tag included',
    );
    check(
      !downs.containsKey('[1]-create_customer'),
      'a migration without a down script cannot be rolled back',
    );
  } finally {
    await dir.delete(recursive: true);
  }

  // 7. A start script calls rollbackFromArgs beside repairFromArgs. Without
  //    the rollback option it does nothing.
  final rolledBack = await TomDbMigrations.rollbackFromArgs([
    'port=8080',
  ], 'migrations');
  print(
    '7. a start without a rollback request: rollbackFromArgs -> $rolledBack',
  );
  check(!rolledBack, 'without --rollback-migrations nothing is rolled back');

  // 8. `--rollback-migrations=system/<datasource>/<schema>/<version>` — or
  //    `tenant:<id>/<datasource>/<version>` — keeps the migrations up to
  //    <version> (-1 for none). A request it cannot read is refused before
  //    any data source is looked up.
  print('8. malformed rollback requests');
  for (final args in [
    ['--${TomDbMigrations.rollbackMigrationsOption}=app_db/app_schema/2'],
    [
      '--${TomDbMigrations.rollbackMigrationsOption}=system/app_db/app_schema/two',
    ],
    ['--${TomDbMigrations.rollbackMigrationsOption}=tenant:acme/app_db'],
  ]) {
    final key = await _rollbackRefusalOf(args);
    print('   ${args.join(' ')} -> $key');
    check(
      key == 'db_migration.rollback.invalid_arguments',
      'a malformed rollback request is refused with its own key',
    );
  }

  print('\nMigration repair example completed.');
}

Future<void> main() => run();
