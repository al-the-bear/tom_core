/// Worker-to-Creator Communication Example
///
/// This example demonstrates bidirectional communication between
/// worker isolates and the creator (main) isolate:
/// - Worker calling back to creator with sendToCreator()
/// - Worker executing commands in creator with executeInCreator()
/// - Custom context initialization with initializeIsolate/initializeWorker
/// - TomWorkerException handling
/// - Checking communication availability
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Command and Executor Definitions
// ============================================================================

/// Command executed in the worker isolate that needs creator data.
class FetchConfigCommand extends TomCommand {
  final String configKey;

  FetchConfigCommand(this.configKey);

  @override
  Future<Object?> execute() async {
    // Worker needs configuration from creator
    // This would use executeInCreator() in real scenario
    print('     Worker: Received request for config key "$configKey"');

    // Simulate getting config
    final config = {
      'database': 'postgres://localhost:5432/app',
      'apiKey': 'secret-key-123',
      'timeout': 30,
    };
    return config[configKey] ?? 'NOT_FOUND';
  }
}

/// A command that simulates work in the worker and reports progress.
class ProgressReportingCommand extends TomCommand {
  final int totalSteps;

  ProgressReportingCommand(this.totalSteps);

  @override
  Future<Object?> execute() async {
    print('     Worker: Starting task with $totalSteps steps');

    // In real scenario, would call sendToCreator() to report progress
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(Duration(milliseconds: 10));
      // TomWorker.sendToCreator({'progress': i, 'total': totalSteps});
    }

    print('     Worker: Task completed');
    return {'completed': true, 'steps': totalSteps};
  }
}

/// Executor to handle commands from worker in the creator isolate.
class CreatorSideExecutor extends TomExecutor {
  final Map<String, String> configStore = {
    'setting1': 'value1',
    'setting2': 'value2',
    'apiUrl': 'https://api.example.com',
  };

  @override
  Object execute(Object command) {
    if (command is Map && command['type'] == 'getConfig') {
      final key = command['key'] as String;
      return configStore[key] ?? 'NOT_FOUND';
    }
    if (command is Map && command['type'] == 'getTimestamp') {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return TomExecutor.noResult;
  }
}

/// Custom worker context with initialization hooks.
class CustomWorkerContext extends TomWorkerContext {
  final Map<String, dynamic> workerConfig;

  CustomWorkerContext({
    required TomEnvironment environment,
    required TomPlatform platform,
    required this.workerConfig,
    String namePrefix = 'Custom',
  }) : super(environment, platform, [], namePrefix);

  @override
  Future<void> initializeIsolate() async {
    // This runs in the new isolate, in static context
    // Set up isolate-level resources here
    print('     [Isolate] initializeIsolate called');
    print('     [Isolate] Setting up isolate resources...');

    // Could register beans, set up logging, etc. Throwing from here aborts
    // the spawn — see example 07 for what the caller sees.
  }

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    // This runs on the TomWorker instance after spawn
    print('     [Creator] initializeWorker called');
    print('     [Creator] Configuring worker with config: $workerConfig');

    // Register executors for handling worker callbacks
    TomWorker.executors.add(CreatorSideExecutor());
  }
}

// ============================================================================
// Example Class
// ============================================================================

class WorkerCreatorCommunicationExample {
  // Captured results
  static bool canSendToCreatorInMain = true; // Should be false in main
  static bool contextInitWorks = false;
  static bool customContextWorks = false;
  static bool exceptionCaught = false;
  static String? exceptionKey;

  // --------------------------------------------------------------------------
  // Example 1: Checking communication availability
  // --------------------------------------------------------------------------
  static void example1CheckCommunicationAvailability() {
    print('1. Checking communication availability:');

    // In main isolate, canSendToCreator should be false
    canSendToCreatorInMain = TomWorker.canSendToCreator();
    print('   - TomWorker.canSendToCreator() in main: $canSendToCreatorInMain');
    print('   - TomWorker.isMainIsolate: ${TomWorker.isMainIsolate}');

    print('');
    print('   In a worker isolate:');
    print('   - canSendToCreator() returns true');
    print('   - isMainIsolate is set to false');

    // Assertion
    assert(!canSendToCreatorInMain, 'Should not be able to send from main');
    assert(TomWorker.isMainIsolate, 'Should be main isolate');
  }

  // --------------------------------------------------------------------------
  // Example 2: TomWorkerException when sending from main
  // --------------------------------------------------------------------------
  static void example2SendFromMainException() {
    print('\n2. TomWorkerException when sending from main isolate:');

    try {
      TomWorker.sendToCreator({'message': 'test'});
      exceptionCaught = false;
    } on TomWorkerException catch (e) {
      exceptionCaught = true;
      exceptionKey = e.key;
      print('   - Caught TomWorkerException as expected');
      print('   - Key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage.substring(0, 50)}...');
    }

    // Assertion
    assert(exceptionCaught, 'Should throw when sending from main');
    assert(
      exceptionKey == 'isolate.state_error.attempt_to_send_to_creator_in_creator',
      'Should have correct error key',
    );
  }

  // --------------------------------------------------------------------------
  // Example 3: TomWorkerException when executing in creator from main
  // --------------------------------------------------------------------------
  static Future<void> example3ExecuteInCreatorException() async {
    print('\n3. TomWorkerException when calling executeInCreator from main:');

    try {
      await TomWorker.executeInCreator({'type': 'getConfig'});
      print('   - ERROR: Should have thrown exception');
    } on TomWorkerException catch (e) {
      print('   - Caught TomWorkerException as expected');
      print('   - Key: ${e.key}');
      assert(
        e.key == 'isolate.state_error.attempt_to_execute_in_creator_in_creator',
        'Should have correct error key',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Example 4: Custom TomWorkerContext with initialization
  // --------------------------------------------------------------------------
  static Future<void> example4CustomWorkerContext() async {
    print('\n4. Custom TomWorkerContext with initialization hooks:');

    final customContext = CustomWorkerContext(
      environment: defaultTomEnvironment,
      platform: platformLinux,
      workerConfig: {'maxRetries': 3, 'timeout': 5000},
      namePrefix: 'CustomW',
    );

    print('   - Created CustomWorkerContext');
    print('   - workerConfig: ${customContext.workerConfig}');

    // Spawn worker (this will trigger initialization hooks)
    print('   - Spawning worker...');
    final worker = await TomWorker.spawn(
      TomWorker.startRemoteIsolate,
      customContext,
    );

    customContextWorks = worker.isReady;
    print('   - Worker ready: ${worker.isReady}');

    // Execute a command
    final result = await worker.executeCommand(FetchConfigCommand('database'));
    print('   - Executed FetchConfigCommand, result: $result');

    // Clean up
    worker.close();
    print('   - Worker closed');

    // Assertion
    assert(customContextWorks, 'Custom context should work');
  }

  // --------------------------------------------------------------------------
  // Example 5: Understanding the communication pattern
  // --------------------------------------------------------------------------
  static void example5CommunicationPattern() {
    print('\n5. Worker-to-Creator communication pattern:');

    print('''
   ┌───────────────────┐         ┌───────────────────┐
   │   Main Isolate    │◄───────►│  Worker Isolate   │
   │    (Creator)      │         │    (TomWorker)    │
   │                   │         │                   │
   │ TomWorker.        │ sendTo  │ TomWorker.        │
   │   executors[]  ◄──│─Creator─│   sendToCreator() │
   │                   │         │                   │
   │                   │execute  │ TomWorker.        │
   │ process & reply ◄─│─InCre─ ─│  executeInCreator │
   └───────────────────┘ ator()  └───────────────────┘
   
   sendToCreator():
   - Fire-and-forget message to creator
   - Creator's executors process the message
   - No response expected
   
   executeInCreator():
   - Request-response pattern
   - Worker waits for creator's response
   - Useful for getting shared state/config
''');
  }

  // --------------------------------------------------------------------------
  // Example 6: Registering executors on creator side
  // --------------------------------------------------------------------------
  static void example6RegisteringExecutors() {
    print('6. Registering executors on creator side:');

    // Executors handle messages from worker
    final executor = CreatorSideExecutor();
    TomWorker.executors.add(executor);
    print('   - Added CreatorSideExecutor to TomWorker.executors');
    print('   - Executor count: ${TomWorker.executors.length}');

    print('');
    print('   When worker calls sendToCreator() or executeInCreator():');
    print('   1. Message arrives at creator isolate');
    print('   2. Each executor.execute() is called in order');
    print('   3. First executor returning non-noResult handles it');
    print('   4. For executeInCreator, result is sent back to worker');

    // Clean up
    TomWorker.executors.remove(executor);
    print('   - Removed executor');
  }

  // --------------------------------------------------------------------------
  // Example 7: Sending executors to worker isolate
  // --------------------------------------------------------------------------
  static Future<void> example7SendExecutorToWorker() async {
    print('\n7. Sending executors to worker isolate:');

    final context = TomWorkerContext(
      defaultTomEnvironment,
      platformLinux,
      [],
      'ExecW',
    );

    final worker = await TomWorker.spawn(
      TomWorker.startRemoteIsolate,
      context,
    );

    print('   - Spawned worker: ${worker.isolate.debugName}');

    // Send executor to worker (not command)
    // Note: The executor class must be sendable across isolates
    print('   - worker.sendExecutorToIsolate(executor)');
    print('     Sends executor to worker for handling future commands');

    // Clean up
    worker.close();
  }

  // --------------------------------------------------------------------------
  // Example 8: Worker lifecycle and isBusy check
  // --------------------------------------------------------------------------
  static Future<void> example8WorkerLifecycle() async {
    print('\n8. Worker lifecycle and busy checking:');

    final context = TomWorkerContext(
      defaultTomEnvironment,
      platformLinux,
      [],
      'LifeW',
    );

    final worker = await TomWorker.spawn(
      TomWorker.startRemoteIsolate,
      context,
    );

    print('   - isReady: ${worker.isReady}');
    print('   - isClosed: ${worker.isClosed}');
    print('   - isBusy() before command: ${worker.isBusy()}');

    // Start a command (don't await)
    final future = worker.executeCommand(ProgressReportingCommand(5));
    print('   - Started command (not awaited)');

    // Check busy state
    print('   - isBusy() during command: ${worker.isBusy()}');

    // Wait for completion
    await future;
    print('   - Command completed');
    print('   - isBusy() after command: ${worker.isBusy()}');

    // Close worker
    worker.close();
    print('   - isClosed after close(): ${worker.isClosed}');

    // Assertions
    assert(worker.isClosed, 'Worker should be closed');
  }

  // --------------------------------------------------------------------------
  // Example 9: Understanding TomCommand vs TomExecutor
  // --------------------------------------------------------------------------
  static void example9CommandVsExecutor() {
    print('\n9. TomCommand vs TomExecutor:');

    print('''
   TomCommand:
   ├─ Extends TomCommand abstract class
   ├─ Encapsulates data AND behavior together
   ├─ execute() method runs in worker isolate
   ├─ Self-contained - command knows how to execute itself
   └─ Use when: Logic is specific to the command
   
   TomExecutor:
   ├─ Extends TomExecutor abstract class
   ├─ Registered handler that processes commands
   ├─ execute() receives any Object as command
   ├─ Return TomExecutor.noResult to pass to next executor
   └─ Use when: Multiple command types share handling logic
   
   Both can be used in:
   - Worker isolate (processing incoming commands)
   - Creator isolate (handling worker callbacks)
''');
  }

  // --------------------------------------------------------------------------
  // Example 10: Static vs instance context
  // --------------------------------------------------------------------------
  static void example10StaticVsInstance() {
    print('10. Static vs instance context in TomWorker:');

    print('''
   TomWorker has both static and instance members:
   
   STATIC (shared across isolates):
   ├─ TomWorker.executors - List of executors
   ├─ TomWorker.isMainIsolate - bool indicating isolate type
   ├─ TomWorker.canSendToCreator() - Check backchannel
   ├─ TomWorker.sendToCreator(obj) - Fire-and-forget to creator
   ├─ TomWorker.executeInCreator(cmd) - Request-response to creator
   └─ TomWorker.workerCount - Counter for worker names
   
   INSTANCE (per-worker):
   ├─ worker.isReady - Worker initialization complete
   ├─ worker.isClosed - Worker has been shut down
   ├─ worker.isBusy() - Has pending requests
   ├─ worker.isolate - The underlying Isolate
   ├─ worker.executeCommand(cmd) - Send command to worker
   ├─ worker.sendExecutorToIsolate(exec) - Add executor to worker
   └─ worker.close() - Shutdown worker
''');
  }
}

// ============================================================================
// Run Function
// ============================================================================

Future<void> run() async {
  print('═══════════════════════════════════════════════════════════════════');
  print('WORKER-TO-CREATOR COMMUNICATION EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  WorkerCreatorCommunicationExample.example1CheckCommunicationAvailability();
  WorkerCreatorCommunicationExample.example2SendFromMainException();
  await WorkerCreatorCommunicationExample.example3ExecuteInCreatorException();
  await WorkerCreatorCommunicationExample.example4CustomWorkerContext();
  WorkerCreatorCommunicationExample.example5CommunicationPattern();
  WorkerCreatorCommunicationExample.example6RegisteringExecutors();
  await WorkerCreatorCommunicationExample.example7SendExecutorToWorker();
  await WorkerCreatorCommunicationExample.example8WorkerLifecycle();
  WorkerCreatorCommunicationExample.example9CommandVsExecutor();
  WorkerCreatorCommunicationExample.example10StaticVsInstance();

  // Final assertions
  assert(!WorkerCreatorCommunicationExample.canSendToCreatorInMain,
      'Cannot send from main');
  assert(WorkerCreatorCommunicationExample.exceptionCaught,
      'Exception should be caught');
  assert(WorkerCreatorCommunicationExample.customContextWorks,
      'Custom context should work');

  print('\n✓ All worker-to-creator communication examples passed!\n');
}
