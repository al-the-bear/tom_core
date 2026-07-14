/// End-to-end cross-tier integration test (step 37, Phase 7; extended for RCC5):
/// the whole stack — both servers and both databases — exercised through the
/// real client tier in one scripted scenario, then the RCC5 live-DB C-5/C-6
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
///     `bob` as `editor`, and `bob` then lists it — the step-17 ownership-or-share
///     resolver in action over the live wire.
///
/// **RCC5 — the live-DB C-5/C-6 checks folded onto the same stack.** Each is an
/// independent, health-gated test that skips when the stack is down (like
/// TC-37-01), so the socket-free unit suites keep the always-on coverage and
/// these prove the live path when an operator brings the stack up via
/// `tool/run_cross_tier_integration.sh`:
///
///  - [TC-37-02] **row-scope reads are filtered.** RCC4 owner-scopes workspace
///    reads (`@TomDbScope(field: 'ownerId')`): `alice` (owner of workspace 1)
///    lists it, `bob` (not the owner) does not — the DB row scope and the
///    service filter agree, so a non-owner never sees another principal's
///    workspace.
///  - [TC-37-03] **a delegation grants, then withholds.** The seeded C-6
///    `share`-mode delegation (id 1: `bob` → `editor` on project 1) makes
///    project 1 visible to `bob`; `alice` (the owner) revokes it and `bob` loses
///    the project; the share is restored so the run stays re-runnable.
///  - [TC-37-04] **a write to a viewer resource is rejected.** `carol` (a
///    `viewer` on project 1) changes item 1's `title` — a field her role grades
///    `read`, not `full` — and the app server rejects the write field-by-field
///    (`app.item.field_forbidden`, HTTP 403).
///  - [TC-37-05] **a second user's WRITE/DELETE of another principal's row is
///    rejected.** `carol` (a `viewer`, below `editor`) tries to delete `alice`'s
///    item 1 and is denied (`app.access.forbidden`, HTTP 403) — the reachable
///    live counterpart of RCA4's connection-free write-scope tests. (The literal
///    `TomDataScopeAuthorizationException` fires only on a `@TomDbScope` entity's
///    write; the advanced sample scopes only `WorkspaceRecord`, which has no
///    write endpoint, so that exact exception is covered at the framework unit
///    level — see the RCC5 decision notes and RCB9.)
///  - [TC-37-06] **the live resource-role map reflects ownership and shares
///    (RCB5).** `alice` reads `GET /resource-roles` and holds `owner` over her
///    workspace's project and items (a C-5 owner grant expanded down the
///    containment chain); `bob` holds only `editor` over the shared project's
///    subtree (the seeded C-6 share) and no workspace role — the same map the
///    app client installs as its exact-match resource-role adapter (RCC2).
///  - [TC-37-07] **the DB-side union scope reaches a shared subtree at the item
///    level (RCB8).** With RCB8 the project/list/item reads are filtered at
///    `app_db` by the async union scope `(id IN (owned…) OR id IN (shared…))` on
///    the surrogate `id`. `bob`, whose only grant is an `editor` share on project
///    1, walks project → list → item to the shared item — proof the shared
///    disjunct expands *down* the containment chain at the database (not merely
///    in the service filter). The revoke-side negative is covered at the project
///    level by [TC-37-03], so this check asserts only the positive item-level
///    reach and stays independent of that test's share id.
///
/// **Why the grant edit writes the whole `viewer` row.** `adminPutGrants`
/// replaces grants *per role* (`replaceGrantsForRole`), and `adminGetGrants`
/// cannot round-trip a single DTO over the live wire yet (the kernel
/// reflection-serializer gap documented in `admin_api_client.dart`). So rather
/// than read-modify-write the matrix, the test posts the complete intended
/// `viewer` row (the §A.4 seed with just `title` flipped); that preserves the
/// other six fields and is robust to the read-back gap. The test normalises
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

// The seeded C-6 share the RCC5 delegation check revokes and restores: row id 1
// in `[003]-auth_demo_seed` is alice(2) → bob(3) `editor` on `project:1`. The id
// is an explicit seed value (not an auto-increment), so it is stable across the
// fresh-seeded runs the integration script guarantees (`docker compose down -v`).
const _seededBobShareId = '1';
const _sharedProjectId = '1';

void main() {
  setUpAll(initializeReflection);

  group('cross-tier scenario (live auth + app servers)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test(
        'TC-37-01: admin grant edit reaches the end-user write enforcement, and '
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
        expect(beforeGrant, isNotNull,
            reason: 'carol (viewer) can read item 1 before attempting a write');
        beforeGrant!.title.set('${beforeGrant.title.get()} (carol edit)');
        await expectLater(
          app.updateItem(beforeGrant),
          throwsA(isA<AppApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.key, 'key', 'app.item.field_forbidden')),
          reason: 'title is graded `read` for the viewer role, so the write is '
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
        expect(saved.title.get(), equals(editedTitle),
            reason: 'the admin regrade to `full` lets carol write the field the '
                'app server previously refused');

        // --- Beat 5: alice creates a fresh project in her workspace. ---
        await auth.login(_aliceLogin);
        final created = await app.createProject(Project()
          ..workspaceId.set(_aliceWorkspaceId)
          ..name.set('Step 37 cross-tier project')
          ..description.set('Created by the cross-tier integration test.')
          ..colour.set('#3366cc')
          ..archived.set(false));
        final newProjectId = created.id.get();
        expect(newProjectId, isNotEmpty);

        // --- Beat 6: bob cannot see the new project yet. ---
        await auth.login(_bobLogin);
        final before = await app.listProjects(_aliceWorkspaceId);
        expect(before.where((p) => p.id.get() == newProjectId), isEmpty,
            reason: 'bob has no access to the project before the share');

        // --- Beat 7: alice shares the project with bob as an editor. ---
        await auth.login(_aliceLogin);
        await app.share(ShareRequest(
          resourceType: 'project',
          resourceId: newProjectId,
          granteeUserId: _bobUserId,
          projectRole: ProjectRole.editor,
        ));

        // --- Beat 8: bob now sees the shared project. ---
        await auth.login(_bobLogin);
        final after = await app.listProjects(_aliceWorkspaceId);
        expect(after.where((p) => p.id.get() == newProjectId), isNotEmpty,
            reason: 'the share makes the project visible to bob');
      } on SocketException catch (e) {
        markTestSkipped(
            'auth/app server not reachable on $_authBaseUri/$_appBaseUri — '
            'run tool/run_cross_tier_integration.sh (or start both servers + '
            'their databases) to run this end-to-end test ($e)');
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

    // --- RCC5: live-DB C-5/C-6 authorization checks over the same stack. ------

    test(
        'TC-37-02: row-scope reads are filtered — a non-owner never sees '
        "another principal's workspace (RCC4 @TomDbScope)", () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // alice owns workspace 1 — the owner scope lets it through.
        await c.auth.login(_aliceLogin);
        final aliceWorkspaces = await c.app.listWorkspaces();
        expect(aliceWorkspaces.map((w) => w.id.get()),
            contains(_aliceWorkspaceId),
            reason: 'the owner sees her own workspace');

        // bob owns no workspace — the owner scope filters alice's out. bob is a
        // seeded share on project 1, but a share never targets or flows up to a
        // workspace, so the row scope hides it.
        await c.auth.login(_bobLogin);
        final bobWorkspaces = await c.app.listWorkspaces();
        expect(bobWorkspaces.map((w) => w.id.get()),
            isNot(contains(_aliceWorkspaceId)),
            reason: 'the workspace owner scope hides a non-owner');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test(
        'TC-37-03: a delegation grants, then withholds — revoking the seeded '
        'share removes the grantee\'s access', () async {
      final c = _liveClients();
      var revoked = false;
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // Grant (seeded, active): bob sees project 1 through the editor share.
        await c.auth.login(_bobLogin);
        expect(await _canSeeProject(c.app, _sharedProjectId), isTrue,
            reason: 'the seeded share grants bob the project');

        // Withhold: alice (the owner) revokes the seeded delegation.
        await c.auth.login(_aliceLogin);
        await c.app.revokeShare(_seededBobShareId);
        revoked = true;

        // bob's only path to project 1 was that share — it is now gone.
        await c.auth.login(_bobLogin);
        expect(await _canSeeProject(c.app, _sharedProjectId), isFalse,
            reason: 'revoking the delegation withholds bob the project');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        // Restore bob's access so the run leaves the shared grant in place (a
        // fresh row id; the fresh-seeded next run resets it regardless).
        if (revoked) {
          try {
            await c.auth.login(_aliceLogin);
            await c.app.share(ShareRequest(
              resourceType: 'project',
              resourceId: _sharedProjectId,
              granteeUserId: _bobUserId,
              projectRole: ProjectRole.editor,
            ));
          } on SocketException {
            // Servers unreachable — nothing to restore.
          }
        }
        c.transport.close();
      }
    });

    test(
        'TC-37-04: a write to a viewer resource is rejected — carol cannot '
        'change a field her role only reads', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        await c.auth.login(_carolLogin);
        // A faithful baseline: fetch the stored item, flip only its title (a
        // field the `viewer` role grades `read`, not `full`).
        final stored = await _findVisibleItem(c.app, _carolItemId);
        expect(stored, isNotNull,
            reason: 'carol (viewer) can read item 1 before attempting a write');
        stored!.title.set('${stored.title.get()} (carol edit)');

        await expectLater(
          c.app.updateItem(stored),
          throwsA(isA<AppApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.key, 'key', 'app.item.field_forbidden')),
          reason: 'a below-`full` field write is rejected field-by-field',
        );
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test(
        "TC-37-05: a second user's delete of another principal's row is "
        'rejected (write-scope counterpart)', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // carol is a `viewer` on project 1 — below the `editor` a delete needs —
        // so deleting alice's item 1 is denied. The row is not carol's to mutate.
        await c.auth.login(_carolLogin);
        await expectLater(
          c.app.deleteItem(EntityIdRequest(id: _carolItemId)),
          throwsA(isA<AppApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.key, 'key', 'app.access.forbidden')),
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
        'TC-37-06: the live resource-role map reflects ownership and shares '
        '(RCB5)', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // alice owns workspace 1 (a C-5 owner grant); the app server's
        // `/resource-roles` expands it down the containment chain, so she holds
        // `owner` on the project and its items — the surrogate ids the live
        // entities carry, so `item:1`/`project:1` match the client's lookups.
        await c.auth.login(_aliceLogin);
        final aliceRoles = await c.app.resourceRoles();
        expect(aliceRoles[ResourceRoleKeys.project(1)], ProjectRole.owner.name);
        expect(aliceRoles[ResourceRoleKeys.item(1)], ProjectRole.owner.name);

        // bob holds only the seeded C-6 `editor` share on project 1 — no
        // ownership — so his map grades the project subtree `editor` and never
        // reaches the workspace (a share does not flow up).
        await c.auth.login(_bobLogin);
        final bobRoles = await c.app.resourceRoles();
        expect(bobRoles[ResourceRoleKeys.project(1)], ProjectRole.editor.name);
        expect(bobRoles[ResourceRoleKeys.item(1)], ProjectRole.editor.name);
        expect(bobRoles.containsKey(ResourceRoleKeys.workspace(1)), isFalse);
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });

    test(
        'TC-37-07: the DB-side union scope reaches a shared subtree at the item '
        'level — a share-only user lists the shared project\'s descendant item '
        '(RCB8)', () async {
      final c = _liveClients();
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // bob's only grant is an active `editor` share on project 1 (the seeded
        // delegation, or TC-37-03's identical restored replacement — either way
        // an editor share on project 1). With RCB8 the project/list/item reads
        // are filtered at app_db by the async union scope
        // `(id IN (owned…) OR id IN (shared…))` on the surrogate `id`, so bob
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
        expect(await _canSeeProject(c.app, _sharedProjectId), isTrue,
            reason: 'the active editor share makes the shared project visible');
        final sharedItem = await _findVisibleItem(c.app, _carolItemId);
        expect(sharedItem, isNotNull,
            reason: 'the DB list/item union scope reaches the shared subtree, '
                'so bob lists the item under the shared project');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        c.transport.close();
      }
    });
  });
}

/// One live transport plus the auth/admin/app clients that share it — the
/// runtime wiring each RCC5 check builds (and closes) independently.
({
  IoJsonTransport transport,
  AuthClient auth,
  AdminApiClient admin,
  AppApiClient app,
}) _liveClients() {
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

/// The complete `viewer` row from the §A.4 seed with `title` set to [title].
///
/// Posting the whole row (not just the one cell) is deliberate:
/// `adminPutGrants` replaces a role's grants wholesale, so a partial row would
/// drop the other six fields. See the library doc.
GrantMatrixDto _viewerRow(TomAuthState title) => GrantMatrixDto.fromGrades({
      'viewer': [
        GradedFieldDto(resourceKey: _titleKey, access: title),
        GradedFieldDto(
            resourceKey: 'todo.item.status', access: TomAuthState.read),
        GradedFieldDto(
            resourceKey: 'todo.item.priority', access: TomAuthState.read),
        GradedFieldDto(
            resourceKey: 'todo.item.assigneeId', access: TomAuthState.none),
        GradedFieldDto(
            resourceKey: 'todo.item.dueDate', access: TomAuthState.read),
        GradedFieldDto(
            resourceKey: 'todo.item.estimate', access: TomAuthState.none),
        GradedFieldDto(
            resourceKey: 'todo.item.description', access: TomAuthState.read),
      ],
    });
