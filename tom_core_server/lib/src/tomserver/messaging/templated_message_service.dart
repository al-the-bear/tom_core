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
///
/// ## One subclass per channel, never a generalised one
///
/// A third channel extends this class with its own sub-key set. It does **not**
/// generalise [TomEmailService] or [TomSmsService], and the instruction is
/// worth writing down because the tempting refactor is exactly the wrong one:
/// the two differ only in their sub-keys (`subject`/`text`/`html` against
/// `text`) and in the message each builds, so a "generalised" service would
/// parameterise precisely the thing that distinguishes one channel from
/// another, leave the shared part exactly as shared as it already is, and cost
/// the compiler its ability to say that a [TomEmailRequest] has no text field
/// to write a literal into.
///
/// Not every channel wants one. A webhook's payload is `TomMessage.toJson()`
/// and its recipient is a program, so there is no user-facing prose to resolve
/// and no locale to resolve it in — see "Not in This Framework" in
/// `doc/messaging.md`.
library;

import '../resources/localized_text_resources.dart';
import 'message.dart';
import 'message_transport.dart';
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

  /// The bundle set passed to the constructor, or `null` to use the installed
  /// one.
  final TomLocalizedTextResources? _texts;

  /// The bundle set every template is resolved against: the one this service
  /// was given, else the one the deployment installed as a bean.
  ///
  /// Resolved per call rather than at construction, which is what lets a
  /// service be built before the bundles are loaded — a bootstrap that
  /// constructs its services and *then* reads its resource files off disk is
  /// the ordinary shape, and an eagerly resolved field would make that order
  /// wrong for no reason a caller could see.
  ///
  /// **Throws rather than rendering without text.** With neither a passed set
  /// nor an installed one there is nothing to resolve a template against, and
  /// the alternatives are both worse: an empty set would send every message
  /// blank, and a blank message that was *sent* cannot be recalled, while
  /// falling back to the key would put `email.invoice.subject` in front of a
  /// recipient. The same argument [TomLocalizedTextResources.resolve] makes for
  /// answering `null` instead of an empty set.
  TomLocalizedTextResources get texts =>
      _texts ??
      TomLocalizedTextResources.resolve() ??
      (throw TomMessagingException(
        'messaging.$channelName.texts.not_configured',
        'The $channelName service has no bundle set: none was passed to it and '
            'no TomLocalizedTextResources bean is installed.',
        parameters: {'channel': channelName},
      ));

  /// Creates the service over an [outbox] and, optionally, a bundle set.
  ///
  /// [texts] is an **override**. Leave it out and the service reads the
  /// installed [TomLocalizedTextResources] bean, which is how a deployment
  /// wires one bundle set into every channel; pass one to give this service
  /// its own — a test with a fixture bundle, or a second service rendering
  /// from a different set.
  const TomTemplatedMessageService({
    required this.outbox,
    TomLocalizedTextResources? texts,
  }) : _texts = texts;

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

  /// Renders [request] and delivers it **now, reporting the outcome** — no
  /// queue, no retry.
  ///
  /// The deliberate exception to "always through the outbox", for the one class
  /// of message the outbox's guarantees do not fit: a payload whose value
  /// expires before the retry budget would, and whose non-arrival the caller
  /// must therefore learn about *now*. A second-factor code is the case this
  /// exists for — it is worthless ten minutes later, and a user waiting for one
  /// that was never sent cannot tell that from a slow relay.
  ///
  /// The trade is explicit: [send] and [sendNow] cannot fail for a transport
  /// reason (they hand that to the queue, which retries and alerts), and this
  /// one can and will. A caller that wants durability wants [sendNow]; a caller
  /// that wants the truth about the first attempt wants this.
  ///
  /// Returns the transport's own receipt, so a caller can see a partial
  /// delivery — some recipients accepted, others refused — which is neither a
  /// success nor a throw.
  Future<TomDeliveryReceipt> deliverNow(R request) =>
      outbox.router.send(render(request));

  /// The template key the list separators are resolved under.
  ///
  /// One well-known key rather than a per-template one, because a list's
  /// punctuation is a fact about the *language* and not about the mail: every
  /// template in a bundle joins a list the same way, and a per-template copy
  /// would be the same two strings written once per template for a translator
  /// to keep in step.
  static const String listTemplateKey = 'messaging.list';

  /// The sub-key holding what goes between all but the last two items.
  static const String listSeparatorSubKey = 'separator';

  /// The sub-key holding what goes between the last two.
  static const String listLastSeparatorSubKey = 'last';

  /// Joins [items] into one string using the separators the bundle gives for
  /// [locale].
  ///
  /// The answer to the other half of "a template has no control flow". A
  /// conditional sentence is a fragment resolved separately — see
  /// [requiredText] — and a *list* is this: a caller with three overdue tasks
  /// renders "Alpha, Beta and Gamma" without the separator or the conjunction
  /// being written in Dart.
  ///
  /// ```yaml
  /// messaging:
  ///   list:
  ///     separator: ", "
  ///     last: " and "
  /// ```
  ///
  /// **The separators come from the bundle and have no default.** `", "` and
  /// `" and "` are English, and a framework that routes every user-facing
  /// string through a bundle cannot make these the two it writes in Dart —
  /// German wants `" und "`, French `" et "`, and a locale that draws no
  /// distinction sets both keys to the same value. A bundle missing them fails
  /// the send naming the key, exactly as a missing subject does.
  ///
  /// They are resolved **only when they are needed**, so a deployment that
  /// never joins more than one item never has to supply them, and one that does
  /// finds out on the first two-item list rather than at start-up. That is the
  /// same moment any optional fragment is discovered, and it is still before
  /// anything is queued.
  ///
  /// An **empty** list is the empty string rather than a failure. A caller that
  /// needs "you have nothing outstanding" is in the conditional case, not the
  /// list case, and renders that sentence as its own key.
  ///
  /// Resolve the items **fully** before passing them in, for the reason
  /// [requiredText] gives: this joins strings and substitutes nothing, so an
  /// item that still carries a placeholder keeps it.
  String requiredList(Iterable<String> items, {TomTextLocale? locale}) {
    final parts = items.toList(growable: false);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    final last = requiredText(
      listTemplateKey,
      listLastSeparatorSubKey,
      locale: locale,
    );
    if (parts.length == 2) return '${parts.first}$last${parts.last}';
    final separator = requiredText(
      listTemplateKey,
      listSeparatorSubKey,
      locale: locale,
    );
    return '${parts.sublist(0, parts.length - 1).join(separator)}'
        '$last${parts.last}';
  }

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
