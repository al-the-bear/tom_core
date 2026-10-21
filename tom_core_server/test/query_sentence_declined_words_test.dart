/// Tests for what the query-sentence grammar deliberately does **not** have —
/// the declined Spring-Data words — and for the forms that replace them.
///
/// `doc/object_persistence.md` §Words this grammar does not have declines eight
/// Spring-Data keywords — *After*, *Before*, *StartsWith*, *EndsWith*,
/// *Containing*, *Within* / *Between*, *Exists*, *isEmpty* / *isNotEmpty* — on
/// the ground that Spring needs word-operators because its query is a **method
/// name**, where `>` and `%` cannot be written, while a query sentence is a
/// string, where they can.
///
/// A declined feature is a promise about two things at once: that the word is
/// not quietly half-supported, and that the form named in its place really does
/// what the word would have. Prose can hold neither claim true on its own, so
/// both are run here — the refusals against the compiler, the replacements
/// against the SQL they render — and the guide's own table is read back, so a
/// row added to it, or a word promoted to a keyword, fails a test rather than
/// drifting away from what the compiler does.
///
/// *Exists*, *isEmpty* and *isNotEmpty* are replaced by the association path
/// (`tags.name = :n`, `tags is empty`), which the guide describes in
/// §Filtering on an association; the forms it names are run here too, so the
/// replacement the table points at is one the compiler takes.
///
/// Connection-free: only the entity's annotations are read.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureExportRecord, FixtureTaggedRecord;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  late TomQuerySentenceCompiler compiler;
  final dialect = MariadbSqlDialect();

  setUpAll(() {
    initializeReflection();
    compiler = TomQuerySentenceCompiler([FixtureExportRecord]);
  });

  /// The `WHERE …` tail of the compiled statement.
  String where(String sentence) {
    final sql = compiler.compileQuerySentence(sentence).generateQuery(dialect);
    return sql.substring(sql.indexOf('WHERE '));
  }

  /// The eight declined words, spelled as the guide spells them.
  const declined = [
    'After',
    'Before',
    'StartsWith',
    'EndsWith',
    'Containing',
    'Between',
    'Within',
    'Exists',
    'isEmpty',
    'isNotEmpty',
  ];

  group('a declined word is not a keyword', () {
    // Each is written where an operator belongs. None may compile: a word that
    // parsed would mean the grammar has it after all, and the guide names a
    // replacement for something the caller could have written directly.
    for (final word in declined) {
      test('[$word] does not compile as an operator', () {
        expect(
          () => compiler.compileQuerySentence('find by title $word :p'),
          throwsA(isA<TomServerException>()),
          reason:
              '[$word] compiled, so the grammar has it — remove it from the '
              'declined table in doc/object_persistence.md §Words this grammar '
              'does not have and document what it renders',
        );
      });
    }
  });

  group('the form named in its place is the one that works', () {
    test('After and Before are > and < on a temporal column', () {
      expect(where('find by createdAt > :t'), endsWith('created_at > :t'));
      expect(where('find by createdAt < :t'), endsWith('created_at < :t'));
      // The literal form too: a temporal column compares against a written
      // timestamp, which is what makes `>` a complete replacement rather than
      // one that works only for a bound value.
      expect(
        where('find by createdAt > 2026-07-05T10:00:00Z'),
        endsWith("created_at > '2026-07-05 10:00:00.000000'"),
      );
    });

    test('StartsWith, EndsWith and Containing are LIKE with the wildcard '
        'placed where you mean it', () {
      expect(
        where("find by title like 'a%'"),
        endsWith(r"title LIKE 'a%' ESCAPE '\\'"),
      );
      expect(
        where("find by title like '%a'"),
        endsWith(r"title LIKE '%a' ESCAPE '\\'"),
      );
      expect(
        where("find by title like '%a%'"),
        endsWith(r"title LIKE '%a%' ESCAPE '\\'"),
      );
    });

    test('Between and Within are a pair of comparisons', () {
      expect(
        where('find by amount >= :lo and amount <= :hi'),
        endsWith('amount >= :lo AND fixture_export.amount <= :hi'),
      );
    });

    test('the single BETWEEN node is reachable from the builder DSL', () {
      // The guide sends a caller who wants one node rather than two conjuncts
      // to `findByQuery`. That is only an answer if the node exists there.
      final b = _Builder();
      final column = TomAnnotationAnalyzer.determineColumn('amount', [
        TomAnnotationAnalyzer.analysePersistentType(FixtureExportRecord),
      ]);
      expect(
        b
            .between(b.doubleF('amount', column), [
              b.doubleOp(1.5),
              b.doubleOp(9.5),
            ])
            .generate(dialect),
        'fixture_export.amount BETWEEN 1.5 AND 9.5',
      );
    });
  });

  group('the guide declines exactly these words', () {
    /// The rows of the guide's declined-words table, as written.
    late String table;

    setUpAll(() {
      final guide = File('doc/object_persistence.md').readAsStringSync();
      final start = guide.indexOf('### Words this grammar does not have');
      expect(start, isNot(-1), reason: 'the guide section was renamed');
      final end = guide.indexOf('\n## ', start);
      table = guide.substring(start, end == -1 ? guide.length : end);
    });

    /// The words in the table's **left** column — the declined spellings. The
    /// right column names what to write instead, and is code, so only the left
    /// one is the list under test.
    Set<String> declinedInGuide() => {
      for (final line in table.split('\n'))
        if (line.startsWith('| ') && !line.startsWith('| ---'))
          ...RegExp(
            r'\*([A-Za-z]+)\*',
          ).allMatches(line.split('|')[1]).map((m) => m.group(1)!),
    };

    test('the table names exactly the words this suite exercises', () {
      // An equality, not two containments, and read from the table rather than
      // from the section: a word named only in the prose below is explained,
      // not declined, and the row is what a reader scans. Dropping a row while
      // leaving the sentence that mentions it is the drift this catches.
      expect(declinedInGuide(), declined.toSet());
    });

    test('the table was read, and is not simply empty', () {
      // Without this the equality above passes vacuously the moment the
      // section is renamed or the table restyled.
      expect(declinedInGuide(), hasLength(greaterThan(5)));
    });

    test('the guide states why, not just what', () {
      // The reason is the load-bearing part: without it the table reads as a
      // backlog, and the next reader adds the keywords.
      expect(
        table,
        allOf(contains('method name'), contains('string'), contains('Exists')),
      );
    });
  });

  group('an association path is the form that replaces Exists and isEmpty', () {
    late TomQuerySentenceCompiler associations;

    setUpAll(() {
      associations = TomQuerySentenceCompiler([FixtureTaggedRecord]);
    });

    String predicate(String sentence) {
      final sql = associations
          .compileQuerySentence(sentence)
          .generateQuery(dialect);
      return sql.substring(sql.indexOf('WHERE '));
    }

    test('a predicate can address an association\'s columns', () {
      // `tags` is a `@TomReference` to FixtureTag through a join entity. The
      // term compiles to a correlated EXISTS over the join entity and target.
      expect(
        predicate('find by tags.name = :n'),
        contains(
          'EXISTS (SELECT 1 FROM fixture_tag_link, fixture_tag WHERE '
          '(fixture_tag_link.tagged_id = fixture_tagged.id AND '
          'fixture_tag_link.tag_id = fixture_tag.id AND '
          'fixture_tag.name = :n))',
        ),
      );
    });

    test('the sentences the guide shows compile as it says', () {
      // §Filtering on an association: a term followed by `and`, a negated
      // term, `<>` inside the subquery, and is empty / is not empty.
      expect(
        predicate("count by tags.name like 'r%' and label = :l"),
        allOf(startsWith('WHERE EXISTS ('), endsWith('label = :l')),
      );
      expect(
        predicate('delete by not tags.name = :n'),
        startsWith('WHERE NOT EXISTS ('),
      );
      expect(
        predicate('find by tags.name <> :n'),
        allOf(startsWith('WHERE EXISTS ('), contains('fixture_tag.name <> :n')),
      );
      expect(
        predicate('find by tags is empty'),
        startsWith('WHERE NOT EXISTS ('),
      );
      expect(
        predicate('find by tags is not empty'),
        startsWith('WHERE EXISTS ('),
      );
    });

    test('the association field itself is not a column', () {
      expect(
        () => associations.compileQuerySentence('find by tags = :n'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.association.no_field',
          ),
        ),
      );
    });

    test('a dotted name that is no association is refused as a column', () {
      expect(
        () => associations.compileQuerySentence('find by author.name = :n'),
        throwsA(
          isA<TomAnnotationAnalyzerSyntaxException>().having(
            (e) => e.key,
            'key',
            endsWith('no_column_match'),
          ),
        ),
      );
    });

    test('the guide lists neither as a limitation', () {
      final guide = File('doc/object_persistence.md').readAsStringSync();
      final start = guide.indexOf('## Not Yet Implemented');
      expect(start, isNot(-1));
      final end = guide.indexOf('\n## ', start + 1);
      final section = guide.substring(start, end == -1 ? guide.length : end);
      expect(
        section,
        allOf(
          isNot(contains("association's columns")),
          isNot(contains('subquery')),
          // The declined words are *not* limitations, and saying so here is
          // what stops the next reader from filing them as a backlog again.
          contains('declined'),
        ),
      );
    });
  });
}

/// A bare host for the [TomQueryBuilder] DSL — a repository is one too.
class _Builder with TomQueryBuilder {}
