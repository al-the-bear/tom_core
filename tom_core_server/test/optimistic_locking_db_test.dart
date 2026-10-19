/// Optimistic locking against a real MariaDB: of two saves of one loaded row,
/// the second is refused with `crud_repository.save.version_conflict` instead
/// of silently overwriting the first — whether the two run one after the other
/// or at the same instant.
///
/// The last group adds the version column to an existing table through a
/// migration, the way a deployment turns the feature on for data it already
/// holds, and saves a row that was written before the column existed.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureVersionedDoc, FixtureVersionedDocRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _docDdl = '''
CREATE TABLE fixture_versioned_doc (
  id      BIGINT       NOT NULL AUTO_INCREMENT,
  version BIGINT       NOT NULL DEFAULT 0,
  title   VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

/// The table as it was before versioning: no version column.
const _unversionedDdl = '''
CREATE TABLE fixture_versioned_doc (
  id      BIGINT       NOT NULL AUTO_INCREMENT,
  title   VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

/// The migration that turns versioning on for the rows already there.
const _addVersion =
    'ALTER TABLE fixture_versioned_doc '
    'ADD COLUMN version BIGINT NOT NULL DEFAULT 0;';

/// Matches the refusal of a versioned write.
TypeMatcher<TomOptimisticLockException> _conflict(
  String key, {
  required int held,
  int? stored,
}) => isA<TomOptimisticLockException>()
    .having((e) => e.key, 'key', key)
    .having((e) => e.clientThrow, 'clientThrow', isTrue)
    .having((e) => e.heldVersion, 'heldVersion', held)
    .having((e) => e.storedVersion, 'storedVersion', stored);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  late TomDataSourceInfo info;

  Future<void> recreate(String ddl) async {
    await info.datasource.executeCommand(
      'DROP TABLE IF EXISTS fixture_versioned_doc',
    );
    await TestDatabase.execute(info.datasource, ddl);
  }

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    info = await TestDatabase.register();
  });

  // The table goes with the suite's database, which the fixture drops when
  // this group ends; dropping it here as well would reach for a database that
  // may already be gone.
  tearDownAll(() async {
    if (!reachable) return;
    await TestDatabase.reset();
  });

  group('two edits of one row', () {
    late FixtureVersionedDocRepository docs;

    setUp(() async {
      await recreate(_docDdl);
      docs = FixtureVersionedDocRepository();
    });

    test('an insert starts the row at version 1', () async {
      final saved = await docs.save(
        FixtureVersionedDoc()
          ..title = 'draft'
          ..version = 41,
      );
      expect(saved.version, 1);
    });

    test('each save moves the version by one', () async {
      var doc = await docs.save(FixtureVersionedDoc()..title = 'v1');
      doc = await docs.save(doc..title = 'v2');
      doc = await docs.save(doc..title = 'v3');
      expect(doc.version, 3);
      expect((await docs.findById(doc.id!))!.title, 'v3');
    });

    test('the second of two saves of one loaded row is refused', () async {
      final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
      final alice = (await docs.findById(created.id!))!;
      final bob = (await docs.findById(created.id!))!;

      await docs.save(alice..title = 'alice');
      await expectLater(
        docs.save(bob..title = 'bob'),
        throwsA(
          _conflict(
            'crud_repository.save.version_conflict',
            held: 1,
            stored: 2,
          ),
        ),
      );
      // Alice's edit is what the row holds; Bob's wrote nothing.
      final stored = (await docs.findById(created.id!))!;
      expect(stored.title, 'alice');
      expect(stored.version, 2);
    });

    test('two saves at the same instant: exactly one wins', () async {
      final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
      final copies = [
        for (var i = 0; i < 6; i++) (await docs.findById(created.id!))!,
      ];
      final outcomes = await Future.wait([
        for (var i = 0; i < copies.length; i++)
          docs
              .save(copies[i]..title = 'edit $i')
              .then<Object>((saved) => saved)
              .catchError((Object e) => e),
      ]);
      final won = outcomes.whereType<FixtureVersionedDoc>().toList();
      final refused = outcomes.whereType<TomOptimisticLockException>().toList();
      expect(won, hasLength(1));
      expect(refused, hasLength(copies.length - 1));
      expect(
        refused.map((e) => e.key),
        everyElement('crud_repository.save.version_conflict'),
      );
      final stored = (await docs.findById(created.id!))!;
      expect(stored.title, won.single.title);
      expect(stored.version, 2);
    });

    test('a refused editor reloads and saves on top of the winner', () async {
      final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
      final stale = (await docs.findById(created.id!))!;
      await docs.save((await docs.findById(created.id!))!..title = 'first');
      await expectLater(
        docs.save(stale..title = 'second'),
        throwsA(isA<TomOptimisticLockException>()),
      );
      final fresh = (await docs.findById(created.id!))!;
      final saved = await docs.save(fresh..title = 'second');
      expect(saved.title, 'second');
      expect(saved.version, 3);
    });

    test('a save without a version is refused, not waved through', () async {
      final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
      await expectLater(
        docs.save(
          FixtureVersionedDoc()
            ..id = created.id
            ..title = 'no version',
        ),
        throwsA(
          isA<TomRepositoryException>()
              .having(
                (e) => e.key,
                'key',
                'crud_repository.save.version_missing',
              )
              .having((e) => e.clientThrow, 'clientThrow', isTrue),
        ),
      );
      expect((await docs.findById(created.id!))!.title, 'draft');
    });

    test('a save of a row deleted meanwhile names no stored version', () async {
      final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
      final stale = (await docs.findById(created.id!))!;
      await docs.deleteById(created.id!);
      // An unscoped entity runs no existence check first, so it is the
      // versioned update matching no row that refuses the save — with no
      // stored version, because there is no row to have one.
      await expectLater(
        docs.save(stale..title = 'too late'),
        throwsA(
          _conflict(
            'crud_repository.save.version_conflict',
            held: 1,
          ).having((e) => e.defaultUserMessage, 'message', contains('deleted')),
        ),
      );
      expect(await docs.findById(created.id!), isNull);
    });

    test(
      'deleting a row someone changed since it was loaded is refused',
      () async {
        final created = await docs.save(FixtureVersionedDoc()..title = 'draft');
        final stale = (await docs.findById(created.id!))!;
        await docs.save((await docs.findById(created.id!))!..title = 'edited');
        await expectLater(
          docs.delete(stale),
          throwsA(
            _conflict(
              'crud_repository.delete.version_conflict',
              held: 1,
              stored: 2,
            ),
          ),
        );
        expect((await docs.findById(created.id!))!.title, 'edited');
        await docs.delete((await docs.findById(created.id!))!);
        expect(await docs.findById(created.id!), isNull);
      },
    );
  }, skip: skipReason);

  group('a migration turns versioning on for existing rows', () {
    setUp(() async {
      await recreate(_unversionedDdl);
      await info.datasource.executeCommand(
        "INSERT INTO fixture_versioned_doc (title) VALUES ('legacy')",
      );
      await info.datasource.executeCommand(
        'DROP TABLE IF EXISTS optimistic_locking_versioning',
      );
      final adaptor = TestDatabase.migrationAdaptor();
      await adaptor.initializeMigration(info, 'optimistic_locking');
      await adaptor.applyMigration(
        info,
        'optimistic_locking',
        1,
        'add_version_to_fixture_versioned_doc',
        _addVersion,
      );
    });

    tearDown(() async {
      await info.datasource.executeCommand(
        'DROP TABLE IF EXISTS optimistic_locking_versioning',
      );
    });

    test('a row written before the column existed loads at version 0 and '
        'saves to 1', () async {
      final docs = FixtureVersionedDocRepository();
      final legacy = (await docs.findAll()).single;
      expect(legacy.version, 0);
      final saved = await docs.save(legacy..title = 'migrated');
      expect(saved.version, 1);
    });

    test('and is locked from then on', () async {
      final docs = FixtureVersionedDocRepository();
      final first = (await docs.findAll()).single;
      final second = (await docs.findAll()).single;
      await docs.save(first..title = 'one');
      await expectLater(
        docs.save(second..title = 'two'),
        throwsA(
          _conflict(
            'crud_repository.save.version_conflict',
            held: 0,
            stored: 1,
          ),
        ),
      );
    });
  }, skip: skipReason);
}
