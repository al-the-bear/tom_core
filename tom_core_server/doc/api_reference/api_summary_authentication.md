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

When the resolved principal declares `TomPrincipal.requires2FA`, the login runs
in two passes. Pass 1 asks the `Tom2FAService` registered in `Tom2FARegistry`
for the principal's `twoFactorType` to issue a `Tom2FAChallengeSpec`, and
answers with an *interim* token carrying the challenge — its client-visible
half in the public claims (as the kernel's `Tom2FAChallenge`), its server-only
verification blob in the encrypted section. `authenticatePass2` recovers the
challenge from the presented bearer, hands the submitted factor to the same
adaptor as a `Tom2FASubmission`, and on success re-issues the token pair without
the challenge. Nothing is stored server-side between the passes.
`Tom2FAException` reports a mis-wired adaptor set and is never client-facing.

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
    ├── TomTotp2FAService  (implements, @Tom2FAAdaptor('totp'))
    └── TomDeliveredCode2FAService  (implements, + Tom2FAEnrolmentSupport)
            ├── TomEmailCode2FAService  (extends, @Tom2FAAdaptor('email'))
            └── TomSmsCode2FAService    (extends, @Tom2FAAdaptor('sms'))

TomServiceLoginTransport  (abstract)
    └── TomHttpServiceLoginTransport  (extends)

TomAuthenticationAdaptor   (@tomReflector, standalone)
Tom2FAAdaptor              (@tomReflector, standalone)
Tom2FAContext              (standalone)
Tom2FAChallengeSpec        (standalone)
Tom2FASubmission           (standalone)
Tom2FARegistry             (standalone, statics only)
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
`Tom2FAChallengeSpec.verificationData`.

- **Abstract**

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

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String type, Tom2FAService service)` | Registers `service` under `type`. Throws `Tom2FAException` (`authentication.2fa.duplicate_adaptor`) if a different adaptor is already registered for `type`; re-registering the identical instance is a no-op. |
| `lookup` | `static Tom2FAService? lookup(String type)` | The adaptor for `type`, or `null` when the mechanism is unknown here. Triggers the annotation scan on first use. |
| `registerAnnotated` | `static void registerAnnotated(Iterable<ClassMirror> candidates)` | Registers every class in `candidates` carrying a `Tom2FAAdaptor` annotation. Throws `Tom2FAException` on the first unusable candidate (`authentication.2fa.adaptor_instantiation_failed`, `authentication.2fa.adaptor_does_not_implement_service`), naming it — an adaptor set that is wrong is wrong at start-up. |
| `reset` | `static void reset()` | Drops every registration and forces a re-scan on next use. For tests. |

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
much clock skew to tolerate, how many attempts. The secret is read from
`globalSettingSecretResolver`, deliberately *not* from `TomUser.attributes`
(those are projected into the token's public claims), and nothing is stored in
`verificationData` — the secret is re-resolved on pass 2, so it never travels.

- **Implements:** `Tom2FAService`

#### Constructors

```dart
TomTotp2FAService()
```

*(no-argument, so the registry can reflect it into life)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mechanismType` | `String` | The mechanism key this adaptor answers to: `'totp'`. |
| `globalSettingSecretResolver` | `TomTotpSecretResolver?` | Resolves a user's base32 TOTP secret. Unset by default, which makes every TOTP challenge fail with `login.error.2fa.not-enrolled`. |
| `globalSettingDigits` | `int` | Number of digits in a generated code. Defaults to `TomTotp.defaultDigits` (6). |
| `globalSettingPeriod` | `Duration` | Length of one time step. Defaults to `TomTotp.defaultPeriod` (30 s). |
| `globalSettingWindowSteps` | `int` | How many time steps either side of "now" are accepted, to tolerate clock skew. Defaults to `1`. |
| `globalSettingAttemptsAllowed` | `int` | How many submissions one challenge tolerates. Defaults to `3`. |
| `globalSettingChallengeValidity` | `Duration` | How long a challenge stays answerable. Defaults to 5 minutes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Resolves the secret — throwing `LoginException('login.error.2fa.not-enrolled')` when there is none — and returns a spec whose `clientData` names the code shape (`digits`, `periodSeconds`) so a UI can size its input field. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Re-resolves the secret and compares the trimmed submission against the codes in the skew window, in constant time. Rejects a submission of the wrong width before hashing. |
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
