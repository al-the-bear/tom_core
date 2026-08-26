# Security Module

The client half of the framework's second-factor design: a ready-made
enrol-and-challenge flow, a seam onto the application's own auth client, a
registry of pluggable per-mechanism panels, the shipped TOTP mechanism, and the
reflection annotation that tags client 2FA adaptors.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [The Flow and Its Three Stops](#the-flow-and-its-three-stops)
- [The Controller Seam](#the-controller-seam)
- [Mechanisms and the Registry](#mechanisms-and-the-registry)
- [The Shipped TOTP Mechanism](#the-shipped-totp-mechanism)
- [Text Resources](#text-resources)
- [The QR View](#the-qr-view)
- [The Discovery Annotation](#the-discovery-annotation)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `Tom2FAFlowPanel` | `StatefulWidget` | Renders whichever stop of the second-factor login the controller reports |
| `Tom2FAFlowController` | abstract class | The seam an application implements over its own auth client — five moves, two pieces of state |
| `Tom2FAClientMechanism` | abstract class | One mechanism's client-side rendering, registered under its mechanism key |
| `Tom2FAClientRegistry` | static registry | The mechanism catalog the flow dispatches through |
| `Tom2FAEnrolmentPanelContext` | value class | What an enrolment panel is given to render itself |
| `Tom2FAChallengePanelContext` | value class | What a challenge panel is given to render itself |
| `TomTotp2FAClientMechanism` | `Tom2FAClientMechanism` | The shipped authenticator-app mechanism, registered under `'totp'` |
| `Tom2FATexts` | static keys + lookup | Every resource key this feature resolves, and the one helper that resolves them |
| `TomQrCodeView` | `StatelessWidget` | A QR code painted from the pure-Dart `qr` encoder |
| `TomClient2FAAdaptor` | `const` annotation (`@tomReflector`) | Tags a class as a client 2FA adaptor for a given `type` |

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
`tom-2fa-skip`, `tom-2fa-skip-cost`, `tom-2fa-cancel`, `tom-2fa-method-<type>`
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

**A mechanism receives the decoded `clientData` and nothing else about the
login** — no principal, no tokens, no backend handle. It renders, validates
locally if it can, and hands a string back through `onSubmit`. Whether that
string travels as a confirmation or a challenge answer, and what happens to the
token pair afterwards, is the flow's business.

`Tom2FAClientRegistry` is the catalog the flow dispatches through:

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
// At start-up, before the first flow build.
Tom2FAClientRegistry.register(SmsClientMechanism());
Tom2FAClientRegistry.register(MyOwnTotpPanel());
```

The flow installs a built-in only where nothing is registered under that key
(`Tom2FAFlowPanel.registerBuiltInMechanisms`, called from the panel's
`initState` and idempotent), so registering first wins.

## The Shipped TOTP Mechanism

TOTP is the mechanism every deployment has, so it ships registered rather than
as a sample to copy. It is also the mechanism that best demonstrates why the
panels are pluggable at all: enrolling one means *showing the user a secret* —
as a QR code to scan and as a string to type when the camera is not an option —
which looks nothing like enrolling an SMS factor or a WebAuthn one.

`TomTotp2FAClientMechanism` reads exactly the keys the server's TOTP service
writes, and nothing more:

| `clientData` key | Constant | Used by | Meaning |
| ---------------- | -------- | ------- | ------- |
| `otpauthUri` | `uriKey` | enrolment | The `otpauth://` URI, rendered as the QR code |
| `secret` | `secretKey` | enrolment | The base32 secret, shown grouped for manual entry |
| `digits` | `digitsKey` | both | The code width the field is sized and validated to |

Every one is read defensively: the map crossed the wire, and a panel that threw
on a missing key would turn a server-side omission into a crashed login screen
rather than a field with a sensible default.

Two helpers are public and static:

| Helper | Purpose |
| ------ | ------- |
| `digitsOf(clientData)` | The declared code width, or the RFC's six. Accepts an `int` or a numeric `String`, since servers that JSON-encode numbers as strings are a real thing. |
| `groupSecret(secret)` | Splits the base32 secret into space-separated groups of four — the difference between manual enrolment being annoying and being abandoned. |

They are public because the flow has no business knowing TOTP's defaults, while
a test — and a cross-tier runner deriving an expected code — needs the same
reading the panel uses, and two readings would be one too many.

The enrolment panel shows the QR code, the account label beneath it when the
application supplied one, the grouped secret as selectable text, and a
digits-only confirmation field. The challenge panel is a single autofocused
digits-only field sized from `digitsOf`. Both carry stable keys
(`tom-2fa-totp-qr`, `tom-2fa-totp-secret`, `tom-2fa-totp-account`,
`tom-2fa-totp-enrolment-code`, `tom-2fa-totp-challenge-code`, and the two
submit buttons).

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
| `noRenderableMethods` | `two_factor.error.noRenderableMethods` | When nothing offered can be rendered |
| `totpEnrolIntro` | `two_factor.totp.enrol.intro` | Above the QR code |
| `totpEnrolQrLabel` | `two_factor.totp.enrol.qrLabel` | Announced in place of the QR code |
| `totpEnrolManualEntry` | `two_factor.totp.enrol.manualEntry` | Introduces the typed fallback |
| `totpEnrolCodeLabel` | `two_factor.totp.enrol.codeLabel` | The confirmation field |
| `totpEnrolSubmit` | `two_factor.totp.enrol.submit` | The enrolment submit button |
| `totpChallengeCodeLabel` | `two_factor.totp.challenge.codeLabel` | The challenge field |
| `totpChallengeSubmit` | `two_factor.totp.challenge.submit` | The challenge submit button |

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
much room it can spare. An empty payload renders an empty square — the honest
rendering of "there is nothing to scan yet" — rather than a valid-but-
meaningless code.

`semanticsLabel` takes resolved text, not a resource key: the widget is a
generic renderer with no opinion about where strings come from, and the caller
does have one. A screen-reader user needs the widget's *purpose* announced and
the base32 fallback string beside it, not a transcription of the code.

## The Discovery Annotation

`TomClient2FAAdaptor` is a `const` annotation carrying one positional `type`.
It is itself `@tomReflector`-registered, so it appears in generated reflection
data and a runtime can enumerate the classes carrying it and recover each one's
mechanism key:

```dart
@tomReflector
@TomClient2FAAdaptor('totp')
class TotpAdaptor { /* ... */ }
```

```dart
tomReflector
    .reflectType(TotpAdaptor)
    .metadata
    .whereType<TomClient2FAAdaptor>();
```

For a class to be discoverable this way it must also be `@tomReflector`-
registered and public, so the generated reflection library can reference it.
The round-trip is pinned by `test/security_test.dart`. Because the class
participates in reflection, its signature — name, the `type` field, the `const`
constructor — is a contract: changing it requires regenerating reflection for
consumers.

**It is not what the shipped flow dispatches on.** `Tom2FAFlowPanel` resolves a
mechanism through `Tom2FAClientRegistry`, keyed by the same string, and never
consults reflection. The annotation is the discovery route for a runtime that
would rather enumerate annotated classes than have each one register itself;
nothing in this package reads it. Annotating a class therefore does *not* make
it renderable by the flow — register the mechanism for that.

## Dependencies

- **`tom_core_kernel`**: the wire types the controller surfaces
  (`Tom2FAPendingEnrolment`, `Tom2FAChallenge`, `Tom2FAMethodDescriptor` and
  its resource-key convention), `TomTextResourceProvider` for text lookup,
  `TomTotp` for the default code width, and the `tomReflector` marker that
  makes the annotation reflection-discoverable.
- **`tom_flutter_ui`**: the widget vocabulary every panel is built from —
  `TomText`, `TomListTile`, `TomTextButton`, `TomSelectableText`,
  `TomTextField` and `TomFilledButton`.
- **`flutter`**: `material` for the flow frame, which styles its title, error
  line and footnotes from the ambient theme; `widgets` for the mechanism panels,
  which have no such need; `services` for the digits-only input formatter.
- **`qr`**: the pure-Dart QR encoder `TomQrCodeView` paints.
