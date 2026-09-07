/// Demonstrates TomUser, TomPrincipal, and TomAccessControlInformation usage.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/01_user_principal_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: Creating a Basic TomUser
// =============================================================================

class BasicUserExample {
  static int? userId;
  static String? userUsername;
  static String? userEmail;
  static String? userTimezone;
  static String? userDepartment;

  static void example1BasicUser() {
    final user = TomUser(
      id: 12345,
      username: 'jdoe',
      firstname: 'John',
      lastname: 'Doe',
      email: 'john.doe@example.com',
      phone: '+1-555-123-4567',
      city: 'San Francisco',
      stateRegion: 'CA',
      timezone: 'America/Los_Angeles',
      attributes: {'department': 'Engineering', 'employeeNumber': 'E1001'},
    );

    userId = user.id;
    userUsername = user.username;
    userEmail = user.email;
    userTimezone = user.timezone;
    userDepartment = user.attributes['department'] as String?;

    assert(userId == 12345, 'User ID should match');
    assert(userUsername == 'jdoe', 'Username should match');
    assert(userEmail == 'john.doe@example.com', 'Email should match');
    assert(userTimezone == 'America/Los_Angeles', 'Timezone should match');
    assert(userDepartment == 'Engineering', 'Department should match');
  }
}

// =============================================================================
// EXAMPLE 2: Creating a Guest User
// =============================================================================

class GuestUserExample {
  static String? guestUsername;
  static bool isGuest = false;
  static String? guestConstant;

  static void example2GuestUser() {
    final guestUser = TomUser();

    guestUsername = guestUser.username;
    isGuest = guestUser.username == TomUser.guestUsername;
    guestConstant = TomUser.guestUsername;

    assert(
      guestUsername == TomUser.guestUsername,
      'Guest username should match',
    );
    assert(isGuest, 'Should be guest user');
    assert(guestConstant != null, 'Guest constant should exist');
  }
}

// =============================================================================
// EXAMPLE 3: Creating TomAccessControlInformation (ACI)
// =============================================================================

class AccessControlInfoExample {
  static List<String> roles = const [];
  static List<String> groups = const [];
  static List<String> entitlements = const [];
  static int rolesCount = 0;
  static int groupsCount = 0;
  static int entitlementsCount = 0;
  static bool hasAdminRole = false;

  static void example3AccessControlInfo() {
    final aci = TomAccessControlInformation(
      roles: ['admin', 'user', 'developer'],
      groups: ['engineering', 'platform-team'],
      entitlements: [
        'feature.dashboard.view',
        'feature.dashboard.edit',
        'feature.reports.view',
      ],
      resourceKeys: ['user.email', 'user.phone'],
    );

    roles = aci.roles;
    groups = aci.groups;
    entitlements = aci.entitlements;
    rolesCount = aci.roles.length;
    groupsCount = aci.groups.length;
    entitlementsCount = aci.entitlements.length;
    hasAdminRole = aci.roles.contains('admin');

    assert(rolesCount == 3, 'Should have 3 roles');
    assert(groupsCount == 2, 'Should have 2 groups');
    assert(entitlementsCount == 3, 'Should have 3 entitlements');
    assert(hasAdminRole, 'Should have admin role');
  }
}

// =============================================================================
// EXAMPLE 4: Creating TomClientLimitsInformation (CLI)
// =============================================================================

class ClientLimitsInfoExample {
  static List<String> enabledModules = const [];
  static Map<String, dynamic> quotas = const {};
  static int modulesCount = 0;
  static bool hasReporting = false;
  static int? apiQuota;

  static void example4ClientLimitsInfo() {
    final cli = TomClientLimitsInformation(
      enabledModules: ['core', 'reporting', 'analytics'],
      quotas: {
        'api_calls_per_day': 10000,
        'storage_mb': 5120,
        'max_users': 100,
      },
    );

    enabledModules = cli.enabledModules;
    quotas = cli.quotas;
    modulesCount = cli.enabledModules.length;
    hasReporting = cli.enabledModules.contains('reporting');
    apiQuota = cli.quotas['api_calls_per_day'];

    assert(modulesCount == 3, 'Should have 3 modules');
    assert(hasReporting, 'Should have reporting module');
    assert(apiQuota == 10000, 'API quota should be 10000');
  }
}

// =============================================================================
// EXAMPLE 5: Creating a TomPrincipal
// =============================================================================

class TomPrincipalExample {
  static bool? authenticated;
  static String? principalUsername;
  static int? principalId;
  static String? organization;

  static void example5TomPrincipal() {
    final user = TomUser(id: 12345, username: 'jdoe');
    final aci = TomAccessControlInformation(
      roles: ['admin'],
      groups: ['engineering'],
      entitlements: ['feature.dashboard.view'],
    );
    final cli = TomClientLimitsInformation(
      enabledModules: ['core'],
      quotas: {'api_calls_per_day': 10000},
    );

    final principal = TomPrincipal(
      authenticated: true,
      user: user,
      aci: aci,
      cli: cli,
      organization: 'acme-corp',
      application: 'dashboard',
      process: 'main',
      timezone: 'America/New_York',
    );

    authenticated = principal.authenticated;
    principalUsername = principal.username;
    principalId = principal.id;
    organization = principal.organization;

    assert(authenticated == true, 'Should be authenticated');
    assert(principalUsername == 'jdoe', 'Username should match');
    assert(principalId == 12345, 'ID should match');
    assert(organization == 'acme-corp', 'Organization should match');
  }
}

// =============================================================================
// EXAMPLE 6: Adding Context to Principal
// =============================================================================

class PrincipalContextExample {
  static String? sessionStart;
  static String? ipAddress;
  static int contextSize = 0;

  static void example6PrincipalContext() {
    final principal = TomPrincipal(
      authenticated: true,
      user: TomUser(id: 1, username: 'testuser'),
    );

    principal.addToContext({
      'sessionStart': '2026-01-01T10:00:00Z',
      'ipAddress': '192.168.1.100',
    });

    sessionStart = principal.currentContext['sessionStart'] as String?;
    ipAddress = principal.currentContext['ipAddress'] as String?;
    contextSize = principal.currentContext.length;

    assert(
      sessionStart == '2026-01-01T10:00:00Z',
      'Session start should match',
    );
    assert(ipAddress == '192.168.1.100', 'IP address should match');
    assert(contextSize >= 2, 'Context should have at least 2 entries');
  }
}

// =============================================================================
// EXAMPLE 7: Principal Requiring 2FA
// =============================================================================

class TwoFactorPrincipalExample {
  static bool? requires2FA;
  static String? twoFactorType;
  static bool twoFactorWorks = false;

  static void example7TwoFactorPrincipal() {
    final principal = TomPrincipal(
      authenticated: true,
      requires2FA: true,
      twoFactorType: 'totp',
      user: TomUser(id: 99, username: 'secure_user'),
    );

    requires2FA = principal.requires2FA;
    twoFactorType = principal.twoFactorType;

    twoFactorWorks = requires2FA == true && twoFactorType == 'totp';

    assert(requires2FA == true, 'Should require 2FA');
    assert(twoFactorType == 'totp', '2FA type should be totp');
    assert(twoFactorWorks, '2FA should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 01: User Principal Example ===\n');

  BasicUserExample.example1BasicUser();
  print('1. A TomUser carries identity plus free-form attributes:');
  print('   id         : ${BasicUserExample.userId}');
  print('   username   : ${BasicUserExample.userUsername}');
  print('   email      : ${BasicUserExample.userEmail}');
  print('   timezone   : ${BasicUserExample.userTimezone}');
  print('   department : ${BasicUserExample.userDepartment} (from attributes)');
  print('');

  GuestUserExample.example2GuestUser();
  print('2. A default TomUser is the guest identity:');
  print('   username             : ${GuestUserExample.guestUsername}');
  print('   TomUser.guestUsername: ${GuestUserExample.guestConstant}');
  print('   is the guest         : ${GuestUserExample.isGuest}');
  print('');

  AccessControlInfoExample.example3AccessControlInfo();
  print('3. What the ACI grants the user:');
  print('   roles         : ${AccessControlInfoExample.roles}');
  print('   groups        : ${AccessControlInfoExample.groups}');
  print('   entitlements  : ${AccessControlInfoExample.entitlements}');
  print('   has admin role: ${AccessControlInfoExample.hasAdminRole}');
  print('');

  ClientLimitsInfoExample.example4ClientLimitsInfo();
  print('4. What the client licence enables and caps:');
  print('   enabled modules  : ${ClientLimitsInfoExample.enabledModules}');
  print('   quotas           : ${ClientLimitsInfoExample.quotas}');
  print('   reporting enabled: ${ClientLimitsInfoExample.hasReporting}');
  print('   api calls per day: ${ClientLimitsInfoExample.apiQuota}');
  print('');

  TomPrincipalExample.example5TomPrincipal();
  print('5. The principal joins the user to their ACI, limits and scope:');
  print('   authenticated : ${TomPrincipalExample.authenticated}');
  print('   username      : ${TomPrincipalExample.principalUsername}');
  print('   id            : ${TomPrincipalExample.principalId}');
  print('   organization  : ${TomPrincipalExample.organization}');
  print('');

  PrincipalContextExample.example6PrincipalContext();
  print('6. Per-session facts added to the principal context:');
  print('   sessionStart : ${PrincipalContextExample.sessionStart}');
  print('   ipAddress    : ${PrincipalContextExample.ipAddress}');
  print('   context size : ${PrincipalContextExample.contextSize}');
  print('');

  TwoFactorPrincipalExample.example7TwoFactorPrincipal();
  print('7. A principal still owing a second factor:');
  print('   requires2FA   : ${TwoFactorPrincipalExample.requires2FA}');
  print('   twoFactorType : ${TwoFactorPrincipalExample.twoFactorType}');
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
