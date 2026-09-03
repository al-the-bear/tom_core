/// The showcase's **interactive-chrome** text bundle (G-RES-1).
///
/// A showcase deliberately splits its user-facing text into two categories:
///
/// - **Teaching text is intentionally hardcoded** — group titles/summaries and
///   the code-snippet bodies ([ShowcaseCell.code]) plus the
///   direct-parameter demo widgets they render (`label:`/`text:`/`tooltip:`
///   inside a snippet). These are a documented copy-paste exemption: a reader
///   must be able to lift a snippet into their own project with nothing to wire
///   up first, so they carry their literals inline (see `main.dart`).
/// - **Interactive chrome is a resource** — text the tour puts on screen in its
///   own right, rather than inside a snippet, is real application copy, so
///   G-RES-1 applies and it resolves through the installed
///   [TomTextResourceProvider]. What decides the category is *where a string
///   renders*, not how it reads: the app-bar title goes through the bundle,
///   while the identical sentence in `MaterialApp.title` stays hardcoded beside
///   it, because that one names the app to the OS rather than to the reader.
///   [chromeTexts] below is the authoritative list, and each entry names the
///   call site that reads it.
///
/// This bundle holds only that second category. `main` installs it before the
/// first frame and the widget tests install it in their `setUp`, so
/// `TomCtr.text('showcase.…')` resolves to the value below rather than echoing
/// the key back as a development indicator.
///
/// Shared in shape with `core_flutter_ui_showcase` /
/// `core_flutter_acl_responsive` / `core_flutter_form_showcase`.
library;

/// The installed interactive-chrome bundle. Flat dotted keys → display values.
const Map<String, dynamic> chromeTexts = <String, dynamic>{
  // Home screen: the app-bar title (acl_app.dart). `MaterialApp.title` stays
  // hardcoded — that is OS-level app identity, not on-screen copy.
  'showcase.app.title': 'Tom Core — ACL Feature Tour',

  // Code panel: the copy-to-clipboard affordance tooltip (common/code_block.dart).
  'showcase.codeBlock.copyTooltip': 'Copy snippet',

  // Group-visibility demo: the switch label (groups/visibility_group.dart).
  'showcase.visibility.showDetails': 'Show details',
};
