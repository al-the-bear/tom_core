import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Annotation marking a class as a client-side two-factor (2FA) adaptor.
///
/// Apply it to a client authentication adaptor and pass the 2FA mechanism it
/// implements via [type] (e.g. `'totp'`, `'sms'`). The annotation is
/// reflection-discoverable (it is itself `@tomReflector`-registered), so a
/// runtime can enumerate the available client 2FA adaptors and dispatch by
/// [type].
///
/// ```dart
/// @TomClient2FAAdaptor('totp')
/// class TotpAdaptor { /* ... */ }
/// ```
@tomReflector
class TomClient2FAAdaptor {
  /// The 2FA mechanism this adaptor implements (e.g. `'totp'`, `'sms'`).
  final String type;

  /// Tags the annotated class as a 2FA adaptor for [type].
  const TomClient2FAAdaptor(this.type);
}
