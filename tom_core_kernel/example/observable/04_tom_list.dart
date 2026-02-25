// ignore_for_file: unnecessary_cast
/// Example: TomList - Observable Lists
///
/// This example demonstrates TomList:
/// - Creating and manipulating observable lists
/// - Automatic observation of list elements
/// - List operators and methods
/// - Notifications on list and element changes
///
/// NOTE: Run `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A simple Task class for list examples.
@tomReflector
class Task extends TomClass {
  final title = TomString("");
  final completed = TomBool(false);
  final priority = TomInt(0);
}

void run() {
  print('=== TomList Example ===\n');

  // --- Creating TomLists ---
  print('1. Creating TomLists');
  final numbers = TomList<TomInt>();

  // Add elements using add() method
  numbers.add(TomInt(10));
  numbers.add(TomInt(20));
  numbers.add(TomInt(30));

  assert(numbers.length == 3, "List should have 3 elements");
  assert(~numbers[0] == 10, "First element should be 10");
  assert(~numbers[1] == 20, "Second element should be 20");
  assert(~numbers[2] == 30, "Third element should be 30");

  print('   numbers: [${numbers.map((e) => ~e).join(", ")}]');
  print('   length: ${numbers.length}');

  // --- Using append() to add elements ---
  print('\n2. Using append() to add elements');
  final names = TomList<TomString>();

  // append() returns the list for chaining
  names.append(TomString("Alice")).append(TomString("Bob")).append(TomString("Charlie"));

  assert(names.length == 3, "List should have 3 elements");
  assert(~names[0] == "Alice", "First should be 'Alice'");
  print('   names: [${names.map((e) => ~e).join(", ")}]');

  // --- Observing list changes ---
  print('\n3. Observing list changes');
  final items = TomList<TomString>();
  int listNotifyCount = 0;

  items >> (obs) {
    listNotifyCount++;
    print('   List notification #$listNotifyCount');
  };

  items.add(TomString("item1"));
  assert(listNotifyCount == 1, "Should notify on add");

  items.add(TomString("item2"));
  assert(listNotifyCount == 2, "Should notify on second add");

  // Modifying an element also notifies the list
  items[0] | "modified item1";
  assert(listNotifyCount == 3, "Should notify when element changes");
  print('   Total notifications: $listNotifyCount');

  // --- List operations ---
  print('\n4. List operations');
  final scores = TomList<TomInt>();
  scores.append(TomInt(100)).append(TomInt(85)).append(TomInt(92)).append(TomInt(78));

  // Access by index
  assert(~scores[0] == 100, "scores[0] should be 100");
  assert(~scores[2] == 92, "scores[2] should be 92");
  print('   scores[0]: ${~scores[0]}');

  // first and last
  assert(~scores.first == 100, "first should be 100");
  assert(~scores.last == 78, "last should be 78");
  print('   first: ${~scores.first}, last: ${~scores.last}');

  // isEmpty/isNotEmpty
  assert(scores.isNotEmpty, "List should not be empty");
  assert(scores.isNotEmpty, "List should not be empty");

  // contains-like operations using any
  final hasHigh = scores.any((e) => ~e >= 90);
  assert(hasHigh, "Should have score >= 90");
  print('   Has score >= 90: $hasHigh');

  // --- Modifying elements by index ---
  print('\n5. Modifying elements by index');
  final values = TomList<TomDouble>();
  values.append(TomDouble(1.0)).append(TomDouble(2.0)).append(TomDouble(3.0));
  int modifyCount = 0;

  values >> (obs) => modifyCount++;

  // Replace element at index
  values[1] = TomDouble(2.5);
  assert(~values[1] == 2.5, "values[1] should be 2.5");
  assert(modifyCount == 1, "Should notify on index assignment");

  // Modify element's value
  values[0] | 1.5;
  assert(~values[0] == 1.5, "values[0] should be 1.5");
  assert(modifyCount == 2, "Should notify on element value change");
  print('   values: [${values.map((e) => ~(e as TomDouble)).join(", ")}]');

  // --- Removing elements ---
  print('\n6. Removing elements');
  final fruits = TomList<TomString>();
  fruits.append(TomString("apple")).append(TomString("banana")).append(TomString("cherry"));

  assert(fruits.length == 3, "Should have 3 fruits");

  fruits.removeAt(1); // Remove "banana"
  assert(fruits.length == 2, "Should have 2 fruits after remove");
  assert(~fruits[0] == "apple", "First should still be 'apple'");
  assert(~fruits[1] == "cherry", "Second should now be 'cherry'");
  print('   After removeAt(1): [${fruits.map((e) => ~(e as TomString)).join(", ")}]');

  fruits.removeLast();
  assert(fruits.length == 1, "Should have 1 fruit after removeLast");
  print('   After removeLast: [${fruits.map((e) => ~(e as TomString)).join(", ")}]');

  // --- Concatenating lists ---
  print('\n7. Concatenating lists with + operator');
  final list1 = TomList<TomInt>();
  list1.append(TomInt(1)).append(TomInt(2));

  final list2 = TomList<TomInt>();
  list2.append(TomInt(3)).append(TomInt(4));

  final combined = list1 + list2;
  assert(combined.length == 4, "Combined list should have 4 elements");
  assert(~combined[2] == 3, "Third element should be 3");
  print('   list1 + list2: [${combined.map((e) => ~(e as TomInt)).join(", ")}]');

  // Original lists unchanged
  assert(list1.length == 2, "list1 should be unchanged");
  assert(list2.length == 2, "list2 should be unchanged");

  // --- Iterating over TomList ---
  print('\n8. Iterating over TomList');
  final tasks = TomList<Task>();
  final task1 = Task()..title.set("Buy groceries")..priority.set(1);
  final task2 = Task()..title.set("Walk the dog")..priority.set(2);
  final task3 = Task()..title.set("Finish report")..priority.set(3);

  tasks.append(task1).append(task2).append(task3);

  print('   Tasks:');
  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    print('   - ${~task.title} (priority: ${~task.priority})');
  }

  // Using for-in
  final titleList = <String>[];
  for (var task in tasks) {
    titleList.add((task as Task).title.get());
  }
  assert(titleList.length == 3, "Should iterate over all tasks");
  print('   Titles: $titleList');

  // --- Observing element changes in list of TomClass ---
  print('\n9. Observing element changes in list of TomClass');
  final taskList = TomList<Task>();
  final newTask = Task();
  newTask.title | "New Task";
  taskList.add(newTask);

  int taskListNotify = 0;
  taskList >> (obs) {
    taskListNotify++;
    print('   TaskList notification #$taskListNotify');
  };

  // Modifying task member notifies the list
  newTask.completed | true;
  assert(taskListNotify == 1, "List should be notified when element's member changes");

  newTask.priority | 5;
  assert(taskListNotify == 2, "List should be notified again");

  // --- Clearing a list ---
  print('\n10. Clearing a list');
  final clearTest = TomList<TomInt>();
  clearTest.append(TomInt(1)).append(TomInt(2)).append(TomInt(3));

  assert(clearTest.length == 3, "Should have 3 elements");
  clearTest.clear();
  assert(clearTest.isEmpty, "Should be empty after clear");
  assert(clearTest.isEmpty, "Length should be 0 after clear");
  print('   After clear(): length = ${clearTest.length}');

  print('\n=== All assertions passed! ===');
}
