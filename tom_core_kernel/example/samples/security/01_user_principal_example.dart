// ignore_for_file: unnecessary_cast
/// Demonstrates TomUser, TomPrincipal, and TomAccessControlInformation usage.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Creating a Basic TomUser
// =============================================================================

class BasicUserExample {
  static int? userId;
  static String? userUsername;
  static String? userEmail;
  static String? userTimeZone;
  static String? userDepartment;
  static bool userCreated = false;

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
      timeZone: 'America/Los_Angeles',
      attributes: {'department': 'Engineering', 'employeeNumber': 'E1001'},
    );

    userId = user.id;
    userUsername = user.username;
    userEmail = user.email;
    userTimeZone = user.timeZone;
    userDepartment = user.attributes['department'] as String?;
    userCreated = true;

    assert(userId == 12345, 'User ID should match');
    assert(userUsername == 'jdoe', 'Username should match');
    assert(userEmail == 'john.doe@example.com', 'Email should match');
    assert(userTimeZone == 'America/Los_Angeles', 'Timezone should match');
    assert(userDepartment == 'Engineering', 'Department should match');
    assert(userCreated, 'User should be created');
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

    assert(guestUsername == TomUser.guestUsername, 'Guest username should match');
    assert(isGuest, 'Should be guest user');
    assert(guestConstant != null, 'Guest constant should exist');
  }
}

// =============================================================================
// EXAMPLE 3: Creating TomAccessControlInformation (ACI)
// =============================================================================

class AccessControlInfoExample {
  static int rolesCount = 0;
  static int groupsCount = 0;
  static int entitlementsCount = 0;
  static bool hasAdminRole = false;
  static bool aciCreated = false;

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

    rolesCount = aci.roles.length;
    groupsCount = aci.groups.length;
    entitlementsCount = aci.entitlements.length;
    hasAdminRole = aci.roles.contains('admin');
    aciCreated = true;

    assert(rolesCount == 3, 'Should have 3 roles');
    assert(groupsCount == 2, 'Should have 2 groups');
    assert(entitlementsCount == 3, 'Should have 3 entitlements');
    assert(hasAdminRole, 'Should have admin role');
    assert(aciCreated, 'ACI should be created');
  }
}

// =============================================================================
// EXAMPLE 4: Creating TomClientLimitsInformation (CLI)
// =============================================================================

class ClientLimitsInfoExample {
  static int modulesCount = 0;
  static bool hasReporting = false;
  static int? apiQuota;
  static bool cliCreated = false;

  static void example4ClientLimitsInfo() {
    final cli = TomClientLimitsInformation(
      enabledModules: ['core', 'reporting', 'analytics'],
      quotas: {
        'api_calls_per_day': 10000,
        'storage_mb': 5120,
        'max_users': 100,
      },
    );

    modulesCount = cli.enabledModules.length;
    hasReporting = cli.enabledModules.contains('reporting');
    apiQuota = cli.quotas['api_calls_per_day'] as int?;
    cliCreated = true;

    assert(modulesCount == 3, 'Should have 3 modules');
    assert(hasReporting, 'Should have reporting module');
    assert(apiQuota == 10000, 'API quota should be 10000');
    assert(cliCreated, 'CLI should be created');
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
  static bool principalCreated = false;

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
    principalCreated = true;

    assert(authenticated == true, 'Should be authenticated');
    assert(principalUsername == 'jdoe', 'Username should match');
    assert(principalId == 12345, 'ID should match');
    assert(organization == 'acme-corp', 'Organization should match');
    assert(principalCreated, 'Principal should be created');
  }
}

// =============================================================================
// EXAMPLE 6: Adding Context to Principal
// =============================================================================

class PrincipalContextExample {
  static String? sessionStart;
  static String? ipAddress;
  static int contextSize = 0;
  static bool contextAdded = false;

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
    contextAdded = true;

    assert(sessionStart == '2026-01-01T10:00:00Z', 'Session start should match');
    assert(ipAddress == '192.168.1.100', 'IP address should match');
    assert(contextSize >= 2, 'Context should have at least 2 entries');
    assert(contextAdded, 'Context should be added');
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
  BasicUserExample.example1BasicUser();
  GuestUserExample.example2GuestUser();
  AccessControlInfoExample.example3AccessControlInfo();
  ClientLimitsInfoExample.example4ClientLimitsInfo();
  TomPrincipalExample.example5TomPrincipal();
  PrincipalContextExample.example6PrincipalContext();
  TwoFactorPrincipalExample.example7TwoFactorPrincipal();
}

void main() => run();
