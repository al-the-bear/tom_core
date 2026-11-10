# Tom Core Server API Reference: Preferences Module

The server-side store for per-principal preferences: the `tom_user_preference`
entity, its repository, the typed service over it, the `/preferences/*`
endpoint implementation, and the deployment and role defaults beneath every
principal's own values (`tom_preference_default`).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomUserPreference](#tomuserpreference)
  - [TomUserPreferenceRepository](#tomuserpreferencerepository)
  - [TomUserPreferences](#tomuserpreferences)
  - [TomUserPreferenceException](#tomuserpreferenceexception)
  - [TomPreferenceDefaultScope](#tompreferencedefaultscope)
  - [TomPreferenceDefault](#tompreferencedefault)
  - [TomPreferenceDefaultRepository](#tompreferencedefaultrepository)
  - [TomPreferenceDefaults](#tompreferencedefaults)
  - [TomUserPreferencesServer](#tomuserpreferencesserver)
  - [TomUserPreferencesErrorHandler](#tomuserpreferenceserrorhandler)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/preferences/user_preference.dart`,
`lib/src/tomserver/preferences/user_preferences_service.dart`,
`lib/src/tomserver/preferences/user_preferences_endpoints.dart`,
`lib/src/tomserver/preferences/preference_default.dart`,
`lib/src/tomserver/preferences/preference_defaults.dart`.

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

Under a key a principal has not written, the store answers a default: a role
default of a role the principal holds (highest `precedence`, then role name in
code-unit order), else the deployment's. `TomPreferenceDefaults` writes them —
an administrative service with no endpoint — and chooses the one a principal
reads; the DTO's `origin` says which applied.

## Class Hierarchy

```text
TomUserPreference                                   (@tomReflector, @TomDbTable, @TomDbScope)

TomSqlDatasourceRepository<TomUserPreference, int>
└── TomUserPreferenceRepository

TomUserPreferences                                  (bean-installed service)

TomPreferenceDefaultScope                           (enum)
TomPreferenceDefault                                (@tomReflector, @TomDbTable)

TomSqlDatasourceRepository<TomPreferenceDefault, int>
└── TomPreferenceDefaultRepository

TomPreferenceDefaults                               (bean-installed service)

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

- **Annotations:** `@tomReflector`; `@TomTenantTable()`;
  `@TomDbTable(datasource: 'main', table: 'tom_user_preference', primaryKeyFields: ['id'])`;
  `@TomDbScope(field: 'principal_id', scope: 'owner')`.

#### Constructors

```dart
TomUserPreference({
  int id = -1,
  String tenantId = '',
  String principalId = '',
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
| `tenantId` | `String` | `tenant_id` | The row's tenant (`@TomTenantTable`): filled by the repository from the tenant in context and bound into every statement; `DEFAULT 'default'` leads the unique key. |
| `principalId` | `String` | `principal_id` | The owning principal's `TomPrincipal.qualifiedId` — its id qualified by its tenant — the scope column, because that is what the built-in `owner` resolver yields. `@TomDataSubject()`: the row's data subject, so erasing the principal deletes the row. |
| `preferenceKey` | `String` | `preference_key` | The preference key. |
| `valueType` | `String` | `value_type` | The name of the type `valueJson` was written as. |
| `valueJson` | `String` | `value_json` | The value's JSON text. `@TomPersonal()`: personal data of the principal, sealed for them in the audit trail. |
| `updatedAt` | `DateTime?` | `updated_at` | When the preference was last written (UTC). |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toDto()` | `TomUserPreferenceDto` | The row as the wire DTO, with `updatedAt` normalised to UTC — MariaDB's `DATETIME` (PostgreSQL's `TIMESTAMP`) carries no zone, so a read-back instant arrives flagged local, which is the wrong convention at the server's edge. |

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `String` | The DDL this entity expects, reproduced verbatim by the framework migration so the two cannot drift — `test/reference_migrations_test.dart` fails if they do. `(tenant_id, principal_id, preference_key)` is unique, because the pair is the preference's identity within its tenant; `updated_at` is `DATETIME(6)`, the width the instant convention writes. |

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
const TomUserPreferences(
  TomSqlDatasourceRepository<TomUserPreference, int> repository, {
  TomPreferenceDefaults? defaults,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomUserPreference, int>` | The repository preference rows are read and written through. |
| `defaults` | `TomPreferenceDefaults?` | The defaults beneath the caller's own values; when `null`, the installed `TomPreferenceDefaults` bean, and when there is none either, no defaults. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve()` | `TomUserPreferences?` | The installed bean, or `null` when none is registered — `null` rather than a throw, because a preference is optional by nature: a deployment without the table should fall back, not fail. |

#### Methods

All of the following read the caller from the request zone, except `getFor`.

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `all` | `Future<List<TomUserPreferenceDto>> all([TomPageRequest? page])` | Every preference of the caller and, under every key it has not written, the default `TomPreferenceDefaults` chooses for its roles (`origin` naming the source) — ordered by key (unmodifiable), the caller's own values bounded by the two ceilings below. `page` windows the merged list in memory (`offset` and `limit`; `sort` is not applied) and is for a server-internal caller — a migration or a batch job; the wire has no equivalent and deliberately, since the set cannot exceed the count ceiling. |
| `read(String key)` | `Future<TomUserPreferenceDto?>` | The caller's preference under `key`; when it has never written one, the default `TomPreferenceDefaults` chooses for its roles; `null` when there is neither. |
| `get<T extends Object>(String key)` | `Future<T?>` | `read`, decoded as a `T` — a default included. Throws `TomUserPreferenceCodecException` when the preference exists but was written as a different type. |
| `getOr<T extends Object>(String key, T fallback)` | `Future<T>` | `get`, with `fallback` for a preference that has never been written and has no default. A type mismatch still throws. |
| `set<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Encodes `value` and upserts it, returning the stored DTO. Scalars and `DateTime`s go through the codec; anything else must be a `@tomReflector` class. |
| `setEncoded(String key, {required String valueType, required String valueJson})` | `Future<TomUserPreferenceDto>` | `set` for a value that arrives already encoded — the endpoint's write path. The pair is validated before it is stored. |
| `setAllEncoded(Iterable<TomUserPreferenceWriteRequest> writes)` | `Future<List<TomUserPreferenceDto>>` | `writes` — each validated here — as the caller's preferences, **all or none**, answered ordered by key; the bulk endpoint's write path. Every key and encoded pair is checked before anything is written; the ceiling counts the batch whole (the keys it would add, beside the ones held, must fit, or nothing is written); the writes run in one transaction (`TomTransactionManager.runInTransaction`) in key order. The held keys are read before the transaction, so two batches over the same keys queue on the row locks rather than failing; two batches racing for the last places can both pass the ceiling. An empty batch writes nothing. |
| `remove(String key)` | `Future<bool>` | Deletes the caller's preference under `key`; answers whether a row was removed, so a caller can tell "deleted" from "was never there" without a second read. |
| `clear()` | `Future<int>` | Deletes **every** preference of the caller and answers how many rows went. One `DELETE` rather than a loop over `all` and `remove`, because a loop that stops half way leaves a state nobody chose on a store every device the user owns reads. Idempotent and unconditional; names the principal in the predicate for the reason every lookup here does — under `TomDataScope.runUnscoped` the scope filters nothing, and a bulk delete that relied on it would be everyone's. |
| `getFor<T extends Object>(TomPrincipal principal, String key)` | `Future<T?>` | `get` for a principal that is not the zone's. Exists for the authentication path, which needs a preference before a request zone carries a principal; it installs one and delegates, so even login reaches the same scoped query. |

**Every write is bounded.** A write that would **add** a key is refused with
`TomUserPreferenceException('preferences.limit.exceeded')` once the caller holds
`tomUserPreferencesMaxPerPrincipal` (256) preferences — for `setAllEncoded`, once
the keys the batch adds would pass it; replacing a held key is never refused for
the count, and `remove` frees a place. The count is taken with the principal
named, so it means "mine" under `TomDataScope.runUnscoped` too, and before the
write, so two racing writes can overshoot by one or two. A value over
`TomUserPreferenceCodec.maxValueBytes` (16 KiB) is refused by the codec —
`preferences.encode.too_large` from `set`, `preferences.encoded.too_large` from
`setEncoded` and `setAllEncoded` — before a statement is built, well inside
`value_json`'s 64 KiB `TEXT`.

**Every write is one statement.** The row is written through
`repository.saveByKey(conflictFields: ['tenantId', 'principalId', 'preferenceKey'])` — for
this entity an upsert on `uq_tom_user_preference` with no read before it, so two
writers racing for a new key cannot both insert.

`set` and `setEncoded` are `async` for the encoding step, which can throw: every
other failure of this service arrives as a rejected future, and one method that
threw synchronously instead would be caught by a `try` the caller wrote around
the `await` and missed by everything else.

`all()`'s order is a contract. The caller's rows are read `order by
preference_key`, which `uq_tom_user_preference (tenant_id, principal_id,
preference_key)` serves off the index, and the list merged with the defaults is ordered by key in
code-unit order. Ordering by key rather than by insertion or by `updated_at`
means rewriting a value does not move the preference in the list, and two
devices of one user see the same sequence.

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

### TomPreferenceDefaultScope

Whom a `TomPreferenceDefault` applies to.

- **Kind:** enum.

#### Values

| Value | Description |
| ----- | ----------- |
| `deployment` | Every principal of the deployment. |
| `role` | The principals holding one role (`TomPreferenceDefault.scopeName`). |

### TomPreferenceDefault

One default preference — a row of `tom_preference_default`. A default belongs
to the whole deployment or to the holders of one role; a principal's own value
always wins over both, and a role's over the deployment's. Unlike
`TomUserPreference` the entity declares no row scope: a default is nobody's own
row.

- **Annotations:** `@tomReflector`; `@TomTenantTable()`;
  `@TomDbTable(datasource: 'main', table: 'tom_preference_default', primaryKeyFields: ['id'])`.

#### Constructors

```dart
TomPreferenceDefault({
  int id = -1,
  String tenantId = '',
  String scopeKind = '',
  String scopeName = '',
  String preferenceKey = '',
  String valueType = '',
  String valueJson = '',
  int precedence = 0,
  DateTime? updatedAt,
})
```

Every field defaults, because the repository instantiates a blank entity and
fills it column by column when mapping a result.

#### Properties

| Property | Type | Column | Description |
| -------- | ---- | ------ | ----------- |
| `id` | `int` | `id` (read-only) | Surrogate primary key; `-1` until persisted. |
| `tenantId` | `String` | `tenant_id` | The row's tenant (`@TomTenantTable`): filled by the repository from the tenant in context and bound into every statement; `DEFAULT 'default'` leads the unique key. |
| `scopeKind` | `String` | `scope_kind` | The `TomPreferenceDefaultScope` name: `deployment` or `role`. |
| `scopeName` | `String` | `scope_name` | The role a role default applies to; `''` for a deployment default. |
| `preferenceKey` | `String` | `preference_key` | The preference key. |
| `valueType` | `String` | `value_type` | The name of the type `valueJson` was written as. |
| `valueJson` | `String` | `value_json` | The value's JSON text. |
| `precedence` | `int` | `precedence` | Which role default wins when a principal holds several roles defaulting one key: the highest precedence, then the role name in code-unit order. `0` for a deployment default. |
| `updatedAt` | `DateTime?` | `updated_at` | When the default was last written (UTC). |
| `scope` | `TomPreferenceDefaultScope` | — | *(getter)* The scope this default applies to. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toDto()` | `TomUserPreferenceDto` | The default as the wire DTO a principal reads it as, `updatedAt` in UTC, its `origin` `role` or `deployment`. |

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `String` | The DDL this entity expects, reproduced verbatim by the framework migration `[2]-create_tom_preference_default.sql` — `test/reference_migrations_test.dart` fails if they drift. `(tenant_id, scope_kind, scope_name, preference_key)` is unique: the default's identity within its tenant, and the conflict key a write replaces it on. The name, key and type columns are `utf8mb4_bin`. |

### TomPreferenceDefaultRepository

The CRUD repository for `TomPreferenceDefault`.

- **Extends:** `TomSqlDatasourceRepository<TomPreferenceDefault, int>`.

### TomPreferenceDefaults

Reads and writes `TomPreferenceDefault`s, and chooses the default a principal
reads. Installed as a bean so `TomUserPreferences` can find it. An
administrative service: no endpoint ships for it, because which roles get which
defaults is a deployment's policy.

For a key, a principal reads its own value; else a default of a role it holds —
the highest `precedence`, then the role name first in code-unit order, so the
answer never depends on the order roles are listed in; else the deployment's
default; else nothing. A default is never copied into the principal's rows.

#### Constructors

```dart
const TomPreferenceDefaults(
  TomSqlDatasourceRepository<TomPreferenceDefault, int> repository,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomPreferenceDefault, int>` | The repository default rows are read and written through. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve()` | `TomPreferenceDefaults?` | The installed bean, or `null` when none is registered — in which case no principal reads a default. |

#### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `maxRoleLength` | `int` | `191` | The longest role name a role default can name — `scope_name`'s width. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `setForDeployment<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Sets the deployment's default under `key`. The value is encoded by `TomUserPreferenceCodec` and the key checked against the key rule; the row is stored by `saveByKey` on `(scopeKind, scopeName, preferenceKey)`, so writing one twice replaces it. |
| `setForRole<T extends Object>(String role, String key, T value, {int precedence = 0})` | `Future<TomUserPreferenceDto>` | Sets the default under `key` for the holders of `role`; `precedence` decides between the defaults of several roles a principal holds. Refuses an empty role or one longer than `maxRoleLength` with `TomUserPreferenceException('preferences.default.invalid_role')`. |
| `removeForDeployment(String key)` | `Future<bool>` | Removes the deployment's default under `key`; answers whether one was there. |
| `removeForRole(String role, String key)` | `Future<bool>` | Removes `role`'s default under `key`; answers whether one was there. The role is checked as `setForRole` checks it. |
| `all()` | `Future<List<TomPreferenceDefault>>` | Every default — deployment defaults first, then by role and key. |
| `effectiveFor(Iterable<String> roles)` | `Future<Map<String, TomUserPreferenceDto>>` | The default a holder of `roles` reads under each key that has one, keyed by preference key. |
| `effectiveValue(String key, Iterable<String> roles)` | `Future<TomUserPreferenceDto?>` | The default a holder of `roles` reads under `key`, or `null`. |

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
| `listPreferences()` | `listPreferences` — `GET /preferences` | Every preference of the caller, and the defaults beneath them. |
| `readPreference(TomUserPreferenceKeyRequest request)` | `readPreference` — `GET /preferences/{key}` | One preference, else the default beneath it; throws a `TomEndpointHandlerException` keyed by the kernel's `tomUserPreferencesNotFoundErrorKey` (`preferences.not_found`) when there is neither, and is served under `TomUserPreferencesErrorHandler` so that miss reaches the client as a `404` carrying the error envelope — which is what separates it from the pipeline's bare `404` for a denied call. Reporting a miss distinctly is safe because the scope makes "not yours" indistinguishable from "not there". |
| `writePreference(TomUserPreferenceWriteRequest request)` | `writePreference` — `PUT /preferences` | Validates the encoded pair, then upserts under `request.key`. The URI carries no `{key}`: the request already has one, and a second statement of the key would be one the body could contradict. |
| `writePreferences(TomUserPreferenceBulkWriteRequest request)` | `writePreferences` — `POST /preferences` | Writes every entry of the request through the store's `setAllEncoded`, all or none, and answers them ordered by key. `request.writes` refuses a malformed entry (`preferences.bulk.malformed`) before the store sees any; served under `TomUserPreferencesErrorHandler`, so that refusal is a `400`, and a batch past the ceiling a `409`. |
| `deletePreference(TomUserPreferenceKeyRequest request)` | `deletePreference` — `DELETE /preferences/{key}` | Deletes one; the absent case is not an error and answers `200`, so a `404` from this endpoint is always a refusal. |
| `clearPreferences()` | `clearPreferences` — `DELETE /preferences` | Deletes every preference of the caller, through the store's single-statement `clear()`. Takes nothing from the caller, so it declares no error handler of its own: there is no malformed input for a `400` and it cannot miss, which leaves the framework default for the faults that remain. |

All six resolve the store per call and throw
`TomEndpointHandlerException('preferences.not_configured')` when no
`TomUserPreferences` bean is installed. Resolving per call rather than holding it
means a deployment that installs its own bean after the pipeline constructed the
handler is obeyed.

### TomUserPreferencesErrorHandler

The error handler the read, both write and the delete endpoints are served
under. It maps `preferences.not_found` (the kernel's
`tomUserPreferencesNotFoundErrorKey`) to a `404`; `preferences.key.invalid`,
every key under `preferences.encoded.` — the write boundary's refusals — and
`preferences.bulk.malformed` (`tomUserPreferencesBulkMalformedErrorKey`) to a
`400`; and `preferences.limit.exceeded`
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
| `statusByErrorKey` | `Map<String, int>` | *(getter, override)* `tomUserPreferencesNotFoundErrorKey` → `404`, `invalidKeyKey` → `400`, `tomUserPreferencesBulkMalformedErrorKey` → `400`, `tomUserPreferencesLimitExceededErrorKey` → `409`. The miss is keyed by the *contract's* key rather than one of this module's own, because the client has to recognise it: a `404` is absence only when it carries that key. |

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
`tom_core_kernel/doc/api/api_summary_preferences.md`).

The framework migrations `migrations/tenant/default/main/[1]-create_tom_user_preference.sql`
and `[2]-create_tom_preference_default.sql` reproduce
`TomUserPreference.createTableSql` and `TomPreferenceDefault.createTableSql`
verbatim — pinned by `test/reference_migrations_test.dart` — and are untagged so
they apply in every environment.
