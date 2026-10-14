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
| `TomItemType` / `TomItemTypeRegistry` / `TomItemPermissions` | Item permission levels: an application's item types with ordered levels (view < comment < edit < manage by default), each mapped to a grade. Items are named at run time (`<type>:<id>`) and a level on a pattern (`<type>:<prefix>*`) covers a category; `allows` answers in the application's vocabulary, the adapter in grades. In `item_permissions.dart`. |
| `TomUser` / `TomPrincipal` | Authenticated identity and its security context. |
| `TomGroup` / `TomRole` / `TomEntitlement` | Authorization subjects a user can hold. |
| `TomClientContext` | The language, country and timezone a principal carries when nothing better is known. Named once because they are compared as often as assigned: `noCountry` (`XX`) is a non-locale sentinel a locale key must drop, not a country. |
| `TomBearerAuthentication` | Bearer-token authentication. |
| `TomTokenLifetimeException` | A token refused because it is not live — expired, without a readable `exp`, or with a `validUntil` more than two minutes from its `exp`. Raised before any principal is built. |
| `TomAuthenticationMessage` / `TomAuthenticationResult` | Authentication request/response payloads. A failed result carries its key in `error` and its reason in `loginFailureReason`. |
| `TomLoginFailure` | Why a login failed, as the closed set a client branches on — the same value the server's `TomLoginException` carries. |
| `TomAuthorizationGroup` / `AuthGroupMode` | Collective authorization: widgets register with a group, and the mode decides how the group's state applies to its members. |
| `TomAuthorizerStrategy` | How a `TomAuthorizer`'s verdict combines with resource authorization rather than replacing it. |
| `TomUIStateController` | The last layer of the resolution: given the combined authorization state, it returns the final UI state. Build-time, and narrowing only. |
| `TomAuthorizable` | Implemented by anything that carries authorization and can be asked for its state. |
| `TomAccessControlHandler` | The function signature a `TomCustomAccess` rule supplies. |
| `TomAccessControlInformation` / `TomAccessControlDefinition` | The ACI a principal carries, and the entitlement/role definitions it is resolved against — both populated from your authorization store at login. |
| `TomResourceKeyProtection` | Resource-key protection: `resourceStateFor` grades a key from the principal's flat `resourceKeys` grants (exact, `prefix.*`, `*`) and its `resourceRoles`, and `isProtectedFor` / `protectFor` are that grade collapsed to two outcomes. Also the switches: resource-key enforcement (off by default) and the four automatic tiers — endpoint, JSON, database, UI — on by default and switched off by a `tom.protection…` define, by `applyArguments`, or by `disableAll`. `automaticState` is the grade every tier applies. |
| `TomProtectedField` | Field annotation naming the resource key that protects it; the JSON tier leaves the field out of reflective output, and the server's database tier masks and write-protects the column, when its grade shows no content. |
| `TomProtectionSettingException` | Raised by `applyArguments` for an unknown `tom.protection…` setting (`security.protection.unknown_setting`) or a non-boolean value (`security.protection.invalid_value`), before any switch changes. |
| `TomGuestAccess` | The rule for endpoints reachable by anyone, authenticated or not. |
| `TomServerPrincipal` | The process's own identity, installed from a service token. `isConfigured` answers which regime is in force — unconfigured is the designed default, not a failure. |
| `TomClientLimitsInformation` | Per-client limits, travelling in the **public** half of the JWT. |
| `TomClientLimitsProvider` | The source of a client's limits — the seam a subscription service fills (no implementation ships). Installed process-wide; asked at login before tokens are minted, and by `TomBearerAuthentication.refreshClientLimits` mid-session. |

### Second factor

| Type | Responsibility |
| ---- | -------------- |
| `Tom2FAChallenge` | A second-factor challenge awaiting an answer. |
| `Tom2FAClaims` / `Tom2FAEnrolmentClaims` | The claim names a pending challenge and a pending enrolment travel under in a token. |
| `Tom2FAMethodDescriptor` | One available mechanism — produced by the server's registry, consumed by a client choosing between them. |
| `Tom2FAPendingEnrolment` | An enrolment mid-confirmation: the mechanism and the client data needed to set it up (for TOTP, the `otpauth://` URI and the base32 secret). |
| `TomTotp` | The TOTP primitive itself, shared so the tiers that must agree about a code cannot disagree. |
| `TomWebAuthnCreationOptions` · `TomWebAuthnRequestOptions` · `TomWebAuthnRegistrationResponse` · `TomWebAuthnAuthenticationResponse` | The passkey wire types the server issues and the client returns, in WebAuthn's own JSON forms; a response travels through the second factor's `String` seam as `toSubmission()`. |
| `TomWebAuthnUserVerification` · `TomWebAuthnAlgorithms` · `TomBase64Url` | The user-verification requirement, the COSE algorithm ids, and the unpadded base64url codec every WebAuthn field uses. |

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
