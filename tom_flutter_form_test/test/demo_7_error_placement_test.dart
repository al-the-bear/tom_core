/// Interaction tests for Demo 7 — Error Placement (legacy demo).
///
/// Demo 7 hosts one [SegmentedButton<ErrorPlacement>] (below / above /
/// both / replaceDescription) and two [OutlinedButton.icon]s (Trigger
/// errors / Clear errors). Trigger errors mutates the bound state with
/// invalid values so the chosen placement renders visible error text.
///
/// We assert that:
///   * baseline — segmented control + buttons render, no error text
///   * Trigger errors → required + invalid-URL messages surface
///   * Clear errors → restores valid sample, error text disappears
///   * each placement segment becomes the active selection when tapped
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/application_state.dart';

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

  // Trigger errors mutates the shared `demoState.companyProfile`. Reseed
  // before each test so prior runs don't bleed in.
  setUp(() {
    demoState.companyProfile.name | 'Acme Corporation';
    demoState.companyProfile.industry | 'tech';
    demoState.companyProfile.taxId | 'US-12345-ABC';
    demoState.companyProfile.website | 'https://acme.example.com';
  });

  Future<void> openDemo7(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo 7: Error Placement'), 200);
    await tester.tap(find.text('Demo 7: Error Placement'));
    await tester.pumpAndSettle();
  }

  Future<void> tapOutlined(WidgetTester tester, String label) async {
    final btn = find.widgetWithText(OutlinedButton, label);
    expect(btn, findsAtLeastNWidgets(1),
        reason: 'OutlinedButton "$label" must exist');
    await tester.ensureVisible(btn.first);
    await tester.pumpAndSettle();
    await tester.tap(btn.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapPlacement(
    WidgetTester tester,
    String label,
  ) async {
    final segmented = find.byType(SegmentedButton<ErrorPlacement>);
    expect(segmented, findsOneWidget);
    final seg = find.descendant(of: segmented, matching: find.text(label));
    expect(seg, findsOneWidget,
        reason: 'segment "$label" must exist on the placement control');
    await tester.ensureVisible(seg);
    await tester.pumpAndSettle();
    await tester.tap(seg);
    await tester.pumpAndSettle();
  }

  Set<ErrorPlacement> selected(WidgetTester tester) {
    final w = find.byType(SegmentedButton<ErrorPlacement>).evaluate().first
        .widget as SegmentedButton<ErrorPlacement>;
    return w.selected;
  }

  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  testWidgets('baseline — controls render and no error text is visible',
      (tester) async {
    await openDemo7(tester);
    expect(find.byType(SegmentedButton<ErrorPlacement>), findsOneWidget);
    expect(selected(tester), {ErrorPlacement.below});
    expect(find.widgetWithText(OutlinedButton, 'Trigger errors'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Clear errors'),
        findsOneWidget);
    // The bound state is valid → no error text on screen.
    expect(find.text('Company name is required.'), findsNothing);
    expect(find.textContaining('Please enter a valid URL'), findsNothing);
    // Form fields render.
    expect(fieldByTomId('name'), findsOneWidget);
    expect(fieldByTomId('taxId'), findsOneWidget);
    expect(fieldByTomId('website'), findsOneWidget);
  });

  testWidgets('Trigger errors surfaces required + invalid-URL messages',
      (tester) async {
    await openDemo7(tester);
    await tapOutlined(tester, 'Trigger errors');
    // Empty name → required. The resolved message uses the field's resource
    // path (`companyBasicInfo.name.error.required`).
    expect(find.text('Company name is required.'), findsAtLeastNWidgets(1),
        reason: 'empty name must surface the required error');
    // Bad URL — field-scoped resource resolves to the long form.
    expect(
      find.text(
          'Please enter a valid URL starting with http:// or https://.'),
      findsAtLeastNWidgets(1),
      reason: 'non-URL value must surface the field-scoped invalidUrl error',
    );
  });

  testWidgets('Clear errors restores the sample and removes error text',
      (tester) async {
    await openDemo7(tester);
    await tapOutlined(tester, 'Trigger errors');
    expect(find.text('Company name is required.'), findsAtLeastNWidgets(1));
    await tapOutlined(tester, 'Clear errors');
    expect(find.text('Company name is required.'), findsNothing,
        reason: 'Clear errors must remove the required error');
    expect(find.textContaining('Please enter a valid URL'), findsNothing,
        reason: 'Clear errors must remove the invalidUrl error');
  });

  testWidgets('picking each placement segment updates the selection',
      (tester) async {
    await openDemo7(tester);
    await tapPlacement(tester, 'above');
    expect(selected(tester), {ErrorPlacement.above});
    await tapPlacement(tester, 'both');
    expect(selected(tester), {ErrorPlacement.both});
    await tapPlacement(tester, 'replaceDescription');
    expect(selected(tester), {ErrorPlacement.replaceDescription});
    await tapPlacement(tester, 'below');
    expect(selected(tester), {ErrorPlacement.below});
  });

  testWidgets(
      'placement = both renders error text twice (above AND below input)',
      (tester) async {
    await openDemo7(tester);
    await tapPlacement(tester, 'both');
    await tapOutlined(tester, 'Trigger errors');
    // The website field's invalidUrl message must appear at least twice
    // (once above, once below). Other fields don't share this exact text,
    // so we can be specific.
    expect(
      find.text(
          'Please enter a valid URL starting with http:// or https://.'),
      findsNWidgets(2),
      reason: 'placement=both must mirror the error text above and below',
    );
  });
}
