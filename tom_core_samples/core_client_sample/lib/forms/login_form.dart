/// The login form — a `TomForm` bound to the client-local [LoginCredentials].
///
/// Field member names match the entity's (`username`, `password`) so the
/// reflection round-trip `bind` performs writes straight into the bound
/// credentials. It is `@tomReflector` and seeded for reflection, like every
/// bound form.
///
/// The form carries no hardcoded label or hint text (G-RES-1): constructed
/// directly (not under an enclosing scope), its `basePath` is `login`, so each
/// field's label/hint resolve from `login.<tomId>.label` / `login.<tomId>.hintText`
/// in the installed [appTexts] bundle.
///
/// The validators are resources too (G-UI-7): neither field passes a code
/// validator. Each declares `required` under `login.<tomId>.validators` in the
/// bundle, and `TomField` resolves it by name through the DI-swappable
/// `TomValidatorRegistry`. A failed `required` renders the resolved
/// `error.required` message — no validator closure or message string lives here.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/login_credentials.dart';

/// Username + password entry, validated as `required` — declared as a resource.
@tomReflector
class LoginForm extends TomForm<LoginCredentials> {
  /// Creates the login form.
  LoginForm() : super(formId: 'login');

  /// Account login name. Label/hint resolve from `login.username.label` and
  /// `login.username.hintText`; its `required` validator from
  /// `login.username.validators`.
  late final username = TomFormStringInput('username', '', form: this);

  /// Account password (the demo backend accepts any non-empty value). Label
  /// resolves from `login.password.label`; its `required` validator from
  /// `login.password.validators`.
  late final password = TomFormStringInput(
    'password',
    '',
    form: this,
    obscureText: true,
  );

  @override
  void createFormElements() {}
}
