/// The audit_reports module without a database: a question asked across two
/// writers of the audit trail, saved with a weekly schedule, and delivered as
/// a CSV export by email when it falls due.
///
/// Run with `dart run example/audit_reports/audit_reports_example.dart`.
///
/// The relational trail and the saved-question table run in
/// `test/audit_reports_db_test.dart` on MariaDB and PostgreSQL. Every step here
/// checks its own result, and the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

TomAuditRecord _record(String id, int hour, TomAuditOutcome outcome) =>
    TomAuditRecord(
      id: id,
      timestamp: DateTime.utc(2026, 11, 6, hour),
      actor: const TomAuditActor(username: 'ada', userId: '1'),
      action: TomAuditAction.delete,
      target: 'Order',
      targetKey: id,
      outcome: outcome,
    );

Future<void> main() async {
  // 1. Two server processes, two hash chains: an auditor's question is about
  //    both, and the view merges their answers by time.
  final nodeA = TomMemoryAuditSink();
  final nodeB = TomMemoryAuditSink();
  await nodeA.write(_record('o1', 9, TomAuditOutcome.succeeded));
  await nodeB.write(_record('o2', 10, TomAuditOutcome.denied));
  await nodeA.write(_record('o3', 11, TomAuditOutcome.denied));
  final view = TomAuditView(
    TomMemoryAuditTrailSource({'node-a': nodeA, 'node-b': nodeB}),
  );
  final denied = TomAuditQuestionFilter(outcome: TomAuditOutcome.denied);
  final answer = await view.query(denied.toQuery(DateTime.utc(2026, 11, 7)));
  print(
    '1. ${[for (final e in answer.entries) '${e.writer}:${e.entry.record.id}']}',
  );
  check(
    answer.entries.length == 2 && answer.entries.first.writer == 'node-a',
    'the denied records of both writers, newest first',
  );

  // 2. A filter is saved as JSON — the form the API carries — and read back.
  final json = TomAuditQuestionFilter(
    outcome: TomAuditOutcome.denied,
    lastHours: 168,
  ).toJson();
  print('2. filter $json');
  check(
    TomAuditQuestionFilter.fromJson(json).lastHours == 168,
    'a filter reads back from its JSON form',
  );

  // 3. Saving a question with a weekly schedule computes its next delivery.
  var now = DateTime.utc(2026, 11, 7, 12); // a Saturday
  final exports = TomMemoryExportStore();
  final transport = TomMemoryMessageTransport();
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([transport]),
    store: TomMemoryJobStore(),
  );
  final reports = TomAuditReports(
    view: view,
    questions: TomMemoryAuditQuestionStore(),
    exports: TomExportService(store: exports),
    email: TomExportEmailDelivery(store: exports, outbox: outbox),
    texts: TomLocalizedTextResources(
      defaultLocale: TomTextLocale('en'),
      bundles: const {
        'en': {
          'audit_reports': {
            'delivery': {
              'subject': 'Audit report: {name}',
              'text': '{count} record(s).',
            },
          },
        },
      },
    ),
    clock: () => now,
  );
  final saved = await reports.save(
    'audrey',
    TomAuditQuestion(
      id: '',
      name: 'Denied this week',
      owner: '',
      filter: TomAuditQuestionFilter.fromJson({'outcome': 'denied'}),
      schedule: '0 6 * * 1',
      recipients: const ['auditor@example.com'],
    ),
  );
  print('3. next delivery ${saved.nextDeliveryAt}');
  check(
    saved.nextDeliveryAt == DateTime.utc(2026, 11, 9, 6),
    'the next delivery is Monday 06:00 UTC',
  );

  // 4. On Monday the delivery pass stores the CSV and sends it.
  now = DateTime.utc(2026, 11, 9, 6);
  final done = await reports.deliverDue();
  await outbox.tick();
  final mail = transport.sent.single;
  print('4. ${mail.subject} -> ${mail.attachments.single.fileName}');
  check(
    done.single.recordCount == 2 &&
        mail.attachments.single.fileName.endsWith('.csv'),
    'the question is delivered as a CSV attachment',
  );

  // 5. The question moves to the following Monday.
  final after = await reports.questionOf('audrey', saved.id);
  print('5. next delivery ${after.nextDeliveryAt}');
  check(
    after.nextDeliveryAt == DateTime.utc(2026, 11, 16, 6),
    'after a delivery the question is due a week later',
  );
  await outbox.close();
}
