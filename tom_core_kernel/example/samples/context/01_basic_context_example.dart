/// Demonstrates basic usage of TomExecutionContext for zone-based context propagation.
///
/// This example shows how to create contexts, add entries, and run code within
/// a context to make values available throughout the call chain.
///
/// Values are read the way the module intends: `getEntry<T>(name)?.value` on a
/// context you hold, and [TomExecutionContext.getValueFromCurrentZone] once you
/// are inside a `runInContext` body. Direct `contextMap` access appears only
/// where the map itself is the subject — entry counts and key listings.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Creating a simple context
// =============================================================================

class BasicContextCreationExample {
  // Captured results for assertions
  static String? capturedUserId;
  static String? capturedRequestId;
  static int? capturedTimestamp;

  static void example1CreatingSimpleContext() {
    print('1. Creating a simple context:');

    final context = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-12345'),
      'requestId': TomContextEntry<String>(() => 'req-abc-xyz'),
      'timestamp': TomContextEntry<int>(() => 1700000000000),
    });

    // Typed read on a context you hold: getEntry<T> matches the entry's
    // declared type, and .value invokes its provider function.
    capturedUserId = context.getEntry<String>('userId')?.value;
    capturedRequestId = context.getEntry<String>('requestId')?.value;
    capturedTimestamp = context.getEntry<int>('timestamp')?.value;

    print('   - userId: $capturedUserId');
    print('   - requestId: $capturedRequestId');
    print('   - timestamp: $capturedTimestamp');

    assert(capturedUserId == 'user-12345', 'User ID should be user-12345');
    assert(
      capturedRequestId == 'req-abc-xyz',
      'Request ID should be req-abc-xyz',
    );
    assert(capturedTimestamp == 1700000000000, 'Timestamp should match');
  }
}

// =============================================================================
// EXAMPLE 2: Running code within a context
// =============================================================================

class ContextExecutionExample {
  static String? retrievedUserId;
  static String? retrievedRequestId;
  static int entriesVisibleInZone = 0;
  static bool zoneExecuted = false;

  static void example2RunningCodeInContext() {
    print('\n2. Running code within a context:');

    final context = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-12345'),
      'requestId': TomContextEntry<String>(() => 'req-abc-xyz'),
    });

    context.runInContext(() {
      zoneExecuted = true;

      // The context object itself is installed in the zone under its own type.
      final currentContext = getFromCurrentZone<TomExecutionContext>();
      entriesVisibleInZone = currentContext?.contextMap.length ?? 0;

      // Individual values come from the named, typed read.
      retrievedUserId = TomExecutionContext.getValueFromCurrentZone<String>(
        'userId',
      );
      retrievedRequestId = TomExecutionContext.getValueFromCurrentZone<String>(
        'requestId',
      );
    });

    print('   - Zone executed: $zoneExecuted');
    print('   - Entries visible in zone: $entriesVisibleInZone');
    print('   - userId: $retrievedUserId');
    print('   - requestId: $retrievedRequestId');

    assert(zoneExecuted, 'Zone code should have executed');
    assert(entriesVisibleInZone == 2, 'Both entries should be in the zone');
    assert(
      retrievedUserId == 'user-12345',
      'Retrieved user ID should match original',
    );
    assert(
      retrievedRequestId == 'req-abc-xyz',
      'Retrieved request ID should match original',
    );
  }
}

// =============================================================================
// EXAMPLE 3: Adding entries dynamically
// =============================================================================

class DynamicEntriesExample {
  static String? capturedRole;
  static List<String>? capturedPermissions;
  static int entryCountAfterAdding = 0;

  static void example3AddingEntriesDynamically() {
    print('\n3. Adding entries dynamically:');

    final dynamicContext = TomExecutionContext({});

    // Add entries one at a time
    dynamicContext.add('role', TomContextEntry<String>(() => 'admin'));
    dynamicContext.add(
      'permissions',
      TomContextEntry<List<String>>(() => ['read', 'write', 'delete']),
    );

    // The count is a property of the map, so it is read from the map.
    entryCountAfterAdding = dynamicContext.contextMap.length;
    capturedRole = dynamicContext.getEntry<String>('role')?.value;
    capturedPermissions = dynamicContext
        .getEntry<List<String>>('permissions')
        ?.value;

    print('   - Entry count after adding: $entryCountAfterAdding');
    print('   - role: $capturedRole');
    print('   - permissions: ${capturedPermissions?.join(', ')}');

    assert(entryCountAfterAdding == 2, 'Should have 2 entries');
    assert(capturedRole == 'admin', 'Role should be admin');
    assert(capturedPermissions is List<String>, 'Permissions should be a list');
    assert(capturedPermissions!.length == 3, 'Should have 3 permissions');
    assert(
      capturedPermissions!.contains('read'),
      'Should have read permission',
    );
  }
}

// =============================================================================
// EXAMPLE 4: Clearing context entries
// =============================================================================

class ClearContextExample {
  static int beforeClearCount = 0;
  static int afterClearCount = 0;

  static void example4ClearingContextEntries() {
    print('\n4. Clearing context entries:');

    final clearableContext = TomExecutionContext({
      'temp1': TomContextEntry<String>(() => 'value1'),
      'temp2': TomContextEntry<String>(() => 'value2'),
    });

    beforeClearCount = clearableContext.contextMap.length;
    clearableContext.clear();
    afterClearCount = clearableContext.contextMap.length;

    print('   - Entries before clear: $beforeClearCount');
    print('   - Entries after clear: $afterClearCount');

    assert(beforeClearCount == 2, 'Should have 2 entries before clear');
    assert(afterClearCount == 0, 'Should have 0 entries after clear');
  }
}

// =============================================================================
// EXAMPLE 5: TomContextEntry type information
// =============================================================================

class ContextEntryTypeExample {
  static Type? stringType;
  static Type? intType;
  static Type? listType;

  static void example5ContextEntryTypeInfo() {
    print('\n5. TomContextEntry type information:');

    final stringEntry = TomContextEntry<String>(() => 'hello');
    final intEntry = TomContextEntry<int>(() => 42);
    final listEntry = TomContextEntry<List<double>>(() => [1.0, 2.0, 3.0]);

    stringType = stringEntry.type;
    intType = intEntry.type;
    listType = listEntry.type;

    print('   - TomContextEntry<String>.type: $stringType');
    print('   - TomContextEntry<int>.type: $intType');
    print('   - TomContextEntry<List<double>>.type: $listType');

    assert(stringType == String, 'String entry type should be String');
    assert(intType == int, 'Int entry type should be int');
    assert(listType == List<double>, 'List entry type should be List<double>');
  }
}

// =============================================================================
// EXAMPLE 6: Multiple ways to access entry values
// =============================================================================

class EntryValueAccessExample {
  static String? viaContextFunction;
  static String? viaValueGetter;
  static String? viaCallOperator;
  static String? viaTildeOperator;

  static void example6MultipleAccessMethods() {
    print('\n6. Multiple ways to access an entry value:');

    final entry = TomContextEntry<String>(() => 'test-value');

    // Method 1: contextFunction() (original)
    viaContextFunction = entry.contextFunction();

    // Method 2: value getter (recommended)
    viaValueGetter = entry.value;

    // Method 3: call operator (shortest)
    viaCallOperator = entry();

    // Method 4: ~ operator (alternative)
    viaTildeOperator = ~entry;

    print('   - entry.contextFunction(): $viaContextFunction');
    print('   - entry.value: $viaValueGetter');
    print('   - entry(): $viaCallOperator');
    print('   - ~entry: $viaTildeOperator');

    assert(viaContextFunction == 'test-value', 'contextFunction() should work');
    assert(viaValueGetter == 'test-value', '.value should work');
    assert(viaCallOperator == 'test-value', 'call operator should work');
    assert(viaTildeOperator == 'test-value', '~ operator should work');

    // All methods should return the same value
    assert(
      viaContextFunction == viaValueGetter &&
          viaValueGetter == viaCallOperator &&
          viaCallOperator == viaTildeOperator,
      'All access methods should return the same value',
    );
    print('   - All four return the same value');
  }
}

// =============================================================================
// EXAMPLE 7: Using getEntry for type-safe access
// =============================================================================

class TypeSafeAccessExample {
  static int? countEntryValue;
  static String? nameEntryValue;
  static TomContextEntry<bool>? wrongTypeEntry;

  static void example7TypeSafeAccess() {
    print('\n7. Type-safe access with getEntry:');

    final typedContext = TomExecutionContext({
      'count': TomContextEntry<int>(() => 100),
      'name': TomContextEntry<String>(() => 'example'),
    });

    // Get entry with correct type
    final countEntry = typedContext.getEntry<int>('count');
    final nameEntry = typedContext.getEntry<String>('name');

    countEntryValue = countEntry?.value;
    nameEntryValue = nameEntry?.value;

    // The type parameter must match the entry's declared type exactly — a
    // mismatch is not an error, it simply misses.
    wrongTypeEntry = typedContext.getEntry<bool>('count');

    print('   - getEntry<int>("count")?.value: $countEntryValue');
    print('   - getEntry<String>("name")?.value: $nameEntryValue');
    print('   - getEntry<bool>("count") (wrong type): $wrongTypeEntry');

    assert(countEntryValue == 100, 'Count should be 100');
    assert(nameEntryValue == 'example', 'Name should be example');
    assert(wrongTypeEntry == null, 'Wrong type entry should be null');
  }
}

// =============================================================================
// EXAMPLE 8: Using getValueFromCurrentZone static method
// =============================================================================

class StaticZoneAccessExample {
  static String? staticSessionId;
  static int? staticMaxRetries;
  static String? staticMissing;

  static void example8GetValueFromCurrentZone() {
    print('\n8. Reading values from the current zone:');

    final staticContext = TomExecutionContext({
      'sessionId': TomContextEntry<String>(() => 'sess-abc-123'),
      'maxRetries': TomContextEntry<int>(() => 3),
    });

    staticContext.runInContext(() {
      // Static method to get values directly by name and type
      staticSessionId = TomExecutionContext.getValueFromCurrentZone<String>(
        'sessionId',
      );
      staticMaxRetries = TomExecutionContext.getValueFromCurrentZone<int>(
        'maxRetries',
      );
      staticMissing = TomExecutionContext.getValueFromCurrentZone<String>(
        'notThere',
      );
    });

    print('   - sessionId: $staticSessionId');
    print('   - maxRetries: $staticMaxRetries');
    print('   - notThere (undeclared entry): $staticMissing');

    assert(staticSessionId == 'sess-abc-123', 'Session ID should match');
    assert(staticMaxRetries == 3, 'Max retries should be 3');
    assert(staticMissing == null, 'Missing value should be null');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 01: Basic Context Example ===\n');

  BasicContextCreationExample.example1CreatingSimpleContext();
  ContextExecutionExample.example2RunningCodeInContext();
  DynamicEntriesExample.example3AddingEntriesDynamically();
  ClearContextExample.example4ClearingContextEntries();
  ContextEntryTypeExample.example5ContextEntryTypeInfo();
  EntryValueAccessExample.example6MultipleAccessMethods();
  TypeSafeAccessExample.example7TypeSafeAccess();
  StaticZoneAccessExample.example8GetValueFromCurrentZone();
  print('');
}

void main() {
  requireAsserts();
  run();
}
