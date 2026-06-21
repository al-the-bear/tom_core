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
  summary: 'startGroup/endGroup name a group; an AclBinaryVisibilityController '
      'shows, hides or disables it reactively via setGroupVisibilityController.',
  icon: Icons.visibility_outlined,
  cells: (context) => const [
    ShowcaseCell(
      title: 'Toggle a named group',
      note: 'Flip the switch to hide or reveal the "details" group. The summary '
          'row stays put; only the grouped row reacts.',
      code: 'final ctrl = AclBinaryVisibilityController();\n'
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

/// Interactive child for the visibility cell: a [Switch] drives an
/// [AclBinaryVisibilityController] bound to a named ACL group.
class _VisibilityDemo extends StatefulWidget {
  const _VisibilityDemo();

  @override
  State<_VisibilityDemo> createState() => _VisibilityDemoState();
}

class _VisibilityDemoState extends State<_VisibilityDemo> {
  final AclBinaryVisibilityController _ctrl = AclBinaryVisibilityController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Show details'),
            ValueListenableBuilder<AclGroupVisibilityMode>(
              valueListenable: _ctrl.modeNotifier,
              builder: (_, mode, _) => Switch(
                value: mode == AclGroupVisibilityMode.visible,
                onChanged: (on) => _ctrl.mode = on
                    ? AclGroupVisibilityMode.visible
                    : AclGroupVisibilityMode.hidden,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
