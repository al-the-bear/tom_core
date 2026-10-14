/// Pins every error key the object-persistence module raises, by its full
/// literal, against the smallest input that reaches it.
///
/// A caller tells the persistence module's refusals apart by
/// [TomServerException.key] — a request handler maps a query-sentence syntax
/// error to a bad request and a missing data source to a server fault, and it
/// can only do that by reading the key. A key that no test names is a failure
/// mode nobody checks: it can be renamed, merged with a neighbour, or stop
/// being raised at all (the branch now throwing a `TypeError` or a different
/// key) without one assertion turning red. The sibling `query_sentence_*`
/// files pin each feature's behaviour and often match only a key's tail; this
/// file states every key whole, so the literal itself is under test.
///
/// Each table maps a key to the input that raises it. The inputs are the
/// smallest ones found to reach the branch, and the comments say why the
/// shape is needed where it is not obvious.
///
/// Connection-free. The one repository path below runs against the scripted
/// data source, and is refused before any statement is built.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

/// Matches a [TomServerException] carrying exactly [key].
Matcher _keyed(String key) =>
    isA<TomServerException>().having((e) => e.key, 'key', key);

void main() {
  setUpAll(initializeReflection);

  group('query sentence compiler', () {
    late TomQuerySentenceCompiler compiler;

    setUpAll(() {
      compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
    });

    // FixtureTaskRecord: `id` and `priority` are int, `title` is text, `done`
    // is bool. Most refusals below hinge on that mix of types.
    const refusals = <String, String>{
      // Options.
      'query_sentence_compiler.compile.skip_without_top':
          'find skip 2 by id = 1',
      // Grouped projection: MIN/MAX are typed by their operand, and a bool
      // column has no MIN/MAX node.
      'query_sentence_compiler.parse_aggregates.unsupported_min_max_column':
          'group min ( done ) as m by id > 0',
      // Order-by clause.
      'query_sentence_compiler.analyse_order_by.order_clause_missing_fields':
          'find by id = 1 order by',
      'query_sentence_compiler.analyse_order_by.direction_without_field':
          'find by id = 1 order by desc',
      // Statement structure.
      'query_sentence_compiler.build_query.unenclosing_closing_bracket':
          'find by ( )',
      'query_sentence_compiler.build_query.and_without_current_operation':
          'find by and id = 1',
      'query_sentence_compiler.build_query.or_without_current_operation':
          'find by or id = 1',
      'query_sentence_compiler.build_query.double_not_usage':
          'find by not not done = TRUE',
      'query_sentence_compiler.build_query.empty_invalid_query_nothing_built':
          'find by',
      // Operators with nothing in front of them.
      'query_sentence_compiler.build_expression.parameter_without_column':
          'find by :p',
      'query_sentence_compiler.build_expression.is_not_null_test_without_column':
          'find by is not null',
      'query_sentence_compiler.build_expression.is_null_test_without_column':
          'find by is null',
      'query_sentence_compiler.build_expression.is_not_in_test_without_column':
          'find by is not in ( 1 )',
      'query_sentence_compiler.build_expression.is_in_test_without_column':
          'find by is in ( 1 )',
      'query_sentence_compiler.build_expression.not_like_test_without_column':
          'find by not like :p',
      'query_sentence_compiler.build_expression.like_test_without_column':
          'find by like :p',
      'query_sentence_compiler.build_expression.regexp_test_without_column':
          'find by regexp :p',
      // Pattern operators on a column that is not text.
      'query_sentence_compiler.build_expression.not_like_invalid_column_type':
          'find by id not like :p',
      'query_sentence_compiler.build_expression.like_invalid_column_type':
          'find by id like :p',
      'query_sentence_compiler.build_expression.regexp_invalid_column_type':
          'find by id regexp :p',
      // A boolean operator where a non-boolean operand is expected. The right
      // side of `title like` is parsed as text, so each predicate written there
      // is refused for producing a bool.
      'query_sentence_compiler.build_expression.is_not_null_invalid_type_expected':
          'find by title like is not null',
      'query_sentence_compiler.build_expression.is_null_invalid_type_expected':
          'find by title like is null',
      'query_sentence_compiler.build_expression.is_not_in_invalid_type_expected':
          'find by title like is not in ( :p )',
      'query_sentence_compiler.build_expression.is_in_invalid_type_expected':
          'find by title like is in ( :p )',
      'query_sentence_compiler.build_expression.not_like_invalid_type_expected':
          'find by title like not like :p',
      'query_sentence_compiler.build_expression.like_invalid_type_expected':
          'find by title like like :p',
      'query_sentence_compiler.build_expression.regexp_invalid_type_expected':
          'find by title like regexp :p',
      'query_sentence_compiler.build_expression.eq_invalid_type_expected':
          'find by title like = :p',
      'query_sentence_compiler.build_expression.not_invalid_type_expected':
          'find by title = not TRUE',
      // Negation inside an operand: the right side of `done =` is a bool
      // operand, which takes one NOT but not two.
      'query_sentence_compiler.build_expression.double_not_usage':
          'find by done = not not TRUE',
      // Literals of the wrong type for the column they are compared with.
      'query_sentence_compiler.build_expression.string_literal_invalid_type_expected':
          "find by id = 'a'",
      'query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_true':
          'find by title = TRUE',
      'query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_false':
          'find by title = FALSE',
      // A column compared with a column of another type.
      'query_sentence_compiler.build_expression.column-type-mismatch_after_creation_second_column':
          'find by id = title',
      // The first-column branch with a non-bool operand type: only a `having`
      // comparison against an aggregate enters it, because the aggregate
      // carries no column. `n > priority = 1` reads `priority = 1` as the
      // int operand of `>`, and a predicate is not an int.
      'query_sentence_compiler.build_expression.column-type-mismatch_after_creation_new_column':
          'group count ( * ) as n by id > 0 having n > priority = 1',
      'query_sentence_compiler.build_expression.sentence_ended_early':
          'find by title =',
      // IS IN lists.
      'query_sentence_compiler.get_in_options.boolean_column_in_not_allowed':
          'find by done is in ( TRUE )',
      'query_sentence_compiler.get_in_options.unterminated_list':
          'find by id is in ( 1',
      'query_sentence_compiler.get_in_options.empty_list':
          'find by id is in ( )',
      // Column resolution is the annotation analyzer's, reached through a
      // sentence naming a field the entity does not have.
      'annotation_analyzer.determine_column.no_column_match':
          'find by nosuch = 1',
    };

    for (final MapEntry(key: key, value: sentence) in refusals.entries) {
      test('[$sentence] is refused with $key', () {
        expect(
          () => compiler.compileQuerySentence(sentence),
          throwsA(_keyed(key)),
        );
      });
    }
  });

  group('page window', () {
    const windows = <String, ({int limit, int offset})>{
      'paging.window.negative_offset': (limit: 0, offset: -1),
      'paging.window.negative_limit': (limit: -1, offset: 0),
      'paging.window.offset_without_limit': (limit: 0, offset: 2),
    };

    for (final MapEntry(key: key, value: window) in windows.entries) {
      test('$window is refused with $key', () {
        expect(
          () => TomPageRequest.assertWindow(
            limit: window.limit,
            offset: window.offset,
          ),
          throwsA(_keyed(key)),
        );
      });
    }
  });

  group('annotation analyzer', () {
    // The analyzer memoises per type, and these fixtures are only ever
    // analysed here; resetting keeps each test independent of the others'
    // order.
    setUp(TomAnnotationAnalyzer.reset);

    test('a type that is not a class is refused with not_a_class', () {
      expect(
        () => TomAnnotationAnalyzer.findMirror(dynamic),
        throwsA(_keyed('annotation_analyzer.find_mirror.not_a_class')),
      );
    });

    test(
      'reflection never initialized is refused with reflection_failed',
      () async {
        // Reflection is per-isolate, so a fresh isolate that never calls
        // `initializeReflection()` is the real deployment fault.
        final key = await Isolate.run(() {
          try {
            TomAnnotationAnalyzer.findMirror(FixtureTaskRecord);
            return 'findMirror returned without raising';
          } on TomServerException catch (error) {
            return error.key;
          }
        });
        expect(key, 'annotation_analyzer.find_mirror.reflection_failed');
      },
    );

    test('@TomDbColumn on a getter is refused by name', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureColumnGetterRecord,
        ),
        throwsA(
          _keyed(
            'annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable',
          ),
        ),
      );
    });

    test('@TomReference on a method is refused by name', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureReferenceMethodRecord,
        ),
        throwsA(
          _keyed(
            'annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable_for_reference',
          ),
        ),
      );
    });

    test('a column on a class with no @TomDbTable is refused', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureTablelessColumnRecord,
        ),
        throwsA(
          _keyed('annotation_analyzer.get_persistent_columns.no_table_info'),
        ),
      );
    });
  });

  group('repository', () {
    setUp(() {
      registerScriptedDatasource();
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
    });
    tearDown(() {
      TomResourceKeyProtection.restoreDefaults();
      unregisterScriptedDatasource();
    });

    test('a grouped query over a masked column is refused', () async {
      // `secretAttachment` is graded by an authKey this principal does not
      // hold. Grouping over it would disclose the masked values' distribution,
      // so the repository refuses before it builds a statement.
      final query =
          TomQuerySentenceCompiler([
                FixtureDocumentRecord,
              ]).compileQuerySentence(
                'group count ( * ) as n over secretAttachment by id > 0',
              )
              as TomGroupedSelect;
      final principal = TomPrincipal(
        user: TomUser(id: '3', username: 'grace'),
        authenticated: true,
        aci: TomAccessControlInformation(resourceKeys: ['fixture.other']),
      );
      await expectLater(
        runZoned(
          () => FixtureDocumentRepository().findGroupedByQuery(query, const {}),
          zoneValues: {TomPrincipal: principal},
        ),
        throwsA(_keyed('crud_repository.grouped.masked_column')),
      );
    });
  });
}
