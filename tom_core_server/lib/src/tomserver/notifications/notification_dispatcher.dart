/// The dispatcher: one notification out to the messaging outbox, once per
/// recipient and channel the recipient wants it on.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../messaging/message.dart';
import '../messaging/outbox.dart';
import 'notification.dart';
import 'notification_catalog.dart';
import 'notification_digests.dart';
import 'notification_preferences.dart';
import 'notification_renderer.dart';

/// What became of one recipient-channel pair of a dispatch.
enum TomNotificationDeliveryOutcome {
  /// Queued in the outbox for delivery now.
  queued,

  /// Queued in the outbox, held until the recipient's quiet hours end.
  deferred,

  /// Added to the recipient's hourly or daily digest, which goes out at
  /// [TomNotificationDelivery.notBefore].
  digested,

  /// The outbox already held this message — an earlier dispatch of the same
  /// notification queued it — so nothing was queued again.
  alreadyQueued,

  /// The recipient has no address on the channel; nothing was queued.
  noAddress,
}

/// One recipient-channel pair of a dispatch.
class TomNotificationDelivery {
  /// The recipient's [TomNotificationRecipient.id].
  final String recipientId;

  /// The channel.
  final TomMessageChannel channel;

  /// What became of it.
  final TomNotificationDeliveryOutcome outcome;

  /// The id of the message; `null` when there is none (no address).
  final String? messageId;

  /// For [TomNotificationDeliveryOutcome.deferred], when delivery may start;
  /// for [TomNotificationDeliveryOutcome.digested], when the digest goes out.
  final DateTime? notBefore;

  /// Creates a delivery record.
  const TomNotificationDelivery({
    required this.recipientId,
    required this.channel,
    required this.outcome,
    this.messageId,
    this.notBefore,
  });

  @override
  String toString() =>
      'TomNotificationDelivery($recipientId, ${channel.name}, ${outcome.name})';
}

/// What a dispatch did: every recipient-channel pair it considered, and the
/// recipients it reached on no channel at all.
class TomNotificationDispatchReport {
  /// The notification dispatched.
  final TomNotification notification;

  /// One entry per recipient and channel the recipient wanted it on.
  final List<TomNotificationDelivery> deliveries;

  /// The recipients whose choice left no channel — they turned the type off.
  final List<String> optedOut;

  /// Creates a report.
  TomNotificationDispatchReport({
    required this.notification,
    required List<TomNotificationDelivery> deliveries,
    required List<String> optedOut,
  }) : deliveries = List.unmodifiable(deliveries),
       optedOut = List.unmodifiable(optedOut);

  /// The deliveries that queued a message — now, deferred, or into a digest.
  List<TomNotificationDelivery> get queued => [
    for (final delivery in deliveries)
      if (delivery.outcome == TomNotificationDeliveryOutcome.queued ||
          delivery.outcome == TomNotificationDeliveryOutcome.deferred ||
          delivery.outcome == TomNotificationDeliveryOutcome.digested)
        delivery,
  ];
}

/// Fans one notification out to the messaging outbox.
///
/// For a notification of a registered type it:
///
/// 1. takes the recipients the notification names and those the type's
///    [TomNotificationAudience] resolves, merging a principal named twice;
/// 2. reads each recipient's choice ([TomNotificationPreferences.choiceFor]):
///    the channels, within what the type allows, and the quiet hours;
/// 3. for each chosen channel the recipient has an address on, renders one
///    message ([TomNotificationRenderer]) and queues it in the outbox — held
///    until the quiet hours end when the type is not urgent and the window is
///    open now — or, when the recipient chose an hourly or daily cadence and
///    [digests] is given, adds it to their digest for that channel instead.
///    Without [digests] every notification goes out at once.
///
/// Every message id is derived from the notification id, the recipient and
/// the channel, and the outbox queues a message id once: dispatching the same
/// notification again — a retry after a crash halfway through, or an hour
/// later — queues only what the first dispatch did not, and reports the rest
/// as [TomNotificationDeliveryOutcome.alreadyQueued].
///
/// The dispatcher knows nothing about transports and the outbox nothing about
/// notifications; a channel the deployment routes is a channel a type may
/// allow.
class TomNotificationDispatcher {
  /// Where the messages go.
  final TomMessageOutbox outbox;

  /// The registered types and their audiences.
  final TomNotificationCatalog catalog;

  /// The choice rules.
  final TomNotificationPreferences preferences;

  /// The renderer.
  final TomNotificationRenderer renderer;

  /// Where notifications of an hourly or daily cadence are collected; `null`
  /// sends every notification at once.
  final TomNotificationDigests? digests;

  final DateTime Function() _clock;

  /// Creates a dispatcher.
  TomNotificationDispatcher({
    required this.outbox,
    required this.catalog,
    this.preferences = const TomNotificationPreferences(),
    this.renderer = const TomTemplatedNotificationRenderer(),
    this.digests,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The installed dispatcher, or `null`.
  static TomNotificationDispatcher? resolve() {
    final installed = TomBean.getBeanByType(TomNotificationDispatcher);
    return installed is TomNotificationDispatcher ? installed : null;
  }

  /// Dispatches [notification]; returns what became of each recipient and
  /// channel.
  ///
  /// Refuses (`notifications.type.unknown`) a notification whose type is not
  /// the one registered in [catalog] under its name. Every message is rendered
  /// before the first is queued, so a missing template fails the dispatch
  /// without having sent part of it.
  Future<TomNotificationDispatchReport> dispatch(
    TomNotification notification,
  ) async {
    final type = notification.type;
    if (!catalog.isRegistered(type)) {
      throw TomNotificationException(
        'notifications.type.unknown',
        "Notification type '${type.name}' is not registered in the catalog.",
        parameters: {'type': type.name, 'notificationId': notification.id},
      );
    }
    final now = _clock();
    final deliveries = <TomNotificationDelivery>[];
    final optedOut = <String>[];
    final pending = <(Future<bool> Function(), TomNotificationDelivery)>[];
    for (final recipient in await _recipientsOf(notification)) {
      final choice = await preferences.choiceFor(recipient.principal, type);
      if (choice.channels.isEmpty) {
        optedOut.add(recipient.id);
        continue;
      }
      final digestAt = digests == null ? null : choice.digestAt(now);
      final notBefore = type.urgent || digestAt != null
          ? null
          : choice.quietHours?.endAfter(now, choice.timeZone);
      for (final channel in _ordered(choice.channels)) {
        final addresses = recipient.addresses[channel] ?? const [];
        if (addresses.isEmpty) {
          deliveries.add(
            TomNotificationDelivery(
              recipientId: recipient.id,
              channel: channel,
              outcome: TomNotificationDeliveryOutcome.noAddress,
            ),
          );
          continue;
        }
        final messageId = messageIdOf(notification, recipient, channel);
        final rendering = TomNotificationRendering(
          notification: notification,
          recipient: recipient,
          channel: channel,
          addresses: addresses,
          messageId: messageId,
        );
        if (digestAt != null) {
          // Rendered now as a digest of one, so a missing digest template
          // fails this dispatch rather than the digest hours later.
          renderer.renderDigest(_probeDigest(rendering));
          pending.add((
            () => digests!.add(
              notification: notification,
              recipient: recipient,
              channel: channel,
              dueAt: digestAt,
              messageId: messageId,
            ),
            TomNotificationDelivery(
              recipientId: recipient.id,
              channel: channel,
              outcome: TomNotificationDeliveryOutcome.digested,
              messageId: messageId,
              notBefore: digestAt,
            ),
          ));
          continue;
        }
        final message = renderer.render(rendering);
        pending.add((
          () => outbox.send(message, notBefore: notBefore),
          TomNotificationDelivery(
            recipientId: recipient.id,
            channel: channel,
            outcome: notBefore == null
                ? TomNotificationDeliveryOutcome.queued
                : TomNotificationDeliveryOutcome.deferred,
            messageId: messageId,
            notBefore: notBefore,
          ),
        ));
      }
    }
    for (final (queue, delivery) in pending) {
      final queued = await queue();
      deliveries.add(
        queued
            ? delivery
            : TomNotificationDelivery(
                recipientId: delivery.recipientId,
                channel: delivery.channel,
                outcome: TomNotificationDeliveryOutcome.alreadyQueued,
                messageId: delivery.messageId,
              ),
      );
    }
    return TomNotificationDispatchReport(
      notification: notification,
      deliveries: deliveries,
      optedOut: optedOut,
    );
  }

  static TomNotificationDigestRendering _probeDigest(
    TomNotificationRendering rendering,
  ) => TomNotificationDigestRendering(
    recipientId: rendering.recipient.id,
    locale: rendering.recipient.locale,
    recipientParameters: rendering.recipient.parameters,
    channel: rendering.channel,
    addresses: rendering.addresses,
    items: [
      TomNotificationDigestItem(
        notificationId: rendering.notification.id,
        type: rendering.notification.type.name,
        parameters: rendering.notification.parameters,
        raisedAt: rendering.notification.createdAt,
      ),
    ],
    messageId: rendering.messageId,
  );

  /// The id of the message [notification] becomes for [recipient] on
  /// [channel]: the same for the same three, whichever process computes it.
  static String messageIdOf(
    TomNotification notification,
    TomNotificationRecipient recipient,
    TomMessageChannel channel,
  ) {
    final digest = sha256.convert(
      utf8.encode(
        '${notification.id}\u0000${recipient.id}\u0000'
        '${channel.name}',
      ),
    );
    return 'notification-${digest.toString().substring(0, 32)}';
  }

  Future<List<TomNotificationRecipient>> _recipientsOf(
    TomNotification notification,
  ) async {
    final merged = <String, TomNotificationRecipient>{};
    void add(TomNotificationRecipient recipient) {
      final known = merged[recipient.id];
      merged[recipient.id] = known == null ? recipient : known.merge(recipient);
    }

    notification.recipients.forEach(add);
    final audience = catalog.audienceOf(notification.type);
    if (audience != null) {
      (await audience.resolve(notification)).forEach(add);
    }
    return merged.values.toList(growable: false);
  }

  /// The channels in a stable order, so a report reads the same each time.
  static List<TomMessageChannel> _ordered(Set<TomMessageChannel> channels) =>
      channels.toList()..sort((a, b) => a.name.compareTo(b.name));
}
