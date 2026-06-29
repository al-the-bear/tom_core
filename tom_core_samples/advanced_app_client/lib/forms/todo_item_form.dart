/// The item editor — a `TomForm` bound to a [TodoItem], with each gradable
/// field gated by the session's resolved [TomAuthState] for the current role
/// (step 30).
///
/// This is where the four-state authorization model meets a real editing form:
/// the [fieldStates] map (keyed by [TodoItemResourceKeys]) is turned into a
/// per-field [TomAuthorizer.fixed], so the *same* form renders four ways
/// depending on who is signed in — `owner` edits everything; `editor` cannot
/// change the assignee or estimate (read); `commenter` cannot see priority or
/// estimate (none); `viewer` toggles nothing and the status control renders
/// disabled. A field absent from [fieldStates] degrades to [TomAuthState.none]
/// (the closed-safe default — hidden, never a leaked editable control),
/// matching the server's resolver.
///
/// The form runs under scope [TodoItemResourceKeys.scope] (`'todo'`) with
/// `formId` [TodoItemResourceKeys.formId] (`'item'`), and each field's `tomId`
/// is sourced from the matching `*Field` token, so every field's `basePath`
/// equals its wire resource key (`todo.item.title`, …). That is what lets the
/// installed [FieldStateAuthorizationAdapter] (todo 3) resolve each field's grade
/// implicitly through layer-1 `TomAuthorization.resolveAuth(basePath)` — the keys
/// and the `tomId`s share the one origin in [TodoItemResourceKeys], so they
/// cannot drift.
///
/// Reflected *member* names still match the entity's field names so the
/// reflection round-trip `bind`/`save` writes straight into the bound [TodoItem]
/// by member name (independent of `tomId`). The estimate field is the entity's
/// `estimateHours` member, but its `tomId` (and thus grade key) is
/// [TodoItemResourceKeys.estimateField] (`'estimate'`) — the key names the
/// concept, not the storage field.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A bound, authorization-aware editor for a single [TodoItem].
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  /// Creates the form, applying [fieldStates] (the session's resolved matrix
  /// for the signed-in role) to each gradable field.
  TodoItemForm(this.fieldStates)
      : super(formId: TodoItemResourceKeys.formId);

  /// The resolved [TomAuthState] per [TodoItemResourceKeys] resource key.
  final Map<String, TomAuthState> fieldStates;

  TomAuthorizer _authFor(String key) =>
      TomAuthorizer.fixed(fieldStates[key] ?? TomAuthState.none);

  /// Title — required free text.
  late final title = TomFormStringInput(
    TodoItemResourceKeys.titleField,
    '',
    form: this,
    labelTextOverride: 'Title',
    authorizer: _authFor(TodoItemResourceKeys.title),
    validators: [Validators.required()],
  );

  /// Workflow status — a dropdown over the [TodoStatus] names.
  late final status = TomFormStringDropdown(
    TodoItemResourceKeys.statusField,
    TodoStatus.backlog.name,
    form: this,
    source: _statusSource,
    labelTextOverride: 'Status',
    authorizer: _authFor(TodoItemResourceKeys.status),
  );

  /// Priority — a dropdown over the [TodoPriority] names.
  late final priority = TomFormStringDropdown(
    TodoItemResourceKeys.priorityField,
    TodoPriority.medium.name,
    form: this,
    source: _prioritySource,
    labelTextOverride: 'Priority',
    authorizer: _authFor(TodoItemResourceKeys.priority),
  );

  /// Assignee id — free text (gated; an editor sees this read-only).
  late final assigneeId = TomFormStringInput(
    TodoItemResourceKeys.assigneeIdField,
    '',
    form: this,
    labelTextOverride: 'Assignee id',
    authorizer: _authFor(TodoItemResourceKeys.assigneeId),
  );

  /// Optional due date.
  late final dueDate = TomFormNDateInput(
    TodoItemResourceKeys.dueDateField,
    null,
    form: this,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    labelTextOverride: 'Due date',
    authorizer: _authFor(TodoItemResourceKeys.dueDate),
  );

  /// Optional effort estimate in hours. The reflected member stays
  /// `estimateHours` (so `bind`/`save` round-trips into the entity), but the
  /// `tomId` is [TodoItemResourceKeys.estimateField] (`'estimate'`) so the
  /// field self-addresses as the graded key `todo.item.estimate` (D-A2).
  late final estimateHours = TomFormNDoubleInput(
    TodoItemResourceKeys.estimateField,
    null,
    form: this,
    decimals: 1,
    labelTextOverride: 'Estimate (h)',
    authorizer: _authFor(TodoItemResourceKeys.estimate),
  );

  /// Free-text description.
  late final description = TomFormStringInput(
    TodoItemResourceKeys.descriptionField,
    '',
    form: this,
    labelTextOverride: 'Description',
    maxLines: 3,
    authorizer: _authFor(TodoItemResourceKeys.description),
  );

  /// The gradable fields, in display order — the screen lays these out and the
  /// Save action is offered only when at least one is editable.
  List<TomField<dynamic>> get gradableFields =>
      [title, status, priority, assigneeId, dueDate, estimateHours, description];

  @override
  void createFormElements() {}
}

/// The status options, labelled from [TodoStatus.label] and valued by the enum
/// name the entity stores.
final TomSelectableSource<String> _statusSource = StaticSelectableSource(
  [
    for (final s in TodoStatus.values)
      SelectableItem<String>(value: s.name, label: s.label),
  ],
);

/// The priority options, labelled from [TodoPriority.label] and valued by the
/// enum name the entity stores.
final TomSelectableSource<String> _prioritySource = StaticSelectableSource(
  [
    for (final p in TodoPriority.values)
      SelectableItem<String>(value: p.name, label: p.label),
  ],
);
