/// The one client-local reflected entity: the username/password pair the
/// [LoginForm] binds.
///
/// Every other entity the app edits comes from the shared `advanced_todo_domain`
/// package — one model across the tier. Credentials are the exception: they
/// never leave the client as a persisted entity (the screen folds them into a
/// wire [LoginRequest]), so they live here rather than in the shared domain.
/// Like the domain entities it is `@tomReflector` and a [TomClass], so the login
/// form binds it through the same reflection round-trip as every other form.
///
/// Shared in shape with `core_client_sample`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Username + password, bound into the login form.
@tomReflector
class LoginCredentials extends TomClass {
  /// The account's login name. The seeded demo accounts are `alice`, `bob`,
  /// `carol`, `dave` and `erin`; `dave` already holds a second factor and is
  /// therefore *challenged* for a code, and `erin` holds none and is *offered*
  /// enrolment. The rest sign straight in.
  late final username = TomString('');

  /// The account's password (the in-memory demo accepts any non-empty value).
  late final password = TomString('');
}
