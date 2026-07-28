# scheduling

The relational implementations of the kernel's two scheduling ports, for a
cluster whose nodes share a database but not a filesystem.

| Type | Implements | Backing |
| ---- | ---------- | ------- |
| `TomSqlJobStore` | `TomJobStore` | one row per scheduled run in `tom_job_run` |
| `TomSqlLeaseLock` | `TomLeaseLock` | one row per resource in `tom_lease` |

Both are ordinary implementations of contracts defined in `tom_core_kernel`;
nothing in this module extends or narrows those contracts, and both are verified
against the kernel's own parameterised contract suite (see
`test/scheduling_db_test.dart`).

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

- a claim is `UPDATE ... WHERE id = :id AND state = 'pending'`;
- a first acquisition is `INSERT IGNORE`;
- a takeover is `UPDATE ... WHERE resource = :r AND token = :t AND version = :v`.

Reads exist only to nominate candidates; the write revalidates every condition
it relied on.

`TomSqlJobStore.claimDue` issues one conditional statement **per candidate**
rather than one for the batch, because `TomScheduler` always supplies a stateful
Dart `accept` predicate that cannot run inside SQL. Claiming the batch first and
releasing the rejects would briefly hide runs from peers that would have
accepted them, making contention depend on timing rather than on state. The
library comment in `sql_job_store.dart` records the reasoning in full.

## Schema

The DDL lives in `sql_scheduling_sql.dart` and is shipped as migration files
under `example/scheduling/migrations/`; `test/scheduling_schema_test.dart`
asserts the two have not drifted apart. Both stores can also create their table
on first use (`createSchema: true`, the default), which is what a test or a
single-service deployment wants; set it `false` when the migration module owns
the schema and the application's database user may not run DDL.

Two constraints carry the design:

- **`UNIQUE (job_name, scheduled_for)`** makes the scheduler's idempotence key —
  one run per job per window — a database invariant rather than a convention.
- **`tom_lease.version`**, incremented on every write, exists because MariaDB
  reports *changed* rows, not matched rows. Without it a renewal landing in the
  same clock instant with the same TTL would report zero affected rows, look
  like a lost lease, and fall through to takeover.

## Time

Instants are stored as UTC `DATETIME(6)` and carried through `String` columns.
The MariaDB driver materialises a `DATETIME` column with `DateTime.parse`, which
yields a *local* `DateTime`; since `DateTime.==` compares `isUtc` as well as the
instant, a UTC value would not compare equal to the value read back. A caller
that writes a local `DateTime` gets a UTC one back — the same instant,
differently labelled.
