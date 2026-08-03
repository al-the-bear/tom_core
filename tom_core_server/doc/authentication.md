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
- [Server Self-Login](#server-self-login)
- [External Identity (OAuth 2.0 / OIDC)](#external-identity-oauth-20--oidc)
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
| `TomDeliveredCode2FAService` | abstract | The shape every *delivered* code shares: generate, seal, send, recognise, and prove the destination by enrolment |
| `TomEmailCode2FAService` | class (`@Tom2FAAdaptor('email')`) | A one-time code mailed through the Messaging module |
| `TomSmsCode2FAService` | class (`@Tom2FAAdaptor('sms')`) | A one-time code texted through the Messaging module |
| `Tom2FAException` | exception | A mis-wired 2FA deployment; never client-facing |
| `TomServerSelfLogin` | class (statics only) | Logs the deployment in as itself and installs its principal |
| `TomServiceCredential` | class | The deployment's own credential and where to present it |
| `TomServiceLoginTransport` | abstract | The one JSON POST behind the self-login, so it is swappable and testable |
| `TomHttpServiceLoginTransport` | class | The default transport, over `TomServerChannel` without bearer auth |
| `TomServiceLoginResponse` | class | A raw status + body from that transport |
| `TomServerSelfLoginException` | exception | A *configured* deployment that could not log itself in; never client-facing |
| `TomOAuthAuthenticationService` | class | A `TomAuthenticationService` that authenticates an authorization code |
| `TomOAuthCredential` | class | The code + state pair carried in `TomAuthenticationData.key` |
| `TomExternalIdentityDirectory` | abstract | What the deployment supplies: local account lookup and first-login provisioning |
| `TomOAuthProviderConfig` | class | One provider, as data: endpoints, client credentials, claim names, provisioning |
| `TomOAuthProviders` | class | The configured provider set, read from `oauth.providers` |
| `TomOAuthProvisioning` | enum | What a first external login with no local account does: `refuse` or `autoProvision` |
| `TomOAuthFlow` | class | The authorization-code + PKCE handshake |
| `TomOAuthPkce` | class | A verifier / `S256` challenge pair |
| `TomOAuthAuthorizationState` | class | One pending authorization: state handle, verifier, and the login context it started in |
| `TomOAuthStateStore` | abstract | Where pending authorizations live; `TomOAuthMemoryStateStore` is the default |
| `TomOAuthTokenTransport` | abstract | The provider HTTP calls, so a test can stub the provider |
| `TomExternalIdentity` | class | What the provider asserted: issuer, subject, username, display name, raw claims |
| `TomExternalIdentityStore` | abstract | The linking table: (issuer, subject) → local account |
| `TomExternalIdentityLink` | entity (`@tomReflector`) | One persisted link row |
| `TomOAuthServer` | class (`@TomApiImplementation`) | The three `/oauth/*` endpoints |
| `TomOAuthException` | exception | A mis-configured provider set or a refused handshake |

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
Tom2FARegistry.register('webauthn', MyWebAuthnService());
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

For the mailed and texted codes there is no resolver to set: the destination is
already on the user record, and what a deployment supplies instead is the
message the code arrives in — see
[Codes delivered by email or SMS](#codes-delivered-by-email-or-sms).

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

### Codes delivered by email or SMS

Two mechanisms ship alongside TOTP: `TomEmailCode2FAService` (`'email'`) and
`TomSmsCode2FAService` (`'sms'`). Both send a one-time numeric code to an
address the user already controls, and both are thin skins over
`TomDeliveredCode2FAService` — code generation, sealing, the constant-time
compare, destination masking, the enrolment round trip and the delivery-failure
rule live there once. A subclass supplies only its channel.

**Wiring.** Install the messaging service the adaptor will use, and write the
templates. Nothing else:

```dart
TomBean.withType(TomEmailService, TomEmailService(outbox: outbox, texts: texts));
TomBean.withType(TomSmsService, TomSmsService(outbox: outbox, texts: texts));
```

```yaml
# The four templates, resource-keyed like all user-facing text (G-RES-1).
email.two_factor_code.subject: "Your {application} sign-in code"
email.two_factor_code.text: "Your code is {code}. It expires in {minutes} minutes."
email.two_factor_enrolment.subject: "Confirm this address"
email.two_factor_enrolment.text: "Enter {code} to confirm this address."
sms.two_factor_code.text: "{code} is your {application} code."
sms.two_factor_enrolment.text: "Enter {code} to confirm this number."
```

Every template is rendered with `code`, `minutes`, `username`, `firstname`,
`lastname` and `application` in scope, whether or not it mentions them — an
unreferenced parameter costs nothing, while a template that wants `{firstname}`
and finds no parameter renders the placeholder.

**Where the destination comes from.** A *confirmed* enrolment first, then the
user record — `TomUser.email` for mail, `TomUser.mobile` then `TomUser.phone`
for SMS. The ordering is the point: an attacker who can edit a profile field
must not thereby redirect the second factor, so a proven address outranks an
asserted one. A user with neither fails the challenge with
`login.error.2fa.not-enrolled` rather than being silently let through.

**What travels where.** This is the mechanism the encrypted split exists for:

| Blob | Contents | Who reads it |
| ---- | -------- | ------------ |
| `clientData` (public claims) | the **masked** destination (`a***e@example.com`, `+*******4567`) and the code's length | the client's UI, to prompt |
| `verificationData` (encrypted claims) | a 16-byte random **salt** and the SHA-256 of `salt + code` | pass 2, to compare |

The code itself appears in neither. It exists in memory long enough to be sent
and is never written down, so the interim token the client carries while typing
cannot be made to yield the answer — not by reading it, and not by decrypting
it, since what is inside is a salted hash and not the code.

**A code that was not sent is not a challenge.** Delivery happens *before* the
challenge spec is built, and synchronously — through
`TomTemplatedMessageService.deliverNow`, which reports the transport's own
outcome, rather than through the outbox. That is a deliberate exception to
"everything goes through the outbox": a one-time code expires with the
challenge, so the outbox's retry budget outlives the message's usefulness and
would only hide that the first attempt failed. A user staring at a prompt for a
code that is never coming cannot tell that from a slow relay, so a failed
delivery fails the login with `login.error.2fa.delivery-failed`. The retry this
message actually wants is the user pressing *resend*, which issues a fresh
challenge with a fresh code.

A missing messaging service is a different fault and reports as one: it raises
`Tom2FAException` (`authentication.2fa.email.no_service` /
`…sms.no_service`), which passes through the delivery wrapper unchanged so that
whoever is on call is not sent to the logs of a relay that was never asked.

**Enrolment is proof of control.** Both adaptors implement
`Tom2FAEnrolmentSupport`. There is no secret to hand over here, so enrolment
sends a code to the destination *on record* and refuses to yield a
`Tom2FAEnrolment` until it comes back — `confirmEnrolment` throws
`login.error.2fa.enrolment-code-invalid` rather than returning something
nullable, so a caller cannot store an unproven address by forgetting a check.
The confirmed destination is stored under a stable `enrolmentId` (the mechanism
type), which makes re-confirmation an upsert — what changing your phone number
should do.

**Tuning.** Static settings, per adaptor: `globalSettingCodeDigits` (6),
`globalSettingAttemptsAllowed` (3), `globalSettingChallengeValidity`
(10 minutes for mail, 5 for SMS — a mail may be greylisted; a text is not),
`globalSettingChallengeTemplateKey` / `globalSettingEnrolmentTemplateKey`,
`globalSettingEnrolmentAttemptsAllowed` and `globalSettingEnrolmentValidity`.

### Writing your own mechanism

For another *delivered* channel — a push notification, a voice call — extend
`TomDeliveredCode2FAService` and supply the four things that differ:

```dart
@tomReflector
@Tom2FAAdaptor('push')
class MyPushCode2FAService extends TomDeliveredCode2FAService {
  @override
  String get type => 'push';

  // From your own store, not TomUser.attributes — those are projected into the
  // token's public claims.
  @override
  String? destinationOnRecord(Tom2FAContext context) =>
      deviceTokens[context.principal.username];

  @override
  String maskDestination(String destination) => '***${destination.substring(
        destination.length - 4,
      )}';

  @override
  Future<void> deliver(
    Tom2FAContext context, {
    required String destination,
    required String code,
    required String templateKey,
    required Duration validity,
  }) =>
      // Throws if the gateway refuses — which is what makes the challenge fail
      // instead of a code silently never arriving.
      myPushGateway.send(
        destination,
        text: myTexts.text(
          '$templateKey.text',
          locale: localeFor(context),
          parameters: templateParameters(
            context,
            code: code,
            validity: validity,
          ),
        ),
      );
  // ... plus the seven getters naming digits, attempts, validity and templates.
}
```

The salted seal, the constant-time compare, the enrolment round trip and the
delivery-failure rule all come with the base — which is the point of extending
it rather than reimplementing them.

For a mechanism that is *not* a delivered code — a hardware key, a push
approval the user taps rather than reads — implement `Tom2FAService` directly:

```dart
@tomReflector
@Tom2FAAdaptor('webauthn')
class MyWebAuthnService implements Tom2FAService {
  @override
  Tom2FAMethodDescriptor get descriptor =>
      Tom2FAMethodDescriptor.scoped('webauthn'); // two_factor.webauthn.*

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    final nonce = _randomNonce();
    return Tom2FAChallengeSpec(
      hint: _credentialLabel(context.principal),
      clientData: {'challenge': nonce},   // public; the browser signs it
      verificationData: {'challenge': nonce}, // encrypted; server-only
      validity: const Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async => _verifySignature(
        context.principal,
        signature: submission.submitted,
        expectedChallenge: submission.verificationData['challenge'] as String,
      );
}
```

Three rules make the rest of the flow work:

- **A descriptor names the mechanism in resource keys, never in literal text.**
  `Tom2FAMethodDescriptor.scoped('webauthn')` points at
  `two_factor.webauthn.name` / `.description` / `.icon`, which is what an
  enrolment picker renders.
- **The two blobs are yours; the framework never looks inside either.**
  `clientData` travels in the token's **public** claims, for your own client
  UI. `verificationData` travels in the **encrypted** section, for your own
  `verifySubmission`. Anything a client must not see goes in the second one —
  and if a client could compute the answer from what you put in the first one,
  the mechanism is broken.
- **Adaptors must be stateless between the two calls.** Pass 1 and pass 2 may
  run in different isolates or on different server instances. Anything you need
  to remember belongs in `verificationData`; a field on the adaptor will not be
  there. The two shipped families sit at the ends of that range:
  `TomTotp2FAService` stores nothing at all, re-resolving the secret on pass 2
  so it never travels, while `TomDeliveredCode2FAService` has nothing to
  re-derive from and therefore stores a salted hash of the code — which is what
  `verificationData` was designed for.

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
| `login.error.2fa.not-enrolled` | Nothing to challenge against: no TOTP secret resolves, or no address is on record for a delivered code | None |
| `login.error.2fa.delivery-failed` | A delivered code could not be handed to its transport, so no challenge was issued | None |
| `login.error.2fa.no-destination` | Enrolment was begun for a delivered code with no address on record to confirm | None |
| `login.error.2fa.enrolment-code-invalid` | The confirmation code did not match the one just sent; nothing is stored | None |
| `login.error.2fa.enrolment-offer-invalid` | The enrolment offer carried no destination and cannot be completed | None |

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

## Server Self-Login

Everything above is about authenticating a *user*. A deployment authenticates
too — as **itself**, once, at startup.

### Why a server logs in

A deployed server is a principal like any other client. It presents a service
credential, receives a token pair, and that token reconstructs a `TomPrincipal`
whose entitlements are **the feature grants of this deployment**. Those grants
then cap every user's grants: every access decision in the framework resolves to
`min(user grade, deployment grade)`, so a feature this deployment is not
licensed for is refused no matter what the user holds.

That is the whole point of the exercise — a per-deployment feature ceiling that
no user grant, and no bug in a user grant, can exceed. The kernel side of it is
`TomServerPrincipal` and the meet; see `tom_core_kernel`'s
`doc/security/security.md` §"The Server Principal and the Meet" for how the two
operands combine.

### The credential

`TomServiceCredential` is what the deployment presents. It is built from the
server configuration by `TomServiceCredential.fromConfiguration`:

| Configuration field | Required | Purpose |
| ------------------- | -------- | ------- |
| `authServerLoginUri` | **yes** | Absolute URI of the auth server's login endpoint, e.g. `https://auth.example.com/auth/login` |
| `serviceAccountName` | **yes** | The service account's login name |
| `serviceAccountCredential` | **yes** | The service account's secret |
| `serviceAccountOrganization` | no | Multi-tenant context; omit when single-tenant |
| `serviceAccountApplication` | no | Application the deployment logs into |
| `serviceAccountProcess` | no | Process (sub-context of the application) |
| `serviceAccountClient` | no | Client identifier the login originates from |

`serviceAccountCredential` is **secret-bearing**. Its *declaration* lives in the
configuration class so the shape and source key are known; its **value is never
authored**. Supply it out-of-band at deploy time through the ordinary
configuration precedence chain — OS environment, `.env`, or command line — and
never write it into a spec or a checked-in configuration tree. The same rule
governs the JWT keys. `TomServiceCredential.toString()` redacts it, and the
request body is built by hand rather than through reflection so the secret never
passes through a general-purpose serialiser that might log or cache it.

### Lifecycle

```dart
// During application startup, before TomServer.start() binds the socket:
final installed = await TomServerSelfLogin.loginAndInstall(configuration);
```

`TomServer` already does this for you in `_installServerPrincipal`, and the
**ordering is load-bearing**: the login runs *before* the socket is bound.
Binding first would open a window in which requests are served uncapped — the
one direction in which getting it wrong grants access rather than denying it.

The three outcomes are deliberately not symmetric:

| Situation | Result | Rationale |
| --------- | ------ | --------- |
| Not configured (any required field absent, blank, or an unparseable URI) | Returns `false`, installs nothing, logs at **info** | The supported default. Every server built before server self-login existed keeps working byte-for-byte, running uncapped. |
| Configured, login succeeds | Returns `true`, installs the principal, logs at **info** | Deployment grants now cap user grants. |
| Configured, login fails | Throws `TomServerSelfLoginException`; `TomServer` logs it and **refuses to bind the socket** | An operator asked to be capped. Degrading to uncapped would silently *widen* access — so a misconfiguration must be seen, not absorbed. |

A *partially* configured deployment counts as unconfigured, on purpose: half a
credential cannot authenticate, and failing startup over a value the operator
may be mid-way through rolling out is worse than running uncapped. The info-level
log is what makes the state visible.

A long-running deployment re-authenticates before its service token expires and
calls `TomServerPrincipal.install` again — that is intended. Note the direction
of `TomServerPrincipal.clear()`: it *widens* access, so it is never the right
response to an expired token.

### Failure keys

`TomServerSelfLoginException` carries `clientThrow: false` — it is an operator
signal, never surfaced to a client.

| Key | Meaning |
| --- | ------- |
| `server.selflogin.unreachable` | The auth server could not be reached. |
| `server.selflogin.rejected` | The auth server refused the credential. Only the HTTP status is reported — the body may echo the credential back. |
| `server.selflogin.bad_response` | The response was not JSON, or was JSON that is not an object. |
| `server.selflogin.no_token` | The response carried no token under any accepted name. |
| `server.selflogin.bad_token` | The token could not be turned into a principal. |

The response is read for `authenticationToken`/`authToken` and
`authorizationToken`/`authzToken` — both spellings, because both are in the
field: the kernel's `TomAuthenticationResult` serialises the long names while
application login DTOs commonly shorten them. When only one token is present it
serves both roles. Nothing is guessed; the names are unambiguous.

### Swapping the transport

The login is one JSON POST, held behind `TomServiceLoginTransport`:

```dart
class MyLoginTransport extends TomServiceLoginTransport {
  const MyLoginTransport();

  @override
  Future<TomServiceLoginResponse> postJson(Uri uri, String body) async {
    // ... your call ...
    return const TomServiceLoginResponse(200, '{"authToken": "..."}');
  }
}

await TomServerSelfLogin.loginAndInstall(
  configuration,
  transport: const MyLoginTransport(),
);
```

Two things this buys: the credential handling, response parsing and principal
reconstruction are testable without a live auth server, and a deployment whose
auth server speaks a different dialect swaps one HTTP call instead of
reimplementing the flow. The default `TomHttpServiceLoginTransport` posts
through `TomServerChannel` with bearer authentication explicitly disabled —
there is no token yet to present.

`decryptTokens` (default `true`) controls whether the authorization token's
encrypted section is unwrapped locally. It must stay `true` for a deployment
whose entitlements travel in the encrypted claims, which is the normal case for
a server holding the RSA private key.

## External Identity (OAuth 2.0 / OIDC)

"Sign in with …" is **not a second login path.** It is one more implementation
of the contract every login already goes through, and everything below follows
from that single decision.

### The shape

`TomOAuthAuthenticationService` implements `TomAuthenticationService`. It
receives a `TomOAuthCredential` (authorization code + state) in
`TomAuthenticationData.key` — the slot a password login fills with a password,
typed `Object?` for exactly this reason — exchanges it with the provider,
resolves the local account, and returns an ordinary `TomAuthenticationInfo`.

Then it stops. It issues no token, consults no 2FA policy and makes no session
decision, because `TomAuthenticationServer.authenticateExternal` hands its
result to the same `_completeLogin` a password login reaches:

```text
POST /oauth/authorize        →  TomOAuthFlow.beginAuthorization
        │                        stores the pending state + PKCE verifier
        ▼
   (browser visits the provider, user consents, provider redirects back)
        │
GET  /oauth/callback?code&state
        │
        ▼
TomAuthenticationServer.authenticateExternal
        │  builds TomAuthenticationData with a TomOAuthCredential as the key
        ▼
TomOAuthAuthenticationService.authenticateUser
        │  code exchange → claims → linking table → TomAuthenticationInfo
        ▼
_completeLogin  ← the *same* continuation a password login reaches
        │
        ├── Tom2FAPolicy says a second factor is owed → challenge / enrolment
        └── otherwise → _issueTokens
```

An externally-authenticated principal is therefore challenged for its second
factor, offered enrolment, and issued exactly the claims a password login would
have produced — not because this module reproduces those rules, but because it
never touches them. `oauth_test.dart` asserts the parity claim-by-claim rather
than describing it.

### Wiring it up

A deployment installs *one* authentication service, so enabling external login
must not mean disabling passwords. The service takes the existing one as a
`delegate` and passes any non-`TomOAuthCredential` straight through:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService =
    TomOAuthAuthenticationService(
      directory: MyExternalIdentityDirectory(),
      delegate: TomAuthenticationServer.globalSettingUserAuthenticationService,
    );

TomBean.withType(TomOAuthProviders, TomOAuthProviders.fromConfiguration());
TomBean.withType(
  TomExternalIdentityStore,
  TomPersistentExternalIdentityStore(TomExternalIdentityLinkRepository()),
);
```

An account may hold a password *and* several external identities at once.

### Provider configuration is data

Providers are read from the ordinary configuration tree under `oauth.providers`
— no new configuration module, and `${...}` env-var substitution already applies
because `yaml_resources` performs it:

```yaml
oauth:
  providers:
    google:
      issuer: https://accounts.google.com
      authorizationEndpoint: https://accounts.google.com/o/oauth2/v2/auth
      tokenEndpoint: https://oauth2.googleapis.com/token
      clientId: 1234.apps.googleusercontent.com
      clientSecret: ${GOOGLE_CLIENT_SECRET}
      redirectUri: https://app.example.com/oauth/callback
      scopes: openid email profile      # a list or a space-separated string
      provisioning: autoProvision       # or: refuse (the default)
    github:
      issuer: https://github.com
      authorizationEndpoint: https://github.com/login/oauth/authorize
      tokenEndpoint: https://github.com/login/oauth/access_token
      userInfoEndpoint: https://api.github.com/user
      clientId: Iv1.abc
      clientSecret: ${GITHUB_CLIENT_SECRET}
      redirectUri: https://app.example.com/oauth/callback
      subjectClaim: id                  # non-OIDC providers name them differently
      usernameClaim: login
      usePkce: false
```

Every *required* value is demanded rather than defaulted: a provider missing its
token endpoint is a configuration error, and one that must fail at startup
rather than as a failed login weeks later. An absent `oauth:` block is not an
error — it is the majority case, and yields an empty provider set.

`TomOAuthProviders.fromConfiguration()` reads it; the endpoints resolve the
installed bean, so a deployment that installs nothing offers nothing.

### First login with no local account: `refuse` or `autoProvision`

This is a **configuration choice per provider**, never a hardcoded policy,
because the two answers are both correct for different deployments:

| `provisioning` | A first external login with no linked account |
| -------------- | --------------------------------------------- |
| `refuse` (default) | Rejected with `login.error.oauth.no-local-account`. The right answer for an enterprise deployment where accounts are created by an administrator. |
| `autoProvision` | `TomExternalIdentityDirectory.provisionFromExternalIdentity` creates the account, and the link is written to the username the *directory* settled on — not to the asserted claim, which a deployment may normalise, prefix or de-duplicate. |

`autoProvision` additionally **links an existing local account** that already
carries the asserted username, which is how a user who signed up with a password
later adds "Sign in with …". That behaviour is deliberately gated on
`autoProvision`: on a provider configured to `refuse`, an unlinked local account
under the asserted name is precisely the case being refused — an attacker who
can make *any* provider assert an address must not thereby acquire the local
account that already uses it.

The default `provisionFromExternalIdentity` throws
`login.error.oauth.provisioning-unsupported`, so a deployment that turns
auto-provisioning on without implementing it gets a clear error rather than a
silently half-created account.

### The linking table

`(issuer, subject)` → local username, unique on the pair and indexed on the
account, so one account may hold several external identities:

```dart
abstract class TomExternalIdentityStore {
  Future<String?> localUsernameFor(TomExternalIdentity identity);
  Future<void> link(TomExternalIdentity identity, String localUsername);
  Future<void> recordLogin(TomExternalIdentity identity);
  Future<List<TomExternalIdentityLink>> identitiesOf(String localUsername);
}
```

Keyed on the pair rather than on the subject alone because a subject is only
unique *within* an issuer — two providers may both call a user `12345`.

`TomPersistentExternalIdentityStore` is the production implementation over
`TomExternalIdentityLinkRepository`; `TomMemoryExternalIdentityStore` exists for
tests. There is no in-memory *default*: a link that vanishes on restart sends a
returning user through provisioning again, so a deployment that installs no
store is told what is missing rather than given a store that loses its rows.

A link pointing at an account that no longer exists **refuses** the login rather
than provisioning a replacement — recreating a deleted account from a stale row
is exactly the state an administrator was trying to reach when they deleted it.

### The handshake

`TomOAuthFlow` implements authorization code + PKCE (`S256`). What it verifies,
and why each check is not optional:

| Check | Failure key |
| ----- | ----------- |
| The `state` was issued by this server, has not expired, and has not been used | `oauth.flow.unknown_state` |
| The redirect carried an authorization code | `oauth.flow.missing_code` |
| The code exchange presents the verifier the challenge was derived from | (the provider rejects the exchange) |
| The claims carry `iss` equal to the configured issuer | `oauth.flow.issuer_mismatch` |
| The claims carry `aud` containing the configured client id | `oauth.flow.audience_mismatch` |
| The claims carry a subject | `oauth.flow.missing_subject` |

An unknown, expired and already-spent state are deliberately **indistinguishable
to a caller**: telling them apart tells an attacker whether a handle was ever
valid.

The `id_token` signature is **not** checked, and that is a deliberate limitation
rather than an oversight — see [Status and Limitations](#status-and-limitations).

Providers that predate OIDC return no `id_token`; for those, configure
`userInfoEndpoint` and the flow fetches the claims with the access token
instead. A provider with neither fails clearly rather than producing an
anonymous identity.

`TomOAuthTokenTransport` is the one HTTP seam. Stubbing it — which is all
`oauth_test.dart` does — leaves every other line of the flow executing exactly
as it does against a real provider.

### The endpoints

Three, declared as an ordinary typed contract (`tomOAuthApi` in the kernel) and
implemented by `TomOAuthServer`. All three are public: there is no caller to
authenticate — that is the point of logging in — and the unguessable `state`
handle is what ties a callback to an authorization this server started.

| Method | URI | Purpose |
| ------ | --- | ------- |
| `GET` | `/oauth/providers` | The configured providers as resource keys only — no endpoint, client id or secret reaches a client |
| `POST` | `/oauth/authorize` | Begins an authorization; returns the provider URL to send the browser to, and the `state` handle |
| `GET` | `/oauth/callback` | Where the provider redirects back; completes the login |

The callback is a `GET` with query parameters because that is what a browser
redirect is; its `code` / `state` / `error` / `error_description` parameters bind
into the typed DTO through the endpoint's `urlParameterMapping`, the same
declaration path parameters already used.

`registerFrameworkApis()` registers the contract, so a router resolves it
without the application registering anything.

### Failure keys

| Key | Meaning |
| --- | ------- |
| `oauth.config.missing_value` · `oauth.config.not_a_map` · `oauth.config.provider_not_a_map` · `oauth.config.unknown_provisioning` | The `oauth.providers` block is malformed. Startup-time. |
| `oauth.config.unknown_provider` | A request named a provider that is not configured. |
| `oauth.callback.unknown_state` · `oauth.flow.unknown_state` | The state handle is unknown, expired, or already used — raised by the endpoint and by the flow respectively. |
| `oauth.callback.provider_error` | The provider itself refused (e.g. the user pressed cancel). |
| `oauth.flow.missing_code` · `oauth.flow.token_exchange_rejected` | The redirect carried no code, or the token endpoint refused the exchange. |
| `oauth.flow.issuer_mismatch` · `oauth.flow.audience_mismatch` · `oauth.flow.missing_subject` · `oauth.flow.malformed_id_token` | The claims failed verification. |
| `oauth.flow.no_claims_source` · `oauth.flow.no_access_token` | The provider returned neither an `id_token` nor a usable `userInfoEndpoint` call. |
| `oauth.provider.http_error` · `oauth.provider.malformed_json` | The provider's HTTP call failed or answered with something that is not a JSON object. |
| `login.error.oauth.no-local-account` | Authenticated, but unlinked, and the provider is configured to refuse. |
| `login.error.oauth.linked-account-missing` | The link outlived the account it pointed at. |
| `login.error.oauth.provisioning-unsupported` | `autoProvision` is configured but the directory does not implement it. |
| `login.error.oauth.no-identity-store` | No `TomExternalIdentityStore` is installed. |
| `login.error.oauth.unknown-issuer` | The token's issuer matches no configured provider. |
| `login.error.oauth.credential-not-supported` | A non-OAuth credential arrived and there is no `delegate`. |

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

### `TomDeliveredCode2FAService`

The shape every second factor that *sends* a code shares: generate a code from
the framework's CSPRNG (rejection-sampled, so no modulo bias), seal it as a
salt plus a SHA-256 into `verificationData`, deliver it synchronously, and
recognise it again with a constant-time compare. It also implements
`Tom2FAEnrolmentSupport`, where enrolment means proving the user can read what
is sent to the destination. A subclass supplies four things: `type`,
`destinationOnRecord`, `maskDestination` and `deliver`. The statics
`generateNumericCode`, `sealCode`, `matchesSealedCode` and `constantTimeEquals`
are public because two adaptors and their tests use them.

### `TomEmailCode2FAService` / `TomSmsCode2FAService`

The two shipped delivered-code mechanisms, registered under `'email'` and
`'sms'`. They resolve `TomEmailService` / `TomSmsService` from the bean locator
at call time and render `email.two_factor_code.*` / `sms.two_factor_code.*`
(and the matching `…_enrolment` templates). A missing service is a
`Tom2FAException`, not a delivery failure. See
[Codes delivered by email or SMS](#codes-delivered-by-email-or-sms).

### Adaptor annotations

`TomAuthenticationAdaptor` (with `guestOnly` / `userOnly`) and `Tom2FAAdaptor`
(with `type`) are reflection-discoverable markers a runtime enumerates to route
logins; `Tom2FARegistry` is the consumer of the latter. Changing their shape
requires regenerating reflection.

### `TomServerSelfLogin` / `TomServiceCredential`

The deployment's own login. `logIn` performs it and returns the principal;
`loginAndInstall` reads the credential from the server configuration, performs
it, and installs the result into the kernel's `TomServerPrincipal` — returning
`false` when the deployment configured no credential. See
[Server Self-Login](#server-self-login).

### `TomOAuthAuthenticationService` / `TomExternalIdentityDirectory`

The service is a `TomAuthenticationService` that authenticates a
`TomOAuthCredential` and delegates everything else. The directory is the half
the framework deliberately does not own — the framework has no user table, so
resolving "`alice@example.com` at `accounts.google.com`" to a local principal,
and deciding whether to create one, are both the deployment's.

### `TomOAuthProviders` / `TomOAuthProviderConfig` / `TomOAuthProvisioning`

Provider configuration as data, read from `oauth.providers`.
`TomOAuthProvisioning` is the per-provider first-login choice.

### `TomOAuthFlow` / `TomOAuthPkce` / `TomOAuthStateStore` / `TomOAuthTokenTransport`

The handshake, the verifier/challenge pair, the pending-authorization records,
and the one HTTP seam a stub provider replaces.

### `TomExternalIdentityStore` / `TomExternalIdentityLink`

The linking table. `TomPersistentExternalIdentityStore` for production,
`TomMemoryExternalIdentityStore` for tests, and no default — see
[The linking table](#the-linking-table).

### `TomOAuthServer`

The `/oauth/*` endpoints. It carries no login logic of its own: the callback
resolves the pending record for its context and calls
`TomAuthenticationServer.authenticateExternal`.

## Status and Limitations

- **`TomDummyAuthenticationService` is for scaffolding only** — it grants any
  non-`GUEST` login. Replace it before any test or production use.
- **Three second-factor mechanisms ship**: `TomTotp2FAService` (authenticator
  app), `TomEmailCode2FAService` and `TomSmsCode2FAService` (delivered codes).
  WebAuthn and anything else remain application-supplied — the mechanism set is
  open by design, and adding one needs no change here (see
  [Writing your own mechanism](#writing-your-own-mechanism)).
- **A delivered code's transport is not retried.** Delivery is synchronous and
  a failure fails the login, because a code that outlives its challenge is worse
  than none. The retry is the user asking for a new code. A deployment whose
  relay is unreliable therefore sees failed logins rather than late ones — which
  is the intended trade, not an oversight.
- **The attempt counter is not a brute-force defence on its own.** It bounds a
  cooperative client; the challenge's short validity is what bounds an
  uncooperative one. A deployment needing a hard per-challenge cap must add the
  server-side state stateless verification omits.
- **The OAuth `id_token` signature is not verified.** The token is read for its
  claims only. This is safe *as deployed here* and unsafe if copied elsewhere:
  the token arrives over TLS on the server's own back-channel call to the
  configured token endpoint, presenting the client secret and the PKCE verifier,
  so an attacker who could substitute it has already broken the transport. It is
  **not** safe for an implicit flow or for any token that arrived by way of the
  browser, neither of which this module performs. Adding JWKS fetching and
  signature verification is the natural next step for a deployment that wants
  defence in depth.
- **`TomOAuthMemoryStateStore` is the default state store, and is per-process.**
  Pending authorizations live for ten minutes in one isolate's memory, which is
  correct for a single-node deployment and wrong behind a load balancer that may
  route the callback to a different node. A clustered deployment installs a
  shared `TomOAuthStateStore`; the contract is three methods.
- **The identity *store* has no default at all**, deliberately — see
  [The linking table](#the-linking-table).
- **Token refresh is not implemented.** The provider's access token is used once
  to fetch claims and then discarded; the session is the framework's own JWT
  pair. A deployment that needs to call the provider's API *on behalf of the
  user* later must retain and refresh that token itself.

## Dependencies

- **`tom_core_kernel`**: `TomPrincipal`, `TomAccessControlDefinition`,
  `TomBearerAuthentication`, `TomServerJwtToken`, the 2FA wire types
  `Tom2FAChallenge` / `Tom2FAClaims`, the `TomTotp` derivation primitives,
  `TomServerPrincipal` (the holder server self-login installs into), and the
  wire types `TomAuthenticationMessage` / `TomAuthenticationResult`.
- **Configuration** (this package): `TomBaseServerConfiguration` supplies the
  service-account fields `TomServiceCredential.fromConfiguration` reads.
- **Server** (this package): `TomServerChannel` carries the default self-login
  transport, and `TomServer` calls `loginAndInstall` before binding its socket.
- **Messaging** (this package): `TomEmailService` and `TomSmsService` deliver
  the one-time codes, through `TomTemplatedMessageService.deliverNow` rather
  than the outbox. A deployment that registers neither can still run TOTP.
- **Resources** (this package): `TomLocalizedTextResources` renders every
  delivered message and every mechanism name — no user-facing text originates
  in this module.
- **Little Things** (this package): `TomServerException`, the base of
  `LoginException`, `Tom2FAException`, `TomServerSelfLoginException` and
  `TomOAuthException`.
- **Endpoints** (this package): `TomOAuthServer` implements the kernel's
  `tomOAuthApi` through `@TomApiImplementation`, and `registerFrameworkApis()`
  registers the contract.
- **Object Persistence** (this package): `TomExternalIdentityLink` is an
  ordinary entity over `TomSqlDatasourceRepository`.
- **Configuration** (this package): the provider set is read through
  `TomServerConfigResourceProvider`, which already performs `${...}` env-var
  substitution.
