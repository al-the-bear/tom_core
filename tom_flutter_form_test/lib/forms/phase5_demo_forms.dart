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

import 'package:flutter/material.dart' show DateTimeRange, TimeOfDay;
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

// ---------------------------------------------------------------------------
// Phase 5b — Cupertino numeric + date/time form (Demo N)
// ---------------------------------------------------------------------------

@tomReflector
class CupertinoPhase5bForm extends TomForm<Phase5bDemoState> {
  CupertinoPhase5bForm() : super(formId: 'cupertinoPhase5b');

  late final quantity = TomCupertinoFormIntInput(
    'quantity',
    1,
    form: this,
    minValue: 0,
    maxValue: 99,
    labelTextOverride: 'Quantity (int input)',
    hintTextOverride: '0–99',
  );

  late final brightness = TomCupertinoFormIntPicker(
    'brightness',
    50,
    form: this,
    min: 0,
    max: 100,
    step: 5,
    labelTextOverride: 'Brightness (int picker)',
  );

  late final ratio = TomCupertinoFormDoubleInput(
    'ratio',
    1.0,
    form: this,
    decimals: 2,
    labelTextOverride: 'Ratio (double input)',
    hintTextOverride: 'e.g. 1.50',
  );

  late final price = TomCupertinoFormCurrencyDoubleInput(
    'price',
    0.0,
    form: this,
    currencyCode: 'USD',
    labelTextOverride: 'Price (currency)',
  );

  late final eventDate = TomCupertinoFormDatePicker(
    'eventDate',
    DateTime(2026, 5, 12),
    form: this,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    labelTextOverride: 'Event date',
  );

  // Time stays form-local — TimeOfDay isn't a TomObject value type, so
  // the field can't bind via setValues() / getValues(). The TomField
  // itself owns the TimeOfDay; observers still flow normally.
  late final eventTime = TomCupertinoFormTimePicker(
    'eventTime',
    const TimeOfDay(hour: 9, minute: 30),
    form: this,
    labelTextOverride: 'Event time',
  );

  late final eventDateTime = TomCupertinoFormDateTimePicker(
    'eventDateTime',
    DateTime(2026, 5, 12, 9, 30),
    form: this,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    labelTextOverride: 'Event date+time',
  );

  // Duration is also form-local — Duration has no TomObject wrapper.
  late final downtime = TomCupertinoFormDurationPicker(
    'downtime',
    const Duration(hours: 1, minutes: 30),
    form: this,
    labelTextOverride: 'Planned downtime',
  );

  // Date range is form-local — DateTimeRange has no TomObject wrapper.
  late final billingPeriod = TomCupertinoFormDateRangePicker(
    'billingPeriod',
    DateTimeRange(
      start: DateTime(2026, 5, 1),
      end: DateTime(2026, 5, 31),
    ),
    form: this,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    labelTextOverride: 'Billing period',
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
