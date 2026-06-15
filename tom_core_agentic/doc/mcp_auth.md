# MCP Auth Module

The single, domain-free bearer-token contract that every MCP (Model Context
Protocol) server in the framework shares. It defines *how* a bearer token is
carried at `initialize` time, *which* JSON-RPC error code an authentication
failure returns, and *what* an authenticator looks like — without binding any
particular identity model. Concrete authenticators (the code that turns a token
into a framework `TomPrincipal`) bind `tom_core_kernel` types and stay in their
owning package; this module keeps the principal a type parameter so it can be
reused without dragging the kernel into the `tom_basics`-only agentic tier.

## Table of Contents

- [Overview](#overview)
- [The Wire Contract](#the-wire-contract)
- [Authenticators](#authenticators)
- [Failure Taxonomy](#failure-taxonomy)
- [What Stays Domain-Specific](#what-stays-domain-specific)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `bearerTokenMetaKey` | `const String` | The JSON-RPC `_meta` key a client uses to carry the bearer token at `initialize` |
| `bearerAuthRpcErrorCode` | `const int` | The JSON-RPC error code (`-32001`) a server returns when bearer auth fails |
| `BearerTokenAuthenticator<P>` | interface | Validates a token and resolves it to a principal of type `P` |
| `BearerAuthFailure` | exception | Raised when a token is rejected; carries a stable `reason` + a server-only `message` |
| `BearerAuthFailureReason` | enum | Closed set: `missing`, `malformed`, `rejected` |

## The Wire Contract

The MCP wire protocol does **not** carry an `Authorization` header on
stdio / UNIX-socket transports. The only request-level extensibility point at the
`initialize` boundary is the JSON-RPC `_meta` map, so the token rides there under
a well-known, namespaced key:

```dart
// Client side: place the token in _meta at initialize.
final initializeMeta = <String, Object?>{
  bearerTokenMetaKey: '<bearer-token>',
};
```

The key is namespaced (`tomBrainBearerToken`) so it cannot collide with the MCP
standard `_meta.progressToken` reservation or with any other `_meta` consumer a
host layers on. When authentication fails the server returns
`bearerAuthRpcErrorCode` (`-32001`) — a value inside the JSON-RPC 2.0
server-defined implementation range (`-32099 … -32000`), shared so every MCP
server in the framework refuses with the same code.

## Authenticators

A server binds one [`BearerTokenAuthenticator<P>`], parameterised on its
principal type. The interface is responsible for **authentication only** —
turning a token string into a principal, or rejecting it. Per-tool
*authorisation* (role / entitlement checks against the principal) is the
consuming server's job, not the contract's.

```dart
final class StaticAuthenticator implements BearerTokenAuthenticator<String> {
  final Map<String, String> _tokens;
  const StaticAuthenticator(this._tokens);

  @override
  String authenticate(String token) {
    if (token.isEmpty) {
      throw const BearerAuthFailure(BearerAuthFailureReason.missing, 'No token.');
    }
    final principal = _tokens[token];
    if (principal == null) {
      throw const BearerAuthFailure(BearerAuthFailureReason.rejected, 'Unknown token.');
    }
    return principal;
  }
}
```

Implementations **must be synchronous**: the `initialize` handshake is on the hot
path and must not make an LLM / network call at this layer. The principal type
parameter is what keeps the contract identity-agnostic — a framework server binds
`BearerTokenAuthenticator<TomPrincipal>`, while a test or a different host binds
any other type. Because the parameter is covariant, a `<String>` authenticator is
also a `BearerTokenAuthenticator<Object>`, so generic plumbing can accept the raw
interface while a server holds the narrowly-typed one.

## Failure Taxonomy

[`BearerAuthFailure`] carries a stable [`BearerAuthFailureReason`] tag plus a
human-readable `message`. The tag is for telemetry and tests; the message is for
**server-side logs only**.

| Reason | Meaning |
| ------ | ------- |
| `missing` | No `_meta` bearer-token field was present when the server requires one |
| `malformed` | The token was present but could not be parsed (bad JWT, unknown format) |
| `rejected` | The token parsed but failed authentication (guest, expired, unknown subject) |

> **Only the `reason` tag belongs on the wire.** A server translates a
> `BearerAuthFailure` into a JSON-RPC error (`bearerAuthRpcErrorCode`) but must
> **not** leak the underlying `message` to the client — token-introspection error
> detail is a side channel for token-guessing attacks. The reason set is closed
> by design: adding a category is a version bump, not a silent extension.

## What Stays Domain-Specific

This module is deliberately the *contract* only. The concrete authenticators that
bind a framework `TomPrincipal` (JWT-backed, static-token, …) and their
conformance tests live in their owning package (e.g. `tom_brain_memory`), because
they pull in `tom_core_kernel` identity types. Keeping the principal a type
parameter here is what lets the contract sit in the `tom_basics`-only tier and be
reused by future thinking / planning / creation / procedure MCP servers without
each re-deriving a failure taxonomy and an error code.

## Core Components

- **`bearerTokenMetaKey` / `bearerAuthRpcErrorCode`** — the two wire constants
  (the `_meta` slot and the JSON-RPC failure code).
- **`BearerTokenAuthenticator<P>`** — the synchronous, principal-parameterised
  authentication interface.
- **`BearerAuthFailure` / `BearerAuthFailureReason`** — the rejection exception
  and its closed reason set.

## Dependencies

- None beyond the Dart core library. The module is `dart:io`-free and depends on
  no other `tom_core_agentic` module, so it is reusable from any tier (including
  `dart:io`-forbidding consumers).
