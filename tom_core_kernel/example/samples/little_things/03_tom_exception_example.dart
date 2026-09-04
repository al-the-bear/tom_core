/// TomException Detailed Usage Example
///
/// This example demonstrates the comprehensive features of TomException:
/// - UUID tracking for error correlation
/// - Request UUID for request-scoped errors
/// - Stack trace capture and printing
/// - Auto-logging on creation
/// - Parameters for context
/// - TomLoggable interface
/// - TomServerCallError integration
///
/// Run with (asserts MUST be enabled so the invariants below are checked):
/// ```bash
/// dart run --enable-asserts example/samples/little_things/03_tom_exception_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

/// Log output that records every emitted message so this example can observe
/// (and assert on) the logging side-effects of the exception helpers.
///
/// The logging examples below install one of these in place of the configured
/// output, exercise the feature, and restore the previous output in a
/// `finally` — otherwise a failed assertion would leave the recorder in place
/// and silence every later example in the run.
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

// ============================================================================
// Example Class
// ============================================================================

class TomExceptionExample {
  // Captured results
  static String? capturedUuid;
  static String? capturedRequestUuid;
  static String? capturedKey;
  static bool uuidGenerated = false;
  static bool timestampSet = false;
  static bool parametersWork = false;
  static bool loggableWorks = false;
  static String? logRepresentation;
  static bool stackTracePrinted = false;
  static bool autoLogEmitted = false;
  static bool serverCallErrorDecoded = false;

  // --------------------------------------------------------------------------
  // Example 1: Basic TomException creation
  // --------------------------------------------------------------------------
  static void example1BasicException() {
    print('1. Basic TomException creation:');

    final exception = TomException(
      'user.fetch.not_found',
      'The requested user could not be found',
    );

    capturedKey = exception.key;
    capturedUuid = exception.uuid;
    timestampSet = exception.timeStamp.millisecondsSinceEpoch > 0;
    uuidGenerated = exception.uuid.isNotEmpty;

    print('   - key: ${exception.key}');
    print('   - defaultUserMessage: ${exception.defaultUserMessage}');
    print('   - uuid: ${exception.uuid}');
    print('   - timeStamp: ${exception.timeStamp}');

    // Assertions
    assert(capturedKey == 'user.fetch.not_found', 'Key should match');
    assert(uuidGenerated, 'UUID should be generated');
    assert(timestampSet, 'Timestamp should be set');
  }

  // --------------------------------------------------------------------------
  // Example 2: Exception with custom UUID
  // --------------------------------------------------------------------------
  static void example2CustomUuid() {
    print('\n2. Exception with custom UUID:');

    final customUuid = 'custom-error-id-12345';
    final exception = TomException(
      'input.validate.failed',
      'Input validation failed',
      uuid: customUuid,
    );

    print('   - Provided uuid: $customUuid');
    print('   - exception.uuid: ${exception.uuid}');

    // Assertions
    assert(exception.uuid == customUuid, 'UUID should be custom value');
  }

  // --------------------------------------------------------------------------
  // Example 3: Exception with request UUID correlation
  // --------------------------------------------------------------------------
  static void example3RequestUuidCorrelation() {
    print('\n3. Exception with request UUID correlation:');

    final requestUuid = 'req-abc-123-xyz';
    final exception = TomException(
      'storage.connect.failed',
      'Database connection failed',
      requestUuid: requestUuid,
    );

    capturedRequestUuid = exception.requestUuid;

    print('   - requestUuid: ${exception.requestUuid}');
    print('   - exception.uuid: ${exception.uuid}');
    print('   - Full correlation: ${exception.uuid}-${exception.requestUuid}');

    // Assertions
    assert(exception.requestUuid == requestUuid, 'Request UUID should match');
  }

  // --------------------------------------------------------------------------
  // Example 4: Exception with parameters
  // --------------------------------------------------------------------------
  static void example4WithParameters() {
    print('\n4. Exception with parameters for context:');

    final exception = TomException(
      'access.check.permission_denied',
      'User does not have access to this resource',
      parameters: {
        'userId': 'user-456',
        'resourceId': 'document-789',
        'requiredRole': 'admin',
        'actualRole': 'viewer',
        // A fixed instant, not DateTime.now(): every run of this example must
        // produce the same output, or its printed result cannot be compared
        // against anything.
        'timestamp': DateTime.utc(2026, 3, 14, 9, 26, 53).toIso8601String(),
      },
    );

    parametersWork =
        exception.parameters != null &&
        exception.parameters!['userId'] == 'user-456';

    print('   - Parameters:');
    exception.parameters?.forEach((key, value) {
      print('     - $key: $value');
    });

    // Assertions
    assert(parametersWork, 'Parameters should be accessible');
  }

  // --------------------------------------------------------------------------
  // Example 5: Exception with root exception
  // --------------------------------------------------------------------------
  static void example5WithRootException() {
    print('\n5. Exception with root exception:');

    try {
      // Simulate an underlying error
      int.parse('not-a-number');
    } on FormatException catch (original) {
      final exception = TomException(
        'input.parse.not_a_number',
        'Failed to parse numeric input',
        rootException: original,
      );

      print('   - rootException type: ${exception.rootException.runtimeType}');
      print('   - rootException: ${exception.rootException}');

      // Assertions
      assert(
        exception.rootException is FormatException,
        'Root should be FormatException',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Example 6: Stack trace capture and printing
  // --------------------------------------------------------------------------
  static void example6StackTraceCapture() {
    print('\n6. Stack trace capture and printing:');

    try {
      _causeError();
    } catch (e, stack) {
      final exception = TomException(
        'sample.nested_call.failed',
        'Error in nested call',
        stack: stack,
        uuid: 'trace-uuid-1',
        requestUuid: 'trace-req-1',
      );

      print('   - Stack trace captured: ${exception.stackTrace.isNotEmpty}');
      print('   - First lines of stack:');

      // Show first 3 lines
      final lines = exception.stackTrace.split('\n').take(3);
      for (final line in lines) {
        print('     $line');
      }

      // printStackTrace routes through tomLog rather than stdout, so the only
      // way to see what it produced is to record the log output.
      final recorder = _RecordingLogOutput();
      final previousOutput = tomLog.logOutput;
      tomLog.logOutput = recorder;
      try {
        exception.printStackTrace(2);
      } finally {
        tomLog.logOutput = previousOutput;
      }

      stackTracePrinted = recorder.messages.any(
        (m) => m.contains('trace-uuid-1-trace-req-1 exception stacktrace'),
      );

      print(
        '   - printStackTrace(2) logged ${recorder.messages.length} '
        'line(s), prefixed with the exception identity:',
      );
      print('     ${recorder.messages.first.split('\n').first}');

      // Assertions
      assert(exception.stackTrace.isNotEmpty, 'Stack trace should be captured');
      assert(
        stackTracePrinted,
        'printStackTrace must log a line prefixed with uuid-requestUuid',
      );
    }
  }

  static void _causeError() {
    _innerError();
  }

  static void _innerError() {
    throw Exception('Inner error');
  }

  // --------------------------------------------------------------------------
  // Example 7: TomLoggable interface
  // --------------------------------------------------------------------------
  static void example7LoggableInterface() {
    print('\n7. TomLoggable interface:');

    final exception = TomException(
      'apis.call.failed',
      'External API call failed',
      parameters: {'endpoint': '/api/users'},
    );

    // TomException implements TomLoggable
    final TomLoggable loggable = exception;
    logRepresentation = loggable.logRepresentation;

    print('   - TomException implements TomLoggable');
    print('   - logRepresentation: $logRepresentation');
    print('   - toString(): ${exception.toString()}');

    loggableWorks = logRepresentation == exception.toString();

    // The logRepresentation includes uuid, key, message, parameters
    assert(
      logRepresentation!.contains('apis.call.failed'),
      'Should contain key',
    );
    assert(loggableWorks, 'logRepresentation should equal toString');
  }

  // --------------------------------------------------------------------------
  // Example 8: Auto-logging on creation
  // --------------------------------------------------------------------------
  static void example8AutoLogging() {
    print('\n8. Auto-logging on creation:');

    final recorder = _RecordingLogOutput();
    final previousOutput = tomLog.logOutput;
    tomLog.logOutput = recorder;

    late TomException logged;
    try {
      // The default: constructing an exception is silent. Shown first so the
      // autoLog lines below are visibly caused by the flag and not by
      // construction itself.
      TomException('storage.connect.failed', 'Database connection failed');
      final quietCount = recorder.messages.length;

      logged = TomException(
        'storage.connect.failed',
        'Database connection failed',
        requestUuid: 'req-8100',
        autoLog: true,
      );

      autoLogEmitted = quietCount == 0 && recorder.messages.length == 2;
    } finally {
      tomLog.logOutput = previousOutput;
    }

    print('   - Without autoLog, construction logged nothing.');
    print(
      '   - With autoLog: true, it logged '
      '${recorder.messages.length} line(s):',
    );
    for (final message in recorder.messages) {
      // Only the first line of each: the stack-trace line runs to many frames.
      print('     ${message.split('\n').first}');
    }
    print(
      '   - Both lines carry ${logged.uuid}-${logged.requestUuid}, so a '
      'trace can be joined back to the failure it came from.',
    );

    // Assertions
    assert(autoLogEmitted, 'autoLog must log exactly two lines, and only then');
    assert(
      recorder.messages.every((m) => m.contains(logged.uuid)),
      'Every autoLog line must carry the exception uuid',
    );
    assert(
      recorder.messages.any((m) => m.contains('EXCEPTION_STACKTRACE:')),
      'autoLog must emit the stack trace alongside the exception',
    );
  }

  // --------------------------------------------------------------------------
  // Example 9: TomServerCallError integration
  // --------------------------------------------------------------------------
  static void example9ServerCallError() {
    print('\n9. TomServerCallError integration:');

    // A Tom server signals its own error format with the x-tom-error header.
    // When that header is present, TomServerCallError decodes the JSON body
    // and lifts the server's own error key and uuids into its fields — which
    // is what lets a client-side exception carry the *server's* identifiers.
    final callError = TomServerCallError(
      statusCode: 403,
      reasonPhrase: 'Forbidden',
      headers: {'x-tom-error': 'true', 'content-type': 'application/json'},
      response:
          '{"errorKey":"access.check.permission_denied",'
          '"uuid":"srv-err-9001","requestUuid":"srv-req-9002",'
          '"autoLog":false,"clientRethrow":true}',
    );

    final exception = TomException(
      'network.request.rejected',
      'Server returned an error',
      serverCallError: callError,
    );

    final attached = exception.serverCallError!;
    serverCallErrorDecoded =
        attached.errorKey == 'access.check.permission_denied' &&
        attached.uuid == 'srv-err-9001';

    print(
      '   - statusCode: ${attached.statusCode} '
      '(${attached.reasonPhrase})',
    );
    print('   - headers: ${attached.headers.keys.join(', ')}');
    print('   - decoded errorKey: ${attached.errorKey}');
    print('   - decoded server uuid: ${attached.uuid}');
    print('   - decoded server requestUuid: ${attached.requestUuid}');
    print('   - clientRethrow: ${attached.clientRethrow}');
    print(
      '   - the client-side exception keeps its own key '
      '(${exception.key}) and uuid, so both identities survive.',
    );

    // Assertions
    assert(attached.statusCode == 403, 'HTTP status must be preserved');
    assert(
      serverCallErrorDecoded,
      'An x-tom-error response body must be decoded into the error fields',
    );
    assert(
      attached.clientRethrow == true,
      'clientRethrow must be read from the server error body',
    );
    assert(
      exception.uuid != attached.uuid,
      'The client exception has its own uuid, distinct from the server one',
    );
  }

  // --------------------------------------------------------------------------
  // Example 10: Catching and handling TomException
  // --------------------------------------------------------------------------
  static void example10CatchingAndHandling() {
    print('\n10. Catching and handling TomException:');

    try {
      throw TomException(
        'user.delete.has_active_subscriptions',
        'Cannot delete user with active subscriptions',
        parameters: {'userId': 'user-123', 'activeSubscriptions': 3},
      );
    } on TomException catch (e) {
      print('   - Caught TomException');
      print('   - key: ${e.key}');
      print('   - message: ${e.defaultUserMessage}');
      print('   - uuid: ${e.uuid}');
      print('   - parameters: ${e.parameters}');

      // Handle based on key
      switch (e.key) {
        case 'user.delete.has_active_subscriptions':
          print('   - Handling: Show user-friendly message');
          break;
        case 'user.fetch.not_found':
          print('   - Handling: Redirect to login');
          break;
        default:
          print('   - Handling: Generic error handler');
      }
    }
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 03: TomException Detailed Usage Example ===\n');

  TomExceptionExample.example1BasicException();
  TomExceptionExample.example2CustomUuid();
  TomExceptionExample.example3RequestUuidCorrelation();
  TomExceptionExample.example4WithParameters();
  TomExceptionExample.example5WithRootException();
  TomExceptionExample.example6StackTraceCapture();
  TomExceptionExample.example7LoggableInterface();
  TomExceptionExample.example8AutoLogging();
  TomExceptionExample.example9ServerCallError();
  TomExceptionExample.example10CatchingAndHandling();

  // Final assertions
  assert(TomExceptionExample.uuidGenerated, 'UUID should be generated');
  assert(TomExceptionExample.timestampSet, 'Timestamp should be set');
  assert(TomExceptionExample.parametersWork, 'Parameters should work');
  assert(TomExceptionExample.loggableWorks, 'Loggable should work');
  assert(TomExceptionExample.stackTracePrinted, 'printStackTrace should log');
  assert(TomExceptionExample.autoLogEmitted, 'autoLog should log');
  assert(
    TomExceptionExample.serverCallErrorDecoded,
    'serverCallError should decode a Tom error body',
  );

  print('\n✓ All TomException examples passed!\n');
}

void main() {
  requireAsserts();
  run();
}
