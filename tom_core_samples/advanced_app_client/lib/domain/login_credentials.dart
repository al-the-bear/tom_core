/// The one client-local reflected entity: the username/password pair the
/// [LoginForm] binds (step 28).
///
/// Every other entity the app edits comes from the shared `advanced_todo_domain`
/// package — one model across the tier. Credentials are the exception: they
/// never leave the client as a persisted entity (the screen folds them into a
/// wire [LoginRequest]), so they live here rather than in the shared domain.
/// Like the domain entities it is `@tomReflector` and a [TomClass], so the login
/// form binds it through the same reflection round-trip as every other form.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Username + password, bound into the login form.
@tomReflector
class LoginCredentials extends TomClass {
  /// The account's login name (a seeded demo account: alice, bob, carol, or
  /// dave — the one enrolled in two-step verification).
  late final username = TomString('');

  /// The account's password (the in-memory demo accepts any non-empty value).
  late final password = TomString('');
}
