/// The data source half of the framework readiness check, against a live
/// database: a registered data source that answers `SELECT 1` is ready, one
/// that has been closed is not.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('data source readiness', () {
    late TomDataSourceInfo dsi;
    const name = TestDatabase.datasourceName;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    test('a data source that answers is ready', () async {
      final checks = await TomFrameworkReadinessAnalyzer().checks();
      final check = checks.singleWhere((c) => c.subject == 'datasource $name');
      expect(check.passed, isTrue, reason: '$check');
      final status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isTrue, reason: status.message);
      expect(status.message, contains('datasource $name: ok'));
    });

    test('a closed data source makes the server not ready', () async {
      await dsi.datasource.close();
      final status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isFalse);
      expect(status.statusCode, 503);
      expect(status.message, contains('datasource $name: not operational'));
    });
  }, skip: skip);
}
