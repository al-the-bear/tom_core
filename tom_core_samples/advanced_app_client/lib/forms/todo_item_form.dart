/// The item editor — a `TomForm` bound to a [TodoItem] (step 30), carrying **no**
/// authorization knowledge of its own.
///
/// This is where the four-state authorization model meets a real editing form,
/// but the gating is now entirely *implicit*: the form runs under scope `'todo'`
/// with `formId: 'item'`, and each field declares its `tomId` directly as a
/// plain `String` (G-RES-6 / G-UI-6 — there is no resource-key constants class),
/// so every field's `basePath` equals its wire resource key (`todo.item.title`,
/// …). The installed [FieldStateAuthorizationAdapter] (todo 3) — fed the
/// signed-in role's matrix by the session — then resolves each field's grade
/// through layer-1 `TomAuthorization.resolveAuth(basePath)`. So the *same* form
/// renders four ways (owner edits everything; editor cannot change the assignee
/// or estimate; commenter cannot see priority or estimate; viewer toggles
/// nothing and the status control renders disabled) without the form holding any
/// per-field authorizer or grade map — a field's `tomId` and its wire key are
/// the one origin, resolved at use from scope + formId + tomId.
///
/// Reflected *member* names still match the entity's field names so the
/// reflection round-trip `bind`/`save` writes straight into the bound [TodoItem]
/// by member name (independent of `tomId`). The estimate field is the entity's
/// `estimateHours` member, but its `tomId` (and thus grade key) is `'estimate'`
/// — the key names the concept, not the storage field.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart' show tomReflector;
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/enum_text.dart';

/// A bound editor for a single [TodoItem]; authorization is resolved implicitly
/// through the installed adapter, not held on the form.
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  /// Creates the form. It carries no grade matrix: each field self-addresses as
  /// its resource key and the installed [FieldStateAuthorizationAdapter] grades
  /// it through layer-1 implicit authorization.
  TodoItemForm() : super(formId: 'item');

  /// Title — required free text. Label resolves from `todo.item.title.label` in
  /// the installed full bundle.
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
    validators: [Validators.required()],
  );

  /// Workflow status — a dropdown over the [TodoStatus] names.
  late final status = TomFormStringDropdown(
    'status',
    TodoStatus.backlog.name,
    form: this,
    source: _enumSource(TodoStatus.values),
  );

  /// Priority — a dropdown over the [TodoPriority] names.
  late final priority = TomFormStringDropdown(
    'priority',
    TodoPriority.medium.name,
    form: this,
    source: _enumSource(TodoPriority.values),
  );

  /// Assignee id — free text (gated; an editor sees this read-only).
  late final assigneeId = TomFormStringInput(
    'assigneeId',
    '',
    form: this,
  );

  /// Optional due date.
  late final dueDate = TomFormNDateInput(
    'dueDate',
    null,
    form: this,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  /// Optional effort estimate in hours. The reflected member stays
  /// `estimateHours` (so `bind`/`save` round-trips into the entity), but the
  /// `tomId` is `'estimate'` so the field self-addresses as the graded key
  /// `todo.item.estimate` (D-A2).
  late final estimateHours = TomFormNDoubleInput(
    'estimate',
    null,
    form: this,
    decimals: 1,
  );

  /// Free-text description.
  late final description = TomFormStringInput(
    'description',
    '',
    form: this,
    maxLines: 3,
  );

  /// The gradable fields, in display order — the screen lays these out and the
  /// Save action is offered only when at least one is editable.
  List<TomField<dynamic>> get gradableFields =>
      [title, status, priority, assigneeId, dueDate, estimateHours, description];

  @override
  void createFormElements() {}
}

/// Builds a dropdown source over [values]: each option is valued by the enum
/// [Enum.name] the entity stores and labelled from the resource bundle via
/// [enumText] (G-RES-5). The source is built when the form's field is
/// constructed — i.e. after the session installs the server-sent bundle — so the
/// options render server-delivered text rather than any hardcoded string.
TomSelectableSource<String> _enumSource(List<Enum> values) =>
    StaticSelectableSource(
      [
        for (final v in values)
          SelectableItem<String>(value: v.name, label: enumText(v)),
      ],
    );
