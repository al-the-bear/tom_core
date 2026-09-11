# scheduling

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Durable job scheduling. A job pairs a schedule with a body; `TomScheduler` turns
the schedule into a stream of **windows** — the instants the job was supposed to
fire — and records each one in a store as a `TomJobRun`. A run is claimed,
dispatched, then completed or retried, and because the store outlives the
process, a restart resumes rather than forgets. A lease lock keeps one window on
one node when several are running.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomScheduler` | The engine: recovers interrupted runs, plans windows, claims, dispatches, records. |
| `TomJobDefinition` | A registered job — trigger, body, and the retry, timeout and overlap policy around both. |
| `TomJobBase` | What a declared job extends; gives the body the `TomJobRun` it is executing. |
| `TomScheduledJob` | Annotation that makes a class its own registration. |
| `TomScheduledJobs` | Scans the annotated classes and registers what it finds. |
| `TomScheduledJobException` | Raised when an annotated class cannot be turned into a `TomJobDefinition`. |

### Schedules — when a job fires

| Type | Responsibility |
| ---- | -------------- |
| `TomSchedule` | The trigger contract, reduced to the one question the scheduler asks: what is the next window after this instant? |
| `TomCronSchedule` | A standard five-field POSIX cron expression. |
| `TomCalendarSchedule` | Recurrences cron cannot express, such as the last Friday of the month. |
| `TomCalendarRule` | Which weekday-of-month rule a `TomCalendarSchedule` applies. |
| `TomIntervalSchedule` | A fixed period measured from an anchor instant. |
| `TomOnceSchedule` | A single absolute instant: fire once, then never again. |
| `TomEventSchedule` | A trigger fed by a source rather than a clock. |
| `TomScheduleException` | Thrown when a schedule expression cannot be parsed or is self-contradictory. |

### The store — what survives a restart

| Type | Responsibility |
| ---- | -------------- |
| `TomJobStore` | Durable storage for job runs; the queue the scheduler works from. |
| `TomMemoryJobStore` | Keeps everything in memory and nothing across restarts. For tests and single-shot processes. |
| `TomFileJobStore` | Keeps the queue in a JSON file that survives a restart. Several stores over one file share one queue: every operation holds a file mutex and re-reads the file, so a claim is atomic between processes and isolates. |
| `TomJobRun` | One attempt-carrying occurrence of a job: its window, attempt count, state and claim. |
| `TomJobRunState` | The lifecycle of a single `TomJobRun`. |
| `TomJobClaim` | A ticket proving one particular claim of a run was won — the fencing token a displaced node fails to present. |

### Running the body

| Type | Responsibility |
| ---- | -------------- |
| `TomJobDispatcher` | Where a job's work body is actually run. |
| `TomInlineJobDispatcher` | Runs bodies in the calling isolate. |
| `TomWorkerPoolJobDispatcher` | Runs bodies on an existing `TomWorkerPool`. |
| `TomRetryPolicy` | How a failed attempt is retried: attempts, backoff, ceiling. |
| `TomMissedWindowPolicy` | What a job does about windows that elapsed while the scheduler was down. |
| `TomPermanentFailure` | Marks an error as one retrying cannot fix, so the run stops rather than exhausting its attempts. |
| `TomPermanentJobFailure` | A ready-made `TomPermanentFailure` for bodies with no exception type of their own. |

### Cluster arbitration

| Type | Responsibility |
| ---- | -------------- |
| `TomLeaseLock` | A lease-based distributed lock, so one window runs on one node. |
| `TomMemoryLeaseLock` | Confined to one process. |
| `TomFileLeaseLock` | Coordinates separate processes through a shared file. |
| `TomLease` | A granted, time-bounded claim on a named resource. |
| `TomLeaseInfo` | What a lock currently knows about a resource — who holds it, and until when. |
| `TomOneShotResource` | A resource name that is never acquired again — the only kind `forget` accepts, so a recurring job name cannot have its fencing tokens reset by accident. |

### Observability

| Type | Responsibility |
| ---- | -------------- |
| `TomJobAlert` | A failure worth telling somebody about. |
| `TomJobAlertKind` | Why a `TomJobAlert` was raised. |
| `TomJobAlertSink` | Where alerts are delivered. |

## Quick start

Write the job as a class and say when it runs. The annotation *is* the
registration, so start-up carries nothing job-specific:

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

@tomReflector
@TomScheduledJob(
  cron: '0 3 * * *',
  retry: TomRetryPolicy(maxAttempts: 5),
  timeout: Duration(minutes: 30),
)
class NightlyReport extends TomJobBase {
  // The body works on `run.scheduledFor` — the window — not on "now". That is
  // what makes a catch-up run produce the report for the day it *missed*.
  @override
  Future<Object?> execute() async => 'report for ${run.scheduledFor}';
}

Future<void> main() async {
  final scheduler = TomScheduler(
    store: TomFileJobStore('var/jobs.json'),
    dispatcher: const TomInlineJobDispatcher(),
    ownerId: 'api-1',
  );

  TomScheduledJobs.registerAll(scheduler);
  await scheduler.start();
}
```

The guarantee is **at-least-once**, not exactly-once: a body that completed but
whose completion was not recorded runs again. Job bodies have to be idempotent —
see
[The Execution Guarantee](../../../../doc/scheduling/scheduling.md#the-execution-guarantee).

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
