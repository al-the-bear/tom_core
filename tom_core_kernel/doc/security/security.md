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
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

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

### Key Concepts

- **User**: Basic identity information (name, email, etc.)
- **Principal**: Authenticated session with full context
- **ACI (Access Control Information)**: Roles, groups, entitlements, resource keys
- **CLI (Client Limits Information)**: Quotas and feature flags

---

## Quick Start

### 1. Set Up Authentication

```dart
import 'package:tom_core/security.dart';

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
| `TomResourceKeyAccess` | Checks resource key protection |
| `TomCustomAccess` | Delegates to custom handler |

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
// TomTextField(tomId: 'street', authorizationGroup: shipping, ...)
// TomTextField(tomId: 'city',   authorizationGroup: shipping, ...)
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

Inspection helpers (all skip hidden `none` members):

| Member | Description |
| ------ | ----------- |
| `members` / `memberCount` / `isEmpty` / `isNotEmpty` | Live membership (stale refs pruned) |
| `isUniform` | `true` if all visible members share one `effectiveAuthState` |
| `mostRestrictive` | The most restrictive `effectiveAuthState` among visible members (`full` if none) |
| `findMember(tomId)` | The member with the given id, or `null` |

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

### 6. Handle 2FA Properly

```dart
var result = await authenticate(message);

if (result.requires2FA) {
  switch (result.twoFactorType) {
    case 'totp':
      showTotpDialog();
      break;
    case 'sms':
      await sendSmsCode();
      showSmsDialog();
      break;
    case 'email':
      await sendEmailCode();
      showEmailDialog();
      break;
  }
}
```

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
