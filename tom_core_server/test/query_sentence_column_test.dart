/// Tests for how [TomQuerySentenceCompiler] types the **columns** named in a
/// query sentence.
///
/// A sentence addresses a column by name and the compiler has to decide which
/// `DbCol` node represents it. It reads the entity's explicit
/// `@TomDbColumn(columnType: ...)` when one is given, and otherwise infers from
/// the field's *declared Dart type* — and a `DateTime` field with no explicit
/// `columnType` must not fall out of that inference and leave the compiler
/// reporting the column as untypeable.
///
/// Both routes end in the same answer, which the column node and the bind
/// parameter then dispatch on separately. That is the arrangement worth
/// testing: for as long as the two dispatches read *different* values, a type
/// could be handled by one and not the other, and every defect this file
/// records was one member of such a set being missed.
///
/// Connection-free: only the entity's annotations are read, so neither fixture
/// needs a table. [FixtureExportRecord] is used for the inferred route rather
/// than `FixtureTaskRecord` because it declares every column family — and in
/// particular a `DateTime`, which the task fixture does not have. That absence
/// is why the bug survived the existing suites, and it is why the fixture
/// gained a `TomZonedTime` field: a family no fixture declares is a family no
/// suite can reach, however completely the compiler handles it.
/// [FixtureColumnTypeRecord] is the same argument one level up — until it
/// existed, no entity in the workspace wrote `columnType:` at all.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureColumnTypeRecord, FixtureExportRecord;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  late TomQuerySentenceCompiler compiler;
  late TomQuerySentenceCompiler explicit;
  final dialect = MariadbSqlDialect();

  setUpAll(() {
    initializeReflection();
    compiler = TomQuerySentenceCompiler([FixtureExportRecord]);
    // A compiler of its own rather than a second entity on the first: the two
    // fixtures share column names (`id`), and resolving a name against two
    // tables is a different question from the one this file asks.
    explicit = TomQuerySentenceCompiler([FixtureColumnTypeRecord]);
  });

  TomSelect select(String sentence) =>
      compiler.compileQuerySentence(sentence) as TomSelect;

  TomSelect selectExplicit(String sentence) =>
      explicit.compileQuerySentence(sentence) as TomSelect;

  group('column typing from the declared Dart type', () {
    // One test per column family, because the defect was a single missing
    // `return` in one arm of the switch: a test that only proved *some* column
    // compiles would have passed throughout.
    test('a String column compiles', () {
      expect(
        select('find by title = :title').generateQuery(dialect),
        contains('fixture_export.title = :title'),
      );
    });

    test('an int column compiles', () {
      expect(
        select('find by id > :id').generateQuery(dialect),
        contains('fixture_export.id > :id'),
      );
    });

    test('a double column compiles', () {
      // The second occurrence of the same defect, in a different family: the
      // declared-type switch enumerated String/int/bool/DateTime/TomZonedDate
      // and simply omitted `double`, so a decimal column was untypeable no
      // matter how it was written. `DoubleCol` existed and `_createAggregate`
      // already had an arm for it — nothing could ever produce one.
      expect(
        select('find by amount > :amount').generateQuery(dialect),
        contains('fixture_export.amount > :amount'),
      );
    });

    test('a bool column compiles', () {
      expect(
        select('find by done = :done').generateQuery(dialect),
        contains('fixture_export.done = :done'),
      );
    });

    test('a DateTime column compiles', () {
      // The arm that is easiest to get wrong: construct the `DateTimeCol` and
      // omit the return, and control falls out of the switch into the "could
      // not determine type" throw — making any sentence with a timestamp
      // predicate uncompilable unless the entity spells out `columnType:` by
      // hand. Nothing in the arm itself looks incomplete.
      expect(
        select('find by created_at >= :from').generateQuery(dialect),
        contains('fixture_export.created_at >= :from'),
      );
    });

    test('a TomZonedDate column compiles', () {
      expect(
        select('find by tag_day = :day').generateQuery(dialect),
        contains('fixture_export.tag_day = :day'),
      );
    });

    test('a TomZonedTime column compiles', () {
      // The third occurrence of the same shape, and the one that had never
      // been half-written: `TomZonedTime` appeared in the migration type map
      // and nowhere in the compiler, so a column a migration could create was
      // addressable by no sentence at all.
      expect(
        select('find by remind_at = :at').generateQuery(dialect),
        contains('fixture_export.remind_at = :at'),
      );
    });

    test('a DateTime column orders and ranges in one sentence', () {
      // The shape the ops server's report query actually uses: a half-open
      // window plus an ordering on the same timestamp column. Asserted as a
      // whole because the column node is built once per *mention*, so a
      // sentence naming it three times exercises three call sites.
      final query = select(
        'find by created_at >= :from and created_at < :to order by created_at',
      ).generateQuery(dialect);
      expect(query, contains('fixture_export.created_at >= :from'));
      expect(query, contains('fixture_export.created_at < :to'));
      expect(query, contains('ORDER BY fixture_export.created_at'));
    });

    test('an unknown column is still rejected', () {
      // The throw the fix must not remove: falling through remains an error,
      // it just no longer catches a type the switch was written to handle.
      //
      // The refusal comes from the annotation analyzer rather than the
      // compiler: naming a column is the one thing in a sentence the compiler
      // cannot decide alone, so it asks the entity's annotations and reports
      // what they answer.
      expect(
        () => compiler.compileQuerySentence('find by nosuch = :x'),
        throwsA(isA<TomAnnotationAnalyzerSyntaxException>()),
      );
    });
  });

  // Typing a column is only the first of three switches a predicate passes
  // through: the column node, the bind parameter, and the comparison that
  // joins them each dispatch on the type independently. `double` was absent
  // from all three, so proving one arm reachable proves nothing about the
  // next — hence one test per operator rather than one per type.
  group('double columns across the predicate forms', () {
    test('every comparison operator accepts a double column', () {
      for (final (symbol, sentence) in const [
        ('=', 'find by amount = :amount'),
        ('<>', 'find by amount <> :amount'),
        ('<', 'find by amount < :amount'),
        ('<=', 'find by amount <= :amount'),
        ('>', 'find by amount > :amount'),
        ('>=', 'find by amount >= :amount'),
      ]) {
        expect(
          select(sentence).generateQuery(dialect),
          contains('fixture_export.amount $symbol :amount'),
          reason: 'the $symbol comparison should type a double column',
        );
      }
    });

    test('a double column binds its parameter as a decimal', () {
      // The parameter's *type* is what carries the value across the bind
      // boundary; typing it as text or int would round-trip a decimal wrong
      // even where the SQL looks right. Asserted on the node, because the
      // rendered `:amount` is identical for every family.
      final query = select('find by amount >= :floor');
      expect(query.getParameters(dialect), ['floor']);
      expect(query.query, isA<Gte<TomDbDouble>>());
    });

    test('a double column takes IS NULL and IS NOT NULL', () {
      expect(
        select('find by amount is null').generateQuery(dialect),
        contains('fixture_export.amount IS NULL'),
      );
      expect(
        select('find by amount is not null').generateQuery(dialect),
        contains('fixture_export.amount IS NOT NULL'),
      );
    });

    test('a double column takes IS IN', () {
      expect(
        select('find by amount is in ( :a , :b )').generateQuery(dialect),
        contains('fixture_export.amount IN (:a,:b)'),
      );
    });

    test('a double column orders and combines with another predicate', () {
      final query = select(
        'find by amount >= :floor and done = :done order by amount desc',
      ).generateQuery(dialect);
      expect(query, contains('fixture_export.amount >= :floor'));
      expect(query, contains('ORDER BY fixture_export.amount DESC'));
    });
  });

  // The aggregate switch dispatches on the *node* `_createColumn` produced, so
  // its `DoubleCol` arm was unreachable for as long as nothing could build one:
  // dead code that looked handled. These are what make it live.
  group('aggregates over a double column', () {
    test('min over a double column yields a double-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group min ( amount ) as lo over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Min<TomDbDouble, double>>());
      expect(
        query.generateQuery(dialect),
        contains('MIN(fixture_export.amount) AS lo'),
      );
    });

    test('max over a double column yields a double-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group max ( amount ) as hi over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Max<TomDbDouble, double>>());
      expect(query.aggregates.single.valueType, double);
    });
  });

  // The same six dispatches, for the family that had none of them. `double`
  // was missing from three; a time of day was missing from all six plus the
  // node, the literal, the builder factory and the dialect rendering — so
  // these are what make the type exist rather than what make it reachable.
  group('time-of-day columns across the predicate forms', () {
    test('every comparison operator accepts a time-of-day column', () {
      for (final (symbol, sentence) in const [
        ('=', 'find by remind_at = :at'),
        ('<>', 'find by remind_at <> :at'),
        ('<', 'find by remind_at < :at'),
        ('<=', 'find by remind_at <= :at'),
        ('>', 'find by remind_at > :at'),
        ('>=', 'find by remind_at >= :at'),
      ]) {
        expect(
          select(sentence).generateQuery(dialect),
          contains('fixture_export.remind_at $symbol :at'),
          reason: 'the $symbol comparison should type a time-of-day column',
        );
      }
    });

    test('a time-of-day column binds its parameter as a time', () {
      // Typed as `TomDbTime` rather than `TomDbDateTime`: the two render a
      // bound value differently — a whole instant against a column that holds
      // a clock reading — so the parameter's type is what decides whether the
      // right value reaches the column, not the identical `:at` in the SQL.
      final query = select('find by remind_at >= :at');
      expect(query.getParameters(dialect), ['at']);
      expect(query.query, isA<Gte<TomDbTime>>());
    });

    test('a time-of-day column takes IS NULL and IS NOT NULL', () {
      expect(
        select('find by remind_at is null').generateQuery(dialect),
        contains('fixture_export.remind_at IS NULL'),
      );
      expect(
        select('find by remind_at is not null').generateQuery(dialect),
        contains('fixture_export.remind_at IS NOT NULL'),
      );
    });

    test('a time-of-day column takes IS IN', () {
      expect(
        select('find by remind_at is in ( :a , :b )').generateQuery(dialect),
        contains('fixture_export.remind_at IN (:a,:b)'),
      );
    });

    test('a time-of-day column orders and combines with another predicate', () {
      final query = select(
        'find by remind_at >= :at and done = :done order by remind_at desc',
      ).generateQuery(dialect);
      expect(query, contains('fixture_export.remind_at >= :at'));
      expect(query, contains('ORDER BY fixture_export.remind_at DESC'));
    });

    test('a time of day can be written inline as a literal', () {
      // `HH:MM:SS` is the one literal shape whose leading character is shared
      // with nothing — `:` opens a bind parameter, and a parameter is
      // recognised by its *first* character, which a time never is. Rendered
      // as the clock reading alone: the epoch day the token is parsed onto is
      // scaffolding for Dart's lack of a time-only value and must not reach
      // the SQL.
      expect(
        select('find by remind_at >= 09:30:00').generateQuery(dialect),
        contains("fixture_export.remind_at >= '09:30:00'"),
      );
    });

    test('a time literal is refused against a column of another type', () {
      // The literal kinds are ordered most-specific-first and every pattern is
      // anchored, so a token belongs to exactly one kind; what remains is that
      // the kind has to match the column. Refusing here is what keeps the
      // ordering honest — an unreachable kind would show up as the *wrong*
      // rejection rather than as a missing one.
      expect(
        () => compiler.compileQuerySentence('find by title = 09:30:00'),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('a datetime literal is still read as a datetime', () {
      // The guard on the new entry's placement: a time pattern that also
      // matched the tail of a timestamp, or one ordered before the datetime,
      // would claim this token and then reject it for being the wrong type.
      expect(
        select(
          'find by created_at >= 2026-01-02T09:30:00Z',
        ).generateQuery(dialect),
        contains("fixture_export.created_at >= '2026-01-02 09:30:00.000000'"),
      );
    });
  });

  // The other route into the same answer, and the one that had never been
  // taken. `@TomDbColumn(columnType: ...)` exists so an entity can say that a
  // column is stored as something other than its Dart declaration implies —
  // and no entity in this package, its examples or the sample servers had ever
  // said so. Both halves of the branch were therefore dead: the honouring, and
  // the refusal that should close it.
  group('column typing from an explicit @TomDbColumn(columnType:)', () {
    test('an explicit columnType is honoured over the declared Dart type', () {
      // `legacy_rank` is declared `String?` and annotated `columnType:
      // TomDbInt`. Inference would make it a text column; the annotation makes
      // it an integer one. The compiled node says which won.
      final query = selectExplicit('find by legacy_rank >= :rank');
      expect(query.query, isA<Gte<TomDbInt>>());
      expect(
        query.generateQuery(dialect),
        contains('fixture_column_type.legacy_rank >= :rank'),
      );
    });

    test('an explicit columnType decides which literals the column admits', () {
      // The same claim without reading the node, because admissibility is what
      // the typing is *for*: a literal is checked against the column's compiled
      // type, so an integer standing against a `String?`-declared field is only
      // accepted if the annotation was honoured, and a string literal against
      // it is only refused for the same reason.
      expect(
        selectExplicit('find by legacy_rank >= 5').generateQuery(dialect),
        contains('fixture_column_type.legacy_rank >= 5'),
      );
      expect(
        () => explicit.compileQuerySentence("find by legacy_rank = 'five'"),
        throwsA(isA<TomQuerySyntaxException>()),
        reason:
            'a text literal must not be admitted against a column the entity '
            'declares as integer-typed',
      );
    });

    test('a bare Dart type is honoured in columnType too', () {
      // `columnType:` takes both spellings — a `TomDb…` box and a plain Dart
      // type — and they enter the same map, so a fixture exercising only one
      // would leave the other's keys unproven. `legacy_flag` is declared `int?`
      // and annotated `columnType: bool`.
      final query = selectExplicit('find by legacy_flag = :flag');
      expect(query.query, isA<Eq<TomDbBool>>());
      expect(
        () => explicit.compileQuerySentence('find by legacy_flag = 5'),
        throwsA(isA<TomQuerySyntaxException>()),
        reason:
            'an integer literal must not be admitted against a column the '
            'entity declares as boolean-typed, however the field is declared',
      );
    });

    test('the bind parameter is typed from the explicit type as well', () {
      // The dispatch that used to disagree. A predicate types its column from
      // the annotation and then binds a parameter against it, and the parameter
      // is cast to the type the column gave the comparison — so while the
      // parameter was typed from the *declared* Dart type instead, every one of
      // these sentences died on a bare `TypeError` naming neither the column
      // nor the annotation. Compiling at all is the assertion; the node type
      // says which answer both dispatches reached.
      final query = selectExplicit('find by legacy_rank >= :rank');
      expect(query.getParameters(dialect), ['rank']);
      expect(query.query, isA<Gte<TomDbInt>>());
    });

    test('a column with no explicit columnType is still inferred', () {
      // The control. Precedence is only meaningful if the fallback still
      // happens, and it has to still happen *in an entity that overrides
      // elsewhere* — a per-column decision, not a per-entity mode.
      expect(
        selectExplicit('find by label = :label').query,
        isA<Eq<TomDbString>>(),
      );
    });

    test('an unsupported columnType is refused, not silently inferred', () {
      // `span` is declared `String?` and annotated `columnType: Duration`, a
      // type no column can hold. The explicit switch used to have no terminal
      // arm, so an unrecognised type fell through into the declared-type
      // inference: the entity said the column was one thing, the compiler
      // built another, and nothing said so. That fails open — the first symptom
      // is a value in a column of the wrong kind — which is why an
      // uninterpretable `columnType:` is now an error rather than a hint.
      expect(
        () => explicit.compileQuerySentence('find by span = :span'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.create_column.failed',
          ),
        ),
      );
    });

    test('an aggregate over an explicitly typed column takes that type', () {
      // The fourth dispatch: `_createAggregate` switches on the *node* the
      // column dispatch produced, so it inherits the annotation without reading
      // it. Asserted because inheriting is a property of the arrangement rather
      // than something written down anywhere.
      final query =
          explicit.compileQuerySentence(
                'group max ( legacy_rank ) as hi over label by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Max<TomDbInt, int>>());
      expect(
        query.generateQuery(dialect),
        contains('MAX(fixture_column_type.legacy_rank) AS hi'),
      );
    });
  });

  group('aggregates over a time-of-day column', () {
    test('min over a time-of-day column yields a time-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group min ( remind_at ) as earliest over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Min<TomDbTime, DateTime>>());
      expect(
        query.generateQuery(dialect),
        contains('MIN(fixture_export.remind_at) AS earliest'),
      );
    });

    test('max over a time-of-day column yields a time-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group max ( remind_at ) as latest over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Max<TomDbTime, DateTime>>());
      expect(query.aggregates.single.valueType, DateTime);
    });
  });
}
