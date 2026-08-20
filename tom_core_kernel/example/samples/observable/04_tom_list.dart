// ignore_for_file: unnecessary_cast
/// TomList - Observable Lists Example
///
/// This example demonstrates TomList:
/// - Creating and manipulating observable lists
/// - Using append() method to add elements
/// - Automatic observation of list elements
/// - List operations (add, remove, access by index)
/// - Notifications on list and element changes
/// - Concatenating lists with + operator
/// - Replacing the whole list with the &lt;&lt; operator
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple Task class for list examples.
@tomReflector
class TaskItem extends TomClass {
  final title = TomString('');
  final completed = TomBool(false);
  final priority = TomInt(0);
}

// ============================================================================
// Example Class
// ============================================================================

class TomListExample {
  // Captured results
  static late TomList<TomInt> numbers;
  static late TomList<TomString> names;
  static late TomList<TaskItem> tasks;
  static int listNotifyCount = 0;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomLists
  // -------------------------------------------------------------------------
  static void example1CreatingLists() {
    print('1. Creating TomLists:');

    numbers = TomList<TomInt>();

    // Add elements using add() method
    numbers.add(TomInt(10));
    numbers.add(TomInt(20));
    numbers.add(TomInt(30));

    print('   numbers: [${numbers.map((e) => ~e).join(', ')}]');
    print('   length: ${numbers.length}');

    // Assertions
    assert(numbers.length == 3, 'List should have 3 elements');
    assert(~numbers[0] == 10, 'First element should be 10');
    assert(~numbers[1] == 20, 'Second element should be 20');
    assert(~numbers[2] == 30, 'Third element should be 30');
  }

  // -------------------------------------------------------------------------
  // Example 2: Using append() to add elements
  //
  // append() is how single elements are added. `<<` does NOT add — on a list
  // it replaces the whole contents; see example 9.
  // -------------------------------------------------------------------------
  static void example2AppendChaining() {
    print('\n2. Using append() to add elements:');

    names = TomList<TomString>();

    // append() returns the list for chaining
    names
        .append(TomString('Alice'))
        .append(TomString('Bob'))
        .append(TomString('Charlie'));

    print('   names: [${names.map((e) => ~e).join(', ')}]');

    // Assertions
    assert(names.length == 3, 'List should have 3 elements');
    assert(~names[0] == 'Alice', "First should be 'Alice'");
  }

  // -------------------------------------------------------------------------
  // Example 3: Observing list changes
  // -------------------------------------------------------------------------
  static void example3ObservingChanges() {
    print('\n3. Observing list changes:');

    final items = TomList<TomString>();
    listNotifyCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final itemsObserver =
        items >>
        (obs) {
          listNotifyCount++;
          print('   List notification #$listNotifyCount');
        };

    items.add(TomString('item1'));
    items.add(TomString('item2'));

    // Modifying an element also notifies the list
    items[0] | 'modified item1';

    print('   Total notifications: $listNotifyCount');

    // Assertions
    assert(listNotifyCount == 3, 'Should notify on add and element change');
    assert(~items[0] == 'modified item1', 'First item should be modified');

    items.removeObserver(itemsObserver);
  }

  // -------------------------------------------------------------------------
  // Example 4: List operations
  // -------------------------------------------------------------------------
  static void example4ListOperations() {
    print('\n4. List operations:');

    final scores = TomList<TomInt>();
    scores
        .append(TomInt(100))
        .append(TomInt(85))
        .append(TomInt(92))
        .append(TomInt(78));

    // Access by index
    print('   scores[0]: ${~scores[0]}');
    print('   scores[2]: ${~scores[2]}');

    // first and last
    print('   first: ${~scores.first}, last: ${~scores.last}');

    // isEmpty/isNotEmpty
    print('   isNotEmpty: ${scores.isNotEmpty}');

    // contains-like operations using any
    final hasHigh = scores.any((e) => ~e >= 90);
    print('   Has score >= 90: $hasHigh');

    // Assertions
    assert(~scores[0] == 100, 'scores[0] should be 100');
    assert(~scores.first == 100, 'first should be 100');
    assert(~scores.last == 78, 'last should be 78');
    assert(hasHigh, 'Should have score >= 90');
  }

  // -------------------------------------------------------------------------
  // Example 5: Modifying elements by index
  // -------------------------------------------------------------------------
  static void example5ModifyByIndex() {
    print('\n5. Modifying elements by index:');

    final values = TomList<TomDouble>();
    values.append(TomDouble(1.0)).append(TomDouble(2.0)).append(TomDouble(3.0));
    int modifyCount = 0;

    final valuesObserver = values >> (obs) => modifyCount++;

    // Replace element at index
    values[1] = TomDouble(2.5);
    print('   After values[1] = 2.5: ${~values[1]}');

    // Modify element's value
    values[0] | 1.5;
    print('   After values[0] | 1.5: ${~values[0]}');

    print('   values: [${values.map((e) => ~(e as TomDouble)).join(', ')}]');
    print('   Total notifications: $modifyCount');

    // Assertions
    assert(~values[1] == 2.5, 'values[1] should be 2.5');
    assert(~values[0] == 1.5, 'values[0] should be 1.5');
    assert(
      modifyCount == 2,
      'Should notify on index assignment and element change',
    );

    values.removeObserver(valuesObserver);
  }

  // -------------------------------------------------------------------------
  // Example 6: Removing elements
  // -------------------------------------------------------------------------
  static void example6RemovingElements() {
    print('\n6. Removing elements:');

    final fruits = TomList<TomString>();
    fruits
        .append(TomString('apple'))
        .append(TomString('banana'))
        .append(TomString('cherry'));

    print('   Before: [${fruits.map((e) => ~(e as TomString)).join(', ')}]');

    fruits.removeAt(1); // Remove "banana"
    print(
      '   After removeAt(1): [${fruits.map((e) => ~(e as TomString)).join(', ')}]',
    );

    fruits.removeLast();
    print(
      '   After removeLast: [${fruits.map((e) => ~(e as TomString)).join(', ')}]',
    );

    // Assertions
    assert(fruits.length == 1, 'Should have 1 fruit after removeLast');
    assert(~fruits[0] == 'apple', "First should still be 'apple'");
  }

  // -------------------------------------------------------------------------
  // Example 7: Concatenating lists with + operator
  // -------------------------------------------------------------------------
  static void example7Concatenating() {
    print('\n7. Concatenating lists with + operator:');

    final list1 = TomList<TomInt>();
    list1.append(TomInt(1)).append(TomInt(2));

    final list2 = TomList<TomInt>();
    list2.append(TomInt(3)).append(TomInt(4));

    final combined = list1 + list2;
    print(
      '   list1 + list2: [${combined.map((e) => ~(e as TomInt)).join(', ')}]',
    );

    // Original lists unchanged
    print('   list1.length: ${list1.length}, list2.length: ${list2.length}');

    // Assertions
    assert(combined.length == 4, 'Combined list should have 4 elements');
    assert(~combined[2] == 3, 'Third element should be 3');
    assert(list1.length == 2, 'list1 should be unchanged');
    assert(list2.length == 2, 'list2 should be unchanged');
  }

  // -------------------------------------------------------------------------
  // Example 8: TomList with TomClass elements
  // -------------------------------------------------------------------------
  static void example8TomClassElements() {
    print('\n8. TomList with TomClass elements:');

    tasks = TomList<TaskItem>();

    final task1 = TaskItem();
    task1.title | 'Complete report';
    task1.priority | 1;
    tasks.append(task1);

    final task2 = TaskItem();
    task2.title | 'Review code';
    task2.priority | 2;
    tasks.append(task2);

    print('   Tasks (${tasks.length}):');
    for (var task in tasks) {
      print('   - ${~task.title} (priority: ${~task.priority})');
    }

    // Modify a task
    tasks[0].completed | true;
    print('   Task 1 completed: ${~tasks[0].completed}');

    // Assertions
    assert(tasks.length == 2, 'Should have 2 tasks');
    assert(
      ~tasks[0].title == 'Complete report',
      'First task title should match',
    );
    assert(~tasks[0].completed == true, 'First task should be completed');
  }

  // -------------------------------------------------------------------------
  // Example 9: Replacing the whole list with the << operator
  // -------------------------------------------------------------------------
  static void example9ReplaceAllWithShiftOperator() {
    print('\n9. Replacing the whole list with <<:');

    final rows = TomList<TomString>();
    rows.append(TomString('a')).append(TomString('b'));

    int notifications = 0;

    // Retain the returned observer — see example 3 for why.
    final rowsObserver = rows >> (obs) => notifications++;

    // `set()` throws on a list: replacing the backing list behind the element
    // observers would strand them. `<<` performs the swap properly — it
    // detaches the outgoing elements, attaches the incoming ones, and emits a
    // single notification for the whole exchange rather than one per element.
    final returned = rows << [TomString('x'), TomString('y')];

    print('   rows: [${rows.map((e) => ~e).join(', ')}]');
    print('   notifications for the swap: $notifications');
    print('   returned is the same list: ${identical(returned, rows)}');

    // The outgoing elements are no longer observed, the incoming ones are.
    rows[0] | 'z';
    print('   notifications after changing a new element: $notifications');

    // Assertions
    assert(rows.length == 2, 'List should still have 2 elements');
    assert(identical(returned, rows), '<< should return the list itself');
    assert(
      notifications == 2,
      'One notification for the swap, one for the edit',
    );
    assert(~rows[0] == 'z', 'The incoming element should be observed and set');

    rows.removeObserver(rowsObserver);
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 04: TomList Example ===\n');

    example1CreatingLists();
    example2AppendChaining();
    example3ObservingChanges();
    example4ListOperations();
    example5ModifyByIndex();
    example6RemovingElements();
    example7Concatenating();
    example8TomClassElements();
    example9ReplaceAllWithShiftOperator();

    print('\n=== TomList Example Complete ===\n');
  }
}

void run() => TomListExample.run();

void main() {
  bootstrapSamples();
  run();
}
