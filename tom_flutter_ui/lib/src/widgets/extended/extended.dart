/// Extended Flutter widgets using the TomWidgetMixin pattern.
///
/// These widgets EXTEND their Flutter originals instead of composing them,
/// preserving type identity for Flutter's `is` checks and type constraints.
///
/// Widget categories:
/// - **StatelessWidget** — override `build()`, use mixin helpers
/// - **StatefulWidget** — State overrides `build()`, accesses `widget.helpers`
/// - **ParentDataWidget** — no build override, parent container filters children
library;

export 'tom_tab_extended.dart';
export 'tom_popup_menu_item_extended.dart';
export 'tom_expanded_extended.dart';
