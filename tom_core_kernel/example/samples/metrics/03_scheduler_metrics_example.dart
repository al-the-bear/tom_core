/// Example: the series [TomScheduler] records into [TomMetrics.registry]
///
/// - `tom_job_backlog` / `tom_job_backlog_age_seconds` — observed from
///   `TomJobStore.backlog` between `start()` and `close()`
/// - `tom_job_start_lag_seconds` — how late a run started
/// - `tom_job_runs` — attempts ended, by `outcome`
/// - `tom_job_last_success_timestamp_seconds` — the last success on this node
///
/// A hand-moved clock makes every value an equality: the run is due at 10:00,
/// the scheduler's next pass happens at 10:00:30, so the start lag is exactly
/// thirty seconds — and before that pass, the backlog says so.
///
/// The framework records into the process registry, so this example reads
/// [TomMetrics.registry] and resets it first; the other two examples use a
/// registry of their own.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/metrics/03_scheduler_metrics_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// A job body that succeeds.
class RollupCommand extends TomCommand {
  @override
  Future<Object?> execute() async => 'rolled up';
}

/// A job body that fails.
class FailingCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw StateError('upstream unavailable');
}

/// The value of the series [name] with [labels] in [families], or `null`.
double? seriesValue(
  List<TomMetricFamily> families,
  String name,
  Map<String, String> labels,
) {
  for (final family in families.where((f) => f.name == name)) {
    for (final point in family.points) {
      final matches = labels.entries.every(
        (e) => point.labels[e.key] == e.value,
      );
      if (matches && point.labels.length == labels.length) {
        return point.histogram?.sum ?? point.value;
      }
    }
  }
  return null;
}

/// Lets the runs a `tick()` started finish.
Future<void> settle() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>(() {});
  }
}

/// Runs the scheduler-metrics demonstrations.
Future<void> run() async {
  print('=== 03: Scheduler Metrics Example ===\n');

  final registry = TomMetrics.registry..reset();
  var now = DateTime.utc(2026, 3, 2, 9);
  final store = TomMemoryJobStore();
  final scheduler = TomScheduler(
    store: store,
    dispatcher: const TomInlineJobDispatcher(),
    clock: () => now,
    ownerId: 'node-a',
    tickJitter: 0,
    onAlert: (_) {},
  );
  scheduler
    ..register(
      TomJobDefinition(
        name: 'hourly-rollup',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (_) => RollupCommand(),
      ),
    )
    ..register(
      TomJobDefinition(
        name: 'hourly-sync',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        retryPolicy: const TomRetryPolicy(maxAttempts: 2),
        body: (_) => FailingCommand(),
      ),
    );

  // ---------------------------------------------------------------------------
  // Example 1: the backlog gauges see a run nobody has started
  // ---------------------------------------------------------------------------
  print('1. A due, unclaimed run shows in the backlog:');

  // start() runs a first pass, which plans the 10:00 windows, and registers
  // the backlog observations.
  await scheduler.start();
  final atNine = await registry.collect();
  now = DateTime.utc(2026, 3, 2, 10, 0, 30);
  final late = await registry.collect();
  final backlog = seriesValue(late, 'tom_job_backlog', {
    'job': 'hourly-rollup',
  });
  final age = seriesValue(late, 'tom_job_backlog_age_seconds', {
    'job': 'hourly-rollup',
  });

  print(
    '   - at 09:00, backlog:       '
    '${seriesValue(atNine, 'tom_job_backlog', {'job': 'hourly-rollup'})}',
  );
  print('   - at 10:00:30, backlog:    $backlog');
  print('   - at 10:00:30, oldest age: ${age}s\n');

  // ---------------------------------------------------------------------------
  // Example 2: the pass records lag, outcomes and the last success
  // ---------------------------------------------------------------------------
  print('2. The pass that runs them records what happened:');

  await scheduler.tick();
  await settle();
  final after = await registry.collect();
  final lag = registry
      .histogram('tom_job_start_lag_seconds', help: '', buckets: tomLagBuckets)
      .valueOf({'job': 'hourly-rollup'})!;
  final succeeded = seriesValue(after, 'tom_job_runs', {
    'job': 'hourly-rollup',
    'outcome': 'succeeded',
  });
  final retried = seriesValue(after, 'tom_job_runs', {
    'job': 'hourly-sync',
    'outcome': 'retried',
  });
  final lastSuccess = seriesValue(
    after,
    'tom_job_last_success_timestamp_seconds',
    {'job': 'hourly-rollup'},
  );
  final drained = seriesValue(after, 'tom_job_backlog', {
    'job': 'hourly-rollup',
  });

  print('   - start lag recorded:      ${lag.sum}s (${lag.count} run)');
  print('   - hourly-rollup succeeded: $succeeded');
  print('   - hourly-sync retried:     $retried');
  print(
    '   - last success:            '
    '${DateTime.fromMillisecondsSinceEpoch((lastSuccess! * 1000).round(), isUtc: true)}',
  );
  print('   - backlog after the pass:  $drained\n');

  // ---------------------------------------------------------------------------
  // Example 3: close() takes the backlog gauges away
  // ---------------------------------------------------------------------------
  print('3. Closing the scheduler cancels its backlog observations:');

  await scheduler.close();
  final closed = await registry.collect();
  final stillObserved = closed.any((f) => f.name == 'tom_job_backlog');
  final runsKept = closed.any((f) => f.name == 'tom_job_runs');

  print('   - tom_job_backlog reported: $stillObserved');
  print('   - tom_job_runs kept:        $runsKept\n');

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  // Example 1
  assert(
    seriesValue(atNine, 'tom_job_backlog', {'job': 'hourly-rollup'}) == null,
    'At 09:00 the planned 10:00 run is not yet due, so it is no backlog',
  );
  assert(backlog == 1, 'At 10:00:30 the 10:00 run is due and unclaimed');
  assert(age == 30, 'And it has been due for thirty seconds');

  // Example 2
  assert(lag.count == 1 && lag.sum == 30, 'It started thirty seconds late');
  assert(
    lag.counts[tomLagBuckets.indexOf(30)] == 1,
    'Thirty seconds falls into the le="30" bucket',
  );
  assert(succeeded == 1, 'One attempt of hourly-rollup ended succeeded');
  assert(
    retried == 1,
    'hourly-sync failed with an attempt left, so its outcome is retried',
  );
  assert(
    seriesValue(after, 'tom_job_runs', {
          'job': 'hourly-sync',
          'outcome': 'failed',
        }) ==
        null,
    'Not failed: that outcome is for a run with no attempt left',
  );
  assert(
    lastSuccess ==
        DateTime.utc(2026, 3, 2, 10, 0, 30).millisecondsSinceEpoch / 1000,
    'The last success is stamped with the scheduler clock, in epoch seconds',
  );
  assert(drained == null, 'The run was claimed, so the backlog has drained');

  // Example 3
  assert(!stillObserved, 'A closed scheduler reports no backlog');
  assert(runsKept, 'The recorded series outlive the scheduler');

  registry.reset();
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
