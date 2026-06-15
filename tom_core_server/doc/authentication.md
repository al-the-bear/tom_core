# Authentication Module

Server-side login orchestration. The module turns an incoming authentication
request into JWT tokens by delegating credential checking to an
application-supplied [`TomAuthenticationService`], then encoding the resulting
principal into an authentication token and an authorization token.

## Table of Contents

- [Overview](#overview)
- [The Login Flow](#the-login-flow)
- [Implementing a Service](#implementing-a-service)
- [Wiring the Server](#wiring-the-server)
- [Core Components](#core-components)
- [Status and Limitations](#status-and-limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthenticationServer` | class (`@tomReflector`) | Orchestrates the login flow and issues JWTs |
| `TomAuthenticationService` | abstract (`@tomReflector`) | The contract an app implements to verify a login |
| `TomAuthenticationData` | class (`@tomReflector`) | The data carried into one authentication attempt |
| `TomAuthenticationInfo` | class | A service's success result: principal + access-control definition |
| `TomDummyAuthenticationService` | class | Scaffolding-only default service (accepts any non-`GUEST` user) |
| `LoginException` | exception | A login failure; carried back as a failed result |
| `TomAuthenticationAdaptor` | annotation (`@tomReflector`) | Marks an adaptor and constrains it to guest/user flows |
| `Tom2FAAdaptor` | annotation (`@tomReflector`) | Marks a 2FA adaptor for a mechanism `type` |
| `Tom2FAService` | abstract (`@tomReflector`) | Placeholder contract for the (unimplemented) 2FA pass |

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
        │  or throws LoginException
        ▼
TomBearerAuthentication.convertPrincipalToTokenPayload
        │  → (public claims, encrypted private claims)
        ▼
TomAuthenticationResult
   ├─ authenticationToken   (JWT of public claims)
   └─ authorizationToken    (JWT of public claims + encrypted acd)
```

A thrown `LoginException` is **not** propagated — the server catches it and
returns a `TomAuthenticationResult` carrying the exception's `key` so the client
can show a localized message. Any other error becomes a
`"login.error.unknown"` result.

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
      throw LoginException('error.invalid-user-or-password', 'Invalid login');
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

## Wiring the Server

Register the service(s) and (optionally) the JWT issuer through the static
settings, then expose a subclass of `TomAuthenticationServer` as endpoints:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService = MyAuthService();
TomAuthenticationServer.globalSettingGuestAuthenticationService = MyGuestService();
TomAuthenticationServer.globalSettingJwtOrganization = 'acme';

// A @tomComponent subclass exposes authenticateGuest / authenticatePass1 as
// HTTP endpoints (see tom_uam_server for a full example).
class ServerAuthenticationServer extends TomAuthenticationServer { /* ... */ }
```

Until a real service is registered, the default
`TomDummyAuthenticationService` authenticates any non-`"GUEST"` user and logs an
error on every call — acceptable only while scaffolding.

## Core Components

### `TomAuthenticationServer`

The orchestrator. `authenticateGuest` and `authenticatePass1` run the flow
above (guest vs. user service); `authenticatePass2` (2FA) currently throws
`UnsupportedError`. The three static settings select the services and JWT
issuer process-wide.

### `TomAuthenticationService` / `TomAuthenticationInfo`

The contract you implement and the value it returns. `authenticateUser` either
returns a `TomAuthenticationInfo` (the `TomPrincipal` plus its
`TomAccessControlDefinition`) or throws a `LoginException`.

### `TomAuthenticationData`

A mutable carrier for one attempt; the server builds it from the wire message.

### Adaptor annotations

`TomAuthenticationAdaptor` (with `guestOnly` / `userOnly`) and `Tom2FAAdaptor`
(with `type`) are reflection-discoverable markers a runtime can enumerate to
route logins. Changing their shape requires regenerating reflection.

## Status and Limitations

- **Two-factor authentication is not implemented.** `authenticatePass2` throws
  `UnsupportedError`, `Tom2FAService` is an empty placeholder contract, and the
  `Tom2FAAdaptor` annotation has no consumer yet. Completing 2FA (email / SMS /
  authenticator mechanisms plus a client-side challenge UI channel) is tracked
  in the quest completion steps.
- **`TomDummyAuthenticationService` is for scaffolding only** — it grants any
  non-`GUEST` login. Replace it before any test or production use.

## Dependencies

- **`tom_core_kernel`**: `TomPrincipal`, `TomAccessControlDefinition`,
  `TomBearerAuthentication`, `TomServerJwtToken`, and the wire types
  `TomAuthenticationMessage` / `TomAuthenticationResult`.
- **Little Things** (this package): `TomServerException`, the base of
  `LoginException`.
