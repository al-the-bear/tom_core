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
/// - What that window costs: until `initScope` runs the instance is not yet a
///   scope, and using it as one is refused on the spot
/// - Why the same rule keeps the parent chain acyclic, which the unguarded
///   walk in `buildScopePath` relies on
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
  // Example 5: the window before initScope
  // ===========================================================================
  //
  // Initialising after construction means an instance exists for a while that
  // is not yet a scope. Using it in that window is refused on the spot — an
  // uninitialised scope can neither be installed nor be another scope's
  // parent — so whatever reaches `TomScope.current` is always usable.

  print('5. Using a scope before initScope has run:');

  String refusalOf(void Function() action) {
    try {
      action();
      return '(no error)';
    } on TomScopeException catch (e) {
      return e.defaultUserMessage;
    }
  }

  final installRefusal = refusalOf(() => LazyScope().runInScope(() {}));
  final parentRefusal = refusalOf(
    () =>
        ScreenSection(title: 'Orphan', scopeId: 'x', parentScope: LazyScope()),
  );

  print('   runInScope:     $installRefusal');
  print('   as parentScope: $parentRefusal');
  print('');

  // ===========================================================================
  // Example 6: why the same rule keeps the chain acyclic
  // ===========================================================================
  //
  // `buildScopePath` walks the parent chain without a cycle guard — the walk is
  // iterative, so a loop would not overflow the stack, it would spin until the
  // heap is gone. It needs no guard because a loop cannot be built here: a
  // parent must already be initialised, which makes it strictly older than its
  // child, and the link is written once, so it stays that way.
  //
  // Closing a loop needs one of the two moves below, and both are refused.

  print('6. Attempting to bend the parent chain back on itself:');

  // Point a scope at one that does not exist yet, planning to close the loop
  // afterwards. Refused at the first half.
  final unbornParentRefusal = refusalOf(() {
    final a = LazyScope();
    final b = LazyScope();
    a.initScope(scopeId: 'a', parentScope: b);
    b.initScope(scopeId: 'b', parentScope: a);
  });

  // Re-point an established parent. `initScope` backs `late final` fields, so
  // this fails as a LateError rather than a TomScopeException.
  final child = ScreenSection(
    title: 'Child',
    scopeId: 'child',
    parentScope: app,
  );
  var rePointRefused = false;
  try {
    child.initScope(scopeId: 'child', parentScope: checkout);
  } on Error {
    rePointRefused = true;
  }

  print('   parent not yet initialised: $unbornParentRefusal');
  print('   re-pointing a parent:       refused: $rePointRefused');
  print('   child.parent unchanged:     ${identical(child.parent, app)}');
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

  // Example 5: the window is closed at the point of use, by a message that
  // names the class and the call that was skipped
  assert(installRefusal.contains('LazyScope'));
  assert(installRefusal.contains('initScope'));
  assert(parentRefusal.contains('LazyScope'));
  assert(parentRefusal.contains('initScope'));

  // Example 6: both routes to a cycle are closed, and the refused re-point
  // leaves the existing link intact
  assert(unbornParentRefusal.contains('LazyScope'));
  assert(unbornParentRefusal.contains('initScope'));
  assert(rePointRefused);
  assert(identical(child.parent, app));
}

/// Standalone entry point.
void main() {
  requireAsserts();
  run();
}
