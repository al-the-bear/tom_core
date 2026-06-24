import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tests §59(d): the example suite had NO tester.pumpWidget at all, so the whole
// _AclContainerState layout engine was unexercised. This is a starter set that
// drives the engine through a real render: multi-row layout, titled rendering,
// and the expandX grow path (_computeFittedWidths slack distribution).

Widget _host(Widget child, {double width = 400, double height = 200}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

void main() {
  group('Acl layout engine — pumpWidget (§59d starter)', () {
    testWidgets('renders every appended component across rows', (tester) async {
      final acl = AclBuilder(title: 'Address')
          .append(const Text('Street'))
          .gap()
          .append(const Text('No.'))
          .newRow()
          .append(const Text('City'))
          .build();

      await tester.pumpWidget(_host(acl));
      await tester.pumpAndSettle();

      expect(find.text('Street'), findsOneWidget);
      expect(find.text('No.'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      // Titled Acl draws its title label.
      expect(find.text('Address'), findsOneWidget);
    });

    testWidgets('expandX component absorbs the row slack width', (tester) async {
      const fixedKey = Key('fixed');
      const growKey = Key('grow');

      final acl = AclBuilder()
          .append(Container(key: fixedKey, color: Colors.red))
          .setPSize(80, 30)
          .gap()
          .append(Container(key: growKey, color: Colors.blue))
          .setPSize(80, 30)
          .expandX()
          .build();

      await tester.pumpWidget(_host(acl, width: 400, height: 100));
      await tester.pumpAndSettle();

      final fixedWidth = tester.getSize(find.byKey(fixedKey)).width;
      final growWidth = tester.getSize(find.byKey(growKey)).width;

      // The fixed component keeps its preferred width; the expandX one grows
      // to take the remaining horizontal space.
      expect(fixedWidth, closeTo(80, 1));
      expect(growWidth, greaterThan(fixedWidth));
    });

    testWidgets('row horizontal alignment is honoured end-to-end',
        (tester) async {
      // Two narrow components in a wide row, right-aligned: their combined
      // right edge should sit near the container's right edge.
      const aKey = Key('a');
      const bKey = Key('b');

      final acl = AclBuilder()
          .setAclDefaultRowHorizontalAlignment(RowAlignment.right)
          .append(Container(key: aKey, color: Colors.red))
          .setPSize(40, 20)
          .gap()
          .append(Container(key: bKey, color: Colors.blue))
          .setPSize(40, 20)
          .build();

      await tester.pumpWidget(_host(acl, width: 400, height: 80));
      await tester.pumpAndSettle();

      final containerRight = tester.getTopRight(find.byType(SizedBox).first).dx;
      final bRight = tester.getTopRight(find.byKey(bKey)).dx;

      // Right-aligned: the last component's right edge is in the right portion
      // of the available width (not pinned to the left).
      expect(bRight, greaterThan(containerRight / 2));
    });
  });
}
