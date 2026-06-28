/// Database-free integration tests for the write endpoints (step 20): the
/// [AppWriteService] composes the step-17 resource-access resolver and the
/// step-18 field-grade resolver, so the whole write path — role gating plus
/// per-field grade enforcement — verifies against seeded in-memory stores with
/// no server or MariaDB.
///
/// The fixture mirrors §A.10 (workspace 1 owned by alice=2, project 1 → list 1,
/// item 1 in list 1) and §A.4 (the grant matrix the auth server seeds), with
/// bob=3 shared `editor`, erin=5 shared `commenter`, and carol=4 shared `viewer`
/// on project 1. The step-20 "Done" bar is the headline triple: a `viewer` `PUT`
/// to `title` is rejected, an `editor` `PUT` succeeds, and the persisted row
/// reflects only the permitted fields.
///
/// The write service maps payloads through the domain↔record layer (which builds
/// observable entities), so the registry must be live; the grant rows and the
/// persistence records are plain classes and need no reflection.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int alice = 2; // workspace owner
const int bob = 3; // editor, shared on project 1
const int carol = 4; // viewer, shared on project 1
const int erin = 5; // commenter, shared on project 1
const int dave = 99; // stranger — grantee of no share, owner of nothing

// The §A.4 field-grade matrix — the per-field state for each role, the same
// data the auth server's `[001]-auth_authz_grants.sql` seeds.
const Map<ProjectRole, Map<String, TomAuthState>> a4Matrix = {
  ProjectRole.owner: {
    TodoItemResourceKeys.title: TomAuthState.full,
    TodoItemResourceKeys.status: TomAuthState.full,
    TodoItemResourceKeys.priority: TomAuthState.full,
    TodoItemResourceKeys.assigneeId: TomAuthState.full,
    TodoItemResourceKeys.dueDate: TomAuthState.full,
    TodoItemResourceKeys.estimate: TomAuthState.full,
    TodoItemResourceKeys.description: TomAuthState.full,
  },
  ProjectRole.editor: {
    TodoItemResourceKeys.title: TomAuthState.full,
    TodoItemResourceKeys.status: TomAuthState.full,
    TodoItemResourceKeys.priority: TomAuthState.full,
    TodoItemResourceKeys.assigneeId: TomAuthState.full,
    TodoItemResourceKeys.dueDate: TomAuthState.full,
    TodoItemResourceKeys.estimate: TomAuthState.read,
    TodoItemResourceKeys.description: TomAuthState.full,
  },
  ProjectRole.commenter: {
    TodoItemResourceKeys.title: TomAuthState.read,
    TodoItemResourceKeys.status: TomAuthState.full,
    TodoItemResourceKeys.priority: TomAuthState.read,
    TodoItemResourceKeys.assigneeId: TomAuthState.read,
    TodoItemResourceKeys.dueDate: TomAuthState.read,
    TodoItemResourceKeys.estimate: TomAuthState.none,
    TodoItemResourceKeys.description: TomAuthState.read,
  },
  ProjectRole.viewer: {
    TodoItemResourceKeys.title: TomAuthState.read,
    TodoItemResourceKeys.status: TomAuthState.read,
    TodoItemResourceKeys.priority: TomAuthState.read,
    TodoItemResourceKeys.assigneeId: TomAuthState.none,
    TodoItemResourceKeys.dueDate: TomAuthState.read,
    TodoItemResourceKeys.estimate: TomAuthState.none,
    TodoItemResourceKeys.description: TomAuthState.read,
  },
};

/// Flattens [a4Matrix] into the grant rows the auth server seeds.
List<TomResourceGrant> seedGrants() => [
      for (final role in a4Matrix.entries)
        for (final field in role.value.entries)
          TomResourceGrant(
            roleName: role.key.name,
            resourceKey: field.key,
            accessLevel: field.value,
          ),
    ];

// The §A.10 demo records. Fresh instances per call so the resource store and
// the write store hold independent (but equal) copies.
List<WorkspaceRecord> demoWorkspaces() => [WorkspaceRecord()..id = 1..ownerId = alice];
List<ProjectRecord> demoProjects() => [ProjectRecord()..id = 1..workspaceId = 1];
List<ListRecord> demoLists() => [ListRecord()..id = 1..projectId = 1];

/// The seeded item — a fully-populated row so a `PUT` can change one graded
/// field while leaving the rest equal to storage (no spurious diff).
ItemRecord demoItem() => ItemRecord()
  ..id = 1
  ..listId = 1
  ..title = 'Original title'
  ..description = 'Original description'
  ..status = TodoStatus.todo.name
  ..priority = TodoPriority.medium.name
  ..label = TodoLabel.feature.name
  ..assigneeId = alice
  ..reporterId = alice
  ..estimateHours = 4.0;

List<ShareRecord> demoShares() => [
      ShareRecord()
        ..id = 1
        ..resourceType = AppResourceTypes.project
        ..resourceId = 1
        ..granteeUserId = bob
        ..projectRole = ProjectRole.editor.name
        ..grantedById = alice,
      ShareRecord()
        ..id = 2
        ..resourceType = AppResourceTypes.project
        ..resourceId = 1
        ..granteeUserId = carol
        ..projectRole = ProjectRole.viewer.name
        ..grantedById = alice,
      ShareRecord()
        ..id = 3
        ..resourceType = AppResourceTypes.project
        ..resourceId = 1
        ..granteeUserId = erin
        ..projectRole = ProjectRole.commenter.name
        ..grantedById = alice,
    ];

/// Wires a write service over a caller-supplied [writeStore] (so a test can
/// inspect what was persisted) and freshly-seeded resolver stores.
AppWriteService writeServiceOver(InMemoryAppWriteStore writeStore) =>
    AppWriteService(
      writeStore,
      ResourceAccessResolver(InMemoryAppResourceStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: [demoItem()],
        shares: demoShares(),
      )),
      FieldGradeResolver(InMemoryGrantStore(seedGrants())),
    );

/// A new write store seeded with the demo item.
InMemoryAppWriteStore seededWriteStore() =>
    InMemoryAppWriteStore(items: [demoItem()]);

/// The persisted item-1 row out of [store].
ItemRecord persistedItem(InMemoryAppWriteStore store) =>
    store.items.firstWhere((i) => i.id == 1);

/// A [TodoItem] payload matching the stored item-1 (so only the fields a test
/// mutates differ from storage).
TodoItem itemPayload() => itemFromRecord(demoItem());

void main() {
  // The write service builds observable domain entities through the mapping
  // layer, which self-observe through reflection; the registry must be live.
  setUpAll(initializeReflection);

  group('updateItem field-grade enforcement (the step-20 Done bar)', () {
    test('a viewer PUT to title is rejected (read-only field)', () async {
      final store = seededWriteStore();
      final service = writeServiceOver(store);
      final payload = itemPayload()..title.set('Hacked by a viewer');

      await expectLater(
        () => service.updateItem(carol, 1, payload),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      // The rejected write left storage untouched.
      expect(persistedItem(store).title, 'Original title');
    });

    test('an editor PUT to full-graded fields succeeds and persists them',
        () async {
      final store = seededWriteStore();
      final service = writeServiceOver(store);
      final payload = itemPayload()
        ..title.set('Refined title')
        ..statusValue = TodoStatus.inProgress;

      final result = await service.updateItem(bob, 1, payload);

      expect(result.title.get(), 'Refined title');
      expect(result.status.get(), TodoStatus.inProgress.name);
      expect(persistedItem(store).title, 'Refined title');
      expect(persistedItem(store).status, TodoStatus.inProgress.name);
    });

    test('the persisted row reflects only permitted fields', () async {
      final store = seededWriteStore();
      final service = writeServiceOver(store);
      // The editor changes a permitted field (title) but the payload also tries
      // to overwrite the server-owned reporter and move the item to another
      // list. Those are not field-graded columns and must be ignored.
      final payload = itemPayload()
        ..title.set('Edited')
        ..reporterId.set('$dave')
        ..listId.set('999');

      await service.updateItem(bob, 1, payload);

      final persisted = persistedItem(store);
      expect(persisted.title, 'Edited'); // permitted change applied
      expect(persisted.reporterId, alice); // server-owned, preserved
      expect(persisted.listId, 1); // structural, preserved
    });

    test('an editor PUT changing a read-only field (estimate) is rejected',
        () async {
      final store = seededWriteStore();
      final service = writeServiceOver(store);
      final payload = itemPayload()..estimateHours.set(99.0);

      await expectLater(
        () => service.updateItem(bob, 1, payload),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(persistedItem(store).estimateHours, 4.0);
    });

    test('a commenter PUT to status succeeds but to title is rejected',
        () async {
      // The §A.4 matrix grants a commenter `full` on status yet only `read` on
      // title — field granularity within a single role.
      final statusStore = seededWriteStore();
      await writeServiceOver(statusStore)
          .updateItem(erin, 1, itemPayload()..statusValue = TodoStatus.done);
      expect(persistedItem(statusStore).status, TodoStatus.done.name);

      final titleStore = seededWriteStore();
      await expectLater(
        () => writeServiceOver(titleStore)
            .updateItem(erin, 1, itemPayload()..title.set('No')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });

    test('the owner may write every field, including estimate', () async {
      final store = seededWriteStore();
      final result = await writeServiceOver(store)
          .updateItem(alice, 1, itemPayload()..estimateHours.set(12.0));
      expect(result.estimateHours.get(), 12.0);
      expect(persistedItem(store).estimateHours, 12.0);
    });

    test('a stranger PUT is denied (closed/safe, not found)', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store)
            .updateItem(dave, 1, itemPayload()..title.set('x')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(persistedItem(store).title, 'Original title');
    });
  });

  group('deleteItem role gating (owner/editor only)', () {
    test('an editor may delete the item', () async {
      final store = seededWriteStore();
      await writeServiceOver(store).deleteItem(bob, 1);
      expect(store.items, isEmpty);
    });

    test('a viewer may not delete the item', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store).deleteItem(carol, 1),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.items, hasLength(1));
    });

    test('a stranger delete is denied', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store).deleteItem(dave, 1),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.items, hasLength(1));
    });
  });

  group('addComment role gating (commenter and above)', () {
    test('a commenter may comment, recorded as the author', () async {
      final store = seededWriteStore();
      final comment = TodoComment()..body.set('Looks good');
      final saved = await writeServiceOver(store).addComment(erin, 1, comment);

      expect(saved.authorId.get(), '$erin');
      expect(saved.itemId.get(), '1');
      expect(store.comments, hasLength(1));
      expect(store.comments.single.body, 'Looks good');
    });

    test('an editor may comment', () async {
      final store = seededWriteStore();
      await writeServiceOver(store)
          .addComment(bob, 1, TodoComment()..body.set('Done'));
      expect(store.comments, hasLength(1));
    });

    test('a viewer may not comment', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store)
            .addComment(carol, 1, TodoComment()..body.set('Nope')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.comments, isEmpty);
    });
  });

  group('createItem role gating + field grade', () {
    test('an editor may create an item, recorded as the reporter', () async {
      final store = seededWriteStore();
      final created = await writeServiceOver(store).createItem(
        bob,
        TodoItem()
          ..listId.set('1')
          ..title.set('Fresh task'),
      );
      expect(created.title.get(), 'Fresh task');
      expect(created.reporterId.get(), '$bob');
      expect(created.id.get(), isNotEmpty); // surrogate key assigned
      expect(store.items, hasLength(2));
    });

    test('a creator may not populate a field they are not full on', () async {
      // An editor is only `read` on estimate, so creating an item carrying an
      // estimate is rejected.
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store).createItem(
          bob,
          TodoItem()
            ..listId.set('1')
            ..estimateHours.set(8.0),
        ),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.items, hasLength(1));
    });

    test('a viewer may not create an item', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store).createItem(
          carol,
          TodoItem()
            ..listId.set('1')
            ..title.set('No'),
        ),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.items, hasLength(1));
    });
  });

  group('createProject role gating (workspace owner/editor)', () {
    test('the workspace owner may create a project', () async {
      final store = seededWriteStore();
      final created = await writeServiceOver(store).createProject(
        alice,
        Project()
          ..workspaceId.set('1')
          ..name.set('New project'),
      );
      expect(created.name.get(), 'New project');
      expect(created.id.get(), isNotEmpty);
      expect(store.projects, hasLength(1));
    });

    test('a project-only editor may not create a sibling workspace project',
        () async {
      // bob is shared `editor` on project 1, but holds no role on workspace 1,
      // so he cannot create a new project there.
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(store).createProject(
          bob,
          Project()
            ..workspaceId.set('1')
            ..name.set('Sneaky'),
        ),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.projects, isEmpty);
    });
  });
}
