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
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference of the caller, in storage order (unmodifiable). |
| `read(String key)` | `Future<TomUserPreferenceDto?>` | The caller's preference under `key`, or `null` when never written. |
| `get<T extends Object>(String key)` | `Future<T?>` | `read`, decoded as a `T`. Throws `TomUserPreferenceCodecException` when the preference exists but was written as a different type. |
| `getOr<T extends Object>(String key, T fallback)` | `Future<T>` | `get`, with `fallback` for a preference that has never been written. A type mismatch still throws. |
| `set<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Encodes `value` and upserts it, returning the stored DTO. Scalars and `DateTime`s go through the codec; anything else must be a `@tomReflector` class. |
| `setEncoded(String key, {required String valueType, required String valueJson})` | `Future<TomUserPreferenceDto>` | `set` for a value that arrives already encoded — the endpoint's write path. The pair is validated before it is stored. |
| `remove(String key)` | `Future<bool>` | Deletes the caller's preference under `key`; answers whether a row was removed, so a caller can tell "deleted" from "was never there" without a second read. |
| `getFor<T extends Object>(TomPrincipal principal, String key)` | `Future<T?>` | `get` for a principal that is not the zone's. Exists for the authentication path, which needs a preference before a request zone carries a principal; it installs one and delegates, so even login reaches the same scoped query. |

`set` and `setEncoded` are `async` for the encoding step, which can throw: every
other failure of this service arrives as a rejected future, and one method that
threw synchronously instead would be caught by a `try` the caller wrote around
the `await` and missed by everything else.

### TomUserPreferenceException

Raised when a preference operation cannot identify the caller —
`preferences.no_principal`.

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

Parameters mirror `TomServerException`.

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
| `readPreference(TomUserPreferenceKeyRequest request)` | `readPreference` — `GET /preferences/{key}` | One preference; throws `TomEndpointHandlerException('preferences.not_found')` when absent, and is served under `TomUserPreferencesErrorHandler` so that miss reaches the client as a `404`. Reporting a miss distinctly is safe because the scope makes "not yours" indistinguishable from "not there". |
| `writePreference(TomUserPreferenceWriteRequest request)` | `writePreference` — `PUT /preferences` | Validates the encoded pair, then upserts under `request.key`. The URI carries no `{key}`: the request already has one, and a second statement of the key would be one the body could contradict. |
| `deletePreference(TomUserPreferenceKeyRequest request)` | `deletePreference` — `DELETE /preferences/{key}` | Deletes; the absent case is not an error. |

All four resolve the store per call and throw
`TomEndpointHandlerException('preferences.not_configured')` when no
`TomUserPreferences` bean is installed. Resolving per call rather than holding it
means a deployment that installs its own bean after the pipeline constructed the
handler is obeyed.

### TomUserPreferencesErrorHandler

The error handler the read endpoint is served under: it maps
`preferences.not_found` — and *only* that key — to a `404`, and leaves every
other failure to `handleErrorDefault`.

- **Extends:** `TomErrorHandler`.

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
| `notFoundKey` | `String` | `'preferences.not_found'` — the one key that becomes a `404`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `handleInvocationError` | `Response handleInvocationError(Object error, Object stacktrace, Request r)` | Answers `404` when `error` is a `TomException` whose `key` is `notFoundKey`, carrying the framework's error envelope and the `x-tom-error` header so a client branches on `errorKey` rather than on a status alone. Everything else falls through to `handleErrorDefault`. |
| `handleErrorDefault` | `Response handleErrorDefault(Object error, Object stacktrace, Request r, Object? result)` | Delegates to `TomDefaultErrorHandler`, so every failure that is not the one mapped miss is answered exactly as it would have been without this handler. |

Why only that key: a client must be able to tell **"you have no such
preference"** from **"the server is broken"**, and a client that cannot must
either treat every failure as a miss or every miss as a failure. Mapping
`preferences.not_configured` — a deployment fault — to a `404` would let a client
read it as absence and paper the outage over with a default. So the mapping is
one key wide, deliberately.

The `404` body carries the usual error envelope (`errorType`, `errorKey`, `uuid`,
`autoLog`, `requestUuid`) and the `x-tom-error: true` header, so a client
branches on the key rather than on message text.

## Global Functions and Constants

None — this module exposes no top-level functions or constants. The API id and
endpoint id constants it binds to are the kernel's (see
`tom_core_kernel/doc/api_reference/api_summary_preferences.md`).

The framework migration `migrations/main/tomcore/[1]-create_tom_user_preference.sql`
reproduces `TomUserPreference.createTableSql` verbatim — pinned by
`test/reference_migrations_test.dart` — and is untagged so it applies in every
environment.
