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

import 'delivery_report.dart';
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

  /// Where a carrier's identifier for a delivered message is remembered, so a
  /// later delivery report can be matched back to the message.
  ///
  /// `null` — the default — means the ids are not kept, which is the right
  /// answer for a deployment whose channels report nothing back and the wrong
  /// one for SMS: a gateway's acceptance is not a handset reached, and
  /// `remoteId` is the only thread between the two.
  ///
  /// Only receipts that actually carry an id are remembered. A transport with
  /// nothing to put there — the memory and file stand-ins mint one, SMTP takes
  /// the relay's accept text — writes no row nobody could ever match.
  final TomDeliveryReportStore? reportStore;

  final StreamController<TomDeliveryReceipt> _receipts =
      StreamController<TomDeliveryReceipt>.broadcast();

  final DateTime Function() _clock;

  bool _closed = false;

  /// The close under way, once [close] has been called.
  Future<void>? _closing;

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
    TomDeliveryReportStore? reportStore,
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
      reportStore: reportStore,
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
    required this.reportStore,
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

  /// Queues [message] for delivery and returns once it is durably stored;
  /// answers whether it was queued.
  ///
  /// The run id is derived from [TomMessage.id], which makes the message its
  /// own idempotence key: a message whose id the outbox already holds — queued,
  /// delivered, or failed for good — is not queued again, and `send` answers
  /// `false`. That is deliberate — a caller retrying a `send` it is unsure
  /// completed should not cause two deliveries, however long ago the first one
  /// went out. The outbox holds an id until [purgeFinished] removes its run.
  ///
  /// Enqueued directly rather than pushed through the schedule's event stream.
  /// The scheduler collapses events that arrive in the same clock instant into
  /// a single windowed run, which is correct for a trigger (two ticks of the
  /// same moment are one moment) and catastrophic for an outbox (two messages
  /// composed in the same microsecond are two messages). Owning the enqueue
  /// keeps the idempotence key the message id, where it belongs.
  ///
  /// The message is queued for the tenant in context, and delivered inside it:
  /// a transport choosing a per-tenant sending identity reads it from there.
  ///
  /// [notBefore] holds the message in the queue until that instant: the first
  /// attempt is made at the first tick after it. A notification held through
  /// its recipient's quiet hours is queued this way, so it is durable from the
  /// moment it was raised. An instant already past is the same as none.
  ///
  /// With a tracer installed ([TomTracing]) queueing is a producer span,
  /// `outbox send`, and the message is queued with that span's `traceparent`
  /// (and `tracestate`) in its [TomMessage.headers]: the delivery continues
  /// the trace that queued it however much later it runs, and an email
  /// carries the header to whoever reads its source.
  Future<bool> send(TomMessage message, {DateTime? notBefore}) {
    final span = TomTracing.start(
      'outbox send',
      kind: TomSpanKind.producer,
      attributes: _messagingAttributes(message, 'send'),
    );
    if (span == null) return _send(message, notBefore);
    final traced = message.copyWith(
      headers: {...message.headers, ...span.context.headers},
    );
    return TomTracing.within(
      span,
      () => TomTracing.ending(span, () => _send(traced, notBefore)),
    );
  }

  Map<String, Object> _messagingAttributes(
    TomMessage message,
    String operation,
  ) => {
    'messaging.system': 'tom_outbox',
    'messaging.operation.type': operation,
    'messaging.destination.name': jobName,
    'messaging.message.id': message.id,
  };

  Future<bool> _send(TomMessage message, DateTime? notBefore) async {
    _requireOpen();
    final now = _clock();
    final runAt = notBefore != null && notBefore.isAfter(now) ? notBefore : now;
    final runId = '$jobName:${message.id}';
    if (await store.findRun(runId) != null) return false;
    await store.enqueue(
      TomJobRun(
        id: runId,
        jobName: jobName,
        scheduledFor: now,
        runAt: runAt,
        payload: message.toJson(),
        tenant: TomTenantContext.currentId,
        // The message's run is keyed by its id, not a window: two messages
        // queued in the same microsecond — on two nodes — are two runs.
        windowed: false,
      ),
    );
    return true;
  }

  /// Queues [message] and delivers it immediately, without waiting for a tick.
  ///
  /// For a caller that wants the durability of the queue and the latency of a
  /// direct send — a password reset, say, where a fifteen-second tick interval
  /// is felt by a human staring at an inbox. A failure still retries on the
  /// queue exactly as [send] would; the only difference is that the first
  /// attempt does not wait.
  ///
  /// Returns when that first attempt has finished, not merely when it has
  /// started: a caller reaching for `sendNow` over `send` wants the delivery
  /// resolved, and going through [tick] rather than the scheduler's pass
  /// directly is what makes the await mean that.
  Future<void> sendNow(TomMessage message) async {
    await send(message);
    await tick();
  }

  /// Runs one delivery pass, completing when the pass has finished.
  ///
  /// Called by [start]'s timer; exposed so a test can drive delivery without
  /// waiting on wall-clock time — and so a shutdown path can empty the queue
  /// before closing.
  ///
  /// "Finished" means every message this pass picked up has been through a
  /// transport and its outcome recorded: delivered, scheduled for retry, or
  /// failed for good. It does not mean the queue is empty — a pass claims at
  /// most `maxRunsPerTick` messages, so a backlog takes several.
  ///
  /// The [TomScheduler.drain] is what makes that true. A scheduler pass
  /// *starts* the runs it finds due and returns, so that one slow job cannot
  /// hold up the next window of a fast one; awaiting the pass alone would
  /// return with the deliveries still pending as microtasks.
  Future<void> tick() async {
    await scheduler.tick();
    await scheduler.drain();
  }

  /// Begins delivering on the scheduler's tick interval, and registers this
  /// outbox in [started] until [close].
  void start() {
    _requireOpen();
    _started.add(this);
    unawaited(scheduler.start());
  }

  static final Set<TomMessageOutbox> _started = {};

  /// The outboxes of this isolate that were started and not yet closed — what
  /// the framework readiness check asks whether they are delivering.
  static Set<TomMessageOutbox> get started => Set.unmodifiable(_started);

  /// The oldest message of this outbox that is due and not yet taken for
  /// delivery has been waiting since this instant, or `null` when none waits.
  Future<DateTime?> oldestWaitingSince() async {
    for (final backlog in await store.backlog(_clock())) {
      if (backlog.jobName == jobName) return backlog.oldestDueAt;
    }
    return null;
  }

  /// Drops finished runs recorded before [before] from the queue.
  ///
  /// An outbox that never forgets grows without bound; every message ever sent
  /// stays in the store as a completed run. How long to keep that history is a
  /// deployment's decision (it is a delivery audit trail, and may be worth
  /// keeping), so nothing purges automatically — but the handle exists so the
  /// decision can be made.
  Future<int> purgeFinished(DateTime before) => store.purgeFinished(before);

  /// Emits [receipt] to [receipts] and remembers its carrier id. Called by the
  /// delivery body.
  ///
  /// The correlation is written *before* the run is completed, which is the
  /// order that matters: a report can arrive while the process is still
  /// recording the send — carriers are fast and some post the first status
  /// within the second — and an index written afterwards would have a window in
  /// which the report is unmatchable.
  ///
  /// Both name the tenant the message was sent for: the delivery body runs in
  /// it, because the run carries it.
  Future<void> _report(TomDeliveryReceipt receipt, TomMessage message) async {
    final tenant = TomTenantContext.currentId;
    final index = reportStore;
    if (index != null && receipt.remoteId != null) {
      await index.remember(
        TomDeliveryCorrelation(
          remoteId: receipt.remoteId!,
          messageId: receipt.messageId,
          channel: message.channel,
          sentAt: receipt.at,
          tenant: tenant,
          addresses: [
            for (final address in message.envelopeAddresses)
              if (!receipt.rejectedRecipients.contains(address)) address,
          ],
        ),
      );
    }
    if (!_receipts.isClosed) _receipts.add(receipt.forTenant(tenant));
  }

  void _requireOpen() {
    if (_closed) {
      throw TomMessagingException(
        'messaging.outbox.closed',
        'The outbox has been closed and accepts no further messages.',
      );
    }
  }

  /// Stops delivery, closes the scheduler — releasing the leases it holds —
  /// and closes [receipts], completing once all of that has. The [router] is
  /// left open. Idempotent: every call is handed the same close.
  @override
  Future<void> close() => _closing ??= _shutDown();

  Future<void> _shutDown() async {
    _closed = true;
    _started.remove(this);
    await scheduler.close();
    await _receipts.close();
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
      // throws-outside-family: kernel protocol — the scheduler's signal for a
      // run that must not be retried.
      throw TomPermanentJobFailure(
        'Outbox run ${_run.id} has no readable message payload '
        '(${payload.runtimeType}).',
      );
    }
    final message = TomMessage.fromJson(payload);
    // The delivery continues the trace that queued the message, when it was
    // queued in one; otherwise it is a step of the job run's own trace.
    final producer = TomTraceContext.parse(
      message.headers['traceparent'],
      traceState: message.headers['tracestate'],
    );
    final span = TomTracing.start(
      'outbox deliver',
      kind: TomSpanKind.consumer,
      parent: producer,
      attributes: {
        ..._outbox._messagingAttributes(message, 'process'),
        'tom.job.run_id': _run.id,
      },
    );
    Future<Object?> deliver() async {
      final receipt = await _outbox.router.send(message);
      await _outbox._report(receipt, message);
      return receipt.toJson();
    }

    return span == null
        ? deliver()
        : TomTracing.within(span, () => TomTracing.ending(span, deliver));
  }
}
