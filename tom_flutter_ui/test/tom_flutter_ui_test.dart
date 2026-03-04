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
      final leftAnchorKey = GlobalKey(debugLabel: 'left-anchor-test');
      final rightAnchorKey = GlobalKey(debugLabel: 'right-anchor-test');
      final buttonAnchorKey = GlobalKey(debugLabel: 'button-anchor-test');

      final alignedFieldAKey = GlobalKey(debugLabel: 'aligned-field-a');
      final alignedFieldBKey = GlobalKey(debugLabel: 'aligned-field-b');
      final linkedButtonKey = GlobalKey(debugLabel: 'linked-button');

      final widget = MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: AclBuilder()
                .append(const SizedBox(width: 140, child: Text('Anchor Label')))
                .setKey(leftAnchorKey)
                .append(
                  const SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  dist: 12,
                )
                .setKey(rightAnchorKey)
                .newRow(dist: 10)
                .append(const SizedBox(child: Text('Linked Label A')))
                .sameWidthAs(leftAnchorKey)
                .alignLeftToComp(leftAnchorKey)
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
                .sameSizeAs(rightAnchorKey)
                .alignRightToComp(rightAnchorKey)
                .newRow(dist: 10)
                .append(const SizedBox(child: Text('Linked Label B')))
                .sameWidthAs(leftAnchorKey)
                .alignLeftToComp(leftAnchorKey)
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
                .sameSizeAs(rightAnchorKey)
                .alignRightToComp(rightAnchorKey, gap: 16)
                .newRow(dist: 14)
                .append(
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Anchor Action'),
                  ),
                )
                .setKey(buttonAnchorKey)
                .append(
                  OutlinedButton(
                    key: linkedButtonKey,
                    onPressed: () {},
                    child: const Text('Same Size Button'),
                  ),
                  dist: 16,
                )
                .sameSizeAs(buttonAnchorKey)
                .build(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump();

      final rectA = tester.getRect(find.byKey(alignedFieldAKey));
      final rectB = tester.getRect(find.byKey(alignedFieldBKey));
      expect((rectA.right - rectB.right).abs(), closeTo(16, 1.0));

      expect(find.byKey(buttonAnchorKey), findsOneWidget);
      expect(find.byKey(linkedButtonKey), findsOneWidget);
    });
  });
}
