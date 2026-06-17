// Assign a task to a user and complete it.
//
// Demonstrates the one concept of the User ↔ TodoItem relationship: a task
// points back at its assignee via assigneeId (= User.id), and the User.role
// is the key the four-state authorization layer reads in the server/UI samples.
//
// Run with: dart run example/assign_and_complete_example.dart

import 'package:todo_domain/todo_domain.dart';

void main() {
  initializeReflection();

  final owner = User()
    ..id.set('u-1')
    ..displayName.set('Ada Lovelace')
    ..role.set('owner');

  final task = TodoItem()
    ..title.set('Publish the article')
    ..assigneeId.set(owner.id.get());

  print('${task.title.get()} → ${owner.displayName.get()} '
      '(${owner.role.get()})');
  // expected: Publish the article → Ada Lovelace (owner)

  task.done.set(true);
  print('done: ${task.done.get()}'); // done: true
}
