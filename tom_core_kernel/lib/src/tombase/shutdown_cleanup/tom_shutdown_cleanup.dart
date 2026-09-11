/// Shutdown cleanup module for graceful process termination.
///
/// This module provides a comprehensive system for managing cleanup operations
/// when a process receives termination signals (SIGHUP, SIGINT, etc.). It ensures
/// that resources are properly released and cleanup handlers are executed in an
/// orderly fashion before the process exits.
///
/// The module supports three types of cleanup mechanisms:
/// - [TomDisposable]: Objects that implement a `dispose()` method
/// - [TomClosable]: Objects that implement a `close()` method
/// - [TomSignalHandler]: Custom signal handlers for specialized cleanup logic
///
/// Each of the three may be **asynchronous**. The shutdown awaits whatever an
/// entry returns before it calls the next one, within a per-phase budget
/// ([TomShutdownCleanup.phaseTimeout]) that keeps one entry that never finishes
/// from holding the process open.
///
/// ## Quick Start
///
/// Registering a resource is the whole setup. Signal listening is already
/// active — [TomShutdownCleanup] registers SIGHUP and SIGINT in its
/// constructor — so there is no arming step to remember or to get wrong.
///
/// ```dart
/// // Use the default global instance
/// tomShutdownCleanup.addClosable(myDatabaseConnection);
/// tomShutdownCleanup.addDisposable(myStreamController);
/// ```
///
/// See also:
/// - [TomShutdownCleanup] for the main cleanup coordinator
/// - [TomCloseAdaptor] for adapting objects without explicit interfaces
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:tom_reflection/mirrors.dart';

import '../little_things/little_things.dart';
import '../reflection/reflection.dart';

// =============================================================================
// Type Definitions
// =============================================================================

/// Handler function type for processing system signals.
///
/// Called when a registered signal is received by the process.
/// The [onData] parameter contains the specific signal that was received.
///
/// A handler may be `async`: the shutdown awaits the future it returns before
/// it calls the next handler, and before the closables phase begins.
typedef TomSignalHandler = FutureOr<void> Function(ProcessSignal onData);

// =============================================================================
// Interfaces
// =============================================================================

/// Interface for objects that can be disposed during shutdown.
///
/// Implement this interface for objects that need cleanup logic executed
/// when the process terminates. The [dispose] method will be called
/// automatically by [TomShutdownCleanup] when a termination signal is received.
///
/// ## Example
///
/// ```dart
/// class MyResource implements TomDisposable {
///   final StreamController _controller = StreamController();
///
///   @override
///   void dispose() {
///     _controller.close();
///     print('MyResource disposed');
///   }
/// }
///
/// // Register with shutdown cleanup
/// final resource = MyResource();
/// tomShutdownCleanup.addDisposable(resource);
/// ```
abstract class TomDisposable {
  /// Disposes of resources held by this object.
  ///
  /// This method is called automatically during shutdown cleanup.
  /// Implementations should release all resources and perform
  /// any necessary cleanup operations.
  ///
  /// May be asynchronous: the shutdown awaits a returned `Future` before it
  /// disposes the next object. See [TomClosable.close] for how long it waits.
  FutureOr<void> dispose();
}

/// Interface for objects that can be closed during shutdown.
///
/// Implement this interface for objects that need to be closed
/// when the process terminates. The [close] method will be called
/// automatically by [TomShutdownCleanup] when a termination signal is received.
///
/// ## Example
///
/// ```dart
/// class MyConnection implements TomClosable {
///   Socket? _socket;
///
///   @override
///   void close() {
///     _socket?.close();
///     print('Connection closed');
///   }
/// }
///
/// // Register with shutdown cleanup
/// final connection = MyConnection();
/// tomShutdownCleanup.addClosable(connection);
/// ```
abstract class TomClosable {
  /// Closes resources held by this object.
  ///
  /// This method is called automatically during shutdown cleanup.
  /// Implementations should close all connections, streams, or
  /// other resources that require explicit closing.
  ///
  /// May be asynchronous. The shutdown awaits a returned `Future` before it
  /// closes the next object, so a flush, a socket close or a queue drain has
  /// finished by the time the phase moves on; a failure inside that future is
  /// reported like one thrown by the call itself.
  ///
  /// The wait is bounded. Every phase has [TomShutdownCleanup.phaseTimeout] to
  /// finish in, and a phase that overruns it is abandoned — the entry it was
  /// waiting on and every entry behind it — so a close that never completes
  /// costs the rest of its phase, not the whole shutdown.
  FutureOr<void> close();
}

// =============================================================================
// Adaptor Classes
// =============================================================================

/// Adaptor that wraps objects with close/dispose methods to implement [TomClosable].
///
/// This class uses reflection to find and invoke close or dispose methods
/// on objects that don't explicitly implement [TomClosable] or [TomDisposable].
/// It reaches the method through the global `tomReflector`, so it works on
/// **classes in your own build that carry `@tomReflector`** — typically ones
/// already annotated for JSON — and not on types from outside it.
///
/// ## Example
///
/// ```dart
/// // A class of your own, annotated for reflection, whose teardown method
/// // you would rather not re-expose by implementing TomClosable.
/// @tomReflector
/// class SessionStore {
///   void close() { /* ... */ }
/// }
///
/// final adaptor = TomCloseAdaptor(SessionStore());
/// tomShutdownCleanup.addClosable(adaptor);
///
/// // Specify a custom method name
/// @tomReflector
/// class Worker {
///   void shutdown() { /* ... */ }
/// }
///
/// tomShutdownCleanup.addClosable(TomCloseAdaptor(Worker(), 'shutdown'));
/// ```
///
/// ## Limitations
///
/// - The target method must have no required parameters
/// - The target's class must be annotated with `@tomReflector` **and** its
///   generated reflection data must have been initialized, which means a
///   `build_runner` step in the package that declares the class
/// - Consequently the adaptor cannot wrap a type you do not own: `dart:io`'s
///   `HttpClient`, or any class from a package you cannot annotate, is out of
///   reach no matter what methods it declares. Wrap such an object in a small
///   class of your own that implements [TomClosable] instead — which is also
///   cheaper, because it needs no reflection at all
///
/// Throws an [Exception] if:
/// - The object's class is not reflectable (a [TomReflectorException])
/// - No close/dispose method is found on the object
/// - The method requires parameters
class TomCloseAdaptor implements TomClosable {
  /// The object being adapted for closure.
  ///
  /// Fixed at construction. The constructor resolves the target's method
  /// mirror and binds an instance mirror to *this* object, and [close] invokes
  /// through that binding — so the adaptor is single-target by construction,
  /// and this field always names the object [close] will actually close. To
  /// close a different object, build a different adaptor.
  final Object closableObject;

  late final MethodMirror _mm;
  late final InstanceMirror _im;

  /// Creates a new adaptor for the given object.
  ///
  /// [closableObject] - The object to wrap. Must have a close() or dispose() method.
  /// [methodName] - Optional custom method name to invoke. If not provided,
  ///                looks for 'close' first, then 'dispose'.
  TomCloseAdaptor(this.closableObject, [String? methodName]) {
    final classMirror = _reflectClass(closableObject);
    MethodMirror? mm = _resolveCloseMethod(classMirror, methodName);
    if (mm == null) {
      throw Exception(
        "TomCloseAdaptor: didn't find a close method in the object you provided.",
      );
    }
    if (mm.parameters.isNotEmpty) {
      throw Exception(
        "TomCloseAdaptor: the method ${mm.simpleName} needs parameter. You need to implement a custom solution for this.",
      );
    }
    _mm = mm;
    _im = tomReflector.reflect(closableObject);
  }

  /// Resolves the class mirror of [closableObject], insisting it is reflectable.
  ///
  /// This is the adaptor's *most likely* failure rather than an exotic one:
  /// the class is reached for when a type does not implement [TomClosable] or
  /// [TomDisposable], and the types that do not are frequently the ones nobody
  /// can annotate. Left unguarded, `tom_reflection` answers with a
  /// `NoSuchCapabilityError` — an [Error], not an [Exception] — that names the
  /// type and nothing else: not the operation that wanted it, and not the
  /// annotation that would fix it. A caller guarding the constructor with
  /// `on Exception` would miss it entirely, even though the constructor's two
  /// other failures are exceptions. Reporting it as a [TomReflectorException]
  /// is what the rest of the package already does for this same condition.
  ///
  /// It is not logged on the way out. Unlike the shutdown diagnostics this
  /// happens at construction time, in the caller's own control flow, and the
  /// thrown object carries the full detail to whoever asked for it.
  static ClassMirror _reflectClass(Object closableObject) {
    try {
      return tomReflector.reflectType(closableObject.runtimeType)
          as ClassMirror;
    } catch (e, s) {
      throw TomReflectorException(
        "shutdown_cleanup.close_adaptor.not_reflectable",
        "TomCloseAdaptor: cannot reflect on ${closableObject.runtimeType} — "
            "the class is not annotated with @tomReflector, or its generated "
            "reflection data was not initialized. A type you do not own cannot "
            "be annotated; wrap it in a class of your own that implements "
            "TomClosable instead: $e",
        rootException: e,
        stack: s,
      );
    }
  }

  /// Resolves the close/dispose method to invoke, walking the superclass chain.
  ///
  /// `ClassMirror.declarations` holds only the type's **own** members, so a
  /// `close()`/`dispose()` inherited from a superclass or mixin is invisible to
  /// the leaf type alone. This walks from the concrete type up its
  /// superclass chain, so the most-derived class wins and, at each level, an
  /// explicit [methodName] is honoured (otherwise `close` is preferred over
  /// `dispose`). Returns `null` when no matching method exists anywhere.
  static MethodMirror? _resolveCloseMethod(
    ClassMirror classMirror,
    String? methodName,
  ) {
    ClassMirror? current = classMirror;
    while (current != null) {
      final declarations = current.declarations;
      final candidate = methodName != null
          ? declarations[methodName]
          : (declarations['close'] ?? declarations['dispose']);
      if (candidate is MethodMirror) {
        return candidate;
      }
      current = current.superclass;
    }
    return null;
  }

  /// Invokes the close/dispose method on the wrapped object, handing on the
  /// `Future` it returns so an asynchronous target is awaited like any other
  /// [TomClosable].
  @override
  FutureOr<void> close() {
    final result = _im.invoke(_mm.simpleName, []);
    if (result is Future) return result.then<void>((_) {});
  }
}

// =============================================================================
// Main Shutdown Cleanup Class
// =============================================================================

/// Central coordinator for graceful shutdown cleanup operations.
///
/// [TomShutdownCleanup] manages the orderly cleanup of resources when the
/// process receives termination signals. It automatically listens for
/// SIGHUP and SIGINT signals by default, and supports adding additional
/// signals as needed.
///
/// The cleanup process executes in the following order:
/// 1. Signal handlers (custom cleanup logic)
/// 2. Closables (objects implementing [TomClosable])
/// 3. Disposables (objects implementing [TomDisposable])
///
/// Every entry is awaited before the next one is called, and each phase has
/// [phaseTimeout] to finish in. A failing entry — whether it throws or its
/// future fails — does not stop the ones behind it: the failure is reported
/// with its exception and the top frames of its stack, printed rather than
/// logged, and suppressed by [silent].
///
/// ## Basic Usage
///
/// Registration is the only setup step; the constructor has already begun
/// listening for SIGHUP and SIGINT.
///
/// ```dart
/// // Use the global instance
/// tomShutdownCleanup.addClosable(databaseConnection);
/// tomShutdownCleanup.addDisposable(streamController);
/// ```
///
/// ## Running it yourself
///
/// ```dart
/// // Returns once every entry has finished, or its phase was abandoned.
/// await tomShutdownCleanup.performShutdown();
/// exit(0);
/// ```
///
/// ## Custom Signal Handlers
///
/// ```dart
/// tomShutdownCleanup.addSignalHandler((signal) async {
///   print('Received signal: $signal');
///   await flushJournal(); // awaited before the closables run
/// });
/// ```
///
/// ## Adding Additional Signals
///
/// ```dart
/// // Listen for SIGTERM in addition to default signals
/// tomShutdownCleanup.addSignal(ProcessSignal.sigterm);
/// ```
///
/// ## Creating Custom Instances
///
/// ```dart
/// // Create a separate cleanup handler for specific signals
/// final customCleanup = TomShutdownCleanup();
/// customCleanup.addSignal(ProcessSignal.sigusr1);
/// customCleanup.addSignalHandler((signal) {
///   // Handle USR1 signal specifically
/// });
///
/// // A custom instance that outlives the program needs nothing further. One
/// // that does not — in a test, a sample, or any bounded scope — must be
/// // disposed, because its watchers keep the process alive:
/// await customCleanup.dispose();
/// ```
class TomShutdownCleanup {
  /// Frames kept from a failing cleanup's stack trace.
  ///
  /// Bounded rather than unlimited: a shutdown can fail in several entries at
  /// once, and full traces from each would bury the failure list in the very
  /// output an operator is scanning. The frames that identify a `close()` or
  /// `dispose()` failure are the top ones.
  static const int _diagnosticStackDepth = 10;

  /// The [phaseTimeout] a new instance starts with.
  ///
  /// Long enough for a flush, a socket close or a pool drain on a healthy
  /// system; short enough that a teardown that has hung is given up on before
  /// an operator reaches for `kill -9`.
  static const Duration defaultPhaseTimeout = Duration(seconds: 10);

  late final void Function(ProcessSignal signal) _signalHandler;

  /// The shutdown, once one has started; every later caller gets this one.
  Future<void>? _shutdown;

  /// Whether [_shutdown] has finished — which decides what a late signal
  /// reports, not whether anything runs.
  bool _shutdownFinished = false;

  Duration _phaseTimeout = defaultPhaseTimeout;

  /// When true, signal handling is paused and signals are ignored.
  /// Use this in interactive REPLs that have their own CTRL-C handling.
  bool paused = false;

  /// When true, suppresses output messages during shutdown.
  bool silent = false;

  /// How long each of the three phases may take before it is abandoned.
  ///
  /// The budget is per phase, and it covers the whole phase rather than each
  /// entry: the time every entry takes — awaited or synchronous — is spent
  /// from it. When it runs out, the entry being awaited is left to finish on
  /// its own and the entries behind it in the same phase are not called; the
  /// next phase then starts with a budget of its own. An abandoned entry that
  /// fails later is still reported.
  ///
  /// A synchronous entry cannot be interrupted. One that overruns the budget
  /// runs to its end, and the entries behind it are then abandoned.
  ///
  /// Defaults to [defaultPhaseTimeout]. Must be positive: a budget of nothing
  /// would abandon every asynchronous entry unseen.
  Duration get phaseTimeout => _phaseTimeout;

  set phaseTimeout(Duration value) {
    if (value <= Duration.zero) {
      throw ArgumentError.value(
        value,
        'phaseTimeout',
        'must be positive; a shutdown phase needs time to run',
      );
    }
    _phaseTimeout = value;
  }

  /// Creates a new shutdown cleanup coordinator.
  ///
  /// Automatically registers listeners for SIGHUP and SIGINT signals.
  /// The cleanup will only execute once, even if multiple signals are received.
  ///
  /// Use [tomShutdownCleanup] for the default global instance, or create
  /// custom instances for specialized signal handling.
  TomShutdownCleanup() {
    // Nothing waits on a stream listener, so the shutdown the signal starts is
    // deliberately not awaited here. A caller that needs to know when it has
    // finished calls performShutdown() and is handed the same shutdown.
    _signalHandler = (signal) =>
        unawaited(performShutdown(signal: signal, fromSignal: true));
    // SIGHUP/SIGINT are registered through the same watcher-subscription path
    // as [addSignal], so there is a single place that owns how a signal is
    // watched and how its subscription is retained for teardown.
    addSignal(ProcessSignal.sighup);
    addSignal(ProcessSignal.sigint);
  }

  /// Runs the shutdown cleanup — registered signal handlers, then closables,
  /// then disposables — exactly once across the instance's life, and completes
  /// when it has finished.
  ///
  /// Every entry is awaited, within [phaseTimeout] per phase, so the returned
  /// future completes only once the teardown has happened or been given up on.
  /// That is what makes it safe to exit the process after awaiting it.
  ///
  /// The first call starts the shutdown and every later one — manual or
  /// signal-driven, during it or after it — is handed that same shutdown
  /// rather than a second run. A caller that awaits it therefore always waits
  /// for the real thing, whoever started it. Do not await it from inside one of
  /// the entries: the entry would be waiting for the shutdown that is waiting
  /// for the entry, and only the phase timeout would end it.
  ///
  /// External code calls this directly to run the cleanup without an OS
  /// signal; that manual path always runs (it ignores [paused]) and stays
  /// quiet. The signal-driven path passes [fromSignal] `true`, which honours
  /// [paused] (skip while paused) and gates the status messages on [silent].
  /// [signal] is forwarded to the registered signal handlers.
  Future<void> performShutdown({
    ProcessSignal signal = ProcessSignal.sigint,
    bool fromSignal = false,
  }) {
    // The signal path is suppressed while paused (e.g. interactive REPL mode).
    if (fromSignal && paused) return Future<void>.value();

    final announce = fromSignal && !silent;
    if (announce) print("Received $signal");
    final running = _shutdown;
    if (running != null) {
      if (announce) {
        print(
          _shutdownFinished
              ? "Shutdown has already been performed"
              : "Shutdown is already in progress",
        );
      }
      return running;
    }
    return _shutdown = _executeCleanup(signal, announce: announce);
  }

  /// Runs the three cleanup phases in order — signal handlers, then closables,
  /// then disposables — each finishing, or being abandoned, before the next
  /// begins.
  Future<void> _executeCleanup(
    ProcessSignal signal, {
    required bool announce,
  }) async {
    await _runPhase(
      _signalHandlers,
      "signalHandler",
      (handler) => handler(signal),
    );
    await _runPhase(_closables, "closable", (closable) => closable.close());
    await _runPhase(
      _disposables,
      "disposable",
      (disposable) => disposable.dispose(),
    );
    _shutdownFinished = true;
    if (announce) print("Shutdown performed");
  }

  /// Runs [action] over every entry of [items] in order, awaiting each one
  /// that returns a `Future`, within a budget of [phaseTimeout] for the phase.
  ///
  /// This is the single owner of the per-entry policy all three phases share.
  /// A failing entry — thrown by the call or by the future it returned — never
  /// aborts the phase: a `Failed to call $label $item: $exception` diagnostic
  /// is printed, followed by the top [_diagnosticStackDepth] frames, unless
  /// [silent]. The exception and its trace are part of the report because a
  /// shutdown runs once, usually unattended, and cannot be re-run to find out
  /// what went wrong. Message and trace go out in a single `print` so that
  /// concurrent output cannot separate a failure from its evidence.
  ///
  /// When the budget runs out the phase is abandoned: the entry being awaited
  /// is left to finish on its own, and the ones behind it are not called.
  /// A synchronous entry is never awaited, so a phase of synchronous entries
  /// runs straight through without yielding.
  Future<void> _runPhase<T>(
    List<T> items,
    String label,
    FutureOr<void> Function(T item) action,
  ) async {
    final elapsed = Stopwatch()..start();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final remaining = _phaseTimeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        _reportAbandoned(label, items, index, waitingOn: null);
        return;
      }
      try {
        final result = action(item);
        if (result is Future<void>) {
          final finished = await _finishesWithin(
            result,
            remaining,
            onLateFailure: (exception, stackTrace) => _reportFailure(
              label,
              item,
              exception,
              stackTrace,
              abandoned: true,
            ),
          );
          if (!finished) {
            _reportAbandoned(label, items, index, waitingOn: item);
            return;
          }
        }
      } catch (exception, stackTrace) {
        _reportFailure(label, item, exception, stackTrace);
      }
    }
  }

  /// Whether [work] finishes within [budget]; rethrows its failure if it fails
  /// in time.
  ///
  /// `Future.timeout` is not used because its `TimeoutException` could not be
  /// told apart from one the entry itself throws — a socket close that times
  /// out is a failure to report, not the phase running out of time. A failure
  /// that arrives after the budget has gone is handed to [onLateFailure]
  /// instead of being dropped.
  static Future<bool> _finishesWithin(
    Future<void> work,
    Duration budget, {
    required void Function(Object exception, StackTrace stackTrace)
    onLateFailure,
  }) {
    final outcome = Completer<bool>();
    final deadline = Timer(budget, () {
      if (!outcome.isCompleted) outcome.complete(false);
    });
    unawaited(
      work.then(
        (_) {
          deadline.cancel();
          if (!outcome.isCompleted) outcome.complete(true);
        },
        onError: (Object exception, StackTrace stackTrace) {
          deadline.cancel();
          if (outcome.isCompleted) {
            onLateFailure(exception, stackTrace);
          } else {
            outcome.completeError(exception, stackTrace);
          }
        },
      ),
    );
    return outcome.future;
  }

  void _reportFailure(
    String label,
    Object? item,
    Object exception,
    StackTrace stackTrace, {
    bool abandoned = false,
  }) {
    if (silent) return;
    final trace = tomGetStackTrace(stackTrace, _diagnosticStackDepth);
    final when = abandoned ? " (after its phase abandoned it)" : "";
    final report = "Failed to call $label $item$when: $exception";
    print(trace.isEmpty ? report : "$report\n$trace");
  }

  /// Reports that the [label] phase ran out of [phaseTimeout] at [index]:
  /// [waitingOn] had not finished — or, when `null`, the budget was already
  /// spent before the entry at [index] could be called.
  void _reportAbandoned<T>(
    String label,
    List<T> items,
    int index, {
    required T? waitingOn,
  }) {
    if (silent) return;
    final skipped = items.length - index - (waitingOn == null ? 0 : 1);
    final budget = "${_phaseTimeout.inMilliseconds} ms";
    final cause = waitingOn == null
        ? "its time was spent"
        : "$waitingOn had not finished";
    print(
      "Abandoned the $label phase after $budget: $cause, "
      "$skipped ${skipped == 1 ? 'entry' : 'entries'} behind it not called",
    );
  }

  final List<TomSignalHandler> _signalHandlers = [];
  final List<TomClosable> _closables = [];
  final List<TomDisposable> _disposables = [];

  /// Active OS-signal watcher subscriptions, retained so they can be cancelled
  /// by [dispose]/[cancelAll] — otherwise each watcher keeps the process alive
  /// and leaks for the instance's whole life.
  ///
  /// Keyed by signal rather than held in a list, so that "at most one watcher
  /// per signal" is a property of the structure instead of a rule [addSignal]
  /// has to remember to check.
  final Map<ProcessSignal, StreamSubscription<ProcessSignal>>
  _signalSubscriptions = {};

  /// Adds a custom signal handler to be executed during shutdown.
  ///
  /// Signal handlers are executed first, before closables and disposables.
  /// Use this for custom cleanup logic that doesn't fit the closable/disposable
  /// pattern.
  ///
  /// [handler] - The function to call when a signal is received.
  void addSignalHandler(TomSignalHandler handler) {
    _signalHandlers.add(handler);
  }

  /// Adds a closable object to be closed during shutdown.
  ///
  /// Closables are closed after signal handlers but before disposables.
  ///
  /// [closable] - An object implementing [TomClosable].
  void addClosable(TomClosable closable) {
    _closables.add(closable);
  }

  /// Adds a disposable object to be disposed during shutdown.
  ///
  /// Disposables are disposed last, after signal handlers and closables.
  ///
  /// [disposable] - An object implementing [TomDisposable].
  void addDisposable(TomDisposable disposable) {
    _disposables.add(disposable);
  }

  /// Adds an additional system signal to listen for.
  ///
  /// By default, SIGHUP and SIGINT are already registered.
  /// Use this method to add additional signals like SIGTERM.
  ///
  /// Idempotent per signal: registering one that is already watched does
  /// nothing. Without that, the second watcher would drive the cleanup a
  /// second time on every arrival — harmless to the cleanup itself, which runs
  /// once, but it makes a single Ctrl-C report itself twice and claim on its
  /// own first arrival that shutdown had already been performed. Since the
  /// constructor registers SIGHUP and SIGINT, that collision is one an ordinary
  /// caller can walk into simply by naming a default.
  ///
  /// [processSignal] - The signal to start listening for.
  ///
  /// ## Example
  ///
  /// ```dart
  /// tomShutdownCleanup.addSignal(ProcessSignal.sigterm);
  /// ```
  void addSignal(ProcessSignal processSignal) {
    _signalSubscriptions.putIfAbsent(
      processSignal,
      () => processSignal.watch().listen(_signalHandler),
    );
  }

  /// Cancels every registered OS-signal watcher subscription.
  ///
  /// After this completes the instance no longer keeps the process alive via
  /// its SIGHUP/SIGINT (and any [addSignal]-registered) watchers. Safe to call
  /// more than once; the subscription list is emptied.
  Future<void> cancelAll() async {
    for (final subscription in _signalSubscriptions.values) {
      await subscription.cancel();
    }
    _signalSubscriptions.clear();
  }

  /// Tears the instance down by cancelling its signal watchers (see
  /// [cancelAll]). Call this for any short-lived [TomShutdownCleanup] so its
  /// watchers stop leaking; the process-lifetime global
  /// [tomShutdownCleanup] normally never needs it.
  Future<void> dispose() => cancelAll();
}

// =============================================================================
// Global Instance
// =============================================================================

/// Global default instance of [TomShutdownCleanup].
///
/// Use this instance for most shutdown cleanup needs. It automatically
/// listens for SIGHUP and SIGINT signals from the moment it is created, so
/// registering a resource is all that is needed to have it cleaned up.
///
/// ## Example
///
/// ```dart
/// tomShutdownCleanup.addClosable(myDatabase);
/// tomShutdownCleanup.addDisposable(myController);
/// ```
///
/// Because construction is what arms it, there is no setup call to forget —
/// and equally none to reach for: a shared instance is already listening
/// before the first resource is registered.
final TomShutdownCleanup tomShutdownCleanup = TomShutdownCleanup();
