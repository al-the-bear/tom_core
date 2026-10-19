# ratelimit

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Request rate limiting for a Tom server. A **rule** admits at most so many
requests per window, counted per signed-in user, per API key or per client
address; a request over a rule is answered `429 Too Many Requests` with
`Retry-After`, and an admitted one carries `RateLimit-*` headers.

**Nothing is limited until a deployment says so** — a framework cannot know an
application's traffic. Rules come from the `rateLimits` configuration key or
`TomRateLimits.install`. Each key is a sliding-window counter, kept in this
process by default (so N nodes admit up to N times a limit) or in a table every
node shares. The middleware sits inside authentication, where the principal and
the API key it counts by are known; behind a proxy the client address is read
from `X-Forwarded-For` only when the peer is a trusted proxy.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomRateLimits` | The rules, the limiter and the trusted proxies. `fromConfiguration` reads `rateLimits`; `install` / `reset` / `current`; `check` counts a request; `headersOf` and `tooManyRequests` are the responses. |
| `TomRateLimitRule` · `TomRateLimitScope` | One limit — name, scope, limit, window, optional path prefixes — and what it counts by: `principal`, `apiKey` or `address`. |
| `TomRateLimitDecision` | One counted request's outcome; `slidingWindow` is the arithmetic both limiters share. |
| `TomRateLimiter` · `TomMemoryRateLimiter` · `TomSqlRateLimiter` | Where the counts live: this process, or the shared `tom_rate_limit` table, counted with one atomic statement per request. |
| `TomClientAddress` | The address an `address` rule counts by. |
| `tomRateLimitMiddleware` | The middleware `TomServer` installs inside the authentication middleware. |
| `TomRateLimitException` | `rate_limit.exceeded` and the `rate_limit.config.*` refusals. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final rule = TomRateLimitRule(
    name: 'keys',
    scope: TomRateLimitScope.apiKey,
    limit: 2,
    window: const Duration(minutes: 1),
  );
  final limiter = TomMemoryRateLimiter();

  for (var i = 1; i <= 3; i++) {
    final decision = await limiter.hit('keys|k1', rule);
    print('request $i: allowed=${decision.allowed} '
        'remaining=${decision.remaining}');
    if (!decision.allowed) {
      print('Retry-After: ${decision.retryAfterSeconds}');
      print(TomRateLimits.headersOf(decision)['RateLimit-Remaining']); // 0
    }
  }

  // Another key has a budget of its own.
  print((await limiter.hit('keys|k2', rule)).allowed); // true
}
```

In a server the limiter is not called by hand: install the rules —
`TomRateLimits.install(TomRateLimits(rules: [rule]))`, or a `rateLimits` block in
the configuration — and the middleware counts every request.

**Metrics.** Every refusal is counted in `tom_rate_limit_refusals`
(`tomRateLimitRefusalsMetric`) by rule and tenant, `none` (`tomNoTenantLabel`)
outside any — see [`doc/metrics.md`](../../../../doc/metrics.md).

See [`doc/ratelimit.md`](../../../../doc/ratelimit.md) for the configuration, the
three scopes, the sliding-window algorithm, per-node and shared counting, the
client address behind proxies, the response headers and starting values, and
`example/ratelimit/rate_limit_example.dart` for a service account's API key
counted, refused, rotated and revoked through the server's own middlewares,
checking its own results. `test/ratelimit_test.dart` covers the module without
a database and `test/ratelimit_api_keys_db_test.dart` (tagged `db`) runs the
shared limiter across two nodes against MariaDB or PostgreSQL. `test/examples_test.dart` runs
the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
