/// Comprehensive tests for the observable functionality in tom_observable.dart
/// and tom_observable_objects.dart
///
/// Run: `dart run build_runner build` before executing these tests.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'observable_test.reflection.dart';

// ============================================================================
// Test Classes
// ============================================================================

/// Simple test class for TomClass tests
@tomReflector
class TestPerson extends TomClass {
  final name = TomString("");
  final age = TomInt(0);
  final email = TomNString(null);
  final isActive = TomBool(true);
}

/// Test class whose second member is registered only after it is assigned and
/// `startSelfObservation()` is re-run — the lazy-member pattern, which is what
/// makes `getMembers()`'s view observably different from a cached copy.
@tomReflector
class TestLateMember extends TomClass {
  final name = TomString("");
  TomInt? bonus;
}

/// Test class with nested TomClass
@tomReflector
class TestAddress extends TomClass {
  final street = TomString("");
  final city = TomString("");
  final zipCode = TomString("");
}

@tomReflector
class TestCustomer extends TomClass {
  final customerId = TomString("");
  final name = TomString("");
  final address = TestAddress();
}

/// Test class for TomList with TomClass elements
@tomReflector
class TestTask extends TomClass {
  final title = TomString("");
  final completed = TomBool(false);
  final priority = TomInt(0);
}

/// Test class exercising `TomList` element serialization: a
/// `TomList<TomString>` (scalar elements) and a `TomList<TestTask>` (nested
/// `TomClass` elements). A `toJson()` that recurses into a nested `TomClass`
/// field but not into a `TomList`'s elements leaves raw `TomObject`s in the
/// map, so `jsonEncode` throws `JsonUnsupportedObjectError`.
@tomReflector
class TestTaggedItem extends TomClass {
  final title = TomString("");
  final tags = TomList<TomString>();
  final subtasks = TomList<TestTask>();
}

/// Test class exercising fractional and integral numbers across every shape a
/// deserialized member can take: a scalar `TomDouble`, its nullable sibling, a
/// `TomList<TomDouble>` and a `TomMap<String, TomDouble>`, with `TomInt`
/// alongside so that widening a number to `double` cannot be shown to swallow
/// genuine integers.
@tomReflector
class TestPricedItem extends TomClass {
  final price = TomDouble(0);
  final discount = TomNDouble(null);
  final quantity = TomInt(0);
  final rates = TomList<TomDouble>();
  final surcharges = TomMap<String, TomDouble>();
  final counts = TomList<TomInt>();
}

/// Container members whose element type is left as the base [TomObject].
///
/// `TomList<TomObject>` means `TomList<TomObject<dynamic>>`, so the element
/// type accepts anything and commits to nothing. That is the only member shape
/// a nested `TomMap`/`TomList` element could be deserialized into, and it is
/// what pins the half of the widening rule that says an element type merely
/// *accepting* a double is not a reason to produce one.
/// Container members whose element type is a *nullable* leaf wrapper.
///
/// `_createFrom` builds only the non-nullable leaves, so before the element
/// factory learned the destination type these members rejected every payload
/// they were given, and a JSON `null` had no representation among them at all.
@tomReflector
class TestNullableElements extends TomClass {
  final tags = TomList<TomNString>();
  final rates = TomList<TomNDouble>();
  final counts = TomList<TomNInt>();
  final flags = TomList<TomNBool>();
  final stamps = TomList<TomNDateTime>();
  final labels = TomMap<String, TomNString>();
  final amounts = TomMap<String, TomNDouble>();
  final zoned = TomList<TomNOZonedDateTime>();
}

@tomReflector
class TestUntypedContainers extends TomClass {
  final anyList = TomList<TomObject>();
  final anyMap = TomMap<String, TomObject>();
}

/// Test class whose only non-scalar member is a nested [TomClass] carrying
/// collections of its own.
///
/// [TomClass.setOrMergeValues] hands its `merge` flag down to a nested class
/// unchanged, and that recursion is only observable when the nested class has
/// a member the flag actually affects — scalars are replaced either way.
@tomReflector
class TestInventory extends TomClass {
  final label = TomString("");
  final item = TestPricedItem();
}

/// Test class for TomMap with TomClass values
@tomReflector
class TestUserProfile extends TomClass {
  final displayName = TomString("");
  final bio = TomNString(null);
  final followerCount = TomInt(0);
}

/// A [TomString] whose [get] always throws, used to verify that
/// [TomClass.getValues] surfaces a serialization failure instead of silently
/// swallowing it into partial data.
///
/// The field that holds it is statically typed [TomString] in
/// [TestThrowingMember] so the reflection generator never references this
/// private subtype; only the runtime instance throws.
class _ThrowingString extends TomString {
  _ThrowingString() : super("");

  @override
  String get() => throw StateError('member serialization boom');
}

/// Test class with one member whose serialization throws.
@tomReflector
class TestThrowingMember extends TomClass {
  final TomString throwingField = _ThrowingString();
  final ok = TomString("fine");
}

/// Test class carrying one member of every timezone-aware observable type,
/// nullable and non-nullable, for round-tripping through [TomClass.getValues]
/// and [TomClass.setValues].
@tomReflector
class TestZonedMembers extends TomClass {
  final date = TomOZonedDate(
    TomZonedDate(year: 2024, month: 6, day: 15, timezone: TomTimezone.utc),
  );
  final time = TomOZonedTime(
    TomZonedTime(hour: 14, minute: 30, second: 45, timezone: TomTimezone.utc),
  );
  final dateTime = TomOZonedDateTime(
    TomZonedDateTime(
      year: 2024,
      month: 12,
      day: 25,
      hour: 18,
      timezone: TomTimezone.utc,
    ),
  );
  final optionalDate = TomNOZonedDate(null);
  final optionalTime = TomNOZonedTime(null);
  final optionalDateTime = TomNOZonedDateTime(null);

  /// A plain (zone-less) member alongside the zoned ones, so that one round
  /// trip exercises both dispatch branches.
  final stamp = TomDateTime(DateTime.utc(2020));
}

/// Test class whose members are *containers* of temporal elements, one per
/// serialization prefix the wire format defines.
///
/// Container elements are the only way to reach `TomObject._createFrom`
/// with a prefixed string. A scalar member is written into the cell that
/// already exists, so it dispatches on the member's own type and never has to
/// recover a type from the string; an element has no cell yet, so the prefix is
/// the only clue there is.
@tomReflector
class TestZonedElements extends TomClass {
  final dates = TomList<TomOZonedDate>();
  final times = TomList<TomOZonedTime>();
  final dateTimes = TomList<TomOZonedDateTime>();
  final stamps = TomList<TomDateTime>();
  final plain = TomList<TomString>();
}

/// Test class whose observable lives in a private field and is published
/// through a public getter.
///
/// Reflection excludes private fields and private accessors, so the member
/// registers under the **public getter name**. This is the whole reason
/// [TomClass.setOrMergeValues] needs no underscore-prefixed fallback lookup:
/// an underscore-prefixed key can never appear in the member map to be found.
@tomReflector
class TestPrivateBackedMember extends TomClass {
  final TomString _label = TomString("");
  final visible = TomInt(0);

  TomString get label => _label;
}

/// Custom observer implementation for testing
class TestObserver<T extends TomObservable> implements TomObserver<T> {
  int notifyCount = 0;
  T? lastObservable;

  @override
  void onNotify(T observable) {
    notifyCount++;
    lastObservable = observable;
  }

  void reset() {
    notifyCount = 0;
    lastObservable = null;
  }
}

/// An observer that declares itself equal to every other instance of its kind.
///
/// Registration keys on *identity*, not on `==`, so two of these are two
/// observers however equal they claim to be. Kept as a distinct type so the
/// pathological equality cannot leak into the tests that use [TestObserver].
class AlwaysEqualObserver extends TestObserver<TomObservable> {
  @override
  bool operator ==(Object other) => other is AlwaysEqualObserver;

  @override
  int get hashCode => 0;
}

/// Registers an observer with [observable] and returns a weak handle on it,
/// keeping no strong reference of its own.
///
/// A local variable in a test body can stay reachable from the frame for the
/// rest of the test, which would defeat the point; going through a function
/// that returns leaves the observable's own weak reference as the only one.
WeakReference<TomObserver> registerTransientObserver(TomObservable observable) {
  final observer = TestObserver<TomObservable>();
  observable.addObserver(observer);
  return WeakReference(observer);
}

/// Allocates until [probe]'s target has been collected, or a budget runs out.
///
/// The VM offers no way to demand a collection, so this makes one likely by
/// producing garbage, and reports whether it worked. A caller must treat
/// `false` as "could not observe", not as a failure — see the pruning test.
Future<bool> collectGarbageUntilCleared(WeakReference<Object> probe) async {
  final sink = <List<int>>[];
  for (var round = 0; round < 60 && probe.target != null; round++) {
    sink.add(List.filled(2000000, round));
    if (sink.length > 3) sink.removeAt(0);
    await Future<void>.delayed(Duration.zero);
  }
  return probe.target == null;
}

/// Reifies the *static* type the analyzer inferred for [value].
///
/// `value.runtimeType` would answer a different question — what the object
/// happens to be — and would pass even if the expression had been typed
/// `dynamic`. Binding the type parameter to the argument's static type and
/// returning it is the only way to assert what the compiler concluded.
Type staticTypeOf<X>(X value) => X;

// ============================================================================
// Tests
// ============================================================================

void main() {
  initializeReflection();
  tz.initializeTimeZones();

  group('TomObservable', () {
    test('addObserver and notifyObservers', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();

      observable.addObserver(observer);
      expect(observer.notifyCount, equals(0));

      observable.notifyObservers();
      expect(observer.notifyCount, equals(1));

      observable.notifyObservers();
      expect(observer.notifyCount, equals(2));
    });

    test('removeObserver stops notifications', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();

      observable.addObserver(observer);
      observable.notifyObservers();
      expect(observer.notifyCount, equals(1));

      observable.removeObserver(observer);
      observable.notifyObservers();
      expect(observer.notifyCount, equals(1)); // Should not increase
    });

    test('mute and unmute', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();

      observable.addObserver(observer);

      observable.mute();
      expect(observable.isMuted, isTrue);

      observable.notifyObservers();
      expect(observer.notifyCount, equals(0)); // Should not notify while muted

      observable.unmute();
      expect(observable.isMuted, isFalse);
      expect(
        observer.notifyCount,
        equals(1),
      ); // Should notify on unmute if dirty
    });

    test('>> operator adds callback observer', () {
      final observable = TomObservable();
      int callbackCount = 0;

      observable >>
          (obs) {
            callbackCount++;
          };

      observable.notifyObservers();
      expect(callbackCount, equals(1));

      observable.notifyObservers();
      expect(callbackCount, equals(2));
    });

    test('>> operator returns removable observer', () {
      final observable = TomObservable();
      int callbackCount = 0;

      final observer =
          observable >>
          (obs) {
            callbackCount++;
          };

      observable.notifyObservers();
      expect(callbackCount, equals(1));

      observable.removeObserver(observer);
      observable.notifyObservers();
      expect(callbackCount, equals(1)); // Should not increase
    });

    test('multiple observers are all notified', () {
      final observable = TomObservable();
      final observer1 = TestObserver<TomObservable>();
      final observer2 = TestObserver<TomObservable>();
      final observer3 = TestObserver<TomObservable>();

      observable.addObserver(observer1);
      observable.addObserver(observer2);
      observable.addObserver(observer3);

      observable.notifyObservers();

      expect(observer1.notifyCount, equals(1));
      expect(observer2.notifyCount, equals(1));
      expect(observer3.notifyCount, equals(1));
    });

    test('duplicate observer registration is ignored', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();

      observable.addObserver(observer);
      observable.addObserver(observer); // Duplicate

      observable.notifyObservers();
      expect(observer.notifyCount, equals(1)); // Should only notify once
    });
  });

  group('observer registration scales linearly', () {
    // `addObserver` used to scan the whole observer list looking for an
    // existing weak reference before appending, so attaching n observers cost
    // O(n^2) comparisons. That is invisible for the handful of observers a
    // typical cell carries and very visible for a `TomList`, which registers
    // itself with every element: a thousand-element `resetWith` paid the cost
    // in full.
    //
    // An algorithmic class is only observable from outside as a shape, so this
    // asserts a *ratio* rather than a duration — the machine cancels out.
    // Quadratic growth multiplies the time by ~16 when the count quadruples;
    // linear growth multiplies it by ~4. The threshold sits between the two,
    // well clear of both.

    /// Microseconds spent registering [count] fresh observers, best of five
    /// runs so one GC pause cannot decide the result. The observers are built
    /// before the clock starts: allocation is not what is being measured.
    int registrationMicros(int count) {
      var best = -1;
      for (var run = 0; run < 5; run++) {
        final observable = TomObservable();
        final observers = List.generate(
          count,
          (_) => TestObserver<TomObservable>(),
        );
        final stopwatch = Stopwatch()..start();
        for (final observer in observers) {
          observable.addObserver(observer);
        }
        stopwatch.stop();
        final micros = stopwatch.elapsedMicroseconds;
        if (best < 0 || micros < best) best = micros;
      }
      return best;
    }

    test(
      'registering 10,000 observers costs ~4x registering 2,500, not ~16x',
      () {
        registrationMicros(500); // warm the JIT before the readings that count

        final small = registrationMicros(2500);
        final large = registrationMicros(10000);

        // A zero reading would make the ratio meaningless; one microsecond is
        // below anything measurable here, so floor the divisor.
        final ratio = large / (small < 1 ? 1 : small);

        expect(
          ratio,
          lessThan(8.0),
          reason:
              'quadrupling the observer count multiplied the registration '
              'time by ${ratio.toStringAsFixed(1)}x '
              '(${small}us for 2500 -> ${large}us for 10000). Linear growth is '
              '~4x; anything approaching 16x means the registration path is '
              'still scanning the observer list.',
        );
      },
    );

    test(
      'every one of 10,000 registered observers is notified exactly once',
      () {
        final observable = TomObservable();
        final observers = List.generate(
          10000,
          (_) => TestObserver<TomObservable>(),
        );
        for (final observer in observers) {
          observable.addObserver(observer);
        }

        observable.notifyObservers();

        expect(observers.where((o) => o.notifyCount != 1), isEmpty);
      },
    );

    test('re-registering all 10,000 attaches none of them a second time', () {
      final observable = TomObservable();
      final observers = List.generate(
        10000,
        (_) => TestObserver<TomObservable>(),
      );
      for (final observer in observers) {
        observable.addObserver(observer);
      }
      for (final observer in observers) {
        observable.addObserver(observer); // every one a duplicate
      }

      observable.notifyObservers();

      expect(observers.where((o) => o.notifyCount != 1), isEmpty);
    });

    test('observers are notified in registration order', () {
      final observable = TomObservable();
      final order = <int>[];
      final observers = List.generate(
        200,
        (index) => TomFunctionObserver<TomObservable>((_) {
          order.add(index);
        }),
      );
      for (final observer in observers) {
        observable.addObserver(observer);
      }

      observable.notifyObservers();

      expect(order, equals(List.generate(200, (index) => index)));
    });

    test('registration keys on identity, not on ==', () {
      // Two observers that declare themselves equal are still two observers.
      final observable = TomObservable();
      final first = AlwaysEqualObserver();
      final second = AlwaysEqualObserver();
      expect(first, equals(second), reason: 'precondition for this test');

      observable.addObserver(first);
      observable.addObserver(second);
      observable.notifyObservers();

      expect(first.notifyCount, equals(1));
      expect(second.notifyCount, equals(1));
    });

    test(
      'removing one of two ==-equal observers leaves the other attached',
      () {
        final observable = TomObservable();
        final kept = AlwaysEqualObserver();
        final dropped = AlwaysEqualObserver();
        observable.addObserver(kept);
        observable.addObserver(dropped);

        observable.removeObserver(dropped);
        observable.notifyObservers();

        expect(kept.notifyCount, equals(1));
        expect(dropped.notifyCount, equals(0));
      },
    );

    test(
      'collecting registered observers does not disturb the survivors',
      () async {
        // The pruning path is the one place where a handle has to be found in
        // the set *after* its target is gone, so it is worth exercising even
        // though the collector cannot be commanded.
        final observable = TomObservable();
        final retained = TestObserver<TomObservable>();
        observable.addObserver(retained);

        final probe = registerTransientObserver(observable);
        for (var i = 0; i < 500; i++) {
          registerTransientObserver(observable);
        }

        if (!await collectGarbageUntilCleared(probe)) {
          markTestSkipped(
            'the VM did not collect the dropped observers, so '
            'there is nothing here to observe',
          );
          return;
        }

        observable.notifyObservers(); // sees the dead handles and prunes them
        expect(retained.notifyCount, equals(1));

        final late = TestObserver<TomObservable>();
        observable.addObserver(late);
        observable.notifyObservers();

        expect(late.notifyCount, equals(1));
        expect(retained.notifyCount, equals(2));
      },
    );
  });

  group('>> is typed to the observable it is applied to', () {
    test('the returned handle keeps the receiver type', () {
      final count = TomInt(0);
      final observer = count >> (obs) {};

      expect(staticTypeOf(observer), equals(TomFunctionObserver<TomInt>));
    });

    test('the callback receives the observable at the receiver type', () {
      final count = TomInt(0);
      int? seen;
      // `obs.get()` returns `int`, not `Object?` — this line only compiles
      // because the parameter is a TomInt, which is the whole point.
      final observer = count >> (obs) => seen = obs.get();

      count | 7;

      expect(seen, equals(7));
      expect(observer, isNotNull); // retain: observers are held weakly
    });

    test('a user-defined TomClass gets its own type, not TomClass', () {
      final person = TestPerson();
      String? seen;
      final observer = person >> (obs) => seen = obs.name.get();

      expect(staticTypeOf(observer), equals(TomFunctionObserver<TestPerson>));

      person.name | 'Ada';

      expect(seen, equals('Ada'));
    });

    test('a collection is typed with its element type', () {
      final names = TomList<TomString>();
      final observer = names >> (obs) {};

      expect(
        staticTypeOf(observer),
        equals(TomFunctionObserver<TomList<TomString>>),
      );
    });

    test('a callback written against the base type is still accepted', () {
      // Function types are contravariant in their parameters, so the old
      // `(TomObservable obs) { ... }` form keeps compiling against the
      // narrower `void Function(TomInt)` the operator now asks for.
      final count = TomInt(0);
      TomObservable? seen;
      final observer = count >> (TomObservable obs) => seen = obs;

      count | 1;

      expect(identical(seen, count), isTrue);
      expect(staticTypeOf(observer), equals(TomFunctionObserver<TomInt>));
    });

    test('the handle can be passed back to removeObserver', () {
      final count = TomInt(0);
      var notifications = 0;
      final observer = count >> (obs) => notifications++;

      count | 1;
      count.removeObserver(observer);
      count | 2;

      expect(notifications, equals(1));
    });

    test('a narrowed observer rejects a foreign observable when notified', () {
      // The narrowing has a runtime edge: registering an observer built for a
      // TomInt on a TomString type-checks (addObserver takes the base type)
      // but fails when the notification arrives. That is the correct outcome —
      // the callback was written against a TomInt and cannot run — and it now
      // surfaces where before the callback would have been handed a value of
      // an unexpected type.
      final count = TomInt(0);
      final label = TomString('');
      final observer = count >> (obs) => obs.get();

      label.addObserver(observer);

      expect(() => label.notifyObservers(), throwsA(isA<TypeError>()));
    });

    test('TomFunctionObserver is reflected like its neighbours', () {
      // Everything around it in the module carries @tomReflector; a hole in
      // the reflected graph breaks anything that walks it (serialization, the
      // Forge inspectors).
      expect(tomReflector.reflectType(TomFunctionObserver), isA<ClassMirror>());
    });
  });

  group('TomObject', () {
    test('constructor sets initial value', () {
      final obj = TomObject<String>("test");
      expect(obj.get(), equals("test"));
    });

    test('get() returns current value', () {
      final obj = TomInt(42);
      expect(obj.get(), equals(42));
    });

    test('set() updates value and notifies', () {
      final obj = TomString("initial");
      int notifyCount = 0;

      obj >> (obs) => notifyCount++;

      obj.set("updated");
      expect(obj.get(), equals("updated"));
      expect(notifyCount, equals(1));
    });

    test('set() does not notify if value unchanged', () {
      final obj = TomString("value");
      int notifyCount = 0;

      obj >> (obs) => notifyCount++;

      obj.set("value"); // Same value
      expect(notifyCount, equals(0));
    });

    test('~ operator gets value', () {
      final obj = TomInt(100);
      expect(~obj, equals(100));
    });

    test('call operator () gets value', () {
      final obj = TomDouble(3.14);
      expect(obj(), equals(3.14));
    });

    test('| operator sets value', () {
      final obj = TomBool(false);
      obj | true;
      expect(~obj, isTrue);
    });

    test('isNull returns true for null values', () {
      final obj = TomNString(null);
      expect(obj.isNull, isTrue);

      obj | "not null";
      expect(obj.isNull, isFalse);
    });

    test('getOrNull returns null for null values', () {
      final obj = TomNInt(null);
      expect(obj.getOrNull(), isNull);

      obj | 42;
      expect(obj.getOrNull(), equals(42));
    });
  });

  group('TomString', () {
    test('holds string value', () {
      final str = TomString("hello");
      expect(~str, equals("hello"));
    });

    test('can be updated', () {
      final str = TomString("hello");
      str | "world";
      expect(~str, equals("world"));
    });
  });

  group('TomInt', () {
    test('holds int value', () {
      final num = TomInt(42);
      expect(~num, equals(42));
    });

    test('can be updated', () {
      final num = TomInt(0);
      num | 100;
      expect(~num, equals(100));
    });
  });

  group('TomDouble', () {
    test('holds double value', () {
      final num = TomDouble(3.14159);
      expect(~num, closeTo(3.14159, 0.0001));
    });

    test('can be updated', () {
      final num = TomDouble(0.0);
      num | 2.718;
      expect(~num, closeTo(2.718, 0.001));
    });
  });

  group('TomBool', () {
    test('holds bool value', () {
      final flag = TomBool(true);
      expect(~flag, isTrue);
    });

    test('can be updated', () {
      final flag = TomBool(true);
      flag | false;
      expect(~flag, isFalse);
    });
  });

  group('TomDateTime', () {
    test('holds DateTime value', () {
      final dt = DateTime(2024, 1, 15);
      final tom = TomDateTime(dt);
      expect(~tom, equals(dt));
    });

    test('has serialization prefix', () {
      expect(TomDateTime.serializationPrefix, equals("@!@"));
    });
  });

  group('Nullable Types', () {
    test('TomNString handles null', () {
      final str = TomNString(null);
      expect(str.isNull, isTrue);
      expect(str.getOrNull(), isNull);

      str | "value";
      expect(str.isNull, isFalse);
      expect(~str, equals("value"));
    });

    test('TomNInt handles null', () {
      final num = TomNInt(null);
      expect(num.isNull, isTrue);

      num | 42;
      expect(~num, equals(42));
    });

    test('TomNDouble handles null', () {
      final num = TomNDouble(null);
      expect(num.isNull, isTrue);

      num | 3.14;
      expect(~num, closeTo(3.14, 0.01));
    });

    test('TomNBool handles null', () {
      final flag = TomNBool(null);
      expect(flag.isNull, isTrue);

      flag | true;
      expect(~flag, isTrue);
    });

    test('TomNDateTime handles null', () {
      final dt = TomNDateTime(null);
      expect(dt.isNull, isTrue);

      final now = DateTime.now();
      dt | now;
      expect(~dt, equals(now));
    });
  });

  group('TomClass', () {
    test('auto-registers members', () {
      final person = TestPerson();
      final members = person.getMembers();

      expect(members.containsKey('name'), isTrue);
      expect(members.containsKey('age'), isTrue);
      expect(members.containsKey('email'), isTrue);
      expect(members.containsKey('isActive'), isTrue);
    });

    test('notifies when member changes', () {
      final person = TestPerson();
      int notifyCount = 0;

      person >> (obs) => notifyCount++;

      person.name | "John";
      expect(notifyCount, equals(1));

      person.age | 30;
      expect(notifyCount, equals(2));
    });

    test('setValues updates multiple fields', () {
      final person = TestPerson();

      person.setValues({
        "name": "Alice",
        "age": 25,
        "email": "alice@example.com",
        "isActive": false,
      });

      expect(~person.name, equals("Alice"));
      expect(~person.age, equals(25));
      expect(~person.email, equals("alice@example.com"));
      expect(~person.isActive, isFalse);
    });

    test('toJson returns values map', () {
      final person = TestPerson();
      person.name | "Bob";
      person.age | 30;

      final json = person.toJson();

      expect(json["name"], equals("Bob"));
      expect(json["age"], equals(30));
    });

    test('fromJson parses JSON string', () {
      final person = TestPerson();
      person.fromJson('{"name": "Carol", "age": 35}');

      expect(~person.name, equals("Carol"));
      expect(~person.age, equals(35));
    });

    test('toJson unwraps TomList elements so jsonEncode round-trips', () {
      // `TomList.get()` returns the backing list without unwrapping, so a
      // TomList member that serialized through it would produce a List of raw
      // TomObject instances and jsonEncode(toJson()) would throw
      // JsonUnsupportedObjectError.
      final item = TestTaggedItem();
      item.title | "release";
      item.tags.append(TomString("urgent")).append(TomString("backend"));
      final sub = TestTask();
      sub.title | "write tests";
      sub.completed | true;
      item.subtasks.append(sub);

      final json = item.toJson();

      // Scalar list elements become plain strings, not TomString instances.
      expect(json["tags"], equals(["urgent", "backend"]));
      // Nested-TomClass list elements are recursively serialized to maps.
      final subtasks = json["subtasks"] as List;
      expect(subtasks.single, isA<Map>());
      expect((subtasks.single as Map)["title"], equals("write tests"));

      // The whole point: the map is now jsonEncode-safe, and the encoded form
      // decodes back to the same scalar list.
      expect(() => jsonEncode(json), returnsNormally);
      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(decoded["tags"], equals(["urgent", "backend"]));
    });

    test('fromJson rebuilds a scalar TomList without a reified-type failure', () {
      // Symmetric counterpart of the serialize fix: setValues() rebuilds a
      // TomList<TomString> member reflectively into a List<TomObject<dynamic>>
      // and used to hand the whole list to resetWith(Iterable<E>). At runtime
      // E is TomString, so the covariant whole-container check threw
      // "type 'List<TomObject<dynamic>>' is not a subtype of type
      // 'Iterable<TomString>' of 'elements'". Deserializing a scalar list must
      // succeed and preserve the element values.
      final source = TestTaggedItem();
      source.title | "release";
      source.tags.append(TomString("frontend")).append(TomString("design"));
      final sub = TestTask();
      sub.title | "write tests";
      sub.completed | true;
      source.subtasks.append(sub);

      final wire = jsonEncode(source.toJson());

      final rebuilt = TestTaggedItem();
      expect(() => rebuilt.fromJson(wire), returnsNormally);

      expect(rebuilt.title.get(), equals("release"));
      // Scalar list elements reconstructed as TomString with the right values.
      expect(
        rebuilt.tags.map((e) => e.get()).toList(),
        equals(["frontend", "design"]),
      );
      // Nested-TomClass list elements reconstructed from their maps.
      expect(rebuilt.subtasks.length, equals(1));
      expect(rebuilt.subtasks.first.title.get(), equals("write tests"));
      expect(rebuilt.subtasks.first.completed.get(), isTrue);
    });

    test('nested TomClass observation', () {
      final customer = TestCustomer();
      int notifyCount = 0;

      customer >> (obs) => notifyCount++;

      customer.name | "Test";
      expect(notifyCount, equals(1));

      customer.address.city | "New York";
      expect(notifyCount, equals(2));

      customer.address.street | "123 Main St";
      expect(notifyCount, equals(3));
    });

    test('mute mutes all members', () {
      final person = TestPerson();
      int notifyCount = 0;

      person >> (obs) => notifyCount++;

      person.mute();
      person.name | "John";
      person.age | 30;
      expect(notifyCount, equals(0));

      person.unmute();
      // Single consolidated notification after unmute
      expect(notifyCount, equals(1));
    });

    test('throws on direct set()', () {
      final person = TestPerson();
      expect(() => person.set({}), throwsA(isA<TomObservableException>()));
    });

    test('throws on direct get()', () {
      final person = TestPerson();
      expect(() => person.get(), throwsA(isA<TomObservableException>()));
    });
  });

  group('TomList', () {
    test('creates empty list', () {
      final list = TomList<TomInt>();
      expect(list.length, equals(0));
      expect(list.isEmpty, isTrue);
    });

    test('add() adds elements', () {
      final list = TomList<TomString>();
      list.add(TomString("first"));
      list.add(TomString("second"));

      expect(list.length, equals(2));
      expect(~list[0], equals("first"));
      expect(~list[1], equals("second"));
    });

    test('append() method adds elements', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

      expect(list.length, equals(3));
      expect(~list[0], equals(1));
      expect(~list[1], equals(2));
      expect(~list[2], equals(3));
    });

    test('notifies when elements added', () {
      final list = TomList<TomString>();
      int notifyCount = 0;

      list >> (obs) => notifyCount++;

      list.add(TomString("test"));
      expect(notifyCount, equals(1));

      list.append(TomString("test2"));
      expect(notifyCount, equals(2));
    });

    test('notifies when element value changes', () {
      final list = TomList<TomInt>();
      int notifyCount = 0;

      list.append(TomInt(10));
      list >> (obs) => notifyCount++;

      list[0] | 20;
      expect(notifyCount, equals(1));
    });

    test('index assignment updates element', () {
      final list = TomList<TomString>();
      list.append(TomString("original"));

      list[0] = TomString("replaced");
      expect(~list[0], equals("replaced"));
    });

    test('removeAt removes element', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

      final removed = list.removeAt(1);
      expect(~removed, equals(2));
      expect(list.length, equals(2));
      expect(~list[0], equals(1));
      expect(~list[1], equals(3));
    });

    test('removeLast removes last element', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

      final removed = list.removeLast();
      expect(~removed, equals(3));
      expect(list.length, equals(2));
    });

    test('clear removes all elements', () {
      final list = TomList<TomString>();
      list.append(TomString("a")).append(TomString("b")).append(TomString("c"));

      list.clear();
      expect(list.isEmpty, isTrue);
      expect(list.length, equals(0));
    });

    test('+ operator concatenates lists', () {
      final list1 = TomList<TomInt>();
      list1.append(TomInt(1)).append(TomInt(2));

      final list2 = TomList<TomInt>();
      list2.append(TomInt(3)).append(TomInt(4));

      final combined = list1 + list2;
      expect(combined.length, equals(4));
      expect(~combined[0], equals(1));
      expect(~combined[3], equals(4));
    });

    test('first and last accessors', () {
      final list = TomList<TomInt>();
      list.append(TomInt(10)).append(TomInt(20)).append(TomInt(30));

      expect(~list.first, equals(10));
      expect(~list.last, equals(30));
    });

    test('TomList.from copies elements', () {
      final original = TomList<TomInt>();
      original.append(TomInt(1)).append(TomInt(2));

      final copy = TomList.from(original);
      expect(copy.length, equals(2));
      expect(~copy[0], equals(1));
    });

    test('forEach iterates elements', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

      num sum = 0;
      for (var e in list) {
        sum += ~e;
      }
      expect(sum, equals(6));
    });

    test('map transforms elements', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

      final doubled = list.map((e) => ~e * 2).toList();
      expect(doubled, equals([2, 4, 6]));
    });

    test('any checks condition', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(5)).append(TomInt(10));

      expect(list.any((e) => ~e > 8), isTrue);
      expect(list.any((e) => ~e > 20), isFalse);
    });

    test('where filters elements', () {
      final list = TomList<TomInt>();
      list
          .append(TomInt(1))
          .append(TomInt(2))
          .append(TomInt(3))
          .append(TomInt(4));

      final even = list.where((e) => ~e % 2 == 0);
      expect(even.length, equals(2));
    });

    test('with TomClass elements', () {
      final list = TomList<TestTask>();
      int notifyCount = 0;

      list >> (obs) => notifyCount++;

      final task = TestTask();
      task.title | "Test Task";
      list.append(task);
      expect(notifyCount, equals(1));

      // Changing task properties notifies the list
      task.completed | true;
      expect(notifyCount, equals(2));
    });

    test('throws on direct set()', () {
      final list = TomList<TomInt>();
      expect(() => list.set([]), throwsA(isA<TomObservableException>()));
    });

    test('set() throws in every state, and leaves the list untouched', () {
      // There is no mode in which `set` succeeds — in particular not on the
      // deserialization path, where a wholesale assignment would be most
      // tempting. So check both a populated list and one that has just been
      // through `resetWith`.
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2));

      int notifications = 0;
      final observer = list >> (_) => notifications++;

      expect(
        () => list.set([TomInt(9)]),
        throwsA(isA<TomObservableException>()),
      );

      list.resetWith([TomInt(3), TomInt(4)]);
      notifications = 0;
      expect(
        () => list.set([TomInt(9)]),
        throwsA(isA<TomObservableException>()),
      );

      // The rejected call changed nothing and said nothing.
      expect(list.length, equals(2));
      expect(~list[0], equals(3));
      expect(~list[1], equals(4));
      expect(notifications, equals(0));

      // The elements are still observed — the whole reason `set` refuses.
      list[0] | 99;
      expect(notifications, equals(1));

      list.removeObserver(observer);
    });

    test('mute mutes all elements', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));
      int notifyCount = 0;
      list >> (obs) => notifyCount++;

      list.mute();
      list[0] | 10;
      list[1] | 20;
      list[2] | 30;
      expect(notifyCount, equals(0));

      list.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute mutes nested TomClass elements', () {
      final list = TomList<TestPerson>();
      final person1 = TestPerson();
      final person2 = TestPerson();
      list.append(person1).append(person2);
      int notifyCount = 0;
      list >> (obs) => notifyCount++;

      list.mute();
      person1.name | "John";
      person1.age | 30;
      person2.name | "Jane";
      person2.age | 25;
      expect(notifyCount, equals(0));

      list.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute mutes TomString elements', () {
      final list = TomList<TomString>();
      list.append(TomString("a")).append(TomString("b")).append(TomString("c"));
      int notifyCount = 0;
      list >> (obs) => notifyCount++;

      list.mute();
      list[0] | "x";
      list[1] | "y";
      list[2] | "z";
      expect(notifyCount, equals(0));

      list.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute actually mutes individual elements', () {
      final list = TomList<TomInt>();
      final item = TomInt(1);
      list.append(item);

      // Observe the individual element
      int elementNotifyCount = 0;
      item >> (obs) => elementNotifyCount++;

      list.mute();
      expect(item.isMuted, isTrue);
      item | 10;
      expect(elementNotifyCount, equals(0)); // Element is muted

      list.unmute();
      expect(item.isMuted, isFalse);
      expect(elementNotifyCount, equals(1)); // Element notifies on unmute
    });
  });

  group('TomMap', () {
    test('creates empty map', () {
      final map = TomMap<String, TomInt>();
      expect(map.length, equals(0));
      expect(map.isEmpty, isTrue);
    });

    test('[]= operator adds entries', () {
      final map = TomMap<String, TomString>();
      map["key1"] = TomString("value1");
      map["key2"] = TomString("value2");

      expect(map.length, equals(2));
      expect(~map["key1"]!, equals("value1"));
      expect(~map["key2"]!, equals("value2"));
    });

    test('[] operator gets values', () {
      final map = TomMap<String, TomInt>();
      map["answer"] = TomInt(42);

      expect(~map["answer"]!, equals(42));
      expect(map["nonexistent"], isNull);
    });

    test('notifies when entries added', () {
      final map = TomMap<String, TomString>();
      int notifyCount = 0;

      map >> (obs) => notifyCount++;

      map["key"] = TomString("value");
      expect(notifyCount, equals(1));
    });

    test('notifies when value changes', () {
      final map = TomMap<String, TomInt>();
      int notifyCount = 0;

      map["num"] = TomInt(10);
      map >> (obs) => notifyCount++;

      map["num"]! | 20;
      expect(notifyCount, equals(1));
    });

    test('containsKey checks key existence', () {
      final map = TomMap<String, TomBool>();
      map["exists"] = TomBool(true);

      expect(map.containsKey("exists"), isTrue);
      expect(map.containsKey("missing"), isFalse);
    });

    test('remove removes entry', () {
      final map = TomMap<String, TomString>();
      map["a"] = TomString("alpha");
      map["b"] = TomString("beta");

      final removed = map.remove("a");
      expect(~removed!, equals("alpha"));
      expect(map.length, equals(1));
      expect(map.containsKey("a"), isFalse);
    });

    test('clear removes all entries', () {
      final map = TomMap<String, TomInt>();
      map["x"] = TomInt(1);
      map["y"] = TomInt(2);

      map.clear();
      expect(map.isEmpty, isTrue);
    });

    test('+ operator merges maps', () {
      final map1 = TomMap<String, TomInt>();
      map1["a"] = TomInt(1);

      final map2 = TomMap<String, TomInt>();
      map2["b"] = TomInt(2);

      final merged = map1 + map2;
      expect(merged.length, equals(2));
      expect(merged.containsKey("a"), isTrue);
      expect(merged.containsKey("b"), isTrue);
    });

    test('keys and values iterables', () {
      final map = TomMap<String, TomInt>();
      map["one"] = TomInt(1);
      map["two"] = TomInt(2);

      expect(map.keys.toList(), containsAll(["one", "two"]));
      expect(map.values.length, equals(2));
    });

    test('forEach iterates entries', () {
      final map = TomMap<String, TomInt>();
      map["a"] = TomInt(1);
      map["b"] = TomInt(2);

      int sum = 0;
      map.forEach((key, value) => sum += ~value);
      expect(sum, equals(3));
    });

    test('putIfAbsent adds only if missing', () {
      final map = TomMap<String, TomString>();
      map["existing"] = TomString("original");

      final result1 = map.putIfAbsent("existing", () => TomString("new"));
      expect(~result1, equals("original"));

      final result2 = map.putIfAbsent("new", () => TomString("added"));
      expect(~result2, equals("added"));
      expect(map.length, equals(2));
    });

    test('with TomClass values', () {
      final map = TomMap<String, TestUserProfile>();
      int notifyCount = 0;

      map >> (obs) => notifyCount++;

      final user = TestUserProfile();
      user.displayName | "Alice";
      map["alice"] = user;
      expect(notifyCount, equals(1));

      // Changing user properties notifies the map
      user.followerCount | 100;
      expect(notifyCount, equals(2));
    });

    test('TomMap.from copies entries', () {
      final original = TomMap<String, TomInt>();
      original["x"] = TomInt(10);

      final copy = TomMap.from(original);
      expect(copy.length, equals(1));
      expect(~copy["x"]!, equals(10));
    });

    test('throws on direct set()', () {
      final map = TomMap<String, TomInt>();
      expect(() => map.set({}), throwsA(isA<TomObservableException>()));
    });

    test('mute mutes all values', () {
      final map = TomMap<String, TomInt>();
      map["a"] = TomInt(1);
      map["b"] = TomInt(2);
      map["c"] = TomInt(3);
      int notifyCount = 0;
      map >> (obs) => notifyCount++;

      map.mute();
      map["a"]! | 10;
      map["b"]! | 20;
      map["c"]! | 30;
      expect(notifyCount, equals(0));

      map.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute mutes nested TomClass values', () {
      final map = TomMap<String, TestPerson>();
      final person1 = TestPerson();
      final person2 = TestPerson();
      map["p1"] = person1;
      map["p2"] = person2;
      int notifyCount = 0;
      map >> (obs) => notifyCount++;

      map.mute();
      person1.name | "John";
      person1.age | 30;
      person2.name | "Jane";
      person2.age | 25;
      expect(notifyCount, equals(0));

      map.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute mutes TomString values', () {
      final map = TomMap<String, TomString>();
      map["a"] = TomString("alpha");
      map["b"] = TomString("beta");
      map["c"] = TomString("gamma");
      int notifyCount = 0;
      map >> (obs) => notifyCount++;

      map.mute();
      map["a"]! | "x";
      map["b"]! | "y";
      map["c"]! | "z";
      expect(notifyCount, equals(0));

      map.unmute();
      // Should trigger only one consolidated notification
      expect(notifyCount, equals(1));
    });

    test('mute actually mutes individual values', () {
      final map = TomMap<String, TomInt>();
      final item = TomInt(1);
      map["key"] = item;

      // Observe the individual value
      int valueNotifyCount = 0;
      item >> (obs) => valueNotifyCount++;

      map.mute();
      expect(item.isMuted, isTrue);
      item | 10;
      expect(valueNotifyCount, equals(0)); // Value is muted

      map.unmute();
      expect(item.isMuted, isFalse);
      expect(valueNotifyCount, equals(1)); // Value notifies on unmute
    });
  });

  group('Timezone Types', () {
    test('TomZonedDate serialization prefix', () {
      expect(TomZonedDate.serializationPrefix, equals("@D@"));
    });

    test('TomZonedTime serialization prefix', () {
      expect(TomZonedTime.serializationPrefix, equals("@T@"));
    });

    test('TomZonedDateTime serialization prefix', () {
      expect(TomZonedDateTime.serializationPrefix, equals("@X@"));
    });

    test('TomOZonedDate holds date value', () {
      final date = TomZonedDate(
        year: 2024,
        month: 6,
        day: 15,
        timezone: TomTimezone.utc,
      );
      final observable = TomOZonedDate(date);

      expect((~observable).year, equals(2024));
      expect((~observable).month, equals(6));
      expect((~observable).day, equals(15));
    });

    test('TomOZonedTime holds time value', () {
      final time = TomZonedTime(
        hour: 14,
        minute: 30,
        second: 45,
        timezone: TomTimezone.utc,
      );
      final observable = TomOZonedTime(time);

      expect((~observable).hour, equals(14));
      expect((~observable).minute, equals(30));
      expect((~observable).second, equals(45));
    });

    test('TomOZonedDateTime holds datetime value', () {
      final dt = TomZonedDateTime(
        year: 2024,
        month: 12,
        day: 25,
        hour: 18,
        minute: 0,
        second: 0,
        timezone: TomTimezone.utc,
      );
      final observable = TomOZonedDateTime(dt);

      expect((~observable).year, equals(2024));
      expect((~observable).month, equals(12));
      expect((~observable).day, equals(25));
      expect((~observable).hour, equals(18));
    });

    test('Nullable timezone types handle null', () {
      final optDate = TomNOZonedDate(null);
      final optTime = TomNOZonedTime(null);
      final optDateTime = TomNOZonedDateTime(null);

      expect(optDate.isNull, isTrue);
      expect(optTime.isNull, isTrue);
      expect(optDateTime.isNull, isTrue);
    });

    test('setByString deserializes zoned date', () {
      final observable = TomOZonedDate(
        TomZonedDate.fromDateTime(DateTime.utc(1970)),
      );
      final serialized = "@D@2024-05-20T00:00:00.000Z_Z_UTC";

      observable.setByString(serialized);

      expect((~observable).year, equals(2024));
      expect((~observable).month, equals(5));
      expect((~observable).day, equals(20));
    });
  });

  group('every TomOTimezoned implements setByString', () {
    // setByString is the sole entry point for a serialized zoned value:
    // TomClass._setMember routes every String destined for a TomOTimezoned
    // member through it. It therefore must never have an inherited
    // implementation that does nothing -- a subtype that forgot to write one
    // would drop the field during deserialization without a throw, a log or a
    // return value to inspect.
    //
    // TomOTimezoned and TomNOTimezoned are abstract and declare setByString
    // abstract, so "forgot to implement it" is a compile error. These tests
    // pin the runtime half: every TomOTimezoned the library can hand out
    // reaches a real implementation.

    final instant = DateTime.utc(2024, 5, 20, 6, 7, 8);

    /// One entry per concrete [TomOTimezoned] in the library, paired with a
    /// value of its own flavour. Serializing that value and feeding it back
    /// through [TomOTimezoned.setByString] must reproduce it.
    List<(String, TomOTimezoned, TomTimezoned)> roundTripCases() => [
      (
        'TomOZonedTime',
        TomOZonedTime(TomOZonedTime.noZonedTime),
        TomZonedTime.fromDateTime(instant),
      ),
      (
        'TomOZonedDate',
        TomOZonedDate(TomOZonedDate.noZonedDate),
        TomZonedDate.fromDateTime(instant),
      ),
      (
        'TomOZonedDateTime',
        TomOZonedDateTime(TomOZonedDateTime.noZonedDateTime),
        TomZonedDateTime.fromDateTime(instant),
      ),
      (
        'TomNOZonedTime',
        TomNOZonedTime(null),
        TomZonedTime.fromDateTime(instant),
      ),
      (
        'TomNOZonedDate',
        TomNOZonedDate(null),
        TomZonedDate.fromDateTime(instant),
      ),
      (
        'TomNOZonedDateTime',
        TomNOZonedDateTime(null),
        TomZonedDateTime.fromDateTime(instant),
      ),
    ];

    test('the base sentinels are concrete subtypes, not bare bases', () {
      // TomOTimezoned.noDateTime and TomNOTimezoned.noDateTime are the only
      // values the library ever handed out whose runtime type was the base
      // itself. Once the base is abstract they cannot be, and they must be the
      // datetime flavour specifically -- that is the flavour whose wire prefix
      // the base's getSerializationPrefix() already defaults to.
      expect(TomOTimezoned.noDateTime, isA<TomOZonedDateTime>());
      expect(TomNOTimezoned.noDateTime, isA<TomNOZonedDateTime>());
      expect(
        TomOTimezoned.noDateTime.getSerializationPrefix(),
        equals(TomZonedDateTime.serializationPrefix),
      );
      expect(
        TomNOTimezoned.noDateTime.getSerializationPrefix(),
        equals(TomZonedDateTime.serializationPrefix),
      );
    });

    test('the base sentinels parse the string instead of ignoring it', () {
      // The sentinels are shared statics, so mutating one would leak into the
      // sentinel tests further down the file. Each is restored on the way out.
      final baseOriginal = TomOTimezoned.noDateTime.get();
      final nullableOriginal = TomNOTimezoned.noDateTime.get();
      addTearDown(() {
        TomOTimezoned.noDateTime.set(baseOriginal);
        TomNOTimezoned.noDateTime.set(nullableOriginal);
      });

      final replacement = TomZonedDateTime.fromDateTime(instant);

      TomOTimezoned.noDateTime.setByString(replacement.toString());
      expect(
        TomOTimezoned.noDateTime.get()!.toUtc(),
        equals(replacement.toUtc()),
      );

      TomNOTimezoned.noDateTime.setByString(replacement.toString());
      expect(
        TomNOTimezoned.noDateTime.get()!.toUtc(),
        equals(replacement.toUtc()),
      );
    });

    test('a value held as the abstract base reaches the subtype parser', () {
      // The static type at the call site is the base -- which is exactly how
      // TomClass._setMember sees it. Dispatch must still land on the concrete
      // implementation.
      for (final (name, observable, replacement) in roundTripCases()) {
        final TomOTimezoned held = observable;
        held.setByString(replacement.toString());
        expect(
          held.get()!.toUtc(),
          equals(replacement.toUtc()),
          reason: '$name.setByString must apply the string it is given',
        );
      }
    });

    test('an unprefixed ISO-8601 string is accepted as well', () {
      // The wire format carries the flavour prefix, but every implementation
      // also accepts a bare timestamp so that hand-written and third-party
      // payloads deserialize.
      for (final (name, observable, _) in roundTripCases()) {
        observable.setByString(instant.toIso8601String());
        expect(
          observable.get(),
          isNotNull,
          reason: '$name.setByString must accept an unprefixed timestamp',
        );
      }
    });

    test('getSerializationPrefix defaults where setByString cannot', () {
      // getSerializationPrefix has a defensible default -- the datetime prefix
      // -- and the datetime subtypes deliberately inherit it rather than
      // restate it. setByString has no comparable default: the base cannot
      // know which of the three wire formats to parse, which is why it is
      // abstract rather than an inherited no-op. This test is the pair that
      // keeps the asymmetry deliberate.
      expect(
        TomOZonedTime(TomOZonedTime.noZonedTime).getSerializationPrefix(),
        equals(TomZonedTime.serializationPrefix),
      );
      expect(
        TomOZonedDate(TomOZonedDate.noZonedDate).getSerializationPrefix(),
        equals(TomZonedDate.serializationPrefix),
      );
      expect(
        TomOZonedDateTime(
          TomOZonedDateTime.noZonedDateTime,
        ).getSerializationPrefix(),
        equals(TomZonedDateTime.serializationPrefix),
      );
      expect(
        TomNOZonedDateTime(null).getSerializationPrefix(),
        equals(TomZonedDateTime.serializationPrefix),
      );
    });
  });

  group('TomClass reads back its own zoned members', () {
    // TomTimezoned extends DateTime, so every zoned observable also satisfies
    // TomObject<DateTime?>. Dispatch in TomClass._setMember must therefore
    // reach the timezoned branch before the plain-DateTime one, or the zoned
    // value arrives at DateTime.parse with its `@D@`/`@T@`/`@X@` prefix
    // attached. Exercising setByString directly does not catch that — only a
    // round trip through the TomClass does.
    test('a full round trip preserves every zoned member', () {
      final written = TestZonedMembers();
      written.optionalDate |
          TomZonedDate(year: 2030, month: 1, day: 2, timezone: TomTimezone.utc);
      written.optionalTime |
          TomZonedTime(hour: 7, minute: 5, timezone: TomTimezone.utc);
      written.optionalDateTime |
          TomZonedDateTime(
            year: 2031,
            month: 3,
            day: 4,
            hour: 9,
            timezone: TomTimezone.utc,
          );

      final read = TestZonedMembers();
      read.setValues(written.getValues());

      expect(read.date.get().toUtc(), equals(written.date.get().toUtc()));
      expect(read.time.get().toUtc(), equals(written.time.get().toUtc()));
      expect(
        read.dateTime.get().toUtc(),
        equals(written.dateTime.get().toUtc()),
      );
      expect(
        read.optionalDate.get()!.toUtc(),
        equals(written.optionalDate.get()!.toUtc()),
      );
      expect(
        read.optionalTime.get()!.toUtc(),
        equals(written.optionalTime.get()!.toUtc()),
      );
      expect(
        read.optionalDateTime.get()!.toUtc(),
        equals(written.optionalDateTime.get()!.toUtc()),
      );
    });

    test('a null nullable zoned member round-trips as null', () {
      final written = TestZonedMembers();

      final read = TestZonedMembers();
      read.optionalDate |
          TomZonedDate(year: 2030, month: 1, day: 2, timezone: TomTimezone.utc);
      read.setValues(written.getValues());

      expect(read.optionalDate.isNull, isTrue);
      expect(read.optionalTime.isNull, isTrue);
      expect(read.optionalDateTime.isNull, isTrue);
    });

    test('a plain TomDateTime member still round-trips', () {
      // The reordering must not steal the plain-DateTime case: TomDateTime is
      // not a TomOTimezoned, so it keeps taking the `@!@` branch.
      final written = TestZonedMembers();
      written.stamp | DateTime.utc(2024, 6, 15, 10, 30);

      final read = TestZonedMembers();
      read.setValues(written.getValues());

      expect(read.stamp.get(), equals(DateTime.utc(2024, 6, 15, 10, 30)));
    });
  });

  group('every serialization prefix is reachable from a string alone', () {
    // These pin the prefix table that TomObject._createFrom consults. The
    // scalar paths cannot stand in for them: a scalar member dispatches on the
    // cell it is writing into, so it never has to recover a type from the
    // string. An element has no cell yet, which is why a prefix exists at all.
    //
    // This is the shape of failure the table is meant to prevent: add a zoned
    // flavour, teach the polymorphic paths nothing (they already handle it via
    // `member is TomOTimezoned`), and forget the one table that maps its
    // prefix — the type then silently deserializes as a TomString.

    test('a @D@ date element rebuilds as TomOZonedDate', () {
      final o = TestZonedElements();
      final source = TomZonedDate(
        year: 2024,
        month: 6,
        day: 15,
        timezone: TomTimezone.utc,
      );

      o.setValues({
        'dates': [source.toString()],
      });

      expect(o.dates, hasLength(1));
      expect(o.dates.first, isA<TomOZonedDate>());
      expect(o.dates.first.get().toUtc(), equals(source.toUtc()));
    });

    test('a @T@ time element rebuilds as TomOZonedTime', () {
      final o = TestZonedElements();
      final source = TomZonedTime(
        hour: 14,
        minute: 30,
        second: 45,
        timezone: TomTimezone.utc,
      );

      o.setValues({
        'times': [source.toString()],
      });

      expect(o.times, hasLength(1));
      expect(o.times.first, isA<TomOZonedTime>());
      expect(o.times.first.get().toUtc(), equals(source.toUtc()));
    });

    test('a @X@ datetime element rebuilds as TomOZonedDateTime', () {
      final o = TestZonedElements();
      final source = TomZonedDateTime(
        year: 2024,
        month: 12,
        day: 25,
        hour: 18,
        timezone: TomTimezone.utc,
      );

      o.setValues({
        'dateTimes': [source.toString()],
      });

      expect(o.dateTimes, hasLength(1));
      expect(o.dateTimes.first, isA<TomOZonedDateTime>());
      expect(o.dateTimes.first.get().toUtc(), equals(source.toUtc()));
    });

    test('a @!@ stamp element rebuilds as TomDateTime, prefix stripped', () {
      // The zoned parsers consume their own prefix; this one does not, so the
      // table has to strip it before DateTime.parse sees the string. Getting
      // that backwards throws rather than corrupting, but only for this entry.
      final o = TestZonedElements();
      final instant = DateTime.utc(2024, 6, 15, 10, 30);

      o.setValues({
        'stamps': [
          '${TomDateTime.serializationPrefix}'
              '${instant.toIso8601String()}',
        ],
      });

      expect(o.stamps, hasLength(1));
      expect(o.stamps.first, isA<TomDateTime>());
      expect(o.stamps.first.get(), equals(instant));
    });

    test('an unprefixed string stays a TomString', () {
      // The negative half: the table must not claim a string it does not own.
      final o = TestZonedElements();

      o.setValues({
        'plain': ['just text', '2024-06-15T10:30:00.000Z'],
      });

      expect(o.plain, everyElement(isA<TomString>()));
      expect(
        o.plain.map((e) => e.get()).toList(),
        equals(['just text', '2024-06-15T10:30:00.000Z']),
      );
    });

    test('a full container round trip preserves every element type', () {
      final written = TestZonedElements();
      written.setValues({
        'dates': [
          TomZonedDate(
            year: 2024,
            month: 6,
            day: 15,
            timezone: TomTimezone.utc,
          ).toString(),
        ],
        'times': [
          TomZonedTime(
            hour: 14,
            minute: 30,
            timezone: TomTimezone.utc,
          ).toString(),
        ],
        'dateTimes': [
          TomZonedDateTime(
            year: 2024,
            month: 12,
            day: 25,
            hour: 18,
            timezone: TomTimezone.utc,
          ).toString(),
        ],
      });

      final read = TestZonedElements();
      read.setValues(written.getValues());

      expect(
        read.dates.first.get().toUtc(),
        equals(written.dates.first.get().toUtc()),
      );
      expect(
        read.times.first.get().toUtc(),
        equals(written.times.first.get().toUtc()),
      );
      expect(
        read.dateTimes.first.get().toUtc(),
        equals(written.dateTimes.first.get().toUtc()),
      );
    });
  });

  group('members register under their public getter name', () {
    // Why this matters: setOrMergeValues used to look up
    // `_value[key] ?? _value["_$key"]`, an inline underscore-prefix convention
    // with nothing explaining it. These tests pin why the fallback could never
    // fire — reflection excludes private fields and private accessors, so an
    // underscore-prefixed key cannot be in the member map to be found.

    test('a private field published by a public getter registers publicly', () {
      final o = TestPrivateBackedMember();

      expect(o.getMembers().keys, contains('label'));
      expect(
        o.getMembers().keys,
        isNot(contains('_label')),
        reason:
            'reflection never yields a private accessor, so the private '
            'field name cannot become a member key',
      );
    });

    test('the public name deserializes the private-backed member', () {
      final o = TestPrivateBackedMember();

      o.setValues({'label': 'written', 'visible': 7});

      expect(o.label.get(), equals('written'));
      expect(o.visible.get(), equals(7));
    });

    test('the underscore-prefixed name is not a second way in', () {
      final o = TestPrivateBackedMember();

      o.setValues({'_label': 'sneaky'});

      expect(
        o.label.get(),
        isEmpty,
        reason: 'an unknown key is skipped; there is no underscore alias',
      );
    });

    test('the member serializes under its public name too', () {
      final o = TestPrivateBackedMember();
      o.label | 'round';

      expect(o.getValues(), equals({'label': 'round', 'visible': 0}));
    });
  });

  group('TomDateRange', () {
    test('has start and end dates', () {
      final range = TomDateRange();
      expect(range.startDate, isNotNull);
      expect(range.endDate, isNotNull);
    });

    test('notifies when dates change', () {
      final range = TomDateRange();
      int notifyCount = 0;

      range >> (obs) => notifyCount++;

      range.startDate | TomZonedDate.fromDateTime(DateTime(2024, 1, 1));
      expect(notifyCount, equals(1));

      range.endDate | TomZonedDate.fromDateTime(DateTime(2024, 12, 31));
      expect(notifyCount, equals(2));
    });
  });

  group('TomTimeRange', () {
    test('has start and end times', () {
      final range = TomTimeRange();
      expect(range.startTime, isNotNull);
      expect(range.endTime, isNotNull);
    });

    test('notifies when times change', () {
      final range = TomTimeRange();
      int notifyCount = 0;

      range >> (obs) => notifyCount++;

      range.startTime |
          TomZonedTime(hour: 9, minute: 0, timezone: TomTimezone.utc);
      expect(notifyCount, equals(1));
    });
  });

  group('TomDateTimeRange', () {
    test('has start and end datetimes', () {
      final range = TomDateTimeRange();
      expect(range.startDateTime, isNotNull);
      expect(range.endDateTime, isNotNull);
    });

    test('notifies when datetimes change', () {
      final range = TomDateTimeRange();
      int notifyCount = 0;

      range >> (obs) => notifyCount++;

      range.startDateTime |
          TomZonedDateTime.fromDateTime(DateTime(2024, 1, 1, 10, 0));
      expect(notifyCount, equals(1));
    });
  });

  group('TomFunctionObserver', () {
    test('wraps callback function', () {
      int callCount = 0;
      final observer = TomFunctionObserver<TomObservable>((obs) {
        callCount++;
      });

      final observable = TomObservable();
      observable.addObserver(observer);
      observable.notifyObservers();

      expect(callCount, equals(1));
    });

    test('receives typed observable', () {
      TomString? receivedObs;
      final observer = TomFunctionObserver<TomString>((obs) {
        receivedObs = obs;
      });

      final str = TomString("test");
      str.addObserver(observer);
      str | "changed";

      expect(receivedObs, isNotNull);
      expect(~receivedObs!, equals("changed"));
    });
  });

  group('Edge Cases', () {
    test('empty TomList operations', () {
      final list = TomList<TomInt>();

      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
      expect(() => list.first, throwsStateError);
      expect(() => list.last, throwsStateError);
    });

    test('empty TomMap operations', () {
      final map = TomMap<String, TomInt>();

      expect(map.isEmpty, isTrue);
      expect(map.isNotEmpty, isFalse);
      expect(map["nonexistent"], isNull);
      expect(map.remove("nonexistent"), isNull);
    });

    test('TomList with single element', () {
      final list = TomList<TomString>();
      list.append(TomString("only"));

      expect(list.first, equals(list.last));
      expect(list.single, equals(list.first));
    });

    test('modifying value after removal does not notify list', () {
      final list = TomList<TomInt>();
      final item = TomInt(10);
      list.append(item);

      int notifyCount = 0;
      list >> (obs) => notifyCount++;

      list.removeAt(0);
      expect(notifyCount, equals(1)); // Removal notifies

      item | 20; // Modifying removed item
      expect(notifyCount, equals(1)); // Should not increase
    });

    test('modifying value after removal does not notify map', () {
      final map = TomMap<String, TomInt>();
      final item = TomInt(10);
      map["key"] = item;

      int notifyCount = 0;
      map >> (obs) => notifyCount++;

      // Two separate effects, measured separately: the removal itself is a
      // change of the map's contents and notifies once...
      map.remove("key");
      expect(notifyCount, equals(1));

      // ...and after it, the map no longer observes the detached value.
      notifyCount = 0;
      item | 20;
      expect(notifyCount, equals(0));
    });

    test('nested TomClass deserialization', () {
      final customer = TestCustomer();
      customer.setValues({
        "customerId": "C001",
        "name": "Test Corp",
        "address": {
          "street": "123 Main St",
          "city": "New York",
          "zipCode": "10001",
        },
      });

      expect(~customer.customerId, equals("C001"));
      expect(~customer.address.city, equals("New York"));
      expect(~customer.address.zipCode, equals("10001"));
    });

    test('TomClass with TomList member', () {
      // This tests that TomClass can have TomList members
      // that are properly observed
      final customer = TestCustomer();
      int notifyCount = 0;

      customer >> (obs) => notifyCount++;

      customer.name | "Updated";
      expect(notifyCount, equals(1));
    });
  });

  // The rendered forms are asserted exactly, not with `contains`. These strings
  // are published in `doc/api_reference/api_summary_observable.md`, and a
  // documented format that no test pins is a format free to drift away from its
  // own documentation. `contains("42")` passed for every conceivable rendering
  // of a TomInt holding 42, which is precisely why the doc could go stale
  // without a test noticing.
  group('toString()', () {
    test(
      'a TomClass subclass inherits the map form, it does not re-add the ~',
      () {
        // The range types are TomClass subclasses and declare no toString of
        // their own, so they must render as the member map. Asserted
        // structurally rather than against a frozen literal: the member *values*
        // of an empty range are an open question and may change, but the
        // inherited *form* is what this test is for.
        final range = TomDateRange();
        expect(range.toString(), equals(range.getValues().toString()));
        expect(range.toString(), startsWith('{startDate: '));
        expect(range.toString(), isNot(startsWith('~')));
      },
    );

    test('TomObject renders as ~<value>', () {
      expect(TomString("hello").toString(), equals('~hello'));
      expect(TomInt(42).toString(), equals('~42'));
      expect(TomBool(true).toString(), equals('~true'));
      expect(TomNString(null).toString(), equals('~null'));
    });

    test('TomList renders the backing list, without a leading ~', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2));

      // The elements render through their own toString, so the `~` appears per
      // element rather than once for the list. TomList overriding toString is
      // what drops the outer marker; TomMap does not override, so it keeps one
      // — see the next test. That asymmetry is documented, so it is pinned.
      expect(list.toString(), equals('[~1, ~2]'));
    });

    test('TomMap inherits TomObject, so it keeps the leading ~', () {
      final map = TomMap<String, TomInt>();
      map['a'] = TomInt(1);

      expect(map.toString(), equals('~{a: ~1}'));
    });

    test('TomClass rendering agrees with getValues(), nested and zoned', () {
      // `toString()` goes through `tomReflectionInfo.getValues(this)` while
      // `getValues()` is TomClass's own `_serializeMember` walk — two separate
      // implementations. The summary documents them as producing the same
      // values, so the agreement is asserted rather than assumed; nothing else
      // would notice the two drifting apart.
      final customer = TestCustomer();
      customer.name | 'Acme';
      customer.address.city | 'Berlin';

      expect(customer.toString(), equals(customer.getValues().toString()));
      expect(
        customer.toString(),
        contains('address: {street: , city: Berlin'),
        reason: 'a nested class recurses rather than printing its type',
      );

      final zoned = TestZonedMembers();
      expect(zoned.toString(), equals(zoned.getValues().toString()));
      expect(
        zoned.toString(),
        contains('@D@'),
        reason: 'zoned members keep their wire prefix',
      );
    });

    test('TomClass renders its reflected values', () {
      final person = TestPerson();
      person.name | 'Jane';
      person.age | 30;

      expect(
        person.toString(),
        equals('{name: Jane, age: 30, email: null, isActive: true}'),
      );
    });
  });

  group('TomList.resetWith', () {
    test('replaces all elements atomically', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2));

      list.resetWith([TomInt(10), TomInt(20), TomInt(30)]);

      expect(list.length, equals(3));
      expect(list.map((e) => e.get()), equals([10, 20, 30]));
    });

    test('clears the list when given an empty iterable', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2));

      list.resetWith(const []);

      expect(list.length, equals(0));
    });

    test('notifies observers exactly once for the whole replacement', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1));
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.resetWith([TomInt(2), TomInt(3), TomInt(4)]);

      expect(observer.notifyCount, equals(1));
    });

    test('observes the new elements and detaches the old ones', () {
      final list = TomList<TomInt>();
      final old = TomInt(1);
      list.append(old);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      final fresh = TomInt(2);
      list.resetWith([fresh]);
      observer.reset();

      // New element is observed → mutating it notifies the list.
      fresh.set(99);
      expect(observer.notifyCount, equals(1));

      // Old element is detached → mutating it no longer notifies the list.
      observer.reset();
      old.set(5);
      expect(observer.notifyCount, equals(0));
    });

    group('lifecycle listeners', () {
      test(
        'fires onBeforeClear before clearing and onAfterReset after install',
        () {
          final list = TomList<TomInt>();
          list.append(TomInt(1)).append(TomInt(2));
          final listener = _RecordingLifecycleListener();
          list.addLifecycleListener(listener);

          list.resetWith([TomInt(9)]);

          // onBeforeClear saw the original contents (list still intact).
          expect(listener.beforeClearLength, equals(2));
          // onAfterReset saw the fully populated new contents.
          expect(listener.afterResetLength, equals(1));
          expect(listener.callOrder, equals(['before', 'after']));
        },
      );

      test('removeLifecycleListener stops further callbacks', () {
        final list = TomList<TomInt>();
        final listener = _RecordingLifecycleListener();
        list.addLifecycleListener(listener);
        list.removeLifecycleListener(listener);

        list.resetWith([TomInt(1)]);

        expect(listener.callOrder, isEmpty);
      });

      test(
        'snapshots listeners so a listener may unregister during callback',
        () {
          final list = TomList<TomInt>();
          late _SelfRemovingLifecycleListener listener;
          listener = _SelfRemovingLifecycleListener(() {
            list.removeLifecycleListener(listener);
          });
          list.addLifecycleListener(listener);

          // Must not throw a concurrent-modification error.
          expect(() => list.resetWith([TomInt(1)]), returnsNormally);
          expect(listener.beforeCalls, equals(1));
        },
      );
    });
  });

  // Composite and single mutations must each notify observers exactly once,
  // never leaking half-applied intermediate state through extra
  // notifications. removeRange/insertAll/setAll/insert guard the ones that
  // already single-notify; replaceRange/retainWhere pin the rest.
  group('TomList mutation single-notification', () {
    TomList<TomInt> seeded(List<int> values) {
      final list = TomList<TomInt>();
      for (final v in values) {
        list.append(TomInt(v));
      }
      return list;
    }

    test('insert notifies exactly once', () {
      final list = seeded([1, 2, 3]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.insert(1, TomInt(9));

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([1, 9, 2, 3]));
    });

    test('insertAll notifies exactly once', () {
      final list = seeded([1, 2]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.insertAll(1, [TomInt(8), TomInt(9)]);

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([1, 8, 9, 2]));
    });

    test('setAll notifies exactly once', () {
      final list = seeded([1, 2, 3]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.setAll(1, [TomInt(20), TomInt(30)]);

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([1, 20, 30]));
    });

    test('removeRange notifies exactly once', () {
      final list = seeded([1, 2, 3, 4]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.removeRange(1, 3);

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([1, 4]));
    });

    test('removeRange over an empty range does not notify', () {
      final list = seeded([1, 2, 3]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.removeRange(1, 1);

      expect(observer.notifyCount, equals(0));
      expect(list.map((e) => e.get()), equals([1, 2, 3]));
    });

    test('replaceRange notifies exactly once', () {
      final list = seeded([1, 2, 3, 4]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.replaceRange(1, 3, [TomInt(20), TomInt(30), TomInt(40)]);

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([1, 20, 30, 40, 4]));
    });

    test('replaceRange observes the new elements and detaches removed ones', () {
      final list = seeded([1, 2, 3]);
      final removed = list[1];
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      final fresh = TomInt(99);
      list.replaceRange(1, 2, [fresh]);
      observer.reset();

      // New element is observed → mutating it notifies the list once.
      fresh.set(100);
      expect(observer.notifyCount, equals(1));

      // Removed element is detached → mutating it no longer notifies the list.
      observer.reset();
      removed.set(5);
      expect(observer.notifyCount, equals(0));
    });

    test('retainWhere notifies exactly once', () {
      final list = seeded([1, 2, 3, 4, 5]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.retainWhere((e) => e.get().isEven);

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => e.get()), equals([2, 4]));
    });
  });

  // Strongly typed Iterable overrides must accept the natural element-typed
  // callbacks, with no unchecked casts.
  group('TomList typed Iterable overrides', () {
    TomList<TomInt> seeded(List<int> values) {
      final list = TomList<TomInt>();
      for (final v in values) {
        list.append(TomInt(v));
      }
      return list;
    }

    test('firstWhere returns the orElse element-typed fallback', () {
      final list = seeded([1, 2, 3]);

      final fallback = TomInt(-1);
      final result = list.firstWhere(
        (e) => e.get() > 10,
        orElse: () => fallback,
      );

      expect(identical(result, fallback), isTrue);
    });

    test('reduce combines element-typed values', () {
      final list = seeded([1, 2, 3, 4]);

      final result = list.reduce(
        (value, element) => value.get() >= element.get() ? value : element,
      );

      expect(result.get(), equals(4));
    });

    test('followedBy chains another element-typed iterable', () {
      final list = seeded([1, 2]);

      final chained = list.followedBy([TomInt(3), TomInt(4)]);

      expect(chained.map((e) => e.get()), equals([1, 2, 3, 4]));
    });
  });

  // getValues/toJson must propagate a member serialization failure as a
  // TomObservableException instead of swallowing it into silent partial data.
  group('TomClass.getValues serialization failure', () {
    test('getValues throws TomObservableException when a member throws', () {
      final subject = TestThrowingMember();

      expect(() => subject.getValues(), throwsA(isA<TomObservableException>()));
    });

    test('toJson propagates the member serialization failure', () {
      final subject = TestThrowingMember();

      expect(() => subject.toJson(), throwsA(isA<TomObservableException>()));
    });
  });

  // A malformed value in the incoming map — the ordinary case when
  // deserializing untrusted JSON — must leave the object usable and must say
  // which key it choked on.
  group('TomClass.setOrMergeValues failure handling', () {
    test('a failed member set leaves the object and its members unmuted', () {
      final person = TestPerson();

      expect(
        () => person.setValues({'age': 'not a number'}),
        throwsA(isA<TomObservableException>()),
      );

      expect(person.isMuted, isFalse);
      expect(person.age.isMuted, isFalse);
      expect(person.name.isMuted, isFalse);
    });

    test('a later change still notifies after a failed setValues', () {
      final person = TestPerson();
      final observer = TestObserver<TomClass>();
      person.addObserver(observer);

      expect(
        () => person.setValues({'age': 'not a number'}),
        throwsA(isA<TomObservableException>()),
      );
      observer.reset();

      person.name.set('Bob');

      expect(observer.notifyCount, equals(1));
    });

    test('the failure names the key and the actual runtime type', () {
      final person = TestPerson();

      expect(
        () => person.setValues({'age': 'not a number'}),
        throwsA(
          isA<TomObservableException>()
              .having((e) => e.defaultUserMessage, 'message', contains("'age'"))
              .having((e) => e.parameters?['key'], 'parameters.key', 'age')
              // Asserted on the parameter rather than the message: the wrapped
              // TypeError's own text happens to mention `String` too, so a
              // message-only check would survive dropping the type entirely.
              .having(
                (e) => e.parameters?['valueType'],
                'parameters.valueType',
                'String',
              ),
        ),
      );
    });

    test('a mistyped list element names the key, the index and both types', () {
      final item = TestTaggedItem();

      expect(
        () => item.setValues({
          'tags': ['ok', 42],
        }),
        throwsA(
          isA<TomObservableException>()
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains("'tags'"),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('element 1'),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('TomInt'),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('TomString'),
              )
              .having((e) => e.parameters?['index'], 'parameters.index', 1),
        ),
      );
    });

    test('a mistyped list element leaves the existing elements intact', () {
      final item = TestTaggedItem();
      item.setValues({
        'tags': ['a', 'b'],
      });

      expect(
        () => item.setValues({
          'tags': ['c', 42],
        }),
        throwsA(isA<TomObservableException>()),
      );

      // The elements are built and checked before the list is touched, so a
      // rejected payload cannot leave the member emptied.
      expect(item.tags.map((e) => e.get()), equals(['a', 'b']));
    });

    test('a failure inside a nested TomClass leaves the outer one unmuted', () {
      final customer = TestCustomer();

      expect(
        () => customer.setValues({
          'address': {'zipCode': 12345},
        }),
        throwsA(isA<TomObservableException>()),
      );

      expect(customer.isMuted, isFalse);
      expect(customer.address.isMuted, isFalse);
      expect(customer.address.zipCode.isMuted, isFalse);
    });
  });

  // ==========================================================================
  // `merge` is the only thing that separates the two public entry points:
  // `setValues(v)` is `setOrMergeValues(v, false)`. It changes the treatment of
  // collection members alone — a list is appended to rather than replaced, a
  // map keeps the keys the payload does not mention — and it is handed down to
  // nested classes unchanged. Scalars are replaced in both modes, which is what
  // makes "merge" a statement about containers, not about values.
  // ==========================================================================
  group('TomClass.setOrMergeValues merge path', () {
    /// A priced item seeded through the replacing path, ready to be merged into.
    TestPricedItem seeded() {
      final item = TestPricedItem();
      item.setValues({
        'price': 10.0,
        'rates': [1.0, 2.0],
        'surcharges': {'ship': 5.0, 'tax': 7.0},
      });
      return item;
    }

    test('merging appends to a list member', () {
      final item = seeded();

      item.setOrMergeValues({
        'rates': [3.0],
      }, true);

      expect(item.rates.map((e) => e.get()), equals([1.0, 2.0, 3.0]));
    });

    test('setValues replaces a list member wholesale', () {
      final item = seeded();

      // The contrast that gives the merge flag its meaning: same payload, same
      // member, opposite outcome.
      item.setValues({
        'rates': [3.0],
      });

      expect(item.rates.map((e) => e.get()), equals([3.0]));
    });

    test('merging keeps map keys the payload does not mention', () {
      final item = seeded();

      item.setOrMergeValues({
        'surcharges': {'handling': 2.0},
      }, true);

      expect(
        item.surcharges.get().map((k, v) => MapEntry(k, v.get())),
        equals({'ship': 5.0, 'tax': 7.0, 'handling': 2.0}),
      );
    });

    test('setValues drops map keys the payload does not mention', () {
      final item = seeded();

      item.setValues({
        'surcharges': {'handling': 2.0},
      });

      expect(
        item.surcharges.get().map((k, v) => MapEntry(k, v.get())),
        equals({'handling': 2.0}),
      );
    });

    test('merging overwrites a map key the payload does mention', () {
      final item = seeded();

      item.setOrMergeValues({
        'surcharges': {'tax': 9.0},
      }, true);

      expect(item.surcharges['tax']!.get(), equals(9.0));
      expect(item.surcharges['ship']!.get(), equals(5.0));
    });

    test('merging still replaces a scalar member', () {
      final item = seeded();

      // There is no sense in which a scalar can be "merged"; the flag reaches
      // only the collection branches of _setMember.
      item.setOrMergeValues({'price': 99.0}, true);

      expect(item.price.get(), equals(99.0));
    });

    test('a member the payload omits is untouched in either mode', () {
      final item = seeded();

      item.setOrMergeValues({'price': 99.0}, true);
      expect(item.rates.length, equals(2));

      item.setValues({'price': 98.0});
      expect(item.rates.length, equals(2));
    });

    test('appended elements are observed by the list', () {
      final item = seeded();
      final observer = TestObserver<TestPricedItem>();
      item.addObserver(observer);

      item.setOrMergeValues({
        'rates': [3.0],
      }, true);
      observer.reset();
      item.rates.last | 30.0;

      // The append path goes through `add`, which registers the list as an
      // observer; a merge that skipped that would produce elements the
      // container cannot hear.
      expect(observer.notifyCount, equals(1));
    });

    test('merging notifies once for the whole payload', () {
      final item = seeded();
      final observer = TestObserver<TestPricedItem>();
      item.addObserver(observer);

      item.setOrMergeValues({
        'price': 99.0,
        'rates': [3.0],
        'surcharges': {'handling': 2.0},
      }, true);

      // The work runs inside a batch, so a multi-member update is one event.
      expect(observer.notifyCount, equals(1));
    });

    test('merging appends TomClass elements to a list', () {
      final item = TestTaggedItem();
      item.setValues({
        'subtasks': [
          {'title': 'first'},
        ],
      });

      item.setOrMergeValues({
        'subtasks': [
          {'title': 'second'},
        ],
      }, true);

      expect(
        item.subtasks.map((t) => t.title.get()),
        equals(['first', 'second']),
      );
    });

    test('merge propagates into a nested TomClass', () {
      final inventory = TestInventory();
      inventory.setValues({
        'item': {
          'rates': [1.0],
        },
      });

      inventory.setOrMergeValues({
        'item': {
          'rates': [2.0],
        },
      }, true);

      expect(inventory.item.rates.map((e) => e.get()), equals([1.0, 2.0]));
    });

    test('setValues replaces inside a nested TomClass', () {
      final inventory = TestInventory();
      inventory.setValues({
        'item': {
          'rates': [1.0],
        },
      });

      inventory.setValues({
        'item': {
          'rates': [2.0],
        },
      });

      expect(inventory.item.rates.map((e) => e.get()), equals([2.0]));
    });
  });

  // The batch mutators suppress their own notifications around a composite
  // edit; a throw in the middle must not leave that suppression in place.
  group('TomList batch mutator failure handling', () {
    TomList<TomInt> seeded(List<int> values) {
      final list = TomList<TomInt>();
      for (final v in values) {
        list.append(TomInt(v));
      }
      return list;
    }

    test('replaceRange leaves the list unmuted when the range is bad', () {
      final list = seeded([1, 2, 3]);

      expect(() => list.replaceRange(1, 99, [TomInt(9)]), throwsA(anything));

      expect(list.isMuted, isFalse);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);
      list.append(TomInt(4));
      expect(observer.notifyCount, equals(1));
    });

    test('retainWhere leaves the list unmuted when the predicate throws', () {
      final list = seeded([1, 2, 3]);

      expect(
        () => list.retainWhere((e) => throw StateError('predicate boom')),
        throwsA(isA<StateError>()),
      );

      expect(list.isMuted, isFalse);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);
      list.append(TomInt(4));
      expect(observer.notifyCount, equals(1));
    });
  });

  // ==========================================================================
  // The mutator notification contract (see doc/observable/observable.md):
  // a mutator notifies exactly once when it changed the container's contents,
  // and not at all when it left them as they were. "Contents" is the sequence
  // of element references, compared by identity — a change *inside* an element
  // reaches observers through `onNotify`, not through the mutator.
  //
  // `TomObject` does not override `==`, so every "same element" below means
  // the same object, and every "absent element" is genuinely absent even when
  // an equal-valued one is present.
  // ==========================================================================
  group('TomList notification contract', () {
    late TomList<TomInt> list;
    late TestObserver<TomList<TomInt>> observer;

    /// Builds a list of [values] with a fresh observer at a zero count.
    void seed(List<int> values) {
      list = TomList<TomInt>();
      for (final v in values) {
        list.append(TomInt(v));
      }
      observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);
    }

    test('remove notifies for a present element', () {
      seed([1, 2, 3]);
      final target = list[1];

      expect(list.remove(target), isTrue);

      expect(observer.notifyCount, equals(1));
      expect(list.length, equals(2));
    });

    test('remove notifies nothing for an absent element', () {
      seed([1, 2, 3]);

      expect(list.remove(TomInt(2)), isFalse);

      expect(observer.notifyCount, equals(0));
      expect(list.length, equals(3));
    });

    test('remove leaves a present element unobserved', () {
      seed([1, 2, 3]);
      final target = list[1];
      list.remove(target);
      observer.reset();

      target | 20;

      expect(observer.notifyCount, equals(0));
    });

    test('removeWhere that matches nothing notifies nothing', () {
      seed([1, 2, 3]);

      list.removeWhere((e) => false);

      expect(observer.notifyCount, equals(0));
      expect(list.length, equals(3));
    });

    test('removeWhere on an empty list notifies nothing', () {
      seed([]);

      list.removeWhere((e) => true);

      expect(observer.notifyCount, equals(0));
    });

    test('removeWhere notifies once however many elements it matches', () {
      seed([1, 2, 3, 4]);

      list.removeWhere((e) => e.get().isEven);

      expect(list.map((e) => e.get()), equals([1, 3]));
      expect(observer.notifyCount, equals(1));
    });

    test('removeWhere leaves the removed elements unobserved', () {
      seed([1, 2, 3]);
      final dropped = list[1];

      list.removeWhere((e) => e.get() == 2);
      observer.reset();
      dropped | 20;

      expect(observer.notifyCount, equals(0));
    });

    test('removeWhere leaves the surviving elements observed', () {
      seed([1, 2, 3]);
      final survivor = list[2];

      list.removeWhere((e) => e.get() == 2);
      observer.reset();
      survivor | 30;

      expect(observer.notifyCount, equals(1));
    });

    test('a shorter length truncates, deregisters and notifies once', () {
      seed([1, 2, 3]);
      final dropped = list[2];

      list.length = 2;

      expect(list.length, equals(2));
      expect(observer.notifyCount, equals(1));

      observer.reset();
      dropped | 30;
      expect(observer.notifyCount, equals(0));
    });

    test('assigning the current length notifies nothing', () {
      seed([1, 2, 3]);

      list.length = 3;

      expect(observer.notifyCount, equals(0));
    });

    test('growing the length is rejected by name', () {
      seed([1, 2]);

      expect(
        () => list.length = 4,
        throwsA(
          isA<TomObservableException>()
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('cannot be grown'),
              )
              .having((e) => e.parameters?['newLength'], 'newLength', 4)
              .having((e) => e.parameters?['length'], 'length', 2),
        ),
      );

      expect(list.length, equals(2));
      expect(observer.notifyCount, equals(0));
    });

    test('addAll notifies nothing for an empty iterable', () {
      seed([1, 2]);

      list.addAll([]);

      expect(observer.notifyCount, equals(0));
    });

    test('addAll notifies once for a non-empty iterable', () {
      seed([1, 2]);

      list.addAll([TomInt(3), TomInt(4)]);

      expect(observer.notifyCount, equals(1));
      expect(list.length, equals(4));
    });

    test('insertAll notifies nothing for an empty iterable', () {
      seed([1, 2]);

      list.insertAll(1, []);

      expect(observer.notifyCount, equals(0));
    });

    test('clear notifies nothing on an already empty list', () {
      seed([]);

      list.clear();

      expect(observer.notifyCount, equals(0));
    });

    test('clear notifies once on a non-empty list', () {
      seed([1, 2]);

      list.clear();

      expect(observer.notifyCount, equals(1));
    });

    test('index assignment of the same element notifies nothing', () {
      seed([1, 2, 3]);
      final existing = list[1];

      list[1] = existing;

      expect(observer.notifyCount, equals(0));
    });

    test('index assignment of the same element keeps it observed', () {
      seed([1, 2, 3]);
      final existing = list[1];

      // The naive implementation detaches before attaching; with the same
      // object on both sides that has to end attached, not detached.
      list[1] = existing;
      observer.reset();
      existing | 20;

      expect(observer.notifyCount, equals(1));
    });

    test('sorting an already sorted list notifies nothing', () {
      seed([1, 2, 3]);

      list.sort((a, b) => (~a).compareTo(~b));

      expect(observer.notifyCount, equals(0));
    });

    test('sorting into a new order notifies once', () {
      seed([3, 1, 2]);

      list.sort((a, b) => (~a).compareTo(~b));

      expect(observer.notifyCount, equals(1));
      expect(list.map((e) => ~e).toList(), equals([1, 2, 3]));
    });

    test('shuffling a single-element list notifies nothing', () {
      seed([1]);

      list.shuffle();

      expect(observer.notifyCount, equals(0));
    });

    test('setRange writing the same elements notifies nothing', () {
      seed([1, 2, 3]);
      final unchanged = [list[0], list[1]];

      list.setRange(0, 2, unchanged);

      expect(observer.notifyCount, equals(0));
    });

    test('setRange writing different elements notifies once', () {
      seed([1, 2, 3]);

      list.setRange(0, 2, [TomInt(8), TomInt(9)]);

      expect(observer.notifyCount, equals(1));
    });

    test('fillRange over an empty range notifies nothing', () {
      seed([1, 2, 3]);

      list.fillRange(1, 1, TomInt(9));

      expect(observer.notifyCount, equals(0));
    });

    test('setAll of an empty iterable notifies nothing', () {
      seed([1, 2, 3]);

      list.setAll(1, []);

      expect(observer.notifyCount, equals(0));
    });

    test('<< with the same elements notifies nothing', () {
      seed([1, 2, 3]);

      list << [list[0], list[1], list[2]];

      expect(observer.notifyCount, equals(0));
    });

    test('<< with different elements notifies once', () {
      seed([1, 2, 3]);

      list << [TomInt(7)];

      expect(observer.notifyCount, equals(1));
    });
  });

  group('TomMap notification contract', () {
    late TomMap<String, TomInt> map;
    late TestObserver<TomMap<String, TomInt>> observer;

    /// Builds a map of [values] with a fresh observer at a zero count.
    void seed(Map<String, int> values) {
      map = TomMap<String, TomInt>();
      values.forEach((k, v) => map[k] = TomInt(v));
      observer = TestObserver<TomMap<String, TomInt>>();
      map.addObserver(observer);
    }

    test('remove notifies for a present key', () {
      seed({'a': 1, 'b': 2});

      final removed = map.remove('a');

      expect(removed, isNotNull);
      expect(observer.notifyCount, equals(1));
      expect(map.length, equals(1));
    });

    test('remove notifies nothing for an absent key', () {
      seed({'a': 1});

      expect(map.remove('missing'), isNull);

      expect(observer.notifyCount, equals(0));
      expect(map.length, equals(1));
    });

    test('remove notifies nothing for a null key', () {
      seed({'a': 1});

      expect(map.remove(null), isNull);

      expect(observer.notifyCount, equals(0));
    });

    test('remove leaves the removed value unobserved', () {
      seed({'a': 1});
      final value = map['a']!;

      map.remove('a');
      observer.reset();
      value | 10;

      expect(observer.notifyCount, equals(0));
    });

    test('re-adding the same value under the same key notifies nothing', () {
      seed({'a': 1});
      final existing = map['a']!;

      map['a'] = existing;

      expect(observer.notifyCount, equals(0));
    });

    test('re-adding the same value keeps it observed', () {
      seed({'a': 1});
      final existing = map['a']!;

      map['a'] = existing;
      observer.reset();
      existing | 10;

      expect(observer.notifyCount, equals(1));
    });

    test('replacing a key with a different value notifies once', () {
      seed({'a': 1});

      map['a'] = TomInt(2);

      expect(observer.notifyCount, equals(1));
    });

    test('addAll of an empty map notifies nothing', () {
      seed({'a': 1});

      map.addAll({});

      expect(observer.notifyCount, equals(0));
    });

    test('addAll of new entries notifies once', () {
      seed({'a': 1});

      map.addAll({'b': TomInt(2), 'c': TomInt(3)});

      expect(observer.notifyCount, equals(1));
      expect(map.length, equals(3));
    });

    test('addEntries of nothing notifies nothing', () {
      seed({'a': 1});

      map.addEntries([]);

      expect(observer.notifyCount, equals(0));
    });

    test('clear notifies nothing on an already empty map', () {
      seed({});

      map.clear();

      expect(observer.notifyCount, equals(0));
    });

    test('clear notifies once on a non-empty map', () {
      seed({'a': 1});

      map.clear();

      expect(observer.notifyCount, equals(1));
    });

    test('removeWhere that matches nothing notifies nothing', () {
      seed({'a': 1, 'b': 2});

      map.removeWhere((key, value) => false);

      expect(observer.notifyCount, equals(0));
      expect(map.length, equals(2));
    });

    test('removeWhere that matches notifies once', () {
      seed({'a': 1, 'b': 2});

      map.removeWhere((key, value) => key == 'a');

      expect(observer.notifyCount, equals(1));
      expect(map.length, equals(1));
    });

    test('removeWhere leaves the surviving values observed', () {
      seed({'a': 1, 'b': 2});
      final survivor = map['b']!;

      map.removeWhere((key, value) => key == 'a');
      observer.reset();
      survivor | 20;

      expect(observer.notifyCount, equals(1));
    });

    test('update returning the same value notifies nothing', () {
      seed({'a': 1});

      map.update('a', (value) => value);

      expect(observer.notifyCount, equals(0));
    });

    test('update returning the same value keeps it observed', () {
      seed({'a': 1});
      final existing = map['a']!;

      map.update('a', (value) => value);
      observer.reset();
      existing | 10;

      expect(observer.notifyCount, equals(1));
    });

    test('update returning a different value notifies once', () {
      seed({'a': 1});

      map.update('a', (value) => TomInt(2));

      expect(observer.notifyCount, equals(1));
    });

    test('update via ifAbsent notifies once', () {
      seed({'a': 1});

      map.update('b', (value) => value, ifAbsent: () => TomInt(2));

      expect(observer.notifyCount, equals(1));
    });

    // The callback may do both things at once: mutate the value it was handed
    // (which reaches the map through its observation of that value) and return
    // a replacement (which the map announces itself). That is still one call,
    // so it is still one notification.
    test('update notifies once when the callback mutates and replaces', () {
      seed({'a': 1});
      final original = map['a']!;

      map.update('a', (value) {
        value.set(99);
        return TomInt(2);
      });

      expect(observer.notifyCount, equals(1));
      expect(original.get(), equals(99));
      expect(map['a']!.get(), equals(2));
    });

    test('updateAll notifies once when the callbacks mutate and replace', () {
      seed({'a': 1, 'b': 2});

      map.updateAll((key, value) {
        value.set(value.get() * 100);
        return TomInt(value.get() + 1);
      });

      expect(observer.notifyCount, equals(1));
    });

    test('updateAll returning the same values notifies nothing', () {
      seed({'a': 1, 'b': 2});

      map.updateAll((key, value) => value);

      expect(observer.notifyCount, equals(0));
    });

    test('updateAll returning a different value notifies once', () {
      seed({'a': 1, 'b': 2});

      map.updateAll((key, value) => key == 'a' ? TomInt(9) : value);

      expect(observer.notifyCount, equals(1));
    });

    test('putIfAbsent on a present key notifies nothing', () {
      seed({'a': 1});

      map.putIfAbsent('a', () => TomInt(9));

      expect(observer.notifyCount, equals(0));
    });

    test('putIfAbsent on an absent key notifies once', () {
      seed({'a': 1});

      map.putIfAbsent('b', () => TomInt(9));

      expect(observer.notifyCount, equals(1));
    });

    test('<< with the same contents notifies nothing', () {
      seed({'a': 1, 'b': 2});

      map << {'a': map['a']!, 'b': map['b']!};

      expect(observer.notifyCount, equals(0));
    });

    test('<< with different contents notifies once', () {
      seed({'a': 1});

      map << {'a': TomInt(9)};

      expect(observer.notifyCount, equals(1));
    });
  });

  // ==========================================================================
  // Mute nests (see doc/observable/observable.md, "Nested Muting").
  //
  // `mute` counts depth rather than setting a flag, so a batching method
  // called from inside an enclosing batch suppresses its own notifications
  // without releasing the caller's. The single notification is emitted by the
  // outermost `unmute`, and only if something actually changed.
  // ==========================================================================
  group('mute nesting', () {
    test('two mutes need two unmutes before notifications resume', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();
      observable.addObserver(observer);

      observable.mute();
      observable.mute();
      expect(observable.isMuted, isTrue);

      observable.notifyObservers();
      expect(observer.notifyCount, equals(0));

      // Inner release: still muted, still silent.
      observable.unmute();
      expect(observable.isMuted, isTrue);
      expect(observer.notifyCount, equals(0));

      // Outer release: one consolidated notification.
      observable.unmute();
      expect(observable.isMuted, isFalse);
      expect(observer.notifyCount, equals(1));
    });

    test(
      'a nested batch that changes nothing leaves the outer batch clean',
      () {
        final observable = TomObservable();
        final observer = TestObserver<TomObservable>();
        observable.addObserver(observer);

        observable.mute();
        observable.mute();
        observable.unmute();
        observable.unmute();

        expect(observer.notifyCount, equals(0));
      },
    );

    test(
      'unmute on an unmuted observable is a no-op, not a negative depth',
      () {
        final observable = TomObservable();
        final observer = TestObserver<TomObservable>();
        observable.addObserver(observer);

        observable.unmute();
        expect(observable.isMuted, isFalse);
        expect(observer.notifyCount, equals(0));

        // The stray unmute must not have left the depth at -1, which would make
        // the next mute() fail to actually mute.
        observable.mute();
        expect(observable.isMuted, isTrue);
        observable.notifyObservers();
        expect(observer.notifyCount, equals(0));
        observable.unmute();
        expect(observer.notifyCount, equals(1));
      },
    );
  });

  // ==========================================================================
  // The batch mutators (`replaceRange`, `retainWhere`, `setOrMergeValues`,
  // `TomMap.update` / `updateAll`) suppress their own notifications while they
  // work. Called inside an enclosing batch they must suppress and no more --
  // releasing the caller's batch early would emit exactly the notification the
  // caller was consolidating.
  // ==========================================================================
  group('batch mutators inside an enclosing mute', () {
    TomList<TomInt> seeded(List<int> values) {
      final list = TomList<TomInt>();
      for (final v in values) {
        list.append(TomInt(v));
      }
      return list;
    }

    test(
      'replaceRange inside an outer mute notifies once, at the outer unmute',
      () {
        final list = seeded([1, 2, 3]);
        final observer = TestObserver<TomList<TomInt>>();
        list.addObserver(observer);

        list.mute();
        list.replaceRange(1, 2, [TomInt(9)]);
        expect(
          observer.notifyCount,
          equals(0),
          reason: 'the outer mute is still held',
        );

        list.unmute();
        expect(observer.notifyCount, equals(1));
      },
    );

    test(
      'retainWhere inside an outer mute notifies once, at the outer unmute',
      () {
        final list = seeded([1, 2, 3]);
        final observer = TestObserver<TomList<TomInt>>();
        list.addObserver(observer);

        list.mute();
        list.retainWhere((e) => e.get() != 2);
        expect(
          observer.notifyCount,
          equals(0),
          reason: 'the outer mute is still held',
        );

        list.unmute();
        expect(observer.notifyCount, equals(1));
        expect(list.length, equals(2));
      },
    );

    test('replaceRange and retainWhere in one batch notify once in total', () {
      final list = seeded([1, 2, 3, 4]);
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.mute();
      list.replaceRange(0, 1, [TomInt(10)]);
      list.retainWhere((e) => e.get() != 3);
      expect(observer.notifyCount, equals(0));

      list.unmute();
      expect(observer.notifyCount, equals(1));
    });

    test(
      'TomMap.update inside an outer mute notifies once, at the outer unmute',
      () {
        final map = TomMap<String, TomInt>();
        map['a'] = TomInt(1);
        final observer = TestObserver<TomMap<String, TomInt>>();
        map.addObserver(observer);

        map.mute();
        map.update('a', (v) => TomInt(2));
        expect(observer.notifyCount, equals(0));

        map.unmute();
        expect(observer.notifyCount, equals(1));
      },
    );

    test('TomMap.updateAll inside an outer mute notifies once', () {
      final map = TomMap<String, TomInt>();
      map['a'] = TomInt(1);
      map['b'] = TomInt(2);
      final observer = TestObserver<TomMap<String, TomInt>>();
      map.addObserver(observer);

      map.mute();
      map.updateAll((k, v) => TomInt(v.get() * 10));
      expect(observer.notifyCount, equals(0));

      map.unmute();
      expect(observer.notifyCount, equals(1));
    });

    test('setOrMergeValues inside an outer mute notifies once', () {
      final person = TestPerson();
      final observer = TestObserver<TestPerson>();
      person.addObserver(observer);

      person.mute();
      person.setValues({'name': 'Ada'});
      expect(observer.notifyCount, equals(0));

      person.unmute();
      expect(observer.notifyCount, equals(1));
      expect(person.name.get(), equals('Ada'));
    });
  });

  // ==========================================================================
  // `mute` cascades to the members a composite held *when it was called*, and
  // `unmute` releases exactly those. Membership changes made during the batch
  // must not leak: an element added mid-batch was never muted by this batch and
  // must not be unmuted by it (which would drive its depth negative), and an
  // element removed mid-batch was muted by this batch and must still be
  // released (or it stays silent forever).
  // ==========================================================================
  group('mute cascade bookkeeping', () {
    test('an element added during a batch is left unmuted', () {
      final list = TomList<TomInt>();
      final first = TomInt(1);
      list.append(first);

      list.mute();
      final added = TomInt(2);
      list.append(added);
      list.unmute();

      expect(first.isMuted, isFalse);
      expect(added.isMuted, isFalse);

      // The real damage of an unbalanced release is a negative depth, which
      // shows up as the *next* mute failing to take effect.
      final observer = TestObserver<TomInt>();
      added.addObserver(observer);
      added.mute();
      added.set(3);
      expect(
        observer.notifyCount,
        equals(0),
        reason: 'depth must not have gone negative during the batch',
      );
      added.unmute();
      expect(observer.notifyCount, equals(1));
    });

    test('an element removed during a batch is still released', () {
      final list = TomList<TomInt>();
      final removed = TomInt(1);
      final kept = TomInt(2);
      list.append(removed);
      list.append(kept);

      list.mute();
      list.remove(removed);
      list.unmute();

      expect(
        removed.isMuted,
        isFalse,
        reason: 'the batch muted it, so the batch must release it',
      );
      expect(kept.isMuted, isFalse);

      final observer = TestObserver<TomInt>();
      removed.addObserver(observer);
      removed.set(9);
      expect(observer.notifyCount, equals(1));
    });

    test('a map value removed during a batch is still released', () {
      final map = TomMap<String, TomInt>();
      final removed = TomInt(1);
      map['a'] = removed;
      map['b'] = TomInt(2);

      map.mute();
      map.remove('a');
      map.unmute();

      expect(removed.isMuted, isFalse);
    });

    test('nested composite mutes cascade and release symmetrically', () {
      final customer = TestCustomer();

      customer.mute();
      expect(customer.address.isMuted, isTrue);
      expect(customer.address.city.isMuted, isTrue);

      customer.mute();
      customer.unmute();
      expect(customer.isMuted, isTrue, reason: 'the outer mute is still held');
      expect(
        customer.address.city.isMuted,
        isTrue,
        reason: 'the outer mute still holds the cascade',
      );

      customer.unmute();
      expect(customer.isMuted, isFalse);
      expect(customer.address.isMuted, isFalse);
      expect(customer.address.city.isMuted, isFalse);
    });
  });

  // ==========================================================================
  // `batch` and `batchSelf` are the scoped forms of mute/unmute. They exist so
  // that callers cannot forget the release -- including on the throwing path.
  // ==========================================================================
  group('batch and batchSelf', () {
    test('batch consolidates the enclosed changes into one notification', () {
      final list = TomList<TomInt>();
      final observer = TestObserver<TomList<TomInt>>();
      list.addObserver(observer);

      list.batch(() {
        list.append(TomInt(1));
        list.append(TomInt(2));
        list.append(TomInt(3));
      });

      expect(observer.notifyCount, equals(1));
      expect(list.length, equals(3));
    });

    test('batch returns the body result', () {
      final list = TomList<TomInt>();

      final result = list.batch(() {
        list.append(TomInt(7));
        return list.length;
      });

      expect(result, equals(1));
    });

    test('batch releases the mute when the body throws', () {
      final list = TomList<TomInt>();
      final element = TomInt(1);
      list.append(element);

      expect(
        () => list.batch(() {
          list.append(TomInt(2));
          throw StateError('body boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect(list.isMuted, isFalse);
      expect(
        element.isMuted,
        isFalse,
        reason: 'the cascade must be released too',
      );
    });

    test('batch nests', () {
      final observable = TomObservable();
      final observer = TestObserver<TomObservable>();
      observable.addObserver(observer);

      observable.batch(() {
        observable.batch(() {
          observable.notifyObservers();
        });
        expect(
          observer.notifyCount,
          equals(0),
          reason: 'the inner batch must not release the outer one',
        );
      });

      expect(observer.notifyCount, equals(1));
    });

    test('batchSelf suppresses the container only, not its members', () {
      final list = TomList<TomInt>();
      final element = TomInt(1);
      list.append(element);

      list.batchSelf(() {
        expect(list.isMuted, isTrue);
        expect(element.isMuted, isFalse, reason: 'batchSelf does not cascade');
      });

      expect(list.isMuted, isFalse);
    });

    test('batchSelf releases the mute when the body throws', () {
      final list = TomList<TomInt>();

      expect(
        () => list.batchSelf(() => throw StateError('body boom')),
        throwsA(isA<StateError>()),
      );

      expect(list.isMuted, isFalse);
    });
  });

  // ==========================================================================
  // Deserializing numbers
  // ==========================================================================

  group('deserializing numbers', () {
    late TestPricedItem item;

    setUp(() => item = TestPricedItem());

    group('the untyped path (TomObject._createFrom, via a TomMap member)', () {
      test('a fractional number becomes a TomDouble, not tomNull', () {
        item.setValues({
          'surcharges': {'handling': 4.25},
        });

        final wrapped = item.surcharges['handling'];
        expect(
          wrapped,
          isA<TomDouble>(),
          reason:
              'a JSON double has a first-class leaf; it must not fall '
              'through to tomNull',
        );
        expect(wrapped!.get(), equals(4.25));
      });

      test('an integral number in a double-valued map widens to TomDouble', () {
        item.setValues({
          'surcharges': {'handling': 4},
        });

        // `4 == 4.0` in Dart, so the value alone proves nothing here — the
        // point of the assertion is the runtime type.
        expect(item.surcharges['handling'], isA<TomDouble>());
        expect(item.surcharges['handling']!.get(), isA<double>());
        expect(item.surcharges['handling']!.get(), equals(4.0));
      });

      // The other half of the rule: an element type which merely *accepts* a
      // double is not a reason to produce one. An untyped container accepts
      // anything, so nothing about it says "double", and an integer stays an
      // integer.
      test('an integer in an untyped list stays an integer', () {
        final untyped = TestUntypedContainers();

        untyped.setValues({
          'anyList': [1, 2.5],
        });

        expect(untyped.anyList[0], isA<TomInt>());
        expect(untyped.anyList[0].get(), equals(1));
        expect(untyped.anyList[1], isA<TomDouble>());
        expect(untyped.anyList[1].get(), equals(2.5));
      });

      test('an integer in an untyped map stays an integer', () {
        final untyped = TestUntypedContainers();

        untyped.setValues({
          'anyMap': {'whole': 1, 'fractional': 2.5},
        });

        expect(untyped.anyMap['whole'], isA<TomInt>());
        expect(untyped.anyMap['whole']!.get(), equals(1));
        expect(untyped.anyMap['fractional'], isA<TomDouble>());
        expect(untyped.anyMap['fractional']!.get(), equals(2.5));
      });

      test('a fractional number nested in a list survives', () {
        item.setValues({
          'rates': [1.5, 2.25],
        });

        expect(item.rates.map((e) => e.get()).toList(), equals([1.5, 2.25]));
      });

      test('integral numbers in a TomList<TomDouble> widen', () {
        item.setValues({
          'rates': [1, 2],
        });

        expect(item.rates, everyElement(isA<TomDouble>()));
        expect(item.rates.map((e) => e.get()), everyElement(isA<double>()));
        expect(item.rates.map((e) => e.get()).toList(), equals([1.0, 2.0]));
      });

      test('integral numbers in a TomList<TomInt> stay integers', () {
        // The widening is keyed on the destination, so an int-holding list
        // must be left alone — otherwise every integer in the system would
        // quietly become a double.
        item.setValues({
          'counts': [1, 2],
        });

        expect(item.counts, everyElement(isA<TomInt>()));
        expect(item.counts.map((e) => e.get()), everyElement(isA<int>()));
      });

      test('integral numbers in a TomList<TomNDouble> widen', () {
        // The nullable double list is a double-holding destination too, so the
        // widening has to fire for it and the widened value has to be
        // installable. It is the case that distinguishes a destination test
        // written against `TomObject<double?>` from one written against the
        // non-nullable `TomObject<double>`.
        final nullable = TestNullableElements();

        nullable.setValues({
          'rates': [1, 2],
        });

        expect(nullable.rates, everyElement(isA<TomNDouble>()));
        expect(nullable.rates.map((e) => e.get()).toList(), equals([1.0, 2.0]));
      });
    });

    group('the typed path (a scalar member)', () {
      test('a fractional number reaches a TomDouble field', () {
        item.setValues({'price': 19.99});

        expect(item.price.get(), equals(19.99));
      });

      test('an integral number reaches a TomDouble field as a double', () {
        // JSON has one number type. A producer that writes 20 rather than
        // 20.0 — JavaScript's JSON.stringify does exactly this — must not
        // fail to load into a double field.
        item.setValues({'price': 20});

        expect(item.price.get(), isA<double>());
        expect(item.price.get(), equals(20.0));
      });

      test('an integral number reaches a TomNDouble field as a double', () {
        item.setValues({'discount': 5});

        expect(item.discount.get(), isA<double>());
        expect(item.discount.get(), equals(5.0));
      });

      test('null still clears a nullable double field', () {
        item.discount | 2.5;

        item.setValues({'discount': null});

        expect(item.discount.get(), isNull);
      });

      test('a fractional number is refused by an int field', () {
        // The widening is one-directional. Narrowing 2.5 to an int would
        // discard data silently, which is the defect this group exists to
        // prevent, not a convenience to add.
        expect(
          () => item.setValues({'quantity': 2.5}),
          throwsA(isA<TomObservableException>()),
        );
      });

      test('an integer still reaches an int field as an int', () {
        item.setValues({'quantity': 7});

        expect(item.quantity.get(), equals(7));
        expect(item.quantity.get(), isA<int>());
      });
    });

    group('round trips', () {
      test('a fractional price survives getValues/setValues', () {
        item.price | 19.99;
        item.quantity | 3;

        final restored = TestPricedItem()..setValues(item.getValues());

        expect(restored.price.get(), equals(19.99));
        expect(restored.quantity.get(), equals(3));
      });

      test('a price survives a real JSON encode/decode round trip', () {
        // The map member is left empty on purpose: `_serializeMember` has no
        // TomMap branch, so a populated map member fails at `jsonEncode`
        // before any of this reaches the number handling. That is a separate
        // defect, and it afflicts every value type equally — the map's number
        // handling is covered above through `setValues`.
        item.price | 19.99;
        item.discount | 1.5;
        item.rates.addAll([TomDouble(0.5), TomDouble(1.25)]);

        final restored = TestPricedItem()..fromJson(jsonEncode(item.toJson()));

        expect(restored.price.get(), equals(19.99));
        expect(restored.discount.get(), equals(1.5));
        expect(
          restored.rates.map((e) => e.get()).toList(),
          equals([0.5, 1.25]),
        );
      });

      test('an integral double survives the JSON round trip as a double', () {
        // The encoder writes 20.0, but a hand-edited or foreign payload may
        // carry 20; both must land as a double.
        item.price | 20.0;

        final restored = TestPricedItem()..fromJson(jsonEncode(item.toJson()));

        expect(restored.price.get(), isA<double>());
        expect(restored.price.get(), equals(20.0));
      });
    });
  });

  // TomList and TomMap are the only observables that override == / hashCode,
  // and they exist to state — rather than merely inherit — that a container is
  // equal to nothing but itself. The rule is load-bearing: these are mutable
  // cells, so a hash that tracked their contents would move underneath any Set
  // that held them. These tests pin identity in both directions: distinct
  // instances stay unequal however alike their contents, and one instance stays
  // findable however much its contents change.
  group('a nullable element type deserializes', () {
    // `_createFrom` chooses from the runtime type of the payload alone, so it
    // only ever built the non-nullable leaves. Every container whose element
    // type was a nullable sibling therefore rejected every element it was
    // given — a `TomList<TomNString>` refused a plain string — and a JSON
    // `null` had no representation among the leaves at all.
    late TestNullableElements item;

    setUp(() => item = TestNullableElements());

    test('each nullable leaf type accepts its own value', () {
      item.setValues({
        'tags': ['a'],
        'counts': [1],
        'rates': [1.5],
        'flags': [true],
        'stamps': ['@!@2024-01-15T09:30:00.000Z'],
      });

      expect(item.tags.single, isA<TomNString>());
      expect(item.tags.single.get(), equals('a'));
      expect(item.counts.single, isA<TomNInt>());
      expect(item.counts.single.get(), equals(1));
      expect(item.rates.single, isA<TomNDouble>());
      expect(item.rates.single.get(), equals(1.5));
      expect(item.flags.single, isA<TomNBool>());
      expect(item.flags.single.get(), isTrue);
      expect(item.stamps.single, isA<TomNDateTime>());
      expect(
        item.stamps.single.get(),
        equals(DateTime.parse('2024-01-15T09:30:00.000Z')),
      );
    });

    test('a null element becomes the nullable leaf holding null', () {
      // The point of a nullable element type. `_createFrom(null)` answers the
      // tomNull sentinel, which is not an instance of any leaf type, so this
      // is the case that had no representation at all before.
      item.setValues({
        'tags': ['a', null],
        'flags': [null],
      });

      expect(item.tags.map((e) => e.get()).toList(), equals(['a', null]));
      expect(item.tags[1], isA<TomNString>());
      expect(item.flags.single, isA<TomNBool>());
      expect(item.flags.single.get(), isNull);
    });

    test('a nullable map value is built the same way', () {
      item.setValues({
        'labels': {'set': 'v', 'unset': null},
      });

      expect(item.labels['set'], isA<TomNString>());
      expect(item.labels['set']!.get(), equals('v'));
      expect(item.labels['unset'], isA<TomNString>());
      expect(item.labels['unset']!.get(), isNull);
    });

    test('a nullable zoned element parses its prefixed wire form', () {
      item.setValues({
        'zoned': ['@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo', null],
      });

      expect(item.zoned.first, isA<TomNOZonedDateTime>());
      expect(item.zoned.first.get()?.timezone.timezone, equals('Asia/Tokyo'));
      expect(item.zoned[1].get(), isNull);
    });

    test('a value the element type cannot hold is still refused', () {
      // The factory only widens what is accepted; a genuine mismatch must
      // still be reported by the element check, which names the member and
      // the position rather than failing as a bare cast.
      expect(
        () => item.setValues({
          'counts': ['not a number'],
        }),
        throwsA(isA<TomObservableException>()),
      );
    });

    test('a non-nullable element type still refuses a null', () {
      // The rule is keyed on the destination: only a nullable element type
      // gains the ability to hold one.
      expect(
        () => TestPricedItem().setValues({
          'counts': [null],
        }),
        throwsA(isA<TomObservableException>()),
      );
    });
  });

  group('an untyped container member deserializes', () {
    // `TomList<TomObject>` / `TomMap<String, TomObject>` commit to no element
    // type. Both setters used to resolve the element's ClassMirror before
    // looking at the payload, and reflection refuses a generic element type
    // because for every committed member shape that means a nested collection
    // — so an untyped member threw on every setValues, including an empty one.
    late TestUntypedContainers item;

    setUp(() => item = TestUntypedContainers());

    test('an empty payload is accepted', () {
      item.setValues({'anyList': <dynamic>[], 'anyMap': <String, dynamic>{}});

      expect(item.anyList, isEmpty);
      expect(item.anyMap, isEmpty);
    });

    test('a list of mixed scalars keeps each element its own type', () {
      item.setValues({
        'anyList': ['text', 7, 1.5, true],
      });

      expect(
        item.anyList.map((e) => e.runtimeType.toString()).toList(),
        equals(['TomString', 'TomInt', 'TomDouble', 'TomBool']),
      );
      expect(
        item.anyList.map((e) => e.get()).toList(),
        equals(['text', 7, 1.5, true]),
      );
    });

    test('a map of mixed scalars keeps each value its own type', () {
      item.setValues({
        'anyMap': {'s': 'text', 'i': 7, 'd': 1.5, 'b': true},
      });

      expect(item.anyMap['s'], isA<TomString>());
      expect(item.anyMap['i'], isA<TomInt>());
      expect(item.anyMap['d'], isA<TomDouble>());
      expect(item.anyMap['b'], isA<TomBool>());
    });

    // The recursive branches of `TomObject._createFrom` build a TomMap or a
    // TomList for a nested payload. An untyped member is the only destination
    // that can hold one, so before this fix those branches were unreachable
    // from deserialization.
    test('a nested map becomes a TomMap element', () {
      item.setValues({
        'anyList': [
          {'inner': 3},
        ],
      });

      final nested = item.anyList.single;
      expect(nested, isA<TomMap>());
      expect(((nested as TomMap)['inner'] as TomObject).get(), equals(3));
    });

    test('a nested list becomes a TomList value', () {
      item.setValues({
        'anyMap': {
          'row': [1, 'two'],
        },
      });

      final nested = item.anyMap['row'];
      expect(nested, isA<TomList>());
      expect(
        (nested as TomList).map((e) => e.get()).toList(),
        equals([1, 'two']),
      );
    });

    test('a committed element type still rejects a wrong element', () {
      // The fix must not loosen a member that *does* name its element type.
      expect(
        () => TestPricedItem().setValues({
          'counts': ['not a number'],
        }),
        throwsA(isA<TomObservableException>()),
      );
    });
  });

  group('container equality is identity, not contents', () {
    group('TomList', () {
      test('equal contents in distinct instances are unequal', () {
        final a = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
        final b = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);

        expect(a == b, isFalse);
      });

      test('a list equals itself', () {
        final list = TomList<TomInt>()..add(TomInt(1));

        expect(list == list, isTrue);
      });

      test('two lists sharing one backing list are still unequal', () {
        // TomList.ofList adopts the caller's list rather than copying it, so
        // two containers can alias the same backing collection. They remain
        // two cells with two observer sets, so they are not equal.
        final backing = [TomInt(1), TomInt(2)];
        final a = TomList<TomInt>.ofList(backing);
        final b = TomList<TomInt>.ofList(backing);

        expect(a == b, isFalse);
        expect(a.hashCode == b.hashCode, isFalse);
      });

      test('a list is unequal to a non-list', () {
        final list = TomList<TomInt>()..add(TomInt(1));

        expect(list == TomInt(1), isFalse);
        expect(list == Object(), isFalse);
      });

      test('hashCode survives an element mutation', () {
        final list = TomList<TomInt>()..add(TomInt(1));
        final before = list.hashCode;

        list.add(TomInt(2));
        list[0] | 99;

        expect(list.hashCode, equals(before));
      });

      test('hashCode survives a wholesale replacement', () {
        // `<<` installs a *new* backing list; hashing that list would move the
        // container's hash.
        final list = TomList<TomInt>()..add(TomInt(1));
        final before = list.hashCode;

        list << [TomInt(7), TomInt(8)];

        expect(list.hashCode, equals(before));
      });

      test('a mutated list is still found in a Set', () {
        final list = TomList<TomInt>()..add(TomInt(1));
        final set = {list};

        list << [TomInt(7)];
        list.add(TomInt(8));

        expect(set.contains(list), isTrue);
      });

      test('a Set keeps two lists with equal contents apart', () {
        final a = TomList<TomInt>()..add(TomInt(1));
        final b = TomList<TomInt>()..add(TomInt(1));

        expect({a, b}, hasLength(2));
      });

      test('contents are compared by unwrapping the elements', () {
        // The recipe the dartdoc prescribes, since the elements are themselves
        // observables and compare by identity in turn.
        bool sameContents(TomList<TomInt> a, TomList<TomInt> b) =>
            a.length == b.length &&
            Iterable<int>.generate(a.length).every((i) => ~a[i] == ~b[i]);

        final a = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
        final b = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
        final c = TomList<TomInt>()..addAll([TomInt(1), TomInt(3)]);

        expect(sameContents(a, b), isTrue);
        expect(sameContents(a, c), isFalse);
      });
    });

    group('TomMap', () {
      TomMap<String, TomInt> mapOf(Map<String, int> values) {
        final map = TomMap<String, TomInt>();
        values.forEach((k, v) => map[k] = TomInt(v));
        return map;
      }

      test('equal contents in distinct instances are unequal', () {
        expect(mapOf({'a': 1}) == mapOf({'a': 1}), isFalse);
      });

      test('a map equals itself', () {
        final map = mapOf({'a': 1});

        expect(map == map, isTrue);
      });

      test('a map is unequal to a non-map', () {
        final map = mapOf({'a': 1});

        expect(map == TomInt(1), isFalse);
        expect(map == Object(), isFalse);
      });

      test('hashCode survives an entry mutation', () {
        final map = mapOf({'a': 1});
        final before = map.hashCode;

        map['b'] = TomInt(2);
        map.remove('a');

        expect(map.hashCode, equals(before));
      });

      test('hashCode survives a wholesale replacement', () {
        final map = mapOf({'a': 1});
        final before = map.hashCode;

        map << {'x': TomInt(9)};

        expect(map.hashCode, equals(before));
      });

      test('a mutated map is still found in a Set', () {
        final map = mapOf({'a': 1});
        final set = {map};

        map << {'x': TomInt(9)};
        map['y'] = TomInt(10);

        expect(set.contains(map), isTrue);
      });

      test('a Set keeps two maps with equal contents apart', () {
        expect({
          mapOf({'a': 1}),
          mapOf({'a': 1}),
        }, hasLength(2));
      });

      test('contents are compared by unwrapping the values', () {
        bool sameContents(TomMap<String, TomInt> a, TomMap<String, TomInt> b) =>
            a.length == b.length &&
            a.keys.every((k) => b.containsKey(k) && ~a[k]! == ~b[k]!);

        expect(sameContents(mapOf({'a': 1}), mapOf({'a': 1})), isTrue);
        expect(sameContents(mapOf({'a': 1}), mapOf({'a': 2})), isFalse);
        expect(sameContents(mapOf({'a': 1}), mapOf({'b': 1})), isFalse);
      });
    });
  });

  // castFrom copies the structure and shares the elements. The two halves of
  // that sentence are both load-bearing: sharing the *structure* would let one
  // container grow the other without notifying it and leave the newcomers
  // unobserved on the far side, while copying the *elements* is impossible —
  // a cast re-types what is there, it cannot manufacture replacements. Both
  // containers therefore observe the shared elements, and neither can disturb
  // the other's shape.
  group('castFrom copies the structure and shares the elements', () {
    group('TomList', () {
      test('the cast holds the very same element instances', () {
        final source = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);

        final cast = TomList.castFrom<TomInt, TomInt>(source);

        expect(cast.length, equals(2));
        expect(identical(cast[0], source[0]), isTrue);
        expect(identical(cast[1], source[1]), isTrue);
      });

      test('growing the cast leaves the source the length it was', () {
        final source = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
        final cast = TomList.castFrom<TomInt, TomInt>(source);

        cast.add(TomInt(3));

        expect(cast.length, equals(3));
        expect(source.length, equals(2));
      });

      test('growing the source leaves the cast the length it was', () {
        final source = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
        final cast = TomList.castFrom<TomInt, TomInt>(source);

        source.add(TomInt(3));

        expect(source.length, equals(3));
        expect(cast.length, equals(2));
      });

      test('a change inside a shared element notifies both', () {
        final source = TomList<TomInt>()..add(TomInt(1));
        final cast = TomList.castFrom<TomInt, TomInt>(source);
        final sourceObserver = TestObserver<TomList<TomInt>>();
        final castObserver = TestObserver<TomList<TomInt>>();
        source.addObserver(sourceObserver);
        cast.addObserver(castObserver);

        source[0] | 99;

        expect(sourceObserver.notifyCount, equals(1));
        expect(castObserver.notifyCount, equals(1));
      });

      test('an element added to the cast is unknown to the source', () {
        final source = TomList<TomInt>()..add(TomInt(1));
        final cast = TomList.castFrom<TomInt, TomInt>(source);
        final sourceObserver = TestObserver<TomList<TomInt>>();
        final castObserver = TestObserver<TomList<TomInt>>();
        source.addObserver(sourceObserver);
        cast.addObserver(castObserver);

        final newcomer = TomInt(7);
        cast.add(newcomer);
        newcomer | 8;

        // One notification for the add, one for the change — both on the cast.
        expect(castObserver.notifyCount, equals(2));
        expect(sourceObserver.notifyCount, equals(0));
      });

      test('an element added to the source is unknown to the cast', () {
        final source = TomList<TomInt>()..add(TomInt(1));
        final cast = TomList.castFrom<TomInt, TomInt>(source);
        final sourceObserver = TestObserver<TomList<TomInt>>();
        final castObserver = TestObserver<TomList<TomInt>>();
        source.addObserver(sourceObserver);
        cast.addObserver(castObserver);

        final newcomer = TomInt(7);
        source.add(newcomer);
        newcomer | 8;

        expect(sourceObserver.notifyCount, equals(2));
        expect(castObserver.notifyCount, equals(0));
      });

      test(
        'removing from the cast leaves the source observing the element',
        () {
          final source = TomList<TomInt>()..addAll([TomInt(1), TomInt(2)]);
          final cast = TomList.castFrom<TomInt, TomInt>(source);
          final sourceObserver = TestObserver<TomList<TomInt>>();
          source.addObserver(sourceObserver);

          final shared = cast[0];
          cast.remove(shared);
          shared | 99;

          expect(source.length, equals(2));
          expect(sourceObserver.notifyCount, equals(1));
        },
      );

      test('the element type can be widened', () {
        final source = TomList<TomInt>()..add(TomInt(1));

        final widened = TomList.castFrom<TomInt, TomObject>(source);

        expect(widened, isA<TomList<TomObject>>());
        expect(identical(widened.first, source.first), isTrue);
      });

      test('a mismatched element type throws at the cast, not on a read', () {
        final source = TomList<TomInt>()..add(TomInt(1));

        expect(
          () => TomList.castFrom<TomInt, TomString>(source),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('TomMap', () {
      TomMap<String, TomInt> mapOf(Map<String, int> values) {
        final map = TomMap<String, TomInt>();
        values.forEach((k, v) => map[k] = TomInt(v));
        return map;
      }

      test('the cast holds the very same value instances', () {
        final source = mapOf({'a': 1, 'b': 2});

        final cast = TomMap.castFrom<String, TomInt, String, TomInt>(source);

        expect(cast.length, equals(2));
        expect(identical(cast['a'], source['a']), isTrue);
      });

      test('adding to the cast leaves the source the size it was', () {
        final source = mapOf({'a': 1});
        final cast = TomMap.castFrom<String, TomInt, String, TomInt>(source);

        cast['b'] = TomInt(2);

        expect(cast.length, equals(2));
        expect(source.length, equals(1));
      });

      test('adding to the source leaves the cast the size it was', () {
        final source = mapOf({'a': 1});
        final cast = TomMap.castFrom<String, TomInt, String, TomInt>(source);

        source['b'] = TomInt(2);

        expect(source.length, equals(2));
        expect(cast.length, equals(1));
      });

      test('a change inside a shared value notifies both', () {
        final source = mapOf({'a': 1});
        final cast = TomMap.castFrom<String, TomInt, String, TomInt>(source);
        final sourceObserver = TestObserver<TomMap<String, TomInt>>();
        final castObserver = TestObserver<TomMap<String, TomInt>>();
        source.addObserver(sourceObserver);
        cast.addObserver(castObserver);

        source['a']! | 99;

        expect(sourceObserver.notifyCount, equals(1));
        expect(castObserver.notifyCount, equals(1));
      });

      test('a value added to the cast is unknown to the source', () {
        final source = mapOf({'a': 1});
        final cast = TomMap.castFrom<String, TomInt, String, TomInt>(source);
        final sourceObserver = TestObserver<TomMap<String, TomInt>>();
        final castObserver = TestObserver<TomMap<String, TomInt>>();
        source.addObserver(sourceObserver);
        cast.addObserver(castObserver);

        final newcomer = TomInt(7);
        cast['b'] = newcomer;
        newcomer | 8;

        expect(castObserver.notifyCount, equals(2));
        expect(sourceObserver.notifyCount, equals(0));
      });

      test('the value type can be widened', () {
        final source = mapOf({'a': 1});

        final widened = TomMap.castFrom<String, TomInt, String, TomObject>(
          source,
        );

        expect(widened, isA<TomMap<String, TomObject>>());
        expect(identical(widened['a'], source['a']), isTrue);
      });

      test('a mismatched value type throws at the cast, not on a read', () {
        final source = mapOf({'a': 1});

        expect(
          () => TomMap.castFrom<String, TomInt, String, TomString>(source),
          throwsA(isA<TypeError>()),
        );
      });
    });
  });

  // No accessor may hand out a live, writable handle on a composite's backing
  // collection. Writing through such a handle bypasses the notification the
  // mutator would have sent, and on a TomClass it deregisters a member without
  // detaching its observer wiring — leaving a half-attached object that cannot
  // be repaired from outside.
  group('backing collections are not writable from outside', () {
    group('TomClass members', () {
      test('getMembers refuses a removal and keeps the member', () {
        final person = TestPerson();

        expect(
          () => person.getMembers().remove('name'),
          throwsUnsupportedError,
        );
        expect(person.getMembers().containsKey('name'), isTrue);
      });

      test('getMembers refuses an insertion', () {
        final person = TestPerson();

        expect(
          () => person.getMembers()['injected'] = TomString('x'),
          throwsUnsupportedError,
        );
        expect(person.getMembers().containsKey('injected'), isFalse);
      });

      test('getMembers refuses a clear', () {
        final person = TestPerson();

        expect(() => person.getMembers().clear(), throwsUnsupportedError);
        expect(person.getMembers(), isNotEmpty);
      });

      test('getMembers still reads every registered member', () {
        final person = TestPerson();

        final members = person.getMembers();

        expect(members.keys, containsAll(['name', 'age', 'email', 'isActive']));
        expect(identical(members['name'], person.name), isTrue);
      });

      test('getMembers is a live view, not a snapshot', () {
        // A nullable member is skipped while it is null and picked up by a
        // later `startSelfObservation()` — the lazy-member pattern, reachable
        // because that method is public. A cached *copy* would have been taken
        // at the first getMembers() call and would never show the new member,
        // silently and with no error, which is the failure mode this whole
        // group exists to remove.
        final subject = TestLateMember();
        final members = subject.getMembers();
        expect(members.containsKey('bonus'), isFalse);

        subject.bonus = TomInt(5);
        subject.startSelfObservation();

        expect(members.containsKey('bonus'), isTrue);
        expect(identical(members['bonus'], subject.bonus), isTrue);
      });

      test('a late-registered member notifies through the parent', () {
        // Liveness of the view is worth nothing if registration itself did not
        // take: the point of appearing in the map is being observed.
        final subject = TestLateMember();
        subject.bonus = TomInt(5);
        subject.startSelfObservation();

        var notifications = 0;
        final observer = TomFunctionObserver((_) => notifications++);
        subject.addObserver(observer);

        subject.bonus! | 6;

        expect(notifications, equals(1));
      });

      test('getOrNull does not hand out the member map', () {
        // getOrNull is the nullable-typed sibling of get(), and get() refuses
        // outright — a TomClass has no scalar value. Reading _value directly
        // let getOrNull walk past that guard and return the live registry.
        final person = TestPerson();

        expect(
          () => person.getOrNull(),
          throwsA(isA<TomObservableException>()),
        );
      });
    });

    group('TomList elements', () {
      TomList<TomInt> seeded(List<int> values) {
        final list = TomList<TomInt>();
        for (final v in values) {
          list.append(TomInt(v));
        }
        return list;
      }

      test(
        'getOrNull returns a copy, so adding to it does not reach the list',
        () {
          final list = seeded([1, 2, 3]);

          list.getOrNull()!.add(TomInt(4));

          expect(list.length, equals(3));
        },
      );

      test('getOrNull notifies nobody, because it changed nothing', () {
        final list = seeded([1, 2]);
        var notifications = 0;
        final observer = TomFunctionObserver((_) => notifications++);
        list.addObserver(observer);

        list.getOrNull()!.clear();

        expect(list.length, equals(2));
        expect(notifications, equals(0));
      });

      test('cast refuses a write and leaves the list intact', () {
        final list = seeded([1, 2, 3]);

        final view = list.cast<TomObject>();

        expect(() => view.removeAt(0), throwsUnsupportedError);
        expect(() => view.add(TomInt(4)), throwsUnsupportedError);
        expect(list.map((e) => e.get()).toList(), equals([1, 2, 3]));
      });

      test('cast still reads through to the elements', () {
        final list = seeded([1, 2, 3]);

        final view = list.cast<TomObject>();

        expect(view.length, equals(3));
        expect(identical(view[0], list[0]), isTrue);
      });
    });

    group('TomMap values', () {
      TomMap<String, TomInt> seeded(Map<String, int> values) {
        final map = TomMap<String, TomInt>();
        values.forEach((k, v) => map[k] = TomInt(v));
        return map;
      }

      test('getOrNull returns a copy, so removing from it spares the map', () {
        final map = seeded({'a': 1, 'b': 2});

        map.getOrNull()!.remove('a');

        expect(map.containsKey('a'), isTrue);
        expect(map.length, equals(2));
      });

      test('cast refuses a write and leaves the map intact', () {
        final map = seeded({'a': 1});

        final view = map.cast<Object, TomObject>();

        expect(() => view.remove('a'), throwsUnsupportedError);
        expect(() => view['b'] = TomInt(2), throwsUnsupportedError);
        expect(map.containsKey('a'), isTrue);
        expect(map.length, equals(1));
      });

      test('cast still reads through to the values', () {
        final map = seeded({'a': 1});

        final view = map.cast<Object, TomObject>();

        expect(view.length, equals(1));
        expect(identical(view['a'], map['a']), isTrue);
      });
    });

    group('scalar cells are unaffected', () {
      test('getOrNull still returns the value of a nullable cell', () {
        final nickname = TomNString(null);

        expect(nickname.getOrNull(), isNull);

        nickname | 'Ada';

        expect(nickname.getOrNull(), equals('Ada'));
      });

      test('getOrNull still returns the value of a non-nullable cell', () {
        final count = TomInt(7);

        expect(count.getOrNull(), equals(7));
      });
    });
  });

  group('"no value" sentinels denote one fixed instant', () {
    // These assertions are deliberately absolute rather than relative: a
    // sentinel that is only "the epoch as this machine sees it" is not a
    // sentinel at all, because two machines then disagree about which values
    // mean "no value". Comparing against DateTime.utc(1970) makes the test
    // itself TZ-independent, which is the property under test.
    final epoch = DateTime.utc(1970);

    void expectEpoch(String name, DateTime value) {
      expect(
        value.toUtc(),
        equals(epoch),
        reason:
            '$name must denote the Unix epoch regardless of the '
            "machine's timezone (TZ here is "
            '${DateTime.now().timeZoneName}, offset '
            '${DateTime.now().timeZoneOffset})',
      );
    }

    test('the plain zoned sentinels are at the epoch', () {
      expectEpoch('TomOZonedTime.noZonedTime', TomOZonedTime.noZonedTime);
      expectEpoch('TomOZonedDate.noZonedDate', TomOZonedDate.noZonedDate);
      expectEpoch(
        'TomOZonedDateTime.noZonedDateTime',
        TomOZonedDateTime.noZonedDateTime,
      );
      expectEpoch('TomNOZonedTime.noZonedTime', TomNOZonedTime.noZonedTime);
      expectEpoch('TomNOZonedDate.noZonedDate', TomNOZonedDate.noZonedDate);
      expectEpoch(
        'TomNOZonedDateTime.noZonedDateTime',
        TomNOZonedDateTime.noZonedDateTime,
      );
    });

    test('the observable sentinels are at the epoch', () {
      expectEpoch('TomDateTime.noDateTime', TomDateTime.noDateTime.get());
      expectEpoch('TomOTimezoned.noDateTime', TomOTimezoned.noDateTime.get()!);
      expectEpoch('TomOZonedTime.noTime', TomOZonedTime.noTime.get());
      expectEpoch('TomOZonedDate.noTime', TomOZonedDate.noTime.get());
      expectEpoch('TomOZonedDateTime.noTime', TomOZonedDateTime.noTime.get());
      expectEpoch('TomNDateTime.noDateTime', TomNDateTime.noDateTime.get());
      expectEpoch(
        'TomNOTimezoned.noDateTime',
        TomNOTimezoned.noDateTime.get()!,
      );
      expectEpoch('TomNOZonedTime.noTime', TomNOZonedTime.noTime.get()!);
      expectEpoch('TomNOZonedDate.noTime', TomNOZonedDate.noTime.get()!);
      expectEpoch(
        'TomNOZonedDateTime.noTime',
        TomNOZonedDateTime.noTime.get()!,
      );
    });

    test('the two families of sentinels are interchangeable', () {
      // The plain and observable sentinels are paired: user code reaches for
      // whichever fits its type, and a comparison must not care which one the
      // value was seeded from.
      expect(
        TomOZonedTime.noZonedTime.toUtc(),
        equals(TomOZonedTime.noTime.get().toUtc()),
      );
      expect(
        TomOZonedDate.noZonedDate.toUtc(),
        equals(TomOZonedDate.noTime.get().toUtc()),
      );
      expect(
        TomOZonedDateTime.noZonedDateTime.toUtc(),
        equals(TomOZonedDateTime.noTime.get().toUtc()),
      );
      expect(
        TomNOZonedTime.noZonedTime.toUtc(),
        equals(TomNOZonedTime.noTime.get()!.toUtc()),
      );
      expect(
        TomNOZonedDate.noZonedDate.toUtc(),
        equals(TomNOZonedDate.noTime.get()!.toUtc()),
      );
      expect(
        TomNOZonedDateTime.noZonedDateTime.toUtc(),
        equals(TomNOZonedDateTime.noTime.get()!.toUtc()),
      );
    });

    test('the range classes default to the epoch on both ends', () {
      // The three range classes seed both ends from the plain zoned family,
      // so they inherit whatever those sentinels denote.
      final dates = TomDateRange();
      expectEpoch('TomDateRange().startDate', dates.startDate.get()!);
      expectEpoch('TomDateRange().endDate', dates.endDate.get()!);

      final times = TomTimeRange();
      expectEpoch('TomTimeRange().startTime', times.startTime.get()!);
      expectEpoch('TomTimeRange().endTime', times.endTime.get()!);

      final dateTimes = TomDateTimeRange();
      expectEpoch(
        'TomDateTimeRange().startDateTime',
        dateTimes.startDateTime.get()!,
      );
      expectEpoch(
        'TomDateTimeRange().endDateTime',
        dateTimes.endDateTime.get()!,
      );
    });

    test('a sentinel serializes to the epoch on the wire', () {
      // A sentinel that changes meaning when it is written by one machine and
      // read by another is worse than no sentinel: the reader silently sees a
      // real date rather than "no value". The wire form is UTC-stamped, so it
      // is enough to pin the instant it carries.
      final written = TomDateRange();

      final wire = written.getValues()['startDate'] as String;

      expect(wire, startsWith(TomZonedDate.serializationPrefix));
      expectEpoch(
        'serialized TomDateRange().startDate',
        DateTime.parse(
          wire.substring(TomZonedDate.serializationPrefix.length).split('_')[0],
        ),
      );
    });

    test('a sentinel survives a round trip through a TomClass', () {
      final written = TomDateRange();
      final read = TomDateRange();

      read.setValues(written.getValues());

      expectEpoch('round-tripped startDate', read.startDate.get()!);
      expectEpoch('round-tripped endDate', read.endDate.get()!);
    });
  });

  group('operator <<', () {
    // `<<` is the "set and hand the object back" operator, so the property
    // that makes it worth having — over `|`, which hands back the value — is
    // that the result is *the same instance*, not an equal one. Every
    // assertion below on the return value therefore uses `same`, not `equals`:
    // an implementation that returned a copy would satisfy `equals` while
    // breaking every chained call.

    group('on a scalar TomObject', () {
      test('sets the value and returns the same instance', () {
        final name = TomString("John");

        final returned = name << "Jane";

        expect(~name, equals("Jane"));
        expect(returned, same(name));
      });

      test('chains, applying each write in order', () {
        final count = TomInt(0);

        count << 1 << 2 << 3;

        expect(~count, equals(3));
      });

      test('notifies once per changed write', () {
        final count = TomInt(0);
        int notifications = 0;
        final observer = count >> (obs) => notifications++;

        count << 1 << 2 << 3;

        expect(notifications, equals(3));
        count.removeObserver(observer);
      });

      test('stays silent when the value does not change, like set()', () {
        // `<<` delegates to `set`, so it inherits the notify-only-on-change
        // rule rather than firing per call.
        final name = TomString("same");
        int notifications = 0;
        final observer = name >> (obs) => notifications++;

        name << "same" << "same";

        expect(notifications, isZero);
        name.removeObserver(observer);
      });

      test(
        'is available on a nullable cell, including a write back to null',
        () {
          final nickname = TomNString(null);

          expect(nickname << "Johnny", same(nickname));
          expect(~nickname, equals("Johnny"));

          nickname << null;
          expect(nickname.isNull, isTrue);
        },
      );
    });

    group('on a TomList', () {
      // TomList overrides `<<` to mean wholesale replacement. This matters:
      // `set` throws on a list, so `<<` is the operator form of "swap all the
      // contents", and it is the only one.
      test('replaces the whole list and returns the same instance', () {
        final rows = TomList<TomString>();
        rows.append(TomString('a')).append(TomString('b'));

        final returned = rows << [TomString('x'), TomString('y')];

        expect(returned, same(rows));
        expect(rows.map((e) => ~e), equals(['x', 'y']));
      });

      test('replaces in one notification, not one per element', () {
        final rows = TomList<TomString>();
        rows.append(TomString('a')).append(TomString('b'));
        int notifications = 0;
        final observer = rows >> (obs) => notifications++;

        rows << [TomString('x'), TomString('y'), TomString('z')];

        expect(notifications, equals(1));
        rows.removeObserver(observer);
      });

      test(
        'detaches the outgoing elements, so they no longer notify the list',
        () {
          final outgoing = TomString('a');
          final rows = TomList<TomString>()..append(outgoing);

          rows << [TomString('x')];

          int notifications = 0;
          final observer = rows >> (obs) => notifications++;
          outgoing | 'changed';

          expect(
            notifications,
            isZero,
            reason:
                'an element that has left the list must not keep '
                'notifying it',
          );
          rows.removeObserver(observer);
        },
      );

      test('attaches the incoming elements, so they do notify the list', () {
        final incoming = TomString('x');
        final rows = TomList<TomString>()..append(TomString('a'));

        rows << [incoming];

        int notifications = 0;
        final observer = rows >> (obs) => notifications++;
        incoming | 'changed';

        expect(notifications, equals(1));
        rows.removeObserver(observer);
      });

      test('stays silent when the identical sequence is written back', () {
        // The change test is by identity, not equality — see
        // `_notifyIfChangedSince`.
        final a = TomString('a');
        final b = TomString('b');
        final rows = TomList<TomString>()
          ..append(a)
          ..append(b);
        int notifications = 0;
        final observer = rows >> (obs) => notifications++;

        rows << [a, b];

        expect(notifications, isZero);
        rows.removeObserver(observer);
      });

      test('notifies for an equal-but-distinct sequence', () {
        // Observers hold element references, so swapping in an equal element
        // is a real change even though `==` cannot see it.
        final rows = TomList<TomString>()..append(TomString('a'));
        int notifications = 0;
        final observer = rows >> (obs) => notifications++;

        rows << [TomString('a')];

        expect(notifications, equals(1));
        rows.removeObserver(observer);
      });
    });

    group('on a TomMap', () {
      test('replaces the whole map and returns the same instance', () {
        final scores = TomMap<String, TomInt>();
        scores['a'] = TomInt(1);

        final returned = scores << {'x': TomInt(9)};

        expect(returned, same(scores));
        expect(scores.keys, equals(['x']));
        expect(~scores['x']!, equals(9));
      });

      test('replaces in one notification', () {
        final scores = TomMap<String, TomInt>();
        scores['a'] = TomInt(1);
        int notifications = 0;
        final observer = scores >> (obs) => notifications++;

        scores << {'x': TomInt(9), 'y': TomInt(8)};

        expect(notifications, equals(1));
        scores.removeObserver(observer);
      });

      test('attaches the incoming values, so they notify the map', () {
        final incoming = TomInt(9);
        final scores = TomMap<String, TomInt>();

        scores << {'x': incoming};

        int notifications = 0;
        final observer = scores >> (obs) => notifications++;
        incoming | 10;

        expect(notifications, equals(1));
        scores.removeObserver(observer);
      });
    });

    group('on a TomClass', () {
      test('throws, because a class has no single value to replace', () {
        // The asymmetry with TomList/TomMap is deliberate: their contents are
        // replaceable, a class's set of members is not. Use `setValues` to
        // write many members at once.
        final person = TestPerson();

        expect(
          () => person << {'name': 'Jane'},
          throwsA(isA<TomObservableException>()),
        );
      });

      test('leaves the members untouched when it throws', () {
        final person = TestPerson();
        person.name | 'John';

        expect(
          () => person << {'name': 'Jane'},
          throwsA(isA<TomObservableException>()),
        );
        expect(~person.name, equals('John'));
      });
    });
  });

  // The key is the half of an exception that callers match on; the message is
  // prose and may be reworded, the key may not. Elsewhere in this suite the
  // assertions are `isA<TomObservableException>()` alone, which cannot tell a
  // renamed key from a correct one — so each raise site is pinned here once,
  // by exact key.
  //
  // The grammar is `observable.<type>_<operation>.<condition>`: module first,
  // as `TomException` documents, then the type that raised it. Grouping the
  // expectations by raising type is the point of the group — a key filed under
  // the wrong type reads as obviously wrong here, which is the failure these
  // tests exist to catch.
  group('exception keys', () {
    void expectKey(String key, void Function() trigger) {
      expect(
        trigger,
        throwsA(
          isA<TomObservableException>().having(
            (e) => e.key,
            'key',
            equals(key),
          ),
        ),
      );
    }

    group('raised by TomClass', () {
      test('set, get and << on the class itself', () {
        expectKey(
          'observable.class_state.set_not_allowed',
          () => TestPerson().set({}),
        );
        expectKey(
          'observable.class_state.get_not_allowed',
          () => TestPerson().get(),
        );
        expectKey(
          'observable.class_state.set_not_allowed',
          () => TestPerson() << {'name': 'Jane'},
        );
      });

      test('a member rejecting the value setValues offered it', () {
        expectKey(
          'observable.class_set_values.member_assignment_failed',
          () => TestPerson().setValues({'age': 'not a number'}),
        );
      });

      test('a member throwing while getValues reads it', () {
        expectKey(
          'observable.class_get_values.member_serialization_failed',
          () => TestThrowingMember().getValues(),
        );
      });

      test('a list member given a non-list', () {
        expectKey(
          'observable.class_set_list_member.not_a_list',
          () => TestTaggedItem().setValues({'tags': 'not a list'}),
        );
      });

      test('a TomClass list element given a non-map', () {
        expectKey(
          'observable.class_set_list_member.not_a_map',
          () => TestTaggedItem().setValues({
            'subtasks': ['not a map'],
          }),
        );
      });

      test('a list element deserializing to the wrong type', () {
        expectKey(
          'observable.class_set_list_member.invalid_element_type',
          () => TestTaggedItem().setValues({
            'tags': [1],
          }),
        );
      });

      test('a map member given a non-map', () {
        expectKey(
          'observable.class_set_map_member.not_a_map',
          () => TestPricedItem().setValues({'surcharges': 'not a map'}),
        );
      });
    });

    group('raised by TomList', () {
      test('set on the list itself', () {
        expectKey(
          'observable.list_state.set_not_allowed',
          () => TomList<TomString>().set([]),
        );
      });

      test('growing the list by assigning length', () {
        expectKey(
          'observable.list_state.length_cannot_grow',
          () => TomList<TomString>().length = 2,
        );
      });
    });

    group('raised by TomMap', () {
      test('set on the map itself', () {
        expectKey(
          'observable.map_state.set_not_allowed',
          () => TomMap<String, TomInt>().set({}),
        );
      });

      test('update on an absent key with no ifAbsent', () {
        expectKey(
          'observable.map_state.update_key_not_found_no_ifabsent',
          () =>
              TomMap<String, TomInt>().update('missing', (value) => TomInt(1)),
        );
      });
    });
  });

  // ==========================================================================
  // The tomNull sentinel
  // ==========================================================================

  group('the tomNull sentinel is not writable', () {
    test('| throws and leaves the sentinel intact', () {
      expect(
        () => tomNull | 'clobbered',
        throwsA(
          isA<TomObservableException>().having(
            (e) => e.key,
            'key',
            equals('observable.null_sentinel.set_not_allowed'),
          ),
        ),
      );

      // The refusal must also leave the sentinel untouched. It is process-wide,
      // so a write that got through would be seen as 'clobbered' by *every*
      // later reader — in unrelated objects, anywhere in the process.
      expect(~tomNull, equals('tomNull'));
    });

    test('set and << are refused too, not just the | operator', () {
      expect(
        () => tomNull.set('clobbered'),
        throwsA(isA<TomObservableException>()),
      );
      expect(
        () => tomNull << 'clobbered',
        throwsA(isA<TomObservableException>()),
      );
      expect(~tomNull, equals('tomNull'));
    });

    test(
      'a rejected write is invisible to a reader holding the same instance',
      () {
        // `tomNull` is one process-wide instance handed to every caller, so two
        // holders are necessarily aliases. That aliasing is the hazard the
        // immutability removes: a successful write through one holder was
        // formerly observed through every other, anywhere in the program.
        final holderA = tomNull;
        final holderB = tomNull;
        expect(identical(holderA, holderB), isTrue);

        expect(
          () => holderA.set('clobbered'),
          throwsA(isA<TomObservableException>()),
        );

        expect(
          ~holderB,
          equals('tomNull'),
          reason: 'a write refused through one alias must not reach another',
        );
        expect(~tomNull, equals('tomNull'));
      },
    );

    test('the sentinel keeps its identity, so `identical` tests still work', () {
      // The fix had two candidate shapes; the todo left the choice to whichever
      // the sentinel's identity comparisons allow. A getter returning a fresh
      // instance per call would have broken this, which is why the immutable
      // single instance was chosen instead.
      expect(identical(tomNull, tomNull), isTrue);
    });

    test('reading the sentinel still works', () {
      // Immutability must not cost the sentinel its readability: callers test
      // for it by identity and print it in diagnostics.
      expect(tomNull.get(), equals('tomNull'));
      expect(tomNull(), equals('tomNull'));
      expect(tomNull.isNull, isFalse);
      expect(tomNull.toString(), equals('~tomNull'));
    });
  });
}

// ============================================================================
// Lifecycle listener test helpers
// ============================================================================

/// Records the order and observed list sizes of lifecycle callbacks.
class _RecordingLifecycleListener extends TomListLifecycleListener {
  final List<String> callOrder = [];
  int? beforeClearLength;
  int? afterResetLength;

  @override
  void onBeforeClear(TomList list) {
    callOrder.add('before');
    beforeClearLength = list.length;
  }

  @override
  void onAfterReset(TomList list) {
    callOrder.add('after');
    afterResetLength = list.length;
  }
}

/// Unregisters itself during [onBeforeClear] to exercise the listener snapshot.
class _SelfRemovingLifecycleListener extends TomListLifecycleListener {
  _SelfRemovingLifecycleListener(this._onBefore);

  final void Function() _onBefore;
  int beforeCalls = 0;

  @override
  void onBeforeClear(TomList list) {
    beforeCalls++;
    _onBefore();
  }
}
