import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';
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
    // Every symbol in this module lives behind one exported file, and that file
    // pulls the variants in with a conditional `import` rather than an
    // `export`. So the barrel publishes exactly one name and keeps both
    // `allowsBadCertificateForHost` and `TomFlutterPlatformUtils` inside `src/`
    // — a distinction invisible from the source of any variant, which is how a
    // summary came to list an unreachable function under "Global Functions".

    test('the barrel publishes only clientPlatformUtils from this module', () {
      final barrel = File('lib/tom_core_flutter.dart').readAsStringSync();
      expect(
        barrel,
        contains(
          "export 'src/tomclient/runtime/platform_detection_client.dart';",
        ),
        reason:
            'the runtime module is no longer exported through its entry '
            'point; the documented surface has to be re-derived',
      );
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
      // could not work here anyway — only the IO variant declares a TLS
      // predicate, so exporting the selected variant would demand the same
      // symbol on all three targets — but the guarantee a reader needs is that
      // nothing escapes, and that is what the absence of `export` states.
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
    });

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
        'allowsBadCertificateForHost',
        'TomFlutterPlatformUtils',
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
      // where the contradiction lived: the summary carried
      // `allowsBadCertificateForHost` under a "Global Functions" heading while
      // the prose two files away called it not part of the public API, and the
      // index tabulated both withheld symbols beside the exported one with
      // nothing to distinguish them.
      final documents = [
        'doc/api_reference/api_summary_runtime.md',
        'doc/api_reference/api_summary_index.md',
      ];
      final withheld = RegExp(
        r'\b(allowsBadCertificateForHost|TomFlutterPlatformUtils)\b',
      );
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

    test('the module document keeps its statement that the hook is internal', () {
      // The summary's new section and this sentence are the two halves of the
      // agreement this pins; without the sentence the summary would be the only
      // place the reachability is stated, and the document a reader reaches
      // first would go quiet on it.
      // Whitespace-collapsed: the sentence is wrapped, so the phrase this looks
      // for is split across lines in the file and would never match as written.
      final runtimeDoc = File(
        'doc/runtime.md',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        runtimeDoc,
        contains('allowsBadCertificateForHost'),
        reason: 'doc/runtime.md dropped the certificate hook entirely',
      );
      expect(
        RegExp(
          r"allowsBadCertificateForHost.{0,400}?not part of the barrel's "
          r'public API',
        ).hasMatch(runtimeDoc),
        isTrue,
        reason:
            'doc/runtime.md no longer says the hook is outside the '
            'exported surface; it and the API summary would disagree',
      );
    });
  });

  group('the documented inventory of variant duplication', () {
    // The module document inventories what the three variants share and what
    // they differ in, and that inventory is the input to the standing decision
    // about extracting a shared base. It was written by hand and drifted twice
    // in the same breath: the list of differences omitted `toString()`, and the
    // count of duplicated members counted only the nine predicates, missing
    // `out` and `outError`. A hand-maintained census of a set the compiler can
    // enumerate is going to drift; these tests recompute it from the sources so
    // the document has to keep up.

    const variants = ['flutter_io', 'neutral', 'web'];

    /// The `@override` members of each variant, by member name then variant.
    Map<String, Map<String, String>> variantMembers() {
      final byName = <String, Map<String, String>>{};
      for (final variant in variants) {
        final source = File(
          'lib/src/tomclient/runtime/platform_detection_$variant.dart',
        ).readAsStringSync();
        overrideBodies(source, 'TomFlutterPlatformUtils').forEach((name, body) {
          byName.putIfAbsent(name, () => {})[variant] = body;
        });
      }
      expect(
        byName.values.every((byVariant) => byVariant.length == variants.length),
        isTrue,
        reason:
            'a member is not overridden in all three variants; the '
            'document describes a set where every member is',
      );
      return byName;
    }

    // Both documents state the inventory, and both had undercounted it. Holding
    // only one of them would leave the other free to drift — which is how the
    // module ended up with three descriptions of one set of files, no two of
    // them agreeing.
    const documents = [
      'doc/runtime.md',
      'doc/api_reference/api_summary_runtime.md',
    ];

    /// The sentence in [path] that enumerates the per-variant differences.
    String differenceSentence(String path) {
      final text = File(
        path,
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final sentence = RegExp(r'differ in [^.]*\.').firstMatch(text)?.group(0);
      expect(
        sentence,
        isNotNull,
        reason: '$path no longer enumerates how the variants differ',
      );
      return sentence!;
    }

    test('both documents list exactly the members that differ', () {
      final members = variantMembers();
      final differing = members.entries
          .where((e) => e.value.values.toSet().length > 1)
          .map((e) => e.key)
          .toSet();
      final shared = members.keys.toSet().difference(differing);

      for (final path in documents) {
        // Scoped to the sentence that enumerates the differences, not the whole
        // document, which legitimately names the shared members when saying
        // what the duplication consists of. Only this sentence claims a member
        // differs, so only this sentence can claim it wrongly.
        final sentence = differenceSentence(path);
        for (final name in differing) {
          expect(
            sentence,
            // Word-bounded: `out` would otherwise match inside any word that
            // happens to contain it, and silently pass a document that never
            // mentions the member.
            matches(RegExp(r'\b' + name + r'\b')),
            reason:
                '$path: `$name` differs between the variants but is not '
                'listed among the differences',
          );
        }
        for (final name in shared) {
          expect(
            sentence,
            isNot(matches(RegExp(r'\b' + name + r'\b'))),
            reason:
                '$path: `$name` is identical in all three variants but is '
                'listed as a per-variant difference',
          );
        }
      }
    });

    test('both documents count the members and the duplicates correctly', () {
      final members = variantMembers();
      final shared = members.values
          .where((byVariant) => byVariant.values.toSet().length == 1)
          .length;

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
        members.length,
        lessThan(words.length),
        reason: 'more members than this test can spell',
      );

      // Both numbers, because deleting a member moves both and a check on one
      // of them alone leaves the other free to keep the figure it had. That is
      // not hypothetical: removing the two console overrides took the total
      // from fifteen to thirteen at the same moment as it took the duplicate
      // count from eleven to nine.
      for (final path in documents) {
        final text = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          text,
          contains('${words[members.length]} members'),
          reason:
              '$path: each variant overrides ${members.length} members; '
              'the document states another number',
        );
        expect(
          text,
          contains('${words[shared]} members'),
          reason:
              '$path: the sources duplicate $shared members verbatim '
              'across the three variants; the document states another number',
        );
      }
    });

    test('no variant override restates the body it inherits', () {
      // The duplication between the variants is forced — they are selected by
      // conditional import, so shared behaviour has nowhere to live but the
      // base, and the base is in another package. Duplication *against* the
      // base is not forced: an override that evaluates exactly what
      // `TomFallbackPlatformUtils` already evaluates changes nothing and can
      // simply be deleted. Six of them were, and no reading of the variants
      // alone could have found them — the two sides write the same body in
      // different forms, `=> print(s);` here against `{ print(s); }` there, so
      // only a comparison that reduces both to their expression sees it.
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

      for (final variant in variants) {
        final source = File(
          'lib/src/tomclient/runtime/platform_detection_$variant.dart',
        ).readAsStringSync();
        overrideBodies(source, 'TomFlutterPlatformUtils').forEach((name, body) {
          expect(
            body,
            isNot(equals(inherited[name])),
            reason:
                '$variant overrides `$name` with the body it already '
                'inherits from TomFallbackPlatformUtils; delete the override',
          );
        });
      }
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

  group('the getter allocates on every read', () {
    // `clientPlatformUtils` is a getter that constructs, and both documents say
    // so — "each read constructs a fresh `TomPlatformUtils`". Nothing observed
    // it. The suite read the getter fourteen times and never once looked at
    // what it handed back, so the contract was free to move in either
    // direction without a single test noticing.
    //
    // Whether it *should* move is genuinely open: every construction on this
    // variant re-copies the whole process environment into the kernel's static
    // env-var map, work a cached instance would do once. These tests take no
    // position on that. They record what the code does now, so that changing
    // it has to be a decision rather than a side effect — and so that whichever
    // way the question is answered, the answer arrives with a test that says
    // what was chosen.

    test('two reads return distinct instances', () {
      final first = clientPlatformUtils;
      final second = clientPlatformUtils;
      expect(
        identical(first, second),
        isFalse,
        reason:
            'the getter returned the same object twice; it has started '
            'caching, and both documents still describe a fresh instance '
            'per read',
      );
    });

    test('a read after registration is not the registered instance', () {
      // The consequence of the line above, and the one that can bite a caller.
      // The documented start-up pattern registers one instance and reaches it
      // through `TomPlatformUtils.current` afterwards; anyone who instead reads
      // the getter again — the natural move, since it reads like a property —
      // holds a different object. Comparing the two for identity is therefore
      // wrong today and would become right under a cached getter, which is
      // exactly why which of the two it is belongs in a test rather than in a
      // reader's assumption.
      final alreadyRegistered = TomPlatformUtils.current;
      addTearDown(() => TomPlatformUtils.setCurrentPlatform(alreadyRegistered));

      final atStartup = clientPlatformUtils;
      TomPlatformUtils.setCurrentPlatform(atStartup);
      expect(TomPlatformUtils.current, same(atStartup));
      expect(
        clientPlatformUtils,
        isNot(same(atStartup)),
        reason:
            'a later read now yields the registered instance; code that '
            'compares platform-utils identities changes meaning',
      );
    });

    test('each read re-imports the process environment', () {
      // What the repeated construction actually costs, made observable. The
      // merge is idempotent against an untouched map, so the only way to watch
      // it happen is to break the map first and see a construction repair it.
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
      // to it is visible to anyone else. Were it ever to return a copy, the
      // overwrite would land nowhere, the key would still hold its real value,
      // and the assertion below would pass having observed nothing at all.
      expect(
        utils.getTomEnvVars()[key],
        sentinel,
        reason:
            'getTomEnvVars no longer exposes the shared map, so the '
            'overwrite says nothing about what a second construction does',
      );

      final reconstructed = clientPlatformUtils;
      expect(
        reconstructed.getTomEnvVars()[key],
        real,
        reason:
            'constructing the utils a second time did not re-import the '
            'process environment; the getter is no longer doing the work '
            'per read',
      );
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
