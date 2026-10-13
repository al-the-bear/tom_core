/// Connection-free tests for the relational scheduler's schema and its instant
/// encoding.
///
/// Everything here can be asserted without a database, so it runs in the default
/// `testkit :test` pass. The behavioural claims — that the stores actually
/// arbitrate a claim, that a lapsed lease is taken over exactly once — need a
/// real server and live in `scheduling_db_test.dart`.
///
/// The drift check earns its place: the DDL exists twice, once as the function
/// the stores call and once as the migration file a deployment applies. A schema
/// that exists in two places and is checked in one will eventually exist in two
/// versions, and the failure mode — a table that works in tests and is missing
/// an index in production — is invisible until it is expensive.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/sql_text.dart';

String _migration(String basename) => readMigration('scheduling', basename);

void main() {
  group('scheduling migration files match the shipped DDL', () {
    test('the job queue migration is the DDL the store creates', () {
      expect(
        normaliseSql(_migration('[1]-create_tom_job_run.sql')),
        normaliseSql(jobRunTableDdl(defaultJobRunTable)),
      );
    });

    test('the lease migration is the DDL the lock creates', () {
      expect(
        normaliseSql(_migration('[2]-create_tom_lease.sql')),
        normaliseSql(leaseTableDdl(defaultLeaseTable)),
      );
    });

    test('the roll-call migration is the DDL the node table creates', () {
      expect(
        normaliseSql(_migration('[3]-create_tom_scheduler_node.sql')),
        normaliseSql(schedulerNodeTableDdl(defaultSchedulerNodeTable)),
      );
    });

    test('the DDL follows the table name it is given', () {
      // The table name is a constructor argument, so index names have to move
      // with it — two stores over differently-named tables in one schema would
      // otherwise collide on `uq_..._window`.
      final ddl = jobRunTableDdl('other_queue');
      expect(ddl, contains('CREATE TABLE IF NOT EXISTS other_queue'));
      expect(ddl, contains('uq_other_queue_window'));
      expect(ddl, contains('ix_other_queue_due'));
    });
  });

  group('the queue schema encodes the invariants the scheduler relies on', () {
    final ddl = jobRunTableDdl(defaultJobRunTable);

    test(
      'one run per job per window, per tenant, is a database constraint',
      () {
        // The scheduler's idempotence key. As a convention it holds until two
        // nodes plan the same window at the same moment; as a unique index it
        // holds always. The tenant is part of it: two tenants' events in one
        // instant are two runs.
        expect(
          ddl,
          contains(
            'UNIQUE KEY uq_tom_job_run_window '
            '(job_name, tenant, scheduled_for)',
          ),
        );
      },
    );

    test('the claim scan and the recovery scan each have an index', () {
      expect(ddl, contains('KEY ix_tom_job_run_due (state, run_at)'));
      expect(ddl, contains('KEY ix_tom_job_run_lease (state, claimed_at)'));
    });

    test(
      'when execution began is recorded separately from when it was claimed',
      () {
        // The two instants answer different questions, and recovery needs both:
        // a row that was claimed and never started can be re-queued for any job,
        // while one that was already executing may only be re-queued when the job
        // opts in. One column carrying both would collapse that distinction.
        expect(ddl, contains('claimed_at    DATETIME(6)  NULL'));
        expect(ddl, contains('started_at    DATETIME(6)  NULL'));
      },
    );

    test('the composite unique key fits the legacy InnoDB index limit', () {
      // 150 + 32 utf8mb4 characters (600 + 128 bytes) plus a DATETIME(6) (8
      // bytes) is 736, under the 767-byte limit of the older row formats, so
      // the table can be created on a server that has not been switched to
      // DYNAMIC.
      expect(ddl, contains(RegExp(r'job_name\s+VARCHAR\(150\)')));
      expect(
        ddl,
        contains(RegExp(r"tenant\s+VARCHAR\(32\)\s+NOT NULL DEFAULT ''")),
      );
    });
  });

  group('the lease schema encodes the fencing invariants', () {
    final ddl = leaseTableDdl(defaultLeaseTable);

    test(
      'a version column exists so a matching update still changes the row',
      () {
        // MariaDB counts changed rows, not matched rows. Without this column a
        // renewal in the same clock instant with the same TTL reports zero
        // affected rows and looks like a lost lease.
        expect(ddl, contains('version     BIGINT       NOT NULL DEFAULT 1'));
      },
    );

    test('release is a flag, not a delete, so the token counter survives', () {
      expect(ddl, contains('released    TINYINT(1)   NOT NULL DEFAULT 0'));
      expect(ddl, contains('token       BIGINT       NOT NULL'));
    });

    test('one row per resource', () {
      expect(ddl, contains('PRIMARY KEY (resource)'));
    });
  });

  group('the roll-call schema encodes what the failure formula needs', () {
    final ddl = schedulerNodeTableDdl(defaultSchedulerNodeTable);

    test('one row per node, rewritten rather than appended', () {
      // The roll call is a current-state table, not a history: `REPLACE INTO`
      // against this key is what keeps it one row per node however long the
      // cluster runs.
      expect(ddl, contains('PRIMARY KEY (node_id)'));
    });

    test('each node publishes its own check-in cadence', () {
      // Stored per node rather than assumed globally, because the failure test
      // judges a peer by the interval *it* keeps: a chatty node and a quiet one
      // must not be given the same grace.
      expect(ddl, contains('checkin_interval BIGINT       NOT NULL'));
      expect(ddl, contains('checkin_at       DATETIME(6)  NOT NULL'));
    });

    test('the node id is wide enough for the owner strings claims use', () {
      // `node_id` is joined against `tom_job_run.claimed_by`, so a failed node's
      // work can be attributed to it. A narrower column here would silently
      // truncate ids that claim fine.
      expect(ddl, contains('node_id          VARCHAR(191) NOT NULL'));
    });
  });

  group('instant encoding', () {
    test('a UTC instant round-trips exactly', () {
      final value = DateTime.utc(2026, 3, 1, 10, 20, 30, 400, 500);
      expect(parseSqlInstant(sqlInstant(value)), value);
    });

    test('a local instant round-trips as the same moment, labelled UTC', () {
      final local = DateTime(2026, 3, 1, 10, 20, 30);
      final restored = parseSqlInstant(sqlInstant(local));
      // Deliberate: a cluster must not compare wall clocks, so the store gives
      // every caller back a UTC instant regardless of what it was handed.
      expect(restored.isUtc, isTrue);
      expect(restored.isAtSameMomentAs(local), isTrue);
    });

    test('the rendered form is a fixed-width DATETIME(6) literal', () {
      // Fixed width keeps the text ordered the same way in SQL as in Dart, so a
      // `run_at <= :now` comparison cannot be surprised by a shorter fraction.
      expect(
        sqlInstant(DateTime.utc(2026, 3, 1)),
        '2026-03-01 00:00:00.000000',
      );
      expect(
        sqlInstant(DateTime.utc(999, 1, 2, 3, 4, 5, 6, 7)),
        '0999-01-02 03:04:05.006007',
      );
    });

    test(
      'a stored value already carrying a zone marker is not double-marked',
      () {
        expect(
          parseSqlInstant('2026-03-01T10:00:00.000000Z'),
          DateTime.utc(2026, 3, 1, 10),
        );
      },
    );
  });
}
