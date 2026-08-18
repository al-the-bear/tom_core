import 'package:test/test.dart';
import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// Deep call chain used to verify that a depth-limited trace keeps the frames
// nearest the throw site (the innermost frames), not the outermost ones. The
// distinction only becomes observable when the total stack is deeper than the
// requested depth, which is why a dedicated multi-level chain is needed.
void _deepLevelInnermost() => throw Exception('deep throw site');
void _deepLevelMiddle() => _deepLevelInnermost();
void _deepLevelOuter() => _deepLevelMiddle();

StackTrace _captureDeepStack() {
  try {
    _deepLevelOuter();
  } catch (_, stack) {
    return stack;
  }
  return StackTrace.current;
}

// Deep *asynchronous* call chain. Each level awaits before calling the next,
// so the captured trace is split by the runtime into one `Chain` segment per
// `await` boundary. A synchronous chain cannot exercise this: it produces a
// single segment, which is exactly why the truncation to `traces[0]` went
// unnoticed. The `await` before each call is load-bearing — without a real
// suspension the levels collapse into one segment again.
Future<void> _asyncLevelInnermost() async {
  await Future<void>.delayed(Duration.zero);
  throw Exception('async throw site');
}

Future<void> _asyncLevelMiddle() async {
  await Future<void>.delayed(Duration.zero);
  await _asyncLevelInnermost();
}

Future<void> _asyncLevelOuter() async {
  await Future<void>.delayed(Duration.zero);
  await _asyncLevelMiddle();
}

Future<StackTrace> _captureAsyncChainStack() async {
  try {
    await _asyncLevelOuter();
  } catch (_, stack) {
    return stack;
  }
  return StackTrace.current;
}

// A construction site with a name that appears nowhere else in the stack, so
// asserting on it proves the trace reached the code that created the exception
// rather than the machinery that later rendered it.
TomException _constructExceptionAtKnownSite() =>
    TomException('ERROR', 'constructed without an explicit stack');

// Named call sites for the implicit-capture tests: each calls a formatting
// function *without* a stack, so the trace is captured inside the formatter and
// this library's own frames are the newest ones on it. The wrapper names differ
// in case from the members they call (`_callerOfTomGetStackTrace` vs
// `tomGetStackTrace`), so asserting that a formatter member is absent cannot
// accidentally match the caller's own frame.
String _callerOfTomGetStackTrace() => tomGetStackTrace();

List<String> _callerOfTomGetStackTraceAsList([int depth = -1]) =>
    tomGetStackTraceAsList(null, depth);

(String, List<String>) _callerOfTomGetStackTraceAsTuple() =>
    tomGetStackTraceAsTuple();

void _callerOfTomPrintStackTrace() =>
    tomPrintStackTrace(null, message: 'IMPLICIT');

void main() {
  // =========================================================================
  // ZONE UTILITIES
  // =========================================================================

  group('getFromCurrentZone', () {
    test('should return null when no value exists in zone', () {
      final result = getFromCurrentZone<String>();
      expect(result, isNull);
    });

    test('should return typed value when stored in zone', () {
      runZoned(
        () {
          final result = getFromCurrentZone<String>();
          expect(result, equals('test-value'));
        },
        zoneValues: {String: 'test-value'},
      );
    });

    test('should return null when value type does not match', () {
      runZoned(
        () {
          final result = getFromCurrentZone<int>();
          expect(result, isNull);
        },
        zoneValues: {String: 'test-value'},
      );
    });

    test('should work with custom class types', () {
      final testConfig = _TestConfig('production', 8080);
      runZoned(
        () {
          final result = getFromCurrentZone<_TestConfig>();
          expect(result, isNotNull);
          expect(result!.environment, equals('production'));
          expect(result.port, equals(8080));
        },
        zoneValues: {_TestConfig: testConfig},
      );
    });

    test('should work with nested zones', () {
      runZoned(
        () {
          runZoned(
            () {
              final outer = getFromCurrentZone<String>();
              final inner = getFromCurrentZone<int>();
              expect(outer, equals('outer-value'));
              expect(inner, equals(42));
            },
            zoneValues: {int: 42},
          );
        },
        zoneValues: {String: 'outer-value'},
      );
    });

    test('should return innermost zone value when shadowed', () {
      runZoned(
        () {
          runZoned(
            () {
              final result = getFromCurrentZone<String>();
              expect(result, equals('inner-value'));
            },
            zoneValues: {String: 'inner-value'},
          );
        },
        zoneValues: {String: 'outer-value'},
      );
    });
  });

  group('getObjectFromCurrentZone', () {
    test('should return null when no value exists in zone', () {
      final result = getObjectFromCurrentZone(String);
      expect(result, isNull);
    });

    test('should return untyped value when stored in zone', () {
      runZoned(
        () {
          final result = getObjectFromCurrentZone(String);
          expect(result, equals('test-value'));
        },
        zoneValues: {String: 'test-value'},
      );
    });

    test('should return value without type checking', () {
      runZoned(
        () {
          final result = getObjectFromCurrentZone(_TestConfig);
          expect(result, isA<_TestConfig>());
        },
        zoneValues: {_TestConfig: _TestConfig('dev', 3000)},
      );
    });
  });

  // =========================================================================
  // CHECKED EXECUTION
  // =========================================================================

  group('runChecked', () {
    test('should return result when body succeeds', () async {
      final result = await runChecked(
        () async => 'success',
        (error, stack) => Exception('transformed'),
      );
      expect(result, equals('success'));
    });

    test('should transform error when body throws', () async {
      await expectLater(
        runChecked(
          () async => throw Exception('original'),
          (error, stack) => _CustomException('transformed: $error'),
        ),
        throwsA(isA<_CustomException>()),
      );
    });

    test('should pass original error to onError handler', () async {
      Object? capturedError;
      try {
        await runChecked(
          () async => throw FormatException('bad format'),
          (error, stack) {
            capturedError = error;
            return _CustomException('wrapped');
          },
        );
      } catch (_) {}

      expect(capturedError, isA<FormatException>());
    });

    test('should pass stack trace to onError handler', () async {
      StackTrace? capturedStack;
      try {
        await runChecked(
          () async => throw Exception('error'),
          (error, stack) {
            capturedStack = stack;
            return _CustomException('wrapped');
          },
        );
      } catch (_) {}

      expect(capturedStack, isNotNull);
      expect(capturedStack.toString(), contains('little_things_test.dart'));
    });

    test('should work with Future returning values', () async {
      final result = await runChecked(
        () => Future.delayed(Duration(milliseconds: 10), () => 42),
        (error, stack) => Exception('should not be called'),
      );
      expect(result, equals(42));
    });

    test('should work with async errors', () async {
      await expectLater(
        runChecked(
          () => Future.delayed(
            Duration(milliseconds: 10),
            () => throw StateError('async error'),
          ),
          (error, stack) => _CustomException('async transformed'),
        ),
        throwsA(isA<_CustomException>()),
      );
    });
  });

  group('runCheckedSync', () {
    test('should return result when body succeeds', () {
      final result = runCheckedSync(
        () => 'success',
        (error, stack) => Exception('transformed'),
      );
      expect(result, equals('success'));
    });

    test('should transform error when body throws', () {
      expect(
        () => runCheckedSync(
          () => throw Exception('original'),
          (error, stack) => _CustomException('transformed'),
        ),
        throwsA(isA<_CustomException>()),
      );
    });

    test('should pass original error to onError handler', () {
      Object? capturedError;
      try {
        runCheckedSync(
          () => throw ArgumentError('bad argument'),
          (error, stack) {
            capturedError = error;
            return _CustomException('wrapped');
          },
        );
      } catch (_) {}

      expect(capturedError, isA<ArgumentError>());
    });

    test('should pass stack trace to onError handler', () {
      StackTrace? capturedStack;
      try {
        runCheckedSync(
          () => throw Exception('error'),
          (error, stack) {
            capturedStack = stack;
            return _CustomException('wrapped');
          },
        );
      } catch (_) {}

      expect(capturedStack, isNotNull);
    });

    test('should work with complex return types', () {
      final result = runCheckedSync(
        () => {'key': 'value', 'count': 42},
        (error, stack) => Exception('should not be called'),
      );
      expect(result, equals({'key': 'value', 'count': 42}));
    });
  });

  // =========================================================================
  // STACK TRACE UTILITIES
  // =========================================================================

  group('tomGetStackTrace', () {
    test('should return non-empty string for current stack', () {
      final trace = tomGetStackTrace(StackTrace.current);
      expect(trace, isNotEmpty);
    });

    test('should return stack trace when passed null', () {
      final trace = tomGetStackTrace(null);
      expect(trace, isNotEmpty);
    });

    test('should respect depth limit', () {
      final limitedTrace = tomGetStackTrace(StackTrace.current, 2);
      final moreFrames = tomGetStackTrace(StackTrace.current, 5);
      expect(limitedTrace.split('\n').length, lessThanOrEqualTo(2));
      // More frames requested should return equal or more lines
      expect(
        moreFrames.split('\n').length,
        greaterThanOrEqualTo(limitedTrace.split('\n').length),
      );
    });

    test('should contain file location information', () {
      final trace = tomGetStackTrace(StackTrace.current);
      expect(trace, contains('little_things_test.dart'));
    });

    test('depth limit keeps the frames nearest the throw site', () {
      final stack = _captureDeepStack();
      // Sanity: the full trace contains the throwing frame.
      expect(tomGetStackTrace(stack), contains('_deepLevelInnermost'));
      // Truncating to a small depth must retain the frames nearest the error
      // (the throw site), not discard them in favour of the outermost frames.
      final limited = tomGetStackTrace(stack, 2);
      expect(limited.split('\n').length, lessThanOrEqualTo(2));
      expect(limited, contains('_deepLevelInnermost'));
    });
  });

  // =========================================================================
  // ASYNC CHAIN SEGMENTS
  //
  // An asynchronous trace is a *chain*: the runtime splits it into one segment
  // per `await` boundary. The caller's identity lives in the older segments,
  // so a formatter that keeps only the newest one reports where the error was
  // thrown but never where the work was started.
  // =========================================================================

  group('async chain segments', () {
    test('default depth keeps every segment of an async chain', () async {
      final stack = await _captureAsyncChainStack();
      final frames = tomGetStackTraceAsList(stack);

      // Every level of the chain must be represented. Before the fix only the
      // innermost survived: the chain was truncated to its newest segment.
      expect(frames.join('\n'), contains('_asyncLevelInnermost'));
      expect(frames.join('\n'), contains('_asyncLevelMiddle'));
      expect(frames.join('\n'), contains('_asyncLevelOuter'));
      expect(frames.join('\n'), contains('_captureAsyncChainStack'));
    });

    test('an async chain yields more than the one newest frame', () async {
      final stack = await _captureAsyncChainStack();
      // Four `await` boundaries, so at least four frames. The exact count is
      // not asserted: it depends on how the runtime folds the test harness's
      // own frames, which is not this module's contract.
      expect(tomGetStackTraceAsList(stack).length, greaterThanOrEqualTo(4));
    });

    test('depth truncates the flattened chain from the throw site', () async {
      final stack = await _captureAsyncChainStack();
      final limited = tomGetStackTraceAsList(stack, 2);

      // The depth limit applies across the whole flattened chain, and still
      // counts from the newest frame — so the throw site leads and the second
      // frame comes from the *next* segment, which flattening made reachable.
      expect(limited.length, equals(2));
      expect(limited[0], contains('_asyncLevelInnermost'));
      expect(limited[1], contains('_asyncLevelMiddle'));
    });

    test('a synchronous trace is unaffected by flattening', () {
      // A sync stack is a single-segment chain, so flattening must leave it
      // exactly as it was — this is the regression guard for the sync path.
      final frames = tomGetStackTraceAsList(_captureDeepStack());
      expect(frames.first, contains('_deepLevelInnermost'));
      expect(frames.join('\n'), contains('_deepLevelOuter'));
    });
  });

  group('tomGetStackTraceAsList', () {
    test('should return list of strings for current stack', () {
      final traceList = tomGetStackTraceAsList(StackTrace.current);
      expect(traceList, isA<List<String>>());
      expect(traceList, isNotEmpty);
    });

    test('should return stack trace list when passed null', () {
      final traceList = tomGetStackTraceAsList(null);
      expect(traceList, isNotEmpty);
    });

    test('should respect depth limit', () {
      final limitedList = tomGetStackTraceAsList(StackTrace.current, 2);
      final moreFrames = tomGetStackTraceAsList(StackTrace.current, 5);
      expect(limitedList.length, lessThanOrEqualTo(2));
      // More frames requested should return equal or more frames
      expect(moreFrames.length, greaterThanOrEqualTo(limitedList.length));
    });

    test('should return individual frame strings', () {
      final traceList = tomGetStackTraceAsList(StackTrace.current, 5);
      for (final frame in traceList) {
        expect(frame, isA<String>());
        expect(frame, isNotEmpty);
      }
    });
  });

  group('tomGetStackTraceAsTuple', () {
    test('should return both string and list representations', () {
      final (traceString, traceList) =
          tomGetStackTraceAsTuple(StackTrace.current);
      expect(traceString, isA<String>());
      expect(traceList, isA<List<String>>());
    });

    test('should have consistent data between string and list', () {
      final (traceString, traceList) =
          tomGetStackTraceAsTuple(StackTrace.current);
      final joinedList = traceList.join('\n');
      expect(traceString, equals(joinedList));
    });

    test('should respect depth limit in both representations', () {
      final (traceString, traceList) =
          tomGetStackTraceAsTuple(StackTrace.current, 2);
      expect(traceList.length, lessThanOrEqualTo(2));
      expect(traceString.split('\n').length, lessThanOrEqualTo(2));
    });

    test('should work when passed null', () {
      final (traceString, traceList) = tomGetStackTraceAsTuple(null);
      expect(traceString, isNotEmpty);
      expect(traceList, isNotEmpty);
    });
  });

  // =========================================================================
  // IMPLICIT CAPTURE
  //
  // When no stack is passed the trace is captured inside the formatter, so this
  // library's own formatting functions are the newest frames on it. They record
  // the act of formatting, never the failure, and must not reach the caller.
  // =========================================================================

  group('implicit capture folds the formatter away', () {
    // On the stack only because the capture happened inside this library.
    const formatterMembers = [
      'tomPrintStackTrace',
      'tomGetStackTraceAsList',
      'tomGetStackTraceAsTuple',
      'tomGetStackTrace',
      '_processStackFrames',
    ];

    test('tomGetStackTrace leads with the caller when given no argument', () {
      final first = _callerOfTomGetStackTrace().split('\n').first;
      expect(first, contains('_callerOfTomGetStackTrace'));
    });

    test('tomGetStackTraceAsList leads with the caller', () {
      expect(
        _callerOfTomGetStackTraceAsList().first,
        contains('_callerOfTomGetStackTraceAsList'),
      );
    });

    test('tomGetStackTraceAsTuple leads with the caller', () {
      final (traceString, traceList) = _callerOfTomGetStackTraceAsTuple();
      expect(traceList.first, contains('_callerOfTomGetStackTraceAsTuple'));
      expect(
        traceString.split('\n').first,
        contains('_callerOfTomGetStackTraceAsTuple'),
      );
    });

    test('no formatting function appears anywhere in the trace', () {
      final joined = _callerOfTomGetStackTraceAsList().join('\n');
      for (final member in formatterMembers) {
        expect(
          joined,
          isNot(contains(member)),
          reason: '$member is on the stack only because the trace was '
              'captured inside this library',
        );
      }
    });

    test('depth counts from the caller, not from the formatter', () {
      // The practical consequence of folding: a small depth on an implicitly
      // captured trace must be spent on the caller. Before the fix `depth: 1`
      // returned a formatter frame, so the whole budget went to this library.
      final frames = _callerOfTomGetStackTraceAsList(1);
      expect(frames, hasLength(1));
      expect(frames.single, contains('_callerOfTomGetStackTraceAsList'));
    });
  });

  // =========================================================================
  // FORMATTING UTILITIES
  // =========================================================================

  group('convertMinutesToUtcOffset', () {
    group('UTC (zero offset)', () {
      test('should return "Z" for zero minutes', () {
        expect(convertMinutesToUtcOffset(0), equals('Z'));
      });
    });

    group('positive offsets (east of UTC)', () {
      test('should return "+01:00" for 60 minutes', () {
        expect(convertMinutesToUtcOffset(60), equals('+01:00'));
      });

      test('should return "+05:30" for 330 minutes (IST)', () {
        expect(convertMinutesToUtcOffset(330), equals('+05:30'));
      });

      test('should return "+09:00" for 540 minutes (JST)', () {
        expect(convertMinutesToUtcOffset(540), equals('+09:00'));
      });

      test('should return "+12:00" for 720 minutes', () {
        expect(convertMinutesToUtcOffset(720), equals('+12:00'));
      });

      test('should return "+05:45" for 345 minutes (Nepal)', () {
        expect(convertMinutesToUtcOffset(345), equals('+05:45'));
      });

      test('should return "+14:00" for 840 minutes (Line Islands)', () {
        expect(convertMinutesToUtcOffset(840), equals('+14:00'));
      });
    });

    group('negative offsets (west of UTC)', () {
      test('should return "-05:00" for -300 minutes (EST)', () {
        expect(convertMinutesToUtcOffset(-300), equals('-05:00'));
      });

      test('should return "-08:00" for -480 minutes (PST)', () {
        expect(convertMinutesToUtcOffset(-480), equals('-08:00'));
      });

      test('should return "-03:30" for -210 minutes (Newfoundland)', () {
        expect(convertMinutesToUtcOffset(-210), equals('-03:30'));
      });

      test('should return "-12:00" for -720 minutes', () {
        expect(convertMinutesToUtcOffset(-720), equals('-12:00'));
      });

      test('should return "-01:00" for -60 minutes', () {
        expect(convertMinutesToUtcOffset(-60), equals('-01:00'));
      });
    });

    group('edge cases', () {
      test('should handle single digit hours with padding', () {
        expect(convertMinutesToUtcOffset(30), equals('+00:30'));
      });

      test('should handle single digit minutes with padding', () {
        expect(convertMinutesToUtcOffset(65), equals('+01:05'));
      });

      test('should handle 15-minute offsets', () {
        expect(convertMinutesToUtcOffset(315), equals('+05:15'));
      });

      test('should handle large positive offset', () {
        expect(convertMinutesToUtcOffset(780), equals('+13:00'));
      });

      test('should handle large negative offset', () {
        expect(convertMinutesToUtcOffset(-660), equals('-11:00'));
      });
    });
  });

  // =========================================================================
  // TomException
  // =========================================================================

  group('TomException', () {
    group('constructor', () {
      test('should create exception with required parameters', () {
        final exception = TomException('ERROR_CODE', 'Error message');
        expect(exception.key, equals('ERROR_CODE'));
        expect(exception.defaultUserMessage, equals('Error message'));
      });

      test('should generate UUID if not provided', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.uuid, isNotNull);
        expect(exception.uuid, isNotEmpty);
        expect(exception.uuid.length, equals(36)); // UUID format
      });

      test('should use provided UUID when specified', () {
        final customUuid = '12345678-1234-1234-1234-123456789012';
        final exception = TomException('ERROR', 'message', uuid: customUuid);
        expect(exception.uuid, equals(customUuid));
      });

      test('should set timestamp on creation', () {
        final before = DateTime.timestamp();
        final exception = TomException('ERROR', 'message');
        final after = DateTime.timestamp();

        expect(
          exception.timeStamp.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          exception.timeStamp.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('should store optional parameters', () {
        final params = {'userId': 123, 'action': 'delete'};
        final exception = TomException(
          'ERROR',
          'message',
          parameters: params,
        );
        expect(exception.parameters, equals(params));
      });

      test('should store request UUID', () {
        final exception = TomException(
          'ERROR',
          'message',
          requestUuid: 'request-123',
        );
        expect(exception.requestUuid, equals('request-123'));
      });

      test('should store root exception', () {
        final rootError = FormatException('original error');
        final exception = TomException(
          'WRAPPED_ERROR',
          'Wrapped error',
          rootException: rootError,
        );
        expect(exception.rootException, isA<FormatException>());
      });

      test('should capture stack trace', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.stackTrace, isNotEmpty);
      });

      test('should populate stack when none is passed', () {
        final exception = TomException('ERROR', 'message');
        expect(
          exception.stack,
          isNotNull,
          reason: 'the raw trace is what printStackTrace re-formats, so it '
              'has to exist even when the caller supplied none',
        );
      });

      test('should keep a provided stack unchanged', () {
        final provided = _captureDeepStack();
        final exception = TomException('ERROR', 'message', stack: provided);
        expect(exception.stack, same(provided));
      });

      test('should default autoLog to false', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.autoLog, isFalse);
      });
    });

    group('toString', () {
      test('should include uuid in string representation', () {
        final exception = TomException(
          'ERROR_CODE',
          'message',
          uuid: 'test-uuid-1234',
        );
        expect(exception.toString(), contains('test-uuid-1234'));
      });

      test('should include key in string representation', () {
        final exception = TomException('MY_ERROR_KEY', 'message');
        expect(exception.toString(), contains('MY_ERROR_KEY'));
      });

      test('should include message in string representation', () {
        final exception = TomException('ERROR', 'This is the error message');
        expect(exception.toString(), contains('This is the error message'));
      });

      test('should include runtime type in string representation', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.toString(), contains('TomException'));
      });

      test('should include parameters in string representation', () {
        final exception = TomException(
          'ERROR',
          'message',
          parameters: {'field': 'email'},
        );
        expect(exception.toString(), contains('field'));
        expect(exception.toString(), contains('email'));
      });

      test('should include request UUID in string representation', () {
        final exception = TomException(
          'ERROR',
          'message',
          requestUuid: 'req-uuid-5678',
        );
        expect(exception.toString(), contains('req-uuid-5678'));
      });
    });

    group('logRepresentation', () {
      test('should return same as toString', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.logRepresentation, equals(exception.toString()));
      });
    });

    group('implements Exception', () {
      test('should be throwable as Exception', () {
        expect(
          () => throw TomException('ERROR', 'test'),
          throwsA(isA<Exception>()),
        );
      });

      test('should be catchable as TomException', () {
        expect(
          () => throw TomException('ERROR', 'test'),
          throwsA(isA<TomException>()),
        );
      });
    });

    group('unique UUIDs', () {
      test('should generate different UUIDs for different instances', () {
        final exception1 = TomException('ERROR', 'message 1');
        final exception2 = TomException('ERROR', 'message 2');
        expect(exception1.uuid, isNot(equals(exception2.uuid)));
      });
    });

    group('edge cases', () {
      test('should handle empty key', () {
        final exception = TomException('', 'message');
        expect(exception.key, equals(''));
      });

      test('should handle empty message', () {
        final exception = TomException('ERROR', '');
        expect(exception.defaultUserMessage, equals(''));
      });

      test('should handle null parameters', () {
        final exception = TomException('ERROR', 'message', parameters: null);
        expect(exception.parameters, isNull);
      });

      test('should handle empty parameters map', () {
        final exception = TomException('ERROR', 'message', parameters: {});
        expect(exception.parameters, isEmpty);
      });

      test('should handle special characters in message', () {
        final message = 'Error: "value" contains <special> & chars\n\ttab';
        final exception = TomException('ERROR', message);
        expect(exception.defaultUserMessage, equals(message));
      });

      test('should handle unicode in parameters', () {
        final exception = TomException(
          'ERROR',
          'message',
          parameters: {'emoji': '🎉', 'chinese': '中文'},
        );
        expect(exception.parameters!['emoji'], equals('🎉'));
        expect(exception.parameters!['chinese'], equals('中文'));
      });
    });

    // -----------------------------------------------------------------------
    // autoLog branch (tests §4c)
    // -----------------------------------------------------------------------
    group('autoLog', () {
      late _CapturingLogOutput captured;
      late TomLogOutput previousOutput;

      setUp(() {
        captured = _CapturingLogOutput();
        previousOutput = tomLog.logOutput;
        tomLog.logOutput = captured;
      });

      tearDown(() {
        tomLog.logOutput = previousOutput;
      });

      test('should not log on construction when autoLog is false', () {
        TomException('ERROR', 'message');
        expect(captured.messages, isEmpty);
      });

      test('should log on construction when autoLog is true', () {
        TomException('CRITICAL', 'boom', autoLog: true);
        expect(captured.messages, isNotEmpty);
        expect(
          captured.messages.any((m) => m.contains('EXCEPTION:')),
          isTrue,
          reason: 'autoLog should emit an EXCEPTION log line',
        );
        expect(
          captured.messages.any((m) => m.contains('EXCEPTION_STACKTRACE:')),
          isTrue,
          reason: 'autoLog should emit an EXCEPTION_STACKTRACE log line',
        );
      });

      test('should include the exception details in the logged line', () {
        TomException('CRITICAL', 'database down', autoLog: true);
        expect(
          captured.messages.any((m) => m.contains('database down')),
          isTrue,
        );
      });
    });

    // -----------------------------------------------------------------------
    // serverCallError (tests §4d)
    // -----------------------------------------------------------------------
    group('serverCallError', () {
      test('should default to null', () {
        final exception = TomException('ERROR', 'message');
        expect(exception.serverCallError, isNull);
      });

      test('should store and expose a provided server call error', () {
        final sce = TomServerCallError(
          statusCode: 404,
          reasonPhrase: 'Not Found',
        );
        final exception = TomException(
          'HTTP_ERROR',
          'request failed',
          serverCallError: sce,
        );
        expect(exception.serverCallError, same(sce));
        expect(exception.serverCallError!.statusCode, equals(404));
        expect(exception.serverCallError!.reasonPhrase, equals('Not Found'));
      });
    });

    // -----------------------------------------------------------------------
    // printStackTrace (tests §4b)
    // -----------------------------------------------------------------------
    group('printStackTrace', () {
      late _CapturingLogOutput captured;
      late TomLogOutput previousOutput;

      setUp(() {
        captured = _CapturingLogOutput();
        previousOutput = tomLog.logOutput;
        tomLog.logOutput = captured;
      });

      tearDown(() {
        tomLog.logOutput = previousOutput;
      });

      test('should log a stack trace prefixed with the exception identity', () {
        final exception = TomException(
          'ERROR',
          'message',
          uuid: 'uuid-123',
          requestUuid: 'req-456',
        );
        exception.printStackTrace();
        expect(captured.messages, isNotEmpty);
        expect(
          captured.messages.any(
            (m) => m.contains('uuid-123-req-456 exception stacktrace'),
          ),
          isTrue,
        );
      });

      test('should log the construction site when no stack was passed', () {
        final exception = _constructExceptionAtKnownSite();
        exception.printStackTrace();

        // The whole point of the method: name the code that created the
        // exception. Before the fix the trace was captured inside the
        // formatter, so the record held only the formatter's own frames.
        expect(
          captured.messages.any(
            (m) => m.contains('_constructExceptionAtKnownSite'),
          ),
          isTrue,
          reason: 'printStackTrace must report where the exception was '
              'constructed, not where it was formatted',
        );
      });

      test('should reach the construction site directly below the '
          'constructor frame', () {
        final exception = _constructExceptionAtKnownSite();
        exception.printStackTrace(2);

        // The trace is captured inside the constructor, so `new TomException`
        // is genuinely the newest frame and the construction site is the one
        // below it. Pinning both positions keeps that ordering deliberate: it
        // is why a useful `depth` here starts at 2 rather than 1.
        final logged = captured.messages.last;
        expect(logged, contains('new TomException'));
        expect(logged, contains('_constructExceptionAtKnownSite'));
        expect(
          logged.indexOf('new TomException'),
          lessThan(logged.indexOf('_constructExceptionAtKnownSite')),
        );
      });

      test('should tolerate an exception built on an empty stack', () {
        // Wrapping code forwards whatever trace it caught, and an async error
        // created without one yields `StackTrace.empty`. Reporting such an
        // exception must not itself throw.
        final exception =
            TomException('ERROR', 'message', stack: StackTrace.empty);

        expect(exception.printStackTrace, returnsNormally);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test('should report no frames when the stack field holds a '
          'non-StackTrace value', () {
        // `stack` is inherited, public and mutable, so a value the formatter
        // cannot use still reaches this method even though the constructor no
        // longer accepts one. Surviving it matters more here than anywhere
        // else: this method runs *because* something already went wrong.
        final exception = TomException('ERROR', 'message');
        exception.stack = 'not a stack trace';

        expect(exception.printStackTrace, returnsNormally);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test('should report no frames when the stack field was cleared', () {
        final exception = TomException('ERROR', 'message');
        exception.stack = null;

        expect(exception.printStackTrace, returnsNormally);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test('should not substitute the reporting site for an unusable stack',
          () {
        final exception = TomException('ERROR', 'message');
        exception.stack = 42;
        exception.printStackTrace();

        // Capturing `StackTrace.current` as a fallback would print the call
        // path of the *report*, which names none of the code that failed —
        // a plausible-looking trace pointing at the wrong place. An unusable
        // stack means no trace is known, so none is shown.
        expect(captured.messages.last, isNot(contains('printStackTrace')));
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test('should prefer an explicitly passed stack over the capture', () {
        final exception = TomException(
          'ERROR',
          'message',
          stack: _captureDeepStack(),
        );
        exception.printStackTrace();

        // An explicit stack is the caller's considered choice — the automatic
        // capture must never override it.
        expect(
          captured.messages.any((m) => m.contains('_deepLevelInnermost')),
          isTrue,
        );
      });

      test('should respect the depth argument', () {
        final exception = TomException('ERROR', 'message');
        exception.printStackTrace(0);
        // With depth 0 the trace portion is empty, so only the prefix message
        // remains — i.e. no stack-frame location lines are appended.
        expect(captured.messages, isNotEmpty);
        expect(
          captured.messages.last.trim(),
          endsWith('exception stacktrace'),
        );
      });
    });
  });

  // =========================================================================
  // tomPrintStackTrace (tests §4a)
  // =========================================================================

  group('tomPrintStackTrace', () {
    late _CapturingLogOutput captured;
    late TomLogOutput previousOutput;

    setUp(() {
      captured = _CapturingLogOutput();
      previousOutput = tomLog.logOutput;
      tomLog.logOutput = captured;
    });

    tearDown(() {
      tomLog.logOutput = previousOutput;
    });

    test('should log the stack trace via tomLog.error', () {
      tomPrintStackTrace(StackTrace.current);
      expect(captured.messages, isNotEmpty);
      expect(
        captured.messages.any((m) => m.contains('little_things_test.dart')),
        isTrue,
      );
    });

    test('should prefix the log entry with the message when provided', () {
      tomPrintStackTrace(StackTrace.current, message: 'CONTEXT_PREFIX');
      expect(
        captured.messages.any((m) => m.startsWith('CONTEXT_PREFIX')),
        isTrue,
      );
    });

    test('should log the caller when given no stack', () {
      _callerOfTomPrintStackTrace();

      // The most common call shape — `tomPrintStackTrace(null, ...)` — used to
      // log nothing but this library's own three formatting frames, which name
      // the printer rather than the code that wanted the trace printed.
      final logged = captured.messages.last;
      expect(logged, contains('_callerOfTomPrintStackTrace'));
      expect(logged, isNot(contains('_processStackFrames')));
    });

    test('should log the message alone for an empty trace', () {
      tomPrintStackTrace(StackTrace.empty, message: 'EMPTY_TRACE');

      // Logging must still happen: the message is the caller's context, and
      // losing it because the trace was empty would hide the error entirely.
      expect(captured.messages, isNotEmpty);
      expect(captured.messages.last.trim(), equals('EMPTY_TRACE'));
    });

    test('should pass the depth limit through to the trace', () {
      tomPrintStackTrace(StackTrace.current, message: 'P', depth: 0);
      // depth 0 yields an empty trace, so the logged entry is just the prefix
      // (plus the joining space) — no frame location lines.
      expect(captured.messages, isNotEmpty);
      expect(captured.messages.last.trim(), equals('P'));
    });
  });

  // =========================================================================
  // depth == 0 boundary (tests §4e)
  // =========================================================================

  // =========================================================================
  // EMPTY TRACES
  //
  // `StackTrace.empty` is not a contrived value. Dart hands that exact object
  // to a catch clause whenever the error was created without a trace — a
  // `Future.error` or a `Completer.completeError` given only an error object.
  // Since this module exists to run on the error path, it has to render such a
  // trace as "nothing" rather than fail while reporting a failure.
  // =========================================================================

  group('empty stack traces', () {
    test('tomGetStackTrace returns an empty string', () {
      expect(tomGetStackTrace(StackTrace.empty), isEmpty);
    });

    test('tomGetStackTraceAsList returns an empty list', () {
      expect(tomGetStackTraceAsList(StackTrace.empty), isEmpty);
    });

    test('tomGetStackTraceAsTuple returns both representations empty', () {
      final (traceString, traceList) =
          tomGetStackTraceAsTuple(StackTrace.empty);
      expect(traceString, isEmpty);
      expect(traceList, isEmpty);
    });

    test('a depth limit on an empty trace yields an empty result', () {
      // Asking for frames that do not exist is not an error: the limit caps
      // the result, it does not promise to fill it.
      expect(tomGetStackTraceAsList(StackTrace.empty, 5), isEmpty);
    });

    test('an async error carrying no trace is formatted, not thrown on',
        () async {
      // The situation the empty case exists for, reproduced end to end rather
      // than asserted against the constant — this is what makes the test a
      // guard on real behaviour instead of on a chosen input.
      late StackTrace caught;
      try {
        await Future<void>.error(Exception('created without a trace'));
      } catch (_, stack) {
        caught = stack;
      }

      expect(caught, same(StackTrace.empty));
      expect(() => tomGetStackTraceAsList(caught), returnsNormally);
      expect(tomGetStackTraceAsList(caught), isEmpty);
    });
  });

  group('stack trace depth == 0', () {
    test('tomGetStackTraceAsList returns empty for depth 0', () {
      final list = tomGetStackTraceAsList(StackTrace.current, 0);
      expect(list, isEmpty);
    });

    test('tomGetStackTrace returns empty string for depth 0', () {
      final trace = tomGetStackTrace(StackTrace.current, 0);
      expect(trace, isEmpty);
    });

    test('tomGetStackTraceAsTuple returns empty for depth 0', () {
      final (traceString, traceList) =
          tomGetStackTraceAsTuple(StackTrace.current, 0);
      expect(traceString, isEmpty);
      expect(traceList, isEmpty);
    });
  });

  // =========================================================================
  // STACK PARAMETER TYPE
  //
  // The formatting functions take `StackTrace?`, not `Object?`. The wider type
  // admitted values the formatter could not use and turned them into a
  // `TypeError` at the cast — raised while reporting some *other* failure, and
  // in `TomException`'s case before the exception object existed at all. The
  // narrow type moves that error to compile time, where it costs nothing.
  // =========================================================================

  group('stack parameter type', () {
    // Assertions on the function type rather than on calls: what changed is
    // what the signature *refuses*, and a refused call cannot appear in a test
    // that has to compile. The negative half carries the weight — a function
    // taking `Object?` also satisfies `StackTrace?` by contravariance, so only
    // `isNot` distinguishes the two.
    test('tomGetStackTrace declares StackTrace?, not Object?', () {
      expect(tomGetStackTrace, isA<String Function([StackTrace?, int])>());
      expect(tomGetStackTrace, isNot(isA<String Function([Object?, int])>()));
    });

    test('tomGetStackTraceAsList declares StackTrace?, not Object?', () {
      expect(
        tomGetStackTraceAsList,
        isA<List<String> Function([StackTrace?, int])>(),
      );
      expect(
        tomGetStackTraceAsList,
        isNot(isA<List<String> Function([Object?, int])>()),
      );
    });

    test('tomGetStackTraceAsTuple declares StackTrace?, not Object?', () {
      expect(
        tomGetStackTraceAsTuple,
        isA<(String, List<String>) Function([StackTrace?, int])>(),
      );
      expect(
        tomGetStackTraceAsTuple,
        isNot(isA<(String, List<String>) Function([Object?, int])>()),
      );
    });

    test('tomPrintStackTrace declares StackTrace?, not Object?', () {
      expect(
        tomPrintStackTrace,
        isA<void Function(StackTrace?, {String? message, int depth})>(),
      );
      expect(
        tomPrintStackTrace,
        isNot(isA<void Function(Object?, {String? message, int depth})>()),
      );
    });
  });
}

// =============================================================================
// TEST HELPER CLASSES
// =============================================================================

/// Test configuration class for zone value testing.
class _TestConfig {
  final String environment;
  final int port;

  _TestConfig(this.environment, this.port);
}

/// Custom exception for error transformation tests.
class _CustomException implements Exception {
  final String message;

  _CustomException(this.message);

  @override
  String toString() => 'CustomException: $message';
}

/// Log output that records every emitted message so log side-effects
/// (autoLog, printStackTrace, tomPrintStackTrace) can be asserted.
class _CapturingLogOutput extends TomLogOutput {
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
