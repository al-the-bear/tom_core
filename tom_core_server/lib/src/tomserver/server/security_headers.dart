/// The security headers every response carries unless it sets its own.
///
/// | Header | Default | Why |
/// | ------ | ------- | --- |
/// | `Strict-Transport-Security` | `max-age=31536000; includeSubDomains`, on HTTPS requests only | keeps a browser from ever reaching the host over plain HTTP again |
/// | `Content-Security-Policy` | `default-src 'none'; frame-ancestors 'none'` | an API answers data, not documents: nothing it returns may load, run or be framed |
/// | `X-Content-Type-Options` | `nosniff` | a browser takes the declared media type, never a guessed one |
/// | `X-Frame-Options` | `DENY` | the same framing refusal for browsers that predate CSP |
/// | `Referrer-Policy` | `no-referrer` | no URL of this server leaks into another's logs |
///
/// A header the response already carries is left alone, so an endpoint that
/// serves a page sets its own `Content-Security-Policy`. The
/// [TomSecurityHeaders.contentSecurityPolicyFor] hook chooses the policy per
/// request instead, for a deployment that serves documents under some paths.
/// A setting configured as `""` is not sent.
library;

import 'package:shelf/shelf.dart';

import '../little_things/server_exception.dart';

/// Thrown when the security-header settings cannot be applied.
class TomSecurityHeadersException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomSecurityHeadersException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Chooses the `Content-Security-Policy` of one response; `null` falls back to
/// [TomSecurityHeaders.contentSecurityPolicy].
typedef TomContentSecurityPolicyHook =
    String? Function(Request request, Response response);

/// The security headers a server sends — see the library documentation.
final class TomSecurityHeaders {
  /// The headers with each value as given; `""` leaves a header out.
  const TomSecurityHeaders({
    this.enabled = true,
    this.hstsMaxAgeSeconds = 31536000,
    this.hstsIncludeSubDomains = true,
    this.hstsPreload = false,
    this.contentSecurityPolicy = "default-src 'none'; frame-ancestors 'none'",
    this.contentSecurityPolicyFor,
    this.frameOptions = 'DENY',
    this.referrerPolicy = 'no-referrer',
  });

  /// Whether any security header is sent.
  final bool enabled;

  /// The HSTS `max-age`; `0` sends no `Strict-Transport-Security`.
  final int hstsMaxAgeSeconds;

  /// Whether HSTS covers subdomains.
  final bool hstsIncludeSubDomains;

  /// Whether HSTS asks to be preloaded into browsers.
  final bool hstsPreload;

  /// The default `Content-Security-Policy`.
  final String contentSecurityPolicy;

  /// The per-request policy hook, or `null`.
  final TomContentSecurityPolicyHook? contentSecurityPolicyFor;

  /// `X-Frame-Options`.
  final String frameOptions;

  /// `Referrer-Policy`.
  final String referrerPolicy;

  /// The configuration key holding the settings — see [configure].
  static const String configurationKey = 'securityHeaders';

  /// The settings [tomSecurityHeadersMiddleware] applies, read per request.
  static TomSecurityHeaders current = const TomSecurityHeaders();

  /// Sets [current] from [config], keeping [current]'s CSP hook:
  ///
  /// ```yaml
  /// securityHeaders:
  ///   enabled: true
  ///   hstsMaxAgeSeconds: 31536000
  ///   hstsIncludeSubDomains: true
  ///   hstsPreload: false
  ///   contentSecurityPolicy: "default-src 'none'; frame-ancestors 'none'"
  ///   frameOptions: DENY
  ///   referrerPolicy: no-referrer
  /// ```
  ///
  /// Throws `server.security_headers.config.invalid` for a value of the wrong
  /// shape, before anything is applied.
  static void configure(Object? config) {
    Never invalid(String message) => throw TomSecurityHeadersException(
      'server.security_headers.config.invalid',
      message,
    );
    if (config is! Map) invalid('The security-header settings must be a map.');
    const defaults = TomSecurityHeaders();
    T read<T>(String key, T fallback) {
      if (!config.containsKey(key)) return fallback;
      final value = config[key];
      if (value is! T) invalid("The security-header setting '$key' is a $T.");
      return value;
    }

    final unknown = config.keys
        .map((k) => '$k')
        .where(
          (k) => !const {
            'enabled',
            'hstsMaxAgeSeconds',
            'hstsIncludeSubDomains',
            'hstsPreload',
            'contentSecurityPolicy',
            'frameOptions',
            'referrerPolicy',
          }.contains(k),
        );
    if (unknown.isNotEmpty) {
      invalid('Unknown security-header settings: ${unknown.join(', ')}.');
    }
    final maxAge = read<int>('hstsMaxAgeSeconds', defaults.hstsMaxAgeSeconds);
    if (maxAge < 0) invalid("'hstsMaxAgeSeconds' must not be negative.");
    current = TomSecurityHeaders(
      enabled: read<bool>('enabled', defaults.enabled),
      hstsMaxAgeSeconds: maxAge,
      hstsIncludeSubDomains: read<bool>(
        'hstsIncludeSubDomains',
        defaults.hstsIncludeSubDomains,
      ),
      hstsPreload: read<bool>('hstsPreload', defaults.hstsPreload),
      contentSecurityPolicy: read<String>(
        'contentSecurityPolicy',
        defaults.contentSecurityPolicy,
      ),
      contentSecurityPolicyFor: current.contentSecurityPolicyFor,
      frameOptions: read<String>('frameOptions', defaults.frameOptions),
      referrerPolicy: read<String>('referrerPolicy', defaults.referrerPolicy),
    );
  }

  /// The headers [response] to [request] gains: every configured one it does
  /// not carry already.
  Map<String, String> headersFor(Request request, Response response) {
    if (!enabled) return const {};
    final hsts = request.requestedUri.scheme == 'https' && hstsMaxAgeSeconds > 0
        ? 'max-age=$hstsMaxAgeSeconds'
              '${hstsIncludeSubDomains ? '; includeSubDomains' : ''}'
              '${hstsPreload ? '; preload' : ''}'
        : '';
    final csp =
        contentSecurityPolicyFor?.call(request, response) ??
        contentSecurityPolicy;
    return {
      for (final MapEntry(:key, :value) in {
        'Strict-Transport-Security': hsts,
        'Content-Security-Policy': csp,
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': frameOptions,
        'Referrer-Policy': referrerPolicy,
      }.entries)
        if (value.isNotEmpty && !response.headers.containsKey(key)) key: value,
    };
  }
}

/// A [Middleware] adding [TomSecurityHeaders.current]'s headers to every
/// response, error responses included.
Middleware tomSecurityHeadersMiddleware() =>
    (innerHandler) => (request) async {
      final response = await innerHandler(request);
      final headers = TomSecurityHeaders.current.headersFor(request, response);
      return headers.isEmpty ? response : response.change(headers: headers);
    };
