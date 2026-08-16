/// Demonstrates context nesting and composition with TomExecutionContext.
///
/// This example shows how contexts can be combined and nested, with inner
/// contexts having access to outer context values.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Combining contexts with combineWith
// =============================================================================

class CombineContextsExample {
  static String? combinedTenant;
  static String? combinedUserId;
  static String? combinedRole;
  static int entryCountAfterCombine = 0;

  static void example1CombiningContexts() {
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
    combinedTenant =
        baseContext.contextMap['tenant']?.contextFunction() as String?;
    combinedUserId =
        baseContext.contextMap['userId']?.contextFunction() as String?;
    combinedRole =
        baseContext.contextMap['role']?.contextFunction() as String?;

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
    final originalContext = TomExecutionContext({
      'version': TomContextEntry<String>(() => 'v1.0'),
      'debug': TomContextEntry<bool>(() => false),
    });

    final overrideContext = TomExecutionContext({
      'version': TomContextEntry<String>(() => 'v2.0'), // Overwrites v1.0
      'newFeature': TomContextEntry<bool>(() => true),
    });

    versionBefore =
        originalContext.contextMap['version']?.contextFunction() as String?;

    originalContext.combineWith(overrideContext);

    versionAfter =
        originalContext.contextMap['version']?.contextFunction() as String?;
    hasNewFeature =
        originalContext.contextMap['newFeature']?.contextFunction() as bool?;
    entryCountAfterOverwrite = originalContext.contextMap.length;

    assert(versionBefore == 'v1.0', 'Original version should be v1.0');
    assert(versionAfter == 'v2.0', 'Version should be overwritten to v2.0');
    assert(hasNewFeature == true, 'New feature should be added');
    assert(entryCountAfterOverwrite == 3, 'Should have 3 entries (not 4)');
  }
}

// =============================================================================
// EXAMPLE 3: Nested context execution (zone within zone)
// =============================================================================

class NestedZoneExample {
  static String? outerLevel;
  static int? outerShared;
  static String? innerLevel;
  static int? innerShared;
  static String? innerOnly;
  static bool outerZoneExecuted = false;
  static bool innerZoneExecuted = false;

  static void example3NestedZoneExecution() {
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
      final ctx = getFromCurrentZone<TomExecutionContext>();
      outerLevel = ctx?.contextMap['level']?.contextFunction() as String?;
      outerShared = ctx?.contextMap['sharedValue']?.contextFunction() as int?;

      innerContext.runInContext(() {
        innerZoneExecuted = true;
        final innerCtx = getFromCurrentZone<TomExecutionContext>();
        innerLevel =
            innerCtx?.contextMap['level']?.contextFunction() as String?;
        innerShared =
            innerCtx?.contextMap['sharedValue']?.contextFunction() as int?;
        innerOnly =
            innerCtx?.contextMap['innerOnly']?.contextFunction() as String?;
      });
    });

    assert(outerZoneExecuted, 'Outer zone should have executed');
    assert(innerZoneExecuted, 'Inner zone should have executed');
    assert(outerLevel == 'outer', 'Outer level should be outer');
    assert(outerShared == 100, 'Outer shared should be 100');
    assert(innerLevel == 'inner', 'Inner level should shadow outer');
    assert(innerShared == 100, 'Inner should inherit shared value');
    assert(innerOnly == 'inner-exclusive', 'Inner-only value should be present');
  }
}

// =============================================================================
// EXAMPLE 4: Context inheritance in nested zones
// =============================================================================

class ContextInheritanceExample {
  static String? inheritedParent;
  static String? inheritedChild;
  static bool parentZoneExecuted = false;
  static bool childZoneExecuted = false;

  static void example4ContextInheritance() {
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
        final ctx = getFromCurrentZone<TomExecutionContext>();
        // Child zone should have access to both parent and child values
        inheritedParent =
            ctx?.contextMap['parentValue']?.contextFunction() as String?;
        inheritedChild =
            ctx?.contextMap['childValue']?.contextFunction() as String?;
      });
    });

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
// EXAMPLE 5: Building context chains
// =============================================================================

class ContextChainExample {
  static int totalEntryCount = 0;
  static String? requestId;
  static String? userId;
  static String? tenantId;
  static String? traceId;

  static void example5BuildingContextChains() {
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
    requestId =
        requestContext.contextMap['requestId']?.contextFunction() as String?;
    userId = requestContext.contextMap['userId']?.contextFunction() as String?;
    tenantId =
        requestContext.contextMap['tenantId']?.contextFunction() as String?;
    traceId =
        requestContext.contextMap['traceId']?.contextFunction() as String?;

    assert(totalEntryCount == 4, 'Should have 4 entries in combined context');
    assert(requestId == 'req-001', 'Request ID should be preserved');
    assert(userId == 'user-authenticated', 'User ID should be added');
    assert(tenantId == 'tenant-main', 'Tenant ID should be added');
    assert(traceId == 'trace-xyz', 'Trace ID should be preserved');
  }
}

// =============================================================================
// EXAMPLE 6: Context with lazy evaluation
// =============================================================================

class LazyEvaluationExample {
  static int evaluationCount = 0;
  static String? firstAccess;
  static String? secondAccess;

  static void example6LazyEvaluation() {
    evaluationCount = 0;

    final lazyContext = TomExecutionContext({
      'lazyValue': TomContextEntry<String>(() {
        evaluationCount++;
        return 'computed-$evaluationCount';
      }),
    });

    // Access the value twice - each access should re-evaluate
    firstAccess =
        lazyContext.contextMap['lazyValue']?.contextFunction() as String?;
    secondAccess =
        lazyContext.contextMap['lazyValue']?.contextFunction() as String?;

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
  CombineContextsExample.example1CombiningContexts();
  OverwriteContextExample.example2OverwritingValues();
  NestedZoneExample.example3NestedZoneExecution();
  ContextInheritanceExample.example4ContextInheritance();
  ContextChainExample.example5BuildingContextChains();
  LazyEvaluationExample.example6LazyEvaluation();
}

void main() => run();
