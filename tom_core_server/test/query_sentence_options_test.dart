/// Tests for the options a query sentence carries besides its predicate, and
/// for which kind of sentence takes which.
///
/// There are four — `distinct`, the row cap, the skip, and the trailing
/// `order by` — and four kinds that may carry them. The compiler parses the
/// four once and then asks one question per option: does this kind permit it?
/// A kind that does not refuses **by name**.
///
/// What a per-kind condition leaves out is what this file is mostly about, and
/// two of its cases are there because nothing asked the question at all. An
/// option no rule mentions is accepted and dropped — `delete distinct by …`
/// compiles and the `distinct` goes nowhere — and a word that names no option
/// is skipped along with its argument, so `find frist 5 by …` returns the whole
/// set while reading as though it had capped. Both are the failure the guide's
/// own promise denies: never accepted and then ignored.
///
/// The matrix below is asserted in **both** directions for every one of the
/// sixteen pairs: a permitted option must reach the rendered SQL, and a refused
/// one must raise with its documented key. `doc/object_persistence.md`
/// §Which kind takes which option carries the same matrix, and it is read back
/// here — so the table, the compiler and this file cannot drift apart without
/// one of them failing.
///
/// Connection-free: only the entity's annotations are read.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureExportRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// One option, as it is written and as it shows up in the SQL.
class _Option {
  const _Option({
    required this.name,
    required this.before,
    required this.after,
    required this.rendered,
    required this.refusalKey,
    this.afterByKind = const {},
    this.maskedBy = const {},
  });

  /// The name the guide's table uses in its first column.
  final String name;

  /// What the option writes before `by`. A skip carries a cap because a skip
  /// without one is refused for every kind, which would hide the answer under
  /// a different rejection.
  final String before;

  /// What it writes after the predicate.
  final String after;

  /// What it writes after the predicate for one kind, where the default will
  /// not do. Only `group` needs it: a grouped select may order only by what it
  /// projects, which is a rule of the grouped kind rather than of the option.
  final Map<String, String> afterByKind;

  /// What must appear in the rendered SQL when the kind permits it.
  final String rendered;

  /// The key tail the refusing kind raises.
  final String refusalKey;

  /// Where a kind's refusal of this option is *masked* by its refusal of
  /// another one written in the same sentence, the key it raises instead.
  ///
  /// One cell needs it, and it is a property of the grammar rather than of
  /// this file: a skip needs a cap, a count refuses caps, so a `count` can
  /// never reach its own skip refusal. The cell is still `no` — it is declared,
  /// and it is what a reader has to be told — but the key it raises is the
  /// cap's, and writing that down is better than either weakening the
  /// assertion or pretending the row is reachable.
  final Map<String, String> maskedBy;
}

const _options = [
  _Option(
    name: '`distinct`',
    before: 'distinct',
    after: '',
    rendered: 'DISTINCT',
    refusalKey: 'distinct_unsupported_for_kind',
  ),
  _Option(
    name: '`first N` / `top N`',
    before: 'top 2',
    after: '',
    rendered: 'LIMIT 2',
    refusalKey: 'top_unsupported_for_count',
  ),
  _Option(
    name: '`skip M` / `offset M`',
    before: 'top 2 skip 4',
    after: '',
    rendered: 'OFFSET 4',
    refusalKey: 'skip_unsupported_for_kind',
    maskedBy: {'count': 'top_unsupported_for_count'},
  ),
  _Option(
    name: '`order by …`',
    before: '',
    after: 'order by id desc',
    afterByKind: {'group': 'order by total desc'},
    rendered: 'ORDER BY',
    refusalKey: 'order_by_unsupported_for_count',
  ),
];

/// The predicate each kind is given, and what the kind writes besides it.
const _kinds = {
  'find': '',
  'group': 'count ( * ) as total over title',
  'count': '',
  'delete': '',
};

void main() {
  late TomQuerySentenceCompiler compiler;
  final dialect = MariadbSqlDialect();

  setUpAll(() {
    initializeReflection();
    compiler = TomQuerySentenceCompiler([FixtureExportRecord]);
  });

  String sentence(String kind, _Option option) => [
    kind,
    option.before,
    _kinds[kind]!,
    'by id > 1',
    option.afterByKind[kind] ?? option.after,
  ].where((part) => part.isNotEmpty).join(' ');

  /// The guide's matrix, as `{option name: {kind: permitted}}`.
  late Map<String, Map<String, bool>> guideMatrix;

  setUpAll(() {
    final guide = File('doc/object_persistence.md').readAsStringSync();
    final start = guide.indexOf('### Which kind takes which option');
    expect(start, isNot(-1), reason: 'the guide section was renamed');
    final end = guide.indexOf('\n### ', start + 1);
    final section = guide.substring(start, end == -1 ? guide.length : end);

    // The first table only: the two below it list the refusals, not the grid.
    final rows = section
        .split('\n')
        .where((line) => line.startsWith('| '))
        .toList();
    final header = rows.first.split('|').map((c) => c.trim()).toList();
    final kinds = header.sublist(2, 6).map((c) => c.replaceAll('`', ''));
    guideMatrix = {
      for (final row in rows.skip(2).take(_options.length))
        row.split('|')[1].trim(): {
          for (final (index, kind) in kinds.indexed)
            kind: row.split('|')[index + 2].trim() == 'yes',
        },
    };
  });

  group('the guide states a matrix this suite can check', () {
    test('it names every kind and every option, once', () {
      expect(guideMatrix.keys.toSet(), _options.map((o) => o.name).toSet());
      for (final row in guideMatrix.values) {
        expect(row.keys.toSet(), _kinds.keys.toSet());
      }
    });

    test('it is not all one answer', () {
      // A grid of sixteen `yes` would satisfy every permitted-case test below
      // and no refusal case, and the suite would still look thorough.
      final answers = guideMatrix.values.expand((row) => row.values).toSet();
      expect(answers, {true, false});
    });
  });

  group('a permitted option reaches the SQL', () {
    for (final kind in _kinds.keys) {
      for (final option in _options) {
        test('$kind takes ${option.name}', () {
          if (!guideMatrix[option.name]![kind]!) return;
          expect(
            compiler
                .compileQuerySentence(sentence(kind, option))
                .generateQuery(dialect),
            contains(option.rendered),
            reason:
                'the guide says a $kind takes ${option.name}; a permitted '
                'option that does not reach the SQL is the defect this matrix '
                'exists to prevent, not a harmless omission',
          );
        });
      }
    }
  });

  group('a refused option is refused by name', () {
    for (final kind in _kinds.keys) {
      for (final option in _options) {
        test('$kind refuses ${option.name}', () {
          if (guideMatrix[option.name]![kind]!) return;
          final key = option.maskedBy[kind] ?? option.refusalKey;
          expect(
            () => compiler.compileQuerySentence(sentence(kind, option)),
            throwsA(
              isA<TomQuerySyntaxException>()
                  .having(
                    (e) => e.key,
                    'key',
                    'query_sentence_compiler.compile.$key',
                  )
                  .having(
                    (e) => e.parameters?['kind'],
                    'kind',
                    kind.toUpperCase(),
                  ),
            ),
          );
        });
      }
    }
  });

  group('a word that is no option at all', () {
    test('a stray word before by is refused, not skipped', () {
      // The token is reported, so the author reads their own typo back.
      expect(
        () => compiler.compileQuerySentence('find garbage by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>()
              .having(
                (e) => e.key,
                'key',
                'query_sentence_compiler.compile.unknown_option',
              )
              .having((e) => e.parameters?['token'], 'token', 'garbage'),
        ),
      );
    });

    test('a misspelled cap does not silently uncap', () {
      // The reason this matters more than the tidiness: skipping `frist` also
      // skipped its `5`, so the sentence ran with no cap and returned every
      // row — a wrong answer, not a rejected one.
      expect(
        () => compiler.compileQuerySentence('find frist 5 by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.unknown_option',
          ),
        ),
      );
    });

    test('the refusal names what this kind does take', () {
      expect(
        () => compiler.compileQuerySentence('count garbage by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.defaultUserMessage,
            'defaultUserMessage',
            allOf(contains('A count takes'), contains('distinct')),
          ),
        ),
      );
    });

    test('a group takes its projection there, and is not refused', () {
      // The one kind for which a token past the options is expected. Asserted
      // beside the refusals because the same index decides both.
      expect(
        compiler
            .compileQuerySentence(
              'group count ( * ) as total over title by id > 1',
            )
            .generateQuery(dialect),
        contains('GROUP BY'),
      );
    });
  });

  group('a sentence with no by', () {
    test('is refused, not a RangeError', () {
      // `by` is what separates the options from the predicate, so without it
      // the split walks off the front of the token list. It used to do exactly
      // that: a raw RangeError, outside the exception family this module
      // documents as covering every rejection, reaching a caller as an
      // internal error rather than a bad request.
      expect(
        () => compiler.compileQuerySentence('find id = 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.missing_by',
          ),
        ),
      );
    });

    test('however the sentence starts', () {
      for (final kind in ['find', 'count', 'delete', 'group', 'nonsense']) {
        expect(
          () => compiler.compileQuerySentence('$kind id = 1'),
          throwsA(isA<TomQuerySyntaxException>()),
          reason: '[$kind id = 1] must not escape the exception family',
        );
      }
    });
  });

  group('the options are parsed once, before the kind is judged', () {
    test('a malformed argument is reported even for an unknown kind', () {
      // The parse does not depend on the kind, so it runs first and its own
      // errors win. Pinned because moving the kind check ahead of it would
      // report "must start with find...By" for a sentence whose real problem
      // the author can see.
      expect(
        () => compiler.compileQuerySentence('nonsense first -1 by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.first_negative',
          ),
        ),
      );
    });

    test('an unknown kind is still named as one', () {
      expect(
        () => compiler.compileQuerySentence('nonsense by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.invalid_query_sentence_start',
          ),
        ),
      );
    });

    test('the two spellings of one option still conflict', () {
      expect(
        () => compiler.compileQuerySentence('find first 2 top 3 by id > 1'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.conflicting_top_first',
          ),
        ),
      );
      expect(
        () => compiler.compileQuerySentence(
          'find top 2 skip 1 offset 1 by id > 1',
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.conflicting_skip_offset',
          ),
        ),
      );
    });

    test('two refused options report the same one whichever order they are '
        'written in', () {
      // The refusal loop walks the option declarations, not the order the
      // sentence happened to use, so the message does not depend on how the
      // author arranged the words. Both of these carry a cap and a skip, and a
      // count refuses both.
      for (final written in ['top 2 skip 4', 'skip 4 top 2']) {
        expect(
          () => compiler.compileQuerySentence('count $written by id > 1'),
          throwsA(
            isA<TomQuerySyntaxException>().having(
              (e) => e.key,
              'key',
              'query_sentence_compiler.compile.top_unsupported_for_count',
            ),
          ),
          reason: '[count $written by …] must report the cap',
        );
      }
    });

    test('options may be written in either order', () {
      // The scan replaced a search, so the order the options appear in is a
      // property worth keeping rather than an accident of how they were found.
      final a = compiler
          .compileQuerySentence('find distinct top 2 by id > 1')
          .generateQuery(dialect);
      final b = compiler
          .compileQuerySentence('find top 2 distinct by id > 1')
          .generateQuery(dialect);
      expect(a, b);
    });
  });
}
