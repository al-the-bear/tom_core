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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange, TimeOfDay;
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase4_state.dart';
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
    DateTimeRange(start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 31)),
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

// ---------------------------------------------------------------------------
// Phase 5c — Cupertino search/lookup/file + nullable form (Demo O)
// ---------------------------------------------------------------------------

/// In-memory deterministic file picker reused by Demo O. Mirrors the
/// `demoFilePicker` in [file_nullable_demo_form.dart] so the Cupertino
/// upload field behaves the same way under tests.
Future<TomFileRef?> phase5cFilePicker(_) async {
  final bytes = Uint8List.fromList(
    'Hello from the Phase 5c Cupertino demo picker.\n'.codeUnits,
  );
  return TomFileRef(
    name: 'cupertino_demo_file.txt',
    sizeBytes: bytes.length,
    mimeType: 'text/plain',
    bytes: bytes,
  );
}

@tomReflector
class CupertinoPhase5cForm extends TomForm<Phase5cDemoState> {
  CupertinoPhase5cForm() : super(formId: 'cupertinoPhase5c');

  // ---- Search / lookup over Phase 4 City + Country sources -----------
  // City / Country aren't TomObject types — these fields stay form-local.

  late final citySearch = TomCupertinoFormSearchInput<City>(
    'citySearch',
    const City(0, 'Berlin', 'DE'),
    form: this,
    source: phase4CitySource,
    labelTextOverride: 'City (search)',
    hintTextOverride: 'Type to search…',
  );

  late final countryLookup = TomCupertinoFormLookupSheet<Country>(
    'countryLookup',
    const Country('US', 'United States'),
    form: this,
    source: phase4LookupCountrySource,
    sheetTitle: 'Pick a country',
    labelTextOverride: 'Country (lookup sheet)',
  );

  // ---- File upload — value type TomFileRef? has no TomObject wrapper ----

  late final upload = TomCupertinoFormFileUpload(
    'upload',
    null,
    form: this,
    picker: phase5cFilePicker,
    labelTextOverride: 'Choose file (Cupertino)',
    descriptionTextOverride:
        'CupertinoButton.filled trigger, error → CupertinoAlertDialog',
    allowedExtensions: const ['txt', 'md', 'json', 'csv'],
    maxSizeBytes: 5 * 1024 * 1024,
  );

  // ---- Nullable variants — bind into Phase5cDemoState ----------------

  late final notes = TomCupertinoFormNStringInput(
    'notes',
    null,
    form: this,
    labelTextOverride: 'Notes (nullable)',
    descriptionTextOverride: 'Empty text → null',
    maxLength: 80,
  );

  late final age = TomCupertinoFormNIntInput(
    'age',
    null,
    form: this,
    labelTextOverride: 'Age (nullable int)',
  );

  late final score = TomCupertinoFormNDoubleInput(
    'score',
    null,
    form: this,
    decimals: 2,
    labelTextOverride: 'Score (nullable double)',
  );

  late final birthday = TomCupertinoFormNDateInput(
    'birthday',
    null,
    form: this,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    labelTextOverride: 'Birthday (nullable date)',
  );

  @override
  void createFormElements() {}
}

// ---------------------------------------------------------------------------
// Phase 5c — Family-swappable form (Demo P)
//
// One `TomForm` declaration that resolves Material vs Cupertino concretes
// at construction time via [TomFormFieldFamily]. The demo rebuilds the form
// when the breakpoint flips; the backing state survives so all values
// round-trip across the swap.
// ---------------------------------------------------------------------------

@tomReflector
class Phase5cFamilyForm extends TomForm<Phase5cFamilyState> {
  Phase5cFamilyForm({required this.family})
    : super(formId: 'phase5cFamily-${family.kind.name}');

  /// Which family this form was instantiated against (Material vs
  /// Cupertino). Stored for inspection in the demo — the actual concrete
  /// classes are picked once at construction.
  final TomFormFieldFamily family;

  late final fullName = family.stringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    hintTextOverride: 'First and last name',
    maxLength: 60,
  );

  late final quantity = family.intInput(
    'quantity',
    0,
    form: this,
    labelTextOverride: 'Quantity',
  );

  late final ratio = family.doubleInput(
    'ratio',
    0.0,
    form: this,
    decimals: 2,
    labelTextOverride: 'Ratio',
  );

  late final notifyMe = family.boolSwitch(
    'notifyMe',
    false,
    form: this,
    labelTextOverride: 'Notify me',
    descriptionTextOverride:
        'Switch surface picks Material Switch vs CupertinoSwitch.',
  );

  late final eventDate = family.datePicker(
    'eventDate',
    DateTime(2026, 1, 1),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    form: this,
    labelTextOverride: 'Event date',
  );

  @override
  void createFormElements() {}
}
