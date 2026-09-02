/// Demo-local interactive-logic coverage for the forms_demos showcase — review
/// tests finding §68.
///
/// The five forms demos carry substantial demo-local logic, and everything that
/// reached them before this suite only ever **mounted** them. All five are in
/// `demos` (`test/demo_harness.dart`), so `demo_overflow_test.dart` pumps each
/// one and measures it for overflow, `demo_coverage_test.dart` constructs each
/// to prove the app's tiles are reachable, `forms_dispose_test.dart` mounts and
/// unmounts each twice, and `screenshots.dart` captures each on demand. Not one
/// of them presses a button, types into a field or opens a dropdown —
/// collectively zero `tap` and zero `enterText` calls. (`widget_test.dart`
/// reaches them least of all: it asserts the four tab labels and three ACL tile
/// titles, and never opens the Forms/Actions tab.)
///
/// A mount proves a demo builds and fits; it says nothing about whether its
/// logic is right. These `WidgetTester` cases drive that logic from a
/// consumer's vantage point
/// — buttons, fields, dropdowns — and assert the observable outcome rather than
/// reaching into the private `State` classes (the one seam used,
/// [SelectionVariantsDemoState.debugSharedSource], was added in non-core step
/// #8 for exactly this):
///
///  - (a) `_FormsOverviewDemoState` validate→save→commit→display flow and the
///        `_formValid` gate.
///  - (b) `_SelectionVariantsDemoState._toggleFilter` swapping the bespoke
///        `SwappableSource` items at runtime.
///  - (c) the `_BooleanVariantsDemoState.sync()` lock-step guard keeping the
///        three shared bool concretes in step (without re-entrancy).
///  - (d) `_ComplexBreakpointsDemoState._bpLabel` / `_collapseRow` width-
///        threshold branching.
///  - (e) the two `_ComplexAuthDemoState` `TomUIStateController` resolve
///        closures (email disables on bad format; phone goes read-only when
///        verified).
///  - (f) `_GroupStateAdapter.resolveAuth` routing group ids to auth states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// TomFieldWidgetAdapter is not exported from the public barrel — it is the
// reliable way to locate a Tom field widget (and read its effective auth) by
// `tomId`. (Same rationale as the form_test authorization suites.)
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_ui_test/demo_resources.dart';
import 'package:tom_flutter_ui_test/forms_demos/forms_demos.dart';
import 'package:tom_flutter_ui_test/forms_demos/phase2_demos.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Demos resolve labels / icons / colours through the global adapters at
    // build time, so install them before mounting any demo.
    initializeDemoResources();
  });

  // The group demos mutate the process-wide TomAuthorization.adapter; reset it
  // around every test so neither baseline nor a later test inherits stale auth.
  setUp(TomAuthorization.reset);
  tearDown(TomAuthorization.reset);

  /// The widget adapter wrapping the Tom field with id [tomId].
  Finder adapterOf(String tomId) => find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      );

  /// The `TextField` underneath the field with id [tomId].
  Finder fieldOf(String tomId) =>
      find.descendant(of: adapterOf(tomId), matching: find.byType(TextField));

  /// The resolved effective auth state of the field with id [tomId].
  TomAuthState authOf(WidgetTester tester, String tomId) =>
      (adapterOf(tomId).evaluate().first.widget as TomFieldWidgetAdapter)
          .effectiveAuthState;

  Future<void> pumpDemo(WidgetTester tester, Widget demo,
      {Size size = const Size(1400, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: demo)));
    await tester.pumpAndSettle();
  }

  // ── (a) FormsOverviewDemo — validate/save/reset flow + gate ──────────────
  group('FormsOverviewDemo (§68a)', () {
    testWidgets('an invalid Save is gated — nothing is committed',
        (tester) async {
      await pumpDemo(tester, const FormsOverviewDemo());

      // All fields empty: required email/password/username fail validation, so
      // the `_formValid` gate stays closed and no values are saved/displayed.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Saved Values:'), findsNothing);
    });

    testWidgets('a valid Save commits and displays; Reset clears',
        (tester) async {
      await pumpDemo(tester, const FormsOverviewDemo());

      await tester.enterText(fieldOf('email'), 'a@b.com');
      await tester.enterText(fieldOf('password'), 'secret123');
      await tester.enterText(fieldOf('username'), 'alexis');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // validate→save→commit→display: the saved map is rendered.
      expect(find.text('Saved Values:'), findsOneWidget);
      expect(find.text('email: a@b.com'), findsOneWidget);
      expect(find.text('username: alexis'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Saved Values:'), findsNothing);
    });
  });

  // ── (b) SelectionVariantsDemo — _toggleFilter source swap ────────────────
  testWidgets('SelectionVariantsDemo: toggling the filter swaps source items '
      '(§68b)', (tester) async {
    await pumpDemo(tester, const SelectionVariantsDemo());
    final state = tester.state<SelectionVariantsDemoState>(
        find.byType(SelectionVariantsDemo));

    expect((await state.debugSharedSource.getItems()).length, 4,
        reason: 'full source starts with four items');

    // `_filtered` starts false → button offers the filtered view.
    await tester.tap(find.widgetWithText(FilledButton, 'Show filtered source'));
    await tester.pumpAndSettle();
    expect(
      (await state.debugSharedSource.getItems()).map((e) => e.value).toList(),
      ['apple', 'cherry'],
      reason: '_toggleFilter installed the filtered item list',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Show all items'));
    await tester.pumpAndSettle();
    expect((await state.debugSharedSource.getItems()).length, 4,
        reason: 'toggling back restores the full source');
  });

  // ── (c) BooleanVariantsDemo — sync() lock-step guard ─────────────────────
  testWidgets('BooleanVariantsDemo: sync() keeps the three shared concretes in '
      'lock-step (§68c)', (tester) async {
    await pumpDemo(tester, const BooleanVariantsDemo());

    final checkbox =
        find.descendant(of: adapterOf('shared1'), matching: find.byType(Checkbox));
    final toggleSwitch =
        find.descendant(of: adapterOf('shared2'), matching: find.byType(Switch));
    final segmented = find.descendant(
        of: adapterOf('shared3'), matching: find.byType(SegmentedButton<bool>));

    // All three start off.
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(tester.widget<Switch>(toggleSwitch).value, isFalse);
    expect(tester.widget<SegmentedButton<bool>>(segmented).selected,
        equals({false}));

    // Flip the checkbox — sync() must propagate to switch and toggle without
    // re-entering (the `_syncing` guard) or throwing.
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(tester.widget<Switch>(toggleSwitch).value, isTrue,
        reason: 'sync() propagated the checkbox change to the switch');
    expect(tester.widget<SegmentedButton<bool>>(segmented).selected,
        equals({true}),
        reason: 'sync() propagated the checkbox change to the toggle');

    // Flip the switch back off — the round-trip keeps all three in step.
    await tester.tap(find.descendant(
        of: adapterOf('shared2'), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(tester.widget<SegmentedButton<bool>>(segmented).selected,
        equals({false}));
    expect(tester.takeException(), isNull);
  });

  // ── (d) ComplexBreakpointsDemo — _bpLabel / _collapseRow thresholds ──────
  testWidgets('ComplexBreakpointsDemo: _bpLabel maps width to a style label '
      '(§68d)', (tester) async {
    // < 480 → compact (≈368px content after 16px padding either side).
    await pumpDemo(tester, const ComplexBreakpointsDemo(),
        size: const Size(400, 1600));
    expect(find.textContaining('compact style'), findsOneWidget);

    // 480 ≤ w < 900 → comfortable.
    await pumpDemo(tester, const ComplexBreakpointsDemo(),
        size: const Size(700, 1600));
    expect(find.textContaining('comfortable style'), findsOneWidget);

    // ≥ 900 → spacious.
    await pumpDemo(tester, const ComplexBreakpointsDemo(),
        size: const Size(1000, 1600));
    expect(find.textContaining('spacious style'), findsOneWidget);
  });

  testWidgets('ComplexBreakpointsDemo: _collapseRow stacks below 600px and '
      'rows above (§68d)', (tester) async {
    Finder collapsePanel() => find.ancestor(
        of: find.text('Collapses under 600px'), matching: find.byType(Card));
    Finder nameInPanel() =>
        find.descendant(of: collapsePanel(), matching: adapterOf('name'));
    Finder emailInPanel() =>
        find.descendant(of: collapsePanel(), matching: adapterOf('email'));

    // Narrow (< 600): the two fields stack — email sits below name, same left.
    await pumpDemo(tester, const ComplexBreakpointsDemo(),
        size: const Size(500, 1600));
    var nameRect = tester.getRect(nameInPanel());
    var emailRect = tester.getRect(emailInPanel());
    expect(emailRect.top, greaterThan(nameRect.bottom - 1),
        reason: 'narrow layout stacks email beneath name');
    expect((emailRect.left - nameRect.left).abs(), lessThan(1),
        reason: 'stacked fields share the same left edge');

    // Wide (≥ 600): the fields sit side-by-side in a Row — same top, email to
    // the right of name.
    await pumpDemo(tester, const ComplexBreakpointsDemo(),
        size: const Size(900, 1600));
    nameRect = tester.getRect(nameInPanel());
    emailRect = tester.getRect(emailInPanel());
    expect((emailRect.top - nameRect.top).abs(), lessThan(1),
        reason: 'row layout aligns the two fields on the same top');
    expect(emailRect.left, greaterThan(nameRect.right - 1),
        reason: 'row layout places email to the right of name');
  });

  // ── (e) ComplexAuthDemo — UIStateController cross-field closures ─────────
  testWidgets('ComplexAuthDemo: email UIStateController disables on bad format '
      '(§68e)', (tester) async {
    await pumpDemo(tester, const ComplexAuthDemo());

    // Empty → the closure returns `current` (full).
    expect(authOf(tester, 'emailLive'), TomAuthState.full);

    // A well-formed value stays full.
    await tester.enterText(fieldOf('emailLive'), 'a@b.com');
    await tester.pumpAndSettle();
    expect(authOf(tester, 'emailLive'), TomAuthState.full);

    // A non-empty value without '@' disables the field.
    await tester.enterText(fieldOf('emailLive'), 'bademail');
    await tester.pumpAndSettle();
    expect(authOf(tester, 'emailLive'), TomAuthState.disabled,
        reason: 'the resolve closure disables on a malformed email');
  });

  testWidgets('ComplexAuthDemo: phone UIStateController goes read-only when '
      'verified (§68e)', (tester) async {
    await pumpDemo(tester, const ComplexAuthDemo());

    expect(authOf(tester, 'phoneLive'), TomAuthState.full);

    final verify = find.descendant(
        of: adapterOf('phoneVerified'), matching: find.byType(Checkbox));
    await tester.ensureVisible(verify);
    await tester.tap(verify);
    await tester.pumpAndSettle();

    expect(authOf(tester, 'phoneLive'), TomAuthState.read,
        reason: 'verifying the phone flips the live phone field read-only');
  });

  // ── (f) ComplexAuthDemo — _GroupStateAdapter.resolveAuth routing ─────────
  testWidgets('ComplexAuthDemo: group dropdown routes auth through '
      '_GroupStateAdapter (§68f)', (tester) async {
    await pumpDemo(tester, const ComplexAuthDemo());

    // Baseline (no adapter installed): every group field resolves to full.
    expect(authOf(tester, 'fAll1'), TomAuthState.full);
    expect(authOf(tester, 'fN1'), TomAuthState.full);

    // The first DropdownButton<TomAuthState> in the tree is the controlsAll
    // group selector (group section precedes the subform parent dropdown).
    final controlsAll = find.byType(DropdownButton<TomAuthState>).first;
    await tester.ensureVisible(controlsAll);
    await tester.tap(controlsAll);
    await tester.pumpAndSettle();
    await tester.tap(find.text('read').last);
    await tester.pumpAndSettle();

    // _GroupStateAdapter.resolveAuth routes groupAll→read; controlsAll mode
    // replaces member state, so both controlsAll fields become read while the
    // untouched controlsNarrowest group still resolves to full (the map's
    // `?? full` default).
    expect(authOf(tester, 'fAll1'), TomAuthState.read);
    expect(authOf(tester, 'fAll2'), TomAuthState.read);
    expect(authOf(tester, 'fN1'), TomAuthState.full,
        reason: 'unset groups fall through to the adapter default (full)');
  });
}
