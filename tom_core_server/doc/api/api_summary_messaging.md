# Tom Core Server API Reference: Messaging Module

The outbound message substrate: a channel-neutral message shape, a transport
contract, four real implementations — SMTP, an HTTP SMS gateway, push through
FCM, APNs or a described service, and an HTTP webhook — stand-in
transports for tests and local runs, a durable outbox that queues delivery onto
the kernel's job scheduler, and the templating layer above it that composes
every channel's messages from resource keys — and, on the receiving side of a
message broker, the idempotent receiver (inbox) that processes a redelivered
message once; and, on the sending side of a message bus, the bus relay that
publishes a message once the transaction it was queued in has committed.

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
  - [TomBusRelay](#tombusrelay)
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
  - [TomPushSubmission](#tompushsubmission)
  - [TomPushGatewayRequest](#tompushgatewayrequest)
  - [TomPushGatewayResponse](#tompushgatewayresponse)
  - [TomPushGatewayAnswer](#tompushgatewayanswer)
  - [TomPushExchange](#tompushexchange)
  - [TomHttp1PushExchange](#tomhttp1pushexchange)
  - [TomHttp2PushExchange](#tomhttp2pushexchange)
  - [TomPushCredential](#tompushcredential)
  - [TomStaticPushCredential](#tomstaticpushcredential)
  - [TomApnsProviderToken](#tomapnsprovidertoken)
  - [TomFcmServiceAccountCredential](#tomfcmserviceaccountcredential)
  - [TomPushProtocol](#tompushprotocol)
  - [TomFcmPushProtocol](#tomfcmpushprotocol)
  - [TomApnsPushProtocol](#tomapnspushprotocol)
  - [TomFieldMappedPushProtocol](#tomfieldmappedpushprotocol)
  - [TomPushTransport](#tompushtransport)
  - [TomPushRequest](#tompushrequest)
  - [TomPushService](#tompushservice)
  - [TomWebhookSettings](#tomwebhooksettings)
  - [TomWebhookTransport](#tomwebhooktransport)
  - [TomDeliveryReport](#tomdeliveryreport)
  - [TomDeliveryState](#tomdeliverystate)
  - [TomDeliveryCorrelation](#tomdeliverycorrelation)
  - [TomDeliveryReportStore](#tomdeliveryreportstore)
  - [TomMemoryDeliveryReportStore](#tommemorydeliveryreportstore)
  - [TomSqlDeliveryReportStore](#tomsqldeliveryreportstore)
  - [TomDeliveryReportRow](#tomdeliveryreportrow)
  - [TomDeliveryCallback](#tomdeliverycallback)
  - [TomDeliveryReportProtocol](#tomdeliveryreportprotocol)
  - [TomFieldMappedDeliveryReportProtocol](#tomfieldmappeddeliveryreportprotocol)
  - [TomDeliveryCallbackRequest](#tomdeliverycallbackrequest)
  - [TomDeliveryCallbackVerifier](#tomdeliverycallbackverifier)
  - [TomSharedSecretCallbackVerifier](#tomsharedsecretcallbackverifier)
  - [TomTwilioCallbackVerifier](#tomtwiliocallbackverifier)
  - [TomVonageSignatureMethod](#tomvonagesignaturemethod)
  - [TomVonageCallbackVerifier](#tomvonagecallbackverifier)
  - [TomDeliveryReportEndpoint](#tomdeliveryreportendpoint)
  - [TomDeliveryReportService](#tomdeliveryreportservice)
  - [TomDeliveryReportServer](#tomdeliveryreportserver)
  - [TomSuppressedAddress](#tomsuppressedaddress)
  - [TomSuppressionList](#tomsuppressionlist)
  - [TomMemorySuppressionList](#tommemorysuppressionlist)
  - [TomSqlSuppressionList](#tomsqlsuppressionlist)
  - [TomSuppressionRow](#tomsuppressionrow)
  - [TomInboxException](#tominboxexception)
  - [TomInboxOutcome](#tominboxoutcome)
  - [TomInbox](#tominbox)
  - [TomMemoryInbox](#tommemoryinbox)
  - [TomSqlInbox](#tomsqlinbox)
  - [TomInboxRow](#tominboxrow)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/messaging/bus_relay.dart`, `lib/src/tomserver/messaging/delivery_callback_verifier.dart`, `lib/src/tomserver/messaging/delivery_report.dart`, `lib/src/tomserver/messaging/delivery_report_endpoint.dart`, `lib/src/tomserver/messaging/delivery_report_sql.dart`, `lib/src/tomserver/messaging/email_service.dart`, `lib/src/tomserver/messaging/inbox.dart`, `lib/src/tomserver/messaging/inbox_sql.dart`, `lib/src/tomserver/messaging/message.dart`, `lib/src/tomserver/messaging/message_transport.dart`, `lib/src/tomserver/messaging/mime_encoder.dart`, `lib/src/tomserver/messaging/outbox.dart`, `lib/src/tomserver/messaging/push_service.dart`, `lib/src/tomserver/messaging/push_transport.dart`, `lib/src/tomserver/messaging/sms_service.dart`, `lib/src/tomserver/messaging/sms_transport.dart`, `lib/src/tomserver/messaging/smtp_transport.dart`, `lib/src/tomserver/messaging/sql_delivery_report_store.dart`, `lib/src/tomserver/messaging/sql_suppression_list.dart`, `lib/src/tomserver/messaging/suppression_list.dart`, `lib/src/tomserver/messaging/suppression_sql.dart`, `lib/src/tomserver/messaging/templated_message_service.dart`, `lib/src/tomserver/messaging/vendor_mapping.dart`, `lib/src/tomserver/messaging/webhook_transport.dart`.

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

Six transports implement the contract. `TomSmtpTransport` speaks the protocol
directly over `TomSmtpConnection` — implemented for real sockets by
`TomSocketSmtpConnection`, and reading each `TomSmtpReply`'s code to decide
whether a failure is worth repeating — configured by `TomSmtpSettings` and
`TomSmtpSecurity`. `TomSmsTransport` reaches an HTTP gateway configured by
`TomSmsGatewaySettings` and `TomSmsAuthScheme`, with the vendor's vocabulary
behind a `TomSmsGatewayProtocol` (`TomFieldMappedSmsProtocol` describes the
common ones in configuration) that maps a `TomSmsSubmission` to a
`TomSmsGatewayRequest` and a response back to a `TomSmsGatewayAnswer`;
`TomSmsSegmentation` and `TomSmsEncoding` supply the GSM 03.38 length
arithmetic an SMS is billed by. `TomPushTransport` delivers to device tokens
through a `TomPushProtocol` — `TomFcmPushProtocol`, `TomApnsPushProtocol`, or a
`TomFieldMappedPushProtocol` describing another service — authenticated by a
`TomPushCredential` (`TomFcmServiceAccountCredential`, `TomApnsProviderToken`,
`TomStaticPushCredential`) over a `TomPushExchange` (`TomHttp1PushExchange`,
`TomHttp2PushExchange`), mapping a `TomPushSubmission` to a
`TomPushGatewayRequest` and a `TomPushGatewayResponse` back to a
`TomPushGatewayAnswer`. `TomMemoryMessageTransport`,
`TomNoOpMessageTransport` and `TomFileMessageTransport` are the stand-ins for
tests, silenced deployments and local development. `TomMimeEncoder` renders the
RFC 5322 / MIME document the SMTP transport transfers, choosing the simplest
structure the content allows and never writing a `Bcc:` header.

*Semantics* is `TomMessageOutbox`, a durable send queue in front of a router. It
owns no retry logic: it enqueues one job run per message on an
inline-dispatching scheduler of its own, and durability, backoff, at-most-one
runner per message and failure alerting all remain the kernel scheduler's.

*Templating* is `TomTemplatedMessageService` and its three subclasses. A request
names a template key and supplies parameters; `TomEmailRequest` has **no subject
and no body field**, `TomSmsRequest` has **no text field** and `TomPushRequest`
has **no title or body field**, so there is no way to spell a literal
user-facing string through any of them. The base owns `send`,
`sendNow`, `deliverNow` and `requiredText`; a subclass supplies only its channel name and how
one of its requests becomes a `TomMessage`. `TomEmailService` resolves
`<templateKey>.subject`, `.text` and (optionally) `.html` against a
`TomLocalizedTextResources` bundle set in the recipient's locale;
`TomSmsService` resolves `.text` alone and additionally measures the result,
refusing a message over its segment budget; `TomPushService` resolves `.title`
and `.body`. Each renders a `TomMessage` and hands it to the outbox — never to a
transport — and each raises before anything is queued.

*Delivery reports* are the carrier's word on a message after it accepted it:
`TomDeliveryReport` and `TomDeliveryState`, matched to the message through the
`TomDeliveryCorrelation` index (`TomDeliveryReportStore`,
`TomMemoryDeliveryReportStore`, `TomSqlDeliveryReportStore`), read from the
carrier's callback by a `TomDeliveryReportProtocol`, and received on
`POST`/`GET /messaging/delivery-report` by `TomDeliveryReportService`. The route is
public and gated by the `TomDeliveryCallbackVerifier` the installation chooses:
`TomSharedSecretCallbackVerifier` (a secret in a header),
`TomTwilioCallbackVerifier` (`X-Twilio-Signature`) or
`TomVonageCallbackVerifier` (the `sig` parameter, with a replay window), each
judging a `TomDeliveryCallbackRequest`.

*Receiving* is `TomInbox`, the idempotent receiver a consumer of a message
broker wraps its handler in. `process` records the `(consumer, message id)`
pair and runs the consumer's work in one transaction, answers a
`TomInboxOutcome`, and calls the broker's acknowledgement only after the commit
— for a duplicate too — so a redelivered message is recognised and a failed one
is processed again. `TomSqlInbox` keeps the records in `tom_message_inbox`,
declared once by `inboxTable` (`inboxTableDdl`, `defaultInboxTable`) and read
back as `TomInboxRow`, in the data source the consumer's work writes to;
`TomMemoryInbox` keeps them in memory for tests. The inbox knows no broker.

*Publishing to a bus* is `TomBusRelay`, the transactional outbox for a
`TomMessageBus` of `tom_core_message_bus`. `publish` writes one job run per
message — `'<jobName>:<messageId>'`, under `tomBusRelayJobName` unless another
name is given — to the relay's `TomJobStore`, in the caller's transaction on a
`TomSqlJobStore`, and the relay's own scheduler publishes it to the bus after
the commit, under the queued message id, in the trace the publish was queued
in, retrying a publish the bus refused.

`TomMessagingException` is the module's base error, from which every failure
above derives — except `TomInboxException`, the inbox's refusal of an empty or
over-long consumer name or message id, which extends `TomServerException`
directly.

## Class Hierarchy

```
TomServerException  (little_things)
    ├── TomMessagingException
    │       └── TomDeliveryException
    │               └── TomPermanentDeliveryException
    └── TomInboxException

TomMessageTransport  (abstract)
    ├── TomMemoryMessageTransport
    ├── TomNoOpMessageTransport
    ├── TomFileMessageTransport
    ├── TomSmtpTransport
    ├── TomSmsTransport
    └── TomPushTransport

TomSmtpConnection  (abstract)
    └── TomSocketSmtpConnection  (implements)

TomSmsGatewayProtocol  (abstract)
    └── TomFieldMappedSmsProtocol

TomPushProtocol  (abstract)
    ├── TomFcmPushProtocol
    ├── TomApnsPushProtocol
    └── TomFieldMappedPushProtocol

TomPushCredential  (abstract)
    ├── TomStaticPushCredential
    ├── TomApnsProviderToken
    └── TomFcmServiceAccountCredential

TomPushExchange  (abstract)
    ├── TomHttp1PushExchange
    └── TomHttp2PushExchange

TomDeliveryCallbackVerifier  (abstract)
    ├── TomSharedSecretCallbackVerifier
    ├── TomTwilioCallbackVerifier
    └── TomVonageCallbackVerifier

TomInbox  (abstract)
    ├── TomMemoryInbox
    └── TomSqlInbox

TomTemplatedMessageService<R>  (abstract)
    ├── TomEmailService     (R = TomEmailRequest)
    ├── TomSmsService       (R = TomSmsRequest)
    └── TomPushService      (R = TomPushRequest)

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
TomBusRelay  (implements TomClosable)
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
TomPushSubmission
TomPushGatewayRequest
TomPushGatewayResponse
TomPushGatewayAnswer
TomPushRequest
TomDeliveryCallbackRequest
TomVonageSignatureMethod  (enum)
TomInboxOutcome  (enum)
TomInboxRow
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
  StackTrace? stack,
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
| `push` | `static const TomMessageChannel` | Mobile push notification, delivered by `TomPushTransport`. |
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
const TomMessageBody(String mediaType, String content, {String charset = defaultCharset})

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
| `charset` | `String` | The character set the content is in; defaults to `defaultCharset` (final). |
| `isPlainText` | `bool` | *(getter)* Whether `mediaType` is `text/plain`, case-insensitively. |
| `isHtml` | `bool` | *(getter)* Whether `mediaType` is `text/html`, case-insensitively. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the part as a JSON-native map. |
| `toString` | `String toString()` | *(override)* The media type and the content's length in characters. |

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultCharset` | `String` | The character set a part carries when the caller names none: `utf-8`. Both constructors and `fromJson` read the default from here, so it has one home; code deciding whether a part needs converting should compare against it rather than restate the value and become another. |

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

factory TomMessage.sms({
  String? id,
  required List<TomRecipient> to,
  required String text,
  String? senderId,
  Map<String, Object?>? metadata,
})

factory TomMessage.push({
  String? id,
  required List<TomRecipient> to,
  String? title,
  required String body,
  Map<String, String> data = const {},
  Map<String, Object?>? metadata,
})

factory TomMessage.fromJson(Map<String, Object?> map)
```

`TomMessage.push` puts the title in `subject`, the text in one body, and `data`
in `metadata` under `TomPushTransport.dataMetadataKey`.

`TomMessage.sms` composes one text body and no subject. `senderId` goes into
`metadata` rather than into `from`, because a short code is not a
`TomRecipient` — nobody replies to one, and modelling it as one would offer a
`displayName` and a `TomRecipientKind` that mean nothing on this channel.

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
| `textBody` | `TomMessageBody?` | *(getter)* The `text/plain` representation, matched case-insensitively, when one was offered. |
| `htmlBody` | `TomMessageBody?` | *(getter)* The HTML representation, matched case-insensitively, when one was offered. |
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
| `suppressed` | Nothing was sent because every recipient is on the suppression list (`TomSuppressionList`): a carrier reported each address as undeliverable. Final, like `rejected`, until an address is released. |

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
  String? tenant,
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
| `tenant` | `String?` | The tenant the message was sent for, or `null` for a message of no tenant. Set by `TomMessageOutbox` from the run it delivered (final). |
| `isDelivered` | `bool` | *(getter)* Whether the far side took responsibility for the message. |
| `isPartial` | `bool` | *(getter)* Whether the message was delivered but some recipients were refused. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `forTenant` | `TomDeliveryReceipt forTenant(String? tenant)` | This receipt for `tenant` — every other field unchanged. |
| `toJson` | `Map<String, Object?> toJson()` | Encodes the receipt as a JSON-native map; null and empty fields are omitted. |
| `toString` | `String toString()` | *(override)* The message id, the outcome name and the remote id when there is one. |

### TomDeliveryException

A delivery attempt that did not succeed. `isPermanent` is the whole point of the
type: it records whether retrying this exact message could ever succeed, and
only the transport can make that call because only the transport read the far
side's answer.

The class is **abstract**, and `isPermanent` is a **getter reading the
`TomPermanentFailure` marker** rather than a stored flag, so the description and
the scheduler's decision cannot disagree. Every instance is therefore one of the
two classified subtypes, or a transport's own subclass of them. Throw through
the `permanent` and `transient` builders.

- **Extends:** `TomMessagingException`

#### Constructors

```dart
TomDeliveryException(
  String key,
  String defaultUserMessage, {
  int? statusCode,
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

For subclasses to call. The classification is not a parameter — it follows from
whether the subtype mixes in `TomPermanentFailure`.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isTransientHttpStatus` | `static bool isTransientHttpStatus(int status)` | Whether an HTTP status is worth trying again: `408`, `425`, `429` and `5xx`. Every other non-`2xx` says the request was wrong, and a retry sends the same wrong request. It lives here rather than on a transport because two of them need it — an SMS gateway and a webhook endpoint are both HTTP — and a second copy is a second thing to keep in step with the retry policy it feeds. |
| `permanent` | `static TomPermanentDeliveryException permanent(String key, String message, {int? statusCode, Map<String, dynamic>? parameters, Object? rootException, StackTrace? stack})` | A failure that retrying cannot fix; the returned type carries the scheduler's give-up marker. |
| `transient` | `static TomTransientDeliveryException transient(String key, String message, {int? statusCode, Map<String, dynamic>? parameters, Object? rootException, StackTrace? stack})` | A failure that a later attempt may well survive. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isPermanent` | `bool` | *(getter)* Whether retrying this exact message could ever succeed. Reads the `TomPermanentFailure` marker rather than storing the answer beside it. |
| `statusCode` | `int?` | The protocol's own status code, when it had one — e.g. SMTP `550` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The base exception string plus the classification and, when present, the status code. |

### TomPermanentDeliveryException

A `TomDeliveryException` the scheduler will not retry. The `TomPermanentFailure`
marker is the payload: the scheduler branches on it and `isPermanent` reads it.
Callers should reach this through `TomDeliveryException.permanent`.

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
  StackTrace? stack,
})
```

### TomTransientDeliveryException

A `TomDeliveryException` worth another attempt. It exists so that the two
classifications are two types rather than one type and its absence: `transient`
returns this the way `permanent` returns `TomPermanentDeliveryException`, and
`on TomTransientDeliveryException` reads as the mirror of
`on TomPermanentDeliveryException`. It carries no marker, which is precisely what
makes it retryable.

It is not the only retryable type — any `TomDeliveryException` without
`TomPermanentFailure` is one — so code deciding whether to retry should ask
`isPermanent` rather than test for this class.

- **Extends:** `TomDeliveryException`

#### Constructors

```dart
TomTransientDeliveryException(
  String key,
  String defaultUserMessage, {
  int? statusCode,
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
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
TomMessageRouter([
  Iterable<TomMessageTransport> transports = const [],
  TomSuppressionList? suppressions,
])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `suppressions` | `TomSuppressionList?` | The addresses `send` leaves out, or `null` to send to every recipient. Consulted on every send, so an address a report suppresses while messages are queued is left out of the next one. |
| `channels` | `List<TomMessageChannel>` | *(getter)* The channels that currently have a transport. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomMessageTransport transport)` | Registers `transport` for its own channel, replacing any previous one. |
| `deregister` | `void deregister(TomMessageChannel channel)` | Removes the transport registered for `channel`, if any. |
| `supports` | `bool supports(TomMessageChannel channel)` | Whether `channel` can be delivered. |
| `transportFor` | `TomMessageTransport transportFor(TomMessage message)` | The transport for the message's channel. An unrouted channel is a permanent failure — no amount of retrying adds a transport. |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | Delivers `message` through its channel's transport. `async` deliberately, so the unrouted-channel failure arrives on the returned future rather than being thrown synchronously. With `suppressions`, suppressed recipients are left out first: when every recipient is suppressed no transport is called and the receipt is `TomDeliveryOutcome.suppressed`; when some are, the rest are sent to and the suppressed ones are reported in `rejectedRecipients`. |
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
`'<jobName>:<messageId>'`, which makes the message its own idempotence key: a
message whose id the store still holds — queued, delivered or failed for good —
is not queued again.

- **Implements:** `TomClosable`

#### Constructors

None — the generative constructor is private; instances are created through the
factory below.

#### Factory Constructors

```dart
factory TomMessageOutbox({
  required TomMessageRouter router,
  TomJobStore? store,
  TomDeliveryReportStore? reportStore,
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
for production. It also joins no transaction: a message queued with a
`TomSqlJobStore` commits or rolls back with the transaction it is queued in. `retryPolicy` defaults to five attempts rather than the
framework's three, because a relay's transient refusals — greylisting above
all — are routinely measured in minutes.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `started` | `static Set<TomMessageOutbox> get` | The outboxes of this isolate that were started and not yet closed, as an unmodifiable copy. `start` adds an outbox, `close` removes it. What the framework readiness check (`TomFrameworkReadinessAnalyzer`) asks whether each is delivering. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `router` | `TomMessageRouter` | Where messages are handed for actual delivery. Not owned: `close` leaves it open (final). |
| `jobName` | `String` | The name the delivery job is registered under (final). |
| `scheduler` | `TomScheduler` | The scheduler driving delivery; owned and closed by `close` (final). |
| `store` | `TomJobStore` | The queue behind `scheduler`, exposed so a caller can inspect what is pending, count failures, or purge history (final). |
| `reportStore` | `TomDeliveryReportStore?` | Where a carrier's identifier for a delivered message is remembered, so a later delivery report can be matched back to it. `null` — the default — means the ids are not kept, which is right for a deployment whose channels report nothing back and wrong for SMS. Only receipts that actually carry an id are remembered (final). |
| `receipts` | `Stream<TomDeliveryReceipt>` | *(getter)* A broadcast stream of every delivery that reached a transport, including partial ones and discards. Failures are not here — they go to the scheduler's `TomJobAlertSink`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<bool> send(TomMessage message, {DateTime? notBefore})` | Queues `message` and returns once it is durably stored, answering `true`. A message whose id the store already holds a run for — queued, delivered, or failed for good — is not queued again, and `send` answers `false`: a caller retrying a `send` it is unsure completed causes no second delivery, however long ago the first went out. The id is held until `purgeFinished` removes its run. `notBefore` holds the message in the queue until that instant — the first attempt is made at the first tick after it; an instant already past is the same as none. Enqueues directly rather than through the schedule's event stream, so two messages composed in the same instant are two runs, and enqueues the run with `windowed: false`, keyed by its id and taking no window, so two messages queued in the same microsecond — on one node or on two — are two runs. The run records the tenant in context, and the message is delivered inside it — a transport choosing a per-tenant sending identity reads it from `TomTenantContext.currentId`; the receipt and the delivery correlation name it. With a tracer installed (`TomTracing`) queueing is a `producer` span, `outbox send` (`messaging.system` `tom_outbox`, `messaging.operation.type` `send`, `messaging.destination.name` the job name, `messaging.message.id`), and the message is queued with that span's `traceparent` and `tracestate` in its `headers`; the delivery is a `consumer` span, `outbox deliver`, continuing that header, with `tom.job.run_id`. Inside a transaction (`TomTransactionManager.runInTransaction`, a `@TomTransactional` endpoint) on a `TomSqlJobStore`, the message is queued in it and commits or rolls back with it — in its branch on the data source it writes to, as a participant of its own on another, on the tenant's branch under `schema` tenancy — and the idempotence check sees the runs the transaction queued; a `TomMemoryJobStore` joins no transaction and queues at once. Throws `TomMessagingException` once the outbox is closed. |
| `runIdOf` | `String runIdOf(String messageId)` | The id of the run carrying message `messageId` queued in the tenant in context: `<jobName>:<messageId>`, the id qualified by the tenant (`TomTenantContext.qualify`), so two tenants queueing one message id queue two messages, each sent once. |
| `sendNow` | `Future<void> sendNow(TomMessage message)` | Queues `message` (as `send` does, so a message already held is not queued again) and ticks immediately, for a case where the tick interval is felt by a human. A failure still retries on the queue exactly as `send` would. |
| `tick` | `Future<void> tick()` | Runs one delivery pass; exposed so a test can drive delivery without waiting on wall-clock time. |
| `start` | `void start()` | Begins delivering on the scheduler's tick interval, and registers this outbox in `started` until `close`. Throws `TomMessagingException` (`messaging.outbox.closed`) once the outbox is closed. |
| `oldestWaitingSince` | `Future<DateTime?> oldestWaitingSince()` | When the oldest message of this outbox that is due and not yet taken for delivery started waiting, or `null` when none waits — read from the store's backlog for `jobName`. The framework readiness check compares it against `maxOutboxWait` when one is set. |
| `purgeFinished` | `Future<int> purgeFinished(DateTime before)` | Drops finished runs recorded before `before`, returning how many. A purged message's id is not held, so a `send` of the same id afterwards queues it again. Never called on your behalf: the completed runs are a delivery audit trail whose retention is a deployment's decision. |
| `close` | `Future<void> close()` | *(override)* Removes the outbox from `started`, stops delivery, closes the scheduler — releasing its leases — and closes the receipt stream, completing once all of that has. The `router` is left open. Idempotent: every call is handed the same close. |

### TomBusRelay

Messages for a `TomMessageBus` queued on a `TomJobStore`, so a publish commits
with the caller's database transaction, and published to the bus once it has.
The relay is the transactional outbox for the bus: `publish` writes a run — in
the caller's transaction on a `TomSqlJobStore`, as the message outbox does —
and the relay's scheduler publishes it, retrying a publish the bus refused. The
publish is at least once, as the bus's delivery is: a publish whose
acknowledgement was lost is made again, under the same message id.

- **Implements:** `TomClosable`

#### Constructors

None — the generative constructor is private; instances are created through the
factory below.

#### Factory Constructors

```dart
factory TomBusRelay({
  required TomMessageBus bus,
  TomJobStore? store,
  String jobName = tomBusRelayJobName,
  TomRetryPolicy retryPolicy = const TomRetryPolicy(
    maxAttempts: 10,
    initialBackoff: Duration(seconds: 5),
    maxBackoff: Duration(minutes: 5),
  ),
  Duration timeout = const Duration(seconds: 30),
  Duration tickInterval = const Duration(seconds: 1),
  DateTime Function()? clock,
  TomJobAlertSink? onAlert,
  TomLeaseLock? lock,
})
```

`store` defaults to a `TomMemoryJobStore` — for tests: a relay on a memory store
joins no transaction and loses what it holds when the process stops.
`retryPolicy` governs a publish the bus refused; `onAlert` is told of one that
failed for good. The relay registers its job on a scheduler of its own that
dispatches inline.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `bus` | `TomMessageBus` | The bus messages are published to. Not owned: `close` leaves it open (final). |
| `store` | `TomJobStore` | The queue the messages wait in (final). |
| `jobName` | `String` | The registered job name, and the prefix of every run id (final). |
| `scheduler` | `TomScheduler` | The scheduler publishing the queued messages; owned and closed by `close` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `publish` | `Future<String> publish<T>(String topic, T payload, {String? key, Map<String, String> headers = const {}, String? id, TomBusCodec<T>? codec})` | Queues `payload` for `topic`, encoded by `codec` (the reflection codec unless given), and answers the message id — `id` when given, a new `msg-` id otherwise. The message is published by a later `tick`, with `key` and `headers`, in the trace the publish was made in. Inside a transaction on a `TomSqlJobStore` the queued run is written in that transaction: the message is published after the commit, or never. A message id the relay already holds a run for is not queued again. The run records the tenant in context. Throws `messaging.bus_relay.closed` (a `TomMessagingException`) once the relay is closed, and `message_bus.payload.not_json` for a payload that does not encode. |
| `runIdOf` | `String runIdOf(String messageId)` | The id of the run carrying message `messageId` published in the tenant in context: `<jobName>:<messageId>`, the id qualified by the tenant (`TomTenantContext.qualify`), so two tenants publishing one message id queue two messages. |
| `tick` | `Future<void> tick()` | Publishes what is due, one message after another, completing when a pass of the scheduler publishes nothing more — the queue is empty, what is left waits for a retry, or another node holds the relay's lease. A tick asked for while one runs joins it. |
| `start` | `void start()` | Runs a `tick` every tick interval of the scheduler. |
| `close` | `Future<void> close()` | *(override)* Stops publishing, waits for the tick under way and closes the scheduler; `bus` stays open. Idempotent: every call is handed the same close. |

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
  TomLocalizedTextResources? texts,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `outbox` | `TomMessageOutbox` | Where rendered messages are queued. Not owned: closing it is the application's call, because one outbox usually carries every channel's traffic (final). |
| `texts` | `TomLocalizedTextResources` | *(getter)* The bundle set every template is resolved against: the one passed to the constructor, else the installed `TomLocalizedTextResources` bean. Resolved per call, so a service may be built before the bundles are read off disk. Throws `messaging.<channel>.texts.not_configured` when there is neither, rather than rendering blank. |
| `channelName` | `String` | *(abstract getter)* The channel's name as it appears in this service's error keys — `email`, `sms`. A missing SMS template must not report itself as an email fault. |
| `listTemplateKey` | `static const String` | `'messaging.list'` — the well-known key `requiredList` resolves its separators under. One key rather than a per-template one, because a list's punctuation is a fact about the *language* and not about the mail. |
| `listSeparatorSubKey` | `static const String` | `'separator'` — what goes between all but the last two items. |
| `listLastSeparatorSubKey` | `static const String` | `'last'` — what goes between the last two. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(R request)` | *(abstract)* Turns a request into a message without queueing it — for a preview, a test, or a digest that renders many and queues one. Where every template fault surfaces, which is why `send` calls it before touching the queue. |
| `send` | `Future<void> send(R request)` | Renders and queues. `async` rather than a forwarding expression, so a template fault arrives as a failed future rather than as a synchronous throw from an otherwise-asynchronous API. |
| `sendNow` | `Future<void> sendNow(R request)` | Renders, queues and delivers immediately, for a message a human is waiting on. Retry behaviour is unchanged: only the first attempt skips the wait. |
| `requiredList` | `String requiredList(Iterable<String> items, {TomTextLocale? locale})` | Joins `items` with the separators the bundle gives for `locale` — the answer to the *list* half of "a template has no control flow", as `requiredText` is to the conditional half. Three items render `Alpha, Beta and Gamma`; one renders itself and consults no separator, so a deployment that never joins more than one never supplies the keys; an empty list is the empty string, because a caller needing "you have nothing outstanding" is in the conditional case. **The separators have no Dart default** — `", "` and `" and "` are English, and a framework that routes every user-facing string through a bundle cannot make these the two it writes in code — so a bundle missing them fails the send naming `messaging.list.last`. It joins strings and substitutes nothing, so resolve items fully before passing them in. |
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
  TomLocalizedTextResources? texts,
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
| `encoder` | `TomMimeEncoder` | Renders the message document; injectable so a test can pin the boundaries and the date — and so a deployment that must **sign** its mail can, without forking the transport: a subclass overriding `encode` to prepend a `DKIM-Signature` header to `super.encode(message)` is the whole seam. The transport writes the document to the socket exactly as the encoder produced it, so a deployment relying on that relies on its relay to sign (final). |
| `connect` | `Future<TomSmtpConnection> Function(TomSmtpSettings settings)` | Opens the connection, defaulting to `TomSocketSmtpConnection.open`; injectable so the protocol can be tested against an in-process fake server (final). |
| `channel` | `TomMessageChannel` | *(getter)* *(override)* Always `TomMessageChannel.email`. |
| `supportsCopies` | `bool` | *(getter)* *(override)* Always `true`. |
| `supportsAttachments` | `bool` | *(getter)* *(override)* Always `true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Runs one conversation — greeting, `EHLO` falling back to `HELO`, `STARTTLS` and re-greet when configured, `AUTH PLAIN` or `LOGIN` when credentials are set, `MAIL FROM`, one `RCPT TO` per envelope address, `DATA` and the document, then a best-effort `QUIT`. A message with no sender and no configured default fails permanently; an unreachable relay fails transiently; refused recipients are collected onto the receipt unless every one is refused. The connection is closed in a `finally`, best-effort: a `close` that throws is logged at debug rather than allowed to replace the receipt the relay already committed to. |

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
| `close` | `Future<void> close()` | Closes the connection. Implementations may throw; `TomSmtpTransport` logs the failure at debug rather than letting it replace the delivery outcome, so a `close` that fails cannot be used to signal one. |

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
| `close` | `Future<void> close()` | *(override)* Cancels the line reader and closes the socket, logging any failure at debug under the stage `socket teardown` rather than raising it — the delivery outcome was decided before this point. `destroy` runs afterwards either way, so the resource is released even when the graceful close failed. |

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
  TomLocalizedTextResources? texts,
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

### TomPushSubmission

One notification to one device, as a protocol sees it.

- **Extends:** none

#### Constructors

```dart
const TomPushSubmission({
  required String messageId,
  required String token,
  required String body,
  String? title,
  Map<String, String> data = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `messageId` | `String` | The message this submission belongs to, for the error parameters (final). |
| `token` | `String` | The device token — `TomRecipient.address` on this channel (final). |
| `title` | `String?` | The notification's title; `null` sends a body-only notification (final). |
| `body` | `String` | The notification's text (final). |
| `data` | `Map<String, String>` | Key/value pairs for the app. Strings only, because FCM's `data` block carries nothing else (final). |

### TomPushGatewayRequest

One HTTP request a protocol asks the transport to make — a value, so `encode`
stays pure.

- **Extends:** none

#### Constructors

```dart
const TomPushGatewayRequest({
  required Uri url,
  required String body,
  String method = 'POST',
  Map<String, String> headers = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `url` | `Uri` | Where to send it (final). |
| `method` | `String` | The HTTP method (final). |
| `headers` | `Map<String, String>` | The request headers, credential included (final). |
| `body` | `String` | The request body (final). |

### TomPushGatewayResponse

What the push service answered, before any protocol has read it.

- **Extends:** none

#### Constructors

```dart
TomPushGatewayResponse(
  int statusCode,
  String body, {
  Map<String, String> headers = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status (final). |
| `headers` | `Map<String, String>` | The response headers, names lowercased by the constructor. APNs answers a success with an empty body and the id in `apns-id`, so a protocol needs them (final). |
| `body` | `String` | The response body (final). |

### TomPushGatewayAnswer

A protocol's reading of one response.

- **Extends:** none

#### Constructors

```dart
const TomPushGatewayAnswer({
  required bool isAccepted,
  String? remoteId,
  String? detail,
  bool? isPermanent,
  bool isCredentialRejected = false,
  String? providerCode,
})

const TomPushGatewayAnswer.accepted({String? remoteId, String? detail})

const TomPushGatewayAnswer.rejected({
  bool? permanent,
  bool isCredentialRejected = false,
  String? detail,
  String? providerCode,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isAccepted` | `bool` | Whether the service took the notification (final). |
| `remoteId` | `String?` | The service's id for it (final). |
| `detail` | `String?` | A short account for the receipt and the error (final). |
| `isPermanent` | `bool?` | `true` permanent, `false` transient, `null` when the code says neither — the transport then judges by the HTTP status (final). |
| `isCredentialRejected` | `bool` | The service refused the credential rather than the notification; the transport refreshes it and submits once more (final). |
| `providerCode` | `String?` | The vendor's error code (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Accepted or rejected, with the code. |

### TomPushExchange

Performs one request and returns what came back — the seam between protocol and
wire, so the classification is testable without a network and the HTTP version
is a choice.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomPushExchange()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exchange` | `Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request)` | *(abstract)* Sends the request. Anything it throws counts as the service being unreachable. |
| `close` | `Future<void> close()` | Releases whatever connections the exchange holds. Default: nothing. |

### TomHttp1PushExchange

An HTTP/1.1 exchange over the kernel call layer, one `TomServerChannel` per
host. Sets `includeBearerAuthentication: false`, so the caller's token never
reaches a third party.

- **Extends:** `TomPushExchange`

#### Constructors

```dart
TomHttp1PushExchange({TomHttpClientAbstractFactory? clientFactory})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `clientFactory` | `TomHttpClientAbstractFactory?` | The client factory handed to every channel, or `null` for the default; injectable for tests (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exchange` | `Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request)` | *(override)* One call; status, headers and body. |
| `close` | `Future<void> close()` | *(override)* Closes every channel. |

### TomHttp2PushExchange

An HTTP/2 exchange over `package:http2`, keeping one connection per host open
for reuse — what APNs requires, and what Apple asks of providers.

- **Extends:** `TomPushExchange`

#### Constructors

```dart
TomHttp2PushExchange({Future<Socket> Function(Uri url)? connect})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `connect` | `Future<Socket> Function(Uri url)` | Opens the socket for a host. Defaults to TLS with ALPN `h2`; injectable so a test can serve plain-text HTTP/2 locally (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exchange` | `Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request)` | *(override)* One stream on the host's connection, opening the connection on first use or after it closed. A failed connect is not cached. |
| `close` | `Future<void> close()` | *(override)* Finishes every connection. |

### TomPushCredential

Supplies the bearer token a push service authenticates with.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomPushCredential()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `token` | `Future<String> token()` | *(abstract)* The current token, minting one when there is none or it has expired. |
| `invalidate` | `void invalidate()` | Discards the cached token so the next `token` mints afresh. Called when the service rejects the credential; a no-op by default. |

### TomStaticPushCredential

A token the deployment already has.

- **Extends:** `TomPushCredential`

#### Constructors

```dart
const TomStaticPushCredential(String token)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `token` | `Future<String> token()` | *(override)* The wrapped token. |
| `toString` | `String toString()` | *(override)* Redacted. |

### TomApnsProviderToken

The APNs provider token: a JWT signed with ES256 over the `.p8` key, issuer the
Team ID, `kid` the Key ID. Cached for `lifetime` — Apple rejects a token older
than an hour and one replaced more often than every twenty minutes.

- **Extends:** `TomPushCredential`

#### Constructors

```dart
TomApnsProviderToken({
  required String teamId,
  required String keyId,
  required String privateKeyPem,
  Duration lifetime = const Duration(minutes: 50),
  DateTime Function()? now,
})
```

Parses the key immediately and raises `TomMessagingException`
(`messaging.push.bad_key`) when it is not an EC private key.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `teamId` | `String` | The developer account's Team ID (final). |
| `keyId` | `String` | The `.p8` key's Key ID (final). |
| `lifetime` | `Duration` | How long a minted token is reused (final). |
| `now` | `DateTime Function()` | The clock; injectable for tests (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `token` | `Future<String> token()` | *(override)* The cached token, or a freshly signed one once `lifetime` has passed. |
| `invalidate` | `void invalidate()` | *(override)* Forgets the cached token. |
| `toString` | `String toString()` | *(override)* Team and key id; never the key. |

### TomFcmServiceAccountCredential

An FCM access token minted from a Google service-account key: an RS256
assertion exchanged at `tokenUri` under the JWT-bearer grant, cached until five
minutes before the stated expiry.

- **Extends:** `TomPushCredential`

#### Constructors

```dart
TomFcmServiceAccountCredential({
  required String clientEmail,
  required String privateKeyPem,
  Uri? tokenUri,
  String scope = messagingScope,
  String? projectId,
  TomPushExchange? exchange,
  DateTime Function()? now,
})

factory TomFcmServiceAccountCredential.fromJson(
  String serviceAccountJson, {
  TomPushExchange? exchange,
  DateTime Function()? now,
})
```

The key is parsed immediately (`messaging.push.bad_key`). `fromJson` reads the
key file Google issues — `client_email`, `private_key`, `token_uri`,
`project_id` — and raises `messaging.push.bad_service_account` when either of
the first two is missing or the text is not JSON.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `messagingScope` | `static const String` | `https://www.googleapis.com/auth/firebase.messaging`. |
| `clientEmail` | `String` | The assertion's issuer (final). |
| `tokenUri` | `Uri` | Where the assertion is exchanged; defaults to `https://oauth2.googleapis.com/token` (final). |
| `scope` | `String` | The scope requested (final). |
| `projectId` | `String?` | The project, when the key file named it (final). |
| `exchange` | `TomPushExchange` | How the token request is sent; defaults to `TomHttp1PushExchange` (final). |
| `now` | `DateTime Function()` | The clock; injectable for tests (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `token` | `Future<String> token()` | *(override)* The cached token, or a new one. An unreachable endpoint or a `408`/`425`/`429`/`5xx` raises transient `messaging.push.credential_unavailable`; any other refusal raises permanent `messaging.push.credential_refused`. |
| `invalidate` | `void invalidate()` | *(override)* Forgets the cached token. |
| `toString` | `String toString()` | *(override)* The account email; never the key. |

### TomPushProtocol

How one push service is spoken to: field names in, status and error paths out.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomPushProtocol()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `requiresHttp2` | `bool` | Whether the service accepts only HTTP/2; picks the transport's default exchange. `false` by default. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `TomPushGatewayRequest encode(TomPushSubmission submission, String? token)` | *(abstract)* The request that submits `submission`, authenticated with `token`. |
| `decode` | `TomPushGatewayAnswer decode(TomPushGatewayResponse response)` | *(abstract)* What the response means. |
| `authorizationHeaders` | `Map<String, String> authorizationHeaders(String? token)` | `Authorization: Bearer <token>`, or nothing without a token. |
| `rejection` | `static TomPushGatewayAnswer rejection({required String? code, required String? detail, required Set<String> permanentCodes, required Set<String> transientCodes, required Set<String> credentialCodes})` | Classifies a refusal's code: a credential code first, then the permanent and transient sets, else unclassified. |

### TomFcmPushProtocol

Firebase Cloud Messaging's HTTP v1 API: `POST /v1/projects/<projectId>/messages:send`
with `{"message": {"token", "notification": {"title", "body"}, "data"}}`. The
error code is the `FcmError` entry's `errorCode` in `error.details`, else
`error.status`; a success's remote id is the message `name`.

- **Extends:** `TomPushProtocol`

#### Constructors

```dart
TomFcmPushProtocol({required String projectId, Uri? baseUri})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `permanentCodes` | `static const Set<String>` | `UNREGISTERED`, `INVALID_ARGUMENT`, `SENDER_ID_MISMATCH`, `THIRD_PARTY_AUTH_ERROR`, `NOT_FOUND`. |
| `transientCodes` | `static const Set<String>` | `QUOTA_EXCEEDED`, `UNAVAILABLE`, `INTERNAL`. |
| `credentialCodes` | `static const Set<String>` | `UNAUTHENTICATED` — also assumed for a `401` with no readable body. |
| `projectId` | `String` | The Firebase project (final). |
| `baseUri` | `Uri` | The API's base URL; injectable for tests (final). |
| `endpoint` | `Uri` | The send endpoint. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `TomPushGatewayRequest encode(TomPushSubmission submission, String? token)` | *(override)* The HTTP v1 message; an absent title and an empty data map are omitted. |
| `decode` | `TomPushGatewayAnswer decode(TomPushGatewayResponse response)` | *(override)* See above. |
| `toString` | `String toString()` | *(override)* The project id. |

### TomApnsPushProtocol

Apple's push service with token authentication: `POST /3/device/<token>` over
HTTP/2, headers `authorization: bearer <token>`, `apns-topic`,
`apns-push-type`, `apns-priority`, and `{"aps": {"alert": {"title", "body"}}}`
with the data keys beside `aps` (written first, so a data key named `aps` cannot
replace the alert). A refusal's code is the body's `reason`; a success's remote
id is the `apns-id` header.

- **Extends:** `TomPushProtocol`

#### Constructors

```dart
const TomApnsPushProtocol({
  required String topic,
  bool sandbox = false,
  String pushType = 'alert',
  int priority = 10,
  Uri? baseUri,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `permanentCodes` | `static const Set<String>` | Token and payload faults — `BadDeviceToken`, `Unregistered`, `DeviceTokenNotForTopic`, `PayloadTooLarge` and the other `Bad*` / `Missing*` reasons. |
| `transientCodes` | `static const Set<String>` | `TooManyRequests`, `TooManyProviderTokenUpdates`, `InternalServerError`, `ServiceUnavailable`, `Shutdown`, `IdleTimeout`. |
| `credentialCodes` | `static const Set<String>` | `ExpiredProviderToken`, `InvalidProviderToken`, `MissingProviderToken`. |
| `topic` | `String` | The app's bundle id (final). |
| `sandbox` | `bool` | Sends to `api.sandbox.push.apple.com` (final). |
| `pushType` | `String` | The `apns-push-type` header (final). |
| `priority` | `int` | The `apns-priority` header (final). |
| `baseUri` | `Uri?` | Overrides the host, for tests (final). |
| `requiresHttp2` | `bool` | *(override getter)* `true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authorizationHeaders` | `Map<String, String> authorizationHeaders(String? token)` | *(override)* `authorization: bearer <token>`. |
| `encode` | `TomPushGatewayRequest encode(TomPushSubmission submission, String? token)` | *(override)* See above. |
| `decode` | `TomPushGatewayAnswer decode(TomPushGatewayResponse response)` | *(override)* See above. |
| `toString` | `String toString()` | *(override)* Topic and environment. |

### TomFieldMappedPushProtocol

Any other JSON push API, described by dotted field paths. A `{token}` in
`endpoint` is replaced by the URL-encoded token, for services that address the
device in the path.

- **Extends:** `TomPushProtocol`

#### Constructors

```dart
const TomFieldMappedPushProtocol({
  required String endpoint,
  String method = 'POST',
  String? tokenField = 'token',
  String titleField = 'title',
  String bodyField = 'body',
  String? dataField = 'data',
  Map<String, Object?> extraFields = const {},
  String authorizationHeader = 'Authorization',
  String authorizationPrefix = 'Bearer ',
  bool requiresHttp2 = false,
  String? statusPath,
  Set<String> acceptedStatuses = const {},
  String? remoteIdPath,
  String? errorCodePath,
  String? errorMessagePath,
  Set<String> permanentErrorCodes = const {},
  Set<String> transientErrorCodes = const {},
  Set<String> credentialErrorCodes = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `endpoint` | `String` | Where to send; may contain `{token}` (final). |
| `method` | `String` | The HTTP method (final). |
| `tokenField` | `String?` | The token's path in the body, or `null` when `endpoint` carries it (final). |
| `titleField` / `bodyField` | `String` | The title's and the text's paths (final). |
| `dataField` | `String?` | Where the data map goes, or `null` to drop it (final). |
| `extraFields` | `Map<String, Object?>` | Constant fields every submission carries (final). |
| `authorizationHeader` / `authorizationPrefix` | `String` | The credential's header and what precedes the token in it (final). |
| `requiresHttp2` | `bool` | *(override)* Whether the service needs HTTP/2 (final). |
| `statusPath` / `acceptedStatuses` | `String?` / `Set<String>` | Where the status is and which values mean "taken", case-insensitively; a configured path that does not resolve is not a success (final). |
| `remoteIdPath` / `errorCodePath` / `errorMessagePath` | `String?` | Where the id, the error code and the error message are (final). |
| `permanentErrorCodes` / `transientErrorCodes` / `credentialErrorCodes` | `Set<String>` | The three classifications (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authorizationHeaders` | `Map<String, String> authorizationHeaders(String? token)` | *(override)* `authorizationHeader: authorizationPrefix + token`. |
| `encode` | `TomPushGatewayRequest encode(TomPushSubmission submission, String? token)` | *(override)* Builds the nested body from the paths. |
| `decode` | `TomPushGatewayAnswer decode(TomPushGatewayResponse response)` | *(override)* Reads the configured paths. |

### TomPushTransport

Delivers `TomMessageChannel.push` to device tokens, one request each, so a dead
token is a rejected recipient rather than a failed message. A rejected
credential is invalidated and the token tried once more with a fresh one.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomPushTransport(
  TomPushProtocol protocol, {
  TomPushCredential? credential,
  TomPushExchange? exchange,
  Duration timeout = const Duration(seconds: 30),
})
```

The exchange defaults to `TomHttp2PushExchange` when `protocol.requiresHttp2`,
else `TomHttp1PushExchange`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dataMetadataKey` | `static const String` | `'pushData'` — the `TomMessage.metadata` key the data map travels under. |
| `protocol` | `TomPushProtocol` | The service mapping (final). |
| `credential` | `TomPushCredential?` | The credential, or `null` for a service that needs none (final). |
| `exchange` | `TomPushExchange` | The wire (final). |
| `timeout` | `Duration` | How long one request may take before it counts as deferred (final). |
| `channel` | `TomMessageChannel` | *(override getter)* `TomMessageChannel.push`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Permanent `messaging.push.no_body` before anything is sent when the message has no text. Then one submission per token: a permanent refusal rejects that token, a transient one stops the pass (`messaging.push.gateway_deferred`), a credential rejected twice is permanent (`messaging.push.credential_rejected`), an unreachable service is transient (`messaging.push.unreachable`), and every token refused is permanent (`messaging.push.all_recipients_rejected`). |
| `close` | `Future<void> close()` | *(override)* Closes the exchange. |

### TomPushRequest

What to send, to which device tokens, and with which values — but never *what
it says*. No title or body field; a `data` map for the app.

- **Extends:** none

#### Constructors

```dart
TomPushRequest({
  required String templateKey,
  required List<TomRecipient> to,
  TomTextLocale? locale,
  Map<String, Object?> parameters = const {},
  Map<String, String> data = const {},
  String? messageId,
})
```

Raises `TomMessagingException` under `messaging.push.template.empty` for a
blank template key and `messaging.push.recipients.empty` for an empty `to`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `templateKey` | `String` | The resource key prefix the title and body live under (final). |
| `to` | `List<TomRecipient>` | The device tokens (final). |
| `locale` | `TomTextLocale?` | The locale to render in (final). |
| `parameters` | `Map<String, Object?>` | Values for the template's placeholders (final). |
| `data` | `Map<String, String>` | Key/value pairs handed to the app — an id to open, never text to show (final). |
| `messageId` | `String?` | The idempotence key the outbox deduplicates on (final). |

### TomPushService

Renders resource-keyed push notifications and queues them on the outbox. Two
sub-keys, both required: `<templateKey>.title` and `.body`.

- **Extends:** `TomTemplatedMessageService<TomPushRequest>`

#### Constructors

```dart
const TomPushService({
  required TomMessageOutbox outbox,
  TomLocalizedTextResources? texts,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `titleSubKey` | `static const String` | `title`. |
| `bodySubKey` | `static const String` | `body`. |
| `channelName` | `String` | *(override getter)* `push`. |

`outbox`, `texts`, `send`, `sendNow`, `deliverNow` and `requiredText` are inherited from
[TomTemplatedMessageService](#tomtemplatedmessageservice).

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(TomPushRequest request)` | *(override)* A `TomMessage.push` with the resolved title and body and the request's data; a missing sub-key raises `messaging.push.template.missing` before anything is queued. |
| `resolve` | `static TomPushService? resolve()` | The service this deployment installed, or `null`. |

### TomWebhookSettings

How the webhook transport calls an endpoint. Deliberately small: the endpoint is
addressed by the *message*, so nothing here names a host. What is here is what a
deployment decides once and every call shares.

#### Constructors

```dart
TomWebhookSettings({
  Duration timeout = const Duration(seconds: 30),
  Map<String, String>? headers,
  int maxDetailChars = 512,
})
```

Throws `TomMessagingException` (`messaging.webhook.bad_detail_cap`) on a
negative cap.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `timeout` | `Duration` | How long to wait for the endpoint to answer (final). |
| `headers` | `Map<String, String>` | Headers applied to every call — an API key, a signature, a tenant id. **They win over `TomMessage.headers`**: the settings carry the credential, and letting composing code overwrite one would let it strip the authentication off a call (final, unmodifiable). |
| `maxDetailChars` | `int` | How much of the endpoint's answer is kept in the receipt. A cap rather than the whole body, because the body is a stranger's and the receipt is logged (final). |

### TomWebhookTransport

Delivers `TomMessageChannel.webhook` by POSTing `TomMessage.toJson()` to the URL
in its recipient's address, as `application/json` — the same representation the
outbox already round-trips, so what an endpoint receives and what a queued
message *is* cannot drift apart.

**One endpoint per message, and a second is refused permanently.** The outbox
retries a message rather than a recipient, so a POST that succeeded at one
endpoint and failed at another would be re-sent to both — and a webhook is not
idempotent. Fan-out is two messages, retried independently.

**The message's trace headers are not posted.** `traceparent` and `tracestate`
in `TomMessage.headers` — what the outbox wrote for the delivery to continue —
are left out of the call; the call goes through the kernel's call layer, which
propagates its own client span, so the receiver's span is a child of the call.

Classification is a single layer, the HTTP status through
`TomDeliveryException.isTransientHttpStatus`; a webhook endpoint answers for
itself, where an SMS gateway answers for a carrier and needs a second,
payload-level layer. Neither copies nor attachments are supported — the base
defaults were already right.

The call sets `includeBearerAuthentication: false`: the kernel call layer would
otherwise inject the *caller's* bearer token, handing a user credential to a
third party. Requests are not signed, because a signature scheme is a
per-consumer contract and a guess at one is a guess the receiver cannot verify;
a deployment that has such a contract puts the header in
`TomWebhookSettings.headers`.

- **Extends:** `TomMessageTransport`

#### Constructors

```dart
TomWebhookTransport({
  TomWebhookSettings? settings,
  TomServerChannel Function(Uri endpoint)? openChannel,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `settings` | `TomWebhookSettings` | What a deployment decided once, for every call (final). |
| `openChannel` | `TomServerChannel Function(Uri)` | Opens the connection to an endpoint. Injectable so the whole classification is testable against a scripted client without a socket. It takes the endpoint because a webhook's host comes from the *message*: there is no configured server to cache a channel for, so one is opened per delivery and closed again (final). |
| `channel` | `TomMessageChannel` | *(override getter)* `TomMessageChannel.webhook`. |
| `contentType` | `static const String` | `'application/json; charset=utf-8'` — what every call declares and every body is. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomDeliveryReceipt> send(TomMessage message)` | *(override)* Permanent before any request leaves: a channel that is not `webhook`, an attachment, a copied recipient, more or fewer than one recipient (`messaging.webhook.not_one_endpoint`), or an address that is not an `http`/`https` URL (`messaging.webhook.bad_endpoint`). After the call: `2xx` is a `delivered` receipt carrying the answer as `detail`, `408`/`425`/`429`/`5xx` is transient (`messaging.webhook.refused`), any other status permanent (`messaging.webhook.rejected`), and an unreachable or unanswering endpoint transient (`messaging.webhook.unreachable`). |

### TomDeliveryReport

One thing a carrier said about one message, *after* accepting it. Tied to
anything only by `remoteId` — the value a transport put in
`TomDeliveryReceipt.remoteId`.

`at` is the **carrier's** instant where the callback supplies one, not the
moment the report was received: a report delayed by an hour of queueing
describes an hour-old event, and stamping it with arrival time would make every
latency measurement read zero.

#### Constructors

```dart
TomDeliveryReport({
  required String remoteId,
  required TomDeliveryState state,
  DateTime? at,
  String? detail,
  String? providerCode,
  String? recipient,
})

factory TomDeliveryReport.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `remoteId` | `final String` | The carrier's identifier for the message. |
| `state` | `final TomDeliveryState` | What the carrier says became of it. |
| `at` | `final DateTime` | When the carrier says that happened; arrival time when it gave none. |
| `detail` | `final String?` | The carrier's own words, verbatim. |
| `providerCode` | `final String?` | The carrier's status or error code. |
| `recipient` | `final String?` | The address the report concerns, when the carrier names it — what a failure suppresses. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `stateOf` | `static TomDeliveryState stateOf(String? name)` | The state `name` denotes, or `unknown`. Shared by the decoder and by every store that reads a state out of a column: a name written by one version and read by another must not throw, and an unrecognised state is exactly what `unknown` means. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | JSON-native values; absent rather than null for `detail` and `providerCode`. |
| `toString` | `String toString()` | *(override)* The id, the state and the provider code when there is one. |

### TomDeliveryState

What became of a message after the far side accepted it. Distinct from
`TomDeliveryOutcome`, and the distinction is the point: an outcome is what *this
attempt* achieved, a state is what the carrier did with it afterwards. A message
can be `TomDeliveryOutcome.delivered` and `TomDeliveryState.failed`.

| Value | Meaning |
| ----- | ------- |
| `delivered` | The carrier says it reached the recipient. |
| `failed` | It did not, and the carrier will not try again. |
| `expired` | The carrier gave up after its own retry window. Separate from `failed` because the remedy differs: an expiry is worth re-sending later, a failure is an address to stop using. |
| `unknown` | A report arrived carrying a status this module does not recognise. Kept rather than dropped — the report happened — and it is what an unmapped status maps to, which keeps a new carrier status from being read as success. |

### TomDeliveryCorrelation

What the module remembers about one sent message, so a later report can be
attributed to it. One row per `remoteId`, because that is the only key a carrier
callback carries; `messageId` is what a deployment actually wants back.

#### Constructors

```dart
TomDeliveryCorrelation({
  required String remoteId,
  required String messageId,
  required TomMessageChannel channel,
  required DateTime sentAt,
  TomDeliveryState? state,
  DateTime? reportedAt,
  String? detail,
  String? tenant,
  List<String> addresses = const [],
  String? providerCode,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `remoteId` | `final String` | The carrier's identifier — the row's identity. |
| `messageId` | `final String` | The `TomMessage.id` it stands for. |
| `channel` | `final TomMessageChannel` | Which channel delivered it, so a deployment routing several carriers through one endpoint can tell whose report it is reading. |
| `sentAt` | `final DateTime` | When the transport accepted the message. |
| `state` | `final TomDeliveryState?` | The last state reported, or `null` while none has arrived. |
| `reportedAt` | `final DateTime?` | When that report was recorded. |
| `detail` | `final String?` | The carrier's own words from that report. |
| `tenant` | `final String?` | The tenant the message was sent for, or `null` — so a report, which arrives carrying nothing but the carrier's id, is attributed to its tenant. `withReport` keeps it. |
| `addresses` | `final List<String>` | The addresses the message was sent to — its envelope, less the recipients the far side refused at once. What a failure report is attributed to when it names no recipient. `withReport` keeps them. |
| `providerCode` | `final String?` | The carrier's code from the last report; `withReport` takes the report's. |
| `isReported` | `bool` | *(getter)* Whether a report has been recorded. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withReport` | `TomDeliveryCorrelation withReport(TomDeliveryReport report)` | This correlation with `report` applied. |
| `toString` | `String toString()` | *(override)* The id, the message and either the state or `unreported`. |

### TomDeliveryReportStore

Remembers which message a carrier's id stands for, and the last report against
it. Addressed by `remoteId` because that is the only key a callback carries.

- **Abstract.** Implemented by `TomMemoryDeliveryReportStore` and
  `TomSqlDeliveryReportStore`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `remember` | `Future<void> remember(TomDeliveryCorrelation correlation)` | Records that the message was accepted under its remote id, replacing any row for the same id. A carrier re-using an id across messages could not be correlated at all, so the later message is the one worth keeping. |
| `messageOf` | `Future<TomDeliveryCorrelation?> messageOf(String remoteId)` | The correlation for `remoteId`, or `null`. |
| `record` | `Future<TomDeliveryCorrelation?> record(TomDeliveryReport report)` | Applies `report` and returns the updated row, or `null` when nothing was remembered under that id. A `null` is not an error: a report can arrive for a message this node never sent, or after the row was purged. |
| `purgeSentBefore` | `Future<int> purgeSentBefore(DateTime before)` | Drops correlations for messages sent before `before`. Nothing purges automatically — the index is a delivery audit trail, and how long to keep one is a deployment's decision. |

### TomMemoryDeliveryReportStore

A `TomDeliveryReportStore` in memory. Right for tests and for a single process
that only cares while it runs; wrong for anything else, because a restart loses
every id and the reports that arrive afterwards match nothing — the same caveat
`TomMessageOutbox` states about its own default store.

- **Extends:** `TomDeliveryReportStore`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `correlations` | `Iterable<TomDeliveryCorrelation>` | *(getter)* Everything remembered, for a test that wants to assert on the index. |

### TomSqlDeliveryReportStore

A `TomDeliveryReportStore` over a relational table — the durable half, and what
a deployment needs, because a carrier's callback arrives minutes or hours after
the send and a restart in between must not lose the only thing tying the two
together.

Every statement is derived from the single `deliveryReportTable` declaration, so
the DDL this store issues, the columns its statements name and the model the
convergence guard compares cannot come apart.

- **Extends:** `TomDeliveryReportStore`
- **Implements:** `TomTenantData`

#### Constructors

```dart
TomSqlDeliveryReportStore(
  TomDataSource datasource, {
  String table = defaultDeliveryReportTable,
  bool createSchema = true,
})

factory TomSqlDeliveryReportStore.named(
  String datasourceName, {
  String table = defaultDeliveryReportTable,
  bool createSchema = true,
})
```

`named` throws a `TomServerException` keyed
`messaging.delivery_report.unknown_datasource` when no such data source is
registered — a configuration error far better caught at start-up than on the
first callback.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `final TomDataSource` | The data source the table lives in. |
| `table` | `final String` | The correlation table. |
| `createSchema` | `final bool` | Whether to create the table on first use. Set it `false` when the schema is owned by the migration module. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the table if it does not exist. Idempotent and called by every operation; exposed so a start-up sequence can provision before serving. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table, for provisioning and for tests. |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | *(TomTenantData)* Deletes the tenant's delivery reports — what `TomTenancy.purgeTenant` calls. Answers how many rows were deleted. |

`remember` uses `REPLACE` rather than `INSERT`, unlike the OAuth state store: the
outbox guarantees at-least-once, so re-sending a message already accepted can
hand back an id already on file, and an insert that failed would turn a
documented duplicate into an error. `record` reads the row back rather than
believing the affected count — MariaDB reports *changed* rows, so a carrier
repeating a status it already sent affects nothing and would otherwise be
indistinguishable from an id nobody remembered.

### TomDeliveryReportRow

One row of the correlation table, as the driver hands it back. Instants are
mapped as text and parsed by `parseSqlInstant`, matching every other framework
store: the driver's own coercion differs by dialect, and that function is the
single place the framework decides what a stored instant means.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `remoteId` | `String` | `remote_id` — the carrier's identifier. |
| `messageId` | `String` | `message_id` — the message it stands for. |
| `channel` | `String` | `channel` — which channel delivered it. |
| `sentAt` | `String` | `sent_at`, as the stored `DATETIME(6)` text. |
| `state` | `String?` | `state` — the last state reported, `null` while none has arrived. |
| `reportedAt` | `String?` | `reported_at`, as the stored text. |
| `detail` | `String?` | `detail` — the carrier's own words from that report. |
| `tenant` | `String?` | `tenant` — the message's tenant, or `null`. |
| `addresses` | `String?` | `addresses` — the JSON array of the addresses the message was sent to, or `null` for none. |
| `providerCode` | `String?` | `provider_code` — the carrier's code from the last report. |

### TomDeliveryCallback

What a callback carried, independent of how it arrived — a value rather than the
request itself, so a protocol can be driven from a file drop or a queue consumer
as easily as from the endpoint, and so a protocol test needs no HTTP.

#### Constructors

```dart
TomDeliveryCallback({
  Object? body,
  Map<String, String>? parameters,
  Map<String, String>? headers,
})
```

### TomDeliveryReportProtocol

Turns a carrier's callback into reports. The same seam `TomSmsGatewayProtocol`
is, for the same reason: the callback shape is a vendor's and changes when the
vendor changes, so it is configuration rather than code. A protocol is **pure**,
which is what makes every carrier's mapping testable without an HTTP server.

- **Abstract.**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `decode` | `List<TomDeliveryReport> decode(TomDeliveryCallback callback)` | The reports one callback carried. A list because carriers batch. An empty list for a body the protocol cannot read, which the endpoint answers `400` for — throwing would be worse, because a carrier retries a `500` and gives up on a `400`. |

### TomFieldMappedDeliveryReportProtocol

A protocol described by field names and status tokens. Expresses the common
carriers without naming any of them, exactly as `TomFieldMappedSmsProtocol` does
for the submission direction. `twilio()` and `vonage()` are this mapping filled
in for those carriers' documented delivery-report callbacks, checked against the
sample callbacks they document.

- **Extends:** `TomDeliveryReportProtocol`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `remoteIdPath` | `final String` | Dotted path to the carrier's message id within one report. |
| `statusPath` | `final String` | Dotted path to the status token. |
| `detailPath` | `final String?` | Dotted path to the carrier's description. |
| `codePath` | `final String?` | Dotted path to the error or status code. |
| `recipientPath` | `final String?` | Dotted path to the recipient's address, when the carrier names it — what a failure suppresses. |
| `atPath` | `final String?` | Dotted path to the instant the carrier says the event happened. Parsed as ISO-8601, a value without a zone as UTC; a value that does not parse leaves the report stamped with arrival time, because a bad timestamp is not a reason to refuse a status. |
| `batchPath` | `final String?` | Dotted path to the array, when the carrier batches reports in one call. `null` means the body *is* one report. |
| `deliveredStatuses` | `final Set<String>` | Tokens meaning `delivered`, lowercased. |
| `failedStatuses` | `final Set<String>` | Tokens meaning `failed`; by default `failed`, `undelivered`, `rejected`, `bounce` and `bounced`. |
| `expiredStatuses` | `final Set<String>` | Tokens meaning `expired`. |
| `codeStates` | `final Map<String, TomDeliveryState>` | Error codes read as a state of their own, overriding a failed or expired status: a failure whose code says the handset was switched off is `expired`, not `failed`. |
| `unlistedFailureState` | `final TomDeliveryState` | The state of a report whose status reads as a failure and whose code is present but not in `codeStates`: `failed` by default, `unknown` in both presets, so an unclassified code suppresses nothing. |

A status in none of the three sets is `TomDeliveryState.unknown`, never
`delivered`: reading an unmapped status as success would report every new
carrier state as a delivery.

#### Constructors

```dart
const TomFieldMappedDeliveryReportProtocol({
  required String remoteIdPath,
  required String statusPath,
  String? detailPath,
  String? codePath,
  String? recipientPath,
  String? atPath,
  String? batchPath,
  Set<String> deliveredStatuses = const {'delivered'},
  Set<String> failedStatuses = const {
    'failed',
    'undelivered',
    'rejected',
    'bounce',
    'bounced',
  },
  Set<String> expiredStatuses = const {'expired'},
  Map<String, TomDeliveryState> codeStates = const {},
  TomDeliveryState unlistedFailureState = TomDeliveryState.failed,
})

factory TomFieldMappedDeliveryReportProtocol.twilio()

factory TomFieldMappedDeliveryReportProtocol.vonage()
```

| Constructor | Description |
| ----------- | ----------- |
| `twilio()` | Twilio's status callback, a form post: `MessageSid`, `MessageStatus`, `ErrorCode`, recipient `To`; no event time. `ErrorCode` 30005 and 30006 are `failed`; 30001, 30003 and 30008 `expired`; any other code on a failure `unknown`. |
| `vonage()` | Vonage's SMS delivery receipt, as a `GET` query or a JSON post: `messageId`, `status`, `err-code`, recipient `msisdn`, `message-timestamp` read as UTC. `err-code` 3, 4, 9, 11, 12 and 14 are `failed`; 2, 7 and 8 `expired`; any other code on a failure `unknown`. |

### TomDeliveryCallbackRequest

A carrier callback as a `TomDeliveryCallbackVerifier` sees it: what was
requested and what arrived, the body read once. `TomDeliveryReportEndpoint.handle`
builds one per callback before anything is decoded.

#### Constructors

```dart
TomDeliveryCallbackRequest({
  required String method,
  required Uri url,
  Map<String, String>? headers,
  String body = '',
  Map<String, String>? parameters,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `method` | `final String` | The HTTP method. |
| `url` | `final Uri` | The URL as this server received it, query included. |
| `headers` | `final Map<String, String>` | The request headers, names lowercased; unmodifiable. |
| `body` | `final String` | The body as text. |
| `parameters` | `final Map<String, String>` | The query parameters and, for a form-encoded body, its fields; unmodifiable. |
| `isForm` | `bool` | *(getter)* Whether `content-type` is `application/x-www-form-urlencoded`. |
| `isJson` | `bool` | *(getter)* Whether `content-type` names JSON. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `header` | `String? header(String name)` | The value of the header `name`, any case. |

### TomDeliveryCallbackVerifier

What gates the delivery-report endpoint: whether a request comes from the
carrier. The installation chooses one in `TomDeliveryReportEndpoint.install` — a
shared secret the carrier presents, or a carrier's request signature. Every
comparison is in constant time (`tomConstantTimeEquals`): the endpoint is public,
and an answer that comes back sooner for a wrong first byte gives the secret
away a byte at a time.

- **Abstract.**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `verify` | `bool verify(TomDeliveryCallbackRequest request)` | Whether `request` comes from the carrier. `false` is answered `401` (`messaging.delivery_report.unauthorized`). |

### TomSharedSecretCallbackVerifier

A callback gated by a shared secret the carrier — or a gateway in front of it —
presents in a header. The secret travels with every callback, so it is only as
safe as the TLS under it; a carrier that signs its requests is better verified
by its signature.

- **Extends:** `TomDeliveryCallbackVerifier`

#### Constructors

```dart
TomSharedSecretCallbackVerifier(String secret, {String header = defaultHeader})
```

Throws `TomMessagingException` (`messaging.delivery_report.empty_secret`) for an
empty `secret`: it would gate nothing.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultHeader` | `static const String` | `'x-tom-delivery-secret'`. A header rather than a query parameter, because a URL is logged by every proxy in between and a secret in a log is a secret somebody has to rotate. |
| `header` | `final String` | The header the secret is presented in. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `verify` | `bool verify(TomDeliveryCallbackRequest request)` | *(override)* Whether `header` holds the secret, compared in constant time. |
| `toString` | `String toString()` | Names the header, never the secret. |

### TomTwilioCallbackVerifier

A Twilio status callback, verified by its `X-Twilio-Signature`: HMAC-SHA1 under
the account's auth token, base64, over the full URL Twilio called (scheme
through query string) followed by the POST parameters sorted by name, each name
and value appended with no delimiter. A JSON callback is signed over the URL
alone, whose `bodySHA256` query parameter — the hex SHA-256 of the body — is
checked too. A URL is accepted signed with or without its port, because Twilio
keeps or drops it depending on the product.

Twilio puts no timestamp in the signature, so a captured callback can be
replayed; a replayed status report records the same state again.

- **Extends:** `TomDeliveryCallbackVerifier`

#### Constructors

```dart
TomTwilioCallbackVerifier(String authToken, {Uri? publicUrl})
```

Throws `TomMessagingException` (`messaging.delivery_report.empty_secret`) for an
empty `authToken`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `signatureHeader` | `static const String` | `'x-twilio-signature'`. |
| `publicUrl` | `final Uri?` | The URL Twilio calls, when it is not the one this server receives (behind a proxy or load balancer): its scheme, host and port replace the received URL's, and its path is put in front of the received path. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `signature` | `static String signature(String authToken, String url, Map<String, String> parameters)` | The signature Twilio computes for `url` and the POST `parameters` (empty for a JSON callback). |
| `calledUrl` | `Uri calledUrl(TomDeliveryCallbackRequest request)` | The URL Twilio called, as far as the request shows it — the received URL rewritten by `publicUrl`. |
| `verify` | `bool verify(TomDeliveryCallbackRequest request)` | *(override)* Whether the presented signature matches, for the URL with and without its port. |

### TomVonageSignatureMethod

How Vonage signs a request — the method the account is set to in the Vonage
dashboard.

| Value | Description |
| ----- | ----------- |
| `md5hash` | MD5 over the parameter string followed by the secret; lowercase hex. |
| `md5` | HMAC-MD5; uppercase hex. |
| `sha1` | HMAC-SHA1; uppercase hex. |
| `sha256` | HMAC-SHA256; uppercase hex. |
| `sha512` | HMAC-SHA512; uppercase hex. |

### TomVonageCallbackVerifier

A Vonage (SMS API) delivery receipt, verified by its `sig` parameter. Vonage
signs every parameter but `sig`, `timestamp` (UNIX seconds) included: each value
with `&` and `=` replaced by `_`, the parameters sorted by name and joined as
`&name=value`, then hashed per `TomVonageSignatureMethod`. The parameters are
read from the query, a form body or a flat JSON body, whichever the receipt
arrived in. A receipt whose `timestamp` is further than `maxAge` from now is
refused, so a captured receipt cannot be replayed later.

- **Extends:** `TomDeliveryCallbackVerifier`

#### Constructors

```dart
TomVonageCallbackVerifier(
  String signatureSecret, {
  TomVonageSignatureMethod method = TomVonageSignatureMethod.md5hash,
  Duration maxAge = const Duration(minutes: 5),
  DateTime Function()? clock,
})
```

Throws `TomMessagingException` (`messaging.delivery_report.empty_secret`) for an
empty `signatureSecret`. `clock` defaults to `DateTime.now`; a test passes a
fixed one.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `method` | `final TomVonageSignatureMethod` | The signing method the Vonage account is set to. |
| `maxAge` | `final Duration` | The furthest a receipt's `timestamp` may be from now — five minutes by default, as Vonage's client libraries allow. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `signature` | `static String signature(String secret, Map<String, String> parameters, {TomVonageSignatureMethod method = TomVonageSignatureMethod.md5hash})` | The signature Vonage computes for `parameters` (without `sig`). |
| `parametersOf` | `static Map<String, String> parametersOf(TomDeliveryCallbackRequest request)` | The signed parameters of a request: query and form parameters and, for a JSON body, its top-level scalar values. |
| `verify` | `bool verify(TomDeliveryCallbackRequest request)` | *(override)* Whether `sig` matches and `timestamp` is within `maxAge` of now. |

### TomDeliveryReportEndpoint

The static configuration behind `TomDeliveryReportService`, and the handler.
Static for the same reason the health module's analyzers are: a callback arrives
before any request has established a zone, and the configuration has to be
installable at start-up, before the bean context exists.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `routeUri` | `static const String` | `'/messaging/delivery-report'`. |
| `store` | `static TomDeliveryReportStore?` | *(getter)* The installed index, or `null`. |
| `protocol` | `static TomDeliveryReportProtocol?` | *(getter)* The installed mapping, or `null`. |
| `suppressions` | `static TomSuppressionList?` | *(getter)* The list a failure report adds its address to, or `null` when none is installed — then a report is recorded and nothing is suppressed. |
| `isGated` | `static bool` | *(getter)* Whether a verifier has been installed. The verifier itself is deliberately not readable: it holds a secret, and a getter returning it would put it in every diagnostic dump that walks a class's properties. |
| `reports` | `static Stream<TomDeliveryCorrelation>` | *(getter)* Correlations as each report is recorded. Carries the correlation rather than the bare report, because "the order-confirmation message failed" is actionable and "the carrier id it came back under failed" is not. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static void install({required TomDeliveryReportStore store, required TomDeliveryReportProtocol protocol, required TomDeliveryCallbackVerifier verifier, TomSuppressionList? suppressions})` | Installs what the endpoint needs, logging at info. With `suppressions`, a recorded `failed` report suppresses its address (`TomSuppressionList.applyReport`); give the same list to the `TomMessageRouter` that sends. `verifier` gates the route and has no default: a deployment that supplies none gets a route that refuses everything, which is the safe direction for a public URL. A verifier refuses an empty secret at its own construction (`messaging.delivery_report.empty_secret`). |
| `reset` | `static void reset()` | Puts the endpoint back to refusing. The supported spelling for a test, and it logs like the installation it is. |
| `handle` | `static Future<Response> handle(Request request)` | Handles one callback. Reads the body once, takes the query parameters and, for a form body (`application/x-www-form-urlencoded`), its fields as the callback's parameters, and verifies the request before decoding anything; a body that is not a form is decoded as JSON. `200` recorded (and, with a suppression list, a failure's address suppressed), `400` unreadable or no report, `401` not verified (secret or signature missing or wrong), `404` no correlation for any id named, `503` nothing installed. |

### TomDeliveryReportService

The delivery-report service interface, mounted by the endpoints pipeline.
`POST`/`GET /messaging/delivery-report`, `@TomPublicAccess`, `logRequests: false`.

Public because the caller is a carrier with no account here: it cannot present a
bearer token, so `@TomAuthenticatedAccess` would refuse every real report. The
installed `TomDeliveryCallbackVerifier` is what gates it instead.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `deliveryReport` | `Future<Response> deliveryReport(Request request)` | The route. Returns a shelf `Response` rather than a value, because the status *is* the answer a carrier acts on — it retries a `5xx` and gives up on a `4xx` — and the pipeline's own envelope would make every refusal a `500`. |

### TomDeliveryReportServer

The default `TomDeliveryReportService` implementation. Holds no state — the
configuration is `TomDeliveryReportEndpoint`'s and the request is the argument —
so the pipeline may construct it itself when an application has registered no
bean of its own.

- **Implements:** `TomDeliveryReportService`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `deliveryReport` | `Future<Response> deliveryReport(Request request)` | *(override)* Hands the request to `TomDeliveryReportEndpoint.handle`. |

### TomSuppressedAddress

One suppressed address and why: the channel, the address normalised by
`TomSuppressionList.normalize`, when it was suppressed, and the message,
carrier id, code, words and tenant of the report that added it.

#### Constructors

```dart
TomSuppressedAddress({
  required TomMessageChannel channel,
  required String address,
  DateTime? suppressedAt,
  String? messageId,
  String? remoteId,
  String? providerCode,
  String? detail,
  String? tenant,
})

factory TomSuppressedAddress.fromReport(
  TomDeliveryCorrelation correlation,
  String address,
)
```

`fromReport` is the entry a failure report on `correlation` adds for `address`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `final TomMessageChannel` | The channel the address is suppressed on. |
| `address` | `final String` | The address, normalised. |
| `suppressedAt` | `final DateTime` | When it was suppressed, in UTC. |
| `messageId` | `final String?` | The message whose failure suppressed it. |
| `remoteId` | `final String?` | The carrier's id of that message. |
| `providerCode` | `final String?` | The carrier's error code from the report. |
| `detail` | `final String?` | The carrier's words, or the reason an operator gave. |
| `tenant` | `final String?` | The tenant the failed message was sent for. |

### TomSuppressionList

The addresses no message is sent to. `TomDeliveryReportEndpoint` adds the
address of a `failed` report; `TomMessageRouter` leaves suppressed recipients
out before a transport is called. Only `failed` suppresses — an expiry is worth
another attempt and an unknown state is not evidence. A failure suppresses the
address the report names, or the message's single address; a message to several
addresses whose report names none suppresses nothing. One entry per channel and
normalised address, for the whole deployment rather than a tenant.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `normalize` | `static String normalize(TomMessageChannel channel, String address)` | `address` as the list compares it: an email address trimmed and lower-cased, a phone number reduced to its digits, any other address trimmed. |
| `addressesToSuppress` | `static List<String> addressesToSuppress(TomDeliveryCorrelation correlation, {TomDeliveryReport? report})` | The addresses a `failed` correlation suppresses: the one `report` names, else the message's single address, else none. |
| `suppress` | `Future<void> suppress(TomSuppressedAddress entry)` | Suppresses the entry's address, replacing an entry for the same address. |
| `release` | `Future<bool> release(TomMessageChannel channel, String address)` | Lifts the suppression, answering whether there was one. |
| `find` | `Future<TomSuppressedAddress?> find(TomMessageChannel channel, String address)` | The entry for the address, or `null`. |
| `suppressedAmong` | `Future<Set<String>> suppressedAmong(TomMessageChannel channel, Iterable<String> addresses)` | Those of `addresses` that are suppressed, as given. |
| `all` | `Future<List<TomSuppressedAddress>> all({TomMessageChannel? channel})` | Every entry, or those of `channel`, most recent first. |
| `applyReport` | `Future<List<TomSuppressedAddress>> applyReport(TomDeliveryCorrelation correlation, {TomDeliveryReport? report})` | Suppresses what `addressesToSuppress` names, answering the entries added; a failure of a message to several addresses whose report names none is logged and suppresses nothing. |

### TomMemorySuppressionList

A `TomSuppressionList` in memory: for tests, and for a single process that
accepts losing the list on restart.

- **Extends:** `TomSuppressionList`

### TomSqlSuppressionList

A `TomSuppressionList` over a relational table — the list a deployment keeps,
since a list in memory is lost on restart and the next message goes to the dead
address again. Every statement is derived from the single `suppressionTable`
declaration. Build it over a data source that is not routed per tenant.

- **Extends:** `TomSuppressionList`
- **Implements:** `TomTenantData`

#### Constructors

```dart
TomSqlSuppressionList(
  TomDataSource datasource, {
  String table = defaultSuppressionTable,
  bool createSchema = true,
})

factory TomSqlSuppressionList.named(
  String datasourceName, {
  String table = defaultSuppressionTable,
  bool createSchema = true,
})
```

`named` throws a `TomServerException` keyed
`messaging.suppression.unknown_datasource` when no such data source is
registered.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `final TomDataSource` | The data source the table lives in. |
| `table` | `final String` | The suppression table. |
| `createSchema` | `final bool` | Whether to create the table on first use. Set it `false` when the schema is owned by the migration module. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the table if it does not exist. Idempotent and called by every operation. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table, for tests. |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | *(TomTenantData)* Deletes the tenant's suppressed addresses — what `TomTenancy.purgeTenant` calls. Answers how many rows were deleted. |

### TomSuppressionRow

One row of the suppression table, as the driver hands it back. Instants are
mapped as text and parsed by `parseSqlInstant`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `String` | `channel` — the channel name. |
| `address` | `String` | `address` — the normalised address. |
| `suppressedAt` | `String` | `suppressed_at`, as the stored `DATETIME(6)` text. |
| `messageId` | `String?` | `message_id` — the message whose failure suppressed it. |
| `remoteId` | `String?` | `remote_id` — the carrier's id of that message. |
| `providerCode` | `String?` | `provider_code` — the carrier's error code. |
| `detail` | `String?` | `detail` — the carrier's words or an operator's reason. |
| `tenant` | `String?` | `tenant` — the tenant of the failed message. |

### TomInboxException

An inbox argument that cannot be used, raised by `TomInbox.process` before
anything is written and before the acknowledgement. Not client-visible
(`clientThrow: false`): a consumer loop raised it, not a caller.

- **Extends:** `TomServerException`

| Key | Meaning |
| --- | ------- |
| `messaging.inbox.invalid_consumer` | The consumer name is empty or longer than 150 characters. |
| `messaging.inbox.invalid_message_id` | The message id is empty or longer than 191 characters. |

Both carry the parameters `length` (the length given) and `max`.

#### Constructors

```dart
TomInboxException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
})
```

### TomInboxOutcome

The outcome of `TomInbox.process`.

#### Values

| Value | Description |
| ----- | ----------- |
| `processed` | The message was new: the work ran and was committed with its record. |
| `duplicate` | The consumer had processed the message before: the work was skipped. |

### TomInbox

The idempotent receiver. A broker that delivers at least once redelivers a
message whose acknowledgement it did not receive; the inbox records each
`(consumer, message id)` pair in the same transaction as the consumer's work and
skips the work for a pair already recorded, so the work is done once. It does
not know the broker: the work and the acknowledgement are functions, so any
consumer loop can use it.

- **Abstract.** Implemented by `TomMemoryInbox` and `TomSqlInbox`; an
  implementation supplies `recordAndRun`, `hasProcessed` and
  `purgeProcessedBefore`, and inherits `process`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `process` | `Future<TomInboxOutcome> process(String consumer, String messageId, FutureOr<void> Function() work, {FutureOr<void> Function()? acknowledge})` | Processes `messageId` for `consumer` once. Records the message and runs `work` in one transaction; a message already recorded skips `work`. After the commit — for a processed and for a duplicate message — calls `acknowledge`, the broker's acknowledgement. When `work` throws, the transaction rolls back (the record with it), `acknowledge` is not called and the error is rethrown, so the broker redelivers. Throws `TomInboxException` (`messaging.inbox.invalid_consumer` / `messaging.inbox.invalid_message_id`) for an empty or over-long name, before anything is written. |
| `recordAndRun` | `Future<TomInboxOutcome> recordAndRun(String consumer, String messageId, FutureOr<void> Function() work)` | *(abstract)* Records `messageId` for `consumer` and runs `work`, atomically; answers `duplicate` without running `work` when the record exists. The step `process` wraps with validation and acknowledgement. |
| `hasProcessed` | `Future<bool> hasProcessed(String consumer, String messageId)` | *(abstract)* Whether `consumer` has processed `messageId`. |
| `purgeProcessedBefore` | `Future<int> purgeProcessedBefore(DateTime before)` | *(abstract)* Removes the records of messages processed before `before` and answers how many were removed. A record must outlive every redelivery of its message, so `before` lies further back than the broker's longest redelivery window. Nothing purges automatically. |

### TomMemoryInbox

The inbox of one process, in memory: for tests, and for a single process whose
work is in memory too. A delivery arriving while the same message is being
processed waits for it, as the second insert does in a database. It forgets
everything on restart, so it cannot stand behind a durable broker, and there is
no transaction around the work: state the work changed before it threw stays
changed.

- **Extends:** `TomInbox`

#### Constructors

```dart
TomMemoryInbox({DateTime Function()? clock})
```

`clock` supplies the processing time a purge compares against; it defaults to
`DateTime.now`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordAndRun` | `Future<TomInboxOutcome> recordAndRun(String consumer, String messageId, FutureOr<void> Function() work)` | *(override)* Runs `work` and records the message once it completed; a record already present answers `duplicate`. A failing `work` records nothing. |
| `hasProcessed` | `Future<bool> hasProcessed(String consumer, String messageId)` | *(override)* Whether the pair is recorded. |
| `purgeProcessedBefore` | `Future<int> purgeProcessedBefore(DateTime before)` | *(override)* Removes the records processed before `before`. |

### TomSqlInbox

The inbox in a SQL data source, written in the same transaction as the
consumer's work. A tenant table: every call reaches it where the tenant in
context's data lives (`placedDatasource`), and every row names its `tenant`,
which leads the primary key. The consumer's work must write through that data
source, so both commit together; work on another data source joins the transaction only when
both are XA data sources, and work that is not a database write is not covered.
Two simultaneous deliveries of one message are serialised by the table's
primary key: the second insert waits on the first transaction and finds the row
once it commits, or claims it if the first rolled back.

Every statement is derived from the single `inboxTable` declaration.

- **Extends:** `TomInbox`

#### Constructors

```dart
TomSqlInbox(
  TomDataSource datasource, {
  String table = defaultInboxTable,
  bool createSchema = true,
  DateTime Function()? clock,
})
```

With `createSchema` (the default) the table is created on first use; a
deployment whose database user may not run DDL applies the shipped migration
and passes `false`. `clock` supplies the processing time, defaulting to
`DateTime.now`; it is stored in UTC.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `final TomDataSource` | The data source the store was built over. |
| `placedDatasource` | `TomDataSource` | *(getter)* Where the inbox and the consumer's work meet for the tenant in context: the inbox table's place (`TomFrameworkTable.placed`) of `datasource`. |
| `table` | `final String` | The inbox table's name. |
| `createSchema` | `final bool` | Whether the table is created on first use. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the inbox table in the tenant in context's data source if it does not exist, once per data source. Idempotent, and called by every operation — outside the consumer's transaction, because MariaDB commits DDL implicitly; exposed so a start-up can provision the table before consuming. |
| `recordAndRun` | `Future<TomInboxOutcome> recordAndRun(String consumer, String messageId, FutureOr<void> Function() work)` | *(override)* In `TomTransactionManager.runInTransaction`: inserts the row, ignoring a conflict, and answers `duplicate` when no row was inserted; otherwise runs `work`. A throwing `work` rolls back the insert with it. |
| `hasProcessed` | `Future<bool> hasProcessed(String consumer, String messageId)` | *(override)* Whether the row exists. |
| `purgeProcessedBefore` | `Future<int> purgeProcessedBefore(DateTime before)` | *(override)* Deletes the rows whose `processed_at` is before `before` in the data source the tenant in context reaches — every tenant's rows kept there; a tenant with a schema or database of its own is purged inside that tenant. The column is indexed. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the inbox. Not part of `TomInbox` — no consumer should want it; it exists for provisioning and tests. |

### TomInboxRow

One row of the inbox table, as `TomSqlInbox.hasProcessed` reads it. Reflected
(`@tomReflector`) and annotated `@TomDbTable` with the primary key
`consumer`, `messageId`, so the driver can map it.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `consumer` | `String` | `consumer` — the consumer name. |
| `messageId` | `String` | `message_id` — the message id. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomMimeLineEnding` | `const String` | `\r\n`, the line ending every mail protocol requires. A bare `\n` is accepted by some servers and silently corrupts the message on others. |
| `tomMimeMaxLineLength` | `const int` | `76` — the maximum line length RFC 5322 permits, excluding the line ending. |
| `tomOutboxJobName` | `const String` | `'messaging.outbox'`, the default job name the outbox registers under. Stable across restarts by necessity: it is the store key tying queued runs to the definition that knows how to execute them. |
| `tomBusRelayJobName` | `const String` | `'messaging.bus_relay'`, the default job name the bus relay registers under. Stable across restarts: it ties queued runs to the relay that publishes them. |
| `defaultDeliveryReportTable` | `const String` | `'tom_delivery_report'`, the correlation index's table name when nothing overrides it. |
| `defaultInboxTable` | `const String` | `'tom_message_inbox'`, the inbox's table name when nothing overrides it. |
| `defaultSuppressionTable` | `const String` | `'tom_message_suppression'`, the suppression list's table name when nothing overrides it. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `tomVendorValueAt` | `String? tomVendorValueAt(Object? json, String? path)` | The value at dotted `path` inside a decoded gateway answer, as text, or `null`. A segment that parses as a non-negative integer indexes a **list**; every other segment reads a map key. Shared by `TomFieldMappedSmsProtocol` and `TomFieldMappedDeliveryReportProtocol`, because a deployment reading the two side by side has every reason to expect `a.b.0.c` to mean the same thing to both. A missing key, an index past the end, or a segment applied to neither answers `null` rather than throwing: a path is configuration describing someone else's payload, and a gateway that changed its shape should produce an unclassifiable answer rather than an exception from inside a decode. A map whose keys are digits is therefore unreachable — a real limit, and not a likely one. |
| `deliveryReportTable` | `TomFrameworkTable deliveryReportTable(String table)` | The correlation table, declared **once**. The DDL `TomSqlDeliveryReportStore` issues, the column lists its statements interpolate and the schema model the convergence guard compares are all derived from this one declaration, so they cannot come apart. |
| `tomConstantTimeEquals` | `bool tomConstantTimeEquals(String a, String b)` | Whether `a` and `b` are equal, in time that depends only on their lengths — the comparison every `TomDeliveryCallbackVerifier` makes. |
| `deliveryReportTableDdl` | `String deliveryReportTableDdl(String table)` | The `CREATE TABLE` for a correlation table named `table` — what a deployment applies by hand when its database user may not run DDL and the store is constructed with `createSchema: false`. |
| `inboxTable` | `TomFrameworkTable inboxTable(String table)` | The inbox table, declared **once**: `consumer` (`VARCHAR(150)`) and `message_id` (`VARCHAR(191)`) as the composite primary key — the whole mechanism, since recording a message is an insert the key refuses for a message already processed — and `processed_at` (`DATETIME(6)`, UTC, indexed for the purge). The DDL `TomSqlInbox` issues, its statements and the schema the convergence guard compares all derive from it; listed by `frameworkOwnedTables`. |
| `inboxTableDdl` | `String inboxTableDdl(String table)` | The `CREATE TABLE` for an inbox table named `table` — what a deployment applies by hand for a renamed table, or when its database user may not run DDL and the inbox is constructed with `createSchema: false`. |
| `suppressionTable` | `TomFrameworkTable suppressionTable(String table)` | The suppression table, declared **once**: `channel` (`VARCHAR(64)`) and `address` (`VARCHAR(191)`, normalised) as the primary key, `suppressed_at` (`DATETIME(6)`, indexed) and the nullable `message_id`, `remote_id`, `provider_code`, `detail` and `tenant` of the report that added it. |
| `suppressionTableDdl` | `String suppressionTableDdl(String table)` | The `CREATE TABLE` for a suppression table named `table` — what a deployment applies by hand when the list is constructed with `createSchema: false`. |
| `tomSuppressedDetail` | `String tomSuppressedDetail(int count)` | The detail of a receipt whose every recipient was suppressed, naming how many. |

