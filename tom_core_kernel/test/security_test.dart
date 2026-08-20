import 'package:test/test.dart';
import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
        expect(user.timeZone, isNull);
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
          timeZone: 'America/New_York',
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
        expect(user.timeZone, equals('America/New_York'));
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

      test(
        'should preserve the user\'s own resource keys',
        () {
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
        },
      );

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

      test(
        'resolved entitlements are entitlements, not a copy of groups',
        () {
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
        },
      );

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

    test('should grant access when protection is disabled', () {
      var access = const TomResourceKeyAccess('user.salary');
      expect(access.checkAccessibility(null), isTrue);
    });

    test('should integrate with TomResourceKeyProtection', () {
      // Arrange
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      var access = const TomResourceKeyAccess('user.salary');

      // Act - no principal in zone means protected
      var result = access.checkAccessibility(createTestPrincipal());

      // Assert
      expect(result, isFalse);
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

      test('mostRestrictive returns full for an empty group', () {
        expect(
          TomAuthorizationGroup('g').mostRestrictive,
          equals(TomAuthState.full),
        );
      });
    });

    test('toString includes groupId and mode', () {
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsAll,
      );
      expect(group.toString(), contains('shipping'));
      expect(group.toString(), contains('controlsAll'));
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
        );

        final aci = TomBearerAuthentication.getPrincipal().aci;
        expect(aci.groups, equals(['team-a']));
        expect(aci.roles, equals(['lead']));
        expect(aci.entitlements, equals(['feature.x']));
        expect(aci.resourceKeys, equals(['key.y']));
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

/// Builds an unsigned, undecrypted JWT string whose middle segment carries
/// [payload]. Suitable for [TomBearerAuthentication.setTokens] with
/// `decrypt: false`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  return '${seg(header)}.${seg(payload)}.sig';
}
