/// End-to-end cross-tier integration test (step 37, Phase 7): the whole stack —
/// both servers and both databases — exercised through the real client tier in
/// one scripted scenario.
///
/// The scenario walks the two authorization mechanisms that span the tiers:
///
///  1. **An admin grant edit shows up in the end-user's field matrix.** The
///     `admin` edits the `viewer` role's `todo.item.title` grant through the
///     auth server's `/admin/grants`; `carol` (a seeded `viewer` on project 1)
///     then re-reads item 1's field states from the *app* server and sees the
///     new grade — proving the app server resolves grades from the very rows the
///     auth server's admin API writes (the app server's `main` datasource points
///     at `auth_db`, read-only).
///  2. **A share lets a second user see a project.** `alice` (workspace owner)
///     creates a fresh project, `bob` cannot list it, `alice` shares it with
///     `bob` as `editor`, and `bob` then lists it — the step-17 ownership-or-share
///     resolver in action over the live wire.
///
/// **Why the grant edit writes the whole `viewer` row.** `adminPutGrants`
/// replaces grants *per role* (`replaceGrantsForRole`), and `adminGetGrants`
/// cannot round-trip a single DTO over the live wire yet (the kernel
/// reflection-serializer gap documented in `admin_api_client.dart`). So rather
/// than read-modify-write the matrix, the test posts the complete intended
/// `viewer` row (the §A.4 seed with just `title` flipped); that preserves the
/// other six fields and is robust to the read-back gap. The test normalises
/// `title` to `read` first, asserts the `read→full` transition, and restores it
/// to `read` in `finally`, so it leaves `auth_db` exactly as seeded and is
/// re-runnable.
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
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    hide initializeReflection;
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

void main() {
  setUpAll(initializeReflection);

  group('cross-tier scenario (live auth + app servers)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test(
        'TC-37-01: admin grant edit reaches the end-user matrix, and a share '
        'reveals a project to a second user', () async {
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

        // --- Beat 2: carol (a viewer) sees title graded `read`. ---
        await auth.login(_carolLogin);
        expect(await _carolTitleState(app), equals(TomAuthState.read));

        // --- Beat 3: admin grants viewer.title -> full. ---
        await auth.login(_adminLogin);
        await admin.putGrants(_viewerRow(TomAuthState.full));

        // --- Beat 4: carol re-reads; the app matrix reflects the new grant. ---
        await auth.login(_carolLogin);
        expect(await _carolTitleState(app), equals(TomAuthState.full));

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
  });
}

/// carol's resolved grade for the `title` field on item [_carolItemId], read
/// from the app server's field-state endpoint.
Future<TomAuthState> _carolTitleState(AppApiClient app) async {
  final states = await app.itemFieldStates(_carolItemId);
  return states.firstWhere((g) => g.resourceKey == _titleKey).accessState;
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
