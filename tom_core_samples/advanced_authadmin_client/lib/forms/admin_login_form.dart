/// The admin login form — a `TomForm` bound to the client-local
/// [AdminLoginCredentials] (todo 12).
///
/// Mirrors the app client's `LoginForm`: built with `tom_flutter_ui`
/// [TomFormStringInput]s (not the legacy `TomFormOld`/`TomEmailField` API), and
/// built **unscoped** with `formId: 'adminLogin'`, so its `formId` *is* its base
/// path and each field self-addresses as its resource key (`adminLogin.username`,
/// `adminLogin.password`) — exactly the keys the auth server serves on the public
/// `/resources/login` bundle the admin client installs before sign-in (todo 8).
/// No `labelTextOverride`: labels/hints resolve from that installed bundle.
///
/// Field member names match the entity's (`username`, `password`) so the
/// reflection round-trip `bind`/`save` writes straight back into the bound
/// credentials. It is `@tomReflector` and seeded for reflection, like every
/// bound form.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/admin_login_credentials.dart';

/// Username + password entry for the admin console, validated as required.
@tomReflector
class AdminLoginForm extends TomForm<AdminLoginCredentials> {
  /// Creates the admin login form. Built unscoped so `formId: 'adminLogin'` is
  /// the base path and the fields self-address as the served bundle keys.
  AdminLoginForm() : super(formId: 'adminLogin');

  /// Administrator login name. Label/hint resolve from the installed login
  /// bundle (`adminLogin.username.label` / `adminLogin.username.hint`).
  late final username = TomFormStringInput(
    'username',
    '',
    form: this,
    validators: [Validators.required()],
  );

  /// Administrator password (the demo backend accepts any non-empty value for a
  /// seeded account). Label resolves from `adminLogin.password.label` in the
  /// installed login bundle.
  late final password = TomFormStringInput(
    'password',
    '',
    form: this,
    obscureText: true,
    validators: [Validators.required()],
  );

  @override
  void createFormElements() {}
}
