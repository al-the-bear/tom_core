/// Creator Back-Channel Example
///
/// This example demonstrates the worker→creator back-channel: the mechanism
/// that lets code running inside a worker isolate call back into the main
/// (creator) isolate. It also shows how to customize worker startup with a
/// [TomWorkerContext] subclass and how command failures propagate back to the
/// caller.
///
/// Key concepts covered:
/// - Detecting the back-channel with TomWorker.canSendToCreator()
/// - Request/response into the creator with TomWorker.executeInCreator()
/// - Fire-and-forget messages with TomWorker.sendToCreator()
/// - Handling creator-side messages with a TomExecutor
/// - Customizing startup via TomWorkerContext.initializeIsolate/initializeWorker
/// - Error propagation: a command that throws surfaces as a RemoteError
library;

import 'dart:isolate' show RemoteError;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Custom Worker Context
// ============================================================================

/// A worker context that records which initialization hooks ran.
///
/// [initializeIsolate] runs *inside* the new isolate before its message loop
/// starts; [initializeWorker] runs on the creator side against the freshly
/// created [TomWorker]. The two run in different isolates, so the isolate-side
/// flag is never observable from the creator — it is asserted indirectly via a
/// probe command below.
class BackchannelWorkerContext extends TomWorkerContext {
  bool workerInitialized = false;

  BackchannelWorkerContext()
      : super(defaultTomEnvironment, platformLinux, [], 'Backchannel');

  @override
  Future<bool> initializeIsolate() async {
    // Isolate-local setup would go here (open resources, register services).
    return true;
  }

  @override
  Future<bool> initializeWorker(TomWorker worker) async {
    workerInitialized = true;
    return true;
  }
}

// ============================================================================
// Commands Run Inside the Worker
// ============================================================================

/// Returns whether the back-channel is available from inside the worker.
///
/// Runs in the worker isolate, so [TomWorker.canSendToCreator] must be `true`.
class CanSendToCreatorProbe extends TomCommand {
  @override
  Future<Object?> execute() async => TomWorker.canSendToCreator();
}

/// Delegates a computation back to the creator and returns its answer.
///
/// The worker calls [TomWorker.executeInCreator] with a [CreatorSideSum]; the
/// creator runs that command and the result round-trips back through the worker
/// to the original caller.
class DelegateSumToCreator extends TomCommand {
  final int a;
  final int b;

  DelegateSumToCreator(this.a, this.b);

  @override
  Future<Object?> execute() async {
    return await TomWorker.executeInCreator(CreatorSideSum(a, b));
  }
}

/// A command executed on the CREATOR side via the back-channel.
class CreatorSideSum extends TomCommand {
  final int a;
  final int b;

  CreatorSideSum(this.a, this.b);

  @override
  Future<Object?> execute() async => a + b;
}

/// Sends a fire-and-forget notification to the creator, then returns.
///
/// The notification is handled by a creator-side [TomExecutor] rather than a
/// command, so there is no response to await — [TomWorker.sendToCreator] is
/// one-way.
class NotifyCreatorCommand extends TomCommand {
  final String payload;

  NotifyCreatorCommand(this.payload);

  @override
  Future<Object?> execute() async {
    TomWorker.sendToCreator({'kind': 'notify', 'payload': payload});
    return 'sent';
  }
}

/// A command that throws, to demonstrate error propagation.
class WorkerThrowingCommand extends TomCommand {
  @override
  Future<Object?> execute() async {
    throw Exception('deliberate worker failure');
  }
}

// ============================================================================
// Creator-Side Executor
// ============================================================================

/// Records fire-and-forget notifications received from workers.
///
/// Registered on the creator via `TomWorker.executors.add(...)`, it is invoked
/// when a worker sends a plain object (not a [TomCommand]) through the
/// back-channel.
class CreatorInboxExecutor extends TomExecutor {
  final List<Object> received = [];

  @override
  Object execute(Object command) {
    if (command is Map && command['kind'] == 'notify') {
      received.add(command['payload'] as Object);
      return 'ack';
    }
    return TomExecutor.noResult;
  }
}

// ============================================================================
// Example Code
// ============================================================================

Future<void> run() async {
  print('=== 03: Creator Back-Channel Example ===\n');

  // Register a creator-side inbox for fire-and-forget notifications.
  final inbox = CreatorInboxExecutor();
  TomWorker.executors.add(inbox);

  // -------------------------------------------------------------------------
  // Example 1: The back-channel is only available inside workers
  // -------------------------------------------------------------------------
  print('1. Back-channel availability:');

  final canSendFromCreator = TomWorker.canSendToCreator();

  final context = BackchannelWorkerContext();
  final worker = await TomWorker.spawn(
    TomWorker.startRemoteIsolate,
    context,
  );

  final canSendFromWorker =
      await worker.executeCommand(CanSendToCreatorProbe()) as bool;

  print('   canSendToCreator() in creator: $canSendFromCreator');
  print('   canSendToCreator() in worker:  $canSendFromWorker');
  print('   initializeWorker ran: ${context.workerInitialized}\n');

  // -------------------------------------------------------------------------
  // Example 2: Request/response into the creator (executeInCreator)
  // -------------------------------------------------------------------------
  print('2. Delegating a computation back to the creator:');

  final delegated =
      await worker.executeCommand(DelegateSumToCreator(7, 8)) as int;

  print('   worker asked creator for 7 + 8 = $delegated\n');

  // -------------------------------------------------------------------------
  // Example 3: Fire-and-forget notification (sendToCreator)
  // -------------------------------------------------------------------------
  print('3. Fire-and-forget notification to the creator:');

  final sendAck =
      await worker.executeCommand(NotifyCreatorCommand('worker-online'));

  // sendToCreator is one-way; give the creator a moment to process the message.
  await Future.delayed(Duration(milliseconds: 20));

  print('   command returned: $sendAck');
  print('   creator inbox received: ${inbox.received}\n');

  // -------------------------------------------------------------------------
  // Example 4: Error propagation
  // -------------------------------------------------------------------------
  print('4. A throwing command surfaces as a RemoteError:');

  Object? caught;
  try {
    await worker.executeCommand(WorkerThrowingCommand());
  } catch (e) {
    caught = e;
  }

  print('   caught: ${caught.runtimeType}\n');

  // -------------------------------------------------------------------------
  // Cleanup
  // -------------------------------------------------------------------------
  worker.close();
  TomWorker.executors.clear();

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: back-channel only exists inside workers.
  assert(canSendFromCreator == false);
  assert(canSendFromWorker == true);
  assert(context.workerInitialized == true);

  // Example 2: executeInCreator round-trip.
  assert(delegated == 15);

  // Example 3: sendToCreator delivered to the creator-side executor.
  assert(sendAck == 'sent');
  assert(inbox.received.length == 1);
  assert(inbox.received.first == 'worker-online');

  // Example 4: thrown command becomes a RemoteError on the future.
  assert(caught is RemoteError);
}
