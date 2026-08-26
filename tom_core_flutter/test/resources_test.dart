import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/resources/resources_example.dart' as example;

/// Tests for the resources module (`TomProperty` and its typed subclasses).
///
/// Each test installs a deterministic config provider, then constructs a
/// property and asserts the value resolved at construction.
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
