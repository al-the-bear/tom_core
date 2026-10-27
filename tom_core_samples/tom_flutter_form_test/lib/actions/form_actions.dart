import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// SaveFormAction — validates and commits one or more forms
// ---------------------------------------------------------------------------

/// Validates and saves a list of forms, then updates [status] with the result.
///
/// Fires asynchronously so the UI can show a validating message immediately.
/// Success / error messages are resolved from resources at the action's
/// canonical path (`<controllerId>.save.success` / `.error` / `.validating`).
class SaveFormAction extends TomSimpleAction<TomActionContext> {
  final List<TomForm> forms;
  final TomString status;

  SaveFormAction(
    TomActionController controller, {
    required this.forms,
    required this.status,
  }) : super(actionId: 'save', controller: controller);

  @override
  void executeSimple(TomActionContext context, TomActionTransaction tx) {
    status | (TomCtr.textOrNull(canonicalPath, 'validating') ?? 'Validating…');
    Future.wait(forms.map((f) => f.save()))
        .then((results) {
          final allOk = results.every((r) => r);
          status |
              (allOk
                  ? TomCtr.textOrNull(canonicalPath, 'success') ?? 'Saved!'
                  : _errorMessage);
        })
        .catchError((Object _) {
          // A save that *throws* (validator/back-write failure) must be reported
          // exactly like a `false` result — otherwise the rejection escapes as an
          // uncaught async error and `status` stays stuck on the transient
          // "Validating…" message.
          status | _errorMessage;
        });
  }

  String get _errorMessage =>
      TomCtr.textOrNull(canonicalPath, 'error') ??
      'Validation failed — check fields';
}

// ---------------------------------------------------------------------------
// DiscardFormAction — reverts all unsaved changes in one or more forms
// ---------------------------------------------------------------------------

class DiscardFormAction extends TomSimpleAction<TomActionContext> {
  final List<TomForm> forms;
  final TomString status;

  DiscardFormAction(
    TomActionController controller, {
    required this.forms,
    required this.status,
  }) : super(actionId: 'discard', controller: controller);

  @override
  void executeSimple(TomActionContext context, TomActionTransaction tx) {
    for (final f in forms) {
      f.discard();
    }
    status |
        (TomCtr.textOrNull(canonicalPath, 'success') ?? 'Changes discarded');
  }
}
