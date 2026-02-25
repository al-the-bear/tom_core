/// Example: Observer Pattern
///
/// This example demonstrates the Observer pattern implementation:
/// - Adding observers using the >> operator
/// - Creating custom TomObserver implementations
/// - Muting and unmuting notifications
/// - Removing observers
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A custom observer that tracks the number of notifications received.
class NotificationCounter implements TomObserver<TomObservable> {
  int count = 0;
  String lastValue = '';

  @override
  void onNotify(TomObservable observable) {
    count++;
    if (observable is TomObject) {
      lastValue = observable.get().toString();
    }
  }
}

void run() {
  print('=== Observer Pattern Example ===\n');

  // --- Using >> operator to add callback observers ---
  print('1. Using >> operator to add callback observers');
  final name = TomString("Alice");
  int callbackCount = 0;
  String? lastNotifiedValue;

  // Add observer using >> operator
  final observer = name >> (obs) {
    callbackCount++;
    lastNotifiedValue = (obs as TomString).get();
    print('   Callback triggered: value is now "$lastNotifiedValue"');
  };

  assert(callbackCount == 0, "Callback should not be called yet");

  name | "Bob";
  assert(callbackCount == 1, "Callback should be called once after first change");
  assert(lastNotifiedValue == "Bob", "Last value should be 'Bob'");

  name | "Charlie";
  assert(callbackCount == 2, "Callback should be called twice after second change");
  assert(lastNotifiedValue == "Charlie", "Last value should be 'Charlie'");

  // --- Removing observers ---
  print('\n2. Removing observers');
  name.removeObserver(observer);
  name | "David";
  assert(callbackCount == 2, "Callback count should stay at 2 after observer removal");
  print('   After removing observer: callbackCount = $callbackCount (unchanged)');

  // --- Using custom TomObserver class ---
  print('\n3. Using custom TomObserver class');
  final age = TomInt(25);
  final counter = NotificationCounter();

  age.addObserver(counter);
  assert(counter.count == 0, "Counter should be 0 initially");

  age | 26;
  assert(counter.count == 1, "Counter should be 1 after first change");
  assert(counter.lastValue == "26", "Last value should be '26'");

  age | 27;
  age | 28;
  assert(counter.count == 3, "Counter should be 3 after three changes");
  print('   Counter received ${counter.count} notifications');
  print('   Last value: ${counter.lastValue}');

  // --- Muting notifications ---
  print('\n4. Muting notifications');
  final score = TomDouble(100.0);
  int muteTestCount = 0;

  score >> (obs) {
    muteTestCount++;
    print('   Score observer: muteTestCount = $muteTestCount');
  };

  score | 110.0;
  assert(muteTestCount == 1, "Should have 1 notification before mute");

  // Mute notifications
  score.mute();
  assert(score.isMuted == true, "Should be muted");
  print('   Muted. Making changes...');

  score | 120.0;
  score | 130.0;
  score | 140.0;
  assert(muteTestCount == 1, "Count should still be 1 while muted");
  assert(~score == 140.0, "Value should still change while muted");
  print('   Count while muted: $muteTestCount (unchanged)');
  print('   Value while muted: ${~score}');

  // Unmute - should trigger notification
  print('   Unmuting...');
  score.unmute();
  assert(muteTestCount == 2, "Should have 2 notifications after unmute (one deferred)");
  assert(score.isMuted == false, "Should not be muted after unmute");
  print('   Count after unmute: $muteTestCount');

  // --- Multiple observers on same observable ---
  print('\n5. Multiple observers on same observable');
  final price = TomDouble(9.99);
  int observer1Count = 0;
  int observer2Count = 0;
  int observer3Count = 0;

  price >> (obs) => observer1Count++;
  price >> (obs) => observer2Count++;
  price >> (obs) => observer3Count++;

  price | 19.99;
  assert(observer1Count == 1, "Observer 1 should be notified");
  assert(observer2Count == 1, "Observer 2 should be notified");
  assert(observer3Count == 1, "Observer 3 should be notified");
  print('   All 3 observers notified: [$observer1Count, $observer2Count, $observer3Count]');

  price | 29.99;
  assert(observer1Count == 2, "Observer 1 count should be 2");
  assert(observer2Count == 2, "Observer 2 count should be 2");
  assert(observer3Count == 2, "Observer 3 count should be 2");
  print('   After second change: [$observer1Count, $observer2Count, $observer3Count]');

  // --- No notification when value doesn't change ---
  print('\n6. No notification when value unchanged');
  final flag = TomBool(true);
  int flagCount = 0;
  flag >> (obs) => flagCount++;

  flag | true; // Same value - should not notify
  assert(flagCount == 0, "Should not notify when value unchanged");
  print('   Set same value (true): flagCount = $flagCount (unchanged)');

  flag | false; // Different value - should notify
  assert(flagCount == 1, "Should notify when value changed");
  print('   Set different value (false): flagCount = $flagCount');

  print('\n=== All assertions passed! ===');
}
