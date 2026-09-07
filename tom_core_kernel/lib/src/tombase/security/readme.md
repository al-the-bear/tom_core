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
| `TomResourceRoleRegistry` / `TomResourceRoleAdapter` | Per-principal-per-resource roles: the `roleName → TomAuthState` table, and the kernel's only shipped `TomAuthorizationAdapter`, which resolves a resource key through the principal's role for it. Closed by design — an ungranted resource or an unregistered role yields `none`, never a fallback. |
| `TomUser` / `TomPrincipal` | Authenticated identity and its security context. |
| `TomGroup` / `TomRole` / `TomEntitlement` | Authorization subjects a user can hold. |
| `TomBearerAuthentication` | Bearer-token authentication. |
| `TomAuthenticationMessage` / `TomAuthenticationResult` | Authentication request/response payloads. |
| `TomAuthorizationGroup` / `AuthGroupMode` | Collective authorization: widgets register with a group, and the mode decides how the group's state applies to its members. |
| `TomAuthorizerStrategy` | How a `TomAuthorizer`'s verdict combines with resource authorization rather than replacing it. |
| `TomUIStateController` | The last layer of the resolution: given the combined authorization state, it returns the final UI state. Build-time, and narrowing only. |
| `TomAuthorizable` | Implemented by anything that carries authorization and can be asked for its state. |
| `TomAccessControlHandler` | The function signature a `TomCustomAccess` rule supplies. |
| `TomAccessControlInformation` / `TomAccessControlDefinition` | The ACI a principal carries, and the entitlement/role definitions it is resolved against — both populated from your authorization store at login. |
| `TomResourceKeyProtection` | The global switches for resource-key protection. Several are declared but read by nothing yet; each says so on its own declaration, so do not rely on one until it does. |
| `TomGuestAccess` | The rule for endpoints reachable by anyone, authenticated or not. |
| `TomServerPrincipal` | The process's own identity, installed from a service token. `isConfigured` answers which regime is in force — unconfigured is the designed default, not a failure. |
| `TomClientLimitsInformation` | Per-client limits, travelling in the **public** half of the JWT. |

### Second factor

| Type | Responsibility |
| ---- | -------------- |
| `Tom2FAChallenge` | A second-factor challenge awaiting an answer. |
| `Tom2FAClaims` / `Tom2FAEnrolmentClaims` | The claim names a pending challenge and a pending enrolment travel under in a token. |
| `Tom2FAMethodDescriptor` | One available mechanism — produced by the server's registry, consumed by a client choosing between them. |
| `Tom2FAPendingEnrolment` | An enrolment mid-confirmation: the mechanism and the client data needed to set it up (for TOTP, the `otpauth://` URI and the base32 secret). |
| `TomTotp` | The TOTP primitive itself, shared so the tiers that must agree about a code cannot disagree. |

### External identity (OAuth)

| Type | Responsibility |
| ---- | -------------- |
| `TomOAuthApiService` | The typed service interface behind `tomOAuthApi`, carrying no server annotations for the same reason every framework contract does not. |
| `TomOAuthProviderDto` | One configured external provider, as offered to a client. |
| `TomOAuthAuthorizationRequest` / `TomOAuthAuthorizationDto` | Starting an external authorization, and what comes back. |
| `TomOAuthCallbackRequest` | The provider's callback, handed back to the server to complete. |

## Quick start

```dart complete
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
