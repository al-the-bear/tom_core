/// The todo editor — a `TomForm` bound to a [TodoItem], with each field gated
/// by the session's resolved [TomAuthState] for the current role.
///
/// This is where the four-state authorization model meets a real editing form:
/// the [fieldStates] map (keyed by the [TodoFieldKeys] resource keys) is turned
/// into a per-field [TomAuthorizer.fixed], so the *same* form renders four ways
/// depending on who is signed in — `owner` edits everything, `member` can't see
/// `priority` (none) and can't change the assignee (read), `viewer` toggles
/// nothing. Field member names match the entity's so the reflection round-trip
/// `bind`/`save` performs writes straight into the bound [TodoItem].
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:todo_domain/todo_domain.dart';

import '../api/field_keys.dart';

/// A bound, authorization-aware editor for a single [TodoItem].
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  /// Creates the form, applying [fieldStates] (the session's resolved matrix
  /// for the signed-in role) to each gradable field.
  ///
  /// A field absent from [fieldStates] degrades to [TomAuthState.none] (the
  /// closed-safe default), matching the api's resolver — so an unconfigured
  /// field hides rather than leaking an editable control. The non-gradable
  /// fields ([description]) are always [TomAuthState.full].
  TodoItemForm(this.fieldStates) : super(formId: 'todoItem');

  /// The resolved [TomAuthState] per [TodoFieldKeys] resource key.
  final Map<String, TomAuthState> fieldStates;

  TomAuthorizer _authFor(String key) =>
      TomAuthorizer.fixed(fieldStates[key] ?? TomAuthState.none);

  /// Title — required free text.
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
    labelTextOverride: 'Title',
    authorizer: _authFor(TodoFieldKeys.title),
    validators: [Validators.required()],
  );

  /// Free-text description — always editable (not part of the grant matrix).
  late final description = TomFormStringInput(
    'description',
    '',
    form: this,
    labelTextOverride: 'Description',
    maxLines: 3,
  );

  /// Done flag — rendered as a switch, gated by the `done` grant.
  late final done = TomFormBoolSwitch(
    'done',
    false,
    form: this,
    labelTextOverride: 'Done',
    authorizer: _authFor(TodoFieldKeys.done),
  );

  /// Priority — a dropdown over the [TodoPriority] names, gated by `priority`.
  late final priority = TomFormStringDropdown(
    'priority',
    TodoPriority.medium.name,
    form: this,
    source: _prioritySource,
    labelTextOverride: 'Priority',
    authorizer: _authFor(TodoFieldKeys.priority),
  );

  /// Assignee id — gated by `assigneeId`.
  late final assigneeId = TomFormStringInput(
    'assigneeId',
    '',
    form: this,
    labelTextOverride: 'Assignee id',
    authorizer: _authFor(TodoFieldKeys.assigneeId),
  );

  @override
  void createFormElements() {}
}

/// The priority options, labelled from [TodoPriority.label] and valued by the
/// enum name the entity stores.
final TomSelectableSource<String> _prioritySource = StaticSelectableSource(
  [
    for (final p in TodoPriority.values)
      SelectableItem<String>(value: p.name, label: p.label),
  ],
);
