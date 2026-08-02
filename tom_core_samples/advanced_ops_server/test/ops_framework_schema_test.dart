/// The framework tables this package ships, checked against the descriptors the
/// framework will use to read them.
///
/// `[004]-ops_framework_tables.sql` is hand-written DDL, copied from the
/// framework's canonical reference migrations. That copy is the risk: the
/// scheduler, the lease lock and the audit sink address these tables through
/// column names compiled into `tom_core_server`, and a missing column or a
/// too-narrow type is a defect that appears at the first tick of a live
/// deployment and nowhere earlier.
///
/// [TomFrameworkSchemaCheck] closes that gap without a database. It builds the
/// model the framework expects, replays the migration chain as text, and reports
/// whether the two converge — so a drift is a failing test on this machine
/// rather than a scheduler that cannot find `scheduled_for` in production.
///
/// Connection-free: the chain is read off disk and parsed, never executed.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// This package's contribution to the `app_db/app_schema` chain.
const String _opsSchemaDir = 'database_migrations/app_db/app_schema/';

/// The app server's part of the same chain.
const String _appSchemaDir =
    '../advanced_app_server/database_migrations/app_db/app_schema/';

/// The migration files of [directory], in applied order.
List<TomMigrationArtifact> _artifacts(String directory) {
  final files = Directory(directory).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      TomMigrationArtifact(
        file.uri.pathSegments.last,
        file.readAsStringSync(),
      ),
  ];
}

/// Both packages' files, in the order the engine would apply them.
///
/// The whole chain, not just this package's file: the engine applies whatever it
/// has not seen for a (datasource, schema) pair regardless of which package the
/// folder sits in, so a check over half the chain would be checking a database
/// that never exists.
List<TomMigrationArtifact> _wholeChain() => [
      ..._artifacts(_appSchemaDir),
      ..._artifacts(_opsSchemaDir),
    ];

void main() {
  group('the hand-written DDL converges with the framework descriptors', () {
    test('every framework table this server uses is present and correct', () {
      final check = TomFrameworkSchemaCheck();
      final report = check.verifyChain(
        datasource: 'app_db',
        schema: 'app_schema',
        tables: [
          // Exactly the four `[004]` creates, and no more: the blob tables of
          // the same chain are the app server's, checked by its own suite.
          jobRunTable(defaultJobRunTable),
          leaseTable(defaultLeaseTable),
          schedulerNodeTable(defaultSchedulerNodeTable),
          auditTrailTable(defaultAuditTrailTable),
        ],
        chain: _wholeChain(),
      );

      // `describe()` as the reason, because a bare `isTrue` on a schema check
      // is the least useful failure message in the suite — the report names the
      // table and the column.
      expect(report.converged, isTrue, reason: report.describe());
    });

    test('the check is checking something', () {
      // A guard on the guard. If the chain were read from the wrong directory
      // the artifact list would be empty, `verifyChain` would find nothing to
      // disagree with, and the test above would pass while asserting nothing.
      final chain = _wholeChain();
      expect(chain, isNotEmpty);
      expect(
        chain.map((artifact) => artifact.basename),
        contains('[004]-ops_framework_tables.sql'),
      );
    });
  });

  group('the tables are created by the chain, not at start-up', () {
    final sql = File('${_opsSchemaDir}[004]-ops_framework_tables.sql')
        .readAsStringSync();

    test('the migration creates all four framework tables', () {
      for (final table in [
        defaultJobRunTable,
        defaultLeaseTable,
        defaultSchedulerNodeTable,
        defaultAuditTrailTable,
      ]) {
        expect(sql, contains(table), reason: table);
      }
    });

    test('the runtime asks the framework not to create them again', () {
      // `createSchema: false` throughout the production wiring. A component
      // quietly creating its own table would mean the schema exists in two
      // places — the chain and a start-up side effect — and this convergence
      // check could no longer tell which one the running server used.
      // Comment lines are dropped first: this file's own prose says
      // `createSchema: false`, and counting it would make the assertion depend
      // on how many times the decision is explained.
      final code = File('lib/src/ops_runtime.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('createSchema: true')));
      expect(
        'createSchema: false'.allMatches(code).length,
        4,
        reason: 'the three scheduling components and the audit sink',
      );
    });

    test('the one-run-per-window constraint is a database invariant', () {
      // The load-bearing unique key: it makes "one run per job per window" a
      // property of the table rather than a convention two nodes both have to
      // honour. Losing it would leave every other test in this package passing.
      expect(sql, contains('uq_tom_job_run_window'));
    });
  });
}
