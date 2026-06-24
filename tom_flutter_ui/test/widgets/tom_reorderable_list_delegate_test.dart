import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// bug §34 + tests §25: TomReorderableList.buildContent force-cast its
// `childrenDelegate` to SliverChildBuilderDelegate, so a caller passing the
// equally-valid SliverChildListDelegate (the common `SliverChildListDelegate([...])`
// form) hit a runtime CastError. These pin that BOTH stock delegate shapes
// render through a real pump.

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 400, width: 300, child: child),
      ),
    );

void main() {
  testWidgets('renders from a SliverChildListDelegate (bug §34)',
      (tester) async {
    await tester.pumpWidget(_host(TomReorderableList(
      childrenDelegate: SliverChildListDelegate([
        const ListTile(key: ValueKey('a'), title: Text('item-a')),
        const ListTile(key: ValueKey('b'), title: Text('item-b')),
      ]),
      onReorder: (_, _) {},
    )));

    expect(find.text('item-a'), findsOneWidget);
    expect(find.text('item-b'), findsOneWidget);
  });

  testWidgets('still renders from a SliverChildBuilderDelegate',
      (tester) async {
    await tester.pumpWidget(_host(TomReorderableList(
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) =>
            ListTile(key: ValueKey(index), title: Text('row-$index')),
        childCount: 3,
      ),
      onReorder: (_, _) {},
    )));

    expect(find.text('row-0'), findsOneWidget);
    expect(find.text('row-1'), findsOneWidget);
    expect(find.text('row-2'), findsOneWidget);
  });
}
