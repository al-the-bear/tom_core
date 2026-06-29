/// The item editor — a `TomForm` bound to a [TodoItem] (step 30), carrying **no**
/// authorization knowledge of its own.
///
/// This is where the four-state authorization model meets a real editing form,
/// but the gating is now entirely *implicit*: the form runs under scope
/// [TodoItemResourceKeys.scope] (`'todo'`) with `formId`
/// [TodoItemResourceKeys.formId] (`'item'`), and each field's `tomId` is sourced
/// from the matching `*Field` token, so every field's `basePath` equals its wire
/// resource key (`todo.item.title`, …). The installed
/// [FieldStateAuthorizationAdapter] (todo 3) — fed the signed-in role's matrix by
/// the session — then resolves each field's grade through layer-1
/// `TomAuthorization.resolveAuth(basePath)`. So the *same* form renders four ways
/// (owner edits everything; editor cannot change the assignee or estimate;
/// commenter cannot see priority or estimate; viewer toggles nothing and the
/// status control renders disabled) without the form holding any per-field
/// authorizer or grade map — the keys and the `tomId`s share the one origin in
/// [TodoItemResourceKeys], so they cannot drift.
///
/// Reflected *member* names still match the entity's field names so the
/// reflection round-trip `bind`/`save` writes straight into the bound [TodoItem]
/// by member name (independent of `tomId`). The estimate field is the entity's
/// `estimateHours` member, but its `tomId` (and thus grade key) is
/// [TodoItemResourceKeys.estimateField] (`'estimate'`) — the key names the
/// concept, not the storage field.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart' show tomReflector;
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A bound editor for a single [TodoItem]; authorization is resolved implicitly
/// through the installed adapter, not held on the form.
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  /// Creates the form. It carries no grade matrix: each field self-addresses as
  /// its resource key and the installed [FieldStateAuthorizationAdapter] grades
  /// it through layer-1 implicit authorization.
  TodoItemForm() : super(formId: TodoItemResourceKeys.formId);

  /// Title — required free text.
  late final title = TomFormStringInput(
    TodoItemResourceKeys.titleField,
    '',
    form: this,
    labelTextOverride: 'Title',
    validators: [Validators.required()],
  );

  /// Workflow status — a dropdown over the [TodoStatus] names.
  late final status = TomFormStringDropdown(
    TodoItemResourceKeys.statusField,
    TodoStatus.backlog.name,
    form: this,
    source: _statusSource,
    labelTextOverride: 'Status',
  );

  /// Priority — a dropdown over the [TodoPriority] names.
  late final priority = TomFormStringDropdown(
    TodoItemResourceKeys.priorityField,
    TodoPriority.medium.name,
    form: this,
    source: _prioritySource,
    labelTextOverride: 'Priority',
  );

  /// Assignee id — free text (gated; an editor sees this read-only).
  late final assigneeId = TomFormStringInput(
    TodoItemResourceKeys.assigneeIdField,
    '',
    form: this,
    labelTextOverride: 'Assignee id',
  );

  /// Optional due date.
  late final dueDate = TomFormNDateInput(
    TodoItemResourceKeys.dueDateField,
    null,
    form: this,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    labelTextOverride: 'Due date',
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
  );

  /// Free-text description.
  late final description = TomFormStringInput(
    TodoItemResourceKeys.descriptionField,
    '',
    form: this,
    labelTextOverride: 'Description',
    maxLines: 3,
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
