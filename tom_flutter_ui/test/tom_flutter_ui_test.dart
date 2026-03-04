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
  });
}
