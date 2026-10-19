/// The Prometheus text exposition format (version 0.0.4) of a metrics
/// snapshot.
///
/// A pure rendering of [TomMetricRegistry.collect]'s answer: nothing here
/// knows about HTTP, which is `tom_core_server`'s `/metrics` endpoint's
/// business. A counter is rendered with the `_total` suffix Prometheus expects,
/// a histogram as cumulative `_bucket` series with `le` labels plus `_sum` and
/// `_count`.
library;

import 'metrics.dart';

/// The `Content-Type` a Prometheus scrape of [tomPrometheusText] is served
/// with.
const String tomPrometheusContentType =
    'text/plain; version=0.0.4; charset=utf-8';

/// [families] in the Prometheus text exposition format.
String tomPrometheusText(Iterable<TomMetricFamily> families) {
  final out = StringBuffer();
  for (final family in families) {
    final name = family.kind == TomMetricKind.counter
        ? '${family.name}_total'
        : family.name;
    out
      ..write('# HELP $name ${_escapeHelp(family.help)}\n')
      ..write('# TYPE $name ${family.kind.name}\n');
    for (final point in family.points) {
      final histogram = point.histogram;
      if (histogram == null) {
        out.write('$name${_labels(point.labels)} ${_number(point.value)}\n');
        continue;
      }
      var cumulative = 0;
      for (var i = 0; i <= histogram.bounds.length; i++) {
        cumulative += histogram.counts[i];
        final le = i < histogram.bounds.length
            ? _number(histogram.bounds[i])
            : '+Inf';
        out.write(
          '${family.name}_bucket${_labels(point.labels, le: le)} '
          '$cumulative\n',
        );
      }
      out
        ..write(
          '${family.name}_sum${_labels(point.labels)} '
          '${_number(histogram.sum)}\n',
        )
        ..write(
          '${family.name}_count${_labels(point.labels)} ${histogram.count}\n',
        );
    }
  }
  return out.toString();
}

/// [labels] sorted by name, so a series renders the same whichever order its
/// labels were given in; a histogram bucket's [le] comes last.
String _labels(Map<String, String> labels, {String? le}) {
  if (labels.isEmpty && le == null) return '';
  final names = labels.keys.toList()..sort();
  final pairs = [
    for (final n in names) '$n="${_escapeValue(labels[n]!)}"',
    if (le != null) 'le="$le"',
  ];
  return '{${pairs.join(',')}}';
}

String _escapeHelp(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('\n', r'\n');

String _escapeValue(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');

String _number(double value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value > 0 ? '+Inf' : '-Inf';
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}
