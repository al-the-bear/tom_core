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
    await tester.scrollUntilVisible(find.text(tile), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tile), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  /// Some Phase 6 widgets (e.g. `TomErrorBoundary`) mutate the global
  /// `ErrorWidget.builder` while mounted. The test binding's
  /// `_verifyErrorWidgetBuilderUnset` asserts that builder is back to
  /// the default at the end of each test, so call this before the test
  /// body returns to tear down the widget tree and restore the chain.
  Future<void> unmountDemo(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
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
    // Items list seeded with 3 rows (productName values shown inside the
    // bound TomFormStringInput widgets).
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    // Right-pane control panel anchors
    expect(find.text('Phase 6 controls'), findsOneWidget);
    expect(find.text('Profile auth (TomAuthGuard)'), findsOneWidget);
    expect(find.text('Items list (TomEmptyState)'), findsOneWidget);
    expect(find.text('Loading overlay (TomLoadingOverlay)'), findsOneWidget);
    // New: Save button now drives an actual SlowValidator instead of a
    // fake Future.delayed.
    expect(find.text('Save (awaits SlowValidator)'), findsOneWidget);
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

  testWidgets(
      'Demo Q save button drives TomLoadingOverlay via SlowValidator',
      (tester) async {
    await openDemo(tester, 'Demo Q: Auth / Empty / Overlay (Phase 6)');
    // Baseline: no overlay before pressing save.
    expect(find.text('Saving — SlowValidator pending…'), findsNothing);

    // Fire-and-forget the save. We pump a short frame-interval so the
    // setState flipping isSaving=true runs, but do NOT pumpAndSettle
    // (which would await the 800 ms SlowValidator and clear the overlay).
    await tester.tap(find.text('Save (awaits SlowValidator)'));
    await tester.pump(const Duration(milliseconds: 50));

    // Overlay visible + button swapped to the saving label.
    expect(find.text('Saving — SlowValidator pending…'), findsOneWidget);
    expect(find.text('Saving…'), findsOneWidget);

    // Let the SlowValidator resolve; overlay tears down.
    await tester.pumpAndSettle();
    expect(find.text('Saving — SlowValidator pending…'), findsNothing);
    expect(find.text('Save (awaits SlowValidator)'), findsOneWidget);
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
    // New per-tile TomErrorBoundary toggle.
    expect(find.text('Throw in row tile'), findsOneWidget);
    await unmountDemo(tester);
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
    await unmountDemo(tester);
  });

  testWidgets(
      'Demo R synthetic tile throw is contained to the failing row '
      'and Retry restores it',
      (tester) async {
    // Regression for round-4 feedback `t`: the row-level error
    // boundary used to collapse the *entire* list to the default
    // 'Something went wrong' card because the synthetic throw lived
    // in the itemBuilder closure (outside the per-row subtree) and
    // only a single outer boundary existed. After the fix each row
    // has its own boundary with a compact fallback, and sibling rows
    // must keep rendering while row 3 shows a `Row #3 failed to
    // render` tile.
    await openDemo(
        tester, 'Demo R: Tree / Radio / Infinite scroll (Phase 6)');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    // Baseline: first rows are visible, no fallback tile.
    expect(find.text('Row #00000'), findsOneWidget);
    expect(find.text('Row #00001'), findsOneWidget);
    expect(find.text('Row #00002'), findsOneWidget);
    expect(find.text('Row #00003'), findsOneWidget);
    expect(find.textContaining('failed to render'), findsNothing);
    // Default boundary fallback ('Something went wrong') must NOT
    // appear — the per-row boundary overrides it with the compact
    // `_DemoRRowErrorTile`.
    expect(find.text('Something went wrong'), findsNothing);

    // Flip the per-tile throw toggle. The tile builder at row
    // `DemoRController.throwRowIndex` (= 3) throws; `ErrorWidget.builder`
    // routes the failure into the per-row `TomErrorBoundary`, which
    // schedules a post-frame setState to paint its fallback.
    await tester.tap(find.text('Throw in row tile'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    // Synthetic build-time throws arrive through `FlutterError.onError`
    // as "unexpected" framework exceptions in the test harness even
    // though `TomErrorBoundary` handles them visually. Drain those so
    // the harness does not fail the test on their account.
    tester.takeException();

    // Row 3's fallback tile is visible.
    expect(find.text('Row #3 failed to render'), findsOneWidget);
    // Sibling rows still render — this is the core regression.
    expect(find.text('Row #00000'), findsOneWidget);
    expect(find.text('Row #00001'), findsOneWidget);
    expect(find.text('Row #00002'), findsOneWidget);
    expect(find.text('Row #00004'), findsOneWidget);
    // The default full-list fallback must NOT appear — containment is
    // per-row.
    expect(find.text('Something went wrong'), findsNothing);

    // Turn the throw off, then tap the row's Retry — the per-row
    // boundary clears and the original tile re-renders.
    await tester.tap(find.text('Throw in row tile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining('failed to render'), findsNothing);
    expect(find.text('Row #00003'), findsOneWidget);
    await unmountDemo(tester);
  });
}
