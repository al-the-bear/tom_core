// Build the todo-management hierarchy: Project → TodoList → TodoItem.
//
// Demonstrates the one concept of nesting the reflected domain entities and
// reading them back through the observable accessors.
//
// Run with: dart run example/build_hierarchy_example.dart

import 'package:todo_domain/todo_domain.dart';

void main() {
  // Reflection must be initialised once before constructing any entity.
  initializeReflection();

  final project = Project()
    ..name.set('Website relaunch')
    ..description.set('Q3 marketing site rebuild');

  final backlog = TodoList()..name.set('Sprint backlog');
  backlog.items.add(TodoItem()..title.set('Design the landing page'));
  backlog.items.add(TodoItem()..title.set('Wire up the contact form'));

  project.lists.add(backlog);

  // Walk the hierarchy and print one line per leaf task.
  for (final list in project.lists) {
    for (final item in list.items) {
      print('${project.name.get()} › ${list.name.get()} › '
          '${item.title.get()}');
    }
  }
  // expected output:
  // Website relaunch › Sprint backlog › Design the landing page
  // Website relaunch › Sprint backlog › Wire up the contact form
}
