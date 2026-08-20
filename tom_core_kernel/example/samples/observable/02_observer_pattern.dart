/// Observer Pattern Example
///
/// This example demonstrates the Observer pattern implementation:
/// - Adding observers using the >> operator
/// - Creating custom TomObserver implementations
/// - Muting and unmuting notifications
/// - Removing observers
/// - Multiple observers on same observable
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Custom Observer Class
// ============================================================================

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

// ============================================================================
// Example Class
// ============================================================================

class ObserverPatternExample {
  // Captured results
  static int callbackCount = 0;
  static String? lastNotifiedValue;
  static late NotificationCounter counter;
  static int muteTestCount = 0;
  static int observer1Count = 0;
  static int observer2Count = 0;
  static int observer3Count = 0;

  // -------------------------------------------------------------------------
  // Example 1: Using >> operator to add callback observers
  // -------------------------------------------------------------------------
  static void example1CallbackObservers() {
    print('1. Using >> operator to add callback observers:');

    final name = TomString('Alice');
    callbackCount = 0;
    lastNotifiedValue = null;

    // Add observer using >> operator
    final observer =
        name >>
        (obs) {
          callbackCount++;
          // `obs` arrives typed as TomString — `>>` is an extension on the
          // receiver's type, so no cast is needed to reach `get()`.
          lastNotifiedValue = obs.get();
          print('   Callback triggered: value is now "$lastNotifiedValue"');
        };

    name | 'Bob';
    name | 'Charlie';

    print('   Total callbacks: $callbackCount');

    // Remove observer
    name.removeObserver(observer);
    name | 'David';
    print(
      '   After removing observer: callbackCount = $callbackCount (unchanged)',
    );

    // Assertions
    assert(
      callbackCount == 2,
      'Callback should be called twice before removal',
    );
    assert(lastNotifiedValue == 'Charlie', "Last value should be 'Charlie'");
  }

  // -------------------------------------------------------------------------
  // Example 2: Using custom TomObserver class
  // -------------------------------------------------------------------------
  static void example2CustomObserver() {
    print('\n2. Using custom TomObserver class:');

    final age = TomInt(25);
    counter = NotificationCounter();

    age.addObserver(counter);

    age | 26;
    age | 27;
    age | 28;

    print('   Counter received ${counter.count} notifications');
    print('   Last value: ${counter.lastValue}');

    // Assertions
    assert(counter.count == 3, 'Counter should be 3 after three changes');
    assert(counter.lastValue == '28', "Last value should be '28'");
  }

  // -------------------------------------------------------------------------
  // Example 3: Muting notifications
  // -------------------------------------------------------------------------
  static void example3MutingNotifications() {
    print('\n3. Muting notifications:');

    final score = TomDouble(100.0);
    muteTestCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final scoreObserver =
        score >>
        (obs) {
          muteTestCount++;
          print('   Score observer: muteTestCount = $muteTestCount');
        };

    score | 110.0;
    print('   After first change: $muteTestCount notification(s)');
    assert(muteTestCount == 1, 'One change while unmuted, one notification');

    // Mute notifications
    score.mute();
    print('   Muted. isMuted = ${score.isMuted}');

    score | 120.0;
    score | 130.0;
    score | 140.0;
    print('   Count while muted: $muteTestCount (unchanged)');
    print('   Value while muted: ${~score}');
    assert(muteTestCount == 1, 'Changes while muted must not notify');

    // Unmute - should trigger notification
    print('   Unmuting...');
    score.unmute();
    print('   Count after unmute: $muteTestCount (consolidated)');

    // Assertions
    // The three muted changes collapse into exactly one notification on
    // unmute — not three replayed, and not none. That consolidation is the
    // behaviour this example exists to show, so it is asserted exactly: `>=`
    // here would pass for a mute that never suppressed anything.
    assert(
      muteTestCount == 2,
      'Unmute should deliver exactly one consolidated notification',
    );
    assert(~score == 140.0, 'Value should still change while muted');
    assert(score.isMuted == false, 'Should not be muted after unmute');

    score.removeObserver(scoreObserver);
  }

  // -------------------------------------------------------------------------
  // Example 4: Multiple observers on same observable
  // -------------------------------------------------------------------------
  static void example4MultipleObservers() {
    print('\n4. Multiple observers on same observable:');

    final price = TomDouble(9.99);
    observer1Count = 0;
    observer2Count = 0;
    observer3Count = 0;

    // Every observer must be retained — observers are held by WeakReference,
    // so a list of the returned wrappers is what keeps all three subscribed.
    final priceObservers = [
      price >> (obs) => observer1Count++,
      price >> (obs) => observer2Count++,
      price >> (obs) => observer3Count++,
    ];

    price | 19.99;
    print(
      '   After first change: [$observer1Count, $observer2Count, $observer3Count]',
    );

    price | 29.99;
    print(
      '   After second change: [$observer1Count, $observer2Count, $observer3Count]',
    );

    // Assertions
    assert(observer1Count == 2, 'Observer 1 count should be 2');
    assert(observer2Count == 2, 'Observer 2 count should be 2');
    assert(observer3Count == 2, 'Observer 3 count should be 2');

    for (final observer in priceObservers) {
      price.removeObserver(observer);
    }
  }

  // -------------------------------------------------------------------------
  // Example 5: No notification when value doesn't change
  // -------------------------------------------------------------------------
  static void example5NoNotificationUnchanged() {
    print('\n5. No notification when value unchanged:');

    final flag = TomBool(true);
    int flagCount = 0;
    final flagObserver = flag >> (obs) => flagCount++;

    flag | true; // Same value - should not notify
    print('   Set same value (true): flagCount = $flagCount (unchanged)');

    flag | false; // Different value - should notify
    print('   Set different value (false): flagCount = $flagCount');

    // Assertions
    assert(flagCount == 1, 'Should only notify when value changed');

    flag.removeObserver(flagObserver);
  }

  // -------------------------------------------------------------------------
  // Example 6: Observer returns itself for chaining
  // -------------------------------------------------------------------------
  static void example6ObserverChaining() {
    print('\n6. Observer returns itself for chaining:');

    final value = TomInt(0);
    int totalNotifications = 0;

    // Add multiple observers in a fluent style. Each `>>` returns an observer,
    // and each one must be kept: they are held weakly, so the wrappers
    // collected here are what keep both callbacks subscribed.
    final valueObservers = [
      value >>
          (obs) {
            totalNotifications++;
          },
      value >>
          (obs) {
            totalNotifications++;
          },
    ];

    value | 1;
    print('   Total notifications from 2 observers: $totalNotifications');

    // Assertions
    assert(
      totalNotifications == 2,
      'Should have 2 notifications (one per observer)',
    );

    for (final observer in valueObservers) {
      value.removeObserver(observer);
    }
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 02: Observer Pattern Example ===\n');

    example1CallbackObservers();
    example2CustomObserver();
    example3MutingNotifications();
    example4MultipleObservers();
    example5NoNotificationUnchanged();
    example6ObserverChaining();

    print('\n=== Observer Pattern Example Complete ===\n');
  }
}

void run() => ObserverPatternExample.run();

void main() {
  requireAsserts();
  run();
}
