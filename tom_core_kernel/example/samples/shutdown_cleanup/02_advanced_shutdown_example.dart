/// Example: adapting a class that has no Tom interface, with TomCloseAdaptor
///
/// [TomShutdownCleanup] closes [TomClosable]s and disposes [TomDisposable]s.
/// [TomCloseAdaptor] is how an object that implements neither still gets torn
/// down: it resolves the object's teardown method through the global
/// `tomReflector` and presents the result as a [TomClosable].
///
/// This example covers the whole of that contract:
/// - resolution — `close()` and `dispose()` are found without being named, and
///   any other method is reached by naming it
/// - the three ways construction fails — no teardown method, a method that
///   takes a parameter, and a class the reflector cannot see
/// - registration — an adaptor is a [TomClosable], so it goes on a cleanup like
///   any other and is closed by the shutdown
///
/// The reflector requirement is the part most likely to bite, and example 6
/// exists to make it concrete: the adaptor reaches classes in *your own* build
/// that carry `@tomReflector`. A type from a package you cannot annotate is out
/// of reach no matter what methods it declares — wrap it in a small
/// [TomClosable] of your own instead, which needs no reflection at all.
///
/// `01_shutdown_handler_example.dart` owns registration in general and
/// `03_shutdown_execution_example.dart` owns the execution semantics — phase
/// order, once-only execution, fault isolation, `paused`, `silent`.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/shutdown_cleanup/02_advanced_shutdown_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// =============================================================================
// Example Support Classes
// =============================================================================

/// A class of our own with a `close()` but no `TomClosable` implementation.
///
/// Note the `@tomReflector`. Every adaptor target below carries it, and that
/// is not incidental: `TomCloseAdaptor` resolves the teardown method through
/// the global reflector, so it only ever reaches classes in your own build. A
/// genuinely third-party class cannot be annotated and so cannot be adapted —
/// wrap one in a small `TomClosable` of your own instead.
@tomReflector
class AnnotatedDatabase {
  AnnotatedDatabase(this.connectionString);

  final String connectionString;
  bool _isClosed = false;

  bool get isClosed => _isClosed;

  // Has close() but doesn't implement TomClosable.
  void close() => _isClosed = true;
}

/// A class of our own with a `dispose()` but no `TomDisposable` implementation.
@tomReflector
class AnnotatedStream {
  AnnotatedStream(this.streamName);

  final String streamName;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  // Has dispose() but doesn't implement TomDisposable.
  void dispose() => _isDisposed = true;
}

/// A class whose teardown method is named neither `close` nor `dispose`.
@tomReflector
class CustomShutdownResource {
  CustomShutdownResource(this.resourceId);

  final String resourceId;
  bool _isShutdown = false;

  bool get isShutdown => _isShutdown;

  void shutdown() => _isShutdown = true;
}

/// A class with no teardown method at all.
@tomReflector
class NoCloseMethod {
  void doSomething() {}
}

/// A class whose `close()` needs an argument the adaptor has no way to supply.
@tomReflector
class ParameterizedClose {
  void close(String reason) {}
}

/// A class the reflector cannot see, standing in for a third-party type.
///
/// Deliberately *not* annotated: it has a perfectly good `close()`, which is
/// the point — the adaptor's requirement is reflectability, not the shape of
/// the method, and no amount of the latter substitutes for the former.
class UnreachableCache {
  bool isClosed = false;

  void close() => isClosed = true;
}

// =============================================================================
// Main Example Function
// =============================================================================

/// Runs the adaptor demonstrations.
///
/// [TomCloseAdaptor] resolves teardown methods through the global reflector, so
/// the reflected targets above must be registered before [run] is called. Both
/// entry points do that: the group runner (`00_run_all_examples.dart`) and this
/// file's own `main()` each call `bootstrapSamples()` first.
Future<void> run() async {
  print('=== 02: Advanced Shutdown Cleanup Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: close() is found without being named
  // ---------------------------------------------------------------------------
  print('1. TomCloseAdaptor wrapping close():');

  final database = AnnotatedDatabase('postgres://localhost:5432');
  final databaseAdaptor = TomCloseAdaptor(database);

  final databaseClosedBefore = database.isClosed;
  // The adaptor *is* a TomClosable — that is the whole conversion.
  final TomClosable asClosable = databaseAdaptor;
  await asClosable.close();
  final databaseClosedAfter = database.isClosed;

  print('   - ${database.connectionString}');
  print('   - isClosed before: $databaseClosedBefore');
  print('   - isClosed after:  $databaseClosedAfter\n');

  // ---------------------------------------------------------------------------
  // Example 2: dispose() is found when there is no close()
  // ---------------------------------------------------------------------------
  print('2. TomCloseAdaptor wrapping dispose():');

  final stream = AnnotatedStream('events-stream');
  final streamAdaptor = TomCloseAdaptor(stream);

  final streamDisposedBefore = stream.isDisposed;
  // Still `close()` on the adaptor — the adaptor's own name for teardown does
  // not change with the target's.
  await streamAdaptor.close();
  final streamDisposedAfter = stream.isDisposed;

  print('   - ${stream.streamName}');
  print('   - isDisposed before: $streamDisposedBefore');
  print('   - isDisposed after:  $streamDisposedAfter\n');

  // ---------------------------------------------------------------------------
  // Example 3: any other method, named explicitly
  // ---------------------------------------------------------------------------
  print('3. TomCloseAdaptor with a custom method name:');

  final resource = CustomShutdownResource('resource-123');
  final resourceAdaptor = TomCloseAdaptor(resource, 'shutdown');

  final resourceShutdownBefore = resource.isShutdown;
  await resourceAdaptor.close();
  final resourceShutdownAfter = resource.isShutdown;

  print('   - ${resource.resourceId}');
  print('   - isShutdown before: $resourceShutdownBefore');
  print('   - isShutdown after:  $resourceShutdownAfter\n');

  // ---------------------------------------------------------------------------
  // Example 4: no teardown method
  // ---------------------------------------------------------------------------
  // The three failures below all happen in the *constructor*. The adaptor
  // resolves the method up front rather than at close() time, so a target it
  // cannot tear down is rejected while there is still a caller to tell —
  // not during a shutdown, where the diagnostic scrolls past unread.
  print('4. Construction fails when there is no teardown method:');

  TomCloseAdaptorException? noMethodFailure;
  try {
    TomCloseAdaptor(NoCloseMethod());
  } on TomCloseAdaptorException catch (e) {
    noMethodFailure = e;
  }

  print('   - key: ${noMethodFailure?.key}');
  print('   - ${noMethodFailure?.defaultUserMessage}\n');

  // ---------------------------------------------------------------------------
  // Example 5: a teardown method that takes an argument
  // ---------------------------------------------------------------------------
  print('5. Construction fails when the method needs an argument:');

  TomCloseAdaptorException? parameterFailure;
  try {
    TomCloseAdaptor(ParameterizedClose());
  } on TomCloseAdaptorException catch (e) {
    parameterFailure = e;
  }

  print('   - key: ${parameterFailure?.key}');
  print('   - parameters: ${parameterFailure?.parameters}\n');

  // ---------------------------------------------------------------------------
  // Example 6: a class the reflector cannot see
  // ---------------------------------------------------------------------------
  print('6. Construction fails when the class is not reflectable:');

  TomReflectorException? notReflectableFailure;
  try {
    TomCloseAdaptor(UnreachableCache());
  } on TomReflectorException catch (e) {
    notReflectableFailure = e;
  }

  print('   - key: ${notReflectableFailure?.key}\n');

  // ---------------------------------------------------------------------------
  // Example 7: adaptors registered on a cleanup
  // ---------------------------------------------------------------------------
  print('7. Registering adaptors and running the shutdown:');

  final primary = AnnotatedDatabase('mysql://localhost');
  final replica = AnnotatedDatabase('postgres://localhost');
  final auditLog = AnnotatedStream('audit-log');

  final cleanup = TomShutdownCleanup();
  cleanup.addClosable(TomCloseAdaptor(primary));
  cleanup.addClosable(TomCloseAdaptor(replica));
  cleanup.addClosable(TomCloseAdaptor(auditLog));

  await cleanup.performShutdown();

  print('   - ${primary.connectionString} closed: ${primary.isClosed}');
  print('   - ${replica.connectionString} closed: ${replica.isClosed}');
  print('   - ${auditLog.streamName} disposed: ${auditLog.isDisposed}\n');

  // ---------------------------------------------------------------------------
  // Teardown for the instance example 7 created
  // ---------------------------------------------------------------------------
  // Running a cleanup is not the same as disposing it: `performShutdown()`
  // executes the registrations but leaves the SIGHUP/SIGINT watchers the
  // constructor started, and an active watcher keeps the process alive.
  await cleanup.dispose();

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: the adaptor invokes the target's close(), and says which object
  // it will close.
  assert(!databaseClosedBefore, 'Building an adaptor must not close anything');
  assert(databaseClosedAfter, 'The adaptor must invoke the target close()');
  assert(
    identical(databaseAdaptor.closableObject, database),
    'closableObject names the object the adaptor will actually close',
  );

  // Example 2: dispose() is reached under the adaptor's close().
  assert(
    !streamDisposedBefore,
    'Building an adaptor must not dispose anything',
  );
  assert(streamDisposedAfter, 'The adaptor must invoke the target dispose()');

  // Example 3: an explicitly named method wins over the defaults, which this
  // target does not have at all.
  assert(!resourceShutdownBefore, 'Building an adaptor must not tear down');
  assert(resourceShutdownAfter, 'The adaptor must invoke the named method');

  // Example 4: rejected with its own key, naming the target type.
  assert(
    noMethodFailure?.key == 'shutdown_cleanup.close_adaptor.no_close_method',
    'A target with no teardown method must be rejected with its key',
  );
  assert(
    noMethodFailure?.parameters?['type'] == 'NoCloseMethod',
    'The failure must carry the target type',
  );

  // Example 5: rejected too — a required parameter the adaptor cannot supply
  // is as fatal as no method at all, and carries a key of its own so the
  // caller can tell the two apart without reading the message.
  assert(
    parameterFailure?.key ==
        'shutdown_cleanup.close_adaptor.method_requires_parameters',
    'A teardown method with a required parameter must be rejected',
  );
  assert(
    parameterFailure?.parameters?['method'] == 'close',
    'The failure must name the method',
  );

  // Example 6: reported as a TomReflectorException carrying the module's key,
  // rather than as the bare NoSuchCapabilityError the reflector would throw —
  // an Error, which `on Exception` would not have caught.
  assert(
    notReflectableFailure != null,
    'An unannotated target must be rejected, however good its close()',
  );
  assert(
    notReflectableFailure?.key ==
        'shutdown_cleanup.close_adaptor.not_reflectable',
    'The failure must carry the documented error key, got '
    '${notReflectableFailure?.key}',
  );

  // Example 7: one shutdown tore down all three targets, through adaptors that
  // resolved two different method names.
  assert(primary.isClosed, 'The shutdown must close the first database');
  assert(replica.isClosed, 'The shutdown must close the second database');
  assert(auditLog.isDisposed, 'The shutdown must dispose the stream');

  print('✓ All advanced shutdown cleanup examples passed!\n');
}

/// Standalone entry point.
Future<void> main() async {
  bootstrapSamples();
  await run();
}
