/// Soft delete, history tables, entity lifecycle hooks and change events
/// against a live database.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureBadSoftNoteRepository,
        FixtureHookedNote,
        FixtureHookedNoteRepository,
        FixtureSoftNote,
        FixtureSoftNoteRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _ddl = [
  '''
CREATE TABLE fixture_soft_note (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  version    BIGINT       NOT NULL DEFAULT 0,
  text       VARCHAR(255) NULL,
  deleted_at DATETIME(6)  NULL,
  PRIMARY KEY (id)
)''',
  '''
CREATE TABLE fixture_soft_note_history (
  history_id     BIGINT       NOT NULL AUTO_INCREMENT,
  history_action VARCHAR(16)  NOT NULL,
  history_at     DATETIME(6)  NOT NULL,
  history_by     VARCHAR(255) NULL,
  id             BIGINT       NOT NULL,
  version        BIGINT       NOT NULL,
  text           VARCHAR(255) NULL,
  deleted_at     DATETIME(6)  NULL,
  PRIMARY KEY (history_id)
)''',
  '''
CREATE TABLE fixture_hooked_note (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  text  VARCHAR(255) NULL,
  stamp VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''',
  // An outbox stand-in: what a change listener writes in the change's
  // transaction.
  '''
CREATE TABLE fixture_change_log (
  id    BIGINT        NOT NULL AUTO_INCREMENT,
  entry VARCHAR(1000) NOT NULL,
  PRIMARY KEY (id)
)''',
];

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// Records every hook call, and stamps or vetoes on request.
class _Recorder extends TomEntityListener<FixtureHookedNote> {
  final List<String> calls = [];
  bool vetoSave = false;
  bool failAfterSave = false;

  @override
  void beforeSave(FixtureHookedNote entity, {required bool insert}) {
    calls.add('beforeSave ${insert ? 'insert' : 'update'} ${entity.text}');
    if (vetoSave) throw StateError('vetoed');
    entity.stamp = 'stamped:${entity.text}';
  }

  @override
  void afterSave(FixtureHookedNote entity, {required bool insert}) {
    calls.add('afterSave ${entity.id} ${entity.stamp}');
    if (failAfterSave) throw StateError('after-save failed');
  }

  @override
  void beforeDelete(Object key, FixtureHookedNote? entity) =>
      calls.add('beforeDelete $key ${entity?.text}');

  @override
  void afterDelete(Object key, FixtureHookedNote? entity) =>
      calls.add('afterDelete $key ${entity?.text}');
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSource ds;
  late FixtureSoftNoteRepository notes;
  late FixtureHookedNoteRepository hooked;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    ds = (await TestDatabase.register()).datasource;
    for (final statement in _ddl) {
      await TestDatabase.execute(ds, statement);
    }
    notes = FixtureSoftNoteRepository();
    hooked = FixtureHookedNoteRepository();
    addTearDown(TestDatabase.reset);
  });

  setUp(() async {
    if (!reachable) return;
    TomEntityLifecycle.reset();
    for (final table in [
      'fixture_soft_note',
      'fixture_soft_note_history',
      'fixture_hooked_note',
      'fixture_change_log',
    ]) {
      await ds.executeCommand('DELETE FROM $table');
    }
  });

  tearDown(TomEntityLifecycle.reset);

  Future<int> rows(String table) async =>
      (await ds.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM $table',
      )).single.count;

  Future<FixtureSoftNote> note(String text) =>
      notes.save(FixtureSoftNote()..text = text);

  Future<T> as<T>(String user, Future<T> Function() body) => runZoned(
    body,
    zoneValues: {
      TomPrincipal: TomPrincipal(
        user: TomUser(id: user, username: user),
        authenticated: true,
      ),
    },
  );

  group('soft delete', () {
    test(
      'a deleted row is hidden from every repository read, and kept',
      () async {
        final kept = await note('kept');
        final gone = await note('gone');
        await notes.delete(gone);

        expect(await notes.findById(gone.id!), isNull);
        expect((await notes.findAll()).map((n) => n.text), ['kept']);
        expect((await notes.count()).get(), 1);
        expect(await notes.existsById([gone.id!]), isFalse);
        expect(
          (await notes.findByQuerySentence('find by text = :t', {'t': 'gone'})),
          isEmpty,
        );
        expect(await notes.findById(kept.id!), isNotNull);

        expect(await rows('fixture_soft_note'), 2, reason: 'the row stays');
        final seen = await TomSoftDelete.includingDeleted(
          () => notes.findById(gone.id!),
        );
        expect(seen!.deletedAt, isNotNull);
      },
      skip: skip,
    );

    test('every delete path is soft, and deleting a deleted row changes '
        'nothing', () async {
      final a = await note('a');
      final b = await note('b');
      final c = await note('c');
      final d = await note('d');

      expect(await notes.deleteById(a.id!), 1);
      expect(await notes.deleteById(a.id!), 0);
      expect(await notes.deleteAllById([b.id!]), 1);
      expect(
        await notes.deleteByQuerySentence('delete by text = :t', {'t': 'c'}),
        1,
      );
      expect(await notes.findAll(), hasLength(1));
      expect(await rows('fixture_soft_note'), 4);
      expect(d.deletedAt, isNull);
      expect(c.id, isNotNull);
    }, skip: skip);

    test(
      'restoreById brings a row back; purgeById removes it for good',
      () async {
        final n = await note('n');
        await notes.deleteById(n.id!);
        expect(await notes.restoreById(n.id!), 1);
        expect((await notes.findById(n.id!))!.deletedAt, isNull);
        expect(await notes.restoreById(n.id!), 0, reason: 'not deleted');

        await notes.deleteById(n.id!);
        expect(await notes.purgeById(n.id!), 1);
        expect(await rows('fixture_soft_note'), 0);
      },
      skip: skip,
    );

    test('a soft delete is version-checked and moves the version', () async {
      final n = await note('n');
      final stale = FixtureSoftNote()
        ..id = n.id
        ..version = n.version
        ..text = 'n';
      await notes.save(n..text = 'edited');

      await expectLater(
        notes.delete(stale),
        _throwsKey('crud_repository.delete.version_conflict'),
      );
      final current = await notes.findById(n.id!);
      await notes.delete(current!);
      final deleted = await TomSoftDelete.includingDeleted(
        () => notes.findById(n.id!),
      );
      expect(deleted!.version, current.version! + 1);
    }, skip: skip);

    test(
      'restoreById and purgeById are refused for an entity that deletes '
      'for good; a soft-delete field that is no DateTime is refused',
      () async {
        await expectLater(
          hooked.restoreById(1),
          _throwsKey('crud_repository.soft_delete.not_soft_delete'),
        );
        await expectLater(
          hooked.purgeById(1),
          _throwsKey('crud_repository.soft_delete.not_soft_delete'),
        );
        await expectLater(
          FixtureBadSoftNoteRepository().findAll(),
          _throwsKey('crud_repository.soft_delete.invalid_field'),
        );
      },
      skip: skip,
    );
  });

  test(
    'a delete cut to a window reaches only the rows the window holds',
    () async {
      final changes = <TomEntityChange>[];
      TomEntityLifecycle.onChange(changes.add);
      for (final text in ['w', 'w', 'w']) {
        await note(text);
      }
      final column = TomAnnotationAnalyzer.determineColumn('text', [
        TomAnnotationAnalyzer.analysePersistentType(FixtureSoftNote),
      ]);
      final affected = await notes.deleteByQuery(
        TomDelete(
          [FixtureSoftNote],
          query: notes.eq<TomDbString>(
            notes.textF('text', column),
            notes.p<TomDbString>('t'),
          ),
          sort: const [TomSortField.desc('id')],
          top: 2,
        ),
        {'t': 'w'},
      );
      expect(affected, 2);
      expect(await notes.findAll(), hasLength(1));
      expect(
        changes.where((c) => c.kind == TomEntityChangeKind.deleted),
        hasLength(2),
      );
      expect(
        (await notes.historyOf((await notes.findAll()).single.id!)),
        isEmpty,
      );
    },
    skip: skip,
  );

  group('history', () {
    test('every update, delete and restore keeps the row as it was', () async {
      await as('ada', () async {
        final n = await note('one');
        await notes.save(n..text = 'two');
        final two = (await notes.findById(n.id!))!;
        await notes.save(two..text = 'three');
        await notes.deleteById(n.id!);
        await notes.restoreById(n.id!);

        final history = await notes.historyOf(n.id!);
        expect(history.map((h) => h.action), [
          'update',
          'update',
          'delete',
          'restore',
        ]);
        expect(history.map((h) => h.entity.text), [
          'one',
          'two',
          'three',
          'three',
        ]);
        expect(history.map((h) => h.entity.version), [1, 2, 3, 3]);
        expect(history.last.entity.deletedAt, isNotNull);
        expect(history.every((h) => h.by == 'ada'), isTrue);
      });
    }, skip: skip);

    test('a write that rolls back leaves no history', () async {
      final n = await note('one');
      await expectLater(
        TomTransactionManager.runInTransaction((_) async {
          await notes.save(n..text = 'two');
          throw StateError('rolled back');
        }),
        throwsStateError,
      );
      expect(await notes.historyOf(n.id!), isEmpty);
      expect((await notes.findById(n.id!))!.text, 'one');
    }, skip: skip);

    test('historyOf is refused for an entity without history', () async {
      await expectLater(
        hooked.historyOf(1),
        _throwsKey('crud_repository.history.not_declared'),
      );
    }, skip: skip);
  });

  group('lifecycle hooks', () {
    test('save and delete run the hooks in order; beforeSave may change the '
        'entity', () async {
      final recorder = _Recorder();
      TomEntityLifecycle.register(recorder);

      final saved = await hooked.save(FixtureHookedNote()..text = 'a');
      expect(saved.stamp, 'stamped:a');
      await hooked.save(saved..text = 'b');
      await hooked.deleteById(saved.id!);

      expect(recorder.calls, [
        'beforeSave insert a',
        'afterSave ${saved.id} stamped:a',
        'beforeSave update b',
        'afterSave ${saved.id} stamped:b',
        'beforeDelete ${saved.id} b',
        'afterDelete ${saved.id} b',
      ]);
    }, skip: skip);

    test('a throwing beforeSave refuses the write; a throwing afterSave rolls '
        'it back', () async {
      final recorder = _Recorder()..vetoSave = true;
      final remove = TomEntityLifecycle.register(recorder);
      await expectLater(
        hooked.save(FixtureHookedNote()..text = 'x'),
        throwsStateError,
      );
      expect(await rows('fixture_hooked_note'), 0);

      remove();
      TomEntityLifecycle.register(_Recorder()..failAfterSave = true);
      await expectLater(
        hooked.save(FixtureHookedNote()..text = 'y'),
        throwsStateError,
      );
      expect(await rows('fixture_hooked_note'), 0);
    }, skip: skip);

    test('a delete by query runs the hooks once per row', () async {
      final recorder = _Recorder();
      await hooked.save(FixtureHookedNote()..text = 'q');
      await hooked.save(FixtureHookedNote()..text = 'q');
      TomEntityLifecycle.register(recorder);
      expect(
        await hooked.deleteByQuerySentence('delete by text = :t', {'t': 'q'}),
        2,
      );
      expect(
        recorder.calls.where((c) => c.startsWith('afterDelete')),
        hasLength(2),
      );
    }, skip: skip);
  });

  group('change events', () {
    test('every change is reported with what it changed', () async {
      final changes = <TomEntityChange>[];
      TomEntityLifecycle.onChange(changes.add);

      final h = await hooked.save(FixtureHookedNote()..text = 'a');
      await hooked.save(h..text = 'b');
      await hooked.deleteById(h.id!);
      final n = await note('soft');
      await notes.deleteById(n.id!);
      await notes.restoreById(n.id!);

      expect(changes.map((c) => '${c.entityType} ${c.kind.name} ${c.soft}'), [
        'FixtureHookedNote inserted false',
        'FixtureHookedNote updated false',
        'FixtureHookedNote deleted false',
        'FixtureSoftNote inserted false',
        'FixtureSoftNote deleted true',
        'FixtureSoftNote restored false',
      ]);
      final update = changes[1];
      expect(update.key, h.id);
      expect(update.beforeValues['text'], 'a');
      expect(update.afterValues['text'], 'b');
      final json = update.toJson();
      expect(json['kind'], 'updated');
      expect(json['entity'], 'FixtureHookedNote');
      expect((json['after'] as Map)['text'], 'b');
    }, skip: skip);

    test(
      'a listener registered for one entity hears only that entity',
      () async {
        final heard = <Type>[];
        TomEntityLifecycle.onChange(
          (c) => heard.add(c.entityType),
          entity: FixtureSoftNote,
        );
        await hooked.save(FixtureHookedNote()..text = 'a');
        await note('b');
        expect(heard, [FixtureSoftNote]);
      },
      skip: skip,
    );

    test(
      'a listener writing an outbox row writes it in the change\'s '
      'transaction: it commits with the change and rolls back with it',
      () async {
        TomEntityLifecycle.onChange(
          (change) => ds.executeCommand(
            'INSERT INTO fixture_change_log (entry) VALUES (:entry)',
            {'entry': '${change.toJson()}'},
          ),
          entity: FixtureHookedNote,
        );

        await hooked.save(FixtureHookedNote()..text = 'kept');
        expect(await rows('fixture_change_log'), 1);

        await expectLater(
          TomTransactionManager.runInTransaction((_) async {
            await hooked.save(FixtureHookedNote()..text = 'lost');
            throw StateError('rolled back');
          }),
          throwsStateError,
        );
        expect(await rows('fixture_change_log'), 1);
        expect(await rows('fixture_hooked_note'), 1);
      },
      skip: skip,
    );
  });
}
