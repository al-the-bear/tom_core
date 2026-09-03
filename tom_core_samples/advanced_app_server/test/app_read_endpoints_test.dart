/// Database-free integration tests for the read endpoints (step 19, RCC3): the
/// [AppReadService] composes the step-17 [ResourceRoleResolver], so the read
/// path — visibility filtering plus the flat resource-role map the client grades
/// fields against locally (RCC2) — verifies against seeded in-memory stores with
/// no server or MariaDB.
///
/// The fixture mirrors the demo seed `[001]-app_demo_seed@dev,test.sql`
/// (workspace 1 owned by alice=2, project 1 → lists 1,2; items 1,2 in list 1),
/// with bob=3 shared `editor` and carol=4 shared `viewer` on the project. RCC3 expresses ownership as a C-5 owner grant (RCC1)
/// and each share as a C-6 `share`-mode [TomPrincipalDelegation], folded by the
/// framework resolver into the effective roles the containment rule then walks.
/// The step-19 "Done" bar is the headline pair: a shared user sees the owner's
/// project, a stranger does not.
///
/// The list endpoints return observable domain entities (built through the
/// mapping layer), so the registry must be live before they run; the grant and
/// delegation rows and the persistence records are plain classes and need no
/// reflection.
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
const int dave = 99; // stranger — grantee of no share, owner of nothing

// The demo seed's records (`[001]-app_demo_seed@dev,test.sql`). Fresh instances
// per call so the resource store and the read store hold independent (but
// equal) copies.
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
        resourceKey: ResourceRoleKeys.workspace('1'),
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
        resourceKey: ResourceRoleKeys.project('1'),
        role: ProjectRole.editor.name,
      ),
      TomPrincipalDelegation(
        mode: TomDelegationMode.share.name,
        delegatorId: '$alice',
        delegateId: '$carol',
        resourceKey: ResourceRoleKeys.project('1'),
        role: ProjectRole.viewer.name,
      ),
    ];

/// The framework resolver folding the demo ownership grants and share
/// delegations into the effective `resourceKey → roleName` map.
ResourceRoleResolver demoResolver() => resolverOver(demoItems());

/// The demo resolver over an explicit item set, so a fixture that needs an extra
/// row (the attachment group below) still resolves containment for it.
ResourceRoleResolver resolverOver(List<ItemRecord> items) => ResourceRoleResolver(
      InMemoryResourceContainmentStore(
        projects: demoProjects(),
        lists: demoLists(),
        items: items,
      ),
      TomDelegationResolver(
        InMemoryPrincipalDelegationStore(demoShares()),
        TomPrincipalResourceRoleResolver(
          InMemoryPrincipalResourceGrantStore(demoGrants()),
        ),
      ),
    );

/// The descriptor the blob store answers for item 1's attachment slot — the
/// exact shape a `HEAD app_items/1/attachment` returns.
TomFileMetadata demoAttachment() => TomFileMetadata(
      key: 'items/attachment/7f3c',
      mediaType: 'text/plain; charset=utf-8',
      byteCount: 34,
      fileName: 'notes.txt',
    );

/// The three attachment cases in one list: item 1 has a file, item 2 has none,
/// and item 3 carries a key the blob store cannot describe (a masked column, or
/// bytes that are gone). Only the first must surface a paperclip.
List<ItemRecord> attachmentItems() => [
      ItemRecord()..id = 1..listId = 1..attachment = 'items/attachment/7f3c',
      ItemRecord()..id = 2..listId = 1,
      ItemRecord()..id = 3..listId = 1..attachment = 'items/attachment/gone',
    ];

/// The read service over the attachment fixture, sharing the demo grants and
/// shares so visibility behaves exactly as in the groups above.
AppReadService attachmentService() => AppReadService(
      InMemoryAppReadStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: attachmentItems(),
        attachments: {1: demoAttachment()},
      ),
      resolverOver(attachmentItems()),
    );

/// Wires the read service over the two seeded in-memory stores.
AppReadService demoService() => AppReadService(
      InMemoryAppReadStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
      ),
      demoResolver(),
    );

/// Three comments on item 1 seeded **out of order** — the middle one first, and
/// two sharing a timestamp. Seeding out of order is the point: it is what
/// distinguishes a store that really sorts from one that merely echoes its seed.
/// The timestamp collision pins the `id` tiebreak that makes the order *total*
/// (`created_at` has second resolution in `app_comments`, so ties are ordinary,
/// not pathological).
List<CommentRecord> threadComments() => [
      CommentRecord()
        ..id = 2
        ..itemId = 1
        ..authorId = bob
        ..body = 'second'
        ..createdAt = DateTime.utc(2026, 1, 1, 12, 0, 30),
      CommentRecord()
        ..id = 3
        ..itemId = 1
        ..authorId = alice
        ..body = 'third'
        // Same second as #2: only the id tiebreak separates them.
        ..createdAt = DateTime.utc(2026, 1, 1, 12, 0, 30),
      CommentRecord()
        ..id = 1
        ..itemId = 1
        ..authorId = alice
        ..body = 'first'
        ..createdAt = DateTime.utc(2026, 1, 1, 12, 0, 0),
      // On a *different* item, to prove the read is keyed and not a full scan.
      CommentRecord()
        ..id = 4
        ..itemId = 2
        ..authorId = alice
        ..body = 'other item'
        ..createdAt = DateTime.utc(2026, 1, 1, 12, 0, 0),
    ];

/// Subtasks of item 1, likewise seeded out of `position` order and with one
/// position collision.
List<SubtaskRecord> checklistSubtasks() => [
      SubtaskRecord()
        ..id = 7
        ..itemId = 1
        ..title = 'b'
        ..done = false
        ..position = 1,
      SubtaskRecord()
        ..id = 5
        ..itemId = 1
        ..title = 'a'
        ..done = true
        ..position = 0,
      SubtaskRecord()
        ..id = 9
        ..itemId = 1
        ..title = 'c'
        ..done = false
        // Ties with #7 on position; the id breaks it.
        ..position = 1,
      SubtaskRecord()
        ..id = 11
        ..itemId = 2
        ..title = 'elsewhere'
        ..done = false
        ..position = 0,
    ];

/// The read service over the comment/subtask fixture, sharing the demo grants
/// and shares so visibility behaves exactly as in the groups above.
AppReadService threadService() => AppReadService(
      InMemoryAppReadStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
        comments: threadComments(),
        subtasks: checklistSubtasks(),
      ),
      demoResolver(),
    );

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
  });

  group('a stranger sees nothing (the step-19 Done bar)', () {
    test('every list endpoint is empty for an unshared, non-owner user', () async {
      expect(await service.listWorkspaces(dave), isEmpty);
      expect(await service.listProjects(dave, 1), isEmpty);
      expect(await service.listLists(dave, 1), isEmpty);
      expect(await service.listItems(dave, 1), isEmpty);
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
        ResourceRoleKeys.workspace('1'): ProjectRole.owner.name,
        ResourceRoleKeys.project('1'): ProjectRole.owner.name,
        ResourceRoleKeys.list('1'): ProjectRole.owner.name,
        ResourceRoleKeys.list('2'): ProjectRole.owner.name,
        ResourceRoleKeys.item('1'): ProjectRole.owner.name,
        ResourceRoleKeys.item('2'): ProjectRole.owner.name,
      });
    });

    test("the editor grantee's project share covers only the project subtree",
        () async {
      // bob is shared `editor` on project 1 — his map covers the project and
      // its lists/items, but not the workspace (a share never flows up).
      expect(await service.resourceRoles(bob), {
        ResourceRoleKeys.project('1'): ProjectRole.editor.name,
        ResourceRoleKeys.list('1'): ProjectRole.editor.name,
        ResourceRoleKeys.list('2'): ProjectRole.editor.name,
        ResourceRoleKeys.item('1'): ProjectRole.editor.name,
        ResourceRoleKeys.item('2'): ProjectRole.editor.name,
      });
    });

    test('the viewer grantee gets the viewer role over the project subtree',
        () async {
      expect(await service.resourceRoles(carol), {
        ResourceRoleKeys.project('1'): ProjectRole.viewer.name,
        ResourceRoleKeys.list('1'): ProjectRole.viewer.name,
        ResourceRoleKeys.list('2'): ProjectRole.viewer.name,
        ResourceRoleKeys.item('1'): ProjectRole.viewer.name,
        ResourceRoleKeys.item('2'): ProjectRole.viewer.name,
      });
    });

    test('a stranger holds no roles (empty map, closed/safe)', () async {
      expect(await service.resourceRoles(dave), isEmpty);
    });
  });

  // The board's paperclip source: one batched call per list rather than one
  // `HEAD` per item. The descriptors are produced by the *same* slot `describe`
  // a `HEAD` would make, so presence here and reachability over HTTP cannot
  // disagree — an item is listed only when its slot really answers.
  group('listAttachments describes only the items that have a file', () {
    final service = attachmentService();

    test('an attached item yields the slot descriptor losslessly', () async {
      final descriptors = await service.listAttachments(alice, 1);
      expect(descriptors, hasLength(1));
      expect(descriptors.single.slot, 'app_items/1/attachment');
      expect(descriptors.single.hasFile, isTrue);
      // Lossless: the DTO carries the HEAD descriptor, it does not summarise it.
      expect(descriptors.single.toMetadata(), demoAttachment());
    });

    test('an item with an empty slot is simply absent', () async {
      final descriptors = await service.listAttachments(alice, 1);
      expect(descriptors.map((d) => d.slotId), isNot(contains('2')));
    });

    test('a key the blob store cannot describe is omitted, not reported',
        () async {
      // Item 3 holds a key but describes as null (masked column or missing
      // bytes). "Absent" must mean "no paperclip" — never a broken one.
      final descriptors = await service.listAttachments(alice, 1);
      expect(descriptors.map((d) => d.slotId), isNot(contains('3')));
    });

    test('a stranger sees no descriptors (visibility is decided once)',
        () async {
      // The descriptors are derived from the already-filtered item listing, so
      // an invisible item cannot leak its attachment metadata.
      expect(await service.listAttachments(dave, 1), isEmpty);
    });

    test('a shared user sees the attachments of the shared project', () async {
      // bob is shared `editor` on project 1, so list 1's items — and therefore
      // their attachments — are his to see.
      final descriptors = await service.listAttachments(bob, 1);
      expect(descriptors.map((d) => d.slot), ['app_items/1/attachment']);
    });
  });

  // The two ordered child reads. Both are gated by the *item's* readability
  // rather than by a role of their own, so the interesting cases are the
  // ordering (which the endpoint promises) and the boundary between "empty
  // thread" and "unreachable item" — which must not look alike.
  group('listComments returns the thread of one item, oldest first', () {
    final service = threadService();

    test('the thread is ordered by creation time, not by seed order', () async {
      expect((await service.listComments(alice, 1)).map((c) => c.body.get()),
          ['first', 'second', 'third']);
    });

    test('comments on other items are not in the thread', () async {
      expect((await service.listComments(alice, 1)).map((c) => c.body.get()),
          isNot(contains('other item')));
    });

    test('an item with no comments yields an empty thread', () async {
      // Item 2 has one comment in the fixture; item 2's *own* thread is that
      // comment, so the empty case is asserted on a reachable item with none.
      final bare = AppReadService(
        InMemoryAppReadStore(
          workspaces: demoWorkspaces(),
          projects: demoProjects(),
          lists: demoLists(),
          items: demoItems(),
        ),
        demoResolver(),
      );
      expect(await bare.listComments(alice, 1), isEmpty);
    });

    test('a viewer reads the history they may not add to (C-3)', () async {
      // The step's point: read access to the *item* is the whole gate, so a
      // `viewer` share sees every comment without holding `commenter`.
      expect((await service.listComments(carol, 1)).map((c) => c.body.get()),
          ['first', 'second', 'third']);
    });

    test('a stranger is told the item does not exist, not that it is empty',
        () async {
      // Closed/safe: an empty list would confirm the item exists. `dave` is
      // shared nothing and owns nothing, so the read must reject.
      expect(
        () => service.listComments(dave, 1),
        throwsA(isA<TomException>()
            .having((e) => e.key, 'key', 'app.item.not_found')),
      );
    });
  });

  group('listSubtasks returns the checklist of one item, in position order', () {
    final service = threadService();

    test('the checklist is ordered by position, ties broken by id', () async {
      expect((await service.listSubtasks(alice, 1)).map((s) => s.title.get()),
          ['a', 'b', 'c']);
    });

    test('the done flag survives the mapping round-trip', () async {
      final checklist = await service.listSubtasks(alice, 1);
      expect(checklist.map((s) => s.done.get()), [true, false, false]);
    });

    test('subtasks of other items are not in the checklist', () async {
      expect((await service.listSubtasks(alice, 1)).map((s) => s.title.get()),
          isNot(contains('elsewhere')));
    });

    test('a viewer sees the checklist (same read gate as the thread)',
        () async {
      expect((await service.listSubtasks(carol, 1)).map((s) => s.title.get()),
          ['a', 'b', 'c']);
    });

    test('a stranger is told the item does not exist', () async {
      expect(
        () => service.listSubtasks(dave, 1),
        throwsA(isA<TomException>()
            .having((e) => e.key, 'key', 'app.item.not_found')),
      );
    });
  });
}
