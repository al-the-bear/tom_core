/// The structured log output and the trace context it reads: the JSON fields
/// of a line, the context fields taken from the zone, and the W3C
/// `traceparent` rules.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [TomJsonLogOutput] capturing its lines instead of printing them.
class _Captured {
  final List<(Map<String, Object?>, bool)> lines = [];
  late final TomJsonLogOutput output = TomJsonLogOutput(
    writer: (line, isError) =>
        lines.add((jsonDecode(line) as Map<String, Object?>, isError)),
  );
}

void main() {
  group('TomTraceContext', () {
    const header = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

    test('parses a traceparent header and renders it back', () {
      final context = TomTraceContext.parse(header)!;
      expect(context.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
      expect(context.spanId, '00f067aa0ba902b7');
      expect(context.sampled, isTrue);
      expect(context.traceparent, header);
    });

    test('reads the sampled flag from the low bit', () {
      expect(
        TomTraceContext.parse(
          header.replaceFirst(RegExp(r'01$'), '00'),
        )!.sampled,
        isFalse,
      );
    });

    test('ignores an invalid header rather than failing', () {
      for (final bad in [
        null,
        '',
        'garbage',
        '01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        '00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01',
        '00-00000000000000000000000000000000-00f067aa0ba902b7-01',
        '00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01',
      ]) {
        expect(TomTraceContext.parse(bad), isNull, reason: '$bad');
      }
    });

    test('a child keeps the trace and continues the span', () {
      final parent = TomTraceContext.parse(header)!;
      final child = parent.child();
      expect(child.traceId, parent.traceId);
      expect(child.parentSpanId, parent.spanId);
      expect(child.spanId, isNot(parent.spanId));
      expect(child.spanId, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('a new root has fresh, well-formed ids', () {
      final a = TomTraceContext.newRoot();
      final b = TomTraceContext.newRoot();
      expect(a.traceId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(a.traceId, isNot(b.traceId));
      expect(a.parentSpanId, isNull);
    });

    test('is current inside run and absent outside', () {
      final context = TomTraceContext.newRoot();
      expect(TomTraceContext.current, isNull);
      TomTraceContext.run(context, () {
        expect(TomTraceContext.current, same(context));
      });
      expect(TomTraceContext.current, isNull);
    });
  });

  group('TomJsonLogOutput', () {
    late _Captured captured;
    late TomLogOutput previousOutput;
    late TomLogLevel previousLevel;

    setUp(() {
      captured = _Captured();
      previousOutput = tomLog.logOutput;
      previousLevel = tomLog.logLevel;
      tomLog.logOutput = captured.output;
      tomLog.setLogLevel(TomLogLevel.all);
    });
    tearDown(() {
      tomLog.logOutput = previousOutput;
      tomLog.setLogLevel(previousLevel);
    });

    test('writes the fixed fields as one JSON object per line', () {
      tomLog.info('hello');
      final (line, isError) = captured.lines.single;
      expect(line['level'], 'info');
      expect(line['message'], 'hello');
      expect(line['isolate'], isA<String>());
      final timestamp = DateTime.parse(line['timestamp']! as String);
      expect(timestamp.isUtc, isTrue);
      expect(isError, isFalse);
      // Outside any trace or tenant, no context field is written at all.
      expect(line.keys, isNot(contains('trace_id')));
      expect(line.keys, isNot(contains('tenant')));
    });

    test('carries the trace, span and tenant of the zone', () {
      final trace = TomTraceContext.newRoot();
      TomTenantContext.run('acme', () {
        TomTraceContext.run(trace, () => tomLog.warn('inside'));
      });
      final (line, _) = captured.lines.single;
      expect(line['trace_id'], trace.traceId);
      expect(line['span_id'], trace.spanId);
      expect(line['tenant'], 'acme');
      expect(line['level'], 'warn');
    });

    test('routes errors to the error stream', () {
      tomLog.error('boom');
      expect(captured.lines.single.$2, isTrue);
    });

    test('an application field is written; a throwing one is left out', () {
      TomLogContext.register('deployment', () => 'blue');
      TomLogContext.register('broken', () => throw StateError('no'));
      addTearDown(() {
        TomLogContext.unregister('deployment');
        TomLogContext.unregister('broken');
      });
      tomLog.info('x');
      final (line, _) = captured.lines.single;
      expect(line['deployment'], 'blue');
      expect(line.keys, isNot(contains('broken')));
    });

    test('a context field may not replace a fixed one', () {
      for (final name in TomJsonLogOutput.fixedFields) {
        expect(
          () => TomLogContext.register(name, () => 'x'),
          throwsArgumentError,
        );
      }
    });

    test('respects the logger level', () {
      tomLog.setLogLevel(TomLogLevel.errors);
      tomLog.info('dropped');
      expect(captured.lines, isEmpty);
    });
  });
}
