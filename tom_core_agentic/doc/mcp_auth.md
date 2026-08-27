# MCP Auth Module

The two MCP-specific facts about bearer-token authentication, shared so that
every MCP (Model Context Protocol) server in the framework refuses the same way
and every client has one slot to fill: *where* a token is carried at
`initialize` time, and *which* JSON-RPC error code an authentication failure
returns. Both are constants; there is no logic in this module.

The interface an authenticator implements and the failure taxonomy it throws are
**not** MCP facts and are not here. They live in [Bearer Auth](bearer_auth.md),
which this module imports and which an HTTP or WebSocket edge reuses without
taking on anything below.

## Table of Contents

- [Overview](#overview)
- [The Wire Contract](#the-wire-contract)
- [Translating a Failure](#translating-a-failure)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `bearerTokenMetaKey` | `const String` | The JSON-RPC `_meta` key a client uses to carry the bearer token at `initialize` |
| `bearerAuthRpcErrorCode` | `const int` | The JSON-RPC error code (`-32001`) a server returns when bearer auth fails |

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
host layers on.

## Translating a Failure

A server holds a `BearerTokenAuthenticator<P>` from
[Bearer Auth](bearer_auth.md), calls it with whatever it found under
`bearerTokenMetaKey`, and turns a thrown `BearerAuthFailure` into a JSON-RPC
error:

```dart
final token = meta[bearerTokenMetaKey] as String? ?? '';
try {
  principal = authenticator.authenticate(token);
} on BearerAuthFailure catch (failure) {
  // Only the reason tag goes on the wire — never failure.message.
  respondWithError(code: bearerAuthRpcErrorCode, data: failure.reason.name);
}
```

`bearerAuthRpcErrorCode` (`-32001`) sits inside the JSON-RPC 2.0 server-defined
implementation range (`-32099 … -32000`); it is named so the value is never a
bare literal at the throw site, and shared so every MCP server in the framework
refuses with the same code. It is the **MCP half** of the translation — an HTTP
edge maps the same `BearerAuthFailureReason` onto a 401 instead, which is why
the code is here and the taxonomy is not.

## Core Components

- **`bearerTokenMetaKey`** — the `_meta` slot the token rides in at
  `initialize`.
- **`bearerAuthRpcErrorCode`** — the JSON-RPC code an MCP server refuses with.

## Dependencies

- [Bearer Auth](bearer_auth.md), for the `BearerAuthFailure` /
  `BearerTokenAuthenticator` types the constants are used with. Nothing beyond
  the Dart core library otherwise; the module is `dart:io`-free.
