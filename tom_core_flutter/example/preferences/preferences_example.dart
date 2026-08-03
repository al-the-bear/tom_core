/// Executable example for the preferences module of `tom_core_flutter`.
///
/// Demonstrates **both** stores and how they meet. The device store keeps what
/// stays on this machine; `TomUserPreferencesClient` keeps what follows the
/// user across devices. Between them: register the store once, write and read
/// typed values through the platform-independent API, survive a restart, read
/// and write the account's own preferences over the kernel's `/preferences/*`
/// contract, apply the documented device-over-server precedence through
/// `getPreferred`, and clear the device.
///
/// The device backend used here is the JSON file one, reached through
/// `TomPlatformDevicePreferenceStore` — the same construction a real client
/// writes, with the path coming from `path_provider` instead of a temporary
/// directory. Nothing below branches on the platform, which is the point of the
/// module.
///
/// The account half talks to a loopback server started at the bottom of this
/// file rather than to a stub, so what is demonstrated is a real request/response
/// cycle over the contract's own routes. `tom_core_server` ships the production
/// implementation of those routes; this package does not depend on it, which is
/// exactly why `getPreferred` takes the account lookup as a callback and why
/// pairing the two is an *application's* job — shown here, at Example 6.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/preferences/preferences_example.dart`, not bare
/// `dart run`. The same behaviour is covered by `test/preferences_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../reflection_seed.dart';

Future<void> run() async {
  // First action, as the reflection contract requires: the account store sends
  // and receives framework DTOs, which are encoded through reflection.
  initializeReflection();

  // The other line every real client writes at startup. The preferences client
  // reaches the network through `TomPlatformUtils.current.httpClient()`, and the
  // neutral fallback deliberately throws rather than guessing an implementation
  // — so a client built without this fails on its first call, not at startup.
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);

  final directory = Directory.systemTemp.createTempSync('tom_preferences_');
  final location = '${directory.path}/device_preferences.json';
  // Stands in for a Tom server: the real one is `TomUserPreferencesServer` in
  // `tom_core_server`, which this package deliberately does not depend on. What
  // matters for the example is that the client below talks to a socket over the
  // contract's own routes rather than to a stub returning a literal.
  final server = await _ExamplePreferencesServer.start();
  // Built here rather than at its first use so that the `finally` below can close
  // it whatever happens in between.
  final userPreferences = TomUserPreferencesClient(baseUri: server.baseUri);

  try {
    // Example 1: registration. The one line in an application that knows where
    // machine-local state lives — every call site below resolves the interface.
    TomBean.withType(
      TomDevicePreferences,
      TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(location)),
    );
    final preferences = TomDevicePreferences.resolve()!;

    // Example 2: typed writes and reads. The value carries its own type, so a
    // read says what it expects and the store says what it is.
    await preferences.set('device.lastAccount', 'alex@example.com');
    await preferences.set('device.biometricUnlock', true);
    await preferences.set('device.launchCount', 12);

    print('account=${await preferences.get<String>('device.lastAccount')}');
    print('biometric=${await preferences.get<bool>('device.biometricUnlock')}');
    assert(await preferences.get<int>('device.launchCount') == 12);

    // Example 3: an unwritten preference answers its default; a *mismatched*
    // one throws rather than coercing, because a value read as the wrong type
    // is one the caller will act on believing it is the user's.
    print('theme=${await preferences.getOr('device.theme', 'system')}');
    assert(await preferences.getOr('device.theme', 'system') == 'system');
    try {
      await preferences.get<String>('device.launchCount');
      throw StateError('a mismatched read must not succeed');
    } on TomUserPreferenceCodecException catch (error) {
      print('mismatch rejected: ${error.key}');
      assert(error.key == 'preferences.decode.type_mismatch');
    }

    // Example 4: persistence. A second store over the same location is the next
    // launch of the app — nothing is shared but what reached the device.
    final afterRestart = TomStoredDevicePreferences(
      TomPlatformDevicePreferenceStore(location),
    );
    print(
      'after restart=${await afterRestart.get<String>('device.lastAccount')}',
    );
    assert(await afterRestart.get<int>('device.launchCount') == 12);

    // Example 5: the server-side store. `TomUserPreferencesClient` speaks the
    // kernel's `/preferences/*` contract, so the account store is reached with
    // the same six methods the device store carries and no URI is written here.
    await userPreferences.set(TomUserPreferenceKeys.language, 'de');
    print(
      'account language=${await userPreferences.get<String>(TomUserPreferenceKeys.language)}',
    );
    assert(
      await userPreferences.get<String>(TomUserPreferenceKeys.language) == 'de',
    );
    // A key the account has never held answers null, not an error: an unset
    // preference is an ordinary state.
    assert(await userPreferences.get<String>('account.unset') == null);
    print(
      'account keys=${(await userPreferences.all()).map((p) => p.key).toList()}',
    );

    // Example 6: precedence. The device value wins while it exists; the account
    // store answers only a key this device has never written. The callback is
    // where the two meet — it stays a callback because this package must not
    // require an HTTP client for a device-only app, and the client is simply
    // what an application that has one closes over.
    await preferences.set(TomUserPreferenceKeys.theme, 'dark');
    await userPreferences.set(TomUserPreferenceKeys.theme, 'light');

    final theme = await preferences.getPreferred<String>(
      TomUserPreferenceKeys.theme,
      () => userPreferences.get<String>(TomUserPreferenceKeys.theme),
    );
    print('resolved theme=$theme');
    assert(theme == 'dark'); // this device overrides the account

    final language = await preferences.getPreferred<String>(
      TomUserPreferenceKeys.language,
      () => userPreferences.get<String>(TomUserPreferenceKeys.language),
    );
    print('resolved language=$language');
    assert(language == 'de'); // never written here, so the account answers

    // Example 7: clearing the device. One atomic operation, not a loop — a loop
    // that failed half way would leave a state no user asked for.
    await preferences.clear();
    print('after clear=${await preferences.all()}');
    assert((await preferences.all()).isEmpty);
    assert(!File(location).existsSync()); // no file left behind
  } finally {
    userPreferences.close();
    await server.close();
    TomBean.resetBeanContext();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

Future<void> main() => run();

/// A loopback HTTP server that answers the four routes `tomUserPreferencesApi`
/// declares, backed by a map instead of a database.
///
/// It exists so the example can exercise a *real* request/response cycle without
/// depending on `tom_core_server`: what is being demonstrated is the client, and
/// a client that is only ever handed a canned literal demonstrates nothing. The
/// routes below are read off the same contract the client resolves its URIs
/// from, so the two cannot drift apart silently.
class _ExamplePreferencesServer {
  _ExamplePreferencesServer._(this._server);

  final HttpServer _server;
  final Map<String, TomUserPreferenceDto> _stored = {};

  /// Binds to an ephemeral loopback port and starts serving.
  static Future<_ExamplePreferencesServer> start() async {
    final server = _ExamplePreferencesServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    unawaited(server._serve());
    return server;
  }

  /// Where the client should point — the port is whatever the OS handed out.
  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      await _handle(request);
      await request.response.close();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // `pathSegments` is already percent-decoded, so a key containing a slash
    // arrives here in one piece — the same round trip `resolveUri` escaped it for.
    final segments = request.uri.pathSegments;
    if (segments.isEmpty || segments.first != 'preferences') {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final key = segments.length > 1 ? segments[1] : null;

    switch ((request.method, key)) {
      case ('GET', null):
        // A list result goes on the wire as a bare JSON array, which is what the
        // framework's pipeline produces and what the client decodes.
        _writeJson(
          response,
          '[${_stored.values.map(tomReflectionInfo.convertToJsonString).join(',')}]',
        );
      case ('GET', final String k):
        final stored = _stored[k];
        if (stored == null) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        _writeJson(response, tomReflectionInfo.convertToJsonString(stored));
      case ('PUT', final String k):
        final written = tomReflectionInfo.convertFromJsonString(
          TomUserPreferenceWriteRequest(),
          await utf8.decoder.bind(request).join(),
        );
        final stored = TomUserPreferenceDto(
          key: k,
          valueType: written.valueType,
          value: written.value,
          updatedAt: DateTime.now().toUtc(),
        );
        _stored[k] = stored;
        _writeJson(response, tomReflectionInfo.convertToJsonString(stored));
      case ('DELETE', final String k):
        // Idempotent: removing what was never there has already achieved its
        // purpose, so this is a 200 and not a 404.
        _stored.remove(k);
      default:
        response.statusCode = HttpStatus.methodNotAllowed;
    }
  }

  void _writeJson(HttpResponse response, String body) {
    response.headers.contentType = ContentType.json;
    response.write(body);
  }
}
