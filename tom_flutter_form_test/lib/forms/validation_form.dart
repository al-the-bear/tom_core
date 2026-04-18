import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// ValidationForm — drives Demo A (lifecycle & validation)
// ---------------------------------------------------------------------------

/// Form that exercises every validation flavour described in §20.
///
/// Fields live inside [createFormElements] so they inherit this form's
/// scope (`<outer>.validationForm`) and their `basePath` matches the
/// resource paths laid out under `demoA.validationForm.*` in
/// `demo_resources.json`.
@tomReflector
class ValidationForm extends TomForm<TomClass> {
  ValidationForm() : super(formId: 'validationForm');

  late final TomFormStringInput username;
  late final TomFormStringInput email;
  late final TomFormStringInput password;
  late final TomFormStringInput confirmPassword;
  late final TomFormStringInput website;

  @override
  void createFormElements() {
    username = TomFormStringInput(
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

    email = TomFormStringInput(
      'email',
      '',
      validators: [Validators.required(), Validators.email()],
      keyboardType: TextInputType.emailAddress,
    );

    password = TomFormStringInput(
      'password',
      '',
      obscureText: true,
      validators: [
        Validators.required(),
        Validators.minLength(8),
      ],
    );

    confirmPassword = TomFormStringInput(
      'confirmPassword',
      '',
      obscureText: true,
      validators: [Validators.required()],
    );

    website = TomFormStringInput(
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
  }

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
