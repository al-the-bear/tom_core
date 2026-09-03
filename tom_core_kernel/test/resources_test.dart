import 'dart:convert';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // ===========================================================================
  // TomTextResourceProvider Tests
  // ===========================================================================
  group('TomTextResourceProvider', () {
    // Bootstrap each test with an empty bundle. This is an install, not a
    // reset: it replaces whatever the previous test left behind and bumps
    // `appResourcesRevision` like any other install. The actual reset is
    // `clearAppResourceProvider`, which returns the process to
    // un-bootstrapped without bumping; it is `@visibleForTesting` and the
    // "bootstrap contract" group below is what exercises it. Installing is
    // what this group wants, because its tests read `getAppResources()` and
    // would throw `not_installed` against a cleared process.
    setUp(() {
      TomTextResourceProvider.loader = null;
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({}),
      );
    });

    // -------------------------------------------------------------------------
    // Constructor Tests
    // -------------------------------------------------------------------------
    group('constructor', () {
      test(
        'should create provider with empty resources when no loader is set',
        () {
          TomTextResourceProvider.loader = null;
          final provider = TomTextResourceProvider();
          expect(provider.resources, isEmpty);
        },
      );

      test('should create provider using loader function when set', () {
        TomTextResourceProvider.loader = () => {'key': 'value'};
        final provider = TomTextResourceProvider();
        expect(provider.resources, equals({'key': 'value'}));
      });

      test('should call loader function exactly once during construction', () {
        int callCount = 0;
        TomTextResourceProvider.loader = () {
          callCount++;
          return {'count': callCount};
        };
        final provider = TomTextResourceProvider();
        expect(callCount, equals(1));
        expect(provider.resources['count'], equals(1));
      });
    });

    group('TomTextResourceProvider.load', () {
      test('should create provider from custom loader function', () {
        final provider = TomTextResourceProvider.load(() => {'custom': 'data'});
        expect(provider.resources, equals({'custom': 'data'}));
      });

      test('should ignore static loader when using named constructor', () {
        TomTextResourceProvider.loader = () => {'static': 'loader'};
        final provider = TomTextResourceProvider.load(
          () => {'named': 'constructor'},
        );
        expect(provider.resources, equals({'named': 'constructor'}));
        expect(provider.resources.containsKey('static'), isFalse);
      });

      test('should support nested map structures', () {
        final provider = TomTextResourceProvider.load(
          () => {
            'level1': {
              'level2': {'level3': 'deep value'},
            },
          },
        );
        expect(
          provider.resources['level1']['level2']['level3'],
          equals('deep value'),
        );
      });
    });

    group('TomTextResourceProvider.from', () {
      test('should create provider from existing map', () {
        final provider = TomTextResourceProvider.from({'existing': 'map'});
        expect(provider.resources, equals({'existing': 'map'}));
      });

      test('should create provider from empty map', () {
        final provider = TomTextResourceProvider.from({});
        expect(provider.resources, isEmpty);
      });

      test('should preserve nested structure', () {
        final nestedMap = {
          'app': {
            'name': 'TestApp',
            'settings': {'theme': 'dark'},
          },
        };
        final provider = TomTextResourceProvider.from(nestedMap);
        expect(provider.resources, equals(nestedMap));
      });

      test('should reference same map object', () {
        final originalMap = {'key': 'value'};
        final provider = TomTextResourceProvider.from(originalMap);
        originalMap['key'] = 'modified';
        expect(provider.resources['key'], equals('modified'));
      });
    });

    // -------------------------------------------------------------------------
    // Static Methods Tests
    // -------------------------------------------------------------------------
    group('setAppResourceProvider', () {
      test('should set the singleton provider instance', () {
        final customProvider = TomTextResourceProvider.from({'custom': 'data'});
        TomTextResourceProvider.setAppResourceProvider(customProvider);
        final retrieved = TomTextResourceProvider.getAppResources();
        expect(retrieved.resources, equals({'custom': 'data'}));
      });

      test('should replace existing singleton provider', () {
        final firstProvider = TomTextResourceProvider.from({'first': 'data'});
        final secondProvider = TomTextResourceProvider.from({'second': 'data'});
        TomTextResourceProvider.setAppResourceProvider(firstProvider);
        TomTextResourceProvider.setAppResourceProvider(secondProvider);
        final retrieved = TomTextResourceProvider.getAppResources();
        expect(retrieved.resources, equals({'second': 'data'}));
      });
    });

    group('getAppResources', () {
      test('should return singleton instance', () {
        final provider1 = TomTextResourceProvider.getAppResources();
        final provider2 = TomTextResourceProvider.getAppResources();
        expect(identical(provider1, provider2), isTrue);
      });

      test(
        'should create instance using loader if set and no instance exists',
        () {
          TomTextResourceProvider.loader = () => {'loaded': 'resource'};
          // Install a provider built by the default constructor, which is the
          // only one that consults `loader`. Installing is what makes the
          // loader's output reachable through `getAppResources()` — the
          // getter never builds a provider of its own.
          TomTextResourceProvider.setAppResourceProvider(
            TomTextResourceProvider(),
          );
          final provider = TomTextResourceProvider.getAppResources();
          expect(provider.resources, equals({'loaded': 'resource'}));
        },
      );

      test('should return same provider on subsequent calls', () {
        TomTextResourceProvider.loader = () => {'test': 'value'};
        TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider(),
        );
        final first = TomTextResourceProvider.getAppResources();
        final second = TomTextResourceProvider.getAppResources();
        expect(identical(first, second), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // exists() Tests
    // -------------------------------------------------------------------------
    group('exists', () {
      test('should return true for flat key that exists', () {
        final provider = TomTextResourceProvider.from({'greeting': 'Hello'});
        expect(provider.exists('greeting'), isTrue);
      });

      test('should return false for flat key that does not exist', () {
        final provider = TomTextResourceProvider.from({'greeting': 'Hello'});
        expect(provider.exists('farewell'), isFalse);
      });

      test('should return true for nested key using dot notation', () {
        final provider = TomTextResourceProvider.from({
          'messages': {'welcome': 'Welcome!'},
        });
        expect(provider.exists('messages.welcome'), isTrue);
      });

      test('should return false for nested key that does not exist', () {
        final provider = TomTextResourceProvider.from({
          'messages': {'welcome': 'Welcome!'},
        });
        expect(provider.exists('messages.goodbye'), isFalse);
      });

      test(
        'should return false for deeply nested path that does not exist',
        () {
          final provider = TomTextResourceProvider.from({
            'level1': {'level2': 'value'},
          });
          expect(provider.exists('level1.level2.level3'), isFalse);
        },
      );

      test('should return true for deeply nested path that exists', () {
        final provider = TomTextResourceProvider.from({
          'level1': {
            'level2': {'level3': 'deep value'},
          },
        });
        expect(provider.exists('level1.level2.level3'), isTrue);
      });

      test('should return true for an empty key the bundle contains', () {
        // '' is a legal flat key, not a malformed one. Splitting it on '.'
        // yields a single empty segment, which `containsKey` finds like any
        // other, so the value resolves.
        final provider = TomTextResourceProvider.from({'': 'empty key'});
        expect(provider.exists(''), isTrue);
        expect(provider.getText(''), equals('empty key'));
      });

      test('should return false for non-string value at path', () {
        final provider = TomTextResourceProvider.from({'number': 42});
        expect(provider.exists('number'), isFalse);
      });

      test('should return false for map value at path', () {
        final provider = TomTextResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.exists('nested'), isFalse);
      });

      test('should return false for list value at path', () {
        final provider = TomTextResourceProvider.from({
          'items': ['a', 'b', 'c'],
        });
        expect(provider.exists('items'), isFalse);
      });

      test(
        'should return false when path contains non-existent intermediate key',
        () {
          final provider = TomTextResourceProvider.from({
            'root': {'child': 'value'},
          });
          expect(provider.exists('root.missing.child'), isFalse);
        },
      );
    });

    // -------------------------------------------------------------------------
    // getText() Tests
    // -------------------------------------------------------------------------
    group('getText', () {
      test('should return value for flat key', () {
        final provider = TomTextResourceProvider.from({'title': 'App Title'});
        expect(provider.getText('title'), equals('App Title'));
      });

      test('should return key itself when key does not exist', () {
        final provider = TomTextResourceProvider.from({});
        expect(provider.getText('missing.key'), equals('missing.key'));
      });

      test('should return value for nested key using dot notation', () {
        final provider = TomTextResourceProvider.from({
          'screens': {
            'home': {'title': 'Home Screen'},
          },
        });
        expect(provider.getText('screens.home.title'), equals('Home Screen'));
      });

      test('should return key when nested path does not exist', () {
        final provider = TomTextResourceProvider.from({
          'screens': {'home': {}},
        });
        expect(
          provider.getText('screens.home.missing'),
          equals('screens.home.missing'),
        );
      });

      test('should return key when intermediate path is not a map', () {
        final provider = TomTextResourceProvider.from({'screens': 'not a map'});
        expect(
          provider.getText('screens.home.title'),
          equals('screens.home.title'),
        );
      });

      test('should return empty string value when stored', () {
        final provider = TomTextResourceProvider.from({'empty': ''});
        expect(provider.getText('empty'), equals(''));
      });

      test('should return string with special characters', () {
        final provider = TomTextResourceProvider.from({
          'special': 'Hello, World! 🌍 <html> & "quotes"',
        });
        expect(
          provider.getText('special'),
          equals('Hello, World! 🌍 <html> & "quotes"'),
        );
      });

      test('should return string with unicode characters', () {
        final provider = TomTextResourceProvider.from({'unicode': '日本語テキスト'});
        expect(provider.getText('unicode'), equals('日本語テキスト'));
      });

      test('should return key when value is not a string', () {
        final provider = TomTextResourceProvider.from({'number': 42});
        expect(provider.getText('number'), equals('number'));
      });

      test('should return key when value is a map', () {
        final provider = TomTextResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.getText('nested'), equals('nested'));
      });

      test('should handle multiple levels of nesting', () {
        final provider = TomTextResourceProvider.from({
          'a': {
            'b': {
              'c': {'d': 'deeply nested value'},
            },
          },
        });
        expect(provider.getText('a.b.c.d'), equals('deeply nested value'));
      });
    });

    // -------------------------------------------------------------------------
    // getTextOrNull Tests
    // -------------------------------------------------------------------------
    group('getTextOrNull', () {
      test('should return the value for a flat key', () {
        final provider = TomTextResourceProvider.from({'greeting': 'Hello'});
        expect(provider.getTextOrNull('greeting'), equals('Hello'));
      });

      test('should return the value for a hierarchical path', () {
        final provider = TomTextResourceProvider.from({
          'app': {'title': 'My App'},
        });
        expect(provider.getTextOrNull('app.title'), equals('My App'));
      });

      test('should return null for a missing key', () {
        final provider = TomTextResourceProvider.from({'greeting': 'Hello'});
        expect(provider.getTextOrNull('unknown'), isNull);
      });

      test('should return null when the value is not a String', () {
        final provider = TomTextResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.getTextOrNull('nested'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // getObject Tests
    // -------------------------------------------------------------------------
    group('getObject', () {
      test('should return a non-String value for a flat key', () {
        final provider = TomTextResourceProvider.from({'count': 42});
        final value = provider.getObject('count');
        expect(value, isA<int>());
        expect(value, equals(42));
      });

      test('should return a nested map for a path ending at a map', () {
        final provider = TomTextResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.getObject('nested'), equals({'key': 'value'}));
      });

      test('should return the key itself for a missing path', () {
        final provider = TomTextResourceProvider.from({'count': 42});
        expect(provider.getObject('unknown'), equals('unknown'));
      });

      test('should return an arbitrary object identically, read through the '
          'installed singleton', () {
        // The case the object family exists for, and the one the module
        // documentation names: a look-and-feel value (a TextStyle, a Color)
        // living in the text bundle beside the strings it styles. Not a
        // primitive, and read the way an application reads it.
        const heading = _UiValue('heading');
        TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider.from({
            'styles': {'heading': heading},
            'labels': {'heading': 'Overview'},
          }),
        );
        final resources = TomTextResourceProvider.getAppResources();

        expect(
          identical(resources.getObject('styles.heading'), heading),
          isTrue,
        );
        expect(resources.existsObject('styles.heading'), isTrue);

        // ... and the reason it must not be read with the String family: to
        // `getText`, a non-String value is absent, so it echoes the key. That
        // is what "text accessor" means — not that the provider is
        // Strings-only.
        expect(resources.getText('styles.heading'), equals('styles.heading'));
        expect(resources.exists('styles.heading'), isFalse);

        // The strings in the same bundle are unaffected.
        expect(resources.getText('labels.heading'), equals('Overview'));
      });
    });

    // -------------------------------------------------------------------------
    // getObjectOrNull Tests
    // -------------------------------------------------------------------------
    group('getObjectOrNull', () {
      test('should return a non-String value for a flat key', () {
        final provider = TomTextResourceProvider.from({'flag': true});
        expect(provider.getObjectOrNull('flag'), isTrue);
      });

      test('should return null for a missing path', () {
        final provider = TomTextResourceProvider.from({'flag': true});
        expect(provider.getObjectOrNull('unknown'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // existsObject Tests
    // -------------------------------------------------------------------------
    group('existsObject', () {
      test('should return true for a non-String value', () {
        final provider = TomTextResourceProvider.from({'count': 42});
        expect(provider.existsObject('count'), isTrue);
      });

      test('should return true for a hierarchical path', () {
        final provider = TomTextResourceProvider.from({
          'nested': {'key': 99},
        });
        expect(provider.existsObject('nested.key'), isTrue);
      });

      test('should return false for a missing path', () {
        final provider = TomTextResourceProvider.from({'count': 42});
        expect(provider.existsObject('unknown'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // resources Field Tests
    // -------------------------------------------------------------------------
    group('resources field', () {
      test('should be modifiable after creation', () {
        final provider = TomTextResourceProvider.from({});
        provider.resources['new'] = 'value';
        expect(provider.getText('new'), equals('value'));
      });

      test('should support adding nested structures after creation', () {
        final provider = TomTextResourceProvider.from({});
        provider.resources['section'] = {'key': 'value'};
        expect(provider.getText('section.key'), equals('value'));
      });
    });
  });

  // ===========================================================================
  // TomConfigResourceProvider Tests
  // ===========================================================================
  group('TomConfigResourceProvider', () {
    // Bootstrap each test with an empty bundle, for the reason given on the
    // `TomTextResourceProvider` group above: this is an install, not a reset,
    // and these tests need an installed provider to read from.
    setUp(() {
      TomConfigResourceProvider.loader = null;
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
    });

    // -------------------------------------------------------------------------
    // Constructor Tests
    // -------------------------------------------------------------------------
    group('constructor', () {
      test(
        'should create provider with empty resources when no loader is set',
        () {
          TomConfigResourceProvider.loader = null;
          final provider = TomConfigResourceProvider();
          expect(provider.resources, isEmpty);
        },
      );

      test('should create provider using loader function when set', () {
        TomConfigResourceProvider.loader = () => {'setting': true};
        final provider = TomConfigResourceProvider();
        expect(provider.resources, equals({'setting': true}));
      });

      test('should call loader function exactly once during construction', () {
        int callCount = 0;
        TomConfigResourceProvider.loader = () {
          callCount++;
          return {'count': callCount};
        };
        final provider = TomConfigResourceProvider();
        expect(callCount, equals(1));
        expect(provider.resources['count'], equals(1));
      });
    });

    group('TomConfigResourceProvider.load', () {
      test('should create provider from custom loader function', () {
        final provider = TomConfigResourceProvider.load(
          () => {'custom': 'config'},
        );
        expect(provider.resources, equals({'custom': 'config'}));
      });

      test('should ignore static loader when using named constructor', () {
        TomConfigResourceProvider.loader = () => {'static': 'loader'};
        final provider = TomConfigResourceProvider.load(
          () => {'named': 'constructor'},
        );
        expect(provider.resources, equals({'named': 'constructor'}));
        expect(provider.resources.containsKey('static'), isFalse);
      });

      test('should support nested map structures', () {
        final provider = TomConfigResourceProvider.load(
          () => {
            'database': {
              'connection': {'pool': 10},
            },
          },
        );
        expect(
          provider.resources['database']['connection']['pool'],
          equals(10),
        );
      });
    });

    group('TomConfigResourceProvider.from', () {
      test('should create provider from existing map', () {
        final provider = TomConfigResourceProvider.from({'existing': 'config'});
        expect(provider.resources, equals({'existing': 'config'}));
      });

      test('should create provider from empty map', () {
        final provider = TomConfigResourceProvider.from({});
        expect(provider.resources, isEmpty);
      });

      test('should preserve mixed type values', () {
        final mixedMap = {
          'string': 'value',
          'number': 42,
          'boolean': true,
          'list': [1, 2, 3],
          'nested': {'key': 'value'},
        };
        final provider = TomConfigResourceProvider.from(mixedMap);
        expect(provider.resources, equals(mixedMap));
      });

      test('should reference same map object', () {
        final originalMap = {'key': 'value'};
        final provider = TomConfigResourceProvider.from(originalMap);
        originalMap['key'] = 'modified';
        expect(provider.resources['key'], equals('modified'));
      });
    });

    // -------------------------------------------------------------------------
    // Static Methods Tests
    // -------------------------------------------------------------------------
    group('setAppConfigProvider', () {
      test('should set the singleton config provider instance', () {
        final customProvider = TomConfigResourceProvider.from({'custom': 123});
        TomConfigResourceProvider.setAppConfigProvider(customProvider);
        final retrieved = TomConfigResourceProvider.getAppConfig();
        expect(retrieved.resources, equals({'custom': 123}));
      });

      test('should replace existing singleton provider', () {
        final firstProvider = TomConfigResourceProvider.from({'first': 1});
        final secondProvider = TomConfigResourceProvider.from({'second': 2});
        TomConfigResourceProvider.setAppConfigProvider(firstProvider);
        TomConfigResourceProvider.setAppConfigProvider(secondProvider);
        final retrieved = TomConfigResourceProvider.getAppConfig();
        expect(retrieved.resources, equals({'second': 2}));
      });
    });

    group('getAppConfig', () {
      test('should return singleton instance', () {
        final provider1 = TomConfigResourceProvider.getAppConfig();
        final provider2 = TomConfigResourceProvider.getAppConfig();
        expect(identical(provider1, provider2), isTrue);
      });

      test('should create instance using loader if set', () {
        TomConfigResourceProvider.loader = () => {'loaded': 'config'};
        TomConfigResourceProvider.setAppConfigProvider(
          TomConfigResourceProvider(),
        );
        final provider = TomConfigResourceProvider.getAppConfig();
        expect(provider.resources, equals({'loaded': 'config'}));
      });

      test('should return same provider on subsequent calls', () {
        TomConfigResourceProvider.loader = () => {'test': 'config'};
        TomConfigResourceProvider.setAppConfigProvider(
          TomConfigResourceProvider(),
        );
        final first = TomConfigResourceProvider.getAppConfig();
        final second = TomConfigResourceProvider.getAppConfig();
        expect(identical(first, second), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // exists() Tests
    // -------------------------------------------------------------------------
    group('exists', () {
      test('should return true for flat key that exists', () {
        final provider = TomConfigResourceProvider.from({'timeout': 5000});
        expect(provider.exists('timeout'), isTrue);
      });

      test('should return false for flat key that does not exist', () {
        final provider = TomConfigResourceProvider.from({'timeout': 5000});
        expect(provider.exists('retries'), isFalse);
      });

      test('should return true for nested key using dot notation', () {
        final provider = TomConfigResourceProvider.from({
          'api': {'baseUrl': 'https://example.com'},
        });
        expect(provider.exists('api.baseUrl'), isTrue);
      });

      test('should return false for nested key that does not exist', () {
        final provider = TomConfigResourceProvider.from({
          'api': {'baseUrl': 'https://example.com'},
        });
        expect(provider.exists('api.timeout'), isFalse);
      });

      test('should return true for deeply nested path', () {
        final provider = TomConfigResourceProvider.from({
          'level1': {
            'level2': {'level3': 42},
          },
        });
        expect(provider.exists('level1.level2.level3'), isTrue);
      });

      test('should return true for any value type at path', () {
        final provider = TomConfigResourceProvider.from({
          'string': 'value',
          'number': 42,
          'boolean': false,
          'list': [1, 2, 3],
        });
        expect(provider.exists('string'), isTrue);
        expect(provider.exists('number'), isTrue);
        expect(provider.exists('boolean'), isTrue);
        expect(provider.exists('list'), isTrue);
      });

      test('should return false for a key present with a null value', () {
        // `exists` is `_resolveObjectOrNull(...) != null`, and that helper
        // returns null both for an absent key and for one holding null, so it
        // cannot tell the two apart. See the 'shared resolution contract' group
        // for the full behaviour and the `resources.containsKey` escape hatch.
        final provider = TomConfigResourceProvider.from({'nullable': null});
        expect(provider.exists('nullable'), isFalse);
        expect(provider.resources.containsKey('nullable'), isTrue);
      });

      test('should return true for nested map value', () {
        final provider = TomConfigResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.exists('nested'), isTrue);
      });

      test(
        'should return false when path contains non-existent intermediate key',
        () {
          final provider = TomConfigResourceProvider.from({
            'root': {'child': 'value'},
          });
          expect(provider.exists('root.missing.child'), isFalse);
        },
      );
    });

    // -------------------------------------------------------------------------
    // getObject() Tests (returns Object for config)
    // -------------------------------------------------------------------------
    group('getObject', () {
      test('should return string value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'baseUrl': 'https://api.example.com',
        });
        expect(
          provider.getObject('baseUrl'),
          equals('https://api.example.com'),
        );
      });

      test('should return integer value for flat key', () {
        final provider = TomConfigResourceProvider.from({'port': 8080});
        expect(provider.getObject('port'), equals(8080));
      });

      test('should return boolean value for flat key', () {
        final provider = TomConfigResourceProvider.from({'enabled': true});
        expect(provider.getObject('enabled'), equals(true));
      });

      test('should return double value for flat key', () {
        final provider = TomConfigResourceProvider.from({'rate': 0.05});
        expect(provider.getObject('rate'), equals(0.05));
      });

      test('should return list value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'hosts': ['host1.com', 'host2.com'],
        });
        expect(provider.getObject('hosts'), equals(['host1.com', 'host2.com']));
      });

      test('should return map value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'database': {'host': 'localhost', 'port': 5432},
        });
        expect(
          provider.getObject('database'),
          equals({'host': 'localhost', 'port': 5432}),
        );
      });

      test('should return key itself when key does not exist', () {
        final provider = TomConfigResourceProvider.from({});
        expect(provider.getObject('missing.key'), equals('missing.key'));
      });

      test('should return value for nested key using dot notation', () {
        final provider = TomConfigResourceProvider.from({
          'database': {
            'connection': {'maxPoolSize': 25},
          },
        });
        expect(
          provider.getObject('database.connection.maxPoolSize'),
          equals(25),
        );
      });

      test('should return key when nested path does not exist', () {
        final provider = TomConfigResourceProvider.from({
          'database': {'connection': {}},
        });
        expect(
          provider.getObject('database.connection.missing'),
          equals('database.connection.missing'),
        );
      });

      test('should return key when intermediate path is not a map', () {
        final provider = TomConfigResourceProvider.from({
          'database': 'not a map',
        });
        expect(
          provider.getObject('database.connection.pool'),
          equals('database.connection.pool'),
        );
      });

      test('should handle multiple levels of nesting with mixed types', () {
        final provider = TomConfigResourceProvider.from({
          'settings': {
            'features': {
              'experimental': {'enabled': false, 'version': 2},
            },
          },
        });
        expect(
          provider.getObject('settings.features.experimental.enabled'),
          equals(false),
        );
        expect(
          provider.getObject('settings.features.experimental.version'),
          equals(2),
        );
      });

      test('should return nested map when path ends at map', () {
        final provider = TomConfigResourceProvider.from({
          'api': {
            'v1': {'baseUrl': 'https://v1.api.com'},
          },
        });
        expect(
          provider.getObject('api.v1'),
          equals({'baseUrl': 'https://v1.api.com'}),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Casting a Config Value
    // -------------------------------------------------------------------------
    //
    // `getObject` returns `Object` and echoes the key back on a miss, so the
    // direct `as int` that reads so naturally throws on exactly the case the
    // lenient fallback exists to survive — and throws a `TypeError` that names
    // `String` and `int` and never names the key that was missing.
    //
    // A nullable cast does not rescue it either: the miss value is a non-null
    // `String`, so `as int?` throws just as hard. These tests pin both the trap
    // and the two forms that actually work, because the documentation now
    // teaches them.
    group('casting a config value', () {
      final provider = TomConfigResourceProvider.from({
        'api': {'timeout': 30000},
      });

      test('a direct cast succeeds when the key is present', () {
        expect(provider.getObject('api.timeout') as int, equals(30000));
      });

      test('a direct cast throws when the key is absent', () {
        expect(
          () => provider.getObject('api.retries') as int,
          throwsA(isA<TypeError>()),
        );
      });

      test(
        'a nullable cast throws too — the miss value is a String, not null',
        () {
          // The obvious defensive move does not work, which is why the guarded
          // forms below are the documented ones.
          expect(
            () => provider.getObject('api.retries') as int?,
            throwsA(isA<TypeError>()),
          );
        },
      );

      test('getObjectOrNull returns null on a miss, so `as int?` is safe', () {
        expect(provider.getObjectOrNull('api.retries'), isNull);
        expect(provider.getObjectOrNull('api.retries') as int? ?? 3, equals(3));
      });

      test('getObjectOrNull returns the value on a hit', () {
        expect(
          provider.getObjectOrNull('api.timeout') as int? ?? 3,
          equals(30000),
        );
      });

      test('guarding with exists() is the two-lookup equivalent', () {
        int read(String key, int fallback) =>
            provider.exists(key) ? provider.getObject(key) as int : fallback;

        expect(read('api.timeout', 5000), equals(30000));
        expect(read('api.retries', 5000), equals(5000));
      });
    });

    // -------------------------------------------------------------------------
    // resources Field Tests
    // -------------------------------------------------------------------------
    group('resources field', () {
      test('should be modifiable after creation', () {
        final provider = TomConfigResourceProvider.from({});
        provider.resources['new'] = 42;
        expect(provider.getObject('new'), equals(42));
      });

      test('should support adding nested structures after creation', () {
        final provider = TomConfigResourceProvider.from({});
        provider.resources['section'] = {'key': 100};
        expect(provider.getObject('section.key'), equals(100));
      });

      test('should support updating existing values', () {
        final provider = TomConfigResourceProvider.from({'value': 1});
        provider.resources['value'] = 2;
        expect(provider.getObject('value'), equals(2));
      });
    });
  });

  // ===========================================================================
  // Bootstrap Contract
  // ===========================================================================
  //
  // Both providers must be installed explicitly before anything reads them.
  // A lazy path — the first `getAppResources()` building a provider from the
  // static `loader` — would install a bundle without bumping
  // `appResourcesRevision`. Observers registered before the first lookup
  // (`TomObservableEnum` re-derives its labels from that counter) would never
  // hear about the bundle that the lookup itself had just loaded, and would
  // keep showing raw keys until some unrelated later change moved the counter.
  //
  // These tests pin the contract that rules that out: there is no way to
  // install a bundle except through `setAppResourceProvider`, which notifies.
  // The counter and the installed bundle cannot disagree because only one
  // thing installs.
  group('bootstrap contract', () {
    setUp(() {
      TomTextResourceProvider.loader = null;
      TomConfigResourceProvider.loader = null;
      TomTextResourceProvider.clearAppResourceProvider();
      TomConfigResourceProvider.clearAppConfigProvider();
    });

    tearDown(() {
      // Leave the process bootstrapped for whatever runs next.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({}),
      );
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
    });

    test('getAppResources throws before a text provider is installed', () {
      expect(
        () => TomTextResourceProvider.getAppResources(),
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.key,
            'key',
            'resources.text_provider.not_installed',
          ),
        ),
      );
    });

    test('getAppConfig throws before a config provider is installed', () {
      expect(
        () => TomConfigResourceProvider.getAppConfig(),
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.key,
            'key',
            'resources.config_provider.not_installed',
          ),
        ),
      );
    });

    // A bootstrap failure is reported at the read, arbitrarily far from the
    // startup code that forgot to install. The message has to carry the fix,
    // because the stack trace points at the innocent party.
    test('each message names the call that fixes it', () {
      expect(
        () => TomTextResourceProvider.getAppResources(),
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('setAppResourceProvider'),
          ),
        ),
      );
      expect(
        () => TomConfigResourceProvider.getAppConfig(),
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('setAppConfigProvider'),
          ),
        ),
      );
    });

    // `loader` is a recipe, not an install. Declaring how to load the bundle
    // must not be enough to get one silently installed at revision 0.
    test('setting the static loader does not install a bundle', () {
      TomTextResourceProvider.loader = () => {
        'app': {'title': 'Lazy Loaded'},
      };
      TomConfigResourceProvider.loader = () => {'api': 42};

      expect(
        () => TomTextResourceProvider.getAppResources(),
        throwsA(isA<TomResourceException>()),
      );
      expect(
        () => TomConfigResourceProvider.getAppConfig(),
        throwsA(isA<TomResourceException>()),
      );
    });

    // The counter's documented meaning — "the installed bundle changed" — has
    // to hold for the *first* bundle too, which is exactly what the lazy path
    // broke.
    test('the first install bumps the revision', () {
      TomTextResourceProvider.loader = () => {
        'app': {'title': 'Loaded'},
      };
      final before = ~TomTextResourceProvider.appResourcesRevision;

      TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider());

      expect(
        ~TomTextResourceProvider.appResourcesRevision,
        greaterThan(before),
      );
      expect(
        TomTextResourceProvider.getAppResources().getText('app.title'),
        equals('Loaded'),
      );
    });

    // Clearing is teardown, and teardown has no readers: an observer woken by
    // the clear would call getAppResources() and throw.
    test('clearing the provider does not bump the revision', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'a': 'b'}),
      );
      final after = ~TomTextResourceProvider.appResourcesRevision;

      TomTextResourceProvider.clearAppResourceProvider();

      expect(~TomTextResourceProvider.appResourcesRevision, equals(after));
    });
  });

  // ===========================================================================
  // Observable Revision
  // ===========================================================================
  //
  // `appResourcesRevision` is the module's only cross-module surface: a locale
  // switch becomes visible to `TomObservableEnum` (see
  // lib/src/tombase/observable/tom_observable_enum.dart) because the counter
  // moves, and for no other reason. Its contract is therefore as much about
  // when it does *not* move as when it does — a spurious bump re-renders the
  // application for nothing, a missing one leaves it showing stale text.
  //
  // The counter is a process-wide `static final TomInt` that nothing resets, so
  // every test here reads it with `~` before and after and compares the delta
  // rather than an absolute value.
  //
  // The two bumps already pinned by the bootstrap contract group above — the
  // first install bumps, clearing does not — are not repeated here.
  group('observable revision', () {
    setUp(() {
      TomTextResourceProvider.loader = null;
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({}),
      );
    });

    test('notifyAppResourcesChanged bumps the revision', () {
      // The manual escape hatch, for the one change the module cannot detect.
      final before = ~TomTextResourceProvider.appResourcesRevision;

      TomTextResourceProvider.notifyAppResourcesChanged();

      expect(~TomTextResourceProvider.appResourcesRevision, equals(before + 1));
    });

    test('replacing an installed provider bumps the revision again', () {
      // Not just the *first* install: every install announces itself, which is
      // what makes a locale switch (install the new bundle) work at all.
      final before = ~TomTextResourceProvider.appResourcesRevision;

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'greeting': 'Hello'}),
      );
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'greeting': 'Bonjour'}),
      );

      expect(~TomTextResourceProvider.appResourcesRevision, equals(before + 2));
      expect(
        TomTextResourceProvider.getAppResources().getText('greeting'),
        equals('Bonjour'),
      );
    });

    // -------------------------------------------------------------------------
    // The setter's identity guard.
    //
    // `set resources` bumps only when `identical(this, _resourceProvider)`.
    // That one line decides whether an assignment is an application-wide event
    // or a private edit, and it is silently correct or silently wrong — nothing
    // observable distinguishes the two until an observer fires (or doesn't).
    // Both sides of it are pinned below.
    // -------------------------------------------------------------------------
    test('assigning resources on the installed provider bumps', () {
      final installed = TomTextResourceProvider.from({'greeting': 'Hello'});
      TomTextResourceProvider.setAppResourceProvider(installed);
      final before = ~TomTextResourceProvider.appResourcesRevision;

      installed.resources = {'greeting': 'Bonjour'};

      expect(~TomTextResourceProvider.appResourcesRevision, equals(before + 1));
      expect(
        TomTextResourceProvider.getAppResources().getText('greeting'),
        equals('Bonjour'),
      );
    });

    test('assigning resources on a provider that is not installed does not '
        'bump', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'greeting': 'Hello'}),
      );
      final other = TomTextResourceProvider.from({});
      final before = ~TomTextResourceProvider.appResourcesRevision;

      other.resources = {'greeting': 'Bonjour'};

      // Nobody is reading `other`, so nobody needs to hear about it.
      expect(~TomTextResourceProvider.appResourcesRevision, equals(before));
      expect(
        TomTextResourceProvider.getAppResources().getText('greeting'),
        equals('Hello'),
      );
    });

    test('constructing a provider does not bump, however it is populated', () {
      // Both populating constructors assign through the setter, and the guard
      // is what keeps that from announcing a bundle nothing has installed yet.
      // This is the instance-level half of the declare/install split.
      TomTextResourceProvider.loader = () => {'origin': 'staticLoader'};
      final before = ~TomTextResourceProvider.appResourcesRevision;

      TomTextResourceProvider();
      TomTextResourceProvider.load(() => {'origin': 'scoped'});
      TomTextResourceProvider.from({'origin': 'literal'});

      expect(~TomTextResourceProvider.appResourcesRevision, equals(before));
    });

    // -------------------------------------------------------------------------
    // In-place mutation.
    //
    // The documented limitation, and the reason notifyAppResourcesChanged
    // exists: assignment goes through a setter that can see it, `[]=` does not.
    // -------------------------------------------------------------------------
    test('mutating the installed bundle in place does not bump', () {
      final installed = TomTextResourceProvider.from({
        'greeting': 'Hello',
        'nested': {'leaf': 'Leaf'},
      });
      TomTextResourceProvider.setAppResourceProvider(installed);
      final before = ~TomTextResourceProvider.appResourcesRevision;

      installed.resources['greeting'] = 'Bonjour';
      (installed.resources['nested'] as Map)['leaf'] = 'Feuille';

      // The value changed and the counter did not: an observer would still be
      // showing 'Hello'.
      expect(
        TomTextResourceProvider.getAppResources().getText('greeting'),
        equals('Bonjour'),
      );
      expect(~TomTextResourceProvider.appResourcesRevision, equals(before));

      // Which is what the manual notification is for.
      TomTextResourceProvider.notifyAppResourcesChanged();
      expect(~TomTextResourceProvider.appResourcesRevision, equals(before + 1));
    });

    test('the revision reaches observers', () {
      // The counter is only useful because something reacts to it; a bump that
      // notified nobody would satisfy every test above. Observers are held
      // weakly, so the subscription is retained for the length of the test.
      var seen = 0;
      final observer =
          TomTextResourceProvider.appResourcesRevision >> (_) => seen++;

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'greeting': 'Bonjour'}),
      );
      TomTextResourceProvider.notifyAppResourcesChanged();

      expect(seen, equals(2));
      TomTextResourceProvider.appResourcesRevision.removeObserver(observer);
    });
  });

  // ===========================================================================
  // Edge Cases and Integration Tests
  // ===========================================================================
  group('Edge Cases', () {
    group('special key names', () {
      test('should handle keys with single dot', () {
        final provider = TomTextResourceProvider.from({
          'a': {'b': 'value'},
        });
        expect(provider.getText('a.b'), equals('value'));
      });

      test('should handle keys that look like paths but are flat', () {
        final provider = TomTextResourceProvider.from({
          'a.b': 'flat key with dot',
        });
        // The dot notation will try to traverse first, but since it fails,
        // it falls back to direct key lookup which finds 'a.b' as a flat key
        expect(provider.getText('a.b'), equals('flat key with dot'));
      });

      test('should handle empty resources map', () {
        final provider = TomTextResourceProvider.from({});
        expect(provider.getText('any.key'), equals('any.key'));
        expect(provider.exists('any.key'), isFalse);
      });

      test('should handle very deep nesting', () {
        final provider = TomTextResourceProvider.from({
          'l1': {
            'l2': {
              'l3': {
                'l4': {'l5': 'deep'},
              },
            },
          },
        });
        expect(provider.getText('l1.l2.l3.l4.l5'), equals('deep'));
        expect(provider.exists('l1.l2.l3.l4.l5'), isTrue);
      });
    });

    group('provider independence', () {
      test(
        'should allow text and config providers to coexist independently',
        () {
          final textProvider = TomTextResourceProvider.from({
            'label': 'Text Label',
          });
          final configProvider = TomConfigResourceProvider.from({
            'setting': 42,
          });

          TomTextResourceProvider.setAppResourceProvider(textProvider);
          TomConfigResourceProvider.setAppConfigProvider(configProvider);

          expect(
            TomTextResourceProvider.getAppResources().getText('label'),
            equals('Text Label'),
          );
          expect(
            TomConfigResourceProvider.getAppConfig().getObject('setting'),
            equals(42),
          );
        },
      );

      test('should have separate singleton instances', () {
        TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider.from({'type': 'text'}),
        );
        TomConfigResourceProvider.setAppConfigProvider(
          TomConfigResourceProvider.from({'type': 'config'}),
        );

        final textInstance = TomTextResourceProvider.getAppResources();
        final configInstance = TomConfigResourceProvider.getAppConfig();

        expect(textInstance.resources['type'], equals('text'));
        expect(configInstance.resources['type'], equals('config'));
      });
    });

    // -------------------------------------------------------------------------
    // Shared resolution contract (pins the RCK2 private-helper extraction:
    // both providers resolve a key as "tree walk first, flat-key fallback",
    // with the text family additionally consulting the flat key when the tree
    // walk lands on a non-String).
    // -------------------------------------------------------------------------
    group('shared resolution contract', () {
      test('text family falls back to a flat dotted key when the tree walk '
          'lands on a non-String', () {
        // 'a.b' resolves via the tree to an int, but a literal 'a.b' String key
        // also exists. The text accessors must surface the flat String rather
        // than treating the non-String tree hit as final.
        final provider = TomTextResourceProvider.from({
          'a': {'b': 5},
          'a.b': 'flat literal',
        });
        expect(provider.getText('a.b'), equals('flat literal'));
        expect(provider.getTextOrNull('a.b'), equals('flat literal'));
        expect(provider.exists('a.b'), isTrue);
      });

      test(
        'object family returns a non-String value at a hierarchical path',
        () {
          final provider = TomTextResourceProvider.from({
            'app': {'retries': 3},
          });
          expect(provider.getObject('app.retries'), equals(3));
          expect(provider.getObjectOrNull('app.retries'), equals(3));
          expect(provider.existsObject('app.retries'), isTrue);
        },
      );

      test('object family surfaces a non-String tree hit that the text family '
          'reports absent', () {
        // No flat fallback here: a nested int is visible to the object family
        // but not the text family.
        final provider = TomTextResourceProvider.from({
          'app': {'retries': 3},
        });
        expect(provider.existsObject('app.retries'), isTrue);
        expect(provider.exists('app.retries'), isFalse);
        expect(provider.getTextOrNull('app.retries'), isNull);
        expect(provider.getText('app.retries'), equals('app.retries'));
      });

      test('config and text object families resolve identically for the same '
          'map', () {
        final map = {
          'api': {'timeout': 30000},
          'flag': true,
        };
        final config = TomConfigResourceProvider.from(map);
        final text = TomTextResourceProvider.from(map);

        // exists / existsObject and getObject share the object rule on both.
        expect(
          config.exists('api.timeout'),
          equals(text.existsObject('api.timeout')),
        );
        expect(config.exists('missing'), equals(text.existsObject('missing')));
        expect(config.getObject('flag'), equals(text.getObject('flag')));
        expect(config.getObject('missing'), equals(text.getObject('missing')));
        // Both echo the key back on a miss.
        expect(config.getObject('missing'), equals('missing'));
      });

      // -----------------------------------------------------------------------
      // A key that is present and holds null.
      //
      // The json layer distinguishes it from an absent key — `getObjectFromTree`
      // returns null for the first and throws for the second — but the provider
      // accessors have no third state to report it with, so every one of them
      // collapses it onto "missing". These tests pin that collapse so it stays a
      // documented property rather than an accident, and pin the escape hatch
      // (`resources.containsKey`) that callers who need the distinction use.
      // -----------------------------------------------------------------------
      test(
        'a present null key reports as absent through every text accessor',
        () {
          final provider = TomTextResourceProvider.from({
            'flat': null,
            'nested': {'leaf': null},
          });

          for (final path in ['flat', 'nested.leaf']) {
            expect(provider.exists(path), isFalse, reason: 'exists($path)');
            expect(
              provider.existsObject(path),
              isFalse,
              reason: 'existsObject($path)',
            );
            expect(
              provider.getTextOrNull(path),
              isNull,
              reason: 'getTextOrNull($path)',
            );
            expect(
              provider.getObjectOrNull(path),
              isNull,
              reason: 'getObjectOrNull($path)',
            );
            // The lenient accessors echo the key, exactly as for a key that was
            // never there.
            expect(provider.getText(path), equals(path));
            expect(provider.getObject(path), equals(path));
          }
        },
      );

      test(
        'a present null key reports as absent through every config accessor',
        () {
          final provider = TomConfigResourceProvider.from({
            'flat': null,
            'nested': {'leaf': null},
          });

          for (final path in ['flat', 'nested.leaf']) {
            expect(provider.exists(path), isFalse, reason: 'exists($path)');
            expect(
              provider.getObjectOrNull(path),
              isNull,
              reason: 'getObjectOrNull($path)',
            );
            expect(provider.getObject(path), equals(path));
          }
        },
      );

      // -----------------------------------------------------------------------
      // What a dotted segment can descend into.
      //
      // Only a Map whose keys are all Strings. A List is a dead end, and so is a
      // Map that holds even one non-String key. Both are ordinary shapes in a
      // JSON-derived bundle, and both miss silently — the fallback echoes the
      // key, so a bad path renders as its own text rather than raising. These
      // tests pin the boundary from both sides.
      // -----------------------------------------------------------------------
      test('a List is a dead end for dotted traversal', () {
        final provider = TomTextResourceProvider.from({
          'items': [
            {'label': 'First'},
            {'label': 'Second'},
          ],
        });

        // No index syntax reaches into the list — not the element, not a field
        // of it. Both echo the key back, which is what makes the miss silent.
        expect(provider.getObject('items.0.label'), equals('items.0.label'));
        expect(provider.getObject('items.0'), equals('items.0'));
        expect(provider.existsObject('items.0'), isFalse);

        // The list itself is reachable as a terminal value, which is why
        // fetching it and indexing in Dart is the way through.
        expect(provider.getObjectOrNull('items'), isA<List<dynamic>>());
        expect(
          ((provider.getObject('items') as List)[0] as Map)['label'],
          equals('First'),
        );
      });

      test('a Map with a non-String key cannot be traversed, but is still '
          'reachable whole', () {
        final provider = TomTextResourceProvider.from({
          'byCode': <int, String>{1: 'one', 2: 'two'},
        });

        // Descending needs String keys; this map has none, so the walk fails
        // and the flat-key fallback finds nothing either.
        expect(provider.getText('byCode.1'), equals('byCode.1'));
        expect(provider.existsObject('byCode.1'), isFalse);

        // As a terminal segment no descent is attempted, so the map comes back
        // intact and the caller indexes it directly.
        expect(provider.existsObject('byCode'), isTrue);
        expect((provider.getObject('byCode') as Map)[1], equals('one'));
      });

      test(
        'traversal turns on the runtime keys, not the declared map type',
        () {
          // The rule is checked key by key at walk time. A narrowly reified
          // Map<String, String> descends even though it is not a
          // Map<String, dynamic>, and so does a Map<dynamic, dynamic> that
          // happens to hold only String keys.
          final provider = TomTextResourceProvider.from({
            'reified': <String, String>{'label': 'Reified'},
            'dynamic': <dynamic, dynamic>{'label': 'Dynamic'},
          });

          expect(provider.getText('reified.label'), equals('Reified'));
          expect(provider.getText('dynamic.label'), equals('Dynamic'));
        },
      );

      test('the bundle map still distinguishes a present null from an absent '
          'key', () {
        // The information is not lost, only unreachable through the accessors:
        // `resources` is public, so a caller that needs the distinction reads
        // the map. This is the documented escape hatch, and the reason the
        // collapse above is acceptable rather than a data-loss bug.
        final provider = TomTextResourceProvider.from({
          'flat': null,
          'nested': {'leaf': null},
        });

        expect(provider.resources.containsKey('flat'), isTrue);
        expect(provider.resources.containsKey('absent'), isFalse);
        expect(
          (provider.resources['nested'] as Map).containsKey('leaf'),
          isTrue,
        );
      });

      // -----------------------------------------------------------------------
      // What the guarded walk absorbs, and what it refuses to.
      //
      // Falling through to the flat leg on an unresolvable path is the whole
      // lenient-lookup design, and `getObjectFromTree` signals that with an
      // `Exception`. The guard is narrowed to exactly that, so an `Error` — a
      // programming fault rather than a lookup outcome — travels out instead.
      // Absorbing one would be the module's worst failure mode: the fault
      // renders as the key's own text, with no exception, no log line and
      // nothing to grep for.
      // -----------------------------------------------------------------------
      test('an Error raised during the tree walk propagates instead of '
          'becoming a miss', () {
        // The subtree throws when the walk reads its terminal segment. The
        // outer bundle is an ordinary map holding a literal dotted key, so the
        // flat leg is reachable and *would* quietly answer for the walk if the
        // Error were absorbed — which is what makes the miss silent.
        final bundle = {
          'corrupt': _ThrowingSubtree(),
          'corrupt.leaf': 'flat literal',
        };
        final text = TomTextResourceProvider.from(bundle);
        final config = TomConfigResourceProvider.from(bundle);

        // Every accessor on both providers routes through the two shared
        // resolvers, so the guarantee is asserted across the whole surface
        // rather than at one entry point.
        final reads = <String, Object? Function()>{
          'text.getText': () => text.getText('corrupt.leaf'),
          'text.getTextOrNull': () => text.getTextOrNull('corrupt.leaf'),
          'text.exists': () => text.exists('corrupt.leaf'),
          'text.getObject': () => text.getObject('corrupt.leaf'),
          'text.getObjectOrNull': () => text.getObjectOrNull('corrupt.leaf'),
          'text.existsObject': () => text.existsObject('corrupt.leaf'),
          'config.getObject': () => config.getObject('corrupt.leaf'),
          'config.getObjectOrNull': () =>
              config.getObjectOrNull('corrupt.leaf'),
          'config.exists': () => config.exists('corrupt.leaf'),
        };
        reads.forEach((name, read) {
          expect(read, throwsA(isA<StateError>()), reason: name);
        });
      });

      test('an Exception raised during the tree walk is still absorbed', () {
        // The counterpart, and the reason the narrowing is `on Exception`
        // rather than no guard at all: an unresolvable path must keep falling
        // through to the flat leg. Both legs are exercised — a literal dotted
        // key that resolves, and one that does not and reaches the fallback.
        final provider = TomTextResourceProvider.from({
          'a': {'b': 1},
          'a.missing': 'flat literal',
        });

        expect(provider.getText('a.missing'), equals('flat literal'));
        expect(provider.exists('a.missing'), isTrue);
        expect(provider.getObject('a.absent'), equals('a.absent'));
        expect(provider.getObjectOrNull('a.absent'), isNull);
      });
    });

    group('loader function behavior', () {
      test('the static loader persists and populates every later default '
          'construction', () {
        // `loader` is not consumed by the construction it was set for. It is
        // process-wide state that stays set, so a provider built much later for
        // an unrelated local scope silently inherits the startup bundle instead
        // of starting empty. Pinned because it is action at a distance, and
        // because it is why this suite clears the field in setUp.
        var calls = 0;
        TomTextResourceProvider.loader = () {
          calls++;
          return {'origin': 'staticLoader'};
        };

        // Bootstrap-style use: build, then install.
        TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider(),
        );
        expect(
          TomTextResourceProvider.getAppResources().getText('origin'),
          equals('staticLoader'),
        );

        // A provider built later, never installed, for a caller that wanted an
        // empty one. It is populated anyway, and the loader ran a second time.
        final local = TomTextResourceProvider();
        expect(local.getText('origin'), equals('staticLoader'));
        expect(calls, equals(2));

        // Installing did not consume the field either.
        expect(TomTextResourceProvider.loader, isNotNull);

        // `load` is the way out: it takes the loader as an argument, so it
        // touches no static state and the bare constructor is unaffected.
        final scoped = TomTextResourceProvider.load(() => {'origin': 'scoped'});
        expect(scoped.getText('origin'), equals('scoped'));
        expect(calls, equals(2));
      });

      test('the config loader has the same process-wide reach', () {
        TomConfigResourceProvider.loader = () => {'origin': 'staticLoader'};
        TomConfigResourceProvider.setAppConfigProvider(
          TomConfigResourceProvider(),
        );

        final local = TomConfigResourceProvider();
        expect(local.getObject('origin'), equals('staticLoader'));
        expect(TomConfigResourceProvider.loader, isNotNull);
      });

      test('should support loader that returns empty map', () {
        TomTextResourceProvider.loader = () => {};
        final provider = TomTextResourceProvider();
        expect(provider.resources, isEmpty);
      });

      test('should support loader with complex nested structure', () {
        TomConfigResourceProvider.loader = () => {
          'database': {
            'primary': {
              'host': 'db1.example.com',
              'port': 5432,
              'credentials': {'user': 'admin', 'password': 'secret'},
            },
            'replica': {
              'hosts': ['db2.example.com', 'db3.example.com'],
              'port': 5432,
            },
          },
          'cache': {'enabled': true, 'ttl': 3600},
        };
        final provider = TomConfigResourceProvider();
        expect(
          provider.getObject('database.primary.host'),
          equals('db1.example.com'),
        );
        expect(
          provider.getObject('database.primary.credentials.user'),
          equals('admin'),
        );
        expect(
          provider.getObject('database.replica.hosts'),
          equals(['db2.example.com', 'db3.example.com']),
        );
        expect(provider.getObject('cache.enabled'), equals(true));
      });
    });

    // -------------------------------------------------------------------------
    // Bootstrapping from a source that is only available asynchronously.
    //
    // `loader` is deliberately synchronous (`Map<String, dynamic> Function()`),
    // because `getText` is synchronous: the bundle has to be in memory by the
    // time anything reads it, and a constructor cannot await. These tests pin
    // that contract and the pattern the documentation recommends in its place,
    // so a sample that awaits inside a loader cannot be reintroduced without a
    // test turning red.
    // -------------------------------------------------------------------------
    group('bootstrapping from an asynchronous source', () {
      /// Stands in for `rootBundle.loadString`, a file read, or a network
      /// fetch — anything whose result only exists after an await.
      Future<String> readAssetString() async {
        await Future<void>.delayed(Duration.zero);
        return '{"labels": {"username": "Username"}}';
      }

      test(
        'awaiting the source before installing makes reads synchronous',
        () async {
          final contents = await readAssetString();
          TomTextResourceProvider.setAppResourceProvider(
            TomTextResourceProvider.from(
              jsonDecode(contents) as Map<String, dynamic>,
            ),
          );

          // No await here, and none at any other call site: the bundle was
          // already in hand when the provider was installed.
          expect(
            TomTextResourceProvider.getAppResources().getText(
              'labels.username',
            ),
            equals('Username'),
          );
        },
      );

      test('load returns a fully populated provider, with no await', () {
        // The counterpart to the test above: when the bundle *can* be produced
        // synchronously, `load` is complete the moment it returns. Nothing in
        // the API defers work to first access, which is why the loader cannot
        // be asynchronous.
        final provider = TomTextResourceProvider.load(
          () =>
              jsonDecode('{"labels": {"username": "Username"}}')
                  as Map<String, dynamic>,
        );
        expect(provider.getText('labels.username'), equals('Username'));
      });

      test('config bundles bootstrap the same way', () async {
        final contents = await readAssetString();
        TomConfigResourceProvider.setAppConfigProvider(
          TomConfigResourceProvider.from(
            jsonDecode(contents) as Map<String, dynamic>,
          ),
        );

        expect(
          TomConfigResourceProvider.getAppConfig().getObjectOrNull(
            'labels.username',
          ),
          equals('Username'),
        );
      });
    });
  });
}

/// Stands in for a look-and-feel value of the kind the object family exists for
/// — a TextStyle or a Color in a real application. Deliberately not a
/// primitive, and deliberately not a `String`.
class _UiValue {
  final String name;
  const _UiValue(this.name);
}

/// A bundle subtree that throws an [Error] — not an [Exception] — as soon as
/// the tree walk reads it.
///
/// It stands in for any programming fault that can surface inside
/// `getObjectFromTree`. What the resolvers have to tell apart is the *kind* of
/// throwable, not the particular fault, so throwing from [noSuchMethod] covers
/// the whole `Map` surface without implementing a member that no test reads.
///
/// It passes the walk's subtree test untouched: that test short-circuits on
/// `value is Map<String, dynamic>`, so nothing is invoked until the segment
/// read itself.
class _ThrowingSubtree implements Map<String, dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('bundle is corrupt');
}
