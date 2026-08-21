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
| `Tom2FAPrerequisite` | abstract | What an adaptor implements to say it cannot run here; the scan skips it and logs why |
| `Tom2FAContext` | class | What the adaptor is told about the login: the principal and its request context |
| `Tom2FAChallengeSpec` | class | What an adaptor returns from `issueChallenge` — hint, client blob, verification blob, attempts, validity |
| `Tom2FASubmission` | class | What an adaptor is handed on `verifySubmission` — the submitted factor plus its challenge |
| `TomTotp2FAService` | class (`@Tom2FAAdaptor('totp')`) | The shipped authenticator-app (RFC 6238 TOTP) mechanism |
| `TomDeliveredCode2FAService` | abstract | The shape every *delivered* code shares: generate, seal, send, recognise, and prove the destination by enrolment |
| `TomEmailCode2FAService` | class (`@Tom2FAAdaptor('email')`) | A one-time code mailed through the Messaging module |
| `TomSmsCode2FAService` | class (`@Tom2FAAdaptor('sms')`) | A one-time code texted through the Messaging module |
| `Tom2FAPolicy` | abstract | Decides per login whether a second factor is owed and which mechanisms may answer for it |
| `Tom2FARequirement` | enum | `disabled` / `optional` / `required` — what a policy concluded |
| `Tom2FADecision` | class | One policy answer: the requirement, the permitted mechanisms, and any grace logins |
| `TomPrincipalFlag2FAPolicy` | class (const) | The default policy: reads `requires2FA` / `twoFactorType` off the principal |
| `TomRole2FAPolicy` | class | A requirement per role; the strictest matched role wins |
| `Tom2FAGraceAccounting` | abstract | Implemented *by a policy* that wants to be told when a grace login is spent |
| `Tom2FAEnrolmentStore` | abstract | Where a principal's set-up factors live. **No default** — see [Enrolment](#enrolment) |
| `TomMemory2FAEnrolmentStore` | class | In-memory store, for tests and single-process development |
| `TomPersistent2FAEnrolmentStore` | class | Store over `TomUserTwoFactorEnrolment`, secrets encrypted at rest |
| `TomUserTwoFactorEnrolment` | entity (`@TomDbTable`) | One persisted enrolment row (`tom_user_two_factor_enrolment`) |
| `TomUserTwoFactorEnrolmentRepository` | class | The repository over that table |
| `Tom2FAEnrolment` | class | One set-up factor: type, id, hint, primary flag, and the mechanism's secret data |
| `Tom2FAEnrolmentSupport` | abstract | What an adaptor adds to become *enrollable*: begin an offer, confirm it |
| `Tom2FAEnrolmentOffer` | class | What `beginEnrolment` returns — client blob, server blob, attempts, validity |
| `Tom2FAEnrolmentState` | class | The server's view of a pending enrolment, carried in the interim token |
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
| `TomSqlOAuthStateStore` | class | A state store over `tom_oauth_state`, so every node of a cluster sees the same pending authorizations |
| `TomOAuthStateRow` | row type (`@tomReflector`) | One `tom_oauth_state` row, as the store reads it back |
| `TomOAuthStateStoreType` | enum | `memory` (the default) or `sql` — which store a deployment selected |
| `TomOAuthStateStoreSettings` | class | The `oauth.stateStore` block as data, and `createStore()` for what it names |
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

### Your service is the only source of what the principal asserts

Everything the returned principal carries is your answer, and the server
resolves none of it. That includes the part it is easy to assume the framework
fills in: `principal.cli`, the client limits — the `enabledModules` and `quotas`
the client's subscription grants. There is no subscription store in
`tom_core_server` and no environment lookup behind it. If your service does not
put the limits on the principal, the principal has none, and the tokens will say
so.

```dart
final principal = TomPrincipal(
  // ... identity, ids, locale ...
  aci: TomAccessControlInformation(roles: user.roles),
  cli: TomClientLimitsInformation(
    enabledModules: subscription.modules,   // what the client bought
    quotas: subscription.quotas,
  ),
);
```

This is deliberate rather than unfinished. The ACI says what this *user* may do
and the CLI says what this *client* has bought; both must allow an action, so
letting them be answered by two different authorities would raise the question
of which one is more current at exactly the moment it must not be asked. One
service resolves both, in one call, against one view of the account.

Two consequences worth knowing before you rely on it. The limits are a
**login-time snapshot** — they ride in the *public* half of the JWT as the
`subscription_enabledModules` / `subscription_quotas` claims and are read back
into `principal.cli` when a token is parsed, and there is no updater for them
the way `updatePrincipal` can replace the ACI, so a subscription change takes
effect on the user's next login. And because that half is public, the quota
figures are readable by anyone holding the token: they are a ceiling to enforce
against, not a secret. Nothing in the framework counts usage or refuses the
1001st call — carrying the ceiling to where the application can read it is the
whole of what the kernel does.

The single exception to "your service is the only source" is
`principal.timezone`, which the server overwrites from the user's stored
preference once the credential is accepted, because that is a server-held
preference rather than a fact about the identity being asserted.

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
primary credential exactly as above, then asks the resolved [`Tom2FAPolicy`](#the-policy-decides)
whether a factor is owed. If one is, the login does not finish there: the
adaptor registered for the mechanism **issues a challenge**, and the server
answers with an *interim* token carrying it. The client answers the challenge;
pass 2 hands the submitted factor back to the same adaptor to **verify**, and on
success re-issues the token pair without the challenge.

That final pair is byte-for-byte what a 2FA-free login would have produced for
the same user: both passes mint tokens through the one private helper
(`_issueTokens`), so the only difference between a completed pass 2 and a
single-pass login is the cleared `requires2FA` claim.

A user who owes a factor but has not set one up is not turned away. Pass 1
branches instead into an **[enrolment offer](#enrolment)**, carried by the same
interim token, and the user sets the factor up as part of the login that
demanded it. Which of the two branches a login takes is decided in one place,
and the four shapes a deployment can be in are these:

| Policy says | User has a usable factor | Pass 1 answers with |
| --- | --- | --- |
| `disabled` | — | the completed token pair, with no mention of 2FA |
| `required` / `optional` | yes | an interim token + a **challenge**, answered by pass 2 |
| `required` | no | an interim token + an **enrolment offer** |
| `optional`, or `required` with grace left | no | the same offer, additionally **declinable** |

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

### The policy decides

Whether a login owes a second factor is **a decision, not a field read**.
`TomAuthenticationServer` asks `Tom2FAPolicy.resolve().decideFor(context)` once
per login and does what the answer says.

```dart
abstract class Tom2FAPolicy {
  Future<Tom2FADecision> decideFor(Tom2FAContext context);
  static Tom2FAPolicy resolve();     // the installed bean, else the default
}
```

`resolve()` returns whatever bean is registered for `Tom2FAPolicy`, and
`TomPrincipalFlag2FAPolicy` when none is. That default reproduces the behaviour
that existed before policies did: `TomPrincipal.requires2FA` maps to `required`
or `disabled`, and `TomPrincipal.twoFactorType` names the one mechanism allowed.
A deployment that installs nothing therefore sees no change.

**What a decision says.** `Tom2FADecision` carries three things:

| Field | Meaning |
| ----- | ------- |
| `requirement` | `Tom2FARequirement.disabled`, `optional` or `required` |
| `allowedMechanisms` | The mechanism keys this login may use, in **preference order**. Unmodifiable |
| `graceLogins` | How many more times this user may decline a `required` factor. Default `0` |

and derives two more:

- `isSatisfiedWithoutFactor` — true only for `disabled`. This is the test the
  server actually makes, so a policy that means "no factor" says it once.
- `offerableMechanisms` — `allowedMechanisms` **intersected with**
  `Tom2FARegistry.registeredTypes`. Permission and availability are different
  questions: a policy states what a user *may* use, the registry states what
  this process *can* run. Intersecting them at the branch that decides the login
  is what turns a wiring fault — a policy naming `'webauthn'` in a deployment
  that registers no such adaptor — into `login.error.2fa.unsupported-mechanism`
  at the login, rather than a null adaptor ten frames further on.

  Registration carries the whole weight of "can run". That is why an adaptor
  that would need a collaborator this deployment never installed is kept *out*
  of the registry rather than registered and found wanting later — see
  [Mechanisms that need something installed](#mechanisms-that-need-something-installed).

**What each requirement does to a login with no enrolment** is the part that is
not visible from the enum:

| Requirement | Has a factor | Has none |
| ----------- | ------------ | -------- |
| `disabled` | never asked | never asked — the login completes on the primary credential |
| `optional` | challenged | offered enrolment, **declinable** at no cost |
| `required` (no grace) | challenged | offered enrolment, **not** declinable — the login cannot complete otherwise |
| `required` with `graceLogins > 0` | challenged | offered enrolment, declinable — and declining **spends one grace login** |

`optional` therefore means *offer it, but let them in either way*, which is
exactly the state the principal flags could never express: `requires2FA` is a
boolean, and a boolean cannot distinguish "may use a factor" from "must".

**`TomRole2FAPolicy`** is the shipped alternative, and states the requirement
per role rather than per user:

```dart
TomBean.withType(
  Tom2FAPolicy,
  TomRole2FAPolicy(
    requirementByRole: const {
      'admin':   Tom2FARequirement.required,
      'auditor': Tom2FARequirement.optional,
    },
    defaultRequirement: Tom2FARequirement.disabled,
    mechanisms: const [TomTotp2FAService.mechanismType],
    graceLogins: 3,
  ),
);
```

Roles are read from `context.principal.aci.roles`, and a principal holding
several **gets the strictest** of their requirements — `Tom2FARequirement`
orders `disabled < optional < required` and `strictest` folds along that order.
An unmatched principal gets `defaultRequirement`, which is `disabled` unless
stated. A `disabled` outcome returns a bare decision with no mechanisms at all,
because naming mechanisms for a login that will never be challenged only invites
a reader to think they matter.

`mechanisms` has a third state that is easy to miss:

| `mechanisms` | Means |
| ------------ | ----- |
| `null` (default) | the policy **does not restrict** the choice — every registered mechanism is permitted |
| a non-empty list | only these, in this order |
| `[]` | **no** mechanism is permitted. A `required` decision then has nothing to satisfy it and the login fails with `login.error.2fa.unsupported-mechanism` |

Neither shipped policy carries `@TomComponent`. Installing one is a deliberate
act — `TomBean.withType(Tom2FAPolicy, ...)` — because a policy that got picked
up by a component scan would silently start demanding second factors from a
deployment that only added a dependency.

**Grace accounting.** `graceLogins` is a number the *policy* supplies, so only
the policy can know how it is spent. A policy that wants to be told implements
`Tom2FAGraceAccounting` as well:

```dart
class MyPolicy implements Tom2FAPolicy, Tom2FAGraceAccounting {
  @override
  Future<void> recordGraceLoginConsumed(Tom2FAContext context) =>
      _users.decrementRemainingGraceLogins(context.principal);
  // ...
}
```

The server calls it **only at the moment grace is actually spent** — a user
declining an offer that was declinable *because* of grace — never when the offer
was merely made, and never for an `optional` decline, which costs nothing. A
policy that does not implement the interface simply grants the same grace every
time, which is a valid deployment: "warn, do not enforce yet".

### Enrolment

A user who owes a factor and has not got one is offered the chance to set one up
**inside the login that demanded it**. That needs two things, supplied by two
different parties.

**What the adaptor supplies: `Tom2FAEnrolmentSupport`.**

```dart
abstract class Tom2FAEnrolmentSupport {
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context);
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  );
}
```

It is a **separate** contract from `Tom2FAService`, not two more methods on it,
because not every mechanism can be enrolled through a login — a hardware token
an administrator provisions is set up somewhere else entirely, and widening the
base contract would force such an adaptor to carry a throw-only body. Keeping
them apart makes "can this be enrolled?" a real question, answered by an `is`
check in one place: `Tom2FARegistry.enrolmentSupportFor(type)` for one
mechanism, `Tom2FARegistry.enrollableMethods` for the whole catalog. All three
shipped mechanisms implement it.

`beginEnrolment` returns an **offer**, never a stored factor:

| `Tom2FAEnrolmentOffer` | Purpose |
| ---------------------- | ------- |
| `type` | The mechanism being set up |
| `hint` | What to show the user about the destination or device |
| `clientData` | Public — travels in the interim token's public claims. For TOTP, the secret and the `otpauth://` URI to scan |
| `enrolmentData` | Server-only — travels **encrypted**, and is what `confirmEnrolment` checks the typed answer against |
| `attemptsAllowed` | Default 3 |
| `validity` | Default 10 minutes |

`confirmEnrolment` either returns the `Tom2FAEnrolment` to store or **throws a
`LoginException`**. There is no `false` return: a wrong code and an unusable
offer are both failures, and the exception's `key` is what the client is told.

**What the deployment supplies: `Tom2FAEnrolmentStore`.**

```dart
abstract class Tom2FAEnrolmentStore {
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context);
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment);
  Future<void> remove(Tom2FAContext context, String enrolmentId);
  static Tom2FAEnrolmentStore? resolve();   // nullable — and deliberately so
}
```

`store` is an **upsert on `enrolmentId`**, so re-enrolling a mechanism replaces
the old factor rather than accumulating one per attempt; `remove` on an id that
is not there is a no-op, so a double-delete is not an error.
`Tom2FAEnrolmentStore.principalKeyOf(context)` is the one place the persistent
store derives its key from, so a store keying rows differently only has one
method to disagree with.

**That key is the principal id and nothing else — the organization is not part
of it.** A `TomPrincipal.id` names one person across the whole deployment rather
than within a tenant, so a user's second factors are theirs in every
organization they log into: enrolling an authenticator once is enough, and
`tom_user_two_factor_enrolment` accordingly has no tenant column and a unique
key of `(principal_id, enrolment_id)`. This is the premise every framework table
that files rows per principal already rests on — `tom_principal_resource_grant`
and `tom_external_identity` carry no tenant column either. A deployment that
allocates principal ids *per tenant* has broken it framework-wide and not only
here; the methods take the whole `Tom2FAContext` precisely so such a deployment
can supply a store that keys rows its own way.

Two implementations ship: `TomMemory2FAEnrolmentStore` (plus a `clear()` for
tests) and `TomPersistent2FAEnrolmentStore`, which stores rows in
`tom_user_two_factor_enrolment` through `TomUserTwoFactorEnrolmentRepository` and
**encrypts `secretData` at rest** with the JWT configuration's RSA key. A row
whose secret cannot be decrypted yields an *empty* secret map rather than
throwing, so one unreadable row costs that factor and not the whole login.

**The rule that is invisible from the signatures.** `resolve()` is nullable and
has no fallback, where `Tom2FAPolicy.resolve()` has one. That is not an
oversight — an empty fallback store would be indistinguishable from a real store
holding nothing, and the server draws exactly that distinction:

| What the store lookup yields | Means | Pass 1 does |
| ---------------------------- | ----- | ----------- |
| `null` | **No store is installed.** Nobody tracks enrolments here | Challenges the mechanism, exactly as before enrolment existed. The adaptor remains the only authority on whether the user has a factor |
| `[]` | A store **is** installed, and this user has enrolled nothing | Branches into the enrolment offer |
| a non-empty list | These are the user's factors | Challenges the primary one |

Collapsing the first two would force enrolment on every deployment that never
opted in, and offering an enrolment that could not then be saved would be a lie.
So: **installing a store changes what pass 1 means by "this user has a factor"**
— before, the question went to the mechanism; after, the store is the authority.
Migrating a deployment therefore does not have to be done all at once. A store
may report a legacy flag as one synthetic enrolment while it has nothing of its
own for that principal, which keeps already-provisioned users on the challenge
path while everyone else enrols; `TomTotp2FAService` cooperates by asking the
store for a secret first and falling back to
`globalSettingSecretResolver` only when it has none.

**The round trip.** Three passes, each answering the interim token from the one
before, and **nothing is written until a confirmation succeeds**:

```text
pass 1  → offer:   Tom2FAEnrolmentState(offeredTypes: [...], skippable: ...)
                   ─ interim token; result.requires2FAEnrolment = true
                   ─ result.availableTwoFactorMethods = the descriptors
                   ─ result.twoFactorEnrolmentSkippable
beginTwoFactorEnrolment(message..password = chosenType)
                   → support.beginEnrolment(context) → Tom2FAEnrolmentOffer
                   ─ interim token: offer.clientData public,
                     the whole offer encrypted
completeTwoFactorEnrolment(message..password = typedCode)
                   → support.confirmEnrolment(context, offer, typed)
                   → store.store(context, enrolment)   ← the first write
                   ─ the FULL token pair, with no further challenge
   or
skipTwoFactorEnrolment(message)    (only when the token says skippable)
                   ─ the full token pair; grace spent if the token says so
```

The client reads its side through the kernel:
`TomBearerAuthentication.pendingTwoFactorEnrolment` yields a
`Tom2FAPendingEnrolment`, whose `hasOffer` distinguishes the two states — *choose
a mechanism* (`offeredTypes` populated, no offer yet) from *confirm this one*
(an offer with its `clientData` and attempt counter).

Five properties of the round trip are worth stating outright, because each one
is a decision that could have gone the other way:

- **It is stateless.** The pending enrolment lives entirely in the interim
  token's claims — the offered types and the attempt counter publicly, the
  offer's server-only `enrolmentData` in the encrypted section. Any instance can
  finish what another began, and switching enrolment on adds no session store.
- **The server names what may be enrolled, not the client.**
  `beginTwoFactorEnrolment` refuses a type that was not in the offer *this token
  was issued with* (`login.error.2fa.enrolment-not-offered`), and the offer was
  built from `decision.offerableMechanisms` narrowed to those that are
  enrollable.
- **A skip must have been permitted by the server.**
  `skipTwoFactorEnrolment` refuses unless the presented — server-signed — token
  says `skippable`, so a client that decides for itself that it may decline
  achieves nothing (`login.error.2fa.enrolment-required`).
- **Confirming completes the login outright.** A user who has just derived a
  code from the secret they were handed has demonstrated possession; challenging
  them for a second code a moment later would prove nothing. A wrong code spends
  one attempt and hands the same offer back, exactly as a wrong challenge answer
  does.
- **A begun offer without a deadline is not an offer.** `enrolmentExpiresAt` is
  one of two things bounding a generated secret that is sitting in a token
  (the other is the attempt counter), so a token that announces an offer but
  carries no readable expiry is refused with
  `login.error.2fa.enrolment-offer-invalid` rather than read as unbounded. The
  cost of refusing is an enrolment the user restarts; the cost of the other
  reading is a confirmable secret with nothing left to close it. Statelessness
  is what makes the rule necessary: with no server-side record of the offer,
  the claim is the only bound there is.

The first factor a user confirms is stored with `isPrimary: true`, so the next
login has something to challenge without anyone having to nominate it.

**No store, but an offer reached anyway?** That cannot happen from pass 1 —
without a store the login is never routed to enrolment. It can happen if a store
is removed between the passes, and `completeTwoFactorEnrolment` answers
`login.error.2fa.enrolment-unavailable` rather than confirming a factor it has
nowhere to put.

### Wiring a second factor

Five steps, all of them in application code, and only the first two are
mandatory:

**1 — Say who owes a factor.** With no `Tom2FAPolicy` installed this is a per-user
flag your `TomAuthenticationService` sets on the principal, naming the one
mechanism that answers for it:

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

Install a [policy](#the-policy-decides) instead as soon as the answer is not
per-user — "everyone in role `admin`", "offer it to anyone but insist for
nobody", "insist, but allow three more logins first". The flags cannot express
any of those; a policy is one bean:

```dart
TomBean.withType(
  Tom2FAPolicy,
  TomRole2FAPolicy(
    requirementByRole: const {'admin': Tom2FARequirement.required},
    mechanisms: const [TomTotp2FAService.mechanismType],
  ),
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

"The first time it is consulted" means the first time the scan can actually
run. A registry consulted before the program's generated reflection has been
initialized logs one informational line and stays armed, so the annotated
adaptors are picked up as soon as reflection arrives rather than being written
off for the life of the process; explicitly registered adaptors resolve the
whole time.

The scan also asks each annotated candidate whether it can run *here*, and
leaves out the ones that cannot — which is why a deployment that mails codes
has to install its `TomEmailService` before the first login, not merely before
the first code. See
[Mechanisms that need something installed](#mechanisms-that-need-something-installed).

**3 — Install an enrolment store**, so users can set a factor up themselves:

```dart
TomBean.withType(
  Tom2FAEnrolmentStore,
  TomPersistent2FAEnrolmentStore(TomUserTwoFactorEnrolmentRepository()),
);
```

Skipping this step is a supported choice, not an omission: with no store the
login is only ever *challenged*, never routed to enrolment, and whether a user
has a factor stays the mechanism's own question. Read [Enrolment](#enrolment)
before installing one — it changes what pass 1 means by "this user has a
factor".

**4 — Configure the mechanism.** For the shipped TOTP adaptor, an installed
store already answers where a user's secret lives. What the resolver is still
for is the accounts that predate the store:

```dart
TomTotp2FAService.globalSettingSecretResolver =
    (context) => secretStore.lookup(context.principal.username);
```

The adaptor asks the store first and the resolver only when the store has
nothing, which is what lets a deployment migrate one user at a time. With
neither, every TOTP challenge fails with `login.error.2fa.not-enrolled` rather
than accepting anything. Note the secret is read from your own store,
deliberately **not** from `TomUser.attributes` — those are projected into the
token's *public* claims.

For the mailed and texted codes there is no resolver to set: the destination is
already on the user record, and what a deployment supplies instead is the
message the code arrives in — see
[Codes delivered by email or SMS](#codes-delivered-by-email-or-sms).

**5 — Drive it from the client.** Pass 1's result tells the client what
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

The enrolment branch is read from the same token through its own accessor, and
answers the three enrolment passes rather than pass 2:

```dart
var enrolment = TomBearerAuthentication.pendingTwoFactorEnrolment;
if (enrolment != null && !enrolment.hasOffer) {
  // No offer yet: the user picks from result.availableTwoFactorMethods, whose
  // descriptors carry resource keys — never literal names — to render.
  result = await api.beginEnrolment(message..password = chosenType);
  // ... setTokens, then re-read pendingTwoFactorEnrolment
}
if (enrolment != null && enrolment.hasOffer) {
  // enrolment.clientData carries what the user must act on — for TOTP the
  // secret and the otpauth:// URI to scan.
  result = await api.completeEnrolment(message..password = typedCode);
}
// enrolment.skippable → api.skipEnrolment(message) completes the login instead.
```

On a **wrong** code with attempts left, pass 2 answers with
`login.error.2fa.invalid-code` *and a fresh interim token* whose attempt counter
has advanced — so the loop above simply repeats. On a wrong code with no
attempts left, or a lapsed challenge, there is no token and the client must
restart at pass 1.

### Mechanisms that need something installed

Some mechanisms cannot work alone. A mailed code needs a `TomEmailService`, a
texted one needs a `TomSmsService`, and a deployment that installed neither has
no way to send anything — while the adaptors themselves ship annotated, so the
scan finds them in *every* reflected program whether or not anybody asked for
mail.

Left at that, the failure lands in the worst possible place. `registeredTypes`
is the only thing `Tom2FADecision.offerableMechanisms` consults, so an adaptor
that merely *exists* is an adaptor that is *offered*; the user picks `email`,
the login issues the challenge, and the adaptor only then discovers there is
nothing to send through. What it raises is a `Tom2FAException`, which is not
client-throwable — so the user is shown an opaque failure halfway through
signing in, having been offered an option that never could have worked.

An adaptor answers the question in advance by implementing
`Tom2FAPrerequisite`:

```dart
abstract class Tom2FAPrerequisite {
  /// What this deployment did not install, or `null` when the adaptor can run.
  String? get unmetPrerequisite;
}
```

`TomDeliveredCode2FAService` already implements it — its answer is "no
`TomEmailService` is installed, so no `"email"` code could be sent" — so an
adaptor extending that base inherits the behaviour by supplying
`resolveDeliveryService()` and `deliveryServiceType`. Anything else opts in by
implementing the one getter.

**The scan skips; it does not refuse.** A server with no mail relay is a
legitimate deployment, not a broken one, and throwing would make one
uninstalled channel cost that deployment every *other* mechanism it wired —
turning a supported shape into a total 2FA outage. So the candidate is left out
of the registry, the scan carries on, and the reason is logged:

```text
2FA adaptor scan: mechanism "email" (TomEmailCode2FAService) was not registered
because no TomEmailService is installed, so no "email" code could be sent. It
will not be offered to any principal. Install what it needs before the first
login, or remove the mechanism from your policies.
```

The answer is a *reason* rather than a flag for exactly that line's sake. A
mechanism that quietly disappears is the hardest kind of absence to debug —
every lookup answers `null`, which is also what a mechanism nobody ever wrote
answers — so the log names both halves: which mechanism went, and what to
install to get it back.

`Tom2FARegistry.register` is deliberately **not** gated. Naming an adaptor in a
call is asking for it, and a deployment that builds its adaptors before its
collaborators needs that escape; the problem the prerequisite answers is the
*automatic* registration nobody asked for.

**Install collaborators during start-up, before the first login.** The scan
runs once, lazily, and a successful scan is not repeated. An adaptor whose
service is not installed *yet* is indistinguishable from one whose service was
never installed at all, so it is skipped — and the mechanism then stays absent
for the life of the process, however many `TomEmailService` beans arrive
afterwards. Ordering is the deployment's duty; the logged skip is what makes a
mis-ordered start-up a one-line diagnosis rather than a hunt.

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

Install them **before the first login**, not merely before the first code: the
adaptor that finds no service at the moment the registry is scanned is left out
of the registry for the life of the process, and the mechanism is then never
offered. Install one and not the other and you keep exactly the channel you
wired — the two are judged separately. See
[Mechanisms that need something installed](#mechanisms-that-need-something-installed).

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

### How a mechanism names itself

A user choosing between second factors reads words: *Authenticator app*,
*Code by email*. Those words are **never** in the adaptor. Every
`Tom2FAService` supplies a `Tom2FAMethodDescriptor` instead, which is four
strings — an identifier and three resource keys:

```dart
@override
Tom2FAMethodDescriptor get descriptor =>
    Tom2FAMethodDescriptor.scoped('webauthn');
```

`scoped(type)` derives all three keys under the one scope
(`Tom2FAMethodDescriptor.resourceScope`, `'two_factor'`), so a resource bundle
can be searched by prefix and no adaptor has to spell the convention out:

| Field | For `scoped('webauthn')` | Rendered as |
| ----- | ------------------------ | ----------- |
| `type` | `'webauthn'` | Not shown — the key the client sends back |
| `displayNameKey` | `two_factor.webauthn.name` | The option's label |
| `descriptionKey` | `two_factor.webauthn.description` | The sentence under it |
| `iconKey` | `two_factor.webauthn.icon` | Whatever the client's icon set calls it |

The unnamed constructor exists for a mechanism whose keys do not follow the
convention — a deployment fitting an adaptor into an existing resource
bundle — but `scoped` is the one to use.

**Why the descriptor sits on the service and not on the registry.** Only the
mechanism knows what it is called. A registry that held the descriptions would
have to be edited every time an adaptor was added, which is the exact coupling
the adaptor contract exists to remove. Deriving it the other way costs nothing
and cannot drift: `Tom2FARegistry.availableMethods` maps the registered adaptors
to their descriptors, and `enrollableMethods` does the same for the subset that
implements `Tom2FAEnrolmentSupport`. A mechanism that is not registered is not
describable, and one that is registered describes itself without anyone
remembering to list it.

Both catalogs are the same for every principal. Narrowing them to *this* user's
permitted mechanisms is `Tom2FADecision.offerableMechanisms`' job — that needs
the policy's answer, and a registry has no principal to ask about. What reaches
the client is narrower still: `TomAuthenticationResult.availableTwoFactorMethods`
carries the descriptors of exactly the types the enrolment offer named, looked
up from the registry at the moment the result is built rather than carried in
the token, so a token minted before a mechanism's resource keys were corrected
cannot keep handing out the old ones.

### Writing your own mechanism

For another *delivered* channel — a push notification, a voice call — extend
`TomDeliveredCode2FAService` and supply the things that differ. The type
argument is the service the channel sends through, which is also what makes the
mechanism [skippable when nobody installed
one](#mechanisms-that-need-something-installed):

```dart
@tomReflector
@Tom2FAAdaptor('push')
class MyPushCode2FAService
    extends TomDeliveredCode2FAService<MyPushGateway> {
  @override
  String get type => 'push';

  // Resolved per call, never held in a field: the registry builds the adaptor
  // before a deployment has necessarily finished installing its beans, so a
  // captured service would be captured as null and stay that way.
  @override
  MyPushGateway? resolveDeliveryService() {
    final installed = TomBean.getBeanByType(MyPushGateway);
    return installed is MyPushGateway ? installed : null;
  }

  // A Type, not a name, so the "install this" diagnostics survive a rename.
  @override
  Type get deliveryServiceType => MyPushGateway;

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
      // requireDeliveryService() rather than the field: it throws a named,
      // logged Tom2FAException if the gateway was uninstalled after the scan.
      // The send itself throws if the gateway refuses — which is what makes the
      // challenge fail instead of a code silently never arriving.
      requireDeliveryService().send(
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

- **A descriptor names the mechanism in resource keys, never in literal text** —
  see [How a mechanism names itself](#how-a-mechanism-names-itself). Implement
  `Tom2FAEnrolmentSupport` as well if the mechanism can be *set up* through a
  login and not only verified; see [Enrolment](#enrolment).
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
| `login.error.2fa.enrolment-code-invalid` | The confirmation code did not match the one just sent; nothing is stored | A re-issued offer, until attempts run out |
| `login.error.2fa.enrolment-offer-invalid` | The enrolment offer is unusable — no destination for a delivered code, a confirmation on a token on which nothing was begun, or a begun offer whose `enrolmentExpiresAt` claim is absent or unreadable | None |

The enrolment passes add their own, all of them from
`TomAuthenticationServer` rather than from a mechanism:

| Key | Meaning | Token returned |
| --- | ------- | -------------- |
| `login.error.2fa.no-enrolment` | No interim token was presented, or the one presented carries no pending enrolment. This is what stops the enrolment passes from being an unauthenticated way to attach a factor to an account | None |
| `login.error.2fa.enrolment-not-offered` | The chosen mechanism was not among the types *this token* was issued offering | None |
| `login.error.2fa.unsupported-mechanism` | No **enrollable** adaptor is registered for the chosen mechanism, or none of the permitted mechanisms can be enrolled here | None |
| `login.error.2fa.enrolment-unavailable` | There is no `Tom2FAEnrolmentStore`, so a confirmed factor could not be recorded | None |
| `login.error.2fa.enrolment-expired` | The offer lapsed (default 10 minutes) | None — restart at pass 1 |
| `login.error.2fa.enrolment-attempts-exhausted` | The confirmation was wrong once too often | None — restart at pass 1 |
| `login.error.2fa.enrolment-required` | A skip was attempted on an offer the server did not mark skippable | None |

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

### Two registrations against one IdP

A provider is keyed by **its own id**, and the `issuer` is an ordinary field
underneath. Nothing makes it unique, and that is deliberate: registering the
same IdP twice is how a deployment offers it under two scope sets, or two client
registrations — one that asks for calendar access and retains the grant, one
that only signs the user in.

```yaml
oauth:
  providers:
    google:                             # sign-in only
      issuer: https://accounts.google.com
      scopes: openid email profile
      # …endpoints, clientId, clientSecret, redirectUri…
    google-calendar:                    # the same IdP, delegating
      issuer: https://accounts.google.com
      scopes: openid email profile https://www.googleapis.com/auth/calendar
      storeTokens: true
      # …endpoints, a second clientId, clientSecret, redirectUri…
```

Every decision a login takes out of provider configuration — `provisioning`,
`storeTokens` — follows **the registration the flow began with**, never
"whichever is configured against this issuer". The two are not the same choice
when twins exist, and taking them apart is what would let a login provision
under one registration's policy while retaining under the other's. The flow
resolves the provider once, when it spends the pending record, and hands it on
as [`TomOAuthExchange.provider`](api_reference/api_summary_authentication.md#tomoauthexchange);
nothing downstream resolves it again.

The identity is unaffected: `TomExternalIdentity.issuer` names the **IdP**, not
the registration, so twins assert the same identity and therefore share one row
in the linking table and one slot in the token store. That is the intended
reading — it is one Google account either way, and a user who consented through
`google-calendar` has not acquired a second local account by doing so.

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
  Future<void> unlink(String issuer, String subject);

  static TomExternalIdentityStore? resolve();
}
```

`unlink` removes the link **and every provider token held through it** — the
cascade is part of the contract, not the caller's responsibility, so a user who
presses *disconnect* cannot leave a live refresh token behind.

Keyed on the pair rather than on the subject alone because a subject is only
unique *within* an issuer — two providers may both call a user `12345`.

`TomPersistentExternalIdentityStore` is the production implementation over
`TomExternalIdentityLinkRepository`; `TomMemoryExternalIdentityStore` exists for
tests. There is no in-memory *default*: a link that vanishes on restart sends a
returning user through provisioning again, so a deployment that installs no
store is told what is missing rather than given a store that loses its rows.

The persistent store needs `TomExternalIdentityLink.createTableSql`, shipped as
`example/authentication/migrations/main/tomcore/[4]-create_tom_external_identity.sql`.

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
| The `id_token` carries an `exp`, and has not passed it | `oauth.flow.missing_expiry` · `oauth.flow.id_token_expired` |
| The `id_token`'s `nbf`, when it sends one, has arrived | `oauth.flow.id_token_not_yet_valid` |
| The claims carry a subject | `oauth.flow.missing_subject` |

An unknown, expired and already-spent state are deliberately **indistinguishable
to a caller**: telling them apart tells an attacker whether a handle was ever
valid.

The `id_token` signature is **not** checked, and that is a deliberate limitation
rather than an oversight — see [Status and Limitations](#status-and-limitations).

**Freshness is checked, and is a different question from that one.** The reason
the signature may go unchecked is about *authenticity* — the token came down the
server's own TLS back channel, so nobody could have substituted it. Nothing in
that argument says the token is *current*, and a token can be unquestionably the
issuer's and hours out of date. So `exp` is verified, and `nbf` when the provider
sends one.

Both are read against a tolerance, `clockSkewSeconds`, which defaults to 60 and
is configured per provider:

```yaml
oauth:
  providers:
    slow-clock-idp:
      clockSkewSeconds: 300
```

The tolerance is what stops the check turning ordinary NTP drift into a failed
login, and it is per provider because the drift being tolerated belongs to one
specific IdP — widening it for the badly-synchronised one must not loosen every
other. `clockSkewSeconds: 0` is a legitimate setting; negative is
`oauth.config.invalid_clock_skew`.

An `id_token` with **no** `exp` is refused rather than read as never expiring:
OIDC Core §2 requires the claim, so its absence is a non-conformant provider, and
treating "cannot check" as "check passed" would make the verification true only
of providers that chose to cooperate.

`iat` is deliberately **not** a rejection. It answers "how long ago was this
minted", which only becomes a refusal once a deployment states a maximum age —
a policy this module does not hold, and one the provider has already expressed
on its own terms as `exp`. A deployment that wants one is asking for OIDC
`max_age` / `auth_time`, which is a separate decision.

Providers that predate OIDC return no `id_token`; for those, configure
`userInfoEndpoint` and the flow fetches the claims with the access token
instead. A provider with neither fails clearly rather than producing an
anonymous identity.

`TomOAuthTokenTransport` is the one HTTP seam. Stubbing it — which is all
`oauth_test.dart` does — leaves every other line of the flow executing exactly
as it does against a real provider.

### Delegated access: the provider's tokens

Authentication asks *who the user is*; delegated authorization asks *what this
application may do as them*. The token response answers both, and the framework
treats the two answers very differently.

**Nothing is retained unless a provider opts in.** `storeTokens` defaults to
`false`, because a framework session token is minted here and revocable here
while a provider refresh token is a long-lived credential against a **third
party** — one that outlives the session, is useful to anyone who obtains it, and
is revocable only by the user noticing. A deployment that only wants "Sign in
with …" must never end up holding one.

The grant is nonetheless handed back on every exchange, so "keeps nothing" is a
statement about *storage* and not a capability withheld:

```dart
final exchange = await flow.completeAuthorization(code: code, state: state);
final grant = exchange.tokens;      // null when the provider delegated nothing
grant?.accessToken;                 // usable for the rest of this request
```

A deployment that needs the credential *later* opts the provider in and installs
a store:

```yaml
oauth:
  providers:
    google:
      # …issuer, endpoints, clientId, clientSecret, redirectUri, scopes…
      scopes: [openid, email, https://www.googleapis.com/auth/calendar.readonly]
      storeTokens: true
      # Google returns no refresh token without these two.
      authorizationParameters:
        access_type: offline
        prompt: consent
```

```dart
TomBean.withType(
  TomOAuthTokenStore,
  TomPersistentOAuthTokenStore(TomExternalIdentityTokenRepository()),
);
```

`authorizationParameters` are merged into the authorization redirect **before**
the flow's own parameters, so a configuration typo cannot replace `state`,
`redirect_uri` or the PKCE challenge.

What the store guarantees:

| Guarantee | How |
| --------- | --- |
| Neither token is readable in the row | The whole grant is JSON, encrypted through `TomJwtConfiguration.encrypt` into `token_data` |
| An operator can still triage | `token_scope`, `obtained_at`, `expires_at` sit beside it in the clear; none of them is authoritative |
| One grant per identity | `UNIQUE KEY (issuer, subject)` — a second row would make which credential is presented depend on row order |
| A credential never outlives its link | `TomExternalIdentityStore.unlink` deletes the grant *before* the link |

Using it later is one call, and it is deliberately **not** on the authentication
service:

```dart
final grant = await flow.accessTokenFor(
  providerId: 'google',
  subject: identity.subject,
);
if (grant == null) {
  // Nothing held, or expired past refreshing: send the user through consent.
}
```

`accessTokenFor` reads the held grant, answers it when it is still live, and
otherwise refreshes it and writes the result back — the three steps every caller
would otherwise write, where the caller that writes them wrong writes back
nothing and refreshes on every call until the provider's rate limiter objects.
`refreshGrant` is the lower-level form for a caller holding a grant already.

**Refreshing is not a login.** Neither method consults a
`TomAuthenticationService`, asks the 2FA policy, touches a session or produces a
principal. That separation is the point: reusing the login path to renew a
background job's calendar token would run a second-factor decision for a user who
is not present.

### Where pending authorizations live

The handshake is **two HTTP requests**, and the second one is not issued by the
client: the provider redirects the browser to `/oauth/callback`, and a load
balancer routes that redirect to whichever node it likes. Whatever
`/oauth/authorize` wrote must therefore be readable by *any* node — including
one that has never heard of the flow.

`TomOAuthMemoryStateStore` keeps it in one isolate's memory, which is exactly
right for a single node and wrong for a cluster: a callback that lands on
another node fails as `oauth.flow.unknown_state`, indistinguishable from an
expired or replayed state. The symptom is a deployment where external login
works, but intermittently, and the log claims replay.

`TomSqlOAuthStateStore` puts the record in `tom_oauth_state` — a framework
table declared once as a `TomFrameworkTable` (see
[Database Migration](db_migration.md#the-frameworks-own-tables)) and so covered
by the same convergence checks as every other. Three decisions in it are worth
stating outright:

* **The PKCE verifier is stored as written, not encrypted.** It is a
  single-use, ten-minute nonce whose only job is to prove that the party
  redeeming the code is the party that began the flow, and it is useless
  without the authorization code — which the store never sees. Encrypting it
  would require a key shared by every node, a second piece of distributed state
  protecting the first, guarding nothing that outlives the request pair. The
  deployment owes this table ordinary database access control; it is not
  public.
* **Expiry is a predicate, not a job.** Every statement carries
  `expires_at > :now`, so a row becomes invisible the instant it expires whether
  or not anything has swept it — correctness does not depend on the cleanup
  running. A throttled sweep on write then deletes what is already invisible, so
  the table does not grow without bound. A scheduled job would have made
  liveness a precondition of correctness; this way it is only a precondition of
  size.
* **Completion is one statement.** `consume` is a single `DELETE … RETURNING`,
  so two nodes racing the same callback cannot both see the row: the database
  picks a winner and the loser is handed nothing. A read followed by a delete
  would open precisely the window that lets one state be spent twice.

Which store a deployment gets is configuration, read from `oauth.stateStore`
beside `oauth.providers` and defaulting to memory — so nothing changes for a
deployment that does not ask:

```yaml
oauth:
  stateStore:
    type: sql               # memory (default) | sql
    datasource: main        # required for sql
    table: tom_oauth_state  # optional
    timeToLiveSeconds: 600  # optional
    createSchema: true      # optional; create the table on first use
  providers:
    google: { ... }
```

```dart
// Read the block and install whatever it named. TomOAuthStateStore.resolve()
// picks the installed bean up; nothing else changes.
TomBean.withType(
  TomOAuthStateStore,
  TomOAuthStateStoreSettings.fromConfiguration().createStore(),
);
```

A `type` that is neither value, or `sql` with no `datasource`, fails at startup
rather than falling back to memory — a typo that quietly selected the
per-process store would reintroduce the intermittent failure on a cluster whose
operator believes it is configured against exactly that.

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
| `oauth.config.missing_value` · `oauth.config.not_a_map` · `oauth.config.provider_not_a_map` · `oauth.config.unknown_provisioning` · `oauth.config.invalid_clock_skew` | The `oauth.providers` block is malformed. Startup-time. |
| `oauth.config.unknown_provider` | A request named a provider that is not configured. |
| `oauth.config.state_store_not_a_map` · `oauth.config.unknown_state_store` · `oauth.config.missing_state_store_datasource` · `oauth.config.invalid_state_store_ttl` | The `oauth.stateStore` block is malformed. Startup-time, and never defaulted away. |
| `oauth.state_store.unknown_datasource` | The SQL state store names a data source that is not registered. Startup-time. |
| `oauth.callback.unknown_state` · `oauth.flow.unknown_state` | The state handle is unknown, expired, or already used — raised by the endpoint and by the flow respectively. |
| `oauth.callback.provider_error` | The provider itself refused (e.g. the user pressed cancel). |
| `oauth.flow.missing_code` · `oauth.flow.token_exchange_rejected` | The redirect carried no code, or the token endpoint refused the exchange. |
| `oauth.flow.issuer_mismatch` · `oauth.flow.audience_mismatch` · `oauth.flow.missing_subject` · `oauth.flow.malformed_id_token` | The claims failed verification. |
| `oauth.flow.missing_expiry` · `oauth.flow.id_token_expired` · `oauth.flow.id_token_not_yet_valid` | The `id_token` is outside its own validity window, or carries none. Read against the provider's `clockSkewSeconds`. |
| `oauth.flow.no_claims_source` · `oauth.flow.no_access_token` | The provider returned neither an `id_token` nor a usable `userInfoEndpoint` call. |
| `oauth.provider.http_error` · `oauth.provider.malformed_json` | The provider's HTTP call failed or answered with something that is not a JSON object. |
| `login.error.oauth.no-local-account` | Authenticated, but unlinked, and the provider is configured to refuse. |
| `login.error.oauth.linked-account-missing` | The link outlived the account it pointed at. |
| `login.error.oauth.provisioning-unsupported` | `autoProvision` is configured but the directory does not implement it. |
| `login.error.oauth.no-identity-store` | No `TomExternalIdentityStore` is installed. |
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
implementing it. An adaptor supplies a `descriptor`, issues a challenge and
verifies a submission; nothing else. `Tom2FARegistry` scans
`@Tom2FAAdaptor`-annotated classes the first time it is consulted; `register` /
`lookup` / `registeredTypes` / `registerAnnotated` drive it explicitly, and
`availableMethods` / `enrollableMethods` / `enrolmentSupportFor` derive the
catalogs from what is registered. The scan skips an annotated candidate whose
`Tom2FAPrerequisite.unmetPrerequisite` names something this deployment did not
install; `register` is unconditional. See
[Two-Factor Authentication](#two-factor-authentication) and
[Mechanisms that need something installed](#mechanisms-that-need-something-installed).

### `Tom2FAPrerequisite`

The one-getter interface an adaptor implements when it can only run if
something *else* was installed — a mail service, an SMS gateway, a push
credential. `unmetPrerequisite` answers a reason string rather than a flag, so
the skip can be logged with what to install;
`TomDeliveredCode2FAService` implements it in terms of `deliveryServiceType`.
Consulted only by the automatic scan, which is where mechanisms nobody asked
for come from. See
[Mechanisms that need something installed](#mechanisms-that-need-something-installed).

### `Tom2FAPolicy` / `Tom2FADecision` / `Tom2FARequirement`

Whether a login owes a second factor, which mechanisms may answer for it, and
how many grace logins remain. `Tom2FAPolicy.resolve()` returns the installed
bean or the default `TomPrincipalFlag2FAPolicy`, which reproduces the
principal-flag behaviour that predates policies; `TomRole2FAPolicy` states the
requirement per role and takes the strictest match. `Tom2FAGraceAccounting` is
the optional second interface a policy implements to be told when a grace login
is spent. See [The policy decides](#the-policy-decides).

### `Tom2FAEnrolmentStore` / `Tom2FAEnrolmentSupport`

The two halves of enrolment: the deployment supplies the store a confirmed
factor is written to, the adaptor supplies the offer/confirm round trip.
`Tom2FAEnrolment` is one set-up factor, `Tom2FAEnrolmentOffer` is one pending
setup and `Tom2FAEnrolmentState` is the server's view of it inside an interim
token. `resolve()` on the store is **nullable with no fallback**, and that null
is load-bearing — see [Enrolment](#enrolment).

### `TomMemory2FAEnrolmentStore` / `TomPersistent2FAEnrolmentStore`

The two shipped stores. The first keeps enrolments in a map (plus `clear()`) for
tests and single-process development; the second persists them as
`TomUserTwoFactorEnrolment` rows through
`TomUserTwoFactorEnrolmentRepository`, encrypting `secretData` at rest with the
JWT configuration's RSA key and degrading an undecryptable row to an empty
secret rather than failing the login.

### `TomTotp2FAService`

The shipped RFC 6238 authenticator-app mechanism, registered under `'totp'`, and
enrollable: it also implements `Tom2FAEnrolmentSupport`, generating a secret and
an `otpauth://` URI in `beginEnrolment` and refusing to yield an enrolment until
the user types back a code derived from it. Its statics configure digits,
period, clock-skew window, attempts, challenge validity, issuer, secret length
and the enrolment attempt/validity budget. The secret is read from the enrolment
store first and from `globalSettingSecretResolver` — unset by default — only
when the store has none, which is what lets a deployment migrate one user at a
time.

### `TomDeliveredCode2FAService`

The shape every second factor that *sends* a code shares: generate a code from
the framework's CSPRNG (rejection-sampled, so no modulo bias), seal it as a
salt plus a SHA-256 into `verificationData`, deliver it synchronously, and
recognise it again with a constant-time compare. It also implements
`Tom2FAEnrolmentSupport`, where enrolment means proving the user can read what
is sent to the destination. Its type parameter is the delivery service the
channel sends through, which also makes it a `Tom2FAPrerequisite`: a code
mechanism with nothing to send through is left out of the registry rather than
discovered at the challenge. A subclass supplies six things: `type`,
`destinationOnRecord`, `maskDestination`, `deliver`, `resolveDeliveryService`
and `deliveryServiceType`; `requireDeliveryService` is what `deliver` sends
through. The statics
`generateNumericCode`, `sealCode`, `matchesSealedCode` and `constantTimeEquals`
are public because two adaptors and their tests use them.

### `TomEmailCode2FAService` / `TomSmsCode2FAService`

The two shipped delivered-code mechanisms, registered under `'email'` and
`'sms'`. They resolve `TomEmailService` / `TomSmsService` from the bean locator
at call time and render `email.two_factor_code.*` / `sms.two_factor_code.*`
(and the matching `…_enrolment` templates). A missing service normally keeps
the mechanism out of the registry altogether; reached anyway — registered by
hand, or uninstalled after the scan — it is a `Tom2FAException`, not a delivery
failure. See [Codes delivered by email or SMS](#codes-delivered-by-email-or-sms)
and
[Mechanisms that need something installed](#mechanisms-that-need-something-installed).

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

### `TomSqlOAuthStateStore` / `TomOAuthStateStoreSettings`

The state store every node of a cluster shares, over the `tom_oauth_state`
framework table, and the `oauth.stateStore` block that selects it. `store` /
`peek` / `consume` / `purgeExpired`, with `consume` a single
`DELETE … RETURNING` so a state stays single-use under concurrent completions —
see [Where pending authorizations live](#where-pending-authorizations-live).

### `TomExternalIdentityStore` / `TomExternalIdentityLink`

The linking table. `TomPersistentExternalIdentityStore` for production,
`TomMemoryExternalIdentityStore` for tests, and no default — see
[The linking table](#the-linking-table). `unlink` is the method that removes a
link, and it cascades into the token store: a provider credential never outlives
the link it was granted through.

### `TomOAuthTokenGrant`

One provider grant — `accessToken`, `refreshToken`, `tokenType`, `scope`,
`expiresAt`, `obtainedAt`. `expiresWithin` answers "will this still be valid when
the request arrives?", which is the question a caller actually has;
`fromTokenResponse` carries a previous grant's refresh token and scope forward,
because RFC 6749 §6 lets a provider omit them from a refresh response. `toString`
prints neither token.

### `TomOAuthTokenStore` / `TomPersistentOAuthTokenStore` / `TomExternalIdentityToken`

Where a grant lives, keyed `(issuer, subject)`. `resolve()` answers `null` when
no store is installed, which is the ordinary and safe state — nothing can be
written where there is nowhere to write it. `TomPersistentOAuthTokenStore` writes
the grant encrypted into `tom_external_identity_token`;
`TomMemoryOAuthTokenStore` is for tests and bring-up. See
[Delegated access](#delegated-access-the-providers-tokens).

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
- **Two policies ship, and neither is a component.** `TomPrincipalFlag2FAPolicy`
  is the default and `TomRole2FAPolicy` is installed by hand. Neither carries
  `@TomComponent`, so a deployment that adds a dependency does not silently
  acquire a 2FA requirement; anything richer than "per role" or "per principal
  flag" is a `Tom2FAPolicy` the deployment writes.
- **No enrolment store is installed by default**, deliberately.
  `Tom2FAEnrolmentStore.resolve()` returns `null` rather than an empty store,
  because "nobody tracks enrolments here" and "this user has enrolled nothing"
  must lead to different logins — see [Enrolment](#enrolment). A deployment
  installs `TomPersistent2FAEnrolmentStore` (and runs the DDL in
  `TomUserTwoFactorEnrolment.createTableSql`) to switch enrolment on.
- **`graceLogins` is counted by the policy, not by the framework.** The server
  reports each spend through `Tom2FAGraceAccounting`; a policy that does not
  implement it grants the same grace on every login, which is a "warn, do not
  enforce yet" deployment and not an error. Nothing in this module persists a
  remaining-grace counter.
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
  defence in depth. This limitation is about *authenticity* only — the token's
  `exp` and `nbf` **are** checked, because freshness does not follow from
  authenticity; see [The handshake](#the-handshake).
- **The `id_token`'s age is not policed, only its expiry.** `iat` is read by
  nothing: a maximum-age policy is a decision this module does not take, and
  `exp` is the provider's own statement of how long the token is good for. A
  deployment that needs "re-authenticate if the session is older than an hour"
  is asking for OIDC `max_age` / `auth_time`, which is not implemented.
- **`TomOAuthMemoryStateStore` is the default state store, and is per-process.**
  Pending authorizations live for ten minutes in one isolate's memory, which is
  correct for a single-node deployment and wrong behind a load balancer that may
  route the callback to a different node. That default is deliberate — a single
  node and a test suite need no database — but it is a default, not the only
  choice.
- **A clustered deployment sets `oauth.stateStore.type: sql`** and gets
  `TomSqlOAuthStateStore` over the shared `tom_oauth_state` table, where an
  authorization begun on one node completes on any other and a state stays
  single-use under concurrent completions. What is *not* implemented is any
  other backing: there is no Redis or other cache-backed store, and a deployment
  wanting one implements the same three-method contract. See
  [Where pending authorizations live](#where-pending-authorizations-live).
- **The identity *store* has no default at all**, deliberately — see
  [The linking table](#the-linking-table). `TomPersistentExternalIdentityStore`
  needs `TomExternalIdentityLink.createTableSql`, shipped as
  `example/authentication/migrations/main/tomcore/[4]-create_tom_external_identity.sql`.
- **The framework retains no provider token unless a provider opts in.**
  `storeTokens` defaults to `false`, so a deployment that only wants "Sign in
  with …" never acquires a third-party credential. The grant is still handed to
  the caller on every exchange; what is opt-in is *storing* it. See
  [Delegated access](#delegated-access-the-providers-tokens).
- **A retained grant needs a `TomOAuthTokenStore` and its table.** Opting a
  provider in without installing a store retains nothing and logs it — the two
  halves are separate on purpose, so a deployment can hold its identity links in
  a table of its own and still let the framework hold credentials, or the
  reverse. `TomPersistentOAuthTokenStore` needs
  `TomExternalIdentityToken.createTableSql`, shipped as
  `example/authentication/migrations/main/tomcore/[3]-create_tom_external_identity_token.sql`.
- **Provider token *revocation* is not implemented.** Deleting the identity link
  deletes the framework's copy of the grant, but nothing calls the provider's
  revocation endpoint — the credential stops being reachable from here and
  remains valid at the provider until it expires or the user withdraws consent.
  A deployment that must revoke on unlink calls the provider's endpoint itself
  (RFC 7009), which is one provider-specific HTTP call this module deliberately
  does not model.

## Dependencies

- **`tom_core_kernel`**: `TomPrincipal`, `TomAccessControlDefinition`,
  `TomBearerAuthentication`, `TomServerJwtToken`, the 2FA wire types
  `Tom2FAChallenge` / `Tom2FAClaims` / `Tom2FAPendingEnrolment` /
  `Tom2FAEnrolmentClaims`, the `Tom2FAMethodDescriptor` every adaptor describes
  itself with, the `TomTotp` derivation primitives, `TomServerPrincipal` (the
  holder server self-login installs into), and the wire types
  `TomAuthenticationMessage` / `TomAuthenticationResult`. The 2FA types live
  there and not here because the server writes them and the client reads them.
- **Crypto** (kernel): `TomJwtConfiguration`'s RSA key encrypts an enrolment's
  `secretData` before `TomPersistent2FAEnrolmentStore` writes it, so the same
  key that protects a token's encrypted claims protects a stored factor.
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
- **Object Persistence** (this package): `TomExternalIdentityLink` and
  `TomUserTwoFactorEnrolment` are ordinary entities over
  `TomSqlDatasourceRepository`. Neither table is created by the framework; each
  entity carries its own `createTableSql` for a deployment's migration to run.
- **Bean Locator** (kernel): `Tom2FAPolicy` and `Tom2FAEnrolmentStore` are
  resolved by type through `TomBean`, which is what makes both of them
  swappable without a configuration key.
- **Configuration** (this package): the provider set is read through
  `TomServerConfigResourceProvider`, which already performs `${...}` env-var
  substitution.
