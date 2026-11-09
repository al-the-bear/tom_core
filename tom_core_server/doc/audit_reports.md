# Audit Reports Module

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The reporting surface above the [audit](audit.md) module. An auditor asks a
question of the audit trail across every process that writes to it, saves the
question under a name, and has it delivered on a schedule as a CSV, XLSX or
PDF export by email. The `audit` module answers one question of one writer's
chain (`TomAuditQuery` → `TomAuditQueryResult`); this module asks every writer,
keeps the questions, and delivers them through the [export](export.md) and
[messaging](messaging.md) modules. It serves the kernel's `tomAuditReportsApi`
to a caller holding the `auditor` role.

**Source:** `tom_core_server/lib/src/tomserver/audit_reports/`

## Table of Contents

- [Overview](#overview)
  - [The contract half](#the-contract-half)
- [Asking Across Writers](#asking-across-writers)
- [Questions and Their Filters](#questions-and-their-filters)
  - [The filter](#the-filter)
  - [A saved question](#a-saved-question)
- [Deliveries](#deliveries)
  - [Which process delivers](#which-process-delivers)
  - [What a delivery does](#what-a-delivery-does)
  - [A delivery that fails](#a-delivery-that-fails)
- [The Endpoints](#the-endpoints)
- [Tables and the Reference Migration](#tables-and-the-reference-migration)
- [Wiring a Server](#wiring-a-server)
- [Error Keys](#error-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Dependencies](#dependencies)

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuditView` | class | Answers a `TomAuditQuery` across the writers of a trail, merged by record time |
| `TomAuditTrailSource` | abstract class | Where a view reads: the writers a trail holds, and one writer's answer |
| `TomSqlAuditTrailSource` | class | The relational trail: one table, every writer's rows, read through one read-side `TomSqlAuditSink` per writer |
| `TomMemoryAuditTrailSource` | class | In-memory sinks, one per writer — for tests and a single process |
| `TomAuditViewResult` / `TomAuditViewEntry` | class | A view's answer, and one record of it with the writer whose chain holds it |
| `TomAuditWriterRow` | class | The row `SELECT DISTINCT writer` answers |
| `TomAuditQuestionFilter` | class | What a question asks — record fields and a window — with its JSON form |
| `TomAuditQuestion` | class | A saved question: name, owner, filter, schedule, recipients, format, delivery times |
| `tomAuditReportFormats` | `const List<String>` | `csv`, `xlsx`, `pdf` — the formats a delivery can take |
| `TomAuditQuestionStore` | abstract class | Where questions are kept: `save`, `find`, `ownedBy`, `due`, `remove` |
| `TomMemoryAuditQuestionStore` / `TomSqlAuditQuestionStore` | class | That store in memory and over `tom_audit_question` |
| `TomAuditQuestionRow` | class | One row of the question table, as the driver hands it back |
| `auditQuestionTable` / `auditQuestionTableDdl` | function | The question table, declared once, and its `CREATE TABLE` |
| `defaultAuditQuestionTable` | const String | `tom_audit_question`, the table's default name |
| `TomAuditReports` | class | The service: `ask`, `questionsOf`, `questionOf`, `save`, `remove`, `deliverSoon`, `deliverDue`, `registerOn`, `install`, `resolve` |
| `TomAuditReportDelivery` | class | What one delivery did: the question, the records, the export or the error |
| `TomAuditReportsServer` | class | The kernel's `TomAuditReportsApiService` over the installed `TomAuditReports` |
| `TomAuditReportsErrorHandler` | class | The statuses the API's refusals answer with |
| `TomAuditReportException` | class | The module's failures, keyed `audit_reports.*` |
| `tomAuditReportsDatasource` | function | The registered data source a `.named` constructor resolves, refusing an unknown name |

### The contract half

The API is declared in `tom_core_kernel`, so a client and a server share it:
`tomAuditReportsApi` with its seven endpoints, the role `tomAuditorRole`
(`auditor`) and the access `tomAuditorAccess` every endpoint requires, the
bodies `TomAuditReportQueryRequest`, `TomAuditReportResultDto` and
`TomAuditReportEntryDto`, `TomAuditQuestionDto` and `TomAuditQuestionsDto`,
`TomAuditReportWritersDto` and `TomAuditQuestionIdRequest`, and the service
interface `TomAuditReportsApiService`. See the kernel's
[security guide](../../tom_core_kernel/doc/security/security.md#audit-reports).

## Asking Across Writers

Every process that records keeps a hash chain of its own — a *writer* — and a
query of one sink reads one chain. An auditor's question is about the system,
not about one node. `TomAuditView.query` asks each writer the trail holds (or
the ones a question names), each with the query's limit; merges the answers by
record time, newest first unless the query asks otherwise — ties by writer,
then by position in the chain, so the order is the same on every run; and cuts
the merged list to the limit. `hasMore` is set when a writer had more matches
or the cut dropped records.

`TomSqlAuditTrailSource` reads the relational trail: `writers()` is
`SELECT DISTINCT writer`, and each writer is read through a `TomSqlAuditSink`
opened read-side (`createSchema: false`), which never writes.
`TomMemoryAuditTrailSource` maps writer names to `TomMemoryAuditSink`s.

## Questions and Their Filters

### The filter

`TomAuditQuestionFilter` is what a question asks, and its JSON form is what the
API carries and the store keeps:

| Key | Meaning |
| --- | ------- |
| `actor` | the acting user's name |
| `action` | `create`, `update`, `delete`, `read` or `execute` |
| `target` / `targetKey` | what was acted on |
| `outcome` | `succeeded`, `failed` or `denied` |
| `requestId` | one request's records |
| `from` / `to` | an absolute window, ISO-8601 instants |
| `lastHours` | a window of that many hours, ending when the question is asked |
| `writers` | the chains to read; every writer when absent |
| `limit` | at most this many records (500 by default, 5000 at most) |

The window is absolute or relative, never both: a question delivered every
Monday with `lastHours: 168` reports on the week before *that* Monday.
`fromJson` refuses an unknown key, a value of the wrong kind, an action or
outcome it does not know, both windows together, a non-positive `lastHours`, a
window that ends before it starts and a limit outside 1 to 5000, all as
`audit_reports.question.invalid` with the reason in `parameters`. `toQuery(now)`
is the `TomAuditQuery` the filter asks at `now`.

### A saved question

`TomAuditQuestion` adds a name, the owner (the saving principal's
`qualifiedId`), a schedule — a five-field cron expression in UTC, such as
`0 6 * * 1` for Mondays at 06:00 — the recipients' email addresses and the
format. It refuses an empty name, an unknown format, a schedule that is not a
cron expression, a recipient that is not an email address and a schedule with
no recipients. `nextAfter(instant)` is the schedule's next time.

`TomAuditReports.save(owner, question)` stores a question with an empty id as a
new one under a new UUID, and one with an id as the replacement of the owner's
question with that id. It sets the owner and computes the next delivery from the
schedule; a question already marked for an earlier delivery keeps that mark.

**A question is its owner's alone.** `questionOf`, `save` of an existing id,
`remove` and `deliverSoon` refuse another owner's question with
`audit_reports.question.not_found`, exactly as for a question that does not
exist — the two are not told apart, so an auditor cannot learn which ids
another auditor holds.

## Deliveries

### Which process delivers

A delivery needs `exports` (a `TomExportService`, where the CSV, XLSX or PDF is
stored) and `email` (a `TomExportEmailDelivery`, which sends it through the
messaging outbox, attached or linked). A process that only answers questions —
a server behind the API — leaves both out: `deliverSoon` marks the question for
the next delivery pass, and the process that has them delivers it.
`registerOn(scheduler)` registers that pass, `audit_reports.deliver`, every
minute by default; in a cluster the scheduler's lease runs each pass on one
node.

### What a delivery does

`deliverDue` reads the questions due now (`TomAuditQuestionStore.due`) and, for
each:

1. asks the question at that moment, across its writers;
2. stores the answer as an export of one section — time, writer, actor, action,
   target, key, outcome, request, detail — under
   `audit-<name>.<format>` partitioned by the delivery's date, owned by the
   question's owner;
3. sends it to the recipients, with the subject and text of the resource keys
   `audit_reports.delivery.subject` and `audit_reports.delivery.text` in the
   deployment's default language, each given `{name}`, `{count}` and, when the
   question has a window, `{from}` and `{to}`;
4. records the delivery in the audit trail — `execute` on `TomAuditQuestion`
   with the question's id, `succeeded` or `failed`;
5. moves the question to its next scheduled time; a question marked for one
   delivery and without a schedule is due no more.

### A delivery that fails

A failure does not stop the other deliveries. It is recorded in the trail as
`failed` with its reason, answered as a `TomAuditReportDelivery` whose `error`
is set, and the question moves on to its next scheduled time like a delivered
one: a broken question must not be retried every pass for ever. A process
without `exports` and `email` fails each due delivery with
`audit_reports.delivery.not_configured`; missing text resources fail it with
`audit_reports.delivery.text_missing`.

## The Endpoints

`TomAuditReportsServer` implements the kernel's `tomAuditReportsApi` over the
installed `TomAuditReports`; the pipeline registers the contract
(`TomEndpointRouting.registerFrameworkApis`) and constructs the server, so
every server mounts the routes. Every route requires the `auditor` role, which
the pipeline checks, and a caller without it is answered as for a route that
does not exist.

| Route | Answers |
| ----- | ------- |
| `GET /audit-reports/writers` | The writers of the trail |
| `POST /audit-reports/query` | A filter answered once, across the writers it names |
| `GET /audit-reports/questions` | The caller's questions, by name |
| `PUT /audit-reports/questions` | A question saved as the caller's, with its next delivery |
| `DELETE /audit-reports/questions/{id}` | The caller's question removed |
| `GET /audit-reports/questions/{id}/answer` | The caller's question answered now |
| `POST /audit-reports/questions/{id}/deliver` | The caller's question marked for the next delivery pass |

`TomAuditReportsErrorHandler` maps the refusals:

| Key | Status |
| --- | ------ |
| `audit_reports.question.not_found` | `404` |
| `audit_reports.question.invalid` | `400` |
| `audit_reports.question.no_recipients` | `409` |
| `audit_reports.no_principal` | `401` |
| `audit_reports.not_configured` | `503` — no `TomAuditReports` is installed |

## Tables and the Reference Migration

`TomSqlAuditQuestionStore` keeps questions in `tom_audit_question`, declared
once as `auditQuestionTable()` and created on first use unless `createSchema`
is off. The reference migration ships under
`example/audit_reports/migrations/` (and its PostgreSQL form under
`migrations_postgresql/`); `test/framework_schema_test.dart` replays it against
the declaration.

| Column | Type | Holds |
| ------ | ---- | ----- |
| `id` | `VARCHAR(64)` | The question's id, the primary key |
| `owner` | `VARCHAR(191)` | The owner's `qualifiedId`; indexed with `name` |
| `name` | `VARCHAR(255)` | What the auditor calls it |
| `definition` | `TEXT` | The filter, recipients and format as JSON |
| `schedule` | `VARCHAR(255) NULL` | The cron expression, or `NULL` |
| `next_delivery_at` | `DATETIME(6) NULL` | The next delivery; indexed for the delivery pass |
| `last_delivered_at` | `DATETIME(6) NULL` | The last delivery |
| `updated_at` | `DATETIME(6)` | When the question was last saved |

The question table is the deployment's and is not routed per tenant; the trail
it reads is the audit module's, which is deployment-wide too.

## Wiring a Server

```dart
final reports = TomAuditReports(
  view: TomAuditView(TomSqlAuditTrailSource.named('main')),
  questions: TomSqlAuditQuestionStore.named('main'),
)..install();
```

That serves the API: asking, saving, answering and marking for delivery. The
process that delivers — the same one, or a back-office process over the same
database — builds the service with `exports` and `email` and registers the
pass:

```dart
final delivering = TomAuditReports(
  view: TomAuditView(TomSqlAuditTrailSource.named('main')),
  questions: TomSqlAuditQuestionStore.named('main'),
  exports: TomExportService(store: exportStore),
  email: TomExportEmailDelivery(store: exportStore, outbox: outbox),
);
delivering.registerOn(scheduler);
```

The deployment's resource bundle carries `audit_reports.delivery.subject` and
`audit_reports.delivery.text`, and its principals the `auditor` role.

## Error Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `audit_reports.question.invalid` | `TomAuditQuestionFilter`, `TomAuditQuestion` | A filter or question that cannot be used; the reason is in `parameters` |
| `audit_reports.question.not_found` | `TomAuditReports` | No such question of the caller's |
| `audit_reports.question.no_recipients` | `TomAuditReports.deliverSoon` | A question with nowhere to deliver to |
| `audit_reports.delivery.not_configured` | `TomAuditReports.deliverDue` | This process has no export service or email delivery |
| `audit_reports.delivery.text_missing` | `TomAuditReports.deliverDue` | The delivery's subject or text resource is missing |
| `audit_reports.not_configured` | `TomAuditReportsServer` | No `TomAuditReports` is installed |
| `audit_reports.no_principal` | `TomAuditReportsServer` | A call without an authenticated principal |
| `audit_reports.view.unknown_datasource` | `TomSqlAuditTrailSource.named` | No data source of that name is registered |
| `audit_reports.store.unknown_datasource` | `TomSqlAuditQuestionStore.named` | No data source of that name is registered |

## Not Yet Implemented

- **Questions are not shared.** A question belongs to the auditor who saved it,
  and another auditor cannot see, run or subscribe to it; a team that wants one
  report saves it once per auditor or names everyone as a recipient.
  <!-- unpinned: decision — saved questions are owned, not shared -->
- **The delivery language is the deployment's default.** A delivery's subject
  and text are rendered in the default language, not each recipient's.
  <!-- unpinned: decision — one language per delivery -->

## Verification

`test/audit_reports_test.dart` (AR-1 to AR-21) covers the module without a
database: the filter's JSON form, its relative window and its refusals; the
question's refusals and its next scheduled time; the view merging two writers,
cutting the merged list to the limit and reading the writers a question names;
saving, ownership and its refusals; a due question delivered as a CSV by email
through the outbox, recorded in the trail and moved to its next time;
delivering now, once; a question without recipients; a process that does not
deliver and missing texts, each failing its delivery once; the pass registered
on a scheduler; every endpoint as the caller, the auditor role, the statuses,
an uninstalled service and the wire forms; and the `.named` refusals.
`test/audit_reports_db_test.dart` (ARD-1, ARD-2, `@Tags(['db'])`) reads the
relational trail across two writers and keeps questions in their table, on
MariaDB and PostgreSQL. `example/audit_reports/audit_reports_example.dart`
runs a question across two writers, saves it weekly and delivers it.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `audit_reports_service.dart`, `audit_view.dart` | `Future`, `Stream` |
| `dart:convert` | dart | `audit_question_store.dart` | `jsonEncode` / `jsonDecode` of a question's definition |
| `tom_core_kernel` | package | `audit_question.dart`, `audit_question_store.dart`, `audit_reports_endpoint.dart`, `audit_reports_service.dart`, `audit_view.dart` | `tomAuditReportsApi`, its ids and bodies, `TomAuditReportsApiService`; `TomCronSchedule`, `TomScheduler`, `TomJobDefinition`, `TomIntervalSchedule`, `TomCommand`; `TomBean`; `TomPrincipal`; `TomDataSource`; `tomReflector` |
| `uuid` | package | `audit_reports_service.dart` | `UuidV4`, a new question's id |
| [audit](audit.md) | module | `audit_question.dart`, `audit_reports_service.dart`, `audit_view.dart` | `TomAuditQuery` and `TomAuditQueryResult`, `filterAuditEntries`, `TomAuditAction` / `TomAuditOutcome`, the sinks a view reads, `TomAuditTrail.recordAction` for each delivery, `defaultAuditTrailTable` |
| [datasources](datasources.md) | module | `audit_question.dart`, `audit_question_sql.dart`, `audit_question_store.dart`, `audit_view.dart` | `TomDataSourceInfo` for the `.named` constructors, `TomFrameworkTable`, `TomSchemaProvisioning`, `sqlInstant` / `parseSqlInstant` |
| [endpoints](endpoints.md) | module | `audit_reports_endpoint.dart` | `@TomApiEndpointImplementation` and `TomStatusMappingErrorHandler` |
| [export](export.md) | module | `audit_reports_service.dart` | `TomExportService`, `TomExportEmailDelivery`, `TomTabularResult`, the shape a delivery is rendered from |
| [little_things](little_things.md) | module | `audit_question.dart` | `TomServerException`, the base of `TomAuditReportException` |
| [messaging](messaging.md) | module | `audit_reports_service.dart` | `TomRecipient` for the delivery's recipients |
| [object_persistence](object_persistence.md) | module | `audit_question_store.dart`, `audit_view.dart` | `TomDbTable` / `TomDbColumn` on the row classes |
| [resources](resources.md) | module | `audit_reports_service.dart` | `TomLocalizedTextResources`, the delivery's subject and text |

- The endpoints module — `TomEndpointRouting.registerFrameworkApis` registers
  `tomAuditReportsApi`, so every server mounts the routes.
- The db_migration module — `frameworkOwnedTables` lists `tom_audit_question`.
