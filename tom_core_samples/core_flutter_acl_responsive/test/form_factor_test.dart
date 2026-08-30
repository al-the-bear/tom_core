// The form-factor group is the one group whose entire subject is the width →
// tier mapping, so a cell whose title disagrees with the tier it actually
// resolves is the worst possible error it can carry — and it carried one: a cell
// titled "Desktop (900px)" rendered a badge reading
// `resolveFormFactor(900.0) → tablet`, because 900 is below the 1024 desktop
// boundary.
//
// Two kinds of assertion follow. The named ones pin one width per tier, so the
// group is required to actually *demonstrate* all three tiers rather than two of
// them. The last one is what stops the drift recurring: it reads every cell's
// title and that cell's own badge out of the rendered tree and requires them to
// name the same tier. The badge is printed by
// `AclDeviceContext.resolveFormFactor`, so a cell re-pinned to a new width — or
// a new cell added later — cannot contradict the resolver without failing here.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/common/showcase_cell.dart';
import 'package:core_flutter_acl_responsive/common/showcase_section.dart';
import 'package:core_flutter_acl_responsive/groups/form_factor_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  void Function(FlutterErrorDetails)? previousOnError;

  /// Hands error reporting back to `flutter_test` before any `expect` runs.
  ///
  /// [pumpGroup] silences `FlutterError.onError` because the cells pin previews
  /// to fixed widths that overflow the narrower preview column — a harness
  /// artifact, not a defect. That silencing also disables the framework's own
  /// failure reporting, which turns a plain mismatch into an opaque
  /// `_pendingExceptionDetails != null` binding assertion. Same guard as
  /// `family_swap_test.dart`.
  void restoreErrorReporting() => FlutterError.onError = previousOnError;

  /// Render the whole form-factor group wide enough that every cell is laid out.
  Future<void> pumpGroup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(restoreErrorReporting);

    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: formFactorGroup)),
    );
    await tester.pump();
  }

  /// Every rendered cell as `(title, badge)`, read back out of the widget tree.
  ///
  /// The badge is matched by prefix rather than by exact text so the snippet
  /// code block — also a `Text`, also inside the cell — cannot be mistaken for
  /// it.
  List<(String, String)> titledBadges(WidgetTester tester) {
    final cells = find.byType(ShowcaseCell);
    final count = cells.evaluate().length;
    final result = <(String, String)>[];
    for (var i = 0; i < count; i++) {
      final cell = cells.at(i);
      final title = tester.widget<ShowcaseCell>(cell).title;
      final badge = find.descendant(
        of: cell,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text && (w.data?.startsWith('resolveFormFactor(') ?? false),
          description: 'a resolveFormFactor badge',
        ),
      );
      expect(badge.evaluate(), hasLength(1),
          reason: 'cell "$title" must paint exactly one resolveFormFactor '
              'badge — the readout is what makes the tier observable');
      result.add((title, tester.widget<Text>(badge).data!));
    }
    return result;
  }

  /// The tier word a badge ends with, e.g. `desktop`.
  String tierOf(String badge) => badge.split('→').last.trim();

  /// The tier word a cell title starts with, lowercased, e.g. `desktop` from
  /// `Desktop (1200px) — default row`.
  String titleTier(String title) => title.split(' ').first.toLowerCase();

  testWidgets('a desktop-tier cell is pinned at a width that resolves desktop',
      (tester) async {
    await pumpGroup(tester);
    restoreErrorReporting();
    expect(find.text('resolveFormFactor(1200.0) → desktop'), findsOneWidget,
        reason: 'desktop starts at 1024, so demonstrating the tier needs a '
            'width at or above it');
  });

  testWidgets('a tablet-tier cell is pinned at a width that resolves tablet',
      (tester) async {
    await pumpGroup(tester);
    restoreErrorReporting();
    expect(find.text('resolveFormFactor(900.0) → tablet'), findsOneWidget,
        reason: '900 sits between the 600 and 1024 boundaries');
  });

  testWidgets('a phone-tier cell is pinned at a width that resolves phone',
      (tester) async {
    await pumpGroup(tester);
    restoreErrorReporting();
    expect(find.text('resolveFormFactor(400.0) → phone'), findsOneWidget,
        reason: 'below 600 the tier is phone — and 400 is also the only cell '
            'below the 600px addVariant threshold, so it is the stacked one');
  });

  testWidgets('every cell title names the tier its own width resolves to',
      (tester) async {
    await pumpGroup(tester);
    final observed = titledBadges(tester);
    restoreErrorReporting();

    for (final (title, badge) in observed) {
      expect(titleTier(title), tierOf(badge),
          reason: 'cell "$title" renders "$badge" — a title that contradicts '
              'the resolver teaches the mapping backwards');
    }
  });

  testWidgets('the group demonstrates all three tiers', (tester) async {
    await pumpGroup(tester);
    final tiers = titledBadges(tester).map((e) => tierOf(e.$2)).toSet();
    restoreErrorReporting();

    expect(tiers, containsAll(<String>['phone', 'tablet', 'desktop']),
        reason: 'the group exists to show the phone/tablet/desktop mapping, so '
            'each tier needs a cell that actually resolves to it');
  });
}
