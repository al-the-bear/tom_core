/// Demonstrates [TomScope] — the hierarchical, zone-propagated scope identifier
/// used to namespace resource lookups (e.g. `app.checkout.orderForm`).
///
/// This example covers:
/// - The root [TomScope.defaultScope] and [TomScope.current]
/// - Installing child scopes with [TomScope.withScope]
/// - Nesting scopes and reading the dotted path via `getScopePath()`
/// - Building scope paths directly with [TomScope.buildScopePath]
/// - Running a body inside an explicit scope with `runInScope`
///
/// Scopes are carried on the current [Zone], so `TomScope.current` always
/// resolves to whichever scope was installed by the nearest enclosing
/// `withScope` / `runInScope` call, and is restored automatically on exit.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 01: Scope Basics Example ===\n');

  // ===========================================================================
  // Example 1: The default scope
  // ===========================================================================

  print('1. The default scope (no scope installed):');

  final defaultId = TomScope.defaultScope.id;
  final defaultPath = TomScope.defaultScope.getScopePath();
  final currentIsDefault = identical(TomScope.current, TomScope.defaultScope);

  print('   defaultScope.id: $defaultId');
  print('   defaultScope.getScopePath(): "$defaultPath" (empty — skipped)');
  print('   current == defaultScope: $currentIsDefault');
  print('');

  // ===========================================================================
  // Example 2: Installing a child scope with withScope
  // ===========================================================================

  print('2. Installing a child scope:');

  late String appScopeId;
  late String appScopePath;
  late bool appParentIsDefault;
  TomScope.withScope('app', () {
    appScopeId = TomScope.current.id;
    appScopePath = TomScope.current.getScopePath();
    appParentIsDefault = identical(TomScope.current.parent, TomScope.defaultScope);
  });

  print('   inside withScope("app"): id=$appScopeId path="$appScopePath"');
  print('   parent is defaultScope: $appParentIsDefault');
  print('');

  // ===========================================================================
  // Example 3: Nesting scopes builds a dotted path
  // ===========================================================================

  print('3. Nesting scopes:');

  late String nestedPath;
  TomScope.withScope('app', () {
    TomScope.withScope('checkout', () {
      TomScope.withScope('orderForm', () {
        nestedPath = TomScope.current.getScopePath();
      });
    });
  });

  print('   app > checkout > orderForm path: "$nestedPath"');
  print('');

  // ===========================================================================
  // Example 4: Scopes are restored on exit
  // ===========================================================================

  print('4. Scope restoration after the body returns:');

  final beforePath = TomScope.current.getScopePath();
  TomScope.withScope('temporary', () {/* do work in scope */});
  final afterPath = TomScope.current.getScopePath();

  print('   path before: "$beforePath"');
  print('   path after withScope returns: "$afterPath" (restored)');
  print('');

  // ===========================================================================
  // Example 5: Building a scope path directly
  // ===========================================================================

  print('5. Building a scope path from a chain:');

  final root = TomScopeBase(scopeId: 'app', parentScope: null);
  final mid = TomScopeBase(scopeId: 'checkout', parentScope: root);
  final leaf = TomScopeBase(scopeId: 'orderForm', parentScope: mid);
  final builtPath = TomScope.buildScopePath(leaf);

  print('   buildScopePath(app > checkout > orderForm): "$builtPath"');
  print('');

  // ===========================================================================
  // Example 6: runInScope executes a body inside an explicit scope
  // ===========================================================================

  print('6. runInScope with an explicit scope:');

  final widgetScope = TomScopeBase(scopeId: 'widget', parentScope: null);
  late bool insideIsWidget;
  widgetScope.runInScope(() {
    insideIsWidget = identical(TomScope.current, widgetScope);
  });
  final afterRunPath = TomScope.current.getScopePath();

  print('   inside runInScope, current == widgetScope: $insideIsWidget');
  print('   path after runInScope: "$afterRunPath" (restored)');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Default scope
  assert(defaultId == 'default');
  assert(defaultPath.isEmpty);
  assert(currentIsDefault);

  // Example 2: Child scope
  assert(appScopeId == 'app');
  assert(appScopePath == 'app');
  assert(appParentIsDefault);

  // Example 3: Nested path
  assert(nestedPath == 'app.checkout.orderForm');

  // Example 4: Restoration
  assert(beforePath.isEmpty);
  assert(afterPath.isEmpty);

  // Example 5: Built path
  assert(builtPath == 'app.checkout.orderForm');

  // Example 6: runInScope
  assert(insideIsWidget);
  assert(afterRunPath.isEmpty);
}
