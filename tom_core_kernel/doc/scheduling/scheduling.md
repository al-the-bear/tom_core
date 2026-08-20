# Scheduling Module

The Scheduling module runs work on a schedule and keeps a durable record of every
occurrence. It answers three questions that an in-process `Timer` cannot: *what
should have run while the process was down*, *what happens when an attempt
fails*, and *which node in a cluster actually runs a given occurrence*.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [Runnable examples](#runnable-examples)
- [The Execution Guarantee](#the-execution-guarantee)
- [Schedules](#schedules)
- [Declaring a Job](#declaring-a-job)
- [Job Definitions](#job-definitions)
- [The Job Store](#the-job-store)
- [The Scheduler](#the-scheduler)
- [Missed Windows](#missed-windows)
- [Recovering an Interrupted Run](#recovering-an-interrupted-run)
- [Retries, Backoff and Timeouts](#retries-backoff-and-timeouts)
- [Running More Than One Node](#running-more-than-one-node)
- [Lease Locks](#lease-locks)
- [Observability](#observability)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

A **job** pairs a [schedule](#schedules) with a body. The **scheduler** turns the
schedule into a stream of **windows** — the instants the job was supposed to fire
— and records each one in a **store** as a `TomJobRun`. A run is claimed,
dispatched, and completed or retried; the store is what makes all of that survive
a restart.

| Type | Role |
| ---- | ---- |
| `TomSchedule` | When a job should fire. Cron, calendar, interval, once or event |
| `TomScheduledJob` | The annotation that makes a class its own registration |
| `TomJobBase` | What a declared job extends; gives the body its `TomJobRun` |
| `TomScheduledJobs` | Scans the annotated classes and registers what it finds |
| `TomJobDefinition` | A schedule plus a body, retry policy, timeout and overlap rule |
| `TomJobRun` | One attempt-carrying occurrence: window, next attempt, state, claim |
| `TomJobStore` | Durable queue of runs. Memory and file implementations ship here |
| `TomJobDispatcher` | Where a body executes: inline, or on an isolate pool |
| `TomScheduler` | The engine: recover, plan, claim, dispatch, record |
| `TomLeaseLock` | Cluster arbitration, so one window runs on one node |
| `TomJobAlert` | Everything worth telling an operator about |

## Quick Start

Write the job as a class and say when it runs:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

@tomReflector
@TomScheduledJob(
  cron: '0 3 * * *',
  retry: TomRetryPolicy(maxAttempts: 5),
  timeout: Duration(minutes: 30),
)
class NightlyReport extends TomJobBase {
  @override
  Future<Object?> execute() async => buildReportFor(run.scheduledFor);
}
```

Start-up then has nothing job-specific in it:

```dart
final scheduler = TomScheduler(
  store: TomFileJobStore('var/jobs.json'),
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: 'api-1',
);

TomScheduledJobs.registerAll(scheduler);
await scheduler.start();
```

The body knows the `TomJobRun` it is executing, so it can work on
`run.scheduledFor` — the window — rather than on "now". That distinction is what
makes a catch-up run produce the report for the day it *missed* rather than for
the day it happens to run.

See [Declaring a Job](#declaring-a-job) for the full annotation, and
[Job Definitions](#job-definitions) for the hand-written form, which stays
available for the jobs an annotation cannot express.

### Runnable examples

Everything in this guide is demonstrated, and asserted, in
[`example/samples/scheduling/`](../../example/samples/scheduling/). It needs no
database and no containers: an in-memory store, an in-memory lease lock and a
clock the examples move by hand, so every outcome is an equality rather than a
timing.

| File | What it shows |
| ---- | ------------- |
| [`01_memory_substrate_example.dart`](../../example/samples/scheduling/01_memory_substrate_example.dart) | One window from registration to a completed row; what a `TomJobRun` records; what the lease is taken on |
| [`02_declared_job_example.dart`](../../example/samples/scheduling/02_declared_job_example.dart) | `@TomScheduledJob` discovery, a malformed declaration failing the scan by name, and declared jobs coexisting with hand-written ones |
| [`03_schedule_kinds_example.dart`](../../example/samples/scheduling/03_schedule_kinds_example.dart) | What each schedule kind answers, an event job in motion, and every missed-window policy across one outage — including a one-shot deadline that survives it |
| [`04_execution_guarantee_example.dart`](../../example/samples/scheduling/04_execution_guarantee_example.dart) | The duplicate a retry produces, the two abandonment cases, and a fencing token making a displaced node harmless |

```bash
dart run --enable-asserts example/samples/scheduling/00_run_all_examples.dart
```

## The Execution Guarantee

**Read this before writing a job body.**

> **A job body may run more than once for the same window. It will not silently
> run zero times. Write bodies to be idempotent.**

That is *at-least-once*, and it is a deliberate choice rather than a limitation
that was left unfixed. At-most-once and at-least-once are the only two options,
and they fail in opposite directions:

- **At-most-once** would mean marking a run complete *before* executing it. A
  node that dies mid-run then leaves work that was silently never done — the
  nightly invoice run that produced no invoices and told nobody.
- **At-least-once** means marking a run complete *after* executing it. A node
  that dies mid-run leaves a run that another node will pick up, so the work
  happens — possibly twice.

For scheduled business work, silent omission is the worse failure, so the module
takes at-least-once and gives you the tools to make duplication harmless.

### What "idempotent" means here

Being idempotent is not usually hard, and `run.scheduledFor` is the key: it is
stable across every attempt and every node, which makes it a natural idempotence
key.

```dart
// Good: keyed on the window, so a second execution is a no-op.
await reports.upsert(key: run.scheduledFor, body: buildReport());

// Bad: appends unconditionally, so a retry duplicates the row.
await reports.insert(body: buildReport());
```

If the effect genuinely cannot be made idempotent — sending an email, charging a
card — record the effect against `run.scheduledFor` transactionally with
performing it, and check that record first.

### Where the duplicate comes from

With a `TomLeaseLock` configured, only one node holds a window at a time under
normal operation. A duplicate needs a node to be **paused longer than its lease
TTL** — a stop-the-world pause, a suspended VM, a wedged disk — so that its lease
lapses, a peer takes over, and the original then wakes up and finishes. The
scheduler detects this on its next heartbeat and stops the displaced node from
*recording* an outcome (see [`leaseLost`](#observability)), but by then the work
itself may already have happened twice.

Closing that last gap requires the protected resource to check the **fencing
token** — see [Lease Locks](#lease-locks). Against a token-checking resource the
effect is single-fire even under a pause. Against everything else, idempotence is
the contract.

## Schedules

A `TomSchedule` answers one question: `nextFireAfter(instant)`. Five
implementations ship, one of them with two constructors:

| Schedule | Fires |
| -------- | ----- |
| `TomCronSchedule('0 3 * * *')` | Standard five-field cron, with `@daily`-style macros |
| `TomCalendarSchedule.dayOfMonth(...)` | Calendar rules: the 15th, the last day, every quarter |
| `TomCalendarSchedule.weekdayOfMonth(...)` | The second Tuesday, the last Friday |
| `TomIntervalSchedule(Duration(minutes: 5))` | A fixed grid anchored at an instant |
| `TomOnceSchedule(DateTime.utc(2026, 8, 1, 9))` | Exactly once, at one absolute instant, then never again |
| `TomEventSchedule(stream)` | Not clock-driven at all — a stream enqueues the runs |

Three behaviours worth knowing:

- **Cron day fields are OR-ed**, per POSIX: with both day-of-month and
  day-of-week restricted, a day matching *either* fires. A step counts as a
  restriction — `*/2` names half the days — so `0 0 */2 * *` is odd days, and
  `0 0 */2 * MON` is odd days *or* Mondays. Only a bare `*`, or the equivalent
  `*/1`, leaves a day field unrestricted. Vixie cron differs here, reading
  every `*/n` as unrestricted and ANDing instead.
- **Intervals do not drift.** The grid is absolute, so a scheduler that was down
  for an hour resumes on the original grid rather than restarting from the
  moment it woke up.
- **A one-shot names an instant, not a wall-clock position.** The recurring
  schedules take their meaning from the zone of the instant they are asked
  about — "03:00" is 03:00 wherever you stand. `TomOnceSchedule` is the
  exception: it already knows the exact point in time, so the zone only decides
  how the answer is *rendered*, never which moment it means. Pass a local
  `DateTime` and you get that machine's reading of it; the schedule fires at the
  same absolute instant either way.
- **Across a DST boundary, cron and intervals move opposite ways.** Cron and
  calendar hold the wall clock, so a local `0 3 * * *` stays at 03:00 and the gap
  to the previous run becomes 23 or 25 hours. An interval holds the grid, so a
  24-hour period stays 24 real hours and its wall-clock time shifts by an hour.
  Pick by what the job actually needs — local 03:00 for a nightly report, 24 real
  hours for a token refresh — and ask in UTC when it must ignore civil time
  altogether.

`TomEventSchedule` inverts the direction: instead of the clock producing windows,
each event on the stream enqueues a run carrying its payload. Two events at the
same instant collapse into one run, since the window *is* the instant.

## Declaring a Job

**This is the recommended way to write a job.** A class annotated with
`@TomScheduledJob` *is* its own registration: there is no second place where the
job's name, schedule and policies are repeated, and therefore no way for the two
to drift apart. A job class cannot exist and be unregistered; a registration
cannot out-live the class it names; and a rename is just a rename.

```dart
@tomReflector
@TomScheduledJob(cron: '0 3 * * *')
class NightlyReconciliation extends TomJobBase {
  @override
  Future<Object?> execute() async => reconcile(run.scheduledFor);
}
```

`@tomReflector` is not optional. The reflection substrate exposes only
"every annotated class", with no by-annotation and no by-supertype query, so a
job that is not in the application's reflection build is not discoverable at
all.

### Declaring the Trigger

A `TomSchedule` is not a constant and so cannot be an annotation argument. The
trigger is declared instead by four **mutually exclusive** fields, of which
**exactly one** must be set:

| Field | Builds | Example |
| ----- | ------ | ------- |
| `cron:` | `TomCronSchedule` | `cron: '0 3 * * *'`, `cron: '@daily'` |
| `interval:` | `TomIntervalSchedule` | `interval: Duration(minutes: 15)` |
| `calendar:` | `TomCalendarSchedule` | `calendar: 'day:-1 at:23:30'` |
| `event: true` | `TomEventSchedule` | see [Event Jobs](#event-jobs) |

The remaining fields map one-to-one onto `TomJobDefinition`: `retry`, `timeout`,
`missedWindow`, `catchUpLimit`, `allowOverlap` and `requestsRecovery`, with the
same defaults. `requestsRecovery` is the one to think about deliberately — see
[Recovering an Interrupted Run](#recovering-an-interrupted-run).

`TomOnceSchedule` has no annotation field on purpose — a one-shot's instant is a
`DateTime`, which is not a constant either, and a "fire in three days" that
recomputed itself on every restart would never fire. Use a
[hand-written definition](#job-definitions) for that.

### Calendar Expressions

`calendar:` is a string because the calendar rules — the month-relative ones
cron cannot spell — need several values, and an annotation reads better with one
field than with seven. Terms are whitespace-separated `key:value` pairs:

| Term | Meaning | Default |
| ---- | ------- | ------- |
| `day:<n>` | day of month, `1`..`31`, or `-1`..`-31` counting from the month's end | — |
| `weekday:<ordinal>/<day>` | ordinal `1`..`5` or `last`; day `mon`..`sun` | — |
| `at:<HH:MM>` | time of day | `00:00` |
| `every:<months>` | month interval, `1`..`12` | `1` |
| `from:<month>` | the month `1`..`12` the interval is anchored on | `1` |

Exactly one of `day:` and `weekday:` selects the rule.

```dart
@TomScheduledJob(calendar: 'day:-1 at:23:30')        // month end, 23:30
@TomScheduledJob(calendar: 'weekday:2/tue at:09:00 every:3 from:2')
```

Parsing is strict: an unknown term, a repeated term or a malformed value is
rejected at scan rather than ignored, because a silently dropped `at:` would
move a month-end job to midnight and nothing would say so.

### The Name Is the Store Key

`name:` defaults to the class's simple name and stays overridable, and the
reason matters.

The name is what a `TomJobStore` keys runs by. Renaming the class of a job that
already has stored runs therefore **orphans its history**: the old rows stay
under the old name, and the job re-anchors as if it had never run — which, with
`TomMissedWindowPolicy.runAll`, can mean a burst of catch-up work nobody asked
for. Pin the old name when renaming a job that is already in production:

```dart
@TomScheduledJob(name: 'legacy-cleanup', interval: Duration(minutes: 15))
class ExpiredSessionCleanup extends TomJobBase { ... }
```

### Reaching Collaborators

A job body is instantiated per run by reflection, through the class's
**no-argument constructor**. There is no call site to pass collaborators from,
so resolve them — from the bean locator, in the constructor or in `execute`:

```dart
@tomReflector
@TomScheduledJob(cron: '@daily')
class ExpireSessions extends TomJobBase {
  final TomBean<SessionService> _sessions = TomBean<SessionService>();

  @override
  Future<Object?> execute() async =>
      _sessions.get().expireBefore(run.scheduledFor);
}
```

This is not a workaround for the annotation. It is the wiring every other
framework component uses, and it is the only form that survives dispatch to a
worker isolate, where a captured reference would not have.

Extending `TomJobBase` is what gives the body its `run`, and with it the window,
the attempt number and any event payload. A plain `TomCommand` with a
no-argument constructor is accepted too — it simply has no way to ask which
occurrence it is.

### Event Jobs

`event: true` declares the job event-triggered. A `Stream` is not a constant
either, so the source is supplied at scan time, keyed by job name:

```dart
TomScheduledJobs.registerAll(
  scheduler,
  eventSource: (name) => name == 'OnInvoiceIssued' ? invoices.stream : null,
);
```

A job declared `event: true` whose source does not resolve is a **scan failure**,
not a job that quietly never fires.

### What the Scan Checks

This is the point of the whole route, and it is worth being explicit about what
it buys. Quartz stores a job's class as a *string* and resolves it when the
trigger fires: a rename parks the trigger in `ERROR` permanently, and cluster
recovery silently skips a firing whose class no longer resolves. Here the class
is present at compile time, and every other way to get a declaration wrong is
reported **at start-up**, naming the offending class:

| Key | Raised when |
| --- | ----------- |
| `scheduled_job.no_schedule` | none of `cron:`/`interval:`/`calendar:`/`event:` is set |
| `scheduled_job.multiple_schedules` | more than one of them is set |
| `scheduled_job.invalid_cron` | the cron expression does not parse |
| `scheduled_job.invalid_calendar` | the calendar expression does not parse, or is out of range |
| `scheduled_job.invalid_interval` | the interval is not positive |
| `scheduled_job.invalid_policy` | `catchUpLimit` or `timeout` is out of range |
| `scheduled_job.not_a_command` | the class is not a `TomCommand` |
| `scheduled_job.not_constructible` | the class has no usable no-argument constructor |
| `scheduled_job.no_event_source` | `event: true` with no resolvable stream |
| `scheduled_job.duplicate_name` | two classes claim one job name |
| `scheduled_job.name_already_registered` | a discovered job would replace one already registered |

Every declaration is validated before any of them is registered, so a start-up
with one bad job registers *none* of them rather than half of them.

`TomScheduledJobs.discover()` returns the definitions instead of registering
them, and both it and `registerAll` take a `where:` predicate that narrows the
scan — which is how one binary can run different jobs in different deployment
profiles.

## Job Definitions

A `TomJobDefinition` is what [discovery](#declaring-a-job) produces, and writing
one by hand remains fully supported — it is the **escape hatch** for the jobs an
annotation cannot express: a schedule computed from configuration, a body that
must close over something, a `TomOnceSchedule` whose instant was loaded from a
database. Hand-written and discovered jobs coexist in one scheduler.

```dart
TomJobDefinition(
  name: 'reconcile',              // unique; also the lease resource
  schedule: TomIntervalSchedule(const Duration(minutes: 15)),
  body: (run) => ReconcileCommand(run.scheduledFor),
  retryPolicy: const TomRetryPolicy(maxAttempts: 4),
  timeout: const Duration(minutes: 10),
  missedWindowPolicy: TomMissedWindowPolicy.runOnce,
  catchUpLimit: 24,
  allowOverlap: false,
  requestsRecovery: false,        // may a partial execution be re-run?
)
```

`body` is a **factory**, not the work itself: it is called once per attempt and
returns a `TomCommand`. That is what lets the same job run on an isolate pool —
the command is the unit that crosses the isolate boundary.

## The Job Store

`TomJobStore` is the durable queue. The unit is the `TomJobRun`:

| Field | Meaning |
| ----- | ------- |
| `scheduledFor` | The **window** — the instant the job was supposed to fire. Stable across attempts and nodes, so it doubles as the idempotence key |
| `runAt` | When this run should next be *attempted*. Equal to `scheduledFor` for a first attempt, later for a backed-off retry |
| `attempt` | Which attempt is next or in flight, 1-based |
| `state` | `pending`, `running`, `succeeded`, `failed` |
| `claimedBy` / `claimedAt` | The node holding it, and when — the store's own lease |
| `startedAt` | When execution actually began, or `null` if it never did |

`startedAt` is not a duplicate of `claimedAt`. A run can be claimed and never
start — the node dies in the gap — and the two cases must be recovered
differently; see [Recovering an Interrupted Run](#recovering-an-interrupted-run).
The scheduler calls `markStarted` immediately before dispatching the body, so the
distinction is recorded where a *peer* can read it rather than being remembered
in the node that is about to disappear.

Two implementations ship here:

- **`TomMemoryJobStore`** — one process, nothing survives a restart. Right for
  tests and for jobs whose loss on restart is acceptable.
- **`TomFileJobStore`** — a JSON-lines file. Survives a restart; an in-flight run
  comes back as an *expired claim* rather than as lost work, so the scheduler
  recovers it on its next tick.

A third, **`TomSqlJobStore`**, ships in `tom_core_server` — the kernel has no
persistence layer, so the relational implementation belongs one layer up. It is
the production choice for a cluster; see
[Choosing a substrate](#choosing-a-substrate).

## The Scheduler

Every `tick()` does three things, in order:

1. **Recover** — return runs whose claim has outlived `leaseTimeout` to the
   queue, subject to the rule in
   [Recovering an Interrupted Run](#recovering-an-interrupted-run). This is how
   work survives the node that was doing it. Recovery does *not* charge the run
   an attempt: a scheduler crash is not the job's fault, and charging it would
   let a crash loop consume a job's retry budget.
2. **Plan** — walk each schedule forward and enqueue the windows now due,
   including any [missed](#missed-windows) while the process was down.
3. **Dispatch** — claim what is due, win the [lease](#lease-locks), and start it.

`tick()` is public and directly awaitable, which is what makes the whole engine
testable without waiting on wall-clock time. `start()` runs a pass immediately
and then every `tickInterval`; `stop()` halts the timer but leaves the scheduler
usable; `close()` releases held leases and refuses further registration.

Two settings shape the rhythm rather than the semantics, and both exist because
several nodes share one queue:

| Setting | Default | Why |
| ------- | ------- | --- |
| `maxCatchUpPerTick` | 20 | A pass enqueues at most this many catch-up windows across *all* jobs. A long outage otherwise produces a burst of backlog that starves the runs that are due now; the remainder is planned by the following ticks, so nothing is lost, only spread. |
| `tickJitter` | 0.1 | Each idle interval is shortened by up to this fraction, at random. N nodes started by the same deployment would otherwise wake in lockstep for the lifetime of the cluster and contend on every single tick. Jitter, not partitioning, is the answer — it costs nothing and needs no coordination. |

The jitter is downward-only, so a tick never happens *later* than
`tickInterval`: lateness is the property schedules care about.

Every constructor argument whose range matters is checked at construction, each
under its own `schedule.scheduler.*` code: `tickInterval`, `leaseTimeout` and
`leaseTtl` must be positive, `leaseRenewInterval` must be shorter than
`leaseTtl`, `maxRunsPerTick` and `maxCatchUpPerTick` must be at least 1, and
`tickJitter` must be in `[0, 1)`. Each of these values has a way of failing that
produces no error and no output — a zero dispatch budget claims nothing on every
pass while planning keeps filling the queue, a zero lease timeout abandons every
run the instant it is claimed — so the constructor is the last place the mistake
is still cheap to see.

Dispatch does **not** await the work it starts — a slow job must not hold up the
next window of a fast one — so completion, the store write and the lease release
all land in later turns of the event loop.

## Missed Windows

When a scheduler starts and finds windows in the past, `missedWindowPolicy`
decides:

| Policy | Behaviour |
| ------ | --------- |
| `skip` | Enqueue nothing; raise an alert with the count |
| `runOnce` | Enqueue only the most recent missed window |
| `runAll` | Enqueue every missed window, up to `catchUpLimit` |

A catch-up run is dated to the window it missed but is due *now*, so the body
still sees the right `scheduledFor`. Windows dropped because `catchUpLimit` bit
are alerted rather than silently discarded.

**First sight anchors on the present.** A newly registered job does not replay
its entire history — the scheduler has no record of it, so there is nothing to
catch up on.

**A planned window survives, whatever the policy says.** The policy governs
windows the schedule would *produce* after the last one on record; once a window
has been written to the store it is durable state and is simply late. This is
most visible with `TomOnceSchedule`: a deadline planned before an outage fires
when the process comes back, under `skip` as much as under `runAll`, and fires
exactly once — because from the instant onwards `nextFireAfter` answers `null`,
so there is no second window to plan.

**A job that can never run says so.** The two cases are a recurrence that cannot
match (`0 0 30 2 *` is February 30th) and a one-shot whose instant had already
passed when the job was *first* registered — the second is what a deadline
restored at start-up after a long outage looks like. Neither has a record to
measure "missed" against, so no missed-window policy applies; instead the
scheduler raises a `neverFires` alert carrying the schedule, once per job rather
than once per tick. Without it, a job that can never run would be
indistinguishable from one that is merely not due yet.

## Recovering an Interrupted Run

A claim that outlives `leaseTimeout` means its holder is gone. What to do with
the run depends on how far it got, and re-queueing everything is not safe by
default:

| The run | Recovered as | Because |
| ------- | ------------ | ------- |
| claimed, never started (`startedAt == null`) | back to `pending` | Nothing happened, so nothing can be repeated. No opt-in needed, ever. |
| started, and the job sets `requestsRecovery` | back to `pending` | The job has stated that re-running a partial execution is safe. |
| started, and the job does not | `failed`, with `TomJobStore.recoveryDeclinedError` | It may have sent the email, charged the card or written half the file. |

The default is the safe one: `requestsRecovery` is `false` unless a job asks.

```dart
@TomScheduledJob(name: 'rebuild-index', cron: '@hourly', requestsRecovery: true)
class RebuildIndexJob extends TomJobBase { … }
```

The declined case is *written off explicitly* rather than left in place, and
raises a `recoveryDeclined` alert. An operator reading the row must be able to
see why the run was not attempted again, not find a gap and have to reconstruct
it.

This is the distinction `startedAt` exists for, and it is also why `markStarted`
is a store operation rather than a field the node keeps: the decision is made by
a *surviving peer*, reading state the departed node wrote before it died.

## Retries, Backoff and Timeouts

`TomRetryPolicy` grows the wait exponentially from `initialBackoff` by
`multiplier`, bounded by `maxBackoff`, with `jitter` that only ever *lengthens*
the wait — so a fleet that failed together does not retry together. `maxAttempts`
counts the first attempt, so `TomRetryPolicy.none` (`maxAttempts: 1`) fails
without retrying. The default is three attempts, 30 s initial backoff, doubling,
capped at 30 min, with 10 % jitter.

`maxBackoff` bounds the delay **after** jitter, so the exponential curve
plateaus at `maxBackoff / (1 + jitter)` — 27 min 16 s under the default 30 min
ceiling — and jitter fills the gap up to it. Reserving that headroom rather than
capping the jittered value is what keeps the spread alive once every job has
saturated, which is the state a long outage leaves a fleet in and precisely the
pile-up jitter exists to prevent.

The fields have ranges — `maxAttempts >= 1`, `multiplier >= 1`, `jitter` in
`0..1`, a non-negative `initialBackoff` and a positive `maxBackoff` — and a
value outside them throws a `schedule.retry.*` `TomScheduleException`. The check
runs when a `TomJobDefinition` adopts the policy, not in the policy's own
constructor: that constructor must stay `const` so a policy can appear in a
`@TomScheduledJob(retry: …)` annotation, and a `const` constructor has no body to
throw from. The placement is also the honest one — an unattached policy governs
nothing, so the moment a bad value starts producing wrong answers is the moment a
job adopts it, and only then is there a job name to put in the message.

An attempt that overruns `timeout` is failed and retried like any other failure.
A **body factory that throws** is different: that is a permanent defect, not a
transient failure, so the run fails outright rather than retrying identically
four more times.

## Running More Than One Node

Point two schedulers at one shared store and both will try to claim the same due
run. Whether that is a problem depends on the store:

- A **`TomMemoryJobStore`** is not shared across processes at all.
- A **`TomFileJobStore`**'s claim is *not* atomic between processes — two nodes
  can both come away believing they claimed the same run.
- A **`TomSqlJobStore`**'s claim *is* atomic: it is a conditional `UPDATE` and
  the database picks the winner. The lock is still worth having — it is what
  enforces `allowOverlap` across nodes — but the store no longer needs it to
  make a claim mean something.

The `lock` is the arbiter that makes the answer uniform:

```dart
final lock = TomFileLeaseLock('var/locks');

final scheduler = TomScheduler(
  store: TomFileJobStore('var/jobs.json'),
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: Platform.localHostname,   // must differ per node
  lock: lock,
  leaseTtl: const Duration(minutes: 1),
);
```

**`ownerId` must be distinct per node.** It is what the lock uses to tell holders
apart; two nodes sharing one would each treat the other's lease as their own.

The dispatch path becomes: claim from the store → acquire the lease → run →
release. A node that claims but cannot win the lease **hands the claim straight
back**, so a peer can take it on its very next tick rather than waiting out a
store lease, and the run is *not* charged an attempt for losing a race.

With no `lock`, behaviour is exactly the single-node behaviour — the lock is
opt-in and costs nothing when absent.

### What the lease is taken on

The resource key *is* the policy:

| `allowOverlap` | Lease resource | Effect |
| -------------- | -------------- | ------ |
| `false` | `job:<name>` | The whole cluster runs at most one of this job at a time |
| `true` | `run:<id>` | Concurrent windows are fine; no single window runs twice |

## Lease Locks

A `TomLeaseLock` is a distributed lock with an expiry. The expiry is not
optional: a plain mutual-exclusion lock whose holder dies is held forever, so
every distributed lock is a lease. Three mechanisms manage the consequences:

- **TTL** — a lease lapses at `expiresAt` whether or not its holder is alive.
  This is what makes holder death self-healing.
- **Renewal** — a heartbeat pushes the expiry forward while the work runs, every
  `leaseRenewInterval` (a third of `leaseTtl` by default). This decouples the TTL
  from job duration: without it the TTL would have to exceed the slowest possible
  run, and a dead node would then block its work for exactly that long. With it,
  the TTL can be short *and* long jobs stay safe.
- **Fencing tokens** — `TomLease.token` strictly increases per resource across
  acquisitions. A protected resource that records the highest token it has seen
  and rejects anything lower will reject a stale holder's late write. This is the
  only mechanism that survives a pause longer than the TTL, and it is why the
  guarantee above distinguishes token-checking resources from everything else.

### Choosing a substrate

The rule: **the lock must live in the same failure domain as the job store it
guards.** A lock in a different store can be healthy while the queue is
unreachable, at which point a node holds a valid lease over work it cannot see
and no reconciliation exists.

| Store | Lock | Shared by | Use for |
| ----- | ---- | --------- | ------- |
| `TomMemoryJobStore` | `TomMemoryLeaseLock` | nothing — one process | tests, single-process work |
| `TomFileJobStore` | `TomFileLeaseLock` | a filesystem | one host, or nodes on a shared mount |
| `TomSqlJobStore` | `TomSqlLeaseLock` | a database | **a cluster — the production choice** |

**For a multi-node deployment, take the relational pair.** `TomSqlJobStore` and
`TomSqlLeaseLock` live in `tom_core_server` (documented in
`tom_core_server/doc/scheduling.md`) and are implementations of these same two
contracts — nothing here is extended or narrowed for them, and they are verified
against this package's own parameterised contract suite rather than against tests
written to fit them. Point both at the same `TomDataSource`:

```dart
final scheduler = TomScheduler(
  store: TomSqlJobStore.named('main', createSchema: false),
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: Platform.localHostname,   // must differ per node
  lock: TomSqlLeaseLock.named('main', createSchema: false),
  leaseTtl: const Duration(minutes: 1),
);
```

The relational pair also offers what only a cluster can use: an optional roll
call (`TomSqlSchedulerNodes`) that notices a departed *node* rather than only an
expired lease, so its work is recovered within a poll interval instead of a whole
lease timeout, and is attributed to the host that left. It is an accelerator —
the lease TTL remains the correctness floor either way. See
`tom_core_server/doc/scheduling.md`.

The file pair remains correct wherever every node mounts the same filesystem —
it is what the cross-process tests exercise — but most clusters do not have a
shared mount, and all of them have a database.

`TomFileLeaseLock` coordinates separate processes through a shared directory,
built on `File.createSync(exclusive: true)` — `O_EXCL`, an atomic test-and-set
shared by every process on the filesystem. Each resource owns a directory and
each acquisition creates a file named after its own fencing token, so taking over
a lapsed lease at token 3 means creating `4.lease` exclusively: every contender
computes the same next token and the kernel picks the one winner. Nothing is ever
briefly absent, so no late arrival can mistake a takeover in progress for a free
resource.

It assumes exclusive-create is atomic between the processes sharing the
filesystem. That holds locally and on a well-behaved network filesystem, but
network filesystems vary. Clocks are compared across nodes only through expiry
timestamps, so **`leaseTtl` must comfortably exceed the fleet's worst clock
skew**.

## Observability

Everything worth an operator's attention arrives as a `TomJobAlert` on
`onAlert`, which defaults to structured logging.

| Kind | Meaning | Default level |
| ---- | ------- | ------------- |
| `attemptFailed` | An attempt failed; `retryAt` says when the next one is | warn |
| `timedOut` | An attempt overran `timeout` | warn |
| `runFailed` | Every attempt is spent; the run is terminally failed | error |
| `runAbandoned` | A claim outlived `leaseTimeout` and was returned to the queue | error |
| `recoveryDeclined` | A run was interrupted mid-execution and *not* re-queued, because its job does not set `requestsRecovery` | error |
| `windowsMissed` | Windows the missed-window policy or `catchUpLimit` dropped | warn |
| `neverFires` | The job's schedule will never produce a window — `schedule` says which | warn |
| `lockContended` | A peer holds this job's lease; conceding | debug |
| `leaseStolen` | Took over from a holder that vanished — `lease` names it | warn |
| `leaseLost` | **Lost the lease mid-run.** Another node may now be executing it | error |

`lockContended` is debug on purpose: in a healthy cluster it fires once per job
per window for every node that did not win, and a warning that fires constantly
is a warning operators learn to ignore. `neverFires` is raised once per job per
scheduler for the same reason: the condition is re-detected on every planning
pass and cannot resolve itself, so repeating it would drown the channel.
Re-registering the job arms it again — a corrected registration that is still
wrong is news.

Three questions and where they are answered:

- **Who holds this resource, and until when?** `lock.inspect(resource)` returns a
  `TomLeaseInfo` without acquiring anything. `describe()` renders it for a log
  line or a diagnostics endpoint.
- **What is *this* node sitting on?** `scheduler.heldLeases`.
- **What happened to a run whose holder vanished?** `TomLeaseInfo` distinguishes
  a lease that was **released** (the node shut down cleanly — a scale-down) from
  one that merely **lapsed** (`holderVanished` — a node died mid-run). The run
  itself is recovered on the next tick and alerted as `runAbandoned`.

## Best Practices

- **Declare jobs with `@TomScheduledJob`.** A hand-written definition is a second
  place to keep in step with the class; reach for it only when the schedule or
  the body genuinely cannot be a constant.
- **Pin `name:` when renaming a job that is already running in production.** The
  name is the store key, and a rename without it orphans the job's history.
- **Write idempotent bodies keyed on `run.scheduledFor`.** This is the contract,
  not a precaution.
- **Give every node a distinct `ownerId`.** Sharing one silently disables the
  lock.
- **Size `leaseTtl` against clock skew, not against job duration.** Renewal
  handles duration; nothing handles skew.
- **Do not carry state between attempts in the body factory.** It is called fresh
  per attempt, and the attempt may land on another node.
- **Use `allowOverlap: false` unless concurrent windows are genuinely safe.** It
  is the cluster-wide reading of the flag, not merely a per-process one.
- **Treat `leaseLost` as an incident.** It means two nodes believed they owned
  the same run.
- **Set `requestsRecovery: true` only when a half-finished run really may be
  repeated.** The default declines, which is the safe answer; a job that sends,
  charges or ships should keep it. `recoveryDeclined` then tells an operator that
  a run needs a human, which is better than a silent re-run.
- **Prefer `tick()` in tests.** It is awaitable, which removes wall-clock waits
  from the suite entirely.

## Dependencies

| Dependency | Used for |
| ---------- | -------- |
| `little_things` | `TomException` base for `TomScheduleException` |
| `logging` | Default `onAlert` sink |
| `isolate_pooling` | `TomWorkerPoolJobDispatcher` |
| `shutdown_cleanup` | `TomClosable`, implemented by `TomScheduler` |
| `dart:io` | `TomFileJobStore` and `TomFileLeaseLock` only |
