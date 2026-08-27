# Bearer Auth Module

The transport-neutral half of bearer-token authentication: an authenticator
interface, a rejection exception, and a closed set of three failure reasons.
Nothing here names a transport. A bearer token arrives, something validates it,
and the validation either yields a principal or fails for one of three reasons —
that sequence is identical whether the token rode in on an HTTP `Authorization`
header, an MCP `initialize` `_meta` field, a WebSocket handshake, or a queue
message envelope, so an edge on any of them reuses this module as-is.

The MCP-specific constants (the `_meta` slot and the JSON-RPC refusal code) live
one module over, in [MCP Auth](mcp_auth.md), and import this one. The direction
matters: MCP depends on the taxonomy, the taxonomy does not depend on MCP.

## Table of Contents

- [Overview](#overview)
- [Why It Is Its Own Module](#why-it-is-its-own-module)
- [Authenticators](#authenticators)
- [Failure Taxonomy](#failure-taxonomy)
- [What Stays Domain-Specific](#what-stays-domain-specific)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `BearerTokenAuthenticator<P>` | interface | Validates a token and resolves it to a principal of type `P` |
| `BearerAuthFailure` | exception | Raised when a token is rejected; carries a stable `reason` + a server-only `message` |
| `BearerAuthFailureReason` | enum | Closed set: `missing`, `malformed`, `rejected` |

## Why It Is Its Own Module

These three types used to sit in the same file as the MCP wire constants, under
`mcp_auth/`. They were transport-independent even then, but a non-MCP edge could
not reach them without importing a `_meta` key and a JSON-RPC error code it had
no use for — so edges re-declared the taxonomy instead of importing it.
`tom_brain_access`'s HTTP edge still carries a copy of `BearerAuthFailure` whose
`toString` is byte-identical to the one here, and it carries that copy *while
already depending on `tom_core_agentic`*: the dependency was there, the reuse
was not. Bundling, not availability, was the obstacle.

Splitting the file is what makes the reuse claim checkable rather than
aspirational. `test/bearer_auth_test.dart` imports
`src/bearer_auth/bearer_auth_contract.dart` directly rather than the package
barrel, so the separation is a compile-time fact: if the taxonomy were ever
folded back in beside the constants, that test would stop compiling.

## Authenticators

An edge binds one [`BearerTokenAuthenticator<P>`], parameterised on its
principal type. The interface is responsible for **authentication only** —
turning a token string into a principal, or rejecting it. *Authorisation* (role
/ entitlement checks against the principal) is the consuming edge's job, not the
contract's.

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

Implementations **must be synchronous**. Every transport that presents a bearer
token does so at a connection or request boundary that is on the hot path, so
this layer must not make an LLM / network call. The principal type parameter is
what keeps the contract identity-agnostic — a framework server binds
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
| `missing` | No bearer token was presented at all when the edge requires one |
| `malformed` | The token was present but could not be parsed (bad JWT, unknown format) |
| `rejected` | The token parsed but failed authentication (guest, expired, unknown subject) |

The three categories are the ones every transport can tell apart from the token
alone, which is what keeps them neutral: *where* the token was supposed to be is
the edge's business, not the enum's. An HTTP edge that finds no `Authorization`
header and an MCP server that finds no `_meta` entry both report `missing`.

> **Only the `reason` tag belongs on the wire.** Each edge translates a
> `BearerAuthFailure` into its own refusal — an HTTP 401, the JSON-RPC
> `bearerAuthRpcErrorCode`, a closed socket — but must **not** leak the
> underlying `message` to the client, because token-introspection error detail
> is a side channel for token-guessing attacks. No transport code lives on the
> exception itself; the mapping belongs to the edge. The reason set is closed by
> design: adding a category is a version bump, not a silent extension.

## What Stays Domain-Specific

This module is deliberately the *contract* only. The concrete authenticators
that bind a framework `TomPrincipal` (JWT-backed, static-token, …) and their
conformance tests live in their owning package (e.g. `tom_brain_memory`),
because they pull in `tom_core_kernel` identity types. Keeping the principal a
type parameter here is what lets the contract sit in the `tom_basics`-only tier.

## Core Components

- **`BearerTokenAuthenticator<P>`** — the synchronous, principal-parameterised
  authentication interface.
- **`BearerAuthFailure` / `BearerAuthFailureReason`** — the rejection exception
  and its closed reason set.

## Dependencies

- None. The contract file has no import directives at all — not `dart:async`,
  not another `tom_core_agentic` module — so it is reusable from any tier,
  including `dart:io`-forbidding consumers.
