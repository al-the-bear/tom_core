/// Authorization group — the four-state model, gated inside ACL rows.
///
/// Every Tom widget carries an [authorizer]; the resolved [TomAuthState]
/// decides how it renders, independent of business logic:
///
/// * [TomAuthState.none] — hidden; the element does not exist for the user.
/// * [TomAuthState.disabled] — visible but greyed out and non-interactive.
/// * [TomAuthState.read] — shows its value but cannot be modified.
/// * [TomAuthState.full] — fully interactive and editable.
///
/// Here each cell places a [TomElevatedButton] pinned to one state (via
/// [TomAuthorizer.fixed]) inside an [AclBuilder] row, so the gating composes
/// with the layout engine. `disabled` and `read` render **distinctly** — they
/// are separate renderings, not two names for the same greying. In a real app
/// the state flows from a resource provider or action controller.
///
/// Maps to the verified `widget_demos/demo_28_authorization.dart` and
/// `tom_flutter_ui/lib/src/widget_base/tom_policy_node_base.dart`. This is the
/// one group in the sample whose source sits outside `acl_demos/`, and it is
/// meant to: authorization is a widget-base capability that *composes* with the
/// layout engine rather than a layout capability of its own. That is also why
/// the group earns a place in an ACL sample: only a cell that puts the two
/// together shows what a state does to the *row* — a `none` button collapses to
/// nothing and leaves its label box behind, which neither source demonstrates
/// on its own.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

Widget _gatedRow(String label, TomAuthState state, Color color) => AclBuilder()
    .append(demoBox(label, color))
    .setPSize(120)
    .append(
      TomElevatedButton(
        authorizer: TomAuthorizer.fixed(state),
        label: 'Approve',
        onPressed: () {},
      ),
      dist: 12,
    )
    .build();

/// The four-state authorization capability group.
final ShowcaseGroup authorizationGroup = ShowcaseGroup(
  id: 'authorization',
  title: 'Four-state authorization',
  summary:
      'none, disabled, read and full — the TomAuthState model gating a '
      'button inside an ACL row, each state rendering distinctly.',
  icon: Icons.shield_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomAuthState.full',
      note: 'Fully interactive and editable — the unconstrained default.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('full', green)).setPSize(120)\n"
          '    .append(\n'
          '      TomElevatedButton(\n'
          '        authorizer: TomAuthorizer.fixed(TomAuthState.full),\n'
          "        label: 'Approve', onPressed: () {},\n"
          '      ),\n'
          '      dist: 12,\n'
          '    )\n'
          '    .build()',
      child: _gatedRow('full', TomAuthState.full, Colors.green),
    ),
    ShowcaseCell(
      title: 'TomAuthState.read',
      note: 'Visible and shows its value, but cannot be activated.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('read', blue)).setPSize(120)\n"
          '    .append(\n'
          '      TomElevatedButton(\n'
          '        authorizer: TomAuthorizer.fixed(TomAuthState.read),\n'
          "        label: 'Approve', onPressed: () {},\n"
          '      ),\n'
          '      dist: 12,\n'
          '    )\n'
          '    .build()',
      child: _gatedRow('read', TomAuthState.read, Colors.blue),
    ),
    ShowcaseCell(
      title: 'TomAuthState.disabled',
      note: 'Greyed out and non-interactive — distinct from read-only.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('disabled', orange)).setPSize(120)\n"
          '    .append(\n'
          '      TomElevatedButton(\n'
          '        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),\n'
          "        label: 'Approve', onPressed: () {},\n"
          '      ),\n'
          '      dist: 12,\n'
          '    )\n'
          '    .build()',
      child: _gatedRow('disabled', TomAuthState.disabled, Colors.orange),
    ),
    ShowcaseCell(
      title: 'TomAuthState.none',
      note:
          'Hidden entirely — the button collapses to nothing, leaving only '
          'the label box in the row.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('none', grey)).setPSize(120)\n"
          '    .append(\n'
          '      TomElevatedButton(\n'
          '        authorizer: TomAuthorizer.fixed(TomAuthState.none),\n'
          "        label: 'Approve', onPressed: () {},\n"
          '      ),\n'
          '      dist: 12,\n'
          '    )\n'
          '    .build()',
      child: _gatedRow('none', TomAuthState.none, Colors.grey),
    ),
  ],
);
