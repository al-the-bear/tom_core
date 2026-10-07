/// Application push notifications as a **template key plus parameters** — the
/// rule [TomEmailService] and [TomSmsService] follow, on a third channel.
///
/// ## Its own sub-keys, not a generalised service
///
/// [TomPushService] extends [TomTemplatedMessageService] directly with its own
/// sub-key set, `title` and `body`, as that base class asks of every channel.
/// It is not a parameterised email service: a notification has a title where a
/// mail has a subject, but no HTML alternative and no attachments, and its
/// request carries a data map no other channel has.
///
/// Both sub-keys are required, as a mail's subject and text are. A notification
/// with no title renders as the app's name above the body on most devices,
/// which is a choice a template should make visibly — by being written — rather
/// than one a missing key makes silently.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resources/localized_text_resources.dart';
import 'message.dart';
import 'templated_message_service.dart';

/// What to send, to which devices, and with which values — but never *what it
/// says*.
///
/// ```dart
/// await pushService.send(TomPushRequest(
///   templateKey: 'push.task_assigned',
///   to: [for (final token in deviceTokensOf(user)) TomRecipient(token)],
///   locale: TomTextLocale.fromPrincipal(principal),
///   parameters: {'task': task.title},
///   data: {'taskId': task.id},
/// ));
/// ```
///
/// There is no `toPrincipal` factory, unlike [TomSmsRequest]: a user's device
/// tokens are registered by the app, one per installation, and the framework
/// keeps no register of them.
class TomPushRequest {
  /// The resource key prefix the title and body live under.
  final String templateKey;

  /// The device tokens, one [TomRecipient] each.
  final List<TomRecipient> to;

  /// The locale to render in; `null` uses the bundle set's default.
  final TomTextLocale? locale;

  /// Values for the template's `{name}` placeholders.
  final Map<String, Object?> parameters;

  /// Key/value pairs handed to the app with the notification — an id to open,
  /// never text to show.
  final Map<String, String> data;

  /// The message id, and therefore the **idempotence key** the outbox
  /// deduplicates on.
  final String? messageId;

  /// Creates a request.
  TomPushRequest({
    required this.templateKey,
    required this.to,
    this.locale,
    this.parameters = const {},
    this.data = const {},
    this.messageId,
  }) {
    if (templateKey.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.push.template.empty',
        'A push notification needs a template key.',
      );
    }
    if (to.isEmpty) {
      throw TomMessagingException(
        'messaging.push.recipients.empty',
        'A push notification needs at least one device token.',
        parameters: {'templateKey': templateKey},
      );
    }
  }
}

/// Renders resource-keyed push notifications and queues them on the outbox.
///
/// ```dart
/// final pushService = TomPushService(outbox: outbox, texts: texts);
/// TomBean.withType<TomPushService>(pushService);
/// ```
class TomPushService extends TomTemplatedMessageService<TomPushRequest> {
  /// The sub-key holding a template's title.
  static const String titleSubKey = 'title';

  /// The sub-key holding a template's body.
  static const String bodySubKey = 'body';

  /// Creates the service over an [outbox] and a bundle set.
  const TomPushService({required super.outbox, super.texts});

  @override
  String get channelName => 'push';

  /// The service this deployment installed, or `null`.
  ///
  /// Nullable with no fallback, for the reason [TomEmailService.resolve] is.
  static TomPushService? resolve() {
    final installed = TomBean.getBeanByType(TomPushService);
    return installed is TomPushService ? installed : null;
  }

  /// Renders [request] into a message without queueing it; a missing title or
  /// body fails here, before anything is queued.
  @override
  TomMessage render(TomPushRequest request) => TomMessage.push(
    id: request.messageId,
    to: request.to,
    title: requiredText(
      request.templateKey,
      titleSubKey,
      locale: request.locale,
      parameters: request.parameters,
    ),
    body: requiredText(
      request.templateKey,
      bodySubKey,
      locale: request.locale,
      parameters: request.parameters,
    ),
    data: request.data,
  );
}
