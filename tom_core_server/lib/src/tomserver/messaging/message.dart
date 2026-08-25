/// The shape of an outbound message, independent of how it is delivered.
///
/// This is the *transport* substrate behind CE-NT notifications and CE-RP
/// report delivery. It deliberately stops short of the notification **model** —
/// which events notify, which users subscribe, what their per-channel
/// preferences are — because that is a CodeSpecs part decision, not a framework
/// one. What lives here is only the envelope and the wire.
///
/// ## Why the shape is not an email
///
/// CE-NT names its channels abstractly — email, push, SMS, webhook — and only
/// the first of those has a subject line, a `Cc:`, or a MIME tree. A message
/// type modelled on SMTP would make the other three subclasses of a thing they
/// are not, and every non-email transport would spend its life ignoring fields.
///
/// So the shape here is the *intersection*, plus two escape hatches:
///
/// - **Common:** a [TomMessage.channel], [TomMessage.recipients], an optional
///   [TomMessage.subject], one or more [TomMessageBody] alternatives, and
///   [TomMessage.attachments].
/// - **[TomMessage.headers]** carries transport-level name/value pairs that
///   only some channels have (email headers, webhook HTTP headers).
/// - **[TomMessage.metadata]** carries channel-specific delivery hints (a push
///   priority, an SMS sender id) that are not headers at all.
///
/// A transport reads what it understands and ignores the rest. That is what
/// lets a spec that names `email` today name `sms` tomorrow without the message
/// type changing.
///
/// ## Everything round-trips through JSON
///
/// A message is not delivered on the thread that created it — it goes onto the
/// durable outbox queue and may be delivered after a restart, in a different
/// isolate. So [TomMessage.toJson] / [TomMessage.fromJson] are not a
/// convenience; they are the reason the outbox can promise that an accepted
/// message survives a crash. Attachment bytes are base64 in that encoding,
/// which is also exactly how MIME will need them.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/v4.dart';

import '../little_things/server_exception.dart';

/// Raised when a message cannot be built, addressed, encoded or delivered.
///
/// Not client-visible by default: a caller who asked for a notification has no
/// business learning the SMTP host was unreachable, and the message would
/// describe server-side infrastructure.
class TomMessagingException extends TomServerException {
  /// Creates a messaging exception.
  TomMessagingException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow = false,
  });
}

// =============================================================================
// CHANNEL
// =============================================================================

/// Which delivery channel a message is bound for.
///
/// A named value rather than an enum, because the set is *open*: CE-NT fixes
/// four channels by name but a deployment may add one (an internal chat
/// webhook, a pager gateway) without the framework being rebuilt. The constants
/// below give the four that CE-NT names a spelling everyone agrees on, which is
/// what an enum was buying; the constructor keeps the door open, which is what
/// an enum was costing.
class TomMessageChannel {
  /// The channel's wire name, lowercase by convention.
  final String name;

  /// Names a channel.
  const TomMessageChannel(this.name);

  /// Email, delivered by [TomSmtpTransport] or another mailer.
  static const TomMessageChannel email = TomMessageChannel('email');

  /// Short text message.
  static const TomMessageChannel sms = TomMessageChannel('sms');

  /// Mobile or browser push notification.
  static const TomMessageChannel push = TomMessageChannel('push');

  /// An HTTP callback to a subscribed endpoint.
  static const TomMessageChannel webhook = TomMessageChannel('webhook');

  /// The four channels CE-NT names, for validation and for iteration.
  static const List<TomMessageChannel> standard = [email, sms, push, webhook];

  @override
  bool operator ==(Object other) =>
      other is TomMessageChannel && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

// =============================================================================
// RECIPIENTS
// =============================================================================

/// How a recipient is addressed relative to the others.
///
/// Meaningful for email; every other channel has only [to], and a transport
/// that cannot express copies is expected to say so rather than silently
/// flatten them (see [TomMessageTransport.supportsCopies]).
enum TomRecipientKind {
  /// A primary addressee.
  to,

  /// A copied addressee, visible to everyone.
  cc,

  /// A copied addressee, hidden from everyone — including the other blind
  /// copies.
  bcc,
}

/// One addressee of a message.
///
/// [address] is deliberately not called `emailAddress`: for SMS it is a phone
/// number, for push a device token, for a webhook a URL. Naming it after the
/// only channel that happens to use `@` is how a transport-neutral type stops
/// being one.
class TomRecipient {
  /// The channel-specific address.
  final String address;

  /// The human-readable name, when one is known.
  final String? displayName;

  /// Whether this is a primary, copied or blind-copied addressee.
  final TomRecipientKind kind;

  /// Creates a recipient.
  TomRecipient(
    this.address, {
    this.displayName,
    this.kind = TomRecipientKind.to,
  }) {
    if (address.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.recipient.empty',
        'A recipient needs a non-empty address.',
      );
    }
  }

  /// A copy of this recipient addressed as [kind].
  TomRecipient as(TomRecipientKind kind) =>
      TomRecipient(address, displayName: displayName, kind: kind);

  /// Encodes this recipient as a JSON-native map.
  Map<String, Object?> toJson() => {
    'address': address,
    if (displayName != null) 'displayName': displayName,
    'kind': kind.name,
  };

  /// Decodes a map produced by [toJson].
  factory TomRecipient.fromJson(Map<String, Object?> map) => TomRecipient(
    map['address'] as String,
    displayName: map['displayName'] as String?,
    kind: TomRecipientKind.values.firstWhere(
      (k) => k.name == map['kind'],
      orElse: () => TomRecipientKind.to,
    ),
  );

  @override
  String toString() =>
      displayName == null ? address : '$displayName <$address>';
}

// =============================================================================
// BODY
// =============================================================================

/// One representation of a message's content.
///
/// A message carries a *list* of these because the same content often has to be
/// offered twice — an HTML mail and its plain-text fallback — and picking one
/// for the recipient is the transport's job, not the caller's. Ordering is
/// least-preferred first, matching MIME's `multipart/alternative` convention,
/// so the richest representation is last.
class TomMessageBody {
  /// The IANA media type, e.g. `text/plain` or `text/html`.
  final String mediaType;

  /// The content itself.
  final String content;

  /// The character set the content is in.
  final String charset;

  /// Creates a body part.
  const TomMessageBody(this.mediaType, this.content, {this.charset = 'utf-8'});

  /// A `text/plain` part.
  const TomMessageBody.text(String content)
    : mediaType = 'text/plain',
      content = content,
      charset = 'utf-8';

  /// A `text/html` part.
  const TomMessageBody.html(String content)
    : mediaType = 'text/html',
      content = content,
      charset = 'utf-8';

  /// Whether [mediaType] names [type], which is spelled in lower case.
  ///
  /// Media types are case-insensitive by specification, so the comparison has
  /// to be too. It lives in one place because the alternative was tried: the
  /// HTML check lowercased, the plain-text check was an inline `==` inside a
  /// selector, and the two drifted apart — a body spelled `Text/Plain` was not
  /// found while `Text/HTML` was. Predicates that share an implementation
  /// cannot disagree about their own rule.
  ///
  /// Matching only; the caller's own spelling is what [mediaType] keeps and
  /// what the MIME encoder puts on the wire.
  bool _mediaTypeIs(String type) => mediaType.toLowerCase() == type;

  /// Whether this part is plain text.
  bool get isPlainText => _mediaTypeIs('text/plain');

  /// Whether this part is HTML.
  bool get isHtml => _mediaTypeIs('text/html');

  /// Encodes this part as a JSON-native map.
  Map<String, Object?> toJson() => {
    'mediaType': mediaType,
    'content': content,
    'charset': charset,
  };

  /// Decodes a map produced by [toJson].
  factory TomMessageBody.fromJson(Map<String, Object?> map) => TomMessageBody(
    map['mediaType'] as String,
    map['content'] as String,
    charset: map['charset'] as String? ?? 'utf-8',
  );

  @override
  String toString() => '$mediaType (${content.length} chars)';
}

// =============================================================================
// ATTACHMENTS
// =============================================================================

/// A file carried with a message.
///
/// Bytes are held in memory rather than referenced by path, because a message
/// may be delivered long after the process that composed it — and a path that
/// resolved at compose time is exactly the sort of thing that has stopped
/// resolving by the time a retry runs.
class TomAttachment {
  /// The name the recipient sees.
  final String fileName;

  /// The IANA media type of the content.
  final String mediaType;

  /// The content.
  final Uint8List bytes;

  /// The `Content-ID` for an attachment referenced from within an HTML body.
  ///
  /// Non-null makes this attachment *inline*: it is not offered as a download
  /// but resolved by `cid:` references in the markup. Null makes it a
  /// conventional attachment.
  final String? contentId;

  /// Creates an attachment.
  TomAttachment({
    required this.fileName,
    required this.bytes,
    this.mediaType = 'application/octet-stream',
    this.contentId,
  }) {
    if (fileName.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.attachment.unnamed',
        'An attachment needs a non-empty file name.',
      );
    }
  }

  /// An attachment holding UTF-8 encoded [text].
  factory TomAttachment.text({
    required String fileName,
    required String text,
    String mediaType = 'text/plain',
  }) => TomAttachment(
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(text)),
    mediaType: mediaType,
  );

  /// Whether this attachment is referenced from the body rather than listed.
  bool get isInline => contentId != null;

  /// Encodes this attachment as a JSON-native map, bytes base64-encoded.
  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'mediaType': mediaType,
    'bytes': base64.encode(bytes),
    if (contentId != null) 'contentId': contentId,
  };

  /// Decodes a map produced by [toJson].
  factory TomAttachment.fromJson(Map<String, Object?> map) => TomAttachment(
    fileName: map['fileName'] as String,
    mediaType: map['mediaType'] as String? ?? 'application/octet-stream',
    bytes: base64.decode(map['bytes'] as String),
    contentId: map['contentId'] as String?,
  );

  @override
  String toString() => '$fileName ($mediaType, ${bytes.length} bytes)';
}

// =============================================================================
// MESSAGE
// =============================================================================

/// An outbound message, ready to hand to a [TomMessageTransport].
///
/// See the library dartdoc for why the shape is channel-neutral. The one
/// invariant enforced here is that a message has somewhere to go: an
/// unaddressed message is a programming error that would otherwise surface as
/// an obscure transport failure minutes later, on a retry, in another isolate.
class TomMessage {
  /// Stable identity, used for correlation in receipts, logs and the outbox.
  ///
  /// Generated when omitted. Supplying one lets a caller make sending
  /// idempotent against its own domain key.
  final String id;

  /// Which channel this message is bound for.
  final TomMessageChannel channel;

  /// Who the message is from, or `null` to let the transport supply its
  /// configured default sender.
  final TomRecipient? from;

  /// Where replies should be addressed, when that differs from [from].
  final TomRecipient? replyTo;

  /// Everyone the message is addressed to, including copies.
  final List<TomRecipient> recipients;

  /// The subject line, for channels that have one.
  final String? subject;

  /// The content representations, least-preferred first.
  final List<TomMessageBody> bodies;

  /// Files carried with the message.
  final List<TomAttachment> attachments;

  /// Transport-level name/value pairs (email headers, webhook HTTP headers).
  final Map<String, String> headers;

  /// Channel-specific delivery hints that are not headers.
  ///
  /// Restricted to JSON-encodable values so a queued message round-trips.
  final Map<String, Object?> metadata;

  /// When the message was composed.
  final DateTime createdAt;

  /// Creates a message.
  TomMessage({
    String? id,
    this.channel = TomMessageChannel.email,
    this.from,
    this.replyTo,
    required this.recipients,
    this.subject,
    this.bodies = const [],
    this.attachments = const [],
    Map<String, String>? headers,
    Map<String, Object?>? metadata,
    DateTime? createdAt,
  }) : id = id ?? const UuidV4().generate(),
       headers = Map.unmodifiable(headers ?? const {}),
       metadata = Map.unmodifiable(metadata ?? const {}),
       createdAt = createdAt ?? DateTime.now() {
    if (recipients.isEmpty) {
      throw TomMessagingException(
        'messaging.message.unaddressed',
        'A message needs at least one recipient.',
        parameters: {'messageId': this.id},
      );
    }
  }

  /// An email with a plain-text body, and optionally an HTML alternative.
  ///
  /// The common case, spelled once so that every caller does not re-derive the
  /// ordering rule that HTML goes last.
  factory TomMessage.email({
    String? id,
    TomRecipient? from,
    TomRecipient? replyTo,
    required List<TomRecipient> to,
    String? subject,
    String? text,
    String? html,
    List<TomAttachment> attachments = const [],
    Map<String, String>? headers,
  }) => TomMessage(
    id: id,
    channel: TomMessageChannel.email,
    from: from,
    replyTo: replyTo,
    recipients: to,
    subject: subject,
    bodies: [
      if (text != null) TomMessageBody.text(text),
      if (html != null) TomMessageBody.html(html),
    ],
    attachments: attachments,
    headers: headers,
  );

  /// An SMS: one text body, no subject, and a sender that is an *id* rather
  /// than an address.
  ///
  /// [senderId] goes into [metadata] rather than into [from], because it is not
  /// a [TomRecipient] — nobody replies to a short code, and modelling it as one
  /// would offer a `displayName` and a [TomRecipientKind] that mean nothing
  /// here. Carrying a sender id is what [metadata] was documented for.
  factory TomMessage.sms({
    String? id,
    required List<TomRecipient> to,
    required String text,
    String? senderId,
    Map<String, Object?>? metadata,
  }) => TomMessage(
    id: id,
    channel: TomMessageChannel.sms,
    recipients: to,
    bodies: [TomMessageBody.text(text)],
    metadata: {
      ...?metadata,
      if (senderId != null && senderId.isNotEmpty) 'senderId': senderId,
    },
  );

  /// The recipients addressed as [kind].
  List<TomRecipient> recipientsOf(TomRecipientKind kind) =>
      recipients.where((r) => r.kind == kind).toList(growable: false);

  /// Every recipient address, in declaration order.
  ///
  /// This is the envelope — what a transport actually delivers to — and it
  /// deliberately includes blind copies, which appear here but must not appear
  /// in any header a recipient can read.
  List<String> get envelopeAddresses =>
      recipients.map((r) => r.address).toList(growable: false);

  /// The richest body offered, or `null` when the message has none.
  TomMessageBody? get preferredBody => bodies.isEmpty ? null : bodies.last;

  /// The plain-text representation, matched case-insensitively, when one was
  /// offered.
  TomMessageBody? get textBody => bodies.cast<TomMessageBody?>().firstWhere(
    (b) => b!.isPlainText,
    orElse: () => null,
  );

  /// The HTML representation, matched case-insensitively, when one was offered.
  TomMessageBody? get htmlBody => bodies.cast<TomMessageBody?>().firstWhere(
    (b) => b!.isHtml,
    orElse: () => null,
  );

  /// Whether any attachment is referenced from the body rather than listed.
  bool get hasInlineAttachments => attachments.any((a) => a.isInline);

  /// A copy of this message with the given fields replaced.
  ///
  /// Used by transports that must fill in a default sender without mutating the
  /// caller's message — which matters, because the same message instance may be
  /// retried, and a transport that edited it in place would make the second
  /// attempt operate on something the first attempt invented.
  TomMessage copyWith({
    TomRecipient? from,
    TomRecipient? replyTo,
    List<TomRecipient>? recipients,
    String? subject,
    List<TomMessageBody>? bodies,
    List<TomAttachment>? attachments,
    Map<String, String>? headers,
    Map<String, Object?>? metadata,
  }) => TomMessage(
    id: id,
    channel: channel,
    from: from ?? this.from,
    replyTo: replyTo ?? this.replyTo,
    recipients: recipients ?? this.recipients,
    subject: subject ?? this.subject,
    bodies: bodies ?? this.bodies,
    attachments: attachments ?? this.attachments,
    headers: headers ?? this.headers,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt,
  );

  /// Encodes this message as a JSON-native map.
  Map<String, Object?> toJson() => {
    'id': id,
    'channel': channel.name,
    if (from != null) 'from': from!.toJson(),
    if (replyTo != null) 'replyTo': replyTo!.toJson(),
    'recipients': recipients.map((r) => r.toJson()).toList(),
    if (subject != null) 'subject': subject,
    'bodies': bodies.map((b) => b.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
    if (headers.isNotEmpty) 'headers': headers,
    if (metadata.isNotEmpty) 'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Decodes a map produced by [toJson].
  factory TomMessage.fromJson(Map<String, Object?> map) => TomMessage(
    id: map['id'] as String,
    channel: TomMessageChannel(map['channel'] as String),
    from: _recipientOrNull(map['from']),
    replyTo: _recipientOrNull(map['replyTo']),
    recipients: (map['recipients'] as List)
        .cast<Map<String, Object?>>()
        .map(TomRecipient.fromJson)
        .toList(),
    subject: map['subject'] as String?,
    bodies: ((map['bodies'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(TomMessageBody.fromJson)
        .toList(),
    attachments: ((map['attachments'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(TomAttachment.fromJson)
        .toList(),
    headers: ((map['headers'] as Map?) ?? const {}).cast<String, String>(),
    metadata: ((map['metadata'] as Map?) ?? const {}).cast<String, Object?>(),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  static TomRecipient? _recipientOrNull(Object? value) => value == null
      ? null
      : TomRecipient.fromJson((value as Map).cast<String, Object?>());

  @override
  String toString() =>
      'TomMessage($id, $channel, '
      '${recipients.length} recipient(s), subject: $subject)';
}
