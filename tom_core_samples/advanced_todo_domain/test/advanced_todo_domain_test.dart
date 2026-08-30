import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        TomAuthState,
        TomObservableEnum,
        TomResourceRoleRegistry,
        TomString;
import 'package:test/test.dart';

// The single test-only reflection seed for this package (G-REFL-2).
import 'run_all_tests.reflection.dart';

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

    test('enum display text resolves as a global.<enumtype>.<value> key '
        '(G-RES-5), carrying no hardcoded string', () {
      // The enum names the concept; the text lives in the resource bundle, and
      // the key is derived by the framework — this domain owns no label table.
      // Asserted here because these are the keys the served bundle must carry.
      String keyOf(Enum value) =>
          TomObservableEnum.resourceKeysFor(value).single;

      expect(keyOf(TodoStatus.inReview), 'global.todostatus.inreview');
      expect(keyOf(TodoPriority.critical), 'global.todopriority.critical');
      expect(keyOf(TodoLabel.docs), 'global.todolabel.docs');
      expect(keyOf(UserStatus.suspended), 'global.userstatus.suspended');
      expect(keyOf(ProjectRole.commenter), 'global.projectrole.commenter');
    });
  });

  group('resource-role vocabulary', () {
    setUp(TomResourceRoleRegistry.reset);
    tearDown(TomResourceRoleRegistry.reset);

    test('maps owner/editor to full and commenter/viewer to read (C-5)', () {
      registerProjectRoleVocabulary();
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.owner.name),
        TomAuthState.full,
      );
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.editor.name),
        TomAuthState.full,
      );
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.commenter.name),
        TomAuthState.read,
      );
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.viewer.name),
        TomAuthState.read,
      );
    });

    test('registers a grade for every ProjectRole', () {
      registerProjectRoleVocabulary();
      for (final role in ProjectRole.values) {
        expect(
          TomResourceRoleRegistry.stateFor(role.name),
          isNotNull,
          reason: 'ProjectRole.${role.name} must have a grade mapping',
        );
      }
    });

    test('is idempotent — re-registering re-establishes the same mapping', () {
      registerProjectRoleVocabulary();
      registerProjectRoleVocabulary();
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.owner.name),
        TomAuthState.full,
      );
      expect(
        TomResourceRoleRegistry.stateFor(ProjectRole.viewer.name),
        TomAuthState.read,
      );
    });
  });

  group('resource-role keys', () {
    test('builds <type>:<id> keys for each resource kind', () {
      expect(ResourceRoleKeys.workspace('1'), 'workspace:1');
      expect(ResourceRoleKeys.project('7'), 'project:7');
      expect(ResourceRoleKeys.list('12'), 'list:12');
      expect(ResourceRoleKeys.item('34'), 'item:34');
    });

    test('forResource composes the type token and id', () {
      expect(
        ResourceRoleKeys.forResource(ResourceRoleKeys.projectType, '7'),
        ResourceRoleKeys.project('7'),
      );
    });
  });
}
