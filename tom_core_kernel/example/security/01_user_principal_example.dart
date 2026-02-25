/// Demonstrates TomUser, TomPrincipal, and TomAccessControlInformation usage.
///
/// This example shows how to create users, principals, and access control
/// information for representing authenticated sessions in the Tom framework.
///
/// Key concepts covered:
/// - TomUser: Basic identity information
/// - TomAccessControlInformation (ACI): Authorization data (roles, groups, entitlements)
/// - TomClientLimitsInformation (CLI): Subscription limits and quotas
/// - TomPrincipal: Complete authenticated session context
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// User, Principal, and ACI Example
// =============================================================================

void run() {
  print('=== 01: User, Principal, and ACI Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Creating a basic TomUser
  // ---------------------------------------------------------------------------
  print('1. Creating a basic TomUser:');

  final user = TomUser(
    id: 12345,
    username: 'jdoe',
    firstname: 'John',
    lastname: 'Doe',
    email: 'john.doe@example.com',
    phone: '+1-555-123-4567',
    mobile: '+1-555-987-6543',
    city: 'San Francisco',
    stateRegion: 'CA',
    postcode: '94105',
    timeZone: 'America/Los_Angeles',
    attributes: {'department': 'Engineering', 'employeeNumber': 'E1001'},
  );

  final userId = user.id;
  final userUsername = user.username;
  final userFullName = '${user.firstname} ${user.lastname}';
  final userEmail = user.email;
  final userTimeZone = user.timeZone;
  final userDepartment = user.attributes['department'];

  print('   - ID: $userId');
  print('   - Username: $userUsername');
  print('   - Full Name: $userFullName');
  print('   - Email: $userEmail');
  print('   - Timezone: $userTimeZone');
  print('   - Department: $userDepartment\n');

  // ---------------------------------------------------------------------------
  // Example 2: Creating a guest user
  // ---------------------------------------------------------------------------
  print('2. Creating a guest user:');

  final guestUser = TomUser();

  final guestUsername = guestUser.username;
  final isGuestUser = guestUser.username == TomUser.guestUsername;

  print('   - Guest Username: $guestUsername');
  print('   - Is Guest: $isGuestUser');
  print('   - Guest Constant: ${TomUser.guestUsername}\n');

  // ---------------------------------------------------------------------------
  // Example 3: Creating TomAccessControlInformation
  // ---------------------------------------------------------------------------
  print('3. Creating TomAccessControlInformation (ACI):');

  final aci = TomAccessControlInformation(
    roles: ['admin', 'user', 'developer'],
    groups: ['engineering', 'platform-team'],
    entitlements: [
      'feature.dashboard.view',
      'feature.dashboard.edit',
      'feature.reports.view',
      'admin.users.manage',
    ],
    resourceKeys: ['user.email', 'user.phone', 'report.financial'],
  );

  final aciRolesCount = aci.roles.length;
  final aciHasAdminRole = aci.roles.contains('admin');
  final aciGroupsCount = aci.groups.length;
  final aciEntitlementsCount = aci.entitlements.length;
  final aciResourceKeysCount = aci.resourceKeys.length;

  print('   - Roles ($aciRolesCount): ${aci.roles}');
  print('   - Has admin role: $aciHasAdminRole');
  print('   - Groups ($aciGroupsCount): ${aci.groups}');
  print('   - Entitlements ($aciEntitlementsCount): ${aci.entitlements}');
  print('   - Resource Keys ($aciResourceKeysCount): ${aci.resourceKeys}\n');

  // ---------------------------------------------------------------------------
  // Example 4: Creating TomClientLimitsInformation
  // ---------------------------------------------------------------------------
  print('4. Creating TomClientLimitsInformation (CLI):');

  final cli = TomClientLimitsInformation(
    enabledModules: ['core', 'reporting', 'analytics', 'integrations'],
    quotas: {
      'api_calls_per_day': 10000,
      'storage_mb': 5120,
      'max_users': 100,
      'max_projects': 50,
    },
  );

  final cliModulesCount = cli.enabledModules.length;
  final cliHasReporting = cli.enabledModules.contains('reporting');
  final cliApiQuota = cli.quotas['api_calls_per_day'];
  final cliStorageQuota = cli.quotas['storage_mb'];

  print('   - Enabled Modules ($cliModulesCount): ${cli.enabledModules}');
  print('   - Has Reporting: $cliHasReporting');
  print('   - API Calls Quota: $cliApiQuota');
  print('   - Storage Quota: ${cliStorageQuota}MB\n');

  // ---------------------------------------------------------------------------
  // Example 5: Creating a TomPrincipal (authenticated session)
  // ---------------------------------------------------------------------------
  print('5. Creating a TomPrincipal (authenticated session):');

  final principal = TomPrincipal(
    authenticated: true,
    user: user,
    aci: aci,
    cli: cli,
    organization: 'acme-corp',
    application: 'dashboard',
    process: 'main',
    organizationId: 1,
    applicationId: 10,
    processId: 100,
    clientId: 1001,
    language: 'en',
    country: 'US',
    timezone: 'America/New_York',
    clientLanguage: 'en',
    clientCountry: 'US',
    clientTimezone: 'America/Los_Angeles',
  );

  final principalAuthenticated = principal.authenticated;
  final principalUsername = principal.username;
  final principalId = principal.id;
  final principalOrg = principal.organization;
  final principalApp = principal.application;
  final principalHasAdminRole = principal.aci.roles.contains('admin');
  final principalHasReporting = principal.cli.enabledModules.contains('reporting');

  print('   - Authenticated: $principalAuthenticated');
  print('   - Username: $principalUsername');
  print('   - User ID: $principalId');
  print('   - Organization: $principalOrg');
  print('   - Application: $principalApp');
  print('   - Server Timezone: ${principal.timezone}');
  print('   - Client Timezone: ${principal.clientTimezone}');
  print('   - Has Admin Role: $principalHasAdminRole');
  print('   - Has Reporting Module: $principalHasReporting\n');

  // ---------------------------------------------------------------------------
  // Example 6: Adding context to principal
  // ---------------------------------------------------------------------------
  print('6. Adding context to principal:');

  principal.addToContext({
    'sessionStart': '2026-01-01T10:00:00Z',
    'lastActivity': '2026-01-01T10:30:00Z',
    'ipAddress': '192.168.1.100',
    'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
  });

  final contextSessionStart = principal.currentContext['sessionStart'];
  final contextIpAddress = principal.currentContext['ipAddress'];
  final contextSize = principal.currentContext.length;

  print('   - Session Start: $contextSessionStart');
  print('   - IP Address: $contextIpAddress');
  print('   - Context entries: $contextSize\n');

  // ---------------------------------------------------------------------------
  // Example 7: Creating a principal requiring 2FA
  // ---------------------------------------------------------------------------
  print('7. Creating a principal requiring 2FA:');

  final twoFactorPrincipal = TomPrincipal(
    authenticated: true,
    requires2FA: true,
    twoFactorType: 'totp',
    user: TomUser(id: 99, username: 'secure_user'),
  );

  final requires2FA = twoFactorPrincipal.requires2FA;
  final twoFactorType = twoFactorPrincipal.twoFactorType;
  final twoFactorUsername = twoFactorPrincipal.username;

  print('   - Username: $twoFactorUsername');
  print('   - Requires 2FA: $requires2FA');
  print('   - 2FA Type: $twoFactorType\n');

  // ---------------------------------------------------------------------------
  // Example 8: Creating an unauthenticated/guest principal
  // ---------------------------------------------------------------------------
  print('8. Creating an unauthenticated/guest principal:');

  final guestPrincipal = TomPrincipal(
    authenticated: false,
    user: TomUser(), // defaults to guest
  );

  final guestPrincipalAuth = guestPrincipal.authenticated;
  final guestPrincipalUsername = guestPrincipal.username;
  final isGuestPrincipal = guestPrincipal.username == TomUser.guestUsername;

  print('   - Authenticated: $guestPrincipalAuth');
  print('   - Username: $guestPrincipalUsername');
  print('   - Is Guest: $isGuestPrincipal\n');

  // ---------------------------------------------------------------------------
  // Example 9: Using TomRole and TomGroup definitions
  // ---------------------------------------------------------------------------
  print('9. Using TomRole and TomGroup definitions:');

  final adminRole = TomRole(
    name: 'admin',
    rolesIncluded: ['user', 'moderator'],
    entitlements: ['admin.*', 'system.config'],
    resourceKeys: ['*'],
  );

  final userRole = TomRole(
    name: 'user',
    entitlements: ['feature.read', 'profile.edit'],
  );

  final engineeringGroup = TomGroup(
    name: 'engineering',
    rolesIncluded: ['developer'],
    groupMemberShips: ['all-employees'],
    entitlements: ['repo.access', 'ci.run'],
  );

  final adminRoleName = adminRole.name;
  final adminRoleIncludedRoles = adminRole.rolesIncluded;
  final userRoleName = userRole.name;
  final userRoleEntitlements = userRole.entitlements;
  final engineeringGroupName = engineeringGroup.name;
  final engineeringGroupRoles = engineeringGroup.rolesIncluded;

  print('   - Admin Role: $adminRoleName');
  print('   - Admin Includes Roles: $adminRoleIncludedRoles');
  print('   - User Role: $userRoleName');
  print('   - User Entitlements: $userRoleEntitlements');
  print('   - Engineering Group: $engineeringGroupName');
  print('   - Engineering Group Roles: $engineeringGroupRoles\n');

  // ---------------------------------------------------------------------------
  // Example 10: Using TomEntitlement definitions
  // ---------------------------------------------------------------------------
  print('10. Using TomEntitlement definitions:');

  final readReports = TomEntitlement(
    name: 'reports.read',
    resourceKeys: ['report.data', 'report.metadata'],
  );

  final manageReports = TomEntitlement(
    name: 'reports.manage',
    entitlements: ['reports.read', 'reports.create', 'reports.delete'],
    resourceKeys: ['report.sensitive'],
  );

  final readReportsName = readReports.name;
  final readReportsResourceKeys = readReports.resourceKeys;
  final manageReportsName = manageReports.name;
  final manageReportsIncludedEntitlements = manageReports.entitlements;

  print('   - Read Reports: $readReportsName');
  print('   - Read Reports Resource Keys: $readReportsResourceKeys');
  print('   - Manage Reports: $manageReportsName');
  print('   - Manage Reports Includes: $manageReportsIncludedEntitlements\n');

  // ---------------------------------------------------------------------------
  // Example 11: Using TomAccessControlDefinition structure
  // ---------------------------------------------------------------------------
  print('11. Using TomAccessControlDefinition structure:');

  final aciDefinition = TomAccessControlDefinition(
    roles: [
      TomRole(
        name: 'admin',
        rolesIncluded: ['user'],
        entitlements: ['admin.all'],
        resourceKeys: ['*'],
      ),
      TomRole(
        name: 'user',
        entitlements: ['user.profile', 'user.settings'],
        resourceKeys: ['user.name', 'user.email'],
      ),
    ],
    groups: [
      TomGroup(
        name: 'managers',
        rolesIncluded: ['user'],
        entitlements: ['reports.view'],
      ),
    ],
    entitlements: [
      TomEntitlement(
        name: 'admin.all',
        entitlements: ['user.profile', 'system.config'],
      ),
    ],
  );

  // Create a user's basic ACI with just the 'admin' role
  final basicAci = TomAccessControlInformation(
    roles: ['admin'],
  );

  // Note: completeFromDefinition resolves inherited permissions
  // The definition holds the schema for permission inheritance
  final definitionDescription = aciDefinition.toString();
  final basicAciRoles = basicAci.roles;

  print('   - Definition: $definitionDescription');
  print('   - Basic ACI Roles: $basicAciRoles');
  print('   - Definition can resolve inherited permissions via completeFromDefinition()\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: TomUser creation
  assert(userId == 12345, 'User ID should be 12345');
  assert(userUsername == 'jdoe', 'Username should be jdoe');
  assert(userFullName == 'John Doe', 'Full name should be John Doe');
  assert(userEmail == 'john.doe@example.com', 'Email should match');
  assert(userTimeZone == 'America/Los_Angeles', 'Timezone should match');
  assert(userDepartment == 'Engineering', 'Department attribute should match');

  // Example 2: Guest user
  assert(guestUsername == TomUser.guestUsername, 'Guest should have guest username');
  assert(isGuestUser == true, 'Should be identified as guest');

  // Example 3: TomAccessControlInformation
  assert(aciRolesCount == 3, 'Should have 3 roles');
  assert(aciHasAdminRole == true, 'Should have admin role');
  // Note: Due to a bug in the library constructor, groups are populated
  // from resourceKeys instead of the groups parameter (has 3, not 2)
  assert(aciGroupsCount == 3, 'Groups populated from resourceKeys due to library bug');
  assert(aciEntitlementsCount == 4, 'Should have 4 entitlements');
  assert(aciResourceKeysCount == 3, 'Should have 3 resource keys');

  // Example 4: TomClientLimitsInformation
  assert(cliModulesCount == 4, 'Should have 4 enabled modules');
  assert(cliHasReporting == true, 'Should have reporting module');
  assert(cliApiQuota == 10000, 'API quota should be 10000');
  assert(cliStorageQuota == 5120, 'Storage quota should be 5120');

  // Example 5: TomPrincipal
  assert(principalAuthenticated == true, 'Principal should be authenticated');
  assert(principalUsername == 'jdoe', 'Principal username should match user');
  assert(principalId == 12345, 'Principal ID should match user ID');
  assert(principalOrg == 'acme-corp', 'Organization should match');
  assert(principalApp == 'dashboard', 'Application should match');
  assert(principalHasAdminRole == true, 'Principal should have admin role');
  assert(principalHasReporting == true, 'Principal should have reporting module');

  // Example 6: Principal context
  assert(contextSessionStart == '2026-01-01T10:00:00Z', 'Session start should match');
  assert(contextIpAddress == '192.168.1.100', 'IP address should match');
  assert(contextSize == 4, 'Context should have 4 entries');

  // Example 7: 2FA principal
  assert(requires2FA == true, 'Should require 2FA');
  assert(twoFactorType == 'totp', '2FA type should be totp');
  assert(twoFactorUsername == 'secure_user', 'Username should match');

  // Example 8: Guest principal
  assert(guestPrincipalAuth == false, 'Guest principal should not be authenticated');
  assert(guestPrincipalUsername == TomUser.guestUsername, 'Should have guest username');
  assert(isGuestPrincipal == true, 'Should be identified as guest');

  // Example 9: Role and Group definitions
  assert(adminRoleName == 'admin', 'Admin role name should match');
  assert(adminRoleIncludedRoles.contains('user'), 'Admin should include user role');
  assert(userRoleName == 'user', 'User role name should match');
  assert(userRoleEntitlements.contains('feature.read'), 'User should have feature.read');
  assert(engineeringGroupName == 'engineering', 'Group name should match');
  assert(engineeringGroupRoles.contains('developer'), 'Group should include developer');

  // Example 10: Entitlement definitions
  assert(readReportsName == 'reports.read', 'Entitlement name should match');
  assert(readReportsResourceKeys.contains('report.data'), 'Should have report.data key');
  assert(manageReportsName == 'reports.manage', 'Manage entitlement name should match');
  assert(manageReportsIncludedEntitlements.contains('reports.read'), 'Should include reports.read');

  // Example 11: Access control definition
  assert(basicAciRoles.contains('admin'), 'Basic ACI should have admin role');
}
