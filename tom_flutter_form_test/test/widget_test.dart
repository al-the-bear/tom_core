// Basic widget test for Form Demo App

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  testWidgets('Demo list screen shows all demos', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FormDemoApp());

    // All tiles are present — scroll each into view before asserting so
    // the test works regardless of default viewport height. Phase 1 demos
    // (A/B/C) sit above the legacy numbered ones, with Phase 3–6 demos
    // (I–R) wedged between Phase 1 and the legacy numbered demos.
    //
    // We use a small `delta` (80 px) and a longer `duration` (500 ms) so
    // each drag has time to settle before the next iteration. With the
    // default `delta: 200` + `duration: 50ms`, fling momentum carries the
    // viewport past short tiles between iterations and `scrollUntilVisible`
    // can skip a tile entirely (e.g. Demo 2 between Demo 1 and Demo 3).
    for (final label in const [
      'Demo A: Lifecycle & Validation',
      'Demo B: Authorization & Events',
      'Demo C: Nested Forms & Theming',
      'Demo D: Hide on Authorization',
      'Demo E: Selection Variants',
      'Demo F: Boolean Variants',
      'Demo G: Complex Breakpoint Scenarios',
      'Demo H: Complex Authorization Scenarios',
      'Demo I: Numeric Forms',
      'Demo J: Date/Time/Duration Forms',
      'Demo K: Enum, Object & Lookup',
      'Demo L: Files & Nullable Variants',
      'Demo M: Material vs Cupertino (Phase 5a)',
      'Demo N: Cupertino numeric + date/time (Phase 5b)',
      'Demo O: Cupertino search / lookup / file (Phase 5c)',
      'Demo P: FormFieldFamily swap by breakpoint (Phase 5c)',
      'Demo Q: Auth / Empty / Overlay (Phase 6)',
      'Demo R: Tree / Radio / Infinite scroll (Phase 6)',
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
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        80,
        // RootScreen wraps the demo list in a TabBarView, so the tree
        // holds several Scrollables (the TabBarView's PageView plus each
        // tab's ListView). Scope the scroll to the DemoListScreen's own
        // Scrollable; the bare finder would match >1 and throw.
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),
        duration: const Duration(milliseconds: 500),
      );
      expect(find.text(label), findsOneWidget);
    }
  });
}
