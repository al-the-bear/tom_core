/// Worker Setup and Creator-Side Guards Example
///
/// This example demonstrates what the *creator* does with the worker API:
/// customizing startup on both sides of the isolate boundary, registering
/// executors in either isolate's chain, and observing a worker through its
/// lifecycle. It also covers the guards that refuse a back-channel call made
/// from the creator, where there is no creator to call.
///
/// The back-channel itself — `sendToCreator`, `executeInCreator`, and the
/// creator-side handling of both — is demonstrated from the worker side in
/// `05_creator_backchannel_example.dart`. This file stops at the guards
/// rather than repeating it.
///
/// Key concepts covered:
/// - Isolate-local setup in `TomWorkerContext.initializeIsolate`, proven by a
///   command that reads it back from inside the worker
/// - Creator-side setup in `TomWorkerContext.initializeWorker`
/// - The creator's executor registry: `addExecutor` / `removeExecutor`, and
///   why `executors` reads back as an unmodifiable view
/// - Seeding a worker's own registry with `worker.sendExecutorToIsolate()`
/// - Worker lifecycle: `isReady`, `isBusy()`, `isClosed`
/// - The guards: `canSendToCreator()`, `isMainIsolate`, and the
///   `TomWorkerException` raised when `sendToCreator` or `executeInCreator`
///   is called in the creator
///
/// This file walks one path through the API; it does not catalogue it. Pool
/// liveness supervision is demonstrated in
/// `04_worker_pool_supervision_example.dart`, and the complete member-by-member
/// surface — including the per-worker supervision primitives that no example
/// calls directly — is in `doc/api_reference/api_summary_isolate_pooling.md`.
/// That summary is the one inventory; keeping a second one here would only let
/// the two disagree.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Isolate-Local State
// ============================================================================

/// Configuration installed by [WorkerSetupContext.initializeIsolate].
///
/// A library's top-level state exists once *per isolate*, so the hook fills in
/// the worker's copy and leaves the creator's empty. That is what makes the
/// hook's effect provable: [ReadIsolateConfigCommand] reads this map from
/// inside the worker, and the creator reads its own and finds nothing.
Map<String, String> isolateConfig = {};

// ============================================================================
// Commands Run Inside the Worker
// ============================================================================

/// Reads one key out of the worker isolate's own [isolateConfig].
class ReadIsolateConfigCommand extends TomCommand {
  final String key;

  ReadIsolateConfigCommand(this.key);

  @override
  Future<Object?> execute() async => isolateConfig[key] ?? 'NOT_FOUND';
}

/// Occupies the worker long enough for [TomWorker.isBusy] to be observed.
class BusyWorkCommand extends TomCommand {
  final int steps;

  BusyWorkCommand(this.steps);

  @override
  Future<Object?> execute() async {
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: 10));
    }
    return {'completed': true, 'steps': steps};
  }
}

// ============================================================================
// Executors
// ============================================================================

/// Answers `describe` messages *inside the worker isolate*.
///
/// It gets there with [TomWorker.sendExecutorToIsolate], after which the worker
/// offers it every message that is not itself a [TomCommand] and so cannot
/// execute itself.
class WorkerSideExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is Map && command['kind'] == 'describe') {
      return 'handled in worker: ${command['what']}';
    }
    return TomExecutor.noResult;
  }
}

/// A creator-side handler, used here to show the registry mechanics.
///
/// Dispatch *into* this chain is driven by a worker calling back — see
/// `05_creator_backchannel_example.dart`; what this file shows is how an
/// entry gets into the chain and back out of it.
class CreatorSideExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is Map && command['kind'] == 'ping') {
      return 'pong';
    }
    return TomExecutor.noResult;
  }
}

// ============================================================================
// Worker Context
// ============================================================================

/// A context that customizes startup on both sides of the boundary.
class WorkerSetupContext extends TomWorkerContext {
  final Map<String, String> workerConfig;

  /// Set by [initializeWorker]. Readable from the creator because that hook
  /// runs there, against this very instance — unlike [initializeIsolate],
  /// which runs against the copy that travelled into the isolate.
  bool workerInitialized = false;

  WorkerSetupContext(this.workerConfig, {String namePrefix = 'SetupW'})
    : super(defaultTomEnvironment, platformLinux, [], namePrefix);

  @override
  Future<void> initializeIsolate() async {
    // Runs inside the new isolate, before its message loop starts. Opening
    // resources or registering services belongs here; a throw aborts the spawn
    // rather than handing back a half-configured worker.
    isolateConfig = Map.of(workerConfig);
  }

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    // Runs on the creator side, against the freshly spawned worker.
    workerInitialized = true;
  }
}

// ============================================================================
// Example Class
// ============================================================================

class WorkerSetupAndGuardsExample {
  // Captured results, asserted where they are observed.
  static bool canSendFromCreator = true; // Must end up false.
  static bool sendToCreatorRefused = false;
  static String? sendToCreatorKey;
  static bool executeInCreatorRefused = false;
  static String? executeInCreatorKey;

  static bool workerReady = false;
  static bool workerInitializedRan = false;
  static String isolateConfigInWorker = '';
  static String? isolateConfigInCreator;

  static Object? beforeSeeding;
  static Object? afterSeeding;

  static bool registryGrew = false;
  static bool viewIsReadOnly = false;
  static bool registryShrank = false;
  static bool secondRemoveReportedMiss = false;
  static bool registryRestored = false;

  static bool busyDuringCommand = false;
  static bool idleAfterCommand = false;
  static bool closedAfterClose = false;

  // --------------------------------------------------------------------------
  // Example 1: There is no back-channel in the creator
  // --------------------------------------------------------------------------
  static void example1CreatorHasNoBackChannel() {
    print('1. The back-channel as seen from the creator:');

    canSendFromCreator = TomWorker.canSendToCreator();

    print('   - canSendToCreator(): $canSendFromCreator');
    print('   - isMainIsolate:      ${TomWorker.isMainIsolate}');

    assert(!canSendFromCreator, 'The creator has no creator to send to');
    assert(TomWorker.isMainIsolate, 'This is the main isolate');
  }

  // --------------------------------------------------------------------------
  // Example 2: sendToCreator() refuses in the creator
  // --------------------------------------------------------------------------
  static void example2SendToCreatorRefuses() {
    print('\n2. sendToCreator() called in the creator:');

    try {
      TomWorker.sendToCreator({'message': 'test'});
    } on TomWorkerException catch (e) {
      sendToCreatorRefused = true;
      sendToCreatorKey = e.key;
    }

    print('   - refused: $sendToCreatorRefused');
    print('   - key:     $sendToCreatorKey');

    assert(sendToCreatorRefused, 'Sending from the creator should throw');
    assert(
      sendToCreatorKey ==
          'isolate.state_error.attempt_to_send_to_creator_in_creator',
      'The refusal should name where the call was made',
    );
  }

  // --------------------------------------------------------------------------
  // Example 3: executeInCreator() refuses in the creator
  // --------------------------------------------------------------------------
  static Future<void> example3ExecuteInCreatorRefuses() async {
    print('\n3. executeInCreator() called in the creator:');

    try {
      await TomWorker.executeInCreator({'type': 'getConfig'});
    } on TomWorkerException catch (e) {
      executeInCreatorRefused = true;
      executeInCreatorKey = e.key;
    }

    print('   - refused: $executeInCreatorRefused');
    print('   - key:     $executeInCreatorKey');

    assert(executeInCreatorRefused, 'Executing from the creator should throw');
    assert(
      executeInCreatorKey ==
          'isolate.state_error.attempt_to_execute_in_creator_in_creator',
      'The refusal should name where the call was made',
    );
  }

  // --------------------------------------------------------------------------
  // Example 4: Startup hooks on both sides of the boundary
  // --------------------------------------------------------------------------
  static Future<void> example4WorkerContextHooks() async {
    print('\n4. Startup hooks on both sides of the boundary:');

    final context = WorkerSetupContext({
      'database': 'postgres://localhost:5432/app',
      'timeout': '30',
    });

    final worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);

    workerReady = worker.isReady;
    workerInitializedRan = context.workerInitialized;

    // Only a command can see what initializeIsolate did, because it ran in the
    // worker's copy of this library's state.
    isolateConfigInWorker =
        await worker.executeCommand(ReadIsolateConfigCommand('database'))
            as String;
    isolateConfigInCreator = isolateConfig['database'];

    print('   - worker ready:                   $workerReady');
    print('   - initializeWorker ran (creator): $workerInitializedRan');
    print('   - config read inside the worker:  $isolateConfigInWorker');
    print('   - same key in the creator:        $isolateConfigInCreator');

    worker.close();

    assert(workerReady, 'spawn() should hand back a ready worker');
    assert(workerInitializedRan, 'initializeWorker runs on the creator side');
    assert(
      isolateConfigInWorker == 'postgres://localhost:5432/app',
      'initializeIsolate should have filled the worker isolate config',
    );
    assert(
      isolateConfigInCreator == null,
      'The creator has its own, still-empty copy of that state',
    );
  }

  // --------------------------------------------------------------------------
  // Example 5: Seeding a worker with its own executor
  // --------------------------------------------------------------------------
  static Future<void> example5SendExecutorToWorker() async {
    print('\n5. Seeding a worker with its own executor:');

    final worker = await TomWorker.spawn(
      TomWorker.startRemoteIsolate,
      TomWorkerContext(defaultTomEnvironment, platformLinux, [], 'ExecW'),
    );

    // `worker.name`, not `worker.isolate.debugName`: the latter is only
    // populated inside the isolate and reads `null` here.
    print('   - spawned worker: ${worker.name}');

    final message = {'kind': 'describe', 'what': 'the worker registry'};

    // A plain map is not a TomCommand, so it cannot execute itself and the
    // worker offers it to its executor chain instead. Nothing is registered
    // there yet, so the chain declines — and the worker answers with the
    // sentinel rather than leaving this await pending forever.
    beforeSeeding = await worker.executeCommand(message);

    worker.sendExecutorToIsolate(WorkerSideExecutor());

    // The registration is one-way and unacknowledged; what makes the next
    // command see it is ordering. Both travel the same port, and the isolate
    // processes them in the order they were sent.
    afterSeeding = await worker.executeCommand(message);

    final beforeLabel = identical(beforeSeeding, TomExecutor.noResult)
        ? 'TomExecutor.noResult'
        : '$beforeSeeding';
    print('   - before sendExecutorToIsolate: $beforeLabel');
    print('   - after  sendExecutorToIsolate: $afterSeeding');

    worker.close();

    assert(
      identical(beforeSeeding, TomExecutor.noResult),
      'An unclaimed message is answered with the sentinel, not with silence',
    );
    assert(
      afterSeeding == 'handled in worker: the worker registry',
      'The executor sent across should claim the message',
    );
  }

  // --------------------------------------------------------------------------
  // Example 6: The creator-side executor registry
  // --------------------------------------------------------------------------
  static void example6ExecutorRegistry() {
    print('\n6. The creator-side executor registry:');

    final initialCount = TomWorker.executors.length;
    final executor = CreatorSideExecutor();

    TomWorker.addExecutor(executor);
    registryGrew = TomWorker.executors.length == initialCount + 1;

    // `executors` is an unmodifiable view over the very list dispatch reads,
    // so it refuses a registration attempted through it. Were it a copy the
    // call would appear to work and the executor would simply never be
    // consulted — a failure that surfaces far from its cause.
    try {
      TomWorker.executors.add(CreatorSideExecutor());
      viewIsReadOnly = false;
    } on UnsupportedError {
      viewIsReadOnly = true;
    }

    registryShrank = TomWorker.removeExecutor(executor);
    secondRemoveReportedMiss = !TomWorker.removeExecutor(executor);
    registryRestored = TomWorker.executors.length == initialCount;

    print('   - addExecutor grew the chain:      $registryGrew');
    print('   - executors view refuses add():    $viewIsReadOnly');
    print('   - removeExecutor reported removal: $registryShrank');
    print('   - removing again reported a miss:  $secondRemoveReportedMiss');
    print('   - chain left as it was found:      $registryRestored');

    assert(registryGrew, 'addExecutor should append to the chain');
    assert(viewIsReadOnly, 'executors should be an unmodifiable view');
    assert(registryShrank, 'removeExecutor should report the removal');
    assert(secondRemoveReportedMiss, 'A second remove should report a miss');
    assert(registryRestored, 'The example should leave the registry as found');
  }

  // --------------------------------------------------------------------------
  // Example 7: Worker lifecycle
  // --------------------------------------------------------------------------
  static Future<void> example7WorkerLifecycle() async {
    print('\n7. Worker lifecycle:');

    final worker = await TomWorker.spawn(
      TomWorker.startRemoteIsolate,
      TomWorkerContext(defaultTomEnvironment, platformLinux, [], 'LifeW'),
    );

    print('   - isReady:  ${worker.isReady}');
    print('   - isClosed: ${worker.isClosed}');
    print('   - isBusy() before the command: ${worker.isBusy()}');

    // Not awaited: executeCommand registers the request before its first
    // suspension, so the worker reads as busy from the moment it is called.
    final pending = worker.executeCommand(BusyWorkCommand(5));
    busyDuringCommand = worker.isBusy();
    print('   - isBusy() during the command: $busyDuringCommand');

    await pending;
    idleAfterCommand = !worker.isBusy();
    print('   - isBusy() after the command:  ${worker.isBusy()}');

    worker.close();
    closedAfterClose = worker.isClosed;
    print('   - isClosed after close(): $closedAfterClose');

    assert(busyDuringCommand, 'A dispatched command should make it busy');
    assert(idleAfterCommand, 'The answer should clear the request');
    assert(closedAfterClose, 'close() should mark the worker closed');
  }
}

// ============================================================================
// Run Function
// ============================================================================

Future<void> run() async {
  print('═══════════════════════════════════════════════════════════════════');
  print('WORKER SETUP AND CREATOR-SIDE GUARDS EXAMPLE');
  print(
    '═══════════════════════════════════════════════════════════════════\n',
  );

  WorkerSetupAndGuardsExample.example1CreatorHasNoBackChannel();
  WorkerSetupAndGuardsExample.example2SendToCreatorRefuses();
  await WorkerSetupAndGuardsExample.example3ExecuteInCreatorRefuses();
  await WorkerSetupAndGuardsExample.example4WorkerContextHooks();
  await WorkerSetupAndGuardsExample.example5SendExecutorToWorker();
  WorkerSetupAndGuardsExample.example6ExecutorRegistry();
  await WorkerSetupAndGuardsExample.example7WorkerLifecycle();

  print('\n✓ All worker setup and guard examples passed!\n');
}

/// Standalone entry point.
Future<void> main() async => run();
