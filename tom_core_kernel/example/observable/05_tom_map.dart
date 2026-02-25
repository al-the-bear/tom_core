/// Example: TomMap - Observable Maps
///
/// This example demonstrates TomMap:
/// - Creating and manipulating observable maps
/// - Automatic observation of map values
/// - Map operators and methods
/// - Notifications on map and value changes
///
/// NOTE: Run `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A simple UserProfile class for map examples.
@tomReflector
class UserProfile extends TomClass {
  final displayName = TomString("");
  final bio = TomNString(null);
  final followerCount = TomInt(0);
}

void run() {
  print('=== TomMap Example ===\n');

  // --- Creating TomMaps ---
  print('1. Creating TomMaps');
  final settings = TomMap<String, TomBool>();

  settings["darkMode"] = TomBool(true);
  settings["notifications"] = TomBool(false);
  settings["autoSave"] = TomBool(true);

  assert(settings.length == 3, "Map should have 3 entries");
  assert(~settings["darkMode"]! == true, "darkMode should be true");
  assert(~settings["notifications"]! == false, "notifications should be false");

  print('   settings: {');
  for (var key in settings.keys) {
    print('     $key: ${~settings[key]!}');
  }
  print('   }');

  // --- Accessing values ---
  print('\n2. Accessing values');
  final scores = TomMap<String, TomInt>();
  scores["alice"] = TomInt(95);
  scores["bob"] = TomInt(87);
  scores["charlie"] = TomInt(92);

  // Using [] operator
  assert(~scores["alice"]! == 95, "alice's score should be 95");
  print('   alice: ${~scores["alice"]!}');
  print('   bob: ${~scores["bob"]!}');

  // Null check for missing keys
  assert(scores["unknown"] == null, "Unknown key should return null");
  print('   unknown: ${scores["unknown"]}');

  // containsKey
  assert(scores.containsKey("bob"), "Should contain 'bob'");
  assert(!scores.containsKey("dave"), "Should not contain 'dave'");
  print('   containsKey("bob"): ${scores.containsKey("bob")}');

  // --- Observing map changes ---
  print('\n3. Observing map changes');
  final config = TomMap<String, TomString>();
  int mapNotifyCount = 0;

  config >> (obs) {
    mapNotifyCount++;
    print('   Map notification #$mapNotifyCount');
  };

  config["theme"] = TomString("light");
  assert(mapNotifyCount == 1, "Should notify on add");

  config["language"] = TomString("en");
  assert(mapNotifyCount == 2, "Should notify on second add");

  // Modifying a value also notifies the map
  config["theme"]! | "dark";
  assert(mapNotifyCount == 3, "Should notify when value changes");

  print('   Total notifications: $mapNotifyCount');

  // --- Updating values ---
  print('\n4. Updating values');
  final counters = TomMap<String, TomInt>();
  counters["page_views"] = TomInt(100);
  counters["clicks"] = TomInt(50);

  int updateNotifyCount = 0;
  counters >> (obs) => updateNotifyCount++;

  // Update existing key with new TomObject
  counters["page_views"] = TomInt(150);
  assert(~counters["page_views"]! == 150, "page_views should be 150");
  assert(updateNotifyCount == 1, "Should notify on replacement");

  // Modify existing value
  counters["clicks"]! | 75;
  assert(~counters["clicks"]! == 75, "clicks should be 75");
  assert(updateNotifyCount == 2, "Should notify on value change");

  print('   counters: page_views=${~counters["page_views"]!}, clicks=${~counters["clicks"]!}');

  // --- Removing entries ---
  print('\n5. Removing entries');
  final items = TomMap<String, TomDouble>();
  items["apple"] = TomDouble(1.50);
  items["banana"] = TomDouble(0.75);
  items["cherry"] = TomDouble(2.00);

  assert(items.length == 3, "Should have 3 items");

  final removed = items.remove("banana");
  assert(removed != null, "remove should return the removed value");
  assert(~removed! == 0.75, "Removed value should be 0.75");
  assert(items.length == 2, "Should have 2 items after remove");
  assert(!items.containsKey("banana"), "Should not contain 'banana'");

  print('   After remove("banana"): ${items.keys.toList()}');

  // --- Merging maps with + operator ---
  print('\n6. Merging maps with + operator');
  final map1 = TomMap<String, TomInt>();
  map1["a"] = TomInt(1);
  map1["b"] = TomInt(2);

  final map2 = TomMap<String, TomInt>();
  map2["c"] = TomInt(3);
  map2["d"] = TomInt(4);

  final merged = map1 + map2;
  assert(merged.length == 4, "Merged map should have 4 entries");
  assert(merged.containsKey("a"), "Should have key 'a'");
  assert(merged.containsKey("c"), "Should have key 'c'");
  assert(~merged["a"]! == 1, "a should be 1");
  assert(~merged["d"]! == 4, "d should be 4");

  print('   map1 + map2 keys: ${merged.keys.toList()}');

  // Original maps unchanged
  assert(map1.length == 2, "map1 should be unchanged");
  assert(map2.length == 2, "map2 should be unchanged");

  // --- Iterating over TomMap ---
  print('\n7. Iterating over TomMap');
  final prices = TomMap<String, TomDouble>();
  prices["coffee"] = TomDouble(4.50);
  prices["tea"] = TomDouble(3.00);
  prices["juice"] = TomDouble(5.25);

  print('   Prices:');
  for (var entry in prices.entries) {
    print('   - ${entry.key}: \$${~entry.value}');
  }

  // Keys and values
  print('   Keys: ${prices.keys.toList()}');
  
  final valueList = <double>[];
  for (var value in prices.values) {
    valueList.add(~value);
  }
  print('   Values: $valueList');

  // forEach
  double totalValue = 0;
  prices.forEach((key, value) {
    totalValue += ~value;
  });
  assert((totalValue - 12.75).abs() < 0.01, "Total should be 12.75");
  print('   Total: \$$totalValue');

  // --- TomMap with TomClass values ---
  print('\n8. TomMap with TomClass values');
  final users = TomMap<String, UserProfile>();
  int userMapNotify = 0;

  users >> (obs) {
    userMapNotify++;
    print('   Users map notification #$userMapNotify');
  };

  final alice = UserProfile();
  alice.displayName | "Alice";
  alice.followerCount | 1000;

  users["alice"] = alice;
  assert(userMapNotify == 1, "Should notify when adding user");

  // Modifying the user's properties notifies the map
  users["alice"]!.followerCount | 1500;
  assert(userMapNotify == 2, "Should notify when user property changes");

  users["alice"]!.bio | "Hello world!";
  assert(userMapNotify == 3, "Should notify for each property change");

  print('   alice.displayName: ${~users["alice"]!.displayName}');
  print('   alice.followerCount: ${~users["alice"]!.followerCount}');

  // --- Clearing a map ---
  print('\n9. Clearing a map');
  final clearTest = TomMap<String, TomBool>();
  clearTest["a"] = TomBool(true);
  clearTest["b"] = TomBool(false);

  assert(clearTest.length == 2, "Should have 2 entries");
  assert(clearTest.isNotEmpty, "Should not be empty");

  clearTest.clear();
  assert(clearTest.isEmpty, "Should be empty after clear");
  assert(clearTest.length == 0, "Length should be 0");
  print('   After clear(): length = ${clearTest.length}');

  // --- putIfAbsent ---
  print('\n10. Using putIfAbsent');
  final cache = TomMap<String, TomString>();
  cache["existing"] = TomString("I exist");

  final existing = cache.putIfAbsent("existing", () => TomString("New value"));
  assert(~existing == "I exist", "Should return existing value");

  final added = cache.putIfAbsent("new_key", () => TomString("I am new"));
  assert(~added == "I am new", "Should return new value");
  assert(cache.containsKey("new_key"), "Should have added new key");

  print('   existing: ${~existing}');
  print('   new_key: ${~cache["new_key"]!}');

  print('\n=== All assertions passed! ===');
}
