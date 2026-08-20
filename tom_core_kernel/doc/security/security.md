# Tom Framework Security Module

The security module provides a comprehensive authentication and authorization system for the Tom framework. It supports multiple authorization paradigms and integrates seamlessly with JWT-based bearer token authentication.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [Authentication](#authentication)
  - [Authorization](#authorization)
  - [Access Control](#access-control)
- [UI Authorization (Four-State Model)](#ui-authorization-four-state-model)
  - [TomAuthState](#tomauthstate)
  - [TomAuthorizable](#tomauthorizable)
  - [TomAuthorizationGroup](#tomauthorizationgroup)
  - [TomAuthorization (Global Singleton)](#tomauthorization-global-singleton)
  - [TomAuthorizer](#tomauthorizer)
  - [TomUIStateController](#tomuistatecontroller)
- [The Server Principal and the Meet](#the-server-principal-and-the-meet)
- [External Identity (OAuth 2.0 / OIDC)](#external-identity-oauth-20--oidc)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

The security module consists of these main files:

| File | Purpose |
| ---- | ------- |
| `access_controls.dart` | Access control types and resource protection |
| `authentication_authorization.dart` | Authentication message DTOs |
| `bearer_authentication.dart` | JWT token management |
| `user_principal_aci.dart` | User, principal, and ACI types |
| `tom_authorization.dart` | UI authorization primitives — the four-state model, groups, authorizers, and the global authorization singleton |
| `two_factor.dart` | The shared half of the two-pass login — the challenge and enrolment wire shapes, their claim names, the method descriptor, and the TOTP primitives |
| `server_principal.dart` | The ambient server principal — the deployment's own identity, which caps every user's grants |
| `oauth_contract.dart` | The wire contract for external-identity login — the provider/authorization/callback DTOs and the `/oauth` API declaration both tiers bind to |

### Key Concepts

- **User**: Basic identity information (name, email, etc.)
- **Principal**: Authenticated session with full context
- **ACI (Access Control Information)**: Roles, groups, entitlements, resource keys
- **CLI (Client Limits Information)**: Quotas and feature flags
- Both ACI and CLI are **read-only once constructed**: each copies what its
  constructor is given and hands out unmodifiable views, so a caller can neither
  edit a grant nor raise a quota by writing to the object it was handed. Both are
  decided by whoever issued the principal. To apply new values, build a new
  instance
- **2FA Challenge**: A pending second factor, carried in an interim token's
  public claims between pass 1 and pass 2 of a login
- **2FA Enrolment**: The same interim-token mechanism one step earlier — the
  user owes a factor and has none, so the login offers the chance to *set one
  up* before completing. See [Drive 2FA from the Challenge, Not from the
  Type](#6-drive-2fa-from-the-challenge-not-from-the-type)
- **Server Principal**: The *deployment's* own grants. Every decision is
  `min(user, deployment)` — see [The Server Principal and the
  Meet](#the-server-principal-and-the-meet)
- **External Identity**: A principal resolved by an OAuth 2.0 / OIDC provider
  instead of by a password — and then treated identically, second factor
  included. See [External Identity](#external-identity-oauth-20--oidc)

---

## Quick Start

### 1. Set Up Authentication

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Create authentication request
var message = TomAuthenticationMessage()
  ..userName = 'john.doe'
  ..password = 'secret'
  ..application = 'myapp';

// Send to server and get result
var result = await authService.authenticate(message);

// Store tokens on success
if (result.error.isEmpty) {
  TomBearerAuthentication.setTokens(
    result.authenticationToken,
    result.authorizationToken,
  );
}
```

### 2. Access Current User

```dart
// Get the authenticated principal
var principal = TomBearerAuthentication.getPrincipal();

// Access user info
print('Hello, ${principal.user.firstname}!');
print('Roles: ${principal.aci.roles}');
```

### 3. Protect Resources

```dart
// Using access control annotations
@TomRoleAccess(['admin'])
void adminOnly() {
  // Only admins can access this
}

// Using resource key protection
var email = tomProtect(user.email, '[hidden]', 'user.email');
```

---

## Core Components

### Authentication

#### TomAuthenticationMessage

The request DTO sent from client to server for authentication:

```dart
var message = TomAuthenticationMessage()
  ..userName = 'admin'
  ..password = 'P@ssw0rd!'
  ..application = 'web-portal'
  ..clientLanguage = 'en'
  ..clientCountry = 'US';
```

#### TomAuthenticationResult

The response DTO from the server:

```dart
if (result.error.isNotEmpty) {
  // Authentication failed
  showError(result.error);
} else if (result.requires2FAEnrolment) {
  // No usable factor yet — offer the mechanisms the server permits.
  showEnrolmentChooser(
    result.availableTwoFactorMethods,
    canSkip: result.twoFactorEnrolmentSkippable,
  );
} else if (result.requires2FA) {
  // Need two-factor authentication
  show2FADialog(result.twoFactorType);
} else {
  // Success - tokens are ready
  useTokens(result.authenticationToken, result.authorizationToken);
}
```

### Authorization

#### TomAccessControlInformation (ACI)

Groups authorization data:

| Property | Description |
| -------- | ----------- |
| `roles` | Job functions (admin, user, manager) |
| `groups` | Organizational units (can be nested) |
| `entitlements` | Fine-grained permissions |
| `resourceKeys` | Field-level access identifiers |

```dart
var aci = TomAccessControlInformation(
  roles: ['admin', 'user'],
  groups: ['engineering'],
  entitlements: ['feature.reports.view'],
  resourceKeys: ['user.email', 'user.phone'],
);
```

#### TomAccessControlDefinition

Defines the authorization schema for resolving inherited permissions:

```dart
var definition = TomAccessControlDefinition(
  roles: [
    TomRole(
      name: 'admin',
      rolesIncluded: ['user'],  // Inherits from user
      entitlements: ['admin.*'],
    ),
    TomRole(
      name: 'user',
      entitlements: ['feature.read'],
    ),
  ],
);

// Resolve complete permissions
var completeAci = definition.completeFromDefinition(userAci);
```

### Access Control

#### Built-in Access Control Types

| Type | Description |
| ---- | ----------- |
| `TomNoAccess` | Denies all access |
| `TomPublicAccess` | Allows all access |
| `TomAuthenticatedAccess` | Requires logged-in user (not guest) |
| `TomGuestAccess` | Allows guests and authenticated users |
| `TomRoleAccess` | Requires specific roles |
| `TomGroupAccess` | Requires group membership |
| `TomEntitlementAccess` | Requires specific entitlements |
| `TomResourceKeyAccess` | Requires a resource key, while protection is switched on |
| `TomCustomAccess` | Delegates to custom handler |

Each of these states a requirement on the **user**, and each answers about the
principal you hand it — `checkAccessibility(principal)` means the same thing
for every row. That is only half of an access decision: the result is met with
what the *deployment* is granted, so a control the user satisfies can still
resolve to `none`. See [The Server Principal and the
Meet](#the-server-principal-and-the-meet) — read it before debugging a refusal
you cannot explain.

`TomResourceKeyAccess` carries one extra condition the others do not: while
`TomResourceKeyProtection.globalSettingProtectionDefault` is `false` — its
default — resource keys are not enforced at all and the control grants
everyone. Turn the switch on before expecting a key to be required.

#### Resource Key Protection

Protect individual fields or resources:

```dart
// Enable protection globally
TomResourceKeyProtection.globalSettingProtectionDefault = true;

// Protect a value
var email = tomProtect(user.email, '[hidden]', 'user.email');

// Check if protected
if (!tomProtected('user.salary')) {
  showSalary(user.salary);
}
```

The rule lives in one place, `TomResourceKeyProtection.isProtectedFor`, and is
reached two ways. The helpers above — `tomProtect`, `tomProtected` and
`isProtected` — apply it to whoever the **ambient zone** names, which is what
you want at a field you are rendering for the current request. Where a
principal is already in hand, name it:

```dart
// Answers about `principal`, whatever the zone happens to hold.
if (!TomResourceKeyProtection.isProtectedFor(principal, 'user.salary')) {
  showSalary(user.salary);
}
```

This is the distinction `TomResourceKeyAccess` sits on: as an access control it
is asked about a principal, so it takes the second form. Reading the zone when
the caller has named someone answers a different question — and outside a
request zone, a fail-closed one.

---

## UI Authorization (Four-State Model)

`tom_authorization.dart` layers a **UI-facing** authorization model on top of the
ACI/access-control primitives above. Where access controls answer "may this user
perform this operation?", the UI model answers "how should this element be
presented?" — hidden, greyed out, read-only, or fully interactive. It is
construction-time and `BuildContext`-free: widgets, forms, and actions read the
global singleton directly.

### TomAuthState

The four authorization states, ordered from most to least restrictive
(`none < disabled < read < full`):

| State | Presentation |
| ----- | ------------ |
| `none` | Hidden — the element does not exist from the user's perspective |
| `disabled` | Visible but greyed out, no content; data may exist but is inaccessible |
| `read` | Shows the current value/state, read-only |
| `full` | Fully interactive and editable |

Helpers: `isVisible` (`!= none`), `isInteractive` (`== full`), `showsContent`
(`read` or `full`). Two combinators express the ordering:

```dart
// narrow → the MORE restrictive of two states
TomAuthState.full.narrow(TomAuthState.read);   // read
// widen → the LESS restrictive of two states
TomAuthState.read.widen(TomAuthState.disabled); // read
```

### TomAuthorizable

The interface implemented by anything that participates in UI authorization
(Tom widgets, actions, menu items, routes):

| Member | Description |
| ------ | ----------- |
| `String? get tomId` | Plain id used for resource lookups (`null` if it doesn't participate) |
| `TomAuthorizationGroup? get tomGroup` | The group this element belongs to, if any |
| `TomAuthState get effectiveAuthState` | The final resolved state after resource auth, group, and authorizers |

### TomAuthorizationGroup

A collection of related authorizables that share authorization control. Members
are held via `WeakReference`, so garbage-collected elements drop out
automatically. The group's path is `<scopePath>.<groupId>` (see the
[Scope IDs module](../scope_ids/scope_ids.md)).

```dart
final shipping = TomAuthorizationGroup('shipping',
    mode: AuthGroupMode.controlsAll);
shipping.register(streetField); // and shipping.unregister(streetField)
// Declaratively, in Tom Flutter UI — input widgets take the group as
// `tomGroup` and register themselves. Mind the name: form- and
// container-level widgets in that package call the same thing
// `authorizationGroup`.
// TomTextField(tomId: 'street', tomGroup: shipping, ...)
// TomTextField(tomId: 'city',   tomGroup: shipping, ...)
```

Members join and leave via `register(element)` / `unregister(element)`. The
group resolves its own state from `authState` (which looks up
`resolveGroupPath()` — `<scopePath>.<groupId>` — through `TomAuthorization`).
`AuthGroupMode` then controls how that resolved state combines with each
member's own state via `applyMode(memberState)`:

| Mode | Effect |
| ---- | ------ |
| `controlsAll` | Group state replaces the member's state |
| `controlsWidest` | Group state is the **ceiling** (narrows the member) |
| `controlsNarrowest` | Group state is the **floor** (widens the member) |

Inspection helpers all report on **visible** membership: a member whose
`effectiveAuthState` is `none` does not exist from the user's perspective, so
it does not exist for inspection either. `members` is the single place that
filter lives — every other helper is defined in terms of it, which is what
stops them from disagreeing about who is in the group.

| Member | Description |
| ------ | ----------- |
| `members` | Snapshot of the live, visible members (stale refs pruned) |
| `memberCount` / `isEmpty` / `isNotEmpty` | Size of that snapshot — a group whose members are all hidden reports empty |
| `isUniform` | `true` if all visible members share one `effectiveAuthState` |
| `mostRestrictive` | The most restrictive `effectiveAuthState` among visible members (`full` if there are none) |
| `findMember(tomId)` | The **visible** member with the given id, or `null` |

Registration is the deliberate exception: `register` / `unregister` work on the
raw registrations, so a hidden member is still tracked and can still be
removed by whoever added it.

### TomAuthorization (Global Singleton)

The app-wide entry point for resolving a resource key path to a `TomAuthState`.
Install a `TomAuthorizationAdapter` at startup; with no adapter the system
resolves to `TomAuthState.full` (development mode).

```dart
// App startup
TomAuthorization.adapter = MyAuthorizationAdapter();

// Anywhere
final state = TomAuthorization.resolveAuth('checkout.email');

// Tests
TomAuthorization.reset(); // clears the adapter
```

`TomAuthorizationAdapter` is the bridging contract — a kernel-backed adapter maps
resource-key protection to states, while test doubles return predetermined
results.

### TomAuthorizer

A per-element modifier attached to an individual widget or action. It is handed
the resource-based state and returns the element's desired state, combined
according to its `TomAuthorizerStrategy`:

| Strategy | Behaviour |
| -------- | --------- |
| `authorizerDecides` | The authorizer's result is final (may widen) |
| `authorizerNarrowsOnly` | The result is `narrow(resourceAuth, authorizerResult)` — can only restrict |

```dart
TomAuthorizer(
  strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
  resolve: (resourceAuth) => hasChanges ? resourceAuth : TomAuthState.disabled,
);
```

`effectiveAuth(resourceAuth)` computes the final state by combining the resource
state with the resolver according to the strategy. Factories:
`TomAuthorizer.fixed(state)` always returns `state`;
`TomAuthorizer.fromAction(actionAuth:)` applies the common pattern where a `full`
widget bound to a `none` action becomes `disabled` (visible but unavailable).

### TomUIStateController

A **build-time** callback that can further narrow (never widen) a widget's state
based on dynamic, possibly row-level data. Authorization runs at construction
time; the UI state controller runs later at build time:

```dart
TomUIStateController(
  resolve: (currentAuth, data) {
    if (items.isEmpty) return TomAuthState.disabled;
    if (data case {'ownerId': int id} when id != currentUserId) {
      return TomAuthState.read;
    }
    return currentAuth;
  },
);
// apply() guarantees the result never widens currentAuth.
```

---

## The Server Principal and the Meet

Every authorization decision in the framework has **two** operands, not one. A
user's grant is met with the grant of the deployment the code is running in, and
the effective answer is the more restrictive of the two:

```text
effective = min(user grade, deployment grade)
```

over the `none < disabled < read < full` ladder — which for a plain two-state
control degenerates to a boolean AND. **The deployment's grants cap every user's
grants; they never widen them.**

### The symptom you probably arrived with

> *"The role is assigned, the entitlement is in the token, the check still
> refuses. The grant is right there."*

It is, and it is still not enough:

```dart
final control = TomEntitlementAccess(['feature.reports.export']);

// The user holds it.
user.aci.entitlements;    // ['feature.reports.export', ...]
control.checkPrincipalAccess(user);            // true  ← the user operand

// The deployment does not.
TomServerPrincipal.current!.aci.entitlements;  // ['feature.reports.view']
control.resolveServerAuthState(server);        // TomAuthState.none

control.resolveAuthState(user);                // TomAuthState.none  ← the meet
control.checkAccessibility(user);               // false
```

Nothing is wrong with the user's grant. This deployment is not licensed for the
feature, so no user of it can be — which is the point. If you are debugging a
refusal that "should" have passed, print `TomServerPrincipal.current?.aci
.entitlements` before you go looking at the user's.

### What a server principal is

A deployed server is a principal like any other client. It authenticates against
the auth server with a service credential and gets back a token; that token
reconstructs a `TomPrincipal` whose entitlements are **the feature grants of
this deployment**. `TomServerPrincipal` is the process-wide holder for it:

| Member | Purpose |
| ------ | ------- |
| `TomServerPrincipal.current` | The deployment's principal, or `null` when this process never logged itself in. |
| `TomServerPrincipal.isConfigured` | Whether a principal has been installed. |
| `TomServerPrincipal.install(principal)` | Installs it for the rest of the process. Re-installing is intended — a long-running server re-authenticates before its service token expires. |
| `TomServerPrincipal.clear()` | Returns the process to the uncapped regime. For tests and orderly shutdown. |

It is a process-wide static rather than a zone value on purpose. The kernel
already carries the *user* principal in the current zone, one per in-flight
request, and the server principal has to be readable from **inside** those same
zones — where that slot is taken. It is also genuinely process-scoped: one
deployment, one identity, resolved once at startup.

The server side of the login is `tom_core_server`'s `TomServerSelfLogin`; see
its `doc/authentication.md` §"Server Self-Login" for the credential and the
lifecycle.

### Unconfigured is a supported state, and `null` is not an empty principal

A deployment that never logs itself in leaves `TomServerPrincipal` empty, and
evaluation then returns the user's grade alone — byte-for-byte the behaviour of
every deployment built before server-as-principal existed. That is the designed
default, not a failure mode.

This is why the evaluation path tests `TomServerPrincipal.current` for `null`
rather than evaluating against a blank principal. The two are **opposites**:

| State | Meaning | Effect |
| ----- | ------- | ------ |
| `null` | No deployment cap applies | Everything the user holds |
| Principal with no entitlements | This deployment is entitled to nothing | Every entitlement check denies |

Never substitute one for the other. And note the direction of `clear()`: it
*widens* access, so it is never the right response to an expired service token —
re-`install` instead.

### Where each operand comes from

`TomAccessControl` splits the two operands into separate hooks, and computes the
meet in a public method that subclasses **cannot** override — a cap any subclass
could sidestep by overriding the method everyone already calls would not be a
cap at all.

| Member | Operand | Notes |
| ------ | ------- | ----- |
| `checkPrincipalAccess(principal)` | User | What this control demands of the caller. Subclasses implement this. |
| `resolvePrincipalAuthState(principal)` | User | The four-state view; defaults to bridging the boolean above onto `full`/`none`. |
| `resolveServerAuthState(serverPrincipal)` | Deployment | What grade this control's subject is granted to the deployment. Defaults to `TomAuthState.full` — *uncapped*. |
| `resolveAuthState(principal)` | **Both** | The meet. `@nonVirtual`. |
| `checkAccessibility(principal)` | **Both** | `resolveAuthState(...).showsContent`. `@nonVirtual`. |

The `full` default on `resolveServerAuthState` is the correct answer, not a
lenient shortcut: a control naming a user role, a group or a resource key
expresses nothing about which *features* a deployment licenses, so it has no
opinion to contribute — and a participant with no opinion must return the
identity element. Anything lower would let an unrelated deployment grant
silently veto a role check.

**`TomEntitlementAccess` is the grant carrier.** Entitlements are the one
requirement kind that means the same thing on both sides of the meet: asked
about a user, "may this person use the feature"; asked about the server
principal, "is this deployment licensed for the feature at all". Same pattern
set, other principal — which is why server-level grants needed no new class.
`TomGradedAccess` composes its children's deployment answers into the same
ladder, so a feature the deployment only partly licenses can still resolve to
`read`.

**Seeing it happen.** The advanced full-stack sample runs a back-office server
whose service account holds one grant more than the process is capped for, and
asserts both halves of the claim in a connection-free suite: the same principal,
holding the same entitlement, refused under the cap and allowed the moment it is
lifted. A refusal on its own proves nothing — it is indistinguishable from a
missing entitlement — which is why the assertions come in pairs and the only
thing that varies between them is the installed `TomServerPrincipal`. See
`tom_core_samples/advanced_ops_server/test/ops_authorization_meet_test.dart` and
the narrative in
[`README_advanced_14_operations.md`](../../../tom_core_samples/README_advanced_14_operations.md).

---

## External Identity (OAuth 2.0 / OIDC)

"Sign in with …" is **not a second login path.** An OAuth provider *resolves a
principal*; everything after the principal is resolved — the second-factor
policy, the enrolment offer, token issuance, grant resolution — is the one login
path every credential reaches.

That decision is visible in this module's contract in a single place, and it is
the one thing to read the file for: the callback endpoint answers with
[`TomAuthenticationResult`](#tomauthenticationresult), the *same* type `/login`
answers with, carrying the same token pair, the same `requires2FA` handshake and
the same enrolment offer. A distinct "OAuth result" type here would be the first
step towards a second token issuer — and the copy that drifts is the one that
stops asking for a second factor.

### What lives here, and what does not

The *flow* is server-side and cannot live in the kernel: it needs a client
secret, a call to the provider's token endpoint, and a linking table. What has
to live here is the part the two tiers must agree on (G-API-1, G-API-3):

| Here (kernel) | There (`tom_core_server`) |
| ------------- | ------------------------- |
| `TomOAuthProviderDto` — a provider as a client sees it | Issuer URLs, client ids, secrets, scopes |
| `TomOAuthAuthorizationRequest` / `TomOAuthAuthorizationDto` | PKCE generation, the pending-state store |
| `TomOAuthCallbackRequest` | Code exchange, id_token claim extraction |
| `tomOAuthApi` (`/oauth`, three public endpoints) | The endpoint implementations |
| `TomOAuthApiService` — the Dart shape both sides bind to | The linking table and provisioning policy |

Provider *configuration* is data on the server (`oauth.providers` in the
configuration module), never code; see `tom_core_server`'s
`doc/authentication.md` for the YAML, the `refuse` / `autoProvision` choice, and
the handshake's verification steps.

### The endpoints

| Endpoint | Method | Request → Response |
| -------- | ------ | ------------------ |
| `/oauth/providers` | GET | — → `List<TomOAuthProviderDto>` |
| `/oauth/authorize` | POST | `TomOAuthAuthorizationRequest` → `TomOAuthAuthorizationDto` |
| `/oauth/callback` | GET | `TomOAuthCallbackRequest` → `TomAuthenticationResult` |

All three are `TomPublicAccess`, and necessarily so: this is how a caller who is
*not yet* authenticated becomes authenticated, exactly like `/login`. Public does
not mean unguarded — the flow is protected by the `state` handle (single-use,
server-issued, TTL-bounded) and the PKCE verifier, neither of which a caller
supplies.

`/oauth/callback` is a `GET` with no body because the provider redirects a
*browser* to it: everything arrives in the query string. The endpoint's
`urlParameterMapping` binds those parameters into the typed DTO and is the one
place the provider's snake_case spelling (`error_description`) appears.

### Driving it from a client

```dart
registerTomOAuthApi();

// 1. Offer the buttons. Both keys are resource keys, not text — render them
//    through the resource module in the user's language.
final providers = await api.listOAuthProviders();

// 2. Start a flow. Send the login context now: the provider's redirect is a
//    plain browser navigation and carries none of it.
final authorization = await api.beginOAuthAuthorization(
  TomOAuthAuthorizationRequest(
    providerId: providers.first.id,
    client: 'flutter',
    application: 'web-portal',
    organization: 'acme',
    clientLanguage: 'en',
    clientCountry: 'US',
    clientTimezone: 'Europe/Berlin',
  ),
);

// 3. Navigate to authorization.authorizationUri. Keep authorization.state only
//    to correlate the redirect you observe with the flow you started — it is
//    not a credential and presenting it authenticates nothing.
```

The response to the callback is an ordinary login result, so **handle it with
the ordinary login code** — including the 2FA block in [Best Practice
6](#6-drive-2fa-from-the-challenge-not-from-the-type). An externally
authenticated principal is challenged for its second factor exactly like a
password login, because nothing about the path is different once the principal
exists.

Two things the client deliberately cannot do: it never names a **redirect URI**
(a redirect target a caller may choose is an open redirect — an attacker who can
name it has the provider deliver a live authorization code to a host they own),
and it never sees an issuer, client id, secret or scope.

---

## Usage Examples

### Role-Based Access Control

```dart
// Single role required
@TomRoleAccess(['admin'])
void deleteAllUsers() {
  // Only admins
}

// Multiple roles (OR logic)
@TomRoleAccess(['admin', 'manager'])
void viewReports() {
  // Admins OR managers
}

// Check programmatically
var access = TomRoleAccess(['admin']);
if (access.checkAccessibility(principal)) {
  showAdminPanel();
}
```

### Entitlement-Based Access Control

```dart
// Exact match
@TomEntitlementAccess(['feature.reports.view'])
Widget reportsButton() { ... }

// Pattern matching (regex)
@TomEntitlementAccess([r'feature\.reports\..*'])
Widget anyReportsAccess() { ... }
```

### Custom Access Control

```dart
// Register a custom handler
TomCustomAccess.registerHandler('canEditDocument', (principal, docId) {
  if (principal == null) return false;
  return DocumentService.isOwner(principal.id, int.parse(docId));
});

// Use the custom handler
@TomCustomAccess(handler: 'canEditDocument', resourceId: '123')
void editDocument() { ... }
```

### Token Management

```dart
// Set tokens after login
TomBearerAuthentication.setTokens(authToken, authzToken);

// Get current tokens
var token = TomBearerAuthentication.token;
var authzToken = TomBearerAuthentication.authorizationToken;

// Update permissions without re-login
TomBearerAuthentication.updatePrincipal(
  ['new-group'],
  ['new-role'],
  ['new-entitlement'],
  ['new-resource-key'],
);
```

---

## Best Practices

### 1. Choose One Authorization Paradigm

While mixing approaches is supported, it's cleaner to use one:

- **Simple apps**: Public vs. authenticated
- **Enterprise apps**: Role-based (RBAC)
- **Fine-grained control**: Entitlement-based
- **Field-level security**: Resource keys

### 2. Define Clear Role Hierarchies

```dart
var definition = TomAccessControlDefinition(
  roles: [
    TomRole(name: 'superadmin', rolesIncluded: ['admin']),
    TomRole(name: 'admin', rolesIncluded: ['user']),
    TomRole(name: 'user', entitlements: ['basic.access']),
  ],
);
```

### 3. Use Meaningful Entitlement Names

Follow a hierarchical naming convention:

```text
module.feature.action
billing.invoices.create
reports.sales.view
admin.users.delete
```

### 4. Validate Custom Handlers at Startup

```dart
void validateAccessHandlers() {
  var customAccesses = [
    TomCustomAccess(handler: 'canEditDoc', resourceId: ''),
    TomCustomAccess(handler: 'canDeleteUser', resourceId: ''),
  ];
  
  for (var access in customAccesses) {
    if (!access.verifyHandler()) {
      throw StateError('Missing handler: ${access.handler}');
    }
  }
}
```

### 5. Protect Sensitive Fields

Use resource keys for PII and sensitive data:

```dart
// In your user serialization
'email': tomProtect(user.email, null, 'user.email'),
'phone': tomProtect(user.phone, null, 'user.phone'),
'salary': tomProtect(user.salary, null, 'user.salary'),
```

### 6. Drive 2FA from the Challenge, Not from the Type

A login that owes a second factor comes back from pass 1 as an **interim token
pair** carrying a [Tom2FAChallenge] in its public claims. Install it like any
other token pair and ask the kernel what is pending:

```dart
var result = await api.login(message);
TomBearerAuthentication.setTokens(
  result.authenticationToken,
  result.authorizationToken,
);

var challenge = TomBearerAuthentication.pendingTwoFactorChallenge;
if (challenge != null) {
  // challenge.type / .hint / .attemptsRemaining / .expiresAt / .clientData
  // carry everything the second-factor UI needs.
  final code = await promptForCode(challenge);
  // The interim token is the ambient bearer, so the pass-2 call presents it.
  result = await api.loginPass2(message..password = code);
  TomBearerAuthentication.setTokens(
    result.authenticationToken,
    result.authorizationToken,
  );
}
// pendingTwoFactorChallenge == null → the login is complete, and the token pair
// is the same one a login with no second factor would have produced.
```

Three things this buys over branching on `result.twoFactorType` by hand:

- **The challenge, not the type, drives the UI.** `hint`, `attemptsRemaining`
  and `expiresAt` are what a user needs to see, and `clientData` carries
  whatever else the mechanism wants to say. Switching on the type alone throws
  all of that away. `expiresAt` is always UTC — the constructor normalises it,
  so a countdown may subtract it from `DateTime.now()` directly and two clients
  in different zones agree about when the challenge dies.
- **A wrong code is a loop, not a restart.** With attempts left, pass 2 answers
  with a *fresh* interim token whose attempt counter has advanced, so the block
  above simply repeats. Only an exhausted or expired challenge sends the client
  back to pass 1 — and then `pendingTwoFactorChallenge` is `null`, so the code
  above cannot mistake it for a completed login.
- **A stale token reads as no challenge.** The getter applies the expiry and
  attempt checks itself, so a client that slept, or sat in a background tab,
  and woke holding a lapsed interim token gets `null` and restarts at pass 1
  rather than prompting for a code the server will refuse. The guarantee is the
  kernel's, not a consequence of the server happening to re-issue in time.
  [Tom2FAChallenge.fromClaims] does *not* filter — it stays a pure decoder of
  the wire format, because the server has its own authoritative clock and runs
  its own checks.
- **The interim token is not a session.** Its `requires2FA` claim makes
  [TomBearerAuthentication.convertTokenPayloadToPrincipal] build a principal
  with `authenticated == false`, so holding it never passes an authentication
  guard. It is a challenge carrier and nothing more.

**When the user has no factor yet.** A deployment whose policy demands a second
factor from someone who has never set one up does not reject the login — it
offers the set-up *inside* the login that demanded it. That leg uses the same
interim-token mechanism, so the client reads it the same way, through
[TomBearerAuthentication.pendingTwoFactorEnrolment]:

```dart
var enrolment = TomBearerAuthentication.pendingTwoFactorEnrolment;
while (enrolment != null) {
  if (!enrolment.hasOffer) {
    // Choosing: render enrolment.offeredTypes, or the descriptors in
    // result.availableTwoFactorMethods, which carry the text keys for them.
    // enrolment.skippable → show a "not now" affordance, which posts
    // skipTwoFactorEnrolment; enrolment.skipSpendsGrace → say that declining
    // costs one of the remaining grace logins.
    result = await api.beginTwoFactorEnrolment(message..password = chosenType);
  } else {
    // Confirming: enrolment.clientData carries the mechanism's set-up material
    // (for TOTP the base32 secret and the otpauth:// URI to scan), and
    // .attemptsRemaining / .expiresAt are what the panel shows.
    final code = await promptForSetupCode(enrolment);
    result =
        await api.completeTwoFactorEnrolment(message..password = code);
  }
  TomBearerAuthentication.setTokens(
    result.authenticationToken,
    result.authorizationToken,
  );
  enrolment = TomBearerAuthentication.pendingTwoFactorEnrolment;
}
// pendingTwoFactorEnrolment == null → nothing further is owed on this leg.
```

Four things follow from reading it this way rather than from tracking the stage
by hand:

- **One type covers both stops.** `hasOffer` is the whole distinction between
  *choose a mechanism* (`offeredTypes` populated, `type` empty) and *confirm
  this one* (`type` named, `clientData` filled). A client holding a token does
  not have to remember which pass produced it.
- **A wrong confirmation code is a loop, not a restart** — exactly as it is for
  a challenge. `attempt` advances in a fresh interim token and the block above
  repeats. The loop terminates on a lapsed or burned offer because the getter
  filters those out, the same way `pendingTwoFactorChallenge` does. One
  difference, and it is the same one that makes `expiresAt` nullable here: the
  attempt budget belongs to the *mechanism's* offer, so the choosing stop is
  never filtered out for exhaustion — a chooser owes no attempts, because
  nothing has been generated to attempt yet.
- **A skip is the server's decision.** `skippable` was decided on the pass that
  made the offer and is carried in the signed token, so a client that shows a
  "not now" button anyway achieves nothing: the server checks the same claim
  again. `skipSpendsGrace` says whether declining is free (an optional policy)
  or costs one of the principal's remaining grace logins (a required one).
- **Confirming completes the login outright.** A user who has just derived a
  code from the secret they were handed has demonstrated possession; there is no
  challenge afterwards. `pendingTwoFactorEnrolment` and
  `pendingTwoFactorChallenge` both answering `null` is the signal that the token
  pair is a real session.

**The text is never in the payload.** `result.availableTwoFactorMethods` carries
`Tom2FAMethodDescriptor`s, and a descriptor is an identifier plus three
*resource keys* — never words (G-RES-1). `Tom2FAMethodDescriptor.scoped(type)`
derives them all under the one scope:

| Field | For `scoped('totp')` | Rendered as |
| ----- | -------------------- | ----------- |
| `type` | `'totp'` | Not shown — the key posted back to `beginTwoFactorEnrolment` |
| `displayNameKey` | `two_factor.totp.name` | The option's label |
| `descriptionKey` | `two_factor.totp.description` | The sentence under it |
| `iconKey` | `two_factor.totp.icon` | Whatever the client's icon set calls it |

So the client resolves the three keys against the user's locale, and the same
deployment serves a login dialog in every language its resource bundle covers.
Rendering `descriptor.type` directly would put an internal identifier on screen;
hard-coding "Authenticator app" beside it would put one locale's English there
permanently.

`Tom2FAChallenge`, `Tom2FAPendingEnrolment`, their claim-name namespaces
(`Tom2FAClaims`, `Tom2FAEnrolmentClaims`), `Tom2FAMethodDescriptor` and
`TomTotp` live in this module because both tiers must agree on them exactly.
The server half — the adaptor registry, the mechanisms, the enrolment store and
the passes — is `tom_core_server`'s authentication module; see its
`doc/authentication.md` for wiring a second factor and for what the server does
with the encrypted half of the same token.

### 7. Refresh Permissions Appropriately

Permissions may change during a session:

```dart
// Periodically refresh from server
void refreshPermissions() async {
  var newAci = await fetchCurrentPermissions();
  TomBearerAuthentication.updatePrincipal(
    newAci.groups,
    newAci.roles,
    newAci.entitlements,
    newAci.resourceKeys,
  );
}
```

---

---

## Dependencies

This module depends on:

- **Crypto Module**: JWT token generation and parsing
- **Observable Module**: Reflection annotations for DTOs
- **Little Things Module**: Zone-based utilities
- **Scope IDs Module**: `TomScope` path resolution for `TomAuthorizationGroup`
- **HTTP Connection Module**: `TomApi` / `TomApiEndpoint` and `TomHttpMethod`
  for the external-identity contract in `oauth_contract.dart`
