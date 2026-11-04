/// The bus relay: messages for a [TomMessageBus] queued on a job store, so a
/// publish commits with the caller's database transaction, and published to
/// the bus once it has.
///
/// Publishing to a broker inside a transaction cannot be undone when the
/// transaction rolls back, and publishing after the commit loses the message
/// when the process stops in between. The relay is the transactional outbox
/// for the bus: [TomBusRelay.publish] writes a run to its [TomJobStore] — in
/// the caller's transaction on a `TomSqlJobStore`, as the message outbox does
/// — and the relay's own scheduler publishes it to the bus, retrying a publish
/// the broker refused.
///
/// ## The guarantees
///
/// - **Nothing is published for a rolled-back transaction**: the queued run
///   was never committed.
/// - **Nothing committed is lost.** A process that stops between the commit
///   and the publish leaves the run queued, and the next relay on the store
///   publishes it. One that stops during the publish leaves the run claimed;
///   once its lease has expired the scheduler re-queues it — the relay
///   requests recovery — and it is published again.
/// - **Duplicates are possible.** A publish the broker accepted whose
///   completion was not recorded is made again, under the same message id: at
///   least once, as the bus delivers, so a consumer recognises a message it
///   has handled by its id.
/// - **One node relays at a time.** The relay's job does not overlap, so with
///   a [TomLeaseLock] shared by the nodes the cluster publishes one message at
///   a time, in the order the messages were queued — a message whose publish
///   failed is retried after its backoff, behind the ones queued after it.
library;

import 'dart:async';
import 'dart:math';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

import '../scheduling/event_instants.dart';
import 'message.dart';

/// The default job name the relay registers under. Stable across restarts:
/// it ties queued runs to the relay that publishes them.
const String tomBusRelayJobName = 'messaging.bus_relay';

/// Queues messages for [bus] on [store], and publishes them.
class TomBusRelay implements TomClosable {
  /// A relay to [bus].
  ///
  /// [store] defaults to an in-memory queue — for tests: a relay on a memory
  /// store joins no transaction and loses what it holds when the process
  /// stops. [retryPolicy] governs a publish the bus refused.
  factory TomBusRelay({
    required TomMessageBus bus,
    TomJobStore? store,
    String jobName = tomBusRelayJobName,
    TomRetryPolicy retryPolicy = const TomRetryPolicy(
      maxAttempts: 10,
      initialBackoff: Duration(seconds: 5),
      maxBackoff: Duration(minutes: 5),
    ),
    Duration timeout = const Duration(seconds: 30),
    Duration tickInterval = const Duration(seconds: 1),
    DateTime Function()? clock,
    TomJobAlertSink? onAlert,
    TomLeaseLock? lock,
  }) {
    final queue = store ?? TomMemoryJobStore();
    return TomBusRelay._(
      bus: bus,
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

  TomBusRelay._({
    required this.bus,
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
        // Never clock-driven: a message is due when it is queued; see
        // TomMessageOutbox for why the enqueue does not go through the stream.
        schedule: const TomEventSchedule(
          Stream<Object?>.empty(),
          sourceName: 'bus relay',
        ),
        body: (run) => _TomBusRelayCommand(this, run),
        retryPolicy: retryPolicy,
        timeout: timeout,
        // One message at a time, cluster-wide with a shared lease lock: the
        // lease is the job's, so messages are published in queue order.
        allowOverlap: false,
        // A publish interrupted by a stopping process is made again: the
        // message is lost otherwise, and a duplicate is what at-least-once
        // already allows.
        requestsRecovery: true,
      ),
    );
  }

  /// The bus messages are published to. Not owned: [close] leaves it open.
  final TomMessageBus bus;

  /// The queue the messages wait in.
  final TomJobStore store;

  /// The registered job name.
  final String jobName;

  /// The scheduler publishing the queued messages. Owned.
  final TomScheduler scheduler;

  final DateTime Function() _clock;
  final Random _random = Random.secure();
  bool _closed = false;
  Future<void>? _closing;
  Timer? _timer;
  Future<void>? _ticking;
  int _published = 0;

  /// Queues [payload] for [topic], encoded by [codec] (the reflection codec
  /// unless given), and answers the message id — [id] when given. The message
  /// is published by a later [tick], with [key] and [headers] and the trace
  /// the publish was made in.
  ///
  /// Inside a transaction on a `TomSqlJobStore` the queued run is written in
  /// that transaction: the message is published after the commit, or never.
  /// A message id the relay already holds is not queued again.
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) async {
    if (_closed) {
      throw TomMessagingException(
        'messaging.bus_relay.closed',
        'The bus relay has been closed.',
      );
    }
    final json = (codec ?? TomBusCodec<T>.reflected()).encode(payload);
    final messageId = id ?? _newId();
    final runId = '$jobName:$messageId';
    if (await store.findRun(runId) != null) return messageId;
    final now = _clock();
    final trace = TomTraceContext.current;
    await store.enqueue(
      TomJobRun(
        id: runId,
        jobName: jobName,
        scheduledFor: TomEventInstants.next(now),
        runAt: now,
        payload: {
          'id': messageId,
          'topic': topic,
          'key': ?key,
          'headers': headers,
          'payload': json,
          'trace': ?trace?.traceparent,
          'traceState': ?trace?.traceState,
        },
        tenant: TomTenantContext.currentId,
      ),
    );
    return messageId;
  }

  String _newId() {
    final buffer = StringBuffer('msg-');
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return '$buffer';
  }

  /// Publishes what is due, one message after another, completing when a pass
  /// of the scheduler publishes nothing more — the queue is empty, what is
  /// left waits for a retry, or another node holds the relay's lease. A tick
  /// asked for while one runs joins it.
  Future<void> tick() =>
      _ticking ??= _tick().whenComplete(() => _ticking = null);

  Future<void> _tick() async {
    while (!_closed) {
      final before = _published;
      await scheduler.tick();
      await scheduler.drain();
      if (_published == before) return;
    }
  }

  /// Begins publishing: a [tick] every tick interval of the scheduler.
  void start() {
    _timer ??= Timer.periodic(scheduler.tickInterval, (_) {
      if (!_closed) unawaited(tick());
    });
    unawaited(tick());
  }

  /// Stops publishing and closes the scheduler; [bus] stays open.
  @override
  Future<void> close() => _closing ??= _shutDown();

  Future<void> _shutDown() async {
    _closed = true;
    _timer?.cancel();
    await _ticking;
    await scheduler.close();
  }
}

/// Publishes one queued message.
class _TomBusRelayCommand extends TomCommand {
  _TomBusRelayCommand(this._relay, this._run);

  final TomBusRelay _relay;
  final TomJobRun _run;

  @override
  Future<Object?> execute() async {
    final queued = _run.payload;
    if (queued is! Map) {
      // throws-outside-family: kernel protocol — the scheduler's signal for a
      // run that must not be retried.
      throw TomPermanentJobFailure(
        'Bus relay run ${_run.id} has no readable message.',
      );
    }
    final headers = <String, String>{
      for (final e in ((queued['headers'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    Future<String> publish() => _relay.bus.publish<Object?>(
      queued['topic']! as String,
      queued['payload'],
      key: queued['key'] as String?,
      headers: headers,
      id: queued['id']! as String,
    );
    // Published in the trace the message was queued in, so a consumer's
    // handling joins the request that queued it.
    final trace = TomTraceContext.parse(
      queued['trace'] as String?,
      traceState: queued['traceState'] as String?,
    );
    final id = await (trace == null
        ? publish()
        : TomTraceContext.run(trace, publish));
    _relay._published++;
    return id;
  }
}
