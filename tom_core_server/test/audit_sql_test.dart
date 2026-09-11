/// Connection-free tests for the relational audit trail's schema and guards.
///
/// Everything here can be asserted without a database, so it runs in the
/// default `testkit :test` pass. The behavioural claims — that the sink
/// actually appends, continues its chain across a reopen, and trims only a
/// prefix — need a real server and live in `audit_sql_db_test.dart`.
///
/// The drift check earns its place for the same reason it does in
/// `scheduling_schema_test.dart`: the DDL exists twice, once as the function
/// the sink calls and once as the migration file a deployment applies. Here it
/// matters more than usual, because the two *optional* migrations are the
/// deployment's write-once guard — a trigger that silently stopped matching the
/// table it protects would leave a trail that looks hardened and is not.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/sql_text.dart';

String _migration(String basename) => readMigration('audit', basename);

void main() {
  group('audit migration files match the shipped DDL', () {
    test('the trail migration is the DDL the sink creates', () {
      expect(
        normaliseSql(_migration('[1]-create_tom_audit_trail.sql')),
        normaliseSql(auditTrailTableDdl(defaultAuditTrailTable)),
      );
    });

    test('the optional update guard is the trigger the module ships', () {
      expect(
        normaliseSql(
          _migration('[2]-guard_tom_audit_trail_no_update@hardened.sql'),
        ),
        normaliseSql(auditTrailNoUpdateTriggerDdl(defaultAuditTrailTable)),
      );
    });

    test('the optional delete guard is the trigger the module ships', () {
      expect(
        normaliseSql(
          _migration('[3]-guard_tom_audit_trail_no_delete@immutable.sql'),
        ),
        normaliseSql(auditTrailNoDeleteTriggerDdl(defaultAuditTrailTable)),
      );
    });

    test('the guards are environment-tagged, not part of the default chain', () {
      // A deployment whose credential already lacks UPDATE gains nothing from
      // the trigger, and the DELETE guard actively blocks retention. Both must
      // therefore be opt-in; the `@env` tag is how a migration says so.
      final names = Directory(
        'example/audit/migrations/main/tomcore',
      ).listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names.where((n) => n.contains('@')), hasLength(2));
      expect(
        names.singleWhere((n) => n.startsWith('[1]')).contains('@'),
        isFalse,
      );
    });

    test('the DDL follows the table name it is given', () {
      // The table name is a constructor argument, so index and trigger names
      // have to move with it — two trails in one schema would otherwise
      // collide on `uq_..._link`.
      final ddl = auditTrailTableDdl('other_trail');
      expect(ddl, contains('CREATE TABLE IF NOT EXISTS other_trail'));
      expect(ddl, contains('uq_other_trail_link'));
      expect(ddl, contains('ix_other_trail_time'));
      expect(
        auditTrailNoUpdateTriggerDdl('other_trail'),
        contains('trg_other_trail_no_update'),
      );
      expect(
        auditTrailNoDeleteTriggerDdl('other_trail'),
        contains('trg_other_trail_no_delete'),
      );
    });
  });

  group('the trail schema encodes the invariants the chain relies on', () {
    final ddl = auditTrailTableDdl(defaultAuditTrailTable);

    test('chain linearity is a database constraint, not a convention', () {
      // Two entries claiming the same predecessor is a fork. As a convention it
      // holds until two writers share a name or a write is replayed; as a
      // unique index it holds always, and the failure arrives at insert time
      // rather than at the next verification.
      expect(
        ddl,
        contains('UNIQUE KEY uq_tom_audit_trail_link (writer, previous_hash)'),
      );
      expect(
        ddl,
        contains('UNIQUE KEY uq_tom_audit_trail_hash (writer, hash)'),
      );
    });

    test('insertion order is the primary key', () {
      // Nothing addresses an audit row by anything else, and insertion order is
      // both the chain's read order and the axis retention trims a prefix from.
      expect(ddl, contains('PRIMARY KEY (seq)'));
      expect(
        ddl,
        contains('seq           BIGINT       NOT NULL AUTO_INCREMENT'),
      );
    });

    test(
      'the chain is scoped by writer so several nodes may share a table',
      () {
        expect(ddl, contains('writer        VARCHAR(64)  NOT NULL'));
        expect(
          ddl,
          contains('KEY ix_tom_audit_trail_time (writer, recorded_at)'),
        );
      },
    );

    test('the record text is stored whole and is not truncated', () {
      // The projection columns are a lossy index for operators; `record` is the
      // canonical JSON that was hashed and is what verification reads.
      expect(ddl, contains('record        LONGTEXT     NOT NULL'));
    });

    test('every index fits the legacy InnoDB index limit', () {
      // (writer, previous_hash) is 64x4 + 64x4 = 512 bytes and
      // (target, action) is 160x4 + 16x4 = 704, both under 767, so the table
      // can be created on a server not switched to DYNAMIC row format.
      expect(ddl, contains('writer        VARCHAR(64)'));
      expect(ddl, contains('target        VARCHAR(160)'));
      expect(ddl, contains('actor         VARCHAR(160)'));
      // target_key is deliberately unindexed: (target, target_key) would not
      // fit, and a trail is searched by target far more often than by key.
      expect(ddl, isNot(contains('target_key)')));
    });

    test('instants are microsecond UTC, like every other framework table', () {
      expect(ddl, contains('recorded_at   DATETIME(6)  NOT NULL'));
    });
  });

  group('the guard triggers reject rather than silently ignore', () {
    test('the update guard signals an error', () {
      final ddl = auditTrailNoUpdateTriggerDdl(defaultAuditTrailTable);
      expect(ddl, contains('BEFORE UPDATE ON tom_audit_trail'));
      // SIGNAL, not a silent no-op: a guard that quietly discarded the update
      // would leave the caller believing it had happened.
      expect(ddl, contains("SIGNAL SQLSTATE '45000'"));
    });

    test('the delete guard signals an error', () {
      final ddl = auditTrailNoDeleteTriggerDdl(defaultAuditTrailTable);
      expect(ddl, contains('BEFORE DELETE ON tom_audit_trail'));
      expect(ddl, contains("SIGNAL SQLSTATE '45000'"));
    });
  });

  group('the write-once check reports what it observed', () {
    TomAuditWriteOnceCheck check({
      bool grantsUpdate = true,
      bool grantsDelete = true,
      String? updateTrigger,
      String? deleteTrigger,
    }) => TomAuditWriteOnceCheck(
      table: 'tom_audit_trail',
      grantsUpdate: grantsUpdate,
      grantsDelete: grantsDelete,
      updateGuardTrigger: updateTrigger,
      deleteGuardTrigger: deleteTrigger,
    );

    test('a missing grant blocks the statement', () {
      expect(check(grantsUpdate: false).updatesBlocked, isTrue);
      expect(check(grantsDelete: false).deletesBlocked, isTrue);
    });

    test('a trigger blocks a statement the grant permits', () {
      // The case the privilege probe alone cannot see: a zero-row UPDATE
      // matches nothing and so fires no FOR EACH ROW trigger, and the table
      // looks perfectly mutable.
      final protected = check(updateTrigger: 'trg_tom_audit_trail_no_update');
      expect(protected.grantsUpdate, isTrue);
      expect(protected.updatesBlocked, isTrue);
    });

    test('an unprotected table is reported as such', () {
      final open = check();
      expect(open.updatesBlocked, isFalse);
      expect(open.isAppendOnly, isFalse);
      expect(open.summary, contains('UPDATE PERMITTED'));
    });

    test('append-only needs both statements blocked', () {
      expect(check(grantsUpdate: false).isAppendOnly, isFalse);
      expect(
        check(grantsUpdate: false, grantsDelete: false).isAppendOnly,
        isTrue,
      );
    });

    test('the summary names the trigger that is doing the blocking', () {
      final guarded = check(
        updateTrigger: 'trg_tom_audit_trail_no_update',
        grantsDelete: false,
      );
      expect(
        guarded.summary,
        contains('blocked by trg_tom_audit_trail_no_update'),
      );
      expect(guarded.summary, contains('DELETE not granted'));
    });
  });

  group('wiring', () {
    test('a sink over an unregistered data source fails at construction', () {
      // Not on the first audited action: the trail is fail-closed, so a
      // misconfiguration discovered there turns into a failed request instead
      // of a failed start-up.
      //
      // The assertion names the base class is what is raised, deliberately — a construction-time
      // wiring guard has no `catch` clause to discriminate for, so there is
      // nothing for a subtype to add. `TomServerException` gives the argument
      // and `server_exception_family_test.dart` pins the five sites that may do
      // it, so this assertion is as narrow as the type system allows here.
      expect(
        () => TomSqlAuditSink.named('no_such_datasource', writer: 'node-a'),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'audit.sink.unknown_datasource',
          ),
        ),
      );
    });
  });

  // The memory and file sinks' counterparts live in `audit_test.dart`; the
  // reasoning is there. It is asserted for all three because it is a promise of
  // `TomAuditSink` rather than of any one implementation, and a caller holding
  // the abstract type has no way to ask which it got.
  group('write reports failure through the future it returns', () {
    test('refusing a record does not throw at the call site', () async {
      final sink = TomSqlAuditSink(_UnusedDataSource(), writer: 'node-a');
      await sink.close();

      // Not `expect(() => sink.write(r), throwsA(...))`: that form passes
      // whichever channel the error takes, and the channel is the subject.
      late final Future<TomAuditEntry> refused;
      expect(() => refused = sink.write(_record()), returnsNormally);
      expect(
        refused,
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.sink.closed',
          ),
        ),
      );
    });
  });
}

/// A record with no content of interest — these tests never store one.
TomAuditRecord _record() => TomAuditRecord(
  id: 'r1',
  timestamp: DateTime.utc(2026, 7, 28, 10, 30),
  actor: TomAuditActor.system,
  action: TomAuditAction.update,
  target: 'Widget',
  outcome: TomAuditOutcome.succeeded,
);

/// A data source that must never be reached.
///
/// A closed sink is refused before it looks at storage, so any statement
/// arriving here means the guard did not run — which is a louder failure than
/// a wrong assertion, and the reason this fake answers nothing rather than
/// answering emptily.
class _UnusedDataSource implements TomDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'A closed audit sink reached its data source for '
    '${invocation.memberName}.',
  );
}
