/// Example: TomObject Basics
///
/// This example demonstrates the fundamental features of TomObject:
/// - Creating observable wrappers for primitive values
/// - Getting and setting values using operators
/// - Observer notifications
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== TomObject Basics Example ===\n');

  // --- Creating TomObjects ---
  print('1. Creating TomObjects');
  final name = TomString("John");
  final age = TomInt(25);
  final balance = TomDouble(100.50);
  final isActive = TomBool(true);
  final createdAt = TomDateTime(DateTime(2024, 1, 15));

  // --- Getting values with ~ operator ---
  print('\n2. Getting values with ~ operator');
  assert(~name == "John", "TomString value should be 'John'");
  assert(~age == 25, "TomInt value should be 25");
  assert(~balance == 100.50, "TomDouble value should be 100.50");
  assert(~isActive == true, "TomBool value should be true");
  print('   name: ${~name}');
  print('   age: ${~age}');
  print('   balance: ${~balance}');
  print('   isActive: ${~isActive}');
  print('   createdAt: ${~createdAt}');

  // --- Getting values with call operator ---
  print('\n3. Getting values with call operator ()');
  assert(name() == "John", "Call operator should return 'John'");
  assert(age() == 25, "Call operator should return 25");
  print('   name(): ${name()}');
  print('   age(): ${age()}');

  // --- Setting values with | operator ---
  print('\n4. Setting values with | operator');
  name | "Jane";
  age | 30;
  balance | 250.75;
  isActive | false;

  assert(~name == "Jane", "TomString value should be 'Jane' after set");
  assert(~age == 30, "TomInt value should be 30 after set");
  assert(~balance == 250.75, "TomDouble value should be 250.75 after set");
  assert(~isActive == false, "TomBool value should be false after set");

  print('   name: ${~name}');
  print('   age: ${~age}');
  print('   balance: ${~balance}');
  print('   isActive: ${~isActive}');

  // --- Using get() and set() methods ---
  print('\n5. Using get() and set() methods');
  name.set("Bob");
  assert(name.get() == "Bob", "get() should return 'Bob'");
  print('   name.get(): ${name.get()}');

  // --- Nullable wrappers ---
  print('\n6. Nullable wrappers');
  final nickname = TomNString(null);
  final score = TomNInt(null);

  assert(nickname.isNull == true, "Nullable should be null initially");
  assert(nickname.getOrNull() == null, "getOrNull() should return null");
  print('   nickname.isNull: ${nickname.isNull}');
  print('   nickname.getOrNull(): ${nickname.getOrNull()}');

  nickname | "Johnny";
  assert(nickname.isNull == false, "Nullable should not be null after set");
  assert(~nickname == "Johnny", "Nullable value should be 'Johnny'");
  print('   After setting: ${~nickname}');

  score | 100;
  assert(~score == 100, "Nullable int should be 100");
  print('   score: ${~score}');

  print('\n=== All assertions passed! ===');
}
