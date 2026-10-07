// The browser binding: `navigator.credentials` through `dart:js_interop`, with
// the binary fields of the W3C JSON forms converted to and from typed arrays.
// See `webauthn_platform.dart`.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'webauthn_platform.dart';

/// The default binding on the web.
TomWebAuthnPlatform defaultWebAuthnPlatform() => const _BrowserWebAuthn();

@JS('navigator.credentials')
external _Credentials? get _credentials;

@JS('PublicKeyCredential')
external JSAny? get _publicKeyCredential;

extension type _Credentials._(JSObject _) implements JSObject {
  external JSPromise<_PublicKeyCredential?> create(JSObject options);
  external JSPromise<_PublicKeyCredential?> get(JSObject options);
}

extension type _PublicKeyCredential._(JSObject _) implements JSObject {
  external JSArrayBuffer get rawId;
  external _AuthenticatorResponse get response;
}

extension type _AuthenticatorResponse._(JSObject _) implements JSObject {
  external JSArrayBuffer get clientDataJSON;
  external JSArrayBuffer? get attestationObject;
  external JSArrayBuffer? get authenticatorData;
  external JSArrayBuffer? get signature;
  external JSArrayBuffer? get userHandle;
  external JSArray<JSString> getTransports();
}

class _BrowserWebAuthn extends TomWebAuthnPlatform {
  const _BrowserWebAuthn();

  @override
  bool get isAvailable => _credentials != null && _publicKeyCredential != null;

  @override
  Future<TomWebAuthnRegistrationResponse> create(
    TomWebAuthnCreationOptions options,
  ) async {
    // Everything but the binary fields goes through jsify; those are set as
    // typed arrays explicitly, because WebAuthn takes a BufferSource and how
    // jsify treats a Uint8List differs between the two web compilers.
    final publicKey = options.toJson().jsify()! as JSObject;
    publicKey.setProperty('challenge'.toJS, _bytes(options.challenge));
    publicKey
        .getProperty<JSObject>('user'.toJS)
        .setProperty('id'.toJS, _bytes(options.userId));
    publicKey.setProperty(
      'excludeCredentials'.toJS,
      [for (final id in options.excludeCredentialIds) _descriptor(id)].toJS,
    );
    final credential = await _call(
      () => _credentials!.create(
        JSObject()..setProperty('publicKey'.toJS, publicKey),
      ),
    );
    final response = credential.response;
    final attestation = response.attestationObject;
    if (attestation == null) {
      throw const TomWebAuthnPlatformException('no attestation object');
    }
    List<String> transports;
    try {
      transports = [for (final t in response.getTransports().toDart) t.toDart];
    } on Object {
      // Older browsers lack getTransports(); the server does not need them.
      transports = const [];
    }
    return TomWebAuthnRegistrationResponse(
      id: _encode(credential.rawId),
      clientDataJson: _encode(response.clientDataJSON),
      attestationObject: _encode(attestation),
      transports: transports,
    );
  }

  @override
  Future<TomWebAuthnAuthenticationResponse> get(
    TomWebAuthnRequestOptions options,
  ) async {
    final publicKey = options.toJson().jsify()! as JSObject;
    publicKey.setProperty('challenge'.toJS, _bytes(options.challenge));
    publicKey.setProperty(
      'allowCredentials'.toJS,
      [for (final id in options.allowCredentialIds) _descriptor(id)].toJS,
    );
    final credential = await _call(
      () => _credentials!.get(
        JSObject()..setProperty('publicKey'.toJS, publicKey),
      ),
    );
    final response = credential.response;
    final authData = response.authenticatorData;
    final signature = response.signature;
    if (authData == null || signature == null) {
      throw const TomWebAuthnPlatformException('incomplete assertion');
    }
    final handle = response.userHandle;
    return TomWebAuthnAuthenticationResponse(
      id: _encode(credential.rawId),
      clientDataJson: _encode(response.clientDataJSON),
      authenticatorData: _encode(authData),
      signature: _encode(signature),
      userHandle: handle == null ? null : _encode(handle),
    );
  }

  Future<_PublicKeyCredential> _call(
    JSPromise<_PublicKeyCredential?> Function() ceremony,
  ) async {
    if (!isAvailable) {
      throw const TomWebAuthnPlatformException('no passkey support here');
    }
    _PublicKeyCredential? credential;
    try {
      credential = await ceremony().toDart;
    } on Object catch (error) {
      throw TomWebAuthnPlatformException('$error');
    }
    if (credential == null) {
      throw const TomWebAuthnPlatformException('no credential returned');
    }
    return credential;
  }

  static JSUint8Array _bytes(String base64Url) =>
      (TomBase64Url.decode(base64Url) ?? Uint8List(0)).toJS;

  static JSObject _descriptor(String id) => JSObject()
    ..setProperty('type'.toJS, 'public-key'.toJS)
    ..setProperty('id'.toJS, _bytes(id));

  static String _encode(JSArrayBuffer buffer) =>
      TomBase64Url.encode(buffer.toDart.asUint8List());
}
