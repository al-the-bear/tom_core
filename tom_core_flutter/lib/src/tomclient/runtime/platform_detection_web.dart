import 'package:web/web.dart' hide RequestMode, Client;
import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'platform_detection_base.dart';

/// Web (`dart:js`) [TomPlatformUtils] for the browser target.
///
/// Exposes the browser location via [getBrowserLocation] and provides a
/// CORS-enabled [FetchClient]. Selected by the conditional import in
/// `platform_detection_client.dart`.
///
/// The platform predicates are [TomFlutterPlatformUtilsBase]'s — all three
/// variants answer them identically, from the same two Flutter symbols.
class TomFlutterPlatformUtils extends TomFlutterPlatformUtilsBase {
  @override
  Client httpClient() => FetchClient(mode: RequestMode.cors);

  @override
  String? getBrowserLocation() {
    return window.location.href;
  }

  @override
  String getIsolateName() => "web";

  @override
  String toString() => "TomFlutterPlatformUtils: web";
}
