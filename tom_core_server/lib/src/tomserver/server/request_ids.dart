/// Which request id a request runs under: the caller's trace, a trusted
/// proxy's id, or one of its own.
///
/// ## The rule
///
/// 1. A request carrying the configured request-id header ([TomRequestIdPolicy
///    .header], `X-Request-Id` by default) **from one of the trusted proxies**,
///    with a value [TomRequestId.isValid] accepts, runs under that value. A
///    proxy that assigns ids — a gateway, a load balancer — is believed; anyone
///    else could choose the id their requests are logged and audited under, so
///    the header is ignored from every other peer.
/// 2. Otherwise the request runs under the id of its trace: the caller's trace
///    id when its `traceparent` is valid, so the caller and this server log one
///    id for one piece of work, or the id of the new trace it starts. A trace
///    id is accepted from anyone — it carries no authority, and its format (32
///    lower-case hex digits) leaves nothing to inject.
/// 3. A malformed header of either kind is ignored, never refused: the request
///    gets an id of its own, as the W3C specification requires for
///    `traceparent`.
///
/// A `tracestate` is carried on unchanged when it is printable and at most 512
/// characters, and dropped otherwise.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../ratelimit/rate_limit.dart';

/// The header a server echoes the request id in by default, so a caller can
/// quote it, and the one it believes from a trusted proxy.
const String tomRequestIdHeader = 'X-Request-Id';

/// Thrown when the request-id settings cannot be applied.
class TomRequestIdException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomRequestIdException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// How a request's id is chosen — see the library documentation for the rule.
final class TomRequestIdPolicy {
  /// A policy believing [header] from the socket peers in [trustedProxies].
  const TomRequestIdPolicy({
    this.header = tomRequestIdHeader,
    this.trustedProxies = const {},
  });

  /// The request-id header: echoed on every response, and believed from a
  /// trusted proxy.
  final String header;

  /// The addresses of the proxies whose request-id header is believed — the
  /// socket peer, compared as its address text (`10.0.0.2`, `::1`).
  final Set<String> trustedProxies;

  /// The configuration key holding the settings — see [configure].
  static const String configurationKey = 'requestIds';

  /// The policy the request pipeline applies; set by [configure].
  static TomRequestIdPolicy current = const TomRequestIdPolicy();

  /// Sets [current] from [config]:
  ///
  /// ```yaml
  /// requestIds:
  ///   header: X-Request-Id       # optional; the default
  ///   trustedProxies: [10.0.0.2] # optional; none by default
  /// ```
  ///
  /// Throws `server.request_ids.config.invalid` for a value of the wrong
  /// shape, before anything is applied.
  static void configure(Object? config) {
    Never invalid(String message, [Map<String, Object?>? parameters]) =>
        throw TomRequestIdException(
          'server.request_ids.config.invalid',
          message,
          parameters: parameters,
        );
    if (config is! Map) {
      invalid(
        'The request-id settings must be a map, not a ${config.runtimeType}.',
      );
    }
    final unknown = config.keys
        .map((k) => '$k')
        .where((k) => k != 'header' && k != 'trustedProxies');
    if (unknown.isNotEmpty) {
      invalid('Unknown request-id settings: ${unknown.join(', ')}.', {
        'keys': unknown.join(', '),
      });
    }
    final header = config['header'] ?? tomRequestIdHeader;
    if (header is! String || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(header)) {
      invalid("The request-id 'header' must be a header name, not '$header'.");
    }
    final proxies = config['trustedProxies'] ?? const [];
    if (proxies is! List) {
      invalid("The request-id 'trustedProxies' must be a list of addresses.");
    }
    final trusted = <String>{};
    for (final proxy in proxies) {
      final address = InternetAddress.tryParse('$proxy');
      if (address == null) {
        invalid(
          "'$proxy' in the request-id 'trustedProxies' is not an "
          'IP address.',
          {'address': '$proxy'},
        );
      }
      trusted.add(address.address);
    }
    current = TomRequestIdPolicy(header: header, trustedProxies: trusted);
  }

  /// The id [request] runs under, given the [trace] it is served in.
  TomRequestId resolve(Request request, TomTraceContext trace) {
    final supplied = request.headers[header];
    if (supplied != null && trustedProxies.isNotEmpty) {
      final info = request.context[TomClientAddress.connectionInfoKey];
      final peer = info is HttpConnectionInfo
          ? info.remoteAddress.address
          : null;
      if (peer != null && trustedProxies.contains(peer)) {
        final id = TomRequestId.tryOf(supplied.trim());
        if (id != null) return id;
      }
    }
    return TomRequestId.of(trace.traceId);
  }
}
