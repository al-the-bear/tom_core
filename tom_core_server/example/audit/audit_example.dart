/// Executable example for the audit module of `tom_core_server` (CE-LG).
///
/// Demonstrates the audit trail without a database or a server: installing a
/// sink, the shape of a [TomAuditRecord], attribution from the ambient zone,
/// the declared-versus-automatic split expressed by [TomAudited], redaction,
/// the tamper-evident hash chain, the append-only file sink with its whole-file
/// retention, the relational sink's schema and write-once check, and the
/// anchors that catch the one attack the chain alone cannot see.
///
/// The two *chokepoints* — the endpoint pipeline and the repository write path
/// — are what make this automatic in a running server; they are exercised by
/// `test/endpoints_pipeline_test.dart` and `test/audit_db_test.dart` (the
/// latter against a live MariaDB). The relational sink's behaviour needs a
/// server too and lives in `test/audit_sql_db_test.dart`. Here the records are
/// produced by hand so the example stays connection-free.
///
/// Run with `dart run example/audit/audit_example.dart`. Every step checks its
/// own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript. The same behaviour is covered by
/// `test/audit_test.dart`.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

Future<void> run() async {
  // 1. Nothing is audited until a sink is installed. That is what makes the
  //    trail switchable at startup rather than compiled into every call site.
  print('1. enabled before install    : ${TomAuditTrail.isEnabled}');
  check(
    !TomAuditTrail.isEnabled,
    'nothing is audited until a sink is installed',
  );

  final sink = TomMemoryAuditSink();
  TomAuditTrail.install(sink);
  print('   enabled after install     : ${TomAuditTrail.isEnabled}');

  // 2. A mutation record carries only the fields that changed. An auditor
  //    reading "email: a -> b" learns more than one handed the whole row.
  final before = {'email': 'ada@old.example', 'name': 'Ada'};
  final after = {'email': 'ada@new.example', 'name': 'Ada'};
  final diff = auditDiff(before, after);
  print('2. changed fields            : ${diff.before} -> ${diff.after}');
  check(
    diff.after.keys.single == 'email',
    'a mutation record carries only the fields that actually changed',
  );

  // 3. Attribution comes from the ambient zone, not from a parameter threaded
  //    through every layer. Outside a request there is still an actor: SYSTEM.
  await TomAuditTrail.recordAction(
    action: TomAuditAction.execute,
    target: 'NightlyRebuild',
    outcome: TomAuditOutcome.succeeded,
  );
  print('3. background actor          : ${sink.records.single.actor.username}');
  check(
    sink.records.single.actor.username == TomAuditActor.systemUsername,
    'work done outside a request is still attributed, to SYSTEM',
  );

  sink.clear();
  final principal = TomPrincipal(
    user: TomUser(id: 42, username: 'ada'),
    authenticated: true,
  );
  await runZoned(
    () => TomAuditTrail.recordAction(
      action: TomAuditAction.execute,
      target: 'AdminApi.grant',
      outcome: TomAuditOutcome.succeeded,
    ),
    zoneValues: {TomPrincipal: principal, TomRequestId: TomRequestId()},
  );
  final attributed = sink.records.single;
  print(
    '   in-request actor          : ${attributed.actor.username} '
    '(id ${attributed.actor.userId}, request ${attributed.requestId})',
  );
  check(
    attributed.actor.userId == 42,
    'inside a request the actor is taken from the ambient zone, unthreaded',
  );

  // 4. The declared-versus-automatic split. Mutations are audited by default —
  //    forgetting to declare one would be a silent gap — while reads are never
  //    audited at all, because auditing every row a list endpoint returns
  //    buries the entries that matter.
  const byDefault = TomAuditPolicy.defaultPolicy;
  print(
    '4. default audits update     : ${byDefault.audits(TomAuditAction.update)}',
  );
  print(
    '   default audits read       : ${byDefault.audits(TomAuditAction.read)}',
  );
  check(
    byDefault.audits(TomAuditAction.update),
    'mutations are audited without being declared, so none can be forgotten',
  );
  check(
    !byDefault.audits(TomAuditAction.read),
    'reads are not, so the entries that matter are not buried under them',
  );

  // The declarations that change it, as they appear on an entity or endpoint —
  // `TomAuditPolicy.from` is exactly what the reflector applies to the
  // annotation it finds on the type:
  //   @TomAudited(enabled: false)          -> opt the type out entirely
  //   @TomAudited(redact: ['secret'])      -> keep a value out of the trail
  //   @TomAudited()  on an endpoint method -> audit that invocation
  // There is no declaration that turns reads on. `audits(read)` is `false`
  // under every annotation, because the read path records nothing for it to
  // be true about.
  final optedOut = TomAuditPolicy.from(const TomAudited(enabled: false));
  final redacted = TomAuditPolicy.from(const TomAudited(redact: ['secret']));
  print(
    '   opted-out audits update   : ${optedOut.audits(TomAuditAction.update)}',
  );
  print(
    '   any policy audits read    : '
    '${[byDefault, optedOut, redacted].any((p) => p.audits(TomAuditAction.read))}',
  );
  check(
    !optedOut.audits(TomAuditAction.update),
    'a type can opt out of the trail entirely, visibly at its source',
  );
  check(
    ![byDefault, optedOut, redacted].any((p) => p.audits(TomAuditAction.read)),
    'no declaration turns reads on, because the read path records nothing',
  );

  // Recording who looked is therefore explicit. `recordAction` consults no
  // entity policy, so the caller that accepted the volume cost is the one that
  // writes the entry — and it can say which rows mattered, which a chokepoint
  // on `findAll` could not.
  sink.clear();
  await TomAuditTrail.recordAction(
    action: TomAuditAction.read,
    target: 'Patient',
    targetKey: '7',
    outcome: TomAuditOutcome.succeeded,
    detail: 'case review',
  );
  print(
    '   hand-recorded read        : ${sink.records.single.action.name} '
    'of ${sink.records.single.target}#${sink.records.single.targetKey}',
  );
  check(
    sink.records.single.action == TomAuditAction.read,
    'a read reaches the trail only when a caller records it by hand',
  );

  // 5. Redaction is not a column grade: it keeps the value from existing in a
  //    *second* place at all. The field still shows as changed.
  final redacting = TomAuditPolicy.from(const TomAudited(redact: ['secret']));
  final masked = redacting.applyRedaction({
    'label': 'api key',
    'secret': 'hunter2',
  });
  print('5. redacted                  : $masked');
  check(
    masked['secret'] == tomAuditRedactedPlaceholder,
    'a redacted field still shows as changed, without naming what it became',
  );
  check(
    !masked.values.contains('hunter2'),
    'the secret does not come to exist in a second place at all',
  );

  // 6. Each entry hashes the previous one, so editing, removing or reordering a
  //    single entry invalidates every hash after it. On its own that is
  //    evidence, not proof — an attacker who can rewrite the whole file
  //    recomputes it — but it defeats the realistic attack of doctoring one
  //    record. Step 10 closes the remaining gap.
  sink.clear();
  for (final target in ['Order', 'Invoice', 'Shipment']) {
    await TomAuditTrail.recordAction(
      action: TomAuditAction.create,
      target: target,
      outcome: TomAuditOutcome.succeeded,
    );
  }
  print('6. chain of ${sink.entries.length} entries        : ${sink.verify()}');
  check(sink.verify().isValid, 'an untouched chain verifies end to end');

  // 7. runUnaudited exists so the trail's own machinery can persist without
  //    auditing itself into an infinite regress. It is not a general opt-out —
  //    that is the visible, source-level @TomAudited(enabled: false).
  sink.clear();
  await TomAuditTrail.runUnaudited(
    () => TomAuditTrail.recordAction(
      action: TomAuditAction.create,
      target: 'AuditTrailInternals',
      outcome: TomAuditOutcome.succeeded,
    ),
  );
  print('7. records inside bypass     : ${sink.records.length}');
  check(
    sink.records.isEmpty,
    'the trail can persist itself without auditing its own writes forever',
  );

  // 8. The file sink appends JSON Lines, one file per *UTC* day — the calendar
  //    the records are stamped on, so the day in the file name is the day to
  //    grep — rotating by size and
  //    recovering the head hash on reopen so a restart continues the chain.
  //    Retention deletes whole files, which leaves a valid *suffix*; deleting
  //    individual entries would break the chain and look like tampering.
  final dir = await Directory.systemTemp.createTemp('tom_audit_example');
  try {
    final files = TomFileAuditSink(directory: dir);
    TomAuditTrail.install(files);
    await TomAuditTrail.recordAction(
      action: TomAuditAction.delete,
      target: 'Order',
      targetKey: '7',
      outcome: TomAuditOutcome.succeeded,
    );

    // Shutting down: `close()` waits for records the sink has accepted but not
    // yet written, and refuses any written after it with `audit.sink.closed`.
    // Here the record above was awaited and is already on disk; the shape is
    // what matters.
    await files.close();

    // Reopening picks the chain up where it left off rather than restarting it.
    final reopened = TomFileAuditSink(directory: dir);
    print(
      '8. head hash recovered       : ${reopened.headHash.substring(0, 12)}…',
    );
    print('   entries on disk           : ${reopened.readAll().length}');
    check(
      reopened.readAll().length == 1,
      'a reopened sink finds everything the previous run put on disk',
    );
    check(
      reopened.verify().isValid,
      'and recovers the head hash, so a restart continues the same chain',
    );

    // A record still queued when the close begins is stored; one written after
    // the close began is refused.
    TomAuditRecord orderUpdate(String id) => TomAuditRecord(
      id: id,
      timestamp: DateTime.now().toUtc(),
      actor: TomAuditActor.system,
      action: TomAuditAction.update,
      target: 'Order',
      targetKey: '7',
      outcome: TomAuditOutcome.succeeded,
    );
    Future<String> outcomeOf(Future<TomAuditEntry> write) async {
      try {
        await write;
        return 'stored';
      } on TomAuditException catch (e) {
        return 'refused (${e.key})';
      }
    }

    // Each outcome is listened for as soon as its write is made, so the
    // refusal has a handler waiting when it arrives.
    final queued = outcomeOf(reopened.write(orderUpdate('queued-at-close')));
    final closing = reopened.close();
    final late = outcomeOf(reopened.write(orderUpdate('written-after-close')));
    await closing;

    final queuedOutcome = await queued;
    final lateOutcome = await late;
    print('   a record queued at close  : $queuedOutcome');
    print('   a record after the close  : $lateOutcome');
    check(
      queuedOutcome == 'stored',
      'the close drains the queue, so a record queued before it is stored',
    );
    check(
      lateOutcome == 'refused (audit.sink.closed)',
      'a record written after the close began is refused, not dropped',
    );
    check(
      reopened.readAll().length == 2,
      'the drained record is on disk, and the refused one is not',
    );
  } finally {
    await dir.delete(recursive: true);
    TomAuditTrail.uninstall();
  }

  // 9. The relational sink stores one row per entry instead of one line per
  //    entry. Installing it needs a database, so what runs here is the part
  //    that does not: the schema it ships, and the reasoning about whether the
  //    table it finds can be trusted.
  //
  //    A file is append-only by construction; a table is not. UPDATE and DELETE
  //    are ordinary statements, so the guarantee has to come from outside the
  //    code — and the grant is not a thing a library can hold. See
  //    `doc/audit.md` § "The Write-Once Story"; the migrations that go with it
  //    are in `example/audit/migrations/main/tomcore/`.
  final ddl = auditTrailTableDdl(defaultAuditTrailTable);
  print('9. chain linearity as a constraint:');
  print('   ${ddl.split('\n').firstWhere((l) => l.contains('uq_')).trim()}');
  // Two entries claiming the same predecessor is a fork. As a convention it
  // holds until two writers share a name; as a unique index it holds always.
  check(
    ddl.contains('UNIQUE KEY uq_tom_audit_trail_link'),
    'the shipped schema makes chain linearity a constraint, not a convention',
  );

  // The posture a deployment should aim for: a serving credential holding
  // INSERT and SELECT and nothing else.
  const granted = TomAuditWriteOnceCheck(
    table: defaultAuditTrailTable,
    grantsUpdate: false,
    grantsDelete: false,
  );
  print('   restricted credential     : ${granted.summary}');
  check(
    granted.isAppendOnly,
    'a credential granted neither UPDATE nor DELETE can only append',
  );

  // The fallback for a deployment that cannot separate credentials: the guard
  // triggers. Defence in depth, not the mechanism — a connection holding SUPER
  // can drop them — and the DELETE guard blocks retention outright.
  const guarded = TomAuditWriteOnceCheck(
    table: defaultAuditTrailTable,
    grantsUpdate: true,
    grantsDelete: true,
    updateGuardTrigger: 'trg_tom_audit_trail_no_update',
  );
  // The case a privilege probe alone cannot see: a zero-row UPDATE fires no
  // FOR EACH ROW trigger, so a protected table looks perfectly mutable.
  print('   trigger-guarded           : ${guarded.summary}');
  check(
    guarded.updatesBlocked && !guarded.isAppendOnly,
    'a trigger guard is defence in depth, not a substitute for the grant',
  );

  // And the posture to recognise rather than assume: nothing stops a rewrite.
  const open = TomAuditWriteOnceCheck(
    table: defaultAuditTrailTable,
    grantsUpdate: true,
    grantsDelete: true,
  );
  print('   unprotected               : ${open.summary}');
  check(
    !open.isAppendOnly,
    'an unguarded table with both grants is reported as rewritable',
  );

  // 10. The chain says nobody edited *an* entry. An anchor says nobody rewrote
  //     *all* of them: it publishes the head hash and the entry count somewhere
  //     the audited server cannot reach back into, so a forged trail that
  //     verifies perfectly still fails to match what was published.
  sink.clear();
  TomAuditTrail.install(sink);
  for (final target in ['Grant', 'Revoke', 'Grant']) {
    await TomAuditTrail.recordAction(
      action: TomAuditAction.update,
      target: target,
      outcome: TomAuditOutcome.succeeded,
    );
  }

  // A memory store keeps the example connection-free, and is explicitly not an
  // anchor: it dies with the process it is anchoring. A deployment points
  // `store` at something outside the server's reach — a WORM mount, a versioned
  // object store, another organisation's inbox — and passes a
  // `signer: TomRsaAuditAnchorSigner(...)` so the store cannot forge one
  // either. See `doc/audit.md` § "Anchoring the Chain Head".
  final anchors = TomMemoryAuditAnchorStore();
  final publisher = TomAuditAnchorPublisher(
    sink: sink,
    store: anchors,
    writer: 'node-a',
  );
  final anchor = await publisher.publishNow();
  print(
    '10. anchored                 : ${anchor.entryCount} entries @ '
    '${anchor.headHash.substring(0, 12)}…',
  );

  // The wholesale rewrite: one record swapped, then every hash from there on
  // recomputed. This is the attack the chain alone cannot see.
  final forged = <TomAuditEntry>[];
  var previousHash = tomAuditGenesisHash;
  for (final entry in sink.entries) {
    final record = entry.index != 1
        ? entry.record
        : TomAuditRecord(
            id: entry.record.id,
            timestamp: entry.record.timestamp,
            actor: entry.record.actor,
            action: entry.record.action,
            target: 'Revoke (never happened)',
            outcome: entry.record.outcome,
          );
    final replacement = TomAuditEntry.chain(
      record,
      previousHash,
      index: entry.index,
    );
    forged.add(replacement);
    previousHash = replacement.hash;
  }
  print('    forged chain verifies    : ${verifyAuditChain(forged).isValid}');
  check(
    verifyAuditChain(forged).isValid,
    'a wholesale rewrite verifies perfectly, which the chain alone misses',
  );

  final checked = verifyAgainstAnchor(forged, anchor, writer: 'node-a');
  print('    against the anchor       : ${checked.status.name}');
  check(
    checked.status == TomAuditAnchorStatus.diverged,
    'the published head the server cannot reach back into exposes the forgery',
  );
  check(
    checked.indicatesTampering,
    'and a divergence from an anchor is reported as tampering, not as drift',
  );

  // Retention is the case that must *not* raise the alarm. An entry keeps the
  // index it was written with, so what survives a sweep reads as a suffix of
  // the anchored chain rather than as a break in it.
  final suffix = sink.entries.skip(2).toList();
  final retained = verifyAgainstAnchor(suffix, anchor, writer: 'node-a');
  print('    retained suffix          : ${retained.status.name}');
  check(
    retained.isMatch && !retained.indicatesTampering,
    'what a retention sweep leaves behind is a suffix, not an alarm',
  );

  // 11. Asking the trail a question. The chain and the anchor establish that
  //     what is stored is what was written; a query is what an auditor
  //     actually does with it afterwards. `TomAuditQuery` is the question as a
  //     value, so the same one can be put to a trail in memory, in a file or
  //     in a table — here, to the memory sink through `filterAuditEntries`.
  final grants = filterAuditEntries(
    sink.entries,
    const TomAuditQuery(target: 'Grant'),
  );
  print(
    '11. grants in the trail      : ${grants.entries.length} of '
    '${grants.examined} entries examined',
  );
  check(
    grants.entries.length == 2 && grants.examined == 3,
    'a query narrows to the entries it asked for and says what it looked at',
  );
  // Newest first by default, which is the order an auditor reads in. Over a
  // relational trail the same query is `await sqlSink.query(...)`, which pushes
  // the filter into the table's indexes rather than reading every row back —
  // and re-judges each row against the record, because the indexed columns are
  // truncated and may narrow a search but never decide it.
  check(
    grants.entries.first.index > grants.entries.last.index,
    'the newest matching entry is the one an auditor is shown first',
  );
  check(
    !grants.hasMore,
    'and the result says plainly that this is the whole answer, not a page',
  );

  // Closing publishes one final anchor: it pins the head the chain ends on,
  // and the close completes only once that anchor is in the store.
  await anchors.close();
  TomAuditTrail.uninstall();
}

Future<void> main() async {
  await run();
}
