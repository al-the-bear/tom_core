/// The seam between the passkey mechanism and whatever can make and use a
/// passkey on this target.
///
/// On the web that is the browser's `navigator.credentials`, reached through
/// `dart:js_interop` with no plugin. Elsewhere this package has no binding: a
/// native app needs a platform plugin (Android's Credential Manager, iOS's
/// `ASAuthorization`), which the framework does not choose for every
/// application. There [TomWebAuthnPlatform.instance] reports
/// [TomWebAuthnPlatform.isAvailable] `false`, the flow does not register the
/// passkey mechanism, and a challenge for one shows the flow's "this app cannot
/// render that method" message. An application with a plugin assigns its own
/// [TomWebAuthnPlatform.instance] at start-up.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'webauthn_platform_neutral.dart'
    if (dart.library.js_interop) 'webauthn_platform_web.dart'
    as binding;

/// Makes and uses passkeys on this target.
abstract class TomWebAuthnPlatform {
  /// Const constructor for subclasses.
  const TomWebAuthnPlatform();

  /// The binding this target uses. Replace it before the first login to supply
  /// a native plugin, or a fake in a test.
  static TomWebAuthnPlatform instance = binding.defaultWebAuthnPlatform();

  /// Whether this target can make and use passkeys at all.
  bool get isAvailable;

  /// Asks the authenticator to make a passkey.
  ///
  /// Throws [TomWebAuthnPlatformException] when the user cancels, the
  /// authenticator refuses, or the target has no authenticator.
  Future<TomWebAuthnRegistrationResponse> create(
    TomWebAuthnCreationOptions options,
  );

  /// Asks the authenticator to sign a challenge with a passkey.
  ///
  /// Throws [TomWebAuthnPlatformException] as [create] does.
  Future<TomWebAuthnAuthenticationResponse> get(
    TomWebAuthnRequestOptions options,
  );
}

/// The platform could not complete a passkey ceremony.
///
/// The browser reports a cancelled prompt, a timed-out one and a refused one
/// alike (`NotAllowedError`), deliberately, so a page cannot learn whether the
/// user holds a credential. The panel therefore shows one message for all of
/// them and offers to try again.
class TomWebAuthnPlatformException implements Exception {
  /// What the platform said, for the log.
  final String message;

  /// Creates the exception.
  const TomWebAuthnPlatformException(this.message);

  @override
  String toString() => 'TomWebAuthnPlatformException: $message';
}

/// The binding for a target with no passkey support.
class TomUnavailableWebAuthnPlatform extends TomWebAuthnPlatform {
  /// Creates the binding.
  const TomUnavailableWebAuthnPlatform();

  @override
  bool get isAvailable => false;

  @override
  Future<TomWebAuthnRegistrationResponse> create(
    TomWebAuthnCreationOptions options,
  ) => Future.error(
    const TomWebAuthnPlatformException('no passkey support on this target'),
  );

  @override
  Future<TomWebAuthnAuthenticationResponse> get(
    TomWebAuthnRequestOptions options,
  ) => Future.error(
    const TomWebAuthnPlatformException('no passkey support on this target'),
  );
}
