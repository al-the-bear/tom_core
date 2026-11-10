# advanced_ops_server

Back-office server for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

A third server with **no HTTP surface and no database of its own**. It runs
scheduled work against the app server's `app_db`: a nightly retention purge, a
morning digest rendered from a text bundle and handed to the messaging outbox, a
weekly report rendered into the blob store, and — deliberately *not* on the
scheduler — an audit-anchor publisher on its own timer. Because it is the one
process that reaches both databases, it is also where the sample's personal data
is registered for erasure and subject access
([below](#a-users-personal-data-across-both-databases)).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[14 · Operations: scheduled work over live data](../README_advanced_14_operations.md)**.

**The server is the demonstration; the example is the seam.**
`dart run bin/ops_server_start.dart` boots the whole back office, and needs both
databases. [`example/digest_composition_example.dart`](example/digest_composition_example.dart)
needs nothing: it runs the real `OpsDigestService` over a two-person in-memory
audience — built through the same `RepositoryDigestAudience.summariesFrom` join
the server uses, so `bob`'s stored `de` becomes his digest's locale — queues
into a memory outbox, ticks it once, and prints the German and the English mail
rendered from the shipped `assets/text_*.yaml`.

```sh
dart run example/digest_composition_example.dart
```

`test/examples_test.dart` runs it the same way and checks it.
[The family's index](../README_advanced_sample.md#the-ten-packages) says which
of the ten carry an `example/`, and why.

## Why a third server

Scheduling, auditing, messaging and export each have a module guide and a
worked example in this suite. What none of them had was an artifact in which
they *meet*. The seams between them are where the interesting decisions live,
and every one of those decisions was previously documented in prose and
demonstrated nowhere:

| Seam | Stated in | Made observable here |
| --- | --- | --- |
| the anchor publisher is not a scheduled job | [audit.md · Why the publisher is not a scheduled job](../../tom_core_server/doc/audit.md#why-the-publisher-is-not-a-scheduled-job) | `lib/src/ops_anchoring.dart` + `test/ops_anchor_test.dart` asserts that no `@TomScheduledJob` declares it |
| the outbox puts retries on the job queue | [messaging.md · Delivery Semantics: One Retry Mechanism](../../tom_core_server/doc/messaging.md#delivery-semantics-one-retry-mechanism) | a job composes, a *second* scheduler delivers; `test/ops_digest_test.dart` shows a failed send redelivered without recomposition |
| a mail names a template key, never a subject | [messaging.md · Application Email: A Template Key, Not a Body](../../tom_core_server/doc/messaging.md#application-email-a-template-key-not-a-body) | the digest holds no user-facing string; `assets/text_{en,de}.yaml` carry subject and body, and `ops_digest_test.dart` renders one digest in two languages |
| an export's only seam is storage | [export.md · Storage: A Deliberately Narrow Seam](../../tom_core_server/doc/export.md#storage-a-deliberately-narrow-seam) | the weekly report lands in the same `tom_blob` pair as an item attachment, under its own prefix |
| the repository is the audit chokepoint | `audit.md` | a machine deleting rows at 03:00 produces the same trail a human's `DELETE` would |

It is also where the sample's `min(user, server)` authorization meet stops being
an abstraction: every job runs as a service account under a deliberately narrow
server cap, and `test/ops_authorization_meet_test.dart` shows the *identical
actor* refused work it could do uncapped.

## The six pieces of recurring work

Five are scheduled jobs; the sixth is not, and that is the point.

| Work | Schedule | Retry | Why that policy |
| --- | --- | --- | --- |
| `ops.purge` | `0 3 * * *` | 2 attempts, `requestsRecovery: true` | idempotent by construction — a destroyed row is not returned by the next scan, so a recovered run resumes rather than repeats |
| `ops.digest` | `0 6 * * *` | **none**, `missedWindow: skip` | the retry budget belongs to the outbox, per message; a digest delivered at noon is contradicted by the board the reader is looking at |
| `ops.blobSweep` | `0 4 * * 0` | **none**, `missedWindow: skip` | the sweep is a predicate over the table, not a window — a missed run costs one week of orphaned chunks, which the next run takes |
| `ops.report` | `0 5 * * 0` | 3 attempts | `allowOverlap: false` matters most here — two runs would render two windows under two date-partitioned keys |
| `audit_reports.deliver` | every minute | none — a failed delivery is recorded in the trail and the question moves to its next time | the framework's audit-report delivery pass (`TomAuditReports.registerOn`): the saved questions the app server's `/audit-reports` API marks or schedules, rendered into the blob store under `audit-reports/` and mailed through the outbox, with the `audit_reports.delivery.*` texts of `assets/text_*.yaml` |
| the anchor publisher | plain `Timer`, hourly | n/a | the trail is a hash chain **per writer**; a cluster-arbitrated anchor would leave every other node unanchored while the dashboard reported success |

Job classes are four lines each. The scheduler instantiates a job per run with
`newInstance('', const [])`, so a job class cannot take constructor arguments —
it resolves its service from a named bean, and the logic lives in an ordinary
testable class (`OpsRetentionService`, `OpsDigestService`, `OpsReportService`,
`OpsBlobSweepService`) that takes its collaborators through its constructor.

## Two schedulers, on purpose

`OpsRuntime` owns the job scheduler; `TomMessageOutbox` owns a second, private
one for delivery. They share the *store* — both queues are rows in `tom_job_run`
— but not the driver, because their tick rates differ by two orders of
magnitude. A cron job is due at most once an hour; a queued message is due now.
Folding delivery into the job scheduler would mean either ticking the cron
evaluator every fifteen seconds or making a queued message wait for the next
minute boundary.

`OpsRuntime.start()` / `.close()` also own the *order* the four collaborators
start and stop in. The audit sink must be installed before the first job body
runs, uninstalled after the last one stops, and **drained** after that — a
record the sink has accepted but not yet written is still in its queue, and
`TomAuditSink.close()` stores it before it completes. That is why
`close()` returns a `Future`: the signal handler — on SIGTERM, which is what an
orchestrator sends, and on SIGINT — awaits it before `exit(0)`, which does not
wait for pending work. Four independent `start()` calls in a
`main` are four chances to get that order wrong with the constraint living only
in a comment.

`close()` walks `start()`'s list backwards, and two of the steps are worth
naming. The deployment principal is cleared, because `TomServerPrincipal` is
*process*-global while the runtime is not — a closed runtime that left its cap
standing would hand the deployment's licence to whatever ran next. And anchoring
is split: the timer is disarmed at the top of the shutdown, so no tick can pin a
head the drain is about to move, while the final anchor is published at the very
end, after the drain, so it covers the records the drain stored rather than the
head as it stood before them.

## The digest's text is not in the digest

`OpsDigestService` holds no sentence a recipient reads. It builds a
`TomEmailRequest` naming the template key `email.ops_digest` plus a parameter
map, and `TomEmailService` resolves subject and body out of
`assets/text_en.yaml` / `assets/text_de.yaml` (`lib/src/ops_texts.dart` loads
them at boot, so a missing or malformed bundle stops the server rather than
being discovered at 06:00 as a blank mail). It is handed the *service*, not the
outbox, so there is no way for it to compose a subject even by accident.

The locale is per recipient — `OpsDigestSummary.locale` — because one pass mails
everybody and there is no moment at which the job could meaningfully "switch to
German". It comes from the account: `RepositoryDigestAudience` reads the stored
`auth_users.language` / `.country` pair, and a user with none gets the deployment
default. In the seeded data `bob` reads German and `carol` has no preference, so
one pass renders one mail of each.

The two sentences the digest includes only sometimes (an overdue count, a next
due date) are **their own resource keys**, resolved separately and passed in as
`{overdueLine}` / `{nextDueLine}`, empty when the condition does not hold. A
template cannot express "only when", and the alternative — conditionals in the
resource format — is the first step of a second template engine beside the one
the client bundles already use.

Every sentence that states a count is resolved the same way, for the same
reason: a template substitutes `{count}` into one sentence, and "1 open item(s)"
is what that produces. The framework's text resources choose no sentence by
count, so the digest does — each counted key (`open_summary`, `open_line`,
`overdue_line`) carries a `one` and an `other` form, `opsCountForm` picks one
from the number by CLDR's rule for English and German, and the bundle supplies
every word. The subject's count and the body's are separate keys because German
declines them differently: "1 offener Vorgang" in the subject, "Sie haben 1
offenen Vorgang" in the body. A third locale with more plural categories would
extend `opsCountForms`, and the bundle test would then demand the new forms of
every bundle.

## Identity: the narrow cap

`lib/src/ops_identity.dart` holds two entitlement sets that differ by exactly
one grant:

- **`opsServiceAccountEntitlements`** — the four scheduled operations *plus*
  `app.item.reassign`;
- **`opsDeploymentEntitlements`** — the four scheduled operations only.

The first is what the actor holds; the second is the server-level cap installed
by `installOpsDeploymentPrincipal()`. Because access resolves as
`min(user, server)`, the reassign grant the account carries is unreachable in
this process — the same actor, uncapped, may do it. `requireOpsCapability`
records a `denied` audit record *before* throwing `TomPermanentJobFailure`, so a
refusal is evidence rather than a log line, and the scheduler does not spend a
retry on a decision that will not change.

## A user's personal data, across both databases

A user's data is spread over both databases: their account, roles and group
memberships in the auth server's `auth_db`, their workspaces, the items they
report or are assigned and the comments they write in the app server's `app_db`.
An erasure or a subject-access export has to reach all of it, and this server is
the one process that holds both servers' repositories — which is why the
registration lives here rather than in either of them.

`bin/ops_server_start.dart` calls `registerOpsPersonalData()`
(`lib/src/ops_privacy.dart`) right after the app server's scope and grade
registrations. It enrols six repositories with `TomPrivacy`, in the order an
erasure visits them. What each row does when its user is erased is not decided
there: it is declared on the record, in the two servers' persistence models.

| Record | Database | `@TomDataSubject` field | On erasure | `@TomPersonal` fields |
| --- | --- | --- | --- | --- |
| `WorkspaceRecord` | `app_db` | `ownerId` | deleted — and with it, by the schema's `ON DELETE CASCADE`, its projects, lists, items and comments | — |
| `ItemRecord` | `app_db` | `assigneeId`, `reporterId` | unlinked: the field is cleared, the item stays in someone else's workspace | — |
| `CommentRecord` | `app_db` | `authorId` | anonymized: the comment stays in its thread, its author cleared and its `body` replaced by `[removed]` | `body` |
| `GroupMemberRecord` | `auth_db` | `userId` | deleted | — |
| `UserRoleRecord` | `auth_db` | `userId` | deleted | — |
| `UserRecord` | `auth_db` | `id` | deleted | `username`, `displayName`, `email` |

Workspaces come first, so the rows their cascade removes are not visited twice;
the account comes last. `TomPrivacy.erase(userId)` then deletes, unlinks and
anonymizes through those repositories — audited, and unscoped, so the caller is
the one who decides who may ask — and `TomPrivacy.subjectAccess` /
`exportSubject` export every row naming the user, one section per record, as
CSV, XLSX or PDF.

**Registered, not exposed.** The boot only makes the operations available to
code in this process. No job and no endpoint calls them — the server has no
endpoints — so `test/ops_privacy_live_test.dart` is what drives them.

**No subject keys at boot.** `@TomPersonal` values are sealed in the audit trail
only when subject keys are installed — `TomPrivacy.installSubjectKeys`, or a
`privacy` configuration section, which `TomServer.start()` applies through
`TomServer.configurePrivacy`. None of the three servers carries that section,
and this one never calls `TomServer.start()`, so in the running sample the trail
records personal values as they are: an erasure removes the rows, and the
values in the trail stay readable. The live suite installs `TomSubjectKeys` over
a `TomSqlSubjectKeyStore('app_db')` itself, which is what lets it show the
other half — the comment's `body` sealed in the trail, readable through
`TomPrivacy.reveal` before the erasure and `[erased]` after it, while the hash
chain still verifies.

## Running it

Relative asset and migration paths resolve against the CWD, so run from the
package root. Both databases must be up — the boot initializes *every* declared
datasource, and the digest resolves recipients through the auth server's user
repository:

```sh
cd ../advanced_auth_server && docker compose up -d auth-db
cd ../advanced_app_server && docker compose up -d app-db
cd ../advanced_ops_server && dart run bin/ops_server_start.dart
```

Nothing is delivered to a real mail server by default: with `OPS_SMTP_HOST`
unset, digests are written as `.eml` files under `OPS_MAIL_DIR`
(`./ztmp/ops_mail`) where they can be opened and read. That is the honest sample
default — a discarding transport would make a green run and an undelivered
digest look identical.

The process stops on SIGTERM or SIGINT (Ctrl-C), closing the runtime before it
exits; a second signal while it closes is ignored. SIGTERM is not watched on
Windows, where Dart cannot watch it, so there only Ctrl-C stops it cleanly.

| Variable | Default | Purpose |
| --- | --- | --- |
| `OPS_NODE_ID` | `ops-<host>-<pid>` | this process's identity in `tom_scheduler_node` and `tom_lease.owner` |
| `OPS_SMTP_HOST` / `_PORT` / `_USER` / `_PASSWORD` | unset | real delivery; unset ⇒ `.eml` files |
| `OPS_MAIL_FROM` | unset | the digest sender address |
| `OPS_MAIL_DIR` | `ztmp/ops_mail` | where `.eml` files land |
| `OPS_ANCHOR_DIR` | `ztmp/ops_anchors` | the anchor store directory |
| `OPS_ANCHOR_INDEPENDENT` | `false` | whether the deployment asserts that directory is genuinely independent storage |

### `--migrate-only`

```sh
dart run bin/ops_server_start.dart --migrate-only
```

Runs the boot as far as the migrations and exits without starting a scheduler.
This package owns `[100]` and up of the `app_db/app_schema` chain — the
framework tables the scheduler, the leases and the trail need — while the
`[000]`–`[099]` band lives in the app server's folder, which is the one mounted
into the database container's initdb hook. Two packages can contribute to one chain because the
engine records an applied version per *(datasource, schema)* pair; something
still has to apply the file the container never sees, and both alternatives are
worse. Starting the server to migrate would also start its timers; applying the
SQL by hand would leave the version table unaware `[100]` had run.

Several ops servers — or the ops server and the app server — starting together
migrate `app_db` one at a time: every run takes the database's migration lock,
and a run that waited finds the other's migrations applied.

### `--repair-migration` / `--repair-action`

```sh
dart run bin/ops_server_start.dart \
  --repair-migration=app_db/app_schema/100 --repair-action=remove
```

Repairs the record of a migration that failed and exits, without migrating or
starting a scheduler. A failed MariaDB script leaves its statements so far
applied and the version recorded as failed, and every later start refuses the
schema until the record is repaired. After undoing what the script left,
`--repair-action=remove` deletes the record so the next start applies the
migration again; after finishing it by hand, `--repair-action=resolve` marks it
applied so the next start skips it. Neither runs a script. See
[Repairing a failed migration](../README_advanced_sample.md#repairing-a-failed-migration).

### `--rollback-migrations`

```sh
dart run bin/ops_server_start.dart --rollback-migrations=app_db/app_schema/-1
```

Undoes the migrations of the schema applied above the version (`-1`: all of
them) with the down scripts beside them, newest first, and exits without
migrating or starting a scheduler. A migration without a down script, or whose
up script is not the one recorded, refuses the rollback before anything is
undone. See
[Rolling migrations back](../README_advanced_sample.md#rolling-migrations-back).

## The migration this package owns

`database_migrations/system/app_db/app_schema/[100]-ops_framework_tables.sql` creates
`tom_job_run`, `tom_job_pause`, `tom_job_run_archive`, `tom_lease`,
`tom_scheduler_node` and `tom_audit_trail`; `[101]-ops_audit_reports.sql` creates
`tom_audit_question`, the saved audit questions the app server's
`/audit-reports` API keeps and this server delivers.
`test/ops_framework_schema_test.dart` checks both files against the framework's
own table descriptors, so a framework column added upstream fails here rather
than at 03:00 in production.

The gap between the app server's highest migration and `[100]` is deliberate.
Two packages number into one chain and neither can see the other's choice, so
each owns a **band** rather than taking the next free number: within its own
range each numbers freely and no coordination is needed. Without that, the two
sides eventually pick the same number — and a collision is silent, because the
engine records the version as applied and never runs the second file, which
surfaces as a missing table at the first tick of whichever deployment was
provisioned last. `test/ops_migration_chain_test.dart` reads both directories
and fails if either side leaves its band.

## API

Every public declaration the barrel (`lib/advanced_ops_server.dart`) exports,
library by library, with its signature as the source declares it. The sections
above are the narrative; this is the index. Annotations, initializer lists and
bodies are left out — the schedule each job declares is in
[The six pieces of recurring work](#the-six-pieces-of-recurring-work).

There is no `doc/` folder and no `doc/api/` summary: no sample carries one, a
decision taken once for all eighteen in [the suite map](../README.md). This
section is the reference instead, and `test/readme_api_reference_test.dart`
holds it to the source in both directions — every line below must occur in its
library, and every public declaration of an exported library must be listed.

### `lib/src/jobs/retention_service.dart`

The nightly purge: terminal items past the retention window, destroyed one entity at a time so each delete is audited.

```dart
const Set<TodoStatus> retainableTerminalStatuses
class OpsRetentionReport
  const OpsRetentionReport({required this.cutoff, required this.examined, required this.deleted, required this.reassignmentRefused})
  final DateTime cutoff
  final int examined
  final int deleted
  final bool reassignmentRefused
  String toString()
abstract class OpsRetentionStore
  Future<List<ItemRecord>> expiredItems(DateTime cutoff, {required int limit})
  Future<void> destroy(ItemRecord item)
class RepositoryRetentionStore implements OpsRetentionStore
  const RepositoryRetentionStore()
  Future<List<ItemRecord>> expiredItems(DateTime cutoff, {required int limit})
  Future<void> destroy(ItemRecord item)
class OpsRetentionService
  OpsRetentionService({required this.store, this.retention = const Duration(days: 90), this.batchLimit = 500})
  final OpsRetentionStore store
  final Duration retention
  final int batchLimit
  bool get reassignInsteadOfDeleting
  Future<OpsRetentionReport> purgeExpired(DateTime now)
```

### `lib/src/jobs/digest_service.dart`

The morning digest: who has open work, in which language, composed from a template key and queued — never sent.

```dart
final Set<TodoStatus> openStatuses
class OpsDigestSummary
  const OpsDigestSummary({required this.userId, required this.displayName, required this.emailAddress, required this.openCount, required this.overdueCount, this.nextDue, this.locale})
  final int userId
  final String displayName
  final String emailAddress
  final int openCount
  final int overdueCount
  final DateTime? nextDue
  final TomTextLocale? locale
  String toString()
class OpsDigestReport
  const OpsDigestReport({required this.window, required this.considered, required this.queued, required this.skippedWithoutAddress})
  final DateTime window
  final int considered
  final int queued
  final int skippedWithoutAddress
  String toString()
abstract class OpsDigestAudience
  Future<List<OpsDigestSummary>> summariesFor(DateTime now)
class RepositoryDigestAudience implements OpsDigestAudience
  const RepositoryDigestAudience()
  Future<List<OpsDigestSummary>> summariesFor(DateTime now)
  static List<OpsDigestSummary> summariesFrom({required Iterable<UserRecord> users, required Map<int, List<ItemRecord>> itemsByAssignee, required DateTime now})
  static OpsDigestSummary summarise({required int userId, required String displayName, required String emailAddress, required List<ItemRecord> items, required DateTime now, TomTextLocale? locale})
class OpsDigestService
  OpsDigestService({required this.audience, required this.email, this.sender, this.productName = 'Advanced Todo'})
  final OpsDigestAudience audience
  final TomEmailService email
  final TomRecipient? sender
  final String productName
  static String messageIdFor(int userId, DateTime window)
  Future<OpsDigestReport> queueDigests(DateTime window)
  TomEmailRequest requestFor(OpsDigestSummary summary, DateTime window)
  TomMessage composeFor(OpsDigestSummary summary, DateTime window)
```

### `lib/src/jobs/report_service.dart`

The weekly export of completed items into the blob store.

```dart
const Duration opsReportWindow
const String opsReportFormat
const String opsExportKeyPrefix
const String opsAuditReportKeyPrefix
class OpsReportOutcome
  const OpsReportOutcome({required this.from, required this.to, required this.rowCount, required this.stored})
  final DateTime from
  final DateTime to
  final int rowCount
  final TomStoredExport stored
  String toString()
abstract class OpsReportSource
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to)
class RepositoryReportSource implements OpsReportSource
  const RepositoryReportSource()
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to)
class OpsReportService
  OpsReportService({required this.source, required this.exports, this.window = opsReportWindow, this.format = opsReportFormat, this.baseName = 'completed-items'})
  final OpsReportSource source
  final TomExportService exports
  final Duration window
  final String format
  final String baseName
  Future<OpsReportOutcome> publishReport(DateTime now)
```

### `lib/src/jobs/blob_sweep_service.dart`

The orphan-chunk sweep over the database blob store.

```dart
class OpsBlobSweepReport
  const OpsBlobSweepReport({required this.chunksRemoved})
  final int chunksRemoved
  String toString()
class OpsBlobSweepService
  const OpsBlobSweepService({required this.store})
  factory OpsBlobSweepService.configured([String? storeName])
  final TomDatabaseBlobStore store
  Future<OpsBlobSweepReport> sweep()
```

### `lib/src/jobs/ops_jobs.dart`

The four `@TomScheduledJob` declarations and the bean and job names that wire them to the services.

```dart
const String opsRetentionServiceBean
const String opsDigestServiceBean
const String opsReportServiceBean
const String opsBlobSweepServiceBean
const String opsPurgeJobName
const String opsReportJobName
const String opsDigestJobName
const String opsBlobSweepJobName
class OpsPurgeJob extends TomJobBase
  Future<Object?> execute()
class OpsReportJob extends TomJobBase
  Future<Object?> execute()
class OpsBlobSweepJob extends TomJobBase
  Future<Object?> execute()
class OpsDigestJob extends TomJobBase
  Future<Object?> execute()
```

### `lib/src/ops_anchoring.dart`

The audit-anchor publisher — on its own timer, deliberately not a scheduled job.

```dart
const String opsAuditWriter
const Duration opsAnchorInterval
class OpsAnchoring
  OpsAnchoring({required this.publisher})
  factory OpsAnchoring.toDirectory(Directory directory, {required TomAuditSink sink, Duration interval = opsAnchorInterval, bool independentOfServer = false})
  final TomAuditAnchorPublisher publisher
  bool get independentOfServer
  Future<void> start()
  Future<TomAuditAnchor> publishNow()
  Future<void> close()
  void stop()
  String describe()
```

### `lib/src/ops_identity.dart`

The two principals (the deployment cap and the service account that acts under it), their entitlements, and the gate every job passes.

```dart
const String retentionPurgeEntitlement
const String digestSendEntitlement
const String exportPublishEntitlement
const String auditAnchorEntitlement
const String itemReassignEntitlement
const List<String> opsDeploymentEntitlements
const List<String> opsServiceAccountEntitlements
const String opsServiceUsername
const String opsServiceUserId
final TomPrincipal opsServiceAccount
final TomPrincipal opsDeploymentPrincipal
class OpsCapabilities
  static const TomAccessControl purgeExpiredItems
  static const TomAccessControl sendDigest
  static const TomAccessControl publishExport
  static const TomAccessControl publishAuditAnchor
  static const TomAccessControl reassignItems
Future<void> requireOpsCapability(TomAccessControl capability, {required String operation, required String entitlement})
void installOpsDeploymentPrincipal()
Future<T> runAsOpsService<T>(Future<T> Function() body)
```

### `lib/src/ops_privacy.dart`

The sample's personal data, registered with `TomPrivacy` in the order an erasure visits it: workspaces, items, comments, group memberships, role assignments, the account.

```dart
void registerOpsPersonalData()
```

### `lib/src/ops_runtime.dart`

Assembly: the scheduler, the outbox, the anchoring, and their start and close order.

```dart
const Duration opsTickInterval
const Duration opsOutboxTickInterval
class OpsRuntime
  OpsRuntime({required this.scheduler, required this.outbox, required this.anchoring, required this.auditSink, this.nodes, this.auditReports})
  factory OpsRuntime.production({required TomDataSource datasource, required String nodeId, required TomMessageTransport transport, required Directory anchorDirectory, TomRecipient? digestSender, bool anchorStoreIsIndependent = false})
  final TomScheduler scheduler
  final TomMessageOutbox outbox
  final OpsAnchoring anchoring
  final TomAuditSink auditSink
  final TomSqlSchedulerNodes? nodes
  final TomAuditReports? auditReports
  void registerServices({required OpsRetentionService retention, required OpsDigestService digest, required OpsReportService report, required OpsBlobSweepService blobSweep})
  Future<List<TomJobDefinition>> start()
  Future<void> close()
```

### `lib/src/ops_texts.dart`

The localized bundle set the digest renders from.

```dart
const String opsDigestTemplateKey
const String opsDigestOpenSummarySubKey
const String opsDigestOpenLineSubKey
const String opsDigestOverdueSubKey
const String opsDigestNextDueSubKey
const List<String> opsDigestCountedSubKeys
const List<String> opsCountForms
String opsCountForm(int count)
class OpsTexts
  static const String assetDirectory
  static const List<String> localeTags
  static const String defaultLocaleTag
  static TomLocalizedTextResources install({String directory = assetDirectory})
  static TomLocalizedTextResources resources()
  static TomLocalizedTextResources load({String directory = assetDirectory})
```

## Tests

Fifteen suites; all but the two live ones, `ops_live_test.dart` and
`ops_privacy_live_test.dart`, need no socket at all.

| Suite | What it settles |
| --- | --- |
| `ops_retention_test.dart` | one `destroy` per candidate, each carrying an entity; the terminal-status filter; the unscoped pass |
| `ops_digest_test.dart` | composition from template keys in two languages, the singular and plural of every counted sentence in both, that the shipped bundles carry every key the digest resolves (both forms of each counted one), that an unknown template fails before anything is queued, the message id as idempotence key, and a failed send redelivered *without* recomposition |
| `ops_report_test.dart` | the rendered projection, the date-partitioned key, the window derived from `run.scheduledFor` |
| `ops_anchor_test.dart` | the publisher's schedule — and that no `@TomScheduledJob` declares it |
| `ops_jobs_test.dart` | every declared schedule, retry policy, timeout and overlap flag |
| `ops_authorization_meet_test.dart` | `min(user, server)`: the same actor refused under the cap, the refusal recorded, and no retry requested |
| `ops_framework_schema_test.dart` | `[100]` and `[101]` against the framework's table descriptors |
| `ops_migration_chain_test.dart` | that this package's file extends the app server's chain rather than forking it, and that neither side numbers outside its band |
| `ops_blob_sweep_test.dart` | the orphan-chunk sweep's wiring: the service calls `purgeOrphanedChunks` and reports the count, and a store that cannot sweep is refused at wire-up rather than becoming a scheduled no-op |
| `comments_read_as_is_test.dart` | that no comment under `lib/`, `bin/`, `test/`, `tool/` or `example/` cites a quest work item or narrates what the code used to do, and that every section number carries the document it belongs to |
| `boot_assets_test.dart` | that the three assets the boot needs throw when absent, naming the absolute path and the working directory; that the per-environment overlay may be absent; and that the root environment ships none, which is the premise the optional branch rests on |
| `examples_test.dart` | that `example/digest_composition_example.dart` runs under its documented command with no infrastructure: queued before delivered, `bob` in German and `carol` in English, the conditional lines only when true |
| `readme_api_reference_test.dart` | that the README's `## API` section matches the source both ways: every listed signature occurs in its library, and every public declaration the barrel exports is listed |
| `ops_live_test.dart` | **the consequences** — that the counted deletes produced audit rows, that the export bytes came back out of the database, that the scheduler's tables are the ones `[100]` built |
| `ops_audit_reports_live_test.dart` | **an audit question delivered from the sample's trail** — records written to `app_db`'s `tom_audit_trail`, a question saved in `tom_audit_question` and marked for delivery, the pass delivering it as a CSV mail holding exactly the matching records, the question delivered once, and the delivery itself in the trail |
| `ops_privacy_live_test.dart` | **a user exported and erased across both databases** — the subject-access export holds their account, role, workspace, both items and both comments; the erasure deletes what is theirs (their workspace's contents with it), unlinks them from the item they were assigned, keeps their comment in the other workspace's thread without their name or words, records the erasure, leaves their words `[erased]` in the audit trail while it still verifies, and finds nothing on a second run |

```sh
dart test                                # every suite; the live ones skip
./tool/run_ops_integration.sh            # boots both databases, applies [100] and [101], runs everything
```

The live suites *skip* when `app_db` is unreachable, so a laptop with no docker
stays green. Both bring the database up through `test/support/live_database.dart`
— the boot sequence of `bin/ops_server_start.dart`, in its order, with the
loaders imported from the boot rather than copied — and skip per test through
its `liveDatabaseUnavailable()`. A skip is only safe if something turns it back
into a failure when the database was supposed to be there — that is the
runner's job: it treats the string `All tests skipped` as a failure, boots both
databases from fresh volumes, applies `[100]` and `[101]`, runs the three live suites and then the
connection-free ones, and tears everything down again.
