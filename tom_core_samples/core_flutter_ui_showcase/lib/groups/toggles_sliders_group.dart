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
  summary:
      'Switches, checkboxes and sliders — the interactive value '
      'widgets that report changes through onChanged.',
  icon: Icons.tune,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomSwitch',
      code:
          "TomSwitch(\n"
          "  value: _on,\n"
          "  onChanged: (v) => setState(() => _on = v),\n"
          ")",
      child: _SwitchDemo(),
    ),
    ShowcaseCell(
      title: 'TomCheckbox',
      code:
          "TomCheckbox(\n"
          "  value: _checked,\n"
          "  onChanged: (v) => setState(() => _checked = v ?? false),\n"
          ")",
      child: _CheckboxDemo(),
    ),
    ShowcaseCell(
      title: 'TomSlider',
      note:
          'A slider has no intrinsic width either — the demo constrains it '
          'to 240px, and the snippet shows that constraint because without it '
          'the copied slider spans its whole parent.',
      code:
          "TomSizedBox(\n"
          "  width: 240,\n"
          "  child: TomSlider(\n"
          "    value: _value,\n"
          "    min: 0,\n"
          "    max: 100,\n"
          "    onChanged: (v) => setState(() => _value = v),\n"
          "  ),\n"
          ")",
      child: _SliderDemo(),
    ),
  ],
);

// Why: extends [TomStatefulWidget]/[TomState] (not raw) so the demo payload
// conforms to G-UI-2. It owns demo-local state (the switch value) but no
// tomId/resources → scope bases, which are non-const (construction reads
// [TomScope.current]). The value/onChanged behaviour is unchanged.
class _SwitchDemo extends TomStatefulWidget {
  _SwitchDemo();

  @override
  TomState<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends TomState<_SwitchDemo> {
  bool _on = true;

  @override
  Widget buildContent(BuildContext context) {
    return TomSwitch(value: _on, onChanged: (v) => setState(() => _on = v));
  }
}

// Why: as above — demo-local checkbox state, scope base, non-const, unchanged
// behaviour.
class _CheckboxDemo extends TomStatefulWidget {
  _CheckboxDemo();

  @override
  TomState<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends TomState<_CheckboxDemo> {
  bool _checked = true;

  @override
  Widget buildContent(BuildContext context) {
    return TomCheckbox(
      value: _checked,
      onChanged: (v) => setState(() => _checked = v ?? false),
    );
  }
}

// Why: as above — demo-local slider value, scope base, non-const, unchanged
// behaviour; raw SizedBox swapped for [TomSizedBox].
class _SliderDemo extends TomStatefulWidget {
  _SliderDemo();

  @override
  TomState<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends TomState<_SliderDemo> {
  double _value = 40;

  @override
  Widget buildContent(BuildContext context) {
    return TomSizedBox(
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
