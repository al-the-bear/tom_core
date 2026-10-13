/// Optimistic locking with `@TomVersion`, step by step, without a database.
///
/// Run with
/// `dart run example/object_persistence/optimistic_locking_example.dart`.
///
/// A versioned entity's update names the version it was loaded with in its
/// `WHERE` clause, so once somebody else's save has moved the version the
/// statement matches no row and the repository throws a
/// `TomOptimisticLockException` (`crud_repository.save.version_conflict`)
/// instead of writing. Everything that decides that is visible without a
/// database — which field is the version, the statement a save prepares, and
/// the migration that adds the column — and this example shows it. The round
/// trip itself, two saves of one row with the second refused, runs against
/// MariaDB in `test/optimistic_locking_db_test.dart`. Every step checks its own
/// result, and the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import 'object_persistence_entities.dart';

void main() {
  initializeReflection();

  // 1. `@TomVersion` marks the field; the analyzer finds it.
  final version = TomAnnotationAnalyzer.findVersionColumn(ExampleArticle);
  print('1. version column           : ${version?.getQueryFieldName()}');
  check(
    version?.declaredName == 'version',
    'the annotated field is the version',
  );

  // 2. An entity without one is saved and deleted unchecked.
  final unversioned = TomAnnotationAnalyzer.findVersionColumn(
    ExampleClaimRecord,
  );
  print('2. claim is versioned       : ${unversioned != null}');
  check(unversioned == null, 'versioning is opt-in per entity');

  // 3. A versioned update matches its row only at the version the caller
  //    loaded, and writes the next one.
  final columns = TomAnnotationAnalyzer.getPersistentColumns(ExampleArticle)!;
  final (sql, parameters) = TomSqlDatasourceRepository.buildUpdateStatement(
    'example_article',
    [
      for (final c in columns)
        if (!(c.column?.isReadOnly ?? false)) c,
    ],
    [columns.firstWhere((c) => c.entityId != null)],
    version: version,
  );
  print('3. update                   : $sql');
  check(
    sql.endsWith(
      'WHERE id = :id AND version = '
      ':${TomSqlDatasourceRepository.versionParameter}',
    ),
    'the stored version is part of what the update matches',
  );
  check(
    parameters.last == TomSqlDatasourceRepository.versionParameter,
    'the expected version binds last, after the key',
  );

  // 4. A table that gains versioning later adds the column NOT NULL with a
  //    default: every existing row starts at 0, and its first save moves it.
  final convergence = TomSchemaConvergenceCheck(dialect: MariadbSqlDialect());
  TomSchemaConvergenceReport chain(String addColumn) => convergence.verify(
    datasource: 'unused_by_this_example',
    schema: 'wiki',
    chain: [
      TomMigrationArtifact(
        '[1]-create_example_article',
        'CREATE TABLE example_article (id BIGINT NOT NULL AUTO_INCREMENT, '
            'body TEXT NULL, PRIMARY KEY (id));',
      ),
      TomMigrationArtifact('[2]-add_version', addColumn),
    ],
    entityTypes: [ExampleArticle],
  );
  final added = chain(
    'ALTER TABLE example_article '
    'ADD COLUMN version BIGINT NOT NULL DEFAULT 0;',
  );
  print('4. NOT NULL DEFAULT 0       : ${added.errors.length} error(s)');
  check(added.errors.isEmpty, 'the migration converges with the entity');

  // 5. A nullable version is refused by the same check: NULL equals nothing,
  //    so no save of such a row could ever match.
  final nullable = chain(
    'ALTER TABLE example_article ADD COLUMN version BIGINT NULL;',
  );
  final kinds = nullable.errors.map((d) => d.kind).toList();
  print('5. NULL                     : ${kinds.map((k) => k.name).join(', ')}');
  check(
    kinds.length == 1 &&
        kinds.single == TomSchemaDivergenceKind.nullableVersionColumn,
    'a nullable version column is reported',
  );
}
