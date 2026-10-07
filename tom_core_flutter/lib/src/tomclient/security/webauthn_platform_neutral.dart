// The binding for every target without `dart:js_interop`: no passkey support
// unless the application supplies a plugin. See `webauthn_platform.dart`.
import 'webauthn_platform.dart';

/// The default binding off the web.
TomWebAuthnPlatform defaultWebAuthnPlatform() =>
    const TomUnavailableWebAuthnPlatform();
