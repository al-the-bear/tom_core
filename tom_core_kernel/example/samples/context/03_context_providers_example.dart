/// Demonstrates TomContextProviders and the default tomExecutionContext.
///
/// This example shows how to use the built-in context providers that extract
/// values from the current zone's TomPrincipal.
///
/// Values are read the way the module intends: `getEntry<T>(name)?.value` on a
/// context you hold, and [TomExecutionContext.getValueFromCurrentZone] once you
/// are inside a `runInContext` body. Direct `contextMap` access appears only
/// where the map itself is the subject — entry counts and key listings.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Using TomContextProviders without a principal (defaults)
// =============================================================================

class DefaultProvidersExample {
  static String? defaultOrg;
  static String? defaultApp;
  static String? defaultProcess;
  static String? defaultLang;
  static String? defaultCountry;
  static String? defaultTimezone;
  static String? defaultClientLang;
  static String? defaultClientCountry;
  static String? defaultClientTimezone;

  static void example1DefaultProviders() {
    print('1. TomContextProviders without a principal (defaults):');

    defaultOrg = TomContextProviders.getOrganization();
    defaultApp = TomContextProviders.getApplication();
    defaultProcess = TomContextProviders.getProcess();
    defaultLang = TomContextProviders.getLanguage();
    defaultCountry = TomContextProviders.getCountry();
    defaultTimezone = TomContextProviders.getTimezone();
    defaultClientLang = TomContextProviders.getClientLanguage();
    defaultClientCountry = TomContextProviders.getClientCountry();
    defaultClientTimezone = TomContextProviders.getClientTimezone();

    print('   - organization: $defaultOrg');
    print('   - application: $defaultApp');
    print('   - process: $defaultProcess');
    print('   - server locale: $defaultLang / $defaultCountry / '
        '$defaultTimezone');
    print('   - client locale: $defaultClientLang / $defaultClientCountry / '
        '$defaultClientTimezone');

    assert(defaultOrg == 'default', 'Default organization should be "default"');
    assert(defaultApp == 'default', 'Default application should be "default"');
    assert(
      defaultProcess == 'default',
      'Default process should be "default"',
    );
    assert(defaultLang == 'en', 'Default language should be "en"');
    assert(defaultCountry == 'XX', 'Default country should be "XX"');
    assert(defaultTimezone == 'utc', 'Default timezone should be "utc"');

    // With no principal in the zone the client-side providers fall back to the
    // same defaults as their server-side counterparts.
    assert(defaultClientLang == 'en', 'Default client language should be "en"');
    assert(
      defaultClientCountry == 'XX',
      'Default client country should be "XX"',
    );
    assert(
      defaultClientTimezone == 'utc',
      'Default client timezone should be "utc"',
    );
  }
}

// =============================================================================
// EXAMPLE 2: Using TomContextProviders with a principal
// =============================================================================

class PrincipalProvidersExample {
  static String? principalOrg;
  static String? principalApp;
  static String? principalLang;
  static String? principalCountry;
  static String? principalTimezone;

  static void example2PrincipalProviders() {
    print('\n2. TomContextProviders with a TomPrincipal in the zone:');

    final principal = TomPrincipal(
      organization: 'acme-corp',
      application: 'billing-app',
      process: 'invoice-processor',
      language: 'de',
      country: 'DE',
      timezone: 'Europe/Berlin',
      clientLanguage: 'en',
      clientCountry: 'US',
      clientTimezone: 'America/New_York',
    );

    // Run with principal in zone
    runZoned(() {
      principalOrg = TomContextProviders.getOrganization();
      principalApp = TomContextProviders.getApplication();
      principalLang = TomContextProviders.getLanguage();
      principalCountry = TomContextProviders.getCountry();
      principalTimezone = TomContextProviders.getTimezone();
    }, zoneValues: {TomPrincipal: principal});

    print('   - organization: $principalOrg');
    print('   - application: $principalApp');
    print('   - language: $principalLang');
    print('   - country: $principalCountry');
    print('   - timezone: $principalTimezone');

    assert(principalOrg == 'acme-corp', 'Principal org should be acme-corp');
    assert(principalApp == 'billing-app', 'Principal app should be billing-app');
    assert(principalLang == 'de', 'Principal language should be de');
    assert(principalCountry == 'DE', 'Principal country should be DE');
    assert(
      principalTimezone == 'Europe/Berlin',
      'Principal timezone should be Europe/Berlin',
    );
  }
}

// =============================================================================
// EXAMPLE 3: Client-side context values from principal
// =============================================================================

class ClientContextExample {
  static String? clientLang;
  static String? clientCountry;
  static String? clientTimezone;
  static String? serverLang;

  static void example3ClientContextValues() {
    print('\n3. Server-side and client-side values are tracked separately:');

    final principal = TomPrincipal(
      organization: 'org',
      application: 'app',
      process: 'proc',
      language: 'de',
      country: 'DE',
      timezone: 'Europe/Berlin',
      clientLanguage: 'fr',
      clientCountry: 'FR',
      clientTimezone: 'Europe/Paris',
    );

    runZoned(() {
      serverLang = TomContextProviders.getLanguage();
      clientLang = TomContextProviders.getClientLanguage();
      clientCountry = TomContextProviders.getClientCountry();
      clientTimezone = TomContextProviders.getClientTimezone();
    }, zoneValues: {TomPrincipal: principal});

    print('   - server language: $serverLang');
    print('   - client language: $clientLang');
    print('   - client country: $clientCountry');
    print('   - client timezone: $clientTimezone');

    // Server and client values are different
    assert(serverLang == 'de', 'Server language should be de');
    assert(clientLang == 'fr', 'Client language should be fr');
    assert(clientCountry == 'FR', 'Client country should be FR');
    assert(clientTimezone == 'Europe/Paris', 'Client timezone should be Paris');
  }
}

// =============================================================================
// EXAMPLE 4: Using the default tomExecutionContext
// =============================================================================

class DefaultExecutionContextExample {
  static List<String> contextEntries = [];
  static String? orgValue;
  static bool hasOrganization = false;
  static bool hasApplication = false;
  static bool hasClientLanguage = false;

  static void example4DefaultExecutionContext() {
    print('\n4. The pre-configured tomExecutionContext:');

    // The tomExecutionContext has all providers pre-configured. Listing the
    // registered names and their declared types is a question about the map
    // itself, so it reads the map.
    contextEntries = tomExecutionContext.contextMap.keys.toList();

    hasOrganization = contextEntries.contains('organization');
    hasApplication = contextEntries.contains('application');
    hasClientLanguage = contextEntries.contains('clientLanguage');

    // The value of one entry is a typed read.
    orgValue = tomExecutionContext.getEntry<String>('organization')?.value;

    print('   - Registered entries (${contextEntries.length}):');
    tomExecutionContext.contextMap.forEach((name, entry) {
      print('     - $name: ${entry.type}');
    });
    print('   - Every entry is declared TomContextEntry<String>, which is what '
        'makes getEntry<String> find them');
    print('   - organization value (no principal in zone): $orgValue');

    assert(hasOrganization, 'Should have organization entry');
    assert(hasApplication, 'Should have application entry');
    assert(hasClientLanguage, 'Should have clientLanguage entry');
    assert(orgValue == 'default', 'Default org value should be "default"');
  }
}

// =============================================================================
// EXAMPLE 5: Running with tomExecutionContext and principal
// =============================================================================

class ContextWithPrincipalExample {
  static String? ctxOrg;
  static String? ctxApp;
  static String? ctxClientLang;
  static bool contextRetrieved = false;

  static void example5ContextWithPrincipal() {
    print('\n5. tomExecutionContext resolving against a principal:');

    final principal = TomPrincipal(
      organization: 'acme-corp',
      application: 'billing-app',
      process: 'invoice-processor',
      language: 'de',
      country: 'DE',
      timezone: 'Europe/Berlin',
      clientLanguage: 'en',
      clientCountry: 'US',
      clientTimezone: 'America/New_York',
    );

    // First set up the principal in zone, then run with context
    runZoned(() {
      tomExecutionContext.runInContext(() {
        contextRetrieved = true;
        ctxOrg =
            TomExecutionContext.getValueFromCurrentZone<String>('organization');
        ctxApp =
            TomExecutionContext.getValueFromCurrentZone<String>('application');
        ctxClientLang = TomExecutionContext.getValueFromCurrentZone<String>(
          'clientLanguage',
        );
      });
    }, zoneValues: {TomPrincipal: principal});

    print('   - organization: $ctxOrg');
    print('   - application: $ctxApp');
    print('   - clientLanguage: $ctxClientLang');
    print('   - The entries are lazy, so they resolve against whichever '
        'principal is in the zone at read time');

    assert(contextRetrieved, 'Context should have been retrieved');
    assert(ctxOrg == 'acme-corp', 'Context org should match principal');
    assert(ctxApp == 'billing-app', 'Context app should match principal');
    assert(ctxClientLang == 'en', 'Context client language should match');
  }
}

// =============================================================================
// EXAMPLE 6: TomZoneValues helper
// =============================================================================

class ZoneValuesHelperExample {
  static String? key1Val;
  static int? key2Val;
  static bool? key3Val;
  static int initialSize = 0;
  static int afterAddSize = 0;

  static void example6ZoneValuesHelper() {
    print('\n6. The TomZoneValues container:');

    final zoneVals = TomZoneValues({'key1': 'value1', 'key2': 42});
    initialSize = zoneVals.zoneValues.length;

    // Zone values are untyped (Object? keys and values), so a cast is part of
    // the API here — unlike a context entry, which carries its own type.
    key1Val = zoneVals['key1'] as String?;
    key2Val = zoneVals['key2'] as int?;

    // Write values
    zoneVals['key3'] = true;
    key3Val = zoneVals['key3'] as bool?;
    afterAddSize = zoneVals.zoneValues.length;

    print('   - Initial size: $initialSize');
    print('   - key1: $key1Val');
    print('   - key2: $key2Val');
    print('   - Added key3: $key3Val');
    print('   - Size after add: $afterAddSize');

    assert(initialSize == 2, 'Initial size should be 2');
    assert(key1Val == 'value1', 'key1 should be value1');
    assert(key2Val == 42, 'key2 should be 42');
    assert(key3Val == true, 'key3 should be true');
    assert(afterAddSize == 3, 'Size after add should be 3');
  }
}

// =============================================================================
// EXAMPLE 7: TomPrincipal creation and properties
// =============================================================================

class PrincipalCreationExample {
  static String? org;
  static String? app;
  static String? process;
  static String? lang;
  static String? country;
  static String? timezone;
  static String? clientLang;
  static String? clientCountry;
  static String? clientTimezone;

  static void example7PrincipalCreation() {
    print('\n7. TomPrincipal properties:');

    final principal = TomPrincipal(
      organization: 'test-org',
      application: 'test-app',
      process: 'test-process',
      language: 'ja',
      country: 'JP',
      timezone: 'Asia/Tokyo',
      clientLanguage: 'ko',
      clientCountry: 'KR',
      clientTimezone: 'Asia/Seoul',
    );

    org = principal.organization;
    app = principal.application;
    process = principal.process;
    lang = principal.language;
    country = principal.country;
    timezone = principal.timezone;
    clientLang = principal.clientLanguage;
    clientCountry = principal.clientCountry;
    clientTimezone = principal.clientTimezone;

    print('   - organization: $org');
    print('   - application: $app');
    print('   - process: $process');
    print('   - server locale: $lang / $country / $timezone');
    print('   - client locale: $clientLang / $clientCountry / $clientTimezone');

    assert(org == 'test-org', 'Organization should match');
    assert(app == 'test-app', 'Application should match');
    assert(process == 'test-process', 'Process should match');
    assert(lang == 'ja', 'Language should match');
    assert(country == 'JP', 'Country should match');
    assert(timezone == 'Asia/Tokyo', 'Timezone should match');
    assert(clientLang == 'ko', 'Client language should match');
    assert(clientCountry == 'KR', 'Client country should match');
    assert(clientTimezone == 'Asia/Seoul', 'Client timezone should match');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  DefaultProvidersExample.example1DefaultProviders();
  PrincipalProvidersExample.example2PrincipalProviders();
  ClientContextExample.example3ClientContextValues();
  DefaultExecutionContextExample.example4DefaultExecutionContext();
  ContextWithPrincipalExample.example5ContextWithPrincipal();
  ZoneValuesHelperExample.example6ZoneValuesHelper();
  PrincipalCreationExample.example7PrincipalCreation();
  print('');
}

void main() => run();
