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
  final version = TomDbVersion()
    ..installedRank = 1
    ..version = 2
    ..description = 'add_orders'
    ..script = 'CREATE TABLE orders (id INT PRIMARY KEY);'
    ..checksum = '12345'
    ..success = 1;
  print('2. recorded migration:');
  print(
    '   rank=${version.installedRank} version=${version.version} '
    'description=${version.description} success=${version.success}',
  );
  assert(version.version == 2);
  assert(version.description == 'add_orders');
  assert(version.success == 1);

  // 3. The expected on-disk layout the orchestrator walks (see the module doc):
  //    <directory>/<datasourceName>/<schemaName>/[<version>]-<description>.sql
  print('3. migration file name pattern: [<version>]-<description>.<ext>');
  print('   e.g. migrations/main/app/[2]-add_orders.sql');

  print('\nDb-migration example completed.');
}

void main() {
  run();
}
