/// Request rate limiting: per principal, per API key and per client address,
/// answered with `429 Too Many Requests` and `Retry-After`.
///
/// ## Nothing is limited until a deployment says so
///
/// A framework cannot know an application's traffic, so no rule ships enabled:
/// limits are configured (`rateLimits:` in the server configuration, or
/// [TomRateLimits.install]). Starting values that suit a typical API are 100
/// requests a minute per principal, 600 per API key and 60 per anonymous
/// address; `doc/ratelimit.md` explains each.
///
/// ## How a request is counted
///
/// Each rule keys a request by what its scope names — the signed-in user, the
/// API key, or the client address — and counts it in a **sliding window**: the
/// count of the current fixed window plus the previous window's count weighted
/// by how much of it still overlaps the sliding one. That is the standard
/// sliding-window counter; it needs two numbers per key rather than a log of
/// every request, and is exact when the traffic is even across a window.
///
/// A request is counted **before** it is checked, refused or not, which is what
/// keeps the shared limiter atomic across nodes with one `INSERT … ON DUPLICATE
/// KEY UPDATE`. A caller that keeps retrying before its `Retry-After` therefore
/// extends its own wait — the behaviour a limit exists to produce.
///
/// ## Where the count lives
///
/// [TomMemoryRateLimiter], the default, counts in this process: on a cluster of
/// N nodes behind a load balancer a caller gets up to N times the configured
/// limit. A deployment that needs one global limit installs
/// `TomSqlRateLimiter`, which counts in a table every node shares.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../authentication/api_keys.dart';
import '../configuration/base_server_configuration.dart';
import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';
import 'sql_rate_limiter.dart';

/// A failure of rate limiting or its configuration, keyed
/// `rate_limit.<area>.<condition>`.
class TomRateLimitException extends TomServerException {
  /// A failure with [key] and [defaultUserMessage].
  TomRateLimitException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.clientThrow = false,
  });
}

/// What a rule counts requests by.
enum TomRateLimitScope {
  /// The signed-in user: requests carrying a bearer token whose principal is
  /// authenticated. Keyed by tenant and username.
  principal,

  /// The API key a service account presented. Keyed by key id.
  apiKey,

  /// The client's address. Keyed by IP address; by default only requests with
  /// no authenticated principal are counted (see
  /// [TomRateLimitRule.anonymousOnly]).
  address;

  /// The scope named [raw] (`principal`, `apiKey` / `api-key`, `address`).
  static TomRateLimitScope parse(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[_\-\s]'), '').toLowerCase();
    for (final value in values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    throw TomRateLimitException(
      'rate_limit.config.unknown_scope',
      "Unknown rate-limit scope '$raw'; expected one of "
          "${values.map((v) => v.name).join(', ')}.",
      parameters: {'scope': raw},
    );
  }
}

/// One limit: at most [limit] requests per [window] per key of [scope].
class TomRateLimitRule {
  /// The rule's name — part of every counter's key, and named in a refusal.
  final String name;

  /// What requests are counted by.
  final TomRateLimitScope scope;

  /// The requests allowed per [window].
  final int limit;

  /// The window the limit is measured over.
  final Duration window;

  /// The path prefixes the rule applies to; empty for every path.
  final List<String> pathPrefixes;

  /// For an [TomRateLimitScope.address] rule: whether only requests with no
  /// authenticated principal are counted. Default `true`, so that one office
  /// behind one address is limited per person once its people sign in.
  final bool anonymousOnly;

  /// A rule. [limit] must be positive and [window] longer than zero.
  TomRateLimitRule({
    required this.name,
    required this.scope,
    required this.limit,
    required this.window,
    this.pathPrefixes = const [],
    this.anonymousOnly = true,
  }) {
    if (limit <= 0 || window <= Duration.zero) {
      throw TomRateLimitException(
        'rate_limit.config.invalid_rule',
        "Rate-limit rule '$name' needs a positive limit and window, but has "
            '$limit per $window.',
        parameters: {'rule': name},
      );
    }
  }

  /// Whether the rule applies to a request for [path].
  bool appliesTo(String path) =>
      pathPrefixes.isEmpty || pathPrefixes.any(path.startsWith);
}

/// The outcome of counting one request against one rule.
class TomRateLimitDecision {
  /// Whether the request is within the limit.
  final bool allowed;

  /// The rule's limit.
  final int limit;

  /// How many more requests the window admits now.
  final int remaining;

  /// When the counting window resets.
  final Duration reset;

  /// How long to wait before the next request is admitted; zero when
  /// [allowed].
  final Duration retryAfter;

  /// A decision.
  const TomRateLimitDecision({
    required this.allowed,
    required this.limit,
    required this.remaining,
    required this.reset,
    required this.retryAfter,
  });

  /// The decision of a sliding-window counter whose current window holds
  /// [current] requests (this one included) and whose previous window held
  /// [previous], [elapsed] into a [window] of [limit].
  ///
  /// The one place the arithmetic lives, so the in-process and the shared
  /// limiter cannot disagree about what a count means.
  factory TomRateLimitDecision.slidingWindow({
    required int limit,
    required Duration window,
    required Duration elapsed,
    required int current,
    required int previous,
  }) {
    final w = window.inMicroseconds;
    final e = elapsed.inMicroseconds.clamp(0, w);
    final weight = (w - e) / w;
    final estimate = previous * weight + current;
    final reset = Duration(microseconds: w - e);
    if (estimate <= limit) {
      return TomRateLimitDecision(
        allowed: true,
        limit: limit,
        remaining: max(0, (limit - estimate).floor()),
        reset: reset,
        retryAfter: Duration.zero,
      );
    }
    // The wait until a next request would be admitted: within this window
    // when only the previous window's weight is in the way, otherwise into the
    // next one, where this window becomes the weighted previous.
    double waitMicros;
    if (current + 1 > limit) {
      final share = (limit - 1) / current;
      waitMicros = (w - e) + (share >= 1 ? 0 : w * (1 - share));
    } else {
      waitMicros = (w - e) - w * (limit - 1 - current) / previous;
    }
    return TomRateLimitDecision(
      allowed: false,
      limit: limit,
      remaining: 0,
      reset: reset,
      retryAfter: Duration(microseconds: max(0, waitMicros.ceil())),
    );
  }

  /// [retryAfter] as whole seconds, at least one — the value of a
  /// `Retry-After` header.
  int get retryAfterSeconds =>
      max(1, (retryAfter.inMilliseconds / 1000).ceil());
}

/// Counts requests per key.
abstract class TomRateLimiter {
  /// Counts one request for [bucket] under [rule] and decides it.
  Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule);
}

/// The default limiter: sliding-window counters in this process.
///
/// **Per node.** Behind a load balancer of N nodes a caller gets up to N times
/// the configured limit; install a `TomSqlRateLimiter` for one shared limit.
class TomMemoryRateLimiter implements TomRateLimiter {
  /// A limiter whose idea of the present is [clock].
  TomMemoryRateLimiter({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _Counter> _counters = {};
  int _hits = 0;

  /// How many keys have a counter. Test-support.
  int get size => _counters.length;

  @override
  Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule) async {
    final now = _clock().microsecondsSinceEpoch;
    final w = rule.window.inMicroseconds;
    final index = now ~/ w;
    if (++_hits % 1024 == 0) _prune(now);
    final counter = _counters[bucket];
    final int previous;
    final int current;
    if (counter == null || counter.index < index - 1) {
      previous = 0;
      current = 1;
    } else if (counter.index == index - 1) {
      previous = counter.count;
      current = 1;
    } else {
      previous = counter.previous;
      current = counter.count + 1;
    }
    _counters[bucket] = _Counter(index, current, previous, w);
    return TomRateLimitDecision.slidingWindow(
      limit: rule.limit,
      window: rule.window,
      elapsed: Duration(microseconds: now - index * w),
      current: current,
      previous: previous,
    );
  }

  /// Drops counters whose two windows have both passed.
  void _prune(int now) => _counters.removeWhere(
    (_, counter) => counter.index < now ~/ counter.window - 1,
  );

  /// Discards every counter. Test-support.
  void clear() => _counters.clear();
}

class _Counter {
  _Counter(this.index, this.count, this.previous, this.window);

  final int index;
  final int count;
  final int previous;
  final int window;
}

/// Which address a request came from.
abstract final class TomClientAddress {
  /// The request context key shelf's server adapter stores the connection
  /// information under.
  static const String connectionInfoKey = 'shelf.io.connection_info';

  /// The client address of [request], or `null` when it cannot be told.
  ///
  /// The socket's peer, unless that peer is one of [trustedProxies]: then the
  /// `X-Forwarded-For` chain is read from the right, skipping trusted proxies,
  /// and the first address no trusted proxy appended is the client. The header
  /// is never believed from an untrusted peer — anyone can send one, and a
  /// limit keyed by a header the caller writes is no limit.
  static String? of(Request request, {Set<String> trustedProxies = const {}}) {
    final info = request.context[connectionInfoKey];
    final peer = info is HttpConnectionInfo ? info.remoteAddress.address : null;
    if (peer == null || !trustedProxies.contains(peer)) return peer;
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded == null) return peer;
    final chain = forwarded
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    for (final address in chain.reversed) {
      if (!trustedProxies.contains(address)) return address;
    }
    return chain.isEmpty ? peer : chain.first;
  }
}

/// The configured rules and the limiter that counts for them.
class TomRateLimits {
  /// The configuration key the rules are read from.
  static const String configurationKey = 'rateLimits';

  /// The rules, each applied to every request it covers.
  final List<TomRateLimitRule> rules;

  /// What counts the requests.
  final TomRateLimiter limiter;

  /// The proxies whose `X-Forwarded-For` is believed (see
  /// [TomClientAddress.of]).
  final Set<String> trustedProxies;

  /// Limits applying [rules], counted by [limiter] (in this process by
  /// default).
  TomRateLimits({
    required this.rules,
    TomRateLimiter? limiter,
    this.trustedProxies = const {},
  }) : limiter = limiter ?? TomMemoryRateLimiter() {
    final names = <String>{};
    for (final rule in rules) {
      if (!names.add(rule.name)) {
        throw TomRateLimitException(
          'rate_limit.config.duplicate_rule',
          "Two rate-limit rules are named '${rule.name}'; a name keys the "
              'counters, so it must be unique.',
          parameters: {'rule': rule.name},
        );
      }
    }
  }

  static TomRateLimits? _current;

  /// The installed limits, or `null` — no limits.
  static TomRateLimits? get current => _current;

  /// Installs [limits] for the request pipeline.
  static void install(TomRateLimits limits) => _current = limits;

  /// Removes the installed limits.
  static void reset() => _current = null;

  /// Reads the limits from the `rateLimits:` configuration key, or `null` when
  /// the key is absent.
  ///
  /// ```yaml
  /// rateLimits:
  ///   limiter: memory            # or: sql (with datasource:)
  ///   trustedProxies: [10.0.0.2]
  ///   rules:
  ///     - { name: users, per: principal, limit: 100, windowSeconds: 60 }
  ///     - { name: keys, per: apiKey, limit: 600, windowSeconds: 60 }
  ///     - { name: anonymous, per: address, limit: 60, windowSeconds: 60 }
  /// ```
  static TomRateLimits? fromConfiguration([
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (!provider.exists(configurationKey)) return null;
    final raw = provider.get(configurationKey);
    if (raw is! Map) {
      throw TomRateLimitException(
        'rate_limit.config.not_a_map',
        "Configuration '$configurationKey' must be a map, but was a "
            '${raw.runtimeType}.',
      );
    }
    final rules = <TomRateLimitRule>[];
    for (final entry in (raw['rules'] as List?) ?? const []) {
      if (entry is! Map) {
        throw TomRateLimitException(
          'rate_limit.config.invalid_rule',
          "Each entry of '$configurationKey.rules' must be a map.",
        );
      }
      int number(String key) {
        final value = entry[key];
        final parsed = value is int ? value : int.tryParse('$value');
        if (parsed == null) {
          throw TomRateLimitException(
            'rate_limit.config.invalid_rule',
            "Rate-limit rule '${entry['name']}' needs a whole-number '$key'.",
            parameters: {'rule': '${entry['name']}', 'field': key},
          );
        }
        return parsed;
      }

      rules.add(
        TomRateLimitRule(
          name: '${entry['name'] ?? entry['per']}',
          scope: TomRateLimitScope.parse('${entry['per']}'),
          limit: number('limit'),
          window: Duration(seconds: number('windowSeconds')),
          pathPrefixes: [
            for (final p in (entry['paths'] as List?) ?? const []) '$p',
          ],
          anonymousOnly: entry['anonymousOnly'] != false,
        ),
      );
    }
    final limiterType = '${raw['limiter'] ?? 'memory'}'.toLowerCase();
    final TomRateLimiter limiter;
    switch (limiterType) {
      case 'memory':
        limiter = TomMemoryRateLimiter();
      case 'sql':
        final name = raw['datasource'];
        final info = name == null
            ? null
            : TomDataSourceInfo.getDataSourceInfo('$name');
        if (info == null) {
          throw TomRateLimitException(
            'rate_limit.config.missing_datasource',
            "The 'sql' rate limiter needs a registered 'datasource'.",
            parameters: {'datasource': '$name'},
          );
        }
        limiter = TomSqlRateLimiter(info.datasource);
      default:
        throw TomRateLimitException(
          'rate_limit.config.unknown_limiter',
          "Unknown rate limiter '$limiterType'; expected memory or sql.",
          parameters: {'limiter': limiterType},
        );
    }
    return TomRateLimits(
      rules: rules,
      limiter: limiter,
      trustedProxies: {
        for (final p in (raw['trustedProxies'] as List?) ?? const []) '$p',
      },
    );
  }

  /// The counter key of [request] under [rule], or `null` when the rule does
  /// not count it.
  String? bucketOf(TomRateLimitRule rule, Request request) {
    final principal = getFromCurrentZone<TomPrincipal>();
    final apiKey = getFromCurrentZone<TomApiKeyIdentity>();
    final signedIn = principal != null && principal.authenticated;
    switch (rule.scope) {
      case TomRateLimitScope.principal:
        if (!signedIn || apiKey != null) return null;
        final tenant = principal.tenant;
        return '${rule.name}|${tenant == null ? '' : '$tenant/'}'
            '${principal.username}';
      case TomRateLimitScope.apiKey:
        return apiKey == null ? null : '${rule.name}|${apiKey.keyId}';
      case TomRateLimitScope.address:
        if (rule.anonymousOnly && signedIn) return null;
        final address = TomClientAddress.of(
          request,
          trustedProxies: trustedProxies,
        );
        return address == null ? null : '${rule.name}|$address';
    }
  }

  /// Counts [request] against every rule that covers it: the refusal of the
  /// first rule it exceeds, or the decision closest to its limit when none.
  Future<(TomRateLimitDecision?, TomRateLimitRule?)> check(
    Request request,
  ) async {
    TomRateLimitDecision? tightest;
    TomRateLimitRule? tightestRule;
    final path = request.requestedUri.path;
    for (final rule in rules) {
      if (!rule.appliesTo(path)) continue;
      final bucket = bucketOf(rule, request);
      if (bucket == null) continue;
      final decision = await limiter.hit(bucket, rule);
      if (!decision.allowed) return (decision, rule);
      if (tightest == null || decision.remaining < tightest.remaining) {
        tightest = decision;
        tightestRule = rule;
      }
    }
    return (tightest, tightestRule);
  }

  /// The `RateLimit-*` headers describing [decision].
  static Map<String, String> headersOf(TomRateLimitDecision decision) => {
    'RateLimit-Limit': '${decision.limit}',
    'RateLimit-Remaining': '${decision.remaining}',
    'RateLimit-Reset':
        '${max(1, (decision.reset.inMilliseconds / 1000).ceil())}',
  };

  /// The `429` refusing a request [rule] does not admit.
  static Response tooManyRequests(
    TomRateLimitDecision decision,
    TomRateLimitRule rule,
  ) => Response(
    429,
    body: jsonEncode(
      tomErrorEnvelope(
        TomRateLimitException(
          'rate_limit.exceeded',
          'Too many requests; try again in ${decision.retryAfterSeconds} '
              'seconds.',
          parameters: {'rule': rule.name},
          clientThrow: true,
        ),
      ),
    ),
    headers: {
      TomHeader.contentType: TomMimeType.json.toHeaderValue(),
      'Retry-After': '${decision.retryAfterSeconds}',
      ...headersOf(decision),
    },
  );
}

/// The rate-limiting [Middleware] of a `TomServer`.
///
/// Placed inside the authentication middleware, where the request's principal
/// and API key are in the zone. A no-op while no limits are installed, and for
/// a CORS preflight, which is the browser's question rather than the caller's
/// request.
Middleware tomRateLimitMiddleware() =>
    (innerHandler) => (request) async {
      final limits = TomRateLimits.current;
      if (limits == null || request.method == 'OPTIONS') {
        return innerHandler(request);
      }
      final (decision, rule) = await limits.check(request);
      if (decision == null) return innerHandler(request);
      if (!decision.allowed) {
        tomLog.info(
          "Rate limit '${rule!.name}' refused a request to "
          '${request.requestedUri.path}; retry after '
          '${decision.retryAfterSeconds}s.',
        );
        return TomRateLimits.tooManyRequests(decision, rule);
      }
      final response = await innerHandler(request);
      return response.change(headers: TomRateLimits.headersOf(decision));
    };
