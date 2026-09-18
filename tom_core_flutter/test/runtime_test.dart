import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_base.dart';
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';
// The neutral fallback is *selected* only where neither `dart:io` nor
// `dart:js` exists, but the file itself imports nothing target-specific, so it
// compiles and runs on this host like any other library. Prefixed because it
// declares the same class name as the IO variant imported above — the shared
// name is what makes one conditional import resolve to all three.
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_neutral.dart'
    as neutral;

import '../example/runtime/runtime_example.dart' as example;

/// The `lib/` directory of [package], as the compiler resolves it.
///
/// Resolved through the package config, which is the same resolution the
/// compiler performs, so a test names the *package* a symbol belongs to rather
/// than a position in the directory tree. That matters here beyond tidiness:
/// `tom_basics` is consumed from pub.dev while `tom_core_kernel` is a path
/// dependency, so the two do not even live in comparable places, and a relative
/// path would pin the wrong thing for one of them.
///
/// `Isolate.resolvePackageUri` would say the same thing in one line, but it is
/// unsupported under the Flutter test runner, so the config is read directly.
Uri packageLibUri(String package) {
  final configFile = File('.dart_tool/package_config.json');
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final entry = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere(
        (p) => p['name'] == package,
        orElse: () => throw StateError('$package is not in the package config'),
      );
  // A trailing slash, or `resolve` treats the package directory as a file name
  // and replaces it with `lib/` instead of descending into it.
  final rootText = entry['rootUri'] as String;
  final root = Uri.parse(rootText.endsWith('/') ? rootText : '$rootText/');
  // `rootUri` is relative to the config file for path dependencies inside the
  // workspace and absolute for hosted ones, so both shapes have to be handled.
  final absolute = root.hasScheme
      ? root
      : configFile.absolute.uri.resolveUri(root);
  return absolute.resolve('${entry['packageUri']}');
}

/// The `@override` members [className] declares in [source], by name, each
/// reduced to the expression it evaluates.
///
/// `=> x;` and `{ return x; }` and `{ x; }` all reduce to `x`, because the same
/// behaviour is written in different forms on either side of every comparison
/// here: the tom_basics base uses block bodies throughout, the variants use
/// expression bodies. Comparing the text as written would report every pair as
/// different and see none of the duplication these tests exist to find.
/// Multi-statement bodies are left as they are, collapsed to single spaces —
/// they reduce to nothing simpler, and nothing compared here has one.
Map<String, String> overrideBodies(String source, String className) {
  final member = RegExp(
    r'@override\s+[\w<>?, ]+?\s(\w+)\(([^)]*)\)\s*(=>\s*[^;]+;|\{.*?\n  \})',
    dotAll: true,
  );
  // From the class declaration on, so a top-level function with an identical
  // shape — or a member of an earlier class in the same file — is not counted.
  final body = source.substring(source.indexOf('class $className'));
  return {
    for (final match in member.allMatches(body))
      match.group(1)!: _expressionOf(match.group(3)!),
  };
}

String _expressionOf(String body) {
  var text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.startsWith('=>')) {
    text = text.substring(2);
  } else if (text.startsWith('{') && text.endsWith('}')) {
    text = text.substring(1, text.length - 1);
  }
  text = text.trim();
  if (text.startsWith('return ')) text = text.substring('return '.length);
  if (text.endsWith(';')) text = text.substring(0, text.length - 1);
  return text.trim();
}

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

  group('the certificate policy', () {
    // The HttpClient.badCertificateCallback delegates to this policy; an
    // X509Certificate has no public constructor and the callback is not
    // readable back off the client, so the decision is tested directly.
    tearDown(TomBadCertificatePolicy.reset);

    test('the shipped policy accepts both loopback families', () {
      // The point of the whole entry. Which address `localhost` resolves to is
      // the resolver's choice and differs between machines, so a policy that
      // named one family and not the other made the same code, certificate and
      // URL succeed on one desktop and fail on the next — reported as a TLS
      // error, which sends the reader to audit the certificate.
      for (final host in [
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '::1',
        '[::1]',
      ]) {
        expect(TomBadCertificatePolicy.allows(host), isTrue, reason: host);
      }
    });

    test('it accepts nothing else, including other IPv6 addresses', () {
      for (final host in [
        'example.com',
        '10.0.0.5',
        // Not loopback, and the spelling closest to one that is: a policy
        // widened by pattern rather than by literal would take these.
        '::2',
        'fe80::1',
        '2001:db8::1',
        'localhost.example.com',
      ]) {
        expect(TomBadCertificatePolicy.allows(host), isFalse, reason: host);
      }
    });

    test('`::1` is the spelling that reaches the callback', () {
      // Measured rather than assumed, because the list carries both and only
      // one of them can be tested against a real URL: `Uri` strips the brackets
      // an IPv6 literal carries in a URL, so what the callback is handed is the
      // bare form. `[::1]` stays in the list for a caller that passes an
      // authority, which is why it is asserted above and not here.
      expect(Uri.parse('https://[::1]:8443/x').host, '::1');
      expect(
        TomBadCertificatePolicy.allows(Uri.parse('https://[::1]:8443/x').host),
        isTrue,
      );
    });

    test('the shipped list is the default, and reset restores it', () {
      expect(
        TomBadCertificatePolicy.hosts,
        TomBadCertificatePolicy.defaultHosts,
      );

      TomBadCertificatePolicy.allowOnly(const ['dev.internal']);
      expect(TomBadCertificatePolicy.allows('dev.internal'), isTrue);
      expect(TomBadCertificatePolicy.allows('localhost'), isFalse);

      TomBadCertificatePolicy.reset();
      expect(
        TomBadCertificatePolicy.hosts,
        TomBadCertificatePolicy.defaultHosts,
      );
    });

    test('allowOnly replaces rather than adds', () {
      // Replacement is what makes narrowing possible, and narrowing is the
      // direction that matters for a security boundary. A setter that only
      // ever added could not express "trust nothing".
      TomBadCertificatePolicy.allowOnly(const ['dev.internal']);

      expect(TomBadCertificatePolicy.hosts, ['dev.internal']);
      for (final host in TomBadCertificatePolicy.defaultHosts) {
        expect(TomBadCertificatePolicy.allows(host), isFalse, reason: host);
      }
    });

    test('an empty policy accepts nothing, which is the hardened setting', () {
      TomBadCertificatePolicy.allowOnly(const []);

      for (final host in [...TomBadCertificatePolicy.defaultHosts, 'other']) {
        expect(TomBadCertificatePolicy.allows(host), isFalse, reason: host);
      }
    });

    test('what is read back cannot be added to', () {
      // The list *is* the policy. A caller that could append to what it read
      // would widen the boundary without passing through the one place the
      // change is validated and logged.
      expect(
        () => TomBadCertificatePolicy.hosts.add('example.com'),
        throwsUnsupportedError,
      );
      expect(TomBadCertificatePolicy.allows('example.com'), isFalse);
    });

    test('a blank entry is refused, and refused before it takes effect', () {
      // What a split over a mis-typed setting leaves behind. No host string is
      // empty, so an entry that is names nothing — and a policy list quietly
      // carrying one reads as though it had been configured.
      expect(
        () => TomBadCertificatePolicy.allowOnly(const ['dev.internal', '  ']),
        throwsArgumentError,
      );
      expect(
        TomBadCertificatePolicy.hosts,
        TomBadCertificatePolicy.defaultHosts,
        reason: 'a rejected policy was applied up to the bad entry',
      );
    });

    test('a replacement is logged, because the source no longer states it', () {
      // The property a `const` list had and a setter cannot: the policy in
      // force was the policy in the source. The log line is what replaces it,
      // so widening leaves a record where an operator looks.
      final recorder = _RecordingLogOutput();
      final previous = tomLog.logOutput;
      tomLog.logOutput = recorder;
      addTearDown(() => tomLog.logOutput = previous);

      TomBadCertificatePolicy.allowOnly(const ['dev.internal']);

      expect(
        recorder.messages.join('\n'),
        allOf(contains('dev.internal'), contains('TomBadCertificatePolicy')),
      );
    });

    test('the native callback asks the policy rather than holding a copy', () {
      // A policy narrowed after a client was built has to take effect on that
      // client too, or hardening an application would depend on the order its
      // clients happened to be created in. `HttpClient.badCertificateCallback`
      // is not readable back off the client and an `X509Certificate` has no
      // public constructor, so the handshake itself cannot be staged here —
      // what can be checked is the property the guarantee rests on: the
      // callback body is a live call into the policy, not a captured list.
      final body = overrideBodies(
        File(
          'lib/src/tomclient/runtime/platform_detection_flutter_io.dart',
        ).readAsStringSync(),
        'TomFlutterPlatformUtils',
      )['httpClient'];

      expect(
        body,
        contains('TomBadCertificatePolicy.allows(host)'),
        reason:
            'the native client no longer delegates each decision to the '
            'policy, so a policy changed after the client was built would '
            'not reach it',
      );
    });
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
    // Reset first, so the read below is the one that constructs. Without it
    // this passes on a map some earlier test filled, and would go on passing
    // if the constructor stopped importing anything.
    resetClientPlatformUtils();
    addTearDown(resetClientPlatformUtils);
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

  test('the conditional import selects the IO variant on this host', () {
    // The selection itself, asserted against the type rather than through the
    // diagnostic string below. The two are different claims: a variant that
    // returned the right string from the wrong class would satisfy one and not
    // the other, and the conditional import is the mechanism the whole module
    // rests on. This is also the assertion that needs the direct `src/` import
    // above — `TomFlutterPlatformUtils` is withheld from the barrel, so the
    // documented path for reaching it is the one this suite compiles against.
    expect(clientPlatformUtils, isA<TomFlutterPlatformUtils>());
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
      final declared = RegExp(
        r'^class (\w+)',
        multiLine: true,
      ).firstMatch(source)?.group(1);
      final rendered = RegExp(
        r'String toString\(\) => "([^"]*)"',
      ).firstMatch(source)?.group(1);
      expect(declared, isNotNull, reason: '$path declares no class');
      expect(
        rendered,
        isNotNull,
        reason: '$path has no single-literal toString',
      );
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
    //
    // Read from the base, not from a variant: no variant declares the pair any
    // more, because each merely restated what it inherits. The source of the
    // behaviour the summary describes is `TomFallbackPlatformUtils`, so that is
    // where a change of destination would have to appear.
    final base = File.fromUri(
      packageLibUri('tom_basics').resolve('src/runtime/platform_neutral.dart'),
    ).readAsStringSync();
    final inherited = overrideBodies(base, 'TomFallbackPlatformUtils');
    for (final method in ['out', 'outError']) {
      expect(
        inherited[method],
        isNotNull,
        reason:
            'TomFallbackPlatformUtils no longer declares $method; the '
            'variants inherit it and the summary describes it',
      );
    }
    expect(
      inherited['outError'],
      inherited['out'],
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
      const types = ['TomPlatformUtils', 'TomFallbackPlatformUtils'];

      final basics = File.fromUri(
        packageLibUri(
          'tom_basics',
        ).resolve('src/runtime/platform_neutral.dart'),
      ).readAsStringSync();
      for (final type in types) {
        expect(
          basics,
          contains('class $type'),
          reason: 'tom_basics no longer declares $type',
        );
      }

      final kernelSources = Directory.fromUri(packageLibUri('tom_core_kernel'))
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
      // permits. Anything else on such a line is the misattribution, and it is
      // the kind that multiplies — one plausible sentence copied into every
      // document that introduces the type — which is why prose review alone
      // does not hold it.
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

  group('the documented reach of the module surface', () {
    // The three variants live behind one entry point that pulls them in with a
    // conditional `import` rather than an `export`, so `TomFlutterPlatformUtils`
    // — three unrelated classes sharing a name, one per target — never escapes
    // `src/`. A distinction invisible from the source of any variant, which is
    // how a summary once came to list an unreachable symbol under "Global
    // Functions".
    //
    // The certificate policy is the module's second exported name and is
    // deliberately *not* in a variant: it has no platform dependency, so it is
    // its own file and exports unconditionally. That is what lets an
    // application change a policy that only the native target consults.

    test(
      'the barrel publishes the entry point and the policy, and no variant',
      () {
        final barrel = File('lib/tom_core_flutter.dart').readAsStringSync();
        for (final exported in [
          'src/tomclient/runtime/platform_detection_client.dart',
          // Exported because an application has to be able to change it. It
          // carries no platform import, so unlike a variant it exists on every
          // target — which is precisely why it is a file of its own rather than
          // a member of the native one.
          'src/tomclient/runtime/bad_certificate_policy.dart',
        ]) {
          expect(
            barrel,
            contains("export '$exported';"),
            reason:
                '$exported is no longer exported; the documented surface has '
                'to be re-derived',
          );
        }
        for (final variant in ['flutter_io', 'neutral', 'web']) {
          expect(
            barrel,
            isNot(contains('platform_detection_$variant.dart')),
            reason:
                'the barrel now reaches past the entry point into the '
                '$variant variant; its symbols became public',
          );
        }

        // The load-bearing line: `import`, not `export`. A conditional export
        // could not work here anyway — `TomFlutterPlatformUtils` denotes a
        // different class on each target, so the name exports no single type —
        // but the guarantee a reader needs is that nothing escapes the entry
        // point, and that is what the absence of `export` states.
        final entry = File(
          'lib/src/tomclient/runtime/platform_detection_client.dart',
        ).readAsStringSync();
        expect(
          RegExp(r'^\s*export\s', multiLine: true).hasMatch(entry),
          isFalse,
          reason:
              'the entry point now re-exports the selected variant; the '
              'documents call its symbols internal and need revisiting',
        );
      },
    );

    test('the API summary marks the unreachable symbols and gives their path', () {
      // The import path is read out of this file rather than written into the
      // assertion, so the summary is held to the line a test actually compiles
      // against. Documenting an import path is only useful if it is the working
      // one, and the way that stops being true is a file move — which changes
      // this test's own import and would leave a hand-copied literal behind.
      final testSource = File('test/runtime_test.dart').readAsStringSync();
      final importPath = RegExp(
        r"^import '(package:tom_core_flutter/src/[^']+)';",
        multiLine: true,
      ).firstMatch(testSource)?.group(1);
      expect(
        importPath,
        isNotNull,
        reason:
            'this suite no longer imports the variant directly; the '
            'documented path has nothing left to match',
      );

      final summary = File(
        'doc/api_reference/api_summary_runtime.md',
      ).readAsStringSync();
      expect(
        summary,
        contains(importPath!),
        reason:
            'the API summary does not give the import path a test needs '
            'for the symbols the barrel withholds',
      );
      for (final symbol in [
        'TomFlutterPlatformUtils',
        'TomFlutterPlatformUtilsBase',
      ]) {
        expect(
          summary,
          contains(symbol),
          reason: '$symbol is no longer documented at all',
        );
      }
    });

    test('no enumeration of the surface lists a withheld symbol unmarked', () {
      // Scoped to the lines that *enumerate* — headings, table rows, list items
      // — and not to explanatory prose, which legitimately names the variant
      // class while describing how one gets selected. The enumerations are
      // where the contradiction lived: a summary once carried a withheld
      // symbol under a "Global Functions" heading while the prose two files
      // away called it not part of the public API, and the index tabulated it
      // beside the exported ones with nothing to distinguish them.
      final documents = [
        'doc/api_reference/api_summary_runtime.md',
        'doc/api_reference/api_summary_index.md',
      ];
      // `TomFlutterPlatformUtilsBase` needs naming separately: a word boundary
      // after `Utils` does not exist in front of `Base`, so the bare pattern
      // would skip every line that mentions only the base.
      final withheld = RegExp(r'\bTomFlutterPlatformUtils(Base)?\b');
      final enumerating = RegExp(r'^\s*(#{1,6} |[-*] |\|)');
      final qualified = RegExp(
        r'not exported|internal|src/',
        caseSensitive: false,
      );

      for (final path in documents) {
        final lines = File(path).readAsLinesSync();
        expect(
          lines.any(withheld.hasMatch),
          isTrue,
          reason: '$path no longer mentions the withheld symbols',
        );
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!withheld.hasMatch(line) || !enumerating.hasMatch(line)) continue;
          expect(
            qualified.hasMatch(line),
            isTrue,
            reason:
                '$path:${i + 1} lists a symbol the barrel withholds as '
                'though it were part of the exported surface:\n  $line',
          );
        }
      }
    });

    test(
      'the module document states which side of the barrel each name is on',
      () {
        // The summary's sections and these sentences are the two halves of the
        // agreement this pins; without them the summary would be the only place
        // reachability is stated, and the document a reader reaches first would
        // go quiet on it. Both directions matter now: one name is withheld and
        // one is published, and a reader who cannot tell which is which will
        // either reach into `src/` for something exported or give up on
        // something that is.
        // Whitespace-collapsed: the sentences are wrapped, so the phrases this
        // looks for are split across lines in the file.
        final runtimeDoc = File(
          'doc/runtime.md',
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

        expect(
          RegExp(
            r"TomFlutterPlatformUtils.{0,400}?not part of the barrel's "
            r'public API',
          ).hasMatch(runtimeDoc),
          isTrue,
          reason:
              'doc/runtime.md no longer says the variant class is outside the '
              'exported surface; it and the API summary would disagree',
        );
        expect(
          RegExp(
            r'TomBadCertificatePolicy.{0,600}?(exported|published)',
          ).hasMatch(runtimeDoc),
          isTrue,
          reason:
              'doc/runtime.md no longer says the certificate policy is part of '
              'the exported surface, which is the whole reason it is a file of '
              'its own',
        );
      },
    );
  });

  group('the variants share a base and duplicate nothing', () {
    // The three variants used to declare the nine platform predicates each,
    // byte for byte, because a conditional import requires them to share a
    // class name and shared behaviour therefore had nowhere to live. It has
    // somewhere now: `TomFlutterPlatformUtilsBase`, in a fourth file all three
    // import unconditionally.
    //
    // The inventory these tests recompute is what the documents state, and a
    // hand-maintained census of a set the compiler can enumerate drifts — this
    // one did, twice in the same breath, before it was checked. What changed
    // with the base is what the census says: the variants now share a
    // superclass instead of sharing copies, and the number of members
    // duplicated between them is zero.

    const variants = ['flutter_io', 'neutral', 'web'];

    String variantSource(String variant) => File(
      'lib/src/tomclient/runtime/platform_detection_$variant.dart',
    ).readAsStringSync();

    /// The `@override` members of each variant, by member name then variant.
    Map<String, Map<String, String>> variantMembers() {
      final byName = <String, Map<String, String>>{};
      for (final variant in variants) {
        overrideBodies(
          variantSource(variant),
          'TomFlutterPlatformUtils',
        ).forEach((name, body) {
          byName.putIfAbsent(name, () => {})[variant] = body;
        });
      }
      return byName;
    }

    /// The `@override` members of the shared base.
    Map<String, String> baseMembers() => overrideBodies(
      File(
        'lib/src/tomclient/runtime/platform_detection_base.dart',
      ).readAsStringSync(),
      'TomFlutterPlatformUtilsBase',
    );

    // Both documents state the inventory, and both had undercounted it. Holding
    // only one of them would leave the other free to drift — which is how the
    // module ended up with three descriptions of one set of files, no two of
    // them agreeing.
    const documents = [
      'doc/runtime.md',
      'doc/api_reference/api_summary_runtime.md',
    ];

    test('the base declares what the variants answer the same way', () {
      // Named rather than counted, because the point of the base is *which*
      // members it holds: the ones every target answers identically. A base
      // that had absorbed `httpClient` would be wrong however many members it
      // had.
      expect(
        baseMembers().keys,
        unorderedEquals(<String>[
          'isDesktop',
          'isMobile',
          'isWeb',
          'isFuchsia',
          'isWindows',
          'isLinux',
          'isMacOs',
          'isAndroid',
          'isIos',
          // Not a predicate, and here for the same reason they are: two of the
          // three variants wrote `null` identically. Only a browser has a
          // location, so only the web variant overrides it.
          'getBrowserLocation',
        ]),
      );
    });

    test('no variant restates a body the base already gives it', () {
      // The regression the extraction exists to prevent: a member copied back
      // into one variant compiles, passes every behavioural test on the host
      // that selects it, and silently restores the split the base removed — on
      // the two targets no test can reach.
      //
      // Overriding a base member is not itself the fault. The web variant
      // overrides `getBrowserLocation` because a browser has one, which is
      // exactly what a base plus specialisations is for. Restating the base's
      // *own* body is the fault, because that is a copy pretending to be a
      // decision.
      final base = baseMembers();
      for (final variant in variants) {
        overrideBodies(
          variantSource(variant),
          'TomFlutterPlatformUtils',
        ).forEach((name, body) {
          if (!base.containsKey(name)) return;
          expect(
            body,
            isNot(equals(base[name])),
            reason:
                '$variant overrides `$name` with the body it already inherits '
                'from TomFlutterPlatformUtilsBase; delete the override',
          );
        });
      }
    });

    test('no member is written identically by two variants', () {
      // The census, as a property rather than a number: whatever the variants
      // still override, no two of them write the same thing. A member that
      // appeared here would be one the base should hold.
      final members = variantMembers();
      expect(members, isNotEmpty, reason: 'no overrides were read at all');

      for (final entry in members.entries) {
        final bodies = entry.value;
        expect(
          bodies.values.toSet().length,
          bodies.length,
          reason:
              '`${entry.key}` is written identically by two variants: '
              '${bodies.keys.join(", ")} — it belongs on the shared base',
        );
      }
    });

    test('both documents list exactly the members that differ', () {
      final members = variantMembers();

      /// The sentence in [path] that enumerates the per-variant differences.
      String differenceSentence(String path) {
        final text = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        final sentence = RegExp(
          r'differ in [^.]*\.',
        ).firstMatch(text)?.group(0);
        expect(
          sentence,
          isNotNull,
          reason: '$path no longer enumerates how the variants differ',
        );
        return sentence!;
      }

      for (final path in documents) {
        // Scoped to the sentence that enumerates the differences, not the whole
        // document, which legitimately names the base's members when saying
        // what the base holds. Only this sentence claims a member differs, so
        // only this sentence can claim it wrongly.
        final sentence = differenceSentence(path);
        for (final name in members.keys) {
          expect(
            sentence,
            matches(RegExp(r'\b' + name + r'\b')),
            reason:
                '$path: `$name` is overridden per variant but is not listed '
                'among the differences',
          );
        }
        // A base member is only wrongly listed when *no* variant overrides it.
        // `getBrowserLocation` is on the base and the web variant specialises
        // it, so it is legitimately both.
        for (final name in baseMembers().keys) {
          if (members.containsKey(name)) continue;
          expect(
            sentence,
            isNot(matches(RegExp(r'\b' + name + r'\b'))),
            reason:
                '$path: `$name` lives on the shared base and no variant '
                'overrides it, yet it is listed as a per-variant difference',
          );
        }
      }
    });

    test('both documents count what each side holds', () {
      final perVariant = variantMembers().length;
      final onBase = baseMembers().length;

      // Spelled out, because that is how the documents write it, and the point
      // of the check is that the sentence a reader sees agrees with the source.
      const words = [
        'zero',
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'ten',
        'eleven',
        'twelve',
        'thirteen',
        'fourteen',
        'fifteen',
        'sixteen',
        'seventeen',
        'eighteen',
        'nineteen',
        'twenty',
      ];
      expect(
        perVariant + onBase,
        lessThan(words.length),
        reason: 'more members than this test can spell',
      );

      // Both numbers, because moving a member changes both and a check on one
      // of them alone leaves the other free to keep the figure it had. That is
      // not hypothetical: drawing the base took the per-variant count from
      // thirteen to four at the same moment as it put nine on the base.
      for (final path in documents) {
        final text = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          text,
          contains('differ in ${words[perVariant]} members'),
          reason:
              '$path: the variants differ in $perVariant members; the '
              'document states another number',
        );
        expect(
          text,
          contains('base holds ${words[onBase]} members'),
          reason:
              '$path: the shared base holds $onBase members; the document '
              'states another number',
        );
      }
    });

    test('no override restates the body it inherits', () {
      // Duplication *against* a supertype is never forced: an override that
      // evaluates exactly what it already inherits changes nothing and can be
      // deleted. Six such overrides were, and no reading of the variants alone
      // could have found them — the two sides write the same body in different
      // forms, `=> print(s);` here against `{ print(s); }` there, so only a
      // comparison that reduces both to their expression sees it.
      final base = File.fromUri(
        packageLibUri(
          'tom_basics',
        ).resolve('src/runtime/platform_neutral.dart'),
      ).readAsStringSync();
      final inherited = overrideBodies(base, 'TomFallbackPlatformUtils');
      expect(
        inherited,
        isNotEmpty,
        reason:
            'no members were read out of TomFallbackPlatformUtils; the '
            'comparison below would pass by finding nothing to compare',
      );

      final sources = {
        for (final variant in variants)
          variant: overrideBodies(
            variantSource(variant),
            'TomFlutterPlatformUtils',
          ),
        // The base is held to the same rule, and is the more likely offender:
        // it overrides nine members of a class that declares all nine.
        'base': baseMembers(),
      };

      sources.forEach((where, overridden) {
        overridden.forEach((name, body) {
          expect(
            body,
            isNot(equals(inherited[name])),
            reason:
                '$where overrides `$name` with the body it already inherits '
                'from TomFallbackPlatformUtils; delete the override',
          );
        });
      });
    });
  });

  group('the shared predicates, exercised without a variant', () {
    // What the extraction bought, and the reason the old deferral's own
    // argument pointed the other way. A conditional import means no host can
    // compile more than one variant, so while each variant carried its own copy
    // of the nine predicates, two of the three copies were untested *by
    // construction* — nothing could reach them. One copy on a base with no
    // conditional import can be instantiated anywhere, so these assertions hold
    // the logic every target uses rather than the copy this host happened to
    // select.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    /// Every predicate answer for [target], by name.
    Map<String, bool> answersFor(TargetPlatform target) {
      debugDefaultTargetPlatformOverride = target;
      final base = TomFlutterPlatformUtilsBase();
      return {
        'isDesktop': base.isDesktop(),
        'isMobile': base.isMobile(),
        'isFuchsia': base.isFuchsia(),
        'isWindows': base.isWindows(),
        'isLinux': base.isLinux(),
        'isMacOs': base.isMacOs(),
        'isAndroid': base.isAndroid(),
        'isIos': base.isIos(),
      };
    }

    test('each target answers exactly one operating-system predicate', () {
      // The property that makes the six OS predicates a partition rather than
      // six independent questions, checked over every target Flutter declares
      // — so a target added to the enum with no predicate behind it fails here
      // instead of answering `false` to all six.
      const osPredicates = [
        'isWindows',
        'isLinux',
        'isMacOs',
        'isAndroid',
        'isIos',
        'isFuchsia',
      ];
      for (final target in TargetPlatform.values) {
        final answers = answersFor(target);
        expect(
          osPredicates.where((name) => answers[name]!).toList(),
          hasLength(1),
          reason: '$target does not answer exactly one OS predicate',
        );
      }
    });

    test('the desktop and mobile families are the documented ones', () {
      const desktop = {
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      };
      const mobile = {TargetPlatform.android, TargetPlatform.iOS};

      for (final target in TargetPlatform.values) {
        final answers = answersFor(target);
        expect(
          answers['isDesktop'],
          desktop.contains(target),
          reason: '$target',
        );
        expect(answers['isMobile'], mobile.contains(target), reason: '$target');
      }
    });

    test('fuchsia is in neither family, which is why there is no total', () {
      // Stated in three documents as the reason `isDesktop() || isMobile()`
      // must not be assumed. Asserted here so it is a measured fact about the
      // enum rather than a remembered one.
      final answers = answersFor(TargetPlatform.fuchsia);

      expect(answers['isFuchsia'], isTrue);
      expect(answers['isDesktop'], isFalse);
      expect(answers['isMobile'], isFalse);
    });

    test('isWeb reports the build, not the target', () {
      // The one predicate that reads `kIsWeb` rather than the target, so it
      // does not move when the target does. On the VM it is false for every
      // one of them.
      for (final target in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = target;
        expect(
          TomFlutterPlatformUtilsBase().isWeb(),
          kIsWeb,
          reason: '$target',
        );
      }
    });

    test('the base refuses to build a client, which is a variant\'s job', () {
      // It is concrete so that the predicates can be reached, not so that it
      // can stand in for a variant. What it does not answer it inherits, and
      // what it inherits for `httpClient` is a refusal.
      expect(
        () => TomFlutterPlatformUtilsBase().httpClient(),
        throwsUnimplementedError,
      );
    });
  });

  group('the neutral fallback refuses networking', () {
    // Run against a real instance rather than against the source text. The
    // neutral variant is the one target-independent variant — it imports only
    // Flutter, `http` and the kernel — so it is constructible here, which the
    // web variant is not (`package:web` needs JS interop the VM cannot give
    // it). Two of the three variants are therefore directly exercisable from
    // this host, and this is the second one.

    Object neutralHttpClientError() {
      try {
        neutral.TomFlutterPlatformUtils().httpClient();
      } catch (error) {
        return error;
      }
      fail('the neutral fallback returned an HTTP client instead of throwing');
    }

    test('the refusal is permanent, not pending', () {
      // `isNot(isA<UnimplementedError>())` is the load-bearing half, and it is
      // not redundant with the line above it: in `dart:core`,
      // `UnimplementedError implements UnsupportedError`. A test asserting only
      // `isA<UnsupportedError>()` passes just as happily on the
      // `UnimplementedError` this replaced — it would have been green before
      // the change and proved nothing.
      //
      // The distinction is the whole point of the change. `UnimplementedError`
      // means "planned, not yet written", and reads as an invitation to finish
      // an implementation that is in fact complete: on a target with neither
      // `dart:io` nor `dart:js` there is no client to construct, ever.
      final error = neutralHttpClientError();
      expect(error, isA<UnsupportedError>());
      expect(
        error,
        isNot(isA<UnimplementedError>()),
        reason:
            'UnimplementedError says the operation is still to be written; '
            'this one is permanently unavailable on such a target',
      );
    });

    test('the message describes the condition rather than instructing', () {
      // What a caller gets is the message, and this one has to survive being
      // read out of a crash log by someone who does not know the module. So it
      // has to say what was unavailable and why — the two libraries whose
      // absence selects this variant are the why — rather than telling the
      // reader what to do about it in a sentence that was, for the whole life
      // of the previous message, missing a word ("You need initialize").
      final message = neutralHttpClientError().toString();
      expect(message, contains('dart:io'));
      expect(message, contains('dart:js'));
      expect(
        message,
        isNot(contains('You need')),
        reason: 'the message instructs the reader instead of naming the fault',
      );
    });

    test('both documents name the type the code actually throws', () {
      // Recomputed from the throw, not restated: the API summary named
      // `UnimplementedError` because it faithfully mirrored the code, and would
      // have gone on mirroring it into being wrong. `doc/runtime.md` said only
      // "throws", which was never false but told a reader nothing they could
      // catch on.
      final thrown = neutralHttpClientError().runtimeType.toString();
      for (final path in [
        'doc/api_reference/api_summary_runtime.md',
        'doc/runtime.md',
      ]) {
        final row = File(path)
            .readAsLinesSync()
            .where((l) => l.startsWith('|') && l.contains('throws'))
            .where((l) => l.contains('neutral'))
            .toList();
        expect(
          row,
          hasLength(1),
          reason:
              '$path has no single variant-table row saying the neutral '
              'fallback throws',
        );
        final named = RegExp(
          r'throws `(\w+)`',
        ).firstMatch(row.single)?.group(1);
        expect(
          named,
          thrown,
          reason: '$path names $named; the code throws $thrown',
        );
      }
    });
  });

  group('the getter hands out one instance', () {
    // `clientPlatformUtils` is a getter that *caches*: the first read builds
    // the variant, every later read answers the same object. Both documents say
    // so, and these tests are what hold them to it.
    //
    // It was a getter that constructed per read, and nothing observed that
    // either — the suite read it fourteen times and never looked at what came
    // back. The contract was free to move in either direction unnoticed, which
    // is why it now moves only with a test that says which way it went.
    tearDown(resetClientPlatformUtils);

    test('two reads return the same instance', () {
      final first = clientPlatformUtils;
      final second = clientPlatformUtils;
      expect(
        identical(first, second),
        isTrue,
        reason:
            'the getter built a second object; it has stopped caching, and '
            'both documents describe one instance per process',
      );
    });

    test('a read after registration is the registered instance', () {
      // The consequence a caller meets. The documented start-up pattern
      // registers one instance and reaches it through `TomPlatformUtils.current`
      // afterwards; anyone who instead reads the getter again — the natural
      // move, since it reads like a property — now holds the same object rather
      // than an equal-looking second one, so comparing the two for identity
      // means what a reader would expect it to mean.
      final alreadyRegistered = TomPlatformUtils.current;
      addTearDown(() => TomPlatformUtils.setCurrentPlatform(alreadyRegistered));

      final atStartup = clientPlatformUtils;
      TomPlatformUtils.setCurrentPlatform(atStartup);

      expect(TomPlatformUtils.current, same(atStartup));
      expect(
        clientPlatformUtils,
        same(atStartup),
        reason:
            'a later read yields a different object again; code comparing '
            'platform-utils identities is silently always false',
      );
    });

    test('the process environment is imported once, not per read', () {
      // What the cache actually saves, made observable. The merge is idempotent
      // against an untouched map, so the only way to see whether it happens is
      // to break the map first and watch whether a read repairs it.
      expect(
        Platform.environment,
        isNotEmpty,
        reason: 'test host is expected to expose some environment variables',
      );
      final key = Platform.environment.keys.first;
      final real = Platform.environment[key]!;

      const sentinel = 'overwritten to make the re-import visible';
      final utils = clientPlatformUtils;
      addTearDown(() => utils.getTomEnvVars()[key] = real);
      utils.getTomEnvVars()[key] = sentinel;

      // The control, and it is load-bearing. `getTomEnvVars` hands back the
      // static map itself rather than a copy, which is the only reason writing
      // to it is visible at all. Were it ever to return a copy, the overwrite
      // would land nowhere and both assertions below would say nothing.
      expect(
        utils.getTomEnvVars()[key],
        sentinel,
        reason:
            'getTomEnvVars no longer exposes the shared map, so the '
            'overwrite says nothing about what a read does',
      );

      expect(
        clientPlatformUtils.getTomEnvVars()[key],
        sentinel,
        reason:
            'reading the getter re-imported the process environment; it is '
            'constructing per read again',
      );

      // And the other half, which is what stops this from passing against a
      // variant that never imports the environment at all: after a reset the
      // next read constructs, and the construction repairs the map.
      resetClientPlatformUtils();
      expect(
        clientPlatformUtils.getTomEnvVars()[key],
        real,
        reason:
            'a freshly constructed instance did not import the process '
            'environment, so the assertion above observed nothing',
      );
    });

    test('a reset makes the next read build a new instance', () {
      // The seam the two assertions above rest on, asserted in its own right:
      // without it "one instance per process" would be indistinguishable from
      // "one instance, ever, that no test can get behind".
      final before = clientPlatformUtils;
      resetClientPlatformUtils();

      expect(clientPlatformUtils, isNot(same(before)));
    });
  });

  group('the shipped example runs', () {
    /// Every line [example.run] prints, joined.
    ///
    /// The example's output *is* its documentation — it is what a reader sees
    /// when they run the command in its header, and the only part of an
    /// example that survives being pasted into a bug report. So the checks
    /// below read what it printed rather than what its source says.
    String exampleOutput() {
      final printed = <String>[];
      runZoned(
        example.run,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      return printed.join('\n');
    }

    test('runtime_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      example.run();
    });

    test('the printed platform answer names what decided it', () {
      // Under `flutter test`, `defaultTargetPlatform` is android whatever
      // machine the harness is running on, and every predicate in every
      // variant reads it. So a developer on a Mac sees `isMobile=true` from a
      // module whose one job is platform detection, and for a long time the
      // example offered nothing to explain it — the number was there and the
      // cause was not.
      //
      // Printing the target beside the answer is what fixes that, and it has
      // to be the *effective* target rather than a sentence about defaults:
      // recomputed here from `defaultTargetPlatform` so that running the
      // example under a different harness, or on a device, keeps the printed
      // explanation true instead of leaving a frozen claim about android.
      final printed = exampleOutput();
      expect(
        printed,
        contains('$defaultTargetPlatform'),
        reason:
            'the example prints platform predicates without naming the '
            'Flutter target that decided them; on a desktop host the answer '
            'reads as a bug in the module',
      );
    });

    test('the printed answer agrees with the target it blames', () {
      // Naming a cause is worth nothing if it is the wrong cause. This checks
      // that the family the example reports really does follow from the target
      // it prints — so if the predicates were ever rewired to read the host
      // instead, the example's explanation would turn false here rather than
      // going on reassuring a reader who has no way to check it.
      final printed = exampleOutput();
      final reported = RegExp(r'isMobile=(true|false)').firstMatch(printed);
      expect(
        reported,
        isNotNull,
        reason: 'the example no longer reports the mobile predicate',
      );
      final targetIsMobile =
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      expect(
        reported!.group(1),
        '$targetIsMobile',
        reason:
            'the example reports isMobile=${reported.group(1)} while the '
            'target it prints, $defaultTargetPlatform, says otherwise',
      );
    });

    test('the example demonstrates the per-variant HTTP client', () {
      // `httpClient()` is one of the few members that genuinely differ between
      // the variants, and the Quick Start in `doc/runtime.md` leads with it —
      // yet the executable example, the one artifact that would break if the
      // call stopped working, never made it.
      final client = clientPlatformUtils.httpClient();
      addTearDown(client.close);
      expect(
        exampleOutput(),
        contains('${client.runtimeType}'),
        reason:
            'the example never obtains an HTTP client, so the member the '
            'module document opens with is demonstrated nowhere executable',
      );
    });
  });
}

/// A log output that keeps what it is given, so a test can read the lines the
/// logger actually wrote rather than assert they exist unseen.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      messages.add(convertToString(message));
    }
  }
}
