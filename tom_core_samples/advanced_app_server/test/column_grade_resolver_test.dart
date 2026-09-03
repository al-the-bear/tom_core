/// Database-free unit tests for the per-row C-4 column grade
/// ([ItemAttachmentGradeResolver]): the grade the file endpoint applies to an
/// item's `attachment` is a *composition* of two layers the app server already
/// had, so it verifies over their in-memory seams with no server and no MariaDB.
///
/// This is the unit-level half of csexd13's centrepiece — *the file endpoint
/// under the existing four-role matrix*. Here the composition is pinned per role
/// (a viewer resolves `read`, an owner `full`) and at every closed-safe edge; the
/// live half, where `read` really does download and really is refused the
/// upload over HTTP, is asserted by `advanced_client_core`'s file-transfer
/// integration suite and by the cross-tier runner.
///
/// The seed mirrors the demo data exactly as `resource_role_resolver_test.dart`
/// does — alice (2) owns the tree, bob (3) is `editor` and carol (4) `viewer` on
/// project 1, dave (99) is a stranger — crossed with the seeded attachment
/// grants ([projectRoleAttachmentGrades]).
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int _alice = 2; // owns the demo tree
const int _bob = 3; // editor share on project 1
const int _carol = 4; // viewer share on project 1
const int _dave = 99; // a stranger — grantee of no share, owner of nothing

/// The containment tree the attachment grades resolve through: item 1 lives in
/// list 1, which lives in project 1, which lives in workspace 1.
InMemoryResourceContainmentStore _containment() =>
    InMemoryResourceContainmentStore(
      projects: [ProjectRecord()..id = 1..workspaceId = 1],
      lists: [ListRecord()..id = 1..projectId = 1],
      items: [ItemRecord()..id = 1..listId = 1],
    );

/// Alice's C-5 owner grant on the workspace; the containment rule flows it down
/// to the item.
List<TomPrincipalResourceGrant> _ownerGrants() => [
      TomPrincipalResourceGrant(
        principalId: '$_alice',
        resourceKey: ResourceRoleKeys.workspace('1'),
        role: ProjectRole.owner.name,
      ),
    ];

/// The two C-6 shares on project 1: bob as `editor`, carol as `viewer`.
List<TomPrincipalDelegation> _shares() => [
      for (final share in const [
        (_bob, ProjectRole.editor),
        (_carol, ProjectRole.viewer),
      ])
        TomPrincipalDelegation(
          mode: TomDelegationMode.share.name,
          delegatorId: '$_alice',
          delegateId: '${share.$1}',
          resourceKey: ResourceRoleKeys.project('1'),
          role: share.$2.name,
        ),
    ];

/// The attachment grant rows the auth seed writes, as the grant store sees them.
List<TomResourceGrant> _attachmentGrants() => [
      for (final entry in projectRoleAttachmentGrades.entries)
        TomResourceGrant(
          roleName: entry.key.name,
          resourceKey: itemAttachmentGradeKey,
          accessLevel: entry.value,
        ),
    ];

/// Builds the resolver over the seeded stores, optionally with a narrowed grant
/// matrix (the shape an administrator's console edit produces).
ItemAttachmentGradeResolver _buildResolver({List<TomResourceGrant>? grants}) {
  final roles = ResourceRoleResolver(
    _containment(),
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore(_shares()),
      TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore(_ownerGrants()),
      ),
    ),
  );
  return ItemAttachmentGradeResolver(
    roles,
    FieldGradeResolver(
      InMemoryGrantStore(grants ?? _attachmentGrants()),
      gradableItemKeys: const [itemAttachmentGradeKey],
    ),
  );
}

/// An authenticated principal for auth user [userId].
TomPrincipal _principal(int userId) => TomPrincipal(
      authenticated: true,
      user: TomUser(id: userId, username: 'user-$userId'),
    );

void main() {
  group('the attachment grade follows the role on the item', () {
    test('the owner resolves full — download and replace', () async {
      expect(
        await _buildResolver().gradeFor(_principal(_alice), 1),
        TomAuthState.full,
      );
    });

    test('an editor share resolves full through containment', () async {
      // Bob's share is on the *project*; the role resolver walks item 1's
      // ancestry up to it, and the grade follows the role it finds there.
      expect(
        await _buildResolver().gradeFor(_principal(_bob), 1),
        TomAuthState.full,
      );
    });

    test('a viewer share resolves read — the download, not the upload',
        () async {
      final grade = await _buildResolver().gradeFor(_principal(_carol), 1);
      expect(grade, TomAuthState.read);
      // Spelling out both halves, because this pair *is* the demonstration: the
      // framework reads `showsContent` in openFile/describeFile and
      // `isInteractive` in saveFile/clearFile, so one grade decides all four.
      expect(grade.showsContent, isTrue, reason: 'carol may download');
      expect(grade.isInteractive, isFalse, reason: 'carol may not upload');
    });
  });

  group('closed-safe at every edge', () {
    test('no principal resolves none', () async {
      expect(await _buildResolver().gradeFor(null, 1), TomAuthState.none);
    });

    test('a stranger with no role on the item resolves none', () async {
      expect(
        await _buildResolver().gradeFor(_principal(_dave), 1),
        TomAuthState.none,
      );
    });

    test('an unparseable row id resolves none', () async {
      expect(
        await _buildResolver().gradeFor(_principal(_alice), 'not-an-id'),
        TomAuthState.none,
      );
    });

    test('a null row id (an insert) resolves none', () async {
      // A row that does not exist yet belongs to no project, so no role can be
      // resolved for it. The sample never reaches this path — the file endpoint
      // always addresses a stored row — but the answer must still be closed.
      expect(
        await _buildResolver().gradeFor(_principal(_alice), null),
        TomAuthState.none,
      );
    });

    test('a role with no grant row for the key resolves none', () async {
      // The role is resolved (alice owns the item) but the matrix grants her
      // nothing on the attachment — the grade fold degrades to none rather than
      // defaulting open.
      final resolver = _buildResolver(grants: const []);
      expect(
        await resolver.gradeFor(_principal(_alice), 1),
        TomAuthState.none,
      );
    });
  });

  group('the grant matrix is the authority, not the code', () {
    test("narrowing owner's grant to read takes away the owner's upload",
        () async {
      // This is what an administrator does through the authadmin console: edit
      // one `tom_resource_grant` row. Nothing in the app server changes, and the
      // owner of the item can now only download its attachment. The cross-tier
      // runner performs this same edit over HTTP against the live pair.
      final resolver = _buildResolver(grants: [
        TomResourceGrant(
          roleName: ProjectRole.owner.name,
          resourceKey: itemAttachmentGradeKey,
          accessLevel: TomAuthState.read,
        ),
      ]);
      final grade = await resolver.gradeFor(_principal(_alice), 1);
      expect(grade, TomAuthState.read);
      expect(grade.isInteractive, isFalse);
    });
  });
}
