/// Smoke tests for Phase 6 — Demo Q (auth / empty / overlay) and
/// Demo R (tree / radio / infinite scroll).
///
/// Mirrors `phase5c_smoke_test.dart`: opens each demo via the demo
/// list, asserts the headline + key anchor widgets render without
/// throwing, and exercises a few state transitions specific to the
/// Phase 6 widget kit.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

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

  Future<void> openDemo(WidgetTester tester, String tile,
      {Size size = const Size(2400, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200);
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tile), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------
  // Demo Q — Auth / Empty / Overlay
  // -------------------------------------------------------------------

  testWidgets('Demo Q opens and renders the three Phase 6 anchor cards',
      (tester) async {
    await openDemo(tester, 'Demo Q: Auth / Empty / Overlay (Phase 6)');
    expect(
      find.text('Demo Q — Auth / Empty / Overlay (Phase 6)'),
      findsOneWidget,
    );
    // Stage cards
    expect(find.text('TomAuthGuard — profile panel'), findsOneWidget);
    expect(
      find.text('TomEmptyState + TomLoadingOverlay'),
      findsOneWidget,
    );
    // Profile-card content (auth = full default → child is rendered)
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    // Items list seeded with 3 rows
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    // Right-pane control panel anchors
    expect(find.text('Phase 6 controls'), findsOneWidget);
    expect(find.text('Profile auth (TomAuthGuard)'), findsOneWidget);
    expect(find.text('Items list (TomEmptyState)'), findsOneWidget);
    expect(find.text('Loading overlay (TomLoadingOverlay)'), findsOneWidget);
  });

  testWidgets('Demo Q empty-state slot renders when items are cleared',
      (tester) async {
    await openDemo(tester, 'Demo Q: Auth / Empty / Overlay (Phase 6)');
    expect(find.text('Alpha'), findsOneWidget);
    // Tap Clear in the right-hand control pane.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('No items'), findsOneWidget);
    expect(
      find.text('Use Seed to insert sample rows, or +1 to '
          'append a single row.'),
      findsOneWidget,
    );
  });

  testWidgets('Demo Q profile auth = none hides the guarded subtree',
      (tester) async {
    await openDemo(tester, 'Demo Q: Auth / Empty / Overlay (Phase 6)');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    // Open the auth dropdown and pick "none".
    await tester.tap(find.byType(DropdownButton<TomAuthState>).first);
    await tester.pumpAndSettle();
    // Use the visible menu item — DropdownMenuItem renders 'none' as
    // a Text inside the menu overlay.
    await tester.tap(find.text('none').last);
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(find.text('Profile hidden — auth = none'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // Demo R — Tree / Radio / Infinite scroll
  // -------------------------------------------------------------------

  testWidgets('Demo R opens and renders all Phase 6 anchor cards',
      (tester) async {
    await openDemo(
        tester, 'Demo R: Tree / Radio / Infinite scroll (Phase 6)');
    // Settle once more so the post-frame first-page fetch completes.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text('Demo R — Tree / Radio / Infinite scroll (Phase 6)'),
      findsOneWidget,
    );
    // Three card titles.
    expect(find.text('TomAuthTreeView'), findsOneWidget);
    expect(find.text('TomRadioGroup'), findsOneWidget);
    expect(find.text('TomInfiniteScroll + TomErrorBoundary'),
        findsOneWidget);
    // Tree visible nodes — `admin` is seeded to `none` → hidden.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
    // Radio items.
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Comfortable'), findsOneWidget);
    expect(find.text('Spacious'), findsOneWidget);
    // First page of infinite-scroll items rendered (page size = 25 →
    // at least row 00000 visible above the fold).
    expect(find.text('Row #00000'), findsOneWidget);
    // Right-pane control headings.
    expect(find.text('Radio group auth'), findsOneWidget);
    expect(find.text('Infinite scroll'), findsOneWidget);
    expect(find.text('Tree-node auth'), findsOneWidget);
  });

  testWidgets('Demo R synthetic fetch failure renders error slot',
      (tester) async {
    await openDemo(
        tester, 'Demo R: Tree / Radio / Infinite scroll (Phase 6)');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Toggle "Fail next page fetch" + Refresh to force the next fetch
    // (which is the *first* page after refresh) to throw.
    await tester.tap(find.text('Fail next page fetch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // The default error slot surfaces a `Failed to load:` line and a
    // Retry button.
    expect(find.textContaining('Failed to load:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
