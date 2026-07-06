/// Widget tests for the app shell (step 27): the bootstrap-wired [AppSession]
/// driving the login↔board switch in [AdvancedTodoApp].
///
/// These are socket-free — the shell runs over the seeded [InMemoryAppBackend]
/// (one test subclasses it to force a post-refresh `401`). The fake builds the
/// reflected domain tree in its constructor, so `initializeReflection()` runs
/// once in [setUpAll]. The contract here is the step's done bar: a successful
/// login flips the home onto the board, and a dropped session routes back to
/// login.
library;

import 'package:advanced_app_client/app/app.dart';
import 'package:advanced_app_client/app/field_state_authorization_adapter.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show TodoItemResourceKeys;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// An [InMemoryAppBackend] that can be armed to fail the next field-states read
/// with the live stack's post-refresh `401` key, so the test can drive the
/// session-lost path without a socket.
class _ExpiringBackend extends InMemoryAppBackend {
  bool expireNextCall = false;

  @override
  Future<Map<String, TomAuthState>> itemFieldStates(String itemId) {
    if (expireNextCall) {
      throw const AppBackendException(
        'Session expired — re-authentication required.',
        key: 'auth.session_expired',
      );
    }
    return super.itemFieldStates(itemId);
  }
}

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // The real login screen builds a bound TomForm whose fields resolve labels
    // through the app resource provider.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  final aliceLogin = LoginRequest(username: 'alice', password: 'pw');
  final loginFinder = find.byKey(const Key('login-screen'));
  final boardFinder = find.byKey(const Key('board-screen'));

  testWidgets('TC-27-01: a logged-out session boots to the login screen',
      (tester) async {
    await tester.pumpWidget(AdvancedTodoApp(session: AppSession(_ExpiringBackend())));

    expect(loginFinder, findsOneWidget);
    expect(boardFinder, findsNothing);
  });

  testWidgets('TC-27-02: a successful login flips the home onto the board',
      (tester) async {
    final session = AppSession(_ExpiringBackend());
    await tester.pumpWidget(AdvancedTodoApp(session: session));

    await session.login(aliceLogin);
    await tester.pump();

    expect(boardFinder, findsOneWidget);
    expect(loginFinder, findsNothing);
    // The session carries the resolved principal + token pair.
    expect(session.user?.username, 'alice');
    expect(session.authToken, isNotEmpty);
    expect(session.authzToken, isNotEmpty);
  });

  testWidgets(
      'TC-27-03: a post-refresh 401 on a guarded call routes back to login',
      (tester) async {
    final backend = _ExpiringBackend();
    final session = AppSession(backend);
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await session.login(aliceLogin);
    await tester.pump();
    expect(boardFinder, findsOneWidget);

    // The next guarded call hits a dead session.
    backend.expireNextCall = true;
    await expectLater(
      session.loadFieldStates('i-1'),
      throwsA(isA<AppBackendException>()
          .having((e) => e.key, 'key', 'auth.session_expired')),
    );
    await tester.pump();

    expect(session.isLoggedIn, isFalse);
    expect(loginFinder, findsOneWidget);
    expect(boardFinder, findsNothing);
  });

  testWidgets('TC-27-04: tapping logout routes back to login', (tester) async {
    final session = AppSession(_ExpiringBackend());
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await session.login(aliceLogin);
    await tester.pump();
    expect(boardFinder, findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pump();

    expect(session.isLoggedIn, isFalse);
    expect(loginFinder, findsOneWidget);
    expect(boardFinder, findsNothing);
  });

  // The realignment (todo 3) feeds the implicit-authorization adapter from the
  // session: loading an item's matrix repoints the live adapter, and logout
  // clears it. Because the bootstrap installs this same adapter on the
  // TomAuthorization singleton, the forms see the matrix change with no
  // reinstall.
  group('session feeds the authorization adapter (todo 3)', () {
    test('the session owns a default adapter when none is injected', () {
      final session = AppSession(InMemoryAppBackend());
      // Empty until an item loads: a gradable leaf is closed-safe, the form path
      // ancestor stays permissive.
      expect(session.authorizationAdapter.states, isEmpty);
      expect(session.authorizationAdapter.resolveAuth(TodoItemResourceKeys.title),
          TomAuthState.none);
    });

    test('loadFieldStates repoints the adapter; logout clears it', () async {
      final session = AppSession(InMemoryAppBackend());
      final adapter = session.authorizationAdapter;

      await session.login(aliceLogin);
      final states = await session.loadFieldStates('i-1');

      // The adapter now resolves against exactly the loaded matrix.
      expect(adapter.states, same(states));
      expect(adapter.states, isNotEmpty);
      for (final entry in states.entries) {
        expect(adapter.resolveAuth(entry.key), entry.value);
      }

      await session.logout();
      // Cleared: every gradable leaf returns to the closed-safe default.
      expect(adapter.states, isEmpty);
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.none);
    });

    test('an injected adapter is the one the session feeds', () async {
      final injected = FieldStateAuthorizationAdapter();
      final session =
          AppSession(InMemoryAppBackend(), authorizationAdapter: injected);
      expect(session.authorizationAdapter, same(injected));

      await session.login(aliceLogin);
      final states = await session.loadFieldStates('i-1');
      expect(injected.states, same(states));
    });
  });
}
