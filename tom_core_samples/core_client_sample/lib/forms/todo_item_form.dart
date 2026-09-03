/// The todo editor — a `TomForm` bound to a [TodoItem], with each field gated
/// by the session's resolved [TomAuthState] for the current role.
///
/// This is where the four-state authorization model meets a real editing form:
/// the [fieldStates] map (keyed by the gradable field resource keys) is turned
/// into a per-field [TomAuthorizer.fixed], so the *same* form renders four ways
/// depending on who is signed in — `owner` edits everything, `member` can't see
/// `priority` (none) and can't change the assignee (read), `viewer` toggles
/// nothing. Field member names match the entity's so the reflection round-trip
/// `bind`/`save` performs writes straight into the bound [TodoItem].
///
/// The form carries no hardcoded label text (G-RES-1) and no `*ResourceKeys`
/// catalogue class (G-RES-6): each field self-addresses by a **single field
/// identity** (G-UI-6) — the form's `basePath` plus the field's `tomId`.
///
/// That `basePath` is built the way the framework builds every path: by
/// *joining segments*. The form runs under scope [todoScopeId] (`todo`) with
/// `formId` [todoItemFormId] (`item`), and `TomForm.prepareForSelfObservation`
/// composes `basePath = todo.item` from the two. So every field's `basePath` is
/// `todo.item.<tomId>`, which is *simultaneously* the label key base
/// (`todo.item.<tomId>.label`, resolved from the installed [appTexts] bundle)
/// and the authz/wire key the server seeds and the field-state matrix is keyed
/// by. There is no second `todoItem.*` addressing scheme beside the wire keys.
///
/// A scope id is a **single** path segment: the kernel refuses one containing
/// the `.` separator, because `'todo.item'` under no parent would render
/// identically to the unrelated chain `'todo'` → `'item'` and a scope named
/// from data could then reach another scope's resources. Hence two segments and
/// an enclosing scope rather than one dotted `formId`. The screen and the tests
/// therefore build the form inside `TomScope.withScope(todoScopeId, ...)`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:todo_domain/todo_domain.dart';

/// The scope the form runs under — the first segment of every field identity.
///
/// The screen and the tests push it with `TomScope.withScope` before building
/// the form; `TomForm` then qualifies its `formId` against it.
const String todoScopeId = 'todo';

/// The form's own id — the second segment. `TomForm` joins it onto the enclosing
/// scope to get the form's `basePath`, and pushes it as a nested scope while the
/// fields are created.
const String todoItemFormId = 'item';

/// The single resource key prefix every [TodoItemForm] field derives its
/// identity from: label key `todo.item.<tomId>.label` and authz/wire key
/// `todo.item.<tomId>` are both composed from this one string.
///
/// It is deliberately **not** a literal. It is joined from the same two
/// segments the framework joins to build the form's `basePath`, so the constant
/// the grant lookup composes from cannot drift away from the path the fields
/// actually carry — the one identity this sample exists to demonstrate.
const String todoItemKey = '$todoScopeId.$todoItemFormId';

/// A bound, authorization-aware editor for a single [TodoItem].
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  /// Creates the form, applying [fieldStates] (the session's resolved matrix
  /// for the signed-in role) to each gradable field.
  ///
  /// Build it under the enclosing [todoScopeId] scope —
  /// `TomScope.withScope(todoScopeId, () => TodoItemForm(states))` — so its
  /// single-segment `formId` qualifies to `todo.item` and the fields resolve at
  /// `todo.item.<tomId>`.
  ///
  /// A field absent from [fieldStates] degrades to [TomAuthState.none] (the
  /// closed-safe default), matching the api's resolver — so an unconfigured
  /// field hides rather than leaking an editable control. The non-gradable
  /// fields ([description]) are always [TomAuthState.full].
  TodoItemForm(this.fieldStates) : super(formId: todoItemFormId);

  /// The resolved [TomAuthState] per gradable-field resource key.
  final Map<String, TomAuthState> fieldStates;

  /// Builds the fixed authorizer for the field named [tomId], resolving its
  /// grade from the matrix under the same identity its `basePath` uses:
  /// `todo.item.<tomId>` (so the label and grant keys never diverge).
  TomAuthorizer _authFor(String tomId) =>
      TomAuthorizer.fixed(fieldStates['$todoItemKey.$tomId'] ?? TomAuthState.none);

  /// Title — required free text.
  ///
  /// Illustrates the G-UI-7 *merge*: `TomField` runs this form's code-supplied
  /// [_noSurroundingSpace] validator **and** the `required` validator declared
  /// as a resource under `todo.item.title.validators`. `required` is the
  /// framework built-in (naturally a resource); the whitespace rule is
  /// app-specific and orthogonal to any built-in, so it stays in code — which is
  /// exactly when a code validator is the right tool. Both error messages
  /// (`error.required`, `error.titleWhitespace`) resolve from the bundle.
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
    authorizer: _authFor('title'),
    validators: [_noSurroundingSpace],
  );

  /// Free-text description — always editable (not part of the grant matrix).
  late final description = TomFormStringInput(
    'description',
    '',
    form: this,
    maxLines: 3,
  );

  /// Done flag — rendered as a switch, gated by the `done` grant.
  late final done = TomFormBoolSwitch(
    'done',
    false,
    form: this,
    authorizer: _authFor('done'),
  );

  /// Priority — a dropdown over the [TodoPriority] names, gated by `priority`.
  late final priority = TomFormStringDropdown(
    'priority',
    TodoPriority.medium.name,
    form: this,
    source: _prioritySource,
    authorizer: _authFor('priority'),
  );

  /// Assignee id — gated by `assigneeId`.
  late final assigneeId = TomFormStringInput(
    'assigneeId',
    '',
    form: this,
    authorizer: _authFor('assigneeId'),
  );

  @override
  void createFormElements() {}
}

/// An app-specific code validator: the title must carry no leading or trailing
/// whitespace. It passes on the empty string (so the resource-declared
/// `required` is the one that reports a missing title) and fails only on a
/// value that differs from its trimmed form. Its `error.titleWhitespace` key
/// resolves as a resource exactly like the built-ins' keys (G-RES-1).
ValidationResult _noSurroundingSpace(String value) => value.trim() != value
    ? const ValidationError('error.titleWhitespace')
    : const ValidationSuccess();

/// The priority options: valued by the enum name the entity stores, labelled
/// from `global.todopriority.<value>` in the installed bundle (G-RES-5). The
/// source resolves each label on read and re-emits when the bundle changes, so
/// there is no Dart-side label table and a locale switch relabels the dropdown
/// without rebuilding the form.
final TomSelectableSource<String> _prioritySource =
    TomEnumNameSelectableSource(TodoPriority.values);
