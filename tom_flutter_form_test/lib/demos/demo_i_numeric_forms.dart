import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/numeric_demo_form.dart';
import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// Demo I — Numeric Forms (Phase 3)
// ---------------------------------------------------------------------------

/// Exercises `tom_flutter_ui`'s numeric form concretes bound to kernel
/// `TomInt` / `TomDouble` observables.
///
/// Covers every Phase 3 numeric concrete: IntInput, IntSlider, IntStepper,
/// DoubleInput, CurrencyDoubleInput (with locale switcher), PercentDoubleInput,
/// DoubleSlider, IntRangeSlider, DoubleRangeSlider.
///
/// The Quantity row binds the same `TomInt` to both an IntInput and an
/// IntSlider — typing in either side updates the other live, exercising
/// the spec's bullet "IntInput + IntSlider sharing a TomInt".
class DemoINumericForms extends StatefulWidget {
  const DemoINumericForms({super.key});

  @override
  State<DemoINumericForms> createState() => _DemoINumericFormsState();
}

class _DemoINumericFormsState extends State<DemoINumericForms> {
  late final NumericDemoForm _form;
  String _currency = 'USD';
  TomFormCurrencyDoubleInput? _currencyField;

  // Cross-observers that keep the two `quantity` fields (input + slider)
  // in lockstep. NumericDemoForm exposes them as separate TomField
  // instances (each is its own TomObject), so the spec promise of
  // "IntInput + IntSlider sharing a TomInt" is implemented at the demo
  // level by two-way mirroring: dragging the slider pushes the rounded
  // int into the input's TomInt and vice versa. Mirrors the same
  // `taskDuration` ↔ `taskMinutes` pattern used in Demo J.
  late final TomFunctionObserver<TomObservable> _quantityInputObserver;
  late final TomFunctionObserver<TomObservable> _quantitySliderObserver;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoI', () => NumericDemoForm());
    _form.bind(phase3NumericState);
    _currencyField = _buildCurrencyField(_currency);

    _quantityInputObserver =
        _form.quantityInput >>
        (_) {
          final v = _form.quantityInput.get();
          if (_form.quantitySlider.get() != v) _form.quantitySlider.setValue(v);
        };
    _quantitySliderObserver =
        _form.quantitySlider >>
        (_) {
          final v = _form.quantitySlider.get();
          if (_form.quantityInput.get() != v) _form.quantityInput.setValue(v);
        };
  }

  @override
  void dispose() {
    _form.quantityInput.removeObserver(_quantityInputObserver);
    _form.quantitySlider.removeObserver(_quantitySliderObserver);
    _currencyField?.dispose();
    _form.dispose();
    super.dispose();
  }

  TomFormCurrencyDoubleInput _buildCurrencyField(String code) {
    return TomScope.withScope(
      'demoI',
      () => TomFormCurrencyDoubleInput(
        'priceUSD',
        _form.priceUSD.get(),
        form: _form,
        currencyCode: code,
        labelTextOverride: 'Price ($code)',
        descriptionTextOverride:
            'Locale-aware currency formatter — switch the code via the chips',
      ),
    );
  }

  void _setCurrency(String code) {
    if (code == _currency) return;
    // Push the current field value into the bound TomDouble so the
    // rebuilt field shows the same number formatted by the new locale.
    _form.priceUSD.set(_currencyField!.get());
    final old = _currencyField;
    setState(() {
      _currency = code;
      _currencyField = _buildCurrencyField(code);
    });
    // Dispose the previous instance after the swap so its observer /
    // validation listenable resources are released — fixes the leak
    // where every chip tap created a fresh field whose state never went
    // away.
    old?.dispose();
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
              'the live (low, high) preview in their value labels.',
            ),
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
            Text(
              'Shared TomInt — input ↔ slider',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _form.quantityInput.widget,
            const SizedBox(height: 8),
            _form.quantitySlider.widget,
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Bound TomInt value: ${_form.quantityInput.get()}',
                style: theme.textTheme.bodySmall,
              ),
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
                  .map(
                    (code) => ChoiceChip(
                      label: Text(code),
                      selected: _currency == code,
                      onSelected: (sel) {
                        if (sel) _setCurrency(code);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Wrap the field widget in a ValueKey so swapping the
            // currency code forces Flutter to discard the old State
            // (including its TextEditingController initialised to the
            // previous symbol/separators). Without this, the field's
            // State persists across rebuilds and keeps showing the old
            // formatted text — the locale switch becomes a no-op
            // visually even though the underlying CurrencyFormatProfile
            // has changed.
            KeyedSubtree(
              key: ValueKey('currencyField_$_currency'),
              child: _currencyField!.widget,
            ),
            const SizedBox(height: 4),
            // Live readout that proves the format profile changed —
            // re-renders on every form change AND every chip tap, since
            // _currency is part of the demo's State.
            Text(
              'Formatted: ${_currencyField!.formatProfile.format(_form.priceUSD.get())}'
              '   (code: $_currency)',
              style: theme.textTheme.bodySmall,
            ),
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
            // The percent input renders '%' as an InputDecoration
            // suffix inside the TextField, but at narrow widths or with
            // certain themes it can be hidden by content padding. This
            // explicit readout makes the formatted percent + the
            // underlying 0..1 fraction unambiguously visible so the
            // demo proves the conversion is working.
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Discount: ${(_form.discount.get() * 100).toStringAsFixed(1)}%'
                '   (stored as fraction: '
                '${_form.discount.get().toStringAsFixed(3)})',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            _form.taxRate.widget,
            // Tax slider had no companion readout — without one a user
            // dragging it had no proof that the bound TomDouble was
            // updating, and the slider thumb's brief tooltip is easy
            // to miss. This Text rebuilds on every form change.
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Tax rate: ${_form.taxRate.get().toStringAsFixed(1)} %',
                style: theme.textTheme.bodySmall,
              ),
            ),
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
