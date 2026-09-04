/// Demonstrates context nesting and composition with TomExecutionContext.
///
/// This example shows how contexts can be combined and nested, with inner
/// contexts having access to outer context values.
///
/// Values are read the way the module intends: `getEntry<T>(name)?.value` on a
/// context you hold, and [TomExecutionContext.getValueFromCurrentZone] once you
/// are inside a `runInContext` body. Direct `contextMap` access appears only
/// where the map itself is the subject — entry counts and key listings.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Combining contexts with combineWith
// =============================================================================

class CombineContextsExample {
  static String? combinedTenant;
  static String? combinedUserId;
  static String? combinedRole;
  static int entryCountAfterCombine = 0;

  static void example1CombiningContexts() {
    print('1. Combining contexts with combineWith:');

    final baseContext = TomExecutionContext({
      'tenant': TomContextEntry<String>(() => 'acme-corp'),
      'environment': TomContextEntry<String>(() => 'production'),
    });

    final userContext = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-42'),
      'role': TomContextEntry<String>(() => 'developer'),
    });

    // Combine user context into base context
    baseContext.combineWith(userContext);

    entryCountAfterCombine = baseContext.contextMap.length;
    combinedTenant = baseContext.getEntry<String>('tenant')?.value;
    combinedUserId = baseContext.getEntry<String>('userId')?.value;
    combinedRole = baseContext.getEntry<String>('role')?.value;

    print('   - Entries after combine: $entryCountAfterCombine');
    print('   - tenant (from base): $combinedTenant');
    print('   - userId (merged in): $combinedUserId');
    print('   - role (merged in): $combinedRole');

    assert(entryCountAfterCombine == 4, 'Should have 4 entries after combine');
    assert(combinedTenant == 'acme-corp', 'Tenant should be preserved');
    assert(combinedUserId == 'user-42', 'User ID should be added from combine');
    assert(combinedRole == 'developer', 'Role should be added from combine');
  }
}

// =============================================================================
// EXAMPLE 2: Overwriting values with combineWith
// =============================================================================

class OverwriteContextExample {
  static String? versionBefore;
  static String? versionAfter;
  static bool? hasNewFeature;
  static int entryCountAfterOverwrite = 0;

  static void example2OverwritingValues() {
    print('\n2. Overwriting values with combineWith:');

    final originalContext = TomExecutionContext({
      'version': TomContextEntry<String>(() => 'v1.0'),
      'debug': TomContextEntry<bool>(() => false),
    });

    final overrideContext = TomExecutionContext({
      'version': TomContextEntry<String>(() => 'v2.0'), // Overwrites v1.0
      'newFeature': TomContextEntry<bool>(() => true),
    });

    versionBefore = originalContext.getEntry<String>('version')?.value;

    originalContext.combineWith(overrideContext);

    versionAfter = originalContext.getEntry<String>('version')?.value;
    hasNewFeature = originalContext.getEntry<bool>('newFeature')?.value;
    entryCountAfterOverwrite = originalContext.contextMap.length;

    print('   - version before: $versionBefore');
    print('   - version after: $versionAfter');
    print('   - newFeature: $hasNewFeature');
    print(
      '   - Entries after overwrite: $entryCountAfterOverwrite '
      '(the colliding key was replaced, not duplicated)',
    );

    assert(versionBefore == 'v1.0', 'Original version should be v1.0');
    assert(versionAfter == 'v2.0', 'Version should be overwritten to v2.0');
    assert(hasNewFeature == true, 'New feature should be added');
    assert(entryCountAfterOverwrite == 3, 'Should have 3 entries (not 4)');
  }
}

// =============================================================================
// EXAMPLE 3: Composing at construction with the parentContext parameter
// =============================================================================

class ExplicitParentExample {
  static String? inheritedBase;
  static String? ownChild;
  static String? overriddenShared;
  static int childEntryCount = 0;
  static int parentEntryCount = 0;

  static void example3ExplicitParentContext() {
    print('\n3. Composing at construction with parentContext:');

    final parentCtx = TomExecutionContext({
      'base': TomContextEntry<String>(() => 'parent-value'),
      'shared': TomContextEntry<String>(() => 'from-parent'),
    });

    // The constructor merges the parent's entries first and the child's over
    // them, so the child wins on collision — the same rule combineWith uses,
    // applied once at construction instead of afterwards.
    final childCtx = TomExecutionContext({
      'child': TomContextEntry<String>(() => 'child-value'),
      'shared': TomContextEntry<String>(() => 'from-child'),
    }, parentContext: parentCtx);

    childEntryCount = childCtx.contextMap.length;
    parentEntryCount = parentCtx.contextMap.length;
    inheritedBase = childCtx.getEntry<String>('base')?.value;
    ownChild = childCtx.getEntry<String>('child')?.value;
    overriddenShared = childCtx.getEntry<String>('shared')?.value;

    print('   - Entries in the child: $childEntryCount');
    print('   - base (inherited from the parent): $inheritedBase');
    print('   - child (the child\'s own): $ownChild');
    print('   - shared (child overrides parent): $overriddenShared');
    print('   - Parent is left unchanged: $parentEntryCount entries');
    print(
      '   - This is the mechanism runInContext nests with: it builds a new '
      'context whose parent is the zone\'s current one',
    );

    assert(childEntryCount == 3, 'Child should hold base, shared and child');
    assert(inheritedBase == 'parent-value', 'Base should come from the parent');
    assert(ownChild == 'child-value', 'Child should keep its own entry');
    assert(overriddenShared == 'from-child', 'Child should win on collision');
    assert(parentEntryCount == 2, 'Parent map must not be mutated');
  }
}

// =============================================================================
// EXAMPLE 4: Nested context execution (zone within zone)
// =============================================================================

class NestedZoneExample {
  static String? outerLevel;
  static int? outerShared;
  static String? innerLevel;
  static int? innerShared;
  static String? innerOnly;
  static bool outerZoneExecuted = false;
  static bool innerZoneExecuted = false;

  static void example4NestedZoneExecution() {
    print('\n4. Nested context execution (zone within zone):');

    final outerContext = TomExecutionContext({
      'level': TomContextEntry<String>(() => 'outer'),
      'sharedValue': TomContextEntry<int>(() => 100),
    });

    final innerContext = TomExecutionContext({
      'level': TomContextEntry<String>(() => 'inner'), // Shadows outer
      'innerOnly': TomContextEntry<String>(() => 'inner-exclusive'),
    });

    outerContext.runInContext(() {
      outerZoneExecuted = true;
      outerLevel = TomExecutionContext.getValueFromCurrentZone<String>('level');
      outerShared = TomExecutionContext.getValueFromCurrentZone<int>(
        'sharedValue',
      );

      innerContext.runInContext(() {
        innerZoneExecuted = true;
        innerLevel = TomExecutionContext.getValueFromCurrentZone<String>(
          'level',
        );
        innerShared = TomExecutionContext.getValueFromCurrentZone<int>(
          'sharedValue',
        );
        innerOnly = TomExecutionContext.getValueFromCurrentZone<String>(
          'innerOnly',
        );
      });
    });

    print('   In the outer zone:');
    print('   - level: $outerLevel');
    print('   - sharedValue: $outerShared');
    print('   In the nested inner zone:');
    print('   - level: $innerLevel (shadows the outer entry)');
    print('   - sharedValue: $innerShared (inherited from the outer zone)');
    print('   - innerOnly: $innerOnly');

    assert(outerZoneExecuted, 'Outer zone should have executed');
    assert(innerZoneExecuted, 'Inner zone should have executed');
    assert(outerLevel == 'outer', 'Outer level should be outer');
    assert(outerShared == 100, 'Outer shared should be 100');
    assert(innerLevel == 'inner', 'Inner level should shadow outer');
    assert(innerShared == 100, 'Inner should inherit shared value');
    assert(
      innerOnly == 'inner-exclusive',
      'Inner-only value should be present',
    );
  }
}

// =============================================================================
// EXAMPLE 5: Context inheritance in nested zones
// =============================================================================

class ContextInheritanceExample {
  static String? inheritedParent;
  static String? inheritedChild;
  static bool parentZoneExecuted = false;
  static bool childZoneExecuted = false;

  static void example5ContextInheritance() {
    print('\n5. Context inheritance in nested zones:');

    final parentContext = TomExecutionContext({
      'parentValue': TomContextEntry<String>(() => 'from-parent'),
    });

    final childContext = TomExecutionContext({
      'childValue': TomContextEntry<String>(() => 'from-child'),
    });

    parentContext.runInContext(() {
      parentZoneExecuted = true;
      childContext.runInContext(() {
        childZoneExecuted = true;
        // Child zone should have access to both parent and child values
        inheritedParent = TomExecutionContext.getValueFromCurrentZone<String>(
          'parentValue',
        );
        inheritedChild = TomExecutionContext.getValueFromCurrentZone<String>(
          'childValue',
        );
      });
    });

    print('   Read from inside the child zone:');
    print('   - parentValue: $inheritedParent');
    print('   - childValue: $inheritedChild');

    assert(parentZoneExecuted, 'Parent zone should have executed');
    assert(childZoneExecuted, 'Child zone should have executed');
    assert(
      inheritedParent == 'from-parent',
      'Parent value should be inherited in child zone',
    );
    assert(
      inheritedChild == 'from-child',
      'Child value should be present in child zone',
    );
  }
}

// =============================================================================
// EXAMPLE 6: Building context chains
// =============================================================================

class ContextChainExample {
  static int totalEntryCount = 0;
  static String? requestId;
  static String? userId;
  static String? tenantId;
  static String? traceId;

  static void example6BuildingContextChains() {
    print('\n6. Building a context chain for request processing:');

    // Build a chain of contexts for request processing
    final requestContext = TomExecutionContext({
      'requestId': TomContextEntry<String>(() => 'req-001'),
      'traceId': TomContextEntry<String>(() => 'trace-xyz'),
    });

    final authContext = TomExecutionContext({
      'userId': TomContextEntry<String>(() => 'user-authenticated'),
      'tenantId': TomContextEntry<String>(() => 'tenant-main'),
    });

    // Combine contexts to build a complete request context
    requestContext.combineWith(authContext);

    totalEntryCount = requestContext.contextMap.length;
    requestId = requestContext.getEntry<String>('requestId')?.value;
    userId = requestContext.getEntry<String>('userId')?.value;
    tenantId = requestContext.getEntry<String>('tenantId')?.value;
    traceId = requestContext.getEntry<String>('traceId')?.value;

    print('   - Entry names: ${requestContext.contextMap.keys.join(', ')}');
    print('   - Total entries: $totalEntryCount');
    print('   - requestId: $requestId');
    print('   - traceId: $traceId');
    print('   - userId: $userId');
    print('   - tenantId: $tenantId');

    assert(totalEntryCount == 4, 'Should have 4 entries in combined context');
    assert(requestId == 'req-001', 'Request ID should be preserved');
    assert(userId == 'user-authenticated', 'User ID should be added');
    assert(tenantId == 'tenant-main', 'Tenant ID should be added');
    assert(traceId == 'trace-xyz', 'Trace ID should be preserved');
  }
}

// =============================================================================
// EXAMPLE 7: Context with lazy evaluation
// =============================================================================

class LazyEvaluationExample {
  static int evaluationCount = 0;
  static String? firstAccess;
  static String? secondAccess;

  static void example7LazyEvaluation() {
    print('\n7. Entries are evaluated lazily, on every access:');

    evaluationCount = 0;

    final lazyContext = TomExecutionContext({
      'lazyValue': TomContextEntry<String>(() {
        evaluationCount++;
        return 'computed-$evaluationCount';
      }),
    });

    print('   - Evaluations before any access: $evaluationCount');

    // Access the value twice - each access should re-evaluate
    firstAccess = lazyContext.getEntry<String>('lazyValue')?.value;
    secondAccess = lazyContext.getEntry<String>('lazyValue')?.value;

    print('   - First access: $firstAccess');
    print('   - Second access: $secondAccess');
    print('   - Evaluations after two accesses: $evaluationCount');

    // The function is called each time
    assert(evaluationCount == 2, 'Should have evaluated twice');
    assert(firstAccess == 'computed-1', 'First access should be computed-1');
    assert(secondAccess == 'computed-2', 'Second access should be computed-2');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 02: Context Nesting Example ===\n');

  CombineContextsExample.example1CombiningContexts();
  OverwriteContextExample.example2OverwritingValues();
  ExplicitParentExample.example3ExplicitParentContext();
  NestedZoneExample.example4NestedZoneExecution();
  ContextInheritanceExample.example5ContextInheritance();
  ContextChainExample.example6BuildingContextChains();
  LazyEvaluationExample.example7LazyEvaluation();
  print('');
}

void main() {
  requireAsserts();
  run();
}
