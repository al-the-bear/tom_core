/// Authorization group — the four-state authorization model.
///
/// Every Tom widget carries an [authorizer]. The resolved [TomAuthState]
/// decides how the widget renders, independent of any business logic:
///
/// * [TomAuthState.none] — hidden; the element does not exist for the user.
/// * [TomAuthState.disabled] — visible but greyed out and non-interactive.
/// * [TomAuthState.read] — shows its value but cannot be modified.
/// * [TomAuthState.full] — fully interactive and editable.
///
/// Here each cell pins a single state with [TomAuthorizer.fixed] so the four
/// renderings can be compared side by side. In real applications the state
/// flows from a resource provider or an action controller instead.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// Puts [gated] between two labels, so a state that renders nothing shows as
/// the labels closing up rather than as an empty preview. They sit flush
/// against it: whatever space shows between them is the widget's own.
Widget _betweenLabels(Widget gated) => TomRow(
  mainAxisSize: MainAxisSize.min,
  children: [
    TomText(text: '[Before]'),
    gated,
    TomText(text: '[After]'),
  ],
);

/// The Authorization component group.
final ShowcaseGroup authorizationGroup = ShowcaseGroup(
  id: 'authorization',
  title: 'Four-state authorization',
  summary:
      'none, disabled, read and full — the TomAuthState model that '
      'drives how every Tom widget renders, shown with TomAuthorizer.fixed.',
  icon: Icons.shield_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomAuthState.full',
      note:
          'Fully interactive and editable — the default for an '
          'unconstrained widget.',
      code:
          "TomElevatedButton(\n"
          "  authorizer: TomAuthorizer.fixed(TomAuthState.full),\n"
          "  label: 'Approve',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomElevatedButton(
        authorizer: TomAuthorizer.fixed(TomAuthState.full),
        label: 'Approve',
        onPressed: () {},
      ),
    ),
    ShowcaseCell(
      title: 'TomAuthState.read',
      note: 'Visible and shows its value, but cannot be activated.',
      code:
          "TomElevatedButton(\n"
          "  authorizer: TomAuthorizer.fixed(TomAuthState.read),\n"
          "  label: 'Approve',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomElevatedButton(
        authorizer: TomAuthorizer.fixed(TomAuthState.read),
        label: 'Approve',
        onPressed: () {},
      ),
    ),
    ShowcaseCell(
      title: 'TomAuthState.disabled',
      note: 'Greyed out — the data may exist but is not accessible here.',
      code:
          "TomElevatedButton(\n"
          "  authorizer: TomAuthorizer.fixed(TomAuthState.disabled),\n"
          "  label: 'Approve',\n"
          "  onPressed: () {},\n"
          ")",
      child: TomElevatedButton(
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
        label: 'Approve',
        onPressed: () {},
      ),
    ),
    ShowcaseCell(
      title: 'TomAuthState.none',
      note:
          'Hidden entirely — the button collapses to nothing, so the two '
          'labels either side of it close up.',
      code:
          "TomElevatedButton(\n"
          "  authorizer: TomAuthorizer.fixed(TomAuthState.none),\n"
          "  label: 'Approve',\n"
          "  onPressed: () {},\n"
          ")",
      child: _betweenLabels(
        TomElevatedButton(
          authorizer: TomAuthorizer.fixed(TomAuthState.none),
          label: 'Approve',
          onPressed: () {},
        ),
      ),
    ),
  ],
);
