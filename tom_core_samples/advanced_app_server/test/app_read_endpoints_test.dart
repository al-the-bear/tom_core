/// Database-free integration tests for the read endpoints (step 19): the
/// [AppReadService] composes the step-17 resource-access resolver and the
/// step-18 field-grade resolver, so the whole read path — visibility filtering
/// plus the per-field grade matrix — verifies against seeded in-memory stores
/// with no server or MariaDB.
///
/// The fixture mirrors §A.10 (workspace 1 owned by alice=2, project 1 → lists
/// 1,2; items 1,2 in list 1) and §A.4 (the grant matrix the auth server seeds),
/// with bob=3 shared `editor` and carol=4 shared `viewer` on the project. The
/// step-19 "Done" bar is the headline pair: a shared user sees the owner's
/// project, a stranger does not.
///
/// The list endpoints return observable domain entities (built through the
/// mapping layer), so the registry must be live before they run; the grant rows
/// and the persistence records are plain classes and need no reflection.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int alice = 2; // workspace owner
const int bob = 3; // editor, shared on project 1
const int carol = 4; // viewer, shared on project 1
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
// the read store hold independent (but equal) copies.
List<WorkspaceRecord> demoWorkspaces() => [WorkspaceRecord()..id = 1..ownerId = alice];
List<ProjectRecord> demoProjects() => [ProjectRecord()..id = 1..workspaceId = 1];
List<ListRecord> demoLists() => [
      ListRecord()..id = 1..projectId = 1,
      ListRecord()..id = 2..projectId = 1,
    ];
List<ItemRecord> demoItems() => [
      ItemRecord()..id = 1..listId = 1,
      ItemRecord()..id = 2..listId = 1,
    ];
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
    ];

/// Wires the read service over the three seeded in-memory stores.
AppReadService demoService() => AppReadService(
      InMemoryAppReadStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
      ),
      ResourceAccessResolver(InMemoryAppResourceStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
        shares: demoShares(),
      )),
      FieldGradeResolver(InMemoryGrantStore(seedGrants())),
    );

/// Collapses a field-state list into the `resourceKey → state` map [a4Matrix]
/// rows are expressed in.
Map<String, TomAuthState> statesMap(List<GradedFieldDto> states) =>
    {for (final state in states) state.resourceKey: state.accessState};

void main() {
  // The list endpoints build observable domain entities through the mapping
  // layer, which self-observe through reflection; the registry must be live.
  setUpAll(initializeReflection);

  final service = demoService();

  group('the owner sees the whole tree', () {
    test('lists the owned workspace, project, lists, and items', () async {
      expect((await service.listWorkspaces(alice)).map((w) => w.id.get()), ['1']);
      expect((await service.listProjects(alice, 1)).map((p) => p.id.get()), ['1']);
      expect((await service.listLists(alice, 1)).map((l) => l.id.get()),
          ['1', '2']);
      expect((await service.listItems(alice, 1)).map((i) => i.id.get()),
          ['1', '2']);
    });

    test('item field-states reproduce the owner grade row (all full)', () async {
      expect(
        statesMap(await service.itemFieldStates(alice, 1)),
        a4Matrix[ProjectRole.owner],
      );
    });
  });

  group('a shared user sees the owner project (the step-19 Done bar)', () {
    test('the editor grantee sees the shared project and its descendants', () async {
      // bob is shared `editor` on project 1 — he sees the owner's project and
      // the lists/items it contains, even though he owns nothing.
      expect((await service.listProjects(bob, 1)).map((p) => p.id.get()), ['1']);
      expect((await service.listLists(bob, 1)).map((l) => l.id.get()),
          ['1', '2']);
      expect((await service.listItems(bob, 1)).map((i) => i.id.get()),
          ['1', '2']);
    });

    test('the share does not flow up to the workspace', () async {
      // The share targets the project, not the workspace; with no upward flow
      // bob has no workspace to list.
      expect(await service.listWorkspaces(bob), isEmpty);
    });

    test('field-states reflect the editor grade row (estimate read-only)', () async {
      expect(
        statesMap(await service.itemFieldStates(bob, 1)),
        a4Matrix[ProjectRole.editor],
      );
    });

    test('the viewer grantee gets the viewer grade row', () async {
      expect(
        statesMap(await service.itemFieldStates(carol, 1)),
        a4Matrix[ProjectRole.viewer],
      );
    });
  });

  group('a stranger sees nothing (the step-19 Done bar)', () {
    test('every list endpoint is empty for an unshared, non-owner user', () async {
      expect(await service.listWorkspaces(dave), isEmpty);
      expect(await service.listProjects(dave, 1), isEmpty);
      expect(await service.listLists(dave, 1), isEmpty);
      expect(await service.listItems(dave, 1), isEmpty);
    });

    test('item field-states are denied (closed/safe) for a stranger', () async {
      expect(
        () => service.itemFieldStates(dave, 1),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });
  });
}
