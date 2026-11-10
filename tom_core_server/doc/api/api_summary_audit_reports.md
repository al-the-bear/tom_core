# tom_core_server API Reference: Audit Reports Module

The public surface of `lib/src/tomserver/audit_reports/`, as its barrel exports it: the view across the audit trail's writers, saved questions and their store, the delivery service and the `tomAuditReportsApi` endpoints. See [`audit_reports.md`](../audit_reports.md) for the module guide.

## Overview

Sources: `lib/src/tomserver/audit_reports/audit_question.dart`, `lib/src/tomserver/audit_reports/audit_question_sql.dart`, `lib/src/tomserver/audit_reports/audit_question_store.dart`, `lib/src/tomserver/audit_reports/audit_reports_endpoint.dart`, `lib/src/tomserver/audit_reports/audit_reports_service.dart`, `lib/src/tomserver/audit_reports/audit_view.dart`.

## Classes

### TomAuditQuestion

**Kind:** `class`

A saved question.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `copyWith` | `TomAuditQuestion copyWith({String? id, String? owner, DateTime? lastDeliveredAt, DateTime? nextDeliveryAt, bool clearNextDelivery = false})` | A copy with the fields given replaced. |
| `cron` | `TomCronSchedule? get cron` | The schedule as a cron schedule, or `null`. |
| `definitionJson` | `Map<String, Object?> definitionJson()` | The stored definition: everything but the identity and the delivery times. |
| `filter` | `final TomAuditQuestionFilter filter` | What it asks. |
| `format` | `final String format` | The format of a delivery: one of [tomAuditReportFormats]. |
| `id` | `final String id` | Its id. |
| `lastDeliveredAt` | `final DateTime? lastDeliveredAt` | When it was last delivered. |
| `name` | `final String name` | What the auditor calls it. |
| `nextAfter` | `DateTime? nextAfter(DateTime after)` | The first delivery its schedule makes after [after], or `null`. |
| `nextDeliveryAt` | `final DateTime? nextDeliveryAt` | When it is next delivered, or `null` for never. |
| `owner` | `final String owner` | The principal that saved it ([TomPrincipal.qualifiedId]). |
| `readDefinition` | `static ({TomAuditQuestionFilter filter, List<String> recipients, String format}) readDefinition(Map<String, Object?> json)` | Reads `definitionJson`'s form back: the filter, the recipients and the format. |
| `recipients` | `final List<String> recipients` | Where its deliveries go. |
| `schedule` | `final String? schedule` | When it is delivered (a five-field cron expression in UTC), or `null`. |
| `static` | `static` | Reads [definitionJson]'s form back. |

### TomAuditQuestionFilter

**Kind:** `class`

What a question asks: the record fields it narrows to and the window.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `action` | `final TomAuditAction? action` | The action. |
| `actor` | `final String? actor` | The acting user's name. |
| `from` | `final DateTime? from` | The window's start (inclusive). |
| `fromJson` | `factory TomAuditQuestionFilter.fromJson(Map<String, Object?> json)` | Reads the JSON form (the keys `tomAuditReportsApi` documents); refuses an unknown key or a value of the wrong kind. |
| `lastHours` | `final int? lastHours` | A window of this many hours, ending when the question is asked. |
| `limit` | `final int limit` | At most this many records. |
| `maxLimit` | `static const int maxLimit = 5000` | The most records a question may ask for. |
| `outcome` | `final TomAuditOutcome? outcome` | The outcome. |
| `requestId` | `final String? requestId` | One request's records. |
| `target` | `final String? target` | What was acted on. |
| `targetKey` | `final String? targetKey` | The key of what was acted on. |
| `to` | `final DateTime? to` | The window's end (exclusive). |
| `toJson` | `Map<String, Object?> toJson()` | The JSON form; only the keys that are set. |
| `toQuery` | `TomAuditQuery toQuery(DateTime now, {String? tenant})` | The query this filter asks at [now], newest first — of [tenant]'s entries only when given. |
| `writers` | `final List<String>? writers` | The writers to read; every writer when `null`. |

### TomAuditQuestionRow

**Kind:** `class`

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `definition` | `String definition = ""` | `definition`. |
| `id` | `String id = ""` | `id`. |
| `lastDeliveredAt` | `String? lastDeliveredAt` | `last_delivered_at`. |
| `name` | `String name = ""` | `name`. |
| `nextDeliveryAt` | `String? nextDeliveryAt` | `next_delivery_at`. |
| `owner` | `String owner = ""` | `owner`. |
| `schedule` | `String? schedule` | `schedule`. |
| `updatedAt` | `String updatedAt = ""` | `updated_at` — when the question was last saved, as stored text. |

### TomAuditQuestionStore

**Kind:** `abstract class`, implementing `TomTenantData`

The saved questions.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `due` | `Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50})` | The questions whose next delivery is at or before [now], oldest due first, at most [limit]. |
| `find` | `Future<TomAuditQuestion?> find(String id)` | The question with [id], or `null`. |
| `ownedBy` | `Future<List<TomAuditQuestion>> ownedBy(String owner)` | The questions [owner] saved, by name. |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | *(TomTenantData)* Deletes the questions whose owner names [tenant] (`tenant:<id>/…`); answers how many. |
| `remove` | `Future<bool> remove(String id)` | Removes the question with [id]; answers whether there was one. |
| `save` | `Future<void> save(TomAuditQuestion question)` | Stores [question], replacing the one with its id. |

### TomAuditReportDelivery

**Kind:** `class`

What one delivery did.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `error` | `final Object? error` | Why it failed, or `null`. |
| `exportKey` | `final String? exportKey` | The stored export's key, or `null` when the delivery failed. |
| `question` | `final TomAuditQuestion question` | The question delivered. |
| `recordCount` | `final int recordCount` | How many records the export holds. |
| `succeeded` | `bool get succeeded` | Whether the export was stored and sent. |

### TomAuditReportException

**Kind:** `class`

Raised when a question cannot be read, saved, found or answered; [key] names which (`audit_reports.question.invalid`, `audit_reports.question.not_found`, …).

### TomAuditReports

**Kind:** `class`

Answers, keeps and delivers audit questions.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `ask` | `Future<TomAuditViewResult> ask(TomAuditQuestionFilter filter)` | [filter] asked now — in a tenant's context of that tenant's entries only. |
| `columns` | `static final List<TomTabularColumn> columns = [ TomTabularColumn('timestamp', label: 'Time'), TomTabularColumn('writer', label: 'Writer'), TomTabularColumn('actor', label: 'Actor'), TomTabularColumn('action', label: 'Action'), TomTabularColumn('target', label: 'Target'), TomTabularColumn('targetKey', label: 'Key'), TomTabularColumn('outcome', label: 'Outcome'), TomTabularColumn('requestId', label: 'Request'), TomTabularColumn('detail', label: 'Detail')]` | The columns of an exported answer. |
| `deliverDue` | `Future<List<TomAuditReportDelivery>> deliverDue()` | Delivers every question due now, each in its owner's tenant; a question of a tenant not served as active now is held, still due. Answers what each delivery did. |
| `deliverSoon` | `Future<TomAuditQuestion> deliverSoon(String owner, String id)` | Marks [owner]'s question [id] for delivery at the next pass; refuses (`audit_reports.question.no_recipients`) a question with nowhere to go. |
| `email` | `final TomExportEmailDelivery? email` | How a delivery is sent; `null` in a process that does not deliver. |
| `exports` | `final TomExportService? exports` | Where delivered exports are stored; `null` in a process that does not deliver. |
| `install` | `void install()` | Installs this service as the process-wide bean. |
| `jobName` | `static const String jobName = 'audit_reports.deliver'` | The job name [registerOn] registers. |
| `questionOf` | `Future<TomAuditQuestion> questionOf(String owner, String id)` | [owner]'s question [id]; refuses (`audit_reports.question.not_found`) one that does not exist or belongs to someone else — the two are not told apart. |
| `questions` | `final TomAuditQuestionStore questions` | Where questions are kept. |
| `questionsOf` | `Future<List<TomAuditQuestion>> questionsOf(String owner)` | The questions [owner] saved. |
| `registerOn` | `TomJobDefinition registerOn(TomScheduler scheduler, {Duration every = const Duration(minutes: 1)})` | Registers the delivery pass on [scheduler]: [deliverDue] every [every]. |
| `remove` | `Future<void> remove(String owner, String id)` | Removes [owner]'s question [id]; refuses one that is not theirs. |
| `resolve` | `static TomAuditReports? resolve()` | The installed service, or `null`. |
| `save` | `Future<TomAuditQuestion> save(String owner, TomAuditQuestion question)` | Saves [question] as [owner]'s: a new question (with a new id) when its id is empty, else the replacement of [owner]'s question with that id. |
| `tabularOf` | `static TomTabularResult tabularOf(String title, TomAuditViewResult answer)` | [answer] as an export of one section, titled [title]. |
| `view` | `final TomAuditView view` | Where the trail is read. |
| `writers` | `Future<List<String>> writers()` | The writers the trail holds records of. |

### TomAuditReportsErrorHandler

**Kind:** `class`

Maps the audit-report refusals to their statuses: a question that is not the caller's (or not there) is a `404`, one that cannot be read a `400`, one with nowhere to deliver to a `409`, a server that is not set up for audit reports a `503`.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `statusByErrorKey` | `Map<String, int> get statusByErrorKey` | *(override)* `question.not_found` 404, `question.invalid` 400, `question.no_recipients` 409, `no_principal` 401, `not_configured` 503; every other key 500. |

### TomAuditReportsServer

**Kind:** `class`

The implementation of `tomAuditReportsApi`, over the installed [TomAuditReports].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `auditReportAnswer` | `Future<TomAuditReportResultDto> auditReportAnswer(TomAuditQuestionIdRequest request)` | *(override)* The caller's question answered now. |
| `auditReportDeleteQuestion` | `Future<void> auditReportDeleteQuestion(TomAuditQuestionIdRequest request)` | *(override)* Removes the caller's question. |
| `auditReportDeliver` | `Future<TomAuditQuestionDto> auditReportDeliver(TomAuditQuestionIdRequest request)` | *(override)* The caller's question marked for the next delivery pass. |
| `auditReportQuery` | `Future<TomAuditReportResultDto> auditReportQuery(TomAuditReportQueryRequest request)` | *(override)* The request's filter answered once, across the writers it names. |
| `auditReportQuestions` | `Future<TomAuditQuestionsDto> auditReportQuestions()` | *(override)* The caller's questions, by name. |
| `auditReportSaveQuestion` | `Future<TomAuditQuestionDto> auditReportSaveQuestion(TomAuditQuestionDto request)` | *(override)* Saves the question as the caller's; the owner and delivery times are the server's. |
| `auditReportWriters` | `Future<TomAuditReportWritersDto> auditReportWriters()` | *(override)* The writers of the trail. |
| `questionDto` | `static TomAuditQuestionDto questionDto(TomAuditQuestion question)` | [question] for the wire. |
| `questionOf` | `static TomAuditQuestion questionOf(TomAuditQuestionDto dto)` | The question [dto] describes; its owner and delivery times are the server's to set. |
| `resultDto` | `static TomAuditReportResultDto resultDto(TomAuditViewResult result)` | [result] for the wire. |

### TomAuditTrailSource

**Kind:** `abstract class`

Where a view reads: the writers a trail holds, and one writer's answer.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `query` | `Future<TomAuditQueryResult> query(String writer, TomAuditQuery query)` | [writer]'s answer to [query]. |
| `writers` | `Future<List<String>> writers()` | The writers the trail holds records of, by name. |

### TomAuditView

**Kind:** `class`

Answers a question across the writers of a trail.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `query` | `Future<TomAuditViewResult> query(TomAuditQuery query, {List<String>? writers})` | [query] asked of [writers] (every writer of the trail when `null`). |
| `source` | `final TomAuditTrailSource source` | Where the trail is read. |

### TomAuditViewEntry

**Kind:** `class`

One record of a view's answer, with the writer whose chain holds it.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `entry` | `final TomAuditEntry entry` | The entry in that writer's chain. |
| `writer` | `final String writer` | The writer. |

### TomAuditViewResult

**Kind:** `class`

A view's answer.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `entries` | `final List<TomAuditViewEntry> entries` | The matching records across the writers asked, ordered as the query asked (newest first by default), at most the query's limit. |
| `hasMore` | `final bool hasMore` | Whether a writer held more matches than the answer carries. |
| `writers` | `final List<String> writers` | The writers that were asked. |

### TomAuditWriterRow

**Kind:** `class`

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `writer` | `String writer = ""` | The writer. |

### TomMemoryAuditQuestionStore

**Kind:** `class`

[TomAuditQuestionStore] in memory.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `due` | `Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50})` | *(override)* The questions whose next delivery is at or before `now`, earliest first. |
| `find` | `Future<TomAuditQuestion?> find(String id)` | *(override)* The question with that id, or `null`. |
| `ownedBy` | `Future<List<TomAuditQuestion>> ownedBy(String owner)` | *(override)* The owner's questions, by name. |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | *(override)* Deletes the questions whose owner names the tenant. |
| `remove` | `Future<bool> remove(String id)` | *(override)* Removes the question, answering whether there was one. |
| `save` | `Future<void> save(TomAuditQuestion question)` | *(override)* Stores the question, replacing one with the same id. |

### TomMemoryAuditTrailSource

**Kind:** `class`

[TomAuditTrailSource] over in-memory sinks, one per writer — for tests and a single process.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `query` | `Future<TomAuditQueryResult> query(String writer, TomAuditQuery query)` | *(override)* The writer's answer to the query. |
| `sinks` | `final Map<String, TomMemoryAuditSink> sinks` | The sinks, by writer. |
| `writers` | `Future<List<String>> writers()` | *(override)* The writers the trail holds records of, by name. |

### TomSqlAuditQuestionStore

**Kind:** `class`

[TomAuditQuestionStore] over the `tom_audit_question` table.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `createSchema` | `final bool createSchema` | Whether the store creates its table when it is missing; `false` hands the schema to the migration chain. |
| `datasource` | `final TomDataSource datasource` | The data source holding [table]. |
| `due` | `Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50})` | *(override)* The questions due at `now`, earliest first. |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the table when [createSchema] is set; once per store. |
| `find` | `Future<TomAuditQuestion?> find(String id)` | *(override)* The question with that id, or `null`. |
| `named` | `factory TomSqlAuditQuestionStore.named(String datasourceName, {String table = defaultAuditQuestionTable, bool createSchema = true, DateTime Function()? clock})` | A store over the registered data source [datasourceName]; refuses (`audit_reports.store.unknown_datasource`) a name the registry does not hold. |
| `ownedBy` | `Future<List<TomAuditQuestion>> ownedBy(String owner)` | *(override)* The owner's questions, by name. |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | *(override)* Deletes the questions whose owner names the tenant. |
| `remove` | `Future<bool> remove(String id)` | *(override)* Removes the question, answering whether there was one. |
| `save` | `Future<void> save(TomAuditQuestion question)` | *(override)* Stores the question, replacing one with the same id. |
| `table` | `final String table` | The table. |

### TomSqlAuditTrailSource

**Kind:** `class`

[TomAuditTrailSource] over the relational trail: one table, every writer's rows.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `datasource` | `final TomDataSource datasource` | The data source holding [table]. |
| `named` | `factory TomSqlAuditTrailSource.named(String datasourceName, {String table = defaultAuditTrailTable})` | Reads the trail of the registered data source [datasourceName]; refuses (`audit_reports.view.unknown_datasource`) a name the registry does not hold. |
| `query` | `Future<TomAuditQueryResult> query(String writer, TomAuditQuery query)` | *(override)* The writer's answer to the query. |
| `table` | `final String table` | The trail's table. |
| `writers` | `Future<List<String>> writers()` | *(override)* The writers the trail holds records of, by name. |

## Global Functions and Constants

| Name | Declaration | Description |
| ---- | ----------- | ----------- |
| `auditQuestionTable` | `TomFrameworkTable auditQuestionTable(String table)` | The saved-question table, as the framework declares it. |
| `auditQuestionTableDdl` | `String auditQuestionTableDdl(String table)` | The `CREATE TABLE` of [auditQuestionTable]. |
| `tomAuditReportsDatasource` | `TomDataSource tomAuditReportsDatasource(String name, String part)` | The data source registered as [name], for the `.named` constructors of this module; refuses (`audit_reports.<part>.unknown_datasource`) a name the registry does not hold. |
