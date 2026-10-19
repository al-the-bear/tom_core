# Rate Limiting Module

Request rate limiting for a Tom server: at most so many requests per window,
counted per signed-in user, per API key or per client address, and answered with
`429 Too Many Requests` and a `Retry-After` once a caller is over. The module
says which requests a rule counts, where the counts live — in this process, or
in a table every node shares — and what a refused and an admitted response
carry.

**Nothing is limited until a deployment says so.** A framework cannot know an
application's traffic, so no rule ships enabled: a server without a `rateLimits`
configuration key and without an installed `TomRateLimits` counts nothing and
adds no header. [Starting Values](#starting-values) gives numbers that suit a
typical API.

API keys — the credential the `apiKey` scope counts by — belong to the
authentication module: see
[Service Accounts and API Keys](authentication.md#service-accounts-and-api-keys).

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
  - [Rules in code](#rules-in-code)
- [Scopes](#scopes)
- [How a Request Is Counted](#how-a-request-is-counted)
  - [The sliding-window counter](#the-sliding-window-counter)
  - [Counted before it is checked](#counted-before-it-is-checked)
  - [Several rules](#several-rules)
- [Where the Count Lives](#where-the-count-lives)
  - [Per node](#per-node)
  - [Shared across the cluster](#shared-across-the-cluster)
- [The Client Address](#the-client-address)
- [Responses](#responses)
- [Where It Sits in the Pipeline](#where-it-sits-in-the-pipeline)
- [Starting Values](#starting-values)
- [Failure Keys](#failure-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomRateLimits` | class | The configured rules, the limiter that counts for them and the trusted proxies; installed once per process |
| `TomRateLimitRule` | class | One limit: at most `limit` requests per `window` per key of its scope, optionally on some paths only |
| `TomRateLimitScope` | enum | `principal`, `apiKey` or `address` — what a rule counts requests by |
| `TomRateLimitDecision` | class | The outcome of counting one request against one rule: allowed, remaining, reset, retry-after |
| `TomRateLimiter` | abstract class | Counts one request for a key under a rule and decides it |
| `TomMemoryRateLimiter` | class | The default limiter: sliding-window counters in this process |
| `TomSqlRateLimiter` | class | The shared limiter: sliding-window counters in a table every node writes |
| `TomRateLimitRow` | class | One counter row, as `TomSqlRateLimiter` reads it back; reflected (`@tomReflector`) |
| `TomClientAddress` | abstract final class | The address a request came from — the socket peer, or `X-Forwarded-For` behind a trusted proxy. Statics only |
| `TomRateLimitException` | class | A rate-limit configuration that cannot be used, and the refusal a `429` carries |
| `tomRateLimitMiddleware` | function | The rate-limiting middleware `TomServer` installs inside the authentication middleware |
| `rateLimitTable` | function | The `tom_rate_limit` declaration, from which the limiter's DDL derives |
| `defaultRateLimitTable` | const String | `'tom_rate_limit'` — the counter table's default name |

The module is two files: `rate_limit.dart` holds the rules, the decision
arithmetic, the in-process limiter, the client address, the installed limits and
the middleware; `sql_rate_limiter.dart` holds the shared limiter and its table.

## Configuration

`TomRateLimits.fromConfiguration()` reads the `rateLimits` key
(`TomRateLimits.configurationKey`) of the server configuration, and
`TomServer.start` installs what it reads — when the key is present and no
limits were installed before it:

```yaml
rateLimits:
  limiter: memory              # memory (the default) or sql
  datasource: main             # with limiter: sql — a registered data source
  trustedProxies: [10.0.0.2]   # whose X-Forwarded-For is believed
  rules:
    - { name: users,     per: principal, limit: 100, windowSeconds: 60 }
    - { name: keys,      per: apiKey,    limit: 600, windowSeconds: 60 }
    - { name: anonymous, per: address,   limit: 60,  windowSeconds: 60 }
    - name: login
      per: address
      limit: 10
      windowSeconds: 60
      paths: [/auth/]
      anonymousOnly: true
```

| Key | Default | Meaning |
| --- | ------- | ------- |
| `limiter` | `memory` | `memory` counts in this process; `sql` counts in the `tom_rate_limit` table of `datasource`. |
| `datasource` | — | With `limiter: sql`, the registered data source the counter table lives in. |
| `trustedProxies` | none | The addresses whose `X-Forwarded-For` header is read — see [The Client Address](#the-client-address). |
| `rules` | none | The rules, each applied to every request it covers. |
| `rules[].name` | the `per` value | The rule's name: part of every counter key, and named in a refusal. Unique. |
| `rules[].per` | — | The scope: `principal`, `apiKey` (also `api-key` / `api_key`) or `address`. |
| `rules[].limit` | — | The requests admitted per window; a positive whole number. |
| `rules[].windowSeconds` | — | The window, in seconds; a positive whole number. |
| `rules[].paths` | every path | Path prefixes the rule applies to. |
| `rules[].anonymousOnly` | `true` | For an `address` rule: count only requests with no authenticated principal. |

An absent `rateLimits` key reads as `null` — no limits — and `TomServer.start`
installs nothing. A present key with no `rules` installs limits that count
nothing.

### Rules in code

The same configuration built in code, installed before the server starts:

```dart
TomRateLimits.install(
  TomRateLimits(
    rules: [
      TomRateLimitRule(
        name: 'users',
        scope: TomRateLimitScope.principal,
        limit: 100,
        window: const Duration(minutes: 1),
      ),
      TomRateLimitRule(
        name: 'anonymous',
        scope: TomRateLimitScope.address,
        limit: 60,
        window: const Duration(minutes: 1),
      ),
    ],
    limiter: TomSqlRateLimiter(datasource),   // omit for the in-process default
    trustedProxies: const {'10.0.0.2'},
  ),
);
```

`TomRateLimits.install` replaces any installed limits and `TomRateLimits.reset`
removes them; `TomRateLimits.current` is the installed set, or `null`.

## Scopes

Each rule keys a request by what its scope names, and a request the scope does
not name is not counted by that rule:

| Scope | Counts | Key | Not counted |
| ----- | ------ | --- | ----------- |
| `principal` | requests by a signed-in user — a bearer token whose principal is authenticated | `<rule>\|<tenant>/<username>`, or `<rule>\|<username>` outside tenancy | anonymous requests, and requests authenticated by an API key |
| `apiKey` | requests a service account's API key authenticated | `<rule>\|<keyId>` | every request not authenticated by a key |
| `address` | requests by client address | `<rule>\|<address>` | with `anonymousOnly` (the default), requests with an authenticated principal; and requests whose address cannot be told |

The `principal` scope keys by tenant and username, so two tenants' `alice` are
two callers. A service account's requests count against `apiKey` rules only:
each key has its own budget, so an integration that holds two keys for two jobs
is limited per job.

`anonymousOnly` exists for the office behind one address. Before its people sign
in they share the address rule; once they sign in each is counted by the
`principal` rule instead. Set `anonymousOnly: false` for an address rule that
caps an address whoever is signed in.

## How a Request Is Counted

### The sliding-window counter

Each key's count is a **sliding-window counter**: the count of the current
fixed window plus the previous window's count, weighted by how much of the
previous window still overlaps a window ending now. Twenty seconds into a
one-minute window, the previous minute counts at two thirds. The counter holds
two numbers per key rather than a log of every request, and it is exact when the
traffic is even across a window; a burst at a window boundary is smoothed rather
than admitted twice, which is the failure of a plain fixed window.

`TomRateLimitDecision.slidingWindow` is the one place the arithmetic lives, so
the in-process and the shared limiter cannot disagree about what a count means.
It answers:

- **allowed** when the estimate — `previous × weight + current`, this request
  included — is within the limit, with `remaining` the whole requests the window
  still admits;
- otherwise **refused**, with `retryAfter` the wait until a next request would
  be admitted: within this window when only the previous window's weight is in
  the way, otherwise into the next window, where this window becomes the
  weighted previous one. `retryAfterSeconds` rounds it up to at least one
  second, the value of `Retry-After`.

`reset` is the time until the current fixed window ends.

### Counted before it is checked

A request is counted **before** it is decided, refused or not. That is what
keeps the shared limiter atomic across nodes — one `INSERT … ON DUPLICATE KEY
UPDATE` both counts and reads the count — and it has a consequence a caller
sees: a client that keeps retrying before its `Retry-After` extends its own
wait. That is the behaviour a limit exists to produce.

### Several rules

`TomRateLimits.check` walks the rules in order. A rule that does not apply to
the path, or whose scope does not name the request, is skipped. Every other rule
counts the request; the first one that refuses it decides — later rules are not
counted — and when none refuses, the decision with the fewest requests remaining
is the one the response describes.

## Where the Count Lives

### Per node

`TomMemoryRateLimiter`, the default, counts in this process. On a cluster of N
nodes behind a load balancer a caller is counted by whichever node serves each
request, so it gets up to N times the configured limit. For many deployments
that is acceptable — a limit is a guard against a runaway client, not a quota —
and it costs nothing: no database call per request. Counters whose two windows
have both passed are pruned as the limiter is written.

### Shared across the cluster

`TomSqlRateLimiter` counts in the `tom_rate_limit` table of a data source every
node shares, so a limit is one limit across the cluster:

| Column | Type | Meaning |
| ------ | ---- | ------- |
| `bucket` | `VARCHAR(191)` | The counter key, naming the rule |
| `rule` | `VARCHAR(64)` | The rule's name, for the sweep |
| `window_index` | `BIGINT` | The fixed window, in the rule's own window length |
| `hits` | `INT` | The requests counted in it |

The primary key is `(bucket, window_index)`, with a second key on
`(rule, window_index)`. A request is counted with one statement, the data
source dialect's `incrementCounter` — on MariaDB `INSERT … VALUES (…,
LAST_INSERT_ID(1)) ON DUPLICATE KEY UPDATE hits = LAST_INSERT_ID(hits + 1)`, on
PostgreSQL `INSERT … ON CONFLICT (bucket, window_index) DO UPDATE SET hits =
<table>.hits + 1 RETURNING hits` — atomic on the server, which hands back
*this* request's place in the count as the statement's generated id. Reading the count
with a second statement would be wrong under concurrency: every request of a
burst would see the burst's final total and nearly all of it would be refused.
The previous window's count is read beside it, and the decision follows the same
arithmetic as the in-process limiter.

Rows two windows old are deleted by an occasional sweep, per rule — a window
index is measured in its own rule's window length, so one cut-off for every rule
would delete a long rule's live rows. A failed sweep is logged and leaves rows
that are merely unread.

The cost is two statements per counted request against a shared database: the
price of one global number. The limiter creates its table on first use unless
`createSchema` is `false`; `rateLimitTable(table)` is the declaration a
deployment's own migration can render.

```dart
final limiter = TomSqlRateLimiter(
  TomDataSourceInfo.getDataSourceInfo('main')!.datasource,
);
```

The table is deployment-wide, like the framework's other tables: build the
limiter over a data source that is not routed per tenant. Its keys already name
the tenant where the scope does.

## The Client Address

`TomClientAddress.of(request, trustedProxies:)` is the address an `address`
rule counts by: the socket's peer, as shelf's adapter records it under
`TomClientAddress.connectionInfoKey`.

Behind a reverse proxy or a load balancer every request's peer is the proxy, so
the client is in `X-Forwarded-For`. The header is read **only when the peer is
one of `trustedProxies`**, and then from the right: each trusted proxy appends
the address it received from, so the first address from the right that no
trusted proxy appended is the client. The header is never believed from an
untrusted peer — anyone can send one, and a limit keyed by a header the caller
writes is no limit. A request whose address cannot be told — no connection
information — is not counted by an address rule.

| Peer | `X-Forwarded-For` | Address |
| ---- | ----------------- | ------- |
| `203.0.113.9`, not trusted | anything | `203.0.113.9` |
| `10.0.0.2`, trusted | `198.51.100.4` | `198.51.100.4` |
| `10.0.0.2`, trusted | `1.2.3.4, 198.51.100.4` | `198.51.100.4` — the leftmost entry is whatever the client wrote |
| `10.0.0.2`, trusted | `198.51.100.4, 10.0.0.3`, with `10.0.0.3` trusted | `198.51.100.4` |
| `10.0.0.2`, trusted | none | `10.0.0.2` |

## Responses

A refused request is answered by the middleware, before any handler runs:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 12
RateLimit-Limit: 60
RateLimit-Remaining: 0
RateLimit-Reset: 12

{"errorType": "TomRateLimitException", "errorKey": "rate_limit.exceeded", "clientThrow": true, ...}
```

The body is the framework error envelope (`tomErrorEnvelope`) of a
`TomRateLimitException` keyed `rate_limit.exceeded`, with `clientThrow: true`.
The envelope does not name the rule, so a caller learns when to come back and
not which limit it met; the server's log names the rule. `Retry-After` is whole
seconds and at least one.

An admitted request's response carries the `RateLimit-Limit`,
`RateLimit-Remaining` and `RateLimit-Reset` headers of the tightest rule that
counted it (`TomRateLimits.headersOf`), so a well-behaved client can slow down
before it is refused. A request no rule counted carries none.

## Where It Sits in the Pipeline

`TomServer.start` installs `tomRateLimitMiddleware()` directly **inside the
authentication middleware**, where the request's principal and the API key it
authenticated with are in the zone — a limit keyed per user or per key has
nothing to key by before authentication. See
[server.md](server.md#the-pipeline).

The middleware is a no-op while no limits are installed, and for an `OPTIONS`
request: a CORS preflight is the browser's question rather than the caller's
request, and counting it would halve every browser client's budget. A request
the authentication middleware answers itself — a tenancy refusal — never reaches
it and is not counted.

A refusal is logged at info level with the rule's name and the path, never with
the caller's credential.

A limiter that cannot count — the shared table unreachable — throws, and the
request fails through the server's error handling rather than being admitted
uncounted.

## Starting Values

No rule is enabled by default. For a typical API, start with:

| Rule | Scope | Limit | Why |
| ---- | ----- | ----- | --- |
| signed-in users | `principal` | 100 per minute | A person working through a UI rarely exceeds one request a second sustained; a script under a user's token does, and should be a service account instead. |
| service accounts | `apiKey` | 600 per minute | An integration batches; ten a second is room for a nightly import without letting one runaway job starve the server. |
| anonymous callers | `address` | 60 per minute | The login, public pages and a provider's redirect. Low, because anonymous traffic is where scraping and credential stuffing come from, and anonymousOnly lifts the office behind one address off it once its people sign in. |

Tighten a path that is expensive or sensitive with its own rule and `paths`.
Raise a number when the `RateLimit-Remaining` header of legitimate traffic
approaches zero, not before.

The login's own protections are separate and stay in force whatever is
configured here: the second-factor attempt counter and the pace of delivered
codes belong to the authentication module — see
[authentication.md](authentication.md#the-attempt-counter-and-what-makes-it-a-bound).

## Failure Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `rate_limit.exceeded` | the middleware | A request over a limit; the body of the `429` (`clientThrow: true`). |
| `rate_limit.config.not_a_map` | `TomRateLimits.fromConfiguration` | `rateLimits` is not a map. |
| `rate_limit.config.invalid_rule` | `TomRateLimitRule`, `fromConfiguration` | A rule that is not a map, has a `limit` or `windowSeconds` that is not a whole number, or a limit or window that is not positive. |
| `rate_limit.config.duplicate_rule` | `TomRateLimits` | Two rules with one name — a name keys the counters. |
| `rate_limit.config.unknown_scope` | `TomRateLimitScope.parse` | A `per` other than `principal`, `apiKey` or `address`. |
| `rate_limit.config.unknown_limiter` | `fromConfiguration` | A `limiter` other than `memory` or `sql`. |
| `rate_limit.config.missing_datasource` | `fromConfiguration` | `limiter: sql` without a registered `datasource`. |

`TomRateLimitException` extends `TomServerException`. The configuration keys are
raised when the server starts, so a misconfigured limit stops the start rather
than the first request.

## Not Yet Implemented

- **The default limiter counts per node.** On N nodes a caller gets up to N
  times the limit; `TomSqlRateLimiter` is the shared alternative.
  <!-- unpinned: decision — the in-process limiter is the default because it costs no database call per request -->
- **A limiter that cannot count does not admit.** There is no fail-open
  setting: a shared table that is unreachable fails the requests it would have
  counted.
  <!-- unpinned: absence — no fail-open mode is offered -->
- **Nothing is limited by default.** Limits are deployment configuration.
  <!-- pinned: test/ratelimit_test.dart › are absent without the key: nothing is limited by default -->
- **No quota or billing period.** A rule is a rate over a sliding window of
  seconds to minutes; a monthly allowance per customer is application logic.
  <!-- unpinned: absence — quotas are not rate limits -->

## Verification

`test/ratelimit_test.dart` covers the module without a database: the
sliding-window arithmetic — what remains, the previous window's weight, the wait
into the next window and the wait for the previous window's weight to drop, and a
`Retry-After` of at least one second; `TomMemoryRateLimiter` admitting the limit,
refusing the next and admitting again in time; rules that need a positive limit
and window and a unique name, read from the `rateLimits` key and absent without
it, with an unknown scope or limiter refused by name; `TomClientAddress` reading
the socket peer, ignoring `X-Forwarded-For` from an untrusted peer and reading it
from the right behind trusted proxies; and the middleware — a `429` with
`Retry-After` per address, a path a rule does not cover, a preflight, a limit per
API key apart from the address rule, a refused key counted by its address, no
limits installed, and a principal rule keyed by tenant and name.

`test/ratelimit_api_keys_db_test.dart`, tagged `db`, runs `TomSqlRateLimiter`
against the database the DB suites run against — MariaDB or PostgreSQL: two nodes counting into one limit, concurrent requests each
counted once, and a new window admitting again weighted by the previous one.
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL) starts a database for it.

```bash
dart run example/ratelimit/rate_limit_example.dart
```

`example/ratelimit/rate_limit_example.dart` walks a service account through seven
steps without a database, through the same two middlewares a `TomServer` stacks:
a key scoped to one of its account's roles, the request it authenticates, a limit
per key refusing the fourth request in a minute, the `Retry-After` of the
refusal, anonymous callers counted by address apart from the key, a rotation and
a revocation. Every step checks its own result, and `test/examples_test.dart`
runs it.

## Core Components

- **`TomRateLimits`** — the rules, the limiter and the trusted proxies; reading
  them (`fromConfiguration`, `configurationKey`), their lifecycle (`install`,
  `reset`, `current`), counting a request (`bucketOf`, `check`) and the responses
  (`headersOf`, `tooManyRequests`).
- **`TomRateLimitRule`** / **`TomRateLimitScope`** — one limit and what it
  counts by; `appliesTo` reads the rule's paths and `TomRateLimitScope.parse` a
  configured scope.
- **`TomRateLimitDecision`** — one counted request's outcome;
  `TomRateLimitDecision.slidingWindow` is the arithmetic, `retryAfterSeconds` the
  header value.
- **`TomRateLimiter`**, **`TomMemoryRateLimiter`**, **`TomSqlRateLimiter`** —
  where the counts live; `TomSqlRateLimiter` over `rateLimitTable` and
  `TomRateLimitRow`.
- **`TomClientAddress`** — the address an `address` rule counts by.
- **`tomRateLimitMiddleware`** — the middleware `TomServer` installs.
- **`TomRateLimitException`** — every refusal this module raises.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `rate_limit.dart` | `jsonEncode`, the body of a `429` |
| `dart:io` | dart | `rate_limit.dart` | `HttpConnectionInfo`, the socket peer shelf's adapter records |
| `dart:math` | dart | `rate_limit.dart` | `max`, for the remaining count and the whole-second headers |
| `shelf` | package | `rate_limit.dart` | `Request`, `Response` and `Middleware` |
| `tom_core_kernel` | package | every file | `getFromCurrentZone`, `TomPrincipal`, `tomLog`, `TomHeader`, `TomMimeType` and `tomReflector` |
| [authentication](authentication.md) | module | `rate_limit.dart` | `TomApiKeyIdentity`, the key a request authenticated with |
| [configuration](configuration.md) | module | `rate_limit.dart` | `TomServerConfigResourceProvider`, which `fromConfiguration` reads the `rateLimits` key from |
| [datasources](datasources.md) | module | every file | `TomDataSourceInfo` (the `datasource` a configured `sql` limiter names), and `TomDataSource`, `TomFrameworkTable`, `TomSchemaProvisioning` and `TomLiteralSelect` for the shared counter table |
| [little_things](little_things.md) | module | `rate_limit.dart` | `TomServerException`, the base of `TomRateLimitException`, and `tomErrorEnvelope`, the body of a `429` |
| [object_persistence](object_persistence.md) | module | `sql_rate_limiter.dart` | `TomDbTable` and `TomDbColumn`, mapping `TomRateLimitRow` |
