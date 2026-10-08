import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// An expandX component keeps its floor — its minimum, or its preferred width
// when no minimum is declared — and only the space left over once every
// component has its fitted width is shared among the expanding ones, by the
// weight `(preferred / minimum) − 1`: doc/acl_design_specification.md
// §6 Step 3 (Option B) and §5b.
//
// The table these tests reproduce was measured against an engine that wrapped
// each expanding component in `Flexible(flex: preferred − minimum)`, so the
// whole row was divided by those weights and a declared minimum of 300 came out
// a few pixels wide — narrower the more room the row had.

Widget _host(Widget child, double width) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, height: 200, child: child),
    ),
  ),
);

const _aKey = Key('a');
const _bKey = Key('b');

/// A row of two expanding components, each filling whatever it is offered: A
/// prefers 400 px, and [declare] adds B's sizes.
Acl _row(AclBuilder Function(AclBuilder) declare) {
  final builder = AclBuilder()
      .setAclDefaultAppendGap(0)
      .append(Container(key: _aKey, height: 20, color: Colors.red))
      .setPSize(400, 20)
      .expandX()
      .append(Container(key: _bKey, height: 20, color: Colors.blue))
      .expandX();
  return declare(builder).build();
}

/// Pumps [acl] in a host [width] wide, on a view wide enough to hold it — the
/// default test surface is 800 px, which would clamp every wider host.
Future<void> _pump(WidgetTester tester, Acl acl, double width) async {
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(acl, width));
  await tester.pumpAndSettle();
}

Future<double> _widthOfB(WidgetTester tester, Acl acl, double width) async {
  await _pump(tester, acl, width);
  return tester.getSize(find.byKey(_bKey)).width;
}

void main() {
  group('ACL expandX keeps its floor while the row has room for it', () {
    for (final available in [900.0, 1200.0]) {
      testWidgets('EXF-1: a declared minimum holds at $available', (
        tester,
      ) async {
        final b = await _widthOfB(
          tester,
          _row((x) => x.setMSize(300, 20)),
          available,
        );
        expect(b, greaterThanOrEqualTo(300 - 0.5));
      });

      testWidgets('EXF-2: minimum = preferred holds at $available', (
        tester,
      ) async {
        final b = await _widthOfB(
          tester,
          _row((x) => x.setMSize(300, 20).setPSize(300, 20)),
          available,
        );
        expect(b, greaterThanOrEqualTo(300 - 0.5));
      });

      testWidgets('EXF-3: a preferred width with no minimum is the floor at '
          '$available', (tester) async {
        final b = await _widthOfB(
          tester,
          _row((x) => x.setPSize(300, 20)),
          available,
        );
        expect(b, greaterThanOrEqualTo(300 - 0.5));
      });

      testWidgets('EXF-4: A keeps its own 400 px preferred floor at '
          '$available', (tester) async {
        await _widthOfB(tester, _row((x) => x.setPSize(300, 20)), available);
        expect(
          tester.getSize(find.byKey(_aKey)).width,
          greaterThanOrEqualTo(400 - 0.5),
        );
      });
    }

    testWidgets('EXF-5: the row is filled exactly — floors plus surplus', (
      tester,
    ) async {
      await _widthOfB(tester, _row((x) => x.setPSize(300, 20)), 1200);
      final a = tester.getSize(find.byKey(_aKey)).width;
      final b = tester.getSize(find.byKey(_bKey)).width;
      expect(a + b, closeTo(1200, 1));
    });
  });

  group('ACL expandX shares the surplus by (preferred / minimum) − 1', () {
    testWidgets('EXF-6: weights 1 and 2 take one and two thirds', (
      tester,
    ) async {
      const p = Key('p');
      const q = Key('q');
      final acl = AclBuilder()
          .setAclDefaultAppendGap(0)
          // (200 / 100) − 1 = 1
          .append(Container(key: p, height: 20, color: Colors.red))
          .setMSize(100, 20)
          .setPSize(200, 20)
          .expandX()
          // (300 / 100) − 1 = 2
          .append(Container(key: q, height: 20, color: Colors.green))
          .setMSize(100, 20)
          .setPSize(300, 20)
          .expandX()
          .build();
      // Floors 200 + 300 = 500; a surplus of 300 splits 100 / 200.
      await _pump(tester, acl, 800);
      expect(tester.getSize(find.byKey(p)).width, closeTo(300, 1));
      expect(tester.getSize(find.byKey(q)).width, closeTo(500, 1));
    });

    testWidgets('EXF-7: with no proportional request the surplus splits '
        'evenly', (tester) async {
      const p = Key('p');
      const q = Key('q');
      final acl = AclBuilder()
          .setAclDefaultAppendGap(0)
          .append(Container(key: p, height: 20, color: Colors.red))
          .setPSize(100, 20)
          .expandX()
          .append(Container(key: q, height: 20, color: Colors.green))
          .setPSize(300, 20)
          .expandX()
          .build();
      // Floors 100 + 300; the 400 left over halves.
      await _pump(tester, acl, 800);
      expect(tester.getSize(find.byKey(p)).width, closeTo(300, 1));
      expect(tester.getSize(find.byKey(q)).width, closeTo(500, 1));
    });

    testWidgets('EXF-8: a maximum caps a share and the rest goes to the '
        'others', (tester) async {
      const p = Key('p');
      const q = Key('q');
      final acl = AclBuilder()
          .setAclDefaultAppendGap(0)
          .append(Container(key: p, height: 20, color: Colors.red))
          .setPSize(100, 20)
          .setXSize(150, 20)
          .expandX()
          .append(Container(key: q, height: 20, color: Colors.green))
          .setPSize(100, 20)
          .expandX()
          .build();
      await _pump(tester, acl, 800);
      expect(tester.getSize(find.byKey(p)).width, closeTo(150, 1));
      expect(tester.getSize(find.byKey(q)).width, closeTo(650, 1));
    });
  });

  group('ACL a minimum above the preferred width raises it', () {
    testWidgets('EXF-9: the neighbour shrinks toward its own minimum, not '
        'the declared floor', (tester) async {
      const p = Key('p');
      const q = Key('q');
      final acl = AclBuilder()
          .setAclDefaultAppendGap(0)
          .append(Container(key: p, height: 20, color: Colors.red))
          .setPSize(460, 20)
          .setMSize(280, 20)
          .expandX()
          // Preferred stays the built-in default (150); the minimum is above
          // it, so the minimum is the width the row has to plan for.
          .append(Container(key: q, height: 20, color: Colors.green))
          .setMSize(734, 20)
          .expandX()
          .build();
      // 460 + 734 does not fit 1136: P shrinks toward its 280, Q holds 734.
      await _pump(tester, acl, 1136);
      expect(tester.getSize(find.byKey(q)).width, closeTo(734, 1));
      expect(tester.getSize(find.byKey(p)).width, closeTo(402, 1));
    });
  });
}
