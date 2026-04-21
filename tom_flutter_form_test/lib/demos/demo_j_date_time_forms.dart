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
// At narrow widths (< 600 px) the picker rows stack in single-column
// layout and the inline calendar drops below the dialog picker; at wide
// widths they split into two columns, fulfilling the spec's "Breakpoint
// swap" bullet.
class DemoJDateTimeForms extends StatefulWidget {
  const DemoJDateTimeForms({super.key});

  @override
  State<DemoJDateTimeForms> createState() => _DemoJDateTimeFormsState();
}

class _DemoJDateTimeFormsState extends State<DemoJDateTimeForms> {
  late final DateTimeDemoForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoJ', () => DateTimeDemoForm());
    _form.bind(phase3DateState);
    // Keep the duration input + minute slider in lockstep — edits to
    // either fire FieldValueChangedEvent on both, demonstrating that
    // Duration and int can share state cleanly even though they're two
    // different field types.
    _form.taskDuration.addObserver(_TomFnObserver((_) {
      final mins = _form.taskDuration.get().inMinutes;
      if (_form.taskMinutes.get() != mins) _form.taskMinutes.set(mins);
    }));
    _form.taskMinutes.addObserver(_TomFnObserver((_) {
      final d = Duration(minutes: _form.taskMinutes.get());
      if (_form.taskDuration.get() != d) _form.taskDuration.set(d);
    }));
  }

  @override
  void dispose() {
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
                'same DateTimeDemoState. The inline calendar mirrors the '
                'value of the dialog-based DatePicker — pick on either '
                'side and they stay in sync. The duration card pairs the '
                'segmented h/m DurationInput with an equivalent IntSlider '
                'in minutes (sync is two-way). At ≥ 700 px the picker '
                'rows split into two columns; under that they stack.'),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _pickerColumn(context)),
        const SizedBox(width: 12),
        Expanded(child: _calendarColumn(context)),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickerColumn(context),
        const SizedBox(height: 12),
        _calendarColumn(context),
      ],
    );
  }

  Widget _pickerColumn(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dialog pickers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.eventDate.widget,
            const SizedBox(height: 8),
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

class _TomFnObserver implements TomObserver {
  final void Function(TomObservable o) _fn;
  _TomFnObserver(this._fn);
  @override
  void onNotify(TomObservable observable) => _fn(observable);
}
