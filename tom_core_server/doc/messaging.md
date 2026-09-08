# Messaging Module

The outbound message substrate: a channel-neutral message shape, a transport
contract, two real implementations — SMTP and an HTTP SMS gateway — stand-in
transports for tests and local runs, a durable outbox that queues delivery onto
the kernel's job scheduler, and a templating layer that composes every message
from resource keys so no user-facing string is written in Dart.

This module does **not** model notification types, subscriptions or user
preferences. That is a separate decision, and building the wire first is what
lets it be made on the merits rather than around a missing substrate.

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
- [SMS: One Gateway Shape, No Vendor Names](#sms-one-gateway-shape-no-vendor-names)
  - [Composing one](#composing-one)
  - [Segments, not characters](#segments-not-characters)
  - [Two layers of classification](#two-layers-of-classification)
  - [Describing a gateway](#describing-a-gateway)
- [Configuration and Secrets](#configuration-and-secrets)
- [The MIME Document](#the-mime-document)
- [Delivery Semantics: One Retry Mechanism](#delivery-semantics-one-retry-mechanism)
- [What "Queued" Guarantees](#what-queued-guarantees)
- [Failure Reporting](#failure-reporting)
- [Wiring a Server](#wiring-a-server)
- [Application Email: A Template Key, Not a Body](#application-email-a-template-key-not-a-body)
  - [The three sub-keys](#the-three-sub-keys)
  - [Locale comes from the recipient, not the process](#locale-comes-from-the-recipient-not-the-process)
  - [Sentences a mail includes only sometimes](#sentences-a-mail-includes-only-sometimes)
  - [A missing key fails before anything is queued](#a-missing-key-fails-before-anything-is-queued)
  - [Always through the outbox](#always-through-the-outbox)
- [Application SMS: The Same Rule, Plus a Length](#application-sms-the-same-rule-plus-a-length)
  - [The shared base](#the-shared-base)
  - [Two caps, deliberately](#two-caps-deliberately)
  - [Addressing a principal](#addressing-a-principal)
- [Verification](#verification)
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
| `TomDeliveryException` / `TomPermanentDeliveryException` / `TomTransientDeliveryException` | classes | A failure, classified transient or permanent |
| `TomMessageRouter` | class | Maps a channel to its transport |
| `TomMemoryMessageTransport` | class | Captures messages in memory; the test stand-in |
| `TomNoOpMessageTransport` | class | Accepts and discards; the local-run stand-in |
| `TomFileMessageTransport` | class | Writes each message to a `.eml` file |
| `TomSmtpTransport` / `TomSmtpSettings` / `TomSmtpSecurity` | classes / enum | Real delivery over SMTP |
| `TomSmtpConnection` / `TomSocketSmtpConnection` / `TomSmtpReply` | abstract class / classes | The wire, behind an interface so the protocol is testable |
| `TomSmsTransport` / `TomSmsGatewaySettings` / `TomSmsAuthScheme` | classes / enum | Real delivery over an HTTP SMS gateway |
| `TomSmsGatewayProtocol` / `TomFieldMappedSmsProtocol` | abstract class / class | The vendor mapping: field names in, status and error codes out |
| `TomSmsSubmission` / `TomSmsGatewayRequest` / `TomSmsGatewayAnswer` / `TomSmsBodyFormat` | classes / enum | The values a protocol maps between, so `encode` and `decode` stay pure |
| `TomSmsSegmentation` / `TomSmsEncoding` | class / enum | GSM 03.38 length arithmetic: the unit an SMS is actually billed in |
| `TomMimeEncoder` | class | Renders a `TomMessage` as an RFC 5322 / MIME document |
| `TomMessageOutbox` | class | The durable send queue in front of a router |
| `TomTemplatedMessageService` | abstract class | The rule every channel shares: a message is a template key plus parameters |
| `TomEmailRequest` | class | What to send and to whom: a template key and parameters, never a subject or body |
| `TomEmailService` | class | Renders a template in the recipient's locale and queues it on the outbox |
| `TomSmsRequest` / `TomSmsService` | classes | The same, for SMS — plus the segment budget email does not have |
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

- **Two factories, one type.** `TomMessage.email` is shown above;
  [`TomMessage.sms`](#composing-one) composes the other channel. They differ in
  what they *accept* — a subject and two bodies against one text and a sender id
  — and not at all in what they produce, which is why one transport contract and
  one outbox carry both.
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
   return `TomPermanentDeliveryException` and `TomTransientDeliveryException`
   respectively, so the classification is visible in the type and `on ... catch`
   reads the same on both sides.
2. **A permanent failure mixes in the kernel's `TomPermanentFailure`**, which
   `TomScheduler` already honours. The judgement is made once, at the point
   where the evidence is, and nothing downstream re-derives it.
3. **`isPermanent` reads that marker rather than storing the answer beside it.**
   This is what makes the first two points a guarantee instead of a convention.
   While the flag was a separate constructor parameter, a failure could describe
   itself as permanent and carry no marker — its `toString` said `(permanent)`
   and the scheduler retried it forever. `TomDeliveryException` is abstract and
   takes no classification argument, so mixing in `TomPermanentFailure` is now
   the only way to be permanent, and there is nothing left to contradict.

A transport that needs to carry vendor-specific data may subclass
`TomDeliveryException` directly; mixing in `TomPermanentFailure` is what makes
such a subclass permanent. Because retryability is the *absence* of the marker
rather than membership of one class, code deciding whether to retry should ask
`isPermanent` rather than test for `TomTransientDeliveryException`.

The default is *transient*. An unrecognised error is retried, because retrying a
permanent failure costs a few wasted attempts whereas dropping a transient one
loses the message.

## The Transport Contract

```dart
abstract class TomMessageTransport {
  TomMessageChannel get channel;
  Future<TomDeliveryReceipt> send(TomMessage message);

  bool get supportsCopies => false;        // Cc / Bcc
  bool get supportsAttachments => false;
  Future<void> close() async {}
  void checkSupported(TomMessage message) { … }
}
```

A bare declaration above is abstract — a transport must supply it. A member
shown with a body is inherited working, and only the first two are bare: a
transport declares its channel and sends. Everything else has an answer already.

The two `supports…` defaults are `false` on purpose. A transport that has not
thought about attachments is a transport that cannot carry them, and the safe
answer is the one that makes `checkSupported` refuse rather than the one that
lets a message through untested.

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
- **`QUIT` and `close` are best-effort, but not silent.** A failure while
  hanging up does not undo a delivery the server already accepted — reporting
  one would produce a *duplicate* on the retry — so it is written to the debug
  log with the stage that produced it (`QUIT after delivery`, `connection
  close`, `socket teardown`) rather than raised. The close is best-effort for
  *any* `TomSmtpConnection`, not only the socket one: `send` hangs up in a
  `finally`, where an exception would replace whatever the conversation
  produced. A relay that consistently errors on `QUIT`, or a TLS socket that
  never shuts down cleanly, is otherwise invisible short of a packet capture.

The protocol runs against the `TomSmtpConnection` interface, and the transport
takes an injectable `connect` function. That is how `test/messaging_test.dart`
asserts the branches that matter most — a relay that does not offer STARTTLS, a
rejected credential, one dead address, a `4xx` deferral — which are precisely
the ones a real relay will not produce on demand.

## SMS: One Gateway Shape, No Vendor Names

`TomSmsTransport` is the second implementation of `TomMessageTransport`, and
writing it was the first real test of whether that contract was channel-agnostic
or merely email-shaped. **It held.** Nothing in `TomMessage`,
`TomDeliveryReceipt` or `TomMessageTransport` had to change:

| What SMS needed | What was already there |
| --- | --- |
| a phone number instead of an address | `TomRecipient.address`, documented from the start as "for SMS it is a phone number" |
| a sender that is an id, not an addressee | `TomMessage.metadata`, whose documented example was "an SMS sender id" |
| one text body, no MIME | `TomMessageBody.text` and `TomMessage.textBody` |
| no copies, no attachments | `supportsCopies` / `supportsAttachments` already default to `false`, and `checkSupported` already refuses both permanently |

There is no `TomSmsConnection` interface as there is for SMTP, because SMS has
no protocol — every gateway is an HTTP API of its own invention. The transport
speaks HTTP through the kernel's `TomServerChannel` / `TomServerCall` layer and
puts the vendor's vocabulary behind a `TomSmsGatewayProtocol`.

One HTTP request per recipient. A gateway that accepts a list of numbers would
save requests and cost the receipt its per-number outcome, and partial delivery
is precisely the case that matters — one dead number must not cost the others
their message, exactly as a refused `RCPT TO` does not over SMTP.

### Composing one

`TomMessage.sms` is the entry point for the whole SMS composition path —
`TomSmsService.render` builds every application SMS through it, and a caller
sending one directly uses the same factory:

```dart
final message = TomMessage.sms(
  to: [TomRecipient('+441234567890')],
  text: 'Your code is 402913. It expires in 5m.',
  senderId: 'ACME',
);
```

It takes no `subject`, no `html` and no `attachments`, because none of them
survive the trip: the factory composes exactly one text body, which is what
`TomSmsTransport` reads through `textBody`. Offering the fields and dropping
them later would put the discovery at delivery time, in another isolate, long
after the caller who supplied them has gone.

`senderId` is a parameter rather than a `from` recipient, and lands in
`metadata` — the row above is the whole reason. A short code is not an
addressee: nobody replies to one, so modelling it as a `TomRecipient` would
offer a `displayName` and a `TomRecipientKind` that mean nothing on this
channel. An empty or omitted `senderId` adds no entry at all, so a gateway
protocol that maps the key sees its absence rather than a blank.

### Segments, not characters

An SMS is billed per *segment*, and `text.length` is the wrong number in three
separate ways. `TomSmsSegmentation.of(text)` computes the right one:

| Rule | Effect |
| --- | --- |
| one character outside GSM 03.38 moves the **whole message** to UCS-2 | capacity drops from 160 to 70 |
| ten GSM characters — `^ { } \ [ ~ ] |`, form feed and `€` — live in an escape table | they cost **two** units each |
| a message that does not fit one part spends seven bits per part on a concatenation header | capacity drops to 153 (GSM) or 67 (UCS-2) *per part* |

The third rule is the counter-intuitive one: the 161st character does not add
one character to a second segment, it adds *eight* — the message is repacked
into 153-unit parts. And because a character never straddles a boundary, the
packing is a greedy walk rather than a division.

This is why a `{firstname}` that arrives as `Zoë` can triple the cost of every
message a template sends, and why nothing in a green test run would say so.

### Two layers of classification

The transport's one job is deciding whether a failure is worth repeating, and
SMS makes that harder than SMTP because a gateway answers on two levels that
routinely disagree — an HTTP `200 OK` carrying `{"status":"failed","code":21211}`
is an accepted *request* and a refused *message*.

| Layer | Owner | Rule |
| --- | --- | --- |
| HTTP status | `TomSmsTransport.isTransientStatus` | `408`, `425`, `429` and `5xx` are transient; every other non-`2xx` is permanent |
| provider payload | the deployment's `TomSmsGatewayProtocol` | named codes are classified explicitly; an unrecognised code returns `null` and defers to the layer above |

`TomSmsGatewayAnswer.isPermanent` is deliberately **three-valued**. A protocol
forced to choose for an unknown code would either guess *permanent* and turn a
rate limit into a lost message, or guess *transient* and spend the retry budget
on an invalid number.

Two more decisions worth knowing:

- **A transient answer stops the pass** rather than continuing down the
  recipient list. A rate limit or an outage applies to the account, not to one
  number; continuing would burn the remaining recipients on the same refusal,
  and the retry would then deliver twice to the ones that had already gone.
- **Over the segment cap is permanent, and never reaches the gateway.** The
  text will not be shorter on a retry, and the alternative — send it anyway —
  is a bill.

### Describing a gateway

`TomFieldMappedSmsProtocol` describes a gateway in configuration rather than in
a subclass: which fields carry the number, the sender and the text; whether the
body is form-encoded or JSON; where in the response the status, the id and the
error code live; and which error codes are final.

```dart
final settings = TomSmsGatewaySettings.fromConfiguration(config); // null ⇒ no SMS
router.register(settings == null
    ? const TomNoOpMessageTransport(channel: TomMessageChannel.sms)
    : TomSmsTransport(
        settings,
        const TomFieldMappedSmsProtocol(
          format: TomSmsBodyFormat.form,
          toField: 'To',
          fromField: 'From',
          textField: 'Body',
          requiresSender: true,
          statusPath: 'status',
          acceptedStatuses: {'queued', 'accepted', 'sending', 'sent'},
          remoteIdPath: 'sid',
          errorCodePath: 'code',
          errorMessagePath: 'message',
          permanentErrorCodes: {'21211', '21610', '21614'},
          transientErrorCodes: {'20429', '30001'},
        ),
      ));
```

**No vendor presets ship.** There is no `TomTwilioProtocol`, no
`TomVonageProtocol`. A preset for an API this repository cannot test against is
a plausible-looking guess, and when it fails the failure is attributed to the
framework rather than to the guess. The mapping above is where a deployment
records what it verified against its own account.

The transport takes an injectable `openChannel`, the seam `TomSmtpTransport`
provides with `connect`. That is how `test/sms_transport_test.dart` asserts a
`429`, a `401`, a provider failure code on a `200`, a socket failure, a gateway
that never answers, and one dead number among three — none of which a real
gateway produces on demand.

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

The SMS gateway follows the same shape:

| Setting | Default | Meaning |
| ------- | ------- | ------- |
| `smsEndpoint` | *unset* | Unset means **this deployment sends no SMS**; must be `http` or `https` |
| `smsApiKey` | *unset* | The gateway credential; **secret-bearing** |
| `smsApiSecret` | *unset* | The second half of a pair; **secret-bearing**, required only by `basic` |
| `smsSenderId` | *unset* | The default sender shown on the handset |
| `smsAuthScheme` | `bearer` | `none` \| `bearer` \| `basic`; an unrecognised value falls back here |
| `smsTimeoutSeconds` | `30` | A timeout is **transient** — the message may well have been accepted |
| `smsMaxSegments` | `3` | The deployment's segment cap; `0` disables it |

The credential is never presented to the gateway by accident and never carried
to it from elsewhere: `TomServerCallSpecs.includeBearerAuthentication` is set to
`false` on every gateway call, because the kernel call layer would otherwise
inject the *caller's* bearer token — handing a user credential to a third party.
`TomSmsGatewaySettings.toString()` never includes `smsApiKey` or `smsApiSecret`.

`smsAuthScheme` also falls back rather than failing, but the direction is
different from `smtpSecurity`'s: it lands on `bearer` rather than `none`, so an
unrecognised value cannot silently drop the credential and send unauthenticated
requests to a paid API. The worst outcome is a `401`.

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

`tick()` is a *completed* pass: it returns once every message it picked up has
been through a transport and its outcome has been recorded — delivered,
scheduled for retry, or failed for good. (It does not mean the queue is empty; a
pass claims at most `maxRunsPerTick` messages, so a backlog takes several.) That
is what makes `await outbox.tick(); expect(transport.count, 1)` true on the very
next line, and what lets a shutdown path empty the queue before it closes. It
costs nothing at run time: the scheduler's own pass still *starts* its runs and
returns, so one slow relay handshake never holds up the next window — the outbox
composes `TomScheduler.tick()` with `TomScheduler.drain()` to get both
properties at once.

`outbox.close()` stops delivery and releases the scheduler, and leaves the
router open: a router shared with the rest of the application must not be torn
down because the outbox stopped.

## Application Email: A Template Key, Not a Body

Everything above answers "send these bytes to this address". `TomEmailService`
answers "send *the password-reset mail* to this user, in their language".

Without that second layer, every caller composes its own subject and body —
which puts user-facing text into Dart string literals, in direct violation of
the rule the rest of the framework keeps, and makes each caller re-derive
recipient formatting, sender identity and the locale to render in. The transport
being good makes this worse rather than better: it is attractive enough to call
directly, and every direct call site is a place the rule is quietly broken.

So `TomEmailRequest` has **no subject and no body field**. It names a template
and supplies values:

```dart
final emailService = TomEmailService(outbox: outbox, texts: texts);
TomBean.withType(TomEmailService, emailService);

await emailService.send(TomEmailRequest.toPrincipal(
  templateKey: 'email.password_reset',
  principal: principal,
  parameters: {'firstname': principal.user.firstname, 'link': resetUrl},
  messageId: 'reset-$resetToken',
));
```

There is no way to spell a literal subject through this API, which is the point:
a rule the type system enforces needs no reviewer to remember it.

### The three sub-keys

A template key resolves three resources:

| Sub-key | Required | Becomes |
| ------- | -------- | ------- |
| `.subject` | yes | the subject line |
| `.text` | yes | the `text/plain` body |
| `.html` | no | the `text/html` alternative |

```yaml
email:
  password_reset:
    subject: "Reset your password, {firstname}"
    text: "Open {link} to choose a new password."
    html: "<p>Open <a href=\"{link}\">this link</a>.</p>"
```

The asymmetry is deliberate. Not every mail has markup, so a missing `.html` is
an ordinary template rather than a fault. But a mail with *no plain-text part* is
a deliverability problem — spam filters score it down and text-only clients
render nothing — so `.text` is required rather than merely preferred. When both
are present the bodies are ordered plain-text first, HTML last, and
`TomMimeEncoder` builds the `multipart/alternative` part from them.

### Locale comes from the recipient, not the process

Templates resolve through `TomLocalizedTextResources` (see `doc/resources.md`),
which holds one bundle per locale and picks by argument rather than by installed
singleton — because a server is answering a German user and an English one in the
same event loop. `TomEmailRequest.toPrincipal` derives the locale from the
principal's stored language, falling back to the device's and then to the bundle
set's default.

### Sentences a mail includes only sometimes

A digest that mentions an overdue count *when there is one* cannot express that
in a single template. Rather than reintroducing conditionals into the resource
format — which is how a template engine starts — the optional sentence is a
resource key of its own, resolved separately and passed in as a parameter:

```yaml
email:
  ops_digest:
    text: |
      You have {openCount} open item(s).
      {overdueLine}
    overdue_line: |
      {overdueCount} of them are past their due date.
```

```dart
parameters: {
  'openCount': summary.openCount,
  'overdueLine': summary.overdueCount == 0
      ? ''
      : emailService.requiredText(
          'email.ops_digest', 'overdue_line',
          locale: locale,
          parameters: {'overdueCount': summary.overdueCount},
        ),
},
```

`requiredText` rather than `TomLocalizedTextResources.textOrNull` so a fragment
nobody wrote fails the send exactly as a missing subject does — one failure mode
for one class of fault, instead of the optional sentence being the one part of a
mail that can silently render empty.

Resolve fragments **fully**, with their own parameters, before passing them in.
Substitution is a single pass over the parameter map, so a fragment inserted with
`{overdueCount}` still in it would be substituted or not depending on map order.

`advanced_ops_server`'s morning digest is the worked example
(`jobs/digest_service.dart`, `assets/text_en.yaml`, `assets/text_de.yaml`).

### A missing key fails before anything is queued

`render` raises `TomMessagingException` when `.subject` or `.text` does not
resolve, and `send` calls `render` before touching the outbox. So a template
nobody wrote produces an error the *caller* sees, not a queued mail with an empty
subject that a *recipient* sees.

This is the one place the framework departs from
`TomTextResourceProvider.getText`'s key-as-fallback. A button reading
`two_factor.enrol.submit` is ugly, unmistakable, and gets fixed; a subject line
reading `email.password_reset.subject` has already been read by the user by the
time anyone notices.

### Always through the outbox

`send` hands the rendered message to a `TomMessageOutbox`, never to a transport.
Retry, backoff, permanence classification, one-delivery-per-message and failure
alerting already exist there, correctly, on the kernel's job scheduler. A service
that reached past it would either lose mail on a transient relay failure or grow
a second retry mechanism beside the working one.

`TomEmailRequest.messageId` is the outbox's idempotence key: two sends of a
request carrying the same id are one queued message. Supply one for anything a
caller might retry without knowing whether the first attempt landed — a reset
keyed by its token, an invoice keyed by its number.

## Application SMS: The Same Rule, Plus a Length

`TomSmsService` is to SMS what `TomEmailService` is to mail, and deliberately so:
`TomSmsRequest` has **no text field**, for the same reason `TomEmailRequest` has
no subject field. A request type that cannot express a literal is a resource rule
the compiler enforces rather than one a reviewer has to remember.

One sub-key instead of three. An SMS has a body and nothing else, so
`<templateKey>.text` is the whole template — no subject to omit, no HTML
alternative to offer.

```dart
await smsService.send(TomSmsRequest.toPrincipal(
  templateKey: 'sms.two_factor',
  principal: principal,
  parameters: {'code': code, 'minutes': 5},
  messageId: 'two-factor-$challengeId',
));
```

```yaml
sms:
  two_factor:
    text: "Your code is {code}. It expires in {minutes}m."
```

What `render` hands back is a plain
[`TomMessage.sms`](#composing-one) — the resolved text, the request's
recipients, and `TomSmsRequest.from` as the sender id. Past that point a
templated SMS and a hand-composed one are indistinguishable, so the outbox, the
transport and the receipt need to know nothing about templates.

### The shared base

`TomEmailService` and `TomSmsService` both extend
`TomTemplatedMessageService<R>`, which owns `send`, `sendNow` and
`requiredText`; a subclass supplies only `channelName` and `render`. So the two
services are not merely alike — the shared parts are the same code.

That matters because the repeated parts *are* the rule: resolve through resource
keys, fail loudly before anything is queued, hand the result to the outbox rather
than to a transport. A convention re-implemented per channel drifts invisibly — a
third channel resolving through `TomLocalizedTextResources.textOrNull` instead of
`requiredText` would silently gain the key-as-fallback behaviour messaging
deliberately does not want.

`channelName` exists so a missing SMS template raises
`messaging.sms.template.missing` rather than reporting itself as an email fault
and sending whoever is on call to the wrong bundle.

The conditional-fragment technique described under
[Sentences a mail includes only sometimes](#sentences-a-mail-includes-only-sometimes)
is inherited rather than reimplemented, and the single-pass substitution caveat
applies unchanged.

### Two caps, deliberately

| Cap | Where | Applies to |
| --- | --- | --- |
| `TomSmsGatewaySettings.maxSegments` | deployment configuration (`smsMaxSegments`, default `3`) | every message reaching the transport, including ones composed elsewhere |
| `TomSmsService.maxSegments` | the service, `null` by default | messages this application composes |

The service cap is `null` rather than a number because two defaults that
disagree produce a message refused by whichever is stricter and reported by
whichever the operator did not set. An application sets it when its own traffic
warrants something tighter — a two-factor code has no business being two
segments long, whatever the deployment permits in general.

`TomSmsService.segmentationOf(request)` renders and measures without sending or
capping, for a preview screen or a test that wants to assert what a template
costs. It deliberately does not throw: a measurement used to *decide* whether a
message is too long cannot be one that raises when it is.

### Addressing a principal

`TomSmsRequest.toPrincipal` prefers `TomUser.mobile` and falls back to
`TomUser.phone`. The fallback earns its place — many directories hold one number
in whichever field the import happened to fill — and so does the ordering: a
landline that silently swallows a two-factor code is a support call nobody can
diagnose.

A principal reachable by neither raises at composition, where the caller still
knows *which user* it was reaching. A transport discovering it later can only
report that a number was empty.

## Verification

Four suites cover the module, split along the same seam this document is: the
substrate below the services, and the templated layer above it.

`test/messaging_test.dart` covers the substrate — the message shape and its
JSON round-trip, the MIME document, the router, the three stand-in transports,
the SMTP line protocol under each security mode, the transient/permanent
classification described in
[The One Distinction a Transport Must Get Right](#the-one-distinction-a-transport-must-get-right),
and the outbox's queueing and retry. `test/sms_transport_test.dart` covers the
gateway: the field mapping, the two layers of classification, and each branch a
real gateway would need a bad number or a rate limit to produce.
`test/email_service_test.dart` and `test/sms_service_test.dart` cover the
templated services — sub-key resolution, the locale a request selects, the
failure that fires before anything is queued, and the segment budget. What that
locale then *resolves* against is the resources module's rule, pinned in
`test/resources_test.dart`; both suites render against the same fixture.

Two examples run the module end to end, one per layer.

`example/messaging/messaging_example.dart` is the substrate, in twelve numbered
steps: composing a message and reading its channel; registering a channel the
enum never named; the envelope's three recipient kinds; the
`multipart/alternative` document a text-plus-HTML message produces; capture by
the memory transport; the no-op transport's `discarded` outcome; routing by
channel; the permanence marker deciding whether the scheduler gives up;
`send` returning before delivery; two sends sharing one run; the file
transport's output; and settings resolved from configuration.

`example/messaging/messaging_templated_example.dart` is the layer above it,
also in twelve steps: a request that carries a template key rather than a body;
the three sub-keys of an email; the same key rendered in `de`, and a key the
`de` bundle lacks falling back rather than rendering blank; a missing sub-key
naming the exact resource key it wanted; `toPrincipal` deriving address,
display name and locale; the single sub-key an SMS has; one accented character
moving a message from GSM-7 to UCS-2 and halving the room in a segment; the
service cap refusing an over-long message at render; both services queueing on
one outbox; one tick delivering both; a gateway accepting a submission and its
id arriving back on the receipt; and one dead number among two being a partial
delivery rather than a failure, with a rate limit thrown for retry instead.

```bash
dart run example/messaging/messaging_example.dart
dart run example/messaging/messaging_templated_example.dart
```

`test/messaging_test.dart` runs both under precisely those commands and requires
each to exit 0 having printed all twelve of its steps, so the transcripts in the
files are what the module currently does rather than what it did when they were
written. Their expectations are written through the shared
`example/_support/check.dart`, which throws rather than asserting — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why, and for the suite that holds that line across every example. A second
test per example requires these two in particular to keep using it.

Neither example opens a socket. The templated one drives a real
`TomSmsTransport` through the injectable channel described in
[Describing a gateway](#describing-a-gateway), against a client whose answers
are scripted — which is the only way steps 11 and 12 can show an
invalid-number rejection and a rate limit at all, since a real gateway will not
produce either on demand.

## Core Components

- **`TomMessage` / `TomRecipient` / `TomRecipientKind` / `TomMessageBody` /
  `TomAttachment` / `TomMessageChannel`** — the composed message and its JSON
  round-trip.
- **`TomMessageTransport` / `TomDeliveryReceipt` / `TomDeliveryOutcome` /
  `TomDeliveryException` / `TomPermanentDeliveryException` /
  `TomTransientDeliveryException`** — the delivery contract and its classified
  failures.
- **`TomMessageRouter`** — channel → transport.
- **`TomMemoryMessageTransport` / `TomNoOpMessageTransport` /
  `TomFileMessageTransport`** — delivery without a network.
- **`TomSmtpTransport` / `TomSmtpSettings` / `TomSmtpSecurity` /
  `TomSmtpConnection` / `TomSocketSmtpConnection` / `TomSmtpReply`** — real
  delivery, with the wire behind an interface.
- **`TomSmsTransport` / `TomSmsGatewaySettings` / `TomSmsAuthScheme`** — real
  delivery over an HTTP gateway, with the connection behind an injectable seam.
- **`TomSmsGatewayProtocol` / `TomFieldMappedSmsProtocol` / `TomSmsSubmission` /
  `TomSmsGatewayRequest` / `TomSmsGatewayAnswer` / `TomSmsBodyFormat`** — the
  vendor mapping, and the values it maps between.
- **`TomSmsSegmentation` / `TomSmsEncoding`** — GSM 03.38 length arithmetic.
- **`TomMimeEncoder`** — the RFC 5322 / MIME document.
- **`TomMessageOutbox` / `tomOutboxJobName`** — the durable send queue.
- **`TomTemplatedMessageService`** — the template-key rule every channel shares.
- **`TomEmailRequest` / `TomEmailService`** — resource-keyed application email,
  rendered in the recipient's locale and queued on the outbox.
- **`TomSmsRequest` / `TomSmsService`** — the same for SMS, plus the segment
  budget.
- **`TomMessagingException`** — the module's base error.

## Not Yet Implemented

- **Transports for the remaining channels.** `push` and `webhook` are named
  constants with no implementation; the contract is what they will implement,
  and a `TomNoOpMessageTransport` registered on those channels makes a spec that
  names them runnable in the meantime. `email` and `sms` are implemented, and
  the second one is the evidence that the contract carries a channel it was not
  designed around.
- **Delivery reports.** `TomDeliveryReceipt.remoteId` carries the gateway's id
  precisely so an asynchronous status callback can be correlated with the
  message that produced it, but nothing here consumes one. An SMS accepted by a
  gateway is not an SMS that reached a handset, and this module currently knows
  only the former.
- **Vendor protocol presets.** `TomFieldMappedSmsProtocol` can express the
  common gateways, but no per-vendor preset ships — see
  [Describing a gateway](#describing-a-gateway) for why.
- **The notification model.** Channels, notification types, per-user
  preferences and subscription resolution are a separate concern, deliberately
  not designed here.
- **Inbound mail.** This module sends only.
- **Templating for the remaining channels.** `TomEmailService` and
  `TomSmsService` cover their channels; `push` and `webhook` have no equivalent
  yet. Each will extend `TomTemplatedMessageService` with its own sub-key set
  rather than generalising either existing one.
- **Markup in templates.** A template resolves to a string. Conditionals, loops
  and partials are not offered: a template that needs one renders the varying
  part in the caller — as its own resource key, through `requiredText` — and
  passes it in as a parameter. See
  [Sentences a mail includes only sometimes](#sentences-a-mail-includes-only-sometimes).
- **DKIM signing**, and other outbound authentication beyond what the relay
  itself performs.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `message_transport.dart`, `outbox.dart`, `sms_transport.dart`, `smtp_transport.dart` | `Future`, `Stream`, `StreamController`, `unawaited` |
| `dart:convert` | dart | `message.dart`, `mime_encoder.dart`, `sms_transport.dart`, `smtp_transport.dart` | `Encoding`, `LineSplitter`, `base64`, `json`, `jsonDecode`, `jsonEncode` |
| `dart:io` | dart | `message_transport.dart`, `smtp_transport.dart` | `Socket` / `SecureSocket` |
| `dart:math` | dart | `mime_encoder.dart` | `Random`, `min` |
| `dart:typed_data` | dart | `message.dart` | `Uint8List` |
| `async` | package | `smtp_transport.dart` | `StreamQueue` drives the SMTP line protocol |
| `path` | package | `message_transport.dart` | file naming in `TomFileMessageTransport` |
| `tom_core_kernel` | package | `email_service.dart`, `message_transport.dart`, `outbox.dart`, `sms_service.dart`, `sms_transport.dart`, `smtp_transport.dart` | `TomScheduler`, `TomJobStore`, `TomJobDefinition`, `TomRetryPolicy`, `TomJobAlertSink`, `TomPermanentFailure`, `TomCommand`, `TomClosable`, `TomPrincipal`, `TomUser`, `TomBean`, `tomLog`, and `TomServerChannel` / `TomServerCall` / `TomServerCallSpecs` — the HTTP call layer `TomSmsTransport` reaches its gateway through, rather than a raw client |
| `uuid` | package | `message.dart` | `UuidV4`, for a message id when the caller supplies none |
| [configuration](configuration.md) | module | `sms_transport.dart`, `smtp_transport.dart` | `TomBaseServerConfiguration` |
| [little_things](little_things.md) | module | `message.dart` | `TomServerException` |
| [resources](resources.md) | module | `email_service.dart`, `sms_service.dart`, `templated_message_service.dart` | `TomLocalizedTextResources` and `TomTextLocale`, which `TomTemplatedMessageService` resolves every template through (see `doc/resources.md`) |
