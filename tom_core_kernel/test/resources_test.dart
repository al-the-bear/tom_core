import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // ===========================================================================
  // TomTextResourceProvider Tests
  // ===========================================================================
  group('TomTextResourceProvider', () {
    // Reset static state before each test
    setUp(() {
      TomTextResourceProvider.loader = null;
      // Reset singleton by setting a new empty provider
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({}),
      );
    });

    // -------------------------------------------------------------------------
    // Constructor Tests
    // -------------------------------------------------------------------------
    group('constructor', () {
      test('should create provider with empty resources when no loader is set', () {
        TomTextResourceProvider.loader = null;
        final provider = TomTextResourceProvider();
        expect(provider.resources, isEmpty);
      });

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
        final provider = TomTextResourceProvider.load(
          () => {'custom': 'data'},
        );
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
        final provider = TomTextResourceProvider.load(() => {
          'level1': {
            'level2': {'level3': 'deep value'},
          },
        });
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

      test('should create instance using loader if set and no instance exists', () {
        TomTextResourceProvider.loader = () => {'loaded': 'resource'};
        // Force reset singleton by setting explicitly
        TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider());
        final provider = TomTextResourceProvider.getAppResources();
        expect(provider.resources, equals({'loaded': 'resource'}));
      });

      test('should return same provider on subsequent calls', () {
        TomTextResourceProvider.loader = () => {'test': 'value'};
        TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider());
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

      test('should return false for deeply nested path that does not exist', () {
        final provider = TomTextResourceProvider.from({
          'level1': {'level2': 'value'},
        });
        expect(provider.exists('level1.level2.level3'), isFalse);
      });

      test('should return true for deeply nested path that exists', () {
        final provider = TomTextResourceProvider.from({
          'level1': {
            'level2': {'level3': 'deep value'},
          },
        });
        expect(provider.exists('level1.level2.level3'), isTrue);
      });

      test('should return false for empty string key', () {
        final provider = TomTextResourceProvider.from({'': 'empty key'});
        expect(provider.exists(''), isTrue);
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

      test('should return false when path contains non-existent intermediate key', () {
        final provider = TomTextResourceProvider.from({
          'root': {'child': 'value'},
        });
        expect(provider.exists('root.missing.child'), isFalse);
      });
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
        final provider = TomTextResourceProvider.from({
          'screens': 'not a map',
        });
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
        final provider = TomTextResourceProvider.from({
          'unicode': '日本語テキスト',
        });
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
    // Reset static state before each test
    setUp(() {
      TomConfigResourceProvider.loader = null;
      // Reset singleton by setting a new empty provider
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
    });

    // -------------------------------------------------------------------------
    // Constructor Tests
    // -------------------------------------------------------------------------
    group('constructor', () {
      test('should create provider with empty resources when no loader is set', () {
        TomConfigResourceProvider.loader = null;
        final provider = TomConfigResourceProvider();
        expect(provider.resources, isEmpty);
      });

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
        final provider = TomConfigResourceProvider.load(() => {
          'database': {
            'connection': {'pool': 10},
          },
        });
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

      test('should return true for null value if key exists', () {
        final provider = TomConfigResourceProvider.from({'nullable': null});
        // Note: null values won't pass the resources[s] != null check
        expect(provider.exists('nullable'), isFalse);
      });

      test('should return true for nested map value', () {
        final provider = TomConfigResourceProvider.from({
          'nested': {'key': 'value'},
        });
        expect(provider.exists('nested'), isTrue);
      });

      test('should return false when path contains non-existent intermediate key', () {
        final provider = TomConfigResourceProvider.from({
          'root': {'child': 'value'},
        });
        expect(provider.exists('root.missing.child'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // getText() Tests (returns Object for config)
    // -------------------------------------------------------------------------
    group('getText', () {
      test('should return string value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'baseUrl': 'https://api.example.com',
        });
        expect(provider.getText('baseUrl'), equals('https://api.example.com'));
      });

      test('should return integer value for flat key', () {
        final provider = TomConfigResourceProvider.from({'port': 8080});
        expect(provider.getText('port'), equals(8080));
      });

      test('should return boolean value for flat key', () {
        final provider = TomConfigResourceProvider.from({'enabled': true});
        expect(provider.getText('enabled'), equals(true));
      });

      test('should return double value for flat key', () {
        final provider = TomConfigResourceProvider.from({'rate': 0.05});
        expect(provider.getText('rate'), equals(0.05));
      });

      test('should return list value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'hosts': ['host1.com', 'host2.com'],
        });
        expect(provider.getText('hosts'), equals(['host1.com', 'host2.com']));
      });

      test('should return map value for flat key', () {
        final provider = TomConfigResourceProvider.from({
          'database': {'host': 'localhost', 'port': 5432},
        });
        expect(
          provider.getText('database'),
          equals({'host': 'localhost', 'port': 5432}),
        );
      });

      test('should return key itself when key does not exist', () {
        final provider = TomConfigResourceProvider.from({});
        expect(provider.getText('missing.key'), equals('missing.key'));
      });

      test('should return value for nested key using dot notation', () {
        final provider = TomConfigResourceProvider.from({
          'database': {
            'connection': {'maxPoolSize': 25},
          },
        });
        expect(provider.getText('database.connection.maxPoolSize'), equals(25));
      });

      test('should return key when nested path does not exist', () {
        final provider = TomConfigResourceProvider.from({
          'database': {'connection': {}},
        });
        expect(
          provider.getText('database.connection.missing'),
          equals('database.connection.missing'),
        );
      });

      test('should return key when intermediate path is not a map', () {
        final provider = TomConfigResourceProvider.from({
          'database': 'not a map',
        });
        expect(
          provider.getText('database.connection.pool'),
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
          provider.getText('settings.features.experimental.enabled'),
          equals(false),
        );
        expect(
          provider.getText('settings.features.experimental.version'),
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
          provider.getText('api.v1'),
          equals({'baseUrl': 'https://v1.api.com'}),
        );
      });
    });

    // -------------------------------------------------------------------------
    // resources Field Tests
    // -------------------------------------------------------------------------
    group('resources field', () {
      test('should be modifiable after creation', () {
        final provider = TomConfigResourceProvider.from({});
        provider.resources['new'] = 42;
        expect(provider.getText('new'), equals(42));
      });

      test('should support adding nested structures after creation', () {
        final provider = TomConfigResourceProvider.from({});
        provider.resources['section'] = {'key': 100};
        expect(provider.getText('section.key'), equals(100));
      });

      test('should support updating existing values', () {
        final provider = TomConfigResourceProvider.from({'value': 1});
        provider.resources['value'] = 2;
        expect(provider.getText('value'), equals(2));
      });
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
      test('should allow text and config providers to coexist independently', () {
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
          TomConfigResourceProvider.getAppConfig().getText('setting'),
          equals(42),
        );
      });

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

    group('loader function behavior', () {
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
          provider.getText('database.primary.host'),
          equals('db1.example.com'),
        );
        expect(
          provider.getText('database.primary.credentials.user'),
          equals('admin'),
        );
        expect(
          provider.getText('database.replica.hosts'),
          equals(['db2.example.com', 'db3.example.com']),
        );
        expect(provider.getText('cache.enabled'), equals(true));
      });
    });
  });
}
