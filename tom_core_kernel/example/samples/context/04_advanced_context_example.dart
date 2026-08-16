/// Advanced Execution Context Example
///
/// This example demonstrates advanced context features:
/// - runInContextAsync for async code
/// - TomZoneValues for zone-scoped state
/// - TomContextEntry operators
/// - TomContextProviders for principal-based values
/// - Parent context inheritance
/// - getValueFromCurrentZone helper
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Class
// ============================================================================

class AdvancedContextExample {
  // Captured results
  static String? asyncContextValue;
  static bool asyncExecuted = false;
  static Object? zoneValueResult;
  static bool zoneValuesWork = false;
  static String? entryValue;
  static bool operatorsWork = false;
  static String? staticValueResult;
  static bool parentInheritanceWorks = false;

  // --------------------------------------------------------------------------
  // Example 1: Async context execution with runInContextAsync
  // --------------------------------------------------------------------------
  static Future<void> example1RunInContextAsync() async {
    print('1. runInContextAsync for async code:');

    final context = TomExecutionContext({
      'requestId': TomContextEntry<String>(() => 'async-req-001'),
      'startTime': TomContextEntry<int>(() => DateTime.now().millisecondsSinceEpoch),
    });

    final result = await context.runInContextAsync(() async {
      asyncExecuted = true;

      // Simulate async work
      await Future.delayed(Duration(milliseconds: 10));

      // Context is still available after await
      asyncContextValue = TomExecutionContext.getValueFromCurrentZone<String>('requestId');

      return 'completed';
    });

    print('   - runInContextAsync executed: $asyncExecuted');
    print('   - Context value after await: $asyncContextValue');
    print('   - Return value: $result');

    // Assertions
    assert(asyncExecuted, 'Async should have executed');
    assert(asyncContextValue == 'async-req-001', 'Context should persist after await');
  }

  // --------------------------------------------------------------------------
  // Example 2: TomZoneValues for mutable zone state
  // --------------------------------------------------------------------------
  static void example2TomZoneValues() {
    print('\n2. TomZoneValues for mutable zone state:');

    final context = TomExecutionContext({});

    // Run with zone values
    context.runInContext(
      () {
        // Access zone values from the zone. This is the only read that reaches
        // them: the `zoneValues:` argument below is wrapped in this container
        // rather than installed as zone keys, so neither
        // TomExecutionContext.getValueFromCurrentZone (which resolves named
        // context entries) nor Zone.current['initialKey'] would find it.
        final zoneValues = getFromCurrentZone<TomZoneValues>();

        final passedIn = zoneValues?['initialKey'];
        print('   - Value passed as zoneValues: $passedIn');
        assert(passedIn == 'initialValue', 'zoneValues argument should arrive');
        assert(Zone.current['initialKey'] == null,
            'the key itself is not installed in the zone');

        // Modify zone values
        zoneValues?['counter'] = 0;
        zoneValues?['metadata'] = {'source': 'example'};

        // Read back
        final counter = zoneValues?['counter'];
        print('   - Initial counter: $counter');

        // Increment
        zoneValues?['counter'] = (counter as int) + 1;
        final updated = zoneValues?['counter'];
        print('   - Updated counter: $updated');

        zoneValuesWork = updated == 1;
      },
      zoneValues: {'initialKey': 'initialValue'},
    );

    print('   - TomZoneValues correctly maintains mutable state');

    // Assertions
    assert(zoneValuesWork, 'Zone values should be mutable');
  }

  // --------------------------------------------------------------------------
  // Example 3: TomZoneValues operations
  // --------------------------------------------------------------------------
  static void example3ZoneValueOperations() {
    print('\n3. TomZoneValues operations:');

    // Create independently for testing
    final zoneValues = TomZoneValues({'key1': 'value1', 'key2': 42});

    print('   - Created with initial values');
    print('   - key1: ${zoneValues['key1']}');
    print('   - key2: ${zoneValues['key2']}');

    // Test operations
    zoneValues['key3'] = true;
    print('   - Added key3: ${zoneValues['key3']}');

    final containsKey = zoneValues.containsKey('key1');
    print('   - containsKey("key1"): $containsKey');

    zoneValues.addAll({'key4': 'added', 'key5': 123});
    print('   - After addAll: key4=${zoneValues['key4']}, key5=${zoneValues['key5']}');

    final removed = zoneValues.remove('key1');
    print('   - Removed key1, value was: $removed');
    print('   - containsKey after remove: ${zoneValues.containsKey('key1')}');

    // Assertions
    assert(containsKey, 'Should contain key1');
    assert(removed == 'value1', 'Removed value should be value1');
  }

  // --------------------------------------------------------------------------
  // Example 4: TomContextEntry operators
  // --------------------------------------------------------------------------
  static void example4EntryOperators() {
    print('\n4. TomContextEntry operators:');

    final entry = TomContextEntry<String>(() => 'entry-value');

    // Different ways to get the value
    final viaValue = entry.value;
    final viaCall = entry();
    final viaOperator = ~entry;
    final viaFunction = entry.contextFunction();

    print('   - entry.value: $viaValue');
    print('   - entry(): $viaCall');
    print('   - ~entry: $viaOperator');
    print('   - entry.contextFunction(): $viaFunction');

    operatorsWork = viaValue == viaCall && viaCall == viaOperator && viaOperator == viaFunction;
    print('   - All methods return same value: $operatorsWork');

    // Check type
    print('   - entry.type: ${entry.type}');

    // Assertions
    assert(operatorsWork, 'All operators should return same value');
    assert(entry.type == String, 'Type should be String');
  }

  // --------------------------------------------------------------------------
  // Example 5: TomContextEntry with lazy evaluation
  // --------------------------------------------------------------------------
  static void example5LazyEvaluation() {
    print('\n5. TomContextEntry with lazy evaluation:');

    var callCount = 0;
    final lazyEntry = TomContextEntry<DateTime>(() {
      callCount++;
      return DateTime.now();
    });

    print('   - Call count before access: $callCount');

    final value1 = lazyEntry.value;
    print('   - First access: $value1');
    print('   - Call count after first: $callCount');

    final value2 = lazyEntry.value;
    print('   - Second access: $value2');
    print('   - Call count after second: $callCount');

    // Each access calls the function
    assert(callCount == 2, 'Function should be called on each access');
    print('   - Entry evaluates lazily on each access');
  }

  // --------------------------------------------------------------------------
  // Example 6: getValueFromCurrentZone helper
  // --------------------------------------------------------------------------
  static void example6GetValueHelper() {
    print('\n6. getValueFromCurrentZone helper:');

    final context = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-456'),
      'tenantId': TomContextEntry<int>(() => 12345),
    });

    context.runInContext(() {
      // Use the static helper method
      final userId = TomExecutionContext.getValueFromCurrentZone<String>('userId');
      final tenantId = TomExecutionContext.getValueFromCurrentZone<int>('tenantId');
      final missing = TomExecutionContext.getValueFromCurrentZone<String>('missing');

      print('   - userId: $userId');
      print('   - tenantId: $tenantId');
      print('   - missing: $missing');

      staticValueResult = userId;

      // Assertions inside zone
      assert(userId == 'user-456', 'Should get userId');
      assert(tenantId == 12345, 'Should get tenantId');
      assert(missing == null, 'Missing should be null');
    });
  }

  // --------------------------------------------------------------------------
  // Example 7: Parent context inheritance
  // --------------------------------------------------------------------------
  static void example7ParentContextInheritance() {
    print('\n7. Parent context inheritance:');

    // Create parent context
    final parentContext = TomExecutionContext({
      'organization': TomContextEntry<String>(() => 'acme-corp'),
      'environment': TomContextEntry<String>(() => 'production'),
    });

    // Run parent context
    parentContext.runInContext(() {
      print('   - In parent context');
      final org = TomExecutionContext.getValueFromCurrentZone<String>('organization');
      print('     organization: $org');

      // Create child context with additional entries
      final childContext = TomExecutionContext({
        'userId': TomContextEntry<String>(() => 'user-789'),
        'role': TomContextEntry<String>(() => 'admin'),
      });

      // Nested context run
      childContext.runInContext(() {
        print('   - In child context');

        // Child has its own entries
        final userId = TomExecutionContext.getValueFromCurrentZone<String>('userId');
        print('     userId: $userId');

        // Parent entries are also available (merged)
        final orgInChild = TomExecutionContext.getValueFromCurrentZone<String>('organization');
        print('     organization (from parent): $orgInChild');

        parentInheritanceWorks = userId == 'user-789' && orgInChild == 'acme-corp';
      });
    });

    // Assertions
    assert(parentInheritanceWorks, 'Parent context should be inherited');
  }

  // --------------------------------------------------------------------------
  // Example 8: TomContextProviders for principal-based values
  // --------------------------------------------------------------------------
  static void example8ContextProviders() {
    print('\n8. TomContextProviders for principal-based values:');

    // These provide defaults when no TomPrincipal is in the zone
    final org = TomContextProviders.getOrganization();
    final app = TomContextProviders.getApplication();
    final process = TomContextProviders.getProcess();
    final lang = TomContextProviders.getLanguage();
    final country = TomContextProviders.getCountry();
    final timezone = TomContextProviders.getTimezone();
    final clientLang = TomContextProviders.getClientLanguage();
    final clientCountry = TomContextProviders.getClientCountry();
    final clientTz = TomContextProviders.getClientTimezone();

    print('   Without TomPrincipal in zone (defaults):');
    print('   - organization: $org');
    print('   - application: $app');
    print('   - process: $process');
    print('   - language: $lang');
    print('   - country: $country');
    print('   - timezone: $timezone');
    print('   - clientLanguage: $clientLang');
    print('   - clientCountry: $clientCountry');
    print('   - clientTimezone: $clientTz');

    // Assertions for defaults
    assert(org == 'default', 'Default org should be "default"');
    assert(lang == 'en', 'Default language should be "en"');
  }

  // --------------------------------------------------------------------------
  // Example 9: Global tomExecutionContext
  // --------------------------------------------------------------------------
  static void example9GlobalContext() {
    print('\n9. Global tomExecutionContext:');

    print('   - tomExecutionContext is pre-configured with TomContextProviders');
    print('   - Available entries:');
    tomExecutionContext.contextMap.forEach((key, entry) {
      print('     - $key: ${entry.type}');
    });

    // Use it
    tomExecutionContext.runInContext(() {
      final org = tomExecutionContext.contextMap['organization']?.value;
      final lang = tomExecutionContext.contextMap['language']?.value;
      print('   - In global context: org=$org, lang=$lang');
    });
  }

  // --------------------------------------------------------------------------
  // Example 10: Context with explicit parent
  // --------------------------------------------------------------------------
  static void example10ExplicitParent() {
    print('\n10. Context with explicit parent parameter:');

    final parentCtx = TomExecutionContext({
      'base': TomContextEntry<String>(() => 'parent-value'),
    });

    // Create child with explicit parent
    final childCtx = TomExecutionContext(
      {'child': TomContextEntry<String>(() => 'child-value')},
      parentContext: parentCtx,
    );

    // Child should have both entries
    final baseEntry = childCtx.contextMap['base'];
    final childEntry = childCtx.contextMap['child'];

    print('   - Parent context has: base');
    print('   - Child created with parentContext parameter');
    print('   - Child context has:');
    print('     - base: ${baseEntry?.value}');
    print('     - child: ${childEntry?.value}');

    // Assertions
    assert(baseEntry?.value == 'parent-value', 'Should inherit from parent');
    assert(childEntry?.value == 'child-value', 'Should have own entry');
  }
}

// ============================================================================
// Run Function
// ============================================================================

Future<void> run() async {
  print('═══════════════════════════════════════════════════════════════════');
  print('ADVANCED EXECUTION CONTEXT EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  await AdvancedContextExample.example1RunInContextAsync();
  AdvancedContextExample.example2TomZoneValues();
  AdvancedContextExample.example3ZoneValueOperations();
  AdvancedContextExample.example4EntryOperators();
  AdvancedContextExample.example5LazyEvaluation();
  AdvancedContextExample.example6GetValueHelper();
  AdvancedContextExample.example7ParentContextInheritance();
  AdvancedContextExample.example8ContextProviders();
  AdvancedContextExample.example9GlobalContext();
  AdvancedContextExample.example10ExplicitParent();

  // Final assertions
  assert(AdvancedContextExample.asyncExecuted, 'Async should execute');
  assert(AdvancedContextExample.zoneValuesWork, 'Zone values should work');
  assert(AdvancedContextExample.operatorsWork, 'Operators should work');
  assert(AdvancedContextExample.parentInheritanceWorks, 'Inheritance should work');

  print('\n✓ All advanced context examples passed!\n');
}
