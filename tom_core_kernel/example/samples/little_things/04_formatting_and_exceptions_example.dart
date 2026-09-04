/// Demonstrates the formatting helper and the logging/HTTP-aware features of
/// [TomException] from the little_things module.
///
/// This example covers:
/// - UTC offset formatting with convertMinutesToUtcOffset
/// - Truly-awaited runChecked (both success and error paths)
/// - Stack-trace logging with tomPrintStackTrace
/// - TomException.printStackTrace()
/// - TomException auto-logging (autoLog)
/// - TomException.serverCallError (HTTP error tracking)
/// - TomException.logRepresentation (TomLoggable integration)
///
/// Run with (asserts MUST be enabled so the invariants below are checked):
/// ```bash
/// dart run --enable-asserts example/samples/little_things/04_formatting_and_exceptions_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

/// Log output that records every emitted message so this example can observe
/// (and assert on) the logging side-effects of the exception helpers.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      messages.add(convertToString(message));
    }
  }
}

Future<void> run() async {
  print('=== 04: Formatting and Exceptions Example ===\n');

  // ---------------------------------------------------------------------------
  // 1. convertMinutesToUtcOffset — ISO 8601 UTC offset formatting.
  // ---------------------------------------------------------------------------
  print('1. UTC offset formatting:');
  final utc = convertMinutesToUtcOffset(0);
  final ist = convertMinutesToUtcOffset(330);
  final cet = convertMinutesToUtcOffset(60);
  final pst = convertMinutesToUtcOffset(-480);
  print('   0    -> "$utc"');
  print('   330  -> "$ist"  (IST)');
  print('   60   -> "$cet"  (CET)');
  print('   -480 -> "$pst"  (PST)');
  assert(utc == 'Z', 'Zero offset must render as "Z"');
  assert(ist == '+05:30', 'India Standard Time offset must be "+05:30"');
  assert(cet == '+01:00', 'Central European Time offset must be "+01:00"');
  assert(pst == '-08:00', 'Pacific Standard Time offset must be "-08:00"');

  // The hour field is two digits wide, so an offset no real zone reaches has
  // no valid rendering at all — 6000 minutes would have to be written
  // "+100:00", which no ISO 8601 parser accepts. Rather than emit that, the
  // function refuses anything outside ±840 minutes (±14:00), the widest offset
  // the IANA database actually produces.
  final lineIslands = convertMinutesToUtcOffset(840);
  print('   840  -> "$lineIslands"  (Line Islands — the maximum)');
  assert(lineIslands == '+14:00', 'The bound itself must still be valid');

  try {
    convertMinutesToUtcOffset(6000);
    throw StateError('6000 minutes should have been rejected');
  } on TomFormattingException catch (e) {
    print('   6000 -> rejected: ${e.key}');
    assert(
      e.key == 'formatting.utc_offset.out_of_range',
      'Out-of-range offsets must report the documented key',
    );
    assert(
      e.parameters?['totalMinutes'] == 6000,
      'The offending value must travel with the exception',
    );
  }
  print('');

  // ---------------------------------------------------------------------------
  // 2. runChecked — awaited success path.
  // ---------------------------------------------------------------------------
  print('2. runChecked awaited success:');
  final value = await runChecked<int>(
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return 42;
    },
    (error, stack) =>
        TomException('sample.unreachable.should_not_happen', 'unreachable'),
  );
  print('   Result: $value');
  assert(value == 42, 'Successful body value must pass through unchanged');
  print('');

  // ---------------------------------------------------------------------------
  // 3. runChecked — awaited error path (error transformed to TomException).
  // ---------------------------------------------------------------------------
  print('3. runChecked awaited error transformation:');
  Object? caught;
  try {
    await runChecked<int>(
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        throw StateError('connection dropped');
      },
      (error, stack) => TomException(
        'network.request.connection_failed',
        'Connection failed during operation',
      ),
    );
  } catch (error) {
    caught = error;
  }
  print('   Caught: ${caught.runtimeType}');
  assert(caught is TomException, 'Error path must yield the mapped exception');
  assert(
    (caught as TomException).key == 'network.request.connection_failed',
    'Mapped exception must carry the onError-provided key',
  );
  print('');

  // ---------------------------------------------------------------------------
  // 4. tomPrintStackTrace — logs a formatted trace with an optional prefix.
  // ---------------------------------------------------------------------------
  print('4. tomPrintStackTrace logging:');
  final recorder = _RecordingLogOutput();
  final previousOutput = tomLog.logOutput;
  tomLog.logOutput = recorder;
  try {
    tomPrintStackTrace(StackTrace.current, message: 'trace-prefix');
    assert(recorder.messages.isNotEmpty, 'tomPrintStackTrace must log a line');
    assert(
      recorder.messages.any((m) => m.contains('trace-prefix')),
      'The provided message must prefix the logged trace',
    );
    print('   Logged ${recorder.messages.length} line(s) with prefix.');

    // -------------------------------------------------------------------------
    // 5. TomException.printStackTrace() — logs prefixed with exception identity.
    // -------------------------------------------------------------------------
    recorder.messages.clear();
    final traced = TomException(
      'sample.trace.boom',
      'boom',
      uuid: 'uuid-123',
      requestUuid: 'req-456',
    );
    traced.printStackTrace();
    assert(
      recorder.messages.any(
        (m) => m.contains('uuid-123-req-456 exception stacktrace'),
      ),
      'printStackTrace must prefix with the exception identity',
    );
    print('5. TomException.printStackTrace logged with identity prefix.');

    // -------------------------------------------------------------------------
    // 6. autoLog — an exception logs itself on construction.
    // -------------------------------------------------------------------------
    recorder.messages.clear();
    TomException(
      'storage.connect.database_down',
      'database down',
      autoLog: true,
    );
    assert(
      recorder.messages.any((m) => m.contains('EXCEPTION:')),
      'autoLog must emit an EXCEPTION line on construction',
    );
    assert(
      recorder.messages.any((m) => m.contains('database down')),
      'autoLog line must contain the default user message',
    );
    print(
      '6. autoLog emitted ${recorder.messages.length} line(s) on '
      'construction.',
    );
  } finally {
    tomLog.logOutput = previousOutput;
  }
  print('');

  // ---------------------------------------------------------------------------
  // 7. serverCallError — attach HTTP error context to an exception.
  // ---------------------------------------------------------------------------
  print('7. TomException.serverCallError:');
  final serverError = TomServerCallError(
    statusCode: 404,
    reasonPhrase: 'Not Found',
  );
  final httpException = TomException(
    'network.request.failed',
    'request failed',
    serverCallError: serverError,
  );
  print(
    '   status: ${httpException.serverCallError!.statusCode} '
    '(${httpException.serverCallError!.reasonPhrase})',
  );
  assert(
    httpException.serverCallError!.statusCode == 404,
    'serverCallError must expose the attached HTTP status',
  );
  print('');

  // ---------------------------------------------------------------------------
  // 8. logRepresentation — TomLoggable string used by the logging system.
  // ---------------------------------------------------------------------------
  print('8. TomException.logRepresentation:');
  final loggable = TomException('sample.loggable.demo', 'human readable');
  print('   ${loggable.logRepresentation}');
  assert(
    loggable.logRepresentation == loggable.toString(),
    'logRepresentation must mirror toString()',
  );
  print('');

  print('--- Formatting & Exceptions Example complete ---\n');
}

Future<void> main() async {
  requireAsserts();
  await run();
}
