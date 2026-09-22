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

  group('an unbounded width is answered, not divided', () {
    // A grid divides the available width among its columns, so substituting a
    // stand-in number for an unbounded constraint gives cells of that number's
    // order — the largest finite double over two columns is about 9e307. That
    // is not an exception, just a nonsense layout, which is harder to diagnose
    // than a throw. So the width travels as null and each kind answers it:
    // never-break for a wrap, content-sized cells for a grid. Unbounded width
    // is ordinary — a horizontal `ListView`, an unconstrained `Row` child and
    // Flutter's own intrinsic passes all produce it.

    /// A host whose width constraint is unbounded.
    Widget unboundedHost(Widget child) => MaterialApp(
      home: Scaffold(
        body: ListView(
          scrollDirection: Axis.horizontal,
          children: [SizedBox(height: 400, child: child)],
        ),
      ),
    );

    test('a grid keeps the components own widths when the width is null', () {
      final container = AclFlowContainer(
        kind: AclFlowKind.grid,
        columns: 2,
        components: List.generate(4, (i) => _item('cell$i', width: 100)),
      );

      final rows = container.buildRows(null);

      expect(rows, hasLength(2), reason: 'the row assignment still applies');
      for (final row in rows) {
        for (final cell in row.components) {
          expect(
            cell.preferredSize?.width,
            100.0,
            reason:
                'a cell keeps its declared width when there is none to '
                'divide, so the grid is as wide as its content',
          );
        }
      }
    });

    test('a non-finite width is treated the same as none', () {
      // The public function guards too, so a caller that passes infinity
      // directly gets the same answer as one that passes null.
      final container = AclFlowContainer(
        kind: AclFlowKind.grid,
        columns: 2,
        components: List.generate(4, (i) => _item('cell$i', width: 100)),
      );

      for (final width in [double.infinity, double.negativeInfinity]) {
        final cells = container
            .buildRows(width)
            .expand((r) => r.components)
            .map((c) => c.preferredSize?.width);
        expect(cells, everyElement(100.0), reason: 'at width $width');
      }
    });

    test('a bounded width still divides, so the guard is not a blanket', () {
      final container = AclFlowContainer(
        kind: AclFlowKind.grid,
        columns: 2,
        gutterWidth: 10,
        components: List.generate(4, (i) => _item('cell$i', width: 100)),
      );

      final cells = container
          .buildRows(410)
          .expand((r) => r.components)
          .map((c) => c.preferredSize?.width);
      // (410 - 10) / 2
      expect(cells, everyElement(200.0));
    });

    testWidgets('a grid inside an unbounded host lays out finitely', (
      tester,
    ) async {
      // The end-to-end claim. `getSize` on a ~9e307-wide cell is the failure
      // this reproduces; a finite width is the fix.
      await tester.pumpWidget(
        unboundedHost(
          AclFlowContainer(
            kind: AclFlowKind.grid,
            columns: 2,
            components: List.generate(4, (i) => _item('cell$i', width: 100)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final width = tester.getSize(find.text('cell0')).width;
      expect(width.isFinite, isTrue, reason: 'the cell width must be finite');
      expect(
        width,
        lessThan(1000),
        reason:
            'a cell sized from its own 100-wide preference, not from a '
            'divided stand-in for infinity',
      );
    });

    testWidgets('a wrap inside an unbounded host puts everything on one row', (
      tester,
    ) async {
      // The other kind's answer to the same question, and the reason the width
      // arrives as null rather than as a number: unbounded means "never break"
      // here, which is the opposite of what the grid needs.
      final container = AclFlowContainer(
        kind: AclFlowKind.wrap,
        components: List.generate(4, (i) => _item('chip$i', width: 100)),
      );

      await tester.pumpWidget(unboundedHost(container));
      await tester.pumpAndSettle();

      expect(container.buildRows(null), hasLength(1));
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
