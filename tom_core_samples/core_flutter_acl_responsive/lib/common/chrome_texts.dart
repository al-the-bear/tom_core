/// The showcase's resource bundles (G-RES-1) and the boundary between them.
///
/// A showcase splits its user-facing text into three categories, and only the
/// first is exempt from the resource rule:
///
/// - **Teaching text is intentionally hardcoded** — group titles/summaries and
///   the code-snippet bodies ([ShowcaseCell.code]) plus the
///   direct-parameter demo widgets they render (`label:`/`text:`/`tooltip:`
///   inside a snippet). These are a documented copy-paste exemption: a reader
///   must be able to lift a snippet into their own project with nothing to wire
///   up first, so they carry their literals inline (see `main.dart`).
/// - **Interactive chrome is a resource** — strings on the showcase's *own*
///   affordances (the code panel's copy-button tooltip) are real application
///   chrome, not teaching snippets, so G-RES-1 applies and they resolve through
///   the installed [TomTextResourceProvider]. See [chromeTexts].
/// - **Validation messages are resources** — and are the category with teeth,
///   because an undeclared one does not fail: it renders as its own key. See
///   [companyValidationTexts].
///
/// [showcaseTexts] is the union, and is what `main` installs before the first
/// frame and what every test installs in its `setUp`, so `TomCtr.text('…')`
/// resolves to a value below rather than echoing the key back as a development
/// indicator.
library;

/// Strings on the showcase's own interactive affordances. Flat dotted keys →
/// display values.
const Map<String, dynamic> chromeTexts = <String, dynamic>{
  // Home screen: the app-bar title (showcase_app.dart). `MaterialApp.title` stays
  // hardcoded — that is OS-level app identity, not on-screen copy.
  'showcase.app.title': 'Tom Flutter UI — Responsive Showcase',

  // Code panel: the copy-to-clipboard affordance tooltip (common/code_block.dart).
  'showcase.codeBlock.copyTooltip': 'Copy snippet',
};

/// Validator messages for `CompanyForm` (G-UI-7 / G-RES-1).
///
/// **A validator carries a key, never a sentence.** `Validators.required()`
/// emits `error.required`, `Validators.minLength(2)` emits `error.minLength`
/// with `params: {'min': 2}`, and a `Validators.pattern(...)` emits whatever
/// `errorKey` it was given. The field resolves that key against
/// `<basePath>.<key>` first (so one field can override a shared message), then
/// the bare `<key>` — which is the level these entries sit at, since the wording
/// is the same wherever the rule is used.
///
/// **Why this map is load-bearing rather than decorative.** Resolution's last
/// step is to return *the key itself* as a development indicator. So a key no
/// bundle defines does not throw, log, or render blank — it renders as
/// `error.invalidUrl`, which reads enough like a message to survive review and
/// any test that merely asserts an error appeared. `validation_message_test.dart`
/// therefore asserts the human sentences by name and sweeps the tree for
/// anything still starting with `error.`. Adding a validator whose `errorKey` is
/// not defined here is a failing build.
///
/// `{min}` is interpolated from the validator's `params` at resolution time, so
/// the bound is stated once — in `company_form.dart` — and never duplicated as
/// prose here.
const Map<String, dynamic> companyValidationTexts = <String, dynamic>{
  // Built-ins. Their key names come from `Validators`, not from this sample.
  'error.required': 'This field is required.',
  'error.minLength': 'Use at least {min} characters.',

  // Custom pattern rules named by `errorKey:` in company_form.dart. They keep
  // the framework's `error.` prefix so they sit in the same namespace as the
  // built-ins and resolve through the identical chain.
  'error.taxIdFormat':
      'Use capital letters, digits and hyphens only — for example DE-1234.',
  'error.invalidUrl': 'Enter a full web address, starting with https://.',
};

/// The installed bundle: every resource-resolved string in the showcase.
const Map<String, dynamic> showcaseTexts = <String, dynamic>{
  ...chromeTexts,
  ...companyValidationTexts,
};
