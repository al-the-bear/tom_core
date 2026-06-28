/// Database-free unit tests for the resource-access resolver (step 17): the
/// ownership-or-share rule is pure over the [AppResourceStore] seam, so it
/// verifies against a seeded [InMemoryAppResourceStore] with no server or
/// MariaDB.
///
/// The seed mirrors the §A.10 demo data: workspace 1 owned by alice (auth user
/// 2), a project 1 with two lists and an item, and two shares — bob (3) as
/// `editor` and carol (4) as `viewer` on the project. The records are plain
/// classes, so no reflection setup is needed.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int alice = 2;
const int bob = 3;
const int carol = 4;
const int dave = 99; // a stranger — grantee of no share, owner of nothing.

/// Builds the demo store: workspace 1 (owner alice) → project 1 → lists 1,2;
/// item 1 in list 1; bob shares as editor and carol as viewer on the project.
InMemoryAppResourceStore demoStore({List<ShareRecord> extraShares = const []}) {
  return InMemoryAppResourceStore(
    workspaces: [WorkspaceRecord()..id = 1..ownerId = alice],
    projects: [ProjectRecord()..id = 1..workspaceId = 1],
    lists: [
      ListRecord()..id = 1..projectId = 1,
      ListRecord()..id = 2..projectId = 1,
    ],
    items: [ItemRecord()..id = 1..listId = 1],
    shares: [
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
      ...extraShares,
    ],
  );
}

void main() {
  final resolver = ResourceAccessResolver(demoStore());

  group('ownership', () {
    test('the workspace owner resolves to owner on the workspace itself', () async {
      expect(
        await resolver.resolveRole(
          userId: alice,
          resourceType: AppResourceTypes.workspace,
          resourceId: 1,
        ),
        ProjectRole.owner,
      );
    });

    test('ownership flows down the chain to project, list, and item', () async {
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
    test('a grantee resolves to the shared role on the shared resource', () async {
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
    });

    test('a share on a project covers its lists and items (descendants)', () async {
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
    });

    test('a share does not flow upward to an ancestor', () async {
      // A share on item 1 only — it must NOT grant access to the parent project.
      final resolver = ResourceAccessResolver(demoStore(extraShares: [
        ShareRecord()
          ..id = 3
          ..resourceType = AppResourceTypes.item
          ..resourceId = 1
          ..granteeUserId = dave
          ..projectRole = ProjectRole.editor.name
          ..grantedById = alice,
      ]));
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
      final resolver = ResourceAccessResolver(demoStore(extraShares: [
        ShareRecord()
          ..id = 3
          ..resourceType = AppResourceTypes.project
          ..resourceId = 1
          ..granteeUserId = dave
          ..projectRole = ProjectRole.viewer.name
          ..grantedById = alice,
        ShareRecord()
          ..id = 4
          ..resourceType = AppResourceTypes.item
          ..resourceId = 1
          ..granteeUserId = dave
          ..projectRole = ProjectRole.editor.name
          ..grantedById = alice,
      ]));
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
      final resolver = ResourceAccessResolver(demoStore(extraShares: [
        ShareRecord()
          ..id = 3
          ..resourceType = AppResourceTypes.project
          ..resourceId = 1
          ..granteeUserId = dave
          ..projectRole = 'not-a-role'
          ..grantedById = alice,
      ]));
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
