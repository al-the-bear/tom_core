/// T12 — Theme / style application matrix.
///
/// `TomFormStyle` ships three built-in presets:
///   * `material3` — no fieldBorder, label above
///   * `compact`   — labelPlacement: floating, reduced gaps, no border
///   * `bordered`  — labelPlacement: floating + OutlineInputBorder
///
/// `TomFormStyleScope` resolves the active style for any field below
/// it; nested scopes override outer ones; `styleBpOverrides` swaps
/// the resolved style at width thresholds without a setState.
///
/// `demo_9_preset_showcase_test.dart` covers the high-level matrix
/// (3×2 grid renders, withTheme switch, segment selection); this file
/// pins the *application* matrix end-to-end on a minimal harness:
///   * each preset rebuilds the underlying TextField with the
///     expected InputDecoration.border
///   * switching the scope's style at runtime propagates immediately
///   * a nested TomFormStyleScope wins over its parent
///   * `styleBpOverrides` flips the resolved style across the
///     declared breakpoint as the viewport resizes
///
/// We probe the resolved [TextField.decoration] (specifically the
/// `border` property) — bordered carries `OutlineInputBorder`,
/// material3/compact don't. This is the smallest deterministic,
/// non-pixel-comparing probe for "the style preset took effect".
///
/// We use [CompanyBasicInfoForm] from the demo as the harness because
/// it is reflection-registered (private types in this test file aren't
/// reachable by the reflector and would throw).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/forms/company_forms.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  /// Locate the (single) TextField beneath the `name` field adapter.
  Finder nameTextField() {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'name',
      ),
      matching: find.byType(TextField),
    );
  }

  /// Pump a one-field form (CompanyBasicInfoForm.name) inside a
  /// [TomFormStyleScope] of [style], at the given viewport size.
  Future<TextField> pumpProbe(
    WidgetTester tester, {
    required TomFormStyle style,
    Size size = const Size(1200, 800),
    String scopeId = 'styleProbe',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final form = TomScope.withScope(scopeId, () => CompanyBasicInfoForm());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomFormStyleScope(
            style: style,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: form.name.widget,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tfFinder = nameTextField();
    expect(
      tfFinder,
      findsOneWidget,
      reason: 'CompanyBasicInfoForm.name must render a single TextField',
    );
    return tester.widget<TextField>(tfFinder);
  }

  // -------------------------------------------------------------------
  // Per-preset application
  // -------------------------------------------------------------------

  testWidgets('material3 preset — TextField decoration carries no '
      'OutlineInputBorder', (tester) async {
    final tf = await pumpProbe(
      tester,
      style: TomFormStyle.material3,
      scopeId: 'styleProbeMaterial',
    );
    expect(
      tf.decoration?.border,
      isNot(isA<OutlineInputBorder>()),
      reason: 'material3 preset must not paint an outline border',
    );
  });

  testWidgets('compact preset — TextField decoration carries no '
      'OutlineInputBorder', (tester) async {
    final tf = await pumpProbe(
      tester,
      style: TomFormStyle.compact,
      scopeId: 'styleProbeCompact',
    );
    expect(
      tf.decoration?.border,
      isNot(isA<OutlineInputBorder>()),
      reason: 'compact preset must not paint an outline border',
    );
  });

  testWidgets('bordered preset — TextField decoration carries an '
      'OutlineInputBorder', (tester) async {
    final tf = await pumpProbe(
      tester,
      style: TomFormStyle.bordered,
      scopeId: 'styleProbeBordered',
    );
    expect(
      tf.decoration?.border,
      isA<OutlineInputBorder>(),
      reason: 'bordered preset must paint an outlined input border',
    );
  });

  // -------------------------------------------------------------------
  // Runtime style swap
  // -------------------------------------------------------------------

  testWidgets('runtime swap — flipping the scope style from material3 to '
      'bordered repaints the TextField with an OutlineInputBorder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final form = TomScope.withScope(
      'styleProbeSwap',
      () => CompanyBasicInfoForm(),
    );
    final styleNotifier = ValueNotifier<TomFormStyle>(TomFormStyle.material3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<TomFormStyle>(
            valueListenable: styleNotifier,
            builder: (context, style, _) => TomFormStyleScope(
              style: style,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: form.name.widget,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tfFinder = nameTextField();
    // Initial: material3 → no outline border.
    expect(
      tester.widget<TextField>(tfFinder).decoration?.border,
      isNot(isA<OutlineInputBorder>()),
      reason: 'starts in material3 — no outline border',
    );
    // Swap to bordered.
    styleNotifier.value = TomFormStyle.bordered;
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(tfFinder).decoration?.border,
      isA<OutlineInputBorder>(),
      reason: 'swapping to bordered must repaint with an outline border',
    );
  });

  // -------------------------------------------------------------------
  // Nested scopes
  // -------------------------------------------------------------------

  testWidgets('nested TomFormStyleScope — inner bordered overrides outer '
      'material3 for fields beneath it', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final form = TomScope.withScope(
      'styleProbeNested',
      () => CompanyBasicInfoForm(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomFormStyleScope(
            style: TomFormStyle.material3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TomFormStyleScope(
                style: TomFormStyle.bordered,
                child: form.name.widget,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tf = tester.widget<TextField>(nameTextField());
    expect(
      tf.decoration?.border,
      isA<OutlineInputBorder>(),
      reason: 'inner bordered scope must win over outer material3',
    );
  });

  // -------------------------------------------------------------------
  // styleBpOverrides — width-driven preset swap
  // -------------------------------------------------------------------

  testWidgets('styleBpOverrides — base material3 + bordered override at '
      '1000 px swaps the resolved preset across the breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final form = TomScope.withScope(
      'styleProbeBp',
      () => CompanyBasicInfoForm(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomFormStyleScope(
            style: TomFormStyle.material3,
            styleBpOverrides: [(1000.0, TomFormStyle.bordered)],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: form.name.widget,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tfFinder = nameTextField();
    // Below 1000 px the base material3 style applies → no outline.
    expect(
      tester.widget<TextField>(tfFinder).decoration?.border,
      isNot(isA<OutlineInputBorder>()),
      reason: 'narrow viewport (<1000) must resolve to base material3',
    );
    // Resize past the breakpoint.
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(tfFinder).decoration?.border,
      isA<OutlineInputBorder>(),
      reason: 'wide viewport (>=1000) must resolve to bordered override',
    );
  });
}
