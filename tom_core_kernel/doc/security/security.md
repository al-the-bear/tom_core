# Tom Framework Security Module

The security module provides a comprehensive authentication and authorization system for the Tom framework. It supports multiple authorization paradigms and integrates seamlessly with JWT-based bearer token authentication.

## Table of Contents

- [Overview](#overview)
  - [Key Concepts](#key-concepts)
- [Quick Start](#quick-start)
  - [1. Set Up Authentication](#1-set-up-authentication)
  - [2. Access Current User](#2-access-current-user)
  - [3. Protect Resources](#3-protect-resources)
- [Core Components](#core-components)
  - [Authentication](#authentication)
    - [TomAuthenticationResult](#tomauthenticationresult)
  - [Identity](#identity)
    - [TomUser](#tomuser)
  - [Authorization](#authorization)
    - [TomClientLimitsInformation](#tomclientlimitsinformation)
  - [Access Control](#access-control)
    - [Built-in Access Control Types](#built-in-access-control-types)
    - [Graded Access (all four states)](#graded-access-all-four-states)
    - [Resource Key Protection](#resource-key-protection)
    - [Automatic Protection](#automatic-protection)
- [UI Authorization (Four-State Model)](#ui-authorization-four-state-model)
  - [TomAuthState](#tomauthstate)
  - [TomAuthorizable](#tomauthorizable)
  - [TomAuthorizationGroup](#tomauthorizationgroup)
  - [TomAuthorization (Global Singleton)](#tomauthorization-global-singleton)
  - [Per-Resource Roles (the shipped adapter)](#per-resource-roles-the-shipped-adapter)
  - [TomAuthorizer](#tomauthorizer)
  - [TomUIStateController](#tomuistatecontroller)
- [The Server Principal and the Meet](#the-server-principal-and-the-meet)
  - [The symptom you probably arrived with](#the-symptom-you-probably-arrived-with)
  - [What a server principal is](#what-a-server-principal-is)
  - [Unconfigured is a supported state, and `null` is not an empty principal](#unconfigured-is-a-supported-state-and-null-is-not-an-empty-principal)
  - [Where each operand comes from](#where-each-operand-comes-from)
- [External Identity (OAuth 2.0 / OIDC)](#external-identity-oauth-20--oidc)
  - [What lives here, and what does not](#what-lives-here-and-what-does-not)
  - [The endpoints](#the-endpoints)
  - [Driving it from a client](#driving-it-from-a-client)
- [Usage Examples](#usage-examples)
  - [Role-Based Access Control](#role-based-access-control)
  - [Entitlement-Based Access Control](#entitlement-based-access-control)
  - [Custom Access Control](#custom-access-control)
  - [Token Management](#token-management)
- [Best Practices](#best-practices)
  - [1. Choose One Authorization Paradigm](#1-choose-one-authorization-paradigm)
  - [2. Define Clear Role Hierarchies](#2-define-clear-role-hierarchies)
  - [3. Use Meaningful Entitlement Names](#3-use-meaningful-entitlement-names)
  - [4. Validate Custom Handlers at Startup](#4-validate-custom-handlers-at-startup)
  - [5. Protect Sensitive Fields](#5-protect-sensitive-fields)
  - [6. Drive 2FA from the Challenge, Not from the Type](#6-drive-2fa-from-the-challenge-not-from-the-type)
  - [7. Refresh Permissions Appropriately](#7-refresh-permissions-appropriately)
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
| `resource_role_authorization.dart` | Per-principal-per-resource roles — the role→state registry and the one `TomAuthorizationAdapter` the kernel ships |
| `two_factor.dart` | The shared half of the two-pass login — the challenge and enrolment wire shapes, their claim names, the method descriptor, and the TOTP primitives |
| `server_principal.dart` | The ambient server principal — the deployment's own identity, which caps every user's grants |
| `oauth_contract.dart` | The wire contract for external-identity login — the provider/authorization/callback DTOs and the `/oauth` API declaration both tiers bind to |

This document explains the module by *concept* and shows the calls each concept
is used through. It is not an exhaustive member list: for the full signature of
every public type —
including the ones named only in passing here — see
[`api_summary_security.md`](../api_reference/api_summary_security.md).

### Key Concepts

- **User** (`TomUser`): Basic identity information (name, email, etc.) — see
  [TomUser](#tomuser)
- **Principal** (`TomPrincipal`): Authenticated session with full context
- **ACI (Access Control Information)** (`TomAccessControlInformation`): Roles,
  groups, entitlements, resource keys, and resource *roles*
- **Resource Role**: A role scoped to a *single* resource rather than to the
  principal as a whole, so one user can be `owner` of one project and `viewer`
  of another at the same time. See [Per-Resource
  Roles](#per-resource-roles-the-shipped-adapter)
- **CLI (Client Limits Information)** (`TomClientLimitsInformation`): Quotas and
  feature flags — see [TomClientLimitsInformation](#tomclientlimitsinformation)
- The principal's three parts — user, ACI and CLI — are **read-only once
  constructed**: each copies what its constructor is given and hands out
  unmodifiable views, so a caller can neither edit a grant, nor raise a quota,
  nor rewrite an identity by holding on to the collection it passed in. All
  three are decided by whoever issued the principal. To apply new values, build
  a new instance
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

This module declares the authentication DTOs; the exchange itself runs over
`TomServerEndpoint` from the `http_connection` module. A login addresses
`TomClientRemoteContext.current!.authenticationUri` — the authentication server,
which differs from the API base URI only in a split deployment — and sends no
bearer token, because establishing one is the point of the call.

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Build the endpoint. This opens no connection; the channel creates its HTTP
// client on the first call.
var endpoint =
    TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>(
      TomServerChannel('auth.example.com', 443),
      TomServerCallSpecs(
        'POST',
        Uri.parse('https://auth.example.com/authenticate'),
        includeBearerAuthentication: false,
      ),
    );

// Create authentication request
var message = TomAuthenticationMessage()
  ..userName = 'john.doe'
  ..password = 'secret'
  ..application = 'myapp';

// Send to server and get result
var (result, error) = await endpoint.send(message);

// Store tokens on success
if (!(error?.hasError ?? false) && result.error.isEmpty) {
  TomBearerAuthentication.setTokens(
    result.authenticationToken,
    result.authorizationToken,
  );
}
```

The two failure channels are distinct: `error` reports that the *call* did not
succeed (refused connection, expired deadline, HTTP error), while
`result.error` reports that the call succeeded and the server declined the
credentials. A client that checks only one of them will treat an unreachable
server as a successful login.

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

// Using resource key protection — the master switch is off by default,
// so without this line tomProtect returns the real value every time.
TomResourceKeyProtection.globalSettingProtectionDefault = true;
var email = tomProtect(user.email, '[hidden]', 'user.email');
```

See [Resource Key Protection](#resource-key-protection) for what the switch
turns on, and [Protect Sensitive Fields](#5-protect-sensitive-fields) for the
fail-closed behaviour it brings with it.

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

### Identity

#### TomUser

The identity half of a principal — who the user *is*, as opposed to what they
may do. Authentication produces one; every authorization type in this document
takes the principal that carries it and never the user directly.

```dart
var user = TomUser(
  id: 123,
  username: 'jdoe',
  firstname: 'John',
  lastname: 'Doe',
  email: 'john.doe@example.com',
  timezone: 'America/New_York',
  attributes: {'department': 'Engineering'},
);
```

Only `id` and `username` always have a value — `id` defaults to `-1` and
`username` to `TomUser.guestUsername` (`'GUEST'`). The eleven name, contact and
locale fields are all nullable, so an identity from a provider that supplied
nothing but a login name is a normal `TomUser`, not a broken one. `attributes`
is never null either, merely empty by default; it carries whatever the
deployment needs that the fixed fields do not cover.

You rarely construct one. Read it off the principal instead, which also
forwards the two fields that are always there:

```dart
var principal = TomBearerAuthentication.getPrincipal();

principal.user.email;    // the full identity
principal.username;      // == principal.user.username
principal.id;            // == principal.user.id
```

Guests are not a separate type. An unauthenticated session carries a real
`TomUser` whose username is the sentinel, which is what
[`TomGuestAccess`](#built-in-access-control-types) tests for:

```dart
if (user.username == TomUser.guestUsername) promptLogin();
```

**Read-only once constructed.** There are no setters, and `attributes` hands
out an unmodifiable view of a map the constructor copied — so a caller that
keeps a reference to the map it passed in cannot edit the identity afterwards.
This is the same contract as ACI and CLI: to change an identity, issue a new
one.

**Identity fields are resource-key protected on the way into a token.**
`convertPrincipalToTokenPayload` runs every optional field through
[`TomResourceKeyProtection.protectFor`](#resource-key-protection) under the key
`tom.user.<field>` — `tom.user.email`, `tom.user.phone`,
`tom.user.attributes`, and so on — falling back to `null` (or `const {}` for
attributes) when the key is protected. Three fields are *not* filtered and
always travel in the clear: `username`, `id` and `timezone`. Note the prefix:
`tom.user.email` is a different key from the `user.email` used as an
application-level example elsewhere in this document, and protecting one does
not protect the other.

**The subject's own keys decide, not the ambient zone's.** The operand is the
principal the token is being minted *for*. That is what makes the filter usable
on the login path, which is where tokens are actually minted: the subject is
being authenticated at that moment, so no principal is installed on the zone
yet, and the zone-reading form ([`tomProtect`](#resource-key-protection)) is
fail-closed on an empty zone — with protection switched on it would blank every
protected field of every token the server issues.

Runnable:
[`example/samples/security/01_user_principal_example.dart`](../../example/samples/security/01_user_principal_example.dart).

### Authorization

#### TomAccessControlInformation (ACI)

Groups authorization data:

| Property | Description |
| -------- | ----------- |
| `roles` | Job functions (admin, user, manager) |
| `groups` | Organizational units (can be nested) |
| `entitlements` | Fine-grained permissions |
| `resourceKeys` | Field-level grants — exact keys, `prefix.*` and `*` (see [Resource Key Protection](#resource-key-protection)) |
| `resourceRoles` | `resourceKey → roleName` — the principal's role on each *individual* resource |

```dart
var aci = TomAccessControlInformation(
  roles: ['admin', 'user'],
  groups: ['engineering'],
  entitlements: ['feature.reports.view'],
  resourceKeys: ['user.email', 'user.phone'],
  resourceRoles: {'project.apollo': 'owner', 'project.gemini': 'viewer'},
);
```

The first four are flat lists that describe the principal *everywhere*.
`resourceRoles` is the odd one out: it is a map, and each entry scopes a role to
one resource, which is what lets the same principal hold different rights on two
projects at once. It is resolved by a different mechanism from the other four —
see [Per-Resource Roles](#per-resource-roles-the-shipped-adapter).

#### TomClientLimitsInformation

The principal's third part, beside the user and the ACI, and the one that
answers a different question. The ACI says what this *user* is permitted; the
CLI says what this *client* has bought. Both must allow an action:

```dart
var cli = TomClientLimitsInformation(
  enabledModules: ['core', 'reporting'],
  quotas: {'api_calls': 1000, 'storage_mb': 500},
);

// The user is a reporting admin, but the subscription has no reporting module.
principal.aci.roles.contains('reporting.admin');       // true
principal.cli.enabledModules.contains('reporting');    // false → no feature
```

It holds two collections and nothing else — `enabledModules`, a list of module
names the subscription turns on, and `quotas`, a `name → limit` map. Neither is
enforced by the kernel: nothing counts your API calls or refuses the 1001st.
The kernel carries the ceiling and the feature list to where the application can
read them; comparing usage against a quota is the application's job.

```dart
if (currentUsage < (principal.cli.quotas['api_calls'] ?? 0)) {
  // allow the call
}
```

Like the ACI, it is read-only once constructed — the constructor copies its
arguments and the getters return unmodifiable views, so a caller cannot raise
its own ceiling by writing to the object it was handed.

**Where the values come from.** At login, the application's authentication
service builds them on the principal it returns — the same call that answers the
ACI. When a `TomClientLimitsProvider` is installed, `tom_core_server` asks it
instead, before it mints the tokens: the provider is the seam a subscription
service (Tom SQM) fills, so that what a client bought is answered by the service
that sells it. The framework ships the contract, the installation point and the
places that ask it — no implementation. Neither the kernel nor `tom_core_server`
holds a subscription store or reads the environment for these.

```dart
class SqmClientLimits extends TomClientLimitsProvider {
  @override
  Future<TomClientLimitsInformation?> clientLimitsFor(
    TomPrincipal principal,
  ) async => null; // the subscription service's answer, or null for "no answer"
}

TomClientLimitsProvider.installed = SqmClientLimits();
```

A provider answering `null` leaves the limits the principal already carries, and
a provider that fails at login is logged and the authentication service's answer
is minted — an unreachable subscription service does not stop every sign-in.

From there they ride in the **public** half of the JWT, as the claims
`subscription_enabledModules` and `subscription_quotas`, and are read back into
`principal.cli` when the token is parsed. The token therefore carries a
**login-time snapshot**, readable by anyone holding it. A client revises its copy
mid-session the way it revises the ACI:

| Call | Does |
| ---- | ---- |
| `TomBearerAuthentication.refreshClientLimits()` | asks the installed provider for the current principal and replaces `cli` with the answer; `false` when there is no provider or no answer |
| `TomBearerAuthentication.replaceClientLimits(enabledModules:, quotas:)` | replaces `cli` with values already in hand — a server push — with the same all-`required` replacement contract as [`replacePrincipalAci`](#token-management) |

Neither re-mints the token, so a server reading limits from a request's token
sees the snapshot until the next login; a server that needs the current figures
asks the provider itself. `principal.cli` is replaced as a whole value, never
edited, which is what keeps the "read-only once constructed" rule above true.

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

The definition takes three kinds of member, one per inheritable thing an ACI
carries — `TomRole`, `TomGroup` and `TomEntitlement`. Each names itself and
lists what it pulls in, and what a kind may pull in narrows as you go down:

| Definition type | Can include | Can grant |
| --------------- | ----------- | --------- |
| `TomRole` | other roles (`rolesIncluded`), group memberships (`groupMemberShips`) | `entitlements`, `resourceKeys` |
| `TomGroup` | roles (`rolesIncluded`), other groups (`groupMemberShips`) | `entitlements`, `resourceKeys` |
| `TomEntitlement` | other entitlements (`entitlements`) | `resourceKeys` |

Only `name` is required on each; every other argument defaults to empty. So a
fuller schema uses all three:

```dart
var definition = TomAccessControlDefinition(
  roles: [
    TomRole(name: 'lead', rolesIncluded: ['analyst'],
            groupMemberShips: ['staff'], entitlements: ['reports.manage']),
    TomRole(name: 'analyst', entitlements: ['reports.read'],
            resourceKeys: ['report.summary']),
  ],
  groups: [
    TomGroup(name: 'staff', groupMemberShips: ['everyone'],
             entitlements: ['directory.view'], resourceKeys: ['user.email']),
    TomGroup(name: 'everyone', entitlements: ['login']),
  ],
  entitlements: [
    TomEntitlement(name: 'reports.manage',
                   entitlements: ['reports.read', 'reports.write'],
                   resourceKeys: ['report.total']),
  ],
);
```

`completeFromDefinition` folds an assigned ACI through all three maps until
nothing new is reached, so the single assignment `roles: ['lead']` above
resolves to two roles, two groups, five entitlements and three resource keys.
Names with no definition are not an error — they survive the fold unchanged,
which is what lets a deployment define only the parts of its vocabulary that
actually inherit.

Runnable:
[`example/samples/security/11_access_control_definition_example.dart`](../../example/samples/security/11_access_control_definition_example.dart).

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
| `TomResourceKeyAccess` | Grades a resource key — flat grant or resource role — while protection is switched on |
| `TomCustomAccess` | Delegates to a registered `TomAccessControlHandler` — see [Custom Access Control](#custom-access-control) |
| `TomGradedAccess` | **Composes** three of the above into all four states — see [Graded Access](#graded-access-all-four-states) |

The first nine each state a requirement on the **user**, and each answers about
the principal you hand it — `checkAccessibility(principal)` means the same thing
for every row. Eight of them are also two-valued: the requirement is either met
or it is not, so they resolve to `full` or `none` and never to the middle two
states. `TomResourceKeyAccess` grades instead, because a resource key can be
held through a resource role as well as a flat grant — a `viewer` role on the
key resolves to `read` (see [Resource Key
Protection](#resource-key-protection)). [`TomGradedAccess`](#graded-access-all-four-states)
composes any of them into all four states, and that is the entire purpose of
the tenth row.

Stating a requirement on the user is only half of an access decision: the result
is met with what the *deployment* is granted, so a control the user satisfies can
still resolve to `none`. See [The Server Principal and the
Meet](#the-server-principal-and-the-meet) — read it before debugging a refusal
you cannot explain.

`TomResourceKeyAccess` carries one extra condition the others do not: while
`TomResourceKeyProtection.globalSettingProtectionDefault` is `false` — its
default — resource keys are not enforced at all and the control grants
everyone. Turn the switch on before expecting a key to be required.

#### Graded Access (all four states)

Every control above answers yes or no. `TomGradedAccess` answers with a
*grade*, by composing three of them — one for each state it can grant:

```dart
final salary = TomGradedAccess(
  full: const TomRoleAccess(['payroll.admin']),
  read: const TomRoleAccess(['manager']),
  disabled: const TomAuthenticatedAccess(),
);

salary.resolveAuthState(principal);
// payroll.admin → full · manager → read · other staff → disabled
// anonymous     → none
```

Resolution walks the ladder from most to least privileged and stops at the first
child that grants: `full`, then `read`, then `disabled`, otherwise `none`.

Omitting a tier inherits the one above it — `read` defaults to `full`, and
`disabled` defaults to `read`. That keeps the ladder monotonic (whoever may edit
may also read, and whoever may read may also see), so the common case of
"editable for these people, invisible to everyone else" needs only the `full`
argument.

Binary consumers are unaffected: `checkAccessibility` is
`resolveAuthState(...).showsContent` for every control, so a `read` or `full`
outcome counts as accessible while `disabled` and `none` do not.

`TomGradedAccess` grades the *deployment* side of [the
meet](#the-server-principal-and-the-meet) too, walking the same ladder against
the server principal. A deployment licensed for a feature's view tier but not
its edit tier resolves to `read` there, which caps even an editing user down to
read.

Runnable:
[`example/samples/security/06_graded_access_example.dart`](../../example/samples/security/06_graded_access_example.dart).

#### Resource Key Protection

Protect individual fields or resources:

```dart
// Enable protection globally. This defaults to `false`, and while it is off
// every check below reports "not protected" and every value is served as-is.
TomResourceKeyProtection.globalSettingProtectionDefault = true;

// Protect a value
var email = tomProtect(user.email, '[hidden]', 'user.email');

// Check if protected
if (!tomProtected('user.salary')) {
  showSalary(user.salary);
}
```

The master switch is the first thing to get right, because the default is
fail-*open*: an application that never sets it can call `tomProtect` on every
sensitive field it has and still serve all of them. Set it once at start-up.

**What a principal holds.** A principal holds a resource key through either of
its two resource grants, and the two are one answer:

- **A flat grant** in `aci.resourceKeys` is full access. An entry is an exact
  key or a pattern:

  | Grant | Covers |
  | ----- | ------ |
  | `user.email` | exactly `user.email` |
  | `user.*` | every key under `user.` — `user.email`, `user.address.city` — but not `user`, nor `username` |
  | `*` | every key except a revocation |

  A key beginning with `-` is a **revocation**: the server's endpoint pipeline
  asks whether a principal holds `-<member>` to withdraw one member of a
  container it otherwise holds. A revocation is issued by name, or by a
  revocation pattern such as `-Orders.*` — never by `*`, or a principal granted
  everything would also be refused everything.
- **A resource role** in `aci.resourceRoles` grades the key through
  `TomResourceRoleRegistry` — `owner → full`, `viewer → read`, whatever the
  application registered. An unknown role grants nothing.

When both apply, the wider state wins. The answer is a four-state
`TomAuthState`, and the boolean checks are that state collapsed: a resource is
*protected* unless its state shows content, so a read-only role unprotects the
value while a `disabled` one does not.

| Ask | Ambient zone | Explicit principal |
| --- | ------------ | ------------------ |
| The four-state grade | `tomResourceState(key)` / `resourceState(key)` | `TomResourceKeyProtection.resourceStateFor(principal, key)` |

```dart
final emailWidget = switch (tomResourceState('user.email')) {
  TomAuthState.full => emailEditor(),
  TomAuthState.read => emailText(),
  TomAuthState.disabled => emailPlaceholder(),
  TomAuthState.none => null,
};
```

The rule lives in one place, `TomResourceKeyProtection.resourceStateFor`, and is
reached two ways. The helpers above — `tomProtect`, `tomProtected` and
`isProtected` — apply it to whoever the **ambient zone** names, which is what
you want at a field you are rendering for the current request. Where a
principal is already in hand, name it. Each zone-reading form has a `For`
sibling that takes the operand explicitly:

| Ambient zone | Explicit principal | Answers with |
| ------------ | ------------------ | ------------ |
| `tomProtect(data, fallback, key)` | `TomResourceKeyProtection.protectFor(principal, data, fallback, key)` | the value or its fallback |
| `tomProtected(key)` / `isProtected(key)` | `TomResourceKeyProtection.isProtectedFor(principal, key)` | a bool |

```dart
// Answers about `principal`, whatever the zone happens to hold.
if (!TomResourceKeyProtection.isProtectedFor(principal, 'user.salary')) {
  showSalary(user.salary);
}
```

This is the distinction `TomResourceKeyAccess` sits on: as an access control it
is asked about a principal, so it takes the second form. So does
`convertPrincipalToTokenPayload`, which filters the fields of the principal it
was handed. Reading the zone when the caller has named someone answers a
different question — and outside a request zone, a fail-closed one.

#### Automatic Protection

`protect` protects the value it is handed. The **automatic tiers** protect
values nobody handed them, at the four layers a value passes through, and each
has a switch:

| Tier | Switch | Applies | Setting |
| ---- | ------ | ------- | ------- |
| Endpoint | `globalSettingUseAutomaticEndpointProtection` | a refused call is granted from the `<api>` / `<api>.<endpoint>` resource keys (`tom_core_server`) | `tom.protection.endpoint` |
| JSON | `globalSettingUseAutomaticJsonProtection` | the reflective serializer leaves out a `@TomProtectedField` field | `tom.protection.json` |
| Database | `globalSettingUseAutomaticDatabaseProtection` | the repository masks and write-protects an authorized column (`tom_core_server`) | `tom.protection.database` |
| UI | `globalSettingUseAutomaticUIProtection` | `tom_flutter_ui` renders every element at its four-state grade | `tom.protection.ui` |

All four are **on by default**. A tier applies whatever the deployment
configured, so one that configured no grants is restricted by none of them;
the switches exist to be turned off. Resource-key enforcement itself
(`globalSettingProtectionDefault`, setting `tom.protection.resourceKeys`) is the
exception and stays off by default: switching it on is what makes resource-key
grants binding, and doing that by default would refuse every unannotated
endpoint and blank every `protect` call of an application with no grants yet.

A field opts into the JSON and database tiers with one annotation:

```dart
@tomReflector
class Employee {
  String? name;

  @TomProtectedField('employee.salary')
  int? salary;
}
```

Both grade it through `TomResourceKeyProtection.automaticState(key)`: the
installed `TomAuthorization` adapter's grade met with the ambient principal's
resource-key grade. Each side is `full` when it is not configured — no adapter,
resource keys not enforced — so a client grading through an adapter and a server
grading from its principals' grants both work without the other. The JSON tier
**omits** a field whose grade shows no content rather than nulling it, since the
reader may be a non-nullable field; only the reflective field walk is protected,
so a type with its own `toJson` protects what it writes with `protect`.

**Switching off.** Every switch reads its start-up value from a compile-time
define, and `applyArguments` applies the same settings at run time:

```bash
dart run -Dtom.protection=false bin/server.dart         # every switch off
flutter run --dart-define=tom.protection.ui=false       # the UI tier off
dart run bin/server.dart tom.protection.json=false      # an argument
```

`tom_core_server`'s server configuration calls `applyArguments` with the
process arguments; a client passes its own. `tom.protection` sets every switch,
a specific setting beats it, and anything outside the namespace is ignored — so
a whole argument list can be passed. A bad setting throws
`TomProtectionSettingException` before any switch changes:

| Key | Raised when |
| --- | ----------- |
| `security.protection.unknown_setting` | a name in the `tom.protection` namespace is not a setting — `tom.protection.jsn` |
| `security.protection.invalid_value` | a setting's value is not `true` or `false` — `tom.protection.json=off` |

From code, `disableAll()` switches everything off and `restoreDefaults()` puts
every switch back to its start-up value.

Runnable:
[`example/samples/security/12_automatic_protection_example.dart`](../../example/samples/security/12_automatic_protection_example.dart).

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

**Where the middle two states come from.** The access controls in the previous
section are two-valued and can only produce `full` or `none`, so a model with
four states needs something that reaches `disabled` and `read`. Three things do:
[`TomGradedAccess`](#graded-access-all-four-states), which composes binary
controls into the full ladder; [per-resource
roles](#per-resource-roles-the-shipped-adapter), whose registry maps a role name
onto any of the four; and [the meet](#the-server-principal-and-the-meet), which
can cap a user's `full` down to a lower state the deployment is licensed for.

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
// Declaratively, in Tom Flutter UI — every widget, form and action
// controller takes the group as `tomGroup` and registers itself.
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

Both take the scope as an optional argument — `resolveGroupPath([scope])` and
`applyMode(memberState, [scope])` — defaulting to the ambient `TomScope.current`.
The default is right for a caller standing in the frame it is asking about, and
wrong for the two cases where a scope travels as a *value* rather than on a
zone: an element constructed with an explicit `scope`, and a callback wrapped by
`ScopeCapture`. Those must pass the same scope they resolved the member's own
path against. A member path and a group path are a `<prefix>.<id>` pair; a
prefix that differs between them looks up a rule belonging to some other member,
so a ceiling can silently vanish rather than merely move.

Inspection helpers all report on **visible** membership: a member whose
`effectiveAuthState` is `none` does not exist from the user's perspective, so
it does not exist for inspection either. `members` is the single place that
filter lives — every other helper is defined in terms of it, which is what
stops them from disagreeing about who is in the group.

| Member | Description |
| ------ | ----------- |
| `members` | Snapshot of the live, visible members (stale refs pruned) |
| `memberCount` / `isEmpty` / `isNotEmpty` | Size of that snapshot — a group whose members are all hidden reports empty |
| `isUniform` | `true` if all visible members share one `effectiveAuthState` — vacuously `true` when none are visible |
| `mostRestrictive` | The most restrictive `effectiveAuthState` among visible members; `none` if there are none |
| `findMember(tomId)` | The **visible** member with the given id, or `null` |

The two aggregates answer the empty case in deliberately opposite ways.
`isUniform` is `true` because "all of nothing shares one state" is vacuously
true, the same convention `Iterable.every` uses. `mostRestrictive` is `none`
because it is being asked for an actual state, and `none` is what "nothing to
show" is called everywhere else in this API — an empty group and a fully
hidden one are the same thing to the user, and both display nothing.

`full` would be the wrong answer there even though it is where the narrowing
fold starts: it is the fold's *identity element*, not a state anyone observed.
Returning it would report the most permissive state possible for the one case
where the group shows nothing, so a container gating on
`mostRestrictive == full` would treat a fully hidden group as fully editable,
and one gating on `mostRestrictive != none` would render an empty section
header. Ask `isEmpty` when the question is really about membership.

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

`TomAuthorizationAdapter` is the bridging contract, and it is a one-method
interface: `TomAuthState resolveAuth(String resourceKeyPath)`. The kernel ships
exactly one implementation — [`TomResourceRoleAdapter`](#per-resource-roles-the-shipped-adapter),
described next. Anything else is yours to write, and test doubles that return
predetermined results are the usual second implementation.

### Per-Resource Roles (the shipped adapter)

`resource_role_authorization.dart` is the kernel's answer to "*what is this
principal **on this resource**?*" — as opposed to `TomAccessControlInformation`'s
`roles`, which answer "*what is this principal, everywhere?*". Two pieces make a
per-resource role resolvable to a `TomAuthState`:

| Type | Role |
| ---- | ---- |
| `TomResourceRoleRegistry` | Process-wide `roleName → TomAuthState` table. Roles arrive from grant data as opaque strings; this is where the application declares what each one is *worth* |
| `TomResourceRoleAdapter` | A `TomAuthorizationAdapter` built over a principal's `resourceRoles` map. Resolves a resource key by finding the principal's role for it, then mapping that role through the registry |

Declare the vocabulary once at startup — client and server declare the *same*
mapping, so presentation and enforcement cannot disagree:

```dart
TomResourceRoleRegistry.registerAll({
  'owner': TomAuthState.full,
  'editor': TomAuthState.full,
  'commenter': TomAuthState.read,
  'viewer': TomAuthState.read,
});
```

Then install an adapter over the current principal's grants, typically at login
from the authorization token's `resourceRoles` claim:

```dart
final principal = TomBearerAuthentication.getPrincipal();
TomAuthorization.adapter = TomResourceRoleAdapter(principal.aci.resourceRoles);

// Anywhere in the UI or the server pipeline:
final state = TomAuthorization.resolveAuth('project.apollo');
if (state.isInteractive) { /* editable */ }
```

**The no-fallback guarantee.** The resolution is deliberately closed, in both
directions where a fallback would be tempting:

- a resource key **absent** from the principal's map means the principal has no
  role there, and resolves to `none`. It does *not* degrade to the global
  `roles` — a user who is a global `admin` still gets `none` on a project nobody
  granted them;
- a role **absent** from the registry resolves to `none` as well. An unknown
  role grants nothing rather than silently granting access, so a typo in grant
  data fails closed.

`stateOf(resourceKey)` performs the same computation as `resolveAuth` under a
name that reads correctly at **server-side enforcement** call sites — where an
adapter is already in hand and going through the global singleton would be
wrong.

A runnable walkthrough of all of the above, with both halves of the no-fallback
guarantee asserted, is
[`example/samples/security/07_resource_role_authorization_example.dart`](../../example/samples/security/07_resource_role_authorization_example.dart).

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
const control = TomEntitlementAccess(['feature.reports.export']);

final user = TomBearerAuthentication.getPrincipal();
final server = TomServerPrincipal.current!;    // this deployment did log in

// The user holds it.
user.aci.entitlements;                         // ['feature.reports.export', ...]
control.checkPrincipalAccess(user);            // true  ← the user operand

// The deployment does not.
server.aci.entitlements;                       // ['feature.reports.view']
control.resolveServerAuthState(server);        // TomAuthState.none

control.resolveAuthState(user);                // TomAuthState.none  ← the meet
control.checkAccessibility(user);              // false
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
| `resolvePrincipalAuthState(principal)` | User | The four-state view; defaults to bridging the boolean above onto `full`/`none`. [`TomGradedAccess`](#graded-access-all-four-states) is the one shipped control that overrides it. |
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
[`TomGradedAccess`](#graded-access-all-four-states) composes its children's
deployment answers into the same ladder, so a feature the deployment only partly
licenses can still resolve to `read`.

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

Runnable, without the full stack:
[`example/samples/security/08_server_principal_meet_example.dart`](../../example/samples/security/08_server_principal_meet_example.dart)
walks the worked example above and the two traps around it — the cap that never
widens, and `null` versus a principal entitled to nothing.

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

**Name the ids through the constants, never as literals.** The api and its
three endpoints are identified by `tomOAuthApiId` (`'tomOAuth'`),
`tomOAuthProvidersEndpointId` (`'listOAuthProviders'`),
`tomOAuthBeginEndpointId` (`'beginOAuthAuthorization'`) and
`tomOAuthCompleteEndpointId` (`'completeOAuthAuthorization'`). They are
constants because the server side has to restate them in
`@TomApiEndpointImplementation(apiId: …)`: a literal spelled out a second time
there is the one string that can go wrong without anything failing to compile —
it names a different api, so the implementation never binds to this contract.

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
void openReport(String reportId) { ... }

// Pattern matching (regex)
@TomEntitlementAccess([r'feature\.reports\..*'])
void exportReports() { ... }
```

### Custom Access Control

The extension point is a plain function, not a class to subclass.
`TomAccessControlHandler` is its signature:

```dart
typedef TomAccessControlHandler =
    bool Function(TomPrincipal? principal, String id);
```

Register one under a name, then refer to it by that name:

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

The `id` the handler receives is the `resourceId` given at the annotation, so
one handler serves every instance of a resource. The principal is nullable —
there may be no session at all — and returning `false` for `null` is the
handler's own job; nothing checks it first.

Registration is one-shot: `registerHandler` **throws** if the name is already
taken, rather than replacing the existing handler. Use
`TomCustomAccess.handlerExists(name)` to test, and `getHandler(name)` to read
one back — that one throws if the name is *unknown*. See [Validate Custom
Handlers at Startup](#4-validate-custom-handlers-at-startup).

### Token Management

```dart
// Set tokens after login — all or nothing: an unreadable pair throws here and
// leaves the previous session (or none) untouched.
TomBearerAuthentication.setTokens(authToken, authzToken);

// Read the session: getPrincipal throws when there is none, tryGetPrincipal
// answers null.
final principal = TomBearerAuthentication.getPrincipal();
final maybe = TomBearerAuthentication.tryGetPrincipal();

// Get current tokens
var token = TomBearerAuthentication.token;
var authzToken = TomBearerAuthentication.authorizationToken;

// Update permissions without re-login
TomBearerAuthentication.replacePrincipalAci(
  groups: ['new-group'],
  roles: ['new-role'],
  entitlements: ['new-entitlement'],
  resourceKeys: ['new-resource-key'],
  resourceRoles: {'project.apollo': 'owner'},
);
```

`replacePrincipalAci` **replaces** the ACI rather than merging into it, so pass
the full set the principal should end up with, not a delta. All five are
required and named, so the two ways to get this wrong silently are both
compile errors: none can be omitted, and none can be transposed with the
identically typed collection beside it. Clearing one is still available — say
`const []` or `const {}` and mean it.

---

## Best Practices

### 1. Choose One Authorization Paradigm

While mixing approaches is supported, it's cleaner to use one:

- **Simple apps**: Public vs. authenticated
- **Enterprise apps**: Role-based (RBAC)
- **Fine-grained control**: Entitlement-based
- **Field-level security**: Resource keys
- **Per-resource rights** (the same user is `owner` here and `viewer` there):
  [Resource roles](#per-resource-roles-the-shipped-adapter)

The last of these is the one that does not compose with the others by accident:
resource roles resolve through their own adapter and, by design, ignore the
global `roles` entirely. Mixing them means a user's rights on a resource come
from one mechanism and their rights everywhere else from another — workable, but
decide it deliberately rather than discovering it.

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

Use resource keys for PII and sensitive data — but **switch protection on
first**. `TomResourceKeyProtection.globalSettingProtectionDefault` defaults to
`false`, and while it is off `tomProtect` returns the real value for every key
and every principal. Without its first line, the snippet below protects nothing:

```dart
// Once, at start-up — without this, everything below is a no-op.
TomResourceKeyProtection.globalSettingProtectionDefault = true;

// In your user serialization
final json = {
  'email': tomProtect(user.email, null, 'user.email'),
  'phone': tomProtect(user.phone, null, 'user.phone'),
  'salary': tomProtect(user.salary, null, 'user.salary'),
};
```

Once it is on, protection is **fail-closed**: `tomProtect` resolves the
principal from the ambient zone, and a `null` principal is treated as holding no
keys at all. Outside a request zone — a start-up path, a background isolate, a
test — *every* protected field therefore serves its fallback. That is the safe
direction to fail, but it means a value that renders correctly inside a request
comes back as `null` from a job that reuses the same serializer. Where the
principal is already in hand, name it with
`TomResourceKeyProtection.protectFor(principal, data, fallback, key)` — or
`isProtectedFor(principal, key)` for the bool — rather than reading the zone. A
serializer that takes the principal it is serializing should always use the
`For` form; it then behaves the same inside a request and out of one. See
[Resource Key Protection](#resource-key-protection).

Resource keys are all-or-nothing: the value is served or it is replaced. When a
field needs a middle ground — payroll edits it, managers see it, everyone else
gets a locked placeholder — reach for [`TomGradedAccess`](#graded-access-all-four-states)
instead and let the resolved state drive the rendering.

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
  filters those out, the same way `pendingTwoFactorChallenge` does. Neither
  filter deletes the chooser, and for one reason stated twice in the type: both
  the deadline and the attempt budget belong to the *mechanism's* offer, so at
  the choosing stop there is nothing that could go stale and nothing that could
  be spent. `isExpired()` and `isExhausted` therefore both answer `false` there
  — read either of them directly and it says the same thing the getter does.
  `attemptsRemaining` is the one member that does not account for the stop: it
  reports `0` for a chooser, meaning "nothing to attempt", not "nothing left".
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
  TomBearerAuthentication.replacePrincipalAci(
    groups: newAci.groups,
    roles: newAci.roles,
    entitlements: newAci.entitlements,
    resourceKeys: newAci.resourceKeys,
    resourceRoles: newAci.resourceRoles,
  );
}
```

A refresh names all five because [the call replaces the
ACI](#token-management), and it *can* name all five because the source it
refreshes from holds the whole answer. Where a source does not — a settings
payload that carries the four lists and no per-resource grants — read the
grants back off the principal and pass them through, rather than clearing what
that source cannot speak for: [`TomResourceRoleAdapter`](#per-resource-roles-the-shipped-adapter)
grades an ungranted resource `none`, so on a timer the symptom is UI that
disappears a few seconds after login, with nothing in the logs.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:collection` | dart | `tom_authorization.dart` | `HashSet` |
| `dart:math` | dart | `two_factor.dart` | `e`, `pow` |
| `dart:typed_data` | dart | `two_factor.dart` | `Uint8List` |
| `crypto` | package | `two_factor.dart` | `Hmac`/`sha1`, the TOTP primitive |
| `meta` | package | `access_controls.dart` | `@nonVirtual` only; no runtime behaviour |
| `tom_crypto` | package | `bearer_authentication.dart` | `TomClientJwtToken`, the parsed form of both bearer tokens |
| [http_connection](../http_connection/http_connection.md) | module | `oauth_contract.dart` | `TomApi` / `TomApiEndpoint` and `TomHttpMethod`, for the external-identity contract |
| [little_things](../little_things/little_things.md) | module | `access_controls.dart`, `two_factor.dart` | `getFromCurrentZone<TomPrincipal>()` — how resource protection finds the ambient principal without being passed one |
| [reflection](../reflection/reflection.md) | module | `authentication_authorization.dart`, `oauth_contract.dart`, `two_factor.dart` | `@tomReflector` — the annotation on every DTO in this module, and hence the JSON round trip that carries them over the wire |
| [scope_ids](../scope_ids/scope_ids.md) | module | `tom_authorization.dart` | `TomScope` path resolution for `TomAuthorizationGroup` |

`TomClientJwtToken` is a dependency's type that this module puts in its **own
public signatures** — two getters return it and `convertTokenPayloadToPrincipal`
takes two — so a consumer has to be able to write the name, not merely call the
members. It can: the package barrel re-exports `tom_crypto` in full, so the type
arrives with the rest of the kernel and needs no second import. That is the
whole of the contract, and it rests on one unfiltered `export` line, so
`test/bearer_auth_barrel_export_test.dart` names the type while importing
nothing but the barrel — narrowing the re-export stops that file compiling
instead of silently shrinking the public surface. `tom_core_flutter` carries the
same guard for the barrel it re-exports this one through, which is the import a
Flutter application actually writes.

Two modules are absent from the table although their subject matter *runs
through* this one, which is the shape a spurious dependency takes here:

- The **observable module** supplies nothing here. It re-exports
  `@tomReflector`, so importing DTO annotations *through* it would look like a
  dependency; the annotation is the reflection module's and is imported from
  there directly.

Note the shape of the reflection row: it reaches the most files of any row, and
it is the only one with a build-time cost. `tomReflector` answers from generated
data, so a package that serializes these DTOs needs `tom_reflection_generator`
as a dev dependency and a `dart run build_runner build`.
