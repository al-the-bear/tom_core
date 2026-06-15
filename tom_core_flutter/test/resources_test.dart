import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

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
  });

  group('missing obligatory key', () {
    test('no-default constructor throws when the key is absent', () {
      installConfig({});
      // The construction fails (intended); the surfaced error is a
      // LateInitializationError rather than the descriptive message — see the
      // documented limitation in doc/resources.md.
      expect(() => TomStringProperty('app.missing'), throwsA(anything));
    });
  });
}
