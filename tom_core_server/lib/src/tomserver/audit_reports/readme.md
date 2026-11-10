# audit_reports

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The reporting surface above the `audit` module: an auditor asks a question of
the audit trail, saves it under a name, and has it delivered on a schedule as
a CSV, XLSX or PDF export by email. The `audit` module answers one question of
one writer's chain (`TomAuditQuery` → `TomAuditQueryResult`); this module asks
every writer, keeps the questions, and delivers them through the `export` and
`messaging` modules.

**A question is asked of every writer.** Each process that records keeps a hash
chain of its own, and an auditor's question is about the system, not about one
node. `TomAuditView` asks each writer the trail holds (or the ones a question
names), merges the answers by record time and keeps the limit over the merged
list.

**A question is saved as its filter.** `TomAuditQuestionFilter` is the record
fields a question narrows to and its window — absolute (`from`, `to`) or
relative (`lastHours`, ending when the question is asked, so a question
delivered every Monday reports on the week before that Monday). A saved
`TomAuditQuestion` adds a name, its owner, a five-field cron schedule in UTC,
the recipients and the format.

**Deliveries run in the process that has the export service and the email
delivery.** A server answering the API only marks a question for delivery;
`TomAuditReports.deliverDue`, registered on a scheduler with `registerOn`,
delivers every question due, stores the export, sends it, records the delivery
in the audit trail and moves the question to its next scheduled time. A
failed delivery is recorded as failed and not retried before that time.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuditView` | Answers a `TomAuditQuery` across the writers of a trail, merged by record time. |
| `TomAuditTrailSource` / `TomSqlAuditTrailSource` / `TomMemoryAuditTrailSource` | Where a view reads: the writers a trail holds and one writer's answer — the relational trail, or in-memory sinks. |
| `TomAuditViewResult` / `TomAuditViewEntry` | A view's answer: the records with the writer whose chain holds each. |
| `TomAuditQuestionFilter` | What a question asks, read from and written to its JSON form; refuses a filter it cannot use. |
| `TomAuditQuestion` | A saved question: name, owner, filter, schedule, recipients, format, delivery times. |
| `TomAuditQuestionStore` / `TomMemoryAuditQuestionStore` / `TomSqlAuditQuestionStore` | Where questions are kept; the SQL store over `tom_audit_question`. |
| `auditQuestionTable` / `auditQuestionTableDdl` / `defaultAuditQuestionTable` | The saved-question table, declared once. |
| `TomAuditReports` | The service: `ask`, `questionsOf`, `save`, `remove`, `deliverSoon`, `deliverDue`, `registerOn`; `install` / `resolve` as the process-wide bean. |
| `TomAuditReportsServer` / `TomAuditReportsErrorHandler` | The kernel's `tomAuditReportsApi` under `/audit-reports`, for a caller holding the `auditor` role, and the statuses its refusals answer with. |
| `TomAuditReportException` | The module's failures, keyed `audit_reports.*`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final reports = TomAuditReports(
    view: TomAuditView(TomSqlAuditTrailSource.named('main')),
    questions: TomSqlAuditQuestionStore.named('main'),
    exports: exportService,          // where delivered exports are stored
    email: TomExportEmailDelivery(   // how they are sent
      store: exportStore,
      outbox: outbox,
      from: TomRecipient('audit@example.com'),
    ),
  )..install();
  reports.registerOn(scheduler);     // delivers due questions every minute

  final answer = await reports.ask(
    TomAuditQuestionFilter(outcome: TomAuditOutcome.denied, lastHours: 24),
  );
  print('${answer.entries.length} denied actions in the last day');
}
```

> **A fragment, not a program.** `exportService`, `exportStore`, `outbox` and
> `scheduler` are the deployment's; `example/audit_reports/audit_reports_example.dart`
> runs the same steps over in-memory stores.

`TomAuditReportsServer` is mounted by the pipeline and serves the installed
service. The delivery's subject and text are the resource keys
`audit_reports.delivery.subject` and `audit_reports.delivery.text`.

```bash
dart run example/audit_reports/audit_reports_example.dart
```

See [`doc/audit_reports.md`](../../../../doc/audit_reports.md) for the filter's
keys, the API, deliveries and their failures. The connection-free surface runs
in `example/audit_reports/audit_reports_example.dart`;
`test/audit_reports_test.dart` covers it without a server, and
`test/audit_reports_db_test.dart` covers the relational trail and the question
table against a live MariaDB or PostgreSQL.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
