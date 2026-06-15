/// Interaction tests for Demo J — Date / Time / Duration Forms (Phase 3).
///
/// Demo J hosts every Phase 3 date/time/duration concrete:
///   * [TomFormDatePicker] (dialog) + [TomFormDateCalendar] (inline) —
///     wired two-way via the form's `_inlineToPicker` / `_pickerToInline`
///     observers
///   * [TomFormTimePicker]
///   * [TomFormDateTimePicker]
///   * [TomFormDateRangePicker]
///   * [TomFormDurationInput] (h / m segmented entry) ↔
///     [TomFormIntSlider] for `taskMinutes`, kept in lockstep by demo-
///     level `_durationObserver` / `_minutesObserver`
///
/// Demo J also implements a width breakpoint at 700 px: at >= 700 the
/// dialog date picker AND the inline calendar both render; below 700
/// the dialog picker is hidden because the calendar offers the same
/// affordance without taking a modal step. The inline-readout
/// "Selected (inline): YYYY-MM-DD" and the duration readout
/// "Stored Duration: H:MM:SS  (slider = N min)" are the canonical
/// single-source-of-truth probes.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase3_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // Replace the bound state between tests. See the matching note in
  // demo_i_numeric_forms_test.dart — Demo J's TomForm leaves observers
  // attached to the bound TomClass after dispose, so re-using the same
  // instance across tests would fire notifications into a disposed
  // _FormChangeNotifier.
  setUp(() {
    phase3DateState = DateTimeDemoState();
  });

  /// Open Demo J on a wide-and-tall viewport so the demo list can scroll
  /// to the tile, then optionally resize so the >=700 / <700 breakpoint
  /// flips the wide / narrow layout branch.
  Future<void> openDemoJ(
    WidgetTester tester, {
    Size finalSize = const Size(2400, 2400),
  }) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo J: Date/Time/Duration Forms'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo J: Date/Time/Duration Forms'));
    await tester.pumpAndSettle();
    if (finalSize != const Size(2400, 2400)) {
      tester.view.physicalSize = finalSize;
      await tester.pumpAndSettle();
    }
  }

  /// Find the (single) TomFieldWidgetAdapter for a given tomId. Date /
  /// time / duration fields don't all expose a TextField (the calendar
  /// is a CalendarDatePicker, the date dialog picker renders a button),
  /// so we test presence at the adapter level.
  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// Find the duration input's "h" or "m" segment by its suffixText.
  /// The widget renders two narrow [TextField]s inside the duration
  /// adapter — one with suffix "h", the other with "m".
  Finder durationSegment(String suffix) {
    return find.descendant(
      of: adapterByTomId('taskDuration'),
      matching: find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.suffixText == suffix,
        description: 'TextField suffix=$suffix',
      ),
    );
  }

  testWidgets('baseline at wide viewport — every field renders, '
      'readouts show seed values', (tester) async {
    await openDemoJ(tester);
    // Dialog pickers + inline calendar all present in the wide layout.
    expect(adapterByTomId('eventDate'), findsOneWidget,
        reason: 'wide layout includes the dialog date picker');
    expect(adapterByTomId('eventDateInline'), findsOneWidget);
    expect(adapterByTomId('startTime'), findsOneWidget);
    expect(adapterByTomId('eventDateTime'), findsOneWidget);
    expect(adapterByTomId('bookingRange'), findsOneWidget);
    expect(adapterByTomId('taskDuration'), findsOneWidget);
    expect(adapterByTomId('taskMinutes'), findsOneWidget);
    // Inline readout uses ISO date — DateTimeDemoState seeds eventDateInline
    // to 2026-05-12.
    expect(find.text('Selected (inline): 2026-05-12'), findsOneWidget);
    // Duration readout — seed Duration is 1h30m, slider 90 min.
    expect(find.textContaining('(slider = 90 min)'), findsOneWidget);
    expect(find.textContaining('Stored Duration: 1:30:00'), findsOneWidget);
  });

  testWidgets('narrow viewport (< 700 px) hides the dialog date picker '
      'but keeps the inline calendar', (tester) async {
    // The narrow demo branch keeps the time / date-time / range pickers
    // (no inline equivalents) but drops the eventDate dialog picker.
    await openDemoJ(tester, finalSize: const Size(600, 2400));
    expect(adapterByTomId('eventDate'), findsNothing,
        reason: 'narrow layout hides the dialog date picker because the '
            'inline calendar offers the same affordance');
    expect(adapterByTomId('eventDateInline'), findsOneWidget,
        reason: 'inline calendar must still render in the narrow branch');
    expect(adapterByTomId('startTime'), findsOneWidget);
    expect(adapterByTomId('eventDateTime'), findsOneWidget);
    expect(adapterByTomId('bookingRange'), findsOneWidget);
    // Inline readout still works.
    expect(find.text('Selected (inline): 2026-05-12'), findsOneWidget);
  });

  testWidgets('tapping a different day in the inline calendar updates '
      'the inline readout', (tester) async {
    await openDemoJ(tester);
    // Seed selected day is 12. Tap day "20" inside the CalendarDatePicker
    // (descendant of the inline-calendar adapter) — the calendar's
    // onDateChanged calls field.setValue(...) which fires the bound
    // form's change notifier, which rebuilds the readout.
    final dayCell = find.descendant(
      of: adapterByTomId('eventDateInline'),
      matching: find.text('20'),
    );
    expect(dayCell, findsAtLeastNWidgets(1),
        reason: 'CalendarDatePicker must render a "20" day cell for May 2026');
    await tester.ensureVisible(dayCell.first);
    await tester.pumpAndSettle();
    await tester.tap(dayCell.first);
    await tester.pumpAndSettle();
    expect(find.text('Selected (inline): 2026-05-20'), findsOneWidget,
        reason: 'tapping day 20 must move the inline readout to 2026-05-20');
  });

  testWidgets('typing in the duration "h" segment updates both readouts',
      (tester) async {
    await openDemoJ(tester);
    final hSeg = durationSegment('h');
    expect(hSeg, findsOneWidget);
    // Replace the hours value with 3 — _push() commits the new Duration
    // and the demo's `_durationObserver` mirrors inMinutes (3*60+30 = 210)
    // into the IntSlider.
    await tester.enterText(hSeg, '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('Stored Duration: 3:30:00'), findsOneWidget,
        reason: 'changing hours must update the stored duration readout');
    expect(find.textContaining('(slider = 210 min)'), findsOneWidget,
        reason: 'the demo-level mirror observer must push 3h30m=210 into '
            'the minute-slider readout');
  });

  testWidgets('typing in the duration "m" segment updates both readouts',
      (tester) async {
    await openDemoJ(tester);
    final mSeg = durationSegment('m');
    expect(mSeg, findsOneWidget);
    // Replace minutes with 45 — combined duration becomes 1h45m = 105 min.
    await tester.enterText(mSeg, '45');
    await tester.pumpAndSettle();
    expect(find.textContaining('Stored Duration: 1:45:00'), findsOneWidget);
    expect(find.textContaining('(slider = 105 min)'), findsOneWidget);
  });
}
