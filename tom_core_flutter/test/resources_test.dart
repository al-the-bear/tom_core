import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/resources/resources_example.dart' as example;

/// Tests for the resources module (`TomProperty` and its typed subclasses).
///
/// Each test installs a deterministic config provider, then constructs a
/// property and asserts the value resolved at construction.
///
/// The final group is not about behaviour but about what the module's four
/// documents say: the recommendation to prefer a typed subclass holds only for
/// the non-nullable value types, and an unqualified statement of it forbids the
/// one construction an optional property requires.
void main() {
  void installConfig(Map<String, Object> values) {
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
