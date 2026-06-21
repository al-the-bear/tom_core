/// A family-swappable `TomForm` bound to [ResponsiveProfile].
///
/// One form *declaration* that resolves Material vs Cupertino field concretes
/// at construction time via [FormFieldFamily]. The family-swap screen pre-builds
/// one instance per family, both bound to the **same** [ResponsiveProfile], and
/// renders whichever matches the current breakpoint — so edits round-trip across
/// the swap. Mirrors the verified `Phase5cFamilyForm` from
/// `tom_flutter_form_test`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/responsive_entities.dart';

/// A form whose field widgets are drawn from [family] (Material or Cupertino).
/// The concrete classes are picked once, at construction.
@tomReflector
class FamilyForm extends TomForm<ResponsiveProfile> {
  /// Creates the form against [family] in the ambient [TomScope].
  FamilyForm({required this.family})
      : super(formId: 'family-${family.kind.name}');

  /// Which family this form was instantiated against (Material vs Cupertino).
  /// Stored for inspection by the screen; the concrete classes are picked once
  /// at construction.
  final FormFieldFamily family;

  /// Free-form name.
  late final fullName = family.stringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    hintTextOverride: 'First and last name',
    maxLength: 60,
  );

  /// Integer quantity.
  late final quantity = family.intInput(
    'quantity',
    0,
    form: this,
    labelTextOverride: 'Quantity',
  );

  /// Decimal ratio.
  late final ratio = family.doubleInput(
    'ratio',
    0.0,
    form: this,
    decimals: 2,
    labelTextOverride: 'Ratio',
  );

  /// Boolean switch.
  late final notifyMe = family.boolSwitch(
    'notifyMe',
    false,
    form: this,
    labelTextOverride: 'Notify me',
    descriptionTextOverride:
        'Switch surface picks Material Switch vs CupertinoSwitch.',
  );

  /// Date picker.
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
