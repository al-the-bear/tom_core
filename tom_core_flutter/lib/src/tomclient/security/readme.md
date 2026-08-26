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
| `Tom2FAClientRegistry` | Process-wide catalog the flow dispatches through; `register` replaces, so an application can substitute a built-in. |
| `Tom2FAEnrolmentPanelContext` | What an enrolment panel is given: `type`, `clientData`, `accountLabel`, `onSubmit`, `busy`. |
| `Tom2FAChallengePanelContext` | What a challenge panel is given: the same, plus `hint` and `attemptsRemaining`. |
| `TomTotp2FAClientMechanism` | The shipped authenticator-app mechanism, registered under `'totp'`. Also the public `digitsOf` / `groupSecret` helpers. |
| `Tom2FATexts` | Every resource key this feature resolves, and the `text` / `textWith` helpers that resolve them. No literal user-facing text exists anywhere in the feature. |
| `TomQrCodeView` | A QR code painted from the pure-Dart `qr` encoder, so it themes like any other widget. Never throws on its payload: empty, or too long to encode, renders an empty square. Re-encodes and repaints only when the payload or the styling changes, not on every parent rebuild. |
| `TomClient2FAAdaptor` | Reflection-discoverable annotation (`@tomReflector`-registered) marking a class as a client 2FA adaptor. Not the flow's dispatch route — see below. |

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
no set-up. Adding or substituting a mechanism is one call at start-up, before
the first build:

```dart
Tom2FAClientRegistry.register(SmsClientMechanism());
```

## A note on the annotation

`TomClient2FAAdaptor` is **not** what the flow dispatches on. `Tom2FAFlowPanel`
resolves a mechanism through `Tom2FAClientRegistry`, keyed by mechanism string,
and never consults reflection; nothing in this package reads the annotation. It
is the discovery route for a runtime that would rather enumerate annotated
classes than have each one register itself. Annotating a class does not make it
renderable by the flow — register the mechanism for that.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
