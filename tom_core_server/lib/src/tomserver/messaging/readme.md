# messaging

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Outbound messaging: one channel-neutral message shape, one delivery contract,
and one durable queue — with SMTP, an HTTP SMS gateway, push through FCM, APNs
or a described push service, and an HTTP webhook as the four real
implementations of that contract.

The module is built in four layers, and the file names alone do not say which
layer a file belongs to. From the bottom:

1. **The message** (`message.dart`) — what is sent. A `TomMessage` names
   recipients, bodies, attachments and a *channel*, so the same envelope can be
   an email or an SMS without the caller learning a second API.
2. **The delivery contract** (`message_transport.dart`) — how anything is sent,
   plus the classified failures that decide whether a send is worth repeating.
   This one file also holds the router and the three transports that need **no
   network**, which is the thing its name does not say: a reader looking for the
   in-memory transport will not think to open it.
3. **The real transports** (`smtp_transport.dart`, `sms_transport.dart`,
   `push_transport.dart`, `webhook_transport.dart`) — the four implementations
   that do touch a wire,
   each with the wire itself behind an injectable seam so the protocol is
   testable without a server.
4. **The application layer** (`templated_message_service.dart` and the three
   services on it, plus `outbox.dart`) — resource-keyed templates, a per-channel
   request type, and the queue that makes a send survive a restart.

**This module sends, and will not receive.** There is no IMAP or POP3 client, no
mailbox, and no parser for an inbound message: `TomMimeEncoder` encodes and
never decodes. Emitting MIME is a closed problem — the framework chooses the
encoding, the boundary and the headers — while parsing it is an open one, and
tolerant parsing, character-set recovery, reply threading and attachment
extraction are each a package's worth of work whose half-done version is worse
than none. An application that needs to read mail uses a dedicated IMAP package.

**`TomSmtpTransport` requires a relay that signs.** The document goes to the
socket exactly as the encoder produced it — no `DKIM-Signature`, no key — so a
deployment sending directly to destination MX hosts must sign it. The seam needs
no new API: `encoder:` takes a `TomMimeEncoder`, and a subclass overriding
`encode` to prepend a signature to `super.encode(message)` is the whole of it.
Nothing here can report a violation, because unsigned mail is accepted and then
filed as spam.

**A template resolves to a string, and a template language is not coming.**
Conditionals, loops and partials cost their own escaping rules, their own
injection surface between a bundle and an HTML body, and a second language a
translator must learn before changing a sentence. Both cases that want one are
answered without it: a sentence included only sometimes is resolved as its own
key through `requiredText` and passed in, and a variable number of items is
joined by `requiredList` with separators from the bundle. The cost is that a
message's *structure* lives in Dart rather than in the bundle — which is the
right way round, since a translator changing wording is the frequent act and a
bundle that can change a message's shape is one that can break it.

**A webhook has nothing to template.** `TomEmailService`, `TomSmsService` and
`TomPushService` are the three templated services, each its own subclass rather
than a generalisation of another — but a webhook's recipient is a program and
its payload is `TomMessage.toJson()`, so there is no user-facing prose to
resolve and no locale to resolve it in.

**The notification model is not here and is not coming.** Which events notify,
who subscribes to them, and through which channels is the *application's*
domain vocabulary and its product's policy; this module answers only how a
message on a named channel leaves. That is a statement of ownership rather than
a deferral — see "Not in This Framework" in `doc/messaging.md` for what an
application builds it out of, all of which is already here: an open channel
value, a durable idempotent outbox, per-principal preference storage, and a
templated-service base to render each type against. Both boundaries are stated
under "Not in This Framework" in `doc/messaging.md`, with the reasoning and the
alternative for each.

`mime_encoder.dart` sits beside the SMTP transport rather than under it: the
RFC 5322 document is a value the encoder produces, not a step of the
conversation, and it is asserted directly by the test suite.

## Key types

### The message

Source: `message.dart`

| Type | What it is |
| ---- | ---------- |
| `TomMessage` | The composed message. `TomMessage.email`, `TomMessage.sms` and `TomMessage.push` are the three factories; `toJson` / `fromJson` are its round-trip. |
| `TomMessageChannel` | A value class with constants, **not** an enum — so a deployment can name a channel this package has never heard of. |
| `TomRecipient` | One addressee. The field is `address`, never `emailAddress`: for SMS it is a phone number, for push a device token. |
| `TomRecipientKind` | To, Cc or Bcc. |
| `TomMessageBody` | One representation of the content. Bodies are ordered least-preferred first, matching MIME's `multipart/alternative`. |
| `TomAttachment` | A file part, optionally inline with a content id. |
| `TomMessagingException` | The module's base error, and the supertype of every delivery failure below. |

### The delivery contract, and delivery without a network

Source: `message_transport.dart`

| Type | What it is |
| ---- | ---------- |
| `TomMessageTransport` | The contract every transport implements: send one message, return a receipt. |
| `TomDeliveryReceipt` | The result of one attempt: the outcome, the far side's id for the message, and the recipients it refused while accepting the others — a partial delivery is a real outcome, and reporting it as either success or failure loses what an operator needs. |
| `TomDeliveryOutcome` | `delivered`, `rejected`, `deferred` or `discarded`. |
| `TomDeliveryException` | The base of the one distinction a transport must get right. |
| `TomPermanentDeliveryException` | Do not retry: retrying cannot change the answer. |
| `TomTransientDeliveryException` | Retry: the same send may succeed later. |
| `TomMessageRouter` | Channel → transport. The only thing that has to know which transport serves `email`. |
| `TomMemoryMessageTransport` | Records what it was asked to send. What a test asserts against. |
| `TomNoOpMessageTransport` | Accepts and discards — how a deployment says "this channel is not configured" without failing to start. |
| `TomFileMessageTransport` | Writes each message to a file, for a developer who wants to *read* what would have been sent. |

### SMTP

Source: `smtp_transport.dart`

| Type | What it is |
| ---- | ---------- |
| `TomSmtpTransport` | Real email delivery. Drives the conversation through the interface below, never a socket directly. |
| `TomSmtpSettings` | Host, port, credentials and security for one relay. |
| `TomSmtpSecurity` | Plain, STARTTLS or implicit TLS. |
| `TomSmtpConnection` | The injectable seam. This is what lets the suite assert STARTTLS, AUTH, a rejected recipient and a `4xx` deferral with no relay running. |
| `TomSocketSmtpConnection` | The production implementation of that seam, over a real socket. |
| `TomSmtpReply` | One reply: the code, and the lines that came with it. |

### SMS

Source: `sms_transport.dart`

There is no `TomSmsConnection` mirroring `TomSmtpConnection`, because SMS has no
protocol — every gateway is an HTTP API of its own invention. The vendor's
vocabulary goes behind a protocol object instead.

| Type | What it is |
| ---- | ---------- |
| `TomSmsTransport` | Real SMS delivery over an HTTP gateway. One request per recipient, so partial delivery stays per-number. |
| `TomSmsGatewaySettings` | Endpoint, credentials and defaults for one gateway. |
| `TomSmsAuthScheme` | How that gateway is authenticated against. |
| `TomSmsGatewayProtocol` | The vendor mapping: request out, answer in. |
| `TomFieldMappedSmsProtocol` | The one shipped implementation — expresses the common gateways by naming their fields rather than by writing code per vendor. |
| `TomSmsSubmission` | One message to one number, already measured — what a protocol is handed to encode. |
| `TomSmsGatewayRequest` | The request a protocol builds. |
| `TomSmsGatewayAnswer` | The answer a protocol reads, before it becomes a receipt. |
| `TomSmsBodyFormat` | How the request body is encoded. |
| `TomSmsSegmentation` | GSM 03.38 length arithmetic. `text.length` is the wrong number in three separate ways, and an SMS is billed per *segment*. |
| `TomSmsEncoding` | GSM or UCS-2 — one character outside GSM 03.38 moves the whole message. |

### Push

Source: `push_transport.dart`

The SMS gateway's shape — the transport owns what every push service shares,
a protocol the vendor's vocabulary — with the two services that reach nearly
every device written down rather than described.

| Type | What it is |
| ---- | ---------- |
| `TomPushTransport` | Real push delivery. One request per device token, so a dead token is a rejected recipient rather than a failed message; a rejected credential is refreshed and the token tried once more. |
| `TomPushProtocol` | The service mapping: request out, answer in, credential codes recognised. |
| `TomFcmPushProtocol` | Firebase Cloud Messaging's HTTP v1 API. |
| `TomApnsPushProtocol` | Apple's push service, over HTTP/2. |
| `TomFieldMappedPushProtocol` | Any other JSON push API, described by field paths. |
| `TomPushCredential` | The bearer token a service authenticates with, and how to forget it. |
| `TomFcmServiceAccountCredential` | An FCM access token minted from a service-account key and cached until shortly before it expires. |
| `TomApnsProviderToken` | An ES256 APNs provider token, reused for fifty minutes. |
| `TomStaticPushCredential` | A token the deployment already has. |
| `TomPushExchange` · `TomHttp1PushExchange` · `TomHttp2PushExchange` | The wire by HTTP version — the injectable seam, and the reason APNs works at all: it answers only HTTP/2. |
| `TomPushSubmission` · `TomPushGatewayRequest` · `TomPushGatewayResponse` · `TomPushGatewayAnswer` | The values a protocol maps between, so `encode` and `decode` stay pure. |

Both vendor protocols are tested against scripted answers in the vendors'
documented formats, not against the live services.

### Webhook

Source: `webhook_transport.dart`

| Type | What it is |
| ---- | ---------- |
| `TomWebhookTransport` | POSTs `TomMessage.toJson()` to the URL in the message's recipient address, as `application/json`. Classified by HTTP status alone — a webhook endpoint answers for itself, where an SMS gateway answers for a carrier. |
| `TomWebhookSettings` | The timeout, headers applied to every call (they win over the message's, because they carry the credential), and how much of the answer the receipt keeps. |

A message addressing two URLs is refused **permanently**: the outbox retries a
message rather than a recipient, so a POST that succeeded at one endpoint and
failed at another would be re-sent to both, and a webhook is not idempotent.
Fan-out is two messages.

### Delivery reports

Source: `delivery_report.dart`, `delivery_report_sql.dart`,
`sql_delivery_report_store.dart`, `delivery_report_endpoint.dart`

A transport's receipt records that the far side *accepted* the message. What the
carrier did with it afterwards arrives minutes or hours later, on a callback, and
`TomDeliveryReceipt.remoteId` is the only thread between the two.

| Type | What it is |
| ---- | ---------- |
| `TomDeliveryReport` · `TomDeliveryState` | What a carrier says became of a message. A state is not an outcome: a message can be `TomDeliveryOutcome.delivered` and `TomDeliveryState.failed`. |
| `TomDeliveryCorrelation` | The `remoteId` → message row: which message an id stands for, and the last state reported. |
| `TomDeliveryReportStore` · `TomMemoryDeliveryReportStore` · `TomSqlDeliveryReportStore` · `TomDeliveryReportRow` | The index. Memory is right for a test; the SQL store is what a deployment needs, because a callback that arrives after a restart must still match. |
| `deliveryReportTable` · `deliveryReportTableDdl` · `defaultDeliveryReportTable` | The table, declared once — the DDL, the statements and the convergence guard all derive from it. |
| `TomDeliveryReportProtocol` · `TomFieldMappedDeliveryReportProtocol` · `TomDeliveryCallback` | The carrier's callback shape, described in configuration rather than coded — the same seam `TomSmsGatewayProtocol` is, and with no vendor presets for the same reason. |
| `TomDeliveryReportService` · `TomDeliveryReportServer` · `TomDeliveryReportEndpoint` | The inbound `POST /messaging/delivery-report` route. Public, because a carrier has no account here, and gated by a shared secret compared in constant time. Nothing is installed by default, and an uninstalled endpoint refuses everything. |

### The vendor mapping's path

Source: `vendor_mapping.dart`

| Type | What it is |
| ---- | ---------- |
| `tomVendorValueAt` | The dotted-path reader `TomFieldMappedSmsProtocol` and `TomFieldMappedDeliveryReportProtocol` share. A numeric segment indexes a **list**, because almost every gateway wraps its answer in one — Vonage, MessageBird, Infobip, Plivo and ClickSend all answer per recipient. Twilio is the outlier, and a map-only reader would express Twilio and none of the others. |

Worked mappings for three named vendors live in
`example/messaging/sms_gateway_presets.dart`, as an **example** rather than as
library API: a preset in the framework is a vendor's API frozen into a release,
and a stale example is obviously the reader's to update while stale library API
is not.

### The MIME document

Source: `mime_encoder.dart`

| Type | What it is |
| ---- | ---------- |
| `TomMimeEncoder` | Renders a `TomMessage` as the RFC 5322 / MIME document a relay receives. Writes no `Bcc:` header at all — naming blind copies in the document is what makes a blind copy not blind. |

### The durable queue

Source: `outbox.dart`

| Type | What it is |
| ---- | ---------- |
| `TomMessageOutbox` | The send queue, on the kernel's job scheduler. A send that outlives the process that asked for it, with retry driven by the permanent/transient distinction above. |
| `tomOutboxJobName` | The scheduler job name the outbox registers under (`messaging.outbox`). |

### Application messaging

Source: `templated_message_service.dart`, `email_service.dart`, `sms_service.dart`, `push_service.dart`

| Type | What it is |
| ---- | ---------- |
| `TomTemplatedMessageService` | The shared base owning `send`, `sendNow` and `requiredText`. A subclass supplies only `channelName` and `render`, so the convention cannot drift per channel. |
| `TomEmailRequest` | An email named by a template key. Has **no** subject field: a request type that cannot express a literal is a resource rule the compiler enforces. |
| `TomEmailService` | Resolves `<templateKey>.subject` / `.text` / `.html` in the recipient's locale and queues the result. |
| `TomSmsRequest` | The same for SMS, with no text field. |
| `TomSmsService` | One sub-key — `<templateKey>.text` is the whole template — plus the segment budget, checked before anything is queued. |
| `TomPushRequest` | The same for push, with no title or body field, and a data map for the app. |
| `TomPushService` | Two sub-keys — `<templateKey>.title` and `.body`, both required. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final message = TomMessage.email(
    from: TomRecipient('build@example.com', displayName: 'Build Robot'),
    to: [TomRecipient('ada@example.com')],
    subject: 'Nightly build failed',
    text: 'The 03:00 build failed on step 4.',
  );

  // No relay, no socket: the stand-in transport records what it was asked to
  // send, which is what makes every rule above assertable in a unit test.
  final transport = TomMemoryMessageTransport();
  final receipt = await transport.send(message);

  print(message.channel.name);   // email
  print(receipt.outcome.name);   // delivered
}
```

See [`doc/messaging.md`](../../../../doc/messaging.md) for the full treatment:
why this is not a mailer call, the open-channel decision, the one distinction a
transport must get right, the SMTP conversation, the SMS gateway shape and its
segment arithmetic, the push protocols and credentials, what "queued" guarantees, and the application template rule.
The connection-free surface runs in
`example/messaging/messaging_example.dart` and, for the template layer, in
`example/messaging/messaging_templated_example.dart` — `test/messaging_test.dart`
executes both and requires them to exit 0, and that same suite drives the SMTP
and SMS protocols through their injectable seams.
`test/email_service_test.dart`, `test/sms_service_test.dart` and
`test/push_service_test.dart` cover the three application services,
`test/sms_transport_test.dart` the gateway mapping and its segment arithmetic,
`test/push_transport_test.dart` the push protocols, credentials and exchanges, and `test/readme_quick_start_test.dart` runs the snippet
above.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
