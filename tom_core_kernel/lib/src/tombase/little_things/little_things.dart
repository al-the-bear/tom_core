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
///   (error, stack) => TomException('catalog.find.failed', 'Lookup failed',
///       rootException: error, stack: stack),
/// );
///
/// // Get formatted stack trace
/// print(tomGetStackTrace(StackTrace.current, 5));
/// ```
library;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:tom_basics/tom_basics.dart';

// [TomStackTraceNoise.addPredicate] hands a [Frame] to consumer code, so the
// type is part of this library's contract and is re-exported with it. Without
// this a consumer would have to take a direct dependency on `stack_trace` to
// write the callback the kernel asked it for.
export 'package:stack_trace/stack_trace.dart' show Frame;

// =============================================================================
// ZONE UTILITIES
// =============================================================================

/// Retrieves a typed value from the current Dart [Zone].
///
/// Zone values are used for passing context through async operations without
/// explicitly threading parameters through function calls.
///
/// ## The key is the exact `Type`, not an assignable one
///
/// The lookup is `Zone.current[T]` — a map lookup whose key is the `Type`
/// object [T] itself, matched by `==`. [Zone] exposes no way to enumerate its
/// keys, so **no subtype scan is possible** and none is performed.
/// Assignability plays no part in *finding* the value:
///
/// ```dart
/// runZoned(
///   () {
///     getFromCurrentZone<Derived>();  // the instance
///     getFromCurrentZone<Base>();     // null — a different key
///     getFromCurrentZone<Object>();   // null — `Object` is not a wildcard
///   },
///   zoneValues: {Derived: Derived()},
/// );
/// ```
///
/// It fails in the other direction too: a `Derived` instance filed under the
/// `Base` key is found by `getFromCurrentZone<Base>()` and *not* by
/// `getFromCurrentZone<Derived>()`. `implements` creates no relationship
/// either, and type arguments are part of the key — `List<int>`, `List` and
/// `List<num>` are three distinct keys, as are `T` and `T?`.
///
/// **So the producer and every consumer must name the same type.** Choose the
/// key once — conventionally the declared type of the field the value is read
/// into — and use it on both sides. A mismatch is not a compile error and
/// raises nothing; it is a silent `null`, which is also what "nothing stored
/// here" looks like.
///
/// ## Two independent reasons for `null`
///
/// Returns `null` when nothing is stored under the key [T], **and** when what
/// is stored under that key is not a [T]. The key lookup is the first and
/// stricter filter; the `is T` guard that follows can only narrow what the key
/// already found. [getObjectFromCurrentZone] tells the two apart — it applies
/// the same key lookup without the guard.
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
/// - [T]: The type of value to retrieve. Must be the *same* type that was used
///   as the key when the value was stored — not merely a type the stored value
///   happens to satisfy.
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
/// type checking. Useful when the type is only known at runtime, and when the
/// caller needs to distinguish "nothing stored under this key" from "something
/// stored, but not of the expected type" — [getFromCurrentZone] answers `null`
/// to both.
///
/// Dropping the guard does not relax the key lookup: [t] is matched exactly,
/// with the same consequences described on [getFromCurrentZone]. A value stored
/// under a subtype of [t] is not found here either.
///
/// ## Parameters
///
/// - [t]: The [Type] to use as the zone value key. Must be the same type the
///   producer used, not merely a supertype of the stored value.
///
/// ## Returns
///
/// The zone value stored under [t], or `null` if that key is absent.
Object? getObjectFromCurrentZone(Type t) {
  return Zone.current[t];
}

// =============================================================================
// CHECKED EXECUTION
// =============================================================================

/// Runs an async function, translating any [Exception] it throws.
///
/// Executes [body] and catches every [Exception], transforming it with
/// [onError] before throwing the result. This is useful for wrapping a
/// low-level failure in a domain-specific exception.
///
/// ## Example
///
/// ```dart
/// final data = await runChecked(
///   () => httpClient.get(url),
///   (error, stacktrace) => TomException(
///     'catalog.fetch.unreachable',
///     'Request failed',
///     rootException: error,
///     stack: stacktrace,
///   ),
/// );
/// ```
///
/// [onError] *returns* the replacement rather than throwing it, which is what
/// makes it impossible to write a transform that swallows the failure: a
/// handler that falls off its end does not compile.
///
/// It returns an [Exception], so the replacement is something a caller can
/// catch by type. `Object` would have let a transform return `42`, and the
/// wrapper would then have thrown the integer — a failure no
/// `on SomeException catch` clause can ever match, reaching the top of the
/// isolate as an unhandled `int`. The narrower type is also the symmetric half
/// of the rule below: this translates an [Exception] into an [Exception], and
/// neither manufactures a bug nor hides one.
///
/// Returning a [TomException] is what carries the `error` and `stacktrace`
/// arguments forward rather than discarding them.
///
/// ## An `Error` is not translated
/// Only an [Exception] reaches [onError]. An [Error] — `StateError`,
/// `RangeError`, `TypeError`, `StackOverflowError` — propagates unchanged, and
/// so does any other object a body throws.
///
/// The distinction is Dart's own: an `Exception` reports a condition the
/// program is expected to handle, an `Error` reports a fault in the program
/// itself. Translating the second kind turns a bug into a domain failure the
/// caller then treats as an ordinary outcome — `.first` on an empty list
/// becomes "not found", a bad cast becomes "the request was invalid" — and the
/// defect is reported at the wrong layer, under a message that describes
/// something else. A wrapper this small should not be able to hide a bug.
///
/// So a body that means "no such thing" has to say so:
///
/// ```dart
/// // Wrong: `.first` throws StateError, which is a bug, and now propagates.
/// final one = await runChecked(
///   () async => (await repository.find(query)).first,
///   (error, stack) => TomException('catalog.find.failed', 'Lookup failed'),
/// );
///
/// // Right: absence is a condition, so it is thrown as one.
/// final other = await runChecked(
///   () async {
///     final rows = await repository.find(query);
///     if (rows.isEmpty) {
///       throw TomException('catalog.find.no_match', 'Nothing matched $query');
///     }
///     return rows.first;
///   },
///   (error, stack) => TomException('catalog.find.failed', 'Lookup failed'),
/// );
/// ```
///
/// A caller that genuinely must translate an `Error` should catch it where it
/// happens, with an explicit `on Error`, which says so at the point it is
/// decided rather than everywhere this wrapper is used.
///
/// ## Parameters
///
/// - [body]: The async function to execute.
/// - [onError]: Transform function called when [body] throws an [Exception].
///
/// ## Returns
///
/// The result of [body] if successful.
///
/// ## Throws
///
/// The [Exception] [onError] returns, when [body] throws an [Exception]; and
/// anything else [body] throws, unaltered.
Future<T> runChecked<T>(
  Future<T> Function() body,
  Exception Function(Object error, StackTrace stacktrace) onError,
) async {
  try {
    return await body();
  } on Exception catch (error, stacktrace) {
    throw onError(error, stacktrace);
  }
}

/// Synchronous version of [runChecked].
///
/// Executes [body] synchronously and catches every [Exception], transforming it
/// with [onError] into another [Exception] before throwing that. An [Error],
/// and anything else that is not an [Exception], propagates unchanged — see
/// [runChecked] for why, and for why [onError] cannot return an arbitrary
/// object.
///
/// ## Example
///
/// ```dart
/// final config = runCheckedSync(
///   () => parseConfig(jsonString),
///   (error, stacktrace) => TomException(
///     'config.parse.invalid_format',
///     'Invalid config format',
///     rootException: error,
///     stack: stacktrace,
///   ),
/// );
/// ```
T runCheckedSync<T>(
  T Function() body,
  Exception Function(Object error, StackTrace stacktrace) onError,
) {
  try {
    return body();
  } on Exception catch (error, stacktrace) {
    throw onError(error, stacktrace);
  }
}

// =============================================================================
// STACK TRACE UTILITIES
// =============================================================================

/// Logs a formatted stack trace at ERROR level.
///
/// Formats the trace with [tomGetStackTrace], prefixes it with [message] when
/// one is given, and passes the result to `tomLog.error`. Despite the name it
/// does **not** call [print]: the text goes wherever the configured log
/// outputs point, so under a recording output in a test it never reaches
/// stdout, and under a filtered one it is dropped entirely.
///
/// Nothing is logged when there would be nothing to say — no message and no
/// frames. That combination is reachable three ways: `depth: 0`, which is a
/// meaningful request for no frames; [StackTrace.empty]; and a trace whose
/// every frame was filtered out as noise. In each case an unconditional call
/// emitted an ERROR record with an empty body, which is worse than silence: it
/// asserts that something failed, describes nothing, and does so at the level
/// operators alert on.
///
/// ## Parameters
///
/// - [s]: The stack trace, or `null` to use [StackTrace.current].
/// - [message]: Optional prefix message for the log entry.
/// - [depth]: Maximum number of frames to include. Any negative value means
///   all frames — -1 is the conventional spelling, not a required sentinel.
void tomPrintStackTrace(StackTrace? s, {String? message, int depth = -1}) {
  // Composing from the parts that have content, rather than concatenating
  // unconditionally, decides all four combinations in one place — and drops
  // the separator a message with no trace would otherwise leave dangling.
  final trace = tomGetStackTrace(s, depth);
  final parts = [
    if (message != null && message.isNotEmpty) message,
    if (trace.isNotEmpty) trace,
  ];
  if (parts.isEmpty) return;
  tomLog.error(parts.join(' '));
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

/// Classifies a stack frame as noise for the formatting functions in this
/// library.
///
/// Four groups are folded by default. Each describes machinery rather than the
/// failure, so none of them can be unregistered:
///
/// | Folded | Why |
/// | ------ | --- |
/// | Dart core-library frames (`frame.isCore`) | The runtime's own plumbing. |
/// | `package:shelf` frames | The HTTP server the request arrived through. |
/// | Members named `TomLogger.*` | The logger that is reporting the failure. |
/// | This library's formatting functions | They record the act of formatting, never the failure. |
///
/// An application built on this framework has a layer of its own that is noise
/// in the same way, and folding it needs no change here. Register a predicate
/// at startup and every trace formatted anywhere in the process folds it —
/// including the ones [TomException] and the logger format for themselves,
/// which a per-call parameter could never reach:
///
/// ```dart
/// void main() {
///   tomStackTraceNoise.addPackage('my_framework');
///   tomStackTraceNoise.addMemberPrefix('MyRequestPipeline.');
///   runMyApp();
/// }
/// ```
///
/// Registration is a startup act. The list is process-wide and is read while a
/// trace is being formatted, so a registration made mid-flight changes what a
/// trace formatted concurrently shows.
///
/// A registered predicate only *adds* to the fold. It cannot rescue a frame the
/// built-in set already claimed, which is why the two are asked in that order
/// and why there is no way to say "not noise".
class TomStackTraceNoise {
  final List<bool Function(Frame frame)> _additional =
      <bool Function(Frame frame)>[];

  /// The predicates registered on top of the built-in set, in registration
  /// order.
  ///
  /// Unmodifiable: register through [addPredicate], [addPackage] or
  /// [addMemberPrefix] so that every registration goes through one place.
  List<bool Function(Frame frame)> get predicates =>
      List<bool Function(Frame frame)>.unmodifiable(_additional);

  /// Folds every frame [predicate] accepts, in addition to the built-in set.
  ///
  /// The general form. [addPackage] and [addMemberPrefix] are the two shapes
  /// that cover nearly every case, and neither requires the caller to name a
  /// [Frame] at all.
  void addPredicate(bool Function(Frame frame) predicate) {
    _additional.add(predicate);
  }

  /// Folds every frame belonging to [package].
  ///
  /// [Frame.package] is the package name without the `package:` scheme, and is
  /// `null` for a frame from a `file:` or `dart:` URI. So this matches a layer
  /// resolved as a package — which is how a framework a consumer depends on
  /// appears in its traces.
  void addPackage(String package) {
    addPredicate((Frame frame) => frame.package == package);
  }

  /// Folds every frame whose member name starts with [prefix].
  ///
  /// The shape the built-in `TomLogger.` rule takes, and the one that reaches a
  /// layer compiled into the application itself, where there is no package name
  /// to match on. Include the trailing `.` to match a class's members without
  /// also matching a class whose name merely starts the same way.
  void addMemberPrefix(String prefix) {
    addPredicate((Frame frame) => frame.member?.startsWith(prefix) ?? false);
  }

  /// Removes every registered predicate. The built-in set is unaffected.
  ///
  /// For a test that registered one and must not leak it into the next. A
  /// process that registers at startup has no reason to call it — and should
  /// not, since it would also drop a registration made by a library it depends
  /// on.
  void clear() {
    _additional.clear();
  }

  /// Whether [frame] is noise and should be folded away.
  ///
  /// A registered predicate that throws is treated as answering `false`, and
  /// the frame is kept. These functions run while some *other* failure is being
  /// reported, and letting a predicate's failure out would lose that report in
  /// order to complain about the machinery describing it — the same trade this
  /// library already makes for an out-of-range depth and for a `stack` that is
  /// not a [StackTrace]. Nor is it logged: the logger formats its own traces
  /// through this very function, so reporting here would re-enter it.
  ///
  /// Keeping the frame is the safe direction. An unfolded frame makes a trace
  /// longer, which the author of the broken predicate will see; folding on a
  /// failure would hide frames for a reason no one could observe.
  bool isNoise(Frame frame) {
    if (frame.isCore ||
        frame.package == 'shelf' ||
        _isFormatterFrame(frame) ||
        (frame.member?.startsWith("TomLogger.") ?? false)) {
      return true;
    }
    for (final bool Function(Frame frame) predicate in _additional) {
      bool matched = false;
      try {
        matched = predicate(frame);
      } on Object {
        matched = false;
      }
      if (matched) {
        return true;
      }
    }
    return false;
  }
}

/// The process-wide noise classification every formatter in this library uses.
///
/// One instance rather than a parameter on each function, because the callers
/// that most need the classification are not the application's own: a trace
/// formatted by [TomException] or by the logger takes the same path, and a
/// per-call parameter would reach neither. See [TomStackTraceNoise].
final TomStackTraceNoise tomStackTraceNoise = TomStackTraceNoise();

/// Core implementation for processing stack trace frames.
///
/// Folds and filters stack frames to remove noise — the built-in set plus
/// whatever a consumer registered on [tomStackTraceNoise] — then flattens
/// every segment of the async chain into one list.
///
/// ## Parameters
///
/// - [s]: The stack trace to process. Defaults to [StackTrace.current].
/// - [depth]: Maximum frames to return. Any negative value means all frames —
///   -1 is the conventional spelling, not a required sentinel.
///
/// ## Returns
///
/// A list of formatted stack frame strings, newest first. Empty when the trace
/// carries no frames — see [StackTrace.empty] below.
List<String> _processStackFrames([StackTrace? s, int depth = -1]) {
  // The parameter is `StackTrace?`, not `Object?`. Widening it and narrowing
  // here with `s as StackTrace?` would accept anything at the call site and
  // then throw a `TypeError` at this line — while formatting a trace, i.e.
  // while reporting some *other* failure, and in `TomException`'s case before
  // the exception being reported even existed. The narrow parameter rejects
  // the same values at compile time, where the mistake is free.
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
      .foldFrames(tomStackTraceNoise.isNoise, terse: true)
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
    //
    // `depth >= 0` rather than the equivalent `depth > -1`: it says what the
    // condition means. A non-negative depth is a bound; *every* negative one
    // is the absence of a bound, so -1 is the conventional spelling of "no
    // limit" and not a sentinel this walk tests for. A depth computed rather
    // than written can land on -2, and that is unbounded like the rest.
    //
    // Deliberately not rejected. These functions run while reporting some
    // other failure, and throwing here would lose that failure to complain
    // about the depth used to describe it — the same trade already settled
    // for the trace parameter above and for a non-StackTrace `stack` in
    // TomException.printStackTrace.
    if (depth >= 0 && remaining-- == 0) break;
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
/// - [depth]: Maximum number of frames to include. Any negative value means
///   all frames — -1 is the conventional spelling, not a required sentinel.
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
/// - [depth]: Maximum number of frames to include. Any negative value means
///   all frames — -1 is the conventional spelling, not a required sentinel.
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
/// - [depth]: Maximum number of frames to include. Any negative value means
///   all frames — -1 is the conventional spelling, not a required sentinel.
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
(String, List<String>) tomGetStackTraceAsTuple([
  StackTrace? s,
  int depth = -1,
]) {
  List<String> stackLines = _processStackFrames(s, depth);
  String stackString = stackLines.join('\n');
  return (stackString, stackLines);
}
