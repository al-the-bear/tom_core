# messaging

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Outbound messaging: one channel-neutral message shape, one delivery contract,
and one durable queue — with SMTP and an HTTP SMS gateway as the two real
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
3. **The real transports** (`smtp_transport.dart`, `sms_transport.dart`) — the
   two implementations that do touch a wire, each with the wire itself behind an
   injectable seam so the protocol is testable without a server.
4. **The application layer** (`templated_message_service.dart` and the two
   services on it, plus `outbox.dart`) — resource-keyed templates, a per-channel
   request type, and the queue that makes a send survive a restart.

`mime_encoder.dart` sits beside the SMTP transport rather than under it: the
RFC 5322 document is a value the encoder produces, not a step of the
conversation, and it is asserted directly by the test suite.

## Key types

### The message

Source: `message.dart`

| Type | What it is |
| ---- | ---------- |
| `TomMessage` | The composed message. `TomMessage.email` and `TomMessage.sms` are the two factories; `toJson` / `fromJson` are its round-trip. |
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

Source: `templated_message_service.dart`, `email_service.dart`, `sms_service.dart`

| Type | What it is |
| ---- | ---------- |
| `TomTemplatedMessageService` | The shared base owning `send`, `sendNow` and `requiredText`. A subclass supplies only `channelName` and `render`, so the convention cannot drift per channel. |
| `TomEmailRequest` | An email named by a template key. Has **no** subject field: a request type that cannot express a literal is a resource rule the compiler enforces. |
| `TomEmailService` | Resolves `<templateKey>.subject` / `.text` / `.html` in the recipient's locale and queues the result. |
| `TomSmsRequest` | The same for SMS, with no text field. |
| `TomSmsService` | One sub-key — `<templateKey>.text` is the whole template — plus the segment budget, checked before anything is queued. |

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
segment arithmetic, what "queued" guarantees, and the application template rule.
The connection-free surface runs in
`example/messaging/messaging_example.dart`, which
`test/messaging_test.dart` executes and requires to exit 0; that same suite
drives the SMTP and SMS protocols through their injectable seams.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
