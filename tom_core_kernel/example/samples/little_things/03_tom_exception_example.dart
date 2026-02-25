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
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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

  // --------------------------------------------------------------------------
  // Example 1: Basic TomException creation
  // --------------------------------------------------------------------------
  static void example1BasicException() {
    print('1. Basic TomException creation:');

    final exception = TomException(
      'USER_NOT_FOUND',
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
    assert(capturedKey == 'USER_NOT_FOUND', 'Key should match');
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
      'VALIDATION_ERROR',
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
      'DATABASE_ERROR',
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
      'PERMISSION_DENIED',
      'User does not have access to this resource',
      parameters: {
        'userId': 'user-456',
        'resourceId': 'document-789',
        'requiredRole': 'admin',
        'actualRole': 'viewer',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    parametersWork = exception.parameters != null &&
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
        'PARSE_ERROR',
        'Failed to parse numeric input',
        rootException: original,
      );

      print('   - rootException type: ${exception.rootException.runtimeType}');
      print('   - rootException: ${exception.rootException}');

      // Assertions
      assert(exception.rootException is FormatException, 'Root should be FormatException');
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
        'NESTED_ERROR',
        'Error in nested call',
        stack: stack,
      );

      print('   - Stack trace captured: ${exception.stackTrace.isNotEmpty}');
      print('   - First lines of stack:');

      // Show first 3 lines
      final lines = exception.stackTrace.split('\n').take(3);
      for (final line in lines) {
        print('     $line');
      }

      // printStackTrace method
      print('   - exception.printStackTrace(2) would print limited frames');

      // Assertions
      assert(exception.stackTrace.isNotEmpty, 'Stack trace should be captured');
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
      'API_ERROR',
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
    assert(logRepresentation!.contains('API_ERROR'), 'Should contain key');
    assert(loggableWorks, 'logRepresentation should equal toString');
  }

  // --------------------------------------------------------------------------
  // Example 8: Auto-logging on creation
  // --------------------------------------------------------------------------
  static void example8AutoLogging() {
    print('\n8. Auto-logging on creation:');

    print('   - When autoLog: true, exception logs itself on creation');
    print('   - Logs both the exception and stack trace');
    print('');
    print('   Example:');
    print('   throw TomException(');
    print('     "CRITICAL_ERROR",');
    print('     "System failure",');
    print('     autoLog: true,  // Logs immediately');
    print('   );');
    print('');
    print('   Output in logs:');
    print('   - ERROR: EXCEPTION: <uuid>-null, TomException: CRITICAL_ERROR...');
    print('   - ERROR: EXCEPTION_STACKTRACE: <uuid>-null <stack>');
  }

  // --------------------------------------------------------------------------
  // Example 9: TomServerCallError integration
  // --------------------------------------------------------------------------
  static void example9ServerCallError() {
    print('\n9. TomServerCallError integration:');

    // When exception comes from HTTP call, serverCallError has details
    print('   - serverCallError field stores HTTP error details');
    print('   - Available from TomServerConnectionException');
    print('');
    print('   final exception = TomException(');
    print('     "HTTP_ERROR",');
    print('     "Server returned error",');
    print('     serverCallError: TomServerCallError(...),');
    print('   );');
    print('');
    print('   - Access via: exception.serverCallError');
    print('   - Contains: status code, response body, headers, etc.');
  }

  // --------------------------------------------------------------------------
  // Example 10: Catching and handling TomException
  // --------------------------------------------------------------------------
  static void example10CatchingAndHandling() {
    print('\n10. Catching and handling TomException:');

    try {
      throw TomException(
        'BUSINESS_RULE_VIOLATION',
        'Cannot delete user with active subscriptions',
        parameters: {
          'userId': 'user-123',
          'activeSubscriptions': 3,
        },
      );
    } on TomException catch (e) {
      print('   - Caught TomException');
      print('   - key: ${e.key}');
      print('   - message: ${e.defaultUserMessage}');
      print('   - uuid: ${e.uuid}');
      print('   - parameters: ${e.parameters}');

      // Handle based on key
      switch (e.key) {
        case 'BUSINESS_RULE_VIOLATION':
          print('   - Handling: Show user-friendly message');
          break;
        case 'USER_NOT_FOUND':
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
  print('═══════════════════════════════════════════════════════════════════');
  print('TOM EXCEPTION DETAILED USAGE EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

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

  print('\n✓ All TomException examples passed!\n');
}

void main() => run();
