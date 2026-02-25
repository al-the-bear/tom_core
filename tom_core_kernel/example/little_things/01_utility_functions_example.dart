/// Demonstrates utility functions from the little_things module including
/// checked execution, stack trace processing, and exception handling.
///
/// This example covers:
/// - Async error transformation with runChecked
/// - Synchronous error transformation with runCheckedSync
/// - Stack trace formatting with tomGetStackTrace
/// - Stack trace as list with tomGetStackTraceAsList
/// - Stack trace as tuple with tomGetStackTraceAsTuple
/// - TomException creation and inspection
///
/// These utilities are particularly useful for:
/// - Wrapping low-level errors in domain-specific exceptions
/// - Formatting stack traces for logging
/// - Creating trackable exceptions with UUIDs
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 01: Utility Functions Example ===\n');

  // ===========================================================================
  // Example 1: Synchronous Checked Execution - Success Case
  // ===========================================================================

  print('1. Synchronous checked execution (success case):');

  final parseInput = '{"name": "test", "value": 42}';
  print('   Input: $parseInput');

  final parsedResult = runCheckedSync(
    () {
      // Simulating JSON parsing by returning a map
      return <String, dynamic>{'name': 'test', 'value': 42};
    },
    (error, stacktrace) => TomException(
      'PARSE_ERROR',
      'Failed to parse configuration',
      rootException: error,
    ),
  );

  final parsedName = parsedResult['name'] as String;
  final parsedValue = parsedResult['value'] as int;

  print('   Parsed successfully:');
  print('   - name: $parsedName');
  print('   - value: $parsedValue');
  print('');

  // ===========================================================================
  // Example 2: Synchronous Checked Execution - Error Case
  // ===========================================================================

  print('2. Synchronous checked execution (error case):');

  String? caughtErrorKey;
  String? caughtErrorMessage;
  Object? caughtRootException;

  try {
    runCheckedSync<int>(
      () {
        throw FormatException('Invalid number format');
      },
      (error, stacktrace) => TomException(
        'VALIDATION_ERROR',
        'Input validation failed',
        rootException: error,
        parameters: {'input': 'bad_value'},
      ),
    );
  } on TomException catch (e) {
    caughtErrorKey = e.key;
    caughtErrorMessage = e.defaultUserMessage;
    caughtRootException = e.rootException;
  }

  print('   Caught TomException:');
  print('   - key: $caughtErrorKey');
  print('   - message: $caughtErrorMessage');
  print('   - rootException type: ${caughtRootException.runtimeType}');
  print('');

  // ===========================================================================
  // Example 3: Stack Trace Formatting
  // ===========================================================================

  print('3. Stack trace formatting with depth limit:');

  String capturedStackTrace = '';
  try {
    _levelOne();
  } catch (e, stack) {
    capturedStackTrace = tomGetStackTrace(stack, 5);
  }

  final stackLineCount = capturedStackTrace.split('\n').length;
  final containsLevelThree = capturedStackTrace.contains('_levelThree');

  print('   Stack trace (limited to 5 frames):');
  for (final line in capturedStackTrace.split('\n')) {
    print('   $line');
  }
  print('   Total lines: $stackLineCount');
  print('   Contains _levelThree: $containsLevelThree');
  print('');

  // ===========================================================================
  // Example 4: Stack Trace as List
  // ===========================================================================

  print('4. Stack trace as list of frames:');

  List<String> stackFrameList = [];
  try {
    _levelOne();
  } catch (e, stack) {
    stackFrameList = tomGetStackTraceAsList(stack, 3);
  }

  final frameCount = stackFrameList.length;
  final firstFrame = stackFrameList.isNotEmpty ? stackFrameList.first : '';
  final lastFrame = stackFrameList.isNotEmpty ? stackFrameList.last : '';

  print('   Number of frames: $frameCount');
  print('   First frame: $firstFrame');
  print('   Last frame: $lastFrame');
  print('');

  // ===========================================================================
  // Example 5: Stack Trace as Tuple
  // ===========================================================================

  print('5. Stack trace as tuple (string and list):');

  String tupleStackString = '';
  List<String> tupleStackList = [];
  try {
    _levelOne();
  } catch (e, stack) {
    final (stackString, stackList) = tomGetStackTraceAsTuple(stack, 3);
    tupleStackString = stackString;
    tupleStackList = stackList;
  }

  final tupleStringLineCount = tupleStackString.split('\n').length;
  final tupleListLength = tupleStackList.length;
  final stringAndListMatch = tupleStringLineCount == tupleListLength;

  print('   Stack string line count: $tupleStringLineCount');
  print('   Stack list length: $tupleListLength');
  print('   String and list match: $stringAndListMatch');
  print('');

  // ===========================================================================
  // Example 6: TomException Creation and Properties
  // ===========================================================================

  print('6. TomException creation and properties:');

  final exception = TomException(
    'USER_NOT_FOUND',
    'The requested user could not be found',
    parameters: {'userId': 'user_123', 'searchType': 'byEmail'},
    requestUuid: 'req-456-789',
  );

  final exceptionKey = exception.key;
  final exceptionMessage = exception.defaultUserMessage;
  final exceptionUuid = exception.uuid;
  final exceptionRequestUuid = exception.requestUuid;
  final exceptionParameters = exception.parameters;
  final hasTimestamp = exception.timeStamp.isBefore(DateTime.now());
  final hasStackTrace = exception.stackTrace.isNotEmpty;

  print('   Exception details:');
  print('   - key: $exceptionKey');
  print('   - message: $exceptionMessage');
  print('   - uuid: $exceptionUuid');
  print('   - requestUuid: $exceptionRequestUuid');
  print('   - parameters: $exceptionParameters');
  print('   - has timestamp: $hasTimestamp');
  print('   - has stackTrace: $hasStackTrace');
  print('');

  // ===========================================================================
  // Example 7: TomException with Custom UUID
  // ===========================================================================

  print('7. TomException with custom UUID:');

  final customUuid = 'custom-error-id-12345';
  final customException = TomException(
    'CUSTOM_ERROR',
    'An error with custom UUID',
    uuid: customUuid,
  );

  final customExceptionUuid = customException.uuid;
  final uuidMatches = customExceptionUuid == customUuid;

  print('   Custom UUID provided: $customUuid');
  print('   Exception UUID: $customExceptionUuid');
  print('   UUIDs match: $uuidMatches');
  print('');

  // ===========================================================================
  // Example 8: TomException toString Representation
  // ===========================================================================

  print('8. TomException string representation:');

  final toStringException = TomException(
    'STRING_TEST',
    'Testing toString output',
    parameters: {'detail': 'test'},
  );

  final exceptionString = toStringException.toString();
  final containsKey = exceptionString.contains('STRING_TEST');
  final containsMessage = exceptionString.contains('Testing toString output');
  final containsUuidPattern = exceptionString.contains(toStringException.uuid);

  print('   Exception.toString():');
  print('   $exceptionString');
  print('   Contains key: $containsKey');
  print('   Contains message: $containsMessage');
  print('   Contains UUID: $containsUuidPattern');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Synchronous checked execution - success
  assert(parsedName == 'test');
  assert(parsedValue == 42);

  // Example 2: Synchronous checked execution - error
  assert(caughtErrorKey == 'VALIDATION_ERROR');
  assert(caughtErrorMessage == 'Input validation failed');
  assert(caughtRootException is FormatException);

  // Example 3: Stack trace formatting
  assert(stackLineCount <= 5);
  assert(capturedStackTrace.isNotEmpty);
  assert(containsLevelThree == true);

  // Example 4: Stack trace as list
  assert(frameCount <= 3);
  assert(stackFrameList.isNotEmpty);

  // Example 5: Stack trace as tuple
  assert(tupleStringLineCount == tupleListLength);
  assert(stringAndListMatch == true);

  // Example 6: TomException creation
  assert(exceptionKey == 'USER_NOT_FOUND');
  assert(exceptionMessage == 'The requested user could not be found');
  assert(exceptionUuid.isNotEmpty);
  assert(exceptionRequestUuid == 'req-456-789');
  assert(exceptionParameters != null);
  assert(exceptionParameters!['userId'] == 'user_123');
  assert(hasTimestamp == true);
  assert(hasStackTrace == true);

  // Example 7: Custom UUID
  assert(customExceptionUuid == customUuid);
  assert(uuidMatches == true);

  // Example 8: toString representation
  assert(containsKey == true);
  assert(containsMessage == true);
  assert(containsUuidPattern == true);
}

// Helper functions to create a deeper call stack for stack trace examples
void _levelOne() {
  _levelTwo();
}

void _levelTwo() {
  _levelThree();
}

void _levelThree() {
  throw Exception('Test exception for stack trace');
}
