# security

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The client half of the framework's second-factor design: a ready-made
enrol-and-challenge flow, a seam onto the application's own auth client, a
registry of pluggable per-mechanism panels, and the shipped TOTP mechanism.

Everything about a second-factor login that is the same whichever mechanism is
in play — the chooser, the frame, the attempt counter, the error line, the skip
affordance — belongs to the framework. What a mechanism *shows* and what counts
as an *answer* varies, and lives behind `Tom2FAClientMechanism`. The token
choreography belongs to neither: the flow calls the application's controller,
whose auth client already handles refresh.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `Tom2FAFlowPanel` | Renders whichever stop the login is at — chooser, enrolment or challenge — reading the position from the controller each build. Registers the built-in mechanisms on first build. |
| `Tom2FAFlowController` | The seam the application implements over its own auth client: five moves (choose, confirm, skip, answer, cancel) and two pieces of read-only state. |
| `Tom2FAClientMechanism` | One mechanism's client-side rendering, paired with its server adaptor by `type` alone. |
| `Tom2FAClientRegistry` | Process-wide catalog the flow dispatches through; scans the reflected program for annotated mechanisms on first read, and `register` replaces, so an application can substitute a built-in. |
| `Tom2FAEnrolmentPanelContext` | What an enrolment panel is given: `type`, `clientData`, `accountLabel`, `onSubmit`, `busy`. |
| `Tom2FAChallengePanelContext` | What a challenge panel is given: the same, plus `hint` and `attemptsRemaining`. |
| `TomTotp2FAClientMechanism` | The shipped authenticator-app mechanism, registered under `'totp'`. Also the public `digitsOf` / `groupSecret` helpers. |
| `Tom2FATexts` | Every resource key this feature resolves, and the `text` / `textWith` helpers that resolve them. No literal user-facing text exists anywhere in the feature. |
| `TomQrCodeView` | A QR code painted from the pure-Dart `qr` encoder, so it themes like any other widget. Never throws on its payload: empty, or too long to encode, renders an empty square. Re-encodes and repaints only when the payload or the styling changes, not on every parent rebuild. |
| `TomClient2FAAdaptor` | Annotation that registers a mechanism under its key with no start-up wiring — the client mirror of the server's `@Tom2FAAdaptor`. See below. |
| `Tom2FAClientException` | The wiring failures the annotation scan raises, keyed `two_factor_client.*`. |

## Quick start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// The whole integration: the panel reads the flow's position from the
// controller on every build, so an application drives it by rebuilding.
if (session.needsSecondFactor) {
  return Tom2FAFlowPanel(controller: MyFlowController(session));
}
```

TOTP is registered by the panel itself on first build, so the common case needs
no set-up.

`MyFlowController` is the one piece an application writes.
[`example/security/security_example.dart`](../../../../example/security/security_example.dart)
implements one and walks it through all three stops; the panels themselves are
widgets, so they are shown in `test/two_factor_client_test.dart` instead.

## Adding a mechanism

Two routes, one registry.

**Annotate it** — no start-up code at all, and the client mirror of what the
server adaptor already does, so one package can ship both halves and touch no
framework file:

```dart
@tomReflector
@TomClient2FAAdaptor('sms')
class SmsClientMechanism extends Tom2FAClientMechanism {
  const SmsClientMechanism() : super('sms');
  // ... buildEnrolmentPanel / buildChallengePanel
}
```

`Tom2FAClientRegistry` scans the reflected program the first time anything reads
it and installs every annotated mechanism. That requires generated reflection,
an unnamed argument-free constructor, and a `type` matching the annotation; each
of the three fails with a named `Tom2FAClientException` rather than quietly, and
a build with no generated reflection logs once and carries on with whatever was
registered by hand.

**Register it** — for a mechanism whose constructor needs arguments, for an
application that does not run the reflection generator, and for substituting a
panel someone else provides:

```dart
Tom2FAClientRegistry.register(SmsClientMechanism(smsGateway));
```

Registering wins: it replaces a built-in, and the scan skips a key an explicit
registration already holds. Two *annotated* classes claiming one key are refused
instead — replacing is a decision an application takes on purpose, whereas that
is a wiring bug whose winner would otherwise depend on reflection ordering.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
