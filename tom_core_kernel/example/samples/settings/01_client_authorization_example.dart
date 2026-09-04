/// Demonstrates TomGetSettingsMessage and TomGetSettingsResult usage.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/settings/01_client_authorization_example.dart
/// ```
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// Both settings DTOs are `@tomReflector` classes, and EXAMPLE 13 round-trips
// one through the reflection helpers — so this sample needs the generated
// registry, not just the assert guard. `bootstrapSamples` calls
// `requireAsserts` itself; the two must not both be called.
import '../../sample_bootstrap.dart';

// =============================================================================
// EXAMPLE 1: Creating a Settings Request Message
// =============================================================================

class SettingsRequestExample {
  static String? messageToken;
  static bool hasToken = false;

  static void example1SettingsRequest() {
    final message = TomGetSettingsMessage()
      ..authorizationToken = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz';

    messageToken = message.authorizationToken;
    hasToken =
        message.authorizationToken != null &&
        message.authorizationToken!.isNotEmpty;

    assert(
      messageToken == 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz',
      'The message should carry back the token it was given',
    );
    assert(hasToken, 'Should have token');
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

/// What the server sends a signed-in user: every one of the fifteen fields
/// carrying a value, across all four groups the class declares — resources,
/// authorization, application context, and localization.
///
/// "Fully populated" is checked rather than taken on trust. The result is
/// serialized and the payload inspected for a `null`, so a sixteenth field
/// added to the class and forgotten here fails this example instead of
/// quietly making it a partial one again — which is how the four that this
/// sample never mentioned came to be missing in the first place.
///
/// The two groups that need more than a value to understand get their own
/// examples: the localization pairs in EXAMPLE 10, the context triple in
/// EXAMPLE 15.
class FullResultExample {
  static int textsCount = 0;
  static int configCount = 0;
  static int rolesCount = 0;
  static int groupsCount = 0;
  static int entitlementsCount = 0;
  static int fieldCount = 0;
  static List<String> unsetFields = const [];

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
      process: 'quarterly-close',
      application: 'admin-portal',
      country: 'US',
      language: 'en',
      timezone: 'UTC',
      clientCountry: 'DE',
      clientLanguage: 'de',
      clientTimezone: 'America/New_York',
    );

    textsCount = result.texts.length;
    configCount = result.config.length;
    rolesCount = result.roles.length;
    groupsCount = result.groups.length;
    entitlementsCount = result.entitlements.length;

    assert(textsCount == 3, 'Should have 3 texts');
    assert(configCount == 3, 'Should have 3 config entries');
    assert(rolesCount == 3, 'Should have 3 roles');
    assert(groupsCount == 2, 'Should have 2 groups');
    assert(entitlementsCount == 3, 'Should have 3 entitlements');

    // The completeness check. Serializing names every field, so nothing here
    // has to repeat the field list — the class stays the single source of it.
    final payload =
        jsonDecode(tomReflectionInfo.convertToJsonString(result))
            as Map<String, Object?>;

    fieldCount = payload.length;
    unsetFields =
        payload.entries
            .where((entry) => entry.value == null)
            .map((entry) => entry.key)
            .toList()
          ..sort();

    assert(fieldCount == 15, 'The result declares fifteen fields');
    assert(
      unsetFields.isEmpty,
      'A fully populated result leaves nothing unset, but these are: '
      '${unsetFields.join(', ')}',
    );
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
  static String? effectiveTimezone;
  static bool timezoneOverridden = false;
  static bool languageOverridden = false;

  static void example10LocalizationPairs() {
    // The client asked for Berlin time and German; the server pinned the
    // session to UTC but let the language request stand.
    final result = TomGetSettingsResult(
      country: 'DE',
      timezone: 'UTC',
      clientCountry: 'DE',
      clientLanguage: 'de',
      clientTimezone: 'Europe/Berlin',
    );

    effectiveCountry = result.country ?? result.clientCountry;
    effectiveLanguage = result.language ?? result.clientLanguage;
    effectiveTimezone = result.timezone ?? result.clientTimezone;

    timezoneOverridden =
        result.timezone != null && result.timezone != result.clientTimezone;
    languageOverridden =
        result.language != null && result.language != result.clientLanguage;

    assert(effectiveCountry == 'DE', 'Server and client agree on the country');
    assert(effectiveLanguage == 'de', 'Server was silent, so the client wins');
    assert(effectiveTimezone == 'UTC', 'Server pinned the zone, so it wins');

    assert(timezoneOverridden, 'The server decided against the client zone');
    assert(!languageOverridden, 'Silence is not an override');
  }
}

// =============================================================================
// EXAMPLE 11: Building a Result Incrementally
// =============================================================================

/// Every example above hands the constructor a finished result. A server
/// rarely has one: it discovers the user's roles from one source, their
/// entitlements from another, and the UI texts from a third. So the
/// default-constructed collections are *fresh mutable* instances — an empty
/// result is a starting point, not a frozen value.
///
/// This is the reason the defaults are written as literals rather than shared
/// `const` ones. A `const []` would be shared by every instance and would
/// throw on the first `add`, which is exactly what the incremental style
/// below does on its first line.
class IncrementalBuildExample {
  static int rolesCount = 0;
  static int entitlementsCount = 0;
  static String? theme;
  static String? welcome;
  static bool startedEmpty = false;

  static void example11IncrementalBuild() {
    final result = TomGetSettingsResult();

    startedEmpty =
        result.roles.isEmpty && result.config.isEmpty && result.texts.isEmpty;
    assert(startedEmpty, 'A default result starts out empty');

    // Authorization, resolved one source at a time.
    result.roles.add('admin');
    result.roles.add('editor');
    result.entitlements.add('feature.dashboard.view');
    result.groups.add('platform-team');
    result.resourceKeys.add('dashboard');

    // Configuration and texts, filled in by key.
    result.config['theme'] = 'dark';
    result.config['maxItemsPerPage'] = 50;
    result.texts['welcome'] = 'Welcome to the Application';

    rolesCount = result.roles.length;
    entitlementsCount = result.entitlements.length;
    theme = result.config['theme'] as String?;
    welcome = result.texts['welcome'] as String?;

    assert(rolesCount == 2, 'Both roles were appended');
    assert(entitlementsCount == 1, 'The entitlement was appended');
    assert(theme == 'dark', 'Config accepts assignment by key');
    assert(welcome == 'Welcome to the Application', 'So does texts');
  }
}

// =============================================================================
// EXAMPLE 12: Two Results Do Not Share State
// =============================================================================

/// The counterpart to EXAMPLE 11, and the half that is easy to get wrong.
/// Mutable defaults are only safe if each instance gets its *own* — a single
/// shared default would silently leak one request's roles into the next.
///
/// A server building one result per request depends on this: nothing resets
/// the collections between requests, so their independence is what keeps two
/// concurrent users from seeing each other's authorization.
class PerInstanceIsolationExample {
  static int firstRolesCount = 0;
  static int secondRolesCount = 0;
  static bool secondUnaffected = false;

  static void example12PerInstanceIsolation() {
    final first = TomGetSettingsResult();
    final second = TomGetSettingsResult();

    first.roles.add('admin');
    first.texts['welcome'] = 'Hello';

    firstRolesCount = first.roles.length;
    secondRolesCount = second.roles.length;
    secondUnaffected = second.roles.isEmpty && second.texts.isEmpty;

    assert(firstRolesCount == 1, 'The first result took the role');
    assert(secondRolesCount == 0, 'The second never saw it');
    assert(secondUnaffected, 'Neither collection is shared between instances');
  }
}

// =============================================================================
// EXAMPLE 13: The Reflected Round Trip
// =============================================================================

/// Both settings classes carry `@tomReflector`, and that is the whole reason
/// they are shaped the way they are — public fields, a no-argument
/// constructor, no computed state. They exist to cross the wire.
///
/// So the operation that matters is the round trip: serialize on the server,
/// deserialize on the client, and get an equal value back. The field
/// identifiers *are* the JSON keys, which is why renaming one is a wire
/// change rather than a refactor.
///
/// This needs the generated reflection registry, which is why this sample's
/// `main()` calls `bootstrapSamples()`.
class ReflectedRoundTripExample {
  static String? json;
  static int restoredRolesCount = 0;
  static String? restoredTheme;
  static String? restoredOrganization;
  static bool survivedRoundTrip = false;

  static void example13ReflectedRoundTrip() {
    final original = TomGetSettingsResult(
      texts: {'welcome': 'Welcome to the Application'},
      config: {'theme': 'dark', 'maxItemsPerPage': 50},
      roles: ['admin', 'editor'],
      entitlements: ['feature.dashboard.view'],
      organization: 'acme-corp',
      language: 'en',
      timezone: 'UTC',
    );

    json = tomReflectionInfo.convertToJsonString(original);

    final mirror =
        tomReflector.reflectType(TomGetSettingsResult) as ClassMirror;
    final restored = tomReflectionInfo
        .createInstanceFromJsonString<TomGetSettingsResult>(mirror, json!);

    restoredRolesCount = restored.roles.length;
    restoredTheme = restored.config['theme'] as String?;
    restoredOrganization = restored.organization;

    survivedRoundTrip =
        restoredRolesCount == 2 &&
        restoredTheme == 'dark' &&
        restoredOrganization == 'acme-corp' &&
        restored.timezone == 'UTC';

    assert(json!.isNotEmpty, 'Serialization produced a payload');
    assert(restoredRolesCount == 2, 'Roles survived the round trip');
    assert(restoredTheme == 'dark', 'Nested config values survived');
    assert(restoredOrganization == 'acme-corp', 'Scalars survived');
    assert(survivedRoundTrip, 'The value came back equal');
  }
}

// =============================================================================
// EXAMPLE 14: Unset Is Null, and Empty Is Not Unset
// =============================================================================

/// The string fields default to `null`, and that is a deliberate distinction
/// rather than an accident of Dart: `null` means *the server said nothing
/// about this*, and `''` means *the server set it to empty*. A client that
/// falls back to a default should do so only in the first case.
///
/// The distinction has to survive the wire for it to mean anything, so this
/// checks it after a round trip as well as on a fresh instance — with every
/// field populated, as in EXAMPLE 13, an unset default never shows.
class UnsetStringDefaultsExample {
  static String? organization;
  static String? clientLanguage;
  static bool allUnsetAreNull = false;
  static bool emptyIsNotNull = false;
  static bool nullSurvivesTheWire = false;

  static void example14UnsetStringDefaults() {
    final result = TomGetSettingsResult();

    organization = result.organization;
    clientLanguage = result.clientLanguage;

    allUnsetAreNull =
        result.organization == null &&
        result.process == null &&
        result.application == null &&
        result.country == null &&
        result.language == null &&
        result.timezone == null &&
        result.clientCountry == null &&
        result.clientLanguage == null &&
        result.clientTimezone == null;

    assert(organization == null, 'An unset organization reads back as null');
    assert(clientLanguage == null, 'So does an unset clientLanguage');
    assert(allUnsetAreNull, 'Every unset string field is null, not empty');

    // An empty string is a value the server chose, and is not the same answer.
    final deliberatelyEmpty = TomGetSettingsResult(organization: '');
    emptyIsNotNull =
        deliberatelyEmpty.organization != null &&
        deliberatelyEmpty.organization!.isEmpty;
    assert(emptyIsNotNull, '"" is set-to-empty, which is not unset');

    // Which is why a client tests for null rather than for emptiness:
    //
    //   final org = result.organization ?? defaultOrganization;
    //
    // `result.organization?.isEmpty ?? true` would collapse the two.

    // The guarantee is consumed on the deserialization path, so check it there
    // too — a client reads results the deserializer built, not ones it
    // constructed.
    final restoredJson = tomReflectionInfo.convertToJsonString(
      TomGetSettingsResult(),
    );
    final mirror =
        tomReflector.reflectType(TomGetSettingsResult) as ClassMirror;
    final restored = tomReflectionInfo
        .createInstanceFromJsonString<TomGetSettingsResult>(
          mirror,
          restoredJson,
        );

    nullSurvivesTheWire =
        restored.organization == null && restored.clientLanguage == null;
    assert(nullSurvivesTheWire, 'Unset stays unset across the wire');
  }
}

// =============================================================================
// EXAMPLE 15: The Application Context Triple
// =============================================================================

/// `organization`, `process` and `application` are not three more settings —
/// they are the *scope* of everything else in the result. The roles, the
/// entitlements, the texts and the config are what this user has **in this
/// organization, in this process, in this application**, and they are not
/// meaningful outside it.
///
/// That makes the triple part of a cached result's identity. Two results can
/// carry identical roles and be answers to different questions, so a client
/// that caches settings keys the cache on the triple; a client that reuses one
/// result after the user switches organization is showing stale authorization.
///
/// The request message carries none of the three — it carries only the bearer
/// token (EXAMPLE 1). The server derives the scope from the session and states
/// it back, which is why `organization` is documented as possibly differing
/// from the one that was asked for: the value in the result is the one that
/// was actually applied.
class ApplicationContextExample {
  static String? organization;
  static String? process;
  static String? application;
  static String? scopeKey;
  static bool sameRolesDifferentScope = false;
  static bool unscoped = false;

  static void example15ApplicationContext() {
    final result = TomGetSettingsResult(
      roles: ['approver'],
      organization: 'acme-corp',
      process: 'quarterly-close',
      application: 'admin-portal',
    );

    organization = result.organization;
    process = result.process;
    application = result.application;

    assert(organization == 'acme-corp', 'The organization owning the session');
    assert(process == 'quarterly-close', 'The workflow the user is inside');
    assert(application == 'admin-portal', 'The application being configured');

    // A cache key is the triple, not the user — this is the shape of it:
    scopeKey = '${result.organization}/${result.process}/${result.application}';
    assert(
      scopeKey == 'acme-corp/quarterly-close/admin-portal',
      'The three together identify the scope',
    );

    // Same user, same role, different process: approving a quarterly close is
    // not approving an onboarding, so this is a different answer and must not
    // reuse the one above.
    final otherProcess = TomGetSettingsResult(
      roles: ['approver'],
      organization: 'acme-corp',
      process: 'employee-onboarding',
      application: 'admin-portal',
    );

    sameRolesDifferentScope =
        otherProcess.roles.join() == result.roles.join() &&
        otherProcess.process != result.process;
    assert(sameRolesDifferentScope, 'Equal roles, different scope');

    // All three are nullable, and all three being absent is a legitimate
    // answer: a server that runs one application for one tenant has no scope
    // to narrow to, and says so by leaving them unset rather than inventing
    // placeholder values.
    final global = TomGetSettingsResult(roles: ['viewer']);
    unscoped =
        global.organization == null &&
        global.process == null &&
        global.application == null;
    assert(unscoped, 'An unscoped result leaves all three null');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 01: Client Authorization Example ===\n');

  SettingsRequestExample.example1SettingsRequest();
  print('1. The request carries nothing but the bearer token:');
  print('   authorizationToken : ${SettingsRequestExample.messageToken}');
  print('   token present      : ${SettingsRequestExample.hasToken}');
  print('');

  AnonymousRequestExample.example2AnonymousRequest();
  print('2. A request without a token asks for the anonymous settings:');
  print(
    '   authorizationToken  : '
    '"${AnonymousRequestExample.anonymousToken}" (the empty default)',
  );
  print('   treated as anonymous: ${AnonymousRequestExample.isAnonymous}');
  print('');

  BasicResultExample.example3BasicResult();
  print('3. A default result starts out empty rather than null:');
  print('   texts    : ${BasicResultExample.textsCount} entries');
  print('   config   : ${BasicResultExample.configCount} entries');
  print('   roles    : ${BasicResultExample.rolesCount} entries');
  print('   all empty: ${BasicResultExample.defaultsToEmpty}');
  print('');

  FullResultExample.example4FullResult();
  print('4. What the server sends a signed-in user, every field set:');
  print('   texts             : ${FullResultExample.textsCount}');
  print('   config            : ${FullResultExample.configCount}');
  print('   roles             : ${FullResultExample.rolesCount}');
  print('   groups            : ${FullResultExample.groupsCount}');
  print('   entitlements      : ${FullResultExample.entitlementsCount}');
  print('   fields on the wire: ${FullResultExample.fieldCount}');
  print('   left unset        : ${FullResultExample.unsetFields.length}');
  print('');

  AccessTextsExample.example5AccessTexts();
  print('5. Texts are read by key, and an absent key reads back null:');
  print('   welcome     : ${AccessTextsExample.welcomeText}');
  print('   logout      : ${AccessTextsExample.logoutText}');
  print('   nonexistent : ${AccessTextsExample.missingText}');
  print('');

  AccessConfigExample.example6AccessConfig();
  print('6. Config values keep their JSON types, so each is cast on read:');
  print('   theme              : ${AccessConfigExample.theme}');
  print('   maxItemsPerPage    : ${AccessConfigExample.maxItems}');
  print('   enableNotifications: ${AccessConfigExample.notifications}');
  print('');

  CheckRolesExample.example7CheckRoles();
  print(
    '7. Role membership, asked of a result carrying [admin, editor, '
    'viewer]:',
  );
  print('   admin       → ${CheckRolesExample.hasAdminRole}');
  print('   editor      → ${CheckRolesExample.hasEditorRole}');
  print('   super-admin → ${CheckRolesExample.hasSuperRole}');
  print('');

  CheckEntitlementsExample.example8CheckEntitlements();
  print('8. Entitlements answer the same question per feature:');
  print(
    '   feature.dashboard.view → '
    '${CheckEntitlementsExample.canViewDashboard}',
  );
  print(
    '   feature.dashboard.edit → '
    '${CheckEntitlementsExample.canEditDashboard}',
  );
  print(
    '   admin.users.delete     → '
    '${CheckEntitlementsExample.canDeleteUsers}',
  );
  print('');

  SettingsEndpointExample.example9BuildEndpoint();
  print('9. The endpoint that carries the exchange, built but not called:');
  print('   method       : ${SettingsEndpointExample.method}');
  print('   url          : ${SettingsEndpointExample.url}');
  print('   bearer token : ${SettingsEndpointExample.sendsBearerToken}');
  print('');

  LocalizationPairsExample.example10LocalizationPairs();
  print('10. Localization resolves as server ?? client:');
  print('   effective country  : ${LocalizationPairsExample.effectiveCountry}');
  print(
    '   effective language : ${LocalizationPairsExample.effectiveLanguage}',
  );
  print(
    '   effective timezone : ${LocalizationPairsExample.effectiveTimezone}',
  );
  print(
    '   timezone overridden by the server: '
    '${LocalizationPairsExample.timezoneOverridden}',
  );
  print(
    '   language overridden by the server: '
    '${LocalizationPairsExample.languageOverridden}',
  );
  print('');

  IncrementalBuildExample.example11IncrementalBuild();
  print('11. A server fills the result in from several sources:');
  print('   started empty : ${IncrementalBuildExample.startedEmpty}');
  print('   roles         : ${IncrementalBuildExample.rolesCount}');
  print('   entitlements  : ${IncrementalBuildExample.entitlementsCount}');
  print('   config[theme] : ${IncrementalBuildExample.theme}');
  print('   texts[welcome]: ${IncrementalBuildExample.welcome}');
  print('');

  PerInstanceIsolationExample.example12PerInstanceIsolation();
  print('12. Two results never share their collections:');
  print(
    '   roles on the first  : '
    '${PerInstanceIsolationExample.firstRolesCount}',
  );
  print(
    '   roles on the second : '
    '${PerInstanceIsolationExample.secondRolesCount}',
  );
  print(
    '   second untouched    : '
    '${PerInstanceIsolationExample.secondUnaffected}',
  );
  print('');

  ReflectedRoundTripExample.example13ReflectedRoundTrip();
  print('13. Serialize, deserialize, and get the same value back:');
  print(
    '   payload              : '
    '${ReflectedRoundTripExample.json!.substring(0, 48)}...',
  );
  print(
    '   restored roles       : '
    '${ReflectedRoundTripExample.restoredRolesCount}',
  );
  print('   restored theme       : ${ReflectedRoundTripExample.restoredTheme}');
  print(
    '   restored organization: '
    '${ReflectedRoundTripExample.restoredOrganization}',
  );
  print(
    '   survived the wire    : '
    '${ReflectedRoundTripExample.survivedRoundTrip}',
  );
  print('');

  UnsetStringDefaultsExample.example14UnsetStringDefaults();
  print('14. Unset is null, and empty is a value the server chose:');
  print('   organization  : ${UnsetStringDefaultsExample.organization}');
  print('   clientLanguage: ${UnsetStringDefaultsExample.clientLanguage}');
  print(
    '   all nine string fields unset are null: '
    '${UnsetStringDefaultsExample.allUnsetAreNull}',
  );
  print(
    '   "" is set-to-empty, not unset       : '
    '${UnsetStringDefaultsExample.emptyIsNotNull}',
  );
  print(
    '   null survives the round trip        : '
    '${UnsetStringDefaultsExample.nullSurvivesTheWire}',
  );
  print('');

  ApplicationContextExample.example15ApplicationContext();
  print('15. The context triple is the scope everything else is stated in:');
  print('   organization : ${ApplicationContextExample.organization}');
  print('   process      : ${ApplicationContextExample.process}');
  print('   application  : ${ApplicationContextExample.application}');
  print('   cache key    : ${ApplicationContextExample.scopeKey}');
  print(
    '   equal roles, different scope: '
    '${ApplicationContextExample.sameRolesDifferentScope}',
  );
  print(
    '   an unscoped result leaves all three null: '
    '${ApplicationContextExample.unscoped}',
  );
  print('');
}

void main() {
  bootstrapSamples();
  run();
}
