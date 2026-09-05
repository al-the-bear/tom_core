// ignore_for_file: unnecessary_type_check
/// TomObject Basics Example
///
/// This example demonstrates the fundamental features of TomObject:
/// - Creating observable wrappers for primitive values
/// - Getting and setting values using operators
/// - Chaining writes with the &lt;&lt; operator
/// - Observer notifications
/// - Nullable wrappers
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class TomObjectBasicsExample {
  // Captured results
  static late TomString name;
  static late TomInt age;
  static late TomDouble balance;
  static late TomBool isActive;
  static late TomDateTime createdAt;
  static late TomNString nickname;
  static late TomNInt score;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomObjects
  // -------------------------------------------------------------------------
  static void example1CreatingTomObjects() {
    print('1. Creating TomObjects:');

    name = TomString('John');
    age = TomInt(25);
    balance = TomDouble(100.50);
    isActive = TomBool(true);
    createdAt = TomDateTime(DateTime(2024, 1, 15));

    print('   Created 5 TomObject instances');
    print('   Types: TomString, TomInt, TomDouble, TomBool, TomDateTime');

    // Assertions
    assert(name is TomString, 'Should be TomString');
    assert(age is TomInt, 'Should be TomInt');
    assert(balance is TomDouble, 'Should be TomDouble');
  }

  // -------------------------------------------------------------------------
  // Example 2: Getting values with ~ operator
  // -------------------------------------------------------------------------
  static void example2GetWithTildeOperator() {
    print('\n2. Getting values with ~ operator:');

    print('   ~name: ${~name}');
    print('   ~age: ${~age}');
    print('   ~balance: ${~balance}');
    print('   ~isActive: ${~isActive}');
    print('   ~createdAt: ${~createdAt}');

    // Assertions
    assert(~name == 'John', "TomString value should be 'John'");
    assert(~age == 25, 'TomInt value should be 25');
    assert(~balance == 100.50, 'TomDouble value should be 100.50');
    assert(~isActive == true, 'TomBool value should be true');
  }

  // -------------------------------------------------------------------------
  // Example 3: Getting values with call operator
  // -------------------------------------------------------------------------
  static void example3GetWithCallOperator() {
    print('\n3. Getting values with call operator ():');

    print('   name(): ${name()}');
    print('   age(): ${age()}');

    // Assertions
    assert(name() == 'John', "Call operator should return 'John'");
    assert(age() == 25, 'Call operator should return 25');
  }

  // -------------------------------------------------------------------------
  // Example 4: Setting values with | operator
  // -------------------------------------------------------------------------
  static void example4SetWithPipeOperator() {
    print('\n4. Setting values with | operator:');

    name | 'Jane';
    age | 30;
    balance | 250.75;
    isActive | false;

    print('   name: ${~name}');
    print('   age: ${~age}');
    print('   balance: ${~balance}');
    print('   isActive: ${~isActive}');

    // Assertions
    assert(~name == 'Jane', "TomString value should be 'Jane' after set");
    assert(~age == 30, 'TomInt value should be 30 after set');
    assert(~balance == 250.75, 'TomDouble value should be 250.75 after set');
    assert(~isActive == false, 'TomBool value should be false after set');
  }

  // -------------------------------------------------------------------------
  // Example 5: Chaining writes with the << operator
  // -------------------------------------------------------------------------
  static void example5ChainWithShiftOperator() {
    print('\n5. Chaining writes with the << operator:');

    // `<<` writes exactly like `|` — both go through set(), so both notify
    // only when the value actually changes. They differ solely in what they
    // hand back: `|` yields the value, `<<` yields the observable itself, and
    // that is what lets writes chain.
    final count = TomInt(0);
    count << 1 << 2 << 3;
    print('   count after "count << 1 << 2 << 3": ${~count}');

    // Because the receiver comes back, the result is usable directly.
    final returned = name << 'Alice';
    print('   name: ${~name}');
    print('   returned is the same object: ${identical(returned, name)}');

    // A chain's static type is TomObject<T>, not the subtype it started from,
    // so chain for the writes rather than to keep hold of a TomString.

    age << 41;
    balance << 99.5;
    isActive << true;
    print('   age: ${~age}, balance: ${~balance}, isActive: ${~isActive}');

    // Assertions
    assert(~count == 3, 'Chained writes should leave the last value, 3');
    assert(identical(returned, name), '<< should return the observable itself');
    assert(~name == 'Alice', "name should be 'Alice' after <<");
    assert(~age == 41, '<< should set TomInt like |');
    assert(~balance == 99.5, '<< should set TomDouble like |');
    assert(~isActive == true, '<< should set TomBool like |');
  }

  // -------------------------------------------------------------------------
  // Example 6: Using get() and set() methods
  // -------------------------------------------------------------------------
  static void example6GetSetMethods() {
    print('\n6. Using get() and set() methods:');

    name.set('Bob');
    print('   name.get(): ${name.get()}');

    // Assertions
    assert(name.get() == 'Bob', "get() should return 'Bob'");
  }

  // -------------------------------------------------------------------------
  // Example 7: Nullable wrappers
  // -------------------------------------------------------------------------
  static void example7NullableWrappers() {
    print('\n7. Nullable wrappers:');

    nickname = TomNString(null);
    score = TomNInt(null);

    print('   nickname.isNull: ${nickname.isNull}');
    print('   nickname.getOrNull(): ${nickname.getOrNull()}');

    nickname | 'Johnny';
    score | 100;

    print('   After setting nickname: ${~nickname}');
    print('   score: ${~score}');

    // Assertions
    assert(nickname.isNull == false, 'Nullable should not be null after set');
    assert(~nickname == 'Johnny', "Nullable value should be 'Johnny'");
    assert(~score == 100, 'Nullable int should be 100');
  }

  // -------------------------------------------------------------------------
  // Example 8: Observer on single value
  // -------------------------------------------------------------------------
  static void example8SingleValueObserver() {
    print('\n8. Observer on single value:');

    final counter = TomInt(0);
    int notifyCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final counterObserver =
        counter >>
        (obs) {
          notifyCount++;
          // `obs` is a TomInt, not a bare TomObservable: `>>` is an extension on
          // the receiver's type, so the callback parameter follows `counter`.
          print('   [Observer] Counter changed to ${~obs}');
        };

    counter | 1;
    counter | 2;
    counter | 3;

    print('   Total notifications: $notifyCount');

    // Assertions
    assert(notifyCount == 3, 'Should have 3 notifications');
    assert(~counter == 3, 'Counter should be 3');

    counter.removeObserver(counterObserver);
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: TomObject Basics Example ===\n');

    example1CreatingTomObjects();
    example2GetWithTildeOperator();
    example3GetWithCallOperator();
    example4SetWithPipeOperator();
    example5ChainWithShiftOperator();
    example6GetSetMethods();
    example7NullableWrappers();
    example8SingleValueObserver();

    print('\n=== TomObject Basics Example Complete ===\n');
  }
}

void run() => TomObjectBasicsExample.run();

void main() {
  prepareSampleProcess();
  run();
}
