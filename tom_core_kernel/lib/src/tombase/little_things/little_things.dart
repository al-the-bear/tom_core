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
/// - [s]: The stack trace, or `null` to use [StackTrace.current].
/// - [message]: Optional prefix message for the log entry.
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
void tomPrintStackTrace(StackTrace? s, {String? message, int depth = -1}) {
  var stackTrace = message != null
      ? "$message ${tomGetStackTrace(s, depth)}"
      : tomGetStackTrace(s, depth);
  tomLog.error(stackTrace);
}

/// The stack-trace formatting functions of this library.
///
/// These appear on a trace only when it was captured *inside* the formatter —
/// that is, whenever the caller passed no stack and [StackTrace.current] was
/// used as the fallback. They record the act of formatting, never the failure,
/// so they are noise in every trace they appear in.
///
/// Matching is on the member name rather than the library, because the library
/// URI of this file differs between `package:` and `file:` resolution and a
/// consumer's trace may carry either form.
const _formatterMembers = {
  'tomPrintStackTrace',
  'tomGetStackTrace',
  'tomGetStackTraceAsList',
  'tomGetStackTraceAsTuple',
  '_processStackFrames',
};

/// Whether [frame] belongs to this library's own stack-trace formatting.
bool _isFormatterFrame(Frame frame) => _formatterMembers.contains(frame.member);

/// Core implementation for processing stack trace frames.
///
/// Folds and filters stack frames to remove noise from core libraries,
/// shelf, TomLogger internals and this library's own formatting functions,
/// then flattens every segment of the async chain into one list.
///
/// ## Parameters
///
/// - [s]: The stack trace to process. Defaults to [StackTrace.current].
/// - [depth]: Maximum frames to return. Use -1 for all frames.
///
/// ## Returns
///
/// A list of formatted stack frame strings, newest first. Empty when the trace
/// carries no frames — see [StackTrace.empty] below.
List<String> _processStackFrames([StackTrace? s, int depth = -1]) {
  // The parameter is `StackTrace?`, not `Object?`. The wider type used to be
  // narrowed here by `s as StackTrace?`, which accepted anything at the call
  // site and then threw a `TypeError` at this line — while formatting a trace,
  // i.e. while reporting some *other* failure, and in `TomException`'s case
  // before the exception being reported even existed. The narrow parameter
  // rejects the same values, but at compile time, where the mistake is free.
  final stackTrace = s ?? StackTrace.current;
  // A Chain holds one trace *segment* per `await` boundary, newest first.
  // Flattening all of them is what makes an asynchronous trace complete: the
  // throw site is in the newest segment, but the caller that started the work
  // is in an older one. Keeping only the newest segment reported where an
  // async failure surfaced and never where it began. Concatenating preserves
  // the newest-first order the depth limit below relies on, and a synchronous
  // trace is a single-segment chain, so it is unaffected.
  //
  // Flattening is also what makes an *empty* trace safe, so do not reintroduce
  // indexing here. `Chain.forTrace(StackTrace.empty).traces` is itself empty,
  // so the `.traces[0]` this replaced threw a RangeError — the reporting
  // machinery crashing while reporting a crash. Dart supplies that exact
  // object for any error created without a trace (`Future.error`,
  // `Completer.completeError`), so it reaches this function through ordinary
  // use, not only through contrived input. `expand` yields nothing for it.
  final frames = Chain.forTrace(stackTrace)
      .foldFrames(
        (frame) =>
            frame.isCore ||
            frame.package == 'shelf' ||
            _isFormatterFrame(frame) ||
            (frame.member?.startsWith("TomLogger.") ?? false),
        terse: true,
      )
      .traces
      .expand((trace) => trace.frames)
      // Folding *collapses* a contiguous run of matching frames into one; it
      // does not remove it. So the fold above leaves a single formatter frame
      // still leading an implicitly captured trace, which is precisely the
      // frame the caller must not see. Dropping the leading run is what makes
      // the caller's own frame first — and what makes a small `depth` land on
      // the caller rather than being spent on this library.
      //
      // Only the *leading* run is dropped. A formatter member appearing deeper
      // in the trace is a genuine call by the code being traced, and folding
      // has already reduced such a run to one frame.
      .skipWhile(_isFormatterFrame);

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
/// - [s]: The stack trace, or `null` to use [StackTrace.current].
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
///   The limit applies across the whole chain, counting from the throw site.
///
/// ## Returns
///
/// A formatted stack trace string with one frame per line. An empty string
/// when the trace has no frames — [StackTrace.empty] is what Dart supplies for
/// an error created without one, so this is an ordinary outcome rather than an
/// error.
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
String tomGetStackTrace([StackTrace? s, int depth = -1]) {
  return _processStackFrames(s, depth).join('\n');
}

/// Formats a stack trace as a list of strings.
///
/// Same as [tomGetStackTrace] but returns individual frames as list elements.
///
/// ## Parameters
///
/// - [s]: The stack trace, or `null` to use [StackTrace.current].
/// - [depth]: Maximum number of frames to include. Use -1 for all frames.
///
/// ## Returns
///
/// A list of formatted stack frame strings, empty when the trace has no
/// frames.
List<String> tomGetStackTraceAsList([StackTrace? s, int depth = -1]) {
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
/// - [s]: The stack trace, or `null` to use [StackTrace.current].
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
(String, List<String>) tomGetStackTraceAsTuple([StackTrace? s, int depth = -1]) {
  List<String> stackLines = _processStackFrames(s, depth);
  String stackString = stackLines.join('\n');
  return (stackString, stackLines);
}

