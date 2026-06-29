/// The login form — a `TomForm` bound to the client-local [LoginCredentials]
/// (step 28).
///
/// Field member names match the entity's (`username`, `password`) so the
/// reflection round-trip `bind`/`save` writes straight into the bound
/// credentials. It is `@tomReflector` and seeded for reflection, like every
/// bound form.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/login_credentials.dart';

/// Username + password entry, validated as required.
@tomReflector
class LoginForm extends TomForm<LoginCredentials> {
  /// Creates the login form.
  LoginForm() : super(formId: 'login');

  /// Account login name. Label/hint resolve from the installed login bundle
  /// (`login.username.label` / `login.username.hint`).
  late final username = TomFormStringInput(
    'username',
    '',
    form: this,
    validators: [Validators.required()],
  );

  /// Account password (the demo backend accepts any non-empty value). Label
  /// resolves from `login.password.label` in the installed login bundle.
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
