/// Metrics: counters, gauges and histograms recorded in process and read as a
/// snapshot.
///
/// The framework records its own series here — the scheduler its job runs, the
/// server its requests, statements, connection pools, caches and rate-limit
/// refusals — and an application adds its own through the same
/// [TomMetricRegistry]. What reads them is not this module's concern: the
/// snapshot [TomMetricRegistry.collect] answers is rendered as Prometheus text
/// by [tomPrometheusText] and exported over OTLP by `tom_core_server`, and both
/// read the same instruments, so a series exists once however it leaves the
/// process.
///
/// ## Instruments
///
/// | Instrument | Records | Read as |
/// | ---------- | ------- | ------- |
/// | [TomCounter] | a total that only grows | `<name>_total` |
/// | [TomGauge] | a value set when it changes | the value |
/// | [TomHistogram] | observations into fixed buckets | `_bucket`, `_sum`, `_count` |
/// | [TomMetricRegistry.observe] | a gauge computed when the snapshot is taken | the value |
///
/// A series is an instrument plus one set of label values. Labels name a
/// bounded dimension — a route pattern, a job name, a data source — never an
/// unbounded one such as a user id or a raw URL: every distinct label set is a
/// series held for the life of the process.
///
/// ## Per isolate
///
/// A registry is ordinary memory, so each isolate has its own. The framework
/// records on the isolate that serves requests and runs the scheduler; work
/// done in a worker isolate is measured where its result comes back.
library;

import 'dart:async';

import '../little_things/exception_base.dart';
import 'package:tom_basics/tom_basics.dart';

/// A misuse of the metrics API: an invalid name, a name registered as two
/// kinds, a negative counter increment.
class TomMetricsException extends TomException {
  /// Creates the exception; see [TomException] for the fields.
  TomMetricsException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// What an instrument measures, and so how its points are read.
enum TomMetricKind {
  /// A monotonically increasing total.
  counter,

  /// A value that goes up and down.
  gauge,

  /// A distribution of observations in fixed buckets.
  histogram,
}

/// The bucket bounds, in seconds, for latencies measured in milliseconds to
/// seconds: an HTTP request, an SQL statement, a pool acquire.
const List<double> tomLatencyBuckets = [
  0.005,
  0.01,
  0.025,
  0.05,
  0.1,
  0.25,
  0.5,
  1,
  2.5,
  5,
  10,
];

/// The bucket bounds, in seconds, for delays measured in seconds to an hour:
/// how late a job started, how long a job ran.
const List<double> tomLagBuckets = [0.1, 0.5, 1, 5, 15, 30, 60, 300, 900, 3600];

final RegExp _metricName = RegExp(r'^[a-zA-Z_:][a-zA-Z0-9_:]*$');
final RegExp _labelName = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// The key a label set is stored under: its pairs sorted by name, so two maps
/// with the same entries in a different order are one series.
String _seriesKey(Map<String, String> labels) {
  if (labels.isEmpty) return '';
  final names = labels.keys.toList()..sort();
  return names.map((n) => '$n\u0000${labels[n]}').join('\u0001');
}

/// One instrument of a [TomMetricRegistry]; see the subclasses.
sealed class TomMetric {
  TomMetric._(this.name, this.help, this.unit);

  /// The series name, without the `_total` a counter is read with.
  final String name;

  /// What the series measures, one line.
  final String help;

  /// The unit, as UCUM (`s`, `By`, `1`), or empty. The name carries it too —
  /// `_seconds`, `_bytes` — because that is what a Prometheus reader sees.
  final String unit;

  /// What kind of instrument this is.
  TomMetricKind get kind;

  final Map<String, Map<String, String>> _labelsByKey = {};

  String _keyOf(Map<String, String> labels) {
    final key = _seriesKey(labels);
    if (!_labelsByKey.containsKey(key)) {
      for (final label in labels.keys) {
        if (!_labelName.hasMatch(label) || label.startsWith('__')) {
          throw TomMetricsException(
            'metrics.label.invalid',
            "The label '$label' of '$name' is not a valid label name.",
            parameters: {'metric': name, 'label': label},
          );
        }
      }
      _labelsByKey[key] = Map.unmodifiable(labels);
    }
    return key;
  }

  List<TomMetricPoint> _points();

  void _clear();
}

/// A total that only grows: requests served, statements failed, runs ended.
class TomCounter extends TomMetric {
  TomCounter._(super.name, super.help, super.unit) : super._();

  final Map<String, double> _values = {};

  @override
  TomMetricKind get kind => TomMetricKind.counter;

  /// Adds [value] (one unless given) to the series [labels] names.
  ///
  /// Throws `metrics.counter.negative` for a negative [value]: a counter that
  /// went down would read as a process restart to every rate computed from it.
  void add([num value = 1, Map<String, String> labels = const {}]) {
    if (value < 0) {
      throw TomMetricsException(
        'metrics.counter.negative',
        "The counter '$name' only grows; it was given $value.",
        parameters: {'metric': name, 'value': value},
      );
    }
    final key = _keyOf(labels);
    _values[key] = (_values[key] ?? 0) + value;
  }

  /// The current total of the series [labels] names; zero when never added to.
  double valueOf([Map<String, String> labels = const {}]) =>
      _values[_seriesKey(labels)] ?? 0;

  @override
  List<TomMetricPoint> _points() => [
    for (final e in _values.entries)
      TomMetricPoint(_labelsByKey[e.key]!, value: e.value),
  ];

  @override
  void _clear() => _values.clear();
}

/// A value set whenever it changes: connections open, a timestamp of the last
/// success.
class TomGauge extends TomMetric {
  TomGauge._(super.name, super.help, super.unit) : super._();

  final Map<String, double> _values = {};

  @override
  TomMetricKind get kind => TomMetricKind.gauge;

  /// Sets the series [labels] names to [value].
  void set(num value, [Map<String, String> labels = const {}]) {
    _values[_keyOf(labels)] = value.toDouble();
  }

  /// The current value of the series [labels] names, or `null` if never set.
  double? valueOf([Map<String, String> labels = const {}]) =>
      _values[_seriesKey(labels)];

  @override
  List<TomMetricPoint> _points() => [
    for (final e in _values.entries)
      TomMetricPoint(_labelsByKey[e.key]!, value: e.value),
  ];

  @override
  void _clear() => _values.clear();
}

/// Observations sorted into fixed buckets: request latencies, job start lag.
class TomHistogram extends TomMetric {
  TomHistogram._(super.name, super.help, super.unit, List<double> buckets)
    : buckets = List.unmodifiable(buckets),
      super._();

  /// The upper bounds of the buckets, ascending; an observation above the last
  /// falls into the implicit `+Inf` bucket.
  final List<double> buckets;

  final Map<String, TomHistogramData> _values = {};

  @override
  TomMetricKind get kind => TomMetricKind.histogram;

  /// Records [value] in the series [labels] names.
  void record(num value, [Map<String, String> labels = const {}]) {
    final key = _keyOf(labels);
    final data = _values[key] ??= TomHistogramData._empty(buckets);
    var index = buckets.length;
    for (var i = 0; i < buckets.length; i++) {
      if (value <= buckets[i]) {
        index = i;
        break;
      }
    }
    data._counts[index]++;
    data._count++;
    data._sum += value;
  }

  /// Records the time [duration] in seconds.
  void recordDuration(
    Duration duration, [
    Map<String, String> labels = const {},
  ]) =>
      record(duration.inMicroseconds / Duration.microsecondsPerSecond, labels);

  /// Runs [body] and records how long it took, whether it returned or threw.
  Future<T> time<T>(
    Future<T> Function() body, [
    Map<String, String> labels = const {},
  ]) async {
    final watch = Stopwatch()..start();
    try {
      return await body();
    } finally {
      recordDuration(watch.elapsed, labels);
    }
  }

  /// The data of the series [labels] names, or `null` if nothing was recorded.
  TomHistogramData? valueOf([Map<String, String> labels = const {}]) =>
      _values[_seriesKey(labels)]?._copy();

  @override
  List<TomMetricPoint> _points() => [
    for (final e in _values.entries)
      TomMetricPoint(_labelsByKey[e.key]!, histogram: e.value._copy()),
  ];

  @override
  void _clear() => _values.clear();
}

/// The state of one histogram series: a count per bucket, the number of
/// observations and their sum.
class TomHistogramData {
  TomHistogramData._(this.bounds, this._counts, this._count, this._sum);

  TomHistogramData._empty(List<double> bounds)
    : this._(bounds, List.filled(bounds.length + 1, 0), 0, 0);

  /// The bucket upper bounds, ascending.
  final List<double> bounds;

  final List<int> _counts;
  int _count;
  double _sum;

  /// Observations per bucket — NOT cumulative — one more than [bounds], the
  /// last being the `+Inf` bucket.
  List<int> get counts => List.unmodifiable(_counts);

  /// How many observations were recorded.
  int get count => _count;

  /// The sum of every observation.
  double get sum => _sum;

  TomHistogramData _copy() =>
      TomHistogramData._(bounds, List.of(_counts), _count, _sum);
}

/// One series of a [TomMetricFamily] at the moment of the snapshot.
class TomMetricPoint {
  /// A point carrying [value] (a counter or gauge) or [histogram].
  const TomMetricPoint(this.labels, {this.value = 0, this.histogram});

  /// The series' labels.
  final Map<String, String> labels;

  /// The value of a counter or gauge series.
  final double value;

  /// The data of a histogram series, `null` for any other kind.
  final TomHistogramData? histogram;
}

/// One instrument's series at the moment of the snapshot.
class TomMetricFamily {
  /// A family of [points].
  const TomMetricFamily({
    required this.name,
    required this.help,
    required this.unit,
    required this.kind,
    required this.points,
  });

  /// The series name, without the `_total` a counter is read with.
  final String name;

  /// What the series measures.
  final String help;

  /// The UCUM unit, or empty.
  final String unit;

  /// The instrument kind.
  final TomMetricKind kind;

  /// Every series, sorted by label set.
  final List<TomMetricPoint> points;
}

/// One value an observation callback reports: [value] for the series [labels]
/// names.
class TomObservedValue {
  /// A value for the series [labels] names.
  const TomObservedValue(this.value, [this.labels = const {}]);

  /// The value.
  final num value;

  /// The series' labels.
  final Map<String, String> labels;
}

/// Computes a gauge's values when a snapshot is taken.
typedef TomMetricObserver = FutureOr<Iterable<TomObservedValue>> Function();

/// A registered observation; [cancel] removes it from its registry.
class TomMetricObservation {
  TomMetricObservation._(
    this._registry,
    this.name,
    this.help,
    this.unit,
    this._observer,
  );

  final TomMetricRegistry _registry;

  /// The gauge the callback reports.
  final String name;

  /// What the gauge measures.
  final String help;

  /// The UCUM unit, or empty.
  final String unit;

  final TomMetricObserver _observer;

  /// Stops reporting; the gauge's series disappear from the next snapshot.
  void cancel() => _registry._observations.remove(this);
}

/// The instruments of one process (one isolate), and the snapshot of them.
///
/// Instruments are created on first request and returned again for the same
/// name afterwards, so a module asks for its instrument where it records and
/// two modules naming one series share it. A name requested as two kinds, or
/// as a histogram with other buckets, is refused (`metrics.name.conflict`).
class TomMetricRegistry {
  /// An empty registry. [clock] is injectable for tests.
  TomMetricRegistry({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _startTime = _clock();
  }

  final DateTime Function() _clock;
  late DateTime _startTime;

  final Map<String, TomMetric> _instruments = {};
  final List<TomMetricObservation> _observations = [];

  /// How long a snapshot waits for one observation callback before reporting
  /// it as failed.
  Duration observationTimeout = const Duration(seconds: 5);

  /// When the totals began accumulating — the registry's creation or its last
  /// [reset]. An OTLP export reports cumulative values from this instant.
  DateTime get startTime => _startTime;

  /// The counter named [name], created with [help] and [unit] on first use.
  TomCounter counter(String name, {required String help, String unit = ''}) {
    if (name.endsWith('_total')) {
      throw TomMetricsException(
        'metrics.name.invalid',
        "The counter '$name' is named without '_total'; the Prometheus "
            'rendering appends it.',
        parameters: {'metric': name},
      );
    }
    return _instrument(name, () => TomCounter._(name, help, unit));
  }

  /// The gauge named [name], created with [help] and [unit] on first use.
  TomGauge gauge(String name, {required String help, String unit = ''}) =>
      _instrument(name, () => TomGauge._(name, help, unit));

  /// The histogram named [name] with [buckets], created on first use.
  TomHistogram histogram(
    String name, {
    required String help,
    String unit = '',
    List<double> buckets = tomLatencyBuckets,
  }) {
    final histogram = _instrument(
      name,
      () => TomHistogram._(name, help, unit, buckets),
    );
    if (!_sameBuckets(histogram.buckets, buckets)) {
      throw TomMetricsException(
        'metrics.name.conflict',
        "The histogram '$name' already exists with other buckets.",
        parameters: {'metric': name},
      );
    }
    return histogram;
  }

  /// Registers [observer] to report the gauge [name] whenever a snapshot is
  /// taken — for a value that is cheaper to read than to keep current, such as
  /// a pool's idle connections or a queue's backlog.
  ///
  /// Several observations may report one name; their series are merged, the
  /// first reporting a label set winning. A callback that throws or exceeds
  /// [observationTimeout] contributes nothing to that snapshot and is counted
  /// in `tom_metrics_observation_failures`.
  TomMetricObservation observe(
    String name, {
    required String help,
    String unit = '',
    required TomMetricObserver observer,
  }) {
    _requireName(name);
    final existing = _instruments[name];
    if (existing != null) {
      throw TomMetricsException(
        'metrics.name.conflict',
        "'$name' is already registered as a ${existing.kind.name}.",
        parameters: {'metric': name, 'kind': existing.kind.name},
      );
    }
    final observation = TomMetricObservation._(
      this,
      name,
      help,
      unit,
      observer,
    );
    _observations.add(observation);
    return observation;
  }

  /// Every instrument and observation, read now.
  ///
  /// Families are sorted by name and points by label set, so two snapshots of
  /// the same state render identically.
  Future<List<TomMetricFamily>> collect() async {
    final families = <String, TomMetricFamily>{
      for (final metric in _instruments.values)
        metric.name: TomMetricFamily(
          name: metric.name,
          help: metric.help,
          unit: metric.unit,
          kind: metric.kind,
          points: _sorted(metric._points()),
        ),
    };
    final observed = <String, Map<String, TomMetricPoint>>{};
    final described = <String, TomMetricObservation>{};
    for (final observation in List.of(_observations)) {
      described.putIfAbsent(observation.name, () => observation);
      final points = observed.putIfAbsent(observation.name, () => {});
      try {
        final values = await Future.sync(
          observation._observer,
        ).timeout(observationTimeout);
        for (final v in values) {
          points.putIfAbsent(
            _seriesKey(v.labels),
            () => TomMetricPoint(v.labels, value: v.value.toDouble()),
          );
        }
      } catch (error) {
        tomLog.warn(
          "Observing the metric '${observation.name}' failed: $error",
        );
        counter(
          'tom_metrics_observation_failures',
          help: 'Observation callbacks that threw or timed out, by metric.',
        ).add(1, {'metric': observation.name});
      }
    }
    for (final entry in observed.entries) {
      final first = described[entry.key]!;
      families[entry.key] = TomMetricFamily(
        name: entry.key,
        help: first.help,
        unit: first.unit,
        kind: TomMetricKind.gauge,
        points: _sorted(entry.value.values.toList()),
      );
    }
    // A failure counted during this snapshot belongs in it.
    final failures = _instruments['tom_metrics_observation_failures'];
    if (failures != null) {
      families[failures.name] = TomMetricFamily(
        name: failures.name,
        help: failures.help,
        unit: failures.unit,
        kind: failures.kind,
        points: _sorted(failures._points()),
      );
    }
    final names = families.keys.toList()..sort();
    return [for (final n in names) families[n]!];
  }

  /// Clears every value and restarts [startTime]; the instruments and
  /// observations stay registered. For tests, which share the process
  /// registry.
  void reset() {
    for (final metric in _instruments.values) {
      metric._clear();
    }
    _startTime = _clock();
  }

  T _instrument<T extends TomMetric>(String name, T Function() create) {
    final existing = _instruments[name];
    if (existing == null) {
      _requireName(name);
      if (_observations.any((o) => o.name == name)) {
        throw TomMetricsException(
          'metrics.name.conflict',
          "'$name' is already registered as an observed gauge.",
          parameters: {'metric': name, 'kind': 'observed'},
        );
      }
      return _instruments[name] = create();
    }
    if (existing is T) return existing;
    throw TomMetricsException(
      'metrics.name.conflict',
      "'$name' is already registered as a ${existing.kind.name}.",
      parameters: {'metric': name, 'kind': existing.kind.name},
    );
  }

  static void _requireName(String name) {
    if (!_metricName.hasMatch(name)) {
      throw TomMetricsException(
        'metrics.name.invalid',
        "'$name' is not a valid metric name.",
        parameters: {'metric': name},
      );
    }
  }

  static bool _sameBuckets(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<TomMetricPoint> _sorted(List<TomMetricPoint> points) =>
      points
        ..sort((a, b) => _seriesKey(a.labels).compareTo(_seriesKey(b.labels)));
}

/// The process registry the framework records into.
abstract final class TomMetrics {
  /// The registry of this isolate.
  static final TomMetricRegistry registry = TomMetricRegistry();
}
