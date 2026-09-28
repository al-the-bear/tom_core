// CE-JB — the deployment/ownership envelope around a scheduled job.
//
// The declaration says WHETHER and WHERE a job is deployed and WHAT it
// touches; the `TomJobDefinition` beside it in `tom_core_kernel` says how it
// runs. The split is the point: a definition's body is an opaque closure, so
// nothing can ask it which entities the job writes. The declaration can be
// asked, which is what makes an impact query possible at all.
//
// Run with:
//   dart run --enable-asserts example/job_declaration_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

/// Stand-ins for the CE-DB entities a real declaration would name.
class Invoice {}

class Payment {}

class AuditEntry {}

void main() {
  requireAsserts();
  print('== CE-JB: job declarations ==');

  final settlement = TomJobDeclaration(
    jobId: 'nightly_settlement',
    displayName: 'Nightly settlement',
    serviceUnitId: 'billing',
    environments: ['staging', 'prod'],
    readEntities: [Invoice],
    writtenEntities: [Payment],
  );

  print(
    '  ${settlement.jobId}: prod=${settlement.runsIn("prod")} '
    'dev=${settlement.runsIn("dev")}',
  );
  assert(settlement.runsIn('prod'));
  assert(!settlement.runsIn('dev'), 'dev is not in the list');
  assert(settlement.targetEntities.length == 2);

  // Two defaults that read as opposites and are both deliberate: an empty
  // environment list deploys EVERYWHERE (nothing was restricted), while
  // `enabled: false` deploys nowhere whatever the list says.
  final housekeeping = TomJobDeclaration(jobId: 'housekeeping');
  final parked = TomJobDeclaration(
    jobId: 'housekeeping',
    enabled: false,
    environments: ['prod'],
  );

  print('  housekeeping (no environments) prod=${housekeeping.runsIn("prod")}');
  print('  parked (enabled: false)        prod=${parked.runsIn("prod")}');
  assert(housekeeping.runsIn('prod'), 'no list means no restriction');
  assert(!parked.runsIn('prod'), 'disabled beats an explicit environment');

  // The impact query the runtime cannot answer.
  final jobs = [
    settlement,
    housekeeping,
    TomJobDeclaration(
      jobId: 'invoice_reminder',
      serviceUnitId: 'billing',
      readEntities: [Invoice],
      writtenEntities: [AuditEntry],
    ),
  ];

  final touching = jobs
      .where((job) => job.targetEntities.contains(Invoice))
      .map((job) => job.jobId)
      .toList();
  final writing = jobs
      .where((job) => job.writtenEntities.contains(Invoice))
      .map((job) => job.jobId)
      .toList();

  print('  touch Invoice: ${touching.join(", ")}');
  print('  write Invoice: ${writing.isEmpty ? "(none)" : writing.join(", ")}');
  assert(touching.length == 2);
  assert(writing.isEmpty, 'both jobs only read Invoice');

  // `targetEntities` unions the two lists, so "touches" and "writes" are
  // different questions with different answers — which is the distinction a
  // change-impact review needs and a closure cannot give.
  assert(settlement.targetEntities.contains(Invoice));
  assert(!settlement.writtenEntities.contains(Invoice));
  print('  reads and writes stay distinguishable');
}
