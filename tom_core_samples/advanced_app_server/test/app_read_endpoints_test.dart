/// Database-free integration tests for the read endpoints (step 19, RCC3): the
/// [AppReadService] composes the step-17 [ResourceRoleResolver] and the step-18
/// field-grade resolver, so the whole read path — visibility filtering plus the
/// per-field grade matrix — verifies against seeded in-memory stores with no
/// server or MariaDB.
///
/// The fixture mirrors §A.10 (workspace 1 owned by alice=2, project 1 → lists
/// 1,2; items 1,2 in list 1) and §A.4 (the grant matrix the auth server seeds),
/// with bob=3 shared `editor` and carol=4 shared `viewer` on the project. RCC3
/// expresses ownership as a C-5 owner grant (RCC1) and each share as a C-6
/// `share`-mode [TomPrincipalDelegation], folded by the framework resolver into
/// the effective roles the containment rule then walks. The step-19 "Done" bar
/// is the headline pair: a shared user sees the owner's project, a stranger does
/// not.
///
/// The list endpoints return observable domain entities (built through the
/// mapping layer), so the registry must be live before they run; the grant and
/// delegation rows and the persistence records are plain classes and need no
/// reflection.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
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
const int dave = 99; // stranger — grantee of no share, owner of nothing

// The §A.4 field-grade matrix — the per-field state for each role, the same
// data the auth server's `[001]-auth_authz_grants.sql` seeds.
const Map<ProjectRole, Map<String, TomAuthState>> a4Matrix = {
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

/// Alice owns the whole tree via a single workspace-level owner grant (RCC1);
/// the containment rule flows it down to the project, lists and items.
List<TomPrincipalResourceGrant> demoGrants() => [
      TomPrincipalResourceGrant(
        principalId: '$alice',
        resourceKey: ResourceRoleKeys.workspace(1),
        role: ProjectRole.owner.name,
      ),
    ];

/// The two shares as C-6 `share`-mode delegations: bob `editor`, carol `viewer`
/// on project 1 (RCC3).
List<TomPrincipalDelegation> demoShares() => [
      TomPrincipalDelegation(
        mode: TomDelegationMode.share.name,
        delegatorId: '$alice',
        delegateId: '$bob',
        resourceKey: ResourceRoleKeys.project(1),
        role: ProjectRole.editor.name,
      ),
      TomPrincipalDelegation(
        mode: TomDelegationMode.share.name,
        delegatorId: '$alice',
        delegateId: '$carol',
        resourceKey: ResourceRoleKeys.project(1),
        role: ProjectRole.viewer.name,
      ),
    ];

/// The framework resolver folding the demo ownership grants and share
/// delegations into the effective `resourceKey → roleName` map.
ResourceRoleResolver demoResolver() => ResourceRoleResolver(
      InMemoryResourceContainmentStore(
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
      ),
      TomDelegationResolver(
        InMemoryPrincipalDelegationStore(demoShares()),
        TomPrincipalResourceRoleResolver(
          InMemoryPrincipalResourceGrantStore(demoGrants()),
        ),
      ),
    );

/// Wires the read service over the three seeded in-memory stores.
AppReadService demoService() => AppReadService(
      InMemoryAppReadStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
      ),
      demoResolver(),
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

  // The RCB5 read side: the resource-role map the app client installs as its
  // exact-match [TomResourceRoleAdapter]. Each grant is expanded down its
  // containment subtree, so a workspace/project grant surfaces on every
  // contained resource — the same downward flow the visibility filter above
  // relies on, here materialised as a flat key→role map.
  group('resourceRoles expands each grant down the containment subtree', () {
    test("the owner's workspace grant covers the whole tree", () async {
      expect(await service.resourceRoles(alice), {
        ResourceRoleKeys.workspace(1): ProjectRole.owner.name,
        ResourceRoleKeys.project(1): ProjectRole.owner.name,
        ResourceRoleKeys.list(1): ProjectRole.owner.name,
        ResourceRoleKeys.list(2): ProjectRole.owner.name,
        ResourceRoleKeys.item(1): ProjectRole.owner.name,
        ResourceRoleKeys.item(2): ProjectRole.owner.name,
      });
    });

    test("the editor grantee's project share covers only the project subtree",
        () async {
      // bob is shared `editor` on project 1 — his map covers the project and
      // its lists/items, but not the workspace (a share never flows up).
      expect(await service.resourceRoles(bob), {
        ResourceRoleKeys.project(1): ProjectRole.editor.name,
        ResourceRoleKeys.list(1): ProjectRole.editor.name,
        ResourceRoleKeys.list(2): ProjectRole.editor.name,
        ResourceRoleKeys.item(1): ProjectRole.editor.name,
        ResourceRoleKeys.item(2): ProjectRole.editor.name,
      });
    });

    test('the viewer grantee gets the viewer role over the project subtree',
        () async {
      expect(await service.resourceRoles(carol), {
        ResourceRoleKeys.project(1): ProjectRole.viewer.name,
        ResourceRoleKeys.list(1): ProjectRole.viewer.name,
        ResourceRoleKeys.list(2): ProjectRole.viewer.name,
        ResourceRoleKeys.item(1): ProjectRole.viewer.name,
        ResourceRoleKeys.item(2): ProjectRole.viewer.name,
      });
    });

    test('a stranger holds no roles (empty map, closed/safe)', () async {
      expect(await service.resourceRoles(dave), isEmpty);
    });
  });
}
