/// Demonstrates TomGetSettingsMessage and TomGetSettingsResult usage.
///
/// This example shows how to create settings request messages and work with
/// settings results containing authorization data, localization preferences,
/// and configuration values.
///
/// Key concepts covered:
/// - TomGetSettingsMessage: Request message with authorization token
/// - TomGetSettingsResult: Response containing texts, config, and authorization
/// - Authorization data: roles, groups, entitlements, resourceKeys
/// - Localization: country, language, timezone settings
/// - Application context: organization, process, application
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Client Authorization Settings Example
// =============================================================================

void run() {
  print('=== 01: Client Authorization Settings Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Creating a settings request message
  // ---------------------------------------------------------------------------
  print('1. Creating a settings request message:');

  final message = TomGetSettingsMessage()
    ..authorizationToken = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz';

  final messageToken = message.authorizationToken;
  final messageHasToken = message.authorizationToken != null &&
      message.authorizationToken!.isNotEmpty;

  print('   - Authorization Token: ${messageToken?.substring(0, 20)}...');
  print('   - Has Token: $messageHasToken\n');

  // ---------------------------------------------------------------------------
  // Example 2: Creating an empty/anonymous settings request
  // ---------------------------------------------------------------------------
  print('2. Creating an empty/anonymous settings request:');

  final anonymousMessage = TomGetSettingsMessage();

  final anonymousToken = anonymousMessage.authorizationToken;
  final isAnonymous = anonymousMessage.authorizationToken == null ||
      anonymousMessage.authorizationToken!.isEmpty;

  print('   - Authorization Token: "$anonymousToken"');
  print('   - Is Anonymous Request: $isAnonymous\n');

  // ---------------------------------------------------------------------------
  // Example 3: Creating a basic settings result
  // ---------------------------------------------------------------------------
  print('3. Creating a basic settings result:');

  final basicResult = TomGetSettingsResult();

  final basicTextsCount = basicResult.texts.length;
  final basicConfigCount = basicResult.config.length;
  final basicRolesCount = basicResult.roles.length;

  print('   - Texts count: $basicTextsCount');
  print('   - Config count: $basicConfigCount');
  print('   - Roles count: $basicRolesCount');
  print('   - All collections default to empty\n');

  // ---------------------------------------------------------------------------
  // Example 4: Creating a fully populated settings result
  // ---------------------------------------------------------------------------
  print('4. Creating a fully populated settings result:');

  final result = TomGetSettingsResult(
    texts: {
      'welcome': 'Welcome to the Application',
      'logout': 'Sign Out',
      'profile': 'My Profile',
      'settings': 'Settings',
      'error.network': 'Network connection failed',
      'error.auth': 'Authentication required',
    },
    config: {
      'theme': 'dark',
      'maxItemsPerPage': 50,
      'enableNotifications': true,
      'apiTimeout': 30000,
      'features': {
        'dashboard': true,
        'reports': true,
        'analytics': false,
      },
    },
    roles: ['admin', 'editor', 'viewer'],
    groups: ['engineering', 'platform-team', 'all-employees'],
    entitlements: [
      'feature.dashboard.view',
      'feature.dashboard.edit',
      'feature.reports.view',
      'feature.reports.export',
      'admin.users.view',
    ],
    resourceKeys: ['dashboard', 'reports', 'user-management'],
    organization: 'acme-corp',
    process: 'main',
    application: 'admin-portal',
    country: 'US',
    language: 'en',
    clientCountry: 'US',
    clientLanguage: 'en',
    clientTimeZone: 'America/New_York',
  );

  final textsCount = result.texts.length;
  final configCount = result.config.length;
  final rolesCount = result.roles.length;
  final groupsCount = result.groups.length;
  final entitlementsCount = result.entitlements.length;
  final resourceKeysCount = result.resourceKeys.length;

  print('   - Texts: $textsCount entries');
  print('   - Config: $configCount entries');
  print('   - Roles: $rolesCount entries');
  print('   - Groups: $groupsCount entries');
  print('   - Entitlements: $entitlementsCount entries');
  print('   - Resource Keys: $resourceKeysCount entries\n');

  // ---------------------------------------------------------------------------
  // Example 5: Accessing text resources
  // ---------------------------------------------------------------------------
  print('5. Accessing text resources:');

  final welcomeText = result.texts['welcome'];
  final logoutText = result.texts['logout'];
  final networkErrorText = result.texts['error.network'];
  final missingText = result.texts['nonexistent'];

  print('   - Welcome: $welcomeText');
  print('   - Logout: $logoutText');
  print('   - Network Error: $networkErrorText');
  print('   - Missing Key: $missingText (null for missing keys)\n');

  // ---------------------------------------------------------------------------
  // Example 6: Accessing configuration values
  // ---------------------------------------------------------------------------
  print('6. Accessing configuration values:');

  final theme = result.config['theme'];
  final maxItems = result.config['maxItemsPerPage'];
  final notifications = result.config['enableNotifications'];
  final apiTimeout = result.config['apiTimeout'];
  final features = result.config['features'] as Map<String, dynamic>?;
  final dashboardEnabled = features?['dashboard'];

  print('   - Theme: $theme');
  print('   - Max Items Per Page: $maxItems');
  print('   - Notifications Enabled: $notifications');
  print('   - API Timeout: ${apiTimeout}ms');
  print('   - Dashboard Feature Enabled: $dashboardEnabled\n');

  // ---------------------------------------------------------------------------
  // Example 7: Checking authorization roles
  // ---------------------------------------------------------------------------
  print('7. Checking authorization roles:');

  final hasAdminRole = result.roles.contains('admin');
  final hasEditorRole = result.roles.contains('editor');
  final hasSuperRole = result.roles.contains('super-admin');
  final allRoles = result.roles.join(', ');

  print('   - Has Admin Role: $hasAdminRole');
  print('   - Has Editor Role: $hasEditorRole');
  print('   - Has Super-Admin Role: $hasSuperRole');
  print('   - All Roles: $allRoles\n');

  // ---------------------------------------------------------------------------
  // Example 8: Checking group membership
  // ---------------------------------------------------------------------------
  print('8. Checking group membership:');

  final inEngineering = result.groups.contains('engineering');
  final inHR = result.groups.contains('hr');
  final allGroups = result.groups.join(', ');

  print('   - In Engineering Group: $inEngineering');
  print('   - In HR Group: $inHR');
  print('   - All Groups: $allGroups\n');

  // ---------------------------------------------------------------------------
  // Example 9: Checking entitlements (fine-grained permissions)
  // ---------------------------------------------------------------------------
  print('9. Checking entitlements (fine-grained permissions):');

  final canViewDashboard = result.entitlements.contains('feature.dashboard.view');
  final canEditDashboard = result.entitlements.contains('feature.dashboard.edit');
  final canDeleteUsers = result.entitlements.contains('admin.users.delete');
  final canExportReports = result.entitlements.contains('feature.reports.export');

  print('   - Can View Dashboard: $canViewDashboard');
  print('   - Can Edit Dashboard: $canEditDashboard');
  print('   - Can Delete Users: $canDeleteUsers');
  print('   - Can Export Reports: $canExportReports\n');

  // ---------------------------------------------------------------------------
  // Example 10: Checking resource access
  // ---------------------------------------------------------------------------
  print('10. Checking resource access:');

  final hasDashboardAccess = result.resourceKeys.contains('dashboard');
  final hasReportsAccess = result.resourceKeys.contains('reports');
  final hasFinanceAccess = result.resourceKeys.contains('finance');
  final allResourceKeys = result.resourceKeys.join(', ');

  print('   - Dashboard Access: $hasDashboardAccess');
  print('   - Reports Access: $hasReportsAccess');
  print('   - Finance Access: $hasFinanceAccess');
  print('   - All Resource Keys: $allResourceKeys\n');

  // ---------------------------------------------------------------------------
  // Example 11: Accessing application context
  // ---------------------------------------------------------------------------
  print('11. Accessing application context:');

  final organization = result.organization;
  final process = result.process;
  final application = result.application;

  print('   - Organization: $organization');
  print('   - Process: $process');
  print('   - Application: $application\n');

  // ---------------------------------------------------------------------------
  // Example 12: Accessing localization settings
  // ---------------------------------------------------------------------------
  print('12. Accessing localization settings:');

  final serverCountry = result.country;
  final serverLanguage = result.language;
  final clientCountry = result.clientCountry;
  final clientLanguage = result.clientLanguage;
  final clientTimeZone = result.clientTimeZone;

  print('   - Server Country: $serverCountry');
  print('   - Server Language: $serverLanguage');
  print('   - Client Country: $clientCountry');
  print('   - Client Language: $clientLanguage');
  print('   - Client TimeZone: $clientTimeZone\n');

  // ---------------------------------------------------------------------------
  // Example 13: Creating settings for different locales
  // ---------------------------------------------------------------------------
  print('13. Creating settings for different locales:');

  final germanResult = TomGetSettingsResult(
    texts: {
      'welcome': 'Willkommen in der Anwendung',
      'logout': 'Abmelden',
      'settings': 'Einstellungen',
    },
    config: {'dateFormat': 'dd.MM.yyyy', 'numberFormat': 'de-DE'},
    roles: ['user'],
    groups: ['employees'],
    entitlements: ['feature.dashboard.view'],
    resourceKeys: ['dashboard'],
    country: 'DE',
    language: 'de',
    clientCountry: 'DE',
    clientLanguage: 'de',
    clientTimeZone: 'Europe/Berlin',
  );

  final germanWelcome = germanResult.texts['welcome'];
  final germanDateFormat = germanResult.config['dateFormat'];
  final germanTimezone = germanResult.clientTimeZone;

  print('   - German Welcome: $germanWelcome');
  print('   - German Date Format: $germanDateFormat');
  print('   - German Timezone: $germanTimezone\n');

  // ---------------------------------------------------------------------------
  // Example 14: Authorization check patterns
  // ---------------------------------------------------------------------------
  print('14. Authorization check patterns:');

  // Pattern 1: Role-based check
  final isAdmin = result.roles.contains('admin');

  // Pattern 2: Any of multiple roles
  final canManage = result.roles.any(
    (role) => ['admin', 'manager', 'supervisor'].contains(role),
  );

  // Pattern 3: Entitlement prefix check
  final dashboardEntitlements = result.entitlements
      .where((e) => e.startsWith('feature.dashboard.'))
      .toList();

  // Pattern 4: Combined check (role AND entitlement)
  final canAdminDashboard =
      result.roles.contains('admin') &&
      result.entitlements.contains('feature.dashboard.edit');

  print('   - Is Admin: $isAdmin');
  print('   - Can Manage (any role): $canManage');
  print('   - Dashboard Entitlements: $dashboardEntitlements');
  print('   - Can Admin Dashboard: $canAdminDashboard\n');

  // ---------------------------------------------------------------------------
  // Example 15: Working with nested config
  // ---------------------------------------------------------------------------
  print('15. Working with nested config:');

  final nestedResult = TomGetSettingsResult(
    texts: const {},
    config: {
      'ui': {
        'theme': 'dark',
        'sidebar': {'collapsed': false, 'width': 250},
        'toolbar': {'visible': true, 'position': 'top'},
      },
      'api': {
        'baseUrl': 'https://api.example.com',
        'timeout': 30000,
        'retries': 3,
      },
      'features': ['dashboard', 'reports', 'analytics'],
    },
    roles: const [],
    groups: const [],
    entitlements: const [],
    resourceKeys: const [],
  );

  final uiConfig = nestedResult.config['ui'] as Map<String, dynamic>?;
  final uiTheme = uiConfig?['theme'];
  final sidebarConfig = uiConfig?['sidebar'] as Map<String, dynamic>?;
  final sidebarWidth = sidebarConfig?['width'];
  final apiConfig = nestedResult.config['api'] as Map<String, dynamic>?;
  final apiBaseUrl = apiConfig?['baseUrl'];
  final featuresList = nestedResult.config['features'] as List?;
  final featuresCount = featuresList?.length ?? 0;

  print('   - UI Theme: $uiTheme');
  print('   - Sidebar Width: $sidebarWidth');
  print('   - API Base URL: $apiBaseUrl');
  print('   - Features Count: $featuresCount\n');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Creating a settings request message
  assert(messageToken == 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz');
  assert(messageHasToken == true);

  // Example 2: Creating an empty/anonymous settings request
  assert(anonymousToken == '');
  assert(isAnonymous == true);

  // Example 3: Creating a basic settings result
  assert(basicTextsCount == 0);
  assert(basicConfigCount == 0);
  assert(basicRolesCount == 0);

  // Example 4: Creating a fully populated settings result
  assert(textsCount == 6);
  assert(configCount == 5);
  assert(rolesCount == 3);
  assert(groupsCount == 3);
  assert(entitlementsCount == 5);
  assert(resourceKeysCount == 3);

  // Example 5: Accessing text resources
  assert(welcomeText == 'Welcome to the Application');
  assert(logoutText == 'Sign Out');
  assert(networkErrorText == 'Network connection failed');
  assert(missingText == null);

  // Example 6: Accessing configuration values
  assert(theme == 'dark');
  assert(maxItems == 50);
  assert(notifications == true);
  assert(apiTimeout == 30000);
  assert(dashboardEnabled == true);

  // Example 7: Checking authorization roles
  assert(hasAdminRole == true);
  assert(hasEditorRole == true);
  assert(hasSuperRole == false);
  assert(allRoles == 'admin, editor, viewer');

  // Example 8: Checking group membership
  assert(inEngineering == true);
  assert(inHR == false);
  assert(allGroups == 'engineering, platform-team, all-employees');

  // Example 9: Checking entitlements
  assert(canViewDashboard == true);
  assert(canEditDashboard == true);
  assert(canDeleteUsers == false);
  assert(canExportReports == true);

  // Example 10: Checking resource access
  assert(hasDashboardAccess == true);
  assert(hasReportsAccess == true);
  assert(hasFinanceAccess == false);
  assert(allResourceKeys == 'dashboard, reports, user-management');

  // Example 11: Accessing application context
  assert(organization == 'acme-corp');
  assert(process == 'main');
  assert(application == 'admin-portal');

  // Example 12: Accessing localization settings
  assert(serverCountry == 'US');
  assert(serverLanguage == 'en');
  assert(clientCountry == 'US');
  assert(clientLanguage == 'en');
  assert(clientTimeZone == 'America/New_York');

  // Example 13: Creating settings for different locales
  assert(germanWelcome == 'Willkommen in der Anwendung');
  assert(germanDateFormat == 'dd.MM.yyyy');
  assert(germanTimezone == 'Europe/Berlin');

  // Example 14: Authorization check patterns
  assert(isAdmin == true);
  assert(canManage == true);
  assert(dashboardEntitlements.length == 2);
  assert(canAdminDashboard == true);

  // Example 15: Working with nested config
  assert(uiTheme == 'dark');
  assert(sidebarWidth == 250);
  assert(apiBaseUrl == 'https://api.example.com');
  assert(featuresCount == 3);
}
