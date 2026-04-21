import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/numeric_demo_form.dart';
import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// Demo I — Numeric Forms (Phase 3)
// ---------------------------------------------------------------------------
//
// Covers every Phase 3 numeric concrete: IntInput, IntSlider, IntStepper,
// DoubleInput, CurrencyDoubleInput (with locale switcher), PercentDoubleInput,
// DoubleSlider, IntRangeSlider, DoubleRangeSlider.
//
// The Quantity row binds the same `TomInt` to both an IntInput and an
// IntSlider — typing in either side updates the other live, exercising
// the spec's bullet "IntInput + IntSlider sharing a TomInt".
class DemoINumericForms extends StatefulWidget {
  const DemoINumericForms({super.key});

  @override
  State<DemoINumericForms> createState() => _DemoINumericFormsState();
}

class _DemoINumericFormsState extends State<DemoINumericForms> {
  late final NumericDemoForm _form;
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoI', () => NumericDemoForm());
    _form.bind(phase3NumericState);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo I — Numeric Forms',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _intro(context),
            const SizedBox(height: 12),
            _quantityCard(context),
            const SizedBox(height: 12),
            _stepperCard(context),
            const SizedBox(height: 12),
            _currencyCard(context),
            const SizedBox(height: 12),
            _percentTaxCard(context),
            const SizedBox(height: 12),
            _rangeCard(context),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
                'Every numeric concrete from Phase 3 in one place. The '
                '"Quantity" row shares one TomInt across input + slider — '
                'edit either side and the other follows. The currency '
                'row uses an in-app currency switcher to demonstrate the '
                'CurrencyDoubleInput formatter swap. Range sliders show '
                'the live (low, high) preview in their value labels.'),
          ],
        ),
      ),
    );
  }

  Widget _quantityCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shared TomInt — input ↔ slider',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.quantityInput.widget,
            const SizedBox(height: 8),
            _form.quantitySlider.widget,
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                  'Bound TomInt value: ${_form.quantityInput.get()}',
                  style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stepper', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.brightnessStepper.widget,
          ],
        ),
      ),
    );
  }

  Widget _currencyCard(BuildContext context) {
    final theme = Theme.of(context);
    final currentCurrency = _currency;
    final currencyField = TomFormCurrencyDoubleInput(
      'priceUSD',
      _form.priceUSD.get(),
      form: _form,
      currencyCode: currentCurrency,
      labelTextOverride: 'Price ($currentCurrency)',
      descriptionTextOverride:
          'Locale-aware currency formatter — switch the code via the chips',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Currency input', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['USD', 'EUR', 'GBP', 'JPY']
                  .map((code) => ChoiceChip(
                        label: Text(code),
                        selected: _currency == code,
                        onSelected: (sel) {
                          if (sel) {
                            // Push current value into the bound TomDouble
                            // so the rebuilt field shows the same number
                            // formatted by the new locale.
                            _form.priceUSD.set(currencyField.get());
                            setState(() => _currency = code);
                          }
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            currencyField.widget,
            const SizedBox(height: 8),
            _form.priceGeneric.widget,
          ],
        ),
      ),
    );
  }

  Widget _percentTaxCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Percent + tax slider', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.discount.widget,
            const SizedBox(height: 8),
            _form.taxRate.widget,
          ],
        ),
      ),
    );
  }

  Widget _rangeCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Range sliders', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.headcountRange.widget,
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Headcount: ${_form.headcountRange.get()}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            _form.budgetRange.widget,
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Budget (k\$): ${_form.budgetRange.get()}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
