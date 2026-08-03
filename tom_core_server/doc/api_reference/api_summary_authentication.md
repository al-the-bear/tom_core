# Tom Core Server API Reference: Authentication Module

Server-side login orchestration: reflection-discoverable adaptor markers, the
authentication-service contract, the data carried into a login attempt, the
two-pass second-factor flow, the JWT-issuing `TomAuthenticationServer`, and the
server's own self-login against an auth server.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomAuthenticationAdaptor](#tomauthenticationadaptor)
  - [Tom2FAAdaptor](#tom2faadaptor)
  - [LoginException](#loginexception)
  - [Tom2FAException](#tom2faexception)
  - [TomAuthenticationData](#tomauthenticationdata)
  - [TomAuthenticationService](#tomauthenticationservice)
  - [Tom2FAContext](#tom2facontext)
  - [Tom2FAChallengeSpec](#tom2fachallengespec)
  - [Tom2FASubmission](#tom2fasubmission)
  - [Tom2FAService](#tom2faservice)
  - [Tom2FARegistry](#tom2faregistry)
  - [Tom2FARequirement](#tom2farequirement)
  - [Tom2FADecision](#tom2fadecision)
  - [Tom2FAPolicy](#tom2fapolicy)
  - [TomPrincipalFlag2FAPolicy](#tomprincipalflag2fapolicy)
  - [TomRole2FAPolicy](#tomrole2fapolicy)
  - [Tom2FAGraceAccounting](#tom2fagraceaccounting)
  - [Tom2FAEnrolment](#tom2faenrolment)
  - [Tom2FAEnrolmentOffer](#tom2faenrolmentoffer)
  - [Tom2FAEnrolmentSupport](#tom2faenrolmentsupport)
  - [Tom2FAEnrolmentState](#tom2faenrolmentstate)
  - [Tom2FAEnrolmentStore](#tom2faenrolmentstore)
  - [TomMemory2FAEnrolmentStore](#tommemory2faenrolmentstore)
  - [TomUserTwoFactorEnrolment](#tomusertwofactorenrolment)
  - [TomUserTwoFactorEnrolmentRepository](#tomusertwofactorenrolmentrepository)
  - [TomPersistent2FAEnrolmentStore](#tompersistent2faenrolmentstore)
  - [TomTotpSecretResolver](#tomtotpsecretresolver)
  - [TomTotp2FAService](#tomtotp2faservice)
  - [TomDeliveredCode2FAService](#tomdeliveredcode2faservice)
  - [TomEmailCode2FAService](#tomemailcode2faservice)
  - [TomSmsCode2FAService](#tomsmscode2faservice)
  - [TomAuthenticationInfo](#tomauthenticationinfo)
  - [TomDummyAuthenticationService](#tomdummyauthenticationservice)
  - [TomAuthenticationServer](#tomauthenticationserver)
  - [TomServiceCredential](#tomservicecredential)
  - [TomServiceLoginTransport](#tomservicelogintransport)
  - [TomServiceLoginResponse](#tomserviceloginresponse)
  - [TomHttpServiceLoginTransport](#tomhttpservicelogintransport)
  - [TomServerSelfLoginException](#tomserverselfloginexception)
  - [TomServerSelfLogin](#tomserverselflogin)
  - [TomOAuthException](#tomoauthexception)
  - [TomOAuthProvisioning](#tomoauthprovisioning)
  - [TomOAuthProviderConfig](#tomoauthproviderconfig)
  - [TomOAuthProviders](#tomoauthproviders)
  - [TomOAuthPkce](#tomoauthpkce)
  - [TomOAuthAuthorizationState](#tomoauthauthorizationstate)
  - [TomOAuthStateStore](#tomoauthstatestore)
  - [TomOAuthMemoryStateStore](#tomoauthmemorystatestore)
  - [TomOAuthTokenTransport](#tomoauthtokentransport)
  - [TomHttpOAuthTokenTransport](#tomhttpoauthtokentransport)
  - [TomExternalIdentity](#tomexternalidentity)
  - [TomOAuthExchange](#tomoauthexchange)
  - [TomOAuthFlow](#tomoauthflow)
  - [TomExternalIdentityLink](#tomexternalidentitylink)
  - [TomExternalIdentityLinkRepository](#tomexternalidentitylinkrepository)
  - [TomExternalIdentityStore](#tomexternalidentitystore)
  - [TomPersistentExternalIdentityStore](#tompersistentexternalidentitystore)
  - [TomMemoryExternalIdentityStore](#tommemoryexternalidentitystore)
  - [TomOAuthCredential](#tomoauthcredential)
  - [TomExternalIdentityDirectory](#tomexternalidentitydirectory)
  - [TomOAuthAuthenticationService](#tomoauthauthenticationservice)
  - [TomOAuthServer](#tomoauthserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/authentication/authentication_server.dart`,
`lib/src/tomserver/authentication/two_factor.dart`,
`lib/src/tomserver/authentication/two_factor_policy.dart`,
`lib/src/tomserver/authentication/two_factor_enrolment.dart`,
`lib/src/tomserver/authentication/two_factor_delivered_code.dart`,
`lib/src/tomserver/authentication/server_self_login.dart`,
`lib/src/tomserver/authentication/oauth_provider.dart`,
`lib/src/tomserver/authentication/oauth_flow.dart`,
`lib/src/tomserver/authentication/oauth_identity.dart`,
`lib/src/tomserver/authentication/oauth_authentication_service.dart`,
`lib/src/tomserver/authentication/oauth_endpoints.dart`.

The module orchestrates the server-side login flow. `TomAuthenticationServer`
receives a `TomAuthenticationMessage`, builds a `TomAuthenticationData` from it,
and delegates credential checking to a configured `TomAuthenticationService`
(the default `TomDummyAuthenticationService` accepts any non-`"GUEST"` user and
logs an error, for scaffolding only). On success the resolved
`TomAuthenticationInfo` (principal + access-control definition) is encoded into
two JWTs — an authentication token and an authorization token — inside the
returned `TomAuthenticationResult`. `LoginException` (a `TomServerException`) is
caught and turned into a failed result. `TomAuthenticationAdaptor`,
`Tom2FAAdaptor`, `TomAuthenticationService`, and `Tom2FAService` are
reflection-discoverable (`@tomReflector`) so a runtime can enumerate and route
to the registered adaptors.

Whether a login owes a second factor is `Tom2FAPolicy`'s answer, taken once per
login as a `Tom2FADecision` (a `Tom2FARequirement`, the permitted mechanism keys
in preference order, and any grace logins). `Tom2FAPolicy.resolve()` returns the
installed bean or the default `TomPrincipalFlag2FAPolicy`, which reads
`TomPrincipal.requires2FA` / `twoFactorType` and so reproduces the behaviour that
predates policies; `TomRole2FAPolicy` states a requirement per role and takes the
strictest match. `Tom2FADecision.offerableMechanisms` intersects the permitted
keys with `Tom2FARegistry.registeredTypes`, so a policy naming an unregistered
mechanism fails at the branch that decides the login rather than as a null
adaptor later. A policy that also implements `Tom2FAGraceAccounting` is told
when a grace login is spent.

Anything but `Tom2FARequirement.disabled` runs the login in two passes. Pass 1
asks the `Tom2FAService` registered in `Tom2FARegistry` for the chosen mechanism
to issue a `Tom2FAChallengeSpec`, and answers with an *interim* token carrying
the challenge — its client-visible half in the public claims (as the kernel's
`Tom2FAChallenge`), its server-only verification blob in the encrypted section.
`authenticatePass2` recovers the challenge from the presented bearer, hands the
submitted factor to the same adaptor as a `Tom2FASubmission`, and on success
re-issues the token pair without the challenge. Nothing is stored server-side
between the passes. `Tom2FAException` reports a mis-wired adaptor set and is
never client-facing.

A user who owes a factor but has none set up is branched into **enrolment**
instead. `Tom2FAEnrolmentStore` is where a principal's `Tom2FAEnrolment`s live;
`resolve()` on it is nullable **with no fallback**, and the three outcomes are
distinguished deliberately — `null` means no store is installed (the mechanism
stays the only authority on whether the user has a factor, exactly as before),
an empty list means a store is installed and this user has enrolled nothing
(branch into the offer), a non-empty list names what to challenge. Enrolment
itself is `Tom2FAEnrolmentSupport`, a contract separate from `Tom2FAService`
because not every mechanism can be set up through a login: `beginEnrolment`
returns a `Tom2FAEnrolmentOffer`, `confirmEnrolment` either yields the
`Tom2FAEnrolment` to store or throws. The pending setup rides in the interim
token as a `Tom2FAEnrolmentState` — offered types and attempt counter public,
the offer's server-only `enrolmentData` encrypted — so the round trip is as
stateless as the challenge one, and nothing is written until a confirmation
succeeds. `TomMemory2FAEnrolmentStore` and `TomPersistent2FAEnrolmentStore`
(over `TomUserTwoFactorEnrolment`, secrets encrypted at rest) ship.

Three mechanisms ship. `TomTotp2FAService` (RFC 6238 authenticator app) needs no
delivery channel and stores nothing in `verificationData`, re-deriving its answer
from the shared secret. `TomEmailCode2FAService` and `TomSmsCode2FAService` are
*delivered* codes — both thin subclasses of `TomDeliveredCode2FAService`, which
generates a code, seals it as a salt plus a SHA-256 into `verificationData`,
sends it synchronously through the Messaging module's `TomEmailService` /
`TomSmsService`, and recognises it again with a constant-time compare. They are
the mechanisms that exercise the encrypted half of the challenge split, and they
also implement `Tom2FAEnrolmentSupport`: enrolling a delivered code means proving
the user can read what is sent to the destination.

`TomServerSelfLogin` covers the separate case of the deployment authenticating
*as itself*: it presents a `TomServiceCredential` over a
`TomServiceLoginTransport`, reconstructs the resulting principal, and installs
it as the server principal whose grants cap every user's. An unconfigured
deployment skips this silently; a configured one that fails raises
`TomServerSelfLoginException`.

## Class Hierarchy

```
TomServerException  (tom_core_server)
    ├── LoginException
    ├── Tom2FAException
    ├── TomServerSelfLoginException
    └── TomOAuthException

TomAuthenticationService  (abstract)
    ├── TomDummyAuthenticationService     (implements)
    └── TomOAuthAuthenticationService     (implements, delegates the rest)

TomOAuthStateStore  (abstract)
    └── TomOAuthMemoryStateStore  (implements)

TomOAuthTokenTransport  (abstract)
    └── TomHttpOAuthTokenTransport  (implements)

TomExternalIdentityStore  (abstract)
    ├── TomPersistentExternalIdentityStore  (implements)
    └── TomMemoryExternalIdentityStore      (implements)

TomExternalIdentityDirectory  (abstract, deployment-supplied)

TomSqlDatasourceRepository<TomExternalIdentityLink, int>
    └── TomExternalIdentityLinkRepository  (extends)

Tom2FAService  (@tomReflector, abstract)
    ├── TomTotp2FAService  (implements, @Tom2FAAdaptor('totp'),
    │                       + Tom2FAEnrolmentSupport)
    └── TomDeliveredCode2FAService  (implements, + Tom2FAEnrolmentSupport)
            ├── TomEmailCode2FAService  (extends, @Tom2FAAdaptor('email'))
            └── TomSmsCode2FAService    (extends, @Tom2FAAdaptor('sms'))

Tom2FAEnrolmentSupport  (abstract, mixed into an enrollable Tom2FAService)
    ├── TomTotp2FAService           (implements)
    └── TomDeliveredCode2FAService  (implements)

Tom2FAPolicy  (abstract)
    ├── TomPrincipalFlag2FAPolicy  (implements, const, the default)
    └── TomRole2FAPolicy           (implements)

Tom2FAGraceAccounting  (abstract, second interface on a policy that counts grace)

Tom2FAEnrolmentStore  (abstract)
    ├── TomMemory2FAEnrolmentStore      (implements)
    └── TomPersistent2FAEnrolmentStore  (implements)

TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int>
    └── TomUserTwoFactorEnrolmentRepository  (extends)

TomServiceLoginTransport  (abstract)
    └── TomHttpServiceLoginTransport  (extends)

TomAuthenticationAdaptor   (@tomReflector, standalone)
Tom2FAAdaptor              (@tomReflector, standalone)
Tom2FAContext              (standalone)
Tom2FAChallengeSpec        (standalone)
Tom2FASubmission           (standalone)
Tom2FARegistry             (standalone, statics only)
Tom2FARequirement          (enum)
Tom2FADecision             (standalone, immutable)
Tom2FAEnrolment            (standalone, immutable)
Tom2FAEnrolmentOffer       (standalone, immutable)
Tom2FAEnrolmentState       (standalone, immutable)
TomUserTwoFactorEnrolment  (@tomReflector, @TomDbTable entity)
TomAuthenticationData      (@tomReflector, standalone)
TomAuthenticationInfo      (standalone)
TomAuthenticationServer    (@tomReflector, standalone)
TomServiceCredential       (standalone)
TomServiceLoginResponse    (standalone)
TomServerSelfLogin         (standalone, statics only)
TomOAuthProvisioning       (enum)
TomOAuthProviderConfig     (standalone, immutable)
TomOAuthProviders          (standalone, immutable)
TomOAuthPkce               (standalone, immutable)
TomOAuthAuthorizationState (standalone, immutable)
TomExternalIdentity        (standalone, immutable)
TomOAuthExchange           (standalone, immutable)
TomOAuthFlow               (standalone, immutable)
TomExternalIdentityLink    (@tomReflector, @TomDbTable entity)
TomOAuthCredential         (standalone, immutable)
TomOAuthServer             (@tomReflector, @TomApiImplementation)
```

## Classes

### TomAuthenticationAdaptor

Reflection-discoverable marker (`@tomReflector`) that tags a class as an
authentication adaptor and constrains which login flows it participates in.

#### Constructors

```dart
TomAuthenticationAdaptor({bool guestOnly = false, bool userOnly = false})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `guestOnly` | `bool` | Whether this adaptor handles only guest logins. |
| `userOnly` | `bool` | Whether this adaptor handles only authenticated-user logins. |

### Tom2FAAdaptor

Reflection-discoverable marker (`@tomReflector`) that tags a class as a
server-side two-factor (2FA) adaptor for a given `type`. The annotated class
must implement `Tom2FAService` and expose a no-argument constructor;
`Tom2FARegistry` discovers it by reflection and instantiates it once.

#### Constructors

```dart
const Tom2FAAdaptor(String type)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The 2FA mechanism this adaptor implements (e.g. `'totp'`, `'sms'`). |

### LoginException

A server-side login failure carrying the `TomServerException` payload.
Thrown by a `TomAuthenticationService` when a login cannot succeed;
`TomAuthenticationServer` catches it and turns its `key` into a failed result.

- **Extends:** `TomServerException`

#### Constructors

```dart
LoginException(
  String key,
  String userMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### Tom2FAException

A 2FA *configuration* fault — a duplicate or unusable adaptor registration, or a
mechanism that cannot be constructed. Distinct from `LoginException`: a wrong
code is an expected outcome and yields a failed `TomAuthenticationResult`, while
a wrongly wired deployment must surface loudly. Constructed with
`clientThrow: false`, so an authentication misconfiguration is never described
to the caller.

- **Extends:** `TomServerException`

#### Constructors

```dart
Tom2FAException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomAuthenticationData

The data carried into a single authentication attempt (reflection-discoverable,
`@tomReflector`). Identifies what is being logged into and who, plus the
credential and client locale. Fields are mutable so a service can enrich them.

#### Constructors

```dart
TomAuthenticationData({
  required String username,
  Object? key,
  required String organization,
  required String application,
  required String process,
  required String language,
  required String country,
  required String timezone,
  required String client,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `organization` | `String` | The organization being logged into. |
| `application` | `String` | The application being logged into. |
| `process` | `String` | The process (sub-context of the application) being logged into. |
| `language` | `String` | The client's language code. |
| `country` | `String` | The client's country code. |
| `timezone` | `String` | The client's timezone identifier. |
| `client` | `String` | The client (front-end) identifier the login originates from. |
| `username` | `String` | The login name of the user (or `"GUEST"` for guest logins). |
| `key` | `Object?` | The credential to verify (typically the password); `null` for guests. |

### TomAuthenticationService

The contract an application implements to authenticate a login
(reflection-discoverable, `@tomReflector`). Implementations resolve the
`TomAuthenticationData` against their user store and return a
`TomAuthenticationInfo`, or throw a `LoginException` on failure.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateUser` | `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)` | Authenticates `authData`, returning the principal and its access rights, or throwing a `LoginException` when rejected. |

### Tom2FAContext

Everything an adaptor is told about the login it is challenging: the identity
being authenticated plus the tenant and locale coordinates of the attempt. An
adaptor needing more resolves it from its own configuration.

#### Constructors

```dart
const Tom2FAContext({
  required TomPrincipal principal,
  String client = '',
  String organization = '',
  String application = '',
  String process = '',
  String language = '',
  String country = '',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `principal` | `TomPrincipal` | The principal produced by the first pass. Not yet an authenticated session — it is exactly this principal's second factor that is in question. |
| `client` | `String` | The client (front-end) identifier the login originates from. |
| `organization` | `String` | The organization being logged into. |
| `application` | `String` | The application being logged into. |
| `process` | `String` | The process (sub-context of the application) being logged into. |
| `language` | `String` | The client's language code, for localising a delivered message. |
| `country` | `String` | The client's country code, for localising a delivered message. |

### Tom2FAChallengeSpec

What an adaptor produces when asked to issue a challenge. The split between
`clientData` and `verificationData` is the point: the first is what the client
may see, the second is what only the server may see.

#### Constructors

```dart
const Tom2FAChallengeSpec({
  String hint = '',
  Map<String, Object?> clientData = const {},
  Map<String, Object?> verificationData = const {},
  int attemptsAllowed = 3,
  Duration validity = const Duration(minutes: 5),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `hint` | `String` | A short, displayable hint (a masked phone number, a device name). Empty when the mechanism has nothing worth showing. |
| `clientData` | `Map<String, Object?>` | The mechanism's client-visible payload; carried in the interim token's public claims and interpreted only by the mechanism's own client code. |
| `verificationData` | `Map<String, Object?>` | The mechanism's server-only payload; carried in the interim token's encrypted section and handed back to `verifySubmission`. |
| `attemptsAllowed` | `int` | How many submissions this challenge tolerates before it is burned. |
| `validity` | `Duration` | How long the challenge stays answerable. |

### Tom2FASubmission

One answer to a challenge, as presented to the adaptor.

#### Constructors

```dart
const Tom2FASubmission({
  required String submitted,
  required Tom2FAChallenge challenge,
  Map<String, Object?> verificationData = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `submitted` | `String` | What the user submitted (the typed code, the signed assertion, …). |
| `challenge` | `Tom2FAChallenge` | The challenge being answered, with this attempt already counted — so `challenge.attemptsRemaining` reads as it will *after* this submission. |
| `verificationData` | `Map<String, Object?>` | The `Tom2FAChallengeSpec.verificationData` recovered from the interim token's encrypted section; empty when the adaptor stored none. |

### Tom2FAService

The contract a second-factor mechanism implements (reflection-discoverable,
`@tomReflector`). Two questions, and only two: what challenge should this user
be given, and is this submission correct? Expiry, attempt counting, dispatch and
token issuance are the framework's job. Implementations must be stateless
between calls — pass 1 and pass 2 may run in different isolates or on different
server instances, so anything the adaptor needs to remember belongs in
`Tom2FAChallengeSpec.verificationData`. An adaptor that can also be *set up*
through a login implements `Tom2FAEnrolmentSupport` in addition.

- **Abstract**

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `descriptor` | `Tom2FAMethodDescriptor` | How this mechanism presents itself in a list of options — an identifier plus three resource keys, never literal text. On the service rather than on the registry because only the mechanism knows what it is called; a registry holding the descriptions would need editing every time an adaptor was added. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | Issues a challenge for `context`, or throws `LoginException` when this user cannot be challenged at all (no enrolled device, no configured secret). |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | Whether `submission` correctly answers the challenge. Returns `false` for a wrong answer; throws only when verification could not be *performed*. |

### Tom2FARegistry

Resolves a mechanism key to the adaptor that implements it. Populated on first
use by scanning the reflection registry for classes annotated `Tom2FAAdaptor`; a
deployment can also register an adaptor built by hand. Registration is
idempotent per key and rejects a second, *different* adaptor for the same key.
Statics only — the constructor is private.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `registeredTypes` | `Set<String>` | The mechanism keys currently resolvable, scanning if needed. |
| `availableMethods` | `List<Tom2FAMethodDescriptor>` | How every registered mechanism describes itself, for a client that must render a choice. Derived from the registry rather than configured beside it, so "installed" and "describable" cannot drift. Every principal sees the same list — narrowing it to one user's permitted mechanisms is `Tom2FADecision.offerableMechanisms`' job. |
| `enrollableMethods` | `List<Tom2FAMethodDescriptor>` | The subset of `availableMethods` whose adaptors implement `Tom2FAEnrolmentSupport`. "Verifiable here" and "enrollable here" are different questions: a hardware token an administrator hands out is the first and not the second, and an enrolment step offering it would present a choice that cannot be acted on. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String type, Tom2FAService service)` | Registers `service` under `type`. Throws `Tom2FAException` (`authentication.2fa.duplicate_adaptor`) if a different adaptor is already registered for `type`; re-registering the identical instance is a no-op. |
| `lookup` | `static Tom2FAService? lookup(String type)` | The adaptor for `type`, or `null` when the mechanism is unknown here. Triggers the annotation scan on first use. |
| `enrolmentSupportFor` | `static Tom2FAEnrolmentSupport? enrolmentSupportFor(String type)` | The adaptor for `type` when it can also be enrolled, else `null` — the one place the `is` check is made, so callers ask "can this be set up here?" rather than reproducing the test. |
| `registerAnnotated` | `static void registerAnnotated(Iterable<ClassMirror> candidates)` | Registers every class in `candidates` carrying a `Tom2FAAdaptor` annotation. Throws `Tom2FAException` on the first unusable candidate (`authentication.2fa.adaptor_instantiation_failed`, `authentication.2fa.adaptor_does_not_implement_service`), naming it — an adaptor set that is wrong is wrong at start-up. |
| `reset` | `static void reset()` | Drops every registration and forces a re-scan on next use. For tests. |

### Tom2FARequirement

How much second factor a login owes. Ordered, so that a principal matching
several rules can be given the strictest of them.

| Value | Meaning |
| ----- | ------- |
| `disabled` | No second factor. The login completes on the primary credential alone. |
| `optional` | Offered, but the login can complete without one — a user with no factor is offered enrolment and may decline at no cost. |
| `required` | Must be satisfied before an authorization token is issued. A user with no factor is offered enrolment and may decline only against a grace login. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `strictest` | `Tom2FARequirement strictest(Tom2FARequirement other)` | Whichever of the two demands more, by declaration order. What lets a policy fold several matched roles into one answer without spelling out the comparison. |

### Tom2FADecision

One policy answer about one login: how much is required, which mechanisms may
answer for it, and how much grace remains. Immutable — `allowedMechanisms` is
wrapped unmodifiable at construction.

#### Constructors

```dart
Tom2FADecision({
  required Tom2FARequirement requirement,
  List<String> allowedMechanisms = const [],
  int graceLogins = 0,
})
```

*(asserts `graceLogins >= 0`)*

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `requirement` | `Tom2FARequirement` | What this login owes. |
| `allowedMechanisms` | `List<String>` | The mechanism keys this principal may use, in **preference order** — the first is chosen when nothing else narrows it. Unmodifiable. |
| `graceLogins` | `int` | How many more times this principal may decline a `required` factor. `0` means none. |
| `offerableMechanisms` | `List<String>` | `allowedMechanisms` intersected with `Tom2FARegistry.registeredTypes`. Permission and availability are separate questions — a policy says what a user *may* use, the registry says what this process *can* run — and intersecting them here turns a wiring fault into `login.error.2fa.unsupported-mechanism` at the login rather than a null adaptor further on. |
| `isSatisfiedWithoutFactor` | `bool` | `true` only for `disabled`. The single test the server makes, so a policy meaning "no factor" says it once. |

### Tom2FAPolicy

Decides, per login, whether a second factor is owed. A decision and not a field
read: `TomPrincipal.requires2FA` can say *this user must* and *this user need
not*, but not *everyone in role `admin` must*, not *offer it but let them
decline*, and not *insist, after three more logins*.

- **Abstract**

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static Tom2FAPolicy resolve()` | The policy bean registered for `Tom2FAPolicy`, else `TomPrincipalFlag2FAPolicy`. Non-nullable with a meaningful fallback — unlike `Tom2FAEnrolmentStore.resolve()`, because "behave as this deployment did before policies existed" is a real answer here and "nobody records enrolments" is not one a store could give. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `decideFor` | `Future<Tom2FADecision> decideFor(Tom2FAContext context)` | The decision for this login. Called once per login, after the primary credential has been accepted. |

### TomPrincipalFlag2FAPolicy

The default policy, and the one that makes installing none a no-op: it reads
`TomPrincipal.requires2FA` and `twoFactorType` off the principal, exactly as the
server did before policies existed. `const`, so the fallback costs no
allocation. A principal that requires a factor but names no type yields
`required` with **no** allowed mechanism — the login then fails with
`login.error.2fa.unsupported-mechanism`, which is the honest outcome for an
account that has been told it must use a mechanism nobody named.

- **Implements:** `Tom2FAPolicy`

#### Constructors

```dart
const TomPrincipalFlag2FAPolicy()
```

### TomRole2FAPolicy

States the requirement per **role** rather than per user, which is the shape
most deployments actually want: "everyone in `admin`", not a flag maintained on
every account. Roles are read from `context.principal.aci.roles`, and a
principal holding several gets the **strictest** of their requirements. Carries
no `@TomComponent` — installing it is a deliberate `TomBean.withType`, because a
policy picked up by a component scan would silently start demanding second
factors from a deployment that only added a dependency.

- **Implements:** `Tom2FAPolicy`

#### Constructors

```dart
TomRole2FAPolicy({
  Map<String, Tom2FARequirement> requirementByRole = const {},
  Tom2FARequirement defaultRequirement = Tom2FARequirement.disabled,
  List<String>? mechanisms,
  int graceLogins = 0,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `requirementByRole` | `Map<String, Tom2FARequirement>` | Role name → requirement. Unmodifiable. |
| `defaultRequirement` | `Tom2FARequirement` | What a principal matching no listed role owes. `disabled` unless stated, so adding the policy changes nothing for anyone not named. |
| `mechanisms` | `List<String>?` | Which mechanisms the permitted logins may use. **`null` means the policy does not restrict the choice** — every registered mechanism is offered; a non-empty list means those, in that order; `[]` means none is permitted, which makes a `required` decision unsatisfiable. |
| `graceLogins` | `int` | Carried into every non-`disabled` decision. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `decideFor` | `Future<Tom2FADecision> decideFor(Tom2FAContext context)` | *(override)* Folds the principal's matched roles with `strictest`, then returns a decision. A `disabled` outcome carries no mechanisms at all — naming them for a login that will never be challenged only suggests they matter. |

### Tom2FAGraceAccounting

The second interface a `Tom2FAPolicy` implements when its `graceLogins` are
meant to run out. `graceLogins` is a number the policy supplies, so only the
policy can know how it is spent; a policy that does not implement this grants
the same grace on every login, which is a valid "warn, do not enforce yet"
deployment rather than an error.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordGraceLoginConsumed` | `Future<void> recordGraceLoginConsumed(Tom2FAContext context)` | Called at the moment grace is **spent** — a user declining an offer that was declinable because of grace — and never when the offer was merely made, nor for an `optional` decline, which costs nothing. |

### Tom2FAEnrolment

One second factor a principal has set up: what mechanism it is, how to name it
to the user, and whatever the mechanism needs to verify it later.

#### Constructors

```dart
Tom2FAEnrolment({
  required String type,
  required String enrolmentId,
  String hint = '',
  DateTime? enrolledAt,
  bool isPrimary = false,
  Map<String, Object?> secretData = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism key — the same value `Tom2FARegistry.lookup` resolves. |
| `enrolmentId` | `String` | Identifies this enrolment among the principal's own. Chosen by whoever enrolled, not by the store, so a mechanism can make re-enrolment an upsert by reusing a stable id (`TomTotp2FAService` uses its `mechanismType`). |
| `hint` | `String` | What to show the user about this factor — a masked address, a device name. User *data*, deliberately not a resource key: a resource bundle cannot contain one entry per user's phone. |
| `enrolledAt` | `DateTime` | When it was set up, normalised to UTC. |
| `isPrimary` | `bool` | Whether this is the factor a login challenges by default. The first factor a user confirms is stored primary, so the next login has something to challenge without anyone nominating it. |
| `secretData` | `Map<String, Object?>` | The mechanism's own material. Treated as secret **in full** — encrypted at rest by `TomPersistent2FAEnrolmentStore` and never printed by `toString`. Unmodifiable. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `copyWith` | `Tom2FAEnrolment copyWith({String? type, String? enrolmentId, String? hint, DateTime? enrolledAt, bool? isPrimary, Map<String, Object?>? secretData})` | A copy with the named fields replaced. |

### Tom2FAEnrolmentOffer

What a mechanism proposes when a user begins setting it up — everything the
client needs to act on, plus everything the server needs to check the answer,
and **no stored state**. Nothing is written until the offer is confirmed.

#### Constructors

```dart
const Tom2FAEnrolmentOffer({
  required String type,
  String hint = '',
  Map<String, Object?> clientData = const {},
  Map<String, Object?> enrolmentData = const {},
  int attemptsAllowed = 3,
  Duration validity = const Duration(minutes: 10),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism being set up. |
| `hint` | `String` | What to tell the user about the destination or device. |
| `clientData` | `Map<String, Object?>` | Public — travels in the interim token's public claims. For TOTP, the secret and the `otpauth://` URI to scan. |
| `enrolmentData` | `Map<String, Object?>` | Server-only — travels in the **encrypted** section, and is what the confirmation checks against. A confirmation that trusted the public copy could be told to accept a secret the client chose. |
| `attemptsAllowed` | `int` | How many confirmations may be attempted. Defaults to `3`. |
| `validity` | `Duration` | How long the offer stays confirmable. Defaults to 10 minutes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toClaim` | `Map<String, Object?> toClaim()` | The offer as one encrypted claim value. |
| `fromClaim` | `static Tom2FAEnrolmentOffer? fromClaim(Object? claim)` | Reads back what `toClaim` wrote, or `null` when the claim is not one — an unreadable offer degrades the pending state to *choose a mechanism* rather than throwing. |

### Tom2FAEnrolmentSupport

What an adaptor adds to become **enrollable**: begin an offer, confirm it.

A contract separate from `Tom2FAService` rather than two more methods on it,
because not every mechanism can be set up through a login — a hardware token an
administrator provisions is verifiable here and enrollable nowhere — and
widening the base contract would force such an adaptor to carry a throw-only
body. Keeping them apart makes "can this be enrolled?" a real question, answered
by `Tom2FARegistry.enrolmentSupportFor` for one mechanism and
`enrollableMethods` for the catalog.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | Proposes a setup for `context`, or throws `LoginException` when this principal cannot enrol this mechanism at all (`login.error.2fa.no-destination` for a delivered code with no address on record). |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | Checks `submitted` against `offer` and yields the enrolment to store. **Throws** rather than returning a nullable enrolment, so a caller cannot store an unconfirmed factor by forgetting a null check. |

### Tom2FAEnrolmentState

The server's view of one pending enrolment, carried in an interim token: which
mechanisms were offered, whether declining is permitted, and — once one is
chosen — the offer itself and how many attempts it has left. Immutable; every
transition returns a new state.

#### Constructors

```dart
Tom2FAEnrolmentState({
  List<String> offeredTypes = const [],
  bool skippable = false,
  bool skipSpendsGrace = false,
  Tom2FAEnrolmentOffer? offer,
  DateTime? expiresAt,
  int attempt = 0,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `offeredTypes` | `List<String>` | The mechanism keys offered, in preference order. The **server's** list — a chosen type not in it is refused with `login.error.2fa.enrolment-not-offered`. |
| `skippable` | `bool` | Whether the offer may be declined. Server-signed, so a client that decides for itself that it may decline achieves nothing. |
| `skipSpendsGrace` | `bool` | Whether declining costs a grace login — true for a `required` decision softened by grace, false for an `optional` one. |
| `offer` | `Tom2FAEnrolmentOffer?` | The chosen mechanism's offer, or `null` while the user is still choosing. |
| `expiresAt` | `DateTime?` | When the offer stops being confirmable. |
| `attempt` | `int` | How many confirmations have been spent. |
| `hasOffer` | `bool` | Whether a mechanism has been chosen — the two states a client renders differently. |
| `attemptsRemaining` | `int` | `offer.attemptsAllowed - attempt`, floored at zero. |
| `isExhausted` | `bool` | Whether an offer exists and has no attempts left. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isExpired` | `bool isExpired({DateTime? now})` | Whether the offer has lapsed. |
| `withOffer` | `Tom2FAEnrolmentState withOffer(Tom2FAEnrolmentOffer chosen, {DateTime? now})` | The state after a mechanism is chosen. Restarts the attempt counter — the attempts belong to the offer, so choosing a different mechanism starts a fresh budget. |
| `withConsumedAttempt` | `Tom2FAEnrolmentState withConsumedAttempt()` | The state after one confirmation has been spent. |
| `toClaims` | `Map<String, Object?> toClaims()` | The public half, for the interim token's claims. |
| `secretClaims` | `Map<String, Object?>?` | The encrypted half — the offer's `enrolmentData` — or `null` when nothing has been chosen. |
| `fromClaims` | `static Tom2FAEnrolmentState? fromClaims(Map<String, dynamic>? payload, [Map<String, dynamic>? secretData])` | Reads a pending enrolment back out of a token, or `null` when it carries none. An offer that cannot be decrypted degrades to the *offered* shape rather than throwing, so an undecryptable token sends the user back to the choice instead of failing the login. |

### Tom2FAEnrolmentStore

Where a principal's set-up factors live. Deployment-supplied: the framework
knows what an enrolment *is* but not where this deployment keeps its user data.

**`resolve()` is nullable and has no fallback, deliberately.** An empty fallback
store would be indistinguishable from a real store holding nothing, and the
server draws exactly that distinction: `null` means *no store is installed*, so
the login is challenged as it was before enrolment existed and the mechanism
stays the only authority on whether the user has a factor; an empty list means
*a store is installed and this user has enrolled nothing*, which routes the
login into the enrolment offer. Collapsing the two would force enrolment on
every deployment that never opted in.

- **Abstract**

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static Tom2FAEnrolmentStore? resolve()` | The store bean registered for `Tom2FAEnrolmentStore`, or `null` when none is installed. |
| `principalKeyOf` | `static String principalKeyOf(Tom2FAContext context)` | The key a store files a principal's enrolments under — `context.principal.id`, stringified, matching `TomPrincipalResourceGrant.principalId`. One place, so the memory store and the persistent store cannot disagree on what "this user" means. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `enrolmentsFor` | `Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context)` | This principal's factors; empty when they have none. |
| `store` | `Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment)` | Saves `enrolment`, **upserting on `enrolmentId`** — so re-enrolling a mechanism replaces the old factor instead of accumulating one per attempt. |
| `remove` | `Future<void> remove(Tom2FAContext context, String enrolmentId)` | Deletes an enrolment. An id that is not there is a no-op, so a double-delete is not an error. |

### TomMemory2FAEnrolmentStore

Enrolments in a map, for tests and single-process development. Everything is
lost on restart, which is the right behaviour for a store whose purpose is to be
predictable rather than durable.

- **Implements:** `Tom2FAEnrolmentStore`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clear` | `void clear()` | Drops every enrolment. For tests. |

### TomUserTwoFactorEnrolment

One persisted enrolment row (`@tomReflector`,
`@TomDbTable(datasource: 'main', table: 'tom_user_two_factor_enrolment',
primaryKeyField: 'id')`). Columns: `id`, `principal_id`, `enrolment_id`,
`mechanism`, `hint`, `enrolled_at`, `is_primary`, `secret_data` — the last held
as `secretDataCipher`, base64 of RSA-OAEP over the secret map's JSON, never
readable from the row alone. A `UNIQUE KEY (principal_id, enrolment_id)` makes
the upsert the database's rule and not only the store's; without it, which
secret answers a login would depend on row order. Every field defaults, because
the repository instantiates a blank entity and fills it column by column.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `String` | The table's DDL, for a deployment's migration to run. The framework creates no tables of its own. |

### TomUserTwoFactorEnrolmentRepository

`TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int>` — an ordinary
repository with no added behaviour, because the mapping is ordinary.

### TomPersistent2FAEnrolmentStore

The durable store: rows in `tom_user_two_factor_enrolment`, with `secretData`
JSON-encoded and **encrypted at rest** — RSA-OAEP through
`TomJwtConfiguration.encrypt`, base64-wrapped for a `TEXT` column. By default
that is the same key pair protecting a token's encrypted claims, so a deployment
configures one secret and not two; passing `cipher` decouples them, which a
deployment rotating its signing key often will want, since an enrolment secret
outlives it. An empty map is stored as an empty string rather than as ciphertext
of `{}`. A row that cannot be decrypted — written under a key since rotated away
— yields an **empty** secret map rather than throwing: the honest reading is
*this factor cannot answer a challenge*, and throwing would fail the whole
login, including the user's other, perfectly good factors.

- **Implements:** `Tom2FAEnrolmentStore`

#### Constructors

```dart
const TomPersistent2FAEnrolmentStore(
  TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int> repository, {
  TomJwtConfiguration? cipher,
})
```

*(`cipher` is resolved **per call**, falling back to
`TomJwtConfiguration.defaultSignConfiguration`, so production keys installed
after boot are obeyed)*

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int>` | Where rows are read and written. |

### TomTotpSecretResolver

Resolves the shared TOTP secret for the user being challenged, or `null` when
that user has no authenticator enrolled. The returned secret is the base32
string an authenticator app was provisioned with.

```dart
typedef TomTotpSecretResolver = FutureOr<String?> Function(
  Tom2FAContext context,
);
```

### TomTotp2FAService

The built-in RFC 6238 time-based one-time-password adaptor
(`@Tom2FAAdaptor('totp')`, `@tomReflector`). It needs no delivery channel, so
the whole path — challenge, submission, verification, retry — is exercisable
without an SMS gateway or mail server. The derivation itself is the kernel's
`TomTotp`; what lives here is only policy: which secret, how many digits, how
much clock skew to tolerate, how many attempts. The secret is read from the
installed `Tom2FAEnrolmentStore` under `secretDataKey`, falling back to
`globalSettingSecretResolver` when no store is installed or it holds no TOTP
enrolment for this user — which is what makes migrating one user at a time
possible. It is deliberately *not* read from `TomUser.attributes` (those are
projected into the token's public claims), and nothing is stored in
`verificationData` — the secret is re-resolved on pass 2, so it never travels.

It is also enrollable: `beginEnrolment` generates a secret and hands back both
the base32 string and an `otpauth://` URI built from **this verifier's own**
digits and period, so the authenticator is provisioned with the policy that will
be applied to it, and `confirmEnrolment` refuses to yield an enrolment until the
user has typed back a code derived from that very secret.

- **Implements:** `Tom2FAService`, `Tom2FAEnrolmentSupport`

#### Constructors

```dart
TomTotp2FAService()
```

*(no-argument, so the registry can reflect it into life)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mechanismType` | `String` | The mechanism key this adaptor answers to: `'totp'`. |
| `secretDataKey` | `String` | The key this adaptor's base32 secret is filed under in `Tom2FAEnrolment.secretData`: `'secret'`. Named rather than inlined because an enrolment tool writes the map this adaptor reads, and a typo on either side presents as *not enrolled* — the one failure mode indistinguishable from the ordinary case. |
| `clientDataUriKey` | `String` | The key the `otpauth://` URI travels under in an offer's `clientData`: `'otpauthUri'`. |
| `globalSettingSecretResolver` | `TomTotpSecretResolver?` | Resolves a user's base32 TOTP secret. Consulted only when the enrolment store has nothing; unset by default, so with neither, every TOTP challenge fails with `login.error.2fa.not-enrolled`. |
| `globalSettingDigits` | `int` | Number of digits in a generated code. Defaults to `TomTotp.defaultDigits` (6). |
| `globalSettingPeriod` | `Duration` | Length of one time step. Defaults to `TomTotp.defaultPeriod` (30 s). |
| `globalSettingWindowSteps` | `int` | How many time steps either side of "now" are accepted, to tolerate clock skew. Defaults to `1`. |
| `globalSettingAttemptsAllowed` | `int` | How many submissions one challenge tolerates. Defaults to `3`. |
| `globalSettingChallengeValidity` | `Duration` | How long a challenge stays answerable. Defaults to 5 minutes. |
| `globalSettingIssuer` | `String` | The name the authenticator app files this account under, shown beside the code. Empty (the default) means *use the application being logged into* — a framework that hardcoded it would put the same word in every deployment's authenticator. |
| `globalSettingSecretBytes` | `int` | How much entropy a generated secret carries, in bytes. Defaults to `20`. |
| `globalSettingEnrolmentAttemptsAllowed` | `int` | How many confirmation attempts one enrolment offer tolerates. Defaults to `3`. |
| `globalSettingEnrolmentValidity` | `Duration` | How long an enrolment offer stays confirmable. Defaults to 10 minutes. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `descriptor` | `Tom2FAMethodDescriptor` | *(override)* `Tom2FAMethodDescriptor.scoped('totp')` — the keys `two_factor.totp.name` / `.description` / `.icon`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Resolves the secret — throwing `LoginException('login.error.2fa.not-enrolled')` when there is none — and returns a spec whose `clientData` names the code shape (`digits`, `periodSeconds`) so a UI can size its input field. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Re-resolves the secret and compares the trimmed submission against the codes in the skew window, in constant time. Rejects a submission of the wrong width before hashing. |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | *(override)* Generates a secret and offers it as `clientData` — the base32 string plus the `otpauth://` URI under `clientDataUriKey` — with the secret also held in the offer's server-only `enrolmentData`. |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | *(override)* Checks `submitted` against the offered secret and yields the enrolment to store, filed under `enrolmentId: mechanismType` so re-enrolling replaces the old authenticator instead of accumulating one per attempt. Throws `LoginException` otherwise. |
| `generateSecret` | `static String generateSecret()` | A fresh base32 secret of `globalSettingSecretBytes` bytes from the framework's CSPRNG. |
| `provisioningUri` | `static String provisioningUri(String secret, Tom2FAContext context)` | The `otpauth://totp/...` URI an authenticator app scans, carrying this verifier's own digits and period. |
| `issuerFor` | `static String issuerFor(Tom2FAContext context)` | `globalSettingIssuer`, or the application being logged into when it is empty. |
| `expectedCode` | `static String expectedCode(String secret, {DateTime? at})` | The code this verifier expects right now for the base32 `secret` — the adaptor's own policy applied to `TomTotp`. For enrolment self-checks and tests. |

### TomDeliveredCode2FAService

The shape shared by every second factor that **sends a code somewhere**. Unlike
TOTP there is nothing to re-derive on pass 2, so this is the mechanism family
that actually uses `Tom2FAChallengeSpec.verificationData`: it carries a random
salt and the SHA-256 of `salt + code`, never the code, because the map travels
in a token the client holds. Delivery happens *before* the spec is built and
synchronously (`TomTemplatedMessageService.deliverNow`, not the outbox) — a code
that outlives its challenge is worse than none, so an undelivered code fails the
login rather than becoming a prompt nobody can answer. Subclasses supply four
things: `type`, `destinationOnRecord`, `maskDestination` and `deliver`.

- **Implements:** `Tom2FAService`, `Tom2FAEnrolmentSupport`
- **Abstract**

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `destinationKey` | `String` | Key the destination is filed under in `Tom2FAEnrolment.secretData` and `Tom2FAEnrolmentOffer.enrolmentData`: `'destination'`. |
| `saltKey` | `String` | Key the code's random salt is filed under: `'salt'`. |
| `hashKey` | `String` | Key the salted hash is filed under: `'codeHash'` — named for the hash so that filing the code here would be visible at the assignment. |
| `maskedDestinationKey` | `String` | Key the *masked* destination is filed under in the client payload: `'destination'`. |
| `digitsKey` | `String` | Key the code's length is filed under in the client payload, so a UI can size its input: `'digits'`. |
| `saltBytes` | `int` | Bytes of salt per sealed code: `16` — enough that no two challenges share a salt, which is what stops a table of hashes of every six-digit code being precomputed once. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | *(abstract)* The mechanism key, and the scope its resource keys live under (`two_factor.<type>.*`). |
| `codeDigits` | `int` | *(abstract)* How many digits a generated code carries. |
| `attemptsAllowed` | `int` | *(abstract)* How many submissions one challenge tolerates. |
| `challengeValidity` | `Duration` | *(abstract)* How long a challenge stays answerable. |
| `challengeTemplateKey` | `String` | *(abstract)* Resource key prefix of the message carrying a login code. |
| `enrolmentTemplateKey` | `String` | *(abstract)* Resource key prefix of the message carrying an enrolment code. |
| `enrolmentAttemptsAllowed` | `int` | *(abstract)* How many confirmation attempts one enrolment offer tolerates. |
| `enrolmentValidity` | `Duration` | *(abstract)* How long an enrolment offer stays confirmable. |
| `descriptor` | `Tom2FAMethodDescriptor` | *(override)* `Tom2FAMethodDescriptor.scoped(type)` — resource keys only, no literal text. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(abstract)* The destination on the **user record**, or `null`. The asserted address; enrolment is what turns it into a proven one. |
| `maskDestination` | `String maskDestination(String destination)` | *(abstract)* `destination` reduced to what is safe to show a caller who has not yet proved anything. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {required String destination, required String code, required String templateKey, required Duration validity})` | *(abstract)* Sends `code` through this adaptor's channel. Must complete only once a transport has accepted the message, and must throw otherwise. |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Resolves the destination (throwing `login.error.2fa.not-enrolled` when there is none), delivers a fresh code, then returns a spec whose `clientData` holds the masked destination and the digit count and whose `verificationData` holds the sealed code. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Re-hashes the trimmed submission against the seal, in constant time. |
| `resolveDestination` | `Future<String?> resolveDestination(Tom2FAContext context)` | The destination a challenge goes to: the **confirmed** enrolment first, then the record — so an attacker who can edit a profile field cannot redirect the second factor. A malformed enrolment row is skipped rather than treated as an answer. |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | *(override)* Sends a code to the destination **on record** (not the confirmed one — that would be a tautology) and returns an offer carrying the sealed code and the destination in its encrypted half. Throws `login.error.2fa.no-destination` when the record names none. |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | *(override)* Yields an enrolment only when `submitted` matches; throws `login.error.2fa.enrolment-code-invalid` (or `.enrolment-offer-invalid` for an offer with no destination) rather than returning a nullable, so an unproven destination cannot be stored by forgetting a check. `enrolmentId` is the mechanism type, making re-confirmation an upsert. |
| `deliverOrFail` | `Future<void> deliverOrFail(Tom2FAContext context, {required String destination, required String code, required String templateKey, required Duration validity})` | Calls `deliver` and turns an unclassified failure into `LoginException('login.error.2fa.delivery-failed')`, logged, with the cause attached. `LoginException` and `Tom2FAException` pass through unchanged — both are already classified, and a wiring fault has a different owner from a relay that is down. |
| `localeFor` | `TomTextLocale? localeFor(Tom2FAContext context)` | The principal's stored language first, then the login attempt's client locale, then `null` so the bundle set applies its own default. |
| `templateParameters` | `Map<String, Object?> templateParameters(Tom2FAContext context, {required String code, required Duration validity})` | `code`, `minutes`, `username`, `firstname`, `lastname`, `application` — supplied whether or not a template mentions them. |
| `generateNumericCode` | `static String generateNumericCode(int digits)` | A decimal code from `RsaKeyHelper.getSecureRandom()`, rejection-sampled so `0`–`5` are no likelier than `6`–`9`. |
| `sealCode` | `static Map<String, Object?> sealCode(String code)` | `code` reduced to a fresh salt and a SHA-256 — the only form of it that may travel. |
| `matchesSealedCode` | `static bool matchesSealedCode(Map<String, Object?> sealed, String submitted)` | Whether `submitted` is the code `sealed` was built from. `false`, never a throw, for a malformed or absent seal. |
| `constantTimeEquals` | `static bool constantTimeEquals(String a, String b)` | Compares without leaking, through timing, how much of a submission was right. |

### TomEmailCode2FAService

A one-time code delivered by email (`@Tom2FAAdaptor('email')`, `@tomReflector`).
Resolves `TomEmailService` from the bean locator at call time; a deployment that
registered none gets `Tom2FAException('authentication.2fa.email.no_service')`,
which is a wiring fault and not a delivery failure. The address comes from the
user's confirmed `'email'` enrolment, falling back to `TomUser.email`.

- **Extends:** `TomDeliveredCode2FAService`

#### Constructors

```dart
TomEmailCode2FAService()
```

*(no-argument, so the registry can reflect it into life)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mechanismType` | `String` | The mechanism key: `'email'`. |
| `globalSettingCodeDigits` | `int` | Digits per code. Defaults to `6`, matching TOTP — the user types into the same field. |
| `globalSettingAttemptsAllowed` | `int` | Submissions one challenge tolerates. Defaults to `3`. |
| `globalSettingChallengeValidity` | `Duration` | Defaults to 10 minutes — longer than TOTP's five, because a mail may be greylisted and then has to be found in an inbox. |
| `globalSettingChallengeTemplateKey` | `String` | Resource key prefix of the login-code mail. Defaults to `'email.two_factor_code'`. |
| `globalSettingEnrolmentTemplateKey` | `String` | Resource key prefix of the enrolment mail. Defaults to `'email.two_factor_enrolment'` — a separate template, because "here is your sign-in code" and "confirm this address" are different sentences. |
| `globalSettingEnrolmentAttemptsAllowed` | `int` | Defaults to `3`. |
| `globalSettingEnrolmentValidity` | `Duration` | Defaults to 15 minutes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(override)* `TomUser.email`. |
| `maskDestination` | `String maskDestination(String destination)` | *(override)* Delegates to `maskEmailAddress`. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {...})` | *(override)* Renders `templateKey` through `TomEmailService.deliverNow`, addressed with the user's display name when the record has one. |
| `maskEmailAddress` | `static String maskEmailAddress(String address)` | `alice@example.com` → `a***e@example.com`. The domain is kept whole — it is what tells a user *which* inbox to open — and a local part of two characters or fewer collapses to `***`. A value with no `@` is masked opaquely rather than rejected. |

### TomSmsCode2FAService

A one-time code delivered by SMS (`@Tom2FAAdaptor('sms')`, `@tomReflector`).
Resolves `TomSmsService` from the bean locator at call time
(`authentication.2fa.sms.no_service` when absent). The number comes from the
user's confirmed `'sms'` enrolment, falling back to `TomUser.mobile` and then
`TomUser.phone` — the same order `TomSmsRequest.toPrincipal` uses, so a code and
a notification reach the same handset.

- **Extends:** `TomDeliveredCode2FAService`

#### Constructors

```dart
TomSmsCode2FAService()
```

*(no-argument, so the registry can reflect it into life)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mechanismType` | `String` | The mechanism key: `'sms'`. |
| `globalSettingCodeDigits` | `int` | Digits per code. Defaults to `6`. |
| `globalSettingAttemptsAllowed` | `int` | Defaults to `3`. |
| `globalSettingChallengeValidity` | `Duration` | Defaults to 5 minutes — a text arrives in seconds, and a one-time code should live no longer than it needs to. |
| `globalSettingChallengeTemplateKey` | `String` | Defaults to `'sms.two_factor_code'`. |
| `globalSettingEnrolmentTemplateKey` | `String` | Defaults to `'sms.two_factor_enrolment'`. |
| `globalSettingEnrolmentAttemptsAllowed` | `int` | Defaults to `3`. |
| `globalSettingEnrolmentValidity` | `Duration` | Defaults to 10 minutes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(override)* The first non-blank of `TomUser.mobile`, `TomUser.phone`. |
| `maskDestination` | `String maskDestination(String destination)` | *(override)* Delegates to `maskPhoneNumber`. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {...})` | *(override)* Renders `templateKey` through `TomSmsService.deliverNow`. |
| `maskPhoneNumber` | `static String maskPhoneNumber(String number)` | `+41791234567` → `+*******4567`. The last four **digits** are kept and non-digits are preserved, so `+41 79 …` and `0041 79 …` still look like the same handset. Counted over digits rather than characters, so spacing does not change which part survives. |

### TomAuthenticationInfo

The successful outcome of a `TomAuthenticationService.authenticateUser` call:
pairs the authenticated principal with its access-control definition.

#### Constructors

```dart
TomAuthenticationInfo(TomPrincipal principal, TomAccessControlDefinition acd)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `principal` | `TomPrincipal` | The authenticated principal (identity, locale, and user record). |
| `acd` | `TomAccessControlDefinition` | The principal's access-control definition (groups and roles). |

### TomDummyAuthenticationService

A no-op `TomAuthenticationService` that authenticates any non-`"GUEST"` user.
Provided as the default so a freshly scaffolded server can issue tokens; logs an
error on every call unless `showErrorMessage` is cleared.

- **Implements:** `TomAuthenticationService`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `showErrorMessage` | `bool` | Whether to log the "you are using the dummy service" error on each call. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateUser` | `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)` | *(override)* Builds a dummy principal (authenticated when username is not `"GUEST"`) and returns it. |

### TomAuthenticationServer

Orchestrates the server-side login flow and issues JWT tokens
(reflection-discoverable, `@tomReflector`). A server endpoint subclasses this
and exposes the pass methods as HTTP endpoints. The service used per flow and
the JWT issuer are selected via the static globals.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingUserAuthenticationService` | `TomAuthenticationService` | The service used for authenticated-user logins (pass 1). Defaults to `TomDummyAuthenticationService()`. |
| `globalSettingGuestAuthenticationService` | `TomAuthenticationService` | The service used for guest logins. Defaults to `TomDummyAuthenticationService()`. |
| `globalSettingJwtOrganization` | `String` | The `iss` (issuer) organization stamped onto issued JWTs. Defaults to `"tom"`. |

#### Constructors

```dart
TomAuthenticationServer()
```

*(implicit default constructor)*

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateGuest` | `Future<TomAuthenticationResult> authenticateGuest(TomAuthenticationMessage m)` | Authenticates a guest login via `globalSettingGuestAuthenticationService`. |
| `authenticatePass1` | `Future<TomAuthenticationResult> authenticatePass1(TomAuthenticationMessage m)` | First pass: validates user credentials via `globalSettingUserAuthenticationService` and issues tokens on success. |
| `authenticatePass2` | `Future<TomAuthenticationResult> authenticatePass2(TomAuthenticationMessage m, {TomClientJwtToken? challengeToken})` | Second pass: answers the challenge issued by pass 1. The submitted factor travels in `m.password`; the challenge is recovered from the interim token the client presents as its bearer (`challengeToken` overrides that lookup, defaulting to the request zone's token). Returns the completed token pair, a re-issued interim token with `login.error.2fa.invalid-code`, or a failed result carrying `login.error.2fa.attempts-exhausted` / `.expired` / `.no-challenge` / `.unsupported-mechanism`. |
| `authenticateUser` | `Future<TomAuthenticationResult> authenticateUser(TomAuthenticationMessage m, bool guestLogin)` | Runs a login: builds `TomAuthenticationData`, delegates to the guest or user service per `guestLogin`, and encodes the principal into the authentication/authorization JWTs of the result. When the principal declares `requires2FA`, issues a challenge through `Tom2FARegistry` instead and returns an interim token. |

### TomServiceCredential

The deployment's own login credential and where to present it. The `credential`
is secret-bearing: supplied out-of-band (OS environment, `.env`, command line)
and never written into a spec or a checked-in configuration tree. `toString` is
redacted.

#### Constructors

```dart
const TomServiceCredential({
  required Uri loginUri,
  required String username,
  required String credential,
  String organization = '',
  String application = '',
  String process = '',
  String client = '',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loginUri` | `Uri` | Absolute URI of the auth server's login endpoint. |
| `username` | `String` | The service account's login name. |
| `credential` | `String` | The service account's secret. Never logged, never serialised anywhere but into the login request body. |
| `organization` | `String` | Multi-tenant context presented with the login; empty when single-tenant. |
| `application` | `String` | The application the deployment logs into. |
| `process` | `String` | The process (sub-context of `application`) the deployment logs into. |
| `client` | `String` | The client identifier the login originates from. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromConfiguration` | `static TomServiceCredential? fromConfiguration(TomBaseServerConfiguration config)` | Reads the credential out of `config`, or returns `null` when self-login is not (or only partially) configured — the supported, silent default. |
| `toRequestBody` | `String toRequestBody()` | The login request body, shaped as the kernel's `TomAuthenticationMessage`. Written by hand so the credential never passes through a general-purpose serialiser. |

### TomServiceLoginTransport

One JSON POST, behind a seam, so the self-login flow can be tested without a
live auth server and so a deployment whose auth server speaks a different
dialect can swap the one HTTP call.

- **Abstract**

#### Constructors

```dart
const TomServiceLoginTransport()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `postJson` | `Future<TomServiceLoginResponse> postJson(Uri uri, String body)` | POSTs `body` as `application/json` to `uri` and returns the raw response. |

### TomServiceLoginResponse

The raw result of a `TomServiceLoginTransport.postJson` call.

#### Constructors

```dart
const TomServiceLoginResponse(int statusCode, String body)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status code. |
| `body` | `String` | The response body, decoded as text. |
| `isSuccess` | `bool` | Whether the status is in the 2xx range. |

### TomHttpServiceLoginTransport

The live transport, over the kernel's `TomServerChannel`. The call is made with
`includeBearerAuthentication: false` — the server has no bearer of its own yet,
which is precisely what this call obtains.

- **Extends:** `TomServiceLoginTransport`

#### Constructors

```dart
const TomHttpServiceLoginTransport()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `postJson` | `Future<TomServiceLoginResponse> postJson(Uri uri, String body)` | *(override)* Opens a `TomServerChannel` to the URI's host and port (scheme default when unspecified), POSTs the body, and closes the channel. |

### TomServerSelfLoginException

Raised when a *configured* deployment fails to log itself in. Never raised for
an unconfigured deployment — that path returns `false` instead. Constructed with
`clientThrow: false`.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomServerSelfLoginException(String key, String defaultUserMessage)
```

Keys raised: `server.selflogin.unreachable`, `server.selflogin.rejected`,
`server.selflogin.bad_response`, `server.selflogin.no_token`,
`server.selflogin.bad_token`.

### TomServerSelfLogin

Logs the deployment in as itself and installs the resulting principal, whose
entitlements are the feature grants of this deployment and therefore cap every
user's grants (the `min(user, server)` meet in the kernel's `TomAccessControl`).
Statics only — the constructor is private.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `logIn` | `static Future<TomPrincipal> logIn(TomServiceCredential credential, {TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(), bool decryptTokens = true})` | Logs in with `credential` and returns the deployment's principal. Throws `TomServerSelfLoginException` when the auth server is unreachable, refuses, answers in an unexpected shape, or returns a token that carries no payload. |
| `loginAndInstall` | `static Future<bool> loginAndInstall(TomBaseServerConfiguration config, {TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(), bool decryptTokens = true})` | Logs in from `config` and installs the principal into `TomServerPrincipal`; returns whether one was installed. Returns `false` silently when self-login is not configured, so a deployment predating server-as-principal behaves exactly as before. Call during startup, before `TomServer.start()`. |

### TomOAuthException

An external-login handshake or provider configuration that could not proceed.
Raised at startup for a malformed `oauth.providers` block, and during a login
for a refused or unverifiable handshake.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomOAuthException(String key, String defaultUserMessage, {bool clientThrow = false})
```

Keys raised: `oauth.config.missing_value`, `oauth.config.not_a_map`,
`oauth.config.provider_not_a_map`, `oauth.config.unknown_provider`,
`oauth.config.unknown_provisioning`, `oauth.flow.unknown_state`,
`oauth.flow.missing_code`, `oauth.flow.token_exchange_rejected`,
`oauth.flow.no_claims_source`, `oauth.flow.no_access_token`,
`oauth.flow.issuer_mismatch`, `oauth.flow.audience_mismatch`,
`oauth.flow.missing_subject`, `oauth.flow.malformed_id_token`,
`oauth.provider.http_error`, `oauth.provider.malformed_json`.

### TomOAuthProvisioning

What a successful external login does when no local account is linked to the
identity. A **configuration choice per provider**, because both answers are
correct for different deployments.

| Value | Meaning |
| ----- | ------- |
| `refuse` | Reject the login. The default, and the right answer where accounts are created by an administrator. |
| `autoProvision` | Create the account through `TomExternalIdentityDirectory.provisionFromExternalIdentity`, and link an existing local account that already carries the asserted username. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomOAuthProvisioning parse(String raw)` | Reads the configured spelling. Throws `oauth.config.unknown_provisioning` for anything else rather than falling back to a default — a typo must not silently enable or disable provisioning. |

### TomOAuthProviderConfig

One identity provider, as data. Immutable.

#### Constructors

```dart
const TomOAuthProviderConfig({
  required String id,
  required String issuer,
  required String authorizationEndpoint,
  required String tokenEndpoint,
  required String clientId,
  required String redirectUri,
  String? userInfoEndpoint,
  String? clientSecret,
  List<String> scopes = const ['openid', 'email', 'profile'],
  bool usePkce = true,
  String subjectClaim = 'sub',
  String usernameClaim = 'email',
  String displayNameClaim = 'name',
  TomOAuthProvisioning provisioning = TomOAuthProvisioning.refuse,
  String displayNameKey = '',
  String iconKey = '',
})

factory TomOAuthProviderConfig.fromMap(String id, Map<Object?, Object?> map)
```

`fromMap` demands every required value rather than defaulting it: a provider
missing its token endpoint is a configuration error, and one that must fail at
startup rather than as a failed login weeks later. `scopes` is accepted as a
YAML list *or* a single space-separated string, which is how every provider's
own documentation writes them.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toDto` | `TomOAuthProviderDto toDto()` | The client-facing descriptor: `id`, `displayNameKey`, `iconKey`. No endpoint, client id or secret reaches a client. |

### TomOAuthProviders

The configured provider set. Immutable.

- **Constant:** `configurationKey = 'oauth.providers'`

#### Constructors

```dart
TomOAuthProviders(Map<String, TomOAuthProviderConfig> providers)
factory TomOAuthProviders.fromConfiguration([TomServerConfigResourceProvider? config])
```

`fromConfiguration` answers an empty set when the key is absent, so calling it
unconditionally at startup is safe — a deployment with no `oauth:` block offers
nothing rather than failing. A *malformed* block still throws: absent and wrong
are different states.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static TomOAuthProviders? resolve()` | The installed bean, or `null`. `null` rather than a throw, because "this deployment offers no external login" is the majority case. |
| `isEmpty` | `bool get isEmpty` | Whether any provider is configured. |
| `descriptors` | `List<TomOAuthProviderDto> get descriptors` | The providers as client-facing DTOs, in configuration order. |
| `lookup` | `TomOAuthProviderConfig? lookup(String id)` | The provider under `id`, or `null`. |
| `operator []` | `TomOAuthProviderConfig operator [](String id)` | The provider under `id`. Throws `oauth.config.unknown_provider` — a request that named a provider must not resolve to some other provider. |

### TomOAuthPkce

A PKCE verifier and its `S256` challenge. Immutable.

- **Constant:** `method = 'S256'`

#### Constructors

```dart
const TomOAuthPkce(String verifier, String challenge)
factory TomOAuthPkce.generate()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `challengeFor` | `static String challengeFor(String verifier)` | The base64url-unpadded SHA-256 of the verifier. |

### TomOAuthAuthorizationState

One pending authorization: the `state` handle, the `providerId`, the `pkce`
pair, `createdAt`, and the login context the flow started in (`client`,
`application`, `process`, `organization`, `clientLanguage`, `clientCountry`,
`clientTimezone`).

The context is recorded here because a provider callback is a browser
navigation with none of its own — replaying it is what makes an external login
land in the organization and locale the user actually started from.

### TomOAuthStateStore

Where pending authorizations live between the redirect out and the callback
back.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `store` | `Future<void> store(TomOAuthAuthorizationState pending)` | Records a pending authorization. |
| `peek` | `Future<TomOAuthAuthorizationState?> peek(String state)` | Reads without spending, so the callback endpoint can build its login context before the credential is authenticated. |
| `consume` | `Future<TomOAuthAuthorizationState?> consume(String state)` | Reads and spends. The single-use guarantee lives here. |
| `resolve` | `static TomOAuthStateStore resolve()` | The installed bean, or a shared `TomOAuthMemoryStateStore`. |

### TomOAuthMemoryStateStore

The default store: a per-process map with a time-to-live.

```dart
TomOAuthMemoryStateStore({Duration timeToLive = const Duration(minutes: 10)})
```

Expired and unknown handles are indistinguishable to a caller. Correct for a
single-node deployment; a cluster installs a shared store (see
[Status and Limitations](../authentication.md#status-and-limitations)).

### TomOAuthTokenTransport

The provider HTTP calls, held behind a contract so a test can stub the provider
and leave every other line of the flow executing for real.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `postForm` | `Future<String> postForm(Uri uri, Map<String, String> form, Map<String, String> headers)` | The token-endpoint call; returns the raw body. |
| `getJson` | `Future<String> getJson(Uri uri, Map<String, String> headers)` | The user-info call, for providers that predate OIDC. |
| `resolve` | `static TomOAuthTokenTransport resolve()` | The installed bean, or `TomHttpOAuthTokenTransport`. |

### TomHttpOAuthTokenTransport

The default transport, over real HTTP. Raises `oauth.provider.http_error` for a
non-2xx answer.

### TomExternalIdentity

What the provider asserted, immutable: `issuer`, `subject`, `username`,
`displayName`, and the raw `claims`. The `(issuer, subject)` pair *is* the
identity — a subject is only unique within its issuer.

### TomOAuthExchange

The result of a completed handshake: the `identity` and the `pending` record it
completed, so the caller can replay the login context the flow captured.

### TomOAuthFlow

The authorization-code + PKCE handshake. Immutable; holds `providers`,
`stateStore` and `transport`.

#### Constructors

```dart
const TomOAuthFlow({
  required TomOAuthProviders providers,
  required TomOAuthStateStore stateStore,
  required TomOAuthTokenTransport transport,
})

factory TomOAuthFlow.fromBeans()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `beginAuthorization` | `Future<TomOAuthAuthorizationDto> beginAuthorization(TomOAuthAuthorizationRequest request)` | Records the pending authorization and answers where to send the browser. Preserves any query the provider's authorization endpoint already carries (some tenanted providers encode the tenant there). |
| `completeAuthorization` | `Future<TomOAuthExchange> completeAuthorization({required String code, required String state})` | Spends the pending record, exchanges the code, verifies the claims, and answers who the provider says this is. |
| `decodeIdTokenClaims` | `static Map<String, Object?> decodeIdTokenClaims(String idToken)` | The `id_token` payload. The **signature is not verified** — see [Status and Limitations](../authentication.md#status-and-limitations). |

### TomExternalIdentityLink

One persisted link row. `@tomReflector`, `@TomDbTable(table: 'tom_external_identity')`.

| Field | Column | Notes |
| ----- | ------ | ----- |
| `id` | `id` | Surrogate key, `-1` until persisted. |
| `issuer` | `issuer` | The provider's issuer identifier. |
| `subject` | `subject` | The provider's stable identifier for the user, within `issuer`. |
| `localUsername` | `local_username` | The local account. A username rather than a numeric id, because that is the handle the directory and `TomAuthenticationData` both already speak. |
| `displayName` | `display_name` | What the provider asserted when the link was made — operator diagnostics. |
| `linkedAt` | `linked_at` | When the link was created (UTC). |
| `lastLoginAt` | `last_login_at` | When it was last used, or `null`. What lets an operator answer "is this link still in use?" before revoking a provider. |

`createTableSql` makes `(issuer, subject)` unique — a duplicate would make which
local account a sign-in reaches depend on row order — and indexes
`local_username`, which turns "every identity linked to this account" into a
lookup rather than a scan.

### TomExternalIdentityLinkRepository

`TomSqlDatasourceRepository<TomExternalIdentityLink, int>`.

### TomExternalIdentityStore

The linking table.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `localUsernameFor` | `Future<String?> localUsernameFor(TomExternalIdentity identity)` | The linked account, or `null`. |
| `link` | `Future<void> link(TomExternalIdentity identity, String localUsername)` | Creates or updates the link. Relinking updates rather than duplicating. |
| `recordLogin` | `Future<void> recordLogin(TomExternalIdentity identity)` | Stamps `lastLoginAt`. |
| `identitiesOf` | `Future<List<TomExternalIdentityLink>> identitiesOf(String localUsername)` | Every identity linked to an account — the account-settings question. |
| `resolve` | `static TomExternalIdentityStore? resolve()` | The installed bean, or `null`. There is deliberately **no in-memory default**: a link that vanishes on restart sends a returning user through provisioning again. |

### TomPersistentExternalIdentityStore

The production implementation, over a
`TomSqlDatasourceRepository<TomExternalIdentityLink, int>`.

```dart
const TomPersistentExternalIdentityStore(TomSqlDatasourceRepository<TomExternalIdentityLink, int> repository)
```

### TomMemoryExternalIdentityStore

A map-backed store for tests. Not a production default — see
`TomExternalIdentityStore.resolve`.

### TomOAuthCredential

The credential an external login carries in `TomAuthenticationData.key`.

```dart
const TomOAuthCredential({required String code, required String state})
```

A typed value rather than a delimited string, because the pair is what the flow
needs and a `'code|state'` convention is a parser two files apart from its
formatter.

### TomExternalIdentityDirectory

What the deployment supplies. The framework has no user table — the whole point
of `TomAuthenticationService` is that a deployment owns that — so an external
login can go no further than "this is `alice@example.com` at
`https://accounts.google.com`" without asking the application who that is.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticatedPrincipalFor` | `Future<TomAuthenticationInfo?> authenticatedPrincipalFor(String username, TomAuthenticationData authData)` | The account lookup — note it is **not** passed a credential: the provider has already authenticated the user, and demanding a password here would be asking them to log in twice. `null` when no local account exists. |
| `provisionFromExternalIdentity` | `Future<TomAuthenticationInfo> provisionFromExternalIdentity(TomExternalIdentity identity, TomAuthenticationData authData)` | Creates a local account. Only ever called under `autoProvision`. The default implementation throws `login.error.oauth.provisioning-unsupported`, so turning provisioning on without implementing this gives a clear error rather than a half-created account. |
| `resolve` | `static TomExternalIdentityDirectory? resolve()` | The installed bean, or `null`. |

The two methods are separate because the second is a *decision* the first is
not: resolving a known account is a lookup, while creating one is a policy
choice.

### TomOAuthAuthenticationService

A `TomAuthenticationService` that authenticates an OAuth 2.0 / OIDC
authorization code — and nothing else. It issues no token, consults no 2FA
policy and makes no session decision; `TomAuthenticationServer.authenticateExternal`
hands its result to the same continuation a password login reaches.

```dart
const TomOAuthAuthenticationService({
  required TomExternalIdentityDirectory directory,
  TomAuthenticationService? delegate,
  TomOAuthFlow? flow,
  TomExternalIdentityStore? identityStore,
})
```

`delegate` is what keeps passwords working: a deployment installs *one*
authentication service, so any credential that is not a `TomOAuthCredential`
passes straight through. `null` makes external identity the only way in — a
legitimate choice, and not the default one.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateUser` | `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)` | *(override)* Completes the handshake, replays the flow's login context over the message's, resolves or provisions the local account, records the login, and returns an ordinary `TomAuthenticationInfo`. |

Login failure keys: `login.error.oauth.no-identity-store`,
`login.error.oauth.linked-account-missing`,
`login.error.oauth.no-local-account`,
`login.error.oauth.provisioning-unsupported`,
`login.error.oauth.unknown-issuer`,
`login.error.oauth.credential-not-supported`.

### TomOAuthServer

The `/oauth/*` endpoints. `@tomReflector @tomComponent
@TomApiImplementation(apiId: tomOAuthApiId)`, implementing the kernel's
`TomOAuthApiService`.

All three endpoints are public: there is no caller to authenticate — that is the
point of logging in — and the unguessable `state` handle is what ties a callback
to an authorization this server started.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `listOAuthProviders` | `Future<List<TomOAuthProviderDto>> listOAuthProviders()` | `GET /oauth/providers`. Resource keys only. |
| `beginOAuthAuthorization` | `Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(TomOAuthAuthorizationRequest request)` | `POST /oauth/authorize`. |
| `completeOAuthAuthorization` | `Future<TomAuthenticationResult> completeOAuthAuthorization(TomOAuthCallbackRequest request)` | `GET /oauth/callback`. Refuses a provider-reported error and an unknown state, then delegates to `TomAuthenticationServer.authenticateExternal`. Returns a login result, not an OAuth result. |

Keys raised: `oauth.callback.provider_error`, `oauth.callback.unknown_state`
(both `TomEndpointHandlerException`).

## Global Functions and Constants

None — this module exposes no top-level functions or constants. The one
top-level type alias, `TomTotpSecretResolver`, is documented above with the
adaptor that reads it. The OAuth contract's ids (`tomOAuthApiId` and the three
endpoint ids) and `registerTomOAuthApi()` live in `tom_core_kernel`'s security
module, with the rest of the wire contract.
