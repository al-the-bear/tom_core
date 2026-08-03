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

  // The two responsive passes run before layout and rewrite the row tree:
  // _selectVariantRows swaps the whole tree for a narrower variant, and
  // _applyRowBreakpoints splits one row into fragments. Both are private and
  // both are driven from build() with the container's available width, so a
  // bounded-width host is the whole test fixture.
  //
  // Each threshold is asserted on both sides *and* exactly on it: the
  // comparison is a strict `availableWidth < atWidth`, so the boundary width
  // itself must keep the wide layout. That is the assertion that fails if the
  // comparison is ever loosened to `<=`.
  group('Acl responsive variants — _selectVariantRows', () {
    Widget variantAcl() => AclBuilder()
        .append(const Text('wide layout'))
        .addVariant(
          'narrow',
          atWidth: 300,
          builder: (b) => b.append(const Text('narrow layout')),
        )
        .build();

    testWidgets('above the threshold the default rows are used',
        (tester) async {
      await tester.pumpWidget(_host(variantAcl(), width: 400));
      await tester.pumpAndSettle();

      expect(find.text('wide layout'), findsOneWidget);
      expect(find.text('narrow layout'), findsNothing);
    });

    testWidgets('below the threshold the variant rows replace them',
        (tester) async {
      await tester.pumpWidget(_host(variantAcl(), width: 250));
      await tester.pumpAndSettle();

      expect(find.text('narrow layout'), findsOneWidget);
      expect(find.text('wide layout'), findsNothing);
    });

    testWidgets('exactly at the threshold the default rows still win',
        (tester) async {
      // `availableWidth < atWidth` is strict, so 300 is not "below 300".
      await tester.pumpWidget(_host(variantAcl(), width: 300));
      await tester.pumpAndSettle();

      expect(find.text('wide layout'), findsOneWidget);
      expect(find.text('narrow layout'), findsNothing);
    });

    testWidgets('the narrowest matching variant wins, whatever the declaration '
        'order', (tester) async {
      // Declared widest-first; build() sorts variants by atWidth ascending, and
      // the pass returns the *first* match — so at 250 both thresholds are
      // exceeded and the more specific (narrower) one must be chosen.
      final acl = AclBuilder()
          .append(const Text('wide layout'))
          .addVariant('medium',
              atWidth: 500,
              builder: (b) => b.append(const Text('medium layout')))
          .addVariant('narrow',
              atWidth: 300,
              builder: (b) => b.append(const Text('narrow layout')))
          .build();

      await tester.pumpWidget(_host(acl, width: 250));
      await tester.pumpAndSettle();

      expect(find.text('narrow layout'), findsOneWidget);
      expect(find.text('medium layout'), findsNothing);

      // And between the two thresholds the wider variant applies.
      await tester.pumpWidget(_host(acl, width: 400));
      await tester.pumpAndSettle();

      expect(find.text('medium layout'), findsOneWidget);
      expect(find.text('narrow layout'), findsNothing);
    });
  });

  group('Acl row breakpoints — _applyRowBreakpoints', () {
    const aKey = Key('bp-a');
    const bKey = Key('bp-b');
    const cKey = Key('bp-c');

    // Every dimension the assertions depend on is pinned by the builder, so the
    // expected offsets below are arithmetic on this fixture rather than on
    // framework defaults: two 60x20 components, the 8px default append gap, a
    // 20px row height and a 12px split distance.
    const double compW = 60;
    const double compH = 20;
    const double appendGap = 8;
    const double rowH = 20;
    const double splitDist = 12;

    Widget splitAcl() => AclBuilder()
        .setAclDefaultRowHeight(rowH)
        .append(Container(key: aKey, color: Colors.red))
        .setPSize(compW, compH)
        .addRowBreakpoint(atWidth: 300, splitRowDist: splitDist)
        .append(Container(key: bKey, color: Colors.blue))
        .setPSize(compW, compH)
        .build();

    testWidgets('above the threshold the row stays intact', (tester) async {
      await tester.pumpWidget(_host(splitAcl(), width: 400));
      await tester.pumpAndSettle();

      final a = tester.getTopLeft(find.byKey(aKey));
      final b = tester.getTopLeft(find.byKey(bKey));

      // Golden geometry: same row, B one component width plus the append gap
      // to the right of A.
      expect(b.dy, a.dy);
      expect(b.dx, closeTo(a.dx + compW + appendGap, 0.01));
    });

    testWidgets('below the threshold the row splits into two', (tester) async {
      await tester.pumpWidget(_host(splitAcl(), width: 250));
      await tester.pumpAndSettle();

      final a = tester.getTopLeft(find.byKey(aKey));
      final b = tester.getTopLeft(find.byKey(bKey));

      // Golden geometry: B moves onto its own row — back to A's left edge, and
      // down by the row height plus the breakpoint's split distance.
      expect(b.dx, closeTo(a.dx, 0.01));
      expect(b.dy, closeTo(a.dy + rowH + splitDist, 0.01));
    });

    testWidgets('exactly at the threshold the row is not split',
        (tester) async {
      await tester.pumpWidget(_host(splitAcl(), width: 300));
      await tester.pumpAndSettle();

      final a = tester.getTopLeft(find.byKey(aKey));
      final b = tester.getTopLeft(find.byKey(bKey));

      expect(b.dy, a.dy);
      expect(b.dx, closeTo(a.dx + compW + appendGap, 0.01));
    });

    testWidgets('two breakpoints split one row into three fragments',
        (tester) async {
      final acl = AclBuilder()
          .setAclDefaultRowHeight(rowH)
          .append(Container(key: aKey, color: Colors.red))
          .setPSize(compW, compH)
          .addRowBreakpoint(atWidth: 300, splitRowDist: splitDist)
          .append(Container(key: bKey, color: Colors.blue))
          .setPSize(compW, compH)
          .addRowBreakpoint(atWidth: 300, splitRowDist: splitDist)
          .append(Container(key: cKey, color: Colors.green))
          .setPSize(compW, compH)
          .build();

      await tester.pumpWidget(_host(acl, width: 250, height: 300));
      await tester.pumpAndSettle();

      final a = tester.getTopLeft(find.byKey(aKey));
      final b = tester.getTopLeft(find.byKey(bKey));
      final c = tester.getTopLeft(find.byKey(cKey));

      // Three fragments stacked at a uniform pitch, all sharing the left edge.
      expect(b.dx, closeTo(a.dx, 0.01));
      expect(c.dx, closeTo(a.dx, 0.01));
      expect(b.dy, closeTo(a.dy + rowH + splitDist, 0.01));
      expect(c.dy, closeTo(b.dy + rowH + splitDist, 0.01));
    });

    testWidgets('a breakpoint only splits the row that declares it',
        (tester) async {
      const otherKey = Key('bp-other');
      final acl = AclBuilder()
          .setAclDefaultRowHeight(rowH)
          .append(Container(key: aKey, color: Colors.red))
          .setPSize(compW, compH)
          .addRowBreakpoint(atWidth: 300, splitRowDist: splitDist)
          .append(Container(key: bKey, color: Colors.blue))
          .setPSize(compW, compH)
          .newRow()
          .append(Container(key: cKey, color: Colors.green))
          .setPSize(compW, compH)
          .append(Container(key: otherKey, color: Colors.orange))
          .setPSize(compW, compH)
          .build();

      await tester.pumpWidget(_host(acl, width: 250, height: 300));
      await tester.pumpAndSettle();

      final b = tester.getTopLeft(find.byKey(bKey));
      final c = tester.getTopLeft(find.byKey(cKey));
      final other = tester.getTopLeft(find.byKey(otherKey));

      // The first row split (B is below A, asserted above); the second row has
      // no breakpoint, so it keeps both components side by side.
      expect(other.dy, c.dy);
      expect(other.dx, closeTo(c.dx + compW + appendGap, 0.01));
      // …and it still sits below the split fragment.
      expect(c.dy, greaterThan(b.dy));
    });
  });
}
