import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the runtime module (`clientPlatformUtils`).
///
/// Run from the Dart VM (native IO branch), so `kIsWeb` is false and
/// `httpClient()` yields a real client. Platform predicates read
/// `defaultTargetPlatform`, which is overridden per test for determinism.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('returns a TomPlatformUtils', () {
    expect(clientPlatformUtils, isA<TomPlatformUtils>());
  });

  test('is not web on the native test host', () {
    expect(clientPlatformUtils.isWeb(), isFalse);
  });

  test('reports macOS as a desktop platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final p = clientPlatformUtils;
    expect(p.isMacOs(), isTrue);
    expect(p.isDesktop(), isTrue);
    expect(p.isMobile(), isFalse);
    expect(p.isWindows(), isFalse);
  });

  test('reports Linux as a desktop platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final p = clientPlatformUtils;
    expect(p.isLinux(), isTrue);
    expect(p.isDesktop(), isTrue);
    expect(p.isMobile(), isFalse);
  });

  test('reports Android as a mobile platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final p = clientPlatformUtils;
    expect(p.isAndroid(), isTrue);
    expect(p.isMobile(), isTrue);
    expect(p.isDesktop(), isFalse);
  });

  test('reports iOS as a mobile platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final p = clientPlatformUtils;
    expect(p.isIos(), isTrue);
    expect(p.isMobile(), isTrue);
    expect(p.isDesktop(), isFalse);
  });

  test('provides an HTTP client on the native branch', () {
    expect(clientPlatformUtils.httpClient(), isA<Client>());
  });

  test('reports a non-empty isolate name', () {
    expect(clientPlatformUtils.getIsolateName(), isNotEmpty);
  });
}
