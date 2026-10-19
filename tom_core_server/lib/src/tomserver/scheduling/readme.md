# scheduling

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The relational implementations of the kernel's two scheduling ports, for a
cluster whose nodes share a database but not a filesystem.

## Key types

| Type | Implements | Backing |
| ---- | ---------- | ------- |
| `TomSqlJobStore` | `TomJobStore` | one row per scheduled run in `tom_job_run` |
| `TomSqlLeaseLock` | `TomLeaseLock` | one row per resource in `tom_lease` |
| `TomSqlSchedulerNodes` | — | one row per node in `tom_scheduler_node` |

The first two are ordinary implementations of contracts defined in
`tom_core_kernel`; nothing in this module extends or narrows those contracts, and
both are verified against the kernel's own parameterised contract suite (see
`test/scheduling_db_test.dart`). The third implements no kernel contract: it
observes *nodes* rather than leases, and nodes exist only where there is a
cluster.

## Quick start

Two things have to be in place before the queue will answer, and the *third*
thing you might expect is not one of them — the tables create themselves.

```dart
import 'package:tom_core_server/tom_core_server.dart';

// Your own package's generated registration. `TomJobRunRow` is `@tomReflector`,
// and the store reads rows back through it.
import 'main.reflection.dart';

Future<void> main() async {
  // 1. Reflection first. The store's queries are `executeQuery<TomJobRunRow>`,
  //    so without this the first *read* — not the construction, and not the
  //    enqueue — throws
  //    `annotation_analyzer.analyse_persistent_type.mirror_not_found`.
  initializeReflection();

  // 2. A registered datasource. `TomSqlJobStore.named` resolves it at
  //    construction rather than on the first tick, so a name that is not
  //    registered is a start-up failure instead of a scheduler that looks alive
  //    and claims nothing.
  await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
    'main': <String, dynamic>{
      'type': 'mariadb',
      'host': 'localhost',
      'port': 3306,
      'username': 'todo',
      'password': 'secret',
      'databaseName': 'todo',
    },
  });

  // 3. There is no third step. `createSchema` defaults to `true`, so the store
  //    issues its own `CREATE TABLE IF NOT EXISTS` on first use — unlike the
  //    entity-backed modules, which need their migration applied first. A
  //    deployment that does not let its application run DDL passes
  //    `createSchema: false` and applies `example/scheduling/migrations/`
  //    (`migrations_postgresql/` on PostgreSQL) instead; see [Schema](#schema).
  final store = TomSqlJobStore.named('main');

  final now = DateTime.now().toUtc();
  await store.enqueue(
    TomJobRun(
      id: 'nightly-2026-05-01',
      jobName: 'nightly',
      scheduledFor: now,
      runAt: now,
    ),
  );

  // The claim is a conditional UPDATE, so a second node running this same line
  // against the same row gets an empty list rather than an error — which is the
  // whole of the arbitration. `owner` is this node's identity in the claim.
  final claimed = await store.claimDue(now, 'node-a');
  print(claimed.single.run.jobName); // nightly

  await store.complete(claimed.single, DateTime.now().toUtc());
}
```

> **Needs your package's generated reflection and a live database.**
> `main.reflection.dart` is written by `dart run build_runner build` in *your*
> package, and step 2 opens a real socket — so this is a sequence to build into
> an application rather than a program to paste and run. It is shown whole
> because the first step fails at a place that does not point at it: a missing
> reflection registration gets as far as enqueueing the run and fails on reading
> it back.

The same sequence runs against a live MariaDB or PostgreSQL in
`test/scheduling_db_test.dart`, which also runs both implementations through the
kernel's own parameterised contract suite.

## Why the pair, and why in one database

`tom_core_kernel` ships `TomMemoryJobStore` / `TomMemoryLeaseLock` (one process)
and `TomFileJobStore` / `TomFileLeaseLock` (any number of processes sharing a
filesystem). The file pair is a correct multi-node implementation — it is what
the kernel's cross-process isolate tests exercise — but only where every node
mounts the same filesystem.

The queue and the lock **must share a failure domain**. If the queue says node A
claimed a run while the lock says node B holds it, the disagreement has no
resolution: neither side is authoritative over the other. So the pairing is not
a convenience — a database queue takes a database lock, over the same
`TomDataSource`, so that there is one thing to be up or down.

## How exclusion is arbitrated

The database decides, never the application. Every transition is a conditional
statement whose affected-row count is the answer:

- a claim is `UPDATE ... WHERE id = :id AND state = 'pending' AND claim_token = :current`, raising `claim_token` as it goes;
- a first acquisition is an insert that keeps a stored row on a conflict — `INSERT IGNORE` on MariaDB, `ON CONFLICT DO NOTHING` on PostgreSQL;
- a takeover is `UPDATE ... WHERE resource = :r AND token = :t AND version = :v`.

Reads exist only to nominate candidates; the write revalidates every condition
it relied on.

`TomSqlJobStore.claimDue` issues one conditional statement **per candidate**
rather than one for the batch, because `TomScheduler` always supplies a stateful
Dart `accept` predicate that cannot run inside SQL. Claiming the batch first and
releasing the rejects would briefly hide runs from peers that would have
accepted them, making contention depend on timing rather than on state. The
library comment in `sql_job_store.dart` records the reasoning in full.

The same conditional shape carries the kernel's rule that a transition out of a
claim records a run but never creates or overrules one: `release`,
`markStarted`, `renewClaim`, `complete` and `fail` each add `AND state =
'running' AND claimed_by = :owner AND claim_token = :token` — the shared
`_heldByClaim` fragment — and return without touching the caller's `TomJobRun`
when the statement affects no row. The state half stops a slow node reporting an
outcome for a run `purgeFinished` has dropped; the `claim_token` half stops it
overwriting a peer's *in-flight* attempt, which the state alone cannot see,
because a run recovery re-queued and a peer re-claimed is `running` again. That
token is the queue's counterpart of `tom_lease.token`, and it is why the queue
and the lock can now agree about who holds a run. See `TomJobStore` and
`TomJobClaim` for the rule; `test/contracts/scheduling_contract.dart` in
`tom_core_kernel` asserts it against this store too.

## When the claim's answer is lost

Because the affected-row count *is* the arbitration, a claim whose
acknowledgement never arrives is not the same as a claim that was refused. A
failed claim is therefore classified (`classifySqlFailure`, in `datasources/`): a
failure the server itself reported is definite and rethrown, while anything else
is ambiguous and settled by re-reading the row. The re-read matches the owner
*and* the claim instant, so a node cannot mistake its own earlier in-flight claim
for this one. No other statement needs the recheck — for `complete`, `fail`,
`markStarted` and `renewClaim` a lost answer leaves the row `running`, and for
`release` it leaves it `pending`, both of which the lease already recovers.

## Noticing a node, not just a lease

`TomSqlSchedulerNodes` keeps one row per node, rewritten on every check-in, and
`recoverAbandoned` uses it to recover a departed node's work within a poll
interval rather than a whole lease timeout — and to attribute it. The failure
test is Quartz's:

```text
failedAfter = checkin_at + max(checkin_interval, now - my_last_checkin) + 7.5s
```

Both terms of the `max` matter: a peer is judged by its *own* cadence, and a node
that was itself stalled must not accuse its peers of the outage it was having.
The formula is exposed as pure functions (`schedulerNodeFailedAfter`,
`isSchedulerNodeFailed`) so that guard is testable without a database.

It is an accelerator, not a correctness mechanism — the lease TTL remains the
floor, and every roll-call failure is logged rather than propagated. It does read
one node's clock against another's, so the cluster needs NTP; claiming and
leasing are unaffected, those instants being database-written.

The check-in happens from `recoverAbandoned`, once per scheduler tick, so
`checkinInterval` is what a node *publishes* rather than what it enforces: set it
to the scheduler's `tickInterval`, never shorter, or the node is late by its own
published standard on every pass. Deriving it from the observed gap instead was
rejected — a stalled node would publish a longer interval and excuse itself,
which is the outage the roll call exists to notice.

## Recovering an interrupted run

`started_at` is recorded separately from `claimed_at`, so recovery can tell
"claimed but never ran" (always safe to re-queue) from "was executing" (only when
the job sets `requestsRecovery`). A started run whose job declines is written off
as `failed` with `TomJobStore.recoveryDeclinedError`, stated rather than left as
a gap. The decision itself lives in the kernel (`TomJobStore.isRecoverable`) so
the memory and SQL stores cannot drift apart on it.

## Schema

The DDL lives in `sql_scheduling_sql.dart` and is shipped as migration files
under `example/scheduling/migrations/`; `test/scheduling_schema_test.dart`
asserts the two have not drifted apart.

Each of the three tables is declared once there, as a `TomFrameworkTable`
descriptor, and everything else is derived from it:

| Declaration | What it gives |
| ----------- | ------------- |
| `jobRunTable(table)` · `leaseTable(table)` · `schedulerNodeTable(table)` | The descriptor for one table under a caller-chosen name — the columns, their families, and the keys. |
| `jobRunTableDdl(table)` · `leaseTableDdl(table)` · `schedulerNodeTableDdl(table)` | That descriptor rendered as canonical (MariaDB-spelled) `CREATE TABLE` — what the shipped MariaDB migration contains. `createSchema: true` runs the descriptor's `create`, which renders it in the connected database's dialect. |
| `defaultJobRunTable` · `defaultLeaseTable` · `defaultSchedulerNodeTable` | The names used when a deployment chooses none: `tom_job_run`, `tom_lease`, `tom_scheduler_node`. |

The table name is a parameter rather than a constant so two deployments can
share one database, and the descriptor is what the convergence check compares a
provisioned schema against. Both stores can also create their table
on first use (`createSchema: true`, the default), which is what a test or a
single-service deployment wants; set it `false` when the migration module owns
the schema and the application's database user may not run DDL.

Three constraints carry the design:

- **`UNIQUE (job_name, tenant, scheduled_for)`** makes the scheduler's
  idempotence key — one run per job per window, per tenant — a database
  invariant rather than a convention. `tenant` is `''` for a run of no tenant.
- **`tom_lease.version`**, incremented on every write, exists because MariaDB
  reports *changed* rows, not matched rows (PostgreSQL reports matched ones). Without it a renewal landing in the
  same clock instant with the same TTL would report zero affected rows, look
  like a lost lease, and fall through to takeover.
- **`tom_scheduler_node.node_id`** is the primary key *and* the same string a
  node claims runs under, so the roll call stays one row per node and a departed
  node's work joins straight back to it.

## Payload

The `payload` column is written by the kernel's `TomJobStore.encodePayload`
rather than by a local `jsonEncode`, so a payload this store cannot serialise is
refused under the same `schedule.job.payload` key the memory and file stores
use. That matters more here than the duplicated line it saves: a job is
developed against the memory store and deployed against this one, and a
restriction only the database enforces is a restriction discovered in
production. The encode runs while the bind map is being built, so the refusal
still precedes any statement.

## Time

Instants are stored as UTC `DATETIME(6)` and carried through `String` columns.
A SQL driver hands a `DATETIME` column over as text, and `DateTime.parse` on it
yields a *local* `DateTime`; since `DateTime.==` compares `isUtc` as well as the
instant, a UTC value would not compare equal to the value read back. A caller
that writes a local `DateTime` gets a UTC one back — the same instant,
differently labelled.

See [`doc/scheduling.md`](../../../../doc/scheduling.md) for the two ports, the
claim protocol and the roll call, and
`example/scheduling/scheduling_example.dart` for a walkthrough that checks its
own results without a database. The arbitration this module exists for happens
*between* processes and so cannot be shown inside one, which is why the cluster
has an example of its own: `example/scheduling/cluster/` runs two real nodes
against a live MariaDB through
`example/scheduling/cluster/run_cluster_demo.sh` (Docker required). It asserts
one execution per window across the pair, a stale fencing token no longer
authorising a write, a killed node's run returning to the queue when its lease
expires and not before, and a node that stops checking in being named failed.
`test/scheduling_db_test.dart` runs the kernel's parameterised contract suite
against both stores, `test/scheduling_cluster_test.dart` covers the roll call and
`test/scheduling_schema_test.dart` holds the DDL and the shipped migrations
together; `test/examples_test.dart` runs the single-process example and states
why it spawns none of the cluster's own programs.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
