/// The group editor — a `TomForm` bound to a [GroupDraft] (step 34).
///
/// The form owns only the group's name; membership is a list of user ids, not a
/// scalar field, so the screen edits it as a checklist alongside this form
/// rather than as a bound field.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/admin_drafts.dart';

/// A bound editor for a [GroupDraft]'s name.
@tomReflector
class GroupForm extends TomForm<GroupDraft> {
  /// Creates the group form.
  GroupForm() : super(formId: 'group');

  /// Human-facing group name. Label resolves from `group.name.label` in the
  /// installed console bundle.
  late final TomFormStringInput name;

  /// The fields the screen renders, in order.
  List<TomField<dynamic>> get editableFields => [name];

  /// Creates the fields (implementation half of the three-part split, G-UI-5).
  @override
  void createFormElements() {
    name = TomFormStringInput(
      'name',
      '',
      form: this,
      validators: [Validators.required()],
    );
  }
}
