import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the object-persistence module:
/// the [TomQueryBuilder] DSL and the [TomOperator] tree rendering SQL through a
/// dialect, plus the persistence annotations and `TomColumnInformation`.
///
/// The repositories and the query-sentence compiler need a reflected entity and
/// a live data source, so they are covered by `doc/object_persistence.md` and
/// integration tests, not here.

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

TomColumnInformation _column(String table, String column) {
  return TomColumnInformation(
    TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    Object,
    TomDbColumn(columnName: column),
    null,
    null,
    null,
    Object,
    column,
    column,
  );
}

void main() {
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
        b.group(b.like(b.textF('name', _column('users', 'name')), b.text('A%'))),
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
        () => b.between(b.intF('age', col), [b.intOp(1), b.intOp(2), b.intOp(3)]),
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
      final info = TomColumnInformation(
        TomDbTable(datasource: 'main', table: 't', primaryKeyField: 'id'),
        Object,
        null, // no column annotation -> fall back to declaredName
        null,
        null,
        null,
        Object,
        'fieldName',
        'fieldName',
      );
      expect(info.getQueryFieldName(), 'fieldName');
    });

    test('module exceptions are TomServerException subtypes', () {
      expect(
        TomQuerySyntaxException('k', 'm'),
        isA<TomServerException>(),
      );
      expect(
        TomAnnotationAnalyzerException('k', 'm'),
        isA<TomServerException>(),
      );
    });
  });

  // Bug §28: a unary operator (Not / And / Or / Group / IsNull) must collect its
  // operands' *fields* in getFields, not their parameter names. The bug had the
  // override delegate to getParameters, so getFields over any tree containing a
  // grouped/conjoined predicate leaked the parameter names and dropped the
  // columns.
  group('unary operator getFields (bug §28)', () {
    test('Not collects the column field, not the parameter name', () {
      final col = _column('users', 'age');
      final pred = b.not(b.gte(b.intF('age', col), b.p<TomDbInt>('min')));
      // Before §28 this returned {'min'} (the parameter) and dropped the column.
      expect(pred.getFields(dialect), {'users.age'});
    });

    test('And collects every operand column and no parameter names', () {
      final pred = b.and([
        b.group(b.gte(b.intF('age', _column('users', 'age')),
            b.p<TomDbInt>('min'))),
        b.group(b.like(
            b.textF('name', _column('users', 'name')), b.text('A%'))),
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

  // Bug §68: `TomSqlDatasourceRepository.save` produced broken SQL — the
  // INSERT/UPDATE `TomLiteralSelect` was built without its `parameters`, so the
  // `:name -> ?` substitution never ran and nothing bound; the UPDATE had no
  // WHERE clause (it would update every row), used the field name instead of
  // the column name in `SET`, and the insert/update decision misfired for a
  // non-nullable sentinel int key. These tests pin the pure SQL builders the
  // fixed `save` delegates to.
  group('save SQL builders (bug §68)', () {
    TomColumnInformation namedColumn(
      String columnName,
      String declaredName, {
      bool readOnly = false,
      bool isPk = false,
    }) {
      return TomColumnInformation(
        TomDbTable(datasource: 'main', table: 'users', primaryKeyField: 'id'),
        Object,
        TomDbColumn(columnName: columnName, isReadOnly: readOnly),
        isPk ? const TomEntityId() : null,
        null,
        null,
        Object,
        declaredName,
        columnName,
      );
    }

    test('buildInsertStatement uses column names and :declaredName placeholders',
        () {
      final cols = [
        namedColumn('user_name', 'userName'),
        namedColumn('password_hash', 'passwordHash'),
      ];
      final (sql, params) =
          TomSqlDatasourceRepository.buildInsertStatement('users', cols);
      expect(
        sql,
        'INSERT INTO users ( user_name,password_hash )'
        ' VALUES ( :userName,:passwordHash )',
      );
      expect(params, ['userName', 'passwordHash']);
    });

    test('buildUpdateStatement sets columns and adds a WHERE on the pk', () {
      final cols = [
        namedColumn('user_name', 'userName'),
        namedColumn('password_hash', 'passwordHash'),
      ];
      final pk = namedColumn('id', 'id', isPk: true, readOnly: true);
      final (sql, params) =
          TomSqlDatasourceRepository.buildUpdateStatement('users', cols, pk);
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

    // Bug §72: `save` read the primary key with `getVariableValue(toSave) as K`.
    // For an entity with a *nullable* surrogate key (`int?`) left null on its
    // first insert, that cast was `null as int`, which throws
    // `Null is not a subtype of int` — before `isUnsavedKey` ever ran. Every
    // INSERT of such an entity failed (the app sample's `createProject` 500'd).
    // `readPrimaryKey` reads as nullable so the unsaved-null case survives to
    // the INSERT/UPDATE decision.
    test('readPrimaryKey reads a null nullable surrogate key without throwing',
        () {
      expect(TomSqlDatasourceRepository.readPrimaryKey<int>(null), isNull);
    });

    test('readPrimaryKey returns a present int key unchanged', () {
      expect(TomSqlDatasourceRepository.readPrimaryKey<int>(7), 7);
    });

    test('readPrimaryKey returns a negative sentinel key unchanged', () {
      // The sentinel still arrives non-null; isUnsavedKey classifies it.
      expect(TomSqlDatasourceRepository.readPrimaryKey<int>(-1), -1);
    });
  });

  // Bug §29: getPersistentColumns memoises `null` for a non-reflectable type,
  // but the cache-hit fast path cast `null` to a non-nullable list. The first
  // call returned null; the second threw a TypeError off the cache.
  group('TomAnnotationAnalyzer.getPersistentColumns (bug §29)', () {
    test('returns null on every call for a non-reflectable type', () {
      // _NotAnEntity is not registered with tomReflector, so the analyzer caches
      // null. A second call must read that cached null back as null, not throw.
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

  // Full-surface scaling (RCF4): the remaining comparison builders the DSL
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

  // Full-surface scaling (RCF4): the null-test, negated-match and
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

  // Full-surface scaling (RCF4): the literal builders beyond int/string.
  // The standard dialect renders numbers/bools bare and dates single-quoted;
  // dateOp is *not* zero-padded (it interpolates `year-month-day` directly).
  group('remaining literal builders', () {
    test('doubleOp renders the value bare', () {
      expect(b.doubleOp(1.5).generate(dialect), '1.5');
    });

    test('boolOp renders true / false bare', () {
      expect(b.boolOp(true).generate(dialect), 'true');
      expect(b.boolOp(false).generate(dialect), 'false');
    });

    test('dateTimeOp renders a single-quoted ISO-8601 timestamp', () {
      final ts = DateTime.utc(2026, 7, 15, 9, 30);
      expect(
        b.dateTimeOp(ts).generate(dialect),
        "'${ts.toIso8601String()}'",
      );
    });

    test('dateOp renders single-quoted YYYY-M-D without padding', () {
      final d = DateTime(2026, 7, 5);
      expect(b.dateOp(d).generate(dialect), "'2026-7-5'");
    });
  });

  // Full-surface scaling (RCF4): the typed column-reference builders beyond
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

  // Full-surface scaling (RCF4): the dialect's own `objectOp` value-dispatch
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

    test('DateTime renders as a quoted ISO-8601 timestamp', () {
      final ts = DateTime.utc(2026, 7, 15, 9, 30);
      expect(dialect.objectOp(ts), "'${ts.toIso8601String()}'");
    });

    test('an Iterable renders as a comma-separated literal list', () {
      expect(dialect.objectOp([1, 2, 'a']), "1,2,'a'");
      expect(dialect.iterableOp([1, 2, 'a']), "1,2,'a'");
    });
  });
}

/// A plain type with no persistence reflection, used to drive the analyzer's
/// non-reflectable / null-memoisation path (bug §29).
class _NotAnEntity {}
