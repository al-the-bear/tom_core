/// Contract tests for the seeded [InMemoryAppBackend] (step 26): the offline
/// teaching backend the app's widgets bind in tests, exercised across the seam's
/// whole surface — login, the workspace→project→list→item reads, item save, the
/// per-principal four-state field matrix, and cross-user sharing.
///
/// These are socket-free: the fake constructs the reflected domain entities
/// in-process, so `initializeReflection()` (from `advanced_todo_domain`) runs
/// once in [setUpAll]. The same scenarios are the contract any [AppBackend] must
/// honour, so when the live backend is wired against a running stack it must
/// behave identically.
library;

import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initializeReflection);

  late InMemoryAppBackend backend;
  setUp(() => backend = InMemoryAppBackend());

  Future<LoginResult> loginAs(String username) =>
      backend.login(LoginRequest(username: username, password: 'pw'));

  group('login', () {
    test('TC-26-01: a known account logs in and returns the principal + tokens',
        () async {
      final result = await loginAs('alice');
      expect(result.user.username, 'alice');
      expect(result.user.id, 'u-alice');
      expect(result.authToken, isNotEmpty);
      expect(result.authzToken, isNotEmpty);
      expect(result.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('TC-26-02: an unknown account is rejected with a typed error',
        () async {
      await expectLater(
        loginAs('mallory'),
        throwsA(isA<AppBackendException>()
            .having((e) => e.key, 'key', 'auth.login.failed')),
      );
    });

    test('TC-26-03: an empty password is rejected', () async {
      await expectLater(
        backend.login(const LoginRequest(username: 'alice', password: '')),
        throwsA(isA<AppBackendException>()
            .having((e) => e.key, 'key', 'auth.login.failed')),
      );
    });

    test('TC-26-04: a call before login throws app.no_session', () async {
      await expectLater(
        backend.listWorkspaces(),
        throwsA(isA<AppBackendException>()
            .having((e) => e.key, 'key', 'app.no_session')),
      );
    });
  });

  group('reads (ownership + sharing filter the visible tree)', () {
    test('TC-26-05: the owner walks workspace → project → list → items',
        () async {
      await loginAs('alice');
      final workspaces = await backend.listWorkspaces();
      expect(workspaces.map((w) => w.id.get()), ['w-1']);

      final projects = await backend.listProjects('w-1');
      expect(projects.map((p) => p.id.get()), ['p-1']);

      final lists = await backend.listLists('p-1');
      expect(lists.map((l) => l.id.get()), ['l-1']);

      final items = await backend.listItems('l-1');
      expect(items.map((i) => i.id.get()), ['i-1', 'i-2']);
    });

    test('TC-26-06: a shared editor sees the same tree', () async {
      await loginAs('bob');
      expect((await backend.listWorkspaces()).map((w) => w.id.get()), ['w-1']);
      expect((await backend.listItems('l-1')).map((i) => i.id.get()),
          ['i-1', 'i-2']);
    });

    test('TC-26-07: an unshared user sees nothing', () async {
      await loginAs('val');
      expect(await backend.listWorkspaces(), isEmpty);
      expect(await backend.listProjects('w-1'), isEmpty);
      expect(await backend.listItems('l-1'), isEmpty);
    });
  });

  group('save (create + update, field-write authorized)', () {
    test('TC-26-08: the owner creates an item, which is assigned an id',
        () async {
      await loginAs('alice');
      final created = await backend.saveItem(TodoItem()
        ..listId.set('l-1')
        ..title.set('New task')
        ..statusValue = TodoStatus.backlog);
      expect(created.id.get(), isNotEmpty);

      final ids = (await backend.listItems('l-1')).map((i) => i.id.get());
      expect(ids, contains(created.id.get()));
    });

    test('TC-26-09: the owner updates an existing item', () async {
      await loginAs('alice');
      final updated = await backend.saveItem(TodoItem()
        ..id.set('i-1')
        ..listId.set('l-1')
        ..title.set('Draft the landing copy (revised)')
        ..statusValue = TodoStatus.inReview);
      expect(updated.title.get(), 'Draft the landing copy (revised)');

      final reread = (await backend.listItems('l-1'))
          .firstWhere((i) => i.id.get() == 'i-1');
      expect(reread.statusValue, TodoStatus.inReview);
    });

    test('TC-26-10: a viewer cannot save (no write grade)', () async {
      // Grant val a viewer share first, then attempt a write.
      await loginAs('alice');
      await backend.share(const ShareRequest(
        resourceType: 'project',
        resourceId: 'p-1',
        granteeUserId: 'u-val',
        projectRole: ProjectRole.viewer,
      ));
      await loginAs('val');
      await expectLater(
        backend.saveItem(TodoItem()
          ..id.set('i-1')
          ..listId.set('l-1')
          ..title.set('hijack')),
        throwsA(isA<AppBackendException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')),
      );
    });
  });

  group('field-states (the four-state matrix per principal)', () {
    test('TC-26-11: the owner gets full on every gradable field', () async {
      await loginAs('alice');
      final states = await backend.itemFieldStates('i-1');
      expect(states.keys, containsAll(TodoItemResourceKeys.all));
      expect(
          states.values.every((s) => s == TomAuthState.full), isTrue);
    });

    test('TC-26-12: an editor is read on assignee/estimate, full elsewhere',
        () async {
      await loginAs('bob');
      final states = await backend.itemFieldStates('i-1');
      expect(states[TodoItemResourceKeys.title], TomAuthState.full);
      expect(states[TodoItemResourceKeys.assigneeId], TomAuthState.read);
      expect(states[TodoItemResourceKeys.estimate], TomAuthState.read);
    });

    test(
        'TC-26-13: an unshared user gets none on every field (closed-safe)',
        () async {
      await loginAs('val');
      final states = await backend.itemFieldStates('i-1');
      expect(
          states.values.every((s) => s == TomAuthState.none), isTrue);
    });
  });

  group('share (cross-user access)', () {
    test('TC-26-14: sharing a project grants the grantee visibility + grade',
        () async {
      // Before: val sees nothing.
      await loginAs('val');
      expect(await backend.listWorkspaces(), isEmpty);

      // The owner shares the project with val as a viewer.
      await loginAs('alice');
      await backend.share(const ShareRequest(
        resourceType: 'project',
        resourceId: 'p-1',
        granteeUserId: 'u-val',
        projectRole: ProjectRole.viewer,
      ));

      // After: val now sees the workspace and gets the viewer field matrix
      // (status renders disabled, the rest read-only).
      await loginAs('val');
      expect((await backend.listWorkspaces()).map((w) => w.id.get()), ['w-1']);
      final states = await backend.itemFieldStates('i-1');
      expect(states[TodoItemResourceKeys.status], TomAuthState.disabled);
      expect(states[TodoItemResourceKeys.title], TomAuthState.read);
    });

    test('TC-26-15: only the owner may share', () async {
      await loginAs('bob'); // editor, not owner
      await expectLater(
        backend.share(const ShareRequest(
          resourceType: 'project',
          resourceId: 'p-1',
          granteeUserId: 'u-val',
          projectRole: ProjectRole.viewer,
        )),
        throwsA(isA<AppBackendException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')),
      );
    });
  });
}
