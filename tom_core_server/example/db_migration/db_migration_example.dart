/// Executable example for the database-migration module of `tom_core_server`.
///
/// Demonstrates the connection-free surface, which is most of the module:
///
///  1. binding a migrator to a data-source type ([TomDbMigrationAdaptor]);
///  2. the recorded row and its content digest ([TomDbVersion],
///     [MariadbMigrationAdaptor.checksumOf]);
///  3. the file-name grammar, parsed rather than printed
///     ([TomDbMigrations.parseMigrationFileName]);
///  4. environment tags ([TomMigrationFileName.appliesInEnvironment]);
///  5. ordering on the parsed version, then selecting for an environment
///     ([TomDbMigrations.orderMigrationNames],
///     [TomDbMigrations.selectForEnvironment]);
///  6. the accumulator both sides of the convergence check build through
///     ([TomSchemaBuilder], [TomSchemaColumn], [TomSchemaModel]);
///  7. splitting a script into statements ([TomSqlLexer.splitStatements]);
///  8. replaying a migration chain into a schema ([TomSchemaDdlReader.replay]);
///  9. how tolerantly two type families compare
///     ([TomSqlTypeFamilyCompatibility.accepts]);
/// 10. a convergence report that finds a divergence
///     ([TomSchemaConvergenceCheck.verify]).
///
/// Two things genuinely need more than a Dart VM and are therefore described in
/// `doc/db_migration.md` instead of run here. The orchestrator
/// ([TomDbMigrations.migrateDatabases]) and the MariaDB adaptor's
/// [TomDbMigrator] half need a registered data source and a live server; and
/// the *entity* side of the convergence check reads `@TomDbTable` types out of
/// `tomReflector`, so it needs a generated reflection root. Step 10 therefore
/// runs [TomSchemaConvergenceCheck.verify] with no entity types at all, which
/// is a legitimate call and reports honestly: every table the chain creates is
/// unmapped, because nothing was offered to map it.
///
/// Run with `dart run example/db_migration/db_migration_example.dart`.
/// `test/db_migration_test.dart` runs this file under exactly that command and
/// requires it to exit 0 having printed every numbered step and no others, so
/// what is printed below is what the module currently does rather than what it
/// did when this was written.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

void run() {
  // 1. A migrator is bound to a data-source type by the @TomDbMigrationAdaptor
  //    annotation; the orchestrator matches it against TomDataSourceInfo.type.
  const adaptor = TomDbMigrationAdaptor('mariadb');
  print('1. adaptor type: ${adaptor.type}');
  check(
    adaptor.type == 'mariadb',
    'the annotation carries its data-source type',
  );

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
  print('2. recorded migration');
  print(
    '   rank=${version.installedRank} version=${version.version} '
    'description=${version.description} success=${version.success}',
  );
  print('   checksum=${version.checksum}');
  //    An edited script no longer matches the recorded checksum, which is how
  //    `applyMigration` refuses to re-run a migration that was changed after
  //    the fact.
  final edited = '$script\n-- edited after the fact';
  print(
    '   an edited script still matches? '
    '${MariadbMigrationAdaptor.checksumOf(edited) == version.checksum}',
  );
  check(
    version.checksum ==
        '9ad9167cb37c929c8f439bcc29682d4f4b6a963310c983d1bdd35ebc21634483',
    'the digest of a given script is stable across processes',
  );
  check(
    MariadbMigrationAdaptor.checksumOf(edited) != version.checksum,
    'editing a script changes its digest',
  );

  // 3. The expected on-disk layout the orchestrator walks (see the module doc):
  //    <directory>/<datasourceName>/<schemaName>/
  //      [<version>]-<description>[@<env>[,<env>...]].<ext>
  //
  //    Parsed rather than merely printed: a name this example claims is legal
  //    but the parser rejects throws here instead of misinforming a reader.
  print('3. migration file name grammar');
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

  // 4. The tag is a whitelist, and its absence is the permissive case: an
  //    untagged migration is schema, and schema goes everywhere. Getting that
  //    default the other way round would make every migration environment-
  //    scoped by omission.
  final untagged = TomDbMigrations.parseMigrationFileName('[2]-add_orders');
  final tagged = TomDbMigrations.parseMigrationFileName(
    '[3]-demo_seed@dev,test',
  );
  print(
    '4. environment tags (active environment: '
    '${TomDbMigrations.resolveActiveEnvironment()})',
  );
  for (final environment in ['prod', 'dev']) {
    print(
      '   under $environment: [2]-add_orders '
      '${untagged.appliesInEnvironment(environment) ? 'applies' : 'skipped'}, '
      '[3]-demo_seed@dev,test '
      '${tagged.appliesInEnvironment(environment) ? 'applies' : 'skipped'}',
    );
  }
  check(
    untagged.appliesInEnvironment('prod') && untagged.environments.isEmpty,
    'an untagged migration applies in every environment',
  );
  check(
    tagged.appliesInEnvironment('dev') && !tagged.appliesInEnvironment('prod'),
    'a tagged migration applies only in the environments it names',
  );

  // 5. Ordering is on the parsed integer, not the name: lexicographically
  //    '[10]-...' sorts before '[2]-...', numerically it must come after.
  //    Selection runs *last*, over an already-ordered chain, so tagging a
  //    migration never moves it — it only decides whether it is there at all.
  final ordered = TomDbMigrations.orderMigrationNames([
    '[10]-add_index',
    '[2]-add_orders',
    '[3]-demo_seed@dev,test',
  ]);
  print('5. ascending numeric version order, then environment selection');
  print('   ordered: ${ordered.map((e) => e.basename).join(', ')}');
  for (final environment in ['prod', 'dev']) {
    final selected = TomDbMigrations.selectForEnvironment(ordered, environment);
    print(
      '   under $environment: ${selected.map((e) => e.basename).join(', ')}',
    );
  }
  check(
    ordered.map((e) => e.basename).toList().indexOf('[2]-add_orders') <
        ordered.map((e) => e.basename).toList().indexOf('[10]-add_index'),
    '[2] is applied before [10] despite sorting after it by name',
  );
  check(
    TomDbMigrations.selectForEnvironment(ordered, 'prod').length == 2 &&
        TomDbMigrations.selectForEnvironment(ordered, 'dev').length == 3,
    'selection omits the tagged migration without reordering the rest',
  );

  // 6. Both halves of the convergence check are assembled through one mutable
  //    accumulator and come out as an immutable TomSchemaModel. Every mutation
  //    against a table the builder does not have is a silent no-op — deciding
  //    whether that absence is a *defect* needs the statement text, which the
  //    builder is never given, so the reader asks `hasTable` first and the
  //    answer decides whether it records an error.
  final builder = TomSchemaBuilder()..addTable('orders', 'hand-built');
  builder.addColumn(
    'orders',
    const TomSchemaColumn(
      name: 'id',
      family: TomSqlTypeFamily.integer,
      declaredType: 'INT',
      origin: 'hand-built',
      nullable: false,
    ),
  );
  builder.setPrimaryKey('orders', ['id']);
  //    ... and the same call against a table nobody created changes nothing.
  builder.addColumn(
    'invoices',
    const TomSchemaColumn(
      name: 'total',
      family: TomSqlTypeFamily.decimal,
      declaredType: 'DECIMAL(10,2)',
      origin: 'hand-built',
    ),
  );
  final TomSchemaModel built = builder.build();
  //    Lookup is case-insensitive and returns null rather than throwing, so the
  //    table type arrives nullable — the model does not pretend a name exists.
  final TomSchemaTable? orders = built.table('ORDERS');
  print('6. schema built by hand: ${built.tables.keys.join(', ')}');
  print('   orders -> $orders');
  print('   primary key: ${orders!.primaryKey.join(', ')}');
  print(
    '   addColumn on the absent "invoices" was a no-op: '
    '${builder.hasTable('invoices') ? 'no' : 'yes'}',
  );
  check(
    built.table('ORDERS') != null && built.tables.keys.single == 'orders',
    'table lookup is case-insensitive while the model keeps the spelling',
  );
  check(
    !builder.hasTable('invoices'),
    'mutating an absent table neither creates it nor throws',
  );

  // 7. A script is split on statement boundaries the *server* would see, not on
  //    semicolons: one inside a quoted run does not end a statement. This is
  //    the single scan the applier and the schema reader share, so the two can
  //    never disagree about where a statement ends.
  const seedScript =
      "INSERT INTO notes (body) VALUES ('a; not a statement break');\n"
      'ALTER TABLE notes ADD COLUMN pinned TINYINT(1);';
  final statements = TomSqlLexer.splitStatements(seedScript);
  final naive = seedScript
      .split(';')
      .where((part) => part.trim().isNotEmpty)
      .length;
  print(
    '7. statement splitting: ${statements.length} statement(s), '
    'a naive split on ";" would give $naive',
  );
  for (final statement in statements) {
    print('   $statement');
  }
  check(
    statements.length == 2,
    'a semicolon inside a string literal does not end a statement',
  );

  // 8. Replaying a chain builds the schema a fresh database would have after
  //    the engine applied it — with no database. A statement that would fail
  //    against a live server is *reported* rather than thrown, so one run
  //    surfaces every defect in the chain instead of stopping at the first.
  final chain = <TomMigrationArtifact>[
    const TomMigrationArtifact(
      '[2]-add_orders',
      'CREATE TABLE orders (id INT NOT NULL, total DECIMAL(10,2), '
          'PRIMARY KEY (id));',
    ),
    const TomMigrationArtifact(
      '[10]-add_index',
      'ALTER TABLE orders ADD COLUMN placed_at DATETIME;\n'
          'ALTER TABLE customers ADD COLUMN nickname VARCHAR(40);',
    ),
  ];
  final TomDdlReplayResult replay = TomSchemaDdlReader(
    MariadbSqlDialect(),
  ).replay(chain);
  print('8. chain replayed into a schema');
  print('   ${replay.schema.table('orders')}');
  print('   ${replay.errors.length} statement(s) could not be replayed:');
  for (final TomDdlReplayError error in replay.errors) {
    print('   $error');
  }
  check(
    replay.schema.table('orders')?.column('placed_at') != null,
    'the ALTER in the later artifact is applied to the earlier CREATE',
  );
  check(
    replay.errors.length == 1,
    'an unguarded ALTER on a table no artifact creates is reported',
  );

  // 9. The two sides speak different vocabularies — Dart types on one, SQL type
  //    names on the other — so both are reduced to a type family and the
  //    comparison asks whether the declared family *accepts* the stored one.
  //    The relation is deliberately asymmetric where losing information is:
  //    reading a whole number as a double is lossless, declaring an int over a
  //    DECIMAL column truncates.
  final dialect = MariadbSqlDialect();
  print('9. type families and how tolerantly they compare');
  print(
    '   TINYINT(1) classifies as ${dialect.typeFamily('TINYINT(1)').name}, '
    'TINYINT(4) as ${dialect.typeFamily('TINYINT(4)').name}',
  );
  print(
    '   integer accepts boolean? '
    '${TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.boolean)}',
  );
  print(
    '   decimal accepts integer? '
    '${TomSqlTypeFamily.decimal.accepts(TomSqlTypeFamily.integer)}',
  );
  print(
    '   integer accepts decimal? '
    '${TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.decimal)}',
  );
  check(
    dialect.typeFamily('TINYINT(1)') == TomSqlTypeFamily.boolean,
    "MariaDB's TINYINT(1) is a truth value",
  );
  check(
    TomSqlTypeFamily.decimal.accepts(TomSqlTypeFamily.integer) &&
        !TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.decimal),
    'the decimal/integer tolerance runs one way only',
  );

  // 10. The check itself, over the same chain. `verify` is the pure core: hand
  //     it a chain and the entity types and it computes the report with no I/O
  //     — which is why it can run here at all. No entity types are offered, so
  //     the entity side is empty and every table the chain creates reads as
  //     unmapped; that is a *warning*, since version tables and join tables
  //     legitimately have no entity. The replay failure is the error, and it is
  //     errors alone that decide `converged`.
  final TomSchemaConvergenceReport report = TomSchemaConvergenceCheck().verify(
    datasource: 'main',
    schema: 'app',
    chain: chain,
    entityTypes: const [],
  );
  print('10. convergence report');
  for (final line in report.describe().trimRight().split('\n')) {
    print('   $line');
  }
  check(!report.converged, 'a chain that cannot be replayed has not converged');
  check(
    report.errors.single.kind == TomSchemaDivergenceKind.chainError,
    'the unreplayable statement is reported as a chain error',
  );
  check(
    report.warnings.single.kind == TomSchemaDivergenceKind.unexpectedTable,
    'a table with no entity behind it is a warning, not an error',
  );

  print('\nDb-migration example completed.');
}

void main() {
  run();
}
