# Tom Core Flutter API Reference: Security Module

The client half of the framework's second-factor design — the flow widget, the
controller seam, the pluggable mechanism contract and its registry, the shipped
TOTP mechanism, the resource keys and the QR view.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [Tom2FAFlowController](#tom2faflowcontroller)
  - [Tom2FAFlowPanel](#tom2faflowpanel)
  - [Tom2FAClientMechanism](#tom2faclientmechanism)
  - [Tom2FAEnrolmentPanelContext](#tom2faenrolmentpanelcontext)
  - [Tom2FAChallengePanelContext](#tom2fachallengepanelcontext)
  - [Tom2FAClientRegistry](#tom2faclientregistry)
  - [TomTotp2FAClientMechanism](#tomtotp2faclientmechanism)
  - [Tom2FATexts](#tom2fatexts)
  - [TomQrCodeView](#tomqrcodeview)
- [Global Functions and Constants](#global-functions-and-constants)
- [Internal Symbols (not exported)](#internal-symbols-not-exported)

## Overview

Sources: all five exported from the package barrel
(`lib/tom_core_flutter.dart`):

| File | Declares |
| ---- | -------- |
| `lib/src/tomclient/security/two_factor_flow.dart` | `Tom2FAFlowController`, `Tom2FAFlowPanel` |
| `lib/src/tomclient/security/two_factor_client.dart` | `Tom2FAEnrolmentPanelContext`, `Tom2FAChallengePanelContext`, `Tom2FAClientMechanism`, `Tom2FAClientRegistry` |
| `lib/src/tomclient/security/two_factor_totp_client.dart` | `TomTotp2FAClientMechanism` |
| `lib/src/tomclient/security/two_factor_texts.dart` | `Tom2FATexts` |
| `lib/src/tomclient/security/qr_code_view.dart` | `TomQrCodeView` |

Nine public types. The flow widget renders whichever stop of a second-factor
login the application's controller reports; per-mechanism rendering is resolved
through a process-wide registry keyed by mechanism string. See
[`security.md`](../security.md) for the design and the integration narrative.

## Class Hierarchy

```
Tom2FAFlowController              (abstract — implemented by the application)

StatefulWidget
    └── Tom2FAFlowPanel

StatelessWidget
    └── TomQrCodeView

Tom2FAClientMechanism             (abstract)
    └── TomTotp2FAClientMechanism (shipped, registered under 'totp')

Tom2FAEnrolmentPanelContext       (value)
Tom2FAChallengePanelContext       (value)
Tom2FAClientRegistry              (static-only)
Tom2FATexts                       (static-only)
```

## Classes

### Tom2FAFlowController

The moves a second-factor login can make, implemented by the application over
its own auth client. The framework cannot call the enrolment endpoints itself —
each deployment's auth service owns its own DTOs — but the *set of moves* is
universal, so that is what the seam is.

Every method may throw; `Tom2FAFlowPanel` catches whatever comes back and
renders it through [`describeError`](#tom2faflowcontroller).

- **Kind:** abstract class

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `pendingEnrolment` | `Tom2FAPendingEnrolment?` | The enrolment the login is part-way through, or `null` when none is owed. |
| `pendingChallenge` | `Tom2FAChallenge?` | The challenge the login is waiting on, or `null` when none is outstanding. |
| `availableMethods` | `List<Tom2FAMethodDescriptor>` | The mechanism catalog the server sent, supplying the chooser's labels. Defaults to `const []`; empty is legitimate, and the chooser falls back to the scoped descriptor convention. |
| `accountLabel` | `String` | The account the factor is being set up for, shown beside the QR code. Defaults to `''`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `chooseMethod` | `Future<void> chooseMethod(String type)` | Begins enrolment in the mechanism the user picked. |
| `confirmEnrolment` | `Future<void> confirmEnrolment(String code)` | Confirms the half-built factor with the code the user entered. |
| `skipEnrolment` | `Future<void> skipEnrolment()` | Declines the offer. Only reachable when the server marked it skippable, so an implementation may treat an unexpected call as a programming error. |
| `submitSecondFactor` | `Future<void> submitSecondFactor(String code)` | Answers the outstanding challenge. |
| `cancel` | `void cancel()` | Abandons the flow and returns to the credentials screen. |
| `describeError` | `String describeError(Object error)` | Turns a failure thrown by any of the above into a displayable message. Defaults to `'$error'`. |

### Tom2FAFlowPanel

Renders whichever stop of the second-factor flow its controller reports.

Stateless with respect to the *login*: the flow's position is read from the
controller on every build, and the only state held is the widget's own — whether
a call is in flight, and what the last failure said. That is what lets an
application drive the panel by rebuilding, and what stops the panel and the
session disagreeing about where the login is.

Three stops, in precedence order: a pending **challenge** outranks a pending
**enrolment**, and an enrolment with no offer yet renders the **chooser**. With
neither pending, the panel renders `SizedBox.shrink()`.

- **Extends:** `StatefulWidget`

#### Constructors

```dart
const Tom2FAFlowPanel({Key? key, required Tom2FAFlowController controller})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `controller` | `Tom2FAFlowController` | The seam to the application's auth client. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerBuiltInMechanisms` | `static void registerBuiltInMechanisms()` | Registers the mechanisms the framework ships with. Called from the panel's `initState`, so an application gets TOTP without wiring. Idempotent, and it never overwrites a mechanism an application registered under the same key first. |

#### Widget Keys

Stable and public, so an integration test can drive the flow without matching
on text a resource bundle is free to change.

| Key | On |
| --- | -- |
| `tom-2fa-chooser` / `tom-2fa-enrolment` / `tom-2fa-challenge` | The frame of each stop |
| `tom-2fa-title` | The stop title |
| `tom-2fa-error` | The error line, present only after a failure |
| `tom-2fa-attempts` | The attempt-budget line. Absent on a challenge whose mechanism has no panel — no attempt can be spent there |
| `tom-2fa-skip` / `tom-2fa-skip-cost` | The decline affordance and its grace-login warning |
| `tom-2fa-cancel` | The abandon affordance |
| `tom-2fa-method-<type>` | One chooser tile |
| `tom-2fa-no-methods` | The chooser, when nothing offered can be rendered |
| `tom-2fa-enrolment-expired` / `tom-2fa-challenge-expired` | Above a panel whose deadline has passed. A **notice, not a refusal**: the panel and its submit button stay, because `expiresAt` is an absolute instant the server issued, there is no skew window on this path, and a flow that hid the panel on its own verdict would lock a fast-clocked user out of a login the server would still complete. The chooser never shows one — `Tom2FAPendingEnrolment.isExpired` answers false while choosing, there being no generated material to go stale |
| `tom-2fa-unrenderable-challenge` | The challenge stop, when the outstanding challenge's mechanism has no panel in this build. Its own key and its own message: the chooser's is about *enrolment*, and a user being challenged is not setting anything up. Cancel is the only exit — the state needs a newer build, which is what the message says — and skip is absent, being enrolment-only by construction |

### Tom2FAClientMechanism

One mechanism's client-side rendering, registered under its mechanism key. The
client mirror of the server's 2FA adaptor: the server knows how to *generate and
verify* the factor, this knows how to *show* it. Pairing is by `type` alone —
neither side imports the other.

- **Kind:** abstract class

#### Constructors

```dart
const Tom2FAClientMechanism(String type)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism key, matching the server adaptor's (e.g. `'totp'`). |
| `descriptor` | `Tom2FAMethodDescriptor` | The catalog entry for the chooser — label, description and icon, all as resource keys, and the chooser renders all three. The icon resolves in two steps (bundle key → icon name → `TomUIIcons` adapter) and is optional: no bundle entry or no adapter renders the row without one. Defaults to the `two_factor.<type>.*` convention, so a conforming mechanism says nothing here. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `buildEnrolmentPanel` | `Widget buildEnrolmentPanel(BuildContext context, Tom2FAEnrolmentPanelContext data)` | Renders the panel that walks the user through setting the factor up. |
| `buildChallengePanel` | `Widget buildChallengePanel(BuildContext context, Tom2FAChallengePanelContext data)` | Renders the panel that asks the user to answer a challenge. |

### Tom2FAEnrolmentPanelContext

What a mechanism's **enrolment** panel is given to render itself. A value rather
than a bag of positional parameters, so adding a field later does not break
every mechanism that ever shipped.

#### Constructors

```dart
const Tom2FAEnrolmentPanelContext({
  required String type,
  required Map<String, Object?> clientData,
  required ValueChanged<String> onSubmit,
  String accountLabel = '',
  bool busy = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism key this panel belongs to, so one class can serve several closely-related mechanisms. |
| `clientData` | `Map<String, Object?>` | The mechanism's enrolment payload, decoded from the interim token's public claims. |
| `accountLabel` | `String` | The account label to show alongside the factor. May be empty, in which case the shipped TOTP panel omits the caption rather than rendering a blank one. **The one value the application supplies to a panel** — everything else on either context comes from the server's offer or from the flow. A further need adds a further *named* field: an untyped `applicationData` map was declined, because one opaque map on this path is the server's `clientData` and a second with different provenance is how the two get confused. |
| `onSubmit` | `ValueChanged<String>` | Called with whatever the user typed. The panel does not decide what happens next. |
| `busy` | `bool` | Whether the flow is mid-call. Panels disable their controls on this rather than tracking a flag of their own. |

### Tom2FAChallengePanelContext

What a mechanism's **challenge** panel is given to render itself — the sibling
of `Tom2FAEnrolmentPanelContext`, one step later in the story, plus the attempt
budget the user is spending.

It carries **nothing the application supplied**, where the enrolment context
carries `accountLabel`. An absence of demand rather than a rule: a challenge
screen naming the account it is for would be as useful, and adding the field is
one line here and one in the flow. It is not added on the chance, because a
field nobody asked for is a field nobody can say what belongs in. The suite
asserts the exact field set, so adding it is a decision rather than a drift.

#### Constructors

```dart
const Tom2FAChallengePanelContext({
  required String type,
  required Map<String, Object?> clientData,
  required ValueChanged<String> onSubmit,
  String hint = '',
  int attemptsRemaining = 0,
  bool busy = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism key this panel belongs to. |
| `clientData` | `Map<String, Object?>` | The mechanism's opaque challenge payload. For TOTP: `digits`. |
| `hint` | `String` | A short displayable hint the mechanism supplied (a masked phone number, say). Empty when there is nothing useful to show. No shipped mechanism renders it — TOTP has nothing to hint — so the framework's guarantee is delivery, not display. |
| `attemptsRemaining` | `int` | How many verification attempts remain before the challenge is burned. |
| `onSubmit` | `ValueChanged<String>` | Called with the code the user entered. |
| `busy` | `bool` | Whether the flow is mid-call. |

### Tom2FAClientRegistry

The mechanism catalog the second-factor flow dispatches through. Process-wide
rather than injected, because it is consulted from inside widget builds several
levels below whoever configured it.

The registry is **not sealed**: registration is accepted at any time, and the
window is a convention rather than something the code enforces. Sealing it after
the first flow build was considered and declined — it would forbid a mechanism
arriving from a plugin loaded after the login screen is up, to prevent a misuse
nobody has committed. See `doc/security.md` §Register at start-up.

Not constructible — the class has a private constructor and only static members.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(Tom2FAClientMechanism mechanism)` | Registers under the mechanism's `type`, **replacing** any previous entry. Replacing rather than rejecting, so an application substituting its own panel does not have to unregister first. **A start-up call**: it is accepted at any time and takes effect on the next frame, because the flow resolves the mechanism on every build. A late replacement that renders a *different* panel widget takes the screen over and discards what the user had typed; one that renders the same widget keeps it, so wrapping or subclassing the shipped panel is free. |
| `find` | `static Tom2FAClientMechanism? find(String type)` | The mechanism registered under `type`, or `null`. Nullable rather than throwing: "the server offered a mechanism this build cannot render" is a real deployment state. |
| `has` | `static bool has(String type)` | Whether a mechanism is registered under `type`. |
| `reset` | `static void reset()` | Drops every registration, including built-ins. `@visibleForTesting`; production code has no reason to call it. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `types` | `Iterable<String>` | Every registered mechanism key. |

### TomTotp2FAClientMechanism

The shipped authenticator-app mechanism, registered under `'totp'`. Ships
registered rather than as a sample to copy, because TOTP is the mechanism every
deployment has.

**It is the only mechanism this package provides.** SMS and WebAuthn are named
throughout the module's documentation as illustrations of what the extension
point is for, and neither exists; a deployment that needs one writes the
mechanism and its server adaptor. The suite asserts both halves of that — the
registry holds exactly `totp` after the built-ins install, and `lib/` declares
exactly one `Tom2FAClientMechanism`.

Reads all four `clientData` keys the server's TOTP service writes —
`otpauthUri`, `secret`, `digits` and `periodSeconds` — each defensively, because
the map crossed the wire and a panel that threw on a missing key would turn a
server-side omission into a crashed login screen.

- **Extends:** `Tom2FAClientMechanism`

#### Constructors

```dart
const TomTotp2FAClientMechanism()
```

#### Static Constants

| Constant | Value | Description |
| -------- | ----- | ----------- |
| `mechanismType` | `'totp'` | The mechanism key, matching the server adaptor's. |
| `uriKey` | `'otpauthUri'` | `clientData` key holding the `otpauth://` URI the QR code encodes. |
| `secretKey` | `'secret'` | `clientData` key holding the base32 secret shown for manual entry. |
| `digitsKey` | `'digits'` | `clientData` key holding the code width. |
| `periodKey` | `'periodSeconds'` | `clientData` key holding the length of one time step, in seconds. |

#### Static Methods

Public because the *flow* has no business knowing TOTP's defaults, while a test
— and a cross-tier runner deriving an expected code — needs the same reading the
panel uses.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `digitsOf` | `static int digitsOf(Map<String, Object?> clientData)` | The code width declared in `clientData`, or `TomTotp.defaultDigits`. Accepts an `int` or a numeric `String`, since servers that JSON-encode numbers as strings are a real thing. |
| `periodOf` | `static Duration periodOf(Map<String, Object?> clientData)` | The time step declared in `clientData`, or `TomTotp.defaultPeriod`. Same defence as `digitsOf`. A `Duration` because that is what `TomTotp` deals in, and the arithmetic this value is for is easier to get wrong in bare seconds. |
| `secondsRemainingIn` | `static int secondsRemainingIn(Duration period, {DateTime? at})` | Whole seconds left in the step containing `at` (default: now). TOTP steps are aligned to the Unix epoch, so this needs no server timestamp — the boundary is the one `TomTotp.counterFor` divides by. Answers the full period exactly on a boundary rather than zero, because a caller renders it as "valid for another N seconds". A period that cannot divide answers `0` rather than throwing. |
| `groupSecret` | `static String groupSecret(String secret)` | Splits the secret into space-separated groups of four — what every authenticator app displays, and the difference between manual enrolment being annoying and being abandoned. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `buildEnrolmentPanel` | `Widget buildEnrolmentPanel(BuildContext, Tom2FAEnrolmentPanelContext)` | *(override)* The QR code, the optional account label, the grouped secret as selectable text, and a digits-only confirmation field. |
| `buildChallengePanel` | `Widget buildChallengePanel(BuildContext, Tom2FAChallengePanelContext)` | *(override)* An autofocused digits-only field sized from `digitsOf`, a countdown to the next rollover driven by `periodOf`, a line shown once a rollover has overtaken a typed code, and a submit button. The line warns and does not block: the server accepts one step either side of its own, so a code typed just before a rollover is still good. |

#### Widget Keys

`tom-2fa-totp-enrolment`, `tom-2fa-totp-qr`, `tom-2fa-totp-account`,
`tom-2fa-totp-secret`, `tom-2fa-totp-enrolment-code`,
`tom-2fa-totp-enrolment-submit`, `tom-2fa-totp-challenge`,
`tom-2fa-totp-challenge-code`, `tom-2fa-totp-challenge-countdown`,
`tom-2fa-totp-challenge-code-changed`, `tom-2fa-totp-challenge-submit`.

### Tom2FATexts

The resource keys the second-factor flow and its shipped panels resolve, and the
one helper that resolves them. Not constructible — private constructor, static
members only.

Collected here rather than scattered as literals at each use site because a
deployment writing its bundle needs one list of what to translate, and a key
that exists only at its use site is one nobody discovers is missing until a user
hits that screen.

#### Static Constants

| Constant | Key |
| -------- | --- |
| `scope` | `two_factor` (from `Tom2FAMethodDescriptor.resourceScope`) |
| `chooseTitle` | `two_factor.choose.title` |
| `chooseIntro` | `two_factor.choose.intro` |
| `enrolTitle` | `two_factor.enrol.title` |
| `challengeTitle` | `two_factor.challenge.title` |
| `skip` | `two_factor.skip.label` |
| `skipSpendsGrace` | `two_factor.skip.spendsGrace` |
| `cancel` | `two_factor.cancel.label` |
| `attemptsRemaining` | `two_factor.attemptsRemaining` |
| `noRenderableMethods` | `two_factor.error.noRenderableMethods` |
| `unrenderableChallenge` | `two_factor.error.unrenderableChallenge` |
| `enrolmentExpired` | `two_factor.error.enrolmentExpired` |
| `challengeExpired` | `two_factor.error.challengeExpired` |
| `totpEnrolIntro` | `two_factor.totp.enrol.intro` |
| `totpEnrolQrLabel` | `two_factor.totp.enrol.qrLabel` |
| `totpEnrolManualEntry` | `two_factor.totp.enrol.manualEntry` |
| `totpEnrolCodeLabel` | `two_factor.totp.enrol.codeLabel` |
| `totpEnrolSubmit` | `two_factor.totp.enrol.submit` |
| `totpChallengeCodeLabel` | `two_factor.totp.challenge.codeLabel` |
| `totpChallengeSubmit` | `two_factor.totp.challenge.submit` |
| `totpChallengeExpiresIn` | `two_factor.totp.challenge.expiresIn` |
| `totpChallengeCodeChanged` | `two_factor.totp.challenge.codeChanged` |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `text` | `static String text(String key)` | Resolves `key` against the installed `TomTextResourceProvider`. The single lookup point for this feature, so swapping the provider mid-session changes what every panel shows. An unknown key resolves to the key itself. |
| `textWith` | `static String textWith(String key, String placeholder, Object value)` | Resolves `key` and substitutes `{placeholder}` with `value` — keeping the wording in the bundle and the value in the code, including where in the sentence the number falls. |

### TomQrCodeView

Renders `data` as a scannable QR code, `size` logical pixels square, painted
from the pure-Dart `qr` encoder rather than pulled in as an image asset.

Sized by the caller rather than by intrinsic content: a QR code has no natural
size, only a natural aspect.

Never throws on its payload. An empty `data` renders an empty square — the
honest rendering of "there is nothing to scan yet" — and so does a `data` past
the capacity of the largest code, 2331 bytes at the correction level used here.
Neither is the widget's to prevent: for TOTP the payload comes from the server
and grows with the deployment's issuer and account label, and the enrolment
panel shows the base32 secret beside the code, so a blank square leaves a
complete enrolment path where a thrown build would leave none.

- **Extends:** `StatefulWidget`

Stateful only to hold the encoded code. Encoding costs on the order of 2.6 ms
for a typical enrolment URI — some 16 % of a 60 fps frame — and depends on
`data` alone, so it happens when `data` changes rather than on every build. A
parent that rebuilds for its own reasons, which the enrolment panel does on
every busy flag and every controller notification, costs nothing here; neither
does a resize or a recolour, since `size`, `padding` and the colours are applied
at paint time.

#### Constructors

```dart
const TomQrCodeView({
  Key? key,
  required String data,
  double size = 200,
  double padding = 8,
  Color? foreground,
  Color? background,
  String? semanticsLabel,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `data` | `String` | The payload to encode — for TOTP enrolment, the `otpauth://` URI. Empty, or longer than a code can hold, renders an empty square rather than throwing. |
| `size` | `double` | The edge length of the rendered code, in logical pixels. Default `200`. |
| `padding` | `double` | The quiet zone around the modules. Default `8` — a scanning requirement rather than a styling preference, hence a default rather than something every caller must remember. |
| `foreground` | `Color?` | The module colour. Defaults to black, which is what scanners expect; overridable because a dark-themed panel may need to invert the pair. |
| `background` | `Color?` | The quiet-zone and light-module colour. Defaults to white. |
| `semanticsLabel` | `String?` | What a screen reader announces in place of the code. Already-resolved text, not a resource key. `null` renders no semantics node. |

Encoding uses medium error correction — the standard authenticator level. Higher
levels buy damage tolerance a screen-displayed code has no use for, at the cost
of a denser grid that scans worse on small displays.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.

## Internal Symbols (not exported)

Private to their files and reachable only through the public types above; listed
so the widget tree the keys hang on is identifiable.

| Symbol | File | Role |
| ------ | ---- | ---- |
| `_Tom2FAFlowPanelState` | `two_factor_flow.dart` | Holds the busy flag and last error, and builds the three stops and their shared frame. |
| `_TotpEnrolmentPanel` | `two_factor_totp_client.dart` | The QR-and-secret enrolment panel. |
| `_TotpChallengePanel` | `two_factor_totp_client.dart` | The one-time-code challenge panel. |
| `_QrPainter` | `qr_code_view.dart` | Paints a `QrImage`'s modules, overdrawing each by half a pixel so neighbours meet cleanly instead of leaving hairline seams a scanner reads badly. |
