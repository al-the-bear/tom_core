import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';

import '../example/runtime/runtime_example.dart' as example;

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

  test('reports Fuchsia via defaultTargetPlatform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    final p = clientPlatformUtils;
    expect(p.isFuchsia(), isTrue);
    expect(p.isDesktop(), isFalse);
    expect(p.isMobile(), isFalse);
  });

  test('reports Windows as a desktop platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final p = clientPlatformUtils;
    expect(p.isWindows(), isTrue);
    expect(p.isDesktop(), isTrue);
    expect(p.isMobile(), isFalse);
  });

  test('provides an HTTP client on the native branch', () {
    expect(clientPlatformUtils.httpClient(), isA<Client>());
  });

  test('tolerates bad certificates only for loopback hosts', () {
    // The HttpClient.badCertificateCallback delegates to this predicate; an
    // X509Certificate has no public constructor and the callback is not
    // readable back off the client, so the decision is tested directly.
    expect(allowsBadCertificateForHost('localhost'), isTrue);
    expect(allowsBadCertificateForHost('127.0.0.1'), isTrue);
    expect(allowsBadCertificateForHost('0.0.0.0'), isTrue);
    expect(allowsBadCertificateForHost('example.com'), isFalse);
    expect(allowsBadCertificateForHost('10.0.0.5'), isFalse);
  });

  test('imports the process environment at construction', () {
    // Constructing the native utils copies Platform.environment into the
    // kernel env vars. Pick a key actually present to stay OS-agnostic.
    expect(
      Platform.environment,
      isNotEmpty,
      reason: 'test host is expected to expose some environment variables',
    );
    final key = Platform.environment.keys.first;
    // Accessing the getter constructs TomFlutterPlatformUtils, whose
    // constructor copies Platform.environment into the (static) env-var map.
    final utils = clientPlatformUtils;
    expect(utils.getTomEnvVars()[key], Platform.environment[key]);
  });

  test('reports a non-empty isolate name', () {
    expect(clientPlatformUtils.getIsolateName(), isNotEmpty);
  });

  test('has no browser location on the native branch', () {
    // getBrowserLocation is meaningful only on the web variant; the native IO
    // implementation returns null.
    expect(clientPlatformUtils.getBrowserLocation(), isNull);
  });

  test('toString identifies the native IO variant', () {
    // The whole string, not `contains('io')`. `toString()` is this module's
    // diagnostic surface — it is what an application logs to record which
    // variant it selected — so what matters is that the record is greppable
    // for the class it names. A substring match cannot see that half of the
    // string, and for a long time did not: the class name in it was
    // misspelled and every test still passed.
    expect(clientPlatformUtils.toString(), 'TomFlutterPlatformUtils: io');
  });

  test('every variant names its own class', () {
    // Only the IO variant is reachable from this host; the other two are
    // chosen by conditional import and cannot be constructed here at all. So
    // the string they would return is read out of their source, which is the
    // only place a test on this host can see it. Without this the two
    // unreachable variants are pinned by nothing, and a name that drifts from
    // its class — the exact defect the test above now guards for `io` — could
    // reappear in either of them unnoticed.
    for (final variant in ['flutter_io', 'neutral', 'web']) {
      final path = 'lib/src/tomclient/runtime/platform_detection_$variant.dart';
      final source = File(path).readAsStringSync();
      final declared = RegExp(r'^class (\w+)', multiLine: true)
          .firstMatch(source)
          ?.group(1);
      final rendered = RegExp(r'String toString\(\) => "([^"]*)"')
          .firstMatch(source)
          ?.group(1);
      expect(declared, isNotNull, reason: '$path declares no class');
      expect(rendered, isNotNull, reason: '$path has no single-literal toString');
      expect(
        rendered,
        startsWith('$declared: '),
        reason: '$variant declares $declared but calls itself "$rendered"',
      );
    }
  });

  test('out and outError write without throwing', () {
    // Both delegate to print on the native branch; assert they are callable and
    // side-effect-only (no return, no throw).
    final utils = clientPlatformUtils;
    expect(() => utils.out('hello'), returnsNormally);
    expect(() => utils.outError('oops'), returnsNormally);
  });

  group('the shipped example runs', () {
    test('runtime_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      example.run();
    });
  });
}
