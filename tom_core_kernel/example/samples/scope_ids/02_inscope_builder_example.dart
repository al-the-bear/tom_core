/// Demonstrates [InScopeBuilder] — captures the active [TomScope] at
/// construction time and wraps callbacks so they run inside that scope even
/// when invoked later from an unrelated zone (e.g. a Flutter `itemBuilder`).
///
/// This example covers:
/// - Capturing the current scope at construction
/// - Wrapping a 0/1-argument callback with `wrap0` / `wrap1`
/// - Restoring the captured scope when the callback runs outside its zone
/// - Passing an explicit scope instead of the ambient one
/// - The nullable wrappers (`wrap1n`) returning `null` for `null` input
/// - The named-parameter `wrapCounter` variant
///
/// The core guarantee: the wrapped callback always observes the scope that was
/// current when the [InScopeBuilder] was built, regardless of where it is
/// finally called.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 02: InScopeBuilder Example ===\n');

  // ===========================================================================
  // Example 1: Capture the current scope at construction
  // ===========================================================================

  print('1. Wrapping a callback captures the current scope:');

  // Build the wrapper *inside* a scope, then invoke it *outside* that scope.
  late String Function() wrapped0;
  TomScope.withScope('app', () {
    TomScope.withScope('checkout', () {
      final builder = InScopeBuilder();
      wrapped0 = builder.wrap0<String>(() => TomScope.current.getScopePath());
    });
  });

  // We are now back at the default scope — but the wrapped callback still sees
  // the scope that was active when it was wrapped.
  final outsideScopePath = TomScope.current.getScopePath();
  final wrappedResult = wrapped0();

  print('   scope when wrapped0() is called: "$outsideScopePath" (default)');
  print('   path observed inside wrapped0():  "$wrappedResult" (restored)');
  print('');

  // ===========================================================================
  // Example 2: Wrapping a 1-argument callback
  // ===========================================================================

  print('2. wrap1 forwards the argument and restores the scope:');

  late String Function(int) wrapped1;
  TomScope.withScope('list', () {
    final builder = InScopeBuilder();
    wrapped1 = builder.wrap1<String, int>(
      (index) => '${TomScope.current.getScopePath()}#$index',
    );
  });

  final wrapped1Result = wrapped1(7);

  print('   wrapped1(7): "$wrapped1Result"');
  print('');

  // ===========================================================================
  // Example 3: Passing an explicit scope
  // ===========================================================================

  print('3. An explicit scope overrides the ambient one:');

  final explicitScope = TomScopeBase(scopeId: 'widget', parentScope: null);
  final explicitBuilder = InScopeBuilder(scope: explicitScope);
  final explicitWrapped = explicitBuilder.wrap0<String>(
    () => TomScope.current.getScopePath(),
  );

  final explicitResult = explicitWrapped();

  print('   explicit scope path observed: "$explicitResult"');
  print('');

  // ===========================================================================
  // Example 4: Nullable wrappers pass null through
  // ===========================================================================

  print('4. wrap1n returns null for a null callback:');

  final nullableBuilder = InScopeBuilder(scope: explicitScope);
  final String Function(int)? nullWrapped = nullableBuilder.wrap1n<String, int>(null);
  final String Function(int)? realWrapped =
      nullableBuilder.wrap1n<String, int>((i) => 'value:$i');

  print('   wrap1n(null) is null: ${nullWrapped == null}');
  print('   wrap1n(fn)(3): "${realWrapped!(3)}"');
  print('');

  // ===========================================================================
  // Example 5: The named-parameter wrapCounter variant
  // ===========================================================================

  print('5. wrapCounter handles a callback with named parameters:');

  final counterScope = TomScopeBase(scopeId: 'form', parentScope: null);
  final counterBuilder = InScopeBuilder(scope: counterScope);
  final counter = counterBuilder.wrapCounter<String, String, int, int, bool>(
    (label, {required currentLength, required maxLength, required isFocused}) =>
        '${TomScope.current.getScopePath()}:$label $currentLength/$maxLength',
  );

  final counterResult =
      counter('chars', currentLength: 4, maxLength: 10, isFocused: true);

  print('   wrapCounter result: "$counterResult"');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: scope captured at construction, restored on invocation
  assert(outsideScopePath.isEmpty);
  assert(wrappedResult == 'app.checkout');

  // Example 2: argument forwarded, scope restored
  assert(wrapped1Result == 'list#7');

  // Example 3: explicit scope used
  assert(explicitResult == 'widget');

  // Example 4: nullable wrappers
  assert(nullWrapped == null);
  assert(realWrapped(3) == 'value:3');

  // Example 5: named-parameter wrapper
  assert(counterResult == 'form:chars 4/10');
}

/// Standalone entry point.
void main() => run();
