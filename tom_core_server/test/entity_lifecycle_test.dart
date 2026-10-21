/// The entity-lifecycle surface that needs no database: the soft-delete
/// statement, the change event's wire form and the listener registry.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureHookedNote, FixtureSoftNote;
import 'fixtures/reflection_fixture.reflection.dart';

class _Quiet extends TomEntityListener<FixtureHookedNote> {}

void main() {
  setUpAll(initializeReflection);
  tearDown(TomEntityLifecycle.reset);

  test('the annotations are read from the entity', () {
    expect(TomSoftDelete.of(FixtureSoftNote)!.field, 'deletedAt');
    expect(TomHistory.of(FixtureSoftNote)!.table, 'fixture_soft_note_history');
    expect(TomSoftDelete.of(FixtureHookedNote), isNull);
    expect(TomHistory.of(FixtureHookedNote), isNull);
  });

  test('includingDeleted marks its zone only', () async {
    expect(TomSoftDelete.isIncludingDeleted, isFalse);
    await TomSoftDelete.includingDeleted(() async {
      expect(TomSoftDelete.isIncludingDeleted, isTrue);
    });
    expect(TomSoftDelete.isIncludingDeleted, isFalse);
  });

  test('TomUpdate renders the assignments before the WHERE, and binds in '
      'that order', () {
    final builder = _Builder();
    final update = TomUpdate(
      [FixtureSoftNote],
      query: builder.eq<TomDbInt>(
        builder.intF('id', _column('id')),
        builder.p<TomDbInt>('id'),
      ),
      set: {'deleted_at': builder.p<TomDbDateTime>('__tomdeleted_at')},
    );
    final dialect = TomStandardSqlDialect();
    expect(
      update.generateQuery(dialect),
      allOf(
        startsWith('UPDATE fixture_soft_note SET deleted_at = '),
        contains(' WHERE '),
      ),
    );
    expect(update.getParameters(dialect), ['__tomdeleted_at', 'id']);
  });

  test('a change carries its context and renders as JSON values', () {
    final at = DateTime.utc(2026, 10, 21, 8);
    final change = TomEntityChange(
      entityType: FixtureHookedNote,
      kind: TomEntityChangeKind.updated,
      key: 7,
      beforeValues: {'text': 'a', 'at': at},
      afterValues: {'text': 'b', 'at': at},
      at: at,
      principalId: 'ada',
      tenant: 'acme',
    );
    expect(change.toJson(), {
      'entity': 'FixtureHookedNote',
      'kind': 'updated',
      'key': '7',
      'soft': false,
      'at': '2026-10-21T08:00:00.000Z',
      'principal': 'ada',
      'tenant': 'acme',
      'before': {'text': 'a', 'at': '2026-10-21T08:00:00.000Z'},
      'after': {'text': 'b', 'at': '2026-10-21T08:00:00.000Z'},
    });
  });

  test('a write is observed while a listener or a history is there', () {
    expect(TomEntityLifecycle.isObserved(FixtureHookedNote), isFalse);
    expect(
      TomEntityLifecycle.isObserved(FixtureSoftNote),
      isTrue,
      reason: 'it keeps a history',
    );
    final remove = TomEntityLifecycle.register(_Quiet());
    expect(TomEntityLifecycle.isObserved(FixtureHookedNote), isTrue);
    remove();
    expect(TomEntityLifecycle.isObserved(FixtureHookedNote), isFalse);
    final stop = TomEntityLifecycle.onChange((_) {}, entity: FixtureSoftNote);
    expect(TomEntityLifecycle.hasChangeListeners(FixtureHookedNote), isFalse);
    stop();
    TomEntityLifecycle.onChange((_) {});
    expect(TomEntityLifecycle.hasChangeListeners(FixtureHookedNote), isTrue);
  });
}

class _Builder with TomQueryBuilder {}

TomColumnInformation _column(String field) =>
    TomAnnotationAnalyzer.determineColumn(field, [
      TomAnnotationAnalyzer.analysePersistentType(FixtureSoftNote),
    ]);
