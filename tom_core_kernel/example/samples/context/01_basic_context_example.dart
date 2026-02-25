/// Demonstrates basic usage of TomExecutionContext for zone-based context propagation.
///
/// This example shows how to create contexts, add entries, and run code within
/// a context to make values available throughout the call chain.
library;

import 'package:tom_core_kernel/src/tombase/context/execution_context.dart';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';

// =============================================================================
// EXAMPLE 1: Creating a simple context
// =============================================================================

class BasicContextCreationExample {
  // Captured results for assertions
  static String? capturedUserId;
  static String? capturedRequestId;
  static int? capturedTimestamp;

  static void example1CreatingSimpleContext() {
    final context = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-12345'),
      'requestId': TomContextEntry<String>(() => 'req-abc-xyz'),
      'timestamp': TomContextEntry<int>(() => 1700000000000),
    });

    // Access entries directly from the context map
    capturedUserId = context.contextMap['userId']?.contextFunction() as String?;
    capturedRequestId =
        context.contextMap['requestId']?.contextFunction() as String?;
    capturedTimestamp =
        context.contextMap['timestamp']?.contextFunction() as int?;

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
  static bool zoneExecuted = false;

  static void example2RunningCodeInContext() {
    final context = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-12345'),
      'requestId': TomContextEntry<String>(() => 'req-abc-xyz'),
    });

    context.runInContext(() {
      zoneExecuted = true;
      // Inside this zone, we can retrieve the context
      final currentContext = getFromCurrentZone<TomExecutionContext>();
      retrievedUserId =
          currentContext?.contextMap['userId']?.contextFunction() as String?;
      retrievedRequestId = currentContext?.contextMap['requestId']
          ?.contextFunction() as String?;
    });

    assert(zoneExecuted, 'Zone code should have executed');
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
    final dynamicContext = TomExecutionContext({});

    // Add entries one at a time
    dynamicContext.add('role', TomContextEntry<String>(() => 'admin'));
    dynamicContext.add(
      'permissions',
      TomContextEntry<List<String>>(() => ['read', 'write', 'delete']),
    );

    entryCountAfterAdding = dynamicContext.contextMap.length;
    capturedRole = dynamicContext.contextMap['role']?.contextFunction() as String?;
    capturedPermissions = dynamicContext.contextMap['permissions']
        ?.contextFunction() as List<String>?;

    assert(entryCountAfterAdding == 2, 'Should have 2 entries');
    assert(capturedRole == 'admin', 'Role should be admin');
    assert(capturedPermissions is List<String>, 'Permissions should be a list');
    assert(capturedPermissions!.length == 3, 'Should have 3 permissions');
    assert(capturedPermissions!.contains('read'), 'Should have read permission');
  }
}

// =============================================================================
// EXAMPLE 4: Clearing context entries
// =============================================================================

class ClearContextExample {
  static int beforeClearCount = 0;
  static int afterClearCount = 0;

  static void example4ClearingContextEntries() {
    final clearableContext = TomExecutionContext({
      'temp1': TomContextEntry<String>(() => 'value1'),
      'temp2': TomContextEntry<String>(() => 'value2'),
    });

    beforeClearCount = clearableContext.contextMap.length;
    clearableContext.clear();
    afterClearCount = clearableContext.contextMap.length;

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
    final stringEntry = TomContextEntry<String>(() => 'hello');
    final intEntry = TomContextEntry<int>(() => 42);
    final listEntry = TomContextEntry<List<double>>(() => [1.0, 2.0, 3.0]);

    stringType = stringEntry.type;
    intType = intEntry.type;
    listType = listEntry.type;

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
    final entry = TomContextEntry<String>(() => 'test-value');

    // Method 1: contextFunction() (original)
    viaContextFunction = entry.contextFunction();

    // Method 2: value getter (recommended)
    viaValueGetter = entry.value;

    // Method 3: call operator (shortest)
    viaCallOperator = entry();

    // Method 4: ~ operator (alternative)
    viaTildeOperator = ~entry;

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
    final typedContext = TomExecutionContext({
      'count': TomContextEntry<int>(() => 100),
      'name': TomContextEntry<String>(() => 'example'),
    });

    // Get entry with correct type
    final countEntry = typedContext.getEntry<int>('count');
    final nameEntry = typedContext.getEntry<String>('name');

    countEntryValue = countEntry?.value;
    nameEntryValue = nameEntry?.value;

    // Get entry with wrong type returns null
    wrongTypeEntry = typedContext.getEntry<bool>('count');

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
    final staticContext = TomExecutionContext({
      'sessionId': TomContextEntry<String>(() => 'sess-abc-123'),
      'maxRetries': TomContextEntry<int>(() => 3),
    });

    staticContext.runInContext(() {
      // Static method to get values directly by name and type
      staticSessionId =
          TomExecutionContext.getValueFromCurrentZone<String>('sessionId');
      staticMaxRetries =
          TomExecutionContext.getValueFromCurrentZone<int>('maxRetries');
      staticMissing =
          TomExecutionContext.getValueFromCurrentZone<String>('notThere');
    });

    assert(staticSessionId == 'sess-abc-123', 'Session ID should match');
    assert(staticMaxRetries == 3, 'Max retries should be 3');
    assert(staticMissing == null, 'Missing value should be null');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicContextCreationExample.example1CreatingSimpleContext();
  ContextExecutionExample.example2RunningCodeInContext();
  DynamicEntriesExample.example3AddingEntriesDynamically();
  ClearContextExample.example4ClearingContextEntries();
  ContextEntryTypeExample.example5ContextEntryTypeInfo();
  EntryValueAccessExample.example6MultipleAccessMethods();
  TypeSafeAccessExample.example7TypeSafeAccess();
  StaticZoneAccessExample.example8GetValueFromCurrentZone();
}

void main() => run();
