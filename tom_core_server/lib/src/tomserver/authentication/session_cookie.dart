/// Browser sessions held in a cookie, and the CSRF protection they need.
///
/// A browser client can keep its access token in an `HttpOnly` cookie instead
/// of script-readable storage: [TomSessionCookie.attach] sets it on the
/// response that hands out the token (a login, a refresh), and the
/// authentication middleware reads it from a request that carries no
/// `Authorization` header. A cookie travels with every request the browser
/// sends to the server — including one a hostile page triggers — so a request
/// authenticated by the cookie is held to a CSRF check before it may change
/// anything.
///
/// ## The cookies
///
/// | Cookie | Holds | Attributes |
/// | ------ | ----- | ---------- |
/// | [TomSessionCookie.name] (`tom_session`) | the access token | `HttpOnly; Secure; SameSite=Strict; Path=/` |
/// | [TomSessionCookie.csrfCookieName] (`tom_csrf`) | a random CSRF token | `Secure; SameSite=Strict; Path=/` — readable by the page, which copies it into a header |
///
/// `Secure`, `SameSite` (`Strict`, `Lax` or `None`), `Path` and `Domain` are
/// configured once and apply to both; `SameSite=None` requires `Secure`.
///
/// ## The CSRF check
///
/// A cookie-authenticated request with a method other than `GET`, `HEAD`,
/// `OPTIONS` and `TRACE` must (double-submit):
///
/// - carry [TomSessionCookie.csrfHeader] (`X-CSRF-Token`) equal to the
///   `tom_csrf` cookie, which a page of another origin can neither read nor
///   set; and
/// - when it carries an `Origin`, come from the server's own origin or from
///   one the CORS policy admits.
///
/// Otherwise it is refused with `403`, `authentication.csrf.rejected`. A
/// request authenticated by an `Authorization` header or an API key is not
/// checked: a browser never attaches those by itself.
library;

import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

import '../endpoints/cors.dart';
import '../little_things/server_exception.dart';

/// Thrown when the session-cookie settings cannot be applied, and when a
/// cookie-authenticated request fails the CSRF check.
class TomSessionCookieException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomSessionCookieException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

/// The `SameSite` attribute of the session cookies.
enum TomSameSite {
  /// Sent only on requests from the server's own site.
  strict('Strict'),

  /// Also sent on top-level navigations from other sites.
  lax('Lax'),

  /// Sent on every request; requires `Secure`.
  none('None');

  const TomSameSite(this.attribute);

  /// The attribute value as it is written in `Set-Cookie`.
  final String attribute;
}

/// The session cookies and their CSRF check — see the library documentation.
final class TomSessionCookie {
  /// Session cookies named [name] and [csrfCookieName] with the given
  /// attributes.
  const TomSessionCookie({
    this.name = 'tom_session',
    this.csrfCookieName = 'tom_csrf',
    this.csrfHeader = 'X-CSRF-Token',
    this.path = '/',
    this.domain,
    this.sameSite = TomSameSite.strict,
    this.secure = true,
  });

  /// The cookie holding the access token.
  final String name;

  /// The cookie holding the CSRF token.
  final String csrfCookieName;

  /// The request header the CSRF token is echoed in.
  final String csrfHeader;

  /// The `Path` of both cookies.
  final String path;

  /// The `Domain` of both cookies, or `null` for the host alone.
  final String? domain;

  /// The `SameSite` of both cookies.
  final TomSameSite sameSite;

  /// Whether both cookies are `Secure` (sent over HTTPS only).
  final bool secure;

  /// The configuration key holding the settings — see [configure].
  static const String configurationKey = 'sessionCookie';

  /// The installed settings, or `null` when no request is authenticated by a
  /// cookie.
  static TomSessionCookie? current;

  /// Installs [current] from [config]:
  ///
  /// ```yaml
  /// sessionCookie:
  ///   name: tom_session
  ///   csrfCookieName: tom_csrf
  ///   csrfHeader: X-CSRF-Token
  ///   path: /
  ///   domain: example.com        # optional
  ///   sameSite: Strict           # Strict | Lax | None
  ///   secure: true
  /// ```
  ///
  /// Throws `authentication.session_cookie.config.invalid` for a value of the
  /// wrong shape — among them `SameSite=None` without `Secure` — before
  /// anything is applied.
  static void configure(Object? config) {
    Never invalid(String message) => throw TomSessionCookieException(
      'authentication.session_cookie.config.invalid',
      message,
    );
    if (config is! Map) invalid('The session-cookie settings must be a map.');
    const defaults = TomSessionCookie();
    final known = {
      'name',
      'csrfCookieName',
      'csrfHeader',
      'path',
      'domain',
      'sameSite',
      'secure',
    };
    final unknown = config.keys
        .map((k) => '$k')
        .where((k) => !known.contains(k));
    if (unknown.isNotEmpty) {
      invalid('Unknown session-cookie settings: ${unknown.join(', ')}.');
    }
    String text(String key, String fallback) {
      final value = config[key] ?? fallback;
      if (value is! String || !_token.hasMatch(value)) {
        invalid("The session-cookie setting '$key' is not a valid token.");
      }
      return value;
    }

    final path = config['path'] ?? defaults.path;
    if (path is! String || !path.startsWith('/') || path.contains(';')) {
      invalid("The session-cookie 'path' must start with '/'.");
    }
    final domain = config['domain'];
    if (domain != null && (domain is! String || !_domain.hasMatch(domain))) {
      invalid("The session-cookie 'domain' is not a host name.");
    }
    final sameSiteName = '${config['sameSite'] ?? 'Strict'}'.toLowerCase();
    final sameSite = TomSameSite.values
        .where((value) => value.name == sameSiteName)
        .firstOrNull;
    if (sameSite == null) invalid("'sameSite' is Strict, Lax or None.");
    final secure = config['secure'] ?? true;
    if (secure is! bool) invalid("'secure' must be a boolean.");
    if (sameSite == TomSameSite.none && !secure) {
      invalid('SameSite=None cookies must be Secure.');
    }
    current = TomSessionCookie(
      name: text('name', defaults.name),
      csrfCookieName: text('csrfCookieName', defaults.csrfCookieName),
      csrfHeader: text('csrfHeader', defaults.csrfHeader),
      path: path,
      domain: domain as String?,
      sameSite: sameSite,
      secure: secure,
    );
  }

  static final RegExp _token = RegExp(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$");
  static final RegExp _domain = RegExp(r'^[A-Za-z0-9.-]+$');
  static final Random _random = Random.secure();

  /// [response] setting the session cookie to [accessToken] and a fresh CSRF
  /// token, both expiring after [maxAge] (a browser session when `null`).
  Response attach(Response response, String accessToken, {Duration? maxAge}) {
    final csrf = base64Url
        .encode(List<int>.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    return _withCookies(response, [
      _cookie(name, accessToken, httpOnly: true, maxAge: maxAge),
      _cookie(csrfCookieName, csrf, httpOnly: false, maxAge: maxAge),
    ]);
  }

  /// [response] deleting both cookies — a logout.
  Response clear(Response response) => _withCookies(response, [
    _cookie(name, '', httpOnly: true, maxAge: Duration.zero),
    _cookie(csrfCookieName, '', httpOnly: false, maxAge: Duration.zero),
  ]);

  /// The access token [request]'s session cookie holds, or `null`.
  String? tokenOf(Request request) => cookiesOf(request)[name];

  /// The cookies of [request], by name.
  static Map<String, String> cookiesOf(Request request) {
    final header = request.headers['cookie'];
    if (header == null) return const {};
    return {
      for (final pair in header.split(';'))
        if (pair.contains('='))
          pair.substring(0, pair.indexOf('=')).trim(): pair
              .substring(pair.indexOf('=') + 1)
              .trim(),
    };
  }

  /// Throws `authentication.csrf.rejected` unless the cookie-authenticated
  /// [request] passes the CSRF check (see the library documentation); a safe
  /// method always passes.
  void checkCsrf(Request request) {
    if (const {'GET', 'HEAD', 'OPTIONS', 'TRACE'}.contains(request.method)) {
      return;
    }
    final cookie = cookiesOf(request)[csrfCookieName];
    final header = request.headers[csrfHeader];
    String? reason;
    if (cookie == null || cookie.isEmpty || header == null) {
      reason = 'missing_token';
    } else if (!_constantTimeEquals(cookie, header)) {
      reason = 'token_mismatch';
    } else {
      final origin = request.headers['origin'];
      if (origin != null &&
          origin != _ownOrigin(request) &&
          !TomCors.current.admits(origin)) {
        reason = 'foreign_origin';
      }
    }
    if (reason != null) {
      throw TomSessionCookieException(
        'authentication.csrf.rejected',
        'The request was refused: it is authenticated by a session cookie '
            'and failed the CSRF check.',
        parameters: {'reason': reason},
        clientThrow: true,
      );
    }
  }

  static String _ownOrigin(Request request) {
    final uri = request.requestedUri;
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    return uri.port == defaultPort
        ? '${uri.scheme}://${uri.host}'
        : '${uri.scheme}://${uri.host}:${uri.port}';
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  String _cookie(
    String cookieName,
    String value, {
    required bool httpOnly,
    Duration? maxAge,
  }) => [
    '$cookieName=$value',
    'Path=$path',
    if (domain != null) 'Domain=$domain',
    if (maxAge != null) 'Max-Age=${maxAge.inSeconds}',
    if (secure) 'Secure',
    if (httpOnly) 'HttpOnly',
    'SameSite=${sameSite.attribute}',
  ].join('; ');

  static Response _withCookies(Response response, List<String> cookies) {
    final existing = response.headersAll['set-cookie'] ?? const <String>[];
    return response.change(
      headers: {
        'set-cookie': [...existing, ...cookies],
      },
    );
  }
}
