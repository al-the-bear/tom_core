# security

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The kernel's authentication and authorization model: principals, groups, roles
and entitlements; a composable `TomAccessControl` hierarchy; and the
`TomAuthState` four-state enum the forms/UI layers honour when deciding whether
an element is hidden, locked, read-only, or fully editable.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthState` | Four UI authorization states: `none` (hidden), `disabled` (locked), `read` (read-only), `full` (editable). |
| `TomAuthorization` / `TomAuthorizer` | Decide the effective access for a principal against a resource. |
| `TomAccessControl` (+ `TomNoAccess` / `TomPublicAccess` / `TomAuthenticatedAccess` / `TomRoleAccess` / `TomEntitlementAccess` / `TomGroupAccess` / `TomResourceKeyAccess` / `TomCustomAccess`) | Composable access-control rules attached to resources. `resolveAuthState` bridges the binary `checkAccessibility` to `TomAuthState` (granted → `full`, denied → `none`). |
| `TomGradedAccess` | Composes `full` / `read` / `disabled` controls into all four `TomAuthState` values, so a single rule can express `full` / `read` / `disabled` / `none`. |
| `TomUser` / `TomPrincipal` | Authenticated identity and its security context. |
| `TomGroup` / `TomRole` / `TomEntitlement` | Authorization subjects a user can hold. |
| `TomBearerAuthentication` | Bearer-token authentication. |
| `TomAuthenticationMessage` / `TomAuthenticationResult` | Authentication request/response payloads. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // The four authorization states, ordered least → most capable.
  const state = TomAuthState.read;

  print(state.isVisible);    // true  (not `none`)
  print(state.showsContent); // true  (`read` or `full`)
  print(TomAuthState.disabled.showsContent); // false (locked, no value)
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
