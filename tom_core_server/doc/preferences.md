# Preferences Module

Server-stored per-principal preferences: a `tom_user_preference` table, a typed
service over it, and the four `/preferences/*` endpoints a device reaches it
through.

## Table of Contents

- [Overview](#overview)
- [The Caller Is the Zone](#the-caller-is-the-zone)
- [Authorization Is the Row Scope](#authorization-is-the-row-scope)
- [The Table and Its Migration](#the-table-and-its-migration)
- [The Endpoints](#the-endpoints)
- [Reading a Preference During Login](#reading-a-preference-during-login)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomUserPreference` | reflected entity | The `tom_user_preference` row; carries the row scope |
| `TomUserPreferenceRepository` | CRUD repository | Persists that entity |
| `TomUserPreferences` | bean-installed service | Typed reads and writes of the caller's preferences |
| `TomUserPreferenceException` | exception | Raised when an operation cannot identify the caller |
| `TomUserPreferencesServer` | reflected API implementation | The `/preferences/*` handlers |

The *contract* is not here. The keys (`TomUserPreferenceKeys`), the wire DTOs
(`TomUserPreferenceDto` and friends), the value codec
(`TomUserPreferenceCodec`) and the API declaration (`tomUserPreferencesApi`) all
live in `tom_core_kernel`'s `preferences` module, because a client and a server
must agree on them and the kernel is the one package both already depend on.
This module is the store.

### Why a service rather than a repository

The repository persists *rows*; the service persists *values*. Every consumer of
a preference wants a `String` timezone or a reflected settings object, not a row
carrying JSON text plus a type name — and if each of them did the encode/decode
itself, each would decide independently whether a `DateTime` is written local or
UTC and whether a mismatched read is an error or a coercion. The codec makes
that decision once; the service is what makes the codec unavoidable.

## The Caller Is the Zone

`get`, `set`, `read`, `all` and `remove` take **no principal**. They read the one
in the request zone — the same principal the `owner` scope resolves against — so
the value a handler stores and the row the repository permits it to store can
never disagree. An API that took a principal would invite a handler to pass one
it read off the request, which is precisely the parameter the endpoints
deliberately do not have.

```dart
final preferences = TomUserPreferences.resolve()!;
await preferences.set(TomUserPreferenceKeys.timezone, 'Europe/Berlin');
final timezone = await preferences.getOr(TomUserPreferenceKeys.timezone, 'UTC');
```

`getFor(principal, key)` is the single exception — see
[Reading a Preference During Login](#reading-a-preference-during-login).

Without a principal, an operation throws `TomUserPreferenceException`
(`preferences.no_principal`) rather than returning `null`: there is no row to
read and no owner to write, and the alternative — an unowned row — is one the
scope would reject on the next read anyway, having already been stored.

### Typed access

| Method | Returns | Description |
|--------|---------|-------------|
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference of the caller |
| `read(key)` | `Future<TomUserPreferenceDto?>` | One preference as stored, or `null` |
| `get<T>(key)` | `Future<T?>` | Decoded as a `T`; `null` when never written |
| `getOr<T>(key, fallback)` | `Future<T>` | `get`, with a default for the unwritten case |
| `set<T>(key, value)` | `Future<TomUserPreferenceDto>` | Encodes and upserts |
| `setEncoded(key, valueType:, valueJson:)` | `Future<TomUserPreferenceDto>` | Upserts a value that arrives already encoded |
| `remove(key)` | `Future<bool>` | Deletes; answers whether a row was removed |
| `getFor<T>(principal, key)` | `Future<T?>` | `get` for a principal that is not the zone's |

`getOr` answers its fallback only for a preference that has **never been
written**. A type *mismatch* still throws: an unwritten preference is an ordinary
state that a default answers, while a preference stored as the wrong type is a
bug, and silently answering the fallback would hide it.

### Every key is checked on the way in

`read`, `get`, `set`, `setEncoded` and `remove` reject a key that does not
satisfy the kernel's `TomUserPreferenceKeys` rule — 1–191 characters, starting
with an ASCII letter, thereafter letters, digits, `.`, `_` and `-` — with
`TomUserPreferenceKeyException` (`preferences.key.invalid`).

That is not a redundant second guard on something the client already refused.
The endpoints read the key off the request URL, so on this side it is untrusted
input, and `maxLength` is `preference_key`'s own column width: a wider key would
be stored truncated, silently merging two preferences into one row.

Each of them checks the key *first*, before the caller is resolved from the
zone. A bad key is the one fault the caller can see from the call site, so it is
the one worth reporting when the ambient state is unusable too; the reverse
ordering answers `preferences.no_principal` to a call that was malformed anyway,
and sends the caller after the wrong problem.

## Authorization Is the Row Scope

The entity declares:

```dart
@TomDbScope(field: 'principal_id', scope: 'owner')
```

and that single line is the whole "a principal reads and writes only their own"
rule. The CRUD repository ANDs `principal_id IN (:__tomscope_0)` into every read,
rejects an update or delete that would touch an out-of-scope row, and rejects an
insert scoped to a principal other than the caller — all from the principal in
the request zone, none of it restated in a handler.

The endpoints therefore carry **no** ownership check, and no URI carries a
principal. One principal reading another's preferences is not *rejected*: the
query never selects the row. A hand-written `if (principal.id != row.principalId)`
in the service would be a second copy of a rule that already exists, and the copy
that is forgotten on the fourth endpoint is the one that leaks.

`principalId` is an `int` rather than a stringified id because the built-in
`owner` resolver yields `TomPrincipal.id` — an `int`. A `String` column would
compare a stringified id against an integer bind value and match nothing, which
is a scope that denies everything: secure, and silently useless.

### Why the lookups name the principal anyway

The scope already confines every statement to the caller, so
`FIND BY preference_key = :key` would be correct inside a request. The service's
queries still say `principal_id = :principalId` because `TomDataScope.runUnscoped`
exists: inside an administrative bypass the scope deliberately filters nothing,
and a lookup that relied on it would then find — and `set` would then overwrite —
some other principal's row. Naming the principal keeps the *lookup* meaning
"mine" under every scope state. It is not a second copy of the authorization: the
scope still decides what may be written, and it is the scope that rejects an
attempt to write elsewhere.

## The Table and Its Migration

```sql
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id BIGINT NOT NULL,
  preference_key VARCHAR(191) NOT NULL,
  value_type VARCHAR(191) NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_preference (principal_id, preference_key),
  KEY idx_tom_user_preference_principal (principal_id)
);
```

`(principal_id, preference_key)` is unique because that pair *is* the
preference's identity: writing a key twice must replace the value, and a
duplicate would make which value a user gets depend on row order. `set` reuses
the row it finds rather than inserting a second — the repository takes its
`UPDATE` path exactly when the surrogate key is set, so carrying the id over is
what makes the write an upsert.

The DDL ships as the framework migration
`migrations/main/tomcore/[1]-create_tom_user_preference.sql`, reproduced verbatim
from `TomUserPreference.createTableSql` so the two cannot drift —
`test/reference_migrations_test.dart` fails if they do. The filename is
**untagged**, so it applies in every environment — a preference table that
existed only in production would fail every test that touched it, and one that
existed only in test would fail in production.

`updated_at` is the server's clock, never the caller's, which is why the write
DTO carries no timestamp. It is normalised to UTC by `toDto()` on the way out:
MariaDB's `DATETIME` carries no zone, so the datasource writes a UTC instant as
its local equivalent and reads it back flagged local. That is the right
convention *inside* the server and the wrong one at its edge, where the DTO is
serialized to ISO-8601 for a client that may be in another zone.

## The Endpoints

`TomUserPreferencesServer` implements the kernel's
`TomUserPreferencesApiService` and is annotated
`@TomApiImplementation(apiId: tomUserPreferencesApiId)`, so the endpoints
pipeline binds each method to the contract's declaration:

| Endpoint | Method | URI | Behaviour |
|----------|--------|-----|-----------|
| `listPreferences` | GET | `/preferences` | Every preference of the caller |
| `readPreference` | GET | `/preferences/{key}` | One preference; `preferences.not_found` when absent |
| `writePreference` | PUT | `/preferences/{key}` | Validates the encoded pair, then upserts |
| `deletePreference` | DELETE | `/preferences/{key}` | Deletes; absent is not an error |

Access is `TomAuthenticatedAccess`, declared **on the contract** and extracted by
the pipeline — the handlers carry no inline access annotation.

Reporting a missing key distinctly is safe precisely because the scope makes
"not yours" indistinguishable from "not there": the answer leaks nothing about
another principal. A delete of something absent has already achieved its purpose,
so a client clearing a preference twice is not a client doing anything wrong.

### A miss is a 404, a bad key is a 400, and nothing else is either

Neither `preferences.not_found` nor `preferences.key.invalid` helps a client
unless it *arrives* as something a client can branch on, and by default every
handler failure leaves as a `500`. So each key-taking endpoint is served under
`TomUserPreferencesErrorHandler`:

```dart
@TomApiEndpointImplementation(
  apiId: tomUserPreferencesApiId,
  endpointId: tomUserPreferencesReadEndpointId,
  errorHandler: TomUserPreferencesErrorHandler(),
)
```

| Error key | Status | Why it is not a server fault |
|-----------|--------|------------------------------|
| `preferences.not_found` | `404` | A preference that was never written is a miss, not a break |
| `preferences.key.invalid` | `400` | The key arrives in the request URL, so a bad one is a bad *request* |

Everything else goes to `handleErrorDefault` and stays a `500`. The narrowness
is the design: a client must be able to tell "you have no such preference" from
"the server is broken", and a client that cannot must either treat every
failure as a miss or every miss as a failure. Mapping
`preferences.not_configured` — a deployment fault — the same way would let a
client read an outage as absence and paper it over with a default. Answering
`500` for a malformed key makes the
opposite mistake: it tells a client its own bad request is worth retrying.

**Read, write and delete all carry the handler**; the list endpoint carries none
and needs none. The key sits in the path of all three, so a `400` only the read
could produce would leave two thirds of the surface answering `500` for the same
mistake — while the list endpoint takes no key and cannot miss, since an empty
list is an answer.

`TomUserPreferencesClient` (`tom_core_flutter`) is the counterpart: `404` is the
only status it reads as absence, so `read` and `get` answer `null` and `getOr`
answers its fallback, while every other status throws. It rarely sees the `400`
at all — it validates the key before building the request — but the server
cannot rely on that, because a client is not the only thing that can send an
HTTP request.

The write path validates the declared type against the JSON text before storing.
The request carries the value already encoded, so nothing on the way in has
proved the two agree — and a disagreeing pair costs nothing to store and fails
every future read of that key, on every device.

The API contract is registered by the pipeline itself
(`TomEndpointRouting.registerFrameworkApis`), so a deployment gets these
endpoints without adding a line. The handler needs no bean: like every
component with a no-argument constructor, the pipeline instantiates it.

### Installing the store

The endpoints resolve `TomUserPreferences` per call, so a deployment installs it
once at bootstrap:

```dart
TomBean.withType(
  TomUserPreferences,
  TomUserPreferences(TomUserPreferenceRepository()),
);
```

Resolving per call rather than holding the store means a deployment that installs
its own `TomUserPreferences` bean *after* the pipeline constructed the handler is
still obeyed. With no bean installed, the endpoints answer
`preferences.not_configured` — a deployment that never created the table gets a
message naming the missing wiring rather than an SQL error.

## Reading a Preference During Login

The authentication path needs a preference *before* a request zone exists — the
principal only comes into being once the credentials have been accepted. That is
what `getFor` is for: it installs the principal in a zone and delegates, so even
that path reaches the same scoped query instead of getting its own unscoped
lookup.

The framework uses it at the single token-minting point to resolve the user's
timezone: a stored `tom.timezone` wins over the timezone the client asserts about
itself, because the stored one is the user's *choice* and the asserted one is
only wherever the device happens to be. A read failure is logged and degrades to
the client assertion, so a deployment that has not run the migration cannot
block every login.

## Core Components

- **`TomUserPreference`** — the reflected entity: the row, its scope, its
  `toDto()`, and the `createTableSql` the migration reproduces.
- **`TomUserPreferenceRepository`** — the CRUD repository, shipped rather than
  left to the deployment because the service would otherwise be unusable without
  one empty line.
- **`TomUserPreferences`** — the typed service; installed as a bean so an
  application can substitute a caching or read-only implementation without any
  consumer changing.
- **`TomUserPreferencesServer`** — the `/preferences/*` implementation.

## Dependencies

- `tom_core_kernel` — `TomUserPreferenceKeys`, the wire DTOs,
  `TomUserPreferenceCodec`, `tomUserPreferencesApi`, `TomBean`, `TomPrincipal`.
- The object-persistence module — `@TomDbTable`, `@TomDbColumn`, `@TomDbScope`,
  `TomSqlDatasourceRepository` (see `doc/object_persistence.md`).
- The endpoints module — `@TomApiImplementation`,
  `@TomApiEndpointImplementation`, the routing pipeline (see
  `doc/endpoints.md`).
- The database-migration module — the untagged framework migration (see
  `doc/db_migration.md`).
