/// Resource bootstrap for the pre-login admin screen: it renders
/// **server-delivered** chrome, with no client-side string and no override.
///
/// Socket-free — the bundle is fetched through the backend seam against the
/// seeded [InMemoryAdminBackend], whose canned login bundle mirrors what the live
/// auth server serves from `AuthResourceBundles.loginBundle()`. The proof is the
/// resource provider's key-fallback
/// behaviour: with no bundle installed the screen's chrome renders the *raw keys*
/// (`adminLogin.title`, …) — so there is no hardcoded chrome string baked into the
/// widget — and only after [AdminSession.loadLoginResources] installs the bundle
/// do the server texts appear. The login screen drives the reflected
/// [AdminLoginForm], so the console's `initializeReflection()` runs once in
/// [setUpAll].
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  testWidgets(
      'TC-8-02: the admin login screen renders server-delivered chrome after the '
      'bootstrap fetch (no hardcoded string)', (tester) async {
    // Start from an empty provider: every chrome key falls back to itself, which
    // is only possible because the widget carries no client-side strings.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );

    final session = AdminSession(InMemoryAdminBackend());
    await tester.pumpWidget(AdminConsoleApp(session: session));
    await tester.pumpAndSettle();

    // Before the fetch: the title shows the raw key, never a baked-in label.
    expect(find.text('adminLogin.title'), findsOneWidget);
    expect(find.text('adminLogin.intro'), findsOneWidget);
    expect(find.text('Advanced Todo — Admin sign in'), findsNothing);

    // Fetch + install the public login bundle through the backend seam, exactly
    // as the bootstrap ([main]) does. notifyListeners rebuilds the screen.
    await session.loadLoginResources();
    await tester.pumpAndSettle();

    // After: the screen renders the server-delivered texts; the raw keys are gone.
    expect(find.text('Advanced Todo — Admin sign in'), findsOneWidget);
    expect(
        find.text('Sign in as admin (password pw). A non-admin (alice, bob, '
            'carol) is rejected.'),
        findsOneWidget);
    expect(find.text('adminLogin.title'), findsNothing);
    expect(find.text('adminLogin.intro'), findsNothing);
  });
}
