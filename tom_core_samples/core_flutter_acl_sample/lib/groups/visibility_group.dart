/// Group visibility group — show, hide or disable a whole ACL group reactively.
///
/// Components appended between `startGroup(name)` and `endGroup()` form a named
/// group whose visibility is driven by an [AclGroupVisibilityController] bound
/// with `setGroupVisibilityController`. An [AclBinaryVisibilityController]
/// flips a group between [AclGroupVisibilityMode.visible],
/// `.hidden` and `.disabled` at runtime. Maps to the verified
/// `group_visibility_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The group-visibility capability group.
final ShowcaseGroup visibilityGroup = ShowcaseGroup(
  id: 'visibility',
  title: 'Group visibility',
  summary:
      'startGroup/endGroup name a group; an AclBinaryVisibilityController '
      'shows, hides or disables it reactively via setGroupVisibilityController.',
  icon: Icons.visibility_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Toggle a named group',
      note:
          'Flip the switch to hide or reveal the "details" group. The summary '
          'row stays put; only the grouped row reacts.',
      code:
          'final ctrl = AclBinaryVisibilityController();\n'
          '\n'
          'AclBuilder()\n'
          "    .setGroupVisibilityController('details', ctrl)\n"
          "    .append(demoBox('Summary (always shown)', teal))\n"
          '    .newRow(dist: 8)\n'
          "    .startGroup('details')\n"
          "    .append(demoBox('Detail A', orange))\n"
          "    .append(demoBox('Detail B', orange))\n"
          '    .endGroup()\n'
          '    .build()\n'
          '\n'
          '// later: ctrl.mode = AclGroupVisibilityMode.hidden;',
      child: _VisibilityDemo(),
    ),
  ],
);

/// Interactive child for the visibility cell: a [TomSwitch] drives an
/// [AclBinaryVisibilityController] bound to a named ACL group.
// Why: extends [TomStatefulWidget]/[TomState] (not raw) so the interactive demo
// payload conforms to G-UI-2, and its layout scaffolding uses Tom primitives.
// It owns no tomId/resources → a family base would be wrong; the scope bases are
// non-const (construction reads [TomScope.current]).
class _VisibilityDemo extends TomStatefulWidget {
  _VisibilityDemo();

  @override
  TomState<_VisibilityDemo> createState() => _VisibilityDemoState();
}

class _VisibilityDemoState extends TomState<_VisibilityDemo> {
  final AclBinaryVisibilityController _ctrl = AclBinaryVisibilityController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomRow(
          children: [
            // Interactive chrome (the demo's own toggle label), not a teaching
            // snippet — resolved as a resource per G-RES-1 (see chrome_texts.dart).
            TomText(text: TomCtr.text('showcase.visibility.showDetails')),
            TomValueListenableBuilder<AclGroupVisibilityMode>(
              valueListenable: _ctrl.modeNotifier,
              builder: (_, mode, _) => TomSwitch(
                value: mode == AclGroupVisibilityMode.visible,
                onChanged: (on) => _ctrl.mode = on
                    ? AclGroupVisibilityMode.visible
                    : AclGroupVisibilityMode.hidden,
              ),
            ),
          ],
        ),
        TomSizedBox(height: 8),
        AclBuilder()
            .setGroupVisibilityController('details', _ctrl)
            .append(demoBox('Summary (always shown)', Colors.teal))
            .newRow(dist: 8)
            .startGroup('details')
            .append(demoBox('Detail A', Colors.orange))
            .append(demoBox('Detail B', Colors.orange))
            .endGroup()
            .build(),
      ],
    );
  }
}
