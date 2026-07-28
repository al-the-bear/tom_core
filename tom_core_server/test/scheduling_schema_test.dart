/// Connection-free tests for the relational scheduler's schema and its instant
/// encoding (CSEXB3).
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

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Strips SQL comments and collapses whitespace, so the comparison is about the
/// statement rather than about how it was laid out or documented.
String _normalise(String sql) => sql
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('--'))
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r';\s*$'), '')
    .trim();

String _migration(String basename) =>
    File('example/scheduling/migrations/main/tomcore/$basename')
        .readAsStringSync();

void main() {
  group('scheduling migration files match the shipped DDL', () {
    test('the job queue migration is the DDL the store creates', () {
      expect(
        _normalise(_migration('[1]-create_tom_job_run.sql')),
        _normalise(jobRunTableDdl(defaultJobRunTable)),
      );
    });

    test('the lease migration is the DDL the lock creates', () {
      expect(
        _normalise(_migration('[2]-create_tom_lease.sql')),
        _normalise(leaseTableDdl(defaultLeaseTable)),
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

    test('one run per job per window is a database constraint', () {
      // The scheduler's idempotence key. As a convention it holds until two
      // nodes plan the same window at the same moment; as a unique index it
      // holds always.
      expect(ddl, contains('UNIQUE KEY uq_tom_job_run_window '
          '(job_name, scheduled_for)'));
    });

    test('the claim scan and the recovery scan each have an index', () {
      expect(ddl, contains('KEY ix_tom_job_run_due (state, run_at)'));
      expect(ddl, contains('KEY ix_tom_job_run_lease (state, claimed_at)'));
    });

    test('the composite unique key fits the legacy InnoDB index limit', () {
      // 160 utf8mb4 characters (640 bytes) plus a DATETIME(6) (8 bytes) stays
      // under the 767-byte limit of the older row formats, so the table can be
      // created on a server that has not been switched to DYNAMIC.
      expect(ddl, contains('job_name      VARCHAR(160)'));
    });
  });

  group('the lease schema encodes the fencing invariants', () {
    final ddl = leaseTableDdl(defaultLeaseTable);

    test('a version column exists so a matching update still changes the row',
        () {
      // MariaDB counts changed rows, not matched rows. Without this column a
      // renewal in the same clock instant with the same TTL reports zero
      // affected rows and looks like a lost lease.
      expect(ddl, contains('version     BIGINT       NOT NULL DEFAULT 1'));
    });

    test('release is a flag, not a delete, so the token counter survives', () {
      expect(ddl, contains('released    TINYINT(1)   NOT NULL DEFAULT 0'));
      expect(ddl, contains('token       BIGINT       NOT NULL'));
    });

    test('one row per resource', () {
      expect(ddl, contains('PRIMARY KEY (resource)'));
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
      expect(sqlInstant(DateTime.utc(2026, 3, 1)),
          '2026-03-01 00:00:00.000000');
      expect(sqlInstant(DateTime.utc(999, 1, 2, 3, 4, 5, 6, 7)),
          '0999-01-02 03:04:05.006007');
    });

    test('a stored value already carrying a zone marker is not double-marked',
        () {
      expect(parseSqlInstant('2026-03-01T10:00:00.000000Z'),
          DateTime.utc(2026, 3, 1, 10));
    });
  });
}
