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
/// - Customizing startup via TomWorkerContext.initializeWorker
/// - Error propagation: a command that throws rethrows on the caller's side,
///   as the same exception type, in both directions
/// - Recognizing TomExecutor.noResult, the answer a creator gives when nothing
///   on its side claimed the message
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Custom Worker Context
// ============================================================================

/// A worker context that records that its creator-side hook ran.
///
/// [initializeWorker] runs on the creator side against the freshly created
/// [TomWorker], so setting a field here is visible below. [initializeIsolate]
/// runs *inside* the new isolate and could not report back the same way; what
/// it can do, and how to prove it did it, is shown in
/// `03_worker_setup_and_guards_example.dart`.
class BackchannelWorkerContext extends TomWorkerContext {
  bool workerInitialized = false;

  BackchannelWorkerContext()
    : super(defaultTomEnvironment, platformLinux, [], 'Backchannel');

  @override
  Future<void> initializeIsolate() async {
    // Isolate-local setup would go here (open resources, register services).
  }

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    workerInitialized = true;
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

/// Delegates a payload to the creator that no creator-side executor claims.
///
/// The payload is a plain `String` rather than a [TomCommand], so the creator
/// offers it to its executor chain — and the only executor registered here
/// answers `notify` maps, so it declines. The creator still replies, with
/// [TomExecutor.noResult]: an unanswered message would leave this `await`
/// pending forever, and liveness supervision could not see the hang, since the
/// isolate is healthy and still answers pings.
class DelegateUnclaimedToCreator extends TomCommand {
  @override
  Future<Object?> execute() async =>
      await TomWorker.executeInCreator('nothing on the creator handles this');
}

/// A domain failure with a type of its own, thrown by the commands below.
///
/// A distinct type is what makes the demonstration worth anything: any
/// transport can report "something went wrong", but only one that carries the
/// exception itself lets the caller write `on InventoryUnavailable` and branch
/// on which failure it was.
class InventoryUnavailable implements Exception {
  final String sku;

  InventoryUnavailable(this.sku);

  @override
  String toString() => 'InventoryUnavailable($sku)';
}

/// A command that throws inside the WORKER, to demonstrate error propagation.
class WorkerThrowingCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw InventoryUnavailable('sku-worker');
}

/// A command that throws on the CREATOR side, reached through the back-channel.
class CreatorThrowingCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw InventoryUnavailable('sku-creator');
}

/// Delegates a throwing command to the creator and reports what came back.
///
/// The failure is caught here rather than left to unwind so that the result
/// describes the creator-bound hop alone; letting it escape would send it over
/// the worker-bound hop as well, and the far end could not tell which hop
/// produced what it saw.
class DelegateThrowToCreator extends TomCommand {
  @override
  Future<Object?> execute() async {
    try {
      final resolved = await TomWorker.executeInCreator(
        CreatorThrowingCommand(),
      );
      return 'returned-as-value:${resolved.runtimeType}';
    } on InventoryUnavailable catch (e) {
      return 'rethrown:${e.sku}';
    }
  }
}

// ============================================================================
// Creator-Side Executor
// ============================================================================

/// Records fire-and-forget notifications received from workers.
///
/// Registered on the creator via `TomWorker.addExecutor(...)`, it is invoked
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
  print('=== 05: Creator Back-Channel Example ===\n');

  // Register a creator-side inbox for fire-and-forget notifications. The
  // registry is process-global and outlives this function, so note what the
  // chain held on entry: the cleanup below has to leave it exactly that way.
  final executorsOnEntry = TomWorker.executors.length;
  final inbox = CreatorInboxExecutor();
  TomWorker.addExecutor(inbox);

  // -------------------------------------------------------------------------
  // Example 1: The back-channel is only available inside workers
  // -------------------------------------------------------------------------
  print('1. Back-channel availability:');

  final canSendFromCreator = TomWorker.canSendToCreator();

  final context = BackchannelWorkerContext();
  final worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);

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

  final sendAck = await worker.executeCommand(
    NotifyCreatorCommand('worker-online'),
  );

  // sendToCreator is one-way; give the creator a moment to process the message.
  await Future.delayed(Duration(milliseconds: 20));

  print('   command returned: $sendAck');
  print('   creator inbox received: ${inbox.received}\n');

  // -------------------------------------------------------------------------
  // Example 4: Error propagation
  // -------------------------------------------------------------------------
  print('4. A throwing command rethrows, keeping its type:');

  // Recording the *result* of the call as well, not only what was caught: an
  // assertion that inspects a variable only ever written by a catch block is
  // satisfied just as well by nothing being thrown at all.
  Object? caught;
  try {
    caught = await worker.executeCommand(WorkerThrowingCommand());
  } catch (e) {
    caught = e;
  }

  final caughtFailure = caught is InventoryUnavailable ? caught : null;

  print('   caught: ${caught.runtimeType}');
  print('   sku:    ${caughtFailure?.sku}\n');

  // -------------------------------------------------------------------------
  // Example 5: The same contract in the other direction
  // -------------------------------------------------------------------------
  // Worth its own example because the two directions are separate code paths.
  // If only one of them carried failures as failures, every caller would have
  // to know which isolate it was running in before it could tell an error from
  // an answer -- and the one that guessed wrong would degrade a reported
  // failure into whatever its fallback for an unrecognized result happens to be.
  print('5. A creator-side throw reaches the worker as a throw:');

  final creatorFailure = await worker.executeCommand(DelegateThrowToCreator());

  print('   worker observed: $creatorFailure\n');

  // -------------------------------------------------------------------------
  // Example 6: Nothing on the creator claimed the message
  // -------------------------------------------------------------------------
  print('6. A message no creator-side executor claims:');

  final unclaimed = await worker.executeCommand(DelegateUnclaimedToCreator());

  // `identical`, not `==`: the sentinel is a const instance with no value
  // equality of its own. Recognizing it relies on that instance staying
  // canonical across the isolate hop — which is exactly why casting the result
  // instead would throw a TypeError naming a private type, far from the
  // addExecutor that was forgotten.
  final wasUnclaimed = identical(unclaimed, TomExecutor.noResult);

  print('   result is TomExecutor.noResult: $wasUnclaimed');
  print('   (the creator also logged a warning naming the command)\n');

  // -------------------------------------------------------------------------
  // Cleanup
  // -------------------------------------------------------------------------
  worker.close();

  // Withdraw exactly the one registration made above. `clearExecutors()` would
  // be wrong here even though it looks tidier: the chain belongs to the whole
  // process, so clearing it would discard registrations this example never
  // made and silently disarm whoever depends on them.
  final removed = TomWorker.removeExecutor(inbox);
  final executorsOnExit = TomWorker.executors.length;

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

  // Example 4: a thrown command completes the future with an error, and the
  // exception arrives with its own type rather than as a description of one.
  assert(caughtFailure != null);
  assert(caughtFailure?.sku == 'sku-worker');

  // Example 5: the creator-bound hop behaves identically. "returned-as-value"
  // would mean the exception had arrived as an ordinary result, which is
  // indistinguishable from a successful answer.
  assert(creatorFailure == 'rethrown:sku-creator');

  // Example 6: an unclaimed message is answered with the sentinel, and the
  // sentinel survives both hops as the same canonical instance.
  assert(wasUnclaimed);

  // Cleanup: the shared registry is handed back as it was found, which is what
  // lets this file run in any position among the samples.
  assert(removed);
  assert(executorsOnExit == executorsOnEntry);
}

/// Standalone entry point.
Future<void> main() async {
  requireAsserts();
  await run();
}
