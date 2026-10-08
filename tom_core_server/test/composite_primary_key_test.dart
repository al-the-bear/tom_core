/// Tests that an entity keyed by **several** fields is addressed by all of them.
///
/// `@TomDbTable.primaryKeyFields` lists the fields of the key, and a table
/// keyed by two columns — the legacy join table, `PRIMARY KEY (task_id,
/// label)` — maps with no surrogate column. Every by-key path of
/// [TomSqlDatasourceRepository] then has to say *every* key column: a read, a
/// delete or an update that matched on one would address every row sharing
/// that value.
///
/// **Connection-free**, against `fixtures/scripted_datasource.dart`, which
/// records the SQL each path prepares and the values it binds. What is under
/// test is that SQL and those values; the DB-backed half — that MariaDB
/// accepts them — is `object_persistence_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTaskLabel, FixtureTaskLabelRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

TomCompositeKey _key(int taskId, String label) =>
    TomCompositeKey({'taskId': taskId, 'label': label});

FixtureTaskLabel _row(int? taskId, String? label, [String? note]) =>
    FixtureTaskLabel()
      ..taskId = taskId
      ..label = label
      ..note = note;

TomCountResult _count(int n) => TomCountResult()..count = n;

/// The SQL with its layout collapsed, so an assertion is about the statement.
String _flat(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  setUpAll(initializeReflection);

  group('TomCompositeKey', () {
    test('CPK-1: keys with the same fields and values are equal, in any '
        'order', () {
      final a = TomCompositeKey({'taskId': 1, 'label': 'x'});
      final b = TomCompositeKey({'label': 'x', 'taskId': 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('CPK-2: a different value or a different field set is unequal', () {
      expect(_key(1, 'x'), isNot(_key(1, 'y')));
      expect(
        TomCompositeKey({'taskId': 1}),
        isNot(TomCompositeKey({'taskId': 1, 'label': null})),
      );
    });

    test('CPK-3: reads its values by field and prints them in order', () {
      final key = _key(7, 'urgent');
      expect(key['taskId'], 7);
      expect(key['label'], 'urgent');
      expect(key.fields, ['taskId', 'label']);
      expect('$key', '(taskId: 7, label: urgent)');
    });

    test('CPK-4: its values cannot be changed after construction', () {
      expect(() => _key(1, 'x').values['taskId'] = 2, throwsUnsupportedError);
    });
  });

  group('a composite-key repository addresses a row by every key column', () {
    late ScriptedDataSource scripted;

    setUp(() => scripted = registerScriptedDatasource());
    tearDown(unregisterScriptedDatasource);

    test('CPK-5: the repository resolves both key columns', () {
      final repo = FixtureTaskLabelRepository();
      expect(repo.hasCompositeKey, isTrue);
      expect(repo.primaryKeyColumns.map((c) => c.getQueryFieldName()), [
        'task_id',
        'label',
      ]);
      expect(repo.keyOf(_row(3, 'a')), _key(3, 'a'));
    });

    test(
      'CPK-6: findById matches on both columns and binds both values',
      () async {
        scripted.answers.add([_row(7, 'urgent', 'n')]);
        final row = await FixtureTaskLabelRepository().findById(
          _key(7, 'urgent'),
        );
        expect(row!.note, 'n');
        expect(
          _flat(scripted.statements.single),
          'SELECT * FROM fixture_task_label WHERE task_id = :id_0 AND label = :id_1',
        );
        expect(scripted.executions.single, {'id_0': 7, 'id_1': 'urgent'});
      },
    );

    test('CPK-7: deleteById deletes by both columns', () async {
      scripted.affectedRows = 1;
      expect(await FixtureTaskLabelRepository().deleteById(_key(7, 'a')), 1);
      expect(
        _flat(scripted.statements.single),
        'DELETE FROM fixture_task_label WHERE fixture_task_label.task_id = '
        ':id_0 AND fixture_task_label.label = :id_1',
      );
      expect(scripted.executions.single, {'id_0': 7, 'id_1': 'a'});
    });

    test('CPK-8: delete(entity) deletes the entity by both of its key '
        'values', () async {
      await FixtureTaskLabelRepository().delete(_row(4, 'b'));
      expect(scripted.executions.single, {'id_0': 4, 'id_1': 'b'});
    });

    test('CPK-9: an id list is one ANDed term per key, ORed', () async {
      scripted.answers.add([_count(2)]);
      expect(
        await FixtureTaskLabelRepository().existsById([
          _key(1, 'a'),
          _key(2, 'b'),
        ]),
        isTrue,
      );
      final sql = _flat(scripted.statements.single);
      expect(sql, contains(' OR '));
      for (final term in [
        'task_id = :__idlist_0_0 AND fixture_task_label.label = :__idlist_0_1',
        'task_id = :__idlist_1_0 AND fixture_task_label.label = :__idlist_1_1',
      ]) {
        expect(sql, contains(term));
      }
      expect(scripted.executions.single, {
        '__idlist_0_0': 1,
        '__idlist_0_1': 'a',
        '__idlist_1_0': 2,
        '__idlist_1_1': 'b',
      });
    });

    test(
      'CPK-10: an empty id list matches nothing rather than every row',
      () async {
        expect(
          await FixtureTaskLabelRepository().findAllById(const []),
          isEmpty,
        );
        expect(_flat(scripted.statements.single), isNot(contains(' OR ')));
      },
    );

    test('CPK-11: a window is ordered by every key column', () async {
      await FixtureTaskLabelRepository().findAll(TomPageRequest.page(1, 10));
      expect(
        _flat(scripted.statements.single),
        contains(
          'ORDER BY fixture_task_label.task_id ASC,fixture_task_label.label ASC',
        ),
      );
    });
  });

  group('save decides insert or update by whether the key is stored', () {
    late ScriptedDataSource scripted;

    setUp(() => scripted = registerScriptedDatasource());
    tearDown(unregisterScriptedDatasource);

    test('CPK-12: a key the table does not hold is inserted, and the row is '
        'read back by the key as given', () async {
      scripted.answers
        ..add([_count(0)]) // the existence check
        ..add(<FixtureTaskLabel>[]) // the INSERT
        ..add([_row(5, 'new', 'hello')]); // the read-back
      final saved = await FixtureTaskLabelRepository().save(
        _row(5, 'new', 'hello'),
      );
      expect(saved.note, 'hello');
      expect(scripted.statements, hasLength(3));
      expect(_flat(scripted.statements[0]), contains('COUNT(*)'));
      expect(
        _flat(scripted.statements[1]),
        'INSERT INTO fixture_task_label ( task_id,label,note ) '
        'VALUES ( :taskId,:label,:note )',
      );
      // No generated id is asked for: the key was supplied, so the read-back
      // binds it as written.
      expect(scripted.executions[2], {'id_0': 5, 'id_1': 'new'});
    });

    test('CPK-13: a key the table holds is updated by both columns', () async {
      scripted.answers
        ..add([_count(1)]) // the existence check
        ..add(<FixtureTaskLabel>[]) // the UPDATE
        ..add([_row(5, 'old', 'changed')]); // the read-back
      await FixtureTaskLabelRepository().save(_row(5, 'old', 'changed'));
      expect(
        _flat(scripted.statements[1]),
        'UPDATE fixture_task_label SET task_id = :taskId,label = :label,'
        'note = :note WHERE task_id = :taskId AND label = :label',
      );
      expect(scripted.executions[1], {
        'taskId': 5,
        'label': 'old',
        'note': 'changed',
      });
    });

    test('CPK-14: a key with a field missing is refused before any '
        'statement runs', () async {
      await expectLater(
        FixtureTaskLabelRepository().save(_row(5, null)),
        throwsA(
          isA<TomRepositoryException>().having(
            (e) => e.key,
            'key',
            'crud_repository.save.incomplete_key',
          ),
        ),
      );
      expect(scripted.statements, isEmpty);
    });

    test('CPK-15: delete refuses an entity whose key is incomplete', () async {
      await expectLater(
        FixtureTaskLabelRepository().delete(_row(null, 'x')),
        throwsA(
          isA<TomRepositoryException>().having(
            (e) => e.key,
            'key',
            'crud_repository.delete.unsaved_entity',
          ),
        ),
      );
    });
  });

  group('a key of the wrong shape is refused', () {
    setUp(registerScriptedDatasource);
    tearDown(unregisterScriptedDatasource);

    final wrongKeys = <String, TomCompositeKey>{
      'a field missing': TomCompositeKey({'taskId': 1}),
      'a field the table is not keyed by': TomCompositeKey({
        'taskId': 1,
        'label': 'a',
        'note': 'n',
      }),
      'a field named by its column': TomCompositeKey({
        'task_id': 1,
        'label': 'a',
      }),
    };
    for (final entry in wrongKeys.entries) {
      test('CPK-16: a key with ${entry.key}', () async {
        await expectLater(
          FixtureTaskLabelRepository().findById(entry.value),
          throwsA(
            isA<TomRepositoryException>().having(
              (e) => e.key,
              'key',
              'crud_repository.key.shape_mismatch',
            ),
          ),
        );
      });
    }
  });
}
