// ignore_for_file: unnecessary_type_check
/// TomObject Basics Example
///
/// This example demonstrates the fundamental features of TomObject:
/// - Creating observable wrappers for primitive values
/// - Getting and setting values using operators
/// - Observer notifications
/// - Nullable wrappers
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
  // Example 5: Using get() and set() methods
  // -------------------------------------------------------------------------
  static void example5GetSetMethods() {
    print('\n5. Using get() and set() methods:');

    name.set('Bob');
    print('   name.get(): ${name.get()}');

    // Assertions
    assert(name.get() == 'Bob', "get() should return 'Bob'");
  }

  // -------------------------------------------------------------------------
  // Example 6: Nullable wrappers
  // -------------------------------------------------------------------------
  static void example6NullableWrappers() {
    print('\n6. Nullable wrappers:');

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
  // Example 7: Observer on single value
  // -------------------------------------------------------------------------
  static void example7SingleValueObserver() {
    print('\n7. Observer on single value:');

    final counter = TomInt(0);
    int notifyCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final counterObserver = counter >> (obs) {
      notifyCount++;
      print('   [Observer] Counter changed to ${~(obs as TomInt)}');
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
    example5GetSetMethods();
    example6NullableWrappers();
    example7SingleValueObserver();

    print('\n=== TomObject Basics Example Complete ===\n');
  }
}

void run() => TomObjectBasicsExample.run();

void main() => run();
