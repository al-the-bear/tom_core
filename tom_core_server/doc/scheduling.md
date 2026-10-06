# Scheduling Module

The relational half of the framework's job scheduler: a shared queue and a
shared lock, in the database a server already has, for a cluster whose nodes do
not share a filesystem.

This module implements two contracts and defines nothing. The scheduling *model*
— schedules, windows, retries, missed-window policy, lease semantics, the
execution guarantee — lives in `tom_core_kernel` and is documented in
`tom_core_kernel/doc/scheduling/scheduling.md`. Read that first; this document
covers only what changes when the substrate is a database.

## Table of Contents

- [Overview](#overview)
- [Why the Pair, and Why in One Database](#why-the-pair-and-why-in-one-database)
- [How Exclusion Is Arbitrated](#how-exclusion-is-arbitrated)
- [Why the Claim Is One Statement per Run](#why-the-claim-is-one-statement-per-run)
- [When the Answer to a Claim Is Lost](#when-the-answer-to-a-claim-is-lost)
- [Reporting an Outcome for a Run You May Have Lost](#reporting-an-outcome-for-a-run-you-may-have-lost)
- [The Roll Call](#the-roll-call)
- [Recovering an Interrupted Run](#recovering-an-interrupted-run)
- [What Was Taken from Quartz, and What Was Not](#what-was-taken-from-quartz-and-what-was-not)
- [The Schema](#the-schema)
  - [tom_job_run](#tom_job_run)
  - [tom_lease](#tom_lease)
  - [tom_scheduler_node](#tom_scheduler_node)
- [Creating the Schema](#creating-the-schema)
- [Time](#time)
- [Wiring a Cluster Node](#wiring-a-cluster-node)
- [Operating Notes](#operating-notes)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSqlJobStore` | class | `TomJobStore` over one row per scheduled run |
| `TomSqlLeaseLock` | class | `TomLeaseLock` over one row per contended resource |
| `TomSqlSchedulerNodes` | class | The cluster roll call: one row per node, so a *node* departing is noticed |
| `TomSchedulerNode` | class | One node's published check-in instant and cadence |
| `schedulerNodeFailedAfter` / `isSchedulerNodeFailed` | function | The failure test, as pure functions |
| `jobRunTable` / `leaseTable` / `schedulerNodeTable` | function | The three table declarations, from which the DDL, the statements and the convergence guard's schema model all derive |
| `jobRunTableDdl` / `leaseTableDdl` / `schedulerNodeTableDdl` | function | The shipped DDL, parameterised by table name |
| `defaultJobRunTable` / `defaultLeaseTable` / `defaultSchedulerNodeTable` | const String | `tom_job_run`, `tom_lease`, `tom_scheduler_node` |
| `TomJobRunRow` / `TomLeaseRow` / `TomSchedulerNodeRow` | class | The reflected row types the stores' result mappers materialise, one per table |
| `TomJobRunWindowRow` | class | The single aggregate column `TomSqlJobStore.lastWindow` projects — its own row type because the mapper binds by column name and that select has no other columns |

Two things the stores lean on hardest belong to `datasources`, because nothing
about them is specific to scheduling:

| Name | Module | Purpose |
| ---- | ------ | ------- |
| `classifySqlFailure` / `TomSqlFailureMode` | `datasources` | Whether a failed write is definite or ambiguous — the distinction [When the Answer to a Claim Is Lost](#when-the-answer-to-a-claim-is-lost) turns on |
| `sqlInstant` / `parseSqlInstant` | `datasources` | The UTC `DATETIME(6)` encoding the stores use |

The two stores are ordinary implementations of contracts declared in the kernel.
Nothing here extends, narrows or reinterprets those contracts, and both are
verified against the kernel's own parameterised contract suite rather than
against tests written to fit them. `TomSqlSchedulerNodes` implements no kernel
contract: it is an optional accelerator that this module owns outright, because
the thing it observes — nodes, as distinct from leases — exists only where there
is a cluster.

## Why the Pair, and Why in One Database

`tom_core_kernel` ships two pairs already: memory (one process) and file (any
number of processes that mount the same filesystem). The file pair is a correct
multi-node implementation — it is what the kernel's cross-process isolate tests
exercise — but its assumption is a shared mount, and most clusters do not have
one. They do have a database.

The queue and the lock **must share a failure domain**. A lock in one system and
a queue in another can each be healthy while the other is unreachable, and the
resulting disagreement — the queue says node A claimed the run, the lock says
node B holds it — has no resolution, because neither side is authoritative over
the other. So `TomSqlJobStore` and `TomSqlLeaseLock` are meant to be pointed at
the same `TomDataSource`: one thing to be up, or down.

| Store | Lock | Shared by |
| ----- | ---- | --------- |
| `TomMemoryJobStore` | `TomMemoryLeaseLock` | nothing — one process |
| `TomFileJobStore` | `TomFileLeaseLock` | a filesystem |
| `TomSqlJobStore` | `TomSqlLeaseLock` | a database |

## How Exclusion Is Arbitrated

The database decides, never the application. Every transition is a conditional
statement whose affected-row count *is* the answer:

| Transition | Statement | Winner |
| ---------- | --------- | ------ |
| claim a due run | `UPDATE … WHERE id = :id AND state = 'pending'` | the one update that changes a row |
| first acquisition of a free resource | `INSERT IGNORE` | the insert that creates the row |
| extension by the live holder | `UPDATE … WHERE resource = :r AND token = :t AND owner = :o AND released = 0` | the holder, while its token is still current |
| takeover of a lapsed lease | `UPDATE … WHERE resource = :r AND token = :t AND version = :v` | the compare-and-set that matches |
| renewal | `UPDATE … WHERE owner = :o AND token = :t AND released = 0 AND expires_at > :now` | the holder, while it still holds |

Reads exist only to nominate candidates. Every write revalidates each condition
the read relied on, so a candidate that went stale between the two loses at the
database rather than being trusted in Dart.

## Why the Claim Is One Statement per Run

`TomScheduler` **always** supplies an `accept` predicate to `claimDue`, and that
predicate is a stateful Dart closure: it is how the scheduler enforces
`allowOverlap`, and its answer for one run depends on the runs it has already
accepted in the same pass. A Dart closure cannot execute inside SQL.

The two ways to reconcile that with a single batch statement are both worse:

- **Claim the batch, then release the rejects.** During the window between the
  two statements the rejected runs are `running` and therefore invisible to
  peers that *would* have accepted them. Contention would then depend on
  timing rather than on state.
- **Push the predicate into SQL.** It is application logic; it does not
  translate, and pretending it does would fork the kernel's contract.

So `claimDue` scans candidates (`SELECT` due, pending, ordered by `seq`), runs
`accept` in Dart, and issues a conditional `UPDATE … WHERE id = :id AND state =
'pending' AND claim_token = :current` **per accepted candidate**, setting
`claim_token = :current + 1`. `affectedRows == 1` means this node won; `0` means
a peer took it first, and the candidate is simply skipped. The claim is still
arbitrated entirely by the database — it is one atomic statement *per run* rather
than one for the batch.

The `claim_token` half of the condition is the queue's fencing token, and it is
compared as well as set. Setting it is what gives the returned `TomJobClaim` a
value that identifies *this* claim; comparing it is what guarantees the value the
ticket carries is the value now in the row. Without the comparison, a run that a
peer claimed, finished and re-queued for retry between the scan and this
statement could be claimed here with a token that peer had already been issued —
and two live tickets bearing the same token is exactly the collision the fence
exists to prevent.

The scan reads `limit * candidateFactor` rows (8× by default) so that a pass
whose predicate rejects most candidates still fills its batch.

One consequence is documented rather than hidden: when the database refuses a
claim, the scheduler's own bookkeeping may briefly record the window as busy even
though this node never ran it. That is conservative in the safe direction — the
window is retried on the next tick, so a run is delayed by a tick, never executed
twice.

## When the Answer to a Claim Is Lost

The affected-row count *is* the arbitration, which makes the claim the one
statement in this module whose lost acknowledgement is genuinely ambiguous. If
the `UPDATE` committed and the reply never arrived, the run is owned by a node
that believes it does not own it — and stays that way until the lease expires,
which for a one-minute TTL is a minute of a due run sitting idle while its owner
does nothing.

So a failed claim is classified rather than assumed:

| The failure | Meaning | What the store does |
| ----------- | ------- | ------------------- |
| `MySQLServerException` (the server answered) | The server processed the statement and refused it | **Definite** — rethrow; nothing was claimed |
| anything else | The statement's fate is unknown | **Ambiguous** — re-read the row and believe it |

`classifySqlFailure` walks the exception's `rootException` chain (the data source
wraps driver failures) and asks the *inverted* question: not "is this a transport
failure" but "did the server answer". That inversion is the design decision. The
set of transport failures is open — it grows with every driver, proxy, container
runtime and platform — and each omission would be a silent correctness bug. The
set of "the server answered" is closed and recognisable. The costs are also
asymmetric: a false *ambiguous* costs one extra `SELECT`; a false *definite*
costs an abandoned run.

On the ambiguous path `_resolveAmbiguousClaim` re-reads the row and takes
ownership only when it says `state = 'running'`, `claimed_by` is us, `claim_token`
is the value this call's compare-and-set would have written **and** `claimed_at`
is this claim's instant. The last two are not decoration: a node whose own
*earlier* claim of the same run is still in flight would otherwise read its own
stale lease as proof and dispatch the run twice. Note that the token alone does
not separate them — two overlapping passes of one node scan the same `pending`
row and so compute the same next token. What separates them is the instant, since
two passes of one node do not share a tick. If the re-read
itself fails, the original failure is rethrown with its stack — still blind, so
the honest answer is the failure that started it, and the lease timeout remains
the backstop.

This is Quartz's `TransactionValidator` in miniature, and like Quartz's it is
scoped narrowly. **No other statement needs it**, and the reason is worth
stating positively rather than left as an omission: a lost acknowledgement leaves
the row `running` for `complete`, `fail`, `markStarted` and `renewClaim`, and
`pending` for `release` — states the lease already recovers from. Those five do
read their affected-row count, but only to decide whether to mirror the write
onto the caller's `TomJobRun`; unlike the claim, none of them is *asking* the
database a question it cannot otherwise answer.

## Reporting an Outcome for a Run You May Have Lost

Every transition out of a claim carries the same four-way guard:

```sql
UPDATE tom_job_run SET state='succeeded', completed_at=:now, claimed_by=NULL,
       claimed_at=NULL
 WHERE id=:id AND state='running'
   AND claimed_by=:owner AND claim_token=:token
```

This is the kernel's rule — a transition out of a claim *records* a run, it
never creates or overrules one — expressed in the idiom this store already uses
for everything else. A node that was slow rather than dead comes back still
holding a `TomJobClaim` and still meaning to report an outcome, by which time the
run may have been recovered, re-claimed, finished by a peer or purged. Zero
affected rows says exactly that, and the store returns without touching the
caller's `TomJobRun`.

The `claim_token` conjunct is what makes the guard cover the case the state alone
cannot see: a node partitioned past its lease timeout comes back to a run that
recovery re-queued and a peer re-claimed, so the row *is* `running` and a
state-only guard would pass — overwriting a peer's in-flight attempt. The token
rose when the peer claimed, so the returning node's ticket no longer matches. It
is the queue's counterpart of `tom_lease.token`, which is the point: the queue
and the lock must agree about who holds a run, and they cannot if only one of
them can order two claims.

That case is asserted rather than argued, and it has to be asserted separately:
every other guard test reaches a row that is *not* running — purged, pending,
already terminal — and a state-only guard satisfies all of them. The contract
suite drives the sequence a cluster actually produces (claim, lose the lease to
recovery, let a peer take it, then report the first node's outcome) for
`complete`, for terminal `fail` and for retrying `fail`, and asserts beside them
that the *successor* still completes normally — a fence that rejected everything
would pass the first three.

The single fragment is written once in the store (`_heldByClaim`) rather than
spelled out five times, because a lost conjunct only ever *widens* what a
statement matches — it fails nothing until two nodes race.

The retrying branch of `fail` has a second reason to be gated: it runs
`attempt = attempt + 1`, so ungated it would spend a retry from the budget of
whoever holds the run now.

`purgeFinished` is the case where the SQL store was already safer than its
in-memory sibling — an `UPDATE` against a deleted row simply misses, where a map
write would have re-inserted it. The guard makes the *stated* contract the same
everywhere rather than an accident of the storage medium, and
`test/contracts/scheduling_contract.dart` in `tom_core_kernel` asserts it
against all three stores.

## The Roll Call

Without it, nothing detects a dead *node* — only an expired *lease*. A node that
is killed mid-run holds its claims for the whole lease timeout, and when they are
finally recovered they are merely orphaned, not attributed to anything.

`TomSqlSchedulerNodes` maintains one row per node in `tom_scheduler_node`,
rewritten on every check-in. Passing it to the store as `nodes:` makes
`recoverAbandoned` check in first and then recover the work of any peer the roll
call declares failed — within a poll interval instead of a lease timeout, and
naming the node that left.

The failure test is Quartz's, unchanged:

```text
failedAfter = peer.checkin_at
            + max(peer.checkin_interval, now - my_last_checkin)
            + 7.5s
```

Both halves of that `max` are load-bearing:

- **`peer.checkin_interval`** — the peer's *own* published cadence, so a chatty
  node and a deliberately quiet one are each judged by the interval each actually
  keeps rather than by whichever node happened to ask.
- **`now - my_last_checkin`** — the accuser's own lateness. **A node that was
  itself stalled must not accuse its peers of the outage it was having.** After a
  two-minute GC pause every peer looks silent for two minutes; without this term
  the recovering node would declare the entire cluster dead and recover work that
  is still running.

`schedulerNodeFailedAfter` and `isSchedulerNodeFailed` are pure top-level
functions precisely so that guard can be asserted without a database.

**It accelerates recovery; it does not replace the lease.** The lease TTL remains
the correctness floor. A node that misses a check-in but is still executing is
still protected by its lease at the claim level, and a node declared failed here
has its runs recovered *earlier*, not by a different rule. Wiring `nodes:` is
optional and every roll-call failure is caught and logged rather than propagated:
lose the roll call and recovery falls back to lease expiry alone, exactly as
before.

**Cadence.** A node checks in from `recoverAbandoned`, which the scheduler calls
once per tick — so the *actual* cadence is the scheduler's `tickInterval`, while
`checkinInterval` is only what the node *publishes* as its cadence, and therefore
what its peers judge it by. **Publish an interval no shorter than the scheduler's
tick.** Set them equal and you have the intended configuration; set
`checkinInterval` shorter and the node is late by its own published standard on
every pass, so healthy peers will declare it failed while it is working
perfectly.

Deriving the published value from the observed gap was considered and rejected: a
node that genuinely stalled would then simply publish a longer interval and
excuse itself, which is precisely the outage the roll call exists to notice. The
value stays a deliberate statement of intent — and the consequence of getting it
wrong is churn, not double execution, because a wrongly recovered run is
re-claimed by a peer that then concedes the job's lease to the node still holding
it.

**Clock skew.** The formula compares one node's clock against another's, so the
cluster's clocks must agree to within about a second — the same requirement
Quartz states, for the same reason. Run NTP. Claiming, leasing and lease expiry
are *unaffected* by skew, because those instants are written and compared by the
database; it is only the roll call that reads a peer's clock.

## Recovering an Interrupted Run

Re-queueing every abandoned run is not safe by default. A run that was claimed
and never started can always be re-queued — nothing happened, so nothing can be
repeated. A run that was *executing* when its node died may have sent the email,
charged the card or written half the file.

`tom_job_run` therefore records `started_at` separately from `claimed_at`, set by
`markStarted` at the moment the dispatcher takes the run, and `recoverAbandoned`
branches on it:

| The row | Recovered as |
| ------- | ------------ |
| claimed, never started | `pending` — re-queued for any job, no opt-in needed |
| started, job sets `requestsRecovery` | `pending` — re-queued, attempt count untouched |
| started, job does not | `failed`, with `TomJobStore.recoveryDeclinedError` as `last_error` |

The declined case is *written off explicitly* rather than left in place: an
operator reading the row must see why it was not run again, not find a gap.

The decision itself lives once, in the kernel (`TomJobStore.isRecoverable`), so
the memory and SQL stores cannot drift apart on it; only the transition differs,
being a field assignment in one and two different `UPDATE`s in the other. The
opt-in is declared per job as `@TomScheduledJob(requestsRecovery: true)`, and the
safe behaviour is the default.

## What Was Taken from Quartz, and What Was Not

Quartz's `JDBCJobStore` is the reference implementation of exactly this problem,
and three of its mechanisms are adopted above. Three more were considered and
**deliberately rejected**, which is worth recording so the question is not
reopened as an oversight:

- **The global `TRIGGER_ACCESS` mutex.** Quartz's default acquisition path
  (`batchTriggerAcquisitionMaxCount = 1`, `acquireTriggersWithinLock = false`)
  takes *no cluster lock at all* — it issues a conditional state update and skips
  when no row changed, which is precisely what `claimDue` already does. The
  single global lock is Quartz's documented scaling ceiling (degradation past
  roughly three nodes). Never put a global mutex in front of claiming.
- **Batch acquisition behind that lock.** It only makes sense as an amortisation
  of the lock, and there is no lock to amortise. It would also break the `accept`
  predicate for the reason given in
  [Why the Claim Is One Statement per Run](#why-the-claim-is-one-statement-per-run).
- **String-named job classes.** Quartz stores a class name and reflects on it at
  fire time. `@TomScheduledJob` binds a reflected class directly, so the name is
  never a string that can go stale against a rename.

Two smaller Quartz behaviours *were* adopted, in the kernel scheduler rather than
here: a cap on catch-up enqueues per pass (Quartz's
`maxMisfiresToHandleAtATime`, default 20), so a backlog cannot starve live runs;
and a randomised idle poll interval, because jitter — not partitioning — is
Quartz's answer to N nodes waking together.

## The Schema

Each of the three tables is declared **once**, as a `TomFrameworkTable`
descriptor in `sql_scheduling_sql.dart` — a name, an ordered column list with
types and nullability, and its keys. The `CREATE TABLE` the store issues, the
column list of every `SELECT`, and every `REPLACE` / `INSERT` are all derived
from that one declaration, so a column exists in the code in exactly one place.

The hand-written reference migrations under `example/scheduling/migrations/`
remain the DBA-facing artifact, and `test/framework_schema_test.dart` compares
them against the descriptors, along with the reflected row types and every
statement the stores issue. See
[Schema Convergence](db_migration.md#schema-convergence) for what each of those
comparisons rules out.

Table names are constructor arguments, and the index names follow them — two
queues in one schema would otherwise collide on `uq_…_window`.

### tom_job_run

One row per scheduled run of a job, shared by every node.

| Column | Type | Role |
| ------ | ---- | ---- |
| `seq` | `BIGINT AUTO_INCREMENT` | Insertion order, so every node scans the queue in the same order |
| `id` | `VARCHAR(191)` | Primary key; what every claim, completion and failure addresses |
| `job_name`, `scheduled_for` | `VARCHAR(160)`, `DATETIME(6)` | The window |
| `run_at` | `DATETIME(6)` | When this run should next be attempted |
| `state`, `attempt` | `VARCHAR(16)`, `INT` | `pending` / `running` / `succeeded` / `failed`, and which attempt |
| `claimed_by`, `claimed_at` | `VARCHAR(191)`, `DATETIME(6)` | The store's own lease on the run; `claimed_at` is the heartbeat and moves during an attempt |
| `claim_token` | `BIGINT` | The fencing counter: which claim of the run is current. Rises on every claim, never repeats, never reset |
| `started_at` | `DATETIME(6)` | When execution actually began, or `NULL` if it never did |
| `last_error`, `completed_at`, `payload` | `TEXT`, `DATETIME(6)`, `LONGTEXT` | Outcome and carried data |

`started_at` is separate from `claimed_at` on purpose: the two answer different
questions, and recovery needs both (see
[Recovering an Interrupted Run](#recovering-an-interrupted-run)). One column
carrying both would collapse "claimed but never ran" into "was executing", and
the safe default would have to become the unsafe one.

`claim_token` is separate from `claimed_at` for the same kind of reason, and it
is the direct counterpart of `tom_lease.token` below. `claimed_at` says *when the
claim was last heard from* and moves on every renewal; `claim_token` says *which
claim this is* and must not move, or a heartbeat would invalidate the attempt it
was proving alive. It is not indexed: it is only ever read as an equality
conjunct on a row already located by its primary key.

Two indexes exist because two scans do: `ix_…_due (state, run_at)` for the claim
and `ix_…_lease (state, claimed_at)` for recovery.

**`UNIQUE (job_name, scheduled_for)`** is the load-bearing constraint. It turns
the scheduler's idempotence key — one run per job per window — from a convention
into a database invariant, so a duplicate window cannot exist even when two nodes
plan the same window in the same instant. `job_name` is `VARCHAR(160)`: 640 bytes
in utf8mb4 plus an 8-byte `DATETIME(6)` stays under the 767-byte index limit of
the older InnoDB row formats, so the table can be created on a server that has
not been switched to `DYNAMIC`.

### tom_lease

One row per contended resource. Two columns are load-bearing and neither is
obvious.

**`token`** is the fencing counter, and it is why a released lease keeps its row
(flagged `released = 1`) rather than being deleted. Deleting would restart the
counter at 1 for the next holder, and a token that repeats is not a fencing
token. Retaining the row is also what lets `inspect()` distinguish an orderly
departure from a holder that vanished.

**`version`** is incremented on every write. MariaDB reports *changed* rows, not
matched rows, so an `UPDATE` writing values already present affects zero rows — a
renewal landing in the same clock instant with the same TTL would look like a
lost lease and fall through to takeover. That is precisely the class of bug the
kernel's contract suite exists to catch (a self-re-acquisition that wrongly
issues a new token). `version` makes a matching update always change the row, and
doubles as the compare-and-set guard that lets exactly one of several racing
takeovers win.

### tom_scheduler_node

One row per node, rewritten on every check-in — a current-state table, not a
history, which is why `REPLACE INTO` against the primary key keeps it one row per
node however long the cluster runs.

| Column | Type | Role |
| ------ | ---- | ---- |
| `node_id` | `VARCHAR(191)` | Primary key; the same string the node claims runs under |
| `checkin_at` | `DATETIME(6)` | When this node last announced itself, in UTC |
| `checkin_interval` | `BIGINT` | Milliseconds; this node's *own* published cadence |

`node_id` matching `tom_job_run.claimed_by` is what lets a failed node's work
join straight back to it. `checkin_interval` is stored rather than assumed
globally because the failure test judges each peer by the interval it keeps.

The table is optional: it exists only if a deployment wires
`TomSqlSchedulerNodes`.

## Creating the Schema

Two supported routes, and the choice is about who is allowed to run DDL:

- **`createSchema: true`** (the default) — each store issues its
  `CREATE TABLE IF NOT EXISTS` once, lazily, on first use. Right for tests and
  for a single-service deployment.
- **`createSchema: false`** — the schema is owned by the migration module. Copy
  the three files from `example/scheduling/migrations/main/tomcore/` into the
  application's own migration tree and let `TomDbMigrations.migrateDatabases()`
  apply them. Right when the application's database user may not run DDL, which
  is the usual production posture.

The migration layout is the module's standard one. The shipped files sit at
`<directory>/<datasourceName>/<schemaName>/[<version>]-<description>.sql` and
carry no environment tag, because a scheduling schema is wanted in every
environment. See [Db Migration](db_migration.md#one-file-per-migration) for the
full file-name grammar, including the optional `@<env>` tag.

## Time

Instants are stored as UTC `DATETIME(6)` and are carried through `String` fields
in the row classes. This is deliberate: the MariaDB driver materialises a
`DATETIME` column with `DateTime.parse`, which yields a *local* `DateTime`, and
`DateTime.==` compares `isUtc` as well as the instant — so a UTC value written
would not compare equal to the value read back.

`sqlInstant` renders a fixed-width `YYYY-MM-DD HH:MM:SS.ffffff` literal in UTC.
Fixed width keeps the text ordered in SQL exactly as the instants are ordered in
Dart, so a `run_at <= :now` comparison cannot be surprised by a shorter fraction.
`parseSqlInstant` reconstructs it as UTC.

A caller that passes a local `DateTime` gets a UTC one back: the same moment,
differently labelled. A cluster must not compare wall clocks, so every caller
receives a UTC instant regardless of what it supplied. Clocks are compared across
nodes only through expiry timestamps, so **`leaseTtl` must comfortably exceed the
fleet's worst clock skew**.

## Wiring a Cluster Node

```dart
final nodeId = Platform.localHostname;   // must differ per node

final roll = TomSqlSchedulerNodes.named('main', nodeId: nodeId,
    createSchema: false);
final store = TomSqlJobStore.named('main', createSchema: false, nodes: roll);
final lock = TomSqlLeaseLock.named('main', createSchema: false);

final scheduler = TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: nodeId,
  lock: lock,
  leaseTtl: const Duration(minutes: 1),
);
```

The roll call is optional — omit `nodes:` and everything still works, with
recovery waiting out the lease instead. When it is wired, the node's check-in
happens on the same pass that judges its peers, so a node that stops recovering
also stops claiming to be alive.

`.named()` resolves a registered `TomDataSourceInfo` and raises
`scheduling.store.unknown_datasource` / `scheduling.lock.unknown_datasource` /
`scheduling.nodes.unknown_datasource` when it is absent — a scheduler pointed at
a data source that was never registered is a configuration error, not an empty
queue. Pass the same data-source name to all three.

**`ownerId` must be distinct per node**, and the roll call's `nodeId` must be the
same string. `ownerId` is what the lock uses to tell holders apart, so two nodes
sharing one would each treat the other's lease as its own; and it is what
`claimed_by` records, so a `nodeId` that differs from it would leave a departed
node's work unattributable.

## Operating Notes

- **The queue is a table, so it can be inspected.** `SELECT state, COUNT(*) FROM
  tom_job_run GROUP BY state` answers "is anything stuck" without a tool.
- **Finished runs accumulate.** `purgeFinished(before:)` deletes terminal runs
  older than a cutoff; the scheduler calls it, but a queue with a high window
  rate wants that cutoff set deliberately.
- **`tom_lease` rows are not garbage.** A released row is retained on purpose
  (see [tom_lease](#tom_lease)); deleting rows to tidy up would reset fencing
  counters. `forget` exists for the per-run resource names that are genuinely
  single-use, and takes the kernel's `TomOneShotResource` rather than a
  `String`, so a recurring name cannot reach it by accident.
- **Both stores hold no connection state of their own.** They take a
  `TomDataSource` and issue statements; the connection lifecycle is the data
  source's.
- **`tom_scheduler_node` is a live census.** `SELECT node_id, checkin_at FROM
  tom_scheduler_node ORDER BY checkin_at` answers "who is in the cluster right
  now"; a departed node's row is removed once its work has been reattributed.
- **Set `checkinInterval` to the scheduler's `tickInterval`.** The check-in
  happens once per tick, so a published interval shorter than the tick makes a
  healthy node look late on every pass; see [The Roll Call](#the-roll-call).
- **Run NTP.** The roll call is the one place a node reads a peer's clock; see
  [The Roll Call](#the-roll-call). Skew beyond a second or so makes nodes accuse
  each other or excuse each other, without affecting claiming or leasing.
- **A warning naming a failed node is the signal to look at.**
  `TomSqlJobStore` logs the node it declared failed and how many runs it
  recovered from it — the difference between "a run was orphaned" and "that host
  went away".

## Not Yet Implemented

- **Runs are claimed in insertion order, and there is no priority.** `claimDue`
  scans `WHERE state = pending AND run_at <= now ORDER BY seq`, so a run cannot
  be marked urgent and cannot overtake a backlog. A deployment that needs one
  class of work to go first gives it its own scheduler and its own queue table.
- **A job cannot be paused.** The store has no pause or disable: a job runs
  because it is registered, so stopping one means not registering it, which is a
  configuration change and a restart. `deleteAll` and `purgeFinished` operate on
  *runs*, not on the schedule.
- **`purgeFinished` deletes; it does not archive.** A purged run's outcome is
  gone, and there is no history table beside the queue — so a deployment that
  wants to answer "did the nightly export run last March" keeps its own record,
  or sets the cutoff generously and accepts the table's growth.
- **The stores speak MariaDB, not a dialect.** Both render SQL directly —
  `LIMIT`, `INSERT … ON DUPLICATE KEY UPDATE`, `DATETIME(6)` — rather than
  through `TomStandardSqlDialect`, so a second database means a second
  implementation of `TomJobStore` and `TomLeaseLock` rather than a second
  dialect. The interfaces are the kernel's and are small; that is what makes the
  port tractable.
- **The roll call reads peers' clocks and does not compensate for skew.** It is
  the one place a node judges another by a timestamp the other wrote, so skew
  beyond a second or so makes nodes accuse each other or excuse each other — see
  [The Roll Call](#the-roll-call). Claiming and leasing are unaffected, because
  both are arbitrated by the database's own clock. Run NTP.
- **A recovered run is re-run, not resumed.** Recovery re-queues an abandoned
  run from the beginning; nothing checkpoints partial work, so a job that is not
  idempotent has to make itself so — which is the same requirement the retry
  path already imposes.

## Verification

`test/scheduling_db_test.dart` runs the kernel's contract suite — imported
directly from `tom_core_kernel/test/contracts/scheduling_contract.dart`, not
copied — against both implementations, then adds what only a real database can
substantiate: contended claims across independent connections resolving to
exactly one winner, a rejected candidate remaining claimable by a peer, the
window uniqueness constraint, holder death and recovery, eight-way lease races on
both the free and the lapsed paths, the fencing counter surviving release,
`started_at` being legible to a peer, recovery in both opt-in states, a departed
node's work being recovered two minutes into a fifteen-minute lease, and the
shipped migrations building the schema on a dropped database.

It is tagged `db` and skips when no server is reachable, so the default
`testkit :test` run stays green without one.

Three suites always run. `test/scheduling_schema_test.dart` covers DDL drift,
schema invariants and instant encoding.
`test/framework_schema_test.dart` covers the wider guarantee that the three
tables are declared once — descriptors against the shipped migrations, against
the reflected row types, and against every statement the stores issue (see
[Schema Convergence](db_migration.md#schema-convergence)). Those are all
readings of the source tree, so that file needs no connection at all. The
remaining comparison — a descriptor against a provisioned `information_schema`,
the only one that can see a schema hand-edited after provisioning — needs a
server, and so lives in a separate file, `test/framework_schema_db_test.dart`,
which is what carries the `db` tag and the skip. The two are a pair, not two
halves of one file: every suite here that needs a provisioned server is a `_db`
sibling of a connection-free one, which is precisely why `testkit :test` runs
green on a machine with no MariaDB. This unit is built the same way, as
`test/scheduling_schema_test.dart` and `test/scheduling_db_test.dart`.

`test/scheduling_cluster_test.dart` covers the six cluster questions that a real
server cannot be asked to demonstrate on request:

1. **The ambiguous commit.** The store is driven through a scripted
   `TomDataSource` that can fail a claim *after* the write — the one thing a
   live server will not do when asked. What is under test is the
   classification, not the network.
2. **The failure formula.** Asserted directly, as arithmetic over three
   instants, including the case easiest to omit: the stalled-accuser guard that
   stops a node which was itself descheduled from convicting its peers.
3. **Recovery in both opt-in states.** Which of two `UPDATE`s an interrupted run
   gets. The behaviour is in the choice, and the choice is visible in the
   statement rather than in the outcome.
4. **A roll call that is itself broken.** That a failing roll call cannot break
   recovery — each of its calls is made to fail on its own, and recovery still
   happens. This is the group that substantiates the module's central safety
   claim, that the roll call is a strict accelerator over lease expiry and never
   the only thing standing between two nodes and the same run.
5. **The wiring guards.** The named-data-source lookups and the payload encoder,
   all of which refuse before any statement is issued.
6. **The contended branches of a lease acquire.** Including one no live server
   can be asked for at all: a `forget()` landing between the insert and the
   read, an interleaving a test cannot arrange against a real connection.

One thing no test suite can substantiate, because a suite is one process:
whether two *separately running* nodes actually arbitrate correctly through the
database. `example/scheduling/cluster/run_cluster_demo.sh` is that experiment.
It brings up MariaDB from a fresh volume, applies the shipped migrations, runs
four scenarios as pairs of real processes, and has a third process judge the
result from both the nodes' logs and the final database state — 30 checks over
four claims: a job fires once across the pair, a stale fencing token no longer
authorises a write, a killed node's run returns to the queue when its lease
expires and not before, and a node that stops checking in is named failed from
the one row it always occupied. It exits non-zero if any claim fails, and each
claim was falsified before being trusted (see
[`example/scheduling/cluster/readme.md`](../example/scheduling/cluster/readme.md)).
It is a demonstration rather than a suite because it needs docker and a minute
of wall clock, so it is run deliberately, not by `testkit :test`.

## Core Components

| File | Contents |
| ---- | -------- |
| `lib/src/tomserver/scheduling/sql_job_store.dart` | `TomSqlJobStore` and its row types |
| `lib/src/tomserver/scheduling/sql_lease_lock.dart` | `TomSqlLeaseLock` and its row type |
| `lib/src/tomserver/scheduling/sql_scheduler_nodes.dart` | `TomSqlSchedulerNodes`, `TomSchedulerNode` and the failure formula |
| `lib/src/tomserver/scheduling/sql_scheduling_sql.dart` | The three table descriptors, their derived DDL, table-name defaults |
| `lib/src/tomserver/datasources/sql_failure_mode.dart` | `classifySqlFailure` — definite or ambiguous |
| `example/scheduling/scheduling_example.dart` | The connection-free surface, runnable |
| `example/scheduling/migrations/main/tomcore/` | The shipped reference migrations |
| `example/scheduling/cluster/` | The two-node demonstration: real processes, one database, four claims asserted by a third process |

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `sql_job_store.dart`, `sql_lease_lock.dart` | `Future` |
| `dart:convert` | dart | `sql_job_store.dart` | `jsonDecode` |
| `tom_core_kernel` | package | `sql_job_store.dart`, `sql_lease_lock.dart`, `sql_scheduler_nodes.dart` | `TomJobStore`, `TomLeaseLock`, `TomJobRun`, `TomLease` and the scheduler that drives them |
| [datasources](datasources.md) | module | every file | `TomDataSource` / `TomDataSourceInfo` for connections and parameterised statements |
| [little_things](little_things.md) | module | `sql_job_store.dart`, `sql_lease_lock.dart`, `sql_scheduler_nodes.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `sql_job_store.dart`, `sql_lease_lock.dart`, `sql_scheduler_nodes.dart` | `TomDbColumn`, `TomDbTable` |

- **`db_migration`** — optional; the route by which a deployment creates the
  schema instead of letting the stores create it.
- **`reflection`** — the row types are reflected so the data source can
  materialise query results into them.
