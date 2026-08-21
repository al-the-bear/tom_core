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

import 'package:tom_basics/tom_basics.dart';
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
typedef TomSignalHandler = void Function(ProcessSignal onData);

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
  void dispose();
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
  void close();
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
  Object closableObject;

  late MethodMirror _mm;
  late InstanceMirror _im;

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

  /// Invokes the close/dispose method on the wrapped object.
  @override
  void close() {
    _im.invoke(_mm.simpleName, []);
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
/// Each cleanup operation is wrapped in a try-catch to ensure that a
/// failing cleanup doesn't prevent other cleanups from executing. The failure
/// is reported with its exception and the top frames of its stack — printed,
/// not logged, and suppressed by [silent].
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
/// ## Custom Signal Handlers
///
/// ```dart
/// tomShutdownCleanup.addSignalHandler((signal) {
///   print('Received signal: $signal');
///   // Perform custom cleanup
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
/// ```
class TomShutdownCleanup {
  /// Frames kept from a failing cleanup's stack trace.
  ///
  /// Bounded rather than unlimited: a shutdown can fail in several entries at
  /// once, and full traces from each would bury the failure list in the very
  /// output an operator is scanning. The frames that identify a `close()` or
  /// `dispose()` failure are the top ones.
  static const int _diagnosticStackDepth = 10;

  late TomSignalHandler _signalHandler;
  bool _executed = false;

  /// When true, signal handling is paused and signals are ignored.
  /// Use this in interactive REPLs that have their own CTRL-C handling.
  bool paused = false;

  /// When true, suppresses output messages during shutdown.
  bool silent = false;

  /// Creates a new shutdown cleanup coordinator.
  ///
  /// Automatically registers listeners for SIGHUP and SIGINT signals.
  /// The cleanup will only execute once, even if multiple signals are received.
  ///
  /// Use [tomShutdownCleanup] for the default global instance, or create
  /// custom instances for specialized signal handling.
  TomShutdownCleanup() {
    _signalHandler = (signal) =>
        performShutdown(signal: signal, fromSignal: true);
    // SIGHUP/SIGINT are registered through the same watcher-subscription path
    // as [addSignal], so there is a single place that owns how a signal is
    // watched and how its subscription is retained for teardown.
    addSignal(ProcessSignal.sighup);
    addSignal(ProcessSignal.sigint);
  }

  /// Triggers shutdown cleanup, running registered signal handlers, then
  /// closables, then disposables — exactly once across the instance's life.
  ///
  /// External code can call `performShutdown()` directly to run the cleanup
  /// without an OS signal; that manual path always runs (it ignores [paused])
  /// and stays quiet. The signal-driven path passes [fromSignal] `true`, which
  /// honours [paused] (skip while paused) and gates the status messages on
  /// [silent]. [signal] is forwarded to the registered signal handlers.
  void performShutdown({
    ProcessSignal signal = ProcessSignal.sigint,
    bool fromSignal = false,
  }) {
    // The signal path is suppressed while paused (e.g. interactive REPL mode).
    if (fromSignal && paused) return;

    if (fromSignal && !silent) print("Received $signal");
    if (_executed) {
      if (fromSignal && !silent) print("Shutdown has already been performed");
      return;
    }
    _executeCleanup(signal);
    _executed = true;
    if (fromSignal && !silent) print("Shutdown performed");
  }

  /// Runs the three cleanup phases in order — signal handlers, then closables,
  /// then disposables — isolating each callout so a failing handler never
  /// prevents the rest from running.
  void _executeCleanup(ProcessSignal signal) {
    _runPhase(_signalHandlers, "signalHandler", (handler) => handler(signal));
    _runPhase(_closables, "closable", (closable) => closable.close());
    _runPhase(_disposables, "disposable", (disposable) => disposable.dispose());
  }

  /// Runs [action] over every entry of [items], isolating each call so one
  /// failing entry never aborts the phase. On failure a `Failed to call
  /// $label $item: $exception` diagnostic is printed, followed by the top
  /// [_diagnosticStackDepth] frames, unless [silent]. This is the single owner
  /// of the per-entry try/catch/report policy shared by all three cleanup
  /// phases.
  ///
  /// The exception and its trace are part of the report because a shutdown
  /// runs once, usually unattended, and cannot be re-run to find out what went
  /// wrong: whatever this line omits is lost. Message and trace go out in a
  /// single `print` so that concurrent output cannot separate a failure from
  /// its evidence when several entries fail.
  void _runPhase<T>(List<T> items, String label, void Function(T item) action) {
    for (final item in items) {
      try {
        action(item);
      } catch (exception, stackTrace) {
        if (silent) continue;
        final trace = tomGetStackTrace(stackTrace, _diagnosticStackDepth);
        final report = "Failed to call $label $item: $exception";
        print(trace.isEmpty ? report : "$report\n$trace");
      }
    }
  }

  final List<TomSignalHandler> _signalHandlers = [];
  final List<TomClosable> _closables = [];
  final List<TomDisposable> _disposables = [];

  /// Active OS-signal watcher subscriptions, retained so they can be cancelled
  /// by [dispose]/[cancelAll] — otherwise each watcher keeps the process alive
  /// and leaks for the instance's whole life.
  final List<StreamSubscription<ProcessSignal>> _signalSubscriptions = [];

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
  /// [processSignal] - The signal to start listening for.
  ///
  /// ## Example
  ///
  /// ```dart
  /// tomShutdownCleanup.addSignal(ProcessSignal.sigterm);
  /// ```
  void addSignal(ProcessSignal processSignal) {
    _signalSubscriptions.add(processSignal.watch().listen(_signalHandler));
  }

  /// Cancels every registered OS-signal watcher subscription.
  ///
  /// After this completes the instance no longer keeps the process alive via
  /// its SIGHUP/SIGINT (and any [addSignal]-registered) watchers. Safe to call
  /// more than once; the subscription list is emptied.
  Future<void> cancelAll() async {
    for (final subscription in _signalSubscriptions) {
      await subscription.cancel();
    }
    _signalSubscriptions.clear();
  }

  /// Tears the instance down by cancelling its signal watchers (see
  /// [cancelAll]). Call this for any short-lived [TomShutdownCleanup] so its
  /// watchers stop leaking; the process-lifetime global
  /// [tomShutdownCleanup] normally never needs it.
  Future<void> dispose() => cancelAll();

  /// Emits a diagnostic log line confirming the cleanup system is in use.
  ///
  /// This method does **not** perform any initialization: the SIGHUP/SIGINT
  /// listeners are registered in the constructor, so calling — or not calling —
  /// `start()` has no effect on shutdown behaviour. It only writes an
  /// informational `tomLog` entry, which is handy as a startup breadcrumb.
  void start() {
    // The wording is deliberate: the line records that the cleanup system is
    // in use, and claims no initialization, because the call performs none.
    tomLog.info("Shutdown cleanup in use");
  }
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
/// [TomShutdownCleanup.start] is optional and is not part of this setup — it
/// writes a log breadcrumb and nothing else.
final TomShutdownCleanup tomShutdownCleanup = TomShutdownCleanup();
