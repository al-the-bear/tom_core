/// How the delivery-report endpoint tells a carrier's callback from anyone
/// else's request: a shared secret in a header, or the request signature a
/// carrier computes when it cannot add a header of its own.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'message.dart';

/// A carrier callback as a [TomDeliveryCallbackVerifier] sees it: what was
/// requested and what arrived, the body read once.
class TomDeliveryCallbackRequest {
  /// A request; [parameters] are the query parameters and, for a
  /// form-encoded body, its fields.
  TomDeliveryCallbackRequest({
    required this.method,
    required this.url,
    Map<String, String>? headers,
    this.body = '',
    Map<String, String>? parameters,
  }) : headers = Map.unmodifiable({
         for (final entry in (headers ?? const {}).entries)
           entry.key.toLowerCase(): entry.value,
       }),
       parameters = Map.unmodifiable(parameters ?? const {});

  /// The HTTP method.
  final String method;

  /// The URL as this server received it, query included.
  final Uri url;

  /// The request headers, names lowercased.
  final Map<String, String> headers;

  /// The body as text.
  final String body;

  /// The query parameters and, for a form-encoded body, its fields.
  final Map<String, String> parameters;

  /// The value of the header [name], any case.
  String? header(String name) => headers[name.toLowerCase()];

  /// Whether the body is a form (`application/x-www-form-urlencoded`).
  bool get isForm => (header('content-type') ?? '').toLowerCase().startsWith(
    'application/x-www-form-urlencoded',
  );

  /// Whether the body is JSON.
  bool get isJson =>
      (header('content-type') ?? '').toLowerCase().contains('json');
}

/// What gates the delivery-report endpoint: whether a request comes from the
/// carrier.
///
/// The installation chooses one ([TomDeliveryReportEndpoint.install]): a
/// shared secret the carrier presents ([TomSharedSecretCallbackVerifier]), or
/// a carrier's request signature ([TomTwilioCallbackVerifier],
/// [TomVonageCallbackVerifier]). Every comparison is in constant time: the
/// endpoint is public, and an answer that comes back sooner for a wrong first
/// byte gives the secret away a byte at a time.
abstract class TomDeliveryCallbackVerifier {
  /// Const constructor for subclasses.
  const TomDeliveryCallbackVerifier();

  /// Whether [request] comes from the carrier.
  bool verify(TomDeliveryCallbackRequest request);
}

/// Whether [a] and [b] are equal, in time that depends only on their lengths.
bool tomConstantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var difference = x.length ^ y.length;
  for (var i = 0; i < x.length; i++) {
    difference |= x[i] ^ (y.isEmpty ? 0 : y[i % y.length]);
  }
  return difference == 0;
}

/// A callback gated by a shared secret the carrier presents in the header
/// [header] (`x-tom-delivery-secret` by default).
///
/// For a carrier — or a gateway in front of one — that can add a header to its
/// callback. The secret travels with every callback, so it is only as safe as
/// the TLS under it; a carrier that signs its requests is better verified by
/// its signature.
class TomSharedSecretCallbackVerifier extends TomDeliveryCallbackVerifier {
  /// A verifier expecting [secret] in [header]. Refuses an empty [secret]
  /// (`messaging.delivery_report.empty_secret`): it would gate nothing.
  TomSharedSecretCallbackVerifier(String secret, {this.header = defaultHeader})
    : _secret = secret {
    if (_secret.isEmpty) {
      throw TomMessagingException(
        'messaging.delivery_report.empty_secret',
        'The delivery-report endpoint needs a non-empty shared secret; an '
            'empty one gates nothing.',
      );
    }
  }

  /// The header the secret is presented in unless another is named.
  ///
  /// A header rather than a query parameter because a URL is logged by every
  /// proxy between here and the carrier, and a secret in a log is a secret
  /// somebody has to rotate.
  static const String defaultHeader = 'x-tom-delivery-secret';

  /// The header the secret is presented in.
  final String header;

  final String _secret;

  @override
  bool verify(TomDeliveryCallbackRequest request) {
    final presented = request.header(header);
    return presented != null && tomConstantTimeEquals(presented, _secret);
  }

  @override
  String toString() => 'TomSharedSecretCallbackVerifier(header: $header)';
}

/// A Twilio status callback, verified by its `X-Twilio-Signature`.
///
/// Twilio signs every webhook with HMAC-SHA1 under the account's auth token
/// ([authToken]), over the full URL it called — scheme through query string —
/// followed by the POST parameters sorted by name (case-sensitive) with each
/// name and value appended, no delimiters; the signature is base64. A JSON
/// callback is signed over the URL alone, which then carries `bodySHA256`, the
/// hex SHA-256 of the body, checked here too.
///
/// The URL is the one Twilio called, which behind a proxy or load balancer is
/// not the one this server sees: [publicUrl], when set, replaces the scheme,
/// host and port (and a path prefix) of the received URL. Twilio keeps or
/// drops the port depending on the product, so a URL is accepted signed with
/// or without its port.
///
/// Twilio puts no timestamp in the signature, so a captured callback can be
/// replayed; a replayed status report records the same state again, which the
/// correlation index tolerates.
class TomTwilioCallbackVerifier extends TomDeliveryCallbackVerifier {
  /// A verifier for the account whose auth token is [authToken].
  TomTwilioCallbackVerifier(String authToken, {this.publicUrl})
    : _authToken = authToken {
    if (_authToken.isEmpty) {
      throw TomMessagingException(
        'messaging.delivery_report.empty_secret',
        'The Twilio callback verifier needs the account auth token.',
      );
    }
  }

  /// The header Twilio signs a request in.
  static const String signatureHeader = 'x-twilio-signature';

  /// The URL Twilio calls, when it is not the one this server receives —
  /// e.g. `https://api.example.com/` in front of `http://app:8080/`. Its
  /// scheme, host and port replace the received URL's, and its path is put in
  /// front of the received path.
  final Uri? publicUrl;

  final String _authToken;

  /// The signature Twilio computes for [url] and the POST [parameters]
  /// (empty for a JSON callback) under [authToken].
  static String signature(
    String authToken,
    String url,
    Map<String, String> parameters,
  ) {
    final buffer = StringBuffer(url);
    for (final name in parameters.keys.toList()..sort()) {
      buffer
        ..write(name)
        ..write(parameters[name]);
    }
    final mac = Hmac(sha1, utf8.encode(authToken));
    return base64.encode(mac.convert(utf8.encode('$buffer')).bytes);
  }

  /// The URL Twilio called, as far as this request shows it.
  Uri calledUrl(TomDeliveryCallbackRequest request) {
    final public = publicUrl;
    if (public == null) return request.url;
    final prefix = public.path.endsWith('/')
        ? public.path.substring(0, public.path.length - 1)
        : public.path;
    return request.url.replace(
      scheme: public.scheme,
      host: public.host,
      port: public.hasPort ? public.port : null,
      path: '$prefix${request.url.path}',
    );
  }

  @override
  bool verify(TomDeliveryCallbackRequest request) {
    final presented = request.header(signatureHeader);
    if (presented == null || presented.isEmpty) return false;
    final url = calledUrl(request);
    final Map<String, String> signed;
    if (request.isJson) {
      final declared = url.queryParameters['bodySHA256'];
      if (declared == null) return false;
      final actual = sha256.convert(utf8.encode(request.body)).toString();
      if (!tomConstantTimeEquals(declared.toLowerCase(), actual)) return false;
      signed = const {};
    } else {
      // The POST parameters only: the query string is part of the URL.
      signed = request.isForm ? Uri.splitQueryString(request.body) : const {};
    }
    var valid = false;
    // Both spellings are compared, every time, so the answer takes as long
    // whichever matches.
    for (final candidate in _withAndWithoutPort(url)) {
      valid |= tomConstantTimeEquals(
        presented,
        signature(_authToken, candidate, signed),
      );
    }
    return valid;
  }

  /// [url] spelled without a port and with its port — the default port of
  /// its scheme when it names none.
  static List<String> _withAndWithoutPort(Uri url) {
    final rest = '${url.path}${url.hasQuery ? '?${url.query}' : ''}';
    final port = url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80);
    return [
      '${url.scheme}://${url.host}$rest',
      '${url.scheme}://${url.host}:$port$rest',
    ];
  }

  @override
  String toString() => 'TomTwilioCallbackVerifier(publicUrl: $publicUrl)';
}

/// How Vonage signs a request: a salted MD5 hash or an HMAC.
enum TomVonageSignatureMethod {
  /// MD5 over the parameter string followed by the secret; lowercase hex.
  md5hash,

  /// HMAC-MD5; uppercase hex.
  md5,

  /// HMAC-SHA1; uppercase hex.
  sha1,

  /// HMAC-SHA256; uppercase hex.
  sha256,

  /// HMAC-SHA512; uppercase hex.
  sha512,
}

/// A Vonage (SMS API) delivery receipt, verified by its `sig` parameter.
///
/// Vonage signs every parameter but `sig` — `timestamp` included, in UNIX
/// seconds — with the account's signature secret ([method] as configured in
/// the Vonage dashboard): each value with `&` and `=` replaced by `_`, the
/// parameters sorted by name and joined as `&name=value`, then either MD5 over
/// that string followed by the secret (`md5hash`, lowercase hex) or an HMAC of
/// it keyed by the secret (uppercase hex). The parameters are read from the
/// query, a form body or a flat JSON body, whichever the receipt arrived in.
///
/// A receipt whose `timestamp` is further than [maxAge] from now is refused,
/// so a captured receipt cannot be replayed later — Vonage's client libraries
/// allow five minutes, the default here.
class TomVonageCallbackVerifier extends TomDeliveryCallbackVerifier {
  /// A verifier for the account's [signatureSecret], checked with [method].
  TomVonageCallbackVerifier(
    String signatureSecret, {
    this.method = TomVonageSignatureMethod.md5hash,
    this.maxAge = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _signatureSecret = signatureSecret,
       _clock = clock ?? DateTime.now {
    if (_signatureSecret.isEmpty) {
      throw TomMessagingException(
        'messaging.delivery_report.empty_secret',
        'The Vonage callback verifier needs the signature secret.',
      );
    }
  }

  /// The signing method the Vonage account is set to.
  final TomVonageSignatureMethod method;

  /// The furthest a receipt's `timestamp` may be from now.
  final Duration maxAge;

  final String _signatureSecret;
  final DateTime Function() _clock;

  /// The signature Vonage computes for [parameters] (without `sig`) under
  /// [secret] with [method].
  static String signature(
    String secret,
    Map<String, String> parameters, {
    TomVonageSignatureMethod method = TomVonageSignatureMethod.md5hash,
  }) {
    final buffer = StringBuffer();
    for (final name in parameters.keys.toList()..sort()) {
      final value = parameters[name]!.replaceAll(RegExp('[&=]'), '_');
      buffer.write('&$name=$value');
    }
    final text = '$buffer';
    if (method == TomVonageSignatureMethod.md5hash) {
      return md5.convert(utf8.encode('$text$secret')).toString();
    }
    final hash = switch (method) {
      TomVonageSignatureMethod.md5 => md5,
      TomVonageSignatureMethod.sha1 => sha1,
      TomVonageSignatureMethod.sha256 => sha256,
      _ => sha512,
    };
    return Hmac(
      hash,
      utf8.encode(secret),
    ).convert(utf8.encode(text)).toString().toUpperCase();
  }

  /// The signed parameters of [request]: the query and form parameters and,
  /// for a JSON body, its top-level values.
  static Map<String, String> parametersOf(TomDeliveryCallbackRequest request) {
    final parameters = <String, String>{...request.parameters};
    if (request.isJson && request.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(request.body);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value == null || value is Map || value is List) continue;
            parameters['${entry.key}'] = '$value';
          }
        }
      } on FormatException {
        // Unsigned noise; the missing signature refuses it below.
      }
    }
    return parameters;
  }

  @override
  bool verify(TomDeliveryCallbackRequest request) {
    final parameters = parametersOf(request);
    final presented = parameters.remove('sig');
    if (presented == null || presented.isEmpty) return false;
    final timestamp = int.tryParse(parameters['timestamp'] ?? '');
    if (timestamp == null) return false;
    final signedAt = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    if (_clock().toUtc().difference(signedAt).abs() > maxAge) return false;
    final expected = signature(_signatureSecret, parameters, method: method);
    return tomConstantTimeEquals(
      method == TomVonageSignatureMethod.md5hash
          ? presented.toLowerCase()
          : presented.toUpperCase(),
      expected,
    );
  }

  @override
  String toString() =>
      'TomVonageCallbackVerifier(method: ${method.name}, maxAge: $maxAge)';
}
