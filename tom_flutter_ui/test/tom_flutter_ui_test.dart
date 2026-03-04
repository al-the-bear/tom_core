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
  });
}
