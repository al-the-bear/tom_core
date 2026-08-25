/// SMS delivery: the segment arithmetic, the gateway mapping, and the failure
/// classification that drives every retry decision downstream.
///
/// ## What SMS needs from the shared shape
///
/// Nothing of its own. [TomSmsTransport] is an ordinary
/// [TomMessageTransport]: it takes the same [TomMessage] and returns the same
/// [TomDeliveryReceipt] as SMTP, and the channel's peculiarities are carried by
/// fields the shared types already have. [TomRecipient.address] is a phone
/// number here rather than a mailbox, [TomMessage.metadata] carries the sender
/// id, and the base's `supportsCopies`/`supportsAttachments` defaults of
/// `false` are the right answer for a channel with neither. A second channel
/// that fits without widening the contract is the evidence that the contract is
/// about delivery rather than about email.
///
/// ## The classification rule
///
/// The transport's *one* judgement is whether a failure is worth repeating.
/// SMS makes that harder than SMTP, because an SMS gateway answers on two
/// levels and they routinely disagree: an HTTP `200 OK` carrying
/// `{"status":"failed","code":21211}` is an accepted *request* and a refused
/// *message*. So the rule here has two layers:
///
/// | Layer | Owner | Rule |
/// |-------|-------|------|
/// | HTTP status | this file | `408`, `425`, `429` and `5xx` are transient; every other non-`2xx` is permanent |
/// | provider payload | the deployment's [TomSmsGatewayProtocol] | named codes are classified explicitly; an unrecognised code defers to the layer above |
///
/// The second layer is configuration rather than code because the codes are a
/// vendor's, not a protocol's, and a constant that hardcodes one vendor's
/// numbering is a constant that starts lying the day the vendor renumbers.
///
/// ## No vendor presets
///
/// [TomFieldMappedSmsProtocol] can express the common gateways — field names,
/// body format, response paths, error codes — but this file ships no
/// `TomTwilioProtocol` or `TomVonageProtocol`. A preset for an API this
/// repository cannot test against would be a plausible-looking guess that fails
/// in production, and the failure would be attributed to the framework rather
/// than to the guess. `doc/messaging.md` shows how to configure one instead.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import 'message.dart';
import 'message_transport.dart';

// =============================================================================
// SEGMENTATION
// =============================================================================

/// The alphabet a message will be encoded in on the wire.
enum TomSmsEncoding {
  /// The GSM 03.38 7-bit alphabet: 160 units in a single message.
  gsm7,

  /// UTF-16, used as soon as one character falls outside GSM 03.38: 70 units.
  ucs2,
}

/// How long a message is in the unit that is actually billed.
///
/// Characters are the wrong unit and every SMS integration that counts them
/// eventually discovers why. Three rules make the count differ from
/// `text.length`:
///
/// 1. one character outside the GSM alphabet moves the **whole message** to
///    UCS-2, cutting capacity from 160 to 70;
/// 2. ten GSM characters — `^ { } \ [ ~ ] |`, form feed and `€` — live in an
///    escape table and cost **two** units each;
/// 3. a message that does not fit one part is split, and each part spends seven
///    bits on a concatenation header, so capacity drops to 153 (GSM) or 67
///    (UCS-2) *per part* — which means the 161st character adds a second
///    segment holding eight characters, not one.
///
/// A character never straddles a segment boundary, so the packing here is
/// greedy rather than a division: an 81-character message of `€` is two
/// segments because the 77th euro sign would cross 153.
class TomSmsSegmentation {
  /// The alphabet the message needs.
  final TomSmsEncoding encoding;

  /// The billable length in [encoding]'s units.
  final int units;

  /// How many messages the gateway will send, and charge for.
  final int segments;

  const TomSmsSegmentation._(this.encoding, this.units, this.segments);

  /// Measures [text].
  factory TomSmsSegmentation.of(String text) {
    final runes = text.runes.toList(growable: false);
    final isGsm = runes.every(
      (r) =>
          _gsm7Basic.contains(String.fromCharCode(r)) ||
          _gsm7Extension.contains(String.fromCharCode(r)),
    );
    final encoding = isGsm ? TomSmsEncoding.gsm7 : TomSmsEncoding.ucs2;
    final costs = runes
        .map(
          (r) => isGsm
              ? (_gsm7Extension.contains(String.fromCharCode(r)) ? 2 : 1)
              // Outside the BMP a rune is a surrogate pair, and the pair is
              // what goes on the wire and onto the bill.
              : (r > 0xFFFF ? 2 : 1),
        )
        .toList(growable: false);
    final units = costs.fold<int>(0, (sum, cost) => sum + cost);
    return TomSmsSegmentation._(
      encoding,
      units,
      _pack(
        costs,
        units,
        _singleCapacityOf(encoding),
        _partCapacityOf(encoding),
      ),
    );
  }

  /// How many units fit when the message is a single part.
  int get singleCapacity => _singleCapacityOf(encoding);

  /// How many units fit in each part of a concatenated message.
  int get partCapacity => _partCapacityOf(encoding);

  /// Whether the message will be split.
  bool get isMultipart => segments > 1;

  static int _singleCapacityOf(TomSmsEncoding encoding) =>
      encoding == TomSmsEncoding.gsm7 ? 160 : 70;

  static int _partCapacityOf(TomSmsEncoding encoding) =>
      encoding == TomSmsEncoding.gsm7 ? 153 : 67;

  static int _pack(List<int> costs, int units, int single, int part) {
    if (units <= single) return 1;
    var segments = 1;
    var used = 0;
    for (final cost in costs) {
      if (used + cost > part) {
        segments++;
        used = 0;
      }
      used += cost;
    }
    return segments;
  }

  @override
  String toString() =>
      'TomSmsSegmentation(${encoding.name}, $units units, $segments segment(s))';

  /// The GSM 03.38 basic alphabet, minus the escape character itself.
  static const String _gsm7Basic =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ'
      ' !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§'
      '¿abcdefghijklmnopqrstuvwxyzäöñüà';

  /// The escape table: two units each, and the most commonly missed detail in
  /// an SMS length calculation.
  static const String _gsm7Extension = '\f^{}\\[~]|€';
}

// =============================================================================
// SETTINGS
// =============================================================================

/// How the gateway credential is presented.
enum TomSmsAuthScheme {
  /// No credential in the transport layer; the gateway takes it in the payload
  /// (see [TomFieldMappedSmsProtocol.apiKeyField]) or not at all.
  none,

  /// `Authorization: Bearer <apiKey>`.
  bearer,

  /// `Authorization: Basic base64(apiKey:apiSecret)`.
  basic,
}

/// Everything needed to reach one SMS gateway.
///
/// Separate from the transport for the same reason [TomSmtpSettings] is: it can
/// be built from [TomBaseServerConfiguration] without the transport knowing
/// about configuration, and built literally in a test without a configuration
/// existing at all.
class TomSmsGatewaySettings {
  /// The gateway's submission URL.
  final Uri endpoint;

  /// The account identifier or API key — **secret-bearing**, never authored.
  final String? apiKey;

  /// The API secret, for gateways whose credential is a pair.
  final String? apiSecret;

  /// The sender shown on the handset — a short code, a long number, or an
  /// alphanumeric id — used when a message does not name its own.
  final String? senderId;

  /// How [apiKey] and [apiSecret] are presented.
  final TomSmsAuthScheme authScheme;

  /// How long to wait for the gateway to answer.
  final Duration timeout;

  /// The most segments a single message may be split into; `0` means no cap.
  ///
  /// A cap rather than a warning because the cost is linear and silent: a
  /// template that grew by one sentence turns every message it sends into three
  /// billed messages, and nothing in a green test run says so.
  final int maxSegments;

  /// Creates gateway settings.
  TomSmsGatewaySettings({
    required this.endpoint,
    this.apiKey,
    this.apiSecret,
    this.senderId,
    this.authScheme = TomSmsAuthScheme.bearer,
    this.timeout = const Duration(seconds: 30),
    this.maxSegments = 3,
  }) {
    if (!endpoint.isScheme('http') && !endpoint.isScheme('https')) {
      throw TomMessagingException(
        'messaging.sms.bad_endpoint',
        'The SMS gateway endpoint must be an http or https URL.',
        parameters: {'endpoint': endpoint.toString()},
      );
    }
    if (authScheme == TomSmsAuthScheme.basic &&
        (apiKey == null || apiSecret == null)) {
      // Caught here rather than at the first send, so a deployment that forgot
      // half its credential fails at startup naming the setting.
      throw TomMessagingException(
        'messaging.sms.incomplete_credential',
        'Basic authentication needs both smsApiKey and smsApiSecret.',
        parameters: {'endpoint': endpoint.toString()},
      );
    }
  }

  /// Reads settings from a server configuration's `sms*` fields.
  ///
  /// Returns `null` when [TomBaseServerConfiguration.smsEndpoint] is unset,
  /// which is how a deployment says "no SMS" — the caller registers a
  /// [TomNoOpMessageTransport] instead of failing to start. An endpoint that is
  /// set but unusable is the opposite case and does throw: someone meant to
  /// send.
  static TomSmsGatewaySettings? fromConfiguration(
    TomBaseServerConfiguration configuration,
  ) {
    final endpoint = configuration.smsEndpoint;
    if (endpoint == null || endpoint.trim().isEmpty) return null;
    final Uri url;
    try {
      url = Uri.parse(endpoint.trim());
    } on FormatException catch (error, stack) {
      throw TomMessagingException(
        'messaging.sms.bad_endpoint',
        'smsEndpoint is not a URL.',
        parameters: {'endpoint': endpoint},
        rootException: error,
        stack: stack,
      );
    }
    return TomSmsGatewaySettings(
      endpoint: url,
      apiKey: _blankToNull(configuration.smsApiKey),
      apiSecret: _blankToNull(configuration.smsApiSecret),
      senderId: _blankToNull(configuration.smsSenderId),
      authScheme: TomSmsAuthScheme.values.firstWhere(
        (s) =>
            s.name.toLowerCase() == configuration.smsAuthScheme.toLowerCase(),
        // Bearer rather than `none`: an unrecognised value must not silently
        // drop the credential and send unauthenticated requests to a paid API.
        orElse: () => TomSmsAuthScheme.bearer,
      ),
      timeout: Duration(seconds: configuration.smsTimeoutSeconds),
      maxSegments: configuration.smsMaxSegments,
    );
  }

  static String? _blankToNull(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  /// A description safe to log. The credential is never included, at any level.
  @override
  String toString() =>
      'TomSmsGatewaySettings(${endpoint.host}${endpoint.path}, '
      '${authScheme.name}'
      '${senderId == null ? '' : ', as $senderId'})';
}

// =============================================================================
// PROTOCOL
// =============================================================================

/// One message to one number, measured and ready to encode.
class TomSmsSubmission {
  /// The [TomMessage.id] this submission belongs to.
  final String messageId;

  /// The destination number.
  final String to;

  /// The sender id, or `null` when the gateway supplies one.
  final String? from;

  /// The text to send.
  final String text;

  /// What it will cost.
  final TomSmsSegmentation segmentation;

  /// Creates a submission.
  const TomSmsSubmission({
    required this.messageId,
    required this.to,
    required this.text,
    required this.segmentation,
    this.from,
  });
}

/// Which body encoding the gateway expects.
enum TomSmsBodyFormat {
  /// `application/x-www-form-urlencoded`.
  form,

  /// `application/json`.
  json,
}

/// One HTTP request to a gateway, before it becomes a kernel server call.
///
/// A value rather than a call, so [TomSmsGatewayProtocol.encode] stays a pure
/// function and can be asserted on without a client.
class TomSmsGatewayRequest {
  /// Where to send it.
  final Uri url;

  /// The HTTP method.
  final String method;

  /// The headers, including any credential.
  final Map<String, String> headers;

  /// The body, for [TomSmsBodyFormat.json].
  final String? body;

  /// The body, for [TomSmsBodyFormat.form]. Exactly one of this and [body] is
  /// set.
  final Map<String, String>? fields;

  /// Creates a gateway request.
  const TomSmsGatewayRequest({
    required this.url,
    this.method = 'POST',
    this.headers = const {},
    this.body,
    this.fields,
  });
}

/// What a gateway said, in the only terms the outbox cares about.
class TomSmsGatewayAnswer {
  /// Whether the gateway took the message.
  final bool isAccepted;

  /// The gateway's own id for it, for correlation with a delivery report.
  final String? remoteId;

  /// A human-readable explanation, for the receipt and the alert.
  final String? detail;

  /// Whether a refusal is final.
  ///
  /// `null` means "the payload did not say" — the transport then falls back to
  /// the HTTP status. Deliberately three-valued: a protocol that had to guess
  /// would guess *permanent* for an unknown code and turn a rate limit into a
  /// lost message, or guess *transient* and spend a retry budget on an invalid
  /// number.
  final bool? isPermanent;

  /// The vendor's error code, as written.
  final String? providerCode;

  /// Creates an answer.
  const TomSmsGatewayAnswer({
    required this.isAccepted,
    this.remoteId,
    this.detail,
    this.isPermanent,
    this.providerCode,
  });

  /// The gateway took the message.
  const TomSmsGatewayAnswer.accepted({this.remoteId, this.detail})
    : isAccepted = true,
      isPermanent = null,
      providerCode = null;

  /// The gateway refused it. [permanent] `null` defers to the HTTP status.
  ///
  /// [permanent] keeps its own name rather than becoming an initialising formal
  /// for [isPermanent]: at a call site `permanent: true` reads as the caller's
  /// claim about this refusal, which is what a rejection is being told.
  const TomSmsGatewayAnswer.rejected({
    bool? permanent,
    this.detail,
    this.providerCode,
  }) : isAccepted = false,
       remoteId = null,
       isPermanent = permanent;

  @override
  String toString() =>
      'TomSmsGatewayAnswer(${isAccepted ? 'accepted' : 'rejected'}'
      '${providerCode == null ? '' : ', code $providerCode'})';
}

/// Turns a submission into a gateway request and an answer back into a
/// judgement.
///
/// The whole vendor surface lives behind these two methods, which is where the
/// module draws its boundary: provider specifics are confined to the transport,
/// and within the transport to the protocol. Nothing above [TomSmsTransport]
/// names a gateway's field, and nothing beside it has to.
abstract class TomSmsGatewayProtocol {
  /// Creates a protocol.
  const TomSmsGatewayProtocol();

  /// Whether the gateway requires a sender id on every submission.
  ///
  /// Deployments differ: a short-code account has one sender and rejects the
  /// field, an alphanumeric-sender account requires it. Saying so here lets the
  /// transport fail at composition rather than posting a request it knows will
  /// be refused.
  bool get requiresSender => false;

  /// Builds the request for one message to one number.
  TomSmsGatewayRequest encode(
    TomSmsSubmission submission,
    TomSmsGatewaySettings settings,
  );

  /// Reads the gateway's answer.
  ///
  /// [statusCode] is supplied so a protocol can use it, not so it must: the
  /// transport applies its own status rule to anything this leaves undecided.
  TomSmsGatewayAnswer decode(int statusCode, String body);

  /// The `Authorization` header for [settings], or nothing.
  ///
  /// Provided here rather than in the concrete protocol so that a deployment
  /// writing its own protocol for an unusual gateway inherits the credential
  /// handling instead of re-deriving base64.
  Map<String, String> authorizationHeaders(TomSmsGatewaySettings settings) {
    switch (settings.authScheme) {
      case TomSmsAuthScheme.none:
        return const {};
      case TomSmsAuthScheme.bearer:
        final key = settings.apiKey;
        return key == null ? const {} : {'Authorization': 'Bearer $key'};
      case TomSmsAuthScheme.basic:
        final pair = '${settings.apiKey}:${settings.apiSecret}';
        return {'Authorization': 'Basic ${base64.encode(utf8.encode(pair))}'};
    }
  }
}

/// A protocol described by field names and response paths rather than by code.
///
/// Enough to reach the common HTTP gateways, all of which do the same thing in
/// different words: post a destination, a sender and a body; read back an id
/// and a status; report failures as codes. Naming those words in configuration
/// rather than in a subclass per vendor is what keeps the transport free of
/// vendor names — see the library dartdoc on why no presets ship.
///
/// ```dart
/// TomFieldMappedSmsProtocol(
///   format: TomSmsBodyFormat.form,
///   toField: 'To',
///   fromField: 'From',
///   textField: 'Body',
///   statusPath: 'status',
///   acceptedStatuses: {'queued', 'accepted', 'sending', 'sent'},
///   remoteIdPath: 'sid',
///   errorCodePath: 'code',
///   errorMessagePath: 'message',
///   permanentErrorCodes: {'21211', '21610', '21614'},
///   transientErrorCodes: {'20429', '30001'},
/// )
/// ```
class TomFieldMappedSmsProtocol extends TomSmsGatewayProtocol {
  /// How the body is encoded.
  final TomSmsBodyFormat format;

  /// The HTTP method.
  final String method;

  /// The field carrying the destination number.
  final String toField;

  /// The field carrying the sender id, or `null` when the gateway has none.
  final String? fromField;

  /// The field carrying the message text.
  final String textField;

  /// The field carrying [TomSmsGatewaySettings.apiKey], for gateways that take
  /// the credential in the payload rather than in a header.
  final String? apiKeyField;

  /// The field carrying [TomSmsGatewaySettings.apiSecret], likewise.
  final String? apiSecretField;

  /// Constant fields every submission carries — a route class, an account sid,
  /// a callback URL.
  final Map<String, String> extraFields;

  @override
  final bool requiresSender;

  /// The dotted path to the status value, or `null` to trust the HTTP status.
  final String? statusPath;

  /// The status values that mean "taken", compared case-insensitively.
  final Set<String> acceptedStatuses;

  /// The dotted path to the gateway's message id.
  final String? remoteIdPath;

  /// The dotted path to the error code.
  final String? errorCodePath;

  /// The dotted path to the error message.
  final String? errorMessagePath;

  /// Error codes that mean "never going to work".
  final Set<String> permanentErrorCodes;

  /// Error codes that mean "not right now".
  final Set<String> transientErrorCodes;

  /// Creates a field-mapped protocol.
  const TomFieldMappedSmsProtocol({
    this.format = TomSmsBodyFormat.form,
    this.method = 'POST',
    this.toField = 'to',
    this.fromField = 'from',
    this.textField = 'text',
    this.apiKeyField,
    this.apiSecretField,
    this.extraFields = const {},
    this.requiresSender = false,
    this.statusPath,
    this.acceptedStatuses = const {},
    this.remoteIdPath,
    this.errorCodePath,
    this.errorMessagePath,
    this.permanentErrorCodes = const {},
    this.transientErrorCodes = const {},
  });

  @override
  TomSmsGatewayRequest encode(
    TomSmsSubmission submission,
    TomSmsGatewaySettings settings,
  ) {
    final fields = <String, String>{
      ...extraFields,
      toField: submission.to,
      if (fromField != null && submission.from != null)
        fromField!: submission.from!,
      textField: submission.text,
      if (apiKeyField != null && settings.apiKey != null)
        apiKeyField!: settings.apiKey!,
      if (apiSecretField != null && settings.apiSecret != null)
        apiSecretField!: settings.apiSecret!,
    };
    final headers = <String, String>{...authorizationHeaders(settings)};
    if (format == TomSmsBodyFormat.json) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
      return TomSmsGatewayRequest(
        url: settings.endpoint,
        method: method,
        headers: headers,
        body: jsonEncode(fields),
      );
    }
    return TomSmsGatewayRequest(
      url: settings.endpoint,
      method: method,
      headers: headers,
      fields: fields,
    );
  }

  @override
  TomSmsGatewayAnswer decode(int statusCode, String body) {
    final json = _decodeOrNull(body);
    final code = _stringAt(json, errorCodePath);
    final detail =
        _stringAt(json, errorMessagePath) ??
        (body.trim().isEmpty ? null : _clip(body));
    final httpOk = statusCode >= 200 && statusCode < 300;

    final bool accepted;
    if (statusPath == null) {
      accepted = httpOk;
    } else {
      final status = _stringAt(json, statusPath);
      // A configured status path that does not resolve is not a success. The
      // gateway promised to say something and did not, and treating silence as
      // acceptance is how a maintenance page becomes a delivered message.
      accepted =
          httpOk &&
          status != null &&
          acceptedStatuses.any((a) => a.toLowerCase() == status.toLowerCase());
    }

    if (accepted) {
      return TomSmsGatewayAnswer.accepted(
        remoteId: _stringAt(json, remoteIdPath),
        detail: detail,
      );
    }
    return TomSmsGatewayAnswer.rejected(
      permanent: code == null
          ? null
          : permanentErrorCodes.contains(code)
          ? true
          : transientErrorCodes.contains(code)
          ? false
          : null,
      detail: detail,
      providerCode: code,
    );
  }

  static Object? _decodeOrNull(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      // Gateways answer with HTML when they are behind a proxy having a bad
      // day. That is not a parse error worth raising — it is an answer the
      // transport's status rule can still classify.
      return null;
    }
  }

  static String? _stringAt(Object? json, String? path) {
    if (json == null || path == null) return null;
    Object? node = json;
    for (final step in path.split('.')) {
      if (node is! Map) return null;
      node = node[step];
    }
    return node == null ? null : node.toString();
  }

  static String _clip(String body) {
    final flat = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return flat.length <= 200 ? flat : '${flat.substring(0, 197)}...';
  }
}

// =============================================================================
// TRANSPORT
// =============================================================================

/// Delivers [TomMessageChannel.sms] through an HTTP gateway.
///
/// ```dart
/// final transport = TomSmsTransport(
///   TomSmsGatewaySettings.fromConfiguration(configuration)!,
///   TomFieldMappedSmsProtocol(statusPath: 'status', /* ... */),
/// );
/// router.register(transport);
/// ```
///
/// One HTTP request per recipient. A gateway that accepts a list would save
/// requests and cost the receipt its per-number outcome, and partial delivery
/// is the case that matters: one dead number in a list must not cost the others
/// their message, exactly as a rejected `RCPT TO` does not in
/// [TomSmtpTransport].
class TomSmsTransport extends TomMessageTransport {
  /// The metadata key a message uses to name its own sender id.
  ///
  /// The documented purpose of [TomMessage.metadata] since it was written; this
  /// constant only fixes the spelling.
  static const String senderIdMetadataKey = 'senderId';

  /// Where and how to reach the gateway.
  final TomSmsGatewaySettings settings;

  /// The vendor mapping.
  final TomSmsGatewayProtocol protocol;

  /// Opens the connection. Injectable so the whole classification can be tested
  /// against a scripted client without a socket — the same seam
  /// [TomSmtpTransport.connect] provides.
  final TomServerChannel Function(TomSmsGatewaySettings settings) openChannel;

  TomServerChannel? _channel;

  /// Creates an SMS transport.
  TomSmsTransport(
    this.settings,
    this.protocol, {
    TomServerChannel Function(TomSmsGatewaySettings settings)? openChannel,
  }) : openChannel =
           openChannel ??
           ((s) => TomServerChannel(
             s.endpoint.host,
             s.endpoint.hasPort
                 ? s.endpoint.port
                 : (s.endpoint.isScheme('https') ? 443 : 80),
           ));

  @override
  TomMessageChannel get channel => TomMessageChannel.sms;

  /// Whether an HTTP status is worth trying again.
  ///
  /// `408` and `425` are the server saying it did not get there in time, `429`
  /// is it asking for later, and `5xx` is it having a problem of its own —
  /// none of which is a statement about the message. Every other non-`2xx`
  /// says the request was wrong, and a retry sends the same wrong request.
  static bool isTransientStatus(int status) =>
      status == 408 || status == 425 || status == 429 || status >= 500;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);

    final text = (message.textBody ?? message.preferredBody)?.content;
    if (text == null || text.isEmpty) {
      throw TomDeliveryException.permanent(
        'messaging.sms.no_text',
        'Message ${message.id} has no text to send.',
        parameters: {'messageId': message.id},
      );
    }

    final sender =
        (message.metadata[senderIdMetadataKey] as String?) ?? settings.senderId;
    if (protocol.requiresSender && (sender == null || sender.isEmpty)) {
      throw TomDeliveryException.permanent(
        'messaging.sms.no_sender',
        'Message ${message.id} names no sender and no default sender id is '
            'configured (smsSenderId).',
        parameters: {'messageId': message.id},
      );
    }

    final segmentation = TomSmsSegmentation.of(text);
    if (settings.maxSegments > 0 &&
        segmentation.segments > settings.maxSegments) {
      // Permanent by construction: the text will not be shorter on a retry,
      // and the alternative — send it anyway — bills for it.
      throw TomDeliveryException.permanent(
        'messaging.sms.too_long',
        'Message ${message.id} needs ${segmentation.segments} segments; the '
            'gateway is capped at ${settings.maxSegments}.',
        parameters: {
          'messageId': message.id,
          'segments': segmentation.segments,
          'maxSegments': settings.maxSegments,
          'encoding': segmentation.encoding.name,
        },
      );
    }

    final rejected = <String>[];
    String? remoteId;
    String? detail;
    for (final recipient in message.recipients) {
      final answer = await _submit(
        TomSmsSubmission(
          messageId: message.id,
          to: recipient.address,
          from: sender,
          text: text,
          segmentation: segmentation,
        ),
      );
      if (answer.isAccepted) {
        remoteId ??= answer.remoteId;
        detail ??= answer.detail;
        continue;
      }
      rejected.add(recipient.address);
      detail ??= answer.detail;
    }

    if (rejected.length == message.recipients.length) {
      throw TomDeliveryException.permanent(
        'messaging.sms.all_recipients_rejected',
        'Every recipient of message ${message.id} was rejected: '
            '${rejected.join(', ')}.',
        parameters: {
          'messageId': message.id,
          'rejected': rejected.join(', '),
          if (detail != null) 'detail': detail,
        },
      );
    }

    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: remoteId,
      detail: detail,
      rejectedRecipients: rejected,
    );
  }

  /// Sends one submission, returning the answer only when it is final.
  ///
  /// A transient refusal is thrown rather than returned, which stops the pass:
  /// a rate limit or an outage applies to the account, not to one number, so
  /// continuing down the list would burn the remaining recipients on the same
  /// refusal — and the retry would then deliver twice to the ones that had
  /// already gone.
  Future<TomSmsGatewayAnswer> _submit(TomSmsSubmission submission) async {
    final request = protocol.encode(submission, settings);
    final (status, body) = await _exchangeOrDefer(request, submission);
    final answer = protocol.decode(status, body);
    if (answer.isAccepted) return answer;

    final permanent = answer.isPermanent ?? !isTransientStatus(status);
    if (permanent) return answer;
    throw TomDeliveryException.transient(
      'messaging.sms.gateway_deferred',
      'The gateway deferred message ${submission.messageId} to '
          '${submission.to}${answer.detail == null ? '' : ': ${answer.detail}'}',
      statusCode: status,
      parameters: {
        'messageId': submission.messageId,
        'to': submission.to,
        'httpStatus': status,
        if (answer.providerCode != null) 'providerCode': answer.providerCode,
      },
    );
  }

  Future<(int, String)> _exchangeOrDefer(
    TomSmsGatewayRequest request,
    TomSmsSubmission submission,
  ) async {
    try {
      return await _exchange(request).timeout(settings.timeout);
    } on TomDeliveryException {
      rethrow;
    } catch (error, stack) {
      // Unreachable, refused, timed out: the textbook transient failure.
      // Nothing about the message is wrong, so nothing is gained by giving up.
      throw TomDeliveryException.transient(
        'messaging.sms.unreachable',
        'Could not reach the SMS gateway at ${settings.endpoint.host}.',
        parameters: {
          'messageId': submission.messageId,
          'host': settings.endpoint.host,
        },
        rootException: error,
        stack: stack,
      );
    }
  }

  Future<(int, String)> _exchange(TomSmsGatewayRequest request) async {
    final call = _serverChannel.prepareCall(
      TomServerCallSpecs(
        request.method,
        request.url,
        headers: request.headers,
        // The kernel call layer injects the *caller's* bearer token by
        // default. A gateway has no idea what that is, and presenting it would
        // hand a user credential to a third party.
        includeBearerAuthentication: false,
      ),
    );
    call.send(
      TomServerCallLoad(stringBody: request.body, bodyFields: request.fields),
    );
    // Order matters: reading the body consumes the stream, and the status is
    // only readable before that.
    final status = await call.getResponseStatusCode();
    return (status, await call.readAsString(utf8));
  }

  TomServerChannel get _serverChannel => _channel ??= openChannel(settings);

  @override
  Future<void> close() async {
    _channel?.close();
    _channel = null;
  }
}
