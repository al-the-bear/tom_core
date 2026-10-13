# Tom Core Server API Reference: Authentication Module

Server-side login orchestration: reflection-discoverable adaptor markers, the
authentication-service contract, the data carried into a login attempt, the
two-pass second-factor flow, the JWT-issuing `TomAuthenticationServer`, the
token signing and verification keys with the JSON Web Key Set that publishes
them, the server's own self-login against an auth server, and single sign-on
against external identity providers over OAuth 2.0 / OpenID Connect and SAML
2.0.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomAuthenticationAdaptor](#tomauthenticationadaptor)
  - [Tom2FAAdaptor](#tom2faadaptor)
  - [TomLoginException](#tomloginexception)
  - [Tom2FAException](#tom2faexception)
  - [TomAuthenticationData](#tomauthenticationdata)
  - [TomAuthenticationService](#tomauthenticationservice)
  - [Tom2FAContext](#tom2facontext)
  - [Tom2FAChallengeSpec](#tom2fachallengespec)
  - [Tom2FASubmission](#tom2fasubmission)
  - [Tom2FAService](#tom2faservice)
  - [Tom2FAPrerequisite](#tom2faprerequisite)
  - [Tom2FARegistry](#tom2faregistry)
  - [Tom2FARequirement](#tom2farequirement)
  - [Tom2FADecision](#tom2fadecision)
  - [Tom2FAPolicy](#tom2fapolicy)
  - [TomPrincipalFlag2FAPolicy](#tomprincipalflag2fapolicy)
  - [TomRole2FAPolicy](#tomrole2fapolicy)
  - [Tom2FAGraceAccounting](#tom2fagraceaccounting)
  - [Tom2FAGraceStore](#tom2fagracestore)
  - [TomMemory2FAGraceStore](#tommemory2fagracestore)
  - [Tom2FAEnrolment](#tom2faenrolment)
  - [Tom2FAEnrolmentOffer](#tom2faenrolmentoffer)
  - [Tom2FAEnrolmentSupport](#tom2faenrolmentsupport)
  - [Tom2FAEnrolmentState](#tom2faenrolmentstate)
  - [Tom2FAAttempt](#tom2faattempt)
  - [Tom2FAAttemptStore](#tom2faattemptstore)
  - [Tom2FAMemoryAttemptStore](#tom2famemoryattemptstore)
  - [Tom2FASend](#tom2fasend)
  - [Tom2FASendLimiter](#tom2fasendlimiter)
  - [Tom2FAMemorySendLimiter](#tom2famemorysendlimiter)
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
  - [TomWebAuthn2FAService](#tomwebauthn2faservice)
  - [TomWebAuthnVerifier](#tomwebauthnverifier)
  - [TomWebAuthnRegisteredCredential](#tomwebauthnregisteredcredential)
  - [TomWebAuthnVerifiedAssertion](#tomwebauthnverifiedassertion)
  - [TomWebAuthnSoftwareAuthenticator](#tomwebauthnsoftwareauthenticator)
  - [TomAuthenticationInfo](#tomauthenticationinfo)
  - [TomDummyAuthenticationService](#tomdummyauthenticationservice)
  - [TomAuthenticationServer](#tomauthenticationserver)
  - [TomServiceCredential](#tomservicecredential)
  - [TomServiceLoginTransport](#tomservicelogintransport)
  - [TomServiceLoginResponse](#tomserviceloginresponse)
  - [TomHttpServiceLoginTransport](#tomhttpservicelogintransport)
  - [TomServerSelfLoginException](#tomserverselfloginexception)
  - [TomServerSession](#tomserversession)
  - [TomServerSelfLogin](#tomserverselflogin)
  - [TomOAuthException](#tomoauthexception)
  - [TomOAuthProvisioning](#tomoauthprovisioning)
  - [TomOAuthProviderConfig](#tomoauthproviderconfig)
  - [TomOAuthProviders](#tomoauthproviders)
  - [TomOAuthPkce](#tomoauthpkce)
  - [TomOAuthAuthorizationState](#tomoauthauthorizationstate)
  - [TomOAuthStateStore](#tomoauthstatestore)
  - [TomOAuthMemoryStateStore](#tomoauthmemorystatestore)
  - [TomSqlOAuthStateStore](#tomsqloauthstatestore)
  - [TomOAuthStateRow](#tomoauthstaterow)
  - [TomOAuthStateStoreType](#tomoauthstatestoretype)
  - [TomOAuthStateStoreSettings](#tomoauthstatestoresettings)
  - [TomOAuthTokenTransport](#tomoauthtokentransport)
  - [TomHttpOAuthTokenTransport](#tomhttpoauthtokentransport)
  - [TomExternalIdentity](#tomexternalidentity)
  - [TomOAuthExchange](#tomoauthexchange)
  - [TomOAuthFlow](#tomoauthflow)
  - [TomOAuthTokenGrant](#tomoauthtokengrant)
  - [TomOAuthTokenStore](#tomoauthtokenstore)
  - [TomMemoryOAuthTokenStore](#tommemoryoauthtokenstore)
  - [TomExternalIdentityToken](#tomexternalidentitytoken)
  - [TomExternalIdentityTokenRepository](#tomexternalidentitytokenrepository)
  - [TomPersistentOAuthTokenStore](#tompersistentoauthtokenstore)
  - [TomExternalIdentityLink](#tomexternalidentitylink)
  - [TomExternalIdentityLinkRepository](#tomexternalidentitylinkrepository)
  - [TomExternalIdentityStore](#tomexternalidentitystore)
  - [TomPersistentExternalIdentityStore](#tompersistentexternalidentitystore)
  - [TomMemoryExternalIdentityStore](#tommemoryexternalidentitystore)
  - [TomOAuthCredential](#tomoauthcredential)
  - [TomExternalIdentityDirectory](#tomexternalidentitydirectory)
  - [TomOAuthAuthenticationService](#tomoauthauthenticationservice)
  - [TomOAuthServer](#tomoauthserver)
  - [TomExternalProvider](#tomexternalprovider)
  - [TomExternalRoleMapping](#tomexternalrolemapping)
  - [TomSamlException](#tomsamlexception)
  - [TomXmlDsig](#tomxmldsig)
  - [TomExclusiveCanonicalizer](#tomexclusivecanonicalizer)
  - [TomXmlSignatureVerifier](#tomxmlsignatureverifier)
  - [TomSamlNames](#tomsamlnames)
  - [TomSamlProviderConfig](#tomsamlproviderconfig)
  - [TomSamlCertificates](#tomsamlcertificates)
  - [TomSamlIdpMetadata](#tomsamlidpmetadata)
  - [TomSamlProviders](#tomsamlproviders)
  - [TomSamlFlow](#tomsamlflow)
  - [TomSamlResponseValidator](#tomsamlresponsevalidator)
  - [TomSamlService](#tomsamlservice)
  - [TomSamlServer](#tomsamlserver)
  - [TomJwtKeyException](#tomjwtkeyexception)
  - [TomJwtAlgorithm](#tomjwtalgorithm)
  - [TomJwtKey](#tomjwtkey)
  - [TomJwtSigningKey](#tomjwtsigningkey)
  - [TomJwtSigning](#tomjwtsigning)
  - [TomJwksService](#tomjwksservice)
  - [TomJwksServer](#tomjwksserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/authentication/authentication_server.dart`,
`lib/src/tomserver/authentication/two_factor.dart`,
`lib/src/tomserver/authentication/two_factor_policy.dart`,
`lib/src/tomserver/authentication/two_factor_enrolment.dart`,
`lib/src/tomserver/authentication/two_factor_attempts.dart`,
`lib/src/tomserver/authentication/two_factor_send_limit.dart`,
`lib/src/tomserver/authentication/two_factor_delivered_code.dart`,
`lib/src/tomserver/authentication/two_factor_webauthn.dart`,
`lib/src/tomserver/authentication/webauthn_software_authenticator.dart`,
`lib/src/tomserver/authentication/server_self_login.dart`,
`lib/src/tomserver/authentication/oauth_provider.dart`,
`lib/src/tomserver/authentication/oauth_flow.dart`,
`lib/src/tomserver/authentication/oauth_state_sql.dart`,
`lib/src/tomserver/authentication/sql_oauth_state_store.dart`,
`lib/src/tomserver/authentication/oauth_identity.dart`,
`lib/src/tomserver/authentication/oauth_tokens.dart`,
`lib/src/tomserver/authentication/oauth_authentication_service.dart`,
`lib/src/tomserver/authentication/oauth_endpoints.dart`,
`lib/src/tomserver/authentication/external_provider.dart`,
`lib/src/tomserver/authentication/saml_xml_signature.dart`,
`lib/src/tomserver/authentication/saml_provider.dart`,
`lib/src/tomserver/authentication/saml_flow.dart`,
`lib/src/tomserver/authentication/saml_endpoints.dart`,
`lib/src/tomserver/authentication/jwt_signing.dart`,
`lib/src/tomserver/authentication/jwt_keys.dart`,
`lib/src/tomserver/authentication/jwks_endpoint.dart`.

The module orchestrates the server-side login flow. `TomAuthenticationServer`
receives a `TomAuthenticationMessage`, builds a `TomAuthenticationData` from it,
and delegates credential checking to a configured `TomAuthenticationService`
(the default `TomDummyAuthenticationService` accepts any non-`"GUEST"` user and
logs an error, for scaffolding only). On success the resolved
`TomAuthenticationInfo` (principal + access-control definition) is encoded into
two JWTs — an authentication token and an authorization token — inside the
returned `TomAuthenticationResult`. `TomLoginException` (a `TomServerException`)
is caught and turned into a failed result. `TomAuthenticationAdaptor`,
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
adaptor later. Registration therefore carries the whole weight of "can run",
which is why an adaptor that declares an unmet `Tom2FAPrerequisite` — a mailed
code in a deployment with no `TomEmailService` — is kept *out* of the registry
by the scan instead of being offered and failing mid-login. A policy that also
implements `Tom2FAGraceAccounting` is told when a grace login is spent.

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
stays the only authority on whether the user has a factor),
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

Four mechanisms ship. `TomWebAuthn2FAService` (passkeys) verifies a signature
by a key that never leaves the user's authenticator, against the origin the
browser reports — see its entry below. `TomTotp2FAService` (RFC 6238
authenticator app) needs no
delivery channel and stores nothing in `verificationData`, re-deriving its answer
from the shared secret. `TomEmailCode2FAService` and `TomSmsCode2FAService` are
*delivered* codes — both thin subclasses of `TomDeliveredCode2FAService`, which
generates a code, seals it as a salt plus a SHA-256 into `verificationData`,
sends it synchronously through the Messaging module's `TomEmailService` /
`TomSmsService`, and recognises it again with a constant-time compare. They are
the mechanisms that exercise the encrypted half of the challenge split, and they
also implement `Tom2FAEnrolmentSupport`: enrolling a delivered code means proving
the user can read what is sent to the destination. Because they need a
collaborator, they also implement `Tom2FAPrerequisite` — a deployment that
installed no `TomEmailService` never has `'email'` registered, and so is never
offered it.

`TomServerSelfLogin` covers the separate case of the deployment authenticating
*as itself*: it presents a `TomServiceCredential` over a
`TomServiceLoginTransport`, reconstructs the resulting principal, and installs
it as the server principal whose grants cap every user's. An unconfigured
deployment skips this silently; a configured one that fails raises
`TomServerSelfLoginException`.

Every token is signed and verified through `TomJwtSigning.current`, which
`installJwtSigning` builds from the server configuration at boot: the
`TomJwtAlgorithm` (RS256 by default, ES256 or HS256), the `TomJwtSigningKey`
tokens are signed with, every `TomJwtKey` a token may be verified with, and the
issuer and audience every token carries. An asymmetric key's id (`kid`) is the
RFC 7638 thumbprint of its public JWK, so every server derives the same id from
the same key. `verifyBearerToken` checks the algorithm, the `kid`, the signature,
the issuer and the audience of an inbound token against that description.
`TomJwksService` publishes the public keys as a JSON Web Key Set at
`GET /.well-known/jwks.json`, so any JWT library or gateway verifies this
deployment's tokens without being handed a key. A misconfigured key or a server
that may only verify raises `TomJwtKeyException`.

External identity is one login over two protocols. `TomOAuthFlow` drives OAuth
2.0 / OpenID Connect providers — read from `oauth.providers`, with their
endpoints taken from the issuer's discovery document when a provider sets
`discovery: true` (`TomOAuthProviders.load`) — and, through its `saml` field, the
SAML 2.0 identity providers `TomSamlFlow` drives, read from `saml.providers`
(`TomSamlProviders.load`, which fetches each provider's metadata). Both provider
types implement `TomExternalProvider`, so `TomOAuthAuthenticationService` links,
provisions and maps roles the same way for either. `TomExternalRoleMapping`
turns a provider's group claim into Tom roles on every login, and
`applyExternalRoles` adds them to the session's principal. A SAML response is
verified by `TomSamlResponseValidator` over `TomXmlSignatureVerifier` and
`TomExclusiveCanonicalizer`; `TomSamlService` is its assertion consumer service
and metadata endpoint. Failures are `TomOAuthException` and `TomSamlException`.

## Class Hierarchy

```text
TomServerException  (little_things)
    ├── TomLoginException
    ├── Tom2FAException
    ├── TomServerSelfLoginException
    ├── TomOAuthException
    ├── TomSamlException
    ├── TomSigningKeyException
    └── TomJwtKeyException

TomJwksService  (@tomService, abstract)
    └── TomJwksServer  (@tomComponent, implements)

TomSamlService  (@tomService, abstract)
    └── TomSamlServer  (@tomComponent, implements)

TomExternalProvider  (abstract interface)
    ├── TomOAuthProviderConfig  (implements)
    └── TomSamlProviderConfig   (implements)

TomAuthenticationService  (abstract)
    ├── TomDummyAuthenticationService     (implements)
    └── TomOAuthAuthenticationService     (implements, delegates the rest)

TomOAuthStateStore  (abstract)
    ├── TomOAuthMemoryStateStore  (implements, per-process, the default)
    └── TomSqlOAuthStateStore     (implements, over tom_oauth_state, shared)

TomOAuthTokenTransport  (abstract)
    └── TomHttpOAuthTokenTransport  (implements)

TomExternalIdentityStore  (abstract)
    ├── TomPersistentExternalIdentityStore  (implements)
    └── TomMemoryExternalIdentityStore      (implements)

TomOAuthTokenStore  (abstract, no default — unregistered means nothing is kept)
    ├── TomMemoryOAuthTokenStore      (implements)
    └── TomPersistentOAuthTokenStore  (implements, encrypted at rest)

TomExternalIdentityDirectory  (abstract, deployment-supplied)

TomSqlDatasourceRepository<TomExternalIdentityLink, int>
    └── TomExternalIdentityLinkRepository  (extends)

TomSqlDatasourceRepository<TomExternalIdentityToken, int>
    └── TomExternalIdentityTokenRepository  (extends)

Tom2FAService  (@tomReflector, abstract)
    ├── TomTotp2FAService  (implements, @Tom2FAAdaptor('totp'),
    │                       + Tom2FAEnrolmentSupport)
    ├── TomWebAuthn2FAService  (implements, @Tom2FAAdaptor('webauthn'),
    │                           + Tom2FAEnrolmentSupport, + Tom2FAPrerequisite)
    └── TomDeliveredCode2FAService<S>  (implements, + Tom2FAEnrolmentSupport,
            │                           + Tom2FAPrerequisite)
            ├── TomEmailCode2FAService  (extends <TomEmailService>,
            │                            @Tom2FAAdaptor('email'))
            └── TomSmsCode2FAService    (extends <TomSmsService>,
                                         @Tom2FAAdaptor('sms'))

Tom2FAEnrolmentSupport  (abstract, mixed into an enrollable Tom2FAService)
    ├── TomTotp2FAService           (implements)
    ├── TomWebAuthn2FAService       (implements)
    └── TomDeliveredCode2FAService  (implements)

Tom2FAPrerequisite  (abstract, opt-in on an adaptor that needs a collaborator)
    ├── TomWebAuthn2FAService       (implements)
    └── TomDeliveredCode2FAService  (implements)

TomWebAuthnVerifier                 (abstract final, static checks)
TomWebAuthnRegisteredCredential     (value)
TomWebAuthnVerifiedAssertion        (value)
TomWebAuthnSoftwareAuthenticator    (test double)

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
TomOAuthStateRow           (@tomReflector, @TomDbTable row type)
TomOAuthStateStoreType     (enum)
TomOAuthStateStoreSettings (standalone, immutable)
TomExternalIdentity        (standalone, immutable)
TomOAuthExchange           (standalone, immutable)
TomOAuthFlow               (standalone, immutable)
TomOAuthTokenGrant         (standalone, immutable)
TomExternalIdentityLink    (@tomReflector, @TomDbTable entity)
TomExternalIdentityToken   (@tomReflector, @TomDbTable entity)
TomOAuthCredential         (standalone, immutable)
TomOAuthServer             (@tomReflector, @TomApiImplementation)
TomExternalRoleMapping     (standalone, immutable)
TomSamlProviders           (standalone, immutable)
TomSamlIdpMetadata         (standalone, immutable)
TomSamlFlow                (standalone)
TomSamlResponseValidator   (standalone, immutable)
TomXmlSignatureVerifier    (standalone, immutable)
TomSamlNames               (abstract final, constants)
TomXmlDsig                 (abstract final, constants)
TomSamlCertificates        (abstract final, statics only)
TomExclusiveCanonicalizer  (abstract final, statics only)
TomJwtAlgorithm            (enum)
TomJwtKey                  (standalone, immutable)
TomJwtSigningKey           (standalone, immutable)
TomJwtSigning              (standalone, statics hold the installed one)
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

### TomLoginException

A server-side login failure carrying the `TomServerException` payload plus a
closed-set `TomLoginFailure` reason. Thrown by a `TomAuthenticationService` when
a login cannot succeed; `TomAuthenticationServer` catches it and turns its `key`
into a failed result.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomLoginException(
  String key,
  String defaultUserMessage, {
  required TomLoginFailure reason,
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `reason` | `TomLoginFailure` | Which closed-set failure this is — the five values are tabled in the kernel's [api_summary_security.md](../../../tom_core_kernel/doc/api/api_summary_security.md#tomloginfailure), beside the module that declares the enum. Required, and required rather than defaulted, because a default is a classification nobody made: every new throw site would silently join it and the value a client branches on would stop meaning anything. It does not replace `key` — the key stays as specific as the throw site can make it and is what the server logs. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The base string extended with `login-failure: <reason>`, so a log line carries the classification beside the key it was classified from. |

### Tom2FAException

A 2FA *configuration* fault — a duplicate or unusable adaptor registration, or a
mechanism that cannot be constructed. Distinct from `TomLoginException`: a wrong
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
  StackTrace? stack,
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
`TomAuthenticationInfo`, or throw a `TomLoginException` on failure.

Everything the returned principal asserts is the implementation's answer — the
identity, the locale, the ACI, and the client limits (`principal.cli`, the
subscription's enabled modules and quotas). The server holds no subscription
store. Two values it resolves after the credential is accepted:
`principal.timezone`, from the user's stored preference, and `principal.cli`,
from the kernel's installed `TomClientLimitsProvider` when there is one (a
`null` answer or a failure keeps the implementation's limits).

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateUser` | `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)` | Authenticates `authData`, returning the principal and its access rights, or throwing a `TomLoginException` when rejected. |

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
| `verificationData` | `Map<String, Object?>` | The `Tom2FAChallengeSpec.verificationData` recovered from the interim token's encrypted section; empty when the adaptor stored none. |
| `challenge` | `Tom2FAChallenge` | The challenge being answered, with this attempt already counted — so `challenge.attemptsRemaining` reads as it will *after* this submission. |

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
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | Issues a challenge for `context`, or throws `TomLoginException` when this user cannot be challenged at all (no enrolled device, no configured secret). |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | Whether `submission` correctly answers the challenge. Returns `false` for a wrong answer; throws only when verification could not be *performed*. |

### Tom2FAPrerequisite

What an adaptor implements when it can only work if something *else* was
installed — a mail service, an SMS gateway, a push credential. A separate
interface rather than a member on `Tom2FAService`, for the reason
`Tom2FAEnrolmentSupport` is separate from it: most mechanisms need nothing
beyond themselves, and a base contract whose implementations almost all answer
`null` teaches callers to stop reading the answer.

`Tom2FARegistry.registerAnnotated` asks and skips a candidate that answers;
`Tom2FARegistry.register` does not ask, because naming an adaptor in a call is
asking for it. The asymmetry is the point — the complaint this interface
answers is about the *automatic* registration nobody asked for, which is what
puts a mechanism the deployment cannot run into
`Tom2FADecision.offerableMechanisms`.

- **Abstract**

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `unmetPrerequisite` | `String?` | What this deployment did not install, phrased for the operator who has to install it — or `null` when the adaptor can run. A reason rather than a bool because a mechanism that quietly disappears is the hardest kind of absence to debug: every lookup answers `null`, which is also what a mechanism nobody ever wrote answers. Read at registration, so it must be cheap and synchronous; anything needing I/O belongs in `Tom2FAService.issueChallenge`, where a failure is a login outcome rather than a deployment shape. |

### Tom2FARegistry

Resolves a mechanism key to the adaptor that implements it. Populated on first
use by scanning the reflection registry for classes annotated `Tom2FAAdaptor`; a
deployment can also register an adaptor built by hand. Registration is
idempotent per key and rejects a second, *different* adaptor for the same key.
Statics only — the constructor is private.

Only a scan that *completed* counts as the first use. Consulted in a program
whose generated reflection has not been initialized yet, the registry says so
once in the log and stays armed, so the scan happens as soon as reflection
arrives; hand-registered adaptors resolve throughout.

The scan also asks each candidate `Tom2FAPrerequisite.unmetPrerequisite` and
**skips** the ones that answer, logging what was missing. A deployment that
ships mail or SMS codes must therefore install its `TomEmailService` /
`TomSmsService` beans during start-up, **before the first login**: a successful
scan is not repeated, so a mechanism skipped for a not-yet-installed
collaborator stays absent for the life of the process.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `registeredTypes` | `Set<String>` | The mechanism keys currently resolvable, scanning if needed. |
| `availableMethods` | `List<Tom2FAMethodDescriptor>` | How every registered mechanism describes itself, for a client that must render a choice. Derived from the registry rather than configured beside it, so "installed" and "describable" cannot drift. Every principal sees the same list — narrowing it to one user's permitted mechanisms is `Tom2FADecision.offerableMechanisms`' job. |
| `enrollableMethods` | `List<Tom2FAMethodDescriptor>` | The subset of `availableMethods` whose adaptors implement `Tom2FAEnrolmentSupport`. "Verifiable here" and "enrollable here" are different questions: a hardware token an administrator hands out is the first and not the second, and an enrolment step offering it would present a choice that cannot be acted on. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String type, Tom2FAService service)` | Registers `service` under `type`. Throws `Tom2FAException` (`authentication.2fa.duplicate_adaptor`) if a different adaptor is already registered for `type`; re-registering the identical instance is a no-op. `Tom2FAPrerequisite` is deliberately **not** consulted: naming an adaptor in a call is asking for it, and a deployment that builds its adaptors before its collaborators needs that escape. |
| `lookup` | `static Tom2FAService? lookup(String type)` | The adaptor for `type`, or `null` when the mechanism is unknown here. Triggers the annotation scan on first use. |
| `enrolmentSupportFor` | `static Tom2FAEnrolmentSupport? enrolmentSupportFor(String type)` | The adaptor for `type` when it can also be enrolled, else `null` — the one place the `is` check is made, so callers ask "can this be set up here?" rather than reproducing the test. |
| `registerAnnotated` | `static void registerAnnotated(Iterable<ClassMirror> candidates)` | Registers every class in `candidates` carrying a `Tom2FAAdaptor` annotation. Throws `Tom2FAException` on the first unusable candidate (`authentication.2fa.adaptor_instantiation_failed`, `authentication.2fa.adaptor_does_not_implement_service`), naming it — an adaptor set that is wrong is wrong at start-up. A call that throws registers nothing and leaves registrations made before it untouched, so a retried scan meets the same registry the first attempt found. A candidate whose `Tom2FAPrerequisite.unmetPrerequisite` is non-null is the other case and is **skipped**, loudly, rather than thrown on: a server with no mail relay is a legitimate deployment, and refusing to start would make one uninstalled channel cost it every other mechanism it wired. |
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
| `offerableMechanisms` | `List<String>` | `allowedMechanisms` intersected with `Tom2FARegistry.registeredTypes`. Permission and availability are separate questions — a policy says what a user *may* use, the registry says what this process *can* run — and intersecting them here turns a wiring fault into `login.error.2fa.unsupported-mechanism` at the login rather than a null adaptor further on. Registration is the only thing consulted, which is why an adaptor that cannot run here (`Tom2FAPrerequisite`) is never registered in the first place. |
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
meant to run out. `TomRole2FAPolicy` implements it and counts through
`Tom2FAGraceStore`, so its `graceLogins: 3` is a budget of three rather than
three-every-login. A policy of your own that does not implement this grants the
same grace every time, which is a valid "warn, do not enforce yet" deployment
rather than an error.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordGraceLoginConsumed` | `Future<void> recordGraceLoginConsumed(Tom2FAContext context)` | Called at the moment grace is **spent** — a user declining an offer that was declinable because of grace — and never when the offer was merely made, nor for an `optional` decline, which costs nothing. |

### Tom2FAGraceStore

Where the grace a principal has already spent is remembered.
`Tom2FAGraceAccounting` says *when* one is used; something has to hold the
running total, and this is it. Without one a policy re-reads its configured
allowance every login and hands back the same number — a countdown that never
counts down.

**`resolve()` falls back to `TomMemory2FAGraceStore`**, unlike
`Tom2FAEnrolmentStore.resolve()`, which returns `null`. The asymmetry is the
consequence of losing the record: an enrolment that vanished would lose a user
their factor, where a grace count that vanishes degrades to exactly the
behaviour that preceded counting it — the user is offered enrolment again and
gets another few logins. A restart can lengthen a budget and never shorten it,
so a per-process default cannot cost anyone access, and a store that had to be
installed before the counter counted is a counter most deployments would not
have.

- **Abstract**

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `Tom2FAGraceStore resolve()` | The installed bean, or the process-wide `TomMemory2FAGraceStore.shared`. |
| `principalKeyOf` | `String principalKeyOf(Tom2FAContext context)` | What a store files a count under — the principal, and deliberately not the principal *and mechanism*: grace is spent by declining to enrol at all, so keying by mechanism would hand a user a fresh allowance for every mechanism offered. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `consumedBy` | `Future<int> consumedBy(Tom2FAContext context)` | How many grace logins this principal has already spent. |
| `recordConsumed` | `Future<void> recordConsumed(Tom2FAContext context)` | Records that one more has just been spent. |

### TomMemory2FAGraceStore

The default store: a map in this process. A restart or a second node starts the
count again — see `Tom2FAGraceStore` for why that is acceptable here. A
deployment that wants the budget to survive implements the two methods against
its own user data; the framework ships no table, because the count is a fact
about a user and this package has no user table.

- **Implements:** `Tom2FAGraceStore`

#### Constructors

```dart
TomMemory2FAGraceStore()
```

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `shared` | `TomMemory2FAGraceStore` | The process-wide instance `Tom2FAGraceStore.resolve()` falls back to. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `size` | `int` | *(getter)* How many principals have spent anything. Test-support. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `consumedBy` | `Future<int> consumedBy(Tom2FAContext context)` | *(override)* The count held for this principal, or `0`. |
| `recordConsumed` | `Future<void> recordConsumed(Tom2FAContext context)` | *(override)* Increments it. |
| `clear` | `void clear()` | Discards every count. Test-support only. |

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
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | Proposes a setup for `context`, or throws `TomLoginException` when this principal cannot enrol this mechanism at all (`login.error.2fa.no-destination` for a delivered code with no address on record). |
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
| `expiresAt` | `DateTime?` | When the offer stops being confirmable. Null only while the user is still choosing: a begun offer always has one, because the claim is the sole bound on a generated secret that lives in a token and nowhere else. |
| `attempt` | `int` | How many confirmations have been spent. |
| `hasOffer` | `bool` | Whether a mechanism has been chosen — the two states a client renders differently. |
| `attemptsRemaining` | `int` | `offer.attemptsAllowed - attempt`, floored at zero. |
| `isExhausted` | `bool` | Whether an offer exists and has no attempts left. |
| `secretClaims` | `Map<String, Object?>?` | *(getter)* The claims this state contributes to the token's **encrypted** section, or `null` in the offered shape. The whole offer goes in, secret included, so that the confirmation is checked against material the client could not have edited on the way past. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isExpired` | `bool isExpired([DateTime? now])` | Whether the offer has lapsed. False in the offered shape, which has no window to close; true for a *begun* state that somehow has no deadline, since a window that was never opened contains no instant. `fromClaims` refuses such a token outright, so this is the backstop for a directly constructed state. |
| `withOffer` | `Tom2FAEnrolmentState withOffer(Tom2FAEnrolmentOffer chosen, {DateTime? now})` | The state after a mechanism is chosen. Restarts the attempt counter — the attempts belong to the offer, so choosing a different mechanism starts a fresh budget. |
| `withConsumedAttempt` | `Tom2FAEnrolmentState withConsumedAttempt()` | The state after one confirmation has been spent. |
| `toClaims` | `Map<String, Object?> toClaims()` | The public half, for the interim token's claims. |
| `secretClaims` | `Map<String, Object?>?` | The encrypted half — the offer's `enrolmentData` — or `null` when nothing has been chosen. |
| `fromClaims` | `static Tom2FAEnrolmentState? fromClaims(Map<String, dynamic>? payload, [Map<String, dynamic>? secretData])` | Reads a pending enrolment back out of a token, or `null` when it carries none. An offer that cannot be decrypted degrades to the *offered* shape rather than throwing, so an undecryptable token sends the user back to the choice instead of failing the login. Every boolean claim is read with `Tom2FAClaims.isTrue` (either wire encoding), the same rule the kernel's `Tom2FAPendingEnrolment.fromClaims` applies — the two decode the same token, one to render the UI and one to authorise the enrolment passes, so they must not disagree about what `skippable` says. An unreadable **expiry** on a begun offer is the one input it refuses outright, throwing `TomLoginException('login.error.2fa.enrolment-offer-invalid')`: the offer travels encrypted and so is authentic, while its deadline travels in the public payload, and reading a missing deadline as *no deadline* would leave a generated secret confirmable for as long as somebody keeps the token. The kernel twin declines the same payload by returning `null` — it renders a panel rather than authorising a pass, so it has no error to raise. |

### Tom2FAAttempt

One presentation of an interim two-factor token, offered to a
`Tom2FAAttemptStore`. Carries more than the fingerprint the default store keys
on, because the seam is also where a per-principal rate limit would go — the
other remedy for the same attack — and such a limiter has to know whose attempt
it is refusing.

#### Constructors

```dart
const Tom2FAAttempt({
  required String fingerprint,
  required String username,
  required String challengeType,
  required DateTime notAfter,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fingerprint` | `String` | A stable, opaque identifier for the presented token — a digest, never the token; see `tom2FATokenFingerprint` (final). |
| `username` | `String` | Who the chain belongs to, as the interim token's payload names them (final). |
| `challengeType` | `String` | The mechanism the challenge belongs to (final). |
| `notAfter` | `DateTime` | When the challenge lapses. After it every token in the chain is refused as expired, so a record older than this bounds nothing and a store may drop it (final). |

### Tom2FAAttemptStore

Records which interim two-factor tokens have already been answered — the one
fact that turns the in-token attempt counter into a bound.

The counter travels inside the token and advances only along the chain the
server hands back, which bounds a cooperative client. An uncooperative one
replays an earlier token: still valid, still carrying its lower count, and
indistinguishable to a stateless server from its first presentation. With this
store each token is answerable exactly once, and since a wrong answer is what
mints the next token, the chain admits exactly `attemptsAllowed` guesses however
the attacker orders it.

**`resolve()` is never null, unlike `Tom2FAEnrolmentStore.resolve()`.** An
absent installation is a single-process deployment, not a deployment that wants
no bound — a bound that has to be opted into is one most deployments will not
have — so it falls back to `Tom2FAMemoryAttemptStore.shared`. A deployment that
genuinely wants the old stateless behaviour installs a store whose `spend`
always answers `true`.

- **Abstract**

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `Tom2FAAttemptStore resolve()` | The installed bean, or the process-wide `Tom2FAMemoryAttemptStore.shared`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `spend` | `Future<bool> spend(Tom2FAAttempt attempt)` | Records `attempt` and reports whether this token had **not** been answered before. `true` lets verification proceed; `false` refuses it with `login.error.2fa.challenge-already-answered`. One call rather than a check and a write, so two requests racing on one token cannot both be told they are the first — an implementation over shared storage makes it atomic (an insert whose unique key is the fingerprint, a duplicate-key error read as `false`). Called **before** the mechanism is asked, so a refused replay costs a request and buys no information. |

### Tom2FAMemoryAttemptStore

The default attempt store: a map in this process.

**Per process, and says so.** In a load-balanced cluster each node bounds only
the answers that reach it, so the effective allowance is the challenge's times
the node count — finite, which is the property that matters, and a deployment
wanting the exact cap installs a store its nodes share. Entries are pruned as
they are written rather than on a timer: a record whose challenge has lapsed
bounds nothing, so the map cannot grow beyond the tokens answered inside one
challenge validity.

- **Implements:** `Tom2FAAttemptStore`

#### Constructors

```dart
Tom2FAMemoryAttemptStore()
```

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `shared` | `Tom2FAMemoryAttemptStore` | The process-wide instance `Tom2FAAttemptStore.resolve()` falls back to. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `size` | `int` | *(getter)* How many records are held — test-support, and a size to assert on. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `spend` | `Future<bool> spend(Tom2FAAttempt attempt)` | *(override)* Prunes lapsed records, then records the fingerprint if it is new. |
| `clear` | `void clear()` | Discards every record. Test-support only. |

### Tom2FASend

One request to send a delivered code, as a send limiter is told about it: the
channel and address it would go to, and the pace the sending service asks for.

#### Constructors

```dart
const Tom2FASend({
  required String channel,
  required String destination,
  required Duration baseInterval,
  required Duration maxInterval,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `String` | The mechanism sending (`'email'`, `'sms'`, …). Part of the key, so a user's email and phone are paced separately. |
| `destination` | `String` | The address the code would go to. |
| `baseInterval` | `Duration` | The gap required after the first send of a run, doubled for each send after it. |
| `maxInterval` | `Duration` | The longest gap a run can require. |
| `lapse` | `Duration` | *(getter)* Twice `maxInterval` — how long an address must go unsent to before its run lapses, so a run at the cap stays at the cap. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `intervalAfter` | `Duration intervalAfter(int sends)` | The gap required after a run of `sends` sends: `baseInterval × 2^(sends−1)`, capped at `maxInterval`; zero before the first. |
| `toString` | `String toString()` | *(override)* `Tom2FASend(<channel>)` — the address is deliberately left out of a string that ends up in logs. |

### Tom2FASendLimiter

Records the codes sent to each address and refuses one sent too soon. The first
code to an address goes out at once; each later one in a run waits twice as
long as the one before, up to `maxInterval`. A run is ended by proof — a code
sent to the address coming back correctly, at login or at enrolment — and lapses
after `Tom2FASend.lapse` without a send. Resolved like `Tom2FAAttemptStore`: a
missing installation is the in-process default, never "no pace".

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `claim` | `Future<Duration?> claim(Tom2FASend send)` | *(abstract)* Records the send and answers `null` if it is allowed now; otherwise records nothing and answers how long until it is. One call, so two racing logins cannot both be told they are early enough. |
| `reset` | `Future<void> reset(String channel, String destination)` | *(abstract)* Ends the run for the address; called when a code sent there came back correctly. |
| `resolve` | `static Tom2FASendLimiter resolve()` | The installed bean, or the process-wide `Tom2FAMemorySendLimiter.shared`. |

### Tom2FAMemorySendLimiter

The default send limiter: a map in this process. **Per process, and says so** —
on a cluster each node paces the sends that pass through it, so an address can
receive one run per node; a deployment wanting one pace installs a limiter its
nodes share. Runs are pruned as they are written once their address has gone
unsent to for their lapse. Addresses compare without case and surrounding
whitespace.

- **Implements:** `Tom2FASendLimiter`

#### Constructors

```dart
Tom2FAMemorySendLimiter({DateTime Function()? clock})
```

`clock` is injectable because the pace is measured in seconds to days.

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `shared` | `Tom2FAMemorySendLimiter` | The process-wide instance `Tom2FASendLimiter.resolve()` falls back to. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `size` | `int` | *(getter)* How many addresses have a run — test-support, and a size to assert on. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `claim` | `Future<Duration?> claim(Tom2FASend send)` | *(override)* Prunes lapsed runs, then allows and records the send, or answers the wait left. |
| `reset` | `Future<void> reset(String channel, String destination)` | *(override)* Drops the address's run. |
| `clear` | `void clear()` | Discards every run. Test-support only. |

### Tom2FAEnrolmentStore

Where a principal's set-up factors live. Deployment-supplied: the framework
knows what an enrolment *is* but not where this deployment keeps its user data.
Every method takes a `Tom2FAContext` rather than a bare principal id for the
same reason the adaptors do — a deployment writing its own store sees the whole
attempt (client, organization, locale) and one handed only an id could not. What
the shipped stores actually file rows under is narrower; see `principalKeyOf`.

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
| `principalKeyOf` | `static String principalKeyOf(Tom2FAContext context)` | The key a store files a principal's enrolments under — `context.principal.id`, stringified, matching `TomPrincipalResourceGrant.principalId`. One place, so the memory store and the persistent store cannot disagree on what "this user" means. The organization is deliberately no part of it: a principal id names one person across the deployment rather than within a tenant, so a user's factors are theirs in every organization they log into, and `tom_user_two_factor_enrolment` has no tenant column. A deployment that allocates ids per tenant has broken that premise framework-wide and supplies its own store, which is handed the whole context — which is also why this staying `static` costs nothing. |

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
primaryKeyFields: ['id'])`). A `UNIQUE KEY (principal_id, enrolment_id)` makes the
upsert the database's rule and not only the store's; without it, which secret
answers a login would depend on row order. Every field defaults, because the
repository instantiates a blank entity and fills it column by column.

#### Properties

The column each field maps to is given beside it: the two spellings differ, and
the Dart name is the one a caller writes.

| Property | Type | Column | Description |
| -------- | ---- | ------ | ----------- |
| `id` | `int` | `id` | Surrogate primary key, `-1` until persisted. Read-only: the database assigns it. |
| `principalId` | `String` | `principal_id` | The principal the factor belongs to — `TomPrincipal.id` stringified, matching `TomPrincipalResourceGrant.principalId`. |
| `enrolmentId` | `String` | `enrolment_id` | The enrolment's stable client-facing handle (`Tom2FAEnrolment.enrolmentId`). |
| `mechanism` | `String` | `mechanism` | The mechanism key (`Tom2FAEnrolment.type`). |
| `hint` | `String` | `hint` | The displayable hint (`Tom2FAEnrolment.hint`). |
| `enrolledAt` | `DateTime?` | `enrolled_at` | When the factor was set up, **UTC** — `DATETIME(6)`, the width the instant convention writes, so the microseconds it always renders are not rounded off. |
| `isPrimary` | `bool` | `is_primary` | Whether this is the user's default factor. |
| `secretDataCipher` | `String` | `secret_data` | The encrypted `Tom2FAEnrolment.secretData`: base64 of RSA-OAEP over the map's JSON. Never readable from the row alone, which is why `secretData` itself is not a column. |

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
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Resolves the secret — throwing `TomLoginException('login.error.2fa.not-enrolled')` when there is none — and returns a spec whose `clientData` names the code shape (`digits`, `periodSeconds`) so a UI can size its input field. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Re-resolves the secret and compares the trimmed submission against the codes in the skew window, in constant time. Rejects a submission of the wrong width before hashing. |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | *(override)* Generates a secret and offers it as `clientData` — the base32 string plus the `otpauth://` URI under `clientDataUriKey` — with the secret also held in the offer's server-only `enrolmentData`. |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | *(override)* Checks `submitted` against the offered secret and yields the enrolment to store, filed under `enrolmentId: mechanismType` so re-enrolling replaces the old authenticator instead of accumulating one per attempt. Throws `TomLoginException` otherwise. |
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
login rather than becoming a prompt nobody can answer. Subclasses supply six
things: `type`, `destinationOnRecord`, `maskDestination`, `deliver`,
`resolveDeliveryService` and `deliveryServiceType`.

The type parameter `S` is the delivery service the channel sends through, named
so that `requireDeliveryService` hands the subclass its own service back without
a cast. It is also what makes this family a `Tom2FAPrerequisite`: a code
mechanism with nothing to send through cannot be offered, and that has to be
answerable at registration rather than discovered at the challenge.

- **Implements:** `Tom2FAService`, `Tom2FAEnrolmentSupport`,
  `Tom2FAPrerequisite`
- **Abstract**
- **Type parameters:** `S extends Object` — the delivery service

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
| `sendInterval` | `Duration` | The gap required after the first code of a run to one address, doubling for each later code: 30 seconds by default. |
| `maxSendInterval` | `Duration` | The longest gap a run of codes to one address can require: 30 days by default. |
| `deliveryServiceType` | `Type` | *(abstract)* The bean type `resolveDeliveryService` looks for. A `Type` rather than a string so the "install this" diagnostics survive a rename: every message that has to name what is missing interpolates it. |
| `unmetPrerequisite` | `String?` | *(override)* `null`, unless this deployment installed no `deliveryServiceType` — in which case the adaptor could accept a challenge and send no code, so the scan leaves the mechanism out of the registry and logs this line. |
| `descriptor` | `Tom2FAMethodDescriptor` | *(override)* `Tom2FAMethodDescriptor.scoped(type)` — resource keys only, no literal text. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveDeliveryService` | `S? resolveDeliveryService()` | *(abstract)* The service this adaptor sends through, or `null` when the deployment installed none. Resolved per call rather than held: the registry constructs the adaptor before a deployment has necessarily finished installing its beans, so a service captured in a field would be captured as `null` and stay that way. |
| `requireDeliveryService` | `S requireDeliveryService()` | The delivery service, or a `Tom2FAException` (`authentication.2fa.<type>.no_service`) naming what is missing. Reached only when the prerequisite was bypassed — an adaptor registered by hand, or a service uninstalled after the scan — which is a wiring fault either way, so it is not client-throwable: the caller learns the login failed while the operator gets a logged, named cause. |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(abstract)* The destination on the **user record**, or `null`. The asserted address; enrolment is what turns it into a proven one. |
| `maskDestination` | `String maskDestination(String destination)` | *(abstract)* `destination` reduced to what is safe to show a caller who has not yet proved anything. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {required String destination, required String code, required String templateKey, required Duration validity})` | *(abstract)* Sends `code` through this adaptor's channel. Must complete only once a transport has accepted the message, and must throw otherwise. |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Resolves the destination (throwing `login.error.2fa.not-enrolled` when there is none), delivers a fresh code, then returns a spec whose `clientData` holds the masked destination and the digit count and whose `verificationData` holds the sealed code. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Re-hashes the trimmed submission against the seal, in constant time; a match ends the address's send run. |
| `resolveDestination` | `Future<String?> resolveDestination(Tom2FAContext context)` | The destination a challenge goes to: the **confirmed** enrolment first, then the record — so an attacker who can edit a profile field cannot redirect the second factor. A malformed enrolment row is skipped rather than treated as an answer. |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | *(override)* Sends a code to the destination **on record** (not the confirmed one — that would be a tautology) and returns an offer carrying the sealed code and the destination in its encrypted half. Throws `login.error.2fa.no-destination` when the record names none. |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | *(override)* Yields an enrolment only when `submitted` matches; throws `login.error.2fa.enrolment-code-invalid` (or `.enrolment-offer-invalid` for an offer with no destination) rather than returning a nullable, so an unproven destination cannot be stored by forgetting a check. `enrolmentId` is the mechanism type, making re-confirmation an upsert. |
| `requireSendAllowed` | `Future<void> requireSendAllowed(String destination)` | Claims a send from the `Tom2FASendLimiter`, or refuses with `TomLoginException('login.error.2fa.send-limit')` (`TomLoginFailure.rateLimited`, `retryAfterSeconds` in its parameters). Called before every challenge and enrolment code is generated; the claim stands whether delivery then succeeds or not. |
| `deliverOrFail` | `Future<void> deliverOrFail(Tom2FAContext context, {required String destination, required String code, required String templateKey, required Duration validity})` | Calls `deliver` and turns an unclassified failure into `TomLoginException('login.error.2fa.delivery-failed')`, logged, with the cause attached. `TomLoginException` and `Tom2FAException` pass through unchanged — both are already classified, and a wiring fault has a different owner from a relay that is down. |
| `localeFor` | `TomTextLocale? localeFor(Tom2FAContext context)` | The principal's stored language first, then the login attempt's client locale, then `null` so the bundle set applies its own default. |
| `templateParameters` | `Map<String, Object?> templateParameters(Tom2FAContext context, {required String code, required Duration validity})` | `code`, `minutes`, `username`, `firstname`, `lastname`, `application` — supplied whether or not a template mentions them. |
| `generateNumericCode` | `static String generateNumericCode(int digits)` | A decimal code from `RsaKeyHelper.getSecureRandom()`, rejection-sampled so `0`–`5` are no likelier than `6`–`9`. |
| `sealCode` | `static Map<String, Object?> sealCode(String code)` | `code` reduced to a fresh salt and a SHA-256 — the only form of it that may travel. |
| `matchesSealedCode` | `static bool matchesSealedCode(Map<String, Object?> sealed, String submitted)` | Whether `submitted` is the code `sealed` was built from. `false`, never a throw, for a malformed or absent seal. |
| `constantTimeEquals` | `static bool constantTimeEquals(String a, String b)` | Compares without leaking, through timing, how much of a submission was right. |

### TomEmailCode2FAService

A one-time code delivered by email (`@Tom2FAAdaptor('email')`, `@tomReflector`).
Resolves `TomEmailService` from the bean locator at call time. A deployment that
registered none does not normally reach the adaptor at all — the unmet
prerequisite keeps `'email'` out of the registry, so it is never offered;
reached anyway (registered by hand, or the service uninstalled after the scan)
it gets `Tom2FAException('authentication.2fa.email.no_service')`, which is a
wiring fault and not a delivery failure. The address comes from the user's
confirmed `'email'` enrolment, falling back to `TomUser.email`.

- **Extends:** `TomDeliveredCode2FAService<TomEmailService>`

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

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | *(override)* `mechanismType` — `'email'`. |
| `codeDigits` | `int` | *(override)* Reads `globalSettingCodeDigits` (`6`). |
| `attemptsAllowed` | `int` | *(override)* Reads `globalSettingAttemptsAllowed` (`3`). |
| `challengeValidity` | `Duration` | *(override)* Reads `globalSettingChallengeValidity` (10 minutes). |
| `challengeTemplateKey` | `String` | *(override)* Reads `globalSettingChallengeTemplateKey` (`'email.two_factor_code'`). |
| `enrolmentTemplateKey` | `String` | *(override)* Reads `globalSettingEnrolmentTemplateKey` (`'email.two_factor_enrolment'`). |
| `enrolmentAttemptsAllowed` | `int` | *(override)* Reads `globalSettingEnrolmentAttemptsAllowed` (`3`). |
| `enrolmentValidity` | `Duration` | *(override)* Reads `globalSettingEnrolmentValidity` (15 minutes). |
| `deliveryServiceType` | `Type` | *(override)* `TomEmailService` — what the skip message tells an operator to install. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveDeliveryService` | `TomEmailService? resolveDeliveryService()` | *(override)* `TomEmailService.resolve()` — the installed bean, or `null`. |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(override)* `TomUser.email`. |
| `maskDestination` | `String maskDestination(String destination)` | *(override)* Delegates to `maskEmailAddress`. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {...})` | *(override)* Renders `templateKey` through `TomEmailService.deliverNow`, addressed with the user's display name when the record has one. |
| `maskEmailAddress` | `static String maskEmailAddress(String address)` | `alice@example.com` → `a***e@example.com`. The domain is kept whole — it is what tells a user *which* inbox to open — and a local part of two characters or fewer collapses to `***`. A value with no `@` is masked opaquely rather than rejected. |

### TomSmsCode2FAService

A one-time code delivered by SMS (`@Tom2FAAdaptor('sms')`, `@tomReflector`).
Resolves `TomSmsService` from the bean locator at call time; absent, the
mechanism is skipped at the scan rather than offered, and
`authentication.2fa.sms.no_service` is what a bypassed prerequisite raises. The
two channels are judged separately, so a deployment that sends mail but has no
SMS contract keeps its mail codes. The number comes from the user's confirmed
`'sms'` enrolment, falling back to `TomUser.mobile` and then `TomUser.phone` —
the same order `TomSmsRequest.toPrincipal` uses, so a code and a notification
reach the same handset.

- **Extends:** `TomDeliveredCode2FAService<TomSmsService>`

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

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | *(override)* `mechanismType` — `'sms'`. |
| `codeDigits` | `int` | *(override)* Reads `globalSettingCodeDigits` (`6`). |
| `attemptsAllowed` | `int` | *(override)* Reads `globalSettingAttemptsAllowed` (`3`). |
| `challengeValidity` | `Duration` | *(override)* Reads `globalSettingChallengeValidity` (5 minutes). |
| `challengeTemplateKey` | `String` | *(override)* Reads `globalSettingChallengeTemplateKey` (`'sms.two_factor_code'`). |
| `enrolmentTemplateKey` | `String` | *(override)* Reads `globalSettingEnrolmentTemplateKey` (`'sms.two_factor_enrolment'`). |
| `enrolmentAttemptsAllowed` | `int` | *(override)* Reads `globalSettingEnrolmentAttemptsAllowed` (`3`). |
| `enrolmentValidity` | `Duration` | *(override)* Reads `globalSettingEnrolmentValidity` (10 minutes). |
| `deliveryServiceType` | `Type` | *(override)* `TomSmsService` — what the skip message tells an operator to install. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveDeliveryService` | `TomSmsService? resolveDeliveryService()` | *(override)* `TomSmsService.resolve()` — the installed bean, or `null`. |
| `destinationOnRecord` | `String? destinationOnRecord(Tom2FAContext context)` | *(override)* The first non-blank of `TomUser.mobile`, `TomUser.phone`. |
| `maskDestination` | `String maskDestination(String destination)` | *(override)* Delegates to `maskPhoneNumber`. |
| `deliver` | `Future<void> deliver(Tom2FAContext context, {...})` | *(override)* Renders `templateKey` through `TomSmsService.deliverNow`. |
| `maskPhoneNumber` | `static String maskPhoneNumber(String number)` | `+41791234567` → `+*******4567`. The last four **digits** are kept and non-digits are preserved, so `+41 79 …` and `0041 79 …` still look like the same handset. Counted over digits rather than characters, so spacing does not change which part survives. |

### TomWebAuthn2FAService

Passkeys as a second factor (`@Tom2FAAdaptor('webauthn')`, `@tomReflector`).
Issues WebAuthn creation and request options, verifies the authenticator's
response with `TomWebAuthnVerifier`, stores one enrolment per credential, and
writes the signature counter back after every login. Offered only once
`globalSettingRelyingPartyId` is set (`Tom2FAPrerequisite`). Attestation is
requested as `none` and not verified.

- **Implements:** `Tom2FAService`, `Tom2FAEnrolmentSupport`, `Tom2FAPrerequisite`

#### Constructors

```dart
TomWebAuthn2FAService()
```

*(no-argument, so the registry can reflect it into life)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mechanismType` | `String` | `'webauthn'`. |
| `optionsKey` | `String` | `'publicKey'` — the `clientData` key the options travel under. |
| `challengeKey` | `String` | `'challenge'` — where the issued challenge is kept in the encrypted half. |
| `credentialIdKey` / `publicKeyKey` / `signCountKey` / `userHandleKey` | `String` | The keys of an enrolment's `secretData`. |
| `globalSettingRelyingPartyId` | `String` | The registrable domain passkeys are bound to. Empty (the default) keeps the mechanism out of the registry. |
| `globalSettingRelyingPartyName` | `String` | The RP display name; the context's application when empty. |
| `globalSettingAllowedOrigins` | `Set<String>` | The origins a ceremony may run on; empty means `https://<RP id>`. |
| `globalSettingUserVerification` | `TomWebAuthnUserVerification` | Defaults to `preferred`; `required` refuses an answer without the user-verified flag. |
| `globalSettingAttemptsAllowed` | `int` | Defaults to `3`. |
| `globalSettingChallengeValidity` | `Duration` | Defaults to 5 minutes. |
| `globalSettingEnrolmentAttemptsAllowed` | `int` | Defaults to `3`. |
| `globalSettingEnrolmentValidity` | `Duration` | Defaults to 10 minutes. |
| `allowedOrigins` | `Set<String>` | *(getter)* The effective origin set. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `descriptor` | `Tom2FAMethodDescriptor` | *(override)* Scoped under `'webauthn'`. |
| `unmetPrerequisite` | `String?` | *(override)* Names the unset RP id, or `null`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `issueChallenge` | `Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context)` | *(override)* Request options allowing every enrolled credential; `login.error.2fa.not-enrolled` when there is none. |
| `verifySubmission` | `Future<bool> verifySubmission(Tom2FAContext context, Tom2FASubmission submission)` | *(override)* Verifies the assertion against the matching credential and stores the new counter. Any failure is `false`. |
| `beginEnrolment` | `Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context)` | *(override)* Creation options, excluding the user's existing credentials. |
| `confirmEnrolment` | `Future<Tom2FAEnrolment> confirmEnrolment(Tom2FAContext context, Tom2FAEnrolmentOffer offer, String submitted)` | *(override)* Verifies the registration; `login.error.2fa.webauthn-registration-invalid` on any failed check, `login.error.2fa.enrolment-offer-invalid` for an offer with no challenge. |
| `userHandleOf` | `static String userHandleOf(Tom2FAContext context)` | The opaque user handle: SHA-256 of the principal key, base64url. |

### TomWebAuthnVerifier

The WebAuthn ceremony checks (WebAuthn Level 2 §7.1, §7.2) as pure functions.
Each answers `null` for anything that fails. Not constructible.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `verifyRegistration` | `static TomWebAuthnRegisteredCredential? verifyRegistration({required TomWebAuthnRegistrationResponse response, required String expectedChallenge, required String rpId, required Set<String> allowedOrigins, required TomWebAuthnUserVerification userVerification})` | Client data (type, challenge, origin), RP id hash, flags, the attested credential id and an ES256 or RS256 COSE key. |
| `verifyAssertion` | `static TomWebAuthnVerifiedAssertion? verifyAssertion({required TomWebAuthnAuthenticationResponse response, required String expectedChallenge, required String rpId, required Set<String> allowedOrigins, required TomWebAuthnUserVerification userVerification, required String publicKey, required int storedSignCount, String? expectedUserHandle})` | Client data, RP id hash, flags, the signature, the rising counter and the user handle. |

### TomWebAuthnRegisteredCredential

A credential registration verified: `credentialId`, `publicKey` (COSE,
base64url) and `signCount`.

#### Constructors

```dart
const TomWebAuthnRegisteredCredential({
  required String credentialId,
  required String publicKey,
  required int signCount,
})
```

### TomWebAuthnVerifiedAssertion

An assertion that verified: the new `signCount`, and `userVerified`.

#### Constructors

```dart
const TomWebAuthnVerifiedAssertion({
  required int signCount,
  required bool userVerified,
})
```

### TomWebAuthnSoftwareAuthenticator

A passkey authenticator in software, for tests and bring-up **only**: a P-256
key pair in memory, `none` attestation, and deterministic ECDSA signatures.

#### Constructors

```dart
factory TomWebAuthnSoftwareAuthenticator({
  required String origin,
  bool userVerified = true,
  bool countsSignatures = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `origin` | `String` | The origin the "browser" writes into client data; settable, so a test can sign on another one. |
| `userVerified` | `bool` | Whether the user-verified flag is set. |
| `countsSignatures` | `bool` | Whether the counter moves; synced passkeys report `0`. |
| `credentialId` | `Uint8List` | The credential id (final). |
| `signCount` | `int` | The signature counter. |
| `id` | `String` | The credential id, base64url. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `create` | `TomWebAuthnRegistrationResponse create(TomWebAuthnCreationOptions options)` | Answers a creation request. |
| `get` | `TomWebAuthnAuthenticationResponse get(TomWebAuthnRequestOptions options, {String? userHandle})` | Signs a request. |

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
and exposes the pass methods as HTTP endpoints. The service used per flow is
selected via the static globals; the issued tokens' issuer, audience and
signing key are `TomJwtSigning.current`'s, and a verify-only server refuses to
issue with `jwt.keys.verify_only`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingUserAuthenticationService` | `TomAuthenticationService` | The service used for authenticated-user logins (pass 1). Defaults to `TomDummyAuthenticationService()`. |
| `globalSettingGuestAuthenticationService` | `TomAuthenticationService` | The service used for guest logins. Defaults to `TomDummyAuthenticationService()`. |

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
| `authenticateUser` | `Future<TomAuthenticationResult> authenticateUser(TomAuthenticationMessage m, bool guestLogin)` | Runs a login: builds `TomAuthenticationData`, delegates to the guest or user service per `guestLogin`, and encodes the principal into the authentication/authorization JWTs of the result. What follows a verified credential is the policy's to decide and not the principal's: the server asks `Tom2FAPolicy.resolve().decideFor(context)` once, and a decision that `isSatisfiedWithoutFactor` completes the login here. Otherwise it challenges the user's primary enrolled mechanism among those the decision permits — or offers enrolment instead, when a `Tom2FAEnrolmentStore` is installed and the user has none — and returns an interim token either way. Fails on `login.error.2fa.unsupported-mechanism` when no mechanism the decision permits has an adaptor in `Tom2FARegistry`. The default policy `TomPrincipalFlag2FAPolicy` reads `requires2FA` and `twoFactorType` off the principal, so a deployment that installs none keeps the pre-policy behaviour; one that installs `TomRole2FAPolicy` gets a second factor for principals whose `requires2FA` is false. |
| `authenticateExternal` | `Future<TomAuthenticationResult> authenticateExternal(TomAuthenticationMessage m, Object credential)` | Authenticates a login whose credential was established by an external identity provider, and completes it exactly as a password login does. `credential` travels in `TomAuthenticationData.key` — the slot a password would occupy — and is verified by `globalSettingUserAuthenticationService`, which a deployment offering external identity wraps in a `TomOAuthAuthenticationService`. Adds no second way to authenticate: the 2FA policy, the enrolment offer, the stored-timezone resolution and the claim set all come from the same continuation `authenticateUser` reaches, so this method raises no error keys of its own. |
| `beginTwoFactorEnrolment` | `Future<TomAuthenticationResult> beginTwoFactorEnrolment(TomAuthenticationMessage m, {TomClientJwtToken? enrolmentToken})` | Enrolment pass 1: begins setting up the mechanism the user chose. The mechanism key travels in `m.password`; the offer is recovered from the interim token the client presents as its bearer (`enrolmentToken` overrides that lookup for tests running without a request zone). Returns an interim token whose public claims carry the mechanism's `Tom2FAEnrolmentOffer.clientData` — for TOTP the secret and the `otpauth://` URI to scan — and whose encrypted section carries the whole offer. Refuses a mechanism absent from the offer this token was issued with, failing on `login.error.2fa.enrolment-not-offered` or `.unsupported-mechanism`. |
| `completeTwoFactorEnrolment` | `Future<TomAuthenticationResult> completeTwoFactorEnrolment(TomAuthenticationMessage m, {TomClientJwtToken? enrolmentToken})` | Enrolment pass 2: confirms the offer and completes the login. The typed confirmation travels in `m.password`. On success the factor is written to the `Tom2FAEnrolmentStore` and the full token pair is issued immediately, with no further challenge. A wrong code stores nothing and re-issues the same offer with one attempt spent, exactly as `authenticatePass2` does, until `Tom2FAEnrolmentOffer.attemptsAllowed` is exhausted. Fails on `login.error.2fa.enrolment-offer-invalid` / `.enrolment-expired` / `.enrolment-attempts-exhausted` / `.unsupported-mechanism` / `.enrolment-unavailable`. |
| `skipTwoFactorEnrolment` | `Future<TomAuthenticationResult> skipTwoFactorEnrolment(TomAuthenticationMessage m, {TomClientJwtToken? enrolmentToken})` | Declines a skippable enrolment offer and completes the login with no factor. A pass of its own rather than a flag on `completeTwoFactorEnrolment`, because "I set up a factor" and "I chose not to" are different events with different consequences — only the second spends a grace login. Refuses unless the presented token, which this server signed, says the offer was skippable; fails on `login.error.2fa.enrolment-required` or `.no-enrolment`. |

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
| `fromConfiguration` | `static TomServiceCredential? fromConfiguration(TomBaseServerConfiguration config)` | Reads the credential out of `config`, or returns `null` when self-login is not (or only partially) configured — the supported, silent default. All three required values count as absent when they are **whitespace**, the credential included; the trim decides only *whether* one was configured, and the value is carried through as written. |
| `toRequestBody` | `String toRequestBody()` | The login request body, shaped as the kernel's `TomAuthenticationMessage`. Written by hand so the credential never passes through a general-purpose serialiser. The identity fields come from the credential; the three locale fields are **read from `TomAuthenticationMessage`'s own defaults**, because a deployment is a process rather than a device and has no locale to assert. |

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
TomServerSelfLoginException(
  String key,
  String defaultUserMessage, {
  TomServerCallError? serverCallError,
  Object? rootException,
})
```

`serverCallError` carries the kernel's account of the outbound HTTP call when
the failure came from one — the status, the body, the underlying exception —
which is what turns "could not be reached" from a sentence an operator reads
into a value anything can branch on. It never reaches a client: this type masks
its message, and `tomErrorEnvelope` does not serialise the field.

Keys raised: `server.selflogin.unreachable`, `server.selflogin.rejected`,
`server.selflogin.bad_response`, `server.selflogin.no_token`,
`server.selflogin.bad_token`.

### TomServerSession

What a self-login produced: the deployment's principal, and how long the tokens
that carry it are good for. The expiry is here rather than inferred by the
caller because it is the one fact renewal is scheduled against.

#### Constructors

```dart
const TomServerSession({
  required TomPrincipal principal,
  required DateTime expiresAt,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `principal` | `TomPrincipal` | The deployment, as a principal (final). |
| `expiresAt` | `DateTime` | The **earlier** of the two tokens' expiries — the session is only as good as its shorter half, and a still-valid authentication token beside an expired authorization token is a principal whose grants have lapsed. Never absent: a session is built only from live tokens, and a token without `exp` is refused (`server.selflogin.bad_token`), so every installed session has a deadline to renew against. |

### TomServerSelfLogin

Logs the deployment in as itself and installs the resulting principal, whose
entitlements are the feature grants of this deployment and therefore cap every
user's grants (the `min(user, server)` meet in the kernel's `TomAccessControl`).
Statics only — the constructor is private.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `logIn` | `static Future<TomServerSession> logIn(TomServiceCredential credential, {TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(), bool decryptTokens = true})` | Logs in with `credential` and returns the deployment's session — the principal, and when its tokens expire. Throws `TomServerSelfLoginException` when the auth server is unreachable, refuses, answers in an unexpected shape, or returns a token that carries no payload. |
| `loginAndInstall` | `static Future<bool> loginAndInstall(TomBaseServerConfiguration config, {TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(), bool decryptTokens = true, bool renew = true})` | Logs in from `config` and installs the principal into `TomServerPrincipal`; returns whether one was installed. Returns `false` silently when self-login is not configured, so a deployment that configures none is unaffected. `TomServer.start()` calls this itself before binding the socket; call it directly only from a process that has no `TomServer`. Schedules the renewal below unless `renew: false`. |
| `renewNow` | `static Future<bool> renewNow()` | Logs in again with the credential `loginAndInstall` used and installs the result; returns whether it succeeded. **A failure keeps the principal it has** — the old cap may be stale, and a stale cap is still a cap, where dropping it would widen every user's access at the moment the auth server became unreachable. The failure is logged and another attempt is scheduled. |
| `stopRenewal` | `static void stopRenewal()` | Cancels any scheduled renewal, leaving the installed principal in place. Not a way to drop the principal, and there is deliberately no such call: clearing it widens access. |
| `renewalDelayFor` | `static Duration renewalDelayFor(DateTime expiresAt, {DateTime? now, Duration? lead})` | How long to wait before renewing a session expiring at `expiresAt` — one lead before it, clamped to `minimumRenewalDelay` so a session shorter than the lead, or one already past, schedules a prompt attempt rather than a negative delay. Public and pure because the arithmetic has three edges and a timer is a poor place to discover which was taken. |

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `globalSettingRenewalLead` | `Duration` | How long before expiry the next login is attempted (2 minutes). Long enough that a slow auth server does not leave the deployment capping at an expired principal, short enough that the extra logins are noise rather than load. |
| `globalSettingRenewalRetry` | `Duration` | How soon a *failed* renewal is tried again (30 seconds) — sooner than the lead, because the session is now closer to expiry than when the attempt was scheduled. |
| `minimumRenewalDelay` | `Duration` | The shortest delay the loop will schedule (1 second), reached when a session's whole life is shorter than the lead. Legitimate for very short service tokens, and a busy-wait without the clamp. |
| `installedUntil` | `DateTime?` | *(getter)* When the installed session expires, or `null` when nothing is installed or no token carried an `exp`. The fact a deployment needs to build its own renewal, exposed whether or not it uses the one here. |
| `isRenewing` | `bool` | *(getter)* Whether a renewal is currently scheduled. |

### TomOAuthException

An external-login handshake or provider configuration that could not proceed.
Raised at startup for a malformed `oauth.providers` block, and during a login
for a refused or unverifiable handshake.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomOAuthException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
  bool clientThrow = false,
})
```

`clientThrow` defaults to `false` rather than to `TomServerException`'s `true`:
a misconfigured provider is an operator's problem, and its detail — endpoint
URLs, client ids — is not a caller's business. `autoLog` is the one inherited
parameter this constructor does *not* forward.

Keys raised: `oauth.config.missing_value`, `oauth.config.not_a_map`,
`oauth.config.provider_not_a_map`, `oauth.config.unknown_provider`,
`oauth.config.unknown_provisioning`, `oauth.config.invalid_clock_skew`,
`oauth.config.invalid_role_mapping`, `oauth.config.discovery_not_loaded`,
`oauth.config.discovery_failed`, `oauth.config.discovery_issuer_mismatch`,
`oauth.config.duplicate_provider_id`,
`oauth.flow.unknown_state`, `oauth.flow.nonce_mismatch`,
`oauth.flow.missing_code`, `oauth.flow.token_exchange_rejected`,
`oauth.flow.no_claims_source`, `oauth.flow.no_access_token`,
`oauth.flow.issuer_mismatch`, `oauth.flow.audience_mismatch`,
`oauth.flow.missing_subject`, `oauth.flow.malformed_id_token`,
`oauth.flow.missing_expiry`, `oauth.flow.id_token_expired`,
`oauth.flow.id_token_not_yet_valid`,
`oauth.provider.http_error`, `oauth.provider.malformed_json`.

### TomOAuthProvisioning

What a successful external login does when no local account is linked to the
identity. A **configuration choice per provider**, because each answer is
correct for a different deployment. `autoProvision` is the default of both
provider types — single sign-on against an enterprise identity provider is the
case the module is built for, and there the identity provider is the account
register. A deployment offering a public provider sets `refuse` for it.

| Value | Meaning |
| ----- | ------- |
| `refuse` | Admit only identities already linked to a local account. |
| `linkExisting` | Link an identity whose asserted username names an existing local account, and refuse one that names none — for accounts created elsewhere (by an administrator, or pushed by SCIM) before their owners first sign in. |
| `autoProvision` | Create the account through `TomExternalIdentityDirectory.provisionFromExternalIdentity`, and link an existing local account that already carries the asserted username. The default. |

Linking an existing account is refused with `login.error.oauth.unverified-email`
when the provider states `email_verified: false`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomOAuthProvisioning parse(String raw)` | Reads the configured spelling (`refuse`, `linkExisting`, `autoProvision`; case, `_` and `-` ignored). Throws `oauth.config.unknown_provisioning` for anything else rather than falling back to a default — a typo must not silently enable or disable provisioning. |

### TomOAuthProviderConfig

One identity provider *registration*, as data. Immutable, and keyed by its own
`id`: `issuer` is an ordinary field underneath and is deliberately not unique,
so a deployment may register one IdP twice under two scope sets or two client
registrations. Every decision a login takes from configuration follows the
registration the flow began with — see
[Two registrations against one IdP](../authentication.md#two-registrations-against-one-idp).

- **Implements:** `TomExternalProvider`

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
  String? revocationEndpoint,
  String? clientSecret,
  List<String> scopes = const ['openid', 'email', 'profile'],
  bool usePkce = true,
  String subjectClaim = 'sub',
  String usernameClaim = 'email',
  String displayNameClaim = 'name',
  TomOAuthProvisioning provisioning = TomOAuthProvisioning.autoProvision,
  TomExternalRoleMapping roleMapping = TomExternalRoleMapping.none,
  String displayNameKey = '',
  String iconKey = '',
  bool storeTokens = false,
  Map<String, String> authorizationParameters = const {},
  Duration clockSkew = TomOAuthProviderConfig.defaultClockSkew,
})

factory TomOAuthProviderConfig.fromMap(String id, Map<Object?, Object?> map)
```

`fromMap` demands every required value rather than defaulting it: a provider
missing its token endpoint is a configuration error, and one that must fail at
startup rather than as a failed login weeks later. `scopes` is accepted as a
YAML list *or* a single space-separated string, which is how every provider's
own documentation writes them. A provider with `discovery: true` takes its
missing endpoints from its discovery document — which `fromMap` does not read;
asked for one it lacks, it throws `oauth.config.discovery_not_loaded`, naming
`TomOAuthProviders.load`.

One field exists for single sign-on:

| Field | Notes |
| ----- | ----- |
| `roleMapping` | The `TomExternalRoleMapping` read from `groupsClaim`, `roleMapping` and `defaultRoles`; `TomExternalRoleMapping.none` unless configured. The roles it grants are applied to the principal on every login. |

Three fields exist for delegated access rather than for login:

| Field | Notes |
| ----- | ----- |
| `revocationEndpoint` | Where a grant is revoked (RFC 7009), or `null` when the provider publishes none — the majority case, and never defaulted: guessing an address for a security-relevant call would mean posting a live credential at a URL nobody configured. `TomExternalIdentityStore.unlink` uses it, so pressing disconnect ends the credential rather than merely forgetting it. |
| `storeTokens` | Whether a completed exchange's `TomOAuthTokenGrant` is *retained*. `false` by default, and opt-in per provider exactly as scopes are: a deployment that only wanted "Sign in with …" must never end up holding a third-party refresh token. The grant is always *surfaced* on `TomOAuthExchange.tokens` regardless — this governs storage, not capability. |
| `authorizationParameters` | Extra query parameters merged into the authorization redirect, for the provider-specific opt-ins a grant needs (Google returns no refresh token without `access_type=offline`). Applied **before** the flow's own parameters, so a configuration typo cannot replace `state`, `redirect_uri` or the PKCE challenge. Must be a map of scalars — `oauth.config.parameters_not_a_map` / `oauth.config.parameter_not_a_scalar` otherwise. |

One field exists for the clocks:

| Field | Notes |
| ----- | ----- |
| `clockSkew` | How far this provider's clock may run ahead of or behind ours before the `id_token`'s `exp` and `nbf` are believed. `defaultClockSkew` (60 s) unless configured. YAML key `clockSkewSeconds`; `0` is a legitimate setting and is distinguished from absent, negative or non-numeric is `oauth.config.invalid_clock_skew`. Per provider because the drift being tolerated belongs to one specific IdP — widening it for the badly-synchronised one must not loosen every other. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isDiscovered` | `static bool isDiscovered(Map<Object?, Object?> map)` | Whether a provider's configuration map sets `discovery: true`. |
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
are different states. It reads no discovery document, so a `discovery: true`
provider without explicit endpoints is refused with
`oauth.config.discovery_not_loaded`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static TomOAuthProviders? resolve()` | The installed bean, or `null`. `null` rather than a throw, because "this deployment offers no external login" is the majority case. |
| `load` | `static Future<TomOAuthProviders> load({TomServerConfigResourceProvider? config, TomOAuthTokenTransport? transport})` | The start-up call for a deployment with enterprise identity providers: reads `oauth.providers`, fetching the discovery document of every `discovery: true` provider. Empty when the key is absent. |
| `discover` | `static Future<TomOAuthProviders> discover(Object? raw, {TomOAuthTokenTransport? transport})` | The provider set `raw` configures, each `discovery: true` provider's `authorizationEndpoint`, `tokenEndpoint`, `userInfoEndpoint` and `revocationEndpoint` read from `discoveryUrl`, or from `<issuer>/.well-known/openid-configuration`. An endpoint configured explicitly wins. The document's `issuer` must equal the configured one exactly (`oauth.config.discovery_issuer_mismatch`); a document that cannot be read fails with `oauth.config.discovery_failed`. |
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
pair, `createdAt`, the `nonce` the next leg must echo, the `assertedIdentity` a
SAML response verified, and the login context the flow started in (`client`,
`application`, `process`, `organization`, `clientLanguage`, `clientCountry`,
`clientTimezone`).

```dart
TomOAuthAuthorizationState({
  required String state,
  required String providerId,
  required DateTime createdAt,
  TomOAuthPkce? pkce,
  String nonce = '',
  TomExternalIdentity? assertedIdentity,
  String client = '',
  String application = '',
  String process = '',
  String organization = '',
  String clientLanguage = '',
  String clientCountry = '',
  String clientTimezone = '',
})
```

| Field | Type | Notes |
| ----- | ---- | ----- |
| `nonce` | `String` | For an OpenID Connect flow, the `nonce` sent in the authorization request, which the `id_token` must carry back. For a SAML flow, the `ID` of the `AuthnRequest` the response must name in `InResponseTo`, and, once the response is verified, the SHA-256 of the handoff code. `''` when the flow sent none. |
| `assertedIdentity` | `TomExternalIdentity?` | The identity a SAML response asserted, waiting between the assertion consumer service and the application's completion; `null` on every other record. |

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

### TomSqlOAuthStateStore

The shared store: pending authorizations as rows in `tom_oauth_state`, so an
authorization begun on one node completes on any other.

```dart
TomSqlOAuthStateStore(
  TomDataSource datasource, {
  String table = defaultOAuthStateTable,
  bool createSchema = true,
  Duration timeToLive = const Duration(minutes: 10),
  Duration sweepInterval = const Duration(minutes: 1),
})

factory TomSqlOAuthStateStore.named(
  String datasourceName, {
  String table = defaultOAuthStateTable,
  bool createSchema = true,
  Duration timeToLive = const Duration(minutes: 10),
  Duration sweepInterval = const Duration(minutes: 1),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | Where the table lives |
| `table` | `String` | The pending-authorization table |
| `createSchema` | `bool` | Create the table on first use |
| `timeToLive` | `Duration` | Measured from `createdAt`, as the memory store measures its own |
| `sweepInterval` | `Duration` | How often `store` prunes; a cost control, not a correctness one |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `ensureSchema()` | `Future<void>` | Creates the table if absent; idempotent, and called by every operation |
| `store(TomOAuthAuthorizationState)` | `Future<void>` | Records a pending authorization. `INSERT`, not `REPLACE` — a duplicate handle is an error, never an overwrite |
| `peek(String state)` | `Future<TomOAuthAuthorizationState?>` | Reads without spending; `null` for unknown *and* expired |
| `consume(String state)` | `Future<TomOAuthAuthorizationState?>` | Spends the record in **one** `DELETE … RETURNING`, so two racing callbacks cannot both be answered |
| `purgeExpired([DateTime now])` | `Future<int>` | Deletes what has expired; affects size, never behaviour. The **only** place the expiry predicate is written — `store`'s throttled sweep comes through here, passing the instant it stamped its throttle with |
| `deleteAll()` | `Future<void>` | Empties the table, for provisioning and tests |

`named` throws `oauth.state_store.unknown_datasource` when no such data source
is registered — a start-up failure rather than a first-login one. Expiry is a
predicate (`expires_at > :now`) on every read, so a row is invisible from the
instant it expires whether or not the sweep has reached it. The sweep prunes by
calling `purgeExpired`, so what it deletes and what an operator's prune deletes
are the same statement rather than two copies of one.

### TomOAuthStateRow

One `tom_oauth_state` row, as `peek` and `consume` read it back — reflected,
`@TomDbTable`-mapped, and internal to the store.

Fifteen `@TomDbColumn` fields. The two instants are typed `String` because the
driver decodes `DATETIME` as local time; `parseSqlInstant` turns them back into
UTC.

#### Properties

| Property | Type | Column | Description |
| -------- | ---- | ------ | ----------- |
| `state` | `String` | `state` | The opaque handle the provider echoes back. |
| `providerId` | `String` | `provider_id` | Which provider the flow is against. |
| `pkceVerifier` | `String?` | `pkce_verifier` | The PKCE secret, or `null` for a provider configured without PKCE. |
| `pkceChallenge` | `String?` | `pkce_challenge` | The PKCE challenge that travelled to the provider. |
| `createdAt` | `String` | `created_at` | When the flow began, as the stored `DATETIME(6)` text — see above for why it is not a `DateTime`. |
| `expiresAt` | `String` | `expires_at` | When the record stops being completable, as the stored text. |
| `client` | `String` | `client` | The client the login was started from. |
| `application` | `String` | `application` | The application the login is for. |
| `process` | `String` | `process` | The process the login is for. |
| `organization` | `String` | `organization` | The organization the login is for. |
| `clientLanguage` | `String` | `client_language` | The client's language code. |
| `clientCountry` | `String` | `client_country` | The client's country code. |
| `clientTimezone` | `String` | `client_timezone` | The client's IANA timezone name. |
| `nonce` | `String` | `nonce` | What the flow's next leg must echo, or `''`. |
| `assertedIdentity` | `String?` | `asserted_identity` | A verified SAML identity as JSON (`TomExternalIdentity.toJson`), or `null`. |

### TomOAuthStateStoreType

Which store a deployment selected.

| Value | Meaning |
| ----- | ------- |
| `memory` | `TomOAuthMemoryStateStore`, per-process. The default |
| `sql` | `TomSqlOAuthStateStore`, shared through a data source |

`TomOAuthStateStoreType.parse(String)` throws
`oauth.config.unknown_state_store` on anything else rather than falling back to
`memory`: a typo that quietly selected the per-process store would reintroduce
the intermittent clustered failure the SQL store exists to remove.

### TomOAuthStateStoreSettings

The `oauth.stateStore` block as data, read beside `oauth.providers`.

```dart
const TomOAuthStateStoreSettings({
  TomOAuthStateStoreType type = TomOAuthStateStoreType.memory,
  String datasourceName = '',
  String table = defaultOAuthStateTable,
  Duration timeToLive = const Duration(minutes: 10),
  bool createSchema = true,
})

factory TomOAuthStateStoreSettings.fromConfiguration([
  TomServerConfigResourceProvider? configuration,
])
```

#### Static Properties

| Property | Value | Description |
| -------- | ----- | ----------- |
| `configurationKey` | `'oauth.stateStore'` | Where the block is read from |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `createStore()` | `TomOAuthStateStore` | The store these settings describe, ready to install as a `TomBean` |

Configuration keys: `type`, `datasource`, `table`, `timeToLiveSeconds`,
`createSchema`. An absent block means `memory`, so a deployment that has never
heard of the SQL store configures nothing. A malformed one fails at start-up —
`oauth.config.state_store_not_a_map`, `oauth.config.unknown_state_store`,
`oauth.config.missing_state_store_datasource`,
`oauth.config.invalid_state_store_ttl`.

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
`displayName`, the raw `claims`, the `groups` read through the provider's
`TomExternalRoleMapping.groupsClaim` and the `roles` its mapping grants. The
`(issuer, subject)` pair *is* the identity — a subject is only unique within its
issuer. For a SAML identity the claims are the assertion's attributes: a single
value as a string, several as a list.

```dart
const TomExternalIdentity({
  required String issuer,
  required String subject,
  String username = '',
  String displayName = '',
  Map<String, Object?> claims = const {},
  List<String> groups = const [],
  List<String> roles = const [],
})

factory TomExternalIdentity.fromJson(Map<String, Object?> json)
```

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `groups` | `List<String>` | The groups the provider asserted. |
| `roles` | `List<String>` | The Tom roles the provider's mapping grants for `groups`; applied to the session's principal on every login. |
| `toJson` | `Map<String, Object?> toJson()` | The identity as JSON, for a store that holds a verified identity between two requests. |
| `fromJson` | `factory TomExternalIdentity.fromJson(Map<String, Object?> json)` | The inverse of `toJson`. |

### TomOAuthExchange

The result of a completed handshake: the `provider` it was against, the
`identity` that provider asserted, and the `pending` record it completed, so the
caller can replay the login context the flow captured.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `identity` | `TomExternalIdentity` | Who the provider says this is. |
| `pending` | `TomOAuthAuthorizationState` | The record the exchange spent, carrying the login context. |
| `provider` | `TomExternalProvider` | The provider this exchange was completed against — a `TomOAuthProviderConfig` or a `TomSamlProviderConfig` — resolved **once** from `pending.providerId`. Carried rather than re-derived, because a login takes several decisions out of provider configuration at points far enough apart that two of them could resolve differently and disagree about which login this was. Deriving it from `identity.issuer` is not equivalent: the issuer names the IdP and two registrations may share one — see [Two registrations against one IdP](../authentication.md#two-registrations-against-one-idp). |
| `tokens` | `TomOAuthTokenGrant?` | The provider's grant, or `null` when the response carried no access token (an `id_token`-only OIDC response). Surfaced on **every** exchange, whatever `storeTokens` says — retention is a storage decision, and a caller that wants the grant for the duration of *this* request may always have it. |

### TomOAuthFlow

The authorization-code + PKCE handshake, and the entry point for every external
login: a provider id that names a SAML identity provider is begun and completed
through `saml`. Immutable; holds `providers`, `stateStore`, `transport` and
`saml`.

#### Constructors

```dart
TomOAuthFlow({
  required TomOAuthProviders providers,
  required TomOAuthStateStore stateStore,
  required TomOAuthTokenTransport transport,
  TomSamlFlow? saml,
})

factory TomOAuthFlow.fromBeans()
```

Provider ids are one namespace across both protocols: an id configured as both
an OAuth and a SAML provider throws `oauth.config.duplicate_provider_id`.
`fromBeans` resolves the `TomOAuthProviders` and `TomSamlProviders` beans,
falling back to configuration for each, and builds a `TomSamlFlow` over the same
state store when any SAML provider is configured.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providers` | `TomOAuthProviders` | The OAuth 2.0 / OpenID Connect providers. |
| `stateStore` | `TomOAuthStateStore` | Where pending authorizations are kept, for both protocols. |
| `transport` | `TomOAuthTokenTransport` | The one HTTP seam. |
| `saml` | `TomSamlFlow?` | The SAML 2.0 identity providers, or `null` when the deployment has none. |
| `descriptors` *(getter)* | `List<TomOAuthProviderDto>` | Every provider a login page offers — the OAuth providers, then the SAML ones. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `beginAuthorization` | `Future<TomOAuthAuthorizationDto> beginAuthorization(TomOAuthAuthorizationRequest request)` | Records the pending authorization and answers where to send the browser. Sends a `nonce` whenever the scopes include `openid`. Dispatches to `saml` for a SAML provider id. Preserves any query the provider's authorization endpoint already carries (some tenanted providers encode the tenant there). |
| `completeAuthorization` | `Future<TomOAuthExchange> completeAuthorization({required String code, required String state})` | Spends the pending record, exchanges the code, verifies the claims, and answers who the provider says this is — or, for a SAML record, hands over the identity the assertion consumer service verified. Verification covers *whose flow this is* (the `id_token`'s `nonce`, `oauth.flow.nonce_mismatch`), *who minted this* (`iss`, `aud`) and *is it still valid* (`exp`, and `nbf` when sent, against the provider's `clockSkew`) — the second does not follow from the first, and is checked even though the signature is not. |
| `revokeGrant` | `Future<bool> revokeGrant({required String providerId, required TomOAuthTokenGrant grant})` | Revokes `grant` at the provider's `revocationEndpoint` (RFC 7009). `true` when the provider was asked and did not refuse; `false` when there was nothing to ask — no endpoint configured, or no token — which is a different fact from a refusal and acted on differently. The **refresh token** is what is revoked when there is one: it ends the chain, where an access token outlives it by minutes. An empty body is the success RFC 7009 specifies, for an unknown token as well as a real one; a body decoding to an object with `error` throws `oauth.flow.revocation_rejected`. |
| `revokeGrantsFor` | `static Future<int> revokeGrantsFor({required String issuer, required String subject, TomOAuthProviders? providers, TomOAuthTokenStore? tokenStore, TomOAuthTokenTransport? transport})` | What `TomExternalIdentityStore.unlink` calls, and it **never throws**: refusing to unlink because a provider is unreachable would leave the deployment holding the credential it was just told to drop. Every failure is logged, naming what stays valid where, and the deletion proceeds. Asks **every registration sharing the issuer**, because the token store is keyed by issuer and so does not record which client credentials minted the grant; RFC 7009 makes an unrecognised token a success, so the extra call costs nothing. Answers how many registrations accepted. |
| `refreshGrant` | `Future<TomOAuthTokenGrant> refreshGrant({required String providerId, required TomOAuthTokenGrant grant})` | Exchanges the grant's refresh token for a fresh one. **Not a login**: no `TomAuthenticationService`, no 2FA policy, no session, no principal. Throws `oauth.flow.no_refresh_token` when the grant carries none — the caller must send the user through consent again, which is a different action rather than a slower one. |
| `accessTokenFor` | `Future<TomOAuthTokenGrant?> accessTokenFor({required String providerId, required String subject, Duration minimumValidity = const Duration(seconds: 30), TomOAuthTokenStore? store})` | A live access token for the identity, refreshed and written back when it is within `minimumValidity` of expiry. `null` when nothing is held, when the held grant expired unrefreshably, or when no store is installed — the cue to send the user through consent. A grant found expired with no refresh token is **deleted** on the way out: it can never mint another token, so it is a fact about the past rather than a credential, and leaving it would grow the store with rows an operator cannot tell from live but idle ones. A failed *refresh* throws and keeps the grant, because a provider rejecting a token it issued is an event an operator needs to see rather than an empty answer a job retries forever — and an outage is not proof the grant is dead. |
| `decodeIdTokenClaims` | `static Map<String, Object?> decodeIdTokenClaims(String idToken)` | The `id_token` payload, decoded only. The **signature is not verified** — see [Status and Limitations](../authentication.md#status-and-limitations) — and neither is `exp`: this is the decoder, not the verifier. `completeAuthorization` checks freshness after calling it; a caller reaching for this method directly gets neither check. |
| `randomHandle` | `static String randomHandle(int byteCount)` | `byteCount` cryptographically secure bytes, base64url without padding — the `state` handles, PKCE verifiers, nonces and SAML handoff codes the flows mint. |

### TomOAuthTokenGrant

One provider grant: the credential an application presents to call a provider's
API *as the user*. Immutable; both instants are normalised to UTC on
construction, because the value crosses a storage boundary and a local-time
instant read back on a server in another zone is silently wrong.

#### Constructors

```dart
TomOAuthTokenGrant({
  required String accessToken,
  String? refreshToken,
  String tokenType = 'Bearer',
  String scope = '',
  DateTime? expiresAt,
  DateTime? obtainedAt,
})

factory TomOAuthTokenGrant.fromTokenResponse(
  Map<String, Object?> response, {
  TomOAuthTokenGrant? previous,
  DateTime? now,
})
```

`fromTokenResponse` turns the provider's relative `expires_in` into an instant,
because the duration was only ever meaningful relative to a response that is long
gone by the time anything reads it back. `previous` is what keeps the long-lived
credential alive across a refresh: RFC 6749 §6 permits omitting `refresh_token`
from a refresh response, meaning *keep the one you have*, and a reader that took
the omission literally would work perfectly until the access token expired.

#### Fields

| Field | Type | Notes |
| ----- | ---- | ----- |
| `accessToken` | `String` | The bearer token to present to the provider's API. |
| `refreshToken` | `String?` | Mints a new access token, or `null`. Absent far more often than deployments expect — most providers return one only when explicitly asked. |
| `tokenType` | `String` | `Bearer` in every practical case. |
| `scope` | `String` | The *granted* scopes, which may be narrower than the requested ones. What an application must check before assuming a capability, not `TomOAuthProviderConfig.scopes`. |
| `expiresAt` | `DateTime?` | When the access token stops being accepted (UTC), or `null` when the provider declared no lifetime. |
| `obtainedAt` | `DateTime` | When the grant was obtained (UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hasRefreshToken` | `bool get hasRefreshToken` | Whether the grant can mint a fresh access token by itself. |
| `isExpired` | `bool isExpired([DateTime? now])` | Whether the access token has expired. A grant with no declared lifetime is never expired — the provider said nothing, and guessing would throw away a working token. |
| `expiresWithin` | `bool expiresWithin(Duration margin, [DateTime? now])` | The question a caller actually has: not "is it still valid?" but "will it still be valid when the request arrives?". |
| `toJson` | `Map<String, Object?> toJson()` | The JSON that goes into the encrypted column. |
| `fromJson` | `static TomOAuthTokenGrant? fromJson(Object? json)` | Reads it back, or `null` for anything malformed. Nullable rather than throwing: the input has been through storage and possibly a key rotation, and "unreadable" has one sane response — treat the user as having granted nothing. |
| `toString` | `String toString()` | Names the grant **without printing either token**. Both are credentials and this value reaches log lines. |

### TomOAuthTokenStore

Where a grant lives, keyed `(issuer, subject)` — the same key as the identity
link, because a grant belongs to the external identity that consented to it.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `Future<TomOAuthTokenGrant?> read(String issuer, String subject)` | The held grant, or `null`. |
| `store` | `Future<void> store(String issuer, String subject, TomOAuthTokenGrant grant)` | Records or replaces it. One row per identity — a second would make which credential an application presents depend on row order. |
| `delete` | `Future<void> delete(String issuer, String subject)` | Removes it. A no-op when nothing is held. |
| `resolve` | `static TomOAuthTokenStore? resolve()` | The installed bean, or `null`. There is deliberately **no default**: unregistered means nothing is ever stored, which is the state a deployment that only wanted "Sign in with …" must land in without configuring anything. |

### TomMemoryOAuthTokenStore

A map-backed store for tests and single-process bring-up. Not a production
default — a grant that vanishes on restart is a user sent through consent again.

- **Implements:** `TomOAuthTokenStore`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clear` | `void clear()` | Drops every grant, so one test's grants cannot reach the next. The affordance a suite calls between cases; the persistent store has no counterpart, because a test that wants an empty table truncates it. |

### TomExternalIdentityToken

One persisted grant. `@tomReflector`,
`@TomDbTable(table: 'tom_external_identity_token')`.

| Field | Column | Notes |
| ----- | ------ | ----- |
| `id` | `id` | Surrogate key, `-1` until persisted. |
| `issuer` | `issuer` | The provider's issuer identifier. |
| `subject` | `subject` | The provider's stable identifier for the user, within `issuer`. |
| `tokenData` | `token_data` | The **whole grant, encrypted** — `TomOAuthTokenGrant.toJson` through `TomJwtConfiguration.encrypt`. Neither token is ever written in the clear. |
| `tokenScope` | `token_scope` | The granted scopes, deliberately **not** encrypted. |
| `obtainedAt` | `obtained_at` | When the grant was obtained, deliberately **not** encrypted. |
| `expiresAt` | `expires_at` | When the access token expires, deliberately **not** encrypted. |

The three cleartext columns are the *operator projection*: "is this grant live,
and what does it cover?" must be answerable by a query, because an operator who
has to hold the private key to answer it defeats the point of encrypting the
rest. None of the three is authoritative — the values the code decides from live
inside `token_data` — so a projection that drifted could not cause a stale token
to be presented.

`createTableSql` makes `(issuer, subject)` unique, matching the key of
`tom_external_identity`. There is deliberately **no foreign key** to that table,
because a deployment may keep its identity links in a table of its own and still
let the framework hold the credentials; the retention bound is enforced in code
by `TomExternalIdentityStore.unlink` instead.

### TomExternalIdentityTokenRepository

`TomSqlDatasourceRepository<TomExternalIdentityToken, int>`.

### TomPersistentOAuthTokenStore

The production implementation, over a
`TomSqlDatasourceRepository<TomExternalIdentityToken, int>`.

```dart
const TomPersistentOAuthTokenStore(
  TomSqlDatasourceRepository<TomExternalIdentityToken, int> repository, {
  TomJwtConfiguration? cipher,
})
```

`cipher` is resolved per call, falling back to
`TomJwtConfiguration.defaultSignConfiguration` — the same at-rest primitive
behind a 2FA enrolment secret. Requires the `tom_external_identity_token` table;
the reference migration is
`example/authentication/migrations/main/tomcore/[3]-create_tom_external_identity_token.sql`.

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
lookup rather than a scan. The reference migration is
`example/authentication/migrations/main/tomcore/[4]-create_tom_external_identity.sql`.

### TomExternalIdentityLinkRepository

`TomSqlDatasourceRepository<TomExternalIdentityLink, int>`.

### TomExternalIdentityStore

The linking table.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `localUsernameFor` | `Future<String?> localUsernameFor(TomExternalIdentity identity)` | The linked account, or `null`. |
| `link` | `Future<void> link(TomExternalIdentity identity, String localUsername)` | Creates or updates the link. Relinking updates rather than duplicating. |
| `unlink` | `Future<void> unlink(String issuer, String subject)` | Removes the link **and every provider token held through it**, in that order. The cascade is part of the contract rather than the caller's responsibility: leaving the two deletions to whoever wrote the account-settings page fails in the one direction that matters — the user pressed *disconnect*, the page said *disconnected*, and the deployment still holds a live refresh token for their mailbox. Removing a link that is not there is a no-op. |
| `recordLogin` | `Future<void> recordLogin(TomExternalIdentity identity)` | Stamps `lastLoginAt`. |
| `identitiesOf` | `Future<List<TomExternalIdentityLink>> identitiesOf(String localUsername)` | Every identity linked to an account — the account-settings question. A **snapshot** in both senses: the list is unmodifiable and each link is detached, so editing one changes nothing a later call reports and two calls answer distinct instances. Write back through `link` or `recordLogin`. In the contract because the implementations would otherwise disagree — a database-backed store materialises fresh rows whether it means to or not, an in-memory one aliases its own state unless it copies, and a test written against the aliasing one passes for a reason production does not share. |
| `resolve` | `static TomExternalIdentityStore? resolve()` | The installed bean, or `null`. There is deliberately **no in-memory default**: a link that vanishes on restart sends a returning user through provisioning again. |

### TomPersistentExternalIdentityStore

The production implementation, over a
`TomSqlDatasourceRepository<TomExternalIdentityLink, int>`.

```dart
const TomPersistentExternalIdentityStore(
  TomSqlDatasourceRepository<TomExternalIdentityLink, int> repository, {
  TomOAuthTokenStore? tokenStore,
})
```

`tokenStore` is what `unlink` cascades into; left unset it follows the installed
`TomOAuthTokenStore` bean at *call* time, so a deployment that wires its token
store after its identity store still gets the cascade. Requires the
`tom_external_identity` table; the reference migration is
`example/authentication/migrations/main/tomcore/[4]-create_tom_external_identity.sql`.

### TomMemoryExternalIdentityStore

A map-backed store for tests. Not a production default — see
`TomExternalIdentityStore.resolve`. Takes the same optional `tokenStore`.

`identitiesOf` copies each link on the way out, because here the entities *are*
the store's state and handing them out would make every caller an unwitting
writer to it. The persistent store owes the same snapshot guarantee and pays
nothing for it, which is the whole reason the guarantee is written into the
interface rather than left to each implementation to happen to provide.

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
  TomOAuthTokenStore? tokenStore,
})
```

`delegate` is what keeps passwords working: a deployment installs *one*
authentication service, so any credential that is not a `TomOAuthCredential`
passes straight through. `null` makes external identity the only way in — a
legitimate choice, and not the default one.

`tokenStore` is where a retained grant goes, following the installed
`TomOAuthTokenStore` bean when unset. Retention happens only where the provider
declared `storeTokens: true`, and the service still issues no token and makes no
session decision — it writes the provider's grant and stops.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `authenticateUser` | `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)` | *(override)* Completes the handshake, replays the flow's login context over the message's, resolves or provisions the local account, records the login, and returns an ordinary `TomAuthenticationInfo`. |

The roles the provider's `TomExternalRoleMapping` grants are applied to the
principal on every login — linked, linked-on-first-sight or provisioned — before
the access-control definition completes its rights.

Login failure keys: `login.error.oauth.no-identity-store`,
`login.error.oauth.linked-account-missing`,
`login.error.oauth.no-local-account`, `login.error.oauth.unverified-email`,
`login.error.oauth.provisioning-unsupported`,
`login.error.oauth.credential-not-supported`.

`provisioning` and `storeTokens` are both read from
`TomOAuthExchange.provider` — the registration the flow began with — so one
login cannot provision under one provider's policy and retain under another's
when two registrations share an issuer.

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
| `listOAuthProviders` | `Future<List<TomOAuthProviderDto>> listOAuthProviders()` | `GET /oauth/providers`. Resource keys only, for the OAuth and the SAML providers alike. |
| `beginOAuthAuthorization` | `Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(TomOAuthAuthorizationRequest request)` | `POST /oauth/authorize`. |
| `completeOAuthAuthorization` | `Future<TomAuthenticationResult> completeOAuthAuthorization(TomOAuthCallbackRequest request)` | `POST /oauth/complete` — the *application's* call, forwarding the `code` and `state` the provider's redirect left on its own page. Refuses a provider-reported error (`oauth.callback.provider_error`) and an unknown state (`oauth.callback.unknown_state`), then delegates to `TomAuthenticationServer.authenticateExternal`. Returns a login result, not an OAuth result. Nothing here is browser-facing: an endpoint the provider redirected to would answer a browser navigation with a token pair. |

Keys raised: `oauth.callback.provider_error`, `oauth.callback.unknown_state`
(both `TomEndpointHandlerException`).

### TomExternalProvider

What every external identity provider has in common, whatever protocol it
speaks. `TomOAuthProviderConfig` (OAuth 2.0 / OpenID Connect) and
`TomSamlProviderConfig` (SAML 2.0) implement it, and everything downstream of
"the provider has said who this is" — linking, provisioning, the mapped roles,
the session — is written against it, so an enterprise identity provider behaves
the same over either protocol. `TomOAuthExchange.provider` is typed by it.

- **Kind:** `abstract interface class`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The configuration id; what a login request names. Unique across both protocols. |
| `issuer` | `String` | The identifier identities are asserted under — the OIDC `iss`, or the SAML identity provider's entity id. Links are keyed by it. |
| `provisioning` | `TomOAuthProvisioning` | What a successful login with no local account does. |
| `roleMapping` | `TomExternalRoleMapping` | How the provider's group claims become Tom roles. |
| `clockSkew` | `Duration` | The tolerance applied to the provider's validity instants. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toDto` | `TomOAuthProviderDto toDto()` | The provider as the client-facing descriptor. |

### TomExternalRoleMapping

How an identity provider's group claims become Tom roles. Immutable, configured
per provider with `groupsClaim`, `roleMapping` and `defaultRoles`. The mapped
roles are recomputed from the claims on **every** login and applied to that
session's principal beside the account's own roles; the framework writes them to
no user store. Groups the mapping does not name grant nothing.

#### Constructors

```dart
const TomExternalRoleMapping({
  String groupsClaim = defaultGroupsClaim,
  Map<String, List<String>> roles = const {},
  List<String> defaultRoles = const [],
})

factory TomExternalRoleMapping.fromMap(String providerId, Map<Object?, Object?> map)
```

`fromMap` reads `groupsClaim`, `roleMapping` (a map of external group to a role
list, or to a single role) and `defaultRoles` from a provider's configuration
map. A `roleMapping` that is not a map, or a role list that is neither a list
nor a string, throws `oauth.config.invalid_role_mapping`: a mistyped security
setting stops the start rather than granting nothing quietly.

#### Static Properties

| Property | Value | Description |
| -------- | ----- | ----------- |
| `defaultGroupsClaim` | `'groups'` | The claim read when a provider names none. |
| `none` | `TomExternalRoleMapping()` | A mapping that grants nothing — the default of both provider types. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `groupsClaim` | `String` | The claim (OIDC) or attribute (SAML) carrying the user's groups. A dotted path reaches into a nested claim — Keycloak puts realm roles at `realm_access.roles` — and a claim whose own name contains a dot is found before the path is split. |
| `roles` | `Map<String, List<String>>` | External group → the Tom roles it grants. |
| `defaultRoles` | `List<String>` | The roles every login from this provider receives. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `groupsIn` | `List<String> groupsIn(Map<String, Object?> claims)` | The groups `claims` assert at `groupsClaim`: a list, a single string (one group, never split on commas), or absent. |
| `rolesFor` | `List<String> rolesFor(Map<String, Object?> claims)` | The `defaultRoles`, then the roles of every mapped group, without duplicates and in that order. |
| `claimAt` | `static Object? claimAt(Map<String, Object?> claims, String path)` | The claim named exactly `path` when there is one, otherwise the dotted path followed through nested maps. |
| `toString` | `String toString()` | Names the claim, the number of mapped groups and the default roles. |

### TomSamlException

A SAML message, configuration value or signature that cannot be used.
`clientThrow` defaults to `false`: what failed in a SAML response is the
operator's business, and telling a sender which check its forgery tripped helps
nobody but the sender. The client-facing keys (`saml.acs.unknown_state`,
`saml.flow.not_asserted`, `saml.flow.handoff_mismatch`,
`saml.config.unknown_provider`) pass `clientThrow: true`.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomSamlException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  bool clientThrow = false,
})
```

| Key | Raised when |
| --- | ----------- |
| `saml.config.not_a_map` · `saml.config.provider_not_a_map` | `saml.providers`, or one provider under it, is not a map. |
| `saml.config.missing_value` | A required setting (`issuer`, `ssoUrl`, `spEntityId`, `acsUrl`, `redirectUri`) is absent and no metadata supplies it. |
| `saml.config.metadata_not_loaded` | A provider relies on `metadataUrl` for a value and was read by the synchronous `fromConfiguration`. |
| `saml.config.metadata_failed` | The metadata document could not be fetched. |
| `saml.config.malformed_metadata` | The metadata is not an identity-provider `EntityDescriptor`, or declares a document type. |
| `saml.config.metadata_issuer_mismatch` | The metadata describes another entity than the configured `issuer`. |
| `saml.config.no_idp_certificate` | No identity-provider signing certificate is configured or published. |
| `saml.config.unreadable_certificate` · `saml.config.unreadable_key` · `saml.config.unreadable_file` | A certificate, the request signing key, or a named file cannot be read. |
| `saml.config.unknown_provider` | A lookup for an id no SAML provider is configured under. |
| `saml.acs.unknown_state` | A response's `RelayState` names no pending SAML login. |
| `saml.flow.not_asserted` · `saml.flow.handoff_mismatch` | A completion arrived before the identity provider's response, or with another code than the one issued. |
| `saml.response.*` · `saml.assertion.*` | A response the validator refuses — see `TomSamlResponseValidator`. |
| `saml.signature.*` · `saml.xml.unbound_prefix` | A signature the verifier refuses — see `TomXmlSignatureVerifier`. |

### TomXmlDsig

Namespace and algorithm identifiers of XML Signature. `abstract final`, constants
only.

#### Static Properties

| Property | Value |
| -------- | ----- |
| `namespace` | `http://www.w3.org/2000/09/xmldsig#` |
| `exclusiveC14n` | `http://www.w3.org/2001/10/xml-exc-c14n#` |
| `envelopedSignature` | `http://www.w3.org/2000/09/xmldsig#enveloped-signature` |
| `rsaSha256` | `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256` |
| `rsaSha512` | `http://www.w3.org/2001/04/xmldsig-more#rsa-sha512` |
| `sha256` | `http://www.w3.org/2001/04/xmlenc#sha256` |
| `sha512` | `http://www.w3.org/2001/04/xmlenc#sha512` |
| `xmlNamespace` | `http://www.w3.org/XML/1998/namespace` |
| `xmlnsNamespace` | `http://www.w3.org/2000/xmlns/` |

### TomExclusiveCanonicalizer

Exclusive XML Canonicalization 1.0, without comments — the serialisation a
signature is computed over. Namespace declarations are rendered only where an
element or attribute uses them, attributes in canonical order, empty elements as
start and end tag, text and attribute values escaped one fixed way. `abstract
final`, statics only.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `canonicalize` | `static String canonicalize(XmlElement apex, {Set<String> inclusivePrefixes = const {}, XmlNode? omit})` | The canonical form of `apex` and its subtree, leaving out `omit` (the enveloped signature). `inclusivePrefixes` is the `InclusiveNamespaces` prefix list; `#default` names the default namespace. Throws `saml.xml.unbound_prefix` for a prefix used and never declared. |

### TomXmlSignatureVerifier

Verifies the enveloped XML signature on a SAML element against a fixed set of
trusted RSA keys — exactly the profile identity providers use: exclusive
canonicalization, RSA PKCS#1 v1.5 with SHA-256 or SHA-512, one reference to the
signed element's `ID`, the enveloped-signature transform, a SHA-256 or SHA-512
digest. SHA-1 is refused. The signature's own `KeyInfo` is ignored: it verifies
against the configured certificates only.

#### Constructors

```dart
const TomXmlSignatureVerifier(List<pc.RSAPublicKey> keys)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keys` | `List<pc.RSAPublicKey>` | The keys a signature may verify against — several, so a key rotation at the identity provider verifies throughout. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `signatureOf` | `static XmlElement? signatureOf(XmlElement signed)` | The enveloped signature among `signed`'s children, or `null`. Throws `saml.signature.ambiguous` for several. |
| `verify` | `void verify(XmlElement signed, XmlDocument document)` | Verifies the signature that is a direct child of `signed` and covers it, in `document`. The reference must name `signed`'s `ID`, which must be unique in the document — the defence against signature wrapping. |
| `signRsa` | `static Uint8List signRsa(String algorithm, pc.RSAPrivateKey key, List<int> data)` | The signing half, for a service provider that signs its `AuthnRequest`. |

| Key | Raised when |
| --- | ----------- |
| `saml.signature.missing` | The element carries no signature. |
| `saml.signature.ambiguous` | The element carries more than one. |
| `saml.signature.malformed` | A `SignedInfo` part is missing or repeated, or a value is not base64. |
| `saml.signature.unsupported_algorithm` | A canonicalization, transform, signature or digest algorithm outside the profile — SHA-1 included — or no enveloped-signature transform. |
| `saml.signature.wrong_reference` | The signature does not reference exactly the signed element, by an `ID` unique in the document. |
| `saml.signature.digest_mismatch` | The signed element was changed after signing. |
| `saml.signature.invalid` | The signature verifies against none of the configured keys. |

### TomSamlNames

SAML 2.0 namespace and binding identifiers. `abstract final`, constants only.

#### Static Properties

| Property | Value |
| -------- | ----- |
| `assertion` | `urn:oasis:names:tc:SAML:2.0:assertion` |
| `protocol` | `urn:oasis:names:tc:SAML:2.0:protocol` |
| `metadata` | `urn:oasis:names:tc:SAML:2.0:metadata` |
| `redirectBinding` | `urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect` |
| `postBinding` | `urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST` |
| `success` | `urn:oasis:names:tc:SAML:2.0:status:Success` |
| `bearer` | `urn:oasis:names:tc:SAML:2.0:cm:bearer` |

### TomSamlProviderConfig

One configured SAML 2.0 identity provider and this server's side of the trust.
Immutable.

- **Implements:** `TomExternalProvider`

#### Constructors

```dart
const TomSamlProviderConfig({
  required String id,
  required String issuer,
  required String ssoUrl,
  required List<pc.RSAPublicKey> idpSigningKeys,
  required String spEntityId,
  required String acsUrl,
  required String redirectUri,
  String? nameIdFormat,
  String? subjectAttribute,
  String? usernameAttribute,
  String? displayNameAttribute,
  bool requireSignedAssertion = false,
  pc.RSAPrivateKey? spSigningKey,
  String? spCertificate,
  TomOAuthProvisioning provisioning = TomOAuthProvisioning.autoProvision,
  TomExternalRoleMapping roleMapping = TomExternalRoleMapping.none,
  Duration clockSkew = TomOAuthProviderConfig.defaultClockSkew,
  String displayNameKey = '',
  String iconKey = '',
})

factory TomSamlProviderConfig.fromMap(
  String id,
  Map<Object?, Object?> map, {
  TomSamlIdpMetadata? metadata,
})
```

`fromMap` takes the identity provider's side from `metadata` where the map does
not configure it; an explicit value wins. Configuration keys: `issuer`, `ssoUrl`,
`idpCertificates` (PEM or bare base64, one or a list), `idpCertificateFiles`,
`metadataUrl`, `spEntityId`, `acsUrl`, `redirectUri`, `nameIdFormat`,
`subjectAttribute`, `usernameAttribute`, `displayNameAttribute`,
`requireSignedAssertion`, `spSigningKeyFile`, `spCertificateFile`,
`provisioning`, `groupsClaim` / `defaultRoles` / `roleMapping`,
`clockSkewSeconds`, `displayNameKey`, `iconKey`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The provider key under `saml.providers`, and what a login names. |
| `issuer` | `String` | The identity provider's entity id. Every response and assertion must be issued by it; identity links are keyed by it. |
| `ssoUrl` | `String` | The identity provider's HTTP-Redirect single sign-on service. |
| `idpSigningKeys` | `List<pc.RSAPublicKey>` | Every key the identity provider signs with. |
| `spEntityId` | `String` | This server's entity id: the audience every assertion must name. |
| `acsUrl` | `String` | This server's assertion consumer service — the `Destination` and `Recipient` every response must name. |
| `redirectUri` | `String` | The application page the browser is sent to with the handoff code. |
| `nameIdFormat` | `String?` | The `NameIDPolicy` format requested, or `null` to leave it to the identity provider. A transient format changes on every login and cannot be linked. |
| `subjectAttribute` | `String?` | The attribute holding the stable subject, or `null` for the `NameID`. |
| `usernameAttribute` | `String?` | The attribute a local username is derived from, or `null` for the subject. |
| `displayNameAttribute` | `String?` | The attribute carrying a display name, or `null`. |
| `requireSignedAssertion` | `bool` | Whether the assertion itself must be signed. Off: a signed response covers the assertion inside it. |
| `spSigningKey` | `pc.RSAPrivateKey?` | The key `AuthnRequest`s are signed with, or `null` to send them unsigned. |
| `spCertificate` | `String?` | This server's signing certificate, base64 DER, published in its metadata; or `null`. |
| `provisioning` | `TomOAuthProvisioning` | `autoProvision` unless configured. |
| `roleMapping` | `TomExternalRoleMapping` | How the group attribute becomes Tom roles. |
| `clockSkew` | `Duration` | The tolerance on the assertion's validity windows. |
| `displayNameKey` | `String` | Resource key of the provider's label; `oauth.<id>.name` from configuration. |
| `iconKey` | `String` | Resource key of the provider's icon; `oauth.<id>.icon` from configuration. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toDto` | `TomOAuthProviderDto toDto()` | The client-facing descriptor, the same shape an OAuth provider answers. |
| `toString` | `String toString()` | `TomSamlProviderConfig(id -> issuer)`. |

### TomSamlCertificates

Reading the certificates and keys a SAML configuration names. `abstract final`,
statics only.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `publicKeyOf` | `static pc.RSAPublicKey publicKeyOf(String providerId, String certificate)` | The RSA public key of an X.509 certificate given as PEM or bare base64 DER. Throws `saml.config.unreadable_certificate`. |
| `privateKeyOf` | `static pc.RSAPrivateKey privateKeyOf(String providerId, String pem)` | The RSA private key in a PEM (PKCS#8 or PKCS#1). Throws `saml.config.unreadable_key`. |
| `base64Of` | `static String base64Of(String certificate)` | The base64 DER body, without PEM armour or whitespace. |

### TomSamlIdpMetadata

What an identity provider's metadata document says about it.

#### Constructors

```dart
const TomSamlIdpMetadata({
  required String entityId,
  required String? ssoRedirectUrl,
  required List<String> signingCertificates,
})

factory TomSamlIdpMetadata.parse(String providerId, String xml)
```

`parse` reads an `EntityDescriptor` with an `IDPSSODescriptor` (or the first such
one in an `EntitiesDescriptor`) and throws `saml.config.malformed_metadata` for
anything else, including a document that declares a document type.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entityId` | `String` | The identity provider's entity id. |
| `ssoRedirectUrl` | `String?` | Its HTTP-Redirect single sign-on service, or `null` when it offers none. |
| `signingCertificates` | `List<String>` | Its signing certificates, base64 DER. |

### TomSamlProviders

The configured SAML identity providers, read from `saml.providers`. Installed as
a bean at start-up, after `load` has fetched the metadata.

- **Constant:** `configurationKey = 'saml.providers'`

#### Constructors

```dart
TomSamlProviders(Map<String, TomSamlProviderConfig> providers)
factory TomSamlProviders.fromConfiguration([TomServerConfigResourceProvider? config])
```

`fromConfiguration` fetches nothing, so a provider that relies on `metadataUrl`
for a value it does not configure is refused with
`saml.config.metadata_not_loaded`. An absent key is an empty set.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providers` | `Map<String, TomSamlProviderConfig>` | The providers, keyed by id. |
| `isEmpty` *(getter)* | `bool` | Whether no provider is configured. |
| `descriptors` *(getter)* | `List<TomOAuthProviderDto>` | The providers as client-facing descriptors, in configuration order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static TomSamlProviders? resolve()` | The installed bean, or `null`. |
| `load` | `static Future<TomSamlProviders> load({TomServerConfigResourceProvider? config, TomOAuthTokenTransport? transport})` | The start-up call: reads `saml.providers`, fetching every provider's `metadataUrl`. |
| `discover` | `static Future<TomSamlProviders> discover(Object? raw, {TomOAuthTokenTransport? transport})` | The provider set `raw` configures, each `metadataUrl` fetched and parsed. A document that cannot be fetched fails with `saml.config.metadata_failed`. The metadata is trusted because of where it came from, so name an `https` address. |
| `lookup` | `TomSamlProviderConfig? lookup(String id)` | The provider under `id`, or `null`. |
| `operator []` | `TomSamlProviderConfig operator [](String id)` | The provider under `id`; throws `saml.config.unknown_provider`. |
| `toString` | `String toString()` | Names the configured ids. |

### TomSamlFlow

SAML 2.0 Web Browser SSO, service-provider initiated: the `AuthnRequest` out over
the HTTP-Redirect binding, the `Response` back over HTTP-POST, and a third leg
that hands the verified identity to the application's own call. It shares the
pending-authorization store with the OAuth flow, and `TomOAuthFlow` dispatches to
it by provider id.

#### Constructors

```dart
TomSamlFlow({
  required TomSamlProviders providers,
  required TomOAuthStateStore stateStore,
  DateTime Function()? clock,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providers` | `TomSamlProviders` | The configured identity providers. |
| `stateStore` | `TomOAuthStateStore` | Where pending authorizations are kept. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `beginAuthorization` | `Future<TomOAuthAuthorizationDto> beginAuthorization(TomOAuthAuthorizationRequest request)` | Stores a pending record whose `nonce` is the `AuthnRequest`'s `ID`, and answers the identity provider's address carrying the deflated request, the `RelayState` and, with a signing key, the redirect-binding signature. |
| `acceptResponse` | `Future<String> acceptResponse({required String samlResponse, required String relayState})` | The assertion consumer service: spends the pending record, verifies the response, stores the verified identity under the same handle with the digest of a one-time code, and answers the application's `redirectUri` with `code` and `state`. A refused response answers the same page with `error=access_denied`, `error_description=<key>` and `state`, and is logged. Throws `saml.acs.unknown_state` when `relayState` names no pending SAML flow. |
| `completeAuthorization` | `Future<TomOAuthExchange> completeAuthorization(TomOAuthAuthorizationState pending, String code)` | Hands the verified identity to the login. Throws `saml.flow.not_asserted` and `saml.flow.handoff_mismatch`. |
| `metadataFor` | `String metadataFor(String providerId)` | This server's service-provider metadata: entity id, signing certificate, `NameIDFormat` and the HTTP-POST assertion consumer service. |
| `authnRequestXml` | `static String authnRequestXml(TomSamlProviderConfig provider, String requestId, DateTime instant)` | The `AuthnRequest`. |
| `redirectUrlFor` | `static String redirectUrlFor(TomSamlProviderConfig provider, String requestXml, String relayState)` | The single sign-on address carrying the request over the HTTP-Redirect binding, signed over the query string exactly as sent when the provider has a signing key. |

### TomSamlResponseValidator

Verifies a SAML `Response` for one provider and answers the identity it asserts.
The assertion read is always the one verified — a child of the verified response,
or itself verified — never one found by searching the document.

#### Constructors

```dart
const TomSamlResponseValidator(TomSamlProviderConfig provider)
```

#### Static Properties

| Property | Value | Description |
| -------- | ----- | ----------- |
| `maxResponseBytes` | `1024 * 1024` | The largest response accepted, decoded. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `provider` | `TomSamlProviderConfig` | The provider the response must come from. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `validate` | `TomExternalIdentity validate(String samlResponse, {required String requestId, required DateTime now})` | Verifies the base64 `SAMLResponse` against the request this flow sent, answering the identity with its claims, groups and mapped roles. An attribute sent as several `Attribute` elements contributes every value. |

| Key | Refused because |
| --- | --------------- |
| `saml.response.malformed` | Not base64, not XML, too large, or not a `samlp:Response`. |
| `saml.response.doctype` | The document declares a document type. |
| `saml.response.wrong_destination` | `Destination` is not this server's assertion consumer service. |
| `saml.response.wrong_request` | `InResponseTo` does not name the request this flow sent. |
| `saml.response.wrong_issuer` | The response or assertion was issued by another entity. |
| `saml.response.status_not_success` | The identity provider reports a failure. |
| `saml.response.encrypted_unsupported` | The assertion is encrypted. |
| `saml.response.assertion_count` | Not exactly one assertion. |
| `saml.signature.*` | The signature is missing or does not verify. |
| `saml.assertion.unsigned` | The provider requires a signed assertion and only the response is signed. |
| `saml.assertion.missing_subject` | No subject to link the identity to. |
| `saml.assertion.no_bearer_confirmation` | No bearer confirmation for this recipient, this request and the present moment. |
| `saml.assertion.not_yet_valid` · `saml.assertion.expired` | Outside the assertion's `Conditions`, beyond the clock skew. |
| `saml.assertion.wrong_audience` | The assertion is not addressed to this service provider. |

### TomSamlService

The two SAML endpoints that cannot be the application's call. `@tomReflector
@tomService`; both `@TomPublicAccess` — the signed response *is* the credential,
and metadata is published by design.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `assertionConsumer` | `Future<Object> assertionConsumer(TomMultipartForm form)` | `POST /saml/acs`, form-urlencoded: accepts `SAMLResponse` and `RelayState` and answers `303` to the application's page. `400` when the post names no pending SAML login. |
| `metadata` | `Future<Response> metadata(String providerId)` | `GET /saml/metadata/<providerId>`, `logRequests: false`: this server's metadata as `application/samlmetadata+xml`; `404` for an unknown id. |

### TomSamlServer

The default `TomSamlService` (`@tomReflector @tomComponent`), answering from
`TomOAuthFlow.fromBeans().saml`.

- **Implements:** `TomSamlService`

#### Constructors

```dart
const TomSamlServer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `assertionConsumer` | `Future<Object> assertionConsumer(TomMultipartForm form)` | *(override)* |
| `metadata` | `Future<Response> metadata(String providerId)` | *(override)* |

### TomJwtKeyException

A key or signing setting that cannot be used. Every case names this
deployment's configuration, so it is constructed with `clientThrow: false`.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomJwtKeyException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
})
```

| Key | Raised when |
| --- | ----------- |
| `jwt.keys.unknown_algorithm` | `jwtAlgorithm` names no supported algorithm. `parameters`: `algorithm`. |
| `jwt.keys.unreadable_key_file` | A configured key file cannot be read or holds no key of the configured algorithm's kind. `parameters`: `source`, `algorithm`. |
| `jwt.keys.verify_only` | A token was to be issued by a server configured with verification keys only. |

### TomJwtAlgorithm

The token signing algorithms a deployment may configure.

| Value | Meaning |
| ----- | ------- |
| `rs256` | RSA PKCS#1 v1.5 with SHA-256 — the default, verified by every JWT library and gateway. |
| `es256` | ECDSA over P-256 with SHA-256 — smaller keys and signatures. |
| `hs256` | HMAC with SHA-256 — one shared secret signs and verifies; for a single service, and never published. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `jwtName` | `String` | The name in a token's `alg` header: `RS256`, `ES256`, `HS256`. |
| `isAsymmetric` | `bool` | Whether signing and verifying use different keys. |
| `algorithm` | `jwt.JWTAlgorithm` | The `dart_jsonwebtoken` algorithm. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomJwtAlgorithm parse(String name)` | The algorithm named `name` (`RS256`, `ES256`, `HS256`; any case). Throws `jwt.keys.unknown_algorithm` for any other name. |

### TomJwtKey

One key a token can be verified with, under its id.

#### Constructors

```dart
factory TomJwtKey.publicPem(String pem, TomJwtAlgorithm algorithm, {String source = 'PEM'})
factory TomJwtKey.hmac(jwt.SecretKey secret)
```

`publicPem` reads an SPKI public key of the algorithm's kind and throws
`jwt.keys.unreadable_key_file`, naming `source`, when `pem` holds none. `hmac`
wraps an HS256 secret, which has no id.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keyId` | `String?` | The `kid` a token signed with the key carries. For an asymmetric key, the RFC 7638 thumbprint of its public JWK, so every server derives the same id from the same key without being told it. `null` for an HMAC secret. |
| `algorithm` | `TomJwtAlgorithm` | The algorithm the key verifies. |
| `verificationKey` | `jwt.JWTKey` | The key `dart_jsonwebtoken` verifies with: the public key, or the secret. |
| `jwk` | `Map<String, Object?>?` | The public JWK as the JSON Web Key Set publishes it — the required members plus `kid`, `use: sig` and `alg`; `null` for an HMAC secret. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `thumbprint` | `static String thumbprint(Map<String, Object?> requiredMembers)` | The RFC 7638 thumbprint: the base64url SHA-256 of the members in lexicographic order, without whitespace or padding. |

### TomJwtSigningKey

A signing key and the public key it publishes.

#### Constructors

```dart
factory TomJwtSigningKey.privatePem(String pem, TomJwtAlgorithm algorithm, {String source = 'PEM'})
factory TomJwtSigningKey.rsa(jwt.RSAPrivateKey private)
```

`privatePem` reads a PKCS#8 private key — RSA for RS256, EC on the named curve
P-256 for ES256 — derives its public half, and throws
`jwt.keys.unreadable_key_file`, naming `source`, when `pem` holds no key of the
algorithm's kind. `rsa` wraps an RSA private key already parsed.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `signingKey` | `jwt.JWTKey` | The key tokens are signed with. |
| `publicKey` | `TomJwtKey` | The public half, as it verifies and is published. |
| `keyId` | `String` | The id signed tokens carry — `publicKey.keyId`. |

### TomJwtSigning

How this process signs and verifies tokens: the algorithm, the key tokens are
signed with, every key a token may be verified with, and the issuer and
audience tokens carry. Installed by `installJwtSigning`; until then `current`
describes the process-wide `TomJwtConfiguration` default — HS256 with its
secret, issuer `tom`.

#### Constructors

```dart
TomJwtSigning({
  required TomJwtAlgorithm algorithm,
  required List<TomJwtKey> keys,
  String? signingKeyId,
  bool canSign = true,
  String issuer = defaultIssuer,
  String? audience,
})
```

#### Static Members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `defaultIssuer` | `static const String defaultIssuer = 'tom'` | The issuer a deployment that configures none writes and expects. |
| `current` | `static TomJwtSigning get current` | The installed description, or the one implied by the `TomJwtConfiguration` default. |
| `install` | `static void install(TomJwtSigning signing)` | Installs `signing` as `current`. |
| `reset` | `static void reset()` | Forgets the installed description. Test support. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `algorithm` | `TomJwtAlgorithm` | The algorithm every token is signed with and every token must name. |
| `keys` | `List<TomJwtKey>` | Every key a token may be verified with: the signing key's public half first, then the retired keys still verifying. |
| `signingKeyId` | `String?` | The `kid` tokens are signed under; `null` for HS256 and on a verify-only server. |
| `canSign` | `bool` | Whether this process can issue tokens, or only verify them. |
| `issuer` | `String` | The `iss` every token carries and must carry. |
| `audience` | `String?` | The `aud` every token carries and must carry, or `null` for none. |
| `jwks` | `Map<String, Object?>?` | The JSON Web Key Set publishing every verification key; `null` for HS256, whose secret is never published. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `keyFor` | `TomJwtKey? keyFor(String? keyId)` | The key a token with header `kid` `keyId` verifies against, or `null`. HS256 has one key and no ids, so its key answers for any token. |
| `requireSigning` | `void requireSigning()` | Throws `jwt.keys.verify_only` unless this process can issue tokens. `TomAuthenticationServer` calls it before minting. |

### TomJwksService

The `GET /.well-known/jwks.json` endpoint (RFC 7517, at the path OpenID Connect
discovery points to). `@tomReflector @tomService`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `jwks` | `Future<Response> jwks()` | `@TomPublicAccess`, `GET /.well-known/jwks.json`, `logRequests: false`. The JSON Web Key Set as `application/jwk-set+json`, cacheable for five minutes; `404` under HS256. Public by design: the set holds public keys only. |

### TomJwksServer

The default `TomJwksService` (`@tomReflector @tomComponent`), mounted by the
endpoints pipeline like every component endpoint. Answers from
`TomJwtSigning.current`.

- **Implements:** `TomJwksService`

#### Static Members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `cacheFor` | `static const Duration cacheFor = Duration(minutes: 5)` | How long a verifier may cache the set, sent as `cache-control: public, max-age=300`. Short enough that a key added for a rotation is seen well before the old key stops verifying. |
| `responseFor` | `static Response responseFor(TomJwtSigning signing)` | The response publishing `signing`'s keys: `200` with the set, or `404` naming the algorithm when it publishes none. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `jwks` | `Future<Response> jwks()` | *(override)* `responseFor(TomJwtSigning.current)`. |

## Global Functions and Constants

| Name | Type | Description |
| ---- | ---- | ----------- |
| `defaultOAuthStateTable` | `String` | `'tom_oauth_state'` — the pending-authorization table's default name |
| `oauthStateTable(String table)` | `TomFrameworkTable` | The table's single column declaration; everything else — the DDL, the `SELECT` column lists, the `INSERT` — is derived from it |
| `oauthStateTableDdl(String table)` | `String` | That declaration rendered as `CREATE TABLE IF NOT EXISTS`, for a start-up sequence that provisions without the store |
| `applyExternalRoles(TomPrincipal principal, List<String> roles)` | `void` | Adds `roles` to `principal`'s access-control information for this session, keeping its own roles and adding none twice. Applied before the access-control definition completes the principal's rights, so a mapped role brings everything the definition derives from it. Lives in `authentication/external_provider.dart`. |
| `installJwtSigning(TomBaseServerConfiguration configuration)` | `TomJwtConfiguration` | Builds this process's token signing from the configuration and installs it — as `TomJwtSigning.current` and as `TomJwtConfiguration.defaultSignConfiguration` — returning the latter. Reads `jwtAlgorithm` (RS256 when unset), the signing key (`jwtSigningKeyFile` for RS256/ES256, `jwtSharedSecretKey` for HS256), the retired keys in `jwtVerificationKeyFiles`, `jwtIssuer` (`tom` when unset), `jwtAudience` (none when unset), and the payload-encryption pair `jwtRsaPrivKey` / `jwtRsaPubKey`. Verification key files without a signing key make a verify-only server. Key material left unset falls back to the bundled sample keys — the RSA pair for RS256, the passphrase for HS256 — with a warning under a development or test environment, and is refused with `TomSigningKeyException` anywhere else, including a boot that never declared an environment. ES256 has no sample key and is refused unconfigured in every environment. A boot calls it once, after the runtime environment is selected and before anything mints or verifies a token. |
| `readPemFile(String path, TomJwtAlgorithm algorithm)` | `String` | Reads the PEM at `path`; a file that cannot be read raises `jwt.keys.unreadable_key_file` naming it. |
| `tom2FATokenFingerprint(String tokenString)` | `String` | The SHA-256 of an encoded interim token, which is what a `Tom2FAAttemptStore` keys on. The digest and not the token: a store is a thing a deployment points at shared infrastructure, and an attempt log holding usable bearer credentials would be a worse hazard than the one it closes. Two byte-identical tokens have one fingerprint, which is the right reading — they are the same token, and the second presentation is the replay this refuses. |
| `verifyBearerToken(String token, {bool decrypt = true})` | `TomClientJwtToken?` | Verifies `token` against `TomJwtSigning.current` and returns it decoded, or `null` when it is not a token this deployment issued. The `alg` header must be the configured algorithm — never taken from the token, so an RS256 public key cannot be presented as an HMAC secret; the `kid` must name a key this deployment holds (the signing key or a retired key still verifying; HS256 has one key and no ids); the signature must verify against that key; `iss` must be the configured issuer, and `aud` the configured audience when one is configured. Called from `extractAuthentication`, the single inbound path a client-supplied token enters by; unconditional, with no opt-out. Never throws — every rejection is `null` plus a warning naming the reason and never the token, so a forged token buys anonymous access rather than a distinguishable error. The validity window is deliberately **not** checked (`checkExpiresIn: false` / `checkNotBefore: false`): an expired token must still reach the request zone for a refresh endpoint to use, and expiry is answered by `tomDefaultAuthenticationMiddleware`, which drops the principal and keeps the credentials. |

`installJwtSigning` and `verifyBearerToken` live in
`authentication/jwt_signing.dart`, with `TomSigningKeyException` beside them —
signing and verifying the same tokens with the same installed key, which is why
they share a file. The keys themselves, `readPemFile` and `TomJwtKeyException`
are `authentication/jwt_keys.dart`'s; the endpoint publishing them is
`authentication/jwks_endpoint.dart`'s.

The first three live in `oauth_state_sql.dart` rather than beside the store so
`db_migration/framework_convergence.dart` can name the table without importing
the store — the same split the scheduling module uses.

The one top-level type alias, `TomTotpSecretResolver`, is documented above with
the adaptor that reads it. The OAuth contract's ids (`tomOAuthApiId` and the
three endpoint ids) and `registerTomOAuthApi()` live in `tom_core_kernel`'s
security module, with the rest of the wire contract.
