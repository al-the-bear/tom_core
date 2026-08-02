# The two-node cluster demonstration

`example/scheduling/scheduling_example.dart` says in its own header that the
interesting behaviour of `TomSqlJobStore` and `TomSqlLeaseLock` "is *arbitrated
by the database* and so cannot be shown without one". This directory is the part
that needs one.

Four claims are made here, and none of them can be observed inside a single
process — each is a statement about what two nodes do to *each other* through a
shared database:

| # | Claim | Why one process cannot show it |
| - | ----- | ------------------------------ |
| 1 | **Single fire.** One schedule, two nodes, N windows — N executions in total, not 2N. | With one node there is nothing to arbitrate. |
| 2 | **The fencing token.** A node that reacquires after a pause carries a higher token, and a write stamped with the older one is refused. | The stale token has to come from a *different* node's lease. |
| 3 | **Takeover.** A node dies mid-run; its work returns to the queue when the lease expires, and not before. | A process cannot recover the run it is still holding. |
| 4 | **The roll call.** A node stops checking in and is named failed — from one row per node, rewritten rather than appended. | A process cannot conclude its own death, and `failedNodes` excludes the caller by design. |

## Running it

```bash
cd tom_ai/core/tom_core_server
./example/scheduling/cluster/run_cluster_demo.sh
```

Requirements: `docker` (with compose v2) and the Dart SDK on `PATH`. Host port
`3309` must be free, or point the `TOM_CORE_SERVER_TEST_DB_*` variables
elsewhere — the same variables the `db`-tagged test suite reads, so a developer
who has already pointed the suite at a database does not have to point this
separately.

The script brings MariaDB up from a **fresh volume**, applies the shipped
scheduler migrations, runs the four scenarios as pairs of real processes, asks
the verifier for a judgement, and tears everything down. It exits non-zero if
any claim fails, and prints every node's testimony when it does.

## The three programs

| File | Role |
| ---- | ---- |
| `cluster_provision.dart` | Drops and re-migrates the schema from `example/scheduling/migrations/`, then seeds the one extra table the fencing scenario contends for. |
| `cluster_node.dart` | One node. Started twice per scenario with a different `--node` and `--scenario`; reports what it observed as JSON lines on stdout. |
| `cluster_verify.dart` | The judge. Reads every node's log *and* the database, and turns the pair into the four assertions. |
| `cluster_support.dart` | Connection coordinates, the fenced-resource table, and the event record the halves communicate through. |
| `cluster_reflection.dart` | The reflection root for the demo's own row type — `executeQuery<T>` resolves `T` through the reflector, so a demo without a generated root throws at its first query. Regenerate with `./reflection_generation.sh`. |

**A node never asserts anything about the cluster.** It cannot: each one sees
only its own half. Keeping the judgement in a third process is what makes this a
demonstration that is also an assertion — a node cannot report success for
behaviour it did not observe.

**The verifier reads both sources on purpose.** A node's log is its own
testimony ("I invoked the body for this window", "my write was refused"); the
database is the shared fact. Either alone misses the interesting failures: two
nodes each believing they ran a window is invisible to the database, which holds
one row either way, and a row marked `succeeded` proves nothing about how many
times a body actually ran.

## What each scenario is shaped around

**Claim 1** runs a real `TomScheduler` on both nodes against the same job and
interval, with no jitter — the stampede is the experiment. The job body is
*slower than the schedule's interval*, which is load-bearing: two mechanisms
keep the total honest, and only one of them is exercised by a fast body.

- The unique key on `(job_name, scheduled_for)` makes a **window** a single row,
  so two nodes reaching for it produce one claim and one refusal.
- The coordination lease on `job:<name>` makes the **job** single-flight across
  the cluster, which the row cannot do — a second window is a second row, and
  nothing about that row knows the first is still running.

With a fast body the row answers every question and the lease sits untested
behind it. With a slow one the next window falls due mid-execution, the peer
claims that row, finds the lease held, and hands the claim back — which the
scheduler reports as a `lockContended` alert. The claim count is taken from
**body invocations**, never from rows.

**Claim 2** uses a node that *stalls* rather than one that dies. A killed node
can do no harm; the dangerous one is merely stopped — descheduled, in a long GC
pause, blocked on a socket that has not timed out — and wakes up still holding
an object it believes is a valid lease. Both of its post-stall operations are
refused by the database without needing its cooperation, which is the point,
because a node in that state cannot be relied on to cooperate.

**Claim 3** uses `kill -9`, not `kill`: a node given the chance to clean up
releases its lease and hands its run back, which is an orderly shutdown and an
easier story. The survivor is started *alongside* the victim so it is already
warm when the kill lands and its first recovery attempt falls inside the lease —
a survivor booted afterwards spends the lease compiling and can only report that
recovery had already happened. Its store is built **without** a roll call, so
the lease timeout is the only signal and "not before" is a statement about the
lease rather than about whichever mechanism happened to notice first.

**Claim 4** uses fresh node ids (`roll-a` / `roll-b`), because the roll-call
table outlives the phase that wrote to it and `node-a` has been dead since the
takeover. The quitter leaves *without* calling `forget`: a node that tidies up
on the way out proves nothing, and the roll call exists for the one that does
not get the chance.

## Verifying that the demonstration can fail

A green run is worth only as much as the red run it can produce. Each claim was
falsified before being trusted — the behaviour was broken on purpose, and the
script was confirmed to exit non-zero on **exactly** that claim, leaving the
other three passing. The unmutated run is 30 checks, all passing.

| Claim | Mutation | Observed |
| ----- | -------- | -------- |
| 1 | Remove `lock:` from the steady scheduler | 28/30 — the job-wide lease is never consulted, so there is no `lockContended` alert and no refused-then-executed window. The per-window counts still pass: the queue row alone keeps them honest, which is precisely why the lease needs its own checks. |
| 2 | Drop `AND fence <= :token` from the fenced write | 28/30 — the stalled node's late write is accepted, and the resource ends up carrying `holder=node-a fence=1` instead of the successor's `node-b fence=2`. |
| 3 | Pass `Duration.zero` as the survivor's lease timeout to `recoverAbandoned`, leaving the *reported* timeout honest | 28/30 — the run comes back 241 ms into a 5000 ms lease, failing both "nothing was recovered while the lease was still live" and "recovered only after the lease expired". Mutating the reported value too would have been the weaker experiment: it moves the goalposts rather than breaking the behaviour. |
| 4 | Have the quitter call `roll.forget` before leaving | the watcher waits out its patience and exits non-zero, so the runner fails the phase before the verifier is reached — a broken *experiment* rather than a disproved claim, and reported as one. |
