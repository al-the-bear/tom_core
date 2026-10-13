# Tom Core Server API Reference: Rate Limiting Module

Request rate limiting: rules counting requests per signed-in user, per API key
or per client address over a sliding window, counted in this process or in a
table every node shares, and answered with `429 Too Many Requests` and
`Retry-After`.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomRateLimitException](#tomratelimitexception)
  - [TomRateLimitRule](#tomratelimitrule)
  - [TomRateLimitDecision](#tomratelimitdecision)
  - [TomRateLimiter](#tomratelimiter)
  - [TomMemoryRateLimiter](#tommemoryratelimiter)
  - [TomClientAddress](#tomclientaddress)
  - [TomRateLimits](#tomratelimits)
  - [TomSqlRateLimiter](#tomsqlratelimiter)
  - [TomRateLimitRow](#tomratelimitrow)
- [Enums](#enums)
  - [TomRateLimitScope](#tomratelimitscope)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/ratelimit/rate_limit.dart`,
`lib/src/tomserver/ratelimit/sql_rate_limiter.dart`.

Nothing is limited until a deployment says so: `TomRateLimits` holds the
configured `TomRateLimitRule`s, the `TomRateLimiter` that counts for them and
the proxies whose `X-Forwarded-For` is believed, and is installed once per
process — by `TomRateLimits.install`, or by `TomServer.start` from the
`rateLimits` configuration key. `tomRateLimitMiddleware`, which `TomServer`
places inside the authentication middleware, counts every request against every
rule that covers it and answers the first refusal with a `429`.

A rule's `TomRateLimitScope` says what it counts by — the signed-in principal,
the API key (`TomApiKeyIdentity`, from the authentication module) or the client
address (`TomClientAddress`). Each key is a sliding-window counter whose
arithmetic is `TomRateLimitDecision.slidingWindow`, shared by
`TomMemoryRateLimiter` (per process, the default) and `TomSqlRateLimiter` (one
atomic statement per request against the shared `tom_rate_limit` table).
`TomRateLimitException` is every refusal the module raises.

## Class Hierarchy

```text
TomServerException  (little_things)
    └── TomRateLimitException

TomRateLimiter  (abstract)
    ├── TomMemoryRateLimiter  (implements, per-process, the default)
    └── TomSqlRateLimiter     (implements, over tom_rate_limit, shared)

TomRateLimitScope     (enum)
TomRateLimitRule      (standalone)
TomRateLimitDecision  (standalone, immutable)
TomClientAddress      (abstract final, statics only)
TomRateLimits         (standalone, statics hold the installed one)
TomRateLimitRow       (@tomReflector, @TomDbTable row type)
```

## Classes

### TomRateLimitException

A failure of rate limiting or its configuration, keyed
`rate_limit.<area>.<condition>`.

| Key | Meaning |
| --- | ------- |
| `rate_limit.exceeded` | A request over a limit — the body of a `429` (`clientThrow: true`). |
| `rate_limit.config.not_a_map` | `rateLimits` is not a map. |
| `rate_limit.config.invalid_rule` | A rule that is not a map, with a `limit` or `windowSeconds` that is not a whole number, or with a limit or window that is not positive. |
| `rate_limit.config.duplicate_rule` | Two rules share a name. |
| `rate_limit.config.unknown_scope` | A scope other than `principal`, `apiKey` or `address`. |
| `rate_limit.config.unknown_limiter` | A limiter other than `memory` or `sql`. |
| `rate_limit.config.missing_datasource` | The `sql` limiter without a registered data source. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomRateLimitException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  bool clientThrow = false,
})
```

### TomRateLimitRule

One limit: at most `limit` requests per `window` per key of `scope`.

- **Extends:** none

#### Constructors

```dart
TomRateLimitRule({
  required String name,
  required TomRateLimitScope scope,
  required int limit,
  required Duration window,
  List<String> pathPrefixes = const [],
  bool anonymousOnly = true,
})
```

Throws `rate_limit.config.invalid_rule` unless `limit` is positive and `window`
longer than zero.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The rule's name — part of every counter's key, and named in the log line of a refusal (final). |
| `scope` | `TomRateLimitScope` | What requests are counted by (final). |
| `limit` | `int` | The requests allowed per `window` (final). |
| `window` | `Duration` | The window the limit is measured over (final). |
| `pathPrefixes` | `List<String>` | The path prefixes the rule applies to; empty for every path (final). |
| `anonymousOnly` | `bool` | For an `address` rule: whether only requests with no authenticated principal are counted (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `appliesTo` | `bool appliesTo(String path)` | Whether the rule applies to a request for `path`: always with no `pathPrefixes`, otherwise when `path` starts with one. |

### TomRateLimitDecision

The outcome of counting one request against one rule.

- **Extends:** none

#### Constructors

```dart
const TomRateLimitDecision({
  required bool allowed,
  required int limit,
  required int remaining,
  required Duration reset,
  required Duration retryAfter,
})
factory TomRateLimitDecision.slidingWindow({
  required int limit,
  required Duration window,
  required Duration elapsed,
  required int current,
  required int previous,
})
```

`slidingWindow` is the decision of a sliding-window counter whose current fixed
window holds `current` requests — this one included — and whose previous window
held `previous`, `elapsed` into a `window` of `limit`. The estimate is
`previous × (window − elapsed) / window + current`; within `limit` the request
is allowed, with `remaining` the whole requests still admitted. Over it,
`retryAfter` is the wait until a next request would be admitted — within this
window when only the previous window's weight is in the way, otherwise into the
next window. It is the one place the arithmetic lives, so the two limiters
cannot disagree about what a count means.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `allowed` | `bool` | Whether the request is within the limit (final). |
| `limit` | `int` | The rule's limit (final). |
| `remaining` | `int` | How many more requests the window admits now (final). |
| `reset` | `Duration` | When the counting window resets (final). |
| `retryAfter` | `Duration` | How long to wait before the next request is admitted; zero when `allowed` (final). |
| `retryAfterSeconds` | `int` | *(getter)* `retryAfter` as whole seconds, rounded up and at least one — the value of a `Retry-After` header. |

### TomRateLimiter

Counts requests per key.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hit` | `Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule)` | Counts one request for `bucket` under `rule` and decides it. The request is counted whether or not it is allowed. |

### TomMemoryRateLimiter

The default limiter: sliding-window counters in this process. **Per node** —
behind a load balancer of N nodes a caller gets up to N times the configured
limit. Counters whose two windows have both passed are pruned every 1024 hits.

- **Implements:** `TomRateLimiter`

#### Constructors

```dart
TomMemoryRateLimiter({DateTime Function()? clock})
```

`clock` is the limiter's idea of the present, `DateTime.now` by default.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `size` | `int` | *(getter)* How many keys have a counter. Test-support. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hit` | `Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule)` | *(override)* |
| `clear` | `void clear()` | Discards every counter. Test-support. |

### TomClientAddress

Which address a request came from. Statics only.

- **Extends:** none (abstract final)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `connectionInfoKey` | `static const String` | `'shelf.io.connection_info'` — the request context key shelf's server adapter stores the `HttpConnectionInfo` under. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static String? of(Request request, {Set<String> trustedProxies = const {}})` | The client address of `request`, or `null` when it cannot be told. The socket's peer, unless the peer is one of `trustedProxies`: then `X-Forwarded-For` is read from the right, skipping trusted proxies, and the first address no trusted proxy appended is the client. The header is never believed from an untrusted peer. |

### TomRateLimits

The configured rules and the limiter that counts for them.

- **Extends:** none

#### Constructors

```dart
TomRateLimits({
  required List<TomRateLimitRule> rules,
  TomRateLimiter? limiter,
  Set<String> trustedProxies = const {},
})
```

`limiter` defaults to a new `TomMemoryRateLimiter`. Throws
`rate_limit.config.duplicate_rule` for two rules sharing a name.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `static const String` | `'rateLimits'` — the configuration key the rules are read from. |
| `current` | `static TomRateLimits?` | *(getter)* The installed limits, or `null` — no limits. |
| `rules` | `List<TomRateLimitRule>` | The rules, each applied to every request it covers (final). |
| `limiter` | `TomRateLimiter` | What counts the requests (final). |
| `trustedProxies` | `Set<String>` | The proxies whose `X-Forwarded-For` is believed (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static void install(TomRateLimits limits)` | Installs `limits` for the request pipeline, replacing any installed. |
| `reset` | `static void reset()` | Removes the installed limits. |
| `fromConfiguration` | `static TomRateLimits? fromConfiguration([TomServerConfigResourceProvider? config])` | The limits the `rateLimits` key describes — `limiter` (`memory` or `sql` with `datasource`), `trustedProxies` and `rules` (`name`, `per`, `limit`, `windowSeconds`, `paths`, `anonymousOnly`) — or `null` when the key is absent. Reads `TomServerConfigResourceProvider.getServerConfig()` unless one is passed. Throws the `rate_limit.config.*` keys. |
| `bucketOf` | `String? bucketOf(TomRateLimitRule rule, Request request)` | The counter key of `request` under `rule` — `<rule>\|<tenant>/<username>` for `principal`, `<rule>\|<keyId>` for `apiKey`, `<rule>\|<address>` for `address` — or `null` when the rule does not count it. Reads the principal and `TomApiKeyIdentity` from the request zone. |
| `check` | `Future<(TomRateLimitDecision?, TomRateLimitRule?)> check(Request request)` | Counts `request` against every rule that covers it, in order: the refusal of the first rule it exceeds, or, when none refuses, the decision with the fewest requests remaining. `(null, null)` when no rule counted it. |
| `headersOf` | `static Map<String, String> headersOf(TomRateLimitDecision decision)` | The `RateLimit-Limit`, `RateLimit-Remaining` and `RateLimit-Reset` headers describing `decision`; the reset in whole seconds, at least one. |
| `tooManyRequests` | `static Response tooManyRequests(TomRateLimitDecision decision, TomRateLimitRule rule)` | The `429` refusing a request: the error envelope of `rate_limit.exceeded` (`clientThrow: true`), with `Retry-After` and the `RateLimit-*` headers. |

### TomSqlRateLimiter

The shared limiter: sliding-window counters in a table every node writes, so a
limit is one limit across the cluster. One row per key and fixed window; a
request is counted with one `INSERT … ON DUPLICATE KEY UPDATE hits =
LAST_INSERT_ID(hits + 1)`, atomic on the server, which hands back this
request's place in the count as the statement's generated id — exact under
concurrency. The previous window's count is read beside it. Every 512 hits the
limiter deletes the rule's rows of windows that can no longer be read; a failed
sweep is logged.

- **Implements:** `TomRateLimiter`

#### Constructors

```dart
TomSqlRateLimiter(
  TomDataSource datasource, {
  String table = defaultRateLimitTable,
  bool createSchema = true,
  DateTime Function()? clock,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the counters live in (final). |
| `table` | `String` | The counter table's name (final). |
| `createSchema` | `bool` | Whether the limiter creates its table on first use (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the table when `createSchema` asks for it; once per limiter, however many first calls arrive together. |
| `hit` | `Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule)` | *(override)* |
| `deleteAll` | `Future<void> deleteAll()` | Deletes every counter. Test-support. |

### TomRateLimitRow

One counter row, as `TomSqlRateLimiter` reads it back — reflected,
`@TomDbTable`-mapped, and internal to the limiter.

#### Properties

| Property | Type | Column | Description |
| -------- | ---- | ------ | ----------- |
| `windowIndex` | `int` | `window_index` | The fixed window, in the rule's own window length. |
| `hits` | `int` | `hits` | The requests counted in it. |

## Enums

### TomRateLimitScope

What a rule counts requests by.

| Value | Meaning |
| ----- | ------- |
| `principal` | The signed-in user: a bearer token whose principal is authenticated, keyed by tenant and username. A request authenticated by an API key is not counted. |
| `apiKey` | The API key a service account presented, keyed by key id. |
| `address` | The client's address; by default only requests with no authenticated principal (`TomRateLimitRule.anonymousOnly`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomRateLimitScope parse(String raw)` | The scope named `raw`, ignoring case, `_`, `-` and spaces — so `apiKey`, `api-key` and `api_key` all read as `apiKey`. Throws `rate_limit.config.unknown_scope`. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomRateLimitMiddleware` | `Middleware tomRateLimitMiddleware()` | The rate-limiting middleware `TomServer` installs inside the authentication middleware, where the principal and the API key are in the zone. A no-op while no limits are installed and for an `OPTIONS` request. A refused request is answered with `TomRateLimits.tooManyRequests` and logged at info level with the rule's name; an admitted one runs and its response gains `TomRateLimits.headersOf` the tightest decision. |
| `defaultRateLimitTable` | `const String` | `'tom_rate_limit'` — the counter table's default name. |
| `rateLimitTable` | `TomFrameworkTable rateLimitTable(String table)` | The counter table's single declaration — `bucket` (`VARCHAR(191)`), `rule` (`VARCHAR(64)`), `window_index` (`BIGINT`), `hits` (`INT`), primary key `(bucket, window_index)` and a key on `(rule, window_index)` — from which the limiter's DDL derives. |

`tomRateLimitMiddleware` lives in `rate_limit.dart`; `defaultRateLimitTable` and
`rateLimitTable` in `sql_rate_limiter.dart`, beside the limiter.
