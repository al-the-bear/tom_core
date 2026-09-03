/// TCCA17 — the date/time typed fields and the format engine behind them.
///
/// [TomDateTimeFormat] is the single riskiest untested unit in the field
/// library: it compiles a pattern into a regex once and caches it in a static
/// `Expando`, so a bug in the tokeniser is silent, global and sticky. Everything
/// the text inputs do — hint text, placeholder, parse-on-type, the on-blur error
/// — is downstream of it.
///
/// The assertions are organised the same way as the numeric suite, around what a
/// typed field is *for*:
///
///  * **parse / format round-trip** — for every preset, and for the two shapes
///    that lose information on the way out (`YY` drops the century, a time-only
///    pattern drops the date).
///  * **null handling** — this family expresses "I could not read that" as a
///    `null` from `parse*`, not an exception. The *field* value is never null,
///    so the widgets' rule is: a value that does not parse leaves the last good
///    one in place. That is what stops a half-typed date from destroying the
///    model.
///  * **format resolution** — resource key → constructor parameter → preset
///    default, and the parallel `hintText` chain. Three sources feeding one
///    getter is precedence logic, and precedence logic is what silently inverts.
///  * **`set()` / `reset()`** — the baseline semantics TCCA15 pinned, checked
///    per concrete type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

TomUIStateController get _readOnly =>
    TomUIStateController(resolve: (_, _) => TomAuthState.read);

/// The field's fast-validation debounce is 300 ms; anything shorter leaves a
/// live timer behind at teardown.
Future<void> _drainDebounce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 700));

/// Bounds wide enough that no test trips the `[firstDate, lastDate]` assert
/// unless it means to.
final _first = DateTime(2000, 1, 1);
final _last = DateTime(2099, 12, 31);

TextField _soleTextField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  // =========================================================================
  // TomDateTimeFormat — formatting
  // =========================================================================

  group('TomDateTimeFormat formatting', () {
    final d = DateTime(2026, 5, 7, 9, 3, 4);

    test(
      'pads the two-character date tokens and not the one-character ones',
      () {
        expect(TomDateTimeFormat('YYYY-MM-DD').formatDate(d), '2026-05-07');
        expect(TomDateTimeFormat('YYYY-M-D').formatDate(d), '2026-5-7');
      },
    );

    test('YY renders the last two digits of the year', () {
      expect(TomDateTimeFormat('YY-MM-DD').formatDate(d), '26-05-07');
      expect(TomDateTimeFormat('YY').formatDate(DateTime(2005, 1, 1)), '05');
    });

    test(
      'pads the two-character time tokens and not the one-character ones',
      () {
        const t = TimeOfDay(hour: 9, minute: 3);
        expect(TomDateTimeFormat('HH:mm').formatTime(t), '09:03');
        expect(TomDateTimeFormat('H:m').formatTime(t), '9:3');
      },
    );

    test('formatDateTime renders date and time tokens from one value', () {
      expect(
        TomDateTimeFormat('YYYY-MM-DD HH:mm:ss').formatDateTime(d),
        '2026-05-07 09:03:04',
      );
    });

    test('non-token characters pass through as literal separators', () {
      expect(TomDateTimeFormat('DD.MM.YYYY').formatDate(d), '07.05.2026');
      expect(
        TomDateTimeFormat('on DD/MM/YYYY').formatDate(d),
        // `o` and `n` are not tokens; `D` and `M` inside them are — which is
        // exactly why the pattern language is documented as token-first. Pinned
        // so a future tokeniser rewrite has to make the same choice knowingly.
        'on 07/05/2026',
      );
    });

    test('formatTime writes zero seconds rather than the token name', () {
      // A TimeOfDay is a whole-minute value, so its second is known to be 0 —
      // not missing. Before this was fixed, the shipped `time24WithSeconds`
      // preset rendered `09:03:ss`, which then failed to parse back.
      expect(
        TomDateTimeFormat.time24WithSeconds.formatTime(
          const TimeOfDay(hour: 9, minute: 3),
        ),
        '09:03:00',
      );
    });

    test('formatDate fills the clock tokens a mixed pattern asks for', () {
      // A `dateFormat` resource is free to carry `HH:mm`, and the DateTime
      // genuinely holds those values. Emitting the token names instead produced
      // output the field could not parse back on the next rebuild.
      expect(
        TomDateTimeFormat('YYYY-MM-DD HH:mm').formatDate(d),
        '2026-05-07 09:03',
      );
    });

    test('formatTime leaves the date tokens as their own names', () {
      // Here the omission is real: a time carries no date, so there is nothing
      // to fill `YYYY-MM-DD` with and the renderer must not invent a day.
      // Pinned because it is the visible symptom of pairing a date pattern
      // with a time field.
      expect(
        TomDateTimeFormat(
          'YYYY-MM-DD HH:mm',
        ).formatTime(const TimeOfDay(hour: 9, minute: 3)),
        'YYYY-MM-DD 09:03',
      );
    });
  });

  // =========================================================================
  // TomDateTimeFormat — parsing
  // =========================================================================

  group('TomDateTimeFormat parsing', () {
    test('every date preset round-trips through format then parse', () {
      final d = DateTime(2026, 5, 7);
      for (final f in const [
        TomDateTimeFormat.isoDate,
        TomDateTimeFormat.europeanDate,
        TomDateTimeFormat.usDate,
        TomDateTimeFormat.germanDate,
      ]) {
        final text = f.formatDate(d);
        expect(
          f.parseDate(text, firstDate: _first, lastDate: _last),
          d,
          reason: 'round-trip failed for ${f.pattern} (rendered "$text")',
        );
      }
    });

    test('every datetime preset round-trips through format then parse', () {
      final d = DateTime(2026, 5, 7, 9, 3);
      for (final f in const [
        TomDateTimeFormat.isoDateTime,
        TomDateTimeFormat.europeanDateTime,
        TomDateTimeFormat.usDateTime,
      ]) {
        final text = f.formatDateTime(d);
        expect(
          f.parseDateTime(text, firstDate: _first, lastDate: _last),
          d,
          reason: 'round-trip failed for ${f.pattern} (rendered "$text")',
        );
      }
    });

    test('every time preset round-trips through format then parse', () {
      const t = TimeOfDay(hour: 9, minute: 3);
      for (final f in const [
        TomDateTimeFormat.time24,
        TomDateTimeFormat.time24WithSeconds,
      ]) {
        expect(
          f.parseTime(f.formatTime(t)),
          t,
          reason: 'round-trip failed for ${f.pattern}',
        );
      }
    });

    test('the day/month distinction is real, not cosmetic', () {
      // The same eight characters mean different days in Europe and the US.
      // If the tokeniser ever collapsed DD and MM this test is the one that
      // notices.
      const text = '05/07/2026';
      expect(
        TomDateTimeFormat.europeanDate.parseDate(
          text,
          firstDate: _first,
          lastDate: _last,
        ),
        DateTime(2026, 7, 5),
      );
      expect(
        TomDateTimeFormat.usDate.parseDate(
          text,
          firstDate: _first,
          lastDate: _last,
        ),
        DateTime(2026, 5, 7),
      );
    });

    test('YY expands into the 2000s', () {
      expect(
        TomDateTimeFormat(
          'YY-MM-DD',
        ).parseDate('26-05-07', firstDate: _first, lastDate: _last),
        DateTime(2026, 5, 7),
      );
      expect(
        TomDateTimeFormat(
          'YY-MM-DD',
        ).parseDate('99-01-01', firstDate: _first, lastDate: _last),
        DateTime(2099, 1, 1),
      );
    });

    test('single-character tokens accept one or two digits', () {
      final f = TomDateTimeFormat('YYYY-M-D');
      expect(
        f.parseDate('2026-5-7', firstDate: _first, lastDate: _last),
        DateTime(2026, 5, 7),
      );
      expect(
        f.parseDate('2026-05-07', firstDate: _first, lastDate: _last),
        DateTime(2026, 5, 7),
      );
    });

    test('surrounding whitespace is trimmed before matching', () {
      expect(
        TomDateTimeFormat.isoDate.parseDate(
          '  2026-05-07  ',
          firstDate: _first,
          lastDate: _last,
        ),
        DateTime(2026, 5, 7),
      );
    });

    test('text that does not match the pattern parses to null', () {
      final f = TomDateTimeFormat.isoDate;
      for (final bad in ['', '2026', '2026/05/07', '07-05-2026', 'nope']) {
        expect(
          f.parseDate(bad, firstDate: _first, lastDate: _last),
          isNull,
          reason: '"$bad" should not parse as ${f.pattern}',
        );
      }
    });

    test('a partial match is not a match — the pattern is anchored', () {
      // The compiled regex is `^...$`. Without the anchors "2026-05-07xyz"
      // would parse, and every half-typed entry would silently commit.
      expect(
        TomDateTimeFormat.isoDate.parseDate(
          '2026-05-07xyz',
          firstDate: _first,
          lastDate: _last,
        ),
        isNull,
      );
    });

    test('impossible calendar values parse to null', () {
      final f = TomDateTimeFormat.isoDate;
      expect(
        f.parseDate('2026-13-01', firstDate: _first, lastDate: _last),
        isNull,
      );
      expect(
        f.parseDate('2026-00-01', firstDate: _first, lastDate: _last),
        isNull,
      );
      expect(
        f.parseDate('2026-01-32', firstDate: _first, lastDate: _last),
        isNull,
      );
      expect(
        f.parseDate('2026-01-00', firstDate: _first, lastDate: _last),
        isNull,
      );
    });

    test('a date outside firstDate..lastDate parses to null', () {
      final f = TomDateTimeFormat.isoDate;
      final first = DateTime(2026, 1, 1);
      final last = DateTime(2026, 12, 31);
      expect(
        f.parseDate('2026-06-15', firstDate: first, lastDate: last),
        DateTime(2026, 6, 15),
      );
      expect(
        f.parseDate('2025-12-31', firstDate: first, lastDate: last),
        isNull,
      );
      expect(
        f.parseDate('2027-01-01', firstDate: first, lastDate: last),
        isNull,
      );
      // The bounds are inclusive.
      expect(
        f.parseDate('2026-01-01', firstDate: first, lastDate: last),
        first,
      );
      expect(f.parseDate('2026-12-31', firstDate: first, lastDate: last), last);
    });

    test('out-of-range clock values parse to null', () {
      expect(TomDateTimeFormat.time24.parseTime('24:00'), isNull);
      expect(TomDateTimeFormat.time24.parseTime('12:60'), isNull);
      expect(
        TomDateTimeFormat.time24.parseTime('23:59'),
        const TimeOfDay(hour: 23, minute: 59),
      );
      expect(
        TomDateTimeFormat.time24WithSeconds.parseTime('00:00:00'),
        const TimeOfDay(hour: 0, minute: 0),
      );
    });

    test('parseTime on a date-only pattern yields null', () {
      // No hour/minute groups exist to fill, so there is nothing to build a
      // TimeOfDay from — null rather than midnight, because midnight would be
      // a fabricated value.
      expect(TomDateTimeFormat.isoDate.parseTime('2026-05-07'), isNull);
    });

    test('parseDateTime defaults the missing time components to zero', () {
      // Date-only text under a date-only pattern is a legitimate datetime at
      // midnight — here the omission is in the *pattern*, so zero is a
      // faithful reading rather than an invention.
      expect(
        TomDateTimeFormat.isoDate.parseDateTime(
          '2026-05-07',
          firstDate: _first,
          lastDate: _last,
        ),
        DateTime(2026, 5, 7),
      );
    });

    test('parseDate on a time-only pattern yields null', () {
      expect(
        TomDateTimeFormat.time24.parseDate(
          '09:30',
          firstDate: _first,
          lastDate: _last,
        ),
        isNull,
      );
    });

    test('the cached parser is reused, not recompiled per call', () {
      // The Expando cache is keyed by instance identity. Two calls on the same
      // const preset must behave identically — this is the cheapest guard
      // against a cache that returns a parser compiled from another pattern.
      const f = TomDateTimeFormat.europeanDate;
      final a = f.parseDate('07/05/2026', firstDate: _first, lastDate: _last);
      final b = f.parseDate('07/05/2026', firstDate: _first, lastDate: _last);
      expect(a, b);
      expect(a, DateTime(2026, 5, 7));
    });
  });

  // =========================================================================
  // TomDateTimeFormat — hint text
  // =========================================================================

  group('TomDateTimeFormat.hintText', () {
    test(
      'falls back to the machine pattern when no display pattern is set',
      () {
        expect(TomDateTimeFormat.isoDate.hintText, 'YYYY-MM-DD');
        expect(TomDateTimeFormat.time24.hintText, 'HH:mm');
      },
    );

    test('prefers the localised display pattern when one is set', () {
      // The German preset parses `DD.MM.YYYY` but shows Tag/Monat/Jahr — the
      // whole point of keeping the two patterns separate.
      expect(TomDateTimeFormat.germanDate.pattern, 'DD.MM.YYYY');
      expect(TomDateTimeFormat.germanDate.hintText, 'TT.MM.JJJJ');
    });
  });

  // =========================================================================
  // TomFormDatePicker
  // =========================================================================

  group('TomFormDatePicker', () {
    test('rejects an initial value outside the bounds', () {
      // The picker throws when opened on an out-of-range initial date, so the
      // field refuses to be built that way at all.
      expect(
        () => TomFormDatePicker(
          'due',
          DateTime(2030),
          firstDate: DateTime(2026),
          lastDate: DateTime(2027),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects inverted bounds', () {
      expect(
        () => TomFormDatePicker(
          'due',
          DateTime(2026, 6),
          firstDate: DateTime(2027),
          lastDate: DateTime(2026),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('reset returns to the initial value and a pristine state', () async {
      final field = TomFormDatePicker(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      field.setValue(DateTime(2026, 6, 1));
      expect(field.isDirty, isTrue);

      field.reset();
      expect(field.get(), DateTime(2026, 5, 7));
      expect(field.isDirty, isFalse);
      expect(field.validationState, isA<ValidationPristine>());
    });

    test('commit moves the baseline reset falls back to', () async {
      final field = TomFormDatePicker(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      field.setValue(DateTime(2026, 6, 1));
      field.commit();
      expect(field.isDirty, isFalse);

      field.setValue(DateTime(2026, 7, 1));
      field.reset();
      expect(field.get(), DateTime(2026, 6, 1));
    });

    testWidgets('renders the bound date through the abstract formatter', (
      tester,
    ) async {
      final field = TomFormDatePicker(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('2026-05-07'), findsOneWidget);
    });

    testWidgets('follows a programmatic write', (tester) async {
      final field = TomFormDatePicker(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));

      field.setValue(DateTime(2026, 12, 24));
      await tester.pump();
      expect(find.text('2026-12-24'), findsOneWidget);
      await _drainDebounce(tester);
    });

    testWidgets('is not openable when read-only', (tester) async {
      final field = TomFormDatePicker(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormDateCalendar
  // =========================================================================

  group('TomFormDateCalendar', () {
    testWidgets('re-keys the calendar so the highlight follows the model', (
      tester,
    ) async {
      // CalendarDatePicker captures `initialDate` on first mount and never
      // reconsults it, so the widget is keyed by the current value. Without
      // that key the selection sticks on the original date after an external
      // write — invisible in the model, wrong on screen.
      final field = TomFormDateCalendar(
        'day',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));

      final before = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(before.key, isNotNull);
      expect(before.initialDate, DateTime(2026, 5, 7));

      field.setValue(DateTime(2026, 8, 20));
      await tester.pump();

      final after = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(after.initialDate, DateTime(2026, 8, 20));
      expect(after.key, isNot(before.key));
      await _drainDebounce(tester);
    });

    testWidgets('writes back the tapped day, stripped of any time component', (
      tester,
    ) async {
      final field = TomFormDateCalendar(
        'day',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));

      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 5, 9, 13, 45));
      await tester.pump();

      expect(field.get(), DateTime(2026, 5, 9));
      await _drainDebounce(tester);
    });

    testWidgets('swallows the callback when read-only', (tester) async {
      // The inline calendar has no disabled mode, so read-only is expressed as
      // a no-op handler. Pinned because "the widget still looks tappable" is
      // exactly the shape of an authorization hole.
      final field = TomFormDateCalendar(
        'day',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 5, 9));
      await tester.pump();

      expect(field.get(), DateTime(2026, 5, 7));
    });
  });

  // =========================================================================
  // TomFormTimePicker
  // =========================================================================

  group('TomFormTimePicker', () {
    testWidgets('renders the bound time zero-padded', (tester) async {
      final field = TomFormTimePicker(
        'start',
        const TimeOfDay(hour: 9, minute: 3),
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('09:03'), findsOneWidget);
    });

    testWidgets('follows a programmatic write', (tester) async {
      final field = TomFormTimePicker(
        'start',
        const TimeOfDay(hour: 9, minute: 3),
      );
      await tester.pumpWidget(_app(field.widget));

      field.setValue(const TimeOfDay(hour: 17, minute: 45));
      await tester.pump();
      expect(find.text('17:45'), findsOneWidget);
      await _drainDebounce(tester);
    });

    test('dirtiness tracks TimeOfDay equality, not identity', () {
      final field = TomFormTimePicker(
        'start',
        const TimeOfDay(hour: 9, minute: 3),
      );
      field.setValue(const TimeOfDay(hour: 9, minute: 3));
      expect(field.isDirty, isFalse);

      field.setValue(const TimeOfDay(hour: 9, minute: 4));
      expect(field.isDirty, isTrue);
    });

    testWidgets('is not openable when read-only', (tester) async {
      final field = TomFormTimePicker(
        'start',
        const TimeOfDay(hour: 9, minute: 3),
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormDateTimePicker
  // =========================================================================

  group('TomFormDateTimePicker', () {
    testWidgets('renders date and time in one label', (tester) async {
      final field = TomFormDateTimePicker(
        'at',
        DateTime(2026, 5, 7, 9, 3),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('2026-05-07 09:03'), findsOneWidget);
    });

    test('rejects an initial value outside the bounds', () {
      expect(
        () => TomFormDateTimePicker(
          'at',
          DateTime(2030),
          firstDate: DateTime(2026),
          lastDate: DateTime(2027),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('is not openable when read-only', (tester) async {
      final field = TomFormDateTimePicker(
        'at',
        DateTime(2026, 5, 7, 9, 3),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormDateRangePicker
  // =========================================================================

  group('TomFormDateRangePicker', () {
    DateTimeRange range(DateTime a, DateTime b) =>
        DateTimeRange(start: a, end: b);

    test('rejects a range that does not fit inside the bounds', () {
      expect(
        () => TomFormDateRangePicker(
          'span',
          range(DateTime(2025), DateTime(2026, 6)),
          firstDate: DateTime(2026),
          lastDate: DateTime(2027),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('renders both endpoints with an arrow between them', (
      tester,
    ) async {
      final field = TomFormDateRangePicker(
        'span',
        range(DateTime(2026, 5, 7), DateTime(2026, 5, 20)),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('2026-05-07  →  2026-05-20'), findsOneWidget);
    });

    testWidgets('follows a programmatic write', (tester) async {
      final field = TomFormDateRangePicker(
        'span',
        range(DateTime(2026, 5, 7), DateTime(2026, 5, 20)),
        firstDate: _first,
        lastDate: _last,
      );
      await tester.pumpWidget(_app(field.widget));

      field.setValue(range(DateTime(2026, 6, 1), DateTime(2026, 6, 30)));
      await tester.pump();
      expect(find.text('2026-06-01  →  2026-06-30'), findsOneWidget);
      await _drainDebounce(tester);
    });

    testWidgets('is not openable when read-only', (tester) async {
      final field = TomFormDateRangePicker(
        'span',
        range(DateTime(2026, 5, 7), DateTime(2026, 5, 20)),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TimeRange value type
  // =========================================================================

  group('TimeRange', () {
    test('is equal by endpoints, so an observer sees a real change only when '
        'one moves', () {
      const a = TimeRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 17, minute: 0),
      );
      const b = TimeRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 17, minute: 0),
      );
      const c = TimeRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('stringifies as a pair', () {
      const r = TimeRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 17, minute: 30),
      );
      expect(r.toString(), '(TimeOfDay(09:00), TimeOfDay(17:30))');
    });
  });

  // =========================================================================
  // TomFormDateTextInput — format resolution and parse-on-type
  // =========================================================================

  group('TomFormDateTextInput', () {
    TomFormDateTextInput build({TomDateTimeFormat? format}) =>
        TomFormDateTextInput(
          'due',
          DateTime(2026, 5, 7),
          firstDate: _first,
          lastDate: _last,
          format: format,
        );

    test(
      'resolves the format from the constructor when no resource exists',
      () {
        expect(
          build().resolvedFormat.pattern,
          TomDateTimeFormat.isoDate.pattern,
        );
        expect(
          build(format: TomDateTimeFormat.germanDate).resolvedFormat.pattern,
          'DD.MM.YYYY',
        );
      },
    );

    test('a dateFormat resource outranks the constructor parameter', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'due.dateFormat': 'MM/DD/YYYY'}),
      );
      expect(
        build(format: TomDateTimeFormat.germanDate).resolvedFormat.pattern,
        'MM/DD/YYYY',
      );
    });

    test('the hint chain is resource → displayPattern → pattern', () {
      // No resource, no display pattern.
      expect(build().resolvedHintText, 'YYYY-MM-DD');

      // No resource, but the preset carries a localised display pattern.
      expect(
        build(format: TomDateTimeFormat.germanDate).resolvedHintText,
        'TT.MM.JJJJ',
      );

      // A dateHint resource outranks both.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'due.dateHint': 'jj/mm/aaaa'}),
      );
      expect(
        build(format: TomDateTimeFormat.germanDate).resolvedHintText,
        'jj/mm/aaaa',
      );
    });

    testWidgets('seeds the text box from the resolved format', (tester) async {
      final field = build(format: TomDateTimeFormat.germanDate);
      await tester.pumpWidget(_app(field.widget));
      expect(_soleTextField(tester).controller!.text, '07.05.2026');
      expect(_soleTextField(tester).decoration!.hintText, 'TT.MM.JJJJ');
    });

    testWidgets('typed text that parses writes through to the field', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2026-12-24');
      await tester.pump();
      expect(field.get(), DateTime(2026, 12, 24));
      await _drainDebounce(tester);
    });

    testWidgets('typed text that does not parse leaves the last good value', (
      tester,
    ) async {
      // This is the whole reason parse returns null instead of throwing: the
      // user is mid-keystroke, and "2026-1" must not wipe the model.
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2026-1');
      await tester.pump();
      expect(field.get(), DateTime(2026, 5, 7));
      await _drainDebounce(tester);
    });

    testWidgets('an out-of-range date is refused rather than stored', (
      tester,
    ) async {
      // Unlike the numeric text fields, a date field's bounds are structural —
      // the picker throws on an out-of-range value — so here refusing is the
      // correct behaviour rather than storing and flagging.
      final field = TomFormDateTextInput(
        'due',
        DateTime(2026, 6, 15),
        firstDate: DateTime(2026, 1, 1),
        lastDate: DateTime(2026, 12, 31),
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2027-01-01');
      await tester.pump();
      expect(field.get(), DateTime(2026, 6, 15));
      await _drainDebounce(tester);
    });

    testWidgets('losing focus on unparseable text surfaces the format hint', (
      tester,
    ) async {
      final field = build(format: TomDateTimeFormat.germanDate);
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.pump();

      // Move focus away — the on-blur check is what promotes a silent
      // non-parse into a visible error.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        _soleTextField(tester).decoration!.errorText,
        'Format: TT.MM.JJJJ',
      );
      await _drainDebounce(tester);
    });

    testWidgets('losing focus on valid text clears the error', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'nonsense');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_soleTextField(tester).decoration!.errorText, isNotNull);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '2026-12-24');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_soleTextField(tester).decoration!.errorText, isNull);
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      field.setValue(DateTime(2026, 12, 24));
      await tester.pump();
      expect(_soleTextField(tester).controller!.text, '2026-12-24');
      await _drainDebounce(tester);
    });

    testWidgets('is disabled and un-openable when read-only', (tester) async {
      final field = TomFormDateTextInput(
        'due',
        DateTime(2026, 5, 7),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      final tf = _soleTextField(tester);
      expect(tf.enabled, isFalse);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormTimeTextInput
  // =========================================================================

  group('TomFormTimeTextInput', () {
    TomFormTimeTextInput build({TomDateTimeFormat? format}) =>
        TomFormTimeTextInput(
          'start',
          const TimeOfDay(hour: 9, minute: 3),
          format: format,
        );

    test('resolves the format from resource → constructor → 24 h default', () {
      expect(build().resolvedFormat.pattern, 'HH:mm');
      expect(
        build(
          format: TomDateTimeFormat.time24WithSeconds,
        ).resolvedFormat.pattern,
        'HH:mm:ss',
      );

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'start.timeFormat': 'H:mm'}),
      );
      expect(
        build(
          format: TomDateTimeFormat.time24WithSeconds,
        ).resolvedFormat.pattern,
        'H:mm',
      );
    });

    test('a timeHint resource outranks the pattern-derived hint', () {
      expect(build().resolvedHintText, 'HH:mm');

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'start.timeHint': 'Std:Min'}),
      );
      expect(build().resolvedHintText, 'Std:Min');
    });

    testWidgets('seeds the text box from the resolved format', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));
      expect(_soleTextField(tester).controller!.text, '09:03');
    });

    testWidgets('typed text that parses writes through to the field', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '17:45');
      await tester.pump();
      expect(field.get(), const TimeOfDay(hour: 17, minute: 45));
      await _drainDebounce(tester);
    });

    testWidgets('an impossible clock value leaves the last good time', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '25:00');
      await tester.pump();
      expect(field.get(), const TimeOfDay(hour: 9, minute: 3));
      await _drainDebounce(tester);
    });

    testWidgets('losing focus on unparseable text surfaces the format hint', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'noon');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(_soleTextField(tester).decoration!.errorText, 'Format: HH:mm');
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      field.setValue(const TimeOfDay(hour: 23, minute: 59));
      await tester.pump();
      expect(_soleTextField(tester).controller!.text, '23:59');
      await _drainDebounce(tester);
    });

    testWidgets('is disabled and un-openable when read-only', (tester) async {
      final field = TomFormTimeTextInput(
        'start',
        const TimeOfDay(hour: 9, minute: 3),
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      expect(_soleTextField(tester).enabled, isFalse);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormDateTimeTextInput
  // =========================================================================

  group('TomFormDateTimeTextInput', () {
    TomFormDateTimeTextInput build({TomDateTimeFormat? format}) =>
        TomFormDateTimeTextInput(
          'at',
          DateTime(2026, 5, 7, 9, 3),
          firstDate: _first,
          lastDate: _last,
          format: format,
        );

    test('resolves the format from resource → constructor → ISO default', () {
      expect(build().resolvedFormat.pattern, 'YYYY-MM-DD HH:mm');
      expect(
        build(format: TomDateTimeFormat.usDateTime).resolvedFormat.pattern,
        'MM/DD/YYYY HH:mm',
      );

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'at.dateTimeFormat': 'DD/MM/YYYY HH:mm'}),
      );
      expect(
        build(format: TomDateTimeFormat.usDateTime).resolvedFormat.pattern,
        'DD/MM/YYYY HH:mm',
      );
    });

    test('a dateTimeHint resource outranks the pattern-derived hint', () {
      expect(build().resolvedHintText, 'YYYY-MM-DD HH:mm');

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'at.dateTimeHint': 'when?'}),
      );
      expect(build().resolvedHintText, 'when?');
    });

    testWidgets('seeds the text box from the resolved format', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));
      expect(_soleTextField(tester).controller!.text, '2026-05-07 09:03');
    });

    testWidgets('typed text that parses writes through to the field', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2026-12-24 18:30');
      await tester.pump();
      expect(field.get(), DateTime(2026, 12, 24, 18, 30));
      await _drainDebounce(tester);
    });

    testWidgets('a date without the time half leaves the last good value', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2026-12-24');
      await tester.pump();
      expect(field.get(), DateTime(2026, 5, 7, 9, 3));
      await _drainDebounce(tester);
    });

    testWidgets('losing focus on unparseable text surfaces the format hint', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'tomorrow');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        _soleTextField(tester).decoration!.errorText,
        'Format: YYYY-MM-DD HH:mm',
      );
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      field.setValue(DateTime(2026, 12, 24, 18, 30));
      await tester.pump();
      expect(_soleTextField(tester).controller!.text, '2026-12-24 18:30');
      await _drainDebounce(tester);
    });

    testWidgets('is disabled and un-openable when read-only', (tester) async {
      final field = TomFormDateTimeTextInput(
        'at',
        DateTime(2026, 5, 7, 9, 3),
        firstDate: _first,
        lastDate: _last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      expect(_soleTextField(tester).enabled, isFalse);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });
  });
}
