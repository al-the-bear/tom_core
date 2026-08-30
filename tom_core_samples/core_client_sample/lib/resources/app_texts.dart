/// The client's user-facing text bundle (G-RES-1).
///
/// Every visible string the app renders is a resource key resolved through the
/// singleton [TomTextResourceProvider] — no widget carries a hardcoded label,
/// hint, title, tooltip or error message. `main` installs this bundle before the
/// first frame (and the widget tests install it in their `setUp`), so a form
/// field's label resolves from `<scope>.<tomId>.label`, a screen resolves its
/// copy through [TomCtr.text], and a domain enum resolves its display text from
/// its `global.<enumtype>.<value>` key — derived and resolved by the framework's
/// `TomObservableEnum` (G-RES-5), so no Dart-side label table stands between the
/// enum and this bundle.
///
/// The keys are flat dotted paths (the provider looks a flat key up directly)
/// and the values are the display strings themselves — this bundle is the one
/// place the app's copy lives. Parameterised copy uses `{placeholder}`
/// templates the call site fills with `replaceAll`.
///
/// Two boundaries are intentionally *not* in this bundle: `MaterialApp.title`
/// (OS-level app identity, not screen copy) and the non-user-facing diagnostic
/// `No todo item with id "…"` (a programmer-facing invariant, never rendered).
///
/// **Field validators are resources too (G-UI-7).** Each validated field
/// declares its validators by name under `<basePath>.validators` (a
/// comma-separated spec, e.g. `required` or `minLength:8`); `TomField` resolves
/// them through the DI-swappable `TomValidatorRegistry` and *merges* them with
/// any code-supplied validators the form passes in its constructor. The
/// validators' error messages are ordinary resources too — a failed validator
/// emits an `error.<name>` key that resolves here (scoped `<basePath>.<key>`
/// first, then global `<key>`), so no message string is ever hardcoded.
library;

/// The installed text bundle: flat dotted keys → display strings.
const Map<String, dynamic> appTexts = {
  // --- Login form fields (scope 'login') ---
  'login.username.label': 'Username',
  'login.username.hintText': 'alice, bob or val',
  // Resource-declared validator (G-UI-7): resolved by name through the
  // TomValidatorRegistry, not hand-coded in the form.
  'login.username.validators': 'required',
  'login.password.label': 'Password',
  'login.password.validators': 'required',

  // --- Login screen ---
  'login.appbar.title': 'Tom Todo — sign in',
  'login.intro': 'Try alice, bob or val (any non-empty password).',
  'login.submit': 'Sign in',
  'login.error.unknownAccount': 'Unknown account. Try alice, bob or val.',
  'login.error.emptyPassword': 'Password must not be empty.',

  // --- Todo item form fields (scope 'todo.item' — the single field identity
  //     shared with the authz/wire keys, G-UI-6) ---
  'todo.item.title.label': 'Title',
  // Resource-declared `required` (G-UI-7) that the form *merges* with a
  // code-supplied validator in TodoItemForm — see todo_item_form.dart.
  'todo.item.title.validators': 'required',
  'todo.item.description.label': 'Description',
  'todo.item.done.label': 'Done',
  'todo.item.priority.label': 'Priority',
  'todo.item.assigneeId.label': 'Assignee id',

  // --- Todo list screen ---
  'todos.appbar.title': 'Todos',
  'todos.role': 'role: {role}',
  'todos.action.refreshLive': 'Refresh from live server',
  'todos.action.refresh': 'Refresh',
  'todos.action.logout': 'Log out',
  'todos.action.new': 'New todo',
  'todos.live.loaded': 'Loaded {count} item(s) from the live server.',
  'todos.live.unreachable': 'Live server unreachable: {error}',
  'todos.live.banner': 'Showing live server data (read-only).',
  'todos.live.back': 'Back to my list',
  'todos.empty': 'No todos yet.',

  // --- Todo detail screen ---
  'todoDetail.title.new': 'New todo',
  'todoDetail.title.edit': 'Edit todo',
  'todoDetail.action.delete': 'Delete',
  'todoDetail.action.save': 'Save',

  // --- Enum display text (G-RES-5): global.<enumtype>.<value> ---
  'global.todopriority.low': 'Low',
  'global.todopriority.medium': 'Medium',
  'global.todopriority.high': 'High',
  'global.todopriority.critical': 'Critical',
  'global.todolabel.feature': 'Feature',
  'global.todolabel.bug': 'Bug',
  'global.todolabel.chore': 'Chore',
  'global.todolabel.docs': 'Docs',
  'global.todolabel.research': 'Research',

  // --- Validator error messages (G-UI-7 / G-RES-1): error.<name> keys ---
  // A failed validator emits an `error.<name>` key (built-ins use `error.required`,
  // `error.minLength`, …); the field resolves it here so no message is hardcoded.
  // These are global keys — any field's failure resolves through them unless a
  // field provides a scoped `<basePath>.error.<name>` override.
  'error.required': 'This field is required.',
  // The message for TodoItemForm's code-supplied title validator.
  'error.titleWhitespace': 'Title cannot have leading or trailing spaces.',
};
