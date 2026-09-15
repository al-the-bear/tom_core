/// Application SMS as a **template key plus parameters** — the email rule,
/// applied to the channel that also has a length.
///
/// ## What is the same
///
/// Everything structural. [TomSmsRequest] has no `text` field, for the reason
/// [TomEmailRequest] has no `subject` field: a request type that cannot express
/// a literal is a resource rule the compiler enforces. [TomSmsService] extends
/// the same [TomTemplatedMessageService] the email service does, so `send`,
/// `sendNow` and `requiredText` are not merely alike here — they are the same
/// code. That the base fitted the second channel without alteration is the
/// evidence that the shape was general rather than email-shaped.
///
/// ## What is different
///
/// One sub-key instead of three: an SMS has a body and nothing else, so
/// `<templateKey>.text` is the whole template. There is no subject to omit and
/// no HTML alternative to offer.
///
/// And a **length**. Nothing about composing an email tells the caller what it
/// will cost; an SMS is billed per 160-character segment (70 if one character
/// falls outside the GSM alphabet), and the arithmetic is not visible in the
/// template. A `{firstname}` that arrives as `Zoë` moves an entire message to
/// UCS-2 and triples its price. So:
///
/// - [TomSmsService.segmentationOf] renders and measures without sending, for a
///   preview screen or a test that wants to assert the cost of a template;
/// - [TomSmsService.maxSegments] refuses at *render*, before anything is
///   queued, so a message too long is a caller's error rather than a line on an
///   invoice.
///
/// The service cap is deliberately separate from
/// [TomSmsGatewaySettings.maxSegments]. The gateway one is a deployment's floor
/// and applies to every message that reaches the transport, including ones
/// composed elsewhere; this one is a composition-time bound an application can
/// set tighter for its own traffic — a two-factor code has no business being
/// two segments long, whatever the deployment permits in general.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resources/localized_text_resources.dart';
import 'message.dart';
import 'sms_transport.dart';
import 'templated_message_service.dart';

/// What to send, to which number, and with which values — but never *what it
/// says*.
///
/// ```dart
/// await smsService.send(TomSmsRequest.toPrincipal(
///   templateKey: 'sms.two_factor',
///   principal: principal,
///   parameters: {'code': code, 'minutes': 5},
///   messageId: 'two-factor-$challengeId',
/// ));
/// ```
class TomSmsRequest {
  /// The resource key prefix the text lives under.
  final String templateKey;

  /// The destination numbers.
  ///
  /// [TomRecipient.address] is a phone number here, which is what it was
  /// documented to be from the start. Copies are meaningless on this channel
  /// and the transport rejects them; a message to three people is three
  /// recipients, not one with two copies.
  final List<TomRecipient> to;

  /// The locale to render in; `null` uses the bundle set's default.
  final TomTextLocale? locale;

  /// Values for the template's `{name}` placeholders.
  final Map<String, Object?> parameters;

  /// The sender id shown on the handset, when this message needs one of its
  /// own.
  ///
  /// Normally `null`: the deployment's default lives in
  /// [TomSmsGatewaySettings.senderId]. Setting it here is for the message that
  /// genuinely differs — a per-tenant sending identity, a campaign short code.
  final String? from;

  /// The message id, and therefore the **idempotence key**.
  ///
  /// The outbox derives its run id from it, so two sends carrying the same id
  /// are one queued message. This matters more here than for mail: an SMS costs
  /// money per send, and the natural retry — a user pressing "resend code" —
  /// is exactly the case a caller should key.
  final String? messageId;

  /// Creates a request naming its numbers directly.
  TomSmsRequest({
    required this.templateKey,
    required this.to,
    this.locale,
    this.parameters = const {},
    this.from,
    this.messageId,
  }) {
    if (templateKey.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.sms.template.empty',
        'An SMS needs a template key.',
      );
    }
    if (to.isEmpty) {
      throw TomMessagingException(
        'messaging.sms.recipients.empty',
        'An SMS needs at least one recipient.',
        parameters: {'templateKey': templateKey},
      );
    }
  }

  /// Creates a request addressed to [principal], in that principal's language.
  ///
  /// Prefers [TomUser.mobile] and falls back to [TomUser.phone]. The fallback
  /// is worth having — many directories hold one number in whichever field the
  /// import happened to fill — and worth being ordered, because a landline that
  /// silently swallows a two-factor code is a support call nobody can diagnose.
  ///
  /// A principal reachable by neither raises here, at composition, where the
  /// caller still knows *which user* it was reaching; a transport discovering it
  /// later can only report that a number was empty.
  factory TomSmsRequest.toPrincipal({
    required String templateKey,
    required TomPrincipal principal,
    Map<String, Object?> parameters = const {},
    TomTextLocale? locale,
    String? from,
    String? messageId,
  }) {
    final number = _firstNonBlank([
      principal.user.mobile,
      principal.user.phone,
    ]);
    if (number == null) {
      throw TomMessagingException(
        'messaging.sms.principal.no_number',
        'The user has no mobile or phone number on record.',
        parameters: {
          'templateKey': templateKey,
          'username': principal.username,
        },
      );
    }
    return TomSmsRequest(
      templateKey: templateKey,
      to: [TomRecipient(number)],
      locale: locale ?? TomTextLocale.fromPrincipal(principal),
      parameters: parameters,
      from: from,
      messageId: messageId,
    );
  }

  static String? _firstNonBlank(List<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }
}

/// Renders resource-keyed SMS and queues it on the outbox.
///
/// ```dart
/// final smsService = TomSmsService(outbox: outbox, texts: texts);
/// TomBean.withType(TomSmsService, smsService);
/// ```
class TomSmsService extends TomTemplatedMessageService<TomSmsRequest> {
  /// The sub-key holding a template's text — the whole template, on this
  /// channel.
  static const String textSubKey = 'text';

  /// The most segments a message composed here may occupy, or `null` for no
  /// application-level cap.
  ///
  /// `null` by default rather than a number, because the deployment already has
  /// one in [TomSmsGatewaySettings.maxSegments] and two defaults that disagree
  /// is a message refused by whichever is stricter, reported by whichever the
  /// operator did not set.
  final int? maxSegments;

  /// Creates the service over an [outbox] and a bundle set.
  const TomSmsService({required super.outbox, super.texts, this.maxSegments});

  @override
  String get channelName => 'sms';

  /// The service this deployment installed, or `null`.
  ///
  /// Nullable with no fallback, for the reason [TomEmailService.resolve] is: a
  /// default would have to invent an outbox and a bundle set, and a message
  /// sent through invented infrastructure goes nowhere while looking as though
  /// it went.
  static TomSmsService? resolve() {
    final installed = TomBean.getBeanByType(TomSmsService);
    return installed is TomSmsService ? installed : null;
  }

  /// What [request] will cost, without sending or capping it.
  ///
  /// Renders the template and measures the result, so the answer accounts for
  /// the parameters — which is where the surprises live. Ignores [maxSegments]:
  /// this is the measurement a caller uses to *decide*, and a measurement that
  /// throws cannot be used to check whether it would.
  TomSmsSegmentation segmentationOf(TomSmsRequest request) =>
      TomSmsSegmentation.of(_textOf(request));

  /// Renders [request] into a message without queueing it.
  ///
  /// Where every fault surfaces: a template nobody wrote, and a message over
  /// [maxSegments]. Both before the outbox, so neither becomes a queued message
  /// somebody pays for.
  @override
  TomMessage render(TomSmsRequest request) {
    final text = _textOf(request);
    final segmentation = TomSmsSegmentation.of(text);
    final cap = maxSegments;
    if (cap != null && segmentation.segments > cap) {
      throw TomMessagingException(
        'messaging.sms.too_long',
        'The rendered SMS needs ${segmentation.segments} segments; this '
            'service allows $cap.',
        parameters: {
          'templateKey': request.templateKey,
          'segments': segmentation.segments,
          'maxSegments': cap,
          'encoding': segmentation.encoding.name,
          'units': segmentation.units,
        },
      );
    }
    return TomMessage.sms(
      id: request.messageId,
      to: request.to,
      text: text,
      senderId: request.from,
    );
  }

  String _textOf(TomSmsRequest request) => requiredText(
    request.templateKey,
    textSubKey,
    locale: request.locale,
    parameters: request.parameters,
  );
}
