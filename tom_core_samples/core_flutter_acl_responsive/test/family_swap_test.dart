// Family-swap tests: two forms (Material + Cupertino) bound to one entity, the
// active one chosen by the 700px breakpoint, with shared state that survives.
//
// [FamilySwapDemo] pre-builds one form per [FormFieldFamily], binds both to the
// same [ResponsiveProfile], and renders whichever matches the live width. The
// page-root [TomFormStyleScope] flips the form style at the same threshold. The
// header badge and the section header read back the active family; the shared
// state panel reads the Material form's observables — the same TomObjects the
// Cupertino form binds — so edits round-trip across the swap. Mirrors the
// verified `tom_flutter_form_test` `demo_p_family_swap_breakpoint_test`.

import 'package:core_flutter_acl_responsive/common/showcase_section.dart';
import 'package:core_flutter_acl_responsive/groups/family_swap_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'overflow_tolerance.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  /// Pump the demo inside a fixed-width SizedBox so its internal LayoutBuilder
  /// sees exactly [width] and picks the matching family.
  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Auxiliary field chrome overflows at the extreme widths; nothing else is
    // tolerated, and reporting stays live so the style assertions below — which
    // exist precisely to fail when the pairing inverts — still report legibly.
    tolerateOverflowErrors();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(width: width, child: FamilySwapDemo()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The form style the page-root [TomFormStyleScope] resolved at the pumped
  /// width, read from a context *below* the scope.
  ///
  /// `TomCard` is rendered by the form column and the state panel, both of which
  /// sit inside the scope, so its element is a valid descendant context.
  /// [TomCupertinoFormStyle.withTheme] re-wraps its result to preserve the
  /// subtype precisely so `is TomCupertinoFormStyle` stays answerable here.
  TomFormStyle resolvedStyle(WidgetTester tester) =>
      TomFormStyleScope.of(tester.element(find.byType(TomCard).first));

  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// Read the value cell from the shared-state panel: each row renders the raw
  /// key name beside its value, and the key only appears in that panel (fields
  /// use overridden labels), so the name finder is unique to the panel.
  String stateValue(WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(nameFinder, findsOneWidget);
    final row = find.ancestor(of: nameFinder, matching: find.byType(Row));
    final texts = find
        .descendant(of: row.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(texts.length, greaterThanOrEqualTo(2));
    return texts[1];
  }

  testWidgets('wide viewport (800px) renders the Material family and seeds', (
    tester,
  ) async {
    await pumpAtWidth(tester, 800);
    expect(
      find.text('Active family: material'),
      findsOneWidget,
      reason: 'wide branch must render the Material family form',
    );
    expect(find.textContaining('wide → Material'), findsOneWidget);
    for (final id in [
      'fullName',
      'quantity',
      'ratio',
      'notifyMe',
      'eventDate',
    ]) {
      expect(
        adapterByTomId(id),
        findsOneWidget,
        reason: 'field "$id" must render in the active family',
      );
    }
    expect(stateValue(tester, 'quantity'), '3');
    expect(stateValue(tester, 'ratio'), '0.75');
    expect(stateValue(tester, 'notifyMe'), 'true');
    expect(stateValue(tester, 'eventDate'), '2026-06-15');
  });

  testWidgets('narrow viewport (600px) flips the active family to Cupertino', (
    tester,
  ) async {
    await pumpAtWidth(tester, 600);
    expect(
      find.text('Active family: cupertino'),
      findsOneWidget,
      reason: 'narrow branch must render the Cupertino family form',
    );
    expect(find.textContaining('narrow → Cupertino'), findsOneWidget);
  });

  // The style flip is the half of the mechanism the family assertions above
  // cannot see: the demo rendered the right *family* on each side of the
  // breakpoint while dressing it in the other side's *style*, and every
  // family-level assertion still passed. These pin the resolved style itself.
  //
  // The direction is the whole point. `styleBpOverrides` entries are
  // `(minWidth, style)` resolved as "highest minWidth <= width wins", so an
  // entry keyed at 700 applies at and above 700 — the Material side. The
  // Cupertino style therefore has to be the scope's *base*, which covers
  // everything below the lowest override.

  testWidgets('narrow viewport (600px) resolves the Cupertino form style', (
    tester,
  ) async {
    await pumpAtWidth(tester, 600);
    final style = resolvedStyle(tester);
    expect(
      style,
      isA<TomCupertinoFormStyle>(),
      reason:
          'the Cupertino family renders below 700, so the Cupertino '
          'style must resolve there — not the Material3 default',
    );
    expect(
      style.defaults.borderRadius,
      6.0,
      reason:
          'Cupertino preset radius (6.0); Material3 uses 8.0, so this '
          'pins the actual preset rather than merely the subtype',
    );
  });

  testWidgets('wide viewport (800px) resolves the Material3 form style', (
    tester,
  ) async {
    await pumpAtWidth(tester, 800);
    final style = resolvedStyle(tester);
    expect(
      style,
      isNot(isA<TomCupertinoFormStyle>()),
      reason:
          'the Material family renders at/above 700, so Cupertino chrome '
          'must not be applied there',
    );
  });

  testWidgets('the style flips on the same side of 700 as the family', (
    tester,
  ) async {
    // Exactly at the breakpoint both rules take their wide branch: the family
    // selector uses `width >= 700` and the override matches on `minWidth <=
    // width`. Pinning the boundary is what stops the two drifting apart by one
    // pixel later.
    await pumpAtWidth(tester, familySwapBreakpoint);
    final style = resolvedStyle(tester);
    expect(find.text('Active family: material'), findsOneWidget);
    expect(
      style,
      isNot(isA<TomCupertinoFormStyle>()),
      reason:
          'at exactly 700 the family is Material, so the style must be '
          'Material3 too',
    );
  });

  testWidgets('editing fullName in the active form reaches the shared panel', (
    tester,
  ) async {
    await pumpAtWidth(tester, 800);
    final input = find.descendant(
      of: adapterByTomId('fullName'),
      matching: find.byType(TextField),
    );
    expect(input, findsOneWidget);
    await tester.enterText(input, 'Grace Hopper');
    await tester.pumpAndSettle();
    expect(
      stateValue(tester, 'fullName'),
      'Grace Hopper',
      reason:
          'edit in the active Material family must reach the shared '
          'TomString → state panel',
    );
  });

  testWidgets('state survives the family swap from wide to narrow', (
    tester,
  ) async {
    await pumpAtWidth(tester, 800);
    final input = find.descendant(
      of: adapterByTomId('fullName'),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'Linus Torvalds');
    await tester.pumpAndSettle();
    expect(stateValue(tester, 'fullName'), 'Linus Torvalds');

    // Flip to narrow: the Cupertino form takes over but the shared entity
    // preserves the value.
    tester.view.physicalSize = const Size(600, 3000);
    await tester.pumpAndSettle();
    expect(find.text('Active family: cupertino'), findsOneWidget);
    expect(
      stateValue(tester, 'fullName'),
      'Linus Torvalds',
      reason: 'wide-side edit must survive into the Cupertino form',
    );
  });

  // The tests above pump the demo alone at an exact width. In the showcase it
  // sits in a cell beside its snippet, whose long lines claim most of a
  // side-by-side row; unless the cell grants the demo its 700px, a reader can
  // never see the swap's wide side, however wide the screen.
  group('in the showcase screen', () {
    Future<void> pumpScreen(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tolerateOverflowErrors();
      await tester.pumpWidget(
        MaterialApp(home: GroupScreen(group: familySwapGroup)),
      );
      await tester.pump();
    }

    testWidgets('FS-SCREEN-1: a desktop screen shows the Material side', (
      tester,
    ) async {
      await pumpScreen(tester, 1200);
      expect(find.text('Active family: material'), findsOneWidget);
    });

    testWidgets('FS-SCREEN-2: a phone screen shows the Cupertino side', (
      tester,
    ) async {
      await pumpScreen(tester, 400);
      expect(find.text('Active family: cupertino'), findsOneWidget);
    });
  });
}
