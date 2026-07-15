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
- [Enums](#enums)
  - [TomAuthState](#tomauthstate)
  - [AuthGroupMode](#authgroupmode)
  - [TomAuthorizerStrategy](#tomauthorizerstrategy)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tombase/security/user_principal_aci.dart`,
`tom_authorization.dart`, `access_controls.dart`,
`resource_role_authorization.dart`, `authentication_authorization.dart`,
`bearer_authentication.dart`.

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

`resource_role_authorization.dart` (C-5) resolves per-principal-per-resource
roles: `TomResourceRoleRegistry` maps role names to a `TomAuthState`, and
`TomResourceRoleAdapter` resolves a resource key through the principal's role
map. `authentication_authorization.dart` carries the login DTOs
(`TomAuthenticationMessage`, `TomAuthenticationResult`), and
`bearer_authentication.dart` manages JWT tokens and principal conversion via
`TomBearerAuthentication`.

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
  String? timeZone,
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
| `timeZone` | `String?` | The user's preferred timezone. |
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
| `organizationId` | `int` | The organization's database ID. |
| `applicationId` | `int` | The application's database ID. |
| `processId` | `int` | The process's database ID. |
| `clientId` | `int` | The client's database ID. |
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
| `members` | `Iterable<TomAuthorizable>` | All currently registered members (excludes garbage-collected elements). |
| `memberCount` | `int` | Number of registered members (after pruning stale references). |
| `isEmpty` | `bool` | Whether the group has no live members. |
| `isNotEmpty` | `bool` | Whether the group has at least one live member. |
| `authState` | `TomAuthState` | The authorization state resolved for this group's path. |
| `isUniform` | `bool` | Whether all visible members share the same effective auth state. |
| `mostRestrictive` | `TomAuthState` | The most restrictive effective auth state among all visible members. |

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `register(TomAuthorizable element)` | `void` | Registers an element with this group. |
| `unregister(TomAuthorizable element)` | `void` | Unregisters an element from this group. |
| `resolveGroupPath()` | `String` | Resolves the full canonical `<scopePath>.<groupId>` path. |
| `applyMode(TomAuthState memberState)` | `TomAuthState` | Applies this group's mode to a member's state. |
| `findMember(String tomId)` | `TomAuthorizable?` | Finds a member by [tomId] within this group. |
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
exposing data based on the current principal's access rights. All members are
static.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingProtectionDefault` | `bool` | Master switch to enable/disable resource protection globally. |
| `globalSettingUseAutomaticEndpointProtection` | `bool` | When enabled, API endpoints are automatically protected based on metadata. |
| `globalSettingUseAutomaticJsonProtection` | `bool` | When enabled, JSON serialization automatically respects resource protection. |
| `globalSettingUseAutomaticDatabaseProtection` | `bool` | When enabled, database queries automatically filter protected resources. |
| `globalSettingUseAutomaticFormFieldProtection` | `bool` | When enabled, form fields are automatically protected based on their resource keys. |
| `globalSettingUseAutomaticActionProtection` | `bool` | When enabled, actions are automatically protected based on their resource keys. |
| `globalSettingUseAutomaticActionProtectionForDisabling` | `bool` | When enabled, a protected action is automatically disabled rather than hidden. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `protect<T>(T data, T fallback, String resourceKey)` | `T` | Returns [data] if the current user has access to [resourceKey], else [fallback]. |
| `isProtected(String resourceKey)` | `bool` | Whether the resource is protected (user lacks access) from the current principal. |

### TomAccessControl

Abstract base class for all access control types. Override [checkAccessibility]
to determine if a [TomPrincipal] should have access.

- **Abstract**

#### Constructors

```dart
const TomAccessControl()
```

#### Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `checkAccessibility(TomPrincipal? principal)` | `bool` | Whether the given [principal] has access (default `false`). |
| `resolveAuthState(TomPrincipal? principal)` | `TomAuthState` | Resolves this control to a four-state [TomAuthState]; default bridges the binary check (granted → full, denied → none). |

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
| `resolveAuthState(TomPrincipal? principal)` | `TomAuthState` | *(override)* Resolves to full/read/disabled/none by testing the three composed controls in order. |
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* Collapses to "can see content" (read or full). |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* Always `false`. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* Always `true`. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` only for a non-null, authenticated, non-guest principal. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` for an authenticated user or a guest session. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* Delegates to the named handler with [resourceId]. |
| `verifyHandler()` | `bool` | Whether the handler for this access control is registered. |

### TomEntitlementAccess

Grants access based on entitlement patterns (regex, OR logic).

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` if any pattern matches one of the principal's entitlements. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` if the principal has any of the listed roles. |

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` if the principal is in any of the listed groups. |

### TomResourceKeyAccess

Grants access based on resource key protection, integrating with
[TomResourceKeyProtection] for field-/resource-level control.

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
| `checkAccessibility(TomPrincipal? principal)` | `bool` | *(override)* `true` when [key] is not protected. |

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
| `clientLanguage` | `String` | The client's preferred language (ISO 639-1). |
| `clientCountry` | `String` | The client's country (ISO 3166-1 alpha-2). |
| `clientTimezone` | `String` | The client's timezone identifier. |

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
| `requires2FA` | `bool` | Indicates if two-factor authentication is required. |
| `twoFactorType` | `String` | The type of 2FA required (e.g. `'totp'`, `'sms'`, `'email'`). |

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
| `bearerAuthentication` | `TomBearerAuthentication` | Global singleton instance for bearer authentication. |
| `token` | `String?` | *(getter)* The current authentication token string. |
| `authorizationToken` | `String?` | *(getter)* The current authorization token string. |
| `clientJwtToken` | `TomClientJwtToken?` | *(getter)* The parsed authentication JWT token. |
| `clientAuthorizationJwtToken` | `TomClientJwtToken?` | *(getter)* The parsed authorization JWT token. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `setTokens(String authenticationToken, String authorizationToken, [bool decrypt = true])` | `void` | Stores the tokens and derives the principal. |
| `convertTokenPayloadToPrincipal(TomClientJwtToken authenticationToken, [TomClientJwtToken? authorizationToken])` | `TomPrincipal` | Builds a [TomPrincipal] from JWT token payloads (defensive against malformed claims). |
| `getPrincipal()` | `TomPrincipal` | The current authenticated principal (cached); throws [StateError] without valid tokens. |
| `updatePrincipal(List<String> groups, List<String> roles, List<String> entitlements, List<String> resourceKeys, {Map<String, String> resourceRoles = const {}})` | `void` | Refreshes the current principal's ACI without re-authentication. |
| `convertPrincipalToTokenPayload(TomPrincipal principal, TomAccessControlDefinition? definition, String? clientCountry, String? clientLanguage)` | `(Map<String, Object?>, Map<String, Object?>)` | Converts a principal to the public and private JWT payloads. |

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
| `tomProtect` | `T tomProtect<T>(T data, T fallback, String resourceKey)` | Convenience shorthand for [TomResourceKeyProtection.protect]. |
| `tomProtected` | `bool tomProtected(String resourceKey)` | Convenience shorthand for [TomResourceKeyProtection.isProtected]. |

### Typedefs

| Typedef | Signature | Description |
| ------- | --------- | ----------- |
| `TomAccessControlHandler` | `bool Function(TomPrincipal? principal, String id)` | Function signature for custom access control handlers used by [TomCustomAccess]. |
