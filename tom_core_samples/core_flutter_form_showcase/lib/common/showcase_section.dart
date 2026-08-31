/// A capability group: the unit of navigation in the forms showcase.
///
/// Each group owns a title, a one-line summary, and a builder that produces the
/// list of [ShowcaseCell]s for that forms capability. The home screen lists
/// every group; tapping one opens a [GroupScreen] that scrolls its cells.
/// Shared in shape with `core_flutter_ui_showcase` / `core_flutter_acl_sample`
/// / `core_flutter_acl_responsive`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'showcase_cell.dart';

/// Describes one forms capability (field types, validation, layout, …).
class ShowcaseGroup {
  const ShowcaseGroup({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.cells,
  });

  /// Stable identifier (used by tests and routing).
  final String id;

  /// Display title, e.g. "Validation".
  final String title;

  /// One-line description shown on the home list tile.
  final String summary;

  /// Leading icon for the home list tile.
  final IconData icon;

  /// Builds the cells for this group. A builder (rather than a const list)
  /// lets interactive cells own their own state.
  final List<ShowcaseCell> Function(BuildContext context) cells;
}

/// A full-screen scroll of one group's cells.
// Why: extends [TomStatelessWidget] so the screen container is a Tom base too
// (G-UI-1/G-UI-2). It carries no tomId/resources, so a family base would be
// wrong; [TomStatelessWidget] is the sanctioned base for scope-participating
// chrome. Construction enters [TomScope.current] → the constructor is non-const.
class GroupScreen extends TomStatelessWidget {
  GroupScreen({super.key, required this.group});

  final ShowcaseGroup group;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomScaffold(
      appBar: TomAppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: TomText(text: group.title),
      ),
      body: TomListView(
        padding: const EdgeInsets.all(16),
        children: [
          TomText(text: group.summary, style: theme.textTheme.bodyLarge),
          TomSizedBox(height: 16),
          ...group.cells(context),
        ],
      ),
    );
  }
}
