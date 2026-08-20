# Tom Core Kernel API Reference: Scheduling Module

A persistent, cluster-safe job scheduler: schedules that compute fire times, a
store that survives a restart, a lease lock that keeps two nodes off the same
run, and a tick loop that plans, claims, dispatches and retries.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Schedules](#schedules)
  - [TomSchedule](#tomschedule)
  - [TomCronSchedule](#tomcronschedule)
  - [TomCalendarSchedule](#tomcalendarschedule)
  - [TomIntervalSchedule](#tomintervalschedule)
  - [TomOnceSchedule](#tomonceschedule)
  - [TomEventSchedule](#tomeventschedule)
- [Job definition](#job-definition)
  - [TomJobDefinition](#tomjobdefinition)
  - [TomRetryPolicy](#tomretrypolicy)
  - [TomJobDispatcher](#tomjobdispatcher)
  - [TomWorkerPoolJobDispatcher](#tomworkerpooljobdispatcher)
  - [TomInlineJobDispatcher](#tominlinejobdispatcher)
  - [TomJobAlert](#tomjobalert)
  - [TomPermanentJobFailure](#tompermanentjobfailure)
- [Declarative jobs](#declarative-jobs)
  - [TomJobBase](#tomjobbase)
  - [TomScheduledJob](#tomscheduledjob)
  - [TomScheduledJobs](#tomscheduledjobs)
- [The store](#the-store)
  - [TomJobRun](#tomjobrun)
  - [TomJobStore](#tomjobstore)
  - [TomMemoryJobStore](#tommemoryjobstore)
  - [TomFileJobStore](#tomfilejobstore)
- [The lease lock](#the-lease-lock)
  - [TomLease](#tomlease)
  - [TomLeaseInfo](#tomleaseinfo)
  - [TomLeaseLock](#tomleaselock)
  - [TomMemoryLeaseLock](#tommemoryleaselock)
  - [TomFileLeaseLock](#tomfileleaselock)
- [The scheduler](#the-scheduler)
  - [TomScheduler](#tomscheduler)
- [Enums](#enums)
- [Exceptions and mixins](#exceptions-and-mixins)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tombase/scheduling/schedule.dart`,
`job_definition.dart`, `scheduled_job.dart`, `job_store.dart`,
`lease_lock.dart`, `scheduler.dart`.

The module separates four concerns that are usually tangled together:

- **When** — a `TomSchedule` answers one question, `nextFireAfter`, and knows
  nothing about jobs. Cron, calendar, interval, one-shot, and stream-driven
  variants all implement it.
- **What** — a `TomJobDefinition` binds a name and a schedule to a
  `TomCommand` factory, plus the retry, timeout, overlap and catch-up policy.
  Jobs can be written by hand or declared with the `@TomScheduledJob`
  annotation and discovered through reflection.
- **State** — a `TomJobStore` holds `TomJobRun` rows: one row per *window*, which
  is what makes planning idempotent across restarts and across a cluster.
- **Exclusion** — a `TomLeaseLock` grants a time-limited, fenced (`token`-carrying)
  lease so exactly one node executes a given run.

`TomScheduler` composes them. A `tick()` recovers abandoned runs, plans the
windows each job is due for, claims what is due, acquires the lease, dispatches
through a `TomJobDispatcher` (inline or onto a worker pool), heartbeats the lease
while the work runs, and applies the retry policy on failure. Everything the
operator needs to know about arrives as a `TomJobAlert` on a `TomJobAlertSink`.

The delivery guarantee is **at-least-once**: a lease that lapses mid-execution is
visible (`TomJobAlertKind.leaseLost`) rather than silently tolerated. See
[`doc/scheduling/scheduling.md`](../scheduling/scheduling.md) for the narrative
treatment, including that window.

## Class Hierarchy

```
TomSchedule  (abstract)
    ├── TomCronSchedule
    ├── TomCalendarSchedule
    ├── TomIntervalSchedule
    ├── TomOnceSchedule
    └── TomEventSchedule

TomJobDispatcher  (abstract)
    ├── TomWorkerPoolJobDispatcher
    └── TomInlineJobDispatcher

TomJobStore  (abstract)
    └── TomMemoryJobStore  (implements TomJobStore)
            └── TomFileJobStore

TomLeaseLock  (abstract)
    ├── TomMemoryLeaseLock
    └── TomFileLeaseLock

TomJobBase  (abstract, extends TomCommand)

TomScheduler  (implements TomClosable)

TomException
    ├── TomScheduleException
    └── TomScheduledJobException

TomPermanentFailure  (mixin)
    └── TomPermanentJobFailure  (implements Exception)
```

## Schedules

### TomSchedule

The "when" contract. A schedule computes fire times and knows nothing about
jobs, runs, or the scheduler.

- **Extends:** abstract class.

#### Constructors

```dart
const TomSchedule()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isClockDriven` | `bool` | Whether fire times come from the clock (getter, default `true`); `false` for a schedule driven by an external stream. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | The first fire time strictly after `from`, or `null` if the schedule will never fire again. Answered in `from`'s zone; for the wall-clock kinds (cron, calendar) that zone also decides what the fields *mean*. |
| `describe` | `String describe()` | A short human-readable form, used in logs and alerts. |
| `toString` | `String toString()` | *(override)* Delegates to `describe`. |

### TomCronSchedule

A five-field cron expression (`minute hour day-of-month month day-of-week`),
with the usual `@hourly`/`@daily`/… macros and three-letter month and day names.
Parsing is eager: a malformed field throws `TomScheduleException` at
construction rather than at the first tick.

- **Extends:** `TomSchedule`

#### Constructors

```dart
factory TomCronSchedule(String expression)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `expression` | `String` | The expression as given. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | *(override)* Searches forward for a matching minute; returns `null` if none exists within the search horizon (e.g. February 30th). |
| `describe` | `String describe()` | *(override)* `cron(<expression>)`. |

### TomCalendarSchedule

Month-grid recurrences that cron cannot express: "the last day of the month",
"the third Tuesday", "every quarter". Negative `dayOfMonth` counts back from the
end; `ordinal` of `-1` means "the last" occurrence.

- **Extends:** `TomSchedule`

#### Constructors

```dart
factory TomCalendarSchedule.dayOfMonth(
  int dayOfMonth, {
  int hour = 0,
  int minute = 0,
  int monthInterval = 1,
  int anchorMonth = 1,
})

factory TomCalendarSchedule.weekdayOfMonth({
  required int weekday,
  required int ordinal,
  int hour = 0,
  int minute = 0,
  int monthInterval = 1,
  int anchorMonth = 1,
})
```

Both validate eagerly and throw `TomScheduleException` on an out-of-range value
(`dayOfMonth` `1..31` or `-1..-31`, `weekday` `DateTime.monday..DateTime.sunday`,
`ordinal` `1..5` or `-1`).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `rule` | `TomCalendarRule` | Which of the two forms this schedule uses, and therefore which fields below are set. The fields the rule does not use are `null`, never a stand-in value. |
| `dayOfMonth` | `int?` | Day of month; negative counts back from the month's end. `null` under `weekdayOfMonth`. |
| `weekday` | `int?` | `DateTime.monday`…`DateTime.sunday`. `null` under `dayOfMonth`. |
| `ordinal` | `int?` | Which occurrence of `weekday` in the month; `-1` for the last. `null` under `dayOfMonth`. |
| `monthInterval` | `int` | Fire every *n*-th month (1 = monthly, 3 = quarterly). |
| `anchorMonth` | `int` | The month the interval grid is aligned to. |
| `hour` | `int` | Fire hour. |
| `minute` | `int` | Fire minute. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | *(override)* Walks forward month by month within the search horizon. |
| `describe` | `String describe()` | *(override)* A readable rendering of the rule. |

### TomIntervalSchedule

Fires every `period`, on a grid aligned to `anchor` — so fire times are
reproducible across processes and machines rather than depending on when a
particular process happened to start.

- **Extends:** `TomSchedule`

#### Constructors

```dart
TomIntervalSchedule(Duration period, {DateTime? anchor})
```

`anchor` defaults to the Unix epoch. A non-positive `period` throws
`TomScheduleException`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `period` | `Duration` | The gap between consecutive fire times. |
| `anchor` | `DateTime` | The instant the grid is aligned to. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | *(override)* The next grid point after `from`. |
| `describe` | `String describe()` | *(override)* `interval(<period>)`. |

### TomOnceSchedule

Fires exactly once, at `at`, and never again.

- **Extends:** `TomSchedule`

#### Constructors

```dart
const TomOnceSchedule(DateTime at)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `at` | `DateTime` | The single fire instant. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | *(override)* `at` when it is still ahead, otherwise `null` — which is what raises `TomJobAlertKind.neverFires` for a deadline restored after its moment has passed. |
| `describe` | `String describe()` | *(override)* `once(<ISO-8601 UTC>)`. |

### TomEventSchedule

Not clock-driven at all: windows come from a `Stream`, so a job can be triggered
by something external while still getting the store, retry and lease machinery.

- **Extends:** `TomSchedule`

#### Constructors

```dart
const TomEventSchedule(Stream<Object?> events, {String sourceName = 'event'})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `events` | `Stream<Object?>` | The trigger stream; each element becomes a run's `payload`. |
| `sourceName` | `String` | A label for logs and alerts. |
| `isClockDriven` | `bool` | *(override)* Always `false`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nextFireAfter` | `DateTime? nextFireAfter(DateTime from)` | *(override)* Always `null` — there is no clock to consult. |
| `describe` | `String describe()` | *(override)* `event(<sourceName>)`. |

## Job definition

### TomJobDefinition

The "what": a named schedule plus the command factory to run, and the policy
around it.

#### Constructors

```dart
TomJobDefinition({
  required String name,
  required TomSchedule schedule,
  required TomCommand Function(TomJobRun run) body,
  TomRetryPolicy retryPolicy = const TomRetryPolicy(),
  Duration timeout = const Duration(minutes: 5),
  TomMissedWindowPolicy missedWindowPolicy = TomMissedWindowPolicy.runOnce,
  int catchUpLimit = 10,
  bool allowOverlap = false,
  bool requestsRecovery = false,
})
```

Validates eagerly, throwing `TomScheduleException` for an empty `name`, a
`catchUpLimit` below 1, or a non-positive `timeout`. It also calls
`retryPolicy.validate(name)`, so an out-of-range retry policy is rejected here
rather than at the constructor that built it — see `TomRetryPolicy.validate`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The job's unique name; also the store and lease key. |
| `schedule` | `TomSchedule` | When it fires. |
| `body` | `TomCommand Function(TomJobRun run)` | Builds the command for one run — a factory, not an instance, so each run gets a fresh command. |
| `retryPolicy` | `TomRetryPolicy` | Attempts and backoff. |
| `timeout` | `Duration` | Per-attempt time limit. |
| `missedWindowPolicy` | `TomMissedWindowPolicy` | What to do about windows that elapsed while nothing was running. |
| `catchUpLimit` | `int` | Upper bound on windows enqueued in one catch-up. |
| `allowOverlap` | `bool` | Whether a second run may start while one is still in flight. |
| `requestsRecovery` | `bool` | Whether a run interrupted mid-execution may be re-queued — opt-in, because re-running could repeat work already done. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Name and schedule description. |

### TomRetryPolicy

Exponential backoff with jitter.

#### Constructors

```dart
const TomRetryPolicy({
  int maxAttempts = 3,
  Duration initialBackoff = const Duration(seconds: 30),
  double multiplier = 2.0,
  Duration maxBackoff = const Duration(minutes: 30),
  double jitter = 0.1,
})
```

The constructor checks nothing, and has to stay that way: a policy appears as a
`@TomScheduledJob(retry: …)` argument, Dart requires annotation arguments to be
compile-time constants, and a `const` constructor has no body to throw from. The
ranges are enforced by `validate`, which `TomJobDefinition` calls — the point
every policy passes through on its way into a scheduler, and the only one where
a job name exists to name in the message.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `none` | `TomRetryPolicy` | One attempt; a failure is final. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxAttempts` | `int` | Total attempts, including the first. At least 1. |
| `initialBackoff` | `Duration` | Delay before attempt 2. Non-negative; zero retries at once. |
| `multiplier` | `double` | Growth factor per attempt. At least 1; exactly 1 is a constant delay. |
| `maxBackoff` | `Duration` | Ceiling on the delay, jitter included; the curve plateaus at `maxBackoff / (1 + jitter)`. Positive. |
| `jitter` | `double` | Random fraction added to each delay, so retries across a cluster spread out. `0`-`1`; `0` disables it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `allowsRetryAfter` | `bool allowsRetryAfter(int attempt)` | Whether another attempt is permitted after `attempt`. |
| `backoffFor` | `Duration backoffFor(int attempt, [Random? random])` | The delay before the given attempt, jitter applied, never above `maxBackoff`. Without a `Random`, the unjittered low end. |
| `validate` | `void validate(String job)` | Throws a `schedule.retry.*` `TomScheduleException` if a field is out of range, naming `job`. Called by `TomJobDefinition`. |
| `toString` | `String toString()` | *(override)* The policy's parameters. |

### TomJobDispatcher

How a job's command is executed. Separating this from the scheduler is what lets
the same job definition run inline in a test and on a worker pool in production.

- **Extends:** abstract class.

#### Constructors

```dart
const TomJobDispatcher()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `dispatch` | `Future<Object?> dispatch(TomCommand command)` | Executes the command and returns its result. |
| `close` | `void close()` | Releases dispatcher-owned resources; a no-op by default. |

### TomWorkerPoolJobDispatcher

Dispatches onto a `TomWorkerPool`, so job bodies run in worker isolates.

- **Extends:** `TomJobDispatcher`

#### Constructors

```dart
const TomWorkerPoolJobDispatcher(TomWorkerPool pool, {bool ownsPool = false})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `pool` | `TomWorkerPool` | The pool commands are executed on. |
| `ownsPool` | `bool` | Whether `close` should also close the pool. |

### TomInlineJobDispatcher

Executes the command directly in the calling isolate. The straightforward choice
for tests and single-process deployments.

- **Extends:** `TomJobDispatcher`

#### Constructors

```dart
const TomInlineJobDispatcher()
```

### TomJobAlert

A failure — or a cluster event — worth telling somebody about. Everything the
scheduler wants an operator to know arrives as one of these on the
`TomJobAlertSink`.

#### Constructors

```dart
const TomJobAlert({
  required String jobName,
  required TomJobAlertKind kind,
  TomJobRun? run,
  Object? error,
  StackTrace? stackTrace,
  DateTime? retryAt,
  int missedWindows = 0,
  TomSchedule? schedule,
  TomLease? lease,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `jobName` | `String` | The job the alert concerns. |
| `kind` | `TomJobAlertKind` | What happened. |
| `run` | `TomJobRun?` | The run involved, when there is one. |
| `error` | `Object?` | The failure, for the failure kinds. |
| `stackTrace` | `StackTrace?` | The accompanying stack trace. |
| `retryAt` | `DateTime?` | When the next attempt is due, for `attemptFailed`. |
| `missedWindows` | `int` | How many windows were skipped, for `windowsMissed`. |
| `schedule` | `TomSchedule?` | The schedule, for `neverFires`. |
| `lease` | `TomLease?` | The lease involved, for the lease kinds. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `describe` | `String describe()` | A one-line description suitable for a log line or notification body. |
| `toString` | `String toString()` | *(override)* Delegates to `describe`. |

### TomPermanentJobFailure

Thrown by a job body to say "do not retry this" — the retry policy is skipped and
the run fails terminally. Carries the `TomPermanentFailure` mixin, which is the
marker the scheduler actually tests for, so an application exception can opt in
by mixing it in rather than by wrapping.

- **Implements:** `Exception`, `TomPermanentFailure`

#### Constructors

```dart
const TomPermanentJobFailure(String message, {Object? cause})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `message` | `String` | Why the failure is permanent. |
| `cause` | `Object?` | The underlying error, if any. |

## Declarative jobs

### TomJobBase

The base class for an annotation-declared job. A job is a `TomCommand` — that is
what the dispatcher runs — with the run it was created for injected.

- **Extends:** `TomCommand` (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `run` | `TomJobRun` | The run this instance was built for. Assigned by `TomScheduledJobs` after construction and before `execute`; reading it on a hand-built instance throws (`late final`). |

### TomScheduledJob

The annotation that declares a class a scheduled job. It carries what
`TomJobDefinition` takes as constructor arguments, with one difference forced by
Dart: a `TomSchedule` is not a constant, so the trigger is declared by four
**mutually exclusive** fields — `cron`, `interval`, `calendar`, `event` — of
which exactly one must be set. Setting none, or two, is a scan-time error.

The class must also carry `@tomReflector`; a job absent from the reflection build
is not discoverable at all.

#### Constructors

```dart
const TomScheduledJob({
  String? name,
  String? cron,
  Duration? interval,
  String? calendar,
  bool event = false,
  TomRetryPolicy retry = const TomRetryPolicy(),
  Duration timeout = const Duration(minutes: 5),
  TomMissedWindowPolicy missedWindow = TomMissedWindowPolicy.runOnce,
  int catchUpLimit = 10,
  bool allowOverlap = false,
  bool requestsRecovery = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String?` | The job name; defaults to the class name. |
| `cron` | `String?` | A cron expression trigger. |
| `interval` | `Duration?` | A fixed-interval trigger. |
| `calendar` | `String?` | A calendar-rule trigger in textual form (e.g. last day of month, third Tuesday). |
| `event` | `bool` | Declares a stream-driven trigger; the stream is supplied at discovery time. |
| `retry`, `timeout`, `missedWindow`, `catchUpLimit`, `allowOverlap`, `requestsRecovery` | — | The `TomJobDefinition` policy fields, verbatim. |

### TomScheduledJobs

Turns `@TomScheduledJob`-annotated classes into registered jobs. A static-only
namespace; the constructor is private.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `discover` | `static List<TomJobDefinition> discover({Stream<Object?>? Function(String jobName)? eventSource, bool Function(ClassMirror candidate)? where})` | Scans the reflected classes and builds a definition per annotated job. `eventSource` supplies the stream for `event: true` jobs; `where` narrows the scan. Validation failures throw `TomScheduledJobException` at scan time. |
| `registerAll` | `static List<TomJobDefinition> registerAll(TomScheduler scheduler, {Stream<Object?>? Function(String jobName)? eventSource, bool Function(ClassMirror candidate)? where})` | Discovers, validates the whole scan, then registers. Refuses to overwrite a name the scheduler already knows. Returns what it registered. |

## The store

### TomJobRun

One row per *window* — which is what makes planning idempotent across restarts
and across a cluster.

- **Implements:** JSON round-trip via `toJson` / `TomJobRun.fromJson`.

#### Constructors

```dart
TomJobRun({
  required String id,
  required String jobName,
  required DateTime scheduledFor,
  required DateTime runAt,
  TomJobRunState state = TomJobRunState.pending,
  int attempt = 1,
  String? claimedBy,
  DateTime? claimedAt,
  DateTime? startedAt,
  String? lastError,
  DateTime? completedAt,
  Object? payload,
})

factory TomJobRun.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Unique run id. |
| `jobName` | `String` | The job this run belongs to. |
| `scheduledFor` | `DateTime` | The window this run *is* — the idempotence key together with `jobName`. |
| `runAt` | `DateTime` | When the run becomes due (moves out on a retry backoff). |
| `state` | `TomJobRunState` | `pending` / `running` / `succeeded` / `failed`. |
| `attempt` | `int` | 1-based attempt counter. |
| `claimedBy` | `String?` | The owner id that claimed the run. |
| `claimedAt` | `DateTime?` | When it was claimed — the basis for the abandonment check. |
| `startedAt` | `DateTime?` | When execution actually began; `null` means nothing has run yet. |
| `lastError` | `String?` | The most recent failure text. |
| `completedAt` | `DateTime?` | When the run reached a terminal state. |
| `payload` | `Object?` | The trigger payload, for event-driven runs. |
| `isFinished` | `bool` | Whether `state` is terminal (getter). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isDue` | `bool isDue(DateTime now)` | Whether this run is pending and `runAt` has arrived. |
| `toJson` | `Map<String, Object?> toJson()` | The persisted form. |
| `toString` | `String toString()` | *(override)* Id, job, window, state, attempt. |

### TomJobStore

The persistence contract. Its methods are the vocabulary of the tick loop.

- **Extends:** abstract class.

#### Static Members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `isRecoverable` | `static bool isRecoverable(TomJobRun run, bool Function(String jobName)? requestsRecovery)` | Whether an abandoned run may be re-queued: always, if it never started; otherwise only if its job opted in. |
| `recoveryDeclinedError` | `static const String` | The operator-facing text recorded against a run that was interrupted and deliberately not re-queued — a constant so it reads identically whichever store wrote it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `enqueue` | `Future<void> enqueue(TomJobRun run)` | Adds a run. Idempotence is the caller's job, via `findWindow`. |
| `findWindow` | `Future<TomJobRun?> findWindow(String jobName, DateTime scheduledFor)` | The existing run for a window, if it was already planned. |
| `lastWindow` | `Future<DateTime?> lastWindow(String jobName)` | The most recent window planned for a job — where catch-up resumes from. |
| `claimDue` | `Future<List<TomJobRun>> claimDue(DateTime now, String owner, {int limit = 16, bool Function(TomJobRun run)? accept})` | Atomically claims up to `limit` due runs for `owner`. |
| `release` | `Future<void> release(TomJobRun run)` | Hands a claimed run back to `pending` **without** charging an attempt — the voluntary counterpart of `recoverAbandoned`, so lease contention cannot drain a retry budget. |
| `markStarted` | `Future<void> markStarted(TomJobRun run, DateTime now)` | Records that execution began. |
| `renewClaim` | `Future<void> renewClaim(TomJobRun run, DateTime now)` | Heartbeats a claim so it is not judged abandoned. |
| `complete` | `Future<void> complete(TomJobRun run, DateTime now)` | Marks the run succeeded. |
| `fail` | `Future<void> fail(TomJobRun run, String error, DateTime now, {DateTime? retryAt})` | Records a failure; a `retryAt` schedules another attempt, its absence makes the failure terminal. |
| `recoverAbandoned` | `Future<List<TomJobRun>> recoverAbandoned(DateTime now, Duration leaseTimeout, {bool Function(String jobName)? requestsRecovery})` | Reclaims runs left `running` by a holder that vanished, without charging an attempt. Returns every run it changed, so the caller can alert on each. |
| `all` | `Future<List<TomJobRun>> all()` | Every held run, in insertion order — diagnostics and tests. |
| `purgeFinished` | `Future<int> purgeFinished(DateTime before)` | Deletes terminal runs completed before `before`; returns the count. |

### TomMemoryJobStore

An in-process store — the default for tests and single-process use.

- **Implements:** `TomJobStore`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `onMutated` | `void onMutated()` | Hook called after every mutation; the extension point `TomFileJobStore` persists from. |
| `snapshotSync` | `List<TomJobRun> snapshotSync()` | A synchronous copy of the held runs. |
| `replaceAll` | `void replaceAll(Iterable<TomJobRun> runs)` | Replaces the contents wholesale (used when loading). |

### TomFileJobStore

Adds durability by writing the whole store to a JSON file on every mutation, so
a restart resumes where it left off.

The write is atomic: the new queue is staged in a sibling `<path>.<pid>.tmp` and
renamed over the target. An interrupted write therefore leaves the previous
queue intact rather than a truncated file — which the loader, being deliberately
forgiving of corruption, would otherwise read back as an *empty* queue. The
process id in the staging name keeps two nodes on a shared mount from publishing
each other's partial writes; strays are ignored on load.

- **Extends:** `TomMemoryJobStore`

#### Constructors

```dart
TomFileJobStore(String path)
```

Loads any previously persisted runs at construction.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `file` | `File` | The backing file. |

## The lease lock

### TomLease

A granted, time-limited claim on a resource. The `token` is a **fence**: it
increases with every grant, so a holder that wakes up after its lease lapsed can
be told its claim is stale.

#### Constructors

```dart
const TomLease({
  required String resource,
  required String owner,
  required int token,
  required DateTime acquiredAt,
  required DateTime expiresAt,
})

factory TomLease.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resource` | `String` | What is locked. |
| `owner` | `String` | Who holds it. |
| `token` | `int` | Monotonic fencing token. |
| `acquiredAt` | `DateTime` | When it was granted. |
| `expiresAt` | `DateTime` | When it lapses unless renewed. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isExpiredAt` | `bool isExpiredAt(DateTime now)` | Whether the lease has lapsed at `now`. |
| `remainingAt` | `Duration remainingAt(DateTime now)` | Time left before expiry. |
| `toJson` | `Map<String, Object?> toJson()` | The persisted form. |
| `toString` | `String toString()` | *(override)* Resource, owner, token and expiry. |

### TomLeaseInfo

The answer to "what is the state of this resource" — which is more than
held/free, because a lease can lapse without ever being released.

#### Constructors

```dart
const TomLeaseInfo({
  required String resource,
  required TomLease? lease,
  required bool isHeld,
  bool wasReleased = false,
})

const TomLeaseInfo.free(String resource)
```

`lease` is required despite being nullable: "never held" has its own
constructor, `TomLeaseInfo.free`, so a null lease should be stated rather than
arrived at by leaving the argument out.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resource` | `String` | The inspected resource. |
| `lease` | `TomLease?` | The most recent lease, held or not. |
| `isHeld` | `bool` | Whether a live lease exists now. |
| `wasReleased` | `bool` | Whether the last lease ended by an explicit release. |
| `holderVanished` | `bool` | A lease exists, is no longer held, and was never released — i.e. the holder died (getter). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `describe` | `String describe()` | A readable summary. |
| `toString` | `String toString()` | *(override)* Delegates to `describe`. |

### TomLeaseLock

The mutual-exclusion contract.

- **Extends:** abstract class.

#### Constructors

```dart
const TomLeaseLock()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `acquire` | `Future<TomLease?> acquire(String resource, String owner, Duration ttl)` | Grants a lease, or returns `null` if a live one is held elsewhere. |
| `renew` | `Future<TomLease?> renew(TomLease lease, Duration ttl)` | Extends a still-valid lease; `null` when the lease is no longer ours. |
| `release` | `Future<void> release(TomLease lease)` | Gives the lease up early. |
| `inspect` | `Future<TomLeaseInfo> inspect(String resource)` | Reports the resource's state without acquiring. |
| `forget` | `Future<void> forget(String resource)` | Drops all record of the resource, fencing token included. |
| `close` | `void close()` | Releases lock-owned resources; a no-op by default. |

### TomMemoryLeaseLock

An in-process lock. Correct within one isolate; it excludes nothing across
processes, which is exactly what a single-node deployment needs and no more.

- **Extends:** `TomLeaseLock`

#### Constructors

```dart
TomMemoryLeaseLock({DateTime Function()? clock})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `clock` | `DateTime Function()` | Time source; injectable so expiry is testable without waiting. |

### TomFileLeaseLock

A cross-process lock built on exclusive file creation in a shared directory, with
the fencing token in the file name. Suitable for several processes on one host or
a shared filesystem.

- **Extends:** `TomLeaseLock`

#### Constructors

```dart
TomFileLeaseLock(String path, {DateTime Function()? clock})
```

Creates the directory if it is missing.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `directory` | `Directory` | Where lease records live. |
| `clock` | `DateTime Function()` | Time source. |

## The scheduler

### TomScheduler

Composes schedule, store, lock and dispatcher into a tick loop.

- **Implements:** `TomClosable`

#### Constructors

```dart
TomScheduler({
  required TomJobStore store,
  required TomJobDispatcher dispatcher,
  Duration tickInterval = const Duration(seconds: 30),
  Duration leaseTimeout = const Duration(minutes: 15),
  String? ownerId,
  DateTime Function()? clock,
  TomJobAlertSink? onAlert,
  Random? random,
  int maxRunsPerTick = 16,
  int maxCatchUpPerTick = 20,
  double tickJitter = 0.1,
  TomLeaseLock? lock,
  Duration leaseTtl = const Duration(minutes: 1),
  Duration? leaseRenewInterval,
})
```

`ownerId` defaults to a per-process unique string, `clock` to `DateTime.now`,
`onAlert` to a sink that logs at a severity matching the alert kind, and
`leaseRenewInterval` to a third of `leaseTtl`.

Every argument whose range matters is checked at construction, each throwing a
`TomScheduleException` under its own `schedule.scheduler.*` code:

| Condition | Code | Why it is an error |
| --------- | ---- | ------------------ |
| `tickInterval <= 0` | `tick_interval` | The timer chain re-arms on the next event-loop turn and spins against the store. Use `tick()` to drive passes by hand. |
| `leaseTimeout <= 0` | `lease_timeout` | Every run is abandoned the moment it is claimed, so nothing finishes. |
| `leaseTtl <= 0` | `lease_ttl` | A coordination lease expires as soon as it is acquired. |
| `leaseRenewInterval >= leaseTtl` | `renew_interval` | The lease lapses before its first renewal. |
| `maxRunsPerTick < 1` | `runs_per_tick` | No pass claims anything while planning keeps filling the queue. |
| `maxCatchUpPerTick < 1` | `catch_up_per_tick` | Catch-up never progresses. |
| `tickJitter` outside `[0, 1)` | `tick_jitter` | At 1 a tick could be scheduled for immediately. |

`leaseTtl` is checked before `leaseRenewInterval` so that a non-positive TTL is
reported as itself rather than as the renew-interval fault it also causes when
the interval is defaulted from it.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxCatchUpScan` | `int` | Hard ceiling (`100000`) on windows examined in one catch-up scan. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomJobStore` | Where runs live. |
| `dispatcher` | `TomJobDispatcher` | How commands are executed. |
| `tickInterval` | `Duration` | Nominal gap between passes. Positive. |
| `leaseTimeout` | `Duration` | After which a claim counts as abandoned. Positive. |
| `ownerId` | `String` | This scheduler's identity in the store and the lock. |
| `clock` | `DateTime Function()` | Injectable time source. |
| `onAlert` | `TomJobAlertSink` | Where alerts go. |
| `random` | `Random` | Jitter source. |
| `maxRunsPerTick` | `int` | Cap on runs dispatched per pass. At least 1. |
| `maxCatchUpPerTick` | `int` | Cap on catch-up windows enqueued per pass. At least 1. |
| `tickJitter` | `double` | Fraction each interval is randomly shortened by, so a cluster started together does not stay in lockstep. |
| `lock` | `TomLeaseLock?` | Cluster coordination; `null` for a single node. |
| `leaseTtl` | `Duration` | Lease lifetime. |
| `leaseRenewInterval` | `Duration` | Heartbeat period while work runs. |
| `jobs` | `Map<String, TomJobDefinition>` | Registered jobs, unmodifiable (getter). |
| `isRunning` | `bool` | Whether the periodic timer is armed (getter). |
| `inFlightCount` | `int` | Runs currently executing (getter). |
| `heldLeases` | `Map<String, TomLease>` | Leases this scheduler holds, unmodifiable (getter). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomJobDefinition job)` | Adds a job; subscribes its stream for an event schedule. |
| `deregister` | `void deregister(String name)` | Removes a job and cancels any subscription. |
| `start` | `Future<void> start()` | Runs one `tick` immediately — which is what recovers abandoned leases and catches up on restart — then repeats roughly every `tickInterval`. |
| `stop` | `void stop()` | Stops the timer; in-flight runs are left to finish. |
| `close` | `void close()` | *(override)* Shutdown: stops, cancels subscriptions, and releases held leases fire-and-forget so peers can take the work at once instead of waiting out `leaseTtl`. |
| `tick` | `Future<void> tick()` | One complete pass — recover, plan, claim, dispatch. Safe to call directly (this is what tests drive); overlapping calls are collapsed rather than re-entered. |

## Enums

### TomMissedWindowPolicy

What to do about windows that elapsed while nothing was running.

| Value | Meaning |
| ----- | ------- |
| `skip` | Forget them; only future windows run. |
| `runOnce` | Collapse them into a single catch-up run (the default). |
| `runAll` | Enqueue every missed window, up to `catchUpLimit`. |

### TomJobRunState

| Value | Meaning |
| ----- | ------- |
| `pending` | Planned, not yet claimed or awaiting a retry backoff. |
| `running` | Claimed and executing. |
| `succeeded` | Terminal success. |
| `failed` | Terminal failure. |

### TomCalendarRule

| Value | Meaning |
| ----- | ------- |
| `dayOfMonth` | Fire on a numbered day, counting from the start or the end of the month. |
| `weekdayOfMonth` | Fire on the *n*-th (or last) given weekday of the month. |

### TomJobAlertKind

| Value | Meaning |
| ----- | ------- |
| `attemptFailed` | An attempt failed and another will follow. |
| `timedOut` | An attempt exceeded the job's `timeout`. |
| `runFailed` | Every attempt is spent; the run is terminally failed. |
| `runAbandoned` | A run whose lease expired was returned to the queue — it *will* run again. |
| `recoveryDeclined` | A run interrupted mid-execution was **not** re-queued, because its job does not set `requestsRecovery`. It will *not* run again; if that work mattered, a human has to decide what to do. |
| `windowsMissed` | Windows were skipped by the missed-window policy. |
| `neverFires` | A registered job's schedule will never produce a window — an unmatched recurrence, or a `TomOnceSchedule` whose instant had already passed. Raised once per job per scheduler, not once per tick. |
| `lockContended` | A cluster peer held the lease, so this node did not run the work. Routine in a healthy cluster (logged at debug), but it is what distinguishes "every node is conceding" from "nobody scheduled it". |
| `leaseStolen` | This node took over a lease whose holder had let it expire. |
| `leaseLost` | A lease could not be renewed while its work was still running — another node may already be executing it, and the work in flight here cannot be recalled. The window in which at-least-once becomes visible. |

## Exceptions and mixins

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomScheduleException` | class | Schedule/definition/scheduler misconfiguration (extends `TomException`). Thrown eagerly at construction, never at tick time. |
| `TomScheduledJobException` | class | Annotation-scan failure — a job with no trigger, two triggers, a duplicate name (extends `TomException`). |
| `TomPermanentFailure` | mixin | Marker meaning "do not retry"; mix into an application exception to opt out of the retry policy. |

## Global Functions and Constants

| Name | Kind | Description |
| ---- | ---- | ----------- |
| `TomJobAlertSink` | typedef | `void Function(TomJobAlert alert)` — where the scheduler reports. |
