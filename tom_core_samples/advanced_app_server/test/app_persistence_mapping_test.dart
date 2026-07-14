/// Database-free unit tests for the `app_db` persistence boundary: the domain
/// ↔ record mapping is pure and total, so it verifies without a server or
/// MariaDB (step 15's "Done" bar).
///
/// The live schema boot + seed rows are the gate of step 16; the live endpoint
/// round-trips against Docker MariaDB land in steps 19–21. These tests cover the
/// whole conversion surface that needs no database: id↔key handling
/// (unpersisted→null PK), foreign keys, enum-token leniency, and the tags codec.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
// `TomString` (kernel) is used to seed item tags; the domain barrel does not
// re-export it.
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

// The server's single reflection seed is its boot root (G-REFL-1); its tests
// bootstrap reflection from that same seed rather than a library seed.
import '../bin/app_server_start.reflection.dart' show initializeReflection;

void main() {
  // The domain entities are observable TomClasses: constructing one self-
  // observes through reflection, so the registry must be live before any
  // mapping runs. The records are plain classes and need no such setup.
  setUpAll(initializeReflection);

  group('workspace mapping', () {
    test('round-trips a persisted workspace, preserving every field', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final record = WorkspaceRecord()
        ..id = 5
        ..name = 'Acme Engineering'
        ..ownerId = 7
        ..createdAt = created;

      final workspace = workspaceFromRecord(record);
      expect(workspace.id.get(), '5');
      expect(workspace.name.get(), 'Acme Engineering');
      expect(workspace.ownerId.get(), '7');
      expect(workspace.createdAt.get(), created);

      final back = workspaceToRecord(workspace);
      expect(back.id, 5);
      expect(back.name, 'Acme Engineering');
      expect(back.ownerId, 7);
      expect(back.createdAt, created);
    });

    test('an unpersisted workspace maps to a null primary key (INSERT)', () {
      final workspace = Workspace()..name.set('New');
      expect(workspaceToRecord(workspace).id, isNull);
    });

    test('an empty owner id maps to a null foreign key', () {
      final workspace = Workspace()..name.set('Ownerless');
      expect(workspaceToRecord(workspace).ownerId, isNull);
    });
  });

  group('project mapping', () {
    test('round-trips a project with its workspace foreign key', () {
      final record = ProjectRecord()
        ..id = 3
        ..workspaceId = 5
        ..name = 'Website relaunch'
        ..description = 'Q1 push'
        ..colour = '#3366FF'
        ..archived = true;

      final project = projectFromRecord(record);
      expect(project.id.get(), '3');
      expect(project.workspaceId.get(), '5');
      expect(project.name.get(), 'Website relaunch');
      expect(project.description.get(), 'Q1 push');
      expect(project.colour.get(), '#3366FF');
      expect(project.archived.get(), isTrue);

      final back = projectToRecord(project);
      expect(back.id, 3);
      expect(back.workspaceId, 5);
      expect(back.colour, '#3366FF');
      expect(back.archived, isTrue);
    });

    test('a null archived flag degrades to false', () {
      final project = projectFromRecord(ProjectRecord()..id = 1);
      expect(project.archived.get(), isFalse);
    });
  });

  group('list mapping', () {
    test('round-trips a list with its project foreign key and position', () {
      final record = ListRecord()
        ..id = 9
        ..projectId = 3
        ..name = 'Sprint backlog'
        ..position = 2;

      final list = listFromRecord(record);
      expect(list.id.get(), '9');
      expect(list.projectId.get(), '3');
      expect(list.name.get(), 'Sprint backlog');
      expect(list.position.get(), 2);

      final back = listToRecord(list);
      expect(back.id, 9);
      expect(back.projectId, 3);
      expect(back.position, 2);
    });

    test('a null position degrades to zero', () {
      final list = listFromRecord(ListRecord()..id = 1);
      expect(list.position.get(), 0);
    });
  });

  group('item mapping', () {
    test('round-trips every scalar field and both user foreign keys', () {
      final due = DateTime.utc(2026, 3, 1);
      final created = DateTime.utc(2026, 2, 1);
      final updated = DateTime.utc(2026, 2, 2);
      final record = ItemRecord()
        ..id = 11
        ..listId = 9
        ..title = 'Write tests'
        ..description = 'cover the mapping'
        ..status = TodoStatus.inReview.name
        ..priority = TodoPriority.high.name
        ..label = TodoLabel.docs.name
        ..assigneeId = 7
        ..reporterId = 8
        ..dueDate = due
        ..estimateHours = 4.5
        ..createdAt = created
        ..updatedAt = updated;

      final item = itemFromRecord(record);
      expect(item.id.get(), '11');
      expect(item.listId.get(), '9');
      expect(item.statusValue, TodoStatus.inReview);
      expect(item.priorityValue, TodoPriority.high);
      expect(item.labelValue, TodoLabel.docs);
      expect(item.assigneeId.get(), '7');
      expect(item.reporterId.get(), '8');
      expect(item.dueDate.get(), due);
      expect(item.estimateHours.get(), 4.5);
      expect(item.createdAt.get(), created);
      expect(item.updatedAt.get(), updated);

      final back = itemToRecord(item);
      expect(back.id, 11);
      expect(back.listId, 9);
      expect(back.status, TodoStatus.inReview.name);
      expect(back.assigneeId, 7);
      expect(back.reporterId, 8);
      expect(back.estimateHours, 4.5);
    });

    test('an unassigned item maps assignee/reporter to null keys', () {
      final item = TodoItem()..title.set('Unassigned');
      final record = itemToRecord(item);
      expect(record.assigneeId, isNull);
      expect(record.reporterId, isNull);
    });

    test('absent enum columns seed the domain defaults', () {
      final item = itemFromRecord(ItemRecord()..id = 1);
      expect(item.statusValue, TodoStatus.backlog);
      expect(item.priorityValue, TodoPriority.medium);
      expect(item.labelValue, TodoLabel.feature);
    });

    test('an unknown stored enum token degrades through the typed accessor', () {
      final item = itemFromRecord(ItemRecord()
        ..id = 1
        ..status = 'not-a-status'
        ..priority = 'galactic');
      // Leniency: the raw token never crashes the mapping; the typed view falls
      // back to the enum's default.
      expect(item.statusValue, TodoStatus.backlog);
      expect(item.priorityValue, TodoPriority.medium);
    });

    test('tags round-trip through the serialized column', () {
      final item = TodoItem()..title.set('Tagged');
      item.tags.add(TomString('backend'));
      item.tags.add(TomString('urgent'));

      final record = itemToRecord(item);
      expect(record.tags, isNotNull);

      final back = itemFromRecord(record);
      expect([for (final t in back.tags.get()) t.get()], ['backend', 'urgent']);
    });

    test('no tags map to a null column, and a null column to no tags', () {
      final item = TodoItem()..title.set('Untagged');
      expect(itemToRecord(item).tags, isNull);

      final rebuilt = itemFromRecord(ItemRecord()..id = 1);
      expect(rebuilt.tags.get(), isEmpty);
    });

    test('a malformed tags column degrades to no tags', () {
      final item = itemFromRecord(ItemRecord()
        ..id = 1
        ..tags = 'not json at all');
      expect(item.tags.get(), isEmpty);
    });
  });

  group('comment mapping', () {
    test('round-trips a comment with item and author foreign keys', () {
      final created = DateTime.utc(2026, 4, 4);
      final record = CommentRecord()
        ..id = 2
        ..itemId = 11
        ..authorId = 7
        ..body = 'Looks good'
        ..createdAt = created;

      final comment = commentFromRecord(record);
      expect(comment.itemId.get(), '11');
      expect(comment.authorId.get(), '7');
      expect(comment.body.get(), 'Looks good');
      expect(comment.createdAt.get(), created);

      final back = commentToRecord(comment);
      expect(back.itemId, 11);
      expect(back.authorId, 7);
      expect(back.body, 'Looks good');
    });
  });

  group('subtask mapping', () {
    test('round-trips a subtask with done flag and position', () {
      final record = SubtaskRecord()
        ..id = 4
        ..itemId = 11
        ..title = 'Add fixtures'
        ..done = true
        ..position = 1;

      final subtask = subtaskFromRecord(record);
      expect(subtask.itemId.get(), '11');
      expect(subtask.done.get(), isTrue);
      expect(subtask.position.get(), 1);

      final back = subtaskToRecord(subtask);
      expect(back.itemId, 11);
      expect(back.done, isTrue);
      expect(back.position, 1);
    });

    test('a null done flag degrades to false', () {
      final subtask = subtaskFromRecord(SubtaskRecord()..id = 1);
      expect(subtask.done.get(), isFalse);
    });
  });
}
