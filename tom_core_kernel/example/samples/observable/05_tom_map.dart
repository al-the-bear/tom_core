/// TomMap - Observable Maps Example
///
/// This example demonstrates TomMap:
/// - Creating and manipulating observable maps
/// - Automatic observation of map values
/// - Map operators and methods
/// - Notifications on map and value changes
/// - Merging maps with + operator
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/observable/05_tom_map.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple UserProfile class for map examples.
@tomReflector
class UserProfile extends TomClass {
  final displayName = TomString('');
  final bio = TomNString(null);
  final followerCount = TomInt(0);
}

// ============================================================================
// Example Class
// ============================================================================

class TomMapExample {
  // Captured results
  static late TomMap<String, TomBool> settings;
  static late TomMap<String, TomInt> scores;
  static late TomMap<String, UserProfile> profiles;
  static int mapNotifyCount = 0;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomMaps
  // -------------------------------------------------------------------------
  static void example1CreatingMaps() {
    print('1. Creating TomMaps:');

    settings = TomMap<String, TomBool>();

    settings['darkMode'] = TomBool(true);
    settings['notifications'] = TomBool(false);
    settings['autoSave'] = TomBool(true);

    print('   settings: {');
    for (var key in settings.keys) {
      print('     $key: ${~settings[key]!}');
    }
    print('   }');

    // Assertions
    assert(settings.length == 3, 'Map should have 3 entries');
    assert(~settings['darkMode']! == true, 'darkMode should be true');
    assert(
      ~settings['notifications']! == false,
      'notifications should be false',
    );
  }

  // -------------------------------------------------------------------------
  // Example 2: Accessing values
  // -------------------------------------------------------------------------
  static void example2AccessingValues() {
    print('\n2. Accessing values:');

    scores = TomMap<String, TomInt>();
    scores['alice'] = TomInt(95);
    scores['bob'] = TomInt(87);
    scores['charlie'] = TomInt(92);

    // Using [] operator
    print('   alice: ${~scores['alice']!}');
    print('   bob: ${~scores['bob']!}');

    // Null check for missing keys
    print('   unknown: ${scores['unknown']}');

    // containsKey
    print('   containsKey("bob"): ${scores.containsKey('bob')}');

    // Assertions
    assert(~scores['alice']! == 95, "alice's score should be 95");
    assert(scores['unknown'] == null, 'Unknown key should return null');
    assert(scores.containsKey('bob'), "Should contain 'bob'");
    assert(!scores.containsKey('dave'), "Should not contain 'dave'");
  }

  // -------------------------------------------------------------------------
  // Example 3: Observing map changes
  // -------------------------------------------------------------------------
  static void example3ObservingChanges() {
    print('\n3. Observing map changes:');

    final config = TomMap<String, TomString>();
    mapNotifyCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final configObserver =
        config >>
        (obs) {
          mapNotifyCount++;
          print('   Map notification #$mapNotifyCount');
        };

    config['theme'] = TomString('light');
    config['language'] = TomString('en');

    // Modifying a value also notifies the map
    config['theme']! | 'dark';

    print('   Total notifications: $mapNotifyCount');

    // Assertions
    assert(mapNotifyCount == 3, 'Should notify on add and value change');
    assert(~config['theme']! == 'dark', 'Theme should be dark');

    config.removeObserver(configObserver);
  }

  // -------------------------------------------------------------------------
  // Example 4: Updating values
  // -------------------------------------------------------------------------
  static void example4UpdatingValues() {
    print('\n4. Updating values:');

    final counters = TomMap<String, TomInt>();
    counters['page_views'] = TomInt(100);
    counters['clicks'] = TomInt(50);

    int updateNotifyCount = 0;
    final countersObserver = counters >> (obs) => updateNotifyCount++;

    // Update existing key with new TomObject
    counters['page_views'] = TomInt(150);

    // Modify existing value
    counters['clicks']! | 75;

    print(
      '   counters: page_views=${~counters['page_views']!}, clicks=${~counters['clicks']!}',
    );
    print('   Total notifications: $updateNotifyCount');

    // Assertions
    assert(~counters['page_views']! == 150, 'page_views should be 150');
    assert(~counters['clicks']! == 75, 'clicks should be 75');
    assert(
      updateNotifyCount == 2,
      'Should notify on replacement and value change',
    );

    counters.removeObserver(countersObserver);
  }

  // -------------------------------------------------------------------------
  // Example 5: Removing entries
  // -------------------------------------------------------------------------
  static void example5RemovingEntries() {
    print('\n5. Removing entries:');

    final items = TomMap<String, TomDouble>();
    items['apple'] = TomDouble(1.50);
    items['banana'] = TomDouble(0.75);
    items['cherry'] = TomDouble(2.00);

    print('   Before: ${items.keys.toList()}');

    final removed = items.remove('banana');
    print('   After remove("banana"): ${items.keys.toList()}');
    print('   Removed value: ${removed != null ? ~removed : null}');

    // Assertions
    assert(removed != null, 'remove should return the removed value');
    assert(~removed! == 0.75, 'Removed value should be 0.75');
    assert(items.length == 2, 'Should have 2 items after remove');
    assert(!items.containsKey('banana'), "Should not contain 'banana'");
  }

  // -------------------------------------------------------------------------
  // Example 6: Merging maps with + operator
  // -------------------------------------------------------------------------
  static void example6MergingMaps() {
    print('\n6. Merging maps with + operator:');

    final map1 = TomMap<String, TomInt>();
    map1['a'] = TomInt(1);
    map1['b'] = TomInt(2);

    final map2 = TomMap<String, TomInt>();
    map2['c'] = TomInt(3);
    map2['d'] = TomInt(4);

    final merged = map1 + map2;
    print('   map1 + map2 keys: ${merged.keys.toList()}');

    // Original maps unchanged
    print('   map1.length: ${map1.length}, map2.length: ${map2.length}');

    // Assertions
    assert(merged.length == 4, 'Merged map should have 4 entries');
    assert(merged.containsKey('a'), "Should have key 'a'");
    assert(merged.containsKey('c'), "Should have key 'c'");
    assert(~merged['a']! == 1, 'a should be 1');
    assert(map1.length == 2, 'map1 should be unchanged');
  }

  // -------------------------------------------------------------------------
  // Example 7: Iterating over TomMap
  // -------------------------------------------------------------------------
  static void example7Iterating() {
    print('\n7. Iterating over TomMap:');

    final prices = TomMap<String, TomDouble>();
    prices['coffee'] = TomDouble(4.50);
    prices['tea'] = TomDouble(3.00);
    prices['juice'] = TomDouble(5.50);

    print('   Prices:');
    for (var key in prices.keys) {
      print('   - $key: \$${~prices[key]!}');
    }

    // Sum using fold
    double total = 0;
    for (var key in prices.keys) {
      total += ~prices[key]!;
    }
    print('   Total: \$$total');

    // Assertions
    assert(prices.length == 3, 'Should have 3 prices');
    assert(total == 13.0, 'Total should be 13.0');
  }

  // -------------------------------------------------------------------------
  // Example 8: TomMap with TomClass values
  // -------------------------------------------------------------------------
  static void example8TomClassValues() {
    print('\n8. TomMap with TomClass values:');

    profiles = TomMap<String, UserProfile>();

    final profile1 = UserProfile();
    profile1.displayName | 'Alice';
    profile1.bio | 'Software Developer';
    profile1.followerCount | 1000;
    profiles['alice'] = profile1;

    final profile2 = UserProfile();
    profile2.displayName | 'Bob';
    profile2.followerCount | 500;
    profiles['bob'] = profile2;

    print('   Profiles:');
    for (var key in profiles.keys) {
      final p = profiles[key]!;
      print('   - $key: ${~p.displayName} (${~p.followerCount} followers)');
    }

    // Modify a profile
    profiles['alice']!.followerCount | 1100;
    print('   Alice new follower count: ${~profiles['alice']!.followerCount}');

    // Assertions
    assert(profiles.length == 2, 'Should have 2 profiles');
    assert(
      ~profiles['alice']!.displayName == 'Alice',
      'Alice display name should match',
    );
    assert(
      ~profiles['alice']!.followerCount == 1100,
      'Alice follower count should be updated',
    );
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 05: TomMap Example ===\n');

    example1CreatingMaps();
    example2AccessingValues();
    example3ObservingChanges();
    example4UpdatingValues();
    example5RemovingEntries();
    example6MergingMaps();
    example7Iterating();
    example8TomClassValues();

    print('\n=== TomMap Example Complete ===\n');
  }
}

void run() => TomMapExample.run();

void main() {
  bootstrapSamples();
  run();
}
