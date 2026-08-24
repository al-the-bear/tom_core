/// Tests for the CE-DB ↔ CE-MG convergence check (CSEX6): the schema model, the
/// DDL replay, the entity-model reduction, and the diff that reports where the
/// two disagree.
///
/// Everything here runs **without a database** — which is the point of the
/// feature, not a convenience of the test. The expected side comes from
/// reflection over `FixtureTaskRecord`, the actual side from replaying SQL text,
/// and the two fixture chains under `test/fixtures/convergence/` are read from
/// disk exactly as a real `<databaseMigrationsDirectory>` would be.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureNullableRecord,
        FixtureOptionalColumnRecord,
        FixtureRekeyedNullableRecord,
        FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// The converged fixture chain: builds exactly what [FixtureTaskRecord] maps.
const String convergedMigrations = 'test/fixtures/convergence/converged';

/// The deliberately divergent fixture chain — a wrong column type, a missing
/// column, and a table no entity maps.
const String divergedMigrations = 'test/fixtures/convergence/diverged';

/// The datasource and schema both fixture chains are keyed by.
const String fixtureDatasource = 'tom_core_server_test';

/// The schema directory both fixture chains live in.
const String fixtureSchema = 'fixture_schema';

TomMigrationArtifact artifact(String basename, String sql) =>
    TomMigrationArtifact(basename, sql);

void main() {
  setUpAll(initializeReflection);

  final dialect = MariadbSqlDialect();

  group('TomSqlTypeFamily classification', () {
    test('classifies the standard type names by family', () {
      final standard = TomStandardSqlDialect();
      expect(standard.typeFamily('BIGINT'), TomSqlTypeFamily.integer);
      expect(standard.typeFamily('VARCHAR(255)'), TomSqlTypeFamily.text);
      expect(standard.typeFamily('DECIMAL(10, 2)'), TomSqlTypeFamily.decimal);
      expect(standard.typeFamily('DOUBLE'), TomSqlTypeFamily.decimal);
      expect(standard.typeFamily('DATETIME'), TomSqlTypeFamily.dateTime);
      expect(standard.typeFamily('DATE'), TomSqlTypeFamily.date);
      expect(standard.typeFamily('TIME'), TomSqlTypeFamily.time);
      expect(standard.typeFamily('BLOB'), TomSqlTypeFamily.binary);
      expect(standard.typeFamily("ENUM('a','b')"), TomSqlTypeFamily.text);
    });

    test('an unknown type name is unknown rather than a guess', () {
      expect(
        TomStandardSqlDialect().typeFamily('GEOGRAPHY'),
        TomSqlTypeFamily.unknown,
      );
    });

    test('splits a type name into its base and its arguments', () {
      final standard = TomStandardSqlDialect();
      expect(standard.baseTypeName('`decimal`(10, 2)'), 'DECIMAL');
      expect(standard.typeArguments('DECIMAL(10, 2)'), ['10', '2']);
      expect(standard.typeArguments('BIGINT'), isEmpty);
      // A multi-word type ends at the space, so a trailing attribute cannot
      // reach the family lookup. `baseTypeName` and `typeArguments` are public
      // for overriding dialects, so these are documented behaviour, not
      // incidental: see doc/datasources.md, "Classifying Column Types".
      expect(standard.baseTypeName('DOUBLE PRECISION'), 'DOUBLE');
      expect(standard.baseTypeName('BIGINT UNSIGNED'), 'BIGINT');
      expect(standard.typeArguments('VARCHAR(255)'), ['255']);
      expect(standard.typeFamily('BIGINT UNSIGNED'), TomSqlTypeFamily.integer);
      expect(standard.typeFamily('DECIMAL(10,2)'), TomSqlTypeFamily.decimal);
    });

    test('MariaDB reads TINYINT(1) as a truth value, TINYINT as an int', () {
      // MariaDB has no distinct boolean storage, so a bool field is spelled
      // TINYINT(1); classifying it as an integer would report every boolean
      // column of every migration as a divergence.
      expect(dialect.typeFamily('TINYINT(1)'), TomSqlTypeFamily.boolean);
      expect(dialect.typeFamily('TINYINT'), TomSqlTypeFamily.integer);
      expect(dialect.typeFamily('TINYINT(4)'), TomSqlTypeFamily.integer);
    });
  });

  group('TomSqlTypeFamily compatibility', () {
    test('a family always accepts itself', () {
      for (final family in TomSqlTypeFamily.values) {
        expect(family.accepts(family), isTrue, reason: family.name);
      }
    });

    test('integer and boolean accept each other', () {
      expect(
        TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.boolean),
        isTrue,
      );
      expect(
        TomSqlTypeFamily.boolean.accepts(TomSqlTypeFamily.integer),
        isTrue,
      );
    });

    test('decimal accepts integer but integer does not accept decimal', () {
      // Reading a whole number as a double is lossless; declaring an int over a
      // DECIMAL column truncates, which is a real defect worth reporting.
      expect(
        TomSqlTypeFamily.decimal.accepts(TomSqlTypeFamily.integer),
        isTrue,
      );
      expect(
        TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.decimal),
        isFalse,
      );
    });

    test('unknown is compatible in both directions', () {
      expect(TomSqlTypeFamily.unknown.accepts(TomSqlTypeFamily.text), isTrue);
      expect(TomSqlTypeFamily.text.accepts(TomSqlTypeFamily.unknown), isTrue);
    });

    test('text and integer are not interchangeable', () {
      expect(TomSqlTypeFamily.integer.accepts(TomSqlTypeFamily.text), isFalse);
      expect(TomSqlTypeFamily.text.accepts(TomSqlTypeFamily.integer), isFalse);
    });
  });

  group('TomSchemaBuilder', () {
    TomSchemaColumn column(String name) => TomSchemaColumn(
      name: name,
      family: TomSqlTypeFamily.text,
      declaredType: 'VARCHAR(10)',
      origin: 'test',
    );

    test('looks tables and columns up case-insensitively', () {
      final builder = TomSchemaBuilder()
        ..addTable('Widget', 'a')
        ..addColumn('widget', column('Label'));
      final model = builder.build();
      expect(model.table('WIDGET')?.name, 'Widget');
      expect(model.table('widget')?.column('label')?.name, 'Label');
    });

    test('a rename preserves the column position and re-attributes it', () {
      final builder = TomSchemaBuilder()
        ..addTable('widget', 'a')
        ..addColumn('widget', column('one'))
        ..addColumn('widget', column('two'))
        ..addColumn('widget', column('three'))
        ..renameColumn('widget', 'two', 'second', 'b');
      final table = builder.build().table('widget')!;
      expect(table.columns.values.map((c) => c.name), [
        'one',
        'second',
        'three',
      ]);
      expect(table.column('second')?.origin, 'b');
    });

    test('dropping a table removes it entirely', () {
      final builder = TomSchemaBuilder()
        ..addTable('widget', 'a')
        ..dropTable('WIDGET');
      expect(builder.hasTable('widget'), isFalse);
      expect(builder.build().tables, isEmpty);
    });

    test('the built model is immutable', () {
      final model = (TomSchemaBuilder()..addTable('widget', 'a')).build();
      expect(() => model.tables.clear(), throwsUnsupportedError);
      expect(
        () => model.table('widget')!.primaryKey.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('TomSchemaDdlReader statement lexing', () {
    test('strips line, hash and block comments outside quotes', () {
      const sql = '''
-- leading note
SELECT 1; # trailing note
/* block */ SELECT '-- not a comment';
''';
      // Asserted as exact text, not as a count: without the strip this still
      // yields two statements — they just carry the comments along — so a
      // length-only assertion would pass whether or not stripping happened.
      final statements = TomSchemaDdlReader.splitStatements(sql);
      expect(statements, ['SELECT 1', "SELECT '-- not a comment'"]);
    });

    test('does not split on a semicolon inside a quoted literal', () {
      final statements = TomSchemaDdlReader.splitStatements(
        "INSERT INTO t VALUES ('a;b'); INSERT INTO t VALUES ('c');",
      );
      expect(statements, hasLength(2));
      expect(statements.first, contains("'a;b'"));
    });

    // The reader's own scanners used to treat a backslash as an escape inside
    // *every* quote character, which is wrong for backtick identifiers: the
    // closing backtick got swallowed and both statements came back as one. The
    // scan now goes through TomSqlLexer, which distinguishes the three.
    test('does not treat a backslash in an identifier as an escape', () {
      final statements = TomSchemaDdlReader.splitStatements(
        'CREATE TABLE `bs\\` (id INT);\nSELECT 1;',
      );
      expect(statements, hasLength(2));
      expect(statements.first, contains('`bs\\`'));
      expect(statements.last, 'SELECT 1');
    });

    test('does treat a backslash in a literal as an escape', () {
      final statements = TomSchemaDdlReader.splitStatements(
        "INSERT INTO t VALUES ('it\\'s; fine');\nSELECT 1;",
      );
      expect(statements, hasLength(2));
      expect(statements.last, 'SELECT 1');
    });

    test('stripComments leaves whitespace so tokens stay apart', () {
      expect(
        TomSchemaDdlReader.stripComments('a/* x */b').trim(),
        'a b'.trim(),
      );
    });

    test('splitTopLevel keeps parenthesised groups whole', () {
      expect(
        TomSchemaDdlReader.splitTopLevel("a DECIMAL(10, 2), b ENUM('x','y')"),
        ['a DECIMAL(10, 2)', "b ENUM('x','y')"],
      );
    });

    test('splitTopLevel is not confused by a backslash in an identifier', () {
      expect(TomSchemaDdlReader.splitTopLevel('`a\\`, b INT'), [
        '`a\\`',
        'b INT',
      ]);
    });
  });

  group('TomSchemaDdlReader replay', () {
    TomSchemaModel replay(List<TomMigrationArtifact> chain) {
      final result = TomSchemaDdlReader(dialect).replay(chain);
      expect(result.errors, isEmpty, reason: '${result.errors}');
      return result.schema;
    }

    test('reads columns, types and the primary key of a CREATE TABLE', () {
      final schema = replay([
        artifact('[000]-create', '''
CREATE TABLE IF NOT EXISTS widget (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  label VARCHAR(255) NULL,
  ratio DECIMAL(10, 2) NULL,
  PRIMARY KEY (id)
);'''),
      ]);
      final table = schema.table('widget')!;
      expect(table.columns.keys, ['id', 'label', 'ratio']);
      expect(table.column('id')!.family, TomSqlTypeFamily.integer);
      expect(table.column('id')!.nullable, isFalse);
      expect(table.column('label')!.declaredType, 'VARCHAR(255)');
      expect(table.column('ratio')!.family, TomSqlTypeFamily.decimal);
      expect(table.primaryKey, ['id']);
      expect(table.origin, '[000]-create');
    });

    test('reads an inline PRIMARY KEY column modifier', () {
      final schema = replay([
        artifact(
          '[000]-create',
          'CREATE TABLE widget (id BIGINT PRIMARY KEY);',
        ),
      ]);
      expect(schema.table('widget')!.primaryKey, ['id']);
    });

    test('reads a composite PRIMARY KEY constraint', () {
      final schema = replay([
        artifact('[000]-create', '''
CREATE TABLE widget (
  owner BIGINT NOT NULL,
  slot  INT    NOT NULL,
  CONSTRAINT widget_pk PRIMARY KEY (owner, slot)
);'''),
      ]);
      expect(schema.table('widget')!.primaryKey, ['owner', 'slot']);
    });

    test('accumulates ALTER TABLE across artifacts, and attributes each', () {
      final schema = replay([
        artifact('[000]-create', 'CREATE TABLE widget (id BIGINT NOT NULL);'),
        artifact(
          '[001]-extend',
          'ALTER TABLE widget ADD COLUMN label VARCHAR(64) NULL, '
              'ADD COLUMN active TINYINT(1) NOT NULL DEFAULT 0;',
        ),
      ]);
      final table = schema.table('widget')!;
      expect(table.columns.keys, ['id', 'label', 'active']);
      expect(table.column('id')!.origin, '[000]-create');
      expect(table.column('label')!.origin, '[001]-extend');
      expect(table.column('active')!.family, TomSqlTypeFamily.boolean);
    });

    test('applies DROP, MODIFY, CHANGE and RENAME COLUMN', () {
      final schema = replay([
        artifact(
          '[000]-create',
          'CREATE TABLE widget (id BIGINT, gone INT, wide INT, old INT, gets INT);',
        ),
        artifact('[001]-drop', 'ALTER TABLE widget DROP COLUMN gone;'),
        artifact('[002]-modify', 'ALTER TABLE widget MODIFY wide VARCHAR(20);'),
        artifact('[003]-change', 'ALTER TABLE widget CHANGE old fresh BIGINT;'),
        artifact(
          '[004]-rename',
          'ALTER TABLE widget RENAME COLUMN gets TO got;',
        ),
      ]);
      final table = schema.table('widget')!;
      expect(table.column('gone'), isNull);
      expect(table.column('wide')!.family, TomSqlTypeFamily.text);
      expect(table.column('old'), isNull);
      expect(table.column('fresh')!.family, TomSqlTypeFamily.integer);
      expect(table.column('gets'), isNull);
      expect(table.column('got')!.origin, '[004]-rename');
    });

    test('applies DROP TABLE and RENAME TO', () {
      final schema = replay([
        artifact(
          '[000]-create',
          'CREATE TABLE a (id BIGINT); '
              'CREATE TABLE b (id BIGINT);',
        ),
        artifact('[001]-drop', 'DROP TABLE IF EXISTS a;'),
        artifact('[002]-rename', 'ALTER TABLE b RENAME TO c;'),
      ]);
      expect(schema.table('a'), isNull);
      expect(schema.table('b'), isNull);
      expect(schema.table('c')!.column('id'), isNotNull);
    });

    test('skips data and index statements in silence', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE widget (id BIGINT);'),
        artifact('[001]-noise', '''
INSERT INTO widget (id) VALUES (1);
UPDATE widget SET id = 2;
DELETE FROM widget;
SET @x = 1;
CREATE INDEX IF NOT EXISTS widget_idx ON widget (id);
DROP INDEX widget_idx ON widget;
CREATE OR REPLACE VIEW widget_v AS SELECT id FROM widget;
'''),
      ]);
      expect(result.errors, isEmpty);
      expect(result.schema.tables.keys, ['widget']);
    });

    test('IF NOT EXISTS makes a re-creation a no-op, not an error', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE IF NOT EXISTS w (id BIGINT);'),
        artifact('[001]-again', 'CREATE TABLE IF NOT EXISTS w (id BIGINT);'),
      ]);
      expect(result.errors, isEmpty);
      expect(result.schema.table('w')!.origin, '[000]-create');
    });

    test('an unguarded re-creation is reported as a chain defect', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE w (id BIGINT);'),
        artifact('[001]-again', 'CREATE TABLE w (id BIGINT);'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.artifact, '[001]-again');
      expect(result.errors.single.message, contains('already exists'));
    });

    test('DROP TABLE IF EXISTS tolerates a table no artifact creates', () {
      final result = TomSchemaDdlReader(
        dialect,
      ).replay([artifact('[000]-tidy', 'DROP TABLE IF EXISTS ghost;')]);
      expect(result.errors, isEmpty);
    });

    test(
      'an unguarded DROP TABLE of a table no artifact creates is reported',
      () {
        final result = TomSchemaDdlReader(
          dialect,
        ).replay([artifact('[000]-tidy', 'DROP TABLE ghost;')]);
        expect(result.errors, hasLength(1));
        expect(result.errors.single.artifact, '[000]-tidy');
        expect(result.errors.single.message, contains('ghost'));
        expect(result.errors.single.message, contains('does not have'));
      },
    );

    test('DROP TABLE drops every table it lists, not just the first', () {
      // A list left half-applied would leave `b` standing and report it as a
      // table the entity model lacks — a finding about a table the chain drops.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact(
          '[000]-create',
          'CREATE TABLE a (id BIGINT); CREATE TABLE b (id BIGINT);',
        ),
        artifact('[001]-drop', 'DROP TABLE a, b;'),
      ]);
      expect(result.errors, isEmpty);
      expect(result.schema.tables, isEmpty);
    });

    test('DROP TABLE reports each listed table the chain does not have', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE a (id BIGINT);'),
        artifact('[001]-drop', 'DROP TABLE a, ghost;'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('ghost'));
    });

    test('an unguarded DROP TABLE of a created table stays silent', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE w (id BIGINT);'),
        artifact('[001]-drop', 'DROP TABLE w;'),
      ]);
      expect(result.errors, isEmpty);
      expect(result.schema.table('w'), isNull);
    });

    test('a DROP TABLE of an already-dropped table is reported', () {
      // The chain drops it twice: the second one would fail against a real
      // server exactly as a drop of a table that never existed would.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE w (id BIGINT);'),
        artifact('[001]-drop', 'DROP TABLE w;'),
        artifact('[002]-drop-again', 'DROP TABLE w;'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.artifact, '[002]-drop-again');
    });

    test('ADD COLUMN IF NOT EXISTS tolerates a column the baseline has', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE w (id BIGINT, tag VARCHAR(8));'),
        artifact(
          '[001]-catchup',
          'ALTER TABLE w ADD COLUMN IF NOT EXISTS tag VARCHAR(8) NULL;',
        ),
      ]);
      expect(result.errors, isEmpty);
      // The baseline's definition wins — the guarded add is a no-op.
      expect(result.schema.table('w')!.column('tag')!.origin, '[000]-create');
    });

    test('an unguarded duplicate column is reported', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-create', 'CREATE TABLE w (id BIGINT, tag VARCHAR(8));'),
        artifact('[001]-dup', 'ALTER TABLE w ADD COLUMN tag VARCHAR(8);'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('already exists'));
    });

    test('an ALTER on a table no artifact creates is reported', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-alter', 'ALTER TABLE ghost ADD COLUMN x INT;'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('no earlier artifact'));
    });

    test('an unsupported statement is reported rather than mis-parsed', () {
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-routine', 'CREATE PROCEDURE p() BEGIN SELECT 1; END'),
      ]);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.message, contains('Unsupported statement'));
    });

    test('reporting continues past a failing artifact', () {
      // A throw would stop at the first defect and hide everything after it,
      // which is the opposite of what a convergence report is for.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-alter', 'ALTER TABLE ghost ADD COLUMN x INT;'),
        artifact('[001]-create', 'CREATE TABLE widget (id BIGINT);'),
      ]);
      expect(result.errors, hasLength(1));
      expect(result.schema.table('widget'), isNotNull);
    });
  });

  group('TomEntitySchemaReader', () {
    test('reduces the entity model to tables, columns, families and key', () {
      final expected = TomEntitySchemaReader.read([FixtureTaskRecord]);
      expect(expected.divergences, isEmpty);
      final table = expected.schema.table('fixture_task')!;
      expect(table.origin, 'FixtureTaskRecord');
      expect(table.columns.keys.toSet(), {'id', 'title', 'priority', 'done'});
      expect(table.column('id')!.family, TomSqlTypeFamily.integer);
      expect(table.column('title')!.family, TomSqlTypeFamily.text);
      expect(table.column('priority')!.family, TomSqlTypeFamily.integer);
      expect(table.column('done')!.family, TomSqlTypeFamily.boolean);
      expect(table.primaryKey, ['id']);
    });

    test('selects entities by datasource, ignoring the rest', () {
      expect(
        TomEntitySchemaReader.selectFor(
          [FixtureTaskRecord],
          fixtureDatasource,
          fixtureSchema,
        ),
        [FixtureTaskRecord],
      );
      expect(
        TomEntitySchemaReader.selectFor(
          [FixtureTaskRecord],
          'some_other_datasource',
          fixtureSchema,
        ),
        isEmpty,
      );
    });

    test('discovers every @TomDbTable type known to the reflector', () {
      expect(
        TomEntitySchemaReader.discoverEntityTypes(),
        contains(FixtureTaskRecord),
      );
    });

    test('two projections of one table that agree on the key merge', () {
      // FixtureNullableRecord and FixtureOptionalColumnRecord map the same
      // `fixture_nullable` table under two member shapes, both keyed by `id`.
      // Reading a table through more than one projection is legitimate, so
      // this is not a finding.
      final expected = TomEntitySchemaReader.read([
        FixtureNullableRecord,
        FixtureOptionalColumnRecord,
      ]);
      expect(expected.divergences, isEmpty);
      final table = expected.schema.table('fixture_nullable')!;
      expect(table.origin, 'FixtureNullableRecord');
      expect(table.primaryKey, ['id']);
    });

    test(
      'a second projection that keys the table differently is a finding',
      () {
        final expected = TomEntitySchemaReader.read([
          FixtureNullableRecord,
          FixtureRekeyedNullableRecord,
        ]);
        final conflict = expected.divergences.single;
        expect(
          conflict.kind,
          TomSchemaDivergenceKind.conflictingEntityPrimaryKey,
        );
        expect(conflict.table, 'fixture_nullable');
        expect(conflict.isError, isTrue);
        // Both entities have to be named: the reader has to know which two
        // declarations to reconcile, and neither alone identifies the pair.
        expect(
          conflict.origin,
          'FixtureNullableRecord vs FixtureRekeyedNullableRecord',
        );
        expect(conflict.message, contains('(id)'));
        expect(conflict.message, contains('(name)'));
      },
    );

    test('the first entity to declare the table keeps the key and origin', () {
      final table = TomEntitySchemaReader.read([
        FixtureNullableRecord,
        FixtureRekeyedNullableRecord,
      ]).schema.table('fixture_nullable')!;
      expect(table.origin, 'FixtureNullableRecord');
      // Not the second declarer's key, and not a union of the two: a union
      // would put a key in the model that neither entity declares, and every
      // downstream comparison would run against a shape nobody wrote.
      expect(table.primaryKey, ['id']);
    });

    test('the contradiction is reported whichever entity is read first', () {
      final reversed = TomEntitySchemaReader.read([
        FixtureRekeyedNullableRecord,
        FixtureNullableRecord,
      ]);
      expect(
        reversed.divergences.single.kind,
        TomSchemaDivergenceKind.conflictingEntityPrimaryKey,
      );
      // The verdict is order-independent. Which key survives is not, and is
      // not meant to be — it follows the origin, so the reported table and the
      // reported key always describe the same entity.
      final table = reversed.schema.table('fixture_nullable')!;
      expect(table.origin, 'FixtureRekeyedNullableRecord');
      expect(table.primaryKey, ['name']);
    });
  });

  group('TomSchemaConvergenceCheck', () {
    final check = TomSchemaConvergenceCheck(dialect: dialect);

    test('the check has a stable name a validator can register', () {
      expect(TomSchemaConvergenceCheck.checkName, 'ce-mg.schema-convergence');
    });

    test(
      'a converged chain reports agreement with no findings at all',
      () async {
        final report = await check.checkSchema(
          convergedMigrations,
          fixtureDatasource,
          fixtureSchema,
          entityTypes: [FixtureTaskRecord],
        );
        expect(report.converged, isTrue, reason: report.describe());
        expect(report.divergences, isEmpty, reason: report.describe());
        expect(report.describe(), contains('converged'));
      },
    );

    test(
      'the chain is environment-filtered exactly as the engine filters it',
      () async {
        // Under the production-safe default only the two untagged artifacts are
        // in the chain; under `dev` the tagged seed joins them and — being data —
        // still leaves the schema unchanged.
        final production = await check.checkSchema(
          convergedMigrations,
          fixtureDatasource,
          fixtureSchema,
          entityTypes: [FixtureTaskRecord],
        );
        expect(production.chain, [
          '[000]-create_fixture_task',
          '[001]-add_task_flags',
        ]);

        final development = TomSchemaConvergenceCheck(
          dialect: dialect,
          environment: 'dev',
        );
        final report = await development.checkSchema(
          convergedMigrations,
          fixtureDatasource,
          fixtureSchema,
          entityTypes: [FixtureTaskRecord],
        );
        expect(report.chain, hasLength(3));
        expect(report.chain.last, '[002]-fixture_seed@dev');
        expect(report.converged, isTrue, reason: report.describe());
      },
    );

    test('a divergent chain localises every disagreement', () async {
      final report = await check.checkSchema(
        divergedMigrations,
        fixtureDatasource,
        fixtureSchema,
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.converged, isFalse);

      final missing = report.errors.singleWhere(
        (d) => d.kind == TomSchemaDivergenceKind.missingColumn,
      );
      expect(missing.subject, 'fixture_task.done');
      expect(missing.origin, contains('FixtureTaskRecord'));
      // The locality has to name the artifact to act on, not just the table.
      expect(missing.message, contains('[000]-create_fixture_task'));

      final mismatch = report.errors.singleWhere(
        (d) => d.kind == TomSchemaDivergenceKind.columnTypeMismatch,
      );
      expect(mismatch.subject, 'fixture_task.priority');
      expect(mismatch.message, contains('VARCHAR(32)'));
      expect(mismatch.message, contains('[000]-create_fixture_task'));

      // The unmapped table is knowledge, not a defect: audit and join tables
      // legitimately have no entity.
      final unexpected = report.warnings.singleWhere(
        (d) => d.kind == TomSchemaDivergenceKind.unexpectedTable,
      );
      expect(unexpected.table, 'fixture_audit');
      expect(unexpected.origin, '[001]-create_fixture_audit');
      expect(report.errors, hasLength(2));
      expect(report.describe(), contains('DIVERGED'));
    });

    test('a table no artifact creates is a missing-table error', () {
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: const [],
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.converged, isFalse);
      final missing = report.errors.single;
      expect(missing.kind, TomSchemaDivergenceKind.missingTable);
      expect(missing.table, 'fixture_task');
      expect(missing.origin, 'FixtureTaskRecord');
    });

    test('a differing primary key is reported once, per table', () {
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: [
          artifact('[000]-create', '''
CREATE TABLE fixture_task (
  id       BIGINT       NOT NULL,
  title    VARCHAR(255) NULL,
  priority INT          NULL,
  done     TINYINT(1)   NULL,
  PRIMARY KEY (title)
);'''),
        ],
        entityTypes: [FixtureTaskRecord],
      );
      final mismatch = report.errors.single;
      expect(mismatch.kind, TomSchemaDivergenceKind.primaryKeyMismatch);
      expect(mismatch.message, contains('(id)'));
      expect(mismatch.message, contains('(title)'));
    });

    test('an entity model that contradicts itself fails the report', () {
      // The chain builds exactly what FixtureNullableRecord declares, key
      // included — so the only thing wrong here is the entity model's own
      // disagreement, and the report has to say so rather than converge.
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: [
          artifact('[000]-create', '''
CREATE TABLE fixture_nullable (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(255) NULL,
  ratio       DOUBLE       NULL,
  quantity    INT          NULL,
  active      TINYINT(1)   NULL,
  occurred_at DATETIME     NULL,
  PRIMARY KEY (id)
);'''),
        ],
        entityTypes: [FixtureNullableRecord, FixtureRekeyedNullableRecord],
      );
      expect(report.converged, isFalse, reason: report.describe());
      final conflict = report.errors.single;
      expect(
        conflict.kind,
        TomSchemaDivergenceKind.conflictingEntityPrimaryKey,
      );
      expect(conflict.table, 'fixture_nullable');
    });

    test('a column the entity does not map is a warning, not an error', () {
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: [
          artifact('[000]-create', '''
CREATE TABLE fixture_task (
  id       BIGINT       NOT NULL AUTO_INCREMENT,
  title    VARCHAR(255) NULL,
  priority INT          NULL,
  done     TINYINT(1)   NULL,
  audited  TINYINT(1)   NULL,
  PRIMARY KEY (id)
);'''),
        ],
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.converged, isTrue, reason: report.describe());
      final unmapped = report.warnings.single;
      expect(unmapped.kind, TomSchemaDivergenceKind.unmappedColumn);
      expect(unmapped.subject, 'fixture_task.audited');
    });

    test('a replay failure surfaces as a chain error on the report', () {
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: [
          artifact('[000]-routine', 'CREATE PROCEDURE p() BEGIN SELECT 1; END'),
        ],
        entityTypes: [FixtureTaskRecord],
      );
      expect(
        report.errors.map((d) => d.kind),
        contains(TomSchemaDivergenceKind.chainError),
      );
      expect(
        report.errors
            .firstWhere((d) => d.kind == TomSchemaDivergenceKind.chainError)
            .origin,
        '[000]-routine',
      );
    });

    test('a column length divergence is deliberately not reported', () {
      // The entity model declares no length, so comparing one would be an
      // invention. This pins the documented comparison scope.
      final report = check.verify(
        datasource: fixtureDatasource,
        schema: fixtureSchema,
        chain: [
          artifact('[000]-create', '''
CREATE TABLE fixture_task (
  id       BIGINT      NOT NULL AUTO_INCREMENT,
  title    VARCHAR(16) NOT NULL,
  priority INT         NULL,
  done     TINYINT(1)  NULL,
  PRIMARY KEY (id)
);'''),
        ],
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.converged, isTrue, reason: report.describe());
      expect(report.divergences, isEmpty);
    });

    test(
      'checkAll walks the whole tree and reports per datasource/schema',
      () async {
        final reports = await check.checkAll(
          convergedMigrations,
          entityTypes: [FixtureTaskRecord],
        );
        expect(reports, hasLength(1));
        expect(reports.single.datasource, fixtureDatasource);
        expect(reports.single.schema, fixtureSchema);
        expect(reports.single.converged, isTrue);
      },
    );

    test(
      'a missing migrations directory yields no reports rather than throwing',
      () async {
        expect(
          await check.checkAll('test/fixtures/convergence/absent'),
          isEmpty,
        );
      },
    );

    test('a malformed artifact name is rejected by the shared parser', () {
      // The check reads names through TomDbMigrations, so a name the engine
      // would reject cannot be quietly tolerated here.
      expect(
        () => TomDbMigrations.parseMigrationFileName('001-no_brackets'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });
}
