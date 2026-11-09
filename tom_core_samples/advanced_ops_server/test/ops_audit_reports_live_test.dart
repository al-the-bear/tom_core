/// The audit-report delivery against the sample's own trail: records in
/// `app_db`'s `tom_audit_trail`, a question saved in its `tom_audit_question`
/// ([101]), and the delivery pass the ops runtime registers — the export
/// stored in the blob store and the mail queued on the outbox.
///
/// The framework's suites prove the module over memory stores and a test
/// database; what only this deployment can show is the module over the tables
/// its migration chain built, beside the trail its other jobs write.
///
/// **Skips rather than fails when `app_db` is unreachable**;
/// `tool/run_ops_integration.sh` boots the database, applies `[100]` and
/// `[101]`, and treats a skip as a failure.
library;

import 'dart:convert';

import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'support/live_database.dart';

void main() {
  setUpAll(bootstrapLiveDatabase);

  test('a saved question is delivered as a CSV of the trail, and the delivery '
      'is in the trail too', () async {
    if (liveDatabaseUnavailable()) return;
    final datasource = TomDataSourceInfo.getDataSourceInfo(
      'app_db',
    )!.datasource;
    // A target no other suite writes, so the question's answer is exactly the
    // records this test put there however often it runs.
    final target = 'AuditReportsLive${DateTime.now().microsecondsSinceEpoch}';
    final sink = TomSqlAuditSink(
      datasource,
      writer: 'ops-audit-reports-live',
      createSchema: false,
    );
    for (final (key, outcome) in [
      ('r1', TomAuditOutcome.denied),
      ('r2', TomAuditOutcome.succeeded),
      ('r3', TomAuditOutcome.denied),
    ]) {
      await sink.write(
        TomAuditRecord(
          id: TomAuditTrail.newAuditRecordId(),
          timestamp: DateTime.now().toUtc(),
          actor: const TomAuditActor(username: 'mallory', userId: '99'),
          action: TomAuditAction.delete,
          target: target,
          targetKey: key,
          outcome: outcome,
        ),
      );
    }
    TomAuditTrail.install(sink);
    addTearDown(() async {
      TomAuditTrail.uninstall();
      await sink.close();
    });

    final transport = TomMemoryMessageTransport();
    final outbox = TomMessageOutbox(
      router: TomMessageRouter([transport]),
      store: TomMemoryJobStore(),
    );
    addTearDown(outbox.close);
    final exports = TomBlobExportStore.named(
      null,
      keyPrefix: opsAuditReportKeyPrefix,
    );
    final questions = TomSqlAuditQuestionStore(datasource, createSchema: false);
    final reports = TomAuditReports(
      view: TomAuditView(TomSqlAuditTrailSource(datasource)),
      questions: questions,
      exports: TomExportService(store: exports),
      email: TomExportEmailDelivery(store: exports, outbox: outbox),
      texts: OpsTexts.resources(),
    );

    expect(await reports.writers(), contains('ops-audit-reports-live'));

    final saved = await reports.save(
      'audrey',
      TomAuditQuestion(
        id: '',
        name: 'Denied deletes',
        owner: '',
        filter: TomAuditQuestionFilter.fromJson({
          'target': target,
          'outcome': 'denied',
        }),
        recipients: const ['audrey@example.com'],
      ),
    );
    addTearDown(() => questions.remove(saved.id));
    await reports.deliverSoon('audrey', saved.id);

    final done = await reports.deliverDue();
    final mine = done.singleWhere((d) => d.question.id == saved.id);
    expect(mine.succeeded, isTrue, reason: '${mine.error}');
    expect(mine.recordCount, 2);

    await outbox.tick();
    final mail = transport.sent.single;
    expect(mail.subject, 'Audit report: Denied deletes');
    final csv = utf8.decode(mail.attachments.single.bytes);
    expect(csv, contains('r1'));
    expect(csv, contains('r3'));
    expect(csv, isNot(contains(',r2,')));

    final after = (await questions.find(saved.id))!;
    expect(after.lastDeliveredAt, isNotNull);
    expect(after.nextDeliveryAt, isNull, reason: 'no schedule: delivered once');

    final delivery = await TomAuditView(
      TomSqlAuditTrailSource(datasource),
    ).query(TomAuditQuery(target: 'TomAuditQuestion', targetKey: saved.id));
    expect(
      delivery.entries.single.entry.record.outcome,
      TomAuditOutcome.succeeded,
    );
  });
}
