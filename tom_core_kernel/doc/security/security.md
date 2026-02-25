# Tom Framework Security Module

The security module provides a comprehensive authentication and authorization system for the Tom framework. It supports multiple authorization paradigms and integrates seamlessly with JWT-based bearer token authentication.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [Authentication](#authentication)
  - [Authorization](#authorization)
  - [Access Control](#access-control)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

---

## Overview

The security module consists of four main files:

| File | Purpose |
| ---- | ------- |
| `access_controls.dart` | Access control types and resource protection |
| `authentication_authorization.dart` | Authentication message DTOs |
| `bearer_authentication.dart` | JWT token management |
| `user_principal_aci.dart` | User, principal, and ACI types |

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
