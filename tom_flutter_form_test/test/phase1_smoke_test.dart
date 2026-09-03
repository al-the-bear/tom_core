/// Smoke tests for the Phase 1 / Phase 2 spec-aligned demos (A through H) —
/// opens each demo through normal navigation and verifies it renders
/// without throwing.
library;

import 'package:flutter/widgets.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
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

  Future<void> openDemo(WidgetTester tester, String tile) async {
    // A wide logical viewport keeps the two-column layout active and
    // removes the need to scroll nested panels. Demos G and H spread a
    // multi-column ProjectBriefForm across the form pane, so the viewport
    // needs to leave enough width for each dropdown to render without
    // overflowing — 2400 comfortably fits the full-bordered band too.
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text(tile),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('Demo A opens and renders the form', (tester) async {
    await openDemo(tester, 'Demo A: Lifecycle & Validation');
    expect(find.text('Demo A — Lifecycle & Validation'), findsOneWidget);
    // Field-state table exposes the username row.
    expect(find.text('username'), findsWidgets);
  });

  testWidgets('Demo B opens with nested billing/shipping', (tester) async {
    await openDemo(tester, 'Demo B: Authorization & Events');
    expect(find.text('Demo B — Authorization & Events'), findsOneWidget);
    expect(find.text('Billing address'), findsOneWidget);
    expect(find.text('Shipping address'), findsOneWidget);
  });

  testWidgets('Demo C opens and shows the theming panel', (tester) async {
    await openDemo(tester, 'Demo C: Nested Forms & Theming');
    expect(find.text('Demo C — Nested Forms & Theming'), findsOneWidget);
    expect(find.text('Theming controls'), findsOneWidget);
    expect(find.text('Form inspection'), findsOneWidget);
    // Resources should supply descriptions on at least one field — this
    // check guards against future accidental removal of demoC resource
    // entries that would make the theming toggles a no-op.
    expect(
      find.text('Primary contact for order updates.'),
      findsOneWidget,
      reason: 'demoC.customer.email.description must resolve to text.',
    );
  });

  testWidgets('Demo D opens with the form + widget gallery', (tester) async {
    await openDemo(tester, 'Demo D: Hide on Authorization');
    expect(find.text('Demo D — Hide on Authorization'), findsOneWidget);
    expect(find.text('Form A — hide on auth, default gaps'), findsOneWidget);
    expect(
      find.text(
        'Form B — hide on auth, non-default gaps (32 / 48 / 24 / 40 px)',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Non-form Tom widgets — same hide-unauthorized rule'),
      findsOneWidget,
    );
    expect(find.text('Form field auth'), findsOneWidget);
    expect(find.text('Widget gallery auth'), findsOneWidget);
  });

  testWidgets('Demo E opens with the selection-variants scaffold', (
    tester,
  ) async {
    await openDemo(tester, 'Demo E: Selection Variants');
    expect(find.text('Demo E — Selection Variants'), findsOneWidget);
    // Each variant card has a spec-class title with a subtitle that names
    // its binding shape. Verify both the multi-select and single-select
    // flavours render + the live bindings panel is active.
    expect(
      find.text('TomFormStringFilterChips — multi-select'),
      findsOneWidget,
    );
    expect(
      find.text('TomFormStringChoiceChips — single-select'),
      findsOneWidget,
    );
    expect(find.text('Live bindings'), findsOneWidget);
    // The shared source supplies six labels to every variant section.
    expect(find.text('Technology'), findsWidgets);
  });

  testWidgets('Demo F opens with the boolean-variants scaffold', (
    tester,
  ) async {
    await openDemo(tester, 'Demo F: Boolean Variants');
    expect(find.text('Demo F — Boolean Variants'), findsOneWidget);
    expect(find.text('Independent (one field per rendering)'), findsOneWidget);
    expect(find.text('Lock-step trio — flip any, flip all'), findsOneWidget);
  });

  testWidgets('Demo G opens with the breakpoint splitter', (tester) async {
    await openDemo(tester, 'Demo G: Complex Breakpoint Scenarios');
    expect(
      find.text('Demo G — Complex Breakpoint & Theming Scenarios'),
      findsOneWidget,
    );
    // ProjectBrief sections visible in the complex form pane.
    expect(find.text('Identity'), findsWidgets);
    expect(find.text('Classification'), findsWidgets);
    expect(find.text('People'), findsWidgets);
  });

  testWidgets('Demo H opens with the complex-auth controls', (tester) async {
    await openDemo(tester, 'Demo H: Complex Authorization Scenarios');
    expect(
      find.text('Demo H — Complex Authorization + Responsive Layout'),
      findsOneWidget,
    );
    expect(find.text('Authorization controls'), findsOneWidget);
    expect(find.text('Form-level ceiling'), findsOneWidget);
    expect(find.text('Field state (live)'), findsOneWidget);
  });
}
