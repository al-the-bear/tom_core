/// The in-memory message bus: the contract kept inside one process, for tests
/// and for a single-process deployment.
library;

import 'dart:async';
import 'dart:math';

import 'bus.dart';
import 'codec.dart';
import 'dispatch.dart';
import 'message.dart';
import 'trace.dart';

/// A [TomMessageBus] in the memory of this process.
///
/// It keeps the whole contract, and ordering per key: within a group the
/// messages of one key are handled one at a time, in publish order. Each
/// consumer handles one delivery at a time, so the consumers of a group share
/// its messages between them. A message waits in memory until a consumer of
/// its group takes it — and is gone when the process ends, which is what makes
/// this bus a single-process one: a deployment of several processes, or one
/// that must not lose a message on a restart, uses an adapter over a broker.
class TomMemoryMessageBus implements TomMessageBus {
  /// A bus; [redeliveryDelay] is how long a rejected message waits before it
  /// is delivered again.
  TomMemoryMessageBus({
    this.redeliveryDelay = Duration.zero,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long a rejected message waits before its next delivery.
  final Duration redeliveryDelay;

  final DateTime Function() _clock;
  final Map<String, Map<String, _Group>> _topics = {};
  final Set<Future<void>> _inFlight = {};
  final Set<Timer> _timers = {};
  final Random _random = Random.secure();
  bool _closed = false;
  Future<void>? _closing;

  @override
  TomBusCapabilities get capabilities =>
      const TomBusCapabilities(orderedPerKey: true);

  void _requireOpen() {
    if (_closed) {
      throw TomBusException(
        'message_bus.closed',
        'The message bus has been closed.',
      );
    }
  }

  String _newId() {
    final buffer = StringBuffer('msg-');
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return '$buffer';
  }

  @override
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) async {
    _requireOpen();
    final json = (codec ?? TomBusCodec<T>.reflected()).encode(payload);
    final messageId = id ?? _newId();
    return TomBusTrace.publishing(topic, headers, (sent) async {
      _route(
        TomBusMessage(
          id: messageId,
          topic: topic,
          key: key,
          payload: json,
          headers: sent,
          publishedAt: _clock(),
        ),
      );
      return messageId;
    });
  }

  void _route(TomBusMessage message) {
    for (final group in (_topics[message.topic] ?? const {}).values) {
      group.queue.add(_Pending(message));
      _pump(group);
    }
  }

  @override
  Future<TomBusSubscription> subscribe<T>(
    String topic, {
    required String group,
    required TomBusHandler<T> handler,
    TomBusCodec<T>? codec,
    int maxDeliveries = 5,
    bool ephemeral = false,
  }) async {
    _requireOpen();
    tomCheckSubscription(topic, group, maxDeliveries);
    final target = (_topics[topic] ??= {})[group] ??= _Group(
      topic,
      group,
      ephemeral: ephemeral,
    );
    final consumer = _Consumer(
      this,
      target,
      maxDeliveries,
      (message, attempt) => tomDispatch(
        message,
        attempt: attempt,
        group: group,
        codec: codec ?? TomBusCodec<T>.reflected(),
        handler: handler,
      ),
    );
    target.consumers.add(consumer);
    _pump(target);
    return consumer;
  }

  /// Hands the group's waiting messages to its free consumers.
  void _pump(_Group group) {
    if (_closed) return;
    while (true) {
      final free = [
        for (final c in group.consumers)
          if (!c.busy) c,
      ];
      if (free.isEmpty) return;
      final index = group.queue.indexWhere(
        (p) => p.message.key == null || !group.busyKeys.contains(p.message.key),
      );
      if (index < 0) return;
      final pending = group.queue.removeAt(index);
      final consumer = free[group.next++ % free.length];
      _deliver(group, consumer, pending);
    }
  }

  void _deliver(_Group group, _Consumer consumer, _Pending pending) {
    consumer.busy = true;
    final key = pending.message.key;
    if (key != null) group.busyKeys.add(key);
    pending.attempts++;
    late final Future<void> run;
    run = Future(() async {
      final (outcome, reason) = await consumer.handle(
        pending.message,
        pending.attempts,
      );
      consumer.busy = false;
      switch (outcome) {
        case TomBusOutcome.acknowledged:
          if (key != null) group.busyKeys.remove(key);
        case TomBusOutcome.deadLettered:
          if (key != null) group.busyKeys.remove(key);
          _deadLetter(group, pending, reason ?? 'rejected');
        case TomBusOutcome.requeued:
          if (pending.attempts >= consumer.maxDeliveries) {
            if (key != null) group.busyKeys.remove(key);
            _deadLetter(group, pending, 'max-deliveries');
          } else {
            _requeue(group, pending);
          }
      }
      _pump(group);
    }).whenComplete(() => _inFlight.remove(run));
    _inFlight.add(run);
  }

  /// Puts [pending] back at the front of its group's queue — before the
  /// messages of its key behind it — after [redeliveryDelay].
  void _requeue(_Group group, _Pending pending) {
    void back() {
      final key = pending.message.key;
      if (key != null) group.busyKeys.remove(key);
      group.queue.insert(0, pending);
      _pump(group);
    }

    if (redeliveryDelay == Duration.zero) {
      back();
      return;
    }
    late final Timer timer;
    timer = Timer(redeliveryDelay, () {
      _timers.remove(timer);
      back();
    });
    _timers.add(timer);
  }

  void _deadLetter(_Group group, _Pending pending, String reason) {
    _route(
      tomDeadLetter(
        pending.message,
        group: group.name,
        reason: reason,
        attempts: pending.attempts,
      ),
    );
  }

  /// Completes when nothing is being handled and no message waits for a free
  /// consumer of its group — every delivery made so far has run its course.
  /// A message waiting for a redelivery delay, or for a group with no
  /// consumer, does not hold it up.
  Future<void> settled() async {
    while (true) {
      if (_inFlight.isNotEmpty) {
        await Future.wait(List.of(_inFlight));
        continue;
      }
      final waiting = _topics.values.any(
        (groups) => groups.values.any(
          (g) => g.queue.isNotEmpty && g.consumers.any((c) => !c.busy),
        ),
      );
      if (!waiting) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> close() => _closing ??= _shutDown();

  Future<void> _shutDown() async {
    _closed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final groups in _topics.values) {
      for (final group in groups.values) {
        group.consumers.clear();
      }
    }
    await Future.wait(List.of(_inFlight));
  }
}

class _Pending {
  _Pending(this.message);

  final TomBusMessage message;
  int attempts = 0;
}

class _Group {
  _Group(this.topic, this.name, {required this.ephemeral});

  final String topic;
  final String name;
  final bool ephemeral;
  final List<_Pending> queue = [];
  final List<_Consumer> consumers = [];
  final Set<String> busyKeys = {};
  int next = 0;
}

class _Consumer implements TomBusSubscription {
  _Consumer(this._bus, this._group, this.maxDeliveries, this.handle);

  final TomMemoryMessageBus _bus;
  final _Group _group;
  final int maxDeliveries;
  final Future<(TomBusOutcome, String?)> Function(
    TomBusMessage message,
    int attempt,
  )
  handle;
  bool busy = false;

  @override
  String get topic => _group.topic;

  @override
  String get group => _group.name;

  @override
  Future<void> cancel() async {
    _group.consumers.remove(this);
    if (_group.ephemeral && _group.consumers.isEmpty) {
      // The last consumer of an ephemeral group: the group goes, and what
      // waits for it with it.
      final groups = _bus._topics[_group.topic];
      if (identical(groups?[_group.name], _group)) groups!.remove(_group.name);
      _group.queue.clear();
    }
    await Future.wait(List.of(_bus._inFlight));
    _bus._pump(_group);
  }
}
