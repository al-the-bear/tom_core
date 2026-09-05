/// Demonstrates utility functions from the little_things module including
/// checked execution, stack trace processing, and exception handling.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

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
  static int unlimitedLineCount = 0;
  static List<String> capturedLines = const [];

  static void example3StackTraceFormatting() {
    try {
      _levelOne();
    } catch (e, stack) {
      capturedStackTrace = tomGetStackTrace(stack, 5);
      // The same trace with no limit, to show what the limit removed. Asked
      // for after the limited one so both describe the very same stack.
      unlimitedLineCount = tomGetStackTrace(stack).split('\n').length;
    }

    capturedLines = capturedStackTrace?.split('\n') ?? const [];
    stackLineCount = capturedLines.length;

    assert(capturedStackTrace != null, 'Should capture stack trace');
    // The depth is a frame count, not a ceiling — so this is `==`, not `<=`.
    // An upper bound would also hold for a single frame, which is what a
    // truncating formatter returns; it would report the bug as success.
    assert(
      unlimitedLineCount > 5,
      'The chain must be deeper than the limit, or the count proves nothing',
    );
    assert(stackLineCount == 5, 'Depth 5 must yield exactly 5 frames');
    // Truncation keeps the frames nearest the throw site, in that order.
    assert(
      capturedLines[0].contains('_levelThree'),
      'The throw site must lead the trace',
    );
    assert(capturedLines[1].contains('_levelTwo'), 'Then its caller');
    assert(capturedLines[2].contains('_levelOne'), 'Then the caller above it');
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
    hasTimestamp = exception.timeStamp.isBefore(
      DateTime.now().add(Duration(seconds: 1)),
    );
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
    rootExceptionMessage =
        (rootException as ArgumentError?)?.message as String?;
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

/// Renders one formatted frame short enough to read in a terminal.
///
/// A frame repeats the source path at both ends of the line; the middle names
/// the position and the member, which is the part that identifies the frame.
String _frameSummary(String frame) {
  final parts = frame.split(' ');
  return parts.length > 2
      ? parts.sublist(1, parts.length - 1).join(' ')
      : frame;
}

void run() {
  print('=== 01: Utility Functions Example ===\n');

  SyncCheckedSuccessExample.example1SyncCheckedSuccess();
  print('1. runCheckedSync hands back the body result when the body works:');
  print('   parsed name      : ${SyncCheckedSuccessExample.parsedName}');
  print('   parsed value     : ${SyncCheckedSuccessExample.parsedValue}');
  print('   parsing succeeded: ${SyncCheckedSuccessExample.parsingSuccessful}');
  print('');

  SyncCheckedErrorExample.example2SyncCheckedError();
  print('2. A throwing body is turned into the TomException you supplied:');
  print('   exception key    : ${SyncCheckedErrorExample.caughtErrorKey}');
  print('   user message     : ${SyncCheckedErrorExample.caughtErrorMessage}');
  print('   root exception   : ${SyncCheckedErrorExample.rootExceptionType}');
  print('   exception caught : ${SyncCheckedErrorExample.exceptionCaught}');
  print('');

  StackTraceFormattingExample.example3StackTraceFormatting();
  print('3. tomGetStackTrace formats a trace and caps it at a frame count:');
  print(
    '   frames unlimited : '
    '${StackTraceFormattingExample.unlimitedLineCount}',
  );
  print('   frames at depth 5: ${StackTraceFormattingExample.stackLineCount}');
  print('   the kept frames, nearest the throw site first:');
  for (final frame in StackTraceFormattingExample.capturedLines) {
    print('     ${_frameSummary(frame)}');
  }
  print('');

  StackTraceAsListExample.example4StackTraceAsList();
  print('4. tomGetStackTraceAsList returns the frames already split:');
  print('   frame count      : ${StackTraceAsListExample.frameCount}');
  print(
    '   first frame      : '
    '${_frameSummary(StackTraceAsListExample.firstFrame ?? '')}',
  );
  print('');

  StackTraceAsTupleExample.example5StackTraceAsTuple();
  final tupleFirstLine =
      StackTraceAsTupleExample.tupleStackString?.split('\n').first ?? '';
  print('5. tomGetStackTraceAsTuple returns both shapes of the same trace:');
  print(
    '   list frame count : '
    '${StackTraceAsTupleExample.tupleStackList.length}',
  );
  print('   string first line: ${_frameSummary(tupleFirstLine)}');
  print(
    '   string and list agree: '
    '${StackTraceAsTupleExample.stringAndListMatch}',
  );
  print('');

  TomExceptionPropertiesExample.example6TomExceptionProperties();
  print('6. What a TomException carries once constructed:');
  print('   key              : ${TomExceptionPropertiesExample.exceptionKey}');
  print(
    '   user message     : '
    '${TomExceptionPropertiesExample.exceptionMessage}',
  );
  print('   uuid             : ${TomExceptionPropertiesExample.exceptionUuid}');
  print(
    '   request uuid     : '
    '${TomExceptionPropertiesExample.exceptionRequestUuid}',
  );
  print(
    '   parameters       : '
    '${TomExceptionPropertiesExample.exceptionParameters}',
  );
  print(
    '   has timestamp / stack trace: '
    '${TomExceptionPropertiesExample.hasTimestamp} / '
    '${TomExceptionPropertiesExample.hasStackTrace}',
  );
  print('');

  CustomUuidExceptionExample.example7CustomUuidException();
  print('7. A caller-supplied uuid is kept instead of a generated one:');
  print(
    '   key              : ${CustomUuidExceptionExample.customExceptionKey}',
  );
  print(
    '   uuid             : ${CustomUuidExceptionExample.customExceptionUuid}',
  );
  print('   uuid was kept    : ${CustomUuidExceptionExample.uuidMatches}');
  print('');

  RootExceptionExample.example8RootException();
  print('8. The original error stays reachable as the root exception:');
  print('   root exception   : ${RootExceptionExample.rootException}');
  print('   its message      : ${RootExceptionExample.rootExceptionMessage}');
  print('   root attached    : ${RootExceptionExample.hasRootException}');
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
