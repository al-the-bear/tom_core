/// The auto-applied default preferred width must never produce a *visible*
/// overflow.
///
/// `AclBuilder` gives every component appended without a size hint a preferred
/// width of [AclBuilder.defaultPreferredWidth] (150). Before this suite that
/// width was emitted as a tight `SizedBox`, so a child wider than 150 that
/// cannot shrink — a `Row`, which is what `TomRow` builds — painted the
/// yellow/black striped banner and reported `RenderFlex overflowed by N
/// pixels`, whatever the container's own width was.
///
/// The contract these tests pin:
///
/// * the default width is a **floor**, not a cap — when the row has the space,
///   an unsized child gets its natural width and simply fits;
/// * when the row does *not* have the space, the content is **clipped**, not
///   overflowed, and it keeps the width it laid out at (no relayout of the
///   child, so nothing reflows or re-wraps as the container narrows);
/// * a child narrower than the default still gets the full 150, so every
///   existing layout that relies on the default is unchanged.
///
/// Overflow is detected the same way `tom_flutter_ui_test`'s demo gate detects
/// it — by intercepting `FlutterError.onError` and matching the rendering
/// library's "overflowed by" report — so a green run here means the same thing
/// a green run of `demo_overflow_test.dart` means.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Width of the unsized child used throughout: comfortably wider than the
/// 150 default, and wider than the narrow host below.
const double _wideChildWidth = 520;

const Key _wideKey = Key('wide-unsized-child');

Widget _host(Widget child, {required double width, double height = 200}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

/// A `Row` of fixed-width boxes totalling [_wideChildWidth].
///
/// A `Row` is the shape that makes this fail loudly: it cannot shrink below the
/// sum of its children, so a tight width smaller than that is an overflow
/// rather than a clip.
Widget _wideRow() => Row(
  key: _wideKey,
  mainAxisSize: MainAxisSize.min,
  children: const [
    SizedBox(width: 200, height: 24),
    SizedBox(width: 160, height: 24),
    SizedBox(width: 160, height: 24),
  ],
);

/// Collects rendering-library overflow reports raised while the test runs.
///
/// Registered per test and torn down again, so one test's reports cannot leak
/// into the next.
List<String> _captureOverflows() {
  final overflows = <String>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library == 'rendering library' &&
        details.exception.toString().contains('overflowed by')) {
      overflows.add(details.exception.toString().split('\n').first);
      return;
    }
    priorOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = priorOnError);
  return overflows;
}

void main() {
  group('ACL default preferred width — never a visible overflow', () {
    testWidgets('an unsized child wider than the default fits when the row has '
        'the space', (tester) async {
      final overflows = _captureOverflows();

      final acl = AclBuilder().append(_wideRow()).build();

      await tester.pumpWidget(_host(acl, width: 600));
      await tester.pumpAndSettle();

      expect(
        overflows,
        isEmpty,
        reason:
            'A child appended without a size hint must not overflow the '
            'auto-applied default width',
      );
      // The default is a floor: with 600px available the component takes the
      // width its content actually needs.
      expect(
        tester.getSize(find.byKey(_wideKey)).width,
        closeTo(_wideChildWidth, 0.5),
      );
    });

    testWidgets('the same child is clipped, not overflowed, when the container '
        'is too narrow', (tester) async {
      final overflows = _captureOverflows();

      final acl = AclBuilder().append(_wideRow()).build();

      // Narrower than both the content (520) and the 240px threshold below
      // which clipping is the sanctioned outcome.
      await tester.pumpWidget(_host(acl, width: 200));
      await tester.pumpAndSettle();

      expect(
        overflows,
        isEmpty,
        reason:
            'Too little space must clip the content, not paint the '
            'striped overflow banner',
      );
      // Clipped *without relayout*: the child keeps the width it needs, so
      // nothing inside it reflows as the container narrows — only the visible
      // portion changes.
      expect(
        tester.getSize(find.byKey(_wideKey)).width,
        closeTo(_wideChildWidth, 0.5),
      );
    });

    testWidgets('a child narrower than the default still gets the full default '
        'width', (tester) async {
      const narrowKey = Key('narrow-unsized-child');

      final acl = AclBuilder()
          .append(Container(key: narrowKey, color: Colors.red, height: 24))
          .build();

      await tester.pumpWidget(_host(acl, width: 600));
      await tester.pumpAndSettle();

      // The floor is unchanged: components that fit inside 150 still occupy
      // 150, which is what every existing layout is tuned against.
      expect(
        tester.getSize(find.byKey(narrowKey)).width,
        closeTo(AclBuilder.defaultPreferredWidth, 0.5),
      );
    });

    testWidgets('a child that cannot answer the intrinsics protocol falls back '
        'to the plain default', (tester) async {
      const builderKey = Key('layout-builder-child');

      // `LayoutBuilder` refuses intrinsic queries — it cannot know its size
      // without being given one. Measuring must degrade to "no measurement"
      // rather than throw, leaving the component at the default width, which is
      // what it would have had before any of this existed.
      final acl = AclBuilder()
          .append(
            LayoutBuilder(
              key: builderKey,
              builder: (context, constraints) =>
                  const SizedBox(height: 24, width: double.infinity),
            ),
          )
          .build();

      await tester.pumpWidget(_host(acl, width: 600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(builderKey)).width,
        closeTo(AclBuilder.defaultPreferredWidth, 0.5),
      );
    });
  });
}
