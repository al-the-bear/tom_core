/// Toggles & sliders group — the interactive value widgets.
///
/// These widgets carry state, so each cell's [child] is a small stateful
/// wrapper that owns its own value; the snippet shows the canonical
/// value/onChanged pairing.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Toggles & sliders component group.
final ShowcaseGroup togglesSlidersGroup = ShowcaseGroup(
  id: 'toggles',
  title: 'Toggles & sliders',
  summary: 'Switches, checkboxes and sliders — the interactive value '
      'widgets that report changes through onChanged.',
  icon: Icons.tune,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomSwitch',
      code: "TomSwitch(\n"
          "  value: _on,\n"
          "  onChanged: (v) => setState(() => _on = v),\n"
          ")",
      child: _SwitchDemo(),
    ),
    ShowcaseCell(
      title: 'TomCheckbox',
      code: "TomCheckbox(\n"
          "  value: _checked,\n"
          "  onChanged: (v) => setState(() => _checked = v ?? false),\n"
          ")",
      child: _CheckboxDemo(),
    ),
    ShowcaseCell(
      title: 'TomSlider',
      code: "TomSlider(\n"
          "  value: _value,\n"
          "  min: 0,\n"
          "  max: 100,\n"
          "  onChanged: (v) => setState(() => _value = v),\n"
          ")",
      child: _SliderDemo(),
    ),
  ],
);

class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo();

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return TomSwitch(
      value: _on,
      onChanged: (v) => setState(() => _on = v),
    );
  }
}

class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _checked = true;

  @override
  Widget build(BuildContext context) {
    return TomCheckbox(
      value: _checked,
      onChanged: (v) => setState(() => _checked = v ?? false),
    );
  }
}

class _SliderDemo extends StatefulWidget {
  const _SliderDemo();

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _value = 40;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: TomSlider(
        value: _value,
        min: 0,
        max: 100,
        onChanged: (v) => setState(() => _value = v),
      ),
    );
  }
}
