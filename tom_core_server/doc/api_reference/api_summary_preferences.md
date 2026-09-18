# Tom Core Server API Reference: Preferences Module

The server-side store for per-principal preferences: the `tom_user_preference`
entity, its repository, the typed service over it, and the `/preferences/*`
endpoint implementation.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomUserPreference](#tomuserpreference)
  - [TomUserPreferenceRepository](#tomuserpreferencerepository)
  - [TomUserPreferences](#tomuserpreferences)
  - [TomUserPreferenceException](#tomuserpreferenceexception)
  - [TomUserPreferencesServer](#tomuserpreferencesserver)
  - [TomUserPreferencesErrorHandler](#tomuserpreferenceserrorhandler)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/preferences/user_preference.dart`,
`lib/src/tomserver/preferences/user_preferences_service.dart`,
`lib/src/tomserver/preferences/user_preferences_endpoints.dart`.

The contract — keys, wire DTOs, value codec and the `TomApi` declaration — lives
in `tom_core_kernel`'s `preferences` module; this module is the store behind it.
A preference row is mapped through the ordinary object-persistence annotations,
and its class-level `@TomDbScope(field: 'principal_id', scope: 'owner')` is the
whole "a principal reads and writes only their own" rule: the repository ANDs the
caller's id into every read and rejects every out-of-scope write, so no handler
restates it and no URI carries a principal.

`TomUserPreferences` is installed as a bean and reads its caller from the request
zone rather than from a parameter, so the value a handler stores and the row the
repository permits it to store cannot disagree.

## Class Hierarchy

```text
TomUserPreference                                   (@tomReflector, @TomDbTable, @TomDbScope)

TomSqlDatasourceRepository<TomUserPreference, int>
└── TomUserPreferenceRepository

TomUserPreferences                                  (bean-installed service)

TomServerException
└── TomUserPreferenceException

TomUserPreferencesApiService                        (kernel contract)
└── TomUserPreferencesServer                        (@tomReflector, @tomComponent, @TomApiImplementation)

TomErrorHandler
└── TomUserPreferencesErrorHandler                  (const; annotation argument)
```

## Classes

### TomUserPreference

One preference of one principal — a row of `tom_user_preference`.

- **Annotations:** `@tomReflector`;
  `@TomDbTable(datasource: 'main', table: 'tom_user_preference', primaryKeyField: 'id')`;
  `@TomDbScope(field: 'principal_id', scope: 'owner')`.

#### Constructors

```dart
TomUserPreference({
  int id = -1,
  int principalId = -1,
  String preferenceKey = '',
  String valueType = '',
  String valueJson = '',
  DateTime? updatedAt,
})
```

Every field defaults, because the repository instantiates a blank entity and
fills it column by column when mapping a result.

#### Properties

| Property | Type | Column | Description |
| -------- | ---- | ------ | ----------- |
| `id` | `int` | `id` (read-only) | Surrogate primary key; `-1` until persisted. |
| `principalId` | `int` | `principal_id` | The owning `TomPrincipal.id` — the scope column. An `int`, because the built-in `owner` resolver yields an `int`. |
| `preferenceKey` | `String` | `preference_key` | The preference key. |
| `valueType` | `String` | `value_type` | The name of the type `valueJson` was written as. |
| `valueJson` | `String` | `value_json` | The value's JSON text. |
| `updatedAt` | `DateTime?` | `updated_at` | When the preference was last written (UTC). |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toDto()` | `TomUserPreferenceDto` | The row as the wire DTO, with `updatedAt` normalised to UTC — MariaDB's `DATETIME` carries no zone, so a read-back instant arrives flagged local, which is the wrong convention at the server's edge. |

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `String` | The DDL this entity expects, reproduced verbatim by the framework migration so the two cannot drift — `test/reference_migrations_test.dart` fails if they do. `(principal_id, preference_key)` is unique, because that pair is the preference's identity; `updated_at` is `DATETIME(6)`, the width the instant convention writes. |

### TomUserPreferenceRepository

The CRUD repository for `TomUserPreference`. Shipped rather than left to the
deployment (as the authorization tables are) because `TomUserPreferences` is
itself shipped and would otherwise be unusable without the caller writing this
one empty line.

- **Extends:** `TomSqlDatasourceRepository<TomUserPreference, int>`.

### TomUserPreferences

Typed access to the calling principal's server-stored preferences. Installed as
a bean so an application can substitute its own implementation — a caching one, a
read-only one — without any consumer changing.

#### Constructors

```dart
const TomUserPreferences(TomSqlDatasourceRepository<TomUserPreference, int> repository)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomUserPreference, int>` | The repository preference rows are read and written through. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve()` | `TomUserPreferences?` | The installed bean, or `null` when none is registered — `null` rather than a throw, because a preference is optional by nature: a deployment without the table should fall back, not fail. |

#### Methods

All of the following read the caller from the request zone, except `getFor`.

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `all` | `Future<List<TomUserPreferenceDto>> all([TomPageRequest? page])` | Every preference of the caller, ordered by key (unmodifiable), and bounded by the two ceilings below. `page` windows the answer and is for a server-internal caller — a migration or a batch job; the wire has no equivalent and deliberately, since the set cannot exceed the count ceiling. |
| `read(String key)` | `Future<TomUserPreferenceDto?>` | The caller's preference under `key`, or `null` when never written. |
| `get<T extends Object>(String key)` | `Future<T?>` | `read`, decoded as a `T`. Throws `TomUserPreferenceCodecException` when the preference exists but was written as a different type. |
| `getOr<T extends Object>(String key, T fallback)` | `Future<T>` | `get`, with `fallback` for a preference that has never been written. A type mismatch still throws. |
| `set<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Encodes `value` and upserts it, returning the stored DTO. Scalars and `DateTime`s go through the codec; anything else must be a `@tomReflector` class. |
| `setEncoded(String key, {required String valueType, required String valueJson})` | `Future<TomUserPreferenceDto>` | `set` for a value that arrives already encoded — the endpoint's write path. The pair is validated before it is stored. |

**Both writes are bounded.** A write that would **add** a key is refused with
`TomUserPreferenceException('preferences.limit.exceeded')` once the caller holds
`tomUserPreferencesMaxPerPrincipal` (256) preferences; replacing a held key is
never refused for the count, and `remove` frees a place. The count is taken with
the principal named, so it means "mine" under `TomDataScope.runUnscoped` too, and
before the insert, so two racing inserts can overshoot by one or two. A value
over `TomUserPreferenceCodec.maxValueBytes` (16 KiB) is refused by the codec —
`preferences.encode.too_large` from `set`, `preferences.encoded.too_large` from
`setEncoded` — before a statement is built, well inside `value_json`'s 64 KiB
`TEXT`.
| `remove(String key)` | `Future<bool>` | Deletes the caller's preference under `key`; answers whether a row was removed, so a caller can tell "deleted" from "was never there" without a second read. |
| `clear()` | `Future<int>` | Deletes **every** preference of the caller and answers how many rows went. One `DELETE` rather than a loop over `all` and `remove`, because a loop that stops half way leaves a state nobody chose on a store every device the user owns reads. Idempotent and unconditional; names the principal in the predicate for the reason every lookup here does — under `TomDataScope.runUnscoped` the scope filters nothing, and a bulk delete that relied on it would be everyone's. |
| `getFor<T extends Object>(TomPrincipal principal, String key)` | `Future<T?>` | `get` for a principal that is not the zone's. Exists for the authentication path, which needs a preference before a request zone carries a principal; it installs one and delegates, so even login reaches the same scoped query. |

`set` and `setEncoded` are `async` for the encoding step, which can throw: every
other failure of this service arrives as a rejected future, and one method that
threw synchronously instead would be caught by a `try` the caller wrote around
the `await` and missed by everything else.

`all()`'s order is a contract, carried by the query's own `order by
preference_key`. Ordering by key rather than by insertion or by `updated_at`
means rewriting a value does not move the preference in the list, and two
devices of one user see the same sequence. `uq_tom_user_preference
(principal_id, preference_key)` already covers the ordered scan, so the
guarantee costs no sort.

### TomUserPreferenceException

Raised when a preference operation cannot identify the caller —
`preferences.no_principal` — or when a write would add a preference beyond the
kernel's `tomUserPreferencesMaxPerPrincipal` — `preferences.limit.exceeded`
(`tomUserPreferencesLimitExceededErrorKey`), carrying `key` and `limit`
parameters.

- **Extends:** `TomServerException`.

#### Constructors

```dart
TomUserPreferenceException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
  bool clientThrow,
})
```

Parameters mirror `TomServerException`; every one of them is a `super.`
forward, so this class adds no state of its own.

`stack` is `StackTrace?` and not `Object?`. The distinction is easy to get
backwards, because the *field* the value ends up in is `Object?` — declared
that way on `TomBaseException`, two classes further up. `TomException`
narrows it on the way in, and since every constructor between here and there
forwards with `super.stack`, that narrowing is what this parameter's type is.
Reading the field's declaration instead of the constructor's is what makes it
look wider than it is; a caller has nothing to widen to, and needs no cast for
the `s` of a `catch (e, s)`, which is already a `StackTrace`.

Leaving `stack` out never leaves the exception without a trace. `TomException`
substitutes `StackTrace.current` for a missing *or* explicitly null argument,
and it does so in its own constructor so that the captured trace still reaches
the `throw` site — late capture would report whatever formatted the exception
instead. Passing a trace is therefore only worth it when the failure happened
somewhere other than the `throw`, which is exactly the `catch (e, s)` case.

### TomUserPreferencesServer

The default `TomUserPreferencesApiService` implementation — the HTTP face of the
store. Holds no state of its own (the store is the bean, the caller is the
request zone), so the pipeline may construct it itself.

- **Annotations:** `@tomReflector`; `@tomComponent`;
  `@TomApiImplementation(apiId: tomUserPreferencesApiId)`.
- **Implements:** `TomUserPreferencesApiService` (kernel).

#### Constructors

```dart
const TomUserPreferencesServer()
```

#### Methods

Each is annotated `@TomApiEndpointImplementation(apiId: …, endpointId: …)`. None
carries an inline access annotation: the contract declares
`TomAuthenticatedAccess`, and the row scope decides which rows are reachable.

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| `listPreferences()` | `listPreferences` — `GET /preferences` | Every preference of the caller. |
| `readPreference(TomUserPreferenceKeyRequest request)` | `readPreference` — `GET /preferences/{key}` | One preference; throws a `TomEndpointHandlerException` keyed by the kernel's `tomUserPreferencesNotFoundErrorKey` (`preferences.not_found`) when absent, and is served under `TomUserPreferencesErrorHandler` so that miss reaches the client as a `404` carrying the error envelope — which is what separates it from the pipeline's bare `404` for a denied call. Reporting a miss distinctly is safe because the scope makes "not yours" indistinguishable from "not there". |
| `writePreference(TomUserPreferenceWriteRequest request)` | `writePreference` — `PUT /preferences` | Validates the encoded pair, then upserts under `request.key`. The URI carries no `{key}`: the request already has one, and a second statement of the key would be one the body could contradict. |
| `deletePreference(TomUserPreferenceKeyRequest request)` | `deletePreference` — `DELETE /preferences/{key}` | Deletes one; the absent case is not an error and answers `200`, so a `404` from this endpoint is always a refusal. |
| `clearPreferences()` | `clearPreferences` — `DELETE /preferences` | Deletes every preference of the caller, through the store's single-statement `clear()`. Takes nothing from the caller, so it declares no error handler of its own: there is no malformed input for a `400` and it cannot miss, which leaves the framework default for the faults that remain. |

All five resolve the store per call and throw
`TomEndpointHandlerException('preferences.not_configured')` when no
`TomUserPreferences` bean is installed. Resolving per call rather than holding it
means a deployment that installs its own bean after the pipeline constructed the
handler is obeyed.

### TomUserPreferencesErrorHandler

The error handler the read, write and delete endpoints are served under. It
maps `preferences.not_found` (the kernel's `tomUserPreferencesNotFoundErrorKey`)
to a `404`; `preferences.key.invalid` and every key under `preferences.encoded.`
— the write boundary's refusals — to a `400`; and `preferences.limit.exceeded`
(`tomUserPreferencesLimitExceededErrorKey`) to a `409` — and *only* those —
leaving every other failure a `500`.

Only the *status* is this module's contribution: the body is the framework
envelope, rendered by the base class, so a client sees one shape whichever
endpoint answered.

- **Extends:** `TomStatusMappingErrorHandler`.

#### Constructors

```dart
const TomUserPreferencesErrorHandler()
```

`const` so it can be written as an annotation argument:

```dart
@TomApiEndpointImplementation(
  apiId: tomUserPreferencesApiId,
  endpointId: tomUserPreferencesReadEndpointId,
  errorHandler: TomUserPreferencesErrorHandler(),
)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `invalidKeyKey` | `String` | `'preferences.key.invalid'` — the key raised for a preference key that violates `TomUserPreferenceKeys`; becomes a `400`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `statusFor` | `int statusFor(Object error)` | *(override)* `400` for every key under `preferences.encoded.` — a prefix rather than four entries, so a fifth refusal of the write boundary does not silently become a `500` — and otherwise the base class's lookup in `statusByErrorKey`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusByErrorKey` | `Map<String, int>` | *(getter, override)* `tomUserPreferencesNotFoundErrorKey` → `404`, `invalidKeyKey` → `400`, `tomUserPreferencesLimitExceededErrorKey` → `409`. The miss is keyed by the *contract's* key rather than one of this module's own, because the client has to recognise it: a `404` is absence only when it carries that key. |

Why only those keys: a client must be able to tell **"you have no such
preference"** from **"the server is broken"**, and a client that cannot must
either treat every failure as a miss or every miss as a failure. A rejected key
or value is the *caller's* own mistake — the key arrives in the request URL and
the value in its body, so on this side both are untrusted input, and a `500`
would tell the client its malformed request was a server fault worth retrying.
The write boundary's refusals are matched by prefix, so one added to
`TomUserPreferenceCodec.validateEncoded` is a `400` without this handler
changing. The ceiling is a `409` because the request is sound: it would
succeed for a principal holding fewer preferences. Everything else stays opaque: mapping
`preferences.not_configured` — a deployment fault — to a `404` would let a
client read it as absence and paper the outage over with a default.

Every translated body is `tomErrorEnvelope(error)` — the package's single
definition of the wire error shape, rendered by
[`little_things`](api_summary_little_things.md#tomerrorenvelope) and not by this
handler — under the `x-tom-error: true` header and
`Content-Type: application/json;charset=UTF-8`. So a client branches on the key
rather than on message text, is told there is a body to decode before it decides
whether to decode one, and sees the same shape here as it does from
`TomServer.errorHandler`. What this handler contributes is the status.

For the `404` the envelope is not a courtesy but the meaning. The endpoint
pipeline answers a denied or unauthenticated call with a bare `404` and no
envelope, so that a refusal cannot be told from a route that does not exist; a
preference that was never written shares that status and differs only in its
body. A client therefore reads absence from `errorKey ==
tomUserPreferencesNotFoundErrorKey` and treats any other `404` as a refusal —
`TomUserPreferencesClient` in `tom_core_flutter` does exactly that.

They do not all carry identical *fields*, and that is the envelope working as
intended: the `404` and the `409` are raised as `TomServerException`s — a
`TomEndpointHandlerException` and a `TomUserPreferenceException` — and therefore
report `clientThrow`, while the `400`s arrive from the kernel as plain
`TomException`s and omit it. The opaque `500` from `handleErrorDefault` keeps
`text/plain`, because it carries no envelope at all.

## Global Functions and Constants

None — this module exposes no top-level functions or constants. The API id and
endpoint id constants it binds to are the kernel's (see
`tom_core_kernel/doc/api_reference/api_summary_preferences.md`).

The framework migration `migrations/main/tomcore/[1]-create_tom_user_preference.sql`
reproduces `TomUserPreference.createTableSql` verbatim — pinned by
`test/reference_migrations_test.dart` — and is untagged so it applies in every
environment.
