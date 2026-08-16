/// Demonstrates asynchronous context propagation and the full [TomZoneValues]
/// container API.
///
/// This example complements the synchronous examples (01–03) by covering the
/// two parts of the public surface they do not exercise:
///
/// - [TomExecutionContext.runInContextAsync] — context and zone values remain
///   available across `await` boundaries, including inside nested async runs.
/// - The complete [TomZoneValues] mutation API: `addAll`, `containsKey`,
///   `remove`, and `clear`, plus the `existingValues` merge constructor.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Async Context + Zone Values Example
// =============================================================================

Future<void> run() async {
  print('=== 04: Async Context & Zone Values Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Context survives an await boundary
  // ---------------------------------------------------------------------------
  print('1. Context available after await inside runInContextAsync:');

  final context = TomExecutionContext({
    'requestId': TomContextEntry<String>(() => 'req-async-001'),
  });

  final resolved = await context.runInContextAsync(() async {
    // The context is installed before the await...
    await Future<void>.delayed(Duration.zero);
    // ...and is still installed after it resumes on the microtask queue.
    final ctx = getFromCurrentZone<TomExecutionContext>();
    return ctx?.contextMap['requestId']?.contextFunction() as String?;
  });

  assert(resolved == 'req-async-001', 'context lost across await');
  print('   - Request ID after await: $resolved\n');

  // ---------------------------------------------------------------------------
  // Example 2: Nested async contexts inherit and override
  // ---------------------------------------------------------------------------
  print('2. Nested async contexts (inherit outer, inner wins on collision):');

  final outer = TomExecutionContext({
    'tenant': TomContextEntry<String>(() => 'acme'),
    'scope': TomContextEntry<String>(() => 'outer'),
  });
  final inner = TomExecutionContext({
    'scope': TomContextEntry<String>(() => 'inner'),
  });

  String? tenant;
  String? scope;

  await outer.runInContextAsync(() async {
    await inner.runInContextAsync(() async {
      await Future<void>.delayed(Duration.zero);
      final ctx = getFromCurrentZone<TomExecutionContext>();
      tenant = ctx?.contextMap['tenant']?.contextFunction() as String?;
      scope = ctx?.contextMap['scope']?.contextFunction() as String?;
    });
  });

  assert(tenant == 'acme', 'inherited outer entry lost');
  assert(scope == 'inner', 'inner context did not win on collision');
  print('   - Inherited tenant: $tenant');
  print('   - Overridden scope: $scope\n');

  // ---------------------------------------------------------------------------
  // Example 3: The full TomZoneValues mutation API
  // ---------------------------------------------------------------------------
  print('3. TomZoneValues mutation API:');

  final values = TomZoneValues({'a': 1});

  // addAll returns `this`, so calls chain.
  values.addAll({'b': 2}).addAll({'c': 3});
  assert(values.containsKey('b'), 'addAll did not add key');
  print('   - After addAll: a=${values['a']} b=${values['b']} c=${values['c']}');

  // containsKey distinguishes present from absent keys.
  assert(values.containsKey('a'), 'expected key a present');
  assert(!values.containsKey('z'), 'unexpected key z');
  print('   - containsKey("a")=${values.containsKey('a')}, '
      'containsKey("z")=${values.containsKey('z')}');

  // remove returns the removed value (or null when absent).
  final removed = values.remove('b');
  assert(removed == 2, 'remove returned wrong value');
  assert(!values.containsKey('b'), 'remove did not delete key');
  assert(values.remove('missing') == null, 'remove of absent key not null');
  print('   - remove("b") returned $removed; containsKey("b")='
      '${values.containsKey('b')}');

  // clear empties the container.
  values.clear();
  assert(!values.containsKey('a') && !values.containsKey('c'),
      'clear left entries behind');
  print('   - After clear: containsKey("a")=${values.containsKey('a')}\n');

  // ---------------------------------------------------------------------------
  // Example 4: existingValues merge (child overrides parent)
  // ---------------------------------------------------------------------------
  print('4. TomZoneValues existingValues merge:');

  final parent = TomZoneValues({'shared': 'parent', 'onlyParent': 'p'});
  final child = TomZoneValues({'shared': 'child'}, existingValues: parent);

  assert(child['shared'] == 'child', 'child did not override parent');
  assert(child['onlyParent'] == 'p', 'parent-only value not inherited');
  print('   - shared=${child['shared']} (child wins), '
      'onlyParent=${child['onlyParent']} (inherited)\n');
}
