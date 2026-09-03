/// Drag-resize behaviour coverage for `ResizableBox`
/// (`lib/acl_demos/resizable_box.dart`) — review tests finding §66.
///
/// `ResizableBox` is the only widget in `acl_demos/` with real behavioural
/// logic; its resize arithmetic was exercised by nothing. These `WidgetTester`
/// drag tests pin:
///
///  - the global-position **1:1 delta** on the right / bottom / corner handles
///    (a pointer move of N px changes that axis by exactly N),
///  - the `_minW` / `_minH` (100 px) **clamps** on each handle,
///  - the `_captureIntrinsicHeight()` **first-drag seeding** — a box started in
///    auto-height mode seeds the first vertical drag from the child's intrinsic
///    height, not from zero / the minimum.
///
/// Assertions read the widget's own live size chip (`'<w> × <h>'` /
/// `'<w> × auto'`) — the direct render of the `_width`/`_height` state under
/// test — so they stay decoupled from the now-private `_ResizableBoxState`
/// type (privatised by member_visibility §30 / plan step #13).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';

void main() {
  // The box seeds its width from the parent's bounded width; a 500-wide parent
  // pinned to the top-left makes the box rect start at the screen origin so
  // global drag coordinates are easy to reason about.
  const parentWidth = 500.0;
  // Child taller than _minH (100) so intrinsic-height seeding is distinguishable
  // from the clamp floor.
  const childHeight = 140.0;

  Future<void> pumpBox(WidgetTester tester, {double? initialHeight}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: parentWidth,
              child: ResizableBox(
                initialHeight: initialHeight,
                child: const SizedBox(
                  width: 300,
                  height: childHeight,
                  child: ColoredBox(color: Color(0xFF2196F3)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags from [start] by [delta] as a single pan and settles.
  Future<void> drag(WidgetTester tester, Offset start, Offset delta) async {
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  // Handle hit-points derived from the live box rect. The right edge handle is
  // a 10px-wide strip down the right (excluding the bottom corner); the bottom
  // handle a 10px strip along the bottom (excluding the right corner); the
  // corner handle the bottom-right 20×20 square.
  Offset rightHandle(WidgetTester t) {
    final r = t.getRect(find.byType(ResizableBox));
    return Offset(r.right - 5, r.top + 20); // mid-strip, clear of the corner
  }

  Offset bottomHandle(WidgetTester t) {
    final r = t.getRect(find.byType(ResizableBox));
    return Offset(r.left + 20, r.bottom - 5); // mid-strip, clear of the corner
  }

  Offset cornerHandle(WidgetTester t) {
    final r = t.getRect(find.byType(ResizableBox));
    return Offset(r.right - 5, r.bottom - 5);
  }

  group('ResizableBox right-edge handle', () {
    testWidgets('tracks the pointer 1:1 in width', (tester) async {
      await pumpBox(tester, initialHeight: 200);
      expect(find.text('500 × 200'), findsOneWidget);

      await drag(tester, rightHandle(tester), const Offset(40, 0));

      expect(find.text('540 × 200'), findsOneWidget);
    });

    testWidgets('clamps width to _minW (100) on a large negative drag', (
      tester,
    ) async {
      await pumpBox(tester, initialHeight: 200);

      await drag(tester, rightHandle(tester), const Offset(-1000, 0));

      expect(find.text('100 × 200'), findsOneWidget);
    });
  });

  group('ResizableBox bottom-edge handle', () {
    testWidgets('tracks the pointer 1:1 in height', (tester) async {
      await pumpBox(tester, initialHeight: 200);

      await drag(tester, bottomHandle(tester), const Offset(0, 60));

      expect(find.text('500 × 260'), findsOneWidget);
    });

    testWidgets('clamps height to _minH (100) on a large negative drag', (
      tester,
    ) async {
      await pumpBox(tester, initialHeight: 200);

      await drag(tester, bottomHandle(tester), const Offset(0, -1000));

      expect(find.text('500 × 100'), findsOneWidget);
    });
  });

  group('ResizableBox corner handle', () {
    testWidgets('resizes both axes 1:1', (tester) async {
      await pumpBox(tester, initialHeight: 200);

      await drag(tester, cornerHandle(tester), const Offset(40, 60));

      expect(find.text('540 × 260'), findsOneWidget);
    });
  });

  group('ResizableBox auto-height seeding', () {
    testWidgets('starts in auto mode and shows the size chip as "w × auto"', (
      tester,
    ) async {
      await pumpBox(tester, initialHeight: null);

      expect(find.text('500 × auto'), findsOneWidget);
    });

    testWidgets(
      'first vertical drag seeds from the child intrinsic height, not zero',
      (tester) async {
        await pumpBox(tester, initialHeight: null);

        // childHeight (140) > _minH (100), so a +50 drag yields 190, proving the
        // seed came from _captureIntrinsicHeight() and not from 0 or the floor.
        await drag(tester, bottomHandle(tester), const Offset(0, 50));

        expect(find.text('500 × 190'), findsOneWidget);
      },
    );
  });
}
