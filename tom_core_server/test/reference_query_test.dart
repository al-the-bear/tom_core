/// Tests for [TomAnnotationAnalyzer.referenceQuery] — the `FIND BY` sentence
/// that resolves a `@TomReference` association.
///
/// A `@TomReference` is not a column. Reading it costs a second query over the
/// join entity, issued once the owning row has been mapped, and that query's
/// text is built from three column lists that mean three different things: one
/// binds to the row just read, one is a plain join condition, and one binds to
/// an ambient value from the execution context. Getting a term into the wrong
/// category silently produces a sentence that either matches everything or
/// nothing.
///
/// The construction used to be welded into the middle of the MariaDB result
/// mapper, reachable only behind a live connection — so none of it was
/// exercised, including seven distinct rejections it already implemented.
/// Splitting the *computation* of the sentence from the *execution* of it is
/// what makes this file possible: nothing here needs a database, a reflector,
/// or even an entity, because the owning row is represented by the field-read
/// callback the caller passes in.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The entity that declares the association. Only its *name* matters here: the
/// left-side expressions must qualify the owner side with it.
class RefOwner {}

/// The entity modelling the join rows.
class RefJoin {}

/// The entity the association points at.
class RefTarget {}

void main() {
  /// Builds a reference with only the three column lists varying — the type
  /// arguments and the repository play no part in the sentence.
  TomReference reference({
    List<String> left = const ['RefJoin.ownerId=RefOwner.id'],
    List<String> right = const [],
    List<String> context = const [],
  }) => TomReference(
    targetEntity: RefTarget,
    repositoryType: Object,
    keyType: int,
    joinEntity: RefJoin,
    leftSideColumns: left,
    rightSideColumns: right,
    contextColumns: context,
  );

  /// A field read standing in for the mapped row.
  Object? Function(String) reads(Map<String, Object?> fields) =>
      (field) => fields[field];

  ({String sentence, Map<String, Object?> parameters}) build(
    TomReference ref, {
    Map<String, Object?> fields = const {'id': 42},
  }) => TomAnnotationAnalyzer.referenceQuery(ref, RefOwner, reads(fields));

  /// Runs [body] with [entries] installed as the ambient execution context.
  T inContext<T>(Map<String, Object?> entries, T Function() body) =>
      TomExecutionContext({
        for (final e in entries.entries)
          e.key: TomContextEntry<Object?>(() => e.value),
      }).runInContext(body);

  group('reference_query.sentence', () {
    test('a left-side column binds the owner value as a parameter', () {
      final query = build(reference());
      expect(query.sentence, 'FIND BY RefJoin.ownerId = :id');
      expect(query.parameters, {'id': 42});
    });

    test(
      'the parameter is named after the owner field, not the join field',
      () {
        // The two sides carry different names on purpose: a build that took the
        // name from the left would still produce a runnable sentence, and only
        // the binding would be wrong.
        final query = build(
          reference(left: ['RefJoin.theUserId=RefOwner.identifier']),
          fields: {'identifier': 7, 'theUserId': 999},
        );
        expect(query.sentence, 'FIND BY RefJoin.theUserId = :identifier');
        expect(query.parameters, {'identifier': 7});
      },
    );

    test('a right-side column is a join condition and binds nothing', () {
      final query = build(reference(right: ['RefJoin.targetId=RefTarget.id']));
      expect(
        query.sentence,
        'FIND BY RefJoin.ownerId = :id AND RefJoin.targetId=RefTarget.id',
      );
      expect(query.parameters, {'id': 42});
    });

    test('a context column binds from the execution context', () {
      final query = inContext(
        {'organization': 7},
        () =>
            build(reference(context: ['RefJoin.organizationId=:organization'])),
      );
      expect(
        query.sentence,
        'FIND BY RefJoin.ownerId = :id'
        ' AND RefJoin.organizationId=:organization',
      );
      expect(query.parameters, {'id': 42, 'organization': 7});
    });

    test('every term of every list is emitted, in list order', () {
      final query = inContext(
        {'organization': 7, 'application': 3},
        () => build(
          reference(
            left: ['RefJoin.ownerId=RefOwner.id', 'RefJoin.kind=RefOwner.kind'],
            right: ['RefJoin.targetId=RefTarget.id'],
            context: [
              'RefJoin.organizationId=:organization',
              'RefJoin.applicationId=:application',
            ],
          ),
          fields: {'id': 42, 'kind': 'primary'},
        ),
      );
      expect(
        query.sentence,
        'FIND BY RefJoin.ownerId = :id'
        ' AND RefJoin.kind = :kind'
        ' AND RefJoin.targetId=RefTarget.id'
        ' AND RefJoin.organizationId=:organization'
        ' AND RefJoin.applicationId=:application',
      );
      expect(query.parameters, {
        'id': 42,
        'kind': 'primary',
        'organization': 7,
        'application': 3,
      });
    });

    test('a reference without context columns needs no execution context', () {
      // The zone read is per context column, so a reference that names none
      // must build outside a context — which is the common case, and would
      // otherwise make every association read require one.
      expect(
        build(reference(right: ['RefJoin.targetId=RefTarget.id'])).sentence,
        'FIND BY RefJoin.ownerId = :id AND RefJoin.targetId=RefTarget.id',
      );
    });
  });

  group('reference_query.rejects', () {
    Matcher throwsSyntax(String key) => throwsA(
      isA<TomAnnotationAnalyzerSyntaxException>().having(
        (e) => e.key,
        'key',
        key,
      ),
    );

    Matcher throwsAnalyzer(String key) => throwsA(
      isA<TomAnnotationAnalyzerException>().having((e) => e.key, 'key', key),
    );

    test('a left-side expression that is not a pair', () {
      expect(
        () => build(reference(left: ['RefJoin.ownerId'])),
        throwsSyntax(
          'annotation_analyzer.reference_query.left_side_not_a_pair',
        ),
      );
    });

    test('a left-side expression with the owner on the left', () {
      expect(
        () => build(reference(left: ['RefOwner.id=RefJoin.ownerId'])),
        throwsSyntax(
          'annotation_analyzer.reference_query.left_side_owner_on_left',
        ),
      );
    });

    test('a left-side expression naming no owner field', () {
      expect(
        () => build(reference(left: ['RefJoin.ownerId=RefTarget.id'])),
        throwsSyntax(
          'annotation_analyzer.reference_query.left_side_owner_missing',
        ),
      );
    });

    test('a context expression that is not a pair', () {
      expect(
        () => inContext({
          'organization': 7,
        }, () => build(reference(context: ['RefJoin.organizationId']))),
        throwsSyntax('annotation_analyzer.reference_query.context_not_a_pair'),
      );
    });

    test('a context expression with the context value on the left', () {
      expect(
        () => inContext({
          'organization': 7,
        }, () => build(reference(context: [':organization=RefJoin.orgId']))),
        throwsSyntax(
          'annotation_analyzer.reference_query.context_value_on_left',
        ),
      );
    });

    test('a context expression whose right side is not a context name', () {
      expect(
        () => inContext({
          'organization': 7,
        }, () => build(reference(context: ['RefJoin.orgId=RefOwner.orgId']))),
        throwsSyntax(
          'annotation_analyzer.reference_query.context_value_missing',
        ),
      );
    });

    test('a context column with no execution context installed', () {
      expect(
        () =>
            build(reference(context: ['RefJoin.organizationId=:organization'])),
        throwsAnalyzer(
          'annotation_analyzer.reference_query.no_execution_context',
        ),
      );
    });

    test('a context column the running context does not carry', () {
      expect(
        () => inContext(
          {'client': 1},
          () => build(
            reference(context: ['RefJoin.organizationId=:organization']),
          ),
        ),
        throwsAnalyzer(
          'annotation_analyzer.reference_query.context_entry_not_found',
        ),
      );
    });

    test('a malformed expression is rejected before the context is read', () {
      // Syntax first: an unparseable expression is an authoring error and says
      // so, rather than reporting the context entry it could not look up
      // because it never worked out which one to ask for.
      expect(
        () => build(reference(context: ['RefJoin.organizationId'])),
        throwsSyntax('annotation_analyzer.reference_query.context_not_a_pair'),
      );
    });

    test('a reference with no terms at all', () {
      // `FIND BY` with nothing after it is not a sentence, and a reference that
      // constrains nothing would load every target row for every owner row.
      expect(
        () => build(reference(left: const [])),
        throwsSyntax('annotation_analyzer.reference_query.no_terms'),
      );
    });
  });
}
