# Security Module

The client half of the framework's second-factor design: a ready-made
enrol-and-challenge flow, a seam onto the application's own auth client, a
registry of pluggable per-mechanism panels, and the shipped TOTP mechanism. It
also holds the code-scanner contract: the interface an application implements
over its own camera plugin to read QR codes and barcodes.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [The Flow and Its Three Stops](#the-flow-and-its-three-stops)
- [The Controller Seam](#the-controller-seam)
- [Mechanisms and the Registry](#mechanisms-and-the-registry)
- [When an Offer or a Challenge Has Lapsed](#when-an-offer-or-a-challenge-has-lapsed)
- [What the Framework Ships](#what-the-framework-ships)
- [The Shipped TOTP Mechanism](#the-shipped-totp-mechanism)
- [The Shipped Passkey Mechanism](#the-shipped-passkey-mechanism)
- [Text Resources](#text-resources)
- [The QR View](#the-qr-view)
- [The Code Scanner](#the-code-scanner)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `Tom2FAFlowPanel` | class | Renders whichever stop of the second-factor login the controller reports |
| `Tom2FAFlowController` | abstract class | The seam an application implements over its own auth client — five moves, two pieces of state |
| `Tom2FAClientMechanism` | abstract class | One mechanism's client-side rendering, registered under its mechanism key |
| `Tom2FAClientRegistry` | class | The mechanism catalog the flow dispatches through; entirely static |
| `Tom2FAEnrolmentPanelContext` | class | What an enrolment panel is given to render itself |
| `Tom2FAChallengePanelContext` | class | What a challenge panel is given to render itself |
| `TomTotp2FAClientMechanism` | class | The shipped authenticator-app mechanism, registered under `'totp'` |
| `TomWebAuthn2FAClientMechanism` | class | The shipped passkey mechanism, registered under `'webauthn'` where a platform authenticator exists |
| `TomWebAuthnPlatform` / `TomUnavailableWebAuthnPlatform` / `TomWebAuthnPlatformException` | abstract class / class / class | The seam to whatever makes passkeys on this target: the browser on the web, nothing elsewhere unless the application supplies a plugin |
| `Tom2FATexts` | class | Every resource key this feature resolves, and the one helper that resolves them — all static |
| `TomQrCodeView` | class | A QR code painted from the pure-Dart `qr` encoder, re-encoded only when its payload changes |
| `TomCodeScanner` | abstract class | The contract for reading codes with the device camera; an application implements it over the camera plugin it chooses |
| `TomFakeCodeScanner` | class | The test double: a scanner that delivers the codes and failures a test tells it to |
| `TomScannedCode` | class | One decoded code — payload, format, raw bytes, the time it was read |
| `TomCodeFormat` | enum | The symbologies a scan can ask for |
| `TomCodeScannerAvailability` | enum | Whether a scanner can read codes here, and if not, why |
| `TomCodeScannerException` | class | Why a scan could not start, keyed `code_scanner.*` |

**Two client mechanisms ship: TOTP everywhere, and passkeys where the target
has a platform authenticator** — on the web, through the browser. The server
ships four adaptors — `totp`, `webauthn`, and the delivered-code `email` and
`sms` — so for those last two the missing half is this one: the registration
example is `SmsClientMechanism()`, and the `hint` field's illustration is the
masked phone number the server's SMS adaptor already sends. See
[What the Framework Ships](#what-the-framework-ships).

The division of labour is the point of the module. Everything about a
second-factor login that is the *same* whichever mechanism is in play — the
chooser, the frame, the attempt counter, the error line, the skip affordance —
belongs to the framework. What a mechanism *shows* and what counts as an
*answer* varies, and lives behind `Tom2FAClientMechanism`. The token
choreography belongs to neither: the flow calls the application's controller,
whose auth client already runs its calls through the framework's refresh
machinery.

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

if (session.needsSecondFactor) {
  return Tom2FAFlowPanel(controller: MyFlowController(session));
}
```

That is the whole integration. The panel renders the stop the login is at,
reading it from the controller on every build — so an application drives it by
rebuilding (its session is typically already a `ChangeNotifier`) rather than by
calling into it. TOTP is registered by the panel itself on first build, so the
common case needs no set-up.

## The Flow and Its Three Stops

`Tom2FAFlowPanel` reads the controller each build and renders one of three
stops, in a fixed precedence:

| Stop | Rendered when | What it shows |
| ---- | ------------- | ------------- |
| **Challenge** | `pendingChallenge != null` | The chosen mechanism's challenge panel, plus the attempt budget |
| **Enrolment** | an enrolment is pending *and* carries an offer | The chosen mechanism's enrolment panel, plus the budget when one applies |
| **Chooser** | an enrolment is pending with no offer yet | One tile per mechanism the server offered *and* this build can render |

**A challenge outranks an enrolment.** A principal who both holds a factor and
owes a new one must prove the one they have before setting up another —
otherwise enrolment would be a way around the factor it is meant to strengthen.

**The chooser lists only renderable mechanisms.** A server upgraded ahead of
its clients offers keys the build has no panel for; listing one would strand
the user on a blank step they cannot back out of. When *nothing* offered is
renderable, the stop says so rather than showing an empty list.

**A challenge for an unrenderable mechanism has nothing to filter.** The chooser
can drop what it cannot render and offer the rest; the challenge stop is holding
one outstanding challenge, of one type, with no alternative to switch to. It is
the same deployment state — a principal who enrolled through a newer client,
signing back in from an older build — and it is not recoverable on this side.

The flow says so in its own words rather than borrowing the chooser's. "This app
cannot set any of these up" is written about enrolment, and a user being
*challenged* is not setting anything up; the challenge stop resolves
`unrenderableChallenge` instead, under its own key
`tom-2fa-unrenderable-challenge`. No attempt budget is printed beside it, because
no attempt can be spent, and the skip affordance is absent because skipping is
enrolment-only by construction. Cancel is the one exit, and the framework does
not pretend there is another: recovering this needs a newer build, which is what
the message says.

**Each chooser tile renders all three of the descriptor's keys** — label,
description and icon. The icon resolves in two steps, the convention
`tom_flutter_ui` uses throughout: `iconKey` resolves through the text bundle to
an icon *name* (`mSecurity`), and the application's `TomUIIcons` adapter maps
that name to something drawable. A mechanism that wants an icon therefore ships
a bundle entry rather than an asset, which is what lets one descriptor serve a
Flutter client and a web one without knowing which is asking.

Only the label and the description are load-bearing. A bundle with no icon
entry, an application that installs no adapter, or an adapter that does not
carry that icon all render the row without a leading icon and lose nothing
else. This is also why a missing icon key cannot leak the way missing text
does: an unknown key resolves to the key itself, which is deliberately
conspicuous on a label, but `two_factor.sms.icon` is not an icon name, so it
resolves to nothing and shows nothing.

**The skip affordance appears only when the server said declining is
permitted**, and never because the client thinks it should be on offer — that
would put the policy decision on the side of the wire that does not get to make
it. When declining costs a grace login, the panel says that too.

Every stop shares one frame: title, body, error line, the skip exit when
permitted, and cancel. The panel owns the busy flag and the error line for all
of them, so no mechanism panel has to. When no enrolment and no challenge are
pending the panel renders nothing, so it is safe to leave mounted.

Widget keys are stable and public — `tom-2fa-chooser`, `tom-2fa-enrolment`,
`tom-2fa-challenge`, `tom-2fa-title`, `tom-2fa-error`, `tom-2fa-attempts`,
`tom-2fa-skip`, `tom-2fa-skip-cost`, `tom-2fa-cancel`, `tom-2fa-method-<type>`,
`tom-2fa-no-methods`, `tom-2fa-unrenderable-challenge`,
`tom-2fa-enrolment-expired`, `tom-2fa-challenge-expired`
— so an integration test can drive the flow without matching on text that a
resource bundle is free to change.

## The Controller Seam

The framework cannot call the enrolment endpoints itself: there is no
framework-wide auth API contract, because each deployment's auth service owns
its own DTOs. What *is* universal is the set of moves, so that is what the seam
is.

```dart
abstract class Tom2FAFlowController {
  Tom2FAPendingEnrolment? get pendingEnrolment;
  Tom2FAChallenge? get pendingChallenge;
  List<Tom2FAMethodDescriptor> get availableMethods; // defaults to const []
  String get accountLabel;                           // defaults to ''

  Future<void> chooseMethod(String type);
  Future<void> confirmEnrolment(String code);
  Future<void> skipEnrolment();
  Future<void> submitSecondFactor(String code);
  void cancel();

  String describeError(Object error);                // defaults to '$error'
}
```

Five moves and two pieces of read-only state, which an application implements
in a dozen lines over the auth client it already has. Two optional getters
supply the chooser's labels and the account name shown beside the QR code.

**Every method may throw.** The panel catches whatever comes back and renders
it through `describeError`, so an application surfaces its own typed failure
without the framework knowing the type. The default is the error's own
description — right for a typed exception whose `toString` is already a
message, wrong for anything else, hence the override point.

`skipEnrolment` is reachable only when the server marked the offer skippable,
so an implementation may treat an unexpected call as a programming error.

A worked implementation is in
[`example/security/security_example.dart`](../example/security/security_example.dart),
which walks one controller through all three stops — choosing a mechanism,
being refused, confirming, and answering a challenge on the next sign-in. It
also shows where the attempt budget lives: the *server* spends it and re-issues
the interim result, which is why `Tom2FAPendingEnrolment` exposes no method for
advancing its own counter while `Tom2FAChallenge` does.

## Mechanisms and the Registry

The server's 2FA design is deliberately open: an adaptor owns generating a
challenge, verifying an answer and beginning an enrolment, and the framework
passes an opaque `clientData` map through untouched precisely so a new
mechanism can ship without the framework learning about it. That contract is
only half kept if the *client* still has to grow an `if (type == 'sms')`
somewhere. So the client mirrors it.

```dart
abstract class Tom2FAClientMechanism {
  const Tom2FAClientMechanism(this.type);
  final String type;

  Widget buildEnrolmentPanel(BuildContext c, Tom2FAEnrolmentPanelContext data);
  Widget buildChallengePanel(BuildContext c, Tom2FAChallengePanelContext data);

  Tom2FAMethodDescriptor get descriptor; // defaults to the scoped convention
}
```

Pairing with the server is **by `type` alone** — neither side imports the other
— which is what lets a mechanism ship as a package that adds a server adaptor
and a client mechanism and touches no framework file.

The two context types carry what a panel needs and nothing more. Both are
values rather than positional parameter lists, so adding a field later does not
break every mechanism that ever shipped.

| Field | Enrolment | Challenge | Meaning |
| ----- | :-------: | :-------: | ------- |
| `type` | ✓ | ✓ | The mechanism key, so one class can serve several related mechanisms |
| `clientData` | ✓ | ✓ | The mechanism's own opaque payload |
| `onSubmit` | ✓ | ✓ | Called with whatever the user typed |
| `busy` | ✓ | ✓ | Whether the flow is mid-call; panels disable controls on this |
| `accountLabel` | ✓ | — | The account the factor is being set up for |
| `hint` | — | ✓ | A short displayable hint, e.g. a masked phone number |
| `attemptsRemaining` | — | ✓ | The budget the user is spending |

Two of those rows are worth a second look, because they are where the split
between what the *framework* guarantees and what a *mechanism* chooses is
sharpest.

`accountLabel` travels from the controller, through the flow, into the enrolment
context, and the shipped TOTP panel captions the QR code with it. A user with
three work accounts in one authenticator scans three visually identical codes;
without the caption they cannot tell which one they are adding until it is
already in the list. Supply nothing and the caption is **omitted rather than
blanked** — an empty caption is a gap that reads as a missing value instead of
an absent one.

`hint` takes the same path and **no shipped client mechanism renders it**.
TOTP has nothing to hint: the user reads the code off the device already in
their hand. The field earns its place with the delivered-code factors — the
server's `email` and `sms` adaptors fill it with the masked destination, and
"we sent it to ••••4417" is the difference between waiting and giving up on the
wrong phone. So the framework's
half of the contract here is **delivery, not display**: the flow hands on
whatever the server sent, as an empty string rather than null so a panel can
render it without a null check. `test/two_factor_client_test.dart` holds it to
that with a test-only SMS mechanism that reads the hint — otherwise the first
mechanism that needed it would be the one to discover it never arrived.

**No credential material reaches a panel.** A mechanism receives the decoded
`clientData` and nothing else about the login — no principal, no tokens, no
backend handle. It renders, validates locally if it can, and hands a string back
through `onSubmit`. Whether that string travels as a confirmation or a challenge
answer, and what happens to the token pair afterwards, is the flow's business.

### What the application may show a panel

That rule is about *credentials*, and it is worth separating from the question
it is often mistaken for. A device name beside a WebAuthn prompt, a tenant that
disambiguates an account, a brand — none is credential material, and the
framework has no objection to any of them in principle.

**They arrive as named fields on the context, supplied by the controller.**
`accountLabel` is the first and so far the only one. The next such need adds the
next named field, which is what the contexts being values rather than positional
parameters buys: a field added later breaks no mechanism that ever shipped.

Two shapes for the general case were considered and declined:

| Declined | Why |
| -------- | --- |
| An untyped `applicationData` map on both contexts | One change would cover every future case, at the cost of a bag whose contents no reader can discover from the type. There is already one opaque map on this path — the server's `clientData` — and a second, with different provenance, is how the two come to be confused about which end owns what |
| Routing it through the server | Putting an application's presentation data in `clientData` means putting it on the wire, and through an adaptor whose job is the factor rather than the UI |

**The challenge context carries no application-supplied field at all**, and that
is an absence of demand rather than a rule. A challenge screen naming the
account it is for would be as useful as an enrolment screen doing so, and adding
the field is one line in the context and one in the flow. It is not added on the
chance, because a field nobody asked for is a field nobody can say what belongs
in.

Both decisions are pinned: the suite asserts the exact field set of each
context, so adding a bag — or quietly giving the challenge context an
`accountLabel` — fails a test rather than passing as an implementation detail.

`Tom2FAClientRegistry` is the catalog the flow dispatches through, and
`register` is the only way into it. The module once had a second route — a
`TomClient2FAAdaptor` annotation, exported from the barrel and documented as
something a runtime could enumerate, which nothing enumerated — and it was
removed rather than relabelled: an unread annotation is not inert, because a
reader who finds one reasonably concludes that annotating a class does
something. Three assertions hold that: one insertion site into the catalog, no
reflection anywhere in the module's sources, and no generated mirrors for it in
`build.yaml`, which is what a scan would need.



| Member | Purpose |
| ------ | ------- |
| `register(mechanism)` | Registers under the mechanism's `type`, replacing any previous entry |
| `find(type)` | The registered mechanism, or `null` |
| `has(type)` | Whether one is registered |
| `types` | Every registered key |
| `reset()` | Drops every registration — `@visibleForTesting` |

It is process-wide rather than injected because it is consulted from inside
widget builds, several levels below whoever configured it; threading it down
would put a parameter on every panel for a value that is the same everywhere in
the process.

`find` is nullable rather than throwing because "the server offered a mechanism
this build cannot render" is a real deployment state, and the flow's answer is
to omit the entry, not to crash the login screen.

Registration **replaces** rather than rejects, which is how an application
substitutes its own TOTP panel:

```dart
// At start-up, before the first flow build. Both classes are the
// application's own — `SmsClientMechanism` is not shipped.
Tom2FAClientRegistry.register(SmsClientMechanism());
Tom2FAClientRegistry.register(MyOwnTotpPanel());
```

The flow installs a built-in only where nothing is registered under that key
(`Tom2FAFlowPanel.registerBuiltInMechanisms`, called from the panel's
`initState` and idempotent), so registering first wins.

### Register at start-up

Nothing bounds *when* `register` may be called, and nothing needs to for a
normal application: register before the first `Tom2FAFlowPanel` is built and the
question never arises. What is worth knowing is what happens if you do not,
because the registry is not sealed and will not complain.

The flow resolves the mechanism on **every build**, so a registration made while
a flow is on screen takes effect on the next frame. Whether the user notices
depends on what the replacement renders:

| The replacement renders | What happens |
| ----------------------- | ------------ |
| a **different** panel widget | it takes the screen over, and the state of the one it replaced — including the controller holding whatever was typed — goes with it |
| the **same** panel widget | nothing is lost: the element is reused and the typing survives |

The cost is therefore attached to the *shape* of a late replacement, not to
replacement itself. An application that wraps or subclasses the shipped panel
changes the mechanism object and keeps the widget type, which is the likelier
substitution and is free. Registering a differently-shaped panel during a live
flow is the one case that costs a user something, and no shipped path does it.

Sealing the registry after the first flow build was considered and declined: it
would forbid a legitimate late registration — a mechanism arriving from a plugin
loaded after the login screen is already up — to prevent a misuse nobody has
committed.

## When an Offer or a Challenge Has Lapsed

Both wire types carry a deadline and an `isExpired`, and the flow read neither.
A user who left the set-up screen open past the offer's validity scanned a QR
code that would not be accepted, typed a confirmation, and got a refusal from the
server — correct behaviour arriving as late as it possibly can.

The flow checks now, at the two stops where a deadline exists, and renders a line
above the panel:

| Stop | Key | Widget key |
| ---- | --- | ---------- |
| Enrolment (a mechanism chosen, its offer half-built) | `two_factor.error.enrolmentExpired` | `tom-2fa-enrolment-expired` |
| Challenge | `two_factor.error.challengeExpired` | `tom-2fa-challenge-expired` |

Two keys rather than one because the nouns differ — a set-up session and a
sign-in request — and a deployment writing a bundle wants to say so.

**The chooser never reports a lapse.** `Tom2FAPendingEnrolment.isExpired` answers
`false` while the user is still choosing, and the kernel gives the reason: there
is no generated material to go stale, so a chooser left open is a UX question
rather than a security one. The flow calls `isExpired` on that same type at two
stops and inherits the distinction rather than re-deriving it.

**A begun offer carrying no deadline reads as lapsed**, which is also the
kernel's reading and also inherited: it answers as the server would, and a panel
showing a live confirmation form for a state the server refuses is worse than one
saying the offer lapsed.

### It is a notice, not a refusal

The panel stays. The submit button stays. Whatever the user sends is judged by
the server, which is the authority on a deadline it issued.

That is the whole of the design and it follows from one measurement:
`expiresAt` is an **absolute instant** the server put in the token, and there is
no skew window anywhere on this path — `isExpired` is a strict comparison. So the
client's verdict is only as good as *this device's* clock. A flow that hid the
panel on its own verdict would lock a user whose clock runs ten minutes fast out
of a login the server was still perfectly willing to complete, and it would do so
silently, on every attempt.

Saying it and letting the authority answer costs nothing and cannot lock anyone
out. What it removes is the same thing the unrenderable-challenge line removes: a
refusal arriving with no explanation, after the user has done the work.

## What the Framework Ships

Two client mechanisms, both installed by the flow so an application gets them
without wiring:

| Mechanism | Registered | Pairs with |
| --------- | ---------- | ---------- |
| `TomTotp2FAClientMechanism` | always | `TomTotp2FAService` |
| `TomWebAuthn2FAClientMechanism` | where `TomWebAuthnPlatform.instance.isAvailable` — on the web, in a browser with `navigator.credentials` | `TomWebAuthn2FAService` |

Passkeys are the first mechanism that is not renderable on every target, and
the flow was built for exactly that: on a target with no authenticator the key
stays unregistered, so the enrolment chooser leaves passkeys out and a challenge
for one shows `two_factor.error.unrenderableChallenge` rather than a button that
can only fail. A native app that wants passkeys assigns its own
`TomWebAuthnPlatform.instance` over a platform plugin at start-up; the framework
does not pick one for every application.

The server ships two more. `tom_core_server` also registers `email` and `sms`,
which generate a code, deliver it through the deployment's `TomEmailService` or
`TomSmsService`, and are offered only once that service is installed. For those
two the half that is not here is the client's: a code field, a confirm step at
enrolment, and the server's masked destination shown as `hint`. A deployment
that offers SMS or email codes writes that mechanism and registers it; until it
does, the enrolment chooser leaves the key out, because it lists only what this
build can render.

The SMS panel is not shipped on purpose. SMS is the weakest of the common
factors — a SIM swap or an intercepted text defeats it — and the dearest to
run, since every challenge is a paid message. The server adaptor is inert until
a deployment installs an SMS service; registering the client mechanism is the
second, explicit step by which a deployment chooses to offer the factor, and
the framework does not take it on the deployment's behalf.

SMS is also named elsewhere in this module — an `if (type == 'sms')` in the
library dartdoc's argument for a registry, a `SmsClientMechanism()` in every
registration example — because a pluggable design argued only against the
mechanisms it ships proves nothing: the panels are pluggable because enrolling
TOTP (show a secret), SMS (type a number, wait) and a passkey (touch a key, no
visible payload) look nothing alike.

The set is held by the suite, not only by this section: it asserts that the
registry holds exactly `totp` after the built-ins install on a target with no
authenticator and `totp` and `webauthn` where one exists, and that `lib/`
declares exactly those two `Tom2FAClientMechanism` subclasses — the last
because a mechanism could be declared and left unregistered and would still be
part of the package's surface.

## The Shipped TOTP Mechanism

TOTP is the mechanism every deployment has, so it ships registered rather than
as a sample to copy. It is also the mechanism that best demonstrates why the
panels are pluggable at all: enrolling one means *showing the user a secret* —
as a QR code to scan and as a string to type when the camera is not an option —
which looks nothing like enrolling an SMS factor or a WebAuthn one.

The server's TOTP service writes four `clientData` keys, and
`TomTotp2FAClientMechanism` reads all four:

| `clientData` key | Constant | Written on | Meaning |
| ---------------- | -------- | ---------- | ------- |
| `otpauthUri` | `uriKey` | enrolment | The `otpauth://` URI, rendered as the QR code |
| `secret` | `secretKey` | enrolment | The base32 secret, shown grouped for manual entry |
| `digits` | `digitsKey` | both | The code width the field is sized and validated to |
| `periodSeconds` | `periodKey` | both | The length of one time step, driving the challenge panel's countdown |

All four are read defensively: the map crossed the wire, and a panel that threw
on a missing key would turn a server-side omission into a crashed login screen
rather than a field with a sensible default.

Four helpers are public and static:

| Helper | Purpose |
| ------ | ------- |
| `digitsOf(clientData)` | The declared code width, or the RFC's six. Accepts an `int` or a numeric `String`, since servers that JSON-encode numbers as strings are a real thing. |
| `periodOf(clientData)` | The declared time step as a `Duration`, or the RFC's thirty seconds. Same defence. |
| `secondsRemainingIn(period)` | Whole seconds left in the step containing now — the countdown's value. |
| `groupSecret(secret)` | Splits the base32 secret into space-separated groups of four — the difference between manual enrolment being annoying and being abandoned. |

They are public because the flow has no business knowing TOTP's defaults, while
a test — and a cross-tier runner deriving an expected code — needs the same
reading the panel uses, and two readings would be one too many.

The enrolment panel shows the QR code, the account label beneath it when the
application supplied one, the grouped secret as selectable text, and a
digits-only confirmation field. The challenge panel is an autofocused
digits-only field sized from `digitsOf`, a countdown beneath it, and a submit
button. Both carry stable keys (`tom-2fa-totp-qr`, `tom-2fa-totp-secret`,
`tom-2fa-totp-account`, `tom-2fa-totp-enrolment-code`,
`tom-2fa-totp-challenge-code`, `tom-2fa-totp-challenge-countdown`,
`tom-2fa-totp-challenge-code-changed`, and the two submit buttons).

### The challenge countdown

A TOTP code lives for one step — thirty seconds by default. A user who reads the
code, switches back and types slowly submits an expired one, and without a
countdown the refusal says only that the code was wrong: nothing on screen
separates "you typed it wrong" from "you typed it too late", and the attempt is
spent either way.

The challenge panel counts down. The value is seeded from the true boundary —
TOTP steps are aligned to the Unix epoch, so `secondsRemainingIn` derives it
from the same UTC seconds `TomTotp.counterFor` divides, without a server
timestamp — and a one-second timer counts it down from there. Re-reading the
clock every second would buy accuracy nobody can see: the timer's jitter over
the five minutes a challenge stays answerable is a fraction of one of the
seconds displayed, and the number is advice to a person.

**When a rollover overtakes something already typed**, a second line says so.
Only then — a rollover the user was not typing through is not news, and a panel
that announced every one of them would say something alarming every thirty
seconds to a user who is still reading. Any edit withdraws it, because the code
in the field belongs to the current step again.

**The line warns; it does not block.** It neither clears the field nor disables
the submit button, and that is the measured part of the decision:
`TomTotp2FAService` accepts one step either side of its own
(`globalSettingWindowSteps`), so a code typed just before a rollover is still
good. A panel that refused to send it would enforce a policy stricter than the
one that judges it — and would cost the user the very attempt it was trying to
save.

## The Shipped Passkey Mechanism

A passkey is a key pair made by an authenticator — a phone's secure enclave, a
security key, a laptop's TPM — whose private half never leaves it. It is the
strongest of the common factors, and phishing-resistant by construction: the
browser writes the page's real origin into what the authenticator signs, and the
server refuses any origin it did not configure.

Its panels have nothing to show and nothing to type: a sentence and one button.
The button is not decoration — Safari refuses a WebAuthn ceremony that a user
gesture did not start, so the panel cannot begin one when it appears.

- **Enrolment** reads the server's creation options from `clientData` under
  `publicKey` (the W3C `PublicKeyCredentialCreationOptionsJSON` form, decoded by
  the kernel's `TomWebAuthnCreationOptions`), hands them to
  `TomWebAuthnPlatform.instance.create`, and submits the authenticator's
  response.
- **The challenge** does the same with request options and
  `TomWebAuthnPlatform.instance.get`.

**The answer travels through the `String` seam.** `onSubmit` takes what the
mechanism collected: for TOTP the code the user typed, for a passkey the
authenticator's response, encoded by `toSubmission()` as its W3C JSON form,
UTF-8 and then base64url. The flow, which owns the busy flag and the error line,
neither knows nor needs to know that this answer was not typed, and no other
mechanism changed shape to admit it.

**A cancelled prompt is one message.** The browser reports a cancelled, a
timed-out and a refused ceremony identically (`NotAllowedError`), deliberately,
so a page cannot learn whether the user holds a credential. The platform turns
each into a `TomWebAuthnPlatformException`, and the panel shows
`two_factor.webauthn.failed` and lets the user press the button again. A wrong
answer — a passkey the server does not accept — comes back through the flow's
error line like any other.

**The web binding needs no plugin.** `TomWebAuthnPlatform`'s default on the web
reaches `navigator.credentials` through `dart:js_interop` and converts the
base64url fields of the JSON forms to and from typed arrays; it builds for
dart2js and for WebAssembly. Off the web the default is
`TomUnavailableWebAuthnPlatform`, which reports `isAvailable` `false`.

## Text Resources

Every string the flow and the shipped panels display is a key looked up in the
installed `TomTextResourceProvider` — there is no literal user-facing text
anywhere in this feature. `Tom2FATexts` collects the keys in one place, because
a deployment writing its bundle needs one list of what to translate, and a key
that exists only at its use site is a key nobody discovers is missing until a
user hits that screen.

Everything lives under the `two_factor.` scope; mechanism-specific keys nest one
level further under the mechanism key, the same shape the server's descriptors
follow, so a mechanism's catalog entry and its panel's text sit together in the
bundle.

| Constant | Key | Shown |
| -------- | --- | ----- |
| `chooseTitle` | `two_factor.choose.title` | Title while choosing |
| `chooseIntro` | `two_factor.choose.intro` | Above the mechanism list |
| `enrolTitle` | `two_factor.enrol.title` | Title while confirming an enrolment |
| `challengeTitle` | `two_factor.challenge.title` | Title while a challenge is outstanding |
| `skip` | `two_factor.skip.label` | The decline affordance |
| `skipSpendsGrace` | `two_factor.skip.spendsGrace` | Beside it, when declining costs a grace login |
| `cancel` | `two_factor.cancel.label` | The abandon affordance |
| `attemptsRemaining` | `two_factor.attemptsRemaining` | Attempt budget; `{count}` is substituted |
| `noRenderableMethods` | `two_factor.error.noRenderableMethods` | The chooser, when nothing offered can be rendered — about *enrolment* |
| `unrenderableChallenge` | `two_factor.error.unrenderableChallenge` | The challenge stop, when the outstanding challenge's mechanism has no panel in this build |
| `enrolmentExpired` | `two_factor.error.enrolmentExpired` | Above a set-up panel whose offer has lapsed — a notice, the panel stays |
| `challengeExpired` | `two_factor.error.challengeExpired` | Above a challenge panel whose challenge has lapsed — likewise |
| `totpEnrolIntro` | `two_factor.totp.enrol.intro` | Above the QR code |
| `totpEnrolQrLabel` | `two_factor.totp.enrol.qrLabel` | Announced in place of the QR code |
| `totpEnrolManualEntry` | `two_factor.totp.enrol.manualEntry` | Introduces the typed fallback |
| `totpEnrolCodeLabel` | `two_factor.totp.enrol.codeLabel` | The confirmation field |
| `totpEnrolSubmit` | `two_factor.totp.enrol.submit` | The enrolment submit button |
| `totpChallengeCodeLabel` | `two_factor.totp.challenge.codeLabel` | The challenge field |
| `totpChallengeSubmit` | `two_factor.totp.challenge.submit` | The challenge submit button |
| `totpChallengeExpiresIn` | `two_factor.totp.challenge.expiresIn` | The countdown line; `{seconds}` is substituted |
| `totpChallengeCodeChanged` | `two_factor.totp.challenge.codeChanged` | Shown once a rollover has overtaken a typed code |
| `webauthnEnrolIntro` | `two_factor.webauthn.enrol.intro` | Above the create-a-passkey button |
| `webauthnEnrolSubmit` | `two_factor.webauthn.enrol.submit` | The button that asks the platform to make a passkey |
| `webauthnChallengeIntro` | `two_factor.webauthn.challenge.intro` | Above the use-a-passkey button |
| `webauthnChallengeSubmit` | `two_factor.webauthn.challenge.submit` | The button that asks the platform to sign in |
| `webauthnFailed` | `two_factor.webauthn.failed` | Shown when the platform prompt was cancelled, timed out or refused |

`Tom2FATexts.text(key)` resolves against the installed provider, and
`textWith(key, placeholder, value)` additionally substitutes `{placeholder}`.
Substituting here rather than in each panel keeps the *wording* in the bundle
and the *value* in the code — including where in the sentence the number falls,
which differs by language.

Resolution goes through the provider on every call, so a deployment that swaps
the provider mid-session changes what every panel shows without any panel
caching a stale string. An unknown key resolves to the key itself, which is the
right failure here: an untranslated build shows `two_factor.totp.enrol.submit`
on the button — ugly and unmistakable — rather than a blank control that looks
like a layout bug.

## The QR View

`TomQrCodeView` renders a payload as painted modules rather than as an image
asset. The framework needs exactly one QR code and needs it to sit inside a
themed panel like any other widget; a rendering package would bring its own
colours, sizing conventions and dependency surface for that one use, while the
pure-Dart `qr` encoder plus a small `CustomPainter` brings none of it.

| Parameter | Default | Purpose |
| --------- | ------- | ------- |
| `data` | required | The payload to encode |
| `size` | `200` | Edge length in logical pixels |
| `padding` | `8` | The quiet zone — a scanning requirement, not a styling preference |
| `foreground` | black | Module colour; overridable for a dark-themed panel |
| `background` | white | Quiet-zone and light-module colour |
| `semanticsLabel` | `null` | Already-resolved text announced in place of the code |

It is sized by the caller rather than by intrinsic content: a QR code has no
natural size, only a natural aspect, and the panel is the party that knows how
much room it can spare.

**It generates; reading a code is the code scanner's job.** The QR use the
second-factor flow has is showing an enrolment URI for a phone to read, and
this widget serves it. Reading a code — off another device, or off a printed
recovery sheet — goes through [`TomCodeScanner`](#the-code-scanner), a
contract the framework holds without a camera plugin behind it.

Encoding is the expensive part of this widget by a wide margin — a typical
enrolment URI costs on the order of 2.6 ms, some 16 % of a 60 fps frame budget,
because the encoder trials all eight mask patterns and scores each one. It
depends on `data` alone, so the widget is stateful and encodes when `data`
changes rather than on every build. That matters because the enrolment panel
rebuilds for reasons of its own — every busy flag, every controller
notification — and none of those change the code. A resize or a recolour does
not re-encode either: `size`, `padding` and the two colours are applied at paint
time.

The painter's `shouldRepaint` compares the *payload*, not the encoded image.
`QrImage` declares no `operator ==`, so comparing two of them is an identity
test — which for a guard whose whole purpose is to notice that nothing changed
would be the same as having no guard at all. The payload determines the modules
(the correction level is fixed), so comparing it compares the rendering, and it
stays correct regardless of how the encoded value happens to be cached.

The widget never throws on its payload. Two values render an empty square of the
requested size instead of a code:

| `data` | Why it renders blank |
| ------ | -------------------- |
| empty | The honest rendering of "there is nothing to scan yet", rather than a valid-but-meaningless code |
| longer than 2331 bytes | Past the capacity of the largest code at the correction level used here |

Neither is treated as an error, because neither is the widget's to prevent. For
TOTP the payload arrives from the server, and an `otpauth://` URI grows with the
issuer and account label a deployment configures — nothing between that config
and this widget bounds their length. Throwing would trade a panel the user can
still complete by typing the secret for a crashed screen they cannot. The
capacity case is caught from the encoder rather than pre-checked, because the
encoder publishes no capacity predicate and reimplementing its block arithmetic
here would mean re-deriving it on every upgrade; the catch names the one
exception type that means "too long", so a genuine encoder fault still surfaces.

`semanticsLabel` takes resolved text, not a resource key: the widget is a
generic renderer with no opinion about where strings come from, and the caller
does have one. A screen-reader user needs the widget's *purpose* announced and
the base32 fallback string beside it, not a transcription of the code.

## The Code Scanner

Reading a code needs three things: a camera preview, a decoder over its
frames, and the platform permissions both bring — camera entitlements, runtime
prompts, per-platform manifests. A camera plugin supplies all three. The
framework holds the **contract** for scanning and never the plugin: an
application that scans picks its plugin, keeps it in its own layer, and
implements `TomCodeScanner` over it in one adapter class. An application that
does not scan carries no camera dependency and no permission surface.

Everything above the adapter — a screen that scans an enrolment code, a test
that drives one — is written against the contract. In a test it runs on
`TomFakeCodeScanner`, which needs no camera.

### The contract

| Member | Signature | What it does |
| ------ | --------- | ------------ |
| `availability` | `Future<TomCodeScannerAvailability> availability()` | Whether scanning can work here now |
| `scan` | `Stream<TomScannedCode> scan({Set<TomCodeFormat> formats = const {}})` | The codes the camera reads, as it reads them; every format the adapter supports when `formats` is empty |
| `preview` | `Widget preview(BuildContext context)` | The camera preview of the running scan, placed by the screen |
| `dispose` | `Future<void> dispose()` | Releases everything the scanner holds; it scans no more afterwards |
| `scanOnce` | `Future<TomScannedCode?> scanOnce({formats, accept, timeout})` | The first code `scan` reads that `accept` takes, or `null` when `timeout` passes first. Implemented on the contract over `scan` |
| `resolve` | `static TomCodeScanner? resolve()` | The installed scanner, or `null` |
| `install` | `static void install(TomCodeScanner scanner)` | Installs the process-wide scanner, replacing one installed before |

The first four are abstract; an adapter implements them. `scanOnce`,
`resolve` and `install` come with the contract.

A decoded code is a `TomScannedCode`: its `payload` text, its `format`, the
raw `bytes` when the decoder reports them, and `scannedAt`. `TomCodeFormat`
names the symbologies a scan can ask for — `qrCode`, `dataMatrix`, `aztec`,
`pdf417`, `code128`, `code39`, `ean13`, `ean8` and `upcA`. A code the
decoder reads in any other symbology arrives as `other`.

### Installing and resolving a scanner

The application installs its adapter once, at start-up. `install` puts it in
the bean context by type, and `resolve` reads it back:

```dart
// at start-up
TomCodeScanner.install(MobileScannerCodeScanner());

// wherever a code is wanted
final scanner = TomCodeScanner.resolve();
```

`resolve` answers `null` when nothing was installed. Code that offers a scan
only where one is possible can test for that rather than fail.

### The lifecycle is the stream's

`scan` opens the camera when its stream is **listened to** and releases it
when the subscription is **cancelled**. There is no start or stop method:
listening is starting, cancelling is stopping. One scan runs at a time.

A code that stays in view is reported **once**, not on every frame. A screen
that lists what it read gets one row per code held up to the camera.

`scanOnce` is the common case wrapped: it listens, waits for the first code
`accept` takes (any code when `accept` is omitted), and cancels. It ends in
one of four ways — a code, `null` after `timeout`, `null` when the stream
ends, or the stream's error rethrown. On every one of them the subscription is
cancelled before the future completes, so once `scanOnce` returns the camera
is off.

```dart
final code = await TomCodeScanner.resolve()!.scanOnce(
  formats: {TomCodeFormat.qrCode},
  accept: (code) => code.payload.startsWith('otpauth://'),
  timeout: const Duration(minutes: 1),
);
```

### Availability

`availability()` lets a screen decide whether to offer a scan button before
the user presses it:

| Value | Meaning | A screen typically |
| ----- | ------- | ------------------ |
| `available` | The camera can be used | Offers the scan |
| `permissionNotRequested` | The user has not been asked yet; scanning will ask | Offers the scan |
| `permissionDenied` | The user refused the camera; the platform's settings are the way back | Says where to allow it |
| `noCamera` | The device has no camera | Offers no scan |
| `unsupported` | The platform or the adapter cannot scan here | Offers no scan |

What an adapter can answer depends on its plugin. A plugin that cannot report
the permission without starting the camera answers `permissionNotRequested`
until the first scan, and what that scan found afterwards.

### Errors and their keys

A scan that cannot start ends with a `TomCodeScannerException` **on the
stream**, never with an empty stream. An empty stream would read as "nothing
scanned yet" when the truth is "nothing can be scanned", and a screen could
not tell the two apart. The exception's `key` names the cause:

| Key | Raised when |
| --- | ----------- |
| `code_scanner.permission_denied` | The user refused the camera |
| `code_scanner.no_camera` | The device has no camera |
| `code_scanner.unsupported` | The platform or the adapter cannot scan |
| `code_scanner.failed` | The camera could not start for another reason |
| `code_scanner.disposed` | A scan was asked of a scanner that was disposed |

`TomCodeScannerException` extends `TomException`, so its `defaultUserMessage`
is there for a screen to show and its `rootException` carries the plugin's own
error.

### The test double

`TomFakeCodeScanner` is a complete `TomCodeScanner` that a test drives by
hand:

| Member | What it does |
| ------ | ------------ |
| `emit(payload, {format})` | Delivers a code to the running scan; answers whether a scan was running. A code of a format the scan did not ask for is not delivered, as a real decoder would not report it |
| `fail(cause)` | Makes the next scan end with a `code_scanner.<cause>` error |
| `availabilityValue` | What `availability()` answers; `available` unless set |
| `listening` | Whether a scan is running — whether "the camera is on" |
| `lastFormats`, `scansStarted` | The formats the last scan asked for, and how many scans started |
| `disposed` | Whether `dispose()` was called |

Its `preview` is an empty box keyed
`ValueKey('tom-fake-code-scanner-preview')`, so a widget test can find where a
screen placed it. After `dispose()`, `scan` answers a stream that fails with
`code_scanner.disposed`.

```dart
final fake = TomFakeCodeScanner();
TomCodeScanner.install(fake);

final enrolment = TomCodeScanner.resolve()!.scanOnce(
  formats: {TomCodeFormat.qrCode},
  accept: (code) => code.payload.startsWith('otpauth://'),
);
await Future<void>.delayed(Duration.zero);
fake
  ..emit('https://example.com/menu')
  ..emit('otpauth://totp/Tom:ada?secret=JBSWY3DPEHPK3PXP');
final code = await enrolment;   // the otpauth code; the menu link was passed over
assert(!fake.listening);        // and the camera is off again
```

This is taken from
[`example/security/code_scanner_example.dart`](../example/security/code_scanner_example.dart),
which `test/code_scanner_test.dart` runs.

### Writing an adapter

An adapter is one class that extends `TomCodeScanner` and is the only file in
the application that imports the camera plugin. It does five things:

1. **Maps the formats.** `TomCodeFormat` to the plugin's format type and back.
   An empty set, or one holding `other`, asks the decoder for every format.
2. **Opens the camera on listen.** In `scan`, return a stream whose
   `onListen` starts the plugin's camera controller with the requested
   formats, and whose `onCancel` stops and disposes it.
3. **Reports each code once.** Use the plugin's duplicate suppression, or
   suppress repeats in the adapter, so a code held in view is one event.
4. **Turns plugin errors into keys.** Catch the plugin's start-up error and add
   a `TomCodeScannerException` with the matching `code_scanner.*` key to the
   stream, with the plugin error as `rootException`.
5. **Shows the preview.** `preview` returns the plugin's preview widget for
   the running controller, or an empty box when no scan runs.

`tom_core_samples/core_flutter_code_scanner_sample` is a complete adapter over
the `mobile_scanner` plugin: `MobileScannerCodeScanner`, its format, code and
error mappings as plain functions with their own tests, a screen that scans
through the contract, and a widget test that drives that screen through
`TomFakeCodeScanner`. Moving to another plugin means rewriting the adapter and
nothing else.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `code_scanner.dart`, `two_factor_totp_client.dart` | the one-second `Timer` behind the challenge panel's countdown; the scan stream's controller, subscription, completer and timeout `Timer` |
| `dart:js_interop` | dart | `webauthn_platform_web.dart` | the browser's `navigator.credentials`, on the web only — selected by a conditional import |
| `dart:js_interop_unsafe` | dart | `webauthn_platform_web.dart` | `setProperty` / `getProperty`, to set WebAuthn's binary fields as typed arrays |
| `dart:typed_data` | dart | `webauthn_platform_web.dart` | `Uint8List`, converted to and from the browser's array buffers |
| `flutter` | package | `code_scanner.dart`, `qr_code_view.dart`, `two_factor_client.dart`, `two_factor_flow.dart`, `two_factor_totp_client.dart`, `two_factor_webauthn_client.dart` | `material` for the flow frame and the TOTP panels, which style their countdown and footnote lines from the ambient theme; `widgets` for the rest; `services` for the digits-only input formatter |
| `qr` | package | `qr_code_view.dart` | the pure-Dart QR encoder `TomQrCodeView` paints |
| `tom_core_kernel` | package | 8 of 10 files | the wire types the controller surfaces (`Tom2FAPendingEnrolment`, `Tom2FAChallenge`, `Tom2FAMethodDescriptor` and its resource-key convention), `TomTextResourceProvider` for text lookup, `TomTotp` for the default code width, and the passkey wire types (`TomWebAuthnCreationOptions`, `TomWebAuthnRequestOptions`, the two responses, `TomBase64Url`), and `TomBean` and `TomException` for the code scanner's installation and its errors |
| `tom_flutter_ui` | package | `two_factor_flow.dart`, `two_factor_totp_client.dart`, `two_factor_webauthn_client.dart` | `TomText`, `TomListTile`, `TomTextButton`, `TomSelectableText`, `TomTextField` and `TomFilledButton` — plus `TomUIIcons`, which resolves the chooser's icon names to drawable icons |
