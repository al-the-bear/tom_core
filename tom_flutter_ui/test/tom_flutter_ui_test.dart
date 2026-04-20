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
          .setRowHorizontalAlignment(RowAlignment.center)
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

    test('sameSize links width and height to reference (cross-row)', () {
      final anchor = Container();
      final follower = Container();

      // sameSize requires cross-row reference (e3551ca)
      final container = AclBuilder()
          .append(anchor)
          .newRow()
          .append(follower)
          .sameSize(anchor)
          .build();

      final linked = container.rows[1].components[0];
      expect(linked.useOtherDimX, isTrue);
      expect(linked.useOtherDimY, isTrue);
      expect(
        linked.referenceKey,
        same(container.rows[0].components[0].componentKey),
      );
    });

    test('convenience placement APIs set expected alignments', () {
      // After e3551ca: alignX* requires different row, alignY* requires same row
      final first = Container();
      final second = Container();
      final third = Container();
      final fourth = Container();
      final fifth = Container();

      final container = AclBuilder()
          .append(first)
          // Same-row Y alignment
          .append(second)
          .alignTopToBottom(first, gap: -10)
          .append(third)
          .alignTopToTop(first, gap: -3)
          .append(fourth)
          .alignBottomToTop(first, gap: 8)
          .append(fifth)
          .alignTopToTop(first, gap: -1)
          // Cross-row X alignment in next row
          .newRow()
          .append(Container())
          .alignLeftToLeft(first, gap: -4)
          .append(Container())
          .alignRightToLeft(first, gap: 6)
          .append(Container())
          .alignLeftToLeft(first, gap: -2)
          .append(Container())
          .alignLeftToRight(first, gap: -5)
          .build();

      // Same-row Y alignments (row 0)
      final c2 = container.rows[0].components[1];
      expect(c2.alignYFrom, AclAxisPointY.top);
      expect(c2.alignYTo, AclAxisPointY.bottom);
      expect(c2.alignYGap, -10);

      final c3 = container.rows[0].components[2];
      expect(c3.alignYFrom, AclAxisPointY.top);
      expect(c3.alignYTo, AclAxisPointY.top);
      expect(c3.alignYGap, -3);

      final c4 = container.rows[0].components[3];
      expect(c4.alignYFrom, AclAxisPointY.bottom);
      expect(c4.alignYTo, AclAxisPointY.top);
      expect(c4.alignYGap, 8);

      final c5 = container.rows[0].components[4];
      expect(c5.alignYFrom, AclAxisPointY.top);
      expect(c5.alignYTo, AclAxisPointY.top);
      expect(c5.alignYGap, -1);

      // Cross-row X alignments (row 1)
      final r1c0 = container.rows[1].components[0];
      expect(r1c0.alignXFrom, AclAxisPointX.left);
      expect(r1c0.alignXTo, AclAxisPointX.left);
      expect(r1c0.alignXGap, -4);

      final r1c1 = container.rows[1].components[1];
      expect(r1c1.alignXFrom, AclAxisPointX.right);
      expect(r1c1.alignXTo, AclAxisPointX.left);
      expect(r1c1.alignXGap, 6);

      final r1c2 = container.rows[1].components[2];
      expect(r1c2.alignXFrom, AclAxisPointX.left);
      expect(r1c2.alignXTo, AclAxisPointX.left);
      expect(r1c2.alignXGap, -2);

      final r1c3 = container.rows[1].components[3];
      expect(r1c3.alignXFrom, AclAxisPointX.left);
      expect(r1c3.alignXTo, AclAxisPointX.right);
      expect(r1c3.alignXGap, -5);
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
          .setAclBorderStyle(const AclBorderStyle.solid(color: Colors.blue))
          .build();

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: container)));

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('applies reference alignment and same-size constraints', (
      tester,
    ) async {
      // Simplified test: two rows with cross-row alignment and size linking
      const anchorKey = ValueKey('anchor');
      const linkedKey = ValueKey('linked');

      // Use SizedBox with explicit dimensions to ensure fixed size
      final anchor = SizedBox(
        key: anchorKey,
        width: 200,
        height: 40,
        child: Container(color: Colors.blue),
      );
      final linked = Container(key: linkedKey, color: Colors.green);

      final acl = AclBuilder()
          .append(anchor)
          .setMSize(200, 40)
          .setPSize(200, 40)
          .newRow(dist: 10)
          .append(linked)
          .sameWidthAs(anchor)
          .sameHeightAs(anchor)
          .alignRightToRight(anchor) // align right edges
          .build();

      // Verify the component data is set correctly
      expect(acl.rows[1].components[0].useOtherDimX, isTrue);
      expect(acl.rows[1].components[0].useOtherDimY, isTrue);
      expect(
        acl.rows[1].components[0].referenceKey,
        same(acl.rows[0].components[0].componentKey),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 400, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final linkedRect = tester.getRect(find.byKey(linkedKey));

      // Anchor should be 200px as specified
      expect(anchorRect.width, closeTo(200, 1.0), reason: 'anchor width');
      // Both should have same width (from sameWidthAs)
      expect(
        linkedRect.width,
        closeTo(anchorRect.width, 1.0),
        reason: 'sameWidthAs should link widths',
      );
      // Both should have same height (from sameHeightAs)
      expect(
        linkedRect.height,
        closeTo(anchorRect.height, 1.0),
        reason: 'sameHeightAs should link heights',
      );
      // Right edges should align (from alignRightToRight)
      expect(
        linkedRect.right,
        closeTo(anchorRect.right, 1.0),
        reason: 'alignRightToRight should align right edges',
      );
    });

    testWidgets('alignRightToRight gap counts to left (positive)', (
      tester,
    ) async {
      // Test that alignRightToRight with a positive gap shifts the component
      // to the left of the reference (gap counts towards left from right edge)
      final anchorField = Container(
        key: const ValueKey('anchor-field'),
        width: 220,
        height: 36,
        color: Colors.blue,
      );
      final linkedField = Container(
        key: const ValueKey('linked-field'),
        width: 220,
        height: 36,
        color: Colors.green,
      );

      final acl = AclBuilder()
          .append(anchorField)
          .setPSize(220, 36)
          .newRow(dist: 10)
          .append(linkedField)
          .setPSize(220, 36)
          .alignRightToRight(anchorField, gap: 16)
          .build();

      final anchorComp = acl.rows[0].components[0];
      final linkedComp = acl.rows[1].components[0];
      expect(linkedComp.alignXToKey, same(anchorComp.componentKey));
      expect(linkedComp.componentKey, isNot(same(anchorComp.componentKey)));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 500, child: acl)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(
        find.byKey(const ValueKey('anchor-field')),
      );
      final linkedRect = tester.getRect(
        find.byKey(const ValueKey('linked-field')),
      );

      // With gap: 16, linked.right should be at anchor.right - 16
      expect(
        (linkedRect.right - (anchorRect.right - 16)).abs(),
        closeTo(0, 1.0),
      );
      expect(linkedRect.width, closeTo(220, 1.0));
    });

    testWidgets('size overrides apply minimum preferred and maximum', (
      tester,
    ) async {
      // With surplus space (500px container, pref 120px), a non-expandX
      // component with min/pref/max gets surplus up to its maximum size.
      // The distribution weight is (pref/min - 1); higher ratio = more share.
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
      // With surplus, component grows to maximum size (horizontal only)
      expect(rect.width, closeTo(140, 1.0));
      // Height stays at preferred (vertical expansion requires expandY)
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
          .setAclDefaultAppendGap(0)
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

        // After e3551ca: alignX* requires cross-row reference
        final acl = AclBuilder()
            .append(first)
            .setPSize(180, 48)
            .newRow(dist: 8)
            .append(left)
            .setPSize(120, 36)
            .alignRightToLeft(first, gap: 12)
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

    testWidgets(
      'row alignment left center right is respected',
      (tester) async {
        final centerKey = GlobalKey(debugLabel: 'align-center');

        // Test AclContainer row alignment
        final acl = AclBuilder()
            .append(SizedBox(key: centerKey, width: 100, height: 32))
            .setPSize(100, 32)
            .setRowHorizontalAlignment(RowAlignment.center)
            .build();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 600,
                  height: 200,
                  child: acl,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final centerRect = tester.getRect(find.byKey(centerKey));
        final scaffold = tester.getRect(find.byType(Scaffold));

        // The centered SizedBox should be at the center of the 600px container
        final containerLeft = (scaffold.width - 600) / 2;
        final expectedCenterLeft = containerLeft + (600 - 100) / 2;

        expect(
          centerRect.left,
          closeTo(expectedCenterLeft, 10),
          reason:
              'AclContainer center-aligned row should be at ~${expectedCenterLeft}px, got ${centerRect.left}',
        );
      },
    );

    testWidgets('single expandX child grows between fixed siblings', (
      tester,
    ) async {
      const leftKey = ValueKey('fixed-left');
      const middleKey = ValueKey('expand-middle');
      const rightKey = ValueKey('fixed-right');

      // With expandX in the row, non-expandX components stay at preferredSize.
      // Explicit setPSize ensures fixed children are exactly 120px.
      final acl = AclBuilder()
          .append(SizedBox(key: leftKey, width: 120, height: 36))
          .setPSize(120, 36)
          .append(SizedBox(key: middleKey, height: 36), dist: 8)
          .setAttr(AclFlags.expandX)
          .append(SizedBox(key: rightKey, width: 120, height: 36), dist: 8)
          .setPSize(120, 36)
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
      // 640 - 120*2 - 8*2 gaps = 384px for expandX
      expect(middleRect.width, greaterThan(350));
    });

    testWidgets('convenience placement horizontal position stays stable', (
      tester,
    ) async {
      const firstKey = ValueKey('stable-first');
      const leftKey = ValueKey('stable-left');

      final firstBox = SizedBox(key: firstKey, width: 180, height: 40);
      final leftBox = SizedBox(key: leftKey, width: 120, height: 32);
      // After e3551ca: alignX* requires cross-row reference
      final acl = AclBuilder()
          .append(firstBox)
          .newRow(dist: 8)
          .append(leftBox)
          .alignRightToLeft(firstBox, gap: 12)
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

    testWidgets('alignTopToBottom places follower edge-flush with no gap',
        (tester) async {
      const anchorKey = ValueKey('acl-tb-anchor');
      const followerKey = ValueKey('acl-tb-follower');
      final anchor = Container(
        key: anchorKey,
        color: const Color(0xFFE64A19),
        width: 160,
        height: 64,
      );
      final follower = Container(
        key: followerKey,
        color: const Color(0xFF004D40),
        width: 160,
        height: 36,
      );
      final acl = AclBuilder()
          .append(anchor)
          .setPSize(160, 64)
          .append(const SizedBox(width: 24))
          .append(follower)
          .setPSize(160, 36)
          .alignTopToBottom(anchor)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 500, height: 200, child: acl),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final followerRect = tester.getRect(find.byKey(followerKey));

      expect(followerRect.top, closeTo(anchorRect.bottom, 0.5),
          reason: 'follower.top should equal anchor.bottom (edge-flush)');
      expect(tester.takeException(), isNull,
          reason: 'no overflow expected');
    });

    testWidgets('alignBottomToTop places follower edge-flush with no gap',
        (tester) async {
      const anchorKey = ValueKey('acl-bt-anchor');
      const followerKey = ValueKey('acl-bt-follower');
      final anchor = Container(
        key: anchorKey,
        color: const Color(0xFF607D8B),
        width: 160,
        height: 64,
      );
      final follower = Container(
        key: followerKey,
        color: const Color(0xFF6A1B9A),
        width: 160,
        height: 36,
      );
      final acl = AclBuilder()
          .append(anchor)
          .setPSize(160, 64)
          .append(const SizedBox(width: 24))
          .append(follower)
          .setPSize(160, 36)
          .alignBottomToTop(anchor)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 500, height: 200, child: acl),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final followerRect = tester.getRect(find.byKey(followerKey));

      expect(followerRect.bottom, closeTo(anchorRect.top, 0.5),
          reason: 'follower.bottom should equal anchor.top (edge-flush)');
      expect(tester.takeException(), isNull,
          reason: 'no overflow expected');
    });

    testWidgets(
        'alignTopToBottom gap>0 pushes follower further down; gap<0 overlaps',
        (tester) async {
      const anchorKey = ValueKey('acl-tb-anchor-gap');
      const pushKey = ValueKey('acl-tb-push');
      const overlapKey = ValueKey('acl-tb-overlap');
      final anchor = Container(
        key: anchorKey, color: const Color(0xFFE64A19),
        width: 160, height: 56,
      );
      final pushFollower = Container(
        key: pushKey, color: const Color(0xFF2E7D32),
        width: 160, height: 32,
      );
      final overlapFollower = Container(
        key: overlapKey, color: const Color(0xFF00796B),
        width: 160, height: 32,
      );
      final acl = AclBuilder()
          .append(anchor).setPSize(160, 56)
          .append(const SizedBox(width: 12))
          .append(pushFollower).setPSize(160, 32)
          .alignTopToBottom(anchor, gap: 12)
          .append(const SizedBox(width: 12))
          .append(overlapFollower).setPSize(160, 32)
          .alignTopToBottom(anchor, gap: -12)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 700, height: 200, child: acl),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final pushRect = tester.getRect(find.byKey(pushKey));
      final overlapRect = tester.getRect(find.byKey(overlapKey));

      expect(pushRect.top, closeTo(anchorRect.bottom + 12, 0.5),
          reason: 'gap: 12 should sit 12 px BELOW anchor bottom');
      expect(overlapRect.top, closeTo(anchorRect.bottom - 12, 0.5),
          reason: 'gap: -12 should overlap anchor bottom by 12 px');
    });

    testWidgets(
        'alignBottomToTop gap>0 pushes follower further up; gap<0 overlaps',
        (tester) async {
      const anchorKey = ValueKey('acl-bt-anchor-gap');
      const pushKey = ValueKey('acl-bt-push');
      const overlapKey = ValueKey('acl-bt-overlap');
      final anchor = Container(
        key: anchorKey, color: const Color(0xFF607D8B),
        width: 160, height: 56,
      );
      final pushFollower = Container(
        key: pushKey, color: const Color(0xFF6A1B9A),
        width: 160, height: 32,
      );
      final overlapFollower = Container(
        key: overlapKey, color: const Color(0xFF4E342E),
        width: 160, height: 32,
      );
      final acl = AclBuilder()
          .append(anchor).setPSize(160, 56)
          .append(const SizedBox(width: 12))
          .append(pushFollower).setPSize(160, 32)
          .alignBottomToTop(anchor, gap: 12)
          .append(const SizedBox(width: 12))
          .append(overlapFollower).setPSize(160, 32)
          .alignBottomToTop(anchor, gap: -12)
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 700, height: 200, child: acl),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final anchorRect = tester.getRect(find.byKey(anchorKey));
      final pushRect = tester.getRect(find.byKey(pushKey));
      final overlapRect = tester.getRect(find.byKey(overlapKey));

      expect(pushRect.bottom, closeTo(anchorRect.top - 12, 0.5),
          reason: 'gap: 12 should sit 12 px ABOVE anchor top');
      expect(overlapRect.bottom, closeTo(anchorRect.top + 12, 0.5),
          reason: 'gap: -12 should overlap anchor top by 12 px');
    });
  });

  group('AclBuilder row height (Phase 5)', () {
    test('newRow height sets per-row height', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .newRow(height: 80)
          .append(const Text('B'))
          .build();

      expect(container.rows[0].height, isNull);
      expect(container.rows[1].height, 80);
    });

    test('setRowHeight on current row', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .setRowHeight(64)
          .build();

      expect(container.rows[0].height, 64);
    });

    test('setAclDefaultRowHeight applied to rows without explicit height', () {
      final container = AclBuilder()
          .setAclDefaultRowHeight(48)
          .append(const Text('A'))
          .newRow()
          .append(const Text('B'))
          .newRow(height: 96)
          .append(const Text('C'))
          .build();

      expect(container.rows[0].height, 48);
      expect(container.rows[1].height, 48);
      expect(container.rows[2].height, 96);
    });

    test('row height breakpoint overrides resolve to widest match', () {
      final row = AclRow(
        components: const [],
        height: 40,
        heightBpOverrides: const [(600, 60), (900, 80)],
      );

      expect(aclResolveRowHeight(row, 500), 40);
      expect(aclResolveRowHeight(row, 600), 60);
      expect(aclResolveRowHeight(row, 850), 60);
      expect(aclResolveRowHeight(row, 900), 80);
      expect(aclResolveRowHeight(row, 1200), 80);
    });

    test('row with no height and no overrides resolves null', () {
      final row = AclRow(components: const []);
      expect(aclResolveRowHeight(row, 600), isNull);
      expect(aclResolveRowHeight(row, null), isNull);
    });
  });

  group('AclBuilder append gap defaults (Phase 5)', () {
    test('default append gap is 8px and applies to first component', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .append(const Text('B'))
          .build();

      final row = container.rows[0];
      // Both components tagged as using the default gap
      expect(row.components[0].gapBeforeIsDefault, true);
      expect(row.components[1].gapBeforeIsDefault, true);
      expect(row.defaultAppendGap, 8.0);

      // Resolved effective gap at any width is 8
      expect(aclEffectiveGapBefore(row.components[0], row, 500), 8.0);
      expect(aclEffectiveGapBefore(row.components[1], row, 500), 8.0);
    });

    test('setAclDefaultAppendGap overrides default value', () {
      final container = AclBuilder()
          .setAclDefaultAppendGap(0)
          .append(const Text('A'))
          .append(const Text('B'))
          .build();

      final row = container.rows[0];
      expect(row.defaultAppendGap, 0);
      expect(aclEffectiveGapBefore(row.components[0], row, 500), 0);
      expect(aclEffectiveGapBefore(row.components[1], row, 500), 0);
    });

    test('explicit dist on append suppresses default gap', () {
      final container = AclBuilder()
          .append(const Text('A'))
          .append(const Text('B'), dist: 20)
          .build();

      final row = container.rows[0];
      expect(row.components[0].gapBeforeIsDefault, true);
      expect(row.components[1].gapBeforeIsDefault, false);
      expect(row.components[1].gapBefore, 20);
      expect(aclEffectiveGapBefore(row.components[1], row, 500), 20);
    });

    test('setAclDefaultAppendGap breakpoint overrides resolve by width', () {
      final container = AclBuilder()
          .setAclDefaultAppendGap(4, const [(600, 12), (1024, 20)])
          .append(const Text('A'))
          .append(const Text('B'))
          .build();

      final row = container.rows[0];
      expect(aclEffectiveGapBefore(row.components[0], row, 400), 4);
      expect(aclEffectiveGapBefore(row.components[0], row, 600), 12);
      expect(aclEffectiveGapBefore(row.components[0], row, 900), 12);
      expect(aclEffectiveGapBefore(row.components[0], row, 1024), 20);
      expect(aclEffectiveGapBefore(row.components[0], row, 2000), 20);
    });
  });
}
