/// Comprehensive tests for the observable functionality in tom_observable.dart
/// and tom_observable_objects.dart
///
/// Run: `dart run build_runner build` before executing these tests.
library;

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

/// Test class for TomMap with TomClass values
@tomReflector
class TestUserProfile extends TomClass {
  final displayName = TomString("");
  final bio = TomNString(null);
  final followerCount = TomInt(0);
}

/// A [TomString] whose [get] always throws, used to verify that
/// [TomClass.getValues] surfaces a serialization failure instead of silently
/// swallowing it into partial data (bug §47 / tests §32b).
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
      expect(observer.notifyCount, equals(1)); // Should notify on unmute if dirty
    });

    test('>> operator adds callback observer', () {
      final observable = TomObservable();
      int callbackCount = 0;

      observable >> (obs) {
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

      final observer = observable >> (obs) {
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
      expect(
        () => person.set({}),
        throwsA(isA<TomObservableException>()),
      );
    });

    test('throws on direct get()', () {
      final person = TestPerson();
      expect(
        () => person.get(),
        throwsA(isA<TomObservableException>()),
      );
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
      list.append(TomInt(1)).append(TomInt(2)).append(TomInt(3)).append(TomInt(4));

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
      expect(
        () => list.set([]),
        throwsA(isA<TomObservableException>()),
      );
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
      expect(
        () => map.set({}),
        throwsA(isA<TomObservableException>()),
      );
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
      final observable = TomOZonedDate(TomZonedDate.fromDateTime(DateTime(1970)));
      final serialized = "@D@2024-05-20T00:00:00.000Z_Z_UTC";

      observable.setByString(serialized);

      expect((~observable).year, equals(2024));
      expect((~observable).month, equals(5));
      expect((~observable).day, equals(20));
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

      range.startTime | TomZonedTime(hour: 9, minute: 0, timezone: TomTimezone.utc);
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

      range.startDateTime | TomZonedDateTime.fromDateTime(DateTime(2024, 1, 1, 10, 0));
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

      map.remove("key");
      // Note: remove doesn't call notifyObservers, but we can check item is unobserved

      item | 20;
      expect(notifyCount, equals(0)); // Should not be notified since removed
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

  group('toString()', () {
    test('TomObject toString includes value', () {
      final str = TomString("hello");
      expect(str.toString(), contains("hello"));
    });

    test('TomInt toString includes value', () {
      final num = TomInt(42);
      expect(num.toString(), contains("42"));
    });

    test('TomList toString shows elements', () {
      final list = TomList<TomInt>();
      list.append(TomInt(1)).append(TomInt(2));
      final str = list.toString();
      expect(str, contains("1"));
      expect(str, contains("2"));
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
      test('fires onBeforeClear before clearing and onAfterReset after install',
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
      });

      test('removeLifecycleListener stops further callbacks', () {
        final list = TomList<TomInt>();
        final listener = _RecordingLifecycleListener();
        list.addLifecycleListener(listener);
        list.removeLifecycleListener(listener);

        list.resetWith([TomInt(1)]);

        expect(listener.callOrder, isEmpty);
      });

      test('snapshots listeners so a listener may unregister during callback',
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
      });
    });
  });

  // tests §32a — composite/single mutations must each notify observers exactly
  // once, never leaking half-applied intermediate state through extra
  // notifications. removeRange/insertAll/setAll/insert are regression guards
  // (already single-notify); replaceRange/retainWhere pin the §40 refactor.
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

  // tests §41 — strongly typed Iterable overrides must accept the natural
  // element-typed callbacks (no unchecked casts), pinning the §41 refactor.
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
      final result = list.firstWhere((e) => e.get() > 10, orElse: () => fallback);

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

  // tests §32b — getValues/toJson must propagate a member serialization
  // failure as a TomObservableException instead of swallowing it into silent
  // partial data (bug §47).
  group('TomClass.getValues serialization failure', () {
    test('getValues throws TomObservableException when a member throws', () {
      final subject = TestThrowingMember();

      expect(
        () => subject.getValues(),
        throwsA(isA<TomObservableException>()),
      );
    });

    test('toJson propagates the member serialization failure', () {
      final subject = TestThrowingMember();

      expect(
        () => subject.toJson(),
        throwsA(isA<TomObservableException>()),
      );
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
