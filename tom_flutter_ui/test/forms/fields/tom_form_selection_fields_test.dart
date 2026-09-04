/// The source-backed selection fields and the nullable inputs.
///
/// What binds this file together is that every widget in it derives what the
/// user sees from a [TomSelectableSource] that resolves *asynchronously*. The
/// field holds a value; the source holds the labels; the two are loaded a frame
/// apart. Almost every interesting behaviour here lives in that gap:
///
///  * **the value is not in the source** — single-pick widgets snap to the
///    first enabled item, multi-pick widgets prune. Both silently rewrite the
///    model, which is defensible but must be deliberate.
///  * **the source has not loaded yet** — the first frame renders with an
///    empty item list, so anything that reads a label on that frame reads a
///    fallback. This is where the search input's display bug lived.
///  * **null as a first-class value** — the nullable family distinguishes
///    "explicitly empty" from "pristine", and expresses the former through a
///    four-step display-resolution chain that no test previously exercised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, child: child)),
  ),
);

TomUIStateController get _readOnly =>
    TomUIStateController(resolve: (_, _) => TomAuthState.read);

/// The field's fast-validation debounce is 300 ms; anything shorter leaves a
/// live timer behind at teardown.
Future<void> _drainDebounce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 700));

/// The source resolves through a `Future`, so the first frame always renders an
/// empty item list. One extra pump settles it.
Future<void> _pumpLoaded(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_app(child));
  await tester.pump();
}

StaticSelectableSource<int> _grades({bool betaEnabled = true}) =>
    StaticSelectableSource<int>([
      const SelectableItem(value: 1, label: 'Alpha'),
      SelectableItem(value: 2, label: 'Beta', enabled: betaEnabled),
      const SelectableItem(value: 3, label: 'Gamma'),
    ]);

/// A domain object with value semantics — the object fields key their menus off
/// `==`, so an identity-only type would look like it worked and then fail the
/// moment a value round-tripped through a repository.
class _Country {
  final String iso;
  final String name;
  const _Country(this.iso, this.name);

  @override
  bool operator ==(Object other) => other is _Country && other.iso == iso;

  @override
  int get hashCode => iso.hashCode;
}

const _de = _Country('DE', 'Germany');
const _fr = _Country('FR', 'France');
const _jp = _Country('JP', 'Japan');

StaticSelectableSource<_Country> _countries() =>
    StaticSelectableSource<_Country>(const [
      SelectableItem(value: _de, label: 'Germany'),
      SelectableItem(value: _fr, label: 'France'),
      SelectableItem(value: _jp, label: 'Japan'),
    ]);

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
  // SelectableItem
  // =========================================================================

  group('SelectableItem', () {
    test('is equal by value alone, so a relabel is not a different item', () {
      const a = SelectableItem(value: 1, label: 'Alpha');
      const b = SelectableItem(value: 1, label: 'Α (relabelled)');
      const c = SelectableItem(value: 2, label: 'Alpha');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('reports its disabled state when described', () {
      expect(
        const SelectableItem(
          value: 1,
          label: 'Alpha',
          enabled: false,
        ).toString(),
        contains('disabled'),
      );
      expect(
        const SelectableItem(value: 1, label: 'Alpha').toString(),
        isNot(contains('disabled')),
      );
    });
  });

  // =========================================================================
  // The list-field toggle contract, shared by enum and object multi-selects
  // =========================================================================

  group('toggleItem', () {
    test('allocates a fresh list rather than mutating in place', () {
      // The field compares old against new to decide whether anything changed;
      // mutating the held list in place would make every comparison see equal
      // values and swallow the notification.
      final field = TomFormEnumFilterChips<int>('grades', const [
        1,
      ], source: _grades());
      final before = field.get();
      field.toggleItem(2, true);

      expect(identical(field.get(), before), isFalse);
      expect(before, const [1]);
      expect(field.get(), const [1, 2]);
    });

    test('is idempotent in both directions', () {
      final field = TomFormEnumFilterChips<int>('grades', const [
        1,
      ], source: _grades());
      field.toggleItem(1, true);
      expect(field.get(), const [1]);

      field.toggleItem(3, false);
      expect(field.get(), const [1]);

      field.toggleItem(1, false);
      expect(field.get(), isEmpty);
      field.toggleItem(1, false);
      expect(field.get(), isEmpty);
    });

    test('preserves insertion order rather than the source order', () {
      final field = TomFormEnumFilterChips<int>(
        'grades',
        const [],
        source: _grades(),
      );
      field.toggleItem(3, true);
      field.toggleItem(1, true);
      expect(field.get(), const [3, 1]);
    });

    test('the object variant keys off value equality, not identity', () {
      final field = TomFormObjectFilterChips<_Country>('visited', const [
        _de,
      ], source: _countries());
      // A distinct instance that compares equal must be recognised as already
      // present, and must be removable.
      field.toggleItem(const _Country('DE', 'Deutschland'), true);
      expect(field.get(), hasLength(1));

      field.toggleItem(const _Country('DE', 'Deutschland'), false);
      expect(field.get(), isEmpty);
    });
  });

  // =========================================================================
  // TomFormEnumDropdown
  // =========================================================================

  group('TomFormEnumDropdown', () {
    testWidgets('offers one menu entry per source item', (tester) async {
      final field = TomFormEnumDropdown<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      // `DropdownButtonFormField` does not expose its items; the menu it
      // builds lives on the inner `DropdownButton`, which is what the user
      // actually interacts with.
      final dd = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dd.items, hasLength(3));
      expect(dd.value, 1);
    });

    testWidgets('carries the source item disabled flag into the menu', (
      tester,
    ) async {
      final field = TomFormEnumDropdown<int>(
        'grade',
        1,
        source: _grades(betaEnabled: false),
      );
      await _pumpLoaded(tester, field.widget);

      final dd = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dd.items!.map((i) => i.enabled), [true, false, true]);
    });

    testWidgets(
      'snaps to the first enabled item when the value is not offered',
      (tester) async {
        // A single-pick widget cannot render a value the source does not know,
        // so it rewrites the model rather than showing an empty box. Pinned
        // because it is a silent write — surprising, but deliberate.
        final field = TomFormEnumDropdown<int>('grade', 99, source: _grades());
        await _pumpLoaded(tester, field.widget);

        expect(field.get(), 1);
        await _drainDebounce(tester);
      },
    );

    testWidgets('skips a disabled item when snapping', (tester) async {
      final field = TomFormEnumDropdown<int>(
        'grade',
        99,
        source: StaticSelectableSource<int>(const [
          SelectableItem(value: 1, label: 'Alpha', enabled: false),
          SelectableItem(value: 2, label: 'Beta'),
        ]),
      );
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), 2);
      await _drainDebounce(tester);
    });

    testWidgets('is not changeable when read-only', (tester) async {
      final field = TomFormEnumDropdown<int>(
        'grade',
        1,
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .onChanged,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormEnumSegmented
  // =========================================================================

  group('TomFormEnumSegmented', () {
    testWidgets('renders a placeholder until the source resolves', (
      tester,
    ) async {
      // Deliberately no settling pump: this is the first frame, before the
      // source future completes. A SegmentedButton with zero segments asserts,
      // so the widget must render something else entirely.
      final field = TomFormEnumSegmented<int>('grade', 1, source: _grades());
      await tester.pumpWidget(_app(field.widget));

      expect(find.byType(SegmentedButton<int>), findsNothing);
      expect(find.text('…'), findsOneWidget);

      await tester.pump();
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
    });

    testWidgets('renders one segment per item and selects the bound value', (
      tester,
    ) async {
      final field = TomFormEnumSegmented<int>('grade', 2, source: _grades());
      await _pumpLoaded(tester, field.widget);

      final sb = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(sb.segments, hasLength(3));
      expect(sb.selected, {2});
    });

    testWidgets('falls back to the first segment when the value is unknown', (
      tester,
    ) async {
      // Belt and braces against the SegmentedButton assert: even if the snap
      // in `_resetIfMissing` were ever removed, the selection passed to the
      // widget still has to name a real segment.
      final field = TomFormEnumSegmented<int>('grade', 99, source: _grades());
      await tester.pumpWidget(_app(field.widget));
      await tester.pump();

      final sb = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(sb.selected, {1});
      await _drainDebounce(tester);
    });

    testWidgets('writes the tapped segment back to the field', (tester) async {
      final field = TomFormEnumSegmented<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.text('Gamma'));
      await tester.pump();
      expect(field.get(), 3);
      await _drainDebounce(tester);
    });

    testWidgets('is not changeable when read-only', (tester) async {
      final field = TomFormEnumSegmented<int>(
        'grade',
        1,
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .onSelectionChanged,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormEnumRadioGroup
  // =========================================================================

  group('TomFormEnumRadioGroup', () {
    testWidgets('renders one labelled row per item', (tester) async {
      final field = TomFormEnumRadioGroup<int>('grade', 2, source: _grades());
      await _pumpLoaded(tester, field.widget);

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('selects the row whose value is bound', (tester) async {
      final field = TomFormEnumRadioGroup<int>('grade', 2, source: _grades());
      await _pumpLoaded(tester, field.widget);

      // The bound value lives on the `RadioGroup` the field renders around
      // the rows, not on each row: that is where a radio's selection comes
      // from now, and asserting it here is what catches a field that stops
      // supplying the ancestor.
      final group = tester.widget<RadioGroup<int>>(
        find.byType(RadioGroup<int>),
      );
      expect(group.groupValue, 2);

      final radios = tester.widgetList<Radio<int>>(find.byType(Radio<int>));
      expect(radios.map((r) => r.value), [1, 2, 3]);
    });

    testWidgets('writes the tapped row back to the field', (tester) async {
      final field = TomFormEnumRadioGroup<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.text('Gamma'));
      await tester.pump();
      expect(field.get(), 3);
      await _drainDebounce(tester);
    });

    testWidgets('leaves a disabled row unselectable', (tester) async {
      final field = TomFormEnumRadioGroup<int>(
        'grade',
        1,
        source: _grades(betaEnabled: false),
      );
      await _pumpLoaded(tester, field.widget);

      // A single row opts out through `enabled`. Withholding `onChanged` no
      // longer expresses it — the shared ancestor supplies one callback for
      // every row, so the per-row lever is the only one left.
      final radios = tester
          .widgetList<Radio<int>>(find.byType(Radio<int>))
          .toList();
      expect(radios[1].enabled, isFalse);
      expect(radios[0].enabled, isTrue);
    });

    testWidgets('disables every row when read-only', (tester) async {
      final field = TomFormEnumRadioGroup<int>(
        'grade',
        1,
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      final radios = tester.widgetList<Radio<int>>(find.byType(Radio<int>));
      expect(radios.map((r) => r.enabled), everyElement(isFalse));
    });
  });

  // =========================================================================
  // TomFormEnumFilterChips
  // =========================================================================

  group('TomFormEnumFilterChips', () {
    testWidgets('renders one chip per item with the bound selection', (
      tester,
    ) async {
      final field = TomFormEnumFilterChips<int>('grades', const [
        1,
        3,
      ], source: _grades());
      await _pumpLoaded(tester, field.widget);

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips, hasLength(3));
      expect(chips.map((c) => c.selected), [true, false, true]);
    });

    testWidgets('tapping a chip toggles it in both directions', (tester) async {
      final field = TomFormEnumFilterChips<int>('grades', const [
        1,
      ], source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(field.get(), const [1, 2]);

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(field.get(), const [2]);
      await _drainDebounce(tester);
    });

    testWidgets('prunes a selection the source no longer offers', (
      tester,
    ) async {
      // The multi-select counterpart of the single-pick snap: rather than
      // rewrite to something else, it drops what it cannot show.
      final field = TomFormEnumFilterChips<int>('grades', const [
        1,
        99,
      ], source: _grades());
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), const [1]);
      await _drainDebounce(tester);
    });

    testWidgets('leaves a disabled chip untappable', (tester) async {
      final field = TomFormEnumFilterChips<int>(
        'grades',
        const [],
        source: _grades(betaEnabled: false),
      );
      await _pumpLoaded(tester, field.widget);

      final chips = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .toList();
      expect(chips[1].onSelected, isNull);
      expect(chips[0].onSelected, isNotNull);
    });

    testWidgets('disables every chip when read-only', (tester) async {
      final field = TomFormEnumFilterChips<int>(
        'grades',
        const [1],
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .map((c) => c.onSelected),
        everyElement(isNull),
      );
    });
  });

  // =========================================================================
  // TomFormObjectDropdown / TomFormObjectFilterChips
  // =========================================================================

  group('TomFormObjectDropdown', () {
    testWidgets('binds a domain object through value equality', (tester) async {
      final field = TomFormObjectDropdown<_Country>(
        'country',
        // A distinct instance that compares equal to the source's entry — the
        // menu must recognise it rather than treat it as "not offered" and
        // snap away.
        const _Country('FR', 'République française'),
        source: _countries(),
      );
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), _fr);
      final dd = tester.widget<DropdownButtonFormField<_Country>>(
        find.byType(DropdownButtonFormField<_Country>),
      );
      expect(dd.initialValue, _fr);
      await _drainDebounce(tester);
    });

    testWidgets('snaps to the first item when the object is not offered', (
      tester,
    ) async {
      final field = TomFormObjectDropdown<_Country>(
        'country',
        const _Country('ZZ', 'Nowhere'),
        source: _countries(),
      );
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), _de);
      await _drainDebounce(tester);
    });
  });

  group('TomFormObjectFilterChips', () {
    testWidgets('prunes objects the source no longer offers', (tester) async {
      final field = TomFormObjectFilterChips<_Country>('visited', const [
        _de,
        _Country('ZZ', 'Nowhere'),
      ], source: _countries());
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), const [_de]);
      await _drainDebounce(tester);
    });

    testWidgets('tapping a chip toggles the object', (tester) async {
      final field = TomFormObjectFilterChips<_Country>(
        'visited',
        const [],
        source: _countries(),
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.text('Japan'));
      await tester.pump();
      expect(field.get(), const [_jp]);
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // TomFormSearchInput
  // =========================================================================

  group('TomFormSearchInput', () {
    testWidgets(
      'shows the source label for the bound value, not its toString',
      (tester) async {
        // The source resolves a frame after the first build, so anything that
        // reads a label during that first frame gets `value.toString()`. For a
        // non-String value type that is a visibly wrong display which never
        // corrects itself unless the text field is rebuilt.
        final field = TomFormSearchInput<int>('grade', 2, source: _grades());
        await _pumpLoaded(tester, field.widget);

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Beta',
        );
      },
    );

    testWidgets('a programmatic write reaches the display text', (
      tester,
    ) async {
      // Same seeding problem from the other end: the controller is built
      // once, so a `setValue` that does not go through the option list
      // has to re-seed it too.
      final field = TomFormSearchInput<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      field.setValue(3);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Gamma',
      );
      await _drainDebounce(tester);
    });

    testWidgets('prefers an explicit labelOf over the source label', (
      tester,
    ) async {
      final field = TomFormSearchInput<int>(
        'grade',
        2,
        source: _grades(),
        labelOf: (v) => 'Grade #$v',
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Grade #2',
      );
    });

    testWidgets('offers a default search hint when none is configured', (
      tester,
    ) async {
      final field = TomFormSearchInput<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        'Type to search…',
      );
    });

    test('resolves its hint from the override then the resource', () {
      TomFormSearchInput<int> build({String? override}) =>
          TomFormSearchInput<int>(
            'grade',
            1,
            source: _grades(),
            hintTextOverride: override,
          );

      expect(build().hintText, isNull);
      expect(build(override: 'Find a grade').hintText, 'Find a grade');

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'grade.hint': 'Suchen…'}),
      );
      expect(build().hintText, 'Suchen…');
      // An explicit override still wins — the resource is the fallback, not
      // an override of the override.
      expect(build(override: 'Find a grade').hintText, 'Find a grade');
    });

    testWidgets('filters the options by a case-insensitive substring', (
      tester,
    ) async {
      final field = TomFormSearchInput<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'mm');
      await tester.pump();

      // 'Gamma' contains 'mm'; the other two do not.
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      await _drainDebounce(tester);
    });

    testWidgets('honours a custom search predicate', (tester) async {
      final field = TomFormSearchInput<int>(
        'grade',
        1,
        source: _grades(),
        // Prefix match instead of the default substring match.
        searchPredicate: (q, item) =>
            item.label.toLowerCase().startsWith(q.toLowerCase()),
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'mm');
      await tester.pump();

      expect(find.text('Gamma'), findsNothing);
      await _drainDebounce(tester);
    });

    testWidgets('picking an option writes the value back', (tester) async {
      final field = TomFormSearchInput<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Gam');
      await tester.pump();
      await tester.tap(find.text('Gamma'));
      await tester.pump();

      expect(field.get(), 3);
      await _drainDebounce(tester);
    });

    testWidgets('hides disabled items from the option list', (tester) async {
      final field = TomFormSearchInput<int>(
        'grade',
        1,
        source: _grades(betaEnabled: false),
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();

      expect(find.text('Beta'), findsNothing);
      expect(find.text('Gamma'), findsOneWidget);
      await _drainDebounce(tester);
    });

    testWidgets('is disabled when read-only', (tester) async {
      final field = TomFormSearchInput<int>(
        'grade',
        1,
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  // =========================================================================
  // TomFormLookupDialog
  // =========================================================================

  group('TomFormLookupDialog', () {
    testWidgets('mirrors the source label into its read-only display', (
      tester,
    ) async {
      final field = TomFormLookupDialog<int>('grade', 2, source: _grades());
      await _pumpLoaded(tester, field.widget);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Beta',
      );
    });

    testWidgets('prefers an explicit labelOf', (tester) async {
      final field = TomFormLookupDialog<int>(
        'grade',
        2,
        source: _grades(),
        labelOf: (v) => 'Grade #$v',
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Grade #2',
      );
    });

    testWidgets('follows a programmatic write', (tester) async {
      final field = TomFormLookupDialog<int>('grade', 2, source: _grades());
      await _pumpLoaded(tester, field.widget);

      field.setValue(3);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Gamma',
      );
      await _drainDebounce(tester);
    });

    testWidgets('honours labelTextOverride despite the decoration mixin', (
      tester,
    ) async {
      // `TomDropdownDecorationMixin` declares `labelText => null`, and a
      // mixin applied over a superclass wins over that superclass — so
      // this class has to re-declare the getter or the constructor
      // parameter is silently dead. Pinned because nothing about the
      // call site hints that a mixin can eat a declared parameter.
      final field = TomFormLookupDialog<int>(
        'grade',
        1,
        source: _grades(),
        labelTextOverride: 'Grade',
      );
      expect(field.labelText, 'Grade');

      await _pumpLoaded(tester, field.widget);
      expect(find.text('Grade'), findsOneWidget);
    });

    testWidgets('titles the dialog from the field label when none is given', (
      tester,
    ) async {
      final field = TomFormLookupDialog<int>(
        'grade',
        1,
        source: _grades(),
        labelTextOverride: 'Grade',
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      // The row's floating label and the dialog title both read "Grade".
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Grade'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('browsing and picking writes the chosen value back', (
      tester,
    ) async {
      final field = TomFormLookupDialog<int>(
        'grade',
        1,
        source: _grades(),
        labelTextOverride: 'Grade',
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(field.get(), 3);
      await _drainDebounce(tester);
    });

    testWidgets('cancelling the dialog leaves the value alone', (tester) async {
      final field = TomFormLookupDialog<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(field.get(), 1);
    });

    testWidgets('the dialog filter narrows the candidate list', (tester) async {
      final field = TomFormLookupDialog<int>('grade', 1, source: _grades());
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // The dialog's own filter box is the autofocused one.
      await tester.enterText(find.byType(TextField).last, 'gam');
      await tester.pumpAndSettle();

      // Scoped to the dialog: the field's own read-only display still
      // shows the bound value's label ("Alpha") behind the barrier, and
      // an unscoped finder would pick that up.
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );
      expect(inDialog('Gamma'), findsOneWidget);
      expect(inDialog('Alpha'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('titles the dialog from dialogTitle, then the label', (
      tester,
    ) async {
      final field = TomFormLookupDialog<int>(
        'grade',
        1,
        source: _grades(),
        labelTextOverride: 'Grade',
        dialogTitle: 'Pick a grade',
      );
      await _pumpLoaded(tester, field.widget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('Pick a grade'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // Nullable inputs — the null-display resolution chain
  // =========================================================================

  group('nullable null display', () {
    TomFormNStringInput build({String? nullDisplay, String? hint}) =>
        TomFormNStringInput(
          'note',
          null,
          nullDisplayOverride: nullDisplay,
          hintTextOverride: hint,
        );

    test(
      'falls back to a visible sentinel so null is distinguishable from ""',
      () {
        expect(build().resolveNullDisplay(), '— null —');
      },
    );

    test('uses the hint when one is configured', () {
      expect(build(hint: 'optional').resolveNullDisplay(), 'optional');
    });

    test('a nullDisplay resource outranks the hint', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'note.nullDisplay': 'Nicht gesetzt'}),
      );
      expect(build(hint: 'optional').resolveNullDisplay(), 'Nicht gesetzt');
    });

    test('an explicit override outranks everything, including empty', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'note.nullDisplay': 'Nicht gesetzt'}),
      );
      expect(
        build(nullDisplay: 'None', hint: 'optional').resolveNullDisplay(),
        'None',
      );
      // Empty is a real choice — "render nothing" — not an absent override.
      expect(build(nullDisplay: '', hint: 'optional').resolveNullDisplay(), '');
    });

    testWidgets('an empty null display pins the label into the floating slot', (
      tester,
    ) async {
      // With both the value and the hint empty, Material drops the label into
      // the field area as a stand-in placeholder — which would defeat the
      // documented "render nothing" mode.
      final field = build(nullDisplay: '');
      await tester.pumpWidget(_app(field.widget));

      final dec = tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(dec.hintText, '');
      expect(dec.floatingLabelBehavior, FloatingLabelBehavior.always);
    });

    testWidgets('a non-empty null display leaves the label behaviour default', (
      tester,
    ) async {
      final field = build();
      await tester.pumpWidget(_app(field.widget));

      final dec = tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(dec.hintText, '— null —');
      expect(dec.floatingLabelBehavior, isNull);
    });
  });

  // =========================================================================
  // TomFormNStringInput
  // =========================================================================

  group('TomFormNStringInput', () {
    testWidgets('renders null as empty text, not as the word "null"', (
      tester,
    ) async {
      final field = TomFormNStringInput('note', null);
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('emptying the text sets the value to null', (tester) async {
      // For a String field, "" and null are genuinely different states and the
      // widget has to pick one for an empty box. It picks null, which is why
      // there is a nullable variant at all.
      final field = TomFormNStringInput('note', 'hello');
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(field.get(), isNull);
      await _drainDebounce(tester);
    });

    testWidgets('the clear button appears only when there is a value', (
      tester,
    ) async {
      final field = TomFormNStringInput('note', null);
      await tester.pumpWidget(_app(field.widget));
      expect(find.byIcon(Icons.clear), findsNothing);

      field.setValue('hello');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(field.get(), isNull);
      expect(find.byIcon(Icons.clear), findsNothing);
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field offers no clear button', (tester) async {
      final field = TomFormNStringInput(
        'note',
        'hello',
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    test('reset returns to the initial value, including back to null', () {
      final field = TomFormNStringInput('note', null);
      field.setValue('hello');
      expect(field.isDirty, isTrue);

      field.reset();
      expect(field.get(), isNull);
      expect(field.isDirty, isFalse);
    });
  });

  // =========================================================================
  // TomFormNIntInput / TomFormNDoubleInput
  // =========================================================================

  group('TomFormNIntInput', () {
    testWidgets('typed digits parse into the field', (tester) async {
      final field = TomFormNIntInput('qty', null);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();
      expect(field.get(), 42);
      await _drainDebounce(tester);
    });

    testWidgets('emptying the text yields null', (tester) async {
      final field = TomFormNIntInput('qty', 42);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(field.get(), isNull);
      await _drainDebounce(tester);
    });

    testWidgets('a half-typed token does not flip the value to null', (
      tester,
    ) async {
      // A lone '-' is unparseable but is not the user saying "empty" — the
      // widget skips it rather than reading it as a clear.
      final field = TomFormNIntInput('qty', 42);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '-');
      await tester.pump();
      expect(field.get(), 42);

      await tester.enterText(find.byType(TextField), '-7');
      await tester.pump();
      expect(field.get(), -7);
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = TomFormNIntInput('qty', null);
      await tester.pumpWidget(_app(field.widget));

      field.setValue(7);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '7',
      );

      field.setValue(null);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await _drainDebounce(tester);
    });
  });

  group('TomFormNDoubleInput', () {
    testWidgets('fixes the rendered precision when decimals are set', (
      tester,
    ) async {
      final field = TomFormNDoubleInput('rate', 1.5, decimals: 3);
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1.500',
      );
    });

    testWidgets('renders verbatim when no precision is configured', (
      tester,
    ) async {
      final field = TomFormNDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1.5',
      );
    });

    testWidgets('a bare decimal point does not flip the value to null', (
      tester,
    ) async {
      final field = TomFormNDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '.');
      await tester.pump();
      expect(field.get(), 1.5);
      await _drainDebounce(tester);
    });

    testWidgets('emptying the text yields null', (tester) async {
      final field = TomFormNDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(field.get(), isNull);
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // TomFormNDateInput
  // =========================================================================

  group('TomFormNDateInput', () {
    final first = DateTime(2000, 1, 1);
    final last = DateTime(2099, 12, 31);

    test('accepts a null initial value despite the range assert', () {
      // The bounds check has to skip null, or "no date yet" would be
      // unrepresentable — which is the entire point of the nullable variant.
      expect(
        () => TomFormNDateInput('due', null, firstDate: first, lastDate: last),
        returnsNormally,
      );
      expect(
        () => TomFormNDateInput(
          'due',
          DateTime(2100),
          firstDate: first,
          lastDate: last,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('renders the null display until a date is set', (tester) async {
      final field = TomFormNDateInput(
        'due',
        null,
        firstDate: first,
        lastDate: last,
        nullDisplayOverride: 'No date',
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('No date'), findsOneWidget);

      field.setValue(DateTime(2026, 5, 7));
      await tester.pump();
      expect(find.text('2026-05-07'), findsOneWidget);
      await _drainDebounce(tester);
    });

    testWidgets('the clear button appears only when a date is set', (
      tester,
    ) async {
      final field = TomFormNDateInput(
        'due',
        DateTime(2026, 5, 7),
        firstDate: first,
        lastDate: last,
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(field.get(), isNull);
      expect(find.byIcon(Icons.clear), findsNothing);
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field offers neither picker nor clear', (
      tester,
    ) async {
      final field = TomFormNDateInput(
        'due',
        DateTime(2026, 5, 7),
        firstDate: first,
        lastDate: last,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  // =========================================================================
  // TomFormNEnumDropdown
  // =========================================================================

  group('TomFormNEnumDropdown', () {
    testWidgets('prepends a null entry to the source items', (tester) async {
      final field = TomFormNEnumDropdown<int>('grade', null, source: _grades());
      await _pumpLoaded(tester, field.widget);

      final dd = tester.widget<DropdownButton<int?>>(
        find.byType(DropdownButton<int?>),
      );
      expect(dd.items, hasLength(4));
      expect(dd.items!.first.value, isNull);
      expect(dd.value, isNull);
    });

    testWidgets('labels the null entry from the resolution chain', (
      tester,
    ) async {
      final field = TomFormNEnumDropdown<int>(
        'grade',
        null,
        source: _grades(),
        nullDisplayOverride: 'Any grade',
      );
      await _pumpLoaded(tester, field.widget);

      expect(find.text('Any grade'), findsWidgets);
    });

    testWidgets('does not snap away from a value the source does not offer', (
      tester,
    ) async {
      // Unlike the non-nullable dropdown there is always a valid entry to fall
      // back on — the null one — so the widget shows that instead of rewriting
      // the model.
      final field = TomFormNEnumDropdown<int>('grade', 99, source: _grades());
      await _pumpLoaded(tester, field.widget);

      expect(field.get(), 99);
      final dd = tester.widget<DropdownButtonFormField<int?>>(
        find.byType(DropdownButtonFormField<int?>),
      );
      expect(dd.initialValue, isNull);
    });

    testWidgets('is not changeable when read-only', (tester) async {
      final field = TomFormNEnumDropdown<int>(
        'grade',
        1,
        source: _grades(),
        uiStateController: _readOnly,
      );
      await _pumpLoaded(tester, field.widget);

      expect(
        tester
            .widget<DropdownButtonFormField<int?>>(
              find.byType(DropdownButtonFormField<int?>),
            )
            .onChanged,
        isNull,
      );
    });
  });
}
