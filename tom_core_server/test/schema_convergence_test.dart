/// Tests for the CE-DB ↔ CE-MG convergence check: the schema model, the
/// DDL replay, the entity-model reduction, and the diff that reports where the
/// two disagree.
///
/// Everything here runs **without a database** — which is the point of the
/// feature, not a convenience of the test. The expected side comes from
/// reflection over `FixtureTaskRecord`, the actual side from replaying SQL text,
/// and the two fixture chains under `test/fixtures/convergence/` are read from
/// disk exactly as a real `<databaseMigrationsDirectory>` would be.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
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

    // `accepts` is directional — the receiver is what the entity model declares,
    // the argument what the DDL creates — but only one pair actually exercises
    // that, and every other test above names its pairs one at a time. So a
    // second asymmetric pair could be added to the policy without a single
    // failure, and the prose describing the relation would quietly become wrong
    // in every place it is written down. This asks the whole matrix instead of a
    // list someone has to remember to extend.
    test(
      'decimal/integer is the only pair whose direction changes the answer',
      () {
        final asymmetric = <String>{};
        for (final declared in TomSqlTypeFamily.values) {
          for (final actual in TomSqlTypeFamily.values) {
            if (declared.accepts(actual) != actual.accepts(declared)) {
              asymmetric.add(([declared.name, actual.name]..sort()).join('/'));
            }
          }
        }
        expect(
          asymmetric,
          {'decimal/integer'},
          reason:
              'a new directional pair means every text describing the '
              'relation needs revisiting, starting with the tolerance table',
        );
      },
    );
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

    // The builder accumulates and never reports: a mutation naming something it
    // does not have returns with the model unchanged. The class dartdoc used to
    // claim the opposite — that each method assumed the caller had already
    // established the operation was legal — while every member below it
    // documented the no-op, so the one sentence a reader met first told them to
    // trust a precondition that was never enforced.
    //
    // Nothing in the suite pinned this either way, which is why the prose could
    // drift: a builder rewritten to throw on an unknown table would have made
    // the retired class doc true and passed. These tests decide it.
    test('every mutation on an unknown table is a silent no-op', () {
      final builder = TomSchemaBuilder()..addTable('widget', 'a');

      expect(() {
        builder
          ..addColumn('ghost', column('label'))
          ..dropColumn('ghost', 'label')
          ..renameColumn('ghost', 'label', 'caption', 'b')
          ..setPrimaryKey('ghost', ['label'])
          ..dropTable('ghost')
          ..renameTable('ghost', 'phantom');
      }, returnsNormally);

      expect(builder.hasTable('ghost'), isFalse);
      expect(builder.hasTable('phantom'), isFalse);
      expect(
        builder.build().tables.keys,
        ['widget'],
        reason:
            'a mutation on a table the builder does not have must not '
            'conjure one, and must not disturb the tables it does have',
      );
    });

    test('a column mutation naming an unknown column is a silent no-op', () {
      final builder = TomSchemaBuilder()
        ..addTable('widget', 'a')
        ..addColumn('widget', column('label'));

      expect(() {
        builder
          ..dropColumn('widget', 'ghost')
          ..renameColumn('widget', 'ghost', 'caption', 'b');
      }, returnsNormally);

      final table = builder.build().table('widget')!;
      expect(table.columns.values.map((c) => c.name), ['label']);
      expect(
        table.column('caption'),
        isNull,
        reason: 'renaming a column that is not there must not create it',
      );
    });
  });

  group('the tolerance the summary states is the tolerance the code applies', () {
    // The completion document described this relation as "symmetric where it
    // exists" directly beneath a table that listed `decimal` accepting
    // `integer` with no reverse row — while the two pairs that *are* symmetric
    // each got two rows saying so. That is the dangerous shape of wrong: it
    // invites a reader to call `accepts` on whichever side is to hand, and the
    // answer silently differs for exactly one pair.
    //
    // The summary states the same relation in prose, in two sentence forms. Both
    // are claims about `accepts`, so `accepts` should be what settles them —
    // rather than a reviewer noticing that a sentence and a switch arm disagree.
    late final String acceptsEntry;

    setUpAll(() {
      acceptsEntry = File('doc/api_reference/api_summary_db_migration.md')
          .readAsLinesSync()
          .firstWhere(
            (line) => line.startsWith('| `accepts` |'),
            orElse: () => fail('the summary no longer documents accepts'),
          );
    });

    TomSqlTypeFamily family(String name) => TomSqlTypeFamily.values.firstWhere(
      (value) => value.name == name,
      orElse: () =>
          fail('the summary names a family that does not exist: $name'),
    );

    test('every pair it calls bidirectional is accepted both ways', () {
      final claims = RegExp(
        r'`(\w+)` ↔ `(\w+)` both ways',
      ).allMatches(acceptsEntry);
      expect(
        claims,
        isNotEmpty,
        reason:
            'the summary states no bidirectional pair, so this test is '
            'reading the wrong text or the entry has been reworded',
      );
      for (final claim in claims) {
        final left = family(claim.group(1)!);
        final right = family(claim.group(2)!);
        expect(left.accepts(right), isTrue, reason: '${claim.group(0)}');
        expect(right.accepts(left), isTrue, reason: '${claim.group(0)}');
      }
    });

    test('every pair it calls one-way is refused in the other direction', () {
      final claims = RegExp(
        r'`(\w+)` accepts `(\w+)` but \*\*not\*\* the reverse',
      ).allMatches(acceptsEntry);
      expect(
        claims,
        isNotEmpty,
        reason:
            'the summary states no one-way pair, which cannot be right '
            'while the policy still has one',
      );
      for (final claim in claims) {
        final declared = family(claim.group(1)!);
        final actual = family(claim.group(2)!);
        expect(declared.accepts(actual), isTrue, reason: '${claim.group(0)}');
        expect(
          actual.accepts(declared),
          isFalse,
          reason:
              'the summary says the reverse does not hold: '
              '${claim.group(0)}',
        );
      }
    });
  });

  group('the builder documents the contract it actually has', () {
    // The retired claim outlived the code in two places at once — the class
    // dartdoc and the API summary paragraph that reproduces it — and the
    // summary carried it directly above a method table that contradicted it
    // seven times. Fixing one site and not the other leaves the reader with the
    // same contradiction, so both are checked here.
    //
    // Each site is asked two questions, because either answer alone is
    // insufficient. Stating the no-op is not enough: the retired sentence could
    // sit beside a correct one and a reader would still meet the wrong claim
    // first. Absence is not enough either — that is how the prose gets deleted
    // without a replacement, which leaves the contract undocumented rather than
    // misdocumented.
    const sites = {
      'lib/src/tomserver/db_migration/schema_model.dart':
          _builderClassDartdocOf,
      'doc/api_reference/api_summary_db_migration.md': _builderSummaryProseOf,
    };

    for (final entry in sites.entries) {
      test('${entry.key} states the no-op contract', () {
        final prose = entry.value(File(entry.key).readAsStringSync());
        expect(
          prose,
          contains('no-op'),
          reason:
              'the builder never reports, and the text a reader meets '
              'first has to say so',
        );
      });

      test('${entry.key} no longer claims the caller must pre-check', () {
        final prose = entry.value(File(entry.key).readAsStringSync());
        for (final retired in const [
          'no-op-free',
          'assumes the caller has already',
        ]) {
          expect(
            prose,
            isNot(contains(retired)),
            reason:
                'the members document a no-op; a precondition stated here '
                'contradicts them',
          );
        }
      });
    }
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

    test('reads a CREATE TABLE whose quoted name contains a bracket', () {
      // The column list opens at the first bracket that is not inside a quoted
      // name. Taking the first bracket in the text split the statement inside
      // the name: the table was registered as `w`, `1` was read as its column
      // list, and `id` was lost — a divergence report about a table the chain
      // creates correctly.
      final schema = replay([
        artifact('[000]-create', 'CREATE TABLE `w(1)` (id BIGINT NOT NULL);'),
      ]);
      expect(schema.table('w'), isNull);
      expect(schema.table('w(1)')!.column('id'), isNotNull);
    });

    test('reads a PRIMARY KEY whose column list touches the keyword', () {
      // `KEY(a, b)` with no space is one word to the tokenizer, which keeps a
      // parenthesised group attached to the word before it. Reading the list
      // from the token *after* `KEY` would find nothing here.
      final schema = replay([
        artifact('[000]-create', '''
CREATE TABLE widget (
  owner BIGINT NOT NULL,
  slot  INT    NOT NULL,
  PRIMARY KEY(owner, slot)
);'''),
      ]);
      expect(schema.table('widget')!.primaryKey, ['owner', 'slot']);
    });

    test('reads a PRIMARY KEY over a column name containing a bracket', () {
      // The brackets inside the quoted name are not structure, so neither the
      // opening bracket of the list nor its match may be taken from there.
      final schema = replay([
        artifact('[000]-create', '''
CREATE TABLE widget (
  `owner(legacy)` BIGINT NOT NULL,
  slot            INT    NOT NULL,
  PRIMARY KEY (`owner(legacy)`, slot)
);'''),
      ]);
      expect(schema.table('widget')!.primaryKey, ['owner(legacy)', 'slot']);
    });

    test('reads a PRIMARY KEY past a constraint name containing a bracket', () {
      // A backtick-quoted identifier may hold anything, including `(`. A
      // quote-blind scan finds that one and reads the constraint's *name* as
      // its column list. Contrived as a table design, ordinary as a quoted
      // identifier — and the same shape that breaks `CREATE TABLE` above.
      final schema = replay([
        artifact('[000]-create', '''
CREATE TABLE widget (
  owner BIGINT NOT NULL,
  slot  INT    NOT NULL,
  CONSTRAINT `pk(legacy)` PRIMARY KEY (owner, slot)
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

    // Where the actions begin is a question about the *token* after the table
    // name, and answering it by searching the raw text for that name answers a
    // different question: the first place those characters occur, which may be
    // inside the leading `ALTER TABLE` keywords. The symptom is the bad kind —
    // not a parse error but a false divergence, reporting an unsupported action
    // named after a fragment of a keyword while the column is silently never
    // added. `replay` fails on any error, so each of these is that report.
    group('ALTER TABLE whose table name also occurs in the keywords', () {
      /// Creates `name` with one column, then adds column `b` to it.
      ///
      /// The two artifacts are the whole point: the `ALTER` has to find its
      /// action list, and `b INT` is the evidence it did.
      TomSchemaModel addColumnTo(String name, {required String alter}) =>
          replay([
            artifact('[000]-create', 'CREATE TABLE $name (id BIGINT);'),
            artifact('[001]-extend', alter),
          ]);

      test('reads the actions of a table named ABLE', () {
        // `ABLE` occurs inside `TABLE`, four characters before the real name.
        final schema = addColumnTo(
          'ABLE',
          alter: 'ALTER TABLE ABLE ADD COLUMN b INT;',
        );
        expect(schema.table('ABLE')!.column('b'), isNotNull);
      });

      // Quoting a reserved word is how a table actually gets named `TABLE` or
      // `ALTER`, and the quotes happen to make the token unique in the text, so
      // these two never misfired. They are here to keep it that way: the name
      // must be matched as the tokenizer cut it, backticks and all.
      test('reads the actions of a quoted table named TABLE', () {
        final schema = addColumnTo(
          '`TABLE`',
          alter: 'ALTER TABLE `TABLE` ADD COLUMN b INT;',
        );
        expect(schema.table('TABLE')!.column('b'), isNotNull);
      });

      test('reads the actions of a quoted table named ALTER', () {
        final schema = addColumnTo(
          '`ALTER`',
          alter: 'ALTER TABLE `ALTER` ADD COLUMN b INT;',
        );
        expect(schema.table('ALTER')!.column('b'), isNotNull);
      });

      test('reads the actions of a lowercase statement on a short name', () {
        // Nothing exotic: `ab` occurs inside `table`, so ordinary lowercase DDL
        // on a two-letter table hits the same misfire. The search is
        // case-sensitive, which is the only reason uppercase DDL escapes it.
        final schema = addColumnTo(
          'ab',
          alter: 'alter table ab add column b int;',
        );
        expect(schema.table('ab')!.column('b'), isNotNull);
      });

      test('reads every action, not just the first, past such a name', () {
        // A misfire that consumed only the first action would still pass the
        // single-column cases above.
        final schema = addColumnTo(
          'ABLE',
          alter: 'ALTER TABLE ABLE ADD COLUMN b INT, ADD COLUMN c VARCHAR(8);',
        );
        expect(schema.table('ABLE')!.columns.keys, ['id', 'b', 'c']);
      });
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

    test('CREATE TABLE … AS SELECT is rejected without leaving a table', () {
      // The parenthesis the header parser finds belongs to the SELECT, so the
      // reader used to read `a, b` as a column list: two "unreadable column"
      // errors *and* a table `copy` with no columns at all. That empty table
      // then turned every column the entity declares on it into a
      // `missingColumn` divergence — a second wave of noise caused by the parse
      // failure rather than by any real disagreement.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact(
          '[000]-copy',
          'CREATE TABLE copy AS SELECT id, name FROM src '
              'WHERE x = COALESCE(a, b);',
        ),
      ]);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.message,
        contains('Unsupported CREATE TABLE form'),
      );
      expect(result.schema.tables, isEmpty);
    });

    test('CREATE TABLE … AS (SELECT …) is rejected rather than mis-parsed', () {
      // The worst of the family: the parenthesised SELECT parses *cleanly* as a
      // one-column list, so the reader reported nothing and invented a column
      // named `select`.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-copy', 'CREATE TABLE copy AS (SELECT id FROM src);'),
      ]);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.message,
        contains('Unsupported CREATE TABLE form'),
      );
      expect(result.schema.tables, isEmpty);
    });

    test('CREATE TABLE … AS SELECT without parentheses names the form', () {
      // Reported before as "without a column list", which reads as a truncated
      // statement and sends the author looking for a missing paren.
      final result = TomSchemaDdlReader(dialect).replay([
        artifact('[000]-copy', 'CREATE TABLE copy AS SELECT * FROM src;'),
      ]);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.message,
        contains('Unsupported CREATE TABLE form'),
      );
      expect(result.schema.tables, isEmpty);
    });

    test('CREATE TABLE … LIKE is rejected as an unsupported form', () {
      final result = TomSchemaDdlReader(
        dialect,
      ).replay([artifact('[000]-copy', 'CREATE TABLE copy LIKE src;')]);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.message,
        contains('Unsupported CREATE TABLE form'),
      );
      expect(result.schema.tables, isEmpty);
    });

    test('a truncated CREATE TABLE is still reported as a missing list', () {
      // The unsupported-form check must not swallow this one: nothing follows
      // the table name, so the statement really is truncated.
      final result = TomSchemaDdlReader(
        dialect,
      ).replay([artifact('[000]-cut', 'CREATE TABLE w')]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('without a column list'));
    });

    test('one unreadable column does not discard the rest of the table', () {
      // Rejection is at the level of the *statement form*, not the entry: once
      // the reader has a genuine column list it reads what it can and reports
      // the entry it cannot. Dropping the whole table here would turn one bad
      // entry into a missingColumn finding for every other column on it.
      final result = TomSchemaDdlReader(
        dialect,
      ).replay([artifact('[000]-create', 'CREATE TABLE w (id BIGINT, oops);')]);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('Unreadable column'));
      expect(result.schema.table('w')!.columns.keys, ['id']);
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

    test('a converged chain reports agreement with no findings at all', () {
      final report = check.checkSchema(
        convergedMigrations,
        fixtureDatasource,
        fixtureSchema,
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.converged, isTrue, reason: report.describe());
      expect(report.divergences, isEmpty, reason: report.describe());
      expect(report.describe(), contains('converged'));
    });

    test(
      'the chain is environment-filtered exactly as the engine filters it',
      () {
        // Under the production-safe default only the two untagged artifacts are
        // in the chain; under `dev` the tagged seed joins them and — being data —
        // still leaves the schema unchanged.
        final production = check.checkSchema(
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
        final report = development.checkSchema(
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

    test('a divergent chain localises every disagreement', () {
      final report = check.checkSchema(
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

    test('checkAll walks the whole tree and reports per datasource/schema', () {
      final reports = check.checkAll(
        convergedMigrations,
        entityTypes: [FixtureTaskRecord],
      );
      expect(reports, hasLength(1));
      expect(reports.single.datasource, fixtureDatasource);
      expect(reports.single.schema, fixtureSchema);
      expect(reports.single.converged, isTrue);
    });

    test(
      'a missing migrations directory aborts rather than reporting nothing',
      () {
        // This replaces an earlier bar that asserted the opposite — an absent
        // tree returning `[]`. The contract changed because `[]` is
        // indistinguishable, at every call site, from "every pair converged":
        // a gate written as `reports.every((r) => r.converged)` passes vacuously
        // on a path that was never read. And the engine, given the very same
        // path, refuses to run. Two tools over one tree cannot disagree about
        // whether the tree being absent is a failure.
        expect(
          () => check.checkAll('test/fixtures/convergence/absent'),
          throwsA(isA<TomDbMigrationException>()),
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

  // The checker half of the duplicate-basename bar. `readChain` collects a
  // schema directory the same way the engine does, so it has to reject the
  // same tree — a check that quietly read one of two colliding files would
  // report a chain the engine would refuse to apply, which is worse than
  // either behaviour alone.
  group('TomSchemaConvergenceCheck.readChain duplicate basenames', () {
    final check = TomSchemaConvergenceCheck(dialect: dialect);
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tom_conv_dupe_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String name, String sql) =>
        File(p.join(dir.path, name)).writeAsStringSync(sql);

    test('two files differing only in extension abort the read', () {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[0]-create_it.ddl', 'CREATE TABLE b (id BIGINT);');
      expect(
        () => check.readChain(dir.path),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('the abort names both colliding paths', () {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[0]-create_it.ddl', 'CREATE TABLE b (id BIGINT);');
      Object? caught;
      try {
        check.readChain(dir.path);
      } catch (error) {
        caught = error;
      }
      expect(caught, isNotNull);
      expect(caught.toString(), contains('[0]-create_it.sql'));
      expect(caught.toString(), contains('[0]-create_it.ddl'));
    });

    test('a directory with distinct basenames still reads its chain', () {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[1]-alter_it.sql', 'ALTER TABLE a ADD COLUMN n INT;');
      expect(check.readChain(dir.path).map((a) => a.basename), [
        '[0]-create_it',
        '[1]-alter_it',
      ]);
    });
  });

  // The missing-directory bar, from the checker's side. The tree *root* is an
  // input the caller configured: absent, it is a wrong path, and the check has
  // nothing to say about a tree it never read. A pair *below* an existing root
  // is content, and content the check can describe — so the two cases are
  // deliberately not the same, and each is pinned here.
  group('TomSchemaConvergenceCheck missing directories', () {
    final check = TomSchemaConvergenceCheck(dialect: dialect);
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tom_conv_absent_'));
    tearDown(() => root.deleteSync(recursive: true));

    String absent() => p.join(root.path, 'not_created');

    test(
      'the checker rejects a missing root with the engine\'s own key',
      () async {
        // Same tree, same key, from both tools — the point of the whole change.
        Object? fromCheck;
        try {
          check.checkAll(absent());
        } catch (error) {
          fromCheck = error;
        }
        Object? fromEngine;
        try {
          await TomDbMigrations.migrateDatabases(absent());
        } catch (error) {
          fromEngine = error;
        }
        expect(fromCheck, isA<TomDbMigrationException>());
        expect(fromEngine, isA<TomDbMigrationException>());
        expect(
          (fromCheck as TomDbMigrationException).key,
          (fromEngine as TomDbMigrationException).key,
        );
        expect(
          fromCheck.key,
          'db_migration.migration.migrations_directory_not_found',
        );
      },
    );

    test('checkSchema rejects a missing root too', () {
      // It takes the same root argument as checkAll, so it cannot hold a
      // different opinion about that root existing.
      expect(
        () => check.checkSchema(absent(), 'some_ds', 'some_schema'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('the refusal is raised by the call, not carried in a future', () {
      // Not a style point about signatures — it is what makes the refusal
      // un-ignorable. The guard exists because an unread tree must not read as
      // "every pair converged"; a future-returning version hands a caller who
      // forgot an `await` exactly that vacuous pass, with the exception arriving
      // later as an unhandled rejection nothing was watching.
      //
      // Deliberately not `throwsA` over a closure: that matcher awaits a future
      // the closure returns and reports its rejection as a throw, so it passes
      // either way and cannot pin this. Only catching around the bare call
      // distinguishes "threw during the call" from "returned a rejected future".
      Object? fromCheckAll;
      try {
        check.checkAll(absent());
      } catch (error) {
        fromCheckAll = error;
      }
      Object? fromCheckSchema;
      try {
        check.checkSchema(absent(), 'some_ds', 'some_schema');
      } catch (error) {
        fromCheckSchema = error;
      }
      expect(fromCheckAll, isA<TomDbMigrationException>());
      expect(fromCheckSchema, isA<TomDbMigrationException>());
    });

    test(
      'an existing but empty root yields no reports, and does not throw',
      () {
        // The negative direction. An empty tree is a legitimate state — a guard
        // that rejected it would reject every project whose migrations have not
        // been written yet.
        expect(check.checkAll(root.path, entityTypes: const []), isEmpty);
      },
    );

    test('a pair absent below an existing root is a finding, not an abort', () {
      // `readChain` stays tolerant on purpose: an empty chain lets `verify`
      // report every entity as missing from the migrations, which is a
      // diagnosis — and a diagnosis is what the check exists to produce. An
      // exception here would replace a precise finding with a crash.
      // Named for the fixture's own schema so the entity is attributed to it —
      // an unattributed entity would leave the report trivially converged and
      // the test would prove nothing.
      Directory(
        p.join(root.path, fixtureDatasource),
      ).createSync(recursive: true);
      final report = check.checkSchema(
        root.path,
        fixtureDatasource,
        fixtureSchema,
        entityTypes: [FixtureTaskRecord],
      );
      expect(report.chain, isEmpty);
      expect(report.converged, isFalse);
      expect(
        report.errors.map((d) => d.kind),
        contains(TomSchemaDivergenceKind.missingTable),
      );
    });
  });
}

/// The run of `///` lines immediately above `class TomSchemaBuilder`.
///
/// Deliberately not the whole file: the claim under test is what a reader meets
/// *at the class*, and a file-wide search would let a sentence anywhere in the
/// library satisfy an assertion about the class's own contract.
String _builderClassDartdocOf(String source) {
  final lines = source.split('\n');
  final declaration = lines.indexWhere(
    (line) => line.startsWith('class TomSchemaBuilder'),
  );
  if (declaration < 0) fail('schema_model.dart no longer declares the builder');
  var first = declaration;
  while (first > 0 && lines[first - 1].trimLeft().startsWith('///')) {
    first--;
  }
  if (first == declaration) fail('TomSchemaBuilder has no class dartdoc');
  return lines.sublist(first, declaration).join('\n');
}

/// The prose under the summary's `### TomSchemaBuilder`, up to its first
/// `####` subsection — the paragraphs, not the member tables that follow.
String _builderSummaryProseOf(String source) {
  final section = RegExp(
    r'^### TomSchemaBuilder$(.*?)^#{3,4} ',
    multiLine: true,
    dotAll: true,
  ).firstMatch(source);
  if (section == null) fail('the summary no longer has a builder section');
  return section.group(1)!;
}
