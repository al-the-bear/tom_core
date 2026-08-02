/// Bootstrap done-when for todo 8: the login screen renders **server-delivered**
/// chrome, with no client-side string and no override.
///
/// Socket-free — the bundle is fetched through the backend seam against the
/// seeded [InMemoryAppBackend], whose canned login bundle mirrors what the live
/// auth server serves (D-A11). The proof is the resource provider's key-fallback
/// behaviour: with no bundle installed the screen renders the *raw keys*
/// (`login.title`, …) — so there is no hardcoded label baked into the widget —
/// and only after [AppSession.loadLoginResources] installs the bundle do the
/// server texts appear.
library;

import 'package:advanced_app_client/app/app.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // The login screen builds a reflected TomForm; the in-memory backend seeds the
  // reflected domain tree in its constructor.
  setUpAll(initializeReflection);

  testWidgets(
      'TC-8-01: the login screen renders server-delivered chrome after the '
      'bootstrap fetch (no hardcoded string)', (tester) async {
    // Start from an empty provider: every chrome key falls back to itself, which
    // is only possible because the widget carries no client-side strings.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );

    final session = AppSession(InMemoryAppBackend());
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await tester.pumpAndSettle();

    // Before the fetch: the title shows the raw key, never a baked-in label.
    expect(find.text('login.title'), findsOneWidget);
    expect(find.text('login.intro'), findsOneWidget);
    expect(find.text('Advanced Todo — Sign in'), findsNothing);

    // Fetch + install the public login bundle through the backend seam, exactly
    // as the bootstrap ([main]) does. notifyListeners rebuilds the screen.
    await session.loadLoginResources();
    await tester.pumpAndSettle();

    // After: the screen renders the server-delivered texts; the raw keys are gone.
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(
        find.text('Try alice, bob or carol (any non-empty password), dave to '
            'be challenged for a second factor, or erin to be offered one.'),
        findsOneWidget);
    expect(find.text('login.title'), findsNothing);
    expect(find.text('login.intro'), findsNothing);
  });
}
