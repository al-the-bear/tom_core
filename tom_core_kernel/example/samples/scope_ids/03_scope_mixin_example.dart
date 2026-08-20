/// Demonstrates [TomScopeMixin] — the reusable implementation that turns any
/// class into a [TomScope] by storing a write-once scope identity.
///
/// `TomScopeBase` is the ready-made concrete scope, but real consumers (e.g.
/// Flutter element providers) mix [TomScopeMixin] directly into their own type
/// so that instance *is* a scope. This example shows:
/// - A custom class `with TomScopeMixin` initialised via `initScope`
/// - The custom instance participating fully as a scope (`current`, path,
///   `runInScope`, `InScopeBuilder`)
/// - `initScope` called *after* construction, for a scope whose parent is only
///   known once the enclosing scope exists
///
/// Run with (asserts MUST be enabled so the invariants below are checked):
/// ```bash
/// dart run --enable-asserts example/samples/scope_ids/03_scope_mixin_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

/// A domain object that is *itself* a scope by mixing in [TomScopeMixin].
///
/// This mirrors how Tom widgets adopt a scope: the class carries its own
/// identity and can install itself on the zone via `runInScope`.
class ScreenSection with TomScopeMixin {
  final String title;

  ScreenSection({
    required this.title,
    required String scopeId,
    TomScope? parentScope,
  }) {
    initScope(scopeId: scopeId, parentScope: parentScope);
  }
}

/// A scope that is constructed before its identity is known, and initialised
/// afterwards. [TomScopeMixin.initScope] backs `late final` fields, so it may
/// be called exactly once — from a constructor or, as here, on the instance.
class LazyScope with TomScopeMixin {}

void run() {
  print('=== 03: TomScopeMixin Example ===\n');

  // ===========================================================================
  // Example 1: A custom class becomes a scope via the mixin
  // ===========================================================================

  print('1. A custom class using TomScopeMixin is a TomScope:');

  final app = ScreenSection(title: 'App Root', scopeId: 'app');
  final checkout = ScreenSection(
    title: 'Checkout',
    scopeId: 'checkout',
    parentScope: app,
  );

  // The custom instance is usable anywhere a TomScope is expected.
  final TomScope asScope = checkout;

  print('   checkout.id: ${checkout.id}');
  print('   checkout.title: ${checkout.title}');
  print('   checkout.getScopePath(): "${checkout.getScopePath()}"');
  print('   usable as TomScope, path: "${asScope.getScopePath()}"');
  print('');

  // ===========================================================================
  // Example 2: The custom scope installs itself on the zone
  // ===========================================================================

  print('2. runInScope on the custom mixin instance:');

  late bool insideIsCheckout;
  late String insidePath;
  checkout.runInScope(() {
    insideIsCheckout = identical(TomScope.current, checkout);
    insidePath = TomScope.current.getScopePath();
  });
  final afterPath = TomScope.current.getScopePath();

  print(
    '   inside: current == checkout: $insideIsCheckout, path "$insidePath"',
  );
  print('   after runInScope: "$afterPath" (restored)');
  print('');

  // ===========================================================================
  // Example 3: The custom scope works with InScopeBuilder
  // ===========================================================================

  print('3. InScopeBuilder captures the custom scope:');

  final wrapped = InScopeBuilder(scope: checkout).wrap1<String, String>(
    (field) => '${TomScope.current.getScopePath()}.$field',
  );
  final wrappedResult = wrapped('orderForm');

  print('   wrapped("orderForm"): "$wrappedResult"');
  print('');

  // ===========================================================================
  // Example 4: initScope called after construction
  // ===========================================================================

  print('4. Assigning identity after construction:');

  final lazy = LazyScope()..initScope(scopeId: 'lazy', parentScope: app);

  print('   lazy.id: ${lazy.id}');
  print('   lazy.getScopePath(): "${lazy.getScopePath()}"');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: custom mixin class is a fully-formed scope
  assert(checkout.id == 'checkout');
  assert(checkout.title == 'Checkout');
  assert(checkout.getScopePath() == 'app.checkout');
  assert(asScope.getScopePath() == 'app.checkout');
  assert(identical(checkout.parent, app));

  // Example 2: runInScope installs and restores the custom scope
  assert(insideIsCheckout);
  assert(insidePath == 'app.checkout');
  assert(afterPath.isEmpty);

  // Example 3: InScopeBuilder observes the captured custom scope
  assert(wrappedResult == 'app.checkout.orderForm');

  // Example 4: a post-construction initScope assigns the identity
  assert(lazy.id == 'lazy');
  assert(lazy.getScopePath() == 'app.lazy');
}

/// Standalone entry point.
void main() {
  requireAsserts();
  run();
}
