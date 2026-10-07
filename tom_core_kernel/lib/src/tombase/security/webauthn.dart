/// The WebAuthn (passkey) wire types both halves of the second factor agree
/// on.
///
/// The server issues options and verifies responses; the client hands options
/// to the platform authenticator and returns its response. Neither package may
/// own the shapes the other reads, so they live here, as plain values with a
/// `toJson` / `fromJson` pair each.
///
/// ## The W3C JSON forms, not a framework shape
///
/// Every type serialises to the JSON form WebAuthn Level 3 defines —
/// `PublicKeyCredentialCreationOptionsJSON`, `RegistrationResponseJSON` and
/// their request/authentication siblings — with every binary field as
/// unpadded base64url. A browser's own `PublicKeyCredential.toJSON()` produces
/// the response forms directly, and a deployment that inspects the traffic sees
/// the field names the specification uses rather than ones invented here.
///
/// ## Through the `String` seam
///
/// A second-factor panel hands its answer back as a `String` — for TOTP the code
/// the user typed, for a passkey the authenticator's signed response. A response
/// travels as [TomWebAuthnRegistrationResponse.toSubmission] /
/// [TomWebAuthnAuthenticationResponse.toSubmission]: its JSON form, UTF-8
/// encoded and then base64url encoded, so the submission is one opaque token
/// with no characters a transport might mangle. The server reverses it with
/// `fromSubmission`, which answers `null` for anything that is not one.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Unpadded base64url, the encoding every WebAuthn JSON field uses.
abstract final class TomBase64Url {
  /// Encodes [bytes] without padding.
  static String encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Decodes [text], with or without padding; `null` when it is not base64url.
  static Uint8List? decode(String text) {
    final trimmed = text.trim();
    final padded = trimmed.padRight((trimmed.length + 3) ~/ 4 * 4, '=');
    try {
      return base64Url.decode(padded);
    } on FormatException {
      return null;
    }
  }
}

/// The COSE algorithm identifiers a credential may be created with.
abstract final class TomWebAuthnAlgorithms {
  /// ECDSA over P-256 with SHA-256 — what every platform authenticator offers.
  static const int es256 = -7;

  /// RSASSA-PKCS1-v1_5 with SHA-256 — Windows Hello's choice.
  static const int rs256 = -257;
}

/// What a credential must prove about the user's presence.
///
/// [required] makes the server refuse an assertion whose user-verified flag is
/// clear; [preferred] asks for it and accepts presence alone; [discouraged]
/// asks for presence only.
enum TomWebAuthnUserVerification {
  /// Must verify the user (PIN, biometric).
  required,

  /// Verify when the authenticator can.
  preferred,

  /// Presence only.
  discouraged,
}

/// The options a client passes to `navigator.credentials.create` to make a
/// passkey.
class TomWebAuthnCreationOptions {
  /// The relying party id — the registrable domain the credential is bound to.
  final String rpId;

  /// The relying party's display name.
  final String rpName;

  /// The user handle, base64url: an opaque id, never a name.
  final String userId;

  /// The account name the authenticator shows.
  final String userName;

  /// The display name the authenticator shows.
  final String userDisplayName;

  /// The challenge, base64url.
  final String challenge;

  /// The COSE algorithms acceptable, most preferred first.
  final List<int> algorithms;

  /// How long the platform may wait for the user, in milliseconds.
  final int timeoutMs;

  /// The user-verification requirement.
  final TomWebAuthnUserVerification userVerification;

  /// Credential ids, base64url, the user already holds — so the authenticator
  /// refuses to make a second credential for the same account.
  final List<String> excludeCredentialIds;

  /// Creates the options.
  const TomWebAuthnCreationOptions({
    required this.rpId,
    required this.rpName,
    required this.userId,
    required this.userName,
    required this.userDisplayName,
    required this.challenge,
    this.algorithms = const [
      TomWebAuthnAlgorithms.es256,
      TomWebAuthnAlgorithms.rs256,
    ],
    this.timeoutMs = 120000,
    this.userVerification = TomWebAuthnUserVerification.preferred,
    this.excludeCredentialIds = const [],
  });

  /// The `PublicKeyCredentialCreationOptionsJSON` form.
  ///
  /// Attestation is always `none`: the server verifies what the credential
  /// signs, not which authenticator model made it.
  Map<String, Object?> toJson() => {
    'rp': {'id': rpId, 'name': rpName},
    'user': {'id': userId, 'name': userName, 'displayName': userDisplayName},
    'challenge': challenge,
    'pubKeyCredParams': [
      for (final alg in algorithms) {'type': 'public-key', 'alg': alg},
    ],
    'timeout': timeoutMs,
    'excludeCredentials': [
      for (final id in excludeCredentialIds) {'type': 'public-key', 'id': id},
    ],
    'authenticatorSelection': {
      'residentKey': 'preferred',
      'userVerification': userVerification.name,
    },
    'attestation': 'none',
  };

  /// Reads the form [toJson] writes; `null` when a required field is missing.
  static TomWebAuthnCreationOptions? fromJson(Object? json) {
    if (json is! Map) return null;
    final rp = json['rp'];
    final user = json['user'];
    final challenge = json['challenge'];
    if (rp is! Map || user is! Map || challenge is! String) return null;
    final rpId = rp['id'];
    final userId = user['id'];
    if (rpId is! String || userId is! String) return null;
    final selection = json['authenticatorSelection'];
    return TomWebAuthnCreationOptions(
      rpId: rpId,
      rpName: _string(rp['name']),
      userId: userId,
      userName: _string(user['name']),
      userDisplayName: _string(user['displayName']),
      challenge: challenge,
      algorithms: [
        for (final param in _list(json['pubKeyCredParams']))
          if (param is Map && param['alg'] is int) param['alg'] as int,
      ],
      timeoutMs: _int(json['timeout'], 120000),
      userVerification: _verification(
        selection is Map ? selection['userVerification'] : null,
      ),
      excludeCredentialIds: _credentialIds(json['excludeCredentials']),
    );
  }
}

/// The options a client passes to `navigator.credentials.get` to sign in with
/// a passkey.
class TomWebAuthnRequestOptions {
  /// The challenge, base64url.
  final String challenge;

  /// The relying party id.
  final String rpId;

  /// The credential ids, base64url, this user may answer with.
  final List<String> allowCredentialIds;

  /// How long the platform may wait for the user, in milliseconds.
  final int timeoutMs;

  /// The user-verification requirement.
  final TomWebAuthnUserVerification userVerification;

  /// Creates the options.
  const TomWebAuthnRequestOptions({
    required this.challenge,
    required this.rpId,
    this.allowCredentialIds = const [],
    this.timeoutMs = 120000,
    this.userVerification = TomWebAuthnUserVerification.preferred,
  });

  /// The `PublicKeyCredentialRequestOptionsJSON` form.
  Map<String, Object?> toJson() => {
    'challenge': challenge,
    'rpId': rpId,
    'allowCredentials': [
      for (final id in allowCredentialIds) {'type': 'public-key', 'id': id},
    ],
    'timeout': timeoutMs,
    'userVerification': userVerification.name,
  };

  /// Reads the form [toJson] writes; `null` when a required field is missing.
  static TomWebAuthnRequestOptions? fromJson(Object? json) {
    if (json is! Map) return null;
    final challenge = json['challenge'];
    final rpId = json['rpId'];
    if (challenge is! String || rpId is! String) return null;
    return TomWebAuthnRequestOptions(
      challenge: challenge,
      rpId: rpId,
      allowCredentialIds: _credentialIds(json['allowCredentials']),
      timeoutMs: _int(json['timeout'], 120000),
      userVerification: _verification(json['userVerification']),
    );
  }
}

/// What the authenticator returned when it made a credential.
class TomWebAuthnRegistrationResponse {
  /// The credential id, base64url.
  final String id;

  /// The client data the authenticator signed over, base64url.
  final String clientDataJson;

  /// The CBOR attestation object, base64url.
  final String attestationObject;

  /// How the authenticator can be reached (`internal`, `usb`, `hybrid`, …).
  final List<String> transports;

  /// Creates the response.
  const TomWebAuthnRegistrationResponse({
    required this.id,
    required this.clientDataJson,
    required this.attestationObject,
    this.transports = const [],
  });

  /// The `RegistrationResponseJSON` form.
  Map<String, Object?> toJson() => {
    'id': id,
    'rawId': id,
    'type': 'public-key',
    'response': {
      'clientDataJSON': clientDataJson,
      'attestationObject': attestationObject,
      'transports': transports,
    },
  };

  /// Reads the form [toJson] writes; `null` when a required field is missing.
  static TomWebAuthnRegistrationResponse? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final response = json['response'];
    if (id is! String || response is! Map) return null;
    final clientData = response['clientDataJSON'];
    final attestation = response['attestationObject'];
    if (clientData is! String || attestation is! String) return null;
    return TomWebAuthnRegistrationResponse(
      id: id,
      clientDataJson: clientData,
      attestationObject: attestation,
      transports: [
        for (final transport in _list(response['transports']))
          if (transport is String) transport,
      ],
    );
  }

  /// This response as a second-factor submission.
  String toSubmission() => _toSubmission(toJson());

  /// The response a [toSubmission] string carries, or `null`.
  static TomWebAuthnRegistrationResponse? fromSubmission(String submission) =>
      fromJson(_fromSubmission(submission));
}

/// What the authenticator returned when it signed a challenge.
class TomWebAuthnAuthenticationResponse {
  /// The credential id, base64url.
  final String id;

  /// The client data the authenticator signed over, base64url.
  final String clientDataJson;

  /// The authenticator data, base64url.
  final String authenticatorData;

  /// The signature over authenticator data and the client-data hash,
  /// base64url.
  final String signature;

  /// The user handle the credential was made for, base64url, when the
  /// authenticator returned one.
  final String? userHandle;

  /// Creates the response.
  const TomWebAuthnAuthenticationResponse({
    required this.id,
    required this.clientDataJson,
    required this.authenticatorData,
    required this.signature,
    this.userHandle,
  });

  /// The `AuthenticationResponseJSON` form.
  Map<String, Object?> toJson() => {
    'id': id,
    'rawId': id,
    'type': 'public-key',
    'response': {
      'clientDataJSON': clientDataJson,
      'authenticatorData': authenticatorData,
      'signature': signature,
      'userHandle': ?userHandle,
    },
  };

  /// Reads the form [toJson] writes; `null` when a required field is missing.
  static TomWebAuthnAuthenticationResponse? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final response = json['response'];
    if (id is! String || response is! Map) return null;
    final clientData = response['clientDataJSON'];
    final authData = response['authenticatorData'];
    final signature = response['signature'];
    if (clientData is! String || authData is! String || signature is! String) {
      return null;
    }
    final handle = response['userHandle'];
    return TomWebAuthnAuthenticationResponse(
      id: id,
      clientDataJson: clientData,
      authenticatorData: authData,
      signature: signature,
      userHandle: handle is String && handle.isNotEmpty ? handle : null,
    );
  }

  /// This response as a second-factor submission.
  String toSubmission() => _toSubmission(toJson());

  /// The response a [toSubmission] string carries, or `null`.
  static TomWebAuthnAuthenticationResponse? fromSubmission(String submission) =>
      fromJson(_fromSubmission(submission));
}

String _toSubmission(Map<String, Object?> json) =>
    TomBase64Url.encode(utf8.encode(jsonEncode(json)));

Object? _fromSubmission(String submission) {
  final bytes = TomBase64Url.decode(submission);
  if (bytes == null) return null;
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value, int fallback) => value is int ? value : fallback;

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _credentialIds(Object? value) => [
  for (final entry in _list(value))
    if (entry is Map && entry['id'] is String) entry['id'] as String,
];

TomWebAuthnUserVerification _verification(Object? value) =>
    TomWebAuthnUserVerification.values.firstWhere(
      (v) => v.name == value,
      orElse: () => TomWebAuthnUserVerification.preferred,
    );
