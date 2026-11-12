/// Example: structured log output — [TomJsonLogOutput] and [TomLogContext]
///
/// - one JSON object per line: `timestamp` (UTC, ISO 8601), `level`
///   (lower-case), `message`, `logger`, `isolate`
/// - the context fields read from the zone the entry was logged in:
///   `trace_id` and `span_id` from [TomTraceContext], `tenant` from
///   [TomTenantContext] — and only when the zone has a value
/// - a field of the application's own, registered with
///   [TomLogContext.register]; a fixed field name is refused, and a provider
///   that throws is skipped rather than failing the line
/// - errors and status lines flagged for stderr, as `TomConsoleLogOutput`
///   routes them
///
/// The trace context itself is shown in
/// `samples/context/05_trace_context_example.dart`.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/logging/07_json_log_output_example.dart
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// A line the output wrote: the decoded object, and whether it is an
/// error-stream line.
typedef CapturedLine = ({Map<String, Object?> fields, bool isError});

/// The zone key the sample's own `region` field is read from.
final Object regionKey = Object();

/// Runs the structured-output demonstrations.
void run() {
  print('=== 07: JSON Log Output Example ===\n');

  final lines = <CapturedLine>[];
  final output = TomJsonLogOutput(
    writer: (line, isError) {
      // Each line is one complete JSON object, without its newline.
      assert(!line.contains('\n'), 'One entry, one line');
      lines.add((
        fields: jsonDecode(line) as Map<String, Object?>,
        isError: isError,
      ));
    },
  );

  final originalOutput = tomLog.logOutput;
  final originalLevel = tomLog.logLevel;
  tomLog.logOutput = output;
  tomLog.setLogLevel(TomLogLevel.production);

  final trace = TomTraceContext.parse(
    '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
  )!.child();

  try {
    // -------------------------------------------------------------------------
    // Example 1: the fixed fields of an entry
    // -------------------------------------------------------------------------
    print('1. The fixed fields of one entry:');

    final entry = output.entry(
      'INFO   ',
      'Order placed',
      'main',
      DateTime.utc(2026, 10, 20, 8, 15, 2, 113),
      'OrderService.place',
    );
    print('   - ${jsonEncode(entry)}');
    print('   - fixed fields: ${TomJsonLogOutput.fixedFields.join(', ')}\n');

    // -------------------------------------------------------------------------
    // Example 2: outside every trace and tenant — fixed fields only
    // -------------------------------------------------------------------------
    print('2. A line logged outside every trace and tenant:');

    tomLog.info('Started');
    final plain = lines.last.fields;
    print('   - ${jsonEncode(plain)}\n');

    // -------------------------------------------------------------------------
    // Example 3: the context fields come from the zone
    // -------------------------------------------------------------------------
    print('3. A line logged inside a trace and a tenant:');

    TomTraceContext.run(trace, () {
      TomTenantContext.run('acme', () {
        tomLog.info('Order placed');
      });
    });
    final traced = lines.last.fields;
    print('   - trace_id: ${traced['trace_id']}');
    print('   - span_id:  ${traced['span_id']}');
    print('   - tenant:   ${traced['tenant']}');
    print('   - registered fields: ${TomLogContext.names.join(', ')}\n');

    // -------------------------------------------------------------------------
    // Example 4: errors and status are error-stream lines
    // -------------------------------------------------------------------------
    print('4. Which lines go to stderr:');

    tomLog.warn('Stock low');
    final warnIsError = lines.last.isError;
    tomLog.error('Payment refused');
    final errorIsError = lines.last.isError;
    tomLog.status('Shutting down');
    final statusIsError = lines.last.isError;
    print('   - warn:   ${warnIsError ? 'stderr' : 'stdout'}');
    print('   - error:  ${errorIsError ? 'stderr' : 'stdout'}');
    print('   - status: ${statusIsError ? 'stderr' : 'stdout'}\n');

    // -------------------------------------------------------------------------
    // Example 5: a field of the application's own
    // -------------------------------------------------------------------------
    print('5. Registering a context field:');

    TomLogContext.register('region', () => Zone.current[regionKey] as String?);
    runZoned(() => tomLog.info('Shipped'), zoneValues: {regionKey: 'eu-west'});
    final withRegion = lines.last.fields;
    tomLog.info('No region here');
    final withoutRegion = lines.last.fields;
    print('   - in the zone:      region=${withRegion['region']}');
    print('   - outside the zone: region=${withoutRegion['region']}');

    String? fixedRefused;
    try {
      TomLogContext.register('level', () => 'loud');
    } on ArgumentError catch (e) {
      fixedRefused = '${e.message}';
    }
    print('   - "level" refused:  $fixedRefused');

    TomLogContext.register('region', () => throw StateError('unreadable'));
    tomLog.info('Still written');
    final afterThrow = lines.last.fields;
    print(
      '   - a throwing provider: the line is still written, '
      'region=${afterThrow['region']}',
    );

    final removed = TomLogContext.unregister('region');
    final removedAgain = TomLogContext.unregister('region');
    print('   - unregister: $removed, then $removedAgain\n');

    // -------------------------------------------------------------------------
    // Verification
    // -------------------------------------------------------------------------

    // Example 1
    assert(entry['timestamp'] == '2026-10-20T08:15:02.113Z', 'UTC, ISO 8601');
    assert(entry['level'] == 'info', 'The level name, trimmed, lower-case');
    assert(entry['message'] == 'Order placed', 'The message');
    assert(entry['logger'] == 'OrderService.place', 'The origin is the logger');
    assert(entry['isolate'] == 'main', 'The isolate');
    assert(
      TomJsonLogOutput.fixedFields.containsAll([
        'timestamp',
        'level',
        'message',
        'logger',
        'isolate',
      ]),
      'Five fixed fields',
    );

    // Example 2
    assert(plain['message'] == 'Started', 'The logged message');
    assert(
      !plain.containsKey('trace_id') &&
          !plain.containsKey('span_id') &&
          !plain.containsKey('tenant'),
      'A field whose zone has no value is left out',
    );
    assert(
      DateTime.parse(plain['timestamp']! as String).isUtc,
      'The timestamp is UTC',
    );

    // Example 3
    assert(traced['trace_id'] == trace.traceId, 'trace_id from the zone');
    assert(traced['span_id'] == trace.spanId, 'span_id is this span');
    assert(traced['tenant'] == 'acme', 'tenant from the zone');
    assert(
      TomLogContext.names.take(4).join(',') ==
          'trace_id,span_id,request_id,tenant',
      'The kernel registers trace_id, span_id, request_id and tenant, in that order',
    );

    // Example 4
    assert(!warnIsError, 'A warning goes to stdout');
    assert(errorIsError, 'An error goes to stderr');
    assert(statusIsError, 'A status line goes to stderr');

    // Example 5
    assert(withRegion['region'] == 'eu-west', 'A registered field is written');
    assert(!withoutRegion.containsKey('region'), 'Only when it has a value');
    assert(fixedRefused != null, 'A fixed field name is refused');
    assert(
      afterThrow['message'] == 'Still written' &&
          !afterThrow.containsKey('region'),
      'A throwing provider is skipped, the line is written',
    );
    assert(removed && !removedAgain, 'unregister answers whether it removed');
    assert(!TomLogContext.names.contains('region'), 'The field is gone');
  } finally {
    TomLogContext.unregister('region');
    tomLog.logOutput = originalOutput;
    tomLog.setLogLevel(originalLevel);
  }
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
