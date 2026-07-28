# Authentication Module

Server-side login orchestration. The module turns an incoming authentication
request into JWT tokens by delegating credential checking to an
application-supplied [`TomAuthenticationService`], then encoding the resulting
principal into an authentication token and an authorization token.

## Table of Contents

- [Overview](#overview)
- [The Login Flow](#the-login-flow)
- [Implementing a Service](#implementing-a-service)
- [Wiring the Server](#wiring-the-server)
- [Two-Factor Authentication](#two-factor-authentication)
- [Core Components](#core-components)
- [Status and Limitations](#status-and-limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthenticationServer` | class (`@tomReflector`) | Orchestrates the login flow and issues JWTs |
| `TomAuthenticationService` | abstract (`@tomReflector`) | The contract an app implements to verify a login |
| `TomAuthenticationData` | class (`@tomReflector`) | The data carried into one authentication attempt |
| `TomAuthenticationInfo` | class | A service's success result: principal + access-control definition |
| `TomDummyAuthenticationService` | class | Scaffolding-only default service (accepts any non-`GUEST` user) |
| `LoginException` | exception | A login failure; carried back as a failed result |
| `TomAuthenticationAdaptor` | annotation (`@tomReflector`) | Marks an adaptor and constrains it to guest/user flows |
| `Tom2FAAdaptor` | annotation (`@tomReflector`) | Marks a 2FA adaptor for a mechanism `type` |
| `Tom2FAService` | abstract (`@tomReflector`) | The contract a second-factor mechanism implements: issue a challenge, verify a submission |
| `Tom2FARegistry` | class (statics only) | Maps a mechanism `type` to its adaptor; scans `@Tom2FAAdaptor` classes on first use |
| `Tom2FAContext` | class | What the adaptor is told about the login: the principal and its request context |
| `Tom2FAChallengeSpec` | class | What an adaptor returns from `issueChallenge` — hint, client blob, verification blob, attempts, validity |
| `Tom2FASubmission` | class | What an adaptor is handed on `verifySubmission` — the submitted factor plus its challenge |
| `TomTotp2FAService` | class (`@Tom2FAAdaptor('totp')`) | The shipped authenticator-app (RFC 6238 TOTP) mechanism |
| `Tom2FAException` | exception | A mis-wired 2FA deployment; never client-facing |

## The Login Flow

```text
TomAuthenticationMessage            (wire request)
        │
        ▼
TomAuthenticationServer.authenticatePass1 / authenticateGuest
        │  builds TomAuthenticationData
        ▼
TomAuthenticationService.authenticateUser   ← your implementation
        │  returns TomAuthenticationInfo (principal + acd)
        │  or throws LoginException
        ▼
        │
        ├─ principal.requires2FA ?  ──► see Two-Factor Authentication
        ▼
TomBearerAuthentication.convertPrincipalToTokenPayload
        │  → (public claims, encrypted private claims)
        ▼
TomAuthenticationResult
   ├─ authenticationToken   (JWT of public claims)
   └─ authorizationToken    (JWT of public claims + encrypted acd)
```

A thrown `LoginException` is **not** propagated — the server catches it and
returns a `TomAuthenticationResult` carrying the exception's `key` so the client
can show a localized message. Any other error becomes a
`"login.error.unknown"` result.

## Implementing a Service

Implement `TomAuthenticationService` to resolve credentials against your store:

```dart
class MyAuthService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) async {
    final user = await _lookup(authData.client, authData.username);
    if (!_verify(authData.key, user)) {
      throw LoginException('error.invalid-user-or-password', 'Invalid login');
    }
    final principal = _buildPrincipal(user, authData);
    final acd = await _accessControl(user);
    return TomAuthenticationInfo(principal, acd);
  }
}
```

`authData` identifies *what* is being logged into (`organization`,
`application`, `process`, `client`) and *who* (`username`), plus the credential
(`key`) and client locale (`language` / `country` / `timezone`).

## Wiring the Server

Register the service(s) and (optionally) the JWT issuer through the static
settings, then expose a subclass of `TomAuthenticationServer` as endpoints:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService = MyAuthService();
TomAuthenticationServer.globalSettingGuestAuthenticationService = MyGuestService();
TomAuthenticationServer.globalSettingJwtOrganization = 'acme';

// A @tomComponent subclass exposes authenticateGuest / authenticatePass1 as
// HTTP endpoints (see tom_uam_server for a full example).
class ServerAuthenticationServer extends TomAuthenticationServer { /* ... */ }
```

Until a real service is registered, the default
`TomDummyAuthenticationService` authenticates any non-`"GUEST"` user and logs an
error on every call — acceptable only while scaffolding.

## Two-Factor Authentication

A login that needs a second factor runs in **two passes**. Pass 1 checks the
primary credential exactly as above; if the resolved principal declares
`TomPrincipal.requires2FA`, the login does not finish there. The adaptor
registered for the principal's `twoFactorType` **issues a challenge**, and the
server answers with an *interim* token carrying it. The client answers the
challenge; pass 2 hands the submitted factor back to the same adaptor to
**verify**, and on success re-issues the token pair without the challenge.

That final pair is byte-for-byte what a 2FA-free login would have produced for
the same user: both passes mint tokens through the one private helper
(`_issueTokens`), so the only difference between a completed pass 2 and a
single-pass login is the cleared `requires2FA` claim.

### The whole path, across both packages

```text
┌─ tom_core_server ────────────────────────────────────────────────────────┐
│ authenticatePass1(message)                                               │
│   └─ TomAuthenticationService.authenticateUser  → principal              │
│        principal.requires2FA == true, twoFactorType == 'totp'            │
│   └─ Tom2FARegistry.lookup('totp')              → Tom2FAService          │
│   └─ service.issueChallenge(Tom2FAContext)      → Tom2FAChallengeSpec    │
│        .clientData        ──► public claims     (the client's UI reads)  │
│        .verificationData  ──► encrypted claims  (only pass 2 reads)      │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │ TomAuthenticationResult
                               │   requires2FA = true, twoFactorType = 'totp'
                               │   authenticationToken / authorizationToken
                               ▼        = the INTERIM token pair
┌─ tom_core_kernel (client) ───────────────────────────────────────────────┐
│ TomBearerAuthentication.setTokens(auth, authz)                           │
│ TomBearerAuthentication.pendingTwoFactorChallenge  → Tom2FAChallenge     │
│      .type .hint .attemptsRemaining .expiresAt .clientData               │
│ user enters the factor; the client calls pass 2 with the interim token   │
│ as its bearer and the factor in the message's `password` slot            │
└──────────────────────────────┬───────────────────────────────────────────┘
                               ▼
┌─ tom_core_server ────────────────────────────────────────────────────────┐
│ authenticatePass2(message)                                               │
│   └─ Tom2FAChallenge.fromClaims(bearer.payload)  (kernel type)           │
│   └─ expiry / attempt checks, then Tom2FARegistry.lookup(challenge.type)  │
│   └─ service.verifySubmission(context, Tom2FASubmission)  → bool         │
└──────────────────────────────┬───────────────────────────────────────────┘
                               ▼
       TomAuthenticationResult — the same token pair a single-pass login
       would have issued. TomBearerAuthentication.setTokens again;
       pendingTwoFactorChallenge is now null, which is the "login done" signal.
```

`Tom2FAChallenge`, `Tom2FAClaims` and `TomTotp` live in **`tom_core_kernel`**
(`security/two_factor.dart`), not here: the challenge is a wire shape that the
server writes and the client reads, and the TOTP derivation must give the same
answer on both sides. This module owns the *server* half — the registry, the
adaptor contract, and the orchestration in `TomAuthenticationServer`.

### The interim token is not a session

It is a **challenge carrier**. It looks like a token pair and is presented like
one, but:

- its `requires2FA` public claim is `"true"`, so
  `TomBearerAuthentication.convertTokenPayloadToPrincipal` builds a principal
  with `authenticated == false` — every guard that tests `authenticated`
  rejects it;
- it exists only to carry the challenge back to pass 2. Presenting it to an
  ordinary endpoint gains nothing;
- it lapses on the challenge's own short validity (default 5 minutes), not on
  the session lifetime.

It *does* carry the access-control payload pass 1 resolved. That is deliberate:
pass 2 needs no second trip to the user store, and the principal cannot be
swapped for another between the passes. The claims are there; the
`authenticated` flag that would make them usable is not.

There is no server-side "pending login" record anywhere in this flow. Any
server instance can complete a login another instance started, and a deployment
adds no session store to switch 2FA on.

### Wiring a second factor

Four steps, all of them in application code:

**1 — Mark the principal.** Your `TomAuthenticationService` decides, per user,
that a second factor is owed and which mechanism answers for it:

```dart
return TomAuthenticationInfo(
  TomPrincipal(
    user: user,
    authenticated: true,
    requires2FA: user.totpEnrolled,
    twoFactorType: TomTotp2FAService.mechanismType, // 'totp'
    // ...
  ),
  acd,
);
```

**2 — Register the mechanism.** A class carrying `@Tom2FAAdaptor('<type>')` and
`@tomReflector` is found automatically the first time the registry is consulted.
A deployment that composes its adaptors explicitly registers them instead:

```dart
Tom2FARegistry.register('sms', MySmsService());
```

Both routes fill the same map; `Tom2FARegistry.registeredTypes` reports it. A
duplicate registration for one type is a `Tom2FAException` at start-up rather
than a surprise at the login that happens to need the other one.

**3 — Configure the mechanism.** For the shipped TOTP adaptor that means
telling it where a user's secret lives:

```dart
TomTotp2FAService.globalSettingSecretResolver =
    (context) => secretStore.lookup(context.principal.username);
```

The resolver is unset by default, so an unconfigured deployment fails every
TOTP challenge with `login.error.2fa.not-enrolled` rather than accepting
anything. Note the secret is read from your own store, deliberately **not**
from `TomUser.attributes` — those are projected into the token's *public*
claims.

**4 — Drive it from the client.** Pass 1's result tells the client what
happened; the kernel reads the challenge out of the token for it:

```dart
var result = await api.login(message);
TomBearerAuthentication.setTokens(
  result.authenticationToken,
  result.authorizationToken,
);

var challenge = TomBearerAuthentication.pendingTwoFactorChallenge;
if (challenge != null) {
  // challenge.type / .hint / .attemptsRemaining / .clientData drive the UI
  final code = await promptForCode(challenge);
  // The interim token is the ambient bearer, so the pass-2 call carries it.
  result = await api.loginPass2(message..password = code);
  TomBearerAuthentication.setTokens(
    result.authenticationToken,
    result.authorizationToken,
  );
}
// pendingTwoFactorChallenge == null → the login is complete.
```

On a **wrong** code with attempts left, pass 2 answers with
`login.error.2fa.invalid-code` *and a fresh interim token* whose attempt counter
has advanced — so the loop above simply repeats. On a wrong code with no
attempts left, or a lapsed challenge, there is no token and the client must
restart at pass 1.

### Writing your own mechanism

Implement `Tom2FAService`:

```dart
@tomReflector
@Tom2FAAdaptor('sms')
class MySmsService implements Tom2FAService {
  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    final code = _random6();
    await _send(context.principal, code);
    return Tom2FAChallengeSpec(
      hint: _maskedNumber(context.principal),
      verificationData: {'hash': _hash(code)}, // encrypted; server-only
      validity: const Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async =>
      submission.verificationData['hash'] == _hash(submission.submitted);
}
```

Two rules make the rest of the flow work:

- **The two blobs are yours; the framework never looks inside either.**
  `clientData` travels in the token's **public** claims, for your own client
  UI. `verificationData` travels in the **encrypted** section, for your own
  `verifySubmission`. Anything a client must not see goes in the second one —
  and if a client could compute the answer from what you put in the first one,
  the mechanism is broken.
- **Adaptors must be stateless between the two calls.** Pass 1 and pass 2 may
  run in different isolates or on different server instances. Anything you need
  to remember belongs in `verificationData`; a field on the adaptor will not be
  there. (`TomTotp2FAService` stores nothing at all — it re-resolves the secret
  on pass 2, so the secret never travels.)

Expiry, the attempt counter and adaptor dispatch are generic and handled once in
`TomAuthenticationServer`; a mechanism never implements them.

### Outcomes

| Key | Meaning | Token returned |
| --- | ------- | -------------- |
| *(none — success)* | The factor verified | The completed pair |
| `login.error.2fa.invalid-code` | Wrong answer, attempts remain | A re-issued interim token |
| `login.error.2fa.attempts-exhausted` | Wrong answer, no attempts left | None — restart at pass 1 |
| `login.error.2fa.expired` | The challenge lapsed | None — restart at pass 1 |
| `login.error.2fa.no-challenge` | No interim token was presented, or it carries none | None |
| `login.error.2fa.unsupported-mechanism` | No adaptor registered for the mechanism | None |
| `login.error.2fa.not-enrolled` | TOTP: no secret resolves for this principal | None |

A wrong code is an ordinary outcome and yields a failed
`TomAuthenticationResult`. A *mis-wired deployment* — a duplicate adaptor, an
annotated class that cannot be instantiated or does not implement
`Tom2FAService` — is a `Tom2FAException` instead, raised at registration with
`clientThrow: false` so it surfaces in the server log rather than to a caller.

**What the attempt counter does and does not bound.** The counter lives in the
token and advances only along the chain of re-issued tokens. A stateless server
holds no record of which interim tokens it has already answered, so it cannot
tell a replay of an *earlier* token in the chain from its original presentation
— and that earlier token is still valid and still carries its lower count. The
counter therefore bounds a cooperative client (and gives a UI its "2 tries
left"); what bounds an uncooperative one is the challenge's short validity,
after which every token in the chain is refused. A deployment needing a hard
per-challenge cap must add the server-side state this flow deliberately omits
(a spent-token denylist or a per-user counter), or rely on the mechanism's own
rate limiting.

## Core Components

### `TomAuthenticationServer`

The orchestrator. `authenticateGuest` and `authenticatePass1` run the flow
above (guest vs. user service); `authenticatePass2` completes a second-factor
login against the challenge the interim token carries. The three static settings
select the services and JWT issuer process-wide.

### `TomAuthenticationService` / `TomAuthenticationInfo`

The contract you implement and the value it returns. `authenticateUser` either
returns a `TomAuthenticationInfo` (the `TomPrincipal` plus its
`TomAccessControlDefinition`) or throws a `LoginException`.

### `TomAuthenticationData`

A mutable carrier for one attempt; the server builds it from the wire message.

### `Tom2FAService` / `Tom2FARegistry`

The second-factor contract and the map from mechanism `type` to the adaptor
implementing it. `Tom2FARegistry` scans `@Tom2FAAdaptor`-annotated classes the
first time it is consulted; `register` / `lookup` / `registeredTypes` /
`registerAnnotated` drive it explicitly. See
[Two-Factor Authentication](#two-factor-authentication).

### `TomTotp2FAService`

The shipped RFC 6238 authenticator-app mechanism, registered under `'totp'`.
Its statics configure digits, period, clock-skew window, attempts and challenge
validity; `globalSettingSecretResolver` — unset by default — says where a user's
base32 secret lives.

### Adaptor annotations

`TomAuthenticationAdaptor` (with `guestOnly` / `userOnly`) and `Tom2FAAdaptor`
(with `type`) are reflection-discoverable markers a runtime enumerates to route
logins; `Tom2FARegistry` is the consumer of the latter. Changing their shape
requires regenerating reflection.

## Status and Limitations

- **`TomDummyAuthenticationService` is for scaffolding only** — it grants any
  non-`GUEST` login. Replace it before any test or production use.
- **One second-factor mechanism ships**: `TomTotp2FAService` (authenticator
  app). SMS, email and WebAuthn are application-supplied — the mechanism set is
  deliberately outside the framework, and adding one needs no change here (see
  [Writing your own mechanism](#writing-your-own-mechanism)).
- **The attempt counter is not a brute-force defence on its own.** It bounds a
  cooperative client; the challenge's short validity is what bounds an
  uncooperative one. A deployment needing a hard per-challenge cap must add the
  server-side state stateless verification omits.

## Dependencies

- **`tom_core_kernel`**: `TomPrincipal`, `TomAccessControlDefinition`,
  `TomBearerAuthentication`, `TomServerJwtToken`, the 2FA wire types
  `Tom2FAChallenge` / `Tom2FAClaims`, the `TomTotp` derivation primitives, and
  the wire types `TomAuthenticationMessage` / `TomAuthenticationResult`.
- **Little Things** (this package): `TomServerException`, the base of
  `LoginException` and `Tom2FAException`.
