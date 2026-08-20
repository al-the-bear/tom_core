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
      timezone: 'UTC',
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
// EXAMPLE 9: Building the Endpoint That Carries the Exchange
// =============================================================================

/// The settings module declares the two DTOs and no transport of its own — the
/// exchange runs over `TomServerEndpoint` from the `http_connection` module.
/// Settings is an ordinary bearer-authenticated endpoint of the API server, not
/// part of the authentication exchange, so it addresses the API base URI.
///
/// Constructing an endpoint opens no connection; the channel creates its HTTP
/// client on the first call. That is why this example can build one and assert
/// its shape without a server: only `send` reaches the network.
class SettingsEndpointExample {
  static String? method;
  static Uri? url;
  static bool sendsBearerToken = false;

  static void example9BuildEndpoint() {
    final endpoint =
        TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult>(
          TomServerChannel('api.example.com', 443),
          TomServerCallSpecs(
            'POST',
            Uri.parse('https://api.example.com/settings'),
            includeBearerAuthentication: true,
          ),
        );

    method = endpoint.specs.method;
    url = endpoint.specs.url;
    sendsBearerToken = endpoint.specs.includeBearerAuthentication;

    assert(method == 'POST', 'Settings is posted');
    assert(
      url.toString() == 'https://api.example.com/settings',
      'Endpoint addresses the API base URI',
    );
    assert(sendsBearerToken, 'Settings is a bearer-authenticated endpoint');

    // Sending it answers a (result, error) pair rather than throwing, so a
    // caller checks the error half before reading the result:
    //
    //   final (result, error) = await endpoint.send(message);
    //   if (error?.hasError ?? false) return;
    //
    // A live round trip needs a server, so it is exercised in the module's
    // tests against a stubbed client rather than here.
  }
}

// =============================================================================
// EXAMPLE 10: Reading Localization as Server/Client Pairs
// =============================================================================

/// Each of the three localization concepts is carried as a pair: the server
/// field states what the server decided, the client field what the client
/// asked for. A consumer resolves the effective value with `server ?? client`,
/// and compares the two when it needs to know it was overridden.
///
/// A `null` server field means the server expressed no opinion — not that it
/// agreed with the client. That is why the fallback and the override check are
/// two different expressions and not one.
class LocalizationPairsExample {
  static String? effectiveCountry;
  static String? effectiveLanguage;
  static String? effectiveTimeZone;
  static bool timeZoneOverridden = false;
  static bool languageOverridden = false;

  static void example10LocalizationPairs() {
    // The client asked for Berlin time and German; the server pinned the
    // session to UTC but let the language request stand.
    final result = TomGetSettingsResult(
      country: 'DE',
      timezone: 'UTC',
      clientCountry: 'DE',
      clientLanguage: 'de',
      clientTimeZone: 'Europe/Berlin',
    );

    effectiveCountry = result.country ?? result.clientCountry;
    effectiveLanguage = result.language ?? result.clientLanguage;
    effectiveTimeZone = result.timezone ?? result.clientTimeZone;

    timeZoneOverridden =
        result.timezone != null && result.timezone != result.clientTimeZone;
    languageOverridden =
        result.language != null && result.language != result.clientLanguage;

    assert(effectiveCountry == 'DE', 'Server and client agree on the country');
    assert(effectiveLanguage == 'de', 'Server was silent, so the client wins');
    assert(effectiveTimeZone == 'UTC', 'Server pinned the zone, so it wins');

    assert(timeZoneOverridden, 'The server decided against the client zone');
    assert(!languageOverridden, 'Silence is not an override');
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
  SettingsEndpointExample.example9BuildEndpoint();
  LocalizationPairsExample.example10LocalizationPairs();
}

void main() {
  requireAsserts();
  run();
}
