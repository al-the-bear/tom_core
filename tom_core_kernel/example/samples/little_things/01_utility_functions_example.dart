/// Demonstrates utility functions from the little_things module including
/// checked execution, stack trace processing, and exception handling.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// Helper functions to generate stack traces
void _levelThree() {
  throw Exception('Error at level three');
}

void _levelTwo() {
  _levelThree();
}

void _levelOne() {
  _levelTwo();
}

// =============================================================================
// EXAMPLE 1: Synchronous Checked Execution - Success Case
// =============================================================================

class SyncCheckedSuccessExample {
  static String? parsedName;
  static int? parsedValue;
  static bool parsingSuccessful = false;

  static void example1SyncCheckedSuccess() {
    final parseInput = '{"name": "test", "value": 42}';

    // Really decode the input rather than returning a fixed map. The point of
    // runCheckedSync is that it maps a failure of `body` into a TomException,
    // so `body` has to be something that can genuinely fail — jsonDecode
    // throws FormatException on malformed input. Example 2 takes that branch.
    final parsedResult = runCheckedSync<Map<String, dynamic>>(
      () => jsonDecode(parseInput) as Map<String, dynamic>,
      (error, stacktrace) => TomException(
        'config.parse.failed',
        'Failed to parse configuration',
        rootException: error,
      ),
    );

    parsedName = parsedResult['name'] as String?;
    parsedValue = parsedResult['value'] as int?;
    parsingSuccessful = parsedName == 'test' && parsedValue == 42;

    assert(parsedName == 'test', 'Parsed name should be test');
    assert(parsedValue == 42, 'Parsed value should be 42');
    assert(parsingSuccessful, 'Parsing should be successful');
  }
}

// =============================================================================
// EXAMPLE 2: Synchronous Checked Execution - Error Case
// =============================================================================

class SyncCheckedErrorExample {
  static String? caughtErrorKey;
  static String? caughtErrorMessage;
  static Type? rootExceptionType;
  static bool exceptionCaught = false;

  static void example2SyncCheckedError() {
    try {
      runCheckedSync<int>(
        () {
          throw FormatException('Invalid number format');
        },
        (error, stacktrace) => TomException(
          'input.validate.failed',
          'Input validation failed',
          rootException: error,
          parameters: {'input': 'bad_value'},
        ),
      );
    } on TomException catch (e) {
      caughtErrorKey = e.key;
      caughtErrorMessage = e.defaultUserMessage;
      rootExceptionType = e.rootException?.runtimeType;
      exceptionCaught = true;
    }

    assert(caughtErrorKey == 'input.validate.failed', 'Error key should match');
    assert(
      caughtErrorMessage == 'Input validation failed',
      'Error message should match',
    );
    assert(
      rootExceptionType == FormatException,
      'Root exception type should be FormatException',
    );
    assert(exceptionCaught, 'Exception should be caught');
  }
}

// =============================================================================
// EXAMPLE 3: Stack Trace Formatting
// =============================================================================

class StackTraceFormattingExample {
  static String? capturedStackTrace;
  static int stackLineCount = 0;
  static bool containsLevelThree = false;

  static void example3StackTraceFormatting() {
    try {
      _levelOne();
    } catch (e, stack) {
      capturedStackTrace = tomGetStackTrace(stack, 5);
    }

    stackLineCount = capturedStackTrace?.split('\n').length ?? 0;
    containsLevelThree = capturedStackTrace?.contains('_levelThree') ?? false;

    assert(capturedStackTrace != null, 'Should capture stack trace');
    assert(stackLineCount <= 5, 'Stack trace should be limited to 5 frames');
    assert(containsLevelThree, 'Stack trace should contain _levelThree');
  }
}

// =============================================================================
// EXAMPLE 4: Stack Trace as List
// =============================================================================

class StackTraceAsListExample {
  static List<String> stackFrameList = [];
  static int frameCount = 0;
  static String? firstFrame;

  static void example4StackTraceAsList() {
    try {
      _levelOne();
    } catch (e, stack) {
      stackFrameList = tomGetStackTraceAsList(stack, 3);
    }

    frameCount = stackFrameList.length;
    firstFrame = stackFrameList.isNotEmpty ? stackFrameList.first : null;

    assert(frameCount == 3, 'Should have 3 frames');
    assert(firstFrame != null, 'First frame should exist');
    assert(stackFrameList.isNotEmpty, 'Stack frame list should not be empty');
  }
}

// =============================================================================
// EXAMPLE 5: Stack Trace as Tuple
// =============================================================================

class StackTraceAsTupleExample {
  static String? tupleStackString;
  static List<String> tupleStackList = [];
  static bool stringAndListMatch = false;

  static void example5StackTraceAsTuple() {
    try {
      _levelOne();
    } catch (e, stack) {
      final (stackString, stackList) = tomGetStackTraceAsTuple(stack, 3);
      tupleStackString = stackString;
      tupleStackList = stackList;
    }

    final tupleStringLineCount = tupleStackString?.split('\n').length ?? 0;
    final tupleListLength = tupleStackList.length;
    stringAndListMatch = tupleStringLineCount == tupleListLength;

    assert(tupleStackString != null, 'Tuple string should exist');
    assert(tupleStackList.isNotEmpty, 'Tuple list should not be empty');
    assert(stringAndListMatch, 'String lines and list length should match');
  }
}

// =============================================================================
// EXAMPLE 6: TomException Creation and Properties
// =============================================================================

class TomExceptionPropertiesExample {
  static String? exceptionKey;
  static String? exceptionMessage;
  static String? exceptionUuid;
  static String? exceptionRequestUuid;
  static Map<String, dynamic>? exceptionParameters;
  static bool hasTimestamp = false;
  static bool hasStackTrace = false;

  static void example6TomExceptionProperties() {
    final exception = TomException(
      'user.fetch.not_found',
      'The requested user could not be found',
      parameters: {'userId': 'user_123', 'searchType': 'byEmail'},
      requestUuid: 'req-456-789',
    );

    exceptionKey = exception.key;
    exceptionMessage = exception.defaultUserMessage;
    exceptionUuid = exception.uuid;
    exceptionRequestUuid = exception.requestUuid;
    exceptionParameters = exception.parameters;
    hasTimestamp = exception.timeStamp.isBefore(DateTime.now().add(Duration(seconds: 1)));
    hasStackTrace = exception.stackTrace.isNotEmpty;

    assert(exceptionKey == 'user.fetch.not_found', 'Key should match');
    assert(
      exceptionMessage == 'The requested user could not be found',
      'Message should match',
    );
    assert(exceptionUuid != null, 'UUID should exist');
    assert(exceptionRequestUuid == 'req-456-789', 'Request UUID should match');
    assert(
      exceptionParameters?['userId'] == 'user_123',
      'Parameters should contain userId',
    );
    assert(hasTimestamp, 'Should have valid timestamp');
    assert(hasStackTrace, 'Should have stack trace');
  }
}

// =============================================================================
// EXAMPLE 7: TomException with Custom UUID
// =============================================================================

class CustomUuidExceptionExample {
  static String? customExceptionUuid;
  static String? customExceptionKey;
  static bool uuidMatches = false;

  static void example7CustomUuidException() {
    const customUuid = 'custom-error-id-12345';
    final customException = TomException(
      'sample.custom_uuid.failed',
      'An error with custom UUID',
      uuid: customUuid,
    );

    customExceptionUuid = customException.uuid;
    customExceptionKey = customException.key;
    uuidMatches = customExceptionUuid == customUuid;

    assert(customExceptionUuid == customUuid, 'Custom UUID should match');
    assert(
      customExceptionKey == 'sample.custom_uuid.failed',
      'Key should match',
    );
    assert(uuidMatches, 'UUID should match');
  }
}

// =============================================================================
// EXAMPLE 8: TomException with Root Exception
// =============================================================================

class RootExceptionExample {
  static Object? rootException;
  static String? rootExceptionMessage;
  static bool hasRootException = false;

  static void example8RootException() {
    final originalError = ArgumentError('Invalid argument provided');
    final wrappedException = TomException(
      'sample.wrap.root_cause_attached',
      'Wrapped exception with root cause',
      rootException: originalError,
    );

    rootException = wrappedException.rootException;
    rootExceptionMessage = (rootException as ArgumentError?)?.message as String?;
    hasRootException = rootException != null;

    assert(hasRootException, 'Should have root exception');
    assert(
      rootExceptionMessage == 'Invalid argument provided',
      'Root exception message should match',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  SyncCheckedSuccessExample.example1SyncCheckedSuccess();
  SyncCheckedErrorExample.example2SyncCheckedError();
  StackTraceFormattingExample.example3StackTraceFormatting();
  StackTraceAsListExample.example4StackTraceAsList();
  StackTraceAsTupleExample.example5StackTraceAsTuple();
  TomExceptionPropertiesExample.example6TomExceptionProperties();
  CustomUuidExceptionExample.example7CustomUuidException();
  RootExceptionExample.example8RootException();
}

void main() => run();
