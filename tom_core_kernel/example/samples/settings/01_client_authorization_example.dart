/// Demonstrates TomGetSettingsMessage and TomGetSettingsResult usage.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Creating a Settings Request Message
// =============================================================================

class SettingsRequestExample {
  static String? messageToken;
  static bool hasToken = false;
  static bool requestCreated = false;

  static void example1SettingsRequest() {
    final message = TomGetSettingsMessage()
      ..authorizationToken = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz';

    messageToken = message.authorizationToken;
    hasToken =
        message.authorizationToken != null &&
        message.authorizationToken!.isNotEmpty;
    requestCreated = true;

    assert(messageToken != null, 'Token should be set');
    assert(hasToken, 'Should have token');
    assert(requestCreated, 'Request should be created');
  }
}

// =============================================================================
// EXAMPLE 2: Creating an Anonymous Settings Request
// =============================================================================

class AnonymousRequestExample {
  static String? anonymousToken;
  static bool isAnonymous = false;

  static void example2AnonymousRequest() {
    final anonymousMessage = TomGetSettingsMessage();

    anonymousToken = anonymousMessage.authorizationToken;
    isAnonymous =
        anonymousMessage.authorizationToken == null ||
        anonymousMessage.authorizationToken!.isEmpty;

    assert(isAnonymous, 'Should be anonymous request');
  }
}

// =============================================================================
// EXAMPLE 3: Creating a Basic Settings Result
// =============================================================================

class BasicResultExample {
  static int textsCount = 0;
  static int configCount = 0;
  static int rolesCount = 0;
  static bool defaultsToEmpty = false;

  static void example3BasicResult() {
    final basicResult = TomGetSettingsResult();

    textsCount = basicResult.texts.length;
    configCount = basicResult.config.length;
    rolesCount = basicResult.roles.length;

    defaultsToEmpty = textsCount == 0 && configCount == 0 && rolesCount == 0;

    assert(textsCount == 0, 'Texts should default to empty');
    assert(configCount == 0, 'Config should default to empty');
    assert(rolesCount == 0, 'Roles should default to empty');
    assert(defaultsToEmpty, 'All should default to empty');
  }
}

// =============================================================================
// EXAMPLE 4: Creating a Fully Populated Settings Result
// =============================================================================

class FullResultExample {
  static int textsCount = 0;
  static int configCount = 0;
  static int rolesCount = 0;
  static int groupsCount = 0;
  static int entitlementsCount = 0;
  static bool resultCreated = false;

  static void example4FullResult() {
    final result = TomGetSettingsResult(
      texts: {
        'welcome': 'Welcome to the Application',
        'logout': 'Sign Out',
        'error.network': 'Network connection failed',
      },
      config: {
        'theme': 'dark',
        'maxItemsPerPage': 50,
        'enableNotifications': true,
      },
      roles: ['admin', 'editor', 'viewer'],
      groups: ['engineering', 'platform-team'],
      entitlements: [
        'feature.dashboard.view',
        'feature.dashboard.edit',
        'feature.reports.view',
      ],
      resourceKeys: ['dashboard', 'reports'],
      organization: 'acme-corp',
      application: 'admin-portal',
      language: 'en',
      clientTimeZone: 'America/New_York',
    );

    textsCount = result.texts.length;
    configCount = result.config.length;
    rolesCount = result.roles.length;
    groupsCount = result.groups.length;
    entitlementsCount = result.entitlements.length;
    resultCreated = true;

    assert(textsCount == 3, 'Should have 3 texts');
    assert(configCount == 3, 'Should have 3 config entries');
    assert(rolesCount == 3, 'Should have 3 roles');
    assert(groupsCount == 2, 'Should have 2 groups');
    assert(entitlementsCount == 3, 'Should have 3 entitlements');
    assert(resultCreated, 'Result should be created');
  }
}

// =============================================================================
// EXAMPLE 5: Accessing Text Resources
// =============================================================================

class AccessTextsExample {
  static String? welcomeText;
  static String? logoutText;
  static String? missingText;
  static bool textsAccessible = false;

  static void example5AccessTexts() {
    final result = TomGetSettingsResult(
      texts: {'welcome': 'Welcome!', 'logout': 'Sign Out'},
    );

    welcomeText = result.texts['welcome'] as String?;
    logoutText = result.texts['logout'] as String?;
    missingText = result.texts['nonexistent'] as String?;

    textsAccessible =
        welcomeText == 'Welcome!' &&
        logoutText == 'Sign Out' &&
        missingText == null;

    assert(welcomeText == 'Welcome!', 'Welcome should match');
    assert(logoutText == 'Sign Out', 'Logout should match');
    assert(missingText == null, 'Missing should be null');
    assert(textsAccessible, 'Texts should be accessible');
  }
}

// =============================================================================
// EXAMPLE 6: Accessing Configuration Values
// =============================================================================

class AccessConfigExample {
  static String? theme;
  static int? maxItems;
  static bool? notifications;
  static bool configAccessible = false;

  static void example6AccessConfig() {
    final result = TomGetSettingsResult(
      config: {
        'theme': 'dark',
        'maxItemsPerPage': 50,
        'enableNotifications': true,
      },
    );

    theme = result.config['theme'] as String?;
    maxItems = result.config['maxItemsPerPage'] as int?;
    notifications = result.config['enableNotifications'] as bool?;

    configAccessible =
        theme == 'dark' && maxItems == 50 && notifications == true;

    assert(theme == 'dark', 'Theme should be dark');
    assert(maxItems == 50, 'Max items should be 50');
    assert(notifications == true, 'Notifications should be true');
    assert(configAccessible, 'Config should be accessible');
  }
}

// =============================================================================
// EXAMPLE 7: Checking Authorization Roles
// =============================================================================

class CheckRolesExample {
  static bool hasAdminRole = false;
  static bool hasEditorRole = false;
  static bool hasSuperRole = false;
  static bool roleCheckWorks = false;

  static void example7CheckRoles() {
    final result = TomGetSettingsResult(roles: ['admin', 'editor', 'viewer']);

    hasAdminRole = result.roles.contains('admin');
    hasEditorRole = result.roles.contains('editor');
    hasSuperRole = result.roles.contains('super-admin');

    roleCheckWorks = hasAdminRole && hasEditorRole && !hasSuperRole;

    assert(hasAdminRole, 'Should have admin role');
    assert(hasEditorRole, 'Should have editor role');
    assert(!hasSuperRole, 'Should not have super-admin role');
    assert(roleCheckWorks, 'Role check should work');
  }
}

// =============================================================================
// EXAMPLE 8: Checking Entitlements
// =============================================================================

class CheckEntitlementsExample {
  static bool canViewDashboard = false;
  static bool canEditDashboard = false;
  static bool canDeleteUsers = false;
  static bool entitlementCheckWorks = false;

  static void example8CheckEntitlements() {
    final result = TomGetSettingsResult(
      entitlements: ['feature.dashboard.view', 'feature.dashboard.edit'],
    );

    canViewDashboard = result.entitlements.contains('feature.dashboard.view');
    canEditDashboard = result.entitlements.contains('feature.dashboard.edit');
    canDeleteUsers = result.entitlements.contains('admin.users.delete');

    entitlementCheckWorks =
        canViewDashboard && canEditDashboard && !canDeleteUsers;

    assert(canViewDashboard, 'Should be able to view dashboard');
    assert(canEditDashboard, 'Should be able to edit dashboard');
    assert(!canDeleteUsers, 'Should not be able to delete users');
    assert(entitlementCheckWorks, 'Entitlement check should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  SettingsRequestExample.example1SettingsRequest();
  AnonymousRequestExample.example2AnonymousRequest();
  BasicResultExample.example3BasicResult();
  FullResultExample.example4FullResult();
  AccessTextsExample.example5AccessTexts();
  AccessConfigExample.example6AccessConfig();
  CheckRolesExample.example7CheckRoles();
  CheckEntitlementsExample.example8CheckEntitlements();
}

void main() {
  requireAsserts();
  run();
}
