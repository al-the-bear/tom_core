/// Rendering: one notification, for one recipient, on one channel, as the
/// message the outbox delivers.
library;

import 'dart:convert';

import '../messaging/message.dart';
import '../resources/localized_text_resources.dart';
import 'notification.dart';

/// What a renderer is asked to render: [notification] for [recipient] on
/// [channel], addressed to [addresses], as the message with id [messageId].
class TomNotificationRendering {
  /// The notification.
  final TomNotification notification;

  /// Who it is for.
  final TomNotificationRecipient recipient;

  /// The channel the message goes out on.
  final TomMessageChannel channel;

  /// The recipient's addresses on [channel]; never empty.
  final List<TomRecipient> addresses;

  /// The id the message must carry, which keeps a repeated dispatch from
  /// queueing a second copy.
  final String messageId;

  /// Creates a rendering request.
  const TomNotificationRendering({
    required this.notification,
    required this.recipient,
    required this.channel,
    required this.addresses,
    required this.messageId,
  });

  /// The template values: the notification's parameters with the recipient's
  /// on top.
  Map<String, Object?> get parameters => {
    ...notification.parameters,
    ...recipient.parameters,
  };

  /// The metadata every rendered message carries, so a delivery report or a
  /// log line leads back to the notification.
  Map<String, Object?> get metadata => {
    'notificationType': notification.type.name,
    'notificationId': notification.id,
    'recipientId': recipient.id,
  };
}

/// One notification collected into a digest: enough to render its line when
/// the digest goes out, long after the notification itself is gone.
class TomNotificationDigestItem {
  /// The notification's id.
  final String notificationId;

  /// The name of its type.
  final String type;

  /// Its template values, as JSON values.
  final Map<String, Object?> parameters;

  /// When it was raised.
  final DateTime raisedAt;

  /// Creates an item.
  TomNotificationDigestItem({
    required this.notificationId,
    required this.type,
    Map<String, Object?> parameters = const {},
    required this.raisedAt,
  }) : parameters = Map.unmodifiable(parameters);

  /// The item as JSON.
  Map<String, Object?> toJson() => {
    'id': notificationId,
    'type': type,
    'parameters': parameters,
    'raisedAt': raisedAt.toUtc().toIso8601String(),
  };

  /// Reads [toJson]'s form.
  factory TomNotificationDigestItem.fromJson(Map<String, Object?> map) =>
      TomNotificationDigestItem(
        notificationId: map['id']! as String,
        type: map['type']! as String,
        parameters: (map['parameters'] as Map? ?? const {})
            .cast<String, Object?>(),
        raisedAt: DateTime.parse(map['raisedAt']! as String),
      );
}

/// What a renderer is asked to render for a digest: the [items] collected for
/// one recipient on [channel], as the message with id [messageId].
class TomNotificationDigestRendering {
  /// The recipient's id.
  final String recipientId;

  /// The locale the digest is rendered in.
  final TomTextLocale? locale;

  /// The recipient's template values (`{firstname}`).
  final Map<String, Object?> recipientParameters;

  /// The channel the digest goes out on.
  final TomMessageChannel channel;

  /// The recipient's addresses on [channel].
  final List<TomRecipient> addresses;

  /// The notifications collected, oldest first; never empty.
  final List<TomNotificationDigestItem> items;

  /// The id the digest message must carry.
  final String messageId;

  /// Creates a digest rendering request.
  const TomNotificationDigestRendering({
    required this.recipientId,
    this.locale,
    this.recipientParameters = const {},
    required this.channel,
    required this.addresses,
    required this.items,
    required this.messageId,
  });

  /// The metadata every digest message carries.
  Map<String, Object?> get metadata => {
    'notificationDigest': true,
    'notificationIds': [for (final item in items) item.notificationId],
    'recipientId': recipientId,
  };
}

/// Turns a notification into a message for one recipient and channel, and a
/// digest of notifications into one message.
abstract class TomNotificationRenderer {
  /// Creates a renderer.
  const TomNotificationRenderer();

  /// The message for [rendering]; it must carry [TomNotificationRendering.messageId]
  /// and be addressed to [TomNotificationRendering.addresses].
  TomMessage render(TomNotificationRendering rendering);

  /// The one message for a digest; it must carry
  /// [TomNotificationDigestRendering.messageId] and be addressed to
  /// [TomNotificationDigestRendering.addresses].
  TomMessage renderDigest(TomNotificationDigestRendering rendering);
}

/// The renderer that composes every message from resource keys, in the
/// recipient's locale — no user-facing text is written in Dart.
///
/// For type `taskAssigned` on channel `email` it reads, under
/// `notification.taskAssigned`, the channel's own key first and the type's
/// second:
///
/// | Text | Keys |
/// | ---- | ---- |
/// | subject (email; push title) | `email.subject`, `subject` |
/// | body (required) | `email.body`, `body` |
/// | HTML body (email, optional) | `email.html` |
///
/// so a type states its text once and overrides it where a channel needs it —
/// typically a shorter SMS. Parameters are the notification's with the
/// recipient's on top (`{taskTitle}`, `{firstname}`). A missing body is a
/// `notifications.template.missing` failure, naming the key.
///
/// A digest reads `notification.digest`: `<channel>.subject` / `subject` with
/// `{count}`, and `<channel>.body` / `body` (required) with `{count}` and
/// `{items}`, the items' lines one per line. Each line is the item's type's
/// `digestItem` key, else its channel body, else its body, rendered with the
/// item's parameters and the recipient's.
///
/// A `webhook` message is not rendered from text: its recipient is a program,
/// and its body is the notification as JSON (`type`, `id`, `parameters`) — a
/// digest's is `{"digest": true, "items": [...]}`.
class TomTemplatedNotificationRenderer extends TomNotificationRenderer {
  final TomLocalizedTextResources? _texts;

  /// The prefix of every notification resource key.
  static const String keyPrefix = 'notification';

  /// Renders from [texts], else the installed `TomLocalizedTextResources`.
  const TomTemplatedNotificationRenderer({TomLocalizedTextResources? texts})
    : _texts = texts;

  TomLocalizedTextResources get _resources =>
      _texts ??
      TomLocalizedTextResources.resolve() ??
      (throw TomNotificationException(
        'notifications.texts.not_configured',
        'Notifications are rendered from TomLocalizedTextResources, and none '
            'was passed or installed as a bean.',
      ));

  @override
  TomMessage render(TomNotificationRendering rendering) {
    final channel = rendering.channel;
    if (channel == TomMessageChannel.webhook) return _webhook(rendering);
    final subject = _text(rendering, 'subject');
    final body = _text(rendering, 'body', required: true)!;
    if (channel == TomMessageChannel.email) {
      return TomMessage(
        id: rendering.messageId,
        channel: channel,
        recipients: rendering.addresses,
        subject: subject,
        bodies: [
          TomMessageBody.text(body),
          if (_text(rendering, 'html', channelOnly: true) case final html?)
            TomMessageBody.html(html),
        ],
        metadata: rendering.metadata,
      );
    }
    if (channel == TomMessageChannel.push) {
      return TomMessage.push(
        id: rendering.messageId,
        to: rendering.addresses,
        title: subject,
        body: body,
        data: {
          'notificationType': rendering.notification.type.name,
          'notificationId': rendering.notification.id,
        },
        metadata: rendering.metadata,
      );
    }
    return TomMessage(
      id: rendering.messageId,
      channel: channel,
      recipients: rendering.addresses,
      subject: channel == TomMessageChannel.sms ? null : subject,
      bodies: [TomMessageBody.text(body)],
      metadata: rendering.metadata,
    );
  }

  TomMessage _webhook(TomNotificationRendering rendering) => TomMessage(
    id: rendering.messageId,
    channel: rendering.channel,
    recipients: rendering.addresses,
    subject: rendering.notification.type.name,
    bodies: [
      TomMessageBody(
        'application/json',
        jsonEncode({
          'type': rendering.notification.type.name,
          'id': rendering.notification.id,
          'parameters': rendering.notification.parameters,
        }, toEncodable: (value) => value.toString()),
      ),
    ],
    metadata: rendering.metadata,
  );

  String? _text(
    TomNotificationRendering rendering,
    String part, {
    bool required = false,
    bool channelOnly = false,
  }) => _lookup(
    '$keyPrefix.${rendering.notification.type.name}',
    rendering.channel,
    part,
    locale: rendering.recipient.locale,
    parameters: rendering.parameters,
    required: required,
    channelOnly: channelOnly,
    subject: rendering.notification.type.name,
  );

  String? _lookup(
    String base,
    TomMessageChannel channel,
    String part, {
    required TomTextLocale? locale,
    required Map<String, Object?> parameters,
    required String subject,
    bool required = false,
    bool channelOnly = false,
    List<String> extraKeys = const [],
  }) {
    final keys = [
      '$base.${channel.name}.$part',
      if (!channelOnly) '$base.$part',
      ...extraKeys,
    ];
    for (final key in keys) {
      final value = _resources.textOrNull(
        key,
        locale: locale,
        parameters: parameters,
      );
      if (value != null) return value;
    }
    if (!required) return null;
    throw TomNotificationException(
      'notifications.template.missing',
      "Notification '$subject' has no $part for ${channel.name}.",
      parameters: {
        'type': subject,
        'channel': channel.name,
        'resourceKeys': keys,
      },
    );
  }

  @override
  TomMessage renderDigest(TomNotificationDigestRendering rendering) {
    final channel = rendering.channel;
    if (channel == TomMessageChannel.webhook) {
      return TomMessage(
        id: rendering.messageId,
        channel: channel,
        recipients: rendering.addresses,
        subject: 'digest',
        bodies: [
          TomMessageBody(
            'application/json',
            jsonEncode({
              'digest': true,
              'items': [for (final item in rendering.items) item.toJson()],
            }, toEncodable: (value) => value.toString()),
          ),
        ],
        metadata: rendering.metadata,
      );
    }
    final lines = [
      for (final item in rendering.items)
        _lookup(
          '$keyPrefix.${item.type}',
          channel,
          'digestItem',
          locale: rendering.locale,
          parameters: {...item.parameters, ...rendering.recipientParameters},
          subject: item.type,
          required: true,
          extraKeys: [
            '$keyPrefix.${item.type}.${channel.name}.body',
            '$keyPrefix.${item.type}.body',
          ],
        )!,
    ];
    final parameters = {
      ...rendering.recipientParameters,
      'count': rendering.items.length,
      'items': lines.join('\n'),
    };
    final base = '$keyPrefix.digest';
    final subject = _lookup(
      base,
      channel,
      'subject',
      locale: rendering.locale,
      parameters: parameters,
      subject: 'digest',
    );
    final body = _lookup(
      base,
      channel,
      'body',
      locale: rendering.locale,
      parameters: parameters,
      subject: 'digest',
      required: true,
    )!;
    if (channel == TomMessageChannel.push) {
      return TomMessage.push(
        id: rendering.messageId,
        to: rendering.addresses,
        title: subject,
        body: body,
        metadata: rendering.metadata,
      );
    }
    return TomMessage(
      id: rendering.messageId,
      channel: channel,
      recipients: rendering.addresses,
      subject: channel == TomMessageChannel.sms ? null : subject,
      bodies: [TomMessageBody.text(body)],
      metadata: rendering.metadata,
    );
  }
}
