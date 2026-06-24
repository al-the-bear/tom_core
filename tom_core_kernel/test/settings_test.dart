import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'settings_test.reflection.dart';

// =============================================================================
// TomGetSettingsMessage Tests
// =============================================================================

void main() {
  // The settings DTOs are @tomReflector classes whose reason to exist is
  // client<->server (de)serialization — register their mirrors so the JSON
  // round-trip tests below can exercise it (tests §35a).
  setUpAll(initializeReflection);

  group('TomGetSettingsMessage', () {
    group('constructor', () {
      test('should create message with default empty authorization token', () {
        // Act
        final message = TomGetSettingsMessage();

        // Assert
        expect(message.authorizationToken, equals(''));
      });

      test('should allow null authorization token', () {
        // Act
        final message = TomGetSettingsMessage();
        message.authorizationToken = null;

        // Assert
        expect(message.authorizationToken, isNull);
      });
    });

    group('authorizationToken', () {
      test('should set and get authorization token', () {
        // Arrange
        final message = TomGetSettingsMessage();
        const token = 'Bearer xyz123';

        // Act
        message.authorizationToken = token;

        // Assert
        expect(message.authorizationToken, equals(token));
      });

      test('should accept JWT bearer token format', () {
        // Arrange
        final message = TomGetSettingsMessage();
        const jwtToken =
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';

        // Act
        message.authorizationToken = jwtToken;

        // Assert
        expect(message.authorizationToken, equals(jwtToken));
        expect(message.authorizationToken, startsWith('Bearer '));
      });

      test('should accept empty string token', () {
        // Arrange
        final message = TomGetSettingsMessage();

        // Act
        message.authorizationToken = '';

        // Assert
        expect(message.authorizationToken, equals(''));
      });

      test('should accept token without Bearer prefix', () {
        // Arrange
        final message = TomGetSettingsMessage();
        const rawToken = 'some-raw-api-key-token';

        // Act
        message.authorizationToken = rawToken;

        // Assert
        expect(message.authorizationToken, equals(rawToken));
      });

      test('should handle token with special characters', () {
        // Arrange
        final message = TomGetSettingsMessage();
        const specialToken = 'Bearer abc+/=123_XYZ-789';

        // Act
        message.authorizationToken = specialToken;

        // Assert
        expect(message.authorizationToken, equals(specialToken));
      });

      test('should allow overwriting token value', () {
        // Arrange
        final message = TomGetSettingsMessage();
        message.authorizationToken = 'first-token';

        // Act
        message.authorizationToken = 'second-token';

        // Assert
        expect(message.authorizationToken, equals('second-token'));
      });
    });
  });

  // ===========================================================================
  // TomGetSettingsResult Tests
  // ===========================================================================

  group('TomGetSettingsResult', () {
    group('constructor', () {
      test('should create result with default empty collections', () {
        // Act
        final result = TomGetSettingsResult();

        // Assert
        expect(result.texts, isEmpty);
        expect(result.config, isEmpty);
        expect(result.groups, isEmpty);
        expect(result.roles, isEmpty);
        expect(result.entitlements, isEmpty);
        expect(result.resourceKeys, isEmpty);
      });

      test('should create result with default null optional strings', () {
        // Act
        final result = TomGetSettingsResult();

        // Assert
        expect(result.organization, isNull);
        expect(result.process, isNull);
        expect(result.application, isNull);
        expect(result.country, isNull);
        expect(result.language, isNull);
        expect(result.clientCountry, isNull);
        expect(result.clientLanguage, isNull);
        expect(result.clientTimeZone, isNull);
      });

      test('should create result with all named parameters', () {
        // Arrange
        final texts = {'welcome': 'Hello', 'goodbye': 'Bye'};
        final config = {'theme': 'dark', 'maxItems': 50};
        final groups = ['staff', 'engineering'];
        final roles = ['admin', 'editor'];
        final entitlements = ['read', 'write', 'delete'];
        final resourceKeys = ['dashboard', 'reports', 'settings'];

        // Act
        final result = TomGetSettingsResult(
          texts: texts,
          config: config,
          groups: groups,
          roles: roles,
          entitlements: entitlements,
          resourceKeys: resourceKeys,
          organization: 'acme-corp',
          process: 'onboarding',
          application: 'main-app',
          country: 'US',
          language: 'en',
          clientCountry: 'GB',
          clientLanguage: 'en-GB',
          clientTimeZone: 'Europe/London',
        );

        // Assert
        expect(result.texts, equals(texts));
        expect(result.config, equals(config));
        expect(result.groups, equals(groups));
        expect(result.roles, equals(roles));
        expect(result.entitlements, equals(entitlements));
        expect(result.resourceKeys, equals(resourceKeys));
        expect(result.organization, equals('acme-corp'));
        expect(result.process, equals('onboarding'));
        expect(result.application, equals('main-app'));
        expect(result.country, equals('US'));
        expect(result.language, equals('en'));
        expect(result.clientCountry, equals('GB'));
        expect(result.clientLanguage, equals('en-GB'));
        expect(result.clientTimeZone, equals('Europe/London'));
      });

      test('should allow partial initialization with named parameters', () {
        // Act
        final result = TomGetSettingsResult(
          roles: ['viewer'],
          clientLanguage: 'de',
        );

        // Assert
        expect(result.roles, equals(['viewer']));
        expect(result.clientLanguage, equals('de'));
        expect(result.texts, isEmpty);
        expect(result.groups, isEmpty);
        expect(result.organization, isNull);
      });
    });

    group('texts property', () {
      test('should store and retrieve text resources', () {
        // Arrange
        final result = TomGetSettingsResult();
        final texts = {
          'welcome': 'Welcome to the app',
          'login': 'Please log in',
          'error': 'An error occurred',
        };

        // Act
        result.texts = texts;

        // Assert
        expect(result.texts, equals(texts));
        expect(result.texts['welcome'], equals('Welcome to the app'));
        expect(result.texts['login'], equals('Please log in'));
        expect(result.texts.length, equals(3));
      });

      test('should handle texts with null values', () {
        // Arrange
        final result = TomGetSettingsResult(
          texts: {'key1': 'value1', 'key2': null, 'key3': 'value3'},
        );

        // Assert
        expect(result.texts['key1'], equals('value1'));
        expect(result.texts['key2'], isNull);
        expect(result.texts.containsKey('key2'), isTrue);
      });

      test('should handle texts with various value types', () {
        // Arrange
        final result = TomGetSettingsResult(
          texts: {
            'string': 'text value',
            'number': 42,
            'boolean': true,
            'list': [1, 2, 3],
            'nested': {'inner': 'value'},
          },
        );

        // Assert
        expect(result.texts['string'], equals('text value'));
        expect(result.texts['number'], equals(42));
        expect(result.texts['boolean'], equals(true));
        expect(result.texts['list'], equals([1, 2, 3]));
        expect(result.texts['nested'], equals({'inner': 'value'}));
      });

      test('should handle empty texts map', () {
        // Arrange
        final result = TomGetSettingsResult(texts: {});

        // Assert
        expect(result.texts, isEmpty);
        expect(result.texts['nonexistent'], isNull);
      });
    });

    group('config property', () {
      test('should store and retrieve configuration values', () {
        // Arrange
        final config = {
          'theme': 'dark',
          'maxItems': 100,
          'enableFeatureX': true,
        };
        final result = TomGetSettingsResult(config: config);

        // Assert
        expect(result.config['theme'], equals('dark'));
        expect(result.config['maxItems'], equals(100));
        expect(result.config['enableFeatureX'], equals(true));
      });

      test('should handle nested configuration objects', () {
        // Arrange
        final result = TomGetSettingsResult(
          config: {
            'ui': {
              'theme': 'dark',
              'fontSize': 14,
              'colors': {'primary': '#007AFF', 'secondary': '#5856D6'},
            },
            'api': {'timeout': 30000, 'retries': 3},
          },
        );

        // Assert
        expect(result.config['ui'], isA<Map>());
        final uiConfig = result.config['ui'] as Map;
        expect(uiConfig['theme'], equals('dark'));
        expect(uiConfig['colors'], isA<Map>());
      });

      test('should handle config with list values', () {
        // Arrange
        final result = TomGetSettingsResult(
          config: {
            'enabledFeatures': ['feature1', 'feature2', 'feature3'],
            'supportedLocales': ['en', 'de', 'fr', 'es'],
          },
        );

        // Assert
        expect(result.config['enabledFeatures'], isA<List>());
        expect(
          (result.config['enabledFeatures'] as List).length,
          equals(3),
        );
      });
    });

    group('authorization properties', () {
      group('groups', () {
        test('should store and retrieve user groups', () {
          // Arrange
          final groups = ['staff', 'engineering', 'managers'];
          final result = TomGetSettingsResult(groups: groups);

          // Assert
          expect(result.groups, equals(groups));
          expect(result.groups.length, equals(3));
          expect(result.groups.contains('staff'), isTrue);
        });

        test('should handle empty groups list', () {
          // Arrange
          final result = TomGetSettingsResult(groups: []);

          // Assert
          expect(result.groups, isEmpty);
          expect(result.groups.contains('any'), isFalse);
        });

        test('should handle single group', () {
          // Arrange
          final result = TomGetSettingsResult(groups: ['admin']);

          // Assert
          expect(result.groups.length, equals(1));
          expect(result.groups.first, equals('admin'));
        });
      });

      group('roles', () {
        test('should store and retrieve user roles', () {
          // Arrange
          final roles = ['admin', 'editor', 'viewer'];
          final result = TomGetSettingsResult(roles: roles);

          // Assert
          expect(result.roles, equals(roles));
          expect(result.roles.contains('admin'), isTrue);
          expect(result.roles.contains('viewer'), isTrue);
        });

        test('should check role membership', () {
          // Arrange
          final result = TomGetSettingsResult(
            roles: ['editor', 'contributor'],
          );

          // Assert
          expect(result.roles.contains('editor'), isTrue);
          expect(result.roles.contains('admin'), isFalse);
        });

        test('should handle multiple similar roles', () {
          // Arrange
          final result = TomGetSettingsResult(
            roles: ['read-only', 'read-write', 'read-admin'],
          );

          // Assert
          expect(result.roles.where((r) => r.startsWith('read')).length, equals(3));
        });
      });

      group('entitlements', () {
        test('should store and retrieve user entitlements', () {
          // Arrange
          final entitlements = ['create-report', 'delete-user', 'view-analytics'];
          final result = TomGetSettingsResult(entitlements: entitlements);

          // Assert
          expect(result.entitlements, equals(entitlements));
          expect(result.entitlements.length, equals(3));
        });

        test('should check entitlement presence', () {
          // Arrange
          final result = TomGetSettingsResult(
            entitlements: ['read', 'write'],
          );

          // Assert
          expect(result.entitlements.contains('read'), isTrue);
          expect(result.entitlements.contains('delete'), isFalse);
        });

        test('should handle fine-grained permission strings', () {
          // Arrange
          final result = TomGetSettingsResult(
            entitlements: [
              'document:read',
              'document:write',
              'user:create',
              'user:delete',
            ],
          );

          // Assert
          expect(
            result.entitlements.where((e) => e.startsWith('document:')).length,
            equals(2),
          );
          expect(
            result.entitlements.where((e) => e.startsWith('user:')).length,
            equals(2),
          );
        });
      });

      group('resourceKeys', () {
        test('should store and retrieve resource keys', () {
          // Arrange
          final keys = ['dashboard', 'reports', 'settings', 'admin-panel'];
          final result = TomGetSettingsResult(resourceKeys: keys);

          // Assert
          expect(result.resourceKeys, equals(keys));
          expect(result.resourceKeys.contains('dashboard'), isTrue);
        });

        test('should check resource access', () {
          // Arrange
          final result = TomGetSettingsResult(
            resourceKeys: ['module-a', 'module-b'],
          );

          // Assert
          expect(result.resourceKeys.contains('module-a'), isTrue);
          expect(result.resourceKeys.contains('module-c'), isFalse);
        });
      });
    });

    group('application context properties', () {
      test('should store organization context', () {
        // Arrange
        final result = TomGetSettingsResult(organization: 'acme-corporation');

        // Assert
        expect(result.organization, equals('acme-corporation'));
      });

      test('should store process context', () {
        // Arrange
        final result = TomGetSettingsResult(process: 'order-fulfillment');

        // Assert
        expect(result.process, equals('order-fulfillment'));
      });

      test('should store application context', () {
        // Arrange
        final result = TomGetSettingsResult(application: 'inventory-app');

        // Assert
        expect(result.application, equals('inventory-app'));
      });

      test('should allow null context values', () {
        // Arrange
        final result = TomGetSettingsResult(
          organization: null,
          process: null,
          application: null,
        );

        // Assert
        expect(result.organization, isNull);
        expect(result.process, isNull);
        expect(result.application, isNull);
      });

      test('should allow empty string context values', () {
        // Arrange
        final result = TomGetSettingsResult(
          organization: '',
          process: '',
          application: '',
        );

        // Assert
        expect(result.organization, equals(''));
        expect(result.process, equals(''));
        expect(result.application, equals(''));
      });
    });

    group('localization properties', () {
      group('server-side localization', () {
        test('should store country code', () {
          // Arrange
          final result = TomGetSettingsResult(country: 'US');

          // Assert
          expect(result.country, equals('US'));
        });

        test('should store language code', () {
          // Arrange
          final result = TomGetSettingsResult(language: 'en');

          // Assert
          expect(result.language, equals('en'));
        });

        test('should handle ISO 3166-1 country codes', () {
          // Arrange & Act
          final resultUS = TomGetSettingsResult(country: 'US');
          final resultGB = TomGetSettingsResult(country: 'GB');
          final resultDE = TomGetSettingsResult(country: 'DE');

          // Assert
          expect(resultUS.country, equals('US'));
          expect(resultGB.country, equals('GB'));
          expect(resultDE.country, equals('DE'));
        });

        test('should handle ISO 639-1 language codes', () {
          // Arrange & Act
          final resultEn = TomGetSettingsResult(language: 'en');
          final resultDe = TomGetSettingsResult(language: 'de');
          final resultFr = TomGetSettingsResult(language: 'fr');

          // Assert
          expect(resultEn.language, equals('en'));
          expect(resultDe.language, equals('de'));
          expect(resultFr.language, equals('fr'));
        });
      });

      group('client-side localization', () {
        test('should store client country code', () {
          // Arrange
          final result = TomGetSettingsResult(clientCountry: 'CA');

          // Assert
          expect(result.clientCountry, equals('CA'));
        });

        test('should store client language code', () {
          // Arrange
          final result = TomGetSettingsResult(clientLanguage: 'fr');

          // Assert
          expect(result.clientLanguage, equals('fr'));
        });

        test('should store client timezone with IANA identifier', () {
          // Arrange
          final result = TomGetSettingsResult(
            clientTimeZone: 'America/New_York',
          );

          // Assert
          expect(result.clientTimeZone, equals('America/New_York'));
        });

        test('should handle various IANA timezone identifiers', () {
          // Arrange & Act
          final timezones = [
            'America/New_York',
            'America/Los_Angeles',
            'Europe/London',
            'Europe/Paris',
            'Asia/Tokyo',
            'Australia/Sydney',
            'Pacific/Auckland',
          ];

          for (final tz in timezones) {
            final result = TomGetSettingsResult(clientTimeZone: tz);

            // Assert
            expect(result.clientTimeZone, equals(tz));
          }
        });

        test('should handle UTC timezone', () {
          // Arrange
          final result = TomGetSettingsResult(clientTimeZone: 'UTC');

          // Assert
          expect(result.clientTimeZone, equals('UTC'));
        });
      });

      group('server vs client localization differences', () {
        test('should allow different server and client country', () {
          // Arrange
          final result = TomGetSettingsResult(
            country: 'US',
            clientCountry: 'GB',
          );

          // Assert
          expect(result.country, equals('US'));
          expect(result.clientCountry, equals('GB'));
          expect(result.country, isNot(equals(result.clientCountry)));
        });

        test('should allow different server and client language', () {
          // Arrange
          final result = TomGetSettingsResult(
            language: 'en',
            clientLanguage: 'de',
          );

          // Assert
          expect(result.language, equals('en'));
          expect(result.clientLanguage, equals('de'));
          expect(result.language, isNot(equals(result.clientLanguage)));
        });

        test('should support full localization configuration', () {
          // Arrange
          final result = TomGetSettingsResult(
            country: 'US',
            language: 'en',
            clientCountry: 'DE',
            clientLanguage: 'de',
            clientTimeZone: 'Europe/Berlin',
          );

          // Assert
          expect(result.country, equals('US'));
          expect(result.language, equals('en'));
          expect(result.clientCountry, equals('DE'));
          expect(result.clientLanguage, equals('de'));
          expect(result.clientTimeZone, equals('Europe/Berlin'));
        });
      });
    });

    group('property mutation', () {
      test('should allow modifying texts after creation', () {
        // Arrange
        final result = TomGetSettingsResult();
        final newTexts = {'key1': 'value1', 'key2': 'value2'};

        // Act
        result.texts = newTexts;

        // Assert
        expect(result.texts, equals(newTexts));
      });

      test('should allow modifying config after creation', () {
        // Arrange
        final result = TomGetSettingsResult();
        final newConfig = {'setting1': true, 'setting2': 100};

        // Act
        result.config = newConfig;

        // Assert
        expect(result.config, equals(newConfig));
      });

      test('should allow modifying roles after creation', () {
        // Arrange
        final result = TomGetSettingsResult(roles: ['initial']);

        // Act
        result.roles = ['updated', 'roles'];

        // Assert
        expect(result.roles, equals(['updated', 'roles']));
      });

      test('should allow modifying groups after creation', () {
        // Arrange
        final result = TomGetSettingsResult(groups: ['group1']);

        // Act
        result.groups = ['newGroup1', 'newGroup2'];

        // Assert
        expect(result.groups, equals(['newGroup1', 'newGroup2']));
      });

      test('should allow modifying entitlements after creation', () {
        // Arrange
        final result = TomGetSettingsResult();

        // Act
        result.entitlements = ['permission1', 'permission2'];

        // Assert
        expect(result.entitlements, equals(['permission1', 'permission2']));
      });

      test('should allow modifying resourceKeys after creation', () {
        // Arrange
        final result = TomGetSettingsResult();

        // Act
        result.resourceKeys = ['resource1', 'resource2'];

        // Assert
        expect(result.resourceKeys, equals(['resource1', 'resource2']));
      });

      test('should allow modifying organization after creation', () {
        // Arrange
        final result = TomGetSettingsResult(organization: 'original');

        // Act
        result.organization = 'modified';

        // Assert
        expect(result.organization, equals('modified'));
      });

      test('should allow modifying localization properties after creation', () {
        // Arrange
        final result = TomGetSettingsResult();

        // Act
        result.country = 'FR';
        result.language = 'fr';
        result.clientCountry = 'IT';
        result.clientLanguage = 'it';
        result.clientTimeZone = 'Europe/Rome';

        // Assert
        expect(result.country, equals('FR'));
        expect(result.language, equals('fr'));
        expect(result.clientCountry, equals('IT'));
        expect(result.clientLanguage, equals('it'));
        expect(result.clientTimeZone, equals('Europe/Rome'));
      });
    });

    // Bug §51 / tests §35b: a default-constructed result documents its
    // collections as "empty collections", and the idiomatic use is to mutate
    // them in place. The defaults must therefore be fresh growable instances,
    // not shared `const` immutables (which throw on add/[]=).
    group('default-constructed in-place collection mutation', () {
      test('texts is a mutable empty map by default', () {
        final result = TomGetSettingsResult();
        expect(result.texts, isEmpty);
        result.texts['welcome'] = 'Hello';
        expect(result.texts['welcome'], equals('Hello'));
      });

      test('config is a mutable empty map by default', () {
        final result = TomGetSettingsResult();
        expect(result.config, isEmpty);
        result.config['theme'] = 'dark';
        expect(result.config['theme'], equals('dark'));
      });

      test('groups/roles/entitlements/resourceKeys are mutable empty lists by default', () {
        final result = TomGetSettingsResult();

        result.groups.add('staff');
        result.roles.add('admin');
        result.entitlements.add('read');
        result.resourceKeys.add('dashboard');

        expect(result.groups, equals(['staff']));
        expect(result.roles, equals(['admin']));
        expect(result.entitlements, equals(['read']));
        expect(result.resourceKeys, equals(['dashboard']));
      });

      test('two default-constructed results do not share collection state', () {
        // A shared const (or any shared) default would leak mutations across
        // instances; fresh literals must give each instance its own.
        final a = TomGetSettingsResult();
        final b = TomGetSettingsResult();

        a.roles.add('admin');
        a.texts['k'] = 'v';

        expect(b.roles, isEmpty);
        expect(b.texts, isEmpty);
      });
    });

    // Tests §35a: the DTOs exist to be serialized; guard their reflection
    // (de)serialization with full round-trips so a regression can't pass green.
    group('JSON serialization round-trip', () {
      test('TomGetSettingsResult survives serialize -> deserialize', () {
        final original = TomGetSettingsResult(
          texts: {'welcome': 'Hello, World!'},
          config: {'theme': 'dark', 'maxItems': 50},
          groups: ['staff'],
          roles: ['admin', 'editor'],
          entitlements: ['read', 'write'],
          resourceKeys: ['dashboard', 'reports'],
          organization: 'acme-corp',
          process: 'checkout',
          application: 'portal',
          country: 'US',
          language: 'en',
          clientCountry: 'GB',
          clientLanguage: 'en',
          clientTimeZone: 'America/New_York',
        );

        final json = tomReflectionInfo.convertToJsonString(original);
        final mirror =
            tomReflector.reflectType(TomGetSettingsResult) as ClassMirror;
        final restored = tomReflectionInfo
            .createInstanceFromJsonString<TomGetSettingsResult>(mirror, json);

        expect(restored, isNotNull);
        expect(restored!.texts, equals({'welcome': 'Hello, World!'}));
        expect(restored.config, equals({'theme': 'dark', 'maxItems': 50}));
        expect(restored.groups, equals(['staff']));
        expect(restored.roles, equals(['admin', 'editor']));
        expect(restored.entitlements, equals(['read', 'write']));
        expect(restored.resourceKeys, equals(['dashboard', 'reports']));
        expect(restored.organization, equals('acme-corp'));
        expect(restored.process, equals('checkout'));
        expect(restored.application, equals('portal'));
        expect(restored.country, equals('US'));
        expect(restored.language, equals('en'));
        expect(restored.clientCountry, equals('GB'));
        expect(restored.clientLanguage, equals('en'));
        expect(restored.clientTimeZone, equals('America/New_York'));
      });

      test('TomGetSettingsMessage survives serialize -> deserialize', () {
        final original = TomGetSettingsMessage()
          ..authorizationToken = 'Bearer xyz123';

        final json = tomReflectionInfo.convertToJsonString(original);
        final mirror =
            tomReflector.reflectType(TomGetSettingsMessage) as ClassMirror;
        final restored = tomReflectionInfo
            .createInstanceFromJsonString<TomGetSettingsMessage>(mirror, json);

        expect(restored, isNotNull);
        expect(restored!.authorizationToken, equals('Bearer xyz123'));
      });
    });

    group('edge cases', () {
      test('should handle unicode text values', () {
        // Arrange
        final result = TomGetSettingsResult(
          texts: {
            'greeting_chinese': '你好世界',
            'greeting_arabic': 'مرحبا بالعالم',
            'greeting_emoji': 'Hello 👋 World 🌍',
            'greeting_japanese': 'こんにちは世界',
          },
        );

        // Assert
        expect(result.texts['greeting_chinese'], equals('你好世界'));
        expect(result.texts['greeting_arabic'], equals('مرحبا بالعالم'));
        expect(result.texts['greeting_emoji'], equals('Hello 👋 World 🌍'));
        expect(result.texts['greeting_japanese'], equals('こんにちは世界'));
      });

      test('should handle very long string values', () {
        // Arrange
        final longString = 'a' * 10000;
        final result = TomGetSettingsResult(
          texts: {'longValue': longString},
          organization: longString,
        );

        // Assert
        expect(result.texts['longValue'], equals(longString));
        expect((result.texts['longValue'] as String).length, equals(10000));
        expect(result.organization, equals(longString));
      });

      test('should handle special characters in keys', () {
        // Arrange
        final result = TomGetSettingsResult(
          texts: {
            'key.with.dots': 'value1',
            'key-with-dashes': 'value2',
            'key_with_underscores': 'value3',
            'key/with/slashes': 'value4',
          },
        );

        // Assert
        expect(result.texts['key.with.dots'], equals('value1'));
        expect(result.texts['key-with-dashes'], equals('value2'));
        expect(result.texts['key_with_underscores'], equals('value3'));
        expect(result.texts['key/with/slashes'], equals('value4'));
      });

      test('should handle large number of roles', () {
        // Arrange
        final manyRoles = List.generate(100, (i) => 'role_$i');
        final result = TomGetSettingsResult(roles: manyRoles);

        // Assert
        expect(result.roles.length, equals(100));
        expect(result.roles.first, equals('role_0'));
        expect(result.roles.last, equals('role_99'));
        expect(result.roles.contains('role_50'), isTrue);
      });

      test('should handle large number of entitlements', () {
        // Arrange
        final manyEntitlements = List.generate(1000, (i) => 'entitlement_$i');
        final result = TomGetSettingsResult(entitlements: manyEntitlements);

        // Assert
        expect(result.entitlements.length, equals(1000));
        expect(result.entitlements.contains('entitlement_500'), isTrue);
      });

      test('should handle deeply nested config objects', () {
        // Arrange
        final result = TomGetSettingsResult(
          config: {
            'level1': {
              'level2': {
                'level3': {
                  'level4': {
                    'level5': {'value': 'deep'}
                  }
                }
              }
            }
          },
        );

        // Assert
        final level1 = result.config['level1'] as Map;
        final level2 = level1['level2'] as Map;
        final level3 = level2['level3'] as Map;
        final level4 = level3['level4'] as Map;
        final level5 = level4['level5'] as Map;
        expect(level5['value'], equals('deep'));
      });
    });

    group('complete usage scenarios', () {
      test('should represent anonymous user settings', () {
        // Arrange & Act
        final result = TomGetSettingsResult(
          texts: {'welcome': 'Welcome, Guest'},
          config: {'showAds': true, 'limitedFeatures': true},
          groups: [],
          roles: ['anonymous'],
          entitlements: ['read'],
          resourceKeys: ['public-content'],
        );

        // Assert
        expect(result.roles.contains('anonymous'), isTrue);
        expect(result.entitlements.length, equals(1));
        expect(result.resourceKeys.first, equals('public-content'));
      });

      test('should represent authenticated user settings', () {
        // Arrange & Act
        final result = TomGetSettingsResult(
          texts: {'welcome': 'Welcome back, John'},
          config: {'showAds': false, 'theme': 'dark'},
          groups: ['employees', 'engineering'],
          roles: ['user', 'contributor'],
          entitlements: ['read', 'write', 'comment'],
          resourceKeys: ['dashboard', 'projects', 'team'],
          organization: 'tech-company',
          application: 'project-manager',
          clientCountry: 'US',
          clientLanguage: 'en',
          clientTimeZone: 'America/New_York',
        );

        // Assert
        expect(result.roles.contains('user'), isTrue);
        expect(result.groups.contains('engineering'), isTrue);
        expect(result.entitlements.length, equals(3));
        expect(result.organization, equals('tech-company'));
        expect(result.clientTimeZone, equals('America/New_York'));
      });

      test('should represent admin user settings', () {
        // Arrange & Act
        final result = TomGetSettingsResult(
          texts: {'welcome': 'Admin Panel'},
          config: {'debugMode': true, 'showMetrics': true},
          groups: ['admins', 'super-users'],
          roles: ['admin', 'super-admin'],
          entitlements: ['read', 'write', 'delete', 'admin', 'manage-users'],
          resourceKeys: ['all'],
          organization: 'platform',
          application: 'admin-console',
        );

        // Assert
        expect(result.roles.contains('admin'), isTrue);
        expect(result.roles.contains('super-admin'), isTrue);
        expect(result.entitlements.contains('manage-users'), isTrue);
        expect(result.config['debugMode'], equals(true));
      });

      test('should represent multi-tenant settings', () {
        // Arrange & Act
        final result = TomGetSettingsResult(
          texts: {'companyName': 'Acme Corp'},
          config: {'brandColor': '#FF5733', 'logoUrl': '/assets/acme-logo.png'},
          organization: 'acme',
          process: 'sales',
          application: 'crm',
          country: 'US',
          language: 'en',
          clientCountry: 'US',
          clientLanguage: 'en',
        );

        // Assert
        expect(result.organization, equals('acme'));
        expect(result.process, equals('sales'));
        expect(result.application, equals('crm'));
        expect(result.texts['companyName'], equals('Acme Corp'));
      });

      test('should represent internationalized settings', () {
        // Arrange & Act
        final result = TomGetSettingsResult(
          texts: {
            'greeting': 'Guten Tag',
            'currency': '€',
            'dateFormat': 'DD.MM.YYYY',
          },
          config: {
            'locale': 'de-DE',
            'currencyCode': 'EUR',
            'numberFormat': '1.234,56',
          },
          country: 'DE',
          language: 'de',
          clientCountry: 'DE',
          clientLanguage: 'de',
          clientTimeZone: 'Europe/Berlin',
        );

        // Assert
        expect(result.country, equals('DE'));
        expect(result.language, equals('de'));
        expect(result.clientTimeZone, equals('Europe/Berlin'));
        expect(result.texts['currency'], equals('€'));
        expect(result.config['currencyCode'], equals('EUR'));
      });
    });
  });
}
