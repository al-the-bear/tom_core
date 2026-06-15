import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// NumericDemoForm — hosts every Phase 3 numeric field for Demo I.
// ---------------------------------------------------------------------------

/// Hosts every Phase 3 numeric field for Demo I.
///
/// Exercises `tom_flutter_ui`'s numeric concretes bound to kernel `TomInt` /
/// `TomDouble` observables: `TomFormIntInput`, `TomFormIntSlider`,
/// `TomFormIntStepper`, `TomFormDoubleInput`, `TomFormCurrencyDoubleInput`,
/// `TomFormPercentDoubleInput`, `TomFormDoubleSlider`,
/// `TomFormIntRangeSlider` and `TomFormDoubleRangeSlider`.
///
/// The same TomInt (`quantity`) is bound to both the input and the slider —
/// typing in one updates the other live, fulfilling the spec's
/// "IntInput + IntSlider sharing a TomInt" bullet.
@tomReflector
class NumericDemoForm extends TomForm<NumericDemoState> {
  NumericDemoForm() : super(formId: 'numericDemo');

  late final quantityInput = TomFormIntInput(
    'quantity',
    8,
    form: this,
    labelTextOverride: 'Quantity (input)',
    minValue: 0,
    maxValue: 100,
  );

  late final quantitySlider = TomFormIntSlider(
    'quantity',
    8,
    form: this,
    min: 0,
    max: 100,
    divisions: 100,
    labelTextOverride: 'Quantity (slider)',
    descriptionTextOverride: 'Shares the same TomInt as the input above',
  );

  late final brightnessStepper = TomFormIntStepper(
    'brightness',
    50,
    form: this,
    minValue: 0,
    maxValue: 100,
    step: 5,
    labelTextOverride: 'Brightness',
    descriptionTextOverride: 'Stepper with min/max + 5-unit step',
  );

  late final priceUSD = TomFormCurrencyDoubleInput(
    'priceUSD',
    199.99,
    form: this,
    currencyCode: 'USD',
    labelTextOverride: 'Price',
    descriptionTextOverride: 'Currency input — locale switcher in the demo',
  );

  late final priceGeneric = TomFormDoubleInput(
    'priceGeneric',
    199.99,
    form: this,
    decimals: 2,
    labelTextOverride: 'Price (plain double)',
  );

  late final discount = TomFormPercentDoubleInput(
    'discount',
    0.15,
    form: this,
    decimals: 1,
    labelTextOverride: 'Discount %',
    descriptionTextOverride: 'Stored as 0.0–1.0; displayed as percent',
  );

  late final taxRate = TomFormDoubleSlider(
    'taxRate',
    7.5,
    form: this,
    min: 0.0,
    max: 25.0,
    divisions: 50,
    valueLabelDecimals: 1,
    labelTextOverride: 'Tax rate',
  );

  late final headcountRange = TomFormIntRangeSlider(
    'headcountRange',
    const NumRange<int>(8, 32),
    form: this,
    min: 0,
    max: 64,
    divisions: 64,
    labelTextOverride: 'Headcount range',
  );

  late final budgetRange = TomFormDoubleRangeSlider(
    'budgetRange',
    const NumRange<double>(2.5, 7.5),
    form: this,
    min: 0.0,
    max: 10.0,
    divisions: 100,
    valueLabelDecimals: 1,
    labelTextOverride: 'Budget range (k\$)',
  );

  @override
  void createFormElements() {}
}
