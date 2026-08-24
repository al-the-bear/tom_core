/// Executable example for the database-migration module of `tom_core_server`.
///
/// The orchestrator ([TomDbMigrations.migrateDatabases]) and the
/// [MariadbMigrationAdaptor] need a registered data source and a live MariaDB
/// connection, so they are described in `doc/db_migration.md` rather than run
/// here. This example shows the connection-free surface: the
/// [TomDbMigrationAdaptor] type binding and the [TomDbVersion] row type that the
/// MariaDB adaptor reads from a `<schema>_versioning` table.
///
/// Run with `dart run example/db_migration/db_migration_example.dart`.
/// The same behaviour is covered by `test/db_migration_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. A migrator is bound to a data-source type by the @TomDbMigrationAdaptor
  //    annotation; the orchestrator matches it against TomDataSourceInfo.type.
  const adaptor = TomDbMigrationAdaptor('mariadb');
  print('1. adaptor type: ${adaptor.type}');
  assert(adaptor.type == 'mariadb');

  // 2. Each applied migration becomes one TomDbVersion row. The MariaDB adaptor
  //    uses `version` + `description` + `checksum` to detect re-runs and edits.
  //    The checksum is a content digest — the same script always produces the
  //    same value, in this process and in every later one that reads the row
  //    back, which is exactly what a stability check needs.
  const script = 'CREATE TABLE orders (id INT PRIMARY KEY);';
  final version = TomDbVersion()
    ..installedRank = 1
    ..version = 2
    ..description = 'add_orders'
    ..script = script
    ..checksum = MariadbMigrationAdaptor.checksumOf(script)
    ..success = 1;
  print('2. recorded migration:');
  print(
    '   rank=${version.installedRank} version=${version.version} '
    'description=${version.description} success=${version.success}',
  );
  print('   checksum=${version.checksum}');
  assert(version.version == 2);
  assert(version.description == 'add_orders');
  assert(version.success == 1);
  assert(
    version.checksum ==
        '9ad9167cb37c929c8f439bcc29682d4f4b6a963310c983d1bdd35ebc21634483',
  );

  // 2b. An edited script no longer matches the recorded checksum, which is how
  //     `applyMigration` refuses to re-run a migration that was changed after
  //     the fact.
  final edited = '$script\n-- edited after the fact';
  print(
    '2b. edited script still matches? '
    '${MariadbMigrationAdaptor.checksumOf(edited) == version.checksum}',
  );
  assert(MariadbMigrationAdaptor.checksumOf(edited) != version.checksum);

  // 3. The expected on-disk layout the orchestrator walks (see the module doc):
  //    <directory>/<datasourceName>/<schemaName>/
  //      [<version>]-<description>[@<env>[,<env>...]].<ext>
  //
  //    Parsed rather than merely printed: a name this example claims is legal
  //    but the parser rejects throws here instead of misinforming a reader.
  print('3. migration file name grammar:');
  print('   [<version>]-<description>[@<env>[,<env>...]].<anyfileextension>');
  for (final basename in ['[2]-add_orders', '[3]-demo_seed@dev,test']) {
    final parsed = TomDbMigrations.parseMigrationFileName(basename);
    final tag = parsed.environments.isEmpty
        ? 'every environment'
        : parsed.environments.join('/');
    print(
      '   $basename -> version=${parsed.version} '
      'description=${parsed.description} applies in: $tag',
    );
  }

  // 4. Ordering is on the parsed integer, not the name: lexicographically
  //    '[10]-...' sorts before '[2]-...', numerically it must come after.
  final ordered = TomDbMigrations.orderMigrationNames([
    '[10]-add_index',
    '[2]-add_orders',
  ]).map((e) => e.basename).toList();
  print('4. applied in ascending numeric version order: ${ordered.join(', ')}');
  assert(ordered.first == '[2]-add_orders');

  print('\nDb-migration example completed.');
}

void main() {
  run();
}
