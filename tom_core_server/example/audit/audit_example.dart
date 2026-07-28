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
/// Run with `dart run example/audit/audit_example.dart`.
/// The same behaviour is covered by `test/audit_test.dart`.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

// ignore_for_file: avoid_print

Future<void> run() async {
  // 1. Nothing is audited until a sink is installed. That is what makes the
  //    trail switchable at startup rather than compiled into every call site.
  print('1. enabled before install    : ${TomAuditTrail.isEnabled}');
  assert(!TomAuditTrail.isEnabled);

  final sink = TomMemoryAuditSink();
  TomAuditTrail.install(sink);
  print('   enabled after install     : ${TomAuditTrail.isEnabled}');

  // 2. A mutation record carries only the fields that changed. An auditor
  //    reading "email: a -> b" learns more than one handed the whole row.
  final before = {'email': 'ada@old.example', 'name': 'Ada'};
  final after = {'email': 'ada@new.example', 'name': 'Ada'};
  final diff = auditDiff(before, after);
  print('2. changed fields            : ${diff.before} -> ${diff.after}');
  assert(diff.after.keys.single == 'email');

  // 3. Attribution comes from the ambient zone, not from a parameter threaded
  //    through every layer. Outside a request there is still an actor: SYSTEM.
  await TomAuditTrail.recordAction(
    action: TomAuditAction.execute,
    target: 'NightlyRebuild',
    outcome: TomAuditOutcome.succeeded,
  );
  print('3. background actor          : ${sink.records.single.actor.username}');
  assert(sink.records.single.actor.username == TomAuditActor.systemUsername);

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
  print('   in-request actor          : ${attributed.actor.username} '
      '(id ${attributed.actor.userId}, request ${attributed.requestId})');
  assert(attributed.actor.userId == 42);

  // 4. The declared-versus-automatic split. Mutations are audited by default —
  //    forgetting to declare one would be a silent gap — while reads are not,
  //    because auditing every row a list endpoint returns buries the entries
  //    that matter.
  const byDefault = TomAuditPolicy.defaultPolicy;
  print('4. default audits update     : ${byDefault.audits(TomAuditAction.update)}');
  print('   default audits read       : ${byDefault.audits(TomAuditAction.read)}');
  assert(byDefault.audits(TomAuditAction.update));
  assert(!byDefault.audits(TomAuditAction.read));

  // The declarations that change it, as they appear on an entity or endpoint —
  // `TomAuditPolicy.from` is exactly what the reflector applies to the
  // annotation it finds on the type:
  //   @TomAudited(enabled: false)          -> opt the type out entirely
  //   @TomAudited(includeReads: true)      -> audit reads too
  //   @TomAudited(redact: ['secret'])      -> keep a value out of the trail
  //   @TomAudited()  on an endpoint method -> audit that invocation
  final optedOut = TomAuditPolicy.from(const TomAudited(enabled: false));
  final withReads = TomAuditPolicy.from(const TomAudited(includeReads: true));
  print('   opted-out audits update   : ${optedOut.audits(TomAuditAction.update)}');
  print('   includeReads audits read  : ${withReads.audits(TomAuditAction.read)}');
  assert(!optedOut.audits(TomAuditAction.update));
  assert(withReads.audits(TomAuditAction.read));

  // 5. Redaction is not a column grade: it keeps the value from existing in a
  //    *second* place at all. The field still shows as changed.
  final redacting = TomAuditPolicy.from(const TomAudited(redact: ['secret']));
  final masked = redacting.applyRedaction({'label': 'api key', 'secret': 'hunter2'});
  print('5. redacted                  : $masked');
  assert(masked['secret'] == tomAuditRedactedPlaceholder);
  assert(!masked.values.contains('hunter2'));

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
  assert(sink.verify().isValid);

  // 7. runUnaudited exists so the trail's own machinery can persist without
  //    auditing itself into an infinite regress. It is not a general opt-out —
  //    that is the visible, source-level @TomAudited(enabled: false).
  sink.clear();
  await TomAuditTrail.runUnaudited(() => TomAuditTrail.recordAction(
        action: TomAuditAction.create,
        target: 'AuditTrailInternals',
        outcome: TomAuditOutcome.succeeded,
      ));
  print('7. records inside bypass     : ${sink.records.length}');
  assert(sink.records.isEmpty);

  // 8. The file sink appends JSON Lines, one file per day, rotating by size and
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
    files.close();

    // Reopening picks the chain up where it left off rather than restarting it.
    final reopened = TomFileAuditSink(directory: dir);
    print('8. head hash recovered       : ${reopened.headHash.substring(0, 12)}…');
    print('   entries on disk           : ${reopened.readAll().length}');
    assert(reopened.readAll().length == 1);
    assert(reopened.verify().isValid);
    reopened.close();
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
  assert(ddl.contains('UNIQUE KEY uq_tom_audit_trail_link'));

  // The posture a deployment should aim for: a serving credential holding
  // INSERT and SELECT and nothing else.
  const granted = TomAuditWriteOnceCheck(
    table: defaultAuditTrailTable,
    grantsUpdate: false,
    grantsDelete: false,
  );
  print('   restricted credential     : ${granted.summary}');
  assert(granted.isAppendOnly);

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
  assert(guarded.updatesBlocked && !guarded.isAppendOnly);

  // And the posture to recognise rather than assume: nothing stops a rewrite.
  const open = TomAuditWriteOnceCheck(
    table: defaultAuditTrailTable,
    grantsUpdate: true,
    grantsDelete: true,
  );
  print('   unprotected               : ${open.summary}');
  assert(!open.isAppendOnly);

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
  print('10. anchored                 : ${anchor.entryCount} entries @ '
      '${anchor.headHash.substring(0, 12)}…');

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
  assert(verifyAuditChain(forged).isValid);

  final checked = verifyAgainstAnchor(forged, anchor, writer: 'node-a');
  print('    against the anchor       : ${checked.status.name}');
  assert(checked.status == TomAuditAnchorStatus.diverged);
  assert(checked.indicatesTampering);

  // Retention is the case that must *not* raise the alarm. An entry keeps the
  // index it was written with, so what survives a sweep reads as a suffix of
  // the anchored chain rather than as a break in it.
  final suffix = sink.entries.skip(2).toList();
  final retained = verifyAgainstAnchor(suffix, anchor, writer: 'node-a');
  print('    retained suffix          : ${retained.status.name}');
  assert(retained.isMatch && !retained.indicatesTampering);

  publisher.close();
  anchors.close();
  TomAuditTrail.uninstall();
}

Future<void> main() async {
  await run();
}
