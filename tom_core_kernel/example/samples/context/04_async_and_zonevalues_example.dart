/// Demonstrates asynchronous context propagation and the [TomZoneValues]
/// container.
///
/// Examples 01-03 cover the context itself: creating entries, reading them,
/// composing and nesting contexts, and the principal-backed providers. All of
/// that is synchronous, and none of it touches the second thing `runInContext`
/// installs in the zone. This example covers the remainder:
///
/// - [TomExecutionContext.runInContextAsync] — context and zone values remain
///   available across `await` boundaries, including inside nested async runs.
/// - The `zoneValues:` argument of `runInContext` — what it is, and what it is
///   deliberately not.
/// - The [TomZoneValues] mutation API: `[]`/`[]=`, `addAll`, `containsKey`,
///   `remove` and `clear`, plus the `existingValues` merge constructor.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Async Context + Zone Values Example
// =============================================================================

Future<void> run() async {
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
    return TomExecutionContext.getValueFromCurrentZone<String>('requestId');
  });

  assert(resolved == 'req-async-001', 'context lost across await');
  print('   - Request ID after await: $resolved');
  print('   - The body\'s return value is what runInContextAsync resolves to');

  // ---------------------------------------------------------------------------
  // Example 2: Nested async contexts inherit and override
  // ---------------------------------------------------------------------------
  print('\n2. Nested async contexts (inherit outer, inner wins on collision):');

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
      tenant = TomExecutionContext.getValueFromCurrentZone<String>('tenant');
      scope = TomExecutionContext.getValueFromCurrentZone<String>('scope');
    });
  });

  assert(tenant == 'acme', 'inherited outer entry lost');
  assert(scope == 'inner', 'inner context did not win on collision');
  print('   - Inherited tenant: $tenant');
  print('   - Overridden scope: $scope');

  // ---------------------------------------------------------------------------
  // Example 3: The zoneValues: argument of runInContext
  // ---------------------------------------------------------------------------
  print('\n3. The zoneValues: argument — mutable state beside the context:');

  var counterAfterIncrement = 0;

  TomExecutionContext({}).runInContext(
    () {
      // The argument is wrapped in a TomZoneValues container installed under
      // that type — its keys are NOT installed as zone keys. So this lookup is
      // the only one that reaches it: getValueFromCurrentZone resolves named
      // context entries, and Zone.current['initialKey'] finds nothing.
      final zoneValues = getFromCurrentZone<TomZoneValues>();

      final passedIn = zoneValues?['initialKey'];
      print('   - Value passed as zoneValues: $passedIn');
      print('   - Zone.current[\'initialKey\']: ${Zone.current['initialKey']} '
          '(the key itself is not a zone key)');

      assert(passedIn == 'initialValue', 'zoneValues argument should arrive');
      assert(Zone.current['initialKey'] == null,
          'the key itself is not installed in the zone');

      // Unlike context entries, which are read-only providers, the container is
      // mutable in place — this is where per-request scratch state lives.
      zoneValues?['counter'] = 0;
      zoneValues?['counter'] = (zoneValues['counter'] as int) + 1;
      counterAfterIncrement = zoneValues?['counter'] as int;

      print('   - Counter after in-place increment: $counterAfterIncrement');
    },
    zoneValues: {'initialKey': 'initialValue'},
  );

  assert(counterAfterIncrement == 1, 'zone values should be mutable in place');

  // ---------------------------------------------------------------------------
  // Example 4: The full TomZoneValues mutation API
  // ---------------------------------------------------------------------------
  print('\n4. TomZoneValues mutation API:');

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
  print('   - After clear: containsKey("a")=${values.containsKey('a')}');

  // ---------------------------------------------------------------------------
  // Example 5: existingValues merge (child overrides parent)
  // ---------------------------------------------------------------------------
  print('\n5. TomZoneValues existingValues merge:');

  final parent = TomZoneValues({'shared': 'parent', 'onlyParent': 'p'});
  final child = TomZoneValues({'shared': 'child'}, existingValues: parent);

  assert(child['shared'] == 'child', 'child did not override parent');
  assert(child['onlyParent'] == 'p', 'parent-only value not inherited');
  print('   - shared=${child['shared']} (child wins), '
      'onlyParent=${child['onlyParent']} (inherited)');
  print('   - Nesting a runInContext merges the container this way, just as '
      'parentContext merges the context (see example 02)');
  print('');
}

/// Standalone entry point.
Future<void> main() async => run();
