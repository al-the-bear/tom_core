/// The relational SCIM store against a real MariaDB: the round trip of a
/// resource, the case-insensitive name lookup, the database refusing a
/// duplicate name, and the SCIM service running over it.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('the relational SCIM store', () {
    late TomDataSourceInfo dsi;
    late TomSqlScimStore store;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Dropped, not truncated: the store creates the table on first use, so
      // a previous run with different DDL would otherwise persist.
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS $defaultScimResourceTable',
      );
    });

    tearDownAll(TestDatabase.reset);

    setUp(() async {
      store = TomSqlScimStore(dsi.datasource);
      await store.deleteAll();
    });

    test('a resource round-trips with its document and lifecycle', () async {
      final created = await store.create(TomScimResourceType.user, {
        'userName': 'Alice',
        'externalId': 'e-1',
        'emails': [
          {'type': 'work', 'value': 'alice@example.test'},
        ],
        TomScimSchemas.enterpriseUser: {'employeeNumber': '42'},
      });
      expect(int.tryParse(created.id), isNotNull);
      expect(created.version, 1);

      final read = await store.read(TomScimResourceType.user, created.id);
      expect(read!.name, 'Alice');
      expect(read.externalId, 'e-1');
      expect(read.document, created.document);
      expect(read.created.isUtc, isTrue);
      expect(await store.read(TomScimResourceType.group, created.id), isNull);

      final replaced = await store.replace(
        TomScimResourceType.user,
        created.id,
        {'userName': 'alice.b', 'active': false},
      );
      expect(replaced!.version, 2);
      expect(replaced.active, isFalse);
      expect(replaced.created, read.created);

      expect(await store.delete(TomScimResourceType.user, created.id), isTrue);
      expect(await store.delete(TomScimResourceType.user, created.id), isFalse);
      expect(await store.read(TomScimResourceType.user, created.id), isNull);
    });

    test('a name is found in any case, and is unique per type', () async {
      await store.create(TomScimResourceType.user, {'userName': 'Alice'});
      await store.create(TomScimResourceType.group, {'displayName': 'alice'});
      expect(
        (await store.findByName(TomScimResourceType.user, 'ALICE'))?.name,
        'Alice',
      );
      expect(await store.list(TomScimResourceType.user), hasLength(1));
      // The service checks first; the key is what decides a race between two
      // requests that both passed the check.
      await expectLater(
        store.create(TomScimResourceType.user, {'userName': 'aLiCe'}),
        throwsA(anything),
      );
    });

    test('the SCIM service provisions and deprovisions over it', () async {
      final revoked = <String>[];
      final service = TomScimService(
        store,
        revoke: (username) async => revoked.add(username),
      );
      const base = 'https://app.example.test/scim/v2';
      final alice = await service.create(TomScimResourceType.user, {
        'userName': 'alice',
        'active': true,
      }, base);
      final group = await service.create(TomScimResourceType.group, {
        'displayName': 'Admins',
        'members': [
          {'value': alice['id']},
        ],
      }, base);
      final found = await service.list(
        TomScimResourceType.user,
        base,
        filter: 'userName eq "ALICE"',
      );
      final listed = (found['Resources']! as List).single as Map;
      expect(
        (listed['groups']! as List).single,
        containsPair('value', group['id']),
      );

      await service.patch(TomScimResourceType.user, alice['id']! as String, {
        'Operations': [
          {'op': 'replace', 'path': 'active', 'value': 'False'},
        ],
      }, base);
      expect(revoked, ['alice', 'alice']);

      await service.delete(TomScimResourceType.user, alice['id']! as String);
      final emptied = await service.get(
        TomScimResourceType.group,
        group['id']! as String,
        base,
      );
      expect(emptied['members'], isEmpty);
    });
  }, skip: skipReason);
}
