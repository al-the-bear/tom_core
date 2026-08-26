/// Tests for the aggregation/grouping surface of the typed query layer
/// (CSEX5): the [TomAggregate] nodes, the [TomGroupedSelect] sentence, the
/// [TomGroupedRow] result shape, the dialect fragments they render through, and
/// the `group …` query sentence the compiler accepts.
///
/// Everything here is connection-free. The nodes render SQL through a dialect
/// and the sentences compile against the reflected `FixtureTaskRecord`, so no
/// MariaDB is needed; the round-trip through a live server is the DB-tagged
/// suite's job.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureExportRecord, FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

/// A hand-built column whose declared type is `Object` — deliberately outside
/// the set the result mapper can materialise, so it can drive the group-column
/// rejection.
TomColumnInformation _opaqueColumn(String table, String column) {
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
  final b = _Builder();
  final dialect = MariadbSqlDialect();

  group('dialect aggregate fragments', () {
    test('COUNT(*) renders without an operand', () {
      expect(dialect.aggregate(TomAggregateFunction.count, null), 'COUNT(*)');
    });

    test('DISTINCT is ignored for the argument-less form', () {
      expect(
        dialect.aggregate(TomAggregateFunction.count, null, distinct: true),
        'COUNT(*)',
      );
    });

    test('an operand renders inside the function call', () {
      expect(
        dialect.aggregate(TomAggregateFunction.sum, 't.amount'),
        'SUM(t.amount)',
      );
    });

    test('DISTINCT qualifies the operand', () {
      expect(
        dialect.aggregate(TomAggregateFunction.count, 't.c', distinct: true),
        'COUNT(DISTINCT t.c)',
      );
    });

    test('aliased renders the AS projection', () {
      expect(dialect.aliased('COUNT(*)', 'total'), 'COUNT(*) AS total');
    });

    test('GROUP BY is empty when nothing is grouped', () {
      expect(dialect.groupByClause([]), '');
    });

    test('GROUP BY joins the column expressions', () {
      expect(dialect.groupByClause(['t.a', 't.b']), ' GROUP BY t.a, t.b');
    });

    test('HAVING is empty without a predicate', () {
      expect(dialect.havingClause(null), '');
    });

    test('HAVING wraps the predicate', () {
      expect(dialect.havingClause('COUNT(*) > 3'), ' HAVING COUNT(*) > 3');
    });
  });

  group('aggregate nodes', () {
    final col = _opaqueColumn('fixture_task', 'priority');

    test('countAll renders COUNT(*)', () {
      expect(b.countAll('total').generate(dialect), 'COUNT(*)');
    });

    test('countAll projects under its alias', () {
      expect(
        b.countAll('total').generateProjection(dialect),
        'COUNT(*) AS total',
      );
    });

    test('countOf counts an expression', () {
      final node = b.countOf(b.intF('priority', col), 'n');
      expect(node.generate(dialect), 'COUNT(fixture_task.priority)');
    });

    test('countOf honours distinct', () {
      final node = b.countOf(b.intF('priority', col), 'n', distinct: true);
      expect(node.generate(dialect), 'COUNT(DISTINCT fixture_task.priority)');
    });

    test('sum widens its value type to double', () {
      expect(b.sum(b.intF('priority', col), 's').valueType, double);
    });

    test('avg widens its value type to double', () {
      expect(b.avg(b.intF('priority', col), 'a').valueType, double);
    });

    test('countAll keeps an int value type', () {
      expect(b.countAll('total').valueType, int);
    });

    test('minInt preserves the operand type', () {
      final node = b.minInt(b.intF('priority', col), 'lo');
      expect(node.generate(dialect), 'MIN(fixture_task.priority)');
      expect(node.valueType, int);
    });

    test('maxText preserves the operand type', () {
      final node = b.maxText(b.textF('title', col), 'hi');
      expect(node.valueType, String);
    });

    test('an aggregate composes with the predicate builders', () {
      final having = b.gt(b.countAll('total'), b.intOp(3));
      expect(having.generate(dialect), 'COUNT(*) > 3');
    });

    test('the operand contributes its field', () {
      final node = b.sum(b.intF('priority', col), 's');
      expect(node.getFields(dialect), {'fixture_task.priority'});
    });

    test('COUNT(*) references no field', () {
      expect(b.countAll('total').getFields(dialect), isEmpty);
    });

    test('the operand contributes its parameters', () {
      final node = b.sum(b.p<TomDbInt>('bonus'), 's');
      expect(node.getParameters(dialect), ['bonus']);
    });

    test('an alias that is not a plain identifier is rejected', () {
      expect(
        () => b.countAll('total; DROP TABLE users'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.aggregate.invalid_alias',
          ),
        ),
      );
    });

    test('an empty alias is rejected', () {
      expect(() => b.countAll(''), throwsA(isA<TomQuerySyntaxException>()));
    });

    test('a value type the mapper cannot materialise is rejected', () {
      expect(
        () => Min<TomDbInt, Object>(b.intF('priority', col), 'lo'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.aggregate.unmappable_value_type',
          ),
        ),
      );
    });

    test('the operand is a child, so tree walks descend into it', () {
      // `TomGroupedSelect.columnsOf` — the C-4 exposure check — finds columns
      // by recursing through `children`. An aggregate that reported none would
      // hide the column it aggregates from that check.
      final operand = b.intF('priority', col);
      expect(b.sum(operand, 's').children, [operand]);
    });

    test('COUNT(*) has no children to descend into', () {
      expect(b.countAll('total').children, isEmpty);
    });

    test('analyze renders the aggregate and its operand', () {
      final tree = b
          .countOf(b.intF('priority', col), 'n', distinct: true)
          .analyze(0);
      expect(tree, contains('COUNT'));
      expect(tree, contains('DISTINCT'));
      expect(tree, contains('AS n'));
      expect(tree, contains('priority'));
    });

    test('analyze marks the argument-less form with a star', () {
      expect(b.countAll('total').analyze(0), contains('*'));
    });

    test('toString names the function and the alias', () {
      expect(b.countAll('total').toString(), 'TomAggregate COUNT AS total');
    });
  });

  group('TomGroupedRow', () {
    final row = TomGroupedRow({
      'status': 'open',
      'total': 7,
      'revenue': '12.5',
      'done': 1,
      'created': '2026-07-28T10:00:00.000',
      'empty': null,
    });

    test('exposes the raw values by alias', () {
      expect(row.value('status'), 'open');
    });

    test('reports which aliases it carries', () {
      expect(row.has('total'), isTrue);
      expect(row.has('missing'), isFalse);
    });

    test('an unknown alias is a query bug, not a null', () {
      expect(
        () => row.value('missing'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.row.unknown_alias',
          ),
        ),
      );
    });

    test('coerces a textual exact-numeric to double', () {
      expect(row.doubleValue('revenue'), 12.5);
    });

    test('coerces an integer to double', () {
      expect(row.doubleValue('total'), 7.0);
    });

    test('coerces MariaDB 1/0 to bool', () {
      expect(row.boolValue('done'), isTrue);
    });

    test('parses a textual timestamp', () {
      expect(row.dateTimeValue('created'), DateTime.parse('2026-07-28 10:00'));
    });

    test('a null value stays null through the accessors', () {
      expect(row.intValue('empty'), isNull);
      expect(row.stringValue('empty'), isNull);
    });

    test('a non-numeric value cannot be read as a number', () {
      expect(
        () => row.intValue('status'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.row.value_conversion_failed',
          ),
        ),
      );
    });

    test('a non-numeric value cannot be read as a double either', () {
      // The int and double readers parse independently, so the same driver
      // value has to be refused twice over — a fractional column that came
      // back as prose must not silently become null on the way to the caller.
      expect(
        () => row.doubleValue('status'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.row.value_conversion_failed',
          ),
        ),
      );
    });

    test('typed dispatches on the requested Dart type', () {
      expect(row.typed<int>('total'), 7);
      expect(row.typed<String>('status'), 'open');
    });

    test('an unsupported target type is rejected', () {
      expect(
        () => row.typed<Object>('total'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.row.unsupported_value_type',
          ),
        ),
      );
    });

    test('an aggregate reads its own value out of the row', () {
      expect(_Builder().countAll('total').read(row), 7);
    });

    test('typed dispatches every type the mapper supports', () {
      // `typed<V>` is the seam the typed nodes read through, so each supported
      // V must reach the accessor that coerces it — a missing case would fall
      // to the "unsupported type" throw at runtime for a node that declared a
      // perfectly ordinary value type.
      expect(row.typed<double>('revenue'), 12.5);
      expect(row.typed<bool>('done'), isTrue);
      expect(
        row.typed<DateTime>('created'),
        DateTime.parse('2026-07-28 10:00'),
      );
    });

    test('an exact-numeric read as int truncates rather than failing', () {
      // MariaDB returns SUM/AVG as DECIMAL, which a driver may hand over as
      // text. A caller that declared the aggregate `int` gets the integer part
      // — the alternative would be an exception on a value the database
      // considers perfectly numeric.
      expect(row.intValue('revenue'), 12);
    });

    test('exposes the whole row, unmodifiable', () {
      expect(row.values, containsPair('status', 'open'));
      expect(() => row.values['injected'] = 1, throwsUnsupportedError);
    });

    test('a textual boolean is coerced by content, not by truthiness', () {
      // Drivers differ on how they hand back a TINYINT(1): a number on the
      // binary protocol, its text form on the text protocol. Both must read
      // the same way, and a value that is neither must read as false rather
      // than as "non-empty string, so true".
      final textual = TomGroupedRow({
        'one': '1',
        'zero': '0',
        'word': 'TRUE',
        'other': 'yes',
      });
      expect(textual.boolValue('one'), isTrue);
      expect(textual.boolValue('zero'), isFalse);
      expect(textual.boolValue('word'), isTrue);
      expect(textual.boolValue('other'), isFalse);
    });

    test('toString shows the row contents', () {
      expect(TomGroupedRow({'total': 7}).toString(), contains('total: 7'));
    });
  });

  group('TomGroupedSelect', () {
    late TomQuerySentenceCompiler compiler;
    late DbCol priority;
    late DbCol title;

    setUpAll(() {
      initializeReflection();
      compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
      priority =
          b.intF('priority', compiler.determineColumn('priority')) as DbCol;
      title = b.textF('title', compiler.determineColumn('title')) as DbCol;
    });

    TomGroupedSelect grouped({
      List<DbCol> groupBy = const [],
      required List<TomAggregate> aggregates,
      TomOperator<TomDbBool>? having,
      List<String> orderBy = const [],
      bool ascending = true,
      int top = 0,
    }) => TomGroupedSelect(
      [FixtureTaskRecord],
      query: b.eq(
        b.boolF('done', compiler.determineColumn('done')),
        b.boolOp(false),
      ),
      groupBy: groupBy,
      aggregates: aggregates,
      having: having,
      orderBy: orderBy,
      ascending: ascending,
      top: top,
    );

    test('renders group keys and aggregates as a named projection', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
      );
      expect(
        query.generateQuery(dialect),
        'SELECT fixture_task.priority AS priority, COUNT(*) AS total'
        ' FROM fixture_task'
        ' WHERE fixture_task.done = false'
        ' GROUP BY fixture_task.priority',
      );
    });

    test('an empty grouping aggregates the whole result set', () {
      final query = grouped(aggregates: [b.countAll('total')]);
      expect(query.generateQuery(dialect), isNot(contains('GROUP BY')));
    });

    test('HAVING renders after GROUP BY', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
        having: b.gt(b.countAll('total'), b.intOp(3)),
      );
      expect(
        query.generateQuery(dialect),
        endsWith(' GROUP BY fixture_task.priority HAVING COUNT(*) > 3'),
      );
    });

    test('ORDER BY and LIMIT follow HAVING', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
        orderBy: ['total'],
        ascending: false,
        top: 5,
      );
      expect(
        query.generateQuery(dialect),
        endsWith(' ORDER BY total DESC LIMIT 5'),
      );
    });

    test('projects group keys under their declared names', () {
      final query = grouped(
        groupBy: [priority, title],
        aggregates: [b.countAll('total')],
      );
      expect(query.projectionAliases, ['priority', 'title', 'total']);
    });

    test('carries the Dart type of every projected column', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total'), b.sum(priority, 'weight')],
      );
      expect(query.projectionTypes, {
        'priority': int,
        'total': int,
        'weight': double,
      });
    });

    test('binds parameters in statement-text order', () {
      final query = TomGroupedSelect(
        [FixtureTaskRecord],
        query: b.gt(priority, b.p<TomDbInt>('minPriority')),
        groupBy: [title],
        aggregates: [b.countOf(b.p<TomDbInt>('bonus'), 'n')],
        having: b.gt(b.countAll('total'), b.p<TomDbInt>('minCount')),
      );
      expect(query.getParameters(dialect), [
        'bonus',
        'minPriority',
        'minCount',
      ]);
    });

    test('reports the columns it reads outside an aggregate', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countOf(title, 'titles')],
      );
      expect(
        query.referencedColumns.map((c) => c.declaredName),
        containsAll(<String>['priority', 'done']),
      );
    });

    test('a select without aggregates is a DISTINCT select, not a group', () {
      expect(
        () => grouped(groupBy: [priority], aggregates: []),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.no_aggregates',
          ),
        ),
      );
    });

    test('two projections cannot share a result-column name', () {
      expect(
        () =>
            grouped(groupBy: [priority], aggregates: [b.countAll('priority')]),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.duplicate_alias',
          ),
        ),
      );
    });

    test('a group column the mapper cannot materialise is rejected', () {
      expect(
        () => grouped(
          groupBy: [
            b.intF('opaque', _opaqueColumn('fixture_task', 'opaque')) as DbCol,
          ],
          aggregates: [b.countAll('total')],
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.unmappable_group_column',
          ),
        ),
      );
    });

    test('ordering by something the query does not project is rejected', () {
      expect(
        () => grouped(
          groupBy: [priority],
          aggregates: [b.countAll('total')],
          orderBy: ['title'],
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.order_by_not_projected',
          ),
        ),
      );
    });

    test('HAVING on a bare ungrouped column is rejected', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
        having: b.eq(title, b.text('x')),
      );
      expect(
        () => query.generateQuery(dialect),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.having_on_ungrouped_field',
          ),
        ),
      );
    });

    test('HAVING on a group column is allowed', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
        having: b.gt(priority, b.intOp(2)),
      );
      expect(query.generateQuery(dialect), contains('HAVING'));
    });

    test('reports every field of all four clauses', () {
      // `getFields` is what a caller inspecting a compiled sentence sees, and
      // unlike `referencedColumns` it does not stop at an aggregate: a column
      // hidden inside SUM() is still a column the statement reads.
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countOf(title, 'titles')],
        having: b.gt(b.countAll('total'), b.intOp(3)),
      );
      expect(query.getFields(dialect), {
        'fixture_task.priority',
        'fixture_task.title',
        'fixture_task.done',
      });
    });

    test('a group key is read out of a row by its declared name', () {
      // The projection aliases a group key as its *declared* name, so `keyOf`
      // is the accessor that spares a caller from restating the alias — and
      // from getting it wrong when the column name and field name differ.
      final row = TomGroupedRow({'priority': 2, 'total': 9});
      expect(row.keyOf(priority), 2);
    });

    test('toString names the grouping and the HAVING', () {
      final query = grouped(
        groupBy: [priority],
        aggregates: [b.countAll('total')],
        having: b.gt(b.countAll('total'), b.intOp(3)),
      );
      expect(query.toString(), contains('priority'));
      expect(query.toString(), contains('having'));
    });
  });

  group('group query sentence', () {
    late TomQuerySentenceCompiler compiler;

    setUpAll(() {
      initializeReflection();
      compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
    });

    TomGroupedSelect compile(String sentence) =>
        compiler.compileQuerySentence(sentence) as TomGroupedSelect;

    test('compiles a count over a group key', () {
      final query = compile(
        'group count ( * ) as total over priority by done = :done',
      );
      expect(
        query.generateQuery(dialect),
        'SELECT fixture_task.priority AS priority, COUNT(*) AS total'
        ' FROM fixture_task'
        ' WHERE fixture_task.done = :done'
        ' GROUP BY fixture_task.priority',
      );
    });

    test('compiles several aggregates', () {
      final query = compile(
        'group count ( * ) as total , sum ( priority ) as weight over done by priority > 0',
      );
      expect(query.projectionAliases, ['done', 'total', 'weight']);
    });

    test('omitting over aggregates the whole result set', () {
      final query = compile('group count ( * ) as total by priority > 0');
      expect(query.groupBy, isEmpty);
      expect(query.generateQuery(dialect), isNot(contains('GROUP BY')));
    });

    test('having filters groups by projection alias', () {
      final query = compile(
        'group count ( * ) as total over priority by priority > 0 having total > 3',
      );
      expect(query.generateQuery(dialect), contains('HAVING COUNT(*) > 3'));
    });

    test('having binds a parameter against an aggregate', () {
      final query = compile(
        'group count ( * ) as total over priority by priority > :min having total > :minCount',
      );
      expect(query.getParameters(dialect), ['min', 'minCount']);
      expect(
        query.generateQuery(dialect),
        contains('HAVING COUNT(*) > :minCount'),
      );
    });

    test('distinct qualifies a counted column', () {
      final query = compile(
        'group count ( distinct priority ) as kinds over done by priority > 0',
      );
      expect(
        query.generateQuery(dialect),
        contains('COUNT(DISTINCT fixture_task.priority) AS kinds'),
      );
    });

    test('min picks the node matching the column type', () {
      final query = compile(
        'group min ( priority ) as lo over done by priority > 0',
      );
      expect(query.aggregates.single, isA<Min<TomDbInt, int>>());
    });

    test('max over a string column keeps the string type', () {
      final query = compile(
        'group max ( title ) as hi over done by priority > 0',
      );
      expect(query.aggregates.single.valueType, String);
    });

    test('order by an alias survives the compile', () {
      final query = compile(
        'group count ( * ) as total over priority by priority > 0 order by total desc',
      );
      expect(query.generateQuery(dialect), endsWith(' ORDER BY total DESC'));
    });

    test('order by names the projection alias, not the column', () {
      // Deliberately unlike TomSelect and TomDelete, which resolve their sort
      // terms to column names. A grouped select orders over what it projects:
      // an aggregate alias has no column at all, and a group column is
      // projected `AS <declaredName>`, so the alias is the name in scope.
      // Resolving these to column names would break both.
      final query = compile(
        'group count ( * ) as total over priority '
        'by priority > 0 order by priority',
      );
      final sql = query.generateQuery(dialect);
      expect(sql, endsWith(' ORDER BY priority ASC'));
      // The guard that makes this safe without a column lookup: a term the
      // query does not project is refused rather than interpolated.
      expect(
        () => compile(
          'group count ( * ) as total over priority '
          'by priority > 0 order by nosuchthing',
        ).generateQuery(dialect),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'grouped_query.select.order_by_not_projected',
          ),
        ),
      );
    });

    test('top caps the grouped result', () {
      final query = compile(
        'group top 5 count ( * ) as total over priority by priority > 0',
      );
      expect(query.generateQuery(dialect), endsWith(' LIMIT 5'));
    });

    test('an unknown aggregate function is rejected', () {
      expect(
        () =>
            compile('group median ( priority ) as m over done by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.unknown_function',
          ),
        ),
      );
    });

    test('a missing alias is rejected', () {
      expect(
        () => compile('group count ( * ) over priority by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.unexpected_token',
          ),
        ),
      );
    });

    test('star is only valid for a plain count', () {
      expect(
        () => compile('group sum ( * ) as s over priority by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.star_only_for_count',
          ),
        ),
      );
    });

    test('an aggregate that stops after the bracket is rejected', () {
      // The projection is parsed on its own, up to `over`/`by`, so a sentence
      // that trails off mid-aggregate leaves the parser at the end of *its*
      // tokens rather than at a token it can complain about. It has to say so
      // instead of reading past them.
      expect(
        () => compile('group count ( by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.missing_argument',
          ),
        ),
      );
    });

    test('an aggregate that stops after AS is rejected', () {
      expect(
        () => compile('group count ( * ) as by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.missing_alias',
          ),
        ),
      );
    });

    test('an over clause naming no field is rejected', () {
      // Distinct from omitting `over` altogether, which is legal and groups the
      // whole result set. Writing the keyword and then nothing is a truncated
      // sentence, and reading it as "group over everything" would silently
      // return one row where the author asked for many.
      expect(
        () => compile('group count ( * ) as total over , by priority > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile_grouped.empty_over_clause',
          ),
        ),
      );
    });

    test('distinct is meaningless for min/max and is rejected', () {
      expect(
        () => compile(
          'group min ( distinct priority ) as lo over done by priority > 0',
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.parse_aggregates.distinct_not_supported',
          ),
        ),
      );
    });

    test('having without a predicate is rejected', () {
      expect(
        () => compile(
          'group count ( * ) as total over priority by priority > 0 having',
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile_grouped.empty_having',
          ),
        ),
      );
    });

    test('the other sentence kinds still compile unchanged', () {
      expect(
        compiler.compileQuerySentence('find by priority > 0'),
        isA<TomSelect>(),
      );
      expect(
        compiler.compileQuerySentence('count by priority > 0'),
        isA<TomCount>(),
      );
    });
  });

  group('min/max over the temporal column types', () {
    // `FixtureTaskRecord` has no date column, so the two temporal arms of the
    // min/max dispatch cannot be reached through the group above. They are the
    // arms that matter most for an extremum: "the newest row in each group" is
    // the ordinary reason to write MAX at all, and an unmapped arm would refuse
    // the sentence as an unsupported column type rather than compile it.
    late TomQuerySentenceCompiler exports;

    setUpAll(() {
      initializeReflection();
      exports = TomQuerySentenceCompiler([FixtureExportRecord]);
    });

    TomGroupedSelect compile(String sentence) =>
        exports.compileQuerySentence(sentence) as TomGroupedSelect;

    test('max over a timestamp keeps the DateTime value type', () {
      final query = compile(
        'group max ( createdAt ) as newest over done by id > 0',
      );
      expect(query.aggregates.single, isA<Max<TomDbDateTime, DateTime>>());
      expect(query.aggregates.single.valueType, DateTime);
    });

    test('min over a timestamp keeps the DateTime value type', () {
      final query = compile(
        'group min ( createdAt ) as oldest over done by id > 0',
      );
      expect(query.aggregates.single, isA<Min<TomDbDateTime, DateTime>>());
    });

    test('a date-only column is its own SQL type, still read as DateTime', () {
      // `TomZonedDate` renders as a DATE, so the node carries `TomDbDate` — but
      // the value the mapper materialises is a `DateTime` all the same, which
      // is what spares a caller from a second date class.
      final query = compile(
        'group max ( tagDay ) as latest over done by id > 0',
      );
      expect(query.aggregates.single, isA<Max<TomDbDate, DateTime>>());
      expect(query.aggregates.single.valueType, DateTime);
    });
  });
}
