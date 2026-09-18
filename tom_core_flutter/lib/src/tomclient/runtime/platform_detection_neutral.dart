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
///
/// [getIsolateName] answers the constant `"neutral"`. There is no isolate API
/// on such a target, so it is a label for *which variant is running* rather
/// than for which isolate — every isolate here answers the same thing.
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

  // A constant: this variant runs where there is neither `dart:io` nor
  // `dart:js`, so there is no isolate API to ask and nothing to distinguish one
  // isolate from another. Every isolate on such a target answers "neutral" —
  // see the class dartdoc for what that means for a reader of a log line.
  //
  // The word rather than an abbreviation. It was `"ntrl"`, which expanded
  // nowhere in the module and matched neither sibling: the other two variants
  // answer `"main"` and `"web"`, whole words both.
  @override
  String getIsolateName() => "neutral";

  @override
  String toString() => "TomFlutterPlatformUtils: neutral";
}
