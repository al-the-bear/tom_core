import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomString;
import 'package:test/test.dart';

void main() {
  setUpAll(initializeReflection);

  group('User', () {
    test('constructs with sensible defaults', () {
      final user = User();
      expect(user.id.get(), '');
      expect(user.username.get(), '');
      expect(user.statusValue, UserStatus.active);
    });

    test('round-trips every field', () {
      final user = User()
        ..id.set('u1')
        ..username.set('alice')
        ..displayName.set('Alice')
        ..email.set('alice@example.com')
        ..avatarRef.set('avatars/alice.png')
        ..statusValue = UserStatus.suspended;
      expect(user.id.get(), 'u1');
      expect(user.username.get(), 'alice');
      expect(user.displayName.get(), 'Alice');
      expect(user.email.get(), 'alice@example.com');
      expect(user.avatarRef.get(), 'avatars/alice.png');
      expect(user.status.get(), 'suspended');
      expect(user.statusValue, UserStatus.suspended);
    });
  });

  group('Workspace', () {
    test('constructs with a null createdAt', () {
      expect(Workspace().createdAt.getOrNull(), isNull);
    });

    test('round-trips every field', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4);
      final workspace = Workspace()
        ..id.set('w1')
        ..name.set('Acme Engineering')
        ..ownerId.set('u1')
        ..createdAt.set(created);
      expect(workspace.id.get(), 'w1');
      expect(workspace.name.get(), 'Acme Engineering');
      expect(workspace.ownerId.get(), 'u1');
      expect(workspace.createdAt.getOrNull(), created);
    });
  });

  group('Project', () {
    test('constructs unarchived', () {
      expect(Project().archived.get(), isFalse);
    });

    test('round-trips every field', () {
      final project = Project()
        ..id.set('p1')
        ..workspaceId.set('w1')
        ..name.set('Website relaunch')
        ..description.set('Q1 marketing site')
        ..colour.set('#3366FF')
        ..archived.set(true);
      expect(project.id.get(), 'p1');
      expect(project.workspaceId.get(), 'w1');
      expect(project.name.get(), 'Website relaunch');
      expect(project.description.get(), 'Q1 marketing site');
      expect(project.colour.get(), '#3366FF');
      expect(project.archived.get(), isTrue);
    });
  });

  group('TodoList', () {
    test('constructs at position zero', () {
      expect(TodoList().position.get(), 0);
    });

    test('round-trips every field', () {
      final list = TodoList()
        ..id.set('l1')
        ..projectId.set('p1')
        ..name.set('Sprint backlog')
        ..position.set(3);
      expect(list.id.get(), 'l1');
      expect(list.projectId.get(), 'p1');
      expect(list.name.get(), 'Sprint backlog');
      expect(list.position.get(), 3);
    });
  });

  group('TodoItem', () {
    test('constructs with workflow defaults', () {
      final item = TodoItem();
      expect(item.statusValue, TodoStatus.backlog);
      expect(item.priorityValue, TodoPriority.medium);
      expect(item.labelValue, TodoLabel.feature);
      expect(item.dueDate.getOrNull(), isNull);
      expect(item.estimateHours.getOrNull(), isNull);
      expect(item.tags.length, 0);
    });

    test('round-trips every field', () {
      final due = DateTime.utc(2026, 3, 10);
      final created = DateTime.utc(2026, 3, 1);
      final updated = DateTime.utc(2026, 3, 5);
      final item = TodoItem()
        ..id.set('i1')
        ..listId.set('l1')
        ..title.set('Ship advanced_todo_domain')
        ..description.set('Define the extended entities')
        ..statusValue = TodoStatus.inReview
        ..priorityValue = TodoPriority.critical
        ..labelValue = TodoLabel.bug
        ..assigneeId.set('u1')
        ..reporterId.set('u2')
        ..dueDate.set(due)
        ..estimateHours.set(4.5)
        ..createdAt.set(created)
        ..updatedAt.set(updated);
      item.tags.add(TomString('backend'));
      item.tags.add(TomString('reflection'));

      expect(item.id.get(), 'i1');
      expect(item.listId.get(), 'l1');
      expect(item.title.get(), 'Ship advanced_todo_domain');
      expect(item.description.get(), 'Define the extended entities');
      expect(item.status.get(), 'inReview');
      expect(item.statusValue, TodoStatus.inReview);
      expect(item.priority.get(), 'critical');
      expect(item.priorityValue, TodoPriority.critical);
      expect(item.label.get(), 'bug');
      expect(item.labelValue, TodoLabel.bug);
      expect(item.assigneeId.get(), 'u1');
      expect(item.reporterId.get(), 'u2');
      expect(item.dueDate.getOrNull(), due);
      expect(item.estimateHours.getOrNull(), 4.5);
      expect(item.createdAt.getOrNull(), created);
      expect(item.updatedAt.getOrNull(), updated);
      expect(item.tags.length, 2);
      expect(item.tags[0].get(), 'backend');
      expect(item.tags[1].get(), 'reflection');
    });

    test('unknown stored status falls back to backlog', () {
      final item = TodoItem()..status.set('bogus');
      expect(item.statusValue, TodoStatus.backlog);
    });
  });

  group('TodoComment', () {
    test('round-trips every field', () {
      final created = DateTime.utc(2026, 4, 1, 9);
      final comment = TodoComment()
        ..id.set('c1')
        ..itemId.set('i1')
        ..authorId.set('u1')
        ..body.set('Looks good to me')
        ..createdAt.set(created);
      expect(comment.id.get(), 'c1');
      expect(comment.itemId.get(), 'i1');
      expect(comment.authorId.get(), 'u1');
      expect(comment.body.get(), 'Looks good to me');
      expect(comment.createdAt.getOrNull(), created);
    });
  });

  group('Subtask', () {
    test('constructs undone at position zero', () {
      final subtask = Subtask();
      expect(subtask.done.get(), isFalse);
      expect(subtask.position.get(), 0);
    });

    test('round-trips every field', () {
      final subtask = Subtask()
        ..id.set('s1')
        ..itemId.set('i1')
        ..title.set('Write the test')
        ..done.set(true)
        ..position.set(2);
      expect(subtask.id.get(), 's1');
      expect(subtask.itemId.get(), 'i1');
      expect(subtask.title.get(), 'Write the test');
      expect(subtask.done.get(), isTrue);
      expect(subtask.position.get(), 2);
    });
  });

  group('Share', () {
    test('defaults to the viewer role', () {
      expect(Share().projectRole.get(), 'viewer');
      expect(Share().projectRoleValue, ProjectRole.viewer);
    });

    test('round-trips every field', () {
      final created = DateTime.utc(2026, 5, 1);
      final share = Share()
        ..id.set('sh1')
        ..resourceType.set('project')
        ..resourceId.set('p1')
        ..granteeUserId.set('u2')
        ..projectRoleValue = ProjectRole.editor
        ..grantedById.set('u1')
        ..createdAt.set(created);
      expect(share.id.get(), 'sh1');
      expect(share.resourceType.get(), 'project');
      expect(share.resourceId.get(), 'p1');
      expect(share.granteeUserId.get(), 'u2');
      expect(share.projectRole.get(), 'editor');
      expect(share.projectRoleValue, ProjectRole.editor);
      expect(share.grantedById.get(), 'u1');
      expect(share.createdAt.getOrNull(), created);
    });

    test('unknown stored role falls back to viewer', () {
      final share = Share()..projectRole.set('bogus');
      expect(share.projectRoleValue, ProjectRole.viewer);
    });
  });

  group('TodoItemResourceKeys', () {
    test('exposes the full, stable gradable-key set in display order', () {
      expect(TodoItemResourceKeys.all, [
        'todo.item.title',
        'todo.item.status',
        'todo.item.priority',
        'todo.item.assigneeId',
        'todo.item.dueDate',
        'todo.item.estimate',
        'todo.item.description',
      ]);
    });

    test('every named key is included in `all` exactly once', () {
      final named = [
        TodoItemResourceKeys.title,
        TodoItemResourceKeys.status,
        TodoItemResourceKeys.priority,
        TodoItemResourceKeys.assigneeId,
        TodoItemResourceKeys.dueDate,
        TodoItemResourceKeys.estimate,
        TodoItemResourceKeys.description,
      ];
      expect(TodoItemResourceKeys.all, named);
      expect(TodoItemResourceKeys.all.toSet(), hasLength(named.length));
    });

    test('every key is namespaced under `todo.item.`', () {
      for (final key in TodoItemResourceKeys.all) {
        expect(key, startsWith('todo.item.'));
      }
    });

    test('pins the scope/form segments the item form must run under', () {
      expect(TodoItemResourceKeys.scope, 'todo');
      expect(TodoItemResourceKeys.formId, 'item');
    });

    test('every key equals `<scope>.<formId>.<field>` (the convention)', () {
      // The contract todo 4 depends on: a field whose tomId is the token and
      // whose form runs under scope/formId self-addresses as exactly this key.
      expect(TodoItemResourceKeys.title,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.title');
      expect(TodoItemResourceKeys.status,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.status');
      expect(TodoItemResourceKeys.priority,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.priority');
      expect(TodoItemResourceKeys.assigneeId,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.assigneeId');
      expect(TodoItemResourceKeys.dueDate,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.dueDate');
      expect(TodoItemResourceKeys.estimate,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.estimate');
      expect(TodoItemResourceKeys.description,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.description');
    });

    test('keyFor builds each key from its field token', () {
      for (var i = 0; i < TodoItemResourceKeys.all.length; i++) {
        expect(TodoItemResourceKeys.keyFor(TodoItemResourceKeys.allFields[i]),
            TodoItemResourceKeys.all[i]);
      }
    });

    test('the estimate field token is `estimate`, not the member `estimateHours`',
        () {
      // D-A2: the resource key names the concept; the gradable estimate field's
      // tomId is `estimate` while its reflected entity member stays
      // `estimateHours`.
      expect(TodoItemResourceKeys.estimateField, 'estimate');
      expect(TodoItemResourceKeys.estimateField, isNot('estimateHours'));
      expect(TodoItemResourceKeys.estimate, endsWith('.estimate'));
    });

    test('field tokens are the last segment of each key, in `all` order', () {
      expect(TodoItemResourceKeys.allFields, hasLength(TodoItemResourceKeys.all.length));
      for (var i = 0; i < TodoItemResourceKeys.all.length; i++) {
        expect(TodoItemResourceKeys.all[i],
            endsWith('.${TodoItemResourceKeys.allFields[i]}'));
      }
    });
  });

  group('enums', () {
    test('every enum value round-trips through its stored name', () {
      for (final status in TodoStatus.values) {
        final item = TodoItem()..statusValue = status;
        expect(item.statusValue, status);
        expect(item.status.get(), status.name);
      }
      for (final priority in TodoPriority.values) {
        final item = TodoItem()..priorityValue = priority;
        expect(item.priorityValue, priority);
      }
      for (final label in TodoLabel.values) {
        final item = TodoItem()..labelValue = label;
        expect(item.labelValue, label);
      }
      for (final userStatus in UserStatus.values) {
        final user = User()..statusValue = userStatus;
        expect(user.statusValue, userStatus);
      }
      for (final role in ProjectRole.values) {
        final share = Share()..projectRoleValue = role;
        expect(share.projectRoleValue, role);
        expect(share.projectRole.get(), role.name);
      }
    });

    test('labels render human-facing text', () {
      expect(TodoStatus.inProgress.label, 'In progress');
      expect(TodoPriority.critical.label, 'Critical');
      expect(TodoLabel.docs.label, 'Docs');
      expect(UserStatus.suspended.label, 'Suspended');
      expect(ProjectRole.commenter.label, 'Commenter');
    });
  });
}
