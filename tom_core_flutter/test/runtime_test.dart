import 'dart:async';
import 'dart:convert';
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

  test('out and outError both write to standard output', () {
    // The pair is this module's only console surface, and the names invite the
    // assumption that the second one is routed elsewhere. It is not: both
    // resolve to `print`, so both land on stdout. Capturing the print zone
    // says so directly. Asserting only `returnsNormally`, which is what this
    // test did before, cannot see a destination at all — and a summary
    // claiming the two were routed differently lived beside it undetected.
    final captured = <String>[];
    final utils = clientPlatformUtils;
    runZoned(
      () {
        utils.out('hello');
        utils.outError('oops');
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => captured.add(line),
      ),
    );
    expect(captured, ['hello', 'oops']);
  });

  test('the API summary describes out and outError as the code routes them', () {
    // Read the source first, because it is the identical bodies that make
    // identical descriptions correct. Stating that dependency in the test is
    // what turns a frozen sentence into a checked one: if the two methods are
    // ever given different destinations, this fails on the source expectation
    // and asks for the summary to be revised rather than quietly leaving a
    // description that has stopped being true.
    final source = File(
      'lib/src/tomclient/runtime/platform_detection_flutter_io.dart',
    ).readAsStringSync();
    String bodyOf(String method) => RegExp(
      'void $method\\(String s\\) => ([^;]+);',
    ).firstMatch(source)!.group(1)!;
    expect(
      bodyOf('outError'),
      bodyOf('out'),
      reason: 'the two no longer share a destination; revise the summary',
    );

    final summary = File(
      'doc/api_reference/api_summary_runtime.md',
    ).readAsStringSync();
    String descriptionOf(String method) => RegExp(
      '^\\| `$method` \\|[^|]*\\|(.*)\\|\\s*\$',
      multiLine: true,
    ).firstMatch(summary)!.group(1)!;
    expect(descriptionOf('out'), contains('standard output'));
    expect(descriptionOf('outError'), contains('standard output'));
  });

  group('the documented home of the platform contract', () {
    // `TomPlatformUtils` and `TomFallbackPlatformUtils` are tom_basics types.
    // This module can only reach them because the kernel barrel re-exports the
    // whole of tom_basics, so every import line here reads
    // `package:tom_core_kernel/tom_core_kernel.dart` — which is exactly how the
    // documents drifted into calling them kernel types. A reader who follows
    // that to tom_core_kernel looking for the contract's dartdoc, or for what a
    // new predicate would have to override, finds nothing there.

    test('the contract is declared in tom_basics, not in the kernel', () {
      // Resolved through the package config, which is the same resolution the
      // compiler performs, so the test names the *package* a type belongs to
      // rather than a position in the directory tree. That matters here beyond
      // tidiness: tom_basics is consumed from pub.dev while tom_core_kernel is
      // a path dependency, so the two do not even live in comparable places,
      // and a relative path would pin the wrong thing for one of them.
      final config =
          jsonDecode(
                File('.dart_tool/package_config.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final packages = (config['packages'] as List)
          .cast<Map<String, dynamic>>();

      Uri libOf(String package) {
        final entry = packages.firstWhere(
          (p) => p['name'] == package,
          orElse: () => throw StateError('$package is not in the package config'),
        );
        // A trailing slash, or `resolve` treats the package directory as a
        // file name and replaces it with `lib/` instead of descending into it.
        final rootText = entry['rootUri'] as String;
        final root = Uri.parse(
          rootText.endsWith('/') ? rootText : '$rootText/',
        );
        final absolute = root.hasScheme
            ? root
            : File('.dart_tool/package_config.json').absolute.uri.resolveUri(
                root,
              );
        return absolute.resolve('${entry['packageUri']}');
      }

      const types = ['TomPlatformUtils', 'TomFallbackPlatformUtils'];

      final basics = File.fromUri(
        libOf('tom_basics').resolve('src/runtime/platform_neutral.dart'),
      ).readAsStringSync();
      for (final type in types) {
        expect(
          basics,
          contains('class $type'),
          reason: 'tom_basics no longer declares $type',
        );
      }

      final kernelSources = Directory.fromUri(libOf('tom_core_kernel'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final source in kernelSources) {
        final text = source.readAsStringSync();
        for (final type in types) {
          expect(
            text,
            isNot(contains('class $type')),
            reason:
                '$type is now declared in the kernel (${source.path}); the '
                'documents say tom_basics and need revisiting',
          );
        }
      }
    });

    test('no document names the kernel as the home of the contract', () {
      // The misattribution is a co-occurrence: a line names one of the types
      // and calls it the kernel's. Naming the kernel beside the type is only
      // legitimate when the line says what the kernel actually is here — the
      // barrel that re-exports the type — so those two words are what the rule
      // permits. Anything else on such a line is the claim this todo removed,
      // and it had reappeared in six places across three documents, which is
      // why prose review alone was never going to hold it.
      final documents = [
        'doc/runtime.md',
        'doc/api_reference/api_summary_runtime.md',
        'README.md',
      ];
      final type = RegExp(r'\bTom(Fallback)?PlatformUtils\b');
      final route = RegExp(r're-export|barrel', caseSensitive: false);

      for (final path in documents) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!type.hasMatch(line) || !line.contains('kernel')) continue;
          expect(
            route.hasMatch(line),
            isTrue,
            reason:
                '$path:${i + 1} names the kernel beside the contract without '
                'saying it is only the re-exporting barrel:\n  $line',
          );
        }
      }
    });
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
