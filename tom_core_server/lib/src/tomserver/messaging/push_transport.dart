/// Push notifications over an HTTP push service — FCM, APNs, or one a
/// deployment describes itself.
///
/// ## The shape: the SMS gateway's, with the vendors written down
///
/// [TomPushTransport] owns everything a push service has in common: one request
/// per device token, the classification of every answer as delivered,
/// permanently refused or deferred, and the refresh of a credential the service
/// has stopped accepting. What differs between services — the URL, where the
/// token, title and body go, and which error codes mean what — is a
/// [TomPushProtocol]: field names in, status and error paths out, the mapping
/// [TomFieldMappedSmsProtocol] makes for SMS gateways.
///
/// Unlike SMS, two push services cover nearly every device there is, so both
/// ship as protocols of their own:
///
/// | Protocol | Service | Credential |
/// |----------|---------|------------|
/// | [TomFcmPushProtocol] | Firebase Cloud Messaging, HTTP v1 API | [TomFcmServiceAccountCredential] — an OAuth access token minted from a service-account key |
/// | [TomApnsPushProtocol] | Apple Push Notification service | [TomApnsProviderToken] — an ES256 provider token signed with a `.p8` key |
/// | [TomFieldMappedPushProtocol] | any other JSON push API | [TomStaticPushCredential], or a [TomPushCredential] of the deployment's own |
///
/// Both vendor protocols are built from the vendors' published request and
/// error formats and are tested against scripted answers in those formats. No
/// test here reaches the live services, which need a registered app and a real
/// device; a deployment's first live send is the check this repository cannot
/// make.
///
/// ## Classification
///
/// The SMS rule, in two layers. The protocol reads the vendor's error code and
/// says whether it is permanent, transient or a credential the service
/// rejected; a code it does not know falls back to the HTTP status, so a
/// `5xx` is deferred and a `4xx` is final. A **permanent** answer refuses that
/// one device token and the message goes on to the next, so a dead token —
/// an uninstalled app, the commonest refusal in push — appears in
/// [TomDeliveryReceipt.rejectedRecipients], which is how the application learns
/// to forget it. A **transient** answer stops the pass and defers the message,
/// because a rate limit applies to the account rather than to one device.
///
/// A **rejected credential** — an expired access token or provider token — is
/// neither. The transport discards the cached credential, mints a new one and
/// submits once more; a second rejection fails the message permanently under
/// `messaging.push.credential_rejected`, because a credential refused twice in
/// a row is a configuration fault that no retry will cure.
///
/// ## HTTP/2
///
/// APNs speaks only HTTP/2 and `dart:io`'s client only HTTP/1.1, so the wire
/// is a [TomPushExchange] chosen by [TomPushProtocol.requiresHttp2]:
/// [TomHttp2PushExchange] keeps one long-lived HTTP/2 connection per host, as
/// Apple asks, and [TomHttp1PushExchange] runs over the kernel call layer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:http2/transport.dart' as h2;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'message.dart';
import 'message_transport.dart';
import 'vendor_mapping.dart';

// =============================================================================
// WIRE VALUES
// =============================================================================

/// One notification to one device, as a protocol sees it.
class TomPushSubmission {
  /// The message this submission belongs to, for the error parameters.
  final String messageId;

  /// The device token — [TomRecipient.address] on this channel.
  final String token;

  /// The notification's title; `null` sends a body-only notification.
  final String? title;

  /// The notification's text.
  final String body;

  /// Key/value pairs delivered to the app alongside the notification.
  ///
  /// Strings only, because FCM accepts nothing else in its `data` block and a
  /// value that is a string in one protocol and a number in the other is a
  /// difference the app would have to know about.
  final Map<String, String> data;

  /// Creates a submission.
  const TomPushSubmission({
    required this.messageId,
    required this.token,
    required this.body,
    this.title,
    this.data = const {},
  });
}

/// One HTTP request a protocol asks the transport to make.
///
/// A value rather than a call, so [TomPushProtocol.encode] stays pure and a
/// test can read what would be sent without anything being sent.
class TomPushGatewayRequest {
  /// Where to send it.
  final Uri url;

  /// The HTTP method.
  final String method;

  /// The request headers, credential included.
  final Map<String, String> headers;

  /// The request body.
  final String body;

  /// Creates a request.
  const TomPushGatewayRequest({
    required this.url,
    required this.body,
    this.method = 'POST',
    this.headers = const {},
  });
}

/// What the push service answered, before any protocol has read it.
class TomPushGatewayResponse {
  /// The HTTP status.
  final int statusCode;

  /// The response headers, names lowercased.
  ///
  /// APNs answers a success with an empty body and the notification's id in
  /// the `apns-id` header, so a protocol needs the headers to report it.
  final Map<String, String> headers;

  /// The response body.
  final String body;

  /// Creates a response; header names are lowercased here so no protocol has
  /// to.
  TomPushGatewayResponse(
    this.statusCode,
    this.body, {
    Map<String, String> headers = const {},
  }) : headers = {
         for (final entry in headers.entries)
           entry.key.toLowerCase(): entry.value,
       };
}

/// A protocol's reading of one [TomPushGatewayResponse].
class TomPushGatewayAnswer {
  /// Whether the service took the notification.
  final bool isAccepted;

  /// The service's id for the notification, when it gave one.
  final String? remoteId;

  /// A short human-readable account, for the receipt and the error.
  final String? detail;

  /// `true` permanent, `false` transient, `null` "the code says nothing
  /// either way" — then the transport decides from the HTTP status.
  final bool? isPermanent;

  /// Whether the service refused the *credential* rather than the
  /// notification: the transport refreshes it and submits once more.
  final bool isCredentialRejected;

  /// The vendor's error code, when it gave one.
  final String? providerCode;

  /// Creates an answer.
  const TomPushGatewayAnswer({
    required this.isAccepted,
    this.remoteId,
    this.detail,
    this.isPermanent,
    this.isCredentialRejected = false,
    this.providerCode,
  });

  /// The service took the notification.
  const TomPushGatewayAnswer.accepted({this.remoteId, this.detail})
    : isAccepted = true,
      isPermanent = null,
      isCredentialRejected = false,
      providerCode = null;

  /// The service refused it.
  const TomPushGatewayAnswer.rejected({
    bool? permanent,
    this.isCredentialRejected = false,
    this.detail,
    this.providerCode,
  }) : isAccepted = false,
       remoteId = null,
       isPermanent = permanent;

  @override
  String toString() =>
      'TomPushGatewayAnswer(${isAccepted ? 'accepted' : 'rejected'}'
      '${providerCode == null ? '' : ', code $providerCode'})';
}

// =============================================================================
// EXCHANGE
// =============================================================================

/// Performs one [TomPushGatewayRequest] and returns what came back.
///
/// The seam between the protocol and the wire, so the whole classification can
/// be tested against a scripted service and so the HTTP version is a choice
/// rather than an accident of the client.
abstract class TomPushExchange {
  /// Const constructor for subclasses.
  const TomPushExchange();

  /// Sends [request]. Any exception it throws is treated by the transport as
  /// the service being unreachable.
  Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request);

  /// Releases whatever connections the exchange holds.
  Future<void> close() async {}
}

/// An HTTP/1.1 exchange over the kernel call layer — FCM and most others.
class TomHttp1PushExchange extends TomPushExchange {
  /// The client factory handed to every channel, or `null` for the default;
  /// injectable so a test can script the service.
  final TomHttpClientAbstractFactory? clientFactory;

  final Map<String, TomServerChannel> _channels = {};

  /// Creates the exchange.
  TomHttp1PushExchange({this.clientFactory});

  @override
  Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request) async {
    final channel = _channels.putIfAbsent(
      '${request.url.scheme}://${request.url.authority}',
      () => TomServerChannel.forUri(request.url, clientFactory: clientFactory),
    );
    final call = channel.prepareCall(
      TomServerCallSpecs(
        request.method,
        request.url,
        headers: request.headers,
        // The kernel call layer injects the *caller's* bearer token by
        // default. A push service has no idea what that is, and presenting it
        // would hand a user credential to a third party.
        includeBearerAuthentication: false,
      ),
    );
    call.send(TomServerCallLoad(stringBody: request.body));
    // Order matters: reading the body consumes the stream, and the status and
    // headers are only readable before that.
    final status = await call.getResponseStatusCode();
    final headers = await call.getResponseHeaders();
    return TomPushGatewayResponse(
      status,
      await call.readAsString(utf8),
      headers: headers,
    );
  }

  @override
  Future<void> close() async {
    for (final channel in _channels.values) {
      channel.close();
    }
    _channels.clear();
  }
}

/// An HTTP/2 exchange, keeping one connection per host — what APNs requires.
///
/// Apple asks providers to hold connections open rather than open one per
/// notification, and treats a burst of new connections as an attack. So the
/// connection is opened on the first request to a host and reused until it
/// closes or [close] is called.
class TomHttp2PushExchange extends TomPushExchange {
  /// Opens the socket for [url]'s host. Defaults to TLS with ALPN `h2`;
  /// injectable so a test can serve plain-text HTTP/2 on a local port.
  final Future<Socket> Function(Uri url) connect;

  final Map<String, Future<h2.ClientTransportConnection>> _connections = {};

  /// Creates the exchange.
  TomHttp2PushExchange({Future<Socket> Function(Uri url)? connect})
    : connect = connect ?? _secureConnect;

  static Future<Socket> _secureConnect(Uri url) => SecureSocket.connect(
    url.host,
    url.hasPort ? url.port : 443,
    supportedProtocols: const ['h2'],
  );

  @override
  Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request) async {
    final connection = await _connectionFor(request.url);
    final stream = connection.makeRequest([
      h2.Header.ascii(':method', request.method),
      h2.Header.ascii(':scheme', request.url.scheme),
      h2.Header.ascii(':authority', request.url.authority),
      h2.Header.ascii(
        ':path',
        request.url.hasQuery
            ? '${request.url.path}?${request.url.query}'
            : request.url.path,
      ),
      // HTTP/2 header names are lowercase on the wire; an uppercase one is a
      // protocol error the peer answers by resetting the stream.
      for (final header in request.headers.entries)
        h2.Header(
          ascii.encode(header.key.toLowerCase()),
          utf8.encode(header.value),
        ),
    ]);
    stream.sendData(utf8.encode(request.body), endStream: true);

    var status = 0;
    final headers = <String, String>{};
    final body = BytesBuilder(copy: false);
    await for (final message in stream.incomingMessages) {
      if (message is h2.HeadersStreamMessage) {
        for (final header in message.headers) {
          final name = ascii.decode(header.name);
          final value = utf8.decode(header.value);
          if (name == ':status') {
            status = int.parse(value);
          } else {
            headers[name] = value;
          }
        }
      } else if (message is h2.DataStreamMessage) {
        body.add(message.bytes);
      }
    }
    return TomPushGatewayResponse(
      status,
      utf8.decode(body.takeBytes()),
      headers: headers,
    );
  }

  Future<h2.ClientTransportConnection> _connectionFor(Uri url) async {
    final key = '${url.scheme}://${url.authority}';
    final existing = _connections[key];
    if (existing != null) {
      final open = await existing;
      if (open.isOpen) return open;
      unawaited(_connections.remove(key));
    }
    final opening = connect(
      url,
    ).then((socket) => h2.ClientTransportConnection.viaSocket(socket));
    _connections[key] = opening;
    try {
      return await opening;
    } catch (_) {
      // A failed connect must not be cached, or every later send would fail
      // on the same dead future.
      unawaited(_connections.remove(key));
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    final pending = _connections.values.toList();
    _connections.clear();
    for (final connection in pending) {
      try {
        await (await connection).finish();
      } catch (_) {
        // Closing a connection that never opened, or that the peer already
        // dropped, has nothing left to release.
      }
    }
  }
}

// =============================================================================
// CREDENTIALS
// =============================================================================

/// Supplies the bearer token a push service authenticates with.
abstract class TomPushCredential {
  /// Const constructor for subclasses.
  const TomPushCredential();

  /// The current token, minting one when there is none or it has expired.
  Future<String> token();

  /// Discards the cached token, so the next [token] mints a fresh one.
  ///
  /// Called when the service rejects the credential. A no-op for a credential
  /// that cannot be refreshed.
  void invalidate() {}
}

/// A token the deployment already has — a server key, a long-lived API token.
class TomStaticPushCredential extends TomPushCredential {
  final String _token;

  /// Wraps [token].
  const TomStaticPushCredential(String token) : _token = token;

  @override
  Future<String> token() async => _token;

  @override
  String toString() => 'TomStaticPushCredential(<redacted>)';
}

/// The APNs provider token: a JWT signed with ES256 over a `.p8` key.
///
/// Apple rejects a token older than an hour and one refreshed more often than
/// every twenty minutes, so it is cached for [lifetime] — fifty minutes by
/// default, inside both bounds.
class TomApnsProviderToken extends TomPushCredential {
  /// The ten-character Team ID from the developer account.
  final String teamId;

  /// The ten-character Key ID of the `.p8` key.
  final String keyId;

  /// How long a minted token is reused.
  final Duration lifetime;

  /// The clock; injectable for tests.
  final DateTime Function() now;

  final jwt.ECPrivateKey _key;

  String? _token;
  DateTime? _mintedAt;

  /// Creates the credential from the `.p8` key's PEM text.
  ///
  /// The key is parsed here, so a damaged key fails at startup under
  /// `messaging.push.bad_key` rather than at the first notification.
  TomApnsProviderToken({
    required this.teamId,
    required this.keyId,
    required String privateKeyPem,
    this.lifetime = const Duration(minutes: 50),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _key = _parseKey(
         () => jwt.ECPrivateKey(privateKeyPem),
         'APNs provider key',
       );

  @override
  Future<String> token() async {
    final current = now();
    final minted = _mintedAt;
    if (_token != null &&
        minted != null &&
        current.difference(minted) < lifetime) {
      return _token!;
    }
    _mintedAt = current;
    return _token = jwt
        .JWT(
          {'iss': teamId, 'iat': _epochSeconds(current)},
          header: {'kid': keyId},
        )
        .sign(_key, algorithm: jwt.JWTAlgorithm.ES256, noIssueAt: true);
  }

  @override
  void invalidate() {
    _token = null;
    _mintedAt = null;
  }

  @override
  String toString() => 'TomApnsProviderToken(team $teamId, key $keyId)';
}

/// An FCM access token, minted from a Google service-account key.
///
/// The OAuth 2.0 JWT-bearer grant: an assertion signed with the account's RSA
/// key is exchanged at [tokenUri] for an access token, which is cached until
/// five minutes before the expiry the token endpoint states.
class TomFcmServiceAccountCredential extends TomPushCredential {
  /// The scope FCM's HTTP v1 API requires.
  static const String messagingScope =
      'https://www.googleapis.com/auth/firebase.messaging';

  /// The service account's email — the assertion's issuer.
  final String clientEmail;

  /// Where the assertion is exchanged.
  final Uri tokenUri;

  /// The scope requested.
  final String scope;

  /// The project the account belongs to, when the key file named it.
  final String? projectId;

  /// How the token request is sent; injectable for tests.
  final TomPushExchange exchange;

  /// The clock; injectable for tests.
  final DateTime Function() now;

  final jwt.RSAPrivateKey _key;

  String? _token;
  DateTime? _expiresAt;

  /// Creates the credential from its parts.
  TomFcmServiceAccountCredential({
    required this.clientEmail,
    required String privateKeyPem,
    Uri? tokenUri,
    this.scope = messagingScope,
    this.projectId,
    TomPushExchange? exchange,
    DateTime Function()? now,
  }) : tokenUri = tokenUri ?? Uri.parse('https://oauth2.googleapis.com/token'),
       exchange = exchange ?? TomHttp1PushExchange(),
       now = now ?? DateTime.now,
       _key = _parseKey(
         () => jwt.RSAPrivateKey(privateKeyPem),
         'FCM service-account key',
       );

  /// Creates the credential from the JSON key file Google issues.
  ///
  /// Reads `client_email`, `private_key`, `token_uri` and `project_id`; a file
  /// missing either of the first two is refused under
  /// `messaging.push.bad_service_account`.
  factory TomFcmServiceAccountCredential.fromJson(
    String serviceAccountJson, {
    TomPushExchange? exchange,
    DateTime Function()? now,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(serviceAccountJson);
    } on FormatException {
      decoded = null;
    }
    final email = decoded is Map ? decoded['client_email'] : null;
    final key = decoded is Map ? decoded['private_key'] : null;
    if (email is! String || key is! String) {
      throw TomMessagingException(
        'messaging.push.bad_service_account',
        'The service-account key is not JSON with client_email and '
            'private_key.',
      );
    }
    final uri = (decoded as Map)['token_uri'];
    final project = decoded['project_id'];
    return TomFcmServiceAccountCredential(
      clientEmail: email,
      privateKeyPem: key,
      tokenUri: uri is String ? Uri.parse(uri) : null,
      projectId: project is String ? project : null,
      exchange: exchange,
      now: now,
    );
  }

  @override
  Future<String> token() async {
    final expires = _expiresAt;
    if (_token != null && expires != null && now().isBefore(expires)) {
      return _token!;
    }
    final issued = now();
    final assertion = jwt
        .JWT({
          'iss': clientEmail,
          'scope': scope,
          'aud': tokenUri.toString(),
          'iat': _epochSeconds(issued),
          'exp': _epochSeconds(issued.add(const Duration(hours: 1))),
        })
        .sign(_key, algorithm: jwt.JWTAlgorithm.RS256, noIssueAt: true);

    final TomPushGatewayResponse response;
    try {
      response = await exchange.exchange(
        TomPushGatewayRequest(
          url: tokenUri,
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: Uri(
            queryParameters: {
              'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
              'assertion': assertion,
            },
          ).query,
        ),
      );
    } catch (error, stack) {
      throw TomDeliveryException.transient(
        'messaging.push.credential_unavailable',
        'Could not reach the token endpoint at ${tokenUri.host}.',
        parameters: {'host': tokenUri.host},
        rootException: error,
        stack: stack,
      );
    }

    final json = _decodeOrNull(response.body);
    final token = tomVendorValueAt(json, 'access_token');
    if (response.statusCode != 200 || token == null) {
      final parameters = <String, Object?>{
        'host': tokenUri.host,
        'httpStatus': response.statusCode,
        if (tomVendorValueAt(json, 'error') case final code?)
          'providerCode': code,
      };
      // A refused grant — a revoked key, a wrong account — will be refused
      // again; an outage at the token endpoint will not.
      if (TomDeliveryException.isTransientHttpStatus(response.statusCode)) {
        throw TomDeliveryException.transient(
          'messaging.push.credential_unavailable',
          'The token endpoint answered ${response.statusCode}.',
          statusCode: response.statusCode,
          parameters: parameters,
        );
      }
      throw TomDeliveryException.permanent(
        'messaging.push.credential_refused',
        'The token endpoint refused the service-account assertion '
            '(${response.statusCode}).',
        statusCode: response.statusCode,
        parameters: parameters,
      );
    }
    final lifetime =
        int.tryParse(tomVendorValueAt(json, 'expires_in') ?? '') ?? 3600;
    // Five minutes early, so a token is never presented in the last moments
    // of its life and expires on the way to the service.
    _expiresAt = issued.add(Duration(seconds: lifetime - 300));
    return _token = token;
  }

  @override
  void invalidate() {
    _token = null;
    _expiresAt = null;
  }

  @override
  String toString() => 'TomFcmServiceAccountCredential($clientEmail)';
}

K _parseKey<K>(K Function() parse, String what) {
  try {
    return parse();
  } catch (error, stack) {
    throw TomMessagingException(
      'messaging.push.bad_key',
      'The $what is not a PEM private key of the expected type.',
      parameters: {'key': what},
      rootException: error,
      stack: stack,
    );
  }
}

int _epochSeconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

Object? _decodeOrNull(String body) {
  if (body.trim().isEmpty) return null;
  try {
    return jsonDecode(body);
  } on FormatException {
    // A proxy's HTML error page is an answer the status rule can still
    // classify, not a parse failure worth raising.
    return null;
  }
}

String? _clip(String body) {
  final flat = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (flat.isEmpty) return null;
  return flat.length <= 200 ? flat : '${flat.substring(0, 197)}...';
}

// =============================================================================
// PROTOCOLS
// =============================================================================

/// How one push service is spoken to: field names in, status and error paths
/// out.
abstract class TomPushProtocol {
  /// Const constructor for subclasses.
  const TomPushProtocol();

  /// Whether the service accepts only HTTP/2; picks the transport's default
  /// [TomPushExchange].
  bool get requiresHttp2 => false;

  /// The request that submits [submission], authenticated with [token].
  TomPushGatewayRequest encode(TomPushSubmission submission, String? token);

  /// What [response] means.
  TomPushGatewayAnswer decode(TomPushGatewayResponse response);

  /// The headers that present [token]: `Authorization: Bearer <token>`, or
  /// nothing when there is no credential.
  Map<String, String> authorizationHeaders(String? token) =>
      token == null ? const {} : {'Authorization': 'Bearer $token'};

  /// Classifies [code] against the three sets every protocol keeps.
  ///
  /// Shared by every protocol here so the precedence is written once: a
  /// credential code first, because the cure is a refresh whatever the status
  /// says, then the permanent and transient sets, then nothing — leaving the
  /// transport to judge by the HTTP status.
  static TomPushGatewayAnswer rejection({
    required String? code,
    required String? detail,
    required Set<String> permanentCodes,
    required Set<String> transientCodes,
    required Set<String> credentialCodes,
  }) => TomPushGatewayAnswer.rejected(
    permanent: code == null
        ? null
        : credentialCodes.contains(code)
        ? null
        : permanentCodes.contains(code)
        ? true
        : transientCodes.contains(code)
        ? false
        : null,
    isCredentialRejected: code != null && credentialCodes.contains(code),
    detail: detail,
    providerCode: code,
  );
}

/// Firebase Cloud Messaging, HTTP v1 API.
///
/// ```dart
/// final credential = TomFcmServiceAccountCredential.fromJson(keyFileText);
/// router.register(TomPushTransport(
///   TomFcmPushProtocol(projectId: credential.projectId!),
///   credential: credential,
/// ));
/// ```
///
/// Posts `{"message": {"token", "notification": {"title", "body"}, "data"}}`
/// to `/v1/projects/<projectId>/messages:send` and reads the error code from
/// the `FcmError` entry of `error.details`, falling back to `error.status`.
class TomFcmPushProtocol extends TomPushProtocol {
  /// Codes that mean this token will never take a notification.
  static const Set<String> permanentCodes = {
    'UNREGISTERED',
    'INVALID_ARGUMENT',
    'SENDER_ID_MISMATCH',
    'THIRD_PARTY_AUTH_ERROR',
    'NOT_FOUND',
  };

  /// Codes that mean "not right now".
  static const Set<String> transientCodes = {
    'QUOTA_EXCEEDED',
    'UNAVAILABLE',
    'INTERNAL',
  };

  /// Codes that mean the access token was refused.
  static const Set<String> credentialCodes = {'UNAUTHENTICATED'};

  /// The Firebase project id.
  final String projectId;

  /// The API's base URL; injectable for tests.
  final Uri baseUri;

  /// Creates the protocol for [projectId].
  TomFcmPushProtocol({required this.projectId, Uri? baseUri})
    : baseUri = baseUri ?? Uri.parse('https://fcm.googleapis.com');

  /// The send endpoint.
  Uri get endpoint => baseUri.resolve(
    '/v1/projects/${Uri.encodeComponent(projectId)}/'
    'messages:send',
  );

  @override
  TomPushGatewayRequest encode(TomPushSubmission submission, String? token) =>
      TomPushGatewayRequest(
        url: endpoint,
        headers: {
          ...authorizationHeaders(token),
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'message': {
            'token': submission.token,
            'notification': {
              if (submission.title != null) 'title': submission.title,
              'body': submission.body,
            },
            if (submission.data.isNotEmpty) 'data': submission.data,
          },
        }),
      );

  @override
  TomPushGatewayAnswer decode(TomPushGatewayResponse response) {
    final json = _decodeOrNull(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return TomPushGatewayAnswer.accepted(
        remoteId: tomVendorValueAt(json, 'name'),
      );
    }
    final code =
        _fcmErrorCode(json) ??
        tomVendorValueAt(json, 'error.status') ??
        // A 401 without a readable body is still an expired access token.
        (response.statusCode == 401 ? 'UNAUTHENTICATED' : null);
    return TomPushProtocol.rejection(
      code: code,
      detail: tomVendorValueAt(json, 'error.message') ?? _clip(response.body),
      permanentCodes: permanentCodes,
      transientCodes: transientCodes,
      credentialCodes: credentialCodes,
    );
  }

  static String? _fcmErrorCode(Object? json) {
    final error = json is Map ? json['error'] : null;
    final details = error is Map ? error['details'] : null;
    if (details is! List) return null;
    for (final detail in details) {
      if (detail is Map &&
          '${detail['@type']}'.endsWith('.FcmError') &&
          detail['errorCode'] is String) {
        return detail['errorCode'] as String;
      }
    }
    return null;
  }

  @override
  String toString() => 'TomFcmPushProtocol($projectId)';
}

/// Apple Push Notification service, token-based authentication.
///
/// ```dart
/// router.register(TomPushTransport(
///   TomApnsPushProtocol(topic: 'com.example.app'),
///   credential: TomApnsProviderToken(
///     teamId: appleTeamId, keyId: appleKeyId, privateKeyPem: p8Text),
/// ));
/// ```
///
/// Posts `{"aps": {"alert": {"title", "body"}}}` plus the data keys to
/// `/3/device/<token>` over HTTP/2, and reads the refusal from the body's
/// `reason`. A success has an empty body; its id is the `apns-id` header.
class TomApnsPushProtocol extends TomPushProtocol {
  /// Reasons that mean this notification or token will never be taken.
  static const Set<String> permanentCodes = {
    'BadDeviceToken',
    'Unregistered',
    'DeviceTokenNotForTopic',
    'BadTopic',
    'TopicDisallowed',
    'MissingTopic',
    'PayloadTooLarge',
    'PayloadEmpty',
    'BadCollapseId',
    'BadPriority',
    'BadExpirationDate',
    'BadMessageId',
    'MissingDeviceToken',
    'BadCertificate',
    'BadCertificateEnvironment',
    'Forbidden',
  };

  /// Reasons that mean "not right now".
  static const Set<String> transientCodes = {
    'TooManyRequests',
    'TooManyProviderTokenUpdates',
    'InternalServerError',
    'ServiceUnavailable',
    'Shutdown',
    'IdleTimeout',
  };

  /// Reasons that mean the provider token was refused.
  static const Set<String> credentialCodes = {
    'ExpiredProviderToken',
    'InvalidProviderToken',
    'MissingProviderToken',
  };

  /// The app's bundle id — the `apns-topic` header.
  final String topic;

  /// Whether to send to the development environment.
  final bool sandbox;

  /// The `apns-push-type` header; `alert` for a visible notification.
  final String pushType;

  /// The `apns-priority` header: `10` delivers immediately, `5` when power
  /// allows.
  final int priority;

  /// The API's base URL; overrides [sandbox], for tests.
  final Uri? baseUri;

  /// Creates the protocol for the app [topic].
  const TomApnsPushProtocol({
    required this.topic,
    this.sandbox = false,
    this.pushType = 'alert',
    this.priority = 10,
    this.baseUri,
  });

  @override
  bool get requiresHttp2 => true;

  Uri get _base =>
      baseUri ??
      Uri.parse(
        sandbox
            ? 'https://api.sandbox.push.apple.com'
            : 'https://api.push.apple.com',
      );

  @override
  Map<String, String> authorizationHeaders(String? token) =>
      token == null ? const {} : {'authorization': 'bearer $token'};

  @override
  TomPushGatewayRequest encode(TomPushSubmission submission, String? token) =>
      TomPushGatewayRequest(
        url: _base.resolve(
          '/3/device/${Uri.encodeComponent(submission.token)}',
        ),
        headers: {
          ...authorizationHeaders(token),
          'apns-topic': topic,
          'apns-push-type': pushType,
          'apns-priority': '$priority',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          // Data first, so a data key named `aps` cannot replace the alert.
          ...submission.data,
          'aps': {
            'alert': {
              if (submission.title != null) 'title': submission.title,
              'body': submission.body,
            },
          },
        }),
      );

  @override
  TomPushGatewayAnswer decode(TomPushGatewayResponse response) {
    if (response.statusCode == 200) {
      return TomPushGatewayAnswer.accepted(
        remoteId: response.headers['apns-id'],
      );
    }
    final json = _decodeOrNull(response.body);
    final reason = tomVendorValueAt(json, 'reason');
    return TomPushProtocol.rejection(
      code: reason,
      detail: reason ?? _clip(response.body),
      permanentCodes: permanentCodes,
      transientCodes: transientCodes,
      credentialCodes: credentialCodes,
    );
  }

  @override
  String toString() =>
      'TomApnsPushProtocol($topic${sandbox ? ', sandbox' : ''})';
}

/// A push service described by field paths — for any JSON push API that is
/// neither FCM nor APNs.
///
/// Field paths are dotted, so `message.notification.title` builds the nested
/// object; a `{token}` in [endpoint] is replaced by the URL-encoded device
/// token, for services that address the device in the path.
///
/// ```dart
/// TomFieldMappedPushProtocol(
///   endpoint: Uri.parse('https://push.example.com/v2/send'),
///   tokenField: 'to',
///   titleField: 'notification.title',
///   bodyField: 'notification.body',
///   dataField: 'data',
///   remoteIdPath: 'id',
///   errorCodePath: 'error.code',
///   permanentErrorCodes: {'invalid_token'},
/// )
/// ```
class TomFieldMappedPushProtocol extends TomPushProtocol {
  /// Where to send; may contain `{token}`.
  final String endpoint;

  /// The HTTP method.
  final String method;

  /// The path of the device token in the body, or `null` when [endpoint]
  /// carries it.
  final String? tokenField;

  /// The path of the title.
  final String titleField;

  /// The path of the body text.
  final String bodyField;

  /// The path the data map goes under, or `null` to drop it.
  final String? dataField;

  /// Constant fields every submission carries.
  final Map<String, Object?> extraFields;

  /// The header carrying the credential.
  final String authorizationHeader;

  /// What precedes the token in [authorizationHeader].
  final String authorizationPrefix;

  @override
  final bool requiresHttp2;

  /// The dotted path to the status value, or `null` to trust the HTTP status.
  final String? statusPath;

  /// The status values that mean "taken", compared case-insensitively.
  final Set<String> acceptedStatuses;

  /// The dotted path to the service's notification id.
  final String? remoteIdPath;

  /// The dotted path to the error code.
  final String? errorCodePath;

  /// The dotted path to the error message.
  final String? errorMessagePath;

  /// Error codes that mean "never going to work".
  final Set<String> permanentErrorCodes;

  /// Error codes that mean "not right now".
  final Set<String> transientErrorCodes;

  /// Error codes that mean the credential was refused.
  final Set<String> credentialErrorCodes;

  /// Creates a field-mapped protocol.
  const TomFieldMappedPushProtocol({
    required this.endpoint,
    this.method = 'POST',
    this.tokenField = 'token',
    this.titleField = 'title',
    this.bodyField = 'body',
    this.dataField = 'data',
    this.extraFields = const {},
    this.authorizationHeader = 'Authorization',
    this.authorizationPrefix = 'Bearer ',
    this.requiresHttp2 = false,
    this.statusPath,
    this.acceptedStatuses = const {},
    this.remoteIdPath,
    this.errorCodePath,
    this.errorMessagePath,
    this.permanentErrorCodes = const {},
    this.transientErrorCodes = const {},
    this.credentialErrorCodes = const {},
  });

  @override
  Map<String, String> authorizationHeaders(String? token) => token == null
      ? const {}
      : {authorizationHeader: '$authorizationPrefix$token'};

  @override
  TomPushGatewayRequest encode(TomPushSubmission submission, String? token) {
    final body = <String, Object?>{...extraFields};
    if (tokenField != null) _put(body, tokenField!, submission.token);
    if (submission.title != null) _put(body, titleField, submission.title);
    _put(body, bodyField, submission.body);
    if (dataField != null && submission.data.isNotEmpty) {
      _put(body, dataField!, submission.data);
    }
    return TomPushGatewayRequest(
      url: Uri.parse(
        endpoint.replaceAll('{token}', Uri.encodeComponent(submission.token)),
      ),
      method: method,
      headers: {
        ...authorizationHeaders(token),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    );
  }

  static void _put(Map<String, Object?> into, String path, Object? value) {
    final steps = path.split('.');
    var node = into;
    for (final step in steps.take(steps.length - 1)) {
      final next = node[step];
      node = next is Map<String, Object?>
          ? next
          : (node[step] = <String, Object?>{});
    }
    node[steps.last] = value;
  }

  @override
  TomPushGatewayAnswer decode(TomPushGatewayResponse response) {
    final json = _decodeOrNull(response.body);
    final httpOk = response.statusCode >= 200 && response.statusCode < 300;
    final bool accepted;
    if (statusPath == null) {
      accepted = httpOk;
    } else {
      final status = tomVendorValueAt(json, statusPath);
      // A configured status path that does not resolve is not a success: the
      // service promised to say something and did not.
      accepted =
          httpOk &&
          status != null &&
          acceptedStatuses.any((a) => a.toLowerCase() == status.toLowerCase());
    }
    final detail =
        tomVendorValueAt(json, errorMessagePath) ?? _clip(response.body);
    if (accepted) {
      return TomPushGatewayAnswer.accepted(
        remoteId: tomVendorValueAt(json, remoteIdPath),
        detail: detail,
      );
    }
    return TomPushProtocol.rejection(
      code: tomVendorValueAt(json, errorCodePath),
      detail: detail,
      permanentCodes: permanentErrorCodes,
      transientCodes: transientErrorCodes,
      credentialCodes: credentialErrorCodes,
    );
  }
}

// =============================================================================
// TRANSPORT
// =============================================================================

/// Delivers [TomMessageChannel.push] through a push service.
///
/// A push message is built by [TomMessage.push]: its recipients are device
/// tokens, its [TomMessage.subject] is the title, its text body the
/// notification text, and its `pushData` metadata the data map.
///
/// One request per device token, for the reason [TomSmsTransport] sends one
/// per number: a dead token must not cost the other devices their
/// notification.
class TomPushTransport extends TomMessageTransport {
  /// The metadata key the data map travels under.
  static const String dataMetadataKey = 'pushData';

  /// The service mapping.
  final TomPushProtocol protocol;

  /// The credential, or `null` for a service that needs none.
  final TomPushCredential? credential;

  /// The wire.
  final TomPushExchange exchange;

  /// How long one request may take before it counts as deferred.
  final Duration timeout;

  /// Creates a push transport; the exchange defaults to HTTP/2 when
  /// [protocol] requires it and HTTP/1.1 otherwise.
  TomPushTransport(
    this.protocol, {
    this.credential,
    TomPushExchange? exchange,
    this.timeout = const Duration(seconds: 30),
  }) : exchange =
           exchange ??
           (protocol.requiresHttp2
               ? TomHttp2PushExchange()
               : TomHttp1PushExchange());

  @override
  TomMessageChannel get channel => TomMessageChannel.push;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);

    final body = (message.textBody ?? message.preferredBody)?.content;
    if (body == null || body.isEmpty) {
      throw TomDeliveryException.permanent(
        'messaging.push.no_body',
        'Message ${message.id} has no text to show.',
        parameters: {'messageId': message.id},
      );
    }
    final data = message.metadata[dataMetadataKey];
    final dataMap = data is Map
        ? {for (final entry in data.entries) '${entry.key}': '${entry.value}'}
        : const <String, String>{};

    final rejected = <String>[];
    String? remoteId;
    String? detail;
    for (final recipient in message.recipients) {
      final answer = await _submit(
        TomPushSubmission(
          messageId: message.id,
          token: recipient.address,
          title: message.subject,
          body: body,
          data: dataMap,
        ),
      );
      if (answer.isAccepted) {
        remoteId ??= answer.remoteId;
        detail ??= answer.detail;
        continue;
      }
      rejected.add(recipient.address);
      detail ??= answer.detail;
    }

    if (rejected.length == message.recipients.length) {
      throw TomDeliveryException.permanent(
        'messaging.push.all_recipients_rejected',
        'Every device token of message ${message.id} was rejected.',
        parameters: {
          'messageId': message.id,
          'rejected': rejected.length,
          if (detail != null) 'detail': detail,
        },
      );
    }

    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: remoteId,
      detail: detail,
      rejectedRecipients: rejected,
    );
  }

  /// Sends one submission, returning the answer only when it is final.
  ///
  /// A rejected credential is refreshed and the submission made once more. A
  /// transient refusal is thrown rather than returned, which stops the pass: a
  /// rate limit applies to the account, not to one device, and the retry would
  /// otherwise deliver twice to the devices already reached.
  Future<TomPushGatewayAnswer> _submit(TomPushSubmission submission) async {
    var (answer, status) = await _attempt(submission);
    if (answer.isCredentialRejected && credential != null) {
      credential!.invalidate();
      (answer, status) = await _attempt(submission);
    }
    if (answer.isAccepted) return answer;

    final parameters = <String, Object?>{
      'messageId': submission.messageId,
      'httpStatus': status,
      if (answer.providerCode != null) 'providerCode': answer.providerCode,
    };
    final detail = answer.detail == null ? '' : ': ${answer.detail}';
    if (answer.isCredentialRejected) {
      throw TomDeliveryException.permanent(
        'messaging.push.credential_rejected',
        'The push service rejected the credential for message '
            '${submission.messageId}$detail',
        statusCode: status,
        parameters: parameters,
      );
    }
    final permanent =
        answer.isPermanent ??
        !TomDeliveryException.isTransientHttpStatus(status);
    if (permanent) return answer;
    throw TomDeliveryException.transient(
      'messaging.push.gateway_deferred',
      'The push service deferred message ${submission.messageId}$detail',
      statusCode: status,
      parameters: parameters,
    );
  }

  Future<(TomPushGatewayAnswer, int)> _attempt(
    TomPushSubmission submission,
  ) async {
    final token = await credential?.token();
    final request = protocol.encode(submission, token);
    final TomPushGatewayResponse response;
    try {
      response = await exchange.exchange(request).timeout(timeout);
    } on TomDeliveryException {
      rethrow;
    } catch (error, stack) {
      // Unreachable, refused, timed out: the textbook transient failure.
      throw TomDeliveryException.transient(
        'messaging.push.unreachable',
        'Could not reach the push service at ${request.url.host}.',
        parameters: {
          'messageId': submission.messageId,
          'host': request.url.host,
        },
        rootException: error,
        stack: stack,
      );
    }
    return (protocol.decode(response), response.statusCode);
  }

  @override
  Future<void> close() => exchange.close();
}
