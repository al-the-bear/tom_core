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
| `Tom2FAClientRegistry` | Process-wide catalog the flow dispatches through; `register` replaces, so an application can substitute a built-in. A start-up call — not sealed, and a late replacement that renders a *different* panel widget discards what the user had typed. |
| `Tom2FAEnrolmentPanelContext` | What an enrolment panel is given: `type`, `clientData`, `accountLabel`, `onSubmit`, `busy`. `accountLabel` is the one value the *application* supplies to a panel. |
| `Tom2FAChallengePanelContext` | What a challenge panel is given: the same, plus `hint` and `attemptsRemaining`. |
| `TomTotp2FAClientMechanism` | The shipped authenticator-app mechanism, registered under `'totp'`. Its challenge panel counts down to the next code rollover and says so when one overtakes a typed code — warning, not blocking, because the server accepts one step either side of its own. Also the public `digitsOf` / `periodOf` / `secondsRemainingIn` / `groupSecret` helpers. |
| `Tom2FATexts` | Every resource key this feature resolves, and the `text` / `textWith` helpers that resolve them. No literal user-facing text exists anywhere in the feature. |
| `TomQrCodeView` | A QR code painted from the pure-Dart `qr` encoder, so it themes like any other widget. Never throws on its payload: empty, or too long to encode, renders an empty square. Re-encodes and repaints only when the payload or the styling changes, not on every parent rebuild. |

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
// `SmsClientMechanism` is the application's own class — see below.
Tom2FAClientRegistry.register(SmsClientMechanism());
```

**TOTP is the only client mechanism this package ships.** `tom_core_server`
ships three adaptors — `totp`, and the delivered-code `email` and `sms`, each
offered once its delivery service is installed — so a deployment that offers SMS
or email codes writes only the client mechanism: a code field, a confirm step at
enrolment, and the server's masked destination as `hint`. Until it registers
one, the enrolment chooser leaves that key out. The SMS panel is not shipped on
purpose: SMS is the weakest common factor and the dearest to run, so offering it
is a step the deployment takes. WebAuthn exists on neither side.

`MyFlowController` is the one piece an application writes.
[`example/security/security_example.dart`](../../../../example/security/security_example.dart)
implements one and walks it through all three stops; the panels themselves are
widgets, so they are shown in `test/two_factor_client_test.dart` instead.

## How a mechanism becomes renderable

`Tom2FAClientRegistry.register` is the only route into the registry, and the
registry is the only thing `Tom2FAFlowPanel` consults. There is no annotation
and no scan: a mechanism the application has not registered does not appear in
the chooser, whatever else it declares about itself.

There *was* an annotation — a `TomClient2FAAdaptor` marker, exported from the
barrel and documented as a route a runtime could enumerate, which nothing
enumerated. It was removed rather than relabelled, because a reader who finds an
annotation in a barrel reasonably concludes that annotating a class does
something, ships a mechanism annotated and unregistered, and finds out at the
chooser. The suite holds the sentence above to the code: one insertion site into
the catalog, no reflection anywhere in the module, and no generated mirrors for
it in `build.yaml` — the last being what a scan would need and the half nobody
would think to check.

Registration is a **start-up** call. The registry is not sealed and the flow
resolves the mechanism on every build, so a registration made during a live flow
lands on the next frame: one that renders a *different* panel widget takes the
screen over and discards what the user had typed, while one that renders the
same widget — wrapping or subclassing the shipped panel — keeps it. See
`doc/security.md` for the whole of it, including why sealing was declined.

**No credential material reaches a panel** — no principal, no tokens, no backend
handle. What the *application* may show one is a separate question with a
separate answer: named fields on the context, supplied by the controller, one
per case that needs it. `accountLabel` is the only one so far. An untyped
`applicationData` bag was declined — there is already one opaque map here, the
server's `clientData`, and a second with different provenance is how the two get
confused — and so was routing presentation data through the server. The
challenge context has no application field yet, which is an absence of demand
rather than a rule; the suite pins both contexts' field sets so either becomes a
decision rather than a drift.

**A lapsed deadline is said out loud, not enforced.** Both wire types carry an
`isExpired` and the flow now reads it at the two stops where a deadline exists,
rendering a line above the panel. The panel and its submit button stay:
`expiresAt` is an absolute instant the server issued, there is no skew window on
this path, and a flow that hid the panel on its own verdict would lock a user
whose clock runs fast out of a login the server would still complete. The
chooser never reports a lapse — there is no generated material to go stale.

A mechanism the build cannot render is handled differently at each stop, because
the two stops have different room to manoeuvre. The **chooser** filters it out
and offers the rest, saying so only when the filter empties the list. A
**challenge** has nothing to filter — one outstanding challenge, one type, no
alternative — so it says that this sign-in method needs a newer version of the
app, prints no attempt budget (none can be spent) and leaves cancel as the one
exit. Two messages, two keys, because the chooser's is about setting a factor
*up* and a user being challenged is not.

That is a deliberate asymmetry with the server, where `@Tom2FAAdaptor` *is*
enumerated by reflection. The server owns the set of adaptors a deployment
offers and discovers them at start-up; a client build renders only the ones it
has panels for, which the build itself knows and states in one place.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
