/// The one client-local reflected entity: the username/password pair the
/// [LoginForm] binds.
///
/// Everything else the client edits comes from the shared `todo_domain`
/// package (one model across the tier). Credentials are the exception — they
/// never leave the client as a persisted entity, so they live here rather than
/// in the shared domain. Like the domain entities it is `@tomReflector` and a
/// [TomClass], so the login form binds it through the same reflection round-trip
/// as every other form.
///
/// Shared in shape with `advanced_app_client`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Username + password, bound into the login form.
@tomReflector
class LoginCredentials extends TomClass {
  /// The account's login name (matches a seeded demo [todo_domain] `User`).
  late final username = TomString('');

  /// The account's password (the in-memory demo accepts any non-empty value).
  late final password = TomString('');
}
