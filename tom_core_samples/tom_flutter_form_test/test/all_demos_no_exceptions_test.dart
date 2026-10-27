/// Round-6 (l): comprehensive component/demo exception coverage.
///
/// For every demo tile listed in `lib/main.dart`, this suite:
///   1. installs a capturing `FlutterError.onError`,
///   2. boots [FormDemoApp] on a generous viewport,
///   3. scrolls the tile into view, taps it, and lets the demo settle,
///   4. fails the test if **any** Flutter framework error fired during
///      that sequence.
///
/// Each demo gets its own `testWidgets` entry so a regression localises
/// to a single tile rather than blowing up the whole suite. Tests are
/// kept self-contained (no shared mutable state, no Navigator.pop
/// gymnastics) — the framework rebuilds the app fresh per test, which
/// is the cleanest way to guarantee one-demo-at-a-time error capture.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

/// All demo tile titles in the order they appear on the demo list
/// screen (`lib/main.dart`). Update this list when tiles are added or
/// renamed.
const List<String> kAllDemoTiles = [
  // Phase 1 — spec-aligned demos
  'Demo A: Lifecycle & Validation',
  'Demo B: Authorization & Events',
  'Demo C: Nested Forms & Theming',
  'Demo D: Hide on Authorization',
  'Demo E: Selection Variants',
  'Demo F: Boolean Variants',
  'Demo G: Complex Breakpoint Scenarios',
  'Demo H: Complex Authorization Scenarios',
  // Phase 2a — composite UX
  'Demo H-A: Master-Detail Customer Editor',
  'Demo H-B: Expandable Rows (Order Items)',
  'Demo H-C: Editable Order-Items Table',
  // Phase 3-6 — additional spec demos
  'Demo I: Numeric Forms',
  'Demo J: Date/Time/Duration Forms',
  'Demo K: Enum, Object & Lookup',
  'Demo L: Files & Nullable Variants',
  'Demo M: Material vs Cupertino (Phase 5a)',
  'Demo N: Cupertino numeric + date/time (Phase 5b)',
  'Demo O: Cupertino search / lookup / file (Phase 5c)',
  'Demo P: TomFormFieldFamily swap by breakpoint (Phase 5c)',
  'Demo Q: Auth / Empty / Overlay (Phase 6)',
  'Demo R: Tree / Radio / Infinite scroll (Phase 6)',
  // Reference / supporting numbered demos
  'Demo 1: Basic Form',
  'Demo 2: Nested Forms',
  'Demo 3: Authorization',
  'Demo 4: Validation',
  'Demo 5: Settings Form',
  'Demo 6: Field Layout Options',
  'Demo 7: Error Placement',
  'Demo 8: Breakpoints',
  'Demo 9: Preset Showcase',
  'Demo 10: Central JSON-Driven Style',
];

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

  /// Open [tile] inside a fresh [FormDemoApp] while capturing any
  /// `FlutterError.onError` events. Returns the captured details so
  /// callers can assert on them.
  Future<List<FlutterErrorDetails>> openDemoCapturingErrors(
    WidgetTester tester,
    String tile,
  ) async {
    // A wide, tall viewport so even the densest demos (H-A, H-C) lay
    // out without overflow exceptions that would otherwise drown out
    // genuine regressions.
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      captured.add(details);
      // Don't forward — we don't want the harness to also mark the test
      // failed via FlutterError; we assert on `captured` ourselves so
      // the message is informative.
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text(tile),
      80,
      duration: const Duration(milliseconds: 500),
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    // `scrollUntilVisible` sometimes leaves the tile's centre just
    // beyond the viewport edge — `ensureVisible` nudges it fully
    // on-screen so the subsequent tap actually hits.
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    // Tap the ListTile ancestor (large hit-area) rather than the Text
    // node. The Text's bounding box can still be partially clipped by
    // the bottom card padding even after `ensureVisible`, which makes
    // the tap silently miss; the ListTile spans the full row and is
    // the actual `onTap` receiver.
    final tileFinder = find.ancestor(
      of: find.text(tile),
      matching: find.byType(ListTile),
    );
    expect(
      tileFinder,
      findsOneWidget,
      reason: 'ListTile ancestor of "$tile" must exist',
    );
    await tester.tap(tileFinder);
    // pumpAndSettle covers route animations + any post-frame
    // initialisation work that might throw lazily.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    return captured;
  }

  String summarise(List<FlutterErrorDetails> errors) {
    final buf = StringBuffer();
    for (var i = 0; i < errors.length; i++) {
      buf.writeln('--- error ${i + 1}/${errors.length} ---');
      buf.writeln(errors[i].exceptionAsString());
      final lib = errors[i].library;
      if (lib != null) buf.writeln('library: $lib');
    }
    return buf.toString();
  }

  for (final tile in kAllDemoTiles) {
    testWidgets('opens "$tile" without FlutterError', (tester) async {
      final errors = await openDemoCapturingErrors(tester, tile);
      expect(
        errors,
        isEmpty,
        reason:
            'Opening "$tile" produced ${errors.length} '
            'FlutterError(s):\n${summarise(errors)}',
      );
    });
  }
}
