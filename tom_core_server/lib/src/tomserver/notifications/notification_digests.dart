/// Digests: the notifications a recipient chose to receive hourly or daily,
/// collected per channel and sent as one message when the digest is due.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';

import '../messaging/message.dart';
import '../messaging/outbox.dart';
import '../resources/localized_text_resources.dart';
import 'notification.dart';
import 'notification_renderer.dart';

/// The default job name digest runs are stored under.
const String tomNotificationDigestJobName = 'notifications.digest';

/// Collects digested notifications and sends each digest when it is due.
///
/// A digest is one recipient's notifications on one channel for one due time
/// (the end of an hour, a daily digest time). It is kept as one pending run of
/// a scheduler job, in the outbox's job store unless given another: the run's
/// id names the recipient, the channel and the due time, its payload holds the
/// collected items, and it becomes due at the due time. So a digest is as
/// durable as the outbox — a node that restarts finds the digests it was
/// collecting, and any node of a cluster sends a due one.
///
/// [add] appends to the digest's run. A notification already in the digest is
/// not added twice, and appends to one digest are serialised: within the
/// process always, across a cluster through [lock] when one is given (use the
/// cluster's lease lock — without one, two nodes appending to the same digest
/// at the same instant can lose an item).
///
/// When the run comes due the digest is rendered ([TomNotificationRenderer.renderDigest])
/// and handed to the outbox under an id derived from the run, so a digest run
/// that is retried queues its message once.
class TomNotificationDigests implements TomClosable {
  /// Where a due digest's message goes.
  final TomMessageOutbox outbox;

  /// Renders a digest.
  final TomNotificationRenderer renderer;

  /// The job name digest runs are stored under.
  final String jobName;

  /// The store holding the digests; the outbox's by default.
  final TomJobStore store;

  /// The scheduler that sends due digests.
  final TomScheduler scheduler;

  final TomLeaseLock? _lock;
  final String _owner;
  final DateTime Function() _clock;
  final Map<String, Future<void>> _appending = {};
  bool _closed = false;
  Future<void>? _closing;

  /// How long one append may hold the digest's lease.
  static const Duration lockTtl = Duration(seconds: 30);

  /// Creates the digests over [outbox]. [store] defaults to the outbox's job
  /// store; [lock] serialises appends across a cluster.
  factory TomNotificationDigests({
    required TomMessageOutbox outbox,
    required TomNotificationRenderer renderer,
    TomJobStore? store,
    String jobName = tomNotificationDigestJobName,
    TomLeaseLock? lock,
    Duration tickInterval = const Duration(seconds: 30),
    DateTime Function()? clock,
    TomJobAlertSink? onAlert,
    String? owner,
  }) {
    final runs = store ?? outbox.store;
    return TomNotificationDigests._(
      outbox: outbox,
      renderer: renderer,
      store: runs,
      jobName: jobName,
      lock: lock,
      owner: owner ?? 'digests-${const UuidV4().generate()}',
      clock: clock ?? DateTime.now,
      scheduler: TomScheduler(
        store: runs,
        dispatcher: const TomInlineJobDispatcher(),
        tickInterval: tickInterval,
        clock: clock,
        onAlert: onAlert,
        lock: lock,
      ),
    );
  }

  TomNotificationDigests._({
    required this.outbox,
    required this.renderer,
    required this.store,
    required this.jobName,
    required this.scheduler,
    required TomLeaseLock? lock,
    required String owner,
    required DateTime Function() clock,
  }) : _lock = lock,
       _owner = owner,
       _clock = clock {
    scheduler.register(
      TomJobDefinition(
        name: jobName,
        // Never clock-driven: a digest is enqueued by [add] with its own due
        // time, as the outbox enqueues its messages.
        schedule: const TomEventSchedule(
          Stream<Object?>.empty(),
          sourceName: 'notification digests',
        ),
        body: (run) => _TomDigestCommand(this, run),
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 5,
          initialBackoff: Duration(minutes: 1),
          maxBackoff: Duration(minutes: 30),
        ),
        timeout: const Duration(minutes: 2),
        allowOverlap: true,
      ),
    );
  }

  /// The id of the digest of [recipientId] on [channel] due at [dueAt].
  String runIdOf(
    String recipientId,
    TomMessageChannel channel,
    DateTime dueAt,
  ) {
    final digest = sha256.convert(
      utf8.encode(
        '$recipientId\u0000${channel.name}\u0000'
        '${dueAt.toUtc().toIso8601String()}',
      ),
    );
    return '$jobName:${digest.toString().substring(0, 32)}';
  }

  /// Adds [notification] to the digest of [recipient] on [channel] due at
  /// [dueAt], creating the digest when it is the first; answers `false` when
  /// the notification is in that digest already.
  ///
  /// A digest that is no longer collecting — its due time passed and it is
  /// being sent, or was sent — is not reopened: the notification goes to the
  /// outbox as a message of its own, rendered by [renderer] with
  /// [messageId], and the answer is `true`.
  Future<bool> add({
    required TomNotification notification,
    required TomNotificationRecipient recipient,
    required TomMessageChannel channel,
    required DateTime dueAt,
    required String messageId,
  }) {
    _requireOpen();
    final runId = runIdOf(recipient.id, channel, dueAt);
    final previous = _appending[runId] ?? Future<void>.value();
    final result = Completer<bool>();
    final done = previous.then((_) async {
      try {
        result.complete(
          await _locked(
            runId,
            () => _append(
              runId,
              notification,
              recipient,
              channel,
              dueAt,
              messageId,
            ),
          ),
        );
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    _appending[runId] = done;
    unawaited(
      done.whenComplete(() {
        if (identical(_appending[runId], done)) {
          unawaited(_appending.remove(runId));
        }
      }),
    );
    return result.future;
  }

  Future<bool> _append(
    String runId,
    TomNotification notification,
    TomNotificationRecipient recipient,
    TomMessageChannel channel,
    DateTime dueAt,
    String messageId,
  ) async {
    final item = TomNotificationDigestItem(
      notificationId: notification.id,
      type: notification.type.name,
      parameters: _jsonValues(notification.parameters),
      raisedAt: notification.createdAt,
    );
    final existing = await store.findRun(runId);
    if (existing != null && existing.state != TomJobRunState.pending) {
      return outbox.send(
        renderer.render(
          TomNotificationRendering(
            notification: notification,
            recipient: recipient,
            channel: channel,
            addresses: recipient.addresses[channel] ?? const [],
            messageId: messageId,
          ),
        ),
      );
    }
    final payload = existing?.payload is Map
        ? (existing!.payload! as Map).cast<String, Object?>()
        : <String, Object?>{
            'recipientId': recipient.id,
            'locale': recipient.locale?.tag,
            'recipientParameters': _jsonValues(recipient.parameters),
            'channel': channel.name,
            'addresses': [
              for (final address in recipient.addresses[channel] ?? const [])
                address.toJson(),
            ],
            'items': <Object?>[],
          };
    final items = [...(payload['items'] as List? ?? const [])];
    if (items.any((i) => i is Map && i['id'] == notification.id)) {
      return false;
    }
    items.add(item.toJson());
    final now = _clock();
    await store.enqueue(
      TomJobRun(
        id: runId,
        jobName: jobName,
        scheduledFor: existing?.scheduledFor ?? now,
        runAt: dueAt,
        payload: {...payload, 'items': items},
        tenant: existing?.tenant ?? TomTenantContext.currentId,
        // Keyed by the digest's run id, not a window.
        windowed: false,
      ),
    );
    return true;
  }

  Future<T> _locked<T>(String resource, Future<T> Function() body) async {
    final lock = _lock;
    if (lock == null) return body();
    TomLease? lease;
    var wait = const Duration(milliseconds: 5);
    final deadline = _clock().add(lockTtl);
    while ((lease = await lock.acquire(resource, _owner, lockTtl)) == null) {
      if (_clock().isAfter(deadline)) {
        throw TomNotificationException(
          'notifications.digest.locked',
          'The digest is being written by another node and did not come free.',
          parameters: {'digest': resource},
        );
      }
      await Future<void>.delayed(wait);
      if (wait < const Duration(milliseconds: 200)) wait *= 2;
    }
    try {
      return await body();
    } finally {
      await lock.release(lease!);
    }
  }

  /// The parameters as JSON values: what is not one is stored as its string.
  static Map<String, Object?> _jsonValues(Map<String, Object?> values) =>
      (jsonDecode(jsonEncode(values, toEncodable: (v) => v.toString())) as Map)
          .cast<String, Object?>();

  /// Sends every digest due now; for a caller driving the clock (a test, a
  /// one-shot process) rather than the scheduler.
  Future<void> tick() async {
    await scheduler.tick();
    await scheduler.drain();
  }

  /// Starts sending due digests on the scheduler's tick.
  void start() {
    _requireOpen();
    unawaited(scheduler.start());
  }

  Future<void> _send(TomJobRun run) async {
    final payload = run.payload;
    if (payload is! Map) {
      // throws-outside-family: kernel protocol — the scheduler's signal for a
      // run that must not be retried.
      throw TomPermanentJobFailure(
        'Digest run ${run.id} has no readable payload '
        '(${payload.runtimeType}).',
      );
    }
    final map = payload.cast<String, Object?>();
    final locale = map['locale'] as String?;
    final message = renderer.renderDigest(
      TomNotificationDigestRendering(
        recipientId: map['recipientId']! as String,
        locale: locale == null ? null : TomTextLocale.parse(locale),
        recipientParameters: (map['recipientParameters'] as Map? ?? const {})
            .cast<String, Object?>(),
        channel: TomMessageChannel(map['channel']! as String),
        addresses: [
          for (final address in map['addresses']! as List)
            TomRecipient.fromJson((address as Map).cast<String, Object?>()),
        ],
        items: [
          for (final item in map['items']! as List)
            TomNotificationDigestItem.fromJson(
              (item as Map).cast<String, Object?>(),
            ),
        ],
        messageId: 'notification-digest-${run.id.split(':').last}',
      ),
    );
    await outbox.send(message);
  }

  void _requireOpen() {
    if (_closed) {
      throw TomNotificationException(
        'notifications.digest.closed',
        'The notification digests have been closed and accept nothing more.',
      );
    }
  }

  @override
  Future<void> close() => _closing ??= () async {
    _closed = true;
    await Future.wait(_appending.values);
    await scheduler.close();
  }();
}

class _TomDigestCommand extends TomCommand {
  final TomNotificationDigests _digests;
  final TomJobRun _run;

  _TomDigestCommand(this._digests, this._run);

  @override
  Future<Object?> execute() async {
    await _digests._send(_run);
    return null;
  }
}
