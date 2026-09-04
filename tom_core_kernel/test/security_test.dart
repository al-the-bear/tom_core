import 'package:test/test.dart';
import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'security_test.reflection.dart';

// =============================================================================
// Test Helper Classes
// =============================================================================

/// Creates a test principal with configurable options.
TomPrincipal createTestPrincipal({
  bool authenticated = true,
  String username = 'testuser',
  List<String> roles = const [],
  List<String> groups = const [],
  List<String> entitlements = const [],
  List<String> resourceKeys = const [],
  Map<String, String> resourceRoles = const {},
  bool requires2FA = false,
  String? twoFactorType,
  String organization = 'testOrg',
  String application = 'testApp',
  String process = 'testProcess',
}) {
  return TomPrincipal(
    authenticated: authenticated,
    user: TomUser(
      id: 1,
      username: username,
      firstname: 'Test',
      lastname: 'User',
      email: 'test@example.com',
    ),
    aci: TomAccessControlInformation(
      roles: roles,
      groups: groups,
      entitlements: entitlements,
      resourceKeys: resourceKeys,
      resourceRoles: resourceRoles,
    ),
    requires2FA: requires2FA,
    twoFactorType: twoFactorType,
    organization: organization,
    application: application,
    process: process,
  );
}

/// Creates a test principal with the given [groups] populated on its ACI.
TomPrincipal createTestPrincipalWithGroups({
  bool authenticated = true,
  String username = 'testuser',
  List<String> roles = const [],
  required List<String> groups,
  List<String> entitlements = const [],
  List<String> additionalResourceKeys = const [],
  bool requires2FA = false,
  String? twoFactorType,
  String organization = 'testOrg',
  String application = 'testApp',
  String process = 'testProcess',
}) {
  return TomPrincipal(
    authenticated: authenticated,
    user: TomUser(
      id: 1,
      username: username,
      firstname: 'Test',
      lastname: 'User',
      email: 'test@example.com',
    ),
    aci: TomAccessControlInformation(
      roles: roles,
      groups: groups,
      entitlements: entitlements,
      resourceKeys: additionalResourceKeys,
    ),
    requires2FA: requires2FA,
    twoFactorType: twoFactorType,
    organization: organization,
    application: application,
    process: process,
  );
}

// =============================================================================
// TomUser Tests
// =============================================================================

void main() {
  group('TomUser', () {
    group('constructor', () {
      test('should create user with default values', () {
        // Act
        var user = TomUser();

        // Assert
        expect(user.id, equals(-1));
        expect(user.username, equals(TomUser.guestUsername));
        expect(user.firstname, isNull);
        expect(user.lastname, isNull);
        expect(user.email, isNull);
        expect(user.phone, isNull);
        expect(user.mobile, isNull);
        expect(user.addressLine1, isNull);
        expect(user.addressLine2, isNull);
        expect(user.city, isNull);
        expect(user.postcode, isNull);
        expect(user.stateRegion, isNull);
        expect(user.timezone, isNull);
        expect(user.attributes, isEmpty);
      });

      test('should create user with all provided values', () {
        // Arrange
        var attrs = {'key1': 'value1', 'key2': 42};

        // Act
        var user = TomUser(
          id: 123,
          username: 'jdoe',
          firstname: 'John',
          lastname: 'Doe',
          email: 'john.doe@example.com',
          phone: '+1-555-0100',
          mobile: '+1-555-0101',
          addressLine1: '123 Main St',
          addressLine2: 'Apt 4B',
          city: 'New York',
          postcode: '10001',
          stateRegion: 'NY',
          timezone: 'America/New_York',
          attributes: attrs,
        );

        // Assert
        expect(user.id, equals(123));
        expect(user.username, equals('jdoe'));
        expect(user.firstname, equals('John'));
        expect(user.lastname, equals('Doe'));
        expect(user.email, equals('john.doe@example.com'));
        expect(user.phone, equals('+1-555-0100'));
        expect(user.mobile, equals('+1-555-0101'));
        expect(user.addressLine1, equals('123 Main St'));
        expect(user.addressLine2, equals('Apt 4B'));
        expect(user.city, equals('New York'));
        expect(user.postcode, equals('10001'));
        expect(user.stateRegion, equals('NY'));
        expect(user.timezone, equals('America/New_York'));
        expect(user.attributes['key1'], equals('value1'));
        expect(user.attributes['key2'], equals(42));
      });
    });

    group('guestUsername', () {
      test('should have correct guest username constant', () {
        expect(TomUser.guestUsername, equals('GUEST'));
      });

      test('should create guest user by default', () {
        var user = TomUser();
        expect(user.username, equals(TomUser.guestUsername));
      });
    });

    group('attributes', () {
      test('should return unmodifiable map', () {
        // Arrange
        var user = TomUser(attributes: {'key': 'value'});

        // Act & Assert
        expect(
          () => user.attributes['newKey'] = 'newValue',
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should copy the caller\'s map rather than alias it', () {
        // The unmodifiable view only guards the getter. If the constructor
        // keeps the caller's map instead of copying it, the caller still holds
        // a live handle and can edit — or inject into — a user's attributes
        // after construction, which is the one thing the view is there to stop.
        // [TomAccessControlInformation] and [TomClientLimitsInformation] both
        // copy; this is the same contract.
        var attrs = <String, Object?>{'tier': 'gold'};
        var user = TomUser(attributes: attrs);

        // Act — the caller edits the map it still holds.
        attrs['tier'] = 'free';
        attrs['injected'] = true;

        // Assert
        expect(user.attributes['tier'], equals('gold'));
        expect(user.attributes.containsKey('injected'), isFalse);
      });

      test('should refuse modification whether or not attributes were '
          'supplied', () {
        // The default-constructed instance must not be a special case.
        var empty = TomUser();
        var populated = TomUser(attributes: {'tier': 'gold'});

        expect(
          () => empty.attributes['tier'] = 'gold',
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => populated.attributes['tier'] = 'free',
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        // Arrange
        var user = TomUser(
          id: 123,
          username: 'jdoe',
          firstname: 'John',
          lastname: 'Doe',
          email: 'john@example.com',
        );

        // Act
        var result = user.toString();

        // Assert
        expect(result, contains('jdoe'));
        expect(result, contains('123'));
        expect(result, contains('John'));
        expect(result, contains('Doe'));
        expect(result, contains('john@example.com'));
      });
    });
  });

  // ===========================================================================
  // TomAccessControlInformation Tests
  // ===========================================================================

  group('TomAccessControlInformation', () {
    group('constructor', () {
      test('should create with empty lists by default', () {
        // Act
        var aci = TomAccessControlInformation();

        // Assert
        expect(aci.roles, isEmpty);
        expect(aci.groups, isEmpty);
        expect(aci.entitlements, isEmpty);
        expect(aci.resourceKeys, isEmpty);
      });

      test('should create with provided lists', () {
        // Arrange
        var roles = ['admin', 'user'];
        var groups = ['engineering', 'qa'];
        var entitlements = ['feature.read', 'feature.write'];
        var resourceKeys = ['user.email', 'user.phone'];

        // Act
        var aci = TomAccessControlInformation(
          roles: roles,
          groups: groups,
          entitlements: entitlements,
          resourceKeys: resourceKeys,
        );

        // Assert
        expect(aci.roles, containsAll(['admin', 'user']));
        // Regression: groups must reflect the `groups` argument, not a
        // copy-paste of `resourceKeys` (former user_principal_aci.dart bug).
        expect(aci.groups, containsAll(['engineering', 'qa']));
        expect(
          aci.entitlements,
          containsAll(['feature.read', 'feature.write']),
        );
        expect(aci.resourceKeys, containsAll(['user.email', 'user.phone']));
      });
    });

    group('immutability', () {
      test('should return unmodifiable roles list', () {
        // Arrange
        var aci = TomAccessControlInformation(roles: ['admin']);

        // Act & Assert
        expect(() => aci.roles.add('user'), throwsA(isA<UnsupportedError>()));
      });

      test('should return unmodifiable groups list', () {
        // Arrange
        var aci = TomAccessControlInformation(groups: ['team']);

        // Act & Assert
        expect(
          () => aci.groups.add('newTeam'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should return unmodifiable entitlements list', () {
        // Arrange
        var aci = TomAccessControlInformation(entitlements: ['feature.read']);

        // Act & Assert
        expect(
          () => aci.entitlements.add('feature.write'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should return unmodifiable resourceKeys list', () {
        // Arrange
        var aci = TomAccessControlInformation(resourceKeys: ['user.email']);

        // Act & Assert
        expect(
          () => aci.resourceKeys.add('user.phone'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        // Arrange
        var aci = TomAccessControlInformation(
          roles: ['admin', 'user'],
          entitlements: ['read'],
          resourceKeys: ['email', 'phone', 'address'],
          groups: ['team1'],
        );

        // Act
        var result = aci.toString();

        // Assert
        expect(result, contains('2 roles'));
        expect(result, contains('1 entitlements'));
        expect(result, contains('3 resource key'));
      });
    });
  });

  // ===========================================================================
  // TomClientLimitsInformation Tests
  // ===========================================================================

  group('TomClientLimitsInformation', () {
    group('constructor', () {
      test('should create with empty defaults', () {
        // Act
        var cli = TomClientLimitsInformation();

        // Assert
        expect(cli.enabledModules, isEmpty);
        expect(cli.quotas, isEmpty);
      });

      test('should create with provided values', () {
        // Arrange
        var modules = ['core', 'reporting', 'analytics'];
        var quotas = {'api_calls': 1000, 'storage_mb': 500};

        // Act
        var cli = TomClientLimitsInformation(
          enabledModules: modules,
          quotas: quotas,
        );

        // Assert
        expect(
          cli.enabledModules,
          containsAll(['core', 'reporting', 'analytics']),
        );
        expect(cli.quotas['api_calls'], equals(1000));
        expect(cli.quotas['storage_mb'], equals(500));
      });
    });

    group('immutability', () {
      test('should return unmodifiable enabledModules list', () {
        // Arrange
        var cli = TomClientLimitsInformation(enabledModules: ['core']);

        // Act & Assert
        expect(
          () => cli.enabledModules.add('reporting'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should return unmodifiable quotas map', () {
        // Arrange
        var cli = TomClientLimitsInformation(quotas: {'api_calls': 1000});

        // Act & Assert
        expect(
          () => cli.quotas['storage_mb'] = 500,
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should refuse modification the same way whether or not values '
          'were supplied', () {
        // The default-constructed instance must not be a special case. It once
        // was: the empty defaults were `const`, so an untouched instance threw
        // while a populated one accepted the write.
        var empty = TomClientLimitsInformation();
        var populated = TomClientLimitsInformation(
          enabledModules: ['core'],
          quotas: {'api_calls': 1000},
        );

        expect(
          () => empty.enabledModules.add('core'),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => populated.enabledModules.add('reporting'),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => empty.quotas['api_calls'] = 1,
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => populated.quotas['storage_mb'] = 500,
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should copy the caller\'s collections rather than alias them', () {
        // Arrange
        var modules = ['core'];
        var quotas = {'api_calls': 1000};
        var cli = TomClientLimitsInformation(
          enabledModules: modules,
          quotas: quotas,
        );

        // Act — the caller still holds its own references and edits them.
        modules.add('reporting');
        quotas['api_calls'] = 999999;

        // Assert
        expect(cli.enabledModules, equals(['core']));
        expect(cli.quotas['api_calls'], equals(1000));
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        // Arrange
        var cli = TomClientLimitsInformation(
          enabledModules: ['core', 'reporting'],
          quotas: {'api_calls': 1000},
        );

        // Act
        var result = cli.toString();

        // Assert
        expect(result, contains('2 modules'));
        expect(result, contains('quotas'));
      });
    });
  });

  // ===========================================================================
  // TomPrincipal Tests
  // ===========================================================================

  group('TomPrincipal', () {
    group('constructor', () {
      test('should create with default values', () {
        // Act
        var principal = TomPrincipal();

        // Assert
        expect(principal.authenticated, isFalse);
        expect(principal.requires2FA, isFalse);
        expect(principal.twoFactorType, isNull);
        expect(principal.username, equals(TomUser.guestUsername));
        expect(principal.id, equals(-1));
        expect(principal.organization, isNull);
        expect(principal.application, isNull);
        expect(principal.process, isNull);
        expect(principal.organizationId, equals(-1));
        expect(principal.applicationId, equals(-1));
        expect(principal.processId, equals(-1));
        expect(principal.clientId, equals(-1));
        expect(principal.currentContext, isEmpty);
      });

      test('should create with provided values', () {
        // Arrange
        var user = TomUser(id: 42, username: 'jdoe');
        var aci = TomAccessControlInformation(roles: ['admin']);
        var cli = TomClientLimitsInformation(enabledModules: ['core']);

        // Act
        var principal = TomPrincipal(
          authenticated: true,
          user: user,
          aci: aci,
          cli: cli,
          requires2FA: true,
          twoFactorType: 'totp',
          organization: 'TestOrg',
          application: 'TestApp',
          process: 'TestProcess',
          organizationId: 1,
          applicationId: 2,
          processId: 3,
          clientId: 4,
          language: 'en',
          country: 'US',
          timezone: 'America/New_York',
          clientLanguage: 'de',
          clientCountry: 'DE',
          clientTimezone: 'Europe/Berlin',
          context: {'key': 'value'},
        );

        // Assert
        expect(principal.authenticated, isTrue);
        expect(principal.id, equals(42));
        expect(principal.username, equals('jdoe'));
        expect(principal.aci.roles, contains('admin'));
        expect(principal.cli.enabledModules, contains('core'));
        expect(principal.requires2FA, isTrue);
        expect(principal.twoFactorType, equals('totp'));
        expect(principal.organization, equals('TestOrg'));
        expect(principal.application, equals('TestApp'));
        expect(principal.process, equals('TestProcess'));
        expect(principal.organizationId, equals(1));
        expect(principal.applicationId, equals(2));
        expect(principal.processId, equals(3));
        expect(principal.clientId, equals(4));
        expect(principal.language, equals('en'));
        expect(principal.country, equals('US'));
        expect(principal.timezone, equals('America/New_York'));
        expect(principal.clientLanguage, equals('de'));
        expect(principal.clientCountry, equals('DE'));
        expect(principal.clientTimezone, equals('Europe/Berlin'));
        expect(principal.currentContext['key'], equals('value'));
      });
    });

    group('addToContext', () {
      test('should add attributes to context', () {
        // Arrange
        var principal = TomPrincipal(context: {'initial': 'value'});

        // Act
        principal.addToContext({'new': 'data', 'count': 42});

        // Assert
        expect(principal.currentContext['initial'], equals('value'));
        expect(principal.currentContext['new'], equals('data'));
        expect(principal.currentContext['count'], equals(42));
      });

      test('should overwrite existing keys', () {
        // Arrange
        var principal = TomPrincipal(context: {'key': 'original'});

        // Act
        principal.addToContext({'key': 'updated'});

        // Assert
        expect(principal.currentContext['key'], equals('updated'));
      });
    });

    group('user accessors', () {
      test('should return user id', () {
        var principal = TomPrincipal(
          user: TomUser(id: 999, username: 'testuser'),
        );
        expect(principal.id, equals(999));
      });

      test('should return username', () {
        var principal = TomPrincipal(user: TomUser(id: 1, username: 'myuser'));
        expect(principal.username, equals('myuser'));
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        // Arrange
        var principal = TomPrincipal(
          authenticated: true,
          user: TomUser(id: 1, username: 'testuser'),
          organization: 'TestOrg',
        );

        // Act
        var result = principal.toString();

        // Assert
        expect(result, contains('Principal'));
        expect(result, contains('TestOrg'));
      });
    });
  });

  // ===========================================================================
  // TomGroup Tests
  // ===========================================================================

  group('TomGroup', () {
    group('constructor', () {
      test('should create with required name only', () {
        // Act
        var group = TomGroup(name: 'engineering');

        // Assert
        expect(group.name, equals('engineering'));
        expect(group.rolesIncluded, isEmpty);
        expect(group.groupMemberShips, isEmpty);
        expect(group.entitlements, isEmpty);
        expect(group.resourceKeys, isEmpty);
      });

      test('should create with all optional values', () {
        // Act
        var group = TomGroup(
          name: 'engineering',
          rolesIncluded: ['developer', 'user'],
          groupMemberShips: ['all-employees'],
          entitlements: ['repo.access'],
          resourceKeys: ['code.read'],
        );

        // Assert
        expect(group.name, equals('engineering'));
        expect(group.rolesIncluded, containsAll(['developer', 'user']));
        expect(group.groupMemberShips, contains('all-employees'));
        expect(group.entitlements, contains('repo.access'));
        expect(group.resourceKeys, contains('code.read'));
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        var group = TomGroup(
          name: 'testGroup',
          rolesIncluded: ['role1', 'role2'],
          entitlements: ['e1'],
        );
        var result = group.toString();
        expect(result, contains('testGroup'));
        expect(result, contains('2 roles'));
        expect(result, contains('1 entitlements'));
      });
    });
  });

  // ===========================================================================
  // TomRole Tests
  // ===========================================================================

  group('TomRole', () {
    group('constructor', () {
      test('should create with required name only', () {
        // Act
        var role = TomRole(name: 'admin');

        // Assert
        expect(role.name, equals('admin'));
        expect(role.rolesIncluded, isEmpty);
        expect(role.groupMemberShips, isEmpty);
        expect(role.entitlements, isEmpty);
        expect(role.resourceKeys, isEmpty);
      });

      test('should create with all optional values', () {
        // Act
        var role = TomRole(
          name: 'admin',
          rolesIncluded: ['user'],
          groupMemberShips: ['administrators'],
          entitlements: ['admin.*'],
          resourceKeys: ['*'],
        );

        // Assert
        expect(role.name, equals('admin'));
        expect(role.rolesIncluded, contains('user'));
        expect(role.groupMemberShips, contains('administrators'));
        expect(role.entitlements, contains('admin.*'));
        expect(role.resourceKeys, contains('*'));
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        var role = TomRole(name: 'testRole', entitlements: ['e1', 'e2', 'e3']);
        var result = role.toString();
        expect(result, contains('testRole'));
        expect(result, contains('3 entitlements'));
      });
    });
  });

  // ===========================================================================
  // TomEntitlement Tests
  // ===========================================================================

  group('TomEntitlement', () {
    group('constructor', () {
      test('should create with required name only', () {
        // Act
        var entitlement = TomEntitlement(name: 'feature.read');

        // Assert
        expect(entitlement.name, equals('feature.read'));
        expect(entitlement.entitlements, isEmpty);
        expect(entitlement.resourceKeys, isEmpty);
      });

      test('should create with all optional values', () {
        // Act
        var entitlement = TomEntitlement(
          name: 'reports.manage',
          entitlements: ['reports.read', 'reports.create', 'reports.delete'],
          resourceKeys: ['report.data', 'report.metadata'],
        );

        // Assert
        expect(entitlement.name, equals('reports.manage'));
        expect(
          entitlement.entitlements,
          containsAll(['reports.read', 'reports.create', 'reports.delete']),
        );
        expect(
          entitlement.resourceKeys,
          containsAll(['report.data', 'report.metadata']),
        );
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        var entitlement = TomEntitlement(
          name: 'test.entitlement',
          entitlements: ['child1'],
          resourceKeys: ['key1', 'key2'],
        );
        var result = entitlement.toString();
        expect(result, contains('test.entitlement'));
        expect(result, contains('1 entitlements'));
        expect(result, contains('2 resource keys'));
      });
    });
  });

  // ===========================================================================
  // TomAccessControlDefinition Tests
  // ===========================================================================

  group('TomAccessControlDefinition', () {
    group('constructor', () {
      test('should create with empty definitions', () {
        // Act
        var definition = TomAccessControlDefinition();

        // Assert
        var result = definition.toString();
        expect(result, contains('0 roles'));
        expect(result, contains('0 entitlements'));
        expect(result, contains('0 groups'));
      });

      test('should create with roles, groups, and entitlements', () {
        // Act
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(name: 'admin'),
            TomRole(name: 'user'),
          ],
          groups: [TomGroup(name: 'engineering')],
          entitlements: [
            TomEntitlement(name: 'feature.read'),
            TomEntitlement(name: 'feature.write'),
          ],
        );

        // Assert
        var result = definition.toString();
        expect(result, contains('2 roles'));
        expect(result, contains('2 entitlements'));
        expect(result, contains('1 groups'));
      });
    });

    group('completeFromDefinition', () {
      test('should handle empty input ACI', () {
        // Arrange
        var definition = TomAccessControlDefinition(
          roles: [TomRole(name: 'admin')],
        );
        var userAci = TomAccessControlInformation();

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.roles, isEmpty);
        expect(result.groups, isEmpty);
        expect(result.entitlements, isEmpty);
        expect(result.resourceKeys, isEmpty);
      });

      test('should handle definition with single role without inheritance', () {
        // Arrange - single role with no inheritance
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(
              name: 'user',
              entitlements: ['user.read'],
              resourceKeys: ['user.profile'],
            ),
          ],
        );
        var userAci = TomAccessControlInformation(roles: ['user']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.roles, contains('user'));
        expect(result.entitlements, contains('user.read'));
        expect(result.resourceKeys, contains('user.profile'));
      });

      test('should resolve role→role inheritance (admin includes user)', () {
        // Arrange — admin inherits user, which carries an entitlement.
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(name: 'admin', rolesIncluded: ['user']),
            TomRole(name: 'user', entitlements: ['feature.read']),
          ],
        );
        var userAci = TomAccessControlInformation(roles: ['admin']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.roles, containsAll(['admin', 'user']));
        expect(result.entitlements, contains('feature.read'));
      });

      test('should resolve role→group membership', () {
        // Arrange — holding the role grants a group membership.
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(name: 'admin', groupMemberShips: ['staff']),
          ],
          groups: [
            TomGroup(name: 'staff', entitlements: ['staff.badge']),
          ],
        );
        var userAci = TomAccessControlInformation(roles: ['admin']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.groups, contains('staff'));
        expect(result.entitlements, contains('staff.badge'));
      });

      test('should resolve group→group nesting', () {
        // Arrange — staff is a member of employees.
        var definition = TomAccessControlDefinition(
          groups: [
            TomGroup(name: 'staff', groupMemberShips: ['employees']),
            TomGroup(name: 'employees', resourceKeys: ['cafeteria']),
          ],
        );
        var userAci = TomAccessControlInformation(groups: ['staff']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.groups, containsAll(['staff', 'employees']));
        expect(result.resourceKeys, contains('cafeteria'));
      });

      test('should resolve entitlement→entitlement inheritance', () {
        // Arrange — admin.manage includes admin.read, which grants a key.
        var definition = TomAccessControlDefinition(
          entitlements: [
            TomEntitlement(name: 'admin.manage', entitlements: ['admin.read']),
            TomEntitlement(name: 'admin.read', resourceKeys: ['admin.view']),
          ],
        );
        var userAci = TomAccessControlInformation(
          entitlements: ['admin.manage'],
        );

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(
          result.entitlements,
          containsAll(['admin.manage', 'admin.read']),
        );
        expect(result.resourceKeys, contains('admin.view'));
      });

      test('should preserve the user\'s own resource keys', () {
        // The user directly holds a resource key; resolution must keep it
        // rather than dropping it in favour of entitlement names.
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(name: 'user', resourceKeys: ['role.key']),
          ],
        );
        var userAci = TomAccessControlInformation(
          roles: ['user'],
          entitlements: ['some.entitlement'],
          resourceKeys: ['own.key'],
        );

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert — both the user's key and the role-granted key are present,
        // and the entitlement name has NOT leaked into the resource keys.
        expect(result.resourceKeys, containsAll(['own.key', 'role.key']));
        expect(result.resourceKeys, isNot(contains('some.entitlement')));
      });

      test(
        'should preserve the user\'s resourceRoles (C-5 per-resource role map)',
        () {
          // resourceRoles carry the principal's per-resource role assignments
          // (resourceKey → roleName); they are NOT derived from role/group
          // inheritance, so completion must pass them through unchanged. The
          // token minting path (bearer_authentication) runs the principal ACI
          // through this method, so dropping them here silently strips
          // resourceRoles from every minted token.
          var definition = TomAccessControlDefinition(
            roles: [TomRole(name: 'user')],
          );
          var userAci = TomAccessControlInformation(
            roles: ['user'],
            resourceRoles: const {'project:1': 'owner', 'item:9': 'viewer'},
          );

          // Act
          var result = definition.completeFromDefinition(userAci);

          // Assert — the per-resource role map survives completion intact.
          expect(result.resourceRoles, {
            'project:1': 'owner',
            'item:9': 'viewer',
          });
        },
      );

      test('resolved entitlements are entitlements, not a copy of groups', () {
        // Distinct group and entitlement names so a groups/entitlements mixup
        // is detectable.
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(
              name: 'manager',
              groupMemberShips: ['leads'],
              entitlements: ['reports.manage'],
            ),
          ],
          groups: [TomGroup(name: 'leads')],
        );
        var userAci = TomAccessControlInformation(roles: ['manager']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.entitlements, contains('reports.manage'));
        expect(result.entitlements, isNot(contains('leads')));
        expect(result.groups, contains('leads'));
      });

      test('should resolve a multi-level definition end to end', () {
        // role admin → role user, group staff; staff → group employees;
        // entitlement admin.manage → admin.read.
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(
              name: 'admin',
              rolesIncluded: ['user'],
              groupMemberShips: ['staff'],
              entitlements: ['admin.manage'],
              resourceKeys: ['*'],
            ),
            TomRole(
              name: 'user',
              entitlements: ['feature.read'],
              resourceKeys: ['user.profile'],
            ),
          ],
          groups: [
            TomGroup(name: 'staff', groupMemberShips: ['employees']),
            TomGroup(name: 'employees', resourceKeys: ['cafeteria']),
          ],
          entitlements: [
            TomEntitlement(
              name: 'admin.manage',
              entitlements: ['admin.read'],
              resourceKeys: ['admin.panel'],
            ),
            TomEntitlement(name: 'admin.read', resourceKeys: ['admin.view']),
          ],
        );
        var userAci = TomAccessControlInformation(roles: ['admin']);

        // Act
        var result = definition.completeFromDefinition(userAci);

        // Assert
        expect(result.roles, containsAll(['admin', 'user']));
        expect(result.groups, containsAll(['staff', 'employees']));
        expect(
          result.entitlements,
          containsAll(['admin.manage', 'feature.read', 'admin.read']),
        );
        expect(
          result.resourceKeys,
          containsAll([
            '*',
            'user.profile',
            'cafeteria',
            'admin.panel',
            'admin.view',
          ]),
        );
      });
    });

    group('toString', () {
      test('should return formatted string with counts', () {
        var definition = TomAccessControlDefinition(
          roles: [
            TomRole(name: 'r1'),
            TomRole(name: 'r2'),
          ],
          entitlements: [TomEntitlement(name: 'e1')],
        );
        var result = definition.toString();
        expect(result, contains('ACD'));
        expect(result, contains('2 roles'));
        expect(result, contains('1 entitlements'));
      });
    });
  });

  // ===========================================================================
  // TomAuthenticationMessage Tests
  // ===========================================================================

  group('TomAuthenticationMessage', () {
    group('default values', () {
      test('should have correct default values', () {
        // Act
        var message = TomAuthenticationMessage();

        // Assert
        expect(message.client, isEmpty);
        expect(message.userName, equals(TomUser.guestUsername));
        expect(message.password, isEmpty);
        expect(message.application, isEmpty);
        expect(message.process, isEmpty);
        expect(message.organization, isEmpty);
        expect(message.clientLanguage, equals('en'));
        expect(message.clientCountry, equals('XX'));
        expect(message.clientTimezone, equals('utc'));
      });
    });

    group('setting values', () {
      test('should allow setting all properties', () {
        // Arrange & Act
        var message = TomAuthenticationMessage()
          ..client = 'client123'
          ..userName = 'admin'
          ..password = 'P@ssw0rd!'
          ..application = 'web-portal'
          ..process = 'main'
          ..organization = 'acme'
          ..clientLanguage = 'de'
          ..clientCountry = 'DE'
          ..clientTimezone = 'Europe/Berlin';

        // Assert
        expect(message.client, equals('client123'));
        expect(message.userName, equals('admin'));
        expect(message.password, equals('P@ssw0rd!'));
        expect(message.application, equals('web-portal'));
        expect(message.process, equals('main'));
        expect(message.organization, equals('acme'));
        expect(message.clientLanguage, equals('de'));
        expect(message.clientCountry, equals('DE'));
        expect(message.clientTimezone, equals('Europe/Berlin'));
      });
    });
  });

  // ===========================================================================
  // TomAuthenticationResult Tests
  // ===========================================================================

  group('TomAuthenticationResult', () {
    group('constructor', () {
      test('should create with empty error by default', () {
        // Act
        var result = TomAuthenticationResult();

        // Assert
        expect(result.error, isEmpty);
        expect(result.authenticationToken, isEmpty);
        expect(result.authorizationToken, isEmpty);
        expect(result.requires2FA, isFalse);
        expect(result.twoFactorType, isEmpty);
      });

      test('should create with provided error message', () {
        // Act
        var result = TomAuthenticationResult('Invalid credentials');

        // Assert
        expect(result.error, equals('Invalid credentials'));
      });
    });

    group('setting values', () {
      test('should allow setting tokens and 2FA properties', () {
        // Arrange & Act
        var result = TomAuthenticationResult()
          ..authenticationToken = 'auth-token-123'
          ..authorizationToken = 'authz-token-456'
          ..requires2FA = true
          ..twoFactorType = 'totp';

        // Assert
        expect(result.authenticationToken, equals('auth-token-123'));
        expect(result.authorizationToken, equals('authz-token-456'));
        expect(result.requires2FA, isTrue);
        expect(result.twoFactorType, equals('totp'));
      });
    });

    group('success vs error states', () {
      test('should indicate success when error is empty', () {
        var result = TomAuthenticationResult();
        expect(result.error.isEmpty, isTrue);
      });

      test('should indicate failure when error is set', () {
        var result = TomAuthenticationResult('Login failed');
        expect(result.error.isNotEmpty, isTrue);
      });
    });
  });

  // ===========================================================================
  // TomResourceKeyProtection Tests
  // ===========================================================================

  group('TomResourceKeyProtection', () {
    setUp(() {
      // Reset global settings before each test
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          false;
      TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection = false;
      TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection =
          false;
    });

    group('global settings', () {
      test('should have protection disabled by default', () {
        expect(
          TomResourceKeyProtection.globalSettingProtectionDefault,
          isFalse,
        );
      });

      test('should have automatic endpoint protection disabled by default', () {
        expect(
          TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection,
          isFalse,
        );
      });

      test('should have automatic JSON protection disabled by default', () {
        expect(
          TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection,
          isFalse,
        );
      });

      test('should have automatic database protection disabled by default', () {
        expect(
          TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection,
          isFalse,
        );
      });

      test('should allow enabling global protection', () {
        // Act
        TomResourceKeyProtection.globalSettingProtectionDefault = true;

        // Assert
        expect(TomResourceKeyProtection.globalSettingProtectionDefault, isTrue);
      });
    });

    group('isProtectedFor', () {
      test('should read its argument, not the zone principal', () {
        // The rule and its ambient-zone form differ in exactly one respect:
        // where the principal comes from. Pinned by name because every other
        // assertion about the explicit operand is made about
        // `TomResourceKeyAccess`, a one-line delegate — so nothing today would
        // catch this method silently starting to consult the zone.
        TomResourceKeyProtection.globalSettingProtectionDefault = true;
        final holder = createTestPrincipal(resourceKeys: ['user.salary']);
        final stranger = createTestPrincipal(resourceKeys: ['user.email']);

        runZoned(() {
          expect(
            TomResourceKeyProtection.isProtectedFor(stranger, 'user.salary'),
            isTrue,
          );
          // The zone holds the key; the argument does not decide differently
          // for having been asked in that zone.
          expect(TomResourceKeyProtection.isProtected('user.salary'), isFalse);
        }, zoneValues: {TomPrincipal: holder});
      });
    });

    group('isProtected', () {
      test('should return false when protection is disabled', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = false;

        // Act & Assert
        expect(TomResourceKeyProtection.isProtected('any.key'), isFalse);
      });

      test('should return true when protection enabled and no principal', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = true;

        // Act & Assert
        expect(TomResourceKeyProtection.isProtected('any.key'), isTrue);
      });

      test('should return false when principal has resource key', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = true;
        var principal = createTestPrincipal(
          resourceKeys: ['user.email', 'user.phone'],
        );

        // Act
        var result = runZoned(
          () => TomResourceKeyProtection.isProtected('user.email'),
          zoneValues: {TomPrincipal: principal},
        );

        // Assert
        expect(result, isFalse);
      });

      test('should return true when principal lacks resource key', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = true;
        var principal = createTestPrincipal(resourceKeys: ['user.phone']);

        // Act
        var result = runZoned(
          () => TomResourceKeyProtection.isProtected('user.email'),
          zoneValues: {TomPrincipal: principal},
        );

        // Assert
        expect(result, isTrue);
      });
    });

    group('protect', () {
      test('should return data when not protected', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = false;

        // Act
        var result = TomResourceKeyProtection.protect(
          'secret@example.com',
          '[hidden]',
          'user.email',
        );

        // Assert
        expect(result, equals('secret@example.com'));
      });

      test('should return fallback when protected', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = true;

        // Act
        var result = TomResourceKeyProtection.protect(
          'secret@example.com',
          '[hidden]',
          'user.email',
        );

        // Assert
        expect(result, equals('[hidden]'));
      });

      test('should work with different types', () {
        // Arrange
        TomResourceKeyProtection.globalSettingProtectionDefault = true;

        // Act - with int
        var intResult = TomResourceKeyProtection.protect<int>(
          100000,
          -1,
          'salary',
        );
        // Act - with bool
        var boolResult = TomResourceKeyProtection.protect<bool>(
          true,
          false,
          'sensitive',
        );

        // Assert
        expect(intResult, equals(-1));
        expect(boolResult, isFalse);
      });
    });
  });

  // ===========================================================================
  // Helper Functions Tests
  // ===========================================================================

  group('tomProtect', () {
    setUp(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
    });

    test('should be shorthand for TomResourceKeyProtection.protect', () {
      // Arrange
      TomResourceKeyProtection.globalSettingProtectionDefault = false;

      // Act
      var result = tomProtect('data', 'fallback', 'key');

      // Assert
      expect(result, equals('data'));
    });
  });

  group('tomProtected', () {
    setUp(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
    });

    test('should be shorthand for TomResourceKeyProtection.isProtected', () {
      // Arrange
      TomResourceKeyProtection.globalSettingProtectionDefault = false;

      // Act
      var result = tomProtected('any.key');

      // Assert
      expect(result, isFalse);
    });
  });

  // ===========================================================================
  // Access Control Classes Tests
  // ===========================================================================

  group('TomNoAccess', () {
    test('should always deny access', () {
      // Arrange
      var access = const TomNoAccess();
      var principal = createTestPrincipal();

      // Assert
      expect(access.checkAccessibility(null), isFalse);
      expect(access.checkAccessibility(principal), isFalse);
    });
  });

  group('TomPublicAccess', () {
    test('should always grant access', () {
      // Arrange
      var access = const TomPublicAccess();
      var principal = createTestPrincipal();

      // Assert
      expect(access.checkAccessibility(null), isTrue);
      expect(access.checkAccessibility(principal), isTrue);
    });
  });

  group('TomAuthenticatedAccess', () {
    test('should deny access to null principal', () {
      var access = const TomAuthenticatedAccess();
      expect(access.checkAccessibility(null), isFalse);
    });

    test('should deny access to unauthenticated principal', () {
      var access = const TomAuthenticatedAccess();
      var principal = createTestPrincipal(authenticated: false);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test('should deny access to guest user', () {
      var access = const TomAuthenticatedAccess();
      var principal = createTestPrincipal(
        authenticated: true,
        username: TomUser.guestUsername,
      );
      expect(access.checkAccessibility(principal), isFalse);
    });

    test('should grant access to authenticated non-guest user', () {
      var access = const TomAuthenticatedAccess();
      var principal = createTestPrincipal(
        authenticated: true,
        username: 'realuser',
      );
      expect(access.checkAccessibility(principal), isTrue);
    });
  });

  group('TomGuestAccess', () {
    test('should deny access to null principal', () {
      var access = const TomGuestAccess();
      expect(access.checkAccessibility(null), isFalse);
    });

    test('should grant access to guest user', () {
      var access = const TomGuestAccess();
      var principal = TomPrincipal(
        authenticated: false,
        user: TomUser(username: TomUser.guestUsername),
      );
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should grant access to authenticated user', () {
      var access = const TomGuestAccess();
      var principal = createTestPrincipal(authenticated: true);
      expect(access.checkAccessibility(principal), isTrue);
    });
  });

  group('TomRoleAccess', () {
    test('should deny access to null principal', () {
      var access = const TomRoleAccess(['admin']);
      expect(access.checkAccessibility(null), isFalse);
    });

    test('should deny access when principal has no matching role', () {
      var access = const TomRoleAccess(['admin']);
      var principal = createTestPrincipal(roles: ['user']);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test('should grant access when principal has matching role', () {
      var access = const TomRoleAccess(['admin']);
      var principal = createTestPrincipal(roles: ['admin', 'user']);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should grant access if any role matches (OR logic)', () {
      var access = const TomRoleAccess(['admin', 'superuser']);
      var principal = createTestPrincipal(roles: ['superuser']);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should deny access when principal has empty roles', () {
      var access = const TomRoleAccess(['admin']);
      var principal = createTestPrincipal(roles: []);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test(
      'should deny access when access declares no roles (empty candidates)',
      () {
        // Pins the shared _principalAciContainsAny contract: an empty candidate
        // list can never match, regardless of what the principal holds.
        var access = const TomRoleAccess([]);
        var principal = createTestPrincipal(roles: ['admin']);
        expect(access.checkAccessibility(principal), isFalse);
      },
    );
  });

  group('TomGroupAccess', () {
    test('should deny access to null principal', () {
      var access = const TomGroupAccess(['engineering']);
      expect(access.checkAccessibility(null), isFalse);
    });

    test('should deny access when principal has no matching group', () {
      var access = const TomGroupAccess(['engineering']);
      var principal = createTestPrincipalWithGroups(groups: ['marketing']);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test('should grant access when principal has matching group', () {
      var access = const TomGroupAccess(['engineering']);
      var principal = createTestPrincipalWithGroups(
        groups: ['engineering', 'qa'],
      );
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should grant access if any group matches (OR logic)', () {
      var access = const TomGroupAccess(['hr', 'management']);
      var principal = createTestPrincipalWithGroups(groups: ['management']);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should deny access when principal has empty groups', () {
      // Parity with the TomRoleAccess empty-collection case — both share the
      // extracted _principalAciContainsAny helper.
      var access = const TomGroupAccess(['engineering']);
      var principal = createTestPrincipalWithGroups(groups: []);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test(
      'should deny access when access declares no groups (empty candidates)',
      () {
        var access = const TomGroupAccess([]);
        var principal = createTestPrincipalWithGroups(groups: ['engineering']);
        expect(access.checkAccessibility(principal), isFalse);
      },
    );
  });

  group('TomEntitlementAccess', () {
    test('should deny access to null principal', () {
      var access = const TomEntitlementAccess(['feature.read']);
      expect(access.checkAccessibility(null), isFalse);
    });

    test('should deny access when principal has no entitlements', () {
      var access = const TomEntitlementAccess(['feature.read']);
      var principal = createTestPrincipal(entitlements: []);
      expect(access.checkAccessibility(principal), isFalse);
    });

    test('should grant access for exact match', () {
      var access = const TomEntitlementAccess(['feature.read']);
      var principal = createTestPrincipal(entitlements: ['feature.read']);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should grant access for regex pattern match', () {
      var access = const TomEntitlementAccess([r'feature\..*']);
      var principal = createTestPrincipal(
        entitlements: ['feature.read', 'feature.write'],
      );
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should grant access if any pattern matches', () {
      var access = const TomEntitlementAccess(['admin.*', 'feature.edit']);
      var principal = createTestPrincipal(entitlements: ['feature.edit']);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should deny access when no pattern matches', () {
      var access = const TomEntitlementAccess(['admin.*']);
      var principal = createTestPrincipal(entitlements: ['user.read']);
      expect(access.checkAccessibility(principal), isFalse);
    });
  });

  group('TomResourceKeyAccess', () {
    setUp(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
    });

    tearDown(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
    });

    test('should grant access when protection is disabled', () {
      var access = const TomResourceKeyAccess('user.salary');
      expect(access.checkAccessibility(null), isTrue);
    });

    test(
      'should grant access to any principal when protection is disabled',
      () {
        // The master switch is the whole rule while it is off: the key the
        // principal does not hold is still not a reason to deny.
        var access = const TomResourceKeyAccess('user.salary');
        var principal = createTestPrincipal(resourceKeys: ['user.email']);
        expect(access.checkPrincipalAccess(principal), isTrue);
      },
    );

    test('should grant access when the given principal holds the key', () {
      // The argument is the operand. No principal is installed on the zone, so
      // this can only pass if the control reads the one it was handed.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');
      var principal = createTestPrincipal(
        resourceKeys: ['user.salary', 'user.email'],
      );
      expect(access.checkPrincipalAccess(principal), isTrue);
    });

    test('should deny access when the given principal lacks the key', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');
      var principal = createTestPrincipal(resourceKeys: ['user.email']);
      expect(access.checkPrincipalAccess(principal), isFalse);
    });

    test('should deny access to null principal when protection is enabled', () {
      // Fail-closed: an unauthenticated caller holds no keys, so a protected
      // resource is out of reach.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');
      expect(access.checkPrincipalAccess(null), isFalse);
    });

    test('should ignore the zone principal in favour of the argument', () {
      // The two operands disagree on purpose. `checkPrincipalAccess` answers
      // about the principal it is asked about — the same promise every other
      // control in this family makes — so a zone principal must neither rescue
      // an argument that lacks the key nor condemn one that holds it.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');
      var holder = createTestPrincipal(resourceKeys: ['user.salary']);
      var stranger = createTestPrincipal(resourceKeys: ['user.email']);

      var strangerUnderHolderZone = runZoned(
        () => access.checkPrincipalAccess(stranger),
        zoneValues: {TomPrincipal: holder},
      );
      var holderUnderStrangerZone = runZoned(
        () => access.checkPrincipalAccess(holder),
        zoneValues: {TomPrincipal: stranger},
      );

      expect(strangerUnderHolderZone, isFalse);
      expect(holderUnderStrangerZone, isTrue);
    });

    test('should agree with its siblings through checkAccessibility', () {
      // The public entry point, reached the way `doc/security/security.md`
      // shows it: one principal argument, uniform across the family.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');
      expect(
        access.checkAccessibility(
          createTestPrincipal(resourceKeys: ['user.salary']),
        ),
        isTrue,
      );
      expect(
        access.checkAccessibility(createTestPrincipal(resourceKeys: [])),
        isFalse,
      );
    });
  });

  group('TomCustomAccess', () {
    setUp(() {
      // Note: We can't clear handlers, so be careful with test isolation
    });

    test('should throw when registering duplicate handler', () {
      // Arrange
      const handlerName = 'testDuplicateHandler';
      TomCustomAccess.registerHandler(handlerName, (principal, id) => true);

      // Act & Assert
      expect(
        () => TomCustomAccess.registerHandler(
          handlerName,
          (principal, id) => false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw when getting non-existent handler', () {
      expect(
        () => TomCustomAccess.getHandler('nonExistentHandler'),
        throwsA(isA<Exception>()),
      );
    });

    test('should return true for handlerExists when registered', () {
      const handlerName = 'testExistsHandler';
      TomCustomAccess.registerHandler(handlerName, (principal, id) => true);
      expect(TomCustomAccess.handlerExists(handlerName), isTrue);
    });

    test('should return false for handlerExists when not registered', () {
      expect(TomCustomAccess.handlerExists('unknownHandler'), isFalse);
    });

    test('should delegate to registered handler', () {
      // Arrange
      const handlerName = 'documentOwnerHandler';
      TomCustomAccess.registerHandler(handlerName, (principal, id) {
        return principal != null && id == '123';
      });
      var access = const TomCustomAccess(
        handler: handlerName,
        resourceId: '123',
      );
      var principal = createTestPrincipal();

      // Act & Assert
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('should pass resourceId to handler', () {
      // Arrange
      const handlerName = 'resourceIdTestHandler';
      String? receivedId;
      TomCustomAccess.registerHandler(handlerName, (principal, id) {
        receivedId = id;
        return true;
      });
      var access = const TomCustomAccess(
        handler: handlerName,
        resourceId: 'myResource456',
      );

      // Act
      access.checkAccessibility(createTestPrincipal());

      // Assert
      expect(receivedId, equals('myResource456'));
    });

    test('should verifyHandler return true for registered handler', () {
      const handlerName = 'verifyTestHandler';
      TomCustomAccess.registerHandler(handlerName, (p, id) => true);
      var access = const TomCustomAccess(handler: handlerName, resourceId: 'x');
      expect(access.verifyHandler(), isTrue);
    });

    test('should verifyHandler return false for unregistered handler', () {
      var access = const TomCustomAccess(
        handler: 'unregisteredHandlerForVerify',
        resourceId: 'x',
      );
      expect(access.verifyHandler(), isFalse);
    });
  });

  // ===========================================================================
  // Abstract TomAccessControl Tests
  // ===========================================================================

  group('TomAccessControl', () {
    test('should return false by default for checkAccessibility', () {
      // Create a minimal concrete implementation
      var access = _TestAccessControl();
      expect(access.checkAccessibility(null), isFalse);
      expect(access.checkAccessibility(createTestPrincipal()), isFalse);
    });
  });

  // ===========================================================================
  // TomAuthState — four-state authorization outcome
  // ===========================================================================
  group('TomAuthState', () {
    test('orders from most to least restrictive by index', () {
      expect(TomAuthState.none.index, lessThan(TomAuthState.disabled.index));
      expect(TomAuthState.disabled.index, lessThan(TomAuthState.read.index));
      expect(TomAuthState.read.index, lessThan(TomAuthState.full.index));
    });

    group('predicates', () {
      test('isVisible is false only for none', () {
        expect(TomAuthState.none.isVisible, isFalse);
        expect(TomAuthState.disabled.isVisible, isTrue);
        expect(TomAuthState.read.isVisible, isTrue);
        expect(TomAuthState.full.isVisible, isTrue);
      });

      test('isInteractive is true only for full', () {
        expect(TomAuthState.none.isInteractive, isFalse);
        expect(TomAuthState.disabled.isInteractive, isFalse);
        expect(TomAuthState.read.isInteractive, isFalse);
        expect(TomAuthState.full.isInteractive, isTrue);
      });

      test('showsContent is true for read and full', () {
        expect(TomAuthState.none.showsContent, isFalse);
        expect(TomAuthState.disabled.showsContent, isFalse);
        expect(TomAuthState.read.showsContent, isTrue);
        expect(TomAuthState.full.showsContent, isTrue);
      });
    });

    group('narrow', () {
      test('returns the more restrictive of the two states', () {
        expect(
          TomAuthState.full.narrow(TomAuthState.read),
          equals(TomAuthState.read),
        );
        expect(
          TomAuthState.read.narrow(TomAuthState.full),
          equals(TomAuthState.read),
        );
        expect(
          TomAuthState.disabled.narrow(TomAuthState.none),
          equals(TomAuthState.none),
        );
      });

      test('is idempotent for equal states', () {
        expect(
          TomAuthState.read.narrow(TomAuthState.read),
          equals(TomAuthState.read),
        );
      });
    });

    group('widen', () {
      test('returns the less restrictive of the two states', () {
        expect(
          TomAuthState.read.widen(TomAuthState.full),
          equals(TomAuthState.full),
        );
        expect(
          TomAuthState.full.widen(TomAuthState.read),
          equals(TomAuthState.full),
        );
        expect(
          TomAuthState.none.widen(TomAuthState.disabled),
          equals(TomAuthState.disabled),
        );
      });

      test('is idempotent for equal states', () {
        expect(
          TomAuthState.full.widen(TomAuthState.full),
          equals(TomAuthState.full),
        );
      });
    });
  });

  // ===========================================================================
  // TomAuthorization — global authorization singleton
  // ===========================================================================
  group('TomAuthorization', () {
    tearDown(TomAuthorization.reset);

    test('resolves to full when no adapter is set (development mode)', () {
      TomAuthorization.reset();
      expect(
        TomAuthorization.resolveAuth('any.path'),
        equals(TomAuthState.full),
      );
    });

    test('delegates to the installed adapter', () {
      TomAuthorization.adapter = _FakeAuthAdapter({
        'checkout.email': TomAuthState.read,
        'checkout.secret': TomAuthState.none,
      });
      expect(
        TomAuthorization.resolveAuth('checkout.email'),
        equals(TomAuthState.read),
      );
      expect(
        TomAuthorization.resolveAuth('checkout.secret'),
        equals(TomAuthState.none),
      );
      // Unknown paths fall back to the adapter default (full here).
      expect(
        TomAuthorization.resolveAuth('unknown'),
        equals(TomAuthState.full),
      );
    });

    test('reset removes the adapter', () {
      TomAuthorization.adapter = _FakeAuthAdapter({'x': TomAuthState.none});
      TomAuthorization.reset();
      expect(TomAuthorization.resolveAuth('x'), equals(TomAuthState.full));
    });

    // `adapter` reads as well as writes. A diagnostics screen, a startup
    // assertion, and any caller that installs an adapter for one operation
    // all need that read: without it the only way back from a temporary
    // install is `reset()`, which is a teardown rather than a restore.
    test('the installed adapter reads back, and is null until one is set', () {
      TomAuthorization.reset();
      expect(TomAuthorization.adapter, isNull);

      final adapter = _FakeAuthAdapter({'x': TomAuthState.none});
      TomAuthorization.adapter = adapter;
      expect(TomAuthorization.adapter, same(adapter));

      TomAuthorization.reset();
      expect(TomAuthorization.adapter, isNull);
    });

    test('an adapter can be swapped in and the previous one put back', () {
      final original = _FakeAuthAdapter({'x': TomAuthState.read});
      TomAuthorization.adapter = original;
      final saved = TomAuthorization.adapter;

      TomAuthorization.adapter = _FakeAuthAdapter({'x': TomAuthState.none});
      expect(TomAuthorization.resolveAuth('x'), equals(TomAuthState.none));

      TomAuthorization.adapter = saved;
      expect(TomAuthorization.adapter, same(original));
      expect(TomAuthorization.resolveAuth('x'), equals(TomAuthState.read));
    });

    // The setter accepts null so that restoring "nothing was installed" is
    // expressible without a branch through reset(). Here the two happen to be
    // equivalent — this class holds no registrations — but the read/write
    // contract is shared with TomUIColors and TomUIIcons, where they are not.
    test('assigning null restores the no-adapter development default', () {
      TomAuthorization.adapter = _FakeAuthAdapter({'x': TomAuthState.none});
      TomAuthorization.adapter = null;

      expect(TomAuthorization.adapter, isNull);
      expect(TomAuthorization.resolveAuth('x'), equals(TomAuthState.full));
    });
  });

  // ===========================================================================
  // TomAuthorizationGroup — collective authorization control
  // ===========================================================================
  group('TomAuthorizationGroup', () {
    tearDown(TomAuthorization.reset);

    test('defaults to controlsWidest mode', () {
      final group = TomAuthorizationGroup('shipping');
      expect(group.mode, equals(AuthGroupMode.controlsWidest));
    });

    group('membership', () {
      test('register / unregister adjusts member count', () {
        final group = TomAuthorizationGroup('g');
        final a = _FakeAuthorizable('a');
        final b = _FakeAuthorizable('b');
        expect(group.isEmpty, isTrue);
        group.register(a);
        group.register(b);
        expect(group.memberCount, equals(2));
        expect(group.isNotEmpty, isTrue);
        group.unregister(a);
        expect(group.memberCount, equals(1));
        expect(group.members.map((m) => m.tomId), equals(['b']));
      });

      test('findMember locates a member by tomId', () {
        final group = TomAuthorizationGroup('g');
        final a = _FakeAuthorizable('street');
        group.register(a);
        expect(group.findMember('street'), same(a));
        expect(group.findMember('missing'), isNull);
      });
    });

    // A `none` member is hidden — it does not exist from the user's
    // perspective, so it must not exist for inspection either. Every helper
    // has to agree on that, or callers get a group that simultaneously has
    // members and is empty.
    group('hidden members are invisible to every inspection helper', () {
      TomAuthorizationGroup buildGroup() => TomAuthorizationGroup('g')
        ..register(_FakeAuthorizable('visible', auth: TomAuthState.read))
        ..register(_FakeAuthorizable('hidden', auth: TomAuthState.none));

      test('members omits hidden members', () {
        expect(buildGroup().members.map((m) => m.tomId), equals(['visible']));
      });

      test('memberCount counts only visible members', () {
        expect(buildGroup().memberCount, equals(1));
      });

      test('findMember does not find a hidden member', () {
        final group = buildGroup();
        expect(group.findMember('hidden'), isNull);
        expect(group.findMember('visible'), isNotNull);
      });

      test('a group whose members are all hidden reports empty', () {
        final group = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.none))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.none));
        expect(group.isEmpty, isTrue);
        expect(group.isNotEmpty, isFalse);
        expect(group.memberCount, isZero);
        expect(group.members, isEmpty);
      });

      test('a hidden member becoming visible restores it to every helper', () {
        final member = _MutableAuthorizable('a', TomAuthState.none);
        final group = TomAuthorizationGroup('g')..register(member);
        expect(group.isEmpty, isTrue);
        expect(group.findMember('a'), isNull);

        member.auth = TomAuthState.read;

        expect(group.isEmpty, isFalse);
        expect(group.memberCount, equals(1));
        expect(group.findMember('a'), same(member));
      });

      // Registration bookkeeping must NOT go through the visibility filter:
      // a hidden member is still registered, and whoever registered it must
      // still be able to take it back out.
      test('a hidden member can still be unregistered', () {
        final hidden = _MutableAuthorizable('hidden', TomAuthState.none);
        final group = TomAuthorizationGroup('g')..register(hidden);

        group.unregister(hidden);
        // Revealing it is what makes the removal observable: an unregister
        // that had gone through the visibility filter would have missed it,
        // and the member would come back from the dead here.
        hidden.auth = TomAuthState.full;

        expect(group.isEmpty, isTrue);
        expect(group.findMember('hidden'), isNull);
      });
    });

    group('applyMode', () {
      test('controlsAll replaces the member state with the group state', () {
        TomAuthorization.adapter = _FakeAuthAdapter({'g': TomAuthState.read});
        final group = TomAuthorizationGroup(
          'g',
          mode: AuthGroupMode.controlsAll,
        );
        expect(group.applyMode(TomAuthState.full), equals(TomAuthState.read));
        expect(group.applyMode(TomAuthState.none), equals(TomAuthState.read));
      });

      test('controlsWidest narrows the member to the group ceiling', () {
        TomAuthorization.adapter = _FakeAuthAdapter({'g': TomAuthState.read});
        final group = TomAuthorizationGroup(
          'g',
          mode: AuthGroupMode.controlsWidest,
        );
        // Member wider than group → narrowed to group.
        expect(group.applyMode(TomAuthState.full), equals(TomAuthState.read));
        // Member already narrower → unchanged.
        expect(
          group.applyMode(TomAuthState.disabled),
          equals(TomAuthState.disabled),
        );
      });

      test('controlsNarrowest widens the member to the group floor', () {
        TomAuthorization.adapter = _FakeAuthAdapter({'g': TomAuthState.read});
        final group = TomAuthorizationGroup(
          'g',
          mode: AuthGroupMode.controlsNarrowest,
        );
        // Member narrower than group → widened to group.
        expect(group.applyMode(TomAuthState.none), equals(TomAuthState.read));
        // Member already wider → unchanged.
        expect(group.applyMode(TomAuthState.full), equals(TomAuthState.full));
      });
    });

    group('aggregate state', () {
      test('isUniform is true for an empty group', () {
        expect(TomAuthorizationGroup('g').isUniform, isTrue);
      });

      test('isUniform ignores hidden members and compares the rest', () {
        final group = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.read))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.read))
          ..register(_FakeAuthorizable('c', auth: TomAuthState.none));
        expect(group.isUniform, isTrue);
      });

      test('isUniform is false when visible members differ', () {
        final group = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.read))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.full));
        expect(group.isUniform, isFalse);
      });

      test('mostRestrictive returns the narrowest visible state', () {
        final group = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.full))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.read))
          ..register(_FakeAuthorizable('c', auth: TomAuthState.none));
        expect(group.mostRestrictive, equals(TomAuthState.read));
      });

      // `full` is the identity element of the narrowing fold, not an answer.
      // Returning it for a group with nothing visible told every caller the
      // opposite of the truth: the one aggregate you would reach for to ask
      // "does this group have anything to show?" reported the most permissive
      // state possible for the two cases where it shows nothing at all.
      test('mostRestrictive is none for an empty group', () {
        expect(
          TomAuthorizationGroup('g').mostRestrictive,
          equals(TomAuthState.none),
        );
      });

      test('mostRestrictive is none when every member is hidden', () {
        final group = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.none))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.none));
        expect(group.mostRestrictive, equals(TomAuthState.none));
      });

      // The defect in one assertion: these two groups are opposites, and the
      // aggregate has to tell them apart.
      test('a fully hidden group does not read as a fully open one', () {
        final hidden = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.none))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.none));
        final open = TomAuthorizationGroup('g')
          ..register(_FakeAuthorizable('a', auth: TomAuthState.full))
          ..register(_FakeAuthorizable('b', auth: TomAuthState.full));

        expect(hidden.mostRestrictive, equals(TomAuthState.none));
        expect(open.mostRestrictive, equals(TomAuthState.full));
        expect(hidden.mostRestrictive, isNot(equals(open.mostRestrictive)));
      });

      // Nothing is cached: the aggregate is recomputed from live member
      // state, so a member that becomes visible restores a real answer.
      test('revealing a hidden member gives mostRestrictive a real answer', () {
        final member = _MutableAuthorizable('a', TomAuthState.none);
        final group = TomAuthorizationGroup('g')..register(member);
        expect(group.mostRestrictive, equals(TomAuthState.none));

        member.auth = TomAuthState.read;

        expect(group.mostRestrictive, equals(TomAuthState.read));
      });
    });

    test('toString renders the groupId and the mode, and nothing else', () {
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsAll,
      );
      // Pinned exactly rather than by `contains`, because this string is
      // documented as the group's debugger/log rendering and a substring
      // check would let the shape drift out from under that.
      expect(
        group.toString(),
        'TomAuthorizationGroup(shipping, mode: AuthGroupMode.controlsAll)',
      );
    });

    test('toString reports no membership, so it stays side-effect free', () {
      // Deliberately absent: a member count would make `toString` call
      // `members`, which prunes collected weak references and evaluates
      // `effectiveAuthState` on every registration. `toString` is what a
      // debugger and an error formatter call, so it must not resolve
      // authorization — least of all while an error is already being built.
      final member = _MutableAuthorizable('a', TomAuthState.full);
      final group = TomAuthorizationGroup('shipping')..register(member);

      expect(
        group.toString(),
        'TomAuthorizationGroup(shipping, mode: AuthGroupMode.controlsWidest)',
      );
      expect(group.memberCount, 1);
    });
  });

  // ===========================================================================
  // TomAuthorizer — per-element authorization modifier
  // ===========================================================================
  group('TomAuthorizer', () {
    test('defaults to authorizerNarrowsOnly strategy', () {
      final authorizer = TomAuthorizer(resolve: (r) => r);
      expect(
        authorizer.strategy,
        equals(TomAuthorizerStrategy.authorizerNarrowsOnly),
      );
    });

    test('authorizerNarrowsOnly never widens the resource auth', () {
      final authorizer = TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
        resolve: (_) => TomAuthState.full,
      );
      // Authorizer wants full but resource is read → stays read.
      expect(
        authorizer.effectiveAuth(TomAuthState.read),
        equals(TomAuthState.read),
      );
    });

    test('authorizerNarrowsOnly applies further restriction', () {
      final authorizer = TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
        resolve: (_) => TomAuthState.disabled,
      );
      expect(
        authorizer.effectiveAuth(TomAuthState.full),
        equals(TomAuthState.disabled),
      );
    });

    test('authorizerDecides returns the authorizer result verbatim', () {
      final authorizer = TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerDecides,
        resolve: (_) => TomAuthState.full,
      );
      // Even though resource is none, authorizerDecides can widen.
      expect(
        authorizer.effectiveAuth(TomAuthState.none),
        equals(TomAuthState.full),
      );
    });

    test('fixed always returns the fixed state regardless of resource', () {
      final authorizer = TomAuthorizer.fixed(TomAuthState.disabled);
      expect(
        authorizer.effectiveAuth(TomAuthState.full),
        equals(TomAuthState.disabled),
      );
      expect(
        authorizer.effectiveAuth(TomAuthState.none),
        equals(TomAuthState.disabled),
      );
    });

    group('fromAction', () {
      test('hidden widget stays hidden', () {
        final authorizer = TomAuthorizer.fromAction(
          actionAuth: () => TomAuthState.full,
        );
        expect(
          authorizer.effectiveAuth(TomAuthState.none),
          equals(TomAuthState.none),
        );
      });

      test('full widget + action none → disabled', () {
        final authorizer = TomAuthorizer.fromAction(
          actionAuth: () => TomAuthState.none,
        );
        expect(
          authorizer.effectiveAuth(TomAuthState.full),
          equals(TomAuthState.disabled),
        );
      });

      test('otherwise narrows to the most restrictive', () {
        final authorizer = TomAuthorizer.fromAction(
          actionAuth: () => TomAuthState.read,
        );
        expect(
          authorizer.effectiveAuth(TomAuthState.full),
          equals(TomAuthState.read),
        );
      });
    });
  });

  // ===========================================================================
  // TomUIStateController — build-time state narrowing
  // ===========================================================================
  group('TomUIStateController', () {
    test('apply never widens the current auth', () {
      final controller = TomUIStateController(
        resolve: (current, data) => TomAuthState.full,
      );
      // Controller wants full but current is read → stays read.
      expect(controller.apply(TomAuthState.read), equals(TomAuthState.read));
    });

    test(
      'apply narrows when the resolver returns a more restrictive state',
      () {
        final controller = TomUIStateController(
          resolve: (current, data) => TomAuthState.disabled,
        );
        expect(
          controller.apply(TomAuthState.full),
          equals(TomAuthState.disabled),
        );
      },
    );

    test('apply forwards the data argument to the resolver', () {
      Object? seen;
      final controller = TomUIStateController(
        resolve: (current, data) {
          seen = data;
          return current;
        },
      );
      controller.apply(TomAuthState.full, data: {'ownerId': 7});
      expect(seen, equals({'ownerId': 7}));
    });
  });

  // ===========================================================================
  // TomAccessControl.resolveAuthState — binary→four-state bridge
  // ===========================================================================
  group('TomAccessControl.resolveAuthState', () {
    test('default maps a granting binary control to full', () {
      expect(
        const TomPublicAccess().resolveAuthState(null),
        equals(TomAuthState.full),
      );
    });

    test('default maps a denying binary control to none', () {
      expect(
        const TomNoAccess().resolveAuthState(null),
        equals(TomAuthState.none),
      );
    });

    test('role access resolves to full when the role is present', () {
      final principal = createTestPrincipal(roles: ['admin']);
      expect(
        const TomRoleAccess(['admin']).resolveAuthState(principal),
        equals(TomAuthState.full),
      );
    });

    test('role access resolves to none when the role is absent', () {
      final principal = createTestPrincipal(roles: ['user']);
      expect(
        const TomRoleAccess(['admin']).resolveAuthState(principal),
        equals(TomAuthState.none),
      );
    });

    test(
      'checkAccessibility stays the binary source of truth (backward compat)',
      () {
        // The default resolveAuthState is derived from the unchanged binary API.
        expect(const TomPublicAccess().checkAccessibility(null), isTrue);
        expect(const TomNoAccess().checkAccessibility(null), isFalse);
        expect(
          const TomPublicAccess().resolveAuthState(null).isInteractive,
          isTrue,
        );
        expect(const TomNoAccess().resolveAuthState(null).isVisible, isFalse);
      },
    );
  });

  // ===========================================================================
  // TomGradedAccess — composes binary controls into all four states
  // ===========================================================================
  group('TomGradedAccess', () {
    const granting = TomPublicAccess();
    const denying = TomNoAccess();

    test('full when the full control grants', () {
      final access = TomGradedAccess(
        full: granting,
        read: granting,
        disabled: granting,
      );
      expect(access.resolveAuthState(null), equals(TomAuthState.full));
    });

    test('read when full denies but read grants', () {
      final access = TomGradedAccess(
        full: denying,
        read: granting,
        disabled: granting,
      );
      expect(access.resolveAuthState(null), equals(TomAuthState.read));
    });

    test('disabled when only the disabled control grants', () {
      final access = TomGradedAccess(
        full: denying,
        read: denying,
        disabled: granting,
      );
      expect(access.resolveAuthState(null), equals(TomAuthState.disabled));
    });

    test('none when nothing grants', () {
      final access = TomGradedAccess(
        full: denying,
        read: denying,
        disabled: denying,
      );
      expect(access.resolveAuthState(null), equals(TomAuthState.none));
    });

    test(
      'read and disabled default to full so a full grant reads and sees',
      () {
        // Only the full control supplied: a granting full grant is interactive.
        expect(
          TomGradedAccess(full: granting).resolveAuthState(null),
          equals(TomAuthState.full),
        );
        // A denying full with no read/disabled override collapses to none.
        expect(
          TomGradedAccess(full: denying).resolveAuthState(null),
          equals(TomAuthState.none),
        );
      },
    );

    test('checkAccessibility collapses to "shows content" (read or full)', () {
      final readOnly = TomGradedAccess(
        full: denying,
        read: granting,
        disabled: granting,
      );
      expect(
        readOnly.checkAccessibility(null),
        isTrue,
        reason: 'a read state shows content',
      );
      final disabledOnly = TomGradedAccess(
        full: denying,
        read: denying,
        disabled: granting,
      );
      expect(
        disabledOnly.checkAccessibility(null),
        isFalse,
        reason: 'a disabled state hides content',
      );
    });

    test('grades role access against the principal', () {
      final access = TomGradedAccess(
        full: const TomRoleAccess(['editor']),
        read: const TomRoleAccess(['viewer']),
      );
      expect(
        access.resolveAuthState(createTestPrincipal(roles: ['editor'])),
        equals(TomAuthState.full),
      );
      expect(
        access.resolveAuthState(createTestPrincipal(roles: ['viewer'])),
        equals(TomAuthState.read),
      );
      expect(
        access.resolveAuthState(createTestPrincipal(roles: ['nobody'])),
        equals(TomAuthState.none),
      );
    });
  });

  // ===========================================================================
  // TomBearerAuthentication Tests
  // ===========================================================================

  group('TomBearerAuthentication', () {
    setUp(() {
      // ACI fields are stored verbatim (no protection redaction) so the
      // round-trip is byte-for-byte comparable.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      // Each test starts from a clean singleton; getPrincipal/setTokens mutate
      // global state.
      TomBearerAuthentication.bearerAuthentication = TomBearerAuthentication();
    });

    tearDown(() {
      TomBearerAuthentication.bearerAuthentication = TomBearerAuthentication();
    });

    group('convertPrincipalToTokenPayload ↔ convertTokenPayloadToPrincipal', () {
      test('round-trips identity and ACI through a single token', () {
        final principal = createTestPrincipal(
          username: 'alice',
          roles: ['admin', 'user'],
          groups: ['engineering'],
          entitlements: ['reports.view'],
          resourceKeys: ['user.email'],
        );

        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          principal,
          null,
          'US',
          'en',
        );

        final token = _FakeClientJwtToken(
          payload: publicInfo,
          secretData: privateInfo,
        );
        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          token,
        );

        expect(restored.username, equals('alice'));
        expect(restored.authenticated, isTrue);
        expect(restored.user.firstname, equals('Test'));
        expect(restored.user.lastname, equals('User'));
        expect(restored.user.email, equals('test@example.com'));
        expect(restored.organization, equals('testOrg'));
        expect(restored.application, equals('testApp'));
        expect(restored.process, equals('testProcess'));
        expect(restored.clientCountry, equals('US'));
        expect(restored.clientLanguage, equals('en'));
        expect(restored.aci.roles, containsAll(['admin', 'user']));
        expect(restored.aci.groups, contains('engineering'));
        expect(restored.aci.entitlements, contains('reports.view'));
        expect(restored.aci.resourceKeys, contains('user.email'));
      });

      test(
        'C-5: carries per-resource roles through the token so re-login applies '
        'them',
        () {
          // A principal whose role differs per resource (Alice: owner of X,
          // viewer of Y). The authorization token must carry that map so a fresh
          // login (re-parse of the token) sees the current grants — G-AUTHZ-5.
          final alice = createTestPrincipal(
            username: 'alice',
            resourceRoles: {'project.X': 'owner', 'project.Y': 'viewer'},
          );

          final (
            publicInfo,
            privateInfo,
          ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
            alice,
            null,
            'US',
            'en',
          );

          // The per-resource roles ride in the encrypted (private) payload.
          expect(
            privateInfo['resourceRoles'],
            equals({'project.X': 'owner', 'project.Y': 'viewer'}),
          );

          final token = _FakeClientJwtToken(
            payload: publicInfo,
            secretData: privateInfo,
          );
          final restored =
              TomBearerAuthentication.convertTokenPayloadToPrincipal(token);

          expect(
            restored.aci.resourceRoles,
            equals({'project.X': 'owner', 'project.Y': 'viewer'}),
          );
        },
      );

      test('a guest username round-trips as not authenticated', () {
        final guest = createTestPrincipal(
          authenticated: false,
          username: TomUser.guestUsername,
        );

        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          guest,
          null,
          null,
          null,
        );

        final token = _FakeClientJwtToken(
          payload: publicInfo,
          secretData: privateInfo,
        );
        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          token,
        );

        expect(restored.username, equals(TomUser.guestUsername));
        expect(restored.authenticated, isFalse);
      });
    });

    group('convertPrincipalToTokenPayload redacts against its subject', () {
      // Every other test in this file runs with protection off, which is the
      // library default and makes redaction a no-op. These tests are the only
      // ones that switch it on, so they are the only ones that can observe
      // *whose* keys decide the payload.
      setUp(() {
        TomResourceKeyProtection.globalSettingProtectionDefault = true;
      });

      tearDown(() {
        TomResourceKeyProtection.globalSettingProtectionDefault = false;
      });

      /// A principal carrying every field the payload runs through protection,
      /// holding exactly the [resourceKeys] given.
      TomPrincipal subject({List<String> resourceKeys = const []}) =>
          TomPrincipal(
            authenticated: true,
            user: TomUser(
              id: 7,
              username: 'alice',
              firstname: 'Alice',
              lastname: 'Anders',
              email: 'alice@example.com',
              phone: '+1-555-0100',
              mobile: '+1-555-0199',
              addressLine1: '1 Main St',
              addressLine2: 'Apt 2',
              city: 'Springfield',
              postcode: '12345',
              stateRegion: 'IL',
              timezone: 'America/Chicago',
              attributes: {'department': 'engineering'},
            ),
            aci: TomAccessControlInformation(resourceKeys: resourceKeys),
          );

      test(
        'the subject keeps the fields its own keys unlock, on an empty zone',
        () {
          // The login path: the principal is being authenticated right now, so
          // nothing is installed on the zone. Reading the zone here would be
          // fail-closed and blank every protected field in every minted token.
          final (publicInfo, _) =
              TomBearerAuthentication.convertPrincipalToTokenPayload(
                subject(
                  resourceKeys: [
                    'tom.user.firstname',
                    'tom.user.lastname',
                    'tom.user.email',
                    'tom.user.attributes',
                  ],
                ),
                null,
                'US',
                'en',
              );

          expect(publicInfo['firstname'], equals('Alice'));
          expect(publicInfo['lastname'], equals('Anders'));
          expect(publicInfo['email'], equals('alice@example.com'));
          expect(
            publicInfo['attributes'],
            equals({'department': 'engineering'}),
          );
        },
      );

      test('fields the subject holds no key for fall back', () {
        final (publicInfo, _) =
            TomBearerAuthentication.convertPrincipalToTokenPayload(
              subject(resourceKeys: ['tom.user.email']),
              null,
              'US',
              'en',
            );

        expect(publicInfo['email'], equals('alice@example.com'));
        expect(publicInfo['firstname'], isNull);
        expect(publicInfo['phone'], isNull);
        expect(publicInfo['mobile'], isNull);
        expect(publicInfo['addressLine1'], isNull);
        expect(publicInfo['addressLine2'], isNull);
        expect(publicInfo['city'], isNull);
        expect(publicInfo['postcode'], isNull);
        expect(publicInfo['stateRegion'], isNull);
        expect(publicInfo['attributes'], isEmpty);
      });

      test('the three unfiltered fields travel in the clear regardless', () {
        final (publicInfo, _) =
            TomBearerAuthentication.convertPrincipalToTokenPayload(
              subject(),
              null,
              'US',
              'en',
            );

        expect(publicInfo['username'], equals('alice'));
        expect(publicInfo['userId'], equals(7));
        expect(publicInfo['userTimezone'], equals('America/Chicago'));
      });

      test('a principal on the zone does not decide another one\'s token', () {
        // A privileged principal is installed on the zone; the token is minted
        // for someone who holds no keys at all. The zone must not lend its keys
        // to a subject that does not have them.
        final onZone = subject(
          resourceKeys: ['tom.user.firstname', 'tom.user.email'],
        );

        final publicInfo = runZoned(
          () =>
              TomBearerAuthentication.convertPrincipalToTokenPayload(
                subject(),
                null,
                'US',
                'en',
              ).$1,
          zoneValues: {TomPrincipal: onZone},
        );

        expect(publicInfo['firstname'], isNull);
        expect(publicInfo['email'], isNull);
      });

      test('nor does it withhold from a subject that holds the key', () {
        // The mirror case: an unprivileged principal on the zone must not
        // redact fields the subject's own keys unlock.
        final publicInfo = runZoned(
          () =>
              TomBearerAuthentication.convertPrincipalToTokenPayload(
                subject(resourceKeys: ['tom.user.email']),
                null,
                'US',
                'en',
              ).$1,
          zoneValues: {TomPrincipal: subject()},
        );

        expect(publicInfo['email'], equals('alice@example.com'));
      });
    });

    group('convertTokenPayloadToPrincipal malformed tokens', () {
      test('throws a clean StateError when the payload is null', () {
        final token = _FakeClientJwtToken(payload: null);

        expect(
          () => TomBearerAuthentication.convertTokenPayloadToPrincipal(token),
          throwsA(isA<StateError>()),
        );
      });

      test('tolerates a payload missing optional fields', () {
        // Only a username is present; every other field — including the int
        // ids, the attributes map, and the entire secretData — is absent.
        final token = _FakeClientJwtToken(payload: {'username': 'bob'});

        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          token,
        );

        expect(restored.username, equals('bob'));
        expect(restored.authenticated, isTrue);
        expect(restored.organizationId, equals(-1));
        expect(restored.applicationId, equals(-1));
        expect(restored.user.id, equals(-1));
        expect(restored.user.attributes, isEmpty);
        expect(restored.aci.roles, isEmpty);
        expect(restored.aci.groups, isEmpty);
        expect(restored.cli.enabledModules, isEmpty);
        expect(restored.cli.quotas, isEmpty);
      });

      test('tolerates wrong-shaped collection fields', () {
        // attributes is a String instead of a Map; subscription fields are the
        // wrong shape; ACI lists are absent. None of this should crash.
        final token = _FakeClientJwtToken(
          payload: {
            'username': 'carol',
            'attributes': 'not-a-map',
            'subscription_enabledModules': 'not-a-list',
            'subscription_quotas': 'not-a-map',
            'userId': 'not-an-int',
          },
        );

        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          token,
        );

        expect(restored.username, equals('carol'));
        expect(restored.user.attributes, isEmpty);
        expect(restored.user.id, equals(-1));
        expect(restored.cli.enabledModules, isEmpty);
        expect(restored.cli.quotas, isEmpty);
      });

      // Tom's own issuer writes `requires2FA` as a string, but this is the
      // gate that decides `authenticated`, so the reading is deliberately the
      // lenient one ([Tom2FAClaims.isTrue]) rather than exact string equality.
      // The asymmetry is the whole point: reading the JSON boolean too means
      // *more* tokens are held back as "still owes a factor". Reading only the
      // string would let a peer that encoded it the other way authenticate a
      // token that had not finished logging in.
      test('the requires2FA claim is read in either wire encoding', () {
        TomPrincipal restore(Object? claim) =>
            TomBearerAuthentication.convertTokenPayloadToPrincipal(
              _FakeClientJwtToken(
                payload: {'username': 'dave', Tom2FAClaims.requires2FA: claim},
              ),
            );

        // Both encodings mean "a factor is still owed", and both therefore
        // leave the principal unauthenticated.
        for (final claim in <Object?>[true, 'true']) {
          final principal = restore(claim);
          expect(
            principal.requires2FA,
            isTrue,
            reason:
                'claim $claim (${claim.runtimeType}) means a factor is owed',
          );
          expect(principal.authenticated, isFalse);
        }

        // Nothing else does. The near-misses are listed explicitly: leniency
        // covers the two encodings the framework itself produces, and stops
        // there rather than becoming a general truthiness coercion.
        for (final claim in <Object?>[
          false,
          'True',
          'TRUE',
          1,
          'false',
          null,
        ]) {
          final principal = restore(claim);
          expect(
            principal.requires2FA,
            isFalse,
            reason:
                'claim $claim (${claim.runtimeType}) is neither `true` nor "true"',
          );
          expect(principal.authenticated, isTrue);
        }
      });
    });

    group('getPrincipal', () {
      test('throws StateError when no tokens have been set', () {
        expect(
          () => TomBearerAuthentication.getPrincipal(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('setTokens / updatePrincipal', () {
      test('setTokens parses the token and exposes a principal', () {
        final jwt = _makeJwt({
          'username': 'dave',
          'userId': 7,
          'firstname': 'Dave',
        });

        TomBearerAuthentication.setTokens(jwt, jwt, false);

        final principal = TomBearerAuthentication.getPrincipal();
        expect(principal.username, equals('dave'));
        expect(principal.user.id, equals(7));
        expect(TomBearerAuthentication.token, equals(jwt));
        expect(TomBearerAuthentication.authorizationToken, equals(jwt));
      });

      test('updatePrincipal replaces the ACI on the current principal', () {
        final jwt = _makeJwt({'username': 'erin', 'userId': 8});
        TomBearerAuthentication.setTokens(jwt, jwt, false);

        TomBearerAuthentication.updatePrincipal(
          ['team-a'],
          ['lead'],
          ['feature.x'],
          ['key.y'],
          resourceRoles: {'project.apollo': 'owner'},
        );

        final aci = TomBearerAuthentication.getPrincipal().aci;
        expect(aci.groups, equals(['team-a']));
        expect(aci.roles, equals(['lead']));
        expect(aci.entitlements, equals(['feature.x']));
        expect(aci.resourceKeys, equals(['key.y']));
        expect(aci.resourceRoles, equals({'project.apollo': 'owner'}));
      });

      test('updatePrincipal clears resourceRoles when they are omitted', () {
        // The trap the documentation warns about. `resourceRoles` is the only
        // optional parameter, so a caller that leaves it out still compiles —
        // and because the call replaces the ACI rather than merging into it,
        // the principal's per-resource grants are gone. A periodic refresh
        // written that way drops them on every tick.
        final jwt = _makeJwt({'username': 'erin', 'userId': 8});
        TomBearerAuthentication.setTokens(jwt, jwt, false);

        TomBearerAuthentication.updatePrincipal(
          ['team-a'],
          ['lead'],
          ['feature.x'],
          ['key.y'],
          resourceRoles: {'project.apollo': 'owner'},
        );
        expect(
          TomBearerAuthentication.getPrincipal().aci.resourceRoles,
          equals({'project.apollo': 'owner'}),
        );

        // The same call, one argument short.
        TomBearerAuthentication.updatePrincipal(
          ['team-a'],
          ['lead'],
          ['feature.x'],
          ['key.y'],
        );

        expect(
          TomBearerAuthentication.getPrincipal().aci.resourceRoles,
          isEmpty,
        );
      });

      test(
        'clearTokens leaves the singleton with no identity to hand back',
        () {
          final jwt = _makeJwt({'username': 'frank'});
          TomBearerAuthentication.setTokens(jwt, jwt, false);
          expect(
            TomBearerAuthentication.getPrincipal().username,
            equals('frank'),
          );

          TomBearerAuthentication.clearTokens();

          expect(TomBearerAuthentication.token, isNull);
          expect(TomBearerAuthentication.authorizationToken, isNull);
          expect(TomBearerAuthentication.clientJwtToken, isNull);
          expect(TomBearerAuthentication.clientAuthorizationJwtToken, isNull);
          expect(
            () => TomBearerAuthentication.getPrincipal(),
            throwsA(isA<StateError>()),
          );
        },
      );

      test('clientTimezone survives the round trip', () {
        // Written as "clientTimezone" and read back under the same name: the
        // two sides used to disagree on the spelling, which silently dropped
        // the value.
        final principal = createTestPrincipal();
        principal.clientTimezone = 'Europe/Berlin';

        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          principal,
          null,
          'DE',
          'de',
        );
        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          _FakeClientJwtToken(payload: publicInfo, secretData: privateInfo),
        );

        expect(restored.clientTimezone, equals('Europe/Berlin'));
      });
    });

    // The claim contract a pending second factor travels under. It is written
    // by the server when it issues the interim token and read by the client to
    // drive the second-factor UI, so both sides live here, in the kernel.
    group('two-factor claims', () {
      Tom2FAChallenge challenge({
        int attempt = 0,
        int attemptsAllowed = 3,
        Duration validIn = const Duration(minutes: 5),
      }) => Tom2FAChallenge(
        type: 'totp',
        hint: 'device',
        attempt: attempt,
        attemptsAllowed: attemptsAllowed,
        expiresAt: DateTime.now().toUtc().add(validIn),
        clientData: const {'digits': 6},
      );

      test('a challenge round-trips through the public claims', () {
        final original = challenge(attempt: 1);
        final restored = Tom2FAChallenge.fromClaims(
          original.toClaims().cast<String, dynamic>(),
        );

        expect(restored, isNotNull);
        expect(restored!.type, equals('totp'));
        expect(restored.hint, equals('device'));
        expect(restored.attempt, equals(1));
        expect(restored.attemptsAllowed, equals(3));
        expect(restored.clientData['digits'], equals(6));
        expect(
          restored.expiresAt.millisecondsSinceEpoch,
          equals(original.expiresAt.millisecondsSinceEpoch),
        );
      });

      test('toClaims always declares the token still owes a factor', () {
        expect(
          challenge().toClaims()[Tom2FAClaims.requires2FA],
          equals('true'),
        );
      });

      test('attempts count down to exhaustion and never go negative', () {
        var c = challenge(attemptsAllowed: 2);
        expect(c.attemptsRemaining, equals(2));
        expect(c.isExhausted, isFalse);

        c = c.withConsumedAttempt();
        expect(c.attempt, equals(1));
        expect(c.attemptsRemaining, equals(1));

        c = c.withConsumedAttempt();
        expect(c.isExhausted, isTrue);
        expect(c.withConsumedAttempt().attemptsRemaining, equals(0));
      });

      test('withConsumedAttempt leaves the original untouched', () {
        final original = challenge();
        original.withConsumedAttempt();
        expect(original.attempt, equals(0));
      });

      test('expiry is evaluated against the given instant', () {
        final c = challenge();
        expect(c.isExpired(), isFalse);
        expect(
          c.isExpired(DateTime.now().toUtc().add(const Duration(minutes: 6))),
          isTrue,
        );
      });

      // `now` is caller-supplied and may well be local. Expiry is a question
      // about instants, not about wall clocks, so the answer must not depend
      // on which zone the caller's clock is labelled with.
      test('expiry is evaluated against a local instant identically', () {
        final c = challenge();
        expect(c.isExpired(DateTime.now()), isFalse);
        expect(
          c.isExpired(DateTime.now().add(const Duration(minutes: 6))),
          isTrue,
        );
      });

      // The field's dartdoc promises a UTC instant, so an application that
      // renders a countdown from `challenge.expiresAt` may read it without
      // re-normalising. Only the constructor can keep that promise: every
      // path but `fromClaims` reaches the field directly.
      test('a locally-built expiry is normalised to UTC', () {
        final local = DateTime.now().add(const Duration(minutes: 5));
        expect(local.isUtc, isFalse, reason: 'precondition for this test');

        final c = Tom2FAChallenge(type: 'totp', expiresAt: local);

        expect(c.expiresAt.isUtc, isTrue);
        expect(
          c.expiresAt.millisecondsSinceEpoch,
          equals(local.millisecondsSinceEpoch),
          reason: 'normalising must re-label the instant, not shift it',
        );
      });

      // Same challenge, two machines, two zones: one string.
      test('toString prints the expiry in UTC', () {
        final local = DateTime.now().add(const Duration(minutes: 5));
        final c = Tom2FAChallenge(type: 'totp', expiresAt: local);

        expect(c.toString(), contains(local.toUtc().toIso8601String()));
      });

      // A token is an outside input, so a payload that claims a challenge but
      // cannot describe one must read as "no challenge" rather than as a
      // half-built one whose gaps an attacker gets to choose.
      test('fromClaims rejects payloads it cannot trust', () {
        expect(Tom2FAChallenge.fromClaims(null), isNull);
        expect(Tom2FAChallenge.fromClaims(<String, dynamic>{}), isNull);
        expect(
          Tom2FAChallenge.fromClaims({Tom2FAClaims.requires2FA: 'false'}),
          isNull,
        );
        expect(
          Tom2FAChallenge.fromClaims({
            Tom2FAClaims.requires2FA: 'true',
            Tom2FAClaims.type: '',
            Tom2FAClaims.expiresAt: DateTime.now().toIso8601String(),
          }),
          isNull,
          reason: 'requires a factor but names no mechanism',
        );
        expect(
          Tom2FAChallenge.fromClaims({
            Tom2FAClaims.requires2FA: 'true',
            Tom2FAClaims.type: 'totp',
            Tom2FAClaims.expiresAt: 'not-a-date',
          }),
          isNull,
          reason: 'names a mechanism but carries an unparseable expiry',
        );
      });

      // The gate that decides whether a challenge is built at all. Reading
      // only the string would hand the client a token that says it owes a
      // factor and no challenge to answer it with — stranded mid-login.
      test('the requires2FA gate is read in either wire encoding', () {
        Tom2FAChallenge? decode(Object? raw) => Tom2FAChallenge.fromClaims({
          Tom2FAClaims.requires2FA: raw,
          Tom2FAClaims.type: 'totp',
          Tom2FAClaims.expiresAt: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        });

        expect(decode(true), isNotNull);
        expect(decode('true'), isNotNull);

        // Leniency covers the two encodings the framework produces and stops
        // there — it is not a general truthiness coercion.
        for (final raw in <Object?>[false, 'True', 1, 'yes', null]) {
          expect(
            decode(raw),
            isNull,
            reason: '$raw (${raw.runtimeType}) is neither `true` nor "true"',
          );
        }
      });

      // The one claim whose fallback deliberately disagrees with the
      // constructor's default. `hint` and `attempt` fall back to what the
      // constructor would have chosen anyway; `attemptsAllowed` falls back to
      // 0 rather than 3, so a token that cannot state its budget is born
      // exhausted instead of being handed three free guesses. Pinned here
      // because the rule is otherwise only prose, and prose is what drifted.
      test('an unreadable attempt budget yields an exhausted challenge, not '
          'a fresh one', () {
        final withoutBudget = Tom2FAChallenge.fromClaims({
          Tom2FAClaims.requires2FA: 'true',
          Tom2FAClaims.type: 'totp',
          Tom2FAClaims.expiresAt: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        });

        expect(
          withoutBudget,
          isNotNull,
          reason: 'the challenge is still readable — only its budget is not',
        );
        expect(withoutBudget!.attemptsAllowed, isZero);
        expect(withoutBudget.attemptsRemaining, isZero);
        expect(withoutBudget.isExhausted, isTrue);

        // A wrong-shaped budget is no more trustworthy than a missing one.
        final wrongShape = Tom2FAChallenge.fromClaims({
          Tom2FAClaims.requires2FA: 'true',
          Tom2FAClaims.type: 'totp',
          Tom2FAClaims.attemptsAllowed: '99',
          Tom2FAClaims.expiresAt: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        });

        expect(wrongShape!.isExhausted, isTrue);
      });

      test('a challenge is projected into the token payload', () {
        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          createTestPrincipal(requires2FA: true, twoFactorType: 'totp'),
          null,
          'US',
          'en',
          challenge: challenge(),
          twoFactorVerification: const {'nonce': 'n-1'},
        );

        expect(publicInfo[Tom2FAClaims.requires2FA], equals('true'));
        expect(publicInfo[Tom2FAClaims.type], equals('totp'));
        expect(publicInfo[Tom2FAClaims.hint], equals('device'));
        expect(publicInfo[Tom2FAClaims.attemptsAllowed], equals(3));
        // The verification blob is server-only: encrypted section, never public.
        expect(
          privateInfo[Tom2FAClaims.verificationData],
          equals({'nonce': 'n-1'}),
        );
        expect(publicInfo, isNot(contains(Tom2FAClaims.verificationData)));
      });

      // The safety property the whole interim-token design rests on: the token
      // carries the real ACI, so what must stop it from authorizing anything is
      // the single `authenticated` flag every access check consults.
      test('a principal owing a factor is not authenticated', () {
        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          createTestPrincipal(
            username: 'alice',
            roles: ['admin'],
            requires2FA: true,
            twoFactorType: 'totp',
          ),
          null,
          'US',
          'en',
          challenge: challenge(),
        );

        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          _FakeClientJwtToken(payload: publicInfo, secretData: privateInfo),
        );

        expect(restored.username, equals('alice'));
        expect(restored.aci.roles, contains('admin'));
        expect(restored.requires2FA, isTrue);
        expect(restored.twoFactorType, equals('totp'));
        expect(restored.authenticated, isFalse);
      });

      test('reporting the factor satisfied clears the claims and the blob', () {
        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          createTestPrincipal(requires2FA: true, twoFactorType: 'totp'),
          null,
          'US',
          'en',
          twoFactorVerification: const {'nonce': 'n-1'},
          twoFactorSatisfied: true,
        );

        expect(publicInfo[Tom2FAClaims.requires2FA], equals('false'));
        expect(publicInfo[Tom2FAClaims.type], isNull);
        expect(Tom2FAChallenge.fromClaims(publicInfo.cast()), isNull);
        // Without a challenge in flight there is nothing to verify, so the blob
        // is dropped and a mechanism secret cannot outlive its challenge.
        expect(privateInfo, isNot(contains(Tom2FAClaims.verificationData)));

        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          _FakeClientJwtToken(payload: publicInfo, secretData: privateInfo),
        );
        expect(restored.authenticated, isTrue);
        expect(restored.requires2FA, isFalse);
      });

      // The two flags disagree, and the challenge wins. `twoFactorSatisfied` is
      // read only on the branch that has no challenge, so a caller passing both
      // gets an interim token — the fail-safe direction. Asserted because the
      // combination is the one a reader is most likely to guess wrong about:
      // "satisfied" sounds final, but issuing a challenge says the opposite.
      test('a challenge outranks twoFactorSatisfied', () {
        final (
          publicInfo,
          privateInfo,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          createTestPrincipal(requires2FA: true, twoFactorType: 'totp'),
          null,
          'US',
          'en',
          challenge: challenge(),
          twoFactorVerification: const {'nonce': 'n-1'},
          twoFactorSatisfied: true,
        );

        expect(publicInfo[Tom2FAClaims.requires2FA], equals('true'));
        expect(Tom2FAChallenge.fromClaims(publicInfo.cast()), isNotNull);
        // A challenge is in flight, so the blob it was minted for rides along.
        expect(
          privateInfo[Tom2FAClaims.verificationData],
          equals({'nonce': 'n-1'}),
        );

        final restored = TomBearerAuthentication.convertTokenPayloadToPrincipal(
          _FakeClientJwtToken(payload: publicInfo, secretData: privateInfo),
        );
        expect(restored.authenticated, isFalse);
      });

      // Fail-safe by construction: omitting `twoFactorSatisfied` produces an
      // unusable interim token, never an over-privileged one.
      test('forgetting to report satisfaction keeps the factor owed', () {
        final (
          publicInfo,
          _,
        ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
          createTestPrincipal(requires2FA: true, twoFactorType: 'totp'),
          null,
          'US',
          'en',
        );

        expect(publicInfo[Tom2FAClaims.requires2FA], equals('true'));
        expect(publicInfo[Tom2FAClaims.type], equals('totp'));
      });

      test('pendingTwoFactorChallenge reads the stored interim token', () {
        expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);

        final interim = _makeJwt(
          challenge().toClaims().cast<String, dynamic>()
            ..['username'] = 'alice',
        );
        TomBearerAuthentication.setTokens(interim, interim, false);

        final pending = TomBearerAuthentication.pendingTwoFactorChallenge;
        expect(pending, isNotNull);
        expect(pending!.type, equals('totp'));
        expect(pending.attemptsRemaining, equals(3));
      });

      test('a completed session has no pending challenge', () {
        final jwt = _makeJwt({
          'username': 'alice',
          Tom2FAClaims.requires2FA: 'false',
        });
        TomBearerAuthentication.setTokens(jwt, jwt, false);

        expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);
      });

      // A client that slept, or sat in a background tab, wakes holding an
      // interim token whose challenge has lapsed. Answering it is pointless —
      // the server will refuse — so the getter reports "nothing pending" and
      // the client restarts at pass 1 rather than looping on a dead challenge.
      test('a lapsed challenge is not pending', () {
        final interim = _makeJwt(
          challenge(
            validIn: const Duration(minutes: -1),
          ).toClaims().cast<String, dynamic>()..['username'] = 'alice',
        );
        TomBearerAuthentication.setTokens(interim, interim, false);

        expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);
      });

      test('a burned challenge is not pending', () {
        final interim = _makeJwt(
          challenge(
            attempt: 3,
            attemptsAllowed: 3,
          ).toClaims().cast<String, dynamic>()..['username'] = 'alice',
        );
        TomBearerAuthentication.setTokens(interim, interim, false);

        expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);
      });

      // The freshness filter belongs to the getter, not to the decoder. The
      // server holds the authoritative clock and tests need to build a lapsed
      // challenge to assert against, so `fromClaims` stays a pure wire reader
      // and only the client-facing read applies `DateTime.now()`.
      test('fromClaims still decodes what the getter filters out', () {
        final lapsed = challenge(validIn: const Duration(minutes: -1));
        final burned = challenge(attempt: 3, attemptsAllowed: 3);

        expect(
          Tom2FAChallenge.fromClaims(lapsed.toClaims().cast<String, dynamic>()),
          isNotNull,
        );
        expect(
          Tom2FAChallenge.fromClaims(burned.toClaims().cast<String, dynamic>()),
          isNotNull,
        );
      });
    });

    // The client-visible half of a pending *enrolment* — the step before a
    // challenge exists at all. Read from the same interim token and, like the
    // challenge, defensively: it arrived from outside the process.
    group('two-factor enrolment claims', () {
      // Mirrors Tom2FAEnrolmentState.toClaims exactly: JSON booleans for the
      // two flags, and the mechanism-specific claims (including the expiry)
      // present only once a mechanism has been chosen.
      Map<String, dynamic> claims({
        String type = '',
        List<String> offeredTypes = const ['totp', 'sms'],
        bool skippable = true,
        bool skipSpendsGrace = false,
        Map<String, Object?> clientData = const {},
        Duration validIn = const Duration(minutes: 10),
      }) {
        final base = <String, dynamic>{
          Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
          Tom2FAEnrolmentClaims.offeredTypes: offeredTypes,
          Tom2FAEnrolmentClaims.skippable: skippable,
          Tom2FAEnrolmentClaims.skipSpendsGrace: skipSpendsGrace,
        };
        if (type.isEmpty) return base;
        return base..addAll({
          Tom2FAEnrolmentClaims.type: type,
          Tom2FAEnrolmentClaims.hint: '',
          Tom2FAEnrolmentClaims.attempt: 0,
          Tom2FAEnrolmentClaims.attemptsAllowed: 3,
          Tom2FAEnrolmentClaims.expiresAt: DateTime.now()
              .toUtc()
              .add(validIn)
              .toIso8601String(),
          Tom2FAEnrolmentClaims.clientData: clientData,
        });
      }

      test('the choosing stop carries the offer but no mechanism', () {
        final pending = Tom2FAPendingEnrolment.fromClaims(claims());

        expect(pending, isNotNull);
        expect(
          pending!.hasOffer,
          isFalse,
          reason: 'no mechanism picked yet, so the client renders a chooser',
        );
        expect(pending.offeredTypes, equals(['totp', 'sms']));
        expect(pending.skippable, isTrue);
        expect(pending.skipSpendsGrace, isFalse);
        // Nothing has been generated yet, so nothing can go stale.
        expect(pending.expiresAt, isNull);
        expect(pending.isExpired(), isFalse);
      });

      test('the confirming stop carries the mechanism and its client data', () {
        final pending = Tom2FAPendingEnrolment.fromClaims(
          claims(
            type: 'totp',
            clientData: const {
              'secret': 'GEZDGNBVGY3TQOJQ',
              'otpauthUri': 'otpauth://totp/App:alice?secret=GEZDGNBVGY3TQOJQ',
              'digits': 6,
            },
          ),
        );

        expect(pending, isNotNull);
        expect(pending!.hasOffer, isTrue);
        expect(pending.type, equals('totp'));
        expect(pending.clientData['digits'], equals(6));
        expect(pending.clientData['otpauthUri'], startsWith('otpauth://'));
        expect(pending.attemptsRemaining, equals(3));
        expect(pending.isExpired(), isFalse);
      });

      test('skipSpendsGrace distinguishes a charged skip from a free one', () {
        final free = Tom2FAPendingEnrolment.fromClaims(claims());
        final charged = Tom2FAPendingEnrolment.fromClaims(
          claims(skipSpendsGrace: true),
        );

        expect(free!.skipSpendsGrace, isFalse);
        expect(charged!.skipSpendsGrace, isTrue);
      });

      // The same promise the challenge's expiry makes, asserted separately so
      // the pair cannot drift apart.
      test('a locally-built expiry is normalised to UTC', () {
        final local = DateTime.now().add(const Duration(minutes: 5));
        expect(local.isUtc, isFalse, reason: 'precondition for this test');

        final pending = Tom2FAPendingEnrolment(type: 'totp', expiresAt: local);

        expect(pending.expiresAt!.isUtc, isTrue);
        expect(
          pending.expiresAt!.millisecondsSinceEpoch,
          equals(local.millisecondsSinceEpoch),
          reason: 'normalising must re-label the instant, not shift it',
        );
      });

      // Normalising must not invent a deadline. The choosing stop has none by
      // design — nothing has been generated that could go stale — and an
      // offer that acquired one here would lapse a chooser the user is still
      // reading.
      test('the choosing stop keeps its absent expiry absent', () {
        final choosing = Tom2FAPendingEnrolment(
          offeredTypes: const ['totp', 'sms'],
        );

        expect(choosing.expiresAt, isNull);
        expect(choosing.isExpired(), isFalse);
      });

      // The mirror of the above, and the reason a null deadline cannot simply
      // mean "no limit": on a begun offer the deadline is the only thing that
      // stops generated material being confirmable forever. fromClaims already
      // refuses such a payload, so this is the backstop for a hand-built value
      // -- and it must answer as the server does, or the panel would offer a
      // confirmation the server has already decided to refuse.
      test('a begun offer with no expiry counts as lapsed', () {
        final begun = Tom2FAPendingEnrolment(
          offeredTypes: const ['totp'],
          type: 'totp',
        );

        expect(begun.hasOffer, isTrue);
        expect(begun.expiresAt, isNull);
        expect(begun.isExpired(), isTrue);
        expect(
          begun.isExpired(DateTime.utc(1970)),
          isTrue,
          reason: 'no instant is inside a window that was never opened',
        );
      });

      test('toString prints the expiry in UTC', () {
        final local = DateTime.now().add(const Duration(minutes: 5));
        final pending = Tom2FAPendingEnrolment(type: 'totp', expiresAt: local);

        expect(pending.toString(), contains(local.toUtc().toIso8601String()));
      });

      // Same fail-safe reading as the challenge: a payload that announces an
      // enrolment but describes nothing renderable is "no enrolment", not a
      // half-built one whose gaps an attacker chooses.
      test('fromClaims rejects payloads it cannot trust', () {
        expect(Tom2FAPendingEnrolment.fromClaims(null), isNull);
        expect(Tom2FAPendingEnrolment.fromClaims(<String, dynamic>{}), isNull);
        expect(
          Tom2FAPendingEnrolment.fromClaims(
            claims()..[Tom2FAEnrolmentClaims.pendingEnrolment] = 'false',
          ),
          isNull,
        );
        expect(
          Tom2FAPendingEnrolment.fromClaims(
            claims(type: 'totp')
              ..[Tom2FAEnrolmentClaims.expiresAt] = 'not-a-date',
          ),
          isNull,
          reason:
              'a begun offer with no readable expiry could be confirmed '
              'forever, and its panel could not say when it lapses',
        );
        expect(
          Tom2FAPendingEnrolment.fromClaims(claims(offeredTypes: const [])),
          isNull,
          reason: 'neither a mechanism in flight nor a list to choose from',
        );
      });

      // The same fail-closed budget as the challenge, asserted separately so
      // the pair cannot drift apart: whichever of the two someone edits, the
      // other's test still states the rule.
      test('an unreadable attempt budget yields an exhausted offer, not a '
          'fresh one', () {
        final begun = claims(type: 'totp');
        begun.remove(Tom2FAEnrolmentClaims.attemptsAllowed);

        final pending = Tom2FAPendingEnrolment.fromClaims(begun);

        expect(
          pending,
          isNotNull,
          reason: 'the offer is still renderable — only its budget is not',
        );
        expect(pending!.attemptsAllowed, isZero);
        expect(pending.isExhausted, isTrue);
      });

      // The two flags cross the wire as JSON booleans today, but the sibling
      // requires2FA claim is a string; a client that read only one encoding
      // would silently drop the skip button against the other tier's version.
      test('the boolean flags are read in either wire encoding', () {
        final asStrings = claims()
          ..[Tom2FAEnrolmentClaims.skippable] = 'true'
          ..[Tom2FAEnrolmentClaims.skipSpendsGrace] = 'true';

        final pending = Tom2FAPendingEnrolment.fromClaims(asStrings);
        expect(pending!.skippable, isTrue);
        expect(pending.skipSpendsGrace, isTrue);
      });

      // The gate that decides whether an enrolment is built at all reads the
      // same two encodings as the flags inside it. Reading only the string
      // would strand a client holding a token that says it owes an enrolment
      // while exposing nothing to render — the exact failure the lenient rule
      // exists to prevent, one level further out.
      test('the pendingEnrolment gate is read in either wire encoding', () {
        final asBool = claims()
          ..[Tom2FAEnrolmentClaims.pendingEnrolment] = true;

        expect(Tom2FAPendingEnrolment.fromClaims(asBool), isNotNull);

        // Leniency stops at the two encodings; it is not truthiness.
        for (final raw in <Object?>['True', 1, 'yes']) {
          expect(
            Tom2FAPendingEnrolment.fromClaims(
              claims()..[Tom2FAEnrolmentClaims.pendingEnrolment] = raw,
            ),
            isNull,
            reason: '$raw (${raw.runtimeType}) is neither `true` nor "true"',
          );
        }
      });

      test('a completed session has no pending enrolment', () {
        final jwt = _makeJwt({
          'username': 'alice',
          Tom2FAClaims.requires2FA: 'false',
        });
        TomBearerAuthentication.setTokens(jwt, jwt, false);

        expect(TomBearerAuthentication.pendingTwoFactorEnrolment, isNull);
      });

      test('pendingTwoFactorEnrolment reads the stored interim token', () {
        final interim = _makeJwt(claims(type: 'totp')..['username'] = 'alice');
        TomBearerAuthentication.setTokens(interim, interim, false);

        final pending = TomBearerAuthentication.pendingTwoFactorEnrolment;
        expect(pending, isNotNull);
        expect(pending!.type, equals('totp'));
        expect(pending.skippable, isTrue);
      });

      // The same freshness filter as the challenge, and it matters more here:
      // the documented client loop re-reads this getter until it answers null,
      // so a lapsed offer that kept reporting itself would spin forever.
      test('a lapsed offer is not pending', () {
        final interim = _makeJwt(
          claims(type: 'totp', validIn: const Duration(minutes: -1))
            ..['username'] = 'alice',
        );
        TomBearerAuthentication.setTokens(interim, interim, false);

        expect(TomBearerAuthentication.pendingTwoFactorEnrolment, isNull);
      });

      test('a burned offer is not pending', () {
        final interim = _makeJwt(
          claims(type: 'totp')
            ..[Tom2FAEnrolmentClaims.attempt] = 3
            ..['username'] = 'alice',
        );
        TomBearerAuthentication.setTokens(interim, interim, false);

        expect(TomBearerAuthentication.pendingTwoFactorEnrolment, isNull);
      });

      // The trap in filtering this getter on exhaustion. The attempt budget
      // belongs to the *mechanism's* offer, so the choosing stop carries no
      // such claim — and an absent budget reads back as 0, i.e. `isExhausted`.
      // Filtering on exhaustion unconditionally would therefore delete the
      // chooser, which owes no attempts because nothing has been generated to
      // attempt yet. Exactly the reading `expiresAt` already gets.
      test('the choosing stop survives the freshness filter', () {
        final interim = _makeJwt(claims()..['username'] = 'alice');
        TomBearerAuthentication.setTokens(interim, interim, false);

        final pending = TomBearerAuthentication.pendingTwoFactorEnrolment;
        expect(pending, isNotNull);
        expect(pending!.hasOffer, isFalse);
        expect(
          pending.isExhausted,
          isTrue,
          reason: 'no budget claim at this stop — the filter must not read it',
        );
      });
    });
  });

  // The one-time-password primitives every tier shares. Anchored on the RFC's
  // own published vectors rather than on values this implementation produced:
  // a self-consistent HOTP is worthless — the whole point is agreeing with an
  // off-the-shelf authenticator app that was never compiled against this code.
  group('TomTotp', () {
    /// The RFC 4226 / RFC 6238 reference secret, as its ASCII bytes.
    final rfcKey = '12345678901234567890'.codeUnits;

    /// The same reference secret in the base32 form an authenticator is
    /// provisioned with.
    const rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('reproduces the RFC 4226 HOTP vectors', () {
      const expected = [
        '755224',
        '287082',
        '359152',
        '969429',
        '338314',
        '254676',
        '287922',
        '162583',
        '399871',
        '520489',
      ];
      for (var counter = 0; counter < expected.length; counter++) {
        expect(
          TomTotp.generateCode(rfcKey, counter, 6),
          expected[counter],
          reason: 'HOTP counter $counter',
        );
      }
    });

    test('reproduces the RFC 6238 TOTP vectors (SHA-1)', () {
      // T = 59 s / 30 s = counter 1; T = 1111111109 s → counter 37037036.
      expect(TomTotp.generateCode(rfcKey, 1, 8), '94287082');
      expect(TomTotp.generateCode(rfcKey, 37037036, 8), '07081804');
    });

    test('pads a short code to the requested width', () {
      final code = TomTotp.generateCode(rfcKey, 37037036, 6);
      expect(code, '081804');
      expect(code.length, 6);
    });

    test('defaults to the RFC digit width', () {
      expect(TomTotp.generateCode(rfcKey, 0), equals('755224'));
      expect(TomTotp.defaultDigits, equals(6));
    });

    // The counter is where two sides of a TOTP exchange most easily disagree,
    // so pin it against the RFC's own worked instants rather than trusting the
    // arithmetic to be obvious.
    test('counts UTC seconds into RFC 6238 time steps', () {
      expect(
        TomTotp.counterFor(at: DateTime.utc(1970, 1, 1, 0, 0, 59)),
        equals(1),
      );
      expect(
        TomTotp.counterFor(
          at: DateTime.fromMillisecondsSinceEpoch(
            1111111109 * 1000,
            isUtc: true,
          ),
        ),
        equals(37037036),
      );
    });

    test('counting is indifferent to the zone the instant is expressed in', () {
      final utc = DateTime.utc(2026, 7, 28, 12, 0, 0);
      expect(
        TomTotp.counterFor(at: utc.toLocal()),
        equals(TomTotp.counterFor(at: utc)),
      );
    });

    test('rejects a period that would divide by zero', () {
      expect(
        () => TomTotp.counterFor(period: Duration.zero),
        throwsA(isA<ArgumentError>()),
      );
      // The bound is one whole second, not "positive": the step is
      // `period.inSeconds`, which truncates, so a sub-second period is a
      // positive duration that would still divide by zero.
      expect(
        () => TomTotp.counterFor(period: const Duration(milliseconds: 500)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TomTotp.counterFor(period: const Duration(seconds: -30)),
        throwsA(isA<ArgumentError>()),
      );
      // One second is accepted — the boundary is inclusive.
      expect(
        TomTotp.counterFor(
          at: DateTime.utc(1970, 1, 1, 0, 0, 42),
          period: const Duration(seconds: 1),
        ),
        equals(42),
      );
    });

    test('codeFor derives the code for an instant from the base32 secret', () {
      final at = DateTime.fromMillisecondsSinceEpoch(
        1111111109 * 1000,
        isUtc: true,
      );
      expect(
        TomTotp.codeFor(rfcSecretBase32, at: at, digits: 8),
        equals('07081804'),
      );
    });

    test('codeFor reports an unusable secret as no code at all', () {
      expect(TomTotp.codeFor('not-base32!'), isEmpty);
    });

    test('base32 round-trips the reference secret', () {
      expect(TomTotp.decodeBase32(rfcSecretBase32), rfcKey);
      expect(TomTotp.encodeBase32(rfcKey), rfcSecretBase32);
    });

    test('base32 tolerates the shapes secrets are shown to users in', () {
      expect(
        TomTotp.decodeBase32('gezd gnbv gy3t qojq-gezdgnbvgy3tqojq='),
        rfcKey,
      );
    });

    test('base32 reports an unusable secret as empty rather than guessing', () {
      expect(TomTotp.decodeBase32('not-base32!'), isEmpty);
    });
  });

  // ==========================================================================
  // Tom2FAMethodDescriptor Tests
  // ==========================================================================

  // The descriptor is how a login offers the user a choice of second factor,
  // and it is deliberately three resource keys rather than three strings. What
  // makes that work is `scoped`, which derives all three from the method's
  // identifier — so the keys are the contract between this payload and every
  // resource bundle the deployment ships.
  group('Tom2FAMethodDescriptor', () {
    setUpAll(initializeReflection);

    test('scoped derives all three keys under the one scope', () {
      // The table in `doc/security/security.md`, asserted rather than
      // described. A client resolves these keys verbatim, so any drift in the
      // derivation is a blank label in every locale at once.
      final descriptor = Tom2FAMethodDescriptor.scoped('totp');

      expect(descriptor.type, 'totp');
      expect(descriptor.displayNameKey, 'two_factor.totp.name');
      expect(descriptor.descriptionKey, 'two_factor.totp.description');
      expect(descriptor.iconKey, 'two_factor.totp.icon');
    });

    test('the scope is one constant both halves name', () {
      // The server's resource bundle is keyed under this prefix, so a rename
      // has to move the bundle with it — the constant is what makes that one
      // edit rather than three string literals.
      expect(Tom2FAMethodDescriptor.resourceScope, 'two_factor');
      expect(
        Tom2FAMethodDescriptor.scoped('webauthn').displayNameKey,
        '${Tom2FAMethodDescriptor.resourceScope}.webauthn.name',
      );
    });

    test('a scoped descriptor carries no literal text', () {
      // The rule the class documents: identifiers only. A descriptor holding
      // 'Authenticator app' would freeze one locale's English into the wire
      // format, and would do it silently — nothing else in the stack would
      // object.
      final descriptor = Tom2FAMethodDescriptor.scoped('sms');

      for (final key in [
        descriptor.displayNameKey,
        descriptor.descriptionKey,
        descriptor.iconKey,
      ]) {
        expect(key, startsWith('two_factor.sms.'));
        expect(key, isNot(contains(' ')));
      }
    });

    test('every field defaults, because reflection fills a blank one', () {
      // It travels inside `TomAuthenticationResult`, so the reflection path
      // instantiates it with no arguments and then writes member by member: a
      // required field would make it unconstructible on the way in.
      final blank = Tom2FAMethodDescriptor();

      expect(blank.type, isEmpty);
      expect(blank.displayNameKey, isEmpty);
      expect(blank.descriptionKey, isEmpty);
      expect(blank.iconKey, isEmpty);
    });

    test('it names the method and the key it resolves to', () {
      expect(
        Tom2FAMethodDescriptor.scoped('totp').toString(),
        'Tom2FAMethodDescriptor(totp -> two_factor.totp.name)',
      );
    });

    test('the derived keys survive the wire', () {
      // Deriving them correctly is only half of it — they are derived on the
      // server and read on the client, so the round-trip is where a renamed
      // field would actually show up.
      final restored = _wireRoundTrip(Tom2FAMethodDescriptor.scoped('totp'));

      expect(restored.type, 'totp');
      expect(restored.displayNameKey, 'two_factor.totp.name');
      expect(restored.descriptionKey, 'two_factor.totp.description');
      expect(restored.iconKey, 'two_factor.totp.icon');
    });
  });

  // ==========================================================================
  // OAuth Contract Tests
  // ==========================================================================

  // These four are the whole of what crosses the wire in an external-identity
  // login. They are plain reflected DTOs with no behaviour, which is exactly
  // why they are worth asserting: a renamed field still compiles on both
  // halves and fails only at run time, on the one code path a deployment
  // cannot exercise without a real provider.
  group('TomOAuth wire DTOs', () {
    setUpAll(initializeReflection);

    test('the provider descriptor survives the wire', () {
      final restored = _wireRoundTrip(
        TomOAuthProviderDto(
          id: 'google',
          displayNameKey: 'oauth.google.name',
          iconKey: 'oauth.google.icon',
        ),
      );

      expect(restored.id, 'google');
      expect(restored.displayNameKey, 'oauth.google.name');
      expect(restored.iconKey, 'oauth.google.icon');
    });

    test('the authorization request survives the wire', () {
      // Eight fields, five of which are the client context the issued token
      // ends up carrying — the ones whose loss would be invisible until a
      // principal came back with the wrong locale.
      final restored = _wireRoundTrip(
        TomOAuthAuthorizationRequest(
          providerId: 'github',
          client: 'web',
          application: 'portal',
          process: 'checkout',
          organization: 'acme-corp',
          clientLanguage: 'de',
          clientCountry: 'DE',
          clientTimezone: 'Europe/Berlin',
        ),
      );

      expect(restored.providerId, 'github');
      expect(restored.client, 'web');
      expect(restored.application, 'portal');
      expect(restored.process, 'checkout');
      expect(restored.organization, 'acme-corp');
      expect(restored.clientLanguage, 'de');
      expect(restored.clientCountry, 'DE');
      expect(restored.clientTimezone, 'Europe/Berlin');
    });

    test('the authorization answer survives the wire', () {
      final restored = _wireRoundTrip(
        TomOAuthAuthorizationDto(
          authorizationUri:
              'https://accounts.example.com/authorize?client_id=x&state=s-1',
          state: 's-1',
        ),
      );

      expect(
        restored.authorizationUri,
        'https://accounts.example.com/authorize?client_id=x&state=s-1',
      );
      expect(restored.state, 's-1');
    });

    test('the callback request survives the wire, error fields included', () {
      // The failure half is the half a provider actually exercises first, and
      // it is the only DTO in the set whose Dart field name differs from its
      // URL spelling — see the mapping assertions below.
      final restored = _wireRoundTrip(
        TomOAuthCallbackRequest(
          code: '',
          state: 's-1',
          error: 'access_denied',
          errorDescription: 'The user declined the request',
        ),
      );

      expect(restored.code, isEmpty);
      expect(restored.state, 's-1');
      expect(restored.error, 'access_denied');
      expect(restored.errorDescription, 'The user declined the request');
    });

    test('every field defaults, because reflection fills a blank one', () {
      // Same reason as every other wire DTO: the pipeline constructs it empty
      // and writes member by member.
      expect(TomOAuthProviderDto().id, isEmpty);
      expect(TomOAuthProviderDto().displayNameKey, isEmpty);
      expect(TomOAuthProviderDto().iconKey, isEmpty);
      expect(TomOAuthAuthorizationRequest().providerId, isEmpty);
      expect(TomOAuthAuthorizationRequest().clientTimezone, isEmpty);
      expect(TomOAuthAuthorizationDto().authorizationUri, isEmpty);
      expect(TomOAuthAuthorizationDto().state, isEmpty);
      expect(TomOAuthCallbackRequest().code, isEmpty);
      expect(TomOAuthCallbackRequest().error, isEmpty);
    });

    test('scoped derives both provider keys under the oauth scope', () {
      // Two keys, not three: a provider offers no description line, where a
      // second factor does. The scope constant is shared with the server's
      // `oauth.providers` configuration.
      final provider = TomOAuthProviderDto.scoped('acme-sso');

      expect(TomOAuthProviderDto.resourceScope, 'oauth');
      expect(provider.id, 'acme-sso');
      expect(provider.displayNameKey, 'oauth.acme-sso.name');
      expect(provider.iconKey, 'oauth.acme-sso.icon');
    });

    test('each DTO names the one field a log needs', () {
      // What identifies the row in a log line beside a failure: the provider
      // for the first two, and the `state` handle — which is what correlates
      // the two halves of one flow — for the last two.
      expect(
        TomOAuthProviderDto.scoped('google').toString(),
        'TomOAuthProviderDto(google)',
      );
      expect(
        TomOAuthAuthorizationRequest(providerId: 'github').toString(),
        'TomOAuthAuthorizationRequest(github)',
      );
      expect(
        TomOAuthAuthorizationDto(state: 's-1').toString(),
        'TomOAuthAuthorizationDto(s-1)',
      );
      expect(
        TomOAuthCallbackRequest(
          state: 's-1',
          error: 'access_denied',
        ).toString(),
        'TomOAuthCallbackRequest(s-1, error: access_denied)',
      );
    });
  });

  group('tomOAuthApi — the contract both halves bind to', () {
    test('the API is mounted at /oauth under its own id', () {
      expect(tomOAuthApi.id, tomOAuthApiId);
      expect(tomOAuthApiId, 'tomOAuth');
      expect(tomOAuthApi.uri, '/oauth');
    });

    test('it declares exactly the three endpoints its ids name', () {
      expect(
        tomOAuthApi.endpoints.keys,
        unorderedEquals(<String>[
          tomOAuthProvidersEndpointId,
          tomOAuthBeginEndpointId,
          tomOAuthCompleteEndpointId,
        ]),
      );
    });

    test('the endpoint ids are the literal text the server restates', () {
      // The server's `@TomApiEndpointImplementation(endpointId: …)` names these
      // as strings. Renaming a constant compiles on both sides and leaves the
      // handler bound to nothing.
      expect(tomOAuthProvidersEndpointId, 'listOAuthProviders');
      expect(tomOAuthBeginEndpointId, 'beginOAuthAuthorization');
      expect(tomOAuthCompleteEndpointId, 'completeOAuthAuthorization');
    });

    test('each endpoint states its method and its address', () {
      // The callback is a `GET` because a provider redirects a *browser* to
      // it; the other two are the client's own calls.
      expect(
        tomOAuthApi[tomOAuthProvidersEndpointId].method,
        TomHttpMethod.get,
      );
      expect(tomOAuthApi[tomOAuthProvidersEndpointId].uri, '/providers');
      expect(tomOAuthApi[tomOAuthBeginEndpointId].method, TomHttpMethod.post);
      expect(tomOAuthApi[tomOAuthBeginEndpointId].uri, '/authorize');
      expect(tomOAuthApi[tomOAuthCompleteEndpointId].method, TomHttpMethod.get);
      expect(tomOAuthApi[tomOAuthCompleteEndpointId].uri, '/callback');
    });

    test('each endpoint states the request type it reads', () {
      // Listing the providers takes nothing at all, and says so explicitly:
      // the type parameter is `Object?`, which would otherwise be declared as
      // a body type the endpoint never has.
      expect(tomOAuthApi[tomOAuthProvidersEndpointId].requestTypes, isEmpty);
      expect(tomOAuthApi[tomOAuthBeginEndpointId].requestTypes, [
        TomOAuthAuthorizationRequest,
      ]);
      expect(tomOAuthApi[tomOAuthCompleteEndpointId].requestTypes, [
        TomOAuthCallbackRequest,
      ]);
    });

    test('each endpoint states the result type it answers with', () {
      expect(
        tomOAuthApi[tomOAuthProvidersEndpointId].responseType,
        List<TomOAuthProviderDto>,
      );
      expect(
        tomOAuthApi[tomOAuthBeginEndpointId].responseType,
        TomOAuthAuthorizationDto,
      );
      // The point of the whole module: an external identity produces exactly
      // the result a password login produces, so everything downstream of the
      // login is unaware of which credential was used.
      expect(
        tomOAuthApi[tomOAuthCompleteEndpointId].responseType,
        TomAuthenticationResult,
      );
    });

    test('the callback binds the provider spelling onto the DTO field', () {
      // The provider chooses these names, not us, and one of the four is not a
      // Dart identifier. A typo on either side of `error_description` is a
      // run-time-only failure on the one path a deployment cannot rehearse
      // without a real provider — which is the whole reason it is pinned here.
      expect(tomOAuthApi[tomOAuthCompleteEndpointId].urlParameterMapping, {
        'code': 'code',
        'state': 'state',
        'error': 'error',
        'error_description': 'errorDescription',
      });
    });

    test('the other two endpoints bind nothing from the URL', () {
      // `/authorize` states everything in its body and `/providers` states
      // nothing at all, so neither has a URL name that could disagree with a
      // field.
      expect(tomOAuthApi[tomOAuthProvidersEndpointId].urlParameterMapping, {});
      expect(tomOAuthApi[tomOAuthBeginEndpointId].urlParameterMapping, {});
    });

    test('the callback resolves exactly as a provider redirects to it', () {
      // The mapping asserted as a URL rather than as a map: the snake_cased
      // name has to survive into the query string, and the field name must not.
      expect(
        tomOAuthApi[tomOAuthCompleteEndpointId]
            .resolveUri(
              Uri.parse('https://api.example.com'),
              parameters: {
                'state': 's-1',
                'error': 'access_denied',
                'errorDescription': 'declined',
              },
            )
            .toString(),
        'https://api.example.com/oauth/callback'
        '?state=s-1&error=access_denied&error_description=declined',
      );
    });

    test('every endpoint is public, and necessarily so', () {
      // This is how a caller who is not yet authenticated becomes
      // authenticated. Requiring a principal on any of the three would make the
      // flow unreachable — the guard is the server-issued `state` handle and
      // the PKCE verifier, neither of which the caller supplies.
      expect(
        tomOAuthApi.endpoints.values.map((endpoint) => endpoint.access),
        everyElement(isA<TomPublicAccess>()),
      );
    });

    test('the service interface matches the endpoints it stands for', () {
      // `TomOAuthApiService` is the contract's Dart face: the server
      // implements it and a client calls through it, but nothing links the two
      // declarations, so a signature that drifted from its endpoint would
      // compile. The implementation below is the link — it does not compile if
      // a signature changes — and the assertions restate the types the
      // endpoints declare.
      final TomOAuthApiService service = _StubOAuthService();

      expect(
        service.listOAuthProviders(),
        isA<Future<List<TomOAuthProviderDto>>>(),
      );
      expect(
        service.beginOAuthAuthorization(TomOAuthAuthorizationRequest()),
        isA<Future<TomOAuthAuthorizationDto>>(),
      );
      expect(
        service.completeOAuthAuthorization(TomOAuthCallbackRequest()),
        isA<Future<TomAuthenticationResult>>(),
      );
    });
  });

  group('registerTomOAuthApi', () {
    test('it puts the contract itself into the registry', () {
      // The registry holds the declaration, not a copy of it, so a caller that
      // resolves an endpoint by id gets the same object the contract exports.
      registerTomOAuthApi();

      expect(tomRemoteApis.apis.containsKey(tomOAuthApiId), isTrue);
      expect(identical(tomRemoteApis[tomOAuthApiId], tomOAuthApi), isTrue);
    });

    test('registering twice registers once', () {
      // Both halves call it without coordinating — a server before mounting
      // the endpoints, a client before building a caller — so the second call
      // has to be free rather than a duplicate or a throw.
      registerTomOAuthApi();
      final registeredCount = tomRemoteApis.apis.length;

      expect(registerTomOAuthApi, returnsNormally);
      expect(tomRemoteApis.apis.length, registeredCount);
    });
  });
}

/// Minimal concrete implementation of TomAccessControl for testing.
class _TestAccessControl extends TomAccessControl {
  const _TestAccessControl();
  // Uses default implementation that returns false
}

/// Map-backed [TomAuthorizationAdapter] for authorization tests.
///
/// Resolves a known set of resource key paths; unknown paths fall back to
/// [TomAuthState.full] (matching the no-adapter development default).
class _FakeAuthAdapter implements TomAuthorizationAdapter {
  _FakeAuthAdapter(this._states);

  final Map<String, TomAuthState> _states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      _states[resourceKeyPath] ?? TomAuthState.full;
}

/// Minimal [TomAuthorizable] used to populate authorization groups in tests.
class _FakeAuthorizable implements TomAuthorizable {
  _FakeAuthorizable(this._id, {TomAuthState auth = TomAuthState.full})
    : _auth = auth;

  final String _id;
  final TomAuthState _auth;

  @override
  String? get tomId => _id;

  @override
  TomAuthorizationGroup? get tomGroup => null;

  @override
  TomAuthState get effectiveAuthState => _auth;
}

/// A [TomAuthorizable] whose state can change after registration, so tests can
/// hide and reveal a member without re-registering it.
class _MutableAuthorizable implements TomAuthorizable {
  _MutableAuthorizable(this._id, this.auth);

  final String _id;
  TomAuthState auth;

  @override
  String? get tomId => _id;

  @override
  TomAuthorizationGroup? get tomGroup => null;

  @override
  TomAuthState get effectiveAuthState => auth;
}

/// A [TomClientJwtToken] whose [payload] and [secretData] are fully controlled,
/// so token→principal conversion can be exercised without RSA/crypto setup.
///
/// The super-constructor still needs a syntactically valid JWT string to
/// decode; `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.sig` is `{"alg":...}.{}.sig`.
/// Decryption is disabled, so the real payload/secretData are never read — the
/// overrides below supply the values the tests care about.
class _FakeClientJwtToken extends TomClientJwtToken {
  _FakeClientJwtToken({
    Map<String, dynamic>? payload,
    Map<String, dynamic>? secretData,
  }) : _payload = payload,
       super('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.sig', decrypt: false) {
    this.secretData = secretData;
  }

  final Map<String, dynamic>? _payload;

  @override
  Map<String, dynamic>? get payload => _payload;
}

/// Sends [original] through the reflection JSON codec and back — the same path
/// the HTTP pipeline puts a wire DTO through.
///
/// Round-tripping is what catches the failure these DTOs are actually prone
/// to: they have no behaviour, so a renamed or dropped field breaks nothing at
/// compile time and shows up only as a value that arrived empty.
T _wireRoundTrip<T extends Object>(T original) {
  final json = tomReflectionInfo.convertToJsonString(original);
  return tomReflectionInfo.createInstanceFromJsonString<T>(
    tomReflector.reflectType(original.runtimeType) as ClassMirror,
    json,
  );
}

/// A do-nothing [TomOAuthApiService].
///
/// Exists to be compiled: the interface and the endpoint declarations are two
/// independent statements of the same three calls, and an implementation is
/// the only thing that fails when one of them moves.
class _StubOAuthService implements TomOAuthApiService {
  @override
  Future<List<TomOAuthProviderDto>> listOAuthProviders() async => const [];

  @override
  Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(
    TomOAuthAuthorizationRequest request,
  ) async => TomOAuthAuthorizationDto();

  @override
  Future<TomAuthenticationResult> completeOAuthAuthorization(
    TomOAuthCallbackRequest request,
  ) async => TomAuthenticationResult();
}

/// Builds an unsigned, undecrypted JWT string whose middle segment carries
/// [payload]. Suitable for [TomBearerAuthentication.setTokens] with
/// `decrypt: false`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  return '${seg(header)}.${seg(payload)}.sig';
}
