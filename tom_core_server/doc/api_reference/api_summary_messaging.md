# Tom Core Server API Reference: Messaging Module

The outbound message substrate: a channel-neutral message shape, a transport
contract, two real implementations — SMTP and an HTTP SMS gateway — stand-in
transports for tests and local runs, a durable outbox that queues delivery onto
the kernel's job scheduler, and the templating layer above it that composes
every channel's messages from resource keys.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomMessagingException](#tommessagingexception)
  - [TomMessageChannel](#tommessagechannel)
  - [TomRecipientKind](#tomrecipientkind)
  - [TomRecipient](#tomrecipient)
  - [TomMessageBody](#tommessagebody)
  - [TomAttachment](#tomattachment)
  - [TomMessage](#tommessage)
  - [TomDeliveryOutcome](#tomdeliveryoutcome)
  - [TomDeliveryReceipt](#tomdeliveryreceipt)
  - [TomDeliveryException](#tomdeliveryexception)
  - [TomPermanentDeliveryException](#tompermanentdeliveryexception)
  - [TomMessageTransport](#tommessagetransport)
  - [TomMessageRouter](#tommessagerouter)
  - [TomMemoryMessageTransport](#tommemorymessagetransport)
  - [TomNoOpMessageTransport](#tomnoopmessagetransport)
  - [TomFileMessageTransport](#tomfilemessagetransport)
  - [TomMimeEncoder](#tommimeencoder)
  - [TomMessageOutbox](#tommessageoutbox)
  - [TomTemplatedMessageService](#tomtemplatedmessageservice)
  - [TomEmailRequest](#tomemailrequest)
  - [TomEmailService](#tomemailservice)
  - [TomSmtpSecurity](#tomsmtpsecurity)
  - [TomSmtpSettings](#tomsmtpsettings)
  - [TomSmtpTransport](#tomsmtptransport)
  - [TomSmtpReply](#tomsmtpreply)
  - [TomSmtpConnection](#tomsmtpconnection)
  - [TomSocketSmtpConnection](#tomsocketsmtpconnection)
  - [TomSmsEncoding](#tomsmsencoding)
  - [TomSmsSegmentation](#tomsmssegmentation)
  - [TomSmsAuthScheme](#tomsmsauthscheme)
  - [TomSmsGatewaySettings](#tomsmsgatewaysettings)
  - [TomSmsSubmission](#tomsmssubmission)
  - [TomSmsBodyFormat](#tomsmsbodyformat)
  - [TomSmsGatewayRequest](#tomsmsgatewayrequest)
  - [TomSmsGatewayAnswer](#tomsmsgatewayanswer)
  - [TomSmsGatewayProtocol](#tomsmsgatewayprotocol)
  - [TomFieldMappedSmsProtocol](#tomfieldmappedsmsprotocol)
  - [TomSmsTransport](#tomsmstransport)
  - [TomSmsRequest](#tomsmsrequest)
  - [TomSmsService](#tomsmsservice)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/messaging/email_service.dart`,
`lib/src/tomserver/messaging/message.dart`,
`lib/src/tomserver/messaging/message_transport.dart`,
`lib/src/tomserver/messaging/mime_encoder.dart`,
`lib/src/tomserver/messaging/outbox.dart`,
`lib/src/tomserver/messaging/sms_service.dart`,
`lib/src/tomserver/messaging/sms_transport.dart`,
`lib/src/tomserver/messaging/smtp_transport.dart`,
`lib/src/tomserver/messaging/templated_message_service.dart`.

The module separates three things a single `sendMail()` call conflates.
*Composition* is `TomMessage` and the value types around it — `TomRecipient`
and `TomRecipientKind`, `TomMessageBody`, `TomAttachment`, and the open named
value `TomMessageChannel`. The shape is the intersection of what every channel
has, with `headers` and `metadata` as escape hatches for what only some do, and
it round-trips through JSON because a queued message may be delivered after a
restart in another isolate.

*Delivery* is `TomMessageTransport`: one attempt at one message, reported as a
`TomDeliveryReceipt` carrying a `TomDeliveryOutcome` and any recipients the far
side refused. Failures are thrown rather than returned, as a
`TomDeliveryException` classified transient or permanent — the permanent form,
`TomPermanentDeliveryException`, mixes in the kernel's `TomPermanentFailure` so
the judgement is made once, where the evidence is, and honoured downstream.
`TomMessageRouter` maps a channel to the transport that delivers it, and treats
an unrouted channel as a permanent failure.

Five transports implement the contract. `TomSmtpTransport` speaks the protocol
directly over `TomSmtpConnection` — implemented for real sockets by
`TomSocketSmtpConnection`, and reading each `TomSmtpReply`'s code to decide
whether a failure is worth repeating — configured by `TomSmtpSettings` and
`TomSmtpSecurity`. `TomSmsTransport` reaches an HTTP gateway configured by
`TomSmsGatewaySettings` and `TomSmsAuthScheme`, with the vendor's vocabulary
behind a `TomSmsGatewayProtocol` (`TomFieldMappedSmsProtocol` describes the
common ones in configuration) that maps a `TomSmsSubmission` to a
`TomSmsGatewayRequest` and a response back to a `TomSmsGatewayAnswer`;
`TomSmsSegmentation` and `TomSmsEncoding` supply the GSM 03.38 length
arithmetic an SMS is billed by. `TomMemoryMessageTransport`,
`TomNoOpMessageTransport` and `TomFileMessageTransport` are the stand-ins for
tests, silenced deployments and local development. `TomMimeEncoder` renders the
RFC 5322 / MIME document the SMTP transport transfers, choosing the simplest
structure the content allows and never writing a `Bcc:` header.

*Semantics* is `TomMessageOutbox`, a durable send queue in front of a router. It
owns no retry logic: it enqueues one job run per message on an
inline-dispatching scheduler of its own, and durability, backoff, at-most-one
runner per message and failure alerting all remain the kernel scheduler's.

*Templating* is `TomTemplatedMessageService` and its two subclasses. A request
names a template key and supplies parameters; `TomEmailRequest` has **no subject
and no body field** and `TomSmsRequest` has **no text field**, so there is no way
to spell a literal user-facing string through either API. The base owns `send`,
`sendNow`, `deliverNow` and `requiredText`; a subclass supplies only its channel name and how
one of its requests becomes a `TomMessage`. `TomEmailService` resolves
`<templateKey>.subject`, `.text` and (optionally) `.html` against a
`TomLocalizedTextResources` bundle set in the recipient's locale;
`TomSmsService` resolves `.text` alone and additionally measures the result,
refusing a message over its segment budget. Both render a `TomMessage` and hand
it to the outbox — never to a transport — and both raise before anything is
queued.

`TomMessagingException` is the module's base error, from which every failure
above derives.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomMessagingException
            └── TomDeliveryException
                    └── TomPermanentDeliveryException

TomMessageTransport  (abstract)
    ├── TomMemoryMessageTransport
    ├── TomNoOpMessageTransport
    ├── TomFileMessageTransport
    ├── TomSmtpTransport
    └── TomSmsTransport

TomSmtpConnection  (abstract)
    └── TomSocketSmtpConnection  (implements)

TomSmsGatewayProtocol  (abstract)
    └── TomFieldMappedSmsProtocol

TomTemplatedMessageService<R>  (abstract)
    ├── TomEmailService     (R = TomEmailRequest)
    └── TomSmsService       (R = TomSmsRequest)

TomMessageChannel
TomRecipientKind  (enum)
TomRecipient
TomMessageBody
TomAttachment
TomMessage
TomDeliveryOutcome  (enum)
TomDeliveryReceipt
TomMessageRouter
TomMimeEncoder
TomMessageOutbox
TomEmailRequest
TomSmtpSecurity  (enum)
TomSmtpSettings
TomSmtpReply
TomSmsEncoding  (enum)
TomSmsSegmentation
TomSmsAuthScheme  (enum)
TomSmsGatewaySettings
TomSmsSubmission
TomSmsBodyFormat  (enum)
TomSmsGatewayRequest
TomSmsGatewayAnswer
TomSmsRequest
```

## Classes

### TomMessagingException

Raised when a message cannot be built, addressed, encoded or delivered. Not
client-visible by default (`clientThrow` defaults to `false`): the message would
describe server-side infrastructure to a caller who only asked for a
notification.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomMessagingException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  Object? stack,
  bool clientThrow = false,
})
```

### TomMessageChannel

Which delivery channel a message is bound for. A named value rather than an
enum, because the set is open: a deployment may add a channel without the
framework being rebuilt, while the constants below give the four the framework
anticipates a spelling everyone agrees on.

#### Constructors

```dart
const TomMessageChannel(String name)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `email` | `static const TomMessageChannel` | Email, delivered by `TomSmtpTransport` or another mailer. |
| `sms` | `static const TomMessageChannel` | Short text message. |
| `push` | `static const TomMessageChannel` | Mobile or browser push notification. |
| `webhook` | `static const TomMessageChannel` | An HTTP callback to a subscribed endpoint. |
| `standard` | `static const List<TomMessageChannel>` | The four anticipated channels, for validation and for iteration. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The channel's wire name, lowercase by convention (final). |
| `hashCode` | `int` | *(getter)* *(override)* Derived from `name`, so equal channels hash alike. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The bare `name`. |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `==` | `bool operator ==(Object other)` | *(override)* Two channels are equal when their `name`s are. |

### TomRecipientKind

How a recipient is addressed relative to the others. Meaningful for email; every
other channel has only `to`, and a transport that cannot express copies says so
through `TomMessageTransport.supportsCopies` rather than flattening them.

#### Values

| Value | Description |
| ----- | ----------- |
| `to` | A primary addressee. |
| `cc` | A copied addressee, visible to everyone. |
| `bcc` | A copied addressee, hidden from everyone — including the other blind copies. |

### TomRecipient

One addressee of a message. Construction rejects a blank `address` with a
`TomMessagingException`.

#### Constructors

```dart
TomRecipient(
  String address, {
  String? displayName,
  TomRecipientKind kind = TomRecipientKind.to,
})
```

#### Factory Constructors

```dart
factory TomRecipient.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `address` | `String` | The channel-specific address — a mailbox, a phone number, a device token, a URL. Deliberately not named `emailAddress` (final). |
| `displayName` | `String?` | The human-readable name, when one is known (final). |
| `kind` | `TomRecipientKind` | Whether this is a primary, copied or blind-copied addressee (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `as` | `TomRecipient as(TomRecipientKind kind)` | A copy of this recipient addressed as `kind`. |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the recipient as a JSON-native map; `displayName` is omitted when null. |
| `toString` | `String toString()` | *(override)* The bare address, or `'displayName <address>'` when a name is known. |

### TomMessageBody

One representation of a message's content. A message carries a list of these
because the same content often has to be offered twice — HTML and its
plain-text fallback — with ordering least-preferred first, matching MIME's
`multipart/alternative` convention.

#### Constructors

```dart
const TomMessageBody(String mediaType, String content, {String charset = 'utf-8'})

const TomMessageBody.text(String content)

const TomMessageBody.html(String content)
```

#### Factory Constructors

```dart
factory TomMessageBody.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mediaType` | `String` | The IANA media type, e.g. `text/plain` or `text/html` (final). |
| `content` | `String` | The content itself (final). |
| `charset` | `String` | The character set the content is in; defaults to `utf-8` (final). |
| `isHtml` | `bool` | *(getter)* Whether `mediaType` is `text/html`, case-insensitively. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the part as a JSON-native map. |
| `toString` | `String toString()` | *(override)* The media type and the content's length in characters. |

### TomAttachment

A file carried with a message. Bytes are held in memory rather than referenced
by path, because a message may be delivered long after the process that composed
it, and a path that resolved at compose time may not resolve on a retry.
Construction rejects a blank `fileName`.

#### Constructors

```dart
TomAttachment({
  required String fileName,
  required Uint8List bytes,
  String mediaType = 'application/octet-stream',
  String? contentId,
})
```

#### Factory Constructors

```dart
factory TomAttachment.text({
  required String fileName,
  required String text,
  String mediaType = 'text/plain',
})

factory TomAttachment.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fileName` | `String` | The name the recipient sees (final). |
| `mediaType` | `String` | The IANA media type of the content (final). |
| `bytes` | `Uint8List` | The content (final). |
| `contentId` | `String?` | The `Content-ID` for an attachment referenced by a `cid:` link from an HTML body; non-null makes it inline rather than listed (final). |
| `isInline` | `bool` | *(getter)* Whether `contentId` is set. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the attachment as a JSON-native map, with the bytes base64-encoded. |
| `toString` | `String toString()` | *(override)* The file name, media type and byte count. |

### TomMessage

An outbound message, ready to hand to a `TomMessageTransport`. The one invariant
enforced at construction is that the message has somewhere to go: an unaddressed
message raises a `TomMessagingException` on the composing stack rather than
surfacing as an obscure transport failure on a later retry. `headers` and
`metadata` are made unmodifiable, so a queued message cannot be edited between
attempts.

#### Constructors

```dart
TomMessage({
  String? id,
  TomMessageChannel channel = TomMessageChannel.email,
  TomRecipient? from,
  TomRecipient? replyTo,
  required List<TomRecipient> recipients,
  String? subject,
  List<TomMessageBody> bodies = const [],
  List<TomAttachment> attachments = const [],
  Map<String, String>? headers,
  Map<String, Object?>? metadata,
  DateTime? createdAt,
})
```

#### Factory Constructors

```dart
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
})

factory TomMessage.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Stable identity used for correlation in receipts, logs and the outbox; a UUIDv4 is generated when none is supplied (final). |
| `channel` | `TomMessageChannel` | Which channel the message is bound for; defaults to email (final). |
| `from` | `TomRecipient?` | Who the message is from, or `null` to let the transport supply its configured default sender (final). |
| `replyTo` | `TomRecipient?` | Where replies should be addressed, when that differs from `from` (final). |
| `recipients` | `List<TomRecipient>` | Everyone the message is addressed to, including copies (final). |
| `subject` | `String?` | The subject line, for channels that have one (final). |
| `bodies` | `List<TomMessageBody>` | The content representations, least-preferred first (final). |
| `attachments` | `List<TomAttachment>` | Files carried with the message (final). |
| `headers` | `Map<String, String>` | Transport-level name/value pairs (email headers, webhook HTTP headers); unmodifiable (final). |
| `metadata` | `Map<String, Object?>` | Channel-specific delivery hints that are not headers, restricted to JSON-encodable values; unmodifiable (final). |
| `createdAt` | `DateTime` | When the message was composed; defaults to now (final). |
| `envelopeAddresses` | `List<String>` | *(getter)* Every recipient address in declaration order, blind copies included — this is the envelope a transport delivers to. |
| `preferredBody` | `TomMessageBody?` | *(getter)* The richest body offered (the last), or `null` when there is none. |
| `textBody` | `TomMessageBody?` | *(getter)* The `text/plain` representation, when one was offered. |
| `htmlBody` | `TomMessageBody?` | *(getter)* The HTML representation, when one was offered. |
| `hasInlineAttachments` | `bool` | *(getter)* Whether any attachment is referenced from a body rather than listed. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recipientsOf` | `List<TomRecipient> recipientsOf(TomRecipientKind kind)` | The recipients addressed as `kind`. |
| `copyWith` | `TomMessage copyWith({TomRecipient? from, TomRecipient? replyTo, List<TomRecipient>? recipients, String? subject, List<TomMessageBody>? bodies, List<TomAttachment>? attachments, Map<String, String>? headers, Map<String, Object?>? metadata})` | A copy with the given fields replaced, keeping `id`, `channel` and `createdAt`. Used by transports that must fill in a default sender without mutating a message that may be retried. |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the message as a JSON-native map; empty collections and null fields are omitted. |
| `toString` | `String toString()` | *(override)* The id, channel, recipient count and subject. |

### TomDeliveryOutcome

What became of one delivery attempt.

#### Values

| Value | Description |
| ----- | ----------- |
| `delivered` | The far side accepted the message — for most channels "accepted for delivery", not "read by a human". |
| `rejected` | The far side refused it, and would refuse it again. |
| `deferred` | The attempt did not conclude and should be repeated. |
| `discarded` | Nothing was sent because the transport is a stand-in. |

### TomDeliveryReceipt

The result of one delivery attempt, including the partial case where some
recipients were accepted and others refused.

#### Constructors

```dart
TomDeliveryReceipt({
  required String messageId,
  required TomDeliveryOutcome outcome,
  String? remoteId,
  DateTime? at,
  String? detail,
  List<String> rejectedRecipients = const [],
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `messageId` | `String` | The `TomMessage.id` this receipt concerns (final). |
| `outcome` | `TomDeliveryOutcome` | What happened (final). |
| `remoteId` | `String?` | The far side's identifier for the message, when the protocol supplies one — for SMTP whatever the server echoed on the final `250` (final). |
| `at` | `DateTime` | When the attempt concluded; defaults to now (final). |
| `detail` | `String?` | The far side's own words, kept verbatim for diagnosis (final). |
| `rejectedRecipients` | `List<String>` | Recipients the far side refused while accepting the others (final). |
| `isDelivered` | `bool` | *(getter)* Whether the far side took responsibility for the message. |
| `isPartial` | `bool` | *(getter)* Whether the message was delivered but some recipients were refused. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the receipt as a JSON-native map; null and empty fields are omitted. |
| `toString` | `String toString()` | *(override)* The message id, the outcome name and the remote id when there is one. |

### TomDeliveryException

A delivery attempt that did not succeed. `isPermanent` is the whole point of the
type: it records whether retrying this exact message could ever succeed, and
only the transport can make that call because only the transport read the far
side's answer. Prefer the `permanent` and `transient` builders, which cannot be
given the wrong classification by accident.

- **Extends:** `TomMessagingException`

#### Constructors

```dart
TomDeliveryException(
  String key,
  String defaultUserMessage, {
  required bool isPermanent,
  int? statusCode,
  Map<String, Object?>? parameters,
  Object? rootException,
  Object? stack,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `permanent` | `static TomPermanentDeliveryException permanent(String key, String message, {int? statusCode, Map<String, dynamic>? parameters, Object? rootException, Object? stack})` | A failure that retrying cannot fix; the returned type carries the scheduler's give-up marker. |
| `transient` | `static TomDeliveryException transient(String key, String message, {int? statusCode, Map<String, dynamic>? parameters, Object? rootException, Object? stack})` | A failure that a later attempt may well survive. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isPermanent` | `bool` | Whether retrying this exact message could ever succeed (final). |
| `statusCode` | `int?` | The protocol's own status code, when it had one — e.g. SMTP `550` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The base exception string plus the classification and, when present, the status code. |

### TomPermanentDeliveryException

A `TomDeliveryException` the scheduler will not retry. A separate type only so
it can carry the kernel's `TomPermanentFailure` marker; callers should reach it
through `TomDeliveryException.permanent`.

- **Extends:** `TomDeliveryException`
- **Mixes in:** `TomPermanentFailure`

#### Constructors

```dart
TomPermanentDeliveryException(
  String key,
  String defaultUserMessage, {
  int? statusCode,
  Map<String, Object?>? parameters,
  Object? rootException,
  Object? stack,
})
```

### TomMessageTransport

One delivery channel. An implementation does a single attempt at one message and
reports the outcome; it must not retry, queue, or decide whether to send. It
throws a classified `TomDeliveryException` rather than returning a failed
receipt, so a caller who ignores the return value cannot silently drop a
message.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomMessageTransport()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `TomMessageChannel` | *(getter)* The channel this transport delivers; supplied by the implementation. |
| `supportsCopies` | `bool` | *(getter)* Whether the transport can express `Cc`/`Bcc`. `false` by default, declared rather than assumed so copies are never quietly promoted to primary recipients. |
| `supportsAttachments` | `bool` | *(getter)* Whether the transport can carry `TomAttachment`s. `false` by default. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | Delivers `message` once, throwing `TomDeliveryException` on failure. Supplied by the implementation. |
| `close` | `Future<void> close()` | Releases whatever the transport owns; does nothing by default. |
| `checkSupported` | `void checkSupported(TomMessage message)` | Called by implementations from `send`. Raises a permanent failure when the message is for another channel, carries attachments this transport cannot, or asks for copies it cannot express. |

### TomMessageRouter

Resolves a message's channel to the transport that delivers it. This is what
makes `email` a name in a spec rather than a class reference: the spec says
which channel, the deployment says which transport.

#### Constructors

```dart
TomMessageRouter([Iterable<TomMessageTransport> transports = const []])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channels` | `List<TomMessageChannel>` | *(getter)* The channels that currently have a transport. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomMessageTransport transport)` | Registers `transport` for its own channel, replacing any previous one. |
| `deregister` | `void deregister(TomMessageChannel channel)` | Removes the transport registered for `channel`, if any. |
| `supports` | `bool supports(TomMessageChannel channel)` | Whether `channel` can be delivered. |
| `transportFor` | `TomMessageTransport transportFor(TomMessage message)` | The transport for the message's channel. An unrouted channel is a permanent failure — no amount of retrying adds a transport. |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | Delivers `message` through its channel's transport. `async` deliberately, so the unrouted-channel failure arrives on the returned future rather than being thrown synchronously. |
| `close` | `Future<void> close()` | Closes every registered transport and clears the registry. |

### TomMemoryMessageTransport

A transport that keeps everything it is given and sends nothing — the test
stand-in. It accepts copies and attachments deliberately: a stand-in that
rejected what the real transport accepts would make tests pass and production
fail.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomMemoryMessageTransport({TomMessageChannel channel = TomMessageChannel.email})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sent` | `List<TomMessage>` | Every message this transport was handed, in order (final). |
| `receipts` | `List<TomDeliveryReceipt>` | Every receipt it issued, in order (final). |
| `channel` | `TomMessageChannel` | *(override)* The channel this stand-in serves; defaults to email (final). |
| `failNext` | `TomDeliveryException?` | A failure to raise instead of accepting the next message, consumed on use — so a test can make exactly the first attempt fail and assert the retry succeeded. |
| `failAlways` | `TomDeliveryException?` | A failure to raise on every message; takes precedence over `failNext`. |
| `supportsCopies` | `bool` | *(getter)* *(override)* Always `true`. |
| `supportsAttachments` | `bool` | *(getter)* *(override)* Always `true`. |
| `count` | `int` | *(getter)* How many messages have been accepted. |
| `last` | `TomMessage?` | *(getter)* The most recently accepted message, or `null`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clear` | `void clear()` | Forgets every recorded message and receipt. |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Raises the configured failure if one is armed, otherwise records the message and returns a `delivered` receipt whose `remoteId` counts the accepted messages. |

### TomNoOpMessageTransport

A transport that discards everything and records nothing — for a deployment that
must run with notifications configured but silenced. It reports `discarded`
rather than `delivered`, so a receipt never claims something reached a recipient
when it did not.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
const TomNoOpMessageTransport({
  TomMessageChannel channel = TomMessageChannel.email,
  bool logDiscarded = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `TomMessageChannel` | *(override)* The channel this stand-in serves; defaults to email (final). |
| `logDiscarded` | `bool` | Whether to log each discarded message at debug level (final). |
| `supportsCopies` | `bool` | *(getter)* *(override)* Always `true`. |
| `supportsAttachments` | `bool` | *(getter)* *(override)* Always `true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Optionally logs the message, sends nothing, and returns a `discarded` receipt. |

### TomFileMessageTransport

A transport that writes each message to an `.eml` file instead of sending it —
the local-development counterpart of the memory transport, for a developer who
wants to open the result in a mail client and see how the MIME tree came out.
Files are named `<stamp>_<id>.eml` from the message's `createdAt` and `id`.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomFileMessageTransport({
  required Directory directory,
  TomMessageChannel channel = TomMessageChannel.email,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `directory` | `Directory` | Where message files are written; created on construction if it does not exist (final). |
| `channel` | `TomMessageChannel` | *(override)* The channel this transport serves; defaults to email (final). |
| `supportsCopies` | `bool` | *(getter)* *(override)* Always `true`. |
| `supportsAttachments` | `bool` | *(getter)* *(override)* Always `true`. |
| `files` | `List<File>` | *(getter)* The `.eml` files written so far, sorted by path and so oldest first. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Writes the encoded message and returns a `delivered` receipt whose `remoteId` is the file path. A `FileSystemException` becomes a transient failure, since a full or unwritable disk is exactly the kind of thing that clears up. |

### TomMimeEncoder

Renders a `TomMessage` as an RFC 5322 document. Kept apart from the SMTP
transport so it is testable without a socket, and so a future transport that
submits mail some other way reuses the document rather than reimplementing it.
Headers are 7-bit (RFC 2047 encoded when they need to be), the body structure
follows the content, and there is never a `Bcc:` header.

#### Constructors

```dart
TomMimeEncoder({Random? random, DateTime Function()? clock})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encodeAddress` | `static String encodeAddress(TomRecipient recipient)` | Renders one address, encoding and quoting the display name when it needs it. Static so a transport can render an envelope address without building an encoder. |
| `encodeHeaderValue` | `static String encodeHeaderValue(String value, {bool quoteIfPlain = false})` | Encodes `value` for use in a header: pure US-ASCII passes through, anything else becomes an RFC 2047 base64 encoded-word. `quoteIfPlain` wraps an untouched value in quotes, which a display name needs and a subject does not. |
| `formatRfc5322Date` | `static String formatRfc5322Date(DateTime when)` | Formats `when` in the `Date:` header's fixed-width English, offset-numeric form — hand-rolled rather than locale-aware, because the RFC fixes the spelling. |
| `wrapBase64` | `static String wrapBase64(String encoded)` | Breaks `encoded` into `tomMimeMaxLineLength` columns, each terminated by `tomMimeLineEnding`, so no server refuses an over-long line. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `String encode(TomMessage message)` | Renders `message` as a complete RFC 5322 document: headers first (caller headers last, so an application header cannot displace a structural one), then the simplest body structure the content allows — a single part, `multipart/alternative`, `multipart/related` for inline attachments, `multipart/mixed` for listed ones. |

### TomMessageOutbox

A durable, retrying send queue in front of a `TomMessageRouter`. It owns no
retry logic: it enqueues one job run per message on a scheduler of its own that
dispatches inline, and durability, retry count, backoff, one-delivery-at-a-time
and failure alerting all remain the kernel scheduler's. The run id is
`'<jobName>:<messageId>'`, which makes the message its own idempotence key.

- **Implements:** `TomClosable`

#### Constructors

None — the generative constructor is private; instances are created through the
factory below.

#### Factory Constructors

```dart
factory TomMessageOutbox({
  required TomMessageRouter router,
  TomJobStore? store,
  String jobName = tomOutboxJobName,
  TomRetryPolicy retryPolicy = const TomRetryPolicy(
    maxAttempts: 5,
    initialBackoff: Duration(minutes: 1),
    maxBackoff: Duration(minutes: 30),
  ),
  Duration timeout = const Duration(minutes: 2),
  Duration tickInterval = const Duration(seconds: 15),
  DateTime Function()? clock,
  TomJobAlertSink? onAlert,
  TomLeaseLock? lock,
})
```

`store` defaults to a `TomMemoryJobStore`, which is right for tests and wrong
for production. `retryPolicy` defaults to five attempts rather than the
framework's three, because a relay's transient refusals — greylisting above
all — are routinely measured in minutes.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `router` | `TomMessageRouter` | Where messages are handed for actual delivery. Not owned: `close` leaves it open (final). |
| `jobName` | `String` | The name the delivery job is registered under (final). |
| `scheduler` | `TomScheduler` | The scheduler driving delivery; owned and closed by `close` (final). |
| `store` | `TomJobStore` | The queue behind `scheduler`, exposed so a caller can inspect what is pending, count failures, or purge history (final). |
| `receipts` | `Stream<TomDeliveryReceipt>` | *(getter)* A broadcast stream of every delivery that reached a transport, including partial ones and discards. Failures are not here — they go to the scheduler's `TomJobAlertSink`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<void> send(TomMessage message)` | Queues `message` and returns once it is durably stored. Enqueues directly rather than through the schedule's event stream, so two messages composed in the same instant are two runs. Throws `TomMessagingException` once the outbox is closed. |
| `sendNow` | `Future<void> sendNow(TomMessage message)` | Queues `message` and ticks immediately, for a case where the tick interval is felt by a human. A failure still retries on the queue exactly as `send` would. |
| `tick` | `Future<void> tick()` | Runs one delivery pass; exposed so a test can drive delivery without waiting on wall-clock time. |
| `start` | `void start()` | Begins delivering on the scheduler's tick interval. |
| `purgeFinished` | `Future<int> purgeFinished(DateTime before)` | Drops finished runs recorded before `before`, returning how many. Never called on your behalf: the completed runs are a delivery audit trail whose retention is a deployment's decision. |
| `close` | `void close()` | *(override)* Stops delivery, releases the scheduler and closes the receipt stream. The `router` is left open. |

### TomTemplatedMessageService

The rule every messaging channel shares, as a superclass rather than a
convention: **a message is a template key plus parameters**, resolved through
resource keys, failing loudly *before* anything is queued, and handed to the
outbox rather than to a transport. A convention re-implemented per channel
drifts invisibly — a third channel resolving through
`TomLocalizedTextResources.textOrNull` instead of `requiredText` would silently
gain the key-as-fallback behaviour messaging deliberately does not want.

`R` is the channel's request type. A request type with no field for user-facing
text is what makes the rule enforceable by the compiler.

- **Extends:** none
- **Type parameter:** `R` — `TomEmailRequest` or `TomSmsRequest`

#### Constructors

```dart
const TomTemplatedMessageService({
  required TomMessageOutbox outbox,
  required TomLocalizedTextResources texts,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `outbox` | `TomMessageOutbox` | Where rendered messages are queued. Not owned: closing it is the application's call, because one outbox usually carries every channel's traffic (final). |
| `texts` | `TomLocalizedTextResources` | The bundle set every template is resolved against (final). |
| `channelName` | `String` | *(abstract getter)* The channel's name as it appears in this service's error keys — `email`, `sms`. A missing SMS template must not report itself as an email fault. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(R request)` | *(abstract)* Turns a request into a message without queueing it — for a preview, a test, or a digest that renders many and queues one. Where every template fault surfaces, which is why `send` calls it before touching the queue. |
| `send` | `Future<void> send(R request)` | Renders and queues. `async` rather than a forwarding expression, so a template fault arrives as a failed future rather than as a synchronous throw from an otherwise-asynchronous API. |
| `sendNow` | `Future<void> sendNow(R request)` | Renders, queues and delivers immediately, for a message a human is waiting on. Retry behaviour is unchanged: only the first attempt skips the wait. |
| `deliverNow` | `Future<TomDeliveryReceipt> deliverNow(R request)` | Renders and delivers **now, reporting the outcome** — no queue, no retry. The deliberate exception to "always through the outbox", for a payload whose value expires before the retry budget would and whose non-arrival the caller must therefore learn about immediately (a second-factor code is the case it exists for). The trade is explicit: `send`/`sendNow` cannot fail for a transport reason, this one can. Returns the transport's own receipt, so a partial delivery — some recipients accepted, others refused — is visible rather than being flattened into a success or a throw. |
| `requiredText` | `String requiredText(String templateKey, String subKey, {TomTextLocale? locale, Map<String, Object?> parameters = const {}})` | Resolves `<templateKey>.<subKey>` or raises `TomMessagingException` (`messaging.<channelName>.template.missing`) naming the key and locale. Public for the **conditional fragment** — a sentence a body includes only sometimes, resolved on its own and passed in as a parameter. Resolve fragments fully before passing them in: substitution is one pass over the map. |

### TomEmailRequest

What to send, to whom, and with which values — but never *what it says*. There is
deliberately no subject or body field: an application email is a template key
plus parameters, so a literal user-facing string cannot be spelled through this
API.

- **Extends:** none

#### Constructors

```dart
TomEmailRequest({
  required String templateKey,
  required List<TomRecipient> to,
  TomTextLocale? locale,
  Map<String, Object?> parameters = const {},
  TomRecipient? from,
  TomRecipient? replyTo,
  List<TomAttachment> attachments = const [],
  Map<String, String>? headers,
  String? messageId,
})

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
})
```

An empty template key or an empty recipient list raises
`TomMessagingException`. `toPrincipal` derives the address from
`TomUser.email`, the display name from the user's names, and the locale from
`TomTextLocale.fromPrincipal`; a principal with no address raises rather than
producing a message with nowhere to go.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `templateKey` | `String` | The resource key prefix the subject and bodies live under (final). |
| `to` | `List<TomRecipient>` | Who receives it; copies are expressed by each recipient's own `TomRecipientKind` (final). |
| `locale` | `TomTextLocale?` | The locale to render in; `null` uses the bundle set's default (final). |
| `parameters` | `Map<String, Object?>` | Values for the template's `{name}` placeholders (final). |
| `from` | `TomRecipient?` | The sender, when this mail needs one of its own. Normally `null` — the deployment default lives in `TomSmtpSettings.defaultFrom` (final). |
| `replyTo` | `TomRecipient?` | Where replies should go, when that is not the sender (final). |
| `attachments` | `List<TomAttachment>` | Files to attach (final). |
| `headers` | `Map<String, String>?` | Additional email headers (final). |
| `messageId` | `String?` | The message id, and therefore the idempotence key: two sends of a request carrying the same id are one queued message (final). |

### TomEmailService

Renders resource-keyed email in the recipient's locale and queues it on the
outbox. A template key resolves three sub-keys: `.subject` and `.text` are
mandatory, `.html` is optional. The asymmetry is deliberate — not every mail has
markup, but a mail with no plain-text part is a deliverability problem.

- **Extends:** `TomTemplatedMessageService<TomEmailRequest>`

#### Constructors

```dart
const TomEmailService({
  required TomMessageOutbox outbox,
  required TomLocalizedTextResources texts,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channelName` | `String` | *(override getter)* `email`. |
| `subjectSubKey` / `textSubKey` / `htmlSubKey` | `static const String` | The sub-keys a template key is suffixed with: `subject`, `text`, `html`. |

`outbox`, `texts`, `send`, `sendNow`, `deliverNow` and `requiredText` are inherited from
[TomTemplatedMessageService](#tomtemplatedmessageservice).

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(TomEmailRequest request)` | *(override)* Renders the request into a message without queueing it. Raises `TomMessagingException` (`messaging.email.template.missing`) when `.subject` or `.text` does not resolve. |
| `resolve` | `static TomEmailService? resolve()` | The service this deployment installed, or `null`. Nullable with no fallback: mail sent through invented infrastructure goes nowhere while looking as though it went. |

### TomSmtpSecurity

How the connection to the mail server is secured. An unrecognised configured
value falls back to `startTls`, so a typo cannot silently downgrade a deployment
to plaintext.

#### Values

| Value | Description |
| ----- | ----------- |
| `none` | Plain TCP, no encryption. For a relay reachable only over a trusted network — anything else sends the credential in the clear. Default port 25. |
| `startTls` | Plain TCP upgraded with `STARTTLS` after the greeting. Default port 587. |
| `implicitTls` | TLS from the first byte ("SMTPS"). Default port 465. |

### TomSmtpSettings

Everything needed to reach one mail server. Separate from the transport so it
can be built from a `TomBaseServerConfiguration` without the transport knowing
about configuration, and built literally in a test without a configuration
existing at all. Construction rejects a blank host, and rejects a username
supplied without a password — so a deployment that forgot the secret fails at
startup with a message naming the setting rather than on the first notification
with a `535`.

#### Constructors

```dart
TomSmtpSettings({
  required String host,
  int? port,
  TomSmtpSecurity security = TomSmtpSecurity.startTls,
  String? username,
  String? password,
  TomRecipient? defaultFrom,
  String clientName = 'localhost',
  Duration timeout = const Duration(seconds: 30),
  bool allowInsecureCertificate = false,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromConfiguration` | `static TomSmtpSettings? fromConfiguration(TomBaseServerConfiguration configuration)` | Reads settings from a configuration's `smtp*` fields, returning `null` when `smtpHost` is unset — which is how a deployment says "no mail", leaving the caller to register a `TomNoOpMessageTransport` instead of failing to start. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `host` | `String` | The mail server's host name (final). |
| `port` | `int` | The port; defaults from `security` when not given explicitly (final). |
| `security` | `TomSmtpSecurity` | How the connection is secured (final). |
| `username` | `String?` | The login name, or `null` for an unauthenticated relay (final). |
| `password` | `String?` | The password — never authored, supplied out-of-band at deploy time (final). |
| `defaultFrom` | `TomRecipient?` | The address messages are sent from when they do not name their own (final). |
| `clientName` | `String` | The name this client announces in `EHLO`; defaults to `localhost` (final). |
| `timeout` | `Duration` | How long to wait for the connection and for each reply; defaults to 30 seconds (final). |
| `allowInsecureCertificate` | `bool` | Whether to accept a server certificate that does not validate. `false`, and it should stay that way; it exists so a developer facing a self-signed cert does not disable TLS entirely (final). |
| `isAuthenticated` | `bool` | *(getter)* Whether a credential should be presented. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Host, port, security mode and login name. The password is never included, at any level. |

### TomSmtpTransport

Delivers `TomMessageChannel.email` over SMTP, speaking the protocol directly
rather than wrapping a mailer package — which is what lets every reply code map
to a retry judgement in one documented place. One connection per message: the
right default for a server whose mail is occasional, and a cost the outbox is
already absorbing asynchronously.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomSmtpTransport(
  TomSmtpSettings settings, {
  TomMimeEncoder? encoder,
  Future<TomSmtpConnection> Function(TomSmtpSettings settings)? connect,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `settings` | `TomSmtpSettings` | Where and how to connect (final). |
| `encoder` | `TomMimeEncoder` | Renders the message document; injectable so a test can pin the boundaries and the date (final). |
| `connect` | `Future<TomSmtpConnection> Function(TomSmtpSettings settings)` | Opens the connection, defaulting to `TomSocketSmtpConnection.open`; injectable so the protocol can be tested against an in-process fake server (final). |
| `channel` | `TomMessageChannel` | *(getter)* *(override)* Always `TomMessageChannel.email`. |
| `supportsCopies` | `bool` | *(getter)* *(override)* Always `true`. |
| `supportsAttachments` | `bool` | *(getter)* *(override)* Always `true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Runs one conversation — greeting, `EHLO` falling back to `HELO`, `STARTTLS` and re-greet when configured, `AUTH PLAIN` or `LOGIN` when credentials are set, `MAIL FROM`, one `RCPT TO` per envelope address, `DATA` and the document, then a best-effort `QUIT`. A message with no sender and no configured default fails permanently; an unreachable relay fails transiently; refused recipients are collected onto the receipt unless every one is refused. |

### TomSmtpReply

One SMTP reply: its code and the text of every line. The predicates below carry
the protocol's own classification, which is what every retry decision keys off.

#### Constructors

```dart
const TomSmtpReply(int code, List<String> lines)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `code` | `int` | The three-digit reply code (final). |
| `lines` | `List<String>` | The reply's lines, without their code prefixes (final). |
| `text` | `String` | *(getter)* The reply's text, lines joined with spaces. |
| `isPositive` | `bool` | *(getter)* Whether the command succeeded (`2xx`). |
| `isIntermediate` | `bool` | *(getter)* Whether the server wants more input (`3xx`). |
| `isTransientNegative` | `bool` | *(getter)* Whether the failure is worth retrying (`4xx`). |
| `isPermanentNegative` | `bool` | *(getter)* Whether the failure is final (`5xx`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The code followed by the joined text. |

### TomSmtpConnection

The socket half of an SMTP conversation. An interface rather than a concrete
socket so the protocol logic in `TomSmtpTransport` is testable end to end
without a mail server: a missing `STARTTLS`, a rejected credential, a partially
refused recipient list and a `4xx` deferral are all reachable against a scripted
fake, and none of them is conveniently reachable against a real relay.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `write` | `Future<void> write(String command)` | Sends one command line. |
| `writeData` | `Future<void> writeData(String data)` | Sends the message body and the terminating `.`. |
| `readReply` | `Future<TomSmtpReply> readReply()` | Reads one complete reply, following multi-line continuations. |
| `upgradeToTls` | `Future<void> upgradeToTls()` | Upgrades the connection to TLS after a `220` to `STARTTLS`. |
| `close` | `Future<void> close()` | Closes the connection. |

### TomSocketSmtpConnection

A `TomSmtpConnection` over a real `dart:io` socket, reading replies off a
line-split stream.

- **Implements:** `TomSmtpConnection`

#### Constructors

None — the constructor is private; obtain instances via
`TomSocketSmtpConnection.open`.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `static Future<TomSmtpConnection> open(TomSmtpSettings settings)` | Connects per `settings`, using a `SecureSocket` for `implicitTls` and a plain `Socket` otherwise, honouring the configured timeout and insecure-certificate allowance. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `write` | `Future<void> write(String command)` | *(override)* Writes `command` terminated by `tomMimeLineEnding` and flushes. |
| `writeData` | `Future<void> writeData(String data)` | *(override)* Writes the body with dot-stuffing — any line starting with `.` is escaped, or the message would be truncated there — then the terminating `.` line. |
| `readReply` | `Future<TomSmtpReply> readReply()` | *(override)* Accumulates continuation lines until one carries a space in the fourth column. A connection that closes mid-reply is a transient failure, because no answer at all is not a refusal. |
| `upgradeToTls` | `Future<void> upgradeToTls()` | *(override)* Secures the existing socket and re-attaches the line reader to it. |
| `close` | `Future<void> close()` | *(override)* Cancels the line reader and closes then destroys the socket, ignoring errors — the delivery outcome was decided before this point. |

### TomSmsEncoding

The alphabet a message will be encoded in on the wire. One character outside
GSM 03.38 moves the **whole message** to UCS-2.

#### Values

| Value | Description |
| ----- | ----------- |
| `gsm7` | The GSM 03.38 7-bit alphabet: 160 units in a single message, 153 per part when concatenated. |
| `ucs2` | UTF-16: 70 units single, 67 per part. |

### TomSmsSegmentation

How long a message is in the unit that is actually billed. Characters are the
wrong unit, and every SMS integration that counts them eventually discovers why:
a non-GSM character cuts capacity from 160 to 70, ten GSM characters
(`^ { } \ [ ~ ] |`, form feed and `€`) cost two units each, and a concatenated
message spends seven bits per part on a header — so the 161st character adds
*eight* characters' worth of segment, not one.

Packing is a greedy walk rather than a division, because a character never
straddles a segment boundary.

- **Extends:** none

#### Constructors

```dart
factory TomSmsSegmentation.of(String text)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `encoding` | `TomSmsEncoding` | The alphabet the message needs (final). |
| `units` | `int` | The billable length in `encoding`'s units (final). |
| `segments` | `int` | How many messages the gateway will send, and charge for (final). |
| `singleCapacity` | `int` | *(getter)* How many units fit when the message is a single part — 160 or 70. |
| `partCapacity` | `int` | *(getter)* How many units fit in each part of a concatenated message — 153 or 67. |
| `isMultipart` | `bool` | *(getter)* Whether the message will be split. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Encoding, unit count and segment count. |

### TomSmsAuthScheme

How the gateway credential is presented.

#### Values

| Value | Description |
| ----- | ----------- |
| `none` | No credential in the transport layer; the gateway takes it in the payload (see `TomFieldMappedSmsProtocol.apiKeyField`) or not at all. |
| `bearer` | `Authorization: Bearer <apiKey>`. The default, and where an unrecognised configured value lands — so a typo cannot silently drop the credential and send unauthenticated requests to a paid API. |
| `basic` | `Authorization: Basic base64(apiKey:apiSecret)`. |

### TomSmsGatewaySettings

Everything needed to reach one SMS gateway. Separate from the transport for the
same reason `TomSmtpSettings` is: it can be built from a
`TomBaseServerConfiguration` without the transport knowing about configuration,
and built literally in a test without a configuration existing at all.

- **Extends:** none

#### Constructors

```dart
TomSmsGatewaySettings({
  required Uri endpoint,
  String? apiKey,
  String? apiSecret,
  String? senderId,
  TomSmsAuthScheme authScheme = TomSmsAuthScheme.bearer,
  Duration timeout = const Duration(seconds: 30),
  int maxSegments = 3,
})
```

Rejects an endpoint that is not `http` or `https`, and a `basic` scheme missing
either half of its credential — both at construction, so a deployment that
mistyped a setting fails at startup naming it rather than on the first send.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `endpoint` | `Uri` | The gateway's submission URL (final). |
| `apiKey` | `String?` | The account identifier or API key — **secret-bearing**, never authored (final). |
| `apiSecret` | `String?` | The second half of a paired credential (final). |
| `senderId` | `String?` | The default sender shown on the handset, used when a message does not name its own (final). |
| `authScheme` | `TomSmsAuthScheme` | How `apiKey` and `apiSecret` are presented (final). |
| `timeout` | `Duration` | How long to wait for the gateway to answer (final). |
| `maxSegments` | `int` | The most segments a single message may occupy; `0` means no cap (final). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromConfiguration` | `static TomSmsGatewaySettings? fromConfiguration(TomBaseServerConfiguration configuration)` | Reads the `sms*` fields. Returns `null` when `smsEndpoint` is unset — how a deployment says "no SMS", answered by registering a `TomNoOpMessageTransport` rather than failing to start. An endpoint that is *set but unusable* throws: someone meant to send. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Host, path, scheme and sender id. Never includes the credential, at any level. |

### TomSmsSubmission

One message to one number, measured and ready to encode. The value a
`TomSmsGatewayProtocol` maps from, so `encode` stays a pure function.

- **Extends:** none

#### Constructors

```dart
const TomSmsSubmission({
  required String messageId,
  required String to,
  required String text,
  required TomSmsSegmentation segmentation,
  String? from,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `messageId` | `String` | The `TomMessage.id` this submission belongs to (final). |
| `to` | `String` | The destination number (final). |
| `from` | `String?` | The sender id, or `null` when the gateway supplies one (final). |
| `text` | `String` | The text to send (final). |
| `segmentation` | `TomSmsSegmentation` | What it will cost (final). |

### TomSmsBodyFormat

Which body encoding the gateway expects.

#### Values

| Value | Description |
| ----- | ----------- |
| `form` | `application/x-www-form-urlencoded`. |
| `json` | `application/json`. |

### TomSmsGatewayRequest

One HTTP request to a gateway, before it becomes a kernel server call. A value
rather than a call, so a protocol's `encode` can be asserted on without a
client.

- **Extends:** none

#### Constructors

```dart
const TomSmsGatewayRequest({
  required Uri url,
  String method = 'POST',
  Map<String, String> headers = const {},
  String? body,
  Map<String, String>? fields,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `url` | `Uri` | Where to send it (final). |
| `method` | `String` | The HTTP method (final). |
| `headers` | `Map<String, String>` | The headers, including any credential (final). |
| `body` | `String?` | The body, for `TomSmsBodyFormat.json` (final). |
| `fields` | `Map<String, String>?` | The body, for `TomSmsBodyFormat.form`. Exactly one of this and `body` is set (final). |

### TomSmsGatewayAnswer

What a gateway said, in the only terms the outbox cares about.

- **Extends:** none

#### Constructors

```dart
const TomSmsGatewayAnswer({
  required bool isAccepted,
  String? remoteId,
  String? detail,
  bool? isPermanent,
  String? providerCode,
})

const TomSmsGatewayAnswer.accepted({String? remoteId, String? detail})

const TomSmsGatewayAnswer.rejected({
  bool? permanent,
  String? detail,
  String? providerCode,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isAccepted` | `bool` | Whether the gateway took the message (final). |
| `remoteId` | `String?` | The gateway's own id, for correlation with a delivery report (final). |
| `detail` | `String?` | A human-readable explanation, for the receipt and the alert (final). |
| `isPermanent` | `bool?` | Whether a refusal is final. **Three-valued**: `null` means the payload did not say, and the transport falls back to the HTTP status. A protocol forced to choose would guess *permanent* and lose a rate-limited message, or *transient* and spend the retry budget on an invalid number (final). |
| `providerCode` | `String?` | The vendor's error code, as written (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Accepted or rejected, with the provider code when there is one. |

### TomSmsGatewayProtocol

Turns a submission into a gateway request and an answer back into a judgement.
The whole vendor surface lives behind these two methods — provider specifics
confined to the transport, and within the transport confined to the protocol.

- **Extends:** none (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `requiresSender` | `bool` | *(getter, default `false`)* Whether the gateway requires a sender id on every submission. Deployments differ — a short-code account has one sender and rejects the field; an alphanumeric-sender account requires it — and saying so here lets the transport fail at composition rather than posting a request it knows will be refused. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `TomSmsGatewayRequest encode(TomSmsSubmission submission, TomSmsGatewaySettings settings)` | *(abstract)* Builds the request for one message to one number. |
| `decode` | `TomSmsGatewayAnswer decode(int statusCode, String body)` | *(abstract)* Reads the gateway's answer. `statusCode` is supplied so a protocol *can* use it, not so it must: the transport applies its own status rule to anything left undecided. |
| `authorizationHeaders` | `Map<String, String> authorizationHeaders(TomSmsGatewaySettings settings)` | The `Authorization` header for `settings`, or nothing. Provided on the base so a deployment writing its own protocol inherits credential handling instead of re-deriving base64. |

### TomFieldMappedSmsProtocol

A protocol described by field names and response paths rather than by code —
enough to reach the common HTTP gateways, all of which do the same thing in
different words. **No per-vendor preset ships**: a preset for an API this
repository cannot test against is a plausible-looking guess whose failure gets
attributed to the framework.

- **Extends:** `TomSmsGatewayProtocol`

#### Constructors

```dart
const TomFieldMappedSmsProtocol({
  TomSmsBodyFormat format = TomSmsBodyFormat.form,
  String method = 'POST',
  String toField = 'to',
  String? fromField = 'from',
  String textField = 'text',
  String? apiKeyField,
  String? apiSecretField,
  Map<String, String> extraFields = const {},
  bool requiresSender = false,
  String? statusPath,
  Set<String> acceptedStatuses = const {},
  String? remoteIdPath,
  String? errorCodePath,
  String? errorMessagePath,
  Set<String> permanentErrorCodes = const {},
  Set<String> transientErrorCodes = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `format` / `method` | `TomSmsBodyFormat` / `String` | How the body is encoded, and the HTTP method (final). |
| `toField` / `fromField` / `textField` | `String` / `String?` / `String` | The fields carrying the destination number, the sender id and the message text (final). |
| `apiKeyField` / `apiSecretField` | `String?` | The fields carrying the credential, for gateways that take it in the payload rather than in a header (final). |
| `extraFields` | `Map<String, String>` | Constant fields every submission carries — a route class, an account sid, a callback URL (final). |
| `requiresSender` | `bool` | *(override)* Whether every submission must name a sender (final). |
| `statusPath` | `String?` | The dotted path to the status value, or `null` to trust the HTTP status (final). |
| `acceptedStatuses` | `Set<String>` | The status values meaning "taken", compared case-insensitively (final). |
| `remoteIdPath` / `errorCodePath` / `errorMessagePath` | `String?` | Dotted paths to the gateway's message id, error code and error message (final). |
| `permanentErrorCodes` / `transientErrorCodes` | `Set<String>` | Codes meaning "never going to work" and "not right now". A code in neither set leaves `isPermanent` `null` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `TomSmsGatewayRequest encode(TomSmsSubmission submission, TomSmsGatewaySettings settings)` | *(override)* Assembles the mapped fields, form- or JSON-encoded, with the credential in a header or in the payload as configured. |
| `decode` | `TomSmsGatewayAnswer decode(int statusCode, String body)` | *(override)* Reads status, id, code and message off the configured paths. A configured `statusPath` that does not resolve is **not** a success — treating silence as acceptance is how a maintenance page becomes a delivered message. A body that is not JSON is not an error either: it is an answer the transport's status rule can still classify. |

### TomSmsTransport

Delivers `TomMessageChannel.sms` through an HTTP gateway. One request per
recipient: a gateway that accepted a list would save requests and cost the
receipt its per-number outcome, and partial delivery is the case that matters.

Neither copies nor attachments are supported — the base defaults were already
the right answer for SMS, which is part of the evidence that
`TomMessageTransport` was genuinely channel-agnostic rather than email-shaped.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomSmsTransport(
  TomSmsGatewaySettings settings,
  TomSmsGatewayProtocol protocol, {
  TomServerChannel Function(TomSmsGatewaySettings settings)? openChannel,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `settings` | `TomSmsGatewaySettings` | Where and how to reach the gateway (final). |
| `protocol` | `TomSmsGatewayProtocol` | The vendor mapping (final). |
| `openChannel` | `TomServerChannel Function(TomSmsGatewaySettings)` | Opens the connection. Injectable so the whole classification is testable against a scripted client without a socket — the seam `TomSmtpTransport.connect` provides (final). |
| `channel` | `TomMessageChannel` | *(override getter)* `TomMessageChannel.sms`. |
| `senderIdMetadataKey` | `static const String` | `'senderId'` — the `TomMessage.metadata` key a message uses to name its own sender id. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isTransientStatus` | `static bool isTransientStatus(int status)` | Whether an HTTP status is worth trying again: `408`, `425`, `429` and `5xx`. Every other non-`2xx` says the request was wrong, and a retry sends the same wrong request. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Measures the text, then submits it once per recipient. Permanent before any request leaves: no text, no sender when the protocol requires one, or more segments than `settings.maxSegments`. Permanent after: every recipient rejected. Otherwise a `delivered` receipt carrying `rejectedRecipients`. A **transient** answer stops the pass rather than continuing — a rate limit applies to the account, not to one number, and continuing would make the retry double-send the recipients already delivered to. |
| `close` | `Future<void> close()` | *(override)* Closes the lazily-created channel. |

The gateway call sets `includeBearerAuthentication: false`, because the kernel
call layer would otherwise inject the *caller's* bearer token — handing a user
credential to a third party.

### TomSmsRequest

What to send, to which number, and with which values — but never *what it says*.
There is deliberately no text field, for the reason `TomEmailRequest` has no
subject field.

- **Extends:** none

#### Constructors

```dart
TomSmsRequest({
  required String templateKey,
  required List<TomRecipient> to,
  TomTextLocale? locale,
  Map<String, Object?> parameters = const {},
  String? from,
  String? messageId,
})

factory TomSmsRequest.toPrincipal({
  required String templateKey,
  required TomPrincipal principal,
  Map<String, Object?> parameters = const {},
  TomTextLocale? locale,
  String? from,
  String? messageId,
})
```

`toPrincipal` prefers `TomUser.mobile` and falls back to `TomUser.phone` — the
ordering matters, because a landline that silently swallows a two-factor code is
a support call nobody can diagnose. A principal reachable by neither raises
`TomMessagingException` (`messaging.sms.principal.no_number`) here, at
composition, where the caller still knows *which user* it was reaching.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `templateKey` | `String` | The resource key prefix the text lives under (final). |
| `to` | `List<TomRecipient>` | The destination numbers. `TomRecipient.address` is a phone number here (final). |
| `locale` | `TomTextLocale?` | The locale to render in; `null` uses the bundle set's default (final). |
| `parameters` | `Map<String, Object?>` | Values for the template's `{name}` placeholders (final). |
| `from` | `String?` | The sender id, when this message needs one of its own (final). |
| `messageId` | `String?` | The **idempotence key** — two sends carrying the same id are one queued message. Matters more here than for mail: an SMS costs money per send, and "resend code" is exactly the case to key (final). |

### TomSmsService

Renders resource-keyed SMS and queues it on the outbox. One sub-key instead of
three: an SMS has a body and nothing else, so `<templateKey>.text` is the whole
template.

- **Extends:** `TomTemplatedMessageService<TomSmsRequest>`

#### Constructors

```dart
const TomSmsService({
  required TomMessageOutbox outbox,
  required TomLocalizedTextResources texts,
  int? maxSegments,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxSegments` | `int?` | The most segments a message composed here may occupy, or `null` for no application-level cap. `null` by default because the deployment already has one in `TomSmsGatewaySettings.maxSegments`, and two defaults that disagree produce a message refused by whichever is stricter and reported by whichever the operator did not set (final). |
| `channelName` | `String` | *(override getter)* `sms`. |
| `textSubKey` | `static const String` | `text` — the whole template, on this channel. |

`outbox`, `texts`, `send`, `sendNow`, `deliverNow` and `requiredText` are inherited from
[TomTemplatedMessageService](#tomtemplatedmessageservice).

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(TomSmsRequest request)` | *(override)* Resolves `.text`, measures the result, and raises `TomMessagingException` (`messaging.sms.too_long`, carrying `segments`) when it exceeds `maxSegments`. Both faults surface before the outbox, so neither becomes a queued message somebody pays for. |
| `segmentationOf` | `TomSmsSegmentation segmentationOf(TomSmsRequest request)` | What `request` will cost, without sending or capping it. Renders first, so the answer accounts for the parameters — which is where the surprises live. Deliberately does not throw: a measurement used to *decide* whether a message is too long cannot be one that raises when it is. |
| `resolve` | `static TomSmsService? resolve()` | The service this deployment installed, or `null`. Nullable with no fallback, for the reason `TomEmailService.resolve` is. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomMimeLineEnding` | `const String` | `\r\n`, the line ending every mail protocol requires. A bare `\n` is accepted by some servers and silently corrupts the message on others. |
| `tomMimeMaxLineLength` | `const int` | `76` — the maximum line length RFC 5322 permits, excluding the line ending. |
| `tomOutboxJobName` | `const String` | `'messaging.outbox'`, the default job name the outbox registers under. Stable across restarts by necessity: it is the store key tying queued runs to the definition that knows how to execute them. |

### Functions

None — this module exposes no top-level functions.
