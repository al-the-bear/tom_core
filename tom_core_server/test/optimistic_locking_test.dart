/// Optimistic locking without a database: which fields may be a
/// `@TomVersion`, the statement a versioned save prepares, the values it binds,
/// how a refusal reads, and the migration shape the schema-convergence check
/// accepts.
///
/// `optimistic_locking_db_test.dart` shows the behaviour against MariaDB —
/// two saves of one row, one refused. This file pins the decisions that
/// behaviour rests on, each against the answer a database would give.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureReadOnlyVersionRecord,
        FixtureTaskRecord,
        FixtureTextVersionRecord,
        FixtureTwoVersionsRecord,
        FixtureVersionedDoc,
        FixtureVersionedDocRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

void main() {
  setUpAll(initializeReflection);

  group('which field may be the version', () {
    Matcher analyzerError(String key) => throwsA(
      isA<TomAnnotationAnalyzerSyntaxException>().having(
        (e) => e.key,
        'key',
        key,
      ),
    );

    test('the @TomVersion field of a versioned entity is found', () {
      final column = TomAnnotationAnalyzer.findVersionColumn(
        FixtureVersionedDoc,
      );
      expect(column?.declaredName, 'version');
      expect(column?.getQueryFieldName(), 'version');
    });

    test('an entity without one is not versioned', () {
      expect(
        TomAnnotationAnalyzer.findVersionColumn(FixtureTaskRecord),
        isNull,
      );
    });

    test('two version fields are refused: a row has one version', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureTwoVersionsRecord,
        ),
        analyzerError('annotation_analyzer.version.more_than_one'),
      );
    });

    test('a version that is not an int is refused', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureTextVersionRecord,
        ),
        analyzerError('annotation_analyzer.version.invalid_field'),
      );
    });

    test('a read-only version is refused: it would never be written', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureReadOnlyVersionRecord,
        ),
        analyzerError('annotation_analyzer.version.invalid_field'),
      );
    });
  });

  group('the versioned update statement', () {
    test('matches the row only at the version the caller loaded', () {
      final columns = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureVersionedDoc,
      )!;
      final key = columns.where((c) => c.entityId != null).toList();
      final writable = columns
          .where((c) => !(c.column?.isReadOnly ?? false))
          .toList();
      final (sql, parameters) = TomSqlDatasourceRepository.buildUpdateStatement(
        'fixture_versioned_doc',
        writable,
        key,
        version: TomAnnotationAnalyzer.findVersionColumn(FixtureVersionedDoc),
      );
      expect(
        sql,
        'UPDATE fixture_versioned_doc SET version = :version,title = :title '
        'WHERE id = :id AND version = '
        ':${TomSqlDatasourceRepository.versionParameter}',
      );
      expect(parameters, [
        'version',
        'title',
        'id',
        TomSqlDatasourceRepository.versionParameter,
      ]);
    });

    test('an unversioned entity keeps the plain key clause', () {
      final columns = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureVersionedDoc,
      )!;
      final key = columns.where((c) => c.entityId != null).toList();
      final (sql, _) = TomSqlDatasourceRepository.buildUpdateStatement(
        'fixture_versioned_doc',
        [columns.firstWhere((c) => c.declaredName == 'title')],
        key,
      );
      expect(
        sql,
        'UPDATE fixture_versioned_doc SET title = :title WHERE id = :id',
      );
    });
  });

  group('a versioned save against a scripted database', () {
    late ScriptedDataSource scripted;

    setUp(() => scripted = registerScriptedDatasource());
    tearDown(unregisterScriptedDatasource);

    FixtureVersionedDoc doc({int? id, int? version, String title = 't'}) =>
        FixtureVersionedDoc()
          ..id = id
          ..version = version
          ..title = title;

    test('an insert binds version 1, whatever the object held', () async {
      // Every execution takes the next answer: the insert's own, then the
      // read-back.
      scripted
        ..generatedId = 7
        ..answers.addAll([
          <FixtureVersionedDoc>[],
          [doc(id: 7, version: 1)],
        ]);
      await FixtureVersionedDocRepository().save(doc(version: 99));
      expect(scripted.executions.first['version'], 1);
    });

    test('an update binds the next version and the one it expects', () async {
      // The scripted source reports no changed row for an update, which is
      // exactly what a database answers when the version moved meanwhile.
      scripted.answers.addAll([
        <FixtureVersionedDoc>[],
        [doc(id: 3, version: 5)],
      ]);
      await expectLater(
        FixtureVersionedDocRepository().save(doc(id: 3, version: 4)),
        throwsA(isA<TomOptimisticLockException>()),
      );
      final update = scripted.executions.first;
      expect(update['version'], 5);
      expect(update[TomSqlDatasourceRepository.versionParameter], 4);
      expect(
        scripted.statements.first,
        contains(
          'AND version = :${TomSqlDatasourceRepository.versionParameter}',
        ),
      );
    });

    test(
      'an update that changed no row is a conflict the caller sees',
      () async {
        // The update's own (empty) answer, then the read of what is stored.
        scripted.answers.addAll([
          <FixtureVersionedDoc>[],
          [doc(id: 3, version: 6)],
        ]);
        await expectLater(
          FixtureVersionedDocRepository().save(doc(id: 3, version: 4)),
          throwsA(
            isA<TomOptimisticLockException>()
                .having(
                  (e) => e.key,
                  'key',
                  'crud_repository.save.version_conflict',
                )
                .having((e) => e.clientThrow, 'clientThrow', isTrue)
                .having((e) => e.heldVersion, 'held', 4)
                .having((e) => e.storedVersion, 'stored', 6)
                .having((e) => e.parameters?['id'], 'id', '3'),
          ),
        );
      },
    );

    test(
      'a conflict on a row that is gone reports no stored version',
      () async {
        await expectLater(
          FixtureVersionedDocRepository().save(doc(id: 3, version: 4)),
          throwsA(
            isA<TomOptimisticLockException>()
                .having((e) => e.storedVersion, 'stored', isNull)
                .having(
                  (e) => e.defaultUserMessage,
                  'message',
                  contains('deleted'),
                ),
          ),
        );
      },
    );

    test('an update carrying no version runs no statement', () async {
      await expectLater(
        FixtureVersionedDocRepository().save(doc(id: 3)),
        throwsA(
          isA<TomRepositoryException>()
              .having(
                (e) => e.key,
                'key',
                'crud_repository.save.version_missing',
              )
              .having((e) => e.clientThrow, 'clientThrow', isTrue),
        ),
      );
      expect(scripted.executions, isEmpty);
    });

    test('a delete that removed no row is a conflict too', () async {
      scripted.answers.addAll([
        <FixtureVersionedDoc>[],
        [doc(id: 3, version: 9)],
      ]);
      await expectLater(
        FixtureVersionedDocRepository().delete(doc(id: 3, version: 8)),
        throwsA(
          isA<TomOptimisticLockException>()
              .having(
                (e) => e.key,
                'key',
                'crud_repository.delete.version_conflict',
              )
              .having((e) => e.storedVersion, 'stored', 9),
        ),
      );
      expect(
        scripted.executions.first[TomSqlDatasourceRepository.versionParameter],
        8,
      );
    });

    test('a delete that removed the row succeeds', () async {
      scripted.affectedRows = 1;
      await FixtureVersionedDocRepository().delete(doc(id: 3, version: 8));
      expect(scripted.executions, hasLength(1));
    });

    test('a delete carrying no version is refused', () async {
      await expectLater(
        FixtureVersionedDocRepository().delete(doc(id: 3)),
        throwsA(
          isA<TomRepositoryException>().having(
            (e) => e.key,
            'key',
            'crud_repository.delete.version_missing',
          ),
        ),
      );
    });
  });

  group('the migration that adds a version column', () {
    final check = TomSchemaConvergenceCheck(dialect: MariadbSqlDialect());

    TomSchemaConvergenceReport verify(List<String> statements) => check.verify(
      datasource: 'tom_core_server_test',
      schema: 'fixture_schema',
      chain: [
        for (var i = 0; i < statements.length; i++)
          TomMigrationArtifact('[${i + 1}]-step', statements[i]),
      ],
      entityTypes: [FixtureVersionedDoc],
    );

    const createWithoutVersion =
        'CREATE TABLE fixture_versioned_doc ('
        ' id BIGINT NOT NULL AUTO_INCREMENT,'
        ' title VARCHAR(255) NULL,'
        ' PRIMARY KEY (id));';

    test('ALTER TABLE … ADD COLUMN … NOT NULL DEFAULT converges', () {
      final report = verify([
        createWithoutVersion,
        'ALTER TABLE fixture_versioned_doc '
            'ADD COLUMN version BIGINT NOT NULL DEFAULT 0;',
      ]);
      expect(report.errors, isEmpty, reason: report.describe());
    });

    test('a nullable version column is reported', () {
      final report = verify([
        createWithoutVersion,
        'ALTER TABLE fixture_versioned_doc ADD COLUMN version BIGINT NULL;',
      ]);
      expect(report.errors.map((d) => d.kind), [
        TomSchemaDivergenceKind.nullableVersionColumn,
      ], reason: report.describe());
    });

    test('a chain that never adds it is a missing column', () {
      final report = verify([createWithoutVersion]);
      expect(report.errors.map((d) => d.kind), [
        TomSchemaDivergenceKind.missingColumn,
      ]);
    });
  });
}
