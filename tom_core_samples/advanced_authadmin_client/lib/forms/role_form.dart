/// The role editor — a `TomForm` bound to a [RoleDraft].
///
/// The role key is the stable identifier the grant matrix and `@TomRoleAccess`
/// key on, so it is editable only on create; on edit it renders read-only and
/// only the human-facing name changes (the seam's `updateRole` keeps the key).
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/admin_drafts.dart';

/// A bound editor for a [RoleDraft], in create or edit mode.
@tomReflector
class RoleForm extends TomForm<RoleDraft> {
  /// Creates the form. When [isCreate] is false the key is read-only.
  RoleForm({this.isCreate = true}) : super(formId: 'role');

  /// Whether the form is creating a new role (vs. editing an existing one).
  final bool isCreate;

  /// Stable role key — editable on create, read-only (stable key) on edit.
  /// Label resolves from `role.key.label` in the installed console bundle.
  late final TomFormStringInput key;

  /// Human-facing role name. Label resolves from `role.name.label`.
  late final TomFormStringInput name;

  /// The fields the screen renders, in order.
  List<TomField<dynamic>> get editableFields => [key, name];

  /// Creates the fields (implementation half of the three-part split, G-UI-5).
  @override
  void createFormElements() {
    key = TomFormStringInput(
      'key',
      '',
      form: this,
      authorizer: TomAuthorizer.fixed(
        isCreate ? TomAuthState.full : TomAuthState.read,
      ),
      validators: [Validators.required()],
    );
    name = TomFormStringInput(
      'name',
      '',
      form: this,
      validators: [Validators.required()],
    );
  }
}
