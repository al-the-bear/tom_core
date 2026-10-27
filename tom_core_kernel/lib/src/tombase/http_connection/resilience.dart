/// Resilience for outgoing HTTP calls: a timeout on every attempt, retries
/// with backoff for calls that may be repeated, a circuit breaker per
/// destination, and a bulkhead limiting concurrent calls per destination.
///
/// The policies live in one client, [TomResilientClient], which wraps any
/// `package:http` client. The framework's own calls go through it: the default
/// client factory of [TomServerChannel] wraps the platform client in one, and
/// the server's components that hold a client of their own (object storage,
/// secret stores, OTLP export, OAuth providers) default to one. A call that
/// should not be retried, broken or limited is still bounded by the timeout —
/// a remote that never answers is the failure the default exists for.
///
/// ## Destinations
///
/// A destination is a scheme, host and port: `https://idp.example.com:443`.
/// Circuit breakers and bulkheads are kept per destination and shared by every
/// client of the isolate, so one failing identity provider opens its own
/// circuit and leaves the others alone, however many clients reach it.
/// [TomHttpResilience.defaults] applies everywhere; a destination may have its
/// own policy ([TomHttpResilience.setDestinationPolicy], or the `destinations`
/// map of [TomHttpResilience.configure]).
///
/// ## What is retried
///
/// A request is retried only when repeating it is safe and possible: its
/// method is idempotent (`GET`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`, `TRACE`) or
/// it carries an `Idempotency-Key` header, and its body is buffered (a
/// `Request`, not a streamed or multipart one, whose body can be read once).
/// An attempt is retried after a connection failure, a timeout, or a status in
/// [TomHttpRetryPolicy.retryStatuses] (`429`, `502`, `503`, `504`), waiting an
/// exponentially growing, jittered backoff — or the server's `Retry-After`,
/// when it names a wait within [TomHttpRetryPolicy.maxBackoff].
///
/// ## Metrics
///
/// | Series | Kind | Labels |
/// | ------ | ---- | ------ |
/// | `tom_http_client_attempts` | counter | `destination`, `outcome` (`ok`, `retryable_status`, `error`) |
/// | `tom_http_client_retries` | counter | `destination` |
/// | `tom_http_client_rejections` | counter | `destination`, `reason` (`circuit_open`, `bulkhead_full`) |
/// | `tom_http_client_circuit_open` | gauge | `destination` — 1 while the circuit is open or half-open |
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart';

import '../context/trace_context.dart';
import '../little_things/exception_base.dart';
import '../metrics/metrics.dart';

/// A call refused or abandoned by a resilience policy.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `http.client.timeout` | An attempt did not receive a response within the policy's timeout. |
/// | `http.client.circuit_open` | The destination's circuit is open: recent calls failed, and none is sent until it half-opens. |
/// | `http.client.bulkhead_full` | The destination already has the most concurrent calls and queued calls the policy allows. |
/// | `http.client.config.invalid` | A resilience configuration value is missing its expected shape. |
class TomHttpResilienceException extends TomException {
  /// Creates the exception; see [TomException] for the fields.
  TomHttpResilienceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// When and how often a failed attempt is repeated.
class TomHttpRetryPolicy {
  /// A policy of at most [maxAttempts] attempts in all.
  const TomHttpRetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 200),
    this.maxBackoff = const Duration(seconds: 5),
    this.retryStatuses = const {429, 502, 503, 504},
    this.idempotentMethods = const {
      'GET',
      'HEAD',
      'OPTIONS',
      'PUT',
      'DELETE',
      'TRACE',
    },
  });

  /// A policy that never retries.
  static const TomHttpRetryPolicy none = TomHttpRetryPolicy(maxAttempts: 1);

  /// The most attempts a call gets, the first included; `1` never retries.
  final int maxAttempts;

  /// The wait before the first retry; each further retry doubles it.
  final Duration initialBackoff;

  /// The longest wait between attempts, and the longest `Retry-After` honoured.
  final Duration maxBackoff;

  /// The response statuses that are retried: the server says try again.
  final Set<int> retryStatuses;

  /// The methods safe to repeat; anything else needs an `Idempotency-Key`.
  final Set<String> idempotentMethods;

  /// Whether [request] may be sent more than once.
  bool mayRetry(BaseRequest request) =>
      maxAttempts > 1 &&
      request is Request &&
      (idempotentMethods.contains(request.method.toUpperCase()) ||
          request.headers.keys.any(
            (h) => h.toLowerCase() == 'idempotency-key',
          ));

  /// The wait before attempt [nextAttempt] (2 for the first retry): the
  /// exponential backoff with full jitter, or [retryAfter] when the server
  /// named one within [maxBackoff].
  Duration backoffBefore(
    int nextAttempt,
    Random random, {
    Duration? retryAfter,
  }) {
    if (retryAfter != null && retryAfter <= maxBackoff) return retryAfter;
    final exponent = max(0, nextAttempt - 2);
    final ceiling = min(
      maxBackoff.inMicroseconds,
      initialBackoff.inMicroseconds * (1 << min(exponent, 20)),
    );
    // Half fixed, half random: spreads a fleet's retries without ever
    // answering a failure with an immediate retry.
    final half = ceiling ~/ 2;
    return Duration(microseconds: half + random.nextInt(max(1, half + 1)));
  }
}

/// When a destination's circuit opens and how long it stays open.
class TomCircuitBreakerPolicy {
  /// A breaker opening after [failureThreshold] consecutive failures and
  /// half-opening after [openDuration].
  const TomCircuitBreakerPolicy({
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
  });

  /// Consecutive failed attempts — an error, a timeout or a `5xx` — that open
  /// the circuit.
  final int failureThreshold;

  /// How long an open circuit refuses calls before letting one trial through.
  final Duration openDuration;
}

/// How many calls one destination may have at once.
class TomBulkheadPolicy {
  /// A bulkhead admitting [maxConcurrent] calls and queueing [maxQueued] more.
  const TomBulkheadPolicy({this.maxConcurrent = 32, this.maxQueued = 64});

  /// Calls in flight at once; the next one waits in the queue.
  final int maxConcurrent;

  /// Calls waiting at once; beyond it a call is refused at once.
  final int maxQueued;
}

/// The policies applied to calls to one destination. A `null` breaker or
/// bulkhead switches that policy off; a `null` [timeout] waits forever.
class TomHttpResiliencePolicy {
  /// A policy of the given parts; the defaults are the framework's.
  const TomHttpResiliencePolicy({
    this.timeout = const Duration(seconds: 30),
    this.streamedTimeout,
    this.retry = const TomHttpRetryPolicy(),
    this.circuitBreaker = const TomCircuitBreakerPolicy(),
    this.bulkhead = const TomBulkheadPolicy(),
  });

  /// How long one attempt may wait for its response's status and headers,
  /// for a request whose body is buffered — a `Request`, the shape of every
  /// API call.
  final Duration? timeout;

  /// The same for a request whose body is streamed (`StreamedRequest`,
  /// `MultipartRequest`) — an upload; `null`, the default, waits forever.
  ///
  /// Separate because a server answers an upload only once the whole body has
  /// arrived, so a response timeout would also cap the upload's duration: a
  /// 30-second limit sized for an API call would fail every large file. Set it
  /// to the longest upload a destination is expected to take.
  final Duration? streamedTimeout;

  /// When failed attempts are repeated.
  final TomHttpRetryPolicy retry;

  /// When the destination's circuit opens, or `null` for no breaker.
  final TomCircuitBreakerPolicy? circuitBreaker;

  /// How many concurrent calls the destination takes, or `null` for no limit.
  final TomBulkheadPolicy? bulkhead;

  /// This policy with the parts a configuration [map] names replaced — see
  /// [TomHttpResilience.configure] for the keys.
  ///
  /// Throws `http.client.config.invalid` for a value of the wrong shape.
  TomHttpResiliencePolicy merge(Map<Object?, Object?> map) {
    int? whole(Map<Object?, Object?> m, String key) {
      if (!m.containsKey(key)) return null;
      final value = m[key];
      final parsed = value is int ? value : int.tryParse('$value');
      if (parsed == null || parsed < 0) {
        throw TomHttpResilienceException(
          'http.client.config.invalid',
          "The HTTP client setting '$key' must be a non-negative whole number, "
              "not '$value'.",
          parameters: {'key': key, 'value': '$value'},
        );
      }
      return parsed;
    }

    Map<Object?, Object?>? section(String key) {
      final value = map[key];
      if (value == null || value == false) return null;
      if (value == true) return const {};
      if (value is Map) return value;
      throw TomHttpResilienceException(
        'http.client.config.invalid',
        "The HTTP client setting '$key' must be a map, true or false.",
        parameters: {'key': key},
      );
    }

    final timeoutMs = whole(map, 'timeoutMs');
    final streamedTimeoutMs = whole(map, 'streamedTimeoutMs');
    final retryMap = section('retry');
    // `retry: true` or a retry map after `retry: false` builds on the
    // framework's retry policy, not on the switched-off one.
    final retryBase = this.retry.maxAttempts > 1
        ? this.retry
        : const TomHttpRetryPolicy();
    final retry = retryMap == null
        ? (map['retry'] == false ? TomHttpRetryPolicy.none : this.retry)
        : TomHttpRetryPolicy(
            maxAttempts:
                whole(retryMap, 'maxAttempts') ?? retryBase.maxAttempts,
            initialBackoff:
                _ms(whole(retryMap, 'initialBackoffMs')) ??
                retryBase.initialBackoff,
            maxBackoff:
                _ms(whole(retryMap, 'maxBackoffMs')) ?? retryBase.maxBackoff,
            retryStatuses: retryMap['retryStatuses'] is List
                ? {
                    for (final s in retryMap['retryStatuses'] as List)
                      int.parse('$s'),
                  }
                : retryBase.retryStatuses,
            idempotentMethods: retryBase.idempotentMethods,
          );
    final breakerMap = section('circuitBreaker');
    final breakerBase = circuitBreaker ?? const TomCircuitBreakerPolicy();
    final bulkheadMap = section('bulkhead');
    final bulkheadBase = bulkhead ?? const TomBulkheadPolicy();
    return TomHttpResiliencePolicy(
      timeout: map.containsKey('timeoutMs')
          ? (timeoutMs == 0 ? null : _ms(timeoutMs))
          : timeout,
      streamedTimeout: map.containsKey('streamedTimeoutMs')
          ? (streamedTimeoutMs == 0 ? null : _ms(streamedTimeoutMs))
          : streamedTimeout,
      retry: retry,
      circuitBreaker: map['circuitBreaker'] == false
          ? null
          : breakerMap == null
          ? circuitBreaker
          : TomCircuitBreakerPolicy(
              failureThreshold:
                  whole(breakerMap, 'failureThreshold') ??
                  breakerBase.failureThreshold,
              openDuration:
                  _ms(whole(breakerMap, 'openDurationMs')) ??
                  breakerBase.openDuration,
            ),
      bulkhead: map['bulkhead'] == false
          ? null
          : bulkheadMap == null
          ? bulkhead
          : TomBulkheadPolicy(
              maxConcurrent:
                  whole(bulkheadMap, 'maxConcurrent') ??
                  bulkheadBase.maxConcurrent,
              maxQueued:
                  whole(bulkheadMap, 'maxQueued') ?? bulkheadBase.maxQueued,
            ),
    );
  }

  static Duration? _ms(int? value) =>
      value == null ? null : Duration(milliseconds: value);
}

/// Where a destination's circuit stands.
enum TomCircuitState {
  /// Calls go through; failures are counted.
  closed,

  /// Calls are refused until the open duration has passed.
  open,

  /// One trial call goes through; its outcome closes or reopens the circuit.
  halfOpen,
}

/// The circuit breaker of one destination.
class TomCircuitBreaker {
  /// A closed breaker under [policy].
  TomCircuitBreaker(this.policy, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The thresholds this breaker applies.
  TomCircuitBreakerPolicy policy;

  final DateTime Function() _clock;
  TomCircuitState _state = TomCircuitState.closed;
  int _failures = 0;
  DateTime? _openedAt;
  bool _trialInFlight = false;

  /// The current state; an open circuit whose open duration has passed reads
  /// as half-open.
  TomCircuitState get state {
    if (_state == TomCircuitState.open &&
        !_clock().isBefore(_openedAt!.add(policy.openDuration))) {
      return TomCircuitState.halfOpen;
    }
    return _state;
  }

  /// Whether a call may be sent now. In the half-open state one call is let
  /// through as the trial and every other call is refused until it ends.
  bool tryAcquire() {
    switch (state) {
      case TomCircuitState.closed:
        return true;
      case TomCircuitState.open:
        return false;
      case TomCircuitState.halfOpen:
        if (_trialInFlight) return false;
        _state = TomCircuitState.halfOpen;
        _trialInFlight = true;
        return true;
    }
  }

  /// Hands back a half-open trial that was never sent, so the next call may be
  /// the trial instead.
  void _returnTrial() => _trialInFlight = false;

  /// Records a successful attempt: the circuit closes.
  void recordSuccess() {
    _failures = 0;
    _trialInFlight = false;
    _state = TomCircuitState.closed;
  }

  /// Records a failed attempt: a failed trial reopens the circuit, and the
  /// [TomCircuitBreakerPolicy.failureThreshold]th consecutive failure opens it.
  void recordFailure() {
    _failures++;
    final wasTrial = _trialInFlight;
    _trialInFlight = false;
    if (wasTrial || _failures >= policy.failureThreshold) {
      _state = TomCircuitState.open;
      _openedAt = _clock();
    }
  }
}

/// The bulkhead of one destination: at most [TomBulkheadPolicy.maxConcurrent]
/// calls at once, at most [TomBulkheadPolicy.maxQueued] waiting.
class TomBulkhead {
  /// A bulkhead under [policy].
  TomBulkhead(this.policy);

  /// The limits this bulkhead applies.
  TomBulkheadPolicy policy;

  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  /// Calls holding a permit now.
  int get active => _active;

  /// Calls waiting for one.
  int get queued => _waiting.length;

  /// Takes a permit, waiting in the queue when every permit is taken, and
  /// answers the function that returns it — call it exactly once. Answers
  /// `null`, without waiting, when the queue is full too.
  Future<void Function()?> acquire() async {
    if (_active < policy.maxConcurrent) {
      _active++;
      return _releaser();
    }
    if (_waiting.length >= policy.maxQueued) return null;
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
    return _releaser();
  }

  void Function() _releaser() {
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_waiting.isNotEmpty) {
        // The permit passes straight to the next caller: [_active] stays.
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    };
  }
}

/// The isolate's resilience configuration and per-destination state.
abstract final class TomHttpResilience {
  static TomHttpResiliencePolicy _defaults = const TomHttpResiliencePolicy();
  static final Map<String, TomHttpResiliencePolicy> _destinations = {};
  static final Map<String, TomCircuitBreaker> _breakers = {};
  static final Map<String, TomBulkhead> _bulkheads = {};
  static TomMetricObservation? _circuitObservation;

  /// The clock circuit breakers read. Replaceable for tests, before the first
  /// call to a destination.
  static DateTime Function() clock = DateTime.now;

  /// The policy of every destination without one of its own.
  static TomHttpResiliencePolicy get defaults => _defaults;

  /// Replaces [defaults].
  static set defaults(TomHttpResiliencePolicy policy) => _defaults = policy;

  /// The destination [uri] belongs to: `scheme://host:port`.
  static String destinationOf(Uri uri) {
    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : (uri.scheme == 'http' ? 80 : 0));
    return '${uri.scheme}://${uri.host}:$port';
  }

  /// Gives [destination] (`scheme://host[:port]`, or a URL on it) its own
  /// policy.
  static void setDestinationPolicy(
    String destination,
    TomHttpResiliencePolicy policy,
  ) => _destinations[destinationOf(Uri.parse(destination))] = policy;

  /// The policy calls to [uri] are made under.
  static TomHttpResiliencePolicy policyFor(Uri uri) =>
      _destinations[destinationOf(uri)] ?? _defaults;

  /// The circuit breaker of [destination] under [policy], or `null` when the
  /// policy has none.
  static TomCircuitBreaker? breakerFor(
    String destination,
    TomHttpResiliencePolicy policy,
  ) {
    final breakerPolicy = policy.circuitBreaker;
    if (breakerPolicy == null) return null;
    _observeCircuits();
    return (_breakers[destination] ??= TomCircuitBreaker(
      breakerPolicy,
      clock: () => clock(),
    ))..policy = breakerPolicy;
  }

  /// The bulkhead of [destination] under [policy], or `null` when the policy
  /// has none.
  static TomBulkhead? bulkheadFor(
    String destination,
    TomHttpResiliencePolicy policy,
  ) {
    final bulkheadPolicy = policy.bulkhead;
    if (bulkheadPolicy == null) return null;
    return (_bulkheads[destination] ??= TomBulkhead(bulkheadPolicy))
      ..policy = bulkheadPolicy;
  }

  /// Applies a configuration map:
  ///
  /// ```yaml
  /// httpClient:
  ///   timeoutMs: 10000            # 0: no timeout
  ///   streamedTimeoutMs: 600000   # uploads; absent or 0: no timeout
  ///   retry: {maxAttempts: 3, initialBackoffMs: 200, maxBackoffMs: 5000,
  ///           retryStatuses: [429, 502, 503, 504]}   # false: no retries
  ///   circuitBreaker: {failureThreshold: 5, openDurationMs: 30000}  # false: off
  ///   bulkhead: {maxConcurrent: 32, maxQueued: 64}  # false: off
  ///   destinations:
  ///     "https://idp.example.com": {timeoutMs: 5000, retry: false}
  /// ```
  ///
  /// The top level replaces parts of [defaults]; each destination's map
  /// replaces parts of the new defaults. Throws `http.client.config.invalid`
  /// for a [config] that is not a map or holds a value of the wrong shape,
  /// before anything is applied.
  static void configure(Object? config) {
    if (config is! Map) {
      throw TomHttpResilienceException(
        'http.client.config.invalid',
        'The HTTP client settings must be a map, not a '
            '${config.runtimeType}.',
      );
    }
    final map = config;
    final defaults = _defaults.merge(map);
    final destinations = <String, TomHttpResiliencePolicy>{};
    final raw = map['destinations'];
    if (raw != null && raw is! Map) {
      throw TomHttpResilienceException(
        'http.client.config.invalid',
        "The HTTP client setting 'destinations' must be a map of destination "
            'to settings.',
      );
    }
    for (final entry in (raw as Map? ?? const {}).entries) {
      final value = entry.value;
      if (value is! Map) {
        throw TomHttpResilienceException(
          'http.client.config.invalid',
          "The HTTP client settings of '${entry.key}' must be a map.",
          parameters: {'destination': '${entry.key}'},
        );
      }
      destinations[destinationOf(Uri.parse('${entry.key}'))] = defaults.merge(
        value,
      );
    }
    _defaults = defaults;
    _destinations
      ..clear()
      ..addAll(destinations);
  }

  /// Forgets every policy and every destination's state, as a fresh isolate
  /// starts. For tests.
  static void reset() {
    _defaults = const TomHttpResiliencePolicy();
    _destinations.clear();
    _breakers.clear();
    _bulkheads.clear();
    _circuitObservation?.cancel();
    _circuitObservation = null;
    clock = DateTime.now;
  }

  static void _observeCircuits() {
    _circuitObservation ??= TomMetrics.registry.observe(
      'tom_http_client_circuit_open',
      help:
          'Whether a destination\'s circuit is open or half-open (1) or '
          'closed (0).',
      observer: () => [
        for (final e in _breakers.entries)
          TomObservedValue(e.value.state == TomCircuitState.closed ? 0 : 1, {
            'destination': e.key,
          }),
      ],
    );
  }
}

/// A `package:http` client applying the resilience policies to every call —
/// see the library documentation.
class TomResilientClient extends BaseClient {
  /// A client sending through [inner] (a new `Client` when omitted). With
  /// [policy] every call uses it; without, [TomHttpResilience.policyFor]
  /// decides per destination.
  TomResilientClient([Client? inner, this.policy, Random? random])
    : _inner = inner ?? Client(),
      _random = random ?? Random();

  final Client _inner;
  final Random _random;

  /// Adds the current trace to [request] as a new span — `traceparent`, and
  /// `tracestate` when the trace carries one — so the callee continues it; a
  /// Tom server then takes the trace id as its request id, and one id follows
  /// the work across both. Nothing is added outside a trace, or when the
  /// request already names one.
  ///
  /// The request id itself is not sent: it equals the trace id unless a
  /// trusted proxy set it, and a callee believes a request-id header only from
  /// its own trusted proxies.
  static void propagateTrace(BaseRequest request) {
    final trace = TomTraceContext.current;
    if (trace == null) return;
    for (final name in request.headers.keys) {
      if (name.toLowerCase() == 'traceparent') return;
    }
    request.headers.addAll(trace.child().headers);
  }

  /// The policy of every call, or `null` to use the destination's.
  final TomHttpResiliencePolicy? policy;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    propagateTrace(request);
    final destination = TomHttpResilience.destinationOf(request.url);
    final policy = this.policy ?? TomHttpResilience.policyFor(request.url);
    final breaker = TomHttpResilience.breakerFor(destination, policy);
    final bulkhead = TomHttpResilience.bulkheadFor(destination, policy);
    final retry = policy.retry;
    final repeatable = retry.mayRetry(request);
    final attempts = repeatable ? retry.maxAttempts : 1;
    final body = request is Request ? request.bodyBytes : null;
    final labels = {'destination': destination};

    for (var attempt = 1; ; attempt++) {
      if (breaker != null && !breaker.tryAcquire()) {
        _count('tom_http_client_rejections', {
          ...labels,
          'reason': 'circuit_open',
        });
        throw TomHttpResilienceException(
          'http.client.circuit_open',
          'The circuit to $destination is open after repeated failures; the '
              'call was not sent.',
          parameters: {'destination': destination},
        );
      }
      final release = bulkhead == null ? () {} : await bulkhead.acquire();
      if (release == null) {
        // The trial permit, if this was one, is handed back unused.
        breaker?._returnTrial();
        _count('tom_http_client_rejections', {
          ...labels,
          'reason': 'bulkhead_full',
        });
        throw TomHttpResilienceException(
          'http.client.bulkhead_full',
          '$destination already has the most concurrent and queued calls '
              'allowed; the call was not sent.',
          parameters: {'destination': destination},
        );
      }

      final abort = Completer<void>();
      final outgoing = body != null
          ? _copy(request as Request, body, abort.future)
          : request;
      final StreamedResponse response;
      try {
        final sending = _inner.send(outgoing);
        final timeout = body != null ? policy.timeout : policy.streamedTimeout;
        response = timeout == null
            ? await sending
            : await sending.timeout(
                timeout,
                onTimeout: () {
                  if (!abort.isCompleted) abort.complete();
                  throw TomHttpResilienceException(
                    'http.client.timeout',
                    '$destination did not answer ${request.method} '
                        '${request.url.path} within ${timeout.inMilliseconds} ms.',
                    parameters: {
                      'destination': destination,
                      'timeoutMs': timeout.inMilliseconds,
                    },
                  );
                },
              );
      } catch (error) {
        release();
        breaker?.recordFailure();
        _count('tom_http_client_attempts', {...labels, 'outcome': 'error'});
        if (attempt < attempts && _isTransient(error)) {
          _count('tom_http_client_retries', labels);
          await Future<void>.delayed(retry.backoffBefore(attempt + 1, _random));
          continue;
        }
        rethrow;
      }

      final status = response.statusCode;
      if (status >= 500) {
        breaker?.recordFailure();
      } else {
        breaker?.recordSuccess();
      }
      if (retry.retryStatuses.contains(status)) {
        _count('tom_http_client_attempts', {
          ...labels,
          'outcome': 'retryable_status',
        });
        if (attempt < attempts) {
          await response.stream.drain<void>().catchError((_) {});
          release();
          _count('tom_http_client_retries', labels);
          await Future<void>.delayed(
            retry.backoffBefore(
              attempt + 1,
              _random,
              retryAfter: _retryAfter(response.headers['retry-after']),
            ),
          );
          continue;
        }
      } else {
        _count('tom_http_client_attempts', {...labels, 'outcome': 'ok'});
      }
      return _releasingOnEnd(response, release);
    }
  }

  @override
  void close() => _inner.close();

  /// A copy of [request] that can be sent again, aborted by [abort] or by the
  /// original's own trigger.
  static Request _copy(Request request, Uint8List body, Future<void> abort) {
    final original = request is Abortable
        ? (request as Abortable).abortTrigger
        : null;
    final trigger = original == null
        ? abort
        : Future.any<void>([abort, original]);
    final copy =
        AbortableRequest(request.method, request.url, abortTrigger: trigger)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..headers.addAll(request.headers)
          ..bodyBytes = body;
    return copy;
  }

  /// Whether [error] may succeed on another attempt: a timeout or a failure
  /// to reach the server, not a refusal by a policy.
  static bool _isTransient(Object error) =>
      error is ClientException ||
      error is TimeoutException ||
      (error is TomHttpResilienceException &&
          error.key == 'http.client.timeout');

  static Duration? _retryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// [response] with its bulkhead permit returned when its body has been read,
  /// has failed or was cancelled.
  static StreamedResponse _releasingOnEnd(
    StreamedResponse response,
    void Function() release,
  ) {
    final stream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleError: (error, stack, sink) {
          release();
          sink.addError(error, stack);
        },
        handleDone: (sink) {
          release();
          sink.close();
        },
      ),
    );
    return StreamedResponse(
      ByteStream(stream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  static void _count(String name, Map<String, String> labels) {
    TomMetrics.registry.counter(name, help: _help[name] ?? name).add(1, labels);
  }

  static const Map<String, String> _help = {
    'tom_http_client_attempts':
        'Outgoing HTTP attempts, by destination and outcome.',
    'tom_http_client_retries':
        'Outgoing HTTP attempts repeated, by destination.',
    'tom_http_client_rejections':
        'Outgoing HTTP calls refused by a policy, by destination and reason.',
  };
}
