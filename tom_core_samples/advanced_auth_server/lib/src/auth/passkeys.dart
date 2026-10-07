/// The sample's passkey wiring: which second factors it offers, and the
/// relying party a passkey made against it is bound to.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// The second factors this deployment offers, in the order the enrolment
/// chooser lists them.
///
/// Named rather than left to "every registered mechanism", so a framework
/// release that ships another adaptor does not silently widen what this
/// server asks its users to set up.
const List<String> advancedTwoFactorMechanisms = [
  TomTotp2FAService.mechanismType,
  TomWebAuthn2FAService.mechanismType,
];

/// The relying party id passkeys are bound to.
///
/// `localhost`, because the sample runs there; browsers allow WebAuthn on
/// `localhost` without TLS, and on nothing else. A deployment on a real host
/// sets its registrable domain here once and never changes it — every passkey
/// made under the old value stops working.
const String advancedPasskeyRelyingPartyId = 'localhost';

/// The OS environment variable that lists the origins a passkey ceremony may
/// run on, comma-separated. Not read from `.env`. Defaults to
/// [advancedPasskeyDefaultOrigin].
const String advancedPasskeyOriginsVariable = 'ADVANCED_PASSKEY_ORIGINS';

/// The origin a browser build of a sample client is served from by default —
/// `flutter run -d chrome --web-port 8090`.
const String advancedPasskeyDefaultOrigin = 'http://localhost:8090';

/// Configures [TomWebAuthn2FAService] for this deployment, before the first
/// login reads the adaptor registry.
void installPasskeyRelyingParty({Map<String, String>? environment}) {
  final configured =
      (environment ?? Platform.environment)[advancedPasskeyOriginsVariable];
  final origins = (configured == null || configured.trim().isEmpty)
      ? {advancedPasskeyDefaultOrigin}
      : {
          for (final origin in configured.split(','))
            if (origin.trim().isNotEmpty) origin.trim(),
        };
  TomWebAuthn2FAService.globalSettingRelyingPartyId =
      advancedPasskeyRelyingPartyId;
  TomWebAuthn2FAService.globalSettingRelyingPartyName = 'Advanced Todo';
  TomWebAuthn2FAService.globalSettingAllowedOrigins = origins;
}
