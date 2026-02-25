/// Demonstrates basic usage of TomExecutionContext for zone-based context propagation.
///
/// This example shows how to create contexts, add entries, and run code within
/// a context to make values available throughout the call chain.
library;

import 'package:tom_core_kernel/src/tombase/context/execution_context.dart';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';

// =============================================================================
// Basic Execution Context Example
// =============================================================================

void run() {
  print('=== 01: Basic Execution Context Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Creating a simple context
  // ---------------------------------------------------------------------------
  print('1. Creating a simple context with entries:');

  final context = TomExecutionContext({
    'userId': TomContextEntry<String>(() => 'user-12345'),
    'requestId': TomContextEntry<String>(() => 'req-abc-xyz'),
    'timestamp': TomContextEntry<int>(() => 1700000000000),
  });

  // Access entries directly from the context map
  final userId = context.contextMap['userId']?.contextFunction();
  final requestId = context.contextMap['requestId']?.contextFunction();

  print('   - User ID: $userId');
  print('   - Request ID: $requestId\n');

  // ---------------------------------------------------------------------------
  // Example 2: Running code within a context
  // ---------------------------------------------------------------------------
  print('2. Running code within a context:');

  String? retrievedUserId;
  String? retrievedRequestId;

  context.runInContext(() {
    // Inside this zone, we can retrieve the context
    final currentContext = getFromCurrentZone<TomExecutionContext>();
    retrievedUserId =
        currentContext?.contextMap['userId']?.contextFunction() as String?;
    retrievedRequestId =
        currentContext?.contextMap['requestId']?.contextFunction() as String?;

    print('   - Retrieved User ID from zone: $retrievedUserId');
    print('   - Retrieved Request ID from zone: $retrievedRequestId');
  });

  print('');

  // ---------------------------------------------------------------------------
  // Example 3: Adding entries dynamically
  // ---------------------------------------------------------------------------
  print('3. Adding entries dynamically:');

  final dynamicContext = TomExecutionContext({});

  // Add entries one at a time
  dynamicContext.add('role', TomContextEntry<String>(() => 'admin'));
  dynamicContext.add('permissions', TomContextEntry<List<String>>(() => [
    'read',
    'write',
    'delete',
  ]));

  final role = dynamicContext.contextMap['role']?.contextFunction();
  final permissions =
      dynamicContext.contextMap['permissions']?.contextFunction();

  print('   - Role: $role');
  print('   - Permissions: $permissions\n');

  // ---------------------------------------------------------------------------
  // Example 4: Clearing context entries
  // ---------------------------------------------------------------------------
  print('4. Clearing context entries:');

  final clearableContext = TomExecutionContext({
    'temp1': TomContextEntry<String>(() => 'value1'),
    'temp2': TomContextEntry<String>(() => 'value2'),
  });

  final beforeClearCount = clearableContext.contextMap.length;
  print('   - Entries before clear: $beforeClearCount');

  clearableContext.clear();
  final afterClearCount = clearableContext.contextMap.length;
  print('   - Entries after clear: $afterClearCount\n');

  // ---------------------------------------------------------------------------
  // Example 5: TomContextEntry type information
  // ---------------------------------------------------------------------------
  print('5. TomContextEntry type information:');

  final stringEntry = TomContextEntry<String>(() => 'hello');
  final intEntry = TomContextEntry<int>(() => 42);
  final listEntry = TomContextEntry<List<double>>(() => [1.0, 2.0, 3.0]);

  print('   - String entry type: ${stringEntry.type}');
  print('   - Int entry type: ${intEntry.type}');
  print('   - List<double> entry type: ${listEntry.type}\n');

  // ---------------------------------------------------------------------------
  // Example 6: Multiple ways to access entry values
  // ---------------------------------------------------------------------------
  print('6. Multiple ways to access entry values:');

  final entry = TomContextEntry<String>(() => 'test-value');

  // Method 1: contextFunction() (original)
  final viaFunction = entry.contextFunction();
  print('   - Via contextFunction(): $viaFunction');

  // Method 2: value getter (recommended)
  final viaValue = entry.value;
  print('   - Via .value: $viaValue');

  // Method 3: call operator (shortest)
  final viaCall = entry();
  print('   - Via call operator (): $viaCall');

  // Method 4: ~ operator (alternative)
  final viaTilde = ~entry;
  print('   - Via ~ operator: $viaTilde\n');

  // ---------------------------------------------------------------------------
  // Example 7: Using getEntry for type-safe access
  // ---------------------------------------------------------------------------
  print('7. Using getEntry for type-safe access:');

  final typedContext = TomExecutionContext({
    'count': TomContextEntry<int>(() => 100),
    'name': TomContextEntry<String>(() => 'example'),
  });

  // Get entry with correct type
  final countEntry = typedContext.getEntry<int>('count');
  final nameEntry = typedContext.getEntry<String>('name');

  print('   - Count entry value: ${countEntry?.value}');
  print('   - Name entry value: ${nameEntry?.value}');

  // Get entry with wrong type returns null
  final wrongTypeEntry = typedContext.getEntry<bool>('count');
  print('   - Wrong type entry: $wrongTypeEntry (null expected)\n');

  // ---------------------------------------------------------------------------
  // Example 8: Using getValueFromCurrentZone static method
  // ---------------------------------------------------------------------------
  print('8. Using getValueFromCurrentZone static method:');

  final staticContext = TomExecutionContext({
    'sessionId': TomContextEntry<String>(() => 'sess-abc-123'),
    'maxRetries': TomContextEntry<int>(() => 3),
  });

  String? staticSessionId;
  int? staticMaxRetries;
  String? staticMissing;

  staticContext.runInContext(() {
    // Static method to get values directly by name and type
    staticSessionId = TomExecutionContext.getValueFromCurrentZone<String>('sessionId');
    staticMaxRetries = TomExecutionContext.getValueFromCurrentZone<int>('maxRetries');
    staticMissing = TomExecutionContext.getValueFromCurrentZone<String>('notThere');
  });

  print('   - Session ID: $staticSessionId');
  print('   - Max retries: $staticMaxRetries');
  print('   - Missing value: $staticMissing (null expected)\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Context creation
  assert(userId == 'user-12345', 'User ID should be user-12345');
  assert(requestId == 'req-abc-xyz', 'Request ID should be req-abc-xyz');

  // Example 2: Running code in context
  assert(
    retrievedUserId == 'user-12345',
    'Retrieved user ID should match original',
  );
  assert(
    retrievedRequestId == 'req-abc-xyz',
    'Retrieved request ID should match original',
  );

  // Example 3: Dynamic entries
  assert(role == 'admin', 'Role should be admin');
  assert(permissions is List<String>, 'Permissions should be a list');
  assert((permissions as List<String>).length == 3, 'Should have 3 permissions');

  // Example 4: Clearing
  assert(beforeClearCount == 2, 'Should have 2 entries before clear');
  assert(afterClearCount == 0, 'Should have 0 entries after clear');

  // Example 5: Type information
  assert(stringEntry.type == String, 'String entry type should be String');
  assert(intEntry.type == int, 'Int entry type should be int');

  // Example 6: Multiple access methods
  assert(viaFunction == 'test-value');
  assert(viaValue == 'test-value');
  assert(viaCall == 'test-value');
  assert(viaTilde == 'test-value');

  // Example 7: getEntry
  assert(countEntry?.value == 100);
  assert(nameEntry?.value == 'example');
  assert(wrongTypeEntry == null);

  // Example 8: getValueFromCurrentZone
  assert(staticSessionId == 'sess-abc-123');
  assert(staticMaxRetries == 3);
  assert(staticMissing == null);
}
