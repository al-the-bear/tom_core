import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('AclFlags', () {
    test('expandX and expandY are distinct', () {
      expect(AclFlags.expandX, 1);
      expect(AclFlags.expandY, 2);
      expect(AclFlags.expandX & AclFlags.expandY, 0);
    });

    test('expand combines expandX and expandY', () {
      expect(AclFlags.expand, AclFlags.expandX | AclFlags.expandY);
    });

    test('otherDim combines otherDimX and otherDimY', () {
      expect(AclFlags.otherDim, AclFlags.otherDimX | AclFlags.otherDimY);
    });
  });

  group('AclBuilder', () {
    test('creates empty container', () {
      final builder = AclBuilder();
      final container = builder.build();
      expect(container.rows.length, 1);
      expect(container.rows[0].components.isEmpty, true);
    });

    test('appends components', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .append(const Text('B'))
          .build();
      expect(container.rows.length, 1);
      expect(container.rows[0].components.length, 2);
    });

    test('creates new rows', () {
      final container = AclBuilder()
          .append(const Text('Row 1'))
          .newRow()
          .append(const Text('Row 2'))
          .build();
      expect(container.rows.length, 2);
    });

    test('sets row alignment', () {
      final container = AclBuilder()
          .append(const Text('Centered'))
          .setRowAlignment(RowAlignment.center)
          .build();
      expect(container.rows[0].alignment, RowAlignment.center);
    });

    test('sets component attributes', () {
      final container = AclBuilder()
          .append(const Text('Expandable'))
          .setAttr(AclFlags.expandX | AclFlags.expandY)
          .build();
      final component = container.rows[0].components[0];
      expect(component.expandX, true);
      expect(component.expandY, true);
    });

    test('sets component spacing', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .append(const Text('B'), dist: 10)
          .build();
      expect(container.rows[0].components[1].gapBefore, 10);
    });

    test('sets preferred size', () {
      final container = AclBuilder()
          .append(const Text('Sized'))
          .setPSize(100, 50)
          .build();
      expect(
        container.rows[0].components[0].preferredSize,
        const Size(100, 50),
      );
    });

    test('sets minimum size', () {
      final container = AclBuilder()
          .append(const Text('Min sized'))
          .setMSize(50, 25)
          .build();
      expect(container.rows[0].components[0].minimumSize, const Size(50, 25));
    });

    test('supports edge-to-edge APIs and keyless references', () {
      final nameLabel = const SizedBox(width: 140, child: Text('Name'));
      final nameField = const SizedBox(width: 280, child: Text('Name Field'));
      final streetLabel = const SizedBox(child: Text('Street'));
      final streetField = const SizedBox(child: Text('Street Field'));

      final container = AclBuilder()
          .append(nameLabel)
          .append(nameField, dist: 10)
          .newRow(dist: 8)
          .append(streetLabel)
          .alignLeftToLeft(nameLabel)
          .append(streetField, dist: 10)
          .sameWidthAs(nameField)
          .sameHeightAs(nameField)
          .alignRightToRight(nameField)
          .build();

      final linkedField = container.rows[1].components[1];
      expect(linkedField.useOtherDimX, isTrue);
      expect(linkedField.useOtherDimY, isTrue);
      expect(linkedField.referenceKey, isNotNull);
    });

    test('sameSize links width and height to reference', () {
      final anchor = Container();
      final follower = Container();

      final container = AclBuilder()
          .append(anchor)
          .append(follower)
          .sameSize(anchor)
          .build();

      final linked = container.rows[0].components[1];
      expect(linked.useOtherDimX, isTrue);
      expect(linked.useOtherDimY, isTrue);
      expect(
        linked.referenceKey,
        same(container.rows[0].components[0].componentKey),
      );
    });

    test('convenience placement APIs set expected alignments', () {
      final first = Container();
      final second = Container();
      final third = Container();
      final fourth = Container();
      final fifth = Container();

      final container = AclBuilder()
          .append(first)
          .addBelow(second, vGap: 10, hOffset: 4)
          .addLeft(third, hGap: 6, vOffset: 3)
          .addAbove(fourth, vGap: 8, hOffset: 2)
          .addRight(fifth, hGap: 5, vOffset: 1)
          .build();

      final c2 = container.rows[0].components[1];
      expect(c2.alignYFrom, AclAxisPointY.top);
      expect(c2.alignYTo, AclAxisPointY.bottom);
      expect(c2.alignYGap, -10);
      expect(c2.alignXFrom, AclAxisPointX.left);
      expect(c2.alignXTo, AclAxisPointX.left);
      expect(c2.alignXGap, -4);

      final c3 = container.rows[0].components[2];
      expect(c3.alignXFrom, AclAxisPointX.right);
      expect(c3.alignXTo, AclAxisPointX.left);
      expect(c3.alignXGap, 6);
      expect(c3.alignYFrom, AclAxisPointY.top);
      expect(c3.alignYTo, AclAxisPointY.top);
      expect(c3.alignYGap, -3);

      final c4 = container.rows[0].components[3];
      expect(c4.alignYFrom, AclAxisPointY.bottom);
      expect(c4.alignYTo, AclAxisPointY.top);
      expect(c4.alignYGap, 8);
      expect(c4.alignXFrom, AclAxisPointX.left);
      expect(c4.alignXTo, AclAxisPointX.left);
      expect(c4.alignXGap, -2);

      final c5 = container.rows[0].components[4];
      expect(c5.alignXFrom, AclAxisPointX.left);
      expect(c5.alignXTo, AclAxisPointX.right);
      expect(c5.alignXGap, -5);
      expect(c5.alignYFrom, AclAxisPointY.top);
      expect(c5.alignYTo, AclAxisPointY.top);
      expect(c5.alignYGap, -1);
    });
  });

  group('AclContainer widget', () {
    testWidgets('renders rows and components', (tester) async {
      final container = AclBuilder()
          .append(const Text('Hello'))
          .newRow()
          .append(const Text('World'))
          .build();

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: container)));

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('applies border style when enabled', (tester) async {
      final container = AclBuilder()
          .append(const Text('Framed'))
          .setBorderStyle(
            const AclBorderStyle(
              enabled: true,
              lineKind: AclBorderLineKind.single,
              primaryColor: Colors.blue,
            ),
          )
          .build();

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: container)));

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('applies reference alignment and same-size constraints', (
      tester,
    ) async {
      const leftAnchorKey = ValueKey('left-anchor-test');
      const rightAnchorKey = ValueKey('right-anchor-test');
      const buttonAnchorKey = ValueKey('button-anchor-test');

      final alignedFieldAKey = GlobalKey(debugLabel: 'aligned-field-a');
      final alignedFieldBKey = GlobalKey(debugLabel: 'aligned-field-b');
      final linkedButtonKey = GlobalKey(debugLabel: 'linked-button');

      final anchorLabel = const SizedBox(
        key: leftAnchorKey,
        width: 140,
        child: Text('Anchor Label'),
      );
      final anchorField = const SizedBox(
        key: rightAnchorKey,
        width: 280,
        child: TextField(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
      final anchorButton = ElevatedButton(
        key: buttonAnchorKey,
        onPressed: () {},
        child: const Text('Anchor Action'),
      );

      final acl = AclBuilder()
          .append(anchorLabel)
          .append(anchorField, dist: 12)
          .newRow(dist: 10)
          .append(const SizedBox(child: Text('Linked Label A')))
          .sameWidthAs(anchorLabel)
          .alignLeftToLeft(anchorLabel)
          .append(
            SizedBox(
              key: alignedFieldAKey,
              child: const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            dist: 12,
          )
          .sameWidthAs(anchorField)
          .sameHeightAs(anchorField)
          .alignRightToRight(anchorField)
          .newRow(dist: 10)
          .append(const SizedBox(child: Text('Linked Label B')))
          .sameWidthAs(anchorLabel)
          .alignLeftToLeft(anchorLabel)
          .append(
            SizedBox(
              key: alignedFieldBKey,
              child: const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            dist: 12,
          )
          .sameWidthAs(anchorField)
          .sameHeightAs(anchorField)
          .alignRightToRight(anchorField, gap: 16)
          .newRow(dist: 14)
          .append(anchorButton)
          .append(
            OutlinedButton(
              key: linkedButtonKey,
              onPressed: () {},
              child: const Text('Same Size Button'),
            ),
            dist: 16,
          )
          .sameWidthAs(anchorButton)
          .sameHeightAs(anchorButton)
          .build();

      expect(acl.rows[1].components[1].useOtherDimX, isTrue);
      expect(acl.rows[1].components[1].useOtherDimY, isTrue);
      expect(
        acl.rows[1].components[1].referenceKey,
        same(acl.rows[0].components[1].componentKey),
      );

      final widget = MaterialApp(
        home: Scaffold(body: SizedBox(width: 900, child: acl)),
      );

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(rightAnchorKey));
      final rectA = tester.getRect(find.byKey(alignedFieldAKey));
      final rectB = tester.getRect(find.byKey(alignedFieldBKey));
      expect((rectA.right - anchorRect.right).abs(), closeTo(0, 1.0));
      expect((rectB.right - (anchorRect.right - 16)).abs(), closeTo(0, 1.0));
      expect((rectA.width - anchorRect.width).abs(), closeTo(0, 1.0));
      expect((rectB.width - anchorRect.width).abs(), closeTo(0, 1.0));

      expect(find.byKey(buttonAnchorKey), findsOneWidget);
      expect(find.byKey(linkedButtonKey), findsOneWidget);
      final buttonAnchorRect = tester.getRect(find.byKey(buttonAnchorKey));
      final linkedButtonRect = tester.getRect(find.byKey(linkedButtonKey));
      expect(
        (linkedButtonRect.width - buttonAnchorRect.width).abs(),
        closeTo(0, 1.0),
      );
      expect(
        (linkedButtonRect.height - buttonAnchorRect.height).abs(),
        closeTo(0, 1.0),
      );
    });

    testWidgets('alignRightToRight gap counts to left (positive)', (
      tester,
    ) async {
      final anchorField = Container(
        key: const ValueKey('anchor-field'),
        width: 220,
        height: 36,
        color: Colors.blue,
      );
      final linkedField = Container(
        key: const ValueKey('linked-field'),
        height: 36,
        color: Colors.green,
      );

      final acl = AclBuilder()
          .append(const SizedBox(width: 120, child: Text('Anchor')))
          .append(anchorField, dist: 12)
          .newRow(dist: 10)
          .append(const SizedBox(width: 120, child: Text('Linked')))
          .append(linkedField, dist: 12)
          .sameWidthAs(anchorField)
          .sameHeightAs(anchorField)
          .alignRightToRight(anchorField, gap: 16)
          .build();

      final anchorComp = acl.rows[0].components[1];
      final linkedComp = acl.rows[1].components[1];
      expect(linkedComp.alignXToKey, same(anchorComp.componentKey));
      expect(linkedComp.componentKey, isNot(same(anchorComp.componentKey)));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 900, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(
        find.byKey(const ValueKey('anchor-field')),
      );
      final linkedRect = tester.getRect(
        find.byKey(const ValueKey('linked-field')),
      );

      expect(
        (linkedRect.right - (anchorRect.right - 16)).abs(),
        closeTo(0, 1.0),
      );
      expect((linkedRect.width - anchorRect.width).abs(), closeTo(0, 1.0));
      expect((linkedRect.height - anchorRect.height).abs(), closeTo(0, 1.0));
    });

    testWidgets('size overrides apply minimum preferred and maximum', (
      tester,
    ) async {
      final constrainedBox = Container(
        key: const ValueKey('size-override-box'),
        color: Colors.amber,
      );

      final acl = AclBuilder()
          .append(constrainedBox)
          .setMSize(90, 28)
          .setPSize(120, 40)
          .setXSize(140, 44)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 500, child: acl)),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(
        find.byKey(const ValueKey('size-override-box')),
      );
      expect(rect.width, closeTo(120, 1.0));
      expect(rect.height, closeTo(40, 1.0));
    });

    testWidgets('expandX distributes width by growth weight ratio', (
      tester,
    ) async {
      final left = Container(
        key: const ValueKey('expand-left'),
        color: Colors.red,
      );
      final right = Container(
        key: const ValueKey('expand-right'),
        color: Colors.blue,
      );

      final acl = AclBuilder()
          .append(left)
          .setAttr(AclFlags.expandX)
          .setMSize(100, 32)
          .setPSize(200, 32)
          .append(right, dist: 0)
          .setAttr(AclFlags.expandX)
          .setMSize(100, 32)
          .setPSize(300, 32)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 500, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final leftRect = tester.getRect(
        find.byKey(const ValueKey('expand-left')),
      );
      final rightRect = tester.getRect(
        find.byKey(const ValueKey('expand-right')),
      );

      expect(leftRect.width, closeTo(500 / 3, 1.0));
      expect(rightRect.width, closeTo((500 * 2) / 3, 1.0));
      expect((rightRect.width / leftRect.width), closeTo(2.0, 0.05));
    });

    testWidgets('expandX honors explicit maximum while extra width remains', (
      tester,
    ) async {
      final left = Container(
        key: const ValueKey('max-left'),
        color: Colors.purple,
      );
      final right = Container(
        key: const ValueKey('max-right'),
        color: Colors.orange,
      );

      final acl = AclBuilder()
          .append(left)
          .setAttr(AclFlags.expandX)
          .setMSize(80, 30)
          .setPSize(200, 30)
          .setXSize(200, 30)
          .append(right)
          .setAttr(AclFlags.expandX)
          .setMSize(80, 30)
          .setPSize(220, 30)
          .setXSize(220, 30)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 700, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final leftRect = tester.getRect(find.byKey(const ValueKey('max-left')));
      final rightRect = tester.getRect(find.byKey(const ValueKey('max-right')));

      expect(leftRect.width <= 200.5, isTrue);
      expect(rightRect.width <= 220.5, isTrue);
    });

    testWidgets('expandY distributes vertical space by row growth weights', (
      tester,
    ) async {
      final top = Container(
        key: const ValueKey('expand-top'),
        color: Colors.green,
      );
      final bottom = Container(
        key: const ValueKey('expand-bottom'),
        color: Colors.teal,
      );

      final acl = AclBuilder()
          .append(top)
          .setAttr(AclFlags.expandY)
          .setMSize(100, 60)
          .setPSize(100, 160)
          .newRow(dist: 0)
          .append(bottom)
          .setAttr(AclFlags.expandY)
          .setMSize(100, 60)
          .setPSize(100, 260)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 300, height: 420, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final topRect = tester.getRect(find.byKey(const ValueKey('expand-top')));
      final bottomRect = tester.getRect(
        find.byKey(const ValueKey('expand-bottom')),
      );

      expect(bottomRect.height > topRect.height, isTrue);
      expect((bottomRect.height / topRect.height), closeTo(2.0, 0.25));
    });

    testWidgets(
      'left convenience placement remains inside and next row expands',
      (tester) async {
        const hostKey = ValueKey('host-container');
        const firstKey = ValueKey('first');
        const leftKey = ValueKey('left-of-first');
        const expAKey = ValueKey('expand-a');
        const expBKey = ValueKey('expand-b');

        final first = Container(key: firstKey, color: Colors.indigo);
        final left = Container(key: leftKey, color: Colors.orange);
        final expA = Container(key: expAKey, color: Colors.green);
        final expB = Container(key: expBKey, color: Colors.red);

        final acl = AclBuilder()
            .append(first)
            .setPSize(180, 48)
            .addLeft(left, hGap: 12)
            .setPSize(120, 36)
            .newRow(dist: 14)
            .append(expA)
            .setAttr(AclFlags.expandX)
            .setPSize(100, 36)
            .append(expB, dist: 8)
            .setAttr(AclFlags.expandX)
            .setPSize(100, 36)
            .build();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 620,
                child: Container(
                  key: hostKey,
                  color: Colors.black12,
                  child: acl,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final hostRect = tester.getRect(find.byKey(hostKey));
        final firstRect = tester.getRect(find.byKey(firstKey));
        final leftRect = tester.getRect(find.byKey(leftKey));
        final expARect = tester.getRect(find.byKey(expAKey));
        final expBRect = tester.getRect(find.byKey(expBKey));

        final leftStarts = <double>[leftRect.left];
        final firstStarts = <double>[firstRect.left];
        for (var i = 0; i < 6; i++) {
          await tester.pump();
          leftStarts.add(tester.getRect(find.byKey(leftKey)).left);
          firstStarts.add(tester.getRect(find.byKey(firstKey)).left);
        }

        expect(leftRect.left >= hostRect.left - 1, isTrue);
        expect(firstRect.left >= hostRect.left - 1, isTrue);
        expect(expARect.width > 240, isTrue);
        expect(expBRect.width > 240, isTrue);
        expect(
          leftStarts.reduce(math.max) - leftStarts.reduce(math.min),
          lessThanOrEqualTo(0.5),
        );
        expect(
          firstStarts.reduce(math.max) - firstStarts.reduce(math.min),
          lessThanOrEqualTo(0.5),
        );
      },
    );

    testWidgets('row alignment left center right is respected', (tester) async {
      final leftKey = GlobalKey(debugLabel: 'align-left');
      final centerKey = GlobalKey(debugLabel: 'align-center');
      final rightKey = GlobalKey(debugLabel: 'align-right');

      final acl = AclBuilder()
          .append(SizedBox(key: leftKey, width: 100, height: 32))
          .setRowAlignment(RowAlignment.left)
          .newRow(dist: 8)
          .append(SizedBox(key: centerKey, width: 100, height: 32))
          .setRowAlignment(RowAlignment.center)
          .newRow(dist: 8)
          .append(SizedBox(key: rightKey, width: 100, height: 32))
          .setRowAlignment(RowAlignment.right)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 600, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final leftRect = tester.getRect(find.byKey(leftKey));
      final centerRect = tester.getRect(find.byKey(centerKey));
      final rightRect = tester.getRect(find.byKey(rightKey));

      expect(leftRect.left < centerRect.left, isTrue);
      expect(centerRect.left < rightRect.left, isTrue);
      expect(centerRect.left, closeTo(250, 8));
      expect(rightRect.left, closeTo(500, 8));
    });

    testWidgets('single expandX child grows between fixed siblings', (
      tester,
    ) async {
      const leftKey = ValueKey('fixed-left');
      const middleKey = ValueKey('expand-middle');
      const rightKey = ValueKey('fixed-right');

      final acl = AclBuilder()
          .append(SizedBox(key: leftKey, width: 120, height: 36))
          .append(SizedBox(key: middleKey, height: 36), dist: 8)
          .setAttr(AclFlags.expandX)
          .append(SizedBox(key: rightKey, width: 120, height: 36), dist: 8)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 640, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final leftRect = tester.getRect(find.byKey(leftKey));
      final middleRect = tester.getRect(find.byKey(middleKey));
      final rightRect = tester.getRect(find.byKey(rightKey));

      expect(leftRect.width, closeTo(120, 1));
      expect(rightRect.width, closeTo(120, 1));
      expect(middleRect.width, greaterThan(350));
    });

    testWidgets('convenience placement horizontal position stays stable', (
      tester,
    ) async {
      const firstKey = ValueKey('stable-first');
      const leftKey = ValueKey('stable-left');

      final acl = AclBuilder()
          .append(SizedBox(key: firstKey, width: 180, height: 40))
          .addLeft(SizedBox(key: leftKey, width: 120, height: 32), hGap: 12)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 620, child: acl)),
        ),
      );
      await tester.pump();
      final firstLeft = tester.getRect(find.byKey(leftKey));
      await tester.pump();
      await tester.pump();
      final laterLeft = tester.getRect(find.byKey(leftKey));

      expect((laterLeft.left - firstLeft.left).abs(), lessThanOrEqualTo(0.5));
    });

    testWidgets('spacer as component does not throw parent-data error', (
      tester,
    ) async {
      final acl = AclBuilder()
          .append(const Text('Left'))
          .append(const Spacer())
          .setAttr(AclFlags.expandX)
          .append(const Text('Right'))
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 500, child: acl)),
        ),
      );
      await tester.pump();

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
