/// AWS Signature Version 4 — the request signing every S3-compatible object
/// store speaks.
///
/// Separated from the store that uses it because signing is a pure function of
/// a request and a key, and pure functions are the part of an integration that
/// can actually be *tested*: the algorithm is published with official test
/// vectors, so this file is verified against them rather than against a live
/// bucket. Whatever remains uncertain about talking to a real object store, the
/// signature is not part of it.
///
/// The scheme (AWS docs, "Signature Version 4 signing process") is three
/// derivations chained together:
///
/// 1. a **canonical request** — the method, path, query, the signed headers and
///    the payload hash, each normalised so that client and server can agree on
///    the bytes being signed;
/// 2. a **string to sign** — the algorithm, timestamp, credential scope, and the
///    hash of (1);
/// 3. a **signing key** derived from the secret by HMAC-ing the date, region,
///    service and a terminator in turn, so a leaked signing key is scoped to one
///    day, region and service rather than to the account.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The credentials a signer presents.
class TomAwsCredentials {
  /// Creates a credential pair, optionally with a session [sessionToken] for
  /// temporary (STS / instance-role) credentials.
  const TomAwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  /// The public key id.
  final String accessKeyId;

  /// The secret used to derive the signing key. Never transmitted.
  final String secretAccessKey;

  /// The session token accompanying temporary credentials, or `null`.
  final String? sessionToken;
}

/// Signs HTTP requests with AWS Signature Version 4.
class TomAwsV4Signer {
  /// Creates a signer for [region] and [service] (`s3` for object storage).
  const TomAwsV4Signer({
    required this.credentials,
    required this.region,
    this.service = 's3',
  });

  /// The credentials to sign with.
  final TomAwsCredentials credentials;

  /// The region the credential scope names, e.g. `eu-central-1`.
  final String region;

  /// The service the credential scope names.
  final String service;

  /// The algorithm identifier that opens the string to sign.
  static const String algorithm = 'AWS4-HMAC-SHA256';

  /// The payload hash to send when the body is not hashed in advance.
  ///
  /// Permitted by S3 over TLS. This store hashes its (buffered) bodies instead,
  /// so the constant is here for a caller that genuinely cannot.
  static const String unsignedPayload = 'UNSIGNED-PAYLOAD';

  /// The SHA-256 of the empty string — the payload hash of every bodyless
  /// request, precomputed because it appears in most of them.
  static const String emptyPayloadHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  /// Returns the headers to send with a signed request.
  ///
  /// [headers] are the request's own headers (`content-type`, `x-amz-meta-*`,
  /// …); the returned map is those plus `host`, `x-amz-date`,
  /// `x-amz-content-sha256`, the optional `x-amz-security-token`, and
  /// `authorization`. [payloadHash] is the hex SHA-256 of the body, or
  /// [unsignedPayload].
  ///
  /// [now] is injectable so a test can assert against a published vector; it
  /// defaults to the current UTC time.
  Map<String, String> signedHeaders({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();
    final amzDate = _amzDate(timestamp);
    final dateStamp = amzDate.substring(0, 8);

    final all = <String, String>{
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
      'host': _hostHeader(uri),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      if (credentials.sessionToken != null)
        'x-amz-security-token': credentials.sessionToken!,
    };

    final signedNames = all.keys.toList()..sort();
    final canonicalHeaders = [
      for (final name in signedNames) '$name:${_trimAll(all[name]!)}\n',
    ].join();
    final signedHeaderList = signedNames.join(';');

    final canonicalRequest = [
      method.toUpperCase(),
      canonicalPath(uri),
      canonicalQuery(uri),
      canonicalHeaders,
      signedHeaderList,
      payloadHash,
    ].join('\n');

    final scope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = [
      algorithm,
      amzDate,
      scope,
      _hex(sha256.convert(utf8.encode(canonicalRequest)).bytes),
    ].join('\n');

    final signature = _hex(
      _hmac(signingKey(dateStamp), utf8.encode(stringToSign)),
    );

    return {
      ...all,
      'authorization': '$algorithm '
          'Credential=${credentials.accessKeyId}/$scope, '
          'SignedHeaders=$signedHeaderList, '
          'Signature=$signature',
    };
  }

  /// The date-scoped signing key for [dateStamp] (`YYYYMMDD`).
  List<int> signingKey(String dateStamp) {
    var key = _hmac(
      utf8.encode('AWS4${credentials.secretAccessKey}'),
      utf8.encode(dateStamp),
    );
    key = _hmac(key, utf8.encode(region));
    key = _hmac(key, utf8.encode(service));
    return _hmac(key, utf8.encode('aws4_request'));
  }

  /// The canonical (percent-encoded, slash-preserving) path of [uri].
  ///
  /// An empty path canonicalises to `/`; every segment is encoded with the
  /// unreserved-character set, which is stricter than [Uri]'s own encoding and
  /// is what the server re-derives when it checks the signature.
  static String canonicalPath(Uri uri) {
    if (uri.pathSegments.isEmpty) return '/';
    return '/${uri.pathSegments.map(encodeRfc3986).join('/')}';
  }

  /// The canonical query string of [uri]: every parameter encoded and sorted,
  /// values included even when empty (`?uploads` signs as `uploads=`).
  static String canonicalQuery(Uri uri) {
    final parameters = <MapEntry<String, String>>[
      for (final entry in uri.queryParameters.entries)
        MapEntry(encodeRfc3986(entry.key), encodeRfc3986(entry.value)),
    ]..sort((a, b) => a.key == b.key
        ? a.value.compareTo(b.value)
        : a.key.compareTo(b.key));
    return parameters.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Percent-encodes [value] leaving only the RFC 3986 unreserved characters.
  ///
  /// Dart's [Uri.encodeComponent] leaves `!`, `*`, `'`, `(` and `)` alone;
  /// SigV4 requires them encoded, and a key containing one would otherwise
  /// produce a signature the server rejects with no useful diagnostic.
  static String encodeRfc3986(String value) {
    final encoded = Uri.encodeComponent(value);
    return encoded
        .replaceAll('!', '%21')
        .replaceAll('*', '%2A')
        .replaceAll("'", '%27')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29');
  }

  /// The hex SHA-256 of [payload] — the payload hash of a signed body.
  static String hashPayload(List<int> payload) =>
      _hex(sha256.convert(payload).bytes);

  static String _hostHeader(Uri uri) =>
      uri.hasPort && !_isDefaultPort(uri) ? '${uri.host}:${uri.port}' : uri.host;

  static bool _isDefaultPort(Uri uri) =>
      (uri.scheme == 'https' && uri.port == 443) ||
      (uri.scheme == 'http' && uri.port == 80);

  /// Collapses runs of spaces and trims — the header-value normalisation the
  /// canonical request requires.
  static String _trimAll(String value) =>
      value.trim().replaceAll(RegExp(r' +'), ' ');

  static List<int> _hmac(List<int> key, List<int> data) =>
      Hmac(sha256, key).convert(data).bytes;

  static String _hex(List<int> bytes) =>
      [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

  /// Formats [timestamp] as the `YYYYMMDDTHHMMSSZ` stamp SigV4 uses.
  static String _amzDate(DateTime timestamp) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${timestamp.year.toString().padLeft(4, '0')}'
        '${two(timestamp.month)}${two(timestamp.day)}T'
        '${two(timestamp.hour)}${two(timestamp.minute)}${two(timestamp.second)}Z';
  }
}
