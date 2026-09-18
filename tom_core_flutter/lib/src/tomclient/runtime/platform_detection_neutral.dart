import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'platform_detection_base.dart';

/// Neutral fallback [TomPlatformUtils] for targets that expose neither
/// `dart:io` nor `dart:js`.
///
/// Cannot create an HTTP [Client] — [httpClient] throws [UnsupportedError],
/// since a concrete platform variant must be selected for networking. Selected
/// by the conditional import in `platform_detection_client.dart`.
///
/// The platform predicates are [TomFlutterPlatformUtilsBase]'s — all three
/// variants answer them identically, from the same two Flutter symbols.
class TomFlutterPlatformUtils extends TomFlutterPlatformUtilsBase {
  // UnsupportedError, not UnimplementedError: nothing here is waiting to be
  // written. A target that exposes neither `dart:io` nor `dart:js` has no HTTP
  // client implementation to construct at all, so the refusal is permanent.
  @override
  Client httpClient() {
    throw UnsupportedError(
      'The neutral platform fallback has no HTTP client: this target exposes '
      'neither dart:io nor dart:js, so there is no Client implementation to '
      'construct. Select a concrete TomPlatformUtils variant for the target '
      'before making network calls.',
    );
  }

  @override
  String getIsolateName() => "ntrl";

  @override
  String toString() => "TomFlutterPlatformUtils: neutral";
}
