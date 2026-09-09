import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

/// Tests for the connection-free surface of the object-persistence module:
/// the [TomQueryBuilder] DSL and the [TomOperator] tree rendering SQL through a
/// dialect, plus the persistence annotations and `TomColumnInformation`.
///
/// The repositories and the query-sentence compiler are asserted elsewhere in
/// this package, and mostly without a database:
///
///  * the sentence grammar by `test/query_sentence_is_in_test.dart`,
///    `query_sentence_boolean_operand_test.dart`,
///    `query_sentence_negation_test.dart`,
///    `query_sentence_string_literal_test.dart` and
///    `query_sentence_rejection_test.dart`, and its grouped form by
///    `grouped_query_test.dart`, in the group named `group query sentence`;
///  * the repositories by `test/crud_repository_exceptions_test.dart` (every
///    failure a repository reports, by key) and
///    `crud_repository_delete_counts_test.dart`;
///  * the round trip against a real MariaDB by
///    `test/object_persistence_db_test.dart`, in the group named
///    `FixtureTaskRepository (DB-backed CRUD)`, which is
///    `@Tags(['db'])` and self-skips without one — `tool/run_db_tests.sh`
///    starts the database those suites need.
///
/// So a live data source is what the *last* of those needs, not the others: a
/// scripted datasource (`test/fixtures/scripted_datasource.dart`) answers a
/// repository's statements from a script, which is how the failure paths are
/// reachable at all — a real database will not produce a broken row set on
/// request.
///
/// Named by file and group rather than by line number on purpose: these
/// pointers have to survive the files they point into being edited.

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

TomColumnInformation _column(String table, String column) {
  return TomColumnInformation(
    tableType: Object,
    table: TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    declaredType: Object,
    declaredName: column,
    field: column,
    column: TomDbColumn(columnName: column),
  );
}

void main() {
  // Reflection is per-isolate top-level state, and the analyzer group below
  // asks about a type that is *not* registered. Without this call nothing is
  // registered, so the answer would be right for the wrong reason — and the
  // first entity this file ever reflects for real would fail obscurely.
  setUpAll(initializeReflection);

  final b = _Builder();
  final dialect = MariadbSqlDialect();

  group('literals and comparisons', () {
    test('integer literal renders bare', () {
      expect(b.intOp(42).generate(dialect), '42');
    });

    test('string literal is single-quoted', () {
      expect(b.text('hi').generate(dialect), "'hi'");
    });

    test('equality renders a = b', () {
      expect(b.eq(b.intOp(1), b.intOp(2)).generate(dialect), '1 = 2');
    });

    test('greater-or-equal renders a >= b', () {
      expect(b.gte(b.intOp(5), b.intOp(3)).generate(dialect), '5 >= 3');
    });
  });

  group('parameters', () {
    test('render as :name placeholders', () {
      expect(b.p<TomDbInt>('min').generate(dialect), ':min');
    });

    test('contribute their name to getParameters', () {
      final pred = b.gte(b.intOp(1), b.p<TomDbInt>('min'));
      expect(pred.getParameters(dialect), contains('min'));
    });

    test('reference no fields', () {
      expect(b.p<TomDbInt>('min').getFields(dialect), isEmpty);
    });
  });

  group('column references', () {
    test('render as table.column', () {
      final col = _column('users', 'age');
      expect(b.intF('age', col).generate(dialect), 'users.age');
    });

    test('are collected as fields', () {
      final col = _column('users', 'name');
      final pred = b.like(b.textF('name', col), b.text('A%'));
      expect(pred.getFields(dialect), contains('users.name'));
    });
  });

  group('compound predicates', () {
    test('AND joins with the right separator and grouping', () {
      final ageCol = _column('users', 'age');
      final pred = b.and([
        b.group(b.gte(b.intF('age', ageCol), b.p<TomDbInt>('min'))),
        b.group(
          b.like(b.textF('name', _column('users', 'name')), b.text('A%')),
        ),
      ]);
      expect(
        pred.generate(dialect),
        "( users.age >= :min ) AND ( users.name LIKE 'A%' )",
      );
    });

    test('IN renders a comma-separated choice list', () {
      final col = _column('users', 'age');
      final pred = b.isIn(b.intF('age', col), [b.intOp(18), b.intOp(21)]);
      expect(pred.generate(dialect), 'users.age IN (18,21)');
    });

    test('OR joins predicates with OR', () {
      final pred = b.or([
        b.eq(b.intOp(1), b.intOp(1)),
        b.eq(b.intOp(2), b.intOp(2)),
      ]);
      expect(pred.generate(dialect), '1 = 1 OR 2 = 2');
    });
  });

  group('BETWEEN arity validation', () {
    test('two bounds renders BETWEEN ... AND ...', () {
      final col = _column('users', 'age');
      final pred = b.between(b.intF('age', col), [b.intOp(18), b.intOp(65)]);
      expect(pred.generate(dialect), 'users.age BETWEEN 18 AND 65');
    });

    test('one bound throws TomQuerySyntaxException', () {
      final col = _column('users', 'age');
      expect(
        () => b.between(b.intF('age', col), [b.intOp(18)]),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'between_expression.must_have_two_values',
          ),
        ),
      );
    });

    test('three bounds throws TomQuerySyntaxException', () {
      final col = _column('users', 'age');
      expect(
        () =>
            b.between(b.intF('age', col), [b.intOp(1), b.intOp(2), b.intOp(3)]),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });
  });

  group('persistence annotations', () {
    test('TomDbColumn.declaredDartType resolves the type argument', () {
      const col = TomDbColumn<String, TomDbString>(columnName: 'name');
      expect(col.declaredDartType(), String);
    });

    test('TomColumnInformation.getQueryFieldName prefers the column name', () {
      final info = _column('users', 'user_name');
      expect(info.getQueryFieldName(), 'user_name');
    });

    test('TomColumnInformation.getQueryFieldName falls back to the field', () {
      // No `column:` argument, so getQueryFieldName falls back to declaredName.
      final info = TomColumnInformation(
        tableType: Object,
        table: TomDbTable(
          datasource: 'main',
          table: 't',
          primaryKeyField: 'id',
        ),
        declaredType: Object,
        declaredName: 'fieldName',
        field: 'fieldName',
      );
      expect(info.getQueryFieldName(), 'fieldName');
    });

    test('module exceptions are TomServerException subtypes', () {
      expect(TomQuerySyntaxException('k', 'm'), isA<TomServerException>());
      expect(
        TomAnnotationAnalyzerException('k', 'm'),
        isA<TomServerException>(),
      );
    });
  });

  // `TomPersistenceEventHandler` is resolved and then ignored, and two places
  // say so in prose: the annotation's own dartdoc and the "Not Yet Implemented"
  // section of `doc/object_persistence.md`. That pair drifted apart once
  // already — the analyzer began resolving the annotation while the dartdoc went
  // on telling readers it was not detected at all, which is the wrong direction
  // to be wrong in: a reader concludes the annotation is inert metadata when it
  // is in fact live and reachable.
  //
  // Prose cannot be kept true by remembering to update it, so the two halves of
  // the claim are pinned here against the source. Implementing the callbacks
  // should fail these tests, and the failure names the prose that then has to
  // change.
  group('TomPersistenceEventHandler is resolved but never invoked', () {
    /// Every library source file, as (path, contents) pairs.
    final library = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          (f.path, f.readAsStringSync()),
    ];

    /// Where the annotation and its four callbacks are *declared*, and so the
    /// one file expected to name them without invoking anything.
    const declarationSite =
        'lib/src/tomserver/object_persistence/persistence_annotations.dart';

    test('the analyzer resolves it onto TomColumnInformation.eventHandler', () {
      final analyzer = File(
        'lib/src/tomserver/object_persistence/annotation_analyzer.dart',
      ).readAsStringSync();
      expect(
        analyzer,
        allOf(
          contains('md is TomPersistenceEventHandler'),
          contains('eventHandler = md'),
        ),
        reason:
            'the annotation must stay detected, or the dartdoc on '
            'TomPersistenceEventHandler and the "Not Yet Implemented" section '
            'of doc/object_persistence.md both become wrong',
      );
    });

    test('no library file invokes a lifecycle callback', () {
      // The declaration names all four; anywhere else naming one means the
      // callbacks have been wired up and "never invoked" has stopped being
      // true.
      final callbacks = ['prePersist', 'postPersist', 'preLoad', 'postLoad'];
      final users = [
        for (final (path, source) in library)
          if (!path.endsWith(declarationSite.split('/').last) &&
              callbacks.any(source.contains))
            path,
      ];
      expect(
        users,
        isEmpty,
        reason:
            'a lifecycle callback is now referenced outside its declaration; '
            'if it is invoked, drop "never invoked" from the dartdoc on '
            'TomPersistenceEventHandler and from the "Not Yet Implemented" '
            'section of doc/object_persistence.md',
      );
    });

    test('nothing reads the resolved handler back', () {
      // The other half of "no effect": the analyzer writes `eventHandler`, and
      // no code path ever reads it. A read is the first thing an implementation
      // would add, and it would appear here before any callback was called.
      final readers = [
        for (final (path, source) in library)
          if (!path.endsWith(declarationSite.split('/').last) &&
              source.contains('.eventHandler'))
            path,
      ];
      expect(
        readers,
        isEmpty,
        reason:
            'TomColumnInformation.eventHandler is now read somewhere; the '
            'annotation may no longer be inert, so the prose that says it has '
            'no effect must be revisited',
      );
    });
  });

  // A unary operator (Not / And / Or / Group / IsNull) must collect its
  // operands' *fields* in getFields, not their parameter names. Delegating the
  // override to getParameters instead makes getFields over any tree containing
  // a grouped/conjoined predicate leak the parameter names and drop the
  // columns.
  group('unary operator getFields', () {
    test('Not collects the column field, not the parameter name', () {
      final col = _column('users', 'age');
      final pred = b.not(b.gte(b.intF('age', col), b.p<TomDbInt>('min')));
      // Delegating to getParameters would return {'min'} and drop the column.
      expect(pred.getFields(dialect), {'users.age'});
    });

    test('And collects every operand column and no parameter names', () {
      final pred = b.and([
        b.group(
          b.gte(b.intF('age', _column('users', 'age')), b.p<TomDbInt>('min')),
        ),
        b.group(
          b.like(b.textF('name', _column('users', 'name')), b.text('A%')),
        ),
      ]);
      final fields = pred.getFields(dialect);
      expect(fields, containsAll(['users.age', 'users.name']));
      expect(fields, isNot(contains('min')));
    });

    test('IsNull collects the wrapped column field', () {
      final col = _column('users', 'name');
      final pred = b.isNull(b.textF('name', col));
      expect(pred.getFields(dialect), {'users.name'});
    });
  });

  // `TomSqlDatasourceRepository.save` delegates to pure SQL builders, and these
  // tests pin them. Each assertion covers a way the generated SQL can be wrong
  // while still looking plausible: a `TomLiteralSelect` built without its
  // `parameters` never runs the `:name -> ?` substitution and binds nothing; an
  // UPDATE without a WHERE clause rewrites every row; `SET` naming the field
  // rather than the column addresses a column that does not exist; and the
  // insert/update decision has to hold for a non-nullable sentinel int key.
  group('save SQL builders', () {
    TomColumnInformation namedColumn(
      String columnName,
      String declaredName, {
      bool readOnly = false,
      bool isPk = false,
    }) {
      return TomColumnInformation(
        tableType: Object,
        table: TomDbTable(
          datasource: 'main',
          table: 'users',
          primaryKeyField: 'id',
        ),
        declaredType: Object,
        declaredName: declaredName,
        field: columnName,
        column: TomDbColumn(columnName: columnName, isReadOnly: readOnly),
        entityId: isPk ? const TomEntityId() : null,
      );
    }

    test(
      'buildInsertStatement uses column names and :declaredName placeholders',
      () {
        final cols = [
          namedColumn('user_name', 'userName'),
          namedColumn('password_hash', 'passwordHash'),
        ];
        final (sql, params) = TomSqlDatasourceRepository.buildInsertStatement(
          'users',
          cols,
        );
        expect(
          sql,
          'INSERT INTO users ( user_name,password_hash )'
          ' VALUES ( :userName,:passwordHash )',
        );
        expect(params, ['userName', 'passwordHash']);
      },
    );

    test('buildUpdateStatement sets columns and adds a WHERE on the pk', () {
      final cols = [
        namedColumn('user_name', 'userName'),
        namedColumn('password_hash', 'passwordHash'),
      ];
      final pk = namedColumn('id', 'id', isPk: true, readOnly: true);
      final (sql, params) = TomSqlDatasourceRepository.buildUpdateStatement(
        'users',
        cols,
        pk,
      );
      expect(
        sql,
        'UPDATE users SET user_name = :userName,password_hash = :passwordHash'
        ' WHERE id = :id',
      );
      expect(params, ['userName', 'passwordHash', 'id']);
    });

    test('isUnsavedKey treats null and negative ints as unsaved', () {
      // A nullable surrogate key is null before first persist; a non-nullable
      // int key uses a negative sentinel (the `id >= 0` convention).
      expect(TomSqlDatasourceRepository.isUnsavedKey(null), isTrue);
      expect(TomSqlDatasourceRepository.isUnsavedKey(-1), isTrue);
      expect(TomSqlDatasourceRepository.isUnsavedKey(0), isFalse);
      expect(TomSqlDatasourceRepository.isUnsavedKey(7), isFalse);
      expect(TomSqlDatasourceRepository.isUnsavedKey('abc'), isFalse);
    });

    // `save` must read the primary key as *nullable*. An entity with a nullable
    // surrogate key (`int?`) is null on its first insert, so a
    // `getVariableValue(toSave) as K` cast would be `null as int` and throw
    // `Null is not a subtype of int` before `isUnsavedKey` ever ran — failing
    // every INSERT of such an entity. `readPrimaryKey` reads as nullable so the
    // unsaved-null case survives to the INSERT/UPDATE decision.
    test(
      'readPrimaryKey reads a null nullable surrogate key without throwing',
      () {
        expect(TomSqlDatasourceRepository.readPrimaryKey<int>(null), isNull);
      },
    );

    test('readPrimaryKey returns a present int key unchanged', () {
      expect(TomSqlDatasourceRepository.readPrimaryKey<int>(7), 7);
    });

    test('readPrimaryKey returns a negative sentinel key unchanged', () {
      // The sentinel still arrives non-null; isUnsavedKey classifies it.
      expect(TomSqlDatasourceRepository.readPrimaryKey<int>(-1), -1);
    });
  });

  // getPersistentColumns memoises `null` for a non-reflectable type, so the
  // cache-hit fast path has to read that entry back as nullable. Casting it to
  // a non-nullable list makes the first call return null and the second throw a
  // TypeError off the cache.
  group('TomAnnotationAnalyzer.getPersistentColumns', () {
    test('returns null on every call for a non-reflectable type', () {
      // _NotAnEntity carries no @tomReflector, so the reflector raises
      // NoSuchCapabilityError — the one cause findMirror tolerates — and the
      // analyzer caches null. A second call must read that cached null back as
      // null, not throw.
      expect(TomAnnotationAnalyzer.getPersistentColumns(_NotAnEntity), isNull);
      expect(TomAnnotationAnalyzer.getPersistentColumns(_NotAnEntity), isNull);
    });
  });

  // C-7 (G-DB-2): every repository operation binds its values through a
  // prepared statement, so no untrusted value is ever concatenated into the
  // SQL text. Two lines of defence are exercised here connection-free:
  //   1. a bound `Parameter` renders a `:name` placeholder — the value never
  //      appears in the generated SQL (it rides the bind protocol at execute);
  //   2. the literal renderer `text()` (the one path that *does* embed a value)
  //      escapes quotes and backslashes, so an embedded quote cannot terminate
  //      the literal and inject trailing SQL.
  group('injection neutralisation (C-7)', () {
    test('a bound parameter keeps the value out of the SQL', () {
      final col = _column('users', 'name');
      // The predicate compares a column to a *parameter*, not a literal — so
      // even a hostile bind value can never reach the SQL string.
      final pred = b.eq(b.textF('name', col), b.p<TomDbString>('name'));
      final sql = pred.generate(dialect);
      expect(sql, "users.name = :name");
      // The bind name is present; no value (and thus no injectable payload) is.
      expect(sql, isNot(contains("'")));
    });

    test('text() escapes a single quote by doubling it', () {
      // O'Brien must not close the literal after the O.
      expect(b.text("O'Brien").generate(dialect), "'O''Brien'");
    });

    test('text() escapes a backslash by doubling it', () {
      // A single backslash in the value becomes a doubled backslash.
      expect(b.text('a\\b').generate(dialect), r"'a\\b'");
    });

    test('a quote/semicolon payload stays inert inside the escaped literal', () {
      // Classic break-out attempt: a leading quote then a statement separator.
      // The leading quote is doubled, so the payload can never escape the
      // surrounding single quotes — it is one inert string literal.
      const payload = "'; DROP TABLE users; --";
      expect(b.text(payload).generate(dialect), "'''; DROP TABLE users; --'");
    });
  });

  // Full-surface scaling: the remaining comparison builders the DSL
  // exposes. eq/gte were already covered above; these are the rest of the
  // binary comparison family, each rendering its own SQL operator.
  group('remaining comparison operators', () {
    test('neq renders a <> b', () {
      expect(b.neq(b.intOp(1), b.intOp(2)).generate(dialect), '1 <> 2');
    });

    test('lt renders a < b', () {
      expect(b.lt(b.intOp(1), b.intOp(2)).generate(dialect), '1 < 2');
    });

    test('lte renders a <= b', () {
      expect(b.lte(b.intOp(1), b.intOp(2)).generate(dialect), '1 <= 2');
    });

    test('gt renders a > b', () {
      expect(b.gt(b.intOp(2), b.intOp(1)).generate(dialect), '2 > 1');
    });
  });

  // Full-surface scaling: the null-test, negated-match and
  // regex-match predicate builders (isNull / like were already covered).
  group('remaining string / null predicates', () {
    test('isNotNull renders <col> IS NOT NULL', () {
      final col = _column('users', 'name');
      expect(
        b.isNotNull(b.textF('name', col)).generate(dialect),
        'users.name IS NOT NULL',
      );
    });

    test('notLike renders <col> NOT LIKE <pattern>', () {
      final col = _column('users', 'name');
      expect(
        b.notLike(b.textF('name', col), b.text('A%')).generate(dialect),
        "users.name NOT LIKE 'A%'",
      );
    });

    test('regexp renders <col> REGEXP <pattern>', () {
      final col = _column('users', 'name');
      expect(
        b.regexp(b.textF('name', col), b.text('^A')).generate(dialect),
        "users.name REGEXP '^A'",
      );
    });
  });

  // Full-surface scaling: the literal builders beyond int/string.
  // The standard dialect renders numbers/bools bare and both date renderers
  // single-quoted and zero-padded to a fixed width.
  group('remaining literal builders', () {
    test('doubleOp renders the value bare', () {
      expect(b.doubleOp(1.5).generate(dialect), '1.5');
    });

    test('boolOp renders true / false bare', () {
      expect(b.boolOp(true).generate(dialect), 'true');
      expect(b.boolOp(false).generate(dialect), 'false');
    });

    test('dateTimeOp renders a single-quoted UTC DATETIME(6) literal', () {
      // Not ISO-8601: the `T` separator and the trailing `Z` of a UTC value are
      // both rejected by a DATETIME column (error 1292). The literal path
      // carries the instant convention (`datasources/sql_instant.dart`) the
      // same way the bind boundary does.
      final ts = DateTime.utc(2026, 7, 15, 9, 30);
      expect(
        b.dateTimeOp(ts).generate(dialect),
        "'2026-07-15 09:30:00.000000'",
      );
    });

    test('dateOp renders a single-quoted, zero-padded YYYY-MM-DD', () {
      // The builder hands straight to the dialect, so this pins the wiring;
      // the padding rule itself is pinned in `datasources_test.dart`.
      final d = DateTime(2026, 7, 5);
      expect(b.dateOp(d).generate(dialect), "'2026-07-05'");
    });
  });

  // Full-surface scaling: the typed column-reference builders beyond
  // int/string. Every DbCol renders as the qualified `table.column` regardless
  // of its SQL type, and collects itself as a field.
  group('remaining typed column references', () {
    test('doubleF renders table.column and is collected as a field', () {
      final col = _column('products', 'price');
      final ref = b.doubleF('price', col);
      expect(ref.generate(dialect), 'products.price');
      expect(ref.getFields(dialect), {'products.price'});
    });

    test('boolF renders table.column', () {
      final col = _column('users', 'active');
      expect(b.boolF('active', col).generate(dialect), 'users.active');
    });

    test('dateTimeF renders table.column', () {
      final col = _column('events', 'occurred_at');
      expect(
        b.dateTimeF('occurredAt', col).generate(dialect),
        'events.occurred_at',
      );
    });

    test('dateF renders table.column', () {
      final col = _column('invoices', 'due_date');
      expect(b.dateF('dueDate', col).generate(dialect), 'invoices.due_date');
    });
  });

  // Full-surface scaling: the dialect's own `objectOp` value-dispatch
  // and the list/null literal helpers. `objectOp` is the public entry point
  // that turns an arbitrary Dart value into the matching SQL literal by runtime
  // type — the one place the whole literal table is exercised together.
  group('dialect objectOp value dispatch', () {
    test('null becomes the SQL NULL literal', () {
      expect(dialect.objectOp(null), 'NULL');
      expect(dialect.nullOp(), 'NULL');
    });

    test('a String is quoted and escaped', () {
      expect(dialect.objectOp("O'Brien"), "'O''Brien'");
    });

    test('int and double render bare', () {
      expect(dialect.objectOp(42), '42');
      expect(dialect.objectOp(1.5), '1.5');
    });

    test('bool renders bare', () {
      expect(dialect.objectOp(true), 'true');
    });

    test('DateTime renders as a quoted UTC DATETIME(6) literal', () {
      final ts = DateTime.utc(2026, 7, 15, 9, 30);
      expect(dialect.objectOp(ts), "'2026-07-15 09:30:00.000000'");
      // Dispatched by runtime type, so a local value renders the same instant.
      expect(dialect.objectOp(ts.toLocal()), "'2026-07-15 09:30:00.000000'");
    });

    test('an Iterable renders as a comma-separated literal list', () {
      expect(dialect.objectOp([1, 2, 'a']), "1,2,'a'");
      expect(dialect.iterableOp([1, 2, 'a']), "1,2,'a'");
    });
  });

  group('a repository is constructed, not discovered', () {
    // The registry is process-wide static state, so it is cleared after every
    // test rather than left for the next file to trip over.
    tearDown(unregisterScriptedDatasource);

    test('the MariaDB repository renders through the MariaDB dialect', () {
      registerScriptedDatasource();
      // Constructed exactly as a caller would: the entity and key as type
      // arguments, the entity's type in the reflectable list. The data source
      // has to exist because the entity names one, but nothing about the
      // repository *class* is registered and nothing looks it up.
      expect(
        MariadbRepository<FixtureTaskRecord, int>([
          FixtureTaskRecord,
        ]).sqlDialect,
        isA<MariadbSqlDialect>(),
      );
    });

    test('no shipped source or guide describes a repository lookup by type', () {
      // `TomRepositoryType` was an annotation binding a repository class to a
      // data-source type name, for a reflection scan that was never written.
      // Nothing read it, so a repository annotated for a second type could not
      // have been found; `MariadbRepository` is reached only because callers
      // construct that exact class. Three documents nevertheless described the
      // scan as the mechanism.
      //
      // The name is guarded rather than merely removed because a lookup keyed
      // on a data-source type name cannot work here even in principle: a
      // repository is generic in its entity and key, and those type arguments
      // are what make it the repository *for an entity*. A string cannot
      // supply them, so the registry could only ever hand back a raw type the
      // caller has to re-specialise — which is the construction it was meant
      // to replace. Re-introducing the lookup is a decision, and this test is
      // where it has to be argued.
      final claims = <String>[];
      for (final directory in [Directory('lib'), Directory('doc')]) {
        for (final entry in directory.listSync(recursive: true)) {
          if (entry is! File) continue;
          if (!entry.path.endsWith('.dart') && !entry.path.endsWith('.md')) {
            continue;
          }
          final lines = entry.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('TomRepositoryType')) {
              claims.add('${entry.path}:${i + 1}');
            }
          }
        }
      }
      expect(claims, isEmpty);
    });
  });
}

/// A plain type with no persistence reflection, used to drive the analyzer's
/// non-reflectable / null-memoisation path.
class _NotAnEntity {}
