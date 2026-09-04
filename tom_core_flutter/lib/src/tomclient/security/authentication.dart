import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Registers a `Tom2FAClientMechanism` under the 2FA mechanism it renders,
/// without a line of start-up wiring.
///
/// The client mirror of the server's `@Tom2FAAdaptor`, deliberately down to the
/// spelling: a mechanism ships as a package that adds a server adaptor and a
/// client mechanism, annotates both with the same key, and touches no framework
/// file on either side.
///
/// ```dart
/// @tomReflector
/// @TomClient2FAAdaptor('sms')
/// class SmsClientMechanism extends Tom2FAClientMechanism {
///   const SmsClientMechanism() : super('sms');
///   // ... buildEnrolmentPanel / buildChallengePanel
/// }
/// ```
///
/// ## What has to be true for it to work
///
/// `Tom2FAClientRegistry` scans the reflected program the first time anything
/// reads it, so three things are required and each fails loudly rather than
/// quietly if it is not:
///
/// * the class must also carry `@tomReflector` (or otherwise be reachable in
///   the generated reflection), because the scan enumerates *reflected* classes
///   — an application that does not run the reflection generator has nothing to
///   scan, and its mechanisms register by hand;
/// * it must extend `Tom2FAClientMechanism` and be constructible with an
///   unnamed, argument-free constructor, which is the one the scan calls; and
/// * its own `type` must equal [type]. The key is written twice — here and on
///   the mechanism — because that is what keeps the annotation identical to the
///   server's; a disagreement is refused rather than resolved, so the
///   duplication cannot drift.
///
/// ## Annotating is not the only way, and not always the winning one
///
/// `Tom2FAClientRegistry.register` *replaces*: an application that wants a
/// different panel than a discovered mechanism provides registers its own, and
/// the scan leaves that registration alone.
/// Two annotated classes claiming one key, by contrast, are refused — nobody
/// decided which should win, and the answer would otherwise depend on
/// reflection ordering.
@tomReflector
class TomClient2FAAdaptor {
  /// The 2FA mechanism this adaptor renders (e.g. `'totp'`, `'sms'`), matching
  /// the server adaptor's key and the mechanism's own `type`.
  final String type;

  /// Tags the annotated class as a 2FA adaptor for [type].
  const TomClient2FAAdaptor(this.type);
}
