import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../common/demo_scaffold.dart';
import '../forms/datetime_demo_form.dart';
import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// Demo J — Date / Time / Duration Forms (Phase 3)
// ---------------------------------------------------------------------------
//
// Covers DatePicker, DateCalendar (inline), TimePicker, DateTimePicker,
// DateRangePicker and DurationInput. The duration row sits next to a
// DoubleSlider-like minute count for direct comparison.
//
// At narrow widths (< 700 px) the dialog-based picker collapses to the
// inline calendar — matching the spec's "at narrow widths the pickers
// collapse to inline calendars; at wide widths they open as dialogs"
// bullet. The TimePicker, DateTimePicker and DateRangePicker stay in
// the dialog flow at all widths because there's no inline calendar
// equivalent in Material for them.
class DemoJDateTimeForms extends StatefulWidget {
  const DemoJDateTimeForms({super.key});

  @override
  State<DemoJDateTimeForms> createState() => _DemoJDateTimeFormsState();
}

class _DemoJDateTimeFormsState extends State<DemoJDateTimeForms> {
  late final DateTimeDemoForm _form;
  late final TomFunctionObserver<TomObservable> _durationObserver;
  late final TomFunctionObserver<TomObservable> _minutesObserver;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoJ', () => DateTimeDemoForm());
    _form.bind(phase3DateState);
    // Keep the duration input + minute slider in lockstep — edits to
    // either fire FieldValueChangedEvent on both, demonstrating that
    // Duration and int can share state cleanly even though they're two
    // different field types. Uses the codebase-standard `>>` operator
    // (returns a TomFunctionObserver registered on the LHS observable).
    _durationObserver = _form.taskDuration >> (_) {
      final mins = _form.taskDuration.get().inMinutes;
      if (_form.taskMinutes.get() != mins) _form.taskMinutes.set(mins);
    };
    _minutesObserver = _form.taskMinutes >> (_) {
      final d = Duration(minutes: _form.taskMinutes.get());
      if (_form.taskDuration.get() != d) _form.taskDuration.set(d);
    };
  }

  @override
  void dispose() {
    _form.taskDuration.removeObserver(_durationObserver);
    _form.taskMinutes.removeObserver(_minutesObserver);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo J — Date/Time/Duration Forms',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _intro(context),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                return wide
                    ? _wideLayout(context)
                    : _narrowLayout(context);
              },
            ),
            const SizedBox(height: 12),
            _durationCard(context),
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
                'Date-only / time-only / date-time pickers wired to the '
                'same DateTimeDemoState. The duration card pairs the '
                'segmented h/m DurationInput with an equivalent IntSlider '
                'in minutes (sync is two-way). Breakpoint swap: at ≥ 700 px '
                'the date column shows the dialog DatePicker alongside the '
                'inline calendar; under 700 px it collapses to the inline '
                'calendar only — the dialog picker is hidden because the '
                'calendar provides the same affordance without taking a '
                'modal screen.'),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _pickerColumn(context, includeDateDialog: true)),
        const SizedBox(width: 12),
        Expanded(child: _calendarColumn(context)),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _calendarColumn(context),
        const SizedBox(height: 12),
        // At narrow widths the date dialog picker collapses into the
        // inline calendar above; the time / date-time / range pickers
        // stay because they have no inline equivalent.
        _pickerColumn(context, includeDateDialog: false),
      ],
    );
  }

  Widget _pickerColumn(BuildContext context, {required bool includeDateDialog}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dialog pickers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (includeDateDialog) ...[
              _form.eventDate.widget,
              const SizedBox(height: 8),
            ],
            _form.startTime.widget,
            const SizedBox(height: 8),
            _form.eventDateTime.widget,
            const SizedBox(height: 8),
            _form.bookingRange.widget,
          ],
        ),
      ),
    );
  }

  Widget _calendarColumn(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inline calendar', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.eventDateInline.widget,
          ],
        ),
      ),
    );
  }

  Widget _durationCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Duration vs. minute slider',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.taskDuration.widget,
            const SizedBox(height: 8),
            _form.taskMinutes.widget,
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _form.changes,
              builder: (context, _) => Text(
                'Stored Duration: ${_form.taskDuration.get()}  '
                '(slider = ${_form.taskMinutes.get()} min)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

