# Tom Core Kernel API Reference: Security Module

Identity, authentication, and authorization primitives for the Tom framework:
the user/principal/ACI data model, the four-state UI authorization system,
declarative access-control annotations, JWT bearer-token management, and
per-principal-per-resource role resolution.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomAccessControlInformation](#tomaccesscontrolinformation)
  - [TomClientLimitsInformation](#tomclientlimitsinformation)
  - [TomAccessControlDefinition](#tomaccesscontroldefinition)
  - [TomGroup](#tomgroup)
  - [TomRole](#tomrole)
  - [TomEntitlement](#tomentitlement)
  - [TomUser](#tomuser)
  - [TomPrincipal](#tomprincipal)
  - [TomAuthorizable](#tomauthorizable)
  - [TomAuthorizationGroup](#tomauthorizationgroup)
  - [TomAuthorizationAdapter](#tomauthorizationadapter)
  - [TomAuthorization](#tomauthorization)
  - [TomAuthorizer](#tomauthorizer)
  - [TomUIStateController](#tomuistatecontroller)
  - [TomResourceRoleRegistry](#tomresourceroleregistry)
  - [TomResourceRoleAdapter](#tomresourceroleadapter)
  - [TomResourceKeyProtection](#tomresourcekeyprotection)
  - [TomAccessControl](#tomaccesscontrol)
  - [TomGradedAccess](#tomgradedaccess)
  - [TomNoAccess](#tomnoaccess)
  - [TomPublicAccess](#tompublicaccess)
  - [TomAuthenticatedAccess](#tomauthenticatedaccess)
  - [TomGuestAccess](#tomguestaccess)
  - [TomCustomAccess](#tomcustomaccess)
  - [TomEntitlementAccess](#tomentitlementaccess)
  - [TomRoleAccess](#tomroleaccess)
  - [TomGroupAccess](#tomgroupaccess)
  - [TomResourceKeyAccess](#tomresourcekeyaccess)
  - [TomAuthenticationMessage](#tomauthenticationmessage)
  - [TomAuthenticationResult](#tomauthenticationresult)
  - [TomBearerAuthentication](#tombearerauthentication)
  - [Tom2FAClaims](#tom2faclaims)
  - [Tom2FAChallenge](#tom2fachallenge)
  - [Tom2FAEnrolmentClaims](#tom2faenrolmentclaims)
  - [Tom2FAPendingEnrolment](#tom2fapendingenrolment)
  - [Tom2FAMethodDescriptor](#tom2famethoddescriptor)
  - [TomTotp](#tomtotp)
  - [TomServerPrincipal](#tomserverprincipal)
  - [TomOAuthProviderDto](#tomoauthproviderdto)
  - [TomOAuthAuthorizationRequest](#tomoauthauthorizationrequest)
  - [TomOAuthAuthorizationDto](#tomoauthauthorizationdto)
  - [TomOAuthCallbackRequest](#tomoauthcallbackrequest)
  - [TomOAuthApiService](#tomoauthapiservice)
- [Enums](#enums)
  - [TomAuthState](#tomauthstate)
  - [AuthGroupMode](#authgroupmode)
  - [TomAuthorizerStrategy](#tomauthorizerstrategy)
- [Global Functions and Constants](#global-functions-and-constants)
  - [Functions](#functions)
  - [Constants](#constants)
  - [Typedefs](#typedefs)

## Overview

Sources: `lib/src/tombase/security/user_principal_aci.dart`,
`tom_authorization.dart`, `access_controls.dart`,
`resource_role_authorization.dart`, `authentication_authorization.dart`,
`bearer_authentication.dart`, `two_factor.dart`, `server_principal.dart`,
`oauth_contract.dart`.

`user_principal_aci.dart` holds the identity/authorization data model:
`TomUser` (identity), `TomPrincipal` (authenticated session + context),
`TomAccessControlInformation` (ACI — roles/groups/entitlements/resource
keys/resource roles), `TomClientLimitsInformation` (CLI — quotas and enabled
modules), and the `TomAccessControlDefinition` schema (built from `TomRole`,
`TomGroup`, `TomEntitlement`) that recursively completes an ACI's inherited
permissions.

`tom_authorization.dart` provides the UI authorization system: the four-state
`TomAuthState`, the `TomAuthorizable` interface, `TomAuthorizationGroup`
(collective control via `AuthGroupMode`), the `TomAuthorization` global
singleton and its `TomAuthorizationAdapter` seam, plus the per-element
`TomAuthorizer` (`TomAuthorizerStrategy`) and build-time `TomUIStateController`.

`access_controls.dart` supplies declarative access-control annotations — the
`TomAccessControl` base and its implementations (`TomGradedAccess`, `TomNoAccess`,
`TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`, `TomCustomAccess`,
`TomEntitlementAccess`, `TomRoleAccess`, `TomGroupAccess`, `TomResourceKeyAccess`)
— plus `TomResourceKeyProtection` and the `tomProtect`/`tomProtected` helpers.

Evaluation there takes **two** operands. A user's grant is met with the grant of
the deployment the code runs in — the ambient `TomServerPrincipal` from
`server_principal.dart` — and the effective answer is `min(user, server)` over
the `TomAuthState` ladder. Deployment grants cap every user's grants and never
widen them, so a control the user satisfies can still resolve to `none`. When no
server principal is installed the meet is skipped entirely and the user's grade
stands alone, so a deployment that installs none is governed by its users'
grants alone. See `doc/security/security.md` §"The Server
Principal and the Meet"; the server-side login that installs the principal is
`tom_core_server`'s `TomServerSelfLogin`.

`resource_role_authorization.dart` (C-5) resolves per-principal-per-resource
roles: `TomResourceRoleRegistry` maps role names to a `TomAuthState`, and
`TomResourceRoleAdapter` resolves a resource key through the principal's role
map. `authentication_authorization.dart` carries the login DTOs
(`TomAuthenticationMessage`, `TomAuthenticationResult`), and
`bearer_authentication.dart` manages JWT tokens and principal conversion via
`TomBearerAuthentication`.

`two_factor.dart` holds the shared half of the two-pass login, in two parallel
pairs plus two singles. The **challenge** pair covers the user who already has a
factor: `Tom2FAClaims` (the claim names a pending challenge travels under) and
`Tom2FAChallenge` (its wire shape, carried in the interim token's public
claims). The **enrolment** pair is the exact analogue one step earlier, for the
user who has no factor yet: `Tom2FAEnrolmentClaims` and
`Tom2FAPendingEnrolment`, which covers both stops of that leg — choosing a
mechanism and confirming it. `Tom2FAMethodDescriptor` is how a mechanism names
itself to a user being asked to choose, in resource keys rather than literal
text; and `TomTotp` is the RFC 4226/6238 derivation primitives plus the base32
codec. These live in the kernel because three tiers must agree about them
exactly — the server issuing and verifying, enrolment tooling handing out a
secret, and the client driving the second-factor UI. The server-side
orchestration (adaptor registry, mechanisms, the two passes) is
`tom_core_server`'s authentication module.

`oauth_contract.dart` (C-9) holds the wire contract for external-identity login:
the DTOs (`TomOAuthProviderDto`, `TomOAuthAuthorizationRequest`,
`TomOAuthAuthorizationDto`, `TomOAuthCallbackRequest`), the `tomOAuthApi`
declaration with its three public endpoints, and the `TomOAuthApiService` shape
both tiers bind to. The *flow* — client secret, token-endpoint call, linking
table — is server-side and lives in `tom_core_server`; what is here is only what
the two halves must agree on.

Note the type the callback endpoint answers with: `TomAuthenticationResult`, the
same type `/login` answers with. That is the contract's half of the framework's
central decision about external identity — an OAuth provider *resolves a
principal*, and everything after the principal is resolved is the one login path
every credential reaches, second factor included. A distinct "OAuth result" type
here would be the first step towards a second token issuer.

## Class Hierarchy

```
Object
├── TomAccessControlInformation
├── TomClientLimitsInformation
├── TomAccessControlDefinition
├── TomGroup
├── TomRole
├── TomEntitlement
├── TomUser
├── TomPrincipal
├── TomAuthorizationGroup
├── TomAuthorization                         (private constructor)
├── TomAuthorizer
├── TomUIStateController
├── TomResourceRoleRegistry                  (private constructor)
├── TomResourceKeyProtection
├── TomAuthenticationMessage                 (@tomReflector)
├── TomAuthenticationResult                  (@tomReflector)
├── TomBearerAuthentication
├── Tom2FAClaims                             (private constructor)
├── Tom2FAChallenge
├── Tom2FAEnrolmentClaims                    (private constructor)
├── Tom2FAPendingEnrolment
├── Tom2FAMethodDescriptor                   (@tomReflector)
├── TomTotp                                  (private constructor)
├── TomServerPrincipal                       (private constructor)
├── TomOAuthProviderDto                      (@tomReflector)
├── TomOAuthAuthorizationRequest             (@tomReflector)
├── TomOAuthAuthorizationDto                 (@tomReflector)
├── TomOAuthCallbackRequest                  (@tomReflector)
└── TomAccessControl                         (abstract)
    ├── TomGradedAccess
    ├── TomNoAccess
    ├── TomPublicAccess
    ├── TomAuthenticatedAccess
    ├── TomGuestAccess
    ├── TomCustomAccess
    ├── TomEntitlementAccess
    ├── TomRoleAccess
    ├── TomGroupAccess
    └── TomResourceKeyAccess

(interfaces / adapters)
├── TomAuthorizable                          (abstract interface)
├── TomOAuthApiService                       (abstract interface)
├── TomAuthorizationAdapter                  (abstract)
│   └── TomResourceRoleAdapter               (implements)

(enums)
├── TomAuthState
├── AuthGroupMode
└── TomAuthorizerStrategy
```

## Classes

### TomAccessControlInformation

Groups together a user's authorization information: roles, groups, entitlements,
resource keys, and per-resource roles. All collections are exposed as
unmodifiable views.

#### Constructors

```dart
TomAccessControlInformation({
  List<String> roles = const [],
  List<String> entitlements = const [],
  List<String> resourceKeys = const [],
  List<String> groups = const [],
  Map<String, String> resourceRoles = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `roles` | `List<String>` | Unmodifiable list of roles assigned to the user. |
| `groups` | `List<String>` | Unmodifiable list of groups the user belongs to. |
| `entitlements` | `List<String>` | Unmodifiable list of entitlements granted to the user. |
| `resourceKeys` | `List<String>` | Unmodifiable list of resource keys the user can access. |
| `resourceRoles` | `Map<String, String>` | Unmodifiable `resourceKey → roleName` map giving the principal's role on each individual resource (C-5). |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Summary of counts of roles, entitlements, resource keys, groups, and resource roles. |

### TomClientLimitsInformation

Controls system capabilities independent of user rights — subscription-based
limits and feature flags (enabled modules and quotas).

The values come from the application's authentication service, on the principal
it returns from a login, and from nowhere else; neither the kernel nor
`tom_core_server` holds a subscription store. They travel in the **public** half
of the JWT as the `subscription_enabledModules` / `subscription_quotas` claims,
so they are a login-time snapshot and their figures are readable by whoever
holds the token.

#### Constructors

```dart
TomClientLimitsInformation({
  List<String> enabledModules = const [],
  Map<String, int> quotas = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `enabledModules` | `List<String>` | List of module names enabled for this client. |
| `quotas` | `Map<String, int>` | Map of quota names to their limits. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Module count and quotas summary. |

### TomAccessControlDefinition

Global ACI schema definition for resolving complete permissions. Defines how
roles, groups, and entitlements relate and recursively resolves inherited
permissions from a user's basic ACI.

#### Constructors

```dart
TomAccessControlDefinition({
  List<TomRole>? roles,
  List<TomGroup>? groups,
  List<TomEntitlement>? entitlements,
})
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `completeFromDefinition(TomAccessControlInformation userProvided)` | `TomAccessControlInformation` | Recursively resolves all inherited roles/groups/entitlements/resource keys from `userProvided`; passes resource roles through unchanged. |
| `toString()` | `String` | *(override)* Counts of roles, entitlements, and groups. |

### TomGroup

Represents a group in the authorization model. Groups organize users and inherit
permissions from other groups and roles.

#### Constructors

```dart
TomGroup({
  required String name,
  List<String>? rolesIncluded,
  List<String>? groupMemberShips,
  List<String>? entitlements,
  List<String>? resourceKeys,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The unique name of this group. |
| `rolesIncluded` | `List<String>` | Roles that members of this group inherit. |
| `groupMemberShips` | `List<String>` | Other groups that this group is a member of. |
| `entitlements` | `List<String>` | Entitlements directly assigned to this group. |
| `resourceKeys` | `List<String>` | Resource keys directly accessible to this group. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Group name and inherited/granted counts. |

### TomRole

Represents a role in the authorization model — the primary RBAC mechanism. Roles
define job functions and can form hierarchies.

#### Constructors

```dart
TomRole({
  required String name,
  List<String>? rolesIncluded,
  List<String>? groupMemberShips,
  List<String>? entitlements,
  List<String>? resourceKeys,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The unique name of this role. |
| `rolesIncluded` | `List<String>` | Other roles that this role inherits from. |
| `groupMemberShips` | `List<String>` | Groups that holders of this role automatically join. |
| `entitlements` | `List<String>` | Entitlements directly granted by this role. |
| `resourceKeys` | `List<String>` | Resource keys directly accessible with this role. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Role name and inherited/granted counts. |

### TomEntitlement

Represents a fine-grained permission (entitlement) that can be assigned to users,
groups, or roles. Entitlements can include other entitlements and grant resource
keys.

#### Constructors

```dart
TomEntitlement({
  required String name,
  List<String>? entitlements,
  List<String>? resourceKeys,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The unique name of this entitlement. |
| `entitlements` | `List<String>` | Other entitlements included in this entitlement. |
| `resourceKeys` | `List<String>` | Resource keys accessible with this entitlement. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Entitlement name and included counts. |

### TomUser

Represents a user's identity information (name, email, contact details),
separate from authorization data. Unauthenticated users use the special
[guestUsername] value.

#### Constructors

```dart
TomUser({
  int id = -1,
  String username = guestUsername,
  String? firstname,
  String? lastname,
  String? email,
  String? phone,
  String? mobile,
  String? addressLine1,
  String? addressLine2,
  String? city,
  String? postcode,
  String? stateRegion,
  String? timezone,
  Map<String, Object?>? attributes,
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `guestUsername` | `static const String` | The username value for unauthenticated/anonymous users (`"GUEST"`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | The user's unique identifier. |
| `username` | `String` | The user's login username. |
| `firstname` | `String?` | The user's first name. |
| `lastname` | `String?` | The user's last name. |
| `email` | `String?` | The user's email address. |
| `phone` | `String?` | The user's phone number. |
| `mobile` | `String?` | The user's mobile phone number. |
| `addressLine1` | `String?` | First line of the user's address. |
| `addressLine2` | `String?` | Second line of the user's address. |
| `city` | `String?` | The user's city. |
| `postcode` | `String?` | The user's postal/zip code. |
| `stateRegion` | `String?` | The user's state or region. |
| `timezone` | `String?` | The user's preferred timezone. |
| `attributes` | `Map<String, Object?>` | Unmodifiable view of custom attributes for extending user data. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* Username, id, name, and email summary. |

### TomPrincipal

Represents an authenticated user session with full context — combines user
identity ([user]), access control information ([aci]), client limits ([cli]),
and session context.

#### Constructors

```dart
TomPrincipal({
  TomClientLimitsInformation? cli,
  TomAccessControlInformation? aci,
  TomUser? user,
  bool authenticated = false,
  bool requires2FA = false,
  String? twoFactorType,
  Map<String, Object?> context = const {},
  String? organization,
  String? application,
  String? process,
  String? language,
  String? country,
  String? clientCountry,
  String? clientLanguage,
  String? timezone,
  String? clientTimezone,
  int organizationId = -1,
  int applicationId = -1,
  int processId = -1,
  int clientId = -1,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authenticated` | `bool` | Whether the user has been authenticated. |
| `id` | `int` | The user's unique identifier (from [user]). |
| `username` | `String` | The user's login name (from [user]). |
| `user` | `TomUser` | The user's identity information. |
| `organization` | `String?` | The organization identifier for multi-tenant systems. |
| `application` | `String?` | The application identifier for multi-application deployments. |
| `process` | `String?` | The process identifier within the application. |
| `organizationId` | `int` | The organization's database ID. Defaults to `-1`, the "unset" value. These four ids are non-nullable where their string counterparts ([organization], [application], [process]) are nullable, so test for `-1` — not for `0`, and not for null. |
| `applicationId` | `int` | The application's database ID. Defaults to `-1` when unset. |
| `processId` | `int` | The process's database ID. Defaults to `-1` when unset. |
| `clientId` | `int` | The client's database ID. Defaults to `-1` when unset. |
| `language` | `String?` | Application/server language (ISO 639-1). |
| `country` | `String?` | Application/server country (ISO 3166-1 alpha-2). |
| `timezone` | `String?` | Application/server timezone identifier. |
| `clientLanguage` | `String?` | Client device language (ISO 639-1). |
| `clientCountry` | `String?` | Client device country (ISO 3166-1 alpha-2). |
| `clientTimezone` | `String?` | Client device timezone identifier. |
| `currentContext` | `Map<String, Object?>` | Session-specific context data. |
| `requires2FA` | `bool` | Whether two-factor authentication is required. |
| `twoFactorType` | `String?` | The type of 2FA required (e.g. `'totp'`, `'sms'`, `'email'`). |
| `aci` | `TomAccessControlInformation` | The user's access control information (roles, groups, entitlements). |
| `cli` | `TomClientLimitsInformation` | The client's limits information (quotas, enabled modules). |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `addToContext(Map<String, Object?> attributes)` | `void` | Adds attributes to the session context. |
| `toString()` | `String` | *(override)* Full principal summary (user, auth, 2FA, locale, ACI, CLI). |

### TomAuthorizable

Interface for elements that participate in the Tom authorization system. Provides
a resource id, an optional group, and the resolved effective state.

- **Abstract interface**

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tomId` | `String?` | The plain ID for this element within its scope; `null` if it does not participate in resource lookup. |
| `tomGroup` | `TomAuthorizationGroup?` | The authorization group this element belongs to, if any. |
| `effectiveAuthState` | `TomAuthState` | The final resolved authorization state after resource, group, and local overrides. |

### TomAuthorizationGroup

A group of related Tom elements ([TomAuthorizable]) that share authorization
control. Members are held as weak references; the group's [mode] governs how its
state applies to members.

#### Constructors

```dart
TomAuthorizationGroup(String groupId, {AuthGroupMode mode = AuthGroupMode.controlsWidest})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `groupId` | `String` | The group ID. |
| `mode` | `AuthGroupMode` | How this group's auth state applies to its members. |
| `members` | `Iterable<TomAuthorizable>` | Snapshot of the live, visible members — excludes garbage-collected elements and members whose `effectiveAuthState` is `none`. The single filter every other inspection helper is built on. |
| `memberCount` | `int` | Number of visible members. |
| `isEmpty` | `bool` | Whether the group has no visible members (true when every member is hidden). |
| `isNotEmpty` | `bool` | Whether the group has at least one visible member. |
| `authState` | `TomAuthState` | The authorization state resolved for this group's path. |
| `isUniform` | `bool` | Whether all visible members share the same effective auth state; vacuously `true` when none are visible. |
| `mostRestrictive` | `TomAuthState` | The most restrictive effective auth state among all visible members, or `none` when there are no visible members — an empty group and a fully hidden one both show nothing. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `register(TomAuthorizable element)` | `void` | Registers an element with this group. Hidden elements register like any other. |
| `unregister(TomAuthorizable element)` | `void` | Unregisters an element. Works on the raw registrations, so hidden elements can still be removed. |
| `resolveGroupPath([TomScope? scope])` | `String` | Resolves the full canonical `<scopePath>.<groupId>` path, in `scope` or in the ambient `TomScope.current`. |
| `applyMode(TomAuthState memberState, [TomScope? scope])` | `TomAuthState` | Applies this group's mode to a member's state, resolving the group in `scope` — which must be the one the member's own path came from. |
| `findMember(String tomId)` | `TomAuthorizable?` | Finds a *visible* member by `tomId`; `null` for one that is registered but hidden. |
| `toString()` | `String` | *(override)* `'TomAuthorizationGroup(groupId, mode: mode)'`. |

### TomAuthorizationAdapter

Adapter that resolves authorization state for a given resource key path,
bridging the kernel security layer to the UI.

- **Abstract**

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `resolveAuth(String resourceKeyPath)` | `TomAuthState` | Resolves the authorization state for the given resource key path. |

### TomAuthorization

Global authorization singleton, initialized at app startup with a concrete
[TomAuthorizationAdapter]. Accessed directly — no BuildContext needed.

- **Private constructor** (not instantiable; static-only)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `adapter` | `TomAuthorizationAdapter` | *(setter only)* Installs the adapter that backs [resolveAuth]. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `resolveAuth(String resourceKeyPath)` | `TomAuthState` | Resolves authorization; returns [TomAuthState.full] if no adapter is set (development mode). |
| `reset()` | `void` | Resets the adapter. Intended for testing only. |

### TomAuthorizer

Per-element authorizer that can modify the authorization outcome according to a
[TomAuthorizerStrategy].

#### Constructors

```dart
const TomAuthorizer({
  TomAuthorizerStrategy strategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
  required TomAuthState Function(TomAuthState resourceAuth) resolve,
})

factory TomAuthorizer.fixed(TomAuthState state)

factory TomAuthorizer.fromAction({
  required TomAuthState Function() actionAuth,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `strategy` | `TomAuthorizerStrategy` | The strategy controlling how the authorizer interacts with resource auth. |
| `resolve` | `TomAuthState Function(TomAuthState resourceAuth)` | Resolves the authorization state given the resource-based state. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `effectiveAuth(TomAuthState resourceAuth)` | `TomAuthState` | Computes the effective state by combining resource auth with this authorizer's resolution per [strategy]. |

### TomUIStateController

Build-time callback that can further narrow (never widen) a widget's effective
state based on dynamic business rules.

#### Constructors

```dart
const TomUIStateController({
  required TomAuthState Function(TomAuthState currentAuth, Object? data) resolve,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resolve` | `TomAuthState Function(TomAuthState currentAuth, Object? data)` | Resolves the final UI state given the current authorization state (may only narrow). |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `apply(TomAuthState currentAuth, {Object? data})` | `TomAuthState` | Applies this controller, ensuring the result never widens [currentAuth]. |

### TomResourceRoleRegistry

Process-wide registry mapping a role name to the resource-level [TomAuthState] a
principal holding that role has on a resource (C-5). Populated once at startup.

- **Private constructor** (not instantiable; static-only)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mapping` | `Map<String, TomAuthState>` | Unmodifiable snapshot of the current `role → state` mapping. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `register(String role, TomAuthState state)` | `void` | Declares that a principal holding [role] has resource-level [state]. |
| `registerAll(Map<String, TomAuthState> mapping)` | `void` | Declares several `role → state` mappings at once. |
| `stateFor(String role)` | `TomAuthState?` | The resource-level state for [role], or `null` when the role is unknown (a denial). |
| `reset()` | `void` | Clears every registered mapping. Intended for testing. |

### TomResourceRoleAdapter

A [TomAuthorizationAdapter] backed by a principal's per-resource roles. Resolves
a resource key by finding the principal's role for it and mapping it through the
[TomResourceRoleRegistry]. Resolution is deliberately closed: unknown resource or
role → [TomAuthState.none].

- **Implements:** `TomAuthorizationAdapter`

#### Constructors

```dart
const TomResourceRoleAdapter(Map<String, String> resourceRoles)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resourceRoles` | `Map<String, String>` | The principal's `resourceKey → roleName` map (a snapshot from the ACI). |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `resolveAuth(String resourceKeyPath)` | `TomAuthState` | *(override)* Resolves the resource key via the principal's role and the registry; [none] when unknown. |
| `stateOf(String resourceKey)` | `TomAuthState` | The effective state on [resourceKey], exposed for server-side enforcement call sites. |

### TomResourceKeyProtection

Provides resource-level protection based on resource keys, selectively hiding or
exposing data according to a principal's access rights. All members are static.
The rule lives in [isProtectedFor], which takes the principal as an argument;
[isProtected] and [protect] are the ambient-zone forms of it, reading the
principal the current request installed. Every one of them is gated on
[globalSettingProtectionDefault], which is `false` by default.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingProtectionDefault` | `bool` | Master switch for resource protection. **Defaults to `false`**, and while it is off every method below short-circuits to "accessible" — a protection call added to the code protects nothing until this is set. |
| `globalSettingUseAutomaticEndpointProtection` | `bool` | When enabled, API endpoints are automatically protected based on metadata. Defaults to `false`. The one automatic switch that is honoured — `tom_core_server`'s endpoint pipeline consults it. |
| `globalSettingUseAutomaticJsonProtection` | `bool` | Defaults to `false`. **Not implemented** — nothing reads this flag, and the `json` module does not reference resource-key protection at all. |
| `globalSettingUseAutomaticDatabaseProtection` | `bool` | Defaults to `false`. **Not implemented** — nothing reads this flag, and `object_persistence` does not reference resource-key protection at all. |
| `globalSettingUseAutomaticFormFieldProtection` | `bool` | Defaults to `false`. **Not implemented** — nothing reads this flag; form fields resolve visibility from `TomAuthState`. |
| `globalSettingUseAutomaticActionProtection` | `bool` | Defaults to `false`. **Not implemented** — nothing reads this flag. |
| `globalSettingUseAutomaticActionProtectionForDisabling` | `bool` | Defaults to `false`. **Not implemented** — nothing reads this flag. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `protect<T>(T data, T fallback, String resourceKey)` | `T` | Returns [data] if the current user has access to [resourceKey], else [fallback]. Decided by [isProtected], so it inherits the master switch: while [globalSettingProtectionDefault] is `false` this returns [data] for every key and every principal. |
| `isProtectedFor(TomPrincipal? principal, String resourceKey)` | `bool` | The protection rule itself, stated over an explicit principal. Answers `false` (accessible) whenever [globalSettingProtectionDefault] is `false`, before any key is consulted; otherwise `true` unless `principal` holds `resourceKey` in its ACI. A `null` principal holds no keys, so with protection on it is denied everything. |
| `isProtected(String resourceKey)` | `bool` | [isProtectedFor] applied to the principal on the ambient zone — the operand is read from the zone, not passed. Note the two ways it answers `false`: protection is switched off, or the principal holds the key. Outside a request zone there is no principal, so with protection on this answers `true` for everything — fail-closed. Where a principal is already in hand, call [isProtectedFor]. |

### TomAccessControl

Abstract base class for all access control types.

Evaluation has **two** operands: what this control demands of the *user*, and
what the deployment identified by [TomServerPrincipal] is granted. The public
entry points compute the meet — `min(user, server)` over the [TomAuthState]
ladder — and are `@nonVirtual`, because a cap a subclass could sidestep by
overriding the method everyone already calls would not be a cap at all.
Subclasses implement the hooks instead.

- **Abstract**

#### Constructors

```dart
const TomAccessControl()
```

#### Methods — hooks (implemented by subclasses)

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | The **user** operand: whether the principal's own grants satisfy this control (default `false`). Deliberately uncapped — it is one half of the meet. |
| `resolvePrincipalAuthState(TomPrincipal? principal)` | `TomAuthState` | The user operand as four states; the default bridges the boolean above (granted → `full`, denied → `none`). Overridden by [TomGradedAccess]. |
| `resolveServerAuthState(TomPrincipal serverPrincipal)` | `TomAuthState` | The **deployment** operand: the grade this control's subject is granted to the deployment. Defaults to `TomAuthState.full` — *uncapped* — because a control naming a role, group or resource key expresses no opinion about deployment features, and a participant with no opinion must return the identity element. Overridden by [TomEntitlementAccess] and [TomGradedAccess]. |

#### Methods — public evaluation (`@nonVirtual`)

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `resolveAuthState(TomPrincipal? principal)` | `TomAuthState` | The **effective** grade: the user's met with the deployment's. Returns the user's grade alone when [TomServerPrincipal.current] is `null` — no installed principal means no cap applies, which is not the same as a principal granted nothing. |
| `checkAccessibility(TomPrincipal? principal)` | `bool` | Defined as `resolveAuthState(...).showsContent`, so the binary and graded views can never disagree. |

### TomGradedAccess

Access control that resolves to all four [TomAuthState] values by composing three
binary controls — [full], [read], and [disabled]. [read] defaults to [full],
[disabled] defaults to [read].

- **Extends:** `TomAccessControl`

#### Constructors

```dart
TomGradedAccess({
  required TomAccessControl full,
  TomAccessControl? read,
  TomAccessControl? disabled,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `full` | `TomAccessControl` | Grants full access → resolves to [TomAuthState.full]. |
| `read` | `TomAccessControl` | Grants read access → resolves to [TomAuthState.read]. Defaults to [full]. |
| `disabled` | `TomAccessControl` | Grants visibility → resolves to [TomAuthState.disabled]. Defaults to [read]. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `resolvePrincipalAuthState(TomPrincipal? principal)` | `TomAuthState` | *(override)* Resolves the user operand to full/read/disabled/none by testing the three composed controls in order. |
| `resolveServerAuthState(TomPrincipal serverPrincipal)` | `TomAuthState` | *(override)* Composes the children's deployment answers onto the same ladder, so a feature the deployment only partly licenses can still cap to `read`. |

### TomNoAccess

Denies access to all users.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomNoAccess()
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* Always `false`. |

### TomPublicAccess

Allows access to all users, including unauthenticated ones.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomPublicAccess()
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* Always `true`. |

### TomAuthenticatedAccess

Requires a fully authenticated user (not a guest).

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomAuthenticatedAccess()
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` only for a non-null, authenticated, non-guest principal. |

### TomGuestAccess

Allows authenticated users and guest users.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomGuestAccess()
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` for an authenticated user or a guest session. |

### TomCustomAccess

Delegates access control to a registered custom handler
([TomAccessControlHandler]), for logic that does not fit the standard model.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomCustomAccess({required String handler, required String resourceId})
```

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `registerHandler(String name, TomAccessControlHandler handler)` | `void` | Registers a custom handler; throws if [name] already exists. |
| `getHandler(String name)` | `TomAccessControlHandler` | Retrieves a registered handler; throws if none exists. |
| `handlerExists(String name)` | `bool` | Whether a handler with the given [name] exists. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `handler` | `String` | The name of the registered handler to use. |
| `resourceId` | `String` | An identifier passed to the handler for resource-specific checks. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* Delegates to the named handler with [resourceId]. |
| `verifyHandler()` | `bool` | Whether the handler for this access control is registered. |

### TomEntitlementAccess

Grants access based on entitlement patterns (regex, OR logic).

**Also the deployment's grant carrier.** Entitlements are the one requirement
kind that means the same thing on both sides of the meet: asked about a *user*
they answer "may this person use the feature", asked about the *server
principal* "is this deployment licensed for the feature at all". Same pattern
set, other principal — which is why server-level grants needed no new class. A
deployment whose entitlements do not match caps the feature to
`TomAuthState.none` no matter what the user holds.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomEntitlementAccess(List<String> patterns)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `patterns` | `List<String>` | List of regex patterns matched against user entitlements. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` if any pattern matches one of the principal's entitlements. |
| `resolveServerAuthState(TomPrincipal serverPrincipal)` | `TomAuthState` | *(override)* The same pattern match run against the deployment's entitlement set: `full` when it matches, `none` when it does not. |

### TomRoleAccess

Grants access based on user roles (OR logic).

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomRoleAccess(List<String> roles)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `roles` | `List<String>` | List of roles that grant access. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` if the principal has any of the listed roles. |

### TomGroupAccess

Grants access based on group membership (OR logic).

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomGroupAccess(List<String> groups)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `groups` | `List<String>` | List of groups that grant access. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` if the principal is in any of the listed groups. |

### TomResourceKeyAccess

Grants access based on resource key protection, integrating with
[TomResourceKeyProtection] for field-/resource-level control. Unlike its
siblings this control has a second operand: while
[TomResourceKeyProtection.globalSettingProtectionDefault] is `false` — its
default — resource keys are not enforced at all and every principal is granted.
Once it is on, the rule is the ordinary one. It is deliberately not routed
through the shared ACI helper the role and group controls use, because that
master switch is a genuinely different rule.

- **Extends:** `TomAccessControl`

#### Constructors

```dart
const TomResourceKeyAccess(String key)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The resource key to check. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkPrincipalAccess(TomPrincipal? principal)` | `bool` | *(override)* `true` when [key] is not protected from `principal`. Delegates to [TomResourceKeyProtection.isProtectedFor] — the explicit-principal form, so the answer is about the principal passed in, not about the ambient zone. |

### TomAuthenticationMessage

Represents an authentication request from a client (reflection-discoverable,
`@tomReflector`). Carries credentials and client context.

#### Constructors

```dart
TomAuthenticationMessage()
```

*(implicit default constructor)*

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `client` | `String` | Unique client identifier for session tracking. |
| `userName` | `String` | The username for authentication (defaults to guest username). |
| `password` | `String` | The password for authentication. |
| `application` | `String` | The application identifier for multi-application deployments. |
| `process` | `String` | The process identifier within the application. |
| `organization` | `String` | The organization identifier for multi-tenant deployments. |
| `clientLanguage` | `String` | The client's preferred language (ISO 639-1). Defaults to `"en"`. |
| `clientCountry` | `String` | The client's country (ISO 3166-1 alpha-2). Defaults to `"XX"`, the "no country" code — not the empty string, so a country is always syntactically present. |
| `clientTimezone` | `String` | The client's timezone identifier — what the *device* is set to, never a stored preference (that is server-side, applied after login). Defaults to `"utc"`. |

### TomAuthenticationResult

Represents the server's response to an authentication request
(reflection-discoverable, `@tomReflector`) — an error or the auth/authz tokens.

#### Constructors

```dart
TomAuthenticationResult([String error = ""])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `error` | `String` | Error message if authentication failed; empty on success. |
| `authenticationToken` | `String` | JWT token proving user identity. |
| `authorizationToken` | `String` | JWT token containing authorization information (ACI). |
| `requires2FA` | `bool` | The user holds a factor and must now **use** it. |
| `twoFactorType` | `String` | The type of 2FA required (e.g. `'totp'`, `'sms'`, `'email'`). |
| `requires2FAEnrolment` | `bool` | The user holds no usable factor and must first **set one up**. Never true at the same time as [requires2FA], so a client written before enrolment existed cannot mistake one for the other. |
| `availableTwoFactorMethods` | `List<Tom2FAMethodDescriptor>` | The mechanisms offered for set-up, in preference order; empty unless `requires2FAEnrolment`. Already narrowed to what this principal's policy permits and this deployment can enrol, so the client renders the list as given. |
| `twoFactorEnrolmentSkippable` | `bool` | Whether the user may decline the offer and finish the login without a factor. The client shows a "not now" affordance only when this is set; the server re-checks the same fact from its own signed token. |

### TomBearerAuthentication

Manages JWT bearer token authentication. A singleton that stores auth/authz
tokens and provides the current user's [TomPrincipal].

#### Constructors

```dart
TomBearerAuthentication()
```

*(implicit default constructor)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `bearerAuthentication` | `TomBearerAuthentication` | Global singleton instance for bearer authentication. **Not `final`** — publicly assignable, and deliberately so: every static accessor below reads through it, so assigning a fresh instance swaps the whole cached authentication state at once. This is the isolation seam tests use in `setUp`/`tearDown`. |
| `token` | `String?` | *(getter)* The current authentication token string. |
| `authorizationToken` | `String?` | *(getter)* The current authorization token string. |
| `clientJwtToken` | `TomClientJwtToken?` | *(getter)* The parsed authentication JWT token. |
| `clientAuthorizationJwtToken` | `TomClientJwtToken?` | *(getter)* The parsed authorization JWT token. |
| `pendingTwoFactorChallenge` | `Tom2FAChallenge?` | *(getter)* The challenge carried by the currently held token, or `null` when the login is complete. Reads the authorization token if present, otherwise the authentication token. Also `null` when the challenge has expired or burned its last attempt: it is no longer answerable, so a client holding a stale token restarts at pass 1 instead of looping. The freshness check lives here, not in `Tom2FAChallenge.fromClaims`, which stays a clock-free wire decoder. |
| `pendingTwoFactorEnrolment` | `Tom2FAPendingEnrolment?` | *(getter)* The enrolment the currently held token is part-way through, or `null` when the login owes no set-up. Read and freshness-filtered the same way as `pendingTwoFactorChallenge`, and with no special case: `isExpired` and `isExhausted` both already answer false at the choosing stop, where nothing has been generated that could go stale or be spent. Both getters can answer non-null at once — a principal forced to enrol who already holds a factor is being asked for both, and the client renders the challenge first. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `setTokens(String authenticationToken, String authorizationToken, [bool decrypt = true])` | `void` | Stores the tokens and derives the principal. |
| `clearTokens()` | `void` | Drops the stored tokens and the cached principal. |
| `convertTokenPayloadToPrincipal(TomClientJwtToken authenticationToken, [TomClientJwtToken? authorizationToken])` | `TomPrincipal` | Builds a [TomPrincipal] from JWT token payloads (defensive against malformed claims). Throws [StateError] when the token has no payload. This is the single point at which `authenticated` is derived, and it is derived rather than read: true only when the username is not [TomUser.guestUsername] **and** no second factor is owed, so every access check rejects an interim token without having to test `requires2FA` itself. The factor test goes through [Tom2FAClaims.isTrue], so both the string `"true"` Tom's own issuer writes and the JSON boolean `true` read as "a factor is owed" and yield an *un*authenticated principal. Nothing else does: a missing claim, `"false"`, `"True"` and `1` all read as "no factor owed". Accepting both encodings is the fail-safe direction at this gate — a reader that took only the string would authenticate a token saying, in the encoding it did not expect, that it had not finished logging in. |
| `getPrincipal()` | `TomPrincipal` | The current authenticated principal (cached); throws [StateError] without valid tokens. |
| `updatePrincipal(List<String> groups, List<String> roles, List<String> entitlements, List<String> resourceKeys, {Map<String, String> resourceRoles = const {}})` | `void` | Refreshes the current principal's ACI without re-authentication. |
| `convertPrincipalToTokenPayload(TomPrincipal principal, TomAccessControlDefinition? definition, String? clientCountry, String? clientLanguage, {Tom2FAChallenge? challenge, Map<String, Object?>? twoFactorVerification, bool twoFactorSatisfied = false})` | `(Map<String, Object?>, Map<String, Object?>)` | Converts a principal to the public and private JWT payloads. The two second-factor parameters are **not** independent — a `challenge` decides both. Supplying one projects its claims, which include `requires2FA: "true"` unconditionally: `twoFactorSatisfied` is consulted only when there is *no* challenge, so `(challenge: c, twoFactorSatisfied: true)` still yields an interim token. That is the fail-safe direction — forgetting a parameter produces an unusable token, never an over-privileged one. `twoFactorVerification` is written into the private payload **only alongside a `challenge`**, and is silently dropped without one, so a mechanism secret cannot outlive the challenge it was minted for. With no challenge, `requires2FA` is `"true"` exactly when the principal owes a factor and `twoFactorSatisfied` is `false`. |

### Tom2FAClaims

The claim names a pending two-factor challenge travels under. Both tiers read
and write the token through these constants rather than string literals, so the
server issuing a challenge and the client reading it cannot drift apart.

All of them name **public** claims — readable by the client without the server
key — except `verificationData`, which names the encrypted claim holding
whatever the mechanism needs on the second pass.

#### Constructors

*(private constructor — the class is a constant namespace)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `requires2FA` | `String` | Claim marking the token as an interim one: a second factor is still owed. Written as the string `"true"`, read with [isTrue]. |
| `type` | `String` | Claim holding the mechanism type, e.g. `'totp'`. |
| `hint` | `String` | Claim holding the mechanism's display hint, e.g. a masked phone number. |
| `attempt` | `String` | Claim holding the number of attempts already consumed. |
| `attemptsAllowed` | `String` | Claim holding the attempt budget for this challenge. |
| `expiresAt` | `String` | Claim holding the challenge expiry as an ISO-8601 UTC string. |
| `clientData` | `String` | Claim holding the mechanism's own opaque payload for its client UI. |
| `verificationData` | `String` | Claim (in the **encrypted** section) holding the mechanism's own opaque payload for its second pass. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTrue(Object? raw)` | `bool` | The single rule for reading a boolean claim in **either** 2FA claim family, on both tiers: true for the JSON boolean `true` and for the string `"true"`, false for everything else. The two families disagree on encoding — `requires2FA` and `pendingEnrolment` are strings, `skippable` and `skipSpendsGrace` are JSON booleans — so every read accepts both. Deliberately not general truthiness: `"True"`, `1` and `"yes"` are false, because widening past what a Tom tier writes would be guessing at other issuers' conventions rather than reconciling our own. |

### Tom2FAChallenge

The wire shape of a pending second factor, carried in the interim token's
public claims. It is a value object: consuming an attempt produces a new
challenge rather than mutating this one, because each attempt is minted into a
fresh token.

#### Constructors

```dart
Tom2FAChallenge({
  required String type,
  required DateTime expiresAt,
  String hint = '',
  int attempt = 0,
  int attemptsAllowed = 3,
  Map<String, Object?> clientData = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism type, matched against [Tom2FARegistry] on the server. |
| `hint` | `String` | Display hint for the client, e.g. a masked destination. Never a secret. |
| `attempt` | `int` | Attempts already consumed against this challenge. |
| `attemptsAllowed` | `int` | The attempt budget. |
| `expiresAt` | `DateTime` | UTC instant after which the challenge is refused. Always UTC: the constructor normalises whatever it is handed, so a countdown rendered from this field needs no `toUtc()` of its own. |
| `clientData` | `Map<String, Object?>` | The mechanism's own payload for its client UI; not interpreted by the framework. |
| `attemptsRemaining` | `int` | *(getter)* `attemptsAllowed - attempt`, floored at zero. |
| `isExhausted` | `bool` | *(getter)* True once no attempts remain. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isExpired([DateTime? now])` | `bool` | Whether the challenge has passed [expiresAt] (defaults to the current instant). `now` may be in either zone — the comparison is between instants, not wall clocks. |
| `withConsumedAttempt()` | `Tom2FAChallenge` | A copy with [attempt] advanced by one. |
| `toClaims()` | `Map<String, Object?>` | The public-claim map, keyed by [Tom2FAClaims]. |
| `toString()` | `String` | *(override)* Type, hint, attempt budget and expiry, for logs. Carries no secret — [hint] is already the masked form. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `fromClaims(Map<String, dynamic>? payload)` | `Tom2FAChallenge?` | Reads a challenge back out of a token payload, or `null` when the payload carries no challenge, names no mechanism, or carries an unreadable expiry. An unreadable `attemptsAllowed` falls back to `0`, not to the constructor's `3`, so a malformed token cannot hand out attempts — the challenge is returned already `isExhausted`. |

### Tom2FAEnrolmentClaims

The claim names a pending second-factor **enrolment** travels under — the
sibling of [Tom2FAClaims], for the leg of the login where the user has no factor
yet and is being offered the chance to set one up.

All of them name **public** claims except `offerData`, which names the encrypted
claim holding the whole offer including the mechanism's server-only section, so
any instance can confirm an enrolment another began.

Two encoding details are worth knowing before reading a token by hand.
`pendingEnrolment` is the string `"true"`, for the same compatibility reason
[Tom2FAClaims.requires2FA] is; `skippable` and `skipSpendsGrace` are JSON
booleans, because they are newer and have no tokens in flight to stay
compatible with. That the two disagree is why **every** boolean claim in both
families is read with [Tom2FAClaims.isTrue], which accepts either encoding —
on the client (`Tom2FAPendingEnrolment.fromClaims`) and on the server
(`Tom2FAEnrolmentState.fromClaims`) alike, since the two decode the same token
and must not disagree about what it says.

#### Constructors

*(private constructor — the class is a constant namespace)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `pendingEnrolment` | `String` | Claim marking the token as carrying an enrolment awaiting confirmation (`"true"`). |
| `type` | `String` | Claim holding the mechanism key being enrolled, e.g. `'totp'`. Absent while the user is still choosing. |
| `hint` | `String` | Claim holding a short, displayable hint for the factor being set up. |
| `attempt` | `String` | Claim holding the number of confirmation attempts already consumed. |
| `attemptsAllowed` | `String` | Claim holding the confirmation-attempt budget for this offer. |
| `expiresAt` | `String` | Claim holding the offer's expiry as an ISO-8601 UTC string. Projected only once a mechanism has been picked. |
| `clientData` | `String` | Claim holding the mechanism's client-interpreted enrolment payload — for TOTP the base32 secret and the `otpauth://` URI. Public because delivering it to the user *is* the enrolment. |
| `offerData` | `String` | Claim (in the **encrypted** section) holding the whole offer, server-only section included. |
| `offeredTypes` | `String` | Claim holding the mechanism keys this principal was offered, in preference order. Carried rather than recomputed: a client naming a mechanism is checked against the list it was actually given. |
| `skippable` | `String` | Claim holding whether the user may decline the offer. Decided on the pass that made the offer, so the authority is the signed token, never a flag the client sends back. |
| `skipSpendsGrace` | `String` | Claim holding whether declining spends one of the principal's grace logins. Recorded on the offering pass, which is the one that knows *why* skipping was allowed. |

### Tom2FAPendingEnrolment

The wire shape of a second-factor enrolment awaiting the user's next move — the
exact analogue of [Tom2FAChallenge], one step earlier in the story. Where a
challenge says *prove you hold the factor you already set up*, a pending
enrolment says *you have none; here are the mechanisms you may set up, and here
is the one you picked, half-built*. Both ride in an interim token's public
claims and both leave the principal unauthenticated.

The flow has two stops and this one type covers both, distinguished by
`hasOffer`:

- **Choosing** — `offeredTypes` is populated and `type` is empty. The client
  renders a chooser and posts the chosen key back.
- **Confirming** — `type` names the mechanism and `clientData` carries what the
  user needs to set it up. The client renders that mechanism's enrolment panel
  and posts the confirmation code.

One type rather than two, because a client that had to pick between two readers
before knowing which it held would only be re-deriving `hasOffer`.

Unlike [Tom2FAChallenge] there is no `toClaims()`: the client reads a pending
enrolment, it never mints one. Projecting the claims is the server's job.

#### Constructors

```dart
Tom2FAPendingEnrolment({
  DateTime? expiresAt,
  String type = '',
  String hint = '',
  int attempt = 0,
  int attemptsAllowed = 3,
  Map<String, Object?> clientData = const {},
  List<String> offeredTypes = const [],
  bool skippable = false,
  bool skipSpendsGrace = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism being enrolled; empty while the user is still choosing. |
| `hint` | `String` | Display hint for the factor being set up; empty when the mechanism has nothing useful to show. |
| `attempt` | `int` | Confirmation attempts already consumed. |
| `attemptsAllowed` | `int` | The confirmation-attempt budget before the offer is burned. |
| `expiresAt` | `DateTime?` | UTC instant after which the offer is no longer answerable — `null` while choosing, because the deadline belongs to the mechanism's offer and nothing has been generated yet. Normalised by the constructor exactly as [Tom2FAChallenge.expiresAt] is; a `null` stays `null` rather than acquiring a deadline. |
| `clientData` | `Map<String, Object?>` | The mechanism's opaque payload for its client UI, passed through untouched by the framework. Empty while choosing. |
| `offeredTypes` | `List<String>` | The mechanism keys this principal was offered, in preference order. |
| `skippable` | `bool` | Whether the user may decline and complete the login without a factor. |
| `skipSpendsGrace` | `bool` | Whether declining spends one of the principal's grace logins. |
| `hasOffer` | `bool` | *(getter)* Whether a mechanism has been chosen and its enrolment begun — i.e. render the mechanism's panel rather than the chooser. |
| `attemptsRemaining` | `int` | *(getter)* `attemptsAllowed - attempt`, floored at zero. Zero while choosing, where no budget claim travels — nothing to attempt, not nothing left. |
| `isExhausted` | `bool` | *(getter)* True once no confirmation attempts remain. **Always false while choosing**, the same reading `isExpired` gives the deadline and for the same reason: the budget belongs to the mechanism's offer, so the choosing stop carries no budget claim, and an absent claim reads back as zero. Only disqualifying once [hasOffer] — which leaves the fail-closed fallback below intact, since that only bites on a begun offer. Matches the server's `Tom2FAEnrolmentState.isExhausted`. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isExpired([DateTime? now])` | `bool` | Whether the offer has lapsed as of `now` (defaults to the current instant; either zone will do, the comparison is between instants). **Always false while choosing** — there is no generated material to go stale, so a chooser left open is a UX question, not a security one. **Always true for a begun offer with no `expiresAt`**, the opposite case: there the deadline is what stops generated material being confirmable indefinitely, so its absence reads as lapsed rather than unbounded. [fromClaims] never builds one, so this is the backstop for a hand-built value, and it answers as the server's `Tom2FAEnrolmentState` does — a panel that offered a confirmation the server has already decided to refuse would be worse than one that says the offer lapsed. |
| `toString()` | `String` | *(override)* Attempt budget, skippability and expiry, for logs; renders the chosen mechanism once [hasOffer], and the offered list while still choosing. Carries no enrolment secret. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `fromClaims(Map<String, dynamic>? payload)` | `Tom2FAPendingEnrolment?` | Reads a pending enrolment back out of a token payload, as defensively as [Tom2FAChallenge.fromClaims]. Yields `null` when the payload carries no enrolment, when it names neither a chosen mechanism nor an offer list (nothing a client could render), and when a *begun* enrolment's expiry is unreadable. An unreadable `attemptsAllowed` falls back to `0`, not to the constructor's `3`, so a malformed token cannot hand out attempts — the offer is returned already `isExhausted`. |

### Tom2FAMethodDescriptor

How a mechanism names itself to a user who is being asked to choose one
(reflection-discoverable, `@tomReflector`). It travels to the client inside
[TomAuthenticationResult.availableTwoFactorMethods], which is what makes it a
wire type and puts it in the kernel beside [Tom2FAChallenge].

A mechanism *key* (`'totp'`, `'sms'`) is an identifier: it dispatches back to
the right adaptor and is stable across releases, which is exactly why it must
never be shown. The label, the explanation and the icon are user-facing, so
under G-RES-1 they are **resource keys**, resolved against the caller's locale
by whichever tier renders them. The descriptor therefore carries no literal text
at all — a descriptor holding `'Authenticator app'` would be a translation
defect that no test could distinguish from a correct value, because it looks
right in the one locale it was written in.

`Tom2FAMethodDescriptor.scoped(type)` derives all three keys under
`resourceScope`, so a mechanism cannot half-follow the convention and adding one
cannot silently invent a fourth naming scheme:

| Field | For `scoped('webauthn')` | Rendered as |
| ----- | ------------------------ | ----------- |
| `type` | `'webauthn'` | Not shown — the key the client sends back |
| `displayNameKey` | `two_factor.webauthn.name` | The option's label |
| `descriptionKey` | `two_factor.webauthn.description` | The sentence under it |
| `iconKey` | `two_factor.webauthn.icon` | Whatever the client's icon set calls it |

The unnamed constructor exists for a mechanism whose keys do not follow the
convention — a deployment fitting an adaptor into an existing resource bundle —
but `scoped` is the one to use.

#### Constructors

```dart
Tom2FAMethodDescriptor({
  String type = '',
  String displayNameKey = '',
  String descriptionKey = '',
  String iconKey = '',
})

Tom2FAMethodDescriptor.scoped(String type)
```

Every parameter of the unnamed constructor is optional and every field is
mutable, because this is a wire DTO: reflection constructs it empty and fills it
in (G-DTO-1/2).

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resourceScope` | `String` | `'two_factor'` — the scope every shipped mechanism's keys live under, so a resource bundle can be searched for the whole 2FA catalog by prefix. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The mechanism key — the same value the server's registry resolves and a challenge dispatches on. |
| `displayNameKey` | `String` | Resource key of the mechanism's short label. |
| `descriptionKey` | `String` | Resource key of the one-sentence explanation shown beside the label. |
| `iconKey` | `String` | Resource key of the icon to render — a key rather than an asset path, because the Flutter and web tiers name their assets differently and the mechanism must not have to know which one is asking. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | `'Tom2FAMethodDescriptor($type -> $displayNameKey)'`. |

### TomTotp

The RFC 4226 / RFC 6238 derivation primitives plus the base32 codec, with no
policy attached — no notion of a window, an attempt budget or where a secret
lives. Those belong to the server's `TomTotp2FAService`; what is here is only
the arithmetic, kept in the kernel because the server verifying a code,
enrolment tooling handing out a secret, and any client generating one must all
agree on it exactly.

#### Constructors

*(private constructor — the class is a static namespace)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultDigits` | `int` | `6` — the code length assumed by authenticator apps. |
| `defaultPeriod` | `Duration` | 30 seconds — the standard time step. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `counterFor({DateTime? at, Duration period = defaultPeriod})` | `int` | The time-step counter for an instant: UTC seconds since the epoch divided by the period. `at` defaults to now. Throws [ArgumentError] unless `period` is at least one second — the step is `period.inSeconds`, which truncates, so a sub-second period is rejected too. |
| `generateCode(List<int> key, int counter, [int digits = defaultDigits])` | `String` | The HOTP code for a raw key and counter, zero-padded to `digits`. |
| `codeFor(String secret, {DateTime? at, int digits = defaultDigits, Duration period = defaultPeriod})` | `String` | The TOTP code for a base32 secret at an instant. Returns an empty string for an undecodable secret, so a bad secret matches nothing rather than throwing into a UI. |
| `decodeBase32(String secret)` | `List<int>` | Decodes an RFC 4648 base32 secret to bytes; case-insensitive, ignoring spaces, `-` and `=`. Returns an empty list for an out-of-alphabet character. |
| `encodeBase32(List<int> bytes)` | `String` | Encodes bytes as an unpadded base32 secret, for enrolment. |

### TomServerPrincipal

The **ambient server principal** — the deployment's own identity, held for the
lifetime of the process and readable from the access-evaluation path.

A deployed server authenticates against the auth server with a service
credential exactly like any other client, and the token it gets back
reconstructs a [TomPrincipal] whose entitlements are the *feature grants of this
deployment*. Those grants cap every user's grants; see [TomAccessControl] for
the meet.

It is a process-wide static rather than a zone value because the zone's
[TomPrincipal] slot already holds the *user*, one per in-flight request, and the
server principal must be readable from inside those same zones. It is also
genuinely process-scoped: one deployment, one identity, resolved once at
startup.

#### Constructors

*(private constructor — the class is a static holder)*

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomPrincipal?` | *(getter)* The deployment's principal, or `null` when this process never logged itself in. `null` means "no deployment cap applies" and is the **opposite** of a principal with an empty entitlement set, which means "entitled to nothing" and denies every feature. Never substitute one for the other. |
| `isConfigured` | `bool` | *(getter)* Whether a server principal has been installed. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `install(TomPrincipal principal)` | `void` | Installs the deployment's identity for the rest of the process. Replacing an existing principal is intended — a long-running server re-authenticates as its service token nears expiry. |
| `clear()` | `void` | Removes the principal, returning the process to the uncapped regime. For tests and orderly shutdown. Note the direction: clearing *widens* access, so it is never the right response to an expired token — `install` again instead. |

### TomOAuthProviderDto

One configured external-identity provider, **as a client sees it** — a
reflection-first wire DTO (G-DTO) with plain non-`final` fields and no
hand-written serializer.

Deliberately thin: a client needs to render a button and post an id back.
Issuer URLs, client ids, secrets and scopes are the server's business and never
reach the wire.

#### Constructors

```dart
TomOAuthProviderDto({
  String id = '',
  String displayNameKey = '',
  String iconKey = '',
})

TomOAuthProviderDto.scoped(String id)
```

`scoped` derives both keys from `id` as `oauth.<id>.name` / `oauth.<id>.icon`,
which is what makes the convention structural rather than a matter of
per-provider discipline — adding a provider cannot silently invent a second
naming scheme.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resourceScope` | `String` | `'oauth'` — the scope every shipped provider's resource keys live under, so a resource bundle can be searched by prefix. The same convention `Tom2FAMethodDescriptor` follows. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The provider key as configured under `oauth.providers` on the server (`google`, `github`, `acme-sso`). What a client posts back in [TomOAuthAuthorizationRequest.providerId]. |
| `displayNameKey` | `String` | Resource key of the provider's short label ("Sign in with Google"). A key rather than text (G-RES-1) — the label is rendered in the user's language, which the server does not know at configuration time. |
| `iconKey` | `String` | Resource key of the icon to render. A key rather than an asset path, because the Flutter and web tiers name their assets differently and the provider must not have to know which one is asking. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* `TomOAuthProviderDto(<id>)`. |

### TomOAuthAuthorizationRequest

The request that starts an authorization-code flow: the same login context a
password [TomAuthenticationMessage] carries, minus the credential — because
there is no credential yet; that is what the provider is about to establish.

The context is captured **now** rather than at the callback because the
provider's redirect arrives as a plain browser navigation carrying none of it:
no client id, no locale, no organization. The server stores it with the pending
authorization and replays it when the code comes back, so an externally
authenticated session is issued in exactly the organization and locale the login
was started in.

#### Constructors

```dart
TomOAuthAuthorizationRequest({
  String providerId = '',
  String client = '',
  String application = '',
  String process = '',
  String organization = '',
  String clientLanguage = '',
  String clientCountry = '',
  String clientTimezone = '',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providerId` | `String` | The provider to authorize against — [TomOAuthProviderDto.id]. |
| `client` | `String` | The calling client (`web`, `flutter`, …), as in [TomAuthenticationMessage.client]. |
| `application` | `String` | The application the login is for. |
| `process` | `String` | The process the login is for. |
| `organization` | `String` | The organization the login is for. |
| `clientLanguage` | `String` | The client's language code. Defaults to `''`, **not** to the `"en"` its namesake [TomAuthenticationMessage.clientLanguage] uses. |
| `clientCountry` | `String` | The client's country code. Defaults to `''`, not to `"XX"`. |
| `clientTimezone` | `String` | The client's IANA timezone name. Defaults to `''`, not to `"utc"`. |

These three carry the same names as their [TomAuthenticationMessage]
counterparts but not the same defaults: the password path starts from
`"en"`/`"XX"`/`"utc"`, the OAuth path from the empty string. A caller that
leaves them unset therefore produces a different client context depending on
which login it used.

Note what is **absent**: a redirect URI. Where the provider sends the user back
is server configuration, because a redirect target a caller may choose is an
open redirect — an attacker who can name it can have the provider deliver a live
authorization code to a host they own.

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* `TomOAuthAuthorizationRequest(<providerId>)`. |

### TomOAuthAuthorizationDto

Where to send the user, and the handle the flow is remembered under.

#### Constructors

```dart
TomOAuthAuthorizationDto({String authorizationUri = '', String state = ''})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authorizationUri` | `String` | The provider's authorization endpoint with the flow's parameters applied — `client_id`, `redirect_uri`, `scope`, `state` and, when the provider supports it, the PKCE `code_challenge`. The client navigates to it and does nothing else with it. |
| `state` | `String` | The opaque handle of the pending authorization. Returned so a client can *correlate* the redirect it later observes with the flow it started. **Not a credential:** presenting it authenticates nothing, because completing the flow additionally requires the provider's authorization code and the PKCE verifier the server kept. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* `TomOAuthAuthorizationDto(<state>)`. |

### TomOAuthCallbackRequest

What the provider's redirect carries back: either `code` + `state` (success) or
`error` + `errorDescription` (the user declined, the provider refused).

The fields are named for the DTO; the snake_cased query parameters they bind
from are declared once in the endpoint's `urlParameterMapping`, which is what
keeps the provider's spelling out of the Dart shape.

#### Constructors

```dart
TomOAuthCallbackRequest({
  String code = '',
  String state = '',
  String error = '',
  String errorDescription = '',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `code` | `String` | The authorization code to exchange, when the flow succeeded. |
| `state` | `String` | The handle of the pending authorization ([TomOAuthAuthorizationDto.state]). |
| `error` | `String` | The provider's error code (`access_denied`, …), when it refused. |
| `errorDescription` | `String` | The provider's human-readable elaboration of `error`, when it sent one. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `toString()` | `String` | *(override)* `TomOAuthCallbackRequest(<state>, error: <error>)`. |

### TomOAuthApiService

The typed service interface behind `tomOAuthApi` — the contract's *Dart* face.
The server implements it; a client that generates or hand-writes a caller
implements the same shape.

It carries no annotation because the server-side ones (`@tomComponent`,
`@TomApiEndpointImplementation`) live in `tom_core_server` and cannot be named
here — the same split the rest of the framework's contracts follow.

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `listOAuthProviders()` | `Future<List<TomOAuthProviderDto>>` | `tomOAuthProvidersEndpointId` — the providers this deployment configures. |
| `beginOAuthAuthorization(TomOAuthAuthorizationRequest request)` | `Future<TomOAuthAuthorizationDto>` | `tomOAuthBeginEndpointId` — starts a flow and answers where to send the user. |
| `completeOAuthAuthorization(TomOAuthCallbackRequest request)` | `Future<TomAuthenticationResult>` | `tomOAuthCompleteEndpointId` — exchanges the code and completes the login, answering exactly what a password login answers. |

## Enums

### TomAuthState

The four authorization states for a UI element.

- **Enum values:** `none`, `disabled`, `read`, `full`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isVisible` | `bool` | Whether this state allows the element to be visible (not `none`). |
| `isInteractive` | `bool` | Whether this state allows interaction (`full`). |
| `showsContent` | `bool` | Whether this state shows content (`read` or `full`). |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `narrow(TomAuthState other)` | `TomAuthState` | The more restrictive of two states (order: none < disabled < read < full). |
| `widen(TomAuthState other)` | `TomAuthState` | The less restrictive of two states. |

### AuthGroupMode

Determines how a [TomAuthorizationGroup]'s auth state applies to its members.

- **Enum values:** `controlsAll`, `controlsWidest`, `controlsNarrowest`

### TomAuthorizerStrategy

Strategy for how a [TomAuthorizer] interacts with resource authorization.

- **Enum values:** `authorizerDecides`, `authorizerNarrowsOnly`

## Global Functions and Constants

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `tomProtect` | `T tomProtect<T>(T data, T fallback, String resourceKey)` | Convenience shorthand for [TomResourceKeyProtection.protect], inheriting its precondition: nothing is protected until [TomResourceKeyProtection.globalSettingProtectionDefault] is `true`. |
| `tomProtected` | `bool tomProtected(String resourceKey)` | Convenience shorthand for [TomResourceKeyProtection.isProtected], inheriting its precondition: while [TomResourceKeyProtection.globalSettingProtectionDefault] is `false` — its default — this always answers `false`, so a `if (!tomProtected(...))` guard always passes. |
| `registerTomOAuthApi` | `void registerTomOAuthApi()` | Registers `tomOAuthApi` with the global `tomRemoteApis` registry. Idempotent, and called by both halves — a server before mounting the endpoints, a client before building a caller. Registration is explicit rather than implicit in a top-level initializer because a deployment that configures no providers should not carry the API in its registry. |

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomOAuthApiId` | `String` | `'tomOAuth'` — the id `tomOAuthApi` is registered and bound under. A constant because the server's `@TomApiEndpointImplementation(apiId: …)` has to name it, and a literal restated on the implementation side is the one string that can go wrong without anything failing to compile. |
| `tomOAuthProvidersEndpointId` | `String` | `'listOAuthProviders'` — the configured providers a client may offer. |
| `tomOAuthBeginEndpointId` | `String` | `'beginOAuthAuthorization'` — start an authorization-code flow for one provider. |
| `tomOAuthCompleteEndpointId` | `String` | `'completeOAuthAuthorization'` — the provider's redirect target; completes the login. |
| `tomOAuthApi` | `TomApi` | External-identity login, mounted at `/oauth`. Three endpoints: `GET /providers` → `List<TomOAuthProviderDto>`; `POST /authorize` (`TomOAuthAuthorizationRequest` → `TomOAuthAuthorizationDto`); `GET /callback` (`TomOAuthCallbackRequest` → `TomAuthenticationResult`, with `urlParameterMapping` binding `code`, `state`, `error` and `error_description` out of the query string). Every endpoint is `TomPublicAccess`, necessarily so: this is how a caller who is *not yet* authenticated becomes authenticated, exactly like `/login`. Public does not mean unguarded — the flow is protected by the single-use, server-issued, TTL-bounded `state` handle and the PKCE verifier, neither of which a caller supplies. Declared `final`, not `const` unlike the four endpoint ids above — `TomApi`'s constructor links each endpoint back to the api it belongs to, which is a run-time assignment. |

### Typedefs

| Typedef | Signature | Description |
| ------- | --------- | ----------- |
| `TomAccessControlHandler` | `bool Function(TomPrincipal? principal, String id)` | Function signature for custom access control handlers used by [TomCustomAccess]. |
