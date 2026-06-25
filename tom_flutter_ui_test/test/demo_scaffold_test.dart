/// Navigation + RTL-toggle coverage for the shared demo scaffold
/// (`lib/common/demo_scaffold.dart`) — review tests finding §67.
///
/// The two interactive behaviours had zero coverage:
///
///  - `DemoTile.onTap` pushes a `MaterialPageRoute` that wraps the demo screen
///    in a `DemoScaffold` titled with the tile's title.
///  - `DemoScaffold`'s RTL `Switch` flips `_direction` between
///    `AclDirection.ltr`/`rtl`, re-wrapping the body in a new `Directionality`
///    + `AclDirectionScope`; on first build the direction is seeded from the
///    ambient locale's text direction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/common/demo_scaffold.dart';

void main() {
  // A child that records the directionality state it is built under, so tests
  // can assert how the scaffold wraps its subtree without reaching into the
  // private `_DemoScaffoldState`.
  AclDirection? scopeDir;
  TextDirection? textDir;
  Widget probe() => Builder(builder: (context) {
        scopeDir = AclDirectionScope.maybeOf(context);
        textDir = Directionality.of(context);
        return const Text('probe-body');
      });

  setUp(() {
    scopeDir = null;
    textDir = null;
  });

  group('DemoTile.onTap', () {
    testWidgets('pushes a DemoScaffold-wrapped route for the tapped tile',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                DemoTile(
                  title: 'Widget Showcase',
                  description: 'A demo',
                  icon: Icons.widgets,
                  screen: probe(),
                ),
              ],
            ),
          ),
        ),
      );

      // Before tapping: the tile is shown, the demo screen is not.
      expect(find.byType(DemoScaffold), findsNothing);
      expect(find.text('probe-body'), findsNothing);

      await tester.tap(find.byType(DemoTile));
      await tester.pumpAndSettle();

      // After tapping: a DemoScaffold route titled with the tile's title is on
      // top, rendering the demo screen.
      expect(find.byType(DemoScaffold), findsOneWidget);
      expect(find.text('probe-body'), findsOneWidget);
      // AppBar title == tile title, and a back button proves a route was pushed.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Widget Showcase')),
        findsOneWidget,
      );
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('DemoScaffold RTL toggle', () {
    testWidgets('defaults to LTR and wraps the body in an LTR scope',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DemoScaffold(title: 'T', child: probe()),
        ),
      );

      expect(scopeDir, AclDirection.ltr);
      expect(textDir, TextDirection.ltr);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('toggling the switch flips the body to RTL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DemoScaffold(title: 'T', child: probe()),
        ),
      );
      expect(scopeDir, AclDirection.ltr);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(scopeDir, AclDirection.rtl,
          reason: 'the AclDirectionScope re-wraps the body as RTL');
      expect(textDir, TextDirection.rtl,
          reason: 'the body Directionality flips to RTL');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // Toggling back returns to LTR.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(scopeDir, AclDirection.ltr);
      expect(textDir, TextDirection.ltr);
    });

    testWidgets('seeds the direction from the ambient locale (RTL)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DemoScaffold(title: 'T', child: probe()),
          ),
        ),
      );

      // First build seeds from the ambient RTL directionality.
      expect(scopeDir, AclDirection.rtl);
      expect(textDir, TextDirection.rtl);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('omits the toggle when showRtlToggle is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DemoScaffold(
            title: 'T',
            showRtlToggle: false,
            child: probe(),
          ),
        ),
      );

      // No switch, but the body is still wrapped in a (default LTR) scope.
      expect(find.byType(Switch), findsNothing);
      expect(scopeDir, AclDirection.ltr);
      expect(textDir, TextDirection.ltr);
    });
  });
}
