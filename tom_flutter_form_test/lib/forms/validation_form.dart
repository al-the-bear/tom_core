import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// ValidationForm — drives Demo A (lifecycle & validation)
// ---------------------------------------------------------------------------

/// Form that exercises every validation flavour the forms layer offers.
///
/// Fields are declared at the class level and pass `form: this` so their
/// basePath resolves under `<outer>.validationForm.*` — e.g.
/// `demoA.validationForm.username` — matching the resource layout in
/// `demo_resources.json`. The `form` parameter is how the field picks up
/// its enclosing scope; relying on TomScope.current instead would race
/// against when reflection-driven lazy init happens to fire.
@tomReflector
class ValidationForm extends TomForm<TomClass> {
  ValidationForm() : super(formId: 'validationForm');

  @override
  void createFormElements() {}

  late final username = TomFormStringInput(
    'username',
    '',
    form: this,
    validators: [
      TomValidators.required(),
      TomValidators.minLength(3),
      TomValidators.pattern(
        RegExp(r'^[a-zA-Z0-9_]+$'),
        errorKey: 'error.usernamePattern',
      ),
      TomSlowValidator<String>((value) async {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (value.toLowerCase().startsWith('admin')) {
          return const TomValidationError('error.usernameTaken');
        }
        return const TomValidationSuccess();
      }),
    ],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    validators: [TomValidators.required(), TomValidators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final password = TomFormStringInput(
    'password',
    '',
    form: this,
    obscureText: true,
    validators: [TomValidators.required(), TomValidators.minLength(8)],
  );

  late final confirmPassword = TomFormStringInput(
    'confirmPassword',
    '',
    form: this,
    obscureText: true,
    validators: [TomValidators.required()],
  );

  late final website = TomFormStringInput(
    'website',
    '',
    form: this,
    validators: [
      TomValidators.pattern(
        RegExp(
          r'^https?:\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
          r'[a-zA-Z]{2,}(?::\d{1,5})?(?:\/[^\s]*)?$',
        ),
        errorKey: 'error.invalidUrl',
      ),
    ],
    keyboardType: TextInputType.url,
  );

  @override
  Future<List<TomFormValidationError>> validateForm() async {
    final errors = <TomFormValidationError>[];
    if (password.get().isNotEmpty &&
        confirmPassword.get().isNotEmpty &&
        password.get() != confirmPassword.get()) {
      errors.add(
        TomFormValidationError(
          errorKey: 'error.passwordsMismatch',
          fields: [password, confirmPassword],
        ),
      );
    }
    return errors;
  }
}
