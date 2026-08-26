import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/resources/resources_example.dart' as example;

/// Tests for the resources module (`TomProperty` and its typed subclasses).
///
/// Each test installs a deterministic config provider, then constructs a
/// property and asserts the value resolved at construction.
///
/// Two groups are not about behaviour but about what the module's documents
/// say. The first holds the four artefacts to the recommendation to prefer a
/// typed subclass *and* its nullable-`T` exception, because unqualified it
/// forbids the one construction an optional property requires. The second
/// holds the API summary to the failures the module actually throws — their
/// wording and their number — because throwing is this module's entire
/// failure contract and both sites fire during construction.
void main() {
  // `Object?`, not `Object`: the config map is a `Map<String, dynamic>` and a
  // null value is a case the module has to answer for (see 'a key configured
  // as null counts as absent'), so the helper has to be able to express it.
  void installConfig(Map<String, Object?> values) {
    TomConfigResourceProvider.setAppConfigProvider(
      TomConfigResourceProvider.from(values),
    );
  }

  setUp(() {
    // Default to an empty config; individual tests override as needed.
    installConfig({});
  });

  group('typed properties resolve their config value', () {
    test('TomStringProperty reads a String', () {
      installConfig({'app.title': 'My App'});
      final p = TomStringProperty('app.title');
      expect(p.get(), 'My App');
      expect(~p, 'My App'); // operator mirrors get()
    });

    test('TomIntProperty reads an int', () {
      installConfig({'app.retries': 3});
      expect(TomIntProperty('app.retries').get(), 3);
    });

    test('TomDoubleProperty reads a double', () {
      installConfig({'app.ratio': 1.5});
      expect(TomDoubleProperty('app.ratio').get(), 1.5);
    });

    test('TomBoolProperty reads a bool', () {
      installConfig({'app.flag': true});
      expect(TomBoolProperty('app.flag').get(), isTrue);
    });
  });

  group('withDefault', () {
    test('uses the config value when the key exists', () {
      installConfig({'app.retries': 7});
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 7);
    });

    test('falls back to the default when the key is absent', () {
      installConfig({});
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 5);
      expect(TomStringProperty.withDefault('app.title', 'Fallback').get(),
          'Fallback');
    });

    // Full-surface: every typed subclass exposes a `withDefault` named
    // constructor. Exercise all four across both branches (present key wins /
    // absent key falls back) so no subclass constructor is left uncovered.
    test('all four typed subclasses honour a present config value', () {
      installConfig({
        'app.title': 'Present',
        'app.retries': 9,
        'app.ratio': 2.5,
        'app.flag': true,
      });
      expect(TomStringProperty.withDefault('app.title', 'x').get(), 'Present');
      expect(TomIntProperty.withDefault('app.retries', 0).get(), 9);
      expect(TomDoubleProperty.withDefault('app.ratio', 0.0).get(), 2.5);
      expect(TomBoolProperty.withDefault('app.flag', false).get(), isTrue);
    });

    test('all four typed subclasses fall back when the key is absent', () {
      installConfig({});
      expect(TomStringProperty.withDefault('app.title', 'Fallback').get(),
          'Fallback');
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 5);
      expect(TomDoubleProperty.withDefault('app.ratio', 1.25).get(), 1.25);
      expect(TomBoolProperty.withDefault('app.flag', true).get(), isTrue);
    });
  });

  group('type mismatch', () {
    // tests §9(a): a present value that cannot be cast to T throws a
    // descriptive Exception naming the key — the type-mismatch branch of
    // `_getValue` had no coverage.
    test('a present value of the wrong type throws a descriptive Exception',
        () {
      installConfig({'app.title': 'not-an-int'});
      expect(
        () => TomIntProperty('app.title'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('app.title'), contains('not-an-int')),
          ),
        ),
      );
    });

    test('a default does not rescue a present value of the wrong type', () {
      // The asymmetry a reader is most likely to get wrong: `withDefault`
      // covers an *absent* key, not an unusable one. A wrong-typed value that
      // is present takes the cast branch before the default is ever consulted,
      // so supplying one does not turn a mistyped config entry into a working
      // property — which is right, because a typo'd value and a deliberate
      // omission are different mistakes and only one of them has an intended
      // fallback.
      installConfig({'app.retries': 'not-an-int'});
      expect(
        () => TomIntProperty.withDefault('app.retries', 5),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('app.retries'), contains('not-an-int')),
          ),
        ),
      );
    });
  });

  group('missing obligatory key', () {
    // tests §9(b): the no-default constructor must surface the intended
    // "Obligatory resource not found" Exception — not the opaque
    // LateInitializationError the unassigned `late` default field used to
    // throw (status_bug.md §17). RED before the fix.
    test('no-default constructor throws the descriptive obligatory-key error',
        () {
      installConfig({});
      expect(
        () => TomStringProperty('app.missing'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Obligatory'), contains('app.missing')),
          ),
        ),
      );
    });

    test('a key configured as null counts as absent', () {
      // `TomConfigResourceProvider.exists` is "resolves to a non-null object",
      // so a key present in the config with a null value is indistinguishable
      // from one that was never written. Worth pinning because the two look
      // different in a YAML file and identical here: `app.region:` with no
      // value does not satisfy an obligatory property.
      installConfig({'app.region': null});
      expect(
        () => TomStringProperty('app.region'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Obligatory'), contains('app.region')),
          ),
        ),
      );
    });
  });

  group('explicit null default (nullable T)', () {
    // tests §9 / status_bug.md §17 second defect: a `withDefault(key, null)`
    // over a nullable T must use the explicitly-supplied null, not fall
    // through the `_defaultValue != null` guard and throw. RED before the fix.
    test('withDefault(key, null) returns null when the key is absent', () {
      installConfig({});
      final p = TomProperty<String?>.withDefault('app.missing', null);
      expect(p.get(), isNull);
    });
  });

  group('the documents qualify the subclass recommendation', () {
    // Every artefact tells the reader to prefer a typed subclass, and that
    // advice is right four times out of five. The fifth is the group above:
    // the subclasses close over non-nullable String/int/double/bool, so an
    // optional value can only be written as the generic. A reader who is told
    // the rule but not its exception writes a sentinel default and tests for
    // it, or uses the generic believing they are breaking the contract.
    const artefacts = <String>[
      'lib/src/tomclient/resources/tom_properties.dart',
      'lib/src/tomclient/resources/readme.md',
      'doc/resources.md',
      'doc/api_reference/api_summary_resources.md',
    ];

    /// The three consumer-facing documents — the artefacts a reader who is not
    /// reading the source arrives at.
    const consumerDocs = <String>[
      'lib/src/tomclient/resources/readme.md',
      'doc/resources.md',
      'doc/api_reference/api_summary_resources.md',
    ];

    /// [file]'s text with emphasis and code markers removed, so a document is
    /// free to bold or quote any part of the rule without breaking the check.
    String plainTextOf(String file) =>
        File(file).readAsStringSync().replaceAll(RegExp(r'[*`\[\]]'), '');

    test('every artefact recommends the typed subclasses', () {
      // The recommendation itself is worth pinning: it is the reason the four
      // subclasses exist, and dropping it would make the exception below
      // read as blanket permission to use the generic everywhere.
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('subclass'),
          reason: '$artefact no longer points the reader at the typed '
              'subclasses, which are the intended form for the four '
              'non-nullable value types',
        );
      }
    });

    test('every artefact states the nullable-T exception to it', () {
      // The half that is easy to leave out, because the four subclasses cover
      // every case their author had in mind. Unqualified, the recommendation
      // forbids the only construction that expresses an optional value.
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('nullable'),
          reason: '$artefact states the subclass recommendation without its '
              'exception, so a reader who needs an optional property is told '
              'their only correct option is the one to avoid',
        );
      }
    });

    test('the construction no subclass can express is shown, and runs as '
        'shown', () {
      // A qualification without the construction beside it leaves the reader
      // knowing an exception exists but not how to write it, so each document
      // has to show it — and then the snippet it shows is run here, against
      // the key the documents themselves use. That is the link to behaviour:
      // not a text match between documents, but the printed line executing.
      const construction = 'TomProperty<String?>.withDefault(';
      for (final doc in consumerDocs) {
        expect(
          plainTextOf(doc),
          contains(construction),
          reason: '$doc names the nullable-T exception but does not show it; '
              'the qualification is only actionable with the construction '
              'beside it',
        );
      }

      installConfig({});
      final region = TomProperty<String?>.withDefault('app.region', null);
      expect(
        region.get(),
        isNull,
        reason: 'the documents print this construction as the way to hold an '
            'optional value; it no longer yields the absent value',
      );
    });
  });

  group('the documented failures are the ones the module throws', () {
    // Throwing is this module's whole failure contract: both constructors
    // resolve in their body, so the two throw sites are not error paths
    // reached after a successful construction — they are the two ways
    // construction fails, at whatever point in start-up the property is built.
    // A summary that omits them leaves the reader with neither the exception
    // type, the message shape, nor the fact that a wrong-typed *present* value
    // fails as hard as a missing one.
    const source = 'lib/src/tomclient/resources/tom_properties.dart';
    const summary = 'doc/api_reference/api_summary_resources.md';

    /// The message literal of every `throw Exception("...")` in [source].
    List<String> thrownMessagesOf(String file) =>
        RegExp(r'throw Exception\(\s*"([^"]*)"')
            .allMatches(File(file).readAsStringSync())
            .map((m) => m[1]!)
            .toList();

    /// [text] with runs of whitespace collapsed, so a document may re-wrap a
    /// long line without breaking a match. Code and emphasis markers go too,
    /// leaving the words themselves.
    String flattened(String text) =>
        text.replaceAll(RegExp(r'[*`\[\]]'), '').replaceAll(RegExp(r'\s+'), ' ');

    /// The body of [heading] in [file], up to the next `## `.
    String sectionOf(String file, String heading) {
      final text = File(file).readAsStringSync();
      final start = text.indexOf('\n## $heading\n');
      if (start < 0) return '';
      var rest = text.substring(start + heading.length + 5);
      final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
      return next == null ? rest : rest.substring(0, next.start);
    }

    test('the summary quotes the message shape each throw site produces', () {
      // Matches the fixed fragments *around* the interpolations rather than
      // whole sentences, so the summary is free to write the holes however
      // reads best (`<key>`, `<T>`) while the words a reader would grep a log
      // for stay tied to the source. Reword the throw and this fails.
      final summaryText = flattened(File(summary).readAsStringSync());
      final messages = thrownMessagesOf(source);
      var checked = 0;
      for (final message in messages) {
        for (final fragment in message.split(RegExp(r'\$\{[^}]*\}|\$\w+'))) {
          if (fragment.trim().length < 4) continue; // a gap between two holes
          checked++;
          expect(
            summaryText,
            contains(flattened(fragment)),
            reason: '$summary does not carry the wording of a message this '
                'module throws, so a reader who greps their log for it finds '
                'nothing:\n  $message',
          );
        }
      }
      // Vacuous if the throw sites stop being recognised as such.
      expect(checked, greaterThanOrEqualTo(4));
    });

    test('every throw site has a row in the Exceptions section', () {
      // The count, not the wording: a third failure added to `_getValue` is
      // exactly the change that would otherwise leave this section quietly
      // describing two of three.
      final rows = sectionOf(summary, 'Exceptions')
          .split('\n')
          .where((l) => l.startsWith('| ') && !l.startsWith('| ---'))
          .length;
      expect(
        rows - 1, // the header row
        thrownMessagesOf(source).length,
        reason: '$summary documents a different number of failures than '
            '$source throws',
      );
    });
  });

  group('the shipped example runs', () {
    test('resources_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // run() installs its own app config provider process-wide and does not
      // restore it — correct for an example, which owns the process, but this
      // suite does not, so the empty default is put back explicitly rather than
      // left to the next setUp to overwrite.
      addTearDown(() => installConfig({}));
      example.run();
    });
  });
}
