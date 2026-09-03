/// End-to-end cross-tier integration test: the whole stack — both servers and
/// both databases — exercised through the real client tier in one scripted
/// scenario, then the live-DB ownership-grant and share-delegation
/// authorization checks over the same stack.
///
/// [TC-37-01] walks the two authorization mechanisms that span the tiers:
///
///  1. **An admin grant edit changes what the end-user may write.** The `admin`
///     edits the `viewer` role's `todo.item.title` grant through the auth
///     server's `/admin/grants`; `carol` (a seeded `viewer` on project 1) is
///     first refused a title write (the field is graded `read`), then — after the
///     admin regrades `title` to `full` — the *same* write succeeds. This proves
///     the app server's field-grade enforcement reads the very rows the auth
///     server's admin API writes (the app server's `main` datasource points at
///     `auth_db`, read-only): a live admin edit is immediately observable in the
///     end-user's write authorization. (The read side — a principal's
///     **resourceRoles** driving what it may *see* — is [TC-37-06].)
///  2. **A share lets a second user see a project.** `alice` (workspace owner)
///     creates a fresh project, `bob` cannot list it, `alice` shares it with
///     `bob` as `editor`, and `bob` then lists it — the ownership-or-share
///     resolver in action over the live wire.
///
/// **The live-DB ownership/share checks folded onto the same stack.** Each is an
/// independent, health-gated test that skips when the stack is down (like
/// TC-37-01), so the socket-free unit suites keep the always-on coverage and
/// these prove the live path when an operator brings the stack up via
/// `tool/run_cross_tier_integration.sh`:
///
///  - [TC-37-02] **row-scope reads are filtered.** Workspace reads are
///    owner-scoped (`@TomDbScope(field: 'ownerId')`): `alice` (owner of workspace 1)
///    lists it, `bob` (not the owner) does not — the DB row scope and the
///    service filter agree, so a non-owner never sees another principal's
///    workspace.
///  - [TC-37-03] **a delegation grants, then withholds.** The seeded
///    `share`-mode delegation (id 1: `bob` → `editor` on project 1) makes
///    project 1 visible to `bob`; `alice` (the owner) revokes it and `bob` loses
///    the project; the share is restored so the run stays re-runnable.
///  - [TC-37-04] **a write to a viewer resource is rejected.** `carol` (a
///    `viewer` on project 1) changes item 1's `title` — a field her role grades
///    `read`, not `full` — and the app server rejects the write field-by-field
///    (`app.item.field_forbidden`, HTTP 403).
///  - [TC-37-05] **a second user's WRITE/DELETE of another principal's row is
///    rejected at the service layer.** `carol` (a `viewer`, below `editor`) tries
///    to delete `alice`'s item 1 and is denied (`app.access.forbidden`, HTTP 403)
///    — the reachable live counterpart of the connection-free write-scope
///    tests. This is the *service-layer* rejection (the item write is gated by the
///    role/field-grade check before it reaches the DB scope); the *framework's*
///    own `TomDataScopeAuthorizationException` — thrown by the CRUD repository on a
///    `@TomDbScope` row write — is the distinct live check in [TC-37-08].
///  - [TC-37-06] **the live resource-role map reflects ownership and shares.**
///    `alice` reads `GET /resource-roles` and holds `owner` over her
///    workspace's project and items (an ownership grant expanded down the
///    containment chain); `bob` holds only `editor` over the shared project's
///    subtree (the seeded share) and no workspace role — the same map the
///    app client installs as its exact-match resource-role adapter.
///  - [TC-37-07] **the DB-side union scope reaches a shared subtree at the item
///    level.** The project/list/item reads are filtered at `app_db` by the
///    async union scope `(id IN (owned…) OR id IN (shared…))` on the
///    surrogate `id`. `bob`, whose only grant is an `editor` share on project
///    1, walks project → list → item to the shared item — proof the shared
///    disjunct expands *down* the containment chain at the database (not merely
///    in the service filter). The revoke-side negative is covered at the project
///    level by [TC-37-03], so this check asserts only the positive item-level
///    reach and stays independent of that test's share id.
///  - [TC-37-08] **the framework's `@TomDbScope` write-scope exception fires
///    live.** `WorkspaceRecord` is owner-scoped (`@TomDbScope(field: 'ownerId')`)
///    and has a client write path (create/update/delete). `bob` creates his
///    own workspace (owner-by-construction — the create stamps `ownerId` to his id
///    and records the ownership grant) and renames it (an owner update succeeds),
///    then tries to update *and* delete `alice`'s workspace 1: both are rejected
///    with HTTP 403 carrying the framework key `data_scope.write.out_of_scope`.
///    This is the CRUD repository's `TomDataScopeAuthorizationException` — the
///    non-owner's `save`/`deleteById` scope-filters the target row to null and the
///    repository refuses the write — mapped to 403 by the app server's
///    `appForbiddenOrNotFound`. It is the live end-to-end counterpart to
///    TC-37-05, whose rejection is only the service-layer `app.access.forbidden`.
///  - [TC-37-09] **the admin grant edit reaches the *file* endpoint too.** The
///    admin narrows the `owner` role's `todo.item.attachment` grade from `full`
///    to `read`; `alice`, who owns item 1, keeps the download and loses the
///    upload (HTTP 403); restoring the grade restores the upload. This is beat 1
///    of TC-37-01 applied to bytes instead of a form field, and it is what makes
///    the file feature part of this sample's thesis rather than a feature demo:
///    the same table, the same admin API, the same console screen, resolved per
///    row at the file endpoint. The role-relative half (a `viewer` downloads and
///    is refused the upload) is asserted by `file_transfer_integration_test.dart`
///    TC-FT-05; this test asserts the *editability* half.
///  - [TC-37-10] **the item's two child collections cross principals.** `alice`
///    (the owner) appends to item 1's comment thread; `bob`, whose only grant is
///    the seeded `editor` **share** on project 1, reads that history back and
///    appends a checklist step (server-owned `position`, so it lands one past
///    the tail whatever the client sent) and ticks it; `carol`, a `viewer` on
///    the same project, reads the thread she may not extend and is refused both
///    writes. This pins the one-step-apart gating the two collections carry — a
///    comment is *about* an item (`commenter` and above), a subtask is *part of*
///    it (`editor` and above) — which is only observable when more than one
///    principal touches the same item, and it proves the share reaches the child
///    collections down the containment chain, not just the item row.
///
/// **Why the grant edit writes the whole `viewer` row.** `adminPutGrants`
/// replaces grants *per role* (`replaceGrantsForRole`), so a partial row would
/// drop the keys it omits. Rather than read-modify-write the matrix, the test
/// posts the complete intended `viewer` row (the seeded grant matrix with just
/// `title` flipped — see [_seededRow]); that preserves the role's other seven graded
/// keys and keeps the scenario independent of whatever else the matrix holds.
/// The test normalises
/// `title` to `read` first (carol's write is rejected), regrades it to `full`
/// (the same write now succeeds), and restores it to `read` in `finally`, so it
/// leaves `auth_db` exactly as seeded and is re-runnable. carol's successful
/// write mutates item 1's title in `app_db`; that is harmless (no later check
/// asserts the title value) and the integration script's fresh-seeded volume
/// resets it every run.
///
/// **Identity sequencing.** [TomBearerAuthentication] is a single global token
/// store, so only one principal is "logged in" at a time; the scenario re-logs
/// in before each actor's calls (every call is awaited, so the active token is
/// always the intended one).
///
/// This needs both servers *and* their databases up (see
/// `tool/run_cross_tier_integration.sh`, which boots the stack and runs this
/// suite). Because none of that is guaranteed in a headless CI/dev box, the test
/// **skips itself at runtime when a server is unreachable** (a connection
/// refusal calls [markTestSkipped] instead of failing) — the socket-free unit
/// suites carry the always-on coverage; this proves the full path end-to-end
/// when an operator brings the stack up.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _appBaseUri = 'http://localhost:8080';
const _authBaseUri = 'http://localhost:8081';

// Seeded principals (auth_db `[000]` seed) and the workspace/item the scenario
// touches (app_db `[000]` seed).
final _adminLogin = LoginRequest(username: 'admin', password: 'admin-pass');
final _aliceLogin = LoginRequest(username: 'alice', password: 'alice-pass');
final _carolLogin = LoginRequest(username: 'carol', password: 'carol-pass');
final _bobLogin = LoginRequest(username: 'bob', password: 'bob-pass');
const _bobUserId = '3';
const _aliceWorkspaceId = '1';
const _carolItemId = '1';
const _titleKey = 'todo.item.title';

/// Item 1's attachment slot, as `<table>/<id>/<column>` — the file column
/// TC-37-09 regrades through the admin API.
const _attachmentSlot = 'app_items/1/attachment';

// The seeded share the delegation check revokes and restores: row id 1
// in `[003]-auth_demo_seed` is alice(2) → bob(3) `editor` on `project:1`. The id
// is an explicit seed value (not an auto-increment), so it is stable across the
// fresh-seeded runs the integration script guarantees (`docker compose down -v`).
const _seededBobShareId = '1';
const _sharedProjectId = '1';

// The framework write-scope key the CRUD repository throws when a non-owner
// writes/deletes a `@TomDbScope` row (`WorkspaceRecord.ownerId`). The app
// server's `appForbiddenOrNotFound` maps `TomDataScopeAuthorizationException`
// to a 403 carrying this exact key (distinct from the service-layer
// `app.access.forbidden`). See TC-37-08.
const _dataScopeWriteKey = 'data_scope.write.out_of_scope';

void main() {
  setUpAll(initializeReflection);

  group('cross-tier scenario (live auth + app servers)', () {
    setUp(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );
    tearDown(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );

    test('TC-37-01: admin grant edit reaches the end-user write enforcement, and '
        'a share reveals a project to a second user', () async {
      // One live transport, shared by the AuthClient and both API clients (the
      // runtime wiring), closed regardless of outcome.
      final transport = IoJsonTransport();
      final authBase = Uri.parse(_authBaseUri);
      final appBase = Uri.parse(_appBaseUri);
      final auth = AuthClient(authBase, transport: transport);
      final authorized = AuthorizedHttp(transport, auth);
      final admin = AdminApiClient(authBase, authorized);
      final app = AppApiClient(appBase, authorized);

      try {
        // Health-gate the whole scenario: an unreachable app server short-circuits
        // to the skip path before any login.
        final health = await app.health();
        expect(health['status'], equals('ok'));

        // --- Beat 1: admin normalises viewer.title -> read (known baseline). ---
        await auth.login(_adminLogin);
        await admin.putGrants(_viewerRow(TomAuthState.read));

        // --- Beat 2: carol (a viewer) cannot write title while it is `read`. ---
        await auth.login(_carolLogin);
        final beforeGrant = await _findVisibleItem(app, _carolItemId);
        expect(
          beforeGrant,
          isNotNull,
          reason: 'carol (viewer) can read item 1 before attempting a write',
        );
        beforeGrant!.title.set('${beforeGrant.title.get()} (carol edit)');
        await expectLater(
          app.updateItem(beforeGrant),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.key, 'key', 'app.item.field_forbidden'),
          ),
          reason:
              'title is graded `read` for the viewer role, so the write is '
              'rejected field-by-field',
        );

        // --- Beat 3: admin grants viewer.title -> full. ---
        await auth.login(_adminLogin);
        await admin.putGrants(_viewerRow(TomAuthState.full));

        // --- Beat 4: carol re-fetches and the same title write now succeeds —
        //     the live admin edit reached the app server's field enforcement. ---
        await auth.login(_carolLogin);
        final afterGrant = await _findVisibleItem(app, _carolItemId);
        expect(afterGrant, isNotNull);
        final editedTitle = '${afterGrant!.title.get()} (carol edit)';
        final saved = await app.updateItem(afterGrant..title.set(editedTitle));
        expect(
          saved.title.get(),
          equals(editedTitle),
          reason:
              'the admin regrade to `full` lets carol write the field the '
              'app server previously refused',
        );

        // --- Beat 5: alice creates a fresh project in her workspace. ---
        await auth.login(_aliceLogin);
        final created = await app.createProject(
          Project()
            ..workspaceId.set(_aliceWorkspaceId)
            ..name.set('Cross-tier integration project')
            ..description.set('Created by the cross-tier integration test.')
            ..colour.set('#3366cc')
            ..archived.set(false),
        );
        final newProjectId = created.id.get();
        expect(newProjectId, isNotEmpty);

        // --- Beat 6: bob cannot see the new project yet. ---
        await auth.login(_bobLogin);
        final before = await app.listProjects(_aliceWorkspaceId);
        expect(
          before.where((p) => p.id.get() == newProjectId),
          isEmpty,
          reason: 'bob has no access to the project before the share',
        );

        // --- Beat 7: alice shares the project with bob as an editor. ---
        await auth.login(_aliceLogin);
        await app.share(
          ShareRequest(
            resourceType: 'project',
            resourceId: newProjectId,
            granteeUserId: _bobUserId,
            projectRole: ProjectRole.editor,
          ),
        );

        // --- Beat 8: bob now sees the shared project. ---
        await auth.login(_bobLogin);
        final after = await app.listProjects(_aliceWorkspaceId);
        expect(
          after.where((p) => p.id.get() == newProjectId),
          isNotEmpty,
          reason: 'the share makes the project visible to bob',
        );
      } on SocketException catch (e) {
        markTestSkipped(
          'auth/app server not reachable on $_authBaseUri/$_appBaseUri — '
          'run tool/run_cross_tier_integration.sh (or start both servers + '
          'their databases) to run this end-to-end test ($e)',
        );
        return;
      } finally {
        // Restore viewer.title -> read so auth_db is left exactly as seeded; if
        // the stack is already down this is just another connection refusal.
        try {
          await auth.login(_adminLogin);
          await admin.putGrants(_viewerRow(TomAuthState.read));
        } on SocketException {
          // Servers unreachable — nothing to restore.
        } finally {
          transport.close();
        }
      }
    });

    // --- Live-DB ownership-grant and share-delegation checks, same stack. -----

    test('TC-37-02: row-scope reads are filtered — a non-owner never sees '
        "another principal's workspace (@TomDbScope)", () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // alice owns workspace 1 — the owner scope lets it through.
        await c.auth.login(_aliceLogin);
        final aliceWorkspaces = await c.app.listWorkspaces();
        expect(
          aliceWorkspaces.map((w) => w.id.get()),
          contains(_aliceWorkspaceId),
          reason: 'the owner sees her own workspace',
        );

        // bob owns no workspace — the owner scope filters alice's out. bob is a
        // seeded share on project 1, but a share never targets or flows up to a
        // workspace, so the row scope hides it.
        await c.auth.login(_bobLogin);
        final bobWorkspaces = await c.app.listWorkspaces();
        expect(
          bobWorkspaces.map((w) => w.id.get()),
          isNot(contains(_aliceWorkspaceId)),
          reason: 'the workspace owner scope hides a non-owner',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test('TC-37-03: a delegation grants, then withholds — revoking the seeded '
        'share removes the grantee\'s access', () async {
      final c = _liveClients();
      var revoked = false;
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // Grant (seeded, active): bob sees project 1 through the editor share.
        await c.auth.login(_bobLogin);
        expect(
          await _canSeeProject(c.app, _sharedProjectId),
          isTrue,
          reason: 'the seeded share grants bob the project',
        );

        // Withhold: alice (the owner) revokes the seeded delegation.
        await c.auth.login(_aliceLogin);
        await c.app.revokeShare(_seededBobShareId);
        revoked = true;

        // bob's only path to project 1 was that share — it is now gone.
        await c.auth.login(_bobLogin);
        expect(
          await _canSeeProject(c.app, _sharedProjectId),
          isFalse,
          reason: 'revoking the delegation withholds bob the project',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        // Restore bob's access so the run leaves the shared grant in place (a
        // fresh row id; the fresh-seeded next run resets it regardless).
        if (revoked) {
          try {
            await c.auth.login(_aliceLogin);
            await c.app.share(
              ShareRequest(
                resourceType: 'project',
                resourceId: _sharedProjectId,
                granteeUserId: _bobUserId,
                projectRole: ProjectRole.editor,
              ),
            );
          } on SocketException {
            // Servers unreachable — nothing to restore.
          }
        }
        c.transport.close();
      }
    });

    test('TC-37-04: a write to a viewer resource is rejected — carol cannot '
        'change a field her role only reads', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        await c.auth.login(_carolLogin);
        // A faithful baseline: fetch the stored item, flip only its title (a
        // field the `viewer` role grades `read`, not `full`).
        final stored = await _findVisibleItem(c.app, _carolItemId);
        expect(
          stored,
          isNotNull,
          reason: 'carol (viewer) can read item 1 before attempting a write',
        );
        stored!.title.set('${stored.title.get()} (carol edit)');

        await expectLater(
          c.app.updateItem(stored),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.key, 'key', 'app.item.field_forbidden'),
          ),
          reason: 'a below-`full` field write is rejected field-by-field',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test("TC-37-05: a second user's delete of another principal's row is "
        'rejected (write-scope counterpart)', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // carol is a `viewer` on project 1 — below the `editor` a delete needs —
        // so deleting alice's item 1 is denied. The row is not carol's to mutate.
        await c.auth.login(_carolLogin);
        await expectLater(
          c.app.deleteItem(EntityIdRequest(id: _carolItemId)),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.key, 'key', 'app.access.forbidden'),
          ),
          reason: 'a non-editor may not delete another principal\'s item',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test(
      'TC-37-06: the live resource-role map reflects ownership and shares',
      () async {
        final c = _liveClients();
        try {
          expect((await c.app.health())['status'], equals('ok'));

          // alice owns workspace 1 (an ownership grant); the app server's
          // `/resource-roles` expands it down the containment chain, so she holds
          // `owner` on the project and its items — the surrogate ids the live
          // entities carry, so `item:1`/`project:1` match the client's lookups.
          await c.auth.login(_aliceLogin);
          final aliceRoles = await c.app.resourceRoles();
          expect(
            aliceRoles[ResourceRoleKeys.project('1')],
            ProjectRole.owner.name,
          );
          expect(
            aliceRoles[ResourceRoleKeys.item('1')],
            ProjectRole.owner.name,
          );

          // bob holds only the seeded `editor` share on project 1 — no
          // ownership — so his map grades the project subtree `editor` and never
          // reaches the workspace (a share does not flow up).
          await c.auth.login(_bobLogin);
          final bobRoles = await c.app.resourceRoles();
          expect(
            bobRoles[ResourceRoleKeys.project('1')],
            ProjectRole.editor.name,
          );
          expect(bobRoles[ResourceRoleKeys.item('1')], ProjectRole.editor.name);
          expect(
            bobRoles.containsKey(ResourceRoleKeys.workspace('1')),
            isFalse,
          );
        } on SocketException catch (e) {
          markTestSkipped(_skipMessage(e));
          return;
        } finally {
          c.transport.close();
        }
      },
    );

    test(
      'TC-37-07: the DB-side union scope reaches a shared subtree at the item '
      'level — a share-only user lists the shared project\'s descendant item',
      () async {
        final c = _liveClients();
        try {
          expect((await c.app.health())['status'], equals('ok'));

          // bob's only grant is an active `editor` share on project 1 (the seeded
          // delegation, or TC-37-03's identical restored replacement — either way
          // an editor share on project 1). The project/list/item reads are
          // filtered at app_db by the async union scope `(id IN (owned…) OR id
          // IN (shared…))` on the surrogate `id`, so bob
          // reaching item 1 — a grandchild of the shared project, which he does
          // not own and was never directly shared — proves the shared disjunct
          // expands *down* the containment chain (project → list → item) at the
          // database, not merely in the service filter.
          //
          // The negative (revoking the share hides the subtree) is covered at the
          // project level by TC-37-03; the item-level negative follows by the same
          // containment, so this check asserts only the positive reach and stays
          // independent of TC-37-03's revoke/restore of the seeded share id.
          await c.auth.login(_bobLogin);
          expect(
            await _canSeeProject(c.app, _sharedProjectId),
            isTrue,
            reason: 'the active editor share makes the shared project visible',
          );
          final sharedItem = await _findVisibleItem(c.app, _carolItemId);
          expect(
            sharedItem,
            isNotNull,
            reason:
                'the DB list/item union scope reaches the shared subtree, '
                'so bob lists the item under the shared project',
          );
        } on SocketException catch (e) {
          markTestSkipped(_skipMessage(e));
          return;
        } finally {
          c.transport.close();
        }
      },
    );

    test("TC-37-08: a non-owner's workspace UPDATE/DELETE raises the framework "
        'TomDataScopeAuthorizationException (scoped-entity write)', () async {
      // The one client write path onto a `@TomDbScope` entity. `WorkspaceRecord`
      // carries `@TomDbScope(field: 'ownerId')`, so an update/delete of a
      // workspace the caller does not own is rejected by the framework CRUD
      // repository *before any statement runs* — the literal
      // `TomDataScopeAuthorizationException`, mapped by the app server to a 403
      // carrying its own `data_scope.write.out_of_scope` key (distinct from the
      // service-layer `app.access.forbidden` TC-37-05 asserts). This is the live
      // end-to-end reach of the connection-free framework write-scope tests.
      final c = _liveClients();
      String? bobWorkspaceId;
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // Positive create: bob makes his own workspace and becomes its owner
        // (the `ownerId` column plus the ownership grant); the insert-scope
        // check permits a row scoped to his own id.
        await c.auth.login(_bobLogin);
        final created = await c.app.createWorkspace(
          Workspace()..name.set('Bob cross-tier workspace'),
        );
        bobWorkspaceId = created.id.get();
        expect(bobWorkspaceId, isNotEmpty);
        expect(
          created.ownerId.get(),
          _bobUserId,
          reason: 'the creator is stamped as the workspace owner',
        );

        // Positive owner update: bob renames his own workspace — the write-scope
        // permits a row within his owner-scope.
        final renamed = await c.app.updateWorkspace(
          created..name.set('Bob renamed'),
        );
        expect(renamed.name.get(), 'Bob renamed');

        // Negative update: bob updates alice's seeded workspace 1, which he does
        // not own — the framework write-scope rejects it with its own key.
        await expectLater(
          c.app.updateWorkspace(
            Workspace()
              ..id.set(_aliceWorkspaceId)
              ..name.set('hijack'),
          ),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.key, 'key', _dataScopeWriteKey),
          ),
          reason: 'a non-owner may not update a @TomDbScope workspace row',
        );

        // Negative delete: the same framework rejection on the delete path.
        await expectLater(
          c.app.deleteWorkspace(EntityIdRequest(id: _aliceWorkspaceId)),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.key, 'key', _dataScopeWriteKey),
          ),
          reason: 'a non-owner may not delete a @TomDbScope workspace row',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        // Owner delete (also the positive delete-path proof): bob removes his own
        // workspace, leaving app_db as seeded. A fresh-seeded next run resets it
        // regardless, so a failure here never blocks re-runs.
        if (bobWorkspaceId != null && bobWorkspaceId.isNotEmpty) {
          try {
            await c.auth.login(_bobLogin);
            await c.app.deleteWorkspace(EntityIdRequest(id: bobWorkspaceId));
          } on SocketException {
            // Servers unreachable — nothing to clean up.
          }
        }
        c.transport.close();
      }
    });

    test('TC-37-09: an admin grant edit reaches the file endpoint — narrowing '
        "the owner's attachment grade takes away her upload", () async {
      // The file step of the cross-tier loop, and the reason the file feature
      // belongs in *this* sample rather than in a framework example: the grade
      // that decides whether bytes may be written is not a file-specific
      // permission model but the very `tom_resource_grant` row TC-37-01 edits
      // for a form field, through the same admin API and the same console
      // screen. The app server resolves it per row at the file endpoint, so an
      // administrator narrowing one cell changes what an *owner* may do with her
      // own attachment — without a redeploy, a restart, or a line of code.
      final c = _liveClients();
      final files = ioFileTransferClient(Uri.parse(_appBaseUri));
      var uploaded = false;
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // --- Beat 1: admin normalises owner.attachment -> full (the seed). ---
        await c.auth.login(_adminLogin);
        await c.admin.putGrants(_ownerRow(TomAuthState.full));

        // --- Beat 2: alice owns item 1 and may write its attachment. ---
        await c.auth.login(_aliceLogin);
        final bytes = utf8.encode('uploaded while the owner was graded full');
        final stored = await files.upload(
          slot: _attachmentSlot,
          source: TomFileSource.bytes(
            'cross-tier.txt',
            bytes,
            mediaType: 'text/plain',
          ),
        );
        uploaded = true;
        expect(stored.byteCount, equals(bytes.length));

        // --- Beat 3: admin narrows owner.attachment -> read. ---
        await c.auth.login(_adminLogin);
        await c.admin.putGrants(_ownerRow(TomAuthState.read));

        // --- Beat 4: the same principal, the same row, the same slot — the
        //     download still works and the upload is now refused. ---
        await c.auth.login(_aliceLogin);
        expect(
          await _downloadAll(files, _attachmentSlot),
          equals(bytes),
          reason:
              'a read grade still serves the file — the edit took away '
              'the write, not the row',
        );
        await expectLater(
          files.upload(
            slot: _attachmentSlot,
            source: TomFileSource.bytes('denied.txt', utf8.encode('nope')),
          ),
          throwsA(
            isA<TomFileTransferException>().having(
              (e) => e.parameters?['statusCode'],
              'statusCode',
              403,
            ),
          ),
          reason:
              'the admin edit reached the file endpoint: the owner of the '
              'item may no longer replace its attachment',
        );

        // --- Beat 5: restore the grade and the upload works again, proving
        //     beat 4's refusal was the grant row and nothing else. ---
        await c.auth.login(_adminLogin);
        await c.admin.putGrants(_ownerRow(TomAuthState.full));
        await c.auth.login(_aliceLogin);
        final again = await files.upload(
          slot: _attachmentSlot,
          source: TomFileSource.bytes(
            'restored.txt',
            utf8.encode('and again once the grade came back'),
          ),
        );
        expect(again.key, isNotEmpty);
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        try {
          // Leave both databases as seeded: the grant row back at `full`, the
          // slot empty. Order matters — the clear needs the restored grade.
          await c.auth.login(_adminLogin);
          await c.admin.putGrants(_ownerRow(TomAuthState.full));
          if (uploaded) {
            await c.auth.login(_aliceLogin);
            await files.remove(_attachmentSlot);
          }
        } on SocketException {
          // Servers unreachable — nothing to restore.
        } finally {
          files.close();
          c.transport.close();
        }
      }
    });

    test('TC-37-10: the item thread and checklist cross principals — an owner '
        'comments, a share-only user reads the history and appends a step, and '
        'a viewer may do neither', () async {
      // The two child collections of an item, live. They are gated one step
      // apart on purpose — a comment is *about* an item (commenter and above),
      // a subtask is *part of* it (editor and above) — and that difference is
      // only observable when more than one principal touches the same item, so
      // it is asserted here rather than in a socket-free unit test.
      //
      // Re-runnable without a reseed: both writes append and every assertion is
      // relative (the tail of the list, one position past the previous tail),
      // so a second run against the same volume passes with the rows the first
      // one left. Neither collection has a client delete path, so there is
      // nothing to restore — the integration script's fresh volume resets them.
      final c = _liveClients();
      final marker = 'cross-tier comment ${DateTime.now().toIso8601String()}';
      final item = EntityIdRequest(id: _carolItemId);
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // --- Beat 1: alice owns item 1 and appends to its thread. ---
        await c.auth.login(_aliceLogin);
        final posted = await c.app.addComment(
          TodoComment()
            ..itemId.set(_carolItemId)
            ..body.set(marker),
        );
        expect(posted.id.get(), isNotEmpty);
        expect(posted.body.get(), marker);

        // --- Beat 2: bob, whose only grant is the seeded editor *share* on
        //     project 1, reads the same thread. The history he sees is not his
        //     own: it carries the seeded comment authored by him and alice's
        //     new one, oldest first, so the share reaches the child collection
        //     down the containment chain exactly as it reaches the item. ---
        await c.auth.login(_bobLogin);
        final thread = await c.app.listComments(item);
        expect(
          thread.map((comment) => comment.body.get()),
          contains(marker),
          reason: "the share reveals another principal's comment",
        );
        expect(
          thread.last.body.get(),
          marker,
          reason: 'the thread is oldest first, so the newest is last',
        );

        // --- Beat 3: the same share-only user appends a checklist step. The
        //     server owns `position`, so the new step lands one past the
        //     current tail rather than wherever the client guessed. ---
        final before = await c.app.listSubtasks(item);
        expect(before, isNotEmpty, reason: 'the seed gives item 1 two steps');
        final step = await c.app.addSubtask(
          Subtask()
            ..itemId.set(_carolItemId)
            ..title.set('Verify the cross-tier loop')
            ..position.set(99), // ignored — the server appends
        );
        final after = await c.app.listSubtasks(item);
        expect(after, hasLength(before.length + 1));
        expect(after.last.id.get(), step.id.get());
        expect(after.last.title.get(), 'Verify the cross-tier loop');
        expect(
          after.last.position.get(),
          before.last.position.get() + 1,
          reason: 'the step appended, one past the previous tail',
        );

        // --- Beat 4: bob ticks his own step — the editor-and-above update
        //     path, and the one write the checklist screen performs most. ---
        final ticked = await c.app.updateSubtask(step..done.set(true));
        expect(ticked.done.get(), isTrue);

        // --- Beat 5: carol is a `viewer` on the same project. She reads the
        //     history she may not add to (the thread is gated by the *item's*
        //     readability, not by the commenter role) and is refused both
        //     writes — the comment because a viewer is below `commenter`, the
        //     step because she is below `editor`. ---
        await c.auth.login(_carolLogin);
        expect(
          (await c.app.listComments(item)).map((cm) => cm.body.get()),
          contains(marker),
          reason: 'a viewer sees the history she may not extend',
        );
        expect(await c.app.listSubtasks(item), hasLength(after.length));

        await expectLater(
          c.app.addComment(
            TodoComment()
              ..itemId.set(_carolItemId)
              ..body.set('viewer comment'),
          ),
          throwsA(
            isA<AppApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
          reason: 'a viewer is below the commenter gate',
        );
        await expectLater(
          c.app.addSubtask(
            Subtask()
              ..itemId.set(_carolItemId)
              ..title.set('viewer step'),
          ),
          throwsA(
            isA<AppApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
          reason: 'a viewer is below the editor gate the checklist needs',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });
  });
}

/// Every byte [slot] serves, or `null` when the slot holds no file.
Future<List<int>?> _downloadAll(
  TomFileTransferClient files,
  String slot,
) async {
  final received = <int>[];
  try {
    await for (final chunk in files.download(slot)) {
      received.addAll(chunk);
    }
  } on TomFileTransferException catch (e) {
    if (e.key == 'file_transfer.not_found') return null;
    rethrow;
  }
  return received;
}

/// One live transport plus the auth/admin/app clients that share it — the
/// runtime wiring each authorization check builds (and closes) independently.
({
  IoJsonTransport transport,
  AuthClient auth,
  AdminApiClient admin,
  AppApiClient app,
})
_liveClients() {
  final transport = IoJsonTransport();
  final authBase = Uri.parse(_authBaseUri);
  final appBase = Uri.parse(_appBaseUri);
  final auth = AuthClient(authBase, transport: transport);
  final authorized = AuthorizedHttp(transport, auth);
  return (
    transport: transport,
    auth: auth,
    admin: AdminApiClient(authBase, authorized),
    app: AppApiClient(appBase, authorized),
  );
}

/// The uniform skip message when the live stack is unreachable at test time.
String _skipMessage(SocketException e) =>
    'auth/app server not reachable on $_authBaseUri/$_appBaseUri — run '
    'tool/run_cross_tier_integration.sh (or start both servers + their '
    'databases) to run this end-to-end test ($e)';

/// Whether the logged-in principal can currently see project [projectId] in
/// alice's workspace — the visibility the share grants and the revoke withholds.
Future<bool> _canSeeProject(AppApiClient app, String projectId) async {
  final projects = await app.listProjects(_aliceWorkspaceId);
  return projects.any((p) => p.id.get() == projectId);
}

/// The stored [itemId] as the logged-in principal sees it, walking the visible
/// project → list → item chain in alice's workspace, or `null` when unreachable.
Future<TodoItem?> _findVisibleItem(AppApiClient app, String itemId) async {
  for (final project in await app.listProjects(_aliceWorkspaceId)) {
    for (final list in await app.listLists(project.id.get())) {
      for (final item in await app.listItems(list.id.get())) {
        if (item.id.get() == itemId) return item;
      }
    }
  }
  return null;
}

/// The complete `viewer` row as seeded, with `title` set to [title].
GrantMatrixDto _viewerRow(TomAuthState title) =>
    _seededRow(ProjectRole.viewer, overrides: {_titleKey: title});

/// The complete `owner` row as seeded, with the item's **file column** graded
/// [attachment] — the one cell TC-37-09 moves, so the owner's seven fields stay
/// exactly as seeded and the beat under test is the file grade alone.
GrantMatrixDto _ownerRow(TomAuthState attachment) => _seededRow(
  ProjectRole.owner,
  overrides: {itemAttachmentGradeKey: attachment},
);

/// [role]'s complete row of the grant matrix — its eight graded keys at the
/// values `[003]-auth_demo_seed@dev,test.sql` seeds — with [overrides] applied.
///
/// Posting the whole row (not just the one cell under test) is forced by the
/// API: `adminPutGrants` replaces a role's grants wholesale
/// (`replaceGrantsForRole`), so a partial row would drop the keys it omits. The
/// **attachment** grant is part of that row and must be posted with it —
/// omitting it would silently revoke the role's file access, leaving carol
/// graded `none` and refused even the download TC-FT-05 asserts she gets, in a
/// suite that never mentions files.
///
/// The seeded values are read from the shared domain maps rather than re-typed
/// here. The seed and the domain maps are pinned equal by
/// `advanced_auth_server/test/grant_matrix_key_consistency_test.dart`, so this
/// really is "the row as seeded" — and a future regrade of the seed reaches this
/// test automatically instead of leaving it restoring stale values in `finally`.
GrantMatrixDto _seededRow(
  ProjectRole role, {
  required Map<String, TomAuthState> overrides,
}) {
  final row = <String, TomAuthState>{
    for (final key in gradableItemKeys)
      key: projectRoleFieldGrades[role]![key]!,
    itemAttachmentGradeKey: projectRoleAttachmentGrades[role]!,
    ...overrides,
  };
  return GrantMatrixDto.fromGrades({
    role.name: [
      for (final entry in row.entries)
        GradedFieldDto(resourceKey: entry.key, access: entry.value),
    ],
  });
}
