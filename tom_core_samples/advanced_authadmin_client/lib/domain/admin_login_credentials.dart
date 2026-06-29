/// The admin console's client-local reflected login entity: the
/// username/password pair the [AdminLoginForm] binds (todo 12).
///
/// It mirrors the app client's `LoginCredentials`: credentials never leave the
/// client as a persisted entity (the screen folds them into a wire
/// [LoginRequest]), so they live here rather than in the shared domain. Like
/// every bound type it is `@tomReflector` and a [TomClass], so the admin login
/// form binds it through the same reflection round-trip as the user/role/group
/// editors.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Username + password, bound into the admin login form.
@tomReflector
class AdminLoginCredentials extends TomClass {
  /// The administrator's login name (the in-memory seam seeds an `admin`
  /// account; a valid non-admin login is refused by the role gate).
  late final username = TomString('');

  /// The administrator's password (the in-memory demo accepts any non-empty
  /// value for a seeded account).
  late final password = TomString('');
}
