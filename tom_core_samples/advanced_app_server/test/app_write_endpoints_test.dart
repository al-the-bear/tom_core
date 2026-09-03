/// Database-free integration tests for the write endpoints (RCC3): the
/// [AppWriteService] composes the [ResourceRoleResolver] and the field-grade
/// resolver, so the whole write path — role gating plus per-field
/// grade enforcement — verifies against seeded in-memory stores with no server
/// or MariaDB.
///
/// The fixture mirrors the demo seed `[001]-app_demo_seed@dev,test.sql`
/// (workspace 1 owned by alice=2, project 1 → list 1, item 1 in list 1) and the
/// grant matrix `[001]-auth_authz_grants.sql` seeds, with bob=3 shared `editor`,
/// erin=5 shared `commenter`, and carol=4 shared `viewer` on project 1. RCC3 expresses ownership as a C-5 owner grant (RCC1) and each
/// share as a C-6 `share`-mode [TomPrincipalDelegation], folded by the framework
/// resolver into the effective roles the containment rule walks. The headline
/// triple is: a `viewer` `PUT` to `title` is rejected, an
/// `editor` `PUT` succeeds, and the persisted row reflects only the permitted
/// fields.
///
/// The write service maps payloads through the domain↔record layer (which builds
/// observable entities), so the registry must be live; the grant and delegation
/// rows and the persistence records are plain classes and need no reflection.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The server's single reflection seed is its boot root (G-REFL-1); its tests
// bootstrap reflection from that same seed rather than a library seed.
import '../bin/app_server_start.reflection.dart' show initializeReflection;

// Auth user ids, mirroring the auth seed.
const int alice = 2; // workspace owner
const int bob = 3; // editor, shared on project 1
const int carol = 4; // viewer, shared on project 1
const int erin = 5; // commenter, shared on project 1
const int dave = 99; // stranger — grantee of no share, owner of nothing

// The field-grade matrix — the per-field state for each role, the same data
// the auth server's `[001]-auth_authz_grants.sql` seeds.
const Map<ProjectRole, Map<String, TomAuthState>> seededGrantMatrix = {
  ProjectRole.owner: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.full,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.full,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.editor: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.full,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.read,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.commenter: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.read,
    'todo.item.assigneeId': TomAuthState.read,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
  ProjectRole.viewer: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.read,
    'todo.item.priority': TomAuthState.read,
    'todo.item.assigneeId': TomAuthState.none,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
};

/// Flattens [seededGrantMatrix] into the grant rows the auth server seeds.
List<TomResourceGrant> seedGrants() => [
  for (final role in seededGrantMatrix.entries)
    for (final field in role.value.entries)
      TomResourceGrant(
        roleName: role.key.name,
        resourceKey: field.key,
        accessLevel: field.value,
      ),
];

// The demo seed's records (`[001]-app_demo_seed@dev,test.sql`). Fresh instances
// per call so the resource store and the write store hold independent (but
// equal) copies.
List<ProjectRecord> demoProjects() => [
  ProjectRecord()
    ..id = 1
    ..workspaceId = 1,
];
List<ListRecord> demoLists() => [
  ListRecord()
    ..id = 1
    ..projectId = 1,
];

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

/// Alice owns the whole tree via a single workspace-level owner grant (RCC1);
/// the containment rule flows it down to the project, lists and item.
List<TomPrincipalResourceGrant> demoGrants() => [
  TomPrincipalResourceGrant(
    principalId: '$alice',
    resourceKey: ResourceRoleKeys.workspace('1'),
    role: ProjectRole.owner.name,
  ),
];

/// The three shares as C-6 `share`-mode delegations on project 1: bob `editor`,
/// carol `viewer`, erin `commenter` (RCC3). None target the workspace, so a
/// grantee holds no role there.
List<TomPrincipalDelegation> demoShares() => [
  shareDelegation(delegate: bob, role: ProjectRole.editor),
  shareDelegation(delegate: carol, role: ProjectRole.viewer),
  shareDelegation(delegate: erin, role: ProjectRole.commenter),
];

/// Builds a `share`-mode delegation from alice on project 1 (unbounded window,
/// not revoked).
TomPrincipalDelegation shareDelegation({
  required int delegate,
  required ProjectRole role,
}) => TomPrincipalDelegation(
  mode: TomDelegationMode.share.name,
  delegatorId: '$alice',
  delegateId: '$delegate',
  resourceKey: ResourceRoleKeys.project('1'),
  role: role.name,
);

/// Wires a write service over a caller-supplied [writeStore] (so a test can
/// inspect what was persisted) and freshly-seeded resolver stores. A test that
/// asserts ownership grants passes its own [ownershipWriter] to introspect the
/// recorded owner grants (RCC1); the default writer discards them.
AppWriteService writeServiceOver(
  InMemoryAppWriteStore writeStore, {
  OwnershipGrantWriter? ownershipWriter,
}) => AppWriteService(
  writeStore,
  ResourceRoleResolver(
    InMemoryResourceContainmentStore(
      projects: demoProjects(),
      lists: demoLists(),
      items: [demoItem()],
    ),
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore(demoShares()),
      TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore(demoGrants()),
      ),
    ),
  ),
  FieldGradeResolver(InMemoryGrantStore(seedGrants())),
  ownershipWriter ?? InMemoryOwnershipGrantWriter(),
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

  group('updateItem field-grade enforcement', () {
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

    test(
      'an editor PUT to full-graded fields succeeds and persists them',
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
      },
    );

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

    test(
      'an editor PUT changing a read-only field (estimate) is rejected',
      () async {
        final store = seededWriteStore();
        final service = writeServiceOver(store);
        final payload = itemPayload()..estimateHours.set(99.0);

        await expectLater(
          () => service.updateItem(bob, 1, payload),
          throwsA(isA<TomEndpointHandlerException>()),
        );
        expect(persistedItem(store).estimateHours, 4.0);
      },
    );

    test(
      'a commenter PUT to status succeeds but to title is rejected',
      () async {
        // The grant matrix gives a commenter `full` on status yet only `read` on
        // title — field granularity within a single role.
        final statusStore = seededWriteStore();
        await writeServiceOver(
          statusStore,
        ).updateItem(erin, 1, itemPayload()..statusValue = TodoStatus.done);
        expect(persistedItem(statusStore).status, TodoStatus.done.name);

        final titleStore = seededWriteStore();
        await expectLater(
          () => writeServiceOver(
            titleStore,
          ).updateItem(erin, 1, itemPayload()..title.set('No')),
          throwsA(isA<TomEndpointHandlerException>()),
        );
      },
    );

    test('the owner may write every field, including estimate', () async {
      final store = seededWriteStore();
      final result = await writeServiceOver(
        store,
      ).updateItem(alice, 1, itemPayload()..estimateHours.set(12.0));
      expect(result.estimateHours.get(), 12.0);
      expect(persistedItem(store).estimateHours, 12.0);
    });

    test('a stranger PUT is denied (closed/safe, not found)', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(
          store,
        ).updateItem(dave, 1, itemPayload()..title.set('x')),
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
      await writeServiceOver(
        store,
      ).addComment(bob, 1, TodoComment()..body.set('Done'));
      expect(store.comments, hasLength(1));
    });

    test('a viewer may not comment', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(
          store,
        ).addComment(carol, 1, TodoComment()..body.set('Nope')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.comments, isEmpty);
    });
  });

  // Subtasks are gated one step *stronger* than comments: a comment is about an
  // item, a subtask is part of it, so adding one changes what the item claims to
  // require. The gating tests below are what pin that difference — `erin` is the
  // fixture's `commenter`, and she is the one caller who may comment but not
  // build a checklist.
  group('addSubtask role gating (editor and above)', () {
    test('an editor may add a subtask, filed under the addressed item', () async {
      // `position` is server-owned like `id` and `itemId`: the step appends, so
      // the caller's 7 is ignored and the first entry of an empty checklist
      // lands at 0. A client's position is only ever a guess from whatever list
      // it happened to be holding.
      final store = seededWriteStore();
      final saved = await writeServiceOver(store).addSubtask(
        bob,
        1,
        Subtask()
          ..title.set('Write the migration')
          ..position.set(7),
      );

      expect(saved.itemId.get(), '1');
      expect(saved.title.get(), 'Write the migration');
      expect(store.subtasks, hasLength(1));
      expect(store.subtasks.single.position, 0);
    });

    test(
      'successive subtasks append rather than collide at one position',
      () async {
        // The counter is per item, not global: a neighbouring item's checklist
        // sitting at position 5 does not push item 1's first step past 0.
        final store = InMemoryAppWriteStore(
          items: [demoItem()],
          subtasks: [
            SubtaskRecord()
              ..id = 9
              ..itemId = 2
              ..title = 'Someone else’s step'
              ..done = false
              ..position = 5,
          ],
        );
        final service = writeServiceOver(store);
        await service.addSubtask(bob, 1, Subtask()..title.set('First'));
        await service.addSubtask(bob, 1, Subtask()..title.set('Second'));

        expect(
          store.subtasks
              .where((s) => s.itemId == 1)
              .map((s) => '${s.position}/${s.title}'),
          ['0/First', '1/Second'],
        );
      },
    );

    test('a commenter may not add a subtask', () async {
      // The line between the two child collections: erin may comment (asserted
      // above) but a checklist entry is an edit to the item's scope.
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(
          store,
        ).addSubtask(erin, 1, Subtask()..title.set('Nope')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.subtasks, isEmpty);
    });

    test('a viewer may not add a subtask', () async {
      final store = seededWriteStore();
      await expectLater(
        () => writeServiceOver(
          store,
        ).addSubtask(carol, 1, Subtask()..title.set('Nope')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.subtasks, isEmpty);
    });

    test('the payload cannot file the subtask under another item', () async {
      // `itemId` is stamped from the addressed item, so a payload naming a
      // different parent is overwritten rather than honoured — otherwise the
      // gate would have been resolved against one item and the row written
      // under another.
      final store = seededWriteStore();
      final saved = await writeServiceOver(store).addSubtask(
        bob,
        1,
        Subtask()
          ..itemId.set('999')
          ..title.set('Smuggled'),
      );
      expect(saved.itemId.get(), '1');
      expect(store.subtasks.single.itemId, 1);
    });
  });

  group('updateSubtask gating and server-owned columns', () {
    /// A store carrying one subtask on item 1 — the row the update tests edit.
    InMemoryAppWriteStore storeWithSubtask() => InMemoryAppWriteStore(
      items: [demoItem()],
      subtasks: [
        SubtaskRecord()
          ..id = 5
          ..itemId = 1
          ..title = 'Draft the schema'
          ..done = false
          ..position = 0,
      ],
    );

    test('an editor may toggle done', () async {
      final store = storeWithSubtask();
      final saved = await writeServiceOver(store).updateSubtask(
        bob,
        5,
        Subtask()
          ..title.set('Draft the schema')
          ..done.set(true)
          ..position.set(0),
      );
      expect(saved.done.get(), true);
      expect(store.subtasks.single.done, isTrue);
    });

    test('a viewer may not toggle done', () async {
      final store = storeWithSubtask();
      await expectLater(
        () => writeServiceOver(
          store,
        ).updateSubtask(carol, 5, Subtask()..done.set(true)),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(store.subtasks.single.done, isFalse);
    });

    test(
      'the parent link is not writable — a subtask cannot be moved',
      () async {
        // The gate was resolved from the *stored* parent, so honouring a payload
        // `itemId` would let an editor of item 1 attach a row to an item they
        // hold nothing on.
        final store = storeWithSubtask();
        final saved = await writeServiceOver(store).updateSubtask(
          bob,
          5,
          Subtask()
            ..itemId.set('999')
            ..title.set('Draft the schema'),
        );
        expect(saved.itemId.get(), '1');
        expect(store.subtasks.single.itemId, 1);
      },
    );

    test('an unknown subtask is reported missing, not forbidden', () async {
      final store = storeWithSubtask();
      await expectLater(
        () => writeServiceOver(
          store,
        ).updateSubtask(bob, 404, Subtask()..done.set(true)),
        throwsA(
          isA<TomException>().having(
            (e) => e.key,
            'key',
            'app.subtask.not_found',
          ),
        ),
      );
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

    test(
      'creating an item stamps the creator as its C-5 owner (RCC1)',
      () async {
        final store = seededWriteStore();
        final owner = InMemoryOwnershipGrantWriter();
        final created = await writeServiceOver(store, ownershipWriter: owner)
            .createItem(
              bob,
              TodoItem()
                ..listId.set('1')
                ..title.set('Fresh task'),
            );

        expect(owner.grants, hasLength(1));
        final grant = owner.grants.single;
        expect(grant.principalId, '$bob');
        expect(grant.resourceKey, ResourceRoleKeys.item(created.id.get()));
        expect(grant.role, ProjectRole.owner.name);
      },
    );

    test('a rejected create records no ownership grant', () async {
      final store = seededWriteStore();
      final owner = InMemoryOwnershipGrantWriter();
      await expectLater(
        () => writeServiceOver(store, ownershipWriter: owner).createItem(
          carol,
          TodoItem()
            ..listId.set('1')
            ..title.set('No'),
        ),
        throwsA(isA<TomEndpointHandlerException>()),
      );
      expect(owner.grants, isEmpty);
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

    test(
      'creating a project stamps the creator as its C-5 owner (RCC1)',
      () async {
        final store = seededWriteStore();
        final owner = InMemoryOwnershipGrantWriter();
        final created = await writeServiceOver(store, ownershipWriter: owner)
            .createProject(
              alice,
              Project()
                ..workspaceId.set('1')
                ..name.set('New project'),
            );

        expect(owner.grants, hasLength(1));
        final grant = owner.grants.single;
        expect(grant.principalId, '$alice');
        expect(grant.resourceKey, ResourceRoleKeys.project(created.id.get()));
        expect(grant.role, ProjectRole.owner.name);
      },
    );

    test(
      'a project-only editor may not create a sibling workspace project',
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
      },
    );
  });

  group('createWorkspace ownership (RCB9 scoped-entity create)', () {
    // The scoped-entity write path. `createWorkspace` has no share/role gate: any
    // authenticated principal may create their *own* workspace, and the creator
    // "becomes the owner" both ways — the `ownerId` column is stamped with their
    // id (so the framework `@TomDbScope(field: 'ownerId')` owner-scope makes the
    // row theirs; the live insert-scope check permits it) and an explicit C-5
    // owner grant is recorded. The database-free store cannot enforce the scope
    // (that fires only against the live repository, exercised in the RCB9
    // integration script), so these tests assert the creator↔owner wiring.
    test('persists the workspace with the creator as its owner', () async {
      final store = seededWriteStore();
      final created = await writeServiceOver(
        store,
      ).createWorkspace(dave, Workspace()..name.set('Dave\'s space'));

      expect(created.name.get(), 'Dave\'s space');
      expect(created.id.get(), isNotEmpty); // surrogate key assigned
      expect(created.ownerId.get(), '$dave'); // creator stamped as owner
      expect(store.workspaces, hasLength(1));
      expect(store.workspaces.single.ownerId, dave);
    });

    test('stamps the creator as the workspace C-5 owner (RCC1)', () async {
      final store = seededWriteStore();
      final owner = InMemoryOwnershipGrantWriter();
      final created = await writeServiceOver(
        store,
        ownershipWriter: owner,
      ).createWorkspace(dave, Workspace()..name.set('Dave\'s space'));

      expect(owner.grants, hasLength(1));
      final grant = owner.grants.single;
      expect(grant.principalId, '$dave');
      expect(grant.resourceKey, ResourceRoleKeys.workspace(created.id.get()));
      expect(grant.role, ProjectRole.owner.name);
    });
  });
}
