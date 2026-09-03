import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Covers the two container kinds that flow a flat child list into rows:
// `wrap` breaks when the next child no longer fits, `grid` breaks every N
// children. Both generate ordinary AclRows, so the assertions come in two
// layers — the pure row assignment (no BuildContext needed) and a real render
// proving the generated rows reach the AclContainer engine.

Widget _host(Widget child, {double width = 400, double height = 400}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

/// A component of a known declared width, so flow decisions are deterministic
/// without measuring anything.
AclComponent _item(String label, {double width = 100, String? id}) {
  return AclComponent(
    child: Text(label),
    id: id,
    preferredSize: Size(width, 0),
  );
}

void main() {
  group('aclWrapRows — break when the next component no longer fits', () {
    test('fills a row to capacity before breaking', () {
      // 3 × 100 wide + 2 × 10 gutter = 320 fits in 340; a 4th would need 430.
      final rows = aclWrapRows(
        List.generate(4, (i) => _item('c$i')),
        availableWidth: 340,
        gutterWidth: 10,
      );

      expect(rows.length, 2);
      expect(rows[0].components.length, 3);
      expect(rows[1].components.length, 1);
    });

    test('first component of every row carries no leading gap', () {
      final rows = aclWrapRows(
        List.generate(4, (i) => _item('c$i')),
        availableWidth: 340,
        gutterWidth: 10,
      );

      expect(rows[0].components[0].gapBefore, 0);
      expect(rows[0].components[1].gapBefore, 10);
      // The wrapped component starts a new row, so its gap is dropped.
      expect(rows[1].components[0].gapBefore, 0);
    });

    test('rows after the first are separated by runSpacing', () {
      final rows = aclWrapRows(
        List.generate(4, (i) => _item('c$i')),
        availableWidth: 340,
        gutterWidth: 10,
        runSpacing: 24,
      );

      expect(rows[0].gapBefore, 0);
      expect(rows[1].gapBefore, 24);
    });

    test('a component wider than the line still gets a row, never dropped', () {
      final rows = aclWrapRows([
        _item('narrow', width: 50),
        _item('huge', width: 900),
      ], availableWidth: 200);

      expect(rows.length, 2);
      expect(rows[1].components.single.child, isA<Text>());
      // Nothing is lost: both components survive the flow.
      expect(
        rows.expand((r) => r.components).length,
        2,
        reason: 'wrap assigns rows, it never discards children',
      );
    });

    test('unsized components fall back to the default item width', () {
      // No declared size → assumed kAclDefaultFlowItemWidth (150) each, so
      // two fit in 320 and the third wraps.
      final rows = aclWrapRows(
        List.generate(3, (i) => AclComponent(child: Text('c$i'))),
        availableWidth: 320,
        gutterWidth: 10,
      );

      expect(rows.length, 2);
      expect(rows[0].components.length, 2);
    });

    test('generated rows are addressable when a prefix is given', () {
      final rows = aclWrapRows(
        List.generate(4, (i) => _item('c$i')),
        availableWidth: 340,
        gutterWidth: 10,
        rowIdPrefix: 'toolbar',
      );

      expect(rows.map((r) => r.id), ['toolbar.r0', 'toolbar.r1']);
    });

    test('an empty child list produces no rows', () {
      expect(aclWrapRows(const [], availableWidth: 300), isEmpty);
    });
  });

  group('aclGridRows — break every N components', () {
    test('chunks into rows of `columns`, last row may be short', () {
      final rows = aclGridRows(
        List.generate(7, (i) => _item('c$i')),
        columns: 3,
      );

      expect(rows.map((r) => r.components.length), [3, 3, 1]);
    });

    test('cells share the width equally once the gutters are removed', () {
      // (320 - 2 × 10) / 3 = 100
      final rows = aclGridRows(
        List.generate(3, (i) => _item('c$i', width: 999)),
        columns: 3,
        availableWidth: 320,
        gutterWidth: 10,
      );

      expect(
        rows.single.components.map((c) => c.preferredSize!.width),
        everyElement(closeTo(100, 0.001)),
      );
    });

    test('a declared height preference survives the cell-width rewrite', () {
      final rows = aclGridRows(
        [
          AclComponent(
            child: const Text('tall'),
            preferredSize: const Size(50, 42),
          ),
        ],
        columns: 1,
        availableWidth: 200,
      );

      expect(rows.single.components.single.preferredSize!.height, 42);
    });

    test('without a known width the declared sizes are left alone', () {
      final rows = aclGridRows([_item('c0', width: 77)], columns: 2);

      expect(rows.single.components.single.preferredSize!.width, 77);
    });

    test('column count is breakpoint-resolvable', () {
      // The widest override at or below the available width wins.
      expect(aclResolveBreakpointed(1, [(600.0, 2), (900.0, 3)], 1000), 3);
      expect(aclResolveBreakpointed(1, [(600.0, 2), (900.0, 3)], 700), 2);
      expect(aclResolveBreakpointed(1, [(600.0, 2), (900.0, 3)], 400), 1);
      expect(aclResolveBreakpointed(1, [(600.0, 2)], null), 1);
    });

    test('rejects a non-positive column count', () {
      expect(() => aclGridRows([_item('c0')], columns: 0), throwsArgumentError);
    });

    test('an empty child list produces no rows', () {
      expect(aclGridRows(const [], columns: 3), isEmpty);
    });
  });

  group('AclFlowContainer — wrap kind renders through the ACL engine', () {
    testWidgets('renders every child and breaks rows at the host width', (
      tester,
    ) async {
      final container = AclFlowContainer(
        kind: AclFlowKind.wrap,
        aclId: 'chips',
        gutterWidth: 10,
        components: List.generate(4, (i) => _item('chip$i')),
      );

      await tester.pumpWidget(_host(container, width: 340));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(find.text('chip$i'), findsOneWidget);
      }
      // Three fit on the first line, so the fourth sits lower down.
      final firstRowY = tester.getTopLeft(find.text('chip0')).dy;
      expect(tester.getTopLeft(find.text('chip2')).dy, firstRowY);
      expect(tester.getTopLeft(find.text('chip3')).dy, greaterThan(firstRowY));
    });

    testWidgets('a narrower host wraps earlier', (tester) async {
      final container = AclFlowContainer(
        kind: AclFlowKind.wrap,
        gutterWidth: 10,
        components: List.generate(4, (i) => _item('chip$i')),
      );

      await tester.pumpWidget(_host(container, width: 220));
      await tester.pumpAndSettle();

      // 220 only fits two 100-wide items (+10 gutter = 210).
      expect(container.buildRows(220).length, 2);
      expect(container.buildRows(340).length, 2);
      expect(container.buildRows(120).length, 4);
    });
  });

  group('AclFlowContainer — grid kind renders through the ACL engine', () {
    testWidgets('places `columns` children per row', (tester) async {
      final container = AclFlowContainer(
        kind: AclFlowKind.grid,
        aclId: 'form',
        columns: 2,
        components: List.generate(5, (i) => _item('cell$i')),
      );

      await tester.pumpWidget(_host(container, width: 400));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('cell$i'), findsOneWidget);
      }
      final firstRowY = tester.getTopLeft(find.text('cell0')).dy;
      expect(tester.getTopLeft(find.text('cell1')).dy, firstRowY);
      expect(tester.getTopLeft(find.text('cell2')).dy, greaterThan(firstRowY));
    });

    testWidgets('breakpoint overrides change the column count', (tester) async {
      final container = AclFlowContainer(
        kind: AclFlowKind.grid,
        columns: 1,
        columnsBpOverrides: const [(600.0, 3)],
        components: List.generate(3, (i) => _item('cell$i')),
      );

      await tester.pumpWidget(_host(container, width: 400));
      await tester.pumpAndSettle();

      // Below the breakpoint: one column, so three rows.
      expect(container.buildRows(400).length, 3);
      // Above it: three columns, so a single row.
      expect(container.buildRows(800).length, 1);
    });
  });
}
