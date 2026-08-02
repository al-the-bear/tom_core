/// The one-time code the second pass of a two-factor login submits.
///
/// A sibling of [LoginCredentials] and there for the same reason: like the
/// password, the code never leaves the client as a persisted entity — the screen
/// folds it into a `submitSecondFactor` call — so it lives here rather than in
/// the shared `advanced_todo_domain`. It is a separate entity rather than a
/// third field on [LoginCredentials] because it belongs to a different form:
/// binding one entity to two forms would make the code field's resource path
/// `login.code` instead of `twoFactor.code`, and would carry the password into
/// the second screen for no reason.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The authenticator code entered on the second-factor screen.
@tomReflector
class SecondFactorCode extends TomClass {
  /// The one-time code — six digits for TOTP, but the field is sized from the
  /// challenge's `clientData['digits']`, never from that assumption.
  late final code = TomString('');
}
