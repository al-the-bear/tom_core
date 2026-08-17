/// Core utility functions for zone management and stack trace handling.
///
/// This library provides essential utility functions used throughout the
/// tom_core framework:
///
/// - **Zone Utilities**: Access typed values from the current Dart zone
/// - **Checked Execution**: Run code with error transformation
/// - **Stack Trace Processing**: Format and analyze stack traces
///
/// ## Example
///
/// ```dart
/// // Access typed values from current zone
/// final config = getFromCurrentZone<AppConfig>();
///
/// // Run with error transformation
/// final result = await runChecked(
///   () => fetchData(),
///   (error, stack) => CustomException('Fetch failed', error),
/// );
///
/// // Get formatted stack trace
/// print(tomGetStackTrace(StackTrace.current, 5));
/// ```
library;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:tom_basics/tom_basics.dart';

// =============================================================================
// ZONE UTILITIES
// =============================================================================

/// Retrieves a typed value from the current Dart [Zone].
///
/// Zone values are used for passing context through async operations without
/// explicitly threading parameters through function calls.
///
/// Returns `null` if no value of type [T] exists in the current zone or if
/// the stored value is not of type [T].
///
/// ## Example
///
/// ```dart
/// // Store a value in a zone
/// runZoned(
///   () {
///     final config = getFromCurrentZone<AppConfig>();
///     print(config?.environment);
///   },
///   zoneValues: {AppConfig: AppConfig(environment: 'production')},
/// );
/// ```
///
/// ## Type Parameter
///
/// - [T]: The type of value to retrieve. Must match the key used when
///   storing the value in the zone.
T? getFromCurrentZone<T>() {
  Object? zoneItem = Zone.current[T];
  if (zoneItem != null && zoneItem is T) {
    return zoneItem as T;
  }
  return null;
}

/// Retrieves an untyped value from the current Dart [Zone] by its [Type].
///
/// Unlike [getFromCurrentZone], this returns the raw [Object?] without
/// type checking. Useful when the type is only known at runtime.
///
/// ## Parameters
///
/// - [t]: The [Type] to use as the zone value key.
///
/// ## Returns
///
/// The zone value associated with type [t], or `null` if not found.
Object? getObjectFromCurrentZone(Type t) {
  return Zone.current[t];
}

// =============================================================================
// CHECKED EXECUTION
// =============================================================================

/// Runs an async function with error transformation.
///
/// Executes [body] and catches any errors, transforming them using [onError]
/// before rethrowing. This is useful for wrapping low-level errors in
/// domain-specific exceptions.
///
/// ## Example
///
/// ```dart
/// final data = await runChecked(
///   () => httpClient.get(url),
///   (error, stacktrace) => NetworkException(
///     'Request failed',
///     originalError: error,
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// - [body]: The async function to execute.
/// - [onError]: Transform function called when [body] throws.
///
/// ## Returns
///
/// The result of [body] if successful.
///
/// ## Throws
///
/// The transformed error from [onError] if [body] throws.
Future<T> runChecked<T>(
  Future<T> Function() body,
  Object Function(Object error, StackTrace stacktrace) onError,
) async {
  try {
    return await body();
  } catch (error, stacktrace) {
    throw onError(error, stacktrace);
  }
}

/// Synchronous version of [runChecked].
///
/// Executes [body] synchronously and catches any errors, transforming them
/// using [onError] before rethrowing.
///
/// ## Example
///
/// ```dart
/// final config = runCheckedSync(
///   () => parseConfig(jsonString),
///   (error, stacktrace) => ConfigException('Invalid config format'),
/// );
/// ```
T runCheckedSync<T>(
  T Function() body,
  Object Function(Object error, StackTrace stacktrace) onError,
) {
  try {
    return body();
  } catch (error, stacktrace) {
    throw onError(error, stacktrace);
  }
}

// =============================================================================
// STACK TRACE UTILITIES
// =============================================================================

/// Prints a formatted stack trace to the error log.
///
/// Formats and logs the stack trace with optional message prefix.
/// Uses [tomGetStackTrace] internally for formatting.
///
/// ## Parameters
///
/// - [s]: The stack trace object, or `null` to use [StackTrace.current].
/// - [message]: Optional prefix message for the log entry.
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
void tomPrintStackTrace(Object? s, {String? message, int depth = -1}) {
  var stackTrace = message != null
      ? "$message ${tomGetStackTrace(s, depth)}"
      : tomGetStackTrace(s, depth);
  tomLog.error(stackTrace);
}

/// Core implementation for processing stack trace frames.
///
/// Folds and filters stack frames to remove noise from core libraries,
/// shelf, and TomLogger internals, then flattens every segment of the async
/// chain into one list.
///
/// ## Parameters
///
/// - [s]: The stack trace to process. Defaults to [StackTrace.current].
/// - [depth]: Maximum frames to return. Use -1 for all frames.
///
/// ## Returns
///
/// A list of formatted stack frame strings, newest first.
List<String> _processStackFrames([Object? s, int depth = -1]) {
  final stackTrace = s as StackTrace? ?? StackTrace.current;
  // A Chain holds one trace *segment* per `await` boundary, newest first.
  // Flattening all of them is what makes an asynchronous trace complete: the
  // throw site is in the newest segment, but the caller that started the work
  // is in an older one. Keeping only the newest segment reported where an
  // async failure surfaced and never where it began. Concatenating preserves
  // the newest-first order the depth limit below relies on, and a synchronous
  // trace is a single-segment chain, so it is unaffected.
  final frames = Chain.forTrace(stackTrace)
      .foldFrames(
        (frame) =>
            frame.isCore ||
            frame.package == 'shelf' ||
            (frame.member?.startsWith("TomLogger.") ?? false),
        terse: true,
      )
      .traces
      .expand((trace) => trace.frames);

  final resultList = <String>[];
  var remaining = depth;

  // Iterate frames newest-first (throw site first, as documented above). This
  // ordering is load-bearing for truncation: a depth limit must keep the
  // frames nearest the error, so those must come first. Iterating reversed
  // (oldest-first) would truncate the throw-site frames away — the most useful
  // ones — leaving only the outermost `main`-side frames.
  for (final f in frames) {
    // Enforce the limit before appending so depth == 0 yields no frames
    // (and depth == n yields exactly n). Checking after appending caused an
    // off-by-one where depth == 0 returned every frame.
    if (depth > -1 && remaining-- == 0) break;
    final line =
        "${f.location} l:${f.line} c:${f.column} ${f.member} ${f.library}";
    resultList.add(line);
  }

  return resultList;
}

/// Formats a stack trace as a single string.
///
/// Processes the stack trace, filtering out framework noise, and returns
/// it as a newline-separated string suitable for logging.
///
/// An asynchronous trace is reported **whole**: the runtime splits it into one
/// segment per `await` boundary, and every segment is included, newest first.
/// So the frames run from the throw site back through each awaiting caller to
/// the one that started the work — which is where an async failure's cause
/// usually is.
///
/// ## Parameters
///
/// - [s]: The stack trace object, or `null` to use [StackTrace.current].
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
///   The limit applies across the whole chain, counting from the throw site.
///
/// ## Returns
///
/// A formatted stack trace string with one frame per line.
///
/// ## Example
///
/// ```dart
/// try {
///   riskyOperation();
/// } catch (e, stack) {
///   log.error('Error: $e\n${tomGetStackTrace(stack, 10)}');
/// }
/// ```
String tomGetStackTrace([Object? s, int depth = -1]) {
  return _processStackFrames(s, depth).join('\n');
}

/// Formats a stack trace as a list of strings.
///
/// Same as [tomGetStackTrace] but returns individual frames as list elements.
///
/// ## Parameters
///
/// - [s]: The stack trace object, or `null` to use [StackTrace.current].
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
///
/// ## Returns
///
/// A list of formatted stack frame strings.
List<String> tomGetStackTraceAsList([Object? s, int depth = -1]) {
  return _processStackFrames(s, depth);
}

/// Formats a stack trace as both a string and list.
///
/// Convenience function that returns both representations in a single call.
/// Processes the trace exactly as [tomGetStackTrace] does, async chain
/// included.
///
/// ## Parameters
///
/// - [s]: The stack trace object, or `null` to use [StackTrace.current].
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
///
/// ## Returns
///
/// A tuple of (formatted string, list of frame strings).
///
/// ## Example
///
/// ```dart
/// final (stackString, stackList) = tomGetStackTraceAsTuple();
/// print('Full trace: $stackString');
/// print('First frame: ${stackList.first}');
/// ```
(String, List<String>) tomGetStackTraceAsTuple([Object? s, int depth = -1]) {
  List<String> stackLines = _processStackFrames(s, depth);
  String stackString = stackLines.join('\n');
  return (stackString, stackLines);
}

