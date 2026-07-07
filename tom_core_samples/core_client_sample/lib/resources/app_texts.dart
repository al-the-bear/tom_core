/// The client's user-facing text bundle (G-RES-1).
///
/// Every visible string the app renders is a resource key resolved through the
/// singleton [TomTextResourceProvider] — no widget carries a hardcoded label,
/// hint, title, tooltip or error message. `main` installs this bundle before the
/// first frame (and the widget tests install it in their `setUp`), so a form
/// field's label resolves from `<scope>.<tomId>.label`, a screen resolves its
/// copy through [TomCtr.text], and a domain enum resolves its display text from
/// its `global.<enumtype>.<value>` key ([EnumResourceKey.resourceKey], G-RES-5).
///
/// The keys are flat dotted paths (the provider looks a flat key up directly);
/// their **values are byte-identical** to the literals they replaced, so nothing
/// the user sees changed — only where the string lives did. Parameterised copy
/// uses `{placeholder}` templates the call site fills with `replaceAll`.
///
/// Two boundaries are intentionally *not* in this bundle: `MaterialApp.title`
/// (OS-level app identity, not screen copy) and the non-user-facing diagnostic
/// `No todo item with id "…"` (a programmer-facing invariant, never rendered).
library;

/// The installed text bundle. Flat dotted keys → byte-identical display values.
const Map<String, dynamic> appTexts = {
  // --- Login form fields (scope 'login') ---
  'login.username.label': 'Username',
  'login.username.hintText': 'alice, bob or val',
  'login.password.label': 'Password',

  // --- Login screen ---
  'login.appbar.title': 'Tom Todo — sign in',
  'login.intro': 'Try alice, bob or val (any non-empty password).',
  'login.submit': 'Sign in',
  'login.error.unknownAccount': 'Unknown account. Try alice, bob or val.',
  'login.error.emptyPassword': 'Password must not be empty.',

  // --- Todo item form fields (scope 'todoItem') ---
  'todoItem.title.label': 'Title',
  'todoItem.description.label': 'Description',
  'todoItem.done.label': 'Done',
  'todoItem.priority.label': 'Priority',
  'todoItem.assigneeId.label': 'Assignee id',

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
};
