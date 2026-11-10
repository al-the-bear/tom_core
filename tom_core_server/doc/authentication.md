# Authentication Module

Server-side login orchestration. The module turns an incoming authentication
request into JWT tokens by delegating credential checking to an
application-supplied `TomAuthenticationService`, then encoding the resulting
principal into an authentication token and an authorization token. External
identity — "Sign in with …" over OAuth 2.0 / OpenID Connect, and enterprise
single sign-on over OpenID Connect or SAML 2.0 — is one more implementation of
that service contract. User provisioning over SCIM 2.0 lets the identity
provider keep the accounts themselves: it creates, updates and deactivates
users and groups, and a deactivation revokes the sessions the user holds.
Service accounts authenticate with API keys — a non-human caller with roles of
its own, presenting `X-API-Key` instead of a bearer token, and held to the same
access rules as a user.

## Table of Contents

- [Overview](#overview)
- [The Login Flow](#the-login-flow)
  - [Tenancy and the token](#tenancy-and-the-token)
  - [The sign-in organization](#the-sign-in-organization)
- [Implementing a Service](#implementing-a-service)
  - [Your service is the source of what the principal asserts](#your-service-is-the-source-of-what-the-principal-asserts)
- [Wiring the Server](#wiring-the-server)
  - [The signing keys](#the-signing-keys)
  - [Key ids](#key-ids)
  - [The JSON Web Key Set](#the-json-web-key-set)
  - [Rotating the signing key](#rotating-the-signing-key)
  - [Verify-only servers](#verify-only-servers)
  - [Verifying an inbound token](#verifying-an-inbound-token)
  - [What a verifier refuses](#what-a-verifier-refuses)
  - [Third-party verification](#third-party-verification)
  - [Signing failure keys](#signing-failure-keys)
- [Two-Factor Authentication](#two-factor-authentication)
  - [The whole path, across both packages](#the-whole-path-across-both-packages)
  - [The interim token is not a session](#the-interim-token-is-not-a-session)
  - [The policy decides](#the-policy-decides)
  - [Enrolment](#enrolment)
  - [Wiring a second factor](#wiring-a-second-factor)
  - [Mechanisms that need something installed](#mechanisms-that-need-something-installed)
  - [Codes delivered by email or SMS](#codes-delivered-by-email-or-sms)
  - [Passkeys (WebAuthn)](#passkeys-webauthn)
  - [How a mechanism names itself](#how-a-mechanism-names-itself)
  - [Writing your own mechanism](#writing-your-own-mechanism)
  - [Outcomes](#outcomes)
  - [The attempt counter, and what makes it a bound](#the-attempt-counter-and-what-makes-it-a-bound)
- [Server Self-Login](#server-self-login)
  - [Why a server logs in](#why-a-server-logs-in)
  - [The credential](#the-credential)
  - [Lifecycle](#lifecycle)
  - [The principal is renewed, not installed once](#the-principal-is-renewed-not-installed-once)
  - [Failure keys](#failure-keys)
  - [Swapping the transport](#swapping-the-transport)
- [External Identity (OAuth 2.0 / OIDC)](#external-identity-oauth-20--oidc)
  - [The shape](#the-shape)
  - [Wiring it up](#wiring-it-up)
  - [Provider configuration is data](#provider-configuration-is-data)
  - [Two registrations against one IdP](#two-registrations-against-one-idp)
  - [First login with no local account: `refuse`, `linkExisting` or `autoProvision`](#first-login-with-no-local-account-refuse-linkexisting-or-autoprovision)
  - [The linking table](#the-linking-table)
  - [The handshake](#the-handshake)
  - [Delegated access: the provider's tokens](#delegated-access-the-providers-tokens)
  - [Where pending authorizations live](#where-pending-authorizations-live)
  - [The endpoints](#the-endpoints)
  - [The completion is your call, not the provider's redirect](#the-completion-is-your-call-not-the-providers-redirect)
  - [Failure keys](#failure-keys-1)
- [Single sign-on with enterprise identity providers](#single-sign-on-with-enterprise-identity-providers)
  - [Wiring it up at start-up](#wiring-it-up-at-start-up)
  - [OpenID Connect: Entra ID, Okta, Keycloak](#openid-connect-entra-id-okta-keycloak)
  - [SAML 2.0 identity providers](#saml-20-identity-providers)
  - [What to register at the identity provider](#what-to-register-at-the-identity-provider)
  - [Claim mapping: groups to roles](#claim-mapping-groups-to-roles)
  - [Claim mapping: tenant and organization](#claim-mapping-tenant-and-organization)
  - [Provisioning modes](#provisioning-modes)
  - [The SAML flow has three legs](#the-saml-flow-has-three-legs)
  - [What a SAML response must be](#what-a-saml-response-must-be)
  - [Security notes](#security-notes)
  - [The interoperability suite](#the-interoperability-suite)
  - [SAML failure keys](#saml-failure-keys)
- [User provisioning with SCIM 2.0](#user-provisioning-with-scim-20)
  - [Enabling SCIM](#enabling-scim)
  - [Configuring Entra ID and Okta](#configuring-entra-id-and-okta)
  - [The SCIM endpoints](#the-scim-endpoints)
  - [What is supported](#what-is-supported)
  - [PATCH forms accepted](#patch-forms-accepted)
  - [Deprovisioning revokes access](#deprovisioning-revokes-access)
  - [Single sign-on over provisioned accounts](#single-sign-on-over-provisioned-accounts)
  - [Where provisioned resources are kept](#where-provisioned-resources-are-kept)
  - [SCIM error keys](#scim-error-keys)
- [Service Accounts and API Keys](#service-accounts-and-api-keys)
  - [The shape](#the-shape-1)
  - [Wiring it up](#wiring-it-up-1)
  - [A key is shown once](#a-key-is-shown-once)
  - [Scoped roles](#scoped-roles)
  - [Rotation and revocation](#rotation-and-revocation)
  - [Authenticating a request](#authenticating-a-request)
  - [Where accounts and keys live](#where-accounts-and-keys-live)
  - [API key failure keys](#api-key-failure-keys)
- [Browser Sessions in a Cookie](#browser-sessions-in-a-cookie)
  - [The cookies](#the-cookies)
  - [Setting and clearing them](#setting-and-clearing-them)
  - [The CSRF check](#the-csrf-check)
  - [The `sessionCookie` key](#the-sessioncookie-key)
  - [Session cookie failure keys](#session-cookie-failure-keys)
- [Verification](#verification)
- [Core Components](#core-components)
  - [`TomAuthenticationServer`](#tomauthenticationserver)
  - [`TomAuthenticationService` / `TomAuthenticationInfo`](#tomauthenticationservice--tomauthenticationinfo)
  - [`TomAuthenticationData`](#tomauthenticationdata)
  - [`Tom2FAService` / `Tom2FARegistry`](#tom2faservice--tom2faregistry)
  - [`Tom2FAPrerequisite`](#tom2faprerequisite)
  - [`Tom2FAPolicy` / `Tom2FADecision` / `Tom2FARequirement`](#tom2fapolicy--tom2fadecision--tom2farequirement)
  - [`Tom2FAEnrolmentStore` / `Tom2FAEnrolmentSupport`](#tom2faenrolmentstore--tom2faenrolmentsupport)
  - [`TomMemory2FAEnrolmentStore` / `TomPersistent2FAEnrolmentStore`](#tommemory2faenrolmentstore--tompersistent2faenrolmentstore)
  - [`TomTotp2FAService`](#tomtotp2faservice)
  - [`TomDeliveredCode2FAService`](#tomdeliveredcode2faservice)
  - [`TomEmailCode2FAService` / `TomSmsCode2FAService`](#tomemailcode2faservice--tomsmscode2faservice)
  - [`TomWebAuthn2FAService`](#tomwebauthn2faservice)
  - [`TomWebAuthnVerifier` / `TomWebAuthnSoftwareAuthenticator`](#tomwebauthnverifier--tomwebauthnsoftwareauthenticator)
  - [Adaptor annotations](#adaptor-annotations)
  - [`TomServerSelfLogin` / `TomServiceCredential`](#tomserverselflogin--tomservicecredential)
  - [`TomOAuthAuthenticationService` / `TomExternalIdentityDirectory`](#tomoauthauthenticationservice--tomexternalidentitydirectory)
  - [`TomOAuthProviders` / `TomOAuthProviderConfig` / `TomOAuthProvisioning`](#tomoauthproviders--tomoauthproviderconfig--tomoauthprovisioning)
  - [`TomOAuthFlow` / `TomOAuthPkce` / `TomOAuthStateStore` / `TomOAuthTokenTransport`](#tomoauthflow--tomoauthpkce--tomoauthstatestore--tomoauthtokentransport)
  - [`TomSqlOAuthStateStore` / `TomOAuthStateStoreSettings`](#tomsqloauthstatestore--tomoauthstatestoresettings)
  - [`TomExternalIdentityStore` / `TomExternalIdentityLink`](#tomexternalidentitystore--tomexternalidentitylink)
  - [`TomOAuthTokenGrant`](#tomoauthtokengrant)
  - [`TomOAuthTokenStore` / `TomPersistentOAuthTokenStore` / `TomExternalIdentityToken`](#tomoauthtokenstore--tompersistentoauthtokenstore--tomexternalidentitytoken)
  - [`TomOAuthServer`](#tomoauthserver)
  - [`TomExternalProvider` / `TomExternalRoleMapping` / `applyExternalRoles`](#tomexternalprovider--tomexternalrolemapping--applyexternalroles)
  - [`TomSamlProviders` / `TomSamlProviderConfig` / `TomSamlIdpMetadata` / `TomSamlCertificates`](#tomsamlproviders--tomsamlproviderconfig--tomsamlidpmetadata--tomsamlcertificates)
  - [`TomSamlFlow` / `TomSamlResponseValidator`](#tomsamlflow--tomsamlresponsevalidator)
  - [`TomXmlSignatureVerifier` / `TomExclusiveCanonicalizer` / `TomXmlDsig` / `TomSamlNames`](#tomxmlsignatureverifier--tomexclusivecanonicalizer--tomxmldsig--tomsamlnames)
  - [`TomSamlService` / `TomSamlServer`](#tomsamlservice--tomsamlserver)
  - [`TomSamlException`](#tomsamlexception)
  - [`TomJwtSigning` / `TomJwtKey` / `TomJwtSigningKey` / `TomJwtAlgorithm`](#tomjwtsigning--tomjwtkey--tomjwtsigningkey--tomjwtalgorithm)
  - [`TomJwksService` / `TomJwksServer`](#tomjwksservice--tomjwksserver)
  - [`TomScimProvisioning` / `TomScimApi` / `TomScimServer`](#tomscimprovisioning--tomscimapi--tomscimserver)
  - [`TomScimService`](#tomscimservice)
  - [`TomScimResource` / `TomScimResourceType` / `TomScimSchemas`](#tomscimresource--tomscimresourcetype--tomscimschemas)
  - [`TomScimStore` / `TomMemoryScimStore` / `TomSqlScimStore`](#tomscimstore--tommemoryscimstore--tomsqlscimstore)
  - [`TomScimFilter` / `TomScimPath`](#tomscimfilter--tomscimpath)
  - [`TomScimIdentityDirectory`](#tomscimidentitydirectory)
  - [`TomScimException`](#tomscimexception)
  - [`TomApiKeys` / `TomServiceAccount` / `TomApiKey`](#tomapikeys--tomserviceaccount--tomapikey)
  - [`TomApiKeyStore` / `TomMemoryApiKeyStore` / `TomSqlApiKeyStore`](#tomapikeystore--tommemoryapikeystore--tomsqlapikeystore)
  - [`TomSessionCookie` / `TomSameSite` / `TomSessionCookieException`](#tomsessioncookie--tomsamesite--tomsessioncookieexception)
- [Status and Limitations](#status-and-limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthenticationServer` | class | Orchestrates the login flow and issues JWTs; reflected (`@tomReflector`) |
| `TomAuthenticationService` | abstract class | The contract an app implements to verify a login; reflected (`@tomReflector`) |
| `TomAuthenticationData` | class | The data carried into one authentication attempt; reflected (`@tomReflector`) |
| `TomAuthenticationInfo` | class | A service's success result: principal + access-control definition |
| `TomDummyAuthenticationService` | class | Scaffolding-only default service (accepts any non-`GUEST` user) |
| `TomSignInOrganizationDirectory` | abstract interface class | The deployment's hook for the sign-in organization: a principal's organizations, and the principal signed in for one |
| `TomSignInOrganizations` · `TomSignInOrganization` · `TomOrganizationFallback` | class / class / enum | A principal's organizations, the default, whether a choice is offered, and what a non-member organization at sign-in does |
| `TomAuthenticationAdaptor` | class | The annotation that marks an adaptor and constrains it to guest/user flows; reflected (`@tomReflector`) |
| `Tom2FAAdaptor` | class | The annotation that marks a 2FA adaptor for a mechanism `type`; reflected (`@tomReflector`) |
| `Tom2FAService` | abstract class | The contract a second-factor mechanism implements: issue a challenge, verify a submission; reflected (`@tomReflector`) |
| `Tom2FARegistry` | class | Maps a mechanism `type` to its adaptor; scans `@Tom2FAAdaptor` classes on first use. Statics only |
| `Tom2FAPrerequisite` | abstract class | What an adaptor implements to say it cannot run here; the scan skips it and logs why |
| `Tom2FAContext` | class | What the adaptor is told about the login: the principal and its request context |
| `Tom2FAChallengeSpec` | class | What an adaptor returns from `issueChallenge` — hint, client blob, verification blob, attempts, validity |
| `Tom2FASubmission` | class | What an adaptor is handed on `verifySubmission` — the submitted factor plus its challenge |
| `TomTotp2FAService` | class | The shipped authenticator-app (RFC 6238 TOTP) mechanism, registered as `@Tom2FAAdaptor('totp')` |
| `TomTotpSecretResolver` | typedef | The fallback hook `TomTotp2FAService` reads when no `Tom2FAEnrolmentStore` is installed: a user in, their base32 secret or `null` out |
| `TomDeliveredCode2FAService` | abstract class | The shape every *delivered* code shares: generate, seal, send, recognise, and prove the destination by enrolment |
| `TomEmailCode2FAService` | class | A one-time code mailed through the Messaging module, registered as `@Tom2FAAdaptor('email')` |
| `TomSmsCode2FAService` | class | A one-time code texted through the Messaging module, registered as `@Tom2FAAdaptor('sms')` |
| `TomWebAuthn2FAService` | class | Passkeys: a credential made by an authenticator and verified by its signature, registered as `@Tom2FAAdaptor('webauthn')` |
| `TomWebAuthnVerifier` / `TomWebAuthnRegisteredCredential` / `TomWebAuthnVerifiedAssertion` | abstract final class / classes | The WebAuthn ceremony checks as pure functions, and what each yields |
| `TomWebAuthnSoftwareAuthenticator` | class | A passkey authenticator in software, for tests and bring-up **only** |
| `Tom2FAPolicy` | abstract class | Decides per login whether a second factor is owed and which mechanisms may answer for it |
| `Tom2FARequirement` | enum | `disabled` / `optional` / `required` — what a policy concluded |
| `Tom2FADecision` | class | One policy answer: the requirement, the permitted mechanisms, and any grace logins |
| `TomPrincipalFlag2FAPolicy` | class | The default policy, `const`-constructible: reads `requires2FA` / `twoFactorType` off the principal |
| `TomRole2FAPolicy` | class | A requirement per role; the strictest matched role wins |
| `Tom2FAGraceAccounting` | abstract class | Implemented *by a policy* that wants to be told when a grace login is spent |
| `Tom2FAGraceStore` | abstract class | Where the grace a principal has already spent is remembered, so a budget counts down |
| `TomMemory2FAGraceStore` | class | The default grace store — a map in this process |
| `Tom2FAEnrolmentStore` | abstract class | Where a principal's set-up factors live. **No default** — see [Enrolment](#enrolment) |
| `TomServerSession` | class | What a self-login produced: the deployment's principal and when its tokens expire |
| `Tom2FAAttemptStore` | abstract class | Records that an interim token has been answered, so a replay cannot mint a fresh allowance. `Tom2FAMemoryAttemptStore` is the per-process default |
| `Tom2FAAttempt` | class | One presentation of an interim token: its fingerprint, whose it is, the mechanism, and when the challenge lapses |
| `Tom2FAMemoryAttemptStore` | class | The default attempt store — a map in this process, pruned as it is written |
| `Tom2FASendLimiter` | abstract class | Paces the codes a delivered second factor sends to one address — each later code waits twice as long, up to 30 days; a correct code ends the run. `Tom2FAMemorySendLimiter` is the per-process default |
| `Tom2FASend` | class | One request to send a code: channel, address, and the pace the service asks for |
| `Tom2FAMemorySendLimiter` | class | The default send limiter — a map in this process, pruned as it is written |
| `tom2FATokenFingerprint` | function | The SHA-256 an attempt store keys on, so the log holds a digest rather than a usable token |
| `TomMemory2FAEnrolmentStore` | class | In-memory store, for tests and single-process development |
| `TomPersistent2FAEnrolmentStore` | class | Store over `TomUserTwoFactorEnrolment`, secrets encrypted at rest |
| `TomUserTwoFactorEnrolment` | class | One persisted enrolment row; the entity behind `@TomDbTable('tom_user_two_factor_enrolment')`, its `principalId` declared the data subject and its `hint` personal for the privacy module; read from the primary, never a read replica (`@TomPrimaryReads`) |
| `TomUserTwoFactorEnrolmentRepository` | class | The repository over that table |
| `Tom2FAEnrolment` | class | One set-up factor: type, id, hint, primary flag, and the mechanism's secret data |
| `Tom2FAEnrolmentSupport` | abstract class | What an adaptor adds to become *enrollable*: begin an offer, confirm it |
| `Tom2FAEnrolmentOffer` | class | What `beginEnrolment` returns — client blob, server blob, attempts, validity |
| `Tom2FAEnrolmentState` | class | The server's view of a pending enrolment, carried in the interim token |
| `Tom2FAException` | class | A mis-wired 2FA deployment; never client-facing |
| `TomServerSelfLogin` | class | Logs the deployment in as itself and installs its principal. Statics only |
| `TomServiceCredential` | class | The deployment's own credential and where to present it |
| `TomServiceLoginTransport` | abstract class | The one JSON POST behind the self-login, so it is swappable and testable |
| `TomHttpServiceLoginTransport` | class | The default transport, over `TomServerChannel` without bearer auth |
| `TomServiceLoginResponse` | class | A raw status + body from that transport |
| `TomServerSelfLoginException` | class | A *configured* deployment that could not log itself in; never client-facing |
| `TomOAuthAuthenticationService` | class | A `TomAuthenticationService` that authenticates an authorization code |
| `TomOAuthCredential` | class | The code + state pair carried in `TomAuthenticationData.key` |
| `TomExternalIdentityDirectory` | abstract class | What the deployment supplies: local account lookup and first-login provisioning |
| `TomOAuthProviderConfig` | class | One provider, as data: endpoints (or `discovery: true`), client credentials, claim names, provisioning, role mapping |
| `TomOAuthProviders` | class | The configured provider set, read from `oauth.providers`; `load` reads each discovery document |
| `TomOAuthProvisioning` | enum | What a first external login with no local account does: `refuse`, `linkExisting` or `autoProvision` (the default) |
| `TomOAuthFlow` | class | The authorization-code + PKCE handshake with an OpenID Connect nonce, and the dispatch to `TomSamlFlow` for a SAML provider id |
| `TomOAuthPkce` | class | A verifier / `S256` challenge pair |
| `TomOAuthAuthorizationState` | class | One pending authorization: state handle, verifier, and the login context it started in |
| `TomOAuthExchange` | class | A completed code exchange: which provider it was against, who that provider says this is, and which pending flow it completes |
| `TomOAuthStateStore` | abstract class | Where pending authorizations live; `TomOAuthMemoryStateStore` is the default |
| `TomOAuthMemoryStateStore` | class | The default in-process store, with expiry enforced on read and a sweep on each write, so no library timer has to be shut down |
| `TomSqlOAuthStateStore` | class | A state store over `tom_oauth_state`, so every node of a cluster sees the same pending authorizations |
| `TomOAuthStateRow` | class | One `tom_oauth_state` row, as the store reads it back; reflected (`@tomReflector`) |
| `oauthStateTable` | function | The `tom_oauth_state` declaration, from which its DDL, its statements and the convergence guard's schema model all derive |
| `oauthStateTableDdl` | function | The `CREATE TABLE` text of that declaration, for a deployment that applies schema by hand |
| `TomOAuthStateStoreType` | enum | `memory` (the default) or `sql` — which store a deployment selected |
| `TomOAuthStateStoreSettings` | class | The `oauth.stateStore` block as data, and `createStore()` for what it names |
| `TomOAuthTokenTransport` | abstract class | The provider HTTP calls, so a test can stub the provider |
| `TomHttpOAuthTokenTransport` | class | The live transport, over `package:http` |
| `TomExternalIdentity` | class | What the provider asserted: issuer, subject, username, display name, raw claims, groups, and the roles its mapping grants |
| `TomExternalIdentityStore` | abstract class | The linking table: (issuer, subject) → local account |
| `TomMemoryExternalIdentityStore` | class | Links in a map, for tests and bring-up **only** — links that vanish on restart cost a user their account |
| `TomPersistentExternalIdentityStore` | class | The store over `tom_external_identity` |
| `TomExternalIdentityLink` | class | One persisted link row; reflected (`@tomReflector`); read from the primary, never a read replica (`@TomPrimaryReads`) |
| `TomExternalIdentityLinkRepository` | class | The repository over that table |
| `TomOAuthTokenGrant` | class | One token grant as a provider issued it, with `expires_in` already resolved against a clock so nothing downstream needs to know when the response arrived |
| `TomOAuthTokenStore` | abstract class | Where grants live — separate from the link store, so holding credentials and holding links are two choices rather than one |
| `TomMemoryOAuthTokenStore` | class | Grants in a map, for tests and bring-up; a grant lost on restart costs one re-consent |
| `TomPersistentOAuthTokenStore` | class | The store over `tom_external_identity_token`, grant JSON encrypted at rest under its own optional cipher |
| `TomExternalIdentityToken` | class | One persisted grant row; the encrypted `tokenData` is the source of truth and the plain columns beside it are the operator projection; read from the primary, never a read replica (`@TomPrimaryReads`) |
| `TomExternalIdentityTokenRepository` | class | The repository over that table |
| `TomOAuthServer` | class | The three `/oauth/*` endpoints, exposed via `@TomApiImplementation` |
| `TomOAuthException` | class | A mis-configured provider set or a refused handshake |
| `TomExternalProvider` | abstract interface class | What every external identity provider has in common, whatever its protocol: id, issuer, provisioning, role mapping, clock skew |
| `TomExternalRoleMapping` | class | How a provider's group claim becomes Tom roles: `groupsClaim`, `roleMapping`, `defaultRoles` |
| `TomExternalTenancyMapping` | class | Which claims name the tenant and the sign-in organization: `tenantClaim`, `organizationClaim`, `organizationParameter` |
| `applyExternalRoles` | function | Adds the mapped roles to a principal for this session, beside the account's own |
| `TomSamlProviderConfig` | class | One SAML 2.0 identity provider and this server's side of the trust |
| `TomSamlProviders` | class | The configured SAML providers, read from `saml.providers`; `load` fetches their metadata |
| `TomTenantProviderSets` | class | Provider sets keyed by tenant — `TomOAuthProviders.tenants` and `TomSamlProviders.tenants`; a tenant with a set of its own sees only its providers |
| `TomSamlIdpMetadata` | class | What an identity provider's metadata says: entity id, single sign-on address, signing certificates |
| `TomSamlCertificates` | abstract final class | Reads the certificates and keys a SAML configuration names |
| `TomSamlNames` | abstract final class | SAML 2.0 namespace and binding identifiers |
| `TomSamlFlow` | class | SAML 2.0 Web Browser SSO: the request out, the response in, the handoff to the application |
| `TomSamlResponseValidator` | class | Verifies a SAML response for one provider and answers the identity it asserts |
| `TomXmlSignatureVerifier` | class | Verifies an enveloped XML signature against the configured keys, in the profile identity providers use |
| `TomExclusiveCanonicalizer` | abstract final class | Exclusive XML Canonicalization 1.0, without comments |
| `TomXmlDsig` | abstract final class | XML Signature namespace and algorithm identifiers |
| `TomSamlService` | abstract class | `POST /saml/acs` and `GET /saml/metadata/<providerId>`; reflected (`@tomReflector`) |
| `TomSamlServer` | class | The default SAML endpoint component; reflected (`@tomReflector`) |
| `TomSamlException` | class | A SAML message, configuration value or signature that cannot be used |
| `installJwtSigning` | function | Installs the configured JWT key material at boot, and refuses the bundled sample keys outside development |
| `verifyBearerToken` | function | Checks an inbound bearer token's algorithm, key id, signature, issuer and audience against the installed signing, returning it decoded or `null` |
| `TomSigningKeyException` | class | Raised by that refusal; names the unset fields and the environment variables that would fill them |
| `TomJwtSigning` | class | How this process signs and verifies tokens: algorithm, keys, signing key id, issuer, audience; `current` is the installed one |
| `TomJwtAlgorithm` | enum | `rs256` (the default), `es256`, `hs256` |
| `TomJwtKey` | class | One key a token can be verified with, under its `kid` — the RFC 7638 thumbprint of its public JWK |
| `TomJwtSigningKey` | class | A private key tokens are signed with, and the public key it publishes |
| `TomJwtKeyException` | class | A key or signing setting that cannot be used: an unknown algorithm, an unreadable key file, or a verify-only server asked to issue |
| `readPemFile` | function | Reads a configured key file, naming it in the error a missing file raises |
| `TomJwksService` | abstract class | The `GET /.well-known/jwks.json` endpoint; reflected (`@tomReflector`) |
| `TomJwksServer` | class | The default JSON Web Key Set component, publishing `TomJwtSigning.current`'s keys; reflected (`@tomReflector`) |
| `TomScimSchemas` | abstract final class | The SCIM schema and message URNs the service uses — core `User` and `Group`, the enterprise extension, list response, PATCH, error and the discovery schemas |
| `TomScimResourceType` | enum | `user` and `group`: resource name, endpoint, core schema and name attribute (`userName` / `displayName`) |
| `TomScimException` | class | A SCIM request that cannot be served, with the HTTP status and SCIM `scimType` it is answered with |
| `TomScimResource` | class | One stored user or group: its id, the client-managed JSON document, its lifecycle instants and change counter |
| `TomScimStore` | abstract interface class | Where provisioned resources are kept: create, read, find by name, list, replace, delete |
| `TomMemoryScimStore` | class | A store in one process's memory — a single node, a test, or a deployment that mirrors resources into its own table |
| `TomSqlScimStore` | class | A store over the `tom_scim_resource` table, shared by every node |
| `TomScimResourceRow` | class | One `tom_scim_resource` row, as the store reads it back; reflected (`@tomReflector`) |
| `scimResourceTable` | function | The `tom_scim_resource` declaration, from which its DDL, its statements and the convergence guard's schema model all derive |
| `scimResourceTableDdl` | function | The `CREATE TABLE` text of that declaration, for a deployment that applies schema by hand |
| `TomScimPath` | class | A PATCH attribute path: optional schema URN, attribute, optional value filter, optional sub-attribute |
| `TomScimFilter` | sealed class | A parsed SCIM filter expression, evaluated against a resource's JSON representation |
| `TomScimAnd` / `TomScimOr` / `TomScimNot` | classes | The logical filter operators |
| `TomScimValuePath` | class | `attr[filter]` — some element of a multi-valued attribute matches |
| `TomScimComparison` | class | `attr op value`, or `attr pr` |
| `scimValues` | function | The values at an attribute path in a JSON document, multi-valued attributes flattened |
| `scimLookup` | function | A JSON value by attribute name, matched case-insensitively |
| `scimKeyOf` | function | The key of a JSON object that equals an attribute name case-insensitively |
| `TomScimService` | class | The SCIM service provider over a `TomScimStore`, independent of HTTP — and the revocations a deprovisioning change makes |
| `TomScimProvisioning` | class | The installed SCIM service and the bearer secrets that may call it, read from `scim` |
| `TomScimApi` | abstract class | The SCIM 2.0 endpoints under `/scim/v2`; reflected (`@tomReflector`) |
| `TomScimServer` | class | The default SCIM endpoint component, answering in `application/scim+json`; reflected (`@tomReflector`) |
| `TomScimIdentityDirectory` | class | The `TomExternalIdentityDirectory` over the provisioned users: single sign-on resolves the provisioned account, with roles from its groups |
| `TomServiceAccount` | class | A non-human caller with roles of its own; every key it issues is bounded by them |
| `TomApiKey` | class | One API key's stored record — the hash of its secret, never the secret — with its roles, label, expiry, revocation and last use |
| `TomIssuedApiKey` | class | A key as issued: the record, and the one time the full `tomk.<keyId>.<secret>` value is visible |
| `TomApiKeyIdentity` | class | The key and service account a request authenticated with, in the request zone |
| `TomApiKeyStore` | abstract class | Where service accounts and key records live |
| `TomMemoryApiKeyStore` | class | The default store — maps in this process, for a single node and tests |
| `TomSqlApiKeyStore` | class | A store over `tom_service_account` and `tom_api_key`, shared by every node |
| `TomServiceAccountRow` | class | One `tom_service_account` row, as the store reads it back; reflected (`@tomReflector`) |
| `TomApiKeyRow` | class | One `tom_api_key` row, as the store reads it back; reflected (`@tomReflector`) |
| `serviceAccountTable` / `apiKeyTable` | function | The two tables' declarations, from which the store's DDL derives |
| `TomApiKeys` | class | Issues, rotates, revokes and checks API keys; `install` makes it the one the request pipeline reads `X-API-Key` with |
| `TomApiKeyException` | class | An API-key operation that cannot be done: an unknown account or key, or a role the account does not hold |
| `TomSessionCookie` | final class | A browser session's access token in an `HttpOnly` cookie, with a page-readable CSRF token beside it; `current` is installed by `configure` from the `sessionCookie` key, and the request pipeline reads the cookie and holds a cookie-authenticated request to `checkCsrf` |
| `TomSameSite` | enum | The `SameSite` attribute of the session cookies: `strict`, `lax`, `none` |
| `TomSessionCookieException` | class | The `sessionCookie` settings cannot be applied, or a cookie-authenticated request failed the CSRF check |

One type every service in the list throws lives in `little_things`, with the
rest of the package's exception hierarchy:

| Name | Module | Purpose |
| ---- | ------ | ------- |
| `TomLoginException` | `little_things` | A login failure; carried back as a failed result rather than propagated. Carries a required `TomLoginFailure` reason — the closed set a client branches on, documented in [little_things.md](little_things.md#tomloginexception-and-its-reason) |

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
        │  or throws TomLoginException
        ▼
        │
        ├─ 2FA policy owes a factor ?  ──► see Two-Factor Authentication
        ▼
TomBearerAuthentication.convertPrincipalToTokenPayload
        │  → (public claims, encrypted private claims)
        ▼
TomAuthenticationResult
   ├─ authenticationToken   (JWT of public claims)
   └─ authorizationToken    (JWT of public claims + encrypted acd)
```

A thrown `TomLoginException` is **not** propagated — the server catches it and
returns a `TomAuthenticationResult` carrying the exception's `key` in `error`, so
the client can show a localized message, and its reason in
`loginFailureReason`, so the client can branch on the closed `TomLoginFailure`
set rather than on the key. Any other error becomes a `"login.error.unknown"`
result classified `providerError`. A refused second factor that is offered
again — a re-issued challenge or enrolment token — carries its reason the same
way.

### Tenancy and the token

In a multi-tenant deployment (see [tenancy.md](tenancy.md)) a login request
carries no token yet, so the request pipeline resolves its tenant from the host
or a header, and the login runs inside it. Before the tokens are minted,
`TomAuthenticationServer` binds the principal to that tenant: `TomPrincipal.tenant`
is set to `TomTenantContext.currentId`, and both tokens carry it as the `tenant`
claim — separately from `organization`, the business unit inside the tenant the
login is for. From then on the claim decides which tenant the session's requests
are for.

A principal the `TomAuthenticationService` already placed in **another** tenant
is refused:

| Key | Reason | When |
| --- | ------ | ---- |
| `login.error.tenant-mismatch` | `TomLoginFailure.accountProblem` | The account belongs to another tenant than the one signed in to — an account of one tenant signing in through another tenant's host would otherwise receive a token for the tenant it reached. |

A service that places no tenant on its principals leaves the choice to the
request; a service whose accounts are a tenant's rows reads them through a
`@TomTenantTable` entity and finds only the current tenant's. With no tenant in
context — a deployment without tenancy, or a login naming none — the token
carries no `tenant` claim.

### The sign-in organization

A user can be a member of several organizations of a tenant. A session is signed
in for one of them — `TomPrincipal.organization`, the token's `organization`
claim — and its rights are that organization's. The deployment knows the
memberships and tells the server through a `TomSignInOrganizationDirectory`
bean:

```dart
/// Answers from the deployment's own memberships: username -> organization
/// ids, the first the user's default.
class MyOrganizations implements TomSignInOrganizationDirectory {
  MyOrganizations(this.memberships);

  final Map<String, List<String>> memberships;

  @override
  Future<TomSignInOrganizations> organizationsFor(TomPrincipal p) async {
    final ids = memberships[p.username] ?? const <String>[];
    return TomSignInOrganizations(
      [for (final id in ids) TomSignInOrganization(id)],
      defaultOrganization: ids.isEmpty ? null : ids.first,
      choiceOffered: ids.length > 1,
      fallback: TomOrganizationFallback.useDefault,
    );
  }

  @override
  Future<TomAuthenticationInfo> signInFor(TomPrincipal p, String org) async {
    // A real directory also loads the organization's roles into p.aci.
    p.organization = org;
    return TomAuthenticationInfo(p, TomAccessControlDefinition());
  }
}

TomBean.withType<TomSignInOrganizationDirectory>(
  MyOrganizations({'alice': ['acme-hq', 'acme-sales']}),
);
```

**At sign-in** the server settles the organization before the second factor is
decided and the tokens are minted, on every login path (password, external
identity, the passes that follow): the organization the authentication service
put on the principal stands when the user is a member of it; a login that named
none is signed in for the default; a login naming an organization the user is
not a member of is refused, or signed in for the default when the list's
`fallback` is `TomOrganizationFallback.useDefault`. When the settled
organization is not the one the service resolved, `signInFor` supplies the
principal and its rights for it. A guest is not settled, and with no directory
installed the organization stays the service's.

**Within a session** a user switches to another organization without signing in
again. `TomAuthenticationServer.switchOrganization(message)` takes the
organization from the message and the session's principal from the request,
and issues new tokens for it — no credential is checked, and the session's
second factor carries over. It refuses an organization the user is not a member
of, a list that offers no choice, and a session that is not fully signed in;
every switch is recorded in the audit trail under `session.organizationSwitched`
with the previous and the new organization. `signInOrganizations()` answers the
list for a client offering the choice (`TomSignInOrganizations.toJson`). The
deployment exposes both through endpoints of its own, beside its login
endpoints. Because the organization is always in the token, switching is the
only way a session's rights stay correct when the user works for another
organization.

An application signing in through a Tom identity provider switches with a new
authorization naming the organization (`organizationParameter`, see
[Claim mapping: tenant and organization](#claim-mapping-tenant-and-organization)),
which the provider answers from its session.

| Key | Reason | When |
| --- | ------ | ---- |
| `login.error.organization.not-member` | `TomLoginFailure.accountProblem` | A login or a switch names an organization the user is not a member of (under `TomOrganizationFallback.refuse` for a login). |
| `login.error.organization.none` | `TomLoginFailure.accountProblem` | The user is a member of no organization to sign in for. |
| `login.error.organization.choice-not-offered` | `TomLoginFailure.accountProblem` | A switch, where the user's list offers no choice. |
| `login.error.not-authenticated` | `TomLoginFailure.accountProblem` | A switch or a listing without a fully signed-in session. |
| `login.error.organization.no-directory` | `TomLoginFailure.providerError` | A switch or a listing with no `TomSignInOrganizationDirectory` installed. |

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
      throw TomLoginException(
        'error.invalid-user-or-password',
        'Invalid login',
        reason: TomLoginFailure.accountProblem,
      );
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

### Your service is the source of what the principal asserts

Everything the returned principal carries is your answer. That includes the part
it is easy to assume the framework fills in: `principal.cli`, the client limits —
the `enabledModules` and `quotas` the client's subscription grants. There is no
subscription store in `tom_core_server` and no environment lookup behind it. If
your service does not put the limits on the principal, and no provider supplies
them, the principal has none, and the tokens will say so.

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

Two values are resolved after the credential is accepted, each because your
service is not their authority:

- **`principal.timezone`**, from the user's stored preference — a server-held
  preference rather than a fact about the identity being asserted.
- **`principal.cli`**, from the kernel's `TomClientLimitsProvider`, when one is
  installed (`TomClientLimitsProvider.installed = …`). The provider is the seam
  a subscription and quota service fills — Tom SQM, when it exists — so that
  what a client bought is answered by the service that sells it. The server asks
  it for every principal before minting tokens; an answer of `null` keeps your
  service's limits, and a provider that fails is logged and your service's
  limits are minted, so an unreachable subscription service does not stop every
  sign-in. With no provider installed, your service's answer stands. The
  framework ships the contract and these call sites, and no implementation.

Two consequences worth knowing before you rely on it. The token carries a
**login-time snapshot** — the limits ride in the *public* half of the JWT as the
`subscription_enabledModules` / `subscription_quotas` claims and are read back
into `principal.cli` when a token is parsed. A client revises its copy
mid-session with `TomBearerAuthentication.refreshClientLimits()` (which asks the
provider) or `replaceClientLimits(...)` (values already in hand), the way
`replacePrincipalAci` revises the ACI; neither re-mints the token, so a server
reading limits from a request's token sees the snapshot until the next login and
asks the provider itself when it needs current figures. And because that half is
public, the quota figures are readable by anyone holding the token: they are a
ceiling to enforce against, not a secret. Nothing in the framework counts usage
or refuses the 1001st call — carrying the ceiling to where the application can
read it is the whole of what the kernel does.

## Wiring the Server

Register the service(s) through the static settings, then expose a subclass of
`TomAuthenticationServer` as endpoints:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService = MyAuthService();
TomAuthenticationServer.globalSettingGuestAuthenticationService = MyGuestService();

// A @tomComponent subclass exposes authenticateGuest / authenticatePass1 as
// HTTP endpoints (see tom_uam_server for a full example).
class ServerAuthenticationServer extends TomAuthenticationServer { /* ... */ }
```

Until a real service is registered, the default
`TomDummyAuthenticationService` authenticates any non-`"GUEST"` user and logs an
error on every call — acceptable only while scaffolding.

The issued tokens' issuer, audience and signing key are not settings of
`TomAuthenticationServer`: they are the server configuration's, read once at
boot by `installJwtSigning` into `TomJwtSigning.current`, and the same values
the inbound check requires.

### The signing keys

A token is only worth what its signing key is worth, so a server that mints or
verifies one calls `installJwtSigning(configuration)` **once at boot** — after
the runtime environment is selected, before anything touches a token. It reads
the fields below off the `TomBaseServerConfiguration`, installs the result as
`TomJwtSigning.current` and as `TomJwtConfiguration.defaultSignConfiguration`,
and returns the latter.

**Three algorithms** are configurable, by `jwtAlgorithm`:

| Algorithm | Signs with | Verifies with | Published |
| --------- | ---------- | ------------- | --------- |
| `RS256` (the default) | The RSA private key in `jwtSigningKeyFile` | Its public half, and every key in `jwtVerificationKeyFiles` | Yes, as a JSON Web Key Set |
| `ES256` | The EC (P-256) private key in `jwtSigningKeyFile` | Its public half, and every key in `jwtVerificationKeyFiles` | Yes, as a JSON Web Key Set |
| `HS256` | The secret `jwtSharedSecretKey` | The same secret | Never |

The asymmetric algorithms separate the two halves: the private key stays on the
server that issues tokens, and the public key verifies them anywhere — on
another Tom server, in an API gateway, in any JWT library. HS256 remains for a
single service, where one secret both signs and verifies; whoever holds it can
mint a token, so it is never published.

| Field | Environment spelling | Role |
| ----- | -------------------- | ---- |
| `jwtAlgorithm` | `JWT_ALGORITHM` | `RS256` (when unset), `ES256` or `HS256`, in any case. Anything else is refused with `jwt.keys.unknown_algorithm` |
| `jwtSigningKeyFile` | `JWT_SIGNING_KEY_FILE` | Path of the PEM file holding the private key RS256 or ES256 tokens are signed with |
| `jwtVerificationKeyFiles` | `JWT_VERIFICATION_KEY_FILES` | Comma-separated paths of PEM files holding public keys that still verify: retired keys on the issuing server, the issuer's keys on a verify-only server |
| `jwtIssuer` | `JWT_ISSUER` | The `iss` every issued token carries and every verified token must carry; `tom` when unset |
| `jwtAudience` | `JWT_AUDIENCE` | The `aud` every issued token carries and every verified token must carry; none when unset |
| `jwtSharedSecretKey` | `JWT_SHARED_SECRET_KEY` | The HMAC secret, read only under `HS256` |
| `jwtRsaPrivKey` | `JWT_RSA_PRIV_KEY` | Decrypts the access-control payload carried inside the token |
| `jwtRsaPubKey` | `JWT_RSA_PUB_KEY` | Encrypts it |

The last two are not signing keys. The authorization token carries its
access-control definition in an `encrypted` section, and this RSA pair encrypts
and decrypts it under every algorithm; a server that reads that section — the
issuer and every server verifying its tokens — holds the pair.

**Key files are PEM**: a private key in PKCS#8 (`-----BEGIN PRIVATE KEY-----`),
a public key in SPKI (`-----BEGIN PUBLIC KEY-----`). An EC key must name the
curve P-256 (`prime256v1`) rather than spell out explicit parameters:

```bash
# RS256
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out jwt_signing.pem
openssl pkey -in jwt_signing.pem -pubout -out jwt_signing.pub.pem

# ES256 — a PKCS#8 key on the named curve P-256 (prime256v1)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
  -pkeyopt ec_param_enc:named_curve -out jwt_signing.pem
openssl pkey -in jwt_signing.pem -pubout -out jwt_signing.pub.pem
```

A file that cannot be read, or holds no key of the configured algorithm's kind,
stops the boot with `jwt.keys.unreadable_key_file`, naming the file.

Every field defaults to `null` — the framework ships no key of its own, because
a default key is a key everyone has. Key material left unset falls back to the
sample material bundled in `tom_crypto`, which is published in its sources and
therefore secret from nobody: the RSA pair as the RS256 signing key, the
passphrase as the HS256 secret, and the RSA pair as the payload-encryption
pair. That fallback is a scaffolding convenience and is treated as one:

- **Outside a development or test environment it is refused.** Any unset field
  makes the boot throw `TomSigningKeyException`, naming the fields and the
  environment variables that would fill them. A server that would have signed
  with a published key does not start.
- **Inside one it warns**, once at boot and again on every sign and verify —
  `installJwtSigning` passes `isDummy: true` when anything was left unset, which
  is what keeps the per-operation warning coming.
- **ES256 has no fallback.** No sample EC key ships, so an ES256 server without
  a `jwtSigningKeyFile` (and without verification keys) is refused in every
  environment.

Two servers trust each other's tokens when the verifier holds the issuer's
public key — in `jwtVerificationKeyFiles`, or under HS256 the same
`jwtSharedSecretKey` — and both name the same issuer and audience. The fields are
ordinary configuration, so they can come from a YAML resource, the process
environment, a `.env` file, or the command line, in that order of increasing
precedence — see [configuration.md](configuration.md#source-precedence) for the
merge and for how the `SCREAMING_SNAKE_CASE` spellings above reach the fields.

### Key ids

Every token signed with an asymmetric key carries a `kid` header naming the key,
and the id is not configured: it is the **RFC 7638 JWK thumbprint** of the
public key — the base64url SHA-256 of its required members (`e`, `kty`, `n` for
RSA; `crv`, `kty`, `x`, `y` for EC) in lexicographic order. A private key and its
public half yield the same id, and every server derives the same id from the
same key without being told it, so the issuer's `kid` and the verifier's key
list agree by construction. `TomJwtKey.thumbprint` computes it.

An HS256 secret has no id. Its tokens carry no `kid`, and the one secret
answers for every token.

### The JSON Web Key Set

`TomJwksService` serves `GET /.well-known/jwks.json` — the path OpenID Connect
discovery points to — and `TomJwksServer`, its default component, is mounted by
the endpoints pipeline like every other component endpoint, with nothing to
register. The set holds the public half of every key a token of this
deployment may be verified with: the signing key first, then the retired keys
still verifying. Each entry carries `kty`, its key members, `kid`, `use: sig` and
`alg`; the private part is never in it.

| Property | Value |
| -------- | ----- |
| Access | `@TomPublicAccess` — a verifier fetching the set holds no token yet, and the set holds public keys only |
| `content-type` | `application/jwk-set+json` |
| `cache-control` | `public, max-age=300` (`TomJwksServer.cacheFor`, five minutes) |
| Under HS256 | `404`: there is no public key, and the secret is never published |

```json
{
  "keys": [
    {"e": "AQAB", "kty": "RSA", "n": "…", "kid": "…", "use": "sig", "alg": "RS256"}
  ]
}
```

### Rotating the signing key

A new key signs as soon as it is configured; the key it replaces moves to the
verification keys, so the tokens it signed keep verifying until they expire, and
is removed afterwards. The steps:

1. **Generate the new key** pair (see [The signing keys](#the-signing-keys)).
2. **Reconfigure every server.** On the issuing server, set `jwtSigningKeyFile`
   to the new private key and add the **old key's public PEM** to
   `jwtVerificationKeyFiles`. On every verify-only server, add the new key's
   public PEM to `jwtVerificationKeyFiles` beside the old one. Restart them.
3. **The new key signs immediately**, and tokens signed with the old key keep
   verifying everywhere, because every server still holds it.
4. **The JSON Web Key Set publishes both keys**, the signing key first. A
   verifier that reads the set picks up the new key within the five-minute cache
   window. Update the verify-only servers, and let caches of the set refresh,
   before relying on new tokens being accepted elsewhere.
5. **After the longest token lifetime has passed**, remove the old key from
   `jwtVerificationKeyFiles` on every server. Its tokens have expired, and once
   it is gone they stop verifying.

The `kid` is what carries a token through this: it names the key that signed it,
and the verifier looks that key up rather than trying each one.

### Verify-only servers

A server configured with `jwtVerificationKeyFiles` and no `jwtSigningKeyFile`
only verifies. It holds the issuer's public keys, accepts the issuer's tokens,
and refuses to mint one: `TomJwtSigning.canSign` is `false`, and
`requireSigning()` — which `TomAuthenticationServer` calls before issuing —
throws `jwt.keys.verify_only`. An application server beside an auth server is
the typical case; it needs no private signing key at all, so the one that exists
lives on one machine.

A verify-only server falls back to no sample key: its verification keys are its
configuration. It still holds the payload-encryption pair, `jwtRsaPrivKey` /
`jwtRsaPubKey`, because it decrypts the access-control section of the tokens it
accepts.

### Verifying an inbound token

Signing is half of it. A JWT's public section is base64, not ciphertext: the
holder can read every claim in it and can just as easily rewrite one and send it
back. Decoding notices nothing — the same string comes apart the same way — so
the signature is the only thing that separates a token this server minted from a
token a client typed.

`verifyBearerToken` is where that is checked, and `extractAuthentication` is the
one place it is called, because the `Authorization: Bearer` header is the one
path a client-supplied token enters by. A token that fails is treated as **no
credentials at all**: the request is served anonymously and refused by the
ordinary access-denied path, which is the same answer a request presenting
nothing gets. That is deliberate — throwing would turn a hostile request into an
HTTP 500 and tell the sender the difference between a rejected signature and an
accepted one. Every rejection is logged at warning level, because a bad
signature on a live server is either two deployments configured with different
keys or somebody probing, and an operator wants to see both. The warning names
the reason and never the token.

The check is unconditional and has no opt-out. A flag permitting an unverified
token would be the same exposure with a name on it, and the deployment shape
that might have wanted one — a server running the bundled sample keys — is
already refused at boot by `installJwtSigning`.

**The signature, and not the validity window.** `verifyBearerToken` passes
`checkExpiresIn: false` / `checkNotBefore: false`, which looks like a gap and is
not. An expired token still has to reach the request zone: it is the only thing
left identifying who is asking, and a refresh or re-login endpoint is reached
with exactly it. Expiry is answered one layer up, where
`tomDefaultAuthenticationMiddleware` resolves an expired session to *no
principal* while leaving the credentials in place. The two questions are
different — *is this ours* and *is it still current* — and only the first can be
forged.

**Why not in `TomClientJwtToken`.** Verifying in the constructor would be the
tighter guarantee, since no code path could then hold an unverified token. But
the same class runs in Flutter clients that hold no verifying key, so it would
need an opt-out, and the opt-out is the hole again. The check therefore lives on
the server, next to the configuration that installs the key it checks against.
What the value class does offer is that `payload` hands back an **unmodifiable
view**: a reader of a token cannot quietly become a writer of it, so the
signature check keeps meaning something after the moment it was made.

### What a verifier refuses

`verifyBearerToken` checks a token against `TomJwtSigning.current`, and answers
`null` for any of these:

| The token | Why it is refused |
| --------- | ----------------- |
| Names another algorithm in its `alg` header | The algorithm is this deployment's, never the token's. A verifier that took `alg` from the header could be told to check an RS256 public key as an HMAC secret — and the public key is public, so anyone could compute that HMAC |
| Names no `kid`, or a `kid` this deployment does not hold | Under RS256 or ES256 the key is looked up by id among the signing key and the retired keys still verifying; there is no "try each key" |
| Carries a signature that does not verify against that key | It was not signed by the key it names |
| Carries another `iss` | The issuer is the configured `jwtIssuer` (`tom` when unset) |
| Carries another `aud`, or none, when an audience is configured | A token minted for one service is not accepted by another |
| Does not decode, or its signed body does not decrypt | It is not a token this deployment can read |

### Third-party verification

Under RS256 and ES256 nothing about verifying a token is specific to this
framework. A verifier fetches `/.well-known/jwks.json`, picks the key whose
`kid` the token names, and checks the signature with any JWT library — an API
gateway, a service in another language, or `package:jose` in Dart. It then
checks `iss` and `aud` against the deployment's `jwtIssuer` and `jwtAudience`,
and `exp` by its own policy. `test/jwt_keys_test.dart` holds this to a library
that shares no code with the framework: `package:jose` fetches the set over HTTP
and verifies RS256 and ES256 tokens through it.

What a third party cannot read is the authorization token's `encrypted`
section, which is encrypted to the payload-encryption pair; the public claims
are readable by any verifier.

### Signing failure keys

All raised at boot or on issue, never by a request, and all `clientThrow: false`.

| Key | Exception | Raised when |
| --- | --------- | ----------- |
| `jwt.signing.key.unconfigured` | `TomSigningKeyException` | Key material would fall back to the bundled sample keys outside a development or test environment, or an ES256 server has no key. `parameters`: `fields` |
| `jwt.keys.unknown_algorithm` | `TomJwtKeyException` | `jwtAlgorithm` names no supported algorithm. `parameters`: `algorithm` |
| `jwt.keys.unreadable_key_file` | `TomJwtKeyException` | A configured key file cannot be read or holds no key of the configured algorithm's kind. `parameters`: `source`, `algorithm` |
| `jwt.keys.verify_only` | `TomJwtKeyException` | A token was to be issued by a server configured with verification keys only |

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
│   └─ Tom2FAPolicy.resolve().decideFor(ctx)      → required, ['totp']     │
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
  static Tom2FAPolicy resolve() { ... } // the installed bean, else the default
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
| `graceLogins` | How many more times this user may decline a `required` factor. Default `0`. What the *decision* reports is what is **left**, where the policy counts — `TomRole2FAPolicy` does |

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
TomBean.withType<Tom2FAPolicy>(
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
act — `TomBean.withType<Tom2FAPolicy>(...)` — because a policy that got picked
up by a component scan would silently start demanding second factors from a
deployment that only added a dependency.

**Grace is a budget, and `TomRole2FAPolicy` counts it.** `graceLogins: 3` means
three logins in all: the policy implements `Tom2FAGraceAccounting`, the server
tells it the moment one is spent, and `Tom2FAGraceStore` holds the running
total, so the next decision reports what is left. After the third, the enrolment
offer stops being declinable.

The server calls the hook **only at the moment grace is actually spent** — a
user declining an offer that was declinable *because* of grace — never when the
offer was merely made, and never for an `optional` decline, which costs nothing.

```dart
abstract class Tom2FAGraceStore {
  Future<int> consumedBy(Tom2FAContext context);
  Future<void> recordConsumed(Tom2FAContext context);
}
```

`TomMemory2FAGraceStore` is installed by default and is **per process**. Unlike
`Tom2FAEnrolmentStore`, which has no default because an enrolment that vanished
on restart would lose a user their factor, losing a grace count degrades to
exactly the behaviour that preceded counting it: the user is offered enrolment
again and gets another few logins. A restart can therefore make the budget
longer and never shorter, so a per-process default cannot cost anyone access —
and a store that had to be installed before the counter counted is a counter
most deployments would not have.

A deployment that wants the budget to survive a restart, or to be one budget
across a cluster, implements the two methods against its own user data, where
the principal already lives. The framework ships no table for it: the count is a
fact about a user, and this package has no user table.

```dart
class MyGraceStore implements Tom2FAGraceStore {
  @override
  Future<int> consumedBy(Tom2FAContext context) =>
      _users.graceLoginsSpentBy(context.principal);

  @override
  Future<void> recordConsumed(Tom2FAContext context) =>
      _users.recordGraceLoginSpentBy(context.principal);
}
```

The count is keyed on the **principal**, deliberately not on the principal and
mechanism: grace is spent by declining to enrol at all, which is a decision
about the obligation rather than about any one way of meeting it. Keying by
mechanism would hand a user a fresh allowance for every mechanism the deployment
offers.

A policy of your own that grants grace implements `Tom2FAGraceAccounting` the
same way, and may use the store or its own records; one that does not implement
it grants the same grace every time, which is a valid deployment — "warn, do not
enforce yet" — but no longer the default's behaviour.

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
`TomLoginException`**. There is no `false` return: a wrong code and an unusable
offer are both failures, and the exception's `key` is what the client is told.

**What the deployment supplies: `Tom2FAEnrolmentStore`.**

```dart
abstract class Tom2FAEnrolmentStore {
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context);
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment);
  Future<void> remove(Tom2FAContext context, String enrolmentId);
  static Tom2FAEnrolmentStore? resolve() { ... } // nullable — deliberately so
}
```

`store` is an **upsert on `enrolmentId`**, so re-enrolling a mechanism replaces
the old factor rather than accumulating one per attempt; `remove` on an id that
is not there is a no-op, so a double-delete is not an error.
`Tom2FAEnrolmentStore.principalKeyOf(context)` is the one place the persistent
store derives its key from, so a store keying rows differently only has one
method to disagree with.

**That key is the principal's tenant-qualified id — the tenant is part of it,
the organization is not.** A `TomPrincipal.id` is unique within its tenant only:
another tenant's `u1` is a different person. The key is
`TomPrincipal.qualifiedId` — `tenant:<tenant>/<id>`, or the bare id in a
deployment without tenancy — so under `shared` isolation, where every tenant's
enrolments sit in one `tom_user_two_factor_enrolment`, two tenants' `u1` keep two
sets of factors; under `schema` and `database` isolation the table is the
tenant's own and the key is the same, so a tenant's rows move between models
unchanged. The organization is left out, so a user's second factors are theirs in
every organization they sign in for: enrolling an authenticator once is enough.
The table is a tenant table (`@TomTenantTable`): a `tenant_id` column leads its
unique key `(tenant_id, principal_id, enrolment_id)`. Every framework table that
files rows per principal keys them the same way — see
[tenancy.md](tenancy.md#principals-per-tenant). The methods take the whole
`Tom2FAContext`, so a deployment can supply a store that keys rows its own
way.

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
| `null` | **No store is installed.** Nobody tracks enrolments here | Challenges the mechanism, as a deployment with no enrolment support does. The adaptor remains the only authority on whether the user has a factor |
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
  achieves nothing (`login.error.2fa.enrolment-required`). "Server-signed" is
  load-bearing and is only worth anything because the signature is checked: see
  [Verifying an inbound token](#verifying-an-inbound-token). A JWT's public
  section is plain base64, so without that check the flag would be a claim the
  caller writes.
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
TomBean.withType<Tom2FAPolicy>(
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
TomBean.withType<Tom2FAEnrolmentStore>(
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

That callback is a `TomTotpSecretResolver` — `FutureOr<String?> Function(
Tom2FAContext)`, answering the base32 secret the user's authenticator app was
provisioned with, or `null` when that user has none enrolled.

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
TomBean.withType<TomEmailService>(TomEmailService(outbox: outbox, texts: texts));
TomBean.withType<TomSmsService>(TomSmsService(outbox: outbox, texts: texts));
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

**Sending is paced.** Guessing a code is bounded by the attempt counter;
*asking* for codes is bounded here. Every login that passes the first factor
issues a fresh challenge, and so a fresh mail or a fresh paid text — so without
a pace, one stolen password could flood a phone and run up the deployment's SMS
bill. Before a code is generated, at a challenge and at enrolment alike, the
adaptor claims a send from the `Tom2FASendLimiter`:

- the first code to an address goes out at once;
- each later one in the run must wait twice as long as the one before —
  30 seconds, 1 minute, 2 minutes, … — so a user who lost a text asks again
  half a minute later, while a script asking without pause meets an hour's wait
  after eight sends;
- the wait never exceeds 30 days, and a run that reaches it stays there: one
  code a month to an address nobody is answering;
- **a correct code ends the run** — at login (`verifySubmission`) or at
  enrolment (`confirmEnrolment`) — so a legitimate user's next login starts
  afresh rather than inheriting the wait earlier logins built up. A run also
  lapses after twice the cap with no send.

A send too soon fails the login with `login.error.2fa.send-limit`
(`TomLoginFailure.rateLimited`), carrying `retryAfterSeconds` — the pace is a
fact about the address, so a client may show the wait. The claim is made before
delivery and stands whether delivery succeeds or not: a failed send may still
have been charged, and a free retry would let a failing relay be hammered.
Addresses are paced per channel, and compare without case or surrounding
whitespace. The pace is `sendInterval` (30 s) and `maxSendInterval` (30 days) on
`TomDeliveredCode2FAService`, overridable per adaptor; the record is the
installed `Tom2FASendLimiter`, by default `Tom2FAMemorySendLimiter` — per
process, like the attempt store, so a cluster that wants one pace across its
nodes installs a limiter they share.

**Tuning.** Static settings, per adaptor: `globalSettingCodeDigits` (6),
`globalSettingAttemptsAllowed` (3), `globalSettingChallengeValidity`
(10 minutes for mail, 5 for SMS — a mail may be greylisted; a text is not),
`globalSettingChallengeTemplateKey` / `globalSettingEnrolmentTemplateKey`,
`globalSettingEnrolmentAttemptsAllowed` and `globalSettingEnrolmentValidity`.

### Passkeys (WebAuthn)

`TomWebAuthn2FAService` is the strongest factor the framework ships. A passkey is
a key pair made by an authenticator — a phone's secure enclave, a security key,
a laptop's TPM — whose private half never leaves it. Enrolment stores the public
half; a challenge asks the authenticator to sign a fresh random value together
with the origin the page is on. A phishing page cannot get a usable answer,
because the browser writes the page's *real* origin into what is signed and the
server refuses any other.

```dart
TomWebAuthn2FAService.globalSettingRelyingPartyId = 'example.com';
TomWebAuthn2FAService.globalSettingAllowedOrigins = {'https://app.example.com'};
```

**It is offered only once a relying party is configured.** The RP id is the
registrable domain passkeys are bound to, forever: a guessed one would make
every passkey enrolled under it unusable once the guess is corrected, so an
unset RP id keeps the mechanism out of the registry (`Tom2FAPrerequisite`). The
allowed origins default to `https://<RP id>`; list every origin the login page
is served from, including `http://localhost:…` for development (browsers allow
WebAuthn on `localhost` without TLS) and the `android:apk-key-hash:…` origin of
an Android app.

**What travels.** The challenge's `clientData` carries the W3C request options
under `publicKey` (`TomWebAuthnRequestOptions` in the kernel), and enrolment's
carries the creation options the same way; the challenge itself is kept in the
encrypted half, so the client cannot choose it. The answer comes back through the
same `String` a typed code does — the authenticator's response in its W3C JSON
form, base64url, decoded by `TomWebAuthnAuthenticationResponse.fromSubmission`.

**What is verified**, following WebAuthn Level 2 §7.1 and §7.2, by
`TomWebAuthnVerifier`:

| Check | Registration | Assertion |
| ----- | ------------ | --------- |
| client data names the ceremony (`webauthn.create` / `webauthn.get`) | ✓ | ✓ |
| client data carries exactly the challenge this server issued | ✓ | ✓ |
| client data's origin is an allowed origin | ✓ | ✓ |
| authenticator data's RP id hash is SHA-256 of the RP id | ✓ | ✓ |
| user-present flag set; user-verified flag set when verification is `required` | ✓ | ✓ |
| the attested credential id is the response's id, and its COSE key is ES256 or RS256 | ✓ | |
| the signature over authenticator data and SHA-256 of the client data verifies | | ✓ |
| the signature counter rose, whenever either it or the stored one is non-zero | | ✓ |
| the user handle, when returned, is this user's | | ✓ |

A counter that does not rise means two copies of the credential exist, and the
login is refused. Synced passkeys report `0` every time, which is accepted. The
new counter is written back to the enrolment after every successful login.

**Attestation is not verified, deliberately.** The creation options request
attestation `none`, and a statement that arrives anyway is not checked.
Attestation answers *which model of authenticator* made a credential — useful
to a deployment that admits only certified hardware keys, and a certificate
trust store to maintain for everyone else. The server trusts what the credential
signs, never what it claims to be, which is what every consumer passkey provider
expects.

Each passkey is its own enrolment (`webauthn:<credential id>`), so a user may
hold one per device and any of them answers a challenge; creating a second for a
credential the user already has is excluded by the creation options. A
registration that fails any check refuses the confirmation with
`login.error.2fa.webauthn-registration-invalid`; an assertion that fails is a
wrong answer and spends an attempt, like a wrong code.

`TomWebAuthnSoftwareAuthenticator` makes real P-256 key pairs, CBOR and
signatures in memory, so a suite drives the whole mechanism without a browser.
Its private key lives in the process and its "user verification" is a flag: it
proves nothing about anyone, and is for tests and bring-up only.

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
| `login.error.2fa.challenge-already-answered` | This interim token has been answered before — a replay, or an honest double-submit | None; the answer that spent it already returned the token to continue with |
| `login.error.2fa.no-challenge` | No interim token was presented, or it carries none | None |
| `login.error.2fa.unsupported-mechanism` | No adaptor registered for the mechanism | None |
| `login.error.2fa.not-enrolled` | Nothing to challenge against: no TOTP secret resolves, or no address is on record for a delivered code | None |
| `login.error.2fa.delivery-failed` | A delivered code could not be handed to its transport, so no challenge was issued | None |
| `login.error.2fa.send-limit` | A code was sent to this address too recently; `retryAfterSeconds` says how long to wait. Nothing was sent | None |
| `login.error.2fa.no-destination` | Enrolment was begun for a delivered code with no address on record to confirm | None |
| `login.error.2fa.enrolment-code-invalid` | The confirmation code did not match the one just sent; nothing is stored | A re-issued offer, until attempts run out |
| `login.error.2fa.enrolment-offer-invalid` | The enrolment offer is unusable — no destination for a delivered code, a confirmation on a token on which nothing was begun, or a begun offer whose `enrolmentExpiresAt` claim is absent or unreadable | None |
| `login.error.2fa.webauthn-registration-invalid` | The authenticator's registration response failed a check — another challenge, origin, ceremony or RP id, an unverified user where verification is required, or a key this server cannot verify with; nothing is stored | A re-issued offer, until attempts run out |

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
| `login.error.2fa.enrolment-already-answered` | This offer token has been answered before | None; the answer that spent it already returned the token to continue with |
| `login.error.2fa.enrolment-required` | A skip was attempted on an offer the server did not mark skippable | None |

A wrong code is an ordinary outcome and yields a failed
`TomAuthenticationResult`. A *mis-wired deployment* is a `Tom2FAException`
instead, raised at registration with `clientThrow: false` so it surfaces in the
server log rather than to a caller. These three are the keys a deployment is
likeliest to meet first, because they fire at wiring time — before any user has
typed anything:

| Key | Meaning |
| --- | ------- |
| `authentication.2fa.duplicate_adaptor` | A *different* adaptor is already registered for the mechanism. Re-registering the identical instance is a no-op, so a double boot is harmless. Raised by `Tom2FARegistry.register` |
| `authentication.2fa.adaptor_instantiation_failed` | An annotated class could not be constructed: its unnamed no-argument constructor threw, or it has none |
| `authentication.2fa.adaptor_does_not_implement_service` | A class carries `@Tom2FAAdaptor` but does not implement `Tom2FAService` |

The last two are raised by the `@Tom2FAAdaptor` scan, which is all-or-nothing:
a failed `registerAnnotated` registers none of the candidates and restores the
registrations that preceded it, so a retried scan cannot collide with leftovers
from the attempt that failed. An adaptor skipped for an unmet
`Tom2FAPrerequisite` is neither of these — that is a logged warning, not a
failure, and the mechanisms that *were* wired stay registered.

### The attempt counter, and what makes it a bound

The counter lives in the token and advances only along the chain of re-issued
tokens. On its own that bounds a **cooperative** client, and gives a UI its "2
tries left". It does not bound an uncooperative one: a server holding no record
of which interim tokens it has already answered cannot tell a replay of an
*earlier* token in the chain from its original presentation, and that earlier
token is still valid and still carries its lower count. Replay pass 1's token
and the allowance is fresh every time — bounded only by how many requests fit
inside the challenge's validity, which for six digits and five minutes is not a
bound on anything.

One recorded fact closes it: *this token has been answered*. `Tom2FAAttemptStore`
holds it, and `authenticatePass2` consults it **before** asking the mechanism
anything:

```dart
abstract class Tom2FAAttemptStore {
  /// True when this token had not been answered before.
  Future<bool> spend(Tom2FAAttempt attempt);
}
```

Each token in the chain is then answerable exactly once, and since a wrong
answer is what mints the next token, the whole chain admits exactly
`attemptsAllowed` guesses however the attacker orders it. A replay is refused
with `login.error.2fa.challenge-already-answered` — including a replay of a
*correct* answer, so one interim token cannot mint two sessions. An honest
client that double-submits meets the same refusal, and should: it already holds
the re-issued token the answer gave it.

The store is keyed on a **fingerprint** of the token — `tom2FATokenFingerprint`,
a SHA-256 of the encoded string — not on the token. An attempt log is a thing a
deployment points at shared infrastructure, and one holding usable bearer
credentials would be a worse hazard than the one it closes. `Tom2FAAttempt`
also carries the username and mechanism, because the seam is where a
per-principal rate limit would go, and such a limiter has to know whose attempt
it is refusing.

**`Tom2FAMemoryAttemptStore` is installed by default, and is per process.** A
bound that has to be opted into is a bound most deployments will not have, so
the default is on; in a load-balanced cluster each node bounds only what reaches
it, so the effective allowance is the challenge's times the node count. Finite,
which is the property that matters, and a deployment that wants the exact cap
installs a store its nodes share — an insert whose unique key is the
fingerprint, with a duplicate-key error read as `false`. One that genuinely
wants the old stateless behaviour installs a store whose `spend` always answers
`true`; the choice is made by installing something, not by forking the pass.

The challenge's own short validity still bounds the chain in time on top of all
this.

Enrolment confirmation is bounded the same way and by the same store, refusing a
replay with `login.error.2fa.enrolment-already-answered`. It matters for the
mechanisms whose confirmation is a code sent out of band: an authenticator app
hands the secret to whoever holds the token, so guessing its code proves
nothing, but an emailed code is exactly as brute-forceable there as a challenge
code is here.

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
| `serviceAccountOrganization` | no | The organization the deployment logs in for; omit when it has none |
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

There is **no locale to configure**, and that absence is deliberate rather than
an omission. `TomAuthenticationMessage` carries three locale fields alongside
the identity ones, but a deployment is a process, not a device: there is no
browser to read a language from, no operator present to have a country, and its
own clock is UTC. So the self-login body sends the message type's **own
defaults** — `en`, `XX` (the ISO 3166-1 user-assigned code the kernel uses for
"none") and `utc` — and it *reads* them from that type rather than restating
them. Building the body by hand is what buys the credential its isolation, and
it costs exactly one thing: nothing otherwise keeps the body agreeing with the
type it claims to be shaped as. Three literals would have been a second copy of
the kernel's defaults, right on the day they were written and quietly stale the
day the kernel moved one.

### Lifecycle

```dart
// Only for a process with no TomServer — a worker isolate or a scheduled job
// that talks to the same capped services but serves no HTTP:
final installed = await TomServerSelfLogin.loginAndInstall(configuration);
```

`TomServer.start()` already does this for you, and the **ordering is
load-bearing**: the login runs *before* the socket is bound.
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

"Blank" in that first row means **whitespace as well as empty, for all three
required values including the credential**, and the credential is the one where
it matters most. An unsubstituted `${SERVICE_CREDENTIAL}` leaves whitespace
behind in some templating setups; read literally that is a configured deployment
with a secret, so the server takes the third row — it attempts a login, the login
is refused, and startup fails reporting a *rejected* credential. That is the
harder of the two diagnoses, because the redaction policy correctly hides the
value that would have explained it. Whitespace is a missing credential and is
reported as one.

The trim decides *whether* a credential was configured, and nothing else: the
value itself reaches the auth server exactly as written. A secret is opaque, so
if the auth server expects a trailing space then that space has to be presented,
and quietly reshaping the value would turn a correct deployment into the same
undiagnosable rejected login — the identical fault, inverted.
`TomSmtpSettings.fromConfiguration` splits the analogous `smtpPassword` the same
way.

### The principal is renewed, not installed once

The server principal caps every user's grants, so a stale one keeps capping at
yesterday's entitlements: a change made in the auth server would otherwise reach
this deployment at its next restart and not before. `loginAndInstall` therefore
schedules its own renewal, driven off the token's own `exp`:

```dart
// What TomServer.start() does for you.
await TomServerSelfLogin.loginAndInstall(configuration);

TomServerSelfLogin.installedUntil;   // when the installed session expires
TomServerSelfLogin.isRenewing;       // whether a renewal is scheduled
await TomServerSelfLogin.renewNow(); // renew now, without waiting for the lead
TomServerSelfLogin.stopRenewal();    // disarm; the principal stays installed
```

The next attempt lands one `globalSettingRenewalLead` (two minutes) before
expiry, clamped to `minimumRenewalDelay` so a session shorter than the lead —
legitimate, if the auth server issues short service tokens — schedules a prompt
attempt rather than a negative delay, and logs that it is doing so. A token
carrying no `exp` is refused (`server.selflogin.bad_token`): no principal is
built from a token that is not live, so every installed session has a deadline
to renew against. Pass `renew: false` to decline the loop, and read `installedUntil` to build your
own.

**A failed renewal keeps the principal it has.** The old cap may be stale, and a
stale cap is still a cap; dropping it would widen every user's access at the
moment the auth server became unreachable, which is exactly when widening is
least defensible. So the failure is logged — naming the staleness — the
principal stands, and another attempt is scheduled `globalSettingRenewalRetry`
later. Note the same direction in `TomServerPrincipal.clear()`: it *widens*
access, so it is never the right response to an expired token, and nothing in
the renewal path calls it.

### Failure keys

`TomServerSelfLoginException` carries `clientThrow: false` — it is an operator
signal, never surfaced to a client.

| Key | Meaning |
| --- | ------- |
| `server.selflogin.unreachable` | The auth server could not be reached. |
| `server.selflogin.rejected` | The auth server refused the credential. Only the HTTP status is reported — the body may echo the credential back. |
| `server.selflogin.bad_response` | The response was not JSON, or was JSON that is not an object. |
| `server.selflogin.no_token` | The response carried no token under any accepted name. |
| `server.selflogin.bad_token` | A token field was present but could not be turned into a principal: it was not a decodable JWT, its payload was not an object, its encrypted section would not unwrap under this deployment's key, or it is not live — expired, without an `exp`, or with a `validUntil` that disagrees with its `exp`. One key for all of them, because the operator's move is the same in each — look at what the auth server put in that field. |

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
   (browser visits the provider, user consents, provider redirects the
    browser to the application's own redirectUri page with ?code&state)
        │
POST /oauth/complete         ←  the application's page, forwarding them
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

TomBean.withType<TomOAuthProviders>(TomOAuthProviders.fromConfiguration());
TomBean.withType<TomExternalIdentityStore>(
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
      revocationEndpoint: https://oauth2.googleapis.com/revoke   # optional
      clientId: 1234.apps.googleusercontent.com
      clientSecret: ${GOOGLE_CLIENT_SECRET}
      redirectUri: https://app.example.com/oauth/callback
      scopes: openid email profile      # a list or a space-separated string
      provisioning: refuse              # a public provider; the default is autoProvision
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

**A tenant can have providers of its own.** `TomOAuthProviders.tenants` (and
`TomSamlProviders.tenants`) hold a provider set per tenant, read from
`oauth.tenants.<id>.providers` by `TomOAuthProviders.loadTenants()` or installed
at run time with `tenants.install(tenantId, set)`. `resolve()` answers the set of
the tenant in context, and the deployment's bean for a tenant without one, so a
sign-in in a tenant with its own set offers and accepts only its providers. See
[tenancy.md](tenancy.md#identity-federation-per-tenant).

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
as [`TomOAuthExchange.provider`](api/api_summary_authentication.md#tomoauthexchange);
nothing downstream resolves it again.

The identity is unaffected: `TomExternalIdentity.issuer` names the **IdP**, not
the registration, so twins assert the same identity and therefore share one row
in the linking table and one slot in the token store. That is the intended
reading — it is one Google account either way, and a user who consented through
`google-calendar` has not acquired a second local account by doing so.

### First login with no local account: `refuse`, `linkExisting` or `autoProvision`

This is a **configuration choice per provider**, never a hardcoded policy,
because each answer is correct for a different deployment:

| `provisioning` | A first external login with no linked account |
| -------------- | --------------------------------------------- |
| `autoProvision` (default) | `TomExternalIdentityDirectory.provisionFromExternalIdentity` creates the account, and the link is written to the username the *directory* settled on — not to the asserted claim, which a deployment may normalise, prefix or de-duplicate. Just-in-time provisioning, the right answer behind an enterprise identity provider. |
| `linkExisting` | Linked to an existing local account carrying the asserted username; rejected with `login.error.oauth.no-local-account` when there is none. For accounts an administrator, or SCIM, created before their owners first sign in. |
| `refuse` | Rejected with `login.error.oauth.no-local-account`. Only identities already linked are admitted — the setting for a public provider. |

`autoProvision` and `linkExisting` **link an existing local account** that
already carries the asserted username, which is how a user who signed up with a
password later adds "Sign in with …". That behaviour is deliberately gated on
the mode: on a provider configured to `refuse`, an unlinked local account under
the asserted name is precisely the case being refused — an attacker who can make
*any* provider assert an address must not thereby acquire the local account that
already uses it. For the same reason a provider that states `email_verified:
false` links no existing account (`login.error.oauth.unverified-email`).

The default is `autoProvision` because single sign-on against an enterprise
identity provider is the case this module is built for — see
[Provisioning modes](#provisioning-modes). A provider anyone can hold an account
at, such as Google or GitHub, is configured with `provisioning: refuse`.

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

  static TomExternalIdentityStore? resolve() { ... }
}
```

`unlink` **revokes the grant at the provider, then** removes the link and every
provider token held through it — the cascade is part of the contract, not the
caller's responsibility, so a user who presses *disconnect* cannot leave a live
refresh token behind. Forgetting a credential is not ending one: a copy taken
before the unlink — a log line, a backup, a compromised process — goes on
working until the provider's own lifetime runs out, and for a refresh token that
is months.

Revocation is RFC 7009 and needs the provider's `revocationEndpoint`, which is
optional configuration: a great many providers publish none, and a deployment
holding no tokens has nothing to revoke. Where it is absent, nothing is called
and nothing is logged as wrong.

**Best effort, and the deletion happens regardless.** Refusing to unlink because
the provider is unreachable would leave the deployment holding the credential it
was just told to drop, which is the opposite of what disconnect asked for. So a
failure is logged — naming what remains valid where — and the link and the local
copy go anyway.

**Every registration sharing the issuer is asked.** Two registrations against
one IdP is a shape this module supports, and the token store is keyed by issuer
rather than by registration, so which client credentials minted a grant is not
recorded. Asking all of them is what makes the revocation reliable, and costs
nothing: RFC 7009 makes a token the provider does not recognise a success. The
refresh token is what is revoked when there is one — it ends the chain, where an
access token would outlive it by minutes.

Keyed on the pair rather than on the subject alone because a subject is only
unique *within* an issuer — two providers may both call a user `12345`.

`identitiesOf` answers a **snapshot**: the list is unmodifiable and every
`TomExternalIdentityLink` in it is detached, so editing one changes nothing a
later call reports, and two calls hand back distinct instances. `link` and
`recordLogin` are how a change is written back; there is no path from a returned
row. The entity is mutable and has to be — the repository fills a blank instance
column by column — so this is the store's guarantee rather than the type's, and
it is in the contract because the two implementations would otherwise disagree
about it: a database-backed store materialises fresh rows on every read whether
it means to or not, an in-memory one aliases its own state unless it copies. A
test written against the store that aliases would pass for a reason that does
not hold in production, which is the failure worth spending a copy to avoid.

`TomPersistentExternalIdentityStore` is the production implementation over
`TomExternalIdentityLinkRepository`; `TomMemoryExternalIdentityStore` exists for
tests. There is no in-memory *default*: a link that vanishes on restart sends a
returning user through provisioning again, so a deployment that installs no
store is told what is missing rather than given a store that loses its rows.

The persistent store needs `TomExternalIdentityLink.createTableSql`, shipped as
`example/authentication/migrations/tenant/default/main/[3]-create_tom_external_identity.sql`.

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
| The `id_token` carries the `nonce` the authorization request sent (whenever the scopes include `openid`) | `oauth.flow.nonce_mismatch` |
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

`TomOAuthTokenTransport` is the one HTTP seam. `resolve()` answers the installed
bean, or `TomHttpOAuthTokenTransport` — the live implementation over
`package:http`, and a working default for the same reason the state store has
one: talking to the provider is not optional. It turns any non-2xx answer into
`oauth.provider.http_error` carrying the provider's own error body, which is the
only thing that says *why* (`invalid_grant`, `redirect_uri_mismatch`); the body
stays server-side. Stubbing the seam — which is all `oauth_test.dart` does —
leaves every other line of the flow executing exactly as it does against a real
provider.

The live transport sends through the kernel's `TomResilientClient`, under the
policy of the provider's destination (the `httpClient` key, see
[configuration.md](configuration.md#outgoing-http-calls)): a provider that does
not answer fails at the timeout instead of holding the sign-in open, and a
failing one opens its own circuit and leaves the other providers alone. Its
`GET`s — the discovery document, SAML metadata, user info — are retried; its
`POST`s to the token endpoint are not, because an authorization code is
single-use.

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
statement about *storage* and not a capability withheld.

`completeAuthorization` answers a **`TomOAuthExchange`**: a completed code
exchange, and the four things a caller needs to know about one. `identity` is
who the provider says this is; `pending` is the record the exchange consumed,
which carries the login context the session must be issued in; `provider` is the
registration it was completed against; and `tokens` is what the token endpoint
returned, or `null` when it delegated nothing. `provider` is carried rather than
re-derived because a login makes several decisions out of provider configuration
at points far enough apart that two of them could resolve differently and
disagree about which login this was — see
[Two registrations against one IdP](#two-registrations-against-one-idp).

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
TomBean.withType<TomOAuthTokenStore>(
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
| One grant per identity in a tenant | `UNIQUE KEY (tenant_id, issuer, subject)` — a second row would make which credential is presented depend on row order |
| A credential never outlives its link | `TomExternalIdentityStore.unlink` revokes at the provider, then deletes the grant *before* the link |
| A credential never outlives its usefulness | `accessTokenFor` deletes a grant it finds expired with nothing to refresh it |

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

**A grant found expired with no refresh token is deleted, not merely reported as
`null`.** It can never mint another token, so it is not a credential the
deployment holds — it is a fact about the past, and a credential store is the
wrong home for one. Leaving it would grow the table without bound, make every
later call repeat the same read for the same answer, and leave an operator
unable to tell a dead row from a live but idle one. The identity link still
records that this user once consented; a deployment that wants a *history* of
consent wants [the audit module](audit.md), not a table of unusable secrets.

A **rejected refresh is deliberately not purged**, and the contrast is the point:
a provider answering `invalid_grant` during an outage is not proof the grant is
dead, and destroying a credential a retry would have used is worse than keeping
one that is stale. That path throws `oauth.flow.token_exchange_rejected` instead,
because a provider rejecting a refresh token it issued is something an operator
needs to see rather than an empty answer a job retries forever. A grant that
declares no expiry at all is never expired, so it is never purged.

**Refreshing is not a login.** Neither method consults a
`TomAuthenticationService`, asks the 2FA policy, touches a session or produces a
principal. That separation is the point: reusing the login path to renew a
background job's calendar token would run a second-factor decision for a user who
is not present.

### Where pending authorizations live

The handshake is **two HTTP requests**, and the second one is not issued by the
client: the provider redirects the browser to the application's page, whose
`POST /oauth/complete` a load balancer routes to whichever node it likes. Whatever
`/oauth/authorize` wrote must therefore be readable by *any* node — including
one that has never heard of the flow.

`TomOAuthMemoryStateStore` keeps it in one isolate's memory, which is exactly
right for a single node and wrong for a cluster: a callback that lands on
another node fails as `oauth.flow.unknown_state`, indistinguishable from an
expired or replayed state. The symptom is a deployment where external login
works, but intermittently, and the log claims replay.

`TomSqlOAuthStateStore` puts the record in `tom_oauth_state` — the value of
`defaultOAuthStateTable`, and a framework table declared once as a
`TomFrameworkTable` by `oauthStateTable(table)` (see
[Database Migration](db_migration.md#the-frameworks-own-tables)) and so covered
by the same convergence checks as every other. `oauthStateTableDdl(table)` is
that declaration's `CREATE TABLE`, which is what `createSchema: true` issues and
what a deployment building the schema itself can print. Declaring the shape once
is what keeps the DDL, the column lists the store's statements interpolate and
the model the convergence guard compares from drifting apart; the shipped
migration under `example/authentication/migrations/` stays hand-written, because
a migration is what a DBA applies and must remain readable, and
`test/framework_schema_test.dart` fails if the two disagree. Three decisions in
the shape are worth stating outright:

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
  size. The sweep prunes by calling `purgeExpired` — the same entry point a
  deployment drives from a job of its own — so the predicate is written once and
  the two prunes cannot come to disagree about what "expired" means.
* **A flow completes only in its tenant.** A record names the tenant of the
  request that began the flow (`tenant`, `''` for none), and every read and
  the completion carry `tenant = :tenant` with the tenant in context — the
  memory store applies the same rule. A callback that reaches another tenant
  finds nothing and spends nothing. The table itself stays deployment-wide.
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
TomBean.withType<TomOAuthStateStore>(
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
| `GET` | `/oauth/providers` | The configured providers — OAuth and SAML alike — as resource keys only; no endpoint, client id or secret reaches a client |
| `POST` | `/oauth/authorize` | Begins an authorization; returns the provider URL to send the browser to, and the `state` handle |
| `POST` | `/oauth/complete` | Completes the login from the `code` and `state` the application received |

### The completion is your call, not the provider's redirect

The provider redirects a **browser**, and not to this server: a provider's
`redirectUri` names a page of *your* application — that is what every example
above configures. That page reads `code` and `state` off its own query string
and posts them to `/oauth/complete`, which answers the same
`TomAuthenticationResult` a password login answers, in a response body the front
end controls.

```text
  provider  ──302──▶  https://app.example.com/oauth/callback?code&state
                              │  (your page, your framework)
                              ▼
                      POST /oauth/complete  { code, state }
                              │
                              ▼
                      TomAuthenticationResult  → the front end's own hands
```

Nothing in this module is browser-facing, and that is a decision rather than an
omission. An endpoint the provider redirects *to* answers a browser navigation,
so the token pair would land in the address bar, in the session's history, in
the access log and in the `Referer` of whatever the page loaded next; a
cancelled authorization would render a fault body as a page. The completion was
a `GET` at `/oauth/callback` once, which invited exactly that reading — hence
the verb and the name it has now, and hence no `urlParameterMapping`: `code`
and `state` travel in a body, not in every log and proxy between your page and
this server.

What your page does with a refusal — `?error=access_denied` when the user
presses cancel — is likewise yours: it never has to reach this server, and
posting it here only buys the `oauth.callback.provider_error` key. Where the
user goes after a successful login is your decision too, which is the other
reason the framework does not own the redirect: it would have to be told.

A deployment that genuinely wants the provider to reach the server directly
writes that handler itself, in its own application, and calls this endpoint
from it.

`registerFrameworkApis()` registers the contract, so a router resolves it
without the application registering anything.

A SAML provider adds two endpoints of its own, `POST /saml/acs` and
`GET /saml/metadata/<providerId>` — see
[Single sign-on with enterprise identity providers](#single-sign-on-with-enterprise-identity-providers).

### Failure keys

| Key | Meaning |
| --- | ------- |
| `oauth.config.missing_value` · `oauth.config.not_a_map` · `oauth.config.provider_not_a_map` · `oauth.config.unknown_provisioning` · `oauth.config.invalid_clock_skew` · `oauth.config.invalid_role_mapping` | The `oauth.providers` block is malformed. Startup-time. |
| `oauth.config.discovery_not_loaded` · `oauth.config.discovery_failed` · `oauth.config.discovery_issuer_mismatch` | A `discovery: true` provider was read without fetching its document, the document could not be read, or it names another issuer. Startup-time. |
| `oauth.config.duplicate_provider_id` | One id is configured as both an OAuth and a SAML provider. |
| `oauth.config.tenants_not_a_map` · `saml.config.tenants_not_a_map` | The `oauth.tenants` or `saml.tenants` block, or one tenant's entry in it, is not a map. Startup-time. |
| `oauth.config.parameters_not_a_map` · `oauth.config.parameter_not_a_scalar` | A provider's `authorizationParameters` is not a map, or one of its values is a map or list where a query parameter can only carry a scalar. Startup-time — stringifying `{a: b}` into the redirect would surface later as a provider error whose text says nothing about the YAML that caused it. |
| `oauth.config.unknown_provider` | A request named a provider that is not configured. |
| `oauth.config.state_store_not_a_map` · `oauth.config.unknown_state_store` · `oauth.config.missing_state_store_datasource` · `oauth.config.invalid_state_store_ttl` | The `oauth.stateStore` block is malformed. Startup-time, and never defaulted away. |
| `oauth.state_store.unknown_datasource` | The SQL state store names a data source that is not registered. Startup-time. |
| `oauth.callback.unknown_state` · `oauth.flow.unknown_state` | The state handle is unknown, expired, already used, or of a flow begun in another tenant — raised by the endpoint and by the flow respectively. |
| `oauth.callback.provider_error` | The provider itself refused (e.g. the user pressed cancel). |
| `oauth.flow.missing_code` · `oauth.flow.token_exchange_rejected` | The redirect carried no code, or the token endpoint refused the exchange. |
| `oauth.flow.revocation_rejected` | The provider refused to revoke a grant. Raised by `TomOAuthFlow.revokeGrant`; `unlink` catches it, logs it and deletes anyway. |
| `oauth.flow.issuer_mismatch` · `oauth.flow.audience_mismatch` · `oauth.flow.missing_subject` · `oauth.flow.malformed_id_token` | The claims failed verification. |
| `oauth.flow.missing_expiry` · `oauth.flow.id_token_expired` · `oauth.flow.id_token_not_yet_valid` | The `id_token` is outside its own validity window, or carries none. Read against the provider's `clockSkewSeconds`. |
| `oauth.flow.nonce_mismatch` | The `id_token` does not carry the nonce this flow sent. |
| `oauth.flow.no_claims_source` · `oauth.flow.no_access_token` | The provider returned neither an `id_token` nor a usable `userInfoEndpoint` call. |
| `oauth.flow.no_refresh_token` | `refreshGrant` was given a grant that carries none. Not a login failure at all: the caller cannot recover by retrying, and must send the user through consent again — a different action, not a slower one. |
| `oauth.provider.http_error` · `oauth.provider.malformed_json` | The provider's HTTP call failed or answered with something that is not a JSON object. |
| `login.error.oauth.no-local-account` | Authenticated, but unlinked, and the provider's mode provisions no account (`refuse`, or `linkExisting` with no account under the asserted username). |
| `login.error.oauth.unverified-email` | The asserted username names an existing account, and the provider reports the address unverified, so the account is not linked. |
| `login.error.oauth.linked-account-missing` | The link outlived the account it pointed at. |
| `login.error.oauth.provisioning-unsupported` | `autoProvision` is configured but the directory does not implement it. |
| `login.error.oauth.no-identity-store` | No `TomExternalIdentityStore` is installed. |
| `login.error.oauth.credential-not-supported` | A non-OAuth credential arrived and there is no `delegate`. |
| `login.error.oauth.tenant-missing` · `login.error.oauth.organization-missing` | The provider configures `tenantClaim` or `organizationClaim` and the token or assertion does not carry it. |
| `login.error.oauth.tenant-invalid` | The token names a tenant that is not a tenant id. |
| `login.error.tenant-mismatch` | The token names another tenant than the one the request resolved to; refused before any account is linked or provisioned. |

## Single sign-on with enterprise identity providers

An enterprise identity provider — Microsoft Entra ID, Okta, Keycloak, ADFS,
Google Workspace — is reached over one of two protocols: OpenID Connect, which is
the OAuth flow above with an `id_token`, or SAML 2.0. Both end in the same place.
`TomOAuthProviderConfig` and `TomSamlProviderConfig` both implement
`TomExternalProvider` — an id, an issuer, a provisioning mode, a role mapping and
a clock skew — and everything from "the provider has said who this is" onwards
is written against that type: the linking table, provisioning, the mapped roles,
the second factor and the token pair. A login page lists both kinds from
`GET /oauth/providers` and drives both through `POST /oauth/authorize` and
`POST /oauth/complete`; provider ids are one namespace across the two protocols,
and an id configured under both fails with `oauth.config.duplicate_provider_id`.

### Wiring it up at start-up

An OpenID Connect provider that names only its issuer, and a SAML provider that
names only its metadata address, are completed from documents the identity
provider publishes. Reading those is network I/O, so it happens once, at
start-up, through the asynchronous loaders, and the result is installed as a
bean:

```dart
TomBean.withType<TomOAuthProviders>(await TomOAuthProviders.load());
TomBean.withType<TomSamlProviders>(await TomSamlProviders.load());

TomAuthenticationServer.globalSettingUserAuthenticationService =
    TomOAuthAuthenticationService(
      directory: MyExternalIdentityDirectory(),
      delegate: TomAuthenticationServer.globalSettingUserAuthenticationService,
    );
TomBean.withType<TomExternalIdentityStore>(
  TomPersistentExternalIdentityStore(TomExternalIdentityLinkRepository()),
);
```

A document that cannot be fetched, or that describes another issuer than the one
configured, stops the start — that is when an operator is watching. The
synchronous readers (`TomOAuthProviders.fromConfiguration`,
`TomSamlProviders.fromConfiguration`) fetch nothing, and refuse a provider that
depends on a document with `oauth.config.discovery_not_loaded` or
`saml.config.metadata_not_loaded`, naming the loader to use.

`TomOAuthFlow.fromBeans` picks both sets up and shares one pending-authorization
store between them, so a cluster that set `oauth.stateStore.type: sql` (see
[Where pending authorizations live](#where-pending-authorizations-live)) shares
SAML logins across nodes too. `TomSamlServer` is a component, so its two
endpoints are mounted without registration.

### OpenID Connect: Entra ID, Okta, Keycloak

With `discovery: true` a provider names its issuer and its client, and the
endpoints are read from `<issuer>/.well-known/openid-configuration`, the
address OpenID Connect Discovery 1.0 defines — or from `discoveryUrl` when the
provider publishes the document elsewhere. The document supplies
`authorizationEndpoint`, `tokenEndpoint`, `userInfoEndpoint` and
`revocationEndpoint`; any of them
configured explicitly wins.

```yaml
oauth:
  providers:
    entra:
      issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
      discovery: true
      clientId: ${ENTRA_CLIENT_ID}
      clientSecret: ${ENTRA_CLIENT_SECRET}
      redirectUri: https://app.example.com/sso/callback
      usernameClaim: preferred_username
      groupsClaim: roles               # app roles; see below
      roleMapping:
        Tom.Admin: [tom.admin]
    okta:
      issuer: https://<org>.okta.com/oauth2/default
      discovery: true
      clientId: ${OKTA_CLIENT_ID}
      clientSecret: ${OKTA_CLIENT_SECRET}
      redirectUri: https://app.example.com/sso/callback
      scopes: openid email profile groups
      roleMapping:
        tom-admins: [tom.admin]
    keycloak:
      issuer: https://login.example.com/realms/<realm>
      discovery: true
      clientId: tom-console
      clientSecret: ${KEYCLOAK_CLIENT_SECRET}
      redirectUri: https://app.example.com/sso/callback
      defaultRoles: [employee]
      roleMapping:
        admins: [tom.admin]
        staff: [tom.user, tom.reporting]
```

The document's `issuer` must equal the configured one exactly, as OpenID
Connect Discovery 1.0 requires.
A document published for a different issuer would send this deployment's users,
and its client secret, to endpoints nobody configured, so a mismatch fails the
start with `oauth.config.discovery_issuer_mismatch`.

What each provider needs on its own side:

| Provider | Issuer | Groups |
| -------- | ------ | ------ |
| Microsoft Entra ID | `https://login.microsoftonline.com/<tenant>/v2.0`. Name the tenant by its id: the discovery document states the issuer with the tenant id, and a tenant *domain* in the configured issuer does not match it. | The `groups` claim carries group **object ids** (GUIDs), not names, unless the app registration is configured otherwise — so a `roleMapping` keyed by names matches nothing. App roles, assigned in the enterprise application and sent in the `roles` claim, are names the deployment chooses; `groupsClaim: roles` reads them. Entra sends no `email_verified`. |
| Okta | `https://<org>.okta.com/oauth2/default` — the issuer of the authorization server, not the bare org URL. | Add a `groups` claim to the authorization server, with the filter that selects the groups to send. |
| Keycloak | `https://<host>/realms/<realm>`. | A *Group Membership* mapper on the client, claim `groups`, with *Full group path* off so the claim carries `admins` rather than `/admins`. Realm roles need no mapper: `groupsClaim: realm_access.roles`. |

Register `redirectUri` — your application's page — as the client's redirect URI,
and request the `openid` scope, which is in the default scope set.

### SAML 2.0 identity providers

SAML providers are read from `saml.providers`, one map per identity provider.
Most identity providers publish their entity id, single sign-on address and
signing certificates as a metadata document, so the shortest configuration names
that document and this server's own side:

```yaml
saml:
  providers:
    corporate-saml:
      metadataUrl: https://login.example.com/realms/staff/protocol/saml/descriptor
      spEntityId: https://app.example.com/saml
      acsUrl: https://app.example.com/saml/acs
      redirectUri: https://app.example.com/sso/callback
      nameIdFormat: urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
      usernameAttribute: email
      displayNameAttribute: displayName
      spSigningKeyFile: /etc/tom/saml-sp.key.pem
      spCertificateFile: /etc/tom/saml-sp.cert.pem
      groupsClaim: groups
      roleMapping:
        admins: [tom.admin]
```

Without metadata, the identity provider's side is configured directly — `issuer`
(its entity id), `ssoUrl` (its HTTP-Redirect single sign-on service) and
`idpCertificates` (its signing certificates, PEM or bare base64, one or a list)
or `idpCertificateFiles`. A value configured explicitly wins over the metadata's;
an `issuer` that disagrees with the metadata's entity id fails with
`saml.config.metadata_issuer_mismatch`. The metadata is trusted because of where
it was fetched from, so `metadataUrl` must be an `https` address.

| Key | Meaning |
| --- | ------- |
| `metadataUrl` | The identity provider's metadata document, fetched by `TomSamlProviders.load`. |
| `issuer` · `ssoUrl` · `idpCertificates` · `idpCertificateFiles` | The identity provider's side, when there is no metadata or to override it. Several certificates verify side by side, for a key rotation. |
| `spEntityId` | This server's entity id: the audience every assertion must name. Required. |
| `acsUrl` | The public address of this server's `POST /saml/acs`. Required. |
| `redirectUri` | The application's page the browser is sent to afterwards. Required. |
| `nameIdFormat` | The `NameIDPolicy` format requested; omitted, the identity provider chooses. |
| `subjectAttribute` | An attribute holding the stable subject, instead of the `NameID`. |
| `usernameAttribute` · `displayNameAttribute` | Attributes the local username and the display name are read from; without `usernameAttribute` the username is the subject. |
| `requireSignedAssertion` | `true` to refuse a response whose assertion is not itself signed. |
| `spSigningKeyFile` · `spCertificateFile` | This server's RSA key (PEM) to sign `AuthnRequest`s with, and its certificate, published in its metadata. Both optional. |
| `provisioning` · `groupsClaim` · `defaultRoles` · `roleMapping` · `clockSkewSeconds` · `displayNameKey` · `iconKey` | As for an OpenID Connect provider. |

**Choose the `NameID` format deliberately.** The subject — the `NameID`, or
`subjectAttribute` — is half of the key the identity is linked under, so it must
be stable. Ask for a persistent format, or for an email address or username the
directory does not reuse. A transient `NameID` changes on every login, and an
identity whose subject changes is a new identity each time: under
`autoProvision` it provisions a new account on every login.

### What to register at the identity provider

The identity provider is configured from this server's metadata, served for each
provider at `GET /saml/metadata/<providerId>` as `application/samlmetadata+xml`.
Most identity providers import it from the URL; what it carries is:

| Item | Value |
| ---- | ----- |
| Entity id (audience) | `spEntityId` |
| Assertion consumer service | `acsUrl`, HTTP-POST binding |
| Signing certificate | `spCertificateFile`, when configured — and the metadata states `AuthnRequestsSigned="true"` when `spSigningKeyFile` is |
| `NameID` format | `nameIdFormat`, when configured |
| Assertions signed | `WantAssertionsSigned` follows `requireSignedAssertion` |

At the identity provider, sign the response or the assertion (or both) with
RSA-SHA256 or RSA-SHA512 and exclusive canonicalization — the defaults of every
current identity provider — and send the groups as an attribute. Do **not**
enable assertion encryption: an encrypted assertion is refused.

### Claim mapping: groups to roles

Every provider of either protocol carries a `TomExternalRoleMapping`:

```yaml
groupsClaim: groups            # a claim, attribute or dotted path
defaultRoles: [employee]       # every login from this provider
roleMapping:
  admins: [tom.admin]          # external group -> Tom roles
  staff: [tom.user, tom.reporting]
```

| Key | Meaning |
| --- | ------- |
| `groupsClaim` | The claim (OIDC) or attribute (SAML) carrying the user's groups; `groups` when unset. A dotted path reaches into a nested claim (`realm_access.roles`); a claim whose own name contains a dot (`https://example.com/groups`) is found before the path is split. |
| `roleMapping` | External group → the Tom roles it grants; a single role may be written without a list. |
| `defaultRoles` | Roles every login from this provider receives. |

The groups are read as the provider sends them: a list, a single string — which
is one group and is never split on commas — or nothing. A SAML attribute that
arrives as several `Attribute` elements, one per value, as Keycloak sends it,
contributes every value. Groups the mapping does not name grant nothing: an
identity provider asserts dozens of groups, most about mailing lists, and a group
nobody mapped is not a permission. A `roleMapping` that is not a map of group to
role list fails the start with `oauth.config.invalid_role_mapping`, because a
mistyped security setting must not grant nothing quietly.

**The mapping is applied per login and persisted nowhere.** The roles are
recomputed from the claims on every login and added to that session's principal
beside the roles the local account holds (`applyExternalRoles`), before the
access-control definition completes the principal's rights — so a mapped role
brings everything the definition derives from it. The provider is the authority
for the roles it maps: a user removed from a group at the identity provider loses
the mapped role at their next login. The framework does not write to the
deployment's user store, which it does not own; a deployment that wants the
mapped roles stored reads them off `TomExternalIdentity.roles` in
`provisionFromExternalIdentity`.

### Claim mapping: tenant and organization

A provider that is itself a Tom identity provider — Tom UAM, for the Tom
applications that sign their users in through it — names the user's tenant and
sign-in organization in its tokens. Every provider of either protocol carries a
`TomExternalTenancyMapping` that reads them:

```yaml
tenantClaim: tenant                    # a claim, attribute or dotted path
organizationClaim: organization
organizationParameter: organization    # OIDC only: sent with the authorization request
```

| Key | Meaning |
| --- | ------- |
| `tenantClaim` | The claim (OIDC) or attribute (SAML) naming the tenant. The principal is placed in that tenant. A sign-in whose request resolved to another tenant is refused with `login.error.tenant-mismatch` **before** any account is linked or provisioned — a token for one tenant is not a pass to another. |
| `organizationClaim` | The claim or attribute naming the sign-in organization. It becomes the login's organization before the directory is asked for the account, and the principal's organization: the identity provider decides the sign-in organization from the user's memberships, whatever organization the login asked for. |
| `organizationParameter` | The OIDC authorization-request parameter the organization the login asked for is sent under. Signing in for another organization is a new authorization naming it; a provider that still holds the user's session issues the new token without asking for credentials again. SAML has no counterpart. |

A configured claim is required: a token without it is refused
(`login.error.oauth.tenant-missing`, `login.error.oauth.organization-missing`),
and a tenant that is not a tenant id is refused
(`login.error.oauth.tenant-invalid`). An identity provider that is the authority
for tenant and organization does not leave them out, and a session that fell back
to a default would carry the rights of the wrong one. A provider configuring
neither claim leaves the tenant to the request and the organization to the
login. See [tenancy.md](tenancy.md#identity-federation-per-tenant).

### Provisioning modes

`provisioning` decides what a successful login does when no local account is
linked to the identity. The same three modes apply to both protocols:

| `provisioning` | An identity with no linked account |
| -------------- | ---------------------------------- |
| `autoProvision` (default) | Linked to the existing account carrying the asserted username, or provisioned through `TomExternalIdentityDirectory.provisionFromExternalIdentity`. Just-in-time provisioning: the identity provider is the account register. |
| `linkExisting` | Linked to the existing account carrying the asserted username; refused with `login.error.oauth.no-local-account` when there is none. For accounts created elsewhere — by an administrator, or pushed by SCIM — before their owners first sign in. |
| `refuse` | Refused with `login.error.oauth.no-local-account`. Only identities already linked are admitted. |

`autoProvision` is the default because single sign-on against an enterprise
identity provider is the case this module is built for, and there an employee
the identity provider authenticates is an employee. **A deployment offering a
public provider** — anyone with a Google or GitHub account can authenticate —
**sets `provisioning: refuse` for it**, or `linkExisting` where the asserted
address is trustworthy.

### The SAML flow has three legs

A SAML login is service-provider initiated and runs through the same two calls
as an OpenID Connect login, with one leg the protocol adds in between:

```text
POST /oauth/authorize { providerId }   →  TomSamlFlow.beginAuthorization
        │   stores a pending record whose nonce is the AuthnRequest's ID;
        │   answers the IdP's SSO address + SAMLRequest + RelayState (+ Signature)
        ▼
   (browser at the identity provider; the user signs in)
        │
POST /saml/acs  SAMLResponse, RelayState  →  TomSamlFlow.acceptResponse
        │   spends the pending record, verifies the response, stores the
        │   verified identity under the same handle with the digest of a
        │   fresh one-time code
        ▼
303  https://app.example.com/sso/callback?code&state
        │   (your page, exactly as for an OpenID Connect provider)
        ▼
POST /oauth/complete { code, state }   →  TomSamlFlow.completeAuthorization
        │   checks the code, hands the verified identity to the login
        ▼
TomOAuthAuthenticationService → _completeLogin → the token pair
```

The third leg exists because the identity provider's response arrives as a
**browser form post**, and the answer to a browser form post can only be a page:
a token pair returned there would land in the browser's history and the access
log. The handoff keeps the rule [the OAuth completion](#the-completion-is-your-call-not-the-providers-redirect)
follows — tokens travel only in the body of the application's own call — and lets
a login page treat every provider alike. The code is single-use, its digest is
what is stored, and it is compared in constant time.

A response the validator refuses sends the browser to the same page with
`error=access_denied`, `error_description=<key>` and `state` — the shape an
OAuth provider's refusal takes — and the reason is logged on the server. A post
whose `RelayState` names no pending SAML login answers `400`
(`saml.acs.unknown_state`): there is no page to send the browser to.

Only service-provider-initiated login is supported. An **unsolicited
(identity-provider-initiated) response** carries no `InResponseTo` linking it to
a request this server sent, and is refused; a deployment that offers the login
from the identity provider's portal configures the portal tile to start at the
application's login page instead.

### What a SAML response must be

`TomSamlResponseValidator` refuses a response, with its own key, unless every
one of these holds:

| Requirement | Refused with |
| ----------- | ------------ |
| Base64, at most a megabyte decoded, XML, and a `samlp:Response` | `saml.response.malformed` |
| No document type declaration | `saml.response.doctype` |
| `Destination`, when present, is this server's `acsUrl` | `saml.response.wrong_destination` |
| `InResponseTo` names the request this login sent | `saml.response.wrong_request` |
| The response and the assertion are issued by the configured entity | `saml.response.wrong_issuer` |
| The status is `Success` | `saml.response.status_not_success` |
| The assertion is not encrypted | `saml.response.encrypted_unsupported` |
| Exactly one assertion | `saml.response.assertion_count` |
| The response or the assertion is signed, and every signature present verifies | `saml.signature.*` |
| The assertion is signed, when `requireSignedAssertion` | `saml.assertion.unsigned` |
| A subject — the `NameID` or `subjectAttribute` | `saml.assertion.missing_subject` |
| A bearer `SubjectConfirmation` for `acsUrl`, this request, and the present moment | `saml.assertion.no_bearer_confirmation` |
| Inside the `Conditions` validity window, within the clock skew | `saml.assertion.not_yet_valid` · `saml.assertion.expired` |
| An `AudienceRestriction` admitting `spEntityId` | `saml.assertion.wrong_audience` |

The pending record is spent when the response arrives, so a response posted twice
finds nothing the second time, and `InResponseTo` binds the response to this
user's request, so a response captured from another user's flow cannot complete
this one.

### Security notes

* **The OpenID Connect nonce.** Whenever the scopes include `openid`, the
  authorization request carries a fresh `nonce`, stored with the pending record,
  and the `id_token` must carry it back (OIDC Core §3.1.3.7) or the login fails
  with `oauth.flow.nonce_mismatch`. `state` protects the redirect; the nonce binds
  the token to this flow rather than to any flow at this client.
* **`email_verified`.** Linking an identity to an *existing* account by its
  asserted address is refused with `login.error.oauth.unverified-email` when the
  provider states `email_verified: false`: linking on it would hand the account
  to whoever typed that address into the provider's sign-up form. An absent claim
  is not `false` — SAML identity providers and Entra ID send none, and their
  directories are the organisation's own.
* **The signature profile.** Exactly what identity providers use and nothing
  wider: exclusive canonicalization, RSA PKCS#1 v1.5 with SHA-256 or SHA-512, one
  reference to the signed element's `ID`, the enveloped-signature transform, a
  SHA-256 or SHA-512 digest. SHA-1 is refused for the signature and the digest.
* **`KeyInfo` is ignored.** A signature verifies against the identity provider's
  certificates as configured, never against a key the document encloses —
  otherwise anyone could sign a response with their own key and attach it.
* **Signature wrapping.** A signature is checked on the element it is a direct
  child of; its one reference must name that element's `ID`, which must be unique
  in the document; and the assertion is read only from the element that was
  verified, never found by searching the document. Moving a validly signed
  assertion aside and planting an unsigned one where a careless reader looks
  therefore fails.
* **No document type declarations.** A response or a metadata document that
  declares one is refused before it is parsed — the vector for entity expansion,
  and never part of SAML.

### The interoperability suite

`test/sso_keycloak_test.dart` (tag `sso`) logs in against a real Keycloak 26
over OpenID Connect and over SAML 2.0 — once with a signed response to a signed
request, once with a signed assertion — driving the browser's part the way a
browser does, and completes each login through the framework's own path. It
skips itself when no Keycloak is listening, so the default run stays green.
`tool/run_sso_tests.sh` starts one from `docker-compose.sso.yaml` on host port
8089, with the realm in `test/fixtures/keycloak/tom-realm.json`, runs the tagged
tests, and tears it down:

```bash
tool/run_sso_tests.sh
```

### SAML failure keys

| Key | Meaning |
| --- | ------- |
| `saml.config.not_a_map` · `saml.config.provider_not_a_map` · `saml.config.missing_value` | The `saml.providers` block is malformed. Startup-time. |
| `saml.config.metadata_not_loaded` | A provider takes a value from its metadata and was read without fetching it; use `TomSamlProviders.load`. |
| `saml.config.metadata_failed` · `saml.config.malformed_metadata` · `saml.config.metadata_issuer_mismatch` | The metadata could not be fetched, is not an identity-provider `EntityDescriptor`, or describes another entity. Startup-time. |
| `saml.config.no_idp_certificate` · `saml.config.unreadable_certificate` · `saml.config.unreadable_key` · `saml.config.unreadable_file` | No signing certificate is configured, or a certificate, key or file cannot be read. Startup-time. |
| `saml.config.unknown_provider` | A request named a SAML provider that is not configured. |
| `saml.acs.unknown_state` | A response's `RelayState` names no pending SAML login — unknown, expired or already used. |
| `saml.flow.not_asserted` · `saml.flow.handoff_mismatch` | The application completed before the identity provider answered, or with another code than the one issued. |
| `saml.response.*` · `saml.assertion.*` | The response was refused — see [What a SAML response must be](#what-a-saml-response-must-be). Reported to the application's page as `error_description`. |
| `saml.signature.missing` · `saml.signature.ambiguous` · `saml.signature.malformed` · `saml.signature.unsupported_algorithm` · `saml.signature.wrong_reference` · `saml.signature.digest_mismatch` · `saml.signature.invalid` | A signature is absent, doubled, malformed, outside the accepted profile, referencing another element, over changed content, or not by a configured key. |
| `saml.xml.unbound_prefix` | The XML uses a namespace prefix it never declares, so it cannot be canonicalised. |
| `saml.response.malformed` · `saml.response.doctype` · `saml.response.wrong_destination` · `saml.response.wrong_request` · `saml.response.wrong_issuer` · `saml.response.status_not_success` · `saml.response.encrypted_unsupported` · `saml.response.assertion_count` | The response itself was refused. |
| `saml.assertion.unsigned` · `saml.assertion.missing_subject` · `saml.assertion.no_bearer_confirmation` · `saml.assertion.not_yet_valid` · `saml.assertion.expired` · `saml.assertion.wrong_audience` | The assertion was refused. |

## User provisioning with SCIM 2.0

Single sign-on answers *who is signing in*; provisioning answers *who has an
account at all*. Over SCIM 2.0 (RFC 7643 and RFC 7644) the identity provider
becomes the register of accounts: it creates users before their owners first
sign in, keeps their attributes and group memberships current, and deactivates
or deletes them when they leave. The module is the service-provider side —
the endpoints Microsoft Entra ID, Okta and any other SCIM client call — in
three layers:

| Layer | Types | What it does |
| ----- | ----- | ------------ |
| Resources and store | `TomScimResource`, `TomScimStore`, `TomMemoryScimStore`, `TomSqlScimStore` | Users and groups kept as the JSON document the identity provider sent, minus what the service owns (`id`, `meta`, a user's `groups`) |
| Service | `TomScimService`, `TomScimFilter`, `TomScimPath` | Create, read, query, replace, patch and delete, independent of HTTP — and the access consequences of every change |
| HTTP | `TomScimProvisioning`, `TomScimApi`, `TomScimServer` | The endpoints under `/scim/v2/`, the bearer secret that admits the identity provider, and the `application/scim+json` wire format |

`TomScimIdentityDirectory` joins provisioning to single sign-on: a login
resolves to the provisioned account, with roles taken from its groups.

### Enabling SCIM

Nothing is served until a deployment installs a `TomScimProvisioning` at
start-up — before that every SCIM path answers `404` with
`scim.not_enabled`. `TomScimServer` is a component, so its endpoints are
mounted by the endpoints pipeline like every other; installing the
provisioning is what switches them on:

```dart
final store = TomSqlScimStore.named('main', createSchema: false);

TomScimProvisioning.install(
  TomScimProvisioning.fromConfiguration(TomScimService(store)),
);
```

`fromConfiguration` reads the `scim` block of the server configuration:

```yaml
scim:
  bearerTokens:
    - ${SCIM_TOKEN_ENTRA}     # one per identity provider; several during a rotation
  baseUrl: https://app.example.com/scim/v2   # behind a proxy; optional
```

| Key | Meaning |
| --- | ------- |
| `scim.bearerTokens` | The secrets an identity provider may present on a request outside every tenant — a list, or a single string. At least one secret, here or for a tenant, is required: `fromConfiguration` throws `scim.not_enabled` when none is configured, because an endpoint that admits nobody is a configuration mistake worth stopping the start for. |
| `scim.tenants.<id>.bearerTokens` | The secrets of one tenant's identity provider. A request that resolves to the tenant is admitted only by these — not by another tenant's and not by the deployment's — so no single secret writes into every tenant. |
| `scim.baseUrl` | The address resources are published under (`meta.location`, `$ref`, the `Location` header). By default, the address the request arrived at — set it when a proxy rewrites the host or path. |

The secrets are held only as SHA-256 digests and a presented secret is
compared against every one of them in constant time, so a rotation is two
entries for as long as the identity provider takes to switch. A request
without a configured secret is answered `401` with
`WWW-Authenticate: Bearer realm="scim"` and `scim.unauthorized`.

In a multi-tenant deployment the resources follow the tenant too:
`TomSqlScimStore.named` reaches the table of the tenant in context and reads only
its rows, and `TomMemoryScimStore` keeps a partition per tenant. Two tenants'
identity providers each see only their own users and groups, and the same
`userName` in two tenants is two users. See
[tenancy.md](tenancy.md#identity-federation-per-tenant).

Installing also claims `/scim/v2/` in `TomEndpointCredentials` (see
[server](server.md#endpoint-owned-credentials)). The identity provider's
secret is not a token of this deployment, and the framework's bearer
middleware would otherwise verify it as a JWT, refuse it, and log a refused
credential on every call; for a claimed path it leaves the header to the
endpoint. `TomScimProvisioning.reset()` uninstalls and releases the claim.

### Configuring Entra ID and Okta

At the identity provider, provisioning is configured with two values and a set
of attribute mappings:

| Setting | Value |
| ------- | ----- |
| Tenant URL (Entra ID) / SCIM connector base URL (Okta) | `https://<host>/scim/v2` |
| Secret token (Entra ID) / API token, authentication mode *HTTP Header* (Okta) | One of the `scim.bearerTokens`, or of the tenant's `scim.tenants.<id>.bearerTokens` |
| Unique identifier field (Okta) | `userName` |

The attribute mappings the service relies on:

| SCIM attribute | Typical source | Used for |
| -------------- | -------------- | -------- |
| `userName` | Entra ID `userPrincipalName`; Okta username | The account's name — unique, compared case-insensitively, and the username a login resolves |
| `active` | Entra ID `Switch([IsSoftDeleted], …)`; Okta's deactivation | Deactivation — see [Deprovisioning revokes access](#deprovisioning-revokes-access) |
| `emails[type eq "work"].value` | `mail` / primary email | The account's email; the `primary` one, or the first |
| `name.givenName` · `name.familyName` | `givenName` · `surname` | The account's first and last name |
| `externalId` | Entra ID `objectId`; Okta's user id | The identity provider's own id, kept for its reconciliation |
| `displayName` (groups) | The group's name | The name a role mapping is keyed on |
| `members` (groups) | Group membership | The roles a login receives |

Every other attribute an identity provider maps — `title`, `phoneNumbers`,
the enterprise extension's `department` or `manager` — is kept in the
resource's document and returned as sent, which is what the identity
provider's own reconciliation reads back. For groups, enable group
provisioning (Entra ID: *Provision Microsoft Entra ID Groups*; Okta: *Push
Groups*): a group's membership is what the roles of its members come from.

Before creating a user, both identity providers query for it —
`GET /scim/v2/Users?filter=userName eq "…"` — and create it only when the
query finds nothing. That query is answered by one lookup in the store rather
than a scan.

### The SCIM endpoints

All under `/scim/v2`, all `@TomPublicAccess` to the framework and
authenticated by `TomScimServer` against the installed secrets, all answered
in `application/scim+json`:

| Method | Path | Answer |
| ------ | ---- | ------ |
| `GET` | `/ServiceProviderConfig` | What is supported — see below |
| `GET` | `/ResourceTypes` | `User` and `Group`, as a list response |
| `GET` | `/ResourceTypes/<name>` | One resource type |
| `GET` | `/Schemas` | The `User` and `Group` schemas, as a list response |
| `GET` | `/Schemas/<schemaId>` | One schema, by its URN |
| `GET` | `/Users` | A page of users matching `filter` |
| `POST` | `/Users` | `201` with the created user and a `Location` header |
| `GET` | `/Users/<id>` | One user; `404` for an unknown id |
| `PUT` | `/Users/<id>` | The user, replaced |
| `PATCH` | `/Users/<id>` | The user, with the operations applied |
| `DELETE` | `/Users/<id>` | `204` |
| `GET` | `/Groups` | A page of groups matching `filter` |
| `POST` | `/Groups` | `201` with the created group and a `Location` header |
| `GET` | `/Groups/<id>` | One group |
| `PUT` | `/Groups/<id>` | The group, replaced |
| `PATCH` | `/Groups/<id>` | The group, with the operations applied |
| `DELETE` | `/Groups/<id>` | `204` |

A user's representation carries `groups` — every group it is a member of, as
`value`, `display`, `$ref` and `type: direct` — derived from the groups and
read-only. A group's `members` carry a `$ref` to the member. Every resource
carries `meta` with `resourceType`, `created`, `lastModified`, `location` and
`version` (`W/"<n>"`, counting the changes).

### What is supported

The subset identity providers use, which is what their own validators exercise:

| Feature | Supported |
| ------- | --------- |
| Users and groups | Create, read, query, replace (`PUT`), patch, delete |
| Filtering | `eq` `ne` `co` `sw` `ew` `gt` `ge` `lt` `le` `pr`; `and`, `or`, `not ( … )`, parentheses; `attr.sub`, a schema-URN prefix, and value filters `attr[filter]` |
| Paging | `startIndex` (1-based) and `count` — `100` when a query names none, at most `200` (`filter.maxResults`) |
| Projection | `attributes` and `excludedAttributes`; `schemas`, `id` and `meta` are always returned |
| Discovery | `ServiceProviderConfig`, `ResourceTypes`, `Schemas` |
| Uniqueness | `userName` among users and `displayName` among groups, case-insensitively — a second one is `409` `uniqueness` |
| Enterprise extension | Kept and patched; advertised as an optional extension of `User` |

Attribute names are case-insensitive, and so is string comparison, except for
the attributes SCIM defines as case-exact — `id`, `externalId` and the `value`
of a member or group reference.

**Not supported, and said so in `ServiceProviderConfig`:** bulk operations,
sorting, ETags (`meta.version` is published, `If-Match` is not honoured),
`/Me`, `POST …/.search`, and changing passwords. The identity providers that
are the target do not use them; a client that does reads the configuration and
does not ask.

### PATCH forms accepted

RFC 7644 PATCH is written loosely by identity providers, and the service
accepts the forms they send:

- **Operation names in any case** — `Add`, `Replace`, `Remove` as Entra ID
  writes them, `add` as Okta does.
- **`active` as the string `"False"` or `"True"`** — Entra ID has sent the
  boolean as a string; any other non-boolean `active` is `scim.invalid_value`.
- **An operation without a `path`**, whose value is an object of attributes —
  including an extension object keyed by its schema URN, whose attributes are
  applied under the extension.
- **Sub-attribute paths** — `name.givenName`.
- **Schema-qualified paths** —
  `urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:department`.
- **Value-filtered paths** — `emails[type eq "work"].value`. When no element
  matches an `eq` filter on `add` or `replace`, the element the filter
  describes is created, which is what an identity provider sending this form
  for a user with no work email expects; for any other filter that matches
  nothing the operation is `scim.no_target`.
- **Membership changes** in all three shapes: `add` on `members` with a list of
  `{value}`, `remove` on `members` with a list of `{value}` (Entra ID), and
  `remove` on `members[value eq "<id>"]` (Okta). Adding a member already present
  adds nothing.

```json
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [
    {"op": "Replace", "path": "active", "value": "False"},
    {"op": "Add", "path": "emails[type eq \"work\"].value", "value": "ada@example.com"},
    {"op": "Remove", "path": "members", "value": [{"value": "17"}]}
  ]
}
```

What is refused: an attribute the service owns (`id`, `meta`, `schemas`, a
user's `groups`) is `scim.mutability`; a `remove` without a path is
`scim.no_target`; a body without an `Operations` list, or an unknown operation,
is `scim.invalid_syntax`; a member that is neither a user nor a group is
`scim.invalid_value`. A PATCH is applied to a copy and validated whole, so a
request with one bad operation changes nothing.

### Deprovisioning revokes access

A provisioning change that takes access away is applied to the sessions the
user already holds, not only to the next login. `TomScimService.revoke` —
`TomCacheInvalidator.revokePrincipal` by default — is called for every
affected username:

| Change | Revoked |
| ------ | ------- |
| a user is deactivated (`active` becomes `false`) | that user |
| a user is deleted | that user |
| a user's `userName` changes | the old name |
| a group's membership changes | every member added or removed |
| a group is renamed or deleted | every member |

`revokePrincipal` refuses every token the user holds that was issued at or
before the revocation, and drops the principals cached for them. Through the
cross-node invalidation channel (see
[cache](cache.md#cross-node-invalidation)) that reaches every node within the
channel's staleness bound — so a user removed at the identity provider is
refused everywhere in the time an invalidation takes, not when their token
expires.

A group change revokes because the roles a session carries are derived from
its groups: the client re-authenticates and receives a token with the roles the
groups now grant — fewer after a removal, more after an addition. A
deactivated user's next login is refused by `TomScimIdentityDirectory` with
`login.error.scim.inactive`; a deleted user's next login finds no account.
Deleting a user also takes it out of every group it was a member of.

A deployment that mirrors the provisioned accounts into a user table of its
own passes its own `revoke` to `TomScimService` and calls
`revokePrincipal` from it, so the mirror and the revocation happen together.

### Single sign-on over provisioned accounts

`TomScimIdentityDirectory` is the `TomExternalIdentityDirectory` over the
provisioned users. Installed under `TomOAuthAuthenticationService`, it makes
single sign-on and provisioning meet in one place:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService =
    TomOAuthAuthenticationService(
      directory: TomScimIdentityDirectory(
        store,
        roleMapping: const TomExternalRoleMapping(
          roles: {
            'Admins': ['tom.admin'],
          },
        ),
      ),
    );
```

with the identity provider configured `provisioning: linkExisting` (see
[Provisioning modes](#provisioning-modes)) — the login links to the
provisioned account and never creates one:

```yaml
oauth:
  providers:
    entra:
      discovery: true
      issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
      clientId: ${ENTRA_CLIENT_ID}
      clientSecret: ${ENTRA_CLIENT_SECRET}
      redirectUri: https://app.example.com/sso/callback
      usernameClaim: preferred_username   # the value provisioned as userName
      provisioning: linkExisting
```

The provider's username claim must carry the value the identity provider
provisions as `userName` — for Entra ID, `preferred_username` against a
`userName` mapped from `userPrincipalName` — because that is the name the
directory looks the account up by.

| Account | Answer |
| ------- | ------ |
| not provisioned | `null` — the login takes its provider's provisioning branch, which under `linkExisting` refuses it with `login.error.oauth.no-local-account` |
| provisioned and active | a principal whose roles come from its groups |
| provisioned and inactive | refused, `login.error.scim.inactive` (`TomLoginFailure.accountProblem`) |

The principal's user carries `userName`, the given and family name, the primary
email (or the first), and `scimId` and `externalId` in its attributes; the
names of the groups it is a member of are in `aci.groups`. Roles are derived on
every login, through the directory's `roleMapping` applied to the groups'
**display names** — its `groupsClaim` is not consulted, because the groups come
from the store, not from a claim. A group change at the identity provider
therefore reaches the next session, and, because the service revokes the
members of a changed group, the current one too.

### Where provisioned resources are kept

| Store | For |
| ----- | --- |
| `TomMemoryScimStore` | A single node, a test, or a deployment that mirrors the resources into its own user table through `revoke`. Ids are a counter; everything is lost on restart. |
| `TomSqlScimStore` | A deployment with more than one node, or with provisioned users that must outlive a restart. |

`TomSqlScimStore` keeps one row per resource in `tom_scim_resource`
(`defaultScimResourceTable`), declared once by `scimResourceTable(table)` and
listed by `frameworkOwnedTables` (see
[db_migration](db_migration.md)):

| Column | Type | Meaning |
| ------ | ---- | ------- |
| `id` | `BIGINT` auto-increment, primary key | The resource's SCIM `id`, in decimal — never reused |
| `resource_type` | `VARCHAR(16)` | `User` or `Group` |
| `name_key` | `VARCHAR(191)` | The name attribute, lower-cased; unique per `resource_type` within a tenant |
| `external_id` | `VARCHAR(191)`, nullable | The identity provider's `externalId`; indexed with `tenant` and `resource_type` |
| `document` | `LONGTEXT` | The resource's JSON without `id` and `meta` |
| `created_at` · `last_modified` | `DATETIME(6)`, UTC | The lifecycle instants |
| `version` | `BIGINT` | The change counter, published as `meta.version` |
| `tenant` | `VARCHAR(32)` | The tenant the resource belongs to, `''` for none; every statement names the tenant in context |

The unique `(tenant, resource_type, name_key)` key arbitrates the one race the store
has: two identity-provider requests creating the same user at once both pass
the service's uniqueness check, and only one of them writes. The reference
migration is
`example/authentication/migrations/tenant/default/main/[4]-create_tom_scim_resource.sql`;
`scimResourceTableDdl(table)` returns the same `CREATE TABLE`, and
`test/framework_schema_test.dart` fails if the two drift apart. With
`createSchema: true` (the default) the store creates the table on first use; a
deployment whose schema is owned by the migration module passes `false`.

### SCIM error keys

Every refusal is a `TomScimException` (`clientThrow: true` — the message
describes the caller's own request, and the identity provider shows it to the
administrator who configured it), answered with its status and the SCIM error
body (RFC 7644, section 3.12): `schemas`, `status`, `scimType` and `detail`.

| Key | Status | `scimType` | Meaning |
| --- | ------ | ---------- | ------- |
| `scim.not_found` | 404 | — | No resource, resource type or schema has that id. |
| `scim.uniqueness` | 409 | `uniqueness` | Another user has the `userName`, or another group the `displayName`, in any case. |
| `scim.invalid_filter` | 400 | `invalidFilter` | The `filter` parameter cannot be read. |
| `scim.invalid_path` | 400 | `invalidPath` | A PATCH `path` cannot be read. |
| `scim.invalid_value` | 400 | `invalidValue` | A resource without its name attribute, a non-boolean `active`, a `members` that is not a list, or a member that is neither a user nor a group. |
| `scim.invalid_syntax` | 400 | `invalidSyntax` | The body is not a JSON object, or a PATCH has no `Operations` list or an unknown operation. |
| `scim.no_target` | 400 | `noTarget` | A `remove` without a path, or a value filter that matches nothing. |
| `scim.mutability` | 400 | `mutability` | A PATCH of `id`, `meta`, `schemas` or a user's `groups`. |
| `scim.unauthorized` | 401 | — | The request carries no configured bearer secret. |
| `scim.not_enabled` | 404 | — | No `TomScimProvisioning` is installed; or, at start-up, no `scim.bearerTokens` is configured. |
| `scim.store.unknown_datasource` | — | — | `TomSqlScimStore.named` names a data source that is not registered; raised at start-up as a `TomServerException`. |

The one key raised to a login rather than to the identity provider:

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `login.error.scim.inactive` | `TomLoginException` (`accountProblem`) | The account has been deactivated by its identity provider. |

## Service Accounts and API Keys

A **service account** is a non-human caller — a nightly import, another
service, a partner's integration — with roles of its own. It authenticates with
an **API key** in the `X-API-Key` header instead of a bearer token, and the
request then runs as an authenticated principal holding the key's roles, so
every access rule — `@TomAuthenticatedAccess`, `@TomRoleAccess`, row and column
grades — applies to it exactly as to a user. Nothing about an endpoint changes
to admit service accounts.

### The shape

| Part | What it is |
| ---- | ---------- |
| `TomServiceAccount` | The account: `id`, `name`, `roles`, `tenant`, `organization`, `disabled` |
| `TomApiKey` | One key's stored record — everything but the secret: `id`, `accountId`, `secretHash`, `roles`, `label`, `createdAt`, `expiresAt`, `revokedAt`, `lastUsedAt` |
| `TomIssuedApiKey` | A key as issued: its record, and the one time its full value is visible |
| `TomApiKeyIdentity` | The key and account a request authenticated with, in the request zone |
| `TomApiKeyStore` | Where accounts and key records live: `TomMemoryApiKeyStore` per process, `TomSqlApiKeyStore` in a shared data source |
| `TomApiKeys` | Issues, rotates, revokes and checks keys; installed once per process |

### Wiring it up

```dart
final keys = TomApiKeys(
  store: TomSqlApiKeyStore(TomDataSourceInfo.getDataSourceInfo('main')!.datasource),
);
TomApiKeys.install(keys);

await keys.saveAccount(
  const TomServiceAccount(
    id: 'importer',
    name: 'Nightly import',
    roles: ['import', 'read'],
  ),
);
final issued = await keys.issue('importer', roles: ['import'], label: 'nightly');
// Hand issued.value over once; nothing stores it.
```

`TomApiKeys.install` makes the service the one the request pipeline reads
`X-API-Key` with and registers the node's lookup cache; `TomApiKeys.reset`
uninstalls it. A server with no `TomApiKeys` installed reads no `X-API-Key`: it
ignores the header with a warning and the request proceeds unauthenticated.

Install it before the server starts, beside the other start-up stores. The
tables are system tables: the store keeps them in the system data source
whichever pool it was built over, and an account names its tenant itself.

### A key is shown once

`issue` answers the key as `tomk.<keyId>.<secret>` once, in
`TomIssuedApiKey.value`. The `tomk` prefix (`TomApiKeys.prefix`) tells a key
from any other secret in a configuration file or a log line; the key id is
sixteen hex characters; the secret is 32 random bytes from `Random.secure`,
base64url-encoded. The store keeps the key id and the SHA-256 of the secret
(`TomApiKeys.hashSecret`), never the secret, so a read of the key table hands
nobody a working key. A fast hash is the right one here: a slow password hash
exists to protect guessable secrets, and nothing about 256 random bits is
guessable. A lost key is replaced, not recovered.

### Scoped roles

A key may carry fewer roles than its account. Its effective roles are the
intersection of the two, so the account's roles bound every key it issues, and
narrowing an account narrows its keys at the next request. A key with no roles
of its own carries the account's. `issue` refuses a role the account does not
hold (`api_key.issue.role_not_held`) and an account that does not exist
(`api_key.issue.unknown_account`).

The principal a key authenticates as:

| Field | Value |
| ----- | ----- |
| `user.username` | `service:<accountId>` |
| `aci.roles` | the key's roles ∩ the account's roles, or the account's when the key has none |
| `authenticated` | `true` |
| `tenant` | the account's `tenant` |
| `organization` | the account's `organization` |
| `context` | `{serviceAccount: <accountId>, apiKey: <keyId>}` |

### Rotation and revocation

`rotate(keyId)` issues a successor with the old key's account, roles and label,
and ends the old key after `overlap` — **zero by default**, so a rotation revokes
the old key at once unless a grace period is asked for. With an overlap the old
key expires at the earlier of `now + overlap` and its own expiry; an overlap
never extends a key. `revoke(keyId)` ends a key at once. Both refuse a key that
does not exist (`api_key.rotate.unknown_key`, `api_key.revoke.unknown_key`).
`expiresIn` on `issue` and `rotate` gives a key an expiry of its own.

A disabled account (`TomServiceAccount.disabled`, saved with `saveAccount`)
authenticates nothing through any of its keys, without revoking them one by
one, and enabling it again restores them. `keysOf(accountId)` lists an account's
keys, live and ended — never their secrets.

A node caches the key records it has looked up, in the `tom.apiKeys` cache
(`TomApiKeys.lookupCacheName`), for at most `lookupCacheSeconds` (60).
`revoke` and `rotate` drop the entry through `TomCacheInvalidator`, so on a
cluster with a shared invalidation channel every node drops it; the cache's
lifetime bounds the staleness where the drop does not reach.

### Authenticating a request

`tomDefaultAuthenticationMiddleware` reads `X-API-Key` **only when the request
carries no `Authorization` header**. A request presenting both is answered as
the bearer it presented, so a key never widens what a signed-in user may do.
`TomApiKeys.authenticate` answers the principal and its `TomApiKeyIdentity`, or
`null`:

- `null` for every failure alike — a malformed key, an unknown key, a wrong
  secret, a revoked or expired key, a disabled or deleted account — so a caller
  probing keys learns nothing from the answer. The reason is logged, never the
  key. The secret's hash is compared in constant time.
- On success the middleware puts the principal in the zone as for a bearer
  token, and the `TomApiKeyIdentity` beside it — what a rate limit keyed per API
  key counts by (see [ratelimit.md](ratelimit.md#scopes)).

A key that authenticates nothing leaves the request unauthenticated, like a
refused token. See
[server.md](server.md#request-context-and-zone-values).

A key's `lastUsedAt` is written at most once a minute (`touchInterval`), so a
busy integration does not turn every request into a write.

### Where accounts and keys live

`TomMemoryApiKeyStore` keeps them in this process — right for a single node and
for tests; on a cluster each node would know only the keys issued on it.
`TomSqlApiKeyStore` keeps them in two tables of a shared data source:

| Table | Default name | Columns |
| ----- | ------------ | ------- |
| service accounts | `tom_service_account` (`defaultServiceAccountTable`) | `id`, `name`, `roles` (a JSON array), `tenant`, `organization`, `disabled` |
| API keys | `tom_api_key` (`defaultApiKeyTable`) | `id`, `account_id` (indexed), `secret_hash` (`CHAR(64)`), `roles`, `label`, `created_at`, `expires_at`, `revoked_at`, `last_used_at` |

A write replaces the row whole (`REPLACE`). The store creates both tables on
first use unless `createSchema` is `false`; `serviceAccountTable(table)` and
`apiKeyTable(table)` are the declarations a deployment's own migration renders.
A store of another kind implements `TomApiKeyStore`'s six methods.

### API key failure keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `api_key.issue.unknown_account` | `issue` | There is no service account with that id. |
| `api_key.issue.role_not_held` | `issue` | A requested role the account does not hold — a key cannot carry more than its account. |
| `api_key.rotate.unknown_key` | `rotate` | There is no key with that id. |
| `api_key.revoke.unknown_key` | `revoke` | There is no key with that id. |

Each is a `TomApiKeyException`, which extends `TomServerException`. A presented
key that authenticates nothing raises nothing: the request proceeds
unauthenticated, and a protected endpoint refuses it downstream.

## Browser Sessions in a Cookie

A browser client can keep its access token in an `HttpOnly` cookie instead of
script-readable storage, where any script that runs in the page — an injected
one included — can read it. `TomSessionCookie` sets the cookie on the response
that hands out the token, and the request pipeline reads it back. A cookie
travels with every request the browser sends to the server — including one a
hostile page triggers — so a request authenticated by the cookie is held to a
CSRF check before it may change anything.

Nothing of it is active until `TomSessionCookie.current` is installed: without
it no request is authenticated by a cookie, whatever cookies it carries.

### The cookies

| Cookie | Holds | Attributes |
| ------ | ----- | ---------- |
| `name` (`tom_session`) | the access token | `HttpOnly; Secure; SameSite=Strict; Path=/` |
| `csrfCookieName` (`tom_csrf`) | a random CSRF token, 32 bytes base64url | `Secure; SameSite=Strict; Path=/` — readable by the page, which copies it into the `X-CSRF-Token` header |

`Secure`, `SameSite` (`TomSameSite.strict`, `lax` or `none`), `Path` and
`Domain` are configured once and apply to both cookies. `SameSite=Strict` is the
default: the browser sends neither cookie on a request another site starts, so
the CSRF check is a second line rather than the only one.

### Setting and clearing them

`attach` sets both cookies on the response that hands out the token — a login, a
refresh — and `clear` deletes both, which is a logout. Both append to the
`Set-Cookie` headers the response already carries:

```dart
final response = TomSessionCookie.current!.attach(
  Response.ok('signed in'),
  accessToken,                          // the token the login handed out
  maxAge: const Duration(hours: 1),     // a browser session when omitted
);
// Set-Cookie: tom_session=<token>; Path=/; Max-Age=3600; Secure; HttpOnly; SameSite=Strict
// Set-Cookie: tom_csrf=<random>; Path=/; Max-Age=3600; Secure; SameSite=Strict

final loggedOut = TomSessionCookie.current!.clear(Response.ok(''));
```

The calls and the two headers are those `test/web_security_test.dart` asserts.

Each `attach` draws a fresh CSRF token. `tokenOf(request)` reads the access
token back, `TomSessionCookie.cookiesOf(request)` every cookie of the request by
name.

When a request carries **no `Authorization` header**,
`tomDefaultAuthenticationMiddleware` takes the session cookie's token as its
bearer token: it is verified, and the principal resolved, exactly as a token in
the header would be. A request presenting a header is answered as the bearer it
presented, and the cookie is not read. A substitute authentication middleware
that should admit cookie sessions has to read the cookie and run the CSRF check
the same way (see [server.md](server.md#cors-and-session-cookies)).

### The CSRF check

A cookie-authenticated request with a method other than `GET`, `HEAD`,
`OPTIONS` and `TRACE` must pass a double-submit check
(`TomSessionCookie.checkCsrf`):

- it carries the `X-CSRF-Token` header (`csrfHeader`) equal to the `tom_csrf`
  cookie, compared in constant time — a page of another origin can neither read
  that cookie nor set it; and
- when it carries an `Origin`, that origin is the server's own or one the CORS
  policy admits (`TomCors.current.admits`; see
  [endpoints.md](endpoints.md#cors)).

Otherwise the middleware answers `403` with `authentication.csrf.rejected`,
whose `reason` parameter names the failure — `missing_token`, `token_mismatch`
or `foreign_origin` — and logs a warning naming the method, the path and the
reason. A safe method always passes, which is why it must not change anything.
A request authenticated by an `Authorization` header or an API key is not
checked: a browser never attaches those by itself.

A web client of another origin needs `allowCredentials` in the `cors` settings
before its browser sends the cookies at all, and its origin on the allow-list.

### The `sessionCookie` key

The settings are the `sessionCookie` key of the server configuration
(`TomSessionCookie.configurationKey`), applied at start by
`TomServer.configureSecurity`:

```yaml
sessionCookie:
  name: tom_session
  csrfCookieName: tom_csrf
  csrfHeader: X-CSRF-Token
  path: /
  domain: example.com        # optional; the host alone when absent
  sameSite: Strict           # Strict | Lax | None
  secure: true
```

Every setting is optional and defaults as shown; the key being present — an
empty map included — is what switches cookie sessions on. A test or an
embedding application installs `TomSessionCookie.current` directly.

### Session cookie failure keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `authentication.session_cookie.config.invalid` | `TomSessionCookie.configure` | The value is not a map, has an unknown key, a name or header that is not a token, a `path` not starting with `/`, a `domain` that is not a host name, a `sameSite` other than `Strict`, `Lax` or `None`, a `secure` that is not a boolean, or `SameSite=None` without `Secure`. Stops the start. |
| `authentication.csrf.rejected` | `TomSessionCookie.checkCsrf` | A cookie-authenticated request with an unsafe method failed the CSRF check; answered `403`. |

Each is a `TomSessionCookieException`, which extends `TomServerException`.

## Verification

`test/authentication_test.dart` covers the module's own contract:
`TomAuthenticationData`, the dummy service, the `TomAuthenticationService`
contract every service satisfies, the adaptor annotations the registry scans,
and `TomAuthenticationServer` including its login flow.

The surfaces this module grew later are covered by suites named after the
mechanism rather than the module: `two_factor_test.dart`,
`two_factor_delivered_code_test.dart` and `two_factor_enrolment_db_test.dart`
for [Two-Factor Authentication](#two-factor-authentication);
`server_self_login_test.dart` for [Server Self-Login](#server-self-login);
`jwt_signing_test.dart` and `jwt_keys_test.dart` for the signing keys, key ids,
rotation, verify-only servers, what a verifier refuses and the JSON Web Key Set,
whose mounted route `endpoints_pipeline_test.dart` asserts in the group
`JSON Web Key Set GET /.well-known/jwks.json route`; and
`oauth_test.dart`, `oauth_state_store_test.dart`,
`oauth_state_store_db_test.dart` and `oauth_tokens_db_test.dart` for
[External Identity](#external-identity-oauth-20--oidc). The three `_db` suites
there are tagged `db` and skip when no server is reachable.
[Single sign-on](#single-sign-on-with-enterprise-identity-providers) is
`oauth_test.dart`'s group `single sign-on over OpenID Connect` — the nonce,
discovery, role mapping and the provisioning modes — and `saml_test.dart`, which
covers canonicalization, every refusal of the response validator including
signature wrapping, the three legs of the flow, identity-provider metadata and
the two endpoints against a scripted identity provider.
`sso_keycloak_test.dart` repeats the logins against a real Keycloak; it is
tagged `sso`, skips when none is listening, and `tool/run_sso_tests.sh` starts
one.
[User provisioning](#user-provisioning-with-scim-20) is `scim_test.dart` — the
filter and path language, a conformance subset driven over HTTP through the
endpoint pipeline in the request shapes Entra ID and Okta send (discovery, the
bearer secret, users, groups, every PATCH form above), and the group
`deprovisioning revokes access`, which signs a provisioned user in through
`TomScimIdentityDirectory` and shows each deprovisioning change refusing the
session it should. `scim_store_db_test.dart` runs the relational store and the
service over it; it is tagged `db` and skips when no server is reachable.
[Service accounts and API keys](#service-accounts-and-api-keys) are
`api_keys_test.dart` — issuing, a key shown once and stored as a hash, the
refusal of an unknown account and of a role the account does not hold;
authenticating as the account with the key's scope, narrowing and disabling the
account, the failures that all answer alike, expiry and the last-use stamp;
revocation, even of a cached key; and rotation with and without an overlap.
`ratelimit_api_keys_db_test.dart`, tagged `db`, runs `TomSqlApiKeyStore` across
two nodes — a key revoked or rotated on one is refused by the other at once —
and `ratelimit_test.dart`'s group `the middleware` reads a key through the
request pipeline. `example/ratelimit/rate_limit_example.dart` walks a service
account from issuing to revocation; it is the rate-limiting module's example,
because a key is what an `apiKey` limit counts by.
[Browser sessions in a cookie](#browser-sessions-in-a-cookie) are
`web_security_test.dart`'s group `a browser session in a cookie`: `attach`
setting the token `HttpOnly` beside a readable CSRF token, a request carrying
only the cookie authenticated, an unsafe method refused with
`authentication.csrf.rejected` without a matching CSRF header, a foreign
`Origin` refused unless the CORS policy admits it, a bearer header not held to
the check, and the `sessionCookie` key read from the server configuration and
refused with `authentication.session_cookie.config.invalid` when malformed.

```bash
dart run example/authentication/authentication_example.dart
dart run example/authentication/two_factor_login_example.dart
dart run example/authentication/two_factor_enrolment_example.dart
dart run example/authentication/oauth_login_example.dart
dart run example/authentication/scim_provisioning_example.dart
```

Five examples, because the module has five flows and one program showing all of
them would show none of them clearly. The first configures the seams; the other
four run a flow end to end against a scripted seam — the two-pass login, the
enrolment round trip that turns "you must use 2FA" from a lockout into an
onboarding step, the OAuth handshake against a scripted provider, so no
network and no browser is involved, and SCIM provisioning from the identity
provider's first call to the deactivation that ends a session, in eight
numbered steps through the server's own router. Each checks every step through
the package's throwing `check` helper, and `test/examples_test.dart` runs all
five.

## Core Components

### `TomAuthenticationServer`

The orchestrator. `authenticateGuest` and `authenticatePass1` run the flow
above (guest vs. user service); `authenticatePass2` completes a second-factor
login against the challenge the interim token carries. The two static settings
select the services process-wide; the issued tokens' issuer, audience and
signing key are `TomJwtSigning.current`'s, and a verify-only server refuses to
issue (`jwt.keys.verify_only`).

### `TomAuthenticationService` / `TomAuthenticationInfo`

The contract you implement and the value it returns. `authenticateUser` either
returns a `TomAuthenticationInfo` (the `TomPrincipal` plus its
`TomAccessControlDefinition`) or throws a `TomLoginException`.

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
secret rather than failing the login. The entity declares its `principalId` the
row's data subject (`@TomDataSubject`, so erasing the principal deletes their
enrolments) and its `hint` personal data (`@TomPersonal`, sealed for the
principal in the audit trail); registering the repository with `TomPrivacy`
takes enrolments into erasure and subject-access export — see
[privacy.md](privacy.md#framework-entities-that-declare-subjects).

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
discovered at the challenge. Every code it sends is paced by the
`Tom2FASendLimiter` — see [Codes delivered by email or SMS](#codes-delivered-by-email-or-sms).
A subclass supplies six things: `type`,
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

### `TomWebAuthn2FAService`

Passkeys, registered under `'webauthn'`, offered once
`globalSettingRelyingPartyId` is set. Statics configure the RP id and name, the
allowed origins, the user-verification requirement and the attempt and validity
budgets. It implements `Tom2FAEnrolmentSupport` and `Tom2FAPrerequisite`. See
[Passkeys (WebAuthn)](#passkeys-webauthn).

### `TomWebAuthnVerifier` / `TomWebAuthnSoftwareAuthenticator`

`verifyRegistration` and `verifyAssertion` are the ceremony checks as pure
functions over the kernel's wire types; each answers `null` for anything that
fails, since every failure is the same "not a valid passkey answer" to the
caller. The software authenticator is the test double that makes real
credentials in memory.

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

Provider configuration as data, read from `oauth.providers` — by `load` when a
provider's endpoints come from its discovery document. `TomOAuthProvisioning` is
the per-provider first-login choice.

### `TomOAuthFlow` / `TomOAuthPkce` / `TomOAuthStateStore` / `TomOAuthTokenTransport`

The handshake, the verifier/challenge pair, the pending-authorization records,
and the one HTTP seam a stub provider replaces — `TomHttpOAuthTokenTransport`
being the live implementation of that seam, over `package:http`, which
`TomOAuthTokenTransport.resolve()` falls back to when no bean is installed.
`TomOAuthExchange` is what a completed handshake answers: the asserted identity,
the pending record it consumed, the provider registration, and the token grant.

### `TomSqlOAuthStateStore` / `TomOAuthStateStoreSettings`

The state store every node of a cluster shares, over the `tom_oauth_state`
framework table, and the `oauth.stateStore` block that selects it. `store` /
`peek` / `consume` / `purgeExpired`, with `consume` a single
`DELETE … RETURNING` so a state stays single-use under concurrent completions —
see [Where pending authorizations live](#where-pending-authorizations-live). The
table itself is declared by `oauthStateTable(table)`, named by default from
`defaultOAuthStateTable`, with `oauthStateTableDdl(table)` its `CREATE TABLE`.

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

### `TomExternalProvider` / `TomExternalRoleMapping` / `applyExternalRoles`

The protocol-neutral half of external identity. `TomExternalProvider` is what
`TomOAuthProviderConfig` and `TomSamlProviderConfig` share, and what
`TomOAuthExchange.provider` is typed by. `TomExternalRoleMapping` reads
`groupsClaim`, `roleMapping` and `defaultRoles`, and `applyExternalRoles` adds
the roles it grants to the session's principal on every login. See
[Claim mapping: groups to roles](#claim-mapping-groups-to-roles).
`TomExternalTenancyMapping` reads `tenantClaim`, `organizationClaim` and
`organizationParameter`; `tenantIn` and `organizationIn` answer the tenant and
organization a token names, refusing a configured claim that is missing. See
[Claim mapping: tenant and organization](#claim-mapping-tenant-and-organization).

### `TomSamlProviders` / `TomSamlProviderConfig` / `TomSamlIdpMetadata` / `TomSamlCertificates`

SAML provider configuration as data, read from `saml.providers`. `load` fetches
each `metadataUrl` and parses it into `TomSamlIdpMetadata`; `TomSamlCertificates`
reads the certificates and keys the configuration names. See
[SAML 2.0 identity providers](#saml-20-identity-providers).

### `TomSamlFlow` / `TomSamlResponseValidator`

The three legs of a SAML login — `beginAuthorization`, `acceptResponse`,
`completeAuthorization` — over the pending-authorization store the OAuth flow
uses, and `metadataFor`, this server's metadata. The validator holds every check
a response must pass. See [The SAML flow has three legs](#the-saml-flow-has-three-legs).

### `TomXmlSignatureVerifier` / `TomExclusiveCanonicalizer` / `TomXmlDsig` / `TomSamlNames`

XML Signature verification in exactly the profile identity providers use, over
Exclusive XML Canonicalization, and the identifiers both protocols' XML is
written in. See [Security notes](#security-notes).

### `TomSamlService` / `TomSamlServer`

`POST /saml/acs` — the identity provider's form post, answered with a `303` to
the application's page — and `GET /saml/metadata/<providerId>`. Both public: the
signed response is the credential, and metadata is published by design.

### `TomSamlException`

A SAML message, configuration value or signature that cannot be used.
`clientThrow` is `false` unless the key is one a client acts on; what failed in a
response is the operator's business. See [SAML failure keys](#saml-failure-keys).

### `TomJwtSigning` / `TomJwtKey` / `TomJwtSigningKey` / `TomJwtAlgorithm`

`TomJwtSigning` is the process's token signing: `algorithm`, `keys` (the
signing key's public half first, then the retired keys), `signingKeyId`,
`canSign`, `issuer` and `audience`, with `keyFor(kid)` for the verifier,
`jwks` for the published set and `requireSigning()` for the issuer.
`TomJwtSigning.current` is what `installJwtSigning` installed — or, in a
process that never ran a server boot, HS256 with the `TomJwtConfiguration`
default secret and issuer `tom`. `TomJwtKey` is one verification key under its
thumbprint id, `TomJwtSigningKey` a private key with its public half, and
`TomJwtAlgorithm` the three algorithms. `TomJwtKeyException` reports a key or
setting that cannot be used. See [The signing keys](#the-signing-keys).

### `TomJwksService` / `TomJwksServer`

The JSON Web Key Set at `GET /.well-known/jwks.json`, public, cacheable for
`TomJwksServer.cacheFor` (five minutes), and `404` under HS256. See
[The JSON Web Key Set](#the-json-web-key-set).

### `TomScimProvisioning` / `TomScimApi` / `TomScimServer`

`TomScimProvisioning` is the installed SCIM service, the secrets that may call
it (held as SHA-256 digests, compared in constant time) and the published
`baseUrl`. `install` enables SCIM and claims `pathPrefix` (`/scim/v2/`) in
`TomEndpointCredentials`; `reset` undoes both; `current` is the installed one;
`fromConfiguration` reads `scim.bearerTokens`, each tenant's
`scim.tenants.<id>.bearerTokens` and `scim.baseUrl`; `tenants` names the tenants
with secrets of their own. Inside a tenant only that tenant's secrets admit.
`TomScimApi` declares the seventeen endpoints and `TomScimServer` answers them.
See [Enabling SCIM](#enabling-scim) and [The SCIM endpoints](#the-scim-endpoints).

### `TomScimService`

The SCIM service provider independent of HTTP: `create`, `get`, `list`,
`replace`, `patch` and `delete` over users and groups, the discovery
documents `serviceProviderConfig`, `resourceTypes`, `resourceType` and
`schemas`, and the `revoke` hook a deprovisioning change calls. Pages are
`defaultCount` (100) by default and at most `maxCount` (200). See
[Deprovisioning revokes access](#deprovisioning-revokes-access).

### `TomScimResource` / `TomScimResourceType` / `TomScimSchemas`

One stored resource — `id`, `type`, the client-managed `document`, `created`,
`lastModified`, `version` — with `name`, `nameKey`, `externalId`, `active` and
the case-insensitive `attribute` lookup. `TomScimResourceType` is `user` or
`group`; `TomScimSchemas` the URNs.

### `TomScimStore` / `TomMemoryScimStore` / `TomSqlScimStore`

Where resources are kept. The memory store is per process, partitioned by the
tenant in context; the SQL store keeps them in `tom_scim_resource` — a tenant table
placed for the tenant in context on every call (`TomFrameworkTable.placed`),
over a data source name (`named`) or object, with a `tenant` column every
statement filters on — declared by `scimResourceTable(table)` and named
by default from `defaultScimResourceTable`, with `scimResourceTableDdl(table)`
its `CREATE TABLE`. See
[Where provisioned resources are kept](#where-provisioned-resources-are-kept).

### `TomScimFilter` / `TomScimPath`

The filter language and the PATCH attribute path, one grammar for both:
`TomScimFilter.parse` (`scim.invalid_filter`) yields a `TomScimAnd`,
`TomScimOr`, `TomScimNot`, `TomScimValuePath` or `TomScimComparison`, and
`TomScimPath.parse` (`scim.invalid_path`) a path. `scimValues`, `scimLookup`
and `scimKeyOf` read a JSON document the case-insensitive way SCIM attributes
are read. See [What is supported](#what-is-supported).

### `TomScimIdentityDirectory`

Single sign-on over the provisioned users: `null` for an account not
provisioned, a principal with roles from its groups for an active one, and
`login.error.scim.inactive` for a deactivated one. See
[Single sign-on over provisioned accounts](#single-sign-on-over-provisioned-accounts).

### `TomScimException`

A SCIM request that cannot be served, carrying its `status` and `scimType`;
`toJson` is the SCIM error body. `clientThrow` is `true`. See
[SCIM error keys](#scim-error-keys).

### `TomApiKeys` / `TomServiceAccount` / `TomApiKey`

Service accounts and the API keys they authenticate with. `TomApiKeys` —
`install`, `reset`, `current`; `saveAccount`, `issue`, `rotate`, `revoke`,
`keysOf`; `authenticate`, which the request pipeline calls for an `X-API-Key`
header; `hashSecret`; and the constants `header`, `prefix`, `lookupCacheName`,
`lookupCacheSeconds` and `touchInterval`. `TomServiceAccount` carries
`withDisabled` and `withRoles`; `TomApiKey` carries `isLiveAt` and `copyWith`.
`TomIssuedApiKey` is a key as issued and `TomApiKeyIdentity` the key a request
authenticated with. `TomApiKeyException` is every refusal. See
[Service Accounts and API Keys](#service-accounts-and-api-keys).

### `TomApiKeyStore` / `TomMemoryApiKeyStore` / `TomSqlApiKeyStore`

Where accounts and key records live. The memory store is per process; the SQL
store keeps them in `tom_service_account` and `tom_api_key`, declared by
`serviceAccountTable(table)` and `apiKeyTable(table)` and named by default from
`defaultServiceAccountTable` and `defaultApiKeyTable`, and reads them back as
`TomServiceAccountRow` and `TomApiKeyRow`. See
[Where accounts and keys live](#where-accounts-and-keys-live).

### `TomSessionCookie` / `TomSameSite` / `TomSessionCookieException`

Browser sessions in a cookie. `TomSessionCookie` — `configure`, `current`,
`configurationKey`; `attach`, `clear`, `tokenOf`, `cookiesOf` and `checkCsrf`;
the settings `name`, `csrfCookieName`, `csrfHeader`, `path`, `domain`,
`sameSite` and `secure`. `TomSameSite` is the cookies' `SameSite` attribute,
and `TomSessionCookieException` both refusals. See
[Browser Sessions in a Cookie](#browser-sessions-in-a-cookie).

## Status and Limitations

- **`TomDummyAuthenticationService` is for scaffolding only** — it grants any
  non-`GUEST` login. Replace it before any test or production use.
  <!-- pinned: test/authentication_test.dart › authenticates any non-GUEST user -->
- **Four second-factor mechanisms ship**: `TomTotp2FAService` (authenticator
  app), `TomWebAuthn2FAService` (passkeys), and `TomEmailCode2FAService` and
  `TomSmsCode2FAService` (delivered codes). Anything else remains
  application-supplied — the mechanism set is open by design, and adding one
  needs no change here (see
  [Writing your own mechanism](#writing-your-own-mechanism)).
  <!-- unpinned: absence — further mechanisms are application-supplied; the set is open -->
- **The delivered-code factors have no shipped client panel.** `tom_core_flutter`
  ships the TOTP and passkey client mechanisms only. A deployment that offers `email` or `sms`
  codes writes and registers the client mechanism — a code field and an
  enrolment confirm step — and until it does, the client's enrolment chooser
  leaves the key out. For SMS that is deliberate: it is the weakest common
  factor and the dearest to run, so registering its panel is the deployment's
  explicit step, on top of installing an SMS service.
  <!-- unpinned: decision — no SMS or email client panel ships; the deployment registers one -->
- **The send pace is per address, not per principal.** A user is limited by
  each address they have, one run per channel — so a principal with both email
  and SMS enrolled can receive one escalating run on each. The pace bounds what
  any one inbox or phone receives, which is what flooding and SMS pumping cost;
  a per-principal budget across channels is not kept. And the default limiter
  is per process, so a cluster without a shared one paces per node.
  <!-- unpinned: decision — send pace keyed by channel and address -->
- **Passkey attestation is not verified.** The server requests attestation
  `none` and does not check a statement that arrives anyway, so it cannot admit
  only certified hardware keys. That is the trust model consumer passkeys
  expect; a deployment that needs an authenticator allow-list verifies the
  attestation statement itself. See [Passkeys (WebAuthn)](#passkeys-webauthn).
  <!-- unpinned: decision — attestation none; the server trusts what a credential signs -->
- **Two policies ship, and neither is a component.** `TomPrincipalFlag2FAPolicy`
  is the default and `TomRole2FAPolicy` is installed by hand. Neither carries
  `@TomComponent`, so a deployment that adds a dependency does not silently
  acquire a 2FA requirement; anything richer than "per role" or "per principal
  flag" is a `Tom2FAPolicy` the deployment writes.
  <!-- unpinned: decision — neither policy is a component, so a dependency adds no 2FA requirement -->
- **No enrolment store is installed by default**, deliberately.
  `Tom2FAEnrolmentStore.resolve()` returns `null` rather than an empty store,
  because "nobody tracks enrolments here" and "this user has enrolled nothing"
  must lead to different logins — see [Enrolment](#enrolment). A deployment
  installs `TomPersistent2FAEnrolmentStore` (and runs the DDL in
  `TomUserTwoFactorEnrolment.createTableSql`) to switch enrolment on.
  <!-- pinned: test/two_factor_test.dart › resolve returns null when no store is installed -->
- **The grace count is per process unless a deployment stores it.**
  `TomRole2FAPolicy` counts its budget down through `Tom2FAGraceStore`, and the
  default store is a map in this process — so a restart or a second node starts
  the count again. That lengthens a budget and never shortens it, which is why
  it is an acceptable default; a deployment that wants the count to survive
  implements the store against its own user data. The framework ships no table
  for it: the count is a fact about a user, and this package has no user table.
  <!-- unpinned: decision — the in-process default store is deliberate; a deployment stores the count itself -->
- **A delivered code's transport is not retried.** Delivery is synchronous and
  a failure fails the login, because a code that outlives its challenge is worse
  than none. The retry is the user asking for a new code. A deployment whose
  relay is unreliable therefore sees failed logins rather than late ones — which
  is the intended trade, not an oversight.
  <!-- pinned: test/two_factor_delivered_code_test.dart › a delivery failure fails the login rather than prompting -->
- **The per-challenge attempt cap is per process by default.** The counter in
  the token bounds a cooperative client; what bounds an uncooperative one is
  `Tom2FAAttemptStore`, which records that an interim token has been answered
  and refuses the replay. The default store is a map in this process, so a
  clustered deployment gets the cap *per node* — finite, and larger than the
  challenge's own allowance by the node count. A deployment wanting the exact
  cap installs a store its nodes share. See [the attempt counter, and what makes
  it a bound](#the-attempt-counter-and-what-makes-it-a-bound).
  <!-- unpinned: decision — the in-process default store is deliberate; a cluster installs a shared one -->
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
  <!-- pinned: test/oauth_test.dart › an id_token is accepted on its claims, whatever its signature -->
- **The `id_token`'s age is not policed, only its expiry.** `iat` is read by
  nothing: a maximum-age policy is a decision this module does not take, and
  `exp` is the provider's own statement of how long the token is good for. A
  deployment that needs "re-authenticate if the session is older than an hour"
  is asking for OIDC `max_age` / `auth_time`, which is not implemented.
  <!-- pinned: test/oauth_test.dart › an old iat does not refuse a token that has not expired -->
- **`TomOAuthMemoryStateStore` is the default state store, and is per-process.**
  Pending authorizations live for ten minutes in one isolate's memory, which is
  correct for a single-node deployment and wrong behind a load balancer that may
  route the callback to a different node. That default is deliberate — a single
  node and a test suite need no database — but it is a default, not the only
  choice.
  <!-- pinned: test/oauth_test.dart › the state store defaults to memory when nothing selects one -->
- **A clustered deployment sets `oauth.stateStore.type: sql`** and gets
  `TomSqlOAuthStateStore` over the shared `tom_oauth_state` table, where an
  authorization begun on one node completes on any other and a state stays
  single-use under concurrent completions. What is *not* implemented is any
  other backing: there is no Redis or other cache-backed store, and a deployment
  wanting one implements the same three-method contract. See
  [Where pending authorizations live](#where-pending-authorizations-live).
  <!-- unpinned: absence — no backing beyond memory and SQL ships -->
- **The identity *store* has no default at all**, deliberately — see
  [The linking table](#the-linking-table). `TomPersistentExternalIdentityStore`
  needs `TomExternalIdentityLink.createTableSql`, shipped as
  `example/authentication/migrations/tenant/default/main/[3]-create_tom_external_identity.sql`.
  <!-- pinned: test/documented_limitations_test.dart › no identity store is installed by default -->
- **The framework retains no provider token unless a provider opts in.**
  `storeTokens` defaults to `false`, so a deployment that only wants "Sign in
  with …" never acquires a third-party credential. The grant is still handed to
  the caller on every exchange; what is opt-in is *storing* it. See
  [Delegated access](#delegated-access-the-providers-tokens).
  <!-- pinned: test/oauth_test.dart › a provider that did not opt in has nothing retained -->
- **A retained grant needs a `TomOAuthTokenStore` and its table.** Opting a
  provider in without installing a store retains nothing and logs it — the two
  halves are separate on purpose, so a deployment can hold its identity links in
  a table of its own and still let the framework hold credentials, or the
  reverse. `TomPersistentOAuthTokenStore` needs
  `TomExternalIdentityToken.createTableSql`, shipped as
  `example/authentication/migrations/tenant/default/main/[2]-create_tom_external_identity_token.sql`.
  <!-- unpinned: decision — opting in and installing a store are separate halves on purpose -->
- **Revocation reaches only providers that publish an endpoint.** `unlink`
  revokes through `revocationEndpoint` (RFC 7009) where a provider configures
  one; where it does not, the framework's copy of the grant is deleted and the
  credential remains valid at the provider until it expires or the user
  withdraws consent there. Nothing can be done about that from here — there is
  no address to call.
  <!-- pinned: test/oauth_test.dart › a provider with no revocation endpoint is not called -->
- **SAML assertions must be signed, not encrypted.** An `EncryptedAssertion`
  is refused with `saml.response.encrypted_unsupported`. Over TLS the assertion
  is already confidential in transit, and decrypting would put this server's
  private key on the path of every login; an identity provider is configured to
  sign instead.
  <!-- pinned: test/saml_test.dart › carrying an encrypted assertion is refused -->
- **SAML login is service-provider initiated only.** A response must answer a
  request this server sent, so an unsolicited, identity-provider-initiated
  response is refused with `saml.response.wrong_request`. A portal tile starts at
  the application's login page instead.
  <!-- pinned: test/saml_test.dart › answering another request is refused -->
- **Single logout is not implemented**, for either protocol. Signing out of the
  application ends the framework session; it does not end the identity
  provider's, and the identity provider ending its session does not reach this
  server.
  <!-- unpinned: absence — no SAML SingleLogout or OIDC logout endpoint ships -->
- **Mapped roles are not persisted.** The roles a provider's `roleMapping`
  grants are applied to each session and written nowhere, so the identity
  provider stays their authority. A deployment that wants them stored reads
  `TomExternalIdentity.roles` in its directory.
  <!-- unpinned: decision — the framework owns no user store to write them to -->
- **SCIM is the subset identity providers use.** Bulk operations, sorting,
  ETags, `/Me`, `.search` and changing passwords are not implemented, and
  `ServiceProviderConfig` says so. See [What is supported](#what-is-supported).
  <!-- pinned: test/scim_test.dart › the service provider configuration states what is supported -->
- **An API key's lookup is cached per node for up to a minute.** `revoke` and
  `rotate` drop the cached record through `TomCacheInvalidator`; where that drop
  does not reach a node — no shared invalidation channel — the node serves the
  record it holds until the entry expires, at most `lookupCacheSeconds` later.
  <!-- unpinned: decision — a node caches key lookups rather than reading the store on every request -->
- **SCIM is the only directory protocol.** LDAP and Active Directory are not
  provided: an on-premises directory reaches this server through an identity
  provider that speaks SCIM, OpenID Connect or SAML.
  <!-- unpinned: absence — no LDAP or Active Directory connector ships -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `server_self_login.dart`, `two_factor.dart` | `Future`, `FutureOr`, and the `Timer` the server principal's renewal is scheduled on |
| `dart:convert` | dart | 23 of 38 files | `base64`, `base64Url`, `json`, `jsonDecode`, `jsonEncode`, `utf8` |
| `dart:io` | dart | `jwt_keys.dart`, `saml_flow.dart`, `saml_provider.dart` | `File`, reading the configured key and certificate files; `ZLibCodec`, deflating a SAML `AuthnRequest` for the redirect binding |
| `dart:math` | dart | `api_keys.dart`, `jwt_signing.dart`, `oauth_flow.dart`, `session_cookie.dart`, `two_factor_send_limit.dart`, `webauthn_software_authenticator.dart` | `Random`, `exp`, and `pow` / `min` for the send pace's doubling interval; `Random.secure` for the unusable signing key a verify-only server holds, for an API key's id and secret, and for a session's CSRF token |
| `dart:typed_data` | dart | `saml_xml_signature.dart`, `two_factor_delivered_code.dart`, `two_factor_webauthn.dart`, `webauthn_software_authenticator.dart` | `Uint8List`, `ByteData`, `BytesBuilder` |
| `crypto` | package | 10 of 38 files | `sha256` and `sha512`, for the JWK thumbprint a key id is, the API-key secret digest, the SCIM bearer-secret digests, the PKCE code challenge, the SAML handoff-code digest and XML Signature digests, the interim-token fingerprint an attempt store keys on, the delivered-code digest, and the WebAuthn RP id hash, client-data hash and user handle |
| `dart_jsonwebtoken` | package | `jwt_keys.dart`, `jwt_signing.dart`, `saml_provider.dart` | `jwt.JWT.verify`, `jwt.JWTAlgorithm`, `jwt.RSAPrivateKey` / `jwt.RSAPublicKey`, `jwt.ECPrivateKey` / `jwt.ECPublicKey`, `jwt.SecretKey`, and `toJWK` for the published set |
| `http` | package | `oauth_flow.dart` | `http.dart`, `http.get`, `http.post` |
| `pointycastle` | package | `jwt_keys.dart`, `saml_provider.dart`, `saml_xml_signature.dart`, `two_factor_webauthn.dart`, `webauthn_software_authenticator.dart` | RSA PKCS#1 v1.5 signing and verification for XML Signature, ECDSA P-256 and RSA PKCS#1 v1.5 signature verification for passkeys, and the software authenticator's key generation and signing; deriving a signing key's public half |
| `shelf` | package | `jwks_endpoint.dart`, `saml_endpoints.dart`, `scim_endpoints.dart`, `session_cookie.dart` | `Request` and `Response` — the SCIM endpoints read the raw request and answer in `application/scim+json`; `Response`, which the JSON Web Key Set and SAML metadata endpoints answer with directly to set their content type — and, for the key set, its cache header; the session cookie reads a request's `Cookie` header and adds `Set-Cookie` to a response |
| `tom_core_kernel` | package | 32 of 38 files | `TomPrincipal`, `TomAccessControlDefinition`, `TomBearerAuthentication`, `TomServerJwtToken`, the 2FA wire types `Tom2FAChallenge` / `Tom2FAClaims` / `Tom2FAPendingEnrolment` / `Tom2FAEnrolmentClaims`, the `Tom2FAMethodDescriptor` every adaptor describes itself with, the `TomTotp` derivation primitives, `TomServerPrincipal` (the holder server self-login installs into), the wire types `TomAuthenticationMessage` / `TomAuthenticationResult`, and `TomResilientClient` (the OAuth transport's client). The 2FA types live there and not here because the server writes them and the client reads them |
| `xml` | package | `saml_flow.dart`, `saml_provider.dart`, `saml_xml_signature.dart` | `XmlDocument`, `XmlElement`, parsing SAML responses and metadata, and the node walk exclusive canonicalization is written over |
| [audit](audit.md) | module | `authentication_server.dart` | `TomAuditTrail.recordAction`, `TomAuditAction` and `TomAuditOutcome` — the record of a switch of the sign-in organization (`session.organizationSwitched`) |
| [cache](cache.md) | module | `api_keys.dart`, `scim_service.dart` | `TomCacheInvalidator.revokePrincipal`, the default revocation a SCIM deprovisioning change calls; `TomCache` and `TomCacheManager` for the node's API-key lookup cache, and `TomCacheInvalidator.invalidateCacheEntry`, which drops a revoked or rotated key from it |
| [configuration](configuration.md) | module | `jwt_signing.dart`, `oauth_provider.dart`, `saml_provider.dart`, `scim_endpoints.dart`, `server_self_login.dart`, `sql_oauth_state_store.dart` | `TomBaseServerConfiguration` supplies the JWT fields `installJwtSigning` reads and the service-account fields `TomServiceCredential.fromConfiguration` reads; `isDevelopmentOrTestRuntime` decides whether the sample-key fallback is permitted |
| [datasources](datasources.md) | module | 8 of 38 files | `TomPrimaryReads` (on the external-identity link and token and the second-factor enrolment, whose reads stay on the primary; `oauth_identity.dart`, `oauth_tokens.dart`, `two_factor_enrolment.dart`), `TomDataSource`, `TomDataSourceInfo`, `TomFrameworkTable` (the single declaration of `tom_oauth_state`, `tom_scim_resource`, `tom_service_account` and `tom_api_key`), `TomSchemaProvisioning` and `sqlInstant` / `parseSqlInstant` |
| [endpoints](endpoints.md) | module | `jwks_endpoint.dart`, `oauth_endpoints.dart`, `saml_endpoints.dart`, `scim_endpoints.dart`, `session_cookie.dart` | `TomScimApi` declares its seventeen routes with `@TomEndpoint` and `@TomPublicAccess`; `TomSamlService` binds the identity provider's form post as a `TomMultipartForm` and answers it with a `TomRedirect`; `TomOAuthServer` implements the kernel's `tomOAuthApi` through `@TomApiImplementation`, and `registerFrameworkApis()` registers the contract; `TomJwksService` declares its route with `@TomEndpoint` and `@TomPublicAccess`; the CSRF check admits an origin `TomCors` admits |
| [little_things](little_things.md) | module | 19 of 38 files | `TomServerException`, the base of `TomLoginException`, `Tom2FAException`, `TomServerSelfLoginException`, `TomOAuthException`, `TomSamlException`, `TomScimException`, `TomSigningKeyException`, `TomJwtKeyException`, `TomApiKeyException` and `TomSessionCookieException` |
| [messaging](messaging.md) | module | `two_factor_delivered_code.dart` | `TomEmailService` and `TomSmsService` deliver the one-time codes, through `TomTemplatedMessageService.deliverNow` rather than the outbox. A deployment that registers neither can still run TOTP |
| [object_persistence](object_persistence.md) | module | `oauth_identity.dart`, `oauth_tokens.dart`, `sql_api_key_store.dart`, `sql_oauth_state_store.dart`, `sql_scim_store.dart`, `two_factor_enrolment.dart` | `TomExternalIdentityLink` and `TomUserTwoFactorEnrolment` are ordinary entities over `TomSqlDatasourceRepository`. Neither table is created by the framework; each entity carries its own `createTableSql` for a deployment's migration to run |
| [preferences](preferences.md) | module | `authentication_server.dart` | `TomUserPreferences` |
| [privacy](privacy.md) | module | `two_factor_enrolment.dart` | `TomDataSubject` and `TomPersonal`, which declare `TomUserTwoFactorEnrolment`'s principal and its hint to erasure, export and audit sealing |
| [resources](resources.md) | module | `two_factor_delivered_code.dart` | no user-facing text originates in this module |
| [server](server.md) | module | `scim_endpoints.dart` | `TomEndpointCredentials`, which `TomScimProvisioning.install` claims `/scim/v2/` in |
| [tenancy](tenancy.md) | module | `sql_api_key_store.dart`, `sql_oauth_state_store.dart` | `TomTenantData`, so a purged tenant's API keys, service accounts and pending sign-ins are deleted |

- **Server** (this package): `TomServerChannel` carries the default self-login
  transport, and `TomServer` calls `loginAndInstall` before binding its socket;
  `TomServer.configureSecurity` installs `TomSessionCookie.current` from the
  `sessionCookie` key, and `tomDefaultAuthenticationMiddleware` reads the cookie
  and runs the CSRF check.
- **Bean Locator** (kernel): `Tom2FAPolicy` and `Tom2FAEnrolmentStore` are
  resolved by type through `TomBean`, which is what makes both of them
  swappable without a configuration key.
