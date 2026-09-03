/// DB-backed tests for the object-persistence CRUD / query-sentence surface.
///
/// The connection-free surface (the `TomQueryBuilder` DSL, the operator tree,
/// the persistence annotations) is covered by `object_persistence_test.dart`.
/// This file exercises what only a real server can: the full
/// [TomSqlDatasourceRepository] round-trip through a live MariaDB — `save`
/// inserting a row and reading back its generated key, then updating it;
/// `findById` / `findAll` / `count`; `delete` / `deleteById` / `existsById`;
/// and the three query styles (`findByQuerySentence`, and a raw
/// `executeQueryString`).
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTaskRecord, FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// Builds a fresh fixture record; the surrogate key stays `null` so `save`
/// takes its INSERT path and lets the database assign the id.
FixtureTaskRecord _task(String title, int priority, {bool done = false}) =>
    FixtureTaskRecord()
      ..title = title
      ..priority = priority
      ..done = done;

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('FixtureTaskRepository (DB-backed CRUD)', () {
    late TomDataSourceInfo dsi;
    late FixtureTaskRepository repo;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureTaskTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureTask(dsi);
      // A fresh repository per test so no prepared-statement cache leaks the
      // previous test's table state.
      repo = FixtureTaskRepository();
    });

    tearDownAll(TestDatabase.reset);

    test(
      'save inserts a new row and returns the database-assigned key',
      () async {
        final saved = await repo.save(_task('write tests', 3, done: true));
        expect(saved.id, isNotNull);
        expect(saved.title, 'write tests');
        expect(saved.priority, 3);
        expect(saved.done, isTrue);
      },
    );

    test('findById loads a previously saved row', () async {
      final saved = await repo.save(_task('find me', 4));
      final loaded = await repo.findById(saved.id!);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'find me');
      expect(loaded.priority, 4);
    });

    test('findById returns null for an absent id', () async {
      expect(await repo.findById(9999), isNull);
    });

    test('save updates an existing row when the key is set', () async {
      final saved = await repo.save(_task('draft', 1));
      saved.title = 'final';
      saved.priority = 9;
      final updated = await repo.save(saved);
      expect(updated.id, saved.id);
      expect(updated.title, 'final');
      final reloaded = await repo.findById(saved.id!);
      expect(reloaded!.priority, 9);
    });

    test('findAll returns every saved row', () async {
      await repo.save(_task('a', 1));
      await repo.save(_task('b', 2));
      await repo.save(_task('c', 3));
      final all = await repo.findAll();
      expect(all, hasLength(3));
      expect(all.map((t) => t.title).toSet(), {'a', 'b', 'c'});
    });

    test('count returns the number of rows', () async {
      await repo.save(_task('a', 1));
      await repo.save(_task('b', 2));
      final total = await repo.count();
      expect(total.get(), 2);
    });

    test('delete removes the row by its entity key', () async {
      final saved = await repo.save(_task('doomed', 1));
      await repo.delete(saved);
      expect(await repo.findById(saved.id!), isNull);
      expect((await repo.count()).get(), 0);
    });

    test('deleteById removes the row by id', () async {
      final saved = await repo.save(_task('doomed', 1));
      await repo.deleteById(saved.id!);
      expect(await repo.findById(saved.id!), isNull);
    });

    test('existsById reflects presence of every requested id', () async {
      final a = await repo.save(_task('a', 1));
      final b = await repo.save(_task('b', 2));
      expect(await repo.existsById([a.id!, b.id!]), isTrue);
      expect(await repo.existsById([a.id!, 9999]), isFalse);
    });

    test('findByQuerySentence binds parameters and maps rows', () async {
      await repo.save(_task('low', 1));
      await repo.save(_task('high', 9));
      final matches = await repo.findByQuerySentence(
        'FIND BY priority = :priority',
        {'priority': 9},
      );
      expect(matches, hasLength(1));
      expect(matches.first.title, 'high');
    });

    test('deleteByQuerySentence reports how many rows it deleted', () async {
      // The count is the point: a query delete addresses an unknown number of
      // rows, so the number it reports is the only way a caller learns what
      // happened. `deleteByQuerySentence` used to answer `0` unconditionally.
      //
      // This is the half a scripted data source cannot cover
      // (`crud_repository_delete_counts_test.dart` covers the other): that a
      // real MariaDB prepared `DELETE` really does carry an affected-row count
      // on its own result set, and that the value reaching the caller is that
      // count and not a coincidence.
      await repo.save(_task('purge', 1));
      await repo.save(_task('purge', 2));
      await repo.save(_task('purge', 3));
      await repo.save(_task('keep', 4));
      expect(
        await repo.deleteByQuerySentence('DELETE BY title = :title', {
          'title': 'purge',
        }),
        3,
      );
      expect((await repo.count()).get(), 1);
    });

    test('deleteByQuerySentence reports zero when nothing matched', () async {
      await repo.save(_task('keep', 1));
      expect(
        await repo.deleteByQuerySentence('DELETE BY title = :title', {
          'title': 'absent',
        }),
        0,
      );
      expect((await repo.count()).get(), 1);
    });

    test('deleteById reports one row, and zero for an absent id', () async {
      final saved = await repo.save(_task('doomed', 1));
      expect(await repo.deleteById(saved.id!), 1);
      // The constant `1` this replaced was wrong precisely here: the row is
      // already gone, and the caller was told it had deleted one.
      expect(await repo.deleteById(saved.id!), 0);
    });

    test('deleteAllById reports the rows that existed', () async {
      final a = await repo.save(_task('a', 1));
      final b = await repo.save(_task('b', 2));
      expect(await repo.deleteAllById([a.id!, b.id!, 9999]), 2);
    });

    test('executeQueryString runs raw SQL with bound placeholders', () async {
      await repo.save(_task('needle', 5));
      await repo.save(_task('hay', 5));
      final matches = await repo.executeQueryString(
        'SELECT id, title, priority, done FROM fixture_task '
        'WHERE title = :title',
        {'title': 'needle'},
      );
      expect(matches, hasLength(1));
      expect(matches.first.priority, 5);
    });
  }, skip: skipReason);
}
