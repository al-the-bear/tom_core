/// The showcase's **interactive-chrome** text bundle (G-RES-1).
///
/// A showcase deliberately splits its user-facing text into two categories:
///
/// - **Teaching text is intentionally hardcoded** — group titles/summaries and
///   the verbatim code-snippet bodies (`ShowcaseCell.code`) plus the
///   direct-parameter demo widgets they render (`label:`/`text:`/`tooltip:`
///   inside a snippet). These are a documented copy-paste exemption: a reader
///   must be able to lift a snippet into their own project with nothing to wire
///   up first, so they carry their literals inline (see `main.dart`).
/// - **Interactive chrome is a resource** — strings on the showcase's *own*
///   affordances (the code panel's copy-button tooltip) are real application
///   chrome, not teaching snippets, so G-RES-1 applies and they resolve through
///   the installed [TomTextResourceProvider].
///
/// This bundle holds only that second category. `main` installs it before the
/// first frame and the widget tests install it in their `setUp`, so
/// `TomCtr.text('showcase.…')` resolves to the value below rather than echoing
/// the key back as a development indicator.
///
/// Shared in shape with `core_flutter_ui_showcase` / `core_flutter_acl_sample`
/// / `core_flutter_acl_responsive`.
library;

/// The installed interactive-chrome bundle. Flat dotted keys → display values.
const Map<String, dynamic> chromeTexts = <String, dynamic>{
  // Home screen: the app-bar title (showcase_app.dart). `MaterialApp.title` stays
  // hardcoded — that is OS-level app identity, not on-screen copy.
  'showcase.app.title': 'Tom Flutter UI — Forms Showcase',

  // Code panel: the copy-to-clipboard affordance tooltip (common/code_block.dart).
  'showcase.codeBlock.copyTooltip': 'Copy snippet',
};
