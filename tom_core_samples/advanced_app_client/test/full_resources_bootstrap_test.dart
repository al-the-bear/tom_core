/// Done-when for todo 9 (app client): right after sign-in the **authenticated
/// full bundle** is installed over the login bundle, so post-login screen chrome
/// renders server-delivered texts; logout resets the provider to the login
/// bundle.
///
/// Socket-free — the full bundle is fetched through the backend seam against the
/// seeded [InMemoryAppBackend], whose canned full bundle mirrors what
/// `advanced_app_server` serves (D-A11). The proof is the resource provider's
/// key-fallback behaviour applied to the **post-login** chrome: `board.title`
/// (no grade counterpart, no form override) falls back to its raw key while only
/// the login bundle is installed, and resolves to the server text once
/// [AppSession.login] installs the full bundle. The login chrome stays
/// resolvable underneath (the merge keeps it), and logout drops the full keys
/// back to fallback while restoring the login bundle.
library;

import 'package:advanced_app_client/app/app.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // The board hosts reflected forms downstream; the in-memory backend seeds the
  // reflected domain tree in its constructor.
  setUpAll(initializeReflection);

  testWidgets(
      'TC-9-01: login installs the full bundle over the login bundle; logout '
      'resets to the login bundle', (tester) async {
    // Start from an empty provider so every key falls back to itself — no key
    // can resolve unless a bundle put it there.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );

    final session = AppSession(InMemoryAppBackend());
    await session.loadLoginResources();
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await tester.pumpAndSettle();

    final texts = TomTextResourceProvider.getAppResources;

    // Before login: the login bundle is installed, but the post-login chrome key
    // still falls back to itself — the board's title is not yet sourced.
    expect(find.text('My Board'), findsNothing);
    expect(texts().getText('board.title'), 'board.title');
    expect(texts().getText('todo.item.title.label'), 'todo.item.title.label');
    // The login chrome is already resolvable.
    expect(texts().getText('login.title'), 'Advanced Todo — Sign in');

    // Sign in: the full bundle is fetched through the seam and merged over the
    // login bundle, then the shell rebuilds onto the board.
    await session.login(const LoginRequest(username: 'alice', password: 'pw'));
    await tester.pumpAndSettle();

    // After login: the board AppBar renders the server-delivered title, and the
    // item-form label key now resolves to the full-bundle text.
    expect(find.text('My Board'), findsOneWidget);
    expect(texts().getText('board.title'), 'My Board');
    expect(texts().getText('todo.item.title.label'), 'Title');
    // The login chrome stays resolvable underneath the merge.
    expect(texts().getText('login.title'), 'Advanced Todo — Sign in');

    // Sign out: the provider is reset to the login bundle — the full keys fall
    // back again while the login chrome remains.
    await session.logout();
    await tester.pumpAndSettle();

    expect(find.text('My Board'), findsNothing);
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(texts().getText('board.title'), 'board.title');
    expect(texts().getText('todo.item.title.label'), 'todo.item.title.label');
    expect(texts().getText('login.title'), 'Advanced Todo — Sign in');
  });
}
