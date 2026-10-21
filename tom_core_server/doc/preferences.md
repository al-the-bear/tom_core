# Preferences Module

Server-stored per-principal preferences: a `tom_user_preference` table, a typed
service over it, and the four `/preferences/*` endpoints a device reaches it
through.

## Table of Contents

- [Overview](#overview)
  - [Why a service rather than a repository](#why-a-service-rather-than-a-repository)
- [The Caller Is the Zone](#the-caller-is-the-zone)
  - [Typed access](#typed-access)
  - [Every key is checked on the way in](#every-key-is-checked-on-the-way-in)
- [Authorization Is the Row Scope](#authorization-is-the-row-scope)
  - [Why the lookups name the principal anyway](#why-the-lookups-name-the-principal-anyway)
- [The Table and Its Migration](#the-table-and-its-migration)
- [The Store Is Bounded](#the-store-is-bounded)
- [When a Preference Was Written](#when-a-preference-was-written)
- [The Endpoints](#the-endpoints)
  - [A miss is a 404, a bad request a 400, a full account a 409](#a-miss-is-a-404-a-bad-request-a-400-a-full-account-a-409)
  - [Installing the store](#installing-the-store)
- [Reading a Preference During Login](#reading-a-preference-during-login)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomUserPreference` | class | The `tom_user_preference` row; carries the row scope, and declares its principal the data subject and its value personal for the privacy module |
| `TomUserPreferenceRepository` | class | Persists that entity |
| `TomUserPreferences` | class | Typed reads and writes of the caller's preferences |
| `TomUserPreferenceException` | class | Raised when an operation cannot identify the caller |
| `TomUserPreferencesServer` | class | The `/preferences/*` handlers |
| `TomUserPreferencesErrorHandler` | class | Maps `preferences.not_found` to a `404`, `preferences.key.invalid` and every `preferences.encoded.*` refusal to a `400`, and `preferences.limit.exceeded` to a `409` — and no other key to anything |

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
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference of the caller, ordered by key |
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

`all()` orders by key, and the query says so. An unordered `SELECT` returns rows
in whatever order the engine finds convenient, which shifts as the table is
rewritten, as rows are deleted and reinserted, or as the planner picks a
different index — so a list a caller renders would reshuffle for reasons that
have nothing to do with the data, and two devices could show the same
preferences in two orders. The key is the ordering column because it is the one
column unique per caller that never changes while the preference exists:
rewriting a value must not move it in the list. It also costs nothing —
`uq_tom_user_preference (principal_id, preference_key)` already covers
`WHERE principal_id = ? ORDER BY preference_key`, so the rows arrive in order
off the index rather than through a sort.

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

`principalId` holds `TomPrincipal.qualifiedId` — the principal id qualified by
its tenant, `tenant:<tenant>/<id>`, or the bare id in a deployment without
tenancy — because that is what the built-in `owner` resolver yields. A principal
id is unique within its tenant only; under `shared` isolation every tenant's
preferences sit in this one table, and the qualified key keeps two tenants' `u1`
apart. See [tenancy.md](tenancy.md#principals-per-tenant).

### Why the lookups name the principal anyway

The scope already confines every statement to the caller, so
`FIND BY preference_key = :key` would be correct inside a request. The service's
queries still say `principal_id = :principalId` because `TomDataScope.runUnscoped`
exists: inside an administrative bypass the scope deliberately filters nothing,
and a lookup that relied on it would then find — and `set` would then overwrite —
some other principal's row. `clear` is where that matters most: a bulk delete
without the predicate, run inside a bypass, is every account on the server, and
the suite asserts it against a second principal from inside `runUnscoped`
rather than leaving the claim to this paragraph. Naming the principal keeps the *lookup* meaning
"mine" under every scope state. It is not a second copy of the authorization: the
scope still decides what may be written, and it is the scope that rejects an
attempt to write elsewhere.

## The Table and Its Migration

```sql
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  preference_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_type VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME(6) NULL,
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

**`preference_key` and `value_type` name their collation, `utf8mb4_bin`.** Left
to the server default — on MariaDB and MySQL commonly a case-insensitive one —
the unique key would treat `device.Theme` and `device.theme` as one preference:
the second write would silently replace the first, while the device store keeps
both, so a preference moving in from the device could lose a sibling with
nothing reported. The binary collation also makes `ORDER BY preference_key` the
code-unit order the contract promises, uppercase before lowercase, which is the
order the device store answers too. `value_type` holds a Dart type name, which is
equally case-significant. On PostgreSQL the translated DDL carries the same
guarantee as `COLLATE "C"`, which `PostgresSqlDialect.translateCanonical` writes
for a binary collation. Schema convergence does not compare collations, so
this is guaranteed by the DDL alone: a table created some other way has to state
it as well.

The DDL ships as the framework migration
`migrations/main/tomcore/[1]-create_tom_user_preference.sql`, reproduced verbatim
from `TomUserPreference.createTableSql` so the two cannot drift —
`test/reference_migrations_test.dart` fails if they do. Its PostgreSQL form,
generated from it, is `migrations_postgresql/main/tomcore/[1]-create_tom_user_preference.sql`
(see [db_migration.md](db_migration.md#reference-migrations-for-postgresql)). The filename is
**untagged**, so it applies in every environment — a preference table that
existed only in production would fail every test that touched it, and one that
existed only in test would fail in production.

`updated_at` is the server's clock, never the caller's, which is why the write
DTO carries no timestamp. It is stored and read as an instant: MariaDB's
`DATETIME` (PostgreSQL's `TIMESTAMP`) carries no zone, so the datasource writes every `TomDbDateTime`
column as UTC text and reads it back UTC-flagged (`datasources/sql_instant.dart`
states the convention). `toDto()` normalises to UTC again on the way out, which
is a no-op for a loaded row and the guard for a DTO built any other way — at the
server's edge the flag is load-bearing, because the DTO is serialized to
ISO-8601 for a client that may be in another zone and a local-flagged instant
renders without an offset.

## The Store Is Bounded

`all()` — and so the list endpoint — answers every preference the caller holds,
with no page and no filter. That is safe because the store is bounded by the
two ceilings the kernel contract declares:

| Ceiling | Value | Where it is enforced | Refusal |
|---------|-------|----------------------|---------|
| `tomUserPreferencesMaxPerPrincipal` | 256 preferences | `set` / `setEncoded`, when the write would **add** a key | `TomUserPreferenceException`, `preferences.limit.exceeded` |
| `TomUserPreferenceCodec.maxValueBytes` | 16 KiB of encoded value | the codec, which `set` encodes with and `setEncoded` validates with | `TomUserPreferenceCodecException`, `preferences.encode.too_large` / `preferences.encoded.too_large` |

The count is checked only for a key the caller does not hold yet: replacing a
preference is never refused for the count, so a principal at the ceiling can
still change every setting it has, and removing one frees a place. It is
counted with the principal named, for the same reason the lookups name it —
inside `TomDataScope.runUnscoped` the scope filters nothing, and a count that
relied on it would be everyone's. It is read before the insert, so two inserts
racing for the last place can both pass and leave the caller one or two over;
the ceiling exists to keep the list small, not to be exact.

The value ceiling sits well inside the column: `value_json` is `TEXT`, 64 KiB in
MariaDB and unbounded in PostgreSQL. So an oversized value is refused as the caller's mistake, by the codec,
before the statement is built — rather than failing inside the database as a
fault of the server's, or, under a lax SQL mode, being truncated into text that
is no longer JSON.

Together they cap the largest list at about four megabytes; a real one is a few
hundred bytes.

**So the wire is unpaged on purpose, and `all()` takes a window anyway.** The
list endpoint returns the whole set because the set is bounded above — that is
the argument, and it is the contract's own
(`TomUserPreferencesApiService.listPreferences`: "Unpaged, and bounded"). Adding
a page parameter to it would be a three-package change — the declaration lives
in `tom_core_kernel` and `tom_core_flutter`'s client implements it — to push
paging into every client for a list that cannot exceed 256 entries. An
application that outgrows this is not storing preferences; it is storing
collection data in a settings store, and the answer there is a table of its own.

`TomUserPreferences.all()` nevertheless takes an optional `TomPageRequest`,
because a caller on *this* side of the wire is not bound by that argument: a
migration walking one principal's settings, or a job reading in batches, has a
use for a window that no client does, and the repository's finders already
accept one. The window applies to the same ordered sentence — page 2 is the
rows after page 1, not whatever the engine returned second — which is what
makes it a window rather than a sample.

This paragraph and the two ceilings above it are pinned against the kernel's
constants by `test/preferences_service_test.dart`: a ceiling raised without the
document following would leave the argument for returning the list whole
reading exactly as convincingly while being wrong.

## When a Preference Was Written

Every row carries `updated_at`, written from the **server's** clock on each
upsert and normalised to UTC on the way out. The write request carries no
timestamp of its own, and deliberately: when a preference was written is the
server's answer, never the client's claim — two devices whose clocks disagree
would otherwise store two different answers to the same question.

**Nothing compares two of them, and that is a decision rather than an
oversight.** A timestamp earns its keep when something can be *stale*, and in
this module nothing can: `TomUserPreferencesClient` holds no cache — `all`,
`read` and `get` are each an HTTP call that branches on the status — so a second
device does not hold an old value to discover, it simply asks. A conditional
read (`If-Modified-Since`, an ETag) or a `list-since` would therefore be a
mechanism with no consumer, and building one means changing the declaration in
`tom_core_kernel`, the server and `tom_core_flutter`'s client together for a
capability nothing yet asks for.

The device store (`TomDevicePreferences`, `tom_core_flutter`) is **not** a cache
of this one and must not be read as one. It exists for the preferences that must *not* follow the user — which
account was last used on this device, whether this device's biometric unlock is
on — and it fills `updatedAt` from its own clock for its own rows. The two
stores share one DTO shape so that a value can *move* between them when it turns
out to belong to the user rather than the device; comparing one store's
timestamp against the other's would be comparing two different facts.

So what the field is for, today, is what it says: the server's answer to when
this preference was last written. That is worth returning — an application that
shows "changed 3 days ago", an operator reading a row, a support question about
which device wrote last — and it is the one part of the answer a client cannot
compute for itself.

If a client ever does cache, this is what has to change: the contract gains a
conditional read or a `since` window, the server compares against the stored
value, and this section is rewritten. `test/preferences_dto_test.dart` fails the
moment a comparison appears in shipped code that handles preferences, so the
rewrite cannot be forgotten.

## The Endpoints

`TomUserPreferencesServer` implements the kernel's
`TomUserPreferencesApiService` and is annotated
`@TomApiImplementation(apiId: tomUserPreferencesApiId)`, so the endpoints
pipeline binds each method to the contract's declaration:

| Endpoint | Method | URI | Behaviour |
|----------|--------|-----|-----------|
| `listPreferences` | GET | `/preferences` | Every preference of the caller — unpaged, and bounded by [the store's ceilings](#the-store-is-bounded) |
| `readPreference` | GET | `/preferences/{key}` | One preference; `preferences.not_found` when absent |
| `writePreference` | PUT | `/preferences` | Validates the encoded pair, then upserts the key named in the body; refuses a value over 16 KiB (`400`) and a new key beyond the principal's 256 (`409`) |
| `deletePreference` | DELETE | `/preferences/{key}` | Deletes one; absent is not an error |
| `clearPreferences` | DELETE | `/preferences` | Deletes every preference of the caller in one statement; an account holding none is cleared, not refused |

Access is `TomAuthenticatedAccess`, declared **on the contract** and extracted by
the pipeline — the handlers carry no inline access annotation.

The write is the one key-taking endpoint with no `{key}` in its URI, and that
too is the contract's decision. Its request already carries a `key` field, so a
path capture would let one request name two preferences; `writePreference`
therefore reads `request.key` and there is no path key it could contradict.

Reporting a missing key distinctly is safe precisely because the scope makes
"not yours" indistinguishable from "not there": the answer leaks nothing about
another principal. A delete of something absent has already achieved its purpose,
so a client clearing a preference twice is not a client doing anything wrong.

**The two deletes differ by one path segment**, and that is the whole of the
difference between removing one preference and removing all of them. The bulk
route exists because an account reset written as a loop — list, then delete each
— can stop half way, and what it leaves is a set of preferences nobody chose, on
the one store every device the user owns reads. `clear()` issues a single
`DELETE ... WHERE principal_id = ?`, which either happens or does not.

It takes nothing from the caller — no key, no filter — so there is no malformed
input for a `400` to describe and it is served under the framework's default
error handler rather than this module's. A partial clear is `deletePreference`
repeated, and a caller that wants one already has it.

### A miss is a 404, a bad request a 400, a full account a 409

None of `preferences.not_found`, `preferences.key.invalid`, the write
boundary's `preferences.encoded.*` refusals or `preferences.limit.exceeded`
helps a client unless it *arrives* as something a client can branch on, and by
default every handler failure leaves as a `500`. So each key-taking endpoint is
served under `TomUserPreferencesErrorHandler`:

```dart
@TomApiEndpointImplementation(
  apiId: tomUserPreferencesApiId,
  endpointId: tomUserPreferencesReadEndpointId,
  errorHandler: TomUserPreferencesErrorHandler(),
)
```

| Error key | Status | Why it is not a server fault |
|-----------|--------|------------------------------|
| `preferences.not_found` (the kernel's `tomUserPreferencesNotFoundErrorKey`) | `404` | A preference that was never written is a miss, not a break |
| `preferences.key.invalid` | `400` | The key is the caller's input — the URL for a read or a delete, the body for a write — so a bad one is a bad *request* |
| `preferences.encoded.*` — `too_large`, `invalid_json`, `type_mismatch`, `not_an_instant` | `400` | The encoded value is the caller's input too, arriving in the write's body |
| `preferences.limit.exceeded` (the kernel's `tomUserPreferencesLimitExceededErrorKey`) | `409` | The write is sound — it succeeds for a principal holding fewer preferences, and for this one once it deletes one — so it conflicts with the state rather than being wrong |

Everything else goes to `handleErrorDefault` and stays a `500`. The narrowness
is the design: a client must be able to tell "you have no such preference" from
"the server is broken", and a client that cannot must either treat every
failure as a miss or every miss as a failure. Mapping
`preferences.not_configured` — a deployment fault — the same way would let a
client read an outage as absence and paper it over with a default. Answering
`500` for a malformed key or value makes the opposite mistake: it tells a client
its own bad request is worth retrying. The write boundary's refusals are matched
as a family, by the `preferences.encoded.` prefix every key
`TomUserPreferenceCodec.validateEncoded` raises is under, so a refusal added to
the codec is a `400` here without the handler being revisited.

Every translated status answers with the framework's error envelope, the
`x-tom-error: true` header and `Content-Type: application/json;charset=UTF-8`.
The body is not this module's: it is `tomErrorEnvelope`, the same builder
`TomServer.errorHandler` renders its `500` from, so what this handler
contributes is the *status* and nothing else. Which fields the body carries, and
why one of them is absent for a key refusal, is described in
[little_things.md](little_things.md#the-error-envelope) — the `404` and the
`409` are raised as `TomServerException`s and so report `clientThrow`, while the
`400`s arrive from the kernel as plain `TomException`s and do not.

The media type is what makes the envelope usable: the argument for the `404` is
that a client branches on `errorKey` rather than on the status, and a client
stack that decides whether to parse by media type has nothing to decide on if
the response declares none. The opaque `500` keeps `text/plain`, because it has
no envelope to parse.

**Read, write and delete all carry the handler**; the list endpoint carries none
and needs none. The key sits in the path of all three, so a `400` only the read
could produce would leave two thirds of the surface answering `500` for the same
mistake — while the list endpoint takes no key and cannot miss, since an empty
list is an answer.

**For the `404` the envelope is the meaning, not a courtesy.** The pipeline
answers a denied or unauthenticated call with a `404` as well — a bare one,
plain text with no envelope, so that a refusal cannot be told from a route that
does not exist. A never-written preference and a refused caller therefore share
a status and differ only in the body, which is why the absence key is declared
in the kernel contract (`tomUserPreferencesNotFoundErrorKey`) rather than here:
the client has to recognise it.

`TomUserPreferencesClient` (`tom_core_flutter`) is the counterpart: a `404`
whose envelope names that key is the only answer it reads as absence, so `read`
and `get` answer `null` and `getOr` answers its fallback, while every other
answer — a bare `404` included — throws. The delete never raises the key: it
answers `200` for a preference that is not there, so a `404` from it is always a
refusal, and the client reports it as one. It rarely sees the `400`
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
TomBean.withType<TomUserPreferences>(
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
  `toDto()`, and the `createTableSql` the migration reproduces. Its
  `principalId` is declared the row's data subject (`@TomDataSubject`) and its
  `valueJson` personal data (`@TomPersonal`), so a deployment that registers
  `TomUserPreferenceRepository` with `TomPrivacy` has a principal's preferences
  deleted when they are erased, included in their subject-access export and
  sealed for them in the audit trail — see
  [privacy.md](privacy.md#framework-entities-that-declare-subjects).
- **`TomUserPreferenceRepository`** — the CRUD repository, shipped rather than
  left to the deployment because the service would otherwise be unusable without
  one empty line.
- **`TomUserPreferences`** — the typed service; installed as a bean so an
  application can substitute a caching or read-only implementation without any
  consumer changing.
- **`TomUserPreferenceException`** — raised when an operation cannot identify
  the caller. It throws rather than returning `null` because there is no useful
  answer to give: with no principal there is no row to read and no owner to
  write, and an unowned row would be stored and then rejected by the scope on
  the next read.
- **`TomUserPreferencesServer`** — the `/preferences/*` implementation.
- **`TomUserPreferencesErrorHandler`** — the endpoint error handler that makes
  a miss, a bad request and a full account distinguishable:
  `preferences.not_found` becomes a `404`, `preferences.key.invalid` and every
  `preferences.encoded.*` refusal a `400`, `preferences.limit.exceeded` a `409`,
  and every other key stays an opaque `500`.
  The narrowness is the design, not an omission — mapping a deployment fault
  such as `preferences.not_configured` the same way would let a client read an
  outage as absence.

## Not Yet Implemented

- **The upsert is read-then-write, not one statement.** `set` reads the row for
  `(principal, key)` and saves it back, so two concurrent writes of the same key
  can both read nothing and both insert; the table's unique key rejects the
  loser, and the caller sees a driver error rather than a retry. Preferences are
  written by a person at a keyboard, so the race is rare — but it is not
  prevented, and a client that writes on every keystroke will find it.
  <!-- unpinned: untestable — a race between two writers is not reproducible deterministically -->
- **A rewrite may change a key's type, and every other reader then fails.**
  `setEncoded` validates that the `valueType` and `valueJson` it was handed
  agree with each other, not that they agree with what is already stored. So a
  client writing `theme` as an object where another wrote a string succeeds, and
  every `get<String>('theme')` on every other device throws
  `TomUserPreferenceCodecException` from then on. A key's type is a convention
  between the clients that share it.
  <!-- pinned: test/preferences_db_test.dart › a rewrite may change a key's type, and a typed reader then fails -->
- **There is no bulk write.** `set` takes one key, and there is no transaction
  around a group of writes, so a partial application is a reachable state. The
  delete side has both shapes — `remove` for one key and `clear` for all of
  them — because deleting everything is the operation an account reset performs
  and the one where a half-completed loop does the most damage; there is no
  equivalent single-statement write.
  <!-- unpinned: absence — no bulk write exists -->
- **There are no deployment-wide or role-wide defaults.** `getOr(key, fallback)`
  takes the default at the call site, so two call sites reading one key can
  disagree about what it means when unset, and a deployment cannot ship a
  default without editing code. The framework stores only what a principal
  actually wrote.
  <!-- unpinned: absence — no stored defaults exist -->
- **A preference is per principal and nothing else.** The row is keyed on
  `(principal_id, preference_key)`, so there is no per-device, per-application
  or per-organization dimension: a user who wants one theme on their phone and
  another on their desktop encodes that in the key.
  <!-- unpinned: decision — the row is keyed on principal and key by design -->

## Verification

Six suites, split by what each needs. Four run everywhere; two are
`@Tags(['db'])` and skip themselves when no database is reachable, so the
default `testkit :test` run stays green — bring a server up with
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL) to include them.

`test/preferences_service_test.dart` covers the service without a database: how
`TomUserPreferences.resolve` answers in a deployment that never installed a
store — a deliberate `null` rather than a throw — and what every operation does
outside a request zone. That second subject is the larger one. The service takes
no principal parameter because it reads the caller from the zone, which is what
keeps the value a handler stores and the row scope permits it to store from ever
disagreeing; with no zone there is nothing to read and nothing to own, so each
operation has to refuse, and refuse before it reaches the table. The suite is
written against the public surface, so which method performs the lookup can
move.

`test/preferences_key_test.dart` covers the server half of the key rule. The
rule itself lives in `tom_core_kernel` and is tested there; two things about it
are only answerable here. The store refuses an illegal key *first* — before the
caller is identified and before a statement is issued — because the key arrives
in the request URL and is untrusted on this side. And `maxLength` agrees with
`preference_key`'s own column width: were the DDL to widen alone, accepted keys
would be silently truncated; were the constant to grow alone, two keys differing
past the cut would collide on the unique key. Neither is visible from one file.

`test/preferences_dto_test.dart` covers `TomUserPreference.toDto()`, and exists
as its own file for a reason worth stating. The conversion normalises `updatedAt`
to UTC, and a value loaded from the column is UTC-flagged before `toDto` is
reached — so asserting `isUtc` on the round trip passes whether the
normalisation happens or not. Only an in-memory, local-flagged value can see the
call, and building one needs nothing.

`test/preferences_endpoints_test.dart` covers the HTTP surface from the outside:
which status a client gets, and what happens with nothing wired behind the
endpoints. Every failure a caller can cause gets a status of its own — a
never-written preference is a miss (`404`), an illegal key or a value the write
boundary refuses is the caller's own malformed request (`400`), and a write
beyond the principal's ceiling conflicts with its state (`409`) — while a
deployment that shipped the endpoints without installing a store is a genuine
server fault and stays an opaque `500`.

`test/preferences_db_test.dart` is the sequence [The Table and Its
Migration](#the-table-and-its-migration) describes, run against a live server. It
asserts the three things only a server can answer —
that a preference written in one session is read back in another, so the value
lives in `tom_user_preference` and not in a service instance; that one principal
cannot read another's, which is the whole reason the entity carries
`@TomDbScope(field: 'principal_id', scope: 'owner')` rather than an ownership
`if` in a handler; and that a reflected value survives the trip as an *object*,
which is what separates a typed preference from a stringly-typed blob. It also
drives [the store's ceilings](#the-store-is-bounded) against the table: a
principal filled to 256 cannot add a key but can still replace one, one short of
the ceiling can add exactly one, another principal is unaffected, and an
oversized value never reaches a row.

`test/preferences_roundtrip_db_test.dart` asserts the claim the module exists to
make, and the one no suite above can: **a preference follows the user**. That is
a statement about two clients and one server, so neither half can make it by
agreeing with itself. A real loopback server carries the shipped
`TomUserPreferencesServer` over the real pipeline and a real table, and two
independent callers — separate connections, no shared state but the server —
take the two ends: the second reads what the first wrote and never wrote itself,
and a caller signed in as somebody else does not. The callers are written in the
file rather than imported, because `TomUserPreferencesClient` lives in
`tom_core_flutter` and a server must not pull in the Flutter SDK to test itself;
that client is covered against this same contract in that package's suite. The
same suite asserts the absence convention against the served pipeline: a
signed-in caller's miss and an anonymous caller's refusal both answer `404`, and
only the miss carries the envelope naming `tomUserPreferencesNotFoundErrorKey`.
And it carries both ceilings to the wire: a write beyond the count answers `409`
naming `preferences.limit.exceeded` while a replacement still answers `200`, and
an oversized value answers `400` naming `preferences.encoded.too_large`.

```bash
dart run example/preferences/preferences_example.dart
```

`example/preferences/preferences_example.dart` is the bootstrap sequence as a
program rather than as a snippet. That matters for this module more than for
most: five things have to be in place before the store answers — reflection, a
datasource under the name the entity declares, the bean, a request zone carrying
a principal, and the table — and four of them fail at the *bootstrap* line
rather than at the call you were making, with a message that does not obviously
name the missing step. The example puts them in the order a deployment does, in
thirteen checked steps: `resolve`'s deliberate `null` before the bean is
installed, the refusals outside a zone and the key check that runs ahead of them,
a scalar and a `@tomReflector` object written and read back, a type mismatch
against `getOr`'s fallback, a second principal seeing none of the first's, the
per-caller list, `remove`'s answer, the endpoint's encoded write path, and the
migration on disk.

**The table is the one substitution**, by a map behind the repository interface,
which is what lets the program run with no database. Where that changes what can
be claimed, the example says so instead of quietly claiming it: the row scope is
enforced by the *repository*, and the contract's key ordering is an `ORDER BY`
clause, so neither is demonstrated there and neither is asserted. Both are the
subject of `preferences_db_test.dart` above.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `user_preferences_service.dart` | `Future` |
| `tom_core_kernel` | package | every file | `TomUserPreferenceKeys`, the wire DTOs, `TomUserPreferenceCodec`, `tomUserPreferencesApi`, `TomBean`, `TomPrincipal` |
| [endpoints](endpoints.md) | module | `user_preferences_endpoints.dart` | `@TomApiImplementation`, `@TomApiEndpointImplementation`, the routing pipeline (see `doc/endpoints.md`) |
| [little_things](little_things.md) | module | `user_preferences_service.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `user_preference.dart`, `user_preferences_service.dart` | `@TomDbTable`, `@TomDbColumn`, `@TomDbScope`, `TomSqlDatasourceRepository` (see `doc/object_persistence.md`) |
| [privacy](privacy.md) | module | `user_preference.dart` | `TomDataSubject` and `TomPersonal`, which declare `TomUserPreference`'s principal and its value to erasure, export and audit sealing |

- The database-migration module — the untagged framework migration (see
  `doc/db_migration.md`).
