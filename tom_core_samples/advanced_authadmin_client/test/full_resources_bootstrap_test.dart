/// Resource bootstrap for the signed-in admin console: right after an admin
/// sign-in the **admin-gated full bundle** is installed over the login bundle,
/// so the post-login console chrome renders server-delivered texts; logout
/// resets the provider to the login bundle.
///
/// Socket-free — the full bundle is fetched through the backend seam against the
/// seeded [InMemoryAdminBackend], whose canned console bundle mirrors what
/// `advanced_auth_server` serves from `AuthResourceBundles.adminConsoleBundle()`.
/// The proof is the resource provider's
/// key-fallback behaviour applied to the **post-login** chrome:
/// `adminConsole.title` (no grade counterpart, no form override) falls back to
/// its raw key while only the login bundle is installed, and resolves to the
/// server text once [AdminSession.login] installs the full bundle. The login
/// chrome stays resolvable underneath (the merge keeps it), and logout drops the
/// full keys back to fallback while restoring the login bundle. The login screen
/// drives the reflected [AdminLoginForm], so the console's
/// `initializeReflection()` runs once in [setUpAll].
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  testWidgets(
    'TC-9-02: admin login installs the console bundle over the login bundle; '
    'logout resets to the login bundle',
    (tester) async {
      // Start from an empty provider so every key falls back to itself — no key
      // can resolve unless a bundle put it there.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(const <String, dynamic>{}),
      );

      final session = AdminSession(InMemoryAdminBackend());
      await session.loadLoginResources();
      await tester.pumpWidget(AdminConsoleApp(session: session));
      await tester.pumpAndSettle();

      final texts = TomTextResourceProvider.getAppResources;

      // Before login: the login bundle is installed, but the post-login console
      // chrome key still falls back to itself.
      expect(find.text('Advanced Todo — Admin console'), findsNothing);
      expect(texts().getText('adminConsole.title'), 'adminConsole.title');
      expect(texts().getText('user.username.label'), 'user.username.label');
      expect(texts().getText('grants.title'), 'grants.title');
      // The admin login chrome is already resolvable.
      expect(
        texts().getText('adminLogin.title'),
        'Advanced Todo — Admin sign in',
      );

      // Sign in as the administrator: the admin-gated console bundle is fetched
      // through the seam (after the admin probe) and merged over the login bundle,
      // then the shell rebuilds onto the console.
      await session.login(LoginRequest(username: 'admin', password: 'pw'));
      await tester.pumpAndSettle();

      // After login: the shell AppBar renders the server-delivered title, and the
      // editor label keys now resolve to the full-bundle texts.
      expect(find.text('Advanced Todo — Admin console'), findsOneWidget);
      expect(
        texts().getText('adminConsole.title'),
        'Advanced Todo — Admin console',
      );
      expect(texts().getText('user.username.label'), 'Username');
      expect(texts().getText('grants.title'), 'Grant matrix');
      // The login chrome stays resolvable underneath the merge.
      expect(
        texts().getText('adminLogin.title'),
        'Advanced Todo — Admin sign in',
      );

      // Sign out: the provider is reset to the login bundle — the full keys fall
      // back again while the login chrome remains.
      await session.logout();
      await tester.pumpAndSettle();

      expect(find.text('Advanced Todo — Admin console'), findsNothing);
      expect(find.text('Advanced Todo — Admin sign in'), findsOneWidget);
      expect(texts().getText('adminConsole.title'), 'adminConsole.title');
      expect(texts().getText('user.username.label'), 'user.username.label');
      expect(
        texts().getText('adminLogin.title'),
        'Advanced Todo — Admin sign in',
      );
    },
  );
}
