/// Executable example for the audit module of `tom_core_server` (CE-LG).
///
/// Demonstrates the audit trail without a database or a server: installing a
/// sink, the shape of a [TomAuditRecord], attribution from the ambient zone,
/// the declared-versus-automatic split expressed by [TomAudited], redaction,
/// the tamper-evident hash chain, and the append-only file sink with its
/// whole-file retention.
///
/// The two *chokepoints* — the endpoint pipeline and the repository write path
/// — are what make this automatic in a running server; they are exercised by
/// `test/endpoints_pipeline_test.dart` and `test/audit_db_test.dart` (the
/// latter against a live MariaDB). Here the records are produced by hand so the
/// example stays connection-free.
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
  //    single entry invalidates every hash after it. This is evidence, not
  //    proof — an attacker who can rewrite the whole file can recompute it —
  //    but it defeats the realistic attack of doctoring one record.
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
}

Future<void> main() async {
  await run();
}
