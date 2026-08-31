/// Database-free unit tests for the persistence boundary: the domain ↔ record
/// mapping is pure — no I/O — so it verifies without a server or MariaDB. It is
/// also total, bar the single rejected input the `malformed ids` group pins.
///
/// The live endpoint + persistence round-trip against Docker MariaDB is
/// asserted by its own suite, `todo_endpoints_integration_test.dart`, which
/// `tool/run_integration.sh` runs against a stack it brings up; these tests
/// cover everything that does not need a database.
library;

import 'package:core_server_sample/core_server_sample.dart';
import 'package:todo_domain/todo_domain.dart';
import 'package:test/test.dart';

void main() {
  // The domain entities are observable TomClasses: constructing one self-
  // observes through reflection, so the reflection registry must be live before
  // any mapping runs. The records are plain DTOs and need no such setup.
  setUpAll(initializeReflection);

  group('user mapping', () {
    test('round-trips a persisted user', () {
      final record = TodoUserRecord()
        ..id = 7
        ..displayName = 'Ada'
        ..email = 'ada@example.com'
        ..role = 'owner';

      final user = userFromRecord(record);
      expect(user.id.get(), '7');
      expect(user.displayName.get(), 'Ada');
      expect(user.email.get(), 'ada@example.com');
      expect(user.role.get(), 'owner');

      final back = userToRecord(user);
      expect(back.id, 7);
      expect(back.displayName, 'Ada');
      expect(back.email, 'ada@example.com');
      expect(back.role, 'owner');
    });

    test('an unpersisted user maps to a null primary key', () {
      final user = User()..displayName.set('New');
      // id was never set -> empty string -> null DB key (INSERT, not UPDATE).
      expect(userToRecord(user).id, isNull);
    });

    test('a null record role defaults to member', () {
      final user = userFromRecord(TodoUserRecord()..id = 1);
      expect(user.role.get(), 'member');
    });
  });

  group('item mapping', () {
    test('round-trips an item with the owning list id', () {
      final record = TodoItemRecord()
        ..id = 3
        ..title = 'Write tests'
        ..description = 'cover the mapping'
        ..done = true
        ..priority = TodoPriority.high.name
        ..label = TodoLabel.docs.name
        ..assigneeId = 9
        ..listId = 4;

      final item = itemFromRecord(record);
      expect(item.id.get(), '3');
      expect(item.title.get(), 'Write tests');
      expect(item.done.get(), isTrue);
      expect(item.priorityValue, TodoPriority.high);
      expect(item.labelValue, TodoLabel.docs);
      expect(item.assigneeId.get(), '9');

      final back = itemToRecord(item, listId: 4);
      expect(back.id, 3);
      expect(back.title, 'Write tests');
      expect(back.done, isTrue);
      expect(back.priority, TodoPriority.high.name);
      expect(back.label, TodoLabel.docs.name);
      expect(back.assigneeId, 9);
      expect(back.listId, 4);
    });

    test('an unknown stored priority token degrades to medium', () {
      final item = itemFromRecord(TodoItemRecord()..priority = 'bogus');
      expect(item.priorityValue, TodoPriority.medium);
    });

    test('an unassigned item maps to a null assignee key', () {
      final item = TodoItem()..title.set('solo');
      expect(itemToRecord(item, listId: 1).assigneeId, isNull);
    });
  });

  group('project and list mapping', () {
    test('project round-trips without its nested lists', () {
      final record = TodoProjectRecord()
        ..id = 2
        ..name = 'Relaunch'
        ..description = 'the site'
        ..ownerId = 7;
      final project = projectFromRecord(record);
      expect(project.name.get(), 'Relaunch');
      expect(project.ownerId.get(), '7');
      expect(projectToRecord(project).ownerId, 7);
    });

    test('list round-trips its project foreign key', () {
      final list = listFromRecord(
        TodoListRecord()
          ..id = 5
          ..name = 'Backlog'
          ..projectId = 2,
      );
      expect(list.name.get(), 'Backlog');
      expect(list.projectId.get(), '2');
      expect(listToRecord(list).projectId, 2);
    });
  });

  // The domain ids are free-form strings a client can put anything into, and on
  // the way to the database `null` is not a neutral value: it is the INSERT
  // signal for a primary key and "unowned"/"unassigned" for a foreign key. So a
  // malformed id that quietly became `null` would duplicate a row or strip an
  // assignment rather than fail. These pin that it cannot.
  group('malformed ids', () {
    test('a malformed primary key throws instead of inserting a new row', () {
      final user = User()
        ..id.set('abc')
        ..displayName.set('Ada');
      expect(() => userToRecord(user), throwsFormatException);
    });

    test('a malformed foreign key throws instead of unassigning', () {
      final item = TodoItem()
        ..title.set('Write tests')
        ..assigneeId.set('nobody');
      expect(() => itemToRecord(item, listId: 1), throwsFormatException);
    });

    test('the failure names the offending field and value', () {
      final project = Project()..ownerId.set('me');
      expect(
        () => projectToRecord(project),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('Project.ownerId'))
              .having((e) => e.source, 'source', 'me'),
        ),
      );
    });

    test('both of a list\'s ids are checked', () {
      expect(
        () => listToRecord(TodoList()..id.set('five')),
        throwsFormatException,
      );
      expect(
        () => listToRecord(TodoList()..projectId.set('two')),
        throwsFormatException,
      );
    });

    // Without this the four cases above would all pass if every non-empty id
    // threw, which would break every write in the sample.
    test('a well-formed id still parses', () {
      expect(userToRecord(User()..id.set('42')).id, 42);
    });
  });
}
