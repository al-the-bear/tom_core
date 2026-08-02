/// The second-factor form — a `TomForm` bound to the client-local
/// [SecondFactorCode].
///
/// Built unscoped like [LoginForm], so its `formId: 'twoFactor'` *is* its base
/// path and the single field self-addresses as `twoFactor.code` — a sibling
/// scope of `login` in the same public bundle the auth server serves before
/// sign-in, which is the only bundle reachable mid-login.
///
/// The field's width is a **constructor argument**, not a constant: the
/// challenge names its own code shape in `clientData['digits']`, so a mechanism
/// with a different digit count needs no change here.
library;

import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/second_factor_code.dart';

/// One-time-code entry, validated to the challenge's exact code width.
@tomReflector
class SecondFactorForm extends TomForm<SecondFactorCode> {
  /// Creates the form for a challenge whose codes are [digits] long.
  SecondFactorForm({this.digits = 6}) : super(formId: 'twoFactor');

  /// The code length the challenge declared (`clientData['digits']`).
  final int digits;

  /// The one-time code. Label/hint resolve from the installed login bundle
  /// (`twoFactor.code.label` / `twoFactor.code.hint`).
  late final TomFormStringInput code;

  /// Creates the fields (implementation half of the three-part split, G-UI-5).
  @override
  void createFormElements() {
    code = TomFormStringInput(
      'code',
      '',
      form: this,
      maxLength: digits,
      keyboardType: TextInputType.number,
      validators: [
        Validators.required(),
        // Exactly [digits] — the server rejects a wrong-width submission before
        // it hashes anything, and a submission that can never match should not
        // cost the user one of their three attempts.
        Validators.minLength(digits),
        Validators.maxLength(digits),
      ],
    );
  }
}
