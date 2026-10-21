/// Association filters and subqueries as the compiler and the builder render
/// them — no database. `query_associations_db_test.dart` runs them.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureContextTaggedRecord,
        FixtureRelatedTag,
        FixtureSoftNote,
        FixtureTagLink,
        FixtureTaggedRecord;
import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

class _Builder with TomQueryBuilder {}

void main() {
  setUpAll(initializeReflection);

  final dialect = TomStandardSqlDialect();
  TomQuery compile(String sentence, [Type owner = FixtureTaggedRecord]) =>
      TomQuerySentenceCompiler([owner]).compileQuerySentence(sentence);

  group('an association path compiles to a correlated EXISTS', () {
    test('a comparison on the target joins through the join entity', () {
      final query = compile('find by tags.name = :n');
      final sql = query.generateQuery(dialect);
      expect(
        sql,
        contains(
          'EXISTS (SELECT 1 FROM fixture_tag_link, fixture_tag WHERE '
          '(fixture_tag_link.tagged_id = fixture_tagged.id AND '
          'fixture_tag_link.tag_id = fixture_tag.id AND '
          'fixture_tag.name = :n))',
        ),
      );
      expect(query.getParameters(dialect), ['n']);
    });

    test('it combines with the owner\'s own columns, parameters in order', () {
      final query = compile('find by label = :l and tags.name like :p');
      expect(query.getParameters(dialect), ['l', 'p']);
    });

    test('is empty / is not empty test whether it reaches any row', () {
      expect(
        compile('find by tags is empty').generateQuery(dialect),
        contains('NOT EXISTS (SELECT 1 FROM fixture_tag_link, fixture_tag'),
      );
      final notEmpty = compile('count by tags is not empty');
      expect(notEmpty.generateQuery(dialect), contains('EXISTS ('));
      expect(notEmpty.generateQuery(dialect), isNot(contains('NOT EXISTS')));
    });

    test('what it refuses', () {
      expect(
        () => compile('find by tags = :n'),
        _throwsKey('query_sentence_compiler.association.no_field'),
      );
      expect(
        () => compile('find by tags.colour = :c'),
        _throwsKey('query_sentence_compiler.association.unknown_field'),
      );
      expect(
        () => compile('find by tags.name = :n', FixtureContextTaggedRecord),
        _throwsKey('query_sentence_compiler.association.context_columns'),
      );
      expect(
        () => compile('find by related.name = :n', FixtureRelatedTag),
        _throwsKey('query_sentence_compiler.association.self_reference'),
      );
    });
  });

  group('the builder\'s subquery nodes', () {
    final b = _Builder();
    TomColumnInformation column(Type type, String field) =>
        TomAnnotationAnalyzer.determineColumn(field, [
          TomAnnotationAnalyzer.analysePersistentType(type),
        ]);

    test('IN (SELECT …) selects the projection and binds in order', () {
      final predicate = b.isInSubquery<TomDbInt>(
        b.intF('id', column(FixtureTaggedRecord, 'id')),
        TomSubquery(
          [FixtureTagLink],
          projection: b.intF('taggedId', column(FixtureTagLink, 'taggedId')),
          where: b.eq<TomDbInt>(
            b.intF('tagId', column(FixtureTagLink, 'tagId')),
            b.p<TomDbInt>('tag'),
          ),
        ),
      );
      expect(
        predicate.generate(dialect),
        'fixture_tagged.id IN (SELECT fixture_tag_link.tagged_id FROM '
        'fixture_tag_link WHERE (fixture_tag_link.tag_id = :tag))',
      );
      expect(predicate.getParameters(dialect), ['tag']);
      expect(predicate.getFields(dialect), {'fixture_tagged.id'});
    });

    test('NOT EXISTS, and a subquery is opaque to the outer walks', () {
      final predicate = b.notExists(TomSubquery([FixtureTagLink]));
      expect(
        predicate.generate(dialect),
        'NOT EXISTS (SELECT 1 FROM fixture_tag_link)',
      );
      expect(predicate.getFields(dialect), isEmpty);
    });

    test(
      'a soft-deleted entity in a subquery contributes its live-row test',
      () async {
        final sub = TomSubquery([FixtureSoftNote]);
        expect(
          sub.generate(dialect),
          'SELECT 1 FROM fixture_soft_note WHERE '
          '(fixture_soft_note.deleted_at IS NULL)',
        );
        await TomSoftDelete.includingDeleted(() async {
          expect(sub.generate(dialect), 'SELECT 1 FROM fixture_soft_note');
        });
      },
    );
  });
}
