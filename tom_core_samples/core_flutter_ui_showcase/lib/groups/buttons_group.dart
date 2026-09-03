/// Buttons group — the Tom button family.
///
/// Every cell renders a real `tom_flutter_ui` button next to the snippet that
/// builds it. The snippets use the direct `label:` / `icon:` / `child:`
/// constructors (no resource provider needed), so they are copy-paste ready.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Buttons component group.
final ShowcaseGroup buttonsGroup = ShowcaseGroup(
  id: 'buttons',
  title: 'Buttons',
  summary:
      'Elevated, filled, text, outlined, icon and floating action '
      'buttons — the full Tom button family.',
  icon: Icons.smart_button,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomElevatedButton',
      code:
          "TomElevatedButton(\n"
          "  label: 'Save',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomElevatedButton(label: 'Save', onPressed: () {}),
    ),
    ShowcaseCell(
      title: 'TomFilledButton (tonal)',
      code:
          "TomFilledButton(\n"
          "  tonal: true,\n"
          "  label: 'Continue',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomFilledButton(tonal: true, label: 'Continue', onPressed: () {}),
    ),
    ShowcaseCell(
      title: 'TomTextButton',
      code:
          "TomTextButton(\n"
          "  label: 'Learn more',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomTextButton(label: 'Learn more', onPressed: () {}),
    ),
    ShowcaseCell(
      title: 'TomOutlinedButton',
      code:
          "TomOutlinedButton(\n"
          "  label: 'Cancel',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomOutlinedButton(label: 'Cancel', onPressed: () {}),
    ),
    ShowcaseCell(
      title: 'TomIconButton',
      note:
          'An icon button needs a tooltip (or a tomId) so it has an '
          'accessible label.',
      code:
          "TomIconButton(\n"
          "  icon: const Icon(Icons.favorite),\n"
          "  tooltip: 'Favorite',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomIconButton(
        icon: const Icon(Icons.favorite),
        tooltip: 'Favorite',
        onPressed: () {},
      ),
    ),
    ShowcaseCell(
      title: 'TomFloatingActionButton',
      code:
          "TomFloatingActionButton(\n"
          "  heroTag: 'fab_showcase',\n"
          "  child: const Icon(Icons.add),\n"
          "  onPressed: () {},\n"
          ")",
      child: TomFloatingActionButton(
        heroTag: 'fab_showcase',
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    ),
    ShowcaseCell(
      title: 'Disabled state',
      note: 'Passing onPressed: null disables any Tom button.',
      code:
          "TomElevatedButton(\n"
          "  label: 'Unavailable',\n"
          "  onPressed: null,\n"
          ")",
      child: TomElevatedButton(label: 'Unavailable', onPressed: null),
    ),
  ],
);
