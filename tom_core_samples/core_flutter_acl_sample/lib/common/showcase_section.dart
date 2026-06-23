/// A component group: the unit of navigation in the showcase.
///
/// Each group owns a title, a one-line summary, and a builder that produces
/// the list of [ShowcaseCell]s for that family. The home screen lists every
/// group; tapping one opens a [GroupScreen] that scrolls its cells.
library;

import 'package:flutter/material.dart';

import 'showcase_cell.dart';

/// Describes one component family (buttons, labels, ACL, …).
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

  /// Display title, e.g. "Buttons".
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
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.group});

  final ShowcaseGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(group.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(group.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...group.cells(context),
        ],
      ),
    );
  }
}
