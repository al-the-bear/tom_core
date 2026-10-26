/// The SQL export register against a live database, and the service's quota
/// and the retention purge over it.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

TomTabularResult _report(int rows) => TomTabularResult.single(
  title: 'Sales',
  section: TomTabularSection.ofRows(
    [TomTabularColumn('line', label: 'Line')],
    [
      for (var i = 0; i < rows; i++) TomTabularRow(['row $i']),
    ],
  ),
);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomSqlExportRegister register;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    final dsi = await TestDatabase.register();
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS tom_export');
    register = TomSqlExportRegister(dsi.datasource);
    addTearDown(TestDatabase.reset);
  });

  setUp(() async {
    if (reachable) await register.deleteAll();
  });

  TomExportRecord record(String key, String owner, int bytes, DateTime at) =>
      TomExportRecord(
        key: key,
        owner: owner,
        mediaType: 'text/csv',
        byteCount: bytes,
        storedAt: at,
        title: 'Sales',
      );

  test('records, finds, sums, lists and removes', () async {
    final at = DateTime.utc(2026, 10, 1, 8, 30, 0, 123);
    await register.record(record('2026/a.csv', 'ada', 10, at));
    await register.record(
      record('2026/b.csv', 'ada', 32, at.add(const Duration(days: 1))),
    );
    await register.record(record('2026/c.csv', 'bob', 5, at));

    final found = (await register.find('2026/a.csv'))!;
    expect(found.owner, 'ada');
    expect(found.byteCount, 10);
    expect(found.storedAt, at);
    expect(found.title, 'Sales');

    final usage = await register.usageOf('ada');
    expect((usage.count, usage.bytes), (2, 42));
    final none = await register.usageOf('nobody');
    expect((none.count, none.bytes), (0, 0));
    expect((await register.ownedBy('ada')).map((r) => r.key), [
      '2026/b.csv',
      '2026/a.csv',
    ]);
    expect(
      (await register.storedBefore(
        at.add(const Duration(hours: 1)),
        limit: 1,
      )).map((r) => r.key),
      ['2026/a.csv'],
    );

    // Recording a key again replaces its row.
    await register.record(record('2026/a.csv', 'ada', 11, at));
    expect((await register.usageOf('ada')).bytes, 43);

    expect(await register.remove('2026/a.csv'), isTrue);
    expect(await register.remove('2026/a.csv'), isFalse);
  }, skip: skip);

  test('the quota and the purge over the SQL register', () async {
    final store = TomMemoryExportStore();
    final service = TomExportService(
      store: store,
      register: register,
      quota: const TomExportQuota(maxCount: 1),
    );
    await service.storeAs(_report(2), 'csv', key: 'a.csv', owner: 'ada');
    await expectLater(
      service.storeAs(_report(2), 'csv', key: 'b.csv', owner: 'ada'),
      throwsA(
        isA<TomExportException>().having(
          (e) => e.key,
          'key',
          'export.quota.count_exceeded',
        ),
      ),
    );

    final retention = TomExportRetention(
      store: store,
      register: register,
      maxAge: const Duration(minutes: 1),
    );
    expect(
      await retention.purge(now: DateTime.now().add(const Duration(hours: 1))),
      1,
    );
    expect(await store.exists('a.csv'), isFalse);
    expect(await register.find('a.csv'), isNull);
  }, skip: skip);
}
