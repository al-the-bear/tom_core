# Operations: scheduled work over live data

*Part 14 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Every part before this one describes a system that acts **because somebody asked
it to**. A request arrives, a principal is resolved, a handler runs, a response
goes back. That framing is so pervasive that the framework's most careful
guarantees — the audit chokepoint, the four-state grade, the closed-safe default
— have only ever been demonstrated against a human at the other end of a socket.

This part is the other half. `advanced_ops_server` is a third server with **no
endpoints and no database of its own**, which wakes on a timer and mutates the
app server's data with nobody watching. It is the process that deletes rows at
03:00. Everything the earlier parts established has to still be true here, and
the interesting thing about building it was discovering which parts needed extra
work to *stay* true.

## Four kinds of recurring work, and one of them is not a job

Scheduling, auditing, messaging and export each have a module guide in
`tom_core_server/doc/` and a focused example in this repository. What none of
them had was an artifact in which they **meet**. Each guide names a seam and
then, necessarily, stops — because a seam between two modules cannot be
demonstrated from inside either one:

| The claim | Where it is stated | Where it is now observable |
| --- | --- | --- |
| the anchor publisher must not be a scheduled job | `audit.md:496` | `ops_anchoring.dart`; `ops_anchor_test.dart` asserts no `@TomScheduledJob` declares it |
| the outbox puts its retries on the job queue | `messaging.md:317` | a job composes; a *second* scheduler delivers; `ops_digest_test.dart` shows a failed send redelivered without recomposition |
| an application mail names a template key, not a body | `messaging.md:435` | the digest holds no sentence a recipient reads; `assets/text_{en,de}.yaml` do, and `ops_digest_test.dart` renders one digest in two languages |
| an export's only real seam is storage | `export.md:394` | the weekly report is rows in the same `tom_blob` pair as an item attachment |
| the repository is the audit chokepoint | `audit.md` | a machine's 03:00 delete produces the same trail a human's would |

The server runs four pieces of recurring work. Three are `@TomScheduledJob`s;
the fourth deliberately is not, and the difference is the most instructive thing
in this part.

| Work | Schedule | Retry policy | The reasoning |
| --- | --- | --- | --- |
| `ops.purge` | `0 3 * * *` | 2 attempts, `requestsRecovery: true` | idempotent by construction — a destroyed row is not returned by the next scan, so a recovered run *resumes*. Two attempts, not three: a purge that fails twice fails for a reason the next window will not fix, and the rows are still there to find. |
| `ops.digest` | `0 6 * * *` | **`TomRetryPolicy.none`**, `missedWindow: skip` | the retry budget belongs to the outbox, per message. Skipping a missed window because a summary of yesterday's open work, delivered at noon after an outage, is a mail contradicted by the board its reader is already looking at. |
| `ops.report` | `0 5 * * 0` | 3 attempts | `allowOverlap: false` matters more here than anywhere: two concurrent runs compute two windows, render two reports, and store them under two date-partitioned keys — leaving a reader to guess which of two plausible files is the week's. |
| the anchor publisher | a plain `Timer`, hourly | — | see below. |

### Why the anchor publisher is not on the scheduler

This is the sample's clearest case of a correct mechanism producing a wrong
answer.

The audit trail is a hash chain **per writer**, and the writer is the process.
That is exactly what lets several nodes append to one `tom_audit_trail` table
without their entries interleaving into a single unverifiable chain — each node
has its own head. An anchor is a published claim about a head at a moment.

Put the publisher on the scheduler and its single-fire guarantee works
perfectly: **one** node anchors. The others do not. And the operations dashboard
reports the trail as anchored, because *an* anchor was published. That is worse
than no anchoring, because it is an assurance nobody will re-check.

So it runs on a plain `Timer` inside `TomAuditAnchorPublisher`, per process,
unarbitrated. `ops_anchor_test.dart` asserts the design point *directly* — that
no `@TomScheduledJob` in the package declares it — because "this is deliberately
not a job" is precisely the kind of comment that stops being true the first time
somebody tidies up.

Note also what the framework does **not** ship, and why this server cannot reach
for it: there is no SQL anchor store. Anchoring a trail into the database that
holds it is one credential and one blast radius — ceremony rather than a
guarantee. `TomFileAuditAnchorStore` writes JSON Lines to a directory, and
whether that directory is genuinely *independent* is a deployment fact this
package cannot establish. `OpsAnchoring.describe()` therefore reports what the
arrangement **is** at boot rather than asserting what it should be.

## The delete this job deliberately does not do

`DELETE FROM app_items WHERE status = 'done' AND updated_at < ?` is one
statement, one round trip, and **invisible to the trail**.

That is not an oversight in `deleteByQuerySentence`; it is a consequence of what
an audit record is. A record names a target key and carries a before-image, and
a bulk statement has neither — the database applies it to a row set the
application never held. There is no version of bulk delete that could be
audited without first becoming row-by-row.

So the retention pass *is* row-by-row, on purpose: `expiredItems()` finds the
candidates and each one is destroyed with `delete(entity)`, the call that
carries a before-image into the trail. It is slower, and that is the trade the
deployment is making — a retention pass that cannot say **which** rows it
destroyed is not one anybody can defend afterwards.

`OpsRetentionReport.deleted` is counted from the calls actually made, never from
a row count, so the connection-free test is an assertion about the *path taken*.

### Running unscoped, and paying for it

`ItemRecord` carries `@TomDbScope(field: 'id', scope: itemVisibilityScope)`, an
async row scope that resolves the current principal's owned ∪ shared id-set into
an OR-union predicate. Exactly right for a request; exactly wrong here. The ops
service account owns nothing and is shared nothing, so a scoped pass would find
zero rows and report a clean, successful, **entirely fictional** retention run.

`TomDataScope.runUnscoped` is the framework's answer, and this server is the one
caller in the whole sample that legitimately uses it. It pays for that in the
only currency available: everything it then does is attributed and audited. A
bypass that was also invisible would be indistinguishable from a bug.

The ops server *installs* the app server's scopes and grades at boot and then
bypasses them explicitly, rather than achieving the same effect by never having
registered them. That is the difference between a documented exemption and an
accident — and it also means the process presents the same picture of
`app_items` the app server does, which a process that reads another server's
tables must.

## `min(user, server)`, made a test

[Part 07](README_advanced_07_authorization.md) and
[Appendix A1](README_advanced_A1_authorization_state_machine.md) describe access
resolving as the **meet** of the user's state and the server's:
`userState.narrow(serverState)`. Composition that can only restrict. Until this
server, that had no demonstration in which the two operands genuinely differed —
in the request path the server cap is uninstalled, so `null` means "no cap
applies" and the meet is the identity.

`ops_identity.dart` makes them differ by exactly one grant:

```dart
// what the actor holds
opsServiceAccountEntitlements = { …the four scheduled operations…,
                                  itemReassignEntitlement };
// the cap this process installs
opsDeploymentEntitlements     = { …the four scheduled operations… };
```

The service account carries `app.item.reassign`. The deployment cap does not.
`min(full, none) = none`, so in this process the grant is unreachable — and
`ops_authorization_meet_test.dart` shows the **identical actor** doing the work
uncapped and being refused under the cap. That contrast is the point: a test
that only showed the refusal would be consistent with the account simply lacking
the grant, which would demonstrate nothing about the meet.

Two further properties are asserted rather than asserted-about:

- **Neither operand can widen the other.** Swapping which set is the cap gives
  the same answer, because the meet is symmetric — a server grant the user lacks
  is as unreachable as a user grant the server lacks.
- **An empty deployment principal is not the same as none at all.** `null`
  means "no cap applies" and yields the user's state unchanged; an installed
  principal holding nothing caps everything to `none`. Conflating them is how a
  deployment accidentally runs uncapped.

### A refusal is evidence, not a log line

`requireOpsCapability` records a `denied` audit record **before** it throws, and
it throws `TomPermanentJobFailure` rather than an ordinary exception. Both
halves matter:

- a machine refused work leaves a trail entry attributed to the service account,
  so the refusal is as auditable as the deletes are;
- `TomPermanentJobFailure` tells the scheduler not to spend a retry. An
  authorization decision will not come out differently in five minutes, and a
  job that retried a denial three times would put three identical refusals in
  the trail and delay the next real window.

## Two schedulers, sharing a store

`OpsRuntime` owns the job scheduler. `TomMessageOutbox` owns a second, private
one for delivery. They share the **store** — both queues are rows in
`tom_job_run` — but not the driver, because their tick rates differ by two
orders of magnitude. A cron job is due at most once an hour; a queued message is
due now. Folding delivery into the job scheduler would mean either ticking the
cron evaluator every fifteen seconds or making a queued message wait for the
next minute boundary.

That split is what puts the digest's retry budget in the right place. The job
composes and returns the moment the messages are durably enqueued; it never
waits for a relay and never learns whether delivery succeeded. A job that
awaited SMTP would fail — and *recompose the whole morning's digest* — because
one mail server was slow.

The idempotence key closes the loop. The scheduler's guarantee is
**at-least-once**, so the digest job will occasionally run twice for one window
(after a node dies mid-run, most obviously), and a digest that arrived twice
because a scheduler recovered would be the framework's fault surfacing as spam.
`messageIdFor(recipient, window)` derives the id from exactly those two things,
and the outbox keys its queue row on it — so a second composition of the same
window **replaces** the queued run rather than adding one. At-least-once
delivery of a message that is its own key is exactly-once delivery of a digest.

## The mail this job does not write

`OpsDigestService` is handed a `TomEmailService`, not the outbox. That is a
deliberate narrowing: given the outbox it *could* compose a `TomMessage`, and a
subject line assembled in Dart is a sentence no translator will ever see. Given
the service, the only thing it can produce is a `TomEmailRequest` — a template
key, a recipient and a parameter map:

```dart
TomEmailRequest(
  templateKey: opsDigestTemplateKey,          // 'email.ops_digest'
  messageId: messageIdFor(summary.userId, window),
  to: [TomRecipient(summary.emailAddress, displayName: summary.displayName)],
  locale: summary.locale,
  parameters: {'product': productName, 'openCount': summary.openCount, ...},
);
```

Subject and body come out of `assets/text_en.yaml` and `assets/text_de.yaml`,
resolved through the same `{name}` substitution the client bundles use, so one
bundle format and one placeholder syntax serve both tiers. `OpsTexts.load()`
runs at boot rather than at 06:00 — a malformed bundle should stop a server
start, not surface as a blank mail somebody already received.

The **locale is per recipient** (`OpsDigestSummary.locale`), not per process.
One pass mails everybody, so there is no moment at which this job could
meaningfully "switch to German". `RepositoryDigestAudience` leaves it null today
because `auth_users` has no language column — a deployment that stores a
preference supplies it here and the rest of the path already honours it.

### A sentence a mail includes only sometimes

The digest mentions an overdue count only when there is one, and a next due date
only when something is ahead. A template cannot express "only when", and adding
conditionals to the resource format is the first step of a second template
engine beside the one the client already has. So each conditional sentence is
**its own resource key**:

```yaml
email:
  ops_digest:
    text: |
      You have {openCount} open item(s).
      {overdueLine}{nextDueLine}
    overdue_line: |
      {overdueCount} of them are past their due date.
```

The job resolves each fragment through `TomEmailService.requiredText` and passes
the finished string in as a parameter — empty when the condition does not hold.
Going through `requiredText` rather than a nullable lookup is what keeps one
failure mode for one class of fault: a fragment nobody translated fails the
send naming the key, exactly as a missing subject does. Otherwise the optional
sentence would be the one part of a mail that can silently render blank.

Fragments must be resolved **fully** before being passed in. Substitution is a
single pass over the parameter map, so a fragment still carrying its own
placeholder would be substituted or not depending on map order.

## One chain, two packages

`[100]-ops_framework_tables.sql` lives in **this** package and extends the app
server's `app_db/app_schema` chain. That works because the migration engine
records an applied version per *(datasource, schema)* pair, regardless of which
package the folder sits in — so a deployment can add a back-office server
without editing the app server's package.

The two packages divide the chain into **bands**: the app server numbers in
`[000]`–`[099]`, the ops server from `[100]` up. The gap is the point. Neither
package depends on the other, so neither can see which numbers are already
taken; taking "the next free number" therefore means guessing, and two packages
guessing eventually guess the same. A collision is not a loud failure — the
engine records the version as applied and the *second* file with that number is
never run at all, so the symptom is a missing table on a fresh deployment,
discovered at the first tick, in whichever environment was provisioned last.
With bands, each side numbers freely inside its own range and the question never
arises. `ops_migration_chain_test.dart` reads both directories and fails if
either side leaves its band — the check belongs to the ops server because it is
the only package that can see both.

(`auth_db` has one contributing package and stays contiguous. A band buys
nothing where nobody else can collide with you, and the gap would be pure
noise.)

It also creates a wrinkle worth stating, because it is the shape any real
multi-package deployment hits. The app server's compose file mounts **its own**
migration folder into MariaDB's initdb hook, so the `[000]`–`[099]` band applies
itself on a fresh volume. The container has never seen `[100]`. Something has to
apply it, and both obvious alternatives are worse:

- *start the ops server to migrate* — which also starts its timers, putting a
  second scheduler node on the same `tom_lease` rows a test is about to claim;
- *apply the SQL by hand* — which leaves the chain's version table unaware
  `[100]` ever ran.

Hence `--migrate-only`: the full boot sequence as far as the migrations, then
exit. `tool/run_ops_integration.sh` uses it for exactly that reason.

`ops_framework_schema_test.dart` then checks the file against the framework's
own table descriptors, so a column added upstream to `tom_job_run` fails in CI
rather than at 03:00.

## What only a live suite could prove

Seven of the package's eight suites need no socket, and between them they cover
every *decision* the package makes. What they cannot reach is the **consequence**
of a call.

`ops_retention_test.dart` counts one `destroy` per candidate, each carrying an
entity — but its store is a stand-in. A repository that quietly stopped writing
audit rows would leave that suite entirely green. `ops_live_test.dart` closes
the loop by reading the trail back out of a real database, and it is the only
artifact in the package that can.

It earned its place immediately. Running it against live MariaDB surfaced three
`tom_core_server` defects that the whole prior sample suite — and every
connection-free suite here — had never reached:

| Defect | Symptom | Fix |
| --- | --- | --- |
| §73 | a UTC `DateTime` could not be written to a datetime column at all — the driver serializes it with a `Z` suffix MariaDB rejects (error 1292) | `_toBindValue` converts to local, preserving the instant so a write/read is a round trip |
| §74 | a `DateTime` predicate was uncompilable unless the entity spelled out `columnType:` by hand — one arm of the declared-type switch built its node and dropped it | the missing `return` |
| §75 | an audited entity with a `DateTime` column could not be updated or deleted **at all**: the before-image was not JSON-encodable, and `_audit` is deliberately uncaught, so the trail's failure failed the mutation | `TomAuditRecord` normalises both images to encodable values in its constructor |

All three are one-line-to-one-method framework fixes with their own regression
tests. They are also all `DateTime` defects, which is the pattern worth naming:
the prior sample's entities happened not to query, audit or bind a timestamp,
and a whole type's worth of behaviour was untested behind that coincidence.
Composing four modules over live data is what walked into it.

## How the whole feature is proved

| Level | Suite | What it settles |
| --- | --- | --- |
| retention | `ops_retention_test.dart` | one `destroy` per candidate, each carrying an entity; the terminal-status filter; the unscoped pass |
| messaging | `ops_digest_test.dart` | composition from template keys in two languages, that the shipped bundles carry every key the digest resolves, that an unknown template fails before anything is queued, the message id as idempotence key, and a failed send redelivered *without* recomposition |
| export | `ops_report_test.dart` | the rendered projection, the date-partitioned key, the window derived from `run.scheduledFor` |
| audit anchoring | `ops_anchor_test.dart` | the publisher's schedule — and that no `@TomScheduledJob` declares it |
| declarations | `ops_jobs_test.dart` | every schedule, retry policy, timeout and overlap flag, read back from the annotations |
| authorization | `ops_authorization_meet_test.dart` | `min(user, server)`: the same actor refused under the cap, the refusal recorded, and no retry requested |
| schema | `ops_framework_schema_test.dart`, `ops_migration_chain_test.dart` | `[100]` against the framework's descriptors; that it extends the app chain rather than forking it, and that neither package numbers outside its band |
| live stack | `ops_live_test.dart` | **the consequences** — the counted deletes produced audit rows carrying before-images; the export bytes came back out of the database; the scheduler's tables are the ones `[100]` built |

```sh
cd advanced_ops_server
dart test                        # all eight; the live suite skips without docker
./tool/run_ops_integration.sh    # boots both databases, applies [100], runs everything
```

The live suite skips when `app_db` is unreachable so a laptop with no docker
stays green — and a skip is only safe because the runner turns it back into a
failure when the database was supposed to be there, the same discipline
[Part 12](README_advanced_12_testing_integration.md) applies to the cross-tier
runner.

Both databases start, though only one is asserted against: the boot initializes
*every* declared datasource, and the digest resolves its recipients through the
auth server's user repository.

## Building this into your own app

1. **Give back-office work its own process, not a background isolate in the API
   server.** It has different failure modes, a different restart cadence, and a
   different identity. Sharing the API server's process means sharing its
   deploy.
2. **Decide per unit of work whether the cluster should arbitrate it.** The
   scheduler runs a job *once across the cluster*. That is right for a purge and
   wrong for anything whose state is per-process — an audit head, an in-memory
   cache, a local file. Ask which one you have before reaching for
   `@TomScheduledJob`.
3. **Mutate through the repository, one row at a time, when the mutation must be
   auditable.** Bulk statements cannot be audited, not merely are not. If you
   need both speed and a trail, you need two passes, not one clever statement.
4. **Put the retry budget on the smallest unit that can fail alone.** Compose in
   a job, deliver through an outbox, and derive an idempotence key from the
   thing the work is *about* — the recipient and the window, not a timestamp.
5. **Give the process a deliberately narrow server cap and let the meet do the
   work.** Do not build a second, machine-only permission scheme. The service
   account may hold grants the deployment does not; `min(user, server)` makes
   them unreachable without a new mechanism to get wrong.
6. **Use `run.scheduledFor`, never `DateTime.now()`.** A run recovered four
   hours late must compute the window the on-time run would have — otherwise two
   nodes replaying one window derive two.
7. **Let a refused machine action reach the trail**, and mark it permanent so
   the scheduler does not retry a decision.

[Appendix A4](README_advanced_A4_implementation_rules_checklist.md) carries the
authorization lines with their enforcement anchors.

## Primary sources

- `advanced_ops_server/lib/src/ops_runtime.dart` (the assembly and its ordering),
  `ops_identity.dart` (the two entitlement sets), `ops_anchoring.dart` (why not a job),
  `ops_texts.dart` + `assets/text_{en,de}.yaml` (the digest's text)
- `advanced_ops_server/lib/src/jobs/` — `ops_jobs.dart` (the declarations),
  `retention_service.dart`, `digest_service.dart`, `report_service.dart`
- `advanced_ops_server/bin/ops_server_start.dart` (the boot sequence and `--migrate-only`),
  `database_migrations/app_db/app_schema/[100]-ops_framework_tables.sql`
- `tom_core_server/doc/` — `scheduling.md`, `audit.md` (§496), `messaging.md`
  (§317 delivery, §435 application email), `resources.md`, `export.md` (§394)
- `advanced_ops_server/test/ops_live_test.dart`, `tool/run_ops_integration.sh`

---

← Prev: [13 · File transfer under the authorization matrix](README_advanced_13_file_transfer.md) · Next: [A1 · Four-state authorization deep dive](README_advanced_A1_authorization_state_machine.md) →
