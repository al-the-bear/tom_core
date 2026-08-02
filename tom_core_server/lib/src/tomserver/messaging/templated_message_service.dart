/// The rule every messaging channel shares: **a message is a template key plus
/// parameters**, never a literal.
///
/// ## Why this is a base rather than a convention
///
/// [TomEmailService] established the shape; the SMS service is the second
/// implementation of it. The parts that repeated are not incidental — they are
/// the rule itself: resolve through resource keys, fail loudly *before*
/// anything is queued, and hand the result to the outbox rather than to a
/// transport. A convention re-implemented per channel is a convention that
/// drifts, and the drift is invisible: a third channel that resolves through
/// [TomLocalizedTextResources.textOrNull] instead of [requiredText] silently
/// gains the key-as-fallback behaviour messaging deliberately does not want.
///
/// So the rule is a superclass, and the only thing a channel supplies is what
/// genuinely differs: its name and how one of its requests becomes a
/// [TomMessage].
///
/// ## What subclasses owe
///
/// | Member | Why it cannot be shared |
/// |--------|-------------------------|
/// | [channelName] | it names the channel's error keys, so a missing SMS template does not report itself as an email fault |
/// | [render] | the sub-keys and the message shape are the channel — an email has a subject and two bodies, an SMS has one text and a length budget |
///
/// Everything else — [send], [sendNow], [requiredText] — is the same code for
/// every channel, and staying that way is the point.
library;

import '../resources/localized_text_resources.dart';
import 'message.dart';
import 'outbox.dart';

/// Renders resource-keyed messages of one channel and queues them on the
/// outbox.
///
/// [R] is the channel's request type — [TomEmailRequest] for mail,
/// [TomSmsRequest] for SMS. A request type that has no field for user-facing
/// text is what makes the rule enforceable by the compiler rather than by a
/// reviewer.
abstract class TomTemplatedMessageService<R> {
  /// Where rendered messages are queued.
  ///
  /// Not owned: [TomMessageOutbox.close] is the application's to call, because
  /// one outbox usually carries every channel's traffic.
  final TomMessageOutbox outbox;

  /// The bundle set every template is resolved against.
  final TomLocalizedTextResources texts;

  /// Creates the service over an [outbox] and a bundle set.
  const TomTemplatedMessageService({required this.outbox, required this.texts});

  /// The channel's name as it appears in this service's error keys — `email`,
  /// `sms`.
  ///
  /// The keys are user-visible in the sense that operators read them, and a
  /// missing SMS template reporting `messaging.email.template.missing` sends
  /// whoever is on call to the wrong bundle.
  String get channelName;

  /// Renders [request] into a message without queueing it.
  ///
  /// Separate from [send] so that a caller can preview what will be sent — a
  /// test, an admin "show me this template" screen, a digest that renders many
  /// and queues one. It is also where every template fault surfaces, which is
  /// why [send] calls it before touching the queue.
  TomMessage render(R request);

  /// Renders [request] and queues it. Returns once it is durably stored.
  ///
  /// `async` rather than a bare forwarding expression so that a template fault
  /// arrives as a failed future, matching every other failure this call can
  /// produce; a synchronous throw from an otherwise-asynchronous API is a trap
  /// for callers that only guard the `await`.
  Future<void> send(R request) async => outbox.send(render(request));

  /// Renders [request], queues it, and delivers immediately.
  ///
  /// For a message a human is waiting on — a password reset, a one-time code —
  /// where the outbox's tick interval is felt. Retry behaviour is unchanged:
  /// only the first attempt skips the wait.
  Future<void> sendNow(R request) async => outbox.sendNow(render(request));

  /// Resolves `<templateKey>.<subKey>`, or explains precisely what is missing.
  ///
  /// Used internally for each channel's required sub-keys, and public for the
  /// **conditional fragment**: a body that mentions an overdue count only when
  /// there is one cannot express that in a single template, so it resolves the
  /// optional sentence separately and passes the result as a parameter. Doing
  /// that through this method rather than [TomLocalizedTextResources.textOrNull]
  /// keeps one failure mode for one class of fault — a fragment nobody wrote
  /// fails the send, naming the key, exactly as a missing subject does.
  ///
  /// Resolve fragments **fully** before passing them in. Substitution is a
  /// single pass over the parameter map, so a fragment inserted with its own
  /// placeholders still in it would be substituted or not depending on map
  /// order.
  String requiredText(
    String templateKey,
    String subKey, {
    TomTextLocale? locale,
    Map<String, Object?> parameters = const {},
  }) {
    final key = '$templateKey.$subKey';
    final value = texts.textOrNull(key, locale: locale, parameters: parameters);
    if (value == null) {
      throw TomMessagingException(
        'messaging.$channelName.template.missing',
        'The $channelName template has no $subKey.',
        parameters: {
          'templateKey': templateKey,
          'resourceKey': key,
          'locale': (locale ?? texts.defaultLocale).tag,
        },
      );
    }
    return value;
  }
}
