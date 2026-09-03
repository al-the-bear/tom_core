/// Database-free unit tests for the resource-role resolver (RCC3): the
/// ownership-and-share rule is pure over the framework [TomDelegationResolver]
/// (fed a seeded C-5 grant store and a C-6 delegation store) plus the app's
/// [ResourceContainmentStore] seam, so it verifies against seeded in-memory
/// stores with no server or MariaDB.
///
/// The seed mirrors the demo data `[001]-app_demo_seed@dev,test.sql` creates:
/// workspace 1 owned by alice (auth user 2), a project 1 with two lists and an
/// item, and two shares — bob (3) as `editor` and carol (4) as `viewer` on the
/// project. RCC3 expresses those as an
/// explicit C-5 owner grant (RCC1) and C-6 `share`-mode [TomPrincipalDelegation]
/// rows, folded by the framework resolver into one flat `resourceKey → roleName`
/// map; this resolver adds only the sample's containment rule.
///
/// Each principal holds at most one role per resource key here, so the fold
/// never has to break a per-key tie and the suite needs no role-vocabulary
/// registry — the entities are plain no-arg-constructible classes.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int alice = 2;
const int bob = 3;
const int carol = 4;
const int dave = 99; // a stranger — grantee of no share, owner of nothing.

/// The demo containment tree: project 1 in workspace 1; lists 1,2 in project 1;
/// item 1 in list 1.
InMemoryResourceContainmentStore demoContainment() =>
    InMemoryResourceContainmentStore(
      projects: [
        ProjectRecord()
          ..id = 1
          ..workspaceId = 1,
      ],
      lists: [
        ListRecord()
          ..id = 1
          ..projectId = 1,
        ListRecord()
          ..id = 2
          ..projectId = 1,
      ],
      items: [
        ItemRecord()
          ..id = 1
          ..listId = 1,
      ],
    );

/// Alice owns the whole tree via a single workspace-level owner grant; the
/// containment rule flows it down to the project, lists and item. (The write
/// paths stamp finer per-resource grants at runtime, but one ancestor grant is
/// enough to exercise the flow-down.)
List<TomPrincipalResourceGrant> demoGrants() => [
  TomPrincipalResourceGrant(
    principalId: '$alice',
    resourceKey: ResourceRoleKeys.workspace('1'),
    role: ProjectRole.owner.name,
  ),
];

/// The two pre-existing shares: bob is `editor`, carol is `viewer` on project 1.
List<TomPrincipalDelegation> demoShares() => [
  shareDelegation(
    delegator: alice,
    delegate: bob,
    resourceKey: ResourceRoleKeys.project('1'),
    role: ProjectRole.editor,
  ),
  shareDelegation(
    delegator: alice,
    delegate: carol,
    resourceKey: ResourceRoleKeys.project('1'),
    role: ProjectRole.viewer,
  ),
];

/// Builds a `share`-mode delegation row (unbounded window, not revoked).
TomPrincipalDelegation shareDelegation({
  required int delegator,
  required int delegate,
  required String resourceKey,
  required ProjectRole role,
}) => TomPrincipalDelegation(
  mode: TomDelegationMode.share.name,
  delegatorId: '$delegator',
  delegateId: '$delegate',
  resourceKey: resourceKey,
  role: role.name,
);

/// Builds the resolver over seeded grant and delegation stores and the demo
/// containment tree.
ResourceRoleResolver buildResolver({
  List<TomPrincipalResourceGrant>? grants,
  List<TomPrincipalDelegation>? shares,
}) {
  final delegationResolver = TomDelegationResolver(
    InMemoryPrincipalDelegationStore(shares ?? demoShares()),
    TomPrincipalResourceRoleResolver(
      InMemoryPrincipalResourceGrantStore(grants ?? demoGrants()),
    ),
  );
  return ResourceRoleResolver(demoContainment(), delegationResolver);
}

void main() {
  group('ownership', () {
    test(
      'the workspace owner resolves to owner on the workspace itself',
      () async {
        expect(
          await buildResolver().resolveRole(
            userId: alice,
            resourceType: AppResourceTypes.workspace,
            resourceId: 1,
          ),
          ProjectRole.owner,
        );
      },
    );

    test('ownership flows down the chain to project, list, and item', () async {
      final resolver = buildResolver();
      for (final ref in [
        (AppResourceTypes.project, 1),
        (AppResourceTypes.list, 1),
        (AppResourceTypes.item, 1),
      ]) {
        expect(
          await resolver.resolveRole(
            userId: alice,
            resourceType: ref.$1,
            resourceId: ref.$2,
          ),
          ProjectRole.owner,
          reason: 'alice owns the workspace, so she owns ${ref.$1}:${ref.$2}',
        );
      }
    });
  });

  group('shares', () {
    test(
      'a grantee resolves to the shared role on the shared resource',
      () async {
        final resolver = buildResolver();
        expect(
          await resolver.resolveRole(
            userId: bob,
            resourceType: AppResourceTypes.project,
            resourceId: 1,
          ),
          ProjectRole.editor,
        );
        expect(
          await resolver.resolveRole(
            userId: carol,
            resourceType: AppResourceTypes.project,
            resourceId: 1,
          ),
          ProjectRole.viewer,
        );
      },
    );

    test(
      'a share on a project covers its lists and items (descendants)',
      () async {
        final resolver = buildResolver();
        // The share targets project 1; the resolver walks the item's ancestry up
        // to that project and grants the shared role.
        expect(
          await resolver.resolveRole(
            userId: bob,
            resourceType: AppResourceTypes.item,
            resourceId: 1,
          ),
          ProjectRole.editor,
        );
        expect(
          await resolver.resolveRole(
            userId: carol,
            resourceType: AppResourceTypes.list,
            resourceId: 2,
          ),
          ProjectRole.viewer,
        );
      },
    );

    test('a share does not flow upward to an ancestor', () async {
      // A share on item 1 only — it must NOT grant access to the parent project.
      final resolver = buildResolver(
        shares: [
          ...demoShares(),
          shareDelegation(
            delegator: alice,
            delegate: dave,
            resourceKey: ResourceRoleKeys.item('1'),
            role: ProjectRole.editor,
          ),
        ],
      );
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.item,
          resourceId: 1,
        ),
        ProjectRole.editor,
        reason: 'dave has a direct share on item 1',
      );
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        isNull,
        reason: 'the item share does not cover the ancestor project',
      );
    });

    test('the strongest of several applicable shares wins', () async {
      // dave is a viewer on the project but an editor on one item; on that item
      // the stronger (editor) role must win.
      final resolver = buildResolver(
        shares: [
          ...demoShares(),
          shareDelegation(
            delegator: alice,
            delegate: dave,
            resourceKey: ResourceRoleKeys.project('1'),
            role: ProjectRole.viewer,
          ),
          shareDelegation(
            delegator: alice,
            delegate: dave,
            resourceKey: ResourceRoleKeys.item('1'),
            role: ProjectRole.editor,
          ),
        ],
      );
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.item,
          resourceId: 1,
        ),
        ProjectRole.editor,
      );
    });

    test('an unknown stored role token degrades to viewer', () async {
      final resolver = buildResolver(
        shares: [
          ...demoShares(),
          TomPrincipalDelegation(
            mode: TomDelegationMode.share.name,
            delegatorId: '$alice',
            delegateId: '$dave',
            resourceKey: ResourceRoleKeys.project('1'),
            role: 'not-a-role',
          ),
        ],
      );
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        ProjectRole.viewer,
      );
    });
  });

  group('no access', () {
    test('a stranger (no ownership, no share) resolves to null', () async {
      final resolver = buildResolver();
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.item,
          resourceId: 1,
        ),
        isNull,
      );
      expect(
        await resolver.resolveRole(
          userId: dave,
          resourceType: AppResourceTypes.workspace,
          resourceId: 1,
        ),
        isNull,
      );
    });
  });
}
