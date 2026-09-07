/// Exception base classes and error handling utilities.
///
/// This library provides the foundation for exception handling throughout
/// the tom_core framework. It includes:
///
/// - [TomException] - Full-featured exception class with logging and server error support
///
/// For the minimal base class without dependencies, see [TomBaseException]
/// from the `tom_basics` package.
///
/// ## Example
///
/// ```dart
/// // Create and throw a tracked exception
/// throw TomException(
///   'user.fetch.not_found',
///   'The requested user could not be found',
///   parameters: {'userId': userId},
///   autoLog: true,
/// );
///
/// // Catch and inspect
/// try {
///   // ... operation that may fail
/// } on TomException catch (e) {
///   print('Error ${e.uuid}: ${e.key}');
///   e.printStackTrace();
/// }
/// ```
library;

import 'package:stack_trace/stack_trace.dart';
import 'package:tom_basics/tom_basics.dart';

import '../http_connection/server_connection.dart';
import 'little_things.dart';

// =============================================================================
// EXCEPTION CLASSES
// =============================================================================

/// Full-featured exception class with logging, server error tracking, and UUID support.
///
/// [TomException] extends [TomBaseException] with additional features:
///
/// - **Auto Logging**: Optional automatic logging when thrown
/// - **Server Call Error**: Track HTTP-related error details
/// - **TomLoggable**: Integration with the TOM logging system
///
/// For a minimal exception class without these dependencies, use
/// [TomBaseException] from the `tom_basics` package.
///
/// ## Example
///
/// ```dart
/// // Basic exception
/// throw TomException('order.submit.rejected', 'Something went wrong');
///
/// // Exception with parameters for context
/// throw TomException(
///   'signup.validate.invalid_email',
///   'Invalid email format',
///   parameters: {'field': 'email', 'value': userInput},
/// );
///
/// // Exception with auto-logging enabled
/// throw TomException(
///   'storage.connect.unreachable',
///   'Database connection failed',
///   autoLog: true,
///   rootException: originalException,
/// );
/// ```
///
/// See also:
/// - [TomBaseException] for the minimal base class
/// - [TomServerConnectionException] for HTTP-related errors
/// - [TomLoggable] for the logging interface
class TomException extends TomBaseException implements TomLoggable {
  /// Whether to automatically log this exception when created.
  bool autoLog;

  /// Server call error details, if this exception originated from an HTTP call.
  TomServerCallError? serverCallError;

  /// Creates a new [TomException] with the given error details.
  ///
  /// The [key] is the error code callers match on, written dotted-lowercase as
  /// `<area>.<operation>.<condition>` — the first segment names the module, so
  /// keys from unrelated code cannot collide.
  /// The [defaultUserMessage] should be human-readable.
  ///
  /// If [autoLog] is true, the exception is logged immediately upon creation.
  ///
  /// When no [stack] is given the trace is captured here, at the construction
  /// site, so [printStackTrace] can report where the failure arose.
  TomException(
    String key,
    String defaultUserMessage, {
    String? requestUuid,
    Map<String, Object?>? parameters,
    Object? rootException,
    this.autoLog = false,
    StackTrace? stack,
    String? uuid,
    this.serverCallError,
  }) : super(
         key,
         defaultUserMessage,
         requestUuid: requestUuid,
         parameters: parameters,
         rootException: rootException,
         // Capture the trace *here* rather than leaving `stack` null. Left
         // null it is captured later, inside the formatter, which by then is
         // the only thing on the stack — so `printStackTrace` reported the
         // formatter's call path and never the failure's. The capture belongs
         // in the constructor because that is the last moment at which the
         // creating code is still on the stack.
         //
         // Passing it to `super` rather than assigning it in the body is what
         // keeps the two representations in step: the base constructor derives
         // the formatted `stackTrace` string from this argument, so the raw
         // trace and the string describe the same place. Assigning afterwards
         // would leave `stackTrace` — which `autoLog` writes — pointing at the
         // base class's own formatter.
         stack: stack ?? StackTrace.current,
         uuid: uuid,
       ) {
    // Only for the implicit capture. A `stack` the caller handed in is their
    // trace of their failure, and nothing above belongs to this class.
    if (stack == null) _dropOwnConstructorFrames();
    if (autoLog) {
      tomLog.error("EXCEPTION: $this");
      // `this.` is load-bearing: the constructor's `uuid` and `requestUuid`
      // parameters shadow the fields, and both are null in the common case
      // where the caller supplies neither. Unqualified, the correlation id on
      // this line read `null-null` while the EXCEPTION line above and
      // [printStackTrace] both reported the generated uuid — two log lines
      // describing one exception, disagreeing about which one it was.
      tomLog.error(
        "EXCEPTION_STACKTRACE: ${this.uuid}-${this.requestUuid} $stackTrace",
      );
    }
  }

  /// Removes this exception's own constructor frames from the captured trace.
  ///
  /// The capture in the initializer above is taken at the last moment the
  /// creating code is still on the stack — and therefore also while every
  /// constructor in this exception's own chain is. Those frames lead the trace
  /// and say nothing: `new TomException` is on every trace in the system, and a
  /// subclass adds one more per level. The cost is that a useful `depth` starts
  /// at 2 rather than 1, on a hierarchy of ~30 subclasses.
  ///
  /// The run is bounded by **this exception's own leaf constructor**, which is
  /// what makes the rule safe. Dropping a leading run of `new …` frames
  /// unconditionally would swallow an application constructor that happens to
  /// throw — the trace of `MyThing()` raising in its own body opens with
  /// `new TomException`, `new MyThing`, and only the first of those is noise.
  /// Stopping at `new $runtimeType` keeps `new MyThing`, because for a directly
  /// constructed `TomException` the leaf *is* the first frame.
  ///
  /// Both representations are rewritten together. `TomBaseException` derives
  /// its `stackTrace` string from `stack` in its constructor, so leaving one
  /// trimmed and the other not would have the raw trace and the string an
  /// `autoLog` writes disagree about which frame comes first.
  ///
  /// Leaves the trace untouched when the leaf frame is not found, rather than
  /// guessing how much to drop: this runs while an exception is being built, so
  /// a wrong answer here corrupts the report of some other failure.
  void _dropOwnConstructorFrames() {
    final raw = stack;
    if (raw is! StackTrace) return;

    // Fold core frames first, exactly as `TomBaseException` does before
    // rendering, so the trimmed trace and the string it derives stay identical
    // to what the base would have produced for it.
    final frames = Chain.forTrace(raw)
        .foldFrames((frame) => frame.isCore, terse: true)
        .traces
        .expand((trace) => trace.frames)
        .toList();

    final leaf = 'new $runtimeType';
    var last = -1;
    for (var i = 0; i < frames.length; i++) {
      final member = frames[i].member;
      // The chain is contiguous and leads the trace; the first frame that is
      // not a constructor ends it, whether or not the leaf was reached.
      if (member == null || !member.startsWith('new ')) break;
      if (member == leaf) {
        last = i;
        break;
      }
    }
    if (last < 0) return;

    final trimmed = Trace(frames.skip(last + 1));
    stack = trimmed;
    stackTrace = trimmed.toString();
  }

  @override
  String get logRepresentation => toString();

  /// Logs the stack trace at ERROR level.
  ///
  /// The [depth] parameter limits how many stack frames are included. Any
  /// negative value means all frames — -1 is the default and the conventional
  /// spelling, not a required sentinel.
  ///
  /// The name is inherited, and so is misleading here: `TomBaseException`
  /// genuinely calls [print], this override routes the same report through
  /// `tomLog.error` instead. So the destination is whatever the configured
  /// log outputs are, not stdout — worth knowing when a caught exception
  /// appears to report nothing.
  ///
  /// A `stack` that is not a [StackTrace] is reported as no trace at all — the
  /// identifying message alone. See below for why nothing is substituted.
  @override
  void printStackTrace([int depth = -1]) {
    // `StackTrace.empty`, not `null`. The field is publicly mutable and can be
    // cleared, and `null` would fall through to `StackTrace.current` inside the
    // formatter and report the call path of the *report* — frames that name
    // none of the code that failed. A wrong trace is worse than no trace,
    // because it looks right.
    //
    // `TomBaseException.stack` is `StackTrace?` as of tom_basics 1.1.0, so the
    // absent value is the only unusable one and a null check is the whole of
    // the substitution.
    tomPrintStackTrace(
      stack ?? StackTrace.empty,
      depth: depth,
      message: "$uuid-$requestUuid exception stacktrace",
    );
  }
}
