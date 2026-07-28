/// Delivery semantics — the durable queue, the retries, and the failure
/// reporting that sit between "compose a message" and "a transport sent it".
///
/// ## There is exactly one retry mechanism, and it is not here
///
/// Sending mail synchronously ties a request's latency to a mail server's mood
/// and loses the message when either end restarts. So delivery is queued. But a
/// queue with retries, backoff, at-most-one-runner-per-item and failure alerts
/// is a substantial piece of machinery, and this framework already has it: the
/// kernel's job scheduler. Building a second one here would mean two backoff
/// curves to tune, two places a message can get stuck, and two answers to "why
/// hasn't this been delivered".
///
/// So [TomMessageOutbox] owns **no retry logic whatsoever**. It enqueues a job
/// run per message and the scheduler does the rest:
///
/// | Concern | Where it lives |
/// |---------|----------------|
/// | durability across restarts | [TomJobStore] |
/// | retry count and backoff | [TomRetryPolicy] |
/// | one delivery at a time per message | the run's coordination lease |
/// | recovering a run whose node died | the scheduler's lease timeout |
/// | failure reporting | [TomJobAlertSink] |
/// | give up permanently | [TomPermanentFailure] on the thrown error |
///
/// The only thing the outbox contributes is the *shape* of the run: a message
/// as the payload, and a body that hands it to a [TomMessageRouter].
///
/// ## Why the outbox runs its own scheduler
///
/// A scheduler has one dispatcher, and a delivery body holds a live transport —
/// a socket factory, an open connection, a router — none of which survive being
/// copied into an isolate. Delivery is also the wrong kind of work for an
/// isolate: it is latency-bound, not CPU-bound, so `await`ing a socket already
/// leaves the event loop free and an isolate hop buys nothing but a copy it
/// cannot make.
///
/// Rather than making that a rule callers must remember — "do not register the
/// outbox on a pool-backed scheduler" — the outbox constructs an
/// inline-dispatching scheduler of its own. Point it at the same [TomJobStore]
/// as the application's scheduler and the two coexist by design: the scheduler
/// declines to claim runs whose job it has not registered, so each takes only
/// its own.
///
/// ## What "queued" guarantees
///
/// At-least-once, the same guarantee the scheduler states for every job. A
/// message whose delivery succeeded but whose completion was not recorded
/// before the process died is delivered again. That is a property of every
/// durable queue that talks to a system without transactional handoff, SMTP
/// very much included, and it is stated rather than papered over.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'message.dart';
import 'message_transport.dart';

/// The default job name the outbox registers under.
///
/// Stable across restarts by necessity: it is the store key that ties queued
/// runs to the definition that knows how to execute them, so renaming it
/// strands everything already in the queue.
const String tomOutboxJobName = 'messaging.outbox';

/// A durable, retrying send queue in front of a [TomMessageRouter].
///
/// ```dart
/// final outbox = TomMessageOutbox(
///   router: TomMessageRouter()..register(TomSmtpTransport(settings)),
///   store: myDurableJobStore,
/// )..start();
///
/// await outbox.send(TomMessage.email(
///   to: [TomRecipient('ops@example.com')],
///   subject: 'Nightly build failed',
///   text: 'See the attached log.',
/// ));
/// ```
///
/// [send] returns as soon as the message is durably queued. Delivery — and any
/// retry it needs — happens on the outbox's own scheduler afterwards.
class TomMessageOutbox implements TomClosable {
  /// Where messages are handed for actual delivery.
  ///
  /// Not owned: [close] leaves it open, because a router shared with the rest
  /// of the application must not be torn down because the outbox stopped.
  final TomMessageRouter router;

  /// The registered job name.
  final String jobName;

  /// The scheduler driving delivery. Owned and closed by [close].
  final TomScheduler scheduler;

  /// The queue behind [scheduler], exposed so a caller can inspect what is
  /// pending, count failures, or purge history.
  final TomJobStore store;

  final StreamController<TomDeliveryReceipt> _receipts =
      StreamController<TomDeliveryReceipt>.broadcast();

  final DateTime Function() _clock;

  bool _closed = false;

  /// Creates an outbox.
  ///
  /// [store] defaults to an in-memory queue, which is right for tests and
  /// wrong for production: an outbox on a memory store loses everything queued
  /// when the process stops, which is precisely the failure queuing exists to
  /// prevent. Supply a durable store for any deployment that means it.
  ///
  /// [retryPolicy] defaults to five attempts over a widening backoff. Five
  /// rather than the framework default of three because a mail relay's
  /// transient refusals — greylisting above all — are routinely measured in
  /// minutes, and a budget that expires inside the greylist window turns a
  /// deliberate delay into a lost message.
  factory TomMessageOutbox({
    required TomMessageRouter router,
    TomJobStore? store,
    String jobName = tomOutboxJobName,
    TomRetryPolicy retryPolicy = const TomRetryPolicy(
      maxAttempts: 5,
      initialBackoff: Duration(minutes: 1),
      maxBackoff: Duration(minutes: 30),
    ),
    Duration timeout = const Duration(minutes: 2),
    Duration tickInterval = const Duration(seconds: 15),
    DateTime Function()? clock,
    TomJobAlertSink? onAlert,
    TomLeaseLock? lock,
  }) {
    // Resolved once, before the scheduler is built. A `store ?? …` repeated in
    // an initialiser list would construct *two* memory stores — the scheduler
    // would then be driving a queue that [send] never writes to, and nothing
    // would ever be delivered.
    final queue = store ?? TomMemoryJobStore();
    return TomMessageOutbox._(
      router: router,
      store: queue,
      jobName: jobName,
      clock: clock ?? DateTime.now,
      scheduler: TomScheduler(
        store: queue,
        dispatcher: const TomInlineJobDispatcher(),
        tickInterval: tickInterval,
        clock: clock,
        onAlert: onAlert,
        lock: lock,
      ),
      retryPolicy: retryPolicy,
      timeout: timeout,
    );
  }

  TomMessageOutbox._({
    required this.router,
    required this.store,
    required this.jobName,
    required this.scheduler,
    required DateTime Function() clock,
    required TomRetryPolicy retryPolicy,
    required Duration timeout,
  }) : _clock = clock {
    scheduler.register(
      TomJobDefinition(
        name: jobName,
        // Never clock-driven: a message is due the moment it is queued, not at
        // some recurring window. The empty stream satisfies the trigger's shape
        // without being the enqueue path — see [send] for why.
        schedule: const TomEventSchedule(
          Stream<Object?>.empty(),
          sourceName: 'outbox',
        ),
        body: (run) => _TomDeliveryCommand(this, run),
        retryPolicy: retryPolicy,
        timeout: timeout,
        // Messages are independent, and one relay handshake must not hold up
        // every other message behind it. Overlap also picks the right lease
        // key: per-run rather than per-job, so a cluster delivers different
        // messages concurrently while never delivering one message twice.
        allowOverlap: true,
      ),
    );
  }

  /// Receipts from every delivery that reached a transport, including partial
  /// ones ([TomDeliveryReceipt.isPartial]) and discards by a no-op transport.
  ///
  /// Failures are **not** here: they are reported through the scheduler's
  /// [TomJobAlertSink], which already carries the attempt number, the retry
  /// decision and the run whose payload is the message. Emitting failures on
  /// both channels would make "how many times did this fail" a question with
  /// two answers.
  Stream<TomDeliveryReceipt> get receipts => _receipts.stream;

  /// Queues [message] for delivery and returns once it is durably stored.
  ///
  /// The run id is derived from [TomMessage.id], which makes the message its
  /// own idempotence key: submitting the same message twice replaces the queued
  /// run rather than queueing a second copy. That is deliberate — a caller
  /// retrying a `send` it is unsure completed should not cause two deliveries.
  ///
  /// Enqueued directly rather than pushed through the schedule's event stream.
  /// The scheduler collapses events that arrive in the same clock instant into
  /// a single windowed run, which is correct for a trigger (two ticks of the
  /// same moment are one moment) and catastrophic for an outbox (two messages
  /// composed in the same microsecond are two messages). Owning the enqueue
  /// keeps the idempotence key the message id, where it belongs.
  Future<void> send(TomMessage message) async {
    _requireOpen();
    final now = _clock();
    await store.enqueue(
      TomJobRun(
        id: '$jobName:${message.id}',
        jobName: jobName,
        scheduledFor: now,
        runAt: now,
        payload: message.toJson(),
      ),
    );
  }

  /// Queues [message] and delivers it immediately, without waiting for a tick.
  ///
  /// For a caller that wants the durability of the queue and the latency of a
  /// direct send — a password reset, say, where a fifteen-second tick interval
  /// is felt by a human staring at an inbox. A failure still retries on the
  /// queue exactly as [send] would; the only difference is that the first
  /// attempt does not wait.
  Future<void> sendNow(TomMessage message) async {
    await send(message);
    await scheduler.tick();
  }

  /// Runs one delivery pass. Called by [start]'s timer; exposed so a test can
  /// drive delivery without waiting on wall-clock time.
  Future<void> tick() => scheduler.tick();

  /// Begins delivering on the scheduler's tick interval.
  void start() => scheduler.start();

  /// Drops finished runs recorded before [before] from the queue.
  ///
  /// An outbox that never forgets grows without bound; every message ever sent
  /// stays in the store as a completed run. How long to keep that history is a
  /// deployment's decision (it is a delivery audit trail, and may be worth
  /// keeping), so nothing purges automatically — but the handle exists so the
  /// decision can be made.
  Future<int> purgeFinished(DateTime before) => store.purgeFinished(before);

  /// Emits [receipt] to [receipts]. Called by the delivery body.
  void _report(TomDeliveryReceipt receipt) {
    if (!_receipts.isClosed) _receipts.add(receipt);
  }

  void _requireOpen() {
    if (_closed) {
      throw TomMessagingException(
        'messaging.outbox.closed',
        'The outbox has been closed and accepts no further messages.',
      );
    }
  }

  /// Stops delivery and releases the scheduler. The [router] is left open.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    scheduler.close();
    // Completes on a later microtask and nothing downstream depends on it;
    // awaiting would make [close] async for no observable difference.
    unawaited(_receipts.close());
  }
}

/// Delivers one queued message.
///
/// A [TomCommand] because that is what the scheduler dispatches, but it never
/// leaves this isolate — see the library comment on why delivery is inline.
class _TomDeliveryCommand extends TomCommand {
  final TomMessageOutbox _outbox;
  final TomJobRun _run;

  _TomDeliveryCommand(this._outbox, this._run);

  @override
  Future<Object?> execute() async {
    final payload = _run.payload;
    if (payload is! Map<String, dynamic>) {
      // Unreadable payloads are permanent by definition: no number of retries
      // will make a malformed run parse, and retrying it holds a slot that a
      // deliverable message could use.
      throw TomPermanentJobFailure(
        'Outbox run ${_run.id} has no readable message payload '
        '(${payload.runtimeType}).',
      );
    }
    final message = TomMessage.fromJson(payload);
    final receipt = await _outbox.router.send(message);
    _outbox._report(receipt);
    return receipt.toJson();
  }
}
