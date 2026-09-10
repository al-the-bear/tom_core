import 'package:test/test.dart';
import 'dart:async';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

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
    TomException('test.error.key', 'constructed without an explicit stack');

// The same, one level down the hierarchy: `TomFormattingException` extends
// `TomException`, so an auto-captured trace carries both constructors.
TomFormattingException _constructSubclassAtKnownSite() =>
    TomFormattingException('test.error.sub', 'constructed by a subclass');

// An ordinary application type that raises from its own constructor. Its frame
// occupies the same position a subclass constructor would, and must survive.
class _ThrowingAppType {
  _ThrowingAppType() {
    throw TomException('test.error.app', 'raised inside a constructor');
  }
}

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
      runZoned(() {
        final result = getFromCurrentZone<String>();
        expect(result, equals('test-value'));
      }, zoneValues: {String: 'test-value'});
    });

    test(
      'should return null when no value is stored under the requested key',
      () {
        runZoned(() {
          // Nothing is stored under `int`, so this returns null at the key
          // lookup — the `is T` guard never runs. Distinguished from the test
          // below, which exercises the guard instead.
          final result = getFromCurrentZone<int>();
          expect(result, isNull);
        }, zoneValues: {String: 'test-value'});
      },
    );

    test('should return null when the value under the key is not a T', () {
      runZoned(() {
        // The key *is* present, so this reaches the `is T` guard — the
        // second and weaker of the two filters. `getObjectFromCurrentZone`
        // has no guard and hands the same value back, which is what makes
        // the two filters distinguishable.
        expect(getFromCurrentZone<String>(), isNull);
        expect(getObjectFromCurrentZone(String), equals(42));
      }, zoneValues: {String: 42});
    });

    test('should work with custom class types', () {
      final testConfig = _TestConfig('production', 8080);
      runZoned(() {
        final result = getFromCurrentZone<_TestConfig>();
        expect(result, isNotNull);
        expect(result!.environment, equals('production'));
        expect(result.port, equals(8080));
      }, zoneValues: {_TestConfig: testConfig});
    });

    test('should work with nested zones', () {
      runZoned(() {
        runZoned(() {
          final outer = getFromCurrentZone<String>();
          final inner = getFromCurrentZone<int>();
          expect(outer, equals('outer-value'));
          expect(inner, equals(42));
        }, zoneValues: {int: 42});
      }, zoneValues: {String: 'outer-value'});
    });

    test('should return innermost zone value when shadowed', () {
      runZoned(() {
        runZoned(() {
          final result = getFromCurrentZone<String>();
          expect(result, equals('inner-value'));
        }, zoneValues: {String: 'inner-value'});
      }, zoneValues: {String: 'outer-value'});
    });
  });

  group('getObjectFromCurrentZone', () {
    test('should return null when no value exists in zone', () {
      final result = getObjectFromCurrentZone(String);
      expect(result, isNull);
    });

    test('should return untyped value when stored in zone', () {
      runZoned(() {
        final result = getObjectFromCurrentZone(String);
        expect(result, equals('test-value'));
      }, zoneValues: {String: 'test-value'});
    });

    test('should return value without type checking', () {
      runZoned(() {
        final result = getObjectFromCurrentZone(_TestConfig);
        expect(result, isA<_TestConfig>());
      }, zoneValues: {_TestConfig: _TestConfig('dev', 3000)});
    });

    test('should key on the exact Type, like getFromCurrentZone', () {
      runZoned(() {
        // Dropping the `is T` guard does not relax the key lookup: the
        // untyped accessor is exactly as exact-key as the typed one.
        expect(getObjectFromCurrentZone(_ZoneDerived), isNotNull);
        expect(getObjectFromCurrentZone(_ZoneBase), isNull);
      }, zoneValues: {_ZoneDerived: _ZoneDerived()});
    });
  });

  // =========================================================================
  // ZONE KEY IDENTITY
  //
  // `Zone.current[T]` is a map lookup on the `Type` object `T`, so the key is
  // matched by identity and not by assignability. That is the *first* filter
  // and the stricter one; the `is T` guard that follows can only ever narrow
  // what the key already found. A reader who knows only about the guard
  // concludes that any stored value satisfying `is T` will be found, which is
  // false in every case below.
  //
  // These tests pin the contract down because it is invisible at the call
  // site: a mismatched key is not a type error and not an exception, only a
  // silent null.
  // =========================================================================

  group('zone key identity', () {
    test(
      'a value stored under a subtype key is invisible to its supertype',
      () {
        runZoned(() {
          expect(getFromCurrentZone<_ZoneDerived>(), isNotNull);
          // A `_ZoneDerived` *is* a `_ZoneBase`, so the `is T` guard would
          // admit it. The key lookup never gets that far.
          expect(getFromCurrentZone<_ZoneBase>(), isNull);
        }, zoneValues: {_ZoneDerived: _ZoneDerived()});
      },
    );

    test(
      'a value stored under a supertype key is invisible to its subtype',
      () {
        runZoned(() {
          // The stored object is a `_ZoneDerived`, but it was filed under
          // `_ZoneBase`. Asking for the runtime type of the value one holds is
          // the natural mistake, and it fails.
          expect(getFromCurrentZone<_ZoneBase>()?.name, equals('derived'));
          expect(getFromCurrentZone<_ZoneDerived>(), isNull);
        }, zoneValues: {_ZoneBase: _ZoneDerived()});
      },
    );

    test(
      'an implementation key is invisible to the interface it implements',
      () {
        runZoned(() {
          expect(getFromCurrentZone<_ZoneService>(), isNull);
        }, zoneValues: {_ZoneServiceImpl: _ZoneServiceImpl()});
      },
    );

    test('Object is not a wildcard key', () {
      runZoned(() {
        // Every stored value is an `Object`, so a subtype-scanning lookup
        // would return the first one. This is the sharpest demonstration
        // that no scanning happens.
        expect(getFromCurrentZone<Object>(), isNull);
      }, zoneValues: {String: 'stored'});
    });

    test('a nullable type argument is a different key from its base type', () {
      runZoned(() {
        expect(getFromCurrentZone<String>(), equals('stored'));
        // `String?` and `String` are different `Type` objects. Writing the
        // nullable form because the *result* is nullable is an easy slip,
        // and it never finds anything.
        expect(getFromCurrentZone<String?>(), isNull);
      }, zoneValues: {String: 'stored'});
    });

    test('type arguments are part of the key', () {
      runZoned(
        () {
          expect(getFromCurrentZone<List<int>>(), equals([1, 2]));
          // Neither the raw type nor a supertype instantiation matches, even
          // though `List<int>` is assignable to both.
          expect(getFromCurrentZone<List>(), isNull);
          expect(getFromCurrentZone<List<num>>(), isNull);
        },
        zoneValues: {
          List<int>: <int>[1, 2],
        },
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
        await runChecked(() async => throw FormatException('bad format'), (
          error,
          stack,
        ) {
          capturedError = error;
          return _CustomException('wrapped');
        });
      } catch (_) {}

      expect(capturedError, isA<FormatException>());
    });

    test('should pass stack trace to onError handler', () async {
      StackTrace? capturedStack;
      try {
        await runChecked(() async => throw Exception('error'), (error, stack) {
          capturedStack = stack;
          return _CustomException('wrapped');
        });
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

    test('should work with an exception raised after an await', () async {
      await expectLater(
        runChecked(
          () => Future.delayed(
            Duration(milliseconds: 10),
            () => throw FormatException('async failure'),
          ),
          (error, stack) => _CustomException('async transformed'),
        ),
        throwsA(isA<_CustomException>()),
      );
    });
  });

  group('runChecked and Error', () {
    // Dart's own distinction: an `Exception` reports a condition the program is
    // expected to handle, an `Error` reports a fault in the program itself.
    // Translating the second kind turns a bug into a domain failure the caller
    // then treats as an ordinary outcome, reported at the wrong layer under a
    // message describing something else.

    test('an Error propagates instead of reaching onError', () async {
      var handlerRan = false;

      await expectLater(
        runChecked(() async => throw StateError('a bug'), (error, stack) {
          handlerRan = true;
          return _CustomException('wrapped');
        }),
        throwsA(isA<StateError>()),
      );
      expect(handlerRan, isFalse);
    });

    test('an Error raised after an await propagates too', () async {
      await expectLater(
        runChecked(
          () => Future.delayed(
            Duration(milliseconds: 10),
            () => throw RangeError('index out of range'),
          ),
          (error, stack) => _CustomException('wrapped'),
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('the sync form refuses an Error the same way', () {
      var handlerRan = false;

      expect(
        () => runCheckedSync<int>(() => throw ArgumentError('a bug'), (
          error,
          stack,
        ) {
          handlerRan = true;
          return _CustomException('wrapped');
        }),
        throwsA(isA<ArgumentError>()),
      );
      expect(handlerRan, isFalse);
    });

    test('a thrown object that is neither propagates as well', () {
      // `on Exception` states the contract in the type. Anything else a body
      // throws is left alone rather than being given a second meaning here.
      expect(
        () => runCheckedSync<int>(
          () => throw 'a bare string',
          (error, stack) => _CustomException('wrapped'),
        ),
        throwsA(isA<String>()),
      );
    });

    test('an Exception thrown beside an Error is still translated', () {
      // The narrowing must not have cost the wrapper its purpose.
      expect(
        () => runCheckedSync<int>(
          () => throw FormatException('bad input'),
          (error, stack) => _CustomException('wrapped'),
        ),
        throwsA(isA<_CustomException>()),
      );
    });

    test('the replacement is catchable by its own type', () {
      // The point of translating at all. `onError` returns an `Exception`, so
      // whatever it produces is something a caller can name in an `on` clause.
      expect(
        () => runCheckedSync<int>(
          () => throw FormatException('bad input'),
          (error, stack) => TomException('catalog.parse.invalid', 'Invalid'),
        ),
        throwsA(
          isA<TomException>().having(
            (e) => e.key,
            'key',
            'catalog.parse.invalid',
          ),
        ),
      );
    });

    test('onError is declared to return an Exception', () {
      // `Object` let a transform return `42`, and the wrapper then threw the
      // integer — a failure no `on SomeException catch` clause can ever match,
      // reaching the top of the isolate as an unhandled `int`. The narrowing
      // is the compiler's, so it is asserted against the declarations: this
      // fails the moment either signature widens again.
      const path = 'lib/src/tombase/little_things/little_things.dart';
      final source = File(path).readAsStringSync();

      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Expected to find $path relative to ${Directory.current.path}',
      );
      expect(
        source,
        contains(
          '  Exception Function(Object error, StackTrace stacktrace) onError,',
        ),
      );
      expect(
        source,
        isNot(
          contains(
            '  Object Function(Object error, StackTrace stacktrace) onError,',
          ),
        ),
      );
    });

    test('absence is a condition, so a body says so with an Exception', () {
      // The pattern the narrowing asks a caller to write instead of relying on
      // `.first` throwing StateError for an empty result.
      List<String> rows = const [];

      expect(
        () => runCheckedSync<String>(() {
          if (rows.isEmpty) {
            throw TomException('catalog.find.no_match', 'Nothing matched');
          }
          return rows.first;
        }, (error, stack) => _CustomException('not found')),
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
        runCheckedSync(() => throw FormatException('bad input'), (
          error,
          stack,
        ) {
          capturedError = error;
          return _CustomException('wrapped');
        });
      } catch (_) {}

      expect(capturedError, isA<FormatException>());
    });

    test('should pass stack trace to onError handler', () {
      StackTrace? capturedStack;
      try {
        runCheckedSync(() => throw Exception('error'), (error, stack) {
          capturedStack = stack;
          return _CustomException('wrapped');
        });
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

    test('depth yields exactly that many frames', () {
      final stack = _captureDeepStack();
      // Non-vacuity guard. An exact count only says something about truncation
      // if the untruncated trace is deeper than the limit — otherwise the
      // assertion is really about how deep the test harness happens to be.
      // Assert the premise rather than assume it, so a shallower stack fails
      // here with a clear cause instead of one line further down.
      expect(tomGetStackTrace(stack).split('\n').length, greaterThan(5));

      // `equals`, not `lessThanOrEqualTo`: an upper bound is satisfied by a
      // formatter that returns a single frame, which is exactly the truncation
      // this suite failed to catch once already.
      expect(tomGetStackTrace(stack, 2).split('\n'), hasLength(2));
      expect(tomGetStackTrace(stack, 5).split('\n'), hasLength(5));
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
      final limited = tomGetStackTrace(stack, 2).split('\n');
      expect(limited, hasLength(2));
      // Asserted positionally: `contains` over the whole string would also
      // pass for a trace that kept the throw site and dropped everything else.
      expect(limited[0], contains('_deepLevelInnermost'));
      expect(limited[1], contains('_deepLevelMiddle'));
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

      // Every level of the chain must be represented. Reading only the newest
      // Chain segment would leave the innermost level and nothing else.
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

    // The two tests below repeat that assertion for the string and tuple
    // forms. They are not redundant with the list-form one: all three share
    // `_processStackFrames`, but only the list form returns it untouched —
    // the string form joins on `\n` and the tuple form does both, so a
    // regression in either wrapper is invisible to the list-form test. An
    // async stack is the case that matters, because it is the multi-segment
    // one, and it is where the truncation to the newest segment hid.
    test('depth truncates an async chain in the string form', () async {
      final stack = await _captureAsyncChainStack();
      final limited = tomGetStackTrace(stack, 2).split('\n');
      expect(limited, hasLength(2));
      expect(limited[0], contains('_asyncLevelInnermost'));
      expect(limited[1], contains('_asyncLevelMiddle'));
    });

    test('depth truncates an async chain in the tuple form', () async {
      final stack = await _captureAsyncChainStack();
      final (traceString, traceList) = tomGetStackTraceAsTuple(stack, 2);
      expect(traceList, hasLength(2));
      expect(traceString.split('\n'), hasLength(2));
      expect(traceList[0], contains('_asyncLevelInnermost'));
      expect(traceList[1], contains('_asyncLevelMiddle'));
    });

    test(
      'an exception carries every segment in its stackTrace string',
      () async {
        // The two representations are rendered by one formatter, so the string
        // an exception stores has to carry the whole chain too — not only the
        // traces the formatting functions are asked for by name. This is the
        // path an `autoLog` line takes, and the one a reader of
        // `EXCEPTION_STACKTRACE` sees.
        final stack = await _captureAsyncChainStack();
        final exception = TomException(
          'test.async.chain',
          'boom',
          stack: stack,
        );

        expect(exception.stackTrace, contains('_asyncLevelInnermost'));
        expect(exception.stackTrace, contains('_asyncLevelMiddle'));
        expect(exception.stackTrace, contains('_asyncLevelOuter'));
        expect(exception.stackTrace, tomGetStackTrace(exception.stack));
      },
    );

    test('the log path reports every segment too', () async {
      // The three read-back forms share `_processStackFrames`, but the logging
      // path composes its own line around the result, and nothing else covers
      // a multi-segment trace through it.
      final captured = _CapturingLogOutput();
      final previousOutput = tomLog.logOutput;
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previousOutput);

      tomPrintStackTrace(await _captureAsyncChainStack(), message: 'failed');

      final logged = captured.messages.last;
      expect(logged, startsWith('failed'));
      expect(logged, contains('_asyncLevelInnermost'));
      expect(logged, contains('_asyncLevelMiddle'));
      expect(logged, contains('_asyncLevelOuter'));
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

    test('depth yields exactly that many frames', () {
      final stack = _captureDeepStack();
      // Non-vacuity guard — see the identically named test above.
      expect(tomGetStackTraceAsList(stack).length, greaterThan(5));

      expect(tomGetStackTraceAsList(stack, 2), hasLength(2));
      expect(tomGetStackTraceAsList(stack, 5), hasLength(5));

      // The count alone still admits any three frames; naming them pins the
      // order too, which is the property truncation actually has to preserve.
      final limited = tomGetStackTraceAsList(stack, 3);
      expect(limited[0], contains('_deepLevelInnermost'));
      expect(limited[1], contains('_deepLevelMiddle'));
      expect(limited[2], contains('_deepLevelOuter'));
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
      final (traceString, traceList) = tomGetStackTraceAsTuple(
        StackTrace.current,
      );
      expect(traceString, isA<String>());
      expect(traceList, isA<List<String>>());
    });

    test('should have consistent data between string and list', () {
      final (traceString, traceList) = tomGetStackTraceAsTuple(
        StackTrace.current,
      );
      final joinedList = traceList.join('\n');
      expect(traceString, equals(joinedList));
    });

    test('depth yields exactly that many frames in both representations', () {
      final stack = _captureDeepStack();
      // Non-vacuity guard — see `tomGetStackTrace`'s depth test.
      expect(tomGetStackTraceAsTuple(stack).$2.length, greaterThan(5));

      final (traceString, traceList) = tomGetStackTraceAsTuple(stack, 3);
      expect(traceList, hasLength(3));
      expect(traceString.split('\n'), hasLength(3));
      expect(traceList[0], contains('_deepLevelInnermost'));
      expect(traceList[1], contains('_deepLevelMiddle'));
      expect(traceList[2], contains('_deepLevelOuter'));
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
          reason:
              '$member is on the stack only because the trace was '
              'captured inside this library',
        );
      }
    });

    test('depth counts from the caller, not from the formatter', () {
      // The practical consequence of folding: a small depth on an implicitly
      // captured trace must be spent on the caller. If the capture were not
      // folded away, `depth: 1` would return a formatter frame and the whole
      // budget would go to this library.
      final frames = _callerOfTomGetStackTraceAsList(1);
      expect(frames, hasLength(1));
      expect(frames.single, contains('_callerOfTomGetStackTraceAsList'));
    });
  });

  // =========================================================================
  // FORMATTING UTILITIES
  // =========================================================================

  group('tomStackTraceNoise', () {
    // The built-in fold names core frames, `shelf`, `TomLogger.*` and this
    // library's own formatting functions. An application built on the
    // framework has a layer of its own that is noise in exactly the same way,
    // and the classification is process-wide rather than a parameter because
    // the formatters that matter most — the ones TomException and the logger
    // call for themselves — are not reached from the application's call sites.

    final consumerTrace = Trace.parse(
      '#0      MyFramework.dispatch (package:my_framework/dispatch.dart:10:5)\n'
      '#1      MyFramework.route (package:my_framework/dispatch.dart:20:5)\n'
      '#2      appHandler (package:my_app/handler.dart:22:7)\n'
      '#3      MyPipeline.run (package:my_app/pipeline.dart:5:3)\n'
      '#4      main (package:my_app/main.dart:3:3)\n',
    );

    setUp(() {
      addTearDown(tomStackTraceNoise.clear);
    });

    test('a consumer package is kept in full by default', () {
      final frames = tomGetStackTraceAsList(consumerTrace);

      expect(frames, hasLength(5));
      expect(frames[0], contains('MyFramework.dispatch'));
      expect(frames[0], contains('dispatch.dart 10:5'));
      expect(frames[1], contains('MyFramework.route'));
    });

    test('addPackage collapses a run of that package into one frame', () {
      tomStackTraceNoise.addPackage('my_framework');

      final frames = tomGetStackTraceAsList(consumerTrace);

      // Folding collapses a contiguous run into a single summary frame; it
      // does not delete it, which is exactly what the built-in `shelf` rule
      // does. The summary keeps the outermost member of the run and loses the
      // line and column, because it no longer stands for one line of source.
      expect(frames, hasLength(4));
      expect(frames.first, contains('MyFramework.route'));
      expect(frames.first, contains('package:my_framework l:null c:null'));
      expect(frames.first, isNot(contains('dispatch.dart')));

      // The application's own frames are untouched.
      expect(frames[1], contains('appHandler'));
      expect(frames[1], contains('handler.dart 22:7'));

      // The package name is matched whole. A different package that merely
      // starts with the same characters is a different package.
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM('#0      X.y (package:my_framework_extra/x.dart:1:1)'),
        ),
        isFalse,
      );
    });

    test('addMemberPrefix folds a layer that has no package of its own', () {
      tomStackTraceNoise.addMemberPrefix('MyPipeline.');

      final frames = tomGetStackTraceAsList(consumerTrace);

      expect(frames, hasLength(5));
      expect(frames[3], contains('MyPipeline.run'));
      expect(frames[3], isNot(contains('pipeline.dart 5:3')));
      // Everything around it is untouched — the fold is per frame, not per
      // trace.
      expect(frames[2], contains('handler.dart 22:7'));
      expect(frames[4], contains('main.dart 3:3'));

      // The match is on the *start* of the member name, so a class whose name
      // merely ends with the prefix is not swept up with it.
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM('#0      MyPipeline.run (package:my_app/p.dart:1:1)'),
        ),
        isTrue,
      );
      tomStackTraceNoise.clear();
      tomStackTraceNoise.addMemberPrefix('Pipeline.');
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM('#0      MyPipeline.run (package:my_app/p.dart:1:1)'),
        ),
        isFalse,
      );
    });

    test('addPredicate takes any classification of a frame', () {
      tomStackTraceNoise.addPredicate(
        (Frame frame) => frame.uri.path.endsWith('/handler.dart'),
      );

      final frames = tomGetStackTraceAsList(consumerTrace);

      expect(frames[2], contains('appHandler'));
      expect(frames[2], isNot(contains('handler.dart 22:7')));
    });

    test('every registration is asked, in order', () {
      tomStackTraceNoise.addPackage('my_framework');
      tomStackTraceNoise.addMemberPrefix('MyPipeline.');

      final frames = tomGetStackTraceAsList(consumerTrace);

      expect(frames, hasLength(4));
      expect(frames.first, contains('MyFramework.route'));
      expect(frames[2], isNot(contains('pipeline.dart 5:3')));
      expect(tomStackTraceNoise.predicates, hasLength(2));
    });

    test('predicates is a snapshot the caller cannot write through', () {
      tomStackTraceNoise.addPackage('my_framework');

      expect(
        () => tomStackTraceNoise.predicates.add((Frame frame) => true),
        throwsUnsupportedError,
      );
      expect(tomStackTraceNoise.predicates, hasLength(1));
    });

    test('clear restores the default classification', () {
      tomStackTraceNoise.addPackage('my_framework');
      expect(tomGetStackTraceAsList(consumerTrace), hasLength(4));

      tomStackTraceNoise.clear();

      expect(tomStackTraceNoise.predicates, isEmpty);
      expect(tomGetStackTraceAsList(consumerTrace), hasLength(5));
    });

    test('clear leaves the built-in set standing', () {
      tomStackTraceNoise.clear();

      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM('#0      Object.noSuchMethod (dart:core-patch/x.dart)'),
        ),
        isTrue,
      );
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM(
            '#0      Server.handle (package:shelf/src/server.dart:9:1)',
          ),
        ),
        isTrue,
      );
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM(
            '#0      TomLogger.error (package:tom_basics/log.dart:9:1)',
          ),
        ),
        isTrue,
      );
      expect(
        tomStackTraceNoise.isNoise(
          Frame.parseVM(
            '#0      appHandler (package:my_app/handler.dart:22:7)',
          ),
        ),
        isFalse,
      );
    });

    test('a predicate that throws keeps the frame instead of the failure', () {
      // These functions run while some *other* failure is being reported.
      // Letting a predicate's failure out would lose that report in order to
      // complain about the machinery describing it.
      tomStackTraceNoise.addPredicate(
        (Frame frame) => throw StateError('broken predicate'),
      );

      final frames = tomGetStackTraceAsList(consumerTrace);

      expect(frames, hasLength(5));
      expect(frames.first, contains('dispatch.dart 10:5'));
    });

    test('a later predicate still runs after one throws', () {
      tomStackTraceNoise.addPredicate(
        (Frame frame) => throw StateError('broken predicate'),
      );
      tomStackTraceNoise.addPackage('my_framework');

      expect(tomGetStackTraceAsList(consumerTrace), hasLength(4));
    });

    test('a registration reaches a formatter the caller never calls', () {
      // The point of the process-wide list: the traces that matter most are
      // formatted by the framework, not by the application.
      final captured = _CapturingLogOutput();
      final previousOutput = tomLog.logOutput;
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previousOutput);

      tomStackTraceNoise.addPackage('my_framework');
      tomPrintStackTrace(consumerTrace);

      final logged = captured.messages.last;
      expect(logged, contains('MyFramework.route'));
      expect(logged, isNot(contains('dispatch.dart 10:5')));
    });

    test('the string and list formatters agree with each other', () {
      tomStackTraceNoise.addPackage('my_framework');

      final asList = tomGetStackTraceAsList(consumerTrace);
      final (asString, fromTuple) = tomGetStackTraceAsTuple(consumerTrace);

      expect(tomGetStackTrace(consumerTrace), asList.join('\n'));
      expect(fromTuple, asList);
      expect(asString, asList.join('\n'));
    });
  });

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

    // The hour field is two digits wide and the padding never truncates, so
    // an unbounded offset rendered as `+100:00` — accepted silently by the
    // formatter, rejected by every ISO 8601 parser downstream. ±840 is the
    // reachable range of the packaged IANA data (measured across every
    // location's transition table), so the bound rejects only values that
    // never came from a timezone in the first place.
    group('range', () {
      test('accepts +840, the largest real offset', () {
        // Asia/Anadyr sits exactly here, so the bound must be inclusive.
        expect(convertMinutesToUtcOffset(840), equals('+14:00'));
      });

      test('accepts -840', () {
        expect(convertMinutesToUtcOffset(-840), equals('-14:00'));
      });

      test('rejects 841, one minute past the bound', () {
        expect(
          () => convertMinutesToUtcOffset(841),
          throwsA(
            isA<TomFormattingException>().having(
              (e) => e.key,
              'key',
              'formatting.utc_offset.out_of_range',
            ),
          ),
        );
      });

      test('rejects -841', () {
        expect(
          () => convertMinutesToUtcOffset(-841),
          throwsA(isA<TomFormattingException>()),
        );
      });

      test('rejects 6000 rather than returning "+100:00"', () {
        // The reported defect, pinned by value: this used to produce a
        // three-digit hour field.
        expect(
          () => convertMinutesToUtcOffset(6000),
          throwsA(isA<TomFormattingException>()),
        );
      });

      test('reports the offending value', () {
        try {
          convertMinutesToUtcOffset(6000);
          fail('expected TomFormattingException');
        } on TomFormattingException catch (e) {
          expect(e.defaultUserMessage, contains('6000'));
          expect(e.parameters?['totalMinutes'], equals(6000));
        }
      });

      test('rejects the most negative int', () {
        // Guards the `.abs()` trap: in Dart this value is its own `abs()`, so
        // an `abs() > max` check would let precisely this one through.
        expect(
          () => convertMinutesToUtcOffset(-9223372036854775808),
          throwsA(isA<TomFormattingException>()),
        );
      });
    });
  });

  // =========================================================================
  // TomException
  // =========================================================================

  group('TomException', () {
    group('constructor', () {
      test('should create exception with required parameters', () {
        final exception = TomException('test.error.code', 'Error message');
        expect(exception.key, equals('test.error.code'));
        expect(exception.defaultUserMessage, equals('Error message'));
      });

      test('should generate UUID if not provided', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.uuid, isNotNull);
        expect(exception.uuid, isNotEmpty);
        expect(exception.uuid.length, equals(36)); // UUID format
      });

      test('should use provided UUID when specified', () {
        final customUuid = '12345678-1234-1234-1234-123456789012';
        final exception = TomException(
          'test.error.key',
          'message',
          uuid: customUuid,
        );
        expect(exception.uuid, equals(customUuid));
      });

      test('should set timestamp on creation', () {
        final before = DateTime.timestamp();
        final exception = TomException('test.error.key', 'message');
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
          'test.error.key',
          'message',
          parameters: params,
        );
        expect(exception.parameters, equals(params));
      });

      test('should store request UUID', () {
        final exception = TomException(
          'test.error.key',
          'message',
          requestUuid: 'request-123',
        );
        expect(exception.requestUuid, equals('request-123'));
      });

      test('should store root exception', () {
        final rootError = FormatException('original error');
        final exception = TomException(
          'test.error.wrapped',
          'Wrapped error',
          rootException: rootError,
        );
        expect(exception.rootException, isA<FormatException>());
      });

      test('should capture stack trace', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.stackTrace, isNotEmpty);
      });

      test('should populate stack when none is passed', () {
        final exception = TomException('test.error.key', 'message');
        expect(
          exception.stack,
          isNotNull,
          reason:
              'the raw trace is what printStackTrace re-formats, so it '
              'has to exist even when the caller supplied none',
        );
      });

      test('should keep a provided stack unchanged', () {
        final provided = _captureDeepStack();
        final exception = TomException(
          'test.error.key',
          'message',
          stack: provided,
        );
        expect(exception.stack, same(provided));
      });

      test('should default autoLog to false', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.autoLog, isFalse);
      });
    });

    group('toString', () {
      test('should include uuid in string representation', () {
        final exception = TomException(
          'test.error.code',
          'message',
          uuid: 'test-uuid-1234',
        );
        expect(exception.toString(), contains('test-uuid-1234'));
      });

      test('should include key in string representation', () {
        final exception = TomException('test.error.my_key', 'message');
        expect(exception.toString(), contains('test.error.my_key'));
      });

      test('should include message in string representation', () {
        final exception = TomException(
          'test.error.key',
          'This is the error message',
        );
        expect(exception.toString(), contains('This is the error message'));
      });

      test('should include runtime type in string representation', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.toString(), contains('TomException'));
      });

      test('should include parameters in string representation', () {
        final exception = TomException(
          'test.error.key',
          'message',
          parameters: {'field': 'email'},
        );
        expect(exception.toString(), contains('field'));
        expect(exception.toString(), contains('email'));
      });

      test('should include request UUID in string representation', () {
        final exception = TomException(
          'test.error.key',
          'message',
          requestUuid: 'req-uuid-5678',
        );
        expect(exception.toString(), contains('req-uuid-5678'));
      });
    });

    group('logRepresentation', () {
      test('should return same as toString', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.logRepresentation, equals(exception.toString()));
      });
    });

    group('implements Exception', () {
      test('should be throwable as Exception', () {
        expect(
          () => throw TomException('test.error.key', 'test'),
          throwsA(isA<Exception>()),
        );
      });

      test('should be catchable as TomException', () {
        expect(
          () => throw TomException('test.error.key', 'test'),
          throwsA(isA<TomException>()),
        );
      });
    });

    group('unique UUIDs', () {
      test('should generate different UUIDs for different instances', () {
        final exception1 = TomException('test.error.key', 'message 1');
        final exception2 = TomException('test.error.key', 'message 2');
        expect(exception1.uuid, isNot(equals(exception2.uuid)));
      });
    });

    group('edge cases', () {
      test('should handle empty key', () {
        final exception = TomException('', 'message');
        expect(exception.key, equals(''));
      });

      test('should handle empty message', () {
        final exception = TomException('test.error.key', '');
        expect(exception.defaultUserMessage, equals(''));
      });

      test('should handle null parameters', () {
        final exception = TomException(
          'test.error.key',
          'message',
          parameters: null,
        );
        expect(exception.parameters, isNull);
      });

      test('should handle empty parameters map', () {
        final exception = TomException(
          'test.error.key',
          'message',
          parameters: {},
        );
        expect(exception.parameters, isEmpty);
      });

      test('should handle special characters in message', () {
        final message = 'Error: "value" contains <special> & chars\n\ttab';
        final exception = TomException('test.error.key', message);
        expect(exception.defaultUserMessage, equals(message));
      });

      test('should handle unicode in parameters', () {
        final exception = TomException(
          'test.error.key',
          'message',
          parameters: {'emoji': '🎉', 'chinese': '中文'},
        );
        expect(exception.parameters!['emoji'], equals('🎉'));
        expect(exception.parameters!['chinese'], equals('中文'));
      });
    });

    // -----------------------------------------------------------------------
    // autoLog branch
    //
    // Constructing with `autoLog: true` emits two records, and they have to
    // agree about which exception they describe: the correlation id on the
    // stack-trace line must match the one the exception reports. It did not,
    // for as long as the branch existed — the constructor's `uuid` and
    // `requestUuid` parameters shadow the fields, so the line read
    // `null-null` whenever the caller supplied neither.
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
        TomException('test.error.key', 'message');
        expect(captured.messages, isEmpty);
      });

      test('should log on construction when autoLog is true', () {
        TomException('test.error.critical', 'boom', autoLog: true);
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
        TomException('test.error.critical', 'database down', autoLog: true);
        expect(
          captured.messages.any((m) => m.contains('database down')),
          isTrue,
        );
      });

      test('should correlate the stacktrace line with the generated uuid', () {
        // The two lines describe one exception, so they must name the same
        // one. They did not: the constructor's `uuid` parameter shadowed the
        // generated field, so an exception created without an explicit uuid —
        // the common case — logged its trace under `null-null` while the
        // EXCEPTION line above carried the real id. Nothing could then join a
        // trace to the failure it came from.
        final exception = TomException(
          'test.error.critical',
          'boom',
          autoLog: true,
        );

        final trace = captured.messages.firstWhere(
          (m) => m.contains('EXCEPTION_STACKTRACE:'),
        );
        expect(trace, contains(exception.uuid));
        expect(
          trace,
          isNot(contains('EXCEPTION_STACKTRACE: null-')),
          reason: 'the correlation id must be the exception\'s own uuid',
        );
      });

      test('should carry the request uuid into the stacktrace line', () {
        final exception = TomException(
          'test.error.critical',
          'boom',
          requestUuid: 'req-77',
          autoLog: true,
        );

        final trace = captured.messages.firstWhere(
          (m) => m.contains('EXCEPTION_STACKTRACE:'),
        );
        expect(trace, contains('${exception.uuid}-req-77'));
      });

      test('reports what the constructor did, and stays that way', () {
        // The field is a record of what happened, not a switch. It is read in
        // exactly one place — the constructor body that writes the two log
        // lines — so by the time anyone holds the exception the decision has
        // been carried out and the field can only describe it.
        final logged = TomException('test.error.on', 'boom', autoLog: true);
        final silent = TomException('test.error.off', 'quiet');

        expect(logged.autoLog, isTrue);
        expect(silent.autoLog, isFalse);
        expect(
          captured.messages.where((m) => m.contains('test.error.off')),
          isEmpty,
        );
      });

      test('is declared final, so it cannot promise a control it lacks', () {
        // A settable field advertised something it could not do: `e.autoLog =
        // true` produced no log line, because the only read is the one the
        // constructor already made. The guarantee is the compiler's, so
        // nothing at runtime can observe it being lost — it is asserted
        // against the declaration instead, which is the only way the defect
        // could come back.
        expect(
          _fieldDeclarationOfTomException('autoLog'),
          'final bool autoLog;',
        );
      });
    });

    // -----------------------------------------------------------------------
    // serverCallError
    // -----------------------------------------------------------------------
    group('serverCallError', () {
      test('should default to null', () {
        final exception = TomException('test.error.key', 'message');
        expect(exception.serverCallError, isNull);
      });

      test('should store and expose a provided server call error', () {
        final sce = TomServerCallError(
          statusCode: 404,
          reasonPhrase: 'Not Found',
        );
        final exception = TomException(
          'test.error.http',
          'request failed',
          serverCallError: sce,
        );
        expect(exception.serverCallError, same(sce));
        expect(exception.serverCallError!.statusCode, equals(404));
        expect(exception.serverCallError!.reasonPhrase, equals('Not Found'));
      });

      test('is declared final, so the report cannot be edited in flight', () {
        // An exception is a report of something that has already happened. A
        // payload that can be swapped after the throw would let a handler five
        // frames up read a description of the failure that the code between it
        // and the throw site had rewritten.
        expect(
          _fieldDeclarationOfTomException('serverCallError'),
          'final TomServerCallError? serverCallError;',
        );
      });
    });

    // -----------------------------------------------------------------------
    // printStackTrace
    // -----------------------------------------------------------------------
    group('one renderer serves both representations', () {
      // An exception carries its stack twice: as the `stack` trace and as the
      // `stackTrace` string the base constructor derives from it. Both come
      // from one formatter, because `TomException` overrides the
      // `renderStackTrace` seam `tom_basics` exposes. Left to the base's own
      // narrow renderer the string would fold core frames only and write each
      // frame differently from `printStackTrace`, so one exception would
      // describe its own stack two ways.

      final handed = StackTrace.fromString(
        '#0      MyFramework.dispatch (package:my_framework/dispatch.dart:10:5)\n'
        '#1      appHandler (package:my_app/handler.dart:22:7)\n'
        '#2      main (package:my_app/main.dart:3:3)\n',
      );

      setUp(() {
        addTearDown(tomStackTraceNoise.clear);
      });

      test('the string equals what the formatter renders from the trace', () {
        final exception = TomException('seam.agree.given', 'x', stack: handed);

        expect(exception.stackTrace, tomGetStackTrace(exception.stack));
      });

      test('the string carries this framework\'s frame format', () {
        final exception = TomException('seam.format.given', 'x', stack: handed);

        // `tom_basics` renders a frame with `Frame.toString()`, which has no
        // `l:`/`c:` fields and does not repeat the library. Seeing them is how
        // the test tells which renderer produced the string.
        expect(exception.stackTrace, contains('l:10 c:5'));
        expect(
          exception.stackTrace.split('\n').first,
          contains('MyFramework.dispatch'),
        );
      });

      test('this framework\'s fold applies to the string too', () {
        // The base renderer folds core frames only, so a registration made for
        // this framework would have reached `printStackTrace` and left the
        // stored string untouched.
        tomStackTraceNoise.addPackage('my_framework');

        final exception = TomException('seam.fold.given', 'x', stack: handed);

        expect(exception.stackTrace, isNot(contains('dispatch.dart 10:5')));
        expect(exception.stackTrace, contains('MyFramework.dispatch'));
        expect(exception.stackTrace, tomGetStackTrace(exception.stack));
      });

      test('an implicit capture keeps both in step after trimming', () {
        // The constructor frames are dropped from `stack` and the string is
        // re-derived through the same seam, so the two cannot drift apart at
        // the one point the class rewrites them.
        final exception = _implicitlyCapturingCaller();

        expect(exception.stackTrace, tomGetStackTrace(exception.stack));
        expect(
          exception.stackTrace.split('\n').first,
          contains('_implicitlyCapturingCaller'),
        );
      });

      test('a subclass keeps the override', () {
        final exception = _SeamSubclass('seam.subclass.given', 'x', handed);

        expect(exception.stackTrace, tomGetStackTrace(exception.stack));
        expect(exception.stackTrace, contains('l:10 c:5'));
      });
    });

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
          'test.error.key',
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

      test('should open the record with the identity message and no more', () {
        // The documented record layout. `tomPrintStackTrace` joins the message
        // to the trace with a space, not a newline, so the first frame shares
        // a line with the identifier — a log rule keying on the uuid pair
        // cannot anchor to end of line, and the words between them are
        // literal text rather than a description of the record.
        final exception = TomException(
          'test.error.key',
          'message',
          uuid: 'uuid-123',
          requestUuid: 'req-456',
        );
        exception.printStackTrace(1);

        final logged = captured.messages.last;
        expect(logged, startsWith('uuid-123-req-456 exception stacktrace '));
        expect(logged.split('\n').first, isNot(endsWith('stacktrace')));
      });

      test('should render a missing requestUuid as null, not omit it', () {
        // The pair is always two fields wide. Dropping the separator when
        // there is no request would make the common case parse differently
        // from the correlated one.
        final exception = TomException(
          'test.error.key',
          'message',
          uuid: 'uuid-123',
        );
        exception.printStackTrace(1);

        expect(captured.messages.last, startsWith('uuid-123-null '));
      });

      test('should log the construction site when no stack was passed', () {
        final exception = _constructExceptionAtKnownSite();
        exception.printStackTrace();

        // The whole point of the method: name the code that created the
        // exception. Capturing the trace inside the formatter instead would
        // leave the record holding only the formatter's own frames.
        expect(
          captured.messages.any(
            (m) => m.contains('_constructExceptionAtKnownSite'),
          ),
          isTrue,
          reason:
              'printStackTrace must report where the exception was '
              'constructed, not where it was formatted',
        );
      });

      test('leads with the construction site, not the constructor', () {
        final exception = _constructExceptionAtKnownSite();
        exception.printStackTrace(1);

        // A depth of *one* is the assertion. The trace is captured inside the
        // constructor, so `new TomException` is genuinely the newest frame —
        // and it is on every trace in the system, which makes it noise rather
        // than information. It is dropped at construction, so one frame is
        // enough to reach the code that failed.
        final logged = captured.messages.last;
        expect(logged, contains('_constructExceptionAtKnownSite'));
        expect(logged, isNot(contains('new TomException')));
      });

      test('drops a subclass constructor chain too, not just the base', () {
        // A subclass adds one constant frame per level, so bounding the run by
        // the base alone would leave `new TomFormattingException` leading.
        final exception = _constructSubclassAtKnownSite();
        exception.printStackTrace(1);

        final logged = captured.messages.last;
        expect(logged, contains('_constructSubclassAtKnownSite'));
        expect(logged, isNot(contains('new TomException')));
        expect(logged, isNot(contains('new TomFormattingException')));
      });

      test('keeps an application constructor that raises', () {
        // The case that makes a blanket "drop leading `new …` frames" rule
        // wrong. `_ThrowingAppType`'s constructor is the code that failed, and
        // it sits in exactly the position a subclass constructor would — so the
        // run has to be bounded by the exception's own leaf type, which for a
        // directly constructed `TomException` is the first frame.
        TomException? caught;
        try {
          _ThrowingAppType();
        } on TomException catch (e) {
          caught = e;
        }
        caught!.printStackTrace(1);

        final logged = captured.messages.last;
        expect(logged, contains('new _ThrowingAppType'));
        expect(logged, isNot(contains('new TomException')));
      });

      test('leaves a caller-supplied trace alone', () {
        // Nothing above a trace the caller handed in belongs to this class, so
        // the trim must not run for it.
        final handed = StackTrace.current;
        final exception = TomException('t.e.k', 'explicit', stack: handed);

        expect(exception.stack, same(handed));
      });

      test('should tolerate an exception built on an empty stack', () {
        // Wrapping code forwards whatever trace it caught, and an async error
        // created without one yields `StackTrace.empty`. Reporting such an
        // exception must not itself throw.
        final exception = TomException(
          'test.error.key',
          'message',
          stack: StackTrace.empty,
        );

        expect(exception.printStackTrace, returnsNormally);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test('should report no frames when the stack field was cleared', () {
        final exception = TomException('test.error.key', 'message');
        exception.stack = null;

        expect(exception.printStackTrace, returnsNormally);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });

      test(
        'should not substitute the reporting site for an unusable stack',
        () {
          final exception = TomException('test.error.key', 'message');
          exception.stack = null;
          exception.printStackTrace();

          // Capturing `StackTrace.current` as a fallback would print the call
          // path of the *report*, which names none of the code that failed —
          // a plausible-looking trace pointing at the wrong place. An unusable
          // stack means no trace is known, so none is shown.
          expect(captured.messages.last, isNot(contains('printStackTrace')));
          expect(
            captured.messages.last.trim(),
            endsWith('exception stacktrace'),
          );
        },
      );

      test('should prefer an explicitly passed stack over the capture', () {
        final exception = TomException(
          'test.error.key',
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
        final exception = TomException('test.error.key', 'message');
        exception.printStackTrace(0);
        // With depth 0 the trace portion is empty, so only the prefix message
        // remains — i.e. no stack-frame location lines are appended.
        expect(captured.messages, isNotEmpty);
        expect(captured.messages.last.trim(), endsWith('exception stacktrace'));
      });
    });
  });

  // =========================================================================
  // tomPrintStackTrace
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
      // — no frame location lines, and no trailing separator either.
      expect(captured.messages, isNotEmpty);
      expect(captured.messages.last, equals('P'));
    });

    test('a nonzero depth reaches the trace with an exact frame count', () {
      // The test above proves the argument is passed on, but only at the
      // degenerate value: depth 0 is satisfied by anything producing no
      // frames at all. Pinning a nonzero count is what shows the printed
      // trace is truncated to the size asked for rather than to some other.
      tomPrintStackTrace(_captureDeepStack(), message: 'P', depth: 3);

      // Message and trace are joined by a space and the trace's own frames by
      // newlines, so the prefix rides on the first frame's line.
      final lines = captured.messages.last.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('P '));
      expect(lines[0], contains('_deepLevelInnermost'));
      expect(lines[1], contains('_deepLevelMiddle'));
      expect(lines[2], contains('_deepLevelOuter'));
    });

    // -----------------------------------------------------------------------
    // Nothing to say
    // -----------------------------------------------------------------------

    // Every test above passes a message, which is why none of them saw this:
    // the record was built and handed to `tomLog.error` unconditionally, so a
    // call with nothing to report emitted an ERROR entry with an empty body.
    // An empty ERROR line is worse than silence — it claims a failure occurred
    // and then describes none, and it does so at the level operators alert on.

    test('should log nothing for an empty trace with no message', () {
      tomPrintStackTrace(StackTrace.empty);
      expect(captured.messages, isEmpty);
    });

    test('should log nothing when depth 0 leaves no frames and no message', () {
      // depth 0 is a meaningful request for no frames, not a mistake. Asking
      // for no frames and supplying no context is a request to report nothing.
      tomPrintStackTrace(StackTrace.current, depth: 0);
      expect(captured.messages, isEmpty);
    });

    test(
      'should log nothing when the message is empty and so is the trace',
      () {
        tomPrintStackTrace(StackTrace.current, message: '', depth: 0);
        expect(captured.messages, isEmpty);
      },
    );

    test('should still log the trace when only the message is empty', () {
      // An empty message must suppress only itself, never the trace it would
      // have prefixed.
      tomPrintStackTrace(StackTrace.current, message: '');
      expect(captured.messages, isNotEmpty);
      expect(captured.messages.last, isNot(startsWith(' ')));
      expect(captured.messages.last, contains('little_things_test.dart'));
    });
  });

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
      final (traceString, traceList) = tomGetStackTraceAsTuple(
        StackTrace.empty,
      );
      expect(traceString, isEmpty);
      expect(traceList, isEmpty);
    });

    test('a depth limit on an empty trace yields an empty result', () {
      // Asking for frames that do not exist is not an error: the limit caps
      // the result, it does not promise to fill it.
      expect(tomGetStackTraceAsList(StackTrace.empty, 5), isEmpty);
    });

    test(
      'an async error carrying no trace is formatted, not thrown on',
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
      },
    );
  });

  // =========================================================================
  // DEPTH == 0 BOUNDARY
  //
  // Zero is the boundary the frame walk got wrong: it appended a frame before
  // testing the counter, so a request for no frames returned every one of
  // them — the maximum instead of the minimum. All three accessors are pinned
  // here because they share that walk, and a regression in it would surface
  // in whichever one the caller happened to use.
  // =========================================================================

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
      final (traceString, traceList) = tomGetStackTraceAsTuple(
        StackTrace.current,
        0,
      );
      expect(traceString, isEmpty);
      expect(traceList, isEmpty);
    });
  });

  // =========================================================================
  // NEGATIVE DEPTHS
  //
  // The walk tests `depth >= 0`, so a bound is a non-negative number and every
  // negative one is the absence of a bound. -1 is convention, not a sentinel —
  // which is what makes a computed depth safe, since arithmetic lands on -2 as
  // readily as on -1. All three accessors are pinned because they share the
  // walk, as in the depth == 0 group above.
  // =========================================================================

  group('negative stack trace depth', () {
    // Larger than any trace these tests produce, so it stands for "all
    // frames". Comparing -5 against -1 alone would pass even if both
    // truncated identically, which is the regression worth catching.
    const unbounded = 1000;

    test('tomGetStackTraceAsList treats -5 as all frames', () {
      final trace = StackTrace.current;
      final all = tomGetStackTraceAsList(trace, unbounded);
      expect(all, isNotEmpty, reason: 'else the comparisons below are vacuous');
      expect(tomGetStackTraceAsList(trace, -5), all);
      expect(tomGetStackTraceAsList(trace, -1), all);
    });

    test('tomGetStackTrace treats -5 as all frames', () {
      final trace = StackTrace.current;
      final all = tomGetStackTrace(trace, unbounded);
      expect(all, isNotEmpty, reason: 'else the comparison below is vacuous');
      expect(tomGetStackTrace(trace, -5), all);
    });

    test('tomGetStackTraceAsTuple treats -5 as all frames', () {
      final trace = StackTrace.current;
      final (allText, allFrames) = tomGetStackTraceAsTuple(trace, unbounded);
      expect(allFrames, isNotEmpty, reason: 'else the comparison is vacuous');
      final (text, frames) = tomGetStackTraceAsTuple(trace, -5);
      expect(text, allText);
      expect(frames, allFrames);
    });

    test('a negative depth is not read as a frame count', () {
      // The hazard the contract removes: -2 is unbounded, not "two frames".
      // Without this, `depth >= 0` could be misread as making the magnitude
      // of a negative meaningful.
      final trace = StackTrace.current;
      final two = tomGetStackTraceAsList(trace, 2);
      expect(two, hasLength(2));
      expect(tomGetStackTraceAsList(trace, -2).length, greaterThan(two.length));
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

/// Base of a two-level hierarchy used to show that a zone lookup keys on the
/// exact `Type` and not on assignability. A supertype and its subtype are
/// distinct keys in both directions.
class _ZoneBase {
  String get name => 'base';
}

class _ZoneDerived extends _ZoneBase {
  @override
  String get name => 'derived';
}

/// An interface and its implementation, used for the same purpose: `implements`
/// creates no relationship between the two `Type` objects used as zone keys.
abstract class _ZoneService {}

class _ZoneServiceImpl implements _ZoneService {}

/// Custom exception for error transformation tests.
class _CustomException implements Exception {
  final String message;

  _CustomException(this.message);

  @override
  String toString() => 'CustomException: $message';
}

/// Log output that records every emitted message so log side-effects
/// (autoLog, printStackTrace, tomPrintStackTrace) can be asserted.
/// The source line declaring [name] on `TomException`, whitespace collapsed.
///
/// `final` is a compile-time guarantee, so nothing at run time can observe it
/// being lost. Reading the declaration is what lets a test fail the moment one
/// is dropped, which is the only way either field could become settable again.
String _fieldDeclarationOfTomException(String name) {
  const path = 'lib/src/tombase/little_things/exception_base.dart';
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Expected to find $path relative to ${Directory.current.path}',
  );
  final source = file.readAsStringSync();

  final classStart = source.indexOf('class TomException extends');
  expect(
    classStart,
    greaterThan(-1),
    reason: 'TomException is no longer declared in $path',
  );
  final constructorStart = source.indexOf('TomException(', classStart + 1);
  expect(
    constructorStart,
    greaterThan(classStart),
    reason: 'TomException has no generative constructor',
  );

  final declaration = RegExp(
    r'^  ((?:final )?[\w<>,? ]+? ' + name + r';)$',
    multiLine: true,
  ).firstMatch(source.substring(classStart, constructorStart));
  expect(
    declaration,
    isNotNull,
    reason: 'TomException no longer declares a field named $name',
  );
  return declaration!.group(1)!;
}

/// Builds a [TomException] with no `stack` argument, so the trace is captured
/// in the constructor and this function is the first frame that matters.
TomException _implicitlyCapturingCaller() =>
    TomException('seam.agree.implicit', 'x');

/// A subclass, so the override is exercised one level down — where the base
/// constructor runs before this class's own body and an override that read
/// instance state would fail.
class _SeamSubclass extends TomException {
  _SeamSubclass(String key, String message, StackTrace stack)
    : super(key, message, stack: stack);
}

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
