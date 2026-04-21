/// Phase 5 — Material vs Cupertino concrete forms (Demo M).
///
/// Two parallel form definitions over the same `Phase5DemoState`:
///   * [MaterialPhase5Form] — Phase 1+2 Material concretes
///   * [CupertinoPhase5Form] — Phase 5a Cupertino concretes
///
/// Both forms can be `bind()`-ed to the same state instance; the demo
/// then wires pair-wise observer-sync so every edit on either side
/// flows through the corresponding peer field, demonstrating that
/// the Cupertino concretes carry identical semantics.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase5_state.dart';

@tomReflector
class MaterialPhase5Form extends TomForm<Phase5DemoState> {
  MaterialPhase5Form() : super(formId: 'materialPhase5');

  late final name = TomFormStringInput(
    'name',
    '',
    form: this,
    labelTextOverride: 'Name (input)',
    hintTextOverride: 'Enter a name',
  );

  late final color = TomFormStringDropdown(
    'color',
    '',
    form: this,
    source: phase5ColorSource,
    labelTextOverride: 'Color (dropdown)',
  );

  late final size = TomFormStringSegmented(
    'size',
    '',
    form: this,
    source: phase5SizeSource,
    labelTextOverride: 'Size (segmented)',
  );

  late final tags = TomFormStringFilterChips(
    'tags',
    const [],
    form: this,
    source: phase5TagSource,
    labelTextOverride: 'Tags (filter chips)',
  );

  // Material side has no dedicated "search" string concrete; reuse
  // the plain string input so the pair-wise sync still works.
  late final search = TomFormStringInput(
    'search',
    '',
    form: this,
    labelTextOverride: 'Search (string input)',
    hintTextOverride: 'Type to search…',
  );

  late final notifications = TomFormBoolSwitch(
    'notifications',
    false,
    form: this,
    labelTextOverride: 'Notifications (switch)',
  );

  late final darkMode = TomFormBoolToggle(
    'darkMode',
    false,
    form: this,
    labelTextOverride: 'Dark mode (toggle)',
    onLabelOverride: 'Dark',
    offLabelOverride: 'Light',
  );

  @override
  void createFormElements() {}
}

@tomReflector
class CupertinoPhase5Form extends TomForm<Phase5DemoState> {
  CupertinoPhase5Form() : super(formId: 'cupertinoPhase5');

  late final name = TomCupertinoFormStringInput(
    'name',
    '',
    form: this,
    labelTextOverride: 'Name (input)',
    hintTextOverride: 'Enter a name',
  );

  late final color = TomCupertinoFormStringPicker(
    'color',
    '',
    form: this,
    source: phase5ColorSource,
    labelTextOverride: 'Color (picker)',
    hintTextOverride: 'Choose a color',
  );

  late final size = TomCupertinoFormStringSegmented(
    'size',
    '',
    form: this,
    source: phase5SizeSource,
    labelTextOverride: 'Size (segmented)',
  );

  late final tags = TomCupertinoFormStringListCheckedPicker(
    'tags',
    const [],
    form: this,
    source: phase5TagSource,
    labelTextOverride: 'Tags (checked picker)',
    hintTextOverride: 'Choose tags…',
  );

  late final search = TomCupertinoFormStringSearchInput(
    'search',
    '',
    form: this,
    labelTextOverride: 'Search',
    hintTextOverride: 'Type to search…',
  );

  late final notifications = TomCupertinoFormBoolSwitch(
    'notifications',
    false,
    form: this,
    labelTextOverride: 'Notifications (switch)',
  );

  late final darkMode = TomCupertinoFormBoolToggle(
    'darkMode',
    false,
    form: this,
    labelTextOverride: 'Dark mode (toggle)',
    onLabelOverride: 'Dark',
    offLabelOverride: 'Light',
  );

  @override
  void createFormElements() {}
}
