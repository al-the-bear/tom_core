/// Application email as a **template key plus parameters**.
///
/// ## Why there is a layer above the transport
///
/// [TomMessageTransport] answers "send these bytes to this address".
/// [TomEmailService] answers "send *the password-reset mail* to this user, in
/// their language". Without the second, every caller composes its own subject
/// and body — which puts user-facing text into Dart string literals, in direct
/// violation of the resource rule the rest of the framework keeps. The
/// transport being good makes this worse rather than better: it is attractive
/// enough to call directly, and every direct call site is a place the rule is
/// quietly broken.
///
/// So [TomEmailRequest] deliberately has **no subject and no body field**. It
/// names a template and supplies values. There is no way to spell a literal
/// subject through this API, which is the point — a rule the type system
/// enforces needs no reviewer to remember it.
///
/// ## The three sub-keys
///
/// A template key `email.password_reset` resolves three resources:
///
/// | Sub-key | Required | Becomes |
/// |---------|----------|---------|
/// | `.subject` | yes | the subject line |
/// | `.text` | yes | the `text/plain` body |
/// | `.html` | no | the `text/html` alternative |
///
/// The asymmetry is deliberate. Not every mail has markup, so a missing `.html`
/// is an ordinary template rather than a fault. But a mail with *no plain-text
/// part* is a deliverability problem — spam filters score it down and text-only
/// clients render nothing — so `.text` is required rather than merely
/// preferred, and a template that omits it fails loudly at send.
///
/// ## Loudly, and before anything is queued
///
/// A missing key raises [TomMessagingException] from [TomEmailService.render],
/// which runs *before* the message reaches the outbox. So a template nobody
/// wrote produces an error the caller sees, not a queued mail with an empty
/// subject that a recipient sees. This is the one place the framework
/// deliberately departs from [TomTextResourceProvider.getText]'s
/// key-as-fallback: a button reading `two_factor.enrol.submit` is ugly and gets
/// fixed, whereas a subject line reading `email.password_reset.subject` has
/// already been read by the user by the time anyone notices.
///
/// ## Always through the outbox
///
/// [send] hands the rendered message to a [TomMessageOutbox], never to a
/// transport. Retry, backoff, permanence classification, one-delivery-per-
/// message and failure alerting all already exist there, correctly, on the
/// kernel's job scheduler. A service that reached past it would either lose
/// mail on a transient relay failure or grow a second retry mechanism beside
/// the working one.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resources/localized_text_resources.dart';
import 'message.dart';
import 'outbox.dart';
import 'templated_message_service.dart';

/// What to send, to whom, and with which values — but never *what it says*.
///
/// ```dart
/// await emailService.send(TomEmailRequest.toPrincipal(
///   templateKey: 'email.password_reset',
///   principal: principal,
///   parameters: {'firstname': principal.user.firstname, 'link': resetUrl},
/// ));
/// ```
class TomEmailRequest {
  /// The resource key prefix the subject and bodies live under.
  final String templateKey;

  /// Who receives it. Copies and blind copies are expressed by the recipients'
  /// own [TomRecipientKind], as everywhere else in messaging.
  final List<TomRecipient> to;

  /// The locale to render in; `null` uses the bundle set's default.
  final TomTextLocale? locale;

  /// Values for the template's `{name}` placeholders.
  final Map<String, Object?> parameters;

  /// The sender, when this mail needs one of its own.
  ///
  /// Normally `null`: the deployment's default sender already lives in
  /// [TomSmtpSettings.defaultFrom] and is applied by the transport. Setting it
  /// here is for the mail that genuinely differs — a reply-to-able support
  /// thread, a per-tenant sending identity.
  final TomRecipient? from;

  /// Where replies should go, when that is not the sender.
  final TomRecipient? replyTo;

  /// Files to attach.
  final List<TomAttachment> attachments;

  /// Additional email headers.
  final Map<String, String>? headers;

  /// The message id, and therefore the **idempotence key**.
  ///
  /// The outbox derives its run id from it, so two sends of a request carrying
  /// the same id are one queued message. Supply one for anything a caller might
  /// retry without knowing whether the first attempt landed — a password reset
  /// keyed by its token, an invoice keyed by its number. Leave it `null` for a
  /// mail that is genuinely new each time, and a fresh id is generated.
  final String? messageId;

  /// Creates a request naming its recipients directly.
  TomEmailRequest({
    required this.templateKey,
    required this.to,
    this.locale,
    this.parameters = const {},
    this.from,
    this.replyTo,
    this.attachments = const [],
    this.headers,
    this.messageId,
  }) {
    if (templateKey.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.email.template.empty',
        'An email needs a template key.',
      );
    }
    if (to.isEmpty) {
      throw TomMessagingException(
        'messaging.email.recipients.empty',
        'An email needs at least one recipient.',
        parameters: {'templateKey': templateKey},
      );
    }
  }

  /// Creates a request addressed to [principal], in that principal's language.
  ///
  /// Derives three things the caller would otherwise re-derive at every send
  /// site — and would eventually get subtly different: the address from
  /// [TomUser.email], the display name from the user's names, and the locale
  /// from [TomTextLocale.fromPrincipal].
  ///
  /// A principal with no email address raises rather than producing a message
  /// with nowhere to go. That failure belongs here, at composition, where the
  /// caller still knows *which user* it was trying to reach; a transport
  /// discovering it later can only say that an address was empty.
  factory TomEmailRequest.toPrincipal({
    required String templateKey,
    required TomPrincipal principal,
    Map<String, Object?> parameters = const {},
    TomTextLocale? locale,
    TomRecipient? from,
    TomRecipient? replyTo,
    List<TomAttachment> attachments = const [],
    Map<String, String>? headers,
    String? messageId,
  }) {
    final address = principal.user.email;
    if (address == null || address.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.email.principal.no_address',
        'The user has no email address on record.',
        parameters: {
          'templateKey': templateKey,
          'username': principal.username,
        },
      );
    }
    final name = [
      principal.user.firstname,
      principal.user.lastname,
    ].whereType<String>().join(' ').trim();
    return TomEmailRequest(
      templateKey: templateKey,
      to: [TomRecipient(address, displayName: name.isEmpty ? null : name)],
      locale: locale ?? TomTextLocale.fromPrincipal(principal),
      parameters: parameters,
      from: from,
      replyTo: replyTo,
      attachments: attachments,
      headers: headers,
      messageId: messageId,
    );
  }
}

/// Renders resource-keyed email and queues it on the outbox.
///
/// ```dart
/// final emailService = TomEmailService(outbox: outbox, texts: texts);
/// TomBean.withType(TomEmailService, emailService);
/// ```
class TomEmailService extends TomTemplatedMessageService<TomEmailRequest> {
  /// The sub-key holding a template's subject line.
  static const String subjectSubKey = 'subject';

  /// The sub-key holding a template's plain-text body.
  static const String textSubKey = 'text';

  /// The sub-key holding a template's HTML body.
  static const String htmlSubKey = 'html';

  /// Creates the service over an [outbox] and a bundle set.
  const TomEmailService({required super.outbox, super.texts});

  @override
  String get channelName => 'email';

  /// The service this deployment installed, or `null`.
  ///
  /// Nullable with no fallback: a default would have to invent both an outbox
  /// and a bundle set, and mail sent through invented infrastructure goes
  /// nowhere while looking as though it went.
  static TomEmailService? resolve() {
    final installed = TomBean.getBeanByType(TomEmailService);
    return installed is TomEmailService ? installed : null;
  }

  /// Renders [request] into a message without queueing it.
  ///
  /// Resolves [subjectSubKey] and [textSubKey] as required, [htmlSubKey] as
  /// optional — the asymmetry the library dartdoc explains.
  @override
  TomMessage render(TomEmailRequest request) {
    final subject = requiredText(
      request.templateKey,
      subjectSubKey,
      locale: request.locale,
      parameters: request.parameters,
    );
    final text = requiredText(
      request.templateKey,
      textSubKey,
      locale: request.locale,
      parameters: request.parameters,
    );
    final html = texts.textOrNull(
      '${request.templateKey}.$htmlSubKey',
      locale: request.locale,
      parameters: request.parameters,
    );
    return TomMessage.email(
      id: request.messageId,
      from: request.from,
      replyTo: request.replyTo,
      to: request.to,
      subject: subject,
      text: text,
      html: html,
      attachments: request.attachments,
      headers: {..._contentLanguage(request.locale), ...?request.headers},
    );
  }

  /// The `Content-Language` header naming the locale this message was rendered
  /// **from**, or empty when there is none to name.
  ///
  /// Not the locale that was *asked for*. The fallback chain is per key, so a
  /// request for `de` against a half-translated bundle is served partly from
  /// `de` and partly from the default — and the bundle that answers is what
  /// [TomLocalizedTextResources.resolveLocale] reports. Echoing the request
  /// instead would put `de` on a message a recipient can see is English.
  ///
  /// Empty rather than a guess when the chain reaches no bundle at all — the
  /// wiring fault where the set carries nothing even for its own default
  /// locale. **Defensive rather than reachable from [render]**: a chain that
  /// reaches no bundle has no subject either, so `requiredText` refuses the
  /// message before this is asked. The branch is kept because the alternative
  /// is a `!` on a value whose null case the type states, and because a
  /// subclass rendering optional text alone could reach it. What it buys is
  /// the guarantee one level up — a message that exists never names a language
  /// it was not rendered in, since a message that could not be rendered does
  /// not exist.
  ///
  /// A `Content-Language` the caller supplied wins, because the spread below
  /// puts `request.headers` last — a deployment assembling one message from
  /// several bundles knows something this cannot.
  Map<String, String> _contentLanguage(TomTextLocale? locale) {
    final rendered = texts.resolveLocale(locale);
    return rendered == null
        ? const {}
        : {'Content-Language': rendered.tag.replaceAll('_', '-')};
  }
}
