/// The HTTP side of metrics: the series every request records, and the
/// Prometheus scrape endpoint.
///
/// Both are middleware `TomServer.start` places at the outer edge of the
/// pipeline, ahead of authentication.
///
/// **The scrape is answered before authentication on purpose.** A scrape is
/// infrastructure, like a probe: it has no user, no tenant, and no business
/// being rate-limited, logged as an access, or counted as a request. Answered
/// as an ordinary endpoint it would pass through all of those — and a scraper's
/// bearer token, which is not a JWT, would be logged as a failed sign-in on
/// every scrape. Answered here it checks its own token and nothing else.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../server/server.dart' show TomRequestLogInfo;

/// The route label of a request no endpoint matched.
const String tomUnmatchedRoute = 'unmatched';

TomCounter get _requests => TomMetrics.registry.counter(
  'tom_http_server_requests',
  help: 'HTTP requests answered, by method, route pattern and status.',
);

TomHistogram get _requestDuration => TomMetrics.registry.histogram(
  'tom_http_server_request_duration_seconds',
  help:
      'How long an HTTP request took to answer, by method and route '
      'pattern.',
  unit: 's',
);

/// A [Middleware] recording `tom_http_server_requests` and
/// `tom_http_server_request_duration_seconds` for every request.
///
/// The `route` label is the pattern of the endpoint that served the request —
/// `/tasks/<id>`, never `/tasks/42` — read from the request's
/// [TomRequestLogInfo], where the endpoint pipeline records it. A request no
/// endpoint matched is labelled [tomUnmatchedRoute], so a scan of random paths
/// adds one series rather than one per path.
///
/// Placed outside both error layers, so a request refused during
/// authentication is counted with the status it was answered with. An error
/// that escapes every layer is counted as a `500` and rethrown.
Middleware tomRequestMetricsMiddleware() =>
    (innerHandler) => (request) async {
      final watch = Stopwatch()..start();
      int status;
      try {
        final response = await innerHandler(request);
        status = response.statusCode;
        _record(request, status, watch.elapsed);
        return response;
      } catch (_) {
        _record(request, 500, watch.elapsed);
        rethrow;
      }
    };

void _record(Request request, int status, Duration elapsed) {
  final info = request.context[TomRequestLogInfo.contextName];
  final route = info is TomRequestLogInfo ? info.route : null;
  final labels = {
    'method': request.method,
    'route': route ?? tomUnmatchedRoute,
  };
  _requests.add(1, {...labels, 'status': '$status'});
  _requestDuration.recordDuration(elapsed, labels);
}

/// A [Middleware] answering `GET` [path] with [registry]'s snapshot in the
/// Prometheus text format, and passing every other request on.
///
/// With a non-empty [token], a scrape must present `Authorization: Bearer
/// <token>` — Prometheus' `authorization` or `bearer_token` setting — and is
/// otherwise answered `401` without a body; the comparison takes the same time
/// wherever the presented token differs. Without one the endpoint is open, which
/// is right only where the port is reachable by the scraper alone.
Middleware tomMetricsEndpointMiddleware({
  String path = '/metrics',
  String token = '',
  TomMetricRegistry? registry,
}) {
  final route = path.startsWith('/') ? path.substring(1) : path;
  return (innerHandler) => (request) async {
    if (request.url.path != route ||
        (request.method != 'GET' && request.method != 'HEAD')) {
      return innerHandler(request);
    }
    if (token.isNotEmpty &&
        !_sameSecret(request.headers['authorization'] ?? '', 'Bearer $token')) {
      return Response(401, headers: {'www-authenticate': 'Bearer'});
    }
    final families = await (registry ?? TomMetrics.registry).collect();
    return Response.ok(
      request.method == 'HEAD' ? null : tomPrometheusText(families),
      headers: {'content-type': tomPrometheusContentType},
    );
  };
}

/// Whether [presented] equals [expected], in time that depends on the length
/// of [expected] only.
bool _sameSecret(String presented, String expected) {
  var difference = presented.length ^ expected.length;
  for (var i = 0; i < expected.length; i++) {
    final p = i < presented.length ? presented.codeUnitAt(i) : 0;
    difference |= p ^ expected.codeUnitAt(i);
  }
  return difference == 0;
}
