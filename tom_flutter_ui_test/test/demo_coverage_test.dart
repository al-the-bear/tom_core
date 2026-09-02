/// Coverage gate: every screen the app can open is mountable by the harness.
///
/// `test/demo_harness.dart` keeps a hand-written `demos` list, and both the
/// overflow gate and the screenshot harness iterate exactly that list. A screen
/// the app offers but the list omits is therefore not merely untested — it is
/// invisible to the two tools whose whole job is to look at every screen, and
/// nothing anywhere fails to say so. That is not hypothetical: the four
/// Phase-2 forms screens sat outside the list from the day they were written,
/// so the widest layouts in the package were the only ones the layout gate
/// never measured.
///
/// Keeping the list in step was a documented manual step, and a documented
/// manual step is a step that gets skipped. This file replaces the instruction
/// with a failure: it opens each tab, reads the screen off every `DemoTile`
/// the app builds, and asserts the harness can construct one of the same type.
///
/// The comparison is by **runtime type**, not by slug. A slug is the harness's
/// own name for a demo and proves nothing about the app; the widget class is
/// the thing the two sides genuinely share.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui_test/common/demo_scaffold.dart';
import 'package:tom_flutter_ui_test/main.dart';

import 'demo_harness.dart';

/// Tall enough that every tile in a tab is built rather than virtualised away.
///
/// The tabs are `ListView`s, which build only what falls inside the viewport
/// plus its cache extent. The longest tab holds 27 tiles of roughly 90 px, so
/// a viewport in the thousands leaves the whole list resident and makes
/// `find.byType(DemoTile)` an honest enumeration instead of a window onto one.
const Size _tallViewport = Size(1280, 12000);

/// Every screen type the app offers on [tab].
Future<Set<Type>> _screenTypesOf(WidgetTester tester, Widget tab) async {
  tester.view.physicalSize = _tallViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
  await tester.pump();

  final tiles = tester.widgetList<DemoTile>(find.byType(DemoTile));
  expect(tiles, isNotEmpty, reason: 'the tab built no DemoTile at all');
  return tiles.map((t) => t.screen.runtimeType).toSet();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installDemoEnvironment(binding));
  tearDownAll(() => restoreDemoEnvironment(binding));

  /// The screen types the harness can construct.
  ///
  /// Built once per test rather than in a `setUpAll`: the factories construct
  /// real widgets, and several resolve resources in their constructor.
  Set<Type> harnessTypes() => demos.map((d) => d.$2().runtimeType).toSet();

  group('every app screen is mountable by demo_harness', () {
    for (final (label, tab) in const <(String, Widget)>[
      ('ACL Demos', AclDemosTab()),
      ('Widget Demos', WidgetDemosTab()),
      ('Forms/Actions', FormsActionsTab()),
      ('Authorization/Resources', AuthorizationResourcesTab()),
    ]) {
      testWidgets(label, (tester) async {
        final offered = await _screenTypesOf(tester, tab);
        final missing = offered.difference(harnessTypes());

        expect(
          missing,
          isEmpty,
          reason: 'the "$label" tab opens ${missing.length} screen(s) that '
              '`demos` in test/demo_harness.dart cannot construct: '
              '${missing.join(", ")}. Add a (slug, builder) pair for each, or '
              'the overflow gate and the screenshot harness will keep skipping '
              'them silently.',
        );
      });
    }
  });
}
