/// Demonstrates context nesting and composition with TomExecutionContext.
///
/// This example shows how contexts can be combined and nested, with inner
/// contexts having access to outer context values.
library;

import 'package:tom_core_kernel/src/tombase/context/execution_context.dart';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';

// =============================================================================
// Context Nesting Example
// =============================================================================

void run() {
  print('=== 02: Context Nesting Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Combining contexts with combineWith
  // ---------------------------------------------------------------------------
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

  final combinedTenant =
      baseContext.contextMap['tenant']?.contextFunction() as String?;
  final combinedUserId =
      baseContext.contextMap['userId']?.contextFunction() as String?;
  final combinedRole =
      baseContext.contextMap['role']?.contextFunction() as String?;

  print('   - Tenant (from base): $combinedTenant');
  print('   - User ID (from user): $combinedUserId');
  print('   - Role (from user): $combinedRole\n');

  // ---------------------------------------------------------------------------
  // Example 2: Overwriting values with combineWith
  // ---------------------------------------------------------------------------
  print('2. Overwriting values with combineWith:');

  final originalContext = TomExecutionContext({
    'version': TomContextEntry<String>(() => 'v1.0'),
    'debug': TomContextEntry<bool>(() => false),
  });

  final overrideContext = TomExecutionContext({
    'version': TomContextEntry<String>(() => 'v2.0'), // Overwrites v1.0
    'newFeature': TomContextEntry<bool>(() => true),
  });

  final versionBefore =
      originalContext.contextMap['version']?.contextFunction();
  print('   - Version before combine: $versionBefore');

  originalContext.combineWith(overrideContext);

  final versionAfter =
      originalContext.contextMap['version']?.contextFunction();
  final hasNewFeature =
      originalContext.contextMap['newFeature']?.contextFunction();

  print('   - Version after combine: $versionAfter');
  print('   - New feature flag: $hasNewFeature\n');

  // ---------------------------------------------------------------------------
  // Example 3: Nested context execution (zone within zone)
  // ---------------------------------------------------------------------------
  print('3. Nested context execution (zone within zone):');

  final outerContext = TomExecutionContext({
    'level': TomContextEntry<String>(() => 'outer'),
    'sharedValue': TomContextEntry<int>(() => 100),
  });

  final innerContext = TomExecutionContext({
    'level': TomContextEntry<String>(() => 'inner'), // Shadows outer
    'innerOnly': TomContextEntry<String>(() => 'inner-exclusive'),
  });

  String? outerLevel;
  int? outerShared;
  String? innerLevel;
  int? innerShared;
  String? innerOnly;

  outerContext.runInContext(() {
    final ctx = getFromCurrentZone<TomExecutionContext>();
    outerLevel = ctx?.contextMap['level']?.contextFunction() as String?;
    outerShared = ctx?.contextMap['sharedValue']?.contextFunction() as int?;

    print('   - In outer zone - level: $outerLevel, shared: $outerShared');

    innerContext.runInContext(() {
      final innerCtx = getFromCurrentZone<TomExecutionContext>();
      innerLevel = innerCtx?.contextMap['level']?.contextFunction() as String?;
      innerShared =
          innerCtx?.contextMap['sharedValue']?.contextFunction() as int?;
      innerOnly =
          innerCtx?.contextMap['innerOnly']?.contextFunction() as String?;

      print(
        '   - In inner zone - level: $innerLevel, shared: $innerShared, innerOnly: $innerOnly',
      );
    });
  });

  print('');

  // ---------------------------------------------------------------------------
  // Example 4: Context inheritance in nested zones
  // ---------------------------------------------------------------------------
  print('4. Context inheritance in nested zones:');

  final parentContext = TomExecutionContext({
    'parentValue': TomContextEntry<String>(() => 'from-parent'),
  });

  final childContext = TomExecutionContext({
    'childValue': TomContextEntry<String>(() => 'from-child'),
  });

  String? inheritedParent;
  String? inheritedChild;

  parentContext.runInContext(() {
    childContext.runInContext(() {
      final ctx = getFromCurrentZone<TomExecutionContext>();
      // Child zone should have access to both parent and child values
      inheritedParent =
          ctx?.contextMap['parentValue']?.contextFunction() as String?;
      inheritedChild =
          ctx?.contextMap['childValue']?.contextFunction() as String?;

      print('   - Parent value in child zone: $inheritedParent');
      print('   - Child value in child zone: $inheritedChild');
    });
  });

  print('');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Combining contexts
  assert(combinedTenant == 'acme-corp', 'Tenant should be preserved');
  assert(combinedUserId == 'user-42', 'User ID should be added from combine');
  assert(combinedRole == 'developer', 'Role should be added from combine');

  // Example 2: Overwriting values
  assert(versionBefore == 'v1.0', 'Original version should be v1.0');
  assert(versionAfter == 'v2.0', 'Version should be overwritten to v2.0');
  assert(hasNewFeature == true, 'New feature should be added');

  // Example 3: Nested execution
  assert(outerLevel == 'outer', 'Outer level should be outer');
  assert(outerShared == 100, 'Outer shared should be 100');
  assert(innerLevel == 'inner', 'Inner level should shadow outer');
  assert(innerShared == 100, 'Inner should inherit shared value');
  assert(innerOnly == 'inner-exclusive', 'Inner-only value should be present');

  // Example 4: Context inheritance
  assert(
    inheritedParent == 'from-parent',
    'Parent value should be inherited in child zone',
  );
  assert(
    inheritedChild == 'from-child',
    'Child value should be present in child zone',
  );
}
