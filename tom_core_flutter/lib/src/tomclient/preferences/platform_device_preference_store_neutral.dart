import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preference_store.dart';
import 'device_preferences.dart';

/// The stand-in for [TomPlatformDevicePreferenceStore] on targets with neither
/// a filesystem nor a browser — in practice, a bare Dart target compiled
/// without either.
///
/// It **throws on construction** with
/// `device_preferences.unsupported_platform` rather than silently degrading to
/// an in-memory store. A settings screen whose switches appear to work but
/// forget everything on restart is a worse outcome than a failure at startup,
/// and only the app knows what the right store would be on such a target — so
/// the choice belongs to the app, made explicitly, not to a fallback made here.
///
/// A client that genuinely wants no machine-local persistence should say so by
/// using [TomMemoryDevicePreferenceStore].
class TomPlatformDevicePreferenceStore extends TomDevicePreferenceStore {
  /// Always throws — see the class documentation.
  ///
  /// [owner] is retained but never used. One name must mean one signature — and
  /// one member set — on every target for a conditional export to be worth
  /// using, so a caller reading `store.owner` compiles here too; a variant whose
  /// whole purpose is to fail at construction has nothing else to do with it.
  TomPlatformDevicePreferenceStore(this.location, {this.owner}) {
    throw TomDevicePreferenceException(
      'device_preferences.unsupported_platform',
      'A device preference store needs a filesystem or a browser, and this '
          'platform offers neither. Supply a platform-appropriate '
          'TomDevicePreferenceStore instead.',
      parameters: {'location': location},
    );
  }

  /// The location that was requested. Retained only so the failure can name it.
  final String location;

  /// The owner that was requested. Retained only for signature parity with the
  /// two variants that store a document.
  final String? owner;

  @override
  Future<List<TomUserPreferenceDto>> read() async => [];

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {}
}
