/// The metrics module: instruments, the registry's snapshot, the Prometheus
/// text rendering, and the series the scheduler records.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

Matcher _refused(String key) =>
    throwsA(isA<TomMetricsException>().having((e) => e.key, 'key', key));

class _Ok extends TomCommand {
  @override
  Future<Object?> execute() async => 'ok';
}

class _Boom extends TomCommand {
  @override
  Future<Object?> execute() async => throw StateError('boom');
}

void main() {
  group('instruments', () {
    late TomMetricRegistry registry;
    setUp(() => registry = TomMetricRegistry());

    test('a counter totals per label set, whatever the label order', () {
      final c = registry.counter('requests', help: 'Requests.');
      c.add();
      c.add(2, {'a': '1', 'b': '2'});
      c.add(3, {'b': '2', 'a': '1'});
      expect(c.valueOf(), 1);
      expect(c.valueOf({'a': '1', 'b': '2'}), 5);
    });

    test('a counter refuses to go down', () {
      final c = registry.counter('requests', help: 'Requests.');
      expect(() => c.add(-1), _refused('metrics.counter.negative'));
    });

    test('a gauge holds the last value set', () {
      final g = registry.gauge('open', help: 'Open.');
      g.set(3);
      g.set(1);
      expect(g.valueOf(), 1);
      expect(g.valueOf({'x': 'y'}), isNull);
    });

    test('a histogram sorts observations into buckets', () {
      final h = registry.histogram('latency', help: 'L.', buckets: [1, 5]);
      for (final v in [0.5, 1, 3, 9]) {
        h.record(v);
      }
      final data = h.valueOf()!;
      expect(data.counts, [2, 1, 1]);
      expect(data.count, 4);
      expect(data.sum, 13.5);
    });

    test('time() records the duration of a body that throws too', () async {
      final h = registry.histogram('t', help: 'T.');
      await expectLater(
        h.time<void>(() async => throw StateError('x')),
        throwsStateError,
      );
      expect(h.valueOf()!.count, 1);
    });

    test('one name is one instrument; a second kind is refused', () {
      expect(
        identical(
          registry.counter('c', help: 'C.'),
          registry.counter('c', help: 'C.'),
        ),
        isTrue,
      );
      expect(
        () => registry.gauge('c', help: 'C.'),
        _refused('metrics.name.conflict'),
      );
      registry.histogram('h', help: 'H.', buckets: [1]);
      expect(
        () => registry.histogram('h', help: 'H.', buckets: [2]),
        _refused('metrics.name.conflict'),
      );
      expect(
        () => registry.observe('c', help: 'C.', observer: () => []),
        _refused('metrics.name.conflict'),
      );
    });

    test('invalid names and labels are refused by name', () {
      expect(
        () => registry.counter('bad-name', help: ''),
        _refused('metrics.name.invalid'),
      );
      expect(
        () => registry.counter('x_total', help: ''),
        _refused('metrics.name.invalid'),
      );
      expect(
        () => registry.counter('x', help: '').add(1, {'bad-label': 'v'}),
        _refused('metrics.label.invalid'),
      );
      expect(
        () => registry.counter('y', help: '').add(1, {'__reserved': 'v'}),
        _refused('metrics.label.invalid'),
      );
    });
  });

  group('collect', () {
    late TomMetricRegistry registry;
    setUp(() => registry = TomMetricRegistry());

    test('families and points come sorted', () async {
      registry.counter('zeta', help: 'Z.').add(1, {'k': 'b'});
      registry.counter('zeta', help: 'Z.').add(1, {'k': 'a'});
      registry.gauge('alpha', help: 'A.').set(1);
      final families = await registry.collect();
      expect(families.map((f) => f.name), ['alpha', 'zeta']);
      expect(families.last.points.map((p) => p.labels['k']), ['a', 'b']);
    });

    test('observations are read at collection and merged by name', () async {
      var open = 1;
      registry.observe(
        'pool_open',
        help: 'Open.',
        observer: () => [
          TomObservedValue(open, {'pool': 'a'}),
        ],
      );
      final second = registry.observe(
        'pool_open',
        help: 'Open.',
        observer: () async => [
          const TomObservedValue(7, {'pool': 'b'}),
          // A label set an earlier observation reported: the first one wins.
          const TomObservedValue(99, {'pool': 'a'}),
        ],
      );
      open = 4;
      var family = (await registry.collect()).single;
      expect(
        {for (final p in family.points) p.labels['pool']: p.value},
        {'a': 4, 'b': 7},
      );
      second.cancel();
      family = (await registry.collect()).single;
      expect(family.points.map((p) => p.labels['pool']), ['a']);
    });

    test('a failing or hanging observation is skipped and counted', () async {
      registry.observationTimeout = const Duration(milliseconds: 50);
      registry.observe(
        'broken',
        help: 'B.',
        observer: () => throw StateError('down'),
      );
      registry.observe(
        'hanging',
        help: 'H.',
        observer: () => Completer<List<TomObservedValue>>().future,
      );
      final families = {for (final f in await registry.collect()) f.name: f};
      expect(families['broken']!.points, isEmpty);
      expect(families['hanging']!.points, isEmpty);
      final failures = families['tom_metrics_observation_failures']!;
      expect(
        {for (final p in failures.points) p.labels['metric']: p.value},
        {'broken': 1, 'hanging': 1},
      );
    });

    test('reset clears values and restarts the start time', () async {
      var now = DateTime.utc(2026);
      final r = TomMetricRegistry(clock: () => now);
      r.counter('c', help: 'C.').add(5);
      now = DateTime.utc(2027);
      r.reset();
      expect(r.counter('c', help: 'C.').valueOf(), 0);
      expect(r.startTime, DateTime.utc(2027));
    });
  });

  group('Prometheus text', () {
    test('renders counters, gauges and histograms in format 0.0.4', () async {
      final registry = TomMetricRegistry();
      registry.counter('tom_http_requests', help: 'Requests\nserved.').add(3, {
        'route': '/a"b',
        'method': 'GET',
      });
      registry.gauge('tom_open', help: r'Open \ now.').set(2.5);
      final h = registry.histogram(
        'tom_latency_seconds',
        help: 'Latency.',
        buckets: [0.1, 1],
      );
      h.record(0.05);
      h.record(0.5);
      h.record(2);
      expect(
        tomPrometheusText(await registry.collect()),
        '# HELP tom_http_requests_total Requests\\nserved.\n'
        '# TYPE tom_http_requests_total counter\n'
        'tom_http_requests_total{method="GET",route="/a\\"b"} 3\n'
        '# HELP tom_latency_seconds Latency.\n'
        '# TYPE tom_latency_seconds histogram\n'
        'tom_latency_seconds_bucket{le="0.1"} 1\n'
        'tom_latency_seconds_bucket{le="1"} 2\n'
        'tom_latency_seconds_bucket{le="+Inf"} 3\n'
        'tom_latency_seconds_sum 2.55\n'
        'tom_latency_seconds_count 3\n'
        '# HELP tom_open Open \\\\ now.\n'
        '# TYPE tom_open gauge\n'
        'tom_open 2.5\n',
      );
    });
  });

  group('scheduler series', () {
    setUp(TomMetrics.registry.reset);

    TomJobRun due(String id, String job, DateTime at) =>
        TomJobRun(id: id, jobName: job, scheduledFor: at, runAt: at);

    test(
      'records start lag, outcome, duration, last success and backlog',
      () async {
        final now = DateTime.utc(2026, 3, 1, 12);
        final store = TomMemoryJobStore();
        final scheduler = TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          clock: () => now,
          tickInterval: const Duration(hours: 1),
          maxRunsPerTick: 2,
          onAlert: (_) {},
        );
        addTearDown(scheduler.close);
        for (final (name, body) in [
          ('metrics.ok', _Ok.new),
          ('metrics.boom', _Boom.new),
        ]) {
          scheduler.register(
            TomJobDefinition(
              name: name,
              schedule: const TomEventSchedule(Stream<Object?>.empty()),
              body: (_) => body(),
              retryPolicy: const TomRetryPolicy(maxAttempts: 2),
            ),
          );
        }
        final late = now.subtract(const Duration(seconds: 30));
        await store.enqueue(due('r1', 'metrics.ok', late));
        await store.enqueue(due('r2', 'metrics.boom', late));
        await store.enqueue(due('r3', 'metrics.ok', late));
        // A run of a job registered on no scheduler here is not this
        // scheduler's backlog.
        await store.enqueue(due('r4', 'someone.else', late));

        await scheduler.start();
        await scheduler.drain();

        final registry = TomMetrics.registry;
        final runs = registry.counter('tom_job_runs', help: '');
        expect(runs.valueOf({'job': 'metrics.ok', 'outcome': 'succeeded'}), 1);
        expect(runs.valueOf({'job': 'metrics.boom', 'outcome': 'retried'}), 1);
        final lag = registry
            .histogram(
              'tom_job_start_lag_seconds',
              help: '',
              buckets: tomLagBuckets,
            )
            .valueOf({'job': 'metrics.ok'})!;
        expect(lag.count, 1);
        expect(lag.sum, 30);
        expect(
          registry
              .histogram(
                'tom_job_run_duration_seconds',
                help: '',
                buckets: tomLagBuckets,
              )
              .valueOf({'job': 'metrics.ok'})!
              .count,
          1,
        );
        expect(
          registry
              .gauge('tom_job_last_success_timestamp_seconds', help: '')
              .valueOf({'job': 'metrics.ok'}),
          now.millisecondsSinceEpoch / 1000,
        );

        final families = {for (final f in await registry.collect()) f.name: f};
        final backlog = families['tom_job_backlog']!.points;
        expect(backlog.single.labels, {'job': 'metrics.ok'});
        expect(backlog.single.value, 1);
        expect(
          families['tom_job_backlog_age_seconds']!.points.single.value,
          30,
        );

        await scheduler.close();
        final after = {for (final f in await registry.collect()) f.name};
        expect(after, isNot(contains('tom_job_backlog')));
      },
    );
  });
}
