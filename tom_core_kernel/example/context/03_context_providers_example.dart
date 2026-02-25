/// Demonstrates TomContextProviders and the default tomExecutionContext.
///
/// This example shows how to use the built-in context providers that extract
/// values from the current zone's TomPrincipal.
library;

import 'dart:async';

import 'package:tom_core_kernel/src/tombase/context/execution_context.dart';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';
import 'package:tom_core_kernel/src/tombase/security/user_principal_aci.dart';

// =============================================================================
// Context Providers Example
// =============================================================================

void run() {
  print('=== 03: Context Providers Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Using TomContextProviders without a principal (defaults)
  // ---------------------------------------------------------------------------
  print('1. Context providers with defaults (no principal):');

  final defaultOrg = TomContextProviders.getOrganization();
  final defaultApp = TomContextProviders.getApplication();
  final defaultProcess = TomContextProviders.getProcess();
  final defaultLang = TomContextProviders.getLanguage();
  final defaultCountry = TomContextProviders.getCountry();
  final defaultTimezone = TomContextProviders.getTimezone();

  print('   - Organization: $defaultOrg (default)');
  print('   - Application: $defaultApp (default)');
  print('   - Process: $defaultProcess (default)');
  print('   - Language: $defaultLang (default)');
  print('   - Country: $defaultCountry (default)');
  print('   - Timezone: $defaultTimezone (default)\n');

  // ---------------------------------------------------------------------------
  // Example 2: Using TomContextProviders with a principal
  // ---------------------------------------------------------------------------
  print('2. Context providers with a TomPrincipal:');

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

  String? principalOrg;
  String? principalLang;
  String? clientLang;
  String? clientTz;

  // Run with principal in zone
  runZoned(() {
    principalOrg = TomContextProviders.getOrganization();
    principalLang = TomContextProviders.getLanguage();
    clientLang = TomContextProviders.getClientLanguage();
    clientTz = TomContextProviders.getClientTimezone();

    print('   - Organization: $principalOrg');
    print('   - Server Language: $principalLang');
    print('   - Client Language: $clientLang');
    print('   - Client Timezone: $clientTz');
  }, zoneValues: {TomPrincipal: principal});

  print('');

  // ---------------------------------------------------------------------------
  // Example 3: Using the default tomExecutionContext
  // ---------------------------------------------------------------------------
  print('3. Using the default tomExecutionContext:');

  // The tomExecutionContext has all providers pre-configured
  final contextEntries = tomExecutionContext.contextMap.keys.toList();
  print('   Available entries: ${contextEntries.join(", ")}');

  // Access organization entry from default context
  final orgEntry = tomExecutionContext.contextMap['organization'];
  final orgValue = orgEntry?.contextFunction();
  print('   - Organization from default context: $orgValue\n');

  // ---------------------------------------------------------------------------
  // Example 4: Running with tomExecutionContext and principal
  // ---------------------------------------------------------------------------
  print('4. Running with tomExecutionContext and principal:');

  String? ctxOrg;
  String? ctxApp;
  String? ctxClientLang;

  // First set up the principal in zone, then run with context
  runZoned(() {
    tomExecutionContext.runInContext(() {
      final ctx = getFromCurrentZone<TomExecutionContext>();
      ctxOrg = ctx?.contextMap['organization']?.contextFunction() as String?;
      ctxApp = ctx?.contextMap['application']?.contextFunction() as String?;
      ctxClientLang =
          ctx?.contextMap['clientLanguage']?.contextFunction() as String?;

      print('   - Organization: $ctxOrg');
      print('   - Application: $ctxApp');
      print('   - Client Language: $ctxClientLang');
    });
  }, zoneValues: {TomPrincipal: principal});

  print('');

  // ---------------------------------------------------------------------------
  // Example 5: TomZoneValues helper
  // ---------------------------------------------------------------------------
  print('5. TomZoneValues helper for zone value manipulation:');

  final zoneVals = TomZoneValues({'key1': 'value1', 'key2': 42});

  // Read values
  final key1Val = zoneVals['key1'];
  final key2Val = zoneVals['key2'];

  print('   - key1: $key1Val');
  print('   - key2: $key2Val');

  // Write values
  zoneVals['key3'] = true;
  final key3Val = zoneVals['key3'];
  print('   - key3 (added): $key3Val\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Default values
  assert(defaultOrg == 'default', 'Default organization should be "default"');
  assert(defaultApp == 'default', 'Default application should be "default"');
  assert(defaultLang == 'en', 'Default language should be "en"');
  assert(defaultCountry == 'XX', 'Default country should be "XX"');
  assert(defaultTimezone == 'utc', 'Default timezone should be "utc"');

  // Example 2: Principal values
  assert(principalOrg == 'acme-corp', 'Principal org should be acme-corp');
  assert(principalLang == 'de', 'Principal language should be de');
  assert(clientLang == 'en', 'Client language should be en');
  assert(clientTz == 'America/New_York', 'Client timezone should be America/New_York');

  // Example 3: Default context entries
  assert(contextEntries.contains('organization'), 'Should have organization');
  assert(contextEntries.contains('application'), 'Should have application');
  assert(contextEntries.contains('clientLanguage'), 'Should have clientLanguage');

  // Example 4: Context with principal
  assert(ctxOrg == 'acme-corp', 'Context org should match principal');
  assert(ctxApp == 'billing-app', 'Context app should match principal');
  assert(ctxClientLang == 'en', 'Context client language should match principal');

  // Example 5: TomZoneValues
  assert(key1Val == 'value1', 'key1 should be value1');
  assert(key2Val == 42, 'key2 should be 42');
  assert(key3Val == true, 'key3 should be true');
}
