# Messaging Module

The outbound message substrate: a channel-neutral message shape, a transport
contract, an SMTP implementation, stand-in transports for tests and local runs,
and a durable outbox that queues delivery onto the kernel's job scheduler.

This module is **transport only**. It carries a message someone else decided to
send. It does not model notification types, subscriptions or user preferences —
that is a separate decision, and building the wire first is what lets that
decision be made on the merits rather than around a missing substrate.

## Table of Contents

- [Overview](#overview)
- [Why Not Just Call a Mailer](#why-not-just-call-a-mailer)
- [The Message Shape](#the-message-shape)
- [Channels Are Open, Not an Enum](#channels-are-open-not-an-enum)
- [The One Distinction a Transport Must Get Right](#the-one-distinction-a-transport-must-get-right)
- [The Transport Contract](#the-transport-contract)
- [Routing](#routing)
- [Stand-In Transports](#stand-in-transports)
- [SMTP](#smtp)
- [Configuration and Secrets](#configuration-and-secrets)
- [The MIME Document](#the-mime-document)
- [Delivery Semantics: One Retry Mechanism](#delivery-semantics-one-retry-mechanism)
- [What "Queued" Guarantees](#what-queued-guarantees)
- [Failure Reporting](#failure-reporting)
- [Wiring a Server](#wiring-a-server)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomMessage` | class | One composed message: sender, recipients, subject, bodies, attachments |
| `TomRecipient` / `TomRecipientKind` | class / enum | One addressee; primary, copied or blind-copied |
| `TomMessageBody` / `TomAttachment` | classes | A typed body part; a named binary part, optionally inline |
| `TomMessageChannel` | class | An open named value — `email`, `sms`, `push`, `webhook`, or yours |
| `TomMessageTransport` | abstract class | One delivery channel: one attempt at one message |
| `TomDeliveryReceipt` / `TomDeliveryOutcome` | class / enum | What became of an attempt, including partial delivery |
| `TomDeliveryException` / `TomPermanentDeliveryException` | classes | A failure, classified transient or permanent |
| `TomMessageRouter` | class | Maps a channel to its transport |
| `TomMemoryMessageTransport` | class | Captures messages in memory; the test stand-in |
| `TomNoOpMessageTransport` | class | Accepts and discards; the local-run stand-in |
| `TomFileMessageTransport` | class | Writes each message to a `.eml` file |
| `TomSmtpTransport` / `TomSmtpSettings` / `TomSmtpSecurity` | classes / enum | Real delivery over SMTP |
| `TomSmtpConnection` / `TomSocketSmtpConnection` / `TomSmtpReply` | abstract class / classes | The wire, behind an interface so the protocol is testable |
| `TomMimeEncoder` | class | Renders a `TomMessage` as an RFC 5322 / MIME document |
| `TomMessageOutbox` | class | The durable send queue in front of a router |
| `TomMessagingException` | class | The module's base error |

## Why Not Just Call a Mailer

Sending mail synchronously inside a request ties that request's latency to a
mail server's mood, and loses the message when either end restarts. Both
failures are invisible in development — a local relay answers in a millisecond
and never restarts mid-request — and both are routine in production.

So the module separates three things a single `sendMail()` call conflates:

1. **Composition** — what the message *is* (`TomMessage`). Independent of how it
   travels.
2. **Delivery** — one attempt over one protocol (`TomMessageTransport`).
   Independent of whether it should be retried.
3. **Semantics** — durability, retry, backoff, failure reporting
   (`TomMessageOutbox`, on the kernel's scheduler). Independent of the protocol.

Each is testable alone, which is why the entire suite runs without a socket.

## The Message Shape

```dart
final message = TomMessage.email(
  from: TomRecipient('build@example.com', displayName: 'Build Robot'),
  to: [TomRecipient('ada@example.com')],
  subject: 'Nightly build failed',
  text: 'The 03:00 build failed on step 4.',
  html: '<p>The 03:00 build failed on <b>step 4</b>.</p>',
);
```

Notes on the shape, each of which is a decision rather than an accident:

- **`TomRecipient.address`, not `emailAddress`.** For SMS it is a phone number,
  for push a device token, for a webhook a URL. Naming the field after the one
  channel that happens to use `@` is how a transport-neutral type stops being
  one.
- **Bodies are ordered least-preferred first**, matching MIME's
  `multipart/alternative` convention, so `bodies.last` — exposed as
  `preferredBody` — is what a capable client shows.
- **An unaddressed message is rejected at composition**, not at delivery. The
  caller who forgot the recipient is on the stack now; minutes later, on a retry
  in another isolate, they are not.
- **`id` is generated when omitted.** It is the correlation key in logs,
  receipts and the queue — see [idempotence](#what-queued-guarantees).
- **`headers` and `metadata` are unmodifiable once composed.** A message that
  can be edited after being queued is a message whose retry does not resend what
  the first attempt sent.
- **The envelope includes Bcc; the document does not.** `envelopeAddresses`
  returns every addressee including blind copies, because that is what a
  transport delivers to. `TomMimeEncoder` writes no `Bcc:` header at all —
  naming blind copies in the document is what makes a blind copy not blind.

## Channels Are Open, Not an Enum

`TomMessageChannel` is a value class with constants, not an enum:

```dart
const slack = TomMessageChannel('slack');
```

An enum would mean that a deployment with an internal channel has to patch the
framework to name it. The four the framework itself anticipates —
`email`, `sms`, `push`, `webhook` — are constants and are listed in
`TomMessageChannel.standard`; anything else is equally valid and routes the
same way.

## The One Distinction a Transport Must Get Right

Delivery fails in two fundamentally different ways, and conflating them is the
classic mailer bug:

| | Meaning | Correct response |
| --- | --- | --- |
| **Transient** | The far side is down, the connection dropped, the server said "try later" (SMTP `4xx`) | Retry — it is the *only* correct response |
| **Permanent** | The address does not exist, the credential was rejected, the message was refused (SMTP `5xx`) | Do not retry — it will fail identically, wasting the budget and delaying a report the caller could act on now |

Two properties make this decision load-bearing rather than advisory:

1. **The transport makes the call**, because only the transport can read the far
   side's answer. `TomDeliveryException.permanent(...)` and `.transient(...)`
   cannot be built with the wrong classification by accident.
2. **A permanent failure mixes in the kernel's `TomPermanentFailure`**, which
   `TomScheduler` already honours. The judgement is made once, at the point
   where the evidence is, and nothing downstream re-derives it.

The default is *transient*. An unrecognised error is retried, because retrying a
permanent failure costs a few wasted attempts whereas dropping a transient one
loses the message.

## The Transport Contract

```dart
abstract class TomMessageTransport {
  TomMessageChannel get channel;
  bool get supportsCopies;       // Cc / Bcc
  bool get supportsAttachments;
  Future<TomDeliveryReceipt> send(TomMessage message);
  Future<void> close();
}
```

A transport does **one attempt at one message** and reports what happened. It
does not retry, does not queue, and does not decide whether to send. That is
precisely what makes `TomMemoryMessageTransport` a complete stand-in for
`TomSmtpTransport`: there is nothing else in the interface to fake.

`checkSupported(message)` raises a *permanent* failure when a message asks for
something the channel cannot do — a wrong channel, attachments on a transport
without them, or copies on one without them. Copies fail rather than degrade:
delivering the Cc list as primary recipients would disclose the recipients to
each other, which is a privacy incident, not a fallback.

Failures are **thrown**, not returned as a failed receipt, so a caller who
ignores the return value cannot silently drop mail.

## Routing

```dart
final router = TomMessageRouter([
  TomSmtpTransport(settings),
  TomNoOpMessageTransport(channel: TomMessageChannel.sms),
]);
```

One transport per channel; registering again replaces. An **unrouted channel is
a permanent failure** — no amount of retrying adds a transport, and a deployment
that named a channel it did not wire up needs to hear about it on the first
attempt rather than after the retry budget runs out.

`TomMessageRouter.send` is `async` deliberately, so that failure arrives on the
returned future rather than being thrown synchronously out of the call. A caller
who handles failures the way a future-returning API invites — `.catchError`, or
`await` inside a `try` — would otherwise miss the one failure most likely in a
half-configured deployment.

## Stand-In Transports

Three, because "no mail server" means three different things:

| Transport | Outcome | For |
| --------- | ------- | --- |
| `TomMemoryMessageTransport` | `delivered` | Tests. Captures `sent` and `receipts`; `failNext` (consumed on use) and `failAlways` inject classified failures |
| `TomNoOpMessageTransport` | `discarded` | Local runs and CI. Accepts everything, sends nothing |
| `TomFileMessageTransport` | `delivered` | Local development where you want to *read* the result: writes `<stamp>_<id>.eml` |

`TomNoOpMessageTransport` reports `discarded` rather than `delivered` because
the receipt must not claim something that did not happen — an operator reading a
receipt trail should be able to tell a real delivery from a stand-in.

This is what makes a spec that names `email` exercisable without a mail server.

## SMTP

`TomSmtpTransport` implements the protocol directly over `dart:io` sockets
rather than wrapping a mailer package. Owning the conversation is what lets the
transient/permanent classification live in one documented place, keyed off the
reply codes the protocol already defines.

The conversation, in order:

```
  220 greeting  →  EHLO (falling back to HELO)
  →  STARTTLS + re-greet, when configured
  →  AUTH PLAIN or LOGIN, when credentials are configured
  →  MAIL FROM  →  RCPT TO (one per recipient, collecting refusals)
  →  DATA / 354  →  the MIME document  →  250
  →  QUIT
```

Details worth knowing:

- **Recipient refusals are collected, not fatal.** One dead address in a
  distribution list must not cost the other four their mail. The receipt carries
  `rejectedRecipients` and `isPartial`. *Every* address refused is a permanent
  failure — there is nobody left to deliver to.
- **A `4xx` on a recipient defers the whole message**, because retrying it later
  is exactly what the server asked for.
- **A required STARTTLS that the relay does not offer is permanent.** Silently
  continuing in the clear would send the password in the clear.
- **A rejected credential names `smtpPassword`** in the failure, because the
  operator's next action is to fix a setting, and the setting should be named.
- **`QUIT` and `close` are best-effort.** A failure while hanging up does not
  undo a delivery the server already accepted.

The protocol runs against the `TomSmtpConnection` interface, and the transport
takes an injectable `connect` function. That is how `test/messaging_test.dart`
asserts the branches that matter most — a relay that does not offer STARTTLS, a
rejected credential, one dead address, a `4xx` deferral — which are precisely
the ones a real relay will not produce on demand.

## Configuration and Secrets

The declarations live on `TomBaseServerConfiguration`:

| Setting | Default | Meaning |
| ------- | ------- | ------- |
| `smtpHost` | *unset* | Unset means **this deployment sends no mail** |
| `smtpPort` | `0` | Unconfigured sentinel; resolved from the security mode (25 / 587 / 465) |
| `smtpSecurity` | `startTls` | `none` \| `startTls` \| `implicitTls`; an unrecognised value falls back here |
| `smtpUsername` / `smtpPassword` | *unset* | Credentials; **`smtpPassword` is secret-bearing** |
| `smtpFromAddress` / `smtpFromName` | *unset* | The default sender for messages composed without one |
| `smtpClientName` | `localhost` | The name announced in `EHLO` |
| `smtpAllowInsecureCertificate` | `false` | Development only |

Two rules govern the secret, per the CodeSpecs configuration model:

1. **The declaration is authorable; the value is not.** `smtpPassword`'s shape
   and source key live in configuration so they are known and documented. Its
   *value* is supplied out-of-band at deploy time through the ordinary
   precedence chain — configuration tree, OS environment, `.env`, command line —
   and must never be written into a spec or a checked-in configuration tree.
2. **A missing secret fails at startup, not at the first notification.**
   `TomSmtpSettings` rejects a username with no password at construction, so a
   deployment that forgot to supply it gets a message naming the setting rather
   than a `535` hours later.

`TomSmtpSettings.toString()` never includes the password.

```dart
final settings = TomSmtpSettings.fromConfiguration(config);   // null ⇒ no mail
router.register(settings == null
    ? const TomNoOpMessageTransport()
    : TomSmtpTransport(settings));
```

An unset host returning `null` rather than throwing is deliberate: a test run, a
local build and a CI job all want a server that composes messages and never
delivers them, and that should not require a mail server to be reachable.

`smtpSecurity` **fails closed** on a typo — an unrecognised value lands on
`startTls`, not on `none`, so a misspelling cannot silently downgrade a
deployment to plaintext.

## The MIME Document

`TomMimeEncoder` renders a `TomMessage` as an RFC 5322 message. The structure
follows the content rather than being fixed:

| Content | Structure |
| ------- | --------- |
| One body, no attachments | A single part |
| Text + HTML | `multipart/alternative` |
| Bodies + inline attachments (`contentId` set) | `multipart/related` |
| Bodies + file attachments | `multipart/mixed` |

Headers are written From / To / Cc / Reply-To / Subject / Date / Message-ID /
MIME-Version, with caller-supplied headers **last** so an application header
cannot displace a structural one. Non-ASCII header values are RFC 2047 encoded;
base64 bodies are wrapped at 76 columns.

There is no `Bcc:` header, ever. See [the message shape](#the-message-shape).

## Delivery Semantics: One Retry Mechanism

A queue with retries, backoff, at-most-one-runner-per-item and failure alerts is
substantial machinery, and this framework already has it: the kernel's job
scheduler. A second one here would mean two backoff curves to tune, two places a
message can get stuck, and two answers to "why hasn't this been delivered".

So **`TomMessageOutbox` owns no retry logic whatsoever.** It enqueues a job run
per message; the scheduler does the rest:

| Concern | Where it lives |
| ------- | -------------- |
| Durability across restarts | `TomJobStore` |
| Retry count and backoff | `TomRetryPolicy` |
| One delivery at a time per message | The run's coordination lease |
| Recovering a run whose node died | The scheduler's lease timeout |
| Failure reporting | `TomJobAlertSink` |
| Giving up permanently | `TomPermanentFailure` on the thrown error |

The outbox contributes only the *shape* of the run: a message as the payload, a
body that hands it to a `TomMessageRouter`.

**Worked example.** `advanced_ops_server`'s digest job composes a message and
hands it over; a *second* scheduler delivers it. `test/ops_digest_test.dart`
asserts the consequence that makes the split worth having — a failed send is
redelivered **without recomposition**, so the digest a reader eventually receives
is the one that was true when it was composed. The job itself therefore declares
`TomRetryPolicy.none`: the retry budget belongs to the outbox, per message. See
[`README_advanced_14_operations.md`](../../tom_core_samples/README_advanced_14_operations.md).

Three consequences of that choice, each of which is a deliberate detail:

**The outbox runs its own scheduler.** A scheduler has one dispatcher, and a
delivery body holds a live transport — a socket factory, an open connection —
which cannot be copied into an isolate. Delivery is also the wrong kind of work
for one: it is latency-bound, not CPU-bound, so awaiting a socket already leaves
the event loop free. Rather than making that a rule callers must remember, the
outbox constructs an inline-dispatching scheduler of its own. Point it at the
same `TomJobStore` as the application's scheduler and the two coexist by design
— the scheduler declines to claim runs whose job it has not registered.

**`send` enqueues directly rather than through the schedule's event stream.**
The scheduler collapses events arriving in the same clock instant into a single
windowed run. That is correct for a trigger — two ticks of the same moment are
one moment — and catastrophic for an outbox, where two messages composed in the
same microsecond are two messages.

**The run id is the message id.** `'<jobName>:<messageId>'`, which makes the
message its own idempotence key: submitting the same message twice replaces the
queued run rather than queueing a second copy. A caller retrying a `send` it is
unsure completed must not cause two deliveries.

The default retry policy is five attempts over a widening backoff — five rather
than the framework default of three, because a mail relay's transient refusals
(greylisting above all) are routinely measured in minutes, and a budget that
expires inside the greylist window turns a deliberate delay into a lost message.

## What "Queued" Guarantees

**At-least-once** — the same guarantee the scheduler states for every job. A
message whose delivery succeeded but whose completion was not recorded before
the process died is delivered again. That is a property of every durable queue
talking to a system without transactional handoff, SMTP very much included, and
it is stated here rather than papered over.

The default store is `TomMemoryJobStore`, which is right for tests and wrong for
production: an outbox on a memory store loses everything queued when the process
stops, which is precisely the failure queuing exists to prevent. Supply a
durable store for any deployment that means it.

Nothing purges automatically. A delivered message stays in the store as a
completed run, which is a delivery audit trail and may be worth keeping; how
long is a deployment's decision, so `purgeFinished(before)` exists but is never
called on your behalf.

## Failure Reporting

Two channels, deliberately not overlapping:

- **`outbox.receipts`** — a broadcast stream of every delivery that reached a
  transport, including partial ones and discards.
- **The scheduler's `TomJobAlertSink`** — every failure, with the attempt
  number, the retry decision, and the run whose payload is the message.

Failures are *not* on the receipt stream. Emitting them on both would make "how
many times did this fail" a question with two answers.

## Wiring a Server

```dart
final settings = TomSmtpSettings.fromConfiguration(config);
final router = TomMessageRouter([
  settings == null ? const TomNoOpMessageTransport() : TomSmtpTransport(settings),
]);

final outbox = TomMessageOutbox(
  router: router,
  store: myDurableJobStore,          // the same store the app scheduler uses
  onAlert: myAlertSink,
)..start();

await outbox.send(TomMessage.email(
  to: [TomRecipient('ops@example.com')],
  subject: 'Nightly build failed',
  text: 'See the attached log.',
));
```

`send` returns as soon as the message is durably queued. `sendNow` queues and
then ticks immediately, for a case where a fifteen-second tick interval is felt
by a human staring at an inbox — a password reset, say. A failure still retries
on the queue exactly as `send` would; the only difference is that the first
attempt does not wait.

`outbox.close()` stops delivery and releases the scheduler, and leaves the
router open: a router shared with the rest of the application must not be torn
down because the outbox stopped.

## Core Components

- **`TomMessage` / `TomRecipient` / `TomRecipientKind` / `TomMessageBody` /
  `TomAttachment` / `TomMessageChannel`** — the composed message and its JSON
  round-trip.
- **`TomMessageTransport` / `TomDeliveryReceipt` / `TomDeliveryOutcome` /
  `TomDeliveryException` / `TomPermanentDeliveryException`** — the delivery
  contract and its classified failures.
- **`TomMessageRouter`** — channel → transport.
- **`TomMemoryMessageTransport` / `TomNoOpMessageTransport` /
  `TomFileMessageTransport`** — delivery without a network.
- **`TomSmtpTransport` / `TomSmtpSettings` / `TomSmtpSecurity` /
  `TomSmtpConnection` / `TomSocketSmtpConnection` / `TomSmtpReply`** — real
  delivery, with the wire behind an interface.
- **`TomMimeEncoder`** — the RFC 5322 / MIME document.
- **`TomMessageOutbox` / `tomOutboxJobName`** — the durable send queue.
- **`TomMessagingException`** — the module's base error.

## Not Yet Implemented

- **Transports for the other three channels.** `sms`, `push` and `webhook` are
  named constants with no implementation; the contract is what they will
  implement, and a `TomNoOpMessageTransport` registered on those channels makes
  a spec that names them runnable in the meantime.
- **The notification model.** Channels, notification types, per-user
  preferences and subscription resolution are a separate concern, deliberately
  not designed here.
- **Inbound mail.** This module sends only.
- **Templating.** A message body is a string; rendering one from a template with
  a data context belongs above this layer.
- **DKIM signing**, and other outbound authentication beyond what the relay
  itself performs.

## Dependencies

- `tom_core_kernel` — `TomScheduler`, `TomJobStore`, `TomJobDefinition`,
  `TomRetryPolicy`, `TomJobAlertSink`, `TomPermanentFailure`, `TomCommand`,
  `TomClosable`, `tomLog`.
- `async` — `StreamQueue` drives the SMTP line protocol.
- `path` — file naming in `TomFileMessageTransport`.
- `dart:io` — `Socket` / `SecureSocket`.
