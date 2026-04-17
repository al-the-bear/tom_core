import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// ValidationForm — drives Demo A (lifecycle & validation)
// ---------------------------------------------------------------------------

/// Form that exercises every validation flavour described in §20:
///
/// * **Sync** — `required()`, `email()`, `minLength()`, `pattern()`.
/// * **Async** — a simulated uniqueness check on `username`, via
///   [SlowValidator] (shows the pending spinner).
/// * **Cross-field** — `confirmPassword` must equal `password`. Enforced in
///   [validateForm] so it runs after the per-field validators pass.
/// * **Debounced** — built-in. `TomField.setValue` schedules a fast/slow
///   debounce; the demo exercises this naturally as the user types.
@tomReflector
class ValidationForm extends TomForm<TomClass> {
  ValidationForm() : super(formId: 'validationForm');

  @override
  void createFormElements() {}

  /// Username with a simulated server-side uniqueness check. Names starting
  /// with `admin` are considered taken.
  late final username = TomFormStringInput(
    'username',
    '',
    validators: [
      Validators.required(),
      Validators.minLength(3),
      Validators.pattern(
        RegExp(r'^[a-zA-Z0-9_]+$'),
        errorKey: 'error.usernamePattern',
      ),
      SlowValidator<String>((value) async {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (value.toLowerCase().startsWith('admin')) {
          return const ValidationError('error.usernameTaken');
        }
        return const ValidationSuccess();
      }),
    ],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    validators: [Validators.required(), Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final password = TomFormStringInput(
    'password',
    '',
    obscureText: true,
    validators: [
      Validators.required(),
      Validators.minLength(8),
    ],
  );

  late final confirmPassword = TomFormStringInput(
    'confirmPassword',
    '',
    obscureText: true,
    validators: [Validators.required()],
  );

  late final website = TomFormStringInput(
    'website',
    '',
    validators: [
      Validators.pattern(
        RegExp(
          r'^https?:\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
          r'[a-zA-Z]{2,}(?::\d{1,5})?(?:\/[^\s]*)?$',
        ),
        errorKey: 'error.invalidUrl',
      ),
    ],
    keyboardType: TextInputType.url,
  );

  // --- Cross-field validation ------------------------------------------------

  @override
  Future<List<FormValidationError>> validateForm() async {
    final errors = <FormValidationError>[];
    if (password.get().isNotEmpty &&
        confirmPassword.get().isNotEmpty &&
        password.get() != confirmPassword.get()) {
      errors.add(FormValidationError(
        errorKey: 'error.passwordsMismatch',
        fields: [password, confirmPassword],
      ));
    }
    return errors;
  }
}
