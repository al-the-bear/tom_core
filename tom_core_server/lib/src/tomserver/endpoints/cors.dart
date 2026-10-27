/// Which browser origins may call the server: an allow-list, empty by default.
///
/// A request from a browser page on another origin is answered with
/// `Access-Control-Allow-Origin: <that origin>` (and `Vary: Origin`) only when
/// the origin is on [TomCors.allowedOrigins]; any other origin gets no such
/// header, and the browser withholds the response from the page. With an
/// empty list — the default — no cross-origin page may read anything; a
/// request from the server's own origin, or from a client that is not a
/// browser, is unaffected either way.
///
/// An entry is an exact origin (`https://app.example.com`), an origin with any
/// port (`http://localhost:*`), or `*` for every origin. `*` is answered as
/// `*` — never as the caller's origin — and so cannot be combined with
/// [TomCors.allowCredentials], which browsers refuse with `*` anyway.
/// An endpoint's `corsAllowedOrigins` replaces the list for that endpoint; it
/// is a comma-separated list in the same form.
library;

import 'package:shelf/shelf.dart';

import '../little_things/server_exception.dart';

/// Thrown when the CORS settings cannot be applied.
class TomCorsException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomCorsException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// The cross-origin policy — see the library documentation.
final class TomCors {
  /// A policy admitting [allowedOrigins].
  const TomCors({
    this.allowedOrigins = const [],
    this.allowedMethods = defaultAllowedMethods,
    this.allowedHeaders = defaultAllowedHeaders,
    this.allowCredentials = false,
    this.maxAgeSeconds = 600,
  });

  /// The `Access-Control-Allow-Methods` a preflight answers by default.
  static const String defaultAllowedMethods =
      'GET, POST, PUT, PATCH, DELETE, HEAD';

  /// The `Access-Control-Allow-Headers` a preflight answers by default: what
  /// the framework's own clients send.
  static const String defaultAllowedHeaders =
      'Origin, Content-Type, Accept, Authorization, X-API-Key, X-CSRF-Token, '
      'X-Request-Id, Idempotency-Key, traceparent, tracestate';

  /// The origins admitted; see the library documentation for the forms.
  final List<String> allowedOrigins;

  /// The methods a preflight admits.
  final String allowedMethods;

  /// The request headers a preflight admits.
  final String allowedHeaders;

  /// Whether a browser may send cookies cross-origin
  /// (`Access-Control-Allow-Credentials: true`).
  final bool allowCredentials;

  /// How long a browser may cache a preflight answer.
  final int maxAgeSeconds;

  /// The configuration key holding the settings — see [configure].
  static const String configurationKey = 'cors';

  /// The policy the endpoint pipeline applies, read per request.
  static TomCors current = const TomCors();

  /// Sets [current] from [config]:
  ///
  /// ```yaml
  /// cors:
  ///   allowedOrigins: [https://app.example.com, http://localhost:*]
  ///   allowedMethods: GET, POST, PUT, PATCH, DELETE, HEAD
  ///   allowedHeaders: Origin, Content-Type, Accept, Authorization
  ///   allowCredentials: false
  ///   maxAgeSeconds: 600
  /// ```
  ///
  /// Throws `endpoint.cors.config.invalid` for a value of the wrong shape —
  /// among them an origin that is not `scheme://host[:port|:*]`, and `*`
  /// together with `allowCredentials` — before anything is applied.
  static void configure(Object? config) {
    Never invalid(String message) =>
        throw TomCorsException('endpoint.cors.config.invalid', message);
    if (config is! Map) invalid('The CORS settings must be a map.');
    final unknown = config.keys
        .map((k) => '$k')
        .where(
          (k) => !const {
            'allowedOrigins',
            'allowedMethods',
            'allowedHeaders',
            'allowCredentials',
            'maxAgeSeconds',
          }.contains(k),
        );
    if (unknown.isNotEmpty) {
      invalid('Unknown CORS settings: ${unknown.join(', ')}.');
    }
    final origins = config['allowedOrigins'] ?? const [];
    if (origins is! List) invalid("'allowedOrigins' must be a list.");
    for (final origin in origins) {
      if (origin is! String || !_isPattern(origin)) {
        invalid("'$origin' is not an origin (scheme://host[:port]).");
      }
    }
    final credentials = config['allowCredentials'] ?? false;
    if (credentials is! bool) invalid("'allowCredentials' must be a boolean.");
    if (credentials && origins.contains('*')) {
      invalid("'*' cannot be combined with 'allowCredentials'.");
    }
    final maxAge = config['maxAgeSeconds'] ?? 600;
    if (maxAge is! int || maxAge < 0) {
      invalid("'maxAgeSeconds' must be a whole number of seconds.");
    }
    final methods = config['allowedMethods'] ?? defaultAllowedMethods;
    final headers = config['allowedHeaders'] ?? defaultAllowedHeaders;
    if (methods is! String || headers is! String) {
      invalid(
        "'allowedMethods' and 'allowedHeaders' are comma-separated "
        'strings.',
      );
    }
    current = TomCors(
      allowedOrigins: [for (final origin in origins) origin as String],
      allowedMethods: methods,
      allowedHeaders: headers,
      allowCredentials: credentials,
      maxAgeSeconds: maxAge,
    );
  }

  static final RegExp _originPattern = RegExp(
    r'^[a-z][a-z0-9+.-]*://[^/:\s]+(:(\d+|\*))?$',
  );

  static bool _isPattern(String origin) =>
      origin == '*' || _originPattern.hasMatch(origin);

  /// Whether [origin] is admitted by [patterns] (by default
  /// [allowedOrigins]).
  bool admits(String origin, [List<String>? patterns]) {
    for (final pattern in patterns ?? allowedOrigins) {
      if (pattern == '*' || pattern == origin) return true;
      if (pattern.endsWith(':*')) {
        final base = pattern.substring(0, pattern.length - 2);
        if (origin == base ||
            (origin.startsWith('$base:') &&
                int.tryParse(origin.substring(base.length + 1)) != null)) {
          return true;
        }
      }
    }
    return false;
  }

  /// The `Access-Control-Allow-*` headers [request] is answered with: none
  /// unless its `Origin` is admitted. [endpointOrigins] is an endpoint's own
  /// comma-separated list, replacing [allowedOrigins]; [preflight] adds the
  /// methods, headers and max-age a preflight answers.
  Map<String, String> headersFor(
    Request request, {
    String? endpointOrigins,
    String? endpointMethods,
    String? endpointHeaders,
    bool preflight = false,
  }) {
    final origin = request.headers['origin'];
    if (origin == null) return const {};
    final patterns = endpointOrigins
        ?.split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (!admits(origin, patterns)) return const {};
    final any = (patterns ?? allowedOrigins).contains('*');
    return {
      'Access-Control-Allow-Origin': any ? '*' : origin,
      if (!any) 'Vary': 'Origin',
      if (allowCredentials && !any) 'Access-Control-Allow-Credentials': 'true',
      if (preflight) ...{
        'Access-Control-Allow-Methods': endpointMethods ?? allowedMethods,
        'Access-Control-Allow-Headers': endpointHeaders ?? allowedHeaders,
        'Access-Control-Max-Age': '$maxAgeSeconds',
      },
    };
  }
}
