# advanced_ops_server

Back-office server for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

A third server with **no HTTP surface and no database of its own**. It runs
scheduled work against the app server's `app_db`: a nightly retention purge, a
morning digest rendered from a text bundle and handed to the messaging outbox, a
weekly report rendered into the blob store, and — deliberately *not* on the
scheduler — an audit-anchor publisher on its own timer.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[14 · Operations: scheduled work over live data](../README_advanced_14_operations.md)**.

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

## The four pieces of recurring work

Three are scheduled jobs; the fourth is not, and that is the point.

| Work | Schedule | Retry | Why that policy |
| --- | --- | --- | --- |
| `ops.purge` | `0 3 * * *` | 2 attempts, `requestsRecovery: true` | idempotent by construction — a destroyed row is not returned by the next scan, so a recovered run resumes rather than repeats |
| `ops.digest` | `0 6 * * *` | **none**, `missedWindow: skip` | the retry budget belongs to the outbox, per message; a digest delivered at noon is contradicted by the board the reader is looking at |
| `ops.report` | `0 5 * * 0` | 3 attempts | `allowOverlap: false` matters most here — two runs would render two windows under two date-partitioned keys |
| the anchor publisher | plain `Timer`, hourly | n/a | the trail is a hash chain **per writer**; a cluster-arbitrated anchor would leave every other node unanchored while the dashboard reported success |

Job classes are four lines each. The scheduler instantiates a job per run with
`newInstance('', const [])`, so a job class cannot take constructor arguments —
it resolves its service from a named bean, and the logic lives in an ordinary
testable class (`OpsRetentionService`, `OpsDigestService`, `OpsReportService`)
that takes its collaborators through its constructor.

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
`TomAuditSink.close()` is synchronous and so has to refuse it. That is why
`close()` returns a `Future`: the signal handler awaits it before `exit(0)`,
which does not wait for pending work. Four independent `start()` calls in a
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
German".

The two sentences the digest includes only sometimes (an overdue count, a next
due date) are **their own resource keys**, resolved separately and passed in as
`{overdueLine}` / `{nextDueLine}`, empty when the condition does not hold. A
template cannot express "only when", and the alternative — conditionals in the
resource format — is the first step of a second template engine beside the one
the client bundles already use.

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

## The migration this package owns

`database_migrations/app_db/app_schema/[100]-ops_framework_tables.sql` creates
`tom_job_run`, `tom_lease`, `tom_scheduler_node` and `tom_audit_trail`.
`test/ops_framework_schema_test.dart` checks that file against the framework's
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

## Tests

Nine suites, eight of which need no socket at all.

| Suite | What it settles |
| --- | --- |
| `ops_retention_test.dart` | one `destroy` per candidate, each carrying an entity; the terminal-status filter; the unscoped pass |
| `ops_digest_test.dart` | composition from template keys in two languages, that the shipped bundles carry every key the digest resolves, that an unknown template fails before anything is queued, the message id as idempotence key, and a failed send redelivered *without* recomposition |
| `ops_report_test.dart` | the rendered projection, the date-partitioned key, the window derived from `run.scheduledFor` |
| `ops_anchor_test.dart` | the publisher's schedule — and that no `@TomScheduledJob` declares it |
| `ops_jobs_test.dart` | every declared schedule, retry policy, timeout and overlap flag |
| `ops_authorization_meet_test.dart` | `min(user, server)`: the same actor refused under the cap, the refusal recorded, and no retry requested |
| `ops_framework_schema_test.dart` | `[100]` against the framework's table descriptors |
| `ops_migration_chain_test.dart` | that this package's file extends the app server's chain rather than forking it, and that neither side numbers outside its band |
| `ops_live_test.dart` | **the consequences** — that the counted deletes produced audit rows, that the export bytes came back out of the database, that the scheduler's tables are the ones `[100]` built |

```sh
dart test                                # the nine suites; the live one skips
./tool/run_ops_integration.sh            # boots both databases, applies [100], runs everything
```

The live suite *skips* when `app_db` is unreachable, so a laptop with no docker
stays green. A skip is only safe if something turns it back into a failure when
the database was supposed to be there — that is the runner's job: it treats the
string `All tests skipped` as a failure, boots both databases from fresh
volumes, applies `[100]`, and tears everything down again.
