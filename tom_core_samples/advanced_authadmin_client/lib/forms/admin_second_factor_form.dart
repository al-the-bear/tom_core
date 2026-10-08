/// The admin second-factor form — a `TomForm` bound to the client-local
/// [AdminSecondFactorCode].
///
/// Built unscoped like [AdminLoginForm], so its `formId: 'adminTwoFactor'` *is*
/// its base path and the single field self-addresses as `adminTwoFactor.code` —
/// a sibling scope of `adminLogin` in the same public bundle the auth server
/// serves before sign-in, which is the only bundle reachable mid-login (the
/// admin-gated console bundle needs a session the interim token does not
/// provide).
///
/// The field's width is a **constructor argument**, not a constant: the
/// challenge names its own code shape in `clientData['digits']`, so a mechanism
/// with a different digit count needs no change here.
library;

import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/admin_second_factor_code.dart';

/// One-time-code entry for the admin console, validated to the challenge's exact
/// code width.
@tomReflector
class AdminSecondFactorForm extends TomForm<AdminSecondFactorCode> {
  /// Creates the form for a challenge whose codes are [digits] long.
  AdminSecondFactorForm({this.digits = 6}) : super(formId: 'adminTwoFactor');

  /// The code length the challenge declared (`clientData['digits']`).
  final int digits;

  /// The one-time code. Label/hint resolve from the installed login bundle
  /// (`adminTwoFactor.code.label` / `adminTwoFactor.code.hint`).
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
        TomValidators.required(),
        // Exactly [digits] — the server rejects a wrong-width submission before
        // it hashes anything, and a submission that can never match should not
        // cost the administrator one of their three attempts.
        TomValidators.minLength(digits),
        TomValidators.maxLength(digits),
      ],
    );
  }
}
