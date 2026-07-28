# Authorization Module

A per-token cache of resolved authorization principals. Resolving the
[`TomPrincipal`] for an authentication token (loading roles, access-control
settings, etc.) is comparatively expensive, so the server caches the result
once and reuses it for the lifetime of the token instead of re-resolving it on
every request.

## Table of Contents

- [Overview](#overview)
- [Where It Fits](#where-it-fits)
- [Isolate Model](#isolate-model)
- [Lifetime and Expiry](#lifetime-and-expiry)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthorizationCache` | class | The main-isolate cache: `getPrincipal` / `storePrincipal` keyed by JWT token string |
| `TomAuthorizationCacheEntry` | class | One cached principal paired with its expiry (`deletionTime`) |
| `TomAuthorizationCacheException` | exception | Thrown when a cached entry exists but has expired |
| `TomAuthorizationCacheStoreMessage` | class | Cross-isolate command: store a principal in the main isolate |
| `TomAuthorizationCacheRetrieveMessage` | class | Cross-isolate command: read a principal from the main isolate |
| `TomAuthorizationCacheExecutor` | `TomExecutor` | Services the two messages in the main isolate |

## Where It Fits

The cache is read by the server's authentication middleware. On each incoming
request the middleware extracts the client JWT token, then asks the cache for
the matching principal before falling back to the principal carried on the
request itself:

```dart
var (TomPrincipal? callPrincipal, TomClientJwtToken? clientToken) =
    extractAuthentication(request);

var principal =
    (clientToken != null
        ? await TomAuthorizationCache.getPrincipal(clientToken)
        : null) ??
    callPrincipal;
```

The authorization layer that resolves a principal calls
`TomAuthorizationCache.storePrincipal(token, principal)` once, so subsequent
requests bearing the same token short-circuit straight to the cached value.

### This module does not decide access

Despite the name, nothing here grants or refuses anything. This is a **cache of
resolved principals** — it makes the *user* operand cheap to obtain, and stops
there. The access decision itself is `TomAccessControl` in `tom_core_kernel`,
and it has a second operand this module never sees: the deployment's own grants,
which cap the user's.

If you are here because a permission that is clearly present was refused
anyway, this is the wrong document. Read `tom_core_kernel`'s
`doc/security/security.md` §"The Server Principal and the Meet", and check
`TomServerPrincipal.current` before you check the cache.

## Isolate Model

The cache is a single map that lives in the **main isolate**, keyed by the JWT
token string. Worker isolates do not keep their own copy. Both entry points
detect the calling isolate via `TomWorker.isMainIsolate`:

```text
main isolate              worker isolate
─────────────             ──────────────
getPrincipal  ──────────  getPrincipal
   │ reads _cache            │ TomWorker.executeInCreator(
   ▼                        │   TomAuthorizationCacheRetrieveMessage)
TomPrincipal?               ▼
                       TomAuthorizationCacheExecutor (main isolate)
                            │ → TomAuthorizationCache.getPrincipal
                            ▼
                       TomPrincipal?
```

`storePrincipal` works the same way, forwarding a
`TomAuthorizationCacheStoreMessage`. This keeps one authoritative copy of the
cache reachable from every request regardless of which isolate handles it.

## Lifetime and Expiry

Each `TomAuthorizationCacheEntry` carries a `deletionTime`. When stored via
`storePrincipal`, this is set from the token's `validUntil` payload claim, so a
cached principal expires together with the token that authorized it. A
constructed entry with no explicit time defaults to one day.

Expiry is enforced two ways:

- **Lazily on read** — `getPrincipal` throws
  `TomAuthorizationCacheException` if a matching entry is found but already
  past its `deletionTime`. The distinct exception type lets the caller catch it
  specifically and treat it as a prompt to re-authorize (a true cache *miss*,
  by contrast, simply returns `null`).
- **Eagerly on a timer** — a periodic timer sweeps the map once an hour and
  removes entries whose `deletionTime` has passed, so stale principals do not
  accumulate.

## Core Components

- **`TomAuthorizationCache`** — the cache itself. Public surface is the two
  static methods `getPrincipal` and `storePrincipal`; the backing map is
  private.
- **`TomAuthorizationCacheEntry`** — value object pairing the
  `authorizedPrincipal` with its `deletionTime`.
- **`TomAuthorizationCacheException`** — signals an expired-but-present entry.
- **`TomAuthorizationCacheStoreMessage` / `TomAuthorizationCacheRetrieveMessage`**
  — the commands worker isolates send to the main isolate.
- **`TomAuthorizationCacheExecutor`** — the `TomExecutor` registered in the
  main isolate that turns those commands back into `TomAuthorizationCache`
  calls.

## Dependencies

- `tom_core_kernel` — `TomPrincipal`, `TomClientJwtToken`, `TomWorker`,
  `TomExecutor`, `TomException`, and the logging helpers.
